from __future__ import annotations

from PySide6.QtCore import Signal
from PySide6.QtWidgets import (
    QWidget, QLabel, QVBoxLayout,
    QRadioButton, QButtonGroup
)


class WorkHistoryWidget(QWidget):
    """
    Editor for PERSONAL_HISTORY['WORK_HISTORY']
    Pattern + recency → deterministic sentence
    """
    changed = Signal(dict)
    sentence_changed = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)

        self._state = {
            "pattern": None,
            "last_worked_years": None,
        }

        layout = QVBoxLayout(self)
        layout.setSpacing(8)

        # ------------------------------
        # Pattern
        # ------------------------------
        layout.addWidget(QLabel("Employment pattern"))

        self.pattern_group = QButtonGroup(self)
        self.rb_never = QRadioButton("Never worked")
        self.rb_intermittent = QRadioButton("Intermittent")
        self.rb_erratic = QRadioButton("Erratic")
        self.rb_continuous = QRadioButton("Continuous")

        for rb in (
            self.rb_never,
            self.rb_intermittent,
            self.rb_erratic,
            self.rb_continuous,
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
            self.pattern_group.addButton(rb)
            layout.addWidget(rb)
            rb.toggled.connect(self._on_pattern_changed)

        # ------------------------------
        # Last worked
        # ------------------------------
        layout.addWidget(QLabel("Last worked"))

        self.last_group = QButtonGroup(self)
        self.rb_lt6m = QRadioButton("< 6 months")
        self.rb_1yr = QRadioButton("~1 year")
        self.rb_2yr = QRadioButton("~2 years")
        self.rb_3yr = QRadioButton("~3 years")
        self.rb_5yr = QRadioButton("5+ years")

        for rb in (
            self.rb_lt6m,
            self.rb_1yr,
            self.rb_2yr,
            self.rb_3yr,
            self.rb_5yr,
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
            self.last_group.addButton(rb)
            layout.addWidget(rb)
            rb.toggled.connect(self._on_last_changed)

        self._update_last_enabled()

    # --------------------------------------------------
    # INTERNAL
    # --------------------------------------------------
    def _on_pattern_changed(self):
        if self.rb_never.isChecked():
            self._state["pattern"] = "never"
            self._state["last_worked_years"] = None
        elif self.rb_intermittent.isChecked():
            self._state["pattern"] = "intermittent"
        elif self.rb_erratic.isChecked():
            self._state["pattern"] = "erratic"
        elif self.rb_continuous.isChecked():
            self._state["pattern"] = "continuous"
        else:
            self._state["pattern"] = None

        self._update_last_enabled()
        self._emit()

    def _on_last_changed(self):
        mapping = {
            self.rb_lt6m: 0,
            self.rb_1yr: 1,
            self.rb_2yr: 2,
            self.rb_3yr: 3,
            self.rb_5yr: 5,
        }

        for rb, years in mapping.items():
            if rb.isChecked():
                self._state["last_worked_years"] = years
                self._emit()
                return

    def _update_last_enabled(self):
        enabled = self._state["pattern"] != "never"
        for rb in (
            self.rb_lt6m,
            self.rb_1yr,
            self.rb_2yr,
            self.rb_3yr,
            self.rb_5yr,
        ):
            rb.setEnabled(enabled)
            if not enabled:
                rb.setChecked(False)

    def _emit(self):
        self.changed.emit(self._state.copy())
        sentence = self._to_sentence()
        if sentence:
            self.sentence_changed.emit(sentence)

    # --------------------------------------------------
    # SENTENCE
    # --------------------------------------------------
    def _to_sentence(self) -> str:
        pattern = self._state.get("pattern")
        years = self._state.get("last_worked_years")

        if not pattern:
            return ""

        if pattern == "never":
            return "They have never worked."

        if pattern == "intermittent":
            sentence = "They have worked, but only intermittently."
        elif pattern == "erratic":
            sentence = "Their work history has been erratic."
        elif pattern == "continuous":
            sentence = "They have worked continuously."
        else:
            return ""

        if years is not None:
            if years == 0:
                sentence += " The last time they worked was less than six months ago."
            elif years == 1:
                sentence += " The last time they worked was one year ago."
            else:
                sentence += f" The last time they worked was {years} years ago."

        return sentence

    # --------------------------------------------------
    # EXTERNAL API
    # --------------------------------------------------
    def set_state(self, state: dict):
        self._state = {
            "pattern": state.get("pattern"),
            "last_worked_years": state.get("last_worked_years"),
        }

        self.rb_never.setChecked(self._state["pattern"] == "never")
        self.rb_intermittent.setChecked(self._state["pattern"] == "intermittent")
        self.rb_erratic.setChecked(self._state["pattern"] == "erratic")
        self.rb_continuous.setChecked(self._state["pattern"] == "continuous")

        mapping = {
            0: self.rb_lt6m,
            1: self.rb_1yr,
            2: self.rb_2yr,
            3: self.rb_3yr,
            5: self.rb_5yr,
        }

        rb = mapping.get(self._state["last_worked_years"])
        if rb:
            rb.setChecked(True)

        self._update_last_enabled()
        
    def get_state(self) -> dict:
        return self._state.copy()
