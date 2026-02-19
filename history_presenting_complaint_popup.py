# =====================================================================
# HISTORY OF PRESENTING COMPLAINT POPUP — RESTRUCTURED VERSION
# Features:
# • Fixed preview at top
# • Fixed onset/triggers section (slider for onset, optional dates)
# • Scrollable collapsed sections for rest
# • Imports data from Presenting Complaint
# =====================================================================

from __future__ import annotations

from PySide6.QtCore import Qt, QSize, Signal
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QGridLayout, QLabel, QPushButton,
    QScrollArea, QCheckBox, QComboBox, QTextEdit, QDateEdit,
    QLineEdit, QSizePolicy, QSlider, QRadioButton, QButtonGroup
)
from shared_widgets import add_lock_to_popup
from spell_check_textedit import enable_spell_check_on_textedit


# =====================================================================
# PRONOUN ENGINE
# =====================================================================
def pronouns_from_gender(g: str):
    g = (g or "").strip().lower()
    if g.startswith("m"):
        sub, obj, poss, plural = "He", "him", "his", False
    elif g.startswith("f"):
        sub, obj, poss, plural = "She", "her", "her", False
    else:
        sub, obj, poss, plural = "They", "them", "their", True

    def verb(base: str):
        return base if plural else base + "s"

    return sub, obj, poss, verb


# =====================================================================
# COLLAPSIBLE SECTION
# =====================================================================
class Collapsible(QWidget):
    def __init__(self, title: str, widget: QWidget = None):
        super().__init__()
        self.expanded = False
        self.widget = widget

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 4, 0, 4)
        layout.setSpacing(4)

        self.lbl = QLabel(f"▶ {title}")
        self.lbl.setWordWrap(True)
        self.lbl.setStyleSheet("font-weight:600; font-size:21px; color:#003c32; padding:2px 0;")
        layout.addWidget(self.lbl)

        self.body = QWidget()
        body_layout = QVBoxLayout(self.body)
        body_layout.setContentsMargins(12, 4, 0, 6)
        body_layout.setSpacing(4)

        if widget:
            body_layout.addWidget(widget)

        layout.addWidget(self.body)
        self.body.hide()
        self.lbl.mousePressEvent = self.toggle

    def toggle(self, event):
        self.expanded = not self.expanded
        if self.expanded:
            self.lbl.setText(self.lbl.text().replace("▶", "▼"))
            self.body.show()
        else:
            self.lbl.setText(self.lbl.text().replace("▼", "▶"))
            self.body.hide()


# =====================================================================
# CHIP BUTTON
# =====================================================================
class ChipButton(QPushButton):
    def __init__(self, text):
        super().__init__(text)
        self.setCheckable(True)
        self.setStyleSheet("""
            QPushButton {
                background: rgba(0,0,0,0.08);
                border-radius: 8px;
                padding: 4px 10px;
                font-size: 21px;
            }
            QPushButton:checked {
                background: #008C7E;
                color: white;
            }
        """)


# =====================================================================
# CHIP GROUP
# =====================================================================
class ChipGroup(QWidget):
    def __init__(self, items, vertical=False, cols=3):
        super().__init__()
        if vertical:
            layout = QVBoxLayout(self)
        else:
            # Use grid layout for wrapping
            layout = QGridLayout(self)
        layout.setSpacing(4)
        layout.setContentsMargins(0, 0, 0, 0)

        self.buttons = []
        for i, t in enumerate(items):
            b = ChipButton(t)
            self.buttons.append(b)
            if vertical:
                layout.addWidget(b)
            else:
                row = i // cols
                col = i % cols
                layout.addWidget(b, row, col)

    def get_selected(self):
        return [b.text() for b in self.buttons if b.isChecked()]

    def set_selected(self, values):
        for b in self.buttons:
            b.setChecked(b.text() in values)


# =====================================================================
# CHECKBOX GROUP
# =====================================================================
class CheckboxGroup(QWidget):
    def __init__(self, items):
        super().__init__()
        layout = QVBoxLayout(self)
        layout.setSpacing(2)
        layout.setContentsMargins(0, 0, 0, 0)

        self.checks = []
        for t in items:
            cb = QCheckBox(t)
            cb.setStyleSheet("font-size:22px;")
            self.checks.append(cb)
            layout.addWidget(cb)

    def get_selected(self):
        return [c.text() for c in self.checks if c.isChecked()]

    def set_selected(self, values):
        for c in self.checks:
            c.setChecked(c.text() in values)


