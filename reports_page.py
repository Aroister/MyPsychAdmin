# ================================================================
#  REPORTS PAGE — Select and generate psychiatric reports
# ================================================================

from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QFrame, QGridLayout, QSizePolicy, QScrollArea
)


class ReportTypeCard(QFrame):
    """A clickable card for selecting a report type."""

    clicked = Signal(str)  # Emits report type key

    def __init__(self, title: str, description: str, key: str, icon: str = "", parent=None):
        super().__init__(parent)
        self.key = key
        self.setFixedSize(400, 336)  # Reduced by 20%
        self.setCursor(Qt.CursorShape.PointingHandCursor)

        self.setStyleSheet("""
            ReportTypeCard {
                background: white;
                border: 2px solid #e5e7eb;
                border-radius: 13px;
            }
            ReportTypeCard:hover {
                border-color: #8b5cf6;
                background: #faf5ff;
            }
        """)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 10, 16, 10)  # Reduced by 20%
        layout.setSpacing(5)  # Reduced by 20%

        # Icon (emoji or text)
        if icon:
            icon_lbl = QLabel(icon)
            icon_lbl.setStyleSheet("font-size: 45px;")  # Reduced by 20%
            icon_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
            layout.addWidget(icon_lbl)

        # Title
        title_lbl = QLabel(title)
        title_lbl.setStyleSheet("""
            font-size: 26px;
            font-weight: 700;
            color: #1f2937;
        """)  # Reduced by 20%
        title_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title_lbl)

        # Description
        desc_lbl = QLabel(description)
        desc_lbl.setWordWrap(True)
        desc_lbl.setStyleSheet("""
            font-size: 16px;
            color: #6b7280;
        """)  # Reduced by 20%
        desc_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(desc_lbl)

        layout.addStretch()

    def mousePressEvent(self, event):
        self.clicked.emit(self.key)
        super().mousePressEvent(event)


class TribunalReportCard(QFrame):
    """A card for Tribunal reports with sub-type options."""

    subtype_selected = Signal(str)  # Emits subtype key

    def __init__(self, title: str, description: str, subtypes: list, icon: str = "", parent=None):
        super().__init__(parent)
        self.subtypes = subtypes
        self.setFixedSize(400, 336)  # Reduced by 20%

        self.setStyleSheet("""
            TribunalReportCard {
                background: white;
                border: 2px solid #e5e7eb;
                border-radius: 13px;
            }
        """)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(32, 10, 32, 10)  # Reduced by 20%
        layout.setSpacing(5)  # Reduced by 20%

        # Icon
        if icon:
            icon_lbl = QLabel(icon)
            icon_lbl.setStyleSheet("font-size: 45px;")  # Reduced by 20%
            icon_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
            layout.addWidget(icon_lbl)

        # Title
        title_lbl = QLabel(title)
        title_lbl.setStyleSheet("""
            font-size: 26px;
            font-weight: 700;
            color: #1f2937;
        """)  # Reduced by 20%
        title_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title_lbl)

        # Description
        desc_lbl = QLabel(description)
        desc_lbl.setWordWrap(True)
        desc_lbl.setStyleSheet("""
            font-size: 16px;
            color: #6b7280;
        """)  # Reduced by 20%
        desc_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(desc_lbl)

        layout.addSpacing(6)  # Reduced by 20%

        # Sub-type buttons
        for subtype in subtypes:
            btn = QPushButton(subtype["label"])
            btn.setCursor(Qt.CursorShape.PointingHandCursor)
            btn.setFixedHeight(35)  # Reduced by 20%
            btn.setStyleSheet("""
                QPushButton {
                    background: #f3f4f6;
                    color: #374151;
                    border: 1px solid #d1d5db;
                    padding: 5px 10px;
                    border-radius: 6px;
                    font-size: 14px;
                    font-weight: 600;
                }
                QPushButton:hover {
                    background: #8b5cf6;
                    color: white;
                    border-color: #8b5cf6;
                }
            """)  # Reduced by 20%
            btn.clicked.connect(lambda checked, k=subtype["key"]: self.subtype_selected.emit(k))
            layout.addWidget(btn)


class ReportsPage(QWidget):
    """Page for selecting and generating psychiatric reports."""

    report_selected = Signal(str)  # Emits report type key

    REPORT_TYPES = [
        {
            "key": "general_psychiatric",
            "title": "General Psychiatric",
            "description": "Standard psychiatric assessment report for referrals and clinical correspondence",
            "icon": "📋"
        },
        {
            "key": "tribunal",
            "title": "Tribunal Report",
            "description": "Mental Health Tribunal report with statutory requirements and recommendations",
            "icon": "⚖️",
            "subtypes": [
                {"key": "tribunal_psychiatric", "label": "Psychiatric"},
                {"key": "tribunal_nursing", "label": "Nursing"},
                {"key": "tribunal_social", "label": "Social Circumstances"},
            ]
        },
    ]

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)

        self._setup_ui()

    def _setup_ui(self):
        outer_layout = QVBoxLayout(self)
        outer_layout.setContentsMargins(0, 0, 0, 0)

        # Scroll area
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        scroll.setVerticalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAsNeeded)
        outer_layout.addWidget(scroll)

        # Content container
        content = QWidget()
        scroll.setWidget(content)

        layout = QVBoxLayout(content)
        layout.setContentsMargins(60, 40, 60, 40)
        layout.setSpacing(32)

        # Header
        header = QLabel("Reports")
        header.setStyleSheet("""
            font-size: 64px;
            font-weight: 700;
            color: #1f2937;
        """)
        header.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(header)

        # Subtitle
        subtitle = QLabel("Select a report type to begin")
        subtitle.setStyleSheet("""
            font-size: 32px;
            color: #6b7280;
        """)
        subtitle.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(subtitle)

        layout.addSpacing(20)

        # Cards container
        cards_container = QWidget()
        cards_layout = QHBoxLayout(cards_container)
        cards_layout.setContentsMargins(0, 0, 0, 0)
        cards_layout.setSpacing(24)
        cards_layout.setAlignment(Qt.AlignmentFlag.AlignHCenter | Qt.AlignmentFlag.AlignTop)

        for report in self.REPORT_TYPES:
            if "subtypes" in report:
                # Create card with sub-options
                card = TribunalReportCard(
                    title=report["title"],
                    description=report["description"],
                    subtypes=report["subtypes"],
                    icon=report["icon"],
                    parent=self
                )
                card.subtype_selected.connect(self._on_report_selected)
            else:
                card = ReportTypeCard(
                    title=report["title"],
                    description=report["description"],
                    key=report["key"],
                    icon=report["icon"],
                    parent=self
                )
                card.clicked.connect(self._on_report_selected)
            cards_layout.addWidget(card)

        layout.addWidget(cards_container)
        layout.addStretch()

    def _on_report_selected(self, key: str):
        print(f"[REPORTS] Selected report type: {key}")
        self.report_selected.emit(key)
