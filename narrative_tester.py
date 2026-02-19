"""
Narrative Generation Testing Platform

A standalone tool for testing and refining the progress narrative generation code.
This narrative is used across multiple reports:
- ASR Section 8 (Progress)
- Leave Application Section 4d
- Psychiatric Tribunal Report Section 14
- Nursing Report Section 9
- Social Circumstances Section 16
- General Psych Report Section 3

Usage:
    python3 narrative_tester.py
"""

import sys
import json
import re
import pickle
from datetime import datetime, timedelta
from collections import defaultdict
from pathlib import Path

# Cache file for storing notes between sessions
NOTES_CACHE_FILE = Path(__file__).parent / ".narrative_tester_cache.pkl"

from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
    QLabel, QPushButton, QTextBrowser, QTextEdit, QScrollArea,
    QFrame, QSplitter, QFileDialog, QRadioButton, QButtonGroup,
    QSizePolicy, QMessageBox, QCheckBox
)
from PySide6.QtCore import Qt, Signal, QUrl, QTimer
from PySide6.QtGui import QFont, QTextCharFormat, QColor, QTextCursor


class NarrativeTester(QMainWindow):
    """Testing platform for narrative generation - matches tribunal Section 14 style."""

    def __init__(self):
        super().__init__()
        self.setWindowTitle("Narrative Generation Tester")
        self.setMinimumSize(600, 400)  # Allow much smaller window
        self.resize(1400, 900)  # Default size but resizable

        self.entries = []
        self.prepared_entries = []
        self.narrative_text = ""
        self.narrative_html = ""

        # Entry tracking (same as tribunal popup)
        self._entry_frames = {}  # Map date_key -> entry_frame
        self._entry_body_texts = {}  # Map date_key -> (body_text, toggle_btn, content)
        self._entry_checkboxes = {}  # Map date_key -> checkbox
        self._entry_feedback = {}  # Map date_key -> feedback_edit
        self._current_filter_keyword = ""  # Track what keyword we're filtering on
        self._current_narrative_line = ""  # The full narrative line that was clicked

        self._setup_ui()

        # Auto-load cached notes on startup
        QTimer.singleShot(100, self._load_cached_notes)

    def _setup_ui(self):
        central = QWidget()
        self.setCentralWidget(central)

        main_layout = QVBoxLayout(central)
        main_layout.setContentsMargins(16, 16, 16, 16)
        main_layout.setSpacing(12)

        # Header
        header = QLabel("Narrative Generation Tester")
        header.setStyleSheet("font-size: 24px; font-weight: bold; color: #1f2937;")
        main_layout.addWidget(header)

        subtitle = QLabel("Reports: ASR §8, Leave App §4d, Psych Tribunal §14, Nursing §9, Social §16, Gen Psych §3")
        subtitle.setStyleSheet("font-size: 13px; color: #6b7280;")
        main_layout.addWidget(subtitle)

        # Single Import Button
        toolbar = QFrame()
        toolbar.setStyleSheet("QFrame { background: #f3f4f6; border-radius: 8px; }")
        toolbar_layout = QHBoxLayout(toolbar)
        toolbar_layout.setContentsMargins(12, 8, 12, 8)

        import_btn = QPushButton("Import Files & Generate Narrative")
        import_btn.setStyleSheet("""
            QPushButton {
                background: #3b82f6;
                color: white;
                border: none;
                padding: 12px 24px;
                border-radius: 6px;
                font-weight: bold;
                font-size: 14px;
            }
            QPushButton:hover { background: #2563eb; }
        """)
        import_btn.clicked.connect(self._import_and_generate)
        toolbar_layout.addWidget(import_btn)

        toolbar_layout.addWidget(QLabel("|"))

        self.stats_label = QLabel("No data loaded")
        self.stats_label.setStyleSheet("color: #6b7280; font-size: 13px;")
        toolbar_layout.addWidget(self.stats_label)

        toolbar_layout.addStretch()

        main_layout.addWidget(toolbar)

        # Main content splitter with visible drag handle
        splitter = QSplitter(Qt.Orientation.Horizontal)
        splitter.setHandleWidth(8)  # Wider handle for easier grabbing
        splitter.setStyleSheet("""
            QSplitter::handle {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #e5e7eb, stop:0.5 #9ca3af, stop:1 #e5e7eb);
                border-radius: 4px;
                margin: 2px 0px;
            }
            QSplitter::handle:hover {
                background: qlineargradient(x1:0, y1:0, x2:1, y2:0,
                    stop:0 #d1d5db, stop:0.5 #6b7280, stop:1 #d1d5db);
            }
            QSplitter::handle:pressed {
                background: #3b82f6;
            }
        """)

        # Left panel: Narrative display
        left_panel = QFrame()
        left_panel.setStyleSheet("QFrame { background: white; border: 1px solid #e5e7eb; border-radius: 8px; }")
        left_layout = QVBoxLayout(left_panel)
        left_layout.setContentsMargins(12, 12, 12, 12)

        narrative_header = QLabel("Generated Narrative (Click references to see source notes)")
        narrative_header.setStyleSheet("font-size: 16px; font-weight: bold; color: #1f2937;")
        left_layout.addWidget(narrative_header)

        self.narrative_browser = QTextBrowser()
        self.narrative_browser.setOpenExternalLinks(False)
        self.narrative_browser.setOpenLinks(False)
        self.narrative_browser.anchorClicked.connect(self._on_link_clicked)
        self.narrative_browser.setStyleSheet("""
            QTextBrowser {
                border: 1px solid #e5e7eb;
                border-radius: 6px;
                padding: 12px;
                font-size: 14px;
                line-height: 1.6;
            }
        """)
        left_layout.addWidget(self.narrative_browser)

        splitter.addWidget(left_panel)

        # Right panel: Source notes (collapsible entries like tribunal)
        right_panel = QFrame()
        right_panel.setStyleSheet("QFrame { background: #fffbeb; border: 1px solid #f59e0b; border-radius: 8px; }")
        right_layout = QVBoxLayout(right_panel)
        right_layout.setContentsMargins(12, 12, 12, 12)

        self.source_header = QLabel("Source Notes (Imported Data)")
        self.source_header.setStyleSheet("font-size: 16px; font-weight: bold; color: #92400e;")
        right_layout.addWidget(self.source_header)

        # Filter info and remove filter button
        filter_row = QHBoxLayout()

        self.source_info = QLabel("Click a highlighted reference in the narrative to filter matching notes")
        self.source_info.setStyleSheet("color: #78716c; font-style: italic;")
        self.source_info.setWordWrap(True)
        filter_row.addWidget(self.source_info, 1)

        self.remove_filter_btn = QPushButton("Remove Filter")
        self.remove_filter_btn.setStyleSheet("""
            QPushButton {
                background: #ef4444;
                color: white;
                border: none;
                padding: 6px 12px;
                border-radius: 4px;
                font-weight: bold;
                font-size: 12px;
            }
            QPushButton:hover { background: #dc2626; }
        """)
        self.remove_filter_btn.clicked.connect(self._remove_filter)
        self.remove_filter_btn.setVisible(False)
        filter_row.addWidget(self.remove_filter_btn)

        self.submit_feedback_btn = QPushButton("Submit Issues")
        self.submit_feedback_btn.setStyleSheet("""
            QPushButton {
                background: #8b5cf6;
                color: white;
                border: none;
                padding: 6px 12px;
                border-radius: 4px;
                font-weight: bold;
                font-size: 12px;
            }
            QPushButton:hover { background: #7c3aed; }
        """)
        self.submit_feedback_btn.clicked.connect(self._submit_feedback)
        self.submit_feedback_btn.setVisible(False)
        filter_row.addWidget(self.submit_feedback_btn)

        right_layout.addLayout(filter_row)

        # Scroll area for collapsible entries
        self.entries_scroll = QScrollArea()
        self.entries_scroll.setWidgetResizable(True)
        self.entries_scroll.setStyleSheet("QScrollArea { border: none; background: transparent; }")

        self.entries_container = QWidget()
        self.entries_layout = QVBoxLayout(self.entries_container)
        self.entries_layout.setContentsMargins(0, 0, 0, 0)
        self.entries_layout.setSpacing(6)
        self.entries_layout.addStretch()

        self.entries_scroll.setWidget(self.entries_container)
        right_layout.addWidget(self.entries_scroll)

        splitter.addWidget(right_panel)

        # Set splitter sizes (55% left, 45% right)
        splitter.setSizes([770, 630])

        main_layout.addWidget(splitter, 1)

    def _detect_notes_source(self, entries):
        """Detect source system from note content patterns."""
        # Sample first 50 entries to detect source
        sample = entries[:50] if len(entries) > 50 else entries
        carenotes_patterns = 0
        rio_patterns = 0

        for e in sample:
            content = str(e.get('content', '') or e.get('text', '')).lower()
            originator = str(e.get('originator', '')).lower()
            note_type = str(e.get('type', '')).lower()

            # CareNotes patterns
            if any(p in content for p in ['title:', 'main patient details:', 'keeping well:', 'keeping safe:']):
                carenotes_patterns += 1
            if ' - ' in originator and any(p in note_type for p in ['nursing day', 'nursing night', 'psychology 1:1']):
                carenotes_patterns += 1

            # RIO patterns
            if any(p in content for p in ['rio reference:', 'progress note', 'care coordinator']):
                rio_patterns += 1

        if carenotes_patterns > rio_patterns and carenotes_patterns > 5:
            return 'carenotes'
        elif rio_patterns > carenotes_patterns and rio_patterns > 5:
            return 'rio'
        return ''

    def _load_cached_notes(self):
        """Load notes from cache file if it exists."""
        if NOTES_CACHE_FILE.exists():
            try:
                with open(NOTES_CACHE_FILE, 'rb') as f:
                    cached_data = pickle.load(f)
                self.entries = cached_data.get('entries', [])
                if self.entries:
                    print(f"[NarrativeTester] Loaded {len(self.entries)} notes from cache")

                    # Detect and apply source if missing
                    sources = set(str(e.get('source', '')).strip() for e in self.entries)
                    if sources == {''} or sources == set():
                        detected_source = self._detect_notes_source(self.entries)
                        if detected_source:
                            print(f"[NarrativeTester] Detected source: {detected_source}")
                            for e in self.entries:
                                e['source'] = detected_source

                    # Push to shared store
                    from shared_data_store import get_shared_store
                    shared_store = get_shared_store()
                    shared_store.set_notes(self.entries, source="narrative_tester")
                    # Update stats
                    self.stats_label.setText(f"{len(self.entries)} notes loaded (from cache)")
                    # Generate narrative and populate entries
                    self._generate_narrative()
                    self._populate_entries()
            except Exception as e:
                print(f"[NarrativeTester] Failed to load cache: {e}")

    def _save_notes_cache(self):
        """Save notes to cache file."""
        try:
            with open(NOTES_CACHE_FILE, 'wb') as f:
                pickle.dump({'entries': self.entries}, f)
            print(f"[NarrativeTester] Saved {len(self.entries)} notes to cache")
        except Exception as e:
            print(f"[NarrativeTester] Failed to save cache: {e}")

    def _import_and_generate(self):
        """Import files and immediately generate narrative."""
        from importer_pdf import import_pdf_notes
        from importer_docx import import_docx_notes

        files, _ = QFileDialog.getOpenFileNames(
            self, "Select files", "",
            "All Supported (*.pdf *.xlsx *.xls *.docx);;All files (*)"
        )
        if not files:
            return

        raw = []
        for f in files:
            fl = f.lower()
            if fl.endswith(".pdf"):
                raw.extend(import_pdf_notes([f]))
            elif fl.endswith(".docx"):
                raw.extend(import_docx_notes([f], "auto"))
            elif fl.endswith(".xlsx") or fl.endswith(".xls"):
                from importer_autodetect import import_files_autodetect
                raw.extend(import_files_autodetect([f]))

        print(f"[NarrativeTester] Imported {len(raw)} raw notes")

        # Clean notes
        self.entries = self._clean_notes(raw)

        # Push to shared store
        from shared_data_store import get_shared_store
        shared_store = get_shared_store()
        shared_store.set_notes(self.entries, source="narrative_tester")

        # Update stats
        self.stats_label.setText(f"{len(self.entries)} notes loaded")

        # Save to cache for next session
        self._save_notes_cache()

        # Generate narrative and populate entries
        self._generate_narrative()
        self._populate_entries()

    def _clean_notes(self, raw):
        """Clean imported notes - same as patient_notes_panel."""
        cleaned = []
        for n in raw:
            dt = n.get("date")
            content = n.get("content") or n.get("text") or n.get("body") or n.get("note") or ""
            content = str(content)

            cleaned.append({
                "date": dt,
                "datetime": dt,
                "type": str(n.get("type", "")).strip(),
                "originator": str(n.get("originator", "")).strip(),
                "content": content,
                "text": content,
                "source": str(n.get("source", "")).lower()
            })
        return cleaned

    def _extract_patient_demographics(self, entries):
        """Extract patient demographics from notes content."""
        import re
        from datetime import datetime
        from collections import Counter

        demographics = {
            'name': None,
            'dob': None,
            'gender': None,
            'ethnicity': None,
            'diagnosis': []
        }

        # Combine all text for searching - use all entries for demographic extraction
        # Age/DOB info often appears in admission notes at start or end of record
        all_text = "\n".join([e.get('text', '') or e.get('content', '') for e in entries])
        all_text_lower = all_text.lower()

        # Words that should NOT start a patient name
        invalid_name_starts = {
            'at', 'dr', 'the', 'a', 'an', 'to', 'from', 'by', 'with', 'for', 'on', 'in',
            'nurse', 'doctor', 'staff', 'consultant', 'registrar', 'ward', 'unit',
            'team', 'service', 'hospital', 'clinic', 'department', 'section',
            'mr', 'mrs', 'ms', 'miss', 'prof', 'professor',  # titles without names
            'no', 'not', 'other', 'regarding', 'garding',
        }

        # Staff role indicators - if these appear before/after a name, it's likely staff
        staff_indicators = [
            'dr', 'doctor', 'nurse', 'consultant', 'registrar', 'sho', 'fy1', 'fy2',
            'st1', 'st2', 'st3', 'ct1', 'ct2', 'ct3', 'specialist', 'therapist',
            'psychologist', 'psychiatrist', 'social worker', 'ot', 'physio',
            'staff', 'manager', 'coordinator', 'lead', 'team', 'ward',
        ]

        # Words that should NEVER appear in a patient name (anywhere)
        invalid_name_words = {
            'participation', 'action', 'other', 'regarding', 'garding',
            'no', 'not', 'none', 'nil', 'unknown', 'patient', 'client',
            'assessment', 'review', 'report', 'notes', 'entry', 'entries',
            'required', 'needed', 'completed', 'pending', 'outcome',
            'contact', 'follow', 'discharge', 'admission', 'transfer',
            'medication', 'treatment', 'therapy', 'intervention', 'session',
            'appointment', 'meeting', 'tribunal', 'hearing', 'tribunal',
            'progress', 'update', 'summary', 'section', 'status',
            'clinical', 'medical', 'nursing', 'psychology', 'psychiatry',
            'date', 'time', 'day', 'night', 'shift', 'today', 'yesterday',
            'morning', 'afternoon', 'evening', 'weekly', 'daily', 'monthly',
            # Common false positives from note templates
            'brewer', 'group', 'sessions', 'activities', 'activity',
            'leave', 'escorted', 'unescorted', 'ground', 'community',
            'risk', 'level', 'observation', 'observations', 'obs',
            # Prepositions and articles that shouldn't be in names
            'to', 'from', 'for', 'with', 'and', 'the', 'a', 'an', 'of', 'in', 'on', 'at', 'by',
            # More common false positives
            'some', 'emotions', 'their', 'his', 'her', 'presenting', 'problems',
            'service', 'user', 'users', 'led', 'topic', 'topics',
            'understanding', 'areas', 'difficulty', 'experienced',
            'shared', 'members', 'previous', 'whereby', 'followed',
            # Meal/food related words that can appear in clinical notes
            'dinner', 'lunch', 'breakfast', 'snack', 'meal', 'meals',
            'food', 'eating', 'ate', 'drink', 'drinks',
            # Place/building words
            'room', 'office', 'hall', 'area', 'areas', 'corridor',
            'communal', 'lounge', 'garden', 'bedroom', 'bathroom',
            # Common verbs that might be capitalized (sentence starts)
            'was', 'is', 'has', 'had', 'have', 'been', 'being',
            'agreed', 'accepted', 'declined', 'refused', 'attended',
            'presented', 'remains', 'continues', 'continued',
            'spoke', 'discussed', 'stated', 'reported', 'explained',
            'appeared', 'seemed', 'looked', 'felt', 'said',
            'came', 'went', 'left', 'arrived', 'returned',
            'expressed', 'showed', 'displayed', 'demonstrated',
            'exhibited', 'manifested', 'indicated', 'suggested',
            'mentioned', 'noted', 'observed', 'recorded',
            'watts', 'watt',  # Common technical words
        }

        # Also try to find patient name from clinical context patterns
        # Look for: "[Name] was seen", "[Name] agreed to", "[Name] remains", etc.
        def find_patient_first_name_from_context(text):
            """Find patient first name from clinical note patterns."""
            context_patterns = [
                r'\b([A-Z][a-z]+)\s+(?:was|is|has been|has|agreed|accepted|declined|refused|attended|presented|remains|continues)',
                r'\b(?:patient|client)\s+([A-Z][a-z]+)\s+',
                r'\b([A-Z][a-z]+)\s+(?:spoke|discussed|stated|reported|explained)',
            ]
            first_name_counts = Counter()
            text_lower = text.lower()

            for pattern in context_patterns:
                matches = re.findall(pattern, text, re.IGNORECASE)
                for match in matches:
                    name = match.strip()
                    name_lower = name.lower()
                    # Filter out common non-names
                    if name_lower not in invalid_name_words and name_lower not in invalid_name_starts:
                        if len(name) >= 3 and len(name) <= 15:
                            first_name_counts[name] += 1

            if first_name_counts:
                # Return most common first name (must appear 5+ times)
                most_common = first_name_counts.most_common(1)
                if most_common and most_common[0][1] >= 5:
                    return most_common[0][0]
            return None

        def is_valid_patient_name(name):
            """Check if extracted name is likely a patient name, not staff/other."""
            name_lower = name.lower().strip()
            words = name_lower.split()

            if not words:
                return False

            # Check if first word is invalid
            if words[0] in invalid_name_starts:
                return False

            # Check if any word is a staff indicator
            for word in words:
                if word in staff_indicators:
                    return False

            # Check if any word is in the invalid name words list
            for word in words:
                if word in invalid_name_words:
                    return False

            # Name should have 2-4 words typically
            if len(words) < 2 or len(words) > 5:
                return False

            # Each word should be reasonable length
            for word in words:
                if len(word) < 2 or len(word) > 20:
                    return False

            return True

        # Extract name - look for common patterns with validation
        # Priority 1: Look for explicit "Patient Name:" or "Re:" patterns
        name_patterns_priority = [
            # Explicit patient name fields
            r'patient\s*name\s*[:\s]+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)',
            r'client\s*name\s*[:\s]+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)',
            # Re: at start of letters (very reliable)
            r'^re[:\s]+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)',
            r'\nre[:\s]+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)',
            # Name field in structured documents
            r'name[:\s]+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)(?:\s*(?:dob|date|nhs|gender|address))',
        ]

        name_patterns_fallback = [
            # Title + Name (but validate it's not staff)
            r'\b(mr|mrs|ms|miss)\s+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)*)',
            # Generic name field
            r'name[:\s]+([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)',
        ]

        # Try priority patterns first
        for pattern in name_patterns_priority:
            matches = re.findall(pattern, all_text, re.IGNORECASE | re.MULTILINE)
            for match in matches:
                name = match if isinstance(match, str) else match[-1]  # Get last group if tuple
                name = name.strip()
                # Clean up trailing metadata
                name = re.sub(r'\s*(date\s*of\s*birth|dob|nhs|address|gender|ethnicity|born).*', '', name, flags=re.IGNORECASE)
                name = name.strip()
                if is_valid_patient_name(name):
                    demographics['name'] = name.title()
                    break
            if demographics['name']:
                break

        # Fallback patterns if no name found
        if not demographics['name']:
            for pattern in name_patterns_fallback:
                matches = re.findall(pattern, all_text, re.IGNORECASE)
                for match in matches:
                    if isinstance(match, tuple):
                        name = ' '.join(match).strip()
                        # Remove title from name
                        name = re.sub(r'^(mr|mrs|ms|miss)\s+', '', name, flags=re.IGNORECASE)
                    else:
                        name = match.strip()
                    name = re.sub(r'\s*(date\s*of\s*birth|dob|nhs|address|gender|ethnicity).*', '', name, flags=re.IGNORECASE)
                    name = name.strip()
                    if is_valid_patient_name(name):
                        demographics['name'] = name.title()
                        break
                if demographics['name']:
                    break

        # Better fallback: Find patient first name from clinical context patterns
        if not demographics['name']:
            first_name = find_patient_first_name_from_context(all_text)
            if first_name:
                # Just use the first name - surname detection is unreliable
                # The narrative generator will use first name naturally anyway
                demographics['name'] = first_name.title()

        # Absolute last resort: Find most frequently mentioned proper name (2+ words, capitalized)
        if not demographics['name']:
            potential_names = re.findall(r'\b([A-Z][a-z]+\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\b', all_text)
            name_counts = Counter(potential_names)
            for name, count in name_counts.most_common(10):
                if count >= 3 and is_valid_patient_name(name):
                    demographics['name'] = name.title()
                    break

        # Extract DOB
        dob_patterns = [
            r'd\.?o\.?b\.?\s*[:\s]+\s*(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})',
            r'date\s+of\s+birth\s*[:\s]+\s*(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})',
            r'born\s*[:\s]+\s*(\d{1,2}[/\-\.]\d{1,2}[/\-\.]\d{2,4})',
        ]
        for pattern in dob_patterns:
            match = re.search(pattern, all_text, re.IGNORECASE)
            if match:
                dob_str = match.group(1)
                # Parse DOB
                for fmt in ['%d/%m/%Y', '%d-%m-%Y', '%d.%m.%Y', '%d/%m/%y', '%d-%m-%y']:
                    try:
                        demographics['dob'] = datetime.strptime(dob_str, fmt)
                        break
                    except:
                        pass
                if demographics['dob']:
                    break

        # If no DOB found, try to extract age directly from text like "[Name] is a 35-year-old"
        if not demographics.get('dob'):
            age_patterns = [
                r'(?:patient|client|he|she|\b[A-Z][a-z]+)\s+is\s+(?:a\s+)?(\d{1,2})\s*-?\s*year\s*-?\s*old',
                r'(\d{1,2})\s*-?\s*year\s*-?\s*old\s+(?:male|female|man|woman|patient)',
                r'aged?\s+(\d{1,2})\s*(?:years?)?',
                r'age[:\s]+(\d{1,2})\b',
            ]
            for pattern in age_patterns:
                matches = re.findall(pattern, all_text, re.IGNORECASE)
                if matches:
                    # Take most common age if multiple matches
                    from collections import Counter
                    age_counts = Counter(int(m) for m in matches if 18 <= int(m) <= 100)
                    if age_counts:
                        most_common_age = age_counts.most_common(1)[0][0]
                        demographics['age'] = most_common_age
                        break

        # Extract gender - more robust detection
        # Priority 1: Explicit gender fields
        explicit_gender = re.search(r'(?:gender|sex)\s*[:\s]+\s*(male|female|m|f)\b', all_text_lower)
        if explicit_gender:
            g = explicit_gender.group(1).lower()
            demographics['gender'] = 'female' if g in ('female', 'f') else 'male'
        else:
            # Priority 2: Count pronouns in patient-context sentences
            # Look for sentences that clearly refer to the patient
            patient_sentences = []
            for sentence in re.split(r'[.!?\n]', all_text_lower):
                # Sentences likely about the patient
                if any(marker in sentence for marker in ['patient', 'client', 'admitted', 'presented', 'was seen', 'attended', 'reports', 'denies', 'states']):
                    patient_sentences.append(sentence)

            patient_text = ' '.join(patient_sentences) if patient_sentences else all_text_lower

            # Count pronouns (exclude possessive 'her' after certain words that might refer to staff)
            he_count = len(re.findall(r'\b(he|him)\b', patient_text))
            # 'his' can be ambiguous (his medication vs his [staff's] opinion), count carefully
            his_count = len(re.findall(r'\bhis\s+(mental|mood|behaviour|medication|treatment|condition|symptoms|presentation|risk)', patient_text))
            he_count += his_count

            she_count = len(re.findall(r'\b(she)\b', patient_text))
            # 'her' can be ambiguous, count in patient contexts
            her_count = len(re.findall(r'\bher\s+(mental|mood|behaviour|medication|treatment|condition|symptoms|presentation|risk)', patient_text))
            she_count += her_count

            # Also count 'hers' which is unambiguous
            she_count += len(re.findall(r'\bhers\b', patient_text))

            # Need clear majority to determine gender
            total = he_count + she_count
            if total >= 10:  # Need enough data points
                if she_count > he_count * 2:
                    demographics['gender'] = 'female'
                elif he_count > she_count * 2:
                    demographics['gender'] = 'male'

        # Extract ethnicity - ONLY from labeled fields to avoid false positives
        # Do NOT match ethnicity words appearing in general clinical text
        ethnicity_patterns = [
            r'ethnicity\s*[:\-]\s*([A-Za-z\s\-]+?)(?:\.|,|\n|$|\t)',
            r'ethnic\s+(?:group|background|origin|category)\s*[:\-]\s*([A-Za-z\s\-]+?)(?:\.|,|\n|$|\t)',
            r'ethnic\s*code\s*[:\-]\s*([A-Za-z0-9\s\-]+?)(?:\.|,|\n|$|\t)',
        ]
        for pattern in ethnicity_patterns:
            match = re.search(pattern, all_text, re.IGNORECASE)
            if match:
                ethnicity = match.group(1).strip()
                # Clean up ethnicity value
                ethnicity = re.sub(r'\s*(gender|sex|dob|date|address|nhs|ward|hospital).*', '', ethnicity, flags=re.IGNORECASE)
                ethnicity = ethnicity.strip()
                # Validate it's not another field label or placeholder
                if len(ethnicity) > 2 and len(ethnicity) < 50 and not re.match(r'(?:not|unknown|n/?a|date|name)', ethnicity, re.IGNORECASE):
                    demographics['ethnicity'] = ethnicity.title()
                    break

        # Extract diagnoses - only valid ICD-10 psychiatric diagnoses
        valid_diagnoses = {
            # Schizophrenia spectrum (F20-F29)
            'schizophrenia': 'Schizophrenia',
            'paranoid schizophrenia': 'Paranoid Schizophrenia',
            'schizoaffective': 'Schizoaffective Disorder',
            'schizoaffective disorder': 'Schizoaffective Disorder',
            'psychosis': 'Psychosis',
            'psychotic disorder': 'Psychotic Disorder',
            'delusional disorder': 'Delusional Disorder',
            # Mood disorders (F30-F39)
            'bipolar': 'Bipolar Affective Disorder',
            'bipolar disorder': 'Bipolar Affective Disorder',
            'bipolar affective disorder': 'Bipolar Affective Disorder',
            'depression': 'Depression',
            'depressive disorder': 'Depressive Disorder',
            'recurrent depressive disorder': 'Recurrent Depressive Disorder',
            'manic episode': 'Manic Episode',
            # Personality disorders (F60-F69)
            'eupd': 'Emotionally Unstable Personality Disorder',
            'emotionally unstable personality disorder': 'Emotionally Unstable Personality Disorder',
            'emotionally unstable personality': 'Emotionally Unstable Personality Disorder',
            'bpd': 'Borderline Personality Disorder',
            'borderline personality disorder': 'Borderline Personality Disorder',
            'borderline personality': 'Borderline Personality Disorder',
            'antisocial personality disorder': 'Antisocial Personality Disorder',
            'dissocial personality disorder': 'Dissocial Personality Disorder',
            'personality disorder': 'Personality Disorder',
            # Anxiety disorders (F40-F48)
            'ptsd': 'PTSD',
            'post traumatic stress disorder': 'PTSD',
            'post-traumatic stress disorder': 'PTSD',
            'anxiety disorder': 'Anxiety Disorder',
            'generalised anxiety disorder': 'Generalised Anxiety Disorder',
            'ocd': 'OCD',
            'obsessive compulsive disorder': 'OCD',
            # Substance use (F10-F19)
            'substance misuse': 'Substance Misuse',
            'polysubstance misuse': 'Polysubstance Misuse',
            'polysubstance abuse': 'Polysubstance Misuse',
            'drug induced psychosis': 'Drug-Induced Psychosis',
            'alcohol dependency': 'Alcohol Dependency',
            'alcohol dependence': 'Alcohol Dependency',
            'cannabis use disorder': 'Cannabis Use Disorder',
            # Developmental (F70-F79, F84)
            'learning disability': 'Learning Disability',
            'intellectual disability': 'Intellectual Disability',
            'autistic spectrum disorder': 'Autistic Spectrum Disorder',
            'autism': 'Autistic Spectrum Disorder',
            'asd': 'Autistic Spectrum Disorder',
            'adhd': 'ADHD',
            'attention deficit': 'ADHD',
        }

        # Extract diagnoses from formal DIAGNOSIS sections in clinic letters
        # Format: "DIAGNOSIS Her main diagnosis was of [name] - [F-code] and as a secondary diagnosis, [name] - [F-code]"

        diagnosis_with_codes = []  # List of (display_name, f_code, is_primary)

        # ICD-10 F-code to display name mapping
        icd10_display = {
            'f20': 'Schizophrenia', 'f21': 'Schizotypal Disorder', 'f22': 'Delusional Disorder',
            'f23': 'Acute Psychotic Disorder', 'f25': 'Schizoaffective Disorder',
            'f30': 'Manic Episode', 'f31': 'Bipolar Affective Disorder',
            'f32': 'Depression', 'f33': 'Recurrent Depression',
            'f40': 'Phobic Anxiety', 'f41': 'Anxiety Disorder', 'f42': 'OCD',
            'f43': 'PTSD', 'f44': 'Dissociative Disorder',
            'f60': 'Personality Disorder', 'f10': 'Alcohol Dependence',
            'f11': 'Opioid Dependence', 'f12': 'Cannabis Dependence',
            'f14': 'Cocaine Dependence', 'f15': 'Stimulant Dependence',
            'f19': 'Polysubstance Misuse', 'f70': 'Learning Disability',
            'f84': 'Autism', 'f90': 'ADHD',
        }

        # Look for formal diagnosis sections in clinic letters
        # Format: "DIAGNOSIS Her main diagnosis was of [description] - F25.00 and as a secondary diagnosis, [description] - F14.22"
        # The F-code comes at the end of each diagnosis description

        # Pattern to match: description followed by F-code
        # e.g., "Schizoaffective disorder, manic type - Concurrent affective and schizophrenic symptoms only - F25.00"
        main_diag_pattern = r'main\s+diagnosis\s+was\s+of\s+(.+?)\s*-\s*(f\d+(?:\.\d+)?)'
        secondary_diag_pattern = r'secondary\s+diagnosis[,:]?\s*(.+?)\s*-\s*(f\d+(?:\.\d+)?)'

        # Process each entry to find diagnoses
        for entry in entries:
            content = entry.get('content', '')
            content_lower = content.lower()

            # Find main diagnosis with F-code
            main_matches = re.findall(main_diag_pattern, content_lower)
            for desc, code in main_matches:
                code_base = code.split('.')[0]  # Get base code (e.g., f25 from f25.00)
                display = icd10_display.get(code_base, desc.strip().split(',')[0].title())
                diagnosis_with_codes.append((display, code, True))

            # Find secondary diagnosis with F-code
            sec_matches = re.findall(secondary_diag_pattern, content_lower)
            for desc, code in sec_matches:
                code_base = code.split('.')[0]
                display = icd10_display.get(code_base, desc.strip().split(',')[0].title())
                diagnosis_with_codes.append((display, code, False))

        # Count occurrences and prioritize by frequency and primary status
        diagnosis_scores = {}
        for display, code, is_primary in diagnosis_with_codes:
            score = diagnosis_scores.get(display, 0)
            score += 100 if is_primary else 50  # Primary diagnoses get higher weight
            diagnosis_scores[display] = score

        # Sort by score and take top 3
        sorted_diagnoses = sorted(diagnosis_scores.items(), key=lambda x: x[1], reverse=True)
        top_diagnoses = [dx for dx, score in sorted_diagnoses[:3]]

        # Fallback: if no formal diagnoses found, use general search
        if not top_diagnoses:
            for search_term, display_name in valid_diagnoses.items():
                pattern = rf'\b{re.escape(search_term)}\b'
                matches = re.findall(pattern, all_text_lower)
                if matches:
                    diagnosis_scores[display_name] = len(matches)
            sorted_diagnoses = sorted(diagnosis_scores.items(), key=lambda x: x[1], reverse=True)
            top_diagnoses = [dx for dx, score in sorted_diagnoses[:3]]

        demographics['diagnosis'] = top_diagnoses

        print(f"[NarrativeTester] Extracted demographics: name={demographics['name']}, dob={demographics['dob']}, gender={demographics['gender']}, ethnicity={demographics['ethnicity']}, diagnoses={demographics['diagnosis']}")

        return demographics

    def _generate_narrative(self):
        """Generate narrative using tribunal's comprehensive function."""
        if not self.entries:
            return

        try:
            from tribunal_popups import TribunalProgressPopup
            from progress_panel import reset_reference_tracker

            reset_reference_tracker()

            # Extract demographics from notes
            demographics = self._extract_patient_demographics(self.entries)

            # Set demographics in shared store
            from shared_data_store import get_shared_store
            shared_store = get_shared_store()
            patient_info = {
                'name': demographics['name'] or 'The patient',
                'gender': demographics['gender'] or '',
                'dob': demographics['dob'],
                'age': demographics.get('age'),  # Direct age if DOB not available
                'ethnicity': demographics['ethnicity'] or '',
                'diagnosis': demographics['diagnosis'],
            }
            shared_store.set_patient_info(patient_info, source="narrative_tester")

            # Prepare entries
            self.prepared_entries = []
            for entry in self.entries:
                text = entry.get('text', '') or entry.get('content', '')
                date_val = entry.get('date') or entry.get('datetime')

                entry_date = None
                if isinstance(date_val, datetime):
                    entry_date = date_val
                elif hasattr(date_val, 'toPython'):
                    entry_date = date_val.toPython()
                elif isinstance(date_val, str) and date_val:
                    for fmt in ["%Y-%m-%d", "%d/%m/%Y", "%Y-%m-%dT%H:%M:%S", "%d-%m-%Y"]:
                        try:
                            entry_date = datetime.strptime(date_val[:10], fmt[:10])
                            break
                        except:
                            pass

                if text:
                    self.prepared_entries.append({
                        'content': text,
                        'text': text,
                        'date': entry_date,
                        'datetime': entry_date,
                        'type': entry.get('type', ''),
                        'originator': entry.get('originator', ''),
                        'source': entry.get('source', ''),  # Preserve source for timeline builder
                    })

            print(f"[NarrativeTester] Generating narrative from {len(self.prepared_entries)} entries")

            # Generate narrative
            temp_popup = TribunalProgressPopup.__new__(TribunalProgressPopup)
            plain_text, html_text = temp_popup._generate_narrative_summary(self.prepared_entries)

            self.narrative_text = plain_text
            self.narrative_html = html_text

            # Display narrative
            self.narrative_browser.setHtml(html_text)

            # Find date range
            dates = [e['date'] for e in self.prepared_entries if e.get('date')]
            if dates:
                earliest = min(dates)
                latest = max(dates)
                date_range = f"{earliest.strftime('%d/%m/%Y')} - {latest.strftime('%d/%m/%Y')}"
            else:
                date_range = "No dates"

            self.stats_label.setText(f"{len(self.prepared_entries)} entries | {date_range}")

        except Exception as e:
            import traceback
            traceback.print_exc()
            QMessageBox.warning(self, "Error", f"Failed to generate narrative: {e}")

    def _populate_entries(self):
        """Populate the right panel with collapsible entries (same as tribunal)."""
        # Clear existing entries
        self._entry_frames.clear()
        self._entry_body_texts.clear()
        self._entry_checkboxes.clear()
        self._entry_feedback.clear()

        while self.entries_layout.count() > 1:  # Keep stretch
            item = self.entries_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        if not self.prepared_entries:
            return

        # Sort by date (newest first)
        sorted_entries = sorted(
            self.prepared_entries,
            key=lambda x: x.get('date') or datetime.min,
            reverse=True
        )

        for idx, entry in enumerate(sorted_entries):
            dt = entry.get('date')
            text = entry.get('text', '')
            if not text:
                continue

            if dt:
                date_str = dt.strftime("%d %b %Y")
                date_key = dt.strftime("%d/%m/%Y")
            else:
                date_str = "No date"
                date_key = f"nodate_{idx}"

            unique_key = f"{date_key}_{idx}"

            # Create entry frame (same style as tribunal)
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

            # Header row with checkbox, toggle button and date
            header_row = QHBoxLayout()
            header_row.setSpacing(8)

            # Checkbox for validation (checked = correct, unchecked = issue)
            cb = QCheckBox()
            cb.setChecked(True)  # Default: correct
            cb.setFixedSize(20, 20)
            cb.setToolTip("Uncheck if this entry has issues")
            header_row.addWidget(cb)

            toggle_btn = QPushButton("▸")
            toggle_btn.setFixedSize(22, 22)
            toggle_btn.setCursor(Qt.CursorShape.PointingHandCursor)
            toggle_btn.setStyleSheet("""
                QPushButton {
                    background: rgba(180, 150, 50, 0.2);
                    border: none;
                    border-radius: 4px;
                    font-size: 17px;
                    font-weight: bold;
                    color: #806000;
                }
                QPushButton:hover { background: rgba(180, 150, 50, 0.35); }
            """)
            header_row.addWidget(toggle_btn)

            date_label = QLabel(f"📅 {date_str}")
            date_label.setStyleSheet("""
                QLabel {
                    font-size: 15px;
                    font-weight: 600;
                    color: #806000;
                    background: transparent;
                }
            """)
            date_label.setCursor(Qt.CursorShape.PointingHandCursor)
            header_row.addWidget(date_label)

            # Add type/originator if available
            entry_type = entry.get('type', '')
            if entry_type:
                type_label = QLabel(f"| {entry_type}")
                type_label.setStyleSheet("color: #92400e; font-size: 13px;")
                header_row.addWidget(type_label)

            header_row.addStretch()
            entry_layout.addLayout(header_row)

            # Body text (hidden by default)
            body_text = QTextEdit()
            body_text.setPlainText(text)
            body_text.setReadOnly(True)
            body_text.setFrameShape(QFrame.Shape.NoFrame)
            body_text.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
            body_text.setStyleSheet("""
                QTextEdit {
                    font-size: 14px;
                    color: #333;
                    background: rgba(255, 248, 220, 0.5);
                    border: none;
                    border-radius: 4px;
                    padding: 6px;
                }
            """)
            body_text.setVisible(False)
            body_text.setMinimumHeight(100)
            body_text.setMaximumHeight(300)

            entry_layout.addWidget(body_text)

            # Feedback text field (hidden by default, shown when unchecked)
            feedback_frame = QFrame()
            feedback_frame.setVisible(False)
            feedback_frame.setStyleSheet("QFrame { background: #fef2f2; border: 1px solid #fca5a5; border-radius: 4px; }")
            feedback_layout = QVBoxLayout(feedback_frame)
            feedback_layout.setContentsMargins(6, 6, 6, 6)
            feedback_layout.setSpacing(4)

            feedback_label = QLabel("What's wrong with this entry?")
            feedback_label.setStyleSheet("color: #dc2626; font-weight: bold; font-size: 12px;")
            feedback_layout.addWidget(feedback_label)

            feedback_edit = QTextEdit()
            feedback_edit.setMaximumHeight(60)
            feedback_edit.setPlaceholderText("Describe the issue: wrong category, shouldn't be included, keyword mismatch...")
            feedback_edit.setStyleSheet("QTextEdit { border: 1px solid #fca5a5; border-radius: 4px; font-size: 12px; background: white; }")
            feedback_layout.addWidget(feedback_edit)

            entry_layout.addWidget(feedback_frame)

            # Toggle function
            def make_toggle(btn, body, frame, fb_frame, checkbox):
                def toggle():
                    if body.isVisible():
                        body.setVisible(False)
                        fb_frame.setVisible(False)
                        btn.setText("▸")
                        frame.setMaximumHeight(50)
                    else:
                        body.setVisible(True)
                        if not checkbox.isChecked():
                            fb_frame.setVisible(True)
                        btn.setText("▾")
                        frame.setMaximumHeight(16777215)
                return toggle

            toggle_fn = make_toggle(toggle_btn, body_text, entry_frame, feedback_frame, cb)
            toggle_btn.clicked.connect(toggle_fn)
            date_label.mousePressEvent = lambda e, fn=toggle_fn: fn()

            # Checkbox toggle shows/hides feedback
            def make_cb_toggle(checkbox, fb_frame, body):
                def on_toggle(state):
                    if body.isVisible():
                        fb_frame.setVisible(not checkbox.isChecked())
                    self._update_submit_button()
                return on_toggle

            cb.stateChanged.connect(make_cb_toggle(cb, feedback_frame, body_text))

            # Insert before stretch
            self.entries_layout.insertWidget(self.entries_layout.count() - 1, entry_frame)

            # Store references
            self._entry_frames[unique_key] = entry_frame
            self._entry_body_texts[unique_key] = (body_text, toggle_btn, text)
            self._entry_checkboxes[unique_key] = cb
            self._entry_feedback[unique_key] = feedback_edit

        self.source_info.setText(f"{len(sorted_entries)} entries loaded. Click a narrative reference to filter.")

    def _update_submit_button(self):
        """Show submit button if there are any unchecked entries."""
        has_issues = any(not cb.isChecked() for cb in self._entry_checkboxes.values())
        self.submit_feedback_btn.setVisible(has_issues)

    def _submit_feedback(self):
        """Submit feedback about problematic entries - outputs to console for Claude to see."""
        issues = []

        for key, cb in self._entry_checkboxes.items():
            if not cb.isChecked():
                feedback_edit = self._entry_feedback.get(key)
                body_info = self._entry_body_texts.get(key)

                if body_info:
                    body_text, toggle_btn, content = body_info
                    feedback_notes = feedback_edit.toPlainText() if feedback_edit else ""

                    # Parse date from key
                    date_part = key.rsplit('_', 1)[0]

                    issues.append({
                        'date': date_part,
                        'filter_keyword': self._current_filter_keyword,
                        'feedback': feedback_notes,
                        'entry_preview': content[:500] + '...' if len(content) > 500 else content
                    })

        if not issues:
            QMessageBox.information(self, "No Issues", "No entries marked as having issues.")
            return

        # Output to console in a format Claude can read
        print("\n" + "="*80)
        print("NARRATIVE TESTER FEEDBACK - ISSUES FOUND")
        print("="*80)
        print(f"Filter keyword used: '{self._current_filter_keyword}'")
        print(f"Number of issues: {len(issues)}")
        print("-"*80)

        for i, issue in enumerate(issues, 1):
            print(f"\n--- ISSUE {i} ---")
            print(f"Date: {issue['date']}")
            print(f"Found under keyword: '{issue['filter_keyword']}'")
            print(f"User feedback: {issue['feedback'] or '(No notes provided)'}")
            print(f"Entry content:")
            print(f"  {issue['entry_preview'][:300]}...")
            print()

        print("="*80)
        print("END OF FEEDBACK")
        print("="*80 + "\n")

        # Also save to a file for persistence
        feedback_file = Path(__file__).parent / "narrative_feedback.txt"
        try:
            with open(feedback_file, 'a', encoding='utf-8') as f:
                f.write(f"\n{'='*80}\n")
                f.write(f"FEEDBACK SUBMITTED: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
                f.write(f"Filter keyword: '{self._current_filter_keyword}'\n")
                f.write(f"{'='*80}\n")
                for i, issue in enumerate(issues, 1):
                    f.write(f"\n--- ISSUE {i} ---\n")
                    f.write(f"Date: {issue['date']}\n")
                    f.write(f"Found under keyword: '{issue['filter_keyword']}'\n")
                    f.write(f"User feedback: {issue['feedback'] or '(No notes provided)'}\n")
                    f.write(f"Entry content:\n{issue['entry_preview']}\n")
                f.write(f"\n{'='*80}\n\n")

            QMessageBox.information(self, "Feedback Submitted",
                f"Submitted {len(issues)} issue(s).\n\n"
                f"Feedback saved to:\n{feedback_file}\n\n"
                f"Also printed to console for Claude to see.")
        except Exception as e:
            QMessageBox.warning(self, "Save Error", f"Printed to console but couldn't save to file: {e}")

    def _on_link_clicked(self, url: QUrl):
        """Handle clicks on narrative reference links - show referenced entries."""
        from progress_panel import get_reference

        ref_id = url.fragment()
        if not ref_id:
            return

        ref_data = get_reference(ref_id)
        if not ref_data:
            self.source_info.setText(f"Reference '{ref_id}' not found in tracker")
            return

        matched_text = ref_data.get("matched", "")
        is_multi = ref_data.get("multi", False)

        # Store the filter keyword for feedback tracking
        self._current_filter_keyword = matched_text

        if is_multi:
            # MULTI-REFERENCE: Show only entries that ACTUALLY contain the keywords
            entries_list = ref_data.get("entries", [])
            print(f"[NarrativeTester] Multi-ref clicked: {len(entries_list)} entries for '{matched_text}'")

            # Build map of target date strings to their keywords AND content snippets
            target_date_keywords = {}  # date_str -> list of keywords
            target_date_snippets = {}  # date_str -> list of content snippets
            for entry_info in entries_list:
                ref_date = entry_info.get('date')
                entry_keyword = entry_info.get('keyword', matched_text)
                content_snippet = entry_info.get('content_snippet', '')
                if ref_date:
                    if hasattr(ref_date, 'strftime'):
                        date_str = ref_date.strftime('%d/%m/%Y')
                    elif hasattr(ref_date, 'date'):
                        date_str = ref_date.date().strftime('%d/%m/%Y')
                    else:
                        continue
                    if date_str not in target_date_keywords:
                        target_date_keywords[date_str] = []
                        target_date_snippets[date_str] = []
                    target_date_keywords[date_str].append(entry_keyword)
                    if content_snippet:
                        target_date_snippets[date_str].append(content_snippet.lower()[:100])

            print(f"[NarrativeTester] Looking for {len(target_date_keywords)} unique dates")

            # Show entries matching dates AND containing relevant keywords
            shown_count = 0
            for key, body_info in self._entry_body_texts.items():
                body_text, toggle_btn, content = body_info
                entry_frame = self._entry_frames.get(key)

                if not entry_frame:
                    continue

                # Extract date from key
                key_date = key.split('_')[0] if '_' in key else key
                content_lower = content.lower()

                if key_date in target_date_keywords:
                    keywords_for_date = target_date_keywords[key_date]
                    snippets_for_date = target_date_snippets.get(key_date, [])

                    # Check if this entry actually contains any of the keywords
                    # OR matches a content snippet from the incidents
                    # Use word boundary matching to avoid "od" matching "today"
                    def has_keyword_with_boundary(text, keyword):
                        return bool(re.search(r'\b' + re.escape(keyword.lower()) + r'\b', text))

                    entry_has_keyword = any(has_keyword_with_boundary(content_lower, kw) for kw in keywords_for_date if kw)
                    entry_matches_snippet = any(snip in content_lower for snip in snippets_for_date if snip)

                    if entry_has_keyword or entry_matches_snippet:
                        # Show and expand this entry
                        entry_frame.setVisible(True)
                        entry_frame.setStyleSheet("""
                            QFrame#entryFrame {
                                background: rgba(255, 250, 220, 0.98);
                                border: 2px solid rgba(200, 150, 50, 0.8);
                                border-radius: 8px;
                                padding: 4px;
                            }
                        """)
                        # Expand if collapsed
                        if not body_text.isVisible():
                            toggle_btn.click()
                        # Highlight ALL keywords for this entry's date
                        self._highlight_multiple_keywords(body_text, keywords_for_date, content)
                        shown_count += 1
                    else:
                        # Entry is on same date but doesn't contain the keyword - HIDE
                        entry_frame.setVisible(False)
                else:
                    # HIDE this entry
                    entry_frame.setVisible(False)

            self.source_info.setText(f"Showing {shown_count} entries for: {matched_text}")

        else:
            # SINGLE REFERENCE: Show one entry
            content_snippet = ref_data.get("content_snippet", "")
            ref_date = ref_data.get("date")

            print(f"[NarrativeTester] Single-ref clicked: matched='{matched_text}', date={ref_date}")

            snippet_lower = content_snippet[:100].lower() if content_snippet else ""

            # Find the SINGLE entry that matches the reference date and content snippet
            # CRITICAL: Date is PRIMARY - we MUST match the date, snippet is secondary
            exact_match_key = None
            date_match_key = None  # Entry matching date (primary requirement)
            best_fallback_key = None
            best_fallback_score = 0

            # Format reference date for comparison
            ref_date_str = None
            if ref_date:
                if hasattr(ref_date, 'strftime'):
                    ref_date_str = ref_date.strftime('%d/%m/%Y')
                elif hasattr(ref_date, 'date'):
                    ref_date_str = ref_date.date().strftime('%d/%m/%Y')

            for key, body_info in self._entry_body_texts.items():
                body_text, toggle_btn, content = body_info
                content_lower = content.lower()

                # Extract date from key
                key_date = key.split('_')[0] if '_' in key else key

                # Check for exact date match - THIS IS PRIMARY
                date_matches = (ref_date_str and key_date == ref_date_str)

                # Check for content snippet match
                snippet_matches = (snippet_lower and len(snippet_lower) > 20 and snippet_lower in content_lower)

                # Check for keyword in content (using word boundary matching)
                keyword_lower = matched_text.strip().lower()
                keyword_in_content = bool(re.search(r'\b' + re.escape(keyword_lower) + r'\b', content_lower)) if keyword_lower else False

                # Perfect match: both date and snippet
                if date_matches and snippet_matches:
                    exact_match_key = key
                    break

                # Date matches - this is our primary requirement
                if date_matches:
                    # Prefer date match with keyword over date match without
                    if date_match_key is None or keyword_in_content:
                        date_match_key = key

                # Fallback: no date match but has keyword (only used if no date match exists)
                if not date_matches and keyword_in_content:
                    score = 1
                    if snippet_matches:
                        score += 5
                    if score > best_fallback_score:
                        best_fallback_score = score
                        best_fallback_key = key

            # Priority: exact match > date match > fallback (only if no ref_date provided)
            if exact_match_key:
                target_key = exact_match_key
            elif date_match_key:
                target_key = date_match_key
            elif not ref_date_str:
                # Only use fallback if no date was specified in the reference
                target_key = best_fallback_key
            else:
                # Date was specified but no match found - don't use fallback from wrong date
                target_key = None
                print(f"[NarrativeTester] WARNING: No entry found for date {ref_date_str}")

            if not target_key:
                self.source_info.setText(f"No entry found for '{matched_text}'")
                return

            print(f"[NarrativeTester] Found target entry: {target_key}")

            # HIDE all entries except the target, SHOW and expand the target
            for key, body_info in self._entry_body_texts.items():
                body_text, toggle_btn, content = body_info
                entry_frame = self._entry_frames.get(key)

                if not entry_frame:
                    continue

                if key == target_key:
                    # Show and expand this entry
                    entry_frame.setVisible(True)
                    entry_frame.setStyleSheet("""
                        QFrame#entryFrame {
                            background: rgba(255, 250, 220, 0.98);
                            border: 2px solid rgba(200, 150, 50, 0.8);
                            border-radius: 8px;
                            padding: 4px;
                        }
                    """)
                    # Expand if collapsed
                    if not body_text.isVisible():
                        toggle_btn.click()
                    # Highlight the matched keyword
                    keyword = matched_text.strip().lower()
                    self._highlight_keyword(body_text, keyword, content)
                else:
                    # HIDE this entry
                    entry_frame.setVisible(False)

            self.source_info.setText(f"Showing: {matched_text}")

        self.remove_filter_btn.setVisible(True)

        # Scroll to top
        self.entries_scroll.verticalScrollBar().setValue(0)
        return  # Skip the rest of the old logic

        # Find matching entries
        matching_entries = []
        snippet_lower = content_snippet[:100].lower() if content_snippet else ""

        def is_keyword_negated(text, kw):
            """Check if keyword is negated in text."""
            # Normalize apostrophes (curly ' to straight ')
            text_lower = text.lower().replace(''', "'").replace(''', "'")
            negation_patterns = [
                r'\bno\s+' + re.escape(kw),
                r'\bno\b[^.!?\n]{0,100}\b' + re.escape(kw),
                r'\bnil\s+' + re.escape(kw),
                r'\bwithout\s+' + re.escape(kw),
                r'\bdenied\s+' + re.escape(kw),
                r'\bnot\s+led\s+to\s+' + re.escape(kw),
                r'\bno\s+incidents?\s*,?\s*.*' + re.escape(kw),
                r'\bno\s+self\s*harm\s+or\s+.*' + re.escape(kw),
                r'\brisk\s+of\s+' + re.escape(kw),
                r'\bhistory\s+of\s+' + re.escape(kw),
                r'\brisks?[:\s]+[^.]*\b' + re.escape(kw),
                # Risk section headers - keyword in risk list (within 300 chars of "Risks:")
                r'\brisks?\s*:\s*.{0,300}\b' + re.escape(kw),
                # "Aggression towards others" in a risk list context
                r'\b' + re.escape(kw) + r'\s+towards\s+others\b',
                # Risk assessment field labels (To Other:, To Others:, To Self:)
                r'\bto\s+others?\s*:\s*history\s+of\b[^.]*' + re.escape(kw),
                r'\bto\s+others?\s*:[^.]*\b' + re.escape(kw),
                r'\bto\s+self\s*:\s*history\s+of\b[^.]*' + re.escape(kw),
                r'\bto\s+self\s*:[^.]*\b' + re.escape(kw),
                # Forensic history mentions
                r'\bforensic\s+history\b[^.]*' + re.escape(kw),
                r'\b' + re.escape(kw) + r'[^.]*\bforensic\s+history\b',
                # Care plan / management language - not actual incidents
                r'\bmanagement\s+of\s+(high\s+)?risks?\b[^.]*' + re.escape(kw),
                r'\bmanagement\s+of\b[^.]*' + re.escape(kw),
                r'\bpreventative\s+interventions?\b[^.]*' + re.escape(kw),
                # Relapse indicators / warning signs - not actual incidents
                r'\brelapse\s+indicators?\b[^.]*' + re.escape(kw),
                r'\bwarning\s+signs?\b[^.]*' + re.escape(kw),
                r'\bearly\s+warning\b[^.]*' + re.escape(kw),
                # "urges" - feelings/potential, not actual behaviour
                r'\b' + re.escape(kw) + r'\s+urges?\b',
                r'\burges?\s+to\s+' + re.escape(kw),
                r'\bhas\s+' + re.escape(kw) + r'\s+urges?\b',
                # Conditional/potential behaviour - not actual incidents
                r'\bcan\s+be\s+' + re.escape(kw),
                r'\bmay\s+be(come)?\s+' + re.escape(kw),
                r'\bcould\s+be(come)?\s+' + re.escape(kw),
                r'\bif\s+.*\b' + re.escape(kw),
                # "didn't/doesn't/does not present as aggressive" patterns
                r'\bdidn\'?t\s+present\s+(as\s+)?' + re.escape(kw),
                r'\bdid\s+not\s+present\s+(as\s+)?' + re.escape(kw),
                r'\bdoes\s+not\s+present\s+(as\s+)?' + re.escape(kw),
                r'\bdoesn\'?t\s+present\s+(as\s+)?' + re.escape(kw),
                # "did not pose any aggressive behaviour"
                r'\bdid\s+not\s+pose\s+(any\s+)?' + re.escape(kw),
                r'\bdidn\'?t\s+pose\s+(any\s+)?' + re.escape(kw),
                # "did not want to be secluded/restrained" - CRITICAL FIX
                r'\bdid\s+not\s+want\s+[^.]*' + re.escape(kw),
                r'\bdidn\'?t\s+want\s+[^.]*' + re.escape(kw),
                r'\bdoes\s+not\s+want\s+[^.]*' + re.escape(kw),
                r'\bdoesn\'?t\s+want\s+[^.]*' + re.escape(kw),
                # "did not feel she would like" patterns
                r'\bdid\s+not\s+feel\s+[^.]*' + re.escape(kw),
                r'\bdidn\'?t\s+feel\s+[^.]*' + re.escape(kw),
                r'\bdoes\s+not\s+feel\s+[^.]*' + re.escape(kw),
                r'\bdoesn\'?t\s+feel\s+[^.]*' + re.escape(kw),
                # "did not want to be secluded" - explicit pattern
                r'\bdid\s+not\s+want\s+to\s+be\s+' + re.escape(kw),
                r'\bdidn\'?t\s+want\s+to\s+be\s+' + re.escape(kw),
                r'\bdoes\s+not\s+want\s+to\s+be\s+' + re.escape(kw),
                r'\bdoesn\'?t\s+want\s+to\s+be\s+' + re.escape(kw),
                # "as she did not want" - subordinate clause pattern
                r'\bas\s+(she|he|they)\s+did\s+not\s+want\s+[^.]*' + re.escape(kw),
                r'\bas\s+(she|he|they)\s+didn\'?t\s+want\s+[^.]*' + re.escape(kw),
                # "would not like to be" patterns
                r'\bwould\s+not\s+like\s+to\s+[^.]*' + re.escape(kw),
                r'\bwouldn\'?t\s+like\s+to\s+[^.]*' + re.escape(kw),
                # "refused/declined seclusion"
                r'\brefused\s+[^.]*' + re.escape(kw),
                r'\bdeclined\s+[^.]*' + re.escape(kw),
                # "didn't display any signs of aggression"
                r'\bdidn\'?t\s+display\s+(any\s+)?(signs?\s+of\s+)?' + re.escape(kw),
                r'\bdid\s+not\s+display\s+(any\s+)?(signs?\s+of\s+)?' + re.escape(kw),
                r'\bno\s+signs?\s+of\s+' + re.escape(kw),
                # "have not been an incident of aggression"
                r'\bhave\s+not\s+been\s+(an?\s+)?incident' + r'[^.]*' + re.escape(kw),
                r'\bhas\s+not\s+been\s+(an?\s+)?incident' + r'[^.]*' + re.escape(kw),
                r'\bthere\s+have\s+not\s+been\b[^.]*' + re.escape(kw),
                r'\bthere\s+has\s+not\s+been\b[^.]*' + re.escape(kw),
                r'\bno\s+incident' + r'[^.]*' + re.escape(kw),
                # Low risk mentions
                r'\b' + re.escape(kw) + r'[^.]*:\s*low\b',
                r'\blow\b[^.]*' + re.escape(kw),
                # Positive behaviour indicators in same sentence as keyword
                r'\bcalm\s+and\s+settled\b[^.]*\b' + re.escape(kw),
                r'\b' + re.escape(kw) + r'[^.]*\bcalm\s+and\s+settled\b',
                r'\bsettled\s+and\s+calm\b[^.]*\b' + re.escape(kw),
                r'\b(very\s+)?pleasant\s+on\s+approach\b[^.]*\b' + re.escape(kw),
                r'\b' + re.escape(kw) + r'[^.]*\b(very\s+)?pleasant\s+on\s+approach\b',
            ]

            # Police-specific patterns (care plan language, fear, etc.)
            if kw in ['police', 'officer', 'arrest', 'custody']:
                negation_patterns.extend([
                    # Care plan / protocol language - NOT actual incidents
                    r'\b' + re.escape(kw) + r'\s+to\s+be\s+called\b',
                    r'\bcall(ing)?\s+(the\s+)?' + re.escape(kw) + r'\s+(if|when|as)\b',
                    r'\bif\s+[^.]*' + re.escape(kw) + r'\s+(to\s+be\s+)?called\b',
                    r'\bif\s+(threats?|incidents?|aggression)[^.]*' + re.escape(kw),
                    r'\bemergenc(y|ies)\s+' + re.escape(kw),
                    # Conditional / hypothetical
                    r'\bif\s+[^.]{0,50}\b' + re.escape(kw),
                    r'\bshould\s+[^.]*' + re.escape(kw),
                    r'\bmay\s+need\s+[^.]*' + re.escape(kw),
                    # Fear of police - patient's feelings, not incident
                    r'\bfear\s+(of\s+)?(the\s+)?' + re.escape(kw),
                    r'\bscared\s+(of\s+|when\s+)[^.]*' + re.escape(kw),
                    r'\bafraid\s+(of\s+)?' + re.escape(kw),
                    r'\banxious\s+(about\s+|around\s+)?' + re.escape(kw),
                    # History mentions
                    r'\bprevious(ly)?\s+[^.]*' + re.escape(kw) + r'\s+contact',
                    # Delusions about police
                    r'\bdelusion[^.]*' + re.escape(kw),
                    r'\bbelie(ve|f)[^.]*' + re.escape(kw) + r'\s+(coming|after|watching)',
                    r'\b' + re.escape(kw) + r'\s+(coming|after|watching)\s+(her|him|them)',
                ])

            # Substance-specific patterns
            if kw in ['drug', 'substance', 'cannabis', 'alcohol', 'cocaine', 'heroin', 'intox', 'amphetamine', 'meth']:
                negation_patterns.extend([
                    # Denial / negation
                    r'\b(denies|denied|abstain|abstinent|negative)\s+[^.]*' + re.escape(kw),
                    r'\bnot\s+(using|taking|drinking)\s+[^.]*' + re.escape(kw),
                    r'\bstopped\s+(using|taking|drinking)\s+' + re.escape(kw),
                    r'\bgave\s+up\s+' + re.escape(kw),
                    r'\bquit\s+' + re.escape(kw),
                    # History / past use
                    r'\bprevious\s+' + re.escape(kw),
                    r'\bpast\s+' + re.escape(kw) + r'\s+use',
                    # Medication context
                    r'\bprescribed\s+' + re.escape(kw),
                    r'\bmedication\s+[^.]*' + re.escape(kw),
                    # Education / advice
                    r'\badvised\s+(about|regarding|on)\s+' + re.escape(kw),
                    r'\beducation\s+(about|on|regarding)\s+' + re.escape(kw),
                    r'\bdiscussed\s+[^.]*' + re.escape(kw) + r'\s+(risks?|harm|use)',
                    # Test results
                    r'\b' + re.escape(kw) + r'\s*[:-]?\s*(negative|clear|nil)',
                    r'\bnegative\s+(for\s+)?' + re.escape(kw),
                    # Clean / sober
                    r'\bclean\s+(from\s+)?' + re.escape(kw),
                    r'\bsober\b[^.]*' + re.escape(kw),
                    r'\b' + re.escape(kw) + r'\s+free\b',
                ])

            # Mental state keywords patterns (delusion, hallucination, paranoid, etc.)
            if kw in ['delusion', 'hallucin', 'paranoid', 'voices', 'psycho', 'agitat', 'irrita', 'withdraw', 'isolat']:
                negation_patterns.extend([
                    r'\b(absent|no\s+evidence)\s+[^.]*' + re.escape(kw),
                    r'\b' + re.escape(kw) + r'[^.]*\babsent\b',
                    r'\bno\s+' + re.escape(kw),
                ])

            for pattern in negation_patterns:
                if re.search(pattern, text_lower, re.IGNORECASE):
                    return True
            return False

        for key, body_info in self._entry_body_texts.items():
            body_text, toggle_btn, content = body_info
            content_lower = content.lower()

            # Check if any keyword matches (and is NOT negated)
            has_keyword = False
            matched_kw = None
            for kw in keywords_to_search:
                if kw and len(kw) >= 2 and kw in content_lower:
                    # Skip if keyword is negated
                    negated = is_keyword_negated(content, kw)
                    if negated:
                        continue
                    has_keyword = True
                    matched_kw = kw
                    break

            # Check snippet match
            has_snippet = snippet_lower and len(snippet_lower) > 20 and snippet_lower in content_lower

            if has_keyword or has_snippet:
                matching_entries.append((key, body_info, matched_kw or keyword, has_snippet))

        print(f"[NarrativeTester] Found {len(matching_entries)} matching entries (before dedup)")

        # Deduplicate: keep only longest entry per day
        if matching_entries:
            by_day = defaultdict(list)
            for entry in matching_entries:
                key, body_info, kw, has_snip = entry
                # Extract date part from key (format: "DD/MM/YYYY" or "DD/MM/YYYY_N")
                day_key = key.split('_')[0] if '_' in key else key
                by_day[day_key].append(entry)

            deduped_entries = []
            for day_key, day_entries in by_day.items():
                if len(day_entries) == 1:
                    deduped_entries.append(day_entries[0])
                else:
                    # Keep longest content for this day
                    longest = max(day_entries, key=lambda e: len(e[1][2]))  # e[1][2] is content
                    deduped_entries.append(longest)

            if len(matching_entries) != len(deduped_entries):
                print(f"[NarrativeTester] Deduped: {len(matching_entries)} -> {len(deduped_entries)} entries")
            matching_entries = deduped_entries

        if not matching_entries:
            self.source_info.setText(f"No entries found matching '{matched_text}'")
            return

        self.source_info.setText(f"Filtered: {len(matching_entries)} entries matching '{matched_text}'")
        self.remove_filter_btn.setVisible(True)

        # Get matching keys
        matching_keys = {entry[0] for entry in matching_entries}

        # HIDE non-matching entries, SHOW and expand matching entries
        for key, body_info in self._entry_body_texts.items():
            body_text, toggle_btn, content = body_info
            entry_frame = self._entry_frames.get(key)

            if not entry_frame:
                continue

            if key in matching_keys:
                # Show this entry
                entry_frame.setVisible(True)

                # Reset frame style
                entry_frame.setStyleSheet("""
                    QFrame#entryFrame {
                        background: rgba(255, 255, 255, 0.95);
                        border: 1px solid rgba(180, 150, 50, 0.4);
                        border-radius: 8px;
                        padding: 4px;
                    }
                """)
            else:
                # HIDE non-matching entry
                entry_frame.setVisible(False)

        # Now expand and highlight matching entries
        first_frame = None
        for key, body_info, matched_kw, is_exact in matching_entries:
            body_text, toggle_btn, content = body_info
            entry_frame = self._entry_frames.get(key)

            if not first_frame:
                first_frame = entry_frame

            # Expand entry
            if not body_text.isVisible():
                toggle_btn.click()

            # Highlight the matched keyword
            self._highlight_keyword(body_text, matched_kw, content)

            # Highlight frame border for exact matches
            if is_exact and entry_frame:
                entry_frame.setStyleSheet("""
                    QFrame#entryFrame {
                        background: rgba(255, 255, 200, 0.95);
                        border: 2px solid #f59e0b;
                        border-radius: 8px;
                        padding: 4px;
                    }
                """)

            # Pre-fill feedback text box with the narrative line
            feedback_edit = self._entry_feedback.get(key)
            if feedback_edit and self._current_narrative_line:
                feedback_edit.setPlainText(f"NARRATIVE: {self._current_narrative_line}\n\nISSUE: ")

        # Scroll to first matching entry
        if first_frame:
            QTimer.singleShot(100, lambda: self.entries_scroll.ensureWidgetVisible(first_frame))

    def _remove_filter(self):
        """Remove filter and show all entries again."""
        self.remove_filter_btn.setVisible(False)
        self.source_info.setText(f"{len(self._entry_frames)} entries loaded. Click a narrative reference to filter.")

        # Show all entries and collapse them
        for key, body_info in self._entry_body_texts.items():
            body_text, toggle_btn, content = body_info
            entry_frame = self._entry_frames.get(key)

            if entry_frame:
                # Show the entry
                entry_frame.setVisible(True)

                # Reset frame style
                entry_frame.setStyleSheet("""
                    QFrame#entryFrame {
                        background: rgba(255, 255, 255, 0.95);
                        border: 1px solid rgba(180, 150, 50, 0.4);
                        border-radius: 8px;
                        padding: 4px;
                    }
                """)

            # Collapse entry and clear highlighting
            if body_text.isVisible():
                toggle_btn.click()
            body_text.setPlainText(content)

    def _highlight_keyword(self, text_edit, keyword, original_content):
        """Highlight keyword in QTextEdit with yellow background."""
        if not keyword:
            return

        # Set the plain text first
        text_edit.setPlainText(original_content)

        # Create highlight format
        highlight_format = QTextCharFormat()
        highlight_format.setBackground(QColor("#fef08a"))  # Yellow
        highlight_format.setFontWeight(700)  # Bold

        # Find and highlight all occurrences
        cursor = text_edit.textCursor()
        cursor.movePosition(QTextCursor.MoveOperation.Start)

        # Search for keyword (case insensitive)
        text_lower = original_content.lower()
        keyword_lower = keyword.lower()

        pos = 0
        while True:
            pos = text_lower.find(keyword_lower, pos)
            if pos == -1:
                break

            # Select the text
            cursor.setPosition(pos)
            cursor.setPosition(pos + len(keyword), QTextCursor.MoveMode.KeepAnchor)
            cursor.mergeCharFormat(highlight_format)

            pos += len(keyword)

        # Move cursor to start
        cursor.movePosition(QTextCursor.MoveOperation.Start)
        text_edit.setTextCursor(cursor)

    def _highlight_multiple_keywords(self, text_edit, keywords, original_content):
        """Highlight multiple keywords in QTextEdit with yellow background."""
        if not keywords:
            return

        # Set the plain text first
        text_edit.setPlainText(original_content)

        # Create highlight format
        highlight_format = QTextCharFormat()
        highlight_format.setBackground(QColor("#fef08a"))  # Yellow
        highlight_format.setFontWeight(700)  # Bold

        cursor = text_edit.textCursor()
        text_lower = original_content.lower()

        # Highlight each keyword
        for keyword in keywords:
            if not keyword:
                continue
            keyword_lower = keyword.lower()

            pos = 0
            while True:
                pos = text_lower.find(keyword_lower, pos)
                if pos == -1:
                    break

                # Select the text
                cursor.setPosition(pos)
                cursor.setPosition(pos + len(keyword), QTextCursor.MoveMode.KeepAnchor)
                cursor.mergeCharFormat(highlight_format)

                pos += len(keyword)

        # Move cursor to start
        cursor.movePosition(QTextCursor.MoveOperation.Start)
        text_edit.setTextCursor(cursor)


def main():
    app = QApplication(sys.argv)
    app.setStyle("Fusion")

    import platform
    if platform.system() == "Darwin":
        font = QFont(".AppleSystemUIFont", 13)
    elif platform.system() == "Windows":
        font = QFont("Segoe UI", 10)
    else:
        font = QFont("Sans Serif", 10)
    app.setFont(font)

    window = NarrativeTester()
    window.show()

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
