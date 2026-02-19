from __future__ import annotations
from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import (
    QWidget, QLabel, QPushButton,
    QVBoxLayout, QHBoxLayout,
    QScrollArea, QCheckBox, QSizePolicy, QFrame, QTextEdit
)
from background_history_popup import CollapsibleSection
from shared_widgets import add_lock_to_popup
from spell_check_textedit import enable_spell_check_on_textedit


# ======================================================
# PRONOUN ENGINE (SAME CONTRACT AS ANXIETY)
# ======================================================
def pronouns_from_gender(g):
        g = (g or "").lower().strip()
        if g == "male":
                return {
                        "subj": "he",
                        "obj": "him",
                        "pos": "his",
                        "have": "has"
                }
        if g == "female":
                return {
                        "subj": "she",
                        "obj": "her",
                        "pos": "her",
                        "have": "has"
                }
        return {
                "subj": "they",
                "obj": "them",
                "pos": "their",
                "have": "have"
        }

# ======================================================
# DATA
# ======================================================
HEALTH_CONDITIONS = {
    "Cardiac conditions": [
        "hypertension", "MI", "arrhythmias", "high cholesterol", "heart failure"
    ],
    "Endocrine conditions": [
        "diabetes", "thyroid disorder", "PCOS"
    ],
    "Respiratory conditions": [
        "asthma", "COPD", "bronchitis"
    ],
    "Gastric conditions": [
        "gastric ulcer",
        "gastro-oesophageal reflux disease (GORD)",
        "irritable bowel syndrome"
    ],
    "Neurological conditions": [
        "multiple sclerosis",
        "Parkinson's disease",
        "epilepsy"
    ],
    "Hepatic conditions": [
        "hepatitis C",
        "fatty liver",
        "alcohol-related liver disease"
    ],
    "Renal conditions": [
        "chronic kidney disease",
        "end-stage renal disease"
    ],
    "Cancer history": [
        "lung", "prostate", "bladder", "uterine", "breast", "brain", "kidney"
    ],
}

