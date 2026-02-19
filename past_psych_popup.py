from __future__ import annotations

from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import (
    QWidget, QLabel, QComboBox, QFrame, QTextEdit, QCheckBox,
    QVBoxLayout, QHBoxLayout, QPushButton,
    QSizePolicy, QScrollArea
)
from background_history_popup import CollapsibleSection
from shared_widgets import add_lock_to_popup
from spell_check_textedit import enable_spell_check_on_textedit


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

# ============================================================
#  OPTIONS
# ============================================================

PREVIOUS_PSYCH_OPTIONS = [
    ("Never", "has never seen a psychiatrist before"),
    ("Did not want to discuss", "did not wish to discuss previous psychiatric contact"),
    ("Outpatient but DNA", "has been an outpatient in the past but did not attend appointments"),
    ("Outpatient but no admission", "has been an outpatient in the past without psychiatric admission"),
    ("Outpatient + 1 admission", "has been an outpatient in the past and has had one inpatient admission"),
    ("Outpatient + several admissions", "has been an outpatient in the past and has had several inpatient admissions"),
    ("Only inpatient", "has only had inpatient psychiatric admissions"),
]

GP_PSYCH_OPTIONS = [
    ("Never", "has never seen their GP for psychiatric issues"),
    ("Did not want to discuss", "did not wish to discuss GP contact for psychiatric issues"),
    ("Occasional", "has occasionally seen their GP for psychiatric issues"),
    ("Frequent", "has frequently seen their GP for psychiatric issues"),
    ("Regular", "has regular GP contact for psychiatric issues"),
]

MEDICATION_OPTIONS = [
    ("Never", "has never taken psychiatric medication"),
    ("Did not want to discuss", "did not wish to discuss psychiatric medication"),
    ("Intermittent", "has taken psychiatric medication intermittently in the past"),
    ("Regularly", "has taken psychiatric medication regularly in the past"),
    ("Current + good compliance", "is currently prescribed psychiatric medication with good adherence"),
    ("Current + varied compliance", "is currently prescribed psychiatric medication with variable adherence"),
    ("Current + poor compliance", "is currently prescribed psychiatric medication with poor adherence"),
    ("Refuses", "refuses psychiatric medication currently and historically"),
]

COUNSELLING_OPTIONS = [
    ("Did not want to discuss", "did not wish to discuss psychological therapy"),
    ("Intermittent in past", "has received intermittent psychological therapy in the past"),
    ("Moderate in past", "has received moderate psychological therapy in the past"),
    ("Extensive in past", "has received extensive psychological therapy historically"),
    ("Current", "is currently receiving psychological therapy"),
    ("Refuses now + past", "refuses psychological therapy currently and historically"),
    ("Refuses now but not past", "refuses psychological therapy currently but has engaged in the past"),
]


