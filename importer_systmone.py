# ================================================================
# importer_systmone.py — SystmOne CSV and RTF clinical notes import
# ================================================================

from __future__ import annotations

import csv
import re
import io
from pathlib import Path
from typing import List, Dict, Tuple, Optional
from datetime import datetime


# ----------------------------------------------------------------
# Constants
# ----------------------------------------------------------------

SYSTMONE_HEADER = ["L", "Date", "Details", "Drawing", "Flags", "R"]

# Matches dates like "27 Jan 2026", "01 Feb 2026", "8 Jan 2026"
_DATE_RE = re.compile(r"^\d{1,2}\s+[A-Za-z]{3,9}\s+\d{4}$")

# Matches clinician initials in the Date column (content rows)
_INITIALS_RE = re.compile(r"^[A-Z]{2,4}$")

# Header details: "HH:MM - Location: SURNAME, Forename (Role)"
# Location can be multi-part e.g. "Office Base, NIGHT SUMMARY" or "Other, Onyx Ward"
_HEADER_RE = re.compile(
    r"^(\d{1,2}:\d{2})\s*-\s*(.+?):\s*"
    r"([A-Z][A-Za-z\'-]+),\s*"
    r"([A-Za-z]+(?:\s+[A-Za-z]+)?)\s*"
    r"\((.+?)\)"
)

# Activity-only lines
_ACTIVITY_RE = re.compile(r"^\s*Activity:\s+")

# Administrative skip patterns (start of Details)
_ADMIN_STARTS = [
    "Referral allocation",
    "Referral In:",
    "Address Changed From:",
    "Current Home Address:",
    "Previous Home Address:",
    "Home telephone number:",
    "Acrobat Document:",
    "Scheduled Task Creation",
    "Amendment via PDS",
]

_ADMIN_CONTAINS = [
    "Record Sharing consent",
]


# ----------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------

def _clean(value) -> str:
    if value is None:
        return ""
    s = str(value).strip()
    if not s or s.lower() in {"nan", "nat", "<na>", "none"}:
        return ""
    return s


def _parse_date(date_str: str) -> Optional[datetime]:
    """Parse SystmOne date format: 'DD Mon YYYY' or 'DD Month YYYY'."""
    s = _clean(date_str)
    if not s:
        return None
    # Quick reject: must look like a date, not initials
    if _INITIALS_RE.match(s):
        return None

    for fmt in ("%d %b %Y", "%d %B %Y"):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            pass
    return None


def _extract_clinician(details: str) -> Tuple[Optional[str], Optional[str], Optional[str]]:
    """Extract (time_str, clinician_name, location) from header row Details.

    Returns (None, None, None) if the pattern doesn't match.
    """
    m = _HEADER_RE.match(details.strip())
    if not m:
        return None, None, None
    time_str = m.group(1)
    location = m.group(2).strip().rstrip(",")
    surname = m.group(3).strip()
    forename = m.group(4).strip()
    clinician = f"{forename} {surname.title()}"
    return time_str, clinician, location


def _is_administrative(details: str) -> bool:
    """Return True for rows that should be skipped entirely."""
    s = details.strip()
    if not s:
        return True
    for prefix in _ADMIN_STARTS:
        if s.startswith(prefix):
            return True
    for fragment in _ADMIN_CONTAINS:
        if fragment in s:
            return True
    return False


def _is_activity_only(details: str) -> bool:
    """Return True if the content is only an activity line with no clinical substance."""
    return bool(_ACTIVITY_RE.match(details))


def _extract_encounter_type(text: str) -> str:
    """Extract the Encounter type field value from structured note text."""
    m = re.search(r"Encounter\s+type:\s*(.+?)(?:\n|$)", text)
    if m:
        return m.group(1).strip()
    return ""


def _canonical_type(raw: str) -> str:
    """Map encounter type text to a canonical note type."""
    s = (raw or "").lower().strip()
    if not s:
        return "SystmOne"
    if "night" in s:
        return "Night Note"
    if "day" in s:
        return "Day Note"
    if "incident" in s:
        return "Incident"
    if "section 132" in s:
        return "Section 132"
    if "1:1" in s or "one to one" in s:
        return "1:1"
    if "sansi" in s:
        return "SANSI"
    if "telephone" in s:
        return "Telephone"
    if "ward round" in s:
        return "Ward Round"
    if "cpa" in s:
        return "CPA"
    if "daily note" in s:
        return "Day Note"
    if "clinical note" in s:
        return "Clinical Note"
    if "face to face" in s:
        return "Clinical Note"
    return raw.strip() or "SystmOne"


