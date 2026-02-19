from __future__ import annotations

from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import (
        QWidget, QLabel, QPushButton,
        QVBoxLayout, QHBoxLayout,
        QScrollArea, QCheckBox, QSizePolicy, QFrame, QTextEdit
)
from PySide6.QtWidgets import QGraphicsDropShadowEffect
from PySide6.QtGui import QColor
from PySide6.QtWidgets import QRadioButton, QButtonGroup
from background_history_popup import CollapsibleSection
from shared_widgets import add_lock_to_popup
from spell_check_textedit import enable_spell_check_on_textedit

# ======================================================
# PLAN DATA
# ======================================================
CAPACITY_DOMAINS = [
        "medication",
        "finances",
        "residence",
        "self-care",
]
PLAN_SECTIONS = {
        "Psychoeducation": [
                "Diagnosis discussed with patient",
                "Medication / side-effects discussed",
        ],
        "Psychology": [
                "Psychology referral made",
                "CBT recommended",
                "Trauma-focused therapy considered",
        ],
        "Occupational Therapy": [
                "Continue with current\noccupational therapy",
                "OT assessment requested",
        ],
        "Care Coordination": [
                "Needs care coordinator -\nreferral to be made",
                "Continue with care coordination\nand CPA process",
        ],
        "Physical Health": [
                "Please can you arrange",
                "Annual physical",
                "U&Es",
                "FBC",
                "LFTs",
                "TFTs",
                "PSA",
                "Haematinics",
                "ECG",
                "CXR",
        ],

        "Letter Signed By": [
                "Consultant Psychiatrist",
                "Specialty Doctor",
                "Registrar",
        ],

}


# ======================================================
# PLAN POPUP
# ======================================================
def pronouns_from_gender(g: str):
        """Return pronoun dict based on gender string."""
        g = (g or "").strip().lower()
        if g == "male":
                return {"subj": "he", "obj": "him", "pos": "his", "be": "is", "have": "has"}
        if g == "female":
                return {"subj": "she", "obj": "her", "pos": "her", "be": "is", "have": "has"}
        return {"subj": "they", "obj": "them", "pos": "their", "be": "are", "have": "have"}


