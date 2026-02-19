from __future__ import annotations

from PySide6.QtCore import Qt, Signal, QEvent
from PySide6.QtWidgets import (
    QWidget, QLabel, QPushButton,
    QVBoxLayout, QHBoxLayout, QFrame,
    QSlider, QScrollArea, QToolButton,
    QRadioButton, QButtonGroup, QSizePolicy,
    QCheckBox, QTextEdit
)
import html
from background_history_popup import CollapsibleSection
from shared_widgets import add_lock_to_popup
from spell_check_textedit import enable_spell_check_on_textedit



# ============================================================
#  PRONOUN ENGINE
# ============================================================

def pronouns_from_gender(g):
    g = (g or "").lower().strip()
    if g == "male":
        return {"subj": "he", "obj": "him", "pos": "his"}
    if g == "female":
        return {"subj": "she", "obj": "her", "pos": "her"}
    return {"subj": "they", "obj": "them", "pos": "their"}
# ============================================================
#  DURATION INFERENCE (FROM AGE STARTED)
# ============================================================

AGE_TO_DURATION = {
    "early teens": "for many years",
    "mid-teens": "for many years",
    "early adulthood": "for several years",
    "30s and 40s": "for some years",
    "50s": "for some years",
    "later adulthood": "more recently",
}

# ============================================================
#  UI HELPERS
# ============================================================

def section_title(text):
    lbl = QLabel(text)
    lbl.setStyleSheet("""
        font-size: 21px;
        font-weight: 700;
        color: #2b2b2b;
        margin-top: 18px;
        margin-bottom: 6px;
    """)
    lbl.setSizePolicy(QSizePolicy.Policy.Preferred, QSizePolicy.Policy.Fixed)
    lbl.setFixedHeight(55)
    return lbl

def soft_panel(widget):
    frame = QFrame()
    frame.setStyleSheet("""
        QFrame {
            background: rgba(255,255,255,0.6);
            border-radius: 10px;
            border: none;
            padding: 8px;
        }
    """)
    lay = QVBoxLayout(frame)
    lay.setContentsMargins(10, 8, 10, 8)
    lay.addWidget(widget)
    return frame


# ============================================================
#  SCALES
# ============================================================

AGE_STARTED = [
    None,
    "early teens",
    "mid-teens",
    "early adulthood",
    "30s and 40s",
    "50s",
    "later adulthood",
]

ALCOHOL_UNITS = [
    None,
    "1–5 units per week",
    "5–10 units per week",
    "10–20 units per week",
    "20–35 units per week",
    "35–50 units per week",
    ">50 units per week",
]

SMOKING_AMOUNT = [
    None,
    "1–5 cigarettes per day",
    "5–10 cigarettes per day",
    "10–20 cigarettes per day",
    "20–30 cigarettes per day",
    ">30 cigarettes per day",
]

DRUG_COST = [
    None,
    "<£20 per week",
    "£20–50 per week",
    "£50–100 per week",
    "£100–250 per week",
    ">£250 per week",
]

DRUG_TYPES = [
    "Cannabis",
    "Cocaine",
    "Crack cocaine",
    "Heroin",
    "Ecstasy (MDMA)",
    "LSD",
    "Spice / synthetic cannabinoids",
    "Amphetamines",
    "Ketamine",
    "Benzodiazepines",
]

class NoWheelSlider(QSlider):
    def wheelEvent(self, event):
        event.ignore()
# ============================================================
#  SLIDER
# ============================================================

