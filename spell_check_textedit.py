# ============================================================
#  SpellCheckTextEdit — QTextEdit with integrated spell checking
# ============================================================

from __future__ import annotations

import re
from typing import Optional

from PySide6.QtWidgets import QTextEdit, QMenu, QApplication
from PySide6.QtGui import (
    QSyntaxHighlighter,
    QTextCharFormat,
    QTextDocument,
    QColor,
    QTextCursor,
    QAction,
    QFont,
    QContextMenuEvent,
)
from PySide6.QtCore import Signal, QTimer

from spell_checker import SpellCheckManager


class SpellCheckHighlighter(QSyntaxHighlighter):
    """
    Syntax highlighter that underlines misspelled words with red wavy underline.
    """

    def __init__(self, document: QTextDocument, enabled: bool = True):
        super().__init__(document)
        self.spell_manager = SpellCheckManager.instance()
        self._enabled = enabled

        # Red wavy underline format for misspelled words
        self._misspelled_format = QTextCharFormat()
        self._misspelled_format.setUnderlineStyle(
            QTextCharFormat.UnderlineStyle.WaveUnderline
        )
        self._misspelled_format.setUnderlineColor(QColor("#ef4444"))  # Red

        # Word pattern - matches words with apostrophes (e.g., "don't")
        self._word_pattern = re.compile(r"\b[A-Za-z']+\b")

    def set_enabled(self, enabled: bool):
        """Enable or disable spell checking."""
        self._enabled = enabled
        self.rehighlight()

    def highlightBlock(self, text: str):
        """Called by Qt for each block of text."""
        if not self._enabled:
            return

        for match in self._word_pattern.finditer(text):
            word = match.group()

            # Skip short words and contractions fragments
            if len(word) < 2:
                continue

            # Skip words that are just apostrophes
            if word.strip("'") == "":
                continue

            if self.spell_manager.is_misspelled(word):
                self.setFormat(
                    match.start(),
                    len(word),
                    self._misspelled_format
                )


class SpellCheckTextEdit(QTextEdit):
    """
    QTextEdit subclass with integrated spell checking.

    Features:
    - Real-time red wavy underline under misspelled words
    - Right-click context menu with spelling suggestions
    - Jump to next/previous error functionality
    """

    # Signal emitted when error count changes
    errorCountChanged = Signal(int)

    def __init__(self, parent=None):
        super().__init__(parent)

        # Create highlighter
        self._highlighter = SpellCheckHighlighter(self.document())
        self._spell_enabled = True

        # Word pattern for navigation
        self._word_pattern = re.compile(r"\b[A-Za-z']+\b")

        # Debounce timer for error counting
        self._error_count_timer = QTimer()
        self._error_count_timer.setSingleShot(True)
        self._error_count_timer.setInterval(500)
        self._error_count_timer.timeout.connect(self._emit_error_count)

        # Connect text changed to update error count
        self.textChanged.connect(self._on_text_changed)

    def set_spell_check_enabled(self, enabled: bool):
        """Enable or disable spell checking."""
        self._spell_enabled = enabled
        self._highlighter.set_enabled(enabled)

    def is_spell_check_enabled(self) -> bool:
        """Return whether spell checking is enabled."""
        return self._spell_enabled

    def _on_text_changed(self):
        """Handle text changes - debounce error count updates."""
        self._error_count_timer.start()

    def _emit_error_count(self):
        """Emit the current error count."""
        count = self.get_error_count()
        self.errorCountChanged.emit(count)

    def get_error_count(self) -> int:
        """Count the number of misspelled words in the document."""
        if not self._spell_enabled:
            return 0

        text = self.toPlainText()
        count = 0
        spell_manager = SpellCheckManager.instance()

        for match in self._word_pattern.finditer(text):
            word = match.group()
            if len(word) >= 2 and spell_manager.is_misspelled(word):
                count += 1

        return count

    def jump_to_next_error(self) -> bool:
        """
        Move cursor to the next misspelled word.

        Returns:
            True if an error was found, False if no errors
        """
        if not self._spell_enabled:
            return False

        text = self.toPlainText()
        current_pos = self.textCursor().position()
        spell_manager = SpellCheckManager.instance()

        # Find errors after current position
        for match in self._word_pattern.finditer(text):
            if match.start() > current_pos:
                word = match.group()
                if len(word) >= 2 and spell_manager.is_misspelled(word):
                    self._select_word_at(match.start(), match.end())
                    return True

        # Wrap to beginning
        for match in self._word_pattern.finditer(text):
            word = match.group()
            if len(word) >= 2 and spell_manager.is_misspelled(word):
                self._select_word_at(match.start(), match.end())
                return True

        return False

    def jump_to_previous_error(self) -> bool:
        """
        Move cursor to the previous misspelled word.

        Returns:
            True if an error was found, False if no errors
        """
        if not self._spell_enabled:
            return False

        text = self.toPlainText()
        current_pos = self.textCursor().position()
        spell_manager = SpellCheckManager.instance()

        # Collect all error positions
        errors = []
        for match in self._word_pattern.finditer(text):
            word = match.group()
            if len(word) >= 2 and spell_manager.is_misspelled(word):
                errors.append((match.start(), match.end()))

        if not errors:
            return False

        # Find error before current position
        for start, end in reversed(errors):
            if end < current_pos:
                self._select_word_at(start, end)
                return True

        # Wrap to end
        start, end = errors[-1]
        self._select_word_at(start, end)
        return True

    def _select_word_at(self, start: int, end: int):
        """Select text at the given positions."""
        cursor = self.textCursor()
        cursor.setPosition(start)
        cursor.setPosition(end, QTextCursor.MoveMode.KeepAnchor)
        self.setTextCursor(cursor)
        self.ensureCursorVisible()

    def contextMenuEvent(self, event: QContextMenuEvent):
        """Override context menu to add spelling suggestions."""
        # Get word under cursor
        cursor = self.cursorForPosition(event.pos())
        cursor.select(QTextCursor.SelectionType.WordUnderCursor)
        word = cursor.selectedText().strip()

        # Create standard context menu
        menu = self.createStandardContextMenu()

        # Style the menu
        menu.setStyleSheet("""
            QMenu {
                background-color: rgba(255,255,255,0.98);
                color: #333;
                border: 1px solid #d1d5db;
                border-radius: 6px;
                padding: 4px;
            }
            QMenu::item {
                padding: 8px 16px;
                border-radius: 4px;
            }
            QMenu::item:selected {
                background-color: rgba(37, 99, 235, 0.15);
            }
            QMenu::separator {
                height: 1px;
                background: #e5e7eb;
                margin: 4px 8px;
            }
        """)

        spell_manager = SpellCheckManager.instance()

        # If word is misspelled, add suggestions
        if word and self._spell_enabled and spell_manager.is_misspelled(word):
            suggestions = spell_manager.get_suggestions(word, max_suggestions=5)

            # Get first action to insert before
            first_action = menu.actions()[0] if menu.actions() else None

            if suggestions:
                for suggestion in suggestions:
                    action = QAction(suggestion, menu)
                    # Make suggestions bold
                    font = action.font()
                    font.setBold(True)
                    action.setFont(font)
                    # Connect to replace function
                    action.triggered.connect(
                        lambda checked, s=suggestion, c=cursor: self._replace_word(c, s)
                    )
                    menu.insertAction(first_action, action)

                menu.insertSeparator(first_action)

            # Add "Add to Dictionary" option
            add_action = QAction("Add to Dictionary", menu)
            add_action.triggered.connect(
                lambda: self._add_to_dictionary(word)
            )
            menu.insertAction(first_action, add_action)
            menu.insertSeparator(first_action)

        menu.exec(event.globalPos())

    def _replace_word(self, cursor: QTextCursor, replacement: str):
        """Replace the selected word with the correction."""
        cursor.beginEditBlock()
        cursor.removeSelectedText()
        cursor.insertText(replacement)
        cursor.endEditBlock()

    def _add_to_dictionary(self, word: str):
        """Add word to the custom dictionary."""
        spell_manager = SpellCheckManager.instance()
        spell_manager.add_to_dictionary(word)
        self._highlighter.rehighlight()


