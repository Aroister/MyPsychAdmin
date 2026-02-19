from __future__ import annotations
from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QPushButton, QLabel, QHBoxLayout
)


# ============================================================
#  SYMPTOM ROW — CLICKABLE → OPENS SEVERITY POPUP
# ============================================================
class SymptomRow(QWidget):
    clicked = Signal(str)

    def __init__(self, label: str):
        super().__init__()
        self.label = label

        layout = QHBoxLayout(self)
        layout.setContentsMargins(6, 4, 6, 4)

        lbl = QLabel(label)
        lbl.setStyleSheet("font-size:15px; color:#003c32;")

        layout.addWidget(lbl)
        layout.addStretch()

        self.setCursor(Qt.PointingHandCursor)
        self.setStyleSheet("""
            QWidget {
                background: transparent;
                border-radius: 6px;
            }
            QWidget:hover {
                background: rgba(0,0,0,0.09);
            }
        """)

    def mousePressEvent(self, e):
        if e.button() == Qt.LeftButton:
            self.clicked.emit(self.label)


# ============================================================
#  SECTION CONTAINER — DYNAMIC ROW HOLDER
# ============================================================
class SymptomSection(QWidget):

    def __init__(self, title: str, start_open=True):
        super().__init__()

        self.rows = {}  # label → SymptomRow

        lay = QVBoxLayout(self)
        lay.setContentsMargins(0, 0, 0, 0)

        self.header = QPushButton(title)
        self.header.setCheckable(True)
        self.header.setChecked(start_open)
        self.header.clicked.connect(self._toggle)
        self.header.setStyleSheet("""
            QPushButton {
                font-size:15px; font-weight:600;
                text-align:left; padding:8px;
                border-radius:6px;
                background:rgba(0,0,0,0.05);
            }
            QPushButton:checked {
                background:rgba(0,0,0,0.13);
            }
        """)
        lay.addWidget(self.header)

        self.container = QWidget()
        self.container.setVisible(start_open)
        lay.addWidget(self.container)

        self.vbox = QVBoxLayout(self.container)
        self.vbox.setContentsMargins(12, 4, 12, 6)
        self.vbox.setSpacing(4)

    # Toggle open/closed
    def _toggle(self):
        self.container.setVisible(self.header.isChecked())

    # Add one symptom row
    def add_symptom(self, label: str):
        row = SymptomRow(label)
        self.rows[label] = row
        self.vbox.addWidget(row)
        return row

    # Remove all rows
    def clear_rows(self):
        for lbl, row in list(self.rows.items()):
            row.setParent(None)
        self.rows.clear()

    # Return list of labels currently in this section
    def current_labels(self):
        return list(self.rows.keys())