class LabeledSlider(QWidget):
    def __init__(self, label: str, scale: list[str | None]):
        super().__init__()   # ✅ NO PARENT LOGIC HERE
        self.scale = scale

        layout = QVBoxLayout(self)
        layout.setSpacing(4)

        lbl = QLabel(label)
        lbl.setStyleSheet("""
            font-size: 21px;
            font-weight: 600;
            color: #444;
            margin-bottom: 2px;
        """)
        layout.addWidget(lbl)

        self.slider = NoWheelSlider(Qt.Horizontal)
        self.slider.setRange(0, len(scale) - 1)
        self.slider.setValue(0)
        layout.addWidget(self.slider)

        self.value_lbl = QLabel("")
        self.value_lbl.setStyleSheet("""
            QLabel {
                font-size: 21px;
                font-weight: 600;
                color: #2b2b2b;
                background: rgba(255, 230, 150, 0.75);
                padding: 4px 8px;
                border-radius: 6px;
                margin-top: 2px;
                margin-bottom: 2px;
            }
        """)
        layout.addWidget(self.value_lbl)

        self.slider.valueChanged.connect(self._update)
        self._update()


    def _update(self):
        value = self.scale[self.slider.value()]
        self.value_lbl.setText(value or "")
        self.value_lbl.setVisible(bool(value))

    def text(self):
        return self.scale[self.slider.value()]

    def state(self):
        return self.slider.value()

    def load(self, idx):
        if isinstance(idx, int):
            self.slider.setValue(idx)

    def set_max_index(self, max_idx: int):
        """Limit the slider to a maximum index."""
        max_idx = min(max_idx, len(self.scale) - 1)
        max_idx = max(max_idx, 0)
        self.slider.setMaximum(max_idx)
        # If current value exceeds new max, adjust it
        if self.slider.value() > max_idx:
            self.slider.setValue(max_idx)

# ============================================================
#  MAIN POPUP
# ============================================================

