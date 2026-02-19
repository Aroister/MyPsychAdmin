# ================================================================
#  LETTER WRITER PAGE — FINAL PATCHED VERSION (PC + GENDER + AFFECT SUPPORT)
# ================================================================

from __future__ import annotations

from PySide6.QtCore import Qt, Signal, QPoint
from PySide6.QtWidgets import (
    QWidget, QHBoxLayout, QVBoxLayout, QScrollArea,
    QLabel, QFrame, QGraphicsDropShadowEffect,
    QPushButton
)
from PySide6.QtGui import QColor
from affect_popup import pronouns_from_gender
from letter_sidebar_popup import SidebarPopup
from presenting_complaint_popup import PresentingComplaintPopup
from letter_sections import SECTION_TITLES
from mypsy_richtext_editor import MyPsyRichTextEditor
from history_presenting_complaint_popup import HistoryPresentingComplaintPopup
from affect_popup import AffectPopup   # <<<<< NEW IMPORT
from anxiety_popup import AnxietyPopup
from psychosis_popup import PsychosisPopup
from psych_history_draft_popup import PsychHistoryDraftPopup


# ================================================================
#  CARD WIDGET
# ================================================================

class CardWidget(QFrame):
    def __init__(self, title: str, parent=None):
        super().__init__(parent)
        self.title = title

        self.setObjectName("letterCard")
        self.setStyleSheet("""
            QFrame#letterCard {
                background: rgba(255,255,255,0.65);
                border-radius: 18px;
                border: 1px solid rgba(0,0,0,0.08);
                padding: 22px;
            }
            QLabel#cardTitle {
                font-size: 19px;
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
        shadow.setXOffset(0)
        shadow.setYOffset(3)
        shadow.setColor(QColor(0, 0, 0, 40))
        self.setGraphicsEffect(shadow)

        self._hover_shadow = shadow
        self._base_geom = None
        self._anim = None

        layout = QVBoxLayout(self)
        layout.setContentsMargins(22, 22, 22, 22)
        layout.setSpacing(12)

        # Title
        self.title_label = QLabel(title)
        self.title_label.setObjectName("cardTitle")
        layout.addWidget(self.title_label)

        # Divider
        divider = QFrame()
        divider.setObjectName("divider")
        layout.addWidget(divider)

        # Add the "Draft from pasted text" button for Psychiatric History card
        if title == "Psychiatric History":
            self.draft_btn = QPushButton("Draft from pasted text")
            self.draft_btn.setStyleSheet("""
                QPushButton {
                    font-size: 12px;
                    padding: 4px 10px;
                    background: rgba(0,0,0,0.06);
                    border-radius: 10px;
                }
                QPushButton:hover {
                    background: rgba(0,0,0,0.12);
                }
            """)
            layout.addWidget(self.draft_btn)
            self.draft_btn.clicked.connect(self._on_draft_button_clicked)

        # Editor
        self.editor = MyPsyRichTextEditor()
        self.editor.setMinimumHeight(180)
        layout.addWidget(self.editor)

        # Hook focus
        self._orig_focus_in = self.editor.focusInEvent
        self.editor.focusInEvent = self._focus_in_event

    def _on_draft_button_clicked(self):
        # climb to LetterWriterPage
        parent = self.parent()
        while parent and not hasattr(parent, "sidebar"):
            parent = parent.parent()

        popup = PsychHistoryDraftPopup(
            parent=parent.window(),
            anchor=parent.sidebar.section_widgets.get("psychhx")
        )

        def insert_draft(text):
            try:
                self.editor.setMarkdown(text)
            except Exception:
                self.editor.setPlainText(text)

        popup.drafted.connect(insert_draft)
        popup.show()
        popup.raise_()
        popup.activateWindow()

        
    # Track active editor
    def _focus_in_event(self, event):
        parent = self.parent()
        while parent and not hasattr(parent, "_register_active_editor"):
            parent = parent.parent()
        if parent:
            parent._register_active_editor(self.editor)
        if self._orig_focus_in:
            self._orig_focus_in(event)

    # Hover animation
    def enterEvent(self, event):
        if self._base_geom is None:
            self._base_geom = self.geometry()
        self._animate(True)
        super().enterEvent(event)

    def leaveEvent(self, event):
        self._animate(False)
        super().leaveEvent(event)

    def _animate(self, up):
        from PySide6.QtCore import QPropertyAnimation, QEasingCurve, QRect

        if self._anim:
            self._anim.stop()

        start = self.geometry()

        if up:
            f = 1.015
            new_w = int(self._base_geom.width() * f)
            new_h = int(self._base_geom.height() * f)
            dx = (new_w - self._base_geom.width()) // 2
            dy = (new_h - self._base_geom.height()) // 2
            end = QRect(self._base_geom.x() - dx,
                        self._base_geom.y() - dy,
                        new_w, new_h)
            self._hover_shadow.setBlurRadius(35)
            self._hover_shadow.setYOffset(6)
        else:
            end = self._base_geom
            self._hover_shadow.setBlurRadius(22)
            self._hover_shadow.setYOffset(3)

        anim = QPropertyAnimation(self, b"geometry")
        anim.setDuration(150)
        anim.setStartValue(start)
        anim.setEndValue(end)
        anim.setEasingCurve(QEasingCurve.OutCubic)
        anim.start()
        self._anim = anim

    def set_text(self, text: str):
        self.editor.setMarkdown(text or "")

    def get_text(self):
        return self.editor.toMarkdown()


# ================================================================
#  SIDEBAR SECTION
# ================================================================

class SidebarSection(QWidget):
    clicked = Signal(str, QPoint)

    def __init__(self, title, key, parent=None):
        super().__init__(parent)
        self.key = key
        self._active = False

        # Enable hover + keyboard focus
        self.setAttribute(Qt.WA_Hover, True)
        self.setFocusPolicy(Qt.StrongFocus)
        self.setCursor(Qt.PointingHandCursor)

        # Layout
        layout = QHBoxLayout(self)
        layout.setContentsMargins(0, 6, 10, 6)
        layout.setSpacing(10)

        # Left accent bar (hidden by default)
        self.accent = QWidget()
        self.accent.setFixedWidth(4)
        self.accent.setStyleSheet("background: transparent; border-radius: 2px;")
        layout.addWidget(self.accent)

        # Label
        self.lbl = QLabel(title)
        self.lbl.setMinimumWidth(200)
        self.lbl.setStyleSheet(
            "font-size: 15px; font-weight: 600; color: #003c32;"
        )
        layout.addWidget(self.lbl)
        layout.addStretch()

        # Initial state
        self._update_style(hover=False, focus=False)

    # ====================================================
    # Public API — called by sidebar / page
    # ====================================================
    def set_active(self, active: bool):
        self._active = active
        self._update_style(hover=False, focus=self.hasFocus())

    # ====================================================
    # Styling engine
    # ====================================================
    def _update_style(self, hover: bool, focus: bool):
        bg = "transparent"
        outline = "none"
        accent = "transparent"

        if self._active:
            bg = "rgba(0, 140, 126, 0.16)"
            accent = "#008C7E"
        elif hover:
            bg = "rgba(0, 140, 126, 0.10)"

        if focus:
            outline = "1px solid rgba(0, 140, 126, 0.45)"

        self.setStyleSheet(f"""
            QWidget {{
                background: {bg};
                border-radius: 10px;
                outline: {outline};
            }}
        """)

        self.accent.setStyleSheet(f"""
            background: {accent};
            border-radius: 2px;
        """)

    # ====================================================
    # Events
    # ====================================================
    def enterEvent(self, event):
        self._update_style(hover=True, focus=self.hasFocus())
        super().enterEvent(event)

    def leaveEvent(self, event):
        self._update_style(hover=False, focus=self.hasFocus())
        super().leaveEvent(event)

    def focusInEvent(self, event):
        self._update_style(hover=False, focus=True)
        super().focusInEvent(event)

    def focusOutEvent(self, event):
        self._update_style(hover=False, focus=False)
        super().focusOutEvent(event)

    def mousePressEvent(self, event):
        self.setFocus(Qt.MouseFocusReason)
        self.clicked.emit(self.key, event.globalPos())

# ================================================================
#  SIDEBAR
# ================================================================

class LetterSidebar(QScrollArea):
    request_popup = Signal(str, QPoint)
    section_selected = Signal(str)

    def __init__(self, sections, parent=None):
        super().__init__(parent)
        self.setWidgetResizable(True)

        container = QWidget()
        layout = QVBoxLayout(container)
        layout.setContentsMargins(18, 20, 18, 20)

        self.section_widgets = {}

        for title, key in sections:
            sec = SidebarSection(title, key)
            self.section_widgets[key] = sec
            sec.clicked.connect(self.request_popup)
            sec.clicked.connect(lambda _, k=key: self.section_selected.emit(k))
            layout.addWidget(sec)

        layout.addStretch()
        self.setWidget(container)

    def set_active_section(self, key):
        for k, sec in self.section_widgets.items():
            sec.set_active(k == key)
# ================================================================
#  LETTER WRITER PAGE
# ================================================================

class LetterWriterPage(QWidget):

    def __init__(self, parent=None):
        super().__init__(parent)

        self.cards = {}
        self._active_editor = None

        self.active_popup = None
        self.popup_memory = {}     # stores values from popup fields
        self.current_first_name = ""
        self.current_gender = ""
        self.current_pronouns = pronouns_from_gender("")


        # Default until front page filled
        self.current_gender = "Other"

        self.sections = [
                ("Front Page", "front"),
                ("Presenting Complaint", "pc"),
                ("History of Presenting Complaint", "hpc"),
                ("Affect", "affect"),

                # MEGA ANXIETY POPUP
                ("Anxiety & Related Disorders", "anxiety"),

                # Psychosis will come next
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


        # Layout root
        main = QVBoxLayout(self)
        main.setContentsMargins(0, 0, 0, 0)
        main.setSpacing(0)

        # Toolbar placeholder
        self.toolbar_frame = QFrame()
        self.toolbar_frame.setFixedHeight(64)
        main.addWidget(self.toolbar_frame)

        toolbar_scroll = QScrollArea(self.toolbar_frame)
        toolbar_scroll.setWidgetResizable(True)
        toolbar_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOn)
        toolbar_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        toolbar_scroll.setFrameShape(QScrollArea.NoFrame)
        toolbar_scroll.setStyleSheet("background: transparent;")

        self.toolbar_container = QWidget()
        self.toolbar_container_layout = QHBoxLayout(self.toolbar_container)
        self.toolbar_container_layout.setContentsMargins(12, 8, 12, 8)
        self.toolbar_container_layout.setSpacing(16)
        toolbar_scroll.setWidget(self.toolbar_container)

        f = QVBoxLayout(self.toolbar_frame)
        f.setContentsMargins(0, 0, 0, 0)
        f.addWidget(toolbar_scroll)

        # Split main view
        split = QHBoxLayout()
        split.setContentsMargins(0, 0, 0, 0)
        split.setSpacing(0)
        main.addLayout(split)

        self.sidebar = LetterSidebar(self.sections)
        self.sidebar.setFixedWidth(280)
        split.addWidget(self.sidebar)

        self.sidebar.request_popup.connect(self.show_popup_for_section)
        self.sidebar.section_selected.connect(self.scroll_to_card)

        self.editor_holder = QScrollArea()
        self.editor_holder.setWidgetResizable(True)
        split.addWidget(self.editor_holder, 1)

        self.editor_root = QWidget()
        self.editor_layout = QVBoxLayout(self.editor_root)
        self.editor_layout.setContentsMargins(40, 40, 40, 40)
        self.editor_layout.setSpacing(28)
        self.editor_holder.setWidget(self.editor_root)

        self.create_all_cards()

    def _handle_anxiety_sent(self, text: str, state: dict):
        print("📩 LetterWriterPage received Anxiety text")

        # 1) Store full popup state for reopening
        self.popup_memory["anxiety"] = state

        # 2) Write text into the Anxiety card
        if "anxiety" in self.cards:
            try:
                self.cards["anxiety"].editor.setMarkdown(text)
            except Exception:
                self.cards["anxiety"].editor.setPlainText(text)



    # Track active editor
    def _register_active_editor(self, editor):
        self._active_editor = editor

    # REQUIRED BY MAIN.PY — returns the correct active editor
    def current_editor(self):
        return self._active_editor

    # Build all cards
    def create_all_cards(self):
        first = None

        for title, key in self.sections:
            card = CardWidget(title, parent=self.editor_root)
            self.cards[key] = card
            self.editor_layout.addWidget(card)
            if first is None:
                first = key

        if first:
            self.cards[first].editor.setFocus()

        self.editor_layout.addStretch()


    def _insert_anxiety_text(self, text: str):
        print("📩 LetterWriterPage received Anxiety text")

        key = "anxiety"
        if key in self.cards:
            try:
                self.cards[key].editor.setMarkdown(text)
            except Exception:
                self.cards[key].editor.setPlainText(text)
    
    def _handle_psychosis_sent(self, payload: dict):
        print("📩 LetterWriterPage received Psychosis payload")

        # 1) Store popup state
        self.popup_memory["psychosis"] = payload

        # 2) Extract text directly from payload
        text = payload.get("text", "").strip()
        if not text:
            return

        # 3) Write into Psychosis card (NOT MSE)
        target_key = "psychosis"
        if target_key in self.cards:
            editor = self.cards[target_key].editor
            try:
                editor.append_markdown(text)
            except Exception:
                editor.setPlainText(
                    editor.toPlainText()
                    + "\n\n"
                    + text
                )


    # ------------------------------------------------------------
    #  SHOW POPUP — PC / FRONT / DEFAULT
    # ------------------------------------------------------------
    def show_popup_for_section(self, key, global_click_pos):
        first_name = self.current_first_name
        gender = self.current_gender


        if self.active_popup:
            self.active_popup.close()
            self.active_popup = None

        title = SECTION_TITLES.get(key, key)
        self.sidebar.set_active_section(key)
        # ============================================================
        # FRONT PAGE POPUP
        # ============================================================
        if key == "front":
            popup = SidebarPopup(key, title, parent=self)
            fp_saved = self.popup_memory.get("front", {})
            if isinstance(fp_saved, dict) and any(fp_saved.values()):
                try:
                    popup.saved_data = fp_saved
                    popup.load_saved()
                except Exception as e:
                    print(">>> FRONT PAGE load_saved failed:", e)

        # ============================================================
        # PRESENTING COMPLAINT
        # ============================================================
        elif key == "pc":
            fp = self.popup_memory.get("front", {})
            gender = fp.get("gender", "")
            popup = PresentingComplaintPopup(gender, parent=self)

            if "pc" in self.popup_memory:
                popup.saved_data = self.popup_memory["pc"]

        # ============================================================
        # HISTORY OF PRESENTING COMPLAINT (intelligent)
        # ============================================================
        elif key == "hpc":
            popup = HistoryPresentingComplaintPopup(self.current_gender, parent=self)
            hpc_saved = self.popup_memory.get("hpc", {})

            if isinstance(hpc_saved, dict) and any(hpc_saved.values()):
                popup.saved_data = hpc_saved
                try:
                    popup.load_saved()
                except Exception as e:
                    print(">>> HPC load_saved failed:", e)
            else:
                pc_data = self.popup_memory.get("pc", {})
                pc_text = ""

                if isinstance(pc_data, dict):
                    pc_text = pc_data.get("text", "") or pc_data.get("formatted", "")

                if not pc_text and "pc" in self.cards:
                    pc_text = self.cards["pc"].get_text()

                try:
                    popup.import_from_pc(pc_text)
                except Exception as e:
                    print(">>> HPC import_from_pc failed:", e)

        # ============================================================
        # NEW: AFFECT POPUP INTEGRATION
        # ============================================================
        elif key == "affect":
            fp = self.popup_memory.get("front", {})

            # derive first name cleanly
            if isinstance(fp, dict):
                full = fp.get("name", "")
                first_name = full.split()[0] if full else ""
                gender = fp.get("gender", self.current_gender)
            else:
                first_name = ""
                gender = self.current_gender

            popup = AffectPopup(self.current_first_name, self.current_gender, self)
            popup.load_saved_data(self.popup_memory.get(key, {}))

            saved = self.popup_memory.get("affect", {})
            if isinstance(saved, dict) and any(saved.values()):
                popup.saved_data = saved
                try:
                    popup.load_saved()
                except Exception as e:
                    print(">>> AFFECT load_saved failed:", e)
        # ============================================================
        # NEW: ANXIETY POPUP INTEGRATION
        # ============================================================

        elif key == "anxiety":
            popup = AnxietyPopup(first_name, gender, parent=self)
            popup.sent.connect(
                lambda text, state: self._handle_anxiety_sent(text, state)
            )

            saved = self.popup_memory.get("anxiety")
            if saved:
                popup.load_state(saved)

        # ============================================================
        # NEW: PSYCHOSIS POPUP INTEGRATION
        # ============================================================
        elif key == "psychosis":
                print(">>> DEBUG: Psychosis sidebar clicked")

                popup = PsychosisPopup(parent=self)

                popup.saved.connect(self._handle_psychosis_sent)

                saved = self.popup_memory.get("psychosis")
                if isinstance(saved, dict):
                        popup.values = saved.get("symptoms", popup.values)
                        popup.current_mode = saved.get("mode", popup.current_mode)

                self.active_popup = popup

                pos = QPoint(self.sidebar.width() + 40, 120)
                popup.move(pos)
                popup.show()
                popup.raise_()
                popup.activateWindow()
                return
        # ============================================================
        # PSYCHIATRIC HISTORY — CARD-ONLY
        # ============================================================
        elif key == "psychhx":
                # Highlight sidebar (already done above)
                # Scroll to the Psychiatric History card
                self.scroll_to_card("psychhx")
                return


        # ============================================================
        # DEFAULT POPUP
        # ============================================================
        else:
            popup = SidebarPopup(key, title, parent=self)

        self.active_popup = popup

        # Wire Send button ONLY for SidebarPopup
        if isinstance(popup, SidebarPopup):
                popup.send_btn.clicked.connect(
                        lambda _, k=key, p=popup: self._handle_popup_send(k, p)
                )


        # Position popup
        win_h = self.height()
        popup_h = 540
        safe_y = max(40, int((win_h - popup_h) / 2))
        target_x = self.sidebar.width() + 40
        pos = QPoint(int(target_x), int(safe_y))

        popup.move(pos)
        popup.show()
        popup.raise_()
        popup.activateWindow()

    # ------------------------------------------------------------
    #  POPUP → CARD
    # ------------------------------------------------------------
    def _handle_popup_send(self, key, popup):

        # 1) Ensure popup finalises its data
        if hasattr(popup, "save_and_close"):
            popup.save_and_close()

        # 2) Store in memory
        self.popup_memory[key] = getattr(popup, "saved_data", {})

        # 3) Front Page special behaviour
        if key == "front":
            saved = self.popup_memory[key]

            # Update global first name + gender
            self.current_first_name = saved.get("first_name", self.current_first_name)
            self.current_gender = saved.get("gender", self.current_gender)

            # Update pronouns globally
            self.current_pronouns = pronouns_from_gender(self.current_gender)

            # Generate front-page Markdown
            text = popup.formatted_front_page_text()

        # 4) Affect (pc) or any other popup
        elif key == "pc":
            text = popup.formatted_section_text()

        else:
            if hasattr(popup, "formatted_section_text"):
                text = popup.formatted_section_text()
            else:
                text = ""

        # 5) Write to card
        if key in self.cards:
            try:
                self.cards[key].editor.setMarkdown(text or "")
            except Exception:
                self.cards[key].editor.setPlainText(text or "")

        popup.close()
        self.active_popup = None
        self.sidebar.set_active_section(None)



    # ------------------------------------------------------------
    #  SCROLL TO CARD
    # ------------------------------------------------------------
    def scroll_to_card(self, key):
        if key not in self.cards:
            return
        card = self.cards[key]
        bar = self.editor_holder.verticalScrollBar()
        bar.setValue(card.y() - 20)

    # ------------------------------------------------------------
    #  EXPORT
    # ------------------------------------------------------------
    def get_combined_markdown(self):
        return "\n".join(
            f"## {title}\n{self.cards[key].get_text()}\n"
            for title, key in self.sections
        )

    def get_combined_html(self):
        return "<br>".join(
            self.cards[key].editor.toHtml()
            for _, key in self.sections
        )
