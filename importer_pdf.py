# ===============================================================
# IMPORTER_PDF_V6.PY — Full OCR + FITZ Hybrid Importer
# ===============================================================
# Features:
#   • Smart OCR merge
#   • Correct DATE1 detection
#   • Multi-page continuation
#   • CareNotes header detection (Option 1B)
#   • Full dedupe of OCR/Fitz overlaps
#   • Zero false Type headings
#   • Headings stay inside body
#   • Clean sorted final notes
# ===============================================================

from __future__ import annotations

import re
import fitz
import pytesseract
import platform
import os
import numpy as np

from PIL import Image
from datetime import datetime
from utils.resource_path import resource_path

# -------------------------
# Tesseract Path Handling
# -------------------------
if platform.system() == "Darwin":
    pytesseract.pytesseract.tesseract_cmd = "/opt/homebrew/bin/tesseract"
else:
    pytesseract.pytesseract.tesseract_cmd = resource_path("resources", "tesseract", "tesseract.exe")



# BODY_HEADERS = [
 #    r"night\s+note", r"night\s+notes", r"night\s+summary", r"night\s+shift",
  #   r"day\s+note", r"day\s+notes", r"day\s+shift", r"day\s+summary",
  #   r"mental\s*state", r"physical\s*health", r"depot", r"depo",
  #   r"medication", r"daily\s*routine", r"key\s*worker",
  #   r"patient\s+activity", r"patient\s+living\s+skill",
   #  r"nursing\s+note", r"nursing\s+notes",
   #  r"adl", r"routine", r"recovery",
   #  r"session\s+name",
   #  r"a\s+call\s+to\s+the\s+sister",
   #  r"communication\s+passport",
   #  r"external\s+professional\s+contact",
  #   r"shower\s+gel",
# ]

# import re
# BODY_HEADER_RES = [re.compile(rf"^{pat}$", re.IGNORECASE) for pat in BODY_HEADERS]

# def is_body_section_title(text: str) -> bool:
  #   t = text.strip().lower()
  #   for rex in BODY_HEADER_RES:
    #     if rex.match(t):
   #          return True
   #  return False

# ---------------------------------------------------------------
# DEBUG printing toggle
# ---------------------------------------------------------------
DEBUG_ENABLED = False

def debug(msg):
    if DEBUG_ENABLED:
        print(msg)

# ---------------------------------------------------------------
# REGEXES
# ---------------------------------------------------------------

# Matches "25/09/2025 14:45" or "25/09/2025 4:41" etc.
DATE1_RE = re.compile(
    r"^(\d{1,2}\/\d{1,2}\/\d{4})\s+(\d{1,2}[:.]\d{2})"
)

# Header-like lines (TYPE candidates).
HEADER_RE = re.compile(
    r"^(Session Name|Physical Health|Patient Activity|Mental State|Day Note|Day Notes|Night Note|Night Notes|Nursing Note|Depot|Activity|Medication|Daily|Court|Routine|Key worker|Mental|Physical)\b",
    re.IGNORECASE,
)

# Remove noise characters commonly seen in OCR.
NOISE_RE = re.compile(r"[•●◦·]")

# ---------------------------------------------------------------
# BASIC UTILITY FUNCTIONS
# ---------------------------------------------------------------

def clean_text(t: str) -> str:
    """Normalises a text line: remove noise, trim, collapse spaces."""
    if not t:
        return ""
    t = NOISE_RE.sub("", t)
    t = t.replace("\u00a0", " ")      # remove non-breaking space
    return re.sub(r"\s+", " ", t).strip()
# ===============================================================
# PART 2 — FITZ TEXT + OCR TEXT + SMART MERGE
# ===============================================================

def get_fitz_text(page) -> str:
    """Extract clean FITZ text from PDF page."""
    try:
        raw = page.get_text("text")
    except Exception as e:
        debug(f"[FITZ] ERROR: {e}")
        return ""

    # Normalise & split into lines
    out = []
    for ln in raw.split("\n"):
        ln = clean_text(ln)
        if ln:
            out.append(ln)

    debug(f"[FITZ] Extracted {len(out)} lines")
    return "\n".join(out)


def ocr_page(page, dpi=200) -> str:
    """Run OCR on a PDF page rendered as an image."""
    try:
        pix = page.get_pixmap(dpi=dpi)
        img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
    except Exception as e:
        debug(f"[OCR] Pixmap failed: {e}")
        return ""

    try:
        text = pytesseract.image_to_string(img)
    except Exception as e:
        debug(f"[OCR] Tesseract failed: {e}")
        return ""

    # Clean OCR lines
    lines = []
    for ln in text.split("\n"):
        ln = clean_text(ln)
        if ln:
            lines.append(ln)

    debug(f"[OCR] Extracted {len(lines)} lines")
    return "\n".join(lines)


