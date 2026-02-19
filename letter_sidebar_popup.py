# ================================================================
# SIDEBAR POPUP — AUTOCOMPLETE MEDICATION BUILDER (FINAL + CLEAN)
# ================================================================

from __future__ import annotations

from PySide6.QtCore import Qt, QPoint, QPropertyAnimation, QDate, QTimer, QEvent
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QLineEdit, QDateEdit, QScrollArea, QComboBox, QFrame
)
from PySide6.QtCore import Signal
from CANONICAL_MEDS import MEDICATIONS
from shared_widgets import add_lock_to_popup

def get_pronouns(gender: str):
    """Get pronouns for a gender. Uses central patient_demographics module."""
    try:
        from patient_demographics import get_pronouns as central_get_pronouns
        p = central_get_pronouns(gender)
        # Map keys to match expected format in this file
        return {"subj": p['subject'], "obj": p['object'], "poss": p['possessive']}
    except ImportError:
        # Fallback if central module not available
        g = (gender or "").strip().lower()
        if g == "male":
            return {"subj": "he", "obj": "him", "poss": "his"}
        if g == "female":
            return {"subj": "she", "obj": "her", "poss": "her"}
        return {"subj": "they", "obj": "them", "poss": "their"}

# ================================================================
# FREQUENCY ENGINE
# ================================================================
def generate_frequencies(info: dict) -> list[str]:
    route = (info.get("route") or "").lower()
    forms = [f.lower() for f in info.get("forms", [])]
    cls = (info.get("class") or "").lower()
    subclass = (info.get("subclass") or "").lower()
    depot = info.get("depot", False)

    if depot or "injection" in forms:
        return ["Monthly", "Fortnightly", "Weekly", "Every 3 months"]

    if any(tag in subclass for tag in ["la", "xl", "sr"]):
        return ["OD", "Nocte"]

    if "patch" in forms:
        return ["Daily", "Every 3 days", "Weekly"]

    if cls in ["antipsychotic", "benzodiazepine", "sedative", "mood stabiliser"]:
        return ["OD", "BD", "TDS", "QDS", "Nocte", "PRN"]

    if route == "oral":
        return ["OD", "BD", "TDS", "QDS", "Nocte"]

    return ["OD", "BD", "TDS"]


# ================================================================
# MEDICATION ROW
# ================================================================
class MedicationRow(QFrame):

    def __init__(self, popup):
        super().__init__(popup)
        self.popup = popup

        self.setFrameShape(QFrame.StyledPanel)
        self.setStyleSheet("""
            QFrame {
                background: rgba(255,255,255,0.70);
                border-radius: 8px;
            }
            QComboBox {
                font-size: 21px;
                padding: 4px 8px;
                min-height: 28px;
            }
            QLabel {
                font-size: 19px;
            }
            QPushButton {
                font-size: 16px;
            }
        """)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(8, 8, 8, 8)
        layout.setSpacing(6)

        # --- Top row: Medication Name + Remove button ---
        top_row = QHBoxLayout()
        self.med_name = QComboBox()
        self.med_name.setEditable(True)
        self.med_name.addItems(sorted(MEDICATIONS.keys()))
        self.med_name.currentTextChanged.connect(self.on_med_change)
        top_row.addWidget(self.med_name, 1)

        rm = QPushButton("×")
        rm.setFixedSize(32, 32)
        rm.clicked.connect(lambda: popup.remove_medication_row(self))
        top_row.addWidget(rm)
        layout.addLayout(top_row)

        # --- Bottom row: Dose + Frequency ---
        bottom_row = QHBoxLayout()
        self.dose = QComboBox()
        self.dose.setEditable(True)
        bottom_row.addWidget(self.dose, 1)

        self.freq = QComboBox()
        self.freq.setEditable(True)
        bottom_row.addWidget(self.freq, 1)
        layout.addLayout(bottom_row)

        # --- BNF label ---
        self.bnf_label = QLabel("")
        self.bnf_label.setStyleSheet("font-size: 19px; color: #666;")
        self.bnf_label.setWordWrap(True)
        layout.addWidget(self.bnf_label)

    # ------------------------------------------------------------
    def on_med_change(self, name):
        key = name.upper()
        if key not in MEDICATIONS:
            return

        info = MEDICATIONS[key]

        self.dose.clear()
        strengths = info.get("allowed_strengths", [])
        self.dose.addItems([f"{s}mg" for s in strengths])

        self.freq.clear()
        self.freq.addItems(generate_frequencies(info))

        self.bnf_label.setText(info.get("bnf_max", ""))

        # Update preview live
        self.popup.update_preview()

    # ------------------------------------------------------------
    def export_text(self):
        med = self.med_name.currentText().strip()
        if not med:
            return ""
        return f"{med}: {self.dose.currentText()} {self.freq.currentText()}"

    # ------------------------------------------------------------
    def to_dict(self):
        return {
            "med": self.med_name.currentText(),
            "dose": self.dose.currentText(),
            "freq": self.freq.currentText(),
            "bnf": self.bnf_label.text(),
        }

    # ------------------------------------------------------------
    def set_from_dict(self, d):
        self.blockSignals(True)

        med = d.get("med", "")
        self.med_name.setCurrentText(med)
        self.on_med_change(med.upper())

        self.dose.setCurrentText(d.get("dose", ""))
        self.freq.setCurrentText(d.get("freq", ""))
        self.bnf_label.setText(d.get("bnf", ""))

        self.blockSignals(False)


