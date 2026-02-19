from __future__ import annotations

from pathlib import Path
from typing import List, Dict
from datetime import datetime
import pandas as pd
import re
from utils.resource_path import resource_path


def looks_like_carenotes_report(df: pd.DataFrame) -> bool:
    if df.shape[1] < 2:
        return False

    sample = (
        df.iloc[:200, :].astype(str).fillna("")
        .agg(" ".join, axis=1)
        .str.lower()
    )

    markers = [
        "night note entry",
        "keeping well",
        "keeping safe",
        "keeping healthy",
        "keeping connected",
    ]

    return any(any(m in row for m in markers) for row in sample)

def split_report_blocks(lines: list[str]) -> list[list[str]]:
    blocks = []
    current = []

    for ln in lines:
        low = ln.lower()

        if (
            "night note entry" in low
            or "day note entry" in low
        ):
            if current:
                blocks.append(current)
            current = [ln]
        else:
            current.append(ln)

    if current:
        blocks.append(current)

    return blocks

# ============================================================
# DATE + TIME PATTERNS
# ============================================================

DATE_RE1 = re.compile(r"^\d{1,2}/\d{1,2}/\d{4}$")                   # dd/mm/yyyy
DATE_RE2 = re.compile(r"^\d{4}-\d{2}-\d{2}$")                       # yyyy-mm-dd
DATE_RE3 = re.compile(r"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?$")  # yyyy-mm-dd HH:MM[:SS]
TIME_RE  = re.compile(r"^\d{1,2}:\d{2}(:\d{2})?$")                  # 06:21 or 06:21:00

def is_date(s: str) -> bool:
    if not isinstance(s, str):
        return False
    s = s.strip()
    return DATE_RE1.match(s) or DATE_RE2.match(s) or DATE_RE3.match(s)


# ============================================================
# SIGNATURE DETECTOR (bottom-most)
# ============================================================

SIG_RE = re.compile(
    r"-{2,}.*?([A-Za-z .'-]+?)\s*,\s*,\s*(\d{1,2}/\d{1,2}/\d{4}|\d{4}-\d{2}-\d{2})"
)


def clean(s):
    if s is None:
        return ""
    s = str(s).strip()
    if s.lower() in {"nan", "none", "<na>", "nat"}:
        return ""
    return s


# ============================================================
# CANONICAL TYPE (matches RIO type logic)
# ============================================================

def canonical_type(raw: str) -> str:
    s = (raw or "").lower()
    if "nurs" in s:
        return "Nursing"
    if "medic" in s or "doctor" in s:
        return "Medical"
    if "social" in s:
        return "Social Work"
    if "psycholog" in s:
        return "Psychology"
    if "occup" in s or "ot" in s:
        return "Occupational Therapy"
    if "admin" in s:
        return "Admin"
    return raw or "CareNotes"

def parse_carenotes_report(df: pd.DataFrame, path: str) -> List[Dict]:
    print("[CARENOTES] REPORT PARSER USED")
    # ------------------------------------
    # TYPE = first non-empty cell in col 2
    # ------------------------------------
    note_type = "CareNotes"
    for i in range(min(5, len(df))):
        val = clean(df.iloc[i, 1])
        if val:
            note_type = val
            break

    # ------------------------------------
    # ORIGINATOR = first name-like cell in col 1
    # ------------------------------------
    originator = "Unknown"
    for i in range(min(5, len(df))):
        val = clean(df.iloc[i, 0])
        if val and not is_date(val) and not TIME_RE.match(val) and val.lower() != "confirmed":
            originator = val
            break

    content_lines = []
    note_date = None
    note_time = None

    # ------------------------------------
    # BODY + DATE/TIME
    # ------------------------------------
    for i in range(len(df)):
        left = clean(df.iloc[i, 0])
        right = clean(df.iloc[i, 1])

        if left and is_date(left):
            note_date = left
            continue

        if left and TIME_RE.match(left):
            note_time = left
            continue

        if left.lower().startswith("confirmed"):
            break

        if right:
            content_lines.append(right)

    # ------------------------------------
    # DATETIME
    # ------------------------------------
    dt = None
    if note_date and note_time:
        try:
            dt = datetime.strptime(
                f"{note_date} {note_time}",
                "%d/%m/%Y %H:%M"
            )
        except Exception:
            pass

    text = "\n".join(content_lines).strip()

    preview = " ".join(content_lines[:3])
    if len(preview) > 200:
        preview = preview[:197] + "…"

    return [{
        "date": dt,
        "type": canonical_type(note_type),
        "originator": originator,
        "preview": preview,
        "text": text,
        "source": "carenotes",
        "source_file": path,
    }]
def flatten_rows(df) -> list[str]:
    lines = []
    for _, row in df.iterrows():
        parts = []
        for cell in row:
            s = clean(cell)
            if s:
                parts.append(s)
        if parts:
            lines.append(" ".join(parts))
    return lines

# ============================================================
# MAIN PARSER — matches RIO structure EXACTLY
# ============================================================

