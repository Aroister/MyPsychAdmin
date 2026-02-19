from __future__ import annotations

from functools import partial

from PySide6.QtCore import Qt, Signal, QEvent
from PySide6.QtWidgets import (
        QWidget, QLabel, QPushButton,
        QVBoxLayout, QHBoxLayout,
        QFrame, QRadioButton, QButtonGroup,
        QSlider, QSizePolicy, QScrollArea, QTextEdit, QSplitter, QCheckBox
)
from PySide6.QtGui import QCursor
import re
import html
from datetime import datetime
from background_history_popup import CollapsibleSection, ResizableSection
from shared_widgets import add_lock_to_popup
from spell_check_textedit import enable_spell_check_on_textedit


# ============================================================
# NO-WHEEL SLIDER (prevents scroll from changing value)
# ============================================================
class NoWheelSlider(QSlider):
    def wheelEvent(self, event):
        event.ignore()


# ============================================================
#  SIMPLE PANEL (with title header, optional collapse)
# ============================================================

class SimplePanel(QFrame):
    """A panel with a title header - optional collapse, for use with splitter."""

    HEADER_HEIGHT = 44  # Fixed header height when collapsed

    def __init__(self, title: str, color: str = "#7c2d12", parent=None, collapsible: bool = False):
        super().__init__(parent)
        self._title = title
        self._color = color
        self._collapsible = collapsible
        self._collapsed = False

        self.setStyleSheet("""
            SimplePanel {
                background: rgba(255,255,255,0.96);
                border: 1px solid rgba(0,0,0,0.15);
                border-radius: 12px;
            }
        """)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        # Header
        self.header = QFrame()
        self.header.setStyleSheet(f"""
            QFrame {{
                background: transparent;
                border: none;
                border-bottom: 1px solid rgba(0,0,0,0.08);
            }}
        """)
        header_layout = QHBoxLayout(self.header)
        header_layout.setContentsMargins(12, 8, 12, 8)
        header_layout.setSpacing(8)

        # Collapse button (if collapsible)
        if collapsible:
            self.collapse_btn = QPushButton("+")
            self._collapsed = True  # Start collapsed
            self.collapse_btn.setFixedSize(24, 24)
            self.collapse_btn.setCursor(QCursor(Qt.CursorShape.PointingHandCursor))
            self.collapse_btn.setStyleSheet("""
                QPushButton {
                    background: rgba(0,0,0,0.05);
                    border: none;
                    border-radius: 4px;
                    font-size: 21px;
                    font-weight: bold;
                    color: #666;
                }
                QPushButton:hover {
                    background: rgba(0,0,0,0.1);
                }
            """)
            self.collapse_btn.clicked.connect(self._toggle_collapse)
            header_layout.addWidget(self.collapse_btn)

        self.title_label = QLabel(title)
        self.title_label.setStyleSheet(f"font-size: 21px; font-weight: 600; color: {color};")
        header_layout.addWidget(self.title_label)
        header_layout.addStretch()

        layout.addWidget(self.header)

        # Content area (scrollable)
        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setFrameShape(QScrollArea.NoFrame)
        self.scroll.setStyleSheet("QScrollArea { background: transparent; border: none; }")

        self.content = QWidget()
        self.content.setStyleSheet("""
            QWidget { background: transparent; }
            QLabel { border: none; background: transparent; }
            QRadioButton { border: none; background: transparent; }
        """)
        self.content_layout = QVBoxLayout(self.content)
        self.content_layout.setContentsMargins(12, 10, 12, 10)
        self.content_layout.setSpacing(8)
        self.scroll.setWidget(self.content)
        layout.addWidget(self.scroll)

        # Start collapsed if collapsible
        if collapsible:
            self.scroll.setVisible(False)
            self.setMaximumHeight(self.HEADER_HEIGHT)
            self.setMinimumHeight(self.HEADER_HEIGHT)

    def _toggle_collapse(self):
        """Toggle the collapsed state."""
        self._collapsed = not self._collapsed
        self.scroll.setVisible(not self._collapsed)
        if hasattr(self, 'collapse_btn'):
            self.collapse_btn.setText("+" if self._collapsed else "-")
        # Set size constraints based on collapsed state
        if self._collapsed:
            self.setMaximumHeight(self.HEADER_HEIGHT)
            self.setMinimumHeight(self.HEADER_HEIGHT)
        else:
            self.setMaximumHeight(16777215)  # Qt default max
            self.setMinimumHeight(0)

    def setCollapsed(self, collapsed: bool):
        """Set the collapsed state."""
        if self._collapsible and self._collapsed != collapsed:
            self._toggle_collapse()

    def addWidget(self, widget):
        """Add widget to the content area."""
        self.content_layout.addWidget(widget)

    def addLayout(self, layout):
        """Add layout to the content area."""
        self.content_layout.addLayout(layout)


# ============================================================
#  PRONOUN ENGINE
# ============================================================

def pronouns_from_gender(g):
    g = (g or "").lower().strip()

    if g == "male":
        return {
            "subj": "he",
            "obj": "him",
            "pos": "his",
            "be": "is",
            "have": "has",
            "do": "does",
        }

    if g == "female":
        return {
            "subj": "she",
            "obj": "her",
            "pos": "her",
            "be": "is",
            "have": "has",
            "do": "does",
        }

    return {
        "subj": "they",
        "obj": "them",
        "pos": "their",
        "be": "are",
        "have": "have",
        "do": "do",
    }


# ============================================================
#  CANONICAL SCALES
# ============================================================

CONVICTION_COUNTS = [
        "one conviction", "two convictions", "three convictions",
        "four convictions", "five convictions", "six convictions",
        "seven convictions", "eight convictions", "nine convictions",
        "ten convictions", "more than ten convictions",
]

OFFENCE_COUNTS = [
        "one offence", "two offences", "three offences", "four offences",
        "five offences", "six offences", "seven offences",
        "eight offences", "nine offences", "ten offences",
        "more than ten offences",
]

PRISON_DURATIONS = [
        "less than six months",
        "six to twelve months",
        "one to two years",
        "two to five years",
        "more than five years",
]


# ============================================================
#  FORENSIC HISTORY POPUP
# ============================================================

