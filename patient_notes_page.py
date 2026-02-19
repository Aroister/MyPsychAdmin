from __future__ import annotations

# ============================================================
# PATIENT NOTES PAGE + WORKSPACE AREA (FINAL — WRAP LAYOUT A1)
# ============================================================

import history_extractor_sections
print(">>> IMPORTED EXTRACTOR FROM:", history_extractor_sections.__file__)

from medication_extractor import extract_medications_from_notes
from medication_panel import MedicationPanel

from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QSplitter, QSizePolicy, QLayout, QStackedWidget, QScrollArea,
    QApplication, QGraphicsDropShadowEffect
)
from PySide6.QtCore import Qt, QSize, QRect, QPoint
from PySide6.QtGui import QColor

# Left Notes Panel
from patient_notes_panel import PatientNotesPanel

# Timeline
from floating_timeline_panel import FloatingTimelinePanel
from timeline_builder import build_timeline

# Patient History
from patient_history_panel import PatientHistoryPanel
from history_extractor_sections import extract_patient_history, convert_to_panel_format

# Physical Health
from physical_health_extractor import extract_physical_health_from_notes
from physical_health_panel import PhysicalHealthPanel
from utils.resource_path import resource_path


# ============================================================
# WRAP LAYOUT — FLUID A1
# ============================================================

class WrapLayout(QLayout):
    """A predictable, fluid wrap layout with line breaks."""

    def __init__(self, parent=None, margin=0, spacing=8):
        super().__init__(parent)
        self.setContentsMargins(margin, margin, margin, margin)
        self.setSpacing(spacing)
        self.items = []

    def addItem(self, item):
        self.items.append(item)

    def count(self):
        return len(self.items)

    def itemAt(self, index):
        return self.items[index] if index < len(self.items) else None

    def takeAt(self, index):
        return self.items.pop(index) if index < len(self.items) else None

    def expandingDirections(self):
        return Qt.Orientations(Qt.Orientation(0))

    def hasHeightForWidth(self):
        return True

    def heightForWidth(self, width):
        return self.doLayout(QRect(0, 0, width, 0), test=True)

    def setGeometry(self, rect):
        super().setGeometry(rect)
        self.doLayout(rect, test=False)

    def sizeHint(self):
        return QSize(200, 200)

    def minimumSize(self):
        return QSize(150, 100)

    def doLayout(self, rect, test=False):
        # Get content margins
        margins = self.contentsMargins()
        effective_rect = rect.adjusted(margins.left(), margins.top(), -margins.right(), -margins.bottom())

        # First pass: calculate rows
        rows = []
        current_row = []
        row_width = 0
        row_height = 0

        for item in self.items:
            size = item.sizeHint()
            item_width = size.width() + self.spacing()

            if row_width + size.width() > effective_rect.width() and current_row:
                # Start new row
                rows.append((current_row, row_width - self.spacing(), row_height))
                current_row = []
                row_width = 0
                row_height = 0

            current_row.append((item, size))
            row_width += item_width
            row_height = max(row_height, size.height())

        if current_row:
            rows.append((current_row, row_width - self.spacing(), row_height))

        # Second pass: position items centered
        y = effective_rect.y()
        for row_items, row_width, row_height in rows:
            # Center the row
            x_offset = (effective_rect.width() - row_width) // 2
            x = effective_rect.x() + x_offset

            for item, size in row_items:
                if not test:
                    item.setGeometry(QRect(QPoint(x, y), size))
                x += size.width() + self.spacing()

            y += row_height + self.spacing()

        total_height = y - self.spacing() - effective_rect.y() if rows else 0
        return total_height + margins.top() + margins.bottom()


# ============================================================
# SONOMA BUTTON STYLE
# ============================================================

def make_sonoma_button(btn: QPushButton):
    btn.setCursor(Qt.PointingHandCursor)
    btn.setFixedHeight(40)
    btn.setMinimumWidth(90)
    btn.setMaximumWidth(260)
    btn.setSizePolicy(QSizePolicy.Preferred, QSizePolicy.Fixed)

    btn.setStyleSheet("""
        QPushButton {
            background: rgba(255,255,255,0.20);
            border-radius: 18px;
            padding: 0 20px;
            font-size: 15px;
            color: #222;
            border: 1px solid rgba(255,255,255,0.35);
        }
        QPushButton:hover {
            background: rgba(255,255,255,0.28);
        }
        QPushButton:pressed {
            background: rgba(255,255,255,0.15);
        }
    """)
    return btn


# ============================================================
# ACRYLIC STYLE
# ============================================================