def perform_smart_ocr(page, fitz_text: str) -> str:
    """
    Merge FITZ + OCR:
      • FITZ gives structure
      • OCR fills missing numbers/headings
      • OCR lines override FITZ if similar
    """
    ocr_text = ocr_page(page, dpi=200)

    if not ocr_text:
        return fitz_text

    fitz_lines = [clean_text(x) for x in fitz_text.split("\n") if x.strip()]
    ocr_lines  = [clean_text(x) for x in ocr_text.split("\n") if x.strip()]

    merged = []
    fi = oi = 0

    while fi < len(fitz_lines) or oi < len(ocr_lines):

        # If FITZ exhausted
        if fi >= len(fitz_lines):
            merged.append(ocr_lines[oi])
            oi += 1
            continue

        # If OCR exhausted
        if oi >= len(ocr_lines):
            merged.append(fitz_lines[fi])
            fi += 1
            continue

        f = fitz_lines[fi]
        o = ocr_lines[oi]

        # If lines are "similar", prefer OCR (fixes missing numbers)
        if f.lower() == o.lower() or f.lower() in o.lower() or o.lower() in f.lower():
            merged.append(o)
            fi += 1
            oi += 1
            continue

        # Otherwise FITZ usually preserves structure
        merged.append(f)
        fi += 1

    debug(f"[MERGE] Total merged lines: {len(merged)}")
    return "\n".join(merged)
# ===============================================================
# PART 3 — DATE / HEADER DETECTION ENGINE (STRICT COL-0 RULE)
# ===============================================================

DATE_PATTERNS = [
    r"^\d{2}/\d{2}/\d{4}\s+\d{1,2}:\d{2}",           # 25/09/2025 14:45
    r"^\d{2}/\d{2}/\d{4}\s+\d{1,2}\.\d{2}",          # 25/09/2025 14.45
    r"^\d{2}/\d{2}/\d{4}",                           # 25/09/2025
]

# -----------------------------------------------------------
# Soft validation of header lines (H3)
# -----------------------------------------------------------

HEADER_TOKENS = [
    "physical", "mental", "activity", "medication",
    "leisure", "patient", "health", "state", "contact",
    "external", "professional", "night", "day", "nursing",
]

def looks_like_header_after_timestamp(remainder: str) -> bool:
    """
    Decide if text after the timestamp looks like a real CareNotes header.

    Valid if:
      - contains "/"  (e.g. Physical Health / Mental State / Medication)
      OR
      - contains at least TWO known header tokens like 'physical', 'mental',
        'activity', 'medication', etc.
    """
    rem = (remainder or "").lower().strip()
    if not rem:
        return False

    # If it contains slash, that’s a strong signal
    if "/" in rem:
        return True

    # Count how many known header tokens appear
    count = sum(1 for token in HEADER_TOKENS if token in rem)
    return count >= 2

def detect_header_timestamp(line: str):
    """
    Valid CareNotes header must:
        1. Begin at column 0
        2. Contain a timestamp at the start
        3. Have meaningful text after timestamp (not empty, not confirmed)
        4. Not be a body section title
        5. Not be a confirmation timestamp
    """

    if not line or not line[0].isdigit():
        return None, None

    text = line.strip()

    # Never treat body-subheadings like “MENTAL STATE” as headers
    #if is_body_section_title(text):
     #   return None, None

    # Match timestamp at column 0
    m = re.match(r"^\d{1,2}/\d{1,2}/\d{4}\s+\d{1,2}[:.]\d{2}", text)
    if not m:
        return None, None

    raw_ts = m.group(0)
    remainder = text[len(raw_ts):].strip()
    # ------------------------------------------------------------
    # RULE H7 — Reject timestamps that are followed by NON-header lines
    # ------------------------------------------------------------
    # If remainder contains no slash AND no alphabetic type info,
    # it is almost always a timestamp inside a session block.
    if not "/" in remainder and len(remainder.split()) <= 2:
        return None, None

    
    # RULE H6 — If the remainder clearly contains a CareNotes category,
    # accept as a header even if earlier continuation timestamps existed.
    HEADER_KEYWORDS = [
        "patient activity",
        "mental state",
        "physical health",
        "medication",
        "external professional contact",
        "day notes",
        "night notes",
        "activities",
        "leisure",
        "daily routine",
        "personal care",
        "physical well being"
    ]

    rem_lc = remainder.lower()

    # If any keyword is in the remainder → treat as header
    if any(kw in rem_lc for kw in HEADER_KEYWORDS):
        try:
            cleaned = raw_ts.replace(".", ":")
            dt = parse_date(cleaned)
            return dt, raw_ts
        except:
            return None, None


    # Reject missing or junk remainder
    if not remainder:
        return None, None

    # Must contain at least one alphabetic character
    if not re.search(r"[A-Za-z]", remainder):
        return None, None

    # Reject confirmation timestamps
    if "confirmed" in remainder.lower():
        return None, None

    # Remainder must NOT be just a number or timestamp
    if re.fullmatch(r"[0-9:.\s]+", remainder):
        return None, None

    # Try parsing timestamp
    try:
        cleaned = raw_ts.replace(".", ":")
        dt = parse_date(cleaned)
        return dt, raw_ts
    except:
        return None, None





