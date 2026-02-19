# -*- mode: python ; coding: utf-8 -*-
# Windows build spec file for MyPsy
# Run on Windows with: pyinstaller MyPsy_Windows.spec

import os
from PyInstaller.utils.hooks import collect_submodules, collect_dynamic_libs

APP_NAME = "MyPsy"

# Hidden imports
hidden = []
hidden += collect_submodules("numpy")
hidden += collect_submodules("PySide6")
hidden += collect_submodules("matplotlib")
hidden += ["matplotlib.backends.backend_qtagg"]

hidden += [
    "importer_pdf",
    "importer_docx",
    "importer_common",
    "importer_rio",
    "importer_autodetect",
    "importer_carenotes",
    "importer_epjs",
]

hidden += [
    "patient_notes_panel",
    "patient_history_panel",
    "physical_health_panel",
    "medication_panel",
    "timeline_builder",
    "history_extractor_sections",
]

# Collect numpy binaries
numpy_binaries = collect_dynamic_libs("numpy")

datas = [
    ("resources/public_key.pem", "resources"),
    ("resources/icons", "resources/icons"),
    # Data files needed at runtime
    ("Letter_headings_search_v2.txt", "."),
    ("Letter headings search.txt", "."),
    ("ICD10_DICT.txt", "."),
    ("incidentDICT.txt", "."),
    ("riskDICT.txt", "."),
    ("medical_dictionary.txt", "."),
    # Templates and config
    ("templates", "templates"),
    ("config", "config"),
]

a = Analysis(
    ['main.py'],
    pathex=[os.path.abspath('.')],
    binaries=numpy_binaries,
    datas=datas,
    hiddenimports=hidden,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)

pyz = PYZ(a.pure, a.zipped_data)

# ---------------------------------------------------------
# Build the Windows executable
# ---------------------------------------------------------
exe = EXE(
    pyz,
    a.scripts,
    a.binaries,
    a.datas,
    [],
    name=APP_NAME,
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    upx_exclude=[],
    runtime_tmpdir=None,
    console=False,  # Set to True for debugging
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon='resources/icons/MyPsy.ico',  # Windows icon (convert from icns if needed)
)
