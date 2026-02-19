from __future__ import annotations

from PySide6.QtCore import Qt, QPoint, QPropertyAnimation, QTimer, Signal
from PySide6.QtWidgets import QSizePolicy
from PySide6.QtWidgets import (
    QWidget, QLabel, QPushButton, QVBoxLayout, QHBoxLayout, QScrollArea,
    QTextEdit, QSlider, QApplication, QFrame
)
from shared_widgets import add_lock_to_popup
from spell_check_textedit import enable_spell_check_on_textedit

# ============================================================
# NO-WHEEL SLIDER (prevents scroll from changing value)
# ============================================================
class NoWheelSlider(QSlider):
    def wheelEvent(self, event):
        event.ignore()


# ============================================================
#  PRONOUN ENGINE
# ============================================================
def pronouns_from_gender(gender: str):
    """
    Returns a dict with grammar-aware pronouns:
    subject, object, possessive adjective, possessive noun,
    AND correct plural/singular verb forms for they/he/she.
    """
    g = (gender or "").strip().lower()

    if g == "male":
        return {
            "subj": "he",
            "obj": "him",
            "pos": "his",
            "pos_noun": "his",
            "be_present": "is",
            "be_past": "was",
            "have_present": "has"
        }

    if g == "female":
        return {
            "subj": "she",
            "obj": "her",
            "pos": "her",
            "pos_noun": "hers",
            "be_present": "is",
            "be_past": "was",
            "have_present": "has"
        }

    # THEY — plural grammar
    return {
        "subj": "they",
        "obj": "them",
        "pos": "their",
        "pos_noun": "theirs",
        "be_present": "are",
        "be_past": "were",
        "have_present": "have"
    }


# ============================================================
# CLICKABLE ROW ITEM
# ============================================================
class RowItem(QWidget):
    clicked = Signal(str)

    def __init__(self, label: str, parent=None):
        super().__init__(parent)

        self.label = label
        self._active = False

        # -------------------------
        # LAYOUT (MUST BE HERE)
        # -------------------------
        lay = QHBoxLayout(self)
        lay.setContentsMargins(18, 4, 2, 4)

        self.lbl = QLabel(label)
        self.lbl.setStyleSheet("font-size: 21px; color:#003c32;")
        lay.addWidget(self.lbl)

        self._apply_style()

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self.clicked.emit(self.label)

    # -------------------------
    # ACTIVE STATE (TRACE PATH)
    # -------------------------
    def set_active(self, active: bool):
        self._active = active
        self._apply_style()

    def _apply_style(self):
        if self._active:
            self.setStyleSheet("""
                QWidget {
                    background: rgba(0,140,126,0.22);
                    border-radius: 4px;
                }
            """)
        else:
            self.setStyleSheet("""
                QWidget { background: transparent; }
                QWidget:hover {
                    background: rgba(0,0,0,0.06);
                    border-radius: 4px;
                }
            """)

# ============================================================
# COLLAPSIBLE SECTION
# ============================================================
class Collapsible(QWidget):
    def __init__(self, title: str, parent=None):
        super().__init__(parent)

        self.header = QPushButton(title)
        self.header.setCheckable(True)
        self.header.setChecked(False)
        self.header.clicked.connect(self._toggle)

        self.header.setStyleSheet("""
            QPushButton {
                font-size: 21px; font-weight: 600;
                text-align: left; padding: 8px;
                border-radius: 6px; background: rgba(0,0,0,0.05);
                color:#003c32;
            }
            QPushButton:checked {
                background: rgba(0,0,0,0.12);
            }
        """)

        self.container = QWidget()
        self.container.setVisible(False)

        lay = QVBoxLayout(self)
        lay.setContentsMargins(0,0,0,0)
        lay.addWidget(self.header)
        lay.addWidget(self.container)

        self.vbox = QVBoxLayout(self.container)
        self.vbox.setContentsMargins(12,4,12,6)
        self.vbox.setSpacing(4)

        self.items = {}

    def _toggle(self):
        self.container.setVisible(self.header.isChecked())

    def add_row_item(self, text: str):
        item = RowItem(text)
        self.vbox.addWidget(item)
        self.items[text] = item
        return item


# ============================================================
# MINI POPUP EDITOR
# ============================================================
# Mania symptom labels for identification
MANIA_LABELS = {
    "Heightened perception", "Psychomotor activity",
    "Pressure of speech", "Disinhibition",
    "Distractibility", "Irritability", "Overspending"
}

