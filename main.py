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
from PySide6.QtCore import Qt, QSize, QSettings
from PySide6.QtGui import QIcon, QFont
from PySide6.QtCore import QDateTime
# App imports
from db import DatabaseManager as Database, PatientDatabase, migrate_old_database, PATIENT_DB_FILENAME
from mydetails_panel import MyDetailsPanel
from theme_manager import apply_theme, load_theme, save_theme, Theme
from utils.resource_path import resource_path

from activation_dialog import ActivationDialog
from license_manager import load_license, is_license_valid

# SHARED DATA STORE - centralized data sharing across all sections
from shared_data_store import get_shared_store, SharedDataStore

# LETTER WRITER MODULE IMPORTS
from letter_writer_page import LetterWriterPage
from letter_generator import LetterGenerator
from letter_toolbar import LetterToolbar
from clipboard_helper import ClipboardHelper
from docx_exporter import DocxExporter
from letter_sections import SECTION_LIST

# FORMS MODULE IMPORTS
from forms_page import FormsPage
from a2_form_page import A2FormPage
from a3_form_page import A3FormPage
from a4_form_page import A4FormPage
from a6_form_page import A6FormPage
from a7_form_page import A7FormPage
from a8_form_page import A8FormPage
from h1_form_page import H1FormPage
from h5_form_page import H5FormPage
from cto1_form_page import CTO1FormPage
from cto3_form_page import CTO3FormPage
from cto4_form_page import CTO4FormPage
from cto5_form_page import CTO5FormPage
from cto7_form_page import CTO7FormPage
from m2_form_page import M2FormPage
from t2_form_page import T2FormPage
from moj_leave_form_page import MOJLeaveFormPage
from moj_asr_form_page import MOJASRFormPage
from hcr20_form_page import HCR20FormPage


