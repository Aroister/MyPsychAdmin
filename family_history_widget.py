from __future__ import annotations

from PySide6.QtCore import Signal
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout,
    QRadioButton, QButtonGroup
)


class FamilyHistoryWidget(QWidget):
    """
    Editor for PERSONAL_HISTORY['FAMILY_HISTORY']
    Excel-aligned, single-choice.
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
        # OPTIONS (EXACTLY AS PER EXCEL)
        # --------------------------------------------------
        self.rb_none = QRadioButton(
            "No family psychiatric history and no alcoholism"
        )
        self.rb_some_no_alc = QRadioButton(
            "Some family mental illness, no alcoholism"
        )
        self.rb_sig_no_alc = QRadioButton(
            "Significant family mental illness, no alcoholism"
        )
        self.rb_none_alc = QRadioButton(
            "No family mental illness, alcoholism present"
        )
        self.rb_some_alc = QRadioButton(
            "Some family mental illness and alcoholism"
        )
        self.rb_sig_alc = QRadioButton(
            "Significant family mental illness and alcoholism"
        )

        for rb in (
            self.rb_none,
            self.rb_some_no_alc,
            self.rb_sig_no_alc,
            self.rb_none_alc,
            self.rb_some_alc,
            self.rb_sig_alc,
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
            self.rb_none: "none_no_alcohol",
            self.rb_some_no_alc: "some_no_alcohol",
            self.rb_sig_no_alc: "significant_no_alcohol",
            self.rb_none_alc: "none_with_alcohol",
            self.rb_some_alc: "some_with_alcohol",
            self.rb_sig_alc: "significant_with_alcohol",
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
        sentences = {
            "none_no_alcohol":
                "There is no known family history of mental illness or alcoholism.",

            "some_no_alcohol":
                "There is some family history of mental illness, with no history of alcoholism.",

            "significant_no_alcohol":
                "There is a significant family history of mental illness, with no history of alcoholism.",

            "none_with_alcohol":
                "There is no known family history of mental illness, but there is a history of alcoholism.",

            "some_with_alcohol":
                "There is some family history of mental illness and alcoholism.",

            "significant_with_alcohol":
                "There is a significant family history of mental illness and alcoholism.",
        }
        return sentences.get(value, "")

    # --------------------------------------------------
    # EXTERNAL API
    # --------------------------------------------------
    def set_value(self, value: str | None):
        self._value = value

        self.rb_none.setChecked(value == "none_no_alcohol")
        self.rb_some_no_alc.setChecked(value == "some_no_alcohol")
        self.rb_sig_no_alc.setChecked(value == "significant_no_alcohol")
        self.rb_none_alc.setChecked(value == "none_with_alcohol")
        self.rb_some_alc.setChecked(value == "some_with_alcohol")
        self.rb_sig_alc.setChecked(value == "significant_with_alcohol")

    def get_value(self) -> str | None:
        return self._value

    def get_state(self) -> str | None:
        return self._value
