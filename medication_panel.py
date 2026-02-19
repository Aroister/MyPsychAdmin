# =============================================================
# MEDICATION PANEL — CLEAN FINAL VERSION (MATCHES PH PANEL)
# Resizable, frameless, translucent panel
# =============================================================

from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QScrollArea, QSizeGrip, QSizePolicy, QToolButton
)
from PySide6.QtWidgets import QFrame
from PySide6.QtCore import Qt, QPoint
from PySide6.QtGui import QColor

# Shared components
from patient_history_panel_shared import CollapsibleSection, apply_macos_blur

# Import PH panel utilities
from physical_health_panel import (
    QtLineChart,
    FloatingHandleEntry,
    _clean_sort_dates_vals,
    _normalise_date,
    wrap_chart_in_hscroll
)

class MedFloatingEntry(QFrame):
    def __init__(self, title, parent=None, embedded=False):
        super().__init__(parent)
        self.embedded = embedded

        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)
        self.setMinimumHeight(0)
        self.setMaximumHeight(16777215)

        if embedded:
            self.setStyleSheet("""
                QFrame {
                    background-color: #f8f9fa;
                    border: none;
                    border-radius: 12px;
                }
            """)
        else:
            self.setStyleSheet("""
                QFrame {
                    background-color: rgba(40,40,40,0.92);
                    border-radius: 12px;
                }
            """)

        lay = QVBoxLayout(self)
        lay.setContentsMargins(12, 12, 12, 12)
        lay.setSpacing(10)

        # Title
        self.title_lab = QLabel(title)
        if embedded:
            self.title_lab.setStyleSheet("font-size: 16px; font-weight: bold; color:#333; background: transparent;")
        else:
            self.title_lab.setStyleSheet("font-size: 16px; font-weight: bold; color:#F5F5F5;")
        lay.addWidget(self.title_lab)

        # Container
        self.container = QWidget()
        self.container.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)
        self.container_layout = QVBoxLayout(self.container)
        self.container_layout.setContentsMargins(0, 0, 0, 0)
        self.container_layout.setSpacing(10)
        lay.addWidget(self.container)

        # Text area
        self.textbox = QLabel("")
        self.textbox.setWordWrap(True)
        if embedded:
            self.textbox.setStyleSheet("font-size: 14px; color:#555; background: transparent;")
        else:
            self.textbox.setStyleSheet("font-size: 14px; color:#DCE6FF;")
        self.container_layout.addWidget(self.textbox)

    def setSmooth(self):
        self.setMinimumHeight(0)
        self.setMaximumHeight(16777215)
        self.container.setMinimumHeight(0)
        self.container.setMaximumHeight(16777215)
        self.updateGeometry()
        p = self.parentWidget()
        if p:
            p.updateGeometry()

# =============================================================
# PSYCHIATRIC CLASSIFICATION
# =============================================================

PSYCH_SUBTYPES = {
    "Antipsychotic": [
        "olanzapine", "haloperidol", "risperidone", "quetiapine",
        "clozapine", "aripiprazole", "amisulpride", "paliperidone",
        "fluphenazine", "zuclopenthixol", "chlorpromazine"
    ],

    "Antidepressant": [
        "sertraline", "fluoxetine", "citalopram", "escitalopram",
        "paroxetine", "venlafaxine", "duloxetine", "mirtazapine",
        "amitriptyline", "trazodone", "agomelatine", "vortioxetine"
    ],

    "Antimanic": [
        "lithium", "sodium valproate", "valproate",
        "valproic acid", "carbamazepine", "lamotrigine"
    ],

    "Hypnotic": [
        "zopiclone", "zolpidem", "clonazepam", "lorazepam",
        "diazepam", "temazepam", "promethazine", "hydroxyzine"
    ],

    "Anticholinergic": [
        "procyclidine", "trihexyphenidyl", "benzatropine"
    ],
}

# =============================================================
# MEDICATION PANEL
# =============================================================