def enable_spell_check_on_textedit(text_edit: QTextEdit) -> SpellCheckHighlighter:
    """
    Retrofit spell checking onto an existing QTextEdit widget.

    This adds spell highlighting and context menu suggestions to any QTextEdit
    without requiring it to be a SpellCheckTextEdit subclass.

    Args:
        text_edit: The QTextEdit to add spell checking to

    Returns:
        The highlighter (keep a reference to prevent garbage collection)
    """
    # Create and attach highlighter
    highlighter = SpellCheckHighlighter(text_edit.document())
    text_edit._spell_highlighter = highlighter  # Keep reference

    # Store original context menu handler
    original_context_menu = text_edit.contextMenuEvent

    def new_context_menu(event: QContextMenuEvent):
        """Enhanced context menu with spelling suggestions."""
        # Get word under cursor
        cursor = text_edit.cursorForPosition(event.pos())
        cursor.select(QTextCursor.SelectionType.WordUnderCursor)
        word = cursor.selectedText().strip()

        # Create standard context menu
        menu = text_edit.createStandardContextMenu()

        # Style the menu
        menu.setStyleSheet("""
            QMenu {
                background-color: rgba(255,255,255,0.98);
                color: #333;
                border: 1px solid #d1d5db;
                border-radius: 6px;
                padding: 4px;
            }
            QMenu::item {
                padding: 8px 16px;
                border-radius: 4px;
            }
            QMenu::item:selected {
                background-color: rgba(37, 99, 235, 0.15);
            }
            QMenu::separator {
                height: 1px;
                background: #e5e7eb;
                margin: 4px 8px;
            }
        """)

        spell_manager = SpellCheckManager.instance()

        # If word is misspelled, add suggestions
        if word and spell_manager.is_misspelled(word):
            suggestions = spell_manager.get_suggestions(word, max_suggestions=5)

            first_action = menu.actions()[0] if menu.actions() else None

            if suggestions:
                for suggestion in suggestions:
                    action = QAction(suggestion, menu)
                    font = action.font()
                    font.setBold(True)
                    action.setFont(font)

                    def make_replace_fn(s, c):
                        def replace():
                            c.beginEditBlock()
                            c.removeSelectedText()
                            c.insertText(s)
                            c.endEditBlock()
                        return replace

                    action.triggered.connect(make_replace_fn(suggestion, cursor))
                    menu.insertAction(first_action, action)

                menu.insertSeparator(first_action)

            # Add "Add to Dictionary" option
            def add_word():
                spell_manager.add_to_dictionary(word)
                highlighter.rehighlight()

            add_action = QAction("Add to Dictionary", menu)
            add_action.triggered.connect(add_word)
            menu.insertAction(first_action, add_action)
            menu.insertSeparator(first_action)

        menu.exec(event.globalPos())

    # Replace context menu method
    text_edit.contextMenuEvent = new_context_menu

    return highlighter
