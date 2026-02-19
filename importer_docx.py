# importer_docx.py
from __future__ import annotations

import os
from docx import Document
from typing import List, Dict, Any

# ------------------------------------------------------------
# IMPORT .DOCX NOTES (very simple reader)
# ------------------------------------------------------------

def import_docx_notes(path: str) -> List[Dict[str, Any]]:
    """
    Minimal DOCX importer.
    Reads paragraphs and returns a list of notes where each line becomes
    a raw text note entry. No date parsing – PatientNotesPage handles that.
    """
    if not os.path.exists(path):
        print(f"[DOCX IMPORT] File not found: {path}")
        return []

    try:
        doc = Document(path)
    except Exception as e:
        print(f"[DOCX IMPORT] ERROR opening docx: {e}")
        return []

    notes = []

    for para in doc.paragraphs:
        text = para.text.strip()
        if not text:
            continue

        notes.append({
            "date": "",           # PatientNotesPage will fill or parse
            "type": "DOCX",
            "originator": "",
            "text": text,
            "source": "docx",
            "origin_file": os.path.basename(path),
        })

    print(f"[DOCX IMPORT] Imported {len(notes)} paragraph notes")
    return notes
