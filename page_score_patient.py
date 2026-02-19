# page_score_patient.py
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QLabel, QTextEdit, QPushButton
)
from PySide6.QtCore import Qt


class ScorePatientPage(QWidget):
    """
    CLEAN REWRITE
    -------------
    - Accepts (db, parent)
    - No QWidget constructor errors
    - Ready for future scoring UI
    """

    def __init__(self, db, parent=None):
        super().__init__(parent)

        self.db = db   # store DB reference
        self._build_ui()


    # -------------------------------------------------------------------------
    def _build_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(40, 40, 40, 40)
        layout.setSpacing(20)

        title = QLabel("Score Patient")
        title.setStyleSheet("""
            QLabel {
                font-size: 26px;
                font-weight: bold;
                color: black;
            }
        """)

        instructions = QLabel(
            "This section will provide structured scoring for:\n"
            "• Risk levels\n"
            "• Mental state\n"
            "• Behaviour patterns\n"
            "• Complexity indexes\n"
        )
        instructions.setStyleSheet("font-size: 16px; color: #333;")

        self.notes_box = QTextEdit()
        self.notes_box.setPlaceholderText("Add clinician scoring notes here...")
        self.notes_box.setStyleSheet("""
            QTextEdit {
                background-color: #eef2f5;
                border: 1px solid #777;
                border-radius: 6px;
                font-size: 16px;
                padding: 8px;
            }
        """)

        save_btn = QPushButton("Save Scoring Notes")
        save_btn.setStyleSheet("""
            QPushButton {
                background-color: #0A63D8;
                color: white;
                padding: 10px;
                border-radius: 8px;
                font-size: 16px;
                font-weight: bold;
            }
            QPushButton:hover {
                background-color: #084A9A;
            }
        """)

        save_btn.clicked.connect(self._save_notes)

        layout.addWidget(title)
        layout.addWidget(instructions)
        layout.addWidget(self.notes_box)
        layout.addWidget(save_btn, alignment=Qt.AlignLeft)


    # -------------------------------------------------------------------------
    def _save_notes(self):
        """Save scoring notes into the DB (extend later)."""
        text = self.notes_box.toPlainText().strip()
        self.db.save_scoring_notes(text)   # MUST exist in database.py