def _detect_note_type(text: str) -> str:
    """Determine the note type from the full clinical note text."""
    # First try Encounter type field
    encounter = _extract_encounter_type(text)
    if encounter:
        return _canonical_type(encounter)

    # Check for template headers
    first_line = text.strip().split("\n")[0].strip().lower() if text.strip() else ""
    if "daily" in first_line and "note" in first_line:
        return "Day Note"
    if "section 132" in first_line:
        return "Section 132"
    if "clinical note" in first_line:
        return "Clinical Note"

    return "SystmOne"


# ----------------------------------------------------------------
# Format detection
# ----------------------------------------------------------------

def is_systmone_csv(path: str) -> bool:
    """Check if a CSV file is in SystmOne format by examining the header."""
    try:
        for enc in ("utf-8", "cp1252", "latin-1"):
            try:
                with open(path, "r", encoding=enc) as f:
                    reader = csv.reader(f)
                    header = next(reader, None)
                    if header and [h.strip() for h in header] == SYSTMONE_HEADER:
                        return True
                    return False
            except UnicodeDecodeError:
                continue
    except Exception:
        pass
    return False


# ----------------------------------------------------------------
# CSV parsing
# ----------------------------------------------------------------

def _parse_csv_rows(path: str) -> List[List[str]]:
    """Read a SystmOne CSV and return data rows as lists of 6 strings."""
    rows = []
    for enc in ("utf-8", "cp1252", "latin-1"):
        try:
            with open(path, "r", encoding=enc) as f:
                reader = csv.reader(f)
                header = next(reader, None)  # skip header row
                if not header:
                    return []
                for row in reader:
                    # Pad short rows, trim long ones
                    while len(row) < 6:
                        row.append("")
                    rows.append([_clean(c) for c in row[:6]])
            return rows
        except UnicodeDecodeError:
            continue
    return rows


# ----------------------------------------------------------------
# RTF parsing
# ----------------------------------------------------------------

def _strip_rtf_cell(text: str) -> str:
    """Strip RTF control words from a cell's content, preserving readable text."""
    # Replace \par with newlines
    text = re.sub(r"\\par\b\s?", "\n", text)
    # Handle RTF unicode escapes \uNNNN?
    def _unicode_replace(m):
        code = int(m.group(1))
        if code < 0:
            code += 65536
        try:
            return chr(code)
        except (ValueError, OverflowError):
            return ""
    text = re.sub(r"\\u(-?\d+)[?]?", _unicode_replace, text)
    # Remove \' hex escapes
    def _hex_replace(m):
        try:
            return bytes.fromhex(m.group(1)).decode("cp1252")
        except Exception:
            return ""
    text = re.sub(r"\\'([0-9a-fA-F]{2})", _hex_replace, text)
    # Remove RTF control words (e.g. \hich, \af1, \dbch, \loch, \f1, \fs20, etc.)
    text = re.sub(r"\\[a-zA-Z]+[-]?\d*\s?", " ", text)
    # Remove braces
    text = re.sub(r"[{}]", "", text)
    # Collapse whitespace (but preserve newlines)
    lines = text.split("\n")
    lines = [re.sub(r"[ \t]+", " ", line).strip() for line in lines]
    return "\n".join(lines).strip()


def _parse_rtf_to_rows(path: str) -> List[List[str]]:
    """Parse SystmOne RTF table into the same 6-column row format as CSV."""
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        raw = f.read()

    # Split by \row to get table rows
    rtf_rows = re.split(r"\\row\b", raw)

    result = []
    for rtf_row in rtf_rows:
        # Split by \cell to get cells
        cells_raw = re.split(r"\\cell\b", rtf_row)
        # Need at least 6 cells (plus trailing formatting segment)
        if len(cells_raw) < 7:
            continue

        cells = []
        for cell_raw in cells_raw[:6]:
            cells.append(_strip_rtf_cell(cell_raw))
        result.append(cells)

    # Skip title row and header row
    # Row 0: "Patient Record - Local Data: ..."
    # Row 1: "L", "Date", "Details", "Drawing", "Flags", "R"
    # Row 2: empty separator
    skip = 0
    for i, row in enumerate(result):
        # Find the header row by looking for "Date" and "Details"
        if any("Date" in c for c in row) and any("Details" in c for c in row):
            skip = i + 1
            break
    if skip > 0 and skip < len(result):
        result = result[skip:]

    # Skip any initial empty separator row
    while result and all(not c.strip() for c in result[0]):
        result = result[1:]

    return result


