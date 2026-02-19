# ================================================================
#  SHARED WIDGETS - Reusable UI components
# ================================================================

import re
from PySide6.QtCore import Qt, Signal
from PySide6.QtWidgets import (
    QHBoxLayout, QPushButton, QTextEdit, QWidget, QLabel,
    QLineEdit, QComboBox, QCheckBox, QRadioButton, QSlider,
    QSpinBox, QDateEdit, QTimeEdit, QTextEdit, QPlainTextEdit
)
from PySide6.QtGui import QFont


# ================================================================
#  LOCKABLE POPUP MIXIN - Adds lock/unlock functionality
# ================================================================

class LockablePopupMixin:
    """
    Mixin class to add lock/unlock functionality to any popup widget.

    Usage:
        1. Add LockablePopupMixin to your class inheritance
        2. Call self.setup_lock_button(parent_layout) in __init__ after creating the layout

    Example:
        class MyPopup(LockablePopupMixin, QWidget):
            def __init__(self, parent=None):
                super().__init__(parent)
                layout = QVBoxLayout(self)
                self.setup_lock_button(layout)  # Add lock button
                # ... rest of your UI
    """

    # Signal emitted when lock state changes (True = locked)
    lock_changed = Signal(bool)

    def setup_lock_button(self, parent_widget=None):
        """
        Set up the lock button. Call this after creating the main layout.

        Args:
            parent_widget: The widget to add the lock button to (usually self)
        """
        self._is_locked = False
        self._lock_overlay = None

        # Create lock button
        self._lock_button = QPushButton("Unlocked")
        self._lock_button.setFixedSize(70, 26)
        self._lock_button.setCursor(Qt.CursorShape.PointingHandCursor)
        self._lock_button.setToolTip("Click to lock this section")
        self._lock_button.setStyleSheet("""
            QPushButton {
                background: rgba(34, 197, 94, 0.2);
                border: 2px solid #22c55e;
                border-radius: 13px;
                font-size: 13px;
                font-weight: 600;
                color: #16a34a;
            }
            QPushButton:hover {
                background: rgba(34, 197, 94, 0.35);
            }
        """)
        self._lock_button.clicked.connect(self.toggle_lock)

        # Position the button in top-right corner using absolute positioning
        target = parent_widget if parent_widget else self
        self._lock_button.setParent(target)
        self._lock_button.raise_()
        self._position_lock_button()

        # Connect to resize event to reposition button
        if hasattr(self, 'resizeEvent'):
            self._original_resize_event = self.resizeEvent
            self.resizeEvent = self._handle_resize

    def _position_lock_button(self):
        """Position the lock button in the top-right corner."""
        if hasattr(self, '_lock_button') and self._lock_button:
            parent = self._lock_button.parent()
            if parent:
                x = parent.width() - self._lock_button.width() - 8
                y = 8
                self._lock_button.move(max(8, x), y)

    def _handle_resize(self, event):
        """Handle resize to reposition lock button."""
        self._position_lock_button()
        if hasattr(self, '_original_resize_event'):
            self._original_resize_event(event)

    def toggle_lock(self):
        """Toggle the locked state."""
        self._is_locked = not self._is_locked
        self._update_lock_state()
        if hasattr(self, 'lock_changed'):
            try:
                self.lock_changed.emit(self._is_locked)
            except:
                pass

    def set_locked(self, locked: bool):
        """Set the locked state directly."""
        self._is_locked = locked
        self._update_lock_state()

    def is_locked(self) -> bool:
        """Return whether the popup is locked."""
        return getattr(self, '_is_locked', False)

    def _update_lock_state(self):
        """Update UI to reflect lock state."""
        if not hasattr(self, '_lock_button'):
            return

        if self._is_locked:
            # Locked state
            self._lock_button.setText("Locked")
            self._lock_button.setToolTip("Click to unlock this section")
            self._lock_button.setStyleSheet("""
                QPushButton {
                    background: rgba(239, 68, 68, 0.25);
                    border: 2px solid #ef4444;
                    border-radius: 13px;
                    font-size: 13px;
                    font-weight: 600;
                    color: #dc2626;
                }
                QPushButton:hover {
                    background: rgba(239, 68, 68, 0.4);
                }
            """)
            self._create_overlay()
            self._disable_inputs(True)
        else:
            # Unlocked state
            self._lock_button.setText("Unlocked")
            self._lock_button.setToolTip("Click to lock this section")
            self._lock_button.setStyleSheet("""
                QPushButton {
                    background: rgba(34, 197, 94, 0.2);
                    border: 2px solid #22c55e;
                    border-radius: 13px;
                    font-size: 13px;
                    font-weight: 600;
                    color: #16a34a;
                }
                QPushButton:hover {
                    background: rgba(34, 197, 94, 0.35);
                }
            """)
            self._remove_overlay()
            self._disable_inputs(False)

    def _create_overlay(self):
        """Create a semi-transparent overlay when locked."""
        if self._lock_overlay:
            return

        self._lock_overlay = QWidget(self)
        self._lock_overlay.setStyleSheet("""
            background: rgba(128, 128, 128, 0.3);
        """)
        self._lock_overlay.setGeometry(0, 0, self.width(), self.height())
        self._lock_overlay.show()
        self._lock_overlay.raise_()

        # Keep lock button above overlay
        self._lock_button.raise_()

    def _remove_overlay(self):
        """Remove the overlay when unlocked."""
        if self._lock_overlay:
            self._lock_overlay.hide()
            self._lock_overlay.deleteLater()
            self._lock_overlay = None

    def _disable_inputs(self, disabled: bool):
        """Enable or disable all input widgets."""
        input_types = (
            QLineEdit, QTextEdit, QPlainTextEdit, QComboBox,
            QCheckBox, QRadioButton, QSlider, QSpinBox,
            QDateEdit, QTimeEdit
        )

        for child in self.findChildren(QWidget):
            # Don't disable the lock button itself
            if child is self._lock_button:
                continue
            # Don't disable the overlay
            if child is self._lock_overlay:
                continue

            if isinstance(child, input_types):
                child.setEnabled(not disabled)
            elif isinstance(child, QPushButton):
                # Disable buttons except the lock button
                if child is not self._lock_button:
                    child.setEnabled(not disabled)

    def showEvent(self, event):
        """Reposition lock button when shown."""
        super().showEvent(event)
        self._position_lock_button()
        if self._is_locked and self._lock_overlay:
            self._lock_overlay.setGeometry(0, 0, self.width(), self.height())
            self._lock_overlay.raise_()
            self._lock_button.raise_()

    def resizeEvent(self, event):
        """Handle resize to update overlay and button position."""
        super().resizeEvent(event)
        self._position_lock_button()
        if self._lock_overlay:
            self._lock_overlay.setGeometry(0, 0, self.width(), self.height())
            self._lock_button.raise_()


