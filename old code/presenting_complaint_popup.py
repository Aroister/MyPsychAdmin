# ================================================================
# PRESENTING COMPLAINT POPUP — ADVANCED VERSION
# Features:
# • Narrow layout (420px)
# • Collapsible clusters
# • Duration/Severity/Impact collapsed by default
# • Clinician guidance text
# • Live summary prself.pronouns = pronouns  # pronouns passed as a dictionaryeview
# • RESET button
# • Drag support
# ================================================================

from __future__ import annotations

from PySide6.QtCore import Qt, QPoint, QPropertyAnimation, QTimer, QSize, Signal
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QScrollArea, QFrame, QCheckBox, QComboBox, QSlider, QTextEdit
)
from PySide6.QtWidgets import QSizePolicy

# ------------------------------------------------------------
# PRONOUNS
# ------------------------------------------------------------
def pronouns_from_gender(g: str):
    g = (g or "").strip().lower()
    if g.startswith("m"):
        return {"subj": "he", "obj": "him", "poss": "his"}
    if g.startswith("f"):
        return {"subj": "she", "obj": "her", "poss": "her"}
    return {"subj": "they", "obj": "them", "poss": "their"}
# ------------------------------------------------------------
# SYMPTOMS
# ------------------------------------------------------------
SYMPTOMS = {
    "Depressive Symptoms": [
        "low mood", "can't sleep", "tired", "can't eat",
        "memory issues", "angry", "suicidal", "cutting",
        "can't concentrate"
    ],
    "Anxiety Symptoms": [
        "anxious", "being stressed", "restless", "panic",
        "compulsions", "obsessions", "nightmares", "flashbacks"
    ],
    "Manic Features": [
        "high mood", "increased activity", "overspending", "disinhibition"
    ],
    "Psychosis Features": [
        "paranoia", "voices", "control or interference"
    ]
}

DURATIONS = [
    "one day", "a few days", "a week", "2 weeks", "3 weeks",
    "1 month", "5 weeks", "6 weeks", "7 weeks",
    "2 months", "3 months", "4 months", "5 months", "6 months",
    "6 months to 1 year", "more than a year"
]

IMPACT_OPTIONS = [
    "Work", "Relationships", "Self-care", "Social functioning",
    "Sleep", "Daily routine"
]


# ------------------------------------------------------------
# COLLAPSIBLE SECTION
# ------------------------------------------------------------
class Collapsible(QWidget):


    def __init__(self, title: str, widget: QWidget = None):
        super().__init__()


        self.expanded = False
        self.widget = widget

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 4, 0, 4)
        layout.setSpacing(4)

        # Header
        self.lbl = QLabel(f"▶ {title}")
        self.lbl.setStyleSheet("font-weight:600; font-size:14px; color:#003c32; padding:2px 0;")
        layout.addWidget(self.lbl)

        # Body
        self.body = QWidget()
        body_layout = QVBoxLayout(self.body)
        body_layout.setContentsMargins(12, 4, 0, 6)
        body_layout.setSpacing(4)

        if widget:
            body_layout.addWidget(widget)

        layout.addWidget(self.body)
        self.body.hide()

        self.lbl.mousePressEvent = self.toggle

    def toggle(self, _):
        self.expanded = not self.expanded
        if self.expanded:
            self.lbl.setText(self.lbl.text().replace("▶", "▼"))
            self.body.show()
        else:
            self.lbl.setText(self.lbl.text().replace("▼", "▶"))
            self.body.hide()


# ------------------------------------------------------------
# SYMPTOM CHECKLIST CLUSTER
# ------------------------------------------------------------
class SymptomCluster(Collapsible):

    def __init__(self, title, items):
        self.checks = []
        box = QWidget()
        layout = QVBoxLayout(box)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(2)

        for t in items:
            cb = QCheckBox(t)
            cb.setStyleSheet("font-size:13px;")
            self.checks.append(cb)
            layout.addWidget(cb)

        super().__init__(title, box)

    def get_selected(self):
        return [cb.text() for cb in self.checks if cb.isChecked()]

    def set_selected(self, vals):
        for cb in self.checks:
            cb.setChecked(cb.text() in vals)


