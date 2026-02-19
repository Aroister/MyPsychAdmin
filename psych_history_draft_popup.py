from __future__ import annotations

from PySide6.QtCore import Qt, QPoint, Signal, QTimer
from PySide6.QtWidgets import (
    QWidget, QLabel, QPushButton,
    QVBoxLayout, QHBoxLayout, QTextEdit,
    QFileDialog, QMessageBox, QCheckBox
)

from psych_history_draft import (
    extract_psych_history_from_text,
    generate_psych_history_draft,
)

# Reuse EXACT importers you actually have
from importer_pdf import import_pdf_notes
from importer_docx import import_docx_notes
from importer_rio import parse_rio_file
from importer_carenotes import parse_carenotes_file

# Timeline logic only (NO UI)
from timeline_builder import build_timeline
from spell_check_textedit import enable_spell_check_on_textedit


# ============================================================
# Helpers
# ============================================================

def extract_past_psych_from_notes(notes: list[dict]) -> str:
    """
    Extracts psychiatric history from notes
    that predate the most recent admission.
    """
    if not notes:
        return ""

    # Sort by date
    notes = sorted(
        [n for n in notes if n.get("date")],
        key=lambda n: n["date"]
    )

    # Heuristic: last 30–45 days = current episode
    from datetime import timedelta
    cutoff = notes[-1]["date"] - timedelta(days=45)

    historical_notes = [
        n for n in notes
        if n["date"] < cutoff
    ]

    text = "\n".join(n.get("text", "") for n in historical_notes)
    return extract_psych_history_from_text(text)


# ============================================================
# Popup
# ============================================================

