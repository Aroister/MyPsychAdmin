# ui_core.py
from PySide6.QtWidgets import QLabel, QPushButton
from PySide6.QtGui import QFont, QColor
from PySide6.QtCore import Qt


# ---------------------------------------------------------
# HEADER LABEL
# ---------------------------------------------------------
class HeaderLabel(QLabel):
    def __init__(self, text="", parent=None):
        super().__init__(text, parent)

        self.setFont(QFont("Segoe UI", 22, QFont.Bold))
        self.setStyleSheet("""
            color: #0A3554;
            padding-left: 10px;
        """)
        self.setAlignment(Qt.AlignVCenter | Qt.AlignLeft)


# ---------------------------------------------------------
# NAV BUTTON (Navigation bar label-buttons)
# ---------------------------------------------------------
class NavButton(QLabel):
    """
    A clickable label used in the navigation bar.
    Turns blue on hover, blue highlight when active.
    """

    def __init__(self, text, parent=None):
        super().__init__(text, parent)

        self.active = False
        self.setFont(QFont("Segoe UI", 16, QFont.Bold))
        self.setAlignment(Qt.AlignCenter)

        self.setStyleSheet("""
            QLabel {
                color: #113A60;
                padding: 8px 20px;
            }
        """)

    def set_active(self, state: bool):
        """Turn the button blue + white when active."""
        self.active = state
        if state:
            self.setStyleSheet("""
                QLabel {
                    background-color: #1A73E8;
                    color: white;
                    padding: 8px 20px;
                    border-radius: 6px;
                }
            """)
        else:
            self.setStyleSheet("""
                QLabel {
                    color: #113A60;
                    padding: 8px 20px;
                }
            """)

    # clickable
    def mousePressEvent(self, event):
        if self.parent():
            # parent should implement on_nav_clicked(label)
            self.parent().on_nav_clicked(self.text())

from PySide6.QtWidgets import QLabel
from PySide6.QtCore import Qt

class HoverLabel(QLabel):
    def __init__(self, text="", parent=None):
        super().__init__(text, parent)
        self.setStyleSheet("""
            QLabel {
                color: white;
                font-size: 15px;
            }
        """)
        self.default_color = "white"
        self.hover_color = "white"  # Hover effect disabled

