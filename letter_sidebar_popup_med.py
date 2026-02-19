# ================================================================
# MEDICATION POPUP — Draggable, BNF Shown Only Here, Narrative Output
# ================================================================

from __future__ import annotations

from PySide6.QtCore import Qt, QPoint, QPropertyAnimation
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QTextEdit, QPushButton
)
from shared_widgets import add_lock_to_popup


class MedicationSidebarPopup(QWidget):

    def __init__(self, meds: list[dict], parent=None):
        super().__init__(parent)

        self.meds = meds
        self._drag_offset = None

        # ----------------------------
        # WINDOW FLAGS
        # ----------------------------
        self.setWindowFlags(
            Qt.FramelessWindowHint |
            Qt.Tool |
            Qt.WindowStaysOnTopHint
        )
        self.setAttribute(Qt.WA_TranslucentBackground, True)

        # ----------------------------
        # MAIN CONTAINER
        # ----------------------------
        self.container = QWidget(self)
        self.container.setObjectName("popup")
        self.container.setStyleSheet("""
            QWidget#popup {
                background: rgba(250,250,250,0.96);
                border-radius: 12px;
                border: 1px solid rgba(0,0,0,0.15);
            }
            QLabel {
                font-size: 21px;
                font-weight: 600;
                color: #222;
            }
            QTextEdit {
                background: white;
                border: 1px solid rgba(0,0,0,0.12);
                border-radius: 6px;
                padding: 6px;
                font-size: 21px;
                color: #222;
            }
            QPushButton#closeBtn {
                background: transparent;
                color: #444;
                font-size: 21px;
                font-weight: bold;
                border: none;
            }
            QPushButton#closeBtn:hover {
                color: #000;
            }
            QPushButton#sendBtn {
                background: #008C7E;
                color: white;
                font-size: 21px;
                padding: 6px 14px;
                border-radius: 6px;
            }
            QPushButton#sendBtn:hover {
                background: #007569;
            }
        """)

        layout = QVBoxLayout(self.container)
        layout.setContentsMargins(14, 14, 14, 14)
        layout.setSpacing(10)

        # ----------------------------
        # TITLE + CLOSE
        # ----------------------------
        top_row = QHBoxLayout()
        title_label = QLabel("Medication Summary")

        close_btn = QPushButton("×")
        close_btn.setObjectName("closeBtn")
        close_btn.setFixedSize(26, 26)
        close_btn.clicked.connect(self.close)

        top_row.addWidget(title_label)
        top_row.addStretch()
        top_row.addWidget(close_btn)
        layout.addLayout(top_row)

        # ----------------------------
        # INFO BOX WITH BNF MAXES
        # ----------------------------
        bnf_text = self._build_bnf_info()
        self.bnf_box = QTextEdit()
        self.bnf_box.setReadOnly(True)
        self.bnf_box.setMinimumHeight(100)
        self.bnf_box.setText(bnf_text)
        layout.addWidget(self.bnf_box)

        # ----------------------------
        # SEND BUTTON
        # ----------------------------
        self.send_btn = QPushButton("Send to Card")
        self.send_btn.setObjectName("sendBtn")
        layout.addWidget(self.send_btn)

        # Size
        self.setMinimumSize(340, 280)
        self.resize(360, 300)

        add_lock_to_popup(self)

    # --------------------------------------------------------
    # Build BNF info (seen only in popup)
    # --------------------------------------------------------
    def _build_bnf_info(self):
        lines = []
        for m in self.meds:
            line = f"{m['name']}: {m['dose']} ({m['bnf_max']} max)"
            lines.append(line)
        return "\n".join(lines)

    # --------------------------------------------------------
    # Narrative to be inserted into letter
    # --------------------------------------------------------
    def build_narrative(self):
        out = []
        for m in self.meds:
            out.append(f"{m['name']} {m['dose']}")
        return "\n".join(out)

    # --------------------------------------------------------
    # Fade + position
    # --------------------------------------------------------
    def show_with_fade(self, pos: QPoint):
        self.move(pos)
        self.raise_()
        self.setWindowOpacity(0.0)
        self.show()

        anim = QPropertyAnimation(self, b"windowOpacity")
        anim.setDuration(160)
        anim.setStartValue(0.0)
        anim.setEndValue(1.0)
        anim.start()
        self._anim = anim

    # --------------------------------------------------------
    # Dragging
    # --------------------------------------------------------
    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self._drag_offset = event.globalPos() - self.frameGeometry().topLeft()
            self.raise_()
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if event.buttons() & Qt.LeftButton and self._drag_offset:
            desired = event.globalPos() - self._drag_offset
            main = self.parent().window().geometry()
            pw, ph = self.width(), self.height()

            x = max(main.left() + 8, min(desired.x(), main.right() - pw - 8))
            y = max(main.top() + 8, min(desired.y(), main.bottom() - ph - 8))
            self.move(x, y)
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        self._drag_offset = None
        super().mouseReleaseEvent(event)
