# -*- mode: python ; coding: utf-8 -*-
# Windows build spec file for MyPsychAdmin
# Run on Windows with: pyinstaller MyPsychAdmin_Windows.spec

import os
from PyInstaller.utils.hooks import collect_submodules, collect_dynamic_libs, collect_data_files

APP_NAME = "MyPsychAdmin"

# Hidden imports
hidden = []
hidden += collect_submodules("numpy")
# Only include essential PySide6 modules, not all submodules
hidden += [
    "PySide6.QtWidgets",
    "PySide6.QtCore",
    "PySide6.QtGui",
    "PySide6.QtPrintSupport",
    "PySide6.QtSvg",
    "PySide6.QtSvgWidgets",
]
hidden += collect_submodules("matplotlib")
hidden += ["matplotlib.backends.backend_qtagg"]
hidden += collect_submodules("bs4")
hidden += collect_submodules("soupsieve")
hidden += ["bs4", "bs4.builder", "bs4.formatter", "bs4.dammit", "bs4.diagnose", "bs4.element", "soupsieve"]

hidden += [
    "importer_pdf",
    "importer_docx",
    "importer_xlsx",
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

# Collect bs4 data files
bs4_datas = collect_data_files("bs4")
soupsieve_datas = collect_data_files("soupsieve")

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
    datas=datas + bs4_datas + soupsieve_datas,
    hiddenimports=hidden,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[
        'PySide6.Qt3DAnimation',
        'PySide6.Qt3DCore',
        'PySide6.Qt3DExtras',
        'PySide6.Qt3DInput',
        'PySide6.Qt3DLogic',
        'PySide6.Qt3DRender',
        'PySide6.QtWebEngine',
        'PySide6.QtWebEngineCore',
        'PySide6.QtWebEngineWidgets',
        'PySide6.QtWebChannel',
        'PySide6.QtQuick',
        'PySide6.QtQuick3D',
        'PySide6.QtQuickControls2',
        'PySide6.QtQuickWidgets',
        'PySide6.QtQml',
        'PySide6.QtBluetooth',
        'PySide6.QtNfc',
        'PySide6.QtSensors',
        'PySide6.QtSerialPort',
        'PySide6.QtSerialBus',
        'PySide6.QtMultimedia',
        'PySide6.QtMultimediaWidgets',
        'PySide6.QtLocation',
        'PySide6.QtPositioning',
        'PySide6.QtRemoteObjects',
        'PySide6.QtTextToSpeech',
        'PySide6.QtVirtualKeyboard',
    ],
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
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
    icon='resources/icons/MyPsy.ico',
)
