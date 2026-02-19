from __future__ import annotations

from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout,
    QPushButton, QLabel, QSizePolicy, QFrame,
    QGraphicsOpacityEffect
)
from PySide6.QtCore import Qt, QPropertyAnimation, QEasingCurve, QSize, QTimer
from PySide6.QtGui import QColor


# ============================================================
# macOS BLUR (safe fallback)
# ============================================================
def apply_macos_blur(widget):
    try:
        widget.setAttribute(Qt.WA_TranslucentBackground, True)
        widget.setStyleSheet("background: transparent;")
    except Exception:
        pass


# ============================================================
# COLLAPSIBLE SECTION — PATCH B (Transparent Header, Smooth Panels)
# ============================================================
class CollapsibleSection(QWidget):

    def __init__(self, title, start_collapsed=True, parent=None, embedded=False):
        super().__init__(parent)

        self.title = title
        self.children_widgets = []
        self.embedded = embedded

        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)

        # Colors based on embedded mode
        if embedded:
            text_color = "#333"
            arrow_color = "#666"
        else:
            text_color = "#E6F2FF"
            arrow_color = "#E6F2FF"

        # ------------------------------
        # OUTER LAYOUT
        # ------------------------------
        outer = QVBoxLayout(self)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(10)

        # ------------------------------
        # HEADER BAR
        # ------------------------------
        self.header_bar = QWidget()
        hb = QHBoxLayout(self.header_bar)
        hb.setContentsMargins(4, 4, 4, 4)
        hb.setSpacing(10)

        self.arrow = QLabel("▶" if start_collapsed else "▼")
        self.arrow.setStyleSheet(f"""
            color: {arrow_color};
            font-size: 17px;
            font-weight: bold;
            background: transparent;
        """)

        self.title_label = QLabel(title)
        self.title_label.setStyleSheet(f"""
            color: {text_color};
            font-size: 17px;
            font-weight: bold;
            padding-left: 4px;
            background: transparent;
        """)

        hb.addWidget(self.arrow)
        hb.addWidget(self.title_label)
        hb.addStretch()

        # Fully transparent header
        self.header_bar.setStyleSheet("background-color: rgba(0,0,0,0);")

        # Click anywhere toggles
        self.header_bar.mousePressEvent = self._toggle

        outer.addWidget(self.header_bar)

        # ------------------------------
        # BODY CONTAINER
        # ------------------------------
        # ------------------------------
        # BODY CONTAINER  (MATCH ORIGINAL BEHAVIOUR)
        # ------------------------------
        self.container = QFrame()
        self.container_layout = QVBoxLayout(self.container)

        # ⭐ Restore original safe margins + spacing
        self.container_layout.setContentsMargins(10, 4, 10, 4)
        self.container_layout.setSpacing(6)

        # Let children expand fully
        self.container.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)

        # Base style for container (no background by default)
        if embedded:
            self._container_base_style = "QFrame { background: transparent; border: none; border-radius: 8px; } QLabel { border: none; }"
            self._container_highlight_style = "QFrame { background: rgba(58, 122, 254, 0.06); border: none; border-radius: 8px; } QLabel { border: none; background: transparent; }"
        else:
            self._container_base_style = "QFrame { background: transparent; border: none; border-radius: 8px; } QLabel { border: none; }"
            self._container_highlight_style = "QFrame { background: rgba(100, 180, 255, 0.08); border: none; border-radius: 8px; } QLabel { border: none; background: transparent; }"

        self.container.setStyleSheet(self._container_base_style)
        self._is_highlighted = False
        self._is_dimmed = False

        outer.addWidget(self.container)

        # Default collapsed
        if start_collapsed:
            self.container.hide()


    # ------------------------------------------------------------
    # Add widget to section
    # ------------------------------------------------------------
    def add_widget(self, w):
        self.children_widgets.append(w)
        self.container_layout.addWidget(w)

        # ⭐️ CRITICAL — allow full panel width, prevents compression
        w.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Preferred)

        # propagate size changes
        self.container.adjustSize()
        self.updateGeometry()

        parent = self.parentWidget()
        if parent:
            parent.updateGeometry()

        # keep resize grip on top (if it exists)
        root = self.window()
        if hasattr(root, "resize_grip") and root.resize_grip is not None:
            root.resize_grip.raise_()


    # ------------------------------------------------------------
    # Toggle open/closed
    # ------------------------------------------------------------
    def _toggle(self, event=None):
        is_open = self.container.isVisible()

        if not is_open:  # Was closed, now opening
            # Clear all highlights in the panel (travelling focus)
            self._clear_all_highlights()
            # Apply highlight to this section only
            self._apply_highlight()
        else:  # Was open, now closing
            # Remove highlight from this section
            self._remove_highlight()
            # Move highlight back to parent section
            parent_section = self._find_parent_section()
            if parent_section:
                parent_section._apply_highlight()
            else:
                # No parent - undim everything
                self._undim_all()

        self.container.setVisible(not is_open)
        self.arrow.setText("▼" if not is_open else "▶")

        # Smooth vertical expansion
        self.setMinimumHeight(0)
        self.setMaximumHeight(16777215)
        self.container.setMinimumHeight(0)
        self.container.setMaximumHeight(16777215)

        self.updateGeometry()

        # Update parent layout so nothing compresses
        parent = self.parentWidget()
        if parent:
            parent.updateGeometry()

        # Ensure resize grip stays above everything (if it exists)
        root = self.window()
        if hasattr(root, "resize_grip") and root.resize_grip is not None:
            root.resize_grip.raise_()

    def _find_parent_section(self):
        """Find the parent CollapsibleSection in the widget hierarchy."""
        widget = self.parentWidget()
        while widget:
            # Check if parent's parent is a CollapsibleSection
            # (we're inside the container of a parent section)
            parent = widget.parentWidget()
            if isinstance(parent, CollapsibleSection):
                return parent
            widget = parent
        return None

    def _clear_all_highlights(self):
        """Clear highlights from ALL CollapsibleSections in the panel (travelling focus)."""
        # Find the root panel widget
        root = self.window()
        if not root:
            root = self

        # Remove highlights from all CollapsibleSections
        for section in root.findChildren(CollapsibleSection):
            if section._is_highlighted:
                section._remove_highlight()

    def _apply_highlight(self):
        """Apply persistent highlight to the container when expanded."""
        self.container.setStyleSheet(self._container_highlight_style)
        self._is_highlighted = True
        # Undim this section
        self._undim()
        # Dim all other sections
        self._dim_others()

    def _remove_highlight(self):
        """Remove highlight and return to base style."""
        self.container.setStyleSheet(self._container_base_style)
        self._is_highlighted = False

    def _dim(self):
        """Dim this section to reduce visual prominence."""
        if self._is_dimmed:
            return
        effect = QGraphicsOpacityEffect(self)
        effect.setOpacity(0.35)
        self.setGraphicsEffect(effect)
        self._is_dimmed = True

    def _undim(self):
        """Restore normal opacity to this section."""
        if not self._is_dimmed:
            return
        self.setGraphicsEffect(None)
        self._is_dimmed = False

    def _dim_others(self):
        """Dim siblings and unrelated sections, but NOT children or ancestors."""
        root = self.window()
        if not root:
            root = self

        # Get ancestor chain (sections we should NOT dim)
        ancestors = set()
        parent = self._find_parent_section()
        while parent:
            ancestors.add(parent)
            parent = parent._find_parent_section()

        # Get direct children of this section (should NOT be dimmed)
        my_children = set()
        for child in self.container.findChildren(CollapsibleSection):
            my_children.add(child)

        # Dim sections that are not: self, ancestors, or children
        for section in root.findChildren(CollapsibleSection):
            if section is self or section in ancestors or section in my_children:
                section._undim()
            else:
                section._dim()

    def _undim_all(self):
        """Restore normal opacity to all sections."""
        root = self.window()
        if not root:
            root = self

        for section in root.findChildren(CollapsibleSection):
            section._undim()

    def expand(self):
        if not self.container.isVisible():
            self._toggle()

    def collapse(self):
        if self.container.isVisible():
            self._toggle()
