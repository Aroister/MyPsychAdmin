# ================================================================
# PRESENTING COMPLAINT POPUP — RESTRUCTURED VERSION
# Features:
# • Fixed preview at top
# • Fixed severity/duration/impact section (always visible, optional)
# • Scrollable symptoms section
# ================================================================

from __future__ import annotations

from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QGridLayout, QLabel, QPushButton,
    QScrollArea, QFrame, QCheckBox, QComboBox, QSlider
)
from PySide6.QtWidgets import QSizePolicy
from shared_widgets import add_lock_to_popup
from spell_check_textedit import enable_spell_check_on_textedit

# ------------------------------------------------------------
# NO-WHEEL SLIDER (prevents scroll from changing value)
# ------------------------------------------------------------
class NoWheelSlider(QSlider):
    def wheelEvent(self, event):
        event.ignore()


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
        "being stressed", "restless", "panic",
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
    "",  # Empty = not specified
    "one day", "a few days", "a week", "2 weeks", "3 weeks",
    "1 month", "5 weeks", "6 weeks", "7 weeks",
    "2 months", "3 months", "4 months", "5 months", "6 months",
    "6 months to 1 year", "more than a year"
]

IMPACT_OPTIONS = [
    "Work", "Relationships", "Self-care",
    "Social", "Sleep", "Routine"
]


# ------------------------------------------------------------
# COLLAPSIBLE SECTION (for symptoms only)
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
        self.lbl.setWordWrap(True)
        self.lbl.setStyleSheet("font-weight:600; font-size:21px; color:#003c32; padding:2px 0;")
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

        checkbox_style = """
            QCheckBox {
                font-size: 21px;
                spacing: 8px;
                padding: 4px 0;
                color: #333;
            }
            QCheckBox::indicator {
                width: 18px;
                height: 18px;
                border: 2px solid #666;
                border-radius: 3px;
                background: #fff;
            }
            QCheckBox::indicator:unchecked {
                background: #fff;
                border: 2px solid #888;
            }
            QCheckBox::indicator:checked {
                background: #008C7E;
                border-color: #008C7E;
                image: none;
            }
            QCheckBox::indicator:hover {
                border-color: #008C7E;
            }
        """
        for t in items:
            cb = QCheckBox(t)
            cb.setStyleSheet(checkbox_style)
            self.checks.append(cb)
            layout.addWidget(cb)

        super().__init__(title, box)

    def get_selected(self):
        return [cb.text() for cb in self.checks if cb.isChecked()]

    def set_selected(self, vals):
        for cb in self.checks:
            cb.setChecked(cb.text() in vals)


