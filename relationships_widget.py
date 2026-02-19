from __future__ import annotations

from PySide6.QtCore import Signal
from PySide6.QtWidgets import (
        QWidget, QVBoxLayout,
        QRadioButton, QButtonGroup, QLabel
)


class RelationshipsWidget(QWidget):
    """
    Editor for PERSONAL_HISTORY['RELATIONSHIPS']
    Status + duration → deterministic sentence
    """
    changed = Signal(dict)
    sentence_changed = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)

        self._state = {
                "status": None,
                "duration_years": None,
        }

        layout = QVBoxLayout(self)
        layout.setSpacing(8)

        # ------------------------------
        # Status
        # ------------------------------
        layout.addWidget(QLabel("Current status"))

        self.status_group = QButtonGroup(self)
        self.rb_none = QRadioButton("Not in a relationship")
        self.rb_relationship = QRadioButton("In a relationship")
        self.rb_married = QRadioButton("Married")

        for rb in (
                self.rb_none,
                self.rb_relationship,
                self.rb_married,
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
                self.status_group.addButton(rb)
                layout.addWidget(rb)
                rb.toggled.connect(self._on_status_changed)

        # ------------------------------
        # Duration
        # ------------------------------
        layout.addWidget(QLabel("Duration"))

        self.duration_group = QButtonGroup(self)
        self.rb_lt1 = QRadioButton("< 1 year")
        self.rb_1 = QRadioButton("1 year")
        self.rb_2 = QRadioButton("2 years")
        self.rb_3 = QRadioButton("3 years")
        self.rb_5 = QRadioButton("5 years")
        self.rb_10 = QRadioButton("10+ years")

        for rb in (
                self.rb_lt1,
                self.rb_1,
                self.rb_2,
                self.rb_3,
                self.rb_5,
                self.rb_10,
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
                self.duration_group.addButton(rb)
                layout.addWidget(rb)
                rb.toggled.connect(self._on_duration_changed)

        self._update_duration_enabled()

    # --------------------------------------------------
    # INTERNAL
    # --------------------------------------------------
    def _on_status_changed(self):
        if self.rb_none.isChecked():
                self._state["status"] = "none"
                self._state["duration_years"] = None
        elif self.rb_relationship.isChecked():
                self._state["status"] = "relationship"
        elif self.rb_married.isChecked():
                self._state["status"] = "married"

        self._update_duration_enabled()
        self._emit()

    def _on_duration_changed(self):
        mapping = {
                self.rb_lt1: 0,
                self.rb_1: 1,
                self.rb_2: 2,
                self.rb_3: 3,
                self.rb_5: 5,
                self.rb_10: 10,
        }

        for rb, years in mapping.items():
                if rb.isChecked():
                        self._state["duration_years"] = years
                        self._emit()
                        return

    def _update_duration_enabled(self):
        enabled = self._state["status"] in ("relationship", "married")

        for rb in (
                self.rb_lt1,
                self.rb_1,
                self.rb_2,
                self.rb_3,
                self.rb_5,
                self.rb_10,
        ):
                rb.setEnabled(enabled)
                if not enabled:
                        rb.setChecked(False)

    def _emit(self):
        self.changed.emit(self._state.copy())
        self.sentence_changed.emit(self._to_sentence())

    # --------------------------------------------------
    # SENTENCE
    # --------------------------------------------------
    def _to_sentence(self) -> str:
        status = self._state.get("status")
        years = self._state.get("duration_years")

        if not status:
            return ""

        # ---------------------------
        # No relationship
        # ---------------------------
        if status == "none":
            return "They are not currently in a relationship."

        # ---------------------------
        # Duration wording
        # ---------------------------
        dur_text = None
        if years is not None:
            if years == 0:
                dur_text = "less than one year"
            elif years == 1:
                dur_text = "one year"
            elif years == 2:
                dur_text = "two years"
            elif years == 3:
                dur_text = "three years"
            elif years == 5:
                dur_text = "five years"
            elif years == 10:
                dur_text = "over ten years"

        # ---------------------------
        # In a relationship
        # ---------------------------
        if status == "relationship":
            if dur_text:
                return f"They have been in a relationship for {dur_text}."
            return "They are currently in a relationship."

        # ---------------------------
        # Married
        # ---------------------------
        if status == "married":
            if dur_text:
                return f"They have been married for {dur_text}."
            return "They are married."

        return ""


    # --------------------------------------------------
    # EXTERNAL API
    # --------------------------------------------------
    def set_state(self, state: dict):
        self._state = {
                "status": state.get("status"),
                "duration_years": state.get("duration_years"),
        }

        self.rb_none.setChecked(self._state["status"] == "none")
        self.rb_relationship.setChecked(self._state["status"] == "relationship")
        self.rb_married.setChecked(self._state["status"] == "married")

        mapping = {
                0: self.rb_lt1,
                1: self.rb_1,
                2: self.rb_2,
                3: self.rb_3,
                5: self.rb_5,
                10: self.rb_10,
        }

        rb = mapping.get(self._state["duration_years"])
        if rb:
                rb.setChecked(True)

        self._update_duration_enabled()

    def get_state(self) -> dict:
        return {
            "status": self._state.get("status"),
            "duration_years": self._state.get("duration_years"),
        }