class MiniAffectEditorPopup(QWidget):
    saved = Signal(str, int, str)

    def __init__(self, label: str, value: int, details: str, is_mania: bool = False, parent=None):
        super().__init__(parent)
        self.label = label
        self.logical_parent = None
        self.is_mania = is_mania

        self.setWindowFlags(Qt.FramelessWindowHint | Qt.Tool)
        self.setMinimumWidth(380)

        self.setStyleSheet("""
            QWidget {
                background: rgba(255,255,255,0.92);
                border-radius: 14px;
                border: 1px solid rgba(0,0,0,0.25);
            }
            QLabel { color:#003c32; border: none; }
        """)

        outer = QVBoxLayout(self)
        outer.setContentsMargins(16,16,16,16)
        outer.setSpacing(12)

        # TITLE
        trow = QHBoxLayout()
        self.title_lbl = QLabel(label)
        self.title_lbl.setStyleSheet("font-size:21px; font-weight:700; color:#003c32;")
        trow.addWidget(self.title_lbl)
        trow.addStretch()

        close_btn = QPushButton("×")
        close_btn.setFixedSize(28,28)
        close_btn.clicked.connect(self.close)
        close_btn.setStyleSheet("""
            QPushButton {
                background: rgba(0,0,0,0.07);
                border-radius: 6px;
                font-size: 21px;
            }
        """)
        trow.addWidget(close_btn)
        outer.addLayout(trow)

        # Labels - different for depression vs mania
        lr = QHBoxLayout()
        if is_mania:
            # Mania: Mild / Moderate / Severe (starting from mild at left)
            self.label_left = QLabel("Mild")
            self.label_mid = QLabel("Moderate")
            self.label_right = QLabel("Severe")
        else:
            # Depression: Low / Normal / High
            self.label_left = QLabel("Low")
            self.label_mid = QLabel("Normal")
            self.label_right = QLabel("High")
        lr.addWidget(self.label_left)
        lr.addStretch()
        lr.addWidget(self.label_mid)
        lr.addStretch()
        lr.addWidget(self.label_right)
        outer.addLayout(lr)

        self.slider = NoWheelSlider(Qt.Horizontal)
        self.slider.setRange(0, 100)
        # For mania, start at 0 (mild) instead of 50 (normal)
        if is_mania and value == 50:
            value = 0
        self.slider.setValue(value)
        outer.addWidget(self.slider)

        self.details_header = QPushButton("Add details ▼")
        self.details_header.setCheckable(True)
        self.details_header.clicked.connect(self._toggle_details)
        outer.addWidget(self.details_header)

        self.details_box = QTextEdit()
        self.details_box.setVisible(False)
        self.details_box.setText(details)
        self.details_box.setMinimumHeight(100)
        self.details_box.setMaximumHeight(100)
        self._details_height = 100
        enable_spell_check_on_textedit(self.details_box)
        outer.addWidget(self.details_box)

        # Drag bar for resizing details box
        self.details_drag_bar = QFrame()
        self.details_drag_bar.setFixedHeight(8)
        self.details_drag_bar.setCursor(Qt.CursorShape.SizeVerCursor)
        self.details_drag_bar.setVisible(False)
        self.details_drag_bar.setStyleSheet("""
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 rgba(0,0,0,0.03), stop:0.5 rgba(0,0,0,0.1), stop:1 rgba(0,0,0,0.03));
                border-radius: 2px;
                margin: 0px 30px;
            }
            QFrame:hover {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 rgba(37,99,235,0.15), stop:0.5 rgba(37,99,235,0.4), stop:1 rgba(37,99,235,0.15));
            }
        """)
        self.details_drag_bar.installEventFilter(self)
        self._details_dragging = False
        outer.addWidget(self.details_drag_bar)

        save_btn = QPushButton("Save & Close")
        save_btn.clicked.connect(self._save)
        save_btn.setStyleSheet("""
            QPushButton {
                padding: 8px;
                background:#008C7E;
                color:white;
                border-radius:6px;
            }
        """)
        outer.addWidget(save_btn)

    def _toggle_details(self):
        visible = self.details_header.isChecked()
        self.details_box.setVisible(visible)
        self.details_drag_bar.setVisible(visible)

    def eventFilter(self, obj, event):
        from PySide6.QtCore import QEvent
        if obj == self.details_drag_bar:
            if event.type() == QEvent.Type.MouseButtonPress:
                self._details_dragging = True
                self._drag_start_y = event.globalPosition().y()
                self._drag_start_height = self._details_height
                return True
            elif event.type() == QEvent.Type.MouseMove and self._details_dragging:
                delta = event.globalPosition().y() - self._drag_start_y
                new_height = max(60, min(300, int(self._drag_start_height + delta)))
                self._details_height = new_height
                self.details_box.setMinimumHeight(new_height)
                self.details_box.setMaximumHeight(new_height)
                return True
            elif event.type() == QEvent.Type.MouseButtonRelease:
                self._details_dragging = False
                return True
        return super().eventFilter(obj, event)

    def _save(self):
        self.saved.emit(
            self.label,
            self.slider.value(),
            self.details_box.toPlainText().strip()
        )
        self.close()

    def show_centered(self, parent: QWidget):
        rect = parent.rect()
        tl = parent.mapToGlobal(rect.topLeft())
        x = tl.x() + rect.width()//2 - self.width()//2
        y = tl.y() + rect.height()//2 - self.height()//2
        self.move(x, y)

        self.setWindowOpacity(0)
        self.show()
        anim = QPropertyAnimation(self, b"windowOpacity")
        anim.setDuration(150)
        anim.setStartValue(0)
        anim.setEndValue(1)
        anim.start()
        self._anim = anim

    def set_mania_mode(self, is_mania: bool):
        """Update labels for mania vs depression mode."""
        self.is_mania = is_mania
        if is_mania:
            self.label_left.setText("Mild")
            self.label_mid.setText("Moderate")
            self.label_right.setText("Severe")
        else:
            self.label_left.setText("Low")
            self.label_mid.setText("Normal")
            self.label_right.setText("High")