# ================================================================
# POPUP CLASS
# ================================================================
class FrontPageSidebarPopup(QWidget):
    gender_changed = Signal(str)
    sent = Signal(str)

    def __init__(self, key: str, title: str, parent=None, db=None, cards=None):
        super().__init__(parent)
        print("[DEBUG SidebarPopup __init__] db =", db)

        if cards is None:
            raise ValueError("cards reference must be passed to the FrontPageSidebarPopup.")

        self.key = key
        self.title = title
        self.db = db          # ✅ STORE DB HERE
        self.cards = cards    # Store the cards reference here

        # ------------------------------------------------------------
        # SAFETY: SidebarPopup is ONLY for Front Page / Medications
        # ------------------------------------------------------------
        if key not in ("front", "medications"):
            raise ValueError(
                f"SidebarPopup used for invalid section '{key}'. "
                "Clinical sections (e.g. Psychosis) must use dedicated popups."
            )

        self.saved_data = {}
        self._signals_connected = False

        self.setWindowFlags(Qt.Widget)
        self.setAttribute(Qt.WA_NoSystemBackground, True)
        self.setAttribute(Qt.WA_StyledBackground, True)
        self.setMinimumWidth(0)
        self.setMaximumWidth(420)
        
        # ------------------------------------------------------------
        # WRAPPER
        # ------------------------------------------------------------
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        outer.addWidget(scroll)

        # ------------------------------------------------------------
        # CONTAINER
        # ------------------------------------------------------------
        self.container = QWidget()
        self.container.setObjectName("popup")

        layout = QVBoxLayout(self.container)

        # Add the saved_label here
        self.saved_label = QLabel("")  # Create saved_label widget
        self.saved_label.setStyleSheet("color: green; font-size: 15px;")
        layout.addWidget(self.saved_label)  # Add it to the layout

        # Other UI elements (fields, buttons, etc.)

        layout.setContentsMargins(16, 12, 16, 16)
        layout.setSpacing(12)

        self.container.setStyleSheet("""
            QWidget#popup {
                background: rgba(255,255,255,0.60);
                border-radius: 18px;
                border: 1px solid rgba(0,0,0,0.25);
            }
            QLabel {
                font-size: 21px;
                font-weight: 600;
                color: #003c32;
                background: transparent;
                border: none;
            }
            QLineEdit {
                font-size: 21px;
                padding: 4px 8px;
            }
            QComboBox {
                font-size: 21px;
                padding: 4px 8px;
            }
            QDateEdit {
                font-size: 21px;
                padding: 4px 8px;
            }
        """)

        scroll.setWidget(self.container)




        # ============================================================
        # FRONT PAGE FIELDS
        # ============================================================

        # ============================================================
        # FRONT PAGE FIELDS - Vertical Layout
        # ============================================================

        # ----------------------------
        # Patient Name (full width)
        # ----------------------------
        name_lab = QLabel("Patient Name")
        self.name_field = QLineEdit()
        self.name_field.setMinimumHeight(32)
        layout.addWidget(name_lab)
        layout.addWidget(self.name_field)

        # ----------------------------
        # DOB and Age row
        # ----------------------------
        dob_age_row = QHBoxLayout()

        dob_col = QVBoxLayout()
        dob_lab = QLabel("DOB")
        self.dob_field = QDateEdit()
        self.dob_field.setDisplayFormat("dd/MM/yyyy")
        self.dob_field.setCalendarPopup(True)
        self.dob_field.setMinimumHeight(32)
        self.dob_field.setMaximumDate(QDate.currentDate())  # No future DOB
        self.dob_field.setMinimumDate(QDate.currentDate().addYears(-115))  # Max 115 years ago
        self._style_calendar(self.dob_field)
        dob_col.addWidget(dob_lab)
        dob_col.addWidget(self.dob_field)

        age_col = QVBoxLayout()
        age_lab = QLabel("Age")
        self.age_field = QLineEdit()
        self.age_field.setMinimumHeight(32)
        self.age_field.setReadOnly(True)
        self.age_field.setStyleSheet("background: #f0f0f0; color: #333; font-size: 21px;")
        age_col.addWidget(age_lab)
        age_col.addWidget(self.age_field)

        # Connect DOB changes to age calculation
        self.dob_field.dateChanged.connect(self._update_age_from_dob)

        dob_age_row.addLayout(dob_col, 2)
        dob_age_row.addLayout(age_col, 1)
        layout.addLayout(dob_age_row)

        # ----------------------------
        # NHS Number (full width)
        # ----------------------------
        nhs_lab = QLabel("NHS Number")
        self.nhs_field = QLineEdit()
        self.nhs_field.setMinimumHeight(32)
        layout.addWidget(nhs_lab)
        layout.addWidget(self.nhs_field)

        # ----------------------------
        # Gender (full width)
        # ----------------------------
        gender_lab = QLabel("Gender")
        self.gender_field = QComboBox()
        self.gender_field.addItems(
                ["Male", "Female", "Other", "Prefer not to say"]
        )
        self.gender_field.setMinimumHeight(32)
        layout.addWidget(gender_lab)
        layout.addWidget(self.gender_field)


        # ------------------------------------------------------------
        # SECOND ROW — Letter metadata
        # ------------------------------------------------------------

        # ----------------------------
        # Clinician (full width)
        # ----------------------------
        clin_lab = QLabel("Clinician")
        self.clinician_field = QLineEdit()
        self.clinician_field.setMinimumHeight(32)
        layout.addWidget(clin_lab)
        layout.addWidget(self.clinician_field)

        # ----------------------------
        # Date of Letter (full width)
        # ----------------------------
        date_lab = QLabel("Date of Letter")
        self.date_field = QDateEdit()
        self.date_field.setDisplayFormat("dd MMMM yyyy")
        self.date_field.setCalendarPopup(True)
        self.date_field.setDate(QDate.currentDate())
        self.date_field.setMaximumDate(QDate.currentDate())  # No future dates
        self.date_field.setMinimumHeight(32)
        self._style_calendar(self.date_field)
        layout.addWidget(date_lab)
        layout.addWidget(self.date_field)



        # ------------------------------------------------------------
        # MEDICATION LIST
        # ------------------------------------------------------------
        layout.addWidget(QLabel("Current Medications"))
        self.med_list = QVBoxLayout()
        layout.addLayout(self.med_list)

        add_btn = QPushButton("+ Add Medication")
        add_btn.clicked.connect(self.add_medication_row)
        layout.addWidget(add_btn)

        layout.addStretch()

        # ------------------------------------------------------------
        # MEDICATION ROW STORAGE (must be created BEFORE preview logic)
        # ------------------------------------------------------------
        self.rows = []

        # Add lock functionality (button hidden - controlled by header)
        add_lock_to_popup(self, show_button=False)

    # ============================================================
    #  CALENDAR STYLING
    # ============================================================
    def _style_calendar(self, date_edit):
        """Apply clean styling to QDateEdit calendar popup."""
        calendar = date_edit.calendarWidget()
        calendar.setStyleSheet("""
            QCalendarWidget {
                background: white;
            }
            QCalendarWidget QWidget#qt_calendar_navigationbar {
                background: #008C7E;
            }
            QCalendarWidget QToolButton {
                color: white;
                background: transparent;
                font-size: 22px;
                font-weight: bold;
                padding: 4px 8px;
            }
            QCalendarWidget QToolButton:hover {
                background: rgba(255,255,255,0.2);
                border-radius: 4px;
            }
            QCalendarWidget QMenu {
                background: white;
                color: #333;
            }
            QCalendarWidget QSpinBox {
                background: white;
                color: #333;
                selection-background-color: #008C7E;
            }
            QCalendarWidget QTableView {
                background: white;
                selection-background-color: #008C7E;
                selection-color: white;
            }
            QCalendarWidget QTableView::item:hover {
                background: rgba(0,140,126,0.2);
            }
            QCalendarWidget QHeaderView::section {
                background: #f5f5f5;
                color: #333;
                font-weight: 600;
                padding: 4px;
                border: none;
            }
            QCalendarWidget #qt_calendar_prevmonth,
            QCalendarWidget #qt_calendar_nextmonth {
                qproperty-icon: none;
                color: white;
                font-size: 24px;
                font-weight: bold;
            }
        """)

    # ============================================================
    #  AGE CALCULATION FROM DOB
    # ============================================================
    def _update_age_from_dob(self, dob: QDate):
        """Calculate and display age from DOB."""
        if not dob.isValid():
            self.age_field.setText("")
            return

        today = QDate.currentDate()
        age = today.year() - dob.year()

        # Adjust if birthday hasn't occurred yet this year
        if (today.month(), today.day()) < (dob.month(), dob.day()):
            age -= 1

        self.age_field.setText(str(age))

    def get_age(self) -> int:
        """Return the calculated age as integer."""
        try:
            return int(self.age_field.text())
        except (ValueError, TypeError):
            return 0

    # ============================================================
    #  GENDER CHANGE HANDLER
    # ============================================================
    def _emit_gender_changed(self, gender_text: str):
        """Emit signal when gender changes so popups can update pronouns."""
        self.gender_changed.emit(gender_text.strip().lower())

    # ============================================================
    #  SAVE FRONT PAGE DATA
    # ============================================================
    def collect_saved_data(self):
        """Collect all front page settings (canonical fields)."""
        full = self.name_field.text().strip()
        first = full.split()[0] if full else "the patient"

        gender = self.gender_field.currentText().strip().lower()
        pron = get_pronouns(gender)

        return {
            "full_name": full,
            "first_name": first,
            "gender": gender,
            "pronouns": pron,
            "dob": self.dob_field.date(),
            "age": self.get_age(),
            "nhs": self.nhs_field.text(),
            "clinician": self.clinician_field.text(),
            "date": self.date_field.date(),
            "meds": [r.to_dict() for r in self.rows],
        }

    def save_and_close(self):
        self.saved_data = self.collect_saved_data()
        self.close()


    # ============================================================
    # SEND TO CARD ON CHANGE
    # ============================================================
    def update_preview(self):
        """Legacy method name - now sends to card immediately."""
        self._send_to_card()

    def _send_to_card(self):
        """Send current text to card immediately."""
        self.save_current()
        text = self.formatted_front_page_text().strip()
        if text:
            self.sent.emit(text)
    # ============================================================
    # EXPORT — final formatted version (no gender)
    # ============================================================
    def export_medications(self):
        """Return clean list of medications with no trailing newline."""
        meds = [r.export_text() for r in self.rows if r.export_text()]
        return "\n".join(meds)   # no trailing \n

    def formatted_front_page_text(self):
        base = (
            f"Patient: {self.name_field.text()}  \n"
            f"DOB: {self.dob_field.date().toString('dd/MM/yyyy')}  \n"
            f"Gender: {self.gender_field.currentText()}  \n"
            f"NHS Number: {self.nhs_field.text()}  \n"
            f"Clinician: {self.clinician_field.text()}  \n"
            f"Date of Letter: {self.date_field.date().toString('dd MMMM yyyy')}  \n"
        )

        meds = self.export_medications().strip()
        if meds:
            formatted_meds = meds.replace("\n", "  \n")
            base += f"\nMedications:  \n{formatted_meds}  \n"

        return base



    # ============================================================
    # SHOW EVENT — wire up preview
    # ============================================================
    def showEvent(self, event):
        super().showEvent(event)

        # Load saved state AFTER widgets exist
        QTimer.singleShot(0, self.load_saved)

        # Connect preview update signals only once
        if not self._signals_connected:
            self.name_field.textChanged.connect(self.update_preview)
            self.gender_field.currentTextChanged.connect(self.update_preview)
            self.gender_field.currentTextChanged.connect(self._emit_gender_changed)
            self.dob_field.dateChanged.connect(self.update_preview)
            self.nhs_field.textChanged.connect(self.update_preview)
            self.clinician_field.textChanged.connect(self.update_preview)
            self.date_field.dateChanged.connect(self.update_preview)
            self._signals_connected = True

        for r in self.rows:
            if hasattr(r, "changed"):
                r.changed.connect(self.update_preview)

        QTimer.singleShot(10, self.update_preview)

    # ============================================================
    # MEDICATION CONTROL
    # ============================================================
    def add_medication_row(self):
        row = MedicationRow(self)
        self.rows.append(row)
        self.med_list.addWidget(row)
        self.update_preview()

    def remove_medication_row(self, row):
        self.rows.remove(row)
        row.setParent(None)
        row.deleteLater()
        self.update_preview()




    # ============================================================
    # MEMORY
    # ============================================================
    def save_current(self):
        full = self.name_field.text().strip()
        first = full.split()[0] if full else "the patient"

        gender = self.gender_field.currentText().strip()
        pron = get_pronouns(gender)

        self.saved_data = {
            "full_name": full,
            "first_name": first,
            "gender": gender,
            "pronouns": pron,
            "dob": self.dob_field.date(),
            "age": self.get_age(),
            "nhs": self.nhs_field.text(),
            "clinician": self.clinician_field.text(),
            "date": self.date_field.date(),
            "meds": [r.to_dict() for r in self.rows],
        }
        
    def populate_from_shared_store(self):
        """Populate empty fields from SharedDataStore patient demographics."""
        try:
            from shared_data_store import get_shared_store
            store = get_shared_store()
            patient_info = store.patient_info

            if not patient_info:
                return

            # Only fill fields that are empty
            if patient_info.get("name") and not self.name_field.text().strip():
                self.name_field.setText(patient_info["name"])
                print(f"[FrontPagePopup] Auto-filled name from SharedDataStore: {patient_info['name']}")

            if patient_info.get("gender"):
                current_gender = self.gender_field.currentText().strip().lower()
                if not current_gender or current_gender == "prefer not to say":
                    gender = patient_info["gender"].capitalize()
                    idx = self.gender_field.findText(gender)
                    if idx >= 0:
                        self.gender_field.setCurrentIndex(idx)
                        print(f"[FrontPagePopup] Auto-filled gender from SharedDataStore: {gender}")

            if patient_info.get("dob"):
                # Only update if DOB is at default (01/01/2000 or current date)
                current_dob = self.dob_field.date()
                if current_dob == QDate(2000, 1, 1) or current_dob == QDate.currentDate():
                    dob = patient_info["dob"]
                    if hasattr(dob, 'year'):
                        self.dob_field.setDate(QDate(dob.year, dob.month, dob.day))
                        self._update_age_from_dob(self.dob_field.date())
                        print(f"[FrontPagePopup] Auto-filled DOB from SharedDataStore")

            if patient_info.get("nhs_number") and not self.nhs_field.text().strip():
                self.nhs_field.setText(patient_info["nhs_number"])
                print(f"[FrontPagePopup] Auto-filled NHS from SharedDataStore: {patient_info['nhs_number']}")

        except ImportError:
            pass
        except Exception as e:
            print(f"[FrontPagePopup] Error populating from SharedDataStore: {e}")

    def load_saved(self):
        print(">>> [STEP 3] SidebarPopup.load_saved CALLED")
        print(">>> [STEP 3] self.db =", self.db)

        details = self.db.get_clinician_details()
        clinician_from_db = ""
        if details:
            (
                _id,
                full_name,
                role_title,
                discipline,
                *_rest
            ) = details
            clinician_from_db = full_name or ""

        print("[DEBUG] Clinician data fetched:", clinician_from_db)

        current_text = self.clinician_field.text().strip()

        if not current_text and clinician_from_db:
            print("[DEBUG] Updating clinician field with DB value")
            self.clinician_field.setText(clinician_from_db)

        d = self.saved_data or {}

        clinician_text = d.get("clinician") or clinician_from_db

        if d:
            self.name_field.setText(d.get("full_name", ""))
            self.gender_field.setCurrentText(d.get("gender", "").capitalize())
            self.dob_field.setDate(d.get("dob", QDate.currentDate()))
            self._update_age_from_dob(self.dob_field.date())  # Explicitly update age
            self.nhs_field.setText(d.get("nhs", ""))
            self.date_field.setDate(d.get("date", QDate.currentDate()))

        # If fields still empty after loading saved data, try SharedDataStore
        self.populate_from_shared_store()

        if clinician_text:
            print("[DEBUG] Setting clinician field to:", clinician_text)
            self.clinician_field.setText(clinician_text)

        for r in self.rows:
            r.setParent(None)
            r.deleteLater()
        self.rows = []

        for m in d.get("meds", []):
            row = MedicationRow(self)
            row.set_from_dict(m)
            self.rows.append(row)
            self.med_list.addWidget(row)

        self.update_preview()

        print("[DEBUG AFTER load_saved] clinician_field.text() =", self.clinician_field.text())

    # Assuming 'front' card is being created
    def send_to_letter(self):
        # Save state before sending
        self.save_current()

        # Gather the data from the fields
        patient_name = self.name_field.text()
        dob = self.dob_field.date().toString('dd/MM/yyyy')
        nhs = self.nhs_field.text()
        clinician = self.clinician_field.text()
        date_of_letter = self.date_field.date().toString('dd MMMM yyyy')
        
        # Here, you can collect the medications or other necessary data
        medications = [row.export_text() for row in self.rows]

        # Check if medications are available, if not, set a default message
        medications_text = ', '.join(medications) if medications else "No medications listed"

        # Format the letter content
        letter_text = f"""
        Patient Name: {patient_name}
        DOB: {dob}
        NHS Number: {nhs}
        Clinician: {clinician}
        Date of Letter: {date_of_letter}
        
        Medications: {medications_text}
        """

        # Emit the text to update the card
        if letter_text.strip():
            self.sent.emit(letter_text)

    def hideEvent(self, event):
        """Auto-send to letter when popup is hidden (navigating away)."""
        self.send_to_letter()
        super().hideEvent(event)
