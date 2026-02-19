from __future__ import annotations
import re
from PySide6.QtCore import Qt, Signal, QEvent
from PySide6.QtWidgets import (
    QWidget, QLabel, QPushButton,
    QVBoxLayout, QHBoxLayout, QScrollArea,
    QSizePolicy, QFrame, QCheckBox, QTextEdit
)
from shared_widgets import add_lock_to_popup
from spell_check_textedit import enable_spell_check_on_textedit

from personal_history_state import (
    empty_personal_history_state,
    PersonalHistoryState,
)

from birth_widget import BirthWidget
from milestones_widget import MilestonesWidget
from family_history_widget import FamilyHistoryWidget
from abuse_widget import AbuseWidget
from schooling_widget import SchoolingWidget
from qualifications_widget import QualificationsWidget
from work_history_widget import WorkHistoryWidget
from sexual_orientation_widget import SexualOrientationWidget
from children_widget import ChildrenWidget
from relationships_widget import RelationshipsWidget


# ======================================================
# PRONOUN ENGINE (SAME CONTRACT AS ANXIETY)
# ======================================================
def pronouns_from_gender(g):
    g = (g or "").lower().strip()
    if g == "male":
        return {"subj": "he", "obj": "him", "pos": "his", "have": "has", "are": "is", "were": "was"}
    if g == "female":
        return {"subj": "she", "obj": "her", "pos": "her", "have": "has", "are": "is", "were": "was"}
    return {"subj": "they", "obj": "them", "pos": "their", "have": "have", "are": "are", "were": "were"}