class PlanPopup(QWidget):
        sent = Signal(str, dict)
        closed = Signal(dict)

        def update_gender(self, gender: str):
                """Update pronouns when gender changes on front page."""
                self.gender = gender
                self._refresh_preview()

        def update_front_page(self, front_page: dict):
                """Update front page data when it changes."""
                self.front_page = front_page or {}
                self._refresh_preview()

        def __init__(self, parent=None, current_meds=None, gender=None, front_page=None, mydetails=None):
                super().__init__(parent)

                self.gender = gender
                self.front_page = front_page or {}
                self.mydetails = mydetails or {}

                # ------------------------------
                # HARDEN AGAINST NONE / MISSING
                # ------------------------------
                if not current_meds:
                        self.current_meds = []
                else:
                        self.current_meds = list(current_meds)

                self._med_action = None

                # ------------------------------
                # WINDOW — fixed panel
                # ------------------------------
                self.setWindowFlags(Qt.WindowType.Widget)
                self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)

                # ------------------------------
                # STATE (CRITICAL)
                # ------------------------------
                self._checkboxes = {k: [] for k in PLAN_SECTIONS}
                self._expanded_sections = set()
                self.next_appt_date = None

                # ==================================================
                # ROOT
                # ==================================================
                root = QVBoxLayout(self)
                root.setContentsMargins(0, 0, 0, 0)
                root.setSpacing(8)

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

                card = QWidget()
                card.setObjectName("plan_container")
                card.setStyleSheet("""
                        QWidget#plan_container {
                                background: rgba(255,255,255,0.94);
                                border-radius: 12px;
                                border: 1px solid rgba(0,0,0,0.18);
                        }
                        QLabel {
                                background: transparent;
                                border: none;
                        }
                """)
                main_layout.addWidget(card)

                self.form = QVBoxLayout(card)
                self.form.setContentsMargins(16, 14, 16, 14)
                self.form.setSpacing(6)

                # ==================================================
                # MEDICATION (RADIO ACTIONS)
                # ==================================================
                container, arrow = self._collapsible_section("Medication")

                self.med_group = QButtonGroup(self)
                self.med_group.setExclusive(True)
                self._med_action = None

                # Store radio buttons for reference
                self._med_radios = {}
                for label in ["Start", "Stop", "Increase", "Decrease"]:
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
                        rb.clicked.connect(
                                lambda _, l=label: self._set_med_action(l.lower())
                        )
                        self.med_group.addButton(rb)
                        container.layout().addWidget(rb)
                        self._med_radios[label.lower()] = rb

                # --------------------------------------------------------
                # START MEDICATION ENTRY (shown only when Start is selected)
                # --------------------------------------------------------
                from PySide6.QtWidgets import QComboBox, QFrame
                from CANONICAL_MEDS import MEDICATIONS

                # Standard frequency options
                FREQUENCY_OPTIONS = ["OD", "BD", "TDS", "QDS", "Nocte", "PRN", "Weekly", "Fortnightly", "Monthly"]

                self._start_med_container = QFrame()
                self._start_med_container.setStyleSheet("""
                        QFrame {
                                background: rgba(0,140,126,0.08);
                                border-radius: 8px;
                                padding: 8px;
                                margin-top: 6px;
                        }
                """)
                self._start_med_container.setVisible(False)

                start_layout = QVBoxLayout(self._start_med_container)
                start_layout.setContentsMargins(8, 8, 8, 8)
                start_layout.setSpacing(6)

                # Medication name dropdown
                name_row = QHBoxLayout()
                name_row.addWidget(QLabel("Medication:"))
                self._start_med_name = QComboBox()
                self._start_med_name.setEditable(True)
                self._start_med_name.addItem("")
                self._start_med_name.addItems(sorted(MEDICATIONS.keys()))
                self._start_med_name.currentTextChanged.connect(self._on_start_med_change)
                self._start_med_name.setMinimumWidth(180)
                name_row.addWidget(self._start_med_name)
                name_row.addStretch()
                start_layout.addLayout(name_row)

                # Dose dropdown
                dose_row = QHBoxLayout()
                dose_row.addWidget(QLabel("Dose:"))
                self._start_med_dose = QComboBox()
                self._start_med_dose.setEditable(True)
                self._start_med_dose.setMinimumWidth(100)
                self._start_med_dose.currentTextChanged.connect(self._refresh_preview)
                dose_row.addWidget(self._start_med_dose)
                dose_row.addStretch()
                start_layout.addLayout(dose_row)

                # Frequency dropdown
                freq_row = QHBoxLayout()
                freq_row.addWidget(QLabel("Frequency:"))
                self._start_med_freq = QComboBox()
                self._start_med_freq.addItems(FREQUENCY_OPTIONS)
                self._start_med_freq.currentTextChanged.connect(self._refresh_preview)
                freq_row.addWidget(self._start_med_freq)
                freq_row.addStretch()
                start_layout.addLayout(freq_row)

                # BNF Max label
                self._start_med_bnf = QLabel("")
                self._start_med_bnf.setStyleSheet("font-size: 21px; color: #666; font-style: italic;")
                start_layout.addWidget(self._start_med_bnf)

                container.layout().addWidget(self._start_med_container)

                # Store MEDICATIONS reference for dose lookup
                self._medications_db = MEDICATIONS

                # --------------------------------------------------------
                # EXISTING MEDS HINT (for stop/increase/decrease)
                # --------------------------------------------------------
                # All radios are enabled - Stop/Increase/Decrease can be used to clear Start selection
                # They just won't produce output if no current_meds
                if not self.current_meds:
                        self._no_meds_hint = QLabel("(Stop/Increase/Decrease use\ncurrent medications from\nfront page)")
                        self._no_meds_hint.setWordWrap(True)
                        self._no_meds_hint.setStyleSheet(
                                "font-size:22px; color:#999; padding-left:22px; margin-top:4px;"
                        )
                        container.layout().addWidget(self._no_meds_hint)
                else:
                        self._no_meds_hint = None

                self._checkboxes["Medication"] = []

                # ==================================================
                # PSYCHOEDUCATION
                # ==================================================
                container, arrow = self._collapsible_section("Psychoeducation")

                dx_cb = QCheckBox("Diagnosis discussed with patient")
                dx_cb.setStyleSheet("font-size:22px;")
                med_cb = QCheckBox("Medication / side-effects discussed")
                med_cb.setStyleSheet("font-size:22px;")

                dx_cb.stateChanged.connect(self._refresh_preview)
                med_cb.stateChanged.connect(self._refresh_preview)

                self._checkboxes["Psychoeducation"] = [dx_cb, med_cb]

                container.layout().addWidget(dx_cb)
                container.layout().addWidget(med_cb)

                # ------------------------------
                # Capacity
                # ------------------------------
                container, arrow = self._collapsible_section("Capacity")

                from PySide6.QtWidgets import QComboBox

                self.capacity_group = QButtonGroup(self)
                self.capacity_group.setExclusive(True)

                self.capacity_status = None
                self.capacity_domain = None

                has_rb = QRadioButton("Has capacity")
                has_rb.setStyleSheet("""
                                            QRadioButton {
                                                font-size: 22px;
                                                background: transparent;
                                            }
                                            QRadioButton::indicator {
                                                width: 18px;
                                                height: 18px;
                                            }
                                        """)
                lacks_rb = QRadioButton("Lacks capacity")
                lacks_rb.setStyleSheet("""
                                            QRadioButton {
                                                font-size: 22px;
                                                background: transparent;
                                            }
                                            QRadioButton::indicator {
                                                width: 18px;
                                                height: 18px;
                                            }
                                        """)

                self.capacity_group.addButton(has_rb)
                self.capacity_group.addButton(lacks_rb)

                domain_box = QComboBox()
                domain_box.addItems([
                        "medication",
                        "finances",
                        "residence",
                        "self-care",
                ])
                domain_box.setEnabled(False)
                domain_box.setStyleSheet("""
                        QComboBox {
                                font-size: 22px;
                                padding: 6px 10px;
                                border: 2px solid rgba(0,140,126,0.4);
                                border-radius: 6px;
                                background: white;
                                min-width: 100px;
                        }
                        QComboBox:disabled {
                                border: 2px solid rgba(0,0,0,0.15);
                                background: #f5f5f5;
                                color: #999;
                        }
                        QComboBox QAbstractItemView {
                                background: white;
                        }
                        QComboBox QAbstractItemView::item {
                                color: black;
                                padding: 4px;
                        }
                        QComboBox QAbstractItemView::item:hover {
                                background-color: #FFEB3B;
                                color: black;
                        }
                        QComboBox QAbstractItemView::item:selected {
                                background-color: #FFEB3B;
                                color: black;
                        }
                """)


                def capacity_changed():
                        btn = self.capacity_group.checkedButton()
                        if not btn:
                                return
                        self.capacity_status = "has" if btn is has_rb else "lacks"
                        domain_box.setEnabled(True)
                        self.capacity_domain = domain_box.currentText()
                        self._refresh_preview()
                self._capacity_domain_box = domain_box

                def domain_changed(text):
                        self.capacity_domain = text
                        self._refresh_preview()

                has_rb.toggled.connect(capacity_changed)
                lacks_rb.toggled.connect(capacity_changed)
                domain_box.currentTextChanged.connect(domain_changed)

                container.layout().addSpacing(10)
                container.layout().addWidget(has_rb)
                container.layout().addWidget(lacks_rb)
                container.layout().addWidget(domain_box)
                

                # ==================================================
                # PSYCHOLOGY
                # ==================================================
                container, arrow = self._collapsible_section("Psychology")

                self.psych_group = QButtonGroup(self)
                self.psych_group.setExclusive(True)

                self.psych_status = None
                self.psych_therapy = None

                psych_continue = QRadioButton("Continue")
                psych_continue.setStyleSheet("""
                        QRadioButton {
                            font-size: 22px;
                            background: transparent;
                        }
                        QRadioButton::indicator {
                            width: 18px;
                            height: 18px;
                        }
                """)
                psych_start = QRadioButton("Start")
                psych_start.setStyleSheet("""
                        QRadioButton {
                            font-size: 22px;
                            background: transparent;
                        }
                        QRadioButton::indicator {
                            width: 18px;
                            height: 18px;
                        }
                """)
                psych_refused = QRadioButton("Refused")
                psych_refused.setStyleSheet("""
                        QRadioButton {
                            font-size: 22px;
                            background: transparent;
                        }
                        QRadioButton::indicator {
                            width: 18px;
                            height: 18px;
                        }
                """)

                self.psych_group.addButton(psych_continue)
                self.psych_group.addButton(psych_start)
                self.psych_group.addButton(psych_refused)

                therapy_box = QComboBox()
                therapy_box.addItems([
                        "CBT",
                        "Trauma-focussed",
                        "DBT",
                        "Psychodynamic",
                        "Supportive",
                ])
                therapy_box.setEnabled(False)
                therapy_box.setStyleSheet("""
                        QComboBox {
                                font-size: 22px;
                                padding: 6px 10px;
                                border: 2px solid rgba(0,140,126,0.4);
                                border-radius: 6px;
                                background: white;
                                min-width: 100px;
                        }
                        QComboBox:disabled {
                                border: 2px solid rgba(0,0,0,0.15);
                                background: #f5f5f5;
                                color: #999;
                        }
                        QComboBox QAbstractItemView {
                                background: white;
                        }
                        QComboBox QAbstractItemView::item {
                                color: black;
                                padding: 4px;
                        }
                        QComboBox QAbstractItemView::item:hover {
                                background-color: #FFEB3B;
                                color: black;
                        }
                        QComboBox QAbstractItemView::item:selected {
                                background-color: #FFEB3B;
                                color: black;
                        }
                """)

                def psych_changed():
                        btn = self.psych_group.checkedButton()
                        if not btn:
                                return

                        if btn is psych_continue:
                                self.psych_status = "continue"
                        elif btn is psych_start:
                                self.psych_status = "start"
                        else:
                                self.psych_status = "refused"

                        therapy_box.setEnabled(True)
                        self.psych_therapy = therapy_box.currentText()
                        self._refresh_preview()

                        
                def therapy_changed(text):
                        self.psych_therapy = text
                        self._refresh_preview()

                psych_continue.toggled.connect(psych_changed)
                psych_start.toggled.connect(psych_changed)
                psych_refused.toggled.connect(psych_changed)
                therapy_box.currentTextChanged.connect(therapy_changed)

                container.layout().addWidget(psych_continue)
                container.layout().addWidget(psych_start)
                container.layout().addWidget(psych_refused)
                container.layout().addWidget(therapy_box)
                self._psych_therapy_box = therapy_box


                self._checkboxes["Psychology"] = []

                # ==================================================
                # OTHER PLAN SECTIONS
                # ==================================================
                for section, items in PLAN_SECTIONS.items():
                        if section in ("Medication", "Psychoeducation", "Psychology", "Next Appointment"):
                                continue

                        container, arrow = self._collapsible_section(section)

                        # ------------------------------
                        # Occupational Therapy (RADIO)
                        # ------------------------------
                        if section == "Occupational Therapy":
                                self.ot_group = QButtonGroup(self)
                                self.ot_group.setExclusive(True)
                                self.ot_status = None

                                for label in items:
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
                                        self.ot_group.addButton(rb)
                                        rb.toggled.connect(self._refresh_preview)
                                        container.layout().addWidget(rb)

                                def ot_changed():
                                        btn = self.ot_group.checkedButton()
                                        self.ot_status = btn.text() if btn else None
                                        self._refresh_preview()

                                for rb in self.ot_group.buttons():
                                        rb.toggled.connect(ot_changed)

                                self._checkboxes["Occupational Therapy"] = []
                                continue

                        # ------------------------------
                        # Care Coordination (RADIO)
                        # ------------------------------
                        if section == "Care Coordination":
                                self.care_group = QButtonGroup(self)
                                self.care_group.setExclusive(True)
                                self.care_status = None

                                for label in items:
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
                                        self.care_group.addButton(rb)
                                        rb.toggled.connect(self._refresh_preview)
                                        container.layout().addWidget(rb)

                                def care_changed():
                                        btn = self.care_group.checkedButton()
                                        self.care_status = btn.text() if btn else None
                                        self._refresh_preview()

                                for rb in self.care_group.buttons():
                                        rb.toggled.connect(care_changed)

                                self._checkboxes["Care Coordination"] = []
                                continue

                        # ------------------------------
                        # Physical Health (GATED)
                        # ------------------------------
                        if section == "Physical Health":
                                ph_items = PLAN_SECTIONS["Physical Health"]

                                master_cb = QCheckBox("Please can you arrange")
                                master_cb.setStyleSheet("font-size:22px;")
                                container.layout().addWidget(master_cb)
                                self._checkboxes[section].append(master_cb)

                                detail_cbs = []

                                for label in ph_items:
                                        if label == "Please can you arrange":
                                                continue

                                        cb = QCheckBox(label)
                                        cb.setStyleSheet("font-size:22px;")
                                        cb.setEnabled(False)
                                        cb.stateChanged.connect(self._refresh_preview)

                                        print("[PH] created detail cb:", label)

                                        detail_cbs.append(cb)
                                        self._checkboxes[section].append(cb)
                                        container.layout().addWidget(cb)

                                def toggle_details(checked: bool):
                                        print("[PH] master_cb toggled:", checked)

                                        for cb in detail_cbs:
                                                cb.setEnabled(checked)
                                                if not checked:
                                                        cb.setChecked(False)

                                        # ❌ DO NOT CALL _refresh_preview HERE
                                        # preview may not exist yet

                                # ✅ correct signal (bool, not CheckState)
                                master_cb.toggled.connect(toggle_details)

                                # ✅ preview refresh only on user action
                                master_cb.toggled.connect(self._refresh_preview)

                                for cb in detail_cbs:
                                        cb.toggled.connect(self._refresh_preview)

                                # ✅ INITIAL UI STATE ONLY (SAFE)
                                toggle_details(False)

                                # store for restore_state
                                self._physical_health_master = master_cb
                                self._physical_health_gate = toggle_details



                                continue





                        # ------------------------------
                        # Letter Signed By (RADIO + Registrar grade)
                        # ------------------------------
                        if section == "Letter Signed By":
                                self.signatory_group = QButtonGroup(self)
                                self.signatory_group.setExclusive(True)

                                consultant_rb = QRadioButton("Consultant Psychiatrist")
                                consultant_rb.setStyleSheet("""
                                            QRadioButton {
                                                font-size: 22px;
                                                background: transparent;
                                            }
                                            QRadioButton::indicator {
                                                width: 18px;
                                                height: 18px;
                                            }
                                        """)
                                specialty_rb = QRadioButton("Specialty Doctor")
                                specialty_rb.setStyleSheet("""
                                            QRadioButton {
                                                font-size: 22px;
                                                background: transparent;
                                            }
                                            QRadioButton::indicator {
                                                width: 18px;
                                                height: 18px;
                                            }
                                        """)
                                registrar_rb = QRadioButton("Registrar")
                                registrar_rb.setStyleSheet("""
                                            QRadioButton {
                                                font-size: 22px;
                                                background: transparent;
                                            }
                                            QRadioButton::indicator {
                                                width: 18px;
                                                height: 18px;
                                            }
                                        """)

                                for rb in (consultant_rb, specialty_rb, registrar_rb):
                                        self.signatory_group.addButton(rb)
                                        rb.toggled.connect(self._refresh_preview)
                                        container.layout().addWidget(rb)

                                from PySide6.QtWidgets import QComboBox

                                grade_box = QComboBox()
                                grade_box.addItems([
                                        "CT1", "CT2", "CT3",
                                        "ST4", "ST5", "ST6",
                                ])
                                grade_box.setEnabled(False)
                                grade_box.setStyleSheet("""
                                        QComboBox {
                                                font-size: 22px;
                                                padding: 6px 10px;
                                                border: 2px solid rgba(0,140,126,0.4);
                                                border-radius: 6px;
                                                background: white;
                                                min-width: 100px;
                                        }
                                        QComboBox:disabled {
                                                border: 2px solid rgba(0,0,0,0.15);
                                                background: #f5f5f5;
                                                color: #999;
                                        }
                                        QComboBox QAbstractItemView {
                                                background: white;
                                        }
                                        QComboBox QAbstractItemView::item {
                                                color: black;
                                                padding: 4px;
                                        }
                                        QComboBox QAbstractItemView::item:hover {
                                                background-color: #FFEB3B;
                                                color: black;
                                        }
                                        QComboBox QAbstractItemView::item:selected {
                                                background-color: #FFEB3B;
                                                color: black;
                                        }
                                """)
                                container.layout().addWidget(grade_box)

                                self.registrar_grade = None

                                def signer_changed():
                                        if registrar_rb.isChecked():
                                                grade_box.setEnabled(True)
                                                self.registrar_grade = grade_box.currentText()
                                        else:
                                                grade_box.setEnabled(False)
                                                self.registrar_grade = None
                                        self._refresh_preview()

                                def grade_changed(text):
                                        self.registrar_grade = text
                                        self._refresh_preview()
                                self._registrar_grade_box = grade_box

                                consultant_rb.toggled.connect(signer_changed)
                                specialty_rb.toggled.connect(signer_changed)
                                registrar_rb.toggled.connect(signer_changed)
                                grade_box.currentTextChanged.connect(grade_changed)

                                self._checkboxes["Letter Signed By"] = []
                                continue


                        # ------------------------------
                        # Generic checkbox sections
                        # ------------------------------
                        for text in items:
                                cb = QCheckBox(text)
                                cb.setStyleSheet("font-size:22px;")
                                cb.stateChanged.connect(
                                        self._on_checked_factory(section, container, arrow)
                                )
                                cb.stateChanged.connect(self._refresh_preview)
                                print("[PH] created detail cb:", label)
                                self._checkboxes[section].append(cb)
                                container.layout().addWidget(cb)

                # ==================================================
                # NEXT APPOINTMENT (DATE PICKER)
                # ==================================================
                container, arrow = self._collapsible_section("Next Appointment")

                from PySide6.QtWidgets import QDateEdit
                from PySide6.QtCore import QDate

                self.next_appt_date = None

                date_edit = QDateEdit()
                date_edit.setCalendarPopup(True)
                date_edit.setDisplayFormat("dd MMM yyyy")
                date_edit.setDate(QDate.currentDate())
                date_edit.setMinimumDate(QDate.currentDate())
                date_edit.setMaximumWidth(200)
                date_edit.setStyleSheet("""
                        QDateEdit {
                                font-size: 22px;
                                padding: 6px 10px;
                                border: 2px solid rgba(0,140,126,0.4);
                                border-radius: 6px;
                                background: white;
                        }
                        QDateEdit::drop-down {
                                border: none;
                                width: 30px;
                                background: transparent;
                        }
                        QDateEdit::down-arrow {
                                image: none;
                                border-left: 5px solid transparent;
                                border-right: 5px solid transparent;
                                border-top: 6px solid #008C7E;
                                margin-right: 10px;
                        }
                """)
                self._style_calendar(date_edit)

                def date_changed(qdate):
                        self.next_appt_date = qdate
                        self._refresh_preview()

                date_edit.dateChanged.connect(date_changed)

                select_lbl = QLabel("Select date:")
                select_lbl.setStyleSheet("font-size: 22px;")
                container.layout().addWidget(select_lbl)
                container.layout().addWidget(date_edit)
                self._next_appt_widget = date_edit


                self._checkboxes["Next Appointment"] = []

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
                root.addWidget(main_scroll, 1)

                self._refresh_preview()

                add_lock_to_popup(self, show_button=False)


        # ==================================================
        # SET EXTRACTED DATA
        # ==================================================
        def set_extracted_data(self, items):
                """Display extracted data from notes with collapsible dated entry boxes."""
                # Clear existing
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
                #         self.extracted_section._toggle_collapse()

        # ==================================================
        # PREVIEW
        # ==================================================
        def _refresh_preview(self):
                print("[PREVIEW] refresh called")
                blocks = []

                # ------------------------------
                # Medication (radio actions)
                # ------------------------------
                med_sentence = self._build_medication_sentence()
                if med_sentence:
                        blocks.append(med_sentence)

                # ------------------------------
                # Psychoeducation checkboxes
                # ------------------------------
                psycho_cbs = self._checkboxes.get("Psychoeducation", [])

                if any(
                        cb.isChecked()
                        and cb.text() == "Diagnosis discussed with patient"
                        for cb in psycho_cbs
                ):
                        blocks.append(self._format_text("diagnosis"))

                if any(
                        cb.isChecked()
                        and cb.text() == "Medication / side-effects discussed"
                        for cb in psycho_cbs
                ):
                        blocks.append(self._format_text("med_side_effects"))

                # ------------------------------
                # Capacity
                # ------------------------------
                if self.capacity_status and self.capacity_domain:
                        if self.capacity_status == "has":
                                blocks.append(
                                        self._format_text(
                                                "capacity_has",
                                                domain=self.capacity_domain,
                                        )
                                )
                        else:
                                blocks.append(
                                        self._format_text(
                                                "capacity_lacks",
                                                domain=self.capacity_domain,
                                        )
                                )

                # ------------------------------
                # Psychology
                # ------------------------------
                if self.psych_status and self.psych_therapy:
                        blocks.append(
                                self._format_text(
                                        f"psych_{self.psych_status}",
                                        therapy=self.psych_therapy,
                                )
                        )

                # ------------------------------
                # Occupational Therapy (RADIO)
                # ------------------------------
                if hasattr(self, "ot_status") and self.ot_status:
                        ot_text = self.ot_status.replace("\n", " ")
                        blocks.append(f"Occupational Therapy: {ot_text}.")

                # ------------------------------
                # Care Coordination (RADIO)
                # ------------------------------
                if hasattr(self, "care_status") and self.care_status:
                        care_text = self.care_status.replace("\n", " ")
                        blocks.append(f"Care Coordination: {care_text}.")

                # ------------------------------
                # Physical Health (MASTER-GATED)
                # ------------------------------
                ph_cbs = self._checkboxes.get("Physical Health", [])

                if ph_cbs:
                        master_checked = any(
                                cb.text() == "Please can you arrange" and cb.isChecked()
                                for cb in ph_cbs
                        )

                        if master_checked:
                                details = [
                                        cb.text()
                                        for cb in ph_cbs
                                        if cb.isChecked() and cb.text() != "Please can you arrange"
                                ]

                                if details:
                                        # Bold and on separate line
                                        blocks.append(
                                                "\n**Physical health: Please can you arrange "
                                                + ", ".join(details) + ".**"
                                        )
                                else:
                                        blocks.append(
                                                "\n**Physical health: Please can you arrange appropriate investigations.**"
                                        )




                # ------------------------------
                # Next Appointment
                # ------------------------------
                if self.next_appt_date:
                        date_str = self.next_appt_date.toString("dd MMM yyyy")
                        blocks.append(
                                f"Next appointment arranged for {date_str}."
                        )
                # ------------------------------
                # Letter Signed By (with clinician details from mydetails)
                # ------------------------------
                signature_line = ""
                if hasattr(self, "signatory_group"):
                        btn = self.signatory_group.checkedButton()
                        if btn:
                                # Get clinician details from mydetails
                                clinician_name = self.mydetails.get("name", "")
                                discipline = self.mydetails.get("discipline", btn.text())
                                gmc_number = self.mydetails.get("gmc_number", "")
                                has_signature = bool(self.mydetails.get("signature_path"))

                                # Build role text
                                if btn.text() == "Registrar" and self.registrar_grade:
                                        role = f"Registrar ({self.registrar_grade})"
                                else:
                                        role = discipline if discipline else btn.text()

                                # Build signature block
                                sig_parts = ["Letter signed by:"]
                                if has_signature:
                                        sig_parts.append("[Signature]")
                                if clinician_name:
                                        sig_parts.append(clinician_name)
                                sig_parts.append(role)
                                if gmc_number:
                                        sig_parts.append(f"GMC {gmc_number}")

                                signature_line = "\n".join(sig_parts)


                # ------------------------------
                # Final render and send to card
                # ------------------------------
                main_text = " ".join(blocks)
                if signature_line:
                        full_text = f"{main_text}\n{signature_line}" if main_text else signature_line
                else:
                        full_text = main_text

                self._current_text = full_text

                # Send to card immediately
                if full_text.strip():
                        self.sent.emit(full_text.strip(), {})

        # ==================================================
        # SEND / CLOSE
        # ==================================================
        def _send(self):
                signed_by = None

                # ------------------------------
                # Letter Signed By (RADIO)
                # ------------------------------
                if hasattr(self, "signatory_group"):
                        btn = self.signatory_group.checkedButton()
                        if btn:
                                if btn.text() == "Registrar":
                                        signed_by = {
                                                "role": "Registrar",
                                                "grade": self.registrar_grade,
                                        }
                                else:
                                        signed_by = {
                                                "role": btn.text(),
                                        }

                # ------------------------------
                # Build canonical state payload
                # ------------------------------
                state = {
                        "plan": {
                                section: [
                                        cb.text()
                                        for cb in cbs
                                        if cb.isChecked()
                                ]
                                for section, cbs in self._checkboxes.items()
                        },

                        "medication_action": next(
                                (
                                        b.text()
                                        for b in self.med_group.buttons()
                                        if b.isChecked()
                                ),
                                None
                        ),

                        "capacity": {
                                "status": self.capacity_status,
                                "domain": self.capacity_domain,
                        } if self.capacity_status else None,

                        "psychology": {
                                "status": self.psych_status,
                                "therapy": self.psych_therapy,
                        } if self.psych_status else None,

                        "ot_status": getattr(self, "ot_status", None),
                        "care_status": getattr(self, "care_status", None),

                        "next_appointment": (
                                self.next_appt_date.toString("yyyy-MM-dd")
                                if self.next_appt_date else None
                        ),

                        "signed_by": signed_by,
                }


                # ------------------------------
                # Emit + close
                # ------------------------------
                self.sent.emit(self.preview.text(), state)
                self.close()


        def closeEvent(self, event):
                signed_by = None
                if hasattr(self, "signatory_group"):
                        btn = self.signatory_group.checkedButton()
                        if btn:
                                if btn.text() == "Registrar":
                                        signed_by = {
                                                "role": "Registrar",
                                                "grade": self.registrar_grade,
                                        }
                                else:
                                        signed_by = {
                                                "role": btn.text(),
                                        }

                state = {
                        "plan": {
                                section: [
                                        cb.text()
                                        for cb in cbs
                                        if cb.isChecked()
                                ]
                                for section, cbs in self._checkboxes.items()
                        },

                        "medication_action": next(
                                (
                                        b.text()
                                        for b in self.med_group.buttons()
                                        if b.isChecked()
                                ),
                                None
                        ),

                        "capacity": {
                                "status": self.capacity_status,
                                "domain": self.capacity_domain,
                        } if self.capacity_status else None,

                        "psychology": {
                                "status": self.psych_status,
                                "therapy": self.psych_therapy,
                        } if self.psych_status else None,

                        "ot_status": getattr(self, "ot_status", None),
                        "care_status": getattr(self, "care_status", None),

                        "next_appointment": (
                                self.next_appt_date.toString("yyyy-MM-dd")
                                if self.next_appt_date else None
                        ),

                        "signed_by": signed_by,
                }

                self.closed.emit(state)
                super().closeEvent(event)

        # ==================================================
        # RESTORE
        # ==================================================
        def restore_state(self, state: dict):
                if not state:
                        return

                # ------------------------------
                # Restore medication radio action
                # ------------------------------
                med_action = state.get("medication_action")
                if med_action and hasattr(self, "med_group"):
                        for b in self.med_group.buttons():
                                b.blockSignals(True)
                                b.setChecked(b.text() == med_action)
                                b.blockSignals(False)

                # ------------------------------
                # Restore checkbox-based sections
                # ------------------------------
                plan = state.get("plan", {})

                for section, items in plan.items():
                        if section not in self._checkboxes:
                                continue

                        selected = set(items or [])

                        for cb in self._checkboxes[section]:
                                cb.blockSignals(True)
                                cb.setChecked(cb.text() in selected)
                                cb.blockSignals(False)
                # ------------------------------
                # Restore capacity (DETERMINISTIC)
                # ------------------------------
                capacity = state.get("capacity")
                if capacity:
                        self.capacity_status = capacity.get("status")
                        self.capacity_domain = capacity.get("domain")

                        # Set radio buttons WITHOUT relying on handlers
                        for rb in self.capacity_group.buttons():
                                rb.blockSignals(True)
                                rb.setChecked(
                                        (self.capacity_status == "has" and rb.text() == "Has capacity")
                                        or
                                        (self.capacity_status == "lacks" and rb.text() == "Lacks capacity")
                                )
                                rb.blockSignals(False)

                        # Enable + restore domain box explicitly
                        if hasattr(self, "_capacity_domain_box"):
                                self._capacity_domain_box.setEnabled(True)
                                if self.capacity_domain:
                                        self._capacity_domain_box.setCurrentText(
                                                self.capacity_domain
                                        )


                # ------------------------------
                # Restore Psychology (DETERMINISTIC)
                # ------------------------------
                psych = state.get("psychology")
                if psych:
                        self.psych_status = psych.get("status")
                        self.psych_therapy = psych.get("therapy")

                        for rb in self.psych_group.buttons():
                                rb.blockSignals(True)
                                rb.setChecked(
                                        rb.text().lower() == self.psych_status
                                )
                                rb.blockSignals(False)

                        if hasattr(self, "_psych_therapy_box"):
                                self._psych_therapy_box.setEnabled(True)
                                if self.psych_therapy:
                                        self._psych_therapy_box.setCurrentText(
                                                self.psych_therapy
                                        )

                # ------------------------------
                # Restore Occupational Therapy (RADIO)
                # ------------------------------
                ot = state.get("ot_status")
                if ot and hasattr(self, "ot_group"):
                        self.ot_status = ot
                        for rb in self.ot_group.buttons():
                                rb.blockSignals(True)
                                rb.setChecked(rb.text() == ot)
                                rb.blockSignals(False)

                # ------------------------------
                # Restore Care Coordination (RADIO)
                # ------------------------------
                care = state.get("care_status")
                if care and hasattr(self, "care_group"):
                        self.care_status = care
                        for rb in self.care_group.buttons():
                                rb.blockSignals(True)
                                rb.setChecked(rb.text() == care)
                                rb.blockSignals(False)

                # ------------------------------
                # Restore Physical Health gate
                # ------------------------------
                if hasattr(self, "_physical_health_master") and hasattr(self, "_physical_health_gate"):
                        self._physical_health_gate(
                                self._physical_health_master.isChecked()
                        )
 


                # ------------------------------
                # Restore Next Appointment
                # ------------------------------
                date_str = state.get("next_appointment")
                if date_str and hasattr(self, "_next_appt_widget"):
                        from PySide6.QtCore import QDate
                        qd = QDate.fromString(date_str, "yyyy-MM-dd")
                        if qd.isValid():
                                self._next_appt_widget.setDate(qd)
                                self.next_appt_date = qd




                # ------------------------------
                # Restore Letter Signed By (DETERMINISTIC)
                # ------------------------------
                signed = state.get("signed_by")
                if signed:
                        role = signed.get("role")
                        grade = signed.get("grade")

                        for rb in self.signatory_group.buttons():
                                rb.blockSignals(True)
                                rb.setChecked(rb.text() == role)
                                rb.blockSignals(False)

                        if role == "Registrar" and hasattr(self, "_registrar_grade_box"):
                                self._registrar_grade_box.setEnabled(True)
                                if grade:
                                        self._registrar_grade_box.setCurrentText(grade)
                        elif hasattr(self, "_registrar_grade_box"):
                                self._registrar_grade_box.setEnabled(False)

                        self.registrar_grade = grade

                # ------------------------------
                # Defer section opening until widget is shown
                # ------------------------------
                from PySide6.QtCore import QTimer

                def _open_restored_sections():
                        plan = state.get("plan", {})

                        # Checkbox-only sections
                        if plan.get("Psychoeducation"):
                                self._open_section("Psychoeducation")

                        # Radio sections
                        if state.get("ot_status"):
                                self._open_section("Occupational Therapy")

                        if state.get("care_status"):
                                self._open_section("Care Coordination")

                        # Structured sections
                        if state.get("capacity"):
                                self._open_section("Capacity")

                        if state.get("psychology"):
                                self._open_section("Psychology")

                        if state.get("signed_by"):
                                self._open_section("Letter Signed By")

                        if state.get("next_appointment"):
                                self._open_section("Next Appointment")

                        # Gated section
                        if plan.get("Physical Health"):
                                self._open_section("Physical Health")

                QTimer.singleShot(0, _open_restored_sections)

                # ------------------------------
                # Final refresh
                # ------------------------------
                self._refresh_preview()


        # ==================================================
        # TEXT FORMATTER (PRONOUN SAFE)
        # ==================================================
        def _get_patient_name(self) -> str:
                """Get patient name with title for formal reference."""
                title = self.front_page.get("title", "")
                surname = self.front_page.get("surname", "")
                if title and surname:
                        return f"{title} {surname}"
                elif surname:
                        return surname
                return "the patient"

        def _format_text(self, key: str, **kwargs) -> str:
                p = self._pronouns()
                patient_name = self._get_patient_name()

                if key == "diagnosis":
                        return f"The diagnosis was discussed with {patient_name}."

                if key == "med_side_effects":
                        was_were = self._was_or_were()
                        return (
                                f"{p['subj'].capitalize()} {was_were} advised about medication, "
                                "specifically the purpose and effects as well as side-effects."
                        )

                if key == "capacity_has":
                        domain = kwargs.get("domain", "")
                        return (
                                "Capacity assessment (understands information, retains it, "
                                "weighs up pros and cons, and can communicate wishes) was "
                                f"carried out for {domain} and {p['subj']} {p['be']} noted to "
                                f"have capacity."
                        )

                if key == "capacity_lacks":
                        domain = kwargs.get("domain", "")
                        return (
                                "Capacity assessment (understands information, retains it, "
                                "weighs up pros and cons, and can communicate wishes) was "
                                f"carried out for {domain} and {p['subj']} {p['be']} noted to "
                                f"lack capacity."
                        )


                if key == "psych_continue":
                        therapy = kwargs.get("therapy", "")
                        return (
                                f"We discussed psychology and {p['subj']} "
                                f"will continue {therapy} therapy."
                        )

                if key == "psych_start":
                        therapy = kwargs.get("therapy", "")
                        return (
                                f"We discussed psychology and {p['subj']} "
                                f"will start {therapy} therapy."
                        )

                if key == "psych_refused":
                        therapy = kwargs.get("therapy", "")
                        return (
                                f"We discussed psychology and {p['subj']} "
                                f"refused {therapy} therapy."
                        )



                return ""


        # ==================================================
        # COLLAPSIBLE
        # ==================================================
        def _collapsible_section(self, title: str):
                header = QWidget()
                h = QHBoxLayout(header)
                h.setContentsMargins(0, 10, 0, 6)
                h.setSpacing(8)

                arrow = QLabel("▸")
                arrow.setFixedWidth(22)
                arrow.setAlignment(Qt.AlignCenter)
                arrow.setStyleSheet(
                        "font-size:21px;font-weight:700;color:#6E6E6E;"
                )

                lbl = QLabel(title)
                lbl.setStyleSheet(
                        "font-size:21px;font-weight:600;color:#6E6E6E;"
                )

                h.addWidget(arrow)
                h.addWidget(lbl)
                h.addStretch()

                container = QWidget()
                container.setVisible(False)

                v = QVBoxLayout(container)
                v.setContentsMargins(22, 6, 0, 10)
                v.setSpacing(6)

                def toggle():
                        visible = not container.isVisible()
                        container.setVisible(visible)
                        arrow.setText("▾" if visible else "▸")

                # ✅ THIS IS ALL YOU NEED
                header.mousePressEvent = lambda e: toggle()

                self.form.addWidget(header)
                self.form.addWidget(container)

                # 🔑 store by title for restore
                if not hasattr(self, "_section_containers"):
                        self._section_containers = {}
                self._section_containers[title] = (container, arrow)

                return container, arrow



        def _on_checked_factory(self, section, container, arrow):
                def handler(_):
                        any_checked = any(
                                cb.isChecked()
                                for cb in self._checkboxes[section]
                        )
                        container.setVisible(any_checked)
                        arrow.setText("▾" if any_checked else "▸")
                return handler
        # ==================================================
        # HELPERS 
        # ==================================================
        def _build_medication_sentence(self) -> str:
                if not self._med_action:
                        return ""

                verb_map = {
                        "start": "starting",
                        "stop": "stopping",
                        "increase": "increasing",
                        "decrease": "decreasing",
                }

                verb = verb_map.get(self._med_action)
                if not verb:
                        return ""

                # Handle START with new medication entry
                if self._med_action == "start" and hasattr(self, '_start_med_name'):
                        med_name = self._start_med_name.currentText().strip()
                        if med_name:
                                # Format medication name: first letter capital, rest lowercase
                                med_name_formatted = med_name.capitalize()
                                dose = self._start_med_dose.currentText().strip()
                                freq = self._start_med_freq.currentText().strip()
                                med_str = med_name_formatted
                                if dose:
                                        med_str += f" {dose}"
                                if freq:
                                        med_str += f" {freq}"
                                return f"**I recommend starting {med_str} - please can you prescribe.**"
                        return ""

                # Handle other actions with existing meds
                if not self.current_meds:
                        return ""

                meds = ", ".join(self.current_meds)
                return f"I recommend {verb} {meds}."

            
        def _set_med_action(self, action: str):
                self._med_action = action
                # Show/hide start medication entry based on action
                if hasattr(self, '_start_med_container'):
                        self._start_med_container.setVisible(action == "start")
                self._refresh_preview()

        def _on_start_med_change(self, med_name: str):
                """Handle medication name change - update dose options and BNF."""
                if not med_name or med_name not in self._medications_db:
                        self._start_med_dose.clear()
                        self._start_med_bnf.setText("")
                        self._refresh_preview()
                        return

                info = self._medications_db[med_name]
                # Use allowed_strengths (list of numbers) not strengths (display string)
                allowed_strengths = info.get("allowed_strengths", [])

                self._start_med_dose.clear()
                if allowed_strengths:
                        self._start_med_dose.addItems([f"{s}mg" for s in allowed_strengths])
                else:
                        # Fallback: parse the strengths string if allowed_strengths is empty
                        strengths_str = info.get("strengths", "")
                        if strengths_str and strengths_str not in ("n/a", "varies"):
                                self._start_med_dose.addItem(strengths_str)

                bnf_max = info.get("bnf_max", "")
                if bnf_max:
                        self._start_med_bnf.setText(f"Max BNF: {bnf_max}")
                else:
                        self._start_med_bnf.setText("")

                self._refresh_preview()

        def _was_or_were(self):
                return "were" if self._pronouns()["subj"] == "they" else "was"

        def _open_section(self, title: str):
                if not hasattr(self, "_section_containers"):
                        return
                pair = self._section_containers.get(title)
                if not pair:
                        return

                container, arrow = pair
                container.setVisible(True)
                arrow.setText("▾")

        # ==================================================
        # MEDICATION AVAILABILITY (DYNAMIC)
        # ==================================================
        def update_current_meds(self, meds):
                self.current_meds = list(meds or [])

                has_meds = bool(self.current_meds)

                # Start is always enabled; Stop/Increase/Decrease need current meds
                for action, rb in self._med_radios.items():
                        if action == "start":
                                rb.setEnabled(True)
                        else:
                                rb.setEnabled(has_meds)

                # If meds were removed and a non-start action was selected, clear selection
                if not has_meds and self._med_action in ("stop", "increase", "decrease"):
                        for b in self.med_group.buttons():
                                b.setChecked(False)
                        self._med_action = None

                self._refresh_preview()


        # ==================================================
        # PRONOUN ENGINE
        # ==================================================
        def _pronouns(self):
                # Try self.gender first, then check front_page
                gender = self.gender
                if not gender:
                        gender = self.front_page.get("gender_noun") or self.front_page.get("gender")
                return pronouns_from_gender(gender)

        # ==================================================
        # CALENDAR STYLING
        # ==================================================
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
                                font-weight: bold;
                                font-size: 22px;
                                padding: 4px;
                        }
                        QCalendarWidget QToolButton:hover {
                                background: rgba(255,255,255,0.2);
                                border-radius: 4px;
                        }
                        QCalendarWidget QMenu {
                                background: white;
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
                                alternate-background-color: #f5f5f5;
                        }
                        QCalendarWidget QTableView::item:hover {
                                background: #e0f2f1;
                        }
                        QCalendarWidget QHeaderView::section {
                                background: #f0f0f0;
                                color: #333;
                                font-weight: bold;
                                padding: 4px;
                        }
                """)