class MedicationPanel(QWidget):

    def __init__(self, extracted, parent=None, embedded=False):
        super().__init__(parent)

        self.extracted = extracted or {}
        self.meds = self.extracted.get("medications", [])
        self.unrecognised = self.extracted.get("unrecognised_tokens", [])
        self.embedded = embedded

        self._drag_offset = QPoint()
        self._panel_dragging = False

        # Window settings - only for floating mode
        if not embedded:
            self.setWindowFlags(
                Qt.FramelessWindowHint |
                Qt.SubWindow |
                Qt.WindowStaysOnTopHint
            )
            self.setCursor(Qt.CursorShape.OpenHandCursor)
            self.resize(980, 860)
            self._last_width = self.width()
            self._last_right = self.x() + self.width()
            self.setMinimumSize(900, 650)
        else:
            # Allow shrinking when embedded
            self.setMinimumSize(1, 1)
            self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        # UI
        self._build_ui()
        self.populate()
        self._apply_entry_styles()
        self.installEventFilter(self)   # <-- Smooth collapses
        # Blur
        try:
            apply_macos_blur(self)
        except Exception as e:
            print("MedicationPanel blur failed:", e)

        self.raise_()
        self.activateWindow()
        self.show()

    def showEvent(self, event):
        super().showEvent(event)
        try:
            self.scroll.widget().adjustSize()
            self.inner.adjustSize()
            self.inner_layout.activate()
            self.updateGeometry()
        except Exception:
            pass
    # =========================================================
    # FORCE LAYOUT UPDATE ON COLLAPSE/EXPAND (smooth animation)
    # =========================================================
    def eventFilter(self, obj, event):
        # Whenever any CollapsibleSection toggles visibility,
        # recalc the whole scroll/inner layout to remove jerkiness.
        try:
            if event.type() in (event.Show, event.Hide):
                if hasattr(self, "scroll") and self.scroll:
                    self.scroll.widget().adjustSize()
                if hasattr(self, "inner") and self.inner:
                    self.inner.adjustSize()
                if hasattr(self, "inner_layout") and self.inner_layout:
                    self.inner_layout.activate()
                self.updateGeometry()
        except Exception:
            pass

        return super().eventFilter(obj, event)


    # =========================================================
    # DRAG WINDOW - drag from anywhere
    # =========================================================
    def _drag_start(self, e):
        if e.button() == Qt.LeftButton:
            self._drag_offset = (
                e.globalPosition().toPoint() -
                self.frameGeometry().topLeft()
            )

    def _drag_move(self, e):
        if e.buttons() & Qt.LeftButton:
            self.move(e.globalPosition().toPoint() - self._drag_offset)

    def mousePressEvent(self, event):
        if self.embedded:
            return super().mousePressEvent(event)
        if event.button() == Qt.MouseButton.LeftButton:
            self._panel_dragging = True
            self._drag_offset = event.globalPosition().toPoint() - self.frameGeometry().topLeft()
            self.setCursor(Qt.CursorShape.ClosedHandCursor)

    def mouseMoveEvent(self, event):
        if self.embedded:
            return super().mouseMoveEvent(event)
        if self._panel_dragging:
            self.move(event.globalPosition().toPoint() - self._drag_offset)

    def mouseReleaseEvent(self, event):
        if self.embedded:
            return super().mouseReleaseEvent(event)
        self._panel_dragging = False
        self.setCursor(Qt.CursorShape.OpenHandCursor)

    # =========================================================
    # RIGHT EDGE ANCHOR RESIZING
    # =========================================================
    def resizeEvent(self, event):
        super().resizeEvent(event)
        # Smooth resizing: do NOT reposition window
        # Just update internal layout geometry
        try:
            if hasattr(self, "scroll"):
                self.scroll.widget().adjustSize()
            if hasattr(self, "inner"):
                self.inner.adjustSize()
            if hasattr(self, "inner_layout"):
                self.inner_layout.activate()
        except Exception:
            pass


    # =========================================================
    # BUILD UI
    # =========================================================
    def _build_ui(self):

        # Different styles for embedded vs floating
        if self.embedded:
            self.setStyleSheet("""
                QWidget {
                    background-color: white;
                    color: #333;
                }
                QLabel {
                    background: transparent;
                    color: #333;
                }
                QPushButton {
                    background-color: rgba(0,0,0,0.08);
                    color: #333;
                    border-radius: 6px;
                }
                QPushButton:hover {
                    background-color: rgba(0,0,0,0.15);
                }
            """)
        else:
            self.setStyleSheet("""
                QWidget {
                    background-color: rgba(32,32,32,0.90);
                    color: #DCE6FF;
                }
                QLabel {
                    color: #DCE6FF;
                }
                QPushButton {
                    background-color: rgba(255,255,255,0.22);
                    color: white;
                    border-radius: 6px;
                }
                QPushButton:hover {
                    background-color: rgba(255,255,255,0.35);
                }
            """)

        outer = QVBoxLayout(self)
        outer.setContentsMargins(12, 12, 12, 12)
        outer.setSpacing(12)

        # TITLE BAR
        self.title_bar = QWidget()
        self.title_bar.setFixedHeight(48)
        if not self.embedded:
            self.title_bar.setCursor(Qt.CursorShape.OpenHandCursor)
            self.title_bar.setStyleSheet("""
                background-color: rgba(30,30,30,0.95);
                border-top-left-radius: 12px;
                border-top-right-radius: 12px;
            """)
        else:
            self.title_bar.setStyleSheet("""
                background-color: rgba(240,242,245,0.95);
                border-bottom: 1px solid #d0d5da;
            """)

        tb = QHBoxLayout(self.title_bar)
        tb.setContentsMargins(12, 6, 12, 6)

        title = QLabel("Medication Overview")
        if self.embedded:
            title.setStyleSheet("font-size:18px; font-weight:bold; color:#333; background:transparent;")
        else:
            title.setStyleSheet("font-size:20px; font-weight:bold; color:#F5F5F5;")
        tb.addWidget(title)
        tb.addStretch()

        # Only add close button for floating mode
        if not self.embedded:
            close_btn = QPushButton("✕")
            close_btn.setFixedSize(34, 30)
            close_btn.setStyleSheet("""
                QPushButton {
                    background-color: rgba(255,255,255,0.18);
                    color: #FFFFFF;
                    font-size: 18px;
                    border: 1px solid rgba(255,255,255,0.35);
                    border-radius: 6px;
                }
                QPushButton:hover {
                    background-color: rgba(255,255,255,0.35);
                }
            """)
            close_btn.clicked.connect(self.close)
            tb.addWidget(close_btn)

            self.title_bar.mousePressEvent = self._drag_start
            self.title_bar.mouseMoveEvent = self._drag_move

        outer.addWidget(self.title_bar)

        # SCROLL AREA
        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        if self.embedded:
            self.scroll.setStyleSheet("""
                QScrollArea { background: white; border: none; }
                QScrollBar:vertical { background: rgba(0,0,0,0.05); width: 10px; border-radius: 5px; }
                QScrollBar::handle:vertical { background: rgba(0,0,0,0.2); border-radius: 5px; }
            """)
        else:
            self.scroll.setStyleSheet("""
                QScrollArea {
                    background-color: rgba(32,32,32,0.0);
                }
                QScrollBar:vertical {
                    background: rgba(80,80,80,0.55);       /* darker track */
                    width: 14px;
                    margin: 0px;
                    border-radius: 7px;
                }
                QScrollBar::handle:vertical {
                    background: rgba(240,240,240,0.85);    /* bright handle */
                    border-radius: 7px;
                    min-height: 40px;
                }
                QScrollBar::handle:vertical:hover {
                    background: rgba(255,255,255,1.0);     /* full bright on hover */
                }
            """)
        outer.addWidget(self.scroll)


        # INNER PANEL
        self.inner = QWidget()
        if self.embedded:
            self.inner.setStyleSheet("background: white;")
        else:
            self.inner.setStyleSheet("""
                background-color: rgba(48,48,48,0.72);
                border-radius: 12px;
                color: #DCE6FF;
            """)

        self.inner_layout = QVBoxLayout(self.inner)
        self.inner_layout.setAlignment(Qt.AlignTop)
        self.inner_layout.setContentsMargins(12, 12, 40, 40)
        self.inner_layout.setSpacing(26)

        self.scroll.setWidget(self.inner)

        # Resize grip (macOS-visible fix) - only for floating mode
        if not self.embedded:
            self.grip = QSizeGrip(self)
            self.grip.setFixedSize(22, 22)
            self.grip.setStyleSheet("""
                QSizeGrip {
                    background-color: rgba(255,255,255,0.70);
                    border-radius: 11px;
                    margin: 0px;
                    padding: 0px;
                }
            """)
            outer.addWidget(self.grip, alignment=Qt.AlignBottom | Qt.AlignRight)
            self.grip.raise_()
        else:
            self.grip = None

    # =========================================================
    # MUTUAL EXCLUSION FOR MAJOR SECTIONS
    # =========================================================
    def _setup_mutual_exclusion(self, section1, section2):
        """When one section opens, collapse the other and all its children."""
        original_toggle1 = section1._toggle
        original_toggle2 = section2._toggle

        def toggle1_wrapper(event=None):
            was_closed = not section1.container.isVisible()
            original_toggle1(event)
            # If we just opened section1, close section2 and its children
            if was_closed:
                self._collapse_section_and_children(section2)

        def toggle2_wrapper(event=None):
            was_closed = not section2.container.isVisible()
            original_toggle2(event)
            # If we just opened section2, close section1 and its children
            if was_closed:
                self._collapse_section_and_children(section1)

        section1._toggle = toggle1_wrapper
        section1.header_bar.mousePressEvent = toggle1_wrapper
        section2._toggle = toggle2_wrapper
        section2.header_bar.mousePressEvent = toggle2_wrapper

    def _collapse_section_and_children(self, section):
        """Collapse a section and all its nested CollapsibleSection children."""
        # Collapse all child sections first
        for child in section.findChildren(CollapsibleSection):
            if child.container.isVisible():
                child.container.hide()
                child.arrow.setText("▶")
                child._remove_highlight()

        # Collapse the main section
        if section.container.isVisible():
            section.container.hide()
            section.arrow.setText("▶")
            section._remove_highlight()

    # =========================================================
    # FIX ENTRY STYLES (FloatingHandleEntry)
    # =========================================================
    def _apply_entry_styles(self):
        from PySide6.QtWidgets import QWidget, QLabel

        for widget in self.findChildren(QWidget):
            if widget.__class__.__name__ == "FloatingHandleEntry":
                widget.setStyleSheet("""
                    QFrame {
                        background-color: rgba(40,40,40,0.92);
                        border-radius: 12px;
                    }
                    QLabel {
                        color: #DCE6FF;
                        font-size: 14px;
                    }
                """)

    # =========================================================
    # POPULATE PANEL
    # =========================================================
    def populate(self):

        # --- Unrecognised medication-like token warning ---
        if self.unrecognised:
            n = len(self.unrecognised)
            term_word = "term" if n == 1 else "terms"
            banner = QLabel(
                f"\u26a0 {n} unrecognised medication-like {term_word} found "
                f"\u2014 verify against source notes"
            )
            banner.setWordWrap(True)
            banner.setStyleSheet(
                "background-color: #FFF3CD; color: #856404; "
                "font-size: 13px; font-weight: bold; "
                "padding: 8px 12px; border-radius: 6px; "
                "border: 1px solid #FFEEBA;"
            )
            self.inner_layout.addWidget(banner)

            details_sec = CollapsibleSection(
                "Unrecognised Terms", start_collapsed=True, embedded=self.embedded
            )
            for tok in self.unrecognised:
                lbl = QLabel(f"  \u2022  {tok}")
                lbl.setStyleSheet("font-size: 13px; padding: 2px 8px;")
                details_sec.add_widget(lbl)
            self.inner_layout.addWidget(details_sec)

        if not self.meds:
            no = QLabel("No medications found.")
            no.setStyleSheet("color:#bbb; font-size:14px;")
            self.inner_layout.addWidget(no)
            return

        # GROUP BY CANONICAL NAME
        grouped = {}

        for m in self.meds:
            canon = m["canonical"]
            date = m.get("date")
            strength = m.get("strength")

            grouped.setdefault(canon, {"meta": m, "dates": [], "values": []})

            if date and date not in grouped[canon]["dates"]:
                grouped[canon]["dates"].append(date)
                grouped[canon]["values"].append(strength)

        for canon, pack in grouped.items():
            d, v = _clean_sort_dates_vals(pack["dates"], pack["values"])
            pack["dates"] = d
            pack["values"] = v

        self.grouped = grouped

        # SUMMARY SECTION - divided into Psychiatric and Physical
        summary = CollapsibleSection("Medication Summary", start_collapsed=True, embedded=self.embedded)
        self.summary_section = summary  # Store reference for mutual exclusion
        self.inner_layout.addWidget(summary)

        # Classify medications into psychiatric (by subtype) and physical
        psych_summary = {sub: {} for sub in PSYCH_SUBTYPES}
        phys_summary = {}

        for canon, pack in grouped.items():
            lc = canon.lower()
            is_psych = False
            for subtype, names in PSYCH_SUBTYPES.items():
                if any(drug in lc for drug in names):
                    psych_summary[subtype][canon] = pack
                    is_psych = True
                    break
            if not is_psych:
                phys_summary[canon] = pack

        # Helper to create medication rows
        def add_med_rows(parent_section, canon, pack):
            block = CollapsibleSection(canon, start_collapsed=True, embedded=self.embedded)
            parent_section.add_widget(block)

            dates = pack["dates"]
            vals = pack["values"]

            for d, v in zip(dates, vals):
                row = QWidget()
                lay = QHBoxLayout(row)
                lay.setContentsMargins(8, 2, 8, 2)
                lay.setSpacing(16)

                lay.addWidget(QLabel(str(v)))
                lay.addWidget(QLabel(str(d)))
                lay.addStretch()

                def make_jump(dt):
                    def handler(event):
                        self._chart_point_clicked(dt)
                    return handler

                row.mousePressEvent = make_jump(d)
                block.add_widget(row)

        # Psychiatric Medications Summary (with subtypes)
        psych_summary_sec = CollapsibleSection("Psychiatric Medications", start_collapsed=True, embedded=self.embedded)
        summary.add_widget(psych_summary_sec)

        has_psych = False
        for subtype in PSYCH_SUBTYPES.keys():
            med_map = psych_summary[subtype]
            if not med_map:
                continue

            has_psych = True
            subtype_sec = CollapsibleSection(subtype, start_collapsed=True, embedded=self.embedded)
            psych_summary_sec.add_widget(subtype_sec)

            for canon, pack in sorted(med_map.items(), key=lambda x: x[0].lower()):
                add_med_rows(subtype_sec, canon, pack)

        if not has_psych:
            no_psych = QLabel("No psychiatric medications found.")
            no_psych.setStyleSheet("color:#888; font-style:italic; padding:8px;")
            psych_summary_sec.add_widget(no_psych)

        # Physical Medications Summary
        phys_summary_sec = CollapsibleSection("Physical Medications", start_collapsed=True, embedded=self.embedded)
        summary.add_widget(phys_summary_sec)

        if phys_summary:
            for canon, pack in sorted(phys_summary.items(), key=lambda x: x[0].lower()):
                add_med_rows(phys_summary_sec, canon, pack)
        else:
            no_phys = QLabel("No physical medications found.")
            no_phys.setStyleSheet("color:#888; font-style:italic; padding:8px;")
            phys_summary_sec.add_widget(no_phys)

        # GRAPHS - Parent container for Psychiatric and Physical graphs
        graphs_root = CollapsibleSection("Graphs", start_collapsed=True, embedded=self.embedded)
        self.graphs_section = graphs_root  # Store reference for mutual exclusion
        self.inner_layout.addWidget(graphs_root)

        # Set up mutual exclusion: opening one closes the other
        self._setup_mutual_exclusion(summary, graphs_root)

        # PSYCHIATRIC GRAPHS
        psych_root = CollapsibleSection("Psychiatric", start_collapsed=True, embedded=self.embedded)
        graphs_root.add_widget(psych_root)

        psych = {sub: {} for sub in PSYCH_SUBTYPES}

        for canon, pack in grouped.items():
            lc = canon.lower()
            for subtype, names in PSYCH_SUBTYPES.items():
                if any(drug in lc for drug in names):
                    psych[subtype][canon] = pack
                    break

        for subtype, med_map in psych.items():
            if not med_map:
                continue

            sub_sec = CollapsibleSection(subtype, start_collapsed=True, embedded=self.embedded)
            psych_root.add_widget(sub_sec)

            for canon, pack in sorted(med_map.items(), key=lambda x: x[0].lower()):

                entry = MedFloatingEntry(canon, parent=self, embedded=self.embedded)
                entry.setSmooth()
                entry.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)
                entry.setMinimumHeight(0)
                entry.setMaximumHeight(16777215)

                dates = pack["dates"]
                vals = pack["values"]
                meta = pack["meta"]

                if not dates:
                    entry.textbox.setText("No valid data.")
                    sub_sec.add_widget(entry)
                    continue

                chart = QtLineChart(
                    dates,
                    {canon: vals},
                    unit=meta.get("unit", "")
                )
                chart.setMinimumHeight(300)
                chart.setMaximumHeight(300)
                chart.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
                chart.pointClicked.connect(self._chart_point_clicked)

                # Wrap in horizontal scroll
                scroll_chart = wrap_chart_in_hscroll(chart, min_width=600)

                entry.textbox.setVisible(False)
                entry.layout().addWidget(scroll_chart)

                sub_sec.add_widget(entry)

        # PHYSICAL GRAPHS
        phys_root = CollapsibleSection("Physical", start_collapsed=True, embedded=self.embedded)
        graphs_root.add_widget(phys_root)

        phys = {}

        for canon, pack in grouped.items():
            lc = canon.lower()
            if not any(
                any(drug in lc for drug in names)
                for names in PSYCH_SUBTYPES.values()
            ):
                phys[canon] = pack

        for canon, pack in sorted(phys.items(), key=lambda x: x[0].lower()):
                entry = MedFloatingEntry(canon, parent=self, embedded=self.embedded)
                entry.setSmooth()

                # --- Smooth animation: allow natural height ---
                entry.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)
                entry.setMinimumHeight(0)                 # remove locked minimums
                entry.setMaximumHeight(16777215)          # allow natural expansion

                dates = pack["dates"]
                vals = pack["values"]
                meta = pack["meta"]

                if not dates:
                        entry.textbox.setText("No valid data.")
                        phys_root.add_widget(entry)
                        continue

                # --- Chart with fluid height for smooth collapsible animation ---
                chart = QtLineChart(dates, {canon: vals}, unit=meta.get("unit", ""))
                chart.setMinimumHeight(300)
                chart.setMaximumHeight(300)
                chart.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
                chart.pointClicked.connect(self._chart_point_clicked)

                # Wrap in horizontal scroll
                scroll_chart = wrap_chart_in_hscroll(chart, min_width=600)

                entry.textbox.setVisible(False)
                entry.layout().addWidget(scroll_chart)

                phys_root.add_widget(entry)

        self.inner_layout.addStretch(1)


    # =========================================================
    # CLICK → JUMP TO NOTES
    # =========================================================
    def _chart_point_clicked(self, dt):
        mw = self.window()
        if mw is None:
            print("MedicationPanel: No MainWindow found.")
            return

        from PySide6.QtWidgets import QWidget as _W
        target_page = None

        for w in mw.findChildren(_W, options=Qt.FindChildrenRecursively):
            if w.__class__.__name__ == "PatientNotesPage":
                target_page = w
                break

        if not target_page:
            print("MedicationPanel: PatientNotesPage not found.")
            return

        try:
            target_page.notes_panel.jump_to_date(dt)
        except Exception as e:
            print("MedicationPanel jump_to_date failed:", e)
