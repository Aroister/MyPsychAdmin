# ================================================================
#  CLEAN LETTER TOOLBAR — Only Export DOCX + Upload
# ================================================================

from __future__ import annotations

from PySide6.QtCore import Qt, QSize, Signal
from PySide6.QtGui import QColor, QFontDatabase
from PySide6.QtWidgets import (
    QWidget, QHBoxLayout, QComboBox, QToolButton, QColorDialog
)


class LetterToolbar(QWidget):

    # -------- Formatting signals --------
    set_font_family = Signal(str)
    set_font_size = Signal(int)

    toggle_bold = Signal()
    toggle_italic = Signal()
    toggle_underline = Signal()

    set_text_color = Signal(QColor)
    set_highlight_color = Signal(QColor)

    set_align_left = Signal()
    set_align_center = Signal()
    set_align_right = Signal()
    set_align_justify = Signal()

    bullet_list = Signal()
    numbered_list = Signal()

    indent = Signal()
    outdent = Signal()

    undo = Signal()
    redo = Signal()

    insert_date = Signal()
    insert_section_break = Signal()

    # -------- The ONLY two actions you want --------
    export_docx = Signal()
    load_letter = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)

        self.setFixedHeight(54)
        self.setStyleSheet("""
            LetterToolbar {
                background: rgba(0,0,0,0.30);
                border-bottom: 1px solid rgba(255,255,255,0.12);
            }
            QToolButton {
                background: transparent;
                color: white;
                padding: 6px;
                border-radius: 6px;
            }
            QToolButton:hover {
                background: rgba(255,255,255,0.10);
            }
            QComboBox {
                background: rgba(255,255,255,0.18);
                color: white;
                border-radius: 6px;
                padding: 4px;
            }
        """)

        layout = QHBoxLayout(self)
        layout.setContentsMargins(8, 6, 8, 6)
        layout.setSpacing(10)

        # ---------------------------------------------------------
        # FONT FAMILY
        # ---------------------------------------------------------
        self.font_combo = QComboBox()
        self.font_combo.setFixedWidth(160)

        families = QFontDatabase.families()
        preferred = ["Avenir Next", "Avenir", "SF Pro Text", "Helvetica Neue", "Helvetica"]

        added = set()
        for f in preferred:
            if f in families:
                self.font_combo.addItem(f)
                added.add(f)
        for f in families:
            if f not in added:
                self.font_combo.addItem(f)

        self.font_combo.currentTextChanged.connect(self.set_font_family.emit)
        layout.addWidget(self.font_combo)

        # ---------------------------------------------------------
        # FONT SIZE
        # ---------------------------------------------------------
        self.size_combo = QComboBox()
        self.size_combo.setFixedWidth(60)
        for sz in [8, 9, 10, 11, 12, 14, 16, 18, 20, 22]:
            self.size_combo.addItem(str(sz))
        self.size_combo.currentTextChanged.connect(lambda v: self.set_font_size.emit(int(v)))
        layout.addWidget(self.size_combo)

        # Simple button helper
        def btn(label, slot):
            b = QToolButton()
            b.setText(label)
            b.clicked.connect(slot)
            return b

        # ---------------------------------------------------------
        # BASIC STYLES
        # ---------------------------------------------------------
        layout.addWidget(btn("B", self.toggle_bold.emit))
        layout.addWidget(btn("I", self.toggle_italic.emit))
        layout.addWidget(btn("U", self.toggle_underline.emit))

        # ---------------------------------------------------------
        # COLORS
        # ---------------------------------------------------------
        color_btn = btn("A", self._choose_text_color)
        layout.addWidget(color_btn)

        highlight_btn = btn("🖍", self._choose_highlight_color)
        layout.addWidget(highlight_btn)

        # ---------------------------------------------------------
        # ALIGNMENT
        # ---------------------------------------------------------
        layout.addWidget(btn("L", self.set_align_left.emit))
        layout.addWidget(btn("C", self.set_align_center.emit))
        layout.addWidget(btn("R", self.set_align_right.emit))
        layout.addWidget(btn("J", self.set_align_justify.emit))

        # ---------------------------------------------------------
        # LISTS / INDENTATION
        # ---------------------------------------------------------
        layout.addWidget(btn("•", self.bullet_list.emit))
        layout.addWidget(btn("1.", self.numbered_list.emit))
        layout.addWidget(btn("→", self.indent.emit))
        layout.addWidget(btn("←", self.outdent.emit))

        # ---------------------------------------------------------
        # UNDO / REDO
        # ---------------------------------------------------------
        layout.addWidget(btn("⟲", self.undo.emit))
        layout.addWidget(btn("⟳", self.redo.emit))

        # ---------------------------------------------------------
        # INSERTS
        # ---------------------------------------------------------
        layout.addWidget(btn("Date", self.insert_date.emit))
        layout.addWidget(btn("Break", self.insert_section_break.emit))

        layout.addStretch()

        # ---------------------------------------------------------
        # THE ONLY TWO ACTION BUTTONS YOU WANT
        # ---------------------------------------------------------

        export_btn = btn("Export DOCX", self.export_docx.emit)
        export_btn.setFixedWidth(120)
        layout.addWidget(export_btn)

        load_btn = btn("Upload", self.load_letter.emit)
        load_btn.setFixedWidth(90)
        layout.addWidget(load_btn)

    # -----------------------------
    # COLOR PICKERS
    # -----------------------------
    def _choose_text_color(self):
        col = QColorDialog.getColor(QColor("black"), self)
        if col.isValid():
            self.set_text_color.emit(col)

    def _choose_highlight_color(self):
        col = QColorDialog.getColor(QColor("yellow"), self)
        if col.isValid():
            self.set_highlight_color.emit(col)