# ----------------------------------------------------------------
# Row grouping — shared logic for CSV and RTF
# ----------------------------------------------------------------

def _group_entries(rows: List[List[str]]) -> List[Dict]:
    """Group parsed rows into logical note entries.

    Each entry starts with a header row (has a date), followed by
    a content row (clinician initials + note text), and optionally
    continuation rows with extra content.
    """
    entries: List[Dict] = []
    current: Optional[Dict] = None

    for row in rows:
        l_col, date_col, details, drawing, flags, r_col = row
        date_str = date_col.strip()
        details = details.strip()
        flags = flags.strip()

        # Skip completely empty rows
        if not date_str and not details and not flags:
            continue
        # Skip rows that are only "No medical drawings" filler
        if not date_str and not details and not flags:
            continue

        # --- HEADER ROW: has a parseable date ---
        dt = _parse_date(date_str)
        if dt is not None:
            # Flush previous entry
            if current and current["text"].strip():
                entries.append(current)

            time_str, clinician, location = _extract_clinician(details)

            # Combine date + time
            if time_str:
                try:
                    t = datetime.strptime(time_str, "%H:%M").time()
                    dt = datetime.combine(dt.date(), t)
                except ValueError:
                    pass

            current = {
                "date": dt,
                "clinician": clinician or "",
                "location": location or "",
                "header_details": details,
                "flags": flags,
                "text": "",
            }
            continue

        # --- CONTENT ROW: clinician initials in date column ---
        if _INITIALS_RE.match(date_str) and current is not None:
            if _is_administrative(details):
                continue
            if _is_activity_only(details):
                continue
            if details:
                if not current["text"]:
                    current["text"] = details
                else:
                    current["text"] += "\n" + details
            continue

        # --- CONTINUATION ROW: empty date, has details ---
        if not date_str and details and current is not None:
            if _is_administrative(details):
                continue
            if _is_activity_only(details):
                continue
            if details:
                current["text"] += "\n" + details
            continue

    # Flush last entry
    if current and current["text"].strip():
        entries.append(current)

    return entries


# ----------------------------------------------------------------
# Convert to standard note dicts
# ----------------------------------------------------------------

def _entries_to_notes(entries: List[Dict], source_path: str) -> List[Dict]:
    """Convert grouped entries to the standard note format used by the app."""
    notes = []
    for entry in entries:
        text = entry["text"].strip()
        if not text:
            continue

        note_type = _detect_note_type(text)

        notes.append({
            "date": entry["date"],
            "type": note_type,
            "originator": entry["clinician"],
            "text": text,
            "content": text,
            "source": "systmone",
            "source_file": str(source_path),
        })

    return notes


# ----------------------------------------------------------------
# Public entry points
# ----------------------------------------------------------------

def parse_systmone_csv(path: str) -> List[Dict]:
    """Parse a SystmOne CSV export and return a list of note dicts."""
    path = str(Path(path))
    print(f"[SYSTMONE] CSV loading → {path}")
    rows = _parse_csv_rows(path)
    entries = _group_entries(rows)
    notes = _entries_to_notes(entries, path)
    print(f"[SYSTMONE] CSV parsed: {len(notes)} clinical notes from {len(rows)} rows")
    return notes


def parse_systmone_rtf(path: str) -> List[Dict]:
    """Parse a SystmOne RTF export and return a list of note dicts."""
    path = str(Path(path))
    print(f"[SYSTMONE] RTF loading → {path}")
    rows = _parse_rtf_to_rows(path)
    entries = _group_entries(rows)
    notes = _entries_to_notes(entries, path)
    print(f"[SYSTMONE] RTF parsed: {len(notes)} clinical notes from {len(rows)} rows")
    return notes
