from __future__ import annotations

from PySide6.QtCore import Signal
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout,
    QRadioButton, QButtonGroup
)


class QualificationsWidget(QWidget):
    """
    Editor for PERSONAL_HISTORY['QUALIFICATIONS']
    Ordered single-choice ladder.
    """
    changed = Signal(str)
    sentence_changed = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)

        self._value: str | None = None

        layout = QVBoxLayout(self)
        layout.setSpacing(8)

        self.group = QButtonGroup(self)
        self.group.setExclusive(True)

        # --------------------------------------------------
        # ORDERED OPTIONS (LOW → HIGH)
        # --------------------------------------------------
        self.rb_none = QRadioButton("No qualifications")
        self.rb_gcse_below = QRadioButton("GCSEs (below C)")
        self.rb_gcse_mixed = QRadioButton("GCSEs (mixed)")
        self.rb_gcse_above = QRadioButton("GCSEs (above C)")
        self.rb_alevel_started = QRadioButton("A levels started")
        self.rb_alevel_completed = QRadioButton("A levels completed")
        self.rb_uni_incomplete = QRadioButton("University – not completed")
        self.rb_degree = QRadioButton("University – degree")
        self.rb_postgraduate = QRadioButton("Postgraduate qualification")

        for rb in (
            self.rb_none,
            self.rb_gcse_below,
            self.rb_gcse_mixed,
            self.rb_gcse_above,
            self.rb_alevel_started,
            self.rb_alevel_completed,
            self.rb_uni_incomplete,
            self.rb_degree,
            self.rb_postgraduate,
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
            self.group.addButton(rb)
            layout.addWidget(rb)
            rb.toggled.connect(self._on_changed)

    # --------------------------------------------------
    # INTERNAL
    # --------------------------------------------------
    def _on_changed(self):
        mapping = {
            self.rb_none: "none",
            self.rb_gcse_below: "gcse_below",
            self.rb_gcse_mixed: "gcse_mixed",
            self.rb_gcse_above: "gcse_above",
            self.rb_alevel_started: "alevel_started",
            self.rb_alevel_completed: "alevel_completed",
            self.rb_uni_incomplete: "uni_incomplete",
            self.rb_degree: "degree",
            self.rb_postgraduate: "postgraduate",
        }

        for rb, value in mapping.items():
            if rb.isChecked():
                if value == self._value:
                    return

                self._value = value
                self.changed.emit(value)

                sentence = self._to_sentence(value)
                if sentence:
                    self.sentence_changed.emit(sentence)
                return

    def _to_sentence(self, value: str) -> str:
        if not value:
            return ""

        if value == "none":
            return "They left school with no qualifications."

        if value == "gcse_below":
            return "They completed GCSEs, all below grade C."

        if value == "gcse_mixed":
            return "They completed GCSEs with mixed results."

        if value == "gcse_above":
            return "They completed GCSEs, all above grade C."

        if value == "alevel_started":
            return "They started A levels but did not complete them."

        if value == "alevel_completed":
            return "They completed A levels."

        if value == "uni_incomplete":
            return "They went to university but did not complete their course."

        if value == "degree":
            return "They went to university and obtained a degree."

        if value == "postgraduate":
            return "They studied at university to postgraduate level."

        return ""



    # --------------------------------------------------
    # EXTERNAL API
    # --------------------------------------------------
    def set_value(self, value: str | None):
        self._value = value

        self.rb_none.setChecked(value == "none")
        self.rb_gcse_below.setChecked(value == "gcse_below")
        self.rb_gcse_mixed.setChecked(value == "gcse_mixed")
        self.rb_gcse_above.setChecked(value == "gcse_above")
        self.rb_alevel_started.setChecked(value == "alevel_started")
        self.rb_alevel_completed.setChecked(value == "alevel_completed")
        self.rb_uni_incomplete.setChecked(value == "uni_incomplete")
        self.rb_degree.setChecked(value == "degree")
        self.rb_postgraduate.setChecked(value == "postgraduate")

    def get_value(self) -> str | None:
        return self._value

    def get_state(self) -> dict:
        return {
            "value": self._value
        }