class ForensicHistoryPopup(QWidget):
        sent = Signal(str, dict)
        closed = Signal(dict)
        FORENSIC_HEADER_HEIGHT = 52  # Header height when collapsed

        def __init__(self, first_name=None, gender=None, parent=None, show_index_offence=False):
                super().__init__(parent)

                self.setWindowFlags(Qt.WindowType.Widget)
                self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)

                self.p = pronouns_from_gender(gender)
                self.show_index_offence = show_index_offence

                # --------------------------------------------------
                # STATE
                # --------------------------------------------------
                self.state = {
                        "convictions": {"status": None, "count_idx": 0},
                        "offences": {"count_idx": 0},
                        "prison": {"status": None, "duration_idx": 0},
                        "index_offence": "",
                }

                # --------------------------------------------------
                # ROOT LAYOUT - VERTICAL STACK
                # --------------------------------------------------
                root = QVBoxLayout(self)
                root.setContentsMargins(0, 0, 0, 0)
                root.setSpacing(0)

                # Main scroll area containing everything
                main_scroll = QScrollArea()
                main_scroll.setWidgetResizable(True)
                main_scroll.setFrameShape(QScrollArea.Shape.NoFrame)
                main_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
                main_scroll.setStyleSheet("QScrollArea { background: transparent; border: none; }")

                main_container = QWidget()
                main_container.setStyleSheet("background: transparent;")
                self.main_layout = QVBoxLayout(main_container)
                self.main_layout.setContentsMargins(8, 8, 8, 8)
                self.main_layout.setSpacing(8)
                self.main_layout.setAlignment(Qt.AlignmentFlag.AlignTop)

                # --------------------------------------------------
                # PANEL 1: INDEX OFFENCE (if enabled) - wrapped in container like convictions
                # --------------------------------------------------
                if self.show_index_offence:
                        self.index_panel = SimplePanel("Details of Index Offence", "#7c2d12", collapsible=True)

                        self.index_offence_field = QTextEdit()
                        self.index_offence_field.setPlaceholderText("Enter details of index offence...")
                        self.index_offence_field.setStyleSheet("""
                            QTextEdit {
                                background: white;
                                border: 1px solid #d1d5db;
                                border-radius: 6px;
                                padding: 8px;
                                font-size: 21px;
                            }
                        """)
                        enable_spell_check_on_textedit(self.index_offence_field)
                        self.index_offence_field.textChanged.connect(self._on_index_offence_changed)
                        self.index_panel.addWidget(self.index_offence_field)

                        # Container wrapping panel + drag bar
                        self._index_expanded_height = 200
                        self.index_container = QFrame()
                        self.index_container.setStyleSheet("background: transparent; border: none;")
                        self.index_container.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
                        index_container_layout = QVBoxLayout(self.index_container)
                        index_container_layout.setContentsMargins(0, 0, 0, 0)
                        index_container_layout.setSpacing(0)
                        index_container_layout.addWidget(self.index_panel)

                        # Drag bar for index offence
                        self.index_drag_bar = QFrame()
                        self.index_drag_bar.setFixedHeight(10)
                        self.index_drag_bar.setCursor(Qt.CursorShape.SizeVerCursor)
                        self.index_drag_bar.setStyleSheet("""
                            QFrame {
                                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                                    stop:0 rgba(0,0,0,0.03), stop:0.5 rgba(0,0,0,0.1), stop:1 rgba(0,0,0,0.03));
                                border-radius: 2px;
                                margin: 0px 40px;
                            }
                            QFrame:hover {
                                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                                    stop:0 rgba(37,99,235,0.15), stop:0.5 rgba(37,99,235,0.4), stop:1 rgba(37,99,235,0.15));
                            }
                        """)
                        self.index_drag_bar.installEventFilter(self)
                        self._index_dragging = False
                        index_container_layout.addWidget(self.index_drag_bar)

                        # Start collapsed (header only)
                        self.index_drag_bar.setVisible(False)
                        self.index_container.setFixedHeight(SimplePanel.HEADER_HEIGHT)

                        # Connect collapse toggle to resize container
                        self.index_panel.collapse_btn.clicked.connect(self._on_index_collapse_toggled)

                        self.main_layout.addWidget(self.index_container)

                # --------------------------------------------------
                # PANEL 3: CONVICTIONS & PRISON
                # --------------------------------------------------
                self.convictions_panel = SimplePanel("Convictions & Prison History", "#7c2d12", collapsible=True)

                # Convictions section
                conv_header = QLabel("Convictions")
                conv_header.setStyleSheet("font-size:21px; font-weight:600; color:#374151; margin-top:4px;")
                self.convictions_panel.addWidget(conv_header)

                self.conv_btn_group = QButtonGroup(self)
                self.conv_buttons = {}
                for label, value in [
                        ("Did not wish to discuss", "declined"),
                        ("No convictions", "none"),
                        ("Has convictions", "some"),
                ]:
                        rb = QRadioButton(label)
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
                        rb.clicked.connect(lambda _, v=value: self._set_convictions(v))
                        self.conv_btn_group.addButton(rb)
                        self.conv_buttons[value] = rb
                        self.convictions_panel.addWidget(rb)

                # Conviction count slider
                self.conv_slider_box = QWidget()
                conv_slider_lay = QVBoxLayout(self.conv_slider_box)
                conv_slider_lay.setContentsMargins(0, 6, 0, 0)
                conv_slider_lay.setSpacing(4)

                conv_slider_lbl = QLabel("Number of convictions")
                conv_slider_lbl.setStyleSheet("font-size:21px; color:#666;")
                conv_slider_lay.addWidget(conv_slider_lbl)

                self.conv_slider = NoWheelSlider(Qt.Horizontal)
                self.conv_slider.setRange(0, len(CONVICTION_COUNTS) - 1)
                self.conv_slider.valueChanged.connect(self._on_conviction_slider)
                conv_slider_lay.addWidget(self.conv_slider)

                self.conv_slider_box.setVisible(False)
                self.convictions_panel.addWidget(self.conv_slider_box)

                # Offence count slider
                self.off_slider_box = QWidget()
                off_slider_lay = QVBoxLayout(self.off_slider_box)
                off_slider_lay.setContentsMargins(0, 6, 0, 0)
                off_slider_lay.setSpacing(4)

                off_slider_lbl = QLabel("Number of offences")
                off_slider_lbl.setStyleSheet("font-size:21px; color:#666;")
                off_slider_lay.addWidget(off_slider_lbl)

                self.off_slider = NoWheelSlider(Qt.Horizontal)
                self.off_slider.setRange(0, len(OFFENCE_COUNTS) - 1)
                self.off_slider.valueChanged.connect(self._on_offence_slider)
                off_slider_lay.addWidget(self.off_slider)

                self.off_slider_box.setVisible(False)
                self.convictions_panel.addWidget(self.off_slider_box)

                # Divider
                divider = QFrame()
                divider.setFixedHeight(1)
                divider.setStyleSheet("background: rgba(0,0,0,0.15); margin: 8px 0;")
                self.convictions_panel.addWidget(divider)

                # Prison section
                prison_header = QLabel("Prison History")
                prison_header.setStyleSheet("font-size:21px; font-weight:600; color:#374151; margin-top:4px;")
                self.convictions_panel.addWidget(prison_header)

                self.prison_btn_group = QButtonGroup(self)
                self.prison_buttons = {}
                for label, value in [
                        ("Did not wish to discuss", "declined"),
                        ("Never been in prison", "never"),
                        ("Has been in prison / remanded", "yes"),
                ]:
                        rb = QRadioButton(label)
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
                        rb.clicked.connect(lambda _, v=value: self._set_prison_status(v))
                        self.prison_btn_group.addButton(rb)
                        self.prison_buttons[value] = rb
                        self.convictions_panel.addWidget(rb)

                # Prison duration slider
                self.prison_slider_box = QWidget()
                prison_slider_lay = QVBoxLayout(self.prison_slider_box)
                prison_slider_lay.setContentsMargins(0, 6, 0, 0)
                prison_slider_lay.setSpacing(4)

                prison_slider_lbl = QLabel("Total time spent in prison")
                prison_slider_lbl.setStyleSheet("font-size:21px; color:#666;")
                prison_slider_lay.addWidget(prison_slider_lbl)

                self.prison_slider = NoWheelSlider(Qt.Horizontal)
                self.prison_slider.setRange(0, len(PRISON_DURATIONS) - 1)
                self.prison_slider.valueChanged.connect(self._on_prison_slider)
                prison_slider_lay.addWidget(self.prison_slider)

                self.prison_slider_box.setVisible(False)
                self.convictions_panel.addWidget(self.prison_slider_box)

                # Container wrapping panel + drag bar
                self._convictions_expanded_height = 400
                self.convictions_container = QFrame()
                self.convictions_container.setStyleSheet("background: transparent; border: none;")
                self.convictions_container.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)
                convictions_container_layout = QVBoxLayout(self.convictions_container)
                convictions_container_layout.setContentsMargins(0, 0, 0, 0)
                convictions_container_layout.setSpacing(0)
                convictions_container_layout.addWidget(self.convictions_panel)

                # Drag bar for convictions
                self.convictions_drag_bar = QFrame()
                self.convictions_drag_bar.setFixedHeight(10)
                self.convictions_drag_bar.setCursor(Qt.CursorShape.SizeVerCursor)
                self.convictions_drag_bar.setStyleSheet("""
                        QFrame {
                                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                                        stop:0 rgba(0,0,0,0.05), stop:0.5 rgba(0,0,0,0.15), stop:1 rgba(0,0,0,0.05));
                                border-radius: 2px;
                                margin: 2px 60px;
                        }
                        QFrame:hover {
                                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                                        stop:0 rgba(37,99,235,0.2), stop:0.5 rgba(37,99,235,0.5), stop:1 rgba(37,99,235,0.2));
                        }
                """)
                self.convictions_drag_bar.installEventFilter(self)
                self._convictions_dragging = False
                convictions_container_layout.addWidget(self.convictions_drag_bar)

                # Start collapsed (header only)
                self.convictions_drag_bar.setVisible(False)
                self.convictions_container.setFixedHeight(SimplePanel.HEADER_HEIGHT)

                # Connect collapse toggle to resize container
                self.convictions_panel.collapse_btn.clicked.connect(self._on_convictions_collapse_toggled)

                self.main_layout.addWidget(self.convictions_container)

                # --------------------------------------------------
                # IMPORTED DATA SECTION (inside main scroll)
                # --------------------------------------------------
                self.extracted_section = CollapsibleSection("Imported Data", start_collapsed=True)
                self.extracted_section.set_header_style("""
                        QFrame {
                                background: rgba(180, 150, 50, 0.25);
                                border: 1px solid rgba(180, 150, 50, 0.5);
                                border-radius: 6px 6px 0 0;
                        }
                """)
                self.extracted_section.title_label.setStyleSheet("""
                        QLabel {
                                font-size: 21px;
                                font-weight: 600;
                                color: #806000;
                                background: transparent;
                                border: none;
                        }
                """)

                extracted_content = QWidget()
                extracted_content.setStyleSheet("""
                        QWidget {
                                background: rgba(255, 248, 220, 0.95);
                                border: 1px solid rgba(180, 150, 50, 0.4);
                                border-top: none;
                                border-radius: 0 0 12px 12px;
                        }
                        QCheckBox {
                                background: transparent;
                                border: none;
                                padding: 4px;
                                font-size: 22px;
                                color: #4a4a4a;
                        }
                        QCheckBox::indicator {
                                width: 16px;
                                height: 16px;
                        }
                """)

                extracted_layout = QVBoxLayout(extracted_content)
                extracted_layout.setContentsMargins(12, 10, 12, 10)
                extracted_layout.setSpacing(6)

                extracted_scroll = QScrollArea()
                extracted_scroll.setWidgetResizable(True)
                extracted_scroll.setFrameShape(QScrollArea.Shape.NoFrame)
                extracted_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
                extracted_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
                extracted_scroll.setStyleSheet("""
                        QScrollArea { background: transparent; border: none; }
                        QScrollArea > QWidget > QWidget { background: transparent; }
                """)

                self.extracted_container = QWidget()
                self.extracted_container.setStyleSheet("background: transparent;")
                self.extracted_checkboxes_layout = QVBoxLayout(self.extracted_container)
                self.extracted_checkboxes_layout.setContentsMargins(2, 2, 2, 2)
                self.extracted_checkboxes_layout.setSpacing(12)
                # Removed AlignTop to allow entries to expand with container

                extracted_scroll.setWidget(self.extracted_container)
                extracted_layout.addWidget(extracted_scroll)

                self.extracted_section.set_content(extracted_content)
                self.extracted_section.setVisible(False)  # Hidden until data loaded

                # Include checkbox in the header (right side)
                self.include_imported_cb = QCheckBox()
                self.include_imported_cb.setToolTip("Include imported data in report")
                self.include_imported_cb.setStyleSheet("""
                        QCheckBox {
                                background: transparent;
                                border: none;
                        }
                        QCheckBox::indicator {
                                width: 20px;
                                height: 20px;
                        }
                """)
                self.include_imported_cb.stateChanged.connect(self._update_preview)
                self.extracted_section.header.layout().addWidget(self.include_imported_cb)

                self.main_layout.addWidget(self.extracted_section)

                # Store extracted checkboxes and imported report text
                self._extracted_checkboxes = []
                self._imported_report_text = ""

                # Add stretch at bottom and set up scroll area
                self.main_layout.addStretch()
                main_scroll.setWidget(main_container)
                root.addWidget(main_scroll, 1)

                add_lock_to_popup(self, show_button=False)

        # ============================================================
        #  GENDER UPDATE
        # ============================================================

        def update_gender(self, gender: str):
                """Update pronouns when gender changes on front page."""
                self.p = pronouns_from_gender(gender)
                self._update_preview()

        # ============================================================
        #  STATE HANDLERS
        # ============================================================

        def _set_convictions(self, value):
                self.state["convictions"]["status"] = value
                show = value == "some"
                self.conv_slider_box.setVisible(show)
                self.off_slider_box.setVisible(show)
                self._update_preview()

        def _set_prison_status(self, value):
                self.state["prison"]["status"] = value
                self.prison_slider_box.setVisible(value == "yes")
                self._update_preview()

        def _on_conviction_slider(self, idx):
                self.state["convictions"]["count_idx"] = idx
                self._update_preview()

        def _on_offence_slider(self, idx):
                self.state["offences"]["count_idx"] = idx
                self._update_preview()

        def _on_prison_slider(self, idx):
                self.state["prison"]["duration_idx"] = idx
                self._update_preview()

        def _on_index_offence_changed(self):
                if hasattr(self, 'index_offence_field'):
                        self.state["index_offence"] = self.index_offence_field.toPlainText()
                        self._update_preview()

        # ============================================================
        #  SET FORENSIC DATA (notes analysis + extracted data)
        #  EXACT COPY FROM GPR SECTION 9
        # ============================================================

        def set_forensic_data(self, notes: list, extracted_entries: list = None):
                """Combine risk analysis (Physical Aggression, Property Damage, Sexual Behaviour) with data extractor forensic data.

                Display in date order with risk type badges, highlighted matches, and filter panel.
                """
                from risk_overview_panel import analyze_notes_for_risk

                print(f"[FORENSIC] set_forensic_data called with {len(notes) if notes else 0} notes, {len(extracted_entries) if extracted_entries else 0} extracted entries")

                all_incidents = []

                # Risk categories relevant to forensic history
                FORENSIC_RISK_CATEGORIES = ["Physical Aggression", "Property Damage", "Sexual Behaviour"]

                # Run risk analysis on notes
                if notes:
                        results = analyze_notes_for_risk(notes)
                        for cat_name in FORENSIC_RISK_CATEGORIES:
                                cat_data = results.get("categories", {}).get(cat_name, {})
                                for incident in cat_data.get("incidents", []):
                                        all_incidents.append({
                                                "date": incident.get("date"),
                                                "text": incident.get("full_text", ""),
                                                "matched": incident.get("matched", ""),
                                                "subcategory": incident.get("subcategory", ""),
                                                "severity": incident.get("severity", "medium"),
                                                "category": cat_name,
                                                "source": "notes",
                                        })

                # Add data extractor entries
                if extracted_entries:
                        for entry in extracted_entries:
                                if isinstance(entry, dict):
                                        text = entry.get("text", "")
                                        date = entry.get("date")
                                else:
                                        text = str(entry)
                                        date = None
                                if text and text.strip():
                                        all_incidents.append({
                                                "date": date,
                                                "text": text,
                                                "matched": "",
                                                "subcategory": "Data Extractor",
                                                "severity": "medium",
                                                "category": "Forensic History",
                                                "source": "extractor",
                                        })

                if not all_incidents:
                        # Hide forensic section if no data
                        if hasattr(self, '_forensic_notes_section'):
                                self._forensic_notes_section.setVisible(False)
                        return

                # Sort by date (newest first)
                def get_sort_date(x):
                        d = x.get("date")
                        if d is None:
                                return datetime.min
                        return d

                sorted_incidents = sorted(all_incidents, key=get_sort_date, reverse=True)

                # Store all incidents for filtering
                self._all_forensic_incidents = sorted_incidents
                self._current_filter = None

                # Category colors
                self._cat_colors = {
                        "Physical Aggression": "#b71c1c",
                        "Property Damage": "#ff9800",
                        "Sexual Behaviour": "#673ab7",
                        "Forensic History": "#607d8b",
                }

                self._severity_colors = {
                        "high": "#dc2626",
                        "medium": "#f59e0b",
                        "low": "#22c55e",
                }

                # Create or get forensic data section
                if not hasattr(self, '_forensic_notes_section'):
                        self._create_forensic_data_section()

                # Clear existing content
                while self._forensic_content_layout.count():
                        child = self._forensic_content_layout.takeAt(0)
                        if child.widget():
                                child.widget().deleteLater()

                # Collect unique labels (category or category:subcategory)
                labels = {}
                for inc in sorted_incidents:
                        cat = inc["category"]
                        subcat = inc.get("subcategory", "")
                        if subcat and subcat != "Data Extractor":
                                label = f"{cat}: {subcat}"
                        else:
                                label = cat
                        if label not in labels:
                                labels[label] = self._cat_colors.get(cat, "#666666")

                # Create filter panel with horizontal scroll
                filter_container = QWidget()
                filter_container.setStyleSheet("background: transparent;")
                filter_layout = QVBoxLayout(filter_container)
                filter_layout.setContentsMargins(0, 0, 0, 8)
                filter_layout.setSpacing(6)

                # Horizontal scroll for labels
                label_scroll = QScrollArea()
                label_scroll.setWidgetResizable(True)
                label_scroll.setFixedHeight(40)
                label_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
                label_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
                label_scroll.setStyleSheet("""
                        QScrollArea {
                                border: none;
                                background: transparent;
                        }
                        QScrollBar:horizontal {
                                height: 6px;
                                background: #f0f0f0;
                                border-radius: 3px;
                        }
                        QScrollBar::handle:horizontal {
                                background: #c0c0c0;
                                border-radius: 3px;
                                min-width: 20px;
                        }
                """)

                label_widget = QWidget()
                label_widget.setStyleSheet("background: transparent;")
                label_row = QHBoxLayout(label_widget)
                label_row.setContentsMargins(0, 0, 0, 0)
                label_row.setSpacing(6)

                for label_text, color in sorted(labels.items()):
                        btn = QPushButton(label_text)
                        btn.setStyleSheet(f"""
                                QPushButton {{
                                        background: {color};
                                        color: white;
                                        border: none;
                                        border-radius: 4px;
                                        padding: 6px 12px;
                                        font-size: 21px;
                                        font-weight: 600;
                                }}
                                QPushButton:hover {{
                                        background: {color}dd;
                                }}
                        """)
                        btn.setCursor(Qt.CursorShape.PointingHandCursor)
                        btn.clicked.connect(lambda checked, lbl=label_text: self._apply_forensic_filter(lbl))
                        label_row.addWidget(btn)

                label_row.addStretch()
                label_scroll.setWidget(label_widget)
                filter_layout.addWidget(label_scroll)

                # Filter status row (hidden initially)
                self._filter_status_widget = QWidget()
                self._filter_status_widget.setStyleSheet("background: transparent;")
                self._filter_status_widget.setVisible(False)
                filter_status_layout = QHBoxLayout(self._filter_status_widget)
                filter_status_layout.setContentsMargins(0, 0, 0, 0)
                filter_status_layout.setSpacing(8)

                self._filter_label = QLabel("Filtered by: ")
                self._filter_label.setStyleSheet("font-size: 21px; color: #374151; font-weight: 500;")
                filter_status_layout.addWidget(self._filter_label)

                remove_filter_btn = QPushButton("✕ Remove filter")
                remove_filter_btn.setStyleSheet("""
                        QPushButton {
                                background: #ef4444;
                                color: white;
                                border: none;
                                border-radius: 4px;
                                padding: 4px 10px;
                                font-size: 21px;
                                font-weight: 600;
                        }
                        QPushButton:hover {
                                background: #dc2626;
                        }
                """)
                remove_filter_btn.setCursor(Qt.CursorShape.PointingHandCursor)
                remove_filter_btn.clicked.connect(self._remove_forensic_filter)
                filter_status_layout.addWidget(remove_filter_btn)
                filter_status_layout.addStretch()

                filter_layout.addWidget(self._filter_status_widget)
                self._forensic_content_layout.addWidget(filter_container)

                # Container for incident entries (for re-rendering on filter)
                self._incidents_container = QWidget()
                self._incidents_container.setStyleSheet("background: transparent;")
                self._incidents_container.setSizePolicy(QSizePolicy.Policy.Ignored, QSizePolicy.Policy.Minimum)
                self._incidents_layout = QVBoxLayout(self._incidents_container)
                self._incidents_layout.setContentsMargins(0, 0, 0, 0)
                self._incidents_layout.setSpacing(8)
                self._forensic_content_layout.addWidget(self._incidents_container)

                # Render all incidents
                self._render_forensic_incidents(sorted_incidents)

                self._forensic_content_layout.addStretch()

                # Show the section
                self._forensic_notes_section.setVisible(True)

                print(f"[FORENSIC] Displayed {len(sorted_incidents)} forensic incidents")

        def _create_forensic_data_section(self):
                """Create the forensic data section using CollapsibleSection (matches GPR sections 8/10)."""
                self._forensic_notes_section = CollapsibleSection("Forensic Data from Notes", start_collapsed=True)
                self._forensic_notes_section.set_content_height(300)
                self._forensic_notes_section._min_height = 150
                self._forensic_notes_section._max_height = 600
                self._forensic_notes_section.set_header_style("""
                        QFrame {
                                background: rgba(183, 28, 28, 0.1);
                                border: 1px solid rgba(183, 28, 28, 0.3);
                                border-radius: 6px 6px 0 0;
                        }
                """)
                self._forensic_notes_section.set_title_style("""
                        QLabel {
                                font-size: 18px;
                                font-weight: 600;
                                color: #b71c1c;
                                background: transparent;
                                border: none;
                        }
                """)

                # Scroll area as content (matches section 8/10 pattern)
                self._forensic_scroll = QScrollArea()
                self._forensic_scroll.setWidgetResizable(True)
                self._forensic_scroll.setFrameShape(QScrollArea.Shape.NoFrame)
                self._forensic_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
                self._forensic_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
                self._forensic_scroll.setStyleSheet("""
                        QScrollArea {
                                background: rgba(255, 255, 255, 0.95);
                                border: 1px solid rgba(183, 28, 28, 0.2);
                                border-top: none;
                                border-radius: 0 0 12px 12px;
                        }
                """)

                self._forensic_content_widget = QWidget()
                self._forensic_content_widget.setStyleSheet("background: transparent;")
                self._forensic_content_layout = QVBoxLayout(self._forensic_content_widget)
                self._forensic_content_layout.setContentsMargins(12, 12, 12, 12)
                self._forensic_content_layout.setSpacing(8)

                self._forensic_scroll.setWidget(self._forensic_content_widget)
                self._forensic_notes_section.set_content(self._forensic_scroll)
                self._forensic_notes_section.setVisible(False)

                # Add to main layout (before the stretch)
                if hasattr(self, 'main_layout'):
                        count = self.main_layout.count()
                        if count > 0:
                                self.main_layout.insertWidget(count - 1, self._forensic_notes_section)
                        else:
                                self.main_layout.addWidget(self._forensic_notes_section)

        def _on_index_collapse_toggled(self):
                """Resize index container when panel is toggled."""
                if self.index_panel._collapsed:
                        self.index_drag_bar.setVisible(False)
                        self.index_container.setFixedHeight(SimplePanel.HEADER_HEIGHT)
                else:
                        self.index_drag_bar.setVisible(True)
                        self.index_container.setFixedHeight(self._index_expanded_height + 10)

        def _on_convictions_collapse_toggled(self):
                """Resize convictions container when panel is toggled."""
                if self.convictions_panel._collapsed:
                        self.convictions_drag_bar.setVisible(False)
                        self.convictions_container.setFixedHeight(SimplePanel.HEADER_HEIGHT)
                else:
                        self.convictions_drag_bar.setVisible(True)
                        self.convictions_container.setFixedHeight(self._convictions_expanded_height + 10)

        def eventFilter(self, obj, event):
                """Handle drag events on section-specific drag bars."""
                # Index offence drag bar
                if hasattr(self, 'index_drag_bar') and obj == self.index_drag_bar:
                        if event.type() == QEvent.Type.MouseButtonPress:
                                self._index_dragging = True
                                self._index_drag_start_y = event.globalPosition().y()
                                self._index_drag_start_height = self._index_expanded_height
                                return True
                        elif event.type() == QEvent.Type.MouseMove and self._index_dragging:
                                delta = event.globalPosition().y() - self._index_drag_start_y
                                new_height = max(100, min(500, int(self._index_drag_start_height + delta)))
                                self._index_expanded_height = new_height
                                self.index_container.setFixedHeight(new_height + 10)
                                return True
                        elif event.type() == QEvent.Type.MouseButtonRelease:
                                self._index_dragging = False
                                return True

                # Convictions panel drag bar
                if hasattr(self, 'convictions_drag_bar') and obj == self.convictions_drag_bar:
                        if event.type() == QEvent.Type.MouseButtonPress:
                                self._convictions_dragging = True
                                self._convictions_drag_start_y = event.globalPosition().y()
                                self._convictions_drag_start_height = self._convictions_expanded_height
                                return True
                        elif event.type() == QEvent.Type.MouseMove and self._convictions_dragging:
                                delta = event.globalPosition().y() - self._convictions_drag_start_y
                                new_height = max(200, min(800, int(self._convictions_drag_start_height + delta)))
                                self._convictions_expanded_height = new_height
                                self.convictions_container.setFixedHeight(new_height + 10)
                                return True
                        elif event.type() == QEvent.Type.MouseButtonRelease:
                                self._convictions_dragging = False
                                return True

                return super().eventFilter(obj, event)

        def _apply_forensic_filter(self, label: str):
                """Apply filter to show only incidents matching the label."""
                self._current_filter = label
                self._filter_label.setText(f"Filtered by: {label}")
                self._filter_status_widget.setVisible(True)

                # Filter incidents
                filtered = []
                for inc in self._all_forensic_incidents:
                        cat = inc["category"]
                        subcat = inc.get("subcategory", "")
                        if subcat and subcat != "Data Extractor":
                                inc_label = f"{cat}: {subcat}"
                        else:
                                inc_label = cat
                        if inc_label == label:
                                filtered.append(inc)

                self._render_forensic_incidents(filtered)

        def _remove_forensic_filter(self):
                """Remove filter and show all incidents."""
                self._current_filter = None
                self._filter_status_widget.setVisible(False)
                self._render_forensic_incidents(self._all_forensic_incidents)

        def _render_forensic_incidents(self, incidents: list):
                """Render the list of incidents."""
                # Clear existing
                while self._incidents_layout.count():
                        child = self._incidents_layout.takeAt(0)
                        if child.widget():
                                child.widget().deleteLater()

                # Clear checkboxes from previous render
                self._extracted_checkboxes.clear()

                for incident in incidents:
                        date = incident["date"]
                        cat_name = incident["category"]
                        text = incident["text"]
                        matched = incident["matched"]
                        subcat_name = incident["subcategory"]
                        severity = incident["severity"]

                        if not text or not text.strip():
                                continue

                        # Format date
                        if date:
                                if hasattr(date, "strftime"):
                                        date_str = date.strftime("%d %b %Y")
                                else:
                                        date_str = str(date)
                        else:
                                date_str = "No date"

                        # Get colors
                        cat_color = self._cat_colors.get(cat_name, "#666666")
                        sev_color = self._severity_colors.get(severity, "#666666")

                        # Create HTML with highlighted matched text
                        escaped_text = html.escape(text)
                        if matched:
                                escaped_matched = html.escape(matched)
                                try:
                                        pattern = re.compile(re.escape(escaped_matched), re.IGNORECASE)
                                        highlighted_html = pattern.sub(
                                                f'<span style="background-color: #FFEB3B; color: #000; font-weight: bold; padding: 1px 3px; border-radius: 3px;">{escaped_matched}</span>',
                                                escaped_text
                                        )
                                except:
                                        highlighted_html = escaped_text
                        else:
                                highlighted_html = escaped_text

                        full_html = f'''
                        <html>
                        <body style="font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 21px; color: #333; margin: 0; padding: 0;">
                        {highlighted_html}
                        </body>
                        </html>
                        '''

                        # Create entry frame
                        entry_frame = QFrame()
                        entry_frame.setObjectName("forensicEntryFrame")
                        entry_frame.setSizePolicy(QSizePolicy.Policy.Ignored, QSizePolicy.Policy.Minimum)
                        entry_frame.setStyleSheet(f"""
                                QFrame#forensicEntryFrame {{
                                        background: rgba(255, 255, 255, 0.95);
                                        border: 1px solid #e5e7eb;
                                        border-left: 4px solid {cat_color};
                                        border-radius: 8px;
                                        padding: 2px;
                                }}
                        """)
                        entry_layout = QVBoxLayout(entry_frame)
                        entry_layout.setContentsMargins(6, 6, 6, 6)
                        entry_layout.setSpacing(4)
                        entry_layout.setSizeConstraint(QVBoxLayout.SizeConstraint.SetMinAndMaxSize)

                        # Header row: toggle → date → category badge → severity → stretch → checkbox
                        header_row = QHBoxLayout()
                        header_row.setSpacing(8)

                        # Toggle button
                        toggle_btn = QPushButton("▸")
                        toggle_btn.setFixedSize(22, 22)
                        toggle_btn.setCursor(Qt.CursorShape.PointingHandCursor)
                        toggle_btn.setStyleSheet(f"""
                                QPushButton {{
                                        background: rgba(180, 150, 50, 0.2);
                                        border: none;
                                        border-radius: 4px;
                                        font-size: 17px;
                                        font-weight: bold;
                                        color: {cat_color};
                                }}
                                QPushButton:hover {{ background: rgba(180, 150, 50, 0.35); }}
                        """)
                        header_row.addWidget(toggle_btn)

                        # Date label
                        date_label = QLabel(f"📅 {date_str}")
                        date_label.setStyleSheet("""
                                QLabel {
                                        font-size: 16px;
                                        font-weight: 500;
                                        color: #806000;
                                        background: transparent;
                                        border: none;
                                }
                        """)
                        date_label.setCursor(Qt.CursorShape.PointingHandCursor)
                        header_row.addWidget(date_label)

                        # Category badge
                        badge_text = f"{cat_name}: {subcat_name}" if subcat_name and subcat_name != "Data Extractor" else cat_name
                        cat_badge = QLabel(badge_text)
                        cat_badge.setStyleSheet(f"""
                                QLabel {{
                                        font-size: 10px;
                                        font-weight: 600;
                                        color: white;
                                        background: {cat_color};
                                        border: none;
                                        border-radius: 3px;
                                        padding: 2px 6px;
                                }}
                        """)
                        header_row.addWidget(cat_badge)

                        # Severity badge
                        sev_badge = QLabel(severity.upper())
                        sev_badge.setStyleSheet(f"""
                                QLabel {{
                                        font-size: 9px;
                                        font-weight: 700;
                                        color: white;
                                        background: {sev_color};
                                        border: none;
                                        border-radius: 3px;
                                        padding: 2px 5px;
                                }}
                        """)
                        header_row.addWidget(sev_badge)
                        header_row.addStretch()

                        # Checkbox on the RIGHT
                        cb = QCheckBox()
                        cb.setProperty("full_text", text)
                        cb.setFixedSize(18, 18)
                        cb.setStyleSheet("""
                                QCheckBox { background: transparent; }
                                QCheckBox::indicator { width: 16px; height: 16px; }
                        """)
                        cb.stateChanged.connect(self._send_to_card)
                        header_row.addWidget(cb)
                        self._extracted_checkboxes.append(cb)

                        entry_layout.addLayout(header_row)

                        # Text content (hidden by default, toggled by arrow)
                        body_text = QTextEdit()
                        body_text.setReadOnly(True)
                        body_text.setHtml(full_html)
                        body_text.setSizePolicy(QSizePolicy.Policy.Ignored, QSizePolicy.Policy.Minimum)
                        body_text.setMinimumHeight(60)
                        body_text.setMaximumHeight(120)
                        body_text.setLineWrapMode(QTextEdit.LineWrapMode.WidgetWidth)
                        body_text.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
                        body_text.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
                        body_text.setStyleSheet("""
                                QTextEdit {
                                        background: #f9fafb;
                                        border: none;
                                        border-radius: 4px;
                                        padding: 6px;
                                        font-size: 21px;
                                        color: #374151;
                                }
                        """)
                        body_text.setVisible(False)
                        entry_layout.addWidget(body_text)

                        drag_bar = QFrame()
                        drag_bar.setFixedHeight(8)
                        drag_bar.setCursor(Qt.CursorShape.SizeVerCursor)
                        drag_bar.setStyleSheet("""
                                QFrame {
                                        background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                                                stop:0 rgba(180,150,50,0.1), stop:0.5 rgba(180,150,50,0.3), stop:1 rgba(180,150,50,0.1));
                                        border-radius: 2px; margin: 2px 40px;
                                }
                                QFrame:hover {
                                        background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                                                stop:0 rgba(180,150,50,0.2), stop:0.5 rgba(180,150,50,0.5), stop:1 rgba(180,150,50,0.2));
                                }
                        """)
                        drag_bar.setVisible(False)
                        drag_bar._drag_y = None
                        drag_bar._init_h = None
                        def _make_drag_handlers(handle, text_widget):
                                def press(ev):
                                        handle._drag_y = ev.globalPosition().y()
                                        handle._init_h = text_widget.height()
                                def move(ev):
                                        if handle._drag_y is not None:
                                                delta = int(ev.globalPosition().y() - handle._drag_y)
                                                new_h = max(60, handle._init_h + delta)
                                                text_widget.setMinimumHeight(new_h)
                                                text_widget.setMaximumHeight(new_h)
                                def release(ev):
                                        if handle._drag_y is not None:
                                                text_widget.setMaximumHeight(16777215)
                                                handle._drag_y = None
                                return press, move, release
                        dp, dm, dr = _make_drag_handlers(drag_bar, body_text)
                        drag_bar.mousePressEvent = dp
                        drag_bar.mouseMoveEvent = dm
                        drag_bar.mouseReleaseEvent = dr
                        entry_layout.addWidget(drag_bar)

                        # Toggle function
                        def make_toggle(btn, body, frame, bar):
                                def toggle():
                                        is_visible = body.isVisible()
                                        body.setVisible(not is_visible)
                                        bar.setVisible(not is_visible)
                                        btn.setText("▾" if not is_visible else "▸")
                                        frame.updateGeometry()
                                return toggle

                        toggle_fn = make_toggle(toggle_btn, body_text, entry_frame, drag_bar)
                        toggle_btn.clicked.connect(toggle_fn)
                        date_label.mousePressEvent = lambda e, fn=toggle_fn: fn()

                        self._incidents_layout.addWidget(entry_frame)

                self._incidents_layout.addStretch()

        # ============================================================
        #  SET ENTRIES (for imported data)
        # ============================================================

        def set_entries(self, items: list, subtitle: str = ""):
                """Display extracted data with collapsible dated entry boxes."""
                # Clear existing checkboxes
                for cb in self._extracted_checkboxes:
                        cb.deleteLater()
                self._extracted_checkboxes.clear()

                # Clear layout
                while self.extracted_checkboxes_layout.count():
                        item = self.extracted_checkboxes_layout.takeAt(0)
                        if item.widget():
                                item.widget().deleteLater()

                # Handle legacy string format
                if isinstance(items, str):
                        if items.strip():
                                items = [{"date": None, "text": p.strip()} for p in items.split("\n\n") if p.strip()]
                        else:
                                items = []

                if items:
                        # Sort by date (newest first)
                        def get_sort_date(item):
                                dt = item.get("date")
                                if dt is None:
                                        return ""
                                if hasattr(dt, "strftime"):
                                        return dt.strftime("%Y-%m-%d")
                                return str(dt)

                        sorted_items = sorted(items, key=get_sort_date, reverse=True)

                        for item in sorted_items:
                                dt = item.get("date")
                                text = item.get("text", "").strip()
                                if not text:
                                        continue

                                # Format date for header
                                if dt:
                                        if hasattr(dt, "strftime"):
                                                date_str = dt.strftime("%d %b %Y")
                                        else:
                                                date_str = str(dt)
                                else:
                                        date_str = "No date"

                                # Create collapsible entry box
                                entry_frame = QFrame()
                                entry_frame.setObjectName("entryFrame")
                                entry_frame.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
                                entry_frame.setStyleSheet("""
                                        QFrame#entryFrame {
                                                background: rgba(255, 255, 255, 0.95);
                                                border: 1px solid rgba(180, 150, 50, 0.4);
                                                border-radius: 8px;
                                                padding: 4px;
                                        }
                                """)
                                entry_layout = QVBoxLayout(entry_frame)
                                entry_layout.setContentsMargins(10, 8, 10, 8)
                                entry_layout.setSpacing(6)
                                entry_layout.setSizeConstraint(QVBoxLayout.SizeConstraint.SetMinAndMaxSize)

                                # Header row with checkbox, date label, and toggle button
                                header_row = QHBoxLayout()
                                header_row.setSpacing(8)

                                # Toggle button on the LEFT
                                toggle_btn = QPushButton("▸")
                                toggle_btn.setFixedSize(22, 22)
                                toggle_btn.setCursor(Qt.CursorShape.PointingHandCursor)
                                toggle_btn.setStyleSheet("""
                                        QPushButton {
                                                background: rgba(180, 150, 50, 0.2);
                                                border: none;
                                                border-radius: 4px;
                                                font-size: 21px;
                                                font-weight: bold;
                                                color: #806000;
                                        }
                                        QPushButton:hover { background: rgba(180, 150, 50, 0.35); }
                                """)
                                header_row.addWidget(toggle_btn)

                                # Date label
                                date_label = QLabel(f"📅 {date_str}")
                                date_label.setStyleSheet("""
                                        QLabel {
                                                font-size: 21px;
                                                font-weight: 600;
                                                color: #806000;
                                                background: transparent;
                                                border: none;
                                        }
                                """)
                                date_label.setCursor(Qt.CursorShape.PointingHandCursor)
                                header_row.addWidget(date_label)
                                header_row.addStretch()

                                # Checkbox on the RIGHT
                                cb = QCheckBox()
                                cb.setProperty("full_text", text)
                                cb.setFixedSize(18, 18)
                                cb.setStyleSheet("""
                                        QCheckBox { background: transparent; }
                                        QCheckBox::indicator { width: 16px; height: 16px; }
                                """)
                                cb.stateChanged.connect(self._update_preview)
                                header_row.addWidget(cb)

                                entry_layout.addLayout(header_row)

                                # Body (full content, hidden by default)
                                body_text = QTextEdit()
                                body_text.setPlainText(text)
                                body_text.setReadOnly(True)
                                body_text.setFrameShape(QFrame.Shape.NoFrame)
                                body_text.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
                                body_text.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
                                body_text.setStyleSheet("""
                                        QTextEdit {
                                                font-size: 17px;
                                                color: #333;
                                                background: rgba(255, 248, 220, 0.5);
                                                border: none;
                                                padding: 8px;
                                                border-radius: 6px;
                                        }
                                """)
                                body_text.setMinimumHeight(60)
                                body_text.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
                                body_text.setVisible(False)
                                entry_layout.addWidget(body_text)

                                drag_bar = QFrame()
                                drag_bar.setFixedHeight(8)
                                drag_bar.setCursor(Qt.CursorShape.SizeVerCursor)
                                drag_bar.setStyleSheet("""
                                        QFrame {
                                                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                                                        stop:0 rgba(180,150,50,0.1), stop:0.5 rgba(180,150,50,0.3), stop:1 rgba(180,150,50,0.1));
                                                border-radius: 2px; margin: 2px 40px;
                                        }
                                        QFrame:hover {
                                                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                                                        stop:0 rgba(180,150,50,0.2), stop:0.5 rgba(180,150,50,0.5), stop:1 rgba(180,150,50,0.2));
                                        }
                                """)
                                drag_bar.setVisible(False)
                                drag_bar._drag_y = None
                                drag_bar._init_h = None
                                def _make_drag_handlers(handle, text_widget):
                                        def press(ev):
                                                handle._drag_y = ev.globalPosition().y()
                                                handle._init_h = text_widget.height()
                                        def move(ev):
                                                if handle._drag_y is not None:
                                                        delta = int(ev.globalPosition().y() - handle._drag_y)
                                                        new_h = max(60, handle._init_h + delta)
                                                        text_widget.setMinimumHeight(new_h)
                                                        text_widget.setMaximumHeight(new_h)
                                        def release(ev):
                                                if handle._drag_y is not None:
                                                        text_widget.setMaximumHeight(16777215)
                                                        handle._drag_y = None
                                        return press, move, release
                                dp, dm, dr = _make_drag_handlers(drag_bar, body_text)
                                drag_bar.mousePressEvent = dp
                                drag_bar.mouseMoveEvent = dm
                                drag_bar.mouseReleaseEvent = dr
                                entry_layout.addWidget(drag_bar)

                                # Toggle function
                                def make_toggle(btn, body, frame, popup_self, bar):
                                        def toggle():
                                                is_visible = body.isVisible()
                                                body.setVisible(not is_visible)
                                                bar.setVisible(not is_visible)
                                                btn.setText("▾" if not is_visible else "▸")
                                                frame.updateGeometry()
                                                if hasattr(popup_self, 'extracted_container'):
                                                        popup_self.extracted_container.updateGeometry()
                                                        popup_self.extracted_container.update()
                                        return toggle

                                toggle_fn = make_toggle(toggle_btn, body_text, entry_frame, self, drag_bar)
                                toggle_btn.clicked.connect(toggle_fn)
                                date_label.mousePressEvent = lambda e, fn=toggle_fn: fn()

                                self.extracted_checkboxes_layout.addWidget(entry_frame)
                                self._extracted_checkboxes.append(cb)

                        self.extracted_checkboxes_layout.addStretch()
                        self.extracted_section.setVisible(True)
                        # Keep collapsed on open
                        # if self.extracted_section._is_collapsed:
                        #         self.extracted_section._toggle_collapse()
                else:
                        self.extracted_section.setVisible(False)

        # ============================================================
        #  TEXT
        # ============================================================

        def formatted_text(self) -> str:
                s = self.p["subj"].capitalize()
                have = self.p["have"]
                out = []

                # Index offence (for tribunal reports)
                index_offence = self.state.get("index_offence", "").strip()
                if index_offence:
                        out.append(f"Index offence: {index_offence}")

                c = self.state["convictions"]
                if c["status"] == "declined":
                        out.append(f"{s} did not wish to discuss convictions.")
                elif c["status"] == "none":
                        out.append(f"{s} has no convictions.")
                elif c["status"] == "some":
                        out.append(
                                f"{s} {have} {CONVICTION_COUNTS[c['count_idx']]} "
                                f"from {OFFENCE_COUNTS[self.state['offences']['count_idx']]}."
                        )

                p = self.state["prison"]

                if p["status"] == "declined":
                        out.append(f"{s} did not wish to discuss prison history.")

                elif p["status"] == "never":
                        out.append(f"{s} {have} never been in prison.")

                elif p["status"] == "yes":
                        duration = PRISON_DURATIONS[p["duration_idx"]]

                        if c["status"] in ("none", "declined", None):
                                out.append(
                                        f"{s} {have} been remanded to prison for {duration}."
                                )
                        else:
                                out.append(
                                        f"{s} {have} spent {duration} in prison."
                                )

                main_text = " ".join(out)

                # Add imported report text if checkbox is ticked
                if hasattr(self, 'include_imported_cb') and self.include_imported_cb.isChecked():
                        imported = getattr(self, '_imported_report_text', '')
                        if imported:
                                if main_text:
                                        main_text += "\n\n" + imported
                                else:
                                        main_text = imported

                # Add selected entries from imported notes data
                selected_texts = []
                for cb in self._extracted_checkboxes:
                        if cb.isChecked():
                                text = cb.property("full_text")
                                if text:
                                        selected_texts.append(text)
                if selected_texts:
                        if main_text:
                                main_text += "\n\nFrom notes:\n" + "\n\n".join(selected_texts)
                        else:
                                main_text = "From notes:\n" + "\n\n".join(selected_texts)

                return main_text

        # ============================================================
        # LOAD / PREVIEW / EMIT
        # ============================================================

        def load_state(self, state: dict):
                if not isinstance(state, dict):
                        return

                self.state = {
                        "convictions": state.get(
                                "convictions",
                                {"status": None, "count_idx": 0},
                        ).copy(),

                        "offences": state.get(
                                "offences",
                                {"count_idx": 0},
                        ).copy(),

                        "prison": state.get(
                                "prison",
                                {"status": None, "duration_idx": 0},
                        ).copy(),
                }

                # Convictions
                c = self.state["convictions"]
                status = c.get("status")

                if status in self.conv_buttons:
                        self.conv_buttons[status].setChecked(True)

                if status == "some":
                        self.conv_slider_box.setVisible(True)
                        self.off_slider_box.setVisible(True)
                        self.conv_slider.setValue(c.get("count_idx", 0))
                        self.off_slider.setValue(self.state["offences"].get("count_idx", 0))

                # Prison
                p = self.state["prison"]
                p_status = p.get("status")

                if p_status in self.prison_buttons:
                        self.prison_buttons[p_status].setChecked(True)

                if p_status == "yes":
                        self.prison_slider_box.setVisible(True)
                        self.prison_slider.setValue(p.get("duration_idx", 0))

                self._update_preview()

        def _update_preview(self):
                """Legacy method name - now sends to card immediately."""
                self._send_to_card()

        def _send_to_card(self):
                """Send current text to card immediately."""
                import copy
                text = self.formatted_text()
                self.sent.emit(text, copy.deepcopy(self.state))

        def _emit(self):
                import copy
                self.sent.emit(self.formatted_text(), copy.deepcopy(self.state))
                self.close()

        def closeEvent(self, event):
                import copy
                self.closed.emit(copy.deepcopy(self.state))
                super().closeEvent(event)

        # ============================================================
        #  IMPORTED DATA FROM NOTES
        # ============================================================
        def set_extracted_data(self, items):
                """Display extracted data from notes with collapsible dated entry boxes."""
                # Clear existing
                for cb in self._extracted_checkboxes:
                        cb.setParent(None)
                        cb.deleteLater()
                self._extracted_checkboxes.clear()

                # Remove old widgets from layout
                while self.extracted_checkboxes_layout.count():
                        item = self.extracted_checkboxes_layout.takeAt(0)
                        if item.widget():
                                item.widget().deleteLater()

                # Handle legacy string format
                if isinstance(items, str):
                        items = [{"date": None, "text": p.strip()} for p in items.split("\n\n") if p.strip()]

                if not items:
                        self.extracted_section.setVisible(False)
                        return

                # Sort by date (newest first)
                from datetime import datetime
                def get_sort_date(item):
                        d = item.get("date")
                        if d is None:
                                return datetime.min
                        if isinstance(d, datetime):
                                return d
                        if isinstance(d, str):
                                for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%d %b %Y", "%d %B %Y"):
                                        try:
                                                return datetime.strptime(d, fmt)
                                        except ValueError:
                                                continue
                        return datetime.min

                sorted_items = sorted(items, key=get_sort_date, reverse=True)

                for item in sorted_items:
                        text = item.get("text", "")
                        date_val = item.get("date")

                        # Format date string
                        if date_val:
                                if isinstance(date_val, datetime):
                                        date_str = date_val.strftime("%d %b %Y")
                                elif isinstance(date_val, str):
                                        # Try to parse and reformat
                                        dt = None
                                        for fmt in ("%Y-%m-%d", "%d/%m/%Y", "%d %b %Y", "%d %B %Y"):
                                                try:
                                                        dt = datetime.strptime(date_val, fmt)
                                                        break
                                                except ValueError:
                                                        continue
                                        if dt:
                                                date_str = dt.strftime("%d %b %Y")
                                        else:
                                                date_str = str(date_val)
                                else:
                                        date_str = str(date_val)
                        else:
                                date_str = "No date"

                        # Create collapsible entry box
                        entry_frame = QFrame()
                        entry_frame.setObjectName("entryFrame")
                        entry_frame.setSizePolicy(QSizePolicy.Policy.Preferred, QSizePolicy.Policy.Minimum)
                        entry_frame.setStyleSheet("""
                                QFrame#entryFrame {
                                        background: rgba(255, 255, 255, 0.95);
                                        border: 1px solid rgba(180, 150, 50, 0.4);
                                        border-radius: 8px;
                                        padding: 4px;
                                }
                        """)
                        entry_layout = QVBoxLayout(entry_frame)
                        entry_layout.setContentsMargins(10, 8, 10, 8)
                        entry_layout.setSpacing(6)
                        entry_layout.setSizeConstraint(QVBoxLayout.SizeConstraint.SetMinAndMaxSize)

                        # Header row with checkbox, date, and toggle button
                        header_row = QHBoxLayout()
                        header_row.setSpacing(8)

                        # Toggle button on the LEFT
                        toggle_btn = QPushButton("▸")
                        toggle_btn.setFixedSize(22, 22)
                        toggle_btn.setCursor(Qt.CursorShape.PointingHandCursor)
                        toggle_btn.setStyleSheet("""
                                QPushButton {
                                        background: rgba(180, 150, 50, 0.2);
                                        border: none;
                                        border-radius: 4px;
                                        font-size: 21px;
                                        font-weight: bold;
                                        color: #806000;
                                }
                                QPushButton:hover { background: rgba(180, 150, 50, 0.35); }
                        """)
                        header_row.addWidget(toggle_btn)

                        # Date label
                        date_label = QLabel(f"📅 {date_str}")
                        date_label.setStyleSheet("""
                                QLabel {
                                        font-size: 21px;
                                        font-weight: 600;
                                        color: #806000;
                                        background: transparent;
                                        border: none;
                                }
                        """)
                        date_label.setCursor(Qt.CursorShape.PointingHandCursor)
                        header_row.addWidget(date_label)
                        header_row.addStretch()

                        # Checkbox on the RIGHT
                        cb = QCheckBox()
                        cb.setProperty("full_text", text)
                        cb.setFixedSize(18, 18)
                        cb.setStyleSheet("""
                                QCheckBox { background: transparent; }
                                QCheckBox::indicator { width: 16px; height: 16px; }
                        """)
                        cb.stateChanged.connect(self._update_preview)
                        header_row.addWidget(cb)

                        entry_layout.addLayout(header_row)

                        # Body (full content, hidden by default)
                        body_text = QTextEdit()
                        body_text.setPlainText(text)
                        body_text.setReadOnly(True)
                        body_text.setFrameShape(QFrame.Shape.NoFrame)
                        body_text.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
                        body_text.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
                        body_text.setStyleSheet("""
                                QTextEdit {
                                        font-size: 21px;
                                        color: #333;
                                        background: rgba(255, 248, 220, 0.5);
                                        border: none;
                                        padding: 8px;
                                        border-radius: 6px;
                                }
                        """)
                        # Calculate height based on content
                        body_text.document().setTextWidth(body_text.viewport().width() if body_text.viewport().width() > 0 else 350)
                        doc_height = body_text.document().size().height() + 20
                        body_text.setFixedHeight(int(max(doc_height, 60)))
                        body_text.setVisible(False)
                        entry_layout.addWidget(body_text)

                        # Toggle function
                        def make_toggle(btn, body, frame, popup_self):
                                def toggle():
                                        is_visible = body.isVisible()
                                        body.setVisible(not is_visible)
                                        btn.setText("▾" if not is_visible else "▸")
                                        # Force full layout recalculation
                                        frame.updateGeometry()
                                        if hasattr(popup_self, 'extracted_container'):
                                                popup_self.extracted_container.updateGeometry()
                                                popup_self.extracted_container.update()
                                return toggle

                        toggle_fn = make_toggle(toggle_btn, body_text, entry_frame, self)
                        toggle_btn.clicked.connect(toggle_fn)
                        date_label.mousePressEvent = lambda e, fn=toggle_fn: fn()

                        self.extracted_checkboxes_layout.addWidget(entry_frame)
                        self._extracted_checkboxes.append(cb)

                # Show the section and expand it
                self.extracted_section.setVisible(True)
                # Keep collapsed on open
                # if self.extracted_section._is_collapsed:
                #         self.extracted_section._toggle_collapse()
