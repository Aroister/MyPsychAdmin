# ===============================================================
# UI EFFECTS MODULE (Qt6-safe, macOS-friendly)
# Shared by: history panel, medication panel, timeline panel,
# physical health panel, and any floating windows.
# ===============================================================

from __future__ import annotations
from PySide6.QtWidgets import QWidget, QGraphicsDropShadowEffect, QFrame
from PySide6.QtGui import QColor, QPainter, QRadialGradient, QPen, QBrush
from PySide6.QtCore import Qt, QOperatingSystemVersion, QPoint, QPointF


# ---------------------------------------------------------------
# GLOW CARD BASE CLASS - Card with mouse-tracking glow effect
# ---------------------------------------------------------------
class GlowCard(QFrame):
    """
    A QFrame-based card with a mouse-tracking glow effect.
    The glow follows the cursor and is brighter over the header area.

    Subclass this or use apply_glow_effect() on existing cards.
    """

    def __init__(self, parent=None, glow_color: QColor = None, header_height: int = 80, border_radius: int = 12):
        super().__init__(parent)
        self._glow_color = QColor(37, 99, 235, 70) if glow_color is None else glow_color
        self._glow_color_header = QColor(
            self._glow_color.red(),
            self._glow_color.green(),
            self._glow_color.blue(),
            min(255, int(self._glow_color.alpha() * 2.2))
        )
        self._glow_radius = 180
        self._header_height = header_height
        self._border_radius = border_radius
        self._mouse_pos = None
        self._background_color = QColor(255, 255, 255)
        self._border_color = QColor("#e5e7eb")
        self._border_color_hover = None  # Set to enable hover border color

        self.setMouseTracking(True)
        self.setAttribute(Qt.WidgetAttribute.WA_Hover, True)
        self.setAutoFillBackground(False)
        self.setAttribute(Qt.WidgetAttribute.WA_OpaquePaintEvent, False)

    def set_glow_color(self, color: QColor):
        """Set the glow color."""
        if isinstance(color, str):
            color = QColor(color)
        self._glow_color = QColor(color.red(), color.green(), color.blue(), 70)
        self._glow_color_header = QColor(color.red(), color.green(), color.blue(), 150)
        self._border_color_hover = color
        self.update()

    def mouseMoveEvent(self, event):
        """Track mouse position."""
        pos = event.position() if hasattr(event, 'position') else event.pos()
        self._mouse_pos = pos.toPoint() if hasattr(pos, 'toPoint') else pos
        self.update()
        super().mouseMoveEvent(event)

    def enterEvent(self, event):
        """Enable glow on enter."""
        super().enterEvent(event)
        self.update()

    def leaveEvent(self, event):
        """Clear glow on leave."""
        self._mouse_pos = None
        self.update()
        super().leaveEvent(event)

    def paintEvent(self, event):
        """Paint background and border (glow disabled)."""
        from PySide6.QtGui import QPainterPath

        rect = self.rect()
        r = self._border_radius

        # Create clipping path for rounded rect
        path = QPainterPath()
        path.addRoundedRect(float(rect.x()), float(rect.y()), float(rect.width()), float(rect.height()), r, r)

        painter = QPainter(self)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        # Draw solid white background (clipped)
        painter.setClipPath(path)
        painter.fillRect(rect, self._background_color)

        # Glow effect disabled

        # Draw border (unclipped)
        painter.setClipping(False)
        painter.setPen(QPen(self._border_color, 1.5))
        painter.setBrush(Qt.BrushStyle.NoBrush)
        painter.drawRoundedRect(rect.adjusted(1, 1, -1, -1), r - 1, r - 1)

        painter.end()
        # Children are painted automatically by Qt after this returns