# ============================================================
#  MAIN AFFECT POPUP
# ============================================================
class AffectPopup(QWidget):
    sent = Signal(str)
    closed = Signal(dict)

    def update_gender(self, gender: str):
        """Update pronouns when gender changes on front page."""
        self.gender = gender
        self.pron = pronouns_from_gender(gender)
        # Refresh and send to card
        self._update_all()
        self._send_to_card()

    def __init__(self, first_name: str, gender: str, parent=None):
        super().__init__(parent)

        # Fixed panel style (not draggable)
        self.setWindowFlags(Qt.WindowType.Widget)
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        # Name
        self.first_name = first_name.strip() if first_name else "The patient"

        # Pronouns
        self.gender = gender
        self.pron = pronouns_from_gender(gender)

        # Model store
        self.values = {}
        self.saved_data = {}
        self.initial_state = None
        self._pwp = None

        # --------------------------------------------------------
        # UI LAYOUT
        # --------------------------------------------------------
        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(8)

        # ========================================================
        # SECTION 1: DIAGNOSIS BOX (fixed at very top)
        # ========================================================
        self.diag_box = QLabel("Likely diagnosis: —")
        self.diag_box.setWordWrap(True)
        self.diag_box.setStyleSheet("""
            background:#003c32;
            color:white; padding:8px 12px;
            border-radius:8px; font-weight:600;
            font-size:21px;
        """)
        root.addWidget(self.diag_box)


        # ========================================================
        # SECTION 3: SCROLLABLE COLLAPSED SECTIONS
        # ========================================================
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        self.container = QWidget()
        self.container.setObjectName("aff_popup")
        self.container.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)
        self.container.setStyleSheet("""
            QWidget#aff_popup {
                background: rgba(255,255,255,0.92);
                border-radius: 12px;
                border: 1px solid rgba(0,0,0,0.15);
            }
            QLabel { color:#003c32; border: none; }
        """)
        scroll.setWidget(self.container)

        layout = QVBoxLayout(self.container)
        layout.setContentsMargins(12, 12, 12, 12)
        layout.setSpacing(12)

        # DEPRESSIVE FEATURES
        self.sec_dep = Collapsible("Depressive Features")
        layout.addWidget(self.sec_dep)

        dep_labels = [
            "Mood","Energy","Anhedonia","Sleep","Appetite","Libido",
            "Self-esteem","Concentration","Guilt",
            "Hopelessness / Helplessness","Suicidal thoughts"
        ]
        for lbl in dep_labels:
            w = self.sec_dep.add_row_item(lbl)
            w.clicked.connect(self._open_editor)

        # MANIC FEATURES
        self.sec_mania = Collapsible("Manic Features")
        layout.addWidget(self.sec_mania)

        mania_labels = [
            "Heightened perception","Psychomotor activity",
            "Pressure of speech","Disinhibition",
            "Distractibility","Irritability","Overspending"
        ]
        for lbl in mania_labels:
            w = self.sec_mania.add_row_item(lbl)
            w.clicked.connect(self._open_editor)

        layout.addStretch()

        root.addWidget(scroll, 1)

        QTimer.singleShot(60, self._update_all)

        # Add lock functionality
        add_lock_to_popup(self, show_button=False)

    # ============================================================
    #  NARRATIVE ENGINE: scale_text()
    # ============================================================
    def scale_text(self, label, value):
        """
        Correct 2-argument version.
        Generates symptom narrative using pronoun grammar rules.
        """
        p = self.pron
        is_mania = label in MANIA_LABELS

        # VALUE BUCKETS - different scale for mania (1-dimensional: mild/moderate/severe)
        if is_mania:
            if value <= 33:
                bucket = "mild"
            elif value <= 66:
                bucket = "moderate"
            else:
                bucket = "severe"
        else:
            # Depression uses 2-dimensional scale (low/normal/high)
            if value <= 10:
                bucket = "vlow"
            elif value <= 25:
                bucket = "low"
            elif value <= 40:
                bucket = "mild_low"
            elif value <= 60:
                bucket = "normal"
            elif value <= 70:
                bucket = "mild_high"
            elif value <= 85:
                bucket = "high"
            else:
                bucket = "vhigh"

        subj = p["subj"]
        subj_cap = subj.capitalize()
        pos = p["pos"]
        be_past = p["be_past"]

        # ----------------------- DEPRESSION ---------------------

        if label == "Mood":
            mapping = {
                "vlow": f"{subj_cap} felt very low in mood.",
                "low": f"{subj_cap} felt low in mood.",
                "mild_low": f"{subj_cap} felt mildly low in mood.",
                "normal": "Mood was normal.",
                "mild_high": f"{subj_cap} felt slightly elevated in mood.",
                "high": f"{pos.capitalize()} mood {be_past} elevated.",
                "vhigh": f"{pos.capitalize()} mood {be_past} significantly elevated."
            }
            return mapping[bucket]

        if label == "Energy":
            mapping = {
                "vlow": f"{subj_cap} had very low energy.",
                "low": f"{subj_cap} had low energy.",
                "mild_low": f"{subj_cap} had mildly reduced energy.",
                "normal": "Energy was normal.",
                "mild_high": f"{subj_cap} had slightly increased energy.",
                "high": f"{subj_cap} had increased energy.",
                "vhigh": f"{subj_cap} had significantly increased energy."
            }
            return mapping[bucket]

        if label == "Anhedonia":
            mapping = {
                "normal": "There was no anhedonia.",
                "mild_high": f"{subj_cap} reported mild anhedonia.",
                "high": f"{subj_cap} reported moderate anhedonia.",
                "vhigh": f"{subj_cap} reported significant anhedonia."
            }
            return mapping.get(bucket, "There was no anhedonia.")

        if label == "Sleep":
            mapping = {
                "vlow": f"Sleep {be_past} very poor.",
                "low": f"Sleep {be_past} poor.",
                "mild_low": f"Sleep {be_past} mildly disrupted.",
                "normal": "Sleep was normal.",
                "mild_high": f"{subj_cap} {be_past} sleeping slightly more than usual.",
                "high": f"{subj_cap} {be_past} sleeping significantly more than usual.",
                "vhigh": f"{subj_cap} described excessive oversleeping."
            }
            return mapping[bucket]

        if label == "Appetite":
            mapping = {
                "vlow": f"{pos.capitalize()} appetite {be_past} very poor.",
                "low": f"{pos.capitalize()} appetite {be_past} poor.",
                "mild_low": f"{subj_cap} {be_past} eating less than normal.",
                "normal": "Appetite was normal.",
                "mild_high": f"{subj_cap} {be_past} eating more than normal.",
                "high": f"{subj_cap} {be_past} moderately overeating.",
                "vhigh": f"{subj_cap} {be_past} significantly overeating."
            }
            return mapping[bucket]

        if label == "Libido":
            mapping = {
                "vlow": f"{pos.capitalize()} sex drive {be_past} absent.",
                "low": f"{pos.capitalize()} sex drive {be_past} significantly reduced.",
                "mild_low": f"{pos.capitalize()} sex drive {be_past} mildly reduced.",
                "normal": "Sex drive was normal.",
                "mild_high": f"{pos.capitalize()} sex drive {be_past} mildly increased.",
                "high": f"{pos.capitalize()} sex drive {be_past} significantly increased.",
                "vhigh": f"{subj_cap} described excessively increased sex drive."
            }
            return mapping[bucket]

        if label == "Self-esteem":
            mapping = {
                "vlow": "Self-esteem was very low.",
                "low": "Self-esteem was low.",
                "mild_low": "Self-esteem was mildly reduced.",
                "normal": "Self-esteem was normal.",
                "mild_high": "Self-esteem was slightly increased.",
                "high": "Self-esteem was increased.",
                "vhigh": "Self-esteem was significantly increased."
            }
            return mapping[bucket]

        # ---------- CONCENTRATION ----------
        if label == "Concentration":
                # Concentration is singular → always “was”, never “were”
                was = "was"

                mapping = {
                        "vlow": f"{subj_cap} reported complete inability to concentrate.",
                        "low": f"{subj_cap} reported significant difficulty concentrating.",
                        "mild_low": f"{pos.capitalize()} concentration {was} mildly disturbed.",
                        "normal": "Concentration was normal.",
                        "mild_high": f"{pos.capitalize()} concentration {was} above normal.",
                        "high": f"{subj_cap} reported significantly increased concentration.",
                        "vhigh": f"{subj_cap} reported very high levels of concentration."
                }
                return mapping[bucket]


        if label == "Guilt":
            mapping = {
                "normal": "There were no feelings of guilt.",
                "mild_high": f"{subj_cap} had some feelings of guilt.",
                "high": f"{subj_cap} had moderate feelings of guilt.",
                "vhigh": f"{subj_cap} had overwhelming feelings of guilt."
            }
            return mapping.get(bucket, "There were no feelings of guilt.")

        if label == "Hopelessness / Helplessness":
            mapping = {
                "normal": "There were no feelings of hopelessness.",
                "mild_high": f"{subj_cap} had some feelings of hopelessness.",
                "high": f"{subj_cap} had moderate feelings of hopelessness.",
                "vhigh": f"{subj_cap} had overwhelming feelings of hopelessness."
            }
            return mapping.get(bucket, "There were no feelings of hopelessness.")

        if label == "Suicidal thoughts":
            mapping = {
                "normal": "There were no suicidal thoughts.",
                "mild_high": f"{subj_cap} reported fleeting suicidal thoughts.",
                "high": f"{subj_cap} reported moderate suicidal thoughts.",
                "vhigh": f"{subj_cap} reported overwhelming suicidal thoughts."
            }
            return mapping.get(bucket, "There were no suicidal thoughts.")

        # ---------------------------- MANIA -----------------------------
        # Mania uses 1-dimensional scale: mild/moderate/severe

        if label == "Heightened perception":
            return {
                "mild": f"{subj_cap} reported mildly increased perception.",
                "moderate": f"{subj_cap} reported moderately increased perception.",
                "severe": f"{subj_cap} reported severely increased perception."
            }[bucket]

        if label == "Psychomotor activity":
            return {
                "mild": "There was mild increase in psychomotor activity.",
                "moderate": "There was moderate increase in psychomotor activity.",
                "severe": "There was severe increase in psychomotor activity."
            }[bucket]

        if label == "Pressure of speech":
            return {
                "mild": f"{subj_cap} reported mild pressure of speech.",
                "moderate": f"{subj_cap} reported moderate pressure of speech.",
                "severe": f"{subj_cap} reported severe pressure of speech."
            }[bucket]

        if label == "Disinhibition":
            return {
                "mild": "There was mild disinhibition.",
                "moderate": "There was moderate disinhibition.",
                "severe": "There was severe disinhibition."
            }[bucket]

        if label == "Distractibility":
            return {
                "mild": "There was mild distractibility.",
                "moderate": "There was moderate distractibility.",
                "severe": "There was severe distractibility."
            }[bucket]

        if label == "Irritability":
            return {
                "mild": "There was mild irritability.",
                "moderate": "There was moderate irritability.",
                "severe": "There was severe irritability."
            }[bucket]

        if label == "Overspending":
            return {
                "mild": "There was mild overspending.",
                "moderate": "There was moderate overspending.",
                "severe": "There was severe overspending."
            }[bucket]

        return None

    # ============================================================
    # OPEN / SAVE POPUP
    # ============================================================
    def _open_editor(self, label):
        value, details = self.values.get(label, (50,""))
        is_mania = label in MANIA_LABELS

        # For mania sliders, default to 0 (mild) instead of 50 (normal)
        if is_mania and value == 50:
            value = 0

        # Reuse existing
        if self._pwp is not None and not self._pwp.isHidden():
            p = self._pwp
            p.blockSignals(True)
            p.label = label
            p.title_lbl.setText(label)
            p.set_mania_mode(is_mania)
            p.slider.setValue(value)
            p.details_box.setText(details)
            p.blockSignals(False)
            p.raise_()
            p.activateWindow()
            return

        popup = MiniAffectEditorPopup(label, value, details, is_mania=is_mania, parent=self.window())
        self._pwp = popup
        popup.saved.connect(self._save_value)
        popup.destroyed.connect(lambda: self._clear_pwp())
        popup.show_centered(self)
        popup.raise_()
        popup.activateWindow()

    def _is_row_modified(self, label: str) -> bool:
        """
        A row is considered modified if:
        - slider value is meaningfully non-neutral, OR
        - details text is non-empty
        For mania symptoms, any value is considered modified (since 0=mild is valid).
        """
        value, details = self.values.get(label, (50, ""))
        if details.strip():
            return True

        # Mania symptoms: any value is meaningful (0=mild, 50=moderate, 100=severe)
        if label in MANIA_LABELS:
            return True  # If it's in values dict, it's been clicked

        # Depression symptoms: check if non-neutral
        return value < 45 or value > 55
    
    def _refresh_row_highlights(self):
        for section in (self.sec_dep, self.sec_mania):
            for label, row in section.items.items():
                row.set_active(self._is_row_modified(label))


    def _clear_pwp(self):
        self._pwp = None

    def save_current(self):
        """
        Packages all affect data into saved_data so Letter Writer can use it
        and the popup can restore it later.
        """
        final_text = self.formatted_section_text()

        self.saved_data = {
            "text": final_text,
            "diagnosis": self.compute_diagnosis(),
            "values": self.values.copy()
        }
        return self.saved_data

    def load_saved_data(self, state: dict):
        """
        Restores slider values, details, preview text,
        AND re-applies row highlights.
        """
        if not state:
            return

        self.initial_state = state

        # Restore values
        self.values = state.get("values", {}).copy()

        # Refresh UI
        self._update_all()
        self._refresh_row_highlights()



    def _save_value(self, label, value, details):
        self.values[label] = (value, details)

        self._update_all()
        self._refresh_row_highlights()

        # Send to card immediately on value change
        self._send_to_card()


    # ============================================================
    # DIAGNOSIS ENGINE — ICD-10 SPECTRUM APPROACH
    # Spectrum: Mania ↔ Hypomania ↔ Mixed ↔ Depression
    # ============================================================
    def compute_diagnosis(self):
        """
        ICD-10 based diagnostic algorithm with spectrum approach.
        Sensitive to mixed affective states when both poles present.
        """

        def get_val(label):
            return self.values.get(label, (50, ""))[0]

        # Thresholds - using moderate thresholds for better sensitivity
        LOW_THRESH = 40         # Below this = low symptom present
        HIGH_THRESH = 60        # Above this = high symptom present
        MODERATE_LOW = 30       # Moderate severity low
        MODERATE_HIGH = 70      # Moderate severity high
        SEVERE_LOW = 20         # Severe low
        SEVERE_HIGH = 80        # Severe high

        # =============================================
        # CALCULATE DEPRESSIVE SCORE (0-100 scale)
        # =============================================
        dep_score = 0
        dep_symptoms = 0

        # Low mood (inverted: low value = depressive)
        mood_val = get_val("Mood")
        if mood_val < LOW_THRESH:
            dep_score += (LOW_THRESH - mood_val) * 2
            dep_symptoms += 1

        # Low energy (inverted)
        energy_val = get_val("Energy")
        if energy_val < LOW_THRESH:
            dep_score += (LOW_THRESH - energy_val) * 2
            dep_symptoms += 1

        # Anhedonia (high = present)
        if get_val("Anhedonia") > HIGH_THRESH:
            dep_score += (get_val("Anhedonia") - HIGH_THRESH) * 2
            dep_symptoms += 1

        # Low concentration
        if get_val("Concentration") < LOW_THRESH:
            dep_score += (LOW_THRESH - get_val("Concentration"))
            dep_symptoms += 1

        # Low self-esteem
        if get_val("Self-esteem") < LOW_THRESH:
            dep_score += (LOW_THRESH - get_val("Self-esteem"))
            dep_symptoms += 1

        # Guilt (high = present)
        if get_val("Guilt") > HIGH_THRESH:
            dep_score += (get_val("Guilt") - HIGH_THRESH)
            dep_symptoms += 1

        # Hopelessness (high = present)
        if get_val("Hopelessness / Helplessness") > HIGH_THRESH:
            dep_score += (get_val("Hopelessness / Helplessness") - HIGH_THRESH)
            dep_symptoms += 1

        # Suicidal thoughts (high = present) - weighted heavily
        suicidal = get_val("Suicidal thoughts")
        if suicidal > HIGH_THRESH:
            dep_score += (suicidal - HIGH_THRESH) * 1.5
            dep_symptoms += 1

        # Sleep disturbance (very low = insomnia)
        sleep_val = get_val("Sleep")
        if sleep_val < MODERATE_LOW:
            dep_score += (MODERATE_LOW - sleep_val)
            dep_symptoms += 1

        # Low appetite
        if get_val("Appetite") < LOW_THRESH:
            dep_score += (LOW_THRESH - get_val("Appetite"))
            dep_symptoms += 1

        # Low libido
        if get_val("Libido") < LOW_THRESH:
            dep_score += (LOW_THRESH - get_val("Libido"))
            dep_symptoms += 1

        # =============================================
        # CALCULATE MANIC SCORE (0-100 scale)
        # =============================================
        manic_score = 0
        manic_symptoms = 0

        # Elevated mood
        if mood_val > HIGH_THRESH:
            manic_score += (mood_val - HIGH_THRESH) * 2
            manic_symptoms += 1

        # Elevated energy
        if energy_val > HIGH_THRESH:
            manic_score += (energy_val - HIGH_THRESH) * 2
            manic_symptoms += 1

        # Irritability
        irritability = get_val("Irritability")
        if irritability > HIGH_THRESH:
            manic_score += (irritability - HIGH_THRESH) * 1.5
            manic_symptoms += 1

        # Heightened perception
        if get_val("Heightened perception") > HIGH_THRESH:
            manic_score += (get_val("Heightened perception") - HIGH_THRESH)
            manic_symptoms += 1

        # Psychomotor activity
        if get_val("Psychomotor activity") > HIGH_THRESH:
            manic_score += (get_val("Psychomotor activity") - HIGH_THRESH)
            manic_symptoms += 1

        # Pressure of speech
        if get_val("Pressure of speech") > HIGH_THRESH:
            manic_score += (get_val("Pressure of speech") - HIGH_THRESH)
            manic_symptoms += 1

        # Disinhibition
        if get_val("Disinhibition") > HIGH_THRESH:
            manic_score += (get_val("Disinhibition") - HIGH_THRESH)
            manic_symptoms += 1

        # Distractibility
        if get_val("Distractibility") > HIGH_THRESH:
            manic_score += (get_val("Distractibility") - HIGH_THRESH)
            manic_symptoms += 1

        # Overspending
        if get_val("Overspending") > HIGH_THRESH:
            manic_score += (get_val("Overspending") - HIGH_THRESH)
            manic_symptoms += 1

        # Grandiosity (high self-esteem)
        if get_val("Self-esteem") > HIGH_THRESH:
            manic_score += (get_val("Self-esteem") - HIGH_THRESH)
            manic_symptoms += 1

        # Decreased sleep need (low sleep + high energy)
        if sleep_val < LOW_THRESH and energy_val > HIGH_THRESH:
            manic_score += 20
            manic_symptoms += 1

        # =============================================
        # SPECTRUM DIAGNOSIS LOGIC
        # =============================================

        # Normalize scores
        dep_score = min(dep_score, 100)
        manic_score = min(manic_score, 100)

        # Calculate ratio for spectrum positioning
        total_score = dep_score + manic_score

        if total_score < 15:
            return "No significant mood disturbance"

        # Both poles active = Mixed state consideration
        both_active = dep_symptoms >= 2 and manic_symptoms >= 2
        dep_significant = dep_score >= 25 and dep_symptoms >= 2
        manic_significant = manic_score >= 25 and manic_symptoms >= 2

        # ---- MIXED AFFECTIVE STATE ----
        # Detected when BOTH poles show significant symptoms
        if dep_significant and manic_significant:
            if dep_score > manic_score * 1.5:
                return "Mixed: Depressive episode with manic features"
            elif manic_score > dep_score * 1.5:
                return "Mixed: Manic/hypomanic with depressive features"
            else:
                return "Mixed affective episode (F38.0)"

        # If both poles have some activity but not fully significant
        if both_active and total_score >= 30:
            if manic_score > dep_score:
                return "Mixed: Hypomanic with depressive features"
            else:
                return "Mixed: Depressive with hypomanic features"

        # ---- PURE MANIC POLE ----
        if manic_significant and not dep_significant:
            if manic_score >= 70 and manic_symptoms >= 5:
                return "Manic episode, severe (F30.1)"
            elif manic_score >= 50 and manic_symptoms >= 4:
                return "Manic episode (F30.1)"
            elif manic_score >= 30 and manic_symptoms >= 3:
                return "Hypomanic episode (F30.0)"
            elif manic_symptoms >= 2:
                return "Subthreshold hypomanic features"

        # ---- PURE DEPRESSIVE POLE ----
        if dep_significant and not manic_significant:
            if dep_score >= 70 or get_val("Suicidal thoughts") > SEVERE_HIGH:
                return "Severe depressive episode (F32.2)"
            elif dep_score >= 50 and dep_symptoms >= 5:
                return "Moderate depressive episode (F32.1)"
            elif dep_score >= 25 and dep_symptoms >= 3:
                return "Mild depressive episode (F32.0)"
            elif dep_symptoms >= 2:
                return "Subthreshold depressive features"

        # ---- SUBTHRESHOLD / MILD ----
        if manic_symptoms >= 2 and manic_score >= 15:
            return "Subthreshold hypomanic features"
        if dep_symptoms >= 2 and dep_score >= 15:
            return "Subthreshold depressive features"

        return "No clear mood episode identified"

    # ============================================================
    # PREVIEW ENGINE (UNCHANGED FROM YOUR WORKING VERSION)
    # ============================================================
    def formatted_section_text(self):
        """
        Your existing adaptive paragraph engine.
        Untouched except removal of the invalid `he` argument.
        """

        fn = self.first_name
        p = self.pron
        subj = p["subj"]

        # lowercase helper
        def lc(s):
            return s[0].lower() + s[1:] if s else s

        # Collect fragments
        dep_raw = {}
        labels = [
            "Mood","Energy","Anhedonia","Sleep","Appetite","Libido",
            "Self-esteem","Concentration","Guilt",
            "Hopelessness / Helplessness","Suicidal thoughts"
        ]
        for lbl in labels:
            val, details = self.values.get(lbl, (50,""))
            text = self.scale_text(lbl, val)   # <<<<<< FIXED
            if text:
                text = text.rstrip(".")
                if details:
                    text += f", {details}"
            dep_raw[lbl] = text

        # ---------------------------- GROUPS ----------------------------
        core = ["Mood","Energy","Anhedonia"]
        somatic = ["Sleep","Appetite","Libido"]
        cognitive = ["Self-esteem","Concentration"]
        risk = ["Guilt","Hopelessness / Helplessness","Suicidal thoughts"]

        # Normal detector
        def is_normal(t):
            if not t:
                return False
            return ("was normal" in t or "were normal" in t or "no anhedonia" in t)

        # ---------------------------- CORE ----------------------------
        cn = [l for l in core if is_normal(dep_raw[l])]
        ca = [l for l in core if dep_raw[l] and not is_normal(dep_raw[l])]

        if ca:
            parts = []
            if "Mood" in ca:
                parts.append(lc(dep_raw["Mood"]))
                ca.remove("Mood")
            parts.extend(lc(dep_raw[l]) for l in ca)
            parts.extend(
                "there was no anhedonia" if l=="Anhedonia" else f"{l.lower()} was normal"
                for l in cn
            )
            core_sentence = "Regarding depression, " + ", ".join(parts) + "."
        else:
            if set(cn)==set(core):
                core_sentence = "Regarding depression, mood and energy were normal and there was no anhedonia."
            else:
                parts = []
                for l in cn:
                    if l=="Anhedonia": parts.append("there was no anhedonia")
                    else: parts.append(f"{l.lower()} was normal")
                core_sentence = "Regarding depression, " + ", ".join(parts) + "."

        # Helper to join normal items properly
        def join_normal_items(items):
            """Join items like 'sleep and appetite were normal' instead of 'sleep was normal, appetite was normal'"""
            if len(items) == 1:
                return f"{items[0].lower()} was normal"
            elif len(items) == 2:
                return f"{items[0].lower()} and {items[1].lower()} were normal"
            else:
                return ", ".join(i.lower() for i in items[:-1]) + f" and {items[-1].lower()} were normal"

        # ---------------------------- SOMATIC ----------------------------
        sn = [l for l in somatic if is_normal(dep_raw[l])]
        sa = [l for l in somatic if dep_raw[l] and not is_normal(dep_raw[l])]

        if sa:
            parts = [lc(dep_raw[l]) for l in sa]
            if sn:
                parts.append("whilst " + join_normal_items(sn))
            som_sentence = "; " + ", ".join(parts) + "."
        else:
            if len(sn)==3:
                som_sentence = "; sleep, appetite and sex drive were all normal."
            elif sn:
                som_sentence = "; " + join_normal_items(sn) + "."
            else:
                som_sentence = ""

        # ---------------------------- COGNITIVE ----------------------------
        gn = [l for l in cognitive if is_normal(dep_raw[l])]
        ga = [l for l in cognitive if dep_raw[l] and not is_normal(dep_raw[l])]

        if ga:
            parts = [lc(dep_raw[l]) for l in ga]
            if gn:
                parts.append("and " + join_normal_items(gn))
            cog_sentence = "; " + ", ".join(parts) + "."
        else:
            if len(gn)==2:
                cog_sentence = "; self-esteem and concentration were normal."
            elif gn:
                cog_sentence = "; " + gn[0].lower()+" was normal."
            else:
                cog_sentence = ""

        # ---------------------------- RISK ----------------------------
        rn = [l for l in risk if is_normal(dep_raw[l])]
        ra = [l for l in risk if dep_raw[l] and not is_normal(dep_raw[l])]

        if ra:
            ra_texts = [lc(dep_raw[l]) for l in ra]
            if len(ra_texts) == 1:
                rtxt = "; " + ra_texts[0] + "."
            elif len(ra_texts) == 2:
                rtxt = "; " + ra_texts[0] + ", and " + ra_texts[1] + "."
            else:
                rtxt = "; " + ", ".join(ra_texts[:-1]) + ", and " + ra_texts[-1] + "."
        else:
            if len(rn)==3:
                rtxt = "; no feelings of guilt, hopelessness or suicidal thoughts."
            elif rn:
                items=[]
                for l in rn:
                    if "Guilt" in l: items.append("no feelings of guilt")
                    elif "Hopelessness" in l: items.append("no feelings of hopelessness")
                    else: items.append("no suicidal thoughts")
                if len(items)>1:
                    rtxt = "; " + ", ".join(items[:-1]) + " and " + items[-1] + "."
                else:
                    rtxt = "; " + items[0] + "."
            else:
                rtxt = ""

        dep_paragraph = core_sentence.rstrip(".")
        for s in (som_sentence, cog_sentence, rtxt):
            if s:
                dep_paragraph += s.rstrip(".")
        dep_paragraph += "."

        # ---------------------------- MANIA ----------------------------
        # Group symptoms by severity
        mania_labels = [
            "Heightened perception", "Psychomotor activity", "Pressure of speech",
            "Disinhibition", "Distractibility", "Irritability", "Overspending"
        ]

        # Symptom name mapping for cleaner output
        symptom_names = {
            "Heightened perception": "heightened perception",
            "Psychomotor activity": "increased psychomotor activity",
            "Pressure of speech": "pressure of speech",
            "Disinhibition": "disinhibition",
            "Distractibility": "distractibility",
            "Irritability": "irritability",
            "Overspending": "overspending"
        }

        # Group by severity
        severe_symptoms = []
        moderate_symptoms = []
        mild_symptoms = []

        for lbl in mania_labels:
            if lbl not in self.values:
                continue  # Not clicked, skip
            v, details = self.values.get(lbl, (0, ""))
            # Determine bucket - same as individual output (0-33 mild, 34-66 moderate, 67-100 severe)
            if v <= 33:
                mild_symptoms.append(symptom_names[lbl])
            elif v <= 66:
                moderate_symptoms.append(symptom_names[lbl])
            else:
                severe_symptoms.append(symptom_names[lbl])

        def join_symptoms(symptoms):
            if len(symptoms) == 1:
                return symptoms[0]
            elif len(symptoms) == 2:
                return f"{symptoms[0]} and {symptoms[1]}"
            else:
                return ", ".join(symptoms[:-1]) + f" and {symptoms[-1]}"

        mania_parts = []
        # Order: severe first, then moderate, then mild
        if severe_symptoms:
            mania_parts.append(f"{join_symptoms(severe_symptoms)} (severe)")
        if moderate_symptoms:
            mania_parts.append(f"{join_symptoms(moderate_symptoms)} (moderate)")
        if mild_symptoms:
            mania_parts.append(f"{join_symptoms(mild_symptoms)} (mild)")

        if mania_parts:
            if len(mania_parts) == 1:
                mania_para = f"Regarding mania, there was {mania_parts[0]}."
            else:
                mania_para = "Regarding mania, there was " + ", ".join(mania_parts[:-1]) + ", and " + mania_parts[-1] + "."
        else:
            mania_para = "No manic symptoms were present."

        return dep_paragraph + "\n\n" + mania_para

    
    def _emit_text(self):
        self.save_current()
        text = self.saved_data.get("text", "").strip()
        if text:
            self.sent.emit(text)
        self.close()

    def _send_to_card(self):
        """Send current text to card immediately."""
        self.save_current()
        text = self.saved_data.get("text", "").strip()
        if text:
            self.sent.emit(text)

    # ============================================================
    # UI UPDATE
    # ============================================================
    def _update_all(self):
        self.diag_box.setText(self.compute_diagnosis())

    def _refresh_preview_text(self):
        """Called when gender changes to refresh preview with new pronouns."""
        self._update_all()

    # ============================================================
    # CLOSE / HIDE — STATE PERSISTENCE
    # ============================================================
    def closeEvent(self, event):
        if self._pwp:
            self._pwp.close()

        self.save_current()
        self.closed.emit(self.saved_data)

        super().closeEvent(event)

    def hideEvent(self, event):
        """Save state when popup is hidden (navigating away)."""
        self.save_current()
        super().hideEvent(event)
