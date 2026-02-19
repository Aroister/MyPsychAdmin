# ================================================================
# importer_autodetect.py — V3 STRICT ROUTER (NO AUTODETECT)
# Avie Luthra — MyPsychAdmin 2.4
#
# Dropdown options:
#   • "Import as Rio"
#   • "Import as Carenotes"
#   • "Import as both"
#
# This router NEVER autodetects and NEVER switches pipelines.
# Whatever the user selects is the importer used.
# ================================================================

from __future__ import annotations
from typing import List, Dict
from pathlib import Path
import re
from importer_rio import parse_rio_file
from importer_carenotes import parse_carenotes_file
from importer_epjs import parse_epjs_file


def detect_note_system(lines: list[str]) -> str:
    text = "\n".join(lines[:200]).lower()

    # -----------------------------
    # RIO (very strong signals)
    # -----------------------------
    if "originator:" in text and "[" in text and "]" in text:
        return "rio"

    # -----------------------------
    # EPJS (ward artefacts)
    # -----------------------------
    EPJS_MARKERS = [
        "am/pm shift",
        "observation level",
        "legal status",
        "dasa",
        "confirmed by",
        "returned safely on the ward",
    ]

    if any(m in text for m in EPJS_MARKERS):
        return "epjs"

    # -----------------------------
    # Default
    # -----------------------------
    return "carenotes"
def import_files_autodetect(paths: List[str]) -> List[Dict]:
    """
    Intelligent importer:
    Detects RIO / CareNotes / EPJS per file and routes accordingly.
    """
    import pandas as pd

    all_notes: List[Dict] = []

    for p in paths:
        ext = Path(p).suffix.lower()
        if ext not in {".xlsx", ".xls"}:
            print(f"[AUTO] Skipping unsupported: {p}")
            continue

        print(f"[AUTO] Inspecting → {p}")

        # ---------------------------------
        # Read minimal content for detection
        # ---------------------------------
        df = pd.read_excel(p, header=None, dtype=str)

        lines: list[str] = []
        for _, row in df.iterrows():
            for cell in row:
                s = str(cell).strip()
                if s and s.lower() not in {"nan", "none", "<na>"}:
                    lines.append(s)

        system = detect_note_system(lines)
        print(f"[AUTO] Detected system = {system.upper()}")

        # ---------------------------------
        # Route to correct parser
        # ---------------------------------
        if system == "rio":
            notes = parse_rio_file(p)
            src = "rio"

        elif system == "epjs":
            notes = parse_epjs_file(p)
            src = "epjs"

        else:
            notes = parse_carenotes_file(p)
            src = "carenotes"

        # ---------------------------------
        # Normalise output
        # ---------------------------------
        for n in notes:
            if "content" in n:
                n["text"] = n.pop("content")
            n["source"] = src
            n["source_file"] = p

        all_notes.extend(notes)

    print(f"[AUTO] DONE — {len(all_notes)} notes")
    return all_notes

# ================================================================
# RIO IMPORT
# ================================================================
def import_files_rio(paths: List[str]) -> List[Dict]:
    all_notes = []

    for p in paths:
        ext = Path(p).suffix.lower()
        if ext not in {".xlsx", ".xls"}:
            print(f"[RIO] Skipping unsupported: {p}")
            continue

        print(f"[RIO] Import → {p}")
        notes = parse_rio_file(p)

        # normalise keys
        for n in notes:
            if "content" in n:
                n["text"] = n.pop("content")
            n["source"] = "rio"
            n["source_file"] = p

        all_notes.extend(notes)

    print(f"[RIO] DONE — {len(all_notes)} notes")
    return all_notes


