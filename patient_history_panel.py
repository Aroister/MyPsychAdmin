# ============================================================
# PATIENT HISTORY PANEL — FLOATING, MACOS BLUR, COLLAPSIBLE UI
# Clinical history viewer for MyPsychAdmin 2.3
# Designed to match Medication + Physical Health panels
# Avie Luthra, 2025
# ============================================================

from __future__ import annotations

from PySide6.QtWidgets import (
        QWidget, QLabel, QPushButton, QVBoxLayout, QHBoxLayout,
        QScrollArea, QSizeGrip, QSizePolicy, QFrame, QLineEdit
)
from PySide6.QtCore import Qt, QPoint
from PySide6.QtGui import QColor

# Shared collapsible components
from patient_history_panel_shared import CollapsibleSection
from patient_history_panel_shared import apply_macos_blur   # safe import

# ============================================================
# ICON MAP FOR 18 HISTORY CATEGORIES
# ============================================================
HISTORY_ICONS = {
        1: "⚖️",
        2: "🧠",
        3: "🏥",
        4: "📘",
        5: "👤",
        6: "⚠️",
        7: "🗣️",
        8: "🏠",
        9: "📚",
        10: "❤️",
        11: "💊",
        12: "🧬",
        13: "💼",
        14: "🚔",
        15: "🔪",
        16: "🛡️",
        17: "📝",
        18: "🔍",
}


