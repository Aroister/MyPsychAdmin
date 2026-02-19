from __future__ import annotations

from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import (
    QWidget, QLabel, QPushButton,
    QVBoxLayout, QHBoxLayout,
    QScrollArea, QFrame,
    QRadioButton, QCheckBox, QSlider
)
from PySide6.QtWidgets import QGraphicsDropShadowEffect
from PySide6.QtGui import QColor
from PySide6.QtCore import QPropertyAnimation, QEasingCurve
from PySide6.QtWidgets import QSizePolicy
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

def pronouns_from_gender(g):
    g = (g or "").lower().strip()

    if g == "male":
        return {
            "subj": "he",
            "obj": "him",
            "pos": "his",
            "be": "is",
            "have": "has",
            "do": "does",
        }

    if g == "female":
        return {
            "subj": "she",
            "obj": "her",
            "pos": "her",
            "be": "is",
            "have": "has",
            "do": "does",
        }

    # singular they
    return {
        "subj": "they",
        "obj": "them",
        "pos": "their",
        "be": "are",
        "have": "have",
        "do": "do",
    }

# ============================================================
#  CANONICAL OPTIONS
# ============================================================

HOUSING_TYPES = [
    "homeless",
    "house",
    "flat",
]

HOUSING_QUALIFIERS = [
    "private",
    "council",
    "own",
    "family",
    "temporary",
]

BENEFITS_OPTIONS = [
    "Section 117 aftercare",
    "ESA",
    "PIP",
    "Universal Credit",
    "DLA",
    "Pension",
    "Income Support",
    "Child Tax Credit",
    "Child Benefit",
]

BENEFITS_NONE = "did not wish to discuss benefits"

DEBT_SCALE = [
    "did not wish to discuss finances",
    "is not in significant debt",
    "has previously been in significant debt but is not currently",
    "is in debt but managing this",
    "is in significant debt and struggling",
]
DEBT_SEVERITY = [
    "no significant debt",
    "some small debt",
    "some moderate debt",
    "significant debt",
    "severely in debt",
]

DEBT_MANAGEMENT_OPTIONS = [
    "did not want to discuss finances",
    "yes and is managing",
    "yes and is not managing",
]


# ============================================================
#  UI HELPERS
# ============================================================

def section_title(text: str) -> QWidget:
        w = QWidget()
        lay = QVBoxLayout(w)
        lay.setContentsMargins(0, 0, 0, 0)
        lay.setSpacing(4)

        lbl = QLabel(text)
        lbl.setStyleSheet("""
            font-size: 21px;
            font-weight: 700;
            color: #0f5132;
            border: none;
        """)

        line = QFrame()
        line.setFrameShape(QFrame.HLine)
        line.setStyleSheet("color: rgba(0,0,0,0.18);")

        lay.addWidget(lbl)
        lay.addWidget(line)
        return w


def soft_panel(widget: QWidget) -> QFrame:
        frame = QFrame()
        frame.setStyleSheet("""
                QFrame {
                        background: transparent;
                        border-radius: 10px;
                }
        """)
        lay = QVBoxLayout(frame)
        lay.setContentsMargins(12, 8, 12, 8)
        lay.addWidget(widget)
        return frame




def radio_group(options, on_change):
    box = QWidget()
    lay = QVBoxLayout(box)
    lay.setSpacing(6)
    buttons = []

    for opt in options:
        rb = QRadioButton(opt.capitalize())
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
            lambda checked, v=opt: checked and on_change(v)
        )
        lay.addWidget(rb)
        buttons.append(rb)

    return box, buttons

def section_divider():
    line = QFrame()
    line.setFrameShape(QFrame.HLine)
    line.setFrameShadow(QFrame.Plain)
    line.setFixedHeight(1)
    line.setStyleSheet("""
        QFrame {
            background: rgba(0, 0, 0, 0.24);
            margin-top: 10px;
            margin-bottom: 16px;
        }
    """)
    return line

    