# ============================================================
#  POPUP
# ============================================================
class PastPsychPopup(QWidget):
    sent = Signal(str, dict)   # text, state
    closed = Signal(dict)      # emitted when popup closes, passes state


    def _apply_pronoun_grammar(self, phrase: str) -> str:
        phrase = phrase.strip()

        if self.p["subj"] == "they":
            for src, tgt in (("has ", "have "), ("is ", "are "), ("was ", "were ")):
                if phrase.startswith(src):
                    return tgt + phrase[len(src):]

        return phrase   # 🔴 YOU WERE MISSING THIS

    def update_gender(self, gender: str):
        """Update pronouns when gender changes on front page."""
        self.gender = gender
        self.p = pronouns_from_gender(gender)
        self._update_preview()
        
    def _sentence_from_option(self, value: str) -> str:
        phrase = value[0].lower() + value[1:]
        # Replace "their" with correct possessive pronoun
        phrase = phrase.replace("their GP", f"{self.p['pos']} GP")
        phrase = self._apply_pronoun_grammar(phrase)
        return f"{self.p['subj'].capitalize()} {phrase}."

            
    def __init__(self, first_name: str = None, gender: str = None, parent=None):
        super().__init__(parent)

        self.first_name = first_name or "The patient"
        self.gender = gender
        self.p = pronouns_from_gender(gender)

        # Window behaviour — fixed panel
        self.setWindowFlags(Qt.WindowType.Widget)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)

        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(8)

        # ========================================================
        # SCROLLABLE CONTENT
        # ========================================================
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        container = QWidget()
        container.setObjectName("past_psych_popup")
        container.setStyleSheet("""
            QWidget#past_psych_popup {
                background: rgba(255,255,255,0.92);
                border-radius: 12px;
                border: 1px solid rgba(0,0,0,0.15);
            }
            QLabel { color:#003c32; border: none; }
        """)

        scroll.setWidget(container)

        layout = QVBoxLayout(container)
        layout.setContentsMargins(12, 12, 12, 12)
        layout.setSpacing(10)

        # --------------------------------------------------
        # Rows
        # --------------------------------------------------
        self._rows = []

        def add_row(label_text, options):
            lbl = QLabel(label_text)
            lbl.setStyleSheet("font-weight:600; font-size:21px;")
            lbl.setWordWrap(True)

            combo = QComboBox()
            combo.addItem("Not specified", None)
            for opt in options:
                # Handle both tuple (label, value) and plain string formats
                if isinstance(opt, tuple):
                    combo.addItem(opt[0], opt[1])  # (display_label, output_value)
                else:
                    combo.addItem(opt, opt)

            # Make combobox fit within panel width
            combo.setSizeAdjustPolicy(QComboBox.SizeAdjustPolicy.AdjustToMinimumContentsLengthWithIcon)
            combo.setMinimumContentsLength(20)
            combo.setStyleSheet("""
                QComboBox {
                    padding: 6px;
                    font-size: 21px;
                }
                QComboBox QAbstractItemView {
                    min-width: 400px;
                }
            """)

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
        # EXTRACTED FROM NOTES SECTION (collapsible, like Background)
        # --------------------------------------------------
        self.extracted_section = CollapsibleSection("Imported Data", start_collapsed=True)
        self.extracted_section.set_content_height(150)
        self.extracted_section._min_height = 60
        self.extracted_section._max_height = 400
        self.extracted_section.set_header_style("""
            QFrame {
                background: rgba(255, 248, 220, 0.95);
                border: 1px solid rgba(180, 150, 50, 0.4);
                border-radius: 6px 6px 0 0;
            }
        """)
        self.extracted_section.set_title_style("""
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
                font-size: 21px;
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

        # Container for checkboxes
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
        layout.addWidget(self.extracted_section)

        # Store extracted checkboxes
        self._extracted_checkboxes = []

        layout.addStretch()

        root.addWidget(scroll, 1)

        self._update_preview()

        # Add lock functionality
        add_lock_to_popup(self, show_button=False)

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
        """Legacy method name - now sends to card immediately."""
        self._send_to_card()

    def _send_to_card(self):
        """Send current text to card immediately."""
        text = self._build_text().strip()
        state = self.get_state()
        if text:
            self.sent.emit(text, state)

    def _build_text(self) -> str:
        sentences = []

        for combo in self._rows:
            value = combo.currentData()
            if not value:
                continue

            sentences.append(
                self._sentence_from_option(value)
            )

        # Add checked extracted items
        for cb in self._extracted_checkboxes:
            if cb.isChecked():
                full_text = cb.property("full_text")
                if full_text:
                    sentences.append(full_text)

        return " ".join(sentences)

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
                    padding: 6px;
                    font-size: 21px;
                }
                QComboBox QAbstractItemView {
                    min-width: 400px;
                }
            """)
        else:
            combo.setStyleSheet("""
                QComboBox {
                    padding: 6px;
                    font-size: 21px;
                }
                QComboBox QAbstractItemView {
                    min-width: 400px;
                }
            """)

    # ============================================================
    # EXTRACTED FROM NOTES
    # ============================================================
    def set_extracted_data(self, items):
        """Display extracted data from notes with collapsible dated entry boxes.

        Args:
            items: List of dicts with 'date' and 'text' keys, or a string (legacy)
        """
        # Clear existing checkboxes
        for cb in self._extracted_checkboxes:
            cb.deleteLater()
        self._extracted_checkboxes.clear()

        # Clear layout
        while self.extracted_checkboxes_layout.count():
            item = self.extracted_checkboxes_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        # Handle legacy string format
        if isinstance(items, str):
            if items.strip():
                items = [{"date": None, "text": p.strip()} for p in items.split("\n\n") if p.strip()]
            else:
                items = []

        if items:
            # Sort by date (newest first)
            def get_sort_date(item):
                dt = item.get("date")
                if dt is None:
                    return ""
                if hasattr(dt, "strftime"):
                    return dt.strftime("%Y-%m-%d")
                return str(dt)

            sorted_items = sorted(items, key=get_sort_date, reverse=True)

            for item in sorted_items:
                dt = item.get("date")
                text = item.get("text", "").strip()
                if not text:
                    continue

                # Format date for header
                if dt:
                    if hasattr(dt, "strftime"):
                        date_str = dt.strftime("%d %b %Y")
                    else:
                        date_str = str(dt)
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
        else:
            self.extracted_section.setVisible(False)

    def closeEvent(self, event):
        parent = self.parent()
        if parent and hasattr(parent, "store_popup_state"):
            parent.store_popup_state("psychhx", self.get_state())
        self.closed.emit(self.get_state())
        super().closeEvent(event)

    def hideEvent(self, event):
        """Save state when popup is hidden (navigating away)."""
        parent = self.parent()
        if parent and hasattr(parent, "store_popup_state"):
            parent.store_popup_state("psychhx", self.get_state())
        self.closed.emit(self.get_state())
        super().hideEvent(event)