# ============================================================
# MAIN PANEL
# ============================================================
class PatientHistoryPanel(QWidget):

        def __init__(self, history_data, parent=None, embedded=False):
                super().__init__(parent)

                self.history = history_data or {}
                self.categories = self.history.get("categories", {})
                self.embedded = embedded

                # Window settings - only for floating mode
                if not embedded:
                        self.setWindowFlags(
                                Qt.FramelessWindowHint |
                                Qt.SubWindow |
                                Qt.WindowStaysOnTopHint
                        )
                        self.setCursor(Qt.CursorShape.OpenHandCursor)
                        self.resize(900, 900)
                        self.setMinimumSize(780, 600)
                else:
                        # Allow shrinking when embedded
                        self.setMinimumSize(1, 1)
                        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

                self._drag_offset = QPoint()
                self._dragging = False

                self._build_ui()
                self.populate()

                # Blur + translucent background
                try:
                        apply_macos_blur(self)
                except:
                        pass

                self.raise_()
                self.activateWindow()
                self.show()


        # --------------------------------------------------------
        # Drag window - drag from anywhere
        # --------------------------------------------------------
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
                        self._dragging = True
                        self._drag_offset = event.globalPosition().toPoint() - self.frameGeometry().topLeft()
                        self.setCursor(Qt.CursorShape.ClosedHandCursor)

        def mouseMoveEvent(self, event):
                if self.embedded:
                        return super().mouseMoveEvent(event)
                if self._dragging:
                        self.move(event.globalPosition().toPoint() - self._drag_offset)

        def mouseReleaseEvent(self, event):
                if self.embedded:
                        return super().mouseReleaseEvent(event)
                self._dragging = False
                self.setCursor(Qt.CursorShape.OpenHandCursor)


        # --------------------------------------------------------
        # UI BUILD
        # --------------------------------------------------------
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
                                        background-color: rgba(32,32,32,0.25);
                                        color: #DCE6FF;
                                        border-radius: 12px;
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

                # =============================
                # BACKGROUND WRAPPER
                # =============================
                self.bg = QWidget()
                if self.embedded:
                        self.bg.setStyleSheet("background-color: white; border-radius: 0;")
                else:
                        self.bg.setStyleSheet("""
                                background-color: rgba(20,20,20,0.18);
                                border-radius: 12px;
                        """)
                bg_layout = QVBoxLayout(self.bg)
                bg_layout.setContentsMargins(0, 0, 0, 0)
                bg_layout.setSpacing(0)
                outer.addWidget(self.bg)

                # =============================
                # TITLE BAR
                # =============================
                self.title_bar = QWidget()
                self.title_bar.setFixedHeight(46)
                if not self.embedded:
                        self.title_bar.setCursor(Qt.CursorShape.OpenHandCursor)
                        self.title_bar.setStyleSheet("""
                                background-color: rgba(30,30,30,0.35);
                                border-top-left-radius:12px;
                                border-top-right-radius:12px;
                        """)
                else:
                        self.title_bar.setStyleSheet("""
                                background-color: rgba(240,242,245,0.95);
                                border-bottom: 1px solid #d0d5da;
                        """)

                tb = QHBoxLayout(self.title_bar)
                tb.setContentsMargins(12, 4, 12, 4)

                title = QLabel("Patient History Overview")
                if self.embedded:
                        title.setStyleSheet("font-size:18px; font-weight:bold; color:#333; background: transparent;")
                else:
                        title.setStyleSheet("font-size:20px; font-weight:bold; color:#F5F5F5;")
                tb.addWidget(title)
                tb.addStretch()

                # Only add close button for floating mode
                if not self.embedded:
                        close_btn = QPushButton("✕")
                        close_btn.setFixedSize(34, 28)
                        close_btn.clicked.connect(self.close)
                        close_btn.setStyleSheet("""
                                QPushButton {
                                        background-color: rgba(255,255,255,0.18);
                                        color: #FFFFFF;
                                        font-size: 18px;
                                        font-weight: bold;
                                        border: 1px solid rgba(255,255,255,0.25);
                                        border-radius: 6px;
                                }
                                QPushButton:hover {
                                        background-color: rgba(255,255,255,0.32);
                                }
                        """)
                        tb.addWidget(close_btn)

                        self.title_bar.mousePressEvent = self._drag_start
                        self.title_bar.mouseMoveEvent = self._drag_move

                bg_layout.addWidget(self.title_bar)

                # =============================
                # SEARCH BAR
                # =============================
                self.search_box = QLineEdit()
                self.search_box.setPlaceholderText("Search history…")
                self.search_box.setMinimumHeight(34)
                self.search_box.textChanged.connect(self._apply_filter)

                if self.embedded:
                        self.search_box.setStyleSheet("""
                                QLineEdit {
                                        background-color: #f5f5f5;
                                        color: #333;
                                        font-size: 14px;
                                        padding: 6px 10px;
                                        border-radius: 8px;
                                        border: 1px solid #ccc;
                                }
                                QLineEdit::placeholder {
                                        color: #999;
                                }
                        """)
                else:
                        self.search_box.setStyleSheet("""
                                QLineEdit {
                                        background-color: rgba(80,85,92,0.65);
                                        color: #FFFFFF;
                                        font-size: 15px;
                                        padding: 6px 10px;
                                        border-radius: 8px;
                                        border: 2px solid #F5D34C;
                                }
                                QLineEdit::placeholder {
                                        color: rgba(255,255,255,0.80);
                                }
                        """)

                bg_layout.addWidget(self.search_box)

                # =============================
                # SCROLL AREA
                # =============================
                self.scroll = QScrollArea()
                self.scroll.setWidgetResizable(True)
                self.scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
                if self.embedded:
                        self.scroll.setStyleSheet("""
                                QScrollArea {
                                        background-color: white;
                                        border: none;
                                }
                                QScrollBar:vertical {
                                        background: rgba(0,0,0,0.05);
                                        width: 10px;
                                        border-radius: 5px;
                                }
                                QScrollBar::handle:vertical {
                                        background: rgba(0,0,0,0.2);
                                        border-radius: 5px;
                                        min-height: 30px;
                                }
                        """)
                        self.scroll.viewport().setStyleSheet("background-color: white;")
                else:
                        self.scroll.setStyleSheet("""
                                QScrollArea {
                                        background-color: rgba(0,0,0,0);
                                }
                                QScrollBar:vertical {
                                        background: rgba(255,255,255,0.10);
                                        width: 12px;
                                        margin: 0px;
                                        border-radius: 6px;
                                }
                                QScrollBar::handle:vertical {
                                        background: rgba(255,255,255,0.35);
                                        border-radius: 6px;
                                        min-height: 40px;
                                }
                        """)
                        self.scroll.viewport().setStyleSheet("""
                                background-color: rgba(32,32,32,0.18);
                                border-radius: 12px;
                        """)

                bg_layout.addWidget(self.scroll)

                # =============================
                # INNER CONTENT PANEL
                # =============================
                self.inner = QWidget()
                if self.embedded:
                        self.inner.setStyleSheet("background-color: white;")
                else:
                        self.inner.setStyleSheet("""
                                background-color: rgba(32,32,32,0.22);
                                border-radius: 12px;
                        """)

                self.inner_layout = QVBoxLayout(self.inner)
                self.inner_layout.setAlignment(Qt.AlignTop)
                self.inner_layout.setSpacing(18)
                self.inner_layout.setContentsMargins(12, 12, 30, 30)

                self.scroll.setWidget(self.inner)

                # Resize grip - only for floating mode
                if not self.embedded:
                        self.resize_grip = QSizeGrip(self)
                        self.resize_grip.setStyleSheet("""
                                background-color: rgba(255,255,255,0.35);
                                border-radius: 6px;
                                width: 16px;
                                height: 16px;
                        """)
                        bg_layout.addWidget(self.resize_grip, alignment=Qt.AlignBottom | Qt.AlignRight)
                else:
                        self.resize_grip = None


        # ============================================================
        # POPULATE PANEL
        # ============================================================
        def populate(self):

                ordered_sections = sorted(self.categories.items(), key=lambda kv: kv[0])
                self.section_widgets = []

                for sec_id, sec_data in ordered_sections:

                        name = sec_data.get("name", f"Section {sec_id}")
                        items = sec_data.get("items", [])

                        icon = HISTORY_ICONS.get(sec_id, "📄")
                        title = f"{icon}  {name}"

                        section = CollapsibleSection(title, start_collapsed=True, embedded=self.embedded)
                        self.inner_layout.addWidget(section)
                        self.section_widgets.append(section)

                        for item in items:
                                dt = item.get("date")
                                txt = item.get("text", "").strip()

                                date_label = dt.strftime("%d %b %Y") if hasattr(dt, "strftime") else str(dt)

                                date_section = CollapsibleSection(date_label, start_collapsed=True, embedded=self.embedded)
                                section.add_widget(date_section)

                                text_block = QLabel(txt)
                                text_block.setWordWrap(True)
                                if self.embedded:
                                        text_block.setStyleSheet("""
                                                padding: 8px 10px;
                                                background-color: #f8f9fa;
                                                border: 1px solid #e0e0e0;
                                                border-radius: 10px;
                                                color: #333;
                                                font-size: 14px;
                                        """)
                                else:
                                        text_block.setStyleSheet("""
                                                padding: 8px 10px;
                                                background-color: rgba(40,40,40,0.72);
                                                border-radius: 10px;
                                                color: #DCE6FF;
                                                font-size: 14px;
                                        """)

                                text_block.mousePressEvent = lambda e, d=dt: self._jump_to(d)
                                date_section.add_widget(text_block)

                self.inner_layout.addStretch(1)


        # ------------------------------------------------------------
        # Jump to date in NotesPanel
        # ------------------------------------------------------------
        def _jump_to(self, dt):

                mw = self.window()
                if mw is None:
                        print("No MainWindow found for jump_to_date")
                        return

                from PySide6.QtWidgets import QWidget as _W
                target_page = None

                for w in mw.findChildren(_W, options=Qt.FindChildrenRecursively):
                        if w.__class__.__name__ == "PatientNotesPage":
                                target_page = w
                                break

                if not target_page:
                        print("PatientNotesPage not found for jump_to_date")
                        return

                try:
                        target_page.notes_panel.jump_to_date(dt)
                except Exception as e:
                        print("HistoryPanel jump_to_date failed:", e)


        # ------------------------------------------------------------
        # SEARCH FILTER
        # ------------------------------------------------------------
        def _apply_filter(self, text):

                text = text.lower().strip()

                for section in self.section_widgets:

                        visible = False

                        if text in section.title.lower():
                                visible = True

                        for child in section.children_widgets:

                                if hasattr(child, "title") and text in child.title.lower():
                                        visible = True

                                for g in getattr(child, "children_widgets", []):
                                        if hasattr(g, "text") and text in g.text().lower():
                                                visible = True

                        section.setVisible(visible or text == "")
