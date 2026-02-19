from __future__ import annotations

from PySide6.QtCore import Signal
from PySide6.QtWidgets import (
    QWidget, QLabel, QVBoxLayout,
    QRadioButton, QButtonGroup, QCheckBox
)


class SchoolingWidget(QWidget):
    """
    Editor for PERSONAL_HISTORY['SCHOOLING']
    Severity + issues → deterministic sentence
    """
    changed = Signal(dict)
    sentence_changed = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)

        self._state = {
            "severity": None,
            "issues": [],
        }

        layout = QVBoxLayout(self)
        layout.setSpacing(8)

        # ------------------------------
        # Severity
        # ------------------------------
        layout.addWidget(QLabel("Overall"))

        self.severity_group = QButtonGroup(self)
        self.rb_none = QRadioButton("Unremarkable")
        self.rb_some = QRadioButton("Some issues")
        self.rb_significant = QRadioButton("Significant issues")

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
            layout.addWidget(rb)
            rb.toggled.connect(self._on_severity_changed)

        # ------------------------------
        # Issues
        # ------------------------------
        layout.addWidget(QLabel("If present:"))

        self.cb_conduct = QCheckBox("Conduct problems")
        self.cb_bullying = QCheckBox("Bullying")
        self.cb_truancy = QCheckBox("Truancy")
        self.cb_expelled = QCheckBox("Expelled")

        for cb in (
            self.cb_conduct,
            self.cb_bullying,
            self.cb_truancy,
            self.cb_expelled,
        ):
            cb.setStyleSheet("font-size: 22px;")
            layout.addWidget(cb)
            cb.stateChanged.connect(self._on_issues_changed)

        self._update_issues_enabled()

    # --------------------------------------------------
    # INTERNAL
    # --------------------------------------------------
    def _on_severity_changed(self):
        if self.rb_none.isChecked():
            self._state["severity"] = "none"
            self._state["issues"] = []
        elif self.rb_some.isChecked():
            self._state["severity"] = "some"
        elif self.rb_significant.isChecked():
            self._state["severity"] = "significant"
        else:
            self._state["severity"] = None

        self._update_issues_enabled()
        self._emit()

    def _on_issues_changed(self):
        issues = []
        if self.cb_conduct.isChecked():
            issues.append("conduct problems")
        if self.cb_bullying.isChecked():
            issues.append("bullying")
        if self.cb_truancy.isChecked():
            issues.append("truancy")
        if self.cb_expelled.isChecked():
            issues.append("expulsion")

        self._state["issues"] = issues
        self._emit()

    def _update_issues_enabled(self):
        enabled = self._state["severity"] in ("some", "significant")
        for cb in (
            self.cb_conduct,
            self.cb_bullying,
            self.cb_truancy,
            self.cb_expelled,
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
        issues = sorted(self._state.get("issues", []))

        if not sev:
            return ""

        if sev == "none":
            return "Schooling was unremarkable."

        if not issues:
            return "Schooling was associated with educational difficulties."

        joined = " and ".join(issues)

        if sev == "some":
            return (
                "Schooling was associated with some difficulties, "
                f"including {joined}."
            )

        return (
            "Schooling was significantly disrupted, "
            f"with {joined}."
        )

    # --------------------------------------------------
    # EXTERNAL API
    # --------------------------------------------------
    def set_state(self, state: dict):
        self._state = {
            "severity": state.get("severity"),
            "issues": state.get("issues", []),
        }

        # Block signals to prevent _on_issues_changed from overwriting state
        for cb in (self.cb_conduct, self.cb_bullying, self.cb_truancy, self.cb_expelled):
            cb.blockSignals(True)

        self.rb_none.setChecked(self._state["severity"] == "none")
        self.rb_some.setChecked(self._state["severity"] == "some")
        self.rb_significant.setChecked(self._state["severity"] == "significant")

        self.cb_conduct.setChecked("conduct problems" in self._state["issues"])
        self.cb_bullying.setChecked("bullying" in self._state["issues"])
        self.cb_truancy.setChecked("truancy" in self._state["issues"])
        self.cb_expelled.setChecked("expulsion" in self._state["issues"])

        # Unblock signals
        for cb in (self.cb_conduct, self.cb_bullying, self.cb_truancy, self.cb_expelled):
            cb.blockSignals(False)

        self._update_issues_enabled()

    def get_state(self) -> dict:
        return self._state.copy()
