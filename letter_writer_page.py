from __future__ import annotations

import os
import re
import sys
from html import unescape

from PySide6.QtCore import Qt, Signal, QPoint, QSize, QEvent
from PySide6.QtGui import QColor, QIcon, QFont
from PySide6.QtWidgets import (
        QWidget, QHBoxLayout, QVBoxLayout, QScrollArea, QSplitter,
        QLabel, QFrame, QGraphicsDropShadowEffect, QPushButton, QTextEdit
)
from PySide6.QtWidgets import QSizePolicy
from PySide6.QtWidgets import QStackedWidget
from mypsy_richtext_editor import MyPsychAdminRichTextEditor
from data_extractor_popup import DataExtractorPopup
from icd10_data import load_icd10_dict
from utils.resource_path import resource_path


ICD10_DICT = load_icd10_dict(
        resource_path("ICD10_DICT.txt")
)

from letter_sidebar_popup import FrontPageSidebarPopup
from letter_sidebar_popup_med import MedicationSidebarPopup
from presenting_complaint_popup import PresentingComplaintPopup
from history_presenting_complaint_popup import HistoryPresentingComplaintPopup
from affect_popup import AffectPopup
from anxiety_popup import AnxietyPopup
from psychosis_popup import PsychosisPopup
from past_psych_popup import PastPsychPopup
from background_history_popup import BackgroundHistoryPopup
from drugs_alcohol_popup import DrugsAlcoholPopup
from social_history_popup import SocialHistoryPopup
from forensic_history_popup import ForensicHistoryPopup
from physical_health_popup import PhysicalHealthPopup
from function_popup import FunctionPopup
from mental_state_examination_popup import MentalStateExaminationPopup
from impression_popup import ImpressionPopup
from plan_popup import PlanPopup


# Define pronouns function in the current file
def pronouns_from_gender(g: str):
    g = (g or "").strip().lower()
    if g.startswith("m"):
        return ("he", "him", "his")
    if g.startswith("f"):
        return ("she", "her", "her")
    return ("they", "them", "their")

# ================================================================
#  ZOOM HELPER FUNCTION
# ================================================================

def create_zoom_row(text_edit: QTextEdit, base_size: int = 13) -> QHBoxLayout:
    """Create a zoom controls row for any QTextEdit."""
    zoom_row = QHBoxLayout()
    zoom_row.setSpacing(2)
    zoom_row.addStretch()

    text_edit._font_size = base_size

    zoom_out_btn = QPushButton("−")
    zoom_out_btn.setFixedSize(16, 16)
    zoom_out_btn.setCursor(Qt.CursorShape.PointingHandCursor)
    zoom_out_btn.setToolTip("Decrease font size")
    zoom_out_btn.setStyleSheet("""
        QPushButton {
            background: #f3f4f6;
            color: #374151;
            border: 1px solid #d1d5db;
            border-radius: 3px;
            font-size: 15px;
            font-weight: bold;
        }
        QPushButton:hover { background: #e5e7eb; }
    """)
    zoom_row.addWidget(zoom_out_btn)

    zoom_in_btn = QPushButton("+")
    zoom_in_btn.setFixedSize(16, 16)
    zoom_in_btn.setCursor(Qt.CursorShape.PointingHandCursor)
    zoom_in_btn.setToolTip("Increase font size")
    zoom_in_btn.setStyleSheet("""
        QPushButton {
            background: #f3f4f6;
            color: #374151;
            border: 1px solid #d1d5db;
            border-radius: 3px;
            font-size: 15px;
            font-weight: bold;
        }
        QPushButton:hover { background: #e5e7eb; }
    """)
    zoom_row.addWidget(zoom_in_btn)

    def zoom_in():
        text_edit._font_size = min(text_edit._font_size + 2, 28)
        font = text_edit.font()
        font.setPointSize(text_edit._font_size)
        text_edit.setFont(font)

    def zoom_out():
        text_edit._font_size = max(text_edit._font_size - 2, 8)
        font = text_edit.font()
        font.setPointSize(text_edit._font_size)
        text_edit.setFont(font)

    zoom_in_btn.clicked.connect(zoom_in)
    zoom_out_btn.clicked.connect(zoom_out)

    return zoom_row


# ================================================================
#  CARD WIDGET
# ================================================================

class CardWidget(QFrame):

        clicked = Signal(str)

        def __init__(self, title: str, key: str, parent=None):
                super().__init__(parent)
                self.title = title
                self.key = key
                self._active = False

                
                self.setObjectName("letterCard")
                self.setStyleSheet("""
                        QFrame#letterCard {
                                background: rgba(255,255,255,0.65);
                                border-radius: 18px;
                                border: 1px solid rgba(0,0,0,0.08);
                        }
                        QLabel#cardTitle {
                                font-size: 29px;
                                font-weight: 600;
                                color: #003c32;
                                padding-bottom: 4px;
                        }
                        QFrame#divider {
                                background: rgba(0,0,0,0.10);
                                height: 1px;
                                margin: 6px 0 14px 0;
                        }
                """)

                shadow = QGraphicsDropShadowEffect(self)
                shadow.setBlurRadius(22)
                shadow.setYOffset(3)
                shadow.setColor(QColor(0, 0, 0, 40))
                self.setGraphicsEffect(shadow)

                layout = QVBoxLayout(self)
                layout.setContentsMargins(22, 22, 22, 22)
                layout.setSpacing(12)

                self.title_label = QLabel(title)
                self.title_label.setObjectName("cardTitle")
                title_font = QFont("Segoe UI", 16) if sys.platform == "win32" else QFont("Helvetica Neue", 19)
                title_font.setWeight(QFont.Weight.DemiBold)
                self.title_label.setFont(title_font)
                self.title_label.setStyleSheet("color: #003c32; padding-bottom: 4px;")
                self.title_label.setCursor(Qt.CursorShape.PointingHandCursor)
                self.title_label.mousePressEvent = lambda e: self.clicked.emit(self.key)
                layout.addWidget(self.title_label)


                divider = QFrame()
                divider.setObjectName("divider")
                layout.addWidget(divider)

                self.editor = MyPsychAdminRichTextEditor()
                self.editor.setPlaceholderText("Click to edit...")
                self._editor_height = 180
                self.editor.setMinimumHeight(80)
                self.editor.setMaximumHeight(self._editor_height)
                editor_zoom = create_zoom_row(self.editor, base_size=17)
                layout.addLayout(editor_zoom)
                layout.addWidget(self.editor)

                # Expand/resize bar
                self.expand_bar = QFrame()
                self.expand_bar.setFixedHeight(10)
                self.expand_bar.setCursor(Qt.CursorShape.SizeVerCursor)
                self.expand_bar.setObjectName("expandBar")
                self.expand_bar.setStyleSheet("""
                    QFrame#expandBar {
                        background: #d1d5db;
                        border-radius: 2px;
                        margin: 2px 50px;
                    }
                    QFrame#expandBar:hover {
                        background: #6BAF8D;
                    }
                """)
                self.expand_bar.installEventFilter(self)
                self._dragging = False
                self._drag_start_y = 0
                self._drag_start_height = 0
                layout.addWidget(self.expand_bar)

                self._orig_focus_in = self.editor.focusInEvent
                self.editor.focusInEvent = self._focus_in_event
                self.setCursor(Qt.CursorShape.PointingHandCursor)
                self.setFocusPolicy(Qt.FocusPolicy.StrongFocus)

        def eventFilter(self, obj, event):
                """Handle drag events on the expand bar."""
                if obj == self.expand_bar:
                        if event.type() == QEvent.Type.MouseButtonPress:
                                self._dragging = True
                                self._drag_start_y = event.globalPosition().y()
                                self._drag_start_height = self._editor_height
                                return True
                        elif event.type() == QEvent.Type.MouseMove and self._dragging:
                                delta = event.globalPosition().y() - self._drag_start_y
                                new_height = max(80, min(600, self._drag_start_height + delta))
                                self._editor_height = int(new_height)
                                self.editor.setMinimumHeight(self._editor_height)
                                self.editor.setMaximumHeight(self._editor_height)
                                self.editor.setFixedHeight(self._editor_height)
                                return True
                        elif event.type() == QEvent.Type.MouseButtonRelease:
                                self._dragging = False
                                return True
                return super().eventFilter(obj, event)

        def set_active(self, active: bool):
                if active:
                        self.setStyleSheet("""
                                QFrame#letterCard {
                                        background: rgba(200,235,215,0.70);
                                        border: 1.5px solid #6BAF8D;
                                        border-radius: 18px;
                                }
                        """)
                else:
                        self.setStyleSheet("""
                                QFrame#letterCard {
                                        background: rgba(255,255,255,0.65);
                                        border: 1px solid rgba(0,0,0,0.08);
                                        border-radius: 18px;
                                }
                        """)


        def _focus_in_event(self, event):
                parent = self.parent()
                while parent and not hasattr(parent, "_register_active_editor"):
                        parent = parent.parent()
                if parent:
                        parent._register_active_editor(self.editor)
                self._orig_focus_in(event)

        def get_text(self):
                return self.editor.toMarkdown()

        def mousePressEvent(self, event):
                self.clicked.emit(self.key)
                super().mousePressEvent(event)


# ================================================================
#  LETTER WRITER PAGE
# ================================================================