class PsychHistoryDraftPopup(QWidget):
    drafted = Signal(str)

    def __init__(self, parent=None, anchor=None):
        super().__init__(parent)

        self.anchor = anchor
        self._drag_offset = None

        self.setWindowFlags(Qt.FramelessWindowHint | Qt.SubWindow)
        self.setMinimumSize(560, 400)

        # ----------------------------------------------------
        # Root
        # ----------------------------------------------------
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)

        container = QWidget()
        container.setStyleSheet("""
            QWidget {
                background: rgba(255,255,255,0.55);
                border-radius: 18px;
                border: 1px solid rgba(0,0,0,0.25);
            }
            QLabel { color:#003c32; border: none; }
        """)
        outer.addWidget(container)

        lay = QVBoxLayout(container)
        lay.setContentsMargins(20, 20, 20, 20)
        lay.setSpacing(10)

        # ----------------------------------------------------
        # Header
        # ----------------------------------------------------
        header = QHBoxLayout()
        title = QLabel("Draft Psychiatric History")
        title.setStyleSheet("font-size:18px; font-weight:700;")
        header.addWidget(title)
        header.addStretch()

        close_btn = QPushButton("×")
        close_btn.setFixedSize(30, 26)
        close_btn.clicked.connect(self.close)
        header.addWidget(close_btn)
        lay.addLayout(header)

        # ----------------------------------------------------
        # Options
        # ----------------------------------------------------
        self.admissions_only = QCheckBox("Use admissions only (recommended)")
        self.admissions_only.setChecked(True)
        lay.addWidget(self.admissions_only)

        # ----------------------------------------------------
        # Text box
        # ----------------------------------------------------
        self.text = QTextEdit()
        self.text.setPlaceholderText(
            "Paste text here or import documents.\n\n"
            "Only psychiatric history will be used."
        )
        enable_spell_check_on_textedit(self.text)
        lay.addWidget(self.text, 1)

        # ----------------------------------------------------
        # Buttons
        # ----------------------------------------------------
        btns = QHBoxLayout()

        from PySide6.QtWidgets import QToolButton, QMenu
        from shared_data_store import get_shared_store
        import_btn = QToolButton()
        import_btn.setText("Uploaded Docs")
        import_btn.setPopupMode(QToolButton.InstantPopup)
        self._upload_menu = QMenu()
        import_btn.setMenu(self._upload_menu)
        import_btn.setStyleSheet("QToolButton { padding: 6px 12px; } QToolButton::menu-indicator { image: none; }")
        self._shared_store = get_shared_store()
        self._shared_store.uploaded_documents_changed.connect(self._refresh_upload_menu)
        self._refresh_upload_menu(self._shared_store.get_uploaded_documents())
        btns.addWidget(import_btn)

        btns.addStretch()

        cancel = QPushButton("Cancel")
        cancel.clicked.connect(self.close)

        generate = QPushButton("Generate draft")
        generate.setStyleSheet("""
            QPushButton {
                background:#008C7E;
                color:white;
                padding:8px 16px;
                border-radius:6px;
            }
        """)
        generate.clicked.connect(self._generate)

        btns.addWidget(cancel)
        btns.addWidget(generate)
        lay.addLayout(btns)

        QTimer.singleShot(0, self._position_popup)

    # ----------------------------------------------------
    # Import
    # ----------------------------------------------------
    def _refresh_upload_menu(self, docs=None):
        """Rebuild the Uploaded Docs dropdown menu from SharedDataStore."""
        self._upload_menu.clear()
        if docs is None:
            from shared_data_store import get_shared_store
            docs = get_shared_store().get_uploaded_documents()
        if not docs:
            action = self._upload_menu.addAction("No documents uploaded")
            action.setEnabled(False)
        else:
            for doc in docs:
                path = doc["path"]
                action = self._upload_menu.addAction(doc["filename"])
                action.triggered.connect(lambda checked=False, p=path: self._import_document(p))

    def _import_document(self, path):

        try:
            raw_text = ""

            if path.lower().endswith(".pdf"):
                notes = import_pdf_notes(path)
                raw_text = "\n".join(n.get("text", "") for n in notes)

            elif path.lower().endswith(".docx"):
                notes = import_docx_notes(path)
                raw_text = "\n".join(n.get("text", "") for n in notes)

            elif path.lower().endswith((".xlsx", ".xls")):
                try:
                    notes = parse_rio_file(path)
                except Exception:
                    notes = parse_carenotes_file(path)

                raw_text = "\n".join(n.get("text", "") for n in notes)

            else:
                with open(path, "r", encoding="utf-8", errors="ignore") as f:
                    raw_text = f.read()

            # Extract past psychiatric history from older notes
            extracted = extract_past_psych_from_notes(notes)

            if not extracted:
                QMessageBox.information(
                    self,
                    "No psychiatric history found",
                    "No psychiatric history could be extracted."
                )
                return

            self.text.setPlainText(extracted)

        except Exception as e:
            QMessageBox.critical(self, "Import failed", str(e))

    # ----------------------------------------------------
    # Generate draft
    # ----------------------------------------------------
    def _generate(self):
        draft = generate_psych_history_draft(self.text.toPlainText())
        if draft:
            self.drafted.emit(draft)
        self.close()

    # ----------------------------------------------------
    # Positioning
    # ----------------------------------------------------
    def _position_popup(self):
        if self.anchor:
            p = self.anchor.mapToGlobal(QPoint(0, 0))
            self.move(p.x() + 280, p.y() - 40)
        elif self.parent():
            geo = self.parent().geometry()
            self.move(
                geo.center().x() - self.width() // 2,
                geo.center().y() - self.height() // 2
            )

    # ----------------------------------------------------
    # Dragging
    # ----------------------------------------------------
    def mousePressEvent(self, e):
        if e.button() == Qt.LeftButton:
            self._drag_offset = e.globalPos() - self.frameGeometry().topLeft()

    def mouseMoveEvent(self, e):
        if e.buttons() & Qt.LeftButton and self._drag_offset:
            self.move(e.globalPos() - self._drag_offset)

    def mouseReleaseEvent(self, e):
        self._drag_offset = None
