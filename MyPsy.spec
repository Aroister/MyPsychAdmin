# -*- mode: python ; coding: utf-8 -*-

import os
from PyInstaller.utils.hooks import collect_submodules, collect_dynamic_libs, collect_data_files

APP_NAME = "MyPsy"

# Hidden imports
hidden = []
hidden += collect_submodules("numpy")
hidden += collect_submodules("PySide6")
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
]

hidden += [
    "patient_notes_panel",
    "patient_history_panel",
    "physical_health_panel",
    "medication_panel",
    "timeline_builder",
    "history_extractor_sections",
]

# --- NEW: collect numpy binaries ---
numpy_binaries = collect_dynamic_libs("numpy")

# Collect bs4 data files
bs4_datas = collect_data_files("bs4")
soupsieve_datas = collect_data_files("soupsieve")

datas = [
    ("resources/public_key.pem", "resources"),
    ("resources/icons", "resources/icons"),
    # Data files
    ("Letter_headings_search_v2.txt", "."),
    ("Letter headings search.txt", "."),
    ("ICD10_DICT.txt", "."),
    ("incidentDICT.txt", "."),
    ("riskDICT.txt", "."),
    # Templates folder
    ("templates", "templates"),
]

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=numpy_binaries,
    datas=datas + bs4_datas + soupsieve_datas,
    hiddenimports=hidden,
    hookspath=[],
    hooksconfig={},
    runtime_hooks=[],
    excludes=[],
    noarchive=False,
    optimize=0,
)
pyz = PYZ(a.pure)

exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name=APP_NAME,
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name=APP_NAME,
)

app = BUNDLE(
    coll,
    name=APP_NAME + '.app',
    icon='resources/icons/MyPsy.icns',
    bundle_identifier='com.mypsy.app',
    info_plist={
        'CFBundleName': APP_NAME,
        'CFBundleDisplayName': APP_NAME,
        'CFBundleVersion': '2.7',
        'CFBundleShortVersionString': '2.7',
        'NSHighResolutionCapable': True,
        'NSRequiresAquaSystemAppearance': False,
    },
)
