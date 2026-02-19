from __future__ import annotations
from PySide6.QtCore import Qt, QPoint, QTimer, QPropertyAnimation, Signal
from PySide6.QtWidgets import (
    QWidget, QLabel, QPushButton, QVBoxLayout, QHBoxLayout,
    QScrollArea, QTextEdit, QSlider, QComboBox
)

from anxiety_widgets import SymptomSection
from mini_severity_popup import MiniSeverityPopup


# ============================================================
#  PRONOUN ENGINE
# ============================================================
def pronouns_from_gender(g):
    g = (g or "").lower().strip()
    if g == "male":
        return {"subj": "he", "obj": "him", "pos": "his",
                "be_present": "is", "be_past": "was"}
    if g == "female":
        return {"subj": "she", "obj": "her", "pos": "her",
                "be_present": "is", "be_past": "was"}
    return {"subj": "they", "obj": "them", "pos": "their",
            "be_present": "are", "be_past": "were"}


# ============================================================
#  MASTER SYMPTOM MAP (per category)
# ============================================================
SYMPTOMS = {
    "Anxiety": [
        "palpitations","breathing difficulty","dry mouth","dizzy/faint",
        "shaking","on edge","sweating","concentration issues",
        "hot flashes / cold chills","irritable","chest pain / discomfort",
        "numbness / tingling","choking","restlessness","increased startle",
        "nausea / abdominal distress","swallowing difficulties / throat lump",
        "muscle tension / aches","initial insomnia","fear of dying",
        "fear of losing control"
    ],

    "Panic": [
        "fear of dying","fear of losing control","nausea / abdominal distress",
        "choking","sweating","dizzy/faint","shaking","palpitations",
        "breathing difficulty","hot flashes / cold chills"
    ],

    "Phobia": [
        "fear of dying","fear of losing control","nausea / abdominal distress",
        "choking","sweating","dizzy/faint","shaking","palpitations",
        "breathing difficulty","depersonalisation/derealisation"
    ],

    "OCD": [
        "own thoughts","impulses","ideas","magical thoughts","images",
        "ruminations","obsessional slowness","gas/electric checking",
        "lock-checking","cleaning","handwashing","fear","relief/contentment",
        "distress","depersonalisation/derealisation",
        "resists at least one thought/act"
    ],

    "PTSD": [
        "accidental trauma","current trauma","historical trauma","flashbacks",
        "imagery","intense memories","nightmares","distress","hyperarousal",
        "avoidance","fear","numbness/depersonalisation"
    ]
}


