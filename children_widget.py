from __future__ import annotations

from PySide6.QtCore import Signal, Qt
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout,
    QRadioButton, QButtonGroup, QLabel
)


class ChildrenWidget(QWidget):
    """
    Editor for PERSONAL_HISTORY['CHILDREN']
    Count + age band + composition → deterministic sentence
    """

    changed = Signal(dict)
    sentence_changed = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)

        # --------------------------------------------------
        # STATE
        # --------------------------------------------------
        self._state = {
            "count": None,
            "age_band": None,
            "composition": None,
        }

        # ==================================================
        # ROOT — VERTICAL LAYOUT
        # ==================================================
        root = QVBoxLayout(self)
        root.setSpacing(6)
        root.setContentsMargins(0, 0, 0, 0)
        root.setAlignment(Qt.AlignTop | Qt.AlignLeft)

        # --------------------------------------------------
        # Number of children
        # --------------------------------------------------
        root.addWidget(QLabel("Number of children"))

        self.count_group = QButtonGroup(self)
        self.rb_0 = QRadioButton("0")
        self.rb_1 = QRadioButton("1")
        self.rb_2 = QRadioButton("2")
        self.rb_3 = QRadioButton("3")
        self.rb_4 = QRadioButton("4")
        self.rb_5 = QRadioButton("5+")

        for rb in (
            self.rb_0,
            self.rb_1,
            self.rb_2,
            self.rb_3,
            self.rb_4,
            self.rb_5,
        ):
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
            self.count_group.addButton(rb)
            root.addWidget(rb)
            rb.toggled.connect(self._on_count_changed)

        # --------------------------------------------------
        # Age band
        # --------------------------------------------------
        root.addSpacing(8)
        root.addWidget(QLabel("Age band"))

        self.age_group = QButtonGroup(self)
        self.rb_toddlers = QRadioButton("Toddlers")
        self.rb_primary = QRadioButton("Primary school age")
        self.rb_secondary = QRadioButton("Secondary school age")
        self.rb_adult = QRadioButton("Adult")
        self.rb_mixed = QRadioButton("Mixed ages")

        for rb in (
            self.rb_toddlers,
            self.rb_primary,
            self.rb_secondary,
            self.rb_adult,
            self.rb_mixed,
        ):
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
            self.age_group.addButton(rb)
            root.addWidget(rb)
            rb.toggled.connect(self._on_age_changed)

        # --------------------------------------------------
        # Composition (optional)
        # --------------------------------------------------
        root.addSpacing(8)
        root.addWidget(QLabel("Composition (optional)"))

        self.comp_group = QButtonGroup(self)
        self.rb_sons = QRadioButton("Sons")
        self.rb_daughters = QRadioButton("Daughters")
        self.rb_mixed_comp = QRadioButton("Mixed")

        for rb in (
            self.rb_sons,
            self.rb_daughters,
            self.rb_mixed_comp,
        ):
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
            self.comp_group.addButton(rb)
            root.addWidget(rb)
            rb.toggled.connect(self._on_comp_changed)

        self._update_enabled()

    # ==================================================
    # INTERNAL — SIGNAL HANDLERS
    # ==================================================
    def _on_count_changed(self):
        if self.rb_0.isChecked():
            self._state["count"] = 0
        elif self.rb_1.isChecked():
            self._state["count"] = 1
        elif self.rb_2.isChecked():
            self._state["count"] = 2
        elif self.rb_3.isChecked():
            self._state["count"] = 3
        elif self.rb_4.isChecked():
            self._state["count"] = 4
        elif self.rb_5.isChecked():
            self._state["count"] = 5

        if self._state["count"] == 0:
            self._state["age_band"] = None
            self._state["composition"] = None

        self._update_enabled()
        self._emit()

    def _on_age_changed(self):
        mapping = {
            self.rb_toddlers: "toddlers",
            self.rb_primary: "primary",
            self.rb_secondary: "secondary",
            self.rb_adult: "adult",
            self.rb_mixed: "mixed",
        }

        for rb, value in mapping.items():
            if rb.isChecked():
                self._state["age_band"] = value
                self._emit()
                return

    def _on_comp_changed(self):
        mapping = {
            self.rb_sons: "sons",
            self.rb_daughters: "daughters",
            self.rb_mixed_comp: "mixed",
        }

        for rb, value in mapping.items():
            if rb.isChecked():
                self._state["composition"] = value
                self._emit()
                return

    def _update_enabled(self):
        enabled = self._state["count"] not in (None, 0)
        count = self._state["count"]

        for rb in (
            self.rb_toddlers,
            self.rb_primary,
            self.rb_secondary,
            self.rb_adult,
            self.rb_sons,
            self.rb_daughters,
        ):
            rb.setEnabled(enabled)
            if not enabled:
                rb.setChecked(False)

        # Mixed ages and mixed composition only make sense for more than 1 child
        mixed_enabled = enabled and count > 1
        self.rb_mixed.setEnabled(mixed_enabled)
        self.rb_mixed_comp.setEnabled(mixed_enabled)
        if not mixed_enabled:
            self.rb_mixed.setChecked(False)
            self.rb_mixed_comp.setChecked(False)
            if self._state["age_band"] == "mixed":
                self._state["age_band"] = None
            if self._state["composition"] == "mixed":
                self._state["composition"] = None

    def _emit(self):
        self.changed.emit(self._state.copy())
        self.sentence_changed.emit(self._to_sentence())

    # ==================================================
    # SENTENCE
    # ==================================================
    def _to_sentence(self) -> str:
        count = self._state.get("count")
        age = self._state.get("age_band")
        comp = self._state.get("composition")

        if count is None:
            return ""

        if count == 0:
            return "They have no children."

        number_map = {
            1: "one",
            2: "two",
            3: "three",
            4: "four",
            5: "five or more",
        }

        number = number_map.get(count, str(count))

        # -------------------------
        # Build subject based on count and composition
        # -------------------------
        if count == 1:
            if comp == "sons":
                sentence = "They have a son"
            elif comp == "daughters":
                sentence = "They have a daughter"
            else:
                sentence = "They have one child"
        else:
            sentence = f"They have {number} children"

        # -------------------------
        # Age band phrasing
        # -------------------------
        if age:
            if age == "toddlers":
                if count == 1:
                    sentence += " who is a toddler"
                else:
                    sentence += " who are all toddlers"
            elif age == "primary":
                if count == 1:
                    sentence += " who is of primary school age"
                else:
                    sentence += " who are of primary school age"
            elif age == "secondary":
                if count == 1:
                    sentence += " who is of secondary school age"
                else:
                    sentence += " who are of secondary school age"
            elif age == "adult":
                if count == 1:
                    sentence += " who is an adult"
                else:
                    sentence += " who are adults"
            elif age == "mixed" and count > 1:
                sentence += " of mixed ages"

        # -------------------------
        # Composition for multiple children
        # -------------------------
        if comp and comp != "mixed" and count > 1:
            sentence += f", all {comp}"

        return sentence + "."

    # ==================================================
    # EXTERNAL API
    # ==================================================
    def set_state(self, state: dict):
        self._state = {
            "count": state.get("count"),
            "age_band": state.get("age_band"),
            "composition": state.get("composition"),
        }

        count_map = {
            0: self.rb_0,
            1: self.rb_1,
            2: self.rb_2,
            3: self.rb_3,
            4: self.rb_4,
            5: self.rb_5,
        }

        rb = count_map.get(self._state["count"])
        if rb:
            rb.setChecked(True)

        age_map = {
            "toddlers": self.rb_toddlers,
            "primary": self.rb_primary,
            "secondary": self.rb_secondary,
            "adult": self.rb_adult,
            "mixed": self.rb_mixed,
        }

        rb = age_map.get(self._state["age_band"])
        if rb:
            rb.setChecked(True)

        comp_map = {
            "sons": self.rb_sons,
            "daughters": self.rb_daughters,
            "mixed": self.rb_mixed_comp,
        }

        rb = comp_map.get(self._state["composition"])
        if rb:
            rb.setChecked(True)

        self._update_enabled()

    def get_state(self) -> dict:
        return {
            "count": self._state.get("count"),
            "age_band": self._state.get("age_band"),
            "composition": self._state.get("composition"),
        }

