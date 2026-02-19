from __future__ import annotations

import os, sys
 #import numpy  # required to force inclusion for PyInstaller

from license_manager import load_license
from activation_dialog import ActivationDialog
from PySide6.QtWidgets import QDialog
print(">>> DEBUG: sys.argv =", sys.argv)
print(">>> DEBUG: CWD =", os.getcwd())
print(">>> DEBUG: FILE =", os.path.abspath(__file__))
print(">>> DEBUG: HOME =", os.path.expanduser("~"))
print(">>> DEBUG: RESOURCE DIR =", getattr(sys, "_MEIPASS", "NO_MEIPASS"))

# Qt imports
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QLabel,
    QVBoxLayout, QHBoxLayout, QStackedWidget,
    QSizePolicy, QScrollArea
)
from PySide6.QtWidgets import QPushButton
from PySide6.QtCore import Qt, QSize
from PySide6.QtGui import QIcon, QFont

# App imports
from db import DatabaseManager as Database
from mydetails_panel import MyDetailsPanel
from theme_manager import apply_theme, load_theme, save_theme, Theme
from utils.resource_path import resource_path

from activation_dialog import ActivationDialog
from license_manager import load_license, is_license_valid

# LETTER WRITER MODULE IMPORTS
from letter_writer_page import LetterWriterPage
from letter_generator import LetterGenerator
from letter_toolbar import LetterToolbar
from clipboard_helper import ClipboardHelper
from docx_exporter import DocxExporter
from letter_sections import SECTION_LIST    


# ============================================================
# HOME PAGE BANNER
# ============================================================
class BannerHomePage(QWidget):
    def __init__(self):
        super().__init__()

        self.setObjectName("BannerRoot")
        self.setStyleSheet("QWidget#BannerRoot { background-color: #A6AFB7; }")

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, -10)
        layout.setSpacing(0)

        banner = QWidget()
        banner.setObjectName("BannerBar")
        banner.setFixedHeight(120)
        banner.setMinimumWidth(0)
        banner.setSizePolicy(QSizePolicy.Ignored, QSizePolicy.Fixed)
        banner.setStyleSheet("QWidget#BannerBar { background-color:#707070; border:none; }")

        banner_layout = QHBoxLayout(banner)
        banner_layout.setContentsMargins(0, 0, 0, 0)
        banner_layout.addStretch()

        title = QLabel("MyPsy")
        title.setFont(QFont("Arial", 72, QFont.Bold))
        title.setAlignment(Qt.AlignCenter)
        title.setStyleSheet("color: #C0FFFF;")
        banner_layout.addWidget(title)
        banner_layout.addStretch()

        layout.addWidget(banner)