class LetterWriterPage(QWidget):

        EXTRACTOR_CATEGORY_TO_CARD = {
                "FRONT PAGE": "front",
                "Past Psychiatric History": "psychhx",
                "Presenting Complaint": "pc",  # Corrected syntax
                "History of Presenting Complaint": "hpc",
                "Personal History": "background",
                "Background History": "background",
                "Social History": "social",
                "Forensic History": "forensic",
                "Drug and Alcohol History": "drugalc",
                "Physical Health": "physical",
                "Mental State Examination": "mse",
                "Diagnosis": "summary",
                "Impression": "summary",
                "Risk": "summary",
                "Plan": "plan",
        }

        def __init__(self, parent=None, notes=None):
                super().__init__(parent)

                self.page_ref = parent
                self.cards = {}
                self._active_editor = None
                self.all_notes = notes or []
                self.last_extracted_panel_data = None
                self._pending_extracted_panel_data = None
                self._pc_saved_state = {}
                self._hpc_saved_state = {}
                self._affect_saved_state = {}
                self._anxiety_saved_state = {}
                self._psychosis_saved_state = {}
                self._psychhx_saved_state = {}
                self._background_saved_state = {}
                self._drugalc_saved_state = {}
                self._social_saved_state = {}
                self._forensic_saved_state = {}
                self._physical_saved_state = {}
                self._function_saved_state = {}
                self._mse_saved_state = {}
                self._summary_saved_state = {}
                self._plan_saved_state = {}

                # Popup memory for storing popup field values (used by export)
                self.popup_memory = {}

                # Track last popup-generated content for each card (for smart updates)
                self._last_popup_content = {}

                # Guard flags to prevent reprocessing on navigation
                self._data_processed_id = None
                self._notes_processed_id = None

                # ==================================================
                # ROOT LAYOUT
                # ==================================================
                
                main = QVBoxLayout(self)
                main.setContentsMargins(0, 0, 0, 0)
                main.setSpacing(0)

                # ==================================================
                # TOOLBAR (HOST FOR LetterToolbar)
                # ==================================================
                self.toolbar_frame = QFrame(self)
                self.toolbar_frame.setFixedHeight(84)

                self.toolbar_container = QWidget(self.toolbar_frame)
                self.toolbar_container_layout = QHBoxLayout(self.toolbar_container)
                self.toolbar_container_layout.setContentsMargins(0, 0, 0, 0)
                self.toolbar_container_layout.setSpacing(0)

                toolbar_layout = QVBoxLayout(self.toolbar_frame)
                toolbar_layout.setContentsMargins(0, 0, 0, 0)
                toolbar_layout.addWidget(self.toolbar_container)

                main.addWidget(self.toolbar_frame)

                # ==================================================
                # MAIN SPLIT AREA (with draggable splitter)
                # ==================================================
                self.splitter = QSplitter(Qt.Horizontal)
                self.splitter.setHandleWidth(6)
                self.splitter.setStyleSheet("""
                    QSplitter::handle {
                        background: #d1d5db;
                    }
                    QSplitter::handle:hover {
                        background: #6BAF8D;
                    }
                """)
                main.addWidget(self.splitter)

                # ==================================================
                # SECTIONS
                # ==================================================
                self.sections = [
                        ("Front Page", "front"),
                        ("Presenting Complaint", "pc"),
                        ("History of Presenting Complaint", "hpc"),
                        ("Affect", "affect"),
                        ("Anxiety & Related Disorders", "anxiety"),
                        ("Psychosis", "psychosis"),
                        ("Psychiatric History", "psychhx"),
                        ("Background History", "background"),
                        ("Drug and Alcohol History", "drugalc"),
                        ("Social History", "social"),
                        ("Forensic History", "forensic"),
                        ("Physical Health", "physical"),
                        ("Function", "function"),
                        ("Mental State Examination", "mse"),
                        ("Summary", "summary"),
                        ("Plan", "plan"),
                ]


                # ---------------- LEFT: CARDS ----------------
                self.cards_holder = QScrollArea()
                self.cards_holder.setWidgetResizable(True)
                self.cards_holder.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
                self.splitter.addWidget(self.cards_holder)

                self.editor_root = QWidget()
                self.editor_layout = QVBoxLayout(self.editor_root)
                self.editor_layout.setContentsMargins(40, 40, 40, 40)
                self.editor_layout.setSpacing(28)
                self.cards_holder.setWidget(self.editor_root)

                # ---------------- RIGHT: PANEL ----------------
                self.editor_panel = QFrame()
                self.editor_panel.setMinimumWidth(350)
                self.editor_panel.setMaximumWidth(600)
                self.editor_panel.setStyleSheet("""
                        QFrame {
                                background: rgba(245,245,245,0.95);
                                border-left: 1px solid rgba(0,0,0,0.08);
                        }
                """)
                self.splitter.addWidget(self.editor_panel)

                # Set initial splitter sizes (left panel larger)
                self.splitter.setSizes([700, 460])

                panel_layout = QVBoxLayout(self.editor_panel)
                panel_layout.setContentsMargins(24, 24, 24, 24)
                panel_layout.setSpacing(12)


                # Header row with title and lock button
                self.panel_header = QWidget()
                self.panel_header.setStyleSheet("""
                        background: rgba(200,235,215,0.75);
                        border-radius: 8px;
                """)
                header_layout = QHBoxLayout(self.panel_header)
                header_layout.setContentsMargins(10, 6, 10, 6)
                header_layout.setSpacing(8)

                self.panel_title = QLabel("Select a section")
                self.panel_title.setWordWrap(True)
                self.panel_title.setStyleSheet("""
                        font-size: 28px;
                        font-weight: 700;
                        color: #003c32;
                        background: transparent;
                """)
                header_layout.addWidget(self.panel_title, 1)

                # Lock button in header
                self.header_lock_btn = QPushButton("Unlocked")
                self.header_lock_btn.setFixedSize(70, 26)
                self.header_lock_btn.setCursor(Qt.CursorShape.PointingHandCursor)
                self.header_lock_btn.setToolTip("Click to lock this section")
                self.header_lock_btn.setStyleSheet("""
                        QPushButton {
                                background: rgba(34, 197, 94, 0.3);
                                border: 2px solid #22c55e;
                                border-radius: 13px;
                                font-size: 13px;
                                font-weight: 600;
                                color: #16a34a;
                        }
                        QPushButton:hover {
                                background: rgba(34, 197, 94, 0.5);
                        }
                """)
                self.header_lock_btn.clicked.connect(self._toggle_current_popup_lock)
                self.header_lock_btn.hide()  # Hidden until a popup is active
                header_layout.addWidget(self.header_lock_btn)

                panel_layout.addWidget(self.panel_header)

                

                self.create_all_cards()

                if self._pending_extracted_panel_data:
                        self._insert_extracted_data_into_letter(
                                self._pending_extracted_panel_data
                        )
                        self._pending_extracted_panel_data = None
                # ==================================================
                # RIGHT PANEL — EDITOR STACK
                # ==================================================
                self.editor_stack = QStackedWidget(self.editor_panel)

                panel_layout.addWidget(self.editor_stack, 1)


                # --------------------------------------------------
                # FRONT PAGE SIDEBAR POPUP (lazy-created)
                # --------------------------------------------------
                self.front_popup = None
                
                # Build editors AFTER cards exist
                self._build_editor_stack()


                
        def update_panel_title(self, title: str, bg_color: str):
                """Helper method to update panel title and its style."""
                self.panel_title.setText(title)
                self.panel_header.setStyleSheet(f"""
                        background: {bg_color};
                        border-radius: 8px;
                """)

        def _toggle_current_popup_lock(self):
                """Toggle lock on the currently active popup."""
                popup = getattr(self, '_current_popup', None)
                if popup and hasattr(popup, 'toggle_lock'):
                        popup.toggle_lock()
                        self._update_header_lock_button()

        def _update_header_lock_button(self):
                """Update header lock button to match current popup state."""
                popup = getattr(self, '_current_popup', None)
                if popup and hasattr(popup, 'is_locked'):
                        is_locked = popup.is_locked()
                        if is_locked:
                                self.header_lock_btn.setText("Locked")
                                self.header_lock_btn.setToolTip("Click to unlock this section")
                                self.header_lock_btn.setStyleSheet("""
                                        QPushButton {
                                                background: rgba(239, 68, 68, 0.3);
                                                border: 2px solid #ef4444;
                                                border-radius: 13px;
                                                font-size: 13px;
                                                font-weight: 600;
                                                color: #dc2626;
                                        }
                                        QPushButton:hover { background: rgba(239, 68, 68, 0.5); }
                                """)
                        else:
                                self.header_lock_btn.setText("Unlocked")
                                self.header_lock_btn.setToolTip("Click to lock this section")
                                self.header_lock_btn.setStyleSheet("""
                                        QPushButton {
                                                background: rgba(34, 197, 94, 0.3);
                                                border: 2px solid #22c55e;
                                                border-radius: 13px;
                                                font-size: 13px;
                                                font-weight: 600;
                                                color: #16a34a;
                                        }
                                        QPushButton:hover { background: rgba(34, 197, 94, 0.5); }
                                """)
                        self.header_lock_btn.show()
                else:
                        self.header_lock_btn.hide()

        def _set_current_popup(self, popup):
                """Set the current active popup and update lock button."""
                self._current_popup = popup
                self._update_header_lock_button()
        # ======================================================
        # activate
        # ======================================================

        def _activate_section(self, key: str):
                # Update card highlight
                for k, card in self.cards.items():
                        card.set_active(k == key)

                # Handle the Presenting Complaint section
                if key == "pc":
                        self.editor_stack.hide()
                        self._close_all_popups()
                        print("[DEBUG] Entering Presenting Complaint section")

                        # Ensure PresentingComplaintPopup is created only once
                        if not hasattr(self.page_ref, 'presenting_complaint_popup') or not self.page_ref.presenting_complaint_popup:
                                print("[DEBUG] Creating PresentingComplaintPopup")
                                # Ensure front_popup is created first if not created already
                                self._ensure_front_popup()

                                # Now fetch gender after ensuring front_popup is created
                                gender = self.page_ref.front_popup.gender_field.currentText().strip().lower()
                                pronouns = pronouns_from_gender(gender)

                                # Create Presenting Complaint Popup and pass pronouns
                                self.page_ref.presenting_complaint_popup = PresentingComplaintPopup(
                                        gender=gender,
                                        pronouns=pronouns,  # Pass pronouns to the constructor
                                        db=getattr(self.page_ref, "db", None),
                                        cards=self.cards
                                )

                                # Connect the sent signal to update the card
                                self.page_ref.presenting_complaint_popup.sent.connect(
                                        lambda text: self._update_card_from_popup("pc", text)
                                )

                                # Add it to the panel layout
                                self.page_ref.presenting_complaint_popup.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
                                self.editor_panel.layout().addWidget(self.page_ref.presenting_complaint_popup)
                                self.page_ref.presenting_complaint_popup.closed.connect(self._store_pc_state)

                                # Populate from imported data if available
                                print(f"[DEBUG] Checking _imported_sections: exists={hasattr(self, '_imported_sections')}")
                                if hasattr(self, '_imported_sections') and self._imported_sections:
                                        from docx_letter_importer import populate_presenting_complaint_popup
                                        pc_content = self._imported_sections.get('pc', '')
                                        print(f"[DEBUG] PC content length: {len(pc_content)}")
                                        hpc_content = self._imported_sections.get('hpc', '')
                                        if pc_content:
                                                populate_presenting_complaint_popup(self.page_ref.presenting_complaint_popup, pc_content)
                                                print("[IMPORT] Populated PC popup from imported data")
                                        if hpc_content:
                                                populate_presenting_complaint_popup(self.page_ref.presenting_complaint_popup, hpc_content)
                                                print("[IMPORT] Populated PC popup from HPC content")

                        # Ensure the Presenting Complaint popup is visible
                        if self.page_ref.presenting_complaint_popup:
                                print("[DEBUG] Showing PresentingComplaintPopup")
                                self.page_ref.presenting_complaint_popup.show()
                                self.page_ref.presenting_complaint_popup.raise_()

                        # Update the panel title
                        self.update_panel_title("Presenting Complaint", "rgba(200,235,215,0.75)")
                        self._set_current_popup(self.page_ref.presenting_complaint_popup)
                        return

                # Handle the History of Presenting Complaint section
                if key == "hpc":
                        self.editor_stack.hide()
                        self._close_all_popups()
                        print("[DEBUG] Entering History of Presenting Complaint section")

                        # Ensure HPC popup is created only once
                        if not hasattr(self.page_ref, 'history_popup') or not self.page_ref.history_popup:
                                print("[DEBUG] Creating HistoryPresentingComplaintPopup")

                                # Ensure front_popup is created first for gender
                                self._ensure_front_popup()

                                # Fetch gender from front_popup
                                gender = self.page_ref.front_popup.gender_field.currentText().strip().lower()

                                # Create History of Presenting Complaint Popup
                                self.page_ref.history_popup = HistoryPresentingComplaintPopup(
                                        gender=gender,
                                        parent=self.editor_panel
                                )

                                # Connect the sent signal to update the card
                                self.page_ref.history_popup.sent.connect(
                                        lambda text: self._update_card_from_popup("hpc", text)
                                )

                                # Add it to the panel layout
                                self.page_ref.history_popup.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
                                self.editor_panel.layout().addWidget(self.page_ref.history_popup)
                                self.page_ref.history_popup.closed.connect(self._store_hpc_state)

                                # Populate from imported data if available
                                if hasattr(self, '_imported_sections') and self._imported_sections:
                                        from docx_letter_importer import populate_hpc_popup
                                        hpc_content = self._imported_sections.get('hpc', '')
                                        if hpc_content:
                                                populate_hpc_popup(self.page_ref.history_popup, hpc_content)
                                                print("[IMPORT] Populated HPC popup from imported data")

                        # Ensure the HPC popup is visible
                        if self.page_ref.history_popup:
                                print("[DEBUG] Showing HistoryPresentingComplaintPopup")
                                self.page_ref.history_popup.show()
                                self.page_ref.history_popup.raise_()

                        # Update the panel title
                        self.update_panel_title("History of\nPresenting Complaint", "rgba(200,235,215,0.75)")
                        self._set_current_popup(self.page_ref.history_popup)
                        return

                # Handle the Affect section
                if key == "affect":
                        self.editor_stack.hide()
                        self._close_all_popups()
                        print("[DEBUG] Entering Affect section")

                        # Ensure Affect popup is created only once
                        if not hasattr(self.page_ref, 'affect_popup') or not self.page_ref.affect_popup:
                                print("[DEBUG] Creating AffectPopup")

                                # Ensure front_popup is created first for gender/name
                                self._ensure_front_popup()

                                # Fetch gender and name from front_popup
                                gender = self.page_ref.front_popup.gender_field.currentText().strip().lower()
                                first_name = self.page_ref.front_popup.first_name_field.text().strip() if hasattr(self.page_ref.front_popup, 'first_name_field') else "The patient"

                                # Create Affect Popup
                                self.page_ref.affect_popup = AffectPopup(
                                        first_name=first_name,
                                        gender=gender,
                                        parent=self.editor_panel
                                )

                                # Connect the sent signal to update the card
                                self.page_ref.affect_popup.sent.connect(
                                        lambda text: self._update_card_from_popup("affect", text)
                                )

                                # Add it to the panel layout
                                self.page_ref.affect_popup.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
                                self.editor_panel.layout().addWidget(self.page_ref.affect_popup)
                                self.page_ref.affect_popup.closed.connect(self._store_affect_state)

                                # Populate from imported data if available
                                if hasattr(self, '_imported_sections') and self._imported_sections:
                                        from docx_letter_importer import populate_affect_popup
                                        affect_content = self._imported_sections.get('affect', '')
                                        if affect_content:
                                                populate_affect_popup(self.page_ref.affect_popup, affect_content)
                                                print("[IMPORT] Populated Affect popup from imported data")

                        # Ensure the Affect popup is visible
                        if self.page_ref.affect_popup:
                                print("[DEBUG] Showing AffectPopup")
                                self.page_ref.affect_popup.show()
                                self.page_ref.affect_popup.raise_()

                        # Update the panel title
                        self.update_panel_title("Affect", "rgba(200,235,215,0.75)")
                        self._set_current_popup(self.page_ref.affect_popup)
                        return

                # Handle the Anxiety section
                if key == "anxiety":
                        self.editor_stack.hide()
                        self._close_all_popups()
                        print("[DEBUG] Entering Anxiety section")

                        # Ensure Anxiety popup is created only once
                        if not hasattr(self.page_ref, 'anxiety_popup') or not self.page_ref.anxiety_popup:
                                print("[DEBUG] Creating AnxietyPopup")

                                # Ensure front_popup is created first for gender/name
                                self._ensure_front_popup()

                                # Fetch gender and name from front_popup
                                gender = self.page_ref.front_popup.gender_field.currentText().strip().lower()
                                first_name = self.page_ref.front_popup.first_name_field.text().strip() if hasattr(self.page_ref.front_popup, 'first_name_field') else "The patient"

                                # Create Anxiety Popup
                                self.page_ref.anxiety_popup = AnxietyPopup(
                                        first_name=first_name,
                                        gender=gender,
                                        parent=self.editor_panel
                                )

                                # Connect the sent signal to update the card
                                self.page_ref.anxiety_popup.sent.connect(
                                        lambda text, state: self._update_card_from_popup("anxiety", text)
                                )

                                # Add it to the panel layout
                                self.page_ref.anxiety_popup.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
                                self.editor_panel.layout().addWidget(self.page_ref.anxiety_popup)
                                self.page_ref.anxiety_popup.sent.connect(self._store_anxiety_state)

                                # Populate from imported data if available
                                if hasattr(self, '_imported_sections') and self._imported_sections:
                                        from docx_letter_importer import populate_anxiety_popup
                                        anxiety_content = self._imported_sections.get('anxiety', '')
                                        if anxiety_content:
                                                populate_anxiety_popup(self.page_ref.anxiety_popup, anxiety_content)
                                                print("[IMPORT] Populated Anxiety popup from imported data")

                        # Ensure the Anxiety popup is visible
                        if self.page_ref.anxiety_popup:
                                print("[DEBUG] Showing AnxietyPopup")
                                self.page_ref.anxiety_popup.show()
                                self.page_ref.anxiety_popup.raise_()

                        # Update the panel title
                        self.update_panel_title("Anxiety", "rgba(200,235,215,0.75)")
                        self._set_current_popup(self.page_ref.anxiety_popup)
                        return

                # Handle the Psychosis section
                if key == "psychosis":
                        self.editor_stack.hide()
                        self._close_all_popups()
                        print("[DEBUG] Entering Psychosis section")

                        # Ensure Psychosis popup is created only once
                        if not hasattr(self.page_ref, 'psychosis_popup') or not self.page_ref.psychosis_popup:
                                print("[DEBUG] Creating PsychosisPopup")

                                # Ensure front_popup is created first for gender/name
                                self._ensure_front_popup()

                                # Fetch gender and name from front_popup
                                gender = self.page_ref.front_popup.gender_field.currentText().strip().lower()
                                first_name = self.page_ref.front_popup.first_name_field.text().strip() if hasattr(self.page_ref.front_popup, 'first_name_field') else "The patient"

                                # Create Psychosis Popup
                                self.page_ref.psychosis_popup = PsychosisPopup(
                                        first_name=first_name,
                                        gender=gender,
                                        parent=self.editor_panel
                                )

                                # Connect the saved signal to update the card
                                self.page_ref.psychosis_popup.saved.connect(
                                        lambda payload: self._update_card_from_popup("psychosis", payload.get("text", ""))
                                )

                                # Add it to the panel layout
                                self.page_ref.psychosis_popup.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
                                self.editor_panel.layout().addWidget(self.page_ref.psychosis_popup)
                                self.page_ref.psychosis_popup.saved.connect(self._store_psychosis_state)

                                # Populate from imported data if available
                                if hasattr(self, '_imported_sections') and self._imported_sections:
                                        from docx_letter_importer import populate_psychosis_popup
                                        psychosis_content = self._imported_sections.get('psychosis', '')
                                        if psychosis_content:
                                                populate_psychosis_popup(self.page_ref.psychosis_popup, psychosis_content)
                                                print("[IMPORT] Populated Psychosis popup from imported data")

                        # Ensure the Psychosis popup is visible
                        if self.page_ref.psychosis_popup:
                                print("[DEBUG] Showing PsychosisPopup")
                                self.page_ref.psychosis_popup.show()
                                self.page_ref.psychosis_popup.raise_()

                        # Update the panel title
                        self.update_panel_title("Psychosis", "rgba(200,235,215,0.75)")
                        self._set_current_popup(self.page_ref.psychosis_popup)
                        return

                # Handle the Past Psychiatric History section
                if key == "psychhx":
                        self.editor_stack.hide()
                        self._close_all_popups()

                        if not hasattr(self.page_ref, 'psychhx_popup') or not self.page_ref.psychhx_popup:
                                gender, first_name = self._get_patient_info()
                                self.page_ref.psychhx_popup = PastPsychPopup(
                                        first_name=first_name,
                                        gender=gender,
                                        parent=self.editor_panel
                                )
                                self.page_ref.psychhx_popup.sent.connect(
                                        lambda text, state: self._update_card_from_popup("psychhx", text)
                                )
                                self.page_ref.psychhx_popup.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
                                self.editor_panel.layout().addWidget(self.page_ref.psychhx_popup)
                                self.page_ref.psychhx_popup.closed.connect(self._store_psychhx_state)

                                # Populate from imported data if available
                                if hasattr(self, '_imported_sections') and self._imported_sections:
                                        from docx_letter_importer import populate_psych_history_popup
                                        psychhx_content = self._imported_sections.get('psychhx', '')
                                        if psychhx_content:
                                                populate_psych_history_popup(self.page_ref.psychhx_popup, psychhx_content)
                                                print("[IMPORT] Populated Psych History popup from imported data")

                        # Apply extracted data from notes if available (with dates)
                        if self.page_ref.psychhx_popup and hasattr(self, '_extracted_category_items'):
                                extracted_items = self._extracted_category_items.get("Past Psychiatric History") or \
                                            self._extracted_category_items.get("Psychiatric History", [])
                                if extracted_items and hasattr(self.page_ref.psychhx_popup, 'set_extracted_data'):
                                        self.page_ref.psychhx_popup.set_extracted_data(extracted_items)

                        if self.page_ref.psychhx_popup:
                                self.page_ref.psychhx_popup.show()
                                self.page_ref.psychhx_popup.raise_()

                        self.update_panel_title("Past Psychiatric History", "rgba(200,235,215,0.75)")
                        self._set_current_popup(self.page_ref.psychhx_popup)
                        return

                # Handle the Background History section
                if key == "background":
                        self.editor_stack.hide()
                        self._close_all_popups()

                        if not hasattr(self.page_ref, 'background_popup') or not self.page_ref.background_popup:
                                gender, first_name = self._get_patient_info()
                                self.page_ref.background_popup = BackgroundHistoryPopup(
                                        first_name=first_name,
                                        gender=gender,
                                        parent=self.editor_panel
                                )
                                self.page_ref.background_popup.sent.connect(
                                        lambda text, state: self._update_card_from_popup("background", text)
                                )
                                self.page_ref.background_popup.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
                                self.editor_panel.layout().addWidget(self.page_ref.background_popup)

                                # Populate from imported data if available
                                if hasattr(self, '_imported_sections') and self._imported_sections:
                                        from docx_letter_importer import populate_background_popup
                                        background_content = self._imported_sections.get('background', '')
                                        if background_content:
                                                populate_background_popup(self.page_ref.background_popup, background_content)
                                                print("[IMPORT] Populated Background popup from imported data")

                        # Apply extracted data from notes if available (with dates)
                        if self.page_ref.background_popup and hasattr(self, '_extracted_category_items'):
                                extracted_items = self._extracted_category_items.get("Background History") or \
                                            self._extracted_category_items.get("Personal History", [])
                                if extracted_items and hasattr(self.page_ref.background_popup, 'set_extracted_data'):
                                        self.page_ref.background_popup.set_extracted_data(extracted_items)

                        if self.page_ref.background_popup:
                                self.page_ref.background_popup.show()
                                self.page_ref.background_popup.raise_()

                        self.update_panel_title("Background History", "rgba(200,235,215,0.75)")
                        self._set_current_popup(self.page_ref.background_popup)
                        return

                # Handle the Drugs & Alcohol section
                if key == "drugalc":
                        self.editor_stack.hide()
                        self._close_all_popups()

                        if not hasattr(self.page_ref, 'drugalc_popup') or not self.page_ref.drugalc_popup:
                                gender, first_name = self._get_patient_info()
                                self.page_ref.drugalc_popup = DrugsAlcoholPopup(
                                        first_name=first_name,
                                        gender=gender,
                                        parent=self.editor_panel
                                )
                                self.page_ref.drugalc_popup.sent.connect(
                                        lambda text, state: self._update_card_from_popup("drugalc", text)
                                )
                                self.page_ref.drugalc_popup.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
                                self.editor_panel.layout().addWidget(self.page_ref.drugalc_popup)

                                # Apply prefilled state from notes if available
                                if hasattr(self, '_drugs_prefill_state') and self._drugs_prefill_state:
                                        self._apply_drugs_prefill()

                                # Populate from imported data if available
                                if hasattr(self, '_imported_sections') and self._imported_sections:
                                        from docx_letter_importer import populate_drugs_alcohol_popup
                                        drugalc_content = self._imported_sections.get('drugalc', '')
                                        if drugalc_content:
                                                populate_drugs_alcohol_popup(self.page_ref.drugalc_popup, drugalc_content)
                                                print("[IMPORT] Populated Drugs & Alcohol popup from imported data")

                        # Apply extracted data from notes if available (with dates)
                        if self.page_ref.drugalc_popup and hasattr(self, '_extracted_category_items'):
                                extracted_items = self._extracted_category_items.get("Drug and Alcohol History", [])
                                if extracted_items and hasattr(self.page_ref.drugalc_popup, 'set_extracted_data'):
                                        self.page_ref.drugalc_popup.set_extracted_data(extracted_items)

                        if self.page_ref.drugalc_popup:
                                self.page_ref.drugalc_popup.show()
                                self.page_ref.drugalc_popup.raise_()

                        self.update_panel_title("Drugs & Alcohol", "rgba(200,235,215,0.75)")
                        self._set_current_popup(self.page_ref.drugalc_popup)
                        return

                # Handle the Social History section
                if key == "social":
                        self.editor_stack.hide()
                        self._close_all_popups()

                        if not hasattr(self.page_ref, 'social_popup') or not self.page_ref.social_popup:
                                gender, first_name = self._get_patient_info()
                                self.page_ref.social_popup = SocialHistoryPopup(
                                        first_name=first_name,
                                        gender=gender,
                                        parent=self.editor_panel
                                )
                                self.page_ref.social_popup.sent.connect(
                                        lambda text, state: self._update_card_from_popup("social", text)
                                )
                                self.page_ref.social_popup.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
                                self.editor_panel.layout().addWidget(self.page_ref.social_popup)

                                # Populate from imported data if available
                                if hasattr(self, '_imported_sections') and self._imported_sections:
                                        from docx_letter_importer import populate_social_history_popup
                                        social_content = self._imported_sections.get('social', '')
                                        if social_content:
                                                populate_social_history_popup(self.page_ref.social_popup, social_content)
                                                print("[IMPORT] Populated Social History popup from imported data")

                        if self.page_ref.social_popup:
                                self.page_ref.social_popup.show()
                                self.page_ref.social_popup.raise_()

                        self.update_panel_title("Social History", "rgba(200,235,215,0.75)")
                        self._set_current_popup(self.page_ref.social_popup)
                        return

                # Handle the Forensic History section
                if key == "forensic":
                        self.editor_stack.hide()
                        self._close_all_popups()

                        if not hasattr(self.page_ref, 'forensic_popup') or not self.page_ref.forensic_popup:
                                gender, first_name = self._get_patient_info()
                                self.page_ref.forensic_popup = ForensicHistoryPopup(
                                        first_name=first_name,
                                        gender=gender,
                                        parent=self.editor_panel
                                )
                                self.page_ref.forensic_popup.sent.connect(
                                        lambda text, state: self._update_card_from_popup("forensic", text)
                                )
                                self.page_ref.forensic_popup.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
                                self.editor_panel.layout().addWidget(self.page_ref.forensic_popup)

                                # Apply prefilled state from notes if available
                                if hasattr(self, '_forensic_prefill_state') and self._forensic_prefill_state:
                                        self.page_ref.forensic_popup.load_state(self._forensic_prefill_state)
                                        print("[PREFILL] Applied forensic history state to popup")

                                # Populate from imported data if available
                                if hasattr(self, '_imported_sections') and self._imported_sections:
                                        from docx_letter_importer import populate_forensic_popup
                                        forensic_content = self._imported_sections.get('forensic', '')
                                        if forensic_content:
                                                populate_forensic_popup(self.page_ref.forensic_popup, forensic_content)
                                                print("[IMPORT] Populated forensic popup from imported data")

                        # Apply extracted data from notes if available (with dates)
                        if self.page_ref.forensic_popup and hasattr(self, '_extracted_category_items'):
                                extracted_items = self._extracted_category_items.get("Forensic History", [])
                                if extracted_items and hasattr(self.page_ref.forensic_popup, 'set_extracted_data'):
                                        self.page_ref.forensic_popup.set_extracted_data(extracted_items)

                        if self.page_ref.forensic_popup:
                                self.page_ref.forensic_popup.show()
                                self.page_ref.forensic_popup.raise_()

                        self.update_panel_title("Forensic History", "rgba(200,235,215,0.75)")
                        self._set_current_popup(self.page_ref.forensic_popup)
                        return

                # Handle the Physical Health section
                if key == "physical":
                        self.editor_stack.hide()
                        self._close_all_popups()

                        if not hasattr(self.page_ref, 'physical_popup') or not self.page_ref.physical_popup:
                                gender, first_name = self._get_patient_info()
                                self.page_ref.physical_popup = PhysicalHealthPopup(
                                        first_name=first_name,
                                        gender=gender,
                                        parent=self.editor_panel
                                )
                                self.page_ref.physical_popup.sent.connect(
                                        lambda text, state: self._update_card_from_popup("physical", text)
                                )
                                self.page_ref.physical_popup.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
                                self.editor_panel.layout().addWidget(self.page_ref.physical_popup)

                                # Populate from imported data if available
                                if hasattr(self, '_imported_sections') and self._imported_sections:
                                        from docx_letter_importer import populate_physical_health_popup
                                        physical_content = self._imported_sections.get('physical', '')
                                        if physical_content:
                                                populate_physical_health_popup(self.page_ref.physical_popup, physical_content)
                                                print("[IMPORT] Populated physical health popup from imported data")

                        # Apply extracted data from notes if available (with dates)
                        if self.page_ref.physical_popup and hasattr(self, '_extracted_category_items'):
                                extracted_items = self._extracted_category_items.get("Past Medical History", [])
                                if extracted_items and hasattr(self.page_ref.physical_popup, 'set_extracted_data'):
                                        self.page_ref.physical_popup.set_extracted_data(extracted_items)

                        if self.page_ref.physical_popup:
                                self.page_ref.physical_popup.show()
                                self.page_ref.physical_popup.raise_()

                        self.update_panel_title("Physical Health", "rgba(200,235,215,0.75)")
                        self._set_current_popup(self.page_ref.physical_popup)
                        return

                # Handle the Function section
                if key == "function":
                        self.editor_stack.hide()
                        self._close_all_popups()

                        if not hasattr(self.page_ref, 'function_popup') or not self.page_ref.function_popup:
                                gender, first_name = self._get_patient_info()
                                self.page_ref.function_popup = FunctionPopup(
                                        first_name=first_name,
                                        gender=gender,
                                        parent=self.editor_panel
                                )
                                self.page_ref.function_popup.sent.connect(
                                        lambda text, state: self._update_card_from_popup("function", text)
                                )
                                self.page_ref.function_popup.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
                                self.editor_panel.layout().addWidget(self.page_ref.function_popup)

                                # Populate from imported data if available
                                if hasattr(self, '_imported_sections') and self._imported_sections:
                                        from docx_letter_importer import populate_function_popup
                                        function_content = self._imported_sections.get('function', '')
                                        if function_content:
                                                populate_function_popup(self.page_ref.function_popup, function_content)
                                                print("[IMPORT] Populated function popup from imported data")

                        if self.page_ref.function_popup:
                                self.page_ref.function_popup.show()
                                self.page_ref.function_popup.raise_()

                        self.update_panel_title("Function", "rgba(200,235,215,0.75)")
                        self._set_current_popup(self.page_ref.function_popup)
                        return

                # Handle the Mental State Examination section
                if key == "mse":
                        self.editor_stack.hide()
                        self._close_all_popups()

                        if not hasattr(self.page_ref, 'mse_popup') or not self.page_ref.mse_popup:
                                gender, first_name = self._get_patient_info()
                                self.page_ref.mse_popup = MentalStateExaminationPopup(
                                        first_name=first_name,
                                        gender=gender,
                                        parent=self.editor_panel
                                )
                                self.page_ref.mse_popup.sent.connect(
                                        lambda text, state: self._update_card_from_popup("mse", text)
                                )
                                self.page_ref.mse_popup.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
                                self.editor_panel.layout().addWidget(self.page_ref.mse_popup)

                                # Populate from imported data if available
                                if hasattr(self, '_imported_sections') and self._imported_sections:
                                        from docx_letter_importer import populate_mental_state_popup
                                        mse_content = self._imported_sections.get('mse', '')
                                        if mse_content:
                                                populate_mental_state_popup(self.page_ref.mse_popup, mse_content)
                                                print("[IMPORT] Populated mental state popup from imported data")

                        # Apply extracted data from notes if available (with dates)
                        if self.page_ref.mse_popup and hasattr(self, '_extracted_category_items'):
                                extracted_items = self._extracted_category_items.get("Mental State Examination", [])
                                if extracted_items and hasattr(self.page_ref.mse_popup, 'set_extracted_data'):
                                        self.page_ref.mse_popup.set_extracted_data(extracted_items)

                        if self.page_ref.mse_popup:
                                self.page_ref.mse_popup.show()
                                self.page_ref.mse_popup.raise_()

                        self.update_panel_title("Mental State Examination", "rgba(200,235,215,0.75)")
                        self._set_current_popup(self.page_ref.mse_popup)
                        return

                # Handle the Summary/Impression section
                if key == "summary":
                        self.editor_stack.hide()
                        self._close_all_popups()

                        if not hasattr(self.page_ref, 'impression_popup') or not self.page_ref.impression_popup:
                                front_page_data = self._get_front_page_data()
                                pc_text = self.cards.get("pc", {}).editor.toPlainText() if "pc" in self.cards else ""
                                mse_text = self.cards.get("mse", {}).editor.toPlainText() if "mse" in self.cards else ""

                                self.page_ref.impression_popup = ImpressionPopup(
                                        front_page=front_page_data,
                                        presenting_complaint=pc_text,
                                        mse_text=mse_text,
                                        icd10_dict=ICD10_DICT,
                                        parent=self.editor_panel
                                )
                                self.page_ref.impression_popup.sent.connect(
                                        lambda text, state: self._update_card_from_popup("summary", text)
                                )
                                self.page_ref.impression_popup.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
                                self.editor_panel.layout().addWidget(self.page_ref.impression_popup)

                                # Populate from imported data if available
                                if hasattr(self, '_imported_sections') and self._imported_sections:
                                        from docx_letter_importer import populate_impression_popup
                                        summary_content = self._imported_sections.get('summary', '')
                                        if summary_content:
                                                populate_impression_popup(self.page_ref.impression_popup, summary_content)
                                                print("[IMPORT] Populated impression popup from imported data")

                        # Apply extracted data from notes if available (with dates)
                        if self.page_ref.impression_popup and hasattr(self, '_extracted_category_items'):
                                extracted_items = self._extracted_category_items.get("Summary", [])
                                if extracted_items and hasattr(self.page_ref.impression_popup, 'set_extracted_data'):
                                        self.page_ref.impression_popup.set_extracted_data(extracted_items)

                        if self.page_ref.impression_popup:
                                self.page_ref.impression_popup.show()
                                self.page_ref.impression_popup.raise_()

                        self.update_panel_title("Impression", "rgba(200,235,215,0.75)")
                        self._set_current_popup(self.page_ref.impression_popup)
                        return

                # Handle the Plan section
                if key == "plan":
                        self.editor_stack.hide()
                        self._close_all_popups()

                        if not hasattr(self.page_ref, 'plan_popup') or not self.page_ref.plan_popup:
                                self.page_ref.plan_popup = PlanPopup(
                                        parent=self.editor_panel,
                                        current_meds=[]
                                )
                                self.page_ref.plan_popup.sent.connect(
                                        lambda text, state: self._update_card_from_popup("plan", text)
                                )
                                self.page_ref.plan_popup.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
                                self.editor_panel.layout().addWidget(self.page_ref.plan_popup)

                                # Populate from imported data if available
                                if hasattr(self, '_imported_sections') and self._imported_sections:
                                        from docx_letter_importer import populate_plan_popup
                                        plan_content = self._imported_sections.get('plan', '')
                                        if plan_content:
                                                populate_plan_popup(self.page_ref.plan_popup, plan_content)
                                                print("[IMPORT] Populated plan popup from imported data")

                        # Apply extracted data from notes if available (with dates)
                        if self.page_ref.plan_popup and hasattr(self, '_extracted_category_items'):
                                extracted_items = self._extracted_category_items.get("Plan", [])
                                if extracted_items and hasattr(self.page_ref.plan_popup, 'set_extracted_data'):
                                        self.page_ref.plan_popup.set_extracted_data(extracted_items)

                        if self.page_ref.plan_popup:
                                self.page_ref.plan_popup.show()
                                self.page_ref.plan_popup.raise_()

                        self.update_panel_title("Plan", "rgba(200,235,215,0.75)")
                        self._set_current_popup(self.page_ref.plan_popup)
                        return

                # Handle the Front Page section
                if key == "front":
                        self.editor_stack.hide()
                        self._close_all_popups()

                        # Ensure FrontPageSidebarPopup is created only once
                        if not hasattr(self, "front_popup") or not self.front_popup:
                                self.front_popup = FrontPageSidebarPopup(
                                        key="front",
                                        title="Front Page",
                                        parent=self.editor_panel,
                                        db=getattr(self.page_ref, "db", None),
                                        cards=self.cards  # Pass any references to cards if needed
                                )
                                # Connect gender_changed signal to update all popups
                                self.front_popup.gender_changed.connect(self._on_gender_changed)
                                # Connect sent signal to update the card
                                self.front_popup.sent.connect(
                                        lambda text: self._update_card_from_popup("front", text)
                                )
                                # Also store in page_ref for consistency
                                self.page_ref.front_popup = self.front_popup

                                # Add it to the panel layout
                                self.front_popup.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
                                self.editor_panel.layout().addWidget(self.front_popup)

                                # Populate from imported data if available
                                if hasattr(self, '_imported_front_data') and self._imported_front_data:
                                        from docx_letter_importer import populate_front_popup
                                        populate_front_popup(self.front_popup, self._imported_front_data)
                                        print("[IMPORT] Populated front popup with imported data")

                        # Show the Front Page popup
                        self.front_popup.show()
                        self.front_popup.raise_()

                        # Update the panel title and lock button
                        self.update_panel_title("Front Page", "rgba(200,235,215,0.75)")
                        self._set_current_popup(self.front_popup)
                        return


        # ======================================================
        # HELPER
        # ======================================================
        def _sync_editors(self, source, target):
                target.blockSignals(True)
                target.setHtml(source.toHtml())
                target.blockSignals(False)

        def _update_card_from_popup(self, key: str, text: str):
                """Update a card's editor with text from a popup - replaces content."""
                # Debug: Check if ** markers are in the incoming text
                if '**' in text:
                        print(f"[POPUP DEBUG] Card '{key}' receiving text with ** markers")

                if key not in self.cards:
                        print(f"[DEBUG] Card '{key}' not found in cards dict")
                        return

                editor = self.cards[key].editor

                # If no new text from popup, don't change anything
                if not text.strip():
                        print(f"[DEBUG] Card '{key}' - no new popup text, keeping existing")
                        return

                # Store the new popup content for tracking
                self._last_popup_content[key] = text

                # Always replace the card content with the popup content
                print(f"[DEBUG] Updating card '{key}' - replacing content")
                editor.blockSignals(True)
                editor.setPlainText(text)
                editor.blockSignals(False)
                
        def set_notes(self, notes):
                """
                Called by MainWindow after LetterWriterPage creation.
                Stores authoritative notes for extractor + future use.
                """
                new_notes = notes or []

                # Skip if these exact notes were already processed
                notes_sig = (len(new_notes), id(notes))
                if self._notes_processed_id == notes_sig:
                        print(f"[LETTER] Skipping set_notes - notes already processed")
                        return
                self._notes_processed_id = notes_sig

                # Clear all data if notes have changed significantly
                old_count = len(self.all_notes) if hasattr(self, 'all_notes') else 0
                if len(new_notes) != old_count and len(new_notes) > 0:
                        # Only clear if we're loading different notes (not just revisiting the page)
                        if old_count > 0:
                                self.clear_all_data()
                                print(f"[NOTES] Cleared data - loading {len(new_notes)} new notes (was {old_count})")
                        self._auto_populated = False

                self.all_notes = new_notes

        def clear_all_data(self):
                """
                Clear all loaded data - cards, popups, demographics, prefill states.
                Call this when loading new notes to start fresh.
                """
                from PySide6.QtCore import QDate

                print("[CLEAR] Clearing all letter data...")

                # ============================================================
                # CLEAR CARD EDITORS
                # ============================================================
                for key, card in self.cards.items():
                        if hasattr(card, 'editor'):
                                card.editor.blockSignals(True)
                                card.editor.clear()
                                card.editor.blockSignals(False)
                print("[CLEAR] Cleared all card editors")

                # ============================================================
                # CLEAR FRONT PAGE POPUP
                # ============================================================
                if hasattr(self, 'front_popup') and self.front_popup:
                        fp = self.front_popup
                        if hasattr(fp, 'name_field'):
                                fp.name_field.clear()
                        if hasattr(fp, 'nhs_field'):
                                fp.nhs_field.clear()
                        if hasattr(fp, 'dob_field'):
                                fp.dob_field.setDate(QDate(2000, 1, 1))
                        if hasattr(fp, 'gender_field'):
                                fp.gender_field.setCurrentIndex(0)
                        if hasattr(fp, 'saved_data'):
                                fp.saved_data = {}
                        if hasattr(fp, 'update_preview'):
                                fp.update_preview()
                        print("[CLEAR] Cleared front page popup")

                # ============================================================
                # CLEAR ALL OTHER POPUPS
                # ============================================================
                popup_attrs = [
                        'drugalc_popup', 'forensic_popup', 'background_popup',
                        'social_popup', 'physical_popup', 'mse_popup',
                        'psychhx_popup', 'pc_popup', 'hpc_popup',
                        'affect_popup', 'anxiety_popup', 'psychosis_popup',
                        'impression_popup', 'plan_popup'
                ]

                for attr in popup_attrs:
                        if hasattr(self.page_ref, attr):
                                popup = getattr(self.page_ref, attr)
                                if popup:
                                        popup.hide()
                                        popup.deleteLater()
                                setattr(self.page_ref, attr, None)
                print("[CLEAR] Cleared all popups")

                # ============================================================
                # CLEAR PREFILL STATES
                # ============================================================
                self._forensic_prefill_state = None
                self._drugs_prefill_state = None
                self._mse_prefill_findings = None
                self._extracted_category_text = {}
                print("[CLEAR] Cleared prefill states")

                # ============================================================
                # CLEAR SAVED POPUP STATES
                # ============================================================
                self._pc_saved_state = None
                self._hpc_saved_state = None
                self._affect_saved_state = None
                self._anxiety_saved_state = None
                self._psychosis_saved_state = None
                self._background_saved_state = None
                self._forensic_saved_state = None
                self._drugs_saved_state = None
                self._social_saved_state = None
                self._physical_saved_state = None
                self._mse_saved_state = None
                self._impression_saved_state = None
                self._plan_saved_state = None
                print("[CLEAR] Cleared saved popup states")

                # ============================================================
                # RESET FLAGS
                # ============================================================
                self._auto_populated = False
                self.all_notes = []
                print("[CLEAR] Reset flags and notes")

                print("[CLEAR] All data cleared successfully")

        def _extract_patient_demographics(self):
                """
                Extract patient demographics (name, DOB, NHS number, gender) from notes.
                - Looks at TOP of notes for structured demographic data
                - Scans ALL notes for patterns and pronouns
                """
                import re
                from datetime import datetime
                from collections import Counter

                demographics = {
                        "name": None,
                        "dob": None,
                        "nhs_number": None,
                        "gender": None,
                }

                if not self.all_notes:
                        return demographics

                # Get text from first note (usually has demographics at top)
                first_note_text = ""
                if self.all_notes:
                        first_note_text = self.all_notes[0].get("text") or self.all_notes[0].get("content") or ""

                # Get combined text from first 20 notes for demographic search
                top_notes_text = ""
                for note in self.all_notes[:20]:
                        text = note.get("text") or note.get("content") or ""
                        top_notes_text += text + "\n"

                # Get ALL notes text for pronoun counting
                all_notes_text = ""
                for note in self.all_notes:
                        text = note.get("text") or note.get("content") or ""
                        all_notes_text += text + "\n"

                all_notes_lower = all_notes_text.lower()

                # ============================================================
                # EXTRACT NAME - scan line by line in top notes
                # ============================================================
                name_candidates = []

                for line in top_notes_text.split('\n'):
                        line = line.strip()
                        if not line:
                                continue

                        # Pattern 1: "PATIENT NAME: Firstname Lastname" or "PATIENT NAME Firstname Lastname"
                        match = re.match(r"(?:PATIENT\s*NAME|CLIENT\s*NAME|NAME)\s*[:\-]?\s*([A-Za-z][A-Za-z\-\']+\s+[A-Za-z][A-Za-z\-\']+(?:\s+[A-Za-z][A-Za-z\-\']+)?)\s*$", line, re.IGNORECASE)
                        if match:
                                candidate = match.group(1).strip()
                                # Make sure it's not a field label
                                if not re.match(r"(?:DATE|DOB|NHS|GENDER|SEX|AGE|BIRTH|ADDRESS)", candidate, re.IGNORECASE):
                                        name_candidates.append(candidate)
                                        continue

                        # Pattern 2: Line starts with "Name:" or "Patient:"
                        match = re.match(r"(?:Name|Patient)\s*[:\-]\s*([A-Za-z][A-Za-z\-\']+\s+[A-Za-z][A-Za-z\-\']+(?:\s+[A-Za-z\-\']+)?)", line, re.IGNORECASE)
                        if match:
                                candidate = match.group(1).strip()
                                if not re.match(r"(?:DATE|DOB|NHS|GENDER|SEX|AGE|BIRTH)", candidate, re.IGNORECASE):
                                        name_candidates.append(candidate)

                # Use the first valid name found (filter out false positives)
                invalid_name_patterns = [
                        r"(?i)responsible\s*clinician",
                        r"(?i)approved\s*clinician",
                        r"(?i)social\s*worker",
                        r"(?i)report\s*of",
                        r"(?i)^of\s+",  # Names starting with "of"
                        r"(?i)tribunal",
                        r"(?i)mental\s*health",
                        r"(?i)first\s*tier",
                        r"(?i)care\s*coordinator",
                        r"(?i)nurse",
                        r"(?i)doctor",
                ]
                for candidate in name_candidates:
                        is_valid = True
                        for pattern in invalid_name_patterns:
                                if re.search(pattern, candidate):
                                        print(f"[DEMOGRAPHICS] Rejected name '{candidate}' - matches invalid pattern")
                                        is_valid = False
                                        break
                        if is_valid:
                                demographics["name"] = candidate
                                print(f"[DEMOGRAPHICS] Found name: {demographics['name']}")
                                break

                # ============================================================
                # EXTRACT DOB - search all top notes
                # ============================================================
                dob_patterns = [
                        r"(?:DATE\s*OF\s*BIRTH|D\.?O\.?B\.?|DOB)\s*[:\-]?\s*(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4})",
                        r"(?:BORN|BIRTH\s*DATE)\s*[:\-]?\s*(\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4})",
                ]
                for pattern in dob_patterns:
                        match = re.search(pattern, top_notes_text, re.IGNORECASE)
                        if match:
                                dob_str = match.group(1).strip()
                                for fmt in ["%d/%m/%Y", "%d-%m-%Y", "%d.%m.%Y", "%d/%m/%y", "%d-%m-%y"]:
                                        try:
                                                demographics["dob"] = datetime.strptime(dob_str, fmt)
                                                print(f"[DEMOGRAPHICS] Found DOB: {dob_str}")
                                                break
                                        except ValueError:
                                                continue
                                if demographics["dob"]:
                                        break

                # ============================================================
                # EXTRACT NHS NUMBER
                # ============================================================
                nhs_patterns = [
                        r"(?:NHS\s*(?:NO\.?|NUMBER|NUM)?)\s*[:\-]?\s*(\d{3}\s*\d{3}\s*\d{4})",
                        r"(?:NHS\s*(?:NO\.?|NUMBER|NUM)?)\s*[:\-]?\s*(\d{10})",
                ]
                for pattern in nhs_patterns:
                        match = re.search(pattern, top_notes_text, re.IGNORECASE)
                        if match:
                                nhs = match.group(1).replace(" ", "")
                                if len(nhs) == 10:
                                        demographics["nhs_number"] = f"{nhs[:3]} {nhs[3:6]} {nhs[6:]}"
                                else:
                                        demographics["nhs_number"] = nhs
                                print(f"[DEMOGRAPHICS] Found NHS: {demographics['nhs_number']}")
                                break

                # ============================================================
                # EXTRACT GENDER - explicit patterns first, then pronouns
                # ============================================================
                # Try explicit gender fields
                gender_patterns = [
                        r"(?:GENDER|SEX)\s*[:\-]\s*(MALE|FEMALE|M|F)\b",
                        r"\b(MALE|FEMALE)\s+PATIENT\b",
                        r"\bPATIENT\s+IS\s+(?:A\s+)?(MALE|FEMALE)\b",
                ]
                for pattern in gender_patterns:
                        match = re.search(pattern, top_notes_text, re.IGNORECASE)
                        if match:
                                g = match.group(1).upper()
                                if g in ("MALE", "M"):
                                        demographics["gender"] = "Male"
                                elif g in ("FEMALE", "F"):
                                        demographics["gender"] = "Female"
                                print(f"[DEMOGRAPHICS] Found gender from label: {demographics['gender']}")
                                break

                # Fallback: count pronouns across ALL notes
                if not demographics["gender"]:
                        male_pronouns = len(re.findall(r"\bhe\b|\bhim\b|\bhis\b", all_notes_lower))
                        female_pronouns = len(re.findall(r"\bshe\b|\bher\b|\bhers\b", all_notes_lower))

                        print(f"[DEMOGRAPHICS] Pronoun count - Male: {male_pronouns}, Female: {female_pronouns}")

                        # Need a clear majority (at least 2x difference or 10+ more)
                        if male_pronouns > female_pronouns * 2 or male_pronouns > female_pronouns + 10:
                                demographics["gender"] = "Male"
                                print(f"[DEMOGRAPHICS] Inferred gender from pronouns: Male")
                        elif female_pronouns > male_pronouns * 2 or female_pronouns > male_pronouns + 10:
                                demographics["gender"] = "Female"
                                print(f"[DEMOGRAPHICS] Inferred gender from pronouns: Female")

                print(f"[DEMOGRAPHICS] Final result: {demographics}")
                return demographics

        def _fill_front_page(self, demographics):
                """Fill the front page fields with extracted demographics."""
                from PySide6.QtCore import QDate

                # Create front popup if it doesn't exist
                if not hasattr(self, "front_popup") or not self.front_popup:
                        self.front_popup = FrontPageSidebarPopup(
                                key="front",
                                title="Patient Details",
                                parent=self,
                                db=self.db,
                                cards=self.cards,
                        )
                        self.front_popup.gender_changed.connect(self._on_gender_changed)

                fp = self.front_popup

                if not fp:
                        print("[DEMOGRAPHICS] Failed to create front popup")
                        return

                # Fill name
                if demographics.get("name") and hasattr(fp, 'name_field'):
                        if not fp.name_field.text().strip():  # Only if empty
                                fp.name_field.setText(demographics["name"])
                                print(f"[DEMOGRAPHICS] Set name: {demographics['name']}")

                # Fill DOB
                if demographics.get("dob") and hasattr(fp, 'dob_field'):
                        dob = demographics["dob"]
                        qdate = QDate(dob.year, dob.month, dob.day)
                        # Only set if currently at default (01/01/2000)
                        current = fp.dob_field.date()
                        if current == QDate(2000, 1, 1):
                                fp.dob_field.setDate(qdate)
                                print(f"[DEMOGRAPHICS] Set DOB: {dob.strftime('%d/%m/%Y')}")

                # Fill NHS Number
                if demographics.get("nhs_number") and hasattr(fp, 'nhs_field'):
                        if not fp.nhs_field.text().strip():  # Only if empty
                                fp.nhs_field.setText(demographics["nhs_number"])
                                print(f"[DEMOGRAPHICS] Set NHS: {demographics['nhs_number']}")

                # Fill Gender
                if demographics.get("gender") and hasattr(fp, 'gender_field'):
                        idx = fp.gender_field.findText(demographics["gender"])
                        if idx >= 0:
                                fp.gender_field.setCurrentIndex(idx)
                                print(f"[DEMOGRAPHICS] Set gender: {demographics['gender']}")

                # Save demographics to saved_data so load_saved doesn't overwrite them
                from PySide6.QtCore import QDate
                if not hasattr(fp, 'saved_data') or not fp.saved_data:
                        fp.saved_data = {}

                if demographics.get("name"):
                        fp.saved_data["full_name"] = demographics["name"]
                if demographics.get("dob"):
                        dob = demographics["dob"]
                        fp.saved_data["dob"] = QDate(dob.year, dob.month, dob.day)
                if demographics.get("nhs_number"):
                        fp.saved_data["nhs"] = demographics["nhs_number"]
                if demographics.get("gender"):
                        fp.saved_data["gender"] = demographics["gender"]

                # Update the preview in the popup
                if hasattr(fp, 'update_preview'):
                        fp.update_preview()

                # Update the front card with the new content
                if "front" in self.cards and hasattr(fp, 'formatted_front_page_text'):
                        front_text = fp.formatted_front_page_text()
                        editor = self.cards["front"].editor
                        editor.blockSignals(True)
                        editor.setPlainText(front_text)
                        editor.blockSignals(False)
                        print(f"[DEMOGRAPHICS] Updated front card with patient details")

        def auto_populate_from_notes(self):
                """
                Automatically extract history from notes and populate letter cards.
                Only runs once per set of notes to avoid overwriting user edits.
                """
                from timeline_builder import build_timeline
                from history_extractor_sections import extract_patient_history, convert_to_panel_format, CATEGORY_TERMS

                # Check if we have notes to process
                if not self.all_notes:
                        print("[AUTO-POPULATE] No notes available")
                        return

                # Check if already populated (avoid re-running on page revisits)
                if hasattr(self, '_auto_populated') and self._auto_populated:
                        print("[AUTO-POPULATE] Already populated, skipping")
                        return

                print(f"[AUTO-POPULATE] Processing {len(self.all_notes)} notes...")

                # Extract and fill patient demographics
                demographics = self._extract_patient_demographics()
                self._fill_front_page(demographics)

                # Prepare notes for extraction
                prepared = []
                for n in self.all_notes:
                        prepared.append({
                                "date": n.get("date"),
                                "type": (n.get("type") or "").strip().lower(),
                                "originator": n.get("originator", "").strip(),
                                "content": n.get("content", "").strip(),
                                "text": n.get("text") or n.get("content", ""),
                                "source": n.get("source", "").strip().lower() if isinstance(n.get("source"), str) else "rio",
                        })

                # Build timeline and extract history
                try:
                        episodes = build_timeline(prepared)
                        history = extract_patient_history(prepared, episodes=episodes)
                        panel_data = convert_to_panel_format(history)
                except Exception as e:
                        print(f"[AUTO-POPULATE] Extraction error: {e}")
                        return

                # Normalise category keys from numeric IDs to names
                id_to_name = {meta["id"]: name for name, meta in CATEGORY_TERMS.items()}
                normalised_categories = {}

                for key, cat in panel_data.get("categories", {}).items():
                        if isinstance(key, int):
                                name = id_to_name.get(key)
                        else:
                                name = key

                        if name and cat.get("items"):
                                normalised_categories[name] = cat

                # Insert extracted data into letter cards
                items_inserted = 0
                for category_name, payload in normalised_categories.items():
                        card_key = self.EXTRACTOR_CATEGORY_TO_CARD.get(category_name)

                        if not card_key or card_key not in self.cards:
                                continue

                        editor = self.cards[card_key].editor
                        for item in payload.get("items", []):
                                text = (item.get("text") or "").strip()
                                if text:
                                        # Add date prefix if available
                                        date = item.get("date")
                                        if date and hasattr(date, "strftime"):
                                                date_str = date.strftime("%d %b %Y")
                                                editor.insertPlainText(f"[{date_str}]\n{text}\n\n")
                                        else:
                                                editor.insertPlainText(text + "\n\n")
                                        items_inserted += 1

                # Store extracted text by category for popup pre-filling
                self._extracted_category_text = {}
                self._extracted_category_items = {}  # Store full items with dates
                for category_name, payload in normalised_categories.items():
                        texts = []
                        items_list = []
                        for item in payload.get("items", []):
                                text = (item.get("text") or "").strip()
                                if text:
                                        texts.append(text)
                                        items_list.append({
                                                "date": item.get("date"),
                                                "text": text
                                        })
                        if texts:
                                self._extracted_category_text[category_name] = "\n".join(texts)
                        if items_list:
                                self._extracted_category_items[category_name] = items_list

                # Pre-fill popup states based on extracted data
                self._prefill_popups_from_notes()

                self._auto_populated = True
                print(f"[AUTO-POPULATE] Inserted {items_inserted} items into letter cards")

        def _apply_drugs_prefill(self):
                """Apply detected drug/alcohol data to the drugs popup."""
                if not hasattr(self, '_drugs_prefill_state') or not self._drugs_prefill_state:
                        return

                popup = self.page_ref.drugalc_popup
                if not popup:
                        return

                state = self._drugs_prefill_state

                # Apply drug toggles if detected
                drug_types = state.get("drugs", {}).get("types", [])
                if drug_types and hasattr(popup, 'drug_buttons'):
                        for drug_name in drug_types:
                                if drug_name in popup.drug_buttons:
                                        popup.drug_buttons[drug_name].setChecked(True)
                                        # Also update the internal state
                                        if hasattr(popup, 'drug_states') and drug_name in popup.drug_states:
                                                popup.drug_states[drug_name]["active"] = True
                                        print(f"[PREFILL] Enabled drug toggle: {drug_name}")

                # Update preview
                if hasattr(popup, '_update_preview'):
                        popup._update_preview()

                print("[PREFILL] Applied drugs/alcohol state to popup")

        def _prefill_popups_from_notes(self):
                """
                Analyze extracted category text and pre-fill popup checkboxes/states.
                """
                import re

                if not hasattr(self, '_extracted_category_text'):
                        return

                all_text = "\n".join(self._extracted_category_text.values()).lower()

                # ============================================================
                # FORENSIC HISTORY
                # ============================================================
                forensic_text = self._extracted_category_text.get("Forensic History", "").lower()

                if forensic_text or re.search(r"\b(conviction|offence|prison|custody|remand|arrest|police|criminal)\b", all_text):
                        forensic_state = {
                                "convictions": {"status": None, "count_idx": 0},
                                "offences": {"count_idx": 0},
                                "prison": {"status": None, "duration_idx": 0},
                        }

                        # Check for no convictions
                        if re.search(r"no\s*(previous\s*)?(criminal\s*)?(conviction|offence|record)", forensic_text):
                                forensic_state["convictions"]["status"] = "none"
                        elif re.search(r"(has|have|had)\s*(a\s*)?(conviction|offence|criminal)", forensic_text):
                                forensic_state["convictions"]["status"] = "some"

                        # Check for prison
                        if re.search(r"never\s*(been\s*)?(to|in)\s*prison", forensic_text):
                                forensic_state["prison"]["status"] = "never"
                        elif re.search(r"(prison|custody|remand|incarcerat)", forensic_text):
                                forensic_state["prison"]["status"] = "yes"

                        # Store the state for the popup
                        self._forensic_prefill_state = forensic_state
                        print(f"[PREFILL] Forensic history state: {forensic_state}")

                # ============================================================
                # DRUGS & ALCOHOL
                # ============================================================
                drug_text = self._extracted_category_text.get("Drug and Alcohol History", "").lower()

                if drug_text or re.search(r"\b(cannabis|cocaine|heroin|alcohol|smoking|cigarette|drug|substance)\b", all_text):
                        drugs_state = {
                                "alcohol": {"status": None, "units_idx": 0, "age_idx": 0},
                                "smoking": {"status": None, "amount_idx": 0, "age_idx": 0},
                                "drugs": {"status": None, "types": [], "cost_idx": 0, "age_idx": 0},
                        }

                        # Alcohol
                        if re.search(r"(no|denies|nil)\s*(alcohol|drinking|etoh)", drug_text):
                                drugs_state["alcohol"]["status"] = "never"
                        elif re.search(r"(teetotal|abstain|sober)", drug_text):
                                drugs_state["alcohol"]["status"] = "never"
                        elif re.search(r"(alcohol|drink|unit|etoh)", drug_text):
                                drugs_state["alcohol"]["status"] = "current"

                        # Smoking
                        if re.search(r"(no|non|never|nil)\s*smok", drug_text):
                                drugs_state["smoking"]["status"] = "never"
                        elif re.search(r"(ex-smok|quit|gave up|stopped)\s*smok", drug_text):
                                drugs_state["smoking"]["status"] = "ex"
                        elif re.search(r"(smok|cigarette|tobacco|nicotine)", drug_text):
                                drugs_state["smoking"]["status"] = "current"

                        # Drugs - detect types
                        drug_types_found = []
                        drug_keywords = {
                                "Cannabis": r"\b(cannabis|marijuana|weed|skunk|hash)\b",
                                "Cocaine": r"\b(cocaine|coke)\b",
                                "Crack cocaine": r"\b(crack)\b",
                                "Heroin": r"\b(heroin|smack)\b",
                                "Ecstasy (MDMA)": r"\b(ecstasy|mdma|molly)\b",
                                "LSD": r"\b(lsd|acid)\b",
                                "Spice / synthetic cannabinoids": r"\b(spice|synthetic)\b",
                                "Amphetamines": r"\b(amphetamine|speed|meth)\b",
                                "Ketamine": r"\b(ketamine|ket)\b",
                                "Benzodiazepines": r"\b(benzodiazepine|benzo|diazepam|valium|xanax)\b",
                        }

                        for drug_name, pattern in drug_keywords.items():
                                if re.search(pattern, drug_text):
                                        drug_types_found.append(drug_name)

                        if drug_types_found:
                                drugs_state["drugs"]["status"] = "current"
                                drugs_state["drugs"]["types"] = drug_types_found
                        elif re.search(r"(no|nil|denies)\s*(illicit|drug|substance)", drug_text):
                                drugs_state["drugs"]["status"] = "never"

                        self._drugs_prefill_state = drugs_state
                        print(f"[PREFILL] Drugs/alcohol state: {drugs_state}")

                # ============================================================
                # MENTAL STATE - detect specific findings
                # ============================================================
                mse_text = self._extracted_category_text.get("Mental State Examination", "").lower()

                if mse_text:
                        mse_findings = {
                                "appearance": [],
                                "behaviour": [],
                                "speech": [],
                                "mood": [],
                                "affect": [],
                                "thought_form": [],
                                "thought_content": [],
                                "perception": [],
                                "cognition": [],
                                "insight": [],
                        }

                        # Mood detection
                        if re.search(r"\b(low mood|depressed|sad|hopeless)\b", mse_text):
                                mse_findings["mood"].append("low")
                        if re.search(r"\b(anxious|worried|nervous)\b", mse_text):
                                mse_findings["mood"].append("anxious")
                        if re.search(r"\b(elated|elevated|high|manic)\b", mse_text):
                                mse_findings["mood"].append("elevated")
                        if re.search(r"\b(euthymic|normal|stable|good)\b", mse_text):
                                mse_findings["mood"].append("euthymic")

                        # Thought content
                        if re.search(r"\b(suicid|self.harm|overdose)\b", mse_text):
                                mse_findings["thought_content"].append("suicidal_ideation")
                        if re.search(r"\b(delusion|paranoi|persecutory)\b", mse_text):
                                mse_findings["thought_content"].append("delusions")

                        # Perception
                        if re.search(r"\b(hallucination|voices|hearing things)\b", mse_text):
                                mse_findings["perception"].append("hallucinations")

                        # Insight
                        if re.search(r"\b(good insight|insight.{0,10}good)\b", mse_text):
                                mse_findings["insight"].append("good")
                        elif re.search(r"\b(poor insight|insight.{0,10}poor|lacks? insight)\b", mse_text):
                                mse_findings["insight"].append("poor")

                        self._mse_prefill_findings = mse_findings
                        print(f"[PREFILL] MSE findings: {mse_findings}")

        def _store_pc_state(self, state: dict):
                """Store Presenting Complaint popup state for persistence."""
                print(f"[DEBUG] Storing PC state: {list(state.keys())}")
                self._pc_saved_state = state

        def _store_hpc_state(self, state: dict):
                """Store History of Presenting Complaint popup state for persistence."""
                print(f"[DEBUG] Storing HPC state: {list(state.keys())}")
                self._hpc_saved_state = state

        def _store_affect_state(self, state: dict):
                """Store Affect popup state for persistence."""
                print(f"[DEBUG] Storing Affect state: {list(state.keys())}")
                self._affect_saved_state = state

        def _store_anxiety_state(self, text: str, state: dict):
                """Store Anxiety popup state for persistence."""
                print(f"[DEBUG] Storing Anxiety state: {list(state.keys())}")
                self._anxiety_saved_state = state

        def _store_psychosis_state(self, state: dict):
                """Store Psychosis popup state for persistence."""
                print(f"[DEBUG] Storing Psychosis state: {list(state.keys())}")
                self._psychosis_saved_state = state

        def _store_psychhx_state(self, state: dict):
                """Store Past Psychiatric History popup state."""
                self._psychhx_saved_state = state

        def _close_all_popups(self):
                """Close all open popups."""
                popup_attrs = [
                        ('front_popup', self),
                        ('presenting_complaint_popup', self.page_ref),
                        ('history_popup', self.page_ref),
                        ('affect_popup', self.page_ref),
                        ('anxiety_popup', self.page_ref),
                        ('psychosis_popup', self.page_ref),
                        ('psychhx_popup', self.page_ref),
                        ('background_popup', self.page_ref),
                        ('drugalc_popup', self.page_ref),
                        ('social_popup', self.page_ref),
                        ('forensic_popup', self.page_ref),
                        ('physical_popup', self.page_ref),
                        ('function_popup', self.page_ref),
                        ('mse_popup', self.page_ref),
                        ('impression_popup', self.page_ref),
                        ('plan_popup', self.page_ref),
                        ('data_extractor_popup', self),
                ]
                for attr, obj in popup_attrs:
                        if hasattr(obj, attr) and getattr(obj, attr):
                                getattr(obj, attr).hide()

        def open_data_extractor_in_panel(self):
                """Create data extractor for background processing (no longer shown)."""
                # Create the data extractor if needed (for signal routing)
                if not hasattr(self, 'data_extractor_popup') or not self.data_extractor_popup:
                        self.data_extractor_popup = DataExtractorPopup(parent=self.editor_panel)
                        self.data_extractor_popup.data_extracted.connect(self._on_extracted_data)
                        self.data_extractor_popup.hide()

                # Inject notes if available
                notes = getattr(self, "all_notes", []) or []
                if notes:
                        self.data_extractor_popup.set_notes(notes)

        def _on_gender_changed(self, gender: str):
                """Update all existing popups when gender changes on front page."""
                popup_attrs = [
                        ('presenting_complaint_popup', self.page_ref),
                        ('history_popup', self.page_ref),
                        ('affect_popup', self.page_ref),
                        ('anxiety_popup', self.page_ref),
                        ('psychosis_popup', self.page_ref),
                        ('psychhx_popup', self.page_ref),
                        ('background_popup', self.page_ref),
                        ('drugalc_popup', self.page_ref),
                        ('social_popup', self.page_ref),
                        ('forensic_popup', self.page_ref),
                        ('physical_popup', self.page_ref),
                        ('function_popup', self.page_ref),
                        ('mse_popup', self.page_ref),
                        ('impression_popup', self.page_ref),
                        ('plan_popup', self.page_ref),
                ]
                for attr, obj in popup_attrs:
                        popup = getattr(obj, attr, None)
                        if popup and hasattr(popup, 'update_gender'):
                                popup.update_gender(gender)

        def _ensure_front_popup(self):
                """Ensure front popup exists and gender_changed signal is connected."""
                if not hasattr(self.page_ref, 'front_popup') or not self.page_ref.front_popup:
                        self.page_ref.front_popup = FrontPageSidebarPopup(
                                key="front",
                                title="Front Page",
                                parent=self.editor_panel,
                                db=getattr(self.page_ref, "db", None),
                                cards=self.cards
                        )
                        # Connect gender_changed signal to update all popups
                        self.page_ref.front_popup.gender_changed.connect(self._on_gender_changed)

                        # Populate from imported data if available
                        if hasattr(self, '_imported_front_data') and self._imported_front_data:
                                from docx_letter_importer import populate_front_popup
                                populate_front_popup(self.page_ref.front_popup, self._imported_front_data)
                                print("[IMPORT] Populated front popup with imported data via _ensure_front_popup")

                return self.page_ref.front_popup

        def _get_patient_info(self):
                """Get gender and first name from front page popup."""
                fp = self._ensure_front_popup()
                gender = fp.gender_field.currentText().strip().lower()
                first_name = fp.first_name_field.text().strip() if hasattr(fp, 'first_name_field') else "The patient"
                return gender, first_name

        def _get_front_page_data(self):
                """Get front page data for impression popup."""
                fp = self._ensure_front_popup()
                return {
                        "title": fp.title_field.currentText() if hasattr(fp, 'title_field') else "",
                        "surname": fp.surname_field.text() if hasattr(fp, 'surname_field') else "",
                        "age": fp.age_field.text() if hasattr(fp, 'age_field') else "",
                        "gender_noun": fp.gender_field.currentText() if hasattr(fp, 'gender_field') else "",
                }

        # ======================================================
        # RIGHT PANEL EDITOR STACK
        # ======================================================
        def _build_editor_stack(self):
                self.editor_widgets = {}

                # 🔒 Proper Qt-safe clear
                while self.editor_stack.count():
                        w = self.editor_stack.widget(0)
                        self.editor_stack.removeWidget(w)
                        w.deleteLater()

                for title, key in self.sections:
                        # Create container for editor + zoom controls
                        panel_container = QWidget()
                        panel_layout = QVBoxLayout(panel_container)
                        panel_layout.setContentsMargins(0, 0, 0, 0)
                        panel_layout.setSpacing(2)

                        panel_editor = MyPsychAdminRichTextEditor()
                        panel_editor.setPlaceholderText(f"Editing: {title}")

                        # Add zoom controls
                        panel_zoom = create_zoom_row(panel_editor, base_size=13)
                        panel_layout.addLayout(panel_zoom)
                        panel_layout.addWidget(panel_editor)

                        card_editor = self.cards[key].editor

                        # CARD → PANEL
                        card_editor.textChanged.connect(
                                lambda k=key: self._sync_editors(
                                        self.cards[k].editor,
                                        self.editor_widgets[k]
                                )
                        )

                        # PANEL → CARD
                        panel_editor.textChanged.connect(
                                lambda k=key: self._sync_editors(
                                        self.editor_widgets[k],
                                        self.cards[k].editor
                                )
                        )

                        self.editor_stack.addWidget(panel_container)
                        self.editor_widgets[key] = panel_editor

                # 🔑 Activate first section by default
                if self.sections:
                        self._activate_section(self.sections[0][1])


        # ============================================================
        # DATA EXTRACTOR
        # ============================================================

        def open_data_extractor_popup(self):
                popup = DataExtractorPopup(parent=self)
                popup.hide()
                popup.data_extracted.connect(self._on_extracted_data)
                popup.set_notes(self.all_notes)

        def _on_extracted_data(self, panel_data):
                # Skip if this exact data was already processed
                categories = panel_data.get("categories", {})
                cat_keys = tuple(sorted(categories.keys())) if categories else ()
                cat_count = sum(len(v.get("items", [])) if isinstance(v, dict) else 0 for v in categories.values())
                content_sig = (cat_keys, cat_count)
                if self._data_processed_id == content_sig:
                        print(f"[LETTER] Skipping _on_extracted_data - data already processed")
                        return
                self._data_processed_id = content_sig

                self.last_extracted_panel_data = panel_data
                self._handle_extracted_data(panel_data)

        def _handle_extracted_data(self, panel_data):
                if not self.cards:
                        self._pending_extracted_panel_data = panel_data
                        return
                self._insert_extracted_data_into_letter(panel_data)

        def _insert_extracted_data_into_letter(self, panel_data):
                for category, payload in panel_data.get("categories", {}).items():
                        card_key = self.EXTRACTOR_CATEGORY_TO_CARD.get(category)
                        if card_key not in self.cards:
                                continue

                        editor = self.cards[card_key].editor
                        for item in payload.get("items", []):
                                text = (item.get("text") or "").strip()
                                if text:
                                        # Include date prefix if available
                                        date = item.get("date")
                                        if date:
                                                # Handle both datetime objects and strings
                                                if hasattr(date, "strftime"):
                                                        date_str = date.strftime("%d %b %Y")
                                                else:
                                                        date_str = str(date)
                                                editor.insertPlainText(f"[{date_str}]\n{text}\n\n")
                                        else:
                                                editor.insertPlainText(text + "\n\n")


        # ============================================================
        # CARD / EDITOR MGMT
        # ============================================================

        def _register_active_editor(self, editor):
                self._active_editor = editor

        def current_editor(self):
                return self._active_editor

        def create_all_cards(self):
                print(
                        "DEBUG CardWidget __init__ signature:",
                        CardWidget.__init__.__code__.co_varnames
                )

                for title, key in self.sections:
                        card = CardWidget(title, key, parent=self.editor_root)
                        card.clicked.connect(self._activate_section)
                        self.cards[key] = card
                        self.editor_layout.addWidget(card)

                self.editor_layout.addStretch()

        def scroll_to_card(self, key):
                if key not in self.cards:
                        return
                bar = self.cards_holder.verticalScrollBar()
                bar.setValue(self.cards[key].y() - 20)

        def get_reorderable_sections(self):
                """Get the current order of reorderable sections (Affect through Function)."""
                # Fixed sections at start: Front Page, PC, HPC (indices 0-2)
                # Reorderable: indices 3-12 (Affect through Function)
                # Fixed at end: MSE, Summary, Plan (indices 13-15)
                return self.sections[3:13]

        def reorder_sections(self, new_order: list):
                """
                Reorder the sections and rebuild the card layout.

                Args:
                    new_order: List of (title, key) tuples for the reorderable sections
                """
                # Build new sections list with fixed start and end
                fixed_start = self.sections[:3]  # Front Page, PC, HPC
                fixed_end = self.sections[13:]   # MSE, Summary, Plan

                self.sections = fixed_start + new_order + fixed_end

                # Remove all widgets from layout (but don't delete them)
                while self.editor_layout.count():
                        item = self.editor_layout.takeAt(0)
                        if item.widget():
                                item.widget().setParent(None)

                # Re-add widgets in new order
                for title, key in self.sections:
                        if key in self.cards:
                                self.editor_layout.addWidget(self.cards[key])

                self.editor_layout.addStretch()
                print(f"[ORGANISE] Reordered sections: {[s[1] for s in self.sections]}")


        # ============================================================
        # EXPORT
        # ============================================================

        def _clean_editor_text(self, raw: str) -> str:
                if not raw:
                        return ""

                text = re.sub(r"<[^>]+>", "", raw)
                text = unescape(text)
                text = re.sub(r"[ \t]+", " ", text)
                text = re.sub(r"\n{3,}", "\n\n", text)

                paragraphs = []
                for block in text.split("\n\n"):
                        lines = [l.strip() for l in block.split("\n") if l.strip()]
                        if lines:
                                paragraphs.append(" ".join(lines))

                return "\n".join(paragraphs).strip()

        def get_combined_markdown(self):
                blocks = []
                for title, key in self.sections:
                        raw = self.cards[key].editor.toMarkdown()
                        clean = self._clean_editor_text(raw)
                        if clean:
                                blocks.append(f"**{title}:** {clean}")
                return "\n\n".join(blocks)

        def get_combined_html(self):
                """Return combined HTML from all editor cards for DOCX export."""
                import re

                # Debug: Check raw card content for ** markers
                for title, key in self.sections:
                        raw = self.cards[key].editor.toPlainText()
                        if '**' in raw:
                                print(f"[EXPORT DEBUG] Card '{key}' contains ** markers: {raw[:100]}...")

                def extract_body_content(html):
                        """Extract just the body content, stripping DOCTYPE and style blocks."""
                        # Try to get content between <body> tags
                        body_match = re.search(r'<body[^>]*>(.*?)</body>', html, re.DOTALL | re.IGNORECASE)
                        if body_match:
                                content = body_match.group(1).strip()
                        else:
                                content = html

                        # Remove any remaining style tags
                        content = re.sub(r'<style[^>]*>.*?</style>', '', content, flags=re.DOTALL | re.IGNORECASE)

                        # Clean up empty paragraphs (with or without attributes, with any whitespace)
                        content = re.sub(r'<p[^>]*>\s*</p>\s*', '', content, flags=re.IGNORECASE)
                        # Clean up paragraphs that only contain <br> or whitespace
                        content = re.sub(r'<p[^>]*>\s*(<br\s*/?>)?\s*</p>\s*', '', content, flags=re.IGNORECASE)
                        # Clean up multiple consecutive br tags (keep just one)
                        content = re.sub(r'(\s*<br\s*/?>\s*){2,}', '<br>', content, flags=re.IGNORECASE)
                        # Remove br tags at start of content
                        content = re.sub(r'^(\s*<br\s*/?>\s*)+', '', content, flags=re.IGNORECASE)
                        # Remove br tags at end of content
                        content = re.sub(r'(\s*<br\s*/?>\s*)+$', '', content, flags=re.IGNORECASE)

                        return content.strip()

                def has_meaningful_content(html):
                        """Check if HTML has actual text content, not just empty tags."""
                        # Strip all HTML tags
                        text_only = re.sub(r'<[^>]+>', '', html)
                        # Remove whitespace and newlines
                        text_only = text_only.strip()
                        return len(text_only) > 0

                parts = []
                for title, key in self.sections:
                        raw_html = self.cards[key].editor.toHtml()
                        content = extract_body_content(raw_html)
                        if content and has_meaningful_content(content):
                                # Front page doesn't need a heading (it has its own structure)
                                if key == "front":
                                        parts.append(content)
                                else:
                                        # Add bold section heading followed by content
                                        section_html = f"<p><b>{title}:</b></p>{content}"
                                        parts.append(section_html)

                return "<br>".join(parts)
