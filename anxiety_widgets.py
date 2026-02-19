from __future__ import annotations
from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import (
    QWidget, QLabel, QVBoxLayout, QHBoxLayout,
    QGridLayout
)

# ============================================================
#  SYMPTOM ROW (clickable)
# ============================================================
class SymptomRow(QWidget):

    clicked = Signal()

    def set_highlighted(self, active: bool):
        if active:
            self.setStyleSheet("""
                QWidget {
                    background: rgba(0,140,126,0.22);
                    border-radius: 8px;
                }
            """)
        else:
            self.setStyleSheet("""
                QWidget {
                    background: rgba(255,255,255,0.35);
                    border-radius: 8px;
                }
                QWidget:hover {
                    background: rgba(0,0,0,0.08);
                }
            """)

    def set_active(self, active: bool):
        if active:
            self.setStyleSheet("""
                QWidget {
                    background: rgba(0,140,126,0.22);
                    border-radius: 8px;
                }
            """)
        else:
            self.setStyleSheet("""
                QWidget {
                    background: rgba(255,255,255,0.35);
                    border-radius: 8px;
                }
                QWidget:hover {
                    background: rgba(0,0,0,0.08);
                }
            """)


    def __init__(self, label: str, parent=None):
        super().__init__(parent)

        self.label = label
        self.severity = 0
        self.details = ""

        lay = QHBoxLayout(self)
        lay.setContentsMargins(10, 6, 10, 6)
        lay.setSpacing(6)

        lbl = QLabel(label)
        lbl.setStyleSheet("color:#003c32; font-size:21px;")
        lay.addWidget(lbl)
        lay.addStretch()

        self.setStyleSheet("""
            QWidget {
                background: rgba(255,255,255,0.35);
                border-radius: 8px;
            }
            QWidget:hover {
                background: rgba(0,0,0,0.08);
            }
        """)

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self.clicked.emit()

    def set_value(self, severity: int, details: str):
        self.severity = severity
        self.details = details

    def get_value(self):
        return self.severity, self.details

    def set_active(self, active: bool):
        """
        Highlight row when severity or details are set.
        """
        if active:
            self.setStyleSheet("""
                QWidget {
                    background: rgba(0,140,126,0.22);
                    border-radius: 8px;
                }
            """)
        else:
            self.setStyleSheet("""
                QWidget {
                    background: rgba(255,255,255,0.35);
                    border-radius: 8px;
                }
                QWidget:hover {
                    background: rgba(0,0,0,0.08);
                }
            """)


# ============================================================
#  SYMPTOM SECTION (STABLE GRID)
# ============================================================
class SymptomSection(QWidget):

    open_editor = Signal(str)

    def __init__(self, cols: int = 4, parent=None):
        super().__init__(parent)

        self.cols = cols
        self.rows = []

        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)              # IMPORTANT
        outer.setAlignment(Qt.AlignTop)

        self.grid = QGridLayout()
        self.grid.setVerticalSpacing(8)
        self.grid.setHorizontalSpacing(24)

        outer.addLayout(self.grid)


    # ------------------------------------------------------------
    # Add symptom
    # ------------------------------------------------------------
    def add_symptom(self, label: str):
        row = SymptomRow(label)
        row.clicked.connect(lambda: self.open_editor.emit(label))

        index = self.grid.count()
        r = index // self.cols
        c = index % self.cols

        self.grid.addWidget(row, r, c)
        self.rows.append(row)
        return row

    # ------------------------------------------------------------
    # Clear grid ONLY (title untouched)
    # ------------------------------------------------------------
    def clear_rows(self):
        for r in self.rows:
            r.setParent(None)
        self.rows.clear()

        while self.grid.count():
            item = self.grid.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

    # ------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------
    def contains_label(self, label: str) -> bool:
        return any(r.label == label for r in self.rows)

    def update_value(self, label: str, sev: int, details: str):
        for r in self.rows:
            if r.label == label:
                r.set_value(sev, details)
                break

    def narrative_text(self, pron):
        fragments = []

        for r in self.rows:
            sev, det = r.get_value()
            if sev == 0:
                continue

            sev_txt = ["nil", "mild", "moderate", "severe"][sev]
            text = f"{r.label} ({sev_txt})"
            if det:
                text += f", {det}"
            fragments.append(text)

        if not fragments:
            return ""

        if len(fragments) == 1:
            return fragments[0]

        return ", ".join(fragments[:-1]) + f", and {fragments[-1]}"
