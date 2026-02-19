from __future__ import annotations

from PySide6.QtCore import Signal
from PySide6.QtWidgets import (
    QWidget, QLabel, QVBoxLayout, QHBoxLayout,
    QRadioButton, QCheckBox, QButtonGroup
)


class AbuseDescriptorWidget(QWidget):
    """
    Editor for PERSONAL_HISTORY['ABUSE']
    """
    changed = Signal(dict)

    def __init__(self, parent=None):
        super().__init__(parent)

        self._state = {
            "severity": None,
            "types": [],
        }

        layout = QVBoxLayout(self)
        layout.setSpacing(10)
        sentence_changed = Signal(str)
        # -------------------------------
        # Severity
        # -------------------------------
        layout.addWidget(QLabel("Severity"))

        self.severity_group = QButtonGroup(self)
        self.rb_none = QRadioButton("None")
        self.rb_some = QRadioButton("Some")
        self.rb_significant = QRadioButton("Significant")

        for rb in (self.rb_none, self.rb_some, self.rb_significant):
            self.severity_group.addButton(rb)
            layout.addWidget(rb)
            rb.toggled.connect(self._on_severity_changed)

        # -------------------------------
        # Types
        # -------------------------------
        layout.addSpacing(6)
        layout.addWidget(QLabel("If present, type(s):"))

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
            layout.addWidget(cb)
            cb.stateChanged.connect(self._on_types_changed)

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

        self._update_type_enabled()
        self.changed.emit(self._state.copy())

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
        self.changed.emit(self._state.copy())

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
    def _to_sentence(self) -> str:
        sev = self._state.get("severity")
        types = self._state.get("types", [])

        if not sev or sev == "none":
            return "There is no reported history of childhood abuse."

        if not types:
            if sev == "some":
                return "There is a history of some childhood abuse."
            return "There is a history of significant childhood abuse."

        joined = " and ".join(types)

        if sev == "some":
            return f"There is a history of some childhood {joined} abuse."

        return f"There is a history of significant childhood {joined} abuse."

    # --------------------------------------------------
    # EXTERNAL API
    # --------------------------------------------------
    def set_state(self, state: dict):
        self._state = {
            "severity": state.get("severity"),
            "types": state.get("types", []),
        }

        self.rb_none.setChecked(self._state["severity"] == "none")
        self.rb_some.setChecked(self._state["severity"] == "some")
        self.rb_significant.setChecked(self._state["severity"] == "significant")

        self.cb_emotional.setChecked("emotional" in self._state["types"])
        self.cb_physical.setChecked("physical" in self._state["types"])
        self.cb_sexual.setChecked("sexual" in self._state["types"])
        self.cb_neglect.setChecked("neglect" in self._state["types"])

        self._update_type_enabled()
        
    def get_state(self) -> dict:
        return self._state.copy()
