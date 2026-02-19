# ============================================================
#  MyPsychAdminRichTextEditor — unified editor for Letter Writer Cards
# ============================================================

from __future__ import annotations

import sys
from PySide6.QtWidgets import QTextEdit
from PySide6.QtGui import QFont, QTextCharFormat, QTextListFormat
from PySide6.QtCore import Qt

from spell_check_textedit import SpellCheckTextEdit


class MyPsychAdminRichTextEditor(SpellCheckTextEdit):
    def __init__(self, parent=None):
        super().__init__(parent)

        # Platform-appropriate default font
        if sys.platform == "win32":
            font = QFont("Segoe UI", 14)
        else:
            font = QFont("Helvetica Neue", 17)
        self.setFont(font)
        self.setStyleSheet("""
            QTextEdit {
                background: transparent;
                border: none;
                color: #111;
            }
        """)

        self.setAcceptRichText(True)
        self.setTabStopDistance(32)

    # --------------------------------------------------------
    # FONT CONTROLS
    # --------------------------------------------------------
    def set_font_size(self, size: int):
        cursor = self.textCursor()
        if not cursor:
            return
        fmt = cursor.charFormat()
        fmt.setFontPointSize(size)
        cursor.mergeCharFormat(fmt)
        self.mergeCurrentCharFormat(fmt)

    def set_font_family(self, family: str):
        cursor = self.textCursor()
        if not cursor:
            return
        fmt = cursor.charFormat()
        fmt.setFontFamily(family)
        cursor.mergeCharFormat(fmt)
        self.mergeCurrentCharFormat(fmt)

    # --------------------------------------------------------
    # INLINE STYLES (BOLD / ITALIC / UNDERLINE)
    # --------------------------------------------------------
    def _toggle_char_flag(self, flag_name: str):
        cursor = self.textCursor()
        if not cursor:
            return
        fmt = cursor.charFormat()
        current = getattr(fmt, flag_name)()
        setter = getattr(fmt, "set" + flag_name[0].upper() + flag_name[1:])
        setter(not current)
        cursor.mergeCharFormat(fmt)
        self.mergeCurrentCharFormat(fmt)

    def toggle_bold(self):
        cursor = self.textCursor()
        if not cursor:
            return
        fmt = cursor.charFormat()
        fmt.setFontWeight(QFont.Normal if fmt.fontWeight() > QFont.Normal else QFont.Bold)
        cursor.mergeCharFormat(fmt)
        self.mergeCurrentCharFormat(fmt)

    def toggle_italic(self):
        self._toggle_char_flag("fontItalic")

    def toggle_underline(self):
        self._toggle_char_flag("fontUnderline")

    # --------------------------------------------------------
    # COLOURS
    # --------------------------------------------------------
    def set_text_color(self, color):
        cursor = self.textCursor()
        if not cursor:
            return
        fmt = cursor.charFormat()
        fmt.setForeground(color)
        cursor.mergeCharFormat(fmt)
        self.mergeCurrentCharFormat(fmt)

    def set_highlight_color(self, color):
        cursor = self.textCursor()
        if not cursor:
            return
        fmt = cursor.charFormat()
        fmt.setBackground(color)
        cursor.mergeCharFormat(fmt)
        self.mergeCurrentCharFormat(fmt)

    # --------------------------------------------------------
    # ALIGNMENT
    # --------------------------------------------------------
    def align_left(self):
        self.setAlignment(Qt.AlignLeft)

    def align_center(self):
        self.setAlignment(Qt.AlignHCenter)

    def align_right(self):
        self.setAlignment(Qt.AlignRight)

    def align_justify(self):
        self.setAlignment(Qt.AlignJustify)

    # --------------------------------------------------------
    # LISTS + INDENT
    # --------------------------------------------------------
    def bullet_list(self):
        cursor = self.textCursor()
        if cursor:
            cursor.insertList(QTextListFormat.ListDisc)

    def numbered_list(self):
        cursor = self.textCursor()
        if cursor:
            cursor.insertList(QTextListFormat.ListDecimal)

    def indent(self):
        cursor = self.textCursor()
        if cursor:
            block = cursor.blockFormat()
            block.setLeftMargin(block.leftMargin() + 20)
            cursor.setBlockFormat(block)

    def outdent(self):
        cursor = self.textCursor()
        if cursor:
            block = cursor.blockFormat()
            block.setLeftMargin(max(0, block.leftMargin() - 20))
            cursor.setBlockFormat(block)

    # --------------------------------------------------------
    # UNDO / REDO
    # --------------------------------------------------------
    def editor_undo(self):
        self.undo()

    def editor_redo(self):
        self.redo()

    # --------------------------------------------------------
    # INSERT HELPERS
    # --------------------------------------------------------
    def insert_date(self):
        from datetime import datetime
        self.insertPlainText(datetime.now().strftime("%d %b %Y"))

    def insert_section_break(self):
        self.insertPlainText("\n\n---\n\n")

    # --------------------------------------------------------
    # MARKDOWN SAFE SETTERS  (SUPER IMPORTANT)
    # --------------------------------------------------------
    def set_markdown(self, text: str):
        """Universal safe setter used by popups + older code."""
        try:
            self.setMarkdown(text or "")
        except Exception:
            self.setHtml(self._md_to_html(text or ""))

    def append_markdown(self, text: str):
        try:
            self.appendMarkdown(text)
        except Exception:
            self.insertHtml(self._md_to_html(text))

    def insert_markdown(self, text: str):
        try:
            self.insertMarkdown(text)
        except Exception:
            self.insertHtml(self._md_to_html(text))

    # --------------------------------------------------------
    # MARKDOWN → HTML FALLBACK
    # --------------------------------------------------------
    def _md_to_html(self, text: str):
        try:
            from markdown import markdown
            return markdown(text)
        except Exception:
            return text  # worst-case fallback

    # --------------------------------------------------------
    # EXTRACT CLEAN MARKDOWN
    # --------------------------------------------------------
    def to_markdown(self) -> str:
        """Public wrapper for old API."""
        try:
            return self.toMarkdown()
        except Exception:
            return self.toPlainText()

    def toMarkdown(self) -> str:
        """Qt native markdown extraction."""
        try:
            return super().toMarkdown()
        except Exception:
            return self.toPlainText()