# =====================================================================
# RADIO GROUP (single selection)
# =====================================================================
class RadioGroup(QWidget):
    def __init__(self, items):
        super().__init__()
        layout = QVBoxLayout(self)
        layout.setSpacing(2)
        layout.setContentsMargins(0, 0, 0, 0)

        self.button_group = QButtonGroup(self)
        self.radios = []
        for t in items:
            rb = QRadioButton(t)
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
            self.radios.append(rb)
            self.button_group.addButton(rb)
            layout.addWidget(rb)

    def get_selected(self):
        """Return list with single selected item (for compatibility with CheckboxGroup interface)."""
        for r in self.radios:
            if r.isChecked():
                return [r.text()]
        return []

    def set_selected(self, values):
        """Set selected item. values should be a list with one item."""
        for r in self.radios:
            r.setChecked(r.text() in values)


# =====================================================================
# LABELED INPUTS
# =====================================================================
class LabeledLineEdit(QWidget):
    def __init__(self, label):
        super().__init__()
        l = QVBoxLayout(self)
        l.setSpacing(2)
        l.setContentsMargins(0, 0, 0, 0)

        self.lbl = QLabel(label)
        self.lbl.setStyleSheet("font-size:21px; font-weight:600; color:#003c32;")
        self.edit = QLineEdit()
        self.edit.setStyleSheet("padding:4px; font-size:21px; border: 1px solid #ccc; border-radius: 4px;")

        l.addWidget(self.lbl)
        l.addWidget(self.edit)

    def text(self):
        return self.edit.text().strip()

    def set_text(self, t):
        self.edit.setText(t or "")


class LabeledDateEdit(QWidget):
    def __init__(self, label):
        super().__init__()
        from PySide6.QtCore import QDate

        l = QHBoxLayout(self)
        l.setSpacing(8)
        l.setContentsMargins(0, 0, 0, 0)

        self.lbl = QLabel(label)
        self.lbl.setStyleSheet("font-size:21px; font-weight:600; color:#003c32;")
        self.lbl.setFixedWidth(100)

        self.edit = QDateEdit()
        self.edit.setCalendarPopup(True)
        self.edit.setStyleSheet("padding:4px; font-size:21px; border: 1px solid #ccc; border-radius: 4px;")
        self.edit.setDate(QDate.currentDate())  # Start on today's date
        self.edit.setMaximumDate(QDate.currentDate())  # No future dates
        self._style_calendar(self.edit)

        # Checkbox to enable/disable
        self.enabled_cb = QCheckBox()
        self.enabled_cb.setStyleSheet("margin-right: 4px;")
        self.enabled_cb.stateChanged.connect(self._toggle_enabled)
        self.edit.setEnabled(False)

        l.addWidget(self.enabled_cb)
        l.addWidget(self.lbl)
        l.addWidget(self.edit, 1)

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
                font-size: 21px;
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

    def _toggle_enabled(self, state):
        self.edit.setEnabled(state == Qt.CheckState.Checked.value)

    def date(self):
        if not self.enabled_cb.isChecked():
            return None
        try:
            return self.edit.date().toPython()
        except Exception:
            return None

    def set_date(self, dt):
        if dt:
            from datetime import date, datetime
            if isinstance(dt, (date, datetime)):
                self.enabled_cb.setChecked(True)
                self.edit.setDate(dt)
        else:
            self.enabled_cb.setChecked(False)

    def is_enabled(self):
        return self.enabled_cb.isChecked()


