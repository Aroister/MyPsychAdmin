from __future__ import annotations

from typing import List, Dict
from datetime import datetime
import pandas as pd
import re


# ============================================================
# EPJS DATE + TIME (same line)
# ============================================================
EPJS_DATETIME_RE = re.compile(
    r"""
    ^(?P<date>
        \d{1,2}                 # day
        \s+[A-Za-z]{3}          # month name (Aug)
        \s+\d{4}                # year
    )
    \s+
    (?P<time>\d{1,2}:\d{2})     # HH:MM
    $
    """,
    re.VERBOSE
)

# ------------------------------------------------------------
# CareNotes-style signature (fallback)
# ------------------------------------------------------------
SIG_RE = re.compile(
    r"-{2,}.*?([A-Za-z .'-]+?)\s*,\s*,\s*"
    r"(\d{1,2}/\d{1,2}/\d{4}|\d{4}-\d{2}-\d{2})"
)

# ------------------------------------------------------------
# Footer signature:
# 30 Aug 2025 19:21, John Smith
# ------------------------------------------------------------
EPJS_SIGNATURE_RE = re.compile(
    r"""
    -+                     # leading dashes
    \s*
    (?P<date>\d{1,2}\s+[A-Za-z]{3}\s+\d{4})
    \s+
    (?P<time>\d{1,2}:\d{2})
    \s*,\s*
    (?P<name>[^,]+)
    """,
    re.VERBOSE
)
CONFIRMED_BY_RE = re.compile(
    r"Confirmed By\s+(?P<name>.+?),\s*\d{1,2}/\d{1,2}/\d{4}",
    re.IGNORECASE
)

# ------------------------------------------------------------
# "-----Confirmed By NAME, dd/mm/yyyy" (dashed END boundary)
# ------------------------------------------------------------
CONFIRMED_BY_SIG_RE = re.compile(
    r"-{5,}\s*Confirmed By\s+(?P<name>[^,]+),\s*(?P<date>\d{1,2}/\d{1,2}/\d{4})",
    re.IGNORECASE
)

# ------------------------------------------------------------
# Standalone "dd/mm/yyyy HH:MM[:SS]" on its own line
# ------------------------------------------------------------
DATETIME_DMY_RE = re.compile(
    r"^(?P<date>\d{1,2}/\d{1,2}/\d{4})\s+(?P<time>\d{1,2}:\d{2}(?::\d{2})?)$"
)

# ------------------------------------------------------------
# ISO datetime: "yyyy-mm-dd HH:MM[:SS]" on its own line
# ------------------------------------------------------------
DATETIME_ISO_RE = re.compile(
    r"^(?P<date>\d{4}-\d{2}-\d{2})\s+(?P<time>\d{1,2}:\d{2}(?::\d{2})?)$"
)

# ------------------------------------------------------------
# Merged Excel: "dd/mm/yyyy HH:MM[:SS] rest of content"
# ------------------------------------------------------------
DATE_START_WITH_TIME_RE = re.compile(
    r"^(\d{1,2}/\d{1,2}/\d{4})\s+(\d{1,2}:\d{2}(?::\d{2})?)\s+(.+)"
)
DATE_START_NO_TIME_RE = re.compile(
    r"^(\d{1,2}/\d{1,2}/\d{4})\s+(.+)"
)

# ------------------------------------------------------------
# EPJS "Originator: NAME" line
# ------------------------------------------------------------
ORIGINATOR_RE = re.compile(r"^Originator:\s*(?P<name>.+)", re.IGNORECASE)

# Metadata lines to skip
METADATA_PREFIXES = ("event by", "entered by", "amended by", "locked by",
                     "detail", "amend", "lock", "actionsoverview")


# ============================================================
# HELPERS
# ============================================================
def clean(s):
    if s is None:
        return ""
    s = str(s).strip()
    if s.lower() in {"nan", "none", "<na>"}:
        return ""
    return s


def canonical_type(raw: str) -> str:
    s = (raw or "").lower()
    if "nurs" in s:
        return "Nursing"
    if "medic" in s or "doctor" in s:
        return "Medical"
    if "psych" in s:
        return "Psychology"
    return "EPJS"

# ============================================================
# DATE + TIME PATTERNS (EPJS UI SCRAPE)
# ============================================================

