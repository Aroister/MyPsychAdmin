# ui_icons.py
# Centralised icon loader for Patient Notes (restores original icon behaviour)

import os
from PySide6.QtGui import QIcon
from utils.resource_path import resource_path

ICON_MAP = {
    "nursing": "nursing.png",
    "medical": "medical.png",
    "therapy": "therapy.png",
    "social": "social.png",
    "hca": "hca.png",
    "other": "other.png",
}


def get_icon(note_type):
    """Return QIcon based on note_type text."""
    if not note_type:
        return QIcon(_path("other.png"))

    t = note_type.lower()

    if "nurs" in t:
        return QIcon(_path("nursing.png"))
    if "medic" in t:
        return QIcon(_path("medical.png"))
    if "therap" in t or "psychol" in t:
        return QIcon(_path("therapy.png"))
    if "social" in t:
        return QIcon(_path("social.png"))
    if "health care assistant" in t or "hca" in t:
        return QIcon(_path("hca.png"))

    return QIcon(_path("other.png"))


def _path(filename):
    """Return OS path to the icon file."""
    return resource_path("resources", "icons", filename)