def parse_date(raw):
    """Multiple formats, tolerant."""
    for fmt in ("%d/%m/%Y %H:%M", "%d/%m/%Y %H.%M", "%d/%m/%Y"):
        try:
            return datetime.strptime(raw, fmt)
        except:
            pass
    return None


# ---------------------------------------------------------------
# INLINE TYPE DETECTION
# ---------------------------------------------------------------

def detect_inline_type(text: str):
    """
    If a FITZ/OCR header line contains category text after the timestamp,
    extract it as TYPE.
    e.g.:
        "25/09/2025 14:45 Patient Activity: Activities/Leisure"
    """
    if not text:
        return None

    # Remove the timestamp from the front
    ts, raw = detect_header_timestamp(text)
    if not ts:
        return None

    remainder = text[len(raw):].strip(" -:•")
    if not remainder:
        return None

    # Trim extremely long strings
    if len(remainder) > 200:
        return remainder[:200]

    return remainder


# ---------------------------------------------------------------
# CANONICAL TYPE CLEANER
# ---------------------------------------------------------------

def canonicalise_type(t: str):
    if not t:
        return ""
    t2 = t.lower()

    if "night" in t2:
        return "Night Note"
    if "day" in t2:
        return "Day Note"
    if "mental" in t2:
        return "Mental State"
    if "physical" in t2:
        return "Physical Health"
    if "depot" in t2 or "depo" in t2:
        return "Depot Administration"
    if "activity" in t2:
        return "Activity"
    if "medication" in t2:
        return "Medication"
    if "session name" in t2:
        return "Activity"

    return t.strip()

# ---------------------------------------------------------------
# NOTE BUILDER — MAIN PARSER
# ===============================================================

def parse_notes_from_lines(lines: list[str]) -> list[dict]:
    notes = []
    current = None

    i = 0
    L = len(lines)

    while i < L:
        ln = lines[i]

        # Skip pagebreak markers
        if ln == "<<<PAGEBREAK>>>":
            i += 1
            continue

        # Detect header timestamp
        ts, raw_ts = detect_header_timestamp(ln)
        # ---------------------------------------------------------
        # RULE H8R — Reject timestamps that follow real narrative text
        # but allow timestamps after metadata or category lines.
        # ---------------------------------------------------------
        if ts and current:
            prev_ln = lines[i - 1].strip() if i > 0 else ""

            # Ignore empty previous line
            if prev_ln == "":
                pass

            else:
                # Consider narrative only if:
                #   • ends with prose punctuation
                #   • AND contains enough words (≥ 12)
                words = prev_ln.split()
                if (
                    prev_ln[-1] in ".!?" and
                    len(words) >= 12
                ):
                    # This timestamp is continuation inside same note → NOT a header
                    ts = None


        # A body section title (MENTAL STATE, PHYSICAL HEALTH) is NOT a header
        # if is_body_section_title(ln):
        #     ts = None

        # -------------------------
        # VALID HEADER FOUND
        # -------------------------
        if ts:

            # RULE: ignore confirmation timestamp headers
            if i + 1 < L:
                nxt = lines[i + 1].strip().lower()
                if nxt.startswith("confirmed"):
                    i += 1
                    continue

            # Flush previous note
            if current:
                current["body"] = current["body"].strip()
                notes.append(current)

            # Extract inline type
            inline_type = detect_inline_type(ln)
            if inline_type:
                inline_type = canonicalise_type(inline_type)

            current = {
                "date": ts,
                "raw_header": ln,
                "type": inline_type or "",
                "body": ""
            }

            i += 1
            continue

        # -------------------------
        # NON-HEADER → add to body
        # -------------------------
        if current:
            current["body"] += ln + "\n"

        i += 1

    # Final flush
    if current:
        current["body"] = current["body"].strip()
        notes.append(current)

    debug(f"[PARSE] Built {len(notes)} initial notes")
    return notes