# ============================================================
# PATIENT DB SETUP DIALOG — choose location for patient DB
# ============================================================
class PatientDbSetupDialog(QDialog):
    """Shown on first run (or when path is missing) to set the patient DB location."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Patient Database Location")
        self.setFixedSize(480, 200)
        self.chosen_path = None

        layout = QVBoxLayout(self)
        layout.setSpacing(12)

        label = QLabel(
            "Choose where to store the shared patient database.\n"
            "For multi-user access, pick a folder on a shared/encrypted drive."
        )
        label.setWordWrap(True)
        layout.addWidget(label)

        from PySide6.QtWidgets import QLineEdit as _QLE, QFileDialog as _QFD
        path_row = QHBoxLayout()
        self.path_input = _QLE()
        self.path_input.setPlaceholderText("e.g. /Volumes/ClinicDrive/MyPsychAdmin")
        self.path_input.setReadOnly(True)
        path_row.addWidget(self.path_input)

        browse_btn = QPushButton("Browse...")
        browse_btn.clicked.connect(self._browse)
        path_row.addWidget(browse_btn)
        layout.addLayout(path_row)

        self.error_label = QLabel("")
        self.error_label.setStyleSheet("color: red;")
        layout.addWidget(self.error_label)

        btn_layout = QHBoxLayout()
        ok_btn = QPushButton("OK")
        ok_btn.clicked.connect(self._accept)
        skip_btn = QPushButton("Skip (local only)")
        skip_btn.clicked.connect(self._use_local)
        btn_layout.addWidget(skip_btn)
        btn_layout.addWidget(ok_btn)
        layout.addLayout(btn_layout)

    def _browse(self):
        from PySide6.QtWidgets import QFileDialog
        folder = QFileDialog.getExistingDirectory(self, "Select Patient Database Folder")
        if folder:
            self.path_input.setText(folder)

    def _use_local(self):
        """Use the default local app data folder."""
        from utils.resource_path import user_data_dir
        self.chosen_path = os.path.join(user_data_dir(), PATIENT_DB_FILENAME)
        self.accept()

    def _accept(self):
        folder = self.path_input.text().strip()
        if not folder:
            self.error_label.setText("Please select a folder.")
            return
        if not os.path.isdir(folder):
            self.error_label.setText("Folder does not exist.")
            return
        self.chosen_path = os.path.join(folder, PATIENT_DB_FILENAME)
        self.accept()


# ============================================================
# HOME PAGE BANNER
# ============================================================
class BannerHomePage(QWidget):
    def __init__(self):
        super().__init__()

        self.setObjectName("BannerRoot")
        self.setStyleSheet("QWidget#BannerRoot { background-color: #C5CFD8; }")

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, -10)
        layout.setSpacing(0)

        banner = QWidget()
        banner.setObjectName("BannerBar")
        banner.setFixedHeight(120)
        banner.setMinimumWidth(0)
        banner.setSizePolicy(QSizePolicy.Ignored, QSizePolicy.Fixed)
        banner.setStyleSheet("QWidget#BannerBar { background-color: #707070; border:none; }")

        banner_layout = QHBoxLayout(banner)
        banner_layout.setContentsMargins(0, 0, 0, 0)
        banner_layout.addStretch()

        title = QLabel("MyPsychAdmin")
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

        self.setWindowTitle("MyPsychAdmin")
        self.resize(990, 720)  # Reduced by 10%
        self.setMinimumSize(540, 360)  # Reduced by 10%

        # Theme
        self.current_theme = load_theme()
        apply_theme(QApplication.instance(), self.current_theme)

        # Database — local DB (clinician details, no password)
        self.db = Database()
        self.patient_db = None  # set later via set_patient_db()
        print("[DEBUG MainWindow] self.db =", self.db)

        # Shared Data Store - centralized data sharing across all sections
        self.shared_store = get_shared_store()
        self.shared_store.notes_changed.connect(self._on_shared_notes_changed)
        self.shared_store.extracted_data_changed.connect(self._on_shared_extracted_data_changed)
        self.shared_store.patient_info_changed.connect(self._on_shared_patient_info_changed)
        print("[DEBUG MainWindow] SharedDataStore initialized")

        # Central root
        central = QWidget()
        central.setObjectName("CentralRoot")
        central.setStyleSheet("QWidget#CentralRoot { background-color: #C5CFD8; }")
        self.setCentralWidget(central)

        main_layout = QVBoxLayout(central)
        main_layout.setContentsMargins(0, 0, 0, 0)
        main_layout.setSpacing(0)

        # -------------------------------------------------------
        # NAV BAR
        # -------------------------------------------------------
        nav_container = QWidget()
        nav_container.setMinimumHeight(43)  # Reduced by 10%
        nav_container.setMaximumHeight(43)
        nav_container.setStyleSheet("""
            QWidget {
                background-color: #C5CFD8;
                border-bottom: 2px solid #A8B5C0;
            }
            QLabel {
                color: #000;
                padding: 5px 16px;
                font-size: 20px;
                font-weight: 700;
            }
        """)

        nav_scroll = QScrollArea()
        nav_scroll.setWidgetResizable(True)
        nav_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        nav_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        nav_scroll.setFrameShape(QScrollArea.NoFrame)
        nav_scroll.setFixedHeight(43)  # Reduced by 10%

        nav_bar = QWidget()
        nav_layout = QHBoxLayout(nav_bar)
        nav_layout.setContentsMargins(20, 0, 20, 0)
        nav_layout.setSpacing(40)

        class NavLabel(QLabel):
            def sizeHint(self):
                s = super().sizeHint()
                return QSize(max(108, s.width()), 29)  # Reduced by 10%

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
            ("Reports", self.show_reports_page),
            ("Forms", self.show_forms_page),
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
        self.reports_page = None
        self.tribunal_page = None
        self.forms_page = None
        self.a2_form_page = None
        self.a3_form_page = None
        self.a4_form_page = None
        self.a6_form_page = None
        self.a7_form_page = None
        self.a8_form_page = None
        self.h1_form_page = None
        self.h5_form_page = None
        self.cto1_form_page = None
        self.cto3_form_page = None
        self.cto4_form_page = None
        self.cto5_form_page = None
        self.cto7_form_page = None
        self.m2_form_page = None
        self.t2_form_page = None
        self.moj_leave_form_page = None
        self.moj_asr_form_page = None
        self.hcr20_form_page = None
        self.stacked.setCurrentWidget(self.home_page)

        self.details_panel = MyDetailsPanel(db=self.db, parent=self)
        self.details_panel.hide()
        self.history_panel = None

        print(">>> MAINWINDOW INIT END")

        # -------------------------------------------------------
        # DEBUG QT MESSAGE HANDLER (helps find QPoint conversion)
        # -------------------------------------------------------
        from PySide6.QtCore import qInstallMessageHandler

        def debug_handler(mode, context, message):
            print(">>> QT DEBUG:", message)

        qInstallMessageHandler(debug_handler)

    # ----------------------------------------------------
    # PATIENT DATABASE (set after password dialog)
    # ----------------------------------------------------
    def set_patient_db(self, patient_db):
        self.patient_db = patient_db
        print(f"[DEBUG MainWindow] patient_db set: {patient_db}")

    # ----------------------------------------------------
    # LETTERS SECTION
    # ----------------------------------------------------

    def open_letter_writer(self):
        """
        Load the Card-Mode Letter Writer.
        Reuse existing instance to preserve injected notes.
        """

        # Hide panels when entering letter mode
        self.details_panel.hide()
        if self.history_panel:
            self.history_panel.hide()

        # ------------------------------------------------------------
        # ♻️ REUSE OR CREATE LETTER PAGE (CRITICAL FIX)
        # ------------------------------------------------------------
        if hasattr(self, "letter_page") and self.letter_page:
            print("[LETTER] Reusing existing LetterWriterPage")
        else:
            print("[LETTER] Creating new LetterWriterPage")
            self.letter_page = LetterWriterPage(parent=self)
            self.stacked.addWidget(self.letter_page)
            # Only inject data on first creation — page handles updates via SharedDataStore signals
            notes = self.shared_store.notes if self.shared_store.has_notes() else []
            self.letter_page.set_notes(notes)
            print(f"[LETTER] Injected {len(notes)} notes from SharedDataStore")
            if notes:
                self.letter_page.auto_populate_from_notes()

        # ------------------------------------------------------------
        # SHOW PAGE (always switch to letter page)
        # ------------------------------------------------------------
        self.stacked.setCurrentWidget(self.letter_page)

        # ------------------------------------------------------------
        # TOOLBAR — ADD ONLY ONCE (SAFE)
        # ------------------------------------------------------------
        tb = getattr(self, "letter_toolbar", None)

        if tb is None:
                tb = LetterToolbar(parent=self.letter_page)
                self.letter_toolbar = tb

                if hasattr(self.letter_page, "toolbar_container_layout"):
                        self.letter_page.toolbar_container_layout.addWidget(tb, 1)  # stretch factor 1

        # ============================================================
        # EXPORT FUNCTION (MUST COME BEFORE SIGNAL WIRING)
        # ============================================================
        def export_letter():
                from PySide6.QtWidgets import QFileDialog, QMessageBox

                # Get patient name from front popup
                name = "Patient"
                front_popup = getattr(self.letter_page, 'front_popup', None)
                if front_popup:
                        first = getattr(front_popup, 'first_name_field', None)
                        last = getattr(front_popup, 'surname_field', None)
                        if first and last:
                                name = f"{first.text().strip()} {last.text().strip()}".strip() or "Patient"
                        elif hasattr(front_popup, 'name_field'):
                                name = front_popup.name_field.text().strip() or "Patient"

                # Get clinician details from database
                details = self.db.get_clinician_details()
                # details tuple: (id, full_name, role_title, discipline, registration_body, registration_number, ...)

                clinician = ""
                if front_popup and hasattr(front_popup, 'clinician_field'):
                        clinician = front_popup.clinician_field.text().strip()
                if not clinician and details:
                        clinician = details[1] if details[1] else "Clinician"

                # Get registration info for signature
                registration_body = ""
                registration_number = ""
                if details:
                        registration_body = details[4] if len(details) > 4 and details[4] else ""
                        registration_number = details[5] if len(details) > 5 and details[5] else ""

                dt = QDateTime.currentDateTime()
                date_str = dt.toString("dd MMM yyyy HH-mm")

                default_filename = (
                        f"Clinic Letter for {name} "
                        f"on {date_str} "
                        f"by {clinician}.docx"
                )

                # Ask user where to save
                path, _ = QFileDialog.getSaveFileName(
                        self,
                        "Save Clinic Letter",
                        default_filename,
                        "Word Documents (*.docx)"
                )

                if not path:
                        return

                # Build signature HTML
                signature_parts = [f"<p><b>{clinician}</b></p>"]
                if registration_body and registration_number:
                        signature_parts.append(f"<p>{registration_body}: {registration_number}</p>")
                elif registration_number:
                        signature_parts.append(f"<p>Registration: {registration_number}</p>")
                signature_html = "".join(signature_parts)

                # Combine letter content with signature
                letter_html = self.letter_page.get_combined_html()
                full_html = f"{letter_html}<br>{signature_html}"

                try:
                        DocxExporter.export_html(full_html, path)
                        QMessageBox.information(self, "Export Complete", f"Letter saved to:\n{path}")
                except Exception as e:
                        QMessageBox.critical(self, "Export Error", f"Failed to export:\n{str(e)}")

        # ------------------------------------------------------------
        # CLEAR ANY PLACEHOLDER LABELS IN toolbar_frame
        # ------------------------------------------------------------
        for child in self.letter_page.toolbar_frame.children():
            if isinstance(child, QLabel):
                child.deleteLater()




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
        # TOOLBAR SIGNALS (SAFE)
        # ============================================================
        if tb:

                # ----------------------------
                # FONT FAMILY + SIZE
                # ----------------------------
                tb.set_font_family.connect(
                        lambda family: cur().set_font_family(family) if cur() else None
                )
                tb.set_font_size.connect(
                        lambda size: cur().set_font_size(size) if cur() else None
                )

                # ----------------------------
                # BASIC FORMATTING (B / I / U)
                # ----------------------------
                tb.toggle_bold.connect(lambda: safe("toggle_bold"))
                tb.toggle_italic.connect(lambda: safe("toggle_italic"))
                tb.toggle_underline.connect(lambda: safe("toggle_underline"))

                # ----------------------------
                # COLOURS
                # ----------------------------
                tb.set_text_color.connect(
                        lambda c: cur().set_text_color(c) if cur() else None
                )
                tb.set_highlight_color.connect(
                        lambda c: cur().set_highlight_color(c) if cur() else None
                )

                # ----------------------------
                # ALIGNMENT
                # ----------------------------
                tb.set_align_left.connect(lambda: safe("align_left"))
                tb.set_align_center.connect(lambda: safe("align_center"))
                tb.set_align_right.connect(lambda: safe("align_right"))
                tb.set_align_justify.connect(lambda: safe("align_justify"))

                # ----------------------------
                # LISTS & INDENTATION
                # ----------------------------
                tb.bullet_list.connect(lambda: safe("bullet_list"))
                tb.numbered_list.connect(lambda: safe("numbered_list"))
                tb.indent.connect(lambda: safe("indent"))
                tb.outdent.connect(lambda: safe("outdent"))

                # ----------------------------
                # UNDO / REDO
                # ----------------------------
                tb.undo.connect(lambda: safe("editor_undo"))
                tb.redo.connect(lambda: safe("editor_redo"))

                # ----------------------------
                # INSERTIONS
                # ----------------------------
                tb.insert_date.connect(lambda: safe("insert_date"))
                tb.insert_section_break.connect(lambda: safe("insert_section_break"))

                # ----------------------------
                # EXPORT
                # ----------------------------
                tb.export_docx.connect(export_letter)

                # ----------------------------
                # UPLOADED DOCS MENU
                # ----------------------------
                self.shared_store.uploaded_documents_changed.connect(
                    lambda docs, toolbar=tb: self._refresh_letter_upload_menu(toolbar, docs)
                )
                self._refresh_letter_upload_menu(tb, self.shared_store.get_uploaded_documents())

                # ----------------------------
                # ORGANISE CARDS
                # ----------------------------
                tb.organise_cards.connect(self.open_organise_dialog)

                # ----------------------------
                # SPELL CHECK
                # ----------------------------
                def check_spelling():
                    editor = cur()
                    if editor and hasattr(editor, 'jump_to_next_error'):
                        if not editor.jump_to_next_error():
                            from PySide6.QtWidgets import QMessageBox
                            QMessageBox.information(
                                self,
                                "Spell Check",
                                "No spelling errors found."
                            )
                tb.check_spelling.connect(check_spelling)

    # ----------------------------------------------------
    # IMPORT DOCUMENTS (notes, reports, or letters)
    # ----------------------------------------------------
    def _refresh_letter_upload_menu(self, toolbar, docs=None):
        """Rebuild the Uploaded Docs dropdown on a letter toolbar."""
        menu = toolbar.upload_menu
        menu.clear()
        if docs is None:
            docs = self.shared_store.get_uploaded_documents()
        if not docs:
            action = menu.addAction("No documents uploaded")
            action.setEnabled(False)
        else:
            for doc in docs:
                path = doc["path"]
                action = menu.addAction(doc["filename"])
                action.triggered.connect(lambda checked=False, p=path: self.load_letter_from_file(p))

    def load_letter_from_file(self, path=None):
        """Import a document - auto-detects if it's notes, a report, or a letter."""
        from PySide6.QtWidgets import QMessageBox

        if not path:
            return

        try:
            ext = path.lower().rsplit('.', 1)[-1] if '.' in path else ''

            if ext == 'docx':
                # Detect if this is an app-generated letter or notes/report
                doc_type = self._detect_document_type(path)
                print(f"[Import] Detected document type: {doc_type}")

                if doc_type == "letter":
                    # Use letter importer for app-generated letters
                    from docx_letter_importer import DocxLetterImporter
                    success = DocxLetterImporter.import_letter(path, self.letter_page)

                    if success:
                        print(f"[Import] Successfully imported letter from {path}")
                        QMessageBox.information(
                            self,
                            "Letter Imported",
                            "Previous letter loaded successfully.\n\n"
                            "All sections have been populated from the document."
                        )
                    else:
                        QMessageBox.warning(
                            self,
                            "Import Warning",
                            "Could not parse letter sections from the document.\n"
                            "The file may not be in the expected format."
                        )
                else:
                    # DOCX but not an app letter - use data extractor
                    self._open_data_extractor_with_file(path)

            elif ext in ('pdf', 'xls', 'xlsx'):
                # PDF and Excel files always go to data extractor
                self._open_data_extractor_with_file(path)

            else:
                QMessageBox.warning(
                    self,
                    "Unsupported Format",
                    "Please select a supported file type:\n"
                    "Word (.docx), PDF (.pdf), or Excel (.xls, .xlsx)"
                )

        except Exception as e:
            print(f"[Import] ERROR loading file: {e}")
            QMessageBox.critical(
                self,
                "Import Error",
                f"Failed to import document:\n{str(e)}"
            )

    def _detect_document_type(self, file_path: str) -> str:
        """
        Detect if a DOCX file is an app-generated letter or notes/report.

        App-generated letters are identified by the presence of characteristic
        section headers like 'Front Page', 'Presenting Complaint', etc.

        Returns:
            'letter' if app-generated letter, 'report' otherwise
        """
        try:
            from docx import Document

            doc = Document(file_path)
            text_content = []

            # Collect all paragraph text (first 50 paragraphs for speed)
            for i, para in enumerate(doc.paragraphs):
                if i > 50:
                    break
                text_content.append(para.text.strip().lower())

            full_text = "\n".join(text_content)

            # Unique section headers used only by this app's letters
            # These are the characteristic headers that identify MyPsychAdmin letters
            app_letter_markers = [
                "front page",
                "presenting complaint",
                "history of presenting complaint",
                "affect",
                "anxiety & related disorders",
                "anxiety and related disorders",
                "psychosis",
                "psychotic symptoms",
                "psychiatric history",
                "past psychiatric history",
                "background history",
                "drug and alcohol history",
                "social history",
                "forensic history",
                "physical health",
                "function",
                "mental state examination",
                "summary",
                "plan",
            ]

            # Count how many app-specific markers are found
            matches = sum(1 for marker in app_letter_markers if marker in full_text)

            # If we find "front page" (unique to this app) or 4+ other markers,
            # it's very likely an app-generated letter
            has_front_page = "front page" in full_text

            if has_front_page or matches >= 4:
                print(f"[Import] Detected as letter (matches: {matches}, front_page: {has_front_page})")
                return "letter"
            else:
                print(f"[Import] Detected as report (matches: {matches})")
                return "report"

        except Exception as e:
            print(f"[Import] Detection error: {e}, defaulting to report")
            return "report"

    def _open_data_extractor_with_file(self, file_path: str):
        """
        Open the data extractor popup and load the specified file.
        """
        from data_extractor_popup import DataExtractorPopup

        popup = DataExtractorPopup(parent=self.letter_page)
        popup.hide()
        popup.data_extracted.connect(self.letter_page._on_extracted_data)

        # Load the file into the extractor
        popup.load_file(file_path)

        print(f"[Import] Data extractor processing file: {file_path}")

    # ----------------------------------------------------
    # ORGANISE CARDS DIALOG
    # ----------------------------------------------------
    def open_organise_dialog(self):
        """Open the dialog to reorder letter sections."""
        from organise_cards_dialog import OrganiseCardsDialog

        # Get current order of reorderable sections
        current_order = self.letter_page.get_reorderable_sections()

        dialog = OrganiseCardsDialog(current_order, parent=self)
        dialog.order_changed.connect(self.letter_page.reorder_sections)

        dialog.exec()

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
        # Only inject data on first creation — page handles updates via SharedDataStore signals
        self._inject_shared_notes_to_page(self.notes_page)
        self._inject_shared_extracted_data_to_page(self.notes_page)

    # -------------------------------
    # Navigation
    # -------------------------------
    def show_notes_workspace(self):
        self.details_panel.hide()
        if self.history_panel:
            self.history_panel.hide()

        self.ensure_notes_page()

        self.stacked.setCurrentWidget(self.notes_page)

    def show_reports_page(self):
        """Show the reports selection page."""
        self.details_panel.hide()
        if self.history_panel:
            self.history_panel.hide()

        # Lazy load reports page
        if self.reports_page is None:
            from reports_page import ReportsPage
            self.reports_page = ReportsPage(parent=self)
            self.reports_page.report_selected.connect(self._on_report_type_selected)
            self.stacked.addWidget(self.reports_page)
            print("[REPORTS] Reports page created")

        self.stacked.setCurrentWidget(self.reports_page)

    def _on_report_type_selected(self, report_type: str):
        """Handle when a report type is selected."""
        print(f"[REPORTS] Opening {report_type} report editor")

        if report_type == "tribunal_psychiatric":
            self._open_tribunal_report()
        elif report_type == "tribunal_nursing":
            self._open_nursing_tribunal_report()
        elif report_type == "tribunal_social":
            self._open_social_tribunal_report()
        elif report_type == "general_psychiatric":
            self._open_general_psychiatric_report()
        else:
            # Other report types - show placeholder
            from PySide6.QtWidgets import QMessageBox
            QMessageBox.information(
                self,
                "Report Selected",
                f"You selected: {report_type.upper()} Report\n\n"
                "Report editor coming soon!"
            )

    def _open_tribunal_report(self):
        """Open the Psychiatric Tribunal Report page."""
        if not hasattr(self, 'tribunal_page') or self.tribunal_page is None:
            from tribunal_report_page import TribunalReportPage
            self.tribunal_page = TribunalReportPage(parent=self, db=self.db)
            self.tribunal_page.go_back.connect(self.show_reports_page)
            self.stacked.addWidget(self.tribunal_page)
            print("[REPORTS] Tribunal report page created")
            self._inject_shared_notes_to_page(self.tribunal_page)
            self._inject_shared_extracted_data_to_page(self.tribunal_page)

        self.stacked.setCurrentWidget(self.tribunal_page)

    def _open_nursing_tribunal_report(self):
        """Open the Nursing Tribunal Report page."""
        if not hasattr(self, 'nursing_tribunal_page') or self.nursing_tribunal_page is None:
            from nursing_tribunal_report_page import NursingTribunalReportPage
            self.nursing_tribunal_page = NursingTribunalReportPage(parent=self, db=self.db)
            self.nursing_tribunal_page.go_back.connect(self.show_reports_page)
            self.stacked.addWidget(self.nursing_tribunal_page)
            print("[REPORTS] Nursing tribunal report page created")
            self._inject_shared_notes_to_page(self.nursing_tribunal_page)
            self._inject_shared_extracted_data_to_page(self.nursing_tribunal_page)

        self.stacked.setCurrentWidget(self.nursing_tribunal_page)

    def _open_social_tribunal_report(self):
        """Open the Social Circumstances Tribunal Report page."""
        if not hasattr(self, 'social_tribunal_page') or self.social_tribunal_page is None:
            from social_tribunal_report_page import SocialTribunalReportPage
            self.social_tribunal_page = SocialTribunalReportPage(parent=self, db=self.db)
            self.social_tribunal_page.go_back.connect(self.show_reports_page)
            self.stacked.addWidget(self.social_tribunal_page)
            print("[REPORTS] Social tribunal report page created")
            self._inject_shared_notes_to_page(self.social_tribunal_page)
            self._inject_shared_extracted_data_to_page(self.social_tribunal_page)

        self.stacked.setCurrentWidget(self.social_tribunal_page)

    def _open_general_psychiatric_report(self):
        """Open the General Psychiatric Report page."""
        if not hasattr(self, 'general_psychiatric_page') or self.general_psychiatric_page is None:
            from general_psychiatric_report_page import GeneralPsychReportPage
            self.general_psychiatric_page = GeneralPsychReportPage(parent=self, db=self.db)
            self.general_psychiatric_page.go_back.connect(self.show_reports_page)
            self.stacked.addWidget(self.general_psychiatric_page)
            print("[REPORTS] General psychiatric report page created")
            self._inject_shared_notes_to_page(self.general_psychiatric_page)
            self._inject_shared_extracted_data_to_page(self.general_psychiatric_page)

        self.stacked.setCurrentWidget(self.general_psychiatric_page)

    # ----------------------------------------------------
    # FORMS SECTION
    # ----------------------------------------------------

    def show_forms_page(self):
        """Show the forms selection page."""
        self.details_panel.hide()
        if self.history_panel:
            self.history_panel.hide()

        # Lazy load forms page
        if self.forms_page is None:
            self.forms_page = FormsPage(parent=self)
            self.forms_page.form_selected.connect(self._on_form_type_selected)
            self.stacked.addWidget(self.forms_page)
            print("[FORMS] Forms page created")

        self.stacked.setCurrentWidget(self.forms_page)

    def _on_form_type_selected(self, form_type: str):
        """Handle when a form type is selected."""
        print(f"[FORMS] Opening {form_type} form")

        if form_type == "a2":
            self._open_a2_form()
        elif form_type == "a3":
            self._open_a3_form()
        elif form_type == "a4":
            self._open_a4_form()
        elif form_type == "a6":
            self._open_a6_form()
        elif form_type == "a7":
            self._open_a7_form()
        elif form_type == "a8":
            self._open_a8_form()
        elif form_type == "h1":
            self._open_h1_form()
        elif form_type == "h5":
            self._open_h5_form()
        elif form_type == "cto1":
            self._open_cto1_form()
        elif form_type == "cto3":
            self._open_cto3_form()
        elif form_type == "cto4":
            self._open_cto4_form()
        elif form_type == "cto5":
            self._open_cto5_form()
        elif form_type == "cto7":
            self._open_cto7_form()
        elif form_type == "m2":
            self._open_m2_form()
        elif form_type == "t2":
            self._open_t2_form()
        elif form_type == "moj_leave":
            self._open_moj_leave_form()
        elif form_type == "moj_asr":
            self._open_moj_asr_form()
        elif form_type == "hcr20":
            self._open_hcr20_form()
        else:
            # Other form types - show placeholder
            from PySide6.QtWidgets import QMessageBox
            QMessageBox.information(
                self,
                "Form Selected",
                f"You selected: {form_type.upper()} Form\n\n"
                "Form editor coming soon!"
            )

    def _open_a2_form(self):
        """Open the A2 Form page."""
        if self.a2_form_page is None:
            self.a2_form_page = A2FormPage(db=self.db, parent=self)
            self.a2_form_page.go_back.connect(self.show_forms_page)
            self.stacked.addWidget(self.a2_form_page)
            print("[FORMS] A2 form page created")
            self._inject_shared_notes_to_page(self.a2_form_page)

        self.stacked.setCurrentWidget(self.a2_form_page)

    def _open_a3_form(self):
        """Open the A3 Form page."""
        if self.a3_form_page is None:
            self.a3_form_page = A3FormPage(db=self.db, parent=self)
            self.a3_form_page.go_back.connect(self.show_forms_page)
            self.stacked.addWidget(self.a3_form_page)
            print("[FORMS] A3 form page created")
            self._inject_shared_notes_to_page(self.a3_form_page)

        self.stacked.setCurrentWidget(self.a3_form_page)

    def _open_a6_form(self):
        """Open the A6 Form page."""
        if self.a6_form_page is None:
            self.a6_form_page = A6FormPage(db=self.db, parent=self)
            self.a6_form_page.go_back.connect(self.show_forms_page)
            self.stacked.addWidget(self.a6_form_page)
            print("[FORMS] A6 form page created")
            self._inject_shared_notes_to_page(self.a6_form_page)

        self.stacked.setCurrentWidget(self.a6_form_page)

    def _open_a7_form(self):
        """Open the A7 Form page."""
        if self.a7_form_page is None:
            self.a7_form_page = A7FormPage(db=self.db, parent=self)
            self.a7_form_page.go_back.connect(self.show_forms_page)
            self.stacked.addWidget(self.a7_form_page)
            print("[FORMS] A7 form page created")
            self._inject_shared_notes_to_page(self.a7_form_page)

        self.stacked.setCurrentWidget(self.a7_form_page)

    def _open_a8_form(self):
        """Open the A8 Form page."""
        if self.a8_form_page is None:
            self.a8_form_page = A8FormPage(db=self.db, parent=self)
            self.a8_form_page.go_back.connect(self.show_forms_page)
            self.stacked.addWidget(self.a8_form_page)
            print("[FORMS] A8 form page created")
            self._inject_shared_notes_to_page(self.a8_form_page)

        self.stacked.setCurrentWidget(self.a8_form_page)

    def _open_h1_form(self):
        """Open the H1 Form page."""
        if self.h1_form_page is None:
            self.h1_form_page = H1FormPage(db=self.db, parent=self)
            self.h1_form_page.go_back.connect(self.show_forms_page)
            self.stacked.addWidget(self.h1_form_page)
            print("[FORMS] H1 form page created")
            self._inject_shared_notes_to_page(self.h1_form_page)

        self.stacked.setCurrentWidget(self.h1_form_page)

    def _open_a4_form(self):
        """Open the A4 Form page."""
        if self.a4_form_page is None:
            self.a4_form_page = A4FormPage(db=self.db, parent=self)
            self.a4_form_page.go_back.connect(self.show_forms_page)
            self.stacked.addWidget(self.a4_form_page)
            print("[FORMS] A4 form page created")
            self._inject_shared_notes_to_page(self.a4_form_page)

        self.stacked.setCurrentWidget(self.a4_form_page)

    def _open_h5_form(self):
        """Open the H5 Form page."""
        if self.h5_form_page is None:
            self.h5_form_page = H5FormPage(db=self.db, parent=self)
            self.h5_form_page.go_back.connect(self.show_forms_page)
            self.stacked.addWidget(self.h5_form_page)
            print("[FORMS] H5 form page created")
            self._inject_shared_notes_to_page(self.h5_form_page)

        self.stacked.setCurrentWidget(self.h5_form_page)

    def _open_cto1_form(self):
        """Open the CTO1 Form page."""
        if self.cto1_form_page is None:
            self.cto1_form_page = CTO1FormPage(db=self.db, parent=self)
            self.cto1_form_page.go_back.connect(self.show_forms_page)
            self.stacked.addWidget(self.cto1_form_page)
            print("[FORMS] CTO1 form page created")
            self._inject_shared_notes_to_page(self.cto1_form_page)

        self.stacked.setCurrentWidget(self.cto1_form_page)

    def _open_cto3_form(self):
        """Open the CTO3 Form page."""
        if self.cto3_form_page is None:
            self.cto3_form_page = CTO3FormPage(db=self.db, parent=self)
            self.cto3_form_page.go_back.connect(self.show_forms_page)
            self.stacked.addWidget(self.cto3_form_page)
            print("[FORMS] CTO3 form page created")
            self._inject_shared_notes_to_page(self.cto3_form_page)

        self.stacked.setCurrentWidget(self.cto3_form_page)

    def _open_cto4_form(self):
        """Open the CTO4 Form page."""
        if self.cto4_form_page is None:
            self.cto4_form_page = CTO4FormPage(db=self.db, parent=self)
            self.cto4_form_page.go_back.connect(self.show_forms_page)
            self.stacked.addWidget(self.cto4_form_page)
            print("[FORMS] CTO4 form page created")
            self._inject_shared_notes_to_page(self.cto4_form_page)

        self.stacked.setCurrentWidget(self.cto4_form_page)

    def _open_cto5_form(self):
        """Open the CTO5 Form page."""
        if self.cto5_form_page is None:
            self.cto5_form_page = CTO5FormPage(db=self.db, parent=self)
            self.cto5_form_page.go_back.connect(self.show_forms_page)
            self.stacked.addWidget(self.cto5_form_page)
            print("[FORMS] CTO5 form page created")
            self._inject_shared_notes_to_page(self.cto5_form_page)

        self.stacked.setCurrentWidget(self.cto5_form_page)

    def _open_cto7_form(self):
        """Open the CTO7 Form page."""
        if self.cto7_form_page is None:
            self.cto7_form_page = CTO7FormPage(db=self.db, parent=self)
            self.cto7_form_page.go_back.connect(self.show_forms_page)
            self.stacked.addWidget(self.cto7_form_page)
            print("[FORMS] CTO7 form page created")
            self._inject_shared_notes_to_page(self.cto7_form_page)

        self.stacked.setCurrentWidget(self.cto7_form_page)

    def _open_m2_form(self):
        """Open the M2 Form page."""
        if self.m2_form_page is None:
            self.m2_form_page = M2FormPage(db=self.db, parent=self)
            self.m2_form_page.go_back.connect(self.show_forms_page)
            self.stacked.addWidget(self.m2_form_page)
            print("[FORMS] M2 form page created")
            self._inject_shared_notes_to_page(self.m2_form_page)

        self.stacked.setCurrentWidget(self.m2_form_page)

    def _open_t2_form(self):
        """Open the T2 Form page."""
        if self.t2_form_page is None:
            self.t2_form_page = T2FormPage(db=self.db, parent=self)
            self.t2_form_page.go_back.connect(self.show_forms_page)
            self.stacked.addWidget(self.t2_form_page)
            print("[FORMS] T2 form page created")
            self._inject_shared_notes_to_page(self.t2_form_page)

        self.stacked.setCurrentWidget(self.t2_form_page)

    def _open_moj_leave_form(self):
        """Open the MOJ Leave Form page."""
        if self.moj_leave_form_page is None:
            self.moj_leave_form_page = MOJLeaveFormPage(db=self.db, parent=self)
            self.moj_leave_form_page.go_back.connect(self.show_forms_page)
            self.stacked.addWidget(self.moj_leave_form_page)
            print("[FORMS] MOJ Leave form page created")
            # Only inject data on first creation — form handles updates via SharedDataStore signals
            self._inject_shared_notes_to_page(self.moj_leave_form_page)
            self._inject_shared_extracted_data_to_page(self.moj_leave_form_page)

        self.stacked.setCurrentWidget(self.moj_leave_form_page)

    def _open_moj_asr_form(self):
        """Open the MOJ ASR Form page."""
        if self.moj_asr_form_page is None:
            self.moj_asr_form_page = MOJASRFormPage(db=self.db, parent=self)
            self.moj_asr_form_page.go_back.connect(self.show_forms_page)
            self.stacked.addWidget(self.moj_asr_form_page)
            print("[FORMS] MOJ ASR form page created")
            # Only inject data on first creation — form handles updates via SharedDataStore signals
            self._inject_shared_notes_to_page(self.moj_asr_form_page)
            self._inject_shared_extracted_data_to_page(self.moj_asr_form_page)

        self.stacked.setCurrentWidget(self.moj_asr_form_page)

    def _open_hcr20_form(self):
        """Open the HCR-20 V3 Risk Assessment Form page."""
        if self.hcr20_form_page is None:
            self.hcr20_form_page = HCR20FormPage(parent=self, db=self.db)
            self.hcr20_form_page.go_back.connect(self.show_forms_page)
            self.stacked.addWidget(self.hcr20_form_page)
            print("[FORMS] HCR-20 form page created")

        self.stacked.setCurrentWidget(self.hcr20_form_page)

    def toggle_details_panel(self):
        if self.history_panel:
            self.history_panel.hide()

        if self.stacked.currentWidget() is self.home_page:
            if self.details_panel.isVisible():
                self.details_panel.hide()
            else:
                self.details_panel.setGeometry(
                    int(20), int(90),
                    int(350), int(self.height() - 110)
                )
                self.details_panel.show()
                self.details_panel.raise_()
            return

        self.stacked.setCurrentWidget(self.home_page)
        self.details_panel.setGeometry(
            int(20), int(90),
            int(350), int(self.height() - 110)
        )
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

    # -------------------------------------------------------
    # SHARED DATA STORE - propagate data to all sections
    # -------------------------------------------------------
    def _on_shared_notes_changed(self, notes: list):
        """
        Called when notes are updated in the shared store.
        Propagates data to all forms, reports, and letter writer.
        """
        print(f"[SharedData] Notes changed - propagating to {len(notes)} notes to all sections")

        # Update letter writer if it exists
        if hasattr(self, 'letter_page') and self.letter_page:
            self.letter_page.set_notes(notes)
            if notes and not getattr(self.letter_page, '_auto_populated', False):
                self.letter_page.auto_populate_from_notes()

        # Update all form pages that have set_notes method
        form_pages = [
            'a2_form_page', 'a3_form_page', 'a4_form_page', 'a6_form_page',
            'a7_form_page', 'a8_form_page', 'h1_form_page', 'h5_form_page',
            'cto1_form_page', 'cto3_form_page', 'cto4_form_page',
            'cto5_form_page', 'cto7_form_page', 'm2_form_page', 't2_form_page',
            'moj_leave_form_page', 'moj_asr_form_page'
        ]

        for page_name in form_pages:
            page = getattr(self, page_name, None)
            if page and hasattr(page, 'set_notes'):
                page.set_notes(notes)
                print(f"[SharedData] Updated {page_name} with {len(notes)} notes")

        # Update all report pages that have set_notes method
        report_pages = [
            'tribunal_page', 'nursing_tribunal_page', 'social_tribunal_page',
            'general_psychiatric_page'
        ]

        for page_name in report_pages:
            page = getattr(self, page_name, None)
            if page and hasattr(page, 'set_notes'):
                page.set_notes(notes)
                print(f"[SharedData] Updated {page_name} with {len(notes)} notes")

        # Update patient notes page if it exists
        if hasattr(self, 'notes_page') and self.notes_page:
            if hasattr(self.notes_page, 'set_notes'):
                self.notes_page.set_notes(notes)
                print(f"[SharedData] Updated notes_page with {len(notes)} notes")

    def _inject_shared_notes_to_page(self, page):
        """Helper to inject current shared store notes and patient details into a page."""
        if page and hasattr(page, 'set_notes') and self.shared_store.has_notes():
            page.set_notes(self.shared_store.notes)
            print(f"[SharedData] Injected {len(self.shared_store.notes)} notes into {page.__class__.__name__}")

        # Also inject patient details if available
        patient_info = self.shared_store.patient_info
        if page and patient_info and any(patient_info.values()):
            if hasattr(page, '_fill_patient_details'):
                page._fill_patient_details(patient_info)
                print(f"[SharedData] Injected patient details into {page.__class__.__name__}")

    def _on_shared_extracted_data_changed(self, extracted_data: dict):
        """
        Called when extracted/categorized data is updated in the shared store.
        Propagates to all reports and forms for auto-population of cards and popups.
        """
        if not extracted_data:
            return

        print(f"[SharedData] Extracted data changed - propagating to all sections")
        print(f"[SharedData] Categories: {list(extracted_data.get('categories', {}).keys())}")

        # Update letter writer with extracted data
        if hasattr(self, 'letter_page') and self.letter_page:
            if hasattr(self.letter_page, '_on_extracted_data'):
                self.letter_page._on_extracted_data(extracted_data)
                print(f"[SharedData] Auto-populated letter_page with extracted data")

        # Update all report pages with extracted data
        report_pages = [
            'tribunal_page', 'nursing_tribunal_page', 'social_tribunal_page',
            'general_psychiatric_page'
        ]

        for page_name in report_pages:
            page = getattr(self, page_name, None)
            if page and hasattr(page, '_on_data_extracted'):
                page._on_data_extracted(extracted_data)
                print(f"[SharedData] Auto-populated {page_name} with extracted data")

        # Update form pages with extracted data
        form_pages = ['moj_leave_form_page', 'moj_asr_form_page']

        for page_name in form_pages:
            page = getattr(self, page_name, None)
            if page and hasattr(page, '_on_data_extracted'):
                page._on_data_extracted(extracted_data)
                print(f"[SharedData] Auto-populated {page_name} with extracted data")

    def _on_shared_patient_info_changed(self, patient_info: dict):
        """
        Called when patient demographics are updated in the shared store.
        Propagates patient details to all forms and reports with patient fields.
        """
        if not patient_info:
            return

        print(f"[SharedData] Patient info changed - propagating to all sections")
        print(f"[SharedData] Patient fields: {list(k for k, v in patient_info.items() if v)}")

        # Update letter writer front page
        if hasattr(self, 'letter_page') and self.letter_page:
            if hasattr(self.letter_page, '_fill_front_page'):
                self.letter_page._fill_front_page(patient_info)
                print(f"[SharedData] Updated letter_page front page with patient info")

        # Update report pages with patient details
        report_pages = [
            'tribunal_page', 'nursing_tribunal_page', 'social_tribunal_page',
            'general_psychiatric_page'
        ]

        for page_name in report_pages:
            page = getattr(self, page_name, None)
            if page and hasattr(page, '_fill_patient_details'):
                page._fill_patient_details(patient_info)
                print(f"[SharedData] Updated {page_name} with patient info")

        # Update form pages with patient details
        form_pages = [
            'moj_leave_form_page', 'moj_asr_form_page', 'h5_form_page',
            'a2_form_page', 'a3_form_page', 'a4_form_page', 'a6_form_page',
            'a7_form_page', 'a8_form_page', 'h1_form_page',
            'cto1_form_page', 'cto3_form_page', 'cto4_form_page',
            'cto5_form_page', 'cto7_form_page', 'm2_form_page', 't2_form_page'
        ]

        for page_name in form_pages:
            page = getattr(self, page_name, None)
            if page and hasattr(page, '_fill_patient_details'):
                page._fill_patient_details(patient_info)
                print(f"[SharedData] Updated {page_name} with patient info")

    def _inject_shared_extracted_data_to_page(self, page):
        """Helper to inject current shared store extracted data into a page."""
        extracted = self.shared_store.extracted_data
        print(f"[SharedData] _inject_shared_extracted_data_to_page called for {page.__class__.__name__ if page else 'None'}")
        print(f"[SharedData] extracted_data available: {bool(extracted)}, categories: {list(extracted.get('categories', {}).keys()) if extracted else 'N/A'}")

        if page and extracted:
            # Try different method names used by different pages
            if hasattr(page, '_on_data_extracted'):
                print(f"[SharedData] Calling _on_data_extracted on {page.__class__.__name__}")
                page._on_data_extracted(extracted)
                print(f"[SharedData] Injected extracted data into {page.__class__.__name__}")
            elif hasattr(page, '_on_extracted_data'):
                print(f"[SharedData] Calling _on_extracted_data on {page.__class__.__name__}")
                page._on_extracted_data(extracted)
                print(f"[SharedData] Injected extracted data into {page.__class__.__name__}")
            else:
                print(f"[SharedData] WARNING: {page.__class__.__name__} has no _on_data_extracted or _on_extracted_data method")
        else:
            print(f"[SharedData] Skipping injection - page: {bool(page)}, extracted: {bool(extracted)}")


