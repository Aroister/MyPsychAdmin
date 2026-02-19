# ================================================================
#  CLIPBOARD HELPER — Rich Text + Plain Text Copy
#  Module 9/10 for MyPsychAdmin Dynamic Letter Writer
# ================================================================
from __future__ import annotations

from PySide6.QtGui import QClipboard
from PySide6.QtWidgets import QApplication
from bs4 import BeautifulSoup


class ClipboardHelper:

    # ------------------------------------------------------------
    # COPY ENTIRE LETTER AS RICH TEXT (HTML)
    # ------------------------------------------------------------
    @staticmethod
    def copy_rich(editor):
        """
        Copies the editor's full HTML content to the clipboard.
        """
        html = editor.toHtml()
        clipboard = QApplication.clipboard()
        clipboard.setText(html, mode=QClipboard.Clipboard)
        print("[Clipboard] Copied full RTF/HTML letter to clipboard.")

    # ------------------------------------------------------------
    # COPY ENTIRE LETTER AS PLAIN TEXT
    # ------------------------------------------------------------
    @staticmethod
    def copy_plain(editor):
        """
        Copies the cleaned plain text content of the full letter.
        """
        html = editor.toHtml()
        soup = BeautifulSoup(html, "html.parser")
        text = soup.get_text("\n", strip=True)

        clipboard = QApplication.clipboard()
        clipboard.setText(text, mode=QClipboard.Clipboard)
        print("[Clipboard] Copied full plain text letter to clipboard.")

    # ------------------------------------------------------------
    # COPY SELECTED TEXT (RICH)
    # ------------------------------------------------------------
    @staticmethod
    def copy_selection_rich(editor):
        """
        Copies selected content in HTML if available, else plain text.
        """
        cursor = editor.textCursor()
        if cursor.hasSelection():
            html = cursor.selection().toHtml()
        else:
            html = editor.toHtml()

        clipboard = QApplication.clipboard()
        clipboard.setText(html, mode=QClipboard.Clipboard)
        print("[Clipboard] Copied selection (rich).")

    # ------------------------------------------------------------
    # COPY SELECTED TEXT (PLAIN)
    # ------------------------------------------------------------
    @staticmethod
    def copy_selection_plain(editor):
        """
        Copies selected content as plain text. If nothing selected,
        copies the entire letter.
        """
        cursor = editor.textCursor()

        if cursor.hasSelection():
            text = cursor.selection().toPlainText()
        else:
            html = editor.toHtml()
            soup = BeautifulSoup(html, "html.parser")
            text = soup.get_text("\n", strip=True)

        clipboard = QApplication.clipboard()
        clipboard.setText(text, mode=QClipboard.Clipboard)
        print("[Clipboard] Copied selection (plain).")
