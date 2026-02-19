from __future__ import annotations
from PySide6.QtCore import Qt, QTimer, Signal
from PySide6.QtWidgets import (
    QWidget, QLabel, QPushButton, QVBoxLayout, QHBoxLayout,
    QScrollArea, QTextEdit, QSlider, QComboBox, QSizePolicy, QCheckBox
)

from anxiety_widgets import SymptomSection
from mini_severity_popup import MiniSeverityPopup
from shared_widgets import add_lock_to_popup
from spell_check_textedit import enable_spell_check_on_textedit


# ============================================================
#  PRONOUN ENGINE
# ============================================================
def pronouns_from_gender(g):
    g = (g or "").lower().strip()
    if g == "male":
        return {"subj": "he", "obj": "him", "pos": "his",
                "be_present": "is", "be_past": "was", "have_present": "has"}
    if g == "female":
        return {"subj": "she", "obj": "her", "pos": "her",
                "be_present": "is", "be_past": "was", "have_present": "has"}
    return {"subj": "they", "obj": "them", "pos": "their",
            "be_present": "are", "be_past": "were", "have_present": "have"}


# ============================================================
#  SYMPTOM DEFINITIONS
# ============================================================
SYMPTOMS = {
    "Anxiety/Panic/Phobia": [
        "palpitations",
        "breathing difficulty",
        "dry mouth",
        "sweating",
        "shaking",
        "chest pain/discomfort",
        "hot flashes/cold chills",
        "concentration issues",
        "being irritable",
        "numbness/tingling",
        "restlessness",
        "dizzy/faint",
        "nausea/abdo distress",
        "swallowing difficulties",
        "choking",
        "on edge",
        "increased startle",
        "muscle tension/aches",
        "initial insomnia",
        "Fear of dying",
        "Fear of losing control",
        "depersonalisation/derealisation",
    ],

    "OCD": [
        "intrusive thoughts",
        "obsessional images",
        "rituals/compulsions",
        "checking",
        "washing/cleaning",
        "orderliness/symmetry",
        "reassurance-seeking",
        "mental rituals",
    ],

    "PTSD": [
        "accidental trauma",
        "current trauma",
        "historical trauma",
        "flashbacks",
        "imagery",
        "intense memories",
        "nightmares",
        "distress",
        "hyperarousal",
        "avoidance",
        "fear",
        "numbness/depersonalisation",
    ],
}

PHOBIA_SUB_SYMPTOMS = {
    "Agoraphobia": [
        "crowds",
        "public places",
        "travelling alone",
        "travel away from home",
    ],
    "Specific phobia": [
        "animals",
        "blood",
        "simple phobia",
        "exams",
        "small spaces",
    ],
    "Social phobia": [
        "social situations",
    ],
    "Hypochondriacal": [
        "heart disease",
        "body shape (dysmorphic)",
        "specific",
        "organ cancer",
    ],
}

PHOBIA_SUB_PHRASES = {
    "Agoraphobia": {
        "crowds": "being anxious in crowded places",
        "public places": "being avoidant of public places",
        "travelling alone": "not liking travelling alone",
        "travel away from home": "being anxious when leaving home",
    },

    "Specific phobia": {
        "animals": "animals",
        "blood": "the sight of blood",
        "simple phobia": "",
        "exams": "exams",
        "small spaces": "small spaces",
    },

    "Social phobia": {
        "social situations": "having anxiety mainly in the presence of others",
    },

    "Hypochondriacal": {
        "heart disease": "fears of having heart disease",
        "body shape (dysmorphic)": "distorted belief about body shape (dysmorphic)",
        "specific": "concerns about a specific organ",
        "organ cancer": "being worried about having cancer",
    },
}

OVERLAP_SYMPTOMS = {
        "palpitations",
        "breathing difficulty",
        "sweating",
        "shaking",
        "choking",
        "nausea/abdo distress",
        "hot flashes/cold chills",
        "dizzy/faint",
        "Fear of dying",
        "Fear of losing control",
}

# ============================================================
# OCD STRUCTURE (REVISED, CLINICALLY ALIGNED)
# ============================================================
OCD_STRUCTURE = {
    "Thoughts": [
        "impulses",
        "ideas",
        "magical thoughts",
        "images",
        "ruminations",
    ],

    "Compulsions": [
        "obsessional slowness",
        "gas/elec checking",
        "lock-checking",
        "cleaning",
        "handwashing",
    ],

    "Associated with": [
        "fear",
        "relief/contentment",
        "distress",
        "depers/dereal",
        "tries to resist",
        "recognised as own thoughts",
    ],

    # Radio button groups (mutually exclusive within each group)
    "Comorbid depression prominence": [
        "less",
        "equal",
        "more",
    ],

    "Organic mental disorder": [
        "present",
        "absent",
    ],

    "Schizophrenia": [
        "present",
        "absent",
    ],

    "Tourette's": [
        "present",
        "absent",
    ],
}

# Sections that should behave as radio buttons (mutually exclusive)
OCD_RADIO_SECTIONS = {
    "Comorbid depression prominence",
    "Organic mental disorder",
    "Schizophrenia",
    "Tourette's",
}