DATE_RE1 = re.compile(r"^\d{1,2}/\d{1,2}/\d{4}$")                   # dd/mm/yyyy
DATE_RE2 = re.compile(r"^\d{4}-\d{2}-\d{2}$")                       # yyyy-mm-dd
DATE_RE3 = re.compile(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?$")  # yyyy-mm-dd HH:MM[:SS]
TIME_RE  = re.compile(r"^\d{1,2}:\d{2}(:\d{2})?$")                  # 06:21 or 06:21:00


def is_date(s: str) -> bool:
    if not isinstance(s, str):
        return False
    s = s.strip()
    return (
        DATE_RE1.match(s)
        or DATE_RE2.match(s)
        or DATE_RE3.match(s)
    )

# ============================================================
# MAIN PARSER
# ============================================================
def parse_epjs_file(path: str) -> List[Dict]:
    print("[EPJS] Loading →", path)

    df = pd.read_excel(path, header=None, dtype=str)

    # --------------------------------------------------------
    # Flatten: each non-empty cell becomes a separate line
    # --------------------------------------------------------
    lines: List[str] = []
    for _, row in df.iterrows():
        for cell in row:
            s = clean(cell)
            if s:
                lines.append(s)

    notes: List[Dict] = []
    n = len(lines)
    i = 0

    # --------------------------------------------------------
    # State for 9-step boundary detection
    # --------------------------------------------------------
    current_date = None
    current_body: List[str] = []
    current_originator = ""

    def _parse_dt(d_str, t_str=None):
        """Parse date string (+ optional time) into datetime."""
        if t_str:
            combined = d_str + " " + t_str
        else:
            combined = d_str
        for fmt in ("%d/%m/%Y %H:%M:%S", "%d/%m/%Y %H:%M", "%d/%m/%Y",
                     "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M", "%Y-%m-%d"):
            try:
                return datetime.strptime(combined, fmt)
            except ValueError:
                continue
        # EPJS date format: "17 Feb 2024 14:30"
        for fmt in ("%d %b %Y %H:%M", "%d %b %Y"):
            try:
                return datetime.strptime(combined, fmt)
            except ValueError:
                continue
        return None

    def save_current_note():
        nonlocal current_date, current_body, current_originator
        if not current_body:
            return
        if current_date is None:
            current_body.clear()
            current_originator = ""
            return  # No-date guard: skip pre-header metadata

        # Clean body: remove "confirmed by" and dash-only lines
        cleaned = [ln for ln in current_body
                   if "confirmed by" not in ln.lower()
                   and not (ln.startswith("---") and ln.replace("-", "").strip() == "")]
        text = "\n".join(cleaned).strip()
        if not text:
            current_body.clear()
            current_originator = ""
            return

        # Extract author if not set (3-tier: EPJS sig → Confirmed By → CareNotes sig)
        author = current_originator
        if not author:
            for ln in current_body:
                m = EPJS_SIGNATURE_RE.search(ln)
                if m:
                    author = m.group("name").strip()
                    break
                m = CONFIRMED_BY_RE.search(ln)
                if m:
                    author = m.group("name").strip()
                    break
                m = SIG_RE.search(ln)
                if m:
                    author = m.group(1).strip()
                    break

        # Extract note type from first non-empty cleaned line
        raw_type = "EPJS"
        for ln in cleaned:
            if ln.strip():
                # EPJS bracket type: "[ Nursing - Ward Nurse ]"
                stripped = ln.strip()
                if stripped.startswith("[") and "]" in stripped:
                    raw_type = stripped[1:stripped.index("]")].strip()
                elif ":" in stripped:
                    raw_type = stripped.split(":", 1)[0].strip()
                else:
                    raw_type = stripped
                break
        note_type = canonical_type(raw_type)

        # Preview
        preview = " ".join(text.split("\n")[:3]).strip()
        if len(preview) > 200:
            preview = preview[:197] + "…"

        notes.append({
            "date": current_date,
            "type": note_type,
            "raw_type": raw_type,
            "originator": author or "Unknown",
            "preview": preview,
            "text": text,
            "source": "epjs",
            "source_file": path,
        })

        current_body.clear()
        current_originator = ""

    # --------------------------------------------------------
    # Main 9-step boundary detection loop
    # --------------------------------------------------------
    while i < n:
        trimmed = lines[i].strip()
        if not trimmed:
            i += 1
            continue

        # --- Step 1: "-----Confirmed By NAME, dd/mm/yyyy" → END boundary ---
        m = CONFIRMED_BY_SIG_RE.match(trimmed)
        if m:
            author = m.group("name").strip()
            date_str = m.group("date")
            dt = _parse_dt(date_str)
            if dt:
                current_originator = author
                save_current_note()
                # Carry forward date (for ward round sub-sections)
                current_date = dt
            i += 1
            continue

        # --- Step 2: EPJS dashed signature "----17 Feb 2024 14:30, Name" → END boundary ---
        m = EPJS_SIGNATURE_RE.match(trimmed)
        if m:
            author = m.group("name").strip()
            dt = _parse_dt(m.group("date"), m.group("time"))
            if dt:
                current_originator = author
                save_current_note()
                current_date = dt
            i += 1
            continue

        # --- Step 3a: Standalone "dd/mm/yyyy HH:MM[:SS]" → START boundary ---
        m = DATETIME_DMY_RE.match(trimmed)
        if m:
            dt = _parse_dt(m.group("date"), m.group("time"))
            if dt:
                save_current_note()
                current_date = dt
            i += 1
            continue

        # --- Step 3b: ISO "yyyy-mm-dd HH:MM[:SS]" → START boundary ---
        m = DATETIME_ISO_RE.match(trimmed)
        if m:
            dt = _parse_dt(m.group("date"), m.group("time"))
            if dt:
                save_current_note()
                current_date = dt
            i += 1
            continue

        # --- Step 4: Date at start with content after (merged Excel columns) ---
        #     ONLY when body is empty (start of new note)
        if not current_body:
            m = DATE_START_WITH_TIME_RE.match(trimmed)
            if m:
                dt = _parse_dt(m.group(1), m.group(2))
                if dt:
                    save_current_note()
                    current_date = dt
                    current_body.append(m.group(3).strip())
                    i += 1
                    continue

            m = DATE_START_NO_TIME_RE.match(trimmed)
            if m:
                dt = _parse_dt(m.group(1))
                if dt:
                    save_current_note()
                    current_date = dt
                    current_body.append(m.group(2).strip())
                    i += 1
                    continue

        # --- Step 5: Date-only line + time on next line ---
        if is_date(trimmed):
            # Lookahead max 3 lines for time
            found_time = False
            for offset in range(1, min(4, n - i)):
                peek = lines[i + offset].strip()
                if not peek:
                    continue
                if TIME_RE.match(peek):
                    dt = _parse_dt(trimmed, peek)
                    if dt:
                        save_current_note()
                        current_date = dt
                        i = i + offset + 1
                        found_time = True
                    break
                break  # Non-empty, non-time line → stop lookahead

            if found_time:
                continue

            # No time found
            if not current_body:
                # Body empty → set date only (no boundary)
                dt = _parse_dt(trimmed)
                if dt:
                    current_date = dt
                i += 1
                continue
            # Body has content → fall through to content (historical date in text)

        # --- Step 6: EPJS_DATETIME_RE "17 Feb 2024 14:30" → START boundary ---
        m = EPJS_DATETIME_RE.match(trimmed)
        if m:
            dt = _parse_dt(m.group("date"), m.group("time"))
            if dt:
                save_current_note()
                current_date = dt
            i += 1
            continue

        # --- Step 7a: Plain "Confirmed By NAME, date" (no dashes) → extract author, skip ---
        m = CONFIRMED_BY_RE.match(trimmed)
        if m:
            current_originator = m.group("name").strip()
            i += 1
            continue

        # --- Step 7b: "Originator: NAME" → save previous note, set author for next ---
        m = ORIGINATOR_RE.match(trimmed)
        if m:
            save_current_note()
            current_originator = m.group("name").strip()
            i += 1
            continue

        # --- Step 8: Skip metadata lines (label + value on next line) ---
        low = trimmed.lower()
        if low in METADATA_PREFIXES or low.startswith(
                ("event by", "entered by", "amended by", "locked by")):
            i += 1
            # Also skip the metadata VALUE on the next line (e.g. "Entered By" / "System Admin")
            if low.startswith(("event by", "entered by", "amended by", "locked by")):
                while i < n and lines[i].strip() and not is_date(lines[i].strip()):
                    peek = lines[i].strip()
                    # Stop if next line is itself a metadata label or boundary
                    if peek.lower() in METADATA_PREFIXES or peek.lower().startswith(
                            ("event by", "entered by", "amended by", "locked by")):
                        break
                    if CONFIRMED_BY_SIG_RE.match(peek) or EPJS_SIGNATURE_RE.match(peek):
                        break
                    if DATETIME_DMY_RE.match(peek) or EPJS_DATETIME_RE.match(peek):
                        break
                    i += 1
                    break  # Skip only ONE value line
            continue

        # --- Step 9: Skip dash-only lines ---
        if trimmed.replace("-", "").replace(" ", "") == "":
            i += 1
            continue

        # --- Step 10: Regular content → append to body ---
        current_body.append(trimmed)
        i += 1

    # Save final note
    save_current_note()

    print("[EPJS] Final parsed notes:", len(notes))
    return notes