def apply_acrylic_style(widget: QWidget):
    widget.setAttribute(Qt.WA_StyledBackground, True)
    widget.setAttribute(Qt.WA_TranslucentBackground, True)
    widget.setStyleSheet("""
        QWidget {
            background: rgba(255,255,255,0.12);
            border-radius: 14px;
            border: 1px solid rgba(255,255,255,0.28);
            box-shadow: inset 0 0 12px rgba(0,0,0,0.15);
        }
    """)


# ============================================================
# WORKSPACE AREA - Fixed panels with button bar
# ============================================================

class WorkspaceArea(QWidget):
    def __init__(self, notes_panel, page_ref, parent=None):
        super().__init__(parent)

        self.page_ref = page_ref
        self.notes_panel = notes_panel
        self._active_button = None
        self._panels_cache = {}  # Cache created panels

        self.setMinimumWidth(240)
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        self._build_ui()

    def _build_ui(self):
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)

        # ============================================================
        # COLLAPSE BUTTON - at top of splitter
        # ============================================================
        self.btn_collapse = QPushButton(">>")
        self.btn_collapse.setFixedSize(28, 20)
        self.btn_collapse.setStyleSheet("""
            QPushButton {
                background: rgba(100, 100, 100, 0.25);
                border: 1px solid rgba(100, 100, 100, 0.4);
                border-left: none;
                border-top: none;
                border-bottom-right-radius: 6px;
                font-weight: bold;
                font-size: 11px;
                color: #444;
            }
            QPushButton:hover {
                background: rgba(58, 122, 254, 0.4);
                color: #000;
            }
        """)
        self.btn_collapse.clicked.connect(self._toggle_left_panel)
        self._left_panel_visible = True  # Track state
        outer.addWidget(self.btn_collapse, 0, Qt.AlignLeft)

        # ============================================================
        # TOP BUTTON BAR (wrapping layout)
        # ============================================================
        self.button_bar = QWidget()
        self.button_bar.setMinimumHeight(50)
        self.button_bar.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Minimum)
        self.button_bar.setStyleSheet("""
            QWidget {
                background: rgba(240, 242, 245, 0.95);
                border-bottom: 1px solid #d0d5da;
            }
        """)

        # Container for wrap layout buttons
        bar_layout = WrapLayout(self.button_bar, margin=12, spacing=10)

        # Create buttons with simpler style for toolbar
        self.btn_timeline = self._make_toolbar_button("Admissions", "timeline")
        self.btn_history = self._make_toolbar_button("History", "history")
        self.btn_phys = self._make_toolbar_button("Physical", "physical")
        self.btn_meds = self._make_toolbar_button("Medications", "meds")
        self.btn_risk = self._make_toolbar_button("Risk", "risk")
        self.btn_progress = self._make_toolbar_button("Progress", "progress")

        self.buttons = {
            "timeline": self.btn_timeline,
            "history": self.btn_history,
            "physical": self.btn_phys,
            "meds": self.btn_meds,
            "risk": self.btn_risk,
            "progress": self.btn_progress,
        }

        for btn in self.buttons.values():
            bar_layout.addWidget(btn)

        outer.addWidget(self.button_bar)

        # ============================================================
        # PANEL CONTAINER (Stacked Widget)
        # ============================================================
        self.panel_stack = QStackedWidget()
        self.panel_stack.setStyleSheet("""
            QStackedWidget {
                background: rgba(248, 250, 252, 0.95);
            }
        """)

        # Placeholder widget (shown when no panel selected)
        self.placeholder = QWidget()
        placeholder_layout = QVBoxLayout(self.placeholder)
        placeholder_layout.addStretch()
        self.placeholder_msg = QLabel("Select a panel from the toolbar above")
        self.placeholder_msg.setAlignment(Qt.AlignCenter)
        self.placeholder_msg.setStyleSheet("font-size: 18px; color: rgba(0,0,0,0.25);")
        placeholder_layout.addWidget(self.placeholder_msg)
        placeholder_layout.addStretch()
        self._has_data = False

        self.panel_stack.addWidget(self.placeholder)
        outer.addWidget(self.panel_stack, 1)

    def _make_toolbar_button(self, text: str, key: str) -> QPushButton:
        btn = QPushButton(text)
        btn.setFixedSize(95, 34)  # Fixed size so buttons don't compress
        btn.setCursor(Qt.PointingHandCursor)
        btn.setCheckable(True)
        btn.setStyleSheet("""
            QPushButton {
                background: rgba(255,255,255,0.85);
                border: 1px solid rgba(0,0,0,0.08);
                border-bottom: 2px solid rgba(0,0,0,0.1);
                border-radius: 8px;
                font-size: 13px;
                font-weight: 500;
                color: #333;
            }
            QPushButton:hover {
                background: rgba(255,255,255,0.95);
                border-color: rgba(0,0,0,0.12);
            }
            QPushButton:checked {
                background: #3a7afe;
                border: 1px solid #2a6ade;
                border-bottom: 2px solid #1a5ace;
                color: white;
            }
        """)

        # Add drop shadow for lifted card effect
        shadow = QGraphicsDropShadowEffect(btn)
        shadow.setBlurRadius(8)
        shadow.setXOffset(0)
        shadow.setYOffset(2)
        shadow.setColor(QColor(0, 0, 0, 40))
        btn.setGraphicsEffect(shadow)

        btn.clicked.connect(lambda checked, k=key: self._on_button_clicked(k))
        return btn

    def _on_button_clicked(self, key: str):
        """Handle button click - show corresponding panel."""
        # Uncheck ALL buttons first to prevent multiple lit buttons
        for btn in self.buttons.values():
            btn.setChecked(False)

        # Toggle off if clicking same button
        if self._active_button == key:
            self._active_button = None
            self.panel_stack.setCurrentWidget(self.placeholder)
            return

        # Check new button immediately for visual feedback
        self._active_button = key
        self.buttons[key].setChecked(True)

        # Force UI update so button highlights before slow panel creation
        self.setCursor(Qt.WaitCursor)
        QApplication.processEvents()

        # Show panel (create if needed)
        self._show_panel(key)

        # Restore cursor
        self.setCursor(Qt.ArrowCursor)

    def _show_panel(self, key: str):
        """Show the panel for the given key, creating it if needed."""
        # Check cache first
        if key in self._panels_cache:
            self.panel_stack.setCurrentWidget(self._panels_cache[key])
            return

        # Create the panel
        panel = self._create_panel(key)
        if panel:
            self._panels_cache[key] = panel
            self.panel_stack.addWidget(panel)
            self.panel_stack.setCurrentWidget(panel)

    def _create_panel(self, key: str) -> QWidget:
        """Create and return the panel widget for the given key."""
        notes = self.notes_panel.all_notes

        if key == "timeline":
            episodes = build_timeline(notes)
            from floating_timeline_panel import FloatingTimelinePanel
            panel = FloatingTimelinePanel(parent=None, manager_ref=self, embedded=True)
            panel.set_episodes(episodes, notes=notes)  # Pass notes for clerking panel
            panel.episodeClicked.connect(self.on_timeline_episode_clicked)
            return self._wrap_panel(panel)

        elif key == "history":
            episodes = build_timeline(notes)
            history = self.page_ref.get_clerkings_history(episodes=episodes)
            panel = PatientHistoryPanel(history, parent=None, embedded=True)
            return self._wrap_panel(panel)

        elif key == "physical":
            phys = extract_physical_health_from_notes(notes)
            panel = PhysicalHealthPanel(phys, parent=None, embedded=True)
            return self._wrap_panel(panel)

        elif key == "meds":
            from CANONICAL_MEDS import MEDICATIONS
            meds = extract_medications_from_notes(notes, MEDICATIONS)
            panel = MedicationPanel(meds, parent=None, embedded=True)
            return self._wrap_panel(panel)

        elif key == "risk":
            from risk_overview_panel import RiskOverviewPanel
            panel = RiskOverviewPanel(notes, parent=None, notes_panel=self.notes_panel, embedded=True)
            return self._wrap_panel(panel)

        elif key == "progress":
            from progress_panel import ProgressPanel
            panel = ProgressPanel(notes, parent=None, notes_panel=self.notes_panel, embedded=True)
            return self._wrap_panel(panel)

        return None

    def _wrap_panel(self, panel: QWidget) -> QWidget:
        """Wrap panel in a scroll area for consistent display."""
        # Make panel expand to fill available space
        panel.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        panel.setMinimumSize(1, 1)  # Allow shrinking

        scroll = QScrollArea()
        scroll.setWidget(panel)
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        scroll.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        scroll.setStyleSheet("""
            QScrollArea {
                background: transparent;
                border: none;
            }
        """)
        return scroll

    def on_timeline_episode_clicked(self, date_obj):
        try:
            self.notes_panel.jump_to_date(date_obj)
        except Exception:
            pass

    def refresh_panels(self):
        """Refresh all cached panels with new notes data."""
        # Clear cache - panels will be recreated on next click
        for key, panel in list(self._panels_cache.items()):
            self.panel_stack.removeWidget(panel)
            panel.deleteLater()
        self._panels_cache.clear()

        # Highlight placeholder to indicate data is ready
        if not self._has_data:
            self._has_data = True
            self.placeholder_msg.setText("✨ Data loaded - Select a panel above ✨")
            self.placeholder_msg.setStyleSheet("font-size: 18px; font-weight: bold; color: #3a7afe;")

        # Re-show current panel if one was active
        if self._active_button:
            self._show_panel(self._active_button)

    def _toggle_left_panel(self):
        """Toggle the left notes panel visibility."""
        if self._left_panel_visible:
            # Collapse left panel
            self._left_panel_visible = False
            self.btn_collapse.setText("<<")  # Arrow points left = "click to show left panel"
            self.notes_panel.collapse()
        else:
            # Expand left panel
            self._left_panel_visible = True
            self.btn_collapse.setText(">>")  # Arrow points right = "click to hide left panel"
            self.notes_panel.expand()