# ============================================================
# OCD PHRASES (FREE TEXT, CLINICAL)
# ============================================================
OCD_PHRASES = {
    "Thoughts": {
        "impulses": "obsessive impulses",
        "ideas": "overwhelming recurrent obsessional ideas",
        "magical thoughts": "magical thinking",
        "images": "recurrent intrusive imagery",
        "ruminations": "excessive rumination",
    },

    "Compulsions": {
        "obsessional slowness": "compulsions took a long time",
        "gas/elec checking": "recurrently checking gas/electrics",
        "lock-checking": "excessive lock-checking",
        "cleaning": "overcleaning",
        "handwashing": "compulsive handwashing",
    },

    "Associated with": {
        "fear": "a sense of fear",
        "relief/contentment": "a feeling of relief after carrying out the act",
        "distress": "significant distress",
        "depers/dereal": "feeling unreal with depersonalisation/derealisation",
        # "tries to resist" handled specially with pronoun in generate_text
        "recognised as own thoughts": "recognising the thoughts/acts as their own",
    },

    "Comorbid depression prominence": {
        "less": "depression that was less prominent than the OCD",
        "equal": "depression that was equally prominent as the OCD",
        "more": "depression that was more prominent than the OCD",
    },

    "Organic mental disorder": {
        "present": "organic mental disorder was present",
        "absent": "organic mental disorder was absent",
    },

    "Schizophrenia": {
        "present": "schizophrenia was present",
        "absent": "schizophrenia was absent",
    },

    "Tourette's": {
        "present": "comorbid Tourette's syndrome was noted",
        "absent": "there was no comorbid Tourette's syndrome",
    },
}


PTSD_STRUCTURE = {
        "Precipitating event": [
                "accidental",
                "current",
                "historical",
        ],

        "Recurrent symptoms": [
                "flashbacks",
                "imagery",
                "intense memories",
                "nightmares",
        ],

        "Onset": [
                "within six months",
        ],

        "Associated with": [
                "distress",
                "hyperarousal",
                "avoidance",
                "fear",
                "numbness/depersonalisation",
        ],
}

PTSD_PHRASES = {
        "Precipitating event": {
                "accidental": "accidental trauma",
                "current": "ongoing trauma/abuse",
                "historical": "past trauma/abuse",
        },

        "Recurrent symptoms": {
                "flashbacks": "vivid, video-like flashbacks",
                "imagery": "recurrent imagery of the events",
                "intense memories": "intense and overwhelming memories",
                "nightmares": "distressing nightmares",
        },

        "Onset": {
                "within six months": " - symptoms commenced within six months of the precipitating event",
        },

        "Associated with": {
                "distress": "significant distress on discussion",
                "hyperarousal": "feelings of anxiety and panic on recall",
                "avoidance": "avoidance of sharing the event",
                "fear": "recurrent fear",
                "numbness/depersonalisation": "a sense of numbness and depersonalisation around the event",
        },
}


def summarise_symptoms(symptom_items):
    """
    symptom_items = list of (label, severity, details)
    severity: 1=mild, 2=moderate, 3=severe
    """
    labels = [lbl for lbl, _, _ in symptom_items]
    severities = [sev for _, sev, _ in symptom_items]

    if not severities:
        return None, None

    unique_sev = sorted(set(severities))

    if len(unique_sev) == 1:
        sev_map = {1: "mild", 2: "moderate", 3: "severe"}
        severity_phrase = f"all {sev_map[unique_sev[0]]}"
    else:
        counts = {s: severities.count(s) for s in unique_sev}
        dominant = max(counts, key=counts.get)

        sev_map = {1: "mild", 2: "moderate", 3: "severe"}
        severity_phrase = (
            f"predominantly {sev_map[dominant]} "
            f"with intermittent {', '.join(sev_map[s] for s in unique_sev if s != dominant)} symptoms"
        )

    joined = (
        ", ".join(labels[:-1]) + f", and {labels[-1]}"
        if len(labels) > 1 else labels[0]
    )

    return joined, severity_phrase



# ============================================================
#  SEVERITY & TIMECOURSE HELPERS  ← 🔴 PUT IT HERE
# ============================================================

from collections import Counter

def weighted_severity_phrase(severities):
    if not severities:
        return ""

    c = Counter(severities)
    sev_map = {1: "mild", 2: "moderate", 3: "severe"}

    if len(c) == 1:
        return f"all {sev_map[next(iter(c))]}"

    dominant, count = c.most_common(1)[0]
    total = sum(c.values())

    if count / total >= 0.6:
        others = [sev_map[s] for s in c if s != dominant]
        return (
            f"predominantly {sev_map[dominant]} "
            f"with intermittent {', '.join(others)} symptoms"
        )

    return "of mixed severity"


def summarise_symptoms_weighted(items):
    labels = [lbl for lbl, _, _ in items]
    severities = [sev for _, sev, _ in items]

    if not labels:
        return "", ""

    # Transform certain labels for better grammar
    label_transforms = {
        "irritable": "being irritable",
        "dry mouth": "having a dry mouth",
        "on edge": "feeling on edge",
    }
    labels = [label_transforms.get(lbl, lbl) for lbl in labels]

    # Special handling for Fear of losing control / Fear of dying
    has_fear_control = "Fear of losing control" in labels
    has_fear_dying = "Fear of dying" in labels

    if has_fear_control and has_fear_dying:
        # Remove both and add combined phrase
        labels = [l for l in labels if l not in ("Fear of losing control", "Fear of dying")]
        labels.append("a fear of losing control and of dying")
    elif has_fear_control:
        labels = [("a fear of losing control" if l == "Fear of losing control" else l) for l in labels]
    elif has_fear_dying:
        labels = [("a fear of dying" if l == "Fear of dying" else l) for l in labels]

    joined = (
        ", ".join(labels[:-1]) + f", and {labels[-1]}"
        if len(labels) > 1 else labels[0]
    )

    return joined, weighted_severity_phrase(severities)


def infer_timecourse(items):
    severities = [sev for _, sev, _ in items]
    if not severities:
        return ""

    avg = sum(severities) / len(severities)

    if avg < 1.5:
        return "intermittent"
    if avg < 2.5:
        return "episodic"
    return "persistent"


def should_merge_panic_anxiety(anxiety_items, panic_items):
    if len(anxiety_items) < 2 or len(panic_items) < 2:
        return False

    anx = {lbl for lbl, _, _ in anxiety_items}
    pan = {lbl for lbl, _, _ in panic_items}

    return bool(anx & pan)

