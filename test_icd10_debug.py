"""Quick test to reproduce ICD-10 visibility issue on Windows."""
import sys
import os

os.chdir(os.path.dirname(os.path.abspath(__file__)))

from PySide6.QtWidgets import QApplication, QMainWindow
from PySide6.QtCore import QTimer

app = QApplication(sys.argv)

if sys.platform == 'win32':
    app.setStyle("Fusion")

from PySide6.QtGui import QFont
default_font = app.font()
default_font.setPointSizeF(default_font.pointSizeF() * 0.9)
app.setFont(default_font)

app.setStyleSheet("""
    QRadioButton { background: transparent; }
    QRadioButton::indicator { width: 16px; height: 16px; border: 2px solid #666; border-radius: 9px; background: white; }
    QRadioButton::indicator:checked { background: #2563eb; border: 2px solid #2563eb; }
    QCheckBox { background: transparent; }
    QCheckBox::indicator { width: 16px; height: 16px; border: 2px solid #666; border-radius: 3px; background: white; }
    QCheckBox::indicator:checked { background: #2563eb; border: 2px solid #2563eb; }
""")

from icd10_dict import ICD10_DICT
from general_psychiatric_report_page import GPRLegalCriteriaPopup

print(f"\n=== TEST: ICD10_DICT has {len(ICD10_DICT)} entries ===")

popup = GPRLegalCriteriaPopup(parent=None, gender="male", icd10_dict=ICD10_DICT)

win = QMainWindow()
win.setCentralWidget(popup)
win.resize(800, 600)
win.show()

def run_test():
    print(f"\n=== Section starts expanded: collapsed={popup.input_section.is_collapsed()} ===")
    print(f"content_container visible: {popup.input_section.content_container.isVisible()}")

    # Click "Present" directly (section is already expanded)
    print(f"\n=== Clicking 'Present' ===")
    popup.md_present.setChecked(True)
    app.processEvents()

    print(f"\nRESULT: dx_container visible={popup.dx_container.isVisible()}")
    print(f"RESULT: dx_container size={popup.dx_container.size().width()}x{popup.dx_container.size().height()}")
    for i, combo in enumerate(popup.dx_combos):
        print(f"  combo[{i}]: {combo.count()} items, visible={combo.isVisible()}")

    print(f"\n=== TEST PASSED ===") if popup.dx_container.isVisible() else print(f"\n=== TEST FAILED ===")
    print("Close the window to exit.")

QTimer.singleShot(500, run_test)
sys.exit(app.exec())