# ------------------------------------------------------------
# IMPACT CHIPS (horizontal flow)
# ------------------------------------------------------------
class ImpactChips(QWidget):

    def __init__(self):
        super().__init__()
        # Use grid layout - 3 buttons per row
        layout = QGridLayout(self)
        layout.setSpacing(6)
        layout.setContentsMargins(0, 0, 0, 0)

        self.buttons = []
        for i, t in enumerate(IMPACT_OPTIONS):
            b = QPushButton(t)
            b.setCheckable(True)
            b.setStyleSheet("""
                QPushButton {
                    background: rgba(0,0,0,0.08);
                    border-radius: 8px;
                    padding: 6px 12px;
                    font-size: 15px;
                }
                QPushButton:checked {
                    background: #008C7E;
                    color: white;
                }
            """)
            self.buttons.append(b)
            row = i // 3
            col = i % 3
            layout.addWidget(b, row, col)

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

    def update_gender(self, gender: str):
        """Update pronouns when gender changes on front page."""
        self.gender = gender
        self.pronouns = pronouns_from_gender(gender)
        self.update_preview()

    def __init__(self, gender: str, pronouns: dict, db=None, cards=None, parent=None):
        super().__init__(parent)

        # Ensure pronouns is a dictionary
        if isinstance(pronouns, dict):
            self.pronouns = pronouns
        else:
            self.pronouns = pronouns_from_gender(gender)

        self.gender = gender
        self.db = db
        self.cards = cards
        self.saved_data = {}

        # Window properties
        self.setWindowFlags(Qt.WindowType.Widget)
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        # ========================================================
        # ROOT LAYOUT
        # ========================================================
        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(8)

        # ========================================================
        # SECTION 1: SEVERITY / DURATION / IMPACT (fixed, always open)
        # ========================================================
        options_container = QWidget()
        options_container.setStyleSheet("""
            QWidget {
                background: rgba(255,255,255,0.92);
                border: none;
                border-radius: 12px;
            }
            QLabel {
                background: transparent;
                border: none;
            }
        """)

        options_layout = QVBoxLayout(options_container)
        options_layout.setContentsMargins(12, 10, 12, 10)
        options_layout.setSpacing(10)

        # Duration row
        dur_row = QHBoxLayout()
        dur_label = QLabel("Duration:")
        dur_label.setStyleSheet("font-weight:600; font-size:21px; color:#003c32;")
        dur_label.setFixedWidth(90)
        self.duration_box = QComboBox()
        self.duration_box.addItems(DURATIONS)
        self.duration_box.setCurrentIndex(0)  # Default: not specified
        self.duration_box.setStyleSheet("padding:4px; font-size:21px;")
        dur_row.addWidget(dur_label)
        dur_row.addWidget(self.duration_box, 1)
        options_layout.addLayout(dur_row)

        # Severity row
        sev_row = QHBoxLayout()
        sev_label = QLabel("Severity:")
        sev_label.setStyleSheet("font-weight:600; font-size:21px; color:#003c32;")
        sev_label.setFixedWidth(90)
        self.severity_slider = NoWheelSlider(Qt.Orientation.Horizontal)
        self.severity_slider.setRange(0, 10)  # 0 = not specified
        self.severity_slider.setValue(0)  # Default: not specified
        self.severity_value = QLabel("—")
        self.severity_value.setFixedWidth(30)
        self.severity_value.setStyleSheet("font-size:21px; font-weight:600; color:#008C7E;")
        self.severity_slider.valueChanged.connect(self._update_severity_label)
        sev_row.addWidget(sev_label)
        sev_row.addWidget(self.severity_slider, 1)
        sev_row.addWidget(self.severity_value)
        options_layout.addLayout(sev_row)

        # Impact row
        impact_label = QLabel("Impact on:")
        impact_label.setStyleSheet("font-weight:600; font-size:21px; color:#003c32;")
        options_layout.addWidget(impact_label)

        self.impact_widget = ImpactChips()
        options_layout.addWidget(self.impact_widget)

        root.addWidget(options_container)

        # ========================================================
        # SECTION 3: SYMPTOMS (scrollable)
        # ========================================================
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        symptoms_container = QWidget()
        symptoms_container.setStyleSheet("""
            QWidget {
                background: rgba(255,255,255,0.92);
                border-radius: 12px;
                border: none;
            }
            QCheckBox, QLabel {
                background: transparent;
                border: none;
            }
        """)

        symptoms_layout = QVBoxLayout(symptoms_container)
        symptoms_layout.setContentsMargins(12, 10, 12, 10)
        symptoms_layout.setSpacing(6)

        symptoms_title = QLabel("Symptoms")
        symptoms_title.setStyleSheet("font-weight:600; font-size:21px; color:#003c32;")
        symptoms_layout.addWidget(symptoms_title)

        # Symptom clusters
        self.clusters = []
        for title, items in SYMPTOMS.items():
            c = SymptomCluster(title, items)
            self.clusters.append(c)
            symptoms_layout.addWidget(c)

        # Reset button at bottom
        btn_row = QHBoxLayout()
        btn_row.addStretch()
        reset_btn = QPushButton("Reset")
        reset_btn.clicked.connect(self.reset_form)
        reset_btn.setStyleSheet("padding:6px 12px; border-radius:6px; background:#ddd; font-size:21px;")
        btn_row.addWidget(reset_btn)
        symptoms_layout.addLayout(btn_row)

        symptoms_layout.addStretch()

        scroll.setWidget(symptoms_container)
        root.addWidget(scroll, 1)  # Takes remaining space

        # ========================================================
        # CONNECT SIGNALS
        # ========================================================
        for c in self.clusters:
            for cb in c.checks:
                cb.stateChanged.connect(self.update_preview)

        self.duration_box.currentIndexChanged.connect(self.update_preview)
        self.severity_slider.valueChanged.connect(self.update_preview)
        for b in self.impact_widget.buttons:
            b.clicked.connect(self.update_preview)

        # Initial preview
        self.update_preview()

        # Add lock functionality
        add_lock_to_popup(self, show_button=False)

    def _update_severity_label(self, value):
        """Update the severity value label."""
        if value == 0:
            self.severity_value.setText("—")
        else:
            self.severity_value.setText(str(value))

    def closeEvent(self, event):
        self.save_current()
        self.closed.emit(self.saved_data)
        super().closeEvent(event)

    def hideEvent(self, event):
        """Save state when popup is hidden."""
        self.save_current()
        super().hideEvent(event)

    # ------------------------------------------------------------
    # RESET
    # ------------------------------------------------------------
    def reset_form(self):
        for c in self.clusters:
            for cb in c.checks:
                cb.setChecked(False)

        self.duration_box.setCurrentIndex(0)
        self.severity_slider.setValue(0)
        self.impact_widget.set_selected([])

        self.update_preview()

    # ------------------------------------------------------------
    # MEMORY
    # ------------------------------------------------------------
    def save_current(self):
        """Save all Presenting Complaint selections AND the generated text."""
        self.saved_data = {
            "clusters": {c.lbl.text()[2:]: c.get_selected() for c in self.clusters},
            "duration": self.duration_box.currentText(),
            "severity": self.severity_slider.value(),
            "impact": self.impact_widget.get_selected(),
        }

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
            if title in d.get("clusters", {}):
                c.set_selected(d["clusters"][title])

        if d.get("duration"):
            idx = self.duration_box.findText(d["duration"])
            if idx >= 0:
                self.duration_box.setCurrentIndex(idx)

        if "severity" in d:
            self.severity_slider.setValue(d["severity"])

        if "impact" in d:
            self.impact_widget.set_selected(d["impact"])

        self.update_preview()

    # ------------------------------------------------------------
    # NARRATIVE
    # ------------------------------------------------------------
    def formatted_section_text(self):
        return self.generate_text()

    def generate_text(self):
        if isinstance(self.pronouns, dict):
            sub, obj, poss = self.pronouns["subj"], self.pronouns["obj"], self.pronouns["poss"]
        else:
            sub, obj, poss = "they", "them", "their"

        sub = sub.capitalize()

        # Transform symptom labels to clinical language
        symptom_transforms = {
            "can't sleep": "an inability to sleep",
            "can't eat": "reduced appetite",
            "angry": "being angry",
            "suicidal": "significant suicidal thoughts",
            "cutting": "concerning self harm",
            "can't concentrate": "difficulties in maintaining concentration",
            "control or interference": "thoughts of control/interference",
            "restless": "restlessness",
            "tired": "tiredness",
        }

        def transform_symptom(s):
            return symptom_transforms.get(s, s)

        # Collect selected symptoms
        symptom_parts = []
        for c in self.clusters:
            sel = c.get_selected()
            if sel:
                cluster_name = c.lbl.text()[2:].lower()
                # Transform symptoms to clinical language
                sel = [transform_symptom(s) for s in sel]
                joined = ", ".join(sel[:-1]) + (f" and {sel[-1]}" if len(sel) > 1 else sel[0])
                symptom_parts.append(f"{cluster_name} including {joined}")

        if not symptom_parts:
            return "No symptoms selected."

        # Determine verb
        verb = "presents" if sub.lower() in ("he", "she") else "present"

        # Build flowing paragraph
        parts = []

        # Opening with symptoms
        if symptom_parts:
            symptoms_text = "; ".join(symptom_parts)
            parts.append(f"{sub} {verb} with {symptoms_text}.")

        # Duration (only if specified)
        duration = self.duration_box.currentText()
        if duration:
            parts.append(f"Symptoms have been present for {duration}.")

        # Severity (only if specified, > 0)
        severity = self.severity_slider.value()
        if severity > 0:
            parts.append(f"Severity is rated {severity} out of 10.")

        # Impact (only if any selected)
        impacts = self.impact_widget.get_selected()
        if impacts:
            # Expand abbreviations for output
            expand = {
                "Relationships": "relationships",
                "Social": "social functioning",
                "Routine": "daily routine"
            }
            expanded = [expand.get(i, i.lower()) for i in impacts]
            joined = ", ".join(expanded[:-1]) + (f" and {expanded[-1]}" if len(expanded) > 1 else expanded[0])
            parts.append(f"These symptoms impact {poss} {joined}.")

        return " ".join(parts)

    def _emit_text(self):
        self.save_current()
        text = self.saved_data.get("formatted", "").strip()
        if text and text != "No symptoms selected.":
            self.sent.emit(text)
        self.close()

    # ------------------------------------------------------------
    # SEND TO CARD ON CHANGE
    # ------------------------------------------------------------
    def update_preview(self):
        """Legacy method name - now sends to card immediately."""
        self._send_to_card()

    def _send_to_card(self):
        """Send current text to card immediately."""
        self.save_current()
        text = self.saved_data.get("formatted", "").strip()
        if text and text != "No symptoms selected.":
            self.sent.emit(text)
