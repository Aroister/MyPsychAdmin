# ================================================
# ACTIVATION DIALOG — MyPsychAdmin 2.7
# ================================================
# Features:
#   - Machine-bound activation
#   - Shows activation status and expiry
#   - Email notification on activation
# ================================================

from PySide6.QtWidgets import (
    QDialog, QVBoxLayout, QHBoxLayout, QLabel, QLineEdit,
    QPushButton, QMessageBox, QFrame
)
from PySide6.QtCore import Qt

from license_manager import activate_license, get_license_info, get_machine_id


class ActivationDialog(QDialog):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Activate MyPsychAdmin")
        self.setMinimumWidth(480)
        self.setStyleSheet("""
            QDialog {
                background-color: #f5f5f7;
            }
            QLabel {
                color: #1d1d1f;
            }
            QLineEdit {
                padding: 10px;
                border: 1px solid #d2d2d7;
                border-radius: 8px;
                background: white;
                font-size: 13px;
            }
            QLineEdit:focus {
                border: 2px solid #0071e3;
            }
            QPushButton {
                padding: 10px 20px;
                border-radius: 8px;
                font-size: 14px;
                font-weight: 500;
            }
            QPushButton#activate {
                background-color: #0071e3;
                color: white;
                border: none;
            }
            QPushButton#activate:hover {
                background-color: #0077ed;
            }
            QPushButton#activate:pressed {
                background-color: #006edb;
            }
        """)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(30, 30, 30, 30)
        layout.setSpacing(16)

        # Title
        title = QLabel("Activate MyPsychAdmin")
        title.setStyleSheet("font-size: 24px; font-weight: 600; color: #1d1d1f;")
        layout.addWidget(title)

        # Subtitle
        subtitle = QLabel("Enter your licence key to activate this application (you only need to do this once).")
        subtitle.setStyleSheet("font-size: 14px; color: #86868b;")
        layout.addWidget(subtitle)

        # Contact info
        contact = QLabel("If you don't have a licence key contact - info@mypsychadmin.com")
        contact.setStyleSheet("font-size: 14px; font-weight: bold; color: #1d1d1f;")
        layout.addWidget(contact)

        layout.addSpacing(10)

        # License key input
        layout.addWidget(QLabel("Licence Key:"))
        self.key_edit = QLineEdit()
        self.key_edit.setPlaceholderText("Paste your licence key here…")
        self.key_edit.setMinimumHeight(44)
        layout.addWidget(self.key_edit)

        # Machine ID display
        machine_frame = QFrame()
        machine_frame.setStyleSheet("""
            QFrame {
                background: #e8e8ed;
                border-radius: 8px;
                padding: 10px;
            }
        """)
        machine_layout = QVBoxLayout(machine_frame)
        machine_layout.setContentsMargins(12, 8, 12, 8)
        machine_layout.setSpacing(4)

        machine_label = QLabel("Machine ID (for support):")
        machine_label.setStyleSheet("font-size: 11px; color: #86868b;")
        machine_layout.addWidget(machine_label)

        machine_id = get_machine_id()
        machine_id_label = QLabel(machine_id)
        machine_id_label.setStyleSheet("font-size: 12px; font-family: monospace; color: #1d1d1f;")
        machine_id_label.setTextInteractionFlags(Qt.TextSelectableByMouse)
        machine_layout.addWidget(machine_id_label)

        layout.addWidget(machine_frame)

        layout.addSpacing(10)

        # Activate button
        btn = QPushButton("Activate")
        btn.setObjectName("activate")
        btn.setMinimumHeight(44)
        btn.clicked.connect(self.activate)
        layout.addWidget(btn)

        # Status label
        self.status_label = QLabel("")
        self.status_label.setStyleSheet("font-size: 12px; color: #86868b;")
        self.status_label.setAlignment(Qt.AlignCenter)
        layout.addWidget(self.status_label)

    def activate(self):
        key = self.key_edit.text().strip()
        if not key:
            QMessageBox.warning(self, "Error", "Please enter a licence key.")
            return

        self.status_label.setText("Activating...")
        self.status_label.setStyleSheet("font-size: 12px; color: #0071e3;")
        self.repaint()

        # Use the new activation function
        success, result = activate_license(key)

        if not success:
            self.status_label.setText("")
            QMessageBox.critical(self, "Activation Failed", str(result))
            return

        # Get license info for display
        info = get_license_info()

        # Build success message
        message = f"MyPsychAdmin has been successfully activated!\n\n"
        message += f"Customer: {info.get('customer', 'N/A')}\n"
        message += f"Licence Type: {info.get('type', 'N/A')}\n"
        message += f"Expires: {info.get('expires', 'N/A')}\n"

        QMessageBox.information(self, "Activated", message)
        self.accept()
