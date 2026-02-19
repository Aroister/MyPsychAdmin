#!/usr/bin/env python3
"""Test the glow card effect. Run with: ./venv/bin/python3 test_glow.py"""

import sys
from PySide6.QtWidgets import QApplication, QVBoxLayout, QHBoxLayout, QWidget, QLabel, QFrame, QTextEdit
from PySide6.QtGui import QColor
from PySide6.QtCore import Qt, Signal

# Import the glow effect
from ui_effects import apply_glow_effect, GlowCard, GlowCardMixin


# Test card using the mixin (like CTO7CardWidget)
class TestMixinCard(GlowCardMixin, QFrame):
    clicked = Signal()

    def __init__(self, title, color, parent=None):
        super().__init__(parent)
        self._init_glow(glow_color=QColor(color), header_height=40)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(12, 10, 12, 10)
        layout.setSpacing(6)

        title_label = QLabel(title)
        title_label.setStyleSheet(f"font-size: 14px; font-weight: 700; color: {color};")
        layout.addWidget(title_label)

        self.content = QTextEdit()
        self.content.setPlaceholderText("Click to edit...")
        self.content.setStyleSheet("""
            QTextEdit {
                font-size: 12px;
                color: #374151;
                background: transparent;
                border: none;
            }
        """)
        self.content.setMaximumHeight(60)
        layout.addWidget(self.content)


class TestWindow(QWidget):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Glow Effect Test - Move mouse over cards")
        self.setFixedSize(700, 500)
        self.setStyleSheet("background: #f5f5f5;")

        layout = QVBoxLayout(self)
        layout.setSpacing(20)
        layout.setContentsMargins(30, 30, 30, 30)

        info = QLabel("Move your mouse over the cards below.\nThe glow should follow your cursor, brighter at the top (header area).")
        info.setStyleSheet("font-size: 14px; color: #666;")
        info.setAlignment(Qt.AlignmentFlag.AlignCenter)
        layout.addWidget(info)

        cards_row = QHBoxLayout()
        cards_row.setSpacing(20)

        # Test 1: GlowCard base class (blue)
        card1 = GlowCard(self, glow_color=QColor("#2563eb"), header_height=50)
        card1.set_glow_color(QColor("#2563eb"))
        card1.setFixedSize(200, 130)
        card1_layout = QVBoxLayout(card1)
        card1_label = QLabel("GlowCard\n(Blue)")
        card1_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        card1_label.setStyleSheet("font-size: 14px; color: #333; background: transparent;")
        card1_layout.addWidget(card1_label)
        cards_row.addWidget(card1)

        # Test 2: TestMixinCard (red) - simulates CTO7CardWidget
        card2 = TestMixinCard("Mixin Card", "#dc2626", self)
        card2.setFixedSize(200, 130)
        cards_row.addWidget(card2)

        # Test 3: QFrame with apply_glow_effect (green)
        card3 = QFrame(self)
        card3.setFixedSize(200, 130)
        apply_glow_effect(card3, glow_color=QColor("#059669"), header_height=50)
        card3_layout = QVBoxLayout(card3)
        card3_label = QLabel("apply_glow_effect\n(Green)")
        card3_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        card3_label.setStyleSheet("font-size: 14px; color: #333; background: transparent;")
        card3_layout.addWidget(card3_label)
        cards_row.addWidget(card3)

        layout.addLayout(cards_row)
        layout.addStretch()


if __name__ == "__main__":
    app = QApplication(sys.argv)
    window = TestWindow()
    window.show()
    print("Move mouse over the cards to see the glow effect.")
    print("Close window or press Ctrl+C to exit.")
    sys.exit(app.exec())