def add_lock_to_popup(popup_widget, header_layout=None, show_button=True):
    """
    Add lock functionality to an existing popup widget instance.

    Args:
        popup_widget: The popup QWidget instance to add lock functionality to
        header_layout: Optional QHBoxLayout to add the lock button to
        show_button: If False, don't show a button (for popups controlled by external header)
    """
    popup_widget._is_locked = False
    popup_widget._lock_overlay = None
    popup_widget._lock_button = None

    if show_button:
        # Create lock button - clear text without emoji
        lock_btn = QPushButton("Unlocked", popup_widget)
        lock_btn.setFixedSize(70, 26)
        lock_btn.setCursor(Qt.CursorShape.PointingHandCursor)
        lock_btn.setToolTip("Click to lock this section")
        lock_btn.setStyleSheet("""
            QPushButton {
                background: rgba(34, 197, 94, 0.2);
                border: 2px solid #22c55e;
                border-radius: 13px;
                font-size: 13px;
                font-weight: 600;
                color: #16a34a;
                padding: 0 8px;
            }
            QPushButton:hover {
                background: rgba(34, 197, 94, 0.35);
            }
        """)
        popup_widget._lock_button = lock_btn

        # Add to header layout if provided
        if header_layout is not None:
            header_layout.addStretch()
            header_layout.addWidget(lock_btn)
            popup_widget._lock_in_layout = True
        else:
            popup_widget._lock_in_layout = False
    else:
        popup_widget._lock_in_layout = True  # Pretend it's in layout so no positioning

    def position_lock_button():
        if not popup_widget._lock_button:
            return
        if getattr(popup_widget, '_lock_in_layout', False):
            return  # No need to position, it's in the layout
        x = popup_widget.width() - popup_widget._lock_button.width() - 10
        popup_widget._lock_button.move(max(10, x), 10)
        popup_widget._lock_button.raise_()

    def create_overlay():
        if popup_widget._lock_overlay:
            return
        popup_widget._lock_overlay = QWidget(popup_widget)
        popup_widget._lock_overlay.setStyleSheet("background: rgba(128, 128, 128, 0.3);")
        popup_widget._lock_overlay.setGeometry(0, 0, popup_widget.width(), popup_widget.height())
        popup_widget._lock_overlay.show()
        popup_widget._lock_overlay.raise_()
        if popup_widget._lock_button:
            popup_widget._lock_button.raise_()

    def remove_overlay():
        if popup_widget._lock_overlay:
            popup_widget._lock_overlay.hide()
            popup_widget._lock_overlay.deleteLater()
            popup_widget._lock_overlay = None

    def disable_inputs(disabled):
        input_types = (QLineEdit, QTextEdit, QPlainTextEdit, QComboBox,
                       QCheckBox, QRadioButton, QSlider, QSpinBox, QDateEdit, QTimeEdit)
        for child in popup_widget.findChildren(QWidget):
            if child is popup_widget._lock_button or child is popup_widget._lock_overlay:
                continue
            if isinstance(child, input_types):
                child.setEnabled(not disabled)
            elif isinstance(child, QPushButton) and child is not popup_widget._lock_button:
                child.setEnabled(not disabled)

    def toggle_lock():
        popup_widget._is_locked = not popup_widget._is_locked
        if popup_widget._is_locked:
            if popup_widget._lock_button:
                popup_widget._lock_button.setText("Locked")
                popup_widget._lock_button.setToolTip("Click to unlock this section")
                popup_widget._lock_button.setStyleSheet("""
                    QPushButton {
                        background: rgba(239, 68, 68, 0.25);
                        border: 2px solid #ef4444;
                        border-radius: 13px;
                        font-size: 13px;
                        font-weight: 600;
                        color: #dc2626;
                        padding: 0 8px;
                    }
                    QPushButton:hover { background: rgba(239, 68, 68, 0.4); }
                """)
            create_overlay()
            disable_inputs(True)
        else:
            if popup_widget._lock_button:
                popup_widget._lock_button.setText("Unlocked")
                popup_widget._lock_button.setToolTip("Click to lock this section")
                popup_widget._lock_button.setStyleSheet("""
                    QPushButton {
                        background: rgba(34, 197, 94, 0.2);
                        border: 2px solid #22c55e;
                        border-radius: 13px;
                        font-size: 13px;
                        font-weight: 600;
                        color: #16a34a;
                        padding: 0 8px;
                    }
                    QPushButton:hover {
                        background: rgba(34, 197, 94, 0.35);
                    }
                """)
            remove_overlay()
            disable_inputs(False)

    if popup_widget._lock_button:
        popup_widget._lock_button.clicked.connect(toggle_lock)
    popup_widget.toggle_lock = toggle_lock
    popup_widget.is_locked = lambda: popup_widget._is_locked
    popup_widget.set_locked = lambda locked: (setattr(popup_widget, '_is_locked', not locked), toggle_lock()) if locked != popup_widget._is_locked else None

    # Hook into resize event
    original_resize = popup_widget.resizeEvent if hasattr(popup_widget, 'resizeEvent') else None
    def new_resize(event):
        if original_resize:
            original_resize(event)
        position_lock_button()
        if popup_widget._lock_overlay:
            popup_widget._lock_overlay.setGeometry(0, 0, popup_widget.width(), popup_widget.height())
            if popup_widget._lock_button:
                popup_widget._lock_button.raise_()
    popup_widget.resizeEvent = new_resize

    # Initial positioning
    position_lock_button()

    return popup_widget