# ============================================================
# MAIN WINDOW
# ============================================================
class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        print(">>> MAINWINDOW INIT START")

        self.setWindowTitle("MyPsy")
        self.resize(1100, 800)
        self.setMinimumSize(600, 400)

        # Theme
        self.current_theme = load_theme()
        apply_theme(QApplication.instance(), self.current_theme)

        # Database
        self.db = Database()

        # Central root
        central = QWidget()
        central.setObjectName("CentralRoot")
        central.setStyleSheet("QWidget#CentralRoot { background-color: #A6AFB7; }")
        self.setCentralWidget(central)

        main_layout = QVBoxLayout(central)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        # -------------------------------------------------------
        # NAV BAR
        # -------------------------------------------------------
        nav_container = QWidget()
        nav_container.setMinimumHeight(48)
        nav_container.setMaximumHeight(48)
        nav_container.setStyleSheet("""
            QWidget {
                background-color: #B4BEC7;
                border-bottom: 2px solid #8E99A3;
            }
            QLabel {
                color: #000;
                padding: 6px 18px;
                font-size: 22px;
                font-weight: 700;
            }
            QLabel:hover {
                color: #004C78;
                background-color: rgba(255,255,255,0.20);
                border-radius: 6px;
            }
        """)

        nav_scroll = QScrollArea()
        nav_scroll.setWidgetResizable(True)
        nav_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        nav_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        nav_scroll.setFrameShape(QScrollArea.NoFrame)
        nav_scroll.setFixedHeight(48)

        nav_bar = QWidget()
        nav_layout = QHBoxLayout(nav_bar)
        nav_layout.setContentsMargins(20, 0, 20, 0)
        nav_layout.setSpacing(40)

        class NavLabel(QLabel):
            def sizeHint(self):
                s = super().sizeHint()
                return QSize(max(120, s.width()), 32)

        self.nav_labels = []

        def make_nav(text, action):
            lbl = NavLabel(text)
            lbl.setCursor(Qt.PointingHandCursor)
            lbl.setAlignment(Qt.AlignCenter)
            lbl.setSizePolicy(QSizePolicy.Fixed, QSizePolicy.Fixed)
            lbl.mousePressEvent = lambda e: action()
            return lbl

        nav_layout.addStretch(1)

        for text, action in [
            ("My Details", self.toggle_details_panel),
            ("Patient Notes", self.show_notes_workspace),
            ("Clinic Letters", self.open_letter_writer),
            ("Reports", self.close_panels),
            ("Forms", self.close_panels),
            ("Score Patient", self.close_panels),
        ]:
            lbl = make_nav(text, action)
            self.nav_labels.append(lbl)
            nav_layout.addWidget(lbl)

        nav_layout.addStretch(1)
        nav_bar.setLayout(nav_layout)
        nav_scroll.setWidget(nav_bar)
        main_layout.addWidget(nav_scroll)


        # -------------------------------------------------------
        # STACKED PAGES
        # -------------------------------------------------------
        self.stacked = QStackedWidget()
        main_layout.addWidget(self.stacked)

        self.empty_page = QWidget()
        self.stacked.addWidget(self.empty_page)

        self.home_page = BannerHomePage()
        self.stacked.addWidget(self.home_page)

        self.notes_page = None
        self.stacked.setCurrentWidget(self.home_page)

        self.details_panel = MyDetailsPanel(db=self.db, parent=self)
        self.details_panel.hide()
        self.history_panel = None

        print(">>> MAINWINDOW INIT END")

     # ----------------------------------------------------
    # LETTERS SECTION
    # ----------------------------------------------------
    def open_letter_writer(self):
        """
        Load the new Card-Mode Letter Writer inside the stacked widget.
        """
        # Hide panels when entering letter mode
        self.details_panel.hide()
        if self.history_panel:
            self.history_panel.hide()

        # ------------------------------------------------------------
        # CREATE PAGE
        # ------------------------------------------------------------
        self.letter_page = LetterWriterPage(parent=self)
        self.stacked.addWidget(self.letter_page)
        self.stacked.setCurrentWidget(self.letter_page)

        # ------------------------------------------------------------
        # CLEAR ANY PLACEHOLDER LABELS IN toolbar_frame
        # ------------------------------------------------------------
        for child in self.letter_page.toolbar_frame.children():
            if isinstance(child, QLabel):
                child.deleteLater()

        # ------------------------------------------------------------
        # CREATE TOOLBAR INSIDE SCROLLABLE TOOLBAR CONTAINER
        # ------------------------------------------------------------
        tb = LetterToolbar(parent=self.letter_page)
        self.letter_toolbar = tb

        # The page already exposes toolbar_container_layout
        self.letter_page.toolbar_container_layout.addWidget(tb)
        self.letter_page.toolbar_container_layout.addStretch()

        # ============================================================
        # SAFE EDITOR ACCESS
        # ============================================================
        def cur():
            """
            Return the editor inside the card that is currently in use.
            Uses LetterWriterPage.current_editor() which looks for focus
            and falls back to the last card.
            """
            return self.letter_page.current_editor()

        def safe(method):
            editor = cur()
            if editor and hasattr(editor, method):
                # print(f"[DEBUG] Toolbar calling {method} on editor")
                getattr(editor, method)()
            else:
                # print(f"[DEBUG] Toolbar tried {method} but no editor / method")
                pass

        # ============================================================
        # FONT FAMILY + SIZE
        # ============================================================
        tb.set_font_family.connect(
            lambda family: cur().set_font_family(family) if cur() else None
        )
        tb.set_font_size.connect(
            lambda size: cur().set_font_size(size) if cur() else None
        )

        # ============================================================
        # BASIC FORMATTING (B / I / U)
        # ============================================================
        tb.toggle_bold.connect(lambda: safe("toggle_bold"))
        tb.toggle_italic.connect(lambda: safe("toggle_italic"))
        tb.toggle_underline.connect(lambda: safe("toggle_underline"))

        # ============================================================
        # COLOURS
        # ============================================================
        tb.set_text_color.connect(
            lambda c: cur().set_text_color(c) if cur() else None
        )
        tb.set_highlight_color.connect(
            lambda c: cur().set_highlight_color(c) if cur() else None
        )

        # ============================================================
        # ALIGNMENT
        # ============================================================
        tb.set_align_left.connect(lambda: safe("align_left"))
        tb.set_align_center.connect(lambda: safe("align_center"))
        tb.set_align_right.connect(lambda: safe("align_right"))
        tb.set_align_justify.connect(lambda: safe("align_justify"))

        # ============================================================
        # LISTS & INDENTATION
        # ============================================================
        tb.bullet_list.connect(lambda: safe("bullet_list"))
        tb.numbered_list.connect(lambda: safe("numbered_list"))
        tb.indent.connect(lambda: safe("indent"))
        tb.outdent.connect(lambda: safe("outdent"))

        # ============================================================
        # UNDO / REDO
        # ============================================================
        tb.undo.connect(lambda: safe("editor_undo"))
        tb.redo.connect(lambda: safe("editor_redo"))

        # ============================================================
        # INSERTIONS
        # ============================================================
        tb.insert_date.connect(lambda: safe("insert_date"))
        tb.insert_section_break.connect(lambda: safe("insert_section_break"))

        # ============================================================
        # SIDEBAR → SCROLL TO CARD
        # ============================================================
        self.letter_page.sidebar.section_selected.connect(
            self.letter_page.scroll_to_card
        )

        # ============================================================
        # EXPORT & COPY  (Fixed for HTML Exporter)
        # ============================================================
        tb.export_docx.connect(
            lambda: DocxExporter.export_html(
                self.letter_page.get_combined_html(),
                "MyPsy_Letter.docx"
            )
        )

        # If you do not want load/upload functionality yet,
        # comment this out or define load_letter_from_file().
        # For now we safely disable it:
        # tb.load_letter.connect(self.load_letter_from_file)

    # ----------------------------------------------------
    # LOAD LETTER FROM FILE  (Fix for toolbar upload)
    # ----------------------------------------------------
    def load_letter_from_file(self):
        """Load .txt / .md / .html into the active card’s editor."""
        from PySide6.QtWidgets import QFileDialog

        path, _ = QFileDialog.getOpenFileName(
            self,
            "Load Letter File",
            "",
            "Text / Markdown / HTML (*.txt *.md *.html *.htm)"
        )

        if not path:
            return

        try:
            with open(path, "r", encoding="utf-8") as f:
                text = f.read()

            editor = self.letter_page.current_editor()
            if editor:
                editor.set_markdown(text)
                print(f"[Letter] Loaded file → {path}")
            else:
                print("[Letter] ERROR: No active editor to load into")

        except Exception as e:
            print(f"[Letter] ERROR loading file: {e}")

    # -------------------------------
    # Lazy load patient notes
    # -------------------------------
    def ensure_notes_page(self):
        if self.notes_page is not None:
            return

        print(">>> SAFE BUILD: Constructing PatientNotesPage…")
        from patient_notes_page import PatientNotesPage

        self.notes_page = PatientNotesPage(db=self.db, parent=self)
        self.stacked.addWidget(self.notes_page)
        print(">>> SAFE BUILD: PatientNotesPage added")

    # -------------------------------
    # Navigation
    # -------------------------------
    def show_notes_workspace(self):
        self.details_panel.hide()
        if self.history_panel:
            self.history_panel.hide()

        self.ensure_notes_page()

        if self.stacked.currentWidget() is self.notes_page:
            self.stacked.setCurrentWidget(self.home_page)
        else:
            self.stacked.setCurrentWidget(self.notes_page)

    def toggle_details_panel(self):
        if self.history_panel:
            self.history_panel.hide()

        if self.stacked.currentWidget() is self.home_page:
            if self.details_panel.isVisible():
                self.details_panel.hide()
            else:
                self.details_panel.setGeometry(20, 90, 350, self.height() - 110)
                self.details_panel.show()
                self.details_panel.raise_()
            return

        self.stacked.setCurrentWidget(self.home_page)
        self.details_panel.setGeometry(20, 90, 350, self.height() - 110)
        self.details_panel.show()
        self.details_panel.raise_()

    def close_panels(self):
        self.details_panel.hide()
        if self.history_panel:
            self.history_panel.hide()

    # -------------------------------
    # Responsive nav font
    # -------------------------------
    def resizeEvent(self, event):
        super().resizeEvent(event)
        self.update_nav_font_size()

    def update_nav_font_size(self):
        w = self.width()

        if w > 1500:
            pad = "padding: 10px 24px;"
            size = 26
        elif w > 1300:
            pad = "padding: 8px 20px;"
            size = 24
        elif w > 1100:
            pad = "padding: 6px 16px;"
            size = 22
        elif w > 900:
            pad = "padding: 4px 14px;"
            size = 18
        else:
            pad = "padding: 2px 10px;"
            size = 14

        for lbl in self.nav_labels:
            f = lbl.font()
            f.setPointSize(size)
            lbl.setFont(f)
            lbl.setStyleSheet("color:#000;font-weight:700;" + pad)

    # -------------------------------
    # Theme toggle
    # -------------------------------
    def toggle_theme(self):
        self.current_theme = Theme.DARK if self.current_theme == Theme.LIGHT else Theme.LIGHT
        save_theme(self.current_theme)
        apply_theme(QApplication.instance(), self.current_theme)


# ============================================================
# ENTRY POINT
# ============================================================

def main():
    app = QApplication(sys.argv)
    app.setWindowIcon(QIcon(resource_path("resources", "icons", "MyPsy.icns")))

    ok, payload_or_msg = is_license_valid()
    if not ok:
        dialog = ActivationDialog()
        result = dialog.exec()
        if result != QDialog.Accepted:
            print("Activation failed — exiting.", payload_or_msg)
            sys.exit(0)

    win = MainWindow()
    win.show()

    sys.exit(app.exec())

if __name__ == "__main__":
    main()