# ======================================================
# COLLAPSIBLE SECTION WITH DRAG BAR
# ======================================================
class CollapsibleSection(QWidget):
    """A section with a collapse button and a drag bar for resizing."""

    def __init__(self, title: str, parent=None, start_collapsed=False):
        super().__init__(parent)
        self._is_collapsed = start_collapsed
        self._title = title
        self._content_height = 200  # Default content height
        self._min_height = 120  # Increased minimum to prevent content cutoff
        self._max_height = 800
        self._dragging = False
        self._drag_start_y = 0
        self._drag_start_height = 0

        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        # Header with collapse button
        self.header = QFrame()
        self.header.setFixedHeight(38)
        self.header.setStyleSheet("""
            QFrame {
                background: rgba(0, 0, 0, 0.05);
                border: 1px solid rgba(0,0,0,0.1);
                border-radius: 6px 6px 0 0;
            }
        """)

        header_layout = QHBoxLayout(self.header)
        header_layout.setContentsMargins(8, 4, 8, 4)
        header_layout.setSpacing(8)

        # Collapse button
        self.collapse_btn = QPushButton("−" if not start_collapsed else "+")
        self.collapse_btn.setFixedSize(24, 24)
        self.collapse_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        self.collapse_btn.setStyleSheet("""
            QPushButton {
                background: rgba(0, 0, 0, 0.1);
                color: #333;
                border: none;
                border-radius: 4px;
                font-size: 21px;
                font-weight: bold;
                padding-bottom: 2px;
            }
            QPushButton:hover {
                background: rgba(0, 0, 0, 0.2);
            }
        """)
        self.collapse_btn.clicked.connect(self._toggle_collapse)
        header_layout.addWidget(self.collapse_btn)

        # Title
        self.title_label = QLabel(title)
        self.title_label.setStyleSheet("""
            QLabel {
                font-size: 21px;
                font-weight: 600;
                color: #003c32;
                background: transparent;
                border: none;
            }
        """)
        header_layout.addWidget(self.title_label)
        header_layout.addStretch()

        layout.addWidget(self.header)

        # Content container with scroll area
        self.content_container = QFrame()
        self.content_container.setStyleSheet("""
            QFrame {
                background: transparent;
                border: none;
            }
        """)
        container_layout = QVBoxLayout(self.content_container)
        container_layout.setContentsMargins(0, 0, 0, 0)
        container_layout.setSpacing(0)

        # Scroll area for content
        self.scroll_area = QScrollArea()
        self.scroll_area.setWidgetResizable(True)
        self.scroll_area.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.scroll_area.setMinimumHeight(100)
        self.scroll_area.setStyleSheet("QScrollArea { border: none; background: transparent; }")

        self.scroll_content = QWidget()
        self.scroll_content.setStyleSheet("background: transparent;")
        self.content_layout = QVBoxLayout(self.scroll_content)
        self.content_layout.setContentsMargins(12, 8, 12, 8)
        self.content_layout.setSpacing(0)

        self.scroll_area.setWidget(self.scroll_content)
        container_layout.addWidget(self.scroll_area)
        layout.addWidget(self.content_container, 1)

        # Drag bar at bottom
        self.drag_bar = QFrame()
        self.drag_bar.setFixedHeight(10)
        self.drag_bar.setCursor(Qt.CursorShape.SizeVerCursor)
        self.drag_bar.setStyleSheet("""
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
        self.drag_bar.installEventFilter(self)
        layout.addWidget(self.drag_bar)

        # Apply initial state
        if start_collapsed:
            self.content_container.setVisible(False)
            self.drag_bar.setVisible(False)
            self.setFixedHeight(self.header.height())
        else:
            self._update_height()

    def set_content(self, widget: QWidget):
        """Set the content widget for this section."""
        self.content_layout.addWidget(widget)

    def set_header_style(self, style: str):
        """Set custom header style."""
        self.header.setStyleSheet(style)

    def set_title_style(self, style: str):
        """Set custom title style."""
        self.title_label.setStyleSheet(style)

    def set_content_height(self, height: int):
        """Set the content area height."""
        self._content_height = max(self._min_height, min(self._max_height, height))
        if not self._is_collapsed:
            self._update_height()

    def _update_height(self):
        """Update the widget height based on content height."""
        total = self.header.height() + self._content_height + self.drag_bar.height()
        self.setFixedHeight(total)

    def _toggle_collapse(self):
        """Toggle the collapsed state."""
        self._is_collapsed = not self._is_collapsed

        if self._is_collapsed:
            self.collapse_btn.setText("+")
            self.content_container.setVisible(False)
            self.drag_bar.setVisible(False)
            self.setFixedHeight(self.header.height())
        else:
            self.collapse_btn.setText("−")
            self.content_container.setVisible(True)
            self.drag_bar.setVisible(True)
            self._update_height()

    def eventFilter(self, obj, event):
        if obj == self.drag_bar:
            if event.type() == QEvent.Type.MouseButtonPress:
                self._dragging = True
                self._drag_start_y = event.globalPosition().y()
                self._drag_start_height = self._content_height
                return True
            elif event.type() == QEvent.Type.MouseMove and self._dragging:
                delta = event.globalPosition().y() - self._drag_start_y
                new_height = self._drag_start_height + delta
                self._content_height = max(self._min_height, min(self._max_height, int(new_height)))
                self._update_height()
                return True
            elif event.type() == QEvent.Type.MouseButtonRelease:
                self._dragging = False
                return True
        return super().eventFilter(obj, event)

    def is_collapsed(self) -> bool:
        return self._is_collapsed


# ======================================================
# RESIZABLE SECTION (non-collapsible, just has drag bar)
# ======================================================
class ResizableSection(QWidget):
    """A section with just a drag bar for resizing (no collapse)."""

    def __init__(self, parent=None):
        super().__init__(parent)
        self._content_height = 100
        self._min_height = 120
        self._max_height = 400
        self._dragging = False
        self._drag_start_y = 0
        self._drag_start_height = 0

        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Fixed)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        # Content container with scroll area
        self.content_container = QFrame()
        container_layout = QVBoxLayout(self.content_container)
        container_layout.setContentsMargins(0, 0, 0, 0)
        container_layout.setSpacing(0)

        # Scroll area for content
        self.scroll_area = QScrollArea()
        self.scroll_area.setWidgetResizable(True)
        self.scroll_area.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        self.scroll_area.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        self.scroll_area.setMinimumHeight(100)
        self.scroll_area.setStyleSheet("QScrollArea { border: none; background: transparent; }")

        self.scroll_content = QWidget()
        self.scroll_content.setStyleSheet("background: transparent;")
        self.content_layout = QVBoxLayout(self.scroll_content)
        self.content_layout.setContentsMargins(12, 8, 12, 8)
        self.content_layout.setSpacing(0)

        self.scroll_area.setWidget(self.scroll_content)
        container_layout.addWidget(self.scroll_area)
        layout.addWidget(self.content_container, 1)

        # Drag bar at bottom
        self.drag_bar = QFrame()
        self.drag_bar.setFixedHeight(10)
        self.drag_bar.setCursor(Qt.CursorShape.SizeVerCursor)
        self.drag_bar.setStyleSheet("""
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
        self.drag_bar.installEventFilter(self)
        layout.addWidget(self.drag_bar)

        self._update_height()

    def set_content(self, widget: QWidget):
        """Set the content widget for this section."""
        self.content_layout.addWidget(widget)

    def set_content_height(self, height: int):
        """Set the content area height."""
        self._content_height = max(self._min_height, min(self._max_height, height))
        self._update_height()

    def _update_height(self):
        """Update the widget height based on content height."""
        total = self._content_height + self.drag_bar.height()
        self.setFixedHeight(total)
        # Force parent layout to recalculate
        self.updateGeometry()
        if self.parent() and self.parent().layout():
            self.parent().layout().invalidate()
            self.parent().layout().activate()

    def eventFilter(self, obj, event):
        if obj == self.drag_bar:
            if event.type() == QEvent.Type.MouseButtonPress:
                self._dragging = True
                self._drag_start_y = event.globalPosition().y()
                self._drag_start_height = self._content_height
                return True
            elif event.type() == QEvent.Type.MouseMove and self._dragging:
                delta = event.globalPosition().y() - self._drag_start_y
                new_height = self._drag_start_height + delta
                self._content_height = max(self._min_height, min(self._max_height, int(new_height)))
                self._update_height()
                return True
            elif event.type() == QEvent.Type.MouseButtonRelease:
                self._dragging = False
                return True
        return super().eventFilter(obj, event)


class BackgroundHistoryPopup(QWidget):
    sent = Signal(str, dict)

    def update_gender(self, gender: str):
        """Update pronouns when gender changes on front page."""
        self.gender = gender
        self.p = pronouns_from_gender(gender)
        # Regenerate all sentences with new pronouns
        for key in list(self._sentences.keys()):
            # Get the original sentence from personal_history (without pronouns applied)
            original = self.personal_history.get(key)
            if original:
                self._sentences[key] = self._apply_pronouns(original)
        self._refresh_preview()

    def __init__(self, first_name: str = None, gender: str = None, parent=None):
        super().__init__(parent)

        # Window behaviour — fixed panel
        self.setWindowFlags(Qt.WindowType.Widget)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)

        # ----------------------------------------------------
        # STATE
        # ----------------------------------------------------
        self.first_name = first_name
        self.gender = gender
        self.p = pronouns_from_gender(gender)

        self.personal_history: PersonalHistoryState = empty_personal_history_state()

        # sentence store (canonical prose units)
        self._sentences: dict[str, str] = {}
        self._active_key: str | None = None

        # ====================================================
        # UI - Scroll area containing all sections
        # ====================================================
        root = QVBoxLayout(self)
        root.setContentsMargins(0, 0, 0, 0)
        root.setSpacing(0)

        # Main scroll area
        main_scroll = QScrollArea()
        main_scroll.setWidgetResizable(True)
        main_scroll.setFrameShape(QScrollArea.NoFrame)
        main_scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        main_scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        main_container = QWidget()
        main_layout = QVBoxLayout(main_container)
        main_layout.setContentsMargins(4, 4, 4, 4)
        main_layout.setSpacing(8)

        # ====================================================
        # INPUT FORM (collapsible with drag bar)
        # ====================================================
        self.input_section = CollapsibleSection("Input Fields", start_collapsed=False)
        self.input_section.set_content_height(500)
        self.input_section._min_height = 200
        self.input_section._max_height = 800
        self.input_section.set_header_style("""
            QFrame {
                background: rgba(0, 140, 126, 0.15);
                border: 1px solid rgba(0, 140, 126, 0.3);
                border-radius: 6px 6px 0 0;
            }
        """)

        # Scrolling form container
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)

        container = QWidget()
        container.setStyleSheet("""
            QWidget {
                background: rgba(255,255,255,0.92);
                border: 1px solid rgba(0,0,0,0.15);
                border-top: none;
                border-radius: 0 0 12px 12px;
            }

            QRadioButton,
            QCheckBox {
                background: transparent;
                border: none;
                padding: 2px 0px;
                spacing: 8px;
                font-size: 22px;
            }

            QRadioButton::indicator,
            QCheckBox::indicator {
                width: 14px;
                height: 14px;
                margin-right: 6px;
            }

            QRadioButton::indicator:unchecked {
                border: 1px solid rgba(0,0,0,0.35);
                border-radius: 7px;
                background: transparent;
            }

            QRadioButton::indicator:checked {
                border: 1px solid #008C7E;
                background: #008C7E;
                border-radius: 7px;
            }

            QLabel {
                background: transparent;
                border: none;
            }
        """)

        scroll.setWidget(container)

        form_layout = QVBoxLayout(container)
        form_layout.setContentsMargins(16, 14, 16, 14)
        form_layout.setSpacing(6)

        # Helper functions
        def column(title: str, widget: QWidget):
            col = QVBoxLayout()
            col.setSpacing(4)
            col.setAlignment(Qt.AlignTop)

            lbl = QLabel(title)
            lbl.setStyleSheet("""
                QLabel {
                    font-size:21px;
                    font-weight:600;
                    color:#003c32;
                    margin: 0px;
                    padding: 0px 0px 4px 0px;
                }
            """)
            lbl.setAlignment(Qt.AlignLeft | Qt.AlignTop)

            col.addWidget(lbl)
            col.addWidget(widget)
            return col

        def section_divider(title: str):
            wrapper = QVBoxLayout()
            wrapper.setSpacing(6)

            lbl = QLabel(title)
            lbl.setStyleSheet("""
                QLabel {
                    font-size:21px;
                    font-weight:600;
                    color:#003c32;
                }
            """)

            line = QWidget()
            line.setFixedHeight(1)
            line.setStyleSheet("background: rgba(0,0,0,0.12);")

            wrapper.addWidget(lbl)
            wrapper.addWidget(line)

            form_layout.addLayout(wrapper)

        # ====================================================
        # WIDGETS (ORDERED)
        # ====================================================
        # EARLY DEVELOPMENT
        section_divider("Early development")

        self.birth_widget = BirthWidget()
        self.birth_widget.sentence_changed.connect(
            lambda s: self._set_sentence("BIRTH", s)
        )

        self.milestones_widget = MilestonesWidget()
        self.milestones_widget.sentence_changed.connect(
            lambda s: self._set_sentence("MILESTONES", s)
        )
        form_layout.addLayout(column("Birth", self.birth_widget))
        form_layout.addLayout(column("Developmental milestones", self.milestones_widget))

        # FAMILY & CHILDHOOD
        section_divider("Family & childhood")

        self.family_history_widget = FamilyHistoryWidget()
        self.family_history_widget.sentence_changed.connect(
            lambda s: self._set_sentence("FAMILY_HISTORY", s)
        )

        self.abuse_widget = AbuseWidget()
        self.abuse_widget.sentence_changed.connect(
            lambda s: self._set_sentence("ABUSE", s)
        )

        form_layout.addLayout(column("Family history", self.family_history_widget))
        form_layout.addLayout(column("Childhood abuse", self.abuse_widget))

        # EDUCATION & WORK
        section_divider("Education & work")

        self.schooling_widget = SchoolingWidget()
        self.schooling_widget.sentence_changed.connect(
            lambda s: self._set_sentence("SCHOOLING", s)
        )

        self.qualifications_widget = QualificationsWidget()
        self.qualifications_widget.sentence_changed.connect(
            lambda s: self._set_sentence("QUALIFICATIONS", s)
        )

        self.work_history_widget = WorkHistoryWidget()
        self.work_history_widget.sentence_changed.connect(
            lambda s: self._set_sentence("WORK_HISTORY", s)
        )

        form_layout.addLayout(column("Schooling", self.schooling_widget))
        form_layout.addLayout(column("Qualifications", self.qualifications_widget))
        form_layout.addLayout(column("Work history", self.work_history_widget))

        # IDENTITY & RELATIONSHIPS
        section_divider("Identity & relationships")

        self.sexual_orientation_widget = SexualOrientationWidget()
        self.sexual_orientation_widget.sentence_changed.connect(
            lambda s: self._set_sentence("SEXUAL_ORIENTATION", s)
        )

        self.children_widget = ChildrenWidget()
        self.children_widget.sentence_changed.connect(
            lambda s: self._set_sentence("CHILDREN", s)
        )

        self.relationships_widget = RelationshipsWidget()
        self.relationships_widget.sentence_changed.connect(
            lambda s: self._set_sentence("RELATIONSHIPS", s)
        )

        form_layout.addLayout(column("Sexual orientation", self.sexual_orientation_widget))
        form_layout.addLayout(column("Children", self.children_widget))
        form_layout.addLayout(column("Relationships", self.relationships_widget))

        self.input_section.set_content(scroll)
        main_layout.addWidget(self.input_section)

        # ====================================================
        # SECTION 3: EXTRACTED DATA (collapsible, at bottom)
        # ====================================================
        self.extracted_section = CollapsibleSection("Imported Data", start_collapsed=True)
        self.extracted_section.set_content_height(150)
        self.extracted_section._min_height = 120
        self.extracted_section._max_height = 400
        self.extracted_section.set_header_style("""
            QFrame {
                background: rgba(255, 248, 220, 0.95);
                border: 1px solid rgba(180, 150, 50, 0.4);
                border-radius: 6px 6px 0 0;
            }
        """)
        self.extracted_section.set_title_style("""
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

        # Container for checkboxes
        self.extracted_container = QWidget()
        self.extracted_container.setStyleSheet("background: transparent;")
        self.extracted_checkboxes_layout = QVBoxLayout(self.extracted_container)
        self.extracted_checkboxes_layout.setContentsMargins(2, 2, 2, 2)
        self.extracted_checkboxes_layout.setSpacing(12)
        self.extracted_checkboxes_layout.setAlignment(Qt.AlignTop)

        extracted_scroll.setWidget(self.extracted_container)
        extracted_layout.addWidget(extracted_scroll)

        self.extracted_section.set_content(extracted_content)
        self.extracted_section.setVisible(False)  # Hidden until data loaded
        main_layout.addWidget(self.extracted_section)

        # Store extracted checkboxes
        self._extracted_checkboxes = []

        # Add stretch at bottom
        main_layout.addStretch()

        main_scroll.setWidget(main_container)
        root.addWidget(main_scroll)

        self._refresh_preview()

        # Add lock functionality
        add_lock_to_popup(self, show_button=False)

    # ======================================================
    # SENTENCE HANDLING
    # ======================================================
    def _set_sentence(self, key: str, sentence: str):
        self.personal_history[key] = sentence

        if sentence:
            self._sentences[key] = self._apply_pronouns(sentence)
            self._active_key = key
        else:
            self._sentences.pop(key, None)
            if self._active_key == key:
                self._active_key = None

        self._refresh_preview()

    def _apply_pronouns(self, text: str) -> str:
        subj = self.p["subj"]
        obj = self.p["obj"]
        pos = self.p["pos"]
        have = self.p["have"]
        are = self.p["are"]
        were = self.p["were"]

        # Replace "They have" → "She has" / "He has" (verb conjugation)
        text = re.sub(r"\bThey have\b", f"{subj.capitalize()} {have}", text)
        text = re.sub(r"\bthey have\b", f"{subj} {have}", text)

        # Replace "They are" → "She is" / "He is" (verb conjugation)
        text = re.sub(r"\bThey are\b", f"{subj.capitalize()} {are}", text)
        text = re.sub(r"\bthey are\b", f"{subj} {are}", text)

        # Replace "They were" → "She was" / "He was" (verb conjugation)
        text = re.sub(r"\bThey were\b", f"{subj.capitalize()} {were}", text)
        text = re.sub(r"\bthey were\b", f"{subj} {were}", text)

        # Replace They/Their/Them (default pronouns from widgets)
        replacements = [
            (r"\bThey\b", subj.capitalize()),
            (r"\bthey\b", subj),
            (r"\bTheir\b", pos.capitalize()),
            (r"\btheir\b", pos),
            (r"\bThem\b", obj.capitalize()),
            (r"\bthem\b", obj),
            # Also handle He/His/Him for any male-default templates
            (r"(?<!T)\bHe\b", subj.capitalize()),
            (r"(?<!T)\bhe\b", subj),
            (r"\bHis\b", pos.capitalize()),
            (r"\bhis\b", pos),
            (r"\bHim\b", obj.capitalize()),
            (r"\bhim\b", obj),
        ]

        for pattern, repl in replacements:
            text = re.sub(pattern, repl, text)

        return text

    def _strip_preview_highlight(self, html: str) -> str:
        # remove ONLY the active-sentence highlight span
        html = re.sub(
            r"<span[^>]*background:[^>]*>(.*?)</span>",
            r"\1",
            html,
            flags=re.DOTALL,
        )
        return html

    # ======================================================
    # GENERATE TEXT AND SEND TO CARD
    # ======================================================
    def _generate_text(self) -> str:
        """Generate the background history text."""
        paragraphs = []

        def take(*keys):
            bits = [self._sentences.get(k) for k in keys if k in self._sentences]
            if bits:
                paragraphs.append(" ".join(bits))

        take("BIRTH")
        take("MILESTONES")
        take("FAMILY_HISTORY")
        take("ABUSE")

        # merged education
        take("SCHOOLING", "QUALIFICATIONS")

        take("WORK_HISTORY")
        take("SEXUAL_ORIENTATION")
        take("CHILDREN")
        take("RELATIONSHIPS")

        # Collect checked extracted entries
        extracted_paragraphs = []
        if hasattr(self, '_extracted_checkboxes'):
            for cb in self._extracted_checkboxes:
                if cb.isChecked():
                    extracted_paragraphs.append(cb.property("full_text"))

        # Combine with blank line separator between sections
        if paragraphs and extracted_paragraphs:
            return " ".join(paragraphs) + "\n\n" + "\n\n".join(extracted_paragraphs)
        elif paragraphs:
            return " ".join(paragraphs)
        elif extracted_paragraphs:
            return "\n\n".join(extracted_paragraphs)
        return ""

    def _refresh_preview(self):
        """Legacy method name - now sends to card immediately."""
        self._send_to_card()

    def _send_to_card(self):
        """Send current text to card immediately."""
        text = self._generate_text().strip()
        if text:
            self.sent.emit(text, {})

    # ======================================================
    # SEND TO LETTER
    # ======================================================
    def _send_to_letter(self):
        # Build clean, highlight-free text from canonical sentences
        paragraphs = []

        def take(*keys):
            bits = [
                self._sentences.get(k)
                for k in keys
                if self._sentences.get(k)
            ]
            if bits:
                paragraphs.append(" ".join(bits))

        take("BIRTH")
        take("MILESTONES")
        take("FAMILY_HISTORY")
        take("ABUSE")
        take("SCHOOLING", "QUALIFICATIONS")
        take("WORK_HISTORY")
        take("SEXUAL_ORIENTATION")
        take("CHILDREN")
        take("RELATIONSHIPS")

        # Collect checked extracted entries
        extracted_paragraphs = []
        if hasattr(self, '_extracted_checkboxes'):
            for cb in self._extracted_checkboxes:
                if cb.isChecked():
                    extracted_paragraphs.append(cb.property("full_text"))

        # Combine with blank line separator between sections
        if paragraphs and extracted_paragraphs:
            text = " ".join(paragraphs) + "\n\n" + "\n\n".join(extracted_paragraphs)
        elif paragraphs:
            text = " ".join(paragraphs)
        elif extracted_paragraphs:
            text = "\n\n".join(extracted_paragraphs)
        else:
            text = ""

        text = text.strip()
        if not text:
            return

        # Persist state
        self.personal_history.update({
            "BIRTH": self.birth_widget.get_value(),
            "MILESTONES": self.milestones_widget.get_value(),
            "FAMILY_HISTORY": self.family_history_widget.get_value(),
            "ABUSE": self.abuse_widget.get_state(),
            "SCHOOLING": self.schooling_widget.get_state(),
            "QUALIFICATIONS": self.qualifications_widget.get_value(),
            "WORK_HISTORY": self.work_history_widget.get_state(),
            "SEXUAL_ORIENTATION": self.sexual_orientation_widget.get_value(),
            "CHILDREN": self.children_widget.get_state(),
            "RELATIONSHIPS": self.relationships_widget.get_state(),
        })

        self.personal_history["_meta"] = {
            "active_sentence": self._active_key
        }

        self.sent.emit(text, self.personal_history)
        self.close()

    # ======================================================
    # LOAD STATE (RECALL + HIGHLIGHT RESTORE)
    # ======================================================
    def load_state(self, state: PersonalHistoryState | None):
        self.personal_history = state or empty_personal_history_state()

        # restore highlight metadata
        meta = self.personal_history.get("_meta", {})
        self._active_key = meta.get("active_sentence")

        # restore widgets + sentences
        def restore(key, widget, setter):
            value = self.personal_history.get(key)
            if not value:
                return

            setter(value)

            # regenerate sentence via widget logic
            if hasattr(widget, "sentence_changed"):
                try:
                    widget.sentence_changed.emit(
                        widget._to_sentence(value)
                        if hasattr(widget, "_to_sentence")
                        else ""
                    )
                except Exception:
                    pass

        restore("BIRTH", self.birth_widget, self.birth_widget.set_value)
        restore("MILESTONES", self.milestones_widget, self.milestones_widget.set_value)
        restore("FAMILY_HISTORY", self.family_history_widget, self.family_history_widget.set_value)
        restore("ABUSE", self.abuse_widget, self.abuse_widget.set_state)
        restore("SCHOOLING", self.schooling_widget, self.schooling_widget.set_state)
        restore("QUALIFICATIONS", self.qualifications_widget, self.qualifications_widget.set_value)
        restore("WORK_HISTORY", self.work_history_widget, self.work_history_widget.set_state)
        restore("SEXUAL_ORIENTATION", self.sexual_orientation_widget, self.sexual_orientation_widget.set_value)
        restore("CHILDREN", self.children_widget, self.children_widget.set_state)
        restore("RELATIONSHIPS", self.relationships_widget, self.relationships_widget.set_state)

        self._refresh_preview()

    def closeEvent(self, event):
        self.personal_history.update({
            "BIRTH": self.birth_widget.get_value(),
            "MILESTONES": self.milestones_widget.get_value(),
            "FAMILY_HISTORY": self.family_history_widget.get_value(),
            "ABUSE": self.abuse_widget.get_state(),
            "SCHOOLING": self.schooling_widget.get_state(),
            "QUALIFICATIONS": self.qualifications_widget.get_value(),
            "WORK_HISTORY": self.work_history_widget.get_state(),
            "SEXUAL_ORIENTATION": self.sexual_orientation_widget.get_value(),
            "CHILDREN": self.children_widget.get_state(),
            "RELATIONSHIPS": self.relationships_widget.get_state(),
        })

        super().closeEvent(event)

    def set_extracted_data(self, items):
        """Display extracted data from notes with collapsible dated entry boxes.

        Args:
            items: List of dicts with 'date' and 'text' keys, or a string (legacy)
        """
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

                # Header row with toggle button, date, and checkbox
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
                cb.stateChanged.connect(self._refresh_preview)
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

            self.extracted_section.setVisible(True)
            # Keep collapsed on open
            # if self.extracted_section._is_collapsed:
            #     self.extracted_section._toggle_collapse()
        else:
            self.extracted_section.setVisible(False)
