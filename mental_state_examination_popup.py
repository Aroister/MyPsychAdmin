from __future__ import annotations
from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import (
    QWidget, QLabel, QPushButton,
    QVBoxLayout, QHBoxLayout,
    QScrollArea, QCheckBox, QRadioButton,
    QButtonGroup, QSlider, QSizePolicy, QFrame, QTextEdit
)
from collections import defaultdict

# Importing the dictionaries from the Psychosis, Anxiety, and Affect Popups
from psychosis_popup import DELUSION_PHRASES, THOUGHT_INTERFERENCE, PASSIVITY_PHENOMENA, AUDITORY_HALLUCINATIONS, OTHER_HALLUCINATIONS
from anxiety_popup import SYMPTOMS
from affect_popup import RowItem
from background_history_popup import CollapsibleSection
from shared_widgets import add_lock_to_popup
from spell_check_textedit import enable_spell_check_on_textedit

# ------------------------------------------------------
# NO-WHEEL SLIDER (prevents scroll from changing value)
# ------------------------------------------------------
class NoWheelSlider(QSlider):
    def wheelEvent(self, event):
        event.ignore()


# ------------------------------------------------------
# Pronoun Handling (same as before)
# ------------------------------------------------------
def pronouns_from_gender(g):
    g = (g or "").lower().strip()
    if g == "male":
        return {"subj": "he", "obj": "him", "pos": "his", "have": "has"}
    if g == "female":
        return {"subj": "she", "obj": "her", "pos": "her", "have": "has"}
    return {"subj": "they", "obj": "them", "pos": "their", "have": "have"}

def gender_noun_from_gender(g):
    g = (g or "").lower().strip()
    if g == "male":
        return "man"
    if g == "female":
        return "woman"
    return "person of unspecified gender"

def gender_noun_from_gender(g):
    g = (g or "").lower().strip()
    if g == "male":
        return "man"
    if g == "female":
        return "woman"
    return "person of unspecified gender"

# ------------------------------------------------------
# SAFE LIST JOINER (ADD THIS HERE)
# ------------------------------------------------------
def join_with_and(items: list[str]) -> str:
    if not items:
        return ""
    if len(items) == 1:
        return items[0]
    if len(items) == 2:
        return f"{items[0]} and {items[1]}"
    return ", ".join(items[:-1]) + f", and {items[-1]}"

def indefinite_article(word: str) -> str:
    return "an" if word[:1].lower() in "aeiou" else "a"

def transform_anxiety_symptoms(symptoms: list[str]) -> list[str]:
    """Transform anxiety symptom labels for better grammar in output."""
    # Individual transforms
    transforms = {
        "irritable": "being irritable",
        "dizzy/faint": "feeling dizzy/faint",
    }

    # Check for fear symptoms
    has_fear_dying = "Fear of dying" in symptoms
    has_fear_control = "Fear of losing control" in symptoms

    result = []
    for s in symptoms:
        if s == "Fear of dying" or s == "Fear of losing control":
            continue  # Handle these separately
        result.append(transforms.get(s, s))

    # Add fear symptoms with proper grammar
    if has_fear_dying and has_fear_control:
        result.append("a fear of dying and of losing control")
    elif has_fear_dying:
        result.append("a fear of dying")
    elif has_fear_control:
        result.append("a fear of losing control")

    return result

def transform_thought_symptoms(thoughts: list[str]) -> list[str]:
    """Transform thought/delusion labels for better grammar in output."""
    # Delusion transforms
    delusion_transforms = {
        "persecutory": "persecutory delusions",
        "reference": "delusions of reference",
        "delusional perception": "delusional perceptions",
        "somatic": "somatic delusions",
        "religious": "religious delusions",
        "mood/feeling": "delusions of mood/feeling",
        "guilt/worthlessness": "delusions of guilt/worthlessness",
        "infidelity/jealousy": "delusions of infidelity/jealousy",
        "nihilistic/negation": "delusions of nihilistic/negation",
        "grandiosity": "grandiose delusions",
    }

    # Thought interference items
    thought_interference = {"broadcast", "withdrawal", "insertion"}

    result = []
    ti_items = []

    for t in thoughts:
        if t in thought_interference:
            ti_items.append(t)
        elif t in delusion_transforms:
            result.append(delusion_transforms[t])
        else:
            result.append(t)

    # Group thought interference items
    if ti_items:
        if len(ti_items) == 1:
            result.append(f"delusions of thought {ti_items[0]}")
        elif len(ti_items) == 2:
            result.append(f"delusions of thought {ti_items[0]} and {ti_items[1]}")
        else:
            ti_str = ", ".join(ti_items[:-1]) + f", and {ti_items[-1]}"
            result.append(f"delusions of thought {ti_str}")

    return result

# ------------------------------------------------------
# MSE Conditions (integrating data from other files)
# ------------------------------------------------------


MOOD_SCALE = [
    "very low",
    "low",
    "slightly low",
    "normal",
    "slightly high",
    "high",
    "very high",
]

DEPRESSION_SCALE = [
    "nil",
    "mild",
    "moderate",
    "severe",
]


COGNITION_CONCERN_SCALE = [
    "nil",
    "slight",
    "mild",
    "moderate",
    "significant",
]



