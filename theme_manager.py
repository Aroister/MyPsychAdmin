# theme_manager.py — final stable version

from __future__ import annotations
from PySide6.QtGui import QPalette, QColor
from PySide6.QtWidgets import QApplication
import json
import os

THEME_FILE = "theme.json"


class Theme:
    LIGHT = "light"
    DARK = "dark"


def load_theme() -> str:
    if not os.path.exists(THEME_FILE):
        return Theme.LIGHT
    try:
        with open(THEME_FILE, "r") as f:
            return json.load(f).get("theme", Theme.LIGHT)
    except:
        return Theme.LIGHT


def save_theme(theme: str):
    try:
        with open(THEME_FILE, "w") as f:
            json.dump({"theme": theme}, f, indent=2)
    except:
        pass


def apply_theme(app, theme: str):
    """
    Apply the theme to the entire application.
    This ONLY sets global palette colours.
    Each page (e.g. Notes) can override its own local CSS.
    """

    palette = QPalette()

    if theme == Theme.DARK:
        # Deep charcoal, soft contrast
        palette.setColor(QPalette.Window, QColor(30, 30, 30))
        palette.setColor(QPalette.WindowText, QColor(220, 220, 220))
        palette.setColor(QPalette.Base, QColor(40, 40, 40))
        palette.setColor(QPalette.AlternateBase, QColor(55, 55, 55))
        palette.setColor(QPalette.Text, QColor(220, 220, 220))
        palette.setColor(QPalette.Button, QColor(55, 55, 55))
        palette.setColor(QPalette.ButtonText, QColor(220, 220, 220))
        palette.setColor(QPalette.Highlight, QColor(255, 215, 0))
        palette.setColor(QPalette.HighlightedText, QColor(0, 0, 0))

    else:
        # Gentle light palette
        palette.setColor(QPalette.Window, QColor(230, 240, 250))
        palette.setColor(QPalette.WindowText, QColor(20, 20, 20))
        palette.setColor(QPalette.Base, QColor(255, 255, 255))
        palette.setColor(QPalette.AlternateBase, QColor(245, 245, 245))
        palette.setColor(QPalette.Text, QColor(20, 20, 20))
        palette.setColor(QPalette.Button, QColor(240, 240, 240))
        palette.setColor(QPalette.ButtonText, QColor(20, 20, 20))
        palette.setColor(QPalette.Highlight, QColor(255, 235, 59))
        palette.setColor(QPalette.HighlightedText, QColor(0, 0, 0))

    app_instance = QApplication.instance()
    if app_instance:
        app_instance.setPalette(palette)

        # Set QMessageBox stylesheet explicitly for Windows compatibility
        if theme == Theme.DARK:
            app_instance.setStyleSheet(app_instance.styleSheet() + """
                QMessageBox {
                    background-color: #1e1e1e;
                    color: #dcdcdc;
                }
                QMessageBox QLabel {
                    color: #dcdcdc;
                }
                QMessageBox QPushButton {
                    background-color: #373737;
                    color: #dcdcdc;
                    border: 1px solid #555555;
                    padding: 5px 15px;
                    min-width: 60px;
                }
                QMessageBox QPushButton:hover {
                    background-color: #4a4a4a;
                }
            """)
