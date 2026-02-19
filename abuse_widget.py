from __future__ import annotations

from PySide6.QtCore import Signal
from PySide6.QtWidgets import (
    QWidget, QLabel,
    QVBoxLayout,
    QRadioButton, QButtonGroup, QCheckBox
)


class AbuseWidget(QWidget):
    """
    Editor for PERSONAL_HISTORY['ABUSE']
    Severity + type → deterministic sentence
    """
    changed = Signal(dict)
    sentence_changed = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)

        self._state = {
            "severity": None,
            "types": [],
        }

        # ==================================================
        # ROOT — SINGLE COLUMN (LEFT-ALIGNED)
        # ==================================================
        root = QVBoxLayout(self)
        root.setSpacing(8)
        root.setContentsMargins(0, 0, 0, 0)

        # ==================================================
        # SEVERITY
        # ==================================================
        lbl_sev = QLabel("Severity")
        root.addWidget(lbl_sev)

        self.severity_group = QButtonGroup(self)
        self.rb_none = QRadioButton("None")
        self.rb_some = QRadioButton("Some")
        self.rb_significant = QRadioButton("Significant")

        for rb in (self.rb_none, self.rb_some, self.rb_significant):
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
            self.severity_group.addButton(rb)
            root.addWidget(rb)
            rb.toggled.connect(self._on_severity_changed)

        # ==================================================
        # TYPES — INDENTED (IF PRESENT)
        # ==================================================
        types_block = QVBoxLayout()
        types_block.setSpacing(6)
        types_block.setContentsMargins(24, 4, 0, 0)   # 👈 semantic indent

        lbl_types = QLabel("If present:")
        types_block.addWidget(lbl_types)

        self.cb_emotional = QCheckBox("Emotional")
        self.cb_physical = QCheckBox("Physical")
        self.cb_sexual = QCheckBox("Sexual")
        self.cb_neglect = QCheckBox("Neglect")

        for cb in (
            self.cb_emotional,
            self.cb_physical,
            self.cb_sexual,
            self.cb_neglect,
        ):
            cb.setStyleSheet("font-size: 22px;")
            types_block.addWidget(cb)
            cb.stateChanged.connect(self._on_types_changed)

        root.addLayout(types_block)

        self._update_type_enabled()

    # --------------------------------------------------
    # INTERNAL
    # --------------------------------------------------
    def _on_severity_changed(self):
        if self.rb_none.isChecked():
            self._state["severity"] = "none"
            self._state["types"] = []
        elif self.rb_some.isChecked():
            self._state["severity"] = "some"
        elif self.rb_significant.isChecked():
            self._state["severity"] = "significant"
        else:
            self._state["severity"] = None

        self._update_type_enabled()
        self._emit()

    def _on_types_changed(self):
        types = []
        if self.cb_emotional.isChecked():
            types.append("emotional")
        if self.cb_physical.isChecked():
            types.append("physical")
        if self.cb_sexual.isChecked():
            types.append("sexual")
        if self.cb_neglect.isChecked():
            types.append("neglect")

        self._state["types"] = types
        self._emit()

    def _update_type_enabled(self):
        enabled = self._state["severity"] in ("some", "significant")
        for cb in (
            self.cb_emotional,
            self.cb_physical,
            self.cb_sexual,
            self.cb_neglect,
        ):
            cb.setEnabled(enabled)
            if not enabled:
                cb.setChecked(False)

    def _emit(self):
        self.changed.emit(self._state.copy())
        sentence = self._to_sentence()
        if sentence:
            self.sentence_changed.emit(sentence)

    # --------------------------------------------------
    # SENTENCE
    # --------------------------------------------------
    def _to_sentence(self) -> str:
        sev = self._state.get("severity")
        types = sorted(self._state.get("types", []))

        if not sev:
            return ""

        if sev == "none":
            return "They described no history of childhood abuse."

        if not types:
            return f"They described a history of {sev} abuse as a child."

        # Format types with proper grammar
        if len(types) == 1:
            types_str = types[0]
        elif len(types) == 2:
            types_str = f"{types[0]} and {types[1]}"
        else:
            types_str = ", ".join(types[:-1]) + f" and {types[-1]}"

        return (
            f"They described a history of {sev} abuse as a child, "
            f"specifically {types_str}."
        )


    # --------------------------------------------------
    # EXTERNAL API
    # --------------------------------------------------
    def set_state(self, state: dict):
        self._state = {
            "severity": state.get("severity"),
            "types": state.get("types", []),
        }

        # Block signals to prevent _on_types_changed from overwriting state
        for cb in (self.cb_emotional, self.cb_physical, self.cb_sexual, self.cb_neglect):
            cb.blockSignals(True)

        self.rb_none.setChecked(self._state["severity"] == "none")
        self.rb_some.setChecked(self._state["severity"] == "some")
        self.rb_significant.setChecked(self._state["severity"] == "significant")

        self.cb_emotional.setChecked("emotional" in self._state["types"])
        self.cb_physical.setChecked("physical" in self._state["types"])
        self.cb_sexual.setChecked("sexual" in self._state["types"])
        self.cb_neglect.setChecked("neglect" in self._state["types"])

        # Unblock signals
        for cb in (self.cb_emotional, self.cb_physical, self.cb_sexual, self.cb_neglect):
            cb.blockSignals(False)

        self._update_type_enabled()

    def get_state(self) -> dict:
        return {
            "severity": self._state.get("severity"),
            "types": list(self._state.get("types", [])),
        }