# ============================================================
# MAIN PATIENT NOTES PAGE
# ============================================================

class PatientNotesPage(QWidget):
    def __init__(self, db=None, parent=None):
        super().__init__(parent)

        # Guard flag to prevent reprocessing on navigation
        self._notes_processed_id = None

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        # Main splitter
        self.splitter = QSplitter(Qt.Horizontal)
        self.splitter.setHandleWidth(10)   # slightly wider
        self.splitter.setChildrenCollapsible(False)

        self.splitter.setStretchFactor(0, 1)
        self.splitter.setStretchFactor(1, 1)

        # 🔥 Visible drag bar patch
        self.splitter.setStyleSheet("""
            QSplitter::handle {
                background: rgba(80, 80, 80, 0.45);      /* darker, visible */
                width: 10px;                              /* wider grip */
                border-radius: 5px;
            }
            QSplitter::handle:hover {
                background: rgba(40,120,255,0.55);        /* macOS blue highlight */
            }
        """)

        # --- Left panel ---
        self.notes_panel = PatientNotesPanel(db=db, parent=self)
        # --- Connect collapse/expand signals from toolbar ---
        self.notes_panel.request_collapse.connect(self._collapse_notes_panel)
        self.notes_panel.request_expand.connect(self._expand_notes_panel)

        apply_acrylic_style(self.notes_panel)
        self.notes_panel.setMinimumWidth(240)

        self.splitter.addWidget(self.notes_panel)

        # --- Right workspace ---
        self.workspace = WorkspaceArea(self.notes_panel, page_ref=self, parent=self)
        self.workspace.setMinimumWidth(260)

        self.splitter.addWidget(self.workspace)

        # Initial sizes
        self.splitter.setSizes([600, 900])

        layout.addWidget(self.splitter)
        
    def _collapse_notes_panel(self):
        # Allow full collapse
        self.notes_panel.setMinimumWidth(0)

        # Collapse left panel fully
        try:
            self.splitter.setSizes([0, self.width()])
        except Exception as e:
            print("Collapse error:", e)

    def _expand_notes_panel(self):
        # Restore minimum width
        self.notes_panel.setMinimumWidth(240)

        # Expand to a reasonable width
        try:
            self.splitter.setSizes([350, self.width() - 350])
        except Exception as e:
            print("Expand error:", e)

    def set_notes(self, notes: list):
        """
        Set notes from shared data store.
        Called by MainWindow when notes are available from another section.
        Updates the notes panel to display the new notes.
        """
        if not notes:
            print(f"[NotesPage] set_notes called with empty notes - skipping")
            return

        # Skip if these exact notes were already processed
        notes_sig = (len(notes), id(notes))
        if self._notes_processed_id == notes_sig:
            print(f"[NotesPage] Skipping set_notes - notes already processed")
            return
        self._notes_processed_id = notes_sig

        print(f"[NotesPage] set_notes called with {len(notes)} notes")
        print(f"[NotesPage] First note keys: {list(notes[0].keys()) if notes else 'N/A'}")

        # Update the notes panel with the new notes
        self.notes_panel.all_notes = notes
        self.notes_panel._rebuild_type_filter()
        self.notes_panel.filter_types()

        print(f"[NotesPage] Updated notes_panel.all_notes: {len(self.notes_panel.all_notes)} notes")
        print(f"[NotesPage] filtered_notes after filter: {len(self.notes_panel.filtered_notes)} notes")

        # Refresh workspace panels so they pick up the new notes
        self.workspace.refresh_panels()

    # History extraction
    def get_clerkings_history(self, episodes=None):
        prepared = []
        for n in self.notes_panel.all_notes:
            prepared.append({
                "date": n.get("date"),
                "type": (n.get("type") or "").strip().lower(),
                "originator": n.get("originator", "").strip(),
                "content": n.get("content", "").strip(),
                "source": n.get("source", "").strip().lower()
            })
        hist = extract_patient_history(prepared, episodes=episodes)
        return convert_to_panel_format(hist)