# ------------------------------------------------------------
# IMPACT CHIPS (vertical)
# ------------------------------------------------------------
class ImpactChips(QWidget):

    def __init__(self):
        super().__init__()
        layout = QVBoxLayout(self)
        layout.setSpacing(4)
        layout.setContentsMargins(0, 0, 0, 0)

        self.buttons = []
        for t in IMPACT_OPTIONS:
            b = QPushButton(t)
            b.setCheckable(True)
            b.setStyleSheet("""
                QPushButton {
                    background: rgba(0,0,0,0.08);
                    border-radius: 8px;
                    padding: 4px 8px;
                    font-size: 13px;
                    text-align: left;
                }
                QPushButton:checked {
                    background: #008C7E;
                    color: white;
                }
            """)
            self.buttons.append(b)
            layout.addWidget(b)

    def get_selected(self):
        return [b.text() for b in self.buttons if b.isChecked()]

    def set_selected(self, vals):
        for b in self.buttons:
            b.setChecked(b.text() in vals)


# =============================================================
# PRESENTING COMPLAINT POPUP
# =============================================================
class PresentingComplaintPopup(QWidget):
    sent = Signal(str)
    closed = Signal(dict)

    def __init__(self, gender: str, pronouns: dict, db=None, cards=None, parent=None):
        super().__init__(parent)

        # Ensure pronouns is a dictionary
        if isinstance(pronouns, dict):
            self.pronouns = pronouns
        else:
            # If not a dictionary, use default pronouns based on gender
            print(f"Invalid pronouns provided: {pronouns}, falling back to defaults.")
            self.pronouns = pronouns_from_gender(gender)  # Using pronouns_from_gender to set defaults

        self.gender = gender
        self.db = db
        self.cards = cards
        
        # Dragging
        self._drag_offset = None

        self.gender = gender
        self.saved_data = {}

        # Set window properties
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.SubWindow)
        self.setMinimumWidth(460)
        self.setMaximumWidth(460)

        # WRAPPER
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)

        # -------- SCROLL WRAPPER (NON-COLLAPSING VERSION) --------
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.NoFrame)

        # FORCE scroll area to have real height before layout occurs
        scroll.setMinimumHeight(650)
        scroll.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        outer.addWidget(scroll)

        # -------- CONTAINER (ALSO NON-COLLAPSING) --------
        self.container = QWidget()
        self.container.setObjectName("pc_popup")
        self.container.setStyleSheet("""
            QWidget#pc_popup {
                background: rgba(255,255,255,0.55);
                border-radius: 18px;
                border: 1px solid rgba(0,0,0,0.25);
            }
        """)

        # hard floor height so Qt can never shrink it
        self.container.setMinimumHeight(900)
        # -------- FIX VERTICAL COLLAPSE (macOS-safe) --------
        self.setMinimumHeight(760)                        # prevents outer window collapse
        scroll.setMinimumHeight(720)                      # viewport height floor
        self.container.setSizePolicy(
                QSizePolicy.Preferred,
                QSizePolicy.Maximum                       # ⭐ critical: prevents 1-line shrink
        )
        self.container.setMinimumHeight(720)              # ensures stable full-height layout
        # ----------------------------------------------------


        scroll.setWidget(self.container)

        # macOS fix: delay-adjust size once scroll viewport exists
        QTimer.singleShot(
            0,
            lambda: self.container.resize(
                scroll.viewport().width(),
                max(900, scroll.viewport().height())
            )
        )



        layout = QVBoxLayout(self.container)
        layout.setContentsMargins(16, 16, 16, 16)
        layout.setSpacing(10)

        # TITLE BAR
        top = QHBoxLayout()
        lbl = QLabel("Presenting Complaint")
        lbl.setStyleSheet("font-weight:600; font-size:17px; color:#003c32;")
        close_btn = QPushButton("×")
        close_btn.setFixedSize(26, 26)
        close_btn.clicked.connect(self.close)
        top.addWidget(lbl)
        top.addStretch()
        top.addWidget(close_btn)
        layout.addLayout(top)

        # GUIDANCE TEXT
        guidance = QLabel(
            "Select the patient's key symptoms, duration, severity and functional impact.\n"
            "These will automatically generate a narrative summary."
        )
        guidance.setStyleSheet("font-size:12px; color:#003c32;")
        layout.addWidget(guidance)

        # CLUSTERS
        self.clusters = []
        for title, items in SYMPTOMS.items():
            c = SymptomCluster(title, items)
            self.clusters.append(c)
            layout.addWidget(c)

        # DURATION (collapsed)
        self.duration_box = QComboBox()
        self.duration_box.addItems(DURATIONS)
        self.duration_box.setStyleSheet("padding:4px; font-size:13px;")
        self.duration_section = Collapsible("Duration", self.duration_box)
        layout.addWidget(self.duration_section)

        # SEVERITY (collapsed)
        self.severity_slider = QSlider(Qt.Horizontal)
        self.severity_slider.setRange(1, 10)
        self.severity_slider.setValue(5)
        self.severity_section = Collapsible("Severity (1–10)", self.severity_slider)
        layout.addWidget(self.severity_section)

        # IMPACT (collapsed)
        self.impact_widget = ImpactChips()
        self.impact_section = Collapsible("Impact on Functioning", self.impact_widget)
        layout.addWidget(self.impact_section)

        # -------------------- PREVIEW PANEL --------------------
        self.preview_box_label = QLabel("Summary Preview")
        self.preview_box_label.setStyleSheet("font-weight:600; font-size:14px; color:#003c32;")
        layout.addWidget(self.preview_box_label)

        self.preview_box = QLabel()
        self.preview_box.setWordWrap(True)
        self.preview_box.setMinimumHeight(140)
        self.preview_box.setStyleSheet("""
                background-color: #1e1e1e;
                color: #e8e8e8;
                border-radius: 10px;
                padding: 12px;
                font-size: 13px;
        """)
        layout.addWidget(self.preview_box)

        # -------------------- LIVE PREVIEW ENGINE --------------------
        def update_preview():
                text = self.formatted_section_text()
                self.preview_box.setText(text)


        # ------------------ END PREVIEW PANEL -------------------



        # RESET + SEND
        btn_row = QHBoxLayout()
        reset_btn = QPushButton("Reset")
        reset_btn.clicked.connect(self.reset_form)
        reset_btn.setStyleSheet("padding:6px; border-radius:6px; background:#ccc;")

        self.send_btn = QPushButton("Send to Letter")
        self.send_btn.setStyleSheet("""
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
        self.send_btn.clicked.connect(self._emit_text)


        btn_row.addWidget(reset_btn)
        btn_row.addWidget(self.send_btn)
        layout.addLayout(btn_row)

        layout.addStretch()

        # Connect preview updates
        for c in self.clusters:
            for cb in c.checks:
                cb.stateChanged.connect(self.update_preview)

        self.duration_box.currentIndexChanged.connect(self.update_preview)
        self.severity_slider.valueChanged.connect(self.update_preview)
        for b in self.impact_widget.buttons:
            b.clicked.connect(self.update_preview)
    # ------------------------------------------------------------
    # HARD OVERRIDE FOR MACOS VIEWPORT COLLAPSING
    # ------------------------------------------------------------
    def sizeHint(self):
        # Force Qt to use a realistic height on creation
        return QSize(420, 900)

    def minimumSizeHint(self):
        # Prevent Qt from returning (1px, 1px) for frameless windows
        return QSize(420, 900)

    def resizeEvent(self, event):
        super().resizeEvent(event)
        try:
            # Enforce viewport + container heights after render
            scroll = self.findChild(QScrollArea)
            if scroll:
                vp = scroll.viewport()
                if vp.height() < 500:
                    vp.setMinimumHeight(900)

            if self.container.height() < 500:
                self.container.setMinimumHeight(900)

        except Exception:
            pass

        


    # ------------------------------------------------------------
    # DRAGGING
    # ------------------------------------------------------------
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
        self.save_current()
        self.closed.emit(self.saved_data)
        super().closeEvent(event)
    # ------------------------------------------------------------
    # RESET
    # ------------------------------------------------------------
    def reset_form(self):
        for c in self.clusters:
            for cb in c.checks:
                cb.setChecked(False)

        self.duration_box.setCurrentIndex(0)
        self.severity_slider.setValue(5)
        self.impact_widget.set_selected([])

        self.update_preview()

    # ------------------------------------------------------------
    # MEMORY
    # ------------------------------------------------------------
    def save_current(self):
        """
        Save all Presenting Complaint selections AND the generated text.
        Letter Writer + HPC rely on 'text' and 'formatted'.
        """
        # Base dictionary
        self.saved_data = {
            "clusters": {c.lbl.text()[2:]: c.get_selected() for c in self.clusters},
            "duration": self.duration_box.currentText(),
            "severity": self.severity_slider.value(),
            "impact": self.impact_widget.get_selected(),
        }

        # ------------------------------------------------------------
        # NEW — store generated narrative so HPC + Letter Writer can use it
        # ------------------------------------------------------------
        try:
            formatted = self.generate_text()
        except Exception:
            formatted = ""

        self.saved_data["text"] = formatted
        self.saved_data["formatted"] = formatted


    def load_saved(self):
        d = self.saved_data
        if not d:
            self.update_preview()
            return

        # Clusters
        for c in self.clusters:
            title = c.lbl.text()[2:]
            if title in d["clusters"]:
                c.set_selected(d["clusters"][title])

        self.duration_box.setCurrentText(d["duration"])
        self.severity_slider.setValue(d["severity"])
        self.impact_widget.set_selected(d["impact"])

        self.update_preview()


    # ------------------------------------------------------------
    # NARRATIVE
    # ------------------------------------------------------------
    def formatted_section_text(self):
        return self.generate_text()

    def generate_text(self):
        # Ensure pronouns are being accessed as a dictionary
        if isinstance(self.pronouns, dict):  # Check if pronouns is a dictionary
            sub, obj, poss = self.pronouns["subj"], self.pronouns["obj"], self.pronouns["poss"]
        else:
            print(f"Error: pronouns is not a dictionary: {self.pronouns}")
            # Provide fallback values in case pronouns is not a dictionary
            sub, obj, poss = "they", "them", "their"

        sub = sub.capitalize()

        # Symptom lines
        lines = []
        for c in self.clusters:
            sel = c.get_selected()
            if sel:
                joined = ", ".join(sel[:-1]) + (f" and {sel[-1]}" if len(sel) > 1 else sel[0])
                lines.append(f"{c.lbl.text()[2:]} include {joined}.")

        # Duration and severity
        duration = f"Symptoms have been present for {self.duration_box.currentText()}."
        severity = f"Severity is rated {self.severity_slider.value()} out of 10."

        # Impact
        impacts = self.impact_widget.get_selected()
        if impacts:
            joined = ", ".join(impacts[:-1]) + (f" and {impacts[-1]}" if len(impacts) > 1 else impacts[0])
            impact_line = f"These symptoms impact {poss} {joined.lower()}."
        else:
            impact_line = ""

        # Determine the verb based on the subject pronoun
        verb = "presents" if sub.lower() in ("he", "she") else "present"

        # Construct the text
        text = f"{sub} {verb} with the following symptoms:\n"
        text += "\n".join(lines) + "\n\n"
        text += duration + "\n" + severity + "\n"
        if impact_line:
            text += impact_line

        return text.strip()


    def _emit_text(self):
        self.save_current()
        text = self.saved_data.get("formatted", "").strip()
        if text:
            self.sent.emit(text)
        self.close()

    # ------------------------------------------------------------
    # LIVE PREVIEW
    # ------------------------------------------------------------
    def update_preview(self):
        self.preview_box.setText(self.generate_text())

    # ------------------------------------------------------------
    # SHOW WITH FADE
    # ------------------------------------------------------------
    def show_with_fade(self, pos: QPoint):
        pos = QPoint(int(pos.x()), int(pos.y()))
        self.move(pos)
        self.setWindowOpacity(0)
        self.show()

        anim = QPropertyAnimation(self, b"windowOpacity")
        anim.setDuration(120)
        anim.setStartValue(0.0)
        anim.setEndValue(1.0)
        anim.start()

        QTimer.singleShot(40, self.load_saved)




