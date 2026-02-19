# ================================================================
#  FORMS PAGE — Select and generate MHA statutory forms
# ================================================================

from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QFrame, QSizePolicy, QScrollArea
)
from PySide6.QtGui import QColor
from ui_effects import GlowCardMixin


class FormCard(GlowCardMixin, QFrame):
    """A card for a form category with clickable form buttons grouped by section."""

    form_selected = Signal(str)  # Emits form key

    def __init__(self, title: str, description: str, icon: str, form_groups: list, color: str = "#2563eb", parent=None):
        super().__init__(parent)
        self.setFixedSize(400, 336)  # Reduced by 20%

        # Initialize glow effect with card's color
        self._init_glow(glow_color=QColor(color), header_height=112)  # Reduced by 20%

        self.setStyleSheet(f"""
            FormCard {{
                background: transparent;
                border: 2px solid #e5e7eb;
                border-radius: 13px;
            }}
            FormCard:hover {{
                border-color: {color};
            }}
        """)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 10, 16, 10)  # Reduced by 20%
        layout.setSpacing(5)  # Reduced by 20%

        # Icon
        icon_lbl = QLabel(icon)
        icon_lbl.setStyleSheet("font-size: 45px; border: none;")  # Reduced by 20%
        icon_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(icon_lbl)

        # Title
        title_lbl = QLabel(title)
        title_lbl.setStyleSheet(f"font-size: 26px; font-weight: 700; color: {color}; border: none;")  # Reduced by 20%
        title_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(title_lbl)

        # Description
        desc_lbl = QLabel(description)
        desc_lbl.setWordWrap(True)
        desc_lbl.setStyleSheet("font-size: 16px; color: #6b7280; border: none;")  # Reduced by 20%
        desc_lbl.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(desc_lbl)

        # Scrollable area for form buttons
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        scroll.setStyleSheet("QScrollArea { background: transparent; border: none; }")

        scroll_content = QWidget()
        scroll_content.setStyleSheet("background: transparent;")
        scroll_layout = QVBoxLayout(scroll_content)
        scroll_layout.setContentsMargins(0, 4, 4, 0)
        scroll_layout.setSpacing(4)

        # Form groups with labels
        for group in form_groups:
            # Group label
            group_lbl = QLabel(group["label"])
            group_lbl.setStyleSheet(f"font-size: 14px; font-weight: 600; color: {group.get('color', '#6b7280')}; border: none; margin-top: 6px;")  # Reduced by 20%
            scroll_layout.addWidget(group_lbl)

            # Form buttons in this group
            for form in group["forms"]:
                btn = QPushButton(f"{form['title']} - {form['desc']}")
                btn.setCursor(Qt.CursorShape.PointingHandCursor)
                btn.setFixedHeight(35)  # Reduced by 20%
                btn.setStyleSheet(f"""
                    QPushButton {{
                        background: #f3f4f6;
                        color: #374151;
                        border: 1px solid #d1d5db;
                        padding: 5px 10px;
                        border-radius: 6px;
                        font-size: 14px;
                        font-weight: 500;
                        text-align: left;
                    }}
                    QPushButton:hover {{
                        background: {color};
                        color: white;
                        border-color: {color};
                    }}
                """)
                btn.clicked.connect(lambda checked, k=form["key"]: self.form_selected.emit(k))
                scroll_layout.addWidget(btn)

        scroll.setWidget(scroll_content)
        layout.addWidget(scroll)


