# ================================================================
# importer_rio.py — ORIGINAL + FIXED DATE EXTRACTION
# ================================================================

from __future__ import annotations

from pathlib import Path
from typing import List, Dict
from datetime import datetime
import pandas as pd
from utils.resource_path import resource_path


def _clean_line(value) -> str:
    if value is None:
        return ""
    s = str(value).strip()
    if not s or s.lower() in {"nan", "nat", "<na>", "none"}:
        return ""
    return s


_DATE_FORMATS = [
    "%d/%m/%Y %H:%M",
    "%d/%m/%Y %H:%M:%S",
    "%d/%m/%Y",
    "%Y-%m-%d %H:%M:%S",
    "%Y-%m-%d",
]


def _parse_date(line: str) -> datetime | None:
    line = _clean_line(line)
    if not line:
        return None

    for fmt in _DATE_FORMATS:
        try:
            return datetime.strptime(line, fmt)
        except ValueError:
            pass

    try:
        dt = pd.to_datetime(line, errors="coerce", dayfirst=True)
        if pd.notna(dt):
            return dt.to_pydatetime()
    except Exception:
        pass

    return None


def _canonical_type(type_raw: str) -> str:
    s = (type_raw or "").lower()

    if "nursing" in s:
        return "Nursing"
    if "medical" in s:
        return "Medical"
    if "social" in s:
        return "Social Work"
    if "psycholog" in s:
        return "Psychology"
    if "occupational" in s or "ot " in s:
        return "Occupational Therapy"

    return type_raw or "Unknown"


# --------------------------------------------------------------------
# MAIN PARSER — FIXED TO HANDLE: date on first body line, not second
# --------------------------------------------------------------------
def parse_rio_file(path: str) -> List[Dict]:
    path = str(Path(path))
    print("parse_rio_file →", path)

    df = pd.read_excel(path, header=None, dtype=str)
    lines = [_clean_line(v) for v in df.iloc[:, 0].tolist()]

    notes: List[Dict] = []
    i = 0
    n = len(lines)

    while i < n:
        line = lines[i]
        if not line.startswith("Originator:"):
            i += 1
            continue

        originator = line.split(":", 1)[1].strip() or "Unknown"
        i += 1

        # --------------------------------------------------------
        # FIX: find the first *non-empty* body line containing date
        # --------------------------------------------------------
        while i < n and not lines[i]:
            i += 1
        if i >= n:
            break

        date_line = lines[i]

        dt = _parse_date(date_line)
        if not dt:
            # NEW FIX: try next lines until date found
            j = i + 1
            while j < n and j < i + 5 and not dt:
                dt = _parse_date(lines[j])
                if dt:
                    i = j  # jump to the correct date line
                    break
                j += 1

        i += 1  # move past date

        if not dt:
            continue

        if dt.year < 2000 or dt.year > 2100:
            continue

        body: List[str] = []
        while i < n and not lines[i].startswith("Originator:"):
            body.append(lines[i])
            i += 1

        note_type_raw = ""
        type_seen = False
        content_lines: List[str] = []

        for ln in body:
            s = ln.strip()
            if not s:
                content_lines.append("")
                continue

            # bracket-type
            if not type_seen and s.startswith("[") and s.endswith("]"):
                note_type_raw = s.strip("[] ").strip()
                type_seen = True
                continue

            if s.lower() in {"detail", "amend", "lock"}:
                continue

            content_lines.append(ln)

        content = "\n".join(content_lines).strip()
        if not content:
            continue

        note_type = _canonical_type(note_type_raw)

        preview = " ".join(content.split("\n")[:3]).strip()
        if len(preview) > 200:
            preview = preview[:197] + "…"

        notes.append(
            {
                "date": dt,
                "type": note_type,
                "originator": originator,
                "preview": preview,
                "text": content,       # REQUIRED BY UI
                "source_file": path,
            }
        )

    print("FINAL VALID NOTES AFTER CLEANING:", len(notes))
    return notes
