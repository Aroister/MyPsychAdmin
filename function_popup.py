from __future__ import annotations
from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import (
    QWidget, QLabel, QPushButton,
    QVBoxLayout, QHBoxLayout,
    QScrollArea, QFrame, QCheckBox, QSlider, QSizePolicy, QRadioButton  # Added QRadioButton import
)
from PySide6.QtWidgets import QGraphicsDropShadowEffect
from PySide6.QtGui import QColor
from shared_widgets import add_lock_to_popup
from spell_check_textedit import enable_spell_check_on_textedit
# ============================================================
# NO-WHEEL SLIDER (prevents scroll from changing value)
# ============================================================
class NoWheelSlider(QSlider):
    def wheelEvent(self, event):
        event.ignore()


# ============================================================
# SECTION DIVIDER FUNCTION
# ============================================================
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

# ============================================================
# PRONOUN ENGINE (Shared Logic)
# ============================================================
def pronouns_from_gender(g):
    g = (g or "").lower().strip()
    if g == "male":
        return {"subj": "he", "obj": "him", "pos": "his", "be": "is", "have": "has", "do": "does"}
    if g == "female":
        return {"subj": "she", "obj": "her", "pos": "her", "be": "is", "have": "has", "do": "does"}
    return {"subj": "they", "obj": "them", "pos": "their", "be": "are", "have": "have", "do": "do"}

# ============================================================
# UI HELPERS
# ============================================================
def section_title(text: str) -> QWidget:
    w = QWidget()
    lay = QVBoxLayout(w)
    lay.setContentsMargins(0, 0, 0, 0)
    lay.setSpacing(4)
    lbl = QLabel(text)
    lbl.setStyleSheet(""" font-size: 21px; font-weight: 700; color: #0f5132; border: none; """)
    line = QFrame()
    line.setFrameShape(QFrame.HLine)
    line.setStyleSheet("color: rgba(0,0,0,0.18);")
    lay.addWidget(lbl)
    lay.addWidget(line)
    return w

def soft_panel(widget: QWidget) -> QFrame:
    frame = QFrame()
    frame.setStyleSheet(""" QFrame { background: transparent; border-radius: 10px; } """)
    lay = QVBoxLayout(frame)
    lay.setContentsMargins(12, 8, 12, 8)
    lay.addWidget(widget)
    return frame

# ============================================================
# FUNCTION POPUP
# ============================================================


