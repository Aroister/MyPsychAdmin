from __future__ import annotations

from PySide6.QtCore import Qt, Signal, QPoint
from PySide6.QtWidgets import (
    QWidget, QLabel, QComboBox,
    QVBoxLayout, QHBoxLayout, QPushButton
)


# ============================================================
#  PRONOUN ENGINE (shared logic)
# ============================================================
def pronouns_from_gender(g):
    g = (g or "").lower().strip()
    if g == "male":
        return {"subj": "he", "obj": "him", "pos": "his"}
    if g == "female":
        return {"subj": "she", "obj": "her", "pos": "her"}
    return {"subj": "they", "obj": "them", "pos": "their"}
def set_gender(self, gender: str):
    self.p = pronouns_from_gender(gender)
    self._update_preview()

# ============================================================
#  OPTIONS
# ============================================================

PREVIOUS_PSYCH_OPTIONS = [
    "has never seen a psychiatrist before",
    "did not wish to discuss previous psychiatric contact",
    "has been an outpatient in the past but did not attend appointments",
    "has been an outpatient in the past without psychiatric admission",
    "has been an outpatient in the past and has had one inpatient admission",
    "has been an outpatient in the past and has had several inpatient admissions",
    "has only had inpatient psychiatric admissions",
]

GP_PSYCH_OPTIONS = [
    "has never seen their GP for psychiatric issues",
    "did not wish to discuss GP contact for psychiatric issues",
    "has occasionally seen their GP for psychiatric issues",
    "has frequently seen their GP for psychiatric issues",
    "has regular GP contact for psychiatric issues",
]

MEDICATION_OPTIONS = [
    "has never taken psychiatric medication",
    "did not wish to discuss psychiatric medication",
    "has taken psychiatric medication intermittently in the past",
    "has taken psychiatric medication regularly in the past",
    "is currently prescribed psychiatric medication with good adherence",
    "is currently prescribed psychiatric medication with variable adherence",
    "is currently prescribed psychiatric medication with poor adherence",
    "refuses psychiatric medication currently and historically",
]

COUNSELLING_OPTIONS = [
    "did not wish to discuss psychological therapy",
    "has received intermittent psychological therapy in the past",
    "is currently receiving psychological therapy",
    "has received extensive psychological therapy historically",
    "refuses psychological therapy currently and historically",
]


