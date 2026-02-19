from __future__ import annotations

from PySide6.QtCore import Qt, QTimer, Signal
from PySide6.QtWidgets import (
    QWidget, QLabel, QPushButton,
    QVBoxLayout, QHBoxLayout, QScrollArea,
    QSizePolicy, QGridLayout,
)
from anxiety_widgets import SymptomSection
from mini_severity_popup import MiniSeverityPopup
from shared_widgets import add_lock_to_popup
from spell_check_textedit import enable_spell_check_on_textedit


# ============================================================
# Grammar helpers
# ============================================================

def join_with_and(items: list[str]) -> str:
    if not items:
        return ""
    if len(items) == 1:
        return items[0]
    if len(items) == 2:
        return f"{items[0]} and {items[1]}"
    return ", ".join(items[:-1]) + f", and {items[-1]}"


def join_with_semicolons(items: list[str]) -> str:
    """Join items with semicolons for longer lists, 'and' for 2 items."""
    if not items:
        return ""
    if len(items) == 1:
        return items[0]
    if len(items) == 2:
        return f"{items[0]} and {items[1]}"
    return "; ".join(items[:-1]) + f"; and {items[-1]}"


def pronouns_from_gender(g: str):
    """Return pronoun dict based on gender string."""
    g = (g or "").strip().lower()
    if g == "male":
        return {
            "subj": "he",
            "obj": "him",
            "pos": "his",
            "be_present": "is",
            "be_past": "was",
            "have_present": "has",
        }
    if g == "female":
        return {
            "subj": "she",
            "obj": "her",
            "pos": "her",
            "be_present": "is",
            "be_past": "was",
            "have_present": "has",
        }
    return {
        "subj": "they",
        "obj": "them",
        "pos": "their",
        "be_present": "are",
        "be_past": "were",
        "have_present": "have",
    }


def pronouns_from_parent(widget: QWidget):
    """
    Mirror Affect behaviour:
    try to pull pronouns from parent, fallback to they/them.
    """
    p = getattr(widget.parent(), "pron", None)
    if p:
        return p
    return {
        "subj": "they",
        "obj": "them",
        "pos": "their",
        "be_present": "are",
        "be_past": "were",
        "have_present": "have",
    }




# ============================================================
# Phrase dictionaries
# ============================================================

DELUSION_PHRASES = {
    "persecutory": "persecutory delusions",
    "reference": "delusions of reference/misidentification",
    "delusional perception": "delusional perceptions",
    "somatic": "somatic delusions",
    "religious": "religious delusions outwith cultural norms",
    "mood/feeling": "delusions of mood/affect",
    "guilt/worthlessness": "profound mood-congruent delusions of guilt",
    "infidelity/jealousy": "delusional jealousy/infidelity",
    "nihilistic/negation": "mood-congruent delusions of worthlessness and nihilism",
    "grandiosity": "delusions of grandiosity",
}

THOUGHT_INTERFERENCE = {
    "broadcast": "thought broadcast",
    "withdrawal": "thought withdrawal",
    "insertion": "thought insertion",
}

PASSIVITY_PHENOMENA = {
    "thoughts": "external control of thoughts",
    "actions": "external control of actions",
    "limbs": "external limb-control (passivity)",
    "sensation": "external control of sensations",
}

ASSOCIATED_WITH = {
    "mannerisms": "mannerisms",
    "fear": "a sense of fear around these experiences",
    "thought disorder": "associated thought disorder",
    "negative symptoms": "significant negative symptoms",
    "acting on delusions": "acting on these experiences",
    "catatonia": "catatonic features",
    "overvalued ideas": "overvalued ideas",
    "inappropriate affect": "inappropriate affect",
    "behaviour change / withdrawal": "significant behavioural change and withdrawal",
    "obsessional beliefs": "obsessional beliefs",
}

# ============================================================
# Hallucinations dictionaries
# ============================================================