class FunctionPopup(QWidget):
    sent = Signal(str, dict)
    closed = Signal(dict)

    def update_gender(self, gender: str):
        """Update pronouns when gender changes on front page."""
        self.p = pronouns_from_gender(gender)
        self._update_preview()

    def __init__(self, first_name=None, gender=None, parent=None):
        super().__init__(parent)
        self._hydrating = False

        # Window behaviour — fixed panel
        self.setWindowFlags(Qt.WindowType.Widget)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)

        # --------------------------------------------------
        # WIDGET REGISTRIES (MUST EXIST BEFORE post_init)
        # --------------------------------------------------
        self.self_care_widgets = {}
        self.relationship_widgets = {}
        self.travel_widgets = {}

        self.p = pronouns_from_gender(gender)
        self.setStyleSheet(""" QWidget { background: transparent; } """)



        
        # --------------------------------------------------
        # STATE (single source of truth)
        # --------------------------------------------------
        self.state = {
            "self_care": {
                "personal care": None,
                "home care": None,
                "children": None,
                "pets": None
            },
            "relationships": {
                "intimate": None,
                "birth family": None,
                "friends": None
            },
            "work": {
                "none": None,
                "some": None,
                "part_time": None,
                "full_time": None
            },
            "travel": {
                "trains": None,
                "buses": None,
                "cars": None
            }
        }

        self.VALID_SELF_CARE_KEYS = {
            "personal care",
            "home care",
            "children",
            "pets",
        }
        self.build_ui()
        self.post_init()

        add_lock_to_popup(self, show_button=False)


    def _apply_self_care_state_to_widgets(self):
        self_care_state = self.state.get("self_care", {})

        for key, widgets in self.self_care_widgets.items():
            checkbox = widgets["checkbox"]
            slider = widgets["slider"]

            value = self_care_state.get(key)

            checkbox.blockSignals(True)
            slider.blockSignals(True)

            if value:
                checkbox.setChecked(True)
                slider.setEnabled(True)
                slider.setMaximumHeight(24)
                slider.setValue(self._get_slider_value_from_level(value))
            else:
                checkbox.setChecked(False)
                slider.setEnabled(False)
                slider.setMaximumHeight(0)
                slider.setValue(0)

            checkbox.blockSignals(False)
            slider.blockSignals(False)


    def _apply_relationships_state_to_widgets(self):
        relationship_state = self.state.get("relationships", {})

        for key, widgets in self.relationship_widgets.items():
            checkbox = widgets["checkbox"]
            slider = widgets["slider"]

            value = relationship_state.get(key)

            checkbox.blockSignals(True)
            slider.blockSignals(True)

            if value:
                checkbox.setChecked(True)
                slider.setEnabled(True)
                slider.setMaximumHeight(24)
                slider.setValue(self._get_slider_value_from_level(value))
            else:
                checkbox.setChecked(False)
                slider.setEnabled(False)
                slider.setMaximumHeight(0)
                slider.setValue(0)

            checkbox.blockSignals(False)
            slider.blockSignals(False)



    def _apply_travel_state_to_widgets(self):
        travel_state = self.state.get("travel", {})

        for key, widgets in self.travel_widgets.items():
            checkbox = widgets["checkbox"]
            slider = widgets["slider"]

            value = travel_state.get(key)

            checkbox.blockSignals(True)
            slider.blockSignals(True)

            if value:
                checkbox.setChecked(True)
                slider.setEnabled(True)
                slider.setMaximumHeight(24)
                slider.setValue(self._get_slider_value_from_level(value))
            else:
                checkbox.setChecked(False)
                slider.setEnabled(False)
                slider.setMaximumHeight(0)
                slider.setValue(0)

            checkbox.blockSignals(False)
            slider.blockSignals(False)

    def _apply_work_state_to_widgets(self):
        """Apply work state to radio buttons."""
        if not hasattr(self, 'work_radios'):
            return

        work_state = self.state.get("work", {})

        for key, radio in self.work_radios.items():
            radio.blockSignals(True)
            radio.setChecked(bool(work_state.get(key)))
            radio.blockSignals(False)




        
    # ===================== ADD SECTIONS =====================
    def _add_section(self, title, method, layout):
        section = section_title(title)
        layout.addWidget(section)
        layout.addWidget(section_divider())
        method(layout)

    # ===================== SELF CARE SECTION =====================
    def _self_care_section(self, layout):
        # Checkboxes for different self-care categories
        self._add_checkboxes(layout, ["personal care", "home care", "children", "pets"], self._set_self_care)

    # ===================== RELATIONSHIPS SECTION =====================
    def _relationships_section(self, layout):
        # Checkboxes for relationships categories
        self._add_checkboxes(layout, ["intimate", "birth family", "friends"], self._set_relationships)

    # ===================== WORK SECTION =====================
    def _work_section(self, layout):
        # Use radio buttons for work status
        self._add_radio_buttons(layout, ["No work", "Some work", "Part-time work", "Full-time work"], self._set_work)

    # ===================== TRAVEL SECTION =====================
    def _travel_section(self, layout):
        # Checkboxes for travel categories
        self._add_checkboxes(layout, ["trains", "buses", "cars"], self._set_travel)

    def _add_checkboxes(self, layout, options, on_change):
        for opt in options:
            checkbox = QCheckBox(opt)
            checkbox.setStyleSheet("font-size:22px;")
            slider = NoWheelSlider(Qt.Horizontal)

            slider.setRange(0, 100)
            slider.setValue(0)
            slider.setMaximumHeight(0)
            slider.setEnabled(False)

            checkbox.toggled.connect(
                lambda checked, v=opt, s=slider: self._toggle_slider(
                    checked, v, on_change, s
                )
            )

            slider.valueChanged.connect(
                lambda _=None, v=opt, s=slider: on_change(v, s)
            )

            layout.addWidget(checkbox)
            layout.addWidget(slider)

            if on_change == self._set_self_care:
                self.self_care_widgets[opt] = {
                    "checkbox": checkbox,
                    "slider": slider,
                }

            elif on_change == self._set_relationships:
                self.relationship_widgets[opt] = {
                    "checkbox": checkbox,
                    "slider": slider,
                }

            elif on_change == self._set_travel:
                self.travel_widgets[opt] = {
                    "checkbox": checkbox,
                    "slider": slider,
                }


                



    def _add_radio_buttons(self, layout, options, on_change):
        box = QWidget()
        lay = QVBoxLayout(box)
        lay.setSpacing(6)
        self.work_radios = {}  # Store references to work radio buttons
        for opt in options:
            radio_button = QRadioButton(opt.capitalize())
            radio_button.setStyleSheet("""
                QRadioButton {
                    font-size: 22px;
                    background: transparent;
                }
                QRadioButton::indicator {
                    width: 18px;
                    height: 18px;
                }
            """)
            radio_button.toggled.connect(lambda checked, v=opt: self._set_work(v, checked))
            lay.addWidget(radio_button)
            # Map state keys to radio buttons
            key_map = {
                "no work": "none",
                "some work": "some",
                "part-time work": "part_time",
                "full-time work": "full_time",
            }
            state_key = key_map.get(opt.lower())
            if state_key:
                self.work_radios[state_key] = radio_button
        layout.addWidget(box)





    # =====================  HANDLERS =====================
    def _set_self_care(self, value, slider_or_checked):
        if getattr(self, "_hydrating", False):
            return

        print(f"Setting self-care: {value}, {slider_or_checked}")

        current_state = self.state["self_care"].get(value)
        new_value = None

        # -------------------------
        # Checkbox toggled
        # -------------------------
        if isinstance(slider_or_checked, bool):
            new_value = "slight" if slider_or_checked else None

        # -------------------------
        # Slider moved
        # -------------------------
        elif isinstance(slider_or_checked, QSlider):
            new_value = self._get_level_from_slider(slider_or_checked.value())
            print(
                f"Slider value for {value}: {slider_or_checked.value()} "
                f"-> Mapped severity: {new_value}"
            )

        # -------------------------
        # Apply change only if needed
        # -------------------------
        if new_value != current_state:
            self.state["self_care"][value] = new_value
            print(f"Updated self_care state: {self.state['self_care']}")
            self._update_preview()
        else:
            print(
                f"No change in self-care state for {value}. "
                f"Current state: {current_state}, New value: {new_value}"
            )

    def _set_relationships(self, value, slider_or_checked):
        if getattr(self, "_hydrating", False):
            return

        print(f"Setting relationships: {value}, {slider_or_checked}")

        current_state = self.state["relationships"].get(value)
        new_value = None

        # -------------------------
        # Checkbox toggled
        # -------------------------
        if isinstance(slider_or_checked, bool):
            new_value = "slight" if slider_or_checked else None

        # -------------------------
        # Slider moved
        # -------------------------
        elif isinstance(slider_or_checked, QSlider):
            new_value = self._get_level_from_slider(slider_or_checked.value())
            print(
                f"Slider value for {value}: {slider_or_checked.value()} "
                f"-> Mapped severity: {new_value}"
            )

        # -------------------------
        # Apply change only if needed
        # -------------------------
        if new_value != current_state:
            self.state["relationships"][value] = new_value
            print(f"Updated relationships state: {self.state['relationships']}")
            self._update_preview()
        else:
            print(
                f"No change in relationships state for {value}. "
                f"Current state: {current_state}, New value: {new_value}"
            )

            
    def _set_travel(self, value, slider_or_checked):
        if getattr(self, "_hydrating", False):
            return

        print(f"Setting travel: {value}, {slider_or_checked}")

        current_state = self.state["travel"].get(value)
        new_value = None

        # -------------------------
        # Checkbox toggled
        # -------------------------
        if isinstance(slider_or_checked, bool):
            new_value = "slight" if slider_or_checked else None

        # -------------------------
        # Slider moved
        # -------------------------
        elif isinstance(slider_or_checked, QSlider):
            new_value = self._get_level_from_slider(slider_or_checked.value())
            print(
                f"Slider value for {value}: {slider_or_checked.value()} "
                f"-> Mapped severity: {new_value}"
            )

        # -------------------------
        # Apply change only if needed
        # -------------------------
        if new_value != current_state:
            self.state["travel"][value] = new_value
            print(f"Updated travel state: {self.state['travel']}")
            self._update_preview()
        else:
            print(
                f"No change in travel state for {value}. "
                f"Current state: {current_state}, New value: {new_value}"
            )

    def _set_work(self, value, checked):
        if not checked:
            return
        key_map = {
            "no work": "none",
            "some work": "some",
            "part-time work": "part_time",
            "full-time work": "full_time",
        }
        value = value.strip().lower()
        if value not in key_map:
            return
        for k in self.state["work"]:
            self.state["work"][k] = False
        self.state["work"][key_map[value]] = True
        print(f"Updated work state: {self.state['work']}")  # Debugging
        self._update_preview()

    # ===================== GET LEVEL FROM SLIDER ==============================

    def _get_level_from_slider(self, slider_value):
        # Ensure proper mapping of slider values to severity levels
        if slider_value >= 80:
            return "severe"
        elif slider_value >= 60:
            return "significant"
        elif slider_value >= 40:
            return "moderate"
        elif slider_value >= 20:
            return "mild"
        else:
            return "slight"




    # ===================== TOGGLE ===============================
    def _toggle_slider(self, checked, value, on_change, slider):
        # Checkbox toggled → show / hide slider
        if checked:
            slider.setEnabled(True)
            slider.setMaximumHeight(24)
            on_change(value, True)
        else:
            slider.setEnabled(False)
            slider.setMaximumHeight(0)
            slider.setValue(0)
            on_change(value, False)



        
    # =====================  SEND TO CARD =====================
    def _update_preview(self):
        """Legacy method name - now sends to card immediately."""
        self._send_to_card()

    def _send_to_card(self):
        """Send current text to card immediately."""
        text = self.formatted_text()
        if text:
            self.sent.emit(text.strip(), {})

    # =====================  FORMAT TEXT=====================

    # =========================
    # FORMATTED TEXT METHOD
    # =========================
    def formatted_text(self) -> str:
        p = self.p
        lines = []

        # Helper to group items by severity
        def group_by_severity(items_dict):
            severity_order = ["severe", "significant", "moderate", "mild", "slight"]
            grouped = {s: [] for s in severity_order}
            for key, sev in items_dict.items():
                if sev:
                    grouped[sev].append(key)
            return grouped, severity_order

        # Helper to join items naturally
        def join_items(items):
            if len(items) == 1:
                return items[0]
            elif len(items) == 2:
                return f"{items[0]} and {items[1]}"
            else:
                return ", ".join(items[:-1]) + f" and {items[-1]}"

        # =========================
        # SELF CARE
        # =========================
        sc = {
            k: v
            for k, v in self.state.get("self_care", {}).items()
            if k in self.VALID_SELF_CARE_KEYS and v
        }

        has_self_care = bool(sc)

        if sc:
            grouped, severity_order = group_by_severity(sc)

            # Transform keys to natural phrases
            key_phrases = {
                "personal care": "personal care",
                "home care": "manage home care",
                "children": "look after {pos} children",
                "pets": "manage {pos} pets",
            }

            parts = []
            for sev in severity_order:
                items = grouped[sev]
                if not items:
                    continue

                phrases = []
                for item in items:
                    phrase = key_phrases.get(item, item)
                    phrase = phrase.replace("{pos}", p["pos"])
                    phrases.append(phrase)

                if sev in ("severe", "significant"):
                    # Primary impact
                    adverb = "severely" if sev == "severe" else "significantly"
                    parts.append((sev, adverb, phrases))
                else:
                    # Secondary impact
                    parts.append((sev, sev, phrases))

            if parts:
                # Build the sentence
                primary_parts = [(s, a, ph) for s, a, ph in parts if s in ("severe", "significant")]
                secondary_parts = [(s, a, ph) for s, a, ph in parts if s not in ("severe", "significant")]

                sentence = f"The illness affects {p['pos']} self-care on several levels"

                if primary_parts:
                    # Combine all primary items
                    all_primary = []
                    adverb = primary_parts[0][1]
                    for _, _, phrases in primary_parts:
                        all_primary.extend(phrases)
                    sentence += f", {adverb} affecting {p['pos']} ability to {join_items(all_primary)}"

                if secondary_parts:
                    for sev, _, phrases in secondary_parts:
                        impact_phrase = join_items(phrases)
                        sentence += f". There is also some {sev} impact on {impact_phrase}"

                sentence += "."
                lines.append(sentence)

        # =========================
        # RELATIONSHIPS
        # =========================
        rel = {k: v for k, v in self.state.get("relationships", {}).items() if v}
        has_relationships = bool(rel)

        if rel:
            grouped, severity_order = group_by_severity(rel)

            # Transform keys
            key_phrases = {
                "intimate": f"{p['pos']} intimate relationship",
                "birth family": f"{p['pos']} relations with {p['pos']} family of origin",
                "friends": "friendships",
            }

            # Build relationship parts ordered by severity
            rel_parts = []
            for sev in severity_order:
                items = grouped[sev]
                if not items:
                    continue
                for item in items:
                    phrase = key_phrases.get(item, item)
                    rel_parts.append((sev, phrase))

            if rel_parts:
                # Use "also" if self-care was mentioned
                intro = "The illness also has had an impact on" if has_self_care else "The illness has had an impact on"

                if len(rel_parts) == 1:
                    sev, phrase = rel_parts[0]
                    lines.append(f"{intro} {p['pos']} relationships with {phrase} {sev}ly affected.")
                else:
                    sentence = f"{intro} {p['pos']} relationships"

                    # First item (most severe)
                    sev, phrase = rel_parts[0]
                    sentence += f" with {phrase} {sev}ly affected"

                    # Middle items
                    for i, (sev, phrase) in enumerate(rel_parts[1:-1]):
                        sentence += f", {phrase} affected {sev}ly"

                    # Last item
                    if len(rel_parts) > 1:
                        sev, phrase = rel_parts[-1]
                        sentence += f" and some {sev} impact on {phrase}"

                    sentence += "."
                    lines.append(sentence)

        # =========================
        # WORK
        # =========================
        work = self.state.get("work", {})

        if work.get("none"):
            lines.append(f"Currently {p['subj']} {p['be']} not working.")
        elif work.get("some"):
            lines.append(f"Currently {p['subj']} {p['do']} work only occasionally.")
        elif work.get("part_time"):
            lines.append(f"Currently {p['subj']} {p['be']} working part time.")
        elif work.get("full_time"):
            lines.append(f"Currently {p['subj']} {p['be']} working full time with no occupational impairment.")

        has_work = any(work.values())

        # =========================
        # TRAVEL
        # =========================
        travel = {k: v for k, v in self.state.get("travel", {}).items() if v}

        if travel:
            grouped, severity_order = group_by_severity(travel)

            # Transform keys
            key_phrases = {
                "trains": "trains",
                "buses": "buses",
                "cars": "cars",
            }

            # Build travel parts ordered by severity
            travel_parts = []
            for sev in severity_order:
                items = grouped[sev]
                if not items:
                    continue
                for item in items:
                    travel_parts.append((sev, item))

            if travel_parts:
                # Determine intro based on whether other sections have content
                has_other_content = has_self_care or has_relationships or has_work
                intro = "In addition, travel is affected" if has_other_content else f"The illness affects {p['pos']} ability to travel"

                if len(travel_parts) == 1:
                    sev, mode = travel_parts[0]
                    lines.append(f"{intro} – {p['subj']} cannot travel on {mode} ({sev}).")
                else:
                    # Most severe first
                    sev, mode = travel_parts[0]
                    sentence = f"{intro} – most {sev}ly {p['subj']} cannot travel on {mode}"

                    # Remaining items
                    remaining = travel_parts[1:]
                    if remaining:
                        # Group remaining by severity
                        remaining_by_sev = {}
                        for s, m in remaining:
                            remaining_by_sev.setdefault(s, []).append(m)

                        remaining_phrases = []
                        for s, modes in remaining_by_sev.items():
                            modes_str = join_items(modes)
                            remaining_phrases.append(f"{s} impact on {p['pos']} ability to travel in {modes_str}")

                        if remaining_phrases:
                            sentence += " with " + join_items(remaining_phrases)

                    sentence += "."
                    lines.append(sentence)

        # =========================
        # FINAL OUTPUT
        # =========================
        return " ".join(lines)




    # ===================== RESTORING THE STATE =====================

    def load_state(self, saved_state):
        self._hydrating = True

        for section, values in saved_state.items():
            if section in self.state:
                self.state[section].update(values)

        self._apply_self_care_state_to_widgets()
        self._apply_relationships_state_to_widgets()
        self._apply_travel_state_to_widgets()
        self._apply_work_state_to_widgets()

        self._hydrating = False
        self._update_preview()


    def post_init(self):
        self._hydrating = True
        self._apply_self_care_state_to_widgets()
        self._apply_relationships_state_to_widgets()
        self._apply_travel_state_to_widgets()
        self._hydrating = False
        self._update_preview()


    def _get_slider_value_from_level(self, level: str) -> int:
        return {
            "slight": 20,
            "mild": 40,
            "moderate": 60,
            "significant": 80,
            "severe": 100,
        }.get(level, 0)



    def build_ui(self):
        # --------------------------------------------------
        # ROOT LAYOUT
        # --------------------------------------------------
        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(8)

        # ========================================================
        # SCROLLABLE CONTENT
        # ========================================================
        card = QFrame()
        card.setStyleSheet("""
            QFrame { background: #ffffff; border-radius: 12px; border: 1px solid rgba(0,0,0,0.15); }
            QLabel { background: transparent; border: none; }
        """)
        root.addWidget(card, 1)

        layout = QVBoxLayout(card)
        layout.setContentsMargins(12, 12, 12, 12)
        layout.setSpacing(12)

        # Scroll Area for Sections
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        scroll_content = QWidget()
        body_lay = QVBoxLayout(scroll_content)
        body_lay.setSpacing(18)
        body_lay.setContentsMargins(12, 12, 12, 12)

        scroll.setWidget(scroll_content)
        layout.addWidget(scroll)

        # Sections
        self._add_section("Self Care", self._self_care_section, body_lay)
        self._add_section("Relationships", self._relationships_section, body_lay)
        self._add_section("Work", self._work_section, body_lay)
        self._add_section("Travel", self._travel_section, body_lay)


# ===================== CLOSE=====================
    def closeEvent(self, event):
        self.hide()  # Hide the widget instead of closing it entirely
        event.accept()  # Accept the event to finish handling

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