class LabeledTextEdit(QWidget):
    def __init__(self, label, height=60):
        super().__init__()
        from PySide6.QtWidgets import QFrame
        from PySide6.QtCore import QEvent

        self._min_height = 40
        self._max_height = 300
        self._current_height = height
        self._dragging = False
        self._drag_start_y = 0
        self._drag_start_height = 0

        l = QVBoxLayout(self)
        l.setSpacing(2)
        l.setContentsMargins(0, 0, 0, 0)

        self.lbl = QLabel(label)
        self.lbl.setStyleSheet("font-size:21px; font-weight:600; color:#003c32;")
        self.edit = QTextEdit()
        self.edit.setMinimumHeight(height)
        self.edit.setMaximumHeight(height)
        # Use native Qt frame for Windows compatibility
        self.edit.setFrameShape(QFrame.Shape.StyledPanel)
        self.edit.setFrameShadow(QFrame.Shadow.Sunken)
        self.edit.setStyleSheet("""
            QTextEdit {
                padding: 4px;
                font-size: 21px;
                background-color: white;
                border: 1px solid #888888;
            }
        """)
        enable_spell_check_on_textedit(self.edit)

        l.addWidget(self.lbl)
        l.addWidget(self.edit)

        # Drag bar for resizing
        self.drag_bar = QFrame()
        self.drag_bar.setFixedHeight(8)
        self.drag_bar.setCursor(Qt.CursorShape.SizeVerCursor)
        self.drag_bar.setStyleSheet("""
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
        self.drag_bar.installEventFilter(self)
        l.addWidget(self.drag_bar)

    def eventFilter(self, obj, event):
        from PySide6.QtCore import QEvent
        if obj == self.drag_bar:
            if event.type() == QEvent.Type.MouseButtonPress:
                self._dragging = True
                self._drag_start_y = event.globalPosition().y()
                self._drag_start_height = self._current_height
                return True
            elif event.type() == QEvent.Type.MouseMove and self._dragging:
                delta = event.globalPosition().y() - self._drag_start_y
                new_height = max(self._min_height, min(self._max_height, int(self._drag_start_height + delta)))
                self._current_height = new_height
                self.edit.setMinimumHeight(new_height)
                self.edit.setMaximumHeight(new_height)
                return True
            elif event.type() == QEvent.Type.MouseButtonRelease:
                self._dragging = False
                return True
        return super().eventFilter(obj, event)

    def text(self):
        return self.edit.toPlainText().strip()

    def set_text(self, t):
        self.edit.setPlainText(t or "")


# =====================================================================
# MINI TIMELINE BUILDER
# =====================================================================
class MiniAddList(QWidget):
    def __init__(self):
        super().__init__()
        layout = QVBoxLayout(self)
        layout.setSpacing(4)
        layout.setContentsMargins(0, 0, 0, 0)

        self.events = []

        add_btn = QPushButton("+ Add timeline event")
        add_btn.setStyleSheet("""
            QPushButton { background: #e0e0e0; border-radius: 6px; padding: 4px 6px; font-size: 21px; }
            QPushButton:hover { background: #d0d0d0; }
        """)
        add_btn.clicked.connect(self.add_event)
        layout.addWidget(add_btn)

        self.list_layout = QVBoxLayout()
        self.list_layout.setSpacing(4)
        layout.addLayout(self.list_layout)

    def add_event(self, label_text="", desc_text=""):
        row = QWidget()
        r = QVBoxLayout(row)
        r.setSpacing(4)
        r.setContentsMargins(0, 0, 0, 8)

        top_row = QHBoxLayout()
        label_edit = QLineEdit()
        label_edit.setPlaceholderText("Timepoint (e.g. 'Week 1')")
        label_edit.setStyleSheet("font-size:21px; padding:3px; border: 1px solid #ccc; border-radius: 4px;")
        label_edit.setText(label_text if isinstance(label_text, str) else "")

        remove_btn = QPushButton("×")
        remove_btn.setFixedSize(22, 22)
        remove_btn.clicked.connect(lambda: self.remove_event(row))

        top_row.addWidget(label_edit)
        top_row.addWidget(remove_btn)
        r.addLayout(top_row)

        text_edit = QLineEdit()
        text_edit.setPlaceholderText("Description")
        text_edit.setStyleSheet("font-size:21px; padding:3px; border: 1px solid #ccc; border-radius: 4px;")
        text_edit.setText(desc_text if isinstance(desc_text, str) else "")
        r.addWidget(text_edit)

        self.events.append((label_edit, text_edit))
        self.list_layout.addWidget(row)

    def remove_event(self, row):
        widgets = row.findChildren(QLineEdit)
        if len(widgets) >= 2:
            label_edit, text_edit = widgets[0], widgets[1]
            self.events = [e for e in self.events if e[0] is not label_edit]
        row.setParent(None)

    def get_events(self):
        out = []
        for label_edit, text_edit in self.events:
            l = label_edit.text().strip()
            t = text_edit.text().strip()
            if l or t:
                out.append((l, t))
        return out

    def load_events(self, events):
        for label_edit, text_edit in list(self.events):
            label_edit.parent().setParent(None)
        self.events.clear()
        for item in events or []:
            if isinstance(item, (list, tuple)) and len(item) >= 2:
                self.add_event(item[0], item[1])


# =====================================================================
# ONSET OPTIONS
# =====================================================================
ONSET_OPTIONS = ["", "Gradual", "Slow", "Over months", "Sudden", "Unclear"]


# =====================================================================
# HISTORY OF PRESENTING COMPLAINT POPUP
# =====================================================================
class HistoryPresentingComplaintPopup(QWidget):
    sent = Signal(str)
    closed = Signal(dict)

    def update_gender(self, gender: str):
        self.gender = gender
        self.update_preview()

    def _setup_risk_checkbox_behavior(self):
        """Set up mutual exclusivity between 'None reported' and other risk checkboxes."""
        none_checkbox = None
        other_checkboxes = []

        for cb in self.risk_categories.checks:
            if cb.text() == "None reported":
                none_checkbox = cb
            else:
                other_checkboxes.append(cb)

        if none_checkbox is None:
            return

        def on_none_changed(state):
            if state == 2:  # Checked
                # Uncheck and disable all other checkboxes
                for cb in other_checkboxes:
                    cb.setChecked(False)
                    cb.setEnabled(False)
                    cb.setStyleSheet("font-size:22px; color: #999999;")
            else:
                # Re-enable all other checkboxes
                for cb in other_checkboxes:
                    cb.setEnabled(True)
                    cb.setStyleSheet("font-size:22px;")

        def on_other_changed(state):
            if state == 2:  # Checked
                # Uncheck "None reported"
                none_checkbox.setChecked(False)

        none_checkbox.stateChanged.connect(on_none_changed)
        for cb in other_checkboxes:
            cb.stateChanged.connect(on_other_changed)

    def __init__(self, gender: str, parent=None):
        super().__init__(parent)
        self.gender = gender
        self.saved_data = {}
        self._signals_connected = False
        self._pc_data = None  # Store presenting complaint data

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
        # SECTION 1: ONSET & TRIGGERS (fixed, always visible)
        # ========================================================
        onset_container = QWidget()
        onset_container.setObjectName("onsetContainer")
        onset_container.setStyleSheet("""
            #onsetContainer { background: rgba(255,255,255,0.92); border-radius: 12px; }
            QLabel, QCheckBox, QRadioButton { background: transparent; }
        """)

        onset_layout = QVBoxLayout(onset_container)
        onset_layout.setContentsMargins(12, 10, 12, 10)
        onset_layout.setSpacing(10)

        # Onset slider row
        onset_row = QHBoxLayout()
        onset_label = QLabel("Onset:")
        onset_label.setStyleSheet("font-weight:600; font-size:19px; color:#003c32;")
        onset_label.setFixedWidth(48)

        self.onset_combo = QComboBox()
        self.onset_combo.addItems(ONSET_OPTIONS)
        self.onset_combo.setCurrentIndex(0)
        self.onset_combo.setStyleSheet("padding:4px; font-size:21px; background: #f3f4f6;")

        onset_row.addWidget(onset_label)
        onset_row.addWidget(self.onset_combo, 1)
        onset_layout.addLayout(onset_row)

        # Triggers
        trigger_label = QLabel("Triggers:")
        trigger_label.setStyleSheet("font-weight:600; font-size:21px; color:#003c32;")
        onset_layout.addWidget(trigger_label)

        self.trigger_group = ChipGroup([
            "Stress", "Work", "Relationship",
            "Health", "Medication", "Substance"
        ])
        onset_layout.addWidget(self.trigger_group)

        self.other_trigger = QLineEdit()
        self.other_trigger.setPlaceholderText("Other trigger (optional)")
        self.other_trigger.setStyleSheet("padding:4px; font-size:21px; border: 1px solid #ccc; border-radius: 4px;")
        onset_layout.addWidget(self.other_trigger)

        # Optional dates
        self.date_first_noticed = LabeledDateEdit("1st noted")
        self.date_became_severe = LabeledDateEdit("Severe")
        onset_layout.addWidget(self.date_first_noticed)
        onset_layout.addWidget(self.date_became_severe)

        # When first noticed changes, update became severe to match
        def sync_became_severe(qdate):
            self.date_became_severe.edit.setDate(qdate)
        self.date_first_noticed.edit.dateChanged.connect(sync_became_severe)

        root.addWidget(onset_container)

        # ========================================================
        # SECTION 3: SCROLLABLE COLLAPSED SECTIONS
        # ========================================================
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        sections_container = QWidget()
        sections_container.setObjectName("sectionsContainer")
        sections_container.setStyleSheet("""
            #sectionsContainer { background: rgba(255,255,255,0.92); border-radius: 12px; }
            QCheckBox, QLabel, QRadioButton { background: transparent; }
        """)

        sections_layout = QVBoxLayout(sections_container)
        sections_layout.setContentsMargins(12, 10, 12, 10)
        sections_layout.setSpacing(6)

        # ----- SECTION A: COURSE OF ILLNESS -----
        self.course_group = RadioGroup([
            "Getting worse", "Improving", "Fluctuating",
            "Relapsing–remitting", "Chronic / unchanged"
        ])
        self.episode_number = LabeledLineEdit("Episode number (optional)")
        self.course_description = LabeledTextEdit("Describe pattern (optional)", height=60)
        self.timeline_events = MiniAddList()

        sectionA = QWidget()
        sA = QVBoxLayout(sectionA)
        sA.setContentsMargins(0, 0, 0, 0)
        sA.setSpacing(8)
        sA.addWidget(QLabel("Course pattern:"))
        sA.addWidget(self.course_group)
        sA.addWidget(self.episode_number)
        sA.addWidget(self.course_description)
        sA.addWidget(QLabel("Timeline events:"))
        sA.addWidget(self.timeline_events)

        self.section_course = Collapsible("Course of Illness", sectionA)
        sections_layout.addWidget(self.section_course)

        # ----- SECTION B: RISKS -----
        self.risk_categories = CheckboxGroup([
            "Suicidal thoughts", "Self-harm", "Harm to others",
            "Neglect", "Vulnerability", "None reported"
        ])
        # Connect risk checkboxes for mutual exclusivity with "None reported"
        self._setup_risk_checkbox_behavior()

        self.risk_frequency = LabeledLineEdit("Frequency")
        self.risk_intensity = LabeledLineEdit("Intensity")
        self.risk_intent = LabeledLineEdit("Intent or planning")
        self.risk_means = LabeledLineEdit("Access to means")
        self.risk_incidents = LabeledTextEdit("Recent concerns", height=50)
        self.risk_protective = LabeledTextEdit("Protective factors", height=50)

        sectionB = QWidget()
        sB = QVBoxLayout(sectionB)
        sB.setContentsMargins(0, 0, 0, 0)
        sB.setSpacing(8)
        sB.addWidget(QLabel("Risk categories:"))
        sB.addWidget(self.risk_categories)
        sB.addWidget(self.risk_frequency)
        sB.addWidget(self.risk_intensity)
        sB.addWidget(self.risk_intent)
        sB.addWidget(self.risk_means)
        sB.addWidget(self.risk_incidents)
        sB.addWidget(self.risk_protective)

        self.section_risks = Collapsible("Risks", sectionB)
        sections_layout.addWidget(self.section_risks)

        # ----- SECTION C: PAST EPISODES -----
        self.past_flags = CheckboxGroup([
            "Previous similar episodes", "Previous admissions",
            "Crisis team involvement", "Past self-harm/suicide attempts",
            "Past violence/aggression"
        ])
        self.past_treatment = LabeledTextEdit("Previous treatment & response", height=60)

        sectionC = QWidget()
        sC = QVBoxLayout(sectionC)
        sC.setContentsMargins(0, 0, 0, 0)
        sC.setSpacing(8)
        hist_label = QLabel("Historical features:")
        hist_label.setStyleSheet("font-size: 22px;")
        sC.addWidget(hist_label)
        sC.addWidget(self.past_flags)
        sC.addWidget(self.past_treatment)

        self.section_past = Collapsible("Past Episodes", sectionC)
        sections_layout.addWidget(self.section_past)

        # ----- SECTION D: EXPLANATORY MODEL -----
        self.model_chips = ChipGroup([
            "Stress", "Chemical", "Trauma",
            "Physical", "Social", "Uncertain"
        ])
        self.model_notes = LabeledTextEdit("Patient's explanation (optional)", height=50)

        sectionD = QWidget()
        sD = QVBoxLayout(sectionD)
        sD.setContentsMargins(0, 0, 0, 0)
        sD.setSpacing(8)
        understanding_label = QLabel("Patient's understanding:")
        understanding_label.setStyleSheet("font-size: 22px;")
        sD.addWidget(understanding_label)
        sD.addWidget(self.model_chips)
        sD.addWidget(self.model_notes)

        self.section_model = Collapsible("Explanatory Model", sectionD)
        sections_layout.addWidget(self.section_model)

        # ----- SECTION E: COLLATERAL -----
        self.collateral_type = RadioGroup([
            "Present", "Telephone", "None obtained"
        ])
        self.collateral_concerns = LabeledTextEdit("Carer concerns", height=50)

        sectionE = QWidget()
        sE = QVBoxLayout(sectionE)
        sE.setContentsMargins(0, 0, 0, 0)
        sE.setSpacing(8)
        collateral_label = QLabel("Collateral:")
        collateral_label.setStyleSheet("font-size: 22px;")
        sE.addWidget(collateral_label)
        sE.addWidget(self.collateral_type)
        sE.addWidget(self.collateral_concerns)

        self.section_collateral = Collapsible("Collateral Information", sectionE)
        sections_layout.addWidget(self.section_collateral)

        sections_layout.addStretch()

        scroll.setWidget(sections_container)
        root.addWidget(scroll, 1)

        add_lock_to_popup(self, show_button=False)

    # =====================================================================
    # SHOW EVENT - CONNECT SIGNALS
    # =====================================================================
    def showEvent(self, event):
        super().showEvent(event)
        if not self._signals_connected:
            # Connect all inputs to preview update
            for w in self.findChildren(QCheckBox):
                w.stateChanged.connect(self.update_preview)
            for w in self.findChildren(QLineEdit):
                w.textChanged.connect(self.update_preview)
            for w in self.findChildren(QTextEdit):
                w.textChanged.connect(self.update_preview)
            for w in self.findChildren(QDateEdit):
                w.dateChanged.connect(self.update_preview)
            for w in self.findChildren(QComboBox):
                w.currentIndexChanged.connect(self.update_preview)
            for w in self.findChildren(QPushButton):
                if w.isCheckable():
                    w.toggled.connect(self.update_preview)
            self._signals_connected = True

        self.update_preview()

    # =====================================================================
    # IMPORT FROM PRESENTING COMPLAINT
    # =====================================================================
    def import_from_pc(self, pc_data: dict):
        """Import data from Presenting Complaint popup."""
        if not pc_data:
            return

        self._pc_data = pc_data
        self.update_preview()

    # =====================================================================
    # PREVIEW BUILDERS
    # =====================================================================
    def preview_onset(self):
        sub, obj, poss, verb = pronouns_from_gender(self.gender)
        parts = []

        onset = self.onset_combo.currentText()
        if onset:
            onset_phrases = {
                "Over months": f"{sub} described an onset over several months.",
                "Gradual": f"{sub} described a gradual onset of symptoms.",
                "Slow": f"{poss.capitalize()} symptoms started slowly.",
                "Sudden": f"{sub} said the symptoms commenced suddenly.",
                "Unclear": f"{sub} was not clear about the onset of {poss} symptoms.",
            }
            if onset in onset_phrases:
                parts.append(onset_phrases[onset])

        triggers = self.trigger_group.get_selected()
        trigger_expand = {
            "Stress": "stress-related factors",
            "Work": "work issues",
            "Relationship": "relationship difficulties",
            "Health": "physical health decline",
            "Medication": "medication changes",
            "Substance": "substance use changes"
        }
        if triggers:
            expanded = [trigger_expand.get(t, t.lower()) for t in triggers]
            parts.append(f"Triggers appear to include {', '.join(expanded)}.")

        other = self.other_trigger.text().strip()
        if other:
            parts.append(f"Additional trigger reported: {other}.")

        d1 = self.date_first_noticed.date()
        if d1:
            parts.append(f"Symptoms were first noticed around {d1.strftime('%d %b %Y')}.")

        d2 = self.date_became_severe.date()
        if d2:
            parts.append(f"Symptoms became more severe around {d2.strftime('%d %b %Y')}.")

        return " ".join(parts)

    def preview_course(self):
        sub, obj, poss, verb = pronouns_from_gender(self.gender)
        parts = []

        patterns = self.course_group.get_selected()
        if patterns:
            parts.append(f"The course has been {', '.join(p.lower() for p in patterns)}.")

        ep = self.episode_number.text()
        if ep:
            parts.append(f"This appears to be episode number {ep}.")

        desc = self.course_description.text()
        if desc:
            parts.append(desc)

        events = self.timeline_events.get_events()
        if events:
            lines = [f"{l}: {t}" if l and t else l or t for l, t in events]
            if lines:
                parts.append(f"Timeline includes {'; '.join(lines)}.")

        return " ".join(parts)

    def preview_risks(self):
        sub, obj, poss, verb = pronouns_from_gender(self.gender)
        selected = self.risk_categories.get_selected()

        if "None reported" in selected:
            return f"{sub} {verb('report')} no current risks."

        parts = []
        if selected:
            parts.append(f"Risks identified include: {', '.join(s.lower() for s in selected)}.")

        for field, label in [
            (self.risk_frequency, "Frequency"),
            (self.risk_intensity, "Intensity"),
            (self.risk_intent, "Intent"),
            (self.risk_means, "Access to means"),
        ]:
            if field.text():
                parts.append(f"{label}: {field.text()}.")

        if self.risk_incidents.text():
            parts.append(f"Recent concerns: {self.risk_incidents.text()}")
        if self.risk_protective.text():
            parts.append(f"Protective factors: {self.risk_protective.text()}")

        return " ".join(parts)

    def preview_past(self):
        parts = []
        flags = self.past_flags.get_selected()
        if flags:
            flags_lower = [f.lower() for f in flags]
            if len(flags_lower) == 1:
                flags_text = flags_lower[0]
            elif len(flags_lower) == 2:
                flags_text = f"{flags_lower[0]} and {flags_lower[1]}"
            else:
                flags_text = ", ".join(flags_lower[:-1]) + f", and {flags_lower[-1]}"
            parts.append(f"Historical factors include {flags_text}.")
        if self.past_treatment.text():
            parts.append(f"Previous treatment: {self.past_treatment.text()}")
        return " ".join(parts)

    def preview_model(self):
        sub, obj, poss, verb = pronouns_from_gender(self.gender)
        parts = []
        model_expand = {
            "Stress": "stress-related",
            "Chemical": "chemical imbalance",
            "Trauma": "trauma-related",
            "Physical": "physical health related",
            "Social": "social or situational",
            "Uncertain": "uncertain"
        }
        sel = self.model_chips.get_selected()
        if sel:
            expanded = [model_expand.get(s, s.lower()) for s in sel]
            parts.append(f"{sub} {verb('understand')} the symptoms as {', '.join(expanded)}.")
        if self.model_notes.text():
            parts.append(self.model_notes.text())
        return " ".join(parts)

    def preview_collateral(self):
        parts = []
        ctype = self.collateral_type.get_selected()
        collateral_expand = {
            "Present": "collateral present",
            "Telephone": "telephone collateral",
            "None obtained": "no collateral obtained"
        }
        if ctype:
            expanded = [collateral_expand.get(c, c.lower()) for c in ctype]
            parts.append(f"Collateral: {', '.join(expanded)}.")
        if self.collateral_concerns.text():
            parts.append(f"Carer concerns: {self.collateral_concerns.text()}")
        return " ".join(parts)

    def preview_pc_summary(self):
        """Include summary from Presenting Complaint if available."""
        if not self._pc_data:
            return ""

        text = self._pc_data.get("formatted", "") or self._pc_data.get("text", "")
        if text and text != "No symptoms selected.":
            return f"From presenting complaint:\n{text}"
        return ""

    # =====================================================================
    # GENERATE TEXT AND SEND TO CARD
    # =====================================================================
    def _generate_text(self) -> str:
        """Generate the section text."""
        parts = [
            self.preview_onset(),
            self.preview_course(),
            self.preview_risks(),
            self.preview_past(),
            self.preview_model(),
            self.preview_collateral(),
        ]
        # Join as flowing paragraph (skip PC summary since it's in its own section)
        return " ".join(p for p in parts if p.strip())

    def update_preview(self):
        """Legacy method name - now sends to card immediately."""
        self._send_to_card()

    def _send_to_card(self):
        """Send current text to card immediately."""
        self.save_current()
        text = self._generate_text().strip()
        if text:
            self.sent.emit(text)

    # =====================================================================
    # SAVE / LOAD
    # =====================================================================
    def save_current(self):
        self.saved_data = {
            "gender": self.gender,
            "onset": self.onset_combo.currentText(),
            "triggers": self.trigger_group.get_selected(),
            "other_trigger": self.other_trigger.text(),
            "date_first": self.date_first_noticed.date(),
            "date_severe": self.date_became_severe.date(),
            "course": self.course_group.get_selected(),
            "episode": self.episode_number.text(),
            "course_desc": self.course_description.text(),
            "timeline": self.timeline_events.get_events(),
            "risks": self.risk_categories.get_selected(),
            "risk_freq": self.risk_frequency.text(),
            "risk_intensity": self.risk_intensity.text(),
            "risk_intent": self.risk_intent.text(),
            "risk_means": self.risk_means.text(),
            "risk_incidents": self.risk_incidents.text(),
            "risk_protective": self.risk_protective.text(),
            "past_flags": self.past_flags.get_selected(),
            "past_treatment": self.past_treatment.text(),
            "model_selected": self.model_chips.get_selected(),
            "model_notes": self.model_notes.text(),
            "collateral_type": self.collateral_type.get_selected(),
            "collateral_concerns": self.collateral_concerns.text(),
            "pc_data": self._pc_data,
        }

    def load_saved(self, data=None):
        if data is None:
            data = self.saved_data
        if not data:
            return

        idx = self.onset_combo.findText(data.get("onset", ""))
        if idx >= 0:
            self.onset_combo.setCurrentIndex(idx)

        self.trigger_group.set_selected(data.get("triggers", []))
        self.other_trigger.setText(data.get("other_trigger", ""))
        self.date_first_noticed.set_date(data.get("date_first"))
        self.date_became_severe.set_date(data.get("date_severe"))

        self.course_group.set_selected(data.get("course", []))
        self.episode_number.set_text(data.get("episode", ""))
        self.course_description.set_text(data.get("course_desc", ""))
        self.timeline_events.load_events(data.get("timeline", []))

        self.risk_categories.set_selected(data.get("risks", []))
        self.risk_frequency.set_text(data.get("risk_freq", ""))
        self.risk_intensity.set_text(data.get("risk_intensity", ""))
        self.risk_intent.set_text(data.get("risk_intent", ""))
        self.risk_means.set_text(data.get("risk_means", ""))
        self.risk_incidents.set_text(data.get("risk_incidents", ""))
        self.risk_protective.set_text(data.get("risk_protective", ""))

        self.past_flags.set_selected(data.get("past_flags", []))
        self.past_treatment.set_text(data.get("past_treatment", ""))

        self.model_chips.set_selected(data.get("model_selected", []))
        self.model_notes.set_text(data.get("model_notes", ""))

        self.collateral_type.set_selected(data.get("collateral_type", []))
        self.collateral_concerns.set_text(data.get("collateral_concerns", ""))

        self._pc_data = data.get("pc_data")

        self.update_preview()

    # =====================================================================
    # EMIT / CLOSE
    # =====================================================================
    def _emit_text(self):
        self.save_current()
        text = self._generate_text().strip()
        if text:
            self.sent.emit(text)
        self.close()

    def formatted_section_text(self):
        return self._generate_text()

    def closeEvent(self, event):
        self.save_current()
        self.closed.emit(self.saved_data)
        super().closeEvent(event)

    def hideEvent(self, event):
        self.save_current()
        super().hideEvent(event)

    def sizeHint(self):
        return QSize(400, 700)

    def minimumSizeHint(self):
        return QSize(300, 400)