class DrugsAlcoholPopup(QWidget):
    sent = Signal(str, dict)

    def update_gender(self, gender: str):
        """Update pronouns when gender changes on front page."""
        self.gender = gender
        self.p = pronouns_from_gender(gender)
        self._update_preview()

    def set_patient_age(self, age: int):
        """Limit age sliders based on patient's current age.

        AGE_STARTED scale:
        0: None
        1: early teens (13-14)
        2: mid-teens (15-17)
        3: early adulthood (18-29)
        4: 30s and 40s (30-49)
        5: 50s (50-59)
        6: later adulthood (60+)
        """
        if age < 13:
            max_idx = 0
        elif age < 15:
            max_idx = 1  # early teens
        elif age < 18:
            max_idx = 2  # mid-teens
        elif age < 30:
            max_idx = 3  # early adulthood
        elif age < 50:
            max_idx = 4  # 30s and 40s
        elif age < 60:
            max_idx = 5  # 50s
        else:
            max_idx = 6  # later adulthood

        # Apply to all age sliders
        self.alc_age.set_max_index(max_idx)
        self.smoke_age.set_max_index(max_idx)
        self.drug_age.set_max_index(max_idx)
        print(f"[DRUG] set_patient_age: age={age}, max_idx={max_idx}")

    def __init__(self, first_name=None, gender=None, parent=None):
        super().__init__(parent)

        self.gender = gender
        self.p = pronouns_from_gender(gender)

        # Window behaviour — fixed panel
        self.setWindowFlags(Qt.WindowType.Widget)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)

        # Drag bar state
        self._content_height = 500
        self._min_height = 300
        self._max_height = 1200
        self._dragging = False
        self._drag_start_y = 0
        self._drag_start_height = 0

        # --------------------------------------------------
        # STATE
        # --------------------------------------------------
        self.drug_states = {
            d: {
                "age": 0,
                "amount": 0,
                "active": False,
                "ever_used": False,
            }
            for d in DRUG_TYPES
        }
        self.active_drug = None

        # --------------------------------------------------
        # UI ROOT
        # --------------------------------------------------
        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(8)

        # ========================================================
        # IMPORTED DATA SECTION (from notes)
        # ========================================================
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
        self.extracted_section.setVisible(False)  # Hidden until data loaded
        # Will be added at bottom after main content

        # Store extracted checkboxes
        self._extracted_checkboxes = []

        # ========================================================
        # SECTION 2: MAIN SCROLLABLE CONTENT
        # ========================================================
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

        frame = QFrame()
        frame.setStyleSheet("""
            QFrame {
                background: rgba(248,249,250,0.96);
                border-radius: 12px;
                border: none;
            }

            QLabel {
                background: transparent;
                border: none;
                padding: 0;
            }
        """)
        self.content_frame = frame  # Store reference for drag resizing

        layout = QVBoxLayout(frame)
        layout.setContentsMargins(12, 12, 12, 12)
        layout.setSpacing(10)

        # --------------------------------------------------
        # Scroll
        # --------------------------------------------------
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        layout.addWidget(scroll, 1)

        body = QWidget()
        scroll.setWidget(body)
        body.setStyleSheet("""
            background: transparent;
        """)
        body_layout = QVBoxLayout(body)
        body_layout.setSpacing(20)

        # ===================== ALCOHOL =====================
        body_layout.addWidget(section_title("Alcohol"))

        alc_block = QWidget()
        alc_layout = QVBoxLayout(alc_block)
        alc_layout.setSpacing(12)
        alc_layout.setContentsMargins(0, 0, 0, 0)

        self.alc_age = LabeledSlider("Age started drinking", AGE_STARTED)
        self.alc_amt = LabeledSlider("Current alcohol use", ALCOHOL_UNITS)

        alc_layout.addWidget(self.alc_age)
        alc_layout.addWidget(self.alc_amt)

        body_layout.addWidget(soft_panel(alc_block))


        # ===================== SMOKING =====================
        body_layout.addWidget(section_title("Smoking"))

        smoke_block = QWidget()
        smoke_layout = QVBoxLayout(smoke_block)
        smoke_layout.setSpacing(12)
        smoke_layout.setContentsMargins(0, 0, 0, 0)

        self.smoke_age = LabeledSlider("Age started smoking", AGE_STARTED)
        self.smoke_amt = LabeledSlider("Current smoking", SMOKING_AMOUNT)

        smoke_layout.addWidget(self.smoke_age)
        smoke_layout.addWidget(self.smoke_amt)

        body_layout.addWidget(soft_panel(smoke_block))


        # ===================== DRUGS =====================
        body_layout.addWidget(section_title("Illicit drugs"))

        drugs_block = QWidget()
        drugs_layout = QVBoxLayout(drugs_block)
        drugs_layout.setSpacing(10)
        drugs_layout.setContentsMargins(0, 0, 0, 0)

        # -------------------------------
        # Drug radio buttons (mutually exclusive)
        # -------------------------------
        self.drug_buttons = {}
        self.drug_button_group = QButtonGroup(self)
        self.drug_button_group.setExclusive(True)

        for d in DRUG_TYPES:
            rb = QRadioButton(d)
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
            rb.toggled.connect(
                lambda checked, drug=d: self._on_drug_toggled(drug, checked)
            )
            self.drug_buttons[d] = rb
            self.drug_button_group.addButton(rb)
            drugs_layout.addWidget(rb)

        # -------------------------------
        # Per-drug sliders (contextual)
        # -------------------------------
        self.drug_age = LabeledSlider("Age started use", AGE_STARTED)
        self.drug_amt = LabeledSlider("Current weekly spend", DRUG_COST)

        drugs_layout.addWidget(self.drug_age)
        drugs_layout.addWidget(self.drug_amt)

        self.drug_age.slider.valueChanged.connect(self._update_active_drug)
        self.drug_amt.slider.valueChanged.connect(self._update_active_drug)

        body_layout.addWidget(soft_panel(drugs_block))

        for s in (self.alc_age, self.alc_amt, self.smoke_age, self.smoke_amt):
            s.slider.valueChanged.connect(self._update_preview)

        # Drag bar at bottom of content frame for resizing
        self.drag_bar = QFrame()
        self.drag_bar.setFixedHeight(10)
        self.drag_bar.setCursor(Qt.CursorShape.SizeVerCursor)
        self.drag_bar.setStyleSheet("""
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 rgba(0,0,0,0.05), stop:0.5 rgba(0,0,0,0.15), stop:1 rgba(0,0,0,0.05));
                border-radius: 2px;
                margin: 2px 60px;
            }
            QFrame:hover {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 rgba(37,99,235,0.2), stop:0.5 rgba(37,99,235,0.5), stop:1 rgba(37,99,235,0.2));
            }
        """)
        self.drag_bar.installEventFilter(self)
        layout.addWidget(self.drag_bar)

        # Add content frame to main layout
        main_layout.addWidget(frame)

        # Add imported data section to main layout
        main_layout.addWidget(self.extracted_section)

        # Add stretch at bottom
        main_layout.addStretch()

        # Set up scroll area and add to root
        main_scroll.setWidget(main_container)
        self.main_scroll = main_scroll
        root.addWidget(main_scroll, 1)

        self._update_height()
        self._update_preview()

        # Add lock functionality
        add_lock_to_popup(self, show_button=False)

    # ============================================================
    #  DRAG BAR RESIZE
    # ============================================================
    def _update_height(self):
        """Update the content frame height based on drag bar position."""
        # Only resize the content frame, not the popup itself
        if hasattr(self, 'content_frame'):
            self.content_frame.setMinimumHeight(self._content_height)
            self.content_frame.setMaximumHeight(self._content_height)
        self.updateGeometry()

    def eventFilter(self, obj, event):
        if obj == self.drag_bar:
            if event.type() == QEvent.Type.MouseButtonPress:
                self._dragging = True
                self._drag_start_y = event.globalPosition().y()
                self._drag_start_height = self._content_height
                return True
            elif event.type() == QEvent.Type.MouseMove and self._dragging:
                delta = event.globalPosition().y() - self._drag_start_y
                new_height = self._drag_start_height + delta
                self._content_height = max(self._min_height, min(self._max_height, int(new_height)))
                self._update_height()
                return True
            elif event.type() == QEvent.Type.MouseButtonRelease:
                self._dragging = False
                return True
        return super().eventFilter(obj, event)

    # ============================================================
    #  STYLE HELPER
    # ============================================================



    # ============================================================
    #  DRUG LOGIC
    # ============================================================
    def _select_drug(self, drug):
        """Select a drug and load its state into sliders (used by load_state)."""
        self.active_drug = drug

        state = self.drug_states[drug]

        # Restore sliders from stored state
        self.drug_age.slider.blockSignals(True)
        self.drug_amt.slider.blockSignals(True)

        self.drug_age.slider.setValue(state.get("age", 0))
        self.drug_amt.slider.setValue(state.get("amount", 0))

        self.drug_age.slider.blockSignals(False)
        self.drug_amt.slider.blockSignals(False)

        self._update_preview()




    def _save_active_drug(self):
        if not self.active_drug:
            print("[DRUG] _save_active_drug: no active_drug, skipping")
            return
        age_val = self.drug_age.state()
        amt_val = self.drug_amt.state()
        print(f"[DRUG] _save_active_drug: saving to '{self.active_drug}' -> age={age_val}, amt={amt_val}")
        self.drug_states[self.active_drug]["age"] = age_val
        self.drug_states[self.active_drug]["amount"] = amt_val

    def _update_active_drug(self):
        self._save_active_drug()
        self._update_preview()

    # ============================================================
    #  TEXT
    # ============================================================
    def formatted_text(self) -> str:
        subj = self.p["subj"].capitalize()
        sentences = []

        verbs = [
            "reported",
            "described",
            "also described",
            "also reported",
            "additionally reported",
        ]

        def add_sentence(body: str):
            if not body:
                return

            idx = min(len(sentences), len(verbs) - 1)
            verb = verbs[idx]
            sentences.append(f"{subj} {verb} {body}.")

        # --------------------------------------------------
        # Alcohol
        # --------------------------------------------------
        alc_bits = []
        if self.alc_age.text():
            alc_bits.append(f"starting in {self.alc_age.text()}")
        if self.alc_amt.text():
            alc_bits.append(f"with current use of {self.alc_amt.text()}")

        if alc_bits:
            add_sentence("drinking alcohol, " + ", ".join(alc_bits))

        # --------------------------------------------------
        # Smoking
        # --------------------------------------------------
        smoke_bits = []
        if self.smoke_age.text():
            smoke_bits.append(f"starting in {self.smoke_age.text()}")
        if self.smoke_amt.text():
            smoke_bits.append(f"with current use of {self.smoke_amt.text()}")

        if smoke_bits:
            add_sentence("smoking tobacco, " + ", ".join(smoke_bits))

        # --------------------------------------------------
        # Drugs — PER DRUG, ISOLATED (CRITICAL SECTION)
        # --------------------------------------------------
        # Collect drugs with current use vs past use
        current_use_drugs = []
        past_use_drugs = []

        for drug, state in self.drug_states.items():
            age_idx = state.get("age", 0)
            amt_idx = state.get("amount", 0)
            ever_used = state.get("ever_used", False)

            # Skip if never used (never clicked the radio button)
            if not ever_used:
                continue

            age = AGE_STARTED[age_idx] if age_idx > 0 else None

            # Current use: has spending amount set (regardless of which radio is selected)
            if amt_idx > 0:
                current_use_drugs.append({
                    "drug": drug,
                    "age": age,
                    "amount": DRUG_COST[amt_idx],
                })
            # Past use: was clicked but no spending amount
            else:
                past_use_drugs.append({
                    "drug": drug,
                    "age": age,
                })

        # --------------------------------------------------
        # Output past use drugs
        # --------------------------------------------------
        if past_use_drugs:
            past_intros = [
                f"{subj} admitted to previous use of",
                f"{subj} has previously used",
                f"{subj} used to take",
            ]
            intro = past_intros[len(sentences) % len(past_intros)]

            if len(past_use_drugs) == 1:
                d = past_use_drugs[0]
                age_part = f", starting in {d['age']}" if d['age'] else ""
                drug_name = d['drug'] if d['drug'].isupper() else d['drug'].lower()
                sentences.append(f"{intro} {drug_name}{age_part}.")
            else:
                drug_names = [d["drug"] if d["drug"].isupper() else d["drug"].lower() for d in past_use_drugs]
                if len(drug_names) == 2:
                    drugs_str = f"{drug_names[0]} and {drug_names[1]}"
                else:
                    drugs_str = ", ".join(drug_names[:-1]) + f", and {drug_names[-1]}"
                sentences.append(f"{intro} {drugs_str}.")

        # --------------------------------------------------
        # Output current use drugs
        # --------------------------------------------------
        for d in current_use_drugs:
            age_part = f"starting in {d['age']}, " if d['age'] else ""
            duration = AGE_TO_DURATION.get(d['age'], "") if d['age'] else ""
            duration_part = f"{duration}, " if duration else ""

            drug_name = d['drug'] if d['drug'].isupper() else d['drug'].lower()
            body = f"current use of {drug_name}, {age_part}{duration_part}spending {d['amount']}"
            add_sentence(body)

        return " ".join(sentences)


    # ============================================================
    #  STATE
    # ============================================================

    def get_state(self):
        return {
            "alcohol": [self.alc_age.state(), self.alc_amt.state()],
            "smoking": [self.smoke_age.state(), self.smoke_amt.state()],
            "drugs": self.drug_states,
            "gender": self.gender,
        }

    def load_state(self, state: dict):
        if not isinstance(state, dict):
            return

        self.gender = state.get("gender", self.gender)
        self.p = pronouns_from_gender(self.gender)

        for s, idx in zip((self.alc_age, self.alc_amt), state.get("alcohol", [])):
            s.load(idx)

        for s, idx in zip((self.smoke_age, self.smoke_amt), state.get("smoking", [])):
            s.load(idx)

        self.drug_states = state.get("drugs", self.drug_states)

        for d, cb in self.drug_buttons.items():
            cb.setChecked(self.drug_states.get(d, {}).get("active", False))

        self._update_preview()

        
    def _on_drug_toggled(self, drug: str, checked: bool):
        print(f"[DRUG] _on_drug_toggled: drug={drug}, checked={checked}")
        print(f"[DRUG]   active_drug BEFORE = {self.active_drug}")
        print(f"[DRUG]   drug_states[{drug}] BEFORE = {self.drug_states[drug]}")
        print(f"[DRUG]   sliders BEFORE: age={self.drug_age.state()}, amt={self.drug_amt.state()}")

        data = self.drug_states[drug]

        # -------------------------------
        # CHECKED → activate + select
        # -------------------------------
        if checked:
            # First, save the PREVIOUS drug's data before switching
            if self.active_drug and self.active_drug != drug:
                print(f"[DRUG]   Saving previous drug '{self.active_drug}' state...")
                self._save_active_drug()
                print(f"[DRUG]   drug_states[{self.active_drug}] AFTER save = {self.drug_states[self.active_drug]}")

            data["active"] = True
            data["ever_used"] = True

            # Set as active and load its stored values (or defaults)
            self.active_drug = drug

            self.drug_age.slider.blockSignals(True)
            self.drug_amt.slider.blockSignals(True)

            # Load this drug's stored values (0 if never defined)
            stored_age = data.get("age", 0)
            stored_amt = data.get("amount", 0)
            print(f"[DRUG]   Loading stored values for '{drug}': age={stored_age}, amt={stored_amt}")
            self.drug_age.slider.setValue(stored_age)
            self.drug_amt.slider.setValue(stored_amt)

            self.drug_age.slider.blockSignals(False)
            self.drug_amt.slider.blockSignals(False)

            print(f"[DRUG]   sliders AFTER load: age={self.drug_age.state()}, amt={self.drug_amt.state()}")
            self._update_preview()
            return

        # -------------------------------
        # UNCHECKED → deactivate but preserve data
        # (Radio buttons: this happens when another drug is selected)
        # -------------------------------
        # Save current slider values before deactivating
        if self.active_drug == drug:
            print(f"[DRUG]   Saving '{drug}' state before deactivating...")
            self._save_active_drug()
            print(f"[DRUG]   drug_states[{drug}] AFTER save = {self.drug_states[drug]}")

        data["active"] = False
        self._update_preview()

    # ============================================================
    #  EMIT / CLOSE
    # ============================================================

    def _update_preview(self):
        """Legacy method name - now sends to card immediately."""
        self._send_to_card()

    def _send_to_card(self):
        """Send current text to card immediately."""
        self._save_active_drug()
        text = self.formatted_text().strip()
        state = self.get_state()
        if text:
            self.sent.emit(text, state)

    def _emit(self):
        # flush active drug
        self._save_active_drug()

        text = self.formatted_text().strip()
        state = self.get_state()

        if text:
            self.sent.emit(text, state)

        self.close()



    def closeEvent(self, event):
        parent = self.parent()
        if parent and hasattr(parent, "store_popup_state"):
            parent.store_popup_state("drugalc", self.get_state())
        super().closeEvent(event)

    def hideEvent(self, event):
        """Save state when popup is hidden (navigating away)."""
        parent = self.parent()
        if parent and hasattr(parent, "store_popup_state"):
            parent.store_popup_state("drugalc", self.get_state())
        super().hideEvent(event)

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
                    # Try to parse and reformat
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

            # Header row with checkbox, +/- button, and date
            header_row = QHBoxLayout()
            header_row.setSpacing(8)

            # Toggle button on the LEFT
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

            # Date label
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

            # Checkbox on the RIGHT
            cb = QCheckBox()
            cb.setProperty("full_text", text)
            cb.setFixedSize(18, 18)
            cb.setStyleSheet("""
                QCheckBox { background: transparent; }
                QCheckBox::indicator { width: 16px; height: 16px; }
            """)
            cb.stateChanged.connect(self._update_preview)
            header_row.addWidget(cb)

            entry_layout.addLayout(header_row)

            # Body (full content, hidden by default)
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
            # Calculate height based on content
            body_text.document().setTextWidth(body_text.viewport().width() if body_text.viewport().width() > 0 else 350)
            doc_height = body_text.document().size().height() + 20
            body_text.setFixedHeight(int(max(doc_height, 60)))
            body_text.setVisible(False)
            entry_layout.addWidget(body_text)

            # Toggle function
            def make_toggle(btn, body, frame, popup_self):
                def toggle():
                    is_visible = body.isVisible()
                    body.setVisible(not is_visible)
                    btn.setText("▾" if not is_visible else "▸")
                    # Force full layout recalculation
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

        # Show the section and expand it
        self.extracted_section.setVisible(True)
        # Keep collapsed on open
        # if self.extracted_section._is_collapsed:
        #     self.extracted_section._toggle_collapse()