MSE_CONDITIONS = {
    "Demographics": {
        "Age Range": [
            "teenager (<20)",
            "early 20s",
            "mid/late 20s",
            "30s",
            "40s",
            "50s",
            "60s",
            "over 70",
        ],
        "Ethnicity": [
            "Hispanic",
            "Caucasian",
            "Afro-Caribbean",
            "Asian",
            "Middle-Eastern",
            "Mixed-race",
        ],
    },

    "Appearance": [
        "well-dressed",
        "well-presented",
        "reasonably dressed",
        "reasonably presented",
        "mildly unkempt",
        "moderately dishevelled",
        "unkempt and dishevelled",
    ],

    "Behavior": {
        "appropriate": "appropriate",
        "pleasant": "pleasant",
        "drunk": "drunk",
        "mildly anxious": "mildly anxious",
        "moderately anxious": "moderately anxious",
        "very anxious": "very anxious",
        "upset": "upset",
        "irritable": "irritable",
        "hostile": "hostile",
        "angry": "angry at times",
        "intox (alc)": "likely to be intoxicated (alcohol)",
        "intox (cannabis)": "likely to be intoxicated (cannabis)",
        "withdrawn": "withdrawn",
        "normal": "normal",
    },

    "Speech": {
        "normal": "normal",
        "loud": "loud",
        "tangential": "tangential",
        "garrulous": "garrulous",
        "Thought D -mania": "clearly suggestive of thought disorder (word salad, knights move thinking)",
        "Thought D -schizop": "clearly suggestive of thought disorder (tangential)",
        "slurred": "slurred",
    },
    "Mood": {},  # handled separately (sliders)
    "Anxiety": ["normal"] + SYMPTOMS["Anxiety/Panic/Phobia"],
    "Thoughts": (
        ["normal"]
        + list(DELUSION_PHRASES.keys())
        + list(THOUGHT_INTERFERENCE.keys())
    ),
    "Perceptions": (
        ["normal"]
        + list(AUDITORY_HALLUCINATIONS.keys())
        + list(OTHER_HALLUCINATIONS.keys())
    ),
    "Cognition": {},  # handled separately (sliders)

    "Insight": {
        "Overall": ["present", "partial", "absent"],
        "Risk": ["present", "partial", "absent"],
        "Treatment": ["present", "partial", "absent"],
        "Diagnosis": ["present", "partial", "absent"],
    },

    }