class FormsPage(QWidget):
    """Page for selecting and generating MHA statutory forms."""

    form_selected = Signal(str)  # Emits form type key

    MHA_FORM_GROUPS = [
        {
            "label": "Social Work",
            "color": "#059669",
            "forms": [
                {"key": "a2", "title": "A2", "desc": "S2 AMHP application"},
                {"key": "a6", "title": "A6", "desc": "S3 AMHP application"},
            ]
        },
        {
            "label": "Medical - Joint",
            "color": "#7c3aed",
            "forms": [
                {"key": "a3", "title": "A3", "desc": "S2 joint recommendation"},
                {"key": "a7", "title": "A7", "desc": "S3 joint recommendation"},
            ]
        },
        {
            "label": "Medical - Single",
            "color": "#7c3aed",
            "forms": [
                {"key": "a4", "title": "A4", "desc": "S2 single recommendation"},
                {"key": "a8", "title": "A8", "desc": "S3 single recommendation"},
            ]
        },
        {
            "label": "Holding Power",
            "color": "#dc2626",
            "forms": [
                {"key": "h1", "title": "H1", "desc": "S5(2) hospital in-patient"},
                {"key": "h5", "title": "H5", "desc": "S20 renewal of detention"},
            ]
        },
        {
            "label": "CTO - Initial/Extend",
            "color": "#0891b2",
            "forms": [
                {"key": "cto1", "title": "CTO1", "desc": "S17A community treatment order"},
                {"key": "cto7", "title": "CTO7", "desc": "S20A report extending CTO"},
            ]
        },
        {
            "label": "CTO - Recall/Revoke",
            "color": "#ea580c",
            "forms": [
                {"key": "cto3", "title": "CTO3", "desc": "S17E notice of recall"},
                {"key": "cto4", "title": "CTO4", "desc": "S17E record of detention"},
                {"key": "cto5", "title": "CTO5", "desc": "S17F(4) revocation of CTO"},
            ]
        },
        {
            "label": "Consent & Discharge",
            "color": "#be185d",
            "forms": [
                {"key": "t2", "title": "T2", "desc": "S58 consent to treatment"},
                {"key": "m2", "title": "M2", "desc": "S25 barring discharge"},
            ]
        },
    ]

    MOJ_FORM_GROUPS = [
        {
            "label": "Leave Applications",
            "color": "#991b1b",
            "forms": [
                {"key": "moj_leave", "title": "Leave", "desc": "MHCS Leave Application"},
            ]
        },
        {
            "label": "Statutory Reports",
            "color": "#7c3aed",
            "forms": [
                {"key": "moj_asr", "title": "ASR", "desc": "Annual Statutory Report"},
            ]
        },
    ]

    RISK_FORM_GROUPS = [
        {
            "label": "Violence Risk",
            "color": "#1e40af",
            "forms": [
                {"key": "hcr20", "title": "HCR-20 V3", "desc": "Violence Risk Assessment"},
            ]
        },
    ]

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Expanding)
        self._setup_ui()

    def _setup_ui(self):
        main_layout = QVBoxLayout(self)
        main_layout.setContentsMargins(0, 0, 0, 0)

        # Scroll area for entire page
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)

        scroll_content = QWidget()
        layout = QVBoxLayout(scroll_content)
        layout.setContentsMargins(60, 40, 60, 40)
        layout.setSpacing(32)

        # Header
        header = QLabel("Forms")
        header.setStyleSheet("font-size: 64px; font-weight: 700; color: #1f2937;")
        header.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(header)

        # Subtitle
        subtitle = QLabel("Select a form to begin")
        subtitle.setStyleSheet("font-size: 32px; color: #6b7280;")
        subtitle.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(subtitle)

        layout.addSpacing(20)

        # Cards container
        cards_container = QWidget()
        cards_layout = QHBoxLayout(cards_container)
        cards_layout.setContentsMargins(0, 0, 0, 0)
        cards_layout.setSpacing(24)
        cards_layout.setAlignment(Qt.AlignmentFlag.AlignHCenter | Qt.AlignmentFlag.AlignTop)

        # MHA Card
        mha_card = FormCard(
            title="MHA",
            description="Mental Health Act 1983 Statutory Forms",
            icon="📋",
            form_groups=self.MHA_FORM_GROUPS,
            color="#2563eb",
            parent=self
        )
        mha_card.form_selected.connect(self._on_form_selected)
        cards_layout.addWidget(mha_card)

        # MOJ Card
        moj_card = FormCard(
            title="MOJ",
            description="Ministry of Justice Forms",
            icon="⚖️",
            form_groups=self.MOJ_FORM_GROUPS,
            color="#dc2626",
            parent=self
        )
        moj_card.form_selected.connect(self._on_form_selected)
        cards_layout.addWidget(moj_card)

        # Risk Assessment Card
        risk_card = FormCard(
            title="Risk",
            description="Risk Assessment Tools",
            icon="⚠️",
            form_groups=self.RISK_FORM_GROUPS,
            color="#1e40af",
            parent=self
        )
        risk_card.form_selected.connect(self._on_form_selected)
        cards_layout.addWidget(risk_card)

        layout.addWidget(cards_container, 1)

        scroll.setWidget(scroll_content)
        main_layout.addWidget(scroll)

    def _on_form_selected(self, key: str):
        print(f"[FORMS] Selected form type: {key}")
        self.form_selected.emit(key)
