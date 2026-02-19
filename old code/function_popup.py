from __future__ import annotations
from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import (
    QWidget, QLabel, QPushButton,
    QVBoxLayout, QHBoxLayout,
    QScrollArea, QFrame, QCheckBox, QSlider, QSizePolicy, QRadioButton  # Added QRadioButton import
)
from PySide6.QtWidgets import QGraphicsDropShadowEffect
from PySide6.QtGui import QColor

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
    lbl.setStyleSheet(""" font-size: 18px; font-weight: 700; color: #0f5132; """)
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

    def __init__(self, first_name=None, gender=None, parent=None):
        super().__init__(parent)
        self.setStyleSheet(""" QWidget { background: transparent; } """)
        self.p = pronouns_from_gender(gender)
        self.setWindowFlags(Qt.FramelessWindowHint | Qt.SubWindow)
        self.setFixedSize(780, 700)

        # --------------------------------------------------
        # STATE (single source of truth)
        # --------------------------------------------------
        self.state = {
            "self_care": {"personal": None, "home": None, "children": None, "pets": None},
            "relationships": {"intimate": None, "birth family": None, "friends": None},
            "work": {"none": None, "some": None, "part_time": None, "full_time": None},
            "travel": {"trains": None, "buses": None, "cars": None}
        }

        # --------------------------------------------------
        # ROOT LAYOUT (Single Card, No Canvas)
        # --------------------------------------------------
        outer = QVBoxLayout(self)
        outer.setContentsMargins(24, 24, 24, 24)
        outer.setSpacing(0)
        card = QFrame()
        card.setStyleSheet(""" QFrame { background: #ffffff; border-radius: 16px; border: none; } """)
        outer.addWidget(card)
        layout = QVBoxLayout(card)
        layout.setContentsMargins(24, 24, 24, 24)
        layout.setSpacing(18)

        # Header Bar
        header = QHBoxLayout()
        header.setContentsMargins(0, 0, 0, 0)
        title = QLabel("Function History")
        title.setStyleSheet(""" font-size: 18px; font-weight: 700; color: #0f5132; """)
        close_btn = QPushButton("✕")
        close_btn.setFixedSize(32, 32)
        close_btn.setCursor(Qt.PointingHandCursor)
        close_btn.setStyleSheet(""" QPushButton { border: none; font-size: 18px; color: #555; } QPushButton:hover { color: #000; } """)
        close_btn.clicked.connect(self.close)
        header.addWidget(title)
        header.addStretch()
        header.addWidget(close_btn)
        layout.addLayout(header)

        # Scroll Area for Sections
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QFrame.NoFrame)

        scroll_content = QWidget()
        scroll_content.setObjectName("ScrollSurface")
        scroll_content.setAutoFillBackground(False)
        scroll_content.setStyleSheet(""" QWidget { background: transparent; } #ScrollSurface { background: rgba(0, 0, 0, 0.04); border-radius: 12px; } """)
        body_lay = QVBoxLayout(scroll_content)
        body_lay.setSpacing(18)
        body_lay.setContentsMargins(16, 16, 16, 16)
        scroll.setWidget(scroll_content)
        layout.addWidget(scroll)

        # Sections for Self Care, Relationships, Work, Travel
        self._add_section("Self Care", self._self_care_section, body_lay)
        self._add_section("Relationships", self._relationships_section, body_lay)
        self._add_section("Work", self._work_section, body_lay)
        self._add_section("Travel", self._travel_section, body_lay)

        # --------------------------------------------------
        # Preview Section (Scrollable and larger space)
        # --------------------------------------------------
        preview_scroll_area = QScrollArea()
        preview_scroll_area.setWidgetResizable(True)
        preview_scroll_area.setFrameShape(QFrame.NoFrame)

        # Create a container for the preview text
        preview_container = QWidget()
        preview_container.setStyleSheet("background: #1c1c1c; border-radius: 12px;")

        # Use the same self.preview for scrollable content (remove the first definition)
        self.preview = QLabel()
        self.preview.setWordWrap(True)
        self.preview.setStyleSheet(""" QLabel { color: #ffffff; padding: 16px; font-size: 14px; } """)
        self.preview.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)  # Make it expandable
        self.preview.setAlignment(Qt.AlignTop)  # Align text to the top of the area

        # Add preview label to container
        preview_layout = QVBoxLayout(preview_container)
        preview_layout.addWidget(self.preview)

        # Add the container to the scroll area
        preview_scroll_area.setWidget(preview_container)

        # Add the scroll area to the layout
        layout.addWidget(preview_scroll_area)

        # Send Button
        send = QPushButton("Send to Letter")
        send.setFixedHeight(44)
        send.setStyleSheet(""" QPushButton { background: #0d9488; color: white; font-size: 15px; font-weight: 600; border-radius: 10px; } QPushButton:hover { background: #0f766e; } QPushButton:pressed { background: #115e59; } """)
        send.clicked.connect(self._emit)
        layout.addWidget(send)
        self.VALID_SELF_CARE_KEYS = {
            "personal care",
            "home care",
            "children",
            "pets",
        }
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
        box = QWidget()
        lay = QVBoxLayout(box)
        lay.setSpacing(6)

        for opt in options:
            cb = QCheckBox(opt.capitalize())
            
            # Create slider associated with checkbox
            slider = QSlider(Qt.Horizontal)
            slider.setRange(0, 100)
            slider.setVisible(False)  # Initially set the slider to be hidden
            
            # Add the checkbox and slider to layout
            lay.addWidget(cb)
            lay.addWidget(slider)

            # Set slider visibility based on checkbox
            cb.toggled.connect(lambda checked, slider=slider: slider.setVisible(checked))  # Show the slider if checked, hide it if unchecked

            # Attach checkbox toggle to show/hide slider
            cb.toggled.connect(lambda checked, checkbox=cb, slider=slider, v=opt: self._toggle_slider(checked, v, on_change, slider))

            # Attach slider value change to the corresponding handler
            slider.valueChanged.connect(
                lambda _=None, v=opt, s=slider: on_change(v, s)
            )


        layout.addWidget(box)

    def _update_slider_state(self, value, slider_value):
        level = self._get_level_from_slider(slider_value)
        print(f"Slider value: {slider_value} -> Mapped severity level: {level}")  # Debugging
        
        # Update state with mapped severity level
        self.state["self_care"][value] = level
        self._update_preview()  # Refresh the preview to show updated value


    def _add_radio_buttons(self, layout, options, on_change):
        box = QWidget()
        lay = QVBoxLayout(box)
        lay.setSpacing(6)
        for opt in options:
            radio_button = QRadioButton(opt.capitalize())
            radio_button.toggled.connect(lambda checked, v=opt: self._set_work(v, checked))
            lay.addWidget(radio_button)
        layout.addWidget(box)





    # ===================== SELF CARE HANDLERS =====================
    def _set_self_care(self, value, slider_or_checked):
        print(f"Setting self-care: {value}, {slider_or_checked}")  # Debugging

        # Clear the corresponding relationships state for this field if it's part of relationships
        if value in ['intimate', 'birth family', 'friends']:  # These belong to relationships, not self-care
            self.state["relationships"][value] = None
            print(f"Clearing relationships state for {value}")

        # Track the previous value before the update
        current_state = self.state["self_care"].get(value)

        if isinstance(slider_or_checked, bool):  # Checkbox is toggled
            new_value = "slight" if slider_or_checked else None
            if current_state != new_value:  # Only update if the value is actually changing
                self.state["self_care"][value] = new_value
                print(f"Updated self_care state: {self.state['self_care']}")  # Debugging
                self._update_preview()  # Update the preview if there's a change
            else:
                print("No change in self-care state for checkbox.")  # Debugging if no change

        elif isinstance(slider_or_checked, QSlider):  # Slider is moved
            # Get the mapped severity level based on the slider value
            level = self._get_level_from_slider(slider_or_checked.value())
            
            # If the severity level is different, update the state and preview
            if current_state != level or current_state is None:  # Update even if it's None (initial state)
                self.state["self_care"][value] = level
                print(f"Slider value for {value}: {slider_or_checked.value()} -> Mapped severity: {level}")  # Debugging
                self._update_preview()  # Update the preview if there's a change
            else:
                print(f"No change in self-care state for {value}. Current state: {current_state}, New level: {level}")  # Debugging


    # ===================== RELATIONSHIP HANDLERS =====================

    def _set_relationships(self, value, slider_or_checked):
        print(f"Setting relationships: {value}, {slider_or_checked}")  # Debugging

        # Prevent unnecessary updates if the state hasn't changed
        current_state = self.state["relationships"].get(value)
        new_value = None

        if isinstance(slider_or_checked, bool):  # Checkbox is toggled
            new_value = slider_or_checked
        elif isinstance(slider_or_checked, QSlider):  # Slider is moved
            new_value = self._get_level_from_slider(slider_or_checked.value())

        # Only update if state has changed or is uninitialized
        if current_state != new_value or current_state is None:
            self.state["relationships"][value] = new_value
            print(f"Updated relationships state: {self.state['relationships']}")  # Debugging
            self._update_preview()  # Update preview after change
        else:
            print(f"No change in relationships state for {value}. Current state: {current_state}, New level: {new_value}")  # Debugging


    # ===================== TRAVEL HANDLERS =====================
    def _set_travel(self, value, slider_or_checked):
        current_state = self.state["travel"].get(value)
        if isinstance(slider_or_checked, bool):  # Checkbox is toggled
            # Handle checkbox state (True/False)
            new_value = slider_or_checked
            if current_state != new_value:  # Only update if the value is changing
                self.state["travel"][value] = new_value
                print(f"Updated travel state: {self.state['travel']}")  # Debugging
        elif isinstance(slider_or_checked, QSlider):  # Slider is moved
            # Handle slider value
            level = self._get_level_from_slider(slider_or_checked.value())
            if current_state != level:  # Only update if the value is changing
                self.state["travel"][value] = level
                print(f"Slider value for {value}: {slider_or_checked.value()} -> Mapped severity: {level}")  # Debugging

        self._update_preview()

    # ===================== STATE HANDLERS =====================
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
    def _toggle_slider(self, checked, value, on_change, slider_or_checkbox):
        if isinstance(slider_or_checkbox, QCheckBox):
            # Show slider when checkbox is checked, hide when unchecked
            slider = slider_or_checkbox.parent().findChild(QSlider)
            slider.setVisible(checked)  # Show the slider if checked, hide if unchecked
            
            # Trigger the handler for the checkbox
            on_change(value, checked)
        elif isinstance(slider_or_checkbox, QSlider):
            # For sliders, pass the slider instance to the handler
            slider = slider_or_checkbox
            slider_value = slider.value()
            severity_level = self._get_level_from_slider(slider_value)  # Map slider value to severity

            # Update the state with the correct severity level
            self.state["relationships"][value] = severity_level  # Update state with severity level for relationships
            self.state["travel"][value] = severity_level  # Update state with severity level for travel
            
            on_change(value, slider)


        
    # =====================  UPDATE PREVIEW=====================
    def _update_preview(self):
        # Generate the formatted text
        text = self.formatted_text()

        # Only update if the text has changed
        if text != self.preview.text():
            self.preview.setText(text or "No functional impairments recorded.")
            print(f"Preview updated: {text}")  # Debugging: Show the updated text
        else:
            print("No change in output text.")  # Debugging: Show if no changes occurred

    # =====================  FORMAT TEXT=====================

    # =========================
    # FORMATTED TEXT METHOD
    # =========================
    def formatted_text(self) -> str:
        p = self.p
        lines = []

        # =========================
        # SELF CARE
        # =========================
        sc = {
            k: v
            for k, v in self.state.get("self_care", {}).items()
            if k in self.VALID_SELF_CARE_KEYS and v
        }

        severity_map = {
            "severe": [],
            "significant": [],
            "moderate": [],
            "mild": [],
            "slight": [],
        }

        for key, value in sc.items():
            if value:
                severity_map[value].append(key)

        self_care_items = []

        for severity in ["severe", "significant", "moderate", "mild", "slight"]:
            for key in severity_map[severity]:
                self_care_items.append(
                    f"their ability to manage {key} ({severity})"
                )

        if self_care_items:
            if len(self_care_items) > 1:
                last_item = self_care_items.pop()
                lines.append(
                    f"The illness affects {p['pos']} self-care on several levels, "
                    f"mainly {', '.join(self_care_items)} and {last_item}."
                )
            else:
                lines.append(
                    f"The illness affects {p['pos']} self-care, "
                    f"specifically {self_care_items[0]}."
                )

        # =========================
        # RELATIONSHIPS
        # =========================
        rel = self.state.get("relationships", {})
        relationship_impairments = []

        if rel.get("intimate"):
            relationship_impairments.append(
                f"intimate relationships ({rel['intimate']})"
            )
        if rel.get("birth family"):
            relationship_impairments.append(
                f"family of origin ({rel['birth family']})"
            )
        if rel.get("friends"):
            relationship_impairments.append(
                f"friendships ({rel['friends']})"
            )

        if relationship_impairments:
            relationship_text = (
                "The illness has had an impact on relationships, specifically "
            )

            if len(relationship_impairments) == 1:
                relationship_text += (
                    f"with their {relationship_impairments[0]}."
                )
            else:
                last_item = relationship_impairments.pop()
                relationship_text += (
                    f"{', '.join(relationship_impairments)} and {last_item}."
                )

            lines.append(relationship_text)

        # =========================
        # WORK
        # =========================
        work = self.state.get("work", {})
        work_status = []

        if work.get("none"):
            work_status.append("they are not currently working")
        elif work.get("some"):
            work_status.append("they work only occasionally")
        elif work.get("part_time"):
            work_status.append("they are working part time")
        elif work.get("full_time"):
            work_status.append(
                "they are working full time with no occupational impairment"
            )

        if work_status:
            lines.append(f"Currently {', '.join(work_status)}.")

        # =========================
        # TRAVEL
        # =========================
        travel = self.state.get("travel", {})
        travel_impairments = []

        if travel.get("trains"):
            travel_impairments.append(f"trains ({travel['trains']})")
        if travel.get("buses"):
            travel_impairments.append(f"buses ({travel['buses']})")
        if travel.get("cars"):
            travel_impairments.append(f"cars ({travel['cars']})")

        if travel_impairments:
            if len(travel_impairments) > 1:
                last_item = travel_impairments.pop()
                lines.append(
                    f"The illness affects {p['pos']} ability to travel by "
                    f"{', '.join(travel_impairments)} and {last_item}."
                )
            else:
                lines.append(
                    f"The illness affects {p['pos']} ability to travel by "
                    f"{travel_impairments[0]}."
                )

        # =========================
        # FINAL OUTPUT
        # =========================
        return "\n\n".join(lines)




    # ===================== RESTORING THE STATE =====================

    def load_state(self, saved_state):
        # Loop through saved state and update the FunctionPopup state
        for section, values in saved_state.items():
            for key, value in values.items():
                if section in self.state:
                    if key in self.state[section]:
                        self.state[section][key] = value

        # Restore checkbox state
        self._restore_checkboxes(self.state['self_care'])
        self._restore_checkboxes(self.state['relationships'])
        self._restore_checkboxes(self.state['travel'])

        # Restore sliders
        self._restore_sliders()

        # Re-render the preview after loading the state
        self._update_preview()


    def _restore_checkboxes(self, section_state):
        # Loop through each key in the section state and set the checkbox checked state
        for key, value in section_state.items():
            checkbox = getattr(self, f"{key}_checkbox", None)
            if checkbox:
                checkbox.setChecked(value is not None and value)


    def _restore_sliders(self):
        # Loop through self_care, relationships, and travel to restore sliders
        for key in self.state['self_care']:
            slider = getattr(self, f"{key}_slider", None)
            if slider:
                value = self.state['self_care'].get(key)
                if value:
                    slider.setValue(self._get_slider_value_from_level(value))

        # Similarly for relationships and travel sliders
        for section in ['relationships', 'travel']:
            for key in self.state[section]:
                slider = getattr(self, f"{key}_slider", None)
                if slider:
                    value = self.state[section].get(key)
                    if value:
                        slider.setValue(self._get_slider_value_from_level(value))


    def _get_slider_value_from_level(self, level):
        # Map the level (Slight, Mild, Moderate, Significant, Severe) to slider values
        level_map = {
            "slight": 10,
            "mild": 30,
            "moderate": 50,
            "significant": 70,
            "severe": 90
        }
        return level_map.get(level.lower(), 0)


    def _restore_radio_buttons(self):
        work = self.state.get("work", {})

        # Handle the radio buttons based on the stored state
        for key, value in work.items():
            radio_button = getattr(self, f"{key}_radio", None)
            if radio_button:
                radio_button.setChecked(value)

# ===================== CLOSE=====================
    def closeEvent(self, event):
        import copy
        self.closed.emit(copy.deepcopy(self.state))
        super().closeEvent(event)


    def _emit(self):
        import copy

        text = self.formatted_text() or ""
        text = text.strip()

        state = copy.deepcopy(self.state)

        if text:
            self.sent.emit(text, state)

        self.close()

# ===================== DRAG SUPPORT =====================
    def mousePressEvent(self, e):
        if e.button() == Qt.LeftButton:
            self._drag_offset = e.globalPos() - self.frameGeometry().topLeft()

    def mouseMoveEvent(self, e):
        if e.buttons() & Qt.LeftButton and self._drag_offset:
            self.move(e.globalPos() - self._drag_offset)

    def mouseReleaseEvent(self, e):
        self._drag_offset = None