# ===============================================================
# RULE H1 — CONTINUATION FIX FOR MULTI-PAGE NOTES
# ===============================================================
BODY_TIMESTAMP_RE = re.compile(
    r"^\s*\d{1,2}\s*[/.\-]\s*\d{1,2}\s*[/.\-]\s*\d{2,4}"
)

def apply_continuations_H1(notes):
    """
    Improved continuation logic:
      • Merge ONLY real narrative continuation.
      • If the first body line of curr contains ANY timestamp-like pattern,
        it FORCES a NEW NOTE (splits).
      • Prevents rogue timestamps inside a note from merging.
    """

    if not notes:
        return notes

    merged = []
    prev = notes[0]

    for i in range(1, len(notes)):
        curr = notes[i]

        same_date = (curr["date"] == prev["date"])
        curr_type = (curr["type"] or "").strip().lower()

        body = (curr.get("body") or "").strip()
        first_line = body.split("\n")[0].strip() if body else ""

        # ----------------------------------------------------
        # RULE D — If first line looks like ANY category header
        # → MUST be a new note (never a continuation)
        # ----------------------------------------------------
        CATEGORY_MARKERS = [
            "physical health", "mental state", "medication",
            "patient activity", "activities", "leisure",
            "day note", "night note", "day notes", "night notes",
            "session name", "start date", "patient status",
            "activity type", "description", "staff name",
            "to view this event", "confirmed"
        ]

        fl_lc = first_line.lower()

        if any(tok in fl_lc for tok in CATEGORY_MARKERS):
            merged.append(prev)
            prev = curr
            continue
        # RULE E — If raw headers differ, do NOT merge
        if curr.get("raw_header") != prev.get("raw_header"):
            merged.append(prev)
            prev = curr
            continue

        # ----------------------------------------------------
        # RULE A — If first body line contains *ANY* timestamp,
        # this MUST be treated as a NEW NOTE.
        # ----------------------------------------------------
        if BODY_TIMESTAMP_RE.match(first_line):
            merged.append(prev)
            prev = curr
            continue

        # ----------------------------------------------------
        # RULE B — If first line is a structural header → NEW NOTE
        # ----------------------------------------------------
        if first_line.lower().startswith(
            (
                "confirmed", "session name", "start date",
                "activity type", "activity:", "patient status",
                "description:", "staff name",
                "to view this event"
            )
        ):
            merged.append(prev)
            prev = curr
            continue

        # ----------------------------------------------------
        # RULE C — Continuation only for genuine narrative text
        # ----------------------------------------------------
        has_sentence = (
            "." in body or
            ";" in body or
            "?" in body or
            len(body.split()) >= 6
        )

        is_continuation = (
            same_date and
            (not curr_type or curr_type in ["", "none", "unknown"]) and
            has_sentence
        )

        if is_continuation:
            prev["body"] += "\n" + body
        else:
            merged.append(prev)
            prev = curr

    merged.append(prev)
    return merged



# ===============================================================
# DEDUPLICATION — Remove duplicates caused by OCR/Fitz overlap
# ===============================================================
def dedupe_notes_v1(notes):
    """
    Removes duplicate notes created by OCR + FITZ double capture.
    
    Duplicate if:
        • Same date
        • Same TYPE (after strip)
        • Bodies identical OR one contains the other

    Keeps the longer version.
    """

    if not notes:
        return notes

    deduped = []
    prev = notes[0]

    for i in range(1, len(notes)):
        curr = notes[i]

        same_date = (curr["date"] == prev["date"])
        same_type = (curr["type"].strip() == prev["type"].strip())

        bodyA = prev["body"].strip()
        bodyB = curr["body"].strip()

        is_duplicate = False

        # Identical body
        if same_date and same_type and bodyA == bodyB:
            is_duplicate = True

        # One contains the other
        elif same_date and same_type:
            if (bodyA and bodyB) and (bodyA in bodyB or bodyB in bodyA):
                is_duplicate = True

        if is_duplicate:
            # Keep the fuller note
            if len(bodyB) > len(bodyA):
                prev = curr
        else:
            deduped.append(prev)
            prev = curr

    deduped.append(prev)
    return deduped

