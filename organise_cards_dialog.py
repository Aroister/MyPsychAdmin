# ================================================================
#  ORGANISE CARDS DIALOG — Drag-and-drop reorder letter sections
# ================================================================

from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import (
    QDialog, QVBoxLayout, QHBoxLayout, QLabel, QPushButton,
    QListWidget, QListWidgetItem, QAbstractItemView
)


class OrganiseCardsDialog(QDialog):
    """Dialog for reordering letter cards via drag-and-drop."""

    order_changed = Signal(list)  # Emits new order as list of keys

    # Cards that can be reordered (between HPC and MSE)
    REORDERABLE_SECTIONS = [
        ("Affect", "affect"),
        ("Anxiety & Related Disorders", "anxiety"),
        ("Psychosis", "psychosis"),
        ("Psychiatric History", "psychhx"),
        ("Background History", "background"),
        ("Drug and Alcohol History", "drugalc"),
        ("Social History", "social"),
        ("Forensic History", "forensic"),
        ("Physical Health", "physical"),
        ("Function", "function"),
    ]

    def __init__(self, current_order: list = None, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Organise Letter Sections")
        self.setFixedSize(400, 500)
        self.setModal(True)

        # Use current order if provided, otherwise use default
        if current_order:
            self.sections = current_order
        else:
            self.sections = self.REORDERABLE_SECTIONS.copy()

        self._setup_ui()

    def _setup_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(20, 20, 20, 20)
        layout.setSpacing(16)

        # Header
        header = QLabel("Drag and drop to reorder sections")
        header.setStyleSheet("font-size: 14px; font-weight: 600; color: #333;")
        layout.addWidget(header)

        # Info text
        info = QLabel("These sections appear between History of Presenting Complaint and Mental State Examination.")
        info.setWordWrap(True)
        info.setStyleSheet("font-size: 12px; color: #666;")
        layout.addWidget(info)

        # List widget with drag-and-drop
        self.list_widget = QListWidget()
        self.list_widget.setDragDropMode(QAbstractItemView.DragDropMode.InternalMove)
        self.list_widget.setDefaultDropAction(Qt.DropAction.MoveAction)
        self.list_widget.setSelectionMode(QAbstractItemView.SelectionMode.SingleSelection)
        self.list_widget.setStyleSheet("""
            QListWidget {
                background: white;
                border: 1px solid #ddd;
                border-radius: 8px;
                padding: 8px;
                font-size: 13px;
            }
            QListWidget::item {
                padding: 12px 16px;
                border-radius: 6px;
                margin: 2px 0;
            }
            QListWidget::item:selected {
                background: #e0e7ff;
                color: #3730a3;
            }
            QListWidget::item:hover {
                background: #f3f4f6;
            }
        """)

        # Populate list
        for title, key in self.sections:
            item = QListWidgetItem(title)
            item.setData(Qt.ItemDataRole.UserRole, key)
            self.list_widget.addItem(item)

        layout.addWidget(self.list_widget, 1)

        # Buttons
        btn_layout = QHBoxLayout()
        btn_layout.setSpacing(12)

        reset_btn = QPushButton("Reset to Default")
        reset_btn.setStyleSheet("""
            QPushButton {
                background: #f3f4f6;
                color: #374151;
                border: 1px solid #d1d5db;
                padding: 10px 20px;
                border-radius: 6px;
                font-size: 13px;
                font-weight: 500;
            }
            QPushButton:hover {
                background: #e5e7eb;
            }
        """)
        reset_btn.clicked.connect(self._reset_order)
        btn_layout.addWidget(reset_btn)

        btn_layout.addStretch()

        cancel_btn = QPushButton("Cancel")
        cancel_btn.setStyleSheet("""
            QPushButton {
                background: #f3f4f6;
                color: #374151;
                border: 1px solid #d1d5db;
                padding: 10px 20px;
                border-radius: 6px;
                font-size: 13px;
                font-weight: 500;
            }
            QPushButton:hover {
                background: #e5e7eb;
            }
        """)
        cancel_btn.clicked.connect(self.reject)
        btn_layout.addWidget(cancel_btn)

        apply_btn = QPushButton("Apply")
        apply_btn.setStyleSheet("""
            QPushButton {
                background: #8b5cf6;
                color: white;
                border: none;
                padding: 10px 24px;
                border-radius: 6px;
                font-size: 13px;
                font-weight: 600;
            }
            QPushButton:hover {
                background: #7c3aed;
            }
        """)
        apply_btn.clicked.connect(self._apply_order)
        btn_layout.addWidget(apply_btn)

        layout.addLayout(btn_layout)

    def _reset_order(self):
        """Reset to default order."""
        self.list_widget.clear()
        for title, key in self.REORDERABLE_SECTIONS:
            item = QListWidgetItem(title)
            item.setData(Qt.ItemDataRole.UserRole, key)
            self.list_widget.addItem(item)

    def _apply_order(self):
        """Apply the new order and close."""
        new_order = []
        for i in range(self.list_widget.count()):
            item = self.list_widget.item(i)
            title = item.text()
            key = item.data(Qt.ItemDataRole.UserRole)
            new_order.append((title, key))

        self.order_changed.emit(new_order)
        self.accept()

    def get_new_order(self) -> list:
        """Get the current order from the list widget."""
        order = []
        for i in range(self.list_widget.count()):
            item = self.list_widget.item(i)
            title = item.text()
            key = item.data(Qt.ItemDataRole.UserRole)
            order.append((title, key))
        return order
