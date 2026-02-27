from __future__ import annotations
from typing import List, Dict, Any
import pandas as pd
import re
import sys
from PySide6.QtGui import QColor
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QTableWidget, QTableWidgetItem, QHeaderView, QComboBox,
    QTextEdit, QLineEdit, QFileDialog, QSplitter, QAbstractItemView, QSizePolicy,
    QGraphicsOpacityEffect, QCalendarWidget, QDialog, QDialogButtonBox, QMessageBox,
    QToolButton, QMenu
)
from PySide6.QtCore import QPropertyAnimation, QEasingCurve
from PySide6.QtCore import Qt, Signal, QTimer
from datetime import datetime, date, time

# IMPORT OPTIONS
from importer_autodetect import (
    import_files_rio,
    import_files_carenotes,
    import_files_epjs,
)
from utils.resource_path import resource_path

# SHARED DATA STORE - centralized data sharing
from shared_data_store import get_shared_store


# ======================================================================
# DATE FORMATTER
# ======================================================================
def format_pretty_date(dt):
    if dt is None:
        return ""
    try:
        if pd.isna(dt):
            return ""
    except Exception:
        pass
    try:
        d = int(dt.day)
    except Exception:
        return str(dt).split(" ")[0]

    if 4 <= d <= 20 or 24 <= d <= 30:
        suf = "th"
    else:
        suf = ["st", "nd", "rd"][d % 10 - 1]

    base = f"{d}{suf} {dt.strftime('%B %Y')}"

    # Append time if the object has hour/minute and it's not midnight
    try:
        if hasattr(dt, 'hour') and (dt.hour != 0 or dt.minute != 0):
            base += dt.strftime(" %H:%M")
    except Exception:
        pass

    return base

