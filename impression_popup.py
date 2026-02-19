from __future__ import annotations

from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import (
    QWidget, QLabel, QPushButton,
    QVBoxLayout, QHBoxLayout,
    QComboBox, QTextEdit, QSizePolicy,
    QListView, QStyleFactory, QCompleter,
    QScrollArea, QFrame, QCheckBox
)
import re
from background_history_popup import CollapsibleSection
from datetime import datetime, date
from shared_widgets import add_lock_to_popup
from spell_check_textedit import enable_spell_check_on_textedit

# ======================================================
# AGE CALCULATION
# ======================================================
def calculate_age_from_dob(dob_str: str) -> int | None:
    """Calculate age from DOB string (various formats supported)."""
    if not dob_str:
        return None

    # Try common date formats
    formats = [
        "%d/%m/%Y",  # 25/12/1980
        "%Y-%m-%d",  # 1980-12-25
        "%d-%m-%Y",  # 25-12-1980
        "%d.%m.%Y",  # 25.12.1980
    ]

    for fmt in formats:
        try:
            dob = datetime.strptime(dob_str.strip(), fmt).date()
            today = date.today()
            age = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
            return age
        except ValueError:
            continue

    return None

# ======================================================
# ICD-10 NORMALISER
# ======================================================
def normalise_icd10_dict(raw: dict) -> dict:
        out = {}

        for key, value in raw.items():
                diagnosis = key.strip()
                icd10 = None
                severity = 0

                # Case 1: "diagnosis | Fxx.x"
                if "|" in diagnosis:
                        left, right = diagnosis.rsplit("|", 1)
                        diagnosis = left.strip()
                        icd10 = right.strip()

                # Case 2: value contains ICD10
                if isinstance(value, str) and value.startswith("F"):
                        icd10 = value

                # Ignore obviously broken entries
                if len(diagnosis) < 5:
                        continue

                out[diagnosis] = {
                        "diagnosis": diagnosis,
                        "icd10": icd10,
                        "severity": severity,
                }

        return out



