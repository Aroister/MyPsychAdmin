# timeline_panel.py — Final Clean Version (Avie + ChatGPT)
# ----------------------------------------------------------
# Fully cleaned, stable, click-to-jump capable timeline panel
# (Based on your uploaded version)

from __future__ import annotations

from datetime import date, timedelta
from typing import List, Dict, Any, Optional

from PySide6.QtWidgets import QWidget, QToolTip, QScrollBar, QVBoxLayout
from PySide6.QtGui import QPainter, QColor, QPen, QBrush, QFont
from PySide6.QtCore import Qt, QRectF, QPoint, Signal


MIN_VIEW_DAYS = 60
MAX_TICKS = 100
BOTTOM_GAP = 10
MAX_BOX_HEIGHT = 260


# ===================================================================
# INTERNAL CANVAS
# ===================================================================
class _TimelineCanvas(QWidget):
    episodeClicked = Signal(date)

    def __init__(self, parent=None):
        super().__init__(parent)

        self._episodes: List[Dict[str, Any]] = []
        self._min_date: Optional[date] = None
        self._max_date: Optional[date] = None
        self._view_start: Optional[date] = None
        self._view_end: Optional[date] = None

        self._panning = False
        self._last_mouse_x = 0.0
        self._hover_ep: Optional[Dict[str, Any]] = None
        self._scrollbar: Optional[QScrollBar] = None

        # Fonts
        base = self.font()
        axis_font = QFont(base)
        axis_font.setPointSize(max((axis_font.pointSize() + 2), 12))
        axis_font.setBold(True)
        self._axis_font = axis_font

        tt_font = QFont(base)
        tt_font.setPointSize(max((tt_font.pointSize() + 2), 12))
        tt_font.setBold(True)
        QToolTip.setFont(tt_font)

        self.setMinimumHeight(200)
        self.setMouseTracking(True)

    # ------------------------------------------------------------
    def set_scrollbar(self, sb: QScrollBar):
        self._scrollbar = sb
        sb.valueChanged.connect(self._on_scrollbar_changed)

    # ------------------------------------------------------------
    def set_episodes(self, episodes: List[Dict[str, Any]]):
        self._episodes = episodes or []

        if not episodes:
            self._min_date = None
            self._max_date = None
            self._view_start = None
            self._view_end = None
            self._update_scrollbar()
            self.update()
            return

        self._min_date = min(ep["start"] for ep in episodes)
        self._max_date = max(ep["end"] for ep in episodes)

        self._view_start = self._min_date
        self._view_end = self._max_date

        self._hover_ep = None
        self._update_scrollbar()
        self.update()

    # ------------------------------------------------------------
    def _days_between(self, d1: date, d2: date) -> int:
        return (d2 - d1).days

    def _date_to_x(self, d: date, left: int, width: int) -> float:
        if not (self._view_start and self._view_end):
            return left
        total = max(1, self._days_between(self._view_start, self._view_end))
        offset = self._days_between(self._view_start, d)
        return left + (offset / total) * width

    def _x_to_date(self, x: float, left: int, width: int) -> date:
        if not (self._view_start and self._view_end):
            return date.today()
        rel = max(0.0, min(1.0, (x - left) / max(1.0, float(width))))
        total = max(1, self._days_between(self._view_start, self._view_end))
        return self._view_start + timedelta(days=int(rel * total))

    # ------------------------------------------------------------
    # CLICK HANDLER — emits episode start
    # ------------------------------------------------------------
    def mousePressEvent(self, event):
        if event.button() != Qt.LeftButton:
            return

        # Panning anchor
        self._panning = True
        self._last_mouse_x = event.position().x()

        if not (self._view_start and self._view_end and self._episodes):
            return

        outer_margin = 8
        padding_x = 20
        tl_left = outer_margin + padding_x
        tl_width = max(10, self.width() - 2 * outer_margin - 2 * padding_x)

        click_date = self._x_to_date(event.position().x(), tl_left, tl_width)

        for ep in self._episodes:
            if ep["start"] <= click_date <= ep["end"]:
                print("TIMELINE CLICKED → sending:", ep["start"])
                self.episodeClicked.emit(ep["start"])
                break

    # ------------------------------------------------------------
    def mouseMoveEvent(self, event):
        if not (self._view_start and self._view_end and self._min_date and self._max_date):
            return

        outer_margin = 8
        padding_x = 20
        tl_left = outer_margin + padding_x
        tl_width = max(10, self.width() - 2 * outer_margin - 2 * padding_x)

        # PAN
        if self._panning:
            dx = event.position().x() - self._last_mouse_x
            self._last_mouse_x = event.position().x()

            total_days = max(1, self._days_between(self._view_start, self._view_end))
            shift_days = int(-dx / max(1.0, tl_width) * total_days)

            self._view_start += timedelta(days=shift_days)
            self._view_end += timedelta(days=shift_days)
            self._clamp_view()
            self._update_scrollbar()
            self.update()
            return

        # HOVER
        mx = event.position().x()
        date_pos = self._x_to_date(mx, tl_left, tl_width)
        hover = next((ep for ep in self._episodes if ep["start"] <= date_pos <= ep["end"]), None)

        if hover != self._hover_ep:
            self._hover_ep = hover
            if hover:
                self._show_tooltip(hover, event.globalPosition().toPoint())
            else:
                QToolTip.hideText()

    def mouseReleaseEvent(self, event):
        if event.button() == Qt.LeftButton:
            self._panning = False

    # ------------------------------------------------------------
    def _on_scrollbar_changed(self, value: int):
        if not (self._view_start and self._view_end and self._min_date and self._max_date):
            return

        span_view = max(1, self._days_between(self._view_start, self._view_end))
        total_span = self._days_between(self._min_date, self._max_date)

        value = max(0, min(value, max(0, total_span - span_view)))

        new_start = self._min_date + timedelta(days=value)
        new_end = new_start + timedelta(days=span_view)

        self._view_start = new_start
        self._view_end = new_end
        self._clamp_view()
        self.update()

    # ------------------------------------------------------------
    def _update_scrollbar(self):
        if not (self._scrollbar and self._view_start and self._view_end and self._min_date and self._max_date):
            return

        total_span = self._days_between(self._min_date, self._max_date)
        span_view = self._days_between(self._view_start, self._view_end)
        max_offset = max(0, total_span - span_view)

        self._scrollbar.blockSignals(True)
        self._scrollbar.setRange(0, max_offset)
        self._scrollbar.setPageStep(span_view)
        self._scrollbar.setSingleStep(max(1, span_view // 10))

        offset = self._days_between(self._min_date, self._view_start)
        self._scrollbar.setValue(max(0, min(max_offset, offset)))
        self._scrollbar.blockSignals(False)

    # ------------------------------------------------------------
    def _clamp_view(self):
        if not (self._min_date and self._max_date):
            return

        span = max(MIN_VIEW_DAYS, self._days_between(self._view_start, self._view_end))

        if self._view_start < self._min_date:
            self._view_start = self._min_date
            self._view_end = self._min_date + timedelta(days=span)

        if self._view_end > self._max_date:
            self._view_end = self._max_date
            self._view_start = self._max_date - timedelta(days=span)

    # ------------------------------------------------------------
    def wheelEvent(self, event):
        if not (self._view_start and self._view_end and self._min_date and self._max_date):
            return

        delta = event.angleDelta().y()
        if delta == 0:
            return

        cur_span = self._days_between(self._view_start, self._view_end)
        factor = (1 - 0.15) if delta > 0 else (1 + 0.15)
        new_span = int(cur_span * factor)
        new_span = max(MIN_VIEW_DAYS, min(new_span, self._days_between(self._min_date, self._max_date)))

        outer_margin = 8
        padding_x = 20
        tl_left = outer_margin + padding_x
        tl_width = max(10, self.width() - 2 * outer_margin - 2 * padding_x)

        mx = event.position().x()
        centre = self._x_to_date(mx, tl_left, tl_width)

        half = new_span // 2
        new_start = centre - timedelta(days=half)
        new_end = new_start + timedelta(days=new_span)

        self._view_start = new_start
        self._view_end = new_end

        self._clamp_view()
        self._update_scrollbar()
        self.update()

    # ------------------------------------------------------------
    def _show_tooltip(self, ep: Dict[str, Any], pos: QPoint):
        lines = []

        if ep["type"] == "inpatient":
            lines.append(f"Admission {ep.get('label', '')}".strip())
        else:
            lines.append("Community period")

        if ep.get("ward"):
            lines.append(f"Ward: {ep['ward']}")

        lines.append(f"Start: {ep['start']:%d %b %Y}")
        lines.append(f"End:   {ep['end']:%d %b %Y}")

        length_days = (ep["end"] - ep["start"]).days
        lines.append(f"Length: {length_days} days")

        if ep.get("note"):
            lines.append(ep["note"])

        # Wrap in HTML with explicit styling for Windows
        tooltip_html = "<div style='background-color: #fffbe6; color: #000000; padding: 4px;'>"
        tooltip_html += "<br>".join(lines)
        tooltip_html += "</div>"
        QToolTip.showText(pos, tooltip_html, self)

    # ------------------------------------------------------------
    def paintEvent(self, event):
        # Avoid QPainter warnings during early layout passes
        if not self._episodes or not (self._view_start and self._view_end):
            return super().paintEvent(event)

        if self.width() <= 5 or self.height() <= 5:
            return super().paintEvent(event)

        painter = QPainter()
        if not painter.begin(self):
            return super().paintEvent(event)

        painter.setRenderHint(QPainter.Antialiasing)


        try:
            outer_margin = 8
            box_left = outer_margin
            box_top = outer_margin
            box_bottom = min(box_top + MAX_BOX_HEIGHT, self.height() - BOTTOM_GAP)
            box_width = max(10, self.width() - 2 * outer_margin)
            box_height = max(10, box_bottom - box_top)


            # Soft backdrop shadow (light Sonoma style)
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor(0, 0, 0, 40))
            painter.drawRoundedRect(
                QRectF(box_left + 3, box_top + 3, box_width, box_height),
                22, 22
            )

            # Light frosted acrylic background (bright, subtle, non-darkening)
            painter.setPen(QPen(QColor(255, 255, 255, 160), 2))
            painter.setBrush(QColor(240, 243, 247, 180))   # ← LIGHT background
            painter.drawRoundedRect(
                QRectF(box_left, box_top, box_width, box_height),
                20, 20
            )


            padding_x = 20
            tl_left = box_left + padding_x
            tl_right = box_left + box_width - padding_x
            tl_width = max(10, tl_right - tl_left)

            bars_top = box_top + 20
            bars_height = 60
            baseline_y = bars_top + bars_height / 2

            tick_top = bars_top + bars_height + 10
            label_y = tick_top + 20
            global_label_y = box_bottom - 6

            # Axis
            painter.setPen(QPen(QColor("#888"), 2))
            painter.drawLine(tl_left, baseline_y, tl_right, baseline_y)

            # Episodes
            for ep in self._episodes:
                d1 = max(ep["start"], self._view_start)
                d2 = min(ep["end"], self._view_end)
                if d1 > d2:
                    continue

                px1 = self._date_to_x(d1, tl_left, tl_width)
                px2 = self._date_to_x(d2, tl_left, tl_width)
                pxw = max(3, px2 - px1)

                color = QColor("#d9534f") if ep["type"] == "inpatient" else QColor("#5cb85c")

                painter.setPen(Qt.NoPen)
                painter.setBrush(QBrush(color))
                painter.drawRoundedRect(QRectF(px1, bars_top, pxw, bars_height), 10, 10)

                # Admission label
                if ep.get("label") and ep["type"] == "inpatient" and pxw > 80:
                    painter.setPen(QColor(30, 30, 30, 255))
                    painter.setFont(self._axis_font)
                    painter.drawText(QRectF(px1, bars_top - 22, pxw, 20),
                                     Qt.AlignCenter, ep["label"])

            # Ticks
            view_days = self._days_between(self._view_start, self._view_end)

            if view_days > 4 * 365:
                mode = "year"
            elif view_days > 18 * 30:
                mode = "quarter"
            else:
                mode = "month"

            painter.setFont(self._axis_font)
            painter.setPen(QPen(QColor(40, 40, 40, 230), 1))

            ticks = self._generate_ticks(mode)

            for idx, t in enumerate(ticks):
                x = self._date_to_x(t, tl_left, tl_width)
                painter.drawLine(x, tick_top, x, tick_top + 10)

                if mode == "month" and len(ticks) > 10 and idx % 2 == 1:
                    continue

                if mode == "year":
                    text = t.strftime("%b %Y")
                elif mode == "quarter":
                    q = (t.month - 1) // 3 + 1
                    text = f"Q{q} {t.year}"
                else:
                    text = t.strftime("%b %Y")

                painter.save()
                painter.translate(x, label_y)
                painter.rotate(-45)
                painter.drawText(0, 0, text)
                painter.restore()

            # Big labels
            painter.setPen(QColor(30, 30, 30, 255))
            painter.setFont(self._axis_font)

            if self._min_date:
                painter.drawText(tl_left, global_label_y,
                                 self._min_date.strftime("%d %b %Y"))
            if self._max_date:
                painter.drawText(tl_right - 150, global_label_y,
                                 self._max_date.strftime("%d %b %Y"))

            # Hint
            hint = "Scroll to zoom • Drag to pan"
            hint_font = QFont(self._axis_font)
            hint_font.setPointSize(max(8, hint_font.pointSize() - 1))
            painter.setFont(hint_font)
            painter.setPen(QColor(40, 40, 40, 220))
            fm = painter.fontMetrics()
            hw = fm.horizontalAdvance(hint)
            hint_y = box_bottom - 24
            painter.drawText(tl_right - hw, hint_y, hint)

        finally:
            painter.end()

    # ------------------------------------------------------------
    def _generate_ticks(self, mode: str) -> List[date]:
        ticks = []
        if not (self._view_start and self._view_end):
            return ticks

        start = self._view_start
        end = self._view_end

        if mode == "year":
            y = start.year
            tick = date(y, 1, 1)
            if tick < start:
                y += 1
                tick = date(y, 1, 1)

            while tick <= end and len(ticks) < MAX_TICKS:
                ticks.append(tick)
                y += 1
                tick = date(y, 1, 1)

        elif mode == "quarter":
            y = start.year
            m = ((start.month - 1) // 3) * 3 + 1
            tick = date(y, m, 1)
            if tick < start:
                m += 3
                if m > 12:
                    m -= 12
                    y += 1
                tick = date(y, m, 1)

            while tick <= end and len(ticks) < MAX_TICKS:
                ticks.append(tick)
                nm = tick.month + 3
                ny = tick.year
                if nm > 12:
                    nm -= 12
                    ny += 1
                tick = date(ny, nm, 1)

        else:
            y = start.year
            m = start.month
            tick = date(y, m, 1)
            if tick < start:
                if m == 12:
                    y += 1
                    m = 1
                else:
                    m += 1
                tick = date(y, m, 1)

            while tick <= end and len(ticks) < MAX_TICKS:
                ticks.append(tick)
                if tick.month == 12:
                    y = tick.year + 1
                    m = 1
                else:
                    y = tick.year
                    m = tick.month + 1
                tick = date(y, m, 1)

        return ticks


    # ------------------------------------------------------------
    # OPTIONAL CLOSE BUTTON SUPPORT (no manager callback needed)
    # ------------------------------------------------------------
    def close_panel(self):
        """Close the panel safely with no external dependency."""
        try:
            self.close()
        except Exception as e:
            print("TimelinePanel close error:", e)
# ===================================================================
# PUBLIC WIDGET
# ===================================================================
class TimelinePanel(QWidget):
    episodeClicked = Signal(date)

    def __init__(self, parent=None):
        super().__init__(parent)

        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(4)

        self.canvas = _TimelineCanvas(self)
        canvas_height = MAX_BOX_HEIGHT + 40
        self.canvas.setFixedHeight(canvas_height)
        layout.addWidget(self.canvas)

        self.scrollbar = QScrollBar(Qt.Horizontal, self)
        self.scrollbar.setMinimumHeight(18)
        layout.addWidget(self.scrollbar)

        self.setFixedHeight(canvas_height + 30)
        self.canvas.set_scrollbar(self.scrollbar)

        self.canvas.episodeClicked.connect(self.episodeClicked.emit)

    def set_episodes(self, episodes: List[Dict[str, Any]]):
        self.canvas.set_episodes(episodes)