def create_zoom_row(text_edit: QTextEdit, base_size: int = 12) -> QHBoxLayout:
    """Create a zoom controls row (+/-) for any QTextEdit.

    Args:
        text_edit: The QTextEdit widget to control
        base_size: Initial font size in pixels

    Returns:
        QHBoxLayout with zoom buttons (stretched to right side)
    """
    zoom_row = QHBoxLayout()
    zoom_row.setSpacing(2)
    zoom_row.addStretch()

    text_edit._font_size = base_size

    zoom_out_btn = QPushButton("−")
    zoom_out_btn.setFixedSize(16, 16)
    zoom_out_btn.setCursor(Qt.CursorShape.PointingHandCursor)
    zoom_out_btn.setToolTip("Decrease font size")
    zoom_out_btn.setStyleSheet("""
        QPushButton {
            background: #f3f4f6;
            color: #374151;
            border: 1px solid #d1d5db;
            border-radius: 3px;
            font-size: 11px;
            font-weight: bold;
        }
        QPushButton:hover { background: #e5e7eb; }
    """)
    zoom_row.addWidget(zoom_out_btn)

    zoom_in_btn = QPushButton("+")
    zoom_in_btn.setFixedSize(16, 16)
    zoom_in_btn.setCursor(Qt.CursorShape.PointingHandCursor)
    zoom_in_btn.setToolTip("Increase font size")
    zoom_in_btn.setStyleSheet("""
        QPushButton {
            background: #f3f4f6;
            color: #374151;
            border: 1px solid #d1d5db;
            border-radius: 3px;
            font-size: 11px;
            font-weight: bold;
        }
        QPushButton:hover { background: #e5e7eb; }
    """)
    zoom_row.addWidget(zoom_in_btn)

    current_style = text_edit.styleSheet()

    def zoom_in():
        text_edit._font_size = min(text_edit._font_size + 2, 28)
        # Update font-size in stylesheet (handles both px and pt)
        new_style = re.sub(r'font-size:\s*\d+(px|pt)', f'font-size: {text_edit._font_size}px', current_style)
        if new_style == current_style:
            # No font-size in stylesheet, set via QFont
            font = text_edit.font()
            font.setPointSize(text_edit._font_size)
            text_edit.setFont(font)
        else:
            text_edit.setStyleSheet(new_style)

    def zoom_out():
        text_edit._font_size = max(text_edit._font_size - 2, 8)
        # Update font-size in stylesheet (handles both px and pt)
        new_style = re.sub(r'font-size:\s*\d+(px|pt)', f'font-size: {text_edit._font_size}px', current_style)
        if new_style == current_style:
            # No font-size in stylesheet, set via QFont
            font = text_edit.font()
            font.setPointSize(text_edit._font_size)
            text_edit.setFont(font)
        else:
            text_edit.setStyleSheet(new_style)

    zoom_in_btn.clicked.connect(zoom_in)
    zoom_out_btn.clicked.connect(zoom_out)

    return zoom_row