AUDITORY_HALLUCINATIONS = {
    "2nd person": "second-person auditory hallucinations (voices addressing the patient directly)",
    "3rd person": "third-person auditory hallucinations (a first-rank symptom)",
    "derogatory": "derogatory voices",
    "thought echo": "thought echo",
    "command": "command hallucinations",
    "running commentary": "a running commentary on the patient’s actions",
    "multiple voices": "multiple voices rather than a single voice",
}

OTHER_HALLUCINATIONS = {
    "visual": "visual",
    "tactile": "tactile",
    "somatic": "somatic",
    "olfactory/taste": "olfactory/gustatory",
}

HALLUCINATION_ASSOCIATED = {
    "pseudohallucinations": "pseudohallucinations rather than true hallucinations",
    "sleep related": "sleep-related perceptions (hypnagogic or hypnopompic)",
    "shadows/illusions": "illusions rather than true hallucinations",
    "fear": "a sense of fear around these perceptions",
    "acting on hallucinations": "acting on these hallucinations",
}


# ============================================================
# Psychosis Popup
# ============================================================
class PsychosisPopup(QWidget):
    saved = Signal(dict)

    def update_gender(self, gender: str):
        """Update pronouns when gender changes on front page."""
        self.gender = gender
        self.pron = pronouns_from_gender(gender)
        self._update_preview()

    # ====================================================
    # Severity helpers (MUST be instance methods)
    # ====================================================
    def severity_wording(self, sev: int, domain: str) -> str:
        """
        sev: 1 = mild, 2 = moderate, 3 = severe
        """
        if domain == "del":
            if sev == 3:
                return "Prominent delusional beliefs were noted"
            if sev == 2:
                return "Delusional beliefs were noted"
            return "Mild delusional beliefs were noted"

        if domain == "hal":
            if sev == 3:
                return "Prominent hallucinatory experiences were reported"
            if sev == 2:
                return "Hallucinatory experiences were reported"
            return "Mild hallucinatory experiences were reported"
        
    def max_severity(self, ns: str) -> int:
        """
        Returns max severity across all items in a namespace (del / hal)
        """
        max_sev = 0
        for k, (sev, _) in self.values.items():
            if k.startswith(f"{ns}|"):
                max_sev = max(max_sev, sev)
        return max_sev

    def max_severity_for(self, ns: str, mapping: dict[str, str]) -> int:
        """
        Returns the maximum severity for a specific sub-domain
        e.g. DELUSION_PHRASES, PASSIVITY_PHENOMENA, etc.
        """
        max_sev = 0
        for k, (sev, _) in self.values.items():
            if not k.startswith(f"{ns}|"):
                continue

            bare_key = k.split("|", 1)[1]
            if bare_key in mapping:
                max_sev = max(max_sev, sev)

        return max_sev
    
    def _toggle_simple(self, key):
        if key in self.values:
            self.values.pop(key)
        else:
            self.values[key] = (1, "")

        self._refresh_highlights()
        self._update_preview()
        

    def __init__(self, first_name: str = "", gender: str = None, parent=None):
        super().__init__(parent)

        self.first_name = first_name or "The patient"
        self.gender = gender
        self.pron = pronouns_from_parent(self)

        self.values: dict[str, tuple[int, str]] = {}
        self.current_mode = "Delusions"

        # Fixed panel style (not draggable)
        self.setWindowFlags(Qt.WindowType.Widget)
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        # ====================================================
        # ROOT
        # ====================================================
        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(8)

        # ========================================================
        # SCROLLABLE CONTENT
        # ========================================================
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        container = QWidget()
        container.setObjectName("psychosis_popup")
        container.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)
        container.setStyleSheet("""
            QWidget#psychosis_popup {
                background: rgba(255,255,255,0.92);
                border-radius: 12px;
                border: 1px solid rgba(0,0,0,0.15);
            }
            QLabel { color:#003c32; border: none; }
        """)
        scroll.setWidget(container)

        lay = QVBoxLayout(container)
        lay.setContentsMargins(12, 12, 12, 12)
        lay.setSpacing(8)

        # ====================================================
        # MODE BUTTONS (title removed - shown in panel header)
        # ====================================================
        mode_row = QHBoxLayout()

        self.btn_del = QPushButton("Delusions")
        self.btn_hal = QPushButton("Hallucinations")

        for b in (self.btn_del, self.btn_hal):
            b.setCheckable(True)
            b.setStyleSheet("""
                QPushButton {
                    padding:6px 14px;
                    border-radius:6px;
                    background:rgba(0,0,0,0.06);
                }
                QPushButton:checked {
                    background:rgba(0,0,0,0.18);
                }
            """)
            mode_row.addWidget(b)

        self.btn_del.setChecked(True)

        self.btn_del.clicked.connect(lambda: self._set_mode("Delusions"))
        self.btn_hal.clicked.connect(lambda: self._set_mode("Hallucinations"))

        mode_row.addStretch()
        lay.addLayout(mode_row)


        # ====================================================
        # DELUSIONS BOX — VERTICAL LAYOUT (2 columns per section)
        # ====================================================
        self.box_delusions = QWidget()
        del_lay = QVBoxLayout(self.box_delusions)
        del_lay.setSpacing(6)

        self._add_section(del_lay, "Delusional content", DELUSION_PHRASES, no_severity=False)
        self._add_section(del_lay, "Thought interference", THOUGHT_INTERFERENCE, no_severity=False)
        self._add_section(del_lay, "Passivity phenomena", PASSIVITY_PHENOMENA, no_severity=False)
        self._add_section(del_lay, "Associated with", ASSOCIATED_WITH, no_severity=True)
        lay.addWidget(self.box_delusions)
        # ====================================================
        # HALLUCINATIONS BOX
        # ====================================================
        self.box_hallucinations = QWidget()
        self.box_hallucinations.setVisible(False)
        hlay = QVBoxLayout(self.box_hallucinations)
        hlay.setSpacing(6)

        # --- Auditory hallucinations ---
        self._add_section(hlay, "Auditory", AUDITORY_HALLUCINATIONS, no_severity=False)
        self._add_section(hlay, "Other hallucinations", OTHER_HALLUCINATIONS, no_severity=False)
        self._add_section(hlay, "Associated with", HALLUCINATION_ASSOCIATED, no_severity=True)
        lay.addWidget(self.box_hallucinations)

        lay.addStretch()

        root.addWidget(scroll, 1)

        QTimer.singleShot(0, self._update_preview)
        QTimer.singleShot(0, self._refresh_highlights)

        # Add lock functionality
        add_lock_to_popup(self, show_button=False)

    # ====================================================
    # MODE SWITCH
    # ====================================================
    def _set_mode(self, mode: str):
        self.current_mode = mode
        self.btn_del.setChecked(mode == "Delusions")
        self.btn_hal.setChecked(mode == "Hallucinations")

        self.box_delusions.setVisible(mode == "Delusions")
        self.box_hallucinations.setVisible(mode == "Hallucinations")

        QTimer.singleShot(0, self._refresh_highlights)
        self._update_preview()

        
    def _current_ns(self) -> str:
        return "del" if self.current_mode == "Delusions" else "hal"

    # ====================================================
    # SECTIONS
    # ====================================================
    def _add_section(self, layout, title, items, row=None, col=None, no_severity=False):
        wrapper = QWidget()
        wrapper.setSizePolicy(
            QSizePolicy.Expanding,
            QSizePolicy.Minimum
        )

        v = QVBoxLayout(wrapper)
        v.setSpacing(4)
        v.setContentsMargins(0, 0, 0, 8)

        lbl = QLabel(title)
        lbl.setStyleSheet("font-weight:600; font-size:21px; color:#003c32; padding-left:6px;")
        v.addWidget(lbl)

        # Use 1 column for narrow panel fit
        sec = SymptomSection(cols=1)
        sec.setSizePolicy(
            QSizePolicy.Expanding,
            QSizePolicy.Minimum
        )

        # Reduce grid spacing for tighter layout
        sec.grid.setHorizontalSpacing(8)
        sec.grid.setVerticalSpacing(4)

        # Clean styling
        sec.setStyleSheet("""
            QWidget {
                border: none;
                background: transparent;
            }
        """)

        v.addWidget(sec)

        for key in items:
            row_item = sec.add_symptom(key)

            # Reduce row margins for tighter alignment
            row_item.layout().setContentsMargins(6, 4, 6, 4)

            # 🚫 Associated-with: NO severity popup, ever
            if no_severity:
                row_item.clicked.connect(
                    lambda checked=False, k=key: self._toggle_simple(
                        f"{self._current_ns()}|{k}"
                    )
                )

            else:
                # ✅ Everything else opens MiniSeverityPopup
                row_item.clicked.connect(
                    lambda checked=False, k=key: self._open_editor(k)
                )

        # ✅ THIS WAS MISSING — WITHOUT IT NOTHING RENDERS
        if row is not None and col is not None:
            layout.addWidget(wrapper, row, col)
        else:
            layout.addWidget(wrapper)


    # ====================================================
    # EDITOR
    # ====================================================
    def _open_editor(self, key):
        ns = "del" if self.current_mode == "Delusions" else "hal"
        namespaced = f"{ns}|{key}"

        sev, det = self.values.get(namespaced, (0, ""))
        pop = MiniSeverityPopup(key, sev, det, parent=self)
        pop.saved.connect(lambda k, s, d: self._save(namespaced, s, d))
        pop.show_centered(self)


    def _save(self, namespaced_key, sev, det):
        if sev > 0:
            self.values[namespaced_key] = (sev, det)
        else:
            self.values.pop(namespaced_key, None)

        self._refresh_highlights()
        self._update_preview()

        
    def max_severity(self, ns: str) -> int:
        """
        Returns the maximum severity (0–100) for a namespace
        e.g. 'del' or 'hal'
        """
        max_sev = 0
        for k, (sev, _) in self.values.items():
            if k.startswith(f"{ns}|"):
                max_sev = max(max_sev, sev)
        return max_sev

    # ====================================================
    # STATE SERIALISATION
    # ====================================================
    def get_state(self) -> dict:
        return {
            "values": self.values.copy(),
            "current_mode": self.current_mode,
        }

    def load_state(self, state: dict):
        if not state:
            return

        # Restore raw data
        self.values = state.get("values", {}).copy()

        # Restore mode FIRST (rebuilds UI)
        mode = state.get("current_mode", "Delusions")
        self._set_mode(mode)

        # Defer highlight restore until rows exist
        QTimer.singleShot(0, self._apply_highlights)


    # ====================================================
    # HIGHLIGHTS 
    # ====================================================

    def _apply_highlights(self):
        """
        Re-apply highlights based on stored values
        """
        ns = "del" if self.current_mode == "Delusions" else "hal"

        # Walk all SymptomSections
        for section in (self.box_delusions, self.box_hallucinations):
            for sec in section.findChildren(SymptomSection):
                for row in sec.rows:
                    key = f"{ns}|{row.label}"
                    active = key in self.values
                    row.set_active(active)

        self._update_preview()


    def _refresh_highlights(self):
        """
        Highlight rows based on current self.values
        """
        ns = self._current_ns()

        for sec in self.findChildren(SymptomSection):
            for row in sec.rows:
                key = f"{ns}|{row.label}"
                active = key in self.values and self.values[key][0] > 0
                row.set_active(active)

    # ====================================================
    # TEXT GENERATION ENGINE (severity-aware, non-repetitive)
    # ====================================================

    def _generate_text(self) -> str:
        """Generate the psychosis section text."""
        p = self.pron
        subj = p["subj"].capitalize()

        def selected(ns: str, mapping: dict[str, str]) -> list[str]:
            return [
                phrase for k, phrase in mapping.items()
                if f"{ns}|{k}" in self.values
            ]

        lines: list[str] = []

        # ====================================================
        # DELUSIONS
        # ====================================================
        delusions = selected("del", DELUSION_PHRASES)
        ti = selected("del", THOUGHT_INTERFERENCE)
        passivity = selected("del", PASSIVITY_PHENOMENA)
        assoc_del = selected("del", ASSOCIATED_WITH)

        # ---- Delusional content (severity ONLY from delusions)
        if delusions:
            del_content_sev = self.max_severity_for("del", DELUSION_PHRASES)
            lead = self.severity_wording(del_content_sev, "del")
            lines.append(f"{lead}, including {join_with_and(delusions)}.")

        # ---- Passivity (severity ONLY from passivity)
        if passivity:
            passivity_sev = self.max_severity_for("del", PASSIVITY_PHENOMENA)
            if passivity_sev == 3:
                lines.append(
                    "There was also significant passivity phenomena, including "
                    + join_with_and(passivity) + "."
                )
            elif passivity_sev == 2:
                lines.append(
                    "Passivity phenomena were evident, including "
                    + join_with_and(passivity) + "."
                )
            else:
                lines.append(
                    "Passivity phenomena were present, including "
                    + join_with_and(passivity) + "."
                )

        # ---- Thought interference (severity ONLY from TI)
        if ti:
            ti_sev = self.max_severity_for("del", THOUGHT_INTERFERENCE)
            if ti_sev == 3:
                lines.append(
                    "There was marked thought interference, including "
                    + join_with_and(ti) + "."
                )
            else:
                lines.append(
                    "There was evidence of thought interference, including "
                    + join_with_and(ti) + "."
                )

        # ---- Associated with (NO severity EVER)
        if assoc_del:
            lines.append(
                "These features were associated with "
                + join_with_and(assoc_del) + "."
            )

        # ====================================================
        # HALLUCINATIONS
        # ====================================================
        aud = selected("hal", AUDITORY_HALLUCINATIONS)
        other = selected("hal", OTHER_HALLUCINATIONS)
        assoc_hal = selected("hal", HALLUCINATION_ASSOCIATED)

        # Auditory hallucinations sentence
        if aud:
            aud_sev = self.max_severity_for("hal", AUDITORY_HALLUCINATIONS)
            lead = self.severity_wording(aud_sev, "hal")
            lines.append(lead + ", auditory phenomena including " + join_with_and(aud) + ".")

        # Other hallucinations as separate sentence
        if other:
            lines.append(
                f"{subj} also described hallucinations in other modalities including "
                + join_with_and(other) + "."
            )

        # ---- Associated with (hallucinations, NO severity) - use semicolons
        if assoc_hal:
            lines.append(
                "These experiences were associated with "
                + join_with_semicolons(assoc_hal) + "."
            )

        return "\n".join(lines)

    def _update_preview(self):
        """Legacy method name - now sends to card immediately."""
        self._send_to_card()

    def _send_to_card(self):
        """Send current text to card immediately."""
        text = self._generate_text().strip()
        if text:
            payload = {
                "text": text,
                "state": {
                    "values": self.values,
                    "current_mode": self.current_mode,
                },
            }
            self.saved.emit(payload)

        
    # ====================================================
    # SEND AND CLOSE
    # ====================================================
    def _send(self):
        text = self._generate_text().strip()
        if not text:
            return

        payload = {
            "text": text,
            "state": {
                "values": self.values,
                "current_mode": self.current_mode,
            },
        }

        self.saved.emit(payload)
        self.close()

    def closeEvent(self, event):
        """
        Persist state even if user closes with X
        """
        self.saved.emit({
            "values": self.values,
            "mode": self.current_mode,
            "text": self._generate_text().strip(),
        })
        super().closeEvent(event)

    def hideEvent(self, event):
        """Save state when popup is hidden (navigating away)."""
        self.saved.emit({
            "values": self.values,
            "mode": self.current_mode,
            "text": self._generate_text().strip(),
        })
        super().hideEvent(event)