# ============================================================
#  POPUP
# ============================================================
class PastPsychPopup(QWidget):
    sent = Signal(str, dict)   # text, state


    def _apply_pronoun_grammar(self, phrase: str) -> str:
        phrase = phrase.strip()

        if self.p["subj"] == "they":
            for src, tgt in (("has ", "have "), ("is ", "are "), ("was ", "were ")):
                if phrase.startswith(src):
                    return tgt + phrase[len(src):]

        return phrase   # 🔴 YOU WERE MISSING THIS

    def set_gender(self, gender: str):
        self.gender = gender
        self.p = pronouns_from_gender(gender)
        self._update_preview()
        
    def _sentence_from_option(self, value: str) -> str:
        phrase = value[0].lower() + value[1:]
        phrase = self._apply_pronoun_grammar(phrase)
        return f"{self.p['subj'].capitalize()} {phrase}."

            
    def __init__(self, first_name: str = None, gender: str = None, parent=None):
        super().__init__(parent)

        self.first_name = first_name or "The patient"
        self.gender = gender
        self.p = pronouns_from_gender(gender)
        # Window behaviour — SAME AS ANXIETY
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.SubWindow)
        self.setFixedWidth(720)
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        self._drag_offset = None
        
        # --------------------------------------------------
        # CONTAINER (this fixes transparency)
        # --------------------------------------------------
        container = QWidget()
        container.setObjectName("past_psych_popup")
        container.setStyleSheet("""
            QWidget#past_psych_popup {
                background: rgba(255,255,255,0.92);
                border-radius: 18px;
                border: 1px solid rgba(0,0,0,0.25);
            }
            QLabel { color:#003c32; }
        """)
        
        outer.addWidget(container)

        layout = QVBoxLayout(container)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(12)

        # --------------------------------------------------
        # Header
        # --------------------------------------------------
        header = QHBoxLayout()
        title = QLabel("Past Psychiatric History")
        title.setStyleSheet("font-size:18px; font-weight:700;")
        header.addWidget(title)
        header.addStretch()

        close_btn = QPushButton("×")
        close_btn.setFixedSize(32, 28)
        close_btn.clicked.connect(self.close)
        header.addWidget(close_btn)

        layout.addLayout(header)

        # --------------------------------------------------
        # Rows
        # --------------------------------------------------
        self._rows = []

        def add_row(label_text, options):
            lbl = QLabel(label_text)
            lbl.setStyleSheet("font-weight:600;")

            combo = QComboBox()
            combo.addItem("Not specified", None)
            for opt in options:
                combo.addItem(opt, opt)

            combo.currentIndexChanged.connect(
                lambda _=None, c=combo: (
                    self._update_combo_highlight(c),
                    self._update_preview()
                )
            )

            layout.addWidget(lbl)
            layout.addWidget(combo)
            self._rows.append(combo)

        add_row("Previous psychiatric contact", PREVIOUS_PSYCH_OPTIONS)
        add_row("GP contact for psychiatric issues", GP_PSYCH_OPTIONS)
        add_row("Psychiatric medication", MEDICATION_OPTIONS)
        add_row("Psychological therapy / counselling", COUNSELLING_OPTIONS)

        # --------------------------------------------------
        # Preview
        # --------------------------------------------------
        self.preview = QLabel("")
        self.preview.setWordWrap(True)
        self.preview.setMinimumHeight(140)
        self.preview.setStyleSheet("""
            background:#1e1e1e;
            color:#eaeaea;
            padding:12px;
            font-size:13px;
            border-radius:10px;
        """)
        layout.addWidget(self.preview)

        # --------------------------------------------------
        # Send
        # --------------------------------------------------
        btn_row = QHBoxLayout()
        btn_row.addStretch()

        send_btn = QPushButton("Send to Letter")
        send_btn.setStyleSheet("""
            QPushButton {
                padding: 10px;
                background: #008C7E;
                color: white;
                border-radius: 6px;
                font-weight: 600;
            }
            QPushButton:hover {
                background: #007366;
            }
        """)
        send_btn.clicked.connect(self._emit_text)

        send_btn.setCursor(Qt.PointingHandCursor)
        btn_row.addWidget(send_btn)
        send_btn.setCursor(Qt.PointingHandCursor)

        layout.addLayout(btn_row)

        self._update_preview()

    # ============================================================
    # STATE SERIALISATION
    # ============================================================

    def get_state(self) -> dict:
        return {
            "indexes": [combo.currentIndex() for combo in self._rows],
            "gender": self.gender,
        }

    def load_state(self, state: dict):
        if not state:
            return

        indexes = state.get("indexes", [])
        for combo, idx in zip(self._rows, indexes):
            if isinstance(idx, int) and idx >= 0:
                combo.setCurrentIndex(idx)

        self._update_preview()
        for combo in self._rows:
            self._update_combo_highlight(combo)

    # ============================================================
    # Preview logic
    # ============================================================
    def _update_preview(self):
        self.preview.setText(self._build_text())

    def _build_text(self) -> str:
        sentences = []

        for combo in self._rows:
            value = combo.currentData()
            if not value:
                continue

            sentences.append(
                self._sentence_from_option(value)
            )

        return "\n".join(sentences)

    # ============================================================
    # Emit
    # ============================================================
    def _emit_text(self):
        text = self._build_text().strip()
        state = self.get_state()

        if text:
            self.sent.emit(text, state)
        self.close()

    # ============================================================
    # HIGHLIGHT
    # ============================================================

    def _update_combo_highlight(self, combo: QComboBox):
        if combo.currentData():
            combo.setStyleSheet("""
                QComboBox {
                    background: rgba(0,140,126,0.18);
                    border-radius: 6px;
                }
            """)
        else:
            combo.setStyleSheet("")

    # ============================================================
    # DRAG TO MOVE (RESTORED)
    # ============================================================
    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self._drag_offset = event.globalPos() - self.frameGeometry().topLeft()
        super().mousePressEvent(event)

    def mouseMoveEvent(self, event):
        if event.buttons() & Qt.LeftButton and self._drag_offset:
            self.move(event.globalPos() - self._drag_offset)
        super().mouseMoveEvent(event)

    def mouseReleaseEvent(self, event):
        self._drag_offset = None
        super().mouseReleaseEvent(event)

    def closeEvent(self, event):
        parent = self.parent()
        if parent and hasattr(parent, "store_popup_state"):
            parent.store_popup_state("psychhx", self.get_state())
        super().closeEvent(event)