# ============================================================
# ENTRY POINT
# ============================================================

def main():
    # Zoom is handled via window resizing in MainWindow
    app = QApplication(sys.argv)

    # Reduce global font size by ~10%
    from PySide6.QtGui import QFont
    default_font = app.font()
    default_font.setPointSizeF(default_font.pointSizeF() * 0.9)
    app.setFont(default_font)

    # Force Fusion style on Windows for consistent radio button appearance
    import sys as _sys
    if _sys.platform == 'win32':
        app.setStyle("Fusion")

    app.setWindowIcon(QIcon(resource_path("resources", "icons", "MyPsychAdmin.icns")))

    # Global styling for Windows compatibility
    app.setStyleSheet("""
        QToolTip {
            background-color: #fffbe6;
            color: #000000;
            border: 1px solid #999;
            padding: 5px;
            font-size: 13px;
            font-weight: 500;
        }
        QRadioButton {
            background: transparent;
        }
        QRadioButton::indicator {
            width: 16px;
            height: 16px;
            border: 2px solid #666;
            border-radius: 9px;
            background: white;
        }
        QRadioButton::indicator:checked {
            background: #2563eb;
            border: 2px solid #2563eb;
        }
        QCheckBox {
            background: transparent;
        }
        QCheckBox::indicator {
            width: 16px;
            height: 16px;
            border: 2px solid #666;
            border-radius: 3px;
            background: white;
        }
        QCheckBox::indicator:checked {
            background: #2563eb;
            border: 2px solid #2563eb;
        }
    """)

    ok, payload_or_msg = is_license_valid()
    if not ok:
        dialog = ActivationDialog()
        result = dialog.exec()
        if result != QDialog.Accepted:
            print("Activation failed — exiting.", payload_or_msg)
            sys.exit(0)

    # --- Migrate legacy DB if it exists ---
    migrate_old_database()

    # --- Create local DB (clinician details, always available) ---
    local_db = Database()

    # --- Connect patient DB ---
    patient_db = None
    saved_path = local_db.get_setting("patient_db_path")

    if saved_path and os.path.exists(os.path.dirname(saved_path)):
        # Saved path exists — connect directly
        try:
            patient_db = PatientDatabase(saved_path)
            print(f"[Startup] Patient DB connected: {saved_path}")
        except Exception as e:
            print(f"[Startup] Patient DB error at {saved_path}: {e}")
            saved_path = None  # fall through to dialog

    if patient_db is None:
        # No saved path or it failed — ask user
        setup = PatientDbSetupDialog()
        if setup.exec() == QDialog.Accepted and setup.chosen_path:
            try:
                patient_db = PatientDatabase(setup.chosen_path)
                local_db.set_setting("patient_db_path", setup.chosen_path)
                print(f"[Startup] Patient DB created: {setup.chosen_path}")
            except Exception as e:
                print(f"[Startup] Patient DB error: {e}")
        else:
            print("[Startup] Patient DB skipped")

    win = MainWindow()
    if patient_db:
        win.set_patient_db(patient_db)
    win.show()

    # Unregister session and close patient DB on shutdown
    def _on_app_quit():
        if win.patient_db is not None:
            try:
                win.patient_db.close()
            except Exception as e:
                print(f"[Shutdown] Patient DB close error: {e}")

    app.aboutToQuit.connect(_on_app_quit)

    sys.exit(app.exec())

if __name__ == "__main__":
    main()
