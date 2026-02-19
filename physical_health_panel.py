# ============================================================
# PHYSICAL HEALTH PANEL — PIXEL-ACCURATE TOOLTIP VERSION
# With custom dark tooltip, yellow text, arrow pointer
# ============================================================

import sys
import numpy as np
from PySide6.QtGui import QPainter, QColor, QPolygon
from PySide6.QtCore import QPoint

from datetime import datetime
from io import BytesIO
from typing import Dict, List, Any

from PySide6.QtWidgets import (
    QWidget, QVBoxLayout, QHBoxLayout, QLabel, QPushButton, QScrollArea,
    QSizeGrip, QTableWidget, QTableWidgetItem, QFrame, QApplication
)
from patient_history_panel_shared import CollapsibleSection
from PySide6.QtWidgets import QSizePolicy
from PySide6.QtCore import Qt, QPoint, Signal, QPropertyAnimation, QRect
from PySide6.QtCore import QPointF
from PySide6.QtGui import QPixmap, QImage
from PySide6.QtGui import QCursor
from PySide6.QtGui import QPen
from PySide6.QtGui import QFont
from PySide6.QtGui import QPainterPath

def _normalise_date(d):
    """Convert any RIO date / Excel date / string to a Python datetime."""
    from datetime import datetime
    import pandas as pd

    if d is None:
        return None

    # Already a datetime
    if isinstance(d, datetime):
        return d

    # Pandas to_datetime handles strings, timestamps, excel dates, etc.
    try:
        dt = pd.to_datetime(d, errors="coerce", dayfirst=True)
        if pd.isna(dt):
            return None
        return dt.to_pydatetime()
    except Exception:
        return None

def _clean_sort_dates_vals(dates, vals):
    """Remove entries with bad dates and return sorted (dates, values)."""

    print("\n--- CLEAN SORT DEBUG ---")
    print("RAW DATES  :", dates)
    print("RAW VALUES :", vals)

    pairs = []
    for d, v in zip(dates, vals):
        nd = _normalise_date(d)
        print(f"   Input={d!r}  → Normalised={nd}")
        if nd:
            pairs.append((nd, v))

    print("PAIRS AFTER NORMALISE:", pairs)

    if not pairs:
        print("EMPTY after cleaning!")
        return [], []

    pairs.sort(key=lambda x: x[0])

    sorted_dates = [p[0] for p in pairs]
    sorted_vals = [p[1] for p in pairs]

    print("SORTED DATES:", sorted_dates)
    print("SORTED VALS :", sorted_vals)
    print("--- END CLEAN SORT DEBUG ---\n")

    return sorted_dates, sorted_vals


# -----------------------------------------------------------
# Import shared components (fallbacks included)
# -----------------------------------------------------------
try:
    from patient_history_panel import (
        ResizableEntry,
        CollapsibleSection,
        apply_macos_blur,
    )
except Exception:
    def apply_macos_blur(widget):
        return None