# ======================================================
# POPUP
# ======================================================
class PhysicalHealthPopup(QWidget):
    sent = Signal(str, dict)

    def __init__(self, first_name: str = None, gender: str = None, parent=None):
        super().__init__(parent)

        # Window behaviour — fixed panel
        self.setWindowFlags(Qt.WindowType.Widget)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)

        self._checkboxes = {category: [] for category in HEALTH_CONDITIONS.keys()}
        self._sentences = {}
        self.p = pronouns_from_gender(gender)
        self._sent_via_button = False  # Flag to prevent double emission
        verb = self.get_pronoun_verb()
        root_layout = QVBoxLayout(self)
        root_layout.setContentsMargins(0, 0, 0, 0)
        root_layout.setSpacing(8)
        self._expanded_sections = set()

        # ==================================================
        # MAIN SCROLL AREA (contains form + imported data)
        # ==================================================
        main_scroll = QScrollArea()
        main_scroll.setWidgetResizable(True)
        main_scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        main_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        main_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        main_scroll.setStyleSheet("QScrollArea { background: transparent; border: none; }")

        main_container = QWidget()
        main_container.setStyleSheet("background: transparent;")
        main_layout = QVBoxLayout(main_container)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(8)

        container = QWidget()
        container.setObjectName("physical_container")
        container.setStyleSheet("""
        QWidget#physical_container {
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
        main_layout.addWidget(container)

        self.form = QVBoxLayout(container)
        self.form.setContentsMargins(16, 14, 16, 14)
        self.form.setSpacing(6)

        # Add sections dynamically
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

        # Adding checkbox handling (Fix for checkbox appearance)
        for category, items in HEALTH_CONDITIONS.items():
            container, arrow = self.collapsible_section(category)
            self._checkboxes[category] = []

            for name in items:
                cb = QCheckBox(name)
                self._checkboxes[category].append(cb)

                # Connecting stateChanged signal to handler
                cb.stateChanged.connect(self.create_on_checked_handler(container, arrow, category))
                cb.stateChanged.connect(self._refresh_preview)  # Refresh preview when checkbox is clicked

                container.layout().addWidget(cb)

        # ==================================================
        # IMPORTED DATA SECTION (from notes)
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

        self._extracted_checkboxes = []

        main_layout.addWidget(self.extracted_section)
        main_layout.addStretch()

        main_scroll.setWidget(main_container)
        root_layout.addWidget(main_scroll, 1)

        # Refresh the preview initially
        self._refresh_preview()

        # Add lock functionality
        add_lock_to_popup(self, show_button=False)

    # ==================================================
    # SET EXTRACTED DATA
    # ==================================================
    def set_extracted_data(self, items):
        """Display extracted data from notes with collapsible dated entry boxes."""
        for cb in self._extracted_checkboxes:
            cb.setParent(None)
            cb.deleteLater()
        self._extracted_checkboxes.clear()

        while self.extracted_checkboxes_layout.count():
            item = self.extracted_checkboxes_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        if isinstance(items, str):
            items = [{"date": None, "text": p.strip()} for p in items.split("\n\n") if p.strip()]

        if not items:
            self.extracted_section.setVisible(False)
            return

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
                    date_str = dt.strftime("%d %b %Y") if dt else str(date_val)
                else:
                    date_str = str(date_val)
            else:
                date_str = "No date"

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
            header_row.addWidget(cb)

            entry_layout.addLayout(header_row)

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

    # ======================================================
    # GENDER UPDATE
    # ======================================================
    def update_gender(self, gender: str):
        """Update pronouns when gender changes on front page."""
        self.p = pronouns_from_gender(gender)
        # Regenerate all sentences with new pronouns
        for key in list(self._sentences.keys()):
            # Get the original sentence from personal_history (without pronouns applied)
            original = self.personal_history.get(key)
            if original:
                self._sentences[key] = self._apply_pronouns(original)
        self._refresh_preview()

    # ======================================================
    # SEND TO CARD ON CHANGE
    # ======================================================
    def _refresh_preview(self):
        """Legacy method name - now sends to card immediately."""
        self._send_to_card()

    def _send_to_card(self):
        """Send current text to card immediately."""
        # Avoid starting a new refresh if one is already in progress
        if hasattr(self, '_is_updating') and self._is_updating:
            return

        self._is_updating = True

        # Collect selected conditions
        selected_conditions = [
            condition for category, cb_list in self._checkboxes.items()
            for cb, condition in zip(cb_list, HEALTH_CONDITIONS.get(category, []))
            if cb.isChecked() and condition.strip().lower() == cb.text().strip().lower()
        ]
        selected_conditions = list(set(selected_conditions))

        if selected_conditions:
            text = self.formatted_text(selected_conditions)
            if text:
                self.sent.emit(text.strip(), {})

        self._is_updating = False

    # ======================================================
    # TEXT HANDLING
    # ======================================================

    def get_pronoun_verb(self):
        return self.p.get("have", "have")

    
    def formatted_text(self, selected_conditions) -> str:
        print(f"Generating text for conditions: {selected_conditions}")

        from collections import defaultdict
        groups = defaultdict(list)

        # --------------------------------------------------
        # GROUP CONDITIONS BY CATEGORY
        # --------------------------------------------------
        for condition in selected_conditions:
            for category, items in HEALTH_CONDITIONS.items():
                if condition in items:
                    groups[category].append(condition)
        text = ""

         # --------------------------------------------------
        # EMIT ONE PARAGRAPH PER CATEGORY
        # --------------------------------------------------
        if "Cardiac conditions" in groups:
            items = ", ".join(groups["Cardiac conditions"])
            text += (
                f"Cardiac conditions, including {items}, "
                f"are noted in the patient's history.\n"
            )

        if "Endocrine conditions" in groups:
            items = ", ".join(groups["Endocrine conditions"])
            text += (
                f"{self.p['subj'].capitalize()} {self.p['have']} endocrine "
                f"conditions including {items}.\n"
            )

        if "Respiratory conditions" in groups:
            items = ", ".join(groups["Respiratory conditions"])
            text += (
                f"Additionally, {self.p['subj']} {self.p['have']} respiratory "
                f"conditions including {items}.\n"
            )

        if "Gastric conditions" in groups:
            items = ", ".join(groups["Gastric conditions"])
            text += (
                f"{self.p['subj'].capitalize()} {self.p['have']} a long-standing "
                f"history of gastrointestinal issues including {items}.\n"
            )

        if "Neurological conditions" in groups:
            items = ", ".join(groups["Neurological conditions"])
            text += (
                f"Neurologically, {self.p['subj']} {self.p['have']} a history of "
                f"{items}, well-managed with treatment.\n"
            )

        if "Hepatic conditions" in groups:
            items = ", ".join(groups["Hepatic conditions"])
            text += (
                f"Regarding hepatic conditions, {self.p['subj']} {self.p['have']} "
                f"been monitored for {items}.\n"
            )

        if "Renal conditions" in groups:
            items = ", ".join(groups["Renal conditions"])
            text += (
                f"{self.p['subj'].capitalize()} {self.p['have']} been treated for "
                f"{items}.\n"
            )

        if "Cancer history" in groups:
            items = ", ".join(groups["Cancer history"])
            text += (
                f"Finally, {self.p['subj']} {self.p['have']} a history of "
                f"{items} cancer and continues with regular monitoring.\n"
            )
        print(f"🔎 Generated text: {text}")  # Debugging line
        return text


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

    # ======================================================
    # SENTENCE HANDLING
    # ======================================================
    def _set_sentence(self, key: str, sentence: str):
        self.personal_history[key] = sentence   # Store the sentence in personal history
        
        if sentence:
            self._sentences[key] = self._apply_pronouns(sentence)  # Apply pronouns if the sentence exists
            self._active_key = key
        else:
            self._sentences.pop(key, None)  # Remove from sentences if there's no sentence
            if self._active_key == key:
                self._active_key = None

        print(f"_sentences: {self._sentences}")  # Debugging line to ensure sentences are stored
        self._refresh_preview()  # Refresh the preview to update the view


    def _apply_pronouns(self, text: str) -> str:
        """ Apply gendered pronouns to a sentence """
        subj = self.p["subj"]
        obj = self.p["obj"]
        pos = self.p["pos"]

        replacements = [
            (r"(?<!T)\bHe\b", subj.capitalize()),
            (r"(?<!T)\bhe\b", subj),
            (r"\bHis\b", pos.capitalize()),
            (r"\bhis\b", pos),
            (r"\bHim\b", obj.capitalize()),
            (r"\bhim\b", obj),
        ]

        for pattern, repl in replacements:
            text = re.sub(pattern, repl, text)

        return text

    # ==================================================         
    # LOGIC
    # ==================================================
    def on_checked(self, state, container, arrow, category):
        # Check if any checkbox in the category is checked
        any_checked = any(cb.isChecked() for cb in self._checkboxes[category])

        if state and not container.isVisible():
            container.setVisible(True)
            arrow.setText("▾")
        elif not any_checked:
            container.setVisible(False)
            arrow.setText("▸")
        self._refresh_preview()  # Update the preview whenever the checkbox state changes




    # ==================================================
    # SEND
    # ==================================================
    def _send(self):
        selected_conditions = []
        for category, cb_list in self._checkboxes.items():
            for cb in cb_list:
                if cb.isChecked():
                    selected_conditions.append(cb.text())

        if not selected_conditions:
            return

        text = self.formatted_text(selected_conditions)
        if not text:
            return

        self._sent_via_button = True  # Mark as sent via button
        self.sent.emit(
            text,
            {"conditions": selected_conditions}
        )
        self.close()


    # ==================================================
    # COLLAPSIBLE
    # ==================================================
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
                color: #6E6E6E;  /* Lighter gray for the arrow */
                background: transparent;
            }
        """)

        lbl = QLabel(title)
        lbl.setStyleSheet("""
            QLabel {
                font-size: 21px;
                font-weight: 600;
                color: #6E6E6E;  /* Lighter gray for section titles */
                background: transparent;
                border: none;
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
        container.setVisible(False)  # collapsed by default
        v = QVBoxLayout(container)
        v.setContentsMargins(22, 6, 0, 10)
        v.setSpacing(6)

        # restore expanded state
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


    # ==================================================
    # RELOAD/close
    # ==================================================
    def load_state(self, state: dict):
        conditions = set(state.get("conditions", []))

        for category, cb_list in self._checkboxes.items():
            for cb in cb_list:
                cb.blockSignals(True)
                cb.setChecked(cb.text() in conditions)
                cb.blockSignals(False)

        self._refresh_preview()
        
    def closeEvent(self, event):
        # Only emit if not already sent via button
        if not self._sent_via_button:
            state = {
                "conditions": [
                    cb.text()
                    for cb_list in self._checkboxes.values()
                    for cb in cb_list
                    if cb.isChecked()
                ]
            }
            self.sent.emit("", state)
        self._sent_via_button = False  # Reset flag
        super().closeEvent(event)