# ======================================================
# IMPRESSION POPUP  (PAST-PSYCH ARCHITECTURE)
# ======================================================
class ImpressionPopup(QWidget):
    sent = Signal(str, dict)
    closed = Signal(dict)

    def update_gender(self, gender: str):
        """Update gender when it changes on front page."""
        self.front_page["gender_noun"] = gender
        self._refresh_preview()

    def __init__(
        self,
        front_page: dict,
        presenting_complaint: str,
        mse_text: str,
        icd10_dict: dict,
        parent=None
    ):
        super().__init__(parent)

        # ------------------------------
        # WINDOW BEHAVIOUR — fixed panel
        # ------------------------------
        self.setWindowFlags(Qt.WindowType.Widget)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        self.setStyleSheet("QComboBox { combobox-popup: 0; }")

        # ==================================================
        # ROOT LAYOUT
        # ==================================================
        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(8)

        # ========================================================
        # IMPORTED DATA SECTION (from notes) - created before main_scroll
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
        self.extracted_section.setVisible(False)

        self._extracted_checkboxes = []

        # ========================================================
        # SECTION 2: MAIN SCROLL AREA (contains form + imported data)
        # ========================================================
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
        container.setObjectName("impression_container")
        container.setStyleSheet("""
            QWidget#impression_container {
                background: rgba(255,255,255,0.95);
                border-radius: 12px;
                border: 1px solid rgba(0,0,0,0.15);
            }
            QLabel {
                background: transparent;
                border: none;
            }
        """)
        main_layout.addWidget(container)

        layout = QVBoxLayout(container)
        layout.setContentsMargins(12, 12, 12, 12)
        layout.setSpacing(12)

        # ------------------------------
        # CORE INPUTS
        # ------------------------------
        self.front_page = front_page or {}
        self.pc_text = presenting_complaint or ""
        self.mse_text = mse_text or ""
        self.icd10_dict = icd10_dict or {}

        # ------------------------------
        # INTERNAL STATE
        # ------------------------------
        self._state = {
            "dx": [],
            "override": "",
        }

        self._override_touched = False
        self._last_autogenerated = ""
        self._override_base = ""
        self.recent_dx = []

        # ==================================================
        # ICD-10 DIAGNOSES
        # ==================================================
        layout.addWidget(self._section_label("Diagnoses (ICD-10)"))

        self.dx_boxes = []

        for _ in range(3):
            combo = QComboBox()
            combo.setStyle(QStyleFactory.create("Fusion"))

            combo.setEditable(True)
            combo.lineEdit().setReadOnly(True)

            combo.setInsertPolicy(QComboBox.NoInsert)
            combo.lineEdit().returnPressed.connect(
                lambda c=combo: c.hidePopup()
            )
            combo.lineEdit().setPlaceholderText("Start typing to search…")

            # Prevent combobox from expanding to fit longest item
            combo.setSizeAdjustPolicy(QComboBox.SizeAdjustPolicy.AdjustToMinimumContentsLengthWithIcon)
            combo.setMinimumContentsLength(23)
            combo.setMaximumWidth(380)
            combo.setStyleSheet("""
                QComboBox {
                    padding: 6px;
                    font-size: 22px;
                }
                QComboBox QAbstractItemView {
                    min-width: 430px;
                }
            """)

            # ------------------------------
            # BASE OPTION
            # ------------------------------
            combo.addItem("Not specified", None)

            # ------------------------------
            # RECENT DIAGNOSES (PINNED)
            # ------------------------------
            if getattr(self, "recent_dx", None):
                combo.addItem("— Recent diagnoses —", None)
                for meta in self.recent_dx:
                    combo.addItem(meta["diagnosis"], meta)
                combo.insertSeparator(combo.count())

            # ------------------------------
            # FULL ICD-10 LIST (SORTED)
            # ------------------------------
            for diagnosis, meta in sorted(
                self.icd10_dict.items(),
                key=lambda x: (-x[1].get("severity", 0), x[0].lower())
            ):
                combo.addItem(
                    diagnosis,
                    {
                        "diagnosis": diagnosis,
                        "icd10": meta.get("icd10"),
                        "severity": meta.get("severity", 0),
                    }
                )

            # ------------------------------
            # SEARCH / AUTOCOMPLETE
            # ------------------------------
            completer = QCompleter(combo.model(), combo)
            completer.setCaseSensitivity(Qt.CaseInsensitive)
            completer.setFilterMode(Qt.MatchContains)
            completer.setCompletionMode(QCompleter.PopupCompletion)
            combo.setCompleter(completer)

            # ------------------------------
            # DROPDOWN VIEW STYLING
            # ------------------------------
            view = combo.view()
            view.setStyleSheet("""
                QListView {
                    background: #2d2d2d;
                }
                QListView::item {
                    padding: 6px;
                    color: white;
                    background: #2d2d2d;
                }
                QListView::item:selected {
                    background: #008C7E;
                    color: white;
                }
                QListView::item:hover {
                    background: #3d3d3d;
                    color: white;
                }
            """)
            
            combo.setMaxVisibleItems(15)
            combo.currentIndexChanged.connect(self._refresh_preview)
            combo.currentIndexChanged.connect(
                lambda _, c=combo: self._track_recent(c.currentData())
            )

            layout.addWidget(combo)
            self.dx_boxes.append(combo)


        # ==================================================
        # ADDITIONAL DETAILS
        # ==================================================
        layout.addWidget(self._section_label("Additional details"))

        self.override_edit = QTextEdit()
        self.override_edit.setPlaceholderText(
            "Add any additional clinical details here…"
        )
        self.override_edit.setStyleSheet("font-size: 22px;")
        self.override_edit.setMinimumHeight(80)
        self.override_edit.setMaximumHeight(80)
        self._override_height = 80
        enable_spell_check_on_textedit(self.override_edit)

        self.override_edit.textChanged.connect(self._on_override_changed)
        self.override_edit.focusInEvent = self._override_focus_in

        layout.addWidget(self.override_edit)

        # Drag bar for resizing override text box
        self.override_drag_bar = QFrame()
        self.override_drag_bar.setFixedHeight(8)
        self.override_drag_bar.setCursor(Qt.CursorShape.SizeVerCursor)
        self.override_drag_bar.setStyleSheet("""
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 rgba(0,0,0,0.03), stop:0.5 rgba(0,0,0,0.1), stop:1 rgba(0,0,0,0.03));
                border-radius: 2px;
                margin: 0px 40px;
            }
            QFrame:hover {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 rgba(37,99,235,0.15), stop:0.5 rgba(37,99,235,0.4), stop:1 rgba(37,99,235,0.15));
            }
        """)
        self.override_drag_bar.installEventFilter(self)
        self._override_dragging = False
        layout.addWidget(self.override_drag_bar)

        layout.addStretch()

        # Add imported data section to main layout
        main_layout.addWidget(self.extracted_section)
        main_layout.addStretch()

        main_scroll.setWidget(main_container)
        root.addWidget(main_scroll, 1)

        self._refresh_preview()

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

    # ==================================================
    # UI HELPERS
    # ==================================================
    def _section_label(self, text: str) -> QLabel:
        lbl = QLabel(text)
        lbl.setStyleSheet("font-weight:600;")
        return lbl

    def eventFilter(self, obj, event):
        from PySide6.QtCore import QEvent
        if obj == self.override_drag_bar:
            if event.type() == QEvent.Type.MouseButtonPress:
                self._override_dragging = True
                self._drag_start_y = event.globalPosition().y()
                self._drag_start_height = self._override_height
                return True
            elif event.type() == QEvent.Type.MouseMove and self._override_dragging:
                delta = event.globalPosition().y() - self._drag_start_y
                new_height = max(60, min(400, int(self._drag_start_height + delta)))
                self._override_height = new_height
                self.override_edit.setMinimumHeight(new_height)
                self.override_edit.setMaximumHeight(new_height)
                return True
            elif event.type() == QEvent.Type.MouseButtonRelease:
                self._override_dragging = False
                return True
        return super().eventFilter(obj, event)

    def _on_override_changed(self):
        self._override_touched = True
        self.preview.setText(self.override_edit.toPlainText())


    def _override_focus_in(self, event):
        if not self._override_touched:
            self._override_base = self._last_autogenerated
            self.override_edit.setPlainText(self._last_autogenerated)
            self._override_touched = True
        QTextEdit.focusInEvent(self.override_edit, event)
        
    # ==================================================
    # DIAGNOSIS TEXT HELPERS
    # ==================================================
    def _format_diagnosis_clause(self, dx: list[dict]) -> str:
        if not dx:
            return ""

        seen = set()
        parts = []

        for meta in dx:
            key = (meta.get("diagnosis"), meta.get("icd10"))
            if key in seen:
                continue
            seen.add(key)

            label = meta["diagnosis"]
            code = meta.get("icd10")
            if code:
                parts.append(f"{label} (ICD-10 {code})")
            else:
                parts.append(label)

        joined = "; ".join(parts)
        return f"Diagnoses under consideration include {joined}."

    def _replace_diagnosis_block(self, text: str, new_clause: str) -> str:
        if not new_clause:
            return text

        pattern = re.compile(
            r"Diagnoses under consideration include .*?\(ICD-10 [^)]+\)\.",
            re.DOTALL
        )

        if pattern.search(text):
            return pattern.sub(new_clause, text, count=1)

        if text.strip().endswith("."):
            return text.strip() + " " + new_clause

        return text.strip() + ". " + new_clause

    # ==================================================
    # GENERATE AND SEND TO CARD
    # ==================================================
    def _refresh_preview(self):
        """Legacy method name - now sends to card immediately."""
        dx = []
        for combo in self.dx_boxes:
            meta = combo.currentData()
            if isinstance(meta, dict):
                dx.append(meta)

        self._state["dx"] = dx

        diagnosis_clause = self._format_diagnosis_clause(dx)
        autogenerated = self._build_impression(dx)
        self._last_autogenerated = autogenerated

        # ------------------------------
        # NO OVERRIDE YET → SYSTEM OWNS
        # ------------------------------
        if not self._override_touched:
            self.override_edit.blockSignals(True)
            self.override_edit.setPlainText(autogenerated)
            self.override_edit.blockSignals(False)
            self._current_text = autogenerated
            self._state["override"] = ""
        else:
            # ------------------------------
            # OVERRIDE EXISTS → SURGICAL UPDATE
            # ------------------------------
            current_text = self.override_edit.toPlainText()

            updated_text = self._replace_diagnosis_block(
                current_text,
                diagnosis_clause
            )

            self.override_edit.blockSignals(True)
            self.override_edit.setPlainText(updated_text)
            self.override_edit.blockSignals(False)
            self._current_text = updated_text
            self._state["override"] = updated_text

        # Send to card immediately
        if hasattr(self, '_current_text') and self._current_text.strip():
            self.sent.emit(self._current_text.strip(), self._state)

    # ==================================================
    # RECENT DIAGNOSES TRACKING
    # ==================================================
    def _track_recent(self, meta: dict):
        if not meta:
            return

        self.recent_dx = [
            m for m in self.recent_dx
            if m["diagnosis"] != meta["diagnosis"]
        ]
        self.recent_dx.insert(0, meta)
        self.recent_dx = self.recent_dx[:5]

    # ==================================================
    # IMPRESSION LOGIC
    # ==================================================
    def _count_symptoms_severity(self, count: int) -> str:
        """Return severity word based on symptom count."""
        if count <= 2:
            return "mild"
        elif count <= 5:
            return "moderate"
        else:
            return "significant"

    def _extract_ethnicity_from_mse(self) -> str:
        """Extract ethnicity from MSE text if present."""
        if not self.mse_text:
            return ""
        # Look for ethnicity patterns
        match = re.search(r"ethnicity[:\s]+(?:is\s+)?([A-Za-z-]+)", self.mse_text, re.IGNORECASE)
        if match:
            return match.group(1)
        # Check for Afro-Caribbean first (before checking for just "Caribbean" or "African")
        if "afro-caribbean" in self.mse_text.lower():
            return "Afro-Caribbean"
        # Also check for common ethnicities mentioned
        ethnicities = ["Caucasian", "Asian", "Black", "African", "Caribbean", "Mixed", "White", "South Asian"]
        for eth in ethnicities:
            if eth.lower() in self.mse_text.lower():
                return eth
        return ""

    def _parse_pc_for_summary(self) -> dict:
        """Parse PC text to extract symptom categories, counts, duration, and impact."""
        result = {
            "categories": [],  # list of (category_name, severity_word)
            "duration": "",
            "impact": "",
        }

        if not self.pc_text:
            return result

        pc = self.pc_text

        # Extract symptom categories and count them
        # Pattern: "X symptoms including A, B, C" or "X features including A, B, C"
        category_patterns = [
            (r"depressive\s+symptoms?\s+including\s+([^;.]+)", "depressive"),
            (r"manic\s+(?:features?|symptoms?)\s+including\s+([^;.]+)", "manic"),
            (r"psychosis\s+(?:features?|symptoms?)\s+including\s+([^;.]+)", "psychotic"),
            (r"psychotic\s+(?:features?|symptoms?)\s+including\s+([^;.]+)", "psychotic"),
            (r"anxiety\s+(?:features?|symptoms?)\s+including\s+([^;.]+)", "anxiety"),
        ]

        for pattern, category in category_patterns:
            match = re.search(pattern, pc, re.IGNORECASE)
            if match:
                symptoms_str = match.group(1)
                # Count symptoms by splitting on commas and 'and'
                symptoms_str = re.sub(r'\s+and\s+', ', ', symptoms_str)
                symptoms = [s.strip() for s in symptoms_str.split(',') if s.strip()]
                count = len(symptoms)
                severity = self._count_symptoms_severity(count)
                result["categories"].append((category, severity))

        # Extract duration
        duration_match = re.search(
            r"(?:symptoms?\s+(?:have\s+)?been\s+present\s+for|over\s+the\s+last)\s+(\d+\s+(?:days?|weeks?|months?|years?))",
            pc, re.IGNORECASE
        )
        if duration_match:
            result["duration"] = duration_match.group(1)

        # Extract impact
        impact_match = re.search(
            r"(?:symptoms?\s+)?impact\s+(?:her|his|their)\s+([^.]+)",
            pc, re.IGNORECASE
        )
        if impact_match:
            result["impact"] = impact_match.group(1).strip()

        return result

    def _build_impression(self, diagnoses: list[dict]) -> str:
        parts = []

        title = self.front_page.get("title")
        surname = self.front_page.get("surname")
        age = self.front_page.get("age")
        dob = self.front_page.get("dob")
        gender = self.front_page.get("gender_noun")

        # Calculate age from DOB if age not directly provided
        if not age and dob:
            calculated_age = calculate_age_from_dob(dob)
            if calculated_age:
                age = str(calculated_age)

        # Determine pronoun and gender noun based on gender
        gender_lower = (gender or "").lower().strip()
        if gender_lower == "male":
            pronoun = "He"
            gender_noun = "man"
            pos_pronoun = "his"
        elif gender_lower == "female":
            pronoun = "She"
            gender_noun = "woman"
            pos_pronoun = "her"
        else:
            pronoun = "They"
            gender_noun = "person"
            pos_pronoun = "their"

        # Build subject name
        if title and surname:
            subject = f"{title} {surname}"
        elif surname:
            subject = surname
        else:
            subject = "The patient"

        # Get ethnicity from MSE
        ethnicity = self._extract_ethnicity_from_mse()

        # Use "an" for words starting with vowel sounds
        def article_for(word):
            return "an" if word and word[0].lower() in "aeiou" else "a"

        # Build opening with age, ethnicity, gender noun
        if age and ethnicity:
            article = article_for(age)
            opening = f"{subject} is {article} {age} year old {ethnicity} {gender_noun}"
        elif age:
            article = article_for(age)
            opening = f"{subject} is {article} {age} year old {gender_noun}"
        elif ethnicity:
            article = article_for(ethnicity)
            opening = f"{subject} is {article} {ethnicity} {gender_noun}"
        else:
            opening = f"{subject} is a {gender_noun}"

        # Parse PC for summary
        pc_summary = self._parse_pc_for_summary()

        # Build symptom summary
        if pc_summary["categories"]:
            # Group categories by severity for better flow
            severity_order = ["significant", "severe", "moderate", "mild"]
            grouped = {}
            for category, severity in pc_summary["categories"]:
                grouped.setdefault(severity, []).append(category)

            # Build grouped symptom phrases (each group includes "symptoms")
            symptom_phrases = []
            for sev in severity_order:
                categories = grouped.get(sev, [])
                if categories:
                    if len(categories) == 1:
                        symptom_phrases.append(f"{sev} {categories[0]} symptoms")
                    elif len(categories) == 2:
                        symptom_phrases.append(f"{sev} {categories[0]} and {categories[1]} symptoms")
                    else:
                        joined = ", ".join(categories[:-1]) + f" and {categories[-1]}"
                        symptom_phrases.append(f"{sev} {joined} symptoms")

            # Join symptom groups
            if len(symptom_phrases) == 1:
                symptoms_text = symptom_phrases[0]
            elif len(symptom_phrases) == 2:
                symptoms_text = f"{symptom_phrases[0]}, and {symptom_phrases[1]}"
            else:
                symptoms_text = ", ".join(symptom_phrases[:-1]) + f", and {symptom_phrases[-1]}"

            # Add duration if present
            if pc_summary["duration"]:
                parts.append(f"{opening} who presented with {symptoms_text} over the last {pc_summary['duration']}.")
            else:
                parts.append(f"{opening} who presented with {symptoms_text}.")
        else:
            # No categories parsed, fall back to simpler opening
            parts.append(f"{opening}.")

        # Add impact if present
        if pc_summary["impact"]:
            parts.append(f"These symptoms impact {pos_pronoun} {pc_summary['impact']}.")

        # Add diagnoses
        if diagnoses:
            ordered = sorted(
                diagnoses,
                key=lambda d: d.get("severity", 0),
                reverse=True
            )
            dx_text = "; ".join(
                f"{d['diagnosis']} (ICD-10 {d['icd10']})"
                for d in ordered if d.get('icd10')
            )
            if dx_text:
                parts.append(f"Diagnoses under consideration include {dx_text}.")
            else:
                parts.append("No formal ICD-10 diagnosis has been selected at this stage.")
        else:
            parts.append("No formal ICD-10 diagnosis has been selected at this stage.")

        return " ".join(parts)
    # --------------------------------------------------
    # RESTORE
    # --------------------------------------------------
    def restore_state(self, state: dict):
        self._state = state or {}

        # ------------------------------
        # Restore diagnoses (safely)
        # ------------------------------
        for cb in self.dx_boxes:
            cb.blockSignals(True)
            cb.setCurrentIndex(0)
            cb.blockSignals(False)

        for cb, meta in zip(self.dx_boxes, self._state.get("dx", [])):
            if not meta:
                continue

            index = cb.findText(meta.get("diagnosis", ""))
            if index >= 0:
                cb.blockSignals(True)
                cb.setCurrentIndex(index)
                cb.blockSignals(False)

        # ------------------------------
        # Restore override
        # ------------------------------
        override = self._state.get("override", "")
        self.override_edit.blockSignals(True)
        self.override_edit.setPlainText(override)
        self.override_edit.blockSignals(False)

        # ------------------------------
        # Final preview refresh
        # ------------------------------
        self._refresh_preview()
        self.show()
    # ==================================================
    # SEND / CLOSE
    # ==================================================
    def _emit_text(self):
        text = getattr(self, '_current_text', '').strip()
        if text:
            self.sent.emit(text, self._state)
        self.close()
        
    def _on_close(self):
        self.closed.emit(self._state)
        self.close()

    def closeEvent(self, event):
        self.closed.emit(self._state)
        super().closeEvent(event)

    def hideEvent(self, event):
        """Save state when popup is hidden (navigating away)."""
        self.closed.emit(self._state)
        super().hideEvent(event)
