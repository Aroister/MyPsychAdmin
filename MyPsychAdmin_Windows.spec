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

# Importers
hidden += [
    "importer_pdf",
    "importer_docx",
    "importer_xlsx",
    "importer_rio",
    "importer_autodetect",
    "importer_carenotes",
    "importer_epjs",
    "importer_systmone",
    "importer_common",
    "epr_widget",
]

# Patient panels
hidden += [
    "patient_notes_panel",
    "patient_notes_page",
    "patient_history_panel",
    "patient_history_panel_shared",
    "physical_health_panel",
    "medication_panel",
    "timeline_builder",
    "timeline_panel",
    "history_extractor_sections",
    "history_summary_engine",
    "floating_timeline_panel",
    "progress_panel",
    "risk_overview_panel",
]

# Letter writer modules
hidden += [
    "letter_writer_page",
    "letter_generator",
    "letter_toolbar",
    "letter_sections",
    "letter_sidebar_popup",
    "letter_sidebar_popup_med",
    "letter_rich_text_editor",
    "letter_templates",
    "letter_sentence_templates",
    "docx_exporter",
    "docx_letter_importer",
    "clipboard_helper",
    "mypsy_richtext_editor",
    "organise_cards_dialog",
    "icd10_data",
    "icd10_dict",
    "icd10_curated",
]

# Letter popup modules (all section popups)
hidden += [
    "presenting_complaint_popup",
    "history_presenting_complaint_popup",
    "affect_popup",
    "anxiety_popup",
    "psychosis_popup",
    "past_psych_popup",
    "background_history_popup",
    "drugs_alcohol_popup",
    "social_history_popup",
    "forensic_history_popup",
    "physical_health_popup",
    "function_popup",
    "mental_state_examination_popup",
    "impression_popup",
    "plan_popup",
    "mini_severity_popup",
    "psych_history_draft_popup",
    "data_extractor_popup",
]

# Form pages
hidden += [
    "forms_page",
    "simple_form_page",
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
    "moj_leave_form_page",
    "moj_asr_form_page",
    "hcr20_form_page",
    "hcr20_extractor",
    "hcr20_docx_exporter",
    "mha_form_toolbar",
]

# Report pages
hidden += [
    "reports_page",
    "tribunal_report_page",
    "nursing_tribunal_report_page",
    "social_tribunal_report_page",
    "general_psychiatric_report_page",
    "gpr_report_parser",
    "tribunal_popups",
    "narrative_generator",
]

# Extractors and shared modules
hidden += [
    "medication_extractor",
    "physical_health_extractor",
    "patient_demographics",
    "shared_data_store",
    "shared_widgets",
    "db",
    "db_crypto",
    "mydetails_panel",
    "theme_manager",
    "activation_dialog",
    "license_manager",
    "machine_id",
    "page_score_patient",
]

# Spell check
hidden += [
    "spell_checker",
    "spell_check_textedit",
]

# UI modules
hidden += [
    "ui_core",
    "ui_effects",
    "ui_icons",
    "flow_layout",
    "clickable_label",
    "CANONICAL_BLOODS",
    "CANONICAL_MEDS",
]

# Widget modules used by popups
hidden += [
    "anxiety_widgets",
    "abuse_descriptor_widget",
    "abuse_widget",
    "birth_widget",
    "children_widget",
    "family_history_widget",
    "milestones_widget",
    "qualifications_widget",
    "relationships_widget",
    "schooling_widget",
    "sexual_orientation_widget",
    "work_history_widget",
    "personal_history_schema",
    "personal_history_state",
    "psych_history_draft",
    "psychosis_text_engine",
]

# Utils package
hidden += [
    "utils",
    "utils.resource_path",
    "utils.document_ingestor",
    "utils.extractor_deduplicator",
    "utils.report_detector",
]

# SSL certificates
hidden += ["certifi"]

# python-docx (needed by letter importer/exporter)
hidden += collect_submodules("docx")

# --- Collect binaries and data files ---
numpy_binaries = collect_dynamic_libs("numpy")

bs4_datas = collect_data_files("bs4")
soupsieve_datas = collect_data_files("soupsieve")
spellchecker_datas = collect_data_files("spellchecker")
certifi_datas = collect_data_files("certifi")

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
    datas=datas + bs4_datas + soupsieve_datas + spellchecker_datas + certifi_datas,
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