# ---------------------------------------------------------------
# HELPER: Apply glow effect to existing card
# ---------------------------------------------------------------
def apply_glow_effect(widget: QFrame, glow_color: QColor = None, header_height: int = 80):
    """
    Apply glow effect to an existing QFrame-based widget.
    This monkey-patches the widget's paint and mouse events.

    Args:
        widget: The QFrame widget to add glow to
        glow_color: Color of the glow (QColor or hex string)
        header_height: Height of the header region for brighter glow
    """
    if isinstance(glow_color, str):
        glow_color = QColor(glow_color)
    elif glow_color is None:
        glow_color = QColor(37, 99, 235, 70)

    # Store glow settings on widget
    widget._glow_color = glow_color
    widget._glow_color_header = QColor(
        glow_color.red(), glow_color.green(), glow_color.blue(),
        min(255, int(glow_color.alpha() * 2.2))
    )
    widget._glow_radius = 180
    widget._glow_header_height = header_height
    widget._glow_mouse_pos = None
    widget._glow_border_radius = 12

    # Enable mouse tracking and disable auto-fill
    widget.setMouseTracking(True)
    widget.setAttribute(Qt.WidgetAttribute.WA_Hover, True)
    widget.setAutoFillBackground(False)
    widget.setAttribute(Qt.WidgetAttribute.WA_OpaquePaintEvent, False)

    # Store original methods
    original_paint = widget.paintEvent
    original_mouse_move = widget.mouseMoveEvent
    original_leave = widget.leaveEvent
    original_enter = widget.enterEvent

    def new_paint_event(event):
        from PySide6.QtGui import QPainterPath

        rect = widget.rect()
        r = widget._glow_border_radius

        # Create path for rounded rectangle
        path = QPainterPath()
        path.addRoundedRect(float(rect.x()), float(rect.y()), float(rect.width()), float(rect.height()), r, r)

        # Start painting
        painter = QPainter(widget)
        painter.setRenderHint(QPainter.RenderHint.Antialiasing)

        # Clip to rounded rect for all painting
        painter.setClipPath(path)

        # 1. Draw solid white background
        painter.fillRect(rect, QColor(255, 255, 255))

        # Glow effect disabled

        # 3. Draw border
        painter.setClipping(False)
        painter.setPen(QPen(QColor("#e5e7eb"), 1.5))
        painter.setBrush(Qt.BrushStyle.NoBrush)
        # Inset slightly for anti-aliased border
        painter.drawRoundedRect(rect.adjusted(1, 1, -1, -1), r - 1, r - 1)

        painter.end()

        # DO NOT call original_paint - we handle everything ourselves
        # Children are painted automatically by Qt after paintEvent returns

    def new_mouse_move(event):
        pos = event.position() if hasattr(event, 'position') else event.pos()
        widget._glow_mouse_pos = pos.toPoint() if hasattr(pos, 'toPoint') else pos
        widget.update()
        original_mouse_move(event)

    def new_enter_event(event):
        widget.update()
        original_enter(event)

    def new_leave_event(event):
        widget._glow_mouse_pos = None
        widget.update()
        original_leave(event)

    # Apply patched methods
    widget.paintEvent = new_paint_event
    widget.mouseMoveEvent = new_mouse_move
    widget.enterEvent = new_enter_event
    widget.leaveEvent = new_leave_event


# ---------------------------------------------------------------
# GLOW CARD MIXIN - For multiple inheritance (kept for compatibility)
# ---------------------------------------------------------------
class GlowCardMixin:
    """
    Mixin for adding glow effect. Call _init_glow() in __init__.
    Note: For best results, use GlowCard base class or apply_glow_effect() instead.
    """

    def _init_glow(self, glow_color: QColor = None, header_height: int = 80):
        """Initialize glow effect."""
        apply_glow_effect(self, glow_color, header_height)


# ---------------------------------------------------------------
# 1. MAC-STYLE TRANSLUCENT BLUR
# ---------------------------------------------------------------
def apply_macos_blur(widget: QWidget):
    """
    On macOS: gives a blurred, semi-translucent acrylic background.
    On Windows/Linux: falls back to a simple translucent style.
    """

    # Detect macOS
    is_macos = QOperatingSystemVersion.currentType() == QOperatingSystemVersion.MacOS

    if is_macos:
        # macOS window blur is applied via NSVisualEffectView
        # Qt does not expose direct blur — apply acrylic style
        widget.setStyleSheet("""
            QWidget {
                background-color: rgba(255, 255, 255, 0.20);
                backdrop-filter: blur(20px);
                border-radius: 12px;
            }
        """)
    else:
        # Windows/Linux fallback — NO blur, but solid translucent background
        widget.setStyleSheet("""
            QWidget {
                background-color: rgba(32, 32, 32, 0.85);   /* 85% opaque */
                border-radius: 12px;
            }
        """)


# ---------------------------------------------------------------
# 2. DROP SHADOW EFFECT
# ---------------------------------------------------------------
def apply_drop_shadow(
    widget: QWidget,
    radius: int = 24,
    color: QColor = QColor(0, 0, 0, 150),
    offset=(0, 4)
):
    """
    Adds soft shadow behind floating panels.
    """
    shadow = QGraphicsDropShadowEffect(widget)
    shadow.setBlurRadius(radius)
    shadow.setColor(color)
    shadow.setOffset(offset[0], offset[1])
    widget.setGraphicsEffect(shadow)


# ---------------------------------------------------------------
# 3. TRANSLUCENT BACKGROUND (Acrylic-style)
# ---------------------------------------------------------------
def make_translucent(widget: QWidget, opacity=None):
    """
    Apply soft acrylic-style translucency without fading all content.
    """
    # DO NOT change widget window opacity (keeps text/charts crisp)
    widget.setAttribute(Qt.WA_TranslucentBackground, False)
