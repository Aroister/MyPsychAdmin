from __future__ import annotations

from PySide6.QtCore import Signal, Qt
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout,
    QRadioButton, QButtonGroup
)


class MilestonesWidget(QWidget):
    """
    Developmental milestones — vertical layout to avoid horizontal scroll
    """
    sentence_changed = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)

        self._value = None

        # ==================================================
        # ROOT — VERTICAL LAYOUT
        # ==================================================
        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(6)
        root.setAlignment(Qt.AlignTop | Qt.AlignLeft)

        self.group = QButtonGroup(self)

        self.rb_normal = QRadioButton("Normal")
        self.rb_mild = QRadioButton("Mildly delayed")
        self.rb_moderate = QRadioButton("Moderately delayed")
        self.rb_significant = QRadioButton("Significantly delayed")
        self.rb_speech = QRadioButton("Delayed – speech")
        self.rb_motor = QRadioButton("Delayed – motor")
        self.rb_speech_motor = QRadioButton("Delayed – speech & motor")

        for rb in (
            self.rb_normal,
            self.rb_mild,
            self.rb_moderate,
            self.rb_significant,
            self.rb_speech,
            self.rb_motor,
            self.rb_speech_motor,
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
            root.addWidget(rb)
            rb.toggled.connect(self._emit)

    # ----------------------------------
    # INTERNAL
    # ----------------------------------
    def _emit(self):
        self._value = self._infer_value()
        text = self._to_sentence()
        if text:
            self.sentence_changed.emit(text)

    def _infer_value(self) -> str | None:
        if self.rb_normal.isChecked():
            return "normal"
        if self.rb_mild.isChecked():
            return "mildly delayed"
        if self.rb_moderate.isChecked():
            return "moderately delayed"
        if self.rb_significant.isChecked():
            return "significantly delayed"
        if self.rb_speech.isChecked():
            return "delayed with concerns about speech"
        if self.rb_motor.isChecked():
            return "delayed with concerns about motor function"
        if self.rb_speech_motor.isChecked():
            return "delayed with concerns about speech and motor function"
        return None

    # ----------------------------------
    # SENTENCE
    # ----------------------------------
    def _to_sentence(self) -> str:
        if self.rb_normal.isChecked():
            return "Their developmental milestones were normal."
        if self.rb_mild.isChecked():
            return "Their developmental milestones were mildly delayed."
        if self.rb_moderate.isChecked():
            return "Their developmental milestones were moderately delayed."
        if self.rb_significant.isChecked():
            return "Their developmental milestones were significantly delayed."
        if self.rb_speech.isChecked():
            return "Their developmental milestones were delayed in speech."
        if self.rb_motor.isChecked():
            return "Their developmental milestones were delayed in motor development."
        if self.rb_speech_motor.isChecked():
            return (
                "Their developmental milestones were delayed in both speech "
                "and motor development."
            )
        return ""

    # --------------------------------------------------
    # EXTERNAL API
    # --------------------------------------------------
    def set_value(self, value: str | None):
        self._value = value

        self.rb_normal.setChecked(value == "normal")
        self.rb_mild.setChecked(value == "mildly delayed")
        self.rb_moderate.setChecked(value == "moderately delayed")
        self.rb_significant.setChecked(value == "significantly delayed")
        self.rb_speech.setChecked(value == "delayed with concerns about speech")
        self.rb_motor.setChecked(value == "delayed with concerns about motor function")
        self.rb_speech_motor.setChecked(
            value == "delayed with concerns about speech and motor function"
        )

    def get_value(self) -> str | None:
        return self._value

    def get_state(self) -> str | None:
        return self._value