# ============================================================
#  MAIN POPUP
# ============================================================
class AnxietyPopup(QWidget):

    def __init__(self, first_name: str, gender: str, parent=None):
        super().__init__(parent)

        self.first_name = first_name or "The patient"
        self.gender = gender
        self.p = pronouns_from_gender(gender)

        self.values = {}          # label → (sev, details)
        self.current_mode = None  # Anxiety / Panic / Phobia / OCD / PTSD

        self.setWindowFlags(Qt.FramelessWindowHint | Qt.SubWindow)
        self.setMinimumWidth(540)
        self.setMinimumHeight(870)

        outer = QVBoxLayout(self)
        outer.setContentsMargins(0,0,0,0)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.NoFrame)
        outer.addWidget(scroll)

        container = QWidget()
        scroll.setWidget(container)

        lay = QVBoxLayout(container)
        lay.setContentsMargins(20,20,20,20)
        lay.setSpacing(20)

        # ============================================================
        # HEADER
        # ============================================================
        hrow = QHBoxLayout()
        ttl = QLabel("Anxiety & Related Disorders")
        ttl.setStyleSheet("font-size:18px; font-weight:700;")
        hrow.addWidget(ttl)
        hrow.addStretch()

        close_btn = QPushButton("×")
        close_btn.setFixedSize(32,28)
        close_btn.clicked.connect(self.close)
        hrow.addWidget(close_btn)

        lay.addLayout(hrow)

        # ============================================================
        # MODE BUTTONS
        # ============================================================
        mode = QHBoxLayout()

        self.btns = {
            "Anxiety": QPushButton("Anxiety"),
            "Panic": QPushButton("Panic"),
            "Phobia": QPushButton("Phobia"),
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
                    background:#008C7E; color:white;
                }
            """)
            b.clicked.connect(lambda _, m=key: self.set_mode(m))
            mode.addWidget(b)

        lay.addLayout(mode)

        # ============================================================
        # DYNAMIC SYMPTOMS SECTION
        # ============================================================
        self.sec = SymptomSection("Symptoms", start_open=True)
        lay.addWidget(self.sec)

        # ============================================================
        # PHOBIA EXTRAS
        # ============================================================
        self.phobia_toggle = QPushButton("Phobic anxiety present")
        self.phobia_toggle.setVisible(False)
        self.phobia_toggle.setCheckable(True)
        lay.addWidget(self.phobia_toggle)

        self.phobia_sub = QComboBox()
        self.phobia_sub.addItems(["","Agoraphobia","Specific phobia",
                                  "Social phobia","Hypochondriacal"])
        self.phobia_sub.setVisible(False)
        lay.addWidget(self.phobia_sub)

        self.phobia_toggle.clicked.connect(
            lambda: self.phobia_sub.setVisible(self.phobia_toggle.isChecked())
        )

        # ============================================================
        # PREVIEW
        # ============================================================
        self.preview = QLabel("")
        self.preview.setWordWrap(True)
        self.preview.setMinimumHeight(200)
        self.preview.setStyleSheet("""
            background:#1e1e1e; color:#eaeaea;
            padding:12px; font-size:13px; border-radius:10px;
        """)
        lay.addWidget(self.preview)

        # ============================================================
        # SEND
        # ============================================================
        self.send_btn = QPushButton("Send to Letter")
        self.send_btn.setStyleSheet("""
            QPushButton { background:#008C7E; color:white;
                          padding:10px; border-radius:6px; }
        """)
        lay.addWidget(self.send_btn)

        QTimer.singleShot(40, self._update_preview)


    # ============================================================
    # MODE SELECTION
    # ============================================================
    def set_mode(self, mode: str):
        """Switch visible list without clearing saved results."""
        # Uncheck others
        for key, b in self.btns.items():
            b.setChecked(key == mode)

        self.current_mode = mode

        # Phobia-only controls
        self.phobia_toggle.setVisible(mode == "Phobia")
        self.phobia_sub.setVisible(mode == "Phobia" and self.phobia_toggle.isChecked())

        # Refresh rows
        self.sec.clear_rows()
        for s in SYMPTOMS[mode]:
            row = self.sec.add_symptom(s)
            row.clicked.connect(lambda _, lbl=s: self._open_editor(lbl))

        self._update_preview()


    # ============================================================
    # EDITOR POPUP
    # ============================================================
    def _open_editor(self, label):
        sev, det = self.values.get(label, (0,""))
        pop = MiniSeverityPopup(label, sev, det, parent=self)
        pop.saved.connect(self._save_symptom)
        pop.show_centered(self)

    def _save_symptom(self, label, sev, det):
        self.values[label] = (sev, det)
        self._update_preview()


    # ============================================================
    # HYBRID NARRATIVE
    # ============================================================
    def formatted_section_text(self):
        fn = self.first_name
        p = []

        # COMBINED Anxiety/Panic/Phobia cluster
        cluster = ["Anxiety","Panic","Phobia"]
        cluster_syms = []

        for cat in cluster:
            for lbl in SYMPTOMS[cat]:
                if lbl in self.values:
                    sev, det = self.values[lbl]
                    if sev == 0:
                        continue
                    txt = f"{lbl} ({['nil','mild','moderate','severe'][sev]})"
                    if det:
                        txt += f", {det}"
                    if txt not in cluster_syms:
                        cluster_syms.append(txt)

        if cluster_syms:
            joined = ", ".join(cluster_syms[:-1]) + f", and {cluster_syms[-1]}" if len(cluster_syms)>1 else cluster_syms[0]
            p.append(f"{fn} experienced symptoms across the anxiety–panic–phobia spectrum, including {joined}.")

        # Phobia subtype
        if self.phobia_toggle.isChecked():
            sub = self.phobia_sub.currentText().strip()
            if sub:
                p.append(f"Features were consistent with {sub.lower()}.")
            else:
                p.append("Phobic anxiety was present.")

        # OCD
        ocd_items = []
        for lbl in SYMPTOMS["OCD"]:
            if lbl in self.values:
                sev, det = self.values[lbl]
                if sev == 0:
                    continue
                t = f"{lbl} ({['nil','mild','moderate','severe'][sev]})"
                if det:
                    t += f", {det}"
                ocd_items.append(t)

        if ocd_items:
            joined = ", ".join(ocd_items[:-1]) + f", and {ocd_items[-1]}" if len(ocd_items)>1 else ocd_items[0]
            p.append(f"Obsessive–compulsive features included {joined}.")

        # PTSD
        ptsd_items = []
        for lbl in SYMPTOMS["PTSD"]:
            if lbl in self.values:
                sev, det = self.values[lbl]
                if sev == 0:
                    continue
                t = f"{lbl} ({['nil','mild','moderate','severe'][sev]})"
                if det:
                    t += f", {det}"
                ptsd_items.append(t)

        if ptsd_items:
            joined = ", ".join(ptsd_items[:-1]) + f", and {ptsd_items[-1]}" if len(ptsd_items)>1 else ptsd_items[0]
            p.append(f"PTSD-related symptoms included {joined}.")

        return "\n\n".join(p).strip()


    # ============================================================
    # PREVIEW
    # ============================================================
    def _update_preview(self):
        self.preview.setText(self.formatted_section_text())


    # ============================================================
    # LETTER WRITER EXPORT
    # ============================================================
    def save_and_close(self):
        self.saved_data = {
            "text": self.formatted_section_text(),
            "values": self.values.copy(),
            "phobia": self.phobia_toggle.isChecked(),
            "phobia_subtype": self.phobia_sub.currentText(),
            "mode": self.current_mode
        }
        self.close()


    # ============================================================
    # FADE-IN API FOR LETTER WRITER
    # ============================================================
    def show_with_fade(self, pos: QPoint):
        self.move(pos)
        self.setWindowOpacity(0)
        self.show()
        anim = QPropertyAnimation(self, b"windowOpacity")
        anim.setDuration(140)
        anim.setStartValue(0)
        anim.setEndValue(1)
        anim.start()
        self._fade = anim
        QTimer.singleShot(60, self._update_preview)