# ============================================================
# NOTE SOURCE COLOURS
# ============================================================
SOURCE_COLOURS = {
    "rio": "#3a7afe",
    "carenotes": "#27ae60",
    "epjs": "#8e44ad",
    "notes_entry": "#d97706",
    "systmone": "#e74c3c",
}
# ======================================================================
# MAIN PANEL
# ======================================================================
class PatientNotesPanel(QWidget):

    request_collapse = Signal()
    request_expand = Signal()
    edit_note_requested = Signal(object)  # emits the note dict
    epr_requested = Signal(str)  # emits NHS number

    def __init__(self, db=None, parent=None):
        super().__init__(parent)
        self.db = db

        self.all_notes: List[Dict[str, Any]] = []
        self.filtered_notes: List[Dict[str, Any]] = []

        self.current_search = ""
        self.extraction_highlight_terms: list = []
        self.is_collapsed = False

        self._build_ui()
        self._entry_notes_loaded = False

        # Load entry notes when patient is selected
        try:
            store = get_shared_store()
            store.patient_changed.connect(self._on_patient_changed)
        except Exception:
            pass

    # ------------------------------------------------------------
    # BUILD UI
    # ------------------------------------------------------------
    def _build_ui(self):
        outer = QVBoxLayout(self)
        outer.setContentsMargins(10, 10, 10, 10)
        outer.setSpacing(8)

        # ============================================================
        # TOP BAR (macOS subtle frosted identity)
        # ============================================================
        # ============================================================
        # TOP BAR — STABLE LAYOUT, NO SHRINKING MESS
        # ============================================================
        top = QWidget()
        top.setObjectName("notesToolbar")
        top.setStyleSheet("""
            #notesToolbar {
                background: rgba(245, 248, 250, 0.55);
                border: 1px solid #D0D5DA;
                border-radius: 8px;
            }
        """)
        bar = QHBoxLayout(top)
        bar.setContentsMargins(8, 8, 8, 8)
        bar.setSpacing(8)

        # --- Sizes ---
        FIX_WIDE  = QSizePolicy.Fixed
        FIX_TALL  = QSizePolicy.Fixed
        EXPAND_H  = QSizePolicy.Expanding

        # --- UPLOAD DOCS BUTTON (far left) ---
        self._upload_btn = QToolButton()
        self._upload_btn.setText("Upload")
        self._upload_btn.setFixedSize(72, 26)
        self._upload_btn.setPopupMode(QToolButton.InstantPopup)
        self._upload_menu = QMenu()
        self._shared_store = get_shared_store()
        self._refresh_upload_menu(self._shared_store.get_uploaded_documents())
        self._shared_store.uploaded_documents_changed.connect(self._refresh_upload_menu)
        self._upload_btn.setMenu(self._upload_menu)
        self._upload_btn.setStyleSheet("""
            QToolButton {
                background: #10b981;
                color: white;
                font-size: 10px;
                font-weight: 600;
                border: none;
                border-radius: 4px;
                padding: 2px 6px;
            }
            QToolButton:hover { background: #059669; }
            QToolButton::menu-indicator { image: none; }
        """)
        bar.addWidget(self._upload_btn)

        # --- SEARCH AREA ---
        self.search_box = QLineEdit()
        self.search_box.setFixedHeight(32)
        self.search_box.setMinimumWidth(80)
        self.search_box.setPlaceholderText("Search notes…")
        self.search_box.setClearButtonEnabled(True)
        self.search_box.returnPressed.connect(self.on_search_clicked)
        bar.addWidget(self.search_box, 1)

        # --- SEARCH BUTTON ---
        self.btn_search = QPushButton("Search")
        self.btn_search.setFixedWidth(80)
        self.btn_search.setFixedHeight(32)
        self.btn_search.setSizePolicy(FIX_WIDE, FIX_TALL)
        self.btn_search.clicked.connect(self.on_search_clicked)
        bar.addWidget(self.btn_search)

        # --- TYPE FILTER ---
        filter_label = QLabel("Filter:")
        filter_label.setStyleSheet("font-weight: bold; color: #555; background: transparent; border: none;")
        bar.addWidget(filter_label)

        self.cmb_type = QComboBox()
        self.cmb_type.addItem("All types")
        self.cmb_type.setFixedWidth(120)
        self.cmb_type.setFixedHeight(32)
        self.cmb_type.setSizePolicy(FIX_WIDE, FIX_TALL)
        self.cmb_type.currentIndexChanged.connect(self.filter_types)
        bar.addWidget(self.cmb_type)

        # live filter on empty search
        self.search_box.textChanged.connect(
                lambda: self.filter_types() if not self.search_box.text().strip() else None
        )

        outer.addWidget(top)       # add toolbar

        

        # ============================================================
        # SPLITTER
        # ============================================================
        self.inner_splitter = QSplitter(Qt.Vertical)
        self.inner_splitter.setHandleWidth(4)
        outer.addWidget(self.inner_splitter, 1)

        # ============================================================
        # TABLE AREA — Medium Frost Glass
        # ============================================================
        top_w = QWidget()
        top_w.setStyleSheet("""
            QWidget {
                background: rgba(248, 250, 252, 0.65);
                border: 1px solid #C6CBD0;
                border-radius: 8px;
            }
        """)
        top_l = QVBoxLayout(top_w)
        top_l.setContentsMargins(6, 6, 6, 6)

        self.table = QTableWidget(0, 4)
        self.table.setHorizontalHeaderLabels(["Date", "Type", "Originator", "Preview"])
        self.table.setAlternatingRowColors(True)
        self.table.setStyleSheet("""
            QTableWidget {
                background: #FFFFFF;
                alternate-background-color: #F3F5F7;
                gridline-color: #D0D5DA;
                selection-background-color: #C7DFFE;
                selection-color: #000000;
                font-size: 13px;
            }
            QHeaderView::section {
                background: rgba(230, 234, 240, 0.85);
                border: 1px solid #C6CBD0;
                padding: 4px;
                font-weight: bold;
            }
        """)

        h = self.table.horizontalHeader()
        h.setSectionsMovable(True)
        h.setSectionResizeMode(QHeaderView.Interactive)
        h.setStretchLastSection(False)

        self.table.setColumnWidth(0, 130)
        self.table.setColumnWidth(1, 150)
        self.table.setColumnWidth(2, 180)
        self.table.setColumnWidth(3, 480)

        self.table.setSelectionBehavior(QTableWidget.SelectRows)
        self.table.setSelectionMode(QTableWidget.SingleSelection)
        self.table.itemSelectionChanged.connect(lambda: self._on_select_delayed())

        # Connect header click for date picker
        h.sectionClicked.connect(self._on_header_clicked)

        top_l.addWidget(self.table)

        # ============================================================
        # DETAIL AREA — Medium Frost Glass
        # ============================================================
        self.detail_panel = QWidget()
        self.detail_panel.setStyleSheet("""
            QWidget {
                background: rgba(245, 247, 249, 0.65);
                border: 1px solid #C6CBD0;
                border-radius: 8px;
            }
        """)
        self._detail_panel_base_style = """
            QWidget {
                background: rgba(245, 247, 249, 0.65);
                border: 1px solid #C6CBD0;
                border-radius: 8px;
            }
        """
        bot_l = QVBoxLayout(self.detail_panel)
        bot_l.setContentsMargins(8, 8, 8, 8)

        lbl = QLabel("Note details")
        lbl.setStyleSheet("font-weight: bold; font-size: 13px; color: #333;")
        bot_l.addWidget(lbl)

        self.txt_detail = QTextEdit()
        self.txt_detail.setReadOnly(True)
        self.txt_detail.setStyleSheet("""
            QTextEdit {
                background: #FFFFFF;
                border: 1px solid #D0D5DA;
                border-radius: 6px;
                padding: 6px;
                font-size: 13px;
            }
        """)
        bot_l.addWidget(self.txt_detail)

        # Action buttons for notes_entry notes
        self._action_bar = QWidget()
        self._action_bar.setStyleSheet("border: none; background: transparent;")
        ab_layout = QHBoxLayout(self._action_bar)
        ab_layout.setContentsMargins(0, 4, 0, 0)
        ab_layout.setSpacing(8)

        self.btn_confirm = QPushButton("Confirm")
        self.btn_confirm.setCursor(Qt.PointingHandCursor)
        self.btn_confirm.setFixedHeight(30)
        self.btn_confirm.setStyleSheet(
            "QPushButton { background: #16a34a; color: white; border: none; "
            "border-radius: 5px; font-size: 13px; font-weight: 600; padding: 0 16px; }"
            "QPushButton:hover { background: #15803d; }"
        )
        self.btn_confirm.clicked.connect(self._on_confirm_note)

        self.btn_edit = QPushButton("Edit")
        self.btn_edit.setCursor(Qt.PointingHandCursor)
        self.btn_edit.setFixedHeight(30)
        self.btn_edit.setStyleSheet(
            "QPushButton { background: #2563eb; color: white; border: none; "
            "border-radius: 5px; font-size: 13px; font-weight: 600; padding: 0 16px; }"
            "QPushButton:hover { background: #1d4ed8; }"
        )
        self.btn_edit.clicked.connect(self._on_edit_note)

        self.btn_error = QPushButton("Entered in Error")
        self.btn_error.setCursor(Qt.PointingHandCursor)
        self.btn_error.setFixedHeight(30)
        self.btn_error.setStyleSheet(
            "QPushButton { background: #dc2626; color: white; border: none; "
            "border-radius: 5px; font-size: 13px; font-weight: 600; padding: 0 16px; }"
            "QPushButton:hover { background: #b91c1c; }"
        )
        self.btn_error.clicked.connect(self._on_error_note)

        ab_layout.addWidget(self.btn_confirm)
        ab_layout.addWidget(self.btn_edit)
        ab_layout.addWidget(self.btn_error)
        ab_layout.addStretch()

        self._action_bar.hide()
        bot_l.addWidget(self._action_bar)

        # Install event filter to catch clicks on the detail panel and text area
        self.detail_panel.installEventFilter(self)
        self.txt_detail.installEventFilter(self)

        self.inner_splitter.addWidget(top_w)
        self.inner_splitter.addWidget(self.detail_panel)

    # ==================================================================
    # EVENT FILTER - catch clicks on detail panel
    # ==================================================================
    def eventFilter(self, obj, event):
        from PySide6.QtCore import QEvent
        if event.type() == QEvent.MouseButtonPress:
            if obj in (self.detail_panel, self.txt_detail):
                self._flash_detail_panel()
        return super().eventFilter(obj, event)

    # ==================================================================
    # SEARCH HANDLER — highlight ALL occurrences
    # ==================================================================
    def on_search_clicked(self):
        query = self.search_box.text().strip()
        self.current_search = query.lower()

        if not self.current_search:
            self.filter_types()
            return

        results = []
        for note in self.all_notes:
            hay = " ".join([
                str(note.get("date", "")),
                note.get("type", ""),
                note.get("originator", ""),
                note.get("preview", ""),
                note.get("content", "")
            ]).lower()

            if self.current_search in hay:
                results.append(note)

        self.filtered_notes = results
        self.refresh_table()

        if results:
            self.table.selectRow(0)
            self.on_select()

    # ==================================================================
    # COLLAPSE (called from WorkspaceArea button)
    # ==================================================================
    def collapse(self):
        """Collapse this panel."""
        self.is_collapsed = True
        self.request_collapse.emit()

    def expand(self):
        """Expand this panel."""
        self.is_collapsed = False
        self.request_expand.emit()

    # ==================================================================
    # UPLOAD MENU
    # ==================================================================
    def _refresh_upload_menu(self, docs=None):
        """Rebuild the Upload Notes dropdown menu."""
        self._upload_menu.clear()

        # EPR option (Windows only)
        if sys.platform == "win32":
            epr_action = self._upload_menu.addAction("Upload from EPR")
            epr_action.triggered.connect(self._launch_epr)

        # Upload from Document
        doc_action = self._upload_menu.addAction("Upload from Document")
        doc_action.triggered.connect(self._upload_from_document)

        self._upload_menu.addSeparator()

        # Existing uploaded documents
        if docs is None:
            docs = get_shared_store().get_uploaded_documents()
        if not docs:
            action = self._upload_menu.addAction("No documents uploaded yet")
            action.setEnabled(False)
        else:
            for doc in docs:
                path = doc["path"]
                action = self._upload_menu.addAction(doc["filename"])
                action.triggered.connect(
                    lambda checked=False, p=path: self._import_from_upload(p)
                )

    def _import_from_upload(self, path):
        """Process an uploaded file through the full notes pipeline."""
        from importer_pdf import import_pdf_notes
        from importer_docx import import_docx_notes

        raw = []
        fl = path.lower()
        if fl.endswith(".pdf"):
            raw.extend(import_pdf_notes([path]))
        elif fl.endswith(".docx"):
            raw.extend(import_docx_notes(path))
        elif fl.endswith(".csv"):
            from importer_systmone import is_systmone_csv, parse_systmone_csv
            if is_systmone_csv(path):
                raw.extend(parse_systmone_csv(path))
        elif fl.endswith(".rtf"):
            from importer_systmone import parse_systmone_rtf
            raw.extend(parse_systmone_rtf(path))
        elif fl.endswith((".xlsx", ".xls")):
            from importer_autodetect import import_files_autodetect
            raw.extend(import_files_autodetect([path]))

        if not raw:
            QMessageBox.information(
                self, "No Notes Found",
                "No notes could be extracted from the uploaded file."
            )
            return

        print(f"[NotesPanel] Upload: parsed {len(raw)} notes from {path}")
        self._clean_and_load(raw)

    def _upload_from_document(self):
        """Open file dialog and import the selected document."""
        files, _ = QFileDialog.getOpenFileNames(
            self, "Upload Documents", "",
            "All Supported (*.pdf *.docx *.xlsx *.xls *.csv *.rtf);;"
            "PDF (*.pdf);;Word (*.docx);;Excel (*.xlsx *.xls);;"
            "CSV (*.csv);;RTF (*.rtf)"
        )
        if files:
            store = get_shared_store()
            for f in files:
                store.add_uploaded_document(f)
            self._import_from_upload(files[0])

    def _launch_epr(self):
        """Emit signal to show EPR embed panel in workspace."""
        store = get_shared_store()
        nhs = store.get_patient_field("nhs_number", "") or ""
        nhs = nhs.replace(" ", "")
        self.epr_requested.emit(nhs)

    def _on_epr_notes_captured(self, rows):
        """Handle rows captured from EPR automation — stash for later."""
        self._epr_pending_rows = rows
        print(f"[NotesPanel] EPR: captured {len(rows)} rows, waiting for automation to finish")

    def _on_epr_done(self, success, msg, system_type=""):
        """Handle EPR automation completion (called from page)."""
        if not success:
            QMessageBox.warning(self, "EPR Capture Failed", msg)
            return

        # Now process the stashed rows with the window visible
        rows = getattr(self, '_epr_pending_rows', None)
        if rows:
            self._epr_pending_rows = None
            try:
                if system_type == "carenotes":
                    from importer_carenotes import parse_carenotes_rows
                    notes = parse_carenotes_rows(rows)
                else:
                    from importer_systmone import parse_systmone_rows
                    notes = parse_systmone_rows(rows)
                if notes:
                    print(f"[NotesPanel] EPR ({system_type}): parsed {len(notes)} notes from {len(rows)} rows")
                    self._clean_and_load(notes)
                else:
                    print(f"[NotesPanel] EPR ({system_type}): no notes parsed from {len(rows)} rows")
            except Exception as e:
                print(f"[NotesPanel] EPR error: {e}")
                QMessageBox.warning(self, "EPR Import Error", str(e))

    # ==================================================================
    # IMPORT
    # ==================================================================
    def on_import_clicked(self):
        from importer_pdf import import_pdf_notes
        from importer_docx import import_docx_notes

        files, _ = QFileDialog.getOpenFileNames(
            self, "Select files", "",
            "All Supported (*.pdf *.xlsx *.xls *.docx *.csv *.rtf);;All files (*)"
        )
        if not files:
            return

        # Register each uploaded file in SharedDataStore for form pages
        shared_store = get_shared_store()
        for f in files:
            shared_store.add_uploaded_document(f)

        raw = []

        for f in files:
            fl = f.lower()

            # ---------------------------------
            # PDF
            # ---------------------------------
            if fl.endswith(".pdf"):
                raw.extend(import_pdf_notes([f]))
                continue

            # ---------------------------------
            # DOCX
            # ---------------------------------
            if fl.endswith(".docx"):
                raw.extend(import_docx_notes([f], "auto"))
                continue

            # ---------------------------------
            # CSV (SystmOne)
            # ---------------------------------
            if fl.endswith(".csv"):
                from importer_systmone import is_systmone_csv, parse_systmone_csv
                if is_systmone_csv(f):
                    raw.extend(parse_systmone_csv(f))
                continue

            # ---------------------------------
            # RTF (SystmOne)
            # ---------------------------------
            if fl.endswith(".rtf"):
                from importer_systmone import parse_systmone_rtf
                raw.extend(parse_systmone_rtf(f))
                continue

            # ---------------------------------
            # EXCEL (AUTO-DETECT ONLY)
            # ---------------------------------
            if fl.endswith(".xlsx") or fl.endswith(".xls"):
                from importer_autodetect import import_files_autodetect
                raw.extend(import_files_autodetect([f]))
                continue

        print("TOTAL RAW NOTES IMPORTED:", len(raw))
        self._clean_and_load(raw)

    # ==================================================================
    # CLEAN
    # ==================================================================
    def _clean_and_load(self, raw):
        cleaned = []
        for n in raw:
            dt = n.get("date")

            content = (
                n.get("content")
                or n.get("text")
                or n.get("body")
                or n.get("note")
                or ""
            )
            content = str(content)

            preview = " ".join(content.split("\n")[:3]).strip()
            if len(preview) > 200:
                preview = preview[:197] + "…"

            cleaned.append({
                "date": dt,
                "type": str(n.get("type", "")).strip(),
                "raw_type": str(n.get("raw_type", "")).strip(),
                "originator": str(n.get("originator", "")).strip(),
                "preview": preview,
                "content": content,
                "source": str(n.get("source", "")).lower()
            })

        # --- Ask to add or replace if notes already loaded ---
        if self.all_notes and cleaned:
            cleaned = self._ask_add_or_replace(cleaned)
            if cleaned is None:
                return  # User cancelled

        # Always sort latest first
        cleaned.sort(key=lambda n: n.get("date") or datetime.min, reverse=True)

        self.all_notes = cleaned
        # Merge back any persisted notes_entry notes so they're not lost on import
        self._entry_notes_loaded = False  # force reload after replace
        self._load_entry_notes_from_db()
        self._rebuild_type_filter()
        self.filter_types()

        # Update shared data store so all sections can access these notes
        # Use all_notes (includes entry notes) so everything is available for analysis
        shared_store = get_shared_store()
        shared_store.set_notes(self.all_notes, source="notes_panel")
        print(f"[NotesPanel] Updated SharedDataStore with {len(self.all_notes)} notes")

        # Run extraction and push extracted data for auto-populating reports/forms
        self._run_extraction_for_global_import(self.all_notes, shared_store)

    # ==================================================================
    # ADD / REPLACE DIALOG
    # ==================================================================
    def _ask_add_or_replace(self, new_notes):
        """When notes already exist, ask the user whether to add or replace.

        Returns the final notes list, or None if cancelled.
        """
        existing_count = len(self.all_notes)
        new_count = len(new_notes)

        # Build a summary of what's loaded vs what's incoming
        existing_range = self._describe_notes(self.all_notes)
        new_range = self._describe_notes(new_notes)

        msg = QMessageBox(self)
        msg.setWindowTitle("Notes Already Loaded")
        msg.setIcon(QMessageBox.Question)
        msg.setText(
            f"There are already {existing_count} notes loaded{existing_range}.\n\n"
            f"You are importing {new_count} new notes{new_range}.\n\n"
            "Do you want to add them to the existing notes, or replace them?"
        )

        add_btn = msg.addButton("Add to Existing", QMessageBox.AcceptRole)
        replace_btn = msg.addButton("Replace All", QMessageBox.DestructiveRole)
        cancel_btn = msg.addButton("Cancel", QMessageBox.RejectRole)
        msg.setDefaultButton(add_btn)

        msg.exec()
        clicked = msg.clickedButton()

        if clicked == cancel_btn:
            return None

        if clicked == add_btn:
            merged = list(self.all_notes) + new_notes
            before = len(merged)
            merged = self._deduplicate_notes(merged)
            dupes = before - len(merged)
            if dupes:
                print(f"[NotesPanel] Removed {dupes} duplicate notes during merge")
            # Sort by date, latest first
            merged.sort(key=lambda n: n.get("date") or datetime.min, reverse=True)
            return merged

        # Replace — sort by date, latest first
        new_notes.sort(key=lambda n: n.get("date") or datetime.min, reverse=True)
        return new_notes

    @staticmethod
    def _describe_notes(notes):
        """Return a short string describing the date range and sources."""
        if not notes:
            return ""
        dates = [n["date"] for n in notes if n.get("date")]
        sources = {n.get("source", "").lower() for n in notes if n.get("source")}
        parts = []
        if dates:
            earliest = min(dates)
            latest = max(dates)
            parts.append(f"{earliest.strftime('%d %b %Y')} - {latest.strftime('%d %b %Y')}")
        if sources:
            parts.append(", ".join(sorted(s for s in sources if s)))
        if parts:
            return f" ({'; '.join(parts)})"
        return ""

    @staticmethod
    def _deduplicate_notes(notes):
        """Remove duplicate notes based on date + first 200 chars of content."""
        seen = set()
        unique = []
        for n in notes:
            dt_str = str(n.get("date", ""))
            content_key = (n.get("content") or "")[:200].strip()
            key = (dt_str, content_key)
            if key not in seen:
                seen.add(key)
                unique.append(n)
        return unique

    def _run_extraction_for_global_import(self, notes, shared_store):
        """Run extraction on notes and push to SharedDataStore for all sections."""
        if not notes:
            return

        try:
            from history_extractor_sections import extract_patient_history, convert_to_panel_format
            from timeline_builder import build_timeline

            # Prepare notes for extraction
            prepared = []
            for n in notes:
                prepared.append({
                    "date": n.get("date"),
                    "type": (n.get("type") or "").strip().lower(),
                    "raw_type": (n.get("raw_type") or "").strip(),
                    "originator": n.get("originator", "").strip(),
                    "content": n.get("content", "").strip(),
                    "text": n.get("content", "").strip(),
                    "source": n.get("source", "").strip().lower()
                })

            # Extract and push patient demographics using central extractor
            try:
                from patient_demographics import extract_demographics
                patient_info = extract_demographics(notes)
            except ImportError:
                # Fallback to local extraction if central module not available
                patient_info = self._extract_patient_demographics(notes)

            if any(patient_info.values()):
                shared_store.set_patient_info(patient_info, source="notes_panel")
                print(f"[NotesPanel] 🌐 Global import: pushed patient info to SharedDataStore: {list(k for k,v in patient_info.items() if v)}")

            # Build timeline and extract history
            episodes = build_timeline(prepared)
            history = extract_patient_history(prepared, episodes=episodes)
            panel_data = convert_to_panel_format(history)

            # Push extracted data to SharedDataStore
            if panel_data:
                categories = panel_data.get("categories", {})
                print(f"[NotesPanel] 🌐 Extracted {len(categories)} categories: {list(categories.keys())}")
                shared_store.set_extracted_data(panel_data, source="notes_panel")
                print(f"[NotesPanel] 🌐 Global import: pushed extracted panel_data to SharedDataStore")
            else:
                print(f"[NotesPanel] ⚠️ No panel_data extracted from notes")

        except Exception as e:
            import traceback
            print(f"[NotesPanel] ⚠️ Extraction failed: {e}")
            traceback.print_exc()

    def _extract_patient_demographics(self, notes):
        """Extract patient demographics (name, DOB, NHS number, gender, age, ethnicity) from notes."""
        from datetime import datetime

        demographics = {
            "name": None,
            "dob": None,
            "nhs_number": None,
            "gender": None,
            "age": None,
            "ethnicity": None,
        }

        if not notes:
            return demographics

        # Get text from first note (usually has demographics at top)
        first_note_text = ""
        if notes:
            first_note = notes[0]
            first_note_text = first_note.get("text") or first_note.get("content") or ""

        # Get combined text from first 20 notes for demographic search
        # Use list + join for O(n) instead of O(n²) string concatenation
        top_texts = [note.get("text") or note.get("content") or "" for note in notes[:20]]
        top_notes_text = "\n".join(top_texts)

        # Get ALL notes text for pronoun counting - single pass, O(n)
        all_texts = [note.get("text") or note.get("content") or "" for note in notes]
        all_notes_text = "\n".join(all_texts)

        all_notes_lower = all_notes_text.lower()

        # ============================================================
        # EXTRACT NAME - scan line by line in top notes
        # ============================================================
        name_candidates = []

        for line in top_notes_text.split('\n'):
            line = line.strip()
            if not line:
                continue

            # Pattern 1: "PATIENT NAME: Firstname Lastname"
            match = re.match(r"(?:PATIENT\s*NAME|CLIENT\s*NAME|NAME)\s*[:\-]?\s*([A-Za-z][A-Za-z\-\']+\s+[A-Za-z][A-Za-z\-\']+(?:\s+[A-Za-z][A-Za-z\-\']+)?)\s*$", line, re.IGNORECASE)
            if match:
                candidate = match.group(1).strip()
                if not re.match(r"(?:DATE|DOB|NHS|GENDER|SEX|AGE|BIRTH|ADDRESS)", candidate, re.IGNORECASE):
                    name_candidates.append(candidate)
                    continue

            # Pattern 2: Line starts with "Name:" or "Patient:"
            match = re.match(r"(?:Name|Patient)\s*[:\-]\s*([A-Za-z][A-Za-z\-\']+\s+[A-Za-z][A-Za-z\-\']+(?:\s+[A-Za-z\-\']+)?)", line, re.IGNORECASE)
            if match:
                candidate = match.group(1).strip()
                if not re.match(r"(?:DATE|DOB|NHS|GENDER|SEX|AGE|BIRTH)", candidate, re.IGNORECASE):
                    name_candidates.append(candidate)

        if name_candidates:
            demographics["name"] = name_candidates[0]
            print(f"[NotesPanel] Found name: {demographics['name']}")

        # ============================================================
        # EXTRACT DOB
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
                        print(f"[NotesPanel] Found DOB: {dob_str}")
                        break
                    except ValueError:
                        continue
                if demographics["dob"]:
                    break

        # ============================================================
        # EXTRACT/CALCULATE AGE
        # ============================================================
        # First try explicit age pattern
        age_patterns = [
            r"(?:AGE)\s*[:\-]?\s*(\d{1,3})\s*(?:years?|yrs?|y\.?o\.?)?\b",
            r"\b(\d{1,3})\s*(?:year|yr)\s*old\b",
            r"\b(\d{1,3})\s*y\.?o\.?\b",
        ]
        for pattern in age_patterns:
            match = re.search(pattern, top_notes_text, re.IGNORECASE)
            if match:
                age = int(match.group(1))
                if 0 < age < 120:  # Reasonable age range
                    demographics["age"] = age
                    print(f"[NotesPanel] Found age: {age}")
                    break

        # Calculate age from DOB if not found explicitly
        if not demographics["age"] and demographics["dob"]:
            today = datetime.now()
            dob = demographics["dob"]
            age = today.year - dob.year - ((today.month, today.day) < (dob.month, dob.day))
            if 0 < age < 120:
                demographics["age"] = age
                print(f"[NotesPanel] Calculated age from DOB: {age}")

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
                print(f"[NotesPanel] Found NHS: {demographics['nhs_number']}")
                break

        # ============================================================
        # EXTRACT GENDER - explicit patterns first, then pronouns
        # ============================================================
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
                print(f"[NotesPanel] Found gender from label: {demographics['gender']}")
                break

        # Fallback: count pronouns across ALL notes
        if not demographics["gender"]:
            male_pronouns = len(re.findall(r"\bhe\b|\bhim\b|\bhis\b", all_notes_lower))
            female_pronouns = len(re.findall(r"\bshe\b|\bher\b|\bhers\b", all_notes_lower))

            print(f"[NotesPanel] Pronoun count - Male: {male_pronouns}, Female: {female_pronouns}")

            if male_pronouns > female_pronouns * 2 or male_pronouns > female_pronouns + 10:
                demographics["gender"] = "Male"
                print(f"[NotesPanel] Inferred gender from pronouns: Male")
            elif female_pronouns > male_pronouns * 2 or female_pronouns > male_pronouns + 10:
                demographics["gender"] = "Female"
                print(f"[NotesPanel] Inferred gender from pronouns: Female")

        # ============================================================
        # EXTRACT ETHNICITY
        # ============================================================
        # Common NHS ethnicity categories
        ethnicity_patterns = [
            # Explicit ethnicity field
            r"(?:ETHNICITY|ETHNIC\s*(?:GROUP|ORIGIN|BACKGROUND)?)\s*[:\-]\s*([A-Za-z][A-Za-z\s\-\/]+?)(?:\n|$|,)",
            # Common ethnic descriptions
            r"\b(White\s*(?:British|Irish|European|Other)?)\b",
            r"\b(Black\s*(?:British|African|Caribbean|Other)?)\b",
            r"\b(Asian\s*(?:British|Indian|Pakistani|Bangladeshi|Chinese|Other)?)\b",
            r"\b(Mixed\s*(?:Race|Heritage|White\s*(?:and|&)\s*(?:Black|Asian))?)\b",
            r"\b(African|Caribbean|Indian|Pakistani|Bangladeshi|Chinese)\b",
            r"\b(British\s*(?:Asian|African|Caribbean))\b",
        ]
        for pattern in ethnicity_patterns:
            match = re.search(pattern, top_notes_text, re.IGNORECASE)
            if match:
                ethnicity = match.group(1).strip()
                # Clean up and standardize
                ethnicity = re.sub(r'\s+', ' ', ethnicity).title()
                if len(ethnicity) > 2 and ethnicity.lower() not in ('the', 'and', 'for'):
                    demographics["ethnicity"] = ethnicity
                    print(f"[NotesPanel] Found ethnicity: {ethnicity}")
                    break

        print(f"[NotesPanel] Demographics result: {demographics}")
        return demographics



    # ==================================================================
    # TYPE FILTER
    # ==================================================================
    def _rebuild_type_filter(self):
        self.cmb_type.blockSignals(True)
        self.cmb_type.clear()
        self.cmb_type.addItem("All types")

        types = sorted({n["type"] or "(No type)" for n in self.all_notes})
        for t in types:
            self.cmb_type.addItem(t)

        self.cmb_type.setCurrentIndex(0)
        self.cmb_type.blockSignals(False)

    def filter_types(self):
        t = self.cmb_type.currentText()

        # Remember currently selected note before filtering
        selected_note = None
        rows = self.table.selectionModel().selectedRows()
        if rows and self.filtered_notes:
            row = rows[0].row()
            if row < len(self.filtered_notes):
                selected_note = self.filtered_notes[row]

        # Filter directly without unnecessary copy
        if t == "All types":
            self.filtered_notes = self.all_notes
        elif t == "(No type)":
            self.filtered_notes = [x for x in self.all_notes if not x["type"]]
        else:
            self.filtered_notes = [x for x in self.all_notes if x["type"] == t]

        self.refresh_table(preserve_selection=selected_note)


    # ==================================================================
    # TABLE REFRESH + HTML HIGHLIGHTING
    # ==================================================================
    # Cache QColor objects for performance
    _COLOR_WHITE = QColor("white")
    _COLOR_CACHE = {}

    def refresh_table(self, preserve_selection=None):
        # Disable updates during batch operation for performance
        self.table.setUpdatesEnabled(False)
        try:
            self.table.setRowCount(len(self.filtered_notes))

            # Pre-compile regex pattern outside loop if searching
            search_pattern = None
            if self.current_search:
                search_pattern = re.compile(re.escape(self.current_search), re.IGNORECASE)

            for r, n in enumerate(self.filtered_notes):
                preview = n["preview"]

                if search_pattern:
                    preview = search_pattern.sub(
                        r'<span style="background-color:#CCE5FF; color:#003366;">\g<0></span>',
                        preview
                    )

                # Create items directly without inner loop
                date_item = QTableWidgetItem(format_pretty_date(n["date"]))
                date_item.setFlags(Qt.ItemIsSelectable | Qt.ItemIsEnabled)
                self.table.setItem(r, 0, date_item)

                type_item = QTableWidgetItem(n["type"])
                type_item.setFlags(Qt.ItemIsSelectable | Qt.ItemIsEnabled)
                # Apply source colour to TYPE column
                src = n.get("source", "")
                colour = SOURCE_COLOURS.get(src)
                if colour:
                    # Use cached QColor objects
                    if colour not in self._COLOR_CACHE:
                        self._COLOR_CACHE[colour] = QColor(colour)
                    type_item.setBackground(self._COLOR_CACHE[colour])
                    type_item.setForeground(self._COLOR_WHITE)
                self.table.setItem(r, 1, type_item)

                orig_item = QTableWidgetItem(n["originator"])
                orig_item.setFlags(Qt.ItemIsSelectable | Qt.ItemIsEnabled)
                self.table.setItem(r, 2, orig_item)

                preview_item = QTableWidgetItem()
                preview_item.setFlags(Qt.ItemIsSelectable | Qt.ItemIsEnabled)
                preview_item.setData(Qt.DisplayRole, preview)
                self.table.setItem(r, 3, preview_item)

                # Style notes_entry rows by status
                status = n.get("status", "")
                if status == "errored":
                    red = QColor("#dc2626")
                    red_bg = QColor("#fef2f2")
                    font = date_item.font()
                    font.setStrikeOut(True)
                    for item in (date_item, type_item, orig_item, preview_item):
                        item.setForeground(red)
                        item.setBackground(red_bg)
                        item.setFont(font)
                elif status == "confirmed":
                    lock_bg = QColor("#f0fdf4")
                    for item in (date_item, orig_item, preview_item):
                        item.setBackground(lock_bg)
                elif status in ("draft", "editing"):
                    yellow_bg = QColor("#fefce8")
                    for item in (date_item, orig_item, preview_item):
                        item.setBackground(yellow_bg)

        finally:
            # Re-enable updates
            self.table.setUpdatesEnabled(True)

        if self.filtered_notes:
            # Try to preserve selection if provided
            target_row = 0
            if preserve_selection is not None:
                for r, n in enumerate(self.filtered_notes):
                    if n is preserve_selection:
                        target_row = r
                        break

            self.table.selectRow(target_row)
            idx = self.table.model().index(target_row, 0)
            self.table.scrollTo(idx, QAbstractItemView.PositionAtCenter)

    # ==================================================================
    # SELECT ROW → DISPLAY CONTENT
    # ==================================================================
    # Cached stylesheets for performance (avoid recompilation)
    _FLASH_STYLE = """
        QWidget {
            background: rgba(199, 223, 254, 0.85);
            border: 2px solid #3a7afe;
            border-radius: 8px;
        }
    """

    def _on_select_delayed(self):
        # Use 0ms timer for deferred execution without creating rapid-fire timers
        QTimer.singleShot(0, self.on_select)

    def on_select(self):
        rows = self.table.selectionModel().selectedRows()
        if not rows:
            self._action_bar.hide()
            return
        row = rows[0].row()
        if row >= len(self.filtered_notes):
            self._action_bar.hide()
            return

        n = self.filtered_notes[row]

        # Auto-lock editing notes past their 30-day deadline
        self._check_edit_deadline(n)

        status = n.get("status", "")
        is_entry = n.get("source") == "notes_entry"

        header = (
            f"Date: {format_pretty_date(n['date'])}\n"
            f"Type: {n['type']}\n"
            f"Originator: {n['originator']}\n"
        )
        if status == "confirmed":
            header += "Status: Confirmed (locked)\n"
        elif status == "editing":
            dl = n.get("edit_deadline")
            if dl:
                header += f"Status: Editing (locks {format_pretty_date(dl)})\n"
        elif status == "errored":
            header += f"Status: Errored — {n.get('error_reason', '')}\n"
        header += "\n"

        body = n["content"]

        if status == "errored":
            body = f'<span style="color:#dc2626; text-decoration:line-through;">{body}</span>'

        if self.current_search:
            pattern = re.escape(self.current_search)
            body = re.sub(
                pattern,
                r'<span style="background-color:#CCE5FF; color:#003366;">\g<0></span>',
                body,
                flags=re.IGNORECASE
            )

        if self.extraction_highlight_terms:
            sorted_terms = sorted(self.extraction_highlight_terms, key=len, reverse=True)
            ext_pattern = "|".join(re.escape(t) for t in sorted_terms)
            body = re.sub(
                ext_pattern,
                r'<span style="background-color:#FFEB3B; color:#333;">\g<0></span>',
                body,
                flags=re.IGNORECASE
            )

        # Make detail editable only if note is in editing state
        is_editing = is_entry and status == "editing"
        self.txt_detail.setReadOnly(not is_editing)

        self.txt_detail.setHtml(header.replace("\n", "<br>") + body.replace("\n", "<br>"))

        # Show/hide action buttons
        if is_entry and status not in ("errored",):
            self._action_bar.show()
            self.btn_confirm.setVisible(status in ("draft", "editing"))
            self.btn_edit.setVisible(status == "draft")
            self.btn_error.setVisible(status in ("draft", "editing", "confirmed"))
        else:
            self._action_bar.hide()

        # Flash the detail panel to indicate selection
        self._flash_detail_panel()

    def _flash_detail_panel(self):
        """Flash the detail panel with a brief highlight effect."""
        # Apply cached highlight style (avoids stylesheet recompilation)
        self.detail_panel.setStyleSheet(self._FLASH_STYLE)
        # Revert after a short delay
        QTimer.singleShot(150, self._reset_detail_panel_style)

    def _reset_detail_panel_style(self):
        """Reset detail panel to normal style."""
        self.detail_panel.setStyleSheet(self._detail_panel_base_style)

    # ==================================================================
    # PATIENT CHANGE HANDLER
    # ==================================================================

    def _on_patient_changed(self, pid):
        """Reload persisted notes_entry notes when patient switches."""
        # Remove old notes_entry notes from all_notes
        self.all_notes = [n for n in self.all_notes if n.get("source") != "notes_entry"]
        self._entry_notes_loaded = False
        # Load saved entry notes for this patient
        self._load_entry_notes_from_db()

    # ==================================================================
    # NOTES ENTRY — PERSISTENCE
    # ==================================================================

    def _load_entry_notes_from_db(self):
        """Merge persisted notes_entry notes into all_notes from DB (per patient)."""
        if not self.db or self._entry_notes_loaded:
            return
        # Only load if a patient is actually selected
        store = get_shared_store()
        pid = store.current_patient_id
        if not pid and not (store.patient_info.get("name") or "").strip():
            return
        if not pid:
            return
        try:
            from datetime import datetime as _dt

            data = self.db.get_json_data(pid, "notes_entry_notes")
            if not data:
                return

            added = 0
            for rec in data:
                # Deserialise dates
                for key in ("date", "edit_deadline"):
                    val = rec.get(key)
                    if val and isinstance(val, str):
                        try:
                            rec[key] = _dt.fromisoformat(val)
                        except Exception:
                            if key == "edit_deadline":
                                rec[key] = None
                # Deduplicate against what's already in all_notes
                already = any(
                    n.get("source") == "notes_entry"
                    and n.get("content") == rec.get("content")
                    and str(n.get("date")) == str(rec.get("date"))
                    for n in self.all_notes
                )
                if not already:
                    self.all_notes.append(rec)
                    added += 1

            self._entry_notes_loaded = True
            if added:
                self.all_notes.sort(
                    key=lambda n: n.get("date") or _dt.min, reverse=True
                )
                self._rebuild_type_filter()
                self.filter_types()
                print(f"[NotesPanel] Loaded {added} entry notes from DB")
        except Exception as e:
            print(f"[NotesPanel] Load entry notes error: {e}")

    def _persist_entry_notes(self):
        """Save all notes_entry notes to DB (per patient)."""
        if not self.db:
            return
        store = get_shared_store()
        pid = store.current_patient_id
        if not pid:
            return
        try:
            from datetime import datetime as _dt, date as _d
            entry_notes = [n for n in self.all_notes if n.get("source") == "notes_entry"]
            serialisable = []
            for n in entry_notes:
                rec = dict(n)
                for key in ("date", "edit_deadline"):
                    val = rec.get(key)
                    if isinstance(val, (_dt, _d)):
                        rec[key] = val.isoformat()
                serialisable.append(rec)
            self.db.save_json_data(pid, "notes_entry_notes", serialisable)
        except Exception as e:
            print(f"[NotesPanel] Persist entry notes error: {e}")

    # ==================================================================
    # NOTES ENTRY — ACTION HANDLERS
    # ==================================================================

    def _get_selected_note(self):
        """Return the currently selected note dict, or None."""
        rows = self.table.selectionModel().selectedRows()
        if not rows:
            return None
        row = rows[0].row()
        if row >= len(self.filtered_notes):
            return None
        return self.filtered_notes[row]

    def _check_edit_deadline(self, n):
        """Auto-lock an editing note if its 30-day deadline has passed."""
        if n.get("status") == "editing" and n.get("edit_deadline"):
            if datetime.now() >= n["edit_deadline"]:
                n["status"] = "confirmed"
                n["edit_deadline"] = None

    def _on_confirm_note(self):
        n = self._get_selected_note()
        if not n or n.get("source") != "notes_entry":
            return

        # If in editing mode, save the current detail text back to the note
        if n.get("status") == "editing":
            new_content = self.txt_detail.toPlainText()
            # Strip the header lines (Date/Type/Originator/Status + blank)
            lines = new_content.split("\n")
            body_start = 0
            for i, line in enumerate(lines):
                if line.startswith("Status:") or line.startswith("Originator:"):
                    body_start = i + 1
            # Skip blank line after header
            if body_start < len(lines) and not lines[body_start].strip():
                body_start += 1
            body = "\n".join(lines[body_start:]).strip()
            if body:
                n["content"] = body
                preview = " ".join(body.split("\n")[:3]).strip()
                n["preview"] = preview[:197] + "..." if len(preview) > 200 else preview

        n["status"] = "confirmed"
        n["edit_deadline"] = None
        self.txt_detail.setReadOnly(True)
        self.refresh_table(preserve_selection=n)
        self.on_select()
        self._persist_entry_notes()

    def _on_edit_note(self):
        n = self._get_selected_note()
        if not n or n.get("source") != "notes_entry":
            return
        if n.get("status") not in ("draft",):
            return

        from datetime import timedelta
        n["status"] = "editing"
        n["edit_deadline"] = datetime.now() + timedelta(days=30)
        self.refresh_table(preserve_selection=n)
        self.on_select()

        # Open notes entry panel pre-filled for editing
        self.edit_note_requested.emit(n)

    def _on_error_note(self):
        n = self._get_selected_note()
        if not n or n.get("source") != "notes_entry":
            return

        from PySide6.QtWidgets import QDialog, QVBoxLayout, QLabel, QComboBox, QTextEdit, QPushButton
        dlg = QDialog(self)
        dlg.setWindowTitle("Mark Note as Error")
        dlg.setMinimumWidth(380)
        lay = QVBoxLayout(dlg)

        lay.addWidget(QLabel("Select a reason:"))
        combo = QComboBox()
        reasons = [
            "Wrong patient",
            "Incorrect information",
            "Duplicate entry",
            "Wrong date/time",
            "Entered in error",
            "Other",
        ]
        combo.addItems(reasons)
        lay.addWidget(combo)

        other_lbl = QLabel("Please specify:")
        other_box = QTextEdit()
        other_box.setMaximumHeight(80)
        other_lbl.hide()
        other_box.hide()
        combo.currentTextChanged.connect(lambda t: (other_lbl.setVisible(t == "Other"), other_box.setVisible(t == "Other")))
        lay.addWidget(other_lbl)
        lay.addWidget(other_box)

        send_btn = QPushButton("Submit")
        send_btn.setStyleSheet(
            "background: #dc2626; color: white; border: none; border-radius: 5px; "
            "font-size: 13px; font-weight: 600; padding: 6px 20px;"
        )
        send_btn.clicked.connect(dlg.accept)
        lay.addWidget(send_btn)

        if dlg.exec() != QDialog.Accepted:
            return

        reason = combo.currentText()
        if reason == "Other":
            reason = other_box.toPlainText().strip()
            if not reason:
                return

        # Prepend error reason to note content
        error_header = f"[ERROR — {reason}]\n\n"
        n["content"] = error_header + n["content"]
        preview = n["content"][:197] + "..." if len(n["content"]) > 200 else n["content"]
        n["preview"] = preview

        n["status"] = "errored"
        n["error_reason"] = reason
        n["edit_deadline"] = None
        self.txt_detail.setReadOnly(True)
        self.refresh_table(preserve_selection=n)
        self.on_select()
        self._persist_entry_notes()

    # ==================================================================
    # TIMELINE JUMP
    # ==================================================================
    def jump_to_date(self, target_dt):
        if isinstance(target_dt, date) and not isinstance(target_dt, datetime):
            target_dt = datetime.combine(target_dt, time.min)

        indexed = []
        for row, n in enumerate(self.filtered_notes):
            nd = n.get("date")
            if nd is None:
                continue
            if isinstance(nd, date) and not isinstance(nd, datetime):
                nd = datetime.combine(nd, time.min)
            indexed.append((row, nd))

        if not indexed:
            return

        indexed.sort(key=lambda x: x[1])

        target_row = None
        for row_idx, nd in indexed:
            if nd >= target_dt:
                target_row = row_idx
                break

        if target_row is None:
            target_row = indexed[-1][0]

        self.table.selectRow(target_row)
        idx = self.table.model().index(target_row, 0)
        self.table.scrollTo(idx, QAbstractItemView.PositionAtCenter)
        self.on_select()

    def jump_to_note(self, target_dt, content_snippet: str = None):
        """Jump to a specific note by date and optional content snippet.

        Args:
            target_dt: The date of the note
            content_snippet: A text snippet that should appear in the note content
                           (used to identify the exact note when multiple notes share a date)
        """
        if isinstance(target_dt, date) and not isinstance(target_dt, datetime):
            target_dt = datetime.combine(target_dt, time.min)

        # If no content snippet, fall back to date-only search
        if not content_snippet:
            return self.jump_to_date(target_dt)

        content_snippet_lower = content_snippet.lower()

        # First pass: find notes on the exact date that contain the snippet
        best_match = None
        for row, n in enumerate(self.filtered_notes):
            nd = n.get("date")
            if nd is None:
                continue
            if isinstance(nd, date) and not isinstance(nd, datetime):
                nd = datetime.combine(nd, time.min)

            # Check if date matches (same day)
            if nd.date() == target_dt.date() if hasattr(target_dt, 'date') else nd.date() == target_dt:
                # Check if content contains the snippet
                note_content = (n.get("content") or n.get("text") or "").lower()
                if content_snippet_lower in note_content:
                    best_match = row
                    break  # Found exact match

        # If no match on exact date with content, try date-only
        if best_match is None:
            return self.jump_to_date(target_dt)

        self.table.selectRow(best_match)
        idx = self.table.model().index(best_match, 0)
        self.table.scrollTo(idx, QAbstractItemView.PositionAtCenter)
        self.on_select()

    # ==================================================================
    # HIGHLIGHT TEXT
    # ==================================================================
    def highlight_text(self, text):
        """Set search term to highlight in the note display."""
        if text:
            self.current_search = text.lower()
            self.on_select()  # Refresh display with highlighting

    # ==================================================================
    # HEADER CLICK - DATE PICKER
    # ==================================================================
    def _on_header_clicked(self, logical_index):
        """Handle header click - show date picker for Date column."""
        if logical_index != 0:  # Only Date column (index 0)
            return

        if not self.all_notes:
            return

        # Get date range from notes
        dates = []
        for n in self.all_notes:
            dt = n.get("date")
            if dt is not None:
                try:
                    if isinstance(dt, datetime):
                        dates.append(dt.date())
                    elif isinstance(dt, date):
                        dates.append(dt)
                except Exception:
                    pass

        if not dates:
            return

        min_date = min(dates)
        max_date = max(dates)

        # Show date picker dialog
        self._show_date_picker(min_date, max_date)

    def _show_date_picker(self, min_date, max_date):
        """Show a calendar dialog to pick a date."""
        from PySide6.QtCore import QDate

        dialog = QDialog(self)
        dialog.setWindowTitle("Jump to Date")
        dialog.setFixedSize(320, 300)

        layout = QVBoxLayout(dialog)

        # Calendar widget
        calendar = QCalendarWidget()
        calendar.setMinimumDate(QDate(min_date.year, min_date.month, min_date.day))
        calendar.setMaximumDate(QDate(max_date.year, max_date.month, max_date.day))
        calendar.setGridVisible(True)
        calendar.setStyleSheet("""
            QCalendarWidget {
                background: white;
            }
            QCalendarWidget QToolButton {
                color: #333;
                background: rgba(240, 242, 245, 0.9);
                border: 1px solid #c0c5ca;
                border-radius: 4px;
                padding: 4px 8px;
            }
            QCalendarWidget QToolButton:hover {
                background: rgba(58, 122, 254, 0.2);
            }
            QCalendarWidget QMenu {
                background: white;
                color: #333;
            }
            QCalendarWidget QSpinBox {
                background: white;
                border: 1px solid #c0c5ca;
                border-radius: 4px;
                color: #333;
            }
            QCalendarWidget QTableView {
                background: white;
                selection-background-color: #3a7afe;
                selection-color: white;
            }
            QCalendarWidget QTableView QTableCornerButton::section {
                background: white;
            }
            QCalendarWidget QAbstractItemView:enabled {
                background: white;
                color: #333;
            }
            QCalendarWidget QAbstractItemView:disabled {
                color: #aaa;
            }
            QCalendarWidget QWidget#qt_calendar_navigationbar {
                background: rgba(240, 242, 245, 0.95);
            }
        """)
        layout.addWidget(calendar)

        # Buttons
        buttons = QDialogButtonBox(QDialogButtonBox.Ok | QDialogButtonBox.Cancel)
        buttons.accepted.connect(dialog.accept)
        buttons.rejected.connect(dialog.reject)
        layout.addWidget(buttons)

        # Double-click on date also accepts
        calendar.activated.connect(dialog.accept)

        if dialog.exec() == QDialog.Accepted:
            selected = calendar.selectedDate()
            target_date = date(selected.year(), selected.month(), selected.day())
            self._jump_to_nearest_note(target_date)

    def _jump_to_nearest_note(self, target_date):
        """Find and select the note nearest to the target date."""
        if not self.filtered_notes:
            return

        # Build list of (row, date, delta) for filtered notes
        candidates = []
        for row, n in enumerate(self.filtered_notes):
            dt = n.get("date")
            if dt is None:
                continue
            try:
                if isinstance(dt, datetime):
                    note_date = dt.date()
                elif isinstance(dt, date):
                    note_date = dt
                else:
                    continue

                delta = abs((note_date - target_date).days)
                candidates.append((row, note_date, delta))
            except Exception:
                pass

        if not candidates:
            return

        # Sort by delta (nearest first), then by date (earliest first for ties)
        candidates.sort(key=lambda x: (x[2], x[1]))

        # Select the nearest (first in sorted list)
        target_row = candidates[0][0]

        self.table.selectRow(target_row)
        idx = self.table.model().index(target_row, 0)
        self.table.scrollTo(idx, QAbstractItemView.PositionAtCenter)
        self.on_select()