def parse_carenotes_file(path: str) -> List[Dict]:
    print("[CARENOTES] Loading →", path)


    df = pd.read_excel(path, header=None, dtype=str)
    print("[CARENOTES] DF SHAPE:", df.shape)
    if looks_like_carenotes_report(df):
        print("[CARENOTES] REPORT PARSER USED (BULK MODE)")

        lines = flatten_rows(df)
        blocks = split_report_blocks(lines)

        notes = []

        for block in blocks:
                raw_type = block[0]
                originator = "Unknown"
                note_date = None
                note_time = None
                content = []

                m = re.search(
                    r"(night|day|evening)\s+note\s+entry",
                    raw_type,
                    re.IGNORECASE
                )
                if m:
                    note_type = canonical_type(m.group(0))
                else:
                    note_type = canonical_type(raw_type)

                for ln in block[1:]:
                    low = ln.lower()

                    if "confirmed" in low:
                        break

                    if not note_date and is_date(ln):
                        note_date = ln
                        continue

                    if not note_time and TIME_RE.match(ln):
                        note_time = ln
                        continue

                    if originator == "Unknown":
                        if (
                            len(ln.split()) <= 4
                            and any(w[0].isupper() for w in ln.split())
                            and not any(
                                k in low
                                for k in [
                                    "keeping",
                                    "note",
                                    "entry",
                                    "observed",
                                    "appeared",
                                ]
                            )
                        ):
                            originator = ln
                            continue

                    content.append(ln)

                if not (note_date and note_time):
                    continue

                try:
                    dt = datetime.strptime(
                        f"{note_date} {note_time}",
                        "%d/%m/%Y %H:%M"
                    )
                except Exception:
                    continue

                text = "\n".join(content).strip()
                if not text:
                    continue

                preview = " ".join(content[:3]).strip()
                if len(preview) > 200:
                    preview = preview[:197] + "…"

                notes.append({
                    "date": dt,
                    "type": note_type,
                    "originator": originator,
                    "preview": preview,
                    "text": text,
                    "source": "carenotes",
                    "source_file": path,
                })



    # --------------------------------------------------------
    # Flatten: each non-empty cell becomes a separate line
    # --------------------------------------------------------
    lines: List[str] = []
    for _, row in df.iterrows():
        for cell in row:
            s = clean(cell)
            if s and s.lower() not in {"detail", "amend", "lock"}:
                lines.append(s)

    # Collect pre-note header lines (demographics / patient details)
    # A "real note" is a date with a time within the next 5 lines.
    # System/UI dates (e.g. diary date fields) won't have a nearby time.
    _header_lines = []
    for _idx, _ln in enumerate(lines):
        if is_date(_ln):
            _has_nearby_time = False
            for _jj in range(_idx + 1, min(_idx + 6, len(lines))):
                if TIME_RE.match(lines[_jj]):
                    _has_nearby_time = True
                    break
            if _has_nearby_time:
                break
        _header_lines.append(_ln)
    _demographics_header = "\n".join(_header_lines) if _header_lines else ""
    if _demographics_header:
        print(f"[CARENOTES] Captured demographics header ({len(_header_lines)} lines, {len(_demographics_header)} chars)")

    notes: List[Dict] = []
    n = len(lines)
    i = 0

    while i < n:
        line = lines[i]

        # ----------------------------------------------------
        # DETECT DATE
        # ----------------------------------------------------
        if is_date(line):

            # Find time on next lines (must be within 5 lines)
            j = i + 1
            max_j = min(i + 6, n)
            while j < max_j and not TIME_RE.match(lines[j]):
                j += 1
            if j >= max_j or not TIME_RE.match(lines[j]):
                i += 1
                continue

            d_str = line
            t_str = lines[j]
            dt = None

            # --- Try date + time parsing
            try:
                if "/" in d_str:
                    dt = datetime.strptime(d_str + " " + t_str, "%d/%m/%Y %H:%M:%S")
                else:
                    base = d_str.split()[0]
                    dt = datetime.strptime(base + " " + t_str, "%Y-%m-%d %H:%M:%S")
            except:
                try:
                    if "/" in d_str:
                        dt = datetime.strptime(d_str + " " + t_str, "%d/%m/%Y %H:%M")
                    else:
                        base = d_str.split()[0]
                        dt = datetime.strptime(base + " " + t_str, "%Y-%m-%d %H:%M")
                except:
                    dt = None

            if not dt:
                i += 1
                continue

            # ----------------------------------------------------
            # COLLECT BODY (until next date)
            # ----------------------------------------------------
            body = []
            k = j + 1
            while k < n and not is_date(lines[k]):
                body.append(lines[k])
                k += 1

            # ----------------------------------------------------
            # SIGNATURE SEARCH (last matching line)
            # ----------------------------------------------------
            originator = "Unknown"
            signature_line = None

            for ln in reversed(body):
                m = SIG_RE.search(ln)
                if m:
                    originator = m.group(1).strip()
                    signature_line = ln
                    break

            # ----------------------------------------------------
            # CLEAN BODY (remove signature line only)
            # ----------------------------------------------------
            if signature_line:
                cleaned_body = [ln for ln in body if ln != signature_line]
            else:
                cleaned_body = body

            text = "\n".join(cleaned_body).strip()

            # ----------------------------------------------------
            # CANONICAL TYPE
            # ----------------------------------------------------
            note_type = "CareNotes"

            for ln in cleaned_body:
                if ln:
                    if ":" in ln:
                        note_type = ln.split(":", 1)[0].strip()
                    else:
                        note_type = ln.strip()
                    break

            note_type = canonical_type(note_type)

            # ----------------------------------------------------
            # PREVIEW (required by PatientNotesPanel)
            # ----------------------------------------------------
            preview = " ".join(text.split("\n")[:3]).strip()
            if len(preview) > 200:
                preview = preview[:197] + "…"

            # ----------------------------------------------------
            # STORE FINAL NOTE (RIO-compatible)
            # ----------------------------------------------------
            if text:
                notes.append(
                    {
                        "date": dt,
                        "type": note_type,
                        "originator": originator,
                        "preview": preview,
                        "text": text,
                        "source": "carenotes",
                        "source_file": path,
                    }
                )

            i = k
            continue

        i += 1

    # Attach demographics header to first note for patient detail extraction
    if notes and _demographics_header:
        notes[0]["demographics_header"] = _demographics_header

    print("[CARENOTES] Final parsed notes:", len(notes))
    return notes
