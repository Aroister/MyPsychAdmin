# ================================================================
#  LETTER SECTIONS — Anchor Mapping + Section Utilities
#  Module 4/10 for MyPsychAdmin Dynamic Letter Writer
# ================================================================
#  Provides:
#   • SECTION_LIST (ordered list of all letter sections)
#   • section_titles (mapping key→title)
#   • helper functions to:
#         - locate a section block
#         - insert/replace section content
#         - ensure anchors remain valid
# ================================================================

from __future__ import annotations
from typing import Optional

from PySide6.QtGui import QTextCursor
from PySide6.QtWidgets import QTextEdit


# ================================================================
#  SECTION DEFINITIONS (keys must match sidebar + editor anchors)
# ================================================================
SECTION_LIST = [
    ("front",     "Front Page"),
    ("pc",        "Presenting Complaint"),
    ("hpc",       "History of Presenting Complaint"),

    ("affect",    "Affect"),
    ("anxiety",   "Anxiety & Related Disorders"),
    ("thoughts",  "Thoughts"),
    ("percepts",  "Perceptions"),

    ("psychhx",   "Psychiatric History"),
    ("background","Background History"),
    ("drugalc",   "Drug and Alcohol History"),
    ("social",    "Social History"),
    ("forensic",  "Forensic History"),
    ("physical",  "Physical Health"),
    ("function",  "Function"),

    ("mse",       "Mental State Examination"),
    ("summary",   "Summary"),
    ("plan",      "Plan"),
]


SECTION_TITLES = {key: title for key, title in SECTION_LIST}



# ================================================================
#  FIND BLOCK FOR A SECTION
# ================================================================
def find_section_block(editor: QTextEdit, key: str) -> Optional[QTextCursor]:
    """
    Returns a QTextCursor positioned at the section header block.
    This relies on the editor's internal section_positions mapping.
    """
    if not hasattr(editor, "section_positions"):
        print("[letter_sections] Editor missing section_positions")
        return None

    if key not in editor.section_positions:
        print(f"[letter_sections] No anchor found for: {key}")
        return None

    block_num = editor.section_positions[key]
    block = editor.document().findBlockByNumber(block_num)

    if not block.isValid():
        print(f"[letter_sections] Invalid block for key={key}")
        return None

    cursor = QTextCursor(block)
    return cursor


# ================================================================
#  GET THE CURSOR AFTER A SECTION HEADER
# ================================================================
def cursor_after_header(editor: QTextEdit, key: str) -> Optional[QTextCursor]:
    """
    Returns cursor immediately after the section header line.
    This is where body text should go.
    """
    header_cursor = find_section_block(editor, key)
    if header_cursor is None:
        return None

    cursor = QTextCursor(header_cursor)
    cursor.movePosition(QTextCursor.NextBlock)
    return cursor


# ================================================================
#  CLEAR CONTENT UNDER A SECTION HEADER
# ================================================================
def clear_section_body(editor: QTextEdit, key: str):
    """
    Removes all text between this section header and the next section header.
    """
    start = cursor_after_header(editor, key)
    if start is None:
        return

    # Determine next section block
    keys = [k for k, _ in SECTION_LIST]
    idx = keys.index(key)

    next_block_num = None
    if idx < len(keys) - 1:
        next_key = keys[idx + 1]
        if next_key in editor.section_positions:
            next_block_num = editor.section_positions[next_key]

    doc = editor.document()
    start_block = start.block()
    end_block_num = next_block_num if next_block_num is not None else doc.blockCount()

    cursor = QTextCursor(start_block)
    cursor.beginEditBlock()

    # Remove blocks until next section
    while cursor.block().blockNumber() < end_block_num:
        if cursor.block().blockNumber() == start_block.blockNumber():
            cursor.select(QTextCursor.BlockUnderCursor)
            cursor.removeSelectedText()
            cursor.deleteChar()
        else:
            cursor.select(QTextCursor.BlockUnderCursor)
            cursor.removeSelectedText()
            cursor.deleteChar()

        cursor.movePosition(QTextCursor.NextBlock)

    cursor.endEditBlock()


# ================================================================
#  INSERT OR REPLACE SECTION CONTENT
# ================================================================
def set_section_text(editor: QTextEdit, key: str, text: str):
    """
    Replaces the section body under a header with new text.
    """
    clear_section_body(editor, key)

    insert_cursor = cursor_after_header(editor, key)
    if insert_cursor is None:
        return

    insert_cursor.beginEditBlock()
    insert_cursor.insertText(text)
    insert_cursor.endEditBlock()


def append_to_section(editor: QTextEdit, key: str, text: str):
    """
    Appends text to the section body (instead of replacing).
    """
    insert_cursor = cursor_after_header(editor, key)
    if insert_cursor is None:
        return

    # Move to end of section
    cursor = QTextCursor(insert_cursor)
    while cursor.movePosition(QTextCursor.NextBlock):
        block_num = cursor.block().blockNumber()
        if block_num in editor.section_positions.values():
            break  # Reached next section

    cursor.insertText("\n" + text)


# ================================================================
#  FETCH CURRENT TEXT OF A SECTION (useful for AI context)
# ================================================================
def get_section_text(editor: QTextEdit, key: str) -> str:
    """
    Reads the text inside a section (excluding the header).
    """
    start = cursor_after_header(editor, key)
    if start is None:
        return ""

    doc = editor.document()
    start_block = start.block().blockNumber()

    # find next section
    keys = [k for k, _ in SECTION_LIST]
    idx = keys.index(key)

    if idx < len(keys) - 1:
        next_key = keys[idx + 1]
        next_block_num = editor.section_positions.get(next_key, doc.blockCount())
    else:
        next_block_num = doc.blockCount()

    text = []
    block = doc.findBlockByNumber(start_block)
    while block.isValid() and block.blockNumber() < next_block_num:
        text.append(block.text())
        block = block.next()

    return "\n".join(text).strip()