def _domain_has_content(domain_dict: dict) -> bool:
    return any(bool(v) for v in domain_dict.values())




# ============================================================
#  MAIN POPUP
# ============================================================
class AnxietyPopup(QWidget):
    sent = Signal(str, dict)   # text, state

    def update_gender(self, gender: str):
        """Update pronouns when gender changes on front page."""
        self.gender = gender
        self.p = pronouns_from_gender(gender)
        self._send_to_card()
        
    def __init__(self, first_name: str, gender: str, parent=None):
        super().__init__(parent)

        print(">>> AnxietyPopup INIT START:", __file__)
        sent = Signal(str)
        self.first_name = first_name or "The patient"
        self.gender = gender
        self.p = pronouns_from_gender(gender)

        self.values = {
            "Anxiety/Panic/Phobia": {},
        }

        # Panic and phobia associations
        self.panic_associated = False
        self.panic_severity = "moderate"
        self.avoidance_associated = False
        self.avoidance_phobia_type = ""
        self.avoidance_severity = "moderate"

        self.ocd_values = {
            "Thoughts": set(),
            "Compulsions": set(),
            "Associated with": set(),
            "Comorbidity": set(),
        }

        self.ptsd_values = {
                "Precipitating event": set(),
                "Recurrent symptoms": set(),
                "Onset": set(),
                "Associated with": set(),
        }

        self.current_mode = None  # Anxiety / Panic / Phobia / OCD / PTSD

        # Fixed panel style (not draggable)
        self.setWindowFlags(Qt.WindowType.Widget)
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

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
        container.setObjectName("anx_popup")
        container.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)
        container.setStyleSheet("""
            QWidget#anx_popup {
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
        self.phobia_sub_rows = []   # ← track injected rows
        self.phobia_sub_selected = set()
        self.phobia_subtype_values = {}
        self._ptsd_started = False
        self._ocd_started = False

        


        # ============================================================
        # MODE BUTTONS (title removed - shown in panel header)
        # ============================================================
        mode = QHBoxLayout()

        self.btns = {
            "Anxiety/Panic/Phobia": QPushButton("Anxiety/Panic/Phobia"),
            "OCD": QPushButton("OCD"),
            "PTSD": QPushButton("PTSD")
        }

        for key, b in self.btns.items():
                b.setCheckable(True)
                b.setStyleSheet("""
                        QPushButton {
                                padding:6px 14px; border-radius:6px;
                                background:rgba(0,0,0,0.05);
                        }
                        QPushButton:checked {
                                background:rgba(0,0,0,0.15);
                        }
                """)

                b.clicked.connect(self._make_mode_handler(key))
                mode.addWidget(b)


        lay.addLayout(mode)

        # ============================================================
        # SYMPTOMS HEADER
        # ============================================================
        symptoms_header = QHBoxLayout()
        symptoms_header.setSpacing(12)

        symptoms_lbl = QLabel("Symptoms")
        symptoms_lbl.setStyleSheet(
                "font-size:21px; font-weight:700; color:#003c32;"
        )
        symptoms_header.addWidget(symptoms_lbl)
        symptoms_header.addStretch()

        lay.addLayout(symptoms_header)

        # ============================================================
        # MAIN SYMPTOM SECTION (2 columns)
        # ============================================================
        self.sec = SymptomSection(cols=2)
        lay.addWidget(self.sec)

        # ============================================================
        # PANIC & AVOIDANCE ASSOCIATIONS (shown when symptoms selected)
        # ============================================================
        self.associations_box = QWidget()
        self.associations_box.setVisible(False)
        assoc_lay = QVBoxLayout(self.associations_box)
        assoc_lay.setContentsMargins(12, 8, 12, 8)
        assoc_lay.setSpacing(8)

        # --- PANIC ATTACKS ---
        panic_row = QHBoxLayout()
        self.panic_checkbox = QCheckBox("Associated with panic attacks")
        self.panic_checkbox.setStyleSheet("font-size:21px;")
        self.panic_checkbox.toggled.connect(self._on_panic_toggled)
        panic_row.addWidget(self.panic_checkbox)

        self.panic_severity_combo = QComboBox()
        self.panic_severity_combo.addItems(["mild", "moderate", "severe"])
        self.panic_severity_combo.setCurrentText("moderate")
        self.panic_severity_combo.setFixedWidth(100)
        self.panic_severity_combo.setVisible(False)
        self.panic_severity_combo.currentTextChanged.connect(self._on_panic_severity_changed)
        panic_row.addWidget(self.panic_severity_combo)
        panic_row.addStretch()
        assoc_lay.addLayout(panic_row)

        # --- AVOIDANCE / PHOBIA ---
        avoid_row = QHBoxLayout()
        self.avoidance_checkbox = QCheckBox("Associated with avoidance")
        self.avoidance_checkbox.setStyleSheet("font-size:21px;")
        self.avoidance_checkbox.toggled.connect(self._on_avoidance_toggled)
        avoid_row.addWidget(self.avoidance_checkbox)

        self.phobia_type_combo = QComboBox()
        self.phobia_type_combo.addItems([
                "click to define",
                "Agoraphobia",
                "Specific phobia",
                "Social phobia",
                "Hypochondriacal"
        ])
        self.phobia_type_combo.setFixedWidth(180)
        self.phobia_type_combo.setVisible(False)
        self.phobia_type_combo.currentTextChanged.connect(self._on_phobia_type_changed)
        avoid_row.addWidget(self.phobia_type_combo)
        avoid_row.addStretch()
        assoc_lay.addLayout(avoid_row)

        # --- PHOBIA SUB-SYMPTOMS (shown below phobia type when selected) ---
        self.phobia_sub_container = QWidget()
        self.phobia_sub_container.setVisible(False)
        phobia_sub_lay = QVBoxLayout(self.phobia_sub_container)
        phobia_sub_lay.setContentsMargins(24, 4, 0, 4)
        phobia_sub_lay.setSpacing(4)

        self.phobia_sub_checkboxes = {}
        assoc_lay.addWidget(self.phobia_sub_container)

        # --- PHOBIA SEVERITY (below sub-symptoms) ---
        severity_row = QHBoxLayout()
        severity_row.setContentsMargins(24, 0, 0, 0)
        self.phobia_severity_label = QLabel("Severity:")
        self.phobia_severity_label.setStyleSheet("font-size:21px; color:#555;")
        self.phobia_severity_label.setVisible(False)
        severity_row.addWidget(self.phobia_severity_label)

        self.avoidance_severity_combo = QComboBox()
        self.avoidance_severity_combo.addItems(["mild", "moderate", "severe"])
        self.avoidance_severity_combo.setCurrentText("moderate")
        self.avoidance_severity_combo.setFixedWidth(100)
        self.avoidance_severity_combo.setVisible(False)
        self.avoidance_severity_combo.currentTextChanged.connect(self._on_avoidance_severity_changed)
        severity_row.addWidget(self.avoidance_severity_combo)
        severity_row.addStretch()
        assoc_lay.addLayout(severity_row)

        lay.addWidget(self.associations_box)

        # Keep references for compatibility (hidden/unused)
        self.phobia_sub_box = QWidget()
        self.phobia_sub_box.setVisible(False)
        self.phobia_sub_grid = SymptomSection(cols=2)
        self.phobia_sub_rows = []
        self.phobia_sub_selected = set()
        self.phobia_subtype_values = {}

        # ============================================================
        # OCD STRUCTURED BOX
        # ============================================================
        self.ocd_box = QWidget()
        self.ocd_box.setVisible(False)

        ocd_lay = QVBoxLayout(self.ocd_box)
        ocd_lay.setSpacing(10)

        self.ocd_sections = {}

        for section, items in OCD_STRUCTURE.items():
                lbl = QLabel(section.upper())
                lbl.setStyleSheet("font-size:21px; font-weight:600; color:#003c32;")
                ocd_lay.addWidget(lbl)

                grid = SymptomSection(cols=2)
                ocd_lay.addWidget(grid)

                for item in items:
                        row = grid.add_symptom(item)
                        row.clicked.connect(
                                lambda *_, s=section, i=item: self._toggle_ocd_item(s, i)
                        )

                self.ocd_sections[section] = grid

        lay.addWidget(self.ocd_box)

        # ============================================================
        # PTSD STRUCTURED BOX
        # ============================================================
        self.ptsd_box = QWidget()
        self.ptsd_box.setVisible(False)

        ptsd_lay = QVBoxLayout(self.ptsd_box)
        ptsd_lay.setSpacing(10)

        self.ptsd_sections = {}

        for section, items in PTSD_STRUCTURE.items():
                lbl = QLabel(section.upper())
                lbl.setStyleSheet("font-size:21px; font-weight:600; color:#003c32;")
                ptsd_lay.addWidget(lbl)

                grid = SymptomSection(cols=2)
                ptsd_lay.addWidget(grid)

                for item in items:
                        row = grid.add_symptom(item)
                        row.clicked.connect(
                                lambda *_, s=section, i=item: self._toggle_ptsd_item(s, i)
                        )

                self.ptsd_sections[section] = grid

        lay.addWidget(self.ptsd_box)
        self.ptsd_box.setVisible(False)

        lay.addStretch()

        root.addWidget(scroll, 1)

        QTimer.singleShot(40, self._send_to_card)
        QTimer.singleShot(0, lambda: self.set_mode("Anxiety/Panic/Phobia"))
        print(">>> AnxietyPopup INIT END")

        # Add lock functionality
        add_lock_to_popup(self, show_button=False)

    def _send_to_letter(self):
        text = self.generate_text().strip()
        if not text:
            return

        state = self.get_state()

        print("✅ AnxietyPopup emitting text + state")
        self.sent.emit(text, state)
        self.close()

        
    def _make_mode_handler(self, mode_name):
        def handler(*args, **kwargs):
            self.set_mode(mode_name)
        return handler




    # ============================================================
    # MODE SELECTION
    # ============================================================
    def set_mode(self, mode: str):
        # Update mode buttons
        for key, b in self.btns.items():
            b.setChecked(key == mode)

        self.current_mode = mode

        # Show/hide appropriate sections
        if mode == "OCD":
            self.sec.setVisible(False)
            self.ocd_box.setVisible(True)
            self.ptsd_box.setVisible(False)
            self.associations_box.setVisible(False)

        elif mode == "PTSD":
            self.sec.setVisible(False)
            self.ocd_box.setVisible(False)
            self.ptsd_box.setVisible(True)
            self.associations_box.setVisible(False)

        else:  # Anxiety/Panic/Phobia
            self.sec.setVisible(True)
            self.ocd_box.setVisible(False)
            self.ptsd_box.setVisible(False)
            # Associations box visibility will be checked after symptom grid is built

        # --- SYMPTOMS GRID ---
        self.sec.clear_rows()
        self.sec.cols = 2  # Always 2 columns for the merged section

        # Build symptom grid for Anxiety/Panic/Phobia
        if mode == "Anxiety/Panic/Phobia":
            for s in SYMPTOMS["Anxiety/Panic/Phobia"]:
                row = self.sec.add_symptom(s)
                row.clicked.connect(lambda *_, lbl=s: self._open_editor(lbl))

        self._refresh_symptom_highlights()
        self._update_preview()

        # Check if associations box should be visible
        self._check_show_associations()

        # -------------------------------------------------
        # Restore highlights AFTER rows are built
        # -------------------------------------------------
        QTimer.singleShot(0, self._apply_all_highlights)


    # ============================================================
    # EDITOR POPUP
    # ============================================================
    def _open_editor(self, label):
        mode = self.current_mode
        if not mode:
            return

        sev, det = self.values.get(mode, {}).get(label, (0, ""))

        pop = MiniSeverityPopup(label, sev, det, parent=self)
        pop.saved.connect(self._save_symptom)
        pop.show_centered(self)


    # ============================================================
    # HIGHLIGHTER
    # ============================================================
        
    def _is_symptom_modified(self, mode: str, label: str) -> bool:
        sev, det = self.values.get(mode, {}).get(label, (0, ""))
        return sev > 0 or bool(det.strip())

    def _refresh_row_highlights(self):
        mode = self.current_mode
        if not mode:
            return

        for row in self.sec.rows.values():
            label = row.label
            active = self._is_symptom_modified(mode, label)
            row.set_active(active)

    def _refresh_symptom_highlights(self):
        """
        Highlights symptoms that have non-zero severity or details
        in the CURRENT MODE.
        """
        mode = self.current_mode
        if not mode:
            return

        active = self.values.get(mode, {})

        for row in self.sec.rows:
            sev, det = active.get(row.label, (0, ""))
            is_modified = sev > 0 or bool(det.strip())
            row.set_active(is_modified)



    def _save_symptom(self, label, sev, det):
        mode = self.current_mode
        if not mode:
            return

        self.values.setdefault(mode, {})
        self.values[mode][label] = (sev, det)

        self._refresh_symptom_highlights()
        self._check_show_associations()
        self._update_preview()


    # ============================================================
    # OCD TOGGLE HANDLER
    # ============================================================
    def _toggle_ocd_item(self, section, label):
        bucket = self.ocd_values.setdefault(section, set())

        # ---- RADIO SECTION ENFORCEMENT (mutually exclusive) ----
        if section in OCD_RADIO_SECTIONS:
            # Clear all other options in this section first
            bucket.clear()
            # Update all row highlights to off
            grid = self.ocd_sections.get(section)
            if grid:
                for row in grid.rows:
                    row.set_active(False)

        # Toggle selected label
        if label in bucket:
            bucket.remove(label)
            active = False
        else:
            bucket.add(label)
            active = True

        # Highlight immediately
        grid = self.ocd_sections.get(section)
        if grid:
            for row in grid.rows:
                if row.label == label:
                    row.set_active(active)
                    break

        self._update_preview()

    # ============================================================
    # PTSD TOGGLE HANDLER
    # ============================================================

    def _toggle_ptsd_item(self, section, label):
            bucket = self.ptsd_values.setdefault(section, set())

            # Precipitating event is mutually exclusive (radio buttons)
            if section == "Precipitating event":
                    bucket.clear()
                    # Clear all row highlights in this section
                    grid = self.ptsd_sections.get(section)
                    if grid:
                        for row in grid.rows:
                            row.set_active(False)

            if label in bucket:
                bucket.remove(label)
                active = False
            else:
                bucket.add(label)
                active = True

            grid = self.ptsd_sections.get(section)
            if grid:
                for row in grid.rows:
                    if row.label == label:
                        row.set_active(active)
                        break

            self._update_preview()


    # ============================================================
    # HYBRID NARRATIVE
    # ============================================================
    def _update_preview(self):
        """Legacy method name - now sends to card immediately."""
        self._send_to_card()

    def _send_to_card(self):
        """Send current text to card immediately."""
        text = self.generate_text().strip()
        if text:
            state = self.get_state()
            self.sent.emit(text, state)

    def generate_text(self) -> str:
        print("DEBUG values:", self.values)
        print("DEBUG PTSD:", self.ptsd_values)

        # Reset section headers for fresh generation each time
        self._ocd_started = False
        self._ptsd_started = False

        p = []
        fn = self.first_name

        # ============================================================
        # COLLECT ANXIETY/PANIC/PHOBIA SYMPTOMS
        # ============================================================
        anxiety_items = {}
        mode_values = self.values.get("Anxiety/Panic/Phobia", {})

        for lbl in SYMPTOMS.get("Anxiety/Panic/Phobia", []):
            if lbl in mode_values and mode_values[lbl][0] > 0:
                anxiety_items[lbl] = mode_values[lbl]

        # ============================================================
        # ANXIETY SYMPTOMS OUTPUT
        # ============================================================
        if anxiety_items:
            items_list = [(lbl, *anxiety_items[lbl]) for lbl in anxiety_items]
            joined, sev_phrase = summarise_symptoms_weighted(items_list)

            # Build the base sentence
            base_sentence = f"{fn} reported anxiety symptoms including {joined} ({sev_phrase})"

            # --- BUILD ASSOCIATION PHRASE ---
            association_parts = []

            # Panic attacks
            if self.panic_associated:
                association_parts.append(f"{self.panic_severity} panic")

            # Phobia
            phobia_type = self.avoidance_phobia_type
            has_phobia = (
                self.avoidance_associated and
                phobia_type and
                phobia_type != "click to define"
            )
            if has_phobia:
                phobia_type_lc = phobia_type.lower()
                association_parts.append(f"{self.avoidance_severity} {phobia_type_lc}")

            # Combine into sentence
            if association_parts:
                if len(association_parts) == 2:
                    assoc_text = f"both {association_parts[0]} and {association_parts[1]}"
                else:
                    assoc_text = association_parts[0]
                    # Add "attacks" for panic if it's alone
                    if self.panic_associated and not has_phobia:
                        assoc_text = f"{self.panic_severity} panic attacks"

                base_sentence += f". These symptoms were associated with {assoc_text}"

                # Add phobia sub-symptoms if any selected
                if has_phobia and self.phobia_sub_selected:
                    sub_phrases = []
                    for sub in self.phobia_sub_selected:
                        phrase = PHOBIA_SUB_PHRASES.get(phobia_type, {}).get(sub, sub)
                        if phrase:
                            sub_phrases.append(phrase)
                    if sub_phrases:
                        if len(sub_phrases) == 1:
                            sub_joined = sub_phrases[0]
                        elif len(sub_phrases) == 2:
                            sub_joined = f"{sub_phrases[0]} and {sub_phrases[1]}"
                        else:
                            sub_joined = ", ".join(sub_phrases[:-1]) + f" and {sub_phrases[-1]}"

                        # For specific phobia, add "to" prefix
                        if phobia_type == "Specific phobia":
                            base_sentence += f" to {sub_joined}"
                        else:
                            base_sentence += f", with {sub_joined}"

                base_sentence += "."
            else:
                base_sentence += "."

            p.append(base_sentence)

        # ============================================================
        # OCD (STRUCTURED, CLINICALLY CLEAN — ONE SENTENCE PER DOMAIN)
        # ============================================================

        thoughts = self.ocd_values.get("Thoughts", set())
        compulsions = self.ocd_values.get("Compulsions", set())

        has_ocd_core = bool(thoughts or compulsions)

        if has_ocd_core:

            if not self._ocd_started:
                p.append("")  # Empty line before OCD section
                p.append("**OCD symptoms:**")
                self._ocd_started = True

        thoughts = sorted(self.ocd_values.get("Thoughts", []))
        compulsions = sorted(self.ocd_values.get("Compulsions", []))
        assoc = sorted(self.ocd_values.get("Associated with", []))

        # ---- THOUGHTS ----
        if thoughts:
            phrases = [
                OCD_PHRASES["Thoughts"].get(t, t)
                for t in thoughts
            ]
            joined = (
                ", ".join(phrases[:-1]) + f", and {phrases[-1]}"
                if len(phrases) > 1
                else phrases[0]
            )
            p.append(
                f"{fn} described obsessional thoughts, including {joined}."
            )

        # ---- COMPULSIONS ----
        if compulsions:
            phrases = [
                OCD_PHRASES["Compulsions"].get(c, c)
                for c in compulsions
            ]
            joined = (
                ", ".join(phrases[:-1]) + f", and {phrases[-1]}"
                if len(phrases) > 1
                else phrases[0]
            )
            p.append(
                f"{self.p['subj'].capitalize()} described compulsive behaviours such as {joined}."
            )

        # ---- ASSOCIATED WITH (ONLY IF CORE OCD EXISTS) ----
        assoc = self.ocd_values.get("Associated with", set())
        if has_ocd_core and assoc:
                phrases = []
                for a in assoc:
                    if a == "tries to resist":
                        # Special handling with pronoun
                        phrases.append(f"{self.p['subj']} tries to resist these thoughts/acts")
                    elif a == "recognised as own thoughts":
                        # Use correct possessive pronoun
                        phrases.append(f"recognising the thoughts/acts as {self.p['pos']} own")
                    else:
                        phrases.append(OCD_PHRASES["Associated with"].get(a, a))
                joined = (
                        ", ".join(phrases[:-1]) + f", and {phrases[-1]}"
                        if len(phrases) > 1 else phrases[0]
                )
                p.append(
                        f"These symptoms were associated with {joined}."
                )

        # ---- COMORBIDITY RADIO SECTIONS (ONLY IF CORE OCD EXISTS) ----
        if has_ocd_core:
            comorb_phrases = []

            # Depression prominence
            depression = self.ocd_values.get("Comorbid depression prominence", set())
            if depression:
                val = next(iter(depression))
                phrase = OCD_PHRASES["Comorbid depression prominence"].get(val, "")
                if phrase:
                    comorb_phrases.append(phrase)

            # Organic mental disorder
            organic = self.ocd_values.get("Organic mental disorder", set())
            if organic:
                val = next(iter(organic))
                phrase = OCD_PHRASES["Organic mental disorder"].get(val, "")
                if phrase:
                    comorb_phrases.append(phrase)

            # Schizophrenia
            schizo = self.ocd_values.get("Schizophrenia", set())
            if schizo:
                val = next(iter(schizo))
                phrase = OCD_PHRASES["Schizophrenia"].get(val, "")
                if phrase:
                    comorb_phrases.append(phrase)

            # Tourette's
            tourettes = self.ocd_values.get("Tourette's", set())
            if tourettes:
                val = next(iter(tourettes))
                phrase = OCD_PHRASES["Tourette's"].get(val, "")
                if phrase:
                    comorb_phrases.append(phrase)

            if comorb_phrases:
                joined = (
                    ", ".join(comorb_phrases[:-1]) + f", and {comorb_phrases[-1]}"
                    if len(comorb_phrases) > 1 else comorb_phrases[0]
                )
                p.append(
                    f"Relevant comorbid considerations included {joined}."
                )

                # Special handling for schizophrenia present
                if schizo and "present" in schizo:
                    p.append(
                        "In view of this, a formal diagnosis of obsessive–compulsive disorder was not made."
                    )


        has_ptsd = any(self.ptsd_values.values())        
        # ============================================================
        # PTSD (STRUCTURED, PHRASE-AWARE, DOMAIN-BOUND)
        # ============================================================
        ptsd = self.ptsd_values
        has_ptsd_core = (
            bool(ptsd.get("Precipitating event")) or
            bool(ptsd.get("Recurrent symptoms")) or
            bool(ptsd.get("Onset"))
        )
        if has_ptsd_core:

                if not self._ptsd_started:
                        p.append("")  # Empty line before PTSD section
                        p.append("**PTSD symptoms:**")
                        self._ptsd_started = True

                # --- PRECIPITATING EVENT ---
                precip = ptsd.get("Precipitating event", set())
                if precip:
                        phrases = [
                                PTSD_PHRASES["Precipitating event"].get(pe, pe)
                                for pe in precip
                        ]
                        joined = (
                                ", ".join(phrases[:-1]) + f", and {phrases[-1]}"
                                if len(phrases) > 1 else phrases[0]
                        )
                        p.append(f"{fn} described post-traumatic stress features following {joined}.")

                # --- RECURRENT SYMPTOMS ---
                recurrent = ptsd.get("Recurrent symptoms", set())
                if recurrent:
                        phrases = [
                                PTSD_PHRASES["Recurrent symptoms"].get(r, r)
                                for r in recurrent
                        ]
                        joined = (
                                ", ".join(phrases[:-1]) + f", and {phrases[-1]}"
                                if len(phrases) > 1 else phrases[0]
                        )
                        # --- ONSET (appended to recurrent symptoms) ---
                        onset = ptsd.get("Onset", set())
                        onset_phrase = ""
                        if onset:
                                onset_phrase = PTSD_PHRASES["Onset"].get(
                                        next(iter(onset)),
                                        next(iter(onset))
                                )
                        sentence = f"There were recurrent symptoms including {joined}"
                        if onset_phrase:
                            sentence += onset_phrase  # onset already has " - " prefix
                        sentence += "."
                        p.append(sentence)

                # --- ASSOCIATED FEATURES (ONLY IF CORE PTSD EXISTS) ---
                assoc = ptsd.get("Associated with", set())
                if assoc:
                        phrases = [
                                PTSD_PHRASES["Associated with"].get(a, a)
                                for a in assoc
                        ]
                        joined = (
                                ", ".join(phrases[:-1]) + f", and {phrases[-1]}"
                                if len(phrases) > 1 else phrases[0]
                        )
                        p.append(
                                f"These symptoms were associated with {joined}."
                        )


        return "\n".join(p)
    # ============================================================
    # STATE SERIALISATION (FOR LETTER RE-OPEN)
    # ============================================================
    def get_state(self) -> dict:
        return {
            "values": self.values,
            "ocd_values": self.ocd_values,
            "ptsd_values": self.ptsd_values,
            "phobia_subtype_values": self.phobia_subtype_values,
            "_ptsd_started": self._ptsd_started,
            "_ocd_started": self._ocd_started,
            "current_mode": self.current_mode,
            # Panic/avoidance associations
            "panic_associated": self.panic_associated,
            "panic_severity": self.panic_severity,
            "avoidance_associated": self.avoidance_associated,
            "avoidance_phobia_type": self.avoidance_phobia_type,
            "avoidance_severity": self.avoidance_severity,
            "phobia_sub_selected": list(self.phobia_sub_selected),
        }


    def _apply_loaded_state(self, mode: str):
        # Main symptoms
        active = self.values.get(mode, {})

        for row in self.sec.rows:
            sev, det = active.get(row.label, (0, ""))
            row.set_active(sev > 0 or bool(det.strip()))

        # OCD
        for section, selected in self.ocd_values.items():
            grid = self.ocd_sections.get(section)
            if not grid:
                continue
            for r in grid.rows:
                r.set_active(r.label in selected)

        # PTSD
        for section, selected in self.ptsd_values.items():
            grid = self.ptsd_sections.get(section)
            if not grid:
                continue
            for r in grid.rows:
                r.set_active(r.label in selected)

        self._update_preview()

    def _apply_all_highlights(self):
        mode = self.current_mode
        if not mode:
            return

        # --- Main symptom grid ---
        active = self.values.get(mode, {})

        for row in self.sec.rows:
            sev, det = active.get(row.label, (0, ""))
            row.set_highlighted(sev > 0 or bool(det.strip()))
            row.set_value(sev, det)

        # --- OCD ---
        for section, selected in self.ocd_values.items():
            grid = self.ocd_sections.get(section)
            if not grid:
                continue

            for row in grid.rows:
                row.set_highlighted(row.label in selected)

        # --- PTSD ---
        for section, selected in self.ptsd_values.items():
            grid = self.ptsd_sections.get(section)
            if not grid:
                continue

            for row in grid.rows:
                row.set_highlighted(row.label in selected)


    def load_state(self, state: dict):
        if not state:
            return

        # -------------------------------------------------
        # Restore raw state
        # -------------------------------------------------
        self.values = state.get("values", {}).copy()
        self.ocd_values = state.get("ocd_values", {}).copy()
        self.ptsd_values = state.get("ptsd_values", {}).copy()
        self.phobia_subtype_values = state.get(
            "phobia_subtype_values", {}
        ).copy()

        self._ptsd_started = state.get("_ptsd_started", False)
        self._ocd_started = state.get("_ocd_started", False)

        # -------------------------------------------------
        # Restore panic/avoidance associations
        # -------------------------------------------------
        self.panic_associated = state.get("panic_associated", False)
        self.panic_severity = state.get("panic_severity", "moderate")
        self.avoidance_associated = state.get("avoidance_associated", False)
        self.avoidance_phobia_type = state.get("avoidance_phobia_type", "")
        self.avoidance_severity = state.get("avoidance_severity", "moderate")
        self.phobia_sub_selected = set(state.get("phobia_sub_selected", []))

        # Update UI controls
        self.panic_checkbox.setChecked(self.panic_associated)
        self.panic_severity_combo.setCurrentText(self.panic_severity)
        self.panic_severity_combo.setVisible(self.panic_associated)

        self.avoidance_checkbox.setChecked(self.avoidance_associated)
        self.phobia_type_combo.setVisible(self.avoidance_associated)
        if self.avoidance_phobia_type:
            self.phobia_type_combo.setCurrentText(self.avoidance_phobia_type)
        self.avoidance_severity_combo.setCurrentText(self.avoidance_severity)

        show_phobia_details = (
            self.avoidance_associated and
            self.avoidance_phobia_type and
            self.avoidance_phobia_type != "click to define"
        )
        self.avoidance_severity_combo.setVisible(show_phobia_details)
        self.phobia_severity_label.setVisible(show_phobia_details)

        # Restore phobia sub-symptoms
        if show_phobia_details:
            self._populate_phobia_sub_symptoms(self.avoidance_phobia_type)

        # -------------------------------------------------
        # Restore mode FIRST (rebuilds symptom grids)
        # -------------------------------------------------
        mode = state.get("current_mode", "Anxiety/Panic/Phobia")
        self.set_mode(mode)

        # -------------------------------------------------
        # APPLY MAIN SYMPTOM VALUES + HIGHLIGHTS
        # -------------------------------------------------
        active = self.values.get(mode, {})

        for row in self.sec.rows:
            sev, det = active.get(row.label, (0, ""))
            row.set_value(sev, det)
            row.set_active(sev > 0 or bool(det.strip()))

        # -------------------------------------------------
        # APPLY OCD HIGHLIGHTS (present / absent)
        # -------------------------------------------------
        for section, selected in self.ocd_values.items():
            grid = self.ocd_sections.get(section)
            if not grid:
                continue

            for row in grid.rows:
                row.set_active(row.label in selected)

        # -------------------------------------------------
        # APPLY PTSD HIGHLIGHTS (present / absent)
        # -------------------------------------------------
        for section, selected in self.ptsd_values.items():
            grid = self.ptsd_sections.get(section)
            if not grid:
                continue

            for row in grid.rows:
                row.set_active(row.label in selected)

        # -------------------------------------------------
        # Check associations box visibility
        # -------------------------------------------------
        self._check_show_associations()

        # -------------------------------------------------
        # FINAL PREVIEW REFRESH (after UI + highlights)
        # -------------------------------------------------
        self._update_preview()

    # ============================================================
    # PANIC/AVOIDANCE ASSOCIATION HANDLERS
    # ============================================================
    def _on_panic_toggled(self, checked: bool):
        self.panic_associated = checked
        self.panic_severity_combo.setVisible(checked)
        self._update_preview()

    def _on_panic_severity_changed(self, text: str):
        self.panic_severity = text
        self._update_preview()

    def _on_avoidance_toggled(self, checked: bool):
        self.avoidance_associated = checked
        self.phobia_type_combo.setVisible(checked)
        # Only show severity/sub-symptoms if a phobia type has been selected
        show_details = (
            checked and
            self.avoidance_phobia_type and
            self.avoidance_phobia_type != "click to define"
        )
        self.avoidance_severity_combo.setVisible(show_details)
        self.phobia_severity_label.setVisible(show_details)

        # Show/hide sub-symptoms
        if show_details:
            self._populate_phobia_sub_symptoms(self.avoidance_phobia_type)
        else:
            self.phobia_sub_container.setVisible(False)

        self._update_preview()

    def _on_phobia_type_changed(self, text: str):
        self.avoidance_phobia_type = text

        # Show severity only when an actual phobia type is selected
        show_phobia_details = (
            self.avoidance_associated and
            text and
            text != "click to define"
        )
        self.avoidance_severity_combo.setVisible(show_phobia_details)
        self.phobia_severity_label.setVisible(show_phobia_details)

        # Populate and show sub-symptoms for this phobia type
        self._populate_phobia_sub_symptoms(text if show_phobia_details else None)

        self._update_preview()

    def _populate_phobia_sub_symptoms(self, phobia_type: str | None):
        """Populate the phobia sub-symptom checkboxes for the selected phobia type."""
        # Clear existing checkboxes
        layout = self.phobia_sub_container.layout()
        while layout.count():
            item = layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()
        self.phobia_sub_checkboxes.clear()

        if not phobia_type or phobia_type not in PHOBIA_SUB_SYMPTOMS:
            self.phobia_sub_container.setVisible(False)
            return

        # Save the current selection before creating checkboxes
        saved_selection = self.phobia_sub_selected.copy()

        # Add checkboxes for this phobia type's sub-symptoms
        sub_symptoms = PHOBIA_SUB_SYMPTOMS.get(phobia_type, [])
        for symptom in sub_symptoms:
            cb = QCheckBox(symptom)
            cb.setStyleSheet("font-size:21px; color:#444;")
            layout.addWidget(cb)
            self.phobia_sub_checkboxes[symptom] = cb

            # Restore checked state if previously selected (block signals to prevent clearing)
            if symptom in saved_selection:
                cb.blockSignals(True)
                cb.setChecked(True)
                cb.blockSignals(False)

            # Connect signal AFTER setting initial state
            cb.toggled.connect(self._on_phobia_sub_toggled)

        self.phobia_sub_container.setVisible(len(sub_symptoms) > 0)

    def _on_phobia_sub_toggled(self):
        """Track which phobia sub-symptoms are selected."""
        self.phobia_sub_selected = set()
        for symptom, cb in self.phobia_sub_checkboxes.items():
            if cb.isChecked():
                self.phobia_sub_selected.add(symptom)
        self._update_preview()

    def _on_avoidance_severity_changed(self, text: str):
        self.avoidance_severity = text
        self._update_preview()

    def _check_show_associations(self):
        """Show the associations box (panic/phobia checkboxes) in Anxiety/Panic/Phobia mode."""
        if self.current_mode != "Anxiety/Panic/Phobia":
            self.associations_box.setVisible(False)
            return

        # Always show associations box in Anxiety/Panic/Phobia mode
        self.associations_box.setVisible(True)

    def closeEvent(self, event):
        parent = self.parent()
        if parent and hasattr(parent, "popup_memory"):
           parent.popup_memory["anxiety"] = self.get_state()
        super().closeEvent(event)

    def hideEvent(self, event):
        """Save state when popup is hidden (navigating away)."""
        parent = self.parent()
        if parent and hasattr(parent, "popup_memory"):
            parent.popup_memory["anxiety"] = self.get_state()
        super().hideEvent(event)