# ================================================================
# CARENOTES IMPORT
# ================================================================
def import_files_carenotes(paths: List[str]) -> List[Dict]:
    all_notes = []

    for p in paths:
        ext = Path(p).suffix.lower()
        if ext not in {".xlsx", ".xls"}:
            print(f"[CN] Skipping unsupported: {p}")
            continue

        print(f"[CN] Import → {p}")
        notes = parse_carenotes_file(p)

        for n in notes:
            if "content" in n:
                n["text"] = n.pop("content")
            n["source"] = "carenotes"
            n["source_file"] = p

        all_notes.extend(notes)

    print(f"[CN] DONE — {len(all_notes)} notes")
    return all_notes


# ================================================================
# BOTH IMPORTS (NO AUTODETECTION)
# Sequential: RIO first, then CareNotes
# ================================================================
def import_files_both(paths: List[str]) -> List[Dict]:
    print("[AUTO MODE DISABLED] Auto-detect import is no longer supported.")
    return []

# ================================================================
# EPJS IMPORT
# ================================================================
def import_files_epjs(paths: List[str]) -> List[Dict]:
    all_notes = []

    for p in paths:
        ext = Path(p).suffix.lower()
        if ext not in {".xlsx", ".xls"}:
            print(f"[EPJS] Skipping unsupported: {p}")
            continue

        print(f"[EPJS] Import → {p}")
        notes = parse_epjs_file(p)

        for n in notes:
            if "content" in n:
                n["text"] = n.pop("content")
            n["source"] = "epjs"
            n["source_file"] = p

        all_notes.extend(notes)

    print(f"[EPJS] DONE — {len(all_notes)} notes")
    return all_notes

# ================================================================
# MASTER ROUTER — called by PatientNotesPanel
# ================================================================
def import_files(mode: str, paths: List[str]) -> List[Dict]:
    """
    mode is literally the dropdown value:
        "Import as Rio"
        "Import as Carenotes"
        "Import as both"
    """
    mode = (mode or "").strip().lower()

    if mode == "import as rio":
        return import_files_rio(paths)

    if mode == "import as carenotes":
        return import_files_carenotes(paths)

    if mode == "import as epjs":
        return import_files_epjs(paths)

    if mode == "import as both":
        return import_files_both(paths)

    if mode == "import as auto":
        return import_files_autodetect(paths)

    print(f"[ERROR] Unknown import mode: {mode!r}")
    return []
def detect_note_system(lines: list[str]) -> str:
    """
    Robust detection between:
    - RIO
    - CareNotes (cut/paste + reports)
    - EPJS
    """

    sample = lines[:300]
    text = "\n".join(sample).lower()

    # =====================================================
    # 1️⃣ RIO — extremely distinctive
    # =====================================================
    if "originator:" in text and "[" in text and "]" in text:
        return "rio"

    # =====================================================
    # 2️⃣ EPJS — MUST have LONG dashed separators
    # =====================================================
    # EPJS always uses very long dash lines (20+ hyphens)
    long_dash_lines = [
        ln for ln in sample
        if re.match(r"-{20,}", ln.strip())
    ]

    if long_dash_lines:
        # EPJS footer pattern: long dashes + date + time + name
        for ln in sample:
            if re.search(
                r"-{20,}\s*\d{1,2}\s+[A-Za-z]{3}\s+\d{4}\s+\d{1,2}:\d{2},",
                ln
            ):
                return "epjs"

    # =====================================================
    # 3️⃣ CareNotes — cut & paste signatures
    # =====================================================
    # Short dashes + double comma is classic CareNotes
    for ln in sample:
        if re.search(r"-{2,}\s*[^,]+,\s*,\s*\d{1,2}/\d{1,2}/\d{4}", ln):
            return "carenotes"

    # =====================================================
    # 4️⃣ CareNotes — report style
    # =====================================================
    CARENOTES_MARKERS = [
        "night note entry",
        "keeping well",
        "keeping healthy",
        "keeping safe",
        "keeping connected",
        "inpatients -",
        "title:",
    ]

    if any(m in text for m in CARENOTES_MARKERS):
        return "carenotes"

    # =====================================================
    # 5️⃣ Safe default
    # =====================================================
    return "carenotes"
