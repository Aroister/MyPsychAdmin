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
            if s and s.lower() not in {"detail", "amend", "lock"}:
                lines.append(s)

    notes: List[Dict] = []
    n = len(lines)
    i = 0

    while i < n:
        line = lines[i]

        # ----------------------------------------------------
        # DETECT DATE (IDENTICAL TO CARENOTES)
        # ----------------------------------------------------
        if is_date(line):

            # Find time on next lines
            j = i + 1
            while j < n and not TIME_RE.match(lines[j]):
                j += 1
            if j >= n:
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
            # EPJS + CARENOTES SIGNATURE SEARCH
            # ----------------------------------------------------
            originator = "Unknown"
            signature_line = None

            # -----------------------------------------
            # 1️⃣ Prefer EPJS dashed author line
            # -----------------------------------------
            for ln in body:
                m = re.search(
                    r"-+\s*\d{1,2}\s+[A-Za-z]{3}\s+\d{4}\s+\d{1,2}:\d{2},\s*(.+)",
                    ln
                )
                if m:
                    originator = m.group(1).strip()
                    signature_line = ln
                    break

            # -----------------------------------------
            # 2️⃣ Fallback → Confirmed By
            # -----------------------------------------
            if originator == "Unknown":
                for ln in body:
                    m = re.search(r"Confirmed By\s+([^,]+)", ln, re.IGNORECASE)
                    if m:
                        originator = m.group(1).strip()
                        signature_line = ln
                        break

            # -----------------------------------------
            # 3️⃣ Fallback → CareNotes signature
            # -----------------------------------------
            if originator == "Unknown":
                for ln in body:
                    m = SIG_RE.search(ln)
                    if m:
                        originator = m.group(1).strip()
                        signature_line = ln
                        break


            # ----------------------------------------------------
            # CLEAN BODY (remove EPJS + CN footer lines)
            # ----------------------------------------------------
            cleaned_body = [
                ln for ln in body
                if ln != signature_line
                and "confirmed by" not in ln.lower()
                and "---" not in ln
            ]

            text = "\n".join(cleaned_body).strip()

            # ----------------------------------------------------
            # CANONICAL TYPE (IDENTICAL TO CARENOTES)
            # ----------------------------------------------------
            note_type = "EPJS"
            for ln in cleaned_body:
                if ln:
                    if ":" in ln:
                        note_type = ln.split(":", 1)[0].strip()
                    else:
                        note_type = ln.strip()
                    break

            note_type = canonical_type(note_type)

            # ----------------------------------------------------
            # PREVIEW
            # ----------------------------------------------------
            preview = " ".join(text.split("\n")[:3]).strip()
            if len(preview) > 200:
                preview = preview[:197] + "…"

            # ----------------------------------------------------
            # STORE FINAL NOTE
            # ----------------------------------------------------
            if text:
                notes.append(
                    {
                        "date": dt,
                        "type": note_type,
                        "originator": originator,
                        "preview": preview,
                        "text": text,
                        "source": "epjs",
                        "source_file": path,
                    }
                )

            i = k
            continue

        i += 1

    print("[EPJS] Final parsed notes:", len(notes))
    return notes



