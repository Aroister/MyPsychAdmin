from __future__ import annotations

from PySide6.QtCore import Signal
from PySide6.QtWidgets import (
    QWidget, QLabel, QVBoxLayout,
    QRadioButton, QButtonGroup
)


class BirthWidget(QWidget):
    """
    Editor for PERSONAL_HISTORY['BIRTH']
    Excel-aligned, single-choice.
    """
    changed = Signal(str)
    sentence_changed = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)

        self._value: str | None = None

        layout = QVBoxLayout(self)
        layout.setSpacing(8)

        # --------------------------------------------------
        # OPTIONS (EXACTLY AS PER EXCEL)
        # --------------------------------------------------
        self.group = QButtonGroup(self)
        self.group.setExclusive(True)

        self.rb_normal = QRadioButton("Normal")
        self.rb_difficult = QRadioButton("Difficult")
        self.rb_premature = QRadioButton("Premature")
        self.rb_traumatic = QRadioButton("Traumatic")

        for rb in (
            self.rb_normal,
            self.rb_difficult,
            self.rb_premature,
            self.rb_traumatic,
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
            self.rb_normal: "normal",
            self.rb_difficult: "difficult",
            self.rb_premature: "premature",
            self.rb_traumatic: "traumatic",
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
        sentences = {
            "normal": "They described their birth as normal.",
            "difficult": "They described their birth as difficult.",
            "premature": "They were born prematurely.",
            "traumatic": "They described their birth as traumatic.",
        }
        return sentences.get(value, "")


    # --------------------------------------------------
    # EXTERNAL API
    # --------------------------------------------------
    def set_value(self, value: str | None):
        self._value = value

        self.rb_normal.setChecked(value == "normal")
        self.rb_difficult.setChecked(value == "difficult")
        self.rb_premature.setChecked(value == "premature")
        self.rb_traumatic.setChecked(value == "traumatic")

    def get_value(self) -> str | None:
        return self._value

    def get_state(self) -> dict:
        return {
            "value": self._value
        }

