# -*- mode: python ; coding: utf-8 -*-
# PyInstaller spec file for MyPsychAdmin - Mac App Store submission

import os
import sys
from PyInstaller.utils.hooks import collect_submodules, collect_dynamic_libs, collect_data_files

APP_NAME = "MyPsychAdmin"
APP_VERSION = "2.7"
BUNDLE_ID = "com.mypsychadmin.app"

# Get the directory containing the spec file
SPEC_DIR = os.path.dirname(os.path.abspath(SPEC))

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
    "importer_systmone",
]

hidden += [
    "patient_notes_panel",
    "patient_history_panel",
    "physical_health_panel",
    "medication_panel",
    "timeline_builder",
    "history_extractor_sections",
    "spell_checker",
    "spell_check_textedit",
]

# Letter writer modules
hidden += [
    "letter_writer_page",
    "letter_generator",
    "letter_toolbar",
    "letter_sections",
    "letter_sidebar_popup",
]

# Form pages
hidden += [
    "tribunal_report_page",
    "nursing_tribunal_report_page",
    "social_tribunal_report_page",
    "general_psychiatric_report_page",
    "hcr20_form_page",
    "hcr20_extractor",
    "moj_asr_form_page",
    "moj_leave_form_page",
    "a2_form_page",
    "a3_form_page",
    "a4_form_page",
    "a6_form_page",
    "a7_form_page",
    "a8_form_page",
    "cto1_form_page",
    "cto3_form_page",
    "cto4_form_page",
    "cto5_form_page",
    "cto7_form_page",
    "h1_form_page",
    "h5_form_page",
    "m2_form_page",
    "t2_form_page",
]

# Tribunal and narrative
hidden += [
    "tribunal_popups",
    "data_extractor_popup",
    "medication_extractor",
    "physical_health_extractor",
    "patient_demographics",
]

# Shared modules
hidden += [
    "shared_data_store",
    "db",
]

# SSL certificates for macOS
hidden += ["certifi"]

# --- NEW: collect numpy binaries ---
numpy_binaries = collect_dynamic_libs("numpy")

# Collect bs4 data files
bs4_datas = collect_data_files("bs4")
soupsieve_datas = collect_data_files("soupsieve")

# Collect certifi certificate bundle for SSL on macOS
certifi_datas = collect_data_files("certifi")

# Collect spellchecker dictionary files
spellchecker_datas = collect_data_files("spellchecker")

datas = [
    ("resources/public_key.pem", "resources"),
    ("resources/icons", "resources/icons"),
    # Data files
    ("Letter_headings_search_v2.txt", "."),
    ("Letter headings search.txt", "."),
    ("ICD10_DICT.txt", "."),
    ("incidentDICT.txt", "."),
    ("riskDICT.txt", "."),
    ("medical_dictionary.txt", "."),
    # Templates folder
    ("templates", "templates"),
]

a = Analysis(
    ['main.py'],
    pathex=[],
    binaries=numpy_binaries,
    datas=datas + bs4_datas + soupsieve_datas + certifi_datas + spellchecker_datas,
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
    upx=False,  # Don't use UPX for App Store - can cause signing issues
    console=False,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,  # Use native architecture (universal2 not supported by all dependencies)
    codesign_identity=None,  # Will be signed separately by build script
    entitlements_file=os.path.join(SPEC_DIR, 'entitlements_dmg.plist'),
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=False,  # Don't use UPX for App Store
    upx_exclude=[],
    name=APP_NAME,
)

app = BUNDLE(
    coll,
    name=APP_NAME + '.app',
    icon='resources/icons/MyPsy.icns',
    bundle_identifier=BUNDLE_ID,
    info_plist={
        # Required App Store metadata
        'CFBundleName': APP_NAME,
        'CFBundleDisplayName': APP_NAME,
        'CFBundleVersion': APP_VERSION,
        'CFBundleShortVersionString': APP_VERSION,
        'CFBundleExecutable': APP_NAME,
        'CFBundleIdentifier': BUNDLE_ID,
        'CFBundlePackageType': 'APPL',
        'CFBundleSignature': 'MPSA',

        # macOS requirements
        'LSMinimumSystemVersion': '11.0',
        'NSHighResolutionCapable': True,
        'NSPrincipalClass': 'NSApplication',
        'NSRequiresAquaSystemAppearance': False,  # Support dark mode

        # App Store category
        'LSApplicationCategoryType': 'public.app-category.medical',

        # Copyright
        'NSHumanReadableCopyright': 'Copyright © 2024 MyPsychAdmin. All rights reserved.',

        # Encryption declaration (no custom encryption)
        'ITSAppUsesNonExemptEncryption': False,

        # Privacy descriptions (required for App Store)
        'NSDocumentsFolderUsageDescription': 'MyPsychAdmin needs access to documents to import and export patient notes and reports.',
        'NSDownloadsFolderUsageDescription': 'MyPsychAdmin needs access to downloads folder to save exported reports.',
        'NSDesktopFolderUsageDescription': 'MyPsychAdmin needs access to desktop to save exported reports.',
    },
)
