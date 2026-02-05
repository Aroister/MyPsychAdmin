# ================================================================
#  TRIBUNAL REPORT POPUPS
# ================================================================

from PySide6.QtCore import Qt, Signal, QDate, QUrl
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit,
    QDateEdit, QPushButton, QScrollArea, QFrame, QTextEdit, QTextBrowser, QSlider,
    QTableWidget, QHeaderView, QCheckBox, QSizePolicy, QGridLayout, QComboBox
)
from shared_widgets import add_lock_to_popup


# ================================================================
# NO-WHEEL SLIDER (prevents scroll from changing value)
# ================================================================
class NoWheelSlider(QSlider):
    def wheelEvent(self, event):
        event.ignore()


# ================================================================
# RESIZABLE TEXT EDIT (with drag handle at bottom)
# ================================================================
class ResizableTextEdit(QWidget):
    """QTextEdit with a drag handle at the bottom for resizing."""

    textChanged = Signal()

    def __init__(self, placeholder: str = "", min_height: int = 60, parent=None):
        super().__init__(parent)
        self._min_height = min_height
        self._current_height = min_height

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        # The text edit
        self.text_edit = QTextEdit()
        self.text_edit.setPlaceholderText(placeholder)
        self.text_edit.setMinimumHeight(min_height)
        self.text_edit.setMaximumHeight(min_height)
        self.text_edit.textChanged.connect(self.textChanged.emit)
        layout.addWidget(self.text_edit)

        # Drag handle
        self.handle = QFrame()
        self.handle.setFixedHeight(8)
        self.handle.setCursor(Qt.CursorShape.SizeVerCursor)
        self.handle.setStyleSheet("""
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 #e0e0e0, stop:0.5 #d0d0d0, stop:1 #c0c0c0);
                border-radius: 3px;
                margin: 2px 40% 2px 40%;
            }
        """)
        layout.addWidget(self.handle)

        self._dragging = False
        self._drag_start_y = 0
        self._drag_start_height = 0

        self.handle.mousePressEvent = self._handle_press
        self.handle.mouseMoveEvent = self._handle_move
        self.handle.mouseReleaseEvent = self._handle_release

    def _handle_press(self, event):
        self._dragging = True
        self._drag_start_y = event.globalPosition().y()
        self._drag_start_height = self._current_height

    def _handle_move(self, event):
        if self._dragging:
            delta = event.globalPosition().y() - self._drag_start_y
            new_height = max(self._min_height, int(self._drag_start_height + delta))
            self._current_height = new_height
            self.text_edit.setMinimumHeight(new_height)
            self.text_edit.setMaximumHeight(new_height)

    def _handle_release(self, event):
        self._dragging = False

    def toPlainText(self) -> str:
        return self.text_edit.toPlainText()

    def setPlainText(self, text: str):
        self.text_edit.setPlainText(text)

    def clear(self):
        self.text_edit.clear()


# ================================================================
# BASE TRIBUNAL POPUP
# ================================================================

class TribunalPopupBase(QWidget):
    """Base class for tribunal report popups."""

    sent = Signal(str)  # Emits generated text

    def __init__(self, title: str, parent=None):
        super().__init__(parent)
        self.title = title

        self.setWindowFlags(Qt.WindowType.Widget)
        self.setAttribute(Qt.WidgetAttribute.WA_StyledBackground, True)

        # Outer layout
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        outer.addWidget(scroll)

        # Container
        self.container = QWidget()
        self.container.setObjectName("tribunal_popup")
        self.container.setStyleSheet("""
            QWidget#tribunal_popup {
                background: rgba(255,255,255,0.95);
                border-radius: 12px;
                border: 1px solid rgba(0,0,0,0.1);
            }
            QLabel {
                font-size: 22px;
                font-weight: 600;
                color: #374151;
                background: transparent;
                border: none;
            }
            QRadioButton {
                background: transparent;
                border: none;
                font-size: 22px;
            }
            QLineEdit, QDateEdit, QTextEdit {
                background: white;
                border: 1px solid #d1d5db;
                border-radius: 6px;
                padding: 8px;
                font-size: 22px;
            }
            QLineEdit:focus, QDateEdit:focus, QTextEdit:focus {
                border-color: #8b5cf6;
            }
            /* Calendar popup styling */
            QCalendarWidget {
                background: white;
            }
            QCalendarWidget QWidget {
                background: white;
                color: #374151;
            }
            QCalendarWidget QToolButton {
                background: white;
                color: #374151;
                border: none;
                padding: 4px;
                border-radius: 4px;
            }
            QCalendarWidget QToolButton:hover {
                background: #f3f4f6;
            }
            QCalendarWidget QMenu {
                background: white;
                color: #374151;
            }
            QCalendarWidget QSpinBox {
                background: white;
                color: #374151;
                border: 1px solid #d1d5db;
                border-radius: 4px;
            }
            QCalendarWidget QAbstractItemView {
                background: white;
                color: #374151;
                selection-background-color: #8b5cf6;
                selection-color: white;
            }
            QCalendarWidget QAbstractItemView:enabled {
                color: #374151;
            }
            QCalendarWidget QAbstractItemView:disabled {
                color: #9ca3af;
            }
        """)

        self.layout = QVBoxLayout(self.container)
        self.layout.setContentsMargins(16, 16, 16, 16)
        self.layout.setSpacing(12)
        # Alias for imported data section insertion
        self.main_layout = self.layout

        # Add title header at top
        title_label = QLabel(self.title)
        title_label.setStyleSheet("""
            font-size: 20px;
            font-weight: 700;
            color: #1f2937;
            padding-bottom: 8px;
            border-bottom: 2px solid #8b5cf6;
            margin-bottom: 8px;
        """)
        self.layout.addWidget(title_label)

        scroll.setWidget(self.container)

        # Add lock functionality (button hidden - controlled by header)
        add_lock_to_popup(self, show_button=False)

    def _add_send_button(self):
        """Add the send to report button."""
        btn = QPushButton("Send to Report")
        btn.setCursor(Qt.CursorShape.PointingHandCursor)
        btn.setStyleSheet("""
            QPushButton {
                background: #f59e0b;
                color: white;
                border: none;
                padding: 10px 20px;
                border-radius: 8px;
                font-size: 18px;
                font-weight: 600;
            }
            QPushButton:hover {
                background: #d97706;
            }
        """)
        btn.clicked.connect(self._send_to_card)
        self.layout.addWidget(btn)

    def _send_to_card(self):
        """Generate text and emit signal."""
        text = self.generate_text()
        self.sent.emit(text)

    def generate_text(self) -> str:
        """Override in subclasses to generate the text output."""
        return ""

    def _style_calendar(self, date_edit):
        """Apply clean styling to QDateEdit calendar popup."""
        calendar = date_edit.calendarWidget()
        calendar.setStyleSheet("""
            QCalendarWidget {
                background: white;
            }
            QCalendarWidget QWidget#qt_calendar_navigationbar {
                background: #8b5cf6;
            }
            QCalendarWidget QToolButton {
                color: white;
                background: transparent;
                font-weight: bold;
                font-size: 18px;
                padding: 4px;
            }
            QCalendarWidget QToolButton:hover {
                background: rgba(255,255,255,0.2);
                border-radius: 4px;
            }
            QCalendarWidget QMenu {
                background: white;
                color: #374151;
            }
            QCalendarWidget QSpinBox {
                background: white;
                color: #374151;
                selection-background-color: #8b5cf6;
            }
            QCalendarWidget QTableView {
                background: white;
                selection-background-color: #8b5cf6;
                selection-color: white;
                alternate-background-color: #f5f5f5;
            }
            QCalendarWidget QTableView::item:hover {
                background: #ede9fe;
            }
            QCalendarWidget QHeaderView::section {
                background: #f3f4f6;
                color: #374151;
                font-weight: bold;
                padding: 4px;
            }
            QCalendarWidget #qt_calendar_prevmonth,
            QCalendarWidget #qt_calendar_nextmonth {
                qproperty-icon: none;
                color: white;
                font-size: 20px;
                font-weight: bold;
            }
        """)


# ================================================================
# AUTHOR POPUP
# ================================================================

class AuthorPopup(TribunalPopupBase):
    """Popup for Author section."""

    def __init__(self, parent=None, my_details=None):
        super().__init__("Author", parent)
        self.my_details = my_details or {}
        self._setup_ui()
        self._prefill_from_mydetails()

    def _prefill_from_mydetails(self):
        """Pre-fill fields from MyDetails data."""
        if not self.my_details:
            return

        # Pre-fill name
        if self.my_details.get("full_name"):
            self.name_field.setText(self.my_details["full_name"])

        # Pre-fill role
        if self.my_details.get("role_title"):
            self.role_field.setText(self.my_details["role_title"])

    def _setup_ui(self):
        # Your Name
        name_lbl = QLabel("Your Name")
        self.name_field = QLineEdit()
        self.name_field.setPlaceholderText("Enter your full name")
        self.name_field.textChanged.connect(self._send_to_card)
        self.layout.addWidget(name_lbl)
        self.layout.addWidget(self.name_field)

        # Your Role
        role_lbl = QLabel("Your Role")
        self.role_field = QLineEdit()
        self.role_field.setPlaceholderText("e.g. Consultant Psychiatrist, Responsible Clinician")
        self.role_field.textChanged.connect(self._send_to_card)
        self.layout.addWidget(role_lbl)
        self.layout.addWidget(self.role_field)

        # Date
        date_lbl = QLabel("Date")
        self.date_field = QDateEdit()
        self.date_field.setDisplayFormat("dd/MM/yyyy")
        self.date_field.setCalendarPopup(True)
        self.date_field.setDate(QDate.currentDate())
        self.date_field.dateChanged.connect(self._send_to_card)
        self._style_calendar(self.date_field)
        self.layout.addWidget(date_lbl)
        self.layout.addWidget(self.date_field)

        self.layout.addStretch()

    def generate_text(self) -> str:
        name = self.name_field.text().strip()
        role = self.role_field.text().strip()
        date = self.date_field.date().toString("dd MMMM yyyy")

        lines = []
        if name:
            lines.append(f"Name of Responsible Clinician: {name}")
        if role:
            lines.append(f"Role: {role}")
        if date:
            lines.append(f"Date: {date}")

        return "\n".join(lines)

    def get_state(self) -> dict:
        return {
            "name": self.name_field.text(),
            "role": self.role_field.text(),
            "date": self.date_field.date().toString("yyyy-MM-dd"),
        }

    def restore_state(self, state: dict):
        if state.get("name"):
            self.name_field.setText(state["name"])
        if state.get("role"):
            self.role_field.setText(state["role"])
        if state.get("date"):
            self.date_field.setDate(QDate.fromString(state["date"], "yyyy-MM-dd"))


# ================================================================
# YES/NO WITH DETAILS POPUP (Reusable)
# ================================================================

class YesNoDetailsPopup(TribunalPopupBase):
    """Popup with Yes/No selection and details box for Yes."""

    def __init__(self, title: str, question: str, parent=None):
        super().__init__(title, parent)
        self.question = question
        self._setup_ui()

    def _setup_ui(self):
        from PySide6.QtWidgets import QRadioButton, QButtonGroup

        # Question label
        q_lbl = QLabel(self.question)
        q_lbl.setWordWrap(True)
        q_lbl.setStyleSheet("font-size: 18px; font-weight: 600; color: #374151;")
        self.layout.addWidget(q_lbl)

        # Radio buttons
        radio_layout = QHBoxLayout()
        self.btn_group = QButtonGroup(self)

        self.no_btn = QRadioButton("No")
        self.yes_btn = QRadioButton("Yes")
        self.no_btn.setChecked(True)

        self.btn_group.addButton(self.no_btn, 0)
        self.btn_group.addButton(self.yes_btn, 1)

        radio_layout.addWidget(self.no_btn)
        radio_layout.addWidget(self.yes_btn)
        radio_layout.addStretch()
        self.layout.addLayout(radio_layout)

        # Details section (hidden by default)
        self.details_container = QWidget()
        details_layout = QVBoxLayout(self.details_container)
        details_layout.setContentsMargins(0, 8, 0, 0)

        details_lbl = QLabel("Details")
        self.details_field = QTextEdit()
        self.details_field.setPlaceholderText("Please provide details...")
        self.details_field.setMinimumHeight(100)

        details_layout.addWidget(details_lbl)
        details_layout.addWidget(self.details_field)

        self.details_container.hide()
        self.layout.addWidget(self.details_container)

        # Connect radio buttons
        self.yes_btn.toggled.connect(self._on_yes_toggled)

        self.layout.addStretch()

    def _on_yes_toggled(self, checked: bool):
        if checked:
            self.details_container.show()
        else:
            self.details_container.hide()

    def generate_text(self) -> str:
        if self.no_btn.isChecked():
            return "No"
        else:
            details = self.details_field.toPlainText().strip()
            if details:
                return f"Yes - {details}"
            return "Yes"

    def get_state(self) -> dict:
        return {
            "answer": "yes" if self.yes_btn.isChecked() else "no",
            "details": self.details_field.toPlainText(),
        }

    def restore_state(self, state: dict):
        if state.get("answer") == "yes":
            self.yes_btn.setChecked(True)
        else:
            self.no_btn.setChecked(True)
        if state.get("details"):
            self.details_field.setPlainText(state["details"])


# ================================================================
# FACTORS AFFECTING HEARING POPUP
# ================================================================

class FactorsHearingPopup(TribunalPopupBase):
    """Popup for factors affecting patient's ability to cope with hearing."""

    def __init__(self, parent=None, gender=None):
        super().__init__("Factors Affecting Hearing", parent)
        self.gender = gender or "neutral"
        self._setup_ui()

    def _get_pronouns(self):
        g = (self.gender or "").lower().strip()
        if g == "male":
            return {"subj": "He", "obj": "him", "pos": "his", "suffers": "suffers", "is": "is", "has": "has", "can": "can"}
        elif g == "female":
            return {"subj": "She", "obj": "her", "pos": "her", "suffers": "suffers", "is": "is", "has": "has", "can": "can"}
        return {"subj": "They", "obj": "them", "pos": "their", "suffers": "suffer", "is": "are", "has": "have", "can": "can"}

    def set_gender(self, gender: str):
        self.gender = gender

    def update_gender(self, gender: str):
        """Update gender and refresh card."""
        self.gender = gender
        self._send_to_card()

    def _setup_ui(self):
        from PySide6.QtWidgets import QRadioButton, QButtonGroup, QCheckBox

        # Question label
        q_lbl = QLabel("Are there any factors that may affect the patient's understanding or ability to cope with a hearing?")
        q_lbl.setWordWrap(True)
        q_lbl.setStyleSheet("font-size: 18px; font-weight: 600; color: #374151;")
        self.layout.addWidget(q_lbl)

        # Yes/No radio buttons
        radio_layout = QHBoxLayout()
        self.btn_group = QButtonGroup(self)

        self.no_btn = QRadioButton("No")
        self.yes_btn = QRadioButton("Yes")
        self.no_btn.setChecked(True)

        self.btn_group.addButton(self.no_btn, 0)
        self.btn_group.addButton(self.yes_btn, 1)

        radio_layout.addWidget(self.no_btn)
        radio_layout.addWidget(self.yes_btn)
        radio_layout.addStretch()
        self.layout.addLayout(radio_layout)

        # Factors section (hidden by default)
        self.factors_container = QWidget()
        factors_layout = QVBoxLayout(self.factors_container)
        factors_layout.setContentsMargins(0, 8, 0, 0)
        factors_layout.setSpacing(8)

        factors_lbl = QLabel("Select factor:")
        factors_lbl.setStyleSheet("font-size: 17px; font-weight: 600; color: #6b7280;")
        factors_layout.addWidget(factors_lbl)

        # Radio buttons for factors (only one can be selected)
        self.factors_btn_group = QButtonGroup(self)

        self.autism_rb = QRadioButton("Autism")
        self.ld_rb = QRadioButton("Learning Disability")
        self.patience_rb = QRadioButton("Low frustration tolerance / Irritability")

        self.factors_btn_group.addButton(self.autism_rb, 0)
        self.factors_btn_group.addButton(self.ld_rb, 1)
        self.factors_btn_group.addButton(self.patience_rb, 2)

        factors_layout.addWidget(self.autism_rb)
        factors_layout.addWidget(self.ld_rb)
        factors_layout.addWidget(self.patience_rb)

        # Additional details - resizable text box
        details_lbl = QLabel("Additional details (optional)")
        details_lbl.setStyleSheet("font-size: 17px; color: #6b7280;")
        factors_layout.addWidget(details_lbl)

        self.details_field = ResizableTextEdit("Any other factors...", min_height=60)
        factors_layout.addWidget(self.details_field)

        self.factors_container.hide()
        self.layout.addWidget(self.factors_container)

        # Additional details outside the factors container - always visible
        self.always_visible_details = QWidget()
        avd_layout = QVBoxLayout(self.always_visible_details)
        avd_layout.setContentsMargins(0, 12, 0, 0)
        avd_layout.setSpacing(4)

        avd_lbl = QLabel("Additional details (optional)")
        avd_lbl.setStyleSheet("font-size: 17px; font-weight: 600; color: #6b7280;")
        avd_layout.addWidget(avd_lbl)

        self.additional_details_field = ResizableTextEdit("Enter any additional details here...", min_height=80)
        avd_layout.addWidget(self.additional_details_field)

        self.layout.addWidget(self.always_visible_details)

        # Connect signals - send to card immediately on click
        self.yes_btn.toggled.connect(self._on_yes_toggled)
        self.no_btn.toggled.connect(self._send_to_card)
        self.autism_rb.toggled.connect(self._send_to_card)
        self.ld_rb.toggled.connect(self._send_to_card)
        self.patience_rb.toggled.connect(self._send_to_card)
        self.details_field.textChanged.connect(self._send_to_card)
        self.additional_details_field.textChanged.connect(self._send_to_card)

        self.layout.addStretch()

    def _on_yes_toggled(self, checked: bool):
        if checked:
            self.factors_container.show()
        else:
            self.factors_container.hide()
        self._send_to_card()

    def generate_text(self) -> str:
        # Get the always-visible additional details
        extra_details = self.additional_details_field.toPlainText().strip() if hasattr(self, 'additional_details_field') else ""

        if self.no_btn.isChecked():
            if extra_details:
                return "No\n\n" + extra_details
            return "No"

        p = self._get_pronouns()
        text = ""

        if self.autism_rb.isChecked():
            text = f"{p['subj']} {p['suffers']} from Autism so may need more time and breaks in the hearing."

        elif self.ld_rb.isChecked():
            text = f"{p['subj']} {p['is']} diagnosed with a learning disability so may need more time and breaks in the hearing."

        elif self.patience_rb.isChecked():
            text = f"{p['subj']} can be irritable and {p['has']} low frustration tolerance so may need more time and breaks in the hearing."

        additional = self.details_field.toPlainText().strip()
        if additional:
            if text:
                text += " " + additional
            else:
                text = additional

        # Append the always-visible extra details
        if extra_details:
            if text:
                text += "\n\n" + extra_details
            else:
                text = extra_details

        if text:
            return "Yes - " + text
        return "Yes"

    def get_state(self) -> dict:
        factor = None
        if self.autism_rb.isChecked():
            factor = "autism"
        elif self.ld_rb.isChecked():
            factor = "ld"
        elif self.patience_rb.isChecked():
            factor = "patience"

        return {
            "answer": "yes" if self.yes_btn.isChecked() else "no",
            "factor": factor,
            "details": self.details_field.toPlainText(),
            "additional_details": self.additional_details_field.toPlainText() if hasattr(self, 'additional_details_field') else "",
        }

    def restore_state(self, state: dict):
        if state.get("answer") == "yes":
            self.yes_btn.setChecked(True)
        else:
            self.no_btn.setChecked(True)

        factor = state.get("factor")
        if factor == "autism":
            self.autism_rb.setChecked(True)
        elif factor == "ld":
            self.ld_rb.setChecked(True)
        elif factor == "patience":
            self.patience_rb.setChecked(True)

        if state.get("details"):
            self.details_field.setPlainText(state["details"])

        if state.get("additional_details") and hasattr(self, 'additional_details_field'):
            self.additional_details_field.setPlainText(state["additional_details"])


# ================================================================
# ADJUSTMENTS POPUP
# ================================================================

class AdjustmentsPopup(TribunalPopupBase):
    """Popup for adjustments the tribunal may consider."""

    def __init__(self, parent=None, gender=None):
        super().__init__("Adjustments", parent)
        self.gender = gender or "neutral"
        self._setup_ui()

    def _get_pronouns(self):
        g = (self.gender or "").lower().strip()
        if g == "male":
            return {"subj": "He", "obj": "him", "pos": "his", "is": "is"}
        elif g == "female":
            return {"subj": "She", "obj": "her", "pos": "her", "is": "is"}
        return {"subj": "They", "obj": "them", "pos": "their", "is": "are"}

    def set_gender(self, gender: str):
        self.gender = gender

    def update_gender(self, gender: str):
        """Update gender and refresh card."""
        self.gender = gender
        self._send_to_card()

    def _setup_ui(self):
        from PySide6.QtWidgets import QRadioButton, QButtonGroup

        # Question label
        q_lbl = QLabel("Are there any adjustments that the tribunal may consider in order to deal with the case fairly and justly?")
        q_lbl.setWordWrap(True)
        q_lbl.setStyleSheet("font-size: 18px; font-weight: 600; color: #374151;")
        self.layout.addWidget(q_lbl)

        # Yes/No radio buttons
        radio_layout = QHBoxLayout()
        self.btn_group = QButtonGroup(self)

        self.no_btn = QRadioButton("No")
        self.yes_btn = QRadioButton("Yes")
        self.no_btn.setChecked(True)

        self.btn_group.addButton(self.no_btn, 0)
        self.btn_group.addButton(self.yes_btn, 1)

        radio_layout.addWidget(self.no_btn)
        radio_layout.addWidget(self.yes_btn)
        radio_layout.addStretch()
        self.layout.addLayout(radio_layout)

        # Adjustments section (hidden by default)
        self.adjustments_container = QWidget()
        adjustments_layout = QVBoxLayout(self.adjustments_container)
        adjustments_layout.setContentsMargins(0, 8, 0, 0)
        adjustments_layout.setSpacing(8)

        adjustments_lbl = QLabel("Select adjustment:")
        adjustments_lbl.setStyleSheet("font-size: 17px; font-weight: 600; color: #6b7280;")
        adjustments_layout.addWidget(adjustments_lbl)

        # Radio buttons for adjustments
        self.adjustments_btn_group = QButtonGroup(self)

        self.explanation_rb = QRadioButton("Needs careful explanation")
        self.breaks_rb = QRadioButton("Needs breaks")
        self.more_time_rb = QRadioButton("Needs more time")

        self.adjustments_btn_group.addButton(self.explanation_rb, 0)
        self.adjustments_btn_group.addButton(self.breaks_rb, 1)
        self.adjustments_btn_group.addButton(self.more_time_rb, 2)

        adjustments_layout.addWidget(self.explanation_rb)
        adjustments_layout.addWidget(self.breaks_rb)
        adjustments_layout.addWidget(self.more_time_rb)

        # Additional details - resizable text box
        details_lbl = QLabel("Additional details (optional)")
        details_lbl.setStyleSheet("font-size: 17px; color: #6b7280;")
        adjustments_layout.addWidget(details_lbl)

        self.details_field = ResizableTextEdit("Any other adjustments...", min_height=60)
        adjustments_layout.addWidget(self.details_field)

        self.adjustments_container.hide()
        self.layout.addWidget(self.adjustments_container)

        # Additional details outside the adjustments container - always visible
        self.always_visible_details = QWidget()
        avd_layout = QVBoxLayout(self.always_visible_details)
        avd_layout.setContentsMargins(0, 12, 0, 0)
        avd_layout.setSpacing(4)

        avd_lbl = QLabel("Additional details (optional)")
        avd_lbl.setStyleSheet("font-size: 17px; font-weight: 600; color: #6b7280;")
        avd_layout.addWidget(avd_lbl)

        self.additional_details_field = ResizableTextEdit("Enter any additional details here...", min_height=80)
        avd_layout.addWidget(self.additional_details_field)

        self.layout.addWidget(self.always_visible_details)

        # Connect signals - send to card immediately on click
        self.yes_btn.toggled.connect(self._on_yes_toggled)
        self.no_btn.toggled.connect(self._send_to_card)
        self.explanation_rb.toggled.connect(self._send_to_card)
        self.breaks_rb.toggled.connect(self._send_to_card)
        self.more_time_rb.toggled.connect(self._send_to_card)
        self.details_field.textChanged.connect(self._send_to_card)
        self.additional_details_field.textChanged.connect(self._send_to_card)

        self.layout.addStretch()

    def _on_yes_toggled(self, checked: bool):
        if checked:
            self.adjustments_container.show()
        else:
            self.adjustments_container.hide()
        self._send_to_card()

    def generate_text(self) -> str:
        # Get the always-visible additional details
        extra_details = self.additional_details_field.toPlainText().strip() if hasattr(self, 'additional_details_field') else ""

        if self.no_btn.isChecked():
            if extra_details:
                return "No\n\n" + extra_details
            return "No"

        p = self._get_pronouns()
        text = ""

        if self.explanation_rb.isChecked():
            text = f"{p['subj']} {p['is']} likely to need some careful explanation around aspects of the hearing to help with {p['pos']} understanding of the process."

        elif self.breaks_rb.isChecked():
            text = f"{p['subj']} will potentially need some breaks in the hearing."

        elif self.more_time_rb.isChecked():
            text = f"{p['subj']} {p['is']} likely to need more time in the hearing to help {p['obj']} cope with the details."

        additional = self.details_field.toPlainText().strip()
        if additional:
            if text:
                text += " " + additional
            else:
                text = additional

        # Append the always-visible extra details
        if extra_details:
            if text:
                text += "\n\n" + extra_details
            else:
                text = extra_details

        if text:
            return "Yes - " + text
        return "Yes"

    def get_state(self) -> dict:
        adjustment = None
        if self.explanation_rb.isChecked():
            adjustment = "explanation"
        elif self.breaks_rb.isChecked():
            adjustment = "breaks"
        elif self.more_time_rb.isChecked():
            adjustment = "more_time"

        return {
            "answer": "yes" if self.yes_btn.isChecked() else "no",
            "adjustment": adjustment,
            "details": self.details_field.toPlainText(),
            "additional_details": self.additional_details_field.toPlainText() if hasattr(self, 'additional_details_field') else "",
        }

    def restore_state(self, state: dict):
        if state.get("answer") == "yes":
            self.yes_btn.setChecked(True)
        else:
            self.no_btn.setChecked(True)

        adjustment = state.get("adjustment")
        if adjustment == "explanation":
            self.explanation_rb.setChecked(True)
        elif adjustment == "breaks":
            self.breaks_rb.setChecked(True)
        elif adjustment == "more_time":
            self.more_time_rb.setChecked(True)

        if state.get("details"):
            self.details_field.setPlainText(state["details"])

        if state.get("additional_details") and hasattr(self, 'additional_details_field'):
            self.additional_details_field.setPlainText(state["additional_details"])

    def set_entries(self, entries: list, date_range_info: str = ""):
        """Set forensic history entries from data extractor."""
        if not entries:
            return

        # Format entries as text for the forensic data panel
        content_parts = []
        for entry in entries[:20]:  # Limit to 20 entries
            content = entry.get('content', '') or entry.get('text', '')
            date = entry.get('date', '') or entry.get('datetime', '')
            if content:
                if date:
                    content_parts.append(f"[{str(date)[:10]}] {content[:300]}")
                else:
                    content_parts.append(content[:300])

        if content_parts:
            self.forensic_data_text.setPlainText('\n\n'.join(content_parts))
            print(f"[MEDICAL] AdjustmentsPopup received {len(entries)} forensic entries")


# ================================================================
# TREATMENT POPUP (Section 12)
# ================================================================

FREQUENCY_OPTIONS = ["OD", "BD", "TDS", "QDS", "Nocte", "PRN", "Weekly", "Fortnightly", "Monthly"]

class TreatmentPopup(TribunalPopupBase):
    """Popup for Medical treatment section with collapsible sections."""

    def __init__(self, parent=None, gender=None):
        super().__init__("Medical Treatment", parent)
        self.gender = gender or "neutral"
        self._medications = []
        self._imported_data_checkboxes = []  # Track imported data checkboxes
        self._imported_data_content = ""  # Store imported content
        self._setup_ui()

    def _get_pronouns(self):
        g = (self.gender or "").lower().strip()
        if g == "male":
            return {"subj": "He", "obj": "him", "pos": "his"}
        elif g == "female":
            return {"subj": "She", "obj": "her", "pos": "her"}
        return {"subj": "They", "obj": "them", "pos": "their"}

    def set_gender(self, gender: str):
        self.gender = gender

    def _setup_ui(self):
        from PySide6.QtWidgets import QCheckBox, QComboBox, QRadioButton, QButtonGroup, QScrollArea
        from background_history_popup import CollapsibleSection

        # ========================================================
        # SCROLLABLE CONTENT
        # ========================================================
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        scroll_content = QWidget()
        scroll_content.setObjectName("treatment_scroll_content")
        scroll_content.setStyleSheet("""
            QWidget#treatment_scroll_content {
                background: rgba(255,255,255,0.95);
                border-radius: 12px;
                border: 1px solid rgba(0,0,0,0.1);
            }
            QLabel, QRadioButton, QCheckBox {
                background: transparent;
                border: none;
            }
        """)
        self.scroll_layout = QVBoxLayout(scroll_content)
        self.scroll_layout.setContentsMargins(12, 12, 12, 12)
        self.scroll_layout.setSpacing(8)
        scroll.setWidget(scroll_content)

        # ========================================================
        # COLLAPSIBLE SECTION 1: MEDICAL TREATMENT
        # ========================================================
        self.medical_section = CollapsibleSection("Medical Treatment", start_collapsed=False)
        med_content = QWidget()
        med_layout = QVBoxLayout(med_content)
        med_layout.setContentsMargins(8, 8, 8, 8)
        med_layout.setSpacing(6)

        self.med_entries_container = QWidget()
        self.med_entries_layout = QVBoxLayout(self.med_entries_container)
        self.med_entries_layout.setContentsMargins(0, 0, 0, 0)
        self.med_entries_layout.setSpacing(4)
        med_layout.addWidget(self.med_entries_container)

        self._add_medication_entry()

        add_med_btn = QPushButton("+ Add Medication")
        add_med_btn.setStyleSheet("QPushButton { background: #e5e7eb; color: #374151; border: none; padding: 6px 12px; border-radius: 4px; font-size: 17px; } QPushButton:hover { background: #d1d5db; }")
        add_med_btn.clicked.connect(self._add_medication_entry)
        med_layout.addWidget(add_med_btn)

        self.medical_section.set_content(med_content)
        self.scroll_layout.addWidget(self.medical_section)

        # ========================================================
        # COLLAPSIBLE SECTION 2: OTHER TREATMENT
        # ========================================================
        self.other_section = CollapsibleSection("Other Treatment", start_collapsed=False)
        other_content = QWidget()
        other_layout = QVBoxLayout(other_content)
        other_layout.setContentsMargins(8, 8, 8, 8)
        other_layout.setSpacing(6)

        # === NURSING ===
        self.nursing_cb = QCheckBox("Nursing")
        self.nursing_cb.setStyleSheet("font-size: 18px; font-weight: 600;")
        self.nursing_cb.toggled.connect(self._on_nursing_toggled)
        other_layout.addWidget(self.nursing_cb)

        self.nursing_dropdown = QComboBox()
        self.nursing_dropdown.addItems(["Select...", "inpatient", "community"])
        self.nursing_dropdown.setStyleSheet("""
            QComboBox {
                padding: 6px;
                font-size: 17px;
                background: white;
                border: 1px solid #d1d5db;
                border-radius: 6px;
            }
            QComboBox QAbstractItemView {
                min-width: 400px;
            }
        """)
        self.nursing_dropdown.currentIndexChanged.connect(self._send_to_card)
        self.nursing_dropdown.hide()
        other_layout.addWidget(self.nursing_dropdown)

        # === PSYCHOLOGY ===
        self.psychology_cb = QCheckBox("Psychology")
        self.psychology_cb.setStyleSheet("font-size: 18px; font-weight: 600;")
        self.psychology_cb.toggled.connect(self._on_psychology_toggled)
        other_layout.addWidget(self.psychology_cb)

        self.psychology_container = QWidget()
        psych_layout = QVBoxLayout(self.psychology_container)
        psych_layout.setContentsMargins(16, 4, 0, 0)
        psych_layout.setSpacing(4)

        self.psych_btn_group = QButtonGroup(self)
        self.psych_continue_rb = QRadioButton("Continue")
        self.psych_start_rb = QRadioButton("Start")
        self.psych_refused_rb = QRadioButton("Refused")

        self.psych_btn_group.addButton(self.psych_continue_rb, 0)
        self.psych_btn_group.addButton(self.psych_start_rb, 1)
        self.psych_btn_group.addButton(self.psych_refused_rb, 2)

        for rb in [self.psych_continue_rb, self.psych_start_rb, self.psych_refused_rb]:
            rb.toggled.connect(self._send_to_card)
            psych_layout.addWidget(rb)

        self.psych_therapy_dropdown = QComboBox()
        self.psych_therapy_dropdown.addItems(["CBT", "Trauma-focussed", "DBT", "Psychodynamic", "Supportive"])
        self.psych_therapy_dropdown.setStyleSheet("""
            QComboBox {
                padding: 6px;
                font-size: 17px;
                background: white;
                border: 1px solid #d1d5db;
                border-radius: 6px;
            }
            QComboBox QAbstractItemView {
                min-width: 400px;
            }
        """)
        self.psych_therapy_dropdown.currentIndexChanged.connect(self._send_to_card)
        psych_layout.addWidget(self.psych_therapy_dropdown)

        self.psychology_container.hide()
        other_layout.addWidget(self.psychology_container)

        # === OT ===
        self.ot_cb = QCheckBox("OT")
        self.ot_cb.setStyleSheet("font-size: 18px; font-weight: 600;")
        self.ot_cb.toggled.connect(self._on_ot_toggled)
        other_layout.addWidget(self.ot_cb)

        self.ot_field = QTextEdit()
        self.ot_field.setPlaceholderText("OT input details...")
        self.ot_field.setMaximumHeight(60)
        self.ot_field.textChanged.connect(self._send_to_card)
        self.ot_field.hide()
        other_layout.addWidget(self.ot_field)

        # === SOCIAL WORK ===
        self.social_cb = QCheckBox("Social Work")
        self.social_cb.setStyleSheet("font-size: 18px; font-weight: 600;")
        self.social_cb.toggled.connect(self._on_social_toggled)
        other_layout.addWidget(self.social_cb)

        self.social_dropdown = QComboBox()
        self.social_dropdown.addItems(["Select...", "inpatient", "community"])
        self.social_dropdown.setStyleSheet("""
            QComboBox {
                padding: 6px;
                font-size: 17px;
                background: white;
                border: 1px solid #d1d5db;
                border-radius: 6px;
            }
            QComboBox QAbstractItemView {
                min-width: 400px;
            }
        """)
        self.social_dropdown.currentIndexChanged.connect(self._send_to_card)
        self.social_dropdown.hide()
        other_layout.addWidget(self.social_dropdown)

        # === CARE PATHWAY ===
        self.pathway_cb = QCheckBox("Care Pathway")
        self.pathway_cb.setStyleSheet("font-size: 18px; font-weight: 600;")
        self.pathway_cb.toggled.connect(self._on_pathway_toggled)
        other_layout.addWidget(self.pathway_cb)

        self.pathway_dropdown = QComboBox()
        self.pathway_dropdown.addItems([
            "Select...",
            "inpatient - less restrictive",
            "inpatient - discharge",
            "outpatient - stepdown",
            "outpatient - independent"
        ])
        self.pathway_dropdown.setStyleSheet("""
            QComboBox {
                padding: 6px;
                font-size: 17px;
                background: white;
                border: 1px solid #d1d5db;
                border-radius: 6px;
            }
            QComboBox QAbstractItemView {
                min-width: 400px;
            }
        """)
        self.pathway_dropdown.currentIndexChanged.connect(self._send_to_card)
        self.pathway_dropdown.hide()
        other_layout.addWidget(self.pathway_dropdown)

        self.other_section.set_content(other_content)
        self.scroll_layout.addWidget(self.other_section)

        # ========================================================
        # COLLAPSIBLE SECTION 3: IMPORTED DATA (yellow/amber theme)
        # ========================================================
        self.imported_section = CollapsibleSection("Imported Data", start_collapsed=True)
        self.imported_section.set_header_style("""
            QFrame {
                background: rgba(180, 150, 50, 0.25);
                border: 1px solid rgba(180, 150, 50, 0.5);
                border-radius: 6px 6px 0 0;
            }
        """)
        self.imported_section.title_label.setStyleSheet("""
            QLabel {
                font-size: 13px;
                font-weight: 600;
                color: #806000;
                background: transparent;
                border: none;
            }
        """)

        self.imported_content = QWidget()
        self.imported_content.setStyleSheet("""
            QWidget {
                background: rgba(255, 248, 220, 0.95);
                border: 1px solid rgba(180, 150, 50, 0.4);
                border-top: none;
                border-radius: 0 0 12px 12px;
            }
        """)
        self.imported_layout = QVBoxLayout(self.imported_content)
        self.imported_layout.setContentsMargins(12, 10, 12, 10)
        self.imported_layout.setSpacing(6)

        # Placeholder label (will be replaced with checkboxes when data is imported)
        self.imported_placeholder = QLabel("No imported data available")
        self.imported_placeholder.setStyleSheet("font-size: 13px; color: #888; font-style: italic; background: transparent;")
        self.imported_layout.addWidget(self.imported_placeholder)

        self.imported_section.set_content(self.imported_content)
        self.imported_section.setVisible(False)  # Hidden until data is imported
        self.scroll_layout.addWidget(self.imported_section)

        self.scroll_layout.addStretch()
        self.layout.addWidget(scroll, 1)

    def set_imported_data(self, content: str, card_text: str = ""):
        """Set imported data with checkboxes. card_text is current card content for checking."""
        from PySide6.QtWidgets import QCheckBox, QHBoxLayout, QFrame

        self._imported_data_content = content
        self._imported_data_checkboxes = []

        # Clear existing content
        while self.imported_layout.count():
            item = self.imported_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        if not content or not content.strip():
            self.imported_placeholder = QLabel("No imported data available")
            self.imported_placeholder.setStyleSheet("font-size: 13px; color: #888; font-style: italic; background: transparent;")
            self.imported_layout.addWidget(self.imported_placeholder)
            self.imported_section.setVisible(False)
            return

        # Split content into paragraphs
        if '\n\n' in content:
            paragraphs = [p.strip() for p in content.split('\n\n') if p.strip()]
        else:
            paragraphs = [p.strip() for p in content.split('\n') if p.strip()]

        card_text_lower = card_text.lower() if card_text else ""

        for para in paragraphs:
            # Create container for checkbox + label
            item_container = QFrame()
            item_container.setStyleSheet("QFrame { background: transparent; border: none; }")
            item_layout = QHBoxLayout(item_container)
            item_layout.setContentsMargins(0, 4, 0, 4)
            item_layout.setSpacing(8)
            item_layout.setAlignment(Qt.AlignmentFlag.AlignTop)

            # Small checkbox (no text)
            cb = QCheckBox()
            cb.setFixedSize(20, 20)
            cb.setStyleSheet("QCheckBox::indicator { width: 16px; height: 16px; }")
            cb.setProperty("full_text", para)

            # Check if this paragraph is already in the card
            para_lower = para.lower()
            significant_words = [w for w in para_lower.split()[:6] if len(w) > 3]
            is_in_card = any(word in card_text_lower for word in significant_words) if significant_words else False
            cb.setChecked(is_in_card)

            cb.toggled.connect(self._on_imported_checkbox_toggled)
            item_layout.addWidget(cb, 0, Qt.AlignmentFlag.AlignTop)

            # Word-wrapped label for the text
            text_label = QLabel(para)
            text_label.setWordWrap(True)
            text_label.setAlignment(Qt.AlignmentFlag.AlignLeft | Qt.AlignmentFlag.AlignTop)
            text_label.setStyleSheet("font-size: 13px; color: #4a4a4a; background: transparent; padding: 0;")
            text_label.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
            item_layout.addWidget(text_label, 1)

            self._imported_data_checkboxes.append(cb)
            self.imported_layout.addWidget(item_container)

        self.imported_section.setVisible(True)
        # Expand the section to show imported data
        if hasattr(self.imported_section, '_is_collapsed') and self.imported_section._is_collapsed:
            self.imported_section._toggle_collapse()

    def _on_imported_checkbox_toggled(self, checked):
        """When an imported data checkbox is toggled, update the card."""
        if checked:
            self._send_to_card()

    def update_checkbox_states(self, card_text: str):
        """Update checkbox states based on current card content."""
        card_text_lower = card_text.lower() if card_text else ""
        for cb in self._imported_data_checkboxes:
            full_text = cb.property("full_text") or ""
            line_lower = full_text.lower()
            # Check if key parts are in the card
            is_in_card = any(word in card_text_lower for word in line_lower.split()[:5] if len(word) > 3)
            cb.blockSignals(True)
            cb.setChecked(is_in_card)
            cb.blockSignals(False)

    def _add_medication_entry(self):
        from PySide6.QtWidgets import QComboBox
        from CANONICAL_MEDS import MEDICATIONS

        entry_widget = QFrame()
        entry_widget.setStyleSheet("QFrame { background: #f3f4f6; border-radius: 6px; }")
        entry_layout = QVBoxLayout(entry_widget)
        entry_layout.setContentsMargins(8, 6, 8, 6)
        entry_layout.setSpacing(4)

        name_row = QHBoxLayout()
        name_combo = QComboBox()
        name_combo.setEditable(True)
        name_combo.addItem("")
        name_combo.addItems(sorted(MEDICATIONS.keys()))
        name_combo.setMinimumWidth(150)
        name_row.addWidget(QLabel("Med:"))
        name_row.addWidget(name_combo)
        name_row.addStretch()
        entry_layout.addLayout(name_row)

        dose_row = QHBoxLayout()
        dose_combo = QComboBox()
        dose_combo.setEditable(True)
        dose_combo.setMinimumWidth(80)
        dose_row.addWidget(QLabel("Dose:"))
        dose_row.addWidget(dose_combo)
        dose_row.addStretch()
        entry_layout.addLayout(dose_row)

        freq_row = QHBoxLayout()
        freq_combo = QComboBox()
        freq_combo.addItems(FREQUENCY_OPTIONS)
        freq_row.addWidget(QLabel("Freq:"))
        freq_row.addWidget(freq_combo)
        freq_row.addStretch()
        entry_layout.addLayout(freq_row)

        bnf_label = QLabel("")
        bnf_label.setStyleSheet("font-size: 16px; color: #666; font-style: italic;")
        entry_layout.addWidget(bnf_label)

        entry_data = {"widget": entry_widget, "name": name_combo, "dose": dose_combo, "freq": freq_combo, "bnf": bnf_label}
        self._medications.append(entry_data)

        def on_med_change(med_name):
            if med_name and med_name in MEDICATIONS:
                info = MEDICATIONS[med_name]
                allowed = info.get("allowed_strengths", [])
                dose_combo.clear()
                if allowed:
                    dose_combo.addItems([f"{s}mg" for s in allowed])
                bnf_max = info.get("bnf_max", "")
                bnf_label.setText(f"Max BNF: {bnf_max}" if bnf_max else "")
            else:
                dose_combo.clear()
                bnf_label.setText("")
            self._send_to_card()

        name_combo.currentTextChanged.connect(on_med_change)
        dose_combo.currentTextChanged.connect(self._send_to_card)
        freq_combo.currentIndexChanged.connect(self._send_to_card)

        self.med_entries_layout.addWidget(entry_widget)

    def _on_nursing_toggled(self, checked):
        self.nursing_dropdown.setVisible(checked)
        if not checked:
            self.nursing_dropdown.setCurrentIndex(0)
        self._send_to_card()

    def _on_psychology_toggled(self, checked):
        self.psychology_container.setVisible(checked)
        self._send_to_card()

    def _on_ot_toggled(self, checked):
        self.ot_field.setVisible(checked)
        if not checked:
            self.ot_field.clear()
        self._send_to_card()

    def _on_social_toggled(self, checked):
        self.social_dropdown.setVisible(checked)
        if not checked:
            self.social_dropdown.setCurrentIndex(0)
        self._send_to_card()

    def _on_pathway_toggled(self, checked):
        self.pathway_dropdown.setVisible(checked)
        if not checked:
            self.pathway_dropdown.setCurrentIndex(0)
        self._send_to_card()

    def generate_text(self) -> str:
        p = self._get_pronouns()
        parts = []

        # Medication
        med_lines = []
        for entry in self._medications:
            name = entry["name"].currentText().strip()
            dose = entry["dose"].currentText().strip()
            freq = entry["freq"].currentText().strip()
            if name:
                line = name.capitalize()
                if dose:
                    line += f" {dose}"
                if freq:
                    line += f" {freq}"
                med_lines.append(line)
        if med_lines:
            parts.append("Current medication: " + ", ".join(med_lines))

        # Nursing
        if self.nursing_cb.isChecked() and self.nursing_dropdown.currentIndex() > 0:
            nursing_type = self.nursing_dropdown.currentText()
            if nursing_type == "inpatient":
                parts.append(f"{p['subj']} will continue with ongoing nursing care and treatment.")
            elif nursing_type == "community":
                parts.append(f"{p['subj']} will have ongoing input from a community psychiatric nurse.")

        # Psychology
        if self.psychology_cb.isChecked():
            therapy = self.psych_therapy_dropdown.currentText()
            if self.psych_continue_rb.isChecked():
                parts.append(f"Psychological treatment will be to continue {therapy} therapy.")
            elif self.psych_start_rb.isChecked():
                parts.append(f"Psychological treatment will be to start {therapy} therapy.")
            elif self.psych_refused_rb.isChecked():
                parts.append(f"Psychological treatment was offered but {p['subj'].lower()} refused {therapy} therapy.")

        # OT
        if self.ot_cb.isChecked():
            ot_text = self.ot_field.toPlainText().strip()
            if ot_text:
                parts.append(f"OT: {ot_text}")

        # Social Work
        if self.social_cb.isChecked() and self.social_dropdown.currentIndex() > 0:
            social_type = self.social_dropdown.currentText()
            if social_type == "inpatient":
                parts.append(f"{p['subj']} will have social worker involved in {p['pos']} care to manage {p['pos']} social circumstances as an inpatient.")
            elif social_type == "community":
                parts.append(f"{p['subj']} will have social worker involved in {p['pos']} care to manage {p['pos']} social circumstances in the community.")

        # Care Pathway
        if self.pathway_cb.isChecked() and self.pathway_dropdown.currentIndex() > 0:
            pathway = self.pathway_dropdown.currentText()
            if pathway == "inpatient - less restrictive":
                parts.append(f"Care Pathway: {p['subj']} will be looking to move to a less restrictive level of inpatient care.")
            elif pathway == "inpatient - discharge":
                parts.append(f"Care Pathway: {p['subj']} will move on from this ward to be discharged into suitable community accommodation following a care act assessment.")
            elif pathway == "outpatient - stepdown":
                parts.append(f"Care Pathway: {p['subj']} will be stepped down into a lower level of supported accommodation when ready.")
            elif pathway == "outpatient - independent":
                parts.append(f"Care Pathway: {p['subj']} will be aiming to move to independent living in a flat of {p['pos']} own.")

        # Imported data - add checked items
        for cb in self._imported_data_checkboxes:
            if cb.isChecked():
                full_text = cb.property("full_text") or ""
                if full_text and full_text not in "\n".join(parts):
                    parts.append(full_text)

        return "\n\n".join(parts)

    def get_state(self) -> dict:
        meds = []
        for entry in self._medications:
            meds.append({
                "name": entry["name"].currentText(),
                "dose": entry["dose"].currentText(),
                "freq": entry["freq"].currentText(),
            })

        psych_status = None
        if self.psych_continue_rb.isChecked():
            psych_status = "continue"
        elif self.psych_start_rb.isChecked():
            psych_status = "start"
        elif self.psych_refused_rb.isChecked():
            psych_status = "refused"

        return {
            "medications": meds,
            "nursing": self.nursing_cb.isChecked(),
            "nursing_type": self.nursing_dropdown.currentText(),
            "psychology": self.psychology_cb.isChecked(),
            "psychology_status": psych_status,
            "psychology_therapy": self.psych_therapy_dropdown.currentText(),
            "ot": self.ot_cb.isChecked(),
            "ot_text": self.ot_field.toPlainText(),
            "social": self.social_cb.isChecked(),
            "social_type": self.social_dropdown.currentText(),
            "pathway": self.pathway_cb.isChecked(),
            "pathway_type": self.pathway_dropdown.currentText(),
        }

    def restore_state(self, state: dict):
        if not state:
            return

        meds = state.get("medications", [])
        while len(self._medications) > 1:
            entry = self._medications.pop()
            entry["widget"].deleteLater()
        for i, med in enumerate(meds):
            if i >= len(self._medications):
                self._add_medication_entry()
            entry = self._medications[i]
            entry["name"].setCurrentText(med.get("name", ""))
            entry["dose"].setCurrentText(med.get("dose", ""))
            idx = entry["freq"].findText(med.get("freq", ""))
            if idx >= 0:
                entry["freq"].setCurrentIndex(idx)

        self.nursing_cb.setChecked(state.get("nursing", False))
        idx = self.nursing_dropdown.findText(state.get("nursing_type", ""))
        if idx >= 0:
            self.nursing_dropdown.setCurrentIndex(idx)

        self.psychology_cb.setChecked(state.get("psychology", False))
        psych_status = state.get("psychology_status")
        if psych_status == "continue":
            self.psych_continue_rb.setChecked(True)
        elif psych_status == "start":
            self.psych_start_rb.setChecked(True)
        elif psych_status == "refused":
            self.psych_refused_rb.setChecked(True)
        idx = self.psych_therapy_dropdown.findText(state.get("psychology_therapy", ""))
        if idx >= 0:
            self.psych_therapy_dropdown.setCurrentIndex(idx)

        self.ot_cb.setChecked(state.get("ot", False))
        self.ot_field.setPlainText(state.get("ot_text", ""))

        self.social_cb.setChecked(state.get("social", False))
        idx = self.social_dropdown.findText(state.get("social_type", ""))
        if idx >= 0:
            self.social_dropdown.setCurrentIndex(idx)

        self.pathway_cb.setChecked(state.get("pathway", False))
        idx = self.pathway_dropdown.findText(state.get("pathway_type", ""))
        if idx >= 0:
            self.pathway_dropdown.setCurrentIndex(idx)

        self._send_to_card()


# ================================================================
# SIMPLE YES/NO POPUP (No details field)
# ================================================================

class SimpleYesNoPopup(TribunalPopupBase):
    """Popup with just Yes/No selection - sends to card on click."""

    def __init__(self, title: str, question: str, parent=None):
        super().__init__(title, parent)
        self.question = question
        self._setup_ui()

    def _setup_ui(self):
        from PySide6.QtWidgets import QRadioButton, QButtonGroup

        # Question label
        q_lbl = QLabel(self.question)
        q_lbl.setWordWrap(True)
        q_lbl.setStyleSheet("font-size: 18px; font-weight: 600; color: #374151;")
        self.layout.addWidget(q_lbl)

        # Radio buttons
        radio_layout = QHBoxLayout()
        self.btn_group = QButtonGroup(self)

        self.no_btn = QRadioButton("No")
        self.yes_btn = QRadioButton("Yes")
        self.no_btn.setChecked(True)

        self.btn_group.addButton(self.no_btn, 0)
        self.btn_group.addButton(self.yes_btn, 1)

        radio_layout.addWidget(self.no_btn)
        radio_layout.addWidget(self.yes_btn)
        radio_layout.addStretch()
        self.layout.addLayout(radio_layout)

        # Connect signals - send to card immediately on click
        self.yes_btn.toggled.connect(self._send_to_card)
        self.no_btn.toggled.connect(self._send_to_card)

        self.layout.addStretch()

    def generate_text(self) -> str:
        return "Yes" if self.yes_btn.isChecked() else "No"

    def get_state(self) -> dict:
        return {
            "answer": "yes" if self.yes_btn.isChecked() else "no",
        }

    def restore_state(self, state: dict):
        if state.get("answer") == "yes":
            self.yes_btn.setChecked(True)
        else:
            self.no_btn.setChecked(True)


# ================================================================
# LEARNING DISABILITY POPUP
# ================================================================

class LearningDisabilityPopup(TribunalPopupBase):
    """Popup for Learning disability section - sends to card on click."""

    def __init__(self, parent=None):
        super().__init__("Learning Disability", parent)
        self._setup_ui()

    def _setup_ui(self):
        from PySide6.QtWidgets import QRadioButton, QButtonGroup

        # Question 1: Does the patient have a learning disability?
        q1_lbl = QLabel("Does the patient have a learning disability?")
        q1_lbl.setWordWrap(True)
        q1_lbl.setStyleSheet("font-size: 18px; font-weight: 600; color: #374151;")
        self.layout.addWidget(q1_lbl)

        # Yes/No radio buttons for Q1
        q1_radio_layout = QHBoxLayout()
        self.q1_btn_group = QButtonGroup(self)

        self.q1_no_btn = QRadioButton("No")
        self.q1_yes_btn = QRadioButton("Yes")
        self.q1_no_btn.setChecked(True)

        self.q1_btn_group.addButton(self.q1_no_btn, 0)
        self.q1_btn_group.addButton(self.q1_yes_btn, 1)

        q1_radio_layout.addWidget(self.q1_no_btn)
        q1_radio_layout.addWidget(self.q1_yes_btn)
        q1_radio_layout.addStretch()
        self.layout.addLayout(q1_radio_layout)

        # Question 2 container (hidden by default)
        self.q2_container = QWidget()
        q2_layout = QVBoxLayout(self.q2_container)
        q2_layout.setContentsMargins(0, 12, 0, 0)
        q2_layout.setSpacing(8)

        q2_lbl = QLabel("Is that disability associated with abnormally aggressive or seriously irresponsible conduct?")
        q2_lbl.setWordWrap(True)
        q2_lbl.setStyleSheet("font-size: 18px; font-weight: 600; color: #374151;")
        q2_layout.addWidget(q2_lbl)

        # Yes/No radio buttons for Q2
        q2_radio_layout = QHBoxLayout()
        self.q2_btn_group = QButtonGroup(self)

        self.q2_no_btn = QRadioButton("No")
        self.q2_yes_btn = QRadioButton("Yes")
        self.q2_no_btn.setChecked(True)

        self.q2_btn_group.addButton(self.q2_no_btn, 0)
        self.q2_btn_group.addButton(self.q2_yes_btn, 1)

        q2_radio_layout.addWidget(self.q2_no_btn)
        q2_radio_layout.addWidget(self.q2_yes_btn)
        q2_radio_layout.addStretch()
        q2_layout.addLayout(q2_radio_layout)

        self.q2_container.hide()
        self.layout.addWidget(self.q2_container)

        # Connect signals - send to card immediately on click
        self.q1_yes_btn.toggled.connect(self._on_q1_yes_toggled)
        self.q1_no_btn.toggled.connect(self._send_to_card)
        self.q2_yes_btn.toggled.connect(self._send_to_card)
        self.q2_no_btn.toggled.connect(self._send_to_card)

        self.layout.addStretch()

    def _on_q1_yes_toggled(self, checked: bool):
        if checked:
            self.q2_container.show()
        else:
            self.q2_container.hide()
        self._send_to_card()

    def generate_text(self) -> str:
        if self.q1_no_btn.isChecked():
            return "No"

        # Q1 is Yes
        if self.q2_yes_btn.isChecked():
            return "Yes - The disability is associated with abnormally aggressive or seriously irresponsible conduct."
        else:
            return "Yes - The disability is not associated with abnormally aggressive or seriously irresponsible conduct."

    def get_state(self) -> dict:
        return {
            "has_ld": "yes" if self.q1_yes_btn.isChecked() else "no",
            "aggressive_conduct": "yes" if self.q2_yes_btn.isChecked() else "no",
        }

    def restore_state(self, state: dict):
        if state.get("has_ld") == "yes":
            self.q1_yes_btn.setChecked(True)
        else:
            self.q1_no_btn.setChecked(True)

        if state.get("aggressive_conduct") == "yes":
            self.q2_yes_btn.setChecked(True)
        else:
            self.q2_no_btn.setChecked(True)


# ================================================================
# DIAGNOSIS POPUP (Mental Disorder - ICD-10)
# ================================================================

class DiagnosisPopup(TribunalPopupBase):
    """Popup for Mental disorder and diagnosis section."""

    def __init__(self, icd10_dict: dict = None, parent=None):
        super().__init__("Mental Disorder and Diagnosis", parent)
        self.icd10_dict = icd10_dict or {}
        self._setup_ui()

    def eventFilter(self, obj, event):
        """Block wheel events on combo boxes to prevent accidental scrolling changes."""
        from PySide6.QtCore import QEvent
        from PySide6.QtWidgets import QComboBox
        if event.type() == QEvent.Type.Wheel and isinstance(obj, QComboBox):
            return True  # Block wheel event
        return super().eventFilter(obj, event)

    def _setup_ui(self):
        from PySide6.QtWidgets import QComboBox, QCompleter, QStyleFactory, QRadioButton, QButtonGroup, QScrollArea
        from background_history_popup import CollapsibleSection

        # ========================================================
        # SCROLLABLE CONTENT
        # ========================================================
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        scroll_content = QWidget()
        scroll_content.setObjectName("diagnosis_scroll_content")
        scroll_content.setStyleSheet("""
            QWidget#diagnosis_scroll_content {
                background: rgba(255,255,255,0.95);
                border-radius: 12px;
                border: 1px solid rgba(0,0,0,0.1);
            }
            QLabel, QRadioButton {
                background: transparent;
                border: none;
            }
        """)
        self.scroll_layout = QVBoxLayout(scroll_content)
        self.scroll_layout.setContentsMargins(12, 12, 12, 12)
        self.scroll_layout.setSpacing(10)
        scroll.setWidget(scroll_content)

        # ========================================================
        # COLLAPSIBLE INPUT SECTION: Mental Disorder & Diagnosis
        # ========================================================
        self.input_section = CollapsibleSection("Mental Disorder & Diagnosis", start_collapsed=False)
        self.input_section.set_content_height(280)
        self.input_section._min_height = 120
        self.input_section._max_height = 400
        self.input_section.set_header_style("""
            QFrame {
                background: rgba(147, 51, 234, 0.15);
                border: 1px solid rgba(147, 51, 234, 0.3);
                border-radius: 6px 6px 0 0;
            }
        """)
        self.input_section.title_label.setStyleSheet("""
            QLabel {
                font-size: 18px;
                font-weight: 600;
                color: #7c3aed;
                background: transparent;
                border: none;
            }
        """)

        input_content = QWidget()
        input_content.setStyleSheet("""
            QWidget {
                background: rgba(245, 243, 255, 0.95);
                border: 1px solid rgba(147, 51, 234, 0.3);
                border-top: none;
                border-radius: 0 0 12px 12px;
            }
            QLabel, QRadioButton {
                background: transparent;
                border: none;
                font-size: 22px;
            }
        """)
        input_layout = QVBoxLayout(input_content)
        input_layout.setContentsMargins(12, 12, 12, 12)
        input_layout.setSpacing(8)

        # Mental disorder question
        question_lbl = QLabel("Is the patient now suffering from a mental disorder?")
        question_lbl.setWordWrap(True)
        question_lbl.setStyleSheet("font-size: 18px; font-weight: 600; color: #374151;")
        input_layout.addWidget(question_lbl)

        # Yes/No radio buttons
        radio_layout = QHBoxLayout()
        self.mental_disorder_group = QButtonGroup(self)

        self.no_btn = QRadioButton("No")
        self.yes_btn = QRadioButton("Yes")
        self.no_btn.setStyleSheet("""
            QRadioButton {
                font-size: 22px;
                background: transparent;
            }
            QRadioButton::indicator {
                width: 18px;
                height: 18px;
            }
        """)
        self.yes_btn.setStyleSheet("""
            QRadioButton {
                font-size: 22px;
                background: transparent;
            }
            QRadioButton::indicator {
                width: 18px;
                height: 18px;
            }
        """)

        self.mental_disorder_group.addButton(self.no_btn, 0)
        self.mental_disorder_group.addButton(self.yes_btn, 1)

        radio_layout.addWidget(self.no_btn)
        radio_layout.addWidget(self.yes_btn)
        radio_layout.addStretch()
        input_layout.addLayout(radio_layout)

        # Connect to show/hide diagnosis section
        self.yes_btn.toggled.connect(self._on_yes_toggled)
        self.no_btn.toggled.connect(self._send_to_card)

        # ========================================================
        # DIAGNOSIS SECTION (shown only when Yes selected)
        # ========================================================
        self.diagnosis_container = QWidget()
        self.diagnosis_container.setStyleSheet("background: transparent; border: none;")
        diagnosis_layout = QVBoxLayout(self.diagnosis_container)
        diagnosis_layout.setContentsMargins(0, 10, 0, 0)
        diagnosis_layout.setSpacing(8)

        # Diagnosis label
        dx_lbl = QLabel("Diagnosis (ICD-10)")
        dx_lbl.setStyleSheet("font-size: 18px; font-weight: 600; color: #374151;")
        diagnosis_layout.addWidget(dx_lbl)

        # Diagnosis comboboxes (up to 3)
        self.dx_boxes = []

        for i in range(3):
            combo = QComboBox()
            combo.setStyle(QStyleFactory.create("Fusion"))
            combo.setEditable(True)
            combo.lineEdit().setReadOnly(True)
            combo.setInsertPolicy(QComboBox.InsertPolicy.NoInsert)
            combo.lineEdit().setPlaceholderText("Start typing to search...")

            combo.setSizeAdjustPolicy(QComboBox.SizeAdjustPolicy.AdjustToMinimumContentsLengthWithIcon)
            combo.setMinimumContentsLength(25)
            combo.setStyleSheet("""
                QComboBox {
                    padding: 6px;
                    font-size: 17px;
                    background: white;
                    border: 1px solid #d1d5db;
                    border-radius: 6px;
                }
                QComboBox QAbstractItemView {
                    min-width: 400px;
                }
            """)

            # Add items
            combo.addItem("Not specified", None)

            for diagnosis, meta in sorted(
                self.icd10_dict.items(),
                key=lambda x: x[0].lower()
            ):
                icd_code = meta.get("icd10") if isinstance(meta, dict) else meta
                combo.addItem(
                    diagnosis,
                    {"diagnosis": diagnosis, "icd10": icd_code}
                )

            # Autocomplete
            completer = QCompleter(combo.model(), combo)
            completer.setCaseSensitivity(Qt.CaseSensitivity.CaseInsensitive)
            completer.setFilterMode(Qt.MatchFlag.MatchContains)
            completer.setCompletionMode(QCompleter.CompletionMode.PopupCompletion)
            combo.setCompleter(completer)

            combo.setMaxVisibleItems(15)
            combo.currentIndexChanged.connect(self._send_to_card)

            # Prevent scroll wheel from changing selection
            combo.setFocusPolicy(Qt.FocusPolicy.StrongFocus)
            combo.installEventFilter(self)

            diagnosis_layout.addWidget(combo)
            self.dx_boxes.append(combo)

        self.diagnosis_container.hide()  # Hidden by default until Yes is clicked
        input_layout.addWidget(self.diagnosis_container)

        self.input_section.set_content(input_content)
        self.scroll_layout.addWidget(self.input_section)

        # Note: imported data collapsible section will be added by _add_imported_data_to_popup
        self.scroll_layout.addStretch()
        self.layout.addWidget(scroll, 1)

    def _on_yes_toggled(self, checked):
        """Show/hide diagnosis section based on Yes selection."""
        self.diagnosis_container.setVisible(checked)
        self._send_to_card()

    def generate_text(self) -> str:
        # If No is selected
        if self.no_btn.isChecked():
            return "No"

        # If Yes is selected, include diagnoses
        if not self.yes_btn.isChecked():
            return ""

        diagnoses = []
        for combo in self.dx_boxes:
            meta = combo.currentData()
            if meta and isinstance(meta, dict):
                dx = meta.get("diagnosis", "")
                icd = meta.get("icd10", "")
                if dx:
                    if icd:
                        diagnoses.append(f"{dx} ({icd})")
                    else:
                        diagnoses.append(dx)

        if not diagnoses:
            return "Yes"

        if len(diagnoses) == 1:
            return f"Yes - {diagnoses[0]} is a mental disorder as defined by the Mental Health Act."
        else:
            joined = ", ".join(diagnoses[:-1]) + f" and {diagnoses[-1]}"
            return f"Yes - {joined} are mental disorders as defined by the Mental Health Act."

    def get_state(self) -> dict:
        dx_list = []
        for combo in self.dx_boxes:
            meta = combo.currentData()
            if meta:
                dx_list.append(meta)
        return {
            "mental_disorder": "yes" if self.yes_btn.isChecked() else "no" if self.no_btn.isChecked() else None,
            "diagnoses": dx_list
        }

    def restore_state(self, state: dict):
        if not state:
            return

        # Restore Yes/No selection
        mental_disorder = state.get("mental_disorder")
        if mental_disorder == "yes":
            self.yes_btn.setChecked(True)
        elif mental_disorder == "no":
            self.no_btn.setChecked(True)

        # Reset diagnosis combos
        for combo in self.dx_boxes:
            combo.blockSignals(True)
            combo.setCurrentIndex(0)
            combo.blockSignals(False)

        # Restore diagnoses
        for combo, meta in zip(self.dx_boxes, state.get("diagnoses", [])):
            if not meta:
                continue
            index = combo.findText(meta.get("diagnosis", ""))
            if index >= 0:
                combo.blockSignals(True)
                combo.setCurrentIndex(index)
                combo.blockSignals(False)


# ================================================================
# PATIENT DETAILS POPUP
# ================================================================

class PatientDetailsPopup(TribunalPopupBase):
    """Popup for Patient Details section."""

    gender_changed = Signal(str)  # Emits when gender changes

    def __init__(self, parent=None):
        super().__init__("Patient Details", parent)
        self._setup_ui()

    def _setup_ui(self):
        from PySide6.QtWidgets import QComboBox

        # Full Name
        name_lbl = QLabel("Full Name")
        self.name_field = QLineEdit()
        self.name_field.setPlaceholderText("Enter patient's full name")
        self.name_field.textChanged.connect(self._send_to_card)
        self.layout.addWidget(name_lbl)
        self.layout.addWidget(self.name_field)

        # DOB
        dob_lbl = QLabel("Date of Birth")
        self.dob_field = QDateEdit()
        self.dob_field.setDisplayFormat("dd/MM/yyyy")
        self.dob_field.setCalendarPopup(True)
        self.dob_field.setMaximumDate(QDate.currentDate())
        self.dob_field.setMinimumDate(QDate.currentDate().addYears(-115))
        self.dob_field.dateChanged.connect(self._send_to_card)
        self._style_calendar(self.dob_field)
        self.layout.addWidget(dob_lbl)
        self.layout.addWidget(self.dob_field)

        # Gender
        gender_lbl = QLabel("Gender")
        self.gender_field = QComboBox()
        self.gender_field.addItems(["Male", "Female", "Other"])
        self.gender_field.currentTextChanged.connect(self._on_gender_changed)
        self.gender_field.currentTextChanged.connect(self._send_to_card)
        self.layout.addWidget(gender_lbl)
        self.layout.addWidget(self.gender_field)

        # Usual Place of Residence
        residence_lbl = QLabel("Usual Place of Residence")
        self.residence_field = QTextEdit()
        self.residence_field.setPlaceholderText("Enter patient's usual address")
        self.residence_field.setMaximumHeight(80)
        self.residence_field.textChanged.connect(self._send_to_card)
        self.layout.addWidget(residence_lbl)
        self.layout.addWidget(self.residence_field)

        self.layout.addStretch()

    def _send_to_card(self):
        """Send generated text to card."""
        text = self.generate_text()
        print(f"[PatientDetailsPopup] _send_to_card: text length={len(text)}")
        if text.strip():
            print(f"[PatientDetailsPopup] Emitting sent signal")
            self.sent.emit(text)
        else:
            print(f"[PatientDetailsPopup] Empty text, not emitting")

    def _on_gender_changed(self, gender: str):
        self.gender_changed.emit(gender)

    def generate_text(self) -> str:
        name = self.name_field.text().strip()
        dob = self.dob_field.date().toString("dd/MM/yyyy")
        gender = self.gender_field.currentText()
        residence = self.residence_field.toPlainText().strip()

        lines = []
        if name:
            lines.append(f"Full Name: {name}")
        if dob:
            lines.append(f"Date of Birth: {dob}")
        if gender:
            lines.append(f"Gender: {gender}")
        if residence:
            lines.append(f"Usual Place of Residence: {residence}")

        return "\n".join(lines)

    def get_gender(self) -> str:
        return self.gender_field.currentText()

    def get_state(self) -> dict:
        """Get current state for saving."""
        return {
            "name": self.name_field.text(),
            "dob": self.dob_field.date().toString("yyyy-MM-dd"),
            "gender": self.gender_field.currentText(),
            "residence": self.residence_field.toPlainText(),
        }

    def restore_state(self, state: dict):
        """Restore state from saved data."""
        if state.get("name"):
            self.name_field.setText(state["name"])
        if state.get("dob"):
            self.dob_field.setDate(QDate.fromString(state["dob"], "yyyy-MM-dd"))
        if state.get("gender"):
            idx = self.gender_field.findText(state["gender"])
            if idx >= 0:
                self.gender_field.setCurrentIndex(idx)
        if state.get("residence"):
            self.residence_field.setPlainText(state["residence"])

    def fill_patient_info(self, patient_info: dict):
        """Fill fields from extracted patient demographics - only if fields are empty."""
        from datetime import datetime

        # Fill name if empty
        if patient_info.get("name") and not self.name_field.text().strip():
            self.name_field.setText(patient_info["name"])
            print(f"[PatientDetailsPopup] Set name: {patient_info['name']}")

        # Fill DOB if at default (01/01/2000)
        if patient_info.get("dob"):
            current = self.dob_field.date()
            if current == QDate(2000, 1, 1):
                dob = patient_info["dob"]
                if isinstance(dob, datetime):
                    self.dob_field.setDate(QDate(dob.year, dob.month, dob.day))
                    print(f"[PatientDetailsPopup] Set DOB: {dob.strftime('%d/%m/%Y')}")

        # Fill gender
        if patient_info.get("gender"):
            idx = self.gender_field.findText(patient_info["gender"])
            if idx >= 0:
                self.gender_field.setCurrentIndex(idx)
                print(f"[PatientDetailsPopup] Set gender: {patient_info['gender']}")

        # Fill residence/address if empty
        if patient_info.get("address") and not self.residence_field.toPlainText().strip():
            self.residence_field.setPlainText(patient_info["address"])
            print(f"[PatientDetailsPopup] Set address: {patient_info['address']}")

        # Trigger card update
        self._send_to_card()


# ================================================================
# STRENGTHS POPUP (Section 13)
# ================================================================

class StrengthsPopup(TribunalPopupBase):
    """Popup for Strengths or positive factors section."""

    def __init__(self, parent=None, gender=None):
        super().__init__("Strengths or Positive Factors", parent)
        self.gender = gender or "neutral"
        self._setup_ui()

    def _get_pronouns(self):
        g = (self.gender or "").lower().strip()
        if g == "male":
            return {"subj": "He", "obj": "him", "pos": "His", "pos_lower": "his"}
        elif g == "female":
            return {"subj": "She", "obj": "her", "pos": "Her", "pos_lower": "her"}
        return {"subj": "They", "obj": "them", "pos": "Their", "pos_lower": "their"}

    def set_gender(self, gender: str):
        self.gender = gender
        self._send_to_card()

    def _setup_ui(self):
        from PySide6.QtWidgets import QCheckBox, QScrollArea
        from background_history_popup import CollapsibleSection

        # ========================================================
        # SCROLLABLE CONTENT
        # ========================================================
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        scroll_content = QWidget()
        scroll_content.setObjectName("strengths_scroll_content")
        scroll_content.setStyleSheet("""
            QWidget#strengths_scroll_content {
                background: rgba(255,255,255,0.95);
                border-radius: 12px;
                border: 1px solid rgba(0,0,0,0.1);
            }
            QLabel, QRadioButton, QCheckBox {
                background: transparent;
                border: none;
                font-size: 22px;
            }
        """)
        self.scroll_layout = QVBoxLayout(scroll_content)
        self.scroll_layout.setContentsMargins(12, 12, 12, 12)
        self.scroll_layout.setSpacing(8)
        scroll.setWidget(scroll_content)

        # ========================================================
        # COLLAPSIBLE SECTION: Strengths or Positive Factors
        # ========================================================
        self.input_section = CollapsibleSection("Strengths or Positive Factors", start_collapsed=False)
        self.input_section.set_content_height(350)
        self.input_section._min_height = 150
        self.input_section._max_height = 500
        self.input_section.set_header_style("""
            QFrame {
                background: rgba(34, 197, 94, 0.15);
                border: 1px solid rgba(34, 197, 94, 0.3);
                border-radius: 6px 6px 0 0;
            }
        """)
        self.input_section.title_label.setStyleSheet("""
            QLabel {
                font-size: 18px;
                font-weight: 600;
                color: #166534;
                background: transparent;
                border: none;
            }
        """)

        input_content = QWidget()
        input_content.setStyleSheet("""
            QWidget {
                background: rgba(220, 252, 231, 0.95);
                border: 1px solid rgba(34, 197, 94, 0.3);
                border-top: none;
                border-radius: 0 0 12px 12px;
            }
            QLabel, QCheckBox {
                background: transparent;
                border: none;
                font-size: 22px;
            }
        """)
        input_layout = QVBoxLayout(input_content)
        input_layout.setContentsMargins(12, 12, 12, 12)
        input_layout.setSpacing(8)

        # === ENGAGEMENT SECTION ===
        engagement_lbl = QLabel("Engagement")
        engagement_lbl.setStyleSheet("font-size: 18px; font-weight: 600; color: #374151;")
        input_layout.addWidget(engagement_lbl)

        self.staff_cb = QCheckBox("Staff")
        self.staff_cb.toggled.connect(self._send_to_card)
        input_layout.addWidget(self.staff_cb)

        self.peers_cb = QCheckBox("Peers")
        self.peers_cb.toggled.connect(self._send_to_card)
        input_layout.addWidget(self.peers_cb)

        # === ACTIVITIES SECTION ===
        activities_lbl = QLabel("Activities & Treatment")
        activities_lbl.setStyleSheet("font-size: 18px; font-weight: 600; color: #374151; margin-top: 8px;")
        input_layout.addWidget(activities_lbl)

        self.ot_cb = QCheckBox("OT")
        self.ot_cb.toggled.connect(self._send_to_card)
        input_layout.addWidget(self.ot_cb)

        self.nursing_cb = QCheckBox("Nursing")
        self.nursing_cb.toggled.connect(self._send_to_card)
        input_layout.addWidget(self.nursing_cb)

        self.psychology_cb = QCheckBox("Psychology")
        self.psychology_cb.toggled.connect(self._send_to_card)
        input_layout.addWidget(self.psychology_cb)

        # === AFFECT SECTION ===
        affect_lbl = QLabel("Affect")
        affect_lbl.setStyleSheet("font-size: 18px; font-weight: 600; color: #374151; margin-top: 8px;")
        input_layout.addWidget(affect_lbl)

        self.affect_cb = QCheckBox("Affect (expand for options)")
        self.affect_cb.toggled.connect(self._on_affect_toggled)
        input_layout.addWidget(self.affect_cb)

        # Affect sub-options container
        self.affect_container = QWidget()
        affect_sub_layout = QVBoxLayout(self.affect_container)
        affect_sub_layout.setContentsMargins(20, 4, 0, 0)
        affect_sub_layout.setSpacing(4)

        self.humour_cb = QCheckBox("Sense of humour")
        self.humour_cb.toggled.connect(self._send_to_card)
        affect_sub_layout.addWidget(self.humour_cb)

        self.warmth_cb = QCheckBox("Warmth")
        self.warmth_cb.toggled.connect(self._send_to_card)
        affect_sub_layout.addWidget(self.warmth_cb)

        self.friendly_cb = QCheckBox("Friendly")
        self.friendly_cb.toggled.connect(self._send_to_card)
        affect_sub_layout.addWidget(self.friendly_cb)

        self.caring_cb = QCheckBox("Caring")
        self.caring_cb.toggled.connect(self._send_to_card)
        affect_sub_layout.addWidget(self.caring_cb)

        self.affect_container.hide()
        input_layout.addWidget(self.affect_container)

        self.input_section.set_content(input_content)
        self.scroll_layout.addWidget(self.input_section)

        # Note: imported data will be added here by _add_imported_data_to_popup
        self.scroll_layout.addStretch()
        self.layout.addWidget(scroll, 1)

    def _on_affect_toggled(self, checked):
        self.affect_container.setVisible(checked)
        if not checked:
            # Uncheck all sub-options when hiding
            self.humour_cb.setChecked(False)
            self.warmth_cb.setChecked(False)
            self.friendly_cb.setChecked(False)
            self.caring_cb.setChecked(False)
        self._send_to_card()

    def generate_text(self) -> str:
        p = self._get_pronouns()
        parts = []

        # Engagement with staff/peers
        staff = self.staff_cb.isChecked()
        peers = self.peers_cb.isChecked()

        if staff and peers:
            parts.append(f"{p['subj']} engages well with both staff and peers.")
        elif staff:
            parts.append(f"{p['subj']} engages well with staff.")
        elif peers:
            parts.append(f"{p['subj']} engages well with peers.")

        # OT
        if self.ot_cb.isChecked():
            parts.append(f"{p['subj']} is able to get involved in OT activities.")

        # Nursing
        if self.nursing_cb.isChecked():
            parts.append(f"{p['subj']} works collaboratively with nursing staff.")

        # Psychology
        if self.psychology_cb.isChecked():
            parts.append(f"{p['pos']} attendance at psychology sessions is an important strength.")

        # Affect sub-options
        if self.affect_cb.isChecked():
            if self.humour_cb.isChecked():
                parts.append(f"{p['subj']} can display a positive sense of humour.")
            if self.warmth_cb.isChecked():
                parts.append(f"{p['subj']} can be warm with staff and peers.")
            if self.friendly_cb.isChecked():
                parts.append(f"{p['subj']} can be appropriately friendly at times.")
            if self.caring_cb.isChecked():
                parts.append(f"{p['subj']} displays empathy and a caring attitude on the ward to staff and peers.")

        return " ".join(parts)

    def get_state(self) -> dict:
        return {
            "staff": self.staff_cb.isChecked(),
            "peers": self.peers_cb.isChecked(),
            "ot": self.ot_cb.isChecked(),
            "nursing": self.nursing_cb.isChecked(),
            "psychology": self.psychology_cb.isChecked(),
            "affect": self.affect_cb.isChecked(),
            "humour": self.humour_cb.isChecked(),
            "warmth": self.warmth_cb.isChecked(),
            "friendly": self.friendly_cb.isChecked(),
            "caring": self.caring_cb.isChecked(),
        }

    def restore_state(self, state: dict):
        if not state:
            return

        self.staff_cb.setChecked(state.get("staff", False))
        self.peers_cb.setChecked(state.get("peers", False))
        self.ot_cb.setChecked(state.get("ot", False))
        self.nursing_cb.setChecked(state.get("nursing", False))
        self.psychology_cb.setChecked(state.get("psychology", False))
        self.affect_cb.setChecked(state.get("affect", False))
        self.humour_cb.setChecked(state.get("humour", False))
        self.warmth_cb.setChecked(state.get("warmth", False))
        self.friendly_cb.setChecked(state.get("friendly", False))
        self.caring_cb.setChecked(state.get("caring", False))

        self._send_to_card()


# ================================================================
# COMPLIANCE POPUP (Section 15)
# ================================================================

class CompliancePopup(TribunalPopupBase):
    """Popup for understanding and compliance with treatment section."""

    UNDERSTANDING_OPTIONS = ["Select...", "good", "fair", "poor"]
    COMPLIANCE_OPTIONS = ["Select...", "full", "reasonable", "partial", "nil"]

    def __init__(self, parent=None, gender=None):
        super().__init__("Understanding & Compliance", parent)
        self.gender = gender or "neutral"
        self._setup_ui()

    def _get_pronouns(self):
        g = (self.gender or "").lower().strip()
        if g == "male":
            return {"subj": "He", "obj": "him", "pos": "his", "is": "is", "has": "has", "does": "does", "sees": "sees", "engages": "engages"}
        elif g == "female":
            return {"subj": "She", "obj": "her", "pos": "her", "is": "is", "has": "has", "does": "does", "sees": "sees", "engages": "engages"}
        return {"subj": "They", "obj": "them", "pos": "their", "is": "are", "has": "have", "does": "do", "sees": "see", "engages": "engage"}

    def set_gender(self, gender: str):
        self.gender = gender

    def _setup_ui(self):
        from PySide6.QtWidgets import QComboBox, QScrollArea, QGridLayout
        from background_history_popup import CollapsibleSection

        # ========================================================
        # SCROLLABLE CONTENT
        # ========================================================
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        scroll_content = QWidget()
        scroll_content.setObjectName("compliance_scroll_content")
        scroll_content.setStyleSheet("""
            QWidget#compliance_scroll_content {
                background: rgba(255,255,255,0.95);
                border-radius: 12px;
                border: 1px solid rgba(0,0,0,0.1);
            }
            QLabel, QRadioButton, QCheckBox {
                background: transparent;
                border: none;
            }
        """)
        self.scroll_layout = QVBoxLayout(scroll_content)
        self.scroll_layout.setContentsMargins(12, 12, 12, 12)
        self.scroll_layout.setSpacing(12)
        scroll.setWidget(scroll_content)

        # ========================================================
        # COLLAPSIBLE INPUT SECTION: Understanding & Compliance
        # ========================================================
        self.input_section = CollapsibleSection("Understanding & Compliance", start_collapsed=False)
        self.input_section.set_content_height(280)
        self.input_section._min_height = 150
        self.input_section._max_height = 400
        self.input_section.set_header_style("""
            QFrame {
                background: rgba(59, 130, 246, 0.15);
                border: 1px solid rgba(59, 130, 246, 0.3);
                border-radius: 6px 6px 0 0;
            }
        """)
        self.input_section.title_label.setStyleSheet("""
            QLabel {
                font-size: 18px;
                font-weight: 600;
                color: #1d4ed8;
                background: transparent;
                border: none;
            }
        """)

        input_content = QWidget()
        input_content.setStyleSheet("""
            QWidget {
                background: rgba(239, 246, 255, 0.95);
                border: 1px solid rgba(59, 130, 246, 0.3);
                border-top: none;
                border-radius: 0 0 12px 12px;
            }
            QLabel {
                background: transparent;
                border: none;
                font-size: 17px;
            }
            QComboBox {
                background: white;
                border: 1px solid #d1d5db;
                border-radius: 4px;
                padding: 4px 8px;
                font-size: 14px;
            }
        """)
        input_layout = QVBoxLayout(input_content)
        input_layout.setContentsMargins(12, 12, 12, 12)
        input_layout.setSpacing(8)

        # Grid for treatments
        grid = QGridLayout()
        grid.setSpacing(8)

        # Headers
        header_treatment = QLabel("Treatment")
        header_treatment.setStyleSheet("font-size: 17px; font-weight: 600; color: #374151; background: transparent; border: none;")
        header_understanding = QLabel("Understanding")
        header_understanding.setStyleSheet("font-size: 17px; font-weight: 600; color: #374151; background: transparent; border: none;")
        header_compliance = QLabel("Compliance")
        header_compliance.setStyleSheet("font-size: 17px; font-weight: 600; color: #374151; background: transparent; border: none;")

        grid.addWidget(header_treatment, 0, 0)
        grid.addWidget(header_understanding, 0, 1)
        grid.addWidget(header_compliance, 0, 2)

        # Treatment rows
        self.treatments = {}
        treatment_names = ["Medical", "Nursing", "Psychology", "OT", "Social Work"]

        for i, name in enumerate(treatment_names, 1):
            key = name.lower().replace(" ", "_")

            # Label
            lbl = QLabel(name)
            lbl.setStyleSheet("font-size: 17px; color: #374151; background: transparent; border: none;")
            grid.addWidget(lbl, i, 0)

            # Understanding dropdown
            understanding = QComboBox()
            understanding.addItems(self.UNDERSTANDING_OPTIONS)
            understanding.currentIndexChanged.connect(self._send_to_card)
            grid.addWidget(understanding, i, 1)

            # Compliance dropdown
            compliance = QComboBox()
            compliance.addItems(self.COMPLIANCE_OPTIONS)
            compliance.currentIndexChanged.connect(self._send_to_card)
            grid.addWidget(compliance, i, 2)

            self.treatments[key] = {
                "understanding": understanding,
                "compliance": compliance
            }

        input_layout.addLayout(grid)
        self.input_section.set_content(input_content)
        self.scroll_layout.addWidget(self.input_section)

        # Note: Imported data section will be added separately by _add_imported_data_to_popup
        self.scroll_layout.addStretch()
        self.layout.addWidget(scroll, 1)

    def _understanding_phrase(self, level: str, treatment: str, p: dict) -> str:
        """Generate understanding phrase based on level."""
        if level == "good":
            return f"{p['subj']} has good understanding of {p['pos']} {treatment} treatment"
        elif level == "fair":
            return f"{p['subj']} has some understanding of {p['pos']} {treatment} treatment"
        elif level == "poor":
            return f"{p['subj']} has limited understanding of {p['pos']} {treatment} treatment"
        return ""

    def _compliance_phrase(self, level: str, p: dict) -> str:
        """Generate compliance phrase based on level."""
        if level == "full":
            return "and compliance is full"
        elif level == "reasonable":
            return "and compliance is reasonable"
        elif level == "partial":
            return "but compliance is partial"
        elif level == "nil":
            return "and compliance is nil"
        return ""

    def _nursing_phrase(self, understanding: str, compliance: str, p: dict) -> str:
        """Generate natural nursing phrase."""
        if understanding == "good" and compliance in ("full", "reasonable"):
            return f"{p['subj']} {p['engages']} well with nursing staff and {p['sees']} the need for nursing input."
        elif understanding == "good" and compliance == "partial":
            return f"{p['subj']} understands the role of nursing but engagement is inconsistent."
        elif understanding == "fair" and compliance in ("full", "reasonable"):
            return f"{p['subj']} has some understanding of nursing care and {p['engages']} reasonably well."
        elif understanding == "fair" and compliance == "partial":
            return f"{p['subj']} has some understanding of nursing input but {p['engages']} only partially."
        elif understanding == "poor" or compliance == "nil":
            return f"{p['subj']} has limited insight into the need for nursing care and {p['does']} not engage meaningfully."
        return ""

    def _psychology_phrase(self, understanding: str, compliance: str, p: dict) -> str:
        """Generate natural psychology phrase."""
        if understanding == "good" and compliance in ("full", "reasonable"):
            return f"{p['subj']} {p['engages']} in psychology sessions and sees the benefit of this work."
        elif understanding == "good" and compliance == "partial":
            return f"{p['subj']} understands the purpose of psychology but compliance with sessions is limited."
        elif understanding == "fair" and compliance in ("full", "reasonable"):
            return f"{p['subj']} has some understanding of psychology and attends sessions regularly."
        elif understanding == "fair" and compliance == "partial":
            return f"{p['subj']} also {p['engages']} in psychology sessions but the compliance with these is limited."
        elif understanding == "poor" or compliance == "nil":
            return f"{p['subj']} has limited insight into the need for psychology and {p['does']} not engage with sessions."
        return ""

    def _ot_phrase(self, understanding: str, compliance: str, p: dict) -> str:
        """Generate natural OT phrase."""
        if understanding == "good" and compliance in ("full", "reasonable"):
            return f"With respect to OT, {p['subj'].lower()} {p['engages']} well and sees the benefit of activities."
        elif understanding == "good" and compliance == "partial":
            return f"With respect to OT, {p['subj'].lower()} understands the purpose but engagement is inconsistent."
        elif understanding == "fair" and compliance in ("full", "reasonable"):
            return f"With respect to OT, {p['subj'].lower()} has some understanding and participates in activities."
        elif understanding == "fair" and compliance == "partial":
            return f"With respect to OT, {p['subj'].lower()} has some insight but engagement is limited."
        elif understanding == "poor" or compliance == "nil":
            return f"With respect to OT, {p['subj'].lower()} {p['is']} not engaging and doesn't see the need to."
        return ""

    def _social_work_phrase(self, understanding: str, compliance: str, p: dict) -> str:
        """Generate natural social work phrase."""
        if understanding == "good" and compliance in ("full", "reasonable"):
            return f"{p['subj']} {p['engages']} well with the social worker and understands {p['pos']} social circumstances."
        elif understanding == "good" and compliance == "partial":
            return f"{p['subj']} understands the social worker's role but engagement is inconsistent."
        elif understanding == "fair" and compliance in ("full", "reasonable"):
            return f"{p['subj']} has some understanding of social work input and {p['engages']} when available."
        elif understanding == "fair" and compliance == "partial":
            return f"{p['subj']} occasionally {p['sees']} the social worker and {p['engages']} partially when {p['subj'].lower()} {p['does']} so."
        elif understanding == "poor" or compliance == "nil":
            return f"{p['subj']} has limited engagement with social work and doesn't see the relevance."
        return ""

    def generate_text(self) -> str:
        p = self._get_pronouns()
        parts = []

        # Medical
        med = self.treatments["medical"]
        med_u = med["understanding"].currentText()
        med_c = med["compliance"].currentText()
        if med_u != "Select..." and med_c != "Select...":
            u_phrase = self._understanding_phrase(med_u, "medical", p)
            c_phrase = self._compliance_phrase(med_c, p)
            if u_phrase and c_phrase:
                parts.append(f"{u_phrase} {c_phrase}.")

        # Nursing
        nursing = self.treatments["nursing"]
        nursing_u = nursing["understanding"].currentText()
        nursing_c = nursing["compliance"].currentText()
        if nursing_u != "Select..." and nursing_c != "Select...":
            phrase = self._nursing_phrase(nursing_u, nursing_c, p)
            if phrase:
                parts.append(phrase)

        # Psychology
        psych = self.treatments["psychology"]
        psych_u = psych["understanding"].currentText()
        psych_c = psych["compliance"].currentText()
        if psych_u != "Select..." and psych_c != "Select...":
            phrase = self._psychology_phrase(psych_u, psych_c, p)
            if phrase:
                parts.append(phrase)

        # OT
        ot = self.treatments["ot"]
        ot_u = ot["understanding"].currentText()
        ot_c = ot["compliance"].currentText()
        if ot_u != "Select..." and ot_c != "Select...":
            phrase = self._ot_phrase(ot_u, ot_c, p)
            if phrase:
                parts.append(phrase)

        # Social Work
        sw = self.treatments["social_work"]
        sw_u = sw["understanding"].currentText()
        sw_c = sw["compliance"].currentText()
        if sw_u != "Select..." and sw_c != "Select...":
            phrase = self._social_work_phrase(sw_u, sw_c, p)
            if phrase:
                parts.append(phrase)

        return " ".join(parts)

    def get_state(self) -> dict:
        state = {}
        for key, widgets in self.treatments.items():
            state[f"{key}_understanding"] = widgets["understanding"].currentText()
            state[f"{key}_compliance"] = widgets["compliance"].currentText()
        return state

    def restore_state(self, state: dict):
        if not state:
            return

        for key, widgets in self.treatments.items():
            u_val = state.get(f"{key}_understanding", "Select...")
            c_val = state.get(f"{key}_compliance", "Select...")

            u_idx = widgets["understanding"].findText(u_val)
            if u_idx >= 0:
                widgets["understanding"].setCurrentIndex(u_idx)

            c_idx = widgets["compliance"].findText(c_val)
            if c_idx >= 0:
                widgets["compliance"].setCurrentIndex(c_idx)

        self._send_to_card()


# ================================================================
# DOLS POPUP (Section 16)
# ================================================================

class DoLsPopup(TribunalPopupBase):
    """Popup for Deprivation of Liberty section."""

    def __init__(self, parent=None):
        super().__init__("Deprivation of Liberty", parent)
        self._setup_ui()

    def _setup_ui(self):
        from PySide6.QtWidgets import QRadioButton, QButtonGroup

        # ========================================================
        # OPTIONS
        # ========================================================
        options_container = QWidget()
        options_container.setStyleSheet("""
            QWidget {
                background: rgba(255,255,255,0.95);
                border-radius: 12px;
                border: 1px solid rgba(0,0,0,0.1);
            }
            QLabel, QRadioButton, QCheckBox {
                background: transparent;
                border: none;
            }
        """)
        self.scroll_layout = QVBoxLayout(options_container)
        self.scroll_layout.setContentsMargins(16, 16, 16, 16)
        self.scroll_layout.setSpacing(12)

        q_lbl = QLabel("Is Deprivation of Liberty under MCA 2005 required?")
        q_lbl.setWordWrap(True)
        q_lbl.setStyleSheet("font-size: 18px; font-weight: 600; color: #374151;")
        self.scroll_layout.addWidget(q_lbl)

        self.btn_group = QButtonGroup(self)

        self.yes_btn = QRadioButton("Yes")
        self.no_btn = QRadioButton("No")
        self.na_btn = QRadioButton("Not Applicable")

        self.btn_group.addButton(self.yes_btn, 0)
        self.btn_group.addButton(self.no_btn, 1)
        self.btn_group.addButton(self.na_btn, 2)

        for btn in [self.yes_btn, self.no_btn, self.na_btn]:
            btn.toggled.connect(self._send_to_card)
            self.scroll_layout.addWidget(btn)

        # Note: imported data will be added here by _add_imported_data_to_popup
        self.scroll_layout.addStretch()
        self.layout.addWidget(options_container, 1)

    def generate_text(self) -> str:
        if self.yes_btn.isChecked():
            return "DoLs is required."
        elif self.no_btn.isChecked():
            return "DoLs is not required."
        elif self.na_btn.isChecked():
            return "DoLs is not applicable."
        return ""

    def get_state(self) -> dict:
        answer = None
        if self.yes_btn.isChecked():
            answer = "yes"
        elif self.no_btn.isChecked():
            answer = "no"
        elif self.na_btn.isChecked():
            answer = "na"
        return {"answer": answer}

    def restore_state(self, state: dict):
        if not state:
            return

        answer = state.get("answer")
        if answer == "yes":
            self.yes_btn.setChecked(True)
        elif answer == "no":
            self.no_btn.setChecked(True)
        elif answer == "na":
            self.na_btn.setChecked(True)


# ================================================================
# YES/NO/NA POPUP (Reusable for sections 19, 20, etc.)
# ================================================================

class YesNoNAPopup(TribunalPopupBase):
    """Popup with Yes/No/NA options and customizable outputs."""

    def __init__(self, title: str, question: str,
                 yes_output: str = "Yes",
                 no_output: str = "No",
                 na_output: str = "Not applicable",
                 parent=None):
        super().__init__(title, parent)
        self.question = question
        self.yes_output = yes_output
        self.no_output = no_output
        self.na_output = na_output
        self._setup_ui()

    def _setup_ui(self):
        from PySide6.QtWidgets import QRadioButton, QButtonGroup

        # ========================================================
        # OPTIONS
        # ========================================================
        options_container = QWidget()
        options_container.setStyleSheet("""
            QWidget {
                background: rgba(255,255,255,0.95);
                border-radius: 12px;
                border: 1px solid rgba(0,0,0,0.1);
            }
            QLabel, QRadioButton, QCheckBox {
                background: transparent;
                border: none;
            }
        """)
        options_layout = QVBoxLayout(options_container)
        options_layout.setContentsMargins(16, 16, 16, 16)
        options_layout.setSpacing(12)

        q_lbl = QLabel(self.question)
        q_lbl.setWordWrap(True)
        q_lbl.setStyleSheet("font-size: 18px; font-weight: 600; color: #374151;")
        options_layout.addWidget(q_lbl)

        self.btn_group = QButtonGroup(self)

        self.yes_btn = QRadioButton("Yes")
        self.no_btn = QRadioButton("No")
        self.na_btn = QRadioButton("Not Applicable")

        self.btn_group.addButton(self.yes_btn, 0)
        self.btn_group.addButton(self.no_btn, 1)
        self.btn_group.addButton(self.na_btn, 2)

        for btn in [self.yes_btn, self.no_btn, self.na_btn]:
            btn.toggled.connect(self._send_to_card)
            options_layout.addWidget(btn)

        options_layout.addStretch()
        self.layout.addWidget(options_container, 1)

    def generate_text(self) -> str:
        if self.yes_btn.isChecked():
            return self.yes_output
        elif self.no_btn.isChecked():
            return self.no_output
        elif self.na_btn.isChecked():
            return self.na_output
        return ""

    def get_state(self) -> dict:
        answer = None
        if self.yes_btn.isChecked():
            answer = "yes"
        elif self.no_btn.isChecked():
            answer = "no"
        elif self.na_btn.isChecked():
            answer = "na"
        return {"answer": answer}

    def restore_state(self, state: dict):
        if not state:
            return

        answer = state.get("answer")
        if answer == "yes":
            self.yes_btn.setChecked(True)
        elif answer == "no":
            self.no_btn.setChecked(True)
        elif answer == "na":
            self.na_btn.setChecked(True)


# ================================================================
# MHA TREATMENT POPUP (Section 20)
# ================================================================

class MHATreatmentPopup(TribunalPopupBase):
    """Popup for Medical treatment under MHA section."""

    def __init__(self, parent=None, gender=None):
        super().__init__("Medical Treatment under MHA", parent)
        self.gender = gender or "neutral"
        self._setup_ui()

    def _get_pronouns(self):
        g = (self.gender or "").lower().strip()
        if g == "male":
            return {"subj": "He", "obj": "him", "pos": "his", "himself": "himself"}
        elif g == "female":
            return {"subj": "She", "obj": "her", "pos": "her", "himself": "herself"}
        return {"subj": "They", "obj": "them", "pos": "their", "himself": "themselves"}

    def set_gender(self, gender: str):
        self.gender = gender

    def _setup_ui(self):
        from PySide6.QtWidgets import QRadioButton, QButtonGroup, QCheckBox, QScrollArea

        # ========================================================
        # SCROLLABLE CONTENT
        # ========================================================
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        scroll_content = QWidget()
        scroll_content.setObjectName("mha_scroll_content")
        scroll_content.setStyleSheet("""
            QWidget#mha_scroll_content {
                background: rgba(255,255,255,0.95);
                border-radius: 12px;
                border: 1px solid rgba(0,0,0,0.1);
            }
            QLabel, QRadioButton, QCheckBox {
                background: transparent;
                border: none;
            }
        """)
        self.scroll_layout = QVBoxLayout(scroll_content)
        self.scroll_layout.setContentsMargins(12, 12, 12, 12)
        self.scroll_layout.setSpacing(10)
        scroll.setWidget(scroll_content)

        # === NECESSARY SECTION ===
        necessary_lbl = QLabel("Is medical treatment under MHA necessary?")
        necessary_lbl.setStyleSheet("font-size: 18px; font-weight: 600; color: #374151;")
        self.scroll_layout.addWidget(necessary_lbl)

        self.necessary_group = QButtonGroup(self)
        necessary_row = QHBoxLayout()

        self.necessary_yes = QRadioButton("Yes")
        self.necessary_no = QRadioButton("No")

        self.necessary_group.addButton(self.necessary_yes, 0)
        self.necessary_group.addButton(self.necessary_no, 1)

        self.necessary_yes.toggled.connect(self._on_necessary_toggled)
        self.necessary_no.toggled.connect(self._on_necessary_toggled)

        necessary_row.addWidget(self.necessary_yes)
        necessary_row.addWidget(self.necessary_no)
        necessary_row.addStretch()
        self.scroll_layout.addLayout(necessary_row)

        # === HEALTH & SAFETY CONTAINER (shown only when Yes selected) ===
        self.health_safety_container = QWidget()
        hs_layout = QVBoxLayout(self.health_safety_container)
        hs_layout.setContentsMargins(0, 0, 0, 0)
        hs_layout.setSpacing(10)

        # === HEALTH SECTION ===
        self.health_cb = QCheckBox("Health")
        self.health_cb.setStyleSheet("font-size: 18px; font-weight: 600; color: #374151;")
        self.health_cb.toggled.connect(self._on_health_toggled)
        hs_layout.addWidget(self.health_cb)

        self.health_container = QWidget()
        health_layout = QVBoxLayout(self.health_container)
        health_layout.setContentsMargins(20, 4, 0, 0)
        health_layout.setSpacing(6)

        # Mental Health
        self.mental_health_cb = QCheckBox("Mental Health")
        self.mental_health_cb.toggled.connect(self._on_mental_health_toggled)
        health_layout.addWidget(self.mental_health_cb)

        # Mental Health sub-options container
        self.mental_health_container = QWidget()
        mh_sub_layout = QVBoxLayout(self.mental_health_container)
        mh_sub_layout.setContentsMargins(20, 4, 0, 0)
        mh_sub_layout.setSpacing(4)

        due_to_lbl = QLabel("Due to:")
        due_to_lbl.setStyleSheet("font-size: 16px; color: #6b7280;")
        mh_sub_layout.addWidget(due_to_lbl)

        self.poor_compliance_cb = QCheckBox("Poor compliance")
        self.poor_compliance_cb.toggled.connect(self._send_to_card)
        mh_sub_layout.addWidget(self.poor_compliance_cb)

        self.limited_insight_cb = QCheckBox("Limited insight")
        self.limited_insight_cb.toggled.connect(self._send_to_card)
        mh_sub_layout.addWidget(self.limited_insight_cb)

        self.mental_health_container.hide()
        health_layout.addWidget(self.mental_health_container)

        # Physical Health
        self.physical_health_cb = QCheckBox("Physical Health")
        self.physical_health_cb.toggled.connect(self._on_physical_health_toggled)
        health_layout.addWidget(self.physical_health_cb)

        self.physical_health_details = QTextEdit()
        self.physical_health_details.setPlaceholderText("Enter physical health details...")
        self.physical_health_details.setMaximumHeight(60)
        self.physical_health_details.textChanged.connect(self._send_to_card)
        self.physical_health_details.hide()
        health_layout.addWidget(self.physical_health_details)

        self.health_container.hide()
        hs_layout.addWidget(self.health_container)

        # === SAFETY SECTION ===
        self.safety_cb = QCheckBox("Safety")
        self.safety_cb.setStyleSheet("font-size: 18px; font-weight: 600; color: #374151;")
        self.safety_cb.toggled.connect(self._on_safety_toggled)
        hs_layout.addWidget(self.safety_cb)

        self.safety_container = QWidget()
        safety_layout = QVBoxLayout(self.safety_container)
        safety_layout.setContentsMargins(20, 4, 0, 0)
        safety_layout.setSpacing(6)

        # Self
        self.self_cb = QCheckBox("Self")
        self.self_cb.toggled.connect(self._on_self_toggled)
        safety_layout.addWidget(self.self_cb)

        self.self_details = QTextEdit()
        self.self_details.setPlaceholderText("Enter details about risk to self...")
        self.self_details.setMaximumHeight(60)
        self.self_details.textChanged.connect(self._send_to_card)
        self.self_details.hide()
        safety_layout.addWidget(self.self_details)

        # Others
        self.others_cb = QCheckBox("Others")
        self.others_cb.toggled.connect(self._on_others_toggled)
        safety_layout.addWidget(self.others_cb)

        self.others_details = QTextEdit()
        self.others_details.setPlaceholderText("Enter details about risk to others...")
        self.others_details.setMaximumHeight(60)
        self.others_details.textChanged.connect(self._send_to_card)
        self.others_details.hide()
        safety_layout.addWidget(self.others_details)

        self.safety_container.hide()
        hs_layout.addWidget(self.safety_container)

        # Hide the entire health/safety container initially
        self.health_safety_container.hide()
        self.scroll_layout.addWidget(self.health_safety_container)

        # Note: imported data will be added here by _add_imported_data_to_popup
        self.scroll_layout.addStretch()
        self.layout.addWidget(scroll, 1)

    def _on_necessary_toggled(self, checked):
        """Show/hide health and safety options based on Yes/No selection."""
        if self.necessary_yes.isChecked():
            self.health_safety_container.show()
        else:
            # Hide and reset all health/safety options
            self.health_safety_container.hide()
            self.health_cb.setChecked(False)
            self.safety_cb.setChecked(False)
        self._send_to_card()

    def _on_health_toggled(self, checked):
        self.health_container.setVisible(checked)
        if not checked:
            self.mental_health_cb.setChecked(False)
            self.physical_health_cb.setChecked(False)
        self._send_to_card()

    def _on_mental_health_toggled(self, checked):
        self.mental_health_container.setVisible(checked)
        if not checked:
            self.poor_compliance_cb.setChecked(False)
            self.limited_insight_cb.setChecked(False)
        self._send_to_card()

    def _on_physical_health_toggled(self, checked):
        self.physical_health_details.setVisible(checked)
        if not checked:
            self.physical_health_details.clear()
        self._send_to_card()

    def _on_safety_toggled(self, checked):
        self.safety_container.setVisible(checked)
        if not checked:
            self.self_cb.setChecked(False)
            self.others_cb.setChecked(False)
        self._send_to_card()

    def _on_self_toggled(self, checked):
        self.self_details.setVisible(checked)
        if not checked:
            self.self_details.clear()
        self._send_to_card()

    def _on_others_toggled(self, checked):
        self.others_details.setVisible(checked)
        if not checked:
            self.others_details.clear()
        self._send_to_card()

    def generate_text(self) -> str:
        p = self._get_pronouns()
        parts = []

        # Necessary
        if self.necessary_yes.isChecked():
            parts.append("Medical treatment under the Mental Health Act is necessary.")
        elif self.necessary_no.isChecked():
            parts.append("Medical treatment under the Mental Health Act is not necessary.")

        # Health
        if self.health_cb.isChecked():
            if self.mental_health_cb.isChecked():
                # Base mental health statement
                parts.append(f"Necessity for detention is to prevent deterioration in {p['pos']} mental health.")

                # Check sub-options
                poor_compliance = self.poor_compliance_cb.isChecked()
                limited_insight = self.limited_insight_cb.isChecked()

                if poor_compliance and limited_insight:
                    parts.append(f"Both historical non compliance and current limited insight makes the risk on stopping medication high without the safeguards of the mental health act. This would result in a deterioration of {p['pos']} mental state.")
                elif poor_compliance:
                    parts.append(f"This is based on historical non compliance and without detention I would be concerned this would result in a deterioration of {p['pos']} mental state.")
                elif limited_insight:
                    parts.append(f"I am concerned about {p['pos']} current limited insight into {p['pos']} mental health needs and how this would result in immediate non compliance with medication, hence a deterioration in {p['pos']} mental health.")

            if self.physical_health_cb.isChecked():
                details = self.physical_health_details.toPlainText().strip()
                # Different wording if mental health is also checked
                if self.mental_health_cb.isChecked():
                    base = f"The Mental Health Act is also necessary for maintaining {p['pos']} physical health and without application of this {p['pos']} physical health would be at risk."
                else:
                    base = f"The Mental Health Act is necessary for {p['pos']} physical health."
                if details:
                    parts.append(f"{base} {details}")
                else:
                    parts.append(base)

        # Safety
        if self.safety_cb.isChecked():
            if self.self_cb.isChecked():
                details = self.self_details.toPlainText().strip()
                if details:
                    parts.append(f"The Mental Health Act is necessary for {p['pos']} risk to {p['himself']}. {details}")
                else:
                    parts.append(f"The Mental Health Act is necessary for {p['pos']} risk to {p['himself']}.")

            if self.others_cb.isChecked():
                details = self.others_details.toPlainText().strip()
                # Different wording if self is also checked
                if self.self_cb.isChecked():
                    base = "Risk to others also makes the Mental Health Act necessary."
                else:
                    base = "Risk to others makes the Mental Health Act necessary."
                if details:
                    parts.append(f"{base} {details}")
                else:
                    parts.append(base)

        return " ".join(parts)

    def get_state(self) -> dict:
        necessary = None
        if self.necessary_yes.isChecked():
            necessary = "yes"
        elif self.necessary_no.isChecked():
            necessary = "no"

        return {
            "necessary": necessary,
            "health": self.health_cb.isChecked(),
            "mental_health": self.mental_health_cb.isChecked(),
            "poor_compliance": self.poor_compliance_cb.isChecked(),
            "limited_insight": self.limited_insight_cb.isChecked(),
            "physical_health": self.physical_health_cb.isChecked(),
            "physical_health_details": self.physical_health_details.toPlainText(),
            "safety": self.safety_cb.isChecked(),
            "self": self.self_cb.isChecked(),
            "self_details": self.self_details.toPlainText(),
            "others": self.others_cb.isChecked(),
            "others_details": self.others_details.toPlainText(),
        }

    def restore_state(self, state: dict):
        if not state:
            return

        necessary = state.get("necessary")
        if necessary == "yes":
            self.necessary_yes.setChecked(True)
        elif necessary == "no":
            self.necessary_no.setChecked(True)

        self.health_cb.setChecked(state.get("health", False))
        self.mental_health_cb.setChecked(state.get("mental_health", False))
        self.poor_compliance_cb.setChecked(state.get("poor_compliance", False))
        self.limited_insight_cb.setChecked(state.get("limited_insight", False))
        self.physical_health_cb.setChecked(state.get("physical_health", False))
        self.physical_health_details.setPlainText(state.get("physical_health_details", ""))

        self.safety_cb.setChecked(state.get("safety", False))
        self.self_cb.setChecked(state.get("self", False))
        self.self_details.setPlainText(state.get("self_details", ""))
        self.others_cb.setChecked(state.get("others", False))
        self.others_details.setPlainText(state.get("others_details", ""))

        self._send_to_card()


# ================================================================
# COMMUNITY MANAGEMENT POPUP (Section 22)
# ================================================================

class CommunityManagementPopup(TribunalPopupBase):
    """Popup for Community risk management section."""

    FLOATING_SUPPORT_OPTIONS = [
        "Select frequency...",
        "24 hour",
        "4x/day",
        "3x/day",
        "2x/day",
        "Daily",
        "Every other day",
        "Every 2 days",
        "Twice a week",
        "Once a week",
        "Every 2 weeks"
    ]

    def __init__(self, parent=None, gender=None):
        super().__init__("Community Risk Management", parent)
        self.gender = gender or "neutral"
        self._setup_ui()

    def _get_pronouns(self):
        g = (self.gender or "").lower().strip()
        if g == "male":
            return {"subj": "He", "obj": "him", "pos": "His", "pos_lower": "his", "is": "is"}
        elif g == "female":
            return {"subj": "She", "obj": "her", "pos": "Her", "pos_lower": "her", "is": "is"}
        return {"subj": "They", "obj": "them", "pos": "Their", "pos_lower": "their", "is": "are"}

    def set_gender(self, gender: str):
        self.gender = gender
        self._send_to_card()

    def _setup_ui(self):
        from PySide6.QtWidgets import QCheckBox, QScrollArea, QRadioButton, QButtonGroup, QComboBox
        from background_history_popup import CollapsibleSection

        # ========================================================
        # SECTION 1: SCROLLABLE CONTENT
        # ========================================================
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        scroll_content = QWidget()
        scroll_content.setObjectName("community_scroll_content")
        scroll_content.setStyleSheet("""
            QWidget#community_scroll_content {
                background: rgba(255,255,255,0.95);
                border-radius: 12px;
                border: 1px solid rgba(0,0,0,0.1);
            }
            QLabel, QRadioButton, QCheckBox {
                background: transparent;
                border: none;
                font-size: 22px;
            }
        """)
        self.scroll_layout = QVBoxLayout(scroll_content)
        self.scroll_layout.setContentsMargins(12, 12, 12, 12)
        self.scroll_layout.setSpacing(10)
        scroll.setWidget(scroll_content)

        # ========================================================
        # COLLAPSIBLE SECTION: Community Risk Management
        # ========================================================
        self.input_section = CollapsibleSection("Community Risk Management", start_collapsed=False)
        self.input_section.set_content_height(400)
        self.input_section._min_height = 200
        self.input_section._max_height = 600
        self.input_section.set_header_style("""
            QFrame {
                background: rgba(59, 130, 246, 0.15);
                border: 1px solid rgba(59, 130, 246, 0.3);
                border-radius: 6px 6px 0 0;
            }
        """)
        self.input_section.title_label.setStyleSheet("""
            QLabel {
                font-size: 18px;
                font-weight: 600;
                color: #1d4ed8;
                background: transparent;
                border: none;
            }
        """)

        input_content = QWidget()
        input_content.setStyleSheet("""
            QWidget {
                background: rgba(239, 246, 255, 0.95);
                border: 1px solid rgba(59, 130, 246, 0.3);
                border-top: none;
                border-radius: 0 0 12px 12px;
            }
            QLabel, QRadioButton, QCheckBox {
                background: transparent;
                border: none;
                font-size: 22px;
            }
        """)
        input_layout = QVBoxLayout(input_content)
        input_layout.setContentsMargins(12, 12, 12, 12)
        input_layout.setSpacing(10)

        # ============ LEGAL SECTION ============
        legal_lbl = QLabel("Legal")
        legal_lbl.setStyleSheet("font-size: 18px; font-weight: 700; color: #374151; margin-top: 4px;")
        input_layout.addWidget(legal_lbl)

        # CTO / S37/41 radio buttons (mutually exclusive)
        self.legal_btn_group = QButtonGroup(self)
        self.legal_btn_group.setExclusive(False)  # Allow none selected

        self.cto_rb = QRadioButton("CTO (Community Treatment Order)")
        self.cto_rb.toggled.connect(self._on_legal_toggled)
        self.legal_btn_group.addButton(self.cto_rb)
        input_layout.addWidget(self.cto_rb)

        self.s37_41_rb = QRadioButton("S37/41")
        self.s37_41_rb.toggled.connect(self._on_legal_toggled)
        self.legal_btn_group.addButton(self.s37_41_rb)
        input_layout.addWidget(self.s37_41_rb)

        # DoLs checkbox with dropdown
        self.dols_cb = QCheckBox("DoLs")
        self.dols_cb.toggled.connect(self._on_dols_toggled)
        input_layout.addWidget(self.dols_cb)

        self.dols_container = QWidget()
        dols_layout = QHBoxLayout(self.dols_container)
        dols_layout.setContentsMargins(20, 0, 0, 0)
        dols_layout.setSpacing(8)

        self.dols_dropdown = QComboBox()
        self.dols_dropdown.addItems(["Select...", "Residence", "Leave", "Both"])
        self.dols_dropdown.setStyleSheet("""
            QComboBox {
                padding: 6px;
                font-size: 17px;
                background: white;
                border: 1px solid #d1d5db;
                border-radius: 6px;
            }
            QComboBox QAbstractItemView {
                min-width: 400px;
            }
        """)
        self.dols_dropdown.currentIndexChanged.connect(self._send_to_card)
        dols_layout.addWidget(self.dols_dropdown)
        dols_layout.addStretch()

        self.dols_container.hide()
        input_layout.addWidget(self.dols_container)

        # SHPO checkbox
        self.shpo_cb = QCheckBox("SHPO (Sexual Harm Prevention Order)")
        self.shpo_cb.toggled.connect(self._send_to_card)
        input_layout.addWidget(self.shpo_cb)

        # ============ COMMUNITY TEAM SECTION ============
        input_layout.addSpacing(8)
        team_lbl = QLabel("Community Team")
        team_lbl.setStyleSheet("font-size: 18px; font-weight: 700; color: #374151; margin-top: 4px;")
        input_layout.addWidget(team_lbl)

        # CMHT checkbox
        self.cmht_cb = QCheckBox("CMHT (Community Mental Health Team)")
        self.cmht_cb.toggled.connect(self._send_to_card)
        input_layout.addWidget(self.cmht_cb)

        # Treatment plan checkbox
        self.treatment_plan_cb = QCheckBox("Treatment Plan")
        self.treatment_plan_cb.toggled.connect(self._send_to_card)
        input_layout.addWidget(self.treatment_plan_cb)

        # ============ ACCOMMODATION SECTION ============
        input_layout.addSpacing(8)
        accom_lbl = QLabel("Accommodation")
        accom_lbl.setStyleSheet("font-size: 18px; font-weight: 700; color: #374151; margin-top: 4px;")
        input_layout.addWidget(accom_lbl)

        self.accom_btn_group = QButtonGroup(self)

        self.accom_24hr_rb = QRadioButton("24 hour supported")
        self.accom_24hr_rb.toggled.connect(self._on_accom_toggled)
        self.accom_btn_group.addButton(self.accom_24hr_rb, 0)
        input_layout.addWidget(self.accom_24hr_rb)

        self.accom_9to5_rb = QRadioButton("9-5 supported")
        self.accom_9to5_rb.toggled.connect(self._on_accom_toggled)
        self.accom_btn_group.addButton(self.accom_9to5_rb, 1)
        input_layout.addWidget(self.accom_9to5_rb)

        self.accom_independent_rb = QRadioButton("Independent")
        self.accom_independent_rb.toggled.connect(self._on_accom_toggled)
        self.accom_btn_group.addButton(self.accom_independent_rb, 2)
        input_layout.addWidget(self.accom_independent_rb)

        # Floating support container (shown when independent selected)
        self.floating_container = QWidget()
        floating_layout = QVBoxLayout(self.floating_container)
        floating_layout.setContentsMargins(20, 4, 0, 0)
        floating_layout.setSpacing(4)

        self.floating_cb = QCheckBox("Floating support")
        self.floating_cb.toggled.connect(self._on_floating_toggled)
        floating_layout.addWidget(self.floating_cb)

        self.floating_dropdown_container = QWidget()
        fd_layout = QHBoxLayout(self.floating_dropdown_container)
        fd_layout.setContentsMargins(20, 0, 0, 0)

        self.floating_dropdown = QComboBox()
        self.floating_dropdown.addItems(self.FLOATING_SUPPORT_OPTIONS)
        self.floating_dropdown.setStyleSheet("""
            QComboBox {
                padding: 6px;
                font-size: 17px;
                background: white;
                border: 1px solid #d1d5db;
                border-radius: 6px;
            }
            QComboBox QAbstractItemView {
                min-width: 400px;
            }
        """)
        self.floating_dropdown.currentIndexChanged.connect(self._send_to_card)
        fd_layout.addWidget(self.floating_dropdown)
        fd_layout.addStretch()

        self.floating_dropdown_container.hide()
        floating_layout.addWidget(self.floating_dropdown_container)

        self.floating_container.hide()
        input_layout.addWidget(self.floating_container)

        self.accom_family_rb = QRadioButton("Family")
        self.accom_family_rb.toggled.connect(self._on_accom_toggled)
        self.accom_btn_group.addButton(self.accom_family_rb, 3)
        input_layout.addWidget(self.accom_family_rb)

        self.input_section.set_content(input_content)
        self.scroll_layout.addWidget(self.input_section)

        # Note: imported data will be added here by _add_imported_data_to_popup
        self.scroll_layout.addStretch()
        self.layout.addWidget(scroll, 1)

    def _on_legal_toggled(self, checked):
        """Ensure CTO and S37/41 are mutually exclusive."""
        sender = self.sender()
        if checked:
            if sender == self.cto_rb:
                self.s37_41_rb.setChecked(False)
            elif sender == self.s37_41_rb:
                self.cto_rb.setChecked(False)
        self._send_to_card()

    def _on_dols_toggled(self, checked):
        self.dols_container.setVisible(checked)
        if not checked:
            self.dols_dropdown.setCurrentIndex(0)
        self._send_to_card()

    def _on_accom_toggled(self, checked):
        # Show floating support options only for independent
        self.floating_container.setVisible(self.accom_independent_rb.isChecked())
        if not self.accom_independent_rb.isChecked():
            self.floating_cb.setChecked(False)
        self._send_to_card()

    def _on_floating_toggled(self, checked):
        self.floating_dropdown_container.setVisible(checked)
        if not checked:
            self.floating_dropdown.setCurrentIndex(0)
        self._send_to_card()

    def generate_text(self) -> str:
        p = self._get_pronouns()
        parts = []

        # Legal section
        if self.cto_rb.isChecked():
            parts.append("I believe for effective community management, a CTO would be necessary.")

        if self.s37_41_rb.isChecked():
            parts.append("I believe ongoing S37/41 would be necessary for community management.")

        if self.dols_cb.isChecked():
            dols_type = self.dols_dropdown.currentText()
            if dols_type == "Residence":
                parts.append(f"I believe a DoLS is necessary in the community as {p['subj'].lower()} lacks capacity for residence decisions.")
            elif dols_type == "Leave":
                parts.append(f"{p['subj']} {p['is']} currently on escorted leave and a discharge on DoLS would be needed to maintain this in the community and to protect against risk of deterioration of mental state.")
            elif dols_type == "Both":
                parts.append(f"{p['subj']} requires a DoLs for both residence and leave due to a lack of capacity around both these issues, and the need to maintain {p['pos_lower']} mental state with this safeguard.")

        if self.shpo_cb.isChecked():
            parts.append(f"{p['subj']} {p['is']} currently subject to a sexual harm prevention order and this would be an important risk management option in the community, working closely with the offender manager.")

        # Community team section
        if self.cmht_cb.isChecked():
            parts.append("Involvement with a community team would be essential for effective management on discharge.")

        if self.treatment_plan_cb.isChecked():
            parts.append(f"{p['pos']} treatment plan in the community would include maintenance of medication, engagement with community psychological work, occupational therapy input and care-coordinator input following the CPA process.")

        # Accommodation section
        if self.accom_24hr_rb.isChecked():
            parts.append(f"With respect to community residence, I believe {p['subj'].lower()} would require 24 hour supported accommodation with input from staff to monitor {p['pos_lower']} mental state and compliance.")
        elif self.accom_9to5_rb.isChecked():
            parts.append(f"With respect to community residence, I believe {p['subj'].lower()} would require 9-5 supported accommodation with input from staff to monitor {p['pos_lower']} mental state and compliance.")
        elif self.accom_independent_rb.isChecked():
            parts.append(f"With respect to community residence, I believe {p['subj'].lower()} {p['is']} able to move into independent accommodation.")
            if self.floating_cb.isChecked():
                freq = self.floating_dropdown.currentText()
                if freq and freq != "Select frequency...":
                    parts.append(f"{p['subj']} would require floating support {freq.lower()}.")
        elif self.accom_family_rb.isChecked():
            parts.append(f"With respect to community residence, I believe {p['subj'].lower()} would return to live with family.")

        return " ".join(parts)

    def get_state(self) -> dict:
        accom = None
        if self.accom_24hr_rb.isChecked():
            accom = "24hr"
        elif self.accom_9to5_rb.isChecked():
            accom = "9to5"
        elif self.accom_independent_rb.isChecked():
            accom = "independent"
        elif self.accom_family_rb.isChecked():
            accom = "family"

        return {
            "cto": self.cto_rb.isChecked(),
            "s37_41": self.s37_41_rb.isChecked(),
            "dols": self.dols_cb.isChecked(),
            "dols_type": self.dols_dropdown.currentText(),
            "shpo": self.shpo_cb.isChecked(),
            "cmht": self.cmht_cb.isChecked(),
            "treatment_plan": self.treatment_plan_cb.isChecked(),
            "accommodation": accom,
            "floating_support": self.floating_cb.isChecked(),
            "floating_frequency": self.floating_dropdown.currentText(),
        }

    def restore_state(self, state: dict):
        if not state:
            return

        self.cto_rb.setChecked(state.get("cto", False))
        self.s37_41_rb.setChecked(state.get("s37_41", False))
        self.dols_cb.setChecked(state.get("dols", False))

        dols_type = state.get("dols_type", "")
        idx = self.dols_dropdown.findText(dols_type)
        if idx >= 0:
            self.dols_dropdown.setCurrentIndex(idx)

        self.shpo_cb.setChecked(state.get("shpo", False))
        self.cmht_cb.setChecked(state.get("cmht", False))
        self.treatment_plan_cb.setChecked(state.get("treatment_plan", False))

        accom = state.get("accommodation")
        if accom == "24hr":
            self.accom_24hr_rb.setChecked(True)
        elif accom == "9to5":
            self.accom_9to5_rb.setChecked(True)
        elif accom == "independent":
            self.accom_independent_rb.setChecked(True)
        elif accom == "family":
            self.accom_family_rb.setChecked(True)

        self.floating_cb.setChecked(state.get("floating_support", False))

        freq = state.get("floating_frequency", "")
        idx = self.floating_dropdown.findText(freq)
        if idx >= 0:
            self.floating_dropdown.setCurrentIndex(idx)

        self._send_to_card()


# ================================================================
# DISCHARGE RISK POPUP (Section 21)
# ================================================================

class DischargeRiskPopup(TribunalPopupBase):
    """Popup for Risk if discharged from hospital section."""

    def __init__(self, parent=None, gender=None):
        super().__init__("Risk if Discharged", parent)
        self.gender = gender or "neutral"
        self._setup_ui()

    def _get_pronouns(self):
        g = (self.gender or "").lower().strip()
        if g == "male":
            return {"subj": "He", "obj": "him", "pos": "His", "pos_lower": "his", "is": "is", "was": "was", "were": "were", "has": "has"}
        elif g == "female":
            return {"subj": "She", "obj": "her", "pos": "Her", "pos_lower": "her", "is": "is", "was": "was", "were": "were", "has": "has"}
        return {"subj": "They", "obj": "them", "pos": "Their", "pos_lower": "their", "is": "are", "was": "were", "were": "were", "has": "have"}

    def set_gender(self, gender: str):
        self.gender = gender
        self._send_to_card()

    def _setup_ui(self):
        from PySide6.QtWidgets import QCheckBox, QScrollArea, QSlider

        # ========================================================
        # SECTION 1: PREVIEW (fixed at top)
        # ========================================================
        preview_container = QWidget()
        preview_container.setStyleSheet("""
            QWidget { background: rgba(255,255,255,0.96); border: 1px solid rgba(0,0,0,0.15); border-radius: 12px; }
        """)
        preview_layout = QVBoxLayout(preview_container)
        preview_layout.setContentsMargins(12, 10, 12, 10)
        preview_layout.setSpacing(8)

        preview_header = QHBoxLayout()
        title_lbl = QLabel("Preview")
        title_lbl.setStyleSheet("font-size: 18px; font-weight: 600; color: #374151;")
        preview_header.addWidget(title_lbl)
        preview_header.addStretch()
        preview_layout.addLayout(preview_header)

        preview_scroll = QScrollArea()
        preview_scroll.setWidgetResizable(True)
        preview_scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        preview_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        preview_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        preview_scroll.setMinimumHeight(100)
        preview_scroll.setMaximumHeight(150)
        preview_scroll.setStyleSheet("QScrollArea { background: #1c1c1c; border-radius: 8px; }")

        self.preview_label = QLabel("Select discharge risks...")
        self.preview_label.setWordWrap(True)
        self.preview_label.setAlignment(Qt.AlignmentFlag.AlignTop | Qt.AlignmentFlag.AlignLeft)
        self.preview_label.setStyleSheet("QLabel { background: #1c1c1c; color: #eaeaea; padding: 10px; font-size: 17px; }")
        preview_scroll.setWidget(self.preview_label)
        preview_layout.addWidget(preview_scroll)

        self.layout.addWidget(preview_container)

        # ========================================================
        # SECTION 2: SCROLLABLE CONTENT
        # ========================================================
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        scroll_content = QWidget()
        scroll_content.setObjectName("discharge_scroll_content")
        scroll_content.setStyleSheet("""
            QWidget#discharge_scroll_content {
                background: rgba(255,255,255,0.95);
                border-radius: 12px;
                border: 1px solid rgba(0,0,0,0.1);
            }
            QLabel, QRadioButton, QCheckBox {
                background: transparent;
                border: none;
            }
        """)
        self.scroll_layout = QVBoxLayout(scroll_content)
        self.scroll_layout.setContentsMargins(12, 12, 12, 12)
        self.scroll_layout.setSpacing(10)
        scroll.setWidget(scroll_content)

        # Section label
        risks_lbl = QLabel("Risk Factors if Discharged")
        risks_lbl.setStyleSheet("font-size: 18px; font-weight: 600; color: #374151;")
        self.scroll_layout.addWidget(risks_lbl)

        # Risk checkboxes with severity sliders
        self.risk_widgets = {}
        risk_types = [
            ("violence", "Violence to others"),
            ("self_harm", "Self-harm"),
            ("suicide", "Suicide"),
            ("self_neglect", "Self-neglect"),
            ("exploitation", "Exploitation by others"),
            ("substance", "Substance misuse relapse"),
            ("deterioration", "Mental health deterioration"),
            ("non_compliance", "Non-compliance with treatment"),
        ]

        for key, label in risk_types:
            container = QWidget()
            container_layout = QVBoxLayout(container)
            container_layout.setContentsMargins(0, 0, 0, 0)
            container_layout.setSpacing(4)

            cb = QCheckBox(label)
            cb.toggled.connect(self._send_to_card)
            container_layout.addWidget(cb)

            # Severity slider (hidden by default)
            slider_container = QWidget()
            slider_outer = QVBoxLayout(slider_container)
            slider_outer.setContentsMargins(20, 0, 0, 8)
            slider_outer.setSpacing(2)

            # Top row: label + slider
            slider_row = QHBoxLayout()
            slider_row.setSpacing(8)

            slider_lbl = QLabel("Severity:")
            slider_lbl.setStyleSheet("font-size: 16px; color: #6b7280;")
            slider_row.addWidget(slider_lbl)

            slider = NoWheelSlider(Qt.Orientation.Horizontal)
            slider.setMinimum(1)
            slider.setMaximum(3)
            slider.setValue(2)
            slider.setTickPosition(QSlider.TickPosition.TicksBelow)
            slider.setTickInterval(1)
            slider.setFixedWidth(120)
            slider.valueChanged.connect(self._send_to_card)
            slider_row.addWidget(slider)
            slider_row.addStretch()

            slider_outer.addLayout(slider_row)

            # Bottom row: level label (below slider)
            level_lbl = QLabel("Medium")
            level_lbl.setStyleSheet("font-size: 16px; color: #374151; font-weight: 500; margin-left: 52px;")
            slider.valueChanged.connect(lambda v, l=level_lbl: l.setText(["Low", "Medium", "High"][v-1]))
            slider_outer.addWidget(level_lbl)

            slider_container.hide()
            container_layout.addWidget(slider_container)

            cb.toggled.connect(lambda checked, sc=slider_container: sc.setVisible(checked))

            self.scroll_layout.addWidget(container)

            self.risk_widgets[key] = {
                "checkbox": cb,
                "slider": slider,
                "slider_container": slider_container,
                "level_label": level_lbl
            }

        self.scroll_layout.addStretch()
        self.layout.addWidget(scroll, 1)

    def _build_discharge_risk_narrative(self, risks: list) -> str:
        """Build a narrative sentence from a list of (risk_name, severity_value) tuples."""
        if not risks:
            return ""

        # Sort by severity (high=3 first, then moderate=2, then low=1)
        sorted_risks = sorted(risks, key=lambda x: x[1], reverse=True)

        # Group by severity
        high_risks = [r[0] for r in sorted_risks if r[1] == 3]
        moderate_risks = [r[0] for r in sorted_risks if r[1] == 2]
        low_risks = [r[0] for r in sorted_risks if r[1] == 1]

        parts = []

        def join_risks(risk_list):
            if len(risk_list) == 1:
                return risk_list[0]
            elif len(risk_list) == 2:
                return f"{risk_list[0]} and {risk_list[1]}"
            else:
                return ", ".join(risk_list[:-1]) + f", and {risk_list[-1]}"

        if high_risks:
            if len(high_risks) == 1:
                parts.append(f"risk of {high_risks[0]} is high")
            else:
                parts.append(f"risks of {join_risks(high_risks)} are high")

        if moderate_risks:
            if len(moderate_risks) == 1:
                if parts:
                    parts.append(f"{moderate_risks[0]} is moderate")
                else:
                    parts.append(f"risk of {moderate_risks[0]} is moderate")
            else:
                if parts:
                    parts.append(f"{join_risks(moderate_risks)} are moderate")
                else:
                    parts.append(f"risks of {join_risks(moderate_risks)} are moderate")

        if low_risks:
            if len(low_risks) == 1:
                if parts:
                    parts.append(f"{low_risks[0]} is low")
                else:
                    parts.append(f"risk of {low_risks[0]} is low")
            else:
                if parts:
                    parts.append(f"{join_risks(low_risks)} are low")
                else:
                    parts.append(f"risks of {join_risks(low_risks)} are low")

        if len(parts) == 1:
            return f"the {parts[0]}"
        elif len(parts) == 2:
            return f"the {parts[0]}, and {parts[1]}"
        else:
            return f"the {parts[0]}, {parts[1]}, and {parts[2]}"

    def generate_text(self) -> str:
        p = self._get_pronouns()

        # Collect (risk_name, severity_value) tuples
        risks = []
        for key, widgets in self.risk_widgets.items():
            if widgets["checkbox"].isChecked():
                risk_name = widgets["checkbox"].text().lower()
                severity_val = widgets["slider"].value()
                risks.append((risk_name, severity_val))

        if risks:
            narrative = self._build_discharge_risk_narrative(risks)
            return f"If {p['subj'].lower()} {p['was']} to be discharged at this time, {narrative}."
        return ""

    def get_state(self) -> dict:
        state = {}
        for key, widgets in self.risk_widgets.items():
            state[key] = {
                "checked": widgets["checkbox"].isChecked(),
                "severity": widgets["slider"].value()
            }
        return state

    def restore_state(self, state: dict):
        if not state:
            return

        for key, data in state.items():
            if key in self.risk_widgets:
                self.risk_widgets[key]["checkbox"].setChecked(data.get("checked", False))
                self.risk_widgets[key]["slider"].setValue(data.get("severity", 2))

        self._send_to_card()


# ================================================================
# RECOMMENDATIONS POPUP (Section 23)
# ================================================================

class RecommendationsPopup(TribunalPopupBase):
    """Popup for Recommendations to tribunal section."""

    def __init__(self, parent=None, gender=None):
        super().__init__("Recommendations to Tribunal", parent)
        self.gender = gender or "neutral"
        self._setup_ui()

    def _get_pronouns(self):
        g = (self.gender or "").lower().strip()
        if g == "male":
            return {"subj": "He", "obj": "him", "pos": "his", "is": "is", "be": "be"}
        elif g == "female":
            return {"subj": "She", "obj": "her", "pos": "her", "is": "is", "be": "be"}
        return {"subj": "They", "obj": "them", "pos": "their", "is": "are", "be": "be"}

    def set_gender(self, gender: str):
        self.gender = gender
        self._send_to_card()

    def _setup_ui(self):
        from PySide6.QtWidgets import QRadioButton, QButtonGroup, QScrollArea

        # ========================================================
        # SECTION 1: PREVIEW (fixed at top)
        # ========================================================
        preview_container = QWidget()
        preview_container.setStyleSheet("""
            QWidget { background: rgba(255,255,255,0.96); border: 1px solid rgba(0,0,0,0.15); border-radius: 12px; }
        """)
        preview_layout = QVBoxLayout(preview_container)
        preview_layout.setContentsMargins(12, 10, 12, 10)
        preview_layout.setSpacing(8)

        preview_header = QHBoxLayout()
        title_lbl = QLabel("Preview")
        title_lbl.setStyleSheet("font-size: 18px; font-weight: 600; color: #374151;")
        preview_header.addWidget(title_lbl)
        preview_header.addStretch()
        preview_layout.addLayout(preview_header)

        preview_scroll = QScrollArea()
        preview_scroll.setWidgetResizable(True)
        preview_scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        preview_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        preview_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        preview_scroll.setMinimumHeight(100)
        preview_scroll.setMaximumHeight(150)
        preview_scroll.setStyleSheet("QScrollArea { background: #1c1c1c; border-radius: 8px; }")

        self.preview_label = QLabel("Select your recommendation...")
        self.preview_label.setWordWrap(True)
        self.preview_label.setAlignment(Qt.AlignmentFlag.AlignTop | Qt.AlignmentFlag.AlignLeft)
        self.preview_label.setStyleSheet("QLabel { background: #1c1c1c; color: #eaeaea; padding: 10px; font-size: 17px; }")
        preview_scroll.setWidget(self.preview_label)
        preview_layout.addWidget(preview_scroll)

        self.layout.addWidget(preview_container)

        # ========================================================
        # SECTION 2: SCROLLABLE CONTENT
        # ========================================================
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        scroll_content = QWidget()
        scroll_content.setObjectName("recommendations_scroll_content")
        scroll_content.setStyleSheet("""
            QWidget#recommendations_scroll_content {
                background: rgba(255,255,255,0.95);
                border-radius: 12px;
                border: 1px solid rgba(0,0,0,0.1);
            }
            QLabel, QRadioButton, QCheckBox {
                background: transparent;
                border: none;
            }
        """)
        self.scroll_layout = QVBoxLayout(scroll_content)
        self.scroll_layout.setContentsMargins(12, 12, 12, 12)
        self.scroll_layout.setSpacing(10)
        scroll.setWidget(scroll_content)

        # Section label
        rec_lbl = QLabel("Recommendation")
        rec_lbl.setStyleSheet("font-size: 18px; font-weight: 600; color: #374151;")
        self.scroll_layout.addWidget(rec_lbl)

        # Recommendation options
        self.rec_btn_group = QButtonGroup(self)

        self.detention_rb = QRadioButton("Continue detention")
        self.detention_rb.setStyleSheet("""
            QRadioButton {
                font-size: 22px;
                background: transparent;
            }
            QRadioButton::indicator {
                width: 18px;
                height: 18px;
            }
        """)
        self.detention_rb.setChecked(True)
        self.detention_rb.toggled.connect(self._send_to_card)
        self.rec_btn_group.addButton(self.detention_rb, 0)
        self.scroll_layout.addWidget(self.detention_rb)

        self.discharge_rb = QRadioButton("Discharge")
        self.discharge_rb.setStyleSheet("""
            QRadioButton {
                font-size: 22px;
                background: transparent;
            }
            QRadioButton::indicator {
                width: 18px;
                height: 18px;
            }
        """)
        self.discharge_rb.toggled.connect(self._send_to_card)
        self.rec_btn_group.addButton(self.discharge_rb, 1)
        self.scroll_layout.addWidget(self.discharge_rb)

        self.conditional_rb = QRadioButton("Conditional discharge")
        self.conditional_rb.setStyleSheet("""
            QRadioButton {
                font-size: 22px;
                background: transparent;
            }
            QRadioButton::indicator {
                width: 18px;
                height: 18px;
            }
        """)
        self.conditional_rb.toggled.connect(self._send_to_card)
        self.rec_btn_group.addButton(self.conditional_rb, 2)
        self.scroll_layout.addWidget(self.conditional_rb)

        self.deferred_rb = QRadioButton("Deferred conditional discharge")
        self.deferred_rb.setStyleSheet("""
            QRadioButton {
                font-size: 22px;
                background: transparent;
            }
            QRadioButton::indicator {
                width: 18px;
                height: 18px;
            }
        """)
        self.deferred_rb.toggled.connect(self._send_to_card)
        self.rec_btn_group.addButton(self.deferred_rb, 3)
        self.scroll_layout.addWidget(self.deferred_rb)

        # Additional comments
        self.scroll_layout.addSpacing(10)
        comments_lbl = QLabel("Additional Comments (optional)")
        comments_lbl.setStyleSheet("font-size: 17px; font-weight: 600; color: #6b7280;")
        self.scroll_layout.addWidget(comments_lbl)

        self.comments_field = QTextEdit()
        self.comments_field.setPlaceholderText("Any additional comments for the tribunal...")
        self.comments_field.setMaximumHeight(80)
        self.comments_field.textChanged.connect(self._send_to_card)
        self.scroll_layout.addWidget(self.comments_field)

        # Note: imported data will be added here by _add_imported_data_to_popup
        self.scroll_layout.addStretch()
        self.layout.addWidget(scroll, 1)

    def generate_text(self) -> str:
        p = self._get_pronouns()
        parts = []

        if self.detention_rb.isChecked():
            parts.append(f"I recommend that {p['pos']} detention continues.")
        elif self.discharge_rb.isChecked():
            parts.append(f"I recommend that {p['subj'].lower()} {p['be']} discharged.")
        elif self.conditional_rb.isChecked():
            parts.append(f"I recommend a conditional discharge.")
        elif self.deferred_rb.isChecked():
            parts.append(f"I recommend a deferred conditional discharge.")

        comments = self.comments_field.toPlainText().strip()
        if comments:
            parts.append(comments)

        return " ".join(parts)

    def get_state(self) -> dict:
        rec = "detention"
        if self.discharge_rb.isChecked():
            rec = "discharge"
        elif self.conditional_rb.isChecked():
            rec = "conditional"
        elif self.deferred_rb.isChecked():
            rec = "deferred"

        return {
            "recommendation": rec,
            "comments": self.comments_field.toPlainText()
        }

    def restore_state(self, state: dict):
        if not state:
            return

        rec = state.get("recommendation", "detention")
        if rec == "detention":
            self.detention_rb.setChecked(True)
        elif rec == "discharge":
            self.discharge_rb.setChecked(True)
        elif rec == "conditional":
            self.conditional_rb.setChecked(True)
        elif rec == "deferred":
            self.deferred_rb.setChecked(True)

        self.comments_field.setPlainText(state.get("comments", ""))
        self._send_to_card()


# ================================================================
# SIGNATURE POPUP (Section 24)
# ================================================================

class SignaturePopup(TribunalPopupBase):
    """Popup for Signature section."""

    def __init__(self, parent=None, my_details=None):
        super().__init__("Signature", parent)
        self.my_details = my_details or {}
        self._setup_ui()
        self._prefill_from_mydetails()

    def _prefill_from_mydetails(self):
        """Pre-fill fields from MyDetails data."""
        if not self.my_details:
            return

        # Pre-fill name
        if self.my_details.get("full_name"):
            self.name_field.setText(self.my_details["full_name"])

        # Pre-fill designation (role_title)
        if self.my_details.get("role_title"):
            self.designation_field.setText(self.my_details["role_title"])

        # Pre-fill qualifications (discipline)
        if self.my_details.get("discipline"):
            self.qualifications_field.setText(self.my_details["discipline"])

        # Pre-fill GMC (registration_number)
        if self.my_details.get("registration_number"):
            self.gmc_field.setText(self.my_details["registration_number"])

        self._send_to_card()

    def _setup_ui(self):
        from PySide6.QtWidgets import QScrollArea

        # ========================================================
        # SECTION 1: SCROLLABLE CONTENT
        # ========================================================
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        scroll_content = QWidget()
        scroll_content.setObjectName("signature_scroll_content")
        scroll_content.setStyleSheet("""
            QWidget#signature_scroll_content {
                background: rgba(255,255,255,0.95);
                border-radius: 12px;
                border: 1px solid rgba(0,0,0,0.1);
            }
            QLabel, QRadioButton, QCheckBox {
                background: transparent;
                border: none;
            }
        """)
        scroll_layout = QVBoxLayout(scroll_content)
        scroll_layout.setContentsMargins(12, 12, 12, 12)
        scroll_layout.setSpacing(10)
        scroll.setWidget(scroll_content)

        # Name
        name_lbl = QLabel("Name")
        name_lbl.setStyleSheet("font-size: 17px; font-weight: 600; color: #374151;")
        scroll_layout.addWidget(name_lbl)

        self.name_field = QLineEdit()
        self.name_field.setPlaceholderText("Enter your full name")
        self.name_field.textChanged.connect(self._send_to_card)
        scroll_layout.addWidget(self.name_field)

        # Designation
        designation_lbl = QLabel("Designation")
        designation_lbl.setStyleSheet("font-size: 17px; font-weight: 600; color: #374151;")
        scroll_layout.addWidget(designation_lbl)

        self.designation_field = QLineEdit()
        self.designation_field.setPlaceholderText("e.g. Consultant Psychiatrist, Responsible Clinician")
        self.designation_field.textChanged.connect(self._send_to_card)
        scroll_layout.addWidget(self.designation_field)

        # Qualifications
        qualifications_lbl = QLabel("Qualifications")
        qualifications_lbl.setStyleSheet("font-size: 17px; font-weight: 600; color: #374151;")
        scroll_layout.addWidget(qualifications_lbl)

        self.qualifications_field = QLineEdit()
        self.qualifications_field.setPlaceholderText("e.g. MBChB, MRCPsych, MD")
        self.qualifications_field.textChanged.connect(self._send_to_card)
        scroll_layout.addWidget(self.qualifications_field)

        # GMC/Professional Registration
        gmc_lbl = QLabel("GMC/Professional Registration Number")
        gmc_lbl.setStyleSheet("font-size: 17px; font-weight: 600; color: #374151;")
        scroll_layout.addWidget(gmc_lbl)

        self.gmc_field = QLineEdit()
        self.gmc_field.setPlaceholderText("Enter registration number")
        self.gmc_field.textChanged.connect(self._send_to_card)
        scroll_layout.addWidget(self.gmc_field)

        # Date
        date_lbl = QLabel("Date")
        date_lbl.setStyleSheet("font-size: 17px; font-weight: 600; color: #374151;")
        scroll_layout.addWidget(date_lbl)

        self.date_field = QDateEdit()
        self.date_field.setDisplayFormat("dd/MM/yyyy")
        self.date_field.setCalendarPopup(True)
        self.date_field.setDate(QDate.currentDate())
        self._style_calendar(self.date_field)
        self.date_field.dateChanged.connect(self._send_to_card)
        scroll_layout.addWidget(self.date_field)

        scroll_layout.addStretch()
        self.layout.addWidget(scroll, 1)

        # Initial send to card
        self._send_to_card()

    def generate_text(self) -> str:
        lines = []

        name = self.name_field.text().strip()
        if name:
            lines.append(f"Signed: {name}")

        designation = self.designation_field.text().strip()
        if designation:
            lines.append(f"Designation: {designation}")

        qualifications = self.qualifications_field.text().strip()
        if qualifications:
            lines.append(f"Qualifications: {qualifications}")

        gmc = self.gmc_field.text().strip()
        if gmc:
            lines.append(f"Registration: {gmc}")

        date = self.date_field.date().toString("dd MMMM yyyy")
        lines.append(f"Date: {date}")

        return "\n".join(lines)

    def get_state(self) -> dict:
        return {
            "name": self.name_field.text(),
            "designation": self.designation_field.text(),
            "qualifications": self.qualifications_field.text(),
            "gmc": self.gmc_field.text(),
            "date": self.date_field.date().toString("yyyy-MM-dd")
        }

    def restore_state(self, state: dict):
        if not state:
            return

        self.name_field.setText(state.get("name", ""))
        self.designation_field.setText(state.get("designation", ""))
        self.qualifications_field.setText(state.get("qualifications", ""))
        self.gmc_field.setText(state.get("gmc", ""))

        date_str = state.get("date", "")
        if date_str:
            self.date_field.setDate(QDate.fromString(date_str, "yyyy-MM-dd"))

        self._send_to_card()


# ================================================================
# TRIBUNAL PSYCH HISTORY POPUP (matches GPR Section 6 exactly)
# ================================================================

class TribunalPsychHistoryPopup(QWidget):
    """Popup for past psychiatric history with admissions table input and extracted notes.
    Sends directly to card on click.
    """

    sent = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        self._entries = []
        self._extracted_checkboxes = []
        self._setup_ui()

    def _setup_ui(self):
        from background_history_popup import CollapsibleSection

        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        # Main scroll area
        main_scroll = QScrollArea()
        main_scroll.setWidgetResizable(True)
        main_scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        main_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        main_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        main_container = QWidget()
        self.main_layout = QVBoxLayout(main_container)
        self.main_layout.setContentsMargins(4, 4, 4, 4)
        self.main_layout.setSpacing(8)

        # ====================================================
        # SECTION 1: DETECTED ADMISSIONS (table only)
        # ====================================================
        self.detected_section = CollapsibleSection("Detected Admissions", start_collapsed=True)
        self.detected_section.set_content_height(180)
        self.detected_section._min_height = 80
        self.detected_section._max_height = 400
        self.detected_section.set_header_style("""
            QFrame {
                background: rgba(37, 99, 235, 0.15);
                border: 1px solid rgba(37, 99, 235, 0.3);
                border-radius: 6px 6px 0 0;
            }
        """)
        self.detected_section.set_title_style("""
            QLabel {
                font-size: 18px;
                font-weight: 600;
                color: #1d4ed8;
                background: transparent;
                border: none;
            }
        """)

        detected_content = QWidget()
        detected_content.setStyleSheet("""
            QWidget {
                background: rgba(239, 246, 255, 0.95);
                border: 1px solid rgba(37, 99, 235, 0.3);
                border-top: none;
                border-radius: 0 0 12px 12px;
            }
        """)

        detected_layout = QVBoxLayout(detected_content)
        detected_layout.setContentsMargins(12, 12, 12, 12)
        detected_layout.setSpacing(8)

        # Detected admissions table (read-only, auto-populated)
        self.detected_table = QTableWidget(0, 3)
        self.detected_table.setHorizontalHeaderLabels(["Admission Date", "Discharge Date", "Duration"])
        self.detected_table.horizontalHeader().setSectionResizeMode(QHeaderView.ResizeMode.Stretch)
        self.detected_table.setMinimumHeight(60)
        self.detected_table.setEditTriggers(QTableWidget.EditTrigger.NoEditTriggers)
        self.detected_table.setStyleSheet("""
            QTableWidget {
                background: white;
                border: 1px solid #93c5fd;
                border-radius: 4px;
            }
            QHeaderView::section {
                background: #dbeafe;
                padding: 6px;
                border: none;
                border-bottom: 1px solid #93c5fd;
                font-weight: 600;
                color: #1e40af;
            }
        """)
        detected_layout.addWidget(self.detected_table)

        # Export to Preview container
        export_container = QFrame()
        export_container.setStyleSheet("""
            QFrame {
                background: rgba(219, 234, 254, 0.6);
                border: 1px solid #93c5fd;
                border-radius: 6px;
            }
        """)
        export_layout = QHBoxLayout(export_container)
        export_layout.setContentsMargins(8, 4, 8, 4)

        self.export_table_cb = QCheckBox("Include Table in Report")
        self.export_table_cb.setStyleSheet("""
            QCheckBox {
                font-size: 16px;
                font-weight: 600;
                color: #1e40af;
                background: transparent;
            }
            QCheckBox::indicator {
                width: 14px;
                height: 14px;
            }
        """)
        self.export_table_cb.stateChanged.connect(self._send_to_card)
        export_layout.addWidget(self.export_table_cb)
        export_layout.addStretch()

        detected_layout.addWidget(export_container)

        self.detected_section.set_content(detected_content)
        self.detected_section.setVisible(False)  # Hidden until data loaded
        self.main_layout.addWidget(self.detected_section)

        # ====================================================
        # SECTION 2B: ADMISSION CLERKING NOTES (separate section)
        # ====================================================
        self.clerking_section = CollapsibleSection("Admission Clerking Notes", start_collapsed=True)
        self.clerking_section.set_content_height(250)
        self.clerking_section._min_height = 100
        self.clerking_section._max_height = 500
        self.clerking_section.set_header_style("""
            QFrame {
                background: rgba(37, 99, 235, 0.15);
                border: 1px solid rgba(37, 99, 235, 0.3);
                border-radius: 6px 6px 0 0;
            }
        """)
        self.clerking_section.set_title_style("""
            QLabel {
                font-size: 18px;
                font-weight: 600;
                color: #1d4ed8;
                background: transparent;
                border: none;
            }
        """)

        clerking_content = QWidget()
        clerking_content.setStyleSheet("""
            QWidget {
                background: rgba(239, 246, 255, 0.95);
                border: 1px solid rgba(37, 99, 235, 0.3);
                border-top: none;
                border-radius: 0 0 12px 12px;
            }
        """)

        clerking_content_layout = QVBoxLayout(clerking_content)
        clerking_content_layout.setContentsMargins(12, 12, 12, 12)
        clerking_content_layout.setSpacing(8)

        # Scrollable container for clerking entries
        clerking_scroll = QScrollArea()
        clerking_scroll.setWidgetResizable(True)
        clerking_scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        clerking_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        clerking_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        clerking_scroll.setStyleSheet("""
            QScrollArea { background: transparent; border: none; }
            QScrollArea > QWidget > QWidget { background: transparent; }
        """)

        self.clerking_container = QWidget()
        self.clerking_container.setStyleSheet("background: transparent;")
        self.clerking_entries_layout = QVBoxLayout(self.clerking_container)
        self.clerking_entries_layout.setContentsMargins(2, 2, 2, 2)
        self.clerking_entries_layout.setSpacing(8)
        self.clerking_entries_layout.setAlignment(Qt.AlignmentFlag.AlignTop)

        clerking_scroll.setWidget(self.clerking_container)
        clerking_content_layout.addWidget(clerking_scroll)

        # Store clerking checkboxes for preview updates
        self._clerking_checkboxes = []

        self.clerking_section.set_content(clerking_content)
        self.clerking_section.setVisible(False)  # Hidden until data loaded
        self.main_layout.addWidget(self.clerking_section)

        # ====================================================
        # SECTION 3: IMPORTED DATA (collapsible)
        # ====================================================
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
                font-size: 18px;
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
                font-size: 17px;
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
        self.extracted_checkboxes_layout.setAlignment(Qt.AlignmentFlag.AlignTop)

        extracted_scroll.setWidget(self.extracted_container)
        extracted_layout.addWidget(extracted_scroll)

        self.extracted_section.set_content(extracted_content)
        self.extracted_section.setVisible(False)
        self.main_layout.addWidget(self.extracted_section)

        self.main_layout.addStretch()
        main_scroll.setWidget(main_container)
        root.addWidget(main_scroll)

    def _send_to_card(self):
        """Send checked items directly to card (replaces card content)."""
        table_parts = []
        clerking_parts = []
        extracted_parts = []

        # Export table if checkbox is checked
        if hasattr(self, 'export_table_cb') and self.export_table_cb.isChecked():
            table_lines = []
            for row in range(self.detected_table.rowCount()):
                adm_date = self.detected_table.item(row, 0)
                dis_date = self.detected_table.item(row, 1)
                duration = self.detected_table.item(row, 2)

                adm_str = adm_date.text() if adm_date else ""
                dis_str = dis_date.text() if dis_date else ""
                dur_str = duration.text() if duration else ""

                if adm_str:
                    table_lines.append(f"Admission {row + 1}: {adm_str} - {dis_str} ({dur_str})")

            if table_lines:
                table_parts.append("HOSPITAL ADMISSIONS:\n" + "\n".join(table_lines))

        # Checked clerking entries
        for cb in self._clerking_checkboxes:
            if cb.isChecked():
                clerking_parts.append(cb.property("full_text"))

        # Checked extracted entries
        for cb in self._extracted_checkboxes:
            if cb.isChecked():
                extracted_parts.append(cb.property("full_text"))

        # Combine
        all_parts = []
        if table_parts:
            all_parts.extend(table_parts)
        if clerking_parts:
            all_parts.append("ADMISSION NOTES:\n" + "\n\n".join(clerking_parts))
        if extracted_parts:
            all_parts.append("FROM NOTES:\n" + "\n\n".join(extracted_parts))

        combined = "\n\n".join(all_parts) if all_parts else ""
        self.sent.emit(combined)

    def update_gender(self, gender: str):
        pass

    def set_entries(self, items: list, subtitle: str = ""):
        self._entries = items

        for cb in self._extracted_checkboxes:
            cb.deleteLater()
        self._extracted_checkboxes.clear()

        while self.extracted_checkboxes_layout.count():
            item = self.extracted_checkboxes_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        if isinstance(items, str):
            if items.strip():
                items = [{"date": None, "text": p.strip()} for p in items.split("\n\n") if p.strip()]
            else:
                items = []

        if items:
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

                if dt:
                    if hasattr(dt, "strftime"):
                        date_str = dt.strftime("%d %b %Y")
                    else:
                        date_str = str(dt)
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
                        font-size: 17px;
                        font-weight: bold;
                        color: #806000;
                    }
                    QPushButton:hover { background: rgba(180, 150, 50, 0.35); }
                """)
                header_row.addWidget(toggle_btn)

                date_label = QLabel(f"📅 {date_str}")
                date_label.setStyleSheet("""
                    QLabel {
                        font-size: 17px;
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
                cb.stateChanged.connect(self._send_to_card)
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
                        font-size: 17px;
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
            # Keep collapsed on open - user can expand manually
        else:
            self.extracted_section.setVisible(False)

    def set_notes(self, notes: list):
        """Analyze notes using timeline to detect admissions and find first clerking."""
        from timeline_builder import build_rio_timeline
        from datetime import timedelta
        from PySide6.QtWidgets import QTableWidgetItem

        print(f"[TRIBUNAL-PSYCH] set_notes called with {len(notes)} notes")

        if not notes:
            print("[TRIBUNAL-PSYCH] No notes - returning early")
            self.detected_section.setVisible(False)
            self.clerking_section.setVisible(False)
            return

        # Run timeline analysis
        try:
            print(f"[TRIBUNAL-PSYCH] Running timeline analysis...")
            episodes = build_rio_timeline(notes, debug=False)
            print(f"[TRIBUNAL-PSYCH] Timeline returned {len(episodes)} episodes")
        except Exception as e:
            print(f"[TRIBUNAL-PSYCH] Timeline error: {e}")
            import traceback
            traceback.print_exc()
            self.detected_section.setVisible(False)
            self.clerking_section.setVisible(False)
            return

        # Filter for inpatient admissions only
        admissions = [ep for ep in episodes if ep.get("type") == "inpatient"]
        print(f"[TRIBUNAL-PSYCH] Found {len(admissions)} inpatient admissions")

        if not admissions:
            print("[TRIBUNAL-PSYCH] No admissions - returning early")
            self.detected_section.setVisible(False)
            self.clerking_section.setVisible(False)
            return

        # Clear and populate detected admissions table
        self.detected_table.setRowCount(len(admissions))

        for row, adm in enumerate(admissions):
            start_date = adm.get("start")
            end_date = adm.get("end")

            # Format dates
            if start_date:
                start_str = start_date.strftime("%d %b %Y") if hasattr(start_date, "strftime") else str(start_date)
            else:
                start_str = "Unknown"

            if end_date:
                end_str = end_date.strftime("%d %b %Y") if hasattr(end_date, "strftime") else str(end_date)
            else:
                end_str = "Ongoing"

            # Calculate duration
            if start_date and end_date:
                try:
                    duration_days = (end_date - start_date).days
                    if duration_days < 7:
                        duration_str = f"{duration_days} days"
                    elif duration_days < 30:
                        weeks = round(duration_days / 7)
                        if weeks < 1:
                            weeks = 1
                        duration_str = f"{weeks} week{'s' if weeks > 1 else ''}"
                    else:
                        months = round(duration_days / 30)
                        if months < 1:
                            months = 1
                        duration_str = f"{months} month{'s' if months > 1 else ''}"
                except:
                    duration_str = "Unknown"
            else:
                duration_str = "Ongoing"

            # Add to table
            self.detected_table.setItem(row, 0, QTableWidgetItem(start_str))
            self.detected_table.setItem(row, 1, QTableWidgetItem(end_str))
            self.detected_table.setItem(row, 2, QTableWidgetItem(duration_str))

        # Find clerking/admission notes for each admission
        # Clear existing clerking entries
        for cb in self._clerking_checkboxes:
            cb.deleteLater()
        self._clerking_checkboxes.clear()

        while self.clerking_entries_layout.count():
            item = self.clerking_entries_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        # Admission entry keywords - looking for notes indicating admission to ward
        ADMISSION_KEYWORDS = [
            # Ward admission phrases
            "admission to ward", "admitted to ward", "admitted to the ward",
            "brought to ward", "brought to the ward", "brought into ward",
            "brought onto ward", "brought onto the ward",
            "arrived on ward", "arrived on the ward", "arrived to ward",
            "transferred to ward", "transferred to the ward",
            "escorted to ward", "escorted to the ward",
            # General admission phrases
            "on admission", "admission clerking", "clerking",
            "duty doctor admission", "admission note",
            "accepted to ward", "accepted onto ward",
            "admitted under", "accepted under",
            # Section/detention phrases often in admission notes
            "detained under", "sectioned", "section 2", "section 3",
            "136 suite", "sec 136", "section 136",
            # Nursing admission entries
            "nursing admission", "admission assessment",
            "initial assessment", "ward admission",
            "new admission", "patient admitted",
        ]

        clerking_notes = []
        seen_keys = set()

        # For each admission, find the first admission entry in 2-week window
        for adm in admissions:
            adm_start = adm.get("start")
            if not adm_start:
                continue

            # 2-week window from admission date
            window_end = adm_start + timedelta(days=14)

            # Sort notes by date to find the FIRST matching entry
            admission_window_notes = []
            for note in notes:
                note_date = note.get("date")
                if not note_date:
                    continue

                if hasattr(note_date, "date"):
                    note_date_obj = note_date.date()
                else:
                    note_date_obj = note_date

                if adm_start <= note_date_obj <= window_end:
                    admission_window_notes.append((note_date_obj, note))

            # Sort by date to get earliest first
            admission_window_notes.sort(key=lambda x: x[0])

            # Find first note with admission keywords
            found_admission_note = None
            for note_date_obj, note in admission_window_notes:
                text = (note.get("text", "") or note.get("content", "")).lower()

                if any(kw in text for kw in ADMISSION_KEYWORDS):
                    key = (note_date_obj, text[:100])
                    if key not in seen_keys:
                        seen_keys.add(key)
                        found_admission_note = {
                            "date": note.get("date"),
                            "text": note.get("text", "") or note.get("content", ""),
                            "admission_label": adm.get("label", "Admission")
                        }
                    break

            if found_admission_note:
                clerking_notes.append(found_admission_note)

        # Create collapsible entry boxes for each clerking note (blue UI)
        for clerking in clerking_notes:
            dt = clerking.get("date")
            text = clerking.get("text", "").strip()
            adm_label = clerking.get("admission_label", "")

            if not text:
                continue

            # Format date
            if dt:
                if hasattr(dt, "strftime"):
                    date_str = dt.strftime("%d %b %Y")
                else:
                    date_str = str(dt)
            else:
                date_str = "No date"

            # Create entry frame (blue style)
            entry_frame = QFrame()
            entry_frame.setObjectName("clerkingEntryFrame")
            entry_frame.setSizePolicy(QSizePolicy.Policy.Preferred, QSizePolicy.Policy.Minimum)
            entry_frame.setStyleSheet("""
                QFrame#clerkingEntryFrame {
                    background: rgba(255, 255, 255, 0.95);
                    border: 1px solid rgba(37, 99, 235, 0.4);
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

            # Toggle button on the LEFT
            toggle_btn = QPushButton("▸")
            toggle_btn.setFixedSize(22, 22)
            toggle_btn.setCursor(Qt.CursorShape.PointingHandCursor)
            toggle_btn.setStyleSheet("""
                QPushButton {
                    background: rgba(37, 99, 235, 0.2);
                    border: none;
                    border-radius: 4px;
                    font-size: 18px;
                    font-weight: bold;
                    color: #1e40af;
                }
                QPushButton:hover { background: rgba(37, 99, 235, 0.35); }
            """)
            header_row.addWidget(toggle_btn)

            # Admission label badge
            if adm_label:
                badge = QLabel(adm_label)
                badge.setStyleSheet("""
                    QLabel {
                        font-size: 14px;
                        font-weight: 600;
                        color: white;
                        background: #2563eb;
                        border: none;
                        border-radius: 3px;
                        padding: 2px 6px;
                    }
                """)
                header_row.addWidget(badge)

            # Date label
            date_label = QLabel(f"📅 {date_str}")
            date_label.setStyleSheet("""
                QLabel {
                    font-size: 17px;
                    font-weight: 600;
                    color: #1e40af;
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
            cb.stateChanged.connect(self._send_to_card)
            header_row.addWidget(cb)

            entry_layout.addLayout(header_row)

            # Body text (hidden by default)
            body_text = QTextEdit()
            body_text.setPlainText(text)
            body_text.setReadOnly(True)
            body_text.setFrameShape(QFrame.Shape.NoFrame)
            body_text.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            body_text.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            body_text.setStyleSheet("""
                QTextEdit {
                    font-size: 17px;
                    color: #333;
                    background: rgba(219, 234, 254, 0.5);
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

            # Toggle function
            def make_toggle(btn, body, frame, popup_self):
                def toggle():
                    is_visible = body.isVisible()
                    body.setVisible(not is_visible)
                    btn.setText("▾" if not is_visible else "▸")
                    frame.updateGeometry()
                    if hasattr(popup_self, 'clerking_container'):
                        popup_self.clerking_container.updateGeometry()
                        popup_self.clerking_container.update()
                return toggle

            toggle_fn = make_toggle(toggle_btn, body_text, entry_frame, self)
            toggle_btn.clicked.connect(toggle_fn)
            date_label.mousePressEvent = lambda e, fn=toggle_fn: fn()

            self.clerking_entries_layout.addWidget(entry_frame)
            self._clerking_checkboxes.append(cb)

        # Show the sections (both stay collapsed)
        self.detected_section.setVisible(True)
        if clerking_notes:
            self.clerking_section.setVisible(True)

        print(f"[TRIBUNAL-PSYCH] Detected {len(admissions)} admissions, {len(clerking_notes)} clerking notes")


# ================================================================
# TRIBUNAL CIRCUMSTANCES POPUP (section 8 - with preview and yellow entries)
# ================================================================

class TribunalCircumstancesPopup(QWidget):
    """Popup for Circumstances leading to current admission with yellow collapsible entries.
    Sends directly to card on click.
    """

    sent = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        self._entries = []
        self._extracted_checkboxes = []
        self._setup_ui()

    def _setup_ui(self):
        from background_history_popup import CollapsibleSection

        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        # Main scroll area
        main_scroll = QScrollArea()
        main_scroll.setWidgetResizable(True)
        main_scroll.setFrameShape(QScrollArea.NoFrame)
        main_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        main_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        main_container = QWidget()
        self.main_layout = QVBoxLayout(main_container)
        self.main_layout.setContentsMargins(4, 4, 4, 4)
        self.main_layout.setSpacing(8)

        # ====================================================
        # IMPORTED DATA (gold/yellow collapsible entries)
        # ====================================================
        self.extracted_section = CollapsibleSection("Imported Data", start_collapsed=True)
        self.extracted_section.set_content_height(300)
        self.extracted_section._min_height = 100
        self.extracted_section._max_height = 500
        self.extracted_section.set_header_style("""
            QFrame {
                background: rgba(255, 248, 220, 0.95);
                border: 1px solid rgba(180, 150, 50, 0.4);
                border-radius: 6px 6px 0 0;
            }
        """)
        self.extracted_section.set_title_style("""
            QLabel {
                font-size: 18px;
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
                font-size: 17px;
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
        self.extracted_checkboxes_layout.setAlignment(Qt.AlignmentFlag.AlignTop)

        extracted_scroll.setWidget(self.extracted_container)
        extracted_layout.addWidget(extracted_scroll)

        self.extracted_section.set_content(extracted_content)
        self.extracted_section.setVisible(False)
        self.main_layout.addWidget(self.extracted_section)

        self.main_layout.addStretch()
        main_scroll.setWidget(main_container)
        root.addWidget(main_scroll)

    def _send_to_card(self):
        """Send checked items directly to card (replaces card content)."""
        parts = []
        for cb in self._extracted_checkboxes:
            if cb.isChecked():
                parts.append(cb.property("full_text"))
        combined = "\n\n".join(parts) if parts else ""
        self.sent.emit(combined)

    def set_entries(self, items: list, date_info: str = ""):
        """Display entries with collapsible dated entry boxes in yellow/gold UI."""
        self._entries = items

        for cb in self._extracted_checkboxes:
            cb.deleteLater()
        self._extracted_checkboxes.clear()

        while self.extracted_checkboxes_layout.count():
            item = self.extracted_checkboxes_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        if isinstance(items, str):
            if items.strip():
                items = [{"date": None, "text": p.strip()} for p in items.split("\n\n") if p.strip()]
            else:
                items = []

        if not items:
            self.extracted_section.setVisible(False)
            return

        self.extracted_section.setVisible(True)

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

            if dt:
                if hasattr(dt, "strftime"):
                    date_str = dt.strftime("%d %b %Y")
                else:
                    date_str = str(dt)
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
                    font-size: 17px;
                    font-weight: bold;
                    color: #806000;
                }
                QPushButton:hover { background: rgba(180, 150, 50, 0.35); }
            """)
            header_row.addWidget(toggle_btn)

            date_label = QLabel(f"📅 {date_str}")
            date_label.setStyleSheet("""
                QLabel {
                    font-size: 17px;
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
            cb.stateChanged.connect(self._send_to_card)
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
                    font-size: 17px;
                    color: #333;
                    background: rgba(255, 248, 220, 0.5);
                    border: none;
                    border-radius: 4px;
                    padding: 6px;
                }
            """)
            body_text.setVisible(False)

            # Calculate height based on content
            doc = body_text.document()
            doc.setTextWidth(body_text.viewport().width() if body_text.viewport().width() > 0 else 400)
            content_height = int(doc.size().height()) + 20
            body_text.setFixedHeight(min(content_height, 200))

            def make_toggle(btn, body):
                def toggle():
                    if body.isVisible():
                        body.setVisible(False)
                        btn.setText("▸")
                    else:
                        body.setVisible(True)
                        btn.setText("▾")
                return toggle

            toggle_btn.clicked.connect(make_toggle(toggle_btn, body_text))
            date_label.mousePressEvent = lambda e, btn=toggle_btn: btn.click()

            entry_layout.addWidget(body_text)
            self._extracted_checkboxes.append(cb)
            self.extracted_checkboxes_layout.addWidget(entry_frame)


# ================================================================
# TRIBUNAL PROGRESS POPUP (section 14 - narrative summary + yellow entries)
# ================================================================

class TribunalProgressPopup(QWidget):
    """Popup for Progress section with narrative summary and yellow collapsible entries.

    Features:
    - Preview section at top with Send to Report button
    - Narrative Summary section with checkbox to include in preview
    - Imported Data section with yellow collapsible entries
    - Clickable references in narrative that scroll to source notes
    - Uses same narrative generation as progress_panel for consistency
    """

    sent = Signal(str)

    def __init__(self, parent=None, date_filter: str = 'all'):
        """
        Initialize the progress popup.

        Args:
            parent: Parent widget
            date_filter: One of:
                - 'all': No filtering (default)
                - '1_year': Last 1 year from most recent entry
                - '6_months': Last 6 months from most recent entry
                - 'last_admission': Only entries from the last admission period
        """
        super().__init__(parent)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        self._entries = []
        self._extracted_checkboxes = []
        self._narrative_text = ""
        self._narrative_html = ""  # Store HTML version for display
        self._entry_frames = {}  # Map date_str -> entry_frame for scrolling
        self._entry_body_texts = {}  # Map date_str -> body_text widget for highlighting
        self._date_filter = date_filter  # Store date filter for use in set_entries
        self._setup_ui()

    def _apply_date_filter(self, items: list) -> list:
        """Apply date filtering to entries based on self._date_filter setting.

        Args:
            items: List of entry dictionaries with 'date' key

        Returns:
            Filtered list of entries
        """
        from datetime import datetime, timedelta

        if not items or self._date_filter == 'all':
            return items

        # Get all dates
        dates = [e['date'] for e in items if e.get('date')]
        if not dates:
            return items

        most_recent = max(dates)

        if self._date_filter == '1_year':
            cutoff = most_recent - timedelta(days=365)
            filtered = [e for e in items if e.get('date') and e['date'] >= cutoff]
            return filtered

        elif self._date_filter == '6_months':
            cutoff = most_recent - timedelta(days=180)
            filtered = [e for e in items if e.get('date') and e['date'] >= cutoff]
            return filtered

        elif self._date_filter == 'last_admission':
            # Detect last admission from entries using timeline builder
            try:
                from timeline_builder import build_timeline_with_external_check
                notes_for_timeline = [{'date': e['date'], 'datetime': e['date'],
                                       'content': e.get('content', e.get('text', '')),
                                       'text': e.get('content', e.get('text', ''))}
                                      for e in items if e.get('date')]

                episodes = build_timeline_with_external_check(notes_for_timeline,
                                                               check_external=False, debug=False)
                # Find the last inpatient episode
                inpatient_episodes = [ep for ep in episodes if ep.get('type') == 'inpatient']
                if inpatient_episodes:
                    last_admission = inpatient_episodes[-1]
                    start = last_admission['start']
                    end = last_admission['end']
                    filtered = [e for e in items if e.get('date') and start <= e['date'] <= end]
                    print(f"[TribunalProgressPopup] Last admission: {start} to {end}, {len(filtered)} entries")
                    return filtered
            except Exception as ex:
                print(f"[TribunalProgressPopup] Timeline detection failed: {ex}")

            return items

        return items

    def _setup_ui(self):
        from background_history_popup import ResizableSection, CollapsibleSection

        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        # Main scroll area
        main_scroll = QScrollArea()
        main_scroll.setWidgetResizable(True)
        main_scroll.setFrameShape(QScrollArea.NoFrame)
        main_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        main_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        main_container = QWidget()
        self.main_layout = QVBoxLayout(main_container)
        self.main_layout.setContentsMargins(4, 4, 4, 4)
        self.main_layout.setSpacing(8)

        # ====================================================
        # SECTION 1: NARRATIVE SUMMARY (green, with checkbox)
        # ====================================================
        self.narrative_section = CollapsibleSection("Narrative Summary", start_collapsed=True)
        self.narrative_section.set_content_height(250)
        self.narrative_section._min_height = 100
        self.narrative_section._max_height = 500
        self.narrative_section.set_header_style("""
            QFrame {
                background: rgba(220, 252, 231, 0.95);
                border: 1px solid rgba(34, 197, 94, 0.4);
                border-radius: 6px 6px 0 0;
            }
        """)
        self.narrative_section.set_title_style("""
            QLabel {
                font-size: 18px;
                font-weight: 600;
                color: #166534;
                background: transparent;
                border: none;
            }
        """)

        narrative_content = QWidget()
        narrative_content.setStyleSheet("""
            QWidget {
                background: rgba(220, 252, 231, 0.95);
                border: 1px solid rgba(34, 197, 94, 0.4);
                border-top: none;
                border-radius: 0 0 12px 12px;
            }
        """)

        narrative_layout = QVBoxLayout(narrative_content)
        narrative_layout.setContentsMargins(12, 10, 12, 10)
        narrative_layout.setSpacing(8)

        # Checkbox to include in preview
        self.include_narrative_cb = QCheckBox("Include narrative summary in preview")
        self.include_narrative_cb.setStyleSheet("""
            QCheckBox {
                font-size: 17px;
                font-weight: 600;
                color: #166534;
                background: transparent;
            }
            QCheckBox::indicator {
                width: 16px;
                height: 16px;
            }
        """)
        self.include_narrative_cb.stateChanged.connect(self._send_to_card)
        narrative_layout.addWidget(self.include_narrative_cb)

        # Narrative text display - using QTextBrowser for clickable links
        narrative_scroll = QScrollArea()
        narrative_scroll.setWidgetResizable(True)
        narrative_scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        narrative_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        narrative_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        narrative_scroll.setStyleSheet("QScrollArea { background: transparent; border: none; }")

        self.narrative_text_widget = QTextBrowser()
        self.narrative_text_widget.setReadOnly(True)
        self.narrative_text_widget.setOpenLinks(False)  # Handle clicks manually
        self.narrative_text_widget.anchorClicked.connect(self._on_narrative_link_clicked)
        self.narrative_text_widget.setStyleSheet("""
            QTextBrowser {
                font-size: 17px;
                color: #1f2937;
                background: rgba(255, 255, 255, 0.8);
                border: 1px solid rgba(34, 197, 94, 0.3);
                border-radius: 6px;
                padding: 8px;
            }
        """)
        narrative_scroll.setWidget(self.narrative_text_widget)
        narrative_layout.addWidget(narrative_scroll)

        self.narrative_section.set_content(narrative_content)
        self.narrative_section.setVisible(False)
        self.main_layout.addWidget(self.narrative_section)

        # ====================================================
        # SECTION 3: IMPORTED DATA (gold/yellow collapsible entries)
        # ====================================================
        self.extracted_section = CollapsibleSection("Imported Data", start_collapsed=True)
        self.extracted_section.set_content_height(300)
        self.extracted_section._min_height = 100
        self.extracted_section._max_height = 500
        self.extracted_section.set_header_style("""
            QFrame {
                background: rgba(255, 248, 220, 0.95);
                border: 1px solid rgba(180, 150, 50, 0.4);
                border-radius: 6px 6px 0 0;
            }
        """)
        self.extracted_section.set_title_style("""
            QLabel {
                font-size: 18px;
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
                font-size: 17px;
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
        self.extracted_checkboxes_layout.setAlignment(Qt.AlignmentFlag.AlignTop)

        # Filter bar will be created dynamically when needed
        self._filter_bar = None

        extracted_scroll.setWidget(self.extracted_container)
        extracted_layout.addWidget(extracted_scroll)

        self.extracted_section.set_content(extracted_content)
        self.extracted_section.setVisible(False)
        self.main_layout.addWidget(self.extracted_section)

        self.main_layout.addStretch()
        main_scroll.setWidget(main_container)
        root.addWidget(main_scroll)

    def _remove_entry_filter(self):
        """Remove the filter and show all entries again."""
        # Remove the filter bar
        if hasattr(self, '_filter_bar') and self._filter_bar is not None:
            try:
                self._filter_bar.deleteLater()
                self._filter_bar = None
            except:
                pass

        # Show all entries and collapse them
        for key, body_info in self._entry_body_texts.items():
            if '_' not in key:
                continue

            entry_frame = self._entry_frames.get(key)
            if entry_frame:
                entry_frame.show()  # Make visible again

            if len(body_info) >= 3:
                body_text, toggle_btn, content = body_info
            else:
                body_text, toggle_btn = body_info[:2]

            # Collapse if open
            if body_text.isVisible():
                toggle_btn.click()

            # Clear any highlighting
            note_content = body_text.toPlainText()
            body_text.setPlainText(note_content)

    def _send_to_card(self):
        """Generate text and send directly to card."""
        parts = []

        # Include narrative if checkbox is checked
        if self.include_narrative_cb.isChecked() and self._narrative_text:
            parts.append(self._narrative_text)

        # Include checked entries
        for cb in self._extracted_checkboxes:
            if cb.isChecked():
                parts.append(cb.property("full_text"))

        combined = "\n\n".join(parts) if parts else ""
        if combined:
            self.sent.emit(combined)

    def _generate_narrative_summary(self, entries):
        """Generate comprehensive clinical narrative for tribunal section 14.

        Analyzes risk scores to identify what's driving clinical concerns,
        then builds a flowing narrative from the actual note content.

        Returns tuple of (plain_text, html_text) for display and export purposes.
        """
        import re
        from datetime import datetime, timedelta
        from collections import defaultdict
        from pathlib import Path
        import html as html_module
        from progress_panel import reset_reference_tracker, make_link, make_multi_link

        if not entries:
            return "", ""

        # Reset reference tracker for fresh narrative
        reset_reference_tracker()

        # Get patient info
        from shared_data_store import get_shared_store
        store = get_shared_store()
        patient_info = store.patient_info
        patient_name = patient_info.get("name", "The patient")
        name = patient_name.split()[0] if patient_name else "The patient"

        # Set up pronouns based on gender
        gender_raw = patient_info.get("gender", "").lower()
        if gender_raw in ("female", "f"):
            pronoun = "she"
            pronoun_obj = "her"
            pronoun_poss = "her"
            pronoun_cap = "She"
            pronoun_poss_cap = "Her"
        elif gender_raw in ("male", "m"):
            pronoun = "he"
            pronoun_obj = "him"
            pronoun_poss = "his"
            pronoun_cap = "He"
            pronoun_poss_cap = "His"
        else:
            pronoun = "they"
            pronoun_obj = "them"
            pronoun_poss = "their"
            pronoun_cap = "They"
            pronoun_poss_cap = "Their"

        # Function to strip signature blocks from content before analysis
        def strip_signature_block(text):
            """Remove email signature blocks to avoid false positives from job titles, 'Kind Regards', etc."""
            lines = text.split('\n')
            result_lines = []
            in_signature = False

            for i, line in enumerate(lines):
                line_stripped = line.strip().lower()

                # Detect start of signature block
                signature_starters = [
                    'kind regards', 'best regards', 'warm regards', 'regards,',
                    'many thanks', 'thanks,', 'thank you,', 'yours sincerely',
                    'yours faithfully', 'best wishes', 'with thanks', 'cheers,'
                ]

                # Check if this line starts a signature block
                if any(line_stripped.startswith(s) or line_stripped == s.rstrip(',') for s in signature_starters):
                    in_signature = True
                    continue  # Skip this line

                # Skip lines that look like job titles (after signature detected)
                if in_signature:
                    continue

                # Also check for standalone job title lines that may appear anywhere
                job_title_patterns = [
                    r'\b(anti.?social\s+behaviour\s+officer)\b',
                    r'\b(staff\s+nurse|ward\s+manager|consultant|psychiatrist)\b',
                    r'\b(social\s+worker|care\s*coordinator)\b',
                    r'\b(clinical\s+nurse|specialist\s+nurse)\b',
                    r'\b(team\s+leader|service\s+manager)\b',
                    r'\b(safeguarding\s+officer|liaison\s+officer)\b',
                    r'\b(community\s+nurse|community\s+mental\s+health)\b',
                    r'\b(forensic\s+community\s+nurse|specialist\s+forensic)\b',
                    r'\b(cpn|cpa|rcn|rmn)\b',  # Nursing abbreviations
                    r'\b(occupational\s+therapist|physiotherapist)\b',
                    r'\b(psychologist|psychology\s+assistant)\b',
                    r'\b(support\s+worker|recovery\s+worker|healthcare\s+assistant)\b',
                    r'\b(registrar|sho|fy\d|ct\d|st\d)\b',  # Medical grades
                    r'\b(band\s+\d|deputy\s+manager|matron)\b',
                ]

                is_job_title_line = False
                for pattern in job_title_patterns:
                    if re.search(pattern, line_stripped, re.IGNORECASE):
                        # Check if this is a short line (likely a signature line)
                        if len(line_stripped) < 60:
                            is_job_title_line = True
                            break

                if not is_job_title_line:
                    result_lines.append(line)

            return '\n'.join(result_lines)

        # Load risk dictionary for scoring
        risk_dict = {}

        # Terms that are too generic/common to be meaningful as clinical indicators
        # These cause false positives and don't provide useful clinical insight
        excluded_terms = {
            'high', 'low', 'reduce', 'reduced', 'reducing', 'reduction',
            'increase', 'increased', 'increasing',
            'good', 'bad', 'well', 'poor',  # Too general
            'im', 'war', 'king', 'ran', 'poo',  # Short words that match inside others
            'can', 'will', 'may', 'has', 'had', 'was', 'were',  # Common verbs
            'new', 'old', 'some', 'any', 'all', 'one', 'two',  # Common adjectives/numbers
            'time', 'times', 'day', 'days', 'week', 'weeks',  # Time words
            'said', 'says', 'told', 'asked', 'noted',  # Reporting verbs
            'need', 'needs', 'want', 'wants',  # Common verbs
            'see', 'seen', 'saw', 'look', 'looked',  # Common verbs
            'feel', 'felt', 'feeling', 'feelings',  # Too general without context
            'think', 'thought', 'thinking',  # Too general
            'make', 'made', 'making',  # Too general
            'take', 'took', 'taking',  # Too general (except medication context)
            'go', 'going', 'went', 'gone',  # Too general
            'come', 'came', 'coming',  # Too general
            'get', 'got', 'getting',  # Too general
            'know', 'known', 'knowing',  # Too general
            'give', 'gave', 'given',  # Too general
            'find', 'found', 'finding',  # Too general
            'tell', 'telling',  # Too general
            'work', 'working', 'worked',  # Too general
            'seem', 'seems', 'seemed',  # Too general
            'leave', 'left',  # Ambiguous (could be S17 leave or departing)
            'call', 'called', 'calling',  # Too general
            'try', 'tried', 'trying',  # Too general
            'use', 'used', 'using',  # Too general
            'help', 'helped', 'helping',  # Too general (usually positive)
            'please',  # Too general - appears in routine requests/politeness
        }

        risk_file = Path(__file__).parent / "riskDICT.txt"
        if risk_file.exists():
            try:
                with open(risk_file, 'r', encoding='utf-8') as f:
                    for line in f:
                        line = line.strip()
                        if not line or ',' not in line:
                            continue
                        parts = line.rsplit(',', 1)
                        term = parts[0].strip().lower()
                        score_str = parts[1].strip() if len(parts) > 1 else ''
                        if term and score_str:
                            # Skip excluded generic terms
                            if term in excluded_terms:
                                continue
                            # Skip very short terms (2 chars or less) - too likely to match substrings
                            if len(term) <= 2:
                                continue
                            try:
                                risk_dict[term] = int(score_str)
                            except:
                                pass
            except:
                pass

        # Parse and process entries
        def parse_date(date_val):
            if not date_val:
                return None
            if isinstance(date_val, datetime):
                return date_val
            if hasattr(date_val, 'toPython'):
                return date_val.toPython()
            for fmt in ["%Y-%m-%d", "%d/%m/%Y", "%Y-%m-%dT%H:%M:%S", "%d-%m-%Y"]:
                try:
                    return datetime.strptime(str(date_val)[:10], fmt[:min(len(fmt), 10)])
                except:
                    pass
            return None

        # Helper function to check if a keyword match is negated
        def is_negated(text_lower, keyword):
            """Check if a keyword appears in a negated context."""
            # Special handling for 'seclusion' - often refers to OTHER people, not the patient
            # e.g., "her boyfriend is in seclusion" should NOT count against the patient
            if keyword == 'seclusion':
                # Check if seclusion is in the context of a third party
                third_party_patterns = [
                    r'\b(he|his|him|boyfriend|bf|partner)\b[^.]*\bseclusion\b',  # he/boyfriend mentioned before seclusion
                    r'\bseclusion\b[^.]*\b(he|his|him|boyfriend|bf|partner)\b',  # seclusion mentioned, then he/boyfriend
                    r'\b(he|his)\s+(is|was|has been|had been|keeps|kept)\s+[^.]*\bseclusion\b',  # "he is in seclusion"
                    r'\b(acting out|behaviou?r)[^.]*\bseclusion\b',  # acting out leading to seclusion (usually about others)
                ]
                for pattern in third_party_patterns:
                    if re.search(pattern, text_lower, re.IGNORECASE):
                        print(f"[NEGATION-DEBUG] 'seclusion' refers to third party, negating")
                        return True

            # Quick check for common negation patterns in the entire text first
            # This catches cases like "have not led to aggression" more reliably
            quick_negation_patterns = [
                r'not\s+led\s+to\s+' + re.escape(keyword),
                r'have\s+not\s+led\s+to\s+' + re.escape(keyword),
                r'has\s+not\s+led\s+to\s+' + re.escape(keyword),
                r'not\s+resulted?\s+in\s+' + re.escape(keyword),
                r'no\s+' + re.escape(keyword),
                r'nil\s+' + re.escape(keyword),
                r'without\s+' + re.escape(keyword),
                r'absence\s+of\s+' + re.escape(keyword),
                # Common clinical negation phrases with lists
                r'no\s+self[- ]?harm\s+(or\s+)?(incidents?\s+of\s+)?' + re.escape(keyword),
                r'no\s+incidents?,?\s+self[- ]?harm\s+(or\s+)?' + re.escape(keyword),
                r'no\s+[\w\s,]+\s+or\s+(incidents?\s+of\s+)?' + re.escape(keyword),
                # Sentence-level negation: "no" anywhere before keyword (allow newlines for multi-line phrases)
                r'\bno\b[^.!?]{0,100}\b' + re.escape(keyword),
                # "didn't/doesn't present as aggressive" patterns
                r'didn\'?t\s+present\s+(as\s+)?' + re.escape(keyword),
                r'did\s+not\s+present\s+(as\s+)?' + re.escape(keyword),
                r'does\s+not\s+present\s+(as\s+)?' + re.escape(keyword),
                r'doesn\'?t\s+present\s+(as\s+)?' + re.escape(keyword),
                # "did not pose any aggressive behaviour"
                r'did\s+not\s+pose\s+(any\s+)?' + re.escape(keyword),
                r'didn\'?t\s+pose\s+(any\s+)?' + re.escape(keyword),
                # "didn't display any signs of aggression"
                r'didn\'?t\s+display\s+(any\s+)?(signs?\s+of\s+)?' + re.escape(keyword),
                r'did\s+not\s+display\s+(any\s+)?(signs?\s+of\s+)?' + re.escape(keyword),
                r'no\s+signs?\s+of\s+' + re.escape(keyword),
                # "have not been an incident of aggression"
                r'have\s+not\s+been\s+(an?\s+)?incident' + r'[^.]*' + re.escape(keyword),
                r'has\s+not\s+been\s+(an?\s+)?incident' + r'[^.]*' + re.escape(keyword),
                r'there\s+have\s+not\s+been\b[^.]*' + re.escape(keyword),
                r'there\s+has\s+not\s+been\b[^.]*' + re.escape(keyword),
                r'no\s+incident' + r'[^.]*' + re.escape(keyword),
                # Low risk context
                r'\b' + re.escape(keyword) + r'[^.]*:\s*low\b',
                r'\blow\b[^.]*' + re.escape(keyword),
                # "not observed/reported" patterns
                r'\b' + re.escape(keyword) + r'[^.]*\bnot\s+(observed|reported|noted|seen)',
                r'\b' + re.escape(keyword) + r'[^.]*\bwere\s+not\s+(observed|reported|noted|seen)',
                # Risk section mentions - these are historical risk lists, not current incidents
                r'risks?[:\s]+[^.]*\b' + re.escape(keyword),
                r'history\s+of\s+' + re.escape(keyword),
                r'risk\s+of\s+' + re.escape(keyword),
                # Risk section headers - keyword in risk list (within 300 chars of "Risks:")
                r'risks?\s*:\s*.{0,300}\b' + re.escape(keyword),
                # "Aggression towards others" in a risk list context
                r'\b' + re.escape(keyword) + r'\s+towards\s+others\b',
                # Risk assessment field labels (To Other:, To Others:, To Self:)
                r'\bto\s+others?\s*:\s*history\s+of\b[^.]*' + re.escape(keyword),
                r'\bto\s+others?\s*:[^.]*\b' + re.escape(keyword),
                r'\bto\s+self\s*:\s*history\s+of\b[^.]*' + re.escape(keyword),
                r'\bto\s+self\s*:[^.]*\b' + re.escape(keyword),
                # Forensic history mentions
                r'\bforensic\s+history\b[^.]*' + re.escape(keyword),
                r'\b' + re.escape(keyword) + r'[^.]*\bforensic\s+history\b',
                # Care plan / management language - not actual incidents
                r'\bmanagement\s+of\s+(high\s+)?risks?\b[^.]*' + re.escape(keyword),
                r'\bmanagement\s+of\b[^.]*' + re.escape(keyword),
                r'\bpreventative\s+interventions?\b[^.]*' + re.escape(keyword),
                # Relapse indicators / warning signs - not actual incidents
                r'\brelapse\s+indicators?\b[^.]*' + re.escape(keyword),
                r'\bwarning\s+signs?\b[^.]*' + re.escape(keyword),
                r'\bearly\s+warning\b[^.]*' + re.escape(keyword),
                # "urges" - feelings/potential, not actual behaviour
                r'\b' + re.escape(keyword) + r'\s+urges?\b',
                r'\burges?\s+to\s+' + re.escape(keyword),
                r'\bhas\s+' + re.escape(keyword) + r'\s+urges?\b',
                # Conditional/potential behaviour - not actual incidents
                r'can\s+be\s+' + re.escape(keyword),
                r'may\s+be(come)?\s+' + re.escape(keyword),
                r'could\s+be(come)?\s+' + re.escape(keyword),
                r'if\s+.*\b' + re.escape(keyword),
                # Positive behaviour indicators in same sentence as keyword
                r'\bcalm\s+and\s+settled\b[^.]*\b' + re.escape(keyword),
                r'\b' + re.escape(keyword) + r'[^.]*\bcalm\s+and\s+settled\b',
                r'\bsettled\s+and\s+calm\b[^.]*\b' + re.escape(keyword),
                r'\b(very\s+)?pleasant\s+on\s+approach\b[^.]*\b' + re.escape(keyword),
                r'\b' + re.escape(keyword) + r'[^.]*\b(very\s+)?pleasant\s+on\s+approach\b',
                # "Nothing suggested" / "nothing to suggest" patterns - assessment language
                r'\bnothing\s+suggested\b[^.]*\b' + re.escape(keyword),
                r'\bnothing\s+to\s+suggest\b[^.]*\b' + re.escape(keyword),
                r'\bno\s+evidence\s+(of|to\s+suggest)\b[^.]*\b' + re.escape(keyword),
                r'\bno\s+indication\s+(of|that)\b[^.]*\b' + re.escape(keyword),
                r'\bno\s+concerns?\s+(about|regarding|of)\b[^.]*\b' + re.escape(keyword),
                r'\bno\s+suggestion\s+(of|that)\b[^.]*\b' + re.escape(keyword),
                r'\bat\s+time\s+of\s+assessment\b[^.]*\b' + re.escape(keyword),
                r'\b' + re.escape(keyword) + r'[^.]*\bat\s+time\s+of\s+assessment\b',
            ]
            for pattern in quick_negation_patterns:
                if re.search(pattern, text_lower, re.IGNORECASE):
                    return True

            # Debug: show when quick patterns fail for aggression
            if keyword in ['aggression', 'aggressive']:
                # Check specifically the sentence-level pattern
                sentence_pattern = r'\bno\b[^.!?]{0,100}\b' + re.escape(keyword)
                match = re.search(sentence_pattern, text_lower, re.IGNORECASE)
                if match:
                    print(f"[NEGATION-DEBUG] Pattern SHOULD have matched: {match.group()}")
                else:
                    print(f"[NEGATION-DEBUG] No sentence-level match found for {keyword}")

            # Find the keyword position
            pos = text_lower.find(keyword.lower())
            if pos == -1:
                return True  # Not found, so "negated" in sense of not applicable

            # Get context window before the keyword (look back ~60 chars for negation)
            start = max(0, pos - 60)
            context_before = text_lower[start:pos]

            # Negation patterns - keyword appears after these phrases
            negation_patterns = [
                r'\bno\s+(incidents?\s+of\s+)?',
                r'\bno\s+(increase\s+in\s+)?',
                r'\bnil\s+',
                r'\bno\s+',
                r'\bnone\s+',
                r'\bwithout\s+(any\s+)?',
                r'\bdenied\s+(any\s+)?',
                r'\bdenies\s+(any\s+)?',  # Present tense: "Denies any suicidal"
                r'\bdeny\s+(any\s+)?',
                r'\bdenying\s+(any\s+)?',
                r'\bdid\s*n[o\']t\s+(present\s+as\s+|show\s+|display\s+|exhibit\s+)?',
                r'\bdoes\s*n[o\']t\s+(present\s+as\s+|show\s+|display\s+|exhibit\s+)?',
                r'\bhas\s*n[o\']t\s+(been\s+|shown\s+)?',
                r'\bnot\s+(been\s+)?',
                r'\bfree\s+from\s+',
                r'\babsence\s+of\s+',
                r'\bnegative\s+for\s+',
                r'\bremains\s+compliant\s+',  # "remains compliant" is positive, not risk
            ]

            for pattern in negation_patterns:
                # Check if negation pattern appears just before keyword
                if re.search(pattern + r'.*?' + re.escape(keyword), context_before + keyword, re.IGNORECASE):
                    return True

            # Also check the immediate sentence context
            # Find sentence start
            sentence_start = max(text_lower.rfind('.', 0, pos) + 1, 0)
            sentence = text_lower[sentence_start:pos + len(keyword) + 50]

            if keyword in ['aggression', 'aggressive'] and 'not led' in text_lower:
                print(f"[NEGATION-DEBUG] Checking sentence for '{keyword}': '{sentence[:100]}...'")

            # Patterns that indicate absence/negation in the sentence
            absence_patterns = [
                r'no\s+(incidents?|episodes?|concerns?|issues?|reports?)\s+(of\s+)?' + re.escape(keyword),
                r'(didn\'t|did not|does not|doesn\'t|hasn\'t|has not|wasn\'t|was not)\s+\w*\s*' + re.escape(keyword),
                # Broader patterns where negation applies to whole statement
                r'no\s+concerns?\s+(about|regarding|re)\b',  # "no concerns about..." in same sentence
                r'no\s+(increase|change|escalation)\s+in\s+risk',  # "no increase in risk"
                r'no\s+incidents?\s+reported',  # "no incidents reported"
                r'any\s+incidents?\s+reported\s+by',  # usually follows "no concerns... or any incidents"
                # "have not led to aggression" patterns
                r'(have|has|had)\s+not\s+led\s+to\s+' + re.escape(keyword),
                r'not\s+led\s+to\s+' + re.escape(keyword),
                r'not\s+resulted?\s+in\s+' + re.escape(keyword),
                r'without\s+(any\s+)?' + re.escape(keyword),
                # "no harm to self or others" patterns
                r'no\s+harm\s+to\s+(self|others)',  # "no harm to self"
                r'no\s+(self[- ]?harm|suicid)',  # "no self-harm", "no suicidal"
                # "Denies X, no Y" patterns - comma-separated negations
                r'denies\s+.*,\s*no\s+' + re.escape(keyword),
                r'no\s+.*,\s*no\s+' + re.escape(keyword),
            ]

            for pattern in absence_patterns:
                match = re.search(pattern, sentence, re.IGNORECASE)
                if match:
                    if keyword in ['aggression', 'aggressive']:
                        print(f"[NEGATION-DEBUG] Pattern '{pattern[:50]}' matched in sentence for '{keyword}'")
                    return True

            # Check if the sentence starts with or contains broad negation that applies to everything
            broad_negation_patterns = [
                r'^no\s+concerns?\b',  # sentence starts with "no concerns"
                r'^nil\b',  # sentence starts with "nil"
                r'^none\b',  # sentence starts with "none"
                r'not\s+been\s+any\b',  # "has not been any"
            ]

            for pattern in broad_negation_patterns:
                if re.search(pattern, sentence.strip(), re.IGNORECASE):
                    return True

            # Handle comma-separated lists: "No incidents, self harm or aggression"
            # The "No" at the start applies to all items in the list
            list_negation_pattern = r'^no\s+[\w\s]+[,].*' + re.escape(keyword)
            if re.search(list_negation_pattern, sentence.strip(), re.IGNORECASE):
                return True

            # Also handle "No X or Y or Z" without commas
            or_list_pattern = r'^no\s+[\w\s]+(\s+or\s+[\w\s]+)*\s+or\s+' + re.escape(keyword)
            if re.search(or_list_pattern, sentence.strip(), re.IGNORECASE):
                return True

            # Check for positive context: if sentence contains positive words BEFORE the keyword,
            # and the keyword appears in a negated/conditional context, it's likely not an incident
            # e.g., "presented as settled and although... have not led to aggression"
            positive_context_words = ['settled', 'stable', 'calm', 'pleasant', 'appropriate', 'well']
            keyword_pos_in_sentence = sentence.find(keyword.lower())
            text_before_keyword = sentence[:keyword_pos_in_sentence] if keyword_pos_in_sentence > 0 else ""

            # If positive word appears before keyword AND there's a negation pattern
            has_positive_before = any(pw in text_before_keyword for pw in positive_context_words)
            has_negation_nearby = bool(re.search(r'\b(not|no|without|haven\'t|hasn\'t|didn\'t)\b', text_before_keyword))

            if has_positive_before and has_negation_nearby:
                return True

            return False

        def is_historical(text_lower, keyword):
            """Check if a keyword appears in a historical/past context rather than current."""
            pos = text_lower.find(keyword.lower())
            if pos == -1:
                return False

            # Get context window around the keyword
            start = max(0, pos - 80)
            end = min(len(text_lower), pos + len(keyword) + 40)
            context = text_lower[start:end]

            # Historical/past reference patterns
            historical_patterns = [
                r'\blast\s+(year|month|week|time)',
                r'\bpreviously\b',
                r'\bin\s+the\s+past\b',
                r'\bhistory\s+of\b',
                r'\bhistorical\s+(risk|record|incident)',  # "historical risk of aggression"
                r'\bpast\s+history\b',
                r'\bprior\s+to\b',
                r'\bbefore\s+(admission|transfer|this)',
                r'\b(years?|months?|weeks?)\s+ago\b',
                r'\bused\s+to\b',
                r'\bformerly\b',
                r'\bprevious(ly)?\s+(episode|incident|relapse)',
                r'\bback\s+in\s+\d{4}\b',
                r'\bwhen\s+(he|she|they)\s+(was|were)\b',
                r'\b(had|was|were)\s+a\s+relapse\b',
            ]

            for pattern in historical_patterns:
                if re.search(pattern, context, re.IGNORECASE):
                    return True

            return False

        def is_contextually_valid_mental_state(text_lower, keyword):
            """Check if a mental state keyword is actually describing mental state, not something else.

            For ambiguous words like 'poor', ensure they're describing presentation/mental state
            rather than 'poor compliance', 'poor engagement', etc.
            """
            # Ambiguous words that need context checking
            ambiguous_words = ['poor']

            if keyword not in ambiguous_words:
                return True  # Not ambiguous, assume valid

            pos = text_lower.find(keyword)
            if pos == -1:
                return False

            # Get the word(s) following the keyword
            after_text = text_lower[pos + len(keyword):pos + len(keyword) + 30].strip()

            # If 'poor' is followed by these words, it's NOT describing mental state
            non_mental_state_contexts = [
                'compliance', 'adherence', 'engagement', 'attendance', 'insight',
                'appetite', 'sleep', 'hygiene', 'self-care', 'self care',
                'diet', 'nutrition', 'oral intake', 'mobility', 'concentration',
                'memory', 'relationship', 'support', 'prognosis'
            ]

            for context_word in non_mental_state_contexts:
                if after_text.startswith(context_word):
                    return False

            return True

        # Calculate risk score for each entry and identify what's driving it
        def calculate_score_and_drivers(content):
            """Calculate risk score and return top contributing terms.

            Uses word boundary matching to avoid false positives like 'war' in 'ward'.
            Also checks negation and historical context for risk terms.
            When negation is detected for risk terms (score > 1), score becomes -10 (protective).
            Signature blocks are stripped to avoid matching job titles and 'Kind Regards'.
            """
            # Strip signature blocks before analysis
            content_clean = strip_signature_block(content)
            # Normalize apostrophes (curly ' to straight ') for consistent pattern matching
            content_lower = content_clean.lower().replace(''', "'").replace(''', "'")
            term_scores = []
            for term, points in risk_dict.items():
                # Use word boundaries to avoid matching substrings
                # e.g., 'war' should not match 'ward', 'im' should not match 'times'
                if re.search(r'\b' + re.escape(term) + r'\b', content_lower):
                    # For positive-scoring terms (risk indicators), check if negated or historical
                    if points > 1:
                        negated = is_negated(content_lower, term)
                        if term in ['aggression', 'aggressive', 'violence', 'violent', 'seclusion', 'restrain']:
                            print(f"[NEGATION-DEBUG] Term '{term}' in text, negated={negated}")
                            if not negated:
                                # This is the problematic case - show what text is NOT being caught
                                print(f"[NEGATION-DEBUG] NOT NEGATED '{term}' - text: {content_lower[:300]}...")
                        if negated:
                            # Negated risk term becomes protective (-10)
                            # e.g., "no aggression" scores -10 instead of +250
                            term_scores.append((term + ' (absent)', -10))
                            continue
                        if is_historical(content_lower, term):
                            # Historical references don't count for current risk
                            continue
                    term_scores.append((term, points))
            term_scores.sort(key=lambda x: abs(x[1]), reverse=True)
            total = sum(pts for _, pts in term_scores)
            return total, term_scores[:5]  # Return top 5 drivers

        entries_data = []
        for entry in entries:
            content = entry.get('content', '') or entry.get('text', '') or ''
            if not content:
                continue
            note_date = parse_date(entry.get('date') or entry.get('datetime'))
            if not note_date:
                continue

            score, drivers = calculate_score_and_drivers(content)
            note_type = entry.get('type', 'Unknown')

            # Strip signature blocks for keyword matching (avoids job titles like "Community Nurse")
            content_stripped = strip_signature_block(content)

            entries_data.append({
                'date': note_date,
                'content': content,  # Original for display
                'content_lower': content_stripped.lower(),  # Stripped for keyword matching
                'score': score,
                'drivers': drivers,
                'type': note_type,
            })

        if not entries_data:
            return "", ""

        entries_data.sort(key=lambda x: x['date'])

        # === EXTRACT CLINICAL INFORMATION ===

        # Professional types
        professional_patterns = {
            'psychiatrist': r'\b(psychiatrist|consultant|dr\s+\w+|medical\s+review|clinic\s+letter|ward\s+round)\b',
            'nursing': r'\b(nurse|nursing|cpn|cpa|key\s*worker|named\s*nurse|primary\s*nurse)\b',
            'psychologist': r'\b(psycholog|cbt|therapy\s+session|psychological)\b',
            'social_worker': r'\b(social\s*worker|sw\b|care\s*coordinator|social\s*circumstances)\b',
            'occupational_therapist': r'\b(occupational\s*therap|ot\b|functional\s*assessment)\b',
            'physiotherapist': r'\b(physiotherap|physio)\b',
            'pharmacy': r'\b(pharmac|medication\s*review)\b',
            'support_worker': r'\b(support\s*worker|recovery\s*worker|hca\b|healthcare\s*assistant)\b',
        }

        # Contact/review patterns
        contact_patterns = {
            'home_visit': r'\b(home\s*visit|visited\s*at\s*home|seen\s*at\s*home|visit\s*to\s*flat|visited\s*flat)\b',
            'clinic': r'\b(clinic|outpatient|appointment|attended\s*for)\b',
            'telephone': r'\b(telephone|phone\s*call|called|spoke\s*on\s*phone|text|messag)\b',
            'ward_review': r'\b(ward\s*round|mdt|multidisciplinary|team\s*meeting|clinical\s*review)\b',
        }

        # Helper function for word boundary matching - avoids "elated" matching "related"
        def word_match(text, keyword):
            """Check if keyword exists as a whole word (not substring) in text."""
            return bool(re.search(r'\b' + re.escape(keyword) + r'\b', text, re.IGNORECASE))

        # Mental state keywords
        mental_state_positive = [
            'stable', 'settled', 'calm', 'pleasant', 'appropriate', 'well presented',
            'good rapport', 'engaging', 'cooperative', 'bright', 'euthymic', 'good mood',
            'no concerns', 'unremarkable', 'maintained', 'consistent'
        ]
        mental_state_negative = [
            'deteriorat', 'worsen', 'declined', 'poor', 'guarded', 'isolat', 'withdrawn',
            'paranoid', 'suspicious', 'agitated', 'irritable', 'low mood', 'flat affect',
            'thought disorder', 'responding to', 'voices', 'hallucination', 'delusion',
            'anxious', 'distressed', 'preoccupied', 'labile'
        ]

        # Engagement keywords
        engagement_positive = ['engaged', 'engaging well', 'good engagement', 'participated', 'attended', 'compliant', 'adherent', 'taking medication', 'cooperative']
        engagement_negative = ['did not engage', 'refused', 'declined', 'not engaging', 'poor engagement', 'non-compliant', 'missed appointment', 'dna', 'did not attend', 'cancelled']

        # Accommodation keywords
        accommodation_kw = ['flat', 'accommodation', 'supported living', 'hostel', 'home', 'residence', 'placement', 'house', 'property', 'tenancy', 'living situation']

        # Activities/daily living
        activities_kw = ['activities', 'cooking', 'cleaning', 'self-care', 'hygiene', 'shopping', 'laundry', 'meals', 'eating', 'sleeping', 'sleep', 'appetite', 'exercise', 'gym', 'walking', 'outing', 'community']

        # Medication keywords
        medication_kw = ['depot', 'clozapine', 'olanzapine', 'risperidone', 'aripiprazole', 'quetiapine', 'haloperidol', 'medication', 'injection', 'tablets', 'prescribed', 'dose', 'mg']

        # Leave keywords
        leave_kw = ['leave', 's17', 'section 17', 'ground leave', 'escorted', 'unescorted', 'community leave', 'home leave']

        # Risk keywords
        risk_violence = ['violent', 'assault', 'attack', 'aggression', 'aggressive', 'hit', 'punch', 'kick', 'restrain', 'seclusion']
        risk_self_harm = ['self-harm', 'self harm', 'cutting', 'overdose', 'ligature', 'suicidal', 'suicide']
        risk_absconding = ['abscond', 'awol', 'failed to return from leave', 'failed to return from pass',
                           'failed to return to the ward', 'failed to return to the unit', 'failed to return to hospital',
                           'did not return from leave', 'did not return from pass', 'did not return to the ward',
                           'did not return to the unit', 'did not return to hospital', 'did not return from overnight']

        # === ANALYZE ENTRIES ===
        professional_contacts = defaultdict(list)
        contact_types = defaultdict(list)
        mental_state_entries = {'positive': [], 'negative': []}
        engagement_entries = {'positive': [], 'negative': []}
        accommodation_entries = []
        activities_entries = []
        medication_entries = []
        leave_entries = []
        risk_entries = {'violence': [], 'self_harm': [], 'absconding': []}

        def is_section_header_or_label(text_lower, keyword):
            """Check if keyword appears in a section header or label context, not actual content."""
            pos = text_lower.find(keyword.lower())
            if pos == -1:
                return False

            # Get context around the keyword
            start = max(0, pos - 30)
            end = min(len(text_lower), pos + len(keyword) + 30)
            context = text_lower[start:end]

            # Section header patterns - keyword followed by colon or in title-like context
            header_patterns = [
                re.escape(keyword) + r'\s*:',  # "Risk:" or "Risk management:"
                re.escape(keyword) + r'\s+management',  # "risk management"
                re.escape(keyword) + r'\s+assessment',  # "risk assessment"
                re.escape(keyword) + r'\s+plan',  # "risk plan"
                re.escape(keyword) + r'\s+screen',  # "risk screen"
                r'no\s+concerns?\s+(about|regarding|re)',  # "no concerns about"
                r'no\s+(increase|change)\s+in\s+' + re.escape(keyword),  # "no increase in risk"
                r'any\s+incidents?\s+reported',  # "any incidents reported" - usually negated
            ]

            for pattern in header_patterns:
                if re.search(pattern, context, re.IGNORECASE):
                    return True

            return False

        def is_risk_management_note(text_lower):
            """Check if a note is describing risk MANAGEMENT measures rather than actual incidents.

            Notes about risk management, risk plans, care plans, staffing levels, etc.
            are NOT actual incidents - they describe what's IN PLACE to manage risk.
            """
            # Patterns that indicate this is about risk management, not incidents
            management_patterns = [
                r'\brisk\s+management\s*:',  # "Risk management:"
                r'\brisk\s+plan\s*:',  # "Risk plan:"
                r'\bcare\s+plan\s*:',  # "Care plan:"
                r'\bmanagement\s+plan\s*:',
                r'\bstaffing\s*:',
                r'\b\d+\s+hour\s+staff',  # "24 hour staff"
                r'\bwaking\s+night',  # "waking nights"
                r'\bsleeping\s+night',
                r'\b1[:\s]*1\b',  # "1:1" observation
                r'\bone\s+to\s+one\b',
                r'\benhanced\s+observation',
                r'\bgeneral\s+observation',
                r'\bintermittent\s+observation',
                r'\brisk\s+assessment\s*:',
                r'\bawaiting\s+toc\b',  # "Awaiting TOC" (Transfer of Care)
                r'\btransfer\s+of\s+care\b',
                r'\bno\s+concerns?\s+about\s+(increase|change)',  # "no concerns about increase"
                r'\bno\s+incidents?\s+reported',  # "no incidents reported"
                r'\bnil\s+incidents?',
            ]

            for pattern in management_patterns:
                if re.search(pattern, text_lower, re.IGNORECASE):
                    return True
            return False

        def has_actual_risk_incident(text_lower, keywords):
            """Check if there's an actual (non-negated, non-historical) risk incident for any keyword."""
            # First check if this note is about risk MANAGEMENT, not actual incidents
            if is_risk_management_note(text_lower):
                return False

            for kw in keywords:
                # Use word boundaries to avoid substring matches
                if re.search(r'\b' + re.escape(kw) + r'\b', text_lower):
                    # Skip if negated, historical, or just a section header/label
                    if is_negated(text_lower, kw):
                        print(f"[RISK-DEBUG] Keyword '{kw}' is NEGATED in: {text_lower[:100]}...")
                        continue
                    if is_historical(text_lower, kw):
                        print(f"[RISK-DEBUG] Keyword '{kw}' is HISTORICAL in: {text_lower[:100]}...")
                        continue
                    if is_section_header_or_label(text_lower, kw):
                        print(f"[RISK-DEBUG] Keyword '{kw}' is HEADER/LABEL in: {text_lower[:100]}...")
                        continue
                    # NON-NEGATED MATCH FOUND
                    print(f"[RISK-DEBUG] *** ACTUAL MATCH *** Keyword '{kw}' found NON-NEGATED in: {text_lower[:200]}...")
                    return True
            return False

        for e in entries_data:
            cl = e['content_lower']
            content = e['content']
            date = e['date']

            # Identify professionals
            for prof, pattern in professional_patterns.items():
                if re.search(pattern, cl):
                    professional_contacts[prof].append(e)

            # Identify contact types
            for ctype, pattern in contact_patterns.items():
                if re.search(pattern, cl):
                    contact_types[ctype].append(e)

            # Mental state - check negation, historical context, and contextual validity
            # Use word boundary matching to avoid "elated" matching "related"
            if any(word_match(cl, kw) for kw in mental_state_positive):
                mental_state_entries['positive'].append(e)
            # Only count as negative if:
            # 1. The keyword is NOT negated (e.g., "no hallucinations" should NOT be flagged)
            # 2. The keyword is NOT in a historical context (e.g., "last year" references)
            # 3. The keyword is contextually valid (e.g., "poor" describes mental state, not "poor compliance")
            # 4. "declined" is NOT in structured refusal context (e.g., "Vitals: declined")
            def is_valid_mental_state_negative(text, kw):
                if not word_match(text, kw):
                    return False
                if is_negated(text, kw):
                    return False
                if is_historical(text, kw):
                    return False
                if not is_contextually_valid_mental_state(text, kw):
                    return False
                # "declined" in structured refusal context is engagement, not mental state
                if kw == 'declined':
                    structured_refusal = r'\b(vitals?|observations?|bloods?|medication|meds|food|fluids?|shower|personal\s*care)\s*:?\s*(monitored:?)?\s*declined'
                    if re.search(structured_refusal, text, re.IGNORECASE):
                        return False
                return True
            if any(is_valid_mental_state_negative(cl, kw) for kw in mental_state_negative):
                mental_state_entries['negative'].append(e)

            # Engagement - use word boundary matching
            if any(re.search(r'\b' + re.escape(kw) + r'\b', cl) for kw in engagement_positive):
                engagement_entries['positive'].append(e)
            # Check engagement negative, but exclude "declined" if external subject is declining
            def has_patient_engagement_issue(text, keywords):
                external_subject_pattern = r'\b(council|hospital|nhs|team|staff|service|department|authority|housing|they|we|it)\s+(have|has|had)\s+(previously\s+)?declined'
                for kw in keywords:
                    if re.search(r'\b' + re.escape(kw) + r'\b', text):
                        if kw == 'declined' and re.search(external_subject_pattern, text, re.IGNORECASE):
                            continue  # Skip - external subject is declining
                        return True
                return False
            if has_patient_engagement_issue(cl, engagement_negative):
                engagement_entries['negative'].append(e)

            # Accommodation - use word boundary matching
            if any(re.search(r'\b' + re.escape(kw) + r'\b', cl) for kw in accommodation_kw):
                accommodation_entries.append(e)

            # Activities - use word boundary matching
            if any(re.search(r'\b' + re.escape(kw) + r'\b', cl) for kw in activities_kw):
                activities_entries.append(e)

            # Medication - use word boundary matching
            if any(re.search(r'\b' + re.escape(kw) + r'\b', cl) for kw in medication_kw):
                medication_entries.append(e)

            # Leave - exclude phrases where "leave" doesn't mean Section 17/escorted leave
            def is_valid_leave_context(text):
                # Phrases where "leave" does NOT mean granted leave
                invalid_leave_patterns = [
                    r'\bleave\s+(me|him|her|them|us)\s+(alone|be)\b',  # "leave me alone"
                    r'\bwon\'?t\s+(you\s+)?(lot\s+)?leave\b',  # "won't you leave"
                    r'\bdon\'?t\s+leave\b',  # "don't leave"
                    r'\bplease\s+leave\b',  # "please leave" (asking someone to go)
                    r'\bto\s+leave\s+(the\s+)?(room|area|ward)\b',  # "leave the room"
                    r'\bleave\s+it\b',  # "leave it"
                    r'\bannual\s+leave\b',  # staff annual leave
                    r'\bsick\s+leave\b',  # staff sick leave
                    r'\bmaternity\s+leave\b',  # staff maternity leave
                ]
                for pattern in invalid_leave_patterns:
                    if re.search(pattern, text, re.IGNORECASE):
                        return False
                # Must have valid leave context - S17, escorted, ground leave, etc.
                valid_leave_patterns = [
                    r'\b(s\.?17|section\s*17)\b',
                    r'\b(escorted|unescorted)\s*(leave)?\b',
                    r'\b(ground|community|home)\s*leave\b',
                    r'\bleave\s*(was\s*)?(granted|approved|agreed|authorised)\b',
                    r'\b(granted|approved|agreed)\s*leave\b',
                ]
                # If the entry has specific leave context, it's valid
                for pattern in valid_leave_patterns:
                    if re.search(pattern, text, re.IGNORECASE):
                        return True
                # If just "leave" without context, skip it
                if re.search(r'\bleave\b', text) and not any(re.search(r'\b' + re.escape(kw) + r'\b', text) for kw in ['s17', 'section 17', 'escorted', 'unescorted', 'ground leave', 'community leave', 'home leave']):
                    return False
                return True

            # Leave - use word boundary matching
            if any(re.search(r'\b' + re.escape(kw) + r'\b', cl) for kw in leave_kw):
                if is_valid_leave_context(cl):
                    leave_entries.append(e)

            # Risk - ONLY count if NOT negated
            if has_actual_risk_incident(cl, risk_violence):
                risk_entries['violence'].append(e)
            if has_actual_risk_incident(cl, risk_self_harm):
                risk_entries['self_harm'].append(e)
            if has_actual_risk_incident(cl, risk_absconding):
                risk_entries['absconding'].append(e)

        # === BUILD NARRATIVE ===
        narrative_parts = []

        # Helper to extract relevant sentence/excerpt
        def extract_excerpt(content, keywords, max_len=200):
            content_lower = content.lower()
            for kw in keywords:
                if isinstance(kw, str):
                    pos = content_lower.find(kw.lower())
                else:
                    match = re.search(kw, content_lower)
                    pos = match.start() if match else -1
                if pos != -1:
                    start = max(0, content.rfind('.', 0, pos) + 1)
                    end = content.find('.', pos)
                    if end == -1 or end > pos + max_len:
                        end = min(len(content), pos + max_len)
                    else:
                        end = end + 1
                    excerpt = content[start:end].strip()
                    if len(excerpt) >= 30:
                        return excerpt
            return content[:max_len].strip()

        # Date range
        earliest = min(e['date'] for e in entries_data)
        latest = max(e['date'] for e in entries_data)
        date_range_days = (latest - earliest).days
        date_range_months = max(1, date_range_days // 30)

        # --- HEADER ---
        narrative_parts.append(f"<b>PROGRESS NARRATIVE: {name}</b>")
        narrative_parts.append(f"Review period: {earliest.strftime('%d %B %Y')} to {latest.strftime('%d %B %Y')}")
        narrative_parts.append("")

        # --- DEMOGRAPHIC INTRODUCTION ---
        # Calculate age from DOB if available
        dob = patient_info.get('dob')
        age_str = ""
        if dob:
            if isinstance(dob, str):
                for fmt in ['%Y-%m-%d', '%d/%m/%Y', '%d-%m-%Y']:
                    try:
                        dob = datetime.strptime(dob, fmt)
                        break
                    except:
                        pass
            if hasattr(dob, 'year'):
                today = datetime.now()
                age = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
                age_str = f"{age} year old "

        ethnicity = patient_info.get('ethnicity', '')
        ethnicity_str = f"{ethnicity} " if ethnicity else ""

        # Gender descriptor
        if gender_raw in ("female", "f"):
            gender_desc = "woman"
        elif gender_raw in ("male", "m"):
            gender_desc = "man"
        else:
            gender_desc = "person"

        # Build diagnosis string
        diagnoses = patient_info.get('diagnosis', [])
        diagnosis_str = ""
        if diagnoses:
            if len(diagnoses) == 1:
                diagnosis_str = f" who has been diagnosed with {diagnoses[0]}"
            elif len(diagnoses) == 2:
                diagnosis_str = f" who has been diagnosed with {diagnoses[0]} and {diagnoses[1]}"
            else:
                diagnosis_str = f" who has been diagnosed with {diagnoses[0]}, {diagnoses[1]}, and {diagnoses[2]}"

        # Full name for intro
        full_name = patient_info.get('name', name)
        intro_sentence = f"{full_name} is a {age_str}{ethnicity_str}{gender_desc}{diagnosis_str}."
        narrative_parts.append(intro_sentence)
        narrative_parts.append("")

        # === SCORE ANALYSIS - What's driving clinical concerns? ===
        # Group entries by month for trend analysis
        monthly_scores = defaultdict(list)
        for e in entries_data:
            month_key = e['date'].strftime('%Y-%m')
            monthly_scores[month_key].append(e)

        # Identify high-scoring entries and their drivers
        high_scoring = [e for e in entries_data if e['score'] >= 200]
        medium_scoring = [e for e in entries_data if 50 <= e['score'] < 200]
        protective = [e for e in entries_data if e['score'] < 0]

        # Collect all score drivers across entries
        all_drivers = defaultdict(lambda: {'count': 0, 'total_score': 0, 'entries': []})
        for e in entries_data:
            for term, score in e['drivers']:
                all_drivers[term]['count'] += 1
                all_drivers[term]['total_score'] += score
                all_drivers[term]['entries'].append(e)

        # Sort drivers by impact (total score contribution)
        top_drivers = sorted(all_drivers.items(), key=lambda x: abs(x[1]['total_score']), reverse=True)[:10]
        positive_drivers = [(k, v) for k, v in top_drivers if v['total_score'] < 0]  # Protective
        concerning_drivers = [(k, v) for k, v in top_drivers if v['total_score'] > 0]  # Risk

        # --- OVERVIEW AND CONTACT FREQUENCY ---
        narrative_parts.append("<b>REVIEW FREQUENCY AND PROFESSIONAL CONTACT</b>")

        total_contacts = len(entries_data)
        contacts_per_week = total_contacts / max(1, date_range_days / 7)

        freq_desc = ""
        if contacts_per_week >= 3:
            freq_desc = "very frequently (multiple times per week)"
        elif contacts_per_week >= 1:
            freq_desc = "regularly (approximately weekly)"
        elif contacts_per_week >= 0.5:
            freq_desc = "regularly (approximately fortnightly)"
        else:
            freq_desc = "periodically (approximately monthly)"

        narrative_parts.append(f"During the review period, {name} was seen {freq_desc} by the clinical team.")

        # Professional breakdown - narrative style
        prof_types = []
        if professional_contacts['psychiatrist']:
            prof_types.append("psychiatry")
        if professional_contacts['nursing']:
            prof_types.append("nursing")
        if professional_contacts['psychologist']:
            prof_types.append("psychology")
        if professional_contacts['social_worker']:
            prof_types.append("social work")
        if professional_contacts['occupational_therapist']:
            prof_types.append("occupational therapy")

        if prof_types:
            narrative_parts.append(f"{pronoun_cap} received input from {', '.join(prof_types[:-1])} and {prof_types[-1]}." if len(prof_types) > 1 else f"{pronoun_cap} received input from {prof_types[0]}.")

        # Contact modes - narrative style
        modes = []
        if contact_types['home_visit']:
            modes.append("home visits")
        if contact_types['clinic']:
            modes.append("clinic appointments")
        if contact_types['telephone']:
            modes.append("telephone contacts")

        if modes:
            narrative_parts.append(f"Contact was maintained through {', '.join(modes)}.")

        narrative_parts.append("")

        # --- CLINICAL THEMES (score-driven analysis) ---
        narrative_parts.append("<b>KEY CLINICAL THEMES</b>")

        # Helper to categorize terms into clinical domains
        def categorize_term(term):
            term_lower = term.lower().replace(' (absent)', '')
            # Risk/safety
            if any(r in term_lower for r in ['aggression', 'violent', 'violence', 'assault', 'restrain', 'seclusion', 'fight', 'threaten', 'threw', 'throw', 'hit', 'punch', 'kick', 'fist']):
                return 'risk_violence'
            if any(r in term_lower for r in ['self-harm', 'self harm', 'suicid', 'ligature', 'overdose', 'cutting']):
                return 'risk_self_harm'
            if any(r in term_lower for r in ['abscond', 'awol', 'missing']):
                return 'risk_absconding'
            # Mental state
            if any(r in term_lower for r in ['delusion', 'hallucin', 'paranoid', 'grandios', 'thought disorder', 'psycho', 'voices']):
                return 'psychosis'
            if any(r in term_lower for r in ['agitat', 'irrita', 'anger', 'frustrat', 'upset', 'distress']):
                return 'agitation'
            if any(r in term_lower for r in ['withdraw', 'isolat', 'mute', 'reclusive']):
                return 'withdrawal'
            # Substances
            if any(r in term_lower for r in ['drug', 'intox', 'amph', 'cocaine', 'cannabis', 'alcohol', 'substance']):
                return 'substances'
            # Engagement
            if any(r in term_lower for r in ['refus', 'decline', 'noncomplian', 'disengage']):
                return 'poor_engagement'
            if any(r in term_lower for r in ['engage', 'comply', 'cooperat', 'attend']):
                return 'good_engagement'
            # Positive/protective
            if any(r in term_lower for r in ['stable', 'settled', 'calm', 'pleasant', 'bright', 'happy', 'smile', 'polite', 'appropriate']):
                return 'positive_presentation'
            if any(r in term_lower for r in ['family', 'friend', 'support', 'visit']):
                return 'social_support'
            # Police/legal
            if any(r in term_lower for r in ['police', 'arrest', 'custody', 'officer']):
                return 'police_involvement'
            return 'other'

        # Group drivers by category, separating actual occurrences from absent (negated) ones
        category_data = defaultdict(lambda: {'terms': [], 'count': 0, 'entries': [], 'actual_entries': [], 'absent_entries': []})
        for term, data in all_drivers.items():
            cat = categorize_term(term)
            category_data[cat]['terms'].append(term)
            category_data[cat]['count'] += data['count']
            category_data[cat]['entries'].extend(data['entries'])
            # Separate actual vs absent entries
            if '(absent)' in term:
                category_data[cat]['absent_entries'].extend(data['entries'])
            else:
                category_data[cat]['actual_entries'].extend(data['entries'])

        # Build flowing narrative based on what's found
        theme_sentences = []

        # Risk themes - use actual_entries (non-negated) for incidents, absent_entries for confirmations of absence
        actual_violence = category_data['risk_violence']['actual_entries']
        absent_violence = category_data['risk_violence']['absent_entries']

        # DEBUG: Show what terms are contributing to risk_violence
        print(f"[VIOLENCE-DEBUG] risk_violence terms: {category_data['risk_violence']['terms']}")
        print(f"[VIOLENCE-DEBUG] actual_entries count: {len(actual_violence)}")
        print(f"[VIOLENCE-DEBUG] absent_entries count: {len(absent_violence)}")
        if actual_violence:
            for i, e in enumerate(actual_violence[:5]):
                print(f"[VIOLENCE-DEBUG] actual_entry {i}: {e['content'][:150]}...")

        if actual_violence:
            # There are ACTUAL incidents of violence/aggression
            count = len(actual_violence)
            sample = actual_violence[0]
            link = make_link(f"{count} occasion(s)", None, 'aggression', sample['content'][:150])
            theme_sentences.append(f"There were incidents involving aggression or challenging behaviour documented on {link}.")
        elif absent_violence:
            # Only "no aggression" type entries - this is a POSITIVE finding
            count = len(absent_violence)
            sample = absent_violence[0]
            link = make_link(f"{count} entry/entries", None, 'no aggression', sample['content'][:150])
            theme_sentences.append(f"Documentation confirms an absence of physical aggression or violence ({link}).")

        actual_self_harm = category_data['risk_self_harm']['actual_entries']
        absent_self_harm = category_data['risk_self_harm']['absent_entries']

        if actual_self_harm:
            # There are ACTUAL self-harm concerns
            count = len(actual_self_harm)
            sample = actual_self_harm[0]
            link = make_link(f"{count} entry/entries", None, 'self-harm', sample['content'][:150])
            theme_sentences.append(f"Self-harm related concerns were documented in {link}.")
        elif absent_self_harm:
            # Only "no self-harm" type entries - this is a POSITIVE finding
            count = len(absent_self_harm)
            sample = absent_self_harm[0]
            link = make_link(f"{count} entry/entries", None, 'no self-harm', sample['content'][:150])
            theme_sentences.append(f"Records confirm no self-harm concerns during this period ({link}).")

        # Scan ALL entries for police keywords (not just score drivers) to match click handler
        police_keywords = ['police', 'officer', 'arrest', 'custody', '999', 'emergency services']

        def is_police_negated(text, kw):
            """Check if police keyword is in a non-incident context."""
            police_negation_patterns = [
                # Basic negation
                r'\b(no|nil|without)\s+[^.]*' + re.escape(kw),
                r'\bno\s+(further\s+)?contact\s+with\s+' + re.escape(kw),
                # Care plan / protocol language - NOT actual incidents
                r'\b' + re.escape(kw) + r'\s+to\s+be\s+called\b',
                r'\bcall(ing)?\s+(the\s+)?' + re.escape(kw) + r'\s+(if|when|as)\b',
                r'\bif\s+[^.]*' + re.escape(kw) + r'\s+(to\s+be\s+)?called\b',
                r'\bif\s+(threats?|incidents?|aggression)[^.]*' + re.escape(kw),
                r'\bemergenc(y|ies)\s+' + re.escape(kw),
                # Conditional / hypothetical
                r'\bif\s+[^.]{0,50}\b' + re.escape(kw),
                r'\bshould\s+[^.]*' + re.escape(kw),
                r'\bmay\s+need\s+[^.]*' + re.escape(kw),
                # Fear of police - patient's feelings, not incident
                r'\bfear\s+(of\s+)?(the\s+)?' + re.escape(kw),
                r'\bscared\s+(of\s+|when\s+)[^.]*' + re.escape(kw),
                r'\bafraid\s+(of\s+)?' + re.escape(kw),
                r'\banxious\s+(about\s+|around\s+)?' + re.escape(kw),
                # History / risk assessment mentions
                r'\bhistory\s+(of\s+)?[^.]*' + re.escape(kw),
                r'\bprevious(ly)?\s+[^.]*' + re.escape(kw) + r'\s+contact',
                r'\brisks?\s*:\s*[^.]*' + re.escape(kw),
                r'\brelapse\s+indicators?\b[^.]*' + re.escape(kw),
                # Delusions about police
                r'\bdelusion[^.]*' + re.escape(kw),
                r'\bbelie(ve|f)[^.]*' + re.escape(kw) + r'\s+(coming|after|watching)',
                r'\b' + re.escape(kw) + r'\s+(coming|after|watching)\s+(her|him|them)',
            ]
            for pattern in police_negation_patterns:
                if re.search(pattern, text, re.IGNORECASE):
                    return True
            return False

        police_entries = []
        for e in entries_data:
            cl = e['content_lower']
            # Use word boundary matching to avoid substring matches
            if any(re.search(r'\b' + re.escape(kw) + r'\b', cl) for kw in police_keywords):
                # Skip if negated or in non-incident context
                negated = False
                for kw in police_keywords:
                    if re.search(r'\b' + re.escape(kw) + r'\b', cl) and is_police_negated(cl, kw):
                        negated = True
                        break
                if not negated:
                    police_entries.append(e)

        if police_entries:
            count = len(police_entries)
            sample = police_entries[0]
            link = make_link(f"{count} entry/entries", None, 'police', sample['content'][:150])
            theme_sentences.append(f"Police involvement or contact was referenced in {link}.")

        # Scan ALL entries for substance keywords (not just score drivers) to match click handler
        substance_keywords = ['drug', 'substance', 'cannabis', 'alcohol', 'cocaine', 'heroin', 'intox', 'amphetamine', 'meth']

        def is_substance_negated(text, kw):
            """Check if substance keyword is in a non-incident context."""
            substance_negation_patterns = [
                # Basic negation / denial
                r'\b(no|nil|denies|denied|abstain|abstinent|negative)\s+[^.]*' + re.escape(kw),
                r'\bnot\s+(using|taking|drinking)\s+[^.]*' + re.escape(kw),
                r'\bstopped\s+(using|taking|drinking)\s+' + re.escape(kw),
                r'\bgave\s+up\s+' + re.escape(kw),
                r'\bquit\s+' + re.escape(kw),
                # Risk assessment / history mentions
                r'\bhistory\s+(of\s+)?' + re.escape(kw),
                r'\bprevious\s+' + re.escape(kw),
                r'\bpast\s+' + re.escape(kw) + r'\s+use',
                r'\brisks?\s*:\s*[^.]*' + re.escape(kw),
                r'\brelapse\s+indicators?\b[^.]*' + re.escape(kw),
                r'\bwarning\s+signs?\b[^.]*' + re.escape(kw),
                # Medication context (not substance misuse)
                r'\bprescribed\s+' + re.escape(kw),
                r'\bmedication\s+[^.]*' + re.escape(kw),
                # Education / advice context
                r'\badvised\s+(about|regarding|on)\s+' + re.escape(kw),
                r'\beducation\s+(about|on|regarding)\s+' + re.escape(kw),
                r'\bdiscussed\s+[^.]*' + re.escape(kw) + r'\s+(risks?|harm|use)',
                # Conditional / hypothetical
                r'\bif\s+[^.]{0,50}\b' + re.escape(kw),
                r'\bmay\s+lead\s+to\s+' + re.escape(kw),
                r'\bcan\s+cause\s+' + re.escape(kw),
                # Test results (negative)
                r'\b' + re.escape(kw) + r'\s*[:-]?\s*(negative|clear|nil)',
                r'\bnegative\s+(for\s+)?' + re.escape(kw),
                # Clean / sober
                r'\bclean\s+(from\s+)?' + re.escape(kw),
                r'\bsober\b[^.]*' + re.escape(kw),
                r'\b' + re.escape(kw) + r'\s+free\b',
            ]
            for pattern in substance_negation_patterns:
                if re.search(pattern, text, re.IGNORECASE):
                    return True
            return False

        substance_entries = []
        for e in entries_data:
            cl = e['content_lower']
            # Use word boundary matching to avoid substring matches (e.g., 'meth' in 'method')
            if any(re.search(r'\b' + re.escape(kw) + r'\b', cl) for kw in substance_keywords):
                # Skip if negated or in non-incident context
                negated = False
                for kw in substance_keywords:
                    if re.search(r'\b' + re.escape(kw) + r'\b', cl) and is_substance_negated(cl, kw):
                        negated = True
                        break
                if not negated:
                    substance_entries.append(e)

        if substance_entries:
            sample = substance_entries[0]
            link = make_link("the records", None, 'drug', sample['content'][:150])
            theme_sentences.append(f"Substance use was a documented theme in {link}.")

        # Helper to extract a meaningful snippet from content around a keyword
        def extract_context_snippet(content, keywords, max_len=80):
            """Extract a short, meaningful sentence or phrase around the keyword."""
            content_lower = content.lower()
            for kw in keywords:
                pos = content_lower.find(kw)
                if pos != -1:
                    # Find sentence boundaries
                    sent_start = max(0, content.rfind('.', 0, pos) + 1)
                    sent_end = content.find('.', pos)
                    if sent_end == -1:
                        sent_end = min(len(content), pos + 100)
                    snippet = content[sent_start:sent_end].strip()
                    if len(snippet) > max_len:
                        # Truncate intelligently
                        snippet = snippet[:max_len].rsplit(' ', 1)[0] + '...'
                    return snippet
            return None

        # General negation check for mental state terms
        def is_mental_state_negated(text, keywords):
            """Check if mental state keywords are in non-incident context."""
            text_lower = text.lower()
            negation_patterns = [
                r'\b(no|nil|denied|denies|absent|without)\s+[^.]*',
                r'\bhistory\s+(of\s+)?',
                r'\brisks?\s*:\s*[^.]*',
                r'\brelapse\s+indicators?\b[^.]*',
                r'\bwarning\s+signs?\b[^.]*',
                r'\bif\s+[^.]{0,50}\b',
                r'\bcan\s+be(come)?\s+',
                r'\bmay\s+be(come)?\s+',
                r'\bmanagement\s+of\b[^.]*',
            ]
            for kw in keywords:
                if kw in text_lower:
                    for pattern in negation_patterns:
                        if re.search(pattern + re.escape(kw), text_lower, re.IGNORECASE):
                            return True
            return False

        # Mental state themes - with actual content extraction
        psychosis_actual = [e for e in category_data['psychosis']['actual_entries']
                          if not is_mental_state_negated(e.get('content', ''), ['delusion', 'hallucin', 'paranoid', 'voices', 'psycho'])]
        psychosis_absent = category_data['psychosis']['absent_entries']

        if psychosis_actual:
            sample = psychosis_actual[0]
            # Extract specific symptom mentioned
            terms_found = category_data['psychosis']['terms']
            actual_terms = [t for t in terms_found if '(absent)' not in t]
            symptom_desc = "psychotic symptoms"
            if any('delusion' in t for t in actual_terms):
                symptom_desc = "delusional beliefs"
            elif any('hallucin' in t or 'voices' in t for t in actual_terms):
                symptom_desc = "hallucinations or hearing voices"
            elif any('paranoid' in t for t in actual_terms):
                symptom_desc = "paranoid thoughts"

            link = make_link("occasions during this period", None, 'delusion', sample['content'][:150])
            snippet = extract_context_snippet(sample['content'], ['delusion', 'hallucin', 'paranoid', 'voices', 'psycho'])
            if snippet and len(snippet) > 20:
                theme_sentences.append(f"Documentation indicates {symptom_desc} on {link}, including: \"{snippet}\"")
            else:
                theme_sentences.append(f"Documentation indicates {symptom_desc} on {link}.")
        elif psychosis_absent:
            sample = psychosis_absent[0]
            link = make_link("the clinical records", None, 'no delusion', sample['content'][:150])
            theme_sentences.append(f"Psychotic symptoms were noted to be absent or well-controlled in {link}.")

        # Agitation themes - with filtering
        agitation_actual = [e for e in category_data['agitation']['actual_entries']
                          if not is_mental_state_negated(e.get('content', ''), ['agitat', 'irrita', 'frustrat', 'upset'])]

        if agitation_actual:
            sample = agitation_actual[0]
            link = make_link("occasions", None, 'agitation', sample['content'][:150])
            snippet = extract_context_snippet(sample['content'], ['agitat', 'irrita', 'frustrat', 'upset', 'distress'])
            if snippet and len(snippet) > 20:
                theme_sentences.append(f"Periods of agitation or irritability were documented on {link}: \"{snippet}\"")
            else:
                theme_sentences.append(f"Periods of agitation or irritability were documented on {link}.")

        # Withdrawal themes - with filtering
        withdrawal_actual = [e for e in category_data['withdrawal']['actual_entries']
                           if not is_mental_state_negated(e.get('content', ''), ['withdraw', 'isolat', 'mute', 'reclusive'])]

        if withdrawal_actual:
            sample = withdrawal_actual[0]
            link = make_link("occasions", None, 'withdraw', sample['content'][:150])
            snippet = extract_context_snippet(sample['content'], ['withdraw', 'isolat', 'mute', 'reclusive'])
            if snippet and len(snippet) > 20:
                theme_sentences.append(f"Social withdrawal or isolation was observed on {link}: \"{snippet}\"")
            else:
                theme_sentences.append(f"Social withdrawal or isolation was observed on {link}.")

        # Engagement themes - with filtering
        engagement_negation_patterns = [
            r'\bhistory\s+(of\s+)?',
            r'\brisks?\s*:\s*[^.]*',
            r'\brelapse\s+indicators?\b[^.]*',
            r'\bif\s+[^.]{0,50}\b',
            r'\bcan\s+',
            r'\bmay\s+',
        ]

        def is_engagement_negated(text, keywords):
            text_lower = text.lower()
            for kw in keywords:
                if kw in text_lower:
                    for pattern in engagement_negation_patterns:
                        if re.search(pattern + re.escape(kw), text_lower, re.IGNORECASE):
                            return True
            return False

        poor_engagement_actual = [e for e in category_data['poor_engagement']['actual_entries']
                                 if not is_engagement_negated(e.get('content', ''), ['refus', 'decline', 'noncomplian', 'disengage'])]

        if poor_engagement_actual:
            sample = poor_engagement_actual[0]
            link = make_link("occasions", None, 'refus', sample['content'][:150])
            snippet = extract_context_snippet(sample['content'], ['refus', 'decline', 'noncomplian', 'disengage'])
            if snippet and len(snippet) > 20:
                theme_sentences.append(f"Reduced engagement or refusal was documented on {link}: \"{snippet}\"")
            else:
                theme_sentences.append(f"Reduced engagement or refusal was documented on {link}.")

        # Positive themes - more detailed
        positive_details = []
        if category_data['positive_presentation']['actual_entries']:
            positive_details.append('stable mental state')
        if category_data['good_engagement']['actual_entries']:
            positive_details.append('good engagement with services')
        if category_data['social_support']['actual_entries']:
            positive_details.append('family/social support')

        if positive_details:
            # Get a sample entry for the link
            for cat in ['positive_presentation', 'good_engagement', 'social_support']:
                if category_data[cat]['actual_entries']:
                    sample = category_data[cat]['actual_entries'][-1]
                    link = make_link("multiple entries", None, 'stable', sample['content'][:150])
                    theme_sentences.append(f"Protective factors documented include {', '.join(positive_details)} ({link}).")
                    break

        # Output the narrative
        if theme_sentences:
            narrative_parts.append(f"Analysis of the clinical notes for {name} during this period reveals the following:")
            narrative_parts.append("")
            for sentence in theme_sentences:
                narrative_parts.append(sentence)
        else:
            narrative_parts.append(f"The clinical notes during this period were largely routine with no significant themes of concern identified.")

        narrative_parts.append("")

        # --- NARRATIVE SUMMARY ---
        # Structured around admissions with detailed content
        narrative_parts.append("<b>NARRATIVE SUMMARY</b>")
        narrative_parts.append("")

        # Build timeline using timeline_builder
        # Uses core density detection + optional external provider check
        try:
            from timeline_builder import build_timeline_with_external_check
            notes_for_timeline = [{'date': e['date'], 'datetime': e['date'], 'content': e['content'], 'text': e['content']} for e in entries_data]
            episodes = build_timeline_with_external_check(notes_for_timeline, check_external=False, debug=False)
            # DEBUG: Print all episodes detected
            print(f"[NARRATIVE-DEBUG] Timeline detected {len(episodes)} episodes:")
            for i, ep in enumerate(episodes):
                ep_type = ep.get('type', 'unknown')
                ep_start = ep.get('start')
                ep_end = ep.get('end')
                print(f"  Episode {i+1}: {ep_type} from {ep_start} to {ep_end}")
        except Exception as e:
            print(f"[TribunalProgress] Timeline build failed: {e}")
            episodes = []

        # Medication extraction with source tracking
        def extract_medications_detailed(entries):
            """Extract medications with doses and source entries."""
            meds_found = {}  # med_name -> {'dose': str, 'entry': entry}
            med_patterns = [
                (r'\b(clozapine|clozaril)\s*(\d+\s*mg(?:/day)?)?', 'Clozapine'),
                (r'\b(olanzapine|zyprexa)\s*(\d+\s*mg(?:/day)?)?', 'Olanzapine'),
                (r'\b(risperidone|risperdal)\s*(\d+\s*mg(?:/day)?)?', 'Risperidone'),
                (r'\b(aripiprazole|abilify)\s*(\d+\s*mg(?:/day)?)?', 'Aripiprazole'),
                (r'\b(quetiapine|seroquel)\s*(\d+\s*mg(?:/day)?)?', 'Quetiapine'),
                (r'\b(haloperidol|haldol)\s*(\d+\s*mg(?:/day)?)?', 'Haloperidol'),
                (r'\b(paliperidone|invega)\s*(\d+\s*mg(?:/day)?)?', 'Paliperidone'),
                (r'\b(amisulpride|solian)\s*(\d+\s*mg(?:/day)?)?', 'Amisulpride'),
                (r'\b(zuclopenthixol)\s*(\d+\s*mg(?:\s*/\s*\d+\s*weekly)?)?', 'Zuclopenthixol'),
                (r'\b(flupentixol|depixol)\s*(\d+\s*mg(?:\s*/\s*\d+\s*weekly)?)?', 'Flupentixol'),
                (r'\b(lithium)\s*(\d+\s*mg(?:/day)?)?', 'Lithium'),
                (r'\b(sodium valproate|depakote|epilim)\s*(\d+\s*mg(?:/day)?)?', 'Sodium Valproate'),
                (r'\b(carbamazepine|tegretol)\s*(\d+\s*mg(?:/day)?)?', 'Carbamazepine'),
                (r'\b(lamotrigine|lamictal)\s*(\d+\s*mg(?:/day)?)?', 'Lamotrigine'),
                (r'\b(sertraline|zoloft)\s*(\d+\s*mg(?:/day)?)?', 'Sertraline'),
                (r'\b(fluoxetine|prozac)\s*(\d+\s*mg(?:/day)?)?', 'Fluoxetine'),
                (r'\b(venlafaxine|effexor)\s*(\d+\s*mg(?:/day)?)?', 'Venlafaxine'),
                (r'\b(mirtazapine)\s*(\d+\s*mg(?:/day)?)?', 'Mirtazapine'),
                (r'\b(lorazepam|ativan)\s*(\d+\s*mg(?:\s*prn)?)?', 'Lorazepam'),
                (r'\b(diazepam|valium)\s*(\d+\s*mg(?:\s*prn)?)?', 'Diazepam'),
                (r'\b(promethazine|phenergan)\s*(\d+\s*mg(?:\s*prn)?)?', 'Promethazine'),
                (r'\b(procyclidine)\s*(\d+\s*mg)?', 'Procyclidine'),
            ]
            for e in entries:
                cl = e['content_lower']
                for pattern, med_name in med_patterns:
                    match = re.search(pattern, cl, re.IGNORECASE)
                    if match:
                        dose = match.group(2) if len(match.groups()) > 1 and match.group(2) else ''
                        if dose and (med_name not in meds_found or not meds_found[med_name]['dose']):
                            meds_found[med_name] = {'dose': dose.strip(), 'entry': e, 'keyword': med_name.lower()}
                        elif med_name not in meds_found:
                            meds_found[med_name] = {'dose': '', 'entry': e, 'keyword': med_name.lower()}
            return meds_found

        # Extract legal status with source
        def extract_legal_status(entries):
            """Extract MHA section with source entry - use word boundaries for short terms.

            Checks for CURRENT status markers like "is on", "detained under", "on a".
            Excludes future/desired status like "would like to be", "wants to be".
            Prioritizes explicit "MHA status:" declarations.
            """
            # FIRST: Look for explicit "MHA status:" declaration - this is authoritative
            for e in entries:
                cl = e['content_lower']
                # Look for "MHA status: under section X" or "MHA status: section X"
                mha_match = re.search(r'mha\s+status\s*:\s*(under\s+)?(section\s*\d+|s\.?\d+|informal)', cl)
                if mha_match:
                    status_text = mha_match.group(0)
                    if 'section 3' in status_text or 's3' in status_text or 's.3' in status_text:
                        return {'status': 'Section 3', 'entry': e, 'keyword': 'section 3'}
                    if 'section 2' in status_text or 's2' in status_text or 's.2' in status_text:
                        return {'status': 'Section 2', 'entry': e, 'keyword': 'section 2'}
                    if 'section 47' in status_text or 's47' in status_text:
                        return {'status': 'Section 47', 'entry': e, 'keyword': 'section 47'}
                    if 'section 37' in status_text or 's37' in status_text:
                        return {'status': 'Section 37', 'entry': e, 'keyword': 'section 37'}
                    if 'informal' in status_text:
                        return {'status': 'Informal', 'entry': e, 'keyword': 'informal'}

            # Future/desired markers that indicate NOT current status
            future_desire_markers = [
                'would like to be', 'wants to be', 'wish to be', 'hope to be',
                'would like to', 'wants to', 'requesting', 'request for',
                'if successful', 'if this is successful', 'may be placed',
                'considering', 'to be considered', 'will be considered',
                'recommended', 'for the future', 'will be', 'plan is',
                'the plan is', 'the plan is that', 'planning for',
                'looking at', 'proposed', 'suggests', 'suitable for',
                'would be necessary', 'agrees with', 'due to attend',
                'upon discharge', 'on discharge', 'after discharge',
                'continue upon', 'will continue', 'towards discharge',
                'work towards', 'working towards', 'remain at',
            ]

            # Historical markers - section mentioned in past context, not current
            historical_markers = [
                'was first admitted', 'first admitted', 'was transferred from',
                'transferred from prison', 'in 2001', 'in 2002', 'in 2003', 'in 2004',
                'in 2005', 'in 2006', 'in 2007', 'in 2008', 'in 2009', 'in 2010',
                'in 2011', 'in 2012', 'in 2013', 'in 2014', 'in 2015', 'in 2016',
                'historical', 'previously', 'prior to', 'background',
            ]

            # Current status markers that indicate ACTUAL current status
            current_markers = [
                'is on', 'are on', 'on a s', 'on s', 'detained under',
                'currently on', 'remains on', 'under section', 'under s',
                'is detained', 'patient is', 'status:'
            ]

            def is_current_status(text, keyword):
                """Check if the legal status keyword indicates CURRENT status."""
                # Use word boundary matching to avoid partial matches (e.g., 'cto' in 'director')
                match = re.search(r'\b' + re.escape(keyword) + r'\b', text, re.IGNORECASE)
                if not match:
                    return False

                keyword_pos = match.start()
                # Get context around keyword (100 chars before and after)
                start = max(0, keyword_pos - 100)
                end = min(len(text), keyword_pos + 100)
                context = text[start:end]

                # Check for historical markers - if found, this is NOT current
                for marker in historical_markers:
                    if marker in context:
                        return False

                # Check for future/desire markers near the keyword
                for marker in future_desire_markers:
                    if marker in context:
                        return False

                # Check for current status markers near the keyword
                for marker in current_markers:
                    if marker in context:
                        return True

                # Default: don't assume current without evidence
                return False

            # Check Section 3 FIRST (most common for treatment)
            for e in entries:
                cl = e['content_lower']
                if 'section 3' in cl or re.search(r'\bs3\b', cl):
                    if is_current_status(cl, 'section 3') or is_current_status(cl, 's3'):
                        return {'status': 'Section 3', 'entry': e, 'keyword': 'section 3'}

            # Section 2 (assessment order)
            for e in entries:
                cl = e['content_lower']
                if 'section 2' in cl or re.search(r'\bs2\b', cl):
                    if is_current_status(cl, 'section 2') or is_current_status(cl, 's2'):
                        return {'status': 'Section 2', 'entry': e, 'keyword': 'section 2'}

            for e in entries:
                cl = e['content_lower']

                # Section 47/49 (prison transfer) - only if current
                if re.search(r'\b(section\s*47|s\.?47|sec\s*47)', cl):
                    if re.search(r'\b(section\s*49|s\.?49|sec\s*49|\b49\b)', cl):
                        if is_current_status(cl, 'section 47') or is_current_status(cl, 's.47') or is_current_status(cl, 's47'):
                            return {'status': 'Section 47/49', 'entry': e, 'keyword': 'section 47'}
                    # Notional 37 (after s47 transfer)
                    if 'notional' in cl and ('37' in cl or 'section 37' in cl):
                        if is_current_status(cl, 'notional'):
                            return {'status': 'Section 47/49 (notional 37)', 'entry': e, 'keyword': 'notional 37'}
                    if is_current_status(cl, 'section 47') or is_current_status(cl, 's.47') or is_current_status(cl, 's47'):
                        return {'status': 'Section 47', 'entry': e, 'keyword': 'section 47'}

                # Section 37/41 (court order with restrictions)
                if 'section 37' in cl or re.search(r'\bs37\b', cl):
                    if 'section 41' in cl or re.search(r'\bs41\b', cl):
                        if is_current_status(cl, 'section 37') or is_current_status(cl, 's37'):
                            return {'status': 'Section 37/41', 'entry': e, 'keyword': 'section 37'}
                    if is_current_status(cl, 'section 37') or is_current_status(cl, 's37'):
                        return {'status': 'Section 37', 'entry': e, 'keyword': 'section 37'}

                # Section 2 (assessment order)
                if 'section 2' in cl or re.search(r'\bs2\b', cl):
                    if is_current_status(cl, 'section 2') or is_current_status(cl, 's2'):
                        return {'status': 'Section 2', 'entry': e, 'keyword': 'section 2'}

                # CTO (Community Treatment Order)
                if re.search(r'\bcto\b', cl) or 'community treatment order' in cl:
                    if is_current_status(cl, 'cto') or is_current_status(cl, 'community treatment order'):
                        return {'status': 'CTO', 'entry': e, 'keyword': 'cto'}

                # Informal - be very careful, must be ACTUAL current status
                if re.search(r'\binformal\b', cl):
                    # Require strong current markers for informal
                    informal_current = [
                        'is informal', 'are informal', 'admitted informal',
                        'informal patient', 'informal admission', 'now informal',
                        'currently informal', 'remains informal', 'status: informal'
                    ]
                    if any(marker in cl for marker in informal_current):
                        return {'status': 'Informal', 'entry': e, 'keyword': 'informal'}
                    # Don't detect "would like to be informal" etc.

            return None

        # Extract symptoms/presentation with sources
        def extract_presentation(entries):
            """Extract key symptoms with source entries."""
            symptoms = {}  # symptom -> {'entry': e, 'keyword': kw}
            symptom_map = {
                'paranoid': 'paranoid ideation', 'paranoia': 'paranoid ideation',
                'delusion': 'delusional beliefs', 'delusional': 'delusional beliefs',
                'hallucin': 'hallucinations', 'voices': 'auditory hallucinations',
                'agitat': 'agitation', 'distress': 'distress',
                'low mood': 'low mood', 'depressed': 'depressed mood',
                'elated': 'elated mood', 'manic': 'manic symptoms',
                'withdrawn': 'social withdrawal', 'isolat': 'isolation',
                'anxious': 'anxiety', 'anxiety': 'anxiety',
            }
            for e in entries[:50]:
                cl = e['content_lower']
                for kw, symptom in symptom_map.items():
                    # Use word boundary matching to avoid "elated" matching "related"
                    if word_match(cl, kw) and not is_negated(cl, kw) and symptom not in symptoms:
                        symptoms[symptom] = {'entry': e, 'keyword': kw}
            return dict(list(symptoms.items())[:4])

        # Extract incidents with dates and sources - with nuanced context detection
        def extract_incidents_detailed(entries, keywords, incident_type):
            """Extract actual incidents, filtering out improvement statements, risk discussions, and historical mentions."""
            incidents = []
            seen_dates = set()

            # Patterns that indicate this is NOT an actual incident
            non_incident_patterns = [
                # Improvement / reduction language
                r'\b(has|have)\s+(reduced|decreased|stopped|ceased|improved)',
                r'\b(is|are)\s+(reducing|decreasing|improving|lessening)',
                r'\bno\s+longer\b',
                r'\bstopped\s+(the\s+)?',
                r'\breduced\s+(significantly|greatly|considerably)',
                r'\bimprovement\s+in\b',
                r'\bless\s+(frequent|severe|intense)',
                r'\bminimal\b',
                r'\brare(ly)?\b',
                # Progress / engagement language
                r'\bengaging\s+with\b',
                r'\bworking\s+on\b',
                r'\baddressing\b',
                r'\bdiscussed\b',
                r'\bexplored\b',
                r'\btalked\s+about\b',
                r'\bprocessing\b',
                r'\btherapy\s+(for|around|regarding)\b',
                r'\bpsychological\s+work\b',
                # Risk assessment / discussion language
                r'\brisk\s+(of|for|assessment)\b',
                r'\bhistory\s+of\b',
                r'\bprevious(ly)?\b',
                r'\bpast\s+(history|episodes?)\b',
                r'\bbackground\s+of\b',
                r'\bknown\s+to\b',
                r'\brisks?\s*:\s*',
                r'\bto\s+(self|others?)\s*:\s*',
                # Historical year references - "in 2006", "in 2006-7", "back in 2010", "even in 2008"
                r'\b(in|back\s+in|even\s+in|during)\s+(19|20)\d{2}(-\d{1,2})?\b',
                r'\b(since|from)\s+(19|20)\d{2}\b',
                r'\bwas\s+still\b',  # "was still harming" implies historical narrative
                r'\bat\s+that\s+time\b',
                r'\bat\s+the\s+time\b',
                r'\bin\s+those\s+days\b',
                # Denial / absence
                r'\bno\s+(recent\s+)?(episodes?|incidents?|acts?)\s+of\b',
                r'\bdenies\b',
                r'\bdenied\b',
                r'\bnil\b',
                r'\babsent\b',
                r'\bwithout\b',
                # Care plan / management language
                r'\bmanagement\s+(of|plan)\b',
                r'\bsafeguarding\b',
                r'\bmonitoring\b',
                r'\bobservations?\s+for\b',
                r'\brelapse\s+(prevention|indicators?|signs?)\b',
                r'\bwarning\s+signs?\b',
                r'\btriggers?\b',
                r'\bcoping\s+(strategies|skills|mechanisms)\b',
                # Support / intervention language
                r'\bsupport\s+(around|for|with)\b',
                r'\bintervention\s+for\b',
                r'\bhelp\s+with\b',
                # Conditional / hypothetical
                r'\bif\s+(she|he|they)\b',
                r'\bshould\s+(she|he|they)\b',
                r'\bwhen\s+feeling\b',
                r'\bin\s+the\s+event\b',
                # Medical items missing (not person missing) - for AWOL keyword "missing"
                r'\bsutures?\s+missing\b',
                r'\bstitche?s?\s+missing\b',
                r'\bstaples?\s+missing\b',
                r'\b(medication|meds?|tablets?|dose)\s+missing\b',
                r'\bmissing\s+(sutures?|stitche?s?|staples?|dose|medication)\b',
                r'\bwound\b.*\bmissing\b',
                r'\bmissing\b.*\bwound\b',
                # Medical "attack" (not violence) - heart attack, panic attack, etc.
                r'\bheart\s+attack\b',
                r'\bpanic\s+attack\b',
                r'\basthma\s+attack\b',
                r'\banxiety\s+attack\b',
                r'\battack\s+of\s+(asthma|anxiety|panic)\b',
            ]

            # Patterns that indicate this IS an actual incident
            actual_incident_patterns = [
                r'\b(has|have)\s+(self[- ]?harmed|cut|overdosed|ligature)',
                r'\b(was|were)\s+found\s+(with|having)',
                r'\bincident\s+(of|involving|where)',
                r'\battended\s+a&e\b',
                r'\brequired\s+(treatment|sutures|medical)',
                r'\bwounds?\b',
                r'\bcuts?\s+(to|on)\b',
                r'\bbleeding\b',
                r'\boverdose[d]?\b',
                r'\bligature[d]?\b',
                r'\btied\s+(around|to)\b',
                r'\bsecluded\b',
                r'\brestrained\b',
                r'\bassaulted\b',
                r'\bpunched\b',
                r'\bkicked\b',
                r'\bspat\b',
                r'\bthrew\b',
                r'\bsmashed\b',
                r'\babsconded\b',
                r'\bawol\b',
                r'\bleft\s+(the\s+)?(ward|unit|hospital)\s+(without|against)',
                r'\bfailed\s+to\s+return\b',
            ]

            def mentions_different_date(context, entry_date):
                """Check if context mentions a specific date different from entry date - indicates historical reference."""
                entry_year = entry_date.year
                entry_month = entry_date.month

                # Month name mapping
                month_map = {
                    'january': 1, 'jan': 1, 'february': 2, 'feb': 2, 'march': 3, 'mar': 3,
                    'april': 4, 'apr': 4, 'may': 5, 'june': 6, 'jun': 6,
                    'july': 7, 'jul': 7, 'august': 8, 'aug': 8, 'september': 9, 'sep': 9, 'sept': 9,
                    'october': 10, 'oct': 10, 'november': 11, 'nov': 11, 'december': 12, 'dec': 12
                }

                # Pattern 1: "On 2nd October 2012", "on the 15th January 2013", etc.
                date_patterns = [
                    r'\b(on|on\s+the)\s+(\d{1,2})(st|nd|rd|th)?\s+(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec)\s+(19\d{2}|20[0-3]\d)\b',
                    r'\b(\d{1,2})(st|nd|rd|th)?\s+(january|february|march|april|may|june|july|august|september|october|november|december|jan|feb|mar|apr|jun|jul|aug|sep|sept|oct|nov|dec)\s+(19\d{2}|20[0-3]\d)\b',
                    r'\b(january|february|march|april|may|june|july|august|september|october|november|december)\s+(19\d{2}|20[0-3]\d)\b',
                ]

                for pattern in date_patterns:
                    matches = re.findall(pattern, context, re.IGNORECASE)
                    for match in matches:
                        try:
                            # Extract year from match (last numeric group)
                            year_str = [m for m in match if re.match(r'^(19|20)\d{2}$', str(m))]
                            if year_str:
                                mentioned_year = int(year_str[0])
                                # Extract month from match
                                month_str = [m.lower() for m in match if m.lower() in month_map]
                                if month_str:
                                    mentioned_month = month_map[month_str[0]]
                                    # Calculate month difference
                                    month_diff = abs((entry_year * 12 + entry_month) - (mentioned_year * 12 + mentioned_month))
                                    if month_diff > 2:  # More than 2 months difference = historical
                                        print(f"[INCIDENT-DEBUG] Historical date detected: entry={entry_date.strftime('%b %Y')}, mentioned={month_str[0]} {mentioned_year}")
                                        return True
                        except:
                            pass

                # Pattern 2: Just year mentions with > 1 year difference
                year_matches = re.findall(r'\b(19\d{2}|20[0-3]\d)\b', context)
                for mentioned_year in year_matches:
                    yr = int(mentioned_year)
                    if abs(yr - entry_year) > 1:
                        print(f"[INCIDENT-DEBUG] Historical year detected: entry={entry_year}, mentioned={yr}")
                        return True

                # Pattern 3: Year ranges like "2006-7" or "2006-2007"
                range_matches = re.findall(r'\b(19\d{2}|20[0-3]\d)[-/](0?[1-9]|[12]\d|3[01]|\d{2}|\d{4})\b', context)
                for match in range_matches:
                    base_year = int(match[0])
                    if abs(base_year - entry_year) > 1:
                        print(f"[INCIDENT-DEBUG] Historical year range detected: entry={entry_year}, mentioned={base_year}")
                        return True

                return False

            for e in entries:
                cl = e['content_lower']
                content = e['content']
                entry_date = e['date']
                entry_year = entry_date.year

                for kw in keywords:
                    # Use word boundary matching to avoid "hit" matching "white"
                    kw_match = re.search(r'\b' + re.escape(kw) + r'\b', cl)
                    if not kw_match:
                        continue

                    # First check if basic negation applies
                    if is_negated(cl, kw):
                        continue

                    # Find the sentence containing the keyword
                    kw_pos = kw_match.start()
                    # Get surrounding context (100 chars before and after)
                    context_start = max(0, kw_pos - 100)
                    context_end = min(len(cl), kw_pos + len(kw) + 100)
                    context = cl[context_start:context_end]

                    # Check if context mentions a date different from entry date (historical reference)
                    if mentions_different_date(context, entry_date):
                        print(f"[INCIDENT-DEBUG] '{kw}' filtered - refers to different date in: {context[:80]}...")
                        continue

                    # Check for non-incident patterns in context
                    is_non_incident = False
                    for pattern in non_incident_patterns:
                        if re.search(pattern, context, re.IGNORECASE):
                            is_non_incident = True
                            print(f"[INCIDENT-DEBUG] '{kw}' filtered out by pattern '{pattern}' in: {context[:80]}...")
                            break

                    if is_non_incident:
                        continue

                    # Check for actual incident patterns (strong positive signal)
                    is_actual_incident = False
                    for pattern in actual_incident_patterns:
                        if re.search(pattern, context, re.IGNORECASE):
                            is_actual_incident = True
                            break

                    # If we have strong incident signals OR no non-incident signals, count it
                    if is_actual_incident or not is_non_incident:
                        date_key = e['date'].strftime('%Y-%m-%d')
                        if date_key not in seen_dates:
                            seen_dates.add(date_key)
                            incidents.append({
                                'date': e['date'],
                                'date_str': e['date'].strftime('%d %b %Y'),
                                'type': incident_type,
                                'entry': e,
                                'keyword': kw
                            })
                        break

            return incidents

        def extract_engagement_detailed(entries):
            """Extract meaningful engagement content - services, appointments, reviews."""
            engagement = []
            seen = set()

            engagement_patterns = [
                (r'\bpsycholog(y|ical|ist)\b', 'psychology', 'engaged with psychology services'),
                (r'\boccupational\s+therap(y|ist)\b|\bOT\b', 'ot', 'received occupational therapy'),
                (r'\bsocial\s+work(er)?\b', 'social_work', 'received social work support'),
                (r'\bcpa\b|\bcare\s+(programme|plan)\s+approach\b', 'cpa', 'attended CPA reviews'),
                (r'\bward\s+r(ound|eview)\b', 'ward_review', 'attended ward reviews'),
                (r'\bmdt\b|\bmulti.?disciplinary\b', 'mdt', 'was discussed at MDT meetings'),
                (r'\bcare\s*co.?ordinator\b', 'care_coord', 'maintained contact with her care coordinator'),
                (r'\boutpatient\s+(appointment|clinic)\b', 'outpatient', 'attended outpatient appointments'),
                (r'\bdepot\b', 'depot', 'received depot medication'),
                (r'\bclozapine\s+clinic\b', 'clozapine_clinic', 'attended clozapine clinic appointments'),
                (r'\b(cpn|community\s+(psych|mental\s+health)\s+nurse)\b', 'cpn', 'received CPN visits'),
                (r'\brelapse\s+prevention\b', 'relapse_work', 'engaged in relapse prevention work'),
                (r'\bgroup\s+(therapy|work|session)\b', 'group', 'participated in group therapy'),
            ]

            for e in entries:
                cl = e['content_lower']
                for pattern, eng_type, description in engagement_patterns:
                    if re.search(pattern, cl, re.IGNORECASE) and eng_type not in seen:
                        seen.add(eng_type)
                        engagement.append({
                            'type': eng_type,
                            'description': description,
                            'entry': e,
                            'keyword': pattern.split(r'\b')[1] if r'\b' in pattern else eng_type
                        })
            return engagement

        def extract_mental_state_detailed(entries):
            """Extract key mental state observations."""
            observations = []
            seen = set()

            state_patterns = [
                # Positive states
                (r'\b(stable|settled|euthymic)\b', 'stable', 'remained mentally stable'),
                (r'\bcalm\s+and\s+settled\b', 'calm', 'presented as calm and settled'),
                (r'\bwell\s+(in|on)\s+(him|her|them)self\b', 'well', 'appeared well in herself'),
                (r'\bgood\s+mental\s+state\b', 'good_ms', 'maintained good mental state'),
                (r'\bcompliant\s+(with\s+)?medication\b', 'compliant', 'remained compliant with medication'),
                # More descriptive states
                (r'\b(anxious|anxiety)\b(?!.*\b(no|nil|denied|denies|without)\b)', 'anxious', 'experienced periods of anxiety'),
                (r'\b(low\s+mood|depressed)\b(?!.*\b(no|nil|denied|denies|without)\b)', 'low_mood', 'experienced low mood at times'),
                (r'\b(paranoid|suspicious)\b(?!.*\b(no|nil|denied|denies|without)\b)', 'paranoid', 'experienced some paranoid thinking'),
                (r'\bhallucination\b(?!.*\b(no|nil|denied|denies|without)\b)', 'hallucinations', 'reported some hallucinatory experiences'),
            ]

            for e in entries:
                cl = e['content_lower']
                for pattern, state_type, description in state_patterns:
                    if re.search(pattern, cl, re.IGNORECASE) and state_type not in seen:
                        # Double-check this isn't negated
                        if not is_negated(cl, state_type):
                            seen.add(state_type)
                            observations.append({
                                'type': state_type,
                                'description': description,
                                'entry': e,
                                'keyword': state_type
                            })
            return observations

        def extract_leave_detailed(entries):
            """Extract leave arrangements."""
            leave_info = []
            seen = set()

            leave_patterns = [
                (r'\b(s\.?17|section\s*17)\s*(leave)?\s*(granted|approved|utilised|used)\b', 's17', 'utilised Section 17 leave'),
                (r'\bescorted\s+leave\b', 'escorted', 'benefited from escorted leave'),
                (r'\bunescorted\s+leave\b', 'unescorted', 'progressed to unescorted leave'),
                (r'\bground\s+leave\b', 'ground', 'had access to ground leave'),
                (r'\bcommunity\s+leave\b', 'community_leave', 'had periods of community leave'),
                (r'\bhome\s+leave\b', 'home_leave', 'had regular home leave'),
                (r'\b(leave\s+to|visited)\s+(family|home)\b', 'family_visit', 'visited family'),
            ]

            for e in entries:
                cl = e['content_lower']
                for pattern, leave_type, description in leave_patterns:
                    if re.search(pattern, cl, re.IGNORECASE) and leave_type not in seen:
                        seen.add(leave_type)
                        leave_info.append({
                            'type': leave_type,
                            'description': description,
                            'entry': e,
                            'keyword': leave_type
                        })
            return leave_info

        # Get entries within date range
        def get_entries_in_range(start_date, end_date):
            result = []
            for e in entries_data:
                d = e['date']
                if hasattr(d, 'date'):
                    d = d.date()
                s = start_date.date() if hasattr(start_date, 'date') else start_date
                en = end_date.date() if hasattr(end_date, 'date') else end_date
                if s <= d <= en:
                    result.append(e)
            # Sort by date so first_entry is actually the earliest
            result.sort(key=lambda x: x['date'] if x.get('date') else datetime.min)
            return result

        # Function to find ACTUAL discharge evidence - must be explicit
        def find_discharge_evidence(entries, window_days=14):
            """
            Find explicit discharge evidence in entries.
            Returns the entry with discharge evidence, or None if not found.

            MUST have explicit discharge language, not just planning/viewing.
            """
            # Explicit discharge markers - these prove discharge happened
            # Must be specific to avoid matching "discharge summary from Plastics"
            discharge_markers = [
                'was discharged', 'has been discharged', 'patient discharged',
                'discharged today', 'discharged on', 'discharged from the ward',
                'discharged from hospital', 'discharged to', 'left the ward',
                'left the unit', 'transferred to community', 'transferred to the community',
                'moved to supported', 'moved to accommodation', 'discharge completed',
            ]

            # NOT discharge - these are planning or documents, not actual discharge
            not_discharge_markers = [
                'view accommodation', 'viewing accommodation', 'view places',
                'potential accommodation', 'potential placement',
                'discharge planning', 'planning for discharge', 'plan for discharge',
                'towards discharge', 'work towards', 'working towards',
                'if discharged', 'when discharged', 'upon discharge planning',
                'prior to discharge', 'before discharge',
                'discharge summary from', 'copies of discharge', 'copy of discharge',
                'discharge summary attached', 'referral letter',
            ]

            for e in entries:
                content_lower = e.get('content_lower', e.get('content', '').lower())

                # Check for NOT discharge markers first
                if any(marker in content_lower for marker in not_discharge_markers):
                    continue

                # Check for explicit discharge markers
                if any(marker in content_lower for marker in discharge_markers):
                    return e

            return None

        def is_community_planning_only(entries):
            """
            Check if entries are about PLANNING for community, not BEING in community.
            Returns True if this looks like discharge planning while still inpatient.
            """
            planning_markers = [
                'view accommodation', 'viewing accommodation', 'view places',
                'potential accommodation', 'potential placement', 'potential supported',
                'consider for', 'considered for', 'being considered',
                'discharge planning', 'planning for discharge', 'plan for discharge',
                'towards discharge', 'work towards', 'working towards',
                'dates in mind', 'come up and view', 'come and view',
                'focused on 24 hour support', '24 hour support',
                'will be discussing', 'meet with', 'copied in',
            ]

            # Check all entries - if majority mention planning, it's planning not actual community
            planning_count = 0
            for e in entries:
                content_lower = e.get('content_lower', e.get('content', '').lower())
                if any(marker in content_lower for marker in planning_markers):
                    planning_count += 1

            # If any entries have planning language and no discharge evidence, it's planning
            if planning_count > 0:
                discharge = find_discharge_evidence(entries)
                if not discharge:
                    return True

            return False

        def find_admission_evidence(entries, min_evidence_count=3):
            """
            Find STRONG admission evidence in entries.
            Returns (has_strong_evidence, admission_entry) tuple.

            Strong evidence requires either:
            1. Admission clerking note, OR
            2. At least min_evidence_count entries with CURRENT admission language

            EXCLUDES:
            - CPA notes (these are reviews, not admissions)
            - Historical incident descriptions with past dates
            - "will remain" / "continues" language (already admitted)
            - Emails and planning documents
            """
            # Strong admission markers - these prove admission happened TODAY
            strong_admission_markers = [
                'admission clerking', 'clerking note', 'admission assessment',
                'admitted to ward today', 'admitted to the ward today',
                'patient admitted today', 'was admitted today',
                'nursing admission', 'admission documentation',
                'accepted to ward', 'accepted onto ward',
            ]

            # Weak admission markers - need multiple CURRENT mentions to count
            weak_admission_markers = [
                'admitted to ward', 'admitted to the ward', 'admitted onto ward',
                'patient admitted', 'was admitted',
            ]

            # NOT admission evidence - these indicate it's NOT a new admission
            # Be VERY targeted to avoid excluding valid admissions
            not_admission_markers = [
                # Email markers - these are correspondence, not admission notes
                'kind regards', 'best wishes', 'many thanks',
                'mailto:', '.co.uk', '.nhs.uk',
                # CPA markers - these are REVIEWS of existing admissions, not new admissions
                'cpa at', 'cpa review', 'cpa meeting', 'cpa will be uploaded',
                # Already at location markers
                'will remain at', 'remains at st andrew', 'continues at',
                'continue to work towards discharge',
                # NON-psychiatric admissions (surgery, A&E, general hospital visits)
                'orthopaedic', 'orthopedic', 'day surgery', 'day case', 'surgical procedure',
                'surgery to remove', 'a&e', 'accident and emergency', 'emergency department',
                'plastics', 'dermatology', 'cardiology', 'gastro', 'gynae', 'maternity',
                'dental', 'ophthalmology', 'ent', 'urology', 'radiology', 'x-ray', 'mri', 'ct scan',
                'outpatient appointment', 'clinic appointment', 'general aesthetic', 'general anaesthetic',
                'recovery unit', 'wound culture', 'pen refill', 'foreign object',
            ]

            strong_evidence_entry = None
            weak_evidence_count = 0
            first_weak_entry = None

            for e in entries:
                content_lower = e.get('content_lower', e.get('content', '').lower())

                # Skip if this looks like NOT an admission
                if any(marker in content_lower for marker in not_admission_markers):
                    continue

                # Check for strong admission markers
                if any(marker in content_lower for marker in strong_admission_markers):
                    strong_evidence_entry = e
                    return (True, e)

                # Check for weak admission markers
                if any(marker in content_lower for marker in weak_admission_markers):
                    weak_evidence_count += 1
                    if not first_weak_entry:
                        first_weak_entry = e

            # If we have enough weak evidence, consider it valid
            if weak_evidence_count >= min_evidence_count:
                return (True, first_weak_entry)

            return (False, first_weak_entry)

        # Varied intro phrases
        admission_intros = [
            "{name} was admitted on {date}",
            "An admission commenced on {date}",
            "{name} required admission on {date}",
            "Hospital admission occurred on {date}",
        ]
        # Phrases for when we have discharge evidence
        discharge_confirmed_intros = [
            "{name} was discharged to the community on {date}",
            "Following discharge on {date}, {name} was supported in the community",
        ]
        # Phrases for when we DON'T have clear discharge evidence but patient seems to be in community
        community_no_discharge_intros = [
            "{name} was in the community from {date}",
            "From {date}, {name} was supported in the community",
        ]
        # Phrases for when entries are about PLANNING for community, not being in community
        community_planning_intros = [
            "By {date}, discharge planning had commenced for {name}",
            "By {date}, {name} was being considered for community placement",
        ]
        stable_phrases = [
            "presented as settled and stable",
            "remained mentally stable",
            "was noted to be well and settled",
            "showed good mental stability",
        ]
        admission_idx = 0
        community_idx = 0
        stable_idx = 0

        # Process episodes chronologically
        if episodes:
            for i, ep in enumerate(episodes):
                ep_type = ep.get('type', '')
                start = ep.get('start')
                end = ep.get('end')

                if not start or not end:
                    continue

                start_d = start.date() if hasattr(start, 'date') else start
                end_d = end.date() if hasattr(end, 'date') else end
                duration_days = (end_d - start_d).days

                ep_entries = get_entries_in_range(start, end)

                # For community periods with no entries, still mention them briefly
                if not ep_entries:
                    if ep_type == 'community' and duration_days >= 7:
                        # At least mention the community period exists
                        weeks = round(duration_days / 7)
                        months = round(duration_days / 30)
                        if duration_days > 60:
                            duration_str = f"approximately {months} month{'s' if months > 1 else ''}"
                        elif duration_days > 21:
                            duration_str = f"approximately {weeks} weeks"
                        else:
                            duration_str = f"{duration_days} days"
                        narrative_parts.append(f"{name} was in the community for {duration_str} (from {start_d.strftime('%d %B %Y')} to {end_d.strftime('%d %B %Y')}). No clinical entries were documented during this period.")
                        narrative_parts.append("")
                    continue

                # REFINE admission date by searching for clerking notes within 2-week window
                # (Same logic as GPR Section 6)
                # REFINE admission date by searching for clerking notes within 2-week window
                refined_admission_entry = None  # Store the refined admission entry for later use
                if ep_type == 'inpatient':
                    ADMISSION_KEYWORDS = [
                        "admission to ward", "admitted to ward", "admitted to the ward",
                        "brought to ward", "brought to the ward", "arrived on ward",
                        "transferred to ward", "on admission", "admission clerking", "clerking",
                        "duty doctor admission", "admission note", "admitted under",
                        "nursing admission", "admission assessment", "initial assessment",
                        "ward admission", "new admission", "patient admitted",
                    ]
                    # Exclusions - these indicate NON-psychiatric admissions (surgery, A&E, etc.)
                    ADMISSION_EXCLUSIONS = [
                        "orthopaedic", "orthopedic", "day surgery", "day case", "surgical procedure",
                        "surgery to remove", "a&e", "accident and emergency", "emergency department",
                        "general hospital", "north mid", "rfh", "royal free", "uclh", "barnet hospital",
                        "whittington", "chase farm hospital staff",  # Staff escorting to another hospital
                        "plastics", "dermatology", "cardiology", "gastro", "gynae", "maternity",
                        "dental", "ophthalmology", "ent", "urology", "radiology", "x-ray", "mri", "ct scan",
                        "outpatient appointment", "clinic appointment", "follow up appointment",
                        "pen refill", "foreign object", "general aesthetic", "general anaesthetic",
                        "recovery unit", "wound culture", "dressing", "stitched",
                    ]
                    window_end = start_d + timedelta(days=14)

                    # Find first entry with admission keywords in 2-week window
                    for e in sorted(ep_entries, key=lambda x: x['date'])[:30]:  # Check first 30 entries
                        e_date = e['date'].date() if hasattr(e['date'], 'date') else e['date']
                        if start_d <= e_date <= window_end:
                            content_lower = e.get('content_lower', e.get('content', '').lower())
                            # Skip if contains exclusion terms (non-psychiatric admission)
                            if any(excl in content_lower for excl in ADMISSION_EXCLUSIONS):
                                continue
                            if any(kw in content_lower for kw in ADMISSION_KEYWORDS):
                                # Found clerking note - refine admission date and store entry
                                start_d = e_date
                                start = e['date']
                                duration_days = (end_d - start_d).days
                                refined_admission_entry = e  # Store for use in narrative
                                print(f"[NARRATIVE] Refined admission date to {start_d} based on clerking note")
                                break

                # REFINE discharge date by searching for discharge notes within window
                # 1 week before and 2 weeks after the timeline-detected discharge date
                refined_discharge_entry = None  # Store the refined discharge entry for later use
                if ep_type == 'inpatient':
                    DISCHARGE_KEYWORDS = [
                        "discharged from the ward", "discharged from ward", "discharged today",
                        "discharge from ward", "discharge from the ward",
                        "discharged to the community", "discharged to community",
                        "discharged home", "discharged to", "patient discharged",
                        "discharge cpa", "discharge planning meeting", "discharge meeting",
                        "date of discharge", "final discharge", "left the ward",
                        "transferred to community", "transfer to community team",
                        "handed over to community", "community follow up arranged",
                    ]
                    # Search window: 1 week before to 2 weeks after
                    window_start = end_d - timedelta(days=7)
                    window_end = end_d + timedelta(days=14)

                    # Find discharge entry in window - search from end backwards
                    for e in sorted(ep_entries, key=lambda x: x['date'], reverse=True):
                        e_date = e['date'].date() if hasattr(e['date'], 'date') else e['date']
                        if window_start <= e_date <= window_end:
                            content_lower = e.get('content_lower', e.get('content', '').lower())
                            if any(kw in content_lower for kw in DISCHARGE_KEYWORDS):
                                # Found discharge note - refine discharge date and store entry
                                end_d = e_date
                                end = e['date']
                                duration_days = (end_d - start_d).days
                                refined_discharge_entry = e  # Store for use in narrative
                                print(f"[NARRATIVE] Refined discharge date to {end_d} based on discharge note")
                                break

                # Extract data for this episode
                meds = extract_medications_detailed(ep_entries)
                legal_info = extract_legal_status(ep_entries)
                symptoms = extract_presentation(ep_entries)

                sh_incidents = extract_incidents_detailed(ep_entries, risk_self_harm, 'self-harm')
                violence_incidents = extract_incidents_detailed(ep_entries, risk_violence, 'aggression')
                abscond_incidents = extract_incidents_detailed(ep_entries, risk_absconding, 'AWOL')
                all_incidents = sh_incidents + violence_incidents + abscond_incidents
                all_incidents.sort(key=lambda x: x['date'])

                ep_narrative = []

                # Get first entry for admission date reference
                first_entry = ep_entries[0] if ep_entries else None

                if ep_type == 'inpatient':
                    # ADMISSION NARRATIVE
                    admission_idx += 1

                    # Add numbered admission header in bold
                    ordinal_words = {1: "First", 2: "Second", 3: "Third", 4: "Fourth", 5: "Fifth",
                                     6: "Sixth", 7: "Seventh", 8: "Eighth", 9: "Ninth", 10: "Tenth"}
                    ordinal = ordinal_words.get(admission_idx, f"{admission_idx}th")
                    ep_narrative.append(f"<b>{ordinal} Admission</b>")

                    # Check if this is an external provider admission
                    is_external = ep.get('external', False)
                    external_provider = ep.get('provider', '')

                    # Validate admission evidence - prefer refined entry if available
                    has_strong_evidence, admission_entry = find_admission_evidence(ep_entries)

                    # Use refined admission entry if available, else admission_entry, else first entry
                    link_entry = refined_admission_entry or admission_entry or first_entry
                    if refined_admission_entry:
                        has_strong_evidence = True  # Refined entry is strong evidence

                    if is_external and external_provider and first_entry:
                        # External provider admission - use specific language
                        date_link = make_link(start_d.strftime('%d %B %Y'), start, external_provider.lower(), first_entry['content'][:200])
                        ep_narrative.append(f"{name} was placed at {external_provider} from {date_link}.")
                    elif has_strong_evidence and link_entry:
                        # Strong admission evidence - use admission language (use refined start date)
                        date_link = make_link(start_d.strftime('%d %B %Y'), start, 'admitted', link_entry['content'][:200])
                        intro_phrases = [
                            f"{name} was admitted on {date_link}.",
                            f"An admission commenced on {date_link}.",
                            f"{name} required hospital admission on {date_link}.",
                        ]
                        ep_narrative.append(intro_phrases[admission_idx % len(intro_phrases)])
                    elif first_entry:
                        # No strong admission evidence - use cautious language
                        # Check if entries suggest inpatient care (ward entries, etc.)
                        ward_evidence = any(
                            any(ind in e.get('content_lower', e.get('content', '').lower())
                                for ind in ['ward round', 'on the ward', 'on ward', 'nursing entry', 'ward manager', 'ward doctor'])
                            for e in ep_entries[:10]  # Check first 10 entries
                        )
                        date_link = make_link(start_d.strftime('%d %B %Y'), start, 'records', first_entry['content'][:200])
                        if ward_evidence:
                            # Evidence suggests inpatient stay
                            ep_narrative.append(f"{name} was an inpatient from {date_link}.")
                        else:
                            # Less certain - use neutral language
                            ep_narrative.append(f"An admission commenced on {date_link}.")

                    # Continue with rest of inpatient narrative regardless of evidence strength

                    # Legal status with reference - use appropriate language
                    if legal_info:
                        status_entry = legal_info['entry']
                        status = legal_info['status']
                        status_link = make_link(status, status_entry['date'], legal_info['keyword'], status_entry['content'][:200])

                        # CTO cannot be used for hospital detention - skip if detected
                        if status == 'CTO':
                            pass  # CTO is community-based, not for hospital admission
                        elif status == 'Informal':
                            ep_narrative.append(f"{pronoun_cap} was admitted as an informal patient.")
                        elif 'Section' in status:
                            ep_narrative.append(f"{pronoun_cap} was detained under {status_link}.")

                    # Presenting symptoms with references
                    if symptoms:
                        symptom_links = []
                        for symp, info in symptoms.items():
                            symp_link = make_link(symp, info['entry']['date'], info['keyword'], info['entry']['content'][:200])
                            symptom_links.append(symp_link)
                        ep_narrative.append(f"At presentation, {pronoun} exhibited {', '.join(symptom_links)}.")

                    # Duration with end date reference - use refined discharge entry if available
                    # Otherwise fall back to find_discharge_evidence
                    discharge_entry = refined_discharge_entry or (find_discharge_evidence(ep_entries[-20:]) if len(ep_entries) > 0 else None)

                    if duration_days > 30:
                        # Use proper rounding for months (58 days = ~2 months, not 1)
                        months = round(duration_days / 30)
                        if months < 1:
                            months = 1
                        if discharge_entry:
                            # Use end_d (which may be refined) for display, and discharge_entry for link target
                            end_link = make_link(end_d.strftime('%d %B %Y'), end, 'discharged', discharge_entry['content'][:200])
                            ep_narrative.append(f"This admission lasted approximately {months} month{'s' if months > 1 else ''} (until {end_link}).")
                        else:
                            ep_narrative.append(f"This admission lasted approximately {months} month{'s' if months > 1 else ''} (until {end_d.strftime('%d %B %Y')}).")
                    else:
                        if discharge_entry:
                            end_link = make_link(end_d.strftime('%d %B %Y'), end, 'discharged', discharge_entry['content'][:200])
                            ep_narrative.append(f"The admission lasted {duration_days} days (until {end_link}).")
                        else:
                            ep_narrative.append(f"The admission lasted {duration_days} days (until {end_d.strftime('%d %B %Y')}).")

                    # Medications with references
                    if meds:
                        med_links = []
                        for med_name, info in sorted(meds.items())[:4]:
                            med_text = f"{med_name} {info['dose']}".strip() if info['dose'] else med_name
                            med_link = make_link(med_text, info['entry']['date'], info['keyword'], info['entry']['content'][:200])
                            med_links.append(med_link)
                        ep_narrative.append(f"Medication during this admission included {', '.join(med_links)}.")

                    # Incidents - summarize narratively for many, list for few
                    if all_incidents:
                        # Helper to describe count without exact numbers
                        def describe_count(count):
                            if count > 50:
                                return "multiple"
                            elif count > 10:
                                return "many"
                            elif count > 3:
                                return "some"
                            elif count > 1:
                                return "a few"
                            else:
                                return "one"

                        # Count incidents by type
                        sh_incidents = [i for i in all_incidents if i['type'] == 'self-harm']
                        agg_incidents = [i for i in all_incidents if i['type'] == 'aggression']
                        awol_incidents = [i for i in all_incidents if i['type'] == 'AWOL']

                        if len(all_incidents) > 30:
                            # Many incidents - provide narrative summary
                            incident_narrative = []

                            # Self-harm summary
                            if sh_incidents:
                                sh_count = len(sh_incidents)
                                sh_desc = describe_count(sh_count)
                                sh_link = make_multi_link(f"{sh_desc} self-harm concerns", sh_incidents, 'self-harm')
                                if sh_count > 50:
                                    incident_narrative.append(f"frequent {sh_link} throughout the admission")
                                elif sh_count > 20:
                                    incident_narrative.append(f"repeated {sh_link}")
                                else:
                                    incident_narrative.append(f"{sh_link}")

                            # Aggression summary
                            if agg_incidents:
                                agg_count = len(agg_incidents)
                                agg_desc = describe_count(agg_count)
                                agg_link = make_multi_link(f"{agg_desc} aggression concerns", agg_incidents, 'aggression')
                                if agg_count > 100:
                                    incident_narrative.append(f"persistent {agg_link}")
                                elif agg_count > 50:
                                    incident_narrative.append(f"frequent {agg_link}")
                                elif agg_count > 20:
                                    incident_narrative.append(f"regular {agg_link}")
                                else:
                                    incident_narrative.append(f"{agg_link}")

                            # AWOL summary
                            if awol_incidents:
                                awol_count = len(awol_incidents)
                                awol_desc = describe_count(awol_count)
                                awol_link = make_multi_link(f"{awol_desc} AWOL concerns", awol_incidents, 'awol')
                                incident_narrative.append(awol_link)

                            if incident_narrative:
                                ep_narrative.append(f"The admission was marked by {', '.join(incident_narrative)}.")

                                # Add description of pattern over time
                                # Convert dates for comparison
                                start_date = start_d if hasattr(start_d, 'date') else start_d
                                end_date = end_d if hasattr(end_d, 'date') else end_d
                                if hasattr(start_d, 'date'):
                                    start_date = start_d
                                else:
                                    start_date = datetime(start_d.year, start_d.month, start_d.day)
                                if hasattr(end_d, 'date'):
                                    end_date = end_d
                                else:
                                    end_date = datetime(end_d.year, end_d.month, end_d.day)

                                early_incidents = [i for i in all_incidents if (i['date'] - start_date).days < 90]
                                late_incidents = [i for i in all_incidents if (end_date - i['date']).days < 90]
                                if len(early_incidents) > len(late_incidents) * 2:
                                    ep_narrative.append(f"These concerns were most frequent in the early months of admission and reduced over time.")
                                elif len(late_incidents) > len(early_incidents) * 2:
                                    ep_narrative.append(f"Concerns increased in frequency towards the end of the admission.")
                                else:
                                    ep_narrative.append(f"Concerns remained relatively consistent throughout the admission.")
                        else:
                            # Fewer incidents - list them but group by type
                            inc_parts = []
                            if sh_incidents:
                                sh_links = [make_link(f"{i['date_str']}", i['entry']['date'], i['keyword'], i['entry']['content'][:200]) for i in sh_incidents[:5]]
                                if len(sh_incidents) > 5:
                                    inc_parts.append(f"self-harm on {', '.join(sh_links)} and {len(sh_incidents) - 5} other occasions")
                                else:
                                    inc_parts.append(f"self-harm on {', '.join(sh_links)}")
                            if agg_incidents:
                                agg_links = [make_link(f"{i['date_str']}", i['entry']['date'], i['keyword'], i['entry']['content'][:200]) for i in agg_incidents[:5]]
                                if len(agg_incidents) > 5:
                                    inc_parts.append(f"aggression on {', '.join(agg_links)} and {len(agg_incidents) - 5} other occasions")
                                else:
                                    inc_parts.append(f"aggression on {', '.join(agg_links)}")
                            if awol_incidents:
                                awol_links = [make_link(f"{i['date_str']}", i['entry']['date'], i['keyword'], i['entry']['content'][:200]) for i in awol_incidents[:3]]
                                if len(awol_incidents) > 3:
                                    inc_parts.append(f"AWOL on {', '.join(awol_links)} and {len(awol_incidents) - 3} other occasions")
                                else:
                                    inc_parts.append(f"AWOL on {', '.join(awol_links)}")
                            if inc_parts:
                                ep_narrative.append(f"Concerns during this admission included {'; '.join(inc_parts)}.")
                    else:
                        ep_narrative.append("No significant concerns were recorded during this admission.")

                    # Leave with references
                    leave_data = []
                    for le in ep_entries:
                        cl = le['content_lower']
                        if 'unescorted' in cl:
                            leave_data.append({'type': 'unescorted leave', 'entry': le, 'keyword': 'unescorted'})
                        elif 'escorted' in cl and 'unescorted' not in cl:
                            leave_data.append({'type': 'escorted leave', 'entry': le, 'keyword': 'escorted'})
                        elif 'ground leave' in cl:
                            leave_data.append({'type': 'ground leave', 'entry': le, 'keyword': 'ground leave'})
                    if leave_data:
                        # Deduplicate by type
                        seen_types = set()
                        unique_leave = []
                        for ld in leave_data:
                            if ld['type'] not in seen_types:
                                seen_types.add(ld['type'])
                                unique_leave.append(ld)
                        leave_links = [make_link(ld['type'], ld['entry']['date'], ld['keyword'], ld['entry']['content'][:200]) for ld in unique_leave]
                        ep_narrative.append(f"During this admission, {pronoun} was granted {', '.join(leave_links)}.")

                else:
                    # COMMUNITY NARRATIVE - detailed year by year for long periods
                    community_idx += 1

                    # REFINE discharge/community start date by searching for discharge notes
                    # Search 1 week before and 2 weeks after the timeline-detected start date
                    DISCHARGE_KEYWORDS_COMMUNITY = [
                        "discharged from the ward", "discharged from ward", "discharged today",
                        "discharged to the community", "discharged to community",
                        "discharged home", "discharged to", "patient discharged",
                        "was discharged", "has been discharged", "discharge cpa",
                        "left the ward", "transferred to community",
                    ]
                    window_start_comm = start_d - timedelta(days=7)
                    window_end_comm = start_d + timedelta(days=14)
                    refined_community_start_entry = None

                    for e in sorted(ep_entries, key=lambda x: x['date'])[:30]:
                        e_date = e['date'].date() if hasattr(e['date'], 'date') else e['date']
                        if window_start_comm <= e_date <= window_end_comm:
                            content_lower = e.get('content_lower', e.get('content', '').lower())
                            if any(kw in content_lower for kw in DISCHARGE_KEYWORDS_COMMUNITY):
                                # Found discharge note - refine community start date
                                start_d = e_date
                                start = e['date']
                                duration_days = (end_d - start_d).days
                                refined_community_start_entry = e
                                print(f"[NARRATIVE] Refined community start date to {start_d} based on discharge note")
                                break

                    # Introduction - check what evidence we have
                    discharge_entry = refined_community_start_entry or find_discharge_evidence(ep_entries)
                    is_planning = is_community_planning_only(ep_entries)

                    if discharge_entry:
                        # We have explicit discharge evidence - use discharge language
                        date_link = make_link(start_d.strftime('%d %B %Y'), start, 'discharged', discharge_entry['content'][:200])
                        intro_phrases = discharge_confirmed_intros
                        ep_narrative.append(intro_phrases[community_idx % len(intro_phrases)].format(name=name, date=date_link))
                    elif is_planning and first_entry:
                        # Entries are about PLANNING, not actual community - use planning language
                        date_link = make_link(start_d.strftime('%d %B %Y'), start, 'discharge planning', first_entry['content'][:200])
                        intro_phrases = community_planning_intros
                        ep_narrative.append(intro_phrases[community_idx % len(intro_phrases)].format(name=name, date=date_link))
                        # Skip the rest of community narrative for planning periods
                        continue
                    elif first_entry:
                        # No explicit discharge evidence - use neutral language
                        date_link = make_link(start_d.strftime('%d %B %Y'), start, 'community', first_entry['content'][:200])
                        intro_phrases = community_no_discharge_intros
                        ep_narrative.append(intro_phrases[community_idx % len(intro_phrases)].format(name=name, date=date_link))
                    else:
                        ep_narrative.append(f"{name} was in the community from {start_d.strftime('%d %B %Y')}.")

                    # Legal status if CTO
                    if legal_info and 'CTO' in legal_info['status']:
                        cto_link = make_link('Community Treatment Order', legal_info['entry']['date'], legal_info['keyword'], legal_info['entry']['content'][:200])
                        ep_narrative.append(f"{pronoun_cap} was managed under a {cto_link}.")

                    # For long periods (>1 year), smart grouping - only detail years with incidents
                    if duration_days > 365:
                        # Group entries by year
                        entries_by_year = defaultdict(list)
                        for e in ep_entries:
                            entries_by_year[e['date'].year].append(e)

                        years_in_episode = sorted(entries_by_year.keys())

                        # First, analyze each year to find meaningful clinical content
                        year_data = {}
                        for year in years_in_episode:
                            year_entries = entries_by_year[year]
                            year_sh = extract_incidents_detailed(year_entries, risk_self_harm, 'self-harm')
                            year_violence = extract_incidents_detailed(year_entries, risk_violence, 'aggression')
                            year_abscond = extract_incidents_detailed(year_entries, risk_absconding, 'AWOL')
                            year_incidents = year_sh + year_violence + year_abscond
                            year_incidents.sort(key=lambda x: x['date'])
                            year_meds = extract_medications_detailed(year_entries)
                            year_engagement = extract_engagement_detailed(year_entries)
                            year_mental_state = extract_mental_state_detailed(year_entries)
                            year_leave = extract_leave_detailed(year_entries)
                            year_data[year] = {
                                'incidents': year_incidents,
                                'meds': year_meds,
                                'engagement': year_engagement,
                                'mental_state': year_mental_state,
                                'leave': year_leave,
                                'entries': year_entries
                            }

                        # Mention medication once at the start if available
                        if meds:
                            med_links = []
                            for med_name, info in sorted(meds.items())[:4]:
                                med_text = f"{med_name} {info['dose']}".strip() if info['dose'] else med_name
                                med_link = make_link(med_text, info['entry']['date'], info['keyword'], info['entry']['content'][:200])
                                med_links.append(med_link)
                            ep_narrative.append(f"Medication during this period included {', '.join(med_links)}.")

                        # Output each year with meaningful content - avoid repetition by grouping thin years
                        content_free_years = []  # Years with no meaningful content at all

                        for year in years_in_episode:
                            data = year_data[year]
                            year_parts = []

                            # Engagement (psychology, OT, social work, CPA, etc.)
                            if data['engagement']:
                                eng_parts = []
                                for eng in data['engagement'][:3]:  # Max 3 engagement items
                                    eng_link = make_link(eng['description'], eng['entry']['date'], eng['keyword'], eng['entry']['content'][:200])
                                    eng_parts.append(eng_link)
                                if eng_parts:
                                    year_parts.append(', '.join(eng_parts))

                            # Mental state observations
                            if data['mental_state']:
                                ms_parts = []
                                for ms in data['mental_state'][:2]:  # Max 2 mental state items
                                    ms_link = make_link(ms['description'], ms['entry']['date'], ms['keyword'], ms['entry']['content'][:200])
                                    ms_parts.append(ms_link)
                                if ms_parts:
                                    year_parts.append(' and '.join(ms_parts))

                            # Leave arrangements
                            if data['leave']:
                                leave_parts = []
                                for lv in data['leave'][:2]:  # Max 2 leave items
                                    lv_link = make_link(lv['description'], lv['entry']['date'], lv['keyword'], lv['entry']['content'][:200])
                                    leave_parts.append(lv_link)
                                if leave_parts:
                                    year_parts.append(' and '.join(leave_parts))

                            # Incidents (if any)
                            if data['incidents']:
                                inc_parts = []
                                for inc in data['incidents']:
                                    inc_link = make_link(f"{inc['type']} ({inc['date_str']})", inc['entry']['date'], inc['keyword'], inc['entry']['content'][:200])
                                    inc_parts.append(inc_link)
                                year_parts.append(f"concerns included {', '.join(inc_parts)}")

                            # Build year narrative with flowing prose
                            if year_parts:
                                # If we have accumulated content-free years, output them first
                                if content_free_years:
                                    if len(content_free_years) == 1:
                                        ep_narrative.append(f"{name} remained stable in {content_free_years[0]}.")
                                    else:
                                        ep_narrative.append(f"{name} remained stable from {content_free_years[0]} to {content_free_years[-1]}.")
                                    content_free_years = []

                                # Build flowing narrative from year_parts
                                if len(year_parts) == 1:
                                    ep_narrative.append(f"In {year}, {name} {year_parts[0]}.")
                                elif len(year_parts) == 2:
                                    # Use 'and' for two items
                                    ep_narrative.append(f"In {year}, {name} {year_parts[0]} and {year_parts[1]}.")
                                else:
                                    # For 3+ items: combine first items with commas, last with 'and'
                                    # But also add pronouns for readability
                                    pronoun = "she" if name.endswith("a") or name in ["Mary", "Emily", "Sarah", "Lucy", "Amy", "Rachel", "Sophie", "Rebecca", "Hannah", "Emma", "Antonia"] else "he"
                                    if len(year_parts) == 3:
                                        ep_narrative.append(f"In {year}, {name} {year_parts[0]}, {year_parts[1]}, and {year_parts[2]}.")
                                    else:
                                        # 4+ items: split into two sentences for readability
                                        first_half = year_parts[:2]
                                        second_half = year_parts[2:]
                                        first_sentence = f"In {year}, {name} {first_half[0]} and {first_half[1]}."
                                        if len(second_half) == 1:
                                            second_sentence = f"{pronoun.capitalize()} also {second_half[0]}."
                                        else:
                                            second_sentence = f"{pronoun.capitalize()} also {' and '.join(second_half)}."
                                        ep_narrative.append(first_sentence + " " + second_sentence)
                            else:
                                # No meaningful content for this year - accumulate for grouping
                                content_free_years.append(year)

                        # Handle any remaining content-free years at the end
                        if content_free_years:
                            if len(content_free_years) == 1:
                                ep_narrative.append(f"{name} remained stable in {content_free_years[0]}.")
                            elif len(content_free_years) > 1:
                                ep_narrative.append(f"{name} remained stable from {content_free_years[0]} to {content_free_years[-1]}.")

                    else:
                        # Shorter period (<1 year) - still provide meaningful detail
                        if duration_days > 30:
                            months = round(duration_days / 30)
                            if months < 1:
                                months = 1
                            ep_narrative.append(f"This community period lasted approximately {months} month{'s' if months > 1 else ''}.")

                        # Medications
                        if meds:
                            med_links = []
                            for med_name, info in sorted(meds.items())[:4]:
                                med_text = f"{med_name} {info['dose']}".strip() if info['dose'] else med_name
                                med_link = make_link(med_text, info['entry']['date'], info['keyword'], info['entry']['content'][:200])
                                med_links.append(med_link)
                            ep_narrative.append(f"Medication included {', '.join(med_links)}.")

                        # Extract engagement, mental state for shorter periods too
                        period_engagement = extract_engagement_detailed(ep_entries)
                        period_mental_state = extract_mental_state_detailed(ep_entries)

                        # Services/engagement (psychology, OT, CPN, CPA, etc.)
                        if period_engagement:
                            eng_parts = []
                            seen_types = set()
                            for eng in period_engagement:
                                if eng['description'] not in seen_types:
                                    seen_types.add(eng['description'])
                                    eng_link = make_link(eng['description'], eng['entry']['date'], eng['keyword'], eng['entry']['content'][:200])
                                    eng_parts.append(eng_link)
                                    if len(eng_parts) >= 4:
                                        break
                            if eng_parts:
                                ep_narrative.append(f"During this period, {pronoun} engaged with {', '.join(eng_parts)}.")

                        # Mental state observations - positive and negative
                        if period_mental_state:
                            positive_ms = [ms for ms in period_mental_state if ms.get('valence') == 'positive']
                            negative_ms = [ms for ms in period_mental_state if ms.get('valence') == 'negative']

                            if positive_ms:
                                pos_parts = []
                                seen_pos = set()
                                for ms in positive_ms:
                                    if ms['description'] not in seen_pos:
                                        seen_pos.add(ms['description'])
                                        ms_link = make_link(ms['description'], ms['entry']['date'], ms['keyword'], ms['entry']['content'][:200])
                                        pos_parts.append(ms_link)
                                        if len(pos_parts) >= 3:
                                            break
                                if pos_parts:
                                    ep_narrative.append(f"{pronoun_cap} presented as {', '.join(pos_parts)} at times.")

                            if negative_ms:
                                neg_parts = []
                                seen_neg = set()
                                for ms in negative_ms:
                                    if ms['description'] not in seen_neg:
                                        seen_neg.add(ms['description'])
                                        ms_link = make_link(ms['description'], ms['entry']['date'], ms['keyword'], ms['entry']['content'][:200])
                                        neg_parts.append(ms_link)
                                        if len(neg_parts) >= 3:
                                            break
                                if neg_parts:
                                    ep_narrative.append(f"There were periods of {', '.join(neg_parts)}.")

                        # Check for negative events that should override "settled and stable"
                        # These are serious concerns that should be reported even if entry also contains positive words
                        negative_event_keywords = [
                            'suicidal', 'suicide', 'self-harm', 'self harm', 'overdose',
                            'dip in mental state', 'mental state deteriorated', 'deterioration',
                            'relapse', 'relapsed', 'crisis', 'required admission',
                            'sectioned', 'detained', 'psychotic', 'manic', 'very unwell',
                        ]
                        negative_entries = []
                        for e in ep_entries:
                            content_lower = e.get('content_lower', e.get('content', '').lower())
                            for kw in negative_event_keywords:
                                if kw in content_lower:
                                    # Check it's not negated - comprehensive patterns
                                    negation_patterns = [
                                        # Direct negation
                                        rf'no\s+{re.escape(kw)}', rf'nil\s+{re.escape(kw)}',
                                        rf'denies?\s+(any\s+)?{re.escape(kw)}',
                                        rf'without\s+(any\s+)?{re.escape(kw)}',
                                        # "were/was not present" patterns
                                        rf'{re.escape(kw)}[^.]*were\s+not\s+present',
                                        rf'{re.escape(kw)}[^.]*was\s+not\s+present',
                                        rf'{re.escape(kw)}[^.]*not\s+present',
                                        rf'{re.escape(kw)}[^.]*not\s+evident',
                                        rf'{re.escape(kw)}[^.]*not\s+reported',
                                        rf'{re.escape(kw)}[^.]*not\s+observed',
                                        rf'{re.escape(kw)}[^.]*not\s+noted',
                                        # "no reports of" patterns
                                        rf'no\s+reports?\s+of\s+[^.]*{re.escape(kw)}',
                                        rf'no\s+evidence\s+of\s+[^.]*{re.escape(kw)}',
                                        rf'no\s+signs?\s+of\s+[^.]*{re.escape(kw)}',
                                        # List negation: "No X or Y" or "No X, Y or Z"
                                        rf'no\s+\w+[^.]*\s+or\s+[^.]*{re.escape(kw)}',
                                        rf'no\s+[^.]*,\s*[^.]*{re.escape(kw)}',
                                        # "thoughts were not present"
                                        rf'{re.escape(kw)}\s+thoughts?\s+were\s+not',
                                        rf'{re.escape(kw)}\s+thoughts?\s+not\s+present',
                                        # Absence language
                                        rf'absence\s+of\s+[^.]*{re.escape(kw)}',
                                        rf'free\s+from\s+[^.]*{re.escape(kw)}',
                                        rf'no\s+\w+\s+symptoms?\s+or\s+reports?\s+of\s+[^.]*{re.escape(kw)}',
                                    ]
                                    kw_is_negated = any(re.search(p, content_lower) for p in negation_patterns)
                                    if not kw_is_negated:
                                        negative_entries.append({'entry': e, 'keyword': kw})
                                        break

                        # Report negative events if found - deduplicate by keyword
                        if negative_entries:
                            seen_keywords = set()
                            neg_links = []
                            for neg in negative_entries:
                                kw = neg['keyword']
                                if kw not in seen_keywords:
                                    seen_keywords.add(kw)
                                    neg_link = make_link(kw, neg['entry']['date'], kw, neg['entry']['content'][:200])
                                    neg_links.append(neg_link)
                                    if len(neg_links) >= 3:  # Limit to 3 unique
                                        break
                            ep_narrative.append(f"During this period, there were concerns including {', '.join(neg_links)}.")
                        else:
                            # Only say "settled and stable" if NO negative events found
                            stable_entries = [e for e in ep_entries if any(kw in e['content_lower'] for kw in ['stable', 'settled', 'well', 'good'])]
                            if len(stable_entries) > len(ep_entries) * 0.3 and stable_entries:
                                stable_entry = stable_entries[-1]
                                stable_link = make_link("settled and stable", stable_entry['date'], 'stable', stable_entry['content'][:200])
                                ep_narrative.append(f"During this period, {name} presented as {stable_link}.")

                        # ALL incidents (risk-specific) - grouped by type for clarity
                        if all_incidents:
                            # Group incidents by type
                            incidents_by_type = defaultdict(list)
                            for inc in all_incidents:
                                incidents_by_type[inc['type']].append(inc)

                            # Build grouped output
                            type_parts = []
                            for inc_type in ['self-harm', 'aggression', 'AWOL']:  # Consistent order
                                if inc_type in incidents_by_type:
                                    type_incidents = incidents_by_type[inc_type]
                                    date_links = []
                                    for inc in type_incidents:
                                        date_link = make_link(inc['date_str'], inc['entry']['date'], inc['keyword'], inc['entry']['content'][:200])
                                        date_links.append(date_link)
                                    type_parts.append(f"{inc_type}: {', '.join(date_links)}")

                            if type_parts:
                                ep_narrative.append(f"Risk concerns - {'; '.join(type_parts)}.")

                # Add episode narrative
                ep_text = " ".join(ep_narrative)
                narrative_parts.append(ep_text)
                narrative_parts.append("")

        else:
            # Fallback if no episodes detected - year by year with references
            entries_by_year = defaultdict(list)
            for e in entries_data:
                entries_by_year[e['date'].year].append(e)

            for year in sorted(entries_by_year.keys()):
                year_entries = entries_by_year[year]
                meds = extract_medications_detailed(year_entries)
                all_incidents = (extract_incidents_detailed(year_entries, risk_self_harm, 'self-harm') +
                                extract_incidents_detailed(year_entries, risk_violence, 'aggression') +
                                extract_incidents_detailed(year_entries, risk_absconding, 'AWOL'))
                all_incidents.sort(key=lambda x: x['date'])

                year_text = f"In {year}, {name} had contact with services."
                if meds:
                    med_links = []
                    for med_name, info in sorted(meds.items())[:3]:
                        med_text = f"{med_name} {info['dose']}".strip() if info['dose'] else med_name
                        med_link = make_link(med_text, info['entry']['date'], info['keyword'], info['entry']['content'][:200])
                        med_links.append(med_link)
                    year_text += f" Medication included {', '.join(med_links)}."
                if all_incidents:
                    inc_links = []
                    for inc in all_incidents:  # ALL incidents, no limit
                        inc_link = make_link(f"{inc['type']} ({inc['date_str']})", inc['entry']['date'], inc['keyword'], inc['entry']['content'][:200])
                        inc_links.append(inc_link)
                    year_text += f" Incidents: {', '.join(inc_links)}."
                else:
                    year_text += " No significant incidents documented."

                narrative_parts.append(year_text)
                narrative_parts.append("")

        # === FORMAT OUTPUT ===
        plain_text = "\n".join(narrative_parts)
        plain_text = re.sub(r'<[^>]+>', '', plain_text)  # Strip HTML for plain text

        html_text = "<br>".join(narrative_parts)

        # Wrap HTML with styling
        styled_html = f"""
        <style>
            a {{ color: #0066cc; text-decoration: underline; cursor: pointer; }}
            a:hover {{ background-color: rgba(255, 200, 0, 0.3); }}
        </style>
        <div style='font-family: sans-serif; font-size: 15px; color: #1f2937; line-height: 1.5;'>{html_text}</div>
        """

        return plain_text, styled_html

    def set_entries(self, items: list, date_info: str = ""):
        """Display entries with narrative summary and collapsible dated entry boxes."""
        self._entries = items

        for cb in self._extracted_checkboxes:
            cb.deleteLater()
        self._extracted_checkboxes.clear()

        # Clear entry frame references
        self._entry_frames.clear()
        self._entry_body_texts.clear()

        while self.extracted_checkboxes_layout.count():
            item = self.extracted_checkboxes_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        if isinstance(items, str):
            if items.strip():
                items = [{"date": None, "text": p.strip()} for p in items.split("\n\n") if p.strip()]
            else:
                items = []

        # Apply date filtering based on self._date_filter
        if items and hasattr(self, '_date_filter') and self._date_filter != 'all':
            items = self._apply_date_filter(items)
            print(f"[TribunalProgressPopup] Applied '{self._date_filter}' filter: {len(items)} entries remaining")

        # Generate narrative summary (returns tuple of plain_text, html_text)
        if items:
            self._narrative_text, self._narrative_html = self._generate_narrative_summary(items)
            self.narrative_text_widget.setHtml(self._narrative_html)
            self.narrative_section.setVisible(True)
        else:
            self._narrative_text = ""
            self._narrative_html = ""
            self.narrative_section.setVisible(False)

        if not items:
            self.extracted_section.setVisible(False)
            return

        self.extracted_section.setVisible(True)

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
            text = (item.get("text", "") or item.get("content", "")).strip()
            if not text:
                continue

            if dt:
                if hasattr(dt, "strftime"):
                    date_str = dt.strftime("%d %b %Y")
                else:
                    date_str = str(dt)
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
                    font-size: 17px;
                    font-weight: bold;
                    color: #806000;
                }
                QPushButton:hover { background: rgba(180, 150, 50, 0.35); }
            """)
            header_row.addWidget(toggle_btn)

            date_label = QLabel(f"📅 {date_str}")
            date_label.setStyleSheet("""
                QLabel {
                    font-size: 17px;
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
            cb.stateChanged.connect(self._send_to_card)
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
                    font-size: 17px;
                    color: #333;
                    background: rgba(255, 248, 220, 0.5);
                    border: none;
                    border-radius: 4px;
                    padding: 6px;
                }
            """)
            body_text.setVisible(False)

            # Calculate height based on content
            doc = body_text.document()
            doc.setTextWidth(body_text.viewport().width() if body_text.viewport().width() > 0 else 400)
            content_height = int(doc.size().height()) + 20
            body_text.setFixedHeight(min(content_height, 200))

            def make_toggle(btn, body):
                def toggle():
                    if body.isVisible():
                        body.setVisible(False)
                        btn.setText("▸")
                    else:
                        body.setVisible(True)
                        btn.setText("▾")
                return toggle

            toggle_btn.clicked.connect(make_toggle(toggle_btn, body_text))
            date_label.mousePressEvent = lambda e, btn=toggle_btn: btn.click()

            entry_layout.addWidget(body_text)
            self._extracted_checkboxes.append(cb)
            self.extracted_checkboxes_layout.addWidget(entry_frame)

            # Store references for scrolling from narrative links
            # Use unique key (date + index) to handle multiple entries per date
            if dt:
                if hasattr(dt, "strftime"):
                    date_key = dt.strftime("%d/%m/%Y")
                else:
                    date_key = str(dt)

                # Create unique key with index
                idx = len(self._entry_frames)
                unique_key = f"{date_key}_{idx}"

                self._entry_frames[unique_key] = entry_frame
                self._entry_body_texts[unique_key] = (body_text, toggle_btn, text)  # Include content for keyword search

                # Also store by date for backwards compatibility (will be last entry with this date)
                self._entry_frames[date_key] = entry_frame
                self._entry_body_texts[date_key] = (body_text, toggle_btn, text)

    def _on_narrative_link_clicked(self, url: QUrl):
        """Handle clicks on narrative reference links - find and open the SPECIFIC entry that generated the narrative."""
        from PySide6.QtWidgets import QApplication
        from PySide6.QtCore import QTimer
        from PySide6.QtGui import QTextCharFormat, QColor, QTextCursor
        from progress_panel import get_reference
        import re

        ref_id = url.fragment()  # Gets the part after #
        if not ref_id:
            return

        # Use progress_panel's global reference tracker
        ref_data = get_reference(ref_id)
        if not ref_data:
            return

        # progress_panel stores: date, matched, content_snippet
        matched_text = ref_data.get("matched", "")
        content_snippet = ref_data.get("content_snippet", "")  # Used to identify specific entry
        ref_date = ref_data.get("date")  # Used for month filtering

        # Extract month/year from reference date for filtering
        ref_month = None
        ref_year = None
        if ref_date:
            if hasattr(ref_date, 'month'):
                ref_month = ref_date.month
                ref_year = ref_date.year
            elif isinstance(ref_date, str):
                # Try to parse date string
                try:
                    from datetime import datetime
                    parsed = datetime.strptime(ref_date[:10], '%Y-%m-%d')
                    ref_month = parsed.month
                    ref_year = parsed.year
                except:
                    pass

        # Get the keyword to search for - clean it up
        keyword = matched_text.strip().lower()
        keyword = keyword.replace(' (absent)', '').replace('no ', '').strip()

        # If keyword is too long, take first 1-2 words
        if len(keyword) > 30:
            words = keyword.split()[:2]
            keyword = ' '.join(words)

        # Expand keywords for contact types and common categories
        # These need expansion because entries are categorized by patterns but links store single keyword
        # All positive/stability keywords should expand to the same list
        stability_terms = ['stable', 'settled', 'calm', 'appropriate', 'bright', 'good mood', 'pleasant', 'cooperative', 'engaging', 'engaged', 'compliant', 'concordant']

        keyword_expansions = {
            'clinic': ['clinic', 'outpatient', 'appointment', 'attended for', 'attended at'],
            'telephone': ['telephone', 'phone call', 'phone', 'called', 'spoke on phone', 'text', 'messag'],
            'home visit': ['home visit', 'visited at home', 'domiciliary', 'visited patient'],
            'ward': ['ward round', 'mdt', 'multidisciplinary', 'team meeting', 'clinical review'],
            'police': ['police', 'officer', 'arrest', 'custody', '999', 'emergency services'],
            'agitation': ['agitation', 'agitated', 'irritable', 'irritability', 'unsettled', 'restless'],
            'withdraw': ['withdraw', 'withdrawn', 'isolat', 'reclusive', 'socially withdrawn'],
            # All positive/stability related keywords map to same expansion
            'stable': stability_terms,
            'settled': stability_terms,
            'calm': stability_terms,
            'pleasant': stability_terms,
            'engage': stability_terms,  # Partial stem from positive_keywords
            'comply': stability_terms,  # Partial stem from positive_keywords
            'aggression': ['aggression', 'aggressive', 'violence', 'violent', 'assault', 'attack'],
            'no aggression': ['no aggression', 'nil aggression', 'no violence', 'nil violence', 'no assault', 'no incidents'],
            'self-harm': ['self-harm', 'self harm', 'cutting', 'overdose', 'ligature', 'suicidal', 'suicide'],
            'no self-harm': ['no self-harm', 'no self harm', 'nil self-harm', 'denies self-harm', 'no suicidal', 'denies suicidal'],
            'delusion': ['delusion', 'delusional', 'psychosis', 'psychotic', 'hallucination', 'voices', 'paranoid'],
            'drug': ['drug', 'substance', 'cannabis', 'alcohol', 'cocaine', 'heroin', 'intox'],
            'refus': ['refus', 'declined', 'did not engage', 'not engaging', 'non-compli', 'noncomplian'],
        }

        # Check if keyword matches any expansion category
        keywords_to_search = [keyword]
        for key, expansions in keyword_expansions.items():
            if keyword == key or keyword in expansions:
                keywords_to_search = expansions
                break

        print(f"[FILTER-DEBUG] Original keyword: '{matched_text}' -> cleaned: '{keyword}'")
        print(f"[FILTER-DEBUG] Searching for keywords: {keywords_to_search}")
        print(f"[FILTER-DEBUG] Content snippet: '{content_snippet[:50] if content_snippet else ''}'...")
        print(f"[FILTER-DEBUG] ref_date={ref_date}, ref_month={ref_month}, ref_year={ref_year}")
        if ref_month and ref_year:
            print(f"[FILTER-DEBUG] Month filter ACTIVE: {ref_month}/{ref_year}")
        else:
            print(f"[FILTER-DEBUG] Month filter INACTIVE - showing ALL entries")

        # Expand the Imported Data section if collapsed
        if hasattr(self, 'extracted_section'):
            self.extracted_section.setVisible(True)  # Make sure it's visible
            if hasattr(self.extracted_section, '_is_collapsed') and self.extracted_section._is_collapsed:
                self.extracted_section._toggle_collapse()

        # Find the SPECIFIC entry that generated the narrative
        # Priority: entries matching BOTH keyword AND content_snippet > entries matching just keyword
        exact_matches = []  # Entries matching both keyword and content snippet
        keyword_matches = []  # Entries matching just keyword
        non_matching_entries = []

        # Clean up content snippet for matching (first 50 chars, lowercased)
        snippet_check = content_snippet[:50].lower().strip() if content_snippet else ""

        print(f"[FILTER-DEBUG] Total entry keys to check: {len(self._entry_body_texts)}")
        if self._entry_body_texts:
            sample_keys = list(self._entry_body_texts.keys())[:5]
            print(f"[FILTER-DEBUG] Sample keys: {sample_keys}")

        for key, body_info in self._entry_body_texts.items():
            # Skip date-only keys (use unique keys with index)
            if '_' not in key:
                continue

            # Filter by month if reference date is available
            if ref_month and ref_year:
                # Entry keys have format "17/12/2024_0" (dd/mm/YYYY_idx)
                date_part = key.rsplit('_', 1)[0]  # Get "17/12/2024"
                print(f"[FILTER-DEBUG] Key '{key}' -> date_part '{date_part}'")
                try:
                    from datetime import datetime
                    entry_date = datetime.strptime(date_part, '%d/%m/%Y')
                    print(f"[FILTER-DEBUG] Parsed date: {entry_date.month}/{entry_date.year}, checking against {ref_month}/{ref_year}")
                    if entry_date.month != ref_month or entry_date.year != ref_year:
                        print(f"[FILTER-DEBUG] SKIPPING entry {key} - month mismatch")
                        continue  # Skip entries not in the same month
                    else:
                        print(f"[FILTER-DEBUG] KEEPING entry {key} - month matches")
                except Exception as e:
                    print(f"[FILTER-DEBUG] Could not parse date from key '{key}': {e}")
                    pass  # If parsing fails, include the entry

            if len(body_info) >= 3:
                body_text, toggle_btn, content = body_info
            else:
                body_text, toggle_btn = body_info[:2]
                content = body_text.toPlainText()

            entry_frame = self._entry_frames.get(key)
            if not entry_frame:
                continue

            content_lower = content.lower()

            # Check if this entry contains any of the keywords (expanded list)
            # Also check negation - skip entries where keyword is negated (e.g., "No aggression")
            has_keyword = False
            matched_kw_in_entry = None

            # Check for negation patterns in the entry
            def is_keyword_negated(text, kw):
                """Check if keyword appears in negated context."""
                negation_patterns = [
                    r'\bno\s+' + re.escape(kw),
                    r'\bno\s+\w+[,\s]+.*' + re.escape(kw),  # "No X, Y or keyword"
                    r'\bnil\s+' + re.escape(kw),
                    r'\bnone\s+.*' + re.escape(kw),
                    r'\bwithout\s+.*' + re.escape(kw),
                    r'\bdenied\s+.*' + re.escape(kw),
                    r'\bdid\s*n[o\']t\s+.*' + re.escape(kw),
                    r'\bno\s+incidents?\s*,?\s*.*' + re.escape(kw),  # "No incidents, self harm or aggression"
                    r'\bno\s+self\s*harm\s+or\s+.*' + re.escape(kw),  # "No self harm or incidents of aggression"
                ]
                for pattern in negation_patterns:
                    if re.search(pattern, text, re.IGNORECASE):
                        return True
                return False

            for kw in keywords_to_search:
                if kw and len(kw) >= 2:
                    # Try exact word boundary match first
                    if re.search(r'\b' + re.escape(kw) + r'\b', content_lower):
                        # Skip if negated (unless searching for "no aggression" type terms)
                        if not keyword.startswith('no ') and is_keyword_negated(content_lower, kw):
                            continue  # Skip negated entries
                        has_keyword = True
                        matched_kw_in_entry = kw  # Remember which keyword matched for highlighting
                        break
                    # Fall back to prefix match (e.g., 'aggress' matches 'aggression')
                    elif re.search(r'\b' + re.escape(kw), content_lower):
                        # Skip if negated
                        if not keyword.startswith('no ') and is_keyword_negated(content_lower, kw):
                            continue
                        has_keyword = True
                        # Find the actual full word that was matched for highlighting
                        match = re.search(r'\b(' + re.escape(kw) + r'\w*)', content_lower)
                        matched_kw_in_entry = match.group(1) if match else kw
                        break

            # Check if this entry matches the content snippet (identifies specific entry)
            has_snippet = False
            if snippet_check and len(snippet_check) > 10:
                # Check if the snippet appears in this entry's content
                has_snippet = snippet_check in content_lower

            if has_keyword and has_snippet:
                # Exact match - this is THE entry that generated the narrative
                exact_matches.append((key, entry_frame, body_text, toggle_btn, matched_kw_in_entry))
            elif has_keyword:
                # Keyword match only
                keyword_matches.append((key, entry_frame, body_text, toggle_btn, matched_kw_in_entry))
            else:
                non_matching_entries.append((key, entry_frame, body_text, toggle_btn))

        # COMBINE exact matches and keyword matches - show ALL entries that match the keyword
        # The content_snippet is just a sample, not a filter - we want all matching entries
        all_matching = exact_matches + keyword_matches

        # Remove duplicates (same key appearing in both lists)
        seen_keys = set()
        matching_entries = []
        for entry in all_matching:
            if entry[0] not in seen_keys:
                seen_keys.add(entry[0])
                matching_entries.append(entry)

        matching_keys = {entry[0] for entry in matching_entries}  # Set of keys for quick lookup

        print(f"[FILTER-DEBUG] Found {len(exact_matches)} exact matches, {len(keyword_matches)} keyword matches")

        # FALLBACK: If month filtering found 0 entries, retry without month filter
        if len(all_matching) == 0 and ref_month and ref_year:
            print(f"[FILTER-DEBUG] No entries found with month filter - retrying without month filter")
            # Re-scan ALL entries without month filtering
            exact_matches = []
            keyword_matches = []
            for key, body_info in self._entry_body_texts.items():
                if '_' not in key:
                    continue
                if len(body_info) >= 3:
                    body_text, toggle_btn, content = body_info
                else:
                    body_text, toggle_btn = body_info[:2]
                    content = body_text.toPlainText()
                entry_frame = self._entry_frames.get(key)
                if not entry_frame:
                    continue
                content_lower = content.lower()

                has_keyword = False
                matched_kw_in_entry = None
                for kw in keywords_to_search:
                    if kw and len(kw) >= 2:
                        if re.search(r'\b' + re.escape(kw) + r'\b', content_lower):
                            has_keyword = True
                            match = re.search(r'\b(' + re.escape(kw) + r'\w*)', content_lower)
                            matched_kw_in_entry = match.group(1) if match else kw
                            break
                        elif re.search(r'\b' + re.escape(kw), content_lower):
                            has_keyword = True
                            match = re.search(r'\b(' + re.escape(kw) + r'\w*)', content_lower)
                            matched_kw_in_entry = match.group(1) if match else kw
                            break

                if has_keyword:
                    has_snippet = snippet_check in content_lower if snippet_check and len(snippet_check) > 10 else False
                    if has_snippet:
                        exact_matches.append((key, entry_frame, body_text, toggle_btn, matched_kw_in_entry))
                    else:
                        keyword_matches.append((key, entry_frame, body_text, toggle_btn, matched_kw_in_entry))

            all_matching = exact_matches + keyword_matches
            seen_keys = set()
            matching_entries = []
            for entry in all_matching:
                if entry[0] not in seen_keys:
                    seen_keys.add(entry[0])
                    matching_entries.append(entry)
            matching_keys = {entry[0] for entry in matching_entries}
            print(f"[FILTER-DEBUG] Fallback found {len(matching_entries)} entries without month filter")
        print(f"[FILTER-DEBUG] Using {len(matching_entries)} total entries (combined)")

        import html as html_module

        # FIRST: Hide ALL entries and clear highlighting (acts as a filter)
        for key, body_info in self._entry_body_texts.items():
            if '_' not in key:
                continue
            if len(body_info) >= 3:
                body_text, toggle_btn, content = body_info
            else:
                body_text, toggle_btn = body_info[:2]

            # Get the entry frame
            entry_frame = self._entry_frames.get(key)

            # Close if open
            if body_text.isVisible():
                toggle_btn.click()

            # Clear highlighting by resetting to plain text
            note_content = body_text.toPlainText()
            body_text.setPlainText(note_content)

            # Hide non-matching entries entirely (filter mode)
            if entry_frame:
                if key in matching_keys:
                    entry_frame.show()  # Ensure matching entries are visible
                else:
                    entry_frame.hide()  # Hide non-matching entries

        # Show the filter bar with count of matching entries
        if matching_entries:
            try:
                # Recreate filter bar each time to avoid Qt object deletion issues
                if hasattr(self, '_filter_bar') and self._filter_bar is not None:
                    try:
                        self._filter_bar.deleteLater()
                    except:
                        pass

                self._filter_bar = QFrame()
                self._filter_bar.setStyleSheet("""
                    QFrame {
                        background-color: #FFF3CD;
                        border: 1px solid #FFECB5;
                        border-radius: 4px;
                        padding: 4px;
                    }
                """)
                filter_bar_layout = QHBoxLayout(self._filter_bar)
                filter_bar_layout.setContentsMargins(8, 4, 8, 4)
                filter_bar_layout.setSpacing(8)

                # Build filter label with month info if applicable
                if ref_month and ref_year:
                    from calendar import month_name
                    month_str = f"{month_name[ref_month]} {ref_year}"
                    filter_label = QLabel(f"Filtered: {len(matching_entries)} entries for '{keyword}' in {month_str}")
                else:
                    filter_label = QLabel(f"Filtered: showing {len(matching_entries)} matching entries for '{keyword}'")
                filter_label.setStyleSheet("color: #664D03; font-size: 11px;")
                filter_bar_layout.addWidget(filter_label)

                filter_bar_layout.addStretch()

                remove_filter_btn = QPushButton("✕ Remove Filter")
                remove_filter_btn.setStyleSheet("""
                    QPushButton {
                        background-color: #664D03;
                        color: white;
                        border: none;
                        border-radius: 3px;
                        padding: 3px 8px;
                        font-size: 10px;
                    }
                    QPushButton:hover {
                        background-color: #805D04;
                    }
                """)
                remove_filter_btn.setCursor(Qt.CursorShape.PointingHandCursor)
                remove_filter_btn.clicked.connect(self._remove_entry_filter)
                filter_bar_layout.addWidget(remove_filter_btn)

                # Insert at top of layout
                self.extracted_checkboxes_layout.insertWidget(0, self._filter_bar)
            except Exception as e:
                print(f"[FILTER] Error creating filter bar: {e}")

        # THEN: Expand and highlight only the matching entries
        first_frame = None

        for entry_data in matching_entries:
            # Unpack - may have 4 or 5 elements depending on whether matched_kw is included
            if len(entry_data) == 5:
                key, entry_frame, body_text, toggle_btn, entry_matched_kw = entry_data
            else:
                key, entry_frame, body_text, toggle_btn = entry_data
                entry_matched_kw = keyword  # Fall back to original keyword

            # Expand if collapsed
            if not body_text.isVisible():
                toggle_btn.click()

            # Remember first frame for scrolling
            if first_frame is None:
                first_frame = entry_frame

            # Use the specific keyword that matched this entry for highlighting
            highlight_keyword = entry_matched_kw if entry_matched_kw else keyword

            # Highlight the keyword in this entry using HTML
            note_content = body_text.toPlainText()

            # Use HTML-based highlighting which is more reliable
            if highlight_keyword and len(highlight_keyword) >= 2:
                # Escape HTML special characters in content
                escaped_content = html_module.escape(note_content)

                # Replace newlines with <br> tags for proper HTML display
                escaped_content = escaped_content.replace('\n', '<br>')

                # Try exact word boundary match first
                pattern = re.compile(r'\b(' + re.escape(highlight_keyword) + r')\b', re.IGNORECASE)
                match = pattern.search(escaped_content)

                if match:
                    # Exact match found - highlight it
                    highlighted_content = pattern.sub(
                        r'<span style="background-color: #FFFF00; font-weight: bold;">\1</span>',
                        escaped_content,
                        count=1
                    )
                else:
                    # Try prefix match (e.g., 'aggress' matches 'aggression')
                    prefix_pattern = re.compile(r'\b(' + re.escape(highlight_keyword) + r'\w*)\b', re.IGNORECASE)
                    highlighted_content = prefix_pattern.sub(
                        r'<span style="background-color: #FFFF00; font-weight: bold;">\1</span>',
                        escaped_content,
                        count=1
                    )

                # Wrap in pre-style div to preserve whitespace
                html_content = f'<div style="white-space: pre-wrap; font-family: inherit;">{highlighted_content}</div>'
                body_text.setHtml(html_content)
            else:
                body_text.setPlainText(note_content)

        # Process events to ensure layout is updated
        QApplication.processEvents()

        # Scroll to the first matching entry
        if first_frame:
            scroll_area = None
            parent = first_frame.parent()
            while parent:
                if isinstance(parent, QScrollArea):
                    scroll_area = parent
                    break
                parent = parent.parent() if hasattr(parent, 'parent') else None

            if scroll_area:
                scroll_area.ensureWidgetVisible(first_frame, 50, 50)


# ================================================================
# TRIBUNAL RISK HARM POPUP (section 17 - Incidents of harm to self or others)
# ================================================================

class TribunalRiskHarmPopup(QWidget):
    """Popup for Risk Harm section with categorized incidents in yellow collapsible entries.

    Features:
    - Preview section at top with Send to Report button
    - Uses analyze_notes_for_risk to extract incidents
    - Categories: Self-Harm, Physical Aggression (harm to others), Verbal Aggression
    - Yellow collapsible entries for each incident
    - Clickable labels to filter by subcategory
    """

    sent = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        self._entries = []
        self._extracted_checkboxes = []
        self._current_filter = None
        self._all_entry_frames = []  # Store all entry frames for filtering
        self._setup_ui()

    def _setup_ui(self):
        from background_history_popup import ResizableSection, CollapsibleSection

        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        # Main scroll area
        main_scroll = QScrollArea()
        main_scroll.setWidgetResizable(True)
        main_scroll.setFrameShape(QScrollArea.NoFrame)
        main_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        main_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        main_container = QWidget()
        self.main_layout = QVBoxLayout(main_container)
        self.main_layout.setContentsMargins(4, 4, 4, 4)
        self.main_layout.setSpacing(8)

        # Store section-specific data
        self._section_filters = {}  # {section_key: {"bar": QFrame, "label": QLabel, "entries": []}}

        # ====================================================
        # SECTION 1: SELF-HARM INCIDENTS (collapsible)
        # ====================================================
        self.selfharm_section = CollapsibleSection("Self-Harm Incidents", start_collapsed=True)
        self.selfharm_section.set_content_height(250)
        self.selfharm_section._min_height = 100
        self.selfharm_section._max_height = 500
        self.selfharm_section.set_header_style("""
            QFrame {
                background: rgba(255, 200, 180, 0.95);
                border: 1px solid rgba(200, 80, 50, 0.4);
                border-radius: 6px 6px 0 0;
            }
        """)
        self.selfharm_section.set_title_style("""
            QLabel {
                font-size: 18px;
                font-weight: 600;
                color: #b03000;
                background: transparent;
                border: none;
            }
        """)

        selfharm_content = QWidget()
        selfharm_content.setStyleSheet("""
            QWidget {
                background: rgba(255, 248, 220, 0.95);
                border: 1px solid rgba(180, 150, 50, 0.4);
                border-top: none;
                border-radius: 0 0 12px 12px;
            }
        """)

        selfharm_layout = QVBoxLayout(selfharm_content)
        selfharm_layout.setContentsMargins(12, 10, 12, 10)
        selfharm_layout.setSpacing(6)

        # Filter bar for self-harm section
        selfharm_filter_bar = QFrame()
        selfharm_filter_bar.setStyleSheet("""
            QFrame {
                background: rgba(100, 149, 237, 0.15);
                border: 1px solid rgba(100, 149, 237, 0.4);
                border-radius: 6px;
            }
        """)
        sfb_layout = QHBoxLayout(selfharm_filter_bar)
        sfb_layout.setContentsMargins(8, 4, 8, 4)
        sfb_layout.setSpacing(6)
        sfb_label = QLabel("Filtered by:")
        sfb_label.setStyleSheet("font-size:15px; color:#333; background:transparent; border:none;")
        sfb_layout.addWidget(sfb_label)
        selfharm_filter_value = QLabel("")
        selfharm_filter_value.setStyleSheet("font-size:14px; font-weight:600; color:white; background:#6495ED; border:none; border-radius:3px; padding:2px 6px;")
        sfb_layout.addWidget(selfharm_filter_value)
        sfb_layout.addStretch()
        selfharm_clear_btn = QPushButton("✕")
        selfharm_clear_btn.setFixedSize(18, 18)
        selfharm_clear_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        selfharm_clear_btn.setStyleSheet("QPushButton{background:rgba(0,0,0,0.1);color:#333;border:none;border-radius:3px;font-size:15px;font-weight:bold;}QPushButton:hover{background:rgba(0,0,0,0.2);}")
        selfharm_clear_btn.clicked.connect(lambda: self._clear_section_filter("selfharm"))
        sfb_layout.addWidget(selfharm_clear_btn)
        selfharm_filter_bar.setVisible(False)
        selfharm_layout.addWidget(selfharm_filter_bar)
        self._section_filters["selfharm"] = {"bar": selfharm_filter_bar, "label": selfharm_filter_value, "entries": []}

        selfharm_scroll = QScrollArea()
        selfharm_scroll.setWidgetResizable(True)
        selfharm_scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        selfharm_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        selfharm_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        selfharm_scroll.setStyleSheet("""
            QScrollArea { background: transparent; border: none; }
            QScrollArea > QWidget > QWidget { background: transparent; }
        """)

        self.selfharm_container = QWidget()
        self.selfharm_container.setStyleSheet("background: transparent;")
        self.selfharm_checkboxes_layout = QVBoxLayout(self.selfharm_container)
        self.selfharm_checkboxes_layout.setContentsMargins(2, 2, 2, 2)
        self.selfharm_checkboxes_layout.setSpacing(12)
        self.selfharm_checkboxes_layout.setAlignment(Qt.AlignmentFlag.AlignTop)

        selfharm_scroll.setWidget(self.selfharm_container)
        selfharm_layout.addWidget(selfharm_scroll)

        self.selfharm_section.set_content(selfharm_content)
        self.selfharm_section.setVisible(False)
        self.main_layout.addWidget(self.selfharm_section)

        # ====================================================
        # SECTION 3: PHYSICAL AGGRESSION INCIDENTS (collapsible)
        # ====================================================
        self.physical_section = CollapsibleSection("Harm to Others - Physical Aggression", start_collapsed=True)
        self.physical_section.set_content_height(250)
        self.physical_section._min_height = 100
        self.physical_section._max_height = 500
        self.physical_section.set_header_style("""
            QFrame {
                background: rgba(255, 180, 180, 0.95);
                border: 1px solid rgba(180, 50, 50, 0.4);
                border-radius: 6px 6px 0 0;
            }
        """)
        self.physical_section.set_title_style("""
            QLabel {
                font-size: 18px;
                font-weight: 600;
                color: #a00000;
                background: transparent;
                border: none;
            }
        """)

        physical_content = QWidget()
        physical_content.setStyleSheet("""
            QWidget {
                background: rgba(255, 248, 220, 0.95);
                border: 1px solid rgba(180, 150, 50, 0.4);
                border-top: none;
                border-radius: 0 0 12px 12px;
            }
        """)

        physical_layout = QVBoxLayout(physical_content)
        physical_layout.setContentsMargins(12, 10, 12, 10)
        physical_layout.setSpacing(6)

        # Filter bar for physical section
        physical_filter_bar = QFrame()
        physical_filter_bar.setStyleSheet("""
            QFrame {
                background: rgba(100, 149, 237, 0.15);
                border: 1px solid rgba(100, 149, 237, 0.4);
                border-radius: 6px;
            }
        """)
        pfb_layout = QHBoxLayout(physical_filter_bar)
        pfb_layout.setContentsMargins(8, 4, 8, 4)
        pfb_layout.setSpacing(6)
        pfb_label = QLabel("Filtered by:")
        pfb_label.setStyleSheet("font-size:15px; color:#333; background:transparent; border:none;")
        pfb_layout.addWidget(pfb_label)
        physical_filter_value = QLabel("")
        physical_filter_value.setStyleSheet("font-size:14px; font-weight:600; color:white; background:#6495ED; border:none; border-radius:3px; padding:2px 6px;")
        pfb_layout.addWidget(physical_filter_value)
        pfb_layout.addStretch()
        physical_clear_btn = QPushButton("✕")
        physical_clear_btn.setFixedSize(18, 18)
        physical_clear_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        physical_clear_btn.setStyleSheet("QPushButton{background:rgba(0,0,0,0.1);color:#333;border:none;border-radius:3px;font-size:15px;font-weight:bold;}QPushButton:hover{background:rgba(0,0,0,0.2);}")
        physical_clear_btn.clicked.connect(lambda: self._clear_section_filter("physical"))
        pfb_layout.addWidget(physical_clear_btn)
        physical_filter_bar.setVisible(False)
        physical_layout.addWidget(physical_filter_bar)
        self._section_filters["physical"] = {"bar": physical_filter_bar, "label": physical_filter_value, "entries": []}

        physical_scroll = QScrollArea()
        physical_scroll.setWidgetResizable(True)
        physical_scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        physical_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        physical_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        physical_scroll.setStyleSheet("""
            QScrollArea { background: transparent; border: none; }
            QScrollArea > QWidget > QWidget { background: transparent; }
        """)

        self.physical_container = QWidget()
        self.physical_container.setStyleSheet("background: transparent;")
        self.physical_checkboxes_layout = QVBoxLayout(self.physical_container)
        self.physical_checkboxes_layout.setContentsMargins(2, 2, 2, 2)
        self.physical_checkboxes_layout.setSpacing(12)
        self.physical_checkboxes_layout.setAlignment(Qt.AlignmentFlag.AlignTop)

        physical_scroll.setWidget(self.physical_container)
        physical_layout.addWidget(physical_scroll)

        self.physical_section.set_content(physical_content)
        self.physical_section.setVisible(False)
        self.main_layout.addWidget(self.physical_section)

        # ====================================================
        # SECTION 4: VERBAL AGGRESSION INCIDENTS (collapsible)
        # ====================================================
        self.verbal_section = CollapsibleSection("Verbal Aggression", start_collapsed=True)
        self.verbal_section.set_content_height(250)
        self.verbal_section._min_height = 100
        self.verbal_section._max_height = 500
        self.verbal_section.set_header_style("""
            QFrame {
                background: rgba(220, 220, 220, 0.95);
                border: 1px solid rgba(100, 100, 100, 0.4);
                border-radius: 6px 6px 0 0;
            }
        """)
        self.verbal_section.set_title_style("""
            QLabel {
                font-size: 18px;
                font-weight: 600;
                color: #505050;
                background: transparent;
                border: none;
            }
        """)

        verbal_content = QWidget()
        verbal_content.setStyleSheet("""
            QWidget {
                background: rgba(255, 248, 220, 0.95);
                border: 1px solid rgba(180, 150, 50, 0.4);
                border-top: none;
                border-radius: 0 0 12px 12px;
            }
        """)

        verbal_layout = QVBoxLayout(verbal_content)
        verbal_layout.setContentsMargins(12, 10, 12, 10)
        verbal_layout.setSpacing(6)

        # Filter bar for verbal section
        verbal_filter_bar = QFrame()
        verbal_filter_bar.setStyleSheet("""
            QFrame {
                background: rgba(100, 149, 237, 0.15);
                border: 1px solid rgba(100, 149, 237, 0.4);
                border-radius: 6px;
            }
        """)
        vfb_layout = QHBoxLayout(verbal_filter_bar)
        vfb_layout.setContentsMargins(8, 4, 8, 4)
        vfb_layout.setSpacing(6)
        vfb_label = QLabel("Filtered by:")
        vfb_label.setStyleSheet("font-size:15px; color:#333; background:transparent; border:none;")
        vfb_layout.addWidget(vfb_label)
        verbal_filter_value = QLabel("")
        verbal_filter_value.setStyleSheet("font-size:14px; font-weight:600; color:white; background:#6495ED; border:none; border-radius:3px; padding:2px 6px;")
        vfb_layout.addWidget(verbal_filter_value)
        vfb_layout.addStretch()
        verbal_clear_btn = QPushButton("✕")
        verbal_clear_btn.setFixedSize(18, 18)
        verbal_clear_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        verbal_clear_btn.setStyleSheet("QPushButton{background:rgba(0,0,0,0.1);color:#333;border:none;border-radius:3px;font-size:15px;font-weight:bold;}QPushButton:hover{background:rgba(0,0,0,0.2);}")
        verbal_clear_btn.clicked.connect(lambda: self._clear_section_filter("verbal"))
        vfb_layout.addWidget(verbal_clear_btn)
        verbal_filter_bar.setVisible(False)
        verbal_layout.addWidget(verbal_filter_bar)
        self._section_filters["verbal"] = {"bar": verbal_filter_bar, "label": verbal_filter_value, "entries": []}

        verbal_scroll = QScrollArea()
        verbal_scroll.setWidgetResizable(True)
        verbal_scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        verbal_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        verbal_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        verbal_scroll.setStyleSheet("""
            QScrollArea { background: transparent; border: none; }
            QScrollArea > QWidget > QWidget { background: transparent; }
        """)

        self.verbal_container = QWidget()
        self.verbal_container.setStyleSheet("background: transparent;")
        self.verbal_checkboxes_layout = QVBoxLayout(self.verbal_container)
        self.verbal_checkboxes_layout.setContentsMargins(2, 2, 2, 2)
        self.verbal_checkboxes_layout.setSpacing(12)
        self.verbal_checkboxes_layout.setAlignment(Qt.AlignmentFlag.AlignTop)

        verbal_scroll.setWidget(self.verbal_container)
        verbal_layout.addWidget(verbal_scroll)

        self.verbal_section.set_content(verbal_content)
        self.verbal_section.setVisible(False)
        self.main_layout.addWidget(self.verbal_section)

        self.main_layout.addStretch()
        main_scroll.setWidget(main_container)
        root.addWidget(main_scroll)

    def _send_to_card(self):
        """Generate text and send directly to card."""
        parts = []
        for cb in self._extracted_checkboxes:
            if cb.isChecked():
                parts.append(cb.property("full_text"))

        combined = "\n\n".join(parts) if parts else ""
        if combined:
            self.sent.emit(combined)

    def _apply_section_filter(self, section_key: str, subcategory: str):
        """Filter entries within a section to show only those with the specified subcategory."""
        if section_key not in self._section_filters:
            return

        section_data = self._section_filters[section_key]
        section_data["label"].setText(subcategory)
        section_data["bar"].setVisible(True)

        # Show/hide entries in this section only
        for entry_frame, entry_subcats in section_data["entries"]:
            if subcategory in entry_subcats:
                entry_frame.setVisible(True)
            else:
                entry_frame.setVisible(False)

    def _clear_section_filter(self, section_key: str):
        """Clear the filter for a specific section and show all its entries."""
        if section_key not in self._section_filters:
            return

        section_data = self._section_filters[section_key]
        section_data["bar"].setVisible(False)

        # Show all entries in this section
        for entry_frame, entry_subcats in section_data["entries"]:
            entry_frame.setVisible(True)

    def set_notes(self, notes: list):
        """Analyze notes for risk incidents and populate the sections."""
        try:
            from risk_overview_panel import analyze_notes_for_risk
        except ImportError:
            print("[TribunalRiskHarmPopup] Could not import analyze_notes_for_risk")
            return

        # Clear existing entries and reset section filters
        self._extracted_checkboxes.clear()
        self._all_entry_frames.clear()
        self._current_filter = None
        # Reset all section filters
        for section_key in self._section_filters:
            self._section_filters[section_key]["bar"].setVisible(False)
            self._section_filters[section_key]["entries"].clear()
        for layout in [self.selfharm_checkboxes_layout, self.physical_checkboxes_layout, self.verbal_checkboxes_layout]:
            while layout.count():
                item = layout.takeAt(0)
                if item.widget():
                    item.widget().deleteLater()

        # Analyze notes for risk
        results = analyze_notes_for_risk(notes)
        categories = results.get("categories", {})

        # Extract incidents for each category
        selfharm_incidents = categories.get("Self-Harm", {}).get("incidents", [])
        physical_incidents = categories.get("Physical Aggression", {}).get("incidents", [])
        verbal_incidents = categories.get("Verbal Aggression", {}).get("incidents", [])

        # Populate each section (titles are set inside _populate_section after deduplication)
        self._populate_section(selfharm_incidents, self.selfharm_checkboxes_layout, self.selfharm_section, "Self-Harm Incidents", "selfharm")
        self._populate_section(physical_incidents, self.physical_checkboxes_layout, self.physical_section, "Harm to Others - Physical Aggression", "physical")
        self._populate_section(verbal_incidents, self.verbal_checkboxes_layout, self.verbal_section, "Verbal Aggression", "verbal")

    def _populate_section(self, incidents: list, layout: QVBoxLayout, section, category_name: str, section_key: str = ""):
        """Populate a section with incident entries, deduplicated by date."""
        if not incidents:
            section.setVisible(False)
            return

        section.setVisible(True)

        # Group incidents by date and deduplicate
        from collections import defaultdict

        def get_date_key(item):
            dt = item.get("date")
            if dt is None:
                return "no_date"
            if hasattr(dt, "strftime"):
                return dt.strftime("%Y-%m-%d")
            return str(dt)

        # Group by date
        date_groups = defaultdict(list)
        for incident in incidents:
            date_key = get_date_key(incident)
            date_groups[date_key].append(incident)

        # Process each date group to create deduplicated entries
        deduplicated_entries = []
        for date_key, group in date_groups.items():
            # Collect unique subcategories with their highest severity and matched terms
            subcategories = {}  # {subcategory: {"severity": str, "matched_terms": set}}
            texts = []
            matched_terms_all = set()
            representative_date = None

            for inc in group:
                subcat = inc.get("subcategory", "")
                severity = inc.get("severity", "medium")
                matched = inc.get("matched", "")
                text = inc.get("full_text", "").strip()
                dt = inc.get("date")

                if representative_date is None:
                    representative_date = dt

                if text:
                    texts.append(text)

                if matched:
                    matched_terms_all.add(matched)

                if subcat:
                    if subcat not in subcategories:
                        subcategories[subcat] = {"severity": severity, "matched_terms": set()}
                    # Keep highest severity (high > medium > low)
                    severity_rank = {"high": 3, "medium": 2, "low": 1}
                    if severity_rank.get(severity, 0) > severity_rank.get(subcategories[subcat]["severity"], 0):
                        subcategories[subcat]["severity"] = severity
                    if matched:
                        subcategories[subcat]["matched_terms"].add(matched)

            # Choose the longest/most comprehensive text as representative
            # Prefer text that contains the most matched terms
            best_text = ""
            best_score = -1
            for text in texts:
                text_lower = text.lower()
                score = len(text)  # Base score is length
                # Bonus for containing matched terms
                for term in matched_terms_all:
                    if term.lower() in text_lower:
                        score += 100
                if score > best_score:
                    best_score = score
                    best_text = text

            if best_text:
                deduplicated_entries.append({
                    "date": representative_date,
                    "date_key": date_key,
                    "text": best_text,
                    "subcategories": subcategories,
                    "matched_terms": matched_terms_all,
                })

        # Sort by date (newest first)
        deduplicated_entries.sort(key=lambda x: x["date_key"], reverse=True)

        # Update section title with deduplicated count
        if deduplicated_entries:
            section.title_label.setText(f"{category_name} ({len(deduplicated_entries)})")

        # Create UI entries
        for entry in deduplicated_entries:
            dt = entry["date"]
            text = entry["text"]
            subcategories = entry["subcategories"]
            matched_terms = entry["matched_terms"]

            if dt:
                if hasattr(dt, "strftime"):
                    date_str = dt.strftime("%d %b %Y")
                else:
                    date_str = str(dt)
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

            # Toggle button first (swapped position)
            toggle_btn = QPushButton("▸")
            toggle_btn.setFixedSize(22, 22)
            toggle_btn.setCursor(Qt.CursorShape.PointingHandCursor)
            toggle_btn.setStyleSheet("""
                QPushButton {
                    background: rgba(180, 150, 50, 0.2);
                    border: none;
                    border-radius: 4px;
                    font-size: 17px;
                    font-weight: bold;
                    color: #806000;
                }
                QPushButton:hover { background: rgba(180, 150, 50, 0.35); }
            """)
            header_row.addWidget(toggle_btn)

            date_label = QLabel(f"📅 {date_str}")
            date_label.setStyleSheet("""
                QLabel {
                    font-size: 17px;
                    font-weight: 600;
                    color: #806000;
                    background: transparent;
                    border: none;
                }
            """)
            date_label.setCursor(Qt.CursorShape.PointingHandCursor)
            header_row.addWidget(date_label)

            header_row.addStretch()

            # Checkbox at the end (swapped position)
            cb = QCheckBox()
            cb.setProperty("full_text", text)
            cb.setFixedSize(18, 18)
            cb.setStyleSheet("""
                QCheckBox { background: transparent; }
                QCheckBox::indicator { width: 16px; height: 16px; }
            """)
            cb.stateChanged.connect(self._send_to_card)
            header_row.addWidget(cb)

            entry_layout.addLayout(header_row)

            # Add subcategory badges stacked vertically (clickable for filtering)
            severity_colors = {"high": "#c0392b", "medium": "#f39c12", "low": "#27ae60"}
            severity_rank = {"high": 3, "medium": 2, "low": 1}
            sorted_subcats = sorted(
                subcategories.items(),
                key=lambda x: severity_rank.get(x[1]["severity"], 0),
                reverse=True
            )
            entry_subcat_names = list(subcategories.keys())  # Store for filtering
            if sorted_subcats:
                badges_layout = QVBoxLayout()
                badges_layout.setContentsMargins(30, 0, 0, 4)  # Indent to align with date
                badges_layout.setSpacing(4)
                for subcat_name, subcat_info in sorted_subcats:
                    badge_color = severity_colors.get(subcat_info["severity"], "#808080")
                    subcat_label = QLabel(f"{subcat_name}")
                    subcat_label.setStyleSheet(f"""
                        QLabel {{
                            font-size: 14px;
                            font-weight: 500;
                            color: white;
                            background: {badge_color};
                            border: none;
                            border-radius: 3px;
                            padding: 2px 6px;
                        }}
                        QLabel:hover {{
                            background: {badge_color};
                            border: 2px solid white;
                        }}
                    """)
                    subcat_label.setSizePolicy(QSizePolicy.Policy.Maximum, QSizePolicy.Policy.Fixed)
                    subcat_label.setCursor(Qt.CursorShape.PointingHandCursor)
                    # Make label clickable for filtering (section-specific)
                    subcat_label.mousePressEvent = lambda e, name=subcat_name, sk=section_key: self._apply_section_filter(sk, name)
                    badges_layout.addWidget(subcat_label)
                entry_layout.addLayout(badges_layout)

            # Store entry frame with its subcategories for section-specific filtering
            self._all_entry_frames.append((entry_frame, entry_subcat_names))
            if section_key and section_key in self._section_filters:
                self._section_filters[section_key]["entries"].append((entry_frame, entry_subcat_names))

            body_text = QTextEdit()
            body_text.setReadOnly(True)
            body_text.setFrameShape(QFrame.Shape.NoFrame)
            body_text.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            body_text.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            body_text.setStyleSheet("""
                QTextEdit {
                    font-size: 17px;
                    color: #333;
                    background: rgba(255, 248, 220, 0.5);
                    border: none;
                    border-radius: 4px;
                    padding: 6px;
                }
            """)
            body_text.setVisible(False)

            # Highlight all matched terms in the text
            if matched_terms:
                import html
                import re
                escaped_text = html.escape(text)
                # Highlight each matched term
                for term in matched_terms:
                    if term:
                        pattern = re.compile(re.escape(html.escape(term)), re.IGNORECASE)
                        escaped_text = pattern.sub(
                            f'<span style="background-color: #ffeb3b; padding: 1px 3px; border-radius: 2px; font-weight: 600;">\\g<0></span>',
                            escaped_text
                        )
                body_text.setHtml(f'<div style="font-size: 17px; color: #333;">{escaped_text}</div>')
            else:
                body_text.setPlainText(text)

            # Calculate height based on content
            doc = body_text.document()
            doc.setTextWidth(body_text.viewport().width() if body_text.viewport().width() > 0 else 400)
            content_height = int(doc.size().height()) + 20
            body_text.setFixedHeight(min(content_height, 200))

            def make_toggle(btn, body):
                def toggle():
                    if body.isVisible():
                        body.setVisible(False)
                        btn.setText("▸")
                    else:
                        body.setVisible(True)
                        btn.setText("▾")
                return toggle

            toggle_btn.clicked.connect(make_toggle(toggle_btn, body_text))
            date_label.mousePressEvent = lambda e, btn=toggle_btn: btn.click()

            entry_layout.addWidget(body_text)
            self._extracted_checkboxes.append(cb)
            layout.addWidget(entry_frame)

    def set_entries(self, items: list, date_info: str = ""):
        """Legacy compatibility method - redirect to set_notes if passed raw notes."""
        # If items look like notes (have 'text' or 'content' keys), use set_notes
        if items and isinstance(items, list) and len(items) > 0:
            first_item = items[0]
            if isinstance(first_item, dict) and ('text' in first_item or 'content' in first_item or 'body' in first_item):
                self.set_notes(items)
                return

        # Otherwise, try to extract text and create simple entries
        all_incidents = []
        for item in items:
            if isinstance(item, dict):
                all_incidents.append({
                    "date": item.get("date"),
                    "full_text": item.get("text", item.get("content", item.get("body", ""))),
                    "subcategory": item.get("subcategory", ""),
                    "severity": item.get("severity", "medium"),
                })
            elif isinstance(item, str):
                all_incidents.append({
                    "date": None,
                    "full_text": item,
                    "subcategory": "",
                    "severity": "medium",
                })

        # Put all in a generic section (physical aggression as default)
        # Title is set automatically in _populate_section after deduplication
        self._populate_section(all_incidents, self.physical_checkboxes_layout, self.physical_section, "Incidents")


# ================================================================
# TRIBUNAL RISK PROPERTY POPUP (section 18 - Incidents of property damage)
# ================================================================

class TribunalRiskPropertyPopup(QWidget):
    """Popup for Property Damage section with categorized incidents in yellow collapsible entries.

    Features:
    - Preview section at top with Send to Report button
    - Uses analyze_notes_for_risk to extract property damage incidents
    - Clickable labels to filter by subcategory
    """

    sent = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        self._entries = []
        self._extracted_checkboxes = []
        self._current_filter = None
        self._all_entry_frames = []
        self._section_filters = {}  # {section_key: {"bar": QFrame, "label": QLabel, "entries": []}}
        self._setup_ui()

    def _setup_ui(self):
        from background_history_popup import ResizableSection, CollapsibleSection

        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        # Main scroll area
        main_scroll = QScrollArea()
        main_scroll.setWidgetResizable(True)
        main_scroll.setFrameShape(QScrollArea.NoFrame)
        main_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        main_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        main_container = QWidget()
        self.main_layout = QVBoxLayout(main_container)
        self.main_layout.setContentsMargins(8, 4, 8, 4)
        self.main_layout.setSpacing(8)

        # ====================================================
        # SECTION 1: PROPERTY DAMAGE INCIDENTS (collapsible)
        # ====================================================
        self.property_section = CollapsibleSection("Property Damage", start_collapsed=True)
        self.property_section.set_content_height(350)
        self.property_section._min_height = 100
        self.property_section._max_height = 600
        self.property_section.set_header_style("""
            QFrame {
                background: rgba(229, 57, 53, 0.2);
                border: 1px solid rgba(229, 57, 53, 0.4);
                border-radius: 6px 6px 0 0;
            }
        """)
        self.property_section.set_title_style("""
            QLabel {
                font-size: 18px;
                font-weight: 600;
                color: #c62828;
                background: transparent;
                border: none;
            }
        """)

        property_content = QWidget()
        property_content.setStyleSheet("""
            QWidget {
                background: rgba(255, 248, 220, 0.95);
                border: 1px solid rgba(180, 150, 50, 0.4);
                border-top: none;
                border-radius: 0 0 12px 12px;
            }
        """)

        property_layout = QVBoxLayout(property_content)
        property_layout.setContentsMargins(12, 10, 12, 10)
        property_layout.setSpacing(6)

        # Filter bar for property section
        property_filter_bar = QFrame()
        property_filter_bar.setStyleSheet("""
            QFrame {
                background: rgba(100, 149, 237, 0.15);
                border: 1px solid rgba(100, 149, 237, 0.4);
                border-radius: 6px;
            }
        """)
        pfb_layout = QHBoxLayout(property_filter_bar)
        pfb_layout.setContentsMargins(8, 4, 8, 4)
        pfb_layout.setSpacing(6)
        pfb_label = QLabel("Filtered by:")
        pfb_label.setStyleSheet("font-size:15px; color:#333; background:transparent; border:none;")
        pfb_layout.addWidget(pfb_label)
        property_filter_value = QLabel("")
        property_filter_value.setStyleSheet("font-size:14px; font-weight:600; color:white; background:#6495ED; border:none; border-radius:3px; padding:2px 6px;")
        pfb_layout.addWidget(property_filter_value)
        pfb_layout.addStretch()
        property_clear_btn = QPushButton("✕")
        property_clear_btn.setFixedSize(18, 18)
        property_clear_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        property_clear_btn.setStyleSheet("QPushButton{background:rgba(0,0,0,0.1);color:#333;border:none;border-radius:3px;font-size:15px;font-weight:bold;}QPushButton:hover{background:rgba(0,0,0,0.2);}")
        property_clear_btn.clicked.connect(lambda: self._clear_section_filter("property"))
        pfb_layout.addWidget(property_clear_btn)
        property_filter_bar.setVisible(False)
        property_layout.addWidget(property_filter_bar)
        self._section_filters["property"] = {"bar": property_filter_bar, "label": property_filter_value, "entries": []}

        property_scroll = QScrollArea()
        property_scroll.setWidgetResizable(True)
        property_scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        property_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        property_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        property_scroll.setStyleSheet("""
            QScrollArea { background: transparent; border: none; }
            QScrollArea > QWidget > QWidget { background: transparent; }
        """)

        self.property_container = QWidget()
        self.property_container.setStyleSheet("background: transparent;")
        self.property_checkboxes_layout = QVBoxLayout(self.property_container)
        self.property_checkboxes_layout.setContentsMargins(2, 2, 2, 2)
        self.property_checkboxes_layout.setSpacing(12)
        self.property_checkboxes_layout.setAlignment(Qt.AlignmentFlag.AlignTop)

        property_scroll.setWidget(self.property_container)
        property_layout.addWidget(property_scroll)

        self.property_section.set_content(property_content)
        self.property_section.setVisible(False)
        self.main_layout.addWidget(self.property_section)

        self.main_layout.addStretch()
        main_scroll.setWidget(main_container)
        root.addWidget(main_scroll)

    def _send_to_card(self):
        """Generate text and send directly to card."""
        parts = []
        for cb in self._extracted_checkboxes:
            if cb.isChecked():
                parts.append(cb.property("full_text"))

        combined = "\n\n".join(parts) if parts else ""
        if combined:
            self.sent.emit(combined)

    def _apply_section_filter(self, section_key: str, subcategory: str):
        """Filter entries within a section to show only those with the specified subcategory."""
        if section_key not in self._section_filters:
            return

        section_data = self._section_filters[section_key]
        section_data["label"].setText(subcategory)
        section_data["bar"].setVisible(True)

        # Show/hide entries in this section only
        for entry_frame, entry_subcats in section_data["entries"]:
            if subcategory in entry_subcats:
                entry_frame.setVisible(True)
            else:
                entry_frame.setVisible(False)

    def _clear_section_filter(self, section_key: str):
        """Clear the filter for a specific section and show all its entries."""
        if section_key not in self._section_filters:
            return

        section_data = self._section_filters[section_key]
        section_data["bar"].setVisible(False)

        # Show all entries in this section
        for entry_frame, entry_subcats in section_data["entries"]:
            entry_frame.setVisible(True)

    def set_notes(self, notes: list):
        """Analyze notes for property damage incidents and populate the section."""
        try:
            from risk_overview_panel import analyze_notes_for_risk
        except ImportError:
            print("[TribunalRiskPropertyPopup] Could not import analyze_notes_for_risk")
            return

        # Clear existing entries and reset section filters
        self._extracted_checkboxes.clear()
        self._all_entry_frames.clear()
        self._current_filter = None
        # Reset all section filters
        for section_key in self._section_filters:
            self._section_filters[section_key]["bar"].setVisible(False)
            self._section_filters[section_key]["entries"].clear()
        while self.property_checkboxes_layout.count():
            item = self.property_checkboxes_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        # Analyze notes for risk
        results = analyze_notes_for_risk(notes)
        categories = results.get("categories", {})

        # Extract property damage incidents
        property_incidents = categories.get("Property Damage", {}).get("incidents", [])

        # Populate section
        self._populate_section(property_incidents, self.property_checkboxes_layout, self.property_section, "Property Damage Incidents", "property")

    def _populate_section(self, incidents: list, layout: QVBoxLayout, section, category_name: str, section_key: str = ""):
        """Populate a section with incident entries, deduplicated by date."""
        if not incidents:
            section.setVisible(False)
            return

        section.setVisible(True)

        from collections import defaultdict

        def get_date_key(item):
            dt = item.get("date")
            if dt is None:
                return "no_date"
            if hasattr(dt, "strftime"):
                return dt.strftime("%Y-%m-%d")
            return str(dt)

        # Group by date
        date_groups = defaultdict(list)
        for incident in incidents:
            date_key = get_date_key(incident)
            date_groups[date_key].append(incident)

        # Process each date group to create deduplicated entries
        deduplicated_entries = []
        for date_key, group in date_groups.items():
            subcategories = {}
            texts = []
            matched_terms_all = set()
            representative_date = None

            for inc in group:
                subcat = inc.get("subcategory", "")
                severity = inc.get("severity", "medium")
                matched = inc.get("matched", "")
                text = inc.get("full_text", "").strip()
                dt = inc.get("date")

                if representative_date is None:
                    representative_date = dt

                if text:
                    texts.append(text)

                if matched:
                    matched_terms_all.add(matched)

                if subcat:
                    if subcat not in subcategories:
                        subcategories[subcat] = {"severity": severity, "matched_terms": set()}
                    severity_rank = {"high": 3, "medium": 2, "low": 1}
                    if severity_rank.get(severity, 0) > severity_rank.get(subcategories[subcat]["severity"], 0):
                        subcategories[subcat]["severity"] = severity
                    if matched:
                        subcategories[subcat]["matched_terms"].add(matched)

            best_text = ""
            best_score = -1
            for text in texts:
                text_lower = text.lower()
                score = len(text)
                for term in matched_terms_all:
                    if term.lower() in text_lower:
                        score += 100
                if score > best_score:
                    best_score = score
                    best_text = text

            if best_text:
                deduplicated_entries.append({
                    "date": representative_date,
                    "date_key": date_key,
                    "text": best_text,
                    "subcategories": subcategories,
                    "matched_terms": matched_terms_all,
                })

        deduplicated_entries.sort(key=lambda x: x["date_key"], reverse=True)

        # Update section title with deduplicated count
        if deduplicated_entries:
            section.title_label.setText(f"{category_name} ({len(deduplicated_entries)})")

        # Create UI entries
        for entry in deduplicated_entries:
            dt = entry["date"]
            text = entry["text"]
            subcategories = entry["subcategories"]
            matched_terms = entry["matched_terms"]

            if dt:
                if hasattr(dt, "strftime"):
                    date_str = dt.strftime("%d %b %Y")
                else:
                    date_str = str(dt)
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

            # Toggle button first
            toggle_btn = QPushButton("▸")
            toggle_btn.setFixedSize(22, 22)
            toggle_btn.setCursor(Qt.CursorShape.PointingHandCursor)
            toggle_btn.setStyleSheet("""
                QPushButton {
                    background: rgba(180, 150, 50, 0.2);
                    border: none;
                    border-radius: 4px;
                    font-size: 17px;
                    font-weight: bold;
                    color: #806000;
                }
                QPushButton:hover { background: rgba(180, 150, 50, 0.35); }
            """)
            header_row.addWidget(toggle_btn)

            date_label = QLabel(f"📅 {date_str}")
            date_label.setStyleSheet("""
                QLabel {
                    font-size: 17px;
                    font-weight: 600;
                    color: #806000;
                    background: transparent;
                    border: none;
                }
            """)
            date_label.setCursor(Qt.CursorShape.PointingHandCursor)
            header_row.addWidget(date_label)

            header_row.addStretch()

            # Checkbox at the end
            cb = QCheckBox()
            cb.setProperty("full_text", text)
            cb.setFixedSize(18, 18)
            cb.setStyleSheet("""
                QCheckBox { background: transparent; }
                QCheckBox::indicator { width: 16px; height: 16px; }
            """)
            cb.stateChanged.connect(self._send_to_card)
            header_row.addWidget(cb)

            entry_layout.addLayout(header_row)

            # Add subcategory badges stacked vertically (clickable for filtering)
            severity_colors = {"high": "#c0392b", "medium": "#f39c12", "low": "#27ae60"}
            severity_rank = {"high": 3, "medium": 2, "low": 1}
            sorted_subcats = sorted(
                subcategories.items(),
                key=lambda x: severity_rank.get(x[1]["severity"], 0),
                reverse=True
            )
            entry_subcat_names = list(subcategories.keys())
            if sorted_subcats:
                badges_layout = QVBoxLayout()
                badges_layout.setContentsMargins(30, 0, 0, 4)
                badges_layout.setSpacing(4)
                for subcat_name, subcat_info in sorted_subcats:
                    badge_color = severity_colors.get(subcat_info["severity"], "#808080")
                    subcat_label = QLabel(f"{subcat_name}")
                    subcat_label.setStyleSheet(f"""
                        QLabel {{
                            font-size: 14px;
                            font-weight: 500;
                            color: white;
                            background: {badge_color};
                            border: none;
                            border-radius: 3px;
                            padding: 2px 6px;
                        }}
                        QLabel:hover {{
                            background: {badge_color};
                            border: 2px solid white;
                        }}
                    """)
                    subcat_label.setSizePolicy(QSizePolicy.Policy.Maximum, QSizePolicy.Policy.Fixed)
                    subcat_label.setCursor(Qt.CursorShape.PointingHandCursor)
                    # Make label clickable for filtering (section-specific)
                    subcat_label.mousePressEvent = lambda e, name=subcat_name, sk=section_key: self._apply_section_filter(sk, name)
                    badges_layout.addWidget(subcat_label)
                entry_layout.addLayout(badges_layout)

            # Store entry frame with its subcategories for section-specific filtering
            self._all_entry_frames.append((entry_frame, entry_subcat_names))
            if section_key and section_key in self._section_filters:
                self._section_filters[section_key]["entries"].append((entry_frame, entry_subcat_names))

            body_text = QTextEdit()
            body_text.setReadOnly(True)
            body_text.setFrameShape(QFrame.Shape.NoFrame)
            body_text.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            body_text.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            body_text.setStyleSheet("""
                QTextEdit {
                    font-size: 17px;
                    color: #333;
                    background: rgba(255, 248, 220, 0.5);
                    border: none;
                    border-radius: 4px;
                    padding: 6px;
                }
            """)
            body_text.setVisible(False)

            # Highlight all matched terms in the text
            if matched_terms:
                import html
                import re
                escaped_text = html.escape(text)
                for term in matched_terms:
                    if term:
                        pattern = re.compile(re.escape(html.escape(term)), re.IGNORECASE)
                        escaped_text = pattern.sub(
                            f'<span style="background-color: #ffeb3b; padding: 1px 3px; border-radius: 2px; font-weight: 600;">\\g<0></span>',
                            escaped_text
                        )
                body_text.setHtml(f'<div style="font-size: 17px; color: #333;">{escaped_text}</div>')
            else:
                body_text.setPlainText(text)

            # Calculate height based on content
            doc = body_text.document()
            doc.setTextWidth(body_text.viewport().width() if body_text.viewport().width() > 0 else 400)
            content_height = int(doc.size().height()) + 20
            body_text.setFixedHeight(min(content_height, 200))

            def make_toggle(btn, body):
                def toggle():
                    if body.isVisible():
                        body.setVisible(False)
                        btn.setText("▸")
                    else:
                        body.setVisible(True)
                        btn.setText("▾")
                return toggle

            toggle_btn.clicked.connect(make_toggle(toggle_btn, body_text))
            date_label.mousePressEvent = lambda e, btn=toggle_btn: btn.click()

            entry_layout.addWidget(body_text)
            self._extracted_checkboxes.append(cb)
            layout.addWidget(entry_frame)

    def set_entries(self, items: list, date_info: str = ""):
        """Legacy compatibility method - redirect to set_notes if passed raw notes."""
        if items and isinstance(items, list) and len(items) > 0:
            first_item = items[0]
            if isinstance(first_item, dict) and ('text' in first_item or 'content' in first_item or 'body' in first_item):
                self.set_notes(items)
                return

        all_incidents = []
        for item in items:
            if isinstance(item, dict):
                all_incidents.append({
                    "date": item.get("date"),
                    "full_text": item.get("text", item.get("content", item.get("body", ""))),
                    "subcategory": item.get("subcategory", ""),
                    "severity": item.get("severity", "medium"),
                })
            elif isinstance(item, str):
                all_incidents.append({
                    "date": None,
                    "full_text": item,
                    "subcategory": "",
                    "severity": "medium",
                })

        self._populate_section(all_incidents, self.property_checkboxes_layout, self.property_section, "Incidents")


# ================================================================
# TRIBUNAL AWOL POPUP (for nursing section 10 - AWOL/Failed Return)
# ================================================================

# AWOL search terms
AWOL_SEARCH_TERMS = [
    "awol", "absent without leave", "escaped", "went missing", "gone missing",
    "missing from ward", "missing from the ward", "missing from unit", "missing from the unit",
    "failed to return from leave", "failed to return from pass", "failed to return to the ward",
    "failed to return to the unit", "failed to return to hospital",
    "did not return from leave", "did not return from pass", "did not return to the ward",
    "did not return to the unit", "did not return to hospital", "did not return from overnight",
    "absconded", "abscond", "left without permission", "unauthorised absence",
]

AWOL_EXCLUDE_TERMS = [
    "no risk of awol", "no awol", "nil awol", "not awol", "risk of awol low",
    "low risk of awol", "no history of awol", "no previous awol", "never been awol",
    "has not been awol", "has not gone awol", "no episodes of awol", "no incidents of awol",
    "denies awol", "no absconding", "nil absconding", "no escape", "nil escape",
    "no missing", "not missing", "returned safely", "returned on time",
]


class TribunalAWOLPopup(QWidget):
    """Popup for AWOL/Failed Return section with categorized concerns in yellow collapsible entries.

    Features:
    - Preview section at top with Send to Report button
    - Searches notes for AWOL-related terms
    - Yellow collapsible entries for each concern
    - Clickable labels to filter by subcategory
    - Identical UI to TribunalRiskPropertyPopup
    """

    sent = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        self._entries = []
        self._extracted_checkboxes = []
        self._current_filter = None
        self._all_entry_frames = []
        self._section_filters = {}  # {section_key: {"bar": QFrame, "label": QLabel, "entries": []}}
        self._setup_ui()

    def _setup_ui(self):
        from background_history_popup import ResizableSection, CollapsibleSection

        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        # Main scroll area
        main_scroll = QScrollArea()
        main_scroll.setWidgetResizable(True)
        main_scroll.setFrameShape(QScrollArea.NoFrame)
        main_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        main_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        main_container = QWidget()
        main_layout = QVBoxLayout(main_container)
        main_layout.setContentsMargins(4, 4, 4, 4)
        main_layout.setSpacing(8)

        # ====================================================
        # SECTION 1: AWOL CONCERNS (collapsible)
        # ====================================================
        self.awol_section = CollapsibleSection("AWOL / Failed Return Concerns", start_collapsed=True)
        self.awol_section.set_content_height(350)
        self.awol_section._min_height = 100
        self.awol_section._max_height = 600
        self.awol_section.set_header_style("""
            QFrame {
                background: rgba(255, 152, 0, 0.2);
                border: 1px solid rgba(255, 152, 0, 0.4);
                border-radius: 6px 6px 0 0;
            }
        """)
        self.awol_section.set_title_style("""
            QLabel {
                font-size: 18px;
                font-weight: 600;
                color: #e65100;
                background: transparent;
                border: none;
            }
        """)

        awol_content = QWidget()
        awol_content.setStyleSheet("""
            QWidget {
                background: rgba(255, 248, 220, 0.95);
                border: 1px solid rgba(180, 150, 50, 0.4);
                border-top: none;
                border-radius: 0 0 12px 12px;
            }
        """)

        awol_layout = QVBoxLayout(awol_content)
        awol_layout.setContentsMargins(12, 10, 12, 10)
        awol_layout.setSpacing(6)

        # Filter bar for awol section
        awol_filter_bar = QFrame()
        awol_filter_bar.setStyleSheet("""
            QFrame {
                background: rgba(100, 149, 237, 0.15);
                border: 1px solid rgba(100, 149, 237, 0.4);
                border-radius: 6px;
            }
        """)
        afb_layout = QHBoxLayout(awol_filter_bar)
        afb_layout.setContentsMargins(8, 4, 8, 4)
        afb_layout.setSpacing(6)
        afb_label = QLabel("Filtered by:")
        afb_label.setStyleSheet("font-size:15px; color:#333; background:transparent; border:none;")
        afb_layout.addWidget(afb_label)
        awol_filter_value = QLabel("")
        awol_filter_value.setStyleSheet("font-size:14px; font-weight:600; color:white; background:#6495ED; border:none; border-radius:3px; padding:2px 6px;")
        afb_layout.addWidget(awol_filter_value)
        afb_layout.addStretch()
        awol_clear_btn = QPushButton("✕")
        awol_clear_btn.setFixedSize(18, 18)
        awol_clear_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        awol_clear_btn.setStyleSheet("QPushButton{background:rgba(0,0,0,0.1);color:#333;border:none;border-radius:3px;font-size:15px;font-weight:bold;}QPushButton:hover{background:rgba(0,0,0,0.2);}")
        awol_clear_btn.clicked.connect(lambda: self._clear_section_filter("awol"))
        afb_layout.addWidget(awol_clear_btn)
        awol_filter_bar.setVisible(False)
        awol_layout.addWidget(awol_filter_bar)
        self._section_filters["awol"] = {"bar": awol_filter_bar, "label": awol_filter_value, "entries": []}

        awol_scroll = QScrollArea()
        awol_scroll.setWidgetResizable(True)
        awol_scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        awol_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        awol_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        awol_scroll.setStyleSheet("""
            QScrollArea { background: transparent; border: none; }
            QScrollArea > QWidget > QWidget { background: transparent; }
        """)

        self.awol_container = QWidget()
        self.awol_container.setStyleSheet("background: transparent;")
        self.awol_checkboxes_layout = QVBoxLayout(self.awol_container)
        self.awol_checkboxes_layout.setContentsMargins(2, 2, 2, 2)
        self.awol_checkboxes_layout.setSpacing(12)
        self.awol_checkboxes_layout.setAlignment(Qt.AlignmentFlag.AlignTop)

        awol_scroll.setWidget(self.awol_container)
        awol_layout.addWidget(awol_scroll)

        self.awol_section.set_content(awol_content)
        self.awol_section.setVisible(False)
        main_layout.addWidget(self.awol_section)

        main_layout.addStretch()
        main_scroll.setWidget(main_container)
        root.addWidget(main_scroll)

    def _send_to_card(self):
        """Generate text and send directly to card."""
        parts = []
        for cb in self._extracted_checkboxes:
            if cb.isChecked():
                parts.append(cb.property("full_text"))

        combined = "\n\n".join(parts) if parts else ""
        if combined:
            self.sent.emit(combined)

    def _apply_section_filter(self, section_key: str, subcategory: str):
        """Filter entries within a section to show only those with the specified subcategory."""
        if section_key not in self._section_filters:
            return

        section_data = self._section_filters[section_key]
        section_data["label"].setText(subcategory)
        section_data["bar"].setVisible(True)

        # Show/hide entries in this section only
        for entry_frame, entry_subcats in section_data["entries"]:
            if subcategory in entry_subcats:
                entry_frame.setVisible(True)
            else:
                entry_frame.setVisible(False)

    def _clear_section_filter(self, section_key: str):
        """Clear the filter for a specific section and show all its entries."""
        if section_key not in self._section_filters:
            return

        section_data = self._section_filters[section_key]
        section_data["bar"].setVisible(False)

        # Show all entries in this section
        for entry_frame, entry_subcats in section_data["entries"]:
            entry_frame.setVisible(True)

    def set_notes(self, notes: list):
        """Search notes for AWOL incidents and populate the section."""
        import re
        from datetime import datetime

        # Clear existing entries and reset section filters
        self._extracted_checkboxes.clear()
        self._all_entry_frames.clear()
        self._current_filter = None
        for section_key in self._section_filters:
            self._section_filters[section_key]["bar"].setVisible(False)
            self._section_filters[section_key]["entries"].clear()
        while self.awol_checkboxes_layout.count():
            item = self.awol_checkboxes_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        if not notes:
            self.awol_section.setVisible(False)
            return

        # Search for AWOL incidents
        awol_incidents = []

        def parse_date(date_val):
            if not date_val:
                return None
            if isinstance(date_val, datetime):
                return date_val
            for fmt in ["%Y-%m-%d", "%d/%m/%Y", "%Y-%m-%dT%H:%M:%S", "%d-%m-%Y"]:
                try:
                    return datetime.strptime(str(date_val)[:10], fmt[:min(len(fmt), 10)])
                except:
                    pass
            return None

        for note in notes:
            content = note.get("content", "") or note.get("text", "") or note.get("body", "")
            if not content:
                continue

            content_lower = content.lower()

            # Skip if contains exclusion terms
            if any(ex in content_lower for ex in AWOL_EXCLUDE_TERMS):
                continue

            # Check for AWOL terms
            matched_term = None
            for term in AWOL_SEARCH_TERMS:
                if term in content_lower:
                    matched_term = term
                    break

            if matched_term:
                note_date = parse_date(note.get("date") or note.get("datetime"))

                # Determine subcategory based on matched term
                if matched_term in ["awol", "absent without leave"]:
                    subcategory = "AWOL"
                elif matched_term in ["absconded", "abscond"]:
                    subcategory = "Absconded"
                elif matched_term in ["escaped"]:
                    subcategory = "Escaped"
                elif matched_term in ["went missing", "gone missing", "missing from ward", "missing from the ward", "missing from unit", "missing from the unit"]:
                    subcategory = "Missing"
                elif "failed to return" in matched_term or "did not return" in matched_term:
                    subcategory = "Failed Return"
                else:
                    subcategory = "AWOL"

                awol_incidents.append({
                    "date": note_date,
                    "full_text": content.strip(),
                    "subcategory": subcategory,
                    "severity": "high",  # AWOL is always high severity
                    "matched": matched_term,
                })

        print(f"[TribunalAWOLPopup] Found {len(awol_incidents)} AWOL concerns")

        # Populate section
        self._populate_section(awol_incidents, self.awol_checkboxes_layout, self.awol_section, "AWOL / Failed Return Concerns", "awol")

    def _populate_section(self, incidents: list, layout: QVBoxLayout, section, category_name: str, section_key: str = ""):
        """Populate a section with incident entries, deduplicated by date."""
        if not incidents:
            section.setVisible(False)
            return

        section.setVisible(True)

        from collections import defaultdict
        from datetime import datetime

        def get_date_key(item):
            dt = item.get("date")
            if dt is None:
                return "no_date"
            if hasattr(dt, "strftime"):
                return dt.strftime("%Y-%m-%d")
            return str(dt)

        # Group by date
        date_groups = defaultdict(list)
        for incident in incidents:
            date_key = get_date_key(incident)
            date_groups[date_key].append(incident)

        # Process each date group to create deduplicated entries
        deduplicated_entries = []
        for date_key, group in date_groups.items():
            subcategories = {}
            texts = []
            matched_terms_all = set()
            representative_date = None

            for inc in group:
                subcat = inc.get("subcategory", "")
                severity = inc.get("severity", "high")
                matched = inc.get("matched", "")
                text = inc.get("full_text", "").strip()
                dt = inc.get("date")

                if representative_date is None:
                    representative_date = dt

                if text:
                    texts.append(text)

                if matched:
                    matched_terms_all.add(matched)

                if subcat:
                    if subcat not in subcategories:
                        subcategories[subcat] = {"severity": severity, "matched_terms": set()}
                    if matched:
                        subcategories[subcat]["matched_terms"].add(matched)

            best_text = ""
            best_score = -1
            for text in texts:
                text_lower = text.lower()
                score = len(text)
                for term in matched_terms_all:
                    if term.lower() in text_lower:
                        score += 100
                if score > best_score:
                    best_score = score
                    best_text = text

            if best_text:
                deduplicated_entries.append({
                    "date": representative_date,
                    "date_key": date_key,
                    "text": best_text,
                    "subcategories": subcategories,
                    "matched_terms": matched_terms_all,
                })

        deduplicated_entries.sort(key=lambda x: x["date_key"], reverse=True)

        # Update section title with deduplicated count
        if deduplicated_entries:
            section.title_label.setText(f"{category_name} ({len(deduplicated_entries)})")

        # Create UI entries
        for entry in deduplicated_entries:
            dt = entry["date"]
            text = entry["text"]
            subcategories = entry["subcategories"]
            matched_terms = entry["matched_terms"]

            if dt:
                if hasattr(dt, "strftime"):
                    date_str = dt.strftime("%d %b %Y")
                else:
                    date_str = str(dt)
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

            # Toggle button first
            toggle_btn = QPushButton("▸")
            toggle_btn.setFixedSize(22, 22)
            toggle_btn.setCursor(Qt.CursorShape.PointingHandCursor)
            toggle_btn.setStyleSheet("""
                QPushButton {
                    background: rgba(180, 150, 50, 0.2);
                    border: none;
                    border-radius: 4px;
                    font-size: 17px;
                    font-weight: bold;
                    color: #806000;
                }
                QPushButton:hover { background: rgba(180, 150, 50, 0.35); }
            """)
            header_row.addWidget(toggle_btn)

            date_label = QLabel(f"📅 {date_str}")
            date_label.setStyleSheet("""
                QLabel {
                    font-size: 17px;
                    font-weight: 600;
                    color: #806000;
                    background: transparent;
                    border: none;
                }
            """)
            date_label.setCursor(Qt.CursorShape.PointingHandCursor)
            header_row.addWidget(date_label)

            header_row.addStretch()

            # Checkbox at the end
            cb = QCheckBox()
            cb.setProperty("full_text", text)
            cb.setFixedSize(18, 18)
            cb.setStyleSheet("""
                QCheckBox { background: transparent; }
                QCheckBox::indicator { width: 16px; height: 16px; }
            """)
            cb.stateChanged.connect(self._send_to_card)
            header_row.addWidget(cb)

            entry_layout.addLayout(header_row)

            # Add subcategory badges stacked vertically (clickable for filtering)
            # AWOL uses orange colors
            severity_colors = {"high": "#e65100", "medium": "#f39c12", "low": "#27ae60"}
            severity_rank = {"high": 3, "medium": 2, "low": 1}
            sorted_subcats = sorted(
                subcategories.items(),
                key=lambda x: severity_rank.get(x[1]["severity"], 0),
                reverse=True
            )
            entry_subcat_names = list(subcategories.keys())
            if sorted_subcats:
                badges_layout = QVBoxLayout()
                badges_layout.setContentsMargins(30, 0, 0, 4)
                badges_layout.setSpacing(4)
                for subcat_name, subcat_info in sorted_subcats:
                    badge_color = severity_colors.get(subcat_info["severity"], "#e65100")
                    subcat_label = QLabel(f"{subcat_name}")
                    subcat_label.setStyleSheet(f"""
                        QLabel {{
                            font-size: 14px;
                            font-weight: 500;
                            color: white;
                            background: {badge_color};
                            border: none;
                            border-radius: 3px;
                            padding: 2px 6px;
                        }}
                        QLabel:hover {{
                            background: {badge_color};
                            border: 2px solid white;
                        }}
                    """)
                    subcat_label.setSizePolicy(QSizePolicy.Policy.Maximum, QSizePolicy.Policy.Fixed)
                    subcat_label.setCursor(Qt.CursorShape.PointingHandCursor)
                    # Make label clickable for filtering (section-specific)
                    subcat_label.mousePressEvent = lambda e, name=subcat_name, sk=section_key: self._apply_section_filter(sk, name)
                    badges_layout.addWidget(subcat_label)
                entry_layout.addLayout(badges_layout)

            # Store entry frame with its subcategories for section-specific filtering
            self._all_entry_frames.append((entry_frame, entry_subcat_names))
            if section_key and section_key in self._section_filters:
                self._section_filters[section_key]["entries"].append((entry_frame, entry_subcat_names))

            body_text = QTextEdit()
            body_text.setReadOnly(True)
            body_text.setFrameShape(QFrame.Shape.NoFrame)
            body_text.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            body_text.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            body_text.setStyleSheet("""
                QTextEdit {
                    font-size: 17px;
                    color: #333;
                    background: rgba(255, 248, 220, 0.5);
                    border: none;
                    border-radius: 4px;
                    padding: 6px;
                }
            """)
            body_text.setVisible(False)

            # Highlight all matched terms in the text
            if matched_terms:
                import html
                escaped_text = html.escape(text)
                for term in matched_terms:
                    if term:
                        import re
                        pattern = re.compile(re.escape(html.escape(term)), re.IGNORECASE)
                        escaped_text = pattern.sub(
                            f'<span style="background-color: #ffeb3b; padding: 1px 3px; border-radius: 2px; font-weight: 600;">\\g<0></span>',
                            escaped_text
                        )
                body_text.setHtml(f'<div style="font-size: 17px; color: #333;">{escaped_text}</div>')
            else:
                body_text.setPlainText(text)

            # Calculate height based on content
            doc = body_text.document()
            doc.setTextWidth(body_text.viewport().width() if body_text.viewport().width() > 0 else 400)
            content_height = int(doc.size().height()) + 20
            body_text.setFixedHeight(min(content_height, 200))

            def make_toggle(btn, body):
                def toggle():
                    if body.isVisible():
                        body.setVisible(False)
                        btn.setText("▸")
                    else:
                        body.setVisible(True)
                        btn.setText("▾")
                return toggle

            toggle_btn.clicked.connect(make_toggle(toggle_btn, body_text))
            date_label.mousePressEvent = lambda e, btn=toggle_btn: btn.click()

            entry_layout.addWidget(body_text)
            self._extracted_checkboxes.append(cb)
            layout.addWidget(entry_frame)

    def set_entries(self, items: list, date_info: str = ""):
        """Legacy compatibility method - redirect to set_notes if passed raw notes."""
        if items and isinstance(items, list) and len(items) > 0:
            first_item = items[0]
            if isinstance(first_item, dict) and ('text' in first_item or 'content' in first_item or 'body' in first_item):
                self.set_notes(items)
                return

        all_incidents = []
        for item in items:
            if isinstance(item, dict):
                all_incidents.append({
                    "date": item.get("date"),
                    "full_text": item.get("text", item.get("content", item.get("body", ""))),
                    "subcategory": item.get("subcategory", "AWOL"),
                    "severity": item.get("severity", "high"),
                })
            elif isinstance(item, str):
                all_incidents.append({
                    "date": None,
                    "full_text": item,
                    "subcategory": "AWOL",
                    "severity": "high",
                })

        self._populate_section(all_incidents, self.awol_checkboxes_layout, self.awol_section, "AWOL Concerns")


# ================================================================
# TRIBUNAL COMPLIANCE POPUP (for nursing section 11 - Non-Compliance Concerns)
# ================================================================

# Non-compliance search terms
COMPLIANCE_SEARCH_TERMS = [
    "non-compliant", "non compliant", "noncompliant", "not compliant",
    "refused medication", "refusing medication", "refuses medication",
    "declined medication", "declining medication", "declines medication",
    "refused treatment", "refusing treatment", "refuses treatment",
    "declined treatment", "declining treatment", "declines treatment",
    "not taking medication", "stopped taking medication", "stopped medication",
    "non-adherent", "non adherent", "nonadherent", "poor adherence",
    "poor compliance", "limited compliance", "partial compliance",
    "medication refusal", "treatment refusal",
    "covert medication", "covert meds", "hidden medication",
    "spitting out", "spat out", "hiding medication", "hiding meds",
    "cheeking medication", "cheeking meds", "palming medication",
    "not engaging", "refuses to engage", "refused to engage",
    "disengaged from", "disengaging from",
]

COMPLIANCE_EXCLUDE_TERMS = [
    "good compliance", "full compliance", "compliant with",
    "taking medication", "takes medication", "accepts medication",
    "no concerns", "nil concerns", "no issues with compliance",
    "compliant", "adherent", "engaged well",
]


class TribunalCompliancePopup(QWidget):
    """Popup for Compliance section with input boxes AND imported non-compliance concerns.

    Features:
    - Preview section at top with Send to Report button
    - Grid with treatment rows (Medical, Nursing, Psychology, OT, Social Work)
    - Understanding and Compliance dropdowns for each treatment
    - Imported Data section with non-compliance concerns from notes
    - Yellow collapsible entries for each concern
    - Identical UI style to TribunalAWOLPopup for imported section
    """

    sent = Signal(str)

    UNDERSTANDING_OPTIONS = ["Select...", "good", "fair", "poor"]
    COMPLIANCE_OPTIONS = ["Select...", "full", "reasonable", "partial", "nil"]

    def __init__(self, parent=None, gender="Male"):
        super().__init__(parent)
        self.gender = gender
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        self._entries = []
        self._extracted_checkboxes = []
        self._current_filter = None
        self._all_entry_frames = []
        self._section_filters = {}
        self._setup_ui()

    def _get_pronouns(self):
        g = (self.gender or "").lower().strip()
        if g == "male":
            return {"subj": "He", "obj": "him", "pos": "his", "is": "is", "has": "has", "does": "does", "sees": "sees", "engages": "engages"}
        elif g == "female":
            return {"subj": "She", "obj": "her", "pos": "her", "is": "is", "has": "has", "does": "does", "sees": "sees", "engages": "engages"}
        return {"subj": "They", "obj": "them", "pos": "their", "is": "are", "has": "have", "does": "do", "sees": "see", "engages": "engage"}

    def set_gender(self, gender: str):
        self.gender = gender
        self._send_to_card()

    def _setup_ui(self):
        from background_history_popup import ResizableSection, CollapsibleSection

        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        # Main scroll area
        main_scroll = QScrollArea()
        main_scroll.setWidgetResizable(True)
        main_scroll.setFrameShape(QScrollArea.NoFrame)
        main_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        main_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        main_container = QWidget()
        self.main_layout = QVBoxLayout(main_container)
        self.main_layout.setContentsMargins(4, 4, 4, 4)
        self.main_layout.setSpacing(8)

        # ====================================================
        # SECTION 1: INPUT GRID (Understanding & Compliance)
        # ====================================================
        input_section = CollapsibleSection("Understanding & Compliance", start_collapsed=True)
        input_section.set_content_height(220)
        input_section._min_height = 100
        input_section._max_height = 400
        input_section.set_header_style("""
            QFrame {
                background: rgba(200, 220, 255, 0.95);
                border: 1px solid rgba(100, 150, 200, 0.4);
                border-radius: 6px 6px 0 0;
            }
        """)
        input_section.set_title_style("""
            QLabel {
                font-size: 18px;
                font-weight: 600;
                color: #1565c0;
                background: transparent;
                border: none;
            }
        """)

        input_content = QWidget()
        input_content.setStyleSheet("""
            QWidget {
                background: rgba(255, 255, 255, 0.95);
                border: 1px solid rgba(100, 150, 200, 0.4);
                border-top: none;
                border-radius: 0 0 12px 12px;
            }
        """)

        input_layout = QVBoxLayout(input_content)
        input_layout.setContentsMargins(12, 10, 12, 10)
        input_layout.setSpacing(8)

        # Grid for treatments
        grid = QGridLayout()
        grid.setSpacing(8)

        # Headers
        header_treatment = QLabel("Treatment")
        header_treatment.setStyleSheet("font-size: 17px; font-weight: 600; color: #374151; background: transparent; border: none;")
        header_understanding = QLabel("Understanding")
        header_understanding.setStyleSheet("font-size: 17px; font-weight: 600; color: #374151; background: transparent; border: none;")
        header_compliance = QLabel("Compliance")
        header_compliance.setStyleSheet("font-size: 17px; font-weight: 600; color: #374151; background: transparent; border: none;")

        grid.addWidget(header_treatment, 0, 0)
        grid.addWidget(header_understanding, 0, 1)
        grid.addWidget(header_compliance, 0, 2)

        # Treatment rows
        self.treatments = {}
        treatment_names = ["Medical", "Nursing", "Psychology", "OT", "Social Work"]

        combo_style = """
            QComboBox {
                background: white;
                border: 1px solid #9ca3af;
                border-radius: 4px;
                padding: 4px 8px;
                font-size: 17px;
                min-height: 24px;
            }
            QComboBox:hover { border-color: #14b8a6; }
            QComboBox::drop-down { border: none; width: 20px; }
        """

        for i, name in enumerate(treatment_names, 1):
            key = name.lower().replace(" ", "_")

            # Label
            lbl = QLabel(name)
            lbl.setStyleSheet("font-size: 17px; color: #374151; background: transparent; border: none;")
            grid.addWidget(lbl, i, 0)

            # Understanding dropdown
            understanding = QComboBox()
            understanding.addItems(self.UNDERSTANDING_OPTIONS)
            understanding.setStyleSheet(combo_style)
            understanding.currentIndexChanged.connect(self._send_to_card)
            grid.addWidget(understanding, i, 1)

            # Compliance dropdown
            compliance = QComboBox()
            compliance.addItems(self.COMPLIANCE_OPTIONS)
            compliance.setStyleSheet(combo_style)
            compliance.currentIndexChanged.connect(self._send_to_card)
            grid.addWidget(compliance, i, 2)

            self.treatments[key] = {
                "understanding": understanding,
                "compliance": compliance
            }

        input_layout.addLayout(grid)
        input_section.set_content(input_content)
        self.main_layout.addWidget(input_section)

        # ====================================================
        # SECTION 3: NON-COMPLIANCE CONCERNS (collapsible)
        # ====================================================
        self.compliance_section = CollapsibleSection("Non-Compliance Concerns", start_collapsed=True)
        self.compliance_section.set_content_height(300)
        self.compliance_section._min_height = 100
        self.compliance_section._max_height = 500
        self.compliance_section.set_header_style("""
            QFrame {
                background: rgba(156, 39, 176, 0.2);
                border: 1px solid rgba(156, 39, 176, 0.4);
                border-radius: 6px 6px 0 0;
            }
        """)
        self.compliance_section.set_title_style("""
            QLabel {
                font-size: 18px;
                font-weight: 600;
                color: #7b1fa2;
                background: transparent;
                border: none;
            }
        """)

        compliance_content = QWidget()
        compliance_content.setStyleSheet("""
            QWidget {
                background: rgba(255, 248, 220, 0.95);
                border: 1px solid rgba(180, 150, 50, 0.4);
                border-top: none;
                border-radius: 0 0 12px 12px;
            }
        """)

        compliance_layout = QVBoxLayout(compliance_content)
        compliance_layout.setContentsMargins(12, 10, 12, 10)
        compliance_layout.setSpacing(6)

        # Filter bar for compliance section
        compliance_filter_bar = QFrame()
        compliance_filter_bar.setStyleSheet("""
            QFrame {
                background: rgba(100, 149, 237, 0.15);
                border: 1px solid rgba(100, 149, 237, 0.4);
                border-radius: 6px;
            }
        """)
        cfb_layout = QHBoxLayout(compliance_filter_bar)
        cfb_layout.setContentsMargins(8, 4, 8, 4)
        cfb_layout.setSpacing(6)
        cfb_label = QLabel("Filtered by:")
        cfb_label.setStyleSheet("font-size:15px; color:#333; background:transparent; border:none;")
        cfb_layout.addWidget(cfb_label)
        compliance_filter_value = QLabel("")
        compliance_filter_value.setStyleSheet("font-size:14px; font-weight:600; color:white; background:#6495ED; border:none; border-radius:3px; padding:2px 6px;")
        cfb_layout.addWidget(compliance_filter_value)
        cfb_layout.addStretch()
        compliance_clear_btn = QPushButton("✕")
        compliance_clear_btn.setFixedSize(18, 18)
        compliance_clear_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        compliance_clear_btn.setStyleSheet("QPushButton{background:rgba(0,0,0,0.1);color:#333;border:none;border-radius:3px;font-size:15px;font-weight:bold;}QPushButton:hover{background:rgba(0,0,0,0.2);}")
        compliance_clear_btn.clicked.connect(lambda: self._clear_section_filter("compliance"))
        cfb_layout.addWidget(compliance_clear_btn)
        compliance_filter_bar.setVisible(False)
        compliance_layout.addWidget(compliance_filter_bar)
        self._section_filters["compliance"] = {"bar": compliance_filter_bar, "label": compliance_filter_value, "entries": []}

        compliance_scroll = QScrollArea()
        compliance_scroll.setWidgetResizable(True)
        compliance_scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        compliance_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        compliance_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        compliance_scroll.setStyleSheet("""
            QScrollArea { background: transparent; border: none; }
            QScrollArea > QWidget > QWidget { background: transparent; }
        """)

        self.compliance_container = QWidget()
        self.compliance_container.setStyleSheet("background: transparent;")
        self.compliance_checkboxes_layout = QVBoxLayout(self.compliance_container)
        self.compliance_checkboxes_layout.setContentsMargins(2, 2, 2, 2)
        self.compliance_checkboxes_layout.setSpacing(12)
        self.compliance_checkboxes_layout.setAlignment(Qt.AlignmentFlag.AlignTop)

        compliance_scroll.setWidget(self.compliance_container)
        compliance_layout.addWidget(compliance_scroll)

        self.compliance_section.set_content(compliance_content)
        self.compliance_section.setVisible(False)
        self.main_layout.addWidget(self.compliance_section)

        self.main_layout.addStretch()
        main_scroll.setWidget(main_container)
        root.addWidget(main_scroll)

    def _send_to_card(self):
        """Generate text and send directly to card."""
        parts = []

        # Add text from dropdown selections
        dropdown_text = self._generate_dropdown_text()
        if dropdown_text:
            parts.append(dropdown_text)

        # Add text from checked imported entries
        for cb in self._extracted_checkboxes:
            if cb.isChecked():
                parts.append(cb.property("full_text"))

        combined = "\n\n".join(parts) if parts else ""
        if combined:
            self.sent.emit(combined)

    def _generate_dropdown_text(self) -> str:
        """Generate text from dropdown selections."""
        p = self._get_pronouns()
        sentences = []

        for key, widgets in self.treatments.items():
            understanding = widgets["understanding"].currentText()
            compliance = widgets["compliance"].currentText()

            if understanding == "Select..." or compliance == "Select...":
                continue

            name = key.replace("_", " ").title()

            # Generate phrase based on treatment type
            if key == "nursing":
                phrase = self._nursing_phrase(understanding, compliance, p)
            elif key == "psychology":
                phrase = self._psychology_phrase(understanding, compliance, p)
            elif key == "ot":
                phrase = self._ot_phrase(understanding, compliance, p)
            elif key == "social_work":
                phrase = self._social_work_phrase(understanding, compliance, p)
            else:  # medical
                phrase = self._medical_phrase(understanding, compliance, p)

            if phrase:
                sentences.append(phrase)

        return " ".join(sentences)

    def _medical_phrase(self, understanding: str, compliance: str, p: dict) -> str:
        if understanding == "good" and compliance in ("full", "reasonable"):
            return f"{p['subj']} has good understanding of {p['pos']} medical treatment and compliance is {compliance}."
        elif understanding == "good" and compliance == "partial":
            return f"{p['subj']} understands {p['pos']} medical treatment but compliance is partial."
        elif understanding == "fair":
            return f"{p['subj']} has some understanding of {p['pos']} medical treatment and compliance is {compliance}."
        elif understanding == "poor" or compliance == "nil":
            return f"{p['subj']} has limited understanding of {p['pos']} medical treatment and compliance is {compliance}."
        return ""

    def _nursing_phrase(self, understanding: str, compliance: str, p: dict) -> str:
        if understanding == "good" and compliance in ("full", "reasonable"):
            return f"{p['subj']} {p['engages']} well with nursing staff and {p['sees']} the need for nursing input."
        elif understanding == "good" and compliance == "partial":
            return f"{p['subj']} understands the role of nursing but engagement is inconsistent."
        elif understanding == "fair" and compliance in ("full", "reasonable"):
            return f"{p['subj']} has some understanding of nursing care and {p['engages']} reasonably well."
        elif understanding == "fair" and compliance == "partial":
            return f"{p['subj']} has some understanding of nursing input but {p['engages']} only partially."
        elif understanding == "poor" or compliance == "nil":
            return f"{p['subj']} has limited insight into the need for nursing care and {p['does']} not engage meaningfully."
        return ""

    def _psychology_phrase(self, understanding: str, compliance: str, p: dict) -> str:
        if understanding == "good" and compliance in ("full", "reasonable"):
            return f"{p['subj']} {p['engages']} in psychology sessions and sees the benefit of this work."
        elif understanding == "good" and compliance == "partial":
            return f"{p['subj']} understands the purpose of psychology but compliance with sessions is limited."
        elif understanding == "fair" and compliance in ("full", "reasonable"):
            return f"{p['subj']} has some understanding of psychology and attends sessions regularly."
        elif understanding == "fair" and compliance == "partial":
            return f"{p['subj']} {p['engages']} in psychology sessions but the compliance with these is limited."
        elif understanding == "poor" or compliance == "nil":
            return f"{p['subj']} has limited insight into the need for psychology and {p['does']} not engage with sessions."
        return ""

    def _ot_phrase(self, understanding: str, compliance: str, p: dict) -> str:
        if understanding == "good" and compliance in ("full", "reasonable"):
            return f"With respect to OT, {p['subj'].lower()} {p['engages']} well and sees the benefit of activities."
        elif understanding == "good" and compliance == "partial":
            return f"With respect to OT, {p['subj'].lower()} understands the purpose but engagement is inconsistent."
        elif understanding == "fair" and compliance in ("full", "reasonable"):
            return f"{p['subj']} has some understanding of OT and participates in activities."
        elif understanding == "fair" and compliance == "partial":
            return f"{p['subj']} has some understanding of OT but participation is limited."
        elif understanding == "poor" or compliance == "nil":
            return f"{p['subj']} has limited insight into the need for OT and {p['does']} not engage with activities."
        return ""

    def _social_work_phrase(self, understanding: str, compliance: str, p: dict) -> str:
        if understanding == "good" and compliance in ("full", "reasonable"):
            return f"{p['subj']} {p['engages']} with social work and understands the support offered."
        elif understanding == "good" and compliance == "partial":
            return f"{p['subj']} understands social work involvement but engagement is variable."
        elif understanding == "fair" and compliance in ("full", "reasonable"):
            return f"{p['subj']} has some understanding of social work input and {p['engages']} when needed."
        elif understanding == "fair" and compliance == "partial":
            return f"{p['subj']} has some understanding of social work but engagement is limited."
        elif understanding == "poor" or compliance == "nil":
            return f"{p['subj']} has limited insight into social work involvement."
        return ""

    def _apply_section_filter(self, section_key: str, subcategory: str):
        """Filter entries within a section to show only those with the specified subcategory."""
        if section_key not in self._section_filters:
            return

        section_data = self._section_filters[section_key]
        section_data["label"].setText(subcategory)
        section_data["bar"].setVisible(True)

        for entry_frame, entry_subcats in section_data["entries"]:
            if subcategory in entry_subcats:
                entry_frame.setVisible(True)
            else:
                entry_frame.setVisible(False)

    def _clear_section_filter(self, section_key: str):
        """Clear the filter for a specific section and show all its entries."""
        if section_key not in self._section_filters:
            return

        section_data = self._section_filters[section_key]
        section_data["bar"].setVisible(False)

        for entry_frame, entry_subcats in section_data["entries"]:
            entry_frame.setVisible(True)

    def set_notes(self, notes: list):
        """Search notes for non-compliance concerns and populate the section."""
        import re
        from datetime import datetime

        # Clear existing entries and reset section filters
        self._extracted_checkboxes.clear()
        self._all_entry_frames.clear()
        self._current_filter = None
        for section_key in self._section_filters:
            self._section_filters[section_key]["bar"].setVisible(False)
            self._section_filters[section_key]["entries"].clear()
        while self.compliance_checkboxes_layout.count():
            item = self.compliance_checkboxes_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        if not notes:
            self.compliance_section.setVisible(False)
            return

        # Search for non-compliance concerns
        compliance_concerns = []

        def parse_date(date_val):
            if not date_val:
                return None
            if isinstance(date_val, datetime):
                return date_val
            for fmt in ["%Y-%m-%d", "%d/%m/%Y", "%Y-%m-%dT%H:%M:%S", "%d-%m-%Y"]:
                try:
                    return datetime.strptime(str(date_val)[:10], fmt[:min(len(fmt), 10)])
                except:
                    pass
            return None

        for note in notes:
            content = note.get("content", "") or note.get("text", "") or note.get("body", "")
            if not content:
                continue

            content_lower = content.lower()

            # Skip if contains exclusion terms
            if any(ex in content_lower for ex in COMPLIANCE_EXCLUDE_TERMS):
                continue

            # Check for compliance terms
            matched_term = None
            for term in COMPLIANCE_SEARCH_TERMS:
                if term in content_lower:
                    matched_term = term
                    break

            if matched_term:
                note_date = parse_date(note.get("date") or note.get("datetime"))

                # Determine subcategory based on matched term
                if "medication" in matched_term or "meds" in matched_term:
                    subcategory = "Medication Refusal"
                elif "treatment" in matched_term:
                    subcategory = "Treatment Refusal"
                elif "engag" in matched_term:
                    subcategory = "Disengagement"
                elif "covert" in matched_term or "hiding" in matched_term or "cheeking" in matched_term or "spitting" in matched_term or "palming" in matched_term:
                    subcategory = "Covert Administration"
                else:
                    subcategory = "Non-Compliance"

                compliance_concerns.append({
                    "date": note_date,
                    "full_text": content.strip(),
                    "subcategory": subcategory,
                    "severity": "high",
                    "matched": matched_term,
                })

        print(f"[TribunalCompliancePopup] Found {len(compliance_concerns)} non-compliance concerns")

        # Populate section
        self._populate_section(compliance_concerns, self.compliance_checkboxes_layout, self.compliance_section, "Non-Compliance Concerns", "compliance")

    def _populate_section(self, incidents: list, layout: QVBoxLayout, section, category_name: str, section_key: str = ""):
        """Populate a section with concern entries, deduplicated by date."""
        if not incidents:
            section.setVisible(False)
            return

        section.setVisible(True)

        from collections import defaultdict
        from datetime import datetime

        def get_date_key(item):
            dt = item.get("date")
            if dt is None:
                return "no_date"
            if hasattr(dt, "strftime"):
                return dt.strftime("%Y-%m-%d")
            return str(dt)

        # Group by date
        date_groups = defaultdict(list)
        for incident in incidents:
            date_key = get_date_key(incident)
            date_groups[date_key].append(incident)

        # Process each date group to create deduplicated entries
        deduplicated_entries = []
        for date_key, group in date_groups.items():
            subcategories = {}
            texts = []
            matched_terms_all = set()
            representative_date = None

            for inc in group:
                subcat = inc.get("subcategory", "")
                severity = inc.get("severity", "high")
                matched = inc.get("matched", "")
                text = inc.get("full_text", "").strip()
                dt = inc.get("date")

                if representative_date is None:
                    representative_date = dt

                if text:
                    texts.append(text)

                if matched:
                    matched_terms_all.add(matched)

                if subcat:
                    if subcat not in subcategories:
                        subcategories[subcat] = {"severity": severity, "matched_terms": set()}
                    if matched:
                        subcategories[subcat]["matched_terms"].add(matched)

            best_text = ""
            best_score = -1
            for text in texts:
                text_lower = text.lower()
                score = len(text)
                for term in matched_terms_all:
                    if term.lower() in text_lower:
                        score += 100
                if score > best_score:
                    best_score = score
                    best_text = text

            if best_text:
                deduplicated_entries.append({
                    "date": representative_date,
                    "date_key": date_key,
                    "text": best_text,
                    "subcategories": subcategories,
                    "matched_terms": matched_terms_all,
                })

        deduplicated_entries.sort(key=lambda x: x["date_key"], reverse=True)

        # Update section title with deduplicated count
        if deduplicated_entries:
            section.title_label.setText(f"{category_name} ({len(deduplicated_entries)})")

        # Create UI entries
        for entry in deduplicated_entries:
            dt = entry["date"]
            text = entry["text"]
            subcategories = entry["subcategories"]
            matched_terms = entry["matched_terms"]

            if dt:
                if hasattr(dt, "strftime"):
                    date_str = dt.strftime("%d %b %Y")
                else:
                    date_str = str(dt)
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

            # Toggle button first
            toggle_btn = QPushButton("▸")
            toggle_btn.setFixedSize(22, 22)
            toggle_btn.setCursor(Qt.CursorShape.PointingHandCursor)
            toggle_btn.setStyleSheet("""
                QPushButton {
                    background: rgba(180, 150, 50, 0.2);
                    border: none;
                    border-radius: 4px;
                    font-size: 17px;
                    font-weight: bold;
                    color: #806000;
                }
                QPushButton:hover { background: rgba(180, 150, 50, 0.35); }
            """)
            header_row.addWidget(toggle_btn)

            date_label = QLabel(f"📅 {date_str}")
            date_label.setStyleSheet("""
                QLabel {
                    font-size: 17px;
                    font-weight: 600;
                    color: #806000;
                    background: transparent;
                    border: none;
                }
            """)
            date_label.setCursor(Qt.CursorShape.PointingHandCursor)
            header_row.addWidget(date_label)

            header_row.addStretch()

            # Checkbox at the end
            cb = QCheckBox()
            cb.setProperty("full_text", text)
            cb.setFixedSize(18, 18)
            cb.setStyleSheet("""
                QCheckBox { background: transparent; }
                QCheckBox::indicator { width: 16px; height: 16px; }
            """)
            cb.stateChanged.connect(self._send_to_card)
            header_row.addWidget(cb)

            entry_layout.addLayout(header_row)

            # Add subcategory badges - purple colors for compliance
            severity_colors = {"high": "#7b1fa2", "medium": "#9c27b0", "low": "#ba68c8"}
            severity_rank = {"high": 3, "medium": 2, "low": 1}
            sorted_subcats = sorted(
                subcategories.items(),
                key=lambda x: severity_rank.get(x[1]["severity"], 0),
                reverse=True
            )
            entry_subcat_names = list(subcategories.keys())
            if sorted_subcats:
                badges_layout = QVBoxLayout()
                badges_layout.setContentsMargins(30, 0, 0, 4)
                badges_layout.setSpacing(4)
                for subcat_name, subcat_info in sorted_subcats:
                    badge_color = severity_colors.get(subcat_info["severity"], "#7b1fa2")
                    subcat_label = QLabel(f"{subcat_name}")
                    subcat_label.setStyleSheet(f"""
                        QLabel {{
                            font-size: 14px;
                            font-weight: 500;
                            color: white;
                            background: {badge_color};
                            border: none;
                            border-radius: 3px;
                            padding: 2px 6px;
                        }}
                        QLabel:hover {{
                            background: {badge_color};
                            border: 2px solid white;
                        }}
                    """)
                    subcat_label.setSizePolicy(QSizePolicy.Policy.Maximum, QSizePolicy.Policy.Fixed)
                    subcat_label.setCursor(Qt.CursorShape.PointingHandCursor)
                    subcat_label.mousePressEvent = lambda e, name=subcat_name, sk=section_key: self._apply_section_filter(sk, name)
                    badges_layout.addWidget(subcat_label)
                entry_layout.addLayout(badges_layout)

            # Store entry frame with its subcategories for section-specific filtering
            self._all_entry_frames.append((entry_frame, entry_subcat_names))
            if section_key and section_key in self._section_filters:
                self._section_filters[section_key]["entries"].append((entry_frame, entry_subcat_names))

            body_text = QTextEdit()
            body_text.setReadOnly(True)
            body_text.setFrameShape(QFrame.Shape.NoFrame)
            body_text.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            body_text.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            body_text.setStyleSheet("""
                QTextEdit {
                    font-size: 17px;
                    color: #333;
                    background: rgba(255, 248, 220, 0.5);
                    border: none;
                    border-radius: 4px;
                    padding: 6px;
                }
            """)
            body_text.setVisible(False)

            # Highlight all matched terms in the text
            if matched_terms:
                import html
                escaped_text = html.escape(text)
                for term in matched_terms:
                    if term:
                        import re
                        pattern = re.compile(re.escape(html.escape(term)), re.IGNORECASE)
                        escaped_text = pattern.sub(
                            f'<span style="background-color: #ffeb3b; padding: 1px 3px; border-radius: 2px; font-weight: 600;">\\g<0></span>',
                            escaped_text
                        )
                body_text.setHtml(f'<div style="font-size: 17px; color: #333;">{escaped_text}</div>')
            else:
                body_text.setPlainText(text)

            # Calculate height based on content
            doc = body_text.document()
            doc.setTextWidth(body_text.viewport().width() if body_text.viewport().width() > 0 else 400)
            content_height = int(doc.size().height()) + 20
            body_text.setFixedHeight(min(content_height, 200))

            def make_toggle(btn, body):
                def toggle():
                    if body.isVisible():
                        body.setVisible(False)
                        btn.setText("▸")
                    else:
                        body.setVisible(True)
                        btn.setText("▾")
                return toggle

            toggle_btn.clicked.connect(make_toggle(toggle_btn, body_text))
            date_label.mousePressEvent = lambda e, btn=toggle_btn: btn.click()

            entry_layout.addWidget(body_text)
            self._extracted_checkboxes.append(cb)
            layout.addWidget(entry_frame)

    def set_entries(self, items: list, date_info: str = ""):
        """Legacy compatibility method - redirect to set_notes if passed raw notes."""
        if items and isinstance(items, list) and len(items) > 0:
            first_item = items[0]
            if isinstance(first_item, dict) and ('text' in first_item or 'content' in first_item or 'body' in first_item):
                self.set_notes(items)
                return

        all_concerns = []
        for item in items:
            if isinstance(item, dict):
                all_concerns.append({
                    "date": item.get("date"),
                    "full_text": item.get("text", item.get("content", item.get("body", ""))),
                    "subcategory": item.get("subcategory", "Non-Compliance"),
                    "severity": item.get("severity", "high"),
                })
            elif isinstance(item, str):
                all_concerns.append({
                    "date": None,
                    "full_text": item,
                    "subcategory": "Non-Compliance",
                    "severity": "high",
                })

        self._populate_section(all_concerns, self.compliance_checkboxes_layout, self.compliance_section, "Non-Compliance Concerns")


# ================================================================
# TRIBUNAL SECLUSION POPUP (for nursing section 14 - Seclusion/Restraint)
# ================================================================

# Seclusion/Restraint search terms
SECLUSION_SEARCH_TERMS = [
    "seclusion", "secluded", "placed in seclusion", "transferred to seclusion",
    "seclusion room", "seclusion suite", "de-escalation room",
    "restraint", "restrained", "physical restraint", "physical intervention",
    "mechanical restraint", "manual restraint", "held down",
    "rapid tranquilisation", "rapid tranquillisation", "rt given", "rt administered",
    "im medication", "im lorazepam", "im haloperidol", "im olanzapine",
    "prn administered", "prn given for agitation", "prn for aggression",
    "control and restraint", "c&r", "breakaway", "personal safety intervention",
    "psi", "supine restraint", "prone restraint", "standing restraint",
]

SECLUSION_EXCLUDE_TERMS = [
    "no seclusion", "nil seclusion", "not secluded", "no restraint", "nil restraint",
    "not restrained", "no episodes of seclusion", "no episodes of restraint",
    "no use of seclusion", "no use of restraint", "denies seclusion",
    "no rt", "nil rt", "no rapid tranquilisation", "no rapid tranquillisation",
    "seclusion not required", "restraint not required",
]


class TribunalSeclusionPopup(QWidget):
    """Popup for Seclusion/Restraint section with categorized concerns in yellow collapsible entries.

    Features:
    - Preview section at top with Send to Report button
    - Searches notes for seclusion/restraint-related terms
    - Yellow collapsible entries for each concern
    - Clickable labels to filter by subcategory
    - Identical UI to TribunalAWOLPopup
    """

    sent = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        self._entries = []
        self._extracted_checkboxes = []
        self._current_filter = None
        self._all_entry_frames = []
        self._section_filters = {}  # {section_key: {"bar": QFrame, "label": QLabel, "entries": []}}
        self._setup_ui()

    def _setup_ui(self):
        from background_history_popup import ResizableSection, CollapsibleSection

        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        # Main scroll area
        main_scroll = QScrollArea()
        main_scroll.setWidgetResizable(True)
        main_scroll.setFrameShape(QScrollArea.NoFrame)
        main_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        main_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        main_container = QWidget()
        main_layout = QVBoxLayout(main_container)
        main_layout.setContentsMargins(4, 4, 4, 4)
        main_layout.setSpacing(8)

        # ====================================================
        # SECTION 1: SECLUSION/RESTRAINT CONCERNS (collapsible)
        # ====================================================
        # Use purple/violet color scheme for seclusion
        self.seclusion_section = CollapsibleSection("Seclusion / Restraint Concerns", start_collapsed=True)
        self.seclusion_section.set_content_height(350)
        self.seclusion_section._min_height = 100
        self.seclusion_section._max_height = 600
        self.seclusion_section.set_header_style("""
            QFrame {
                background: rgba(128, 0, 128, 0.2);
                border: 1px solid rgba(128, 0, 128, 0.4);
                border-radius: 6px 6px 0 0;
            }
        """)
        self.seclusion_section.set_title_style("""
            QLabel {
                font-size: 18px;
                font-weight: 600;
                color: #6a0dad;
                background: transparent;
                border: none;
            }
        """)

        seclusion_content = QWidget()
        seclusion_content.setStyleSheet("""
            QWidget {
                background: rgba(230, 220, 250, 0.95);
                border: 1px solid rgba(128, 0, 128, 0.4);
                border-top: none;
                border-radius: 0 0 12px 12px;
            }
        """)

        seclusion_layout = QVBoxLayout(seclusion_content)
        seclusion_layout.setContentsMargins(12, 10, 12, 10)
        seclusion_layout.setSpacing(6)

        # Filter bar for seclusion section
        seclusion_filter_bar = QFrame()
        seclusion_filter_bar.setStyleSheet("""
            QFrame {
                background: rgba(128, 0, 128, 0.15);
                border: 1px solid rgba(128, 0, 128, 0.4);
                border-radius: 6px;
            }
        """)
        sfb_layout = QHBoxLayout(seclusion_filter_bar)
        sfb_layout.setContentsMargins(8, 4, 8, 4)
        sfb_layout.setSpacing(6)
        sfb_label = QLabel("Filtered by:")
        sfb_label.setStyleSheet("font-size:15px; color:#333; background:transparent; border:none;")
        sfb_layout.addWidget(sfb_label)
        seclusion_filter_value = QLabel("")
        seclusion_filter_value.setStyleSheet("font-size:14px; font-weight:600; color:white; background:#6a0dad; border:none; border-radius:3px; padding:2px 6px;")
        sfb_layout.addWidget(seclusion_filter_value)
        sfb_layout.addStretch()
        seclusion_clear_btn = QPushButton("✕")
        seclusion_clear_btn.setFixedSize(18, 18)
        seclusion_clear_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        seclusion_clear_btn.setStyleSheet("QPushButton{background:rgba(0,0,0,0.1);color:#333;border:none;border-radius:3px;font-size:15px;font-weight:bold;}QPushButton:hover{background:rgba(0,0,0,0.2);}")
        seclusion_clear_btn.clicked.connect(lambda: self._clear_section_filter("seclusion"))
        sfb_layout.addWidget(seclusion_clear_btn)
        seclusion_filter_bar.setVisible(False)
        seclusion_layout.addWidget(seclusion_filter_bar)
        self._section_filters["seclusion"] = {"bar": seclusion_filter_bar, "label": seclusion_filter_value, "entries": []}

        seclusion_scroll = QScrollArea()
        seclusion_scroll.setWidgetResizable(True)
        seclusion_scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        seclusion_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        seclusion_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        seclusion_scroll.setStyleSheet("""
            QScrollArea { background: transparent; border: none; }
            QScrollArea > QWidget > QWidget { background: transparent; }
        """)

        self.seclusion_container = QWidget()
        self.seclusion_container.setStyleSheet("background: transparent;")
        self.seclusion_checkboxes_layout = QVBoxLayout(self.seclusion_container)
        self.seclusion_checkboxes_layout.setContentsMargins(2, 2, 2, 2)
        self.seclusion_checkboxes_layout.setSpacing(12)
        self.seclusion_checkboxes_layout.setAlignment(Qt.AlignmentFlag.AlignTop)

        seclusion_scroll.setWidget(self.seclusion_container)
        seclusion_layout.addWidget(seclusion_scroll)

        self.seclusion_section.set_content(seclusion_content)
        self.seclusion_section.setVisible(False)
        main_layout.addWidget(self.seclusion_section)

        main_layout.addStretch()
        main_scroll.setWidget(main_container)
        root.addWidget(main_scroll)

    def _send_to_card(self):
        """Generate text and send directly to card."""
        parts = []
        for cb in self._extracted_checkboxes:
            if cb.isChecked():
                parts.append(cb.property("full_text"))

        combined = "\n\n".join(parts) if parts else ""
        if combined:
            self.sent.emit(combined)

    def _apply_section_filter(self, section_key: str, subcategory: str):
        """Filter entries within a section to show only those with the specified subcategory."""
        if section_key not in self._section_filters:
            return

        section_data = self._section_filters[section_key]
        section_data["label"].setText(subcategory)
        section_data["bar"].setVisible(True)

        # Show/hide entries in this section only
        for entry_frame, entry_subcats in section_data["entries"]:
            if subcategory in entry_subcats:
                entry_frame.setVisible(True)
            else:
                entry_frame.setVisible(False)

    def _clear_section_filter(self, section_key: str):
        """Clear the filter for a specific section and show all its entries."""
        if section_key not in self._section_filters:
            return

        section_data = self._section_filters[section_key]
        section_data["bar"].setVisible(False)

        # Show all entries in this section
        for entry_frame, entry_subcats in section_data["entries"]:
            entry_frame.setVisible(True)

    def set_notes(self, notes: list):
        """Search notes for seclusion/restraint incidents and populate the section."""
        import re
        from datetime import datetime

        # Clear existing entries and reset section filters
        self._extracted_checkboxes.clear()
        self._all_entry_frames.clear()
        self._current_filter = None
        for section_key in self._section_filters:
            self._section_filters[section_key]["bar"].setVisible(False)
            self._section_filters[section_key]["entries"].clear()
        while self.seclusion_checkboxes_layout.count():
            item = self.seclusion_checkboxes_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        if not notes:
            self.seclusion_section.setVisible(False)
            return

        # Search for seclusion/restraint incidents
        seclusion_incidents = []

        def parse_date(date_val):
            if not date_val:
                return None
            if isinstance(date_val, datetime):
                return date_val
            for fmt in ["%Y-%m-%d", "%d/%m/%Y", "%Y-%m-%dT%H:%M:%S", "%d-%m-%Y"]:
                try:
                    return datetime.strptime(str(date_val)[:10], fmt[:min(len(fmt), 10)])
                except:
                    pass
            return None

        for note in notes:
            content = note.get("content", "") or note.get("text", "") or note.get("body", "")
            if not content:
                continue

            content_lower = content.lower()

            # Skip if contains exclusion terms
            if any(ex in content_lower for ex in SECLUSION_EXCLUDE_TERMS):
                continue

            # Check for seclusion/restraint terms
            matched_term = None
            for term in SECLUSION_SEARCH_TERMS:
                if term in content_lower:
                    matched_term = term
                    break

            if matched_term:
                note_date = parse_date(note.get("date") or note.get("datetime"))

                # Determine subcategory based on matched term
                if matched_term in ["seclusion", "secluded", "placed in seclusion", "transferred to seclusion", "seclusion room", "seclusion suite", "de-escalation room"]:
                    subcategory = "Seclusion"
                elif matched_term in ["rapid tranquilisation", "rapid tranquillisation", "rt given", "rt administered", "im medication", "im lorazepam", "im haloperidol", "im olanzapine", "prn administered", "prn given for agitation", "prn for aggression"]:
                    subcategory = "Rapid Tranquilisation"
                elif matched_term in ["mechanical restraint"]:
                    subcategory = "Mechanical Restraint"
                elif matched_term in ["restraint", "restrained", "physical restraint", "physical intervention", "manual restraint", "held down", "control and restraint", "c&r", "breakaway", "personal safety intervention", "psi", "supine restraint", "prone restraint", "standing restraint"]:
                    subcategory = "Physical Restraint"
                else:
                    subcategory = "Seclusion"

                seclusion_incidents.append({
                    "date": note_date,
                    "full_text": content.strip(),
                    "subcategory": subcategory,
                    "severity": "high",  # Seclusion/restraint is always high severity
                    "matched": matched_term,
                })

        print(f"[TribunalSeclusionPopup] Found {len(seclusion_incidents)} seclusion/restraint concerns")

        # Populate section
        self._populate_section(seclusion_incidents, self.seclusion_checkboxes_layout, self.seclusion_section, "Seclusion / Restraint Concerns", "seclusion")

    def _populate_section(self, incidents: list, layout: QVBoxLayout, section, category_name: str, section_key: str = ""):
        """Populate a section with incident entries, deduplicated by date."""
        if not incidents:
            section.setVisible(False)
            return

        section.setVisible(True)

        from collections import defaultdict
        from datetime import datetime

        def get_date_key(item):
            dt = item.get("date")
            if dt is None:
                return "no_date"
            if hasattr(dt, "strftime"):
                return dt.strftime("%Y-%m-%d")
            return str(dt)

        # Group by date
        date_groups = defaultdict(list)
        for incident in incidents:
            date_key = get_date_key(incident)
            date_groups[date_key].append(incident)

        # Process each date group to create deduplicated entries
        deduplicated_entries = []
        for date_key, group in date_groups.items():
            subcategories = {}
            texts = []
            matched_terms_all = set()
            representative_date = None

            for inc in group:
                subcat = inc.get("subcategory", "")
                severity = inc.get("severity", "high")
                matched = inc.get("matched", "")
                text = inc.get("full_text", "").strip()
                dt = inc.get("date")

                if representative_date is None:
                    representative_date = dt

                if text:
                    texts.append(text)

                if matched:
                    matched_terms_all.add(matched)

                if subcat:
                    if subcat not in subcategories:
                        subcategories[subcat] = {"severity": severity, "matched_terms": set()}
                    if matched:
                        subcategories[subcat]["matched_terms"].add(matched)

            best_text = ""
            best_score = -1
            for text in texts:
                text_lower = text.lower()
                score = len(text)
                for term in matched_terms_all:
                    if term.lower() in text_lower:
                        score += 100
                if score > best_score:
                    best_score = score
                    best_text = text

            if best_text:
                deduplicated_entries.append({
                    "date": representative_date,
                    "date_key": date_key,
                    "text": best_text,
                    "subcategories": subcategories,
                    "matched_terms": matched_terms_all,
                })

        deduplicated_entries.sort(key=lambda x: x["date_key"], reverse=True)

        # Update section title with deduplicated count
        if deduplicated_entries:
            section.title_label.setText(f"{category_name} ({len(deduplicated_entries)})")

        # Create UI entries
        for entry in deduplicated_entries:
            dt = entry["date"]
            text = entry["text"]
            subcategories = entry["subcategories"]
            matched_terms = entry["matched_terms"]

            if dt:
                if hasattr(dt, "strftime"):
                    date_str = dt.strftime("%d %b %Y")
                else:
                    date_str = str(dt)
            else:
                date_str = "No date"

            entry_frame = QFrame()
            entry_frame.setObjectName("entryFrame")
            entry_frame.setSizePolicy(QSizePolicy.Policy.Preferred, QSizePolicy.Policy.Minimum)
            entry_frame.setStyleSheet("""
                QFrame#entryFrame {
                    background: rgba(255, 255, 255, 0.95);
                    border: 1px solid rgba(128, 0, 128, 0.4);
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

            # Toggle button first
            toggle_btn = QPushButton("▸")
            toggle_btn.setFixedSize(22, 22)
            toggle_btn.setCursor(Qt.CursorShape.PointingHandCursor)
            toggle_btn.setStyleSheet("""
                QPushButton {
                    background: rgba(128, 0, 128, 0.2);
                    border: none;
                    border-radius: 4px;
                    font-size: 17px;
                    font-weight: bold;
                    color: #6a0dad;
                }
                QPushButton:hover { background: rgba(128, 0, 128, 0.35); }
            """)
            header_row.addWidget(toggle_btn)

            date_label = QLabel(f"📅 {date_str}")
            date_label.setStyleSheet("""
                QLabel {
                    font-size: 17px;
                    font-weight: 600;
                    color: #6a0dad;
                    background: transparent;
                    border: none;
                }
            """)
            date_label.setCursor(Qt.CursorShape.PointingHandCursor)
            header_row.addWidget(date_label)

            header_row.addStretch()

            # Checkbox at the end
            cb = QCheckBox()
            cb.setProperty("full_text", text)
            cb.setFixedSize(18, 18)
            cb.setStyleSheet("""
                QCheckBox { background: transparent; }
                QCheckBox::indicator { width: 16px; height: 16px; }
            """)
            cb.stateChanged.connect(self._send_to_card)
            header_row.addWidget(cb)

            entry_layout.addLayout(header_row)

            # Add subcategory badges stacked vertically (clickable for filtering)
            # Seclusion uses purple colors
            severity_colors = {"high": "#6a0dad", "medium": "#9b59b6", "low": "#bb8fce"}
            severity_rank = {"high": 3, "medium": 2, "low": 1}
            sorted_subcats = sorted(
                subcategories.items(),
                key=lambda x: severity_rank.get(x[1]["severity"], 0),
                reverse=True
            )
            entry_subcat_names = list(subcategories.keys())
            if sorted_subcats:
                badges_layout = QVBoxLayout()
                badges_layout.setContentsMargins(30, 0, 0, 4)
                badges_layout.setSpacing(4)
                for subcat_name, subcat_info in sorted_subcats:
                    badge_color = severity_colors.get(subcat_info["severity"], "#6a0dad")
                    subcat_label = QLabel(f"{subcat_name}")
                    subcat_label.setStyleSheet(f"""
                        QLabel {{
                            font-size: 14px;
                            font-weight: 500;
                            color: white;
                            background: {badge_color};
                            border: none;
                            border-radius: 3px;
                            padding: 2px 6px;
                        }}
                        QLabel:hover {{
                            background: {badge_color};
                            border: 2px solid white;
                        }}
                    """)
                    subcat_label.setSizePolicy(QSizePolicy.Policy.Maximum, QSizePolicy.Policy.Fixed)
                    subcat_label.setCursor(Qt.CursorShape.PointingHandCursor)
                    # Make label clickable for filtering (section-specific)
                    subcat_label.mousePressEvent = lambda e, name=subcat_name, sk=section_key: self._apply_section_filter(sk, name)
                    badges_layout.addWidget(subcat_label)
                entry_layout.addLayout(badges_layout)

            # Store entry frame with its subcategories for section-specific filtering
            self._all_entry_frames.append((entry_frame, entry_subcat_names))
            if section_key and section_key in self._section_filters:
                self._section_filters[section_key]["entries"].append((entry_frame, entry_subcat_names))

            body_text = QTextEdit()
            body_text.setReadOnly(True)
            body_text.setFrameShape(QFrame.Shape.NoFrame)
            body_text.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            body_text.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
            body_text.setStyleSheet("""
                QTextEdit {
                    font-size: 17px;
                    color: #333;
                    background: rgba(230, 220, 250, 0.5);
                    border: none;
                    border-radius: 4px;
                    padding: 6px;
                }
            """)
            body_text.setVisible(False)

            # Highlight all matched terms in the text
            if matched_terms:
                import html
                escaped_text = html.escape(text)
                for term in matched_terms:
                    if term:
                        import re
                        pattern = re.compile(re.escape(html.escape(term)), re.IGNORECASE)
                        escaped_text = pattern.sub(
                            f'<span style="background-color: #e1bee7; padding: 1px 3px; border-radius: 2px; font-weight: 600;">\\g<0></span>',
                            escaped_text
                        )
                body_text.setHtml(f'<div style="font-size: 17px; color: #333;">{escaped_text}</div>')
            else:
                body_text.setPlainText(text)

            # Calculate height based on content
            doc = body_text.document()
            doc.setTextWidth(body_text.viewport().width() if body_text.viewport().width() > 0 else 400)
            content_height = int(doc.size().height()) + 20
            body_text.setFixedHeight(min(content_height, 200))

            def make_toggle(btn, body):
                def toggle():
                    if body.isVisible():
                        body.setVisible(False)
                        btn.setText("▸")
                    else:
                        body.setVisible(True)
                        btn.setText("▾")
                return toggle

            toggle_btn.clicked.connect(make_toggle(toggle_btn, body_text))
            date_label.mousePressEvent = lambda e, btn=toggle_btn: btn.click()

            entry_layout.addWidget(body_text)
            self._extracted_checkboxes.append(cb)
            layout.addWidget(entry_frame)

    def set_entries(self, items: list, date_info: str = ""):
        """Legacy compatibility method - redirect to set_notes if passed raw notes."""
        if items and isinstance(items, list) and len(items) > 0:
            first_item = items[0]
            if isinstance(first_item, dict) and ('text' in first_item or 'content' in first_item or 'body' in first_item):
                self.set_notes(items)
                return

        all_concerns = []
        for item in items:
            if isinstance(item, dict):
                all_concerns.append({
                    "date": item.get("date"),
                    "full_text": item.get("text", item.get("content", item.get("body", ""))),
                    "subcategory": item.get("subcategory", "Seclusion"),
                    "severity": item.get("severity", "high"),
                })
            elif isinstance(item, str):
                all_concerns.append({
                    "date": None,
                    "full_text": item,
                    "subcategory": "Seclusion",
                    "severity": "high",
                })

        self._populate_section(all_concerns, self.seclusion_checkboxes_layout, self.seclusion_section, "Seclusion / Restraint Concerns")