class AnimatedDivider(QFrame):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setMaximumHeight(0)
        self.setMinimumHeight(0)

        self.setStyleSheet("""
            QFrame {
                background: rgba(0, 0, 0, 0.28);
                margin-top: 10px;
                margin-bottom: 12px;
            }
        """)

        self._anim = QPropertyAnimation(self, b"maximumHeight")
        self._anim.setDuration(180)
        self._anim.setEasingCurve(QEasingCurve.OutCubic)

    def reveal(self):
        self._anim.stop()
        self._anim.setStartValue(self.maximumHeight())
        self._anim.setEndValue(1)
        self._anim.start()

    def hide_divider(self):
        self._anim.stop()
        self._anim.setStartValue(self.maximumHeight())
        self._anim.setEndValue(0)
        self._anim.start()
        



# ============================================================
#  SOCIAL HISTORY POPUP
# ============================================================

class SocialHistoryPopup(QWidget):
    sent = Signal(str, dict)
    closed = Signal(dict)

    def update_gender(self, gender: str):
        """Update pronouns when gender changes on front page."""
        self.p = pronouns_from_gender(gender)
        self._update_preview()

    def __init__(self, first_name=None, gender=None, parent=None):
        super().__init__(parent)
        self.setStyleSheet("""
            QWidget {
                background: transparent;
            }
        """)

        self.p = pronouns_from_gender(gender)

        # Window behaviour — fixed panel
        self.setWindowFlags(Qt.WindowType.Widget)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)

        # --------------------------------------------------
        # STATE (single source of truth)
        # --------------------------------------------------
        self.state = {
            "housing": {
                "type": None,
                "qualifier": None,
            },
            "benefits": {
                "none": False,
                "items": set(),
            },
            "debt": {
                "status": None,        # "none" | "not_in_debt" | "in_debt"
                "severity_idx": 0,     # index into DEBT_SEVERITY
                "managing": None,      # "managing" | "not_managing"
            },
        }

        # --------------------------------------------------
        # ROOT
        # --------------------------------------------------
        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(8)

        # ========================================================
        # SCROLLABLE CONTENT
        # ========================================================
        card = QFrame()
        card.setStyleSheet("""
            QFrame {
                background: #ffffff;
                border-radius: 12px;
                border: 1px solid rgba(0,0,0,0.15);
            }
            QLabel {
                background: transparent;
                border: none;
            }
        """)
        root.addWidget(card, 1)

        layout = QVBoxLayout(card)
        layout.setContentsMargins(12, 12, 12, 12)
        layout.setSpacing(12)

        # ===================== SCROLL AREA =====================
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        scroll.setStyleSheet("""
            QScrollArea {
                background: transparent;
                border: none;
            }
            QScrollArea::viewport {
                background: transparent;
                border: none;
            }
        """)

        # ---------------------
        # Scroll content (single styled container)
        # ---------------------
        scroll_content = QWidget()
        scroll_content.setObjectName("ScrollSurface")
        scroll_content.setAutoFillBackground(False)

        scroll_content.setStyleSheet("""
            QWidget {
                background: transparent;
            }

            #ScrollSurface {
                background: rgba(0, 0, 0, 0.04);
                border-radius: 12px;
            }
        """)

        body_lay = QVBoxLayout(scroll_content)
        body_lay.setSpacing(18)
        body_lay.setContentsMargins(16, 16, 16, 16)

        scroll.setWidget(scroll_content)
        layout.addWidget(scroll)


        # ===================== HOUSING =====================
        body_lay.addWidget(section_title("Housing"))
        body_lay.addWidget(section_divider())


        # --- Housing type (single row) ---
        housing_box, self.housing_type_buttons = radio_group(
                HOUSING_TYPES,
                self._set_housing_type
        )

        housing_row = QWidget()
        housing_row_lay = QHBoxLayout(housing_row)
        housing_row_lay.setContentsMargins(0, 0, 0, 0)
        housing_row_lay.setSpacing(20)

        for rb in self.housing_type_buttons:
                housing_row_lay.addWidget(rb)

        housing_row_lay.addStretch()
        body_lay.addWidget(housing_row)
        self.housing_divider = AnimatedDivider()
        body_lay.addWidget(self.housing_divider)
        
        # --- Qualifiers (house / flat only) ---
        self.qualifier_box, self.housing_qual_buttons = radio_group(
                HOUSING_QUALIFIERS,
                self._set_housing_qualifier
        )

        qualifier_row = QWidget()
        qualifier_row_lay = QHBoxLayout(qualifier_row)
        qualifier_row_lay.setContentsMargins(0, 0, 0, 0)
        qualifier_row_lay.setSpacing(20)

        for rb in self.housing_qual_buttons:
                qualifier_row_lay.addWidget(rb)

        qualifier_row_lay.addStretch()

        self.qualifier_panel = qualifier_row
        self.qualifier_panel.setVisible(False)
        body_lay.addWidget(self.qualifier_panel)


        # ===================== BENEFITS =====================
        body_lay.addWidget(section_title("Benefits"))
        body_lay.addWidget(section_divider())

        ben_box = QWidget()
        ben_outer = QVBoxLayout(ben_box)
        ben_outer.setSpacing(6)
        ben_outer.setContentsMargins(4, 2, 4, 2)

        self.benefit_checks = {}

        # 2-column grid layout for benefits
        from PySide6.QtWidgets import QGridLayout
        ben_grid = QGridLayout()
        ben_grid.setSpacing(6)
        ben_grid.setContentsMargins(0, 0, 0, 0)

        all_benefits = [
                "Section 117 aftercare",
                "ESA",
                "PIP",
                "Universal Credit",
                "DLA",
                "Pension",
                "Income Support",
                "Child Tax Credit",
                "Child Benefit",
        ]

        for i, b in enumerate(all_benefits):
                cb = QCheckBox(b)
                cb.setStyleSheet("font-size:22px;")
                cb.toggled.connect(
                        lambda checked, v=b: self._toggle_benefit(v, checked)
                )
                self.benefit_checks[b] = cb
                row = i // 2
                col = i % 2
                ben_grid.addWidget(cb, row, col)

        ben_outer.addLayout(ben_grid)

        # --- NONE (exclusive) ---
        self.benefits_none = QCheckBox(BENEFITS_NONE)
        self.benefits_none.setStyleSheet("font-size:22px;")
        self.benefits_none.toggled.connect(self._toggle_benefits_none)
        ben_outer.addWidget(self.benefits_none)

        body_lay.addWidget(ben_box)


        # ===================== DEBT =====================
        body_lay.addWidget(section_title("Debt"))
        body_lay.addWidget(section_divider())

        # --- Top-level status radios (vertical layout) ---
        debt_status_box = QWidget()
        debt_status_lay = QVBoxLayout(debt_status_box)
        debt_status_lay.setSpacing(6)
        debt_status_lay.setContentsMargins(0, 0, 0, 0)

        self.debt_status_buttons = {}

        for label, value in (
                ("Did not want to discuss", "none"),
                ("No, not in debt", "not_in_debt"),
                ("Yes, in debt", "in_debt"),
        ):
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
                rb.toggled.connect(
                        lambda checked, v=value: checked and self._set_debt_status(v)
                )
                self.debt_status_buttons[value] = rb
                debt_status_lay.addWidget(rb)

        body_lay.addWidget(debt_status_box)
        self.debt_divider = AnimatedDivider()
        body_lay.addWidget(self.debt_divider)
        
        # --- Severity slider (hidden by default) ---
        label = QLabel("Debt severity")
        label.setStyleSheet("font-size: 21px; color: #666;")
        self.debt_slider = NoWheelSlider(Qt.Horizontal)
        self.debt_slider.setRange(0, len(DEBT_SEVERITY) - 1)
        self.debt_slider.valueChanged.connect(self._set_debt_severity)

        self.debt_slider_panel = soft_panel(self.debt_slider)
        self.debt_slider_panel.setStyleSheet("""
            QFrame {
                border: 1px solid rgba(13,148,136,0.35);
            }
        """)
        # 🔑 Prevent collapse during scroll
        self.debt_slider_panel.setSizePolicy(
            QSizePolicy.Expanding,
            QSizePolicy.Fixed
        )

        # 🔑 Start collapsed (DO NOT use setFixedHeight)
        self.debt_slider_panel.setMaximumHeight(0)
        self.debt_slider_panel.setMinimumHeight(0)
        self.debt_slider_panel.setVisible(False)





        # --- Managing radios (hidden by default) ---
        manage_box = QWidget()
        manage_lay = QVBoxLayout(manage_box)
        manage_lay.setSpacing(6)
        manage_lay.setContentsMargins(0, 0, 0, 0)

        self.debt_manage_buttons = {}

        for label, value in (
                ("Is managing", "managing"),
                ("Is not managing", "not_managing"),
        ):
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
                rb.toggled.connect(
                        lambda checked, v=value: checked and self._set_debt_managing(v)
                )
                self.debt_manage_buttons[value] = rb
                manage_lay.addWidget(rb)

        self.debt_manage_panel = soft_panel(manage_box)
        self.debt_manage_panel.setVisible(False)
        body_lay.addWidget(self.debt_manage_panel)


        divider = QFrame()
        divider.setFrameShape(QFrame.HLine)
        divider.setStyleSheet("""
                QFrame {
                        background: rgba(0,0,0,0.15);
                        margin-top: 12px;
                        margin-bottom: 12px;
                }
        """)
        layout.addWidget(divider)

        # ===================== FIXED SLIDER SLOT =====================
        self.debt_slider_slot = QWidget()
        self.debt_slider_slot.setVisible(False)

        slot_lay = QVBoxLayout(self.debt_slider_slot)
        slot_lay.setContentsMargins(0, 8, 0, 0)
        slot_lay.setSpacing(6)

        # --- Label ---
        label = QLabel("Debt severity")
        label.setStyleSheet("font-size: 21px; color: #666;")
        slot_lay.addWidget(label)

        # --- Slider ---
        self.debt_slider = NoWheelSlider(Qt.Horizontal)
        self.debt_slider.setRange(0, len(DEBT_SEVERITY) - 1)
        self.debt_slider.valueChanged.connect(self._set_debt_severity)

        self.debt_slider_panel = soft_panel(self.debt_slider)
        self.debt_slider_panel.setStyleSheet("""
            QFrame {
                border: 1px solid rgba(13,148,136,0.35);
                border-radius: 8px;
            }
        """)
        self.debt_slider_panel.setSizePolicy(
            QSizePolicy.Expanding,
            QSizePolicy.Fixed
        )
        slot_lay.addWidget(self.debt_slider_panel)

        layout.addWidget(self.debt_slider_slot)

        # Add lock functionality
        add_lock_to_popup(self, show_button=False)

    # ============================================================
    #  ANIMATION HANDLER
    # ============================================================

    def _fade_panel(self, panel: QWidget, show: bool, expanded_height: int):
        anim = getattr(panel, "_height_anim", None)
        if anim is None:
            anim = QPropertyAnimation(panel, b"maximumHeight", panel)
            anim.setDuration(180)
            anim.setEasingCurve(QEasingCurve.OutCubic)
            panel._height_anim = anim

        anim.stop()

        if show:
            panel.setVisible(True)
            anim.setStartValue(panel.maximumHeight())
            anim.setEndValue(expanded_height)
        else:
            anim.setStartValue(panel.maximumHeight())
            anim.setEndValue(0)

        anim.start()



    # ============================================================
    #  STATE HANDLERS
    # ============================================================

    #  HOUSING-----------------------------------------------------
    def _set_housing_type(self, value):
        self.state["housing"]["type"] = value

        show = value in ("house", "flat")

        if show:
            self.qualifier_panel.setVisible(True)
            self.housing_divider.reveal()
        else:
            self.qualifier_panel.setVisible(False)
            self.housing_divider.hide_divider()
            self.state["housing"]["qualifier"] = None

        self._update_preview()


    def _set_housing_qualifier(self, value):
        self.state["housing"]["qualifier"] = value
        self._update_preview()
        
    #  BENEFITS-----------------------------------------------------
    def _toggle_benefit(self, benefit, checked):
        if self.state["benefits"]["none"]:
            return

        if checked:
            self.state["benefits"]["items"].add(benefit)
        else:
            self.state["benefits"]["items"].discard(benefit)

        self._update_preview()

    def _toggle_benefits_none(self, checked):
        self.state["benefits"]["none"] = checked

        if checked:
            self.state["benefits"]["items"].clear()
            for cb in self.benefit_checks.values():
                cb.setChecked(False)
                cb.setEnabled(False)
        else:
            for cb in self.benefit_checks.values():
                cb.setEnabled(True)

        self._update_preview()


    #  DEBT -----------------------------------------------------


    def _set_debt_status(self, value):
        debt = self.state["debt"]
        debt["status"] = value

        is_in_debt = value == "in_debt"

        if is_in_debt:
            self.debt_divider.reveal()
            self.debt_slider_slot.setVisible(True)
            self._fade_panel(self.debt_slider_panel, True, 48)
            self._fade_panel(self.debt_manage_panel, True, 48)
        else:
            self.debt_divider.hide_divider()
            self._fade_panel(self.debt_slider_panel, False, 0)
            self._fade_panel(self.debt_manage_panel, False, 0)
            self.debt_slider_slot.setVisible(False)
            debt["severity_idx"] = 0
            debt["managing"] = None

        self._update_preview()

    def _set_debt_severity(self, idx):
            self.state["debt"]["severity_idx"] = idx
            self._update_preview()


    def _set_debt_managing(self, value):
            self.state["debt"]["managing"] = value
            self._update_preview()


    # ============================================================
    #  TEXT GENERATION
    # ============================================================

    def formatted_text(self) -> str:
        s = self.p["subj"].capitalize()
        be = self.p["be"]
        have = self.p["have"]
        pos = self.p["pos"]

        out = []


        # ---------------- Housing ----------------
        h = self.state["housing"]

        if h["type"] == "homeless":
            out.append(f"{s} {be} currently homeless.")

        elif h["type"]:
            if h["qualifier"]:
                if h["qualifier"] == "own":
                    out.append(f"{s} {be} living in {pos} own {h['type']}.")
                elif h["qualifier"] == "private":
                    out.append(f"{s} {be} living in a privately rented {h['type']}.")
                elif h["qualifier"] == "temporary":
                    out.append(f"{s} {be} living in a {h['type']} which is temporary accommodation.")
                else:
                    out.append(f"{s} {be} living in a {h['qualifier']} {h['type']}.")
            else:
                out.append(f"{s} {be} living in a {h['type']}.")

        # ---------------- Benefits ----------------
        ben = self.state["benefits"]

        if ben["none"]:
            out.append(f"{s} did not wish to discuss benefits.")

        elif ben["items"]:
            items = sorted(ben["items"])
            if len(items) == 1:
                out.append(f"{s} {have} access to {items[0]}.")
            else:
                joined = ", ".join(items[:-1]) + f", and {items[-1]}"
                out.append(f"{s} {have} access to {joined}.")

        # ---------------- Debt ----------------
        debt = self.state.get("debt", {})
        status = debt.get("status")

        if status == "none":
            out.append(f"{s} did not wish to discuss financial matters.")

        elif status == "not_in_debt":
            out.append(f"{s} {be} not currently in debt.")

        elif status == "in_debt":
            sev = DEBT_SEVERITY[debt.get("severity_idx", 0)]
            managing = debt.get("managing")

            # Use "is" for phrases like "severely in debt", "has" for "some debt"
            debt_verb = be if "in debt" in sev else have

            if managing == "managing":
                out.append(f"{s} {debt_verb} {sev} and {be} managing this.")
            elif managing == "not_managing":
                out.append(f"{s} {debt_verb} {sev} and {be} not managing this.")
            else:
                out.append(f"{s} {debt_verb} {sev}.")

        return " ".join(out)


    # ============================================================
    #  PREVIEW / EMIT / PERSIST
    # ============================================================

    def _update_preview(self):
        """Legacy method name - now sends to card immediately."""
        self._send_to_card()

    def _send_to_card(self):
        """Send current text to card immediately."""
        import copy
        text = self.formatted_text() or ""
        text = text.strip()
        state = copy.deepcopy(self.state)
        if text:
            self.sent.emit(text, state)

    def closeEvent(self, event):
        import copy
        self.closed.emit(copy.deepcopy(self.state))
        super().closeEvent(event)

    def hideEvent(self, event):
        """Save state when popup is hidden (navigating away)."""
        import copy
        self.closed.emit(copy.deepcopy(self.state))
        super().hideEvent(event)


    def _emit(self):
        import copy

        text = self.formatted_text() or ""
        text = text.strip()

        state = copy.deepcopy(self.state)

        if text:
            self.sent.emit(text, state)

        self.close()

    def load_state(self, state: dict):
        if not isinstance(state, dict):
            return

        # 🔑 Replace state wholesale (single source of truth)
        self.state = {
            "housing": state.get(
                "housing",
                {
                    "type": None,
                    "qualifier": None,
                }
            ).copy(),

            "benefits": {
                "none": state.get("benefits", {}).get("none", False),
                "items": set(state.get("benefits", {}).get("items", [])),
            },

            "debt": {
                "status": state.get("debt", {}).get("status"),
                "severity_idx": state.get("debt", {}).get("severity_idx", 0),
                "managing": state.get("debt", {}).get("managing"),
            },
        }

        # ---------------- Housing (restore) ----------------
        h = self.state["housing"]

        # housing type
        for rb in self.housing_type_buttons:
            rb.setChecked(
                rb.text().lower() == (h["type"] or "")
            )

        show_qualifier = h["type"] in ("house", "flat")
        self.qualifier_panel.setVisible(show_qualifier)

        # qualifier
        for rb in self.housing_qual_buttons:
            rb.setChecked(
                rb.text().lower() == (h["qualifier"] or "")
            )

        # ---------------- Benefits ----------------
        self.benefits_none.setChecked(self.state["benefits"]["none"])

        for b, cb in self.benefit_checks.items():
            cb.setChecked(b in self.state["benefits"]["items"])
            cb.setEnabled(not self.state["benefits"]["none"])

        # ---------------- Debt ----------------
        debt = self.state["debt"]

        status = debt.get("status")
        if status:
            rb = self.debt_status_buttons.get(status)
            if rb:
                rb.setChecked(True)

        # Visibility follows status
        is_in_debt = status == "in_debt"
        self.debt_slider_panel.setMaximumHeight(56 if is_in_debt else 0)
        self.debt_manage_panel.setMaximumHeight(48 if is_in_debt else 0)


        self.debt_slider.setValue(debt.get("severity_idx", 0))

        managing = debt.get("managing")
        if managing:
            rb = self.debt_manage_buttons.get(managing)
            if rb:
                rb.setChecked(True)

        if h["type"] in ("house", "flat"):
                self.housing_divider.setMaximumHeight(1)
        else:
                self.housing_divider.setMaximumHeight(0)

        if debt.get("status") == "in_debt":
                self.debt_divider.setMaximumHeight(1)
        else:
                self.debt_divider.setMaximumHeight(0)

        self._update_preview()