# ============================================================
# FLOATING HANDLE ENTRY FOR PHYSICAL HEALTH PANELS
# ============================================================
class FloatingHandleEntry(QFrame):
    """Used by Physical Health for charts with floating right-side handle."""
    def __init__(self, title_line, html_text="", parent=None, embedded=False):
        super().__init__(parent)
        self.embedded = embedded

        # Different styles for embedded vs floating
        if embedded:
            self.setStyleSheet("""
                QFrame {
                    background-color: #f8f9fa;
                    border: none;
                    border-radius: 8px;
                }
                QLabel {
                    color: #333;
                    background: transparent;
                }
            """)
        else:
            self.setStyleSheet("""
                QFrame {
                    background-color: rgba(55,65,80,0.22);
                    border-radius: 10px;
                }
                QLabel {
                    color: #CFE9FF;
                }
            """)

        self._dragging = False
        self._drag_start_y = 0
        self._orig_height = 0

        self.setMinimumHeight(1)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(16, 18, 16, 18)
        layout.setSpacing(10)

        self.title = QLabel(title_line)
        if embedded:
            self.title.setStyleSheet("font-weight:bold; font-size:15px; color:#333; background:transparent;")
        else:
            self.title.setStyleSheet("font-weight:bold; font-size:16px;")
        layout.addWidget(self.title)

        self.textbox = QLabel(html_text)
        self.textbox.setWordWrap(True)
        if embedded:
            self.textbox.setStyleSheet("color:#555; background:transparent;")
        layout.addWidget(self.textbox)

        # floating handle - hide in embedded mode
        self.handle = QWidget(self)
        self.handle.setFixedWidth(12)
        self.handle.setCursor(Qt.SizeVerCursor)
        if embedded:
            self.handle.setStyleSheet("""
                background-color: rgba(0,0,0,0.15);
                border-radius: 6px;
            """)
        else:
            self.handle.setStyleSheet("""
                background-color: rgba(255,255,255,0.28);
                border-radius: 6px;
            """)
        self.handle.raise_()
        self.handle.show()

    def resizeEvent(self, e):
        super().resizeEvent(e)
        h = self.height()
        self.handle.setGeometry(
            self.width() - 18,
            (h // 2) - 40,
            12,
            80
        )

    def mousePressEvent(self, e):
        # Only consume event when clicking the drag handle
        if e.button() == Qt.LeftButton and self.handle.geometry().contains(e.pos()):
            self._dragging = True
            self._drag_start_y = e.globalPosition().y()
            self._orig_height = self.height()
            e.accept()
        else:
            e.ignore()  # <- LET CHILDREN (CHART) GET EVENT


    def mouseMoveEvent(self, e):
        if self._dragging:
            dy = e.globalPosition().y() - self._drag_start_y
            new_h = max(160, int(self._orig_height + dy))
            self.setFixedHeight(new_h)
            e.accept()
        else:
            e.ignore()  # <- LET CHILDREN GET HOVER EVENTS


    def mouseReleaseEvent(self, e):
        if self._dragging:
            self._dragging = False
            e.accept()
        else:
            e.ignore()

class ResizableEntry(QFrame):
        """A collapsible content box with a floating drag handle on the right side."""

        def __init__(self, title_line, html_text="", parent=None, embedded=False):
            super().__init__(parent)
            self.embedded = embedded

            # Different styles for embedded vs floating
            if embedded:
                self.setStyleSheet("""
                    QFrame {
                        background-color: #f8f9fa;
                        border: none;
                        border-radius: 8px;
                    }
                    QLabel {
                        color: #333;
                        background: transparent;
                    }
                """)
            else:
                self.setStyleSheet("""
                    QFrame {
                        background-color: rgba(55,65,80,0.22);
                        border-radius: 10px;
                    }
                    QLabel {
                        color: #CFE9FF;
                    }
                """)

            self._dragging = False
            self._drag_start_y = 0
            self._orig_height = 0

            self.setMinimumHeight(1)

            # --- Layout ------------------------------------------
            layout = QVBoxLayout(self)
            layout.setContentsMargins(16, 18, 16, 18)
            layout.setSpacing(10)

            # Title
            self.title = QLabel(title_line)
            if embedded:
                self.title.setStyleSheet("font-weight:bold; font-size:15px; color:#333; background:transparent;")
            else:
                self.title.setStyleSheet("font-weight:bold; font-size:16px;")
            layout.addWidget(self.title)

            # Body text (hidden when charts are added)
            self.textbox = QLabel(html_text)
            self.textbox.setWordWrap(True)
            if embedded:
                self.textbox.setStyleSheet("color:#555; background:transparent;")
            layout.addWidget(self.textbox)

            # --- Floating drag handle overlay ----------------------
            self.handle = QWidget(self)
            self.handle.setFixedWidth(12)
            self.handle.setCursor(Qt.SizeVerCursor)
            if embedded:
                self.handle.setStyleSheet("""
                    background-color: rgba(0,0,0,0.15);
                    border-radius: 6px;
                """)
            else:
                self.handle.setStyleSheet("""
                    background-color: rgba(255,255,255,0.25);
                    border-radius: 6px;
                """)
            self.handle.raise_()
            self.handle.show()
            

        # ---------------------------------------------------------------
        # FLOATING HANDLE POSITIONING
        # ---------------------------------------------------------------
        def resizeEvent(self, e):
            super().resizeEvent(e)

            # Always float at right edge, vertically centred
            h = self.height()
            self.handle.setGeometry(
                self.width() - 18,      # x offset from right
                (h // 2) - 40,          # y position
                12,                     # width
                80                      # height
            )

        # ---------------------------------------------------------------
        # MOUSE EVENTS FOR DRAGGING HANDLE
        # ---------------------------------------------------------------
        def mousePressEvent(self, e):
            # Only consume mouse when clicking handle
            if e.button() == Qt.LeftButton and self.handle.geometry().contains(e.pos()):
                self._dragging = True
                self._drag_start_y = e.globalPosition().y()
                self._orig_height = self.height()
                e.accept()
            else:
                e.ignore()   # <- CRITICAL


        def mouseMoveEvent(self, e):
            if self._dragging:
                dy = e.globalPosition().y() - self._drag_start_y
                new_height = max(140, int(self._orig_height + dy))
                self.setFixedHeight(new_height)
                e.accept()
            else:
                e.ignore()   # <- CRITICAL


        def mouseReleaseEvent(self, e):
            if self._dragging:
                self._dragging = False
                e.accept()
            else:
                e.ignore()

class HorizontalResizableEntry(QWidget):
    """A resizable container with a horizontal drag pill under the content."""

    def __init__(self, title="", parent=None):
        super().__init__(parent)
        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Minimum)
        self.setMinimumHeight(120)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        # Title
        self.title_lbl = QLabel(title)
        self.title_lbl.setStyleSheet("color: white; font-size: 16px;")
        self.title_lbl.setAlignment(Qt.AlignLeft | Qt.AlignVCenter)
        layout.addWidget(self.title_lbl)

        # Content area
        self.content = QWidget()
        self.content.setLayout(QVBoxLayout())
        self.content.layout().setContentsMargins(8, 8, 8, 8)
        self.content.layout().setSpacing(0)

        # ⭐ THIS IS THE CORRECT LOCATION ⭐
        self.content.layout().setStretch(0, 1)

        layout.addWidget(self.content)
        layout.setStretchFactor(self.content, 1)

        # Resize pill (horizontal)
        self.handle = QLabel("⟷")
        self.handle.setAlignment(Qt.AlignCenter)
        self.handle.setFixedHeight(18)
        self.handle.setStyleSheet("""
            QLabel {
                background-color: rgba(255,255,255,0.25);
                color: white;
                border-radius: 6px;
                margin: 6px 80px;  /* centre it */
            }
        """)
        layout.addWidget(self.handle)

        self.handle.installEventFilter(self)
        self.drag_start_y = None

    def eventFilter(self, src, event):
        from PySide6.QtCore import QEvent

        if src is self.handle:

            # DRAG START
            if event.type() == QEvent.MouseButtonPress:
                self.drag_start_y = event.globalY()
                event.accept()
                return True

            # DRAG MOVE
            if event.type() == QEvent.MouseMove and self.drag_start_y is not None:
                dy = event.globalY() - self.drag_start_y
                new_h = max(120, self.height() + dy)
                self.setFixedHeight(new_h)
                self.drag_start_y = event.globalY()
                event.accept()
                return True
    
            # DRAG END
            if event.type() == QEvent.MouseButtonRelease:
                self.drag_start_y = None
                event.accept()
                return True
    
        # FOR ALL OTHER EVENTS → let CHILD (chart/table) receive them
        return QWidget.eventFilter(self, src, event)

# ============================================================
# CUSTOM FLOATING TOOLTIP WITH ARROW (dark + yellow text)
# ============================================================

class FloatingTooltip(QWidget):
    def __init__(self):
        super().__init__(None)

        self.setWindowFlags(
            Qt.FramelessWindowHint |
            Qt.WindowStaysOnTopHint |
            Qt.NoDropShadowWindowHint
        )

        self.setAttribute(Qt.WA_TranslucentBackground)
        self.setAttribute(Qt.WA_ShowWithoutActivating)
        self.setAttribute(Qt.WA_TransparentForMouseEvents)

        self.setStyleSheet("""
            QWidget {
                background-color: rgba(20, 20, 20, 220);
                border-radius: 8px;
                border: 1px solid rgba(255, 255, 255, 40);
            }
            QLabel {
                color: #FFD93D;
                padding: 4px 8px;
                font-size: 13px;
            }
        """)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(8, 8, 8, 8)
        self.lbl = QLabel("")
        layout.addWidget(self.lbl)

        self.anim = QPropertyAnimation(self, b"windowOpacity")
        self.anim.setDuration(120)
        self.setWindowOpacity(0)

        self.arrow_h = 8

    def set_text(self, text):
        self.lbl.setText(text)
        self.adjustSize()

    def show_fade(self, pos):
        self.move(pos)
        self.raise_()
        self.anim.stop()
        self.setWindowOpacity(0)
        self.show()
        self.anim.setStartValue(0)
        self.anim.setEndValue(1)
        self.anim.start()

    def hide_fade(self):
        self.anim.stop()
        self.anim.setStartValue(1)
        self.anim.setEndValue(0)
        self.anim.finished.connect(self.hide)
        self.anim.start()

    def paintEvent(self, e):

        # 🔒 Prevent crash: Tooltip has no dates/series
        if not hasattr(self, "dates"):
            return super().paintEvent(e)

        # (Optional) Remove debug print entirely
        # print("CHART PAINT:", self.width(), self.height(),
        #       "dates:", len(self.dates),
        #       "series:", {k: len(v) for k, v in self.series.items()})

        super().paintEvent(e)
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)

        w = self.width()
        arrow = QPolygon([
            QPoint((w // 2) - 6, self.height() - 1),
            QPoint((w // 2) + 6, self.height() - 1),
            QPoint((w // 2), self.height() + self.arrow_h - 1),
        ])

        p.setBrush(QColor(20, 20, 20, 220))
        p.setPen(QColor(255, 255, 255, 40))
        p.drawPolygon(arrow)
        p.end()


class OverlayTooltip(QWidget):
    def __init__(self, parent):
        super().__init__(parent)

        # normal child widget, guarantees visibility
        self.setAttribute(Qt.WA_TransparentForMouseEvents)
        self.setAttribute(Qt.WA_ShowWithoutActivating)
        self.setWindowOpacity(0)

        self.setStyleSheet("""
            QWidget {
                background-color: rgba(20, 20, 20, 220);
                border-radius: 8px;
                border: 1px solid rgba(255,255,255,40);
            }
            QLabel {
                color: #FFD93D;
                padding: 4px 8px;
                font-size: 13px;
            }
        """)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(8,8,8,8)
        self.lbl = QLabel("")
        layout.addWidget(self.lbl)

        self.anim = QPropertyAnimation(self, b"windowOpacity")
        self.anim.setDuration(120)

    def set_text(self, text):
        self.lbl.setText(text)
        self.adjustSize()

    def show_at(self, x, y):
        self.move(x, y)
        self.raise_()
        self.anim.stop()
        self.setWindowOpacity(0)
        self.show()
        self.anim.setStartValue(0)
        self.anim.setEndValue(1)
        self.anim.start()

    def hide_now(self):
        self.hide()

# ============================================================
# NEW INTERACTIVE CHARTS (CLICK + HOVER FIXED)
# ============================================================

def wrap_chart_in_hscroll(chart, min_width=800):
    """Wrap a chart widget in a horizontal scroll area."""
    scroll = QScrollArea()
    scroll.setWidgetResizable(False)
    scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOn)  # Always show scrollbar
    scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
    scroll.setFrameShape(QScrollArea.Shape.NoFrame)
    scroll.setStyleSheet("""
        QScrollArea {
            background: transparent;
            border: none;
        }
        QScrollBar:horizontal {
            background: #e0e0e0;
            height: 12px;
            border-radius: 6px;
        }
        QScrollBar::handle:horizontal {
            background: #999;
            border-radius: 6px;
            min-width: 40px;
        }
        QScrollBar::handle:horizontal:hover {
            background: #777;
        }
    """)

    # Chart manages its own width based on zoom level
    scroll.setWidget(chart)
    scroll.setMinimumHeight(chart.minimumHeight() + 18)  # Extra for scrollbar
    return scroll


class QtLineChart(QWidget):
    pointClicked = Signal(object)
    pointHovered = Signal(object)

    BASE_WIDTH = 800  # Base width at zoom=1

    def __init__(self, dates, series_dict, unit="", parent=None):
        super().__init__(parent)
        self.setMouseTracking(True)

        self.dates = dates
        self.series = series_dict
        self.unit = unit

        self.date_nums = np.array([d.timestamp() for d in dates])

        self.margin_left = 70
        self.margin_bottom = 50
        self.margin_top = 30
        self.margin_right = 30

        # zoom state - widget gets wider when zoomed
        self.zoom = 1.0
        self._dragging = False
        self._last_mouse_x = 0

        # tooltip
        self.tooltip = OverlayTooltip(self)
        self.tooltip.hide()
        self.hover_point = None

        # point cache (rebuilt every paintEvent)
        self._point_cache = []

        # colours
        self.color_map = {
            "BMI": QColor(255, 230, 90),
            "Systolic": QColor(255, 90, 90),
            "Diastolic": QColor(90, 180, 255),
        }
        for name in series_dict:
            if name not in self.color_map:
                self.color_map[name] = QColor(180, 220, 255)

        self.setMinimumHeight(260)
        self._update_width()

    # ---------------------------------------------------------
    # WIDTH UPDATE (chart gets wider when zoomed)
    # ---------------------------------------------------------
    def _update_width(self):
        new_width = int(self.BASE_WIDTH * self.zoom)
        self.setFixedWidth(new_width)

    # ---------------------------------------------------------
    # RANGE HELPERS
    # ---------------------------------------------------------
    def _visible_x_range(self):
        full_min = float(np.min(self.date_nums))
        full_max = float(np.max(self.date_nums))
        return full_min, full_max

    def _map_x(self, date_num):
        left, right = self._visible_x_range()
        w = self.width() - self.margin_left - self.margin_right
        if w <= 0 or right == left:
            return self.margin_left

        return self.margin_left + (date_num - left) / (right - left) * w

    def _map_y(self, value):
        h = self.height() - self.margin_top - self.margin_bottom
        if h <= 0:
            return self.margin_top + h / 2

        all_vals = np.concatenate(list(self.series.values()))
        vmin = float(np.min(all_vals))
        vmax = float(np.max(all_vals))
        pad = (vmax - vmin) * 0.1
        vmin -= pad
        vmax += pad

        if vmax == vmin:
            return self.margin_top + h / 2

        return self.margin_top + (vmax - value) / (vmax - vmin) * h

    # ---------------------------------------------------------
    # MAIN PAINT
    # ---------------------------------------------------------
    def paintEvent(self, e):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)

        try:
            p.fillRect(self.rect(), QColor(28, 32, 38))

            left = self.margin_left
            top = self.margin_top
            right = self.width() - self.margin_right
            bottom = self.height() - self.margin_bottom

            # reset point cache
            self._point_cache = []

            # grid
            p.setPen(QPen(QColor(70, 70, 70), 1))
            for i in range(6):
                y = top + (i / 5) * (bottom - top)
                p.drawLine(left, y, right, y)

            # axes
            p.setPen(QPen(QColor(255, 255, 255), 2))
            p.drawLine(left, bottom, right, bottom)
            p.drawLine(left, top, left, bottom)

            # axis labels
            p.setFont(QFont("Segoe UI", 12))
            p.setPen(QColor(200, 200, 200))

            x_left_ts, x_right_ts = self._visible_x_range()
            dt_l = datetime.fromtimestamp(x_left_ts)
            dt_r = datetime.fromtimestamp(x_right_ts)

            p.drawText(left, bottom + 28, dt_l.strftime("%b %Y"))
            p.drawText(right - 60, bottom + 28, dt_r.strftime("%b %Y"))

            # --- series ---
            for name, vals in self.series.items():
                c = self.color_map[name]
                p.setPen(QPen(c, 3))

                pts = []
                for dt, val in zip(self.date_nums, vals):
                    px = self._map_x(dt)
                    py = self._map_y(val)
                    pts.append((px, py))
                    self._point_cache.append((dt, px, py, val, name))

                # smooth curves
                if len(pts) >= 2:
                    for i in range(len(pts) - 1):
                        x1, y1 = pts[i]
                        x2, y2 = pts[i + 1]

                        cx1 = x1 + (x2 - x1) * 0.33
                        cy1 = y1
                        cx2 = x1 + (x2 - x1) * 0.66
                        cy2 = y2

                        path = QPainterPath()
                        path.moveTo(QPointF(x1, y1))
                        path.cubicTo(QPointF(cx1, cy1),
                                     QPointF(cx2, cy2),
                                     QPointF(x2, y2))
                        p.drawPath(path)

                # markers
                p.setBrush(c)
                p.setPen(Qt.NoPen)
                for (px, py) in pts:
                    p.drawEllipse(QPointF(px, py), 5, 5)

            # tooltip
            if self.hover_point:
                    dt, px, py, val, name = self.hover_point

                    txt = f"{datetime.fromtimestamp(dt):%d %b %Y}\n{name}: {val} {self.unit}"
                    self.tooltip.set_text(txt)

                    # ---------------------------
                    # SAFE POSITIONING
                    # ---------------------------
                    tw = self.tooltip.width()
                    th = self.tooltip.height()

                    # 1. Start centered above point
                    tx = px - tw / 2
                    ty = py - th - 15

                    # 2. Clamp horizontally to chart bounds
                    chart_left = self.margin_left
                    chart_right = self.width() - self.margin_right

                    if tx < chart_left:
                            tx = chart_left
                    if tx + tw > chart_right:
                            tx = chart_right - tw

                    # 3. Clamp vertically (never above chart top)
                    if ty < self.margin_top:
                            ty = self.margin_top

                    self.tooltip.move(int(tx), int(ty))
                    self.tooltip.show()
            else:
                    self.tooltip.hide()

        finally:
            p.end()

    # ---------------------------------------------------------
    # INTERACTION
    # ---------------------------------------------------------
    def mouseMoveEvent(self, e):
        mx = e.position().x()

        best = None
        best_dist = 999999

        for dt, px, py, val, name in self._point_cache:
            d = abs(px - mx)
            if d < best_dist and d < 25:
                best_dist = d
                best = (dt, px, py, val, name)

        self.hover_point = best
        self.update()

    def mousePressEvent(self, e):
        if e.button() == Qt.LeftButton:
            self._dragging = True
            self._last_mouse_x = e.position().x()

            # CLICK EVENT
            mx = e.position().x()
            best_dt = None
            best_dist = 999999

            for dt, px, py, val, name in self._point_cache:
                d = abs(px - mx)
                if d < best_dist and d < 20:
                    best_dist = d
                    best_dt = dt

            if best_dt is not None:
                self.pointClicked.emit(datetime.fromtimestamp(best_dt))

    def mouseReleaseEvent(self, e):
        self._dragging = False

    def wheelEvent(self, e):
        delta = e.angleDelta().y()
        if delta > 0:
            self.zoom *= 1.2
        else:
            self.zoom /= 1.2

        self.zoom = max(1.0, min(self.zoom, 10.0))
        self._update_width()
        self.update()
# ============================================================

def _latest_entry(entries):
    usable = []
    for e in entries:
        nd = _normalise_date(e.get("date"))
        if nd:
            usable.append((nd, e))

    if not usable:
        return None

    usable.sort(key=lambda x: x[0])
    return usable[-1][1]

# ============================================================
# PHYSICAL HEALTH PANEL
# ============================================================

class PhysicalHealthPanel(QWidget):

    def _to_float(v):
        try:
            return float(v)
        except:
            return None


    def __init__(self, phys_dict, parent=None, embedded=False):
        super().__init__(parent)

        self.phys = phys_dict or {}
        self._drag_offset = QPoint()
        self._panel_dragging = False
        self.embedded = embedded

        # Window settings - only for floating mode
        if not embedded:
            self.setWindowFlags(Qt.FramelessWindowHint | Qt.SubWindow)
            self.setCursor(Qt.CursorShape.OpenHandCursor)
            self.resize(980, 820)
            self.setMinimumSize(1, 1)
        else:
            # Allow shrinking when embedded
            self.setMinimumSize(1, 1)
            self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        # Track right anchor resizing
        self._last_width = self.width()
        self._last_right = self.x() + self.width()

        self._build_ui()
        self.populate()

        # =====================================================
        # TEST TOOLTIP — MUST APPEAR AT SCREEN COORD (300,300)
        # =====================================================
        from physical_health_panel import FloatingTooltip
        test_tip = FloatingTooltip()
        test_tip.set_text("TEST TOOLTIP")
        test_tip.move(300, 300)
        test_tip.show()


        try:
            apply_macos_blur(self)
        except Exception:
            pass

    # -----------------------------------------------------------
    # DRAG WINDOW - drag from anywhere
    # -----------------------------------------------------------
    def _drag_start(self, e):
        if e.button() == Qt.LeftButton:
            self._drag_offset = e.globalPosition().toPoint() - self.frameGeometry().topLeft()

    def _drag_move(self, e):
        if e.buttons() & Qt.LeftButton:
            self.move(e.globalPosition().toPoint() - self._drag_offset)

    def mousePressEvent(self, event):
        if self.embedded:
            return super().mousePressEvent(event)
        if event.button() == Qt.MouseButton.LeftButton:
            self._panel_dragging = True
            self._drag_offset = event.globalPosition().toPoint() - self.frameGeometry().topLeft()
            self.setCursor(Qt.CursorShape.ClosedHandCursor)

    def mouseMoveEvent(self, event):
        if self.embedded:
            return super().mouseMoveEvent(event)
        if self._panel_dragging:
            self.move(event.globalPosition().toPoint() - self._drag_offset)

    def mouseReleaseEvent(self, event):
        if self.embedded:
            return super().mouseReleaseEvent(event)
        self._panel_dragging = False
        self.setCursor(Qt.CursorShape.OpenHandCursor)

    # -----------------------------------------------------------
    # RIGHT-ANCHOR WINDOW RESIZE
    # -----------------------------------------------------------
    def resizeEvent(self, event):
        super().resizeEvent(event)

        # Let the panel resize normally — no anchoring.
        self._last_width = self.width()
        
    # -----------------------------------------------------------
    # UI SETUP
    # -----------------------------------------------------------
    def _build_ui(self):
        # Different styles for embedded vs floating
        if self.embedded:
            self.setStyleSheet("""
                QWidget { background-color: white; color: #333; }
                QLabel { background: transparent; color: #333; }
            """)
        else:
            self.setStyleSheet("""
                QWidget { background-color: rgba(25,28,33,0.28);
                          color:white; border-radius:12px; }
            """)

        outer = QVBoxLayout(self)
        outer.setContentsMargins(12,12,12,12)
        outer.setSpacing(12)

        # -------------------------------------------------------
        # TITLE BAR
        # -------------------------------------------------------
        self.title_bar = QWidget()
        self.title_bar.setFixedHeight(46)
        if not self.embedded:
            self.title_bar.setCursor(Qt.CursorShape.OpenHandCursor)
            self.title_bar.setStyleSheet("""
                background-color: rgba(40,45,52,0.32);
                border-top-left-radius:12px;
                border-top-right-radius:12px;
            """)
        else:
            self.title_bar.setStyleSheet("""
                background-color: rgba(240,242,245,0.95);
                border-bottom: 1px solid #d0d5da;
            """)

        tb = QHBoxLayout(self.title_bar)
        tb.setContentsMargins(12,4,12,4)

        title = QLabel("Physical Health Overview")
        if self.embedded:
            title.setStyleSheet("font-size:18px; font-weight:bold; color:#333; background:transparent;")
        else:
            title.setStyleSheet("font-size:22px; font-weight:bold;")
        tb.addWidget(title)
        tb.addStretch()

        # Only add close button for floating mode
        if not self.embedded:
            close_btn = QPushButton("✕")
            close_btn.setFixedSize(34,28)
            close_btn.clicked.connect(self.close)
            tb.addWidget(close_btn)

        outer.addWidget(self.title_bar)

        if not self.embedded:
            self.title_bar.mousePressEvent = self._drag_start
            self.title_bar.mouseMoveEvent = self._drag_move

        # -------------------------------------------------------
        # SCROLL AREA
        # -------------------------------------------------------
        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        if self.embedded:
            self.scroll.setStyleSheet("""
                QScrollArea { background: white; border: none; }
                QScrollBar:vertical { background: rgba(0,0,0,0.05); width: 10px; border-radius: 5px; }
                QScrollBar::handle:vertical { background: rgba(0,0,0,0.2); border-radius: 5px; }
            """)
        outer.addWidget(self.scroll)

        # -------------------------------------------------------
        # INNER CONTENT
        # -------------------------------------------------------
        self.inner = QWidget()
        if self.embedded:
            self.inner.setStyleSheet("background: white;")
        from PySide6.QtWidgets import QSizePolicy
        self.inner.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

        self.inner_layout = QVBoxLayout(self.inner)
        self.inner_layout.setAlignment(Qt.AlignTop)
        self.inner_layout.setSpacing(26)
        self.inner_layout.setContentsMargins(12,12,12,40)

        self.scroll.setWidget(self.inner)
        # -------------------------------------------------------
        # RESIZE GRIP (bottom-right) - only for floating mode
        # -------------------------------------------------------
        if not self.embedded:
            grip = QSizeGrip(self)
            grip.setFixedSize(22, 22)
            outer.addWidget(grip, alignment=Qt.AlignBottom | Qt.AlignRight)
            self.grip = grip
        else:
            self.grip = None

    # -----------------------------------------------------------
    # CLICK-ON-CHART → jump to correct note date
    # -----------------------------------------------------------
    def _chart_point_clicked(self, dt):
        mw = self.window()
        if mw is None:
            print("No MainWindow for jump")
            return

        target_page = None
        for w in mw.findChildren(QWidget, options=Qt.FindChildrenRecursively):
            if w.__class__.__name__ == "PatientNotesPage":
                target_page = w
                break

        if not target_page:
            print("PatientNotesPage not found")
            return

        try:
            target_page.notes_panel.jump_to_date(dt)
        except Exception as e:
            print("jump_to_date failed:", e)

    # -----------------------------------------------------------
    # POPULATE CONTENT
    # -----------------------------------------------------------
    def populate(self):

        phys = self.phys
        bloods = phys.get("bloods", {})

        # Debug dump
        print("\n======== PHYSICAL HEALTH PANEL DEBUG ========")
        for tid, entries in bloods.items():
            print(f"\nTEST_ID {tid}: {len(entries)} results")
            for e in entries:
                print(f"   {e['date']} → {e['value']} {e['unit']}")
        print("======== END DEBUG ========\n")

        # SUMMARY
        summary_html = self._build_summary_html()
        summary_entry = ResizableEntry("Summary of Physical Health", summary_html, parent=self, embedded=self.embedded)
        #summary_entry.textbox.setReadOnly(True)
        summary_entry.layout().setAlignment(Qt.AlignLeft | Qt.AlignTop)
        self.inner_layout.addWidget(summary_entry)

        # BMI
        bmi_sec = CollapsibleSection("BMI", start_collapsed=True, embedded=self.embedded)
        self.inner_layout.addWidget(bmi_sec)
        self._add_bmi_box(bmi_sec)

        # BP
        bp_sec = CollapsibleSection("Blood Pressure", start_collapsed=True, embedded=self.embedded)
        self.inner_layout.addWidget(bp_sec)
        self._add_bp_box(bp_sec)

        # BLOOD TESTS
        blood_sec = CollapsibleSection("Blood Tests", start_collapsed=True, embedded=self.embedded)
        self.inner_layout.addWidget(blood_sec)
        self._add_bloods(blood_sec)

    # -----------------------------------------------------------
    # SUMMARY HTML
    # -----------------------------------------------------------
    def _build_summary_html(self):
        bmi = _latest_entry(self.phys.get("bmi", []))
        bp  = _latest_entry(self.phys.get("bp", []))
        bloods = self.phys.get("bloods", {})

        def fmt(d):
            nd = _normalise_date(d)
            return nd.strftime("%d %b %Y") if nd else "Unknown"

        bmi_txt = "No BMI data."
        if bmi:
            bmi_txt = f"Latest BMI: <b>{bmi['bmi']}</b> on {fmt(bmi['date'])}"

        bp_txt = "No BP data."
        if bp:
            bp_txt = f"Latest BP: <b>{bp['sys']}/{bp['dia']}</b> mmHg on {fmt(bp['date'])}"

        blood_count = sum(len(v) for v in bloods.values())
        blood_txt = f"{blood_count} results across {len(bloods)} tests."

        # Use dark text for embedded mode, light for floating
        text_color = "#333" if self.embedded else "#e0e0e0"

        return f"""
            <div style='font-size:13px; color:{text_color};'>
                <p>{bmi_txt}</p>
                <p>{bp_txt}</p>
                <p>{blood_txt}</p>
            </div>
        """

    
    def _add_bmi_box(self, section):
        bmi = self.phys.get("bmi", [])

        entry = FloatingHandleEntry("BMI Trend", "", parent=self, embedded=self.embedded)

        if not bmi:
            entry.textbox.setText("No BMI data available.")
            section.add_widget(entry)
            return

        # --- CLEAN + SORT DATE/VALUE PAIRS ---
        raw_dates = [e["date"] for e in bmi]
        raw_vals = [e["bmi"] for e in bmi]

        dates, vals = _clean_sort_dates_vals(raw_dates, raw_vals)

        if not dates:
            entry.textbox.setText("No valid BMI dates.")
            section.add_widget(entry)
            return

        # --- BUILD CHART ---
        chart = QtLineChart(
            dates,
            {"BMI": vals},
            unit="BMI",
            parent=self
        )
        chart.pointClicked.connect(self._chart_point_clicked)

        # ---- FIX: Make chart fully visible ----
        chart.setMinimumHeight(300)
        chart.setMaximumHeight(300)
        chart.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)

        # Wrap in horizontal scroll
        scroll_chart = wrap_chart_in_hscroll(chart, min_width=600)

        # --- INSERT ---
        entry.textbox.setVisible(False)
        entry.layout().addWidget(scroll_chart)
        entry.layout().setAlignment(Qt.AlignLeft | Qt.AlignTop)

        section.add_widget(entry)


    def _add_bp_box(self, section):
        bp = self.phys.get("bp", [])

        entry = FloatingHandleEntry("Blood Pressure Trend", "", parent=self, embedded=self.embedded)

        if not bp:
            entry.textbox.setText("No BP data available.")
            section.add_widget(entry)
            return

        raw_dates = [e["date"] for e in bp]
        vals_sys = [e["sys"] for e in bp]
        vals_dia = [e["dia"] for e in bp]

        dates, sys_vals = _clean_sort_dates_vals(raw_dates, vals_sys)
        _, dia_vals = _clean_sort_dates_vals(raw_dates, vals_dia)

        if not dates:
            entry.textbox.setText("No valid BP dates.")
            section.add_widget(entry)
            return

        series = {
            "Systolic": sys_vals,
            "Diastolic": dia_vals
        }

        chart = QtLineChart(
            dates,
            series,
            unit="mmHg",
            parent=self
        )
        chart.pointClicked.connect(self._chart_point_clicked)

        # ---- FIX: Make chart fully visible ----
        chart.setMinimumHeight(300)
        chart.setMaximumHeight(300)
        chart.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)

        # Wrap in horizontal scroll
        scroll_chart = wrap_chart_in_hscroll(chart, min_width=600)

        entry.textbox.setVisible(False)
        entry.layout().addWidget(scroll_chart)
        entry.layout().setAlignment(Qt.AlignLeft | Qt.AlignTop)

        section.add_widget(entry)



    # -----------------------------------------------------------
    # BLOODS BOX — QtLineChart version (NO matplotlib)
    # -----------------------------------------------------------
    def _add_bloods(self, section):
        print("ADDING BLOODS SECTION")

        bloods = self.phys.get("bloods", {})
        if not bloods:
            no = QLabel("No blood test data found.")
            no.setStyleSheet("color:#bbb;")
            section.add_widget(no)
            return

        blood_sec = section

        # -------------------------------------------------------
        # BLOOD TEST TABLE (RESIZABLE)
        # -------------------------------------------------------
        table_entry = HorizontalResizableEntry("Blood Test Table", parent=self)
        table_entry.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Fixed)
        blood_sec.add_widget(table_entry)

        table_wrapper = QWidget()
        table_wrapper.setLayout(QVBoxLayout())
        table_wrapper.layout().setContentsMargins(0, 0, 0, 0)
        table_wrapper.layout().setSpacing(0)

        table = QTableWidget()
        table.setColumnCount(5)
        table.setHorizontalHeaderLabels(["Test", "Value", "Unit", "Flag", "Date"])
        table.horizontalHeader().setStretchLastSection(True)
        table.setEditTriggers(QTableWidget.NoEditTriggers)
        table_wrapper.layout().addWidget(table)
        table_entry.content.layout().addWidget(table_wrapper)

        # -------------------------------------------------------
        # POPULATE TABLE
        # -------------------------------------------------------
        rows = []
        from CANONICAL_BLOODS import CANONICAL_BLOODS

        for tid, entries in bloods.items():
            latest = _latest_entry(entries)
            if not latest:
                continue

            meta = CANONICAL_BLOODS.get(tid, {})
            name = meta.get("canonical", f"Test {tid}")
            val = latest["value"]
            unit = meta.get("unit", "")

            dt = _normalise_date(latest["date"])
            dt_str = dt.strftime("%d %b %Y") if dt else ""

            low = meta.get("normal_low")
            high = meta.get("normal_high")

            if low is not None and high is not None:
                if val < low:
                    flag = "Low"
                elif val > high:
                    flag = "High"
                else:
                    flag = "Normal"
            else:
                flag = ""

            rows.append((name, val, unit, flag, dt_str, dt))

        rows.sort(key=lambda x: x[0])
        table.setRowCount(len(rows))

        for r, (name, val, unit, flag, dt_str, dt) in enumerate(rows):
            table.setItem(r, 0, QTableWidgetItem(name))
            table.setItem(r, 1, QTableWidgetItem(str(val)))
            table.setItem(r, 2, QTableWidgetItem(unit))

            flag_item = QTableWidgetItem(flag)
            if flag == "High":
                flag_item.setForeground(Qt.red)
            elif flag == "Low":
                flag_item.setForeground(Qt.yellow)
            table.setItem(r, 3, flag_item)

            table.setItem(r, 4, QTableWidgetItem(dt_str))

        table.resizeColumnsToContents()

        def table_click(row, col):
            dt = rows[row][5]
            if dt:
                self._chart_point_clicked(dt)
        table.cellClicked.connect(table_click)

        # -------------------------------------------------------
        # PER-TEST COLLAPSIBLE CHARTS (QtLineChart)
        # -------------------------------------------------------
        for tid, entries in bloods.items():
                meta = CANONICAL_BLOODS.get(tid, {})
                name = meta.get("canonical", f"Test {tid}")
                unit = meta.get("unit", "")

                raw_dates = [e["date"] for e in entries]
                raw_vals = [e["value"] for e in entries]

                dates, vals = _clean_sort_dates_vals(raw_dates, raw_vals)
                if not dates:
                        continue

                chart_sec = CollapsibleSection(name, start_collapsed=True, embedded=self.embedded)
                blood_sec.add_widget(chart_sec)

                wrapper = QWidget()
                lay = QVBoxLayout(wrapper)
                lay.setContentsMargins(0, 10, 0, 10)

                chart = QtLineChart(
                        dates,
                        {name: vals},
                        unit=unit,
                        parent=self
                )
                chart.pointClicked.connect(self._chart_point_clicked)

                # ⭐ FORCE VISIBLE HEIGHT — REQUIRED
                chart.setMinimumHeight(300)
                chart.setMaximumHeight(300)

                # Wrap in horizontal scroll
                scroll_chart = wrap_chart_in_hscroll(chart, min_width=600)

                lay.addWidget(scroll_chart)
                chart_sec.add_widget(wrapper)
    # ============================================================
    # END OF FILE
    # ============================================================

