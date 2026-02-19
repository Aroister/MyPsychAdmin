from __future__ import annotations

from PySide6.QtCore import Signal
from PySide6.QtWidgets import (
        QWidget, QVBoxLayout,
        QRadioButton, QButtonGroup
)


class SexualOrientationWidget(QWidget):
    """
    Editor for PERSONAL_HISTORY['SEXUAL_ORIENTATION']
    Single-choice with explicit opt-out.
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

        self.rb_hetero = QRadioButton("Heterosexual")
        self.rb_homo = QRadioButton("Homosexual")
        self.rb_bi = QRadioButton("Bisexual")
        self.rb_trans = QRadioButton("Transgender")
        self.rb_none = QRadioButton("Prefer not to say")

        for rb in (
                self.rb_hetero,
                self.rb_homo,
                self.rb_bi,
                self.rb_trans,
                self.rb_none,
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
                self.rb_hetero: "heterosexual",
                self.rb_homo: "homosexual",
                self.rb_bi: "bisexual",
                self.rb_trans: "transgender",
                self.rb_none: "not_specified",
        }

        for rb, value in mapping.items():
                if rb.isChecked():
                        if value == self._value:
                                return
                        self._value = value
                        self.changed.emit(value)
                        self.sentence_changed.emit(self._to_sentence(value))
                        return

    def _to_sentence(self, value: str) -> str:
        if not value:
            return ""

        if value == "not_specified":
            return "They did not wish to specify their sexual orientation."

        mapping = {
            "heterosexual": "They are heterosexual.",
            "homosexual": "They are homosexual.",
            "bisexual": "They are bisexual.",
            "transgender": "They are transgender.",
        }

        return mapping.get(value, "")

    # --------------------------------------------------
    # EXTERNAL API
    # --------------------------------------------------
    def set_value(self, value: str | None):
        self._value = value

        self.rb_hetero.setChecked(value == "heterosexual")
        self.rb_homo.setChecked(value == "homosexual")
        self.rb_bi.setChecked(value == "bisexual")
        self.rb_trans.setChecked(value == "transgender")
        self.rb_none.setChecked(value == "not_specified")

    def get_value(self) -> str | None:
        return self._value

    def get_state(self) -> dict:
        return {
            "value": self._value
        }