# ===============================================================
# NOTE FILTERING — REMOVE EMPTY / USELESS NOTES
# ===============================================================
def remove_empty_notes_v1(notes):
    """
    Removes notes that contain no meaningful body text.
    A note is removed if:

        • body is empty or extremely short, AND
        • type is empty or a 'junk' category, AND
        • body contains no real sentences.

    This prevents false fragments like:
        'Patient Activity: Activities/Leisure / Mental State / Medication'
    """

    junk_type_patterns = {
        "", "activity", "mental", "physical",
        "patient activity", "session", "note", "general"
    }

    cleaned = []

    for note in notes:
        body = (note.get("body") or "").strip()
        type_ = (note.get("type") or "").strip().lower()

        # Rule 1: If body has real sentences → KEEP
        has_sentence = (
            "." in body or
            ";" in body or
            "?" in body or
            "!" in body or
            len(body.split()) >= 12   # 12+ words = meaningful content
        )

        if has_sentence:
            cleaned.append(note)
            continue

        # Rule 2: If type is junk AND body is short → DROP
        if type_ in junk_type_patterns and len(body) < 50:
            continue  # drop this note

        # Rule 3: If body contains ONLY category lines → DROP
        if (
            len(body) < 60 and
            ("physical health" in body.lower() or
             "mental state" in body.lower() or
             "patient activity" in body.lower())
        ):
            continue

        cleaned.append(note)

    debug(f"[FILTER] Removed empty/meaningless notes. "
          f"Before: {len(notes)}, After: {len(cleaned)}")

    return cleaned

# ===============================================================
# FINAL CLEANUP & SORTING
# ===============================================================
def final_cleanup(notes):
    """
    Trim whitespace, normalise fields, and sort notes by datetime.
    """

    cleaned = []

    for note in notes:
        n = dict(note)  # shallow copy

        # Normalise body
        if "body" in n and isinstance(n["body"], str):
            n["body"] = n["body"].strip()

        # Normalise type
        if "type" in n and isinstance(n["type"], str):
            n["type"] = n["type"].strip()

        # Normalise originator
        if "originator" in n and isinstance(n["originator"], str):
            n["originator"] = n["originator"].strip()

        cleaned.append(n)

    # Sort by datetime
    try:
        cleaned.sort(key=lambda x: x["date"])
    except Exception:
        # Defensive fallback
        pass

    debug("[CLEANUP] Notes cleaned and sorted.")
    return cleaned


# ===============================================================
# PUBLIC ENTRY POINT — CALLED BY MyPsychAdmin
# ===============================================================
def import_pdf_notes(file_list):
    """
    Main entry point called by MyPsychAdmin.
    file_list — list of PDF paths.
    Returns a list of structured notes.
    """

    all_lines = []
    debug(f"[IMPORT] Starting import for {len(file_list)} file(s).")

    for path in file_list:
        debug(f"[IMPORT] Opening PDF: {path}")

        try:
            doc = fitz.open(path)
        except Exception as e:
            debug(f"[IMPORT] ERROR opening file {path}: {e}")
            continue

        for page_num, page in enumerate(doc):
            debug(f"[PAGE] Processing page {page_num + 1}/{len(doc)}")

            fitz_text = get_fitz_text(page)
            merged = perform_smart_ocr(page, fitz_text)

            # page break marker
            all_lines.append("<<<PAGEBREAK>>>")

            for ln in merged.split("\n"):
                ln = ln.strip()
                if ln:
                    all_lines.append(ln)

        doc.close()

    debug(f"[IMPORT] Total collected lines: {len(all_lines)}")

    # ----------------------------------------------------------
    # PARSE RAW NOTES
    # ----------------------------------------------------------
    notes = parse_notes_from_lines(all_lines)
    debug(f"[IMPORT] Raw notes parsed: {len(notes)}")

    # ----------------------------------------------------------
    # APPLY CONTINUATION RULE (H1)
    # ----------------------------------------------------------
    notes = apply_continuations_H1(notes)

    # ----------------------------------------------------------
    # DE-DUPLICATION
    # ----------------------------------------------------------
    notes = dedupe_notes_v1(notes)

    # ----------------------------------------------------------
    # FINAL CLEANUP
    # ----------------------------------------------------------
    notes = final_cleanup(notes)

    debug(f"[IMPORT] FINAL NOTE COUNT: {len(notes)}")
    debug("==== IMPORT FINISHED — IMPORTER V6 ====\n")

    return notes
