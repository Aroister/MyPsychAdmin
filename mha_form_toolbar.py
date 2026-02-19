# ============================================================
#  MHAFormToolbar — Shared formatting toolbar for MHA form pages
# ============================================================

from __future__ import annotations

import sys
from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QColor, QFontDatabase
from PySide6.QtWidgets import (
    QWidget, QHBoxLayout, QToolButton, QComboBox,
    QScrollArea, QColorDialog,
)


class MHAFormToolbar(QWidget):
    """Full-featured formatting toolbar for Mental Health Act form pages."""

    # Formatting signals
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

    export_docx = Signal()
    check_spelling = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)

        self.setFixedHeight(64)
        self.setStyleSheet("""
            MHAFormToolbar {
                background: rgba(200, 215, 220, 0.95);
                border-bottom: 1px solid rgba(0,0,0,0.12);
            }
            QToolButton {
                background: transparent;
                color: #333333;
                padding: 6px 10px;
                border-radius: 6px;
                font-size: 15px;
                font-weight: 500;
            }
            QToolButton:hover {
                background: rgba(0,0,0,0.08);
            }
            QComboBox {
                background: rgba(255,255,255,0.85);
                color: #333333;
                border: 1px solid rgba(0,0,0,0.15);
                border-radius: 6px;
                padding: 4px 8px;
                font-size: 14px;
            }
            QComboBox::drop-down {
                border: none;
                width: 20px;
            }
            QComboBox QAbstractItemView {
                background: white;
                color: #333333;
                selection-background-color: #e0e0e0;
            }
        """)

        outer_layout = QHBoxLayout(self)
        outer_layout.setContentsMargins(0, 0, 0, 0)
        outer_layout.setSpacing(0)

        scroll = QScrollArea()
        scroll.setWidgetResizable(False)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOn)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        scroll.setFixedHeight(64)

        container = QWidget()
        container.setStyleSheet("background: transparent;")
        container.setFixedHeight(60)
        container.setMinimumWidth(1200)
        layout = QHBoxLayout(container)
        layout.setContentsMargins(8, 2, 8, 2)
        layout.setSpacing(10)

        # Export DOCX
        export_btn = QToolButton()
        export_btn.setText("Export DOCX")
        export_btn.setFixedSize(150, 42)
        export_btn.setStyleSheet("""
            QToolButton {
                background: #2563eb; color: white;
                font-size: 18px; font-weight: 600;
                border: none; border-radius: 8px; padding: 8px 16px;
            }
            QToolButton:hover { background: #1d4ed8; }
            QToolButton:pressed { background: #1e40af; }
        """)
        export_btn.clicked.connect(self.export_docx.emit)
        layout.addWidget(export_btn)

        # Uploaded Docs (dropdown menu)
        from PySide6.QtWidgets import QMenu
        import_btn = QToolButton()
        import_btn.setText("Uploaded Docs")
        import_btn.setFixedSize(170, 42)
        import_btn.setPopupMode(QToolButton.InstantPopup)
        self.upload_menu = QMenu()
        import_btn.setMenu(self.upload_menu)
        import_btn.setStyleSheet("""
            QToolButton {
                background: #10b981; color: white;
                font-size: 18px; font-weight: 600;
                border: none; border-radius: 8px; padding: 8px 16px;
            }
            QToolButton:hover { background: #059669; }
            QToolButton:pressed { background: #047857; }
            QToolButton::menu-indicator { image: none; }
        """)
        layout.addWidget(import_btn)

        # Font Family
        self.font_combo = QComboBox()
        self.font_combo.setFixedWidth(180)
        families = QFontDatabase.families()
        if sys.platform == "win32":
            preferred = ["Segoe UI", "Calibri", "Cambria", "Arial", "Times New Roman"]
        else:
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

        # Font Size
        self.size_combo = QComboBox()
        self.size_combo.setFixedWidth(65)
        for sz in [8, 9, 10, 11, 12, 14, 16, 18, 20, 22]:
            self.size_combo.addItem(str(sz))
        self.size_combo.currentTextChanged.connect(lambda v: self.set_font_size.emit(int(v)))
        layout.addWidget(self.size_combo)

        def btn(label, slot):
            b = QToolButton()
            b.setText(label)
            b.setMinimumWidth(36)
            b.clicked.connect(slot)
            return b

        # Basic styles
        layout.addWidget(btn("B", self.toggle_bold.emit))
        layout.addWidget(btn("I", self.toggle_italic.emit))
        layout.addWidget(btn("U", self.toggle_underline.emit))

        # Colors
        layout.addWidget(btn("A", self._choose_text_color))
        layout.addWidget(btn("\U0001f58d", self._choose_highlight_color))

        # Alignment
        layout.addWidget(btn("L", self.set_align_left.emit))
        layout.addWidget(btn("C", self.set_align_center.emit))
        layout.addWidget(btn("R", self.set_align_right.emit))
        layout.addWidget(btn("J", self.set_align_justify.emit))

        # Lists / Indentation
        layout.addWidget(btn("\u2022", self.bullet_list.emit))
        layout.addWidget(btn("1.", self.numbered_list.emit))
        layout.addWidget(btn("\u2192", self.indent.emit))
        layout.addWidget(btn("\u2190", self.outdent.emit))

        # Undo / Redo
        layout.addWidget(btn("\u27f2", self.undo.emit))
        layout.addWidget(btn("\u27f3", self.redo.emit))

        # Inserts
        layout.addWidget(btn("Date", self.insert_date.emit))
        layout.addWidget(btn("Break", self.insert_section_break.emit))

        # Spell Check
        spell_btn = QToolButton()
        spell_btn.setText("Spell Check")
        spell_btn.setFixedSize(120, 38)
        spell_btn.setStyleSheet("""
            QToolButton {
                background: #f59e0b; color: white;
                font-size: 15px; font-weight: 600;
                border: none; border-radius: 8px; padding: 6px 12px;
            }
            QToolButton:hover { background: #d97706; }
            QToolButton:pressed { background: #b45309; }
        """)
        spell_btn.setToolTip("Jump to next spelling error")
        spell_btn.clicked.connect(self.check_spelling.emit)
        layout.addWidget(spell_btn)

        scroll.setWidget(container)
        outer_layout.addWidget(scroll)

    def _choose_text_color(self):
        col = QColorDialog.getColor(QColor("black"), self)
        if col.isValid():
            self.set_text_color.emit(col)

    def _choose_highlight_color(self):
        col = QColorDialog.getColor(QColor("yellow"), self)
        if col.isValid():
            self.set_highlight_color.emit(col)