class MentalStateExaminationPopup(QWidget):
    sent = Signal(str, dict)
    closed = Signal(dict)

    def update_gender(self, gender: str):
        """Update pronouns when gender changes on front page."""
        self._gender = gender
        self.p = pronouns_from_gender(gender)
        self._refresh_preview()

    def __init__(self, first_name: str = None, gender: str = None, parent=None):
        super().__init__(parent)

        # Window behaviour — fixed panel
        self.setWindowFlags(Qt.WindowType.Widget)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)

        self._checkboxes = {category: [] for category in MSE_CONDITIONS.keys()}
        self._sentences = {}
        self._gender = gender
        self.p = pronouns_from_gender(gender)
        self._current_mse_text = ""
        self._expanded_sections = set()

        root_layout = QVBoxLayout(self)
        root_layout.setContentsMargins(0, 0, 0, 0)
        root_layout.setSpacing(8)

        # ==================================================
        # MAIN SCROLL AREA (contains form + imported data)
        # ==================================================
        main_scroll = QScrollArea()
        main_scroll.setWidgetResizable(True)
        main_scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        main_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        main_scroll.setStyleSheet("QScrollArea { background: transparent; border: none; }")

        main_container = QWidget()
        main_container.setStyleSheet("background: transparent;")
        main_layout = QVBoxLayout(main_container)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(8)

        # Form container
        container = QWidget()
        container.setStyleSheet("""
        QWidget {
                background: rgba(255,255,255,0.92);
                border-radius: 12px;
                border: 1px solid rgba(0,0,0,0.15);
        }

        QRadioButton,
        QCheckBox {
                background: transparent;
                border: none;
                padding: 2px 0px;
                spacing: 8px;
                font-size: 22px;
        }

        QLabel {
                background: transparent;
                border: none;
        }
        """)

        self.form = QVBoxLayout(container)
        self.form.setContentsMargins(16, 14, 16, 14)
        self.form.setSpacing(6)

        # Add sections dynamically (No changes needed)
        def section(title: str):
            lbl = QLabel(title)
            lbl.setStyleSheet("""
                    QLabel {
                        font-size: 21px;
                        font-weight: 600;
                        color:#003c32;
                        padding-top: 10px;
                        padding-bottom: 6px;
                        border: none;
                        border-bottom:1px solid rgba(0,0,0,0.08);
                    }
            """)
            self.form.addWidget(lbl)

        # Adding checkbox handling for MSE conditions (change for Anxiety, Thoughts, Perceptions)
        # Adding checkbox handling for MSE conditions
        for category, items in MSE_CONDITIONS.items():
            section_container, arrow = self.collapsible_section(category)

            # Ensure category bucket exists
            self._checkboxes.setdefault(category, [])

            # ------------------------------
            # DEMOGRAPHICS (Age + Ethnicity)
            # ------------------------------
            if category == "Demographics":
                for subcategory, options in items.items():
                    sub_lbl = QLabel(subcategory)
                    sub_lbl.setStyleSheet("""
                        QLabel {
                            font-size: 21px;
                            font-weight: 600;
                            color: #003c32;
                            margin-top: 6px;
                        }
                    """)
                    section_container.layout().addWidget(sub_lbl)

                    group = QButtonGroup(self)
                    group.setExclusive(True)

                    for opt in options:
                        rb = QRadioButton(opt)
                        rb.setStyleSheet("""
                            QRadioButton {
                                font-size: 22px;
                                background: transparent;
                            }
                            QRadioButton::indicator {
                                width: 18px;
                                height: 18px;
                            }
                        """)
                        rb._demographic_key = subcategory
                        group.addButton(rb)

                        self._checkboxes.setdefault(subcategory, []).append(rb)
                        rb.toggled.connect(self._refresh_preview)
                        section_container.layout().addWidget(rb)
                continue

            # ------------------------------
            # INSIGHT
            # ------------------------------
            if category == "Insight":
                for subcategory, options in items.items():
                    sub_lbl = QLabel(subcategory)
                    sub_lbl.setStyleSheet("""
                        QLabel {
                            font-size: 21px;
                            font-weight: 600;
                            color: #003c32;
                            margin-top: 6px;
                        }
                    """)
                    section_container.layout().addWidget(sub_lbl)

                    group = QButtonGroup(self)
                    group.setExclusive(True)

                    for opt in options:
                        rb = QRadioButton(opt)
                        rb.setStyleSheet("""
                            QRadioButton {
                                font-size: 22px;
                                background: transparent;
                            }
                            QRadioButton::indicator {
                                width: 18px;
                                height: 18px;
                            }
                        """)
                        rb._insight_key = f"Insight {subcategory}"
                        group.addButton(rb)

                        self._checkboxes.setdefault(rb._insight_key, []).append(rb)
                        rb.toggled.connect(self._refresh_preview)
                        section_container.layout().addWidget(rb)
                continue

            # ------------------------------
            # MOOD (3 sliders)
            # ------------------------------
            if category == "Mood":
                self._mood_state = {}
                self._mood_sliders = {}  # Store slider references

                def mood_slider(title: str, labels: list[str], key: str):
                    lbl = QLabel(title)
                    lbl.setStyleSheet("""
                        QLabel {
                            font-size: 21px;
                            font-weight: 600;
                            color: #003c32;
                            margin-top: 6px;
                        }
                    """)
                    section_container.layout().addWidget(lbl)

                    slider = NoWheelSlider(Qt.Horizontal)
                    slider.setMinimum(0)
                    slider.setMaximum(len(labels) - 1)
                    slider.setValue(
                        labels.index("normal") if "normal" in labels else 0
                    )
                    slider.setTickPosition(QSlider.TicksBelow)
                    slider.setTickInterval(1)

                    value_lbl = QLabel(labels[slider.value()])
                    value_lbl.setStyleSheet("color:#555;font-size:21px;")

                    def on_change(v):
                        value_lbl.setText(labels[v])
                        self._mood_state[key] = labels[v]
                        self._refresh_preview()

                    slider.valueChanged.connect(on_change)

                    section_container.layout().addWidget(slider)
                    section_container.layout().addWidget(value_lbl)

                    # Store reference to slider and labels
                    self._mood_sliders[key] = {"slider": slider, "labels": labels, "value_lbl": value_lbl}

                mood_slider("Objective mood", MOOD_SCALE, "Mood Objective")
                mood_slider("Subjective mood", MOOD_SCALE, "Mood Subjective")
                mood_slider("Depressive features", DEPRESSION_SCALE, "Mood Depression")
                continue

            # ------------------------------
            # BEHAVIOR (label → narrative map)
            # ------------------------------
            if category == "Behavior":
                for label, narrative in items.items():
                    rb = QRadioButton(label)
                    rb.setStyleSheet("""
                        QRadioButton {
                            font-size: 22px;
                            background: transparent;
                        }
                        QRadioButton::indicator {
                            width: 18px;
                            height: 18px;
                        }
                    """)
                    rb._mapped_value = narrative
                    self._checkboxes[category].append(rb)
                    rb.toggled.connect(self._refresh_preview)
                    section_container.layout().addWidget(rb)
                continue

            # ------------------------------
            # SPEECH (label → narrative map)
            # ------------------------------
            if category == "Speech":
                for label, narrative in items.items():
                    rb = QRadioButton(label)
                    rb.setStyleSheet("""
                        QRadioButton {
                            font-size: 22px;
                            background: transparent;
                        }
                        QRadioButton::indicator {
                            width: 18px;
                            height: 18px;
                        }
                    """)
                    rb._mapped_value = narrative
                    self._checkboxes[category].append(rb)
                    rb.toggled.connect(self._refresh_preview)
                    section_container.layout().addWidget(rb)
                continue


            # ------------------------------
            # COGNITION (concern slider)
            # ------------------------------
            if category == "Cognition":
                self._cognition_state = "nil"

                lbl = QLabel("Cognitive concern")
                lbl.setStyleSheet("""
                    QLabel {
                        font-size: 21px;
                        font-weight: 600;
                        color: #003c32;
                        margin-top: 6px;
                    }
                """)
                section_container.layout().addWidget(lbl)

                slider = NoWheelSlider(Qt.Horizontal)
                slider.setMinimum(0)
                slider.setMaximum(len(COGNITION_CONCERN_SCALE) - 1)
                slider.setValue(0)
                slider.setTickPosition(QSlider.TicksBelow)
                slider.setTickInterval(1)

                value_lbl = QLabel("nil")
                value_lbl.setStyleSheet("color:#555;font-size:21px;")

                def on_change(v):
                    self._cognition_state = COGNITION_CONCERN_SCALE[v]
                    value_lbl.setText(self._cognition_state)
                    self._refresh_preview()

                slider.valueChanged.connect(on_change)

                section_container.layout().addWidget(slider)
                section_container.layout().addWidget(value_lbl)

                # Store reference to cognition slider
                self._cognition_slider = {"slider": slider, "value_lbl": value_lbl}
                continue

            # ------------------------------
            # DEFAULT MULTI-SELECT CATEGORIES
            # ------------------------------
            is_checkbox_category = category in [
                "Anxiety",
                "Thoughts",
                "Perceptions",    
            ]

            for name in items:
                if is_checkbox_category:
                    cb = QCheckBox(name)
                    self._checkboxes[category].append(cb)

                    if name == "normal":
                        cb.toggled.connect(
                            lambda checked, c=category, b=cb:
                                self._handle_normal_exclusive(c, b)
                        )

                    cb.toggled.connect(self._refresh_preview)
                    section_container.layout().addWidget(cb)

                else:
                    rb = QRadioButton(name)
                    rb.setStyleSheet("""
                        QRadioButton {
                            font-size: 22px;
                            background: transparent;
                        }
                        QRadioButton::indicator {
                            width: 18px;
                            height: 18px;
                        }
                    """)
                    self._checkboxes[category].append(rb)
                    rb.toggled.connect(self._refresh_preview)
                    section_container.layout().addWidget(rb)

        # Add form container to main layout
        main_layout.addWidget(container)

        # ==================================================
        # IMPORTED DATA SECTION
        # ==================================================
        self.extracted_section = CollapsibleSection("Imported Data", start_collapsed=True)
        self.extracted_section.set_header_style("""
            QFrame {
                background: rgba(180, 150, 50, 0.25);
                border: 1px solid rgba(180, 150, 50, 0.5);
                border-radius: 6px 6px 0 0;
            }
        """)
        self.extracted_section.title_label.setStyleSheet("""
            QLabel {
                font-size: 21px;
                font-weight: 600;
                color: #806000;
                background: transparent;
                border: none;
            }
        """)

        extracted_content = QWidget()
        extracted_content.setStyleSheet("""
            QWidget {
                background: rgba(255, 248, 220, 0.95);
                border: 1px solid rgba(180, 150, 50, 0.4);
                border-top: none;
                border-radius: 0 0 12px 12px;
            }
            QCheckBox {
                background: transparent;
                border: none;
                padding: 4px;
                font-size: 22px;
                color: #4a4a4a;
            }
            QCheckBox::indicator {
                width: 16px;
                height: 16px;
            }
        """)

        extracted_layout = QVBoxLayout(extracted_content)
        extracted_layout.setContentsMargins(12, 10, 12, 10)
        extracted_layout.setSpacing(6)

        extracted_scroll = QScrollArea()
        extracted_scroll.setWidgetResizable(True)
        extracted_scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        extracted_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        extracted_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        extracted_scroll.setStyleSheet("""
            QScrollArea { background: transparent; border: none; }
            QScrollArea > QWidget > QWidget { background: transparent; }
        """)

        self.extracted_container = QWidget()
        self.extracted_container.setStyleSheet("background: transparent;")
        self.extracted_checkboxes_layout = QVBoxLayout(self.extracted_container)
        self.extracted_checkboxes_layout.setContentsMargins(2, 2, 2, 2)
        self.extracted_checkboxes_layout.setSpacing(12)
        self.extracted_checkboxes_layout.setAlignment(Qt.AlignTop)

        extracted_scroll.setWidget(self.extracted_container)
        extracted_layout.addWidget(extracted_scroll)

        self.extracted_section.set_content(extracted_content)
        self.extracted_section.setVisible(False)
        main_layout.addWidget(self.extracted_section)

        # Store extracted checkboxes
        self._extracted_checkboxes = []

        # Add stretch and set up scroll area
        main_layout.addStretch()
        main_scroll.setWidget(main_container)
        root_layout.addWidget(main_scroll, 1)

        # Refresh the preview initially
        self._refresh_preview()

        add_lock_to_popup(self, show_button=False)

    # -----------------------------------------------------
    # Get Pronoun Verb (No changes needed)
    # -----------------------------------------------------
    def get_pronoun_verb(self):
        # Fetch the verb from the pronoun dictionary. Default to "have" if not found.
        return self.p.get("have", "have")

    # -----------------------------------------------------
    # Create_on_checked_handler (No changes needed)
    # -----------------------------------------------------
    def create_on_checked_handler(self, container, arrow, category):
        def on_checked(state):
            print(f"Checkbox state changed for {category}")  # Debugging line
            any_checked = any(cb.isChecked() for cb in self._checkboxes[category])
            if state and not container.isVisible():
                container.setVisible(True)
                arrow.setText("▾")
            elif not any_checked:
                container.setVisible(False)
                arrow.setText("▸")
            self._refresh_preview()  # Only refresh when necessary
        return on_checked

    # -----------------------------------------------------
    # Preview Handling (No changes needed)
    # -----------------------------------------------------
    def update_preview(self):
        p = self.p
        subj = p["subj"].capitalize()

        def selected(ns: str, mapping: dict[str, str]) -> list[str]:
            return [
                phrase for k, phrase in mapping.items()
                if f"{ns}|{k}" in self.values
            ]

        lines: list[str] = []

        # ---- Age Range
        age_range = selected("age", MSE_CONDITIONS["Age Range"])
        if age_range:
            lines.append(f"The patient is in the age range of {join_with_and(age_range)}.")

        # ---- Ethnicity
        ethnicity = selected("ethnicity", MSE_CONDITIONS["Ethnicity"])
        if ethnicity:
            lines.append(f"The patient's ethnicity is {join_with_and(ethnicity)}.")

        # ---- Anxiety
        anxiety = selected("anx", SYMPTOMS["Anxiety/Panic/Phobia"])
        if anxiety:
            transformed = transform_anxiety_symptoms(anxiety)
            lines.append(f"The patient reported anxiety symptoms, including {join_with_and(transformed)}.")

        # ---- Thoughts
        thoughts = selected("del", THOUGHT_INTERFERENCE)
        if thoughts:
            lines.append(f"Thoughts were characterized by {join_with_and(thoughts)}.")

        # ---- Perceptions
        perceptions = selected("hal", AUDITORY_HALLUCINATIONS) + selected("hal", OTHER_HALLUCINATIONS)
        if perceptions:
            lines.append(f"Perceptions included {join_with_and(perceptions)}.")

        # ---- Insight
        insight_overall = selected("insight_overall", ["present", "partial", "absent"])
        if insight_overall:
            lines.append(f"Overall insight: {join_with_and(insight_overall)}.")

        insight_risk = selected("insight_risk", ["present", "partial", "absent"])
        if insight_risk:
            lines.append(f"Insight into risk: {join_with_and(insight_risk)}.")

        insight_treatment = selected("insight_treatment", ["present", "partial", "absent"])
        if insight_treatment:
            lines.append(f"Insight into treatment: {join_with_and(insight_treatment)}.")

        insight_diagnosis = selected("insight_diagnosis", ["present", "partial", "absent"])
        if insight_diagnosis:
            lines.append(f"Insight into diagnosis: {join_with_and(insight_diagnosis)}.")

        # Formatting for severity and associated conditions
        self.preview.setText("\n".join(lines))





    # ======================================================
    # COLLAPSIBLE SECTIONS
    # ======================================================
    def collapsible_section(self, title: str):
        header = QWidget()
        header.setFocusPolicy(Qt.NoFocus)
        header.setStyleSheet("background: transparent;")

        h = QHBoxLayout(header)
        h.setContentsMargins(0, 10, 0, 6)
        h.setSpacing(8)

        arrow = QLabel("▸")
        arrow.setFixedWidth(22)
        arrow.setAlignment(Qt.AlignCenter)
        arrow.setStyleSheet("""
            QLabel {
                font-size: 21px;
                font-weight: 700;
                color: #6E6E6E;
                background: transparent;
            }
        """)

        lbl = QLabel(title)
        lbl.setStyleSheet("""
            QLabel {
                font-size: 21px;
                font-weight: 600;
                color: #6E6E6E;
                background: transparent;
            }
        """)

        h.addWidget(arrow)
        h.addWidget(lbl)
        h.addStretch()

        divider = QLabel()
        divider.setFixedHeight(1)
        divider.setStyleSheet("""
            background: rgba(0,0,0,0.08);
            margin-left: 22px;
        """)

        container = QWidget()
        container.setVisible(False)
        v = QVBoxLayout(container)
        v.setContentsMargins(22, 6, 0, 10)
        v.setSpacing(6)

        if title in self._expanded_sections:
            container.setVisible(True)
            arrow.setText("▾")

        def toggle():
            visible = not container.isVisible()
            container.setVisible(visible)
            arrow.setText("▾" if visible else "▸")

            if visible:
                self._expanded_sections.add(title)
            else:
                self._expanded_sections.discard(title)

        header.mousePressEvent = lambda e: toggle()

        self.form.addWidget(header)
        self.form.addWidget(divider)
        self.form.addWidget(container)

        return container, arrow

    # ------------------------------NORMAL HANDLER ------------------------------

    def _handle_normal_exclusive(self, category: str, toggled_box):
        boxes = self._checkboxes.get(category, [])

        if toggled_box.text() != "normal":
            return

        if toggled_box.isChecked():
            for cb in boxes:
                if cb is not toggled_box:
                    cb.blockSignals(True)
                    cb.setChecked(False)
                    cb.setEnabled(False)
                    cb.blockSignals(False)
        else:
            for cb in boxes:
                if cb is not toggled_box:
                    cb.setEnabled(True)


    # ------------------------------REFRESH PREVIEW ------------------------------

    def _refresh_preview(self):
        if hasattr(self, '_is_updating') and self._is_updating:
            return

        self._is_updating = True

        selected_conditions = []

        # ------------------------------
        # COLLECT RADIO / CHECKBOX INPUTS
        # ------------------------------
        for category, rb_list in self._checkboxes.items():
            for rb in rb_list:
                if not rb.isChecked():
                    continue

                # INSIGHT
                if hasattr(rb, "_insight_key"):
                    selected_conditions.append(
                        (rb._insight_key, rb.text())
                    )

                # DEMOGRAPHICS
                elif hasattr(rb, "_demographic_key"):
                    selected_conditions.append(
                        (rb._demographic_key, rb.text())
                    )

                # MAPPED SECTIONS (Behaviour / Speech)
                elif hasattr(rb, "_mapped_value"):
                    selected_conditions.append(
                        (category, rb._mapped_value)
                    )

                # DEFAULT
                else:
                    selected_conditions.append(
                        (category, rb.text())
                    )

        # ------------------------------
        # MOOD (SLIDER-BASED — ONLY IF SET)
        # ------------------------------
        if hasattr(self, "_mood_state") and self._mood_state:
            for key, value in self._mood_state.items():
                if value is not None:
                    selected_conditions.append((key, value))

        # ------------------------------
        # COGNITION (slider-based — ONLY IF MEANINGFUL)
        # ------------------------------
        if hasattr(self, "_cognition_state"):
            if self._cognition_state and self._cognition_state != "nil":
                selected_conditions.append(
                    ("Cognition Concern", self._cognition_state)
                )
            else:
                # still include nil explicitly so formatter can output
                selected_conditions.append(
                    ("Cognition Concern", "nil")
                )

        # ------------------------------
        # SEND TO CARD
        # ------------------------------
        if selected_conditions:
            text = self.formatted_text(selected_conditions)
            self._current_mse_text = text
            if text.strip():
                self.sent.emit(
                    text,
                    {
                        "section": "Mental State Examination",
                        "state": self.get_state(),
                    }
                )

        self._is_updating = False


    # ------------------------------FORMATTED TEXT ------------------------------
    def formatted_text(self, selected_conditions) -> str:
        """
        Creates a flowing clinical narrative based on the selected MSE conditions.
        """
        groups = defaultdict(list)
        subj = self.p["subj"].capitalize()
        obj = self.p["obj"]
        pos = self.p["pos"]
        be = "was" if self.p["subj"] in ["he", "she"] else "were"

        # --------------------------------
        # Group conditions by category
        # --------------------------------
        for item in selected_conditions:

            # ------------------------------
            # INSIGHT (explicit key/value)
            # ------------------------------
            if isinstance(item, tuple):
                key, value = item
                groups[key].append(value)
                continue

            # ------------------------------
            # DEFAULT CATEGORIES
            # ------------------------------
            for category, items in MSE_CONDITIONS.items():
                if isinstance(items, list) and item in items:
                    groups[category].append(item)

        narrative = []

        # ------------------------------
        # DEMOGRAPHICS (Age + Ethnicity + Gender)
        # ------------------------------
        age = join_with_and(groups.get("Age Range", []))
        ethnicity = join_with_and(groups.get("Ethnicity", []))

        subj = self.p["subj"].capitalize()
        pos = self.p["pos"]
        be = "was" if self.p["subj"] in ["he", "she"] else "were"
        gender_noun = gender_noun_from_gender(self._gender)

        parts = []

        if ethnicity:
            parts.append(ethnicity)

        if gender_noun:
            parts.append(gender_noun)

        if age:
            if age.startswith("teenager"):
                parts.append("a teenager")
            elif age.endswith("s") or age.startswith("over"):
                parts.append(f"in {pos} {age}")
            else:
                parts.append(age)

        if parts:
            # Use "an" for words starting with vowel sounds
            description = ' '.join(parts)
            article = "an" if description and description[0].lower() in "aeiou" else "a"

            if "a teenager" in parts:
                parts.remove("a teenager")
                description = ' '.join(parts)
                article = "an" if description and description[0].lower() in "aeiou" else "a"
                narrative.append(
                    f"{subj} {be} {article} {description}, a teenager."
                )
            else:
                narrative.append(
                    f"{subj} {be} {article} {description}."
                )


        # Describe Appearance
        if "Appearance" in groups:
            appearance_conditions = join_with_and(groups["Appearance"])
            narrative.append(
                f"{subj} {be} {appearance_conditions}."
            )

        # Describe Behavior
        if "Behavior" in groups:
            behavior_conditions = join_with_and(groups["Behavior"])
            narrative.append(
                f"In terms of behaviour, {subj.lower()} {be} {behavior_conditions}."
            )

        # Describe Speech
        if "Speech" in groups:
            speech_conditions = join_with_and(groups["Speech"])
            narrative.append(
                f"{pos.capitalize()} speech was {speech_conditions}."
            )

        # ------------------------------
        # MOOD (objective / subjective / depressive features)
        # ------------------------------
        obj = groups.get("Mood Objective")
        subj = groups.get("Mood Subjective")
        dep = groups.get("Mood Depression")

        if obj or subj:
            # If both objective and subjective moods are the same, combine them
            if obj and subj and obj[0] == subj[0]:
                narrative.append(
                    f"Mood was objectively and subjectively {obj[0]}."
                )
            else:
                parts = []
                if obj:
                    parts.append(f"objectively {obj[0]}")
                if subj:
                    parts.append(f"subjectively {subj[0]}")
                narrative.append(
                    f"Mood was {join_with_and(parts)}."
                )

        if dep and dep[0] != "nil":
            narrative.append(
                f"There were {dep[0]} depressive features."
            )


        # ------------------------------
        # ANXIETY
        # ------------------------------
        if "Anxiety" in groups:
            anxiety = groups["Anxiety"]

            if "normal" in anxiety:
                narrative.append(
                    "There was no evidence of pathological anxiety."
                )
            else:
                transformed = transform_anxiety_symptoms(anxiety)
                joined = join_with_and(transformed)
                narrative.append(
                    f"{self.p['subj'].capitalize()} reported anxiety symptoms, including {joined}."
                )

        # ------------------------------
        # THOUGHTS (DELUSIONS / INTERFERENCE)
        # ------------------------------
        if "Thoughts" in groups:
            thoughts = groups["Thoughts"]

            if "normal" in thoughts:
                narrative.append(
                    f"{self.p['pos'].capitalize()} thoughts were normal."
                )
            else:
                transformed = transform_thought_symptoms(thoughts)
                joined = join_with_and(transformed)
                narrative.append(
                    f"{self.p['pos'].capitalize()} thoughts were characterised by {joined}."
                )

        # ------------------------------
        # PERCEPTIONS (HALLUCINATIONS)
        # ------------------------------
        if "Perceptions" in groups:
            perceptions = groups["Perceptions"]

            if "normal" in perceptions:
                narrative.append(
                    "There was no evidence of perceptual disturbance."
                )
            else:
                joined = join_with_and(perceptions)
                narrative.append(
                    f"{self.p['subj'].capitalize()} reported {joined} hallucinations."
                )

        # ------------------------------
        # COGNITION (concern-based)
        # ------------------------------
        concern = groups.get("Cognition Concern")

        if concern:
            level = concern[0]

            if level == "nil":
                narrative.append(
                    "Cognition was broadly intact and not assessed clinically."
                )
            else:
                narrative.append(
                    f"Cognition was of {level} concern and requires further assessment."
                )

        # ------------------------------
        # INSIGHT (overall + qualifiers grouped by value)
        # ------------------------------
        overall = groups.get("Insight Overall")
        risk = groups.get("Insight Risk")
        treatment = groups.get("Insight Treatment")
        diagnosis = groups.get("Insight Diagnosis")

        if overall:
            # Group subcategories by their value (present/partial/absent)
            value_groups = {}
            if risk:
                value_groups.setdefault(risk[0], []).append("risk")
            if treatment:
                value_groups.setdefault(treatment[0], []).append("treatment")
            if diagnosis:
                value_groups.setdefault(diagnosis[0], []).append("diagnosis")

            if value_groups:
                # Build qualifier phrases grouped by value
                qualifier_phrases = []
                is_first = True

                for value, categories in value_groups.items():
                    if len(categories) == 1:
                        cat_str = categories[0]
                    elif len(categories) == 2:
                        cat_str = f"{categories[0]} and {categories[1]}"
                    else:
                        cat_str = ", ".join(categories[:-1]) + f", and {categories[-1]}"

                    if is_first:
                        qualifier_phrases.append(f"insight into {cat_str} being {value}")
                        is_first = False
                    else:
                        qualifier_phrases.append(f"into {cat_str} being {value}")

                joined_qualifiers = ", and ".join(qualifier_phrases)
                narrative.append(
                    f"Insight was {overall[0]} overall, with {joined_qualifiers}."
                )
            else:
                narrative.append(
                    f"Insight was {overall[0]} overall."
                )


        # Combine the narrative into a single flowing string
        final_narrative = " ".join(narrative)

        return final_narrative

    # ------------------------------SEND AND SAVE ------------------------------

    def _send(self):
        if not getattr(self, "_current_mse_text", "").strip():
            return

        self.sent.emit(
            self._current_mse_text,
            {
                "section": "Mental State Examination",
                "state": self.get_state(),
            }
        )

        self.close()


    def get_state(self) -> dict:
        """
        Canonical snapshot of the MSE popup state.
        Used for memory on close + restore on reopen.
        """

        checkbox_state = {}

        for category, widgets in self._checkboxes.items():
            selected = []
            for w in widgets:
                if w.isChecked():
                    if hasattr(w, "_mapped_value"):
                        selected.append(w._mapped_value)
                    else:
                        selected.append(w.text())
            if selected:
                checkbox_state[category] = selected

        return {
            "checkboxes": checkbox_state,
            "mood": getattr(self, "_mood_state", {}).copy(),
            "cognition": getattr(self, "_cognition_state", None),
        }


    def closeEvent(self, event):
        try:
            self.closed.emit(self.get_state())
        except Exception as e:
            print("[MSE] ❌ Failed to emit close state:", e)
        super().closeEvent(event)

        
    def load_state(self, state: dict):
        if not state:
            return

        # ------------------------------
        # RADIO / CHECKBOX RESTORE
        # ------------------------------
        checked = state.get("checked", {})
        for category, values in checked.items():
            for w in self._checkboxes.get(category, []):
                if w.text() in values or getattr(w, "_mapped_value", None) in values:
                    w.setChecked(True)

        # ------------------------------
        # MOOD SLIDERS
        # ------------------------------
        if hasattr(self, "_mood_state") and hasattr(self, "_mood_sliders"):
            for k, v in state.get("mood", {}).items():
                self._mood_state[k] = v
                # Also set the actual slider widget
                if k in self._mood_sliders:
                    slider_info = self._mood_sliders[k]
                    labels = slider_info["labels"]
                    if v in labels:
                        idx = labels.index(v)
                        slider_info["slider"].blockSignals(True)
                        slider_info["slider"].setValue(idx)
                        slider_info["value_lbl"].setText(v)
                        slider_info["slider"].blockSignals(False)

        # ------------------------------
        # COGNITION SLIDER
        # ------------------------------
        if "cognition" in state:
            self._cognition_state = state["cognition"]
            # Also set the actual slider widget
            if hasattr(self, "_cognition_slider") and state["cognition"] in COGNITION_CONCERN_SCALE:
                idx = COGNITION_CONCERN_SCALE.index(state["cognition"])
                self._cognition_slider["slider"].blockSignals(True)
                self._cognition_slider["slider"].setValue(idx)
                self._cognition_slider["value_lbl"].setText(state["cognition"])
                self._cognition_slider["slider"].blockSignals(False)

        self._refresh_preview()


    def get_state(self) -> dict:
        """
        Canonical snapshot of the MSE popup.
        Used for BOTH Send and Close.
        """

        state = {
            "checked": {},
            "mood": {},
            "cognition": None,
        }

        # ------------------------------
        # RADIO / CHECKBOX VALUES
        # ------------------------------
        for category, widgets in self._checkboxes.items():
            selected = []
            for w in widgets:
                if w.isChecked():
                    if hasattr(w, "_mapped_value"):
                        selected.append(w._mapped_value)
                    else:
                        selected.append(w.text())
            if selected:
                state["checked"][category] = selected

        # ------------------------------
        # MOOD SLIDERS
        # ------------------------------
        if hasattr(self, "_mood_state"):
            state["mood"] = dict(self._mood_state)

        # ------------------------------
        # COGNITION SLIDER
        # ------------------------------
        if hasattr(self, "_cognition_state"):
            state["cognition"] = self._cognition_state

        return state

    # ============================================================
    #  IMPORTED DATA FROM NOTES
    # ============================================================
    def set_extracted_data(self, items):
        """Display extracted data from notes with collapsible dated entry boxes."""
        # Clear existing
        for cb in self._extracted_checkboxes:
            cb.setParent(None)
            cb.deleteLater()
        self._extracted_checkboxes.clear()

        # Remove old widgets from layout
        while self.extracted_checkboxes_layout.count():
            item = self.extracted_checkboxes_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        # Handle legacy string format
        if isinstance(items, str):
            items = [{"date": None, "text": p.strip()} for p in items.split("\n\n") if p.strip()]

        if not items:
            self.extracted_section.setVisible(False)
            return

        # Sort by date (newest first)
        from datetime import datetime
        def get_sort_date(item):
            d = item.get("date")
            if d is None:
                return datetime.min
            if isinstance(d, datetime):
                return d
            if isinstance(d, str):
                for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%d %b %Y", "%d %B %Y"):
                    try:
                        return datetime.strptime(d, fmt)
                    except ValueError:
                        continue
            return datetime.min

        sorted_items = sorted(items, key=get_sort_date, reverse=True)

        for item in sorted_items:
            text = item.get("text", "")
            date_val = item.get("date")

            # Format date string
            if date_val:
                if isinstance(date_val, datetime):
                    date_str = date_val.strftime("%d %b %Y")
                elif isinstance(date_val, str):
                    dt = None
                    for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%d %b %Y", "%d %B %Y"):
                        try:
                            dt = datetime.strptime(date_val, fmt)
                            break
                        except ValueError:
                            continue
                    if dt:
                        date_str = dt.strftime("%d %b %Y")
                    else:
                        date_str = str(date_val)
                else:
                    date_str = str(date_val)
            else:
                date_str = "No date"

            # Create collapsible entry box
            entry_frame = QFrame()
            entry_frame.setObjectName("entryFrame")
            entry_frame.setSizePolicy(QSizePolicy.Policy.Preferred, QSizePolicy.Policy.Minimum)
            entry_frame.setStyleSheet("""
                QFrame#entryFrame {
                    background: rgba(255, 255, 255, 0.95);
                    border: 1px solid rgba(180, 150, 50, 0.4);
                    border-radius: 8px;
                    padding: 4px;
                }
            """)
            entry_layout = QVBoxLayout(entry_frame)
            entry_layout.setContentsMargins(10, 8, 10, 8)
            entry_layout.setSpacing(6)
            entry_layout.setSizeConstraint(QVBoxLayout.SizeConstraint.SetMinAndMaxSize)

            # Header row
            header_row = QHBoxLayout()
            header_row.setSpacing(8)

            toggle_btn = QPushButton("▸")
            toggle_btn.setFixedSize(22, 22)
            toggle_btn.setCursor(Qt.CursorShape.PointingHandCursor)
            toggle_btn.setStyleSheet("""
                QPushButton {
                    background: rgba(180, 150, 50, 0.2);
                    border: none;
                    border-radius: 4px;
                    font-size: 21px;
                    font-weight: bold;
                    color: #806000;
                }
                QPushButton:hover { background: rgba(180, 150, 50, 0.35); }
            """)
            header_row.addWidget(toggle_btn)

            date_label = QLabel(f"📅 {date_str}")
            date_label.setStyleSheet("""
                QLabel {
                    font-size: 21px;
                    font-weight: 600;
                    color: #806000;
                    background: transparent;
                    border: none;
                }
            """)
            date_label.setCursor(Qt.CursorShape.PointingHandCursor)
            header_row.addWidget(date_label)
            header_row.addStretch()

            cb = QCheckBox()
            cb.setProperty("full_text", text)
            cb.setFixedSize(18, 18)
            cb.setStyleSheet("""
                QCheckBox { background: transparent; }
                QCheckBox::indicator { width: 16px; height: 16px; }
            """)
            cb.stateChanged.connect(self._refresh_preview)
            header_row.addWidget(cb)

            entry_layout.addLayout(header_row)

            # Body
            body_text = QTextEdit()
            body_text.setPlainText(text)
            body_text.setReadOnly(True)
            body_text.setFrameShape(QFrame.Shape.NoFrame)
            body_text.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            body_text.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            body_text.setStyleSheet("""
                QTextEdit {
                    font-size: 21px;
                    color: #333;
                    background: rgba(255, 248, 220, 0.5);
                    border: none;
                    padding: 8px;
                    border-radius: 6px;
                }
            """)
            body_text.document().setTextWidth(body_text.viewport().width() if body_text.viewport().width() > 0 else 350)
            doc_height = body_text.document().size().height() + 20
            body_text.setFixedHeight(int(max(doc_height, 60)))
            body_text.setVisible(False)
            entry_layout.addWidget(body_text)

            def make_toggle(btn, body, frame, popup_self):
                def toggle():
                    is_visible = body.isVisible()
                    body.setVisible(not is_visible)
                    btn.setText("▾" if not is_visible else "▸")
                    frame.updateGeometry()
                    if hasattr(popup_self, 'extracted_container'):
                        popup_self.extracted_container.updateGeometry()
                        popup_self.extracted_container.update()
                return toggle

            toggle_fn = make_toggle(toggle_btn, body_text, entry_frame, self)
            toggle_btn.clicked.connect(toggle_fn)
            date_label.mousePressEvent = lambda e, fn=toggle_fn: fn()

            self.extracted_checkboxes_layout.addWidget(entry_frame)
            self._extracted_checkboxes.append(cb)

        self.extracted_section.setVisible(True)
        # Keep collapsed on open
        # if self.extracted_section._is_collapsed:
        #     self.extracted_section._toggle_collapse()

