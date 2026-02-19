# ================================================================
# SIDEBAR POPUP — Draggable, With Front Page Fields + Send Button
# ================================================================

from __future__ import annotations

from PySide6.QtCore import Qt, QPoint, QPropertyAnimation, QDate
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QTextEdit, QPushButton, QLineEdit, QDateEdit
)


class SidebarPopup(QWidget):

    def __init__(self, key: str, title: str, parent=None):
        super().__init__(parent)
        self.key = key
        self.title = title

        # Stored values persist when popup reopens
        self.saved_data = {}

        # --------------------------------------------------------
        # WINDOW FLAGS — Floating + draggable
        # --------------------------------------------------------
        self.setWindowFlags(
            Qt.FramelessWindowHint |
            Qt.Tool |
            Qt.WindowStaysOnTopHint
        )
        self.setAttribute(Qt.WA_TranslucentBackground, True)
        self.setMinimumSize(320, 260)

        # --------------------------------------------------------
        # MAIN CONTAINER
        # --------------------------------------------------------
        self.container = QWidget(self)
        self.container.setObjectName("popup")
        self.container.setStyleSheet("""
            QWidget#popup {
                background: rgba(250,250,250,0.96);
                border-radius: 12px;
                border: 1px solid rgba(0,0,0,0.15);
            }
            QLabel {
                font-size: 15px;
                font-weight: 600;
                color: #222;
            }
            QLineEdit, QDateEdit {
                background: white;
                border: 1px solid rgba(0,0,0,0.15);
                border-radius: 6px;
                padding: 4px;
                font-size: 14px;
            }
        """)

        layout = QVBoxLayout(self.container)
        layout.setContentsMargins(14, 14, 14, 14)
        layout.setSpacing(10)

        # --------------------------------------------------------
        # TITLE + CLOSE BUTTON
        # --------------------------------------------------------
        top_row = QHBoxLayout()
        title_label = QLabel(title)

        close_btn = QPushButton("×")
        close_btn.setFixedSize(22, 22)
        close_btn.setObjectName("closeBtn")
        close_btn.setStyleSheet("""
            QPushButton {
                background: transparent;
                font-size: 18px;
                color: #444;
                border: none;
            }
            QPushButton:hover { color: black; }
        """)
        close_btn.clicked.connect(self.close)

        top_row.addWidget(title_label)
        top_row.addStretch()
        top_row.addWidget(close_btn)
        layout.addLayout(top_row)

        # --------------------------------------------------------
        # FRONT PAGE FIELDS
        # --------------------------------------------------------
        self.name_field = QLineEdit()
        self.dob_field = QDateEdit()
        self.dob_field.setDisplayFormat("dd/MM/yyyy")
        self.dob_field.setCalendarPopup(True)

        self.nhs_field = QLineEdit()

        self.clinician_label = QLabel("Dr Avie Luthra")
        self.date_field = QDateEdit()
        self.date_field.setDisplayFormat("dd MMMM yyyy")
        self.date_field.setDate(QDate.currentDate())
        self.date_field.setCalendarPopup(True)

        layout.addWidget(QLabel("Patient name"))
        layout.addWidget(self.name_field)

        layout.addWidget(QLabel("DOB"))
        layout.addWidget(self.dob_field)

        layout.addWidget(QLabel("NHS Number"))
        layout.addWidget(self.nhs_field)

        layout.addWidget(QLabel("Clinician"))
        layout.addWidget(self.clinician_label)

        layout.addWidget(QLabel("Date of Letter"))
        layout.addWidget(self.date_field)

        # --------------------------------------------------------
        # SEND BUTTON
        # --------------------------------------------------------
        self.send_btn = QPushButton("Send to Letter")
        self.send_btn.setObjectName("sendBtn")
        self.send_btn.setStyleSheet("""
            QPushButton#sendBtn {
                background: #008C7E;
                color: white;
                border-radius: 6px;
                padding: 6px 14px;
                font-size: 14px;
            }
            QPushButton#sendBtn:hover { background: #007266; }
        """)
        layout.addWidget(self.send_btn)

        # For dragging
        self._drag_offset = None

    # ------------------------------------------------------------
    # REMEMBER VALUES WHEN POPUP REOPENS
    # ------------------------------------------------------------
    def load_saved(self):
        if not self.saved_data:
            return
        self.name_field.setText(self.saved_data.get("name", ""))
        self.dob_field.setDate(self.saved_data.get("dob", QDate.currentDate()))
        self.nhs_field.setText(self.saved_data.get("nhs", ""))
        self.date_field.setDate(self.saved_data.get("letter_date", QDate.currentDate()))

    def save_current(self):
        self.saved_data = {
            "name": self.name_field.text(),
            "dob": self.dob_field.date(),
            "nhs": self.nhs_field.text(),
            "letter_date": self.date_field.date(),
        }

    # ------------------------------------------------------------
    # FORMAT OUTPUT FOR THE LETTER EDITOR
    # ------------------------------------------------------------
    def formatted_front_page_text(self) -> str:
        return (
            f"**Front Page**\n"
            f"**Patient:** {self.name_field.text()}\n"
            f"**DOB:** {self.dob_field.date().toString('dd/MM/yyyy')}\n"
            f"**NHS Number:** {self.nhs_field.text()}\n"
            f"**Clinician:** Dr Avie Luthra\n"
            f"**Date of Letter:** {self.date_field.date().toString('dd MMMM yyyy')}\n"
        )

    # ------------------------------------------------------------
    # Fade + show
    # ------------------------------------------------------------
    def show_with_fade(self, pos: QPoint):
        self.load_saved()  # restore previous data
        self.move(pos)
        self.raise_()
        self.setWindowOpacity(0)
        self.show()

        anim = QPropertyAnimation(self, b"windowOpacity")
        anim.setDuration(120)
        anim.setStartValue(0)
        anim.setEndValue(1)
        anim.start()
        self._anim = anim

    # ------------------------------------------------------------
    # DRAGGING
    # ------------------------------------------------------------
    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self._drag_offset = event.globalPos() - self.frameGeometry().topLeft()
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if event.buttons() & Qt.LeftButton and self._drag_offset:
            parent_rect = self.parent().geometry()
            new_pos = event.globalPos() - self._drag_offset

            x = max(parent_rect.left() + 8, min(new_pos.x(), parent_rect.right() - self.width() - 8))
            y = max(parent_rect.top() + 8, min(new_pos.y(), parent_rect.bottom() - self.height() - 8))

            self.move(x, y)

        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        self._drag_offset = None
        super().mouseReleaseEvent(event)
