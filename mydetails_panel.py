from PySide6.QtWidgets import (
    QWidget, QLabel, QLineEdit, QPushButton,
    QVBoxLayout, QScrollArea, QFileDialog, QGraphicsBlurEffect
)
from PySide6.QtCore import Qt, QTimer
from PySide6.QtGui import QFont, QPixmap, QPainter, QColor, QBrush
import os
import sys


def apply_native_blur(widget):
    """Apply native macOS vibrancy blur effect."""
    if sys.platform != "darwin":
        return False

    try:
        from ctypes import c_void_p, cdll, c_bool
        from objc import objc_getClass, sel_registerName
        from Cocoa import NSVisualEffectView, NSVisualEffectBlendingModeBehindWindow

        # Get the native window handle
        win_id = int(widget.winId())
        # This approach requires more complex setup
        return False
    except ImportError:
        return False


class MyDetailsPanel(QWidget):

    def __init__(self, db, parent=None):
        super().__init__(parent)

        self.db = db
        self.setFixedWidth(380)

        # Enable translucent background for blur effect
        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setAutoFillBackground(False)
        self.setObjectName("MyDetailsPanel")

        # ==============================
        # SCROLL AREA
        # ==============================
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        scroll.setStyleSheet("background: transparent; border: none;")
        scroll.setAttribute(Qt.WA_TranslucentBackground)

        container = QWidget()
        container.setStyleSheet("background: transparent;")
        container.setAttribute(Qt.WA_TranslucentBackground)
        scroll.setWidget(container)

        layout = QVBoxLayout(container)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(18)

        # ==============================
        # TITLE
        # ==============================
        title = QLabel("My Details")
        title.setFont(QFont("Arial", 22, QFont.Bold))
        title.setStyleSheet("color: black; background: transparent;")
        layout.addWidget(title)

        # ==============================
        # TEXT FIELDS
        # ==============================
        self.inputs = {}
        fields = [
            ("Full Name", "full_name"),
            ("Role Title", "role_title"),
            ("Discipline", "discipline"),
            ("Registration Body", "registration_body"),
            ("Registration Number", "registration_number"),
            ("Phone", "phone"),
            ("Email", "email"),
            ("Team/Service", "team_service"),
            ("Hospital/Organisation", "hospital_org"),
            ("Ward/Department", "ward_department"),
            ("Signature Block", "signature_block"),
        ]

        for label_text, key in fields:
            lbl = QLabel(label_text)
            lbl.setFont(QFont("Arial", 12, QFont.Bold))
            lbl.setStyleSheet("background: transparent;")
            layout.addWidget(lbl)

            edit = QLineEdit()
            edit.setFixedHeight(32)
            edit.setStyleSheet("""
                QLineEdit {
                    background: white;
                    border: 1px solid #A0A8AF;
                    border-radius: 4px;
                    padding: 6px;
                }
            """)
            layout.addWidget(edit)
            self.inputs[key] = edit

        # ==============================
        # SIGNATURE IMAGE SECTION
        # ==============================
        sig_lbl = QLabel("Signature Image (optional)")
        sig_lbl.setFont(QFont("Arial", 12, QFont.Bold))
        sig_lbl.setStyleSheet("background: transparent;")
        layout.addWidget(sig_lbl)

        self.signature_preview = QLabel()
        self.signature_preview.setFixedSize(240, 120)
        self.signature_preview.setAlignment(Qt.AlignCenter)
        self.signature_preview.setStyleSheet("""
            background: white;
            border: 1px solid #A0A8AF;
            border-radius: 4px;
        """)
        layout.addWidget(self.signature_preview)

        load_sig_btn = QPushButton("Load Signature Image...")
        load_sig_btn.setFixedHeight(32)
        load_sig_btn.clicked.connect(self.load_signature_image)
        layout.addWidget(load_sig_btn)

        # ==============================
        # SAVE CONFIRMATION LABEL
        # ==============================
        self.saved_label = QLabel("")
        self.saved_label.setStyleSheet("color: green; font-size: 13px; background: transparent;")
        layout.addWidget(self.saved_label)

        # ==============================
        # SAVE BUTTON
        # ==============================
        save_btn = QPushButton("Save Details")
        save_btn.setFixedHeight(36)
        save_btn.setStyleSheet("""
            QPushButton {
                background-color: #4A90E2;
                color: white;
                border-radius: 4px;
            }
            QPushButton:hover {
                background-color: #357ABD;
            }
        """)
        save_btn.clicked.connect(self.save_details)
        layout.addWidget(save_btn)

        # ==============================
        # OUTER LAYOUT
        # ==============================
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.addWidget(scroll)

        # Load saved data + signature
        self.load_details()
        self.load_signature_on_startup()

    # ============================================================
    # LOAD SAVED SIGNATURE IMAGE (if exists)
    # ============================================================
    def load_signature_on_startup(self):
        sig_path = os.path.expanduser("~/MyPsychAdmin/signature.png")
        if os.path.exists(sig_path):
            pix = QPixmap(sig_path)
            scaled = pix.scaled(
                self.signature_preview.size(),
                Qt.KeepAspectRatio,
                Qt.SmoothTransformation
            )
            self.signature_preview.setPixmap(scaled)

    # ============================================================
    # LOAD SIGNATURE IMAGE BUTTON HANDLER
    # ============================================================
    def load_signature_image(self):
        file, _ = QFileDialog.getOpenFileName(
            self,
            "Select Signature Image",
            "",
            "Image Files (*.png *.jpg *.jpeg *.bmp)"
        )
        if not file:
            return

        # Ensure directory exists
        sig_dir = os.path.expanduser("~/MyPsychAdmin")
        os.makedirs(sig_dir, exist_ok=True)
        sig_path = os.path.join(sig_dir, "signature.png")

        pix = QPixmap(file)
        pix.save(sig_path, "PNG")

        scaled = pix.scaled(
            self.signature_preview.size(),
            Qt.KeepAspectRatio,
            Qt.SmoothTransformation
        )
        self.signature_preview.setPixmap(scaled)

        self.show_saved_message("Signature image saved")

    # ============================================================
    # LOAD TEXT DETAILS INTO FIELDS
    # ============================================================
    def load_details(self):
        details = self.db.get_clinician_details()
        if not details:
            return

        mapping = {
            "full_name": details["full_name"],
            "role_title": details["role_title"],
            "discipline": details["discipline"],
            "registration_body": details["registration_body"],
            "registration_number": details["registration_number"],
            "phone": details["phone"],
            "email": details["email"],
            "team_service": details["team_service"],
            "hospital_org": details["hospital_org"],
            "ward_department": details["ward_department"],
            "signature_block": details["signature_block"],
        }

        for key, value in mapping.items():
            self.inputs[key].setText(value or "")

    # ============================================================
    # SAVE TEXT DETAILS TO DATABASE
    # ============================================================
    def save_details(self):
        self.db.save_clinician_details(
            self.inputs["full_name"].text(),
            self.inputs["role_title"].text(),
            self.inputs["discipline"].text(),
            self.inputs["registration_body"].text(),
            self.inputs["registration_number"].text(),
            self.inputs["phone"].text(),
            self.inputs["email"].text(),
            self.inputs["team_service"].text(),
            self.inputs["hospital_org"].text(),
            self.inputs["ward_department"].text(),
            self.inputs["signature_block"].text(),
        )

        self.show_saved_message("Details saved")

    # ============================================================
    # SMALL GREEN CONFIRMATION MESSAGE
    # ============================================================
    def show_saved_message(self, text):
        self.saved_label.setText(text)
        QTimer.singleShot(2000, lambda: self.saved_label.setText(""))

    # ============================================================
    # PAINT EVENT - FROSTED GLASS EFFECT
    # ============================================================
    def paintEvent(self, event):
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)

        # Create frosted glass effect with layered semi-transparent fills
        rect = self.rect()

        # Base layer - slightly dark for depth
        painter.fillRect(rect, QColor(160, 175, 190, 180))

        # Middle layer - lighter frost
        painter.fillRect(rect, QColor(190, 200, 210, 120))

        # Top layer - bright frost highlight
        painter.fillRect(rect, QColor(220, 230, 240, 80))

        # Draw subtle right border
        painter.setPen(QColor(80, 90, 100, 120))
        painter.drawLine(self.width() - 1, 0, self.width() - 1, self.height())
