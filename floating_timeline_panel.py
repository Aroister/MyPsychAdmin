# floating_timeline_panel.py — Final Clean Version (Avie + ChatGPT)
# -----------------------------------------------------------------
from __future__ import annotations

from PySide6.QtWidgets import (
    QWidget,
    QFrame,
    QLabel,
    QPushButton,
    QSizeGrip,
    QVBoxLayout,
    QHBoxLayout,
    QSizePolicy,
    QScrollArea,
    QTextEdit
)
from PySide6.QtGui import QPainter, QColor, QPen, QFont, QBrush
from PySide6.QtCore import Qt, QRect, QRectF, QPoint, Signal

from timeline_panel import TimelinePanel


# ============================================================
# ADMISSION KEYWORDS - for identifying clerking notes
# ============================================================
ADMISSION_KEYWORDS = [
    # Ward admission phrases
    "admission to ward", "admitted to ward", "admitted to the ward",
    "brought to ward", "brought to the ward", "brought into ward",
    "brought onto ward", "brought onto the ward",
    "arrived on ward", "arrived on the ward", "arrived to ward",
    "transferred to ward", "transferred to the ward",
    "escorted to ward", "escorted to the ward",
    # General admission phrases
    "on admission", "admission clerking", "clerking",
    "duty doctor admission", "admission note",
    "accepted to ward", "accepted onto ward",
    "admitted under", "accepted under",
    # Section/detention phrases often in admission notes
    "detained under", "sectioned", "section 2", "section 3",
    "136 suite", "sec 136", "section 136",
    # Nursing admission entries
    "nursing admission", "admission assessment",
    "initial assessment", "ward admission",
    "new admission", "patient admitted",
]


# ============================================================
# VERTICAL TIMELINE CANVAS (matching horizontal style exactly)
# ============================================================
from datetime import date, timedelta
from PySide6.QtWidgets import QToolTip

class VerticalTimelineCanvas(QWidget):
    """Vertical timeline canvas - identical to horizontal but rotated 90 degrees."""

    episodeClicked = Signal(date)

    MIN_VIEW_DAYS = 60
    MAX_TICKS = 100

    def __init__(self, parent=None):
        super().__init__(parent)

        self._episodes = []
        self._min_date = None
        self._max_date = None
        self._view_start = None
        self._view_end = None

        self._panning = False
        self._last_mouse_y = 0.0
        self._hover_ep = None

        # Fonts
        base = self.font()
        axis_font = QFont(base)
        axis_font.setPointSize(max((axis_font.pointSize() + 1), 11))
        axis_font.setBold(True)
        self._axis_font = axis_font

        tt_font = QFont(base)
        tt_font.setPointSize(max((tt_font.pointSize() + 1), 11))
        tt_font.setBold(True)
        QToolTip.setFont(tt_font)

        self.setMinimumWidth(200)
        self.setMouseTracking(True)

    def set_episodes(self, episodes):
        self._episodes = episodes or []

        if not episodes:
            self._min_date = self._max_date = self._view_start = self._view_end = None
            self.update()
            return

        self._min_date = min(ep["start"] for ep in episodes)
        self._max_date = max(ep["end"] for ep in episodes)
        self._view_start = self._min_date
        self._view_end = self._max_date
        self._hover_ep = None
        self.update()

    def _days_between(self, d1, d2):
        return (d2 - d1).days

    def _date_to_y(self, d, top, height):
        if not (self._view_start and self._view_end):
            return top
        total = max(1, self._days_between(self._view_start, self._view_end))
        offset = self._days_between(self._view_start, d)
        return top + (offset / total) * height

    def _y_to_date(self, y, top, height):
        if not (self._view_start and self._view_end):
            return date.today()
        rel = max(0.0, min(1.0, (y - top) / max(1.0, float(height))))
        total = max(1, self._days_between(self._view_start, self._view_end))
        return self._view_start + timedelta(days=int(rel * total))

    def mousePressEvent(self, event):
        if event.button() != Qt.LeftButton:
            return

        self._panning = True
        self._last_mouse_y = event.position().y()

        if not (self._view_start and self._view_end and self._episodes):
            return

        margin = 8
        padding = 20
        tl_top = margin + padding
        tl_height = max(10, self.height() - 2 * margin - 2 * padding - 40)

        click_date = self._y_to_date(event.position().y(), tl_top, tl_height)

        for ep in self._episodes:
            if ep["start"] <= click_date <= ep["end"]:
                self.episodeClicked.emit(ep["start"])
                break

    def mouseMoveEvent(self, event):
        if not (self._view_start and self._view_end and self._min_date and self._max_date):
            return

        margin = 8
        padding = 20
        tl_top = margin + padding
        tl_height = max(10, self.height() - 2 * margin - 2 * padding - 40)

        # Pan
        if self._panning:
            dy = event.position().y() - self._last_mouse_y
            self._last_mouse_y = event.position().y()

            total_days = max(1, self._days_between(self._view_start, self._view_end))
            shift_days = int(-dy / max(1.0, tl_height) * total_days)

            self._view_start += timedelta(days=shift_days)
            self._view_end += timedelta(days=shift_days)
            self._clamp_view()
            self.update()
            return

        # Hover
        my = event.position().y()
        date_pos = self._y_to_date(my, tl_top, tl_height)
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

    def wheelEvent(self, event):
        if not (self._view_start and self._view_end and self._min_date and self._max_date):
            return

        delta = event.angleDelta().y()
        if delta == 0:
            return

        cur_span = self._days_between(self._view_start, self._view_end)
        factor = (1 - 0.15) if delta > 0 else (1 + 0.15)
        new_span = int(cur_span * factor)
        new_span = max(self.MIN_VIEW_DAYS, min(new_span, self._days_between(self._min_date, self._max_date)))

        margin = 8
        padding = 20
        tl_top = margin + padding
        tl_height = max(10, self.height() - 2 * margin - 2 * padding - 40)

        my = event.position().y()
        centre = self._y_to_date(my, tl_top, tl_height)

        half = new_span // 2
        self._view_start = centre - timedelta(days=half)
        self._view_end = self._view_start + timedelta(days=new_span)

        self._clamp_view()
        self.update()

    def _clamp_view(self):
        if not (self._min_date and self._max_date):
            return

        span = max(self.MIN_VIEW_DAYS, self._days_between(self._view_start, self._view_end))

        if self._view_start < self._min_date:
            self._view_start = self._min_date
            self._view_end = self._min_date + timedelta(days=span)

        if self._view_end > self._max_date:
            self._view_end = self._max_date
            self._view_start = self._max_date - timedelta(days=span)

    def _show_tooltip(self, ep, pos):
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

    def paintEvent(self, event):
        if not self._episodes or not (self._view_start and self._view_end):
            return super().paintEvent(event)

        if self.width() <= 5 or self.height() <= 5:
            return super().paintEvent(event)

        painter = QPainter()
        if not painter.begin(self):
            return super().paintEvent(event)

        painter.setRenderHint(QPainter.Antialiasing)

        try:
            margin = 8
            box_left = margin
            box_top = margin
            box_width = max(10, self.width() - 2 * margin)
            box_height = max(10, self.height() - 2 * margin)

            # Background
            painter.setPen(Qt.NoPen)
            painter.setBrush(QColor(0, 0, 0, 40))
            painter.drawRoundedRect(QRectF(box_left + 3, box_top + 3, box_width, box_height), 20, 20)

            painter.setPen(QPen(QColor(255, 255, 255, 160), 2))
            painter.setBrush(QColor(240, 243, 247, 180))
            painter.drawRoundedRect(QRectF(box_left, box_top, box_width, box_height), 20, 20)

            # Timeline area
            padding = 20
            label_width = 70  # Space for date labels on left
            bars_width = 50   # Width of episode bars

            tl_top = box_top + padding
            tl_bottom = box_top + box_height - padding - 40
            tl_height = max(10, tl_bottom - tl_top)

            bars_left = box_left + label_width
            baseline_x = bars_left + bars_width / 2

            # Vertical axis line
            painter.setPen(QPen(QColor("#888"), 2))
            painter.drawLine(int(baseline_x), int(tl_top), int(baseline_x), int(tl_bottom))

            # Episodes as vertical bars
            for ep in self._episodes:
                d1 = max(ep["start"], self._view_start)
                d2 = min(ep["end"], self._view_end)
                if d1 > d2:
                    continue

                py1 = self._date_to_y(d1, tl_top, tl_height)
                py2 = self._date_to_y(d2, tl_top, tl_height)
                pyh = max(3, py2 - py1)

                color = QColor("#d9534f") if ep["type"] == "inpatient" else QColor("#5cb85c")

                painter.setPen(Qt.NoPen)
                painter.setBrush(QBrush(color))
                painter.drawRoundedRect(QRectF(bars_left, py1, bars_width, pyh), 8, 8)

            # Date ticks on left
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
                y = self._date_to_y(t, tl_top, tl_height)
                painter.drawLine(int(bars_left - 5), int(y), int(bars_left), int(y))

                if mode == "month" and len(ticks) > 10 and idx % 2 == 1:
                    continue

                if mode == "year":
                    text = t.strftime("%b %Y")
                elif mode == "quarter":
                    q = (t.month - 1) // 3 + 1
                    text = f"Q{q} {t.year}"
                else:
                    text = t.strftime("%b %Y")

                painter.drawText(QRectF(box_left + 4, y - 8, label_width - 10, 16),
                                 Qt.AlignRight | Qt.AlignVCenter, text)

            # Start/end date labels
            painter.setPen(QColor(30, 30, 30, 255))
            painter.setFont(self._axis_font)

            if self._min_date:
                painter.drawText(QRectF(box_left + 4, tl_top - 4, label_width + bars_width, 16),
                                 Qt.AlignLeft, self._min_date.strftime("%d %b %Y"))
            if self._max_date:
                painter.drawText(QRectF(box_left + 4, tl_bottom + 8, label_width + bars_width, 16),
                                 Qt.AlignLeft, self._max_date.strftime("%d %b %Y"))

        finally:
            painter.end()

    def _generate_ticks(self, mode):
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
            while tick <= end and len(ticks) < self.MAX_TICKS:
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
            while tick <= end and len(ticks) < self.MAX_TICKS:
                ticks.append(tick)
                nm = tick.month + 3
                ny = tick.year
                if nm > 12:
                    nm -= 12
                    ny += 1
                tick = date(ny, nm, 1)

        else:  # month
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
            while tick <= end and len(ticks) < self.MAX_TICKS:
                ticks.append(tick)
                if tick.month == 12:
                    y = tick.year + 1
                    m = 1
                else:
                    y = tick.year
                    m = tick.month + 1
                tick = date(y, m, 1)

        return ticks


# ============================================================
# VERTICAL TIMELINE WIDGET WRAPPER (with scroll)
# ============================================================
class VerticalTimelineWidget(QWidget):
    """Wrapper for vertical timeline canvas with scrollbar."""

    episodeClicked = Signal(object)

    def __init__(self, parent=None):
        super().__init__(parent)
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)

        # Scroll area for vertical scrolling
        self.scroll = QScrollArea()
        self.scroll.setWidgetResizable(True)
        self.scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        self.scroll.setHorizontalScrollBarPolicy(Qt.ScrollBarAlwaysOff)
        self.scroll.setVerticalScrollBarPolicy(Qt.ScrollBarAsNeeded)
        self.scroll.setStyleSheet("""
            QScrollArea {
                background: transparent;
                border: none;
            }
            QScrollBar:vertical {
                background: #f0f0f0;
                width: 10px;
                border-radius: 5px;
            }
            QScrollBar::handle:vertical {
                background: #c0c0c0;
                border-radius: 5px;
                min-height: 30px;
            }
            QScrollBar::handle:vertical:hover {
                background: #a0a0a0;
            }
        """)

        self.canvas = VerticalTimelineCanvas(self)
        self.canvas.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        self.canvas.setMinimumHeight(400)  # Minimum height for scrolling
        self.canvas.episodeClicked.connect(self.episodeClicked.emit)

        self.scroll.setWidget(self.canvas)
        layout.addWidget(self.scroll)

    def set_episodes(self, episodes):
        # Adjust canvas height based on number of episodes
        if episodes:
            # More episodes = taller canvas for better scrolling
            height = max(400, len(episodes) * 80)
            self.canvas.setMinimumHeight(height)
        self.canvas.set_episodes(episodes)


# ============================================================
# ADMISSION CLERKING PANEL - shows first entry for each admission
# ============================================================
class AdmissionClerkingPanel(QWidget):
    """Panel showing first clerking note for each admission."""

    # Signal emitted with list of admissions that have clerking notes
    admissionsWithClerkings = Signal(list)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._episodes = []
        self._notes = []
        self._clerking_widgets = []
        self._matched_admissions = []  # Admissions that have clerking notes

        self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
        self._build_ui()

    def _build_ui(self):
        layout = QVBoxLayout(self)
        layout.setContentsMargins(0, 0, 0, 0)
        layout.setSpacing(0)

        # Title
        title = QLabel("Admission Clerking Notes")
        title.setStyleSheet("""
            font-size: 16px;
            font-weight: bold;
            color: #333;
            padding: 8px 12px;
            background: transparent;
        """)
        layout.addWidget(title)

        # Scroll area for clerking entries
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setFrameShape(QScrollArea.Shape.NoFrame)
        scroll.setStyleSheet("""
            QScrollArea {
                background: transparent;
                border: none;
            }
            QScrollBar:vertical {
                background: #f0f0f0;
                width: 10px;
                border-radius: 5px;
            }
            QScrollBar::handle:vertical {
                background: #c0c0c0;
                border-radius: 5px;
                min-height: 30px;
            }
            QScrollBar::handle:vertical:hover {
                background: #a0a0a0;
            }
        """)

        self.content_widget = QWidget()
        self.content_widget.setStyleSheet("background: transparent; border: none;")
        self.content_layout = QVBoxLayout(self.content_widget)
        self.content_layout.setContentsMargins(8, 8, 8, 8)
        self.content_layout.setSpacing(4)
        self.content_layout.addStretch()

        scroll.setWidget(self.content_widget)
        layout.addWidget(scroll, 1)

    def set_data(self, episodes: list, notes: list):
        """Set episodes and notes, then extract clerking notes."""
        self._episodes = episodes or []
        self._notes = notes or []
        self._extract_and_display()

    def _extract_and_display(self):
        """Extract first clerking note for each admission and display."""
        # Clear existing widgets
        for widget in self._clerking_widgets:
            widget.deleteLater()
        self._clerking_widgets.clear()
        self._matched_admissions.clear()

        # Remove stretch
        while self.content_layout.count():
            item = self.content_layout.takeAt(0)
            if item.widget():
                item.widget().deleteLater()

        # Get only inpatient episodes (admissions)
        admissions = [ep for ep in self._episodes if ep.get("type") == "inpatient"]

        if not admissions:
            no_data = QLabel("No admissions found")
            no_data.setStyleSheet("color: #888; font-style: italic; padding: 20px;")
            no_data.setAlignment(Qt.AlignCenter)
            self.content_layout.addWidget(no_data)
            self.content_layout.addStretch()
            self._clerking_widgets.append(no_data)
            self.admissionsWithClerkings.emit([])
            return

        clerking_notes = []
        seen_keys = set()

        # For each admission, find the first clerking note in 2-week window
        for adm in admissions:
            adm_start = adm.get("start")
            if not adm_start:
                continue

            # 2-week window from admission date
            window_end = adm_start + timedelta(days=14)

            # Collect notes within window
            admission_window_notes = []
            for note in self._notes:
                note_date = note.get("date")
                if not note_date:
                    continue

                if hasattr(note_date, "date"):
                    note_date_obj = note_date.date()
                else:
                    note_date_obj = note_date

                if adm_start <= note_date_obj <= window_end:
                    admission_window_notes.append((note_date_obj, note))

            # Sort by date to find the FIRST matching entry
            admission_window_notes.sort(key=lambda x: x[0])

            found_admission_note = None
            for note_date_obj, note in admission_window_notes:
                text = (note.get("text", "") or note.get("content", "")).lower()
                if any(kw in text for kw in ADMISSION_KEYWORDS):
                    key = (note_date_obj, text[:100])
                    if key not in seen_keys:
                        seen_keys.add(key)
                        found_admission_note = {
                            "date": note.get("date"),
                            "text": note.get("text", "") or note.get("content", ""),
                            "admission_label": adm.get("label", "Admission"),
                            "ward": adm.get("ward", ""),
                            "admission_start": adm_start  # Store admission date for matching
                        }
                    break

            if found_admission_note:
                clerking_notes.append(found_admission_note)
                self._matched_admissions.append(adm)  # Track matched admission

        if not clerking_notes:
            no_data = QLabel("No clerking notes found")
            no_data.setStyleSheet("color: #888; font-style: italic; padding: 20px;")
            no_data.setAlignment(Qt.AlignCenter)
            self.content_layout.addWidget(no_data)
            self.content_layout.addStretch()
            self._clerking_widgets.append(no_data)
            self.admissionsWithClerkings.emit([])
            return

        # Create collapsible entries for each clerking note
        for clerking in clerking_notes:
            widget = self._create_clerking_entry(clerking)
            self.content_layout.addWidget(widget)
            self._clerking_widgets.append(widget)

        self.content_layout.addStretch()

        # Emit signal with matched admissions
        self.admissionsWithClerkings.emit(self._matched_admissions)

    def get_matched_admissions(self) -> list:
        """Return list of admissions that have clerking notes."""
        return self._matched_admissions

    def expand_clerking_for_date(self, admission_date):
        """Toggle the clerking entry for the given admission date."""
        for widget in self._clerking_widgets:
            adm_start = widget.property("admission_start")
            content = widget.property("content_widget")
            toggle_btn = widget.property("toggle_btn")

            if adm_start == admission_date:
                # Toggle this one
                if content:
                    is_visible = content.isVisible()
                    content.setVisible(not is_visible)
                    if toggle_btn:
                        toggle_btn.setText("▶" if is_visible else "▼")
            else:
                # Collapse others
                if content and content.isVisible():
                    content.setVisible(False)
                    if toggle_btn:
                        toggle_btn.setText("▶")

    def _create_clerking_entry(self, clerking: dict) -> QWidget:
        """Create a collapsible entry widget for a clerking note."""
        dt = clerking.get("date")
        text = clerking.get("text", "").strip()
        adm_label = clerking.get("admission_label", "")
        ward = clerking.get("ward", "")

        # Format date
        if dt:
            if hasattr(dt, "strftime"):
                date_str = dt.strftime("%d %b %Y")
            else:
                date_str = str(dt)
        else:
            date_str = "No date"

        # Container widget (no border, simple)
        frame = QWidget()
        frame.setStyleSheet("background: transparent; border: none;")
        frame_layout = QVBoxLayout(frame)
        frame_layout.setContentsMargins(4, 2, 4, 2)
        frame_layout.setSpacing(2)

        # Header row
        header = QWidget()
        header.setStyleSheet("background: transparent; border: none;")
        header_layout = QHBoxLayout(header)
        header_layout.setContentsMargins(0, 0, 0, 0)
        header_layout.setSpacing(4)

        # Toggle button
        toggle_btn = QPushButton("▶")
        toggle_btn.setFixedSize(18, 18)
        toggle_btn.setCursor(Qt.PointingHandCursor)
        toggle_btn.setStyleSheet("""
            QPushButton {
                background: transparent;
                border: none;
                font-size: 11px;
                color: #d9534f;
            }
        """)
        header_layout.addWidget(toggle_btn)

        # Simple label: Admission 1 - Ward Name (date)
        label_text = adm_label
        if ward:
            label_text += f" - {ward}"
        label_text += f" ({date_str})"

        title_label = QLabel(label_text)
        title_label.setCursor(Qt.PointingHandCursor)
        title_label.setStyleSheet("""
            font-size: 15px;
            font-weight: 600;
            color: #d9534f;
            background: transparent;
            border: none;
        """)
        header_layout.addWidget(title_label, 1)

        frame_layout.addWidget(header)

        # Content (collapsed by default)
        content = QTextEdit()
        content.setPlainText(text)
        content.setReadOnly(True)
        content.setVisible(False)
        content.setMinimumHeight(100)
        content.setMaximumHeight(250)
        content.setStyleSheet("""
            QTextEdit {
                background: #fafafa;
                border: none;
                border-left: 3px solid #d9534f;
                font-size: 14px;
                color: #333;
                padding: 8px;
                margin-left: 18px;
            }
        """)
        frame_layout.addWidget(content)

        # Toggle function
        def toggle_content():
            is_visible = content.isVisible()
            content.setVisible(not is_visible)
            toggle_btn.setText("▼" if not is_visible else "▶")

        toggle_btn.clicked.connect(toggle_content)
        title_label.mousePressEvent = lambda e: toggle_content()

        # Store admission_start for matching with timeline clicks
        admission_start = clerking.get("admission_start")
        frame.setProperty("admission_start", admission_start)
        frame.setProperty("toggle_func", toggle_content)
        frame.setProperty("content_widget", content)
        frame.setProperty("toggle_btn", toggle_btn)

        return frame


# ============================================================
# LIGHT ACRYLIC BACKDROP FRAME
# ============================================================
class BackdropFrame(QFrame):
    def paintEvent(self, event):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)

        # Light frosted acrylic-style background
        # Adjust alpha for strength: 40 (very light) to 120 (darkest acceptable)
        bg = QColor(210, 210, 210, 55)

        p.setBrush(bg)
        p.setPen(QPen(QColor(150, 150, 150, 120), 2))

        rect = self.rect().adjusted(4, 4, -4, -4)
        p.drawRoundedRect(rect, 20, 20)


# ============================================================
# FLOATING TIMELINE PANEL
# ============================================================
class FloatingTimelinePanel(QFrame):
    panel_closed = Signal(object)
    episodeClicked = Signal(object)

    DEFAULT_WIDTH = 1100
    DEFAULT_HEIGHT = 380
    TITLE_BAR_HEIGHT = 36

    def __init__(self, parent=None, manager_ref=None, embedded=False):
        super().__init__(parent)

        self.manager_ref = manager_ref
        self.embedded = embedded

        # Dragging state
        self._drag = False
        self._drag_offset = QPoint()

        if embedded:
            # EMBEDDED MODE - vertical timeline on left, clerking panel on right
            self.setStyleSheet("QWidget { background: white; }")
            self.setMinimumSize(1, 1)  # Allow shrinking
            self.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)

            layout = QVBoxLayout(self)
            layout.setContentsMargins(12, 12, 12, 12)
            layout.setSpacing(8)

            # Title
            title = QLabel("Admissions / Community Timeline")
            title.setStyleSheet("font-size: 16px; font-weight: bold; color: #333;")
            layout.addWidget(title)

            # Horizontal container for timeline and clerking panel
            h_container = QWidget()
            h_layout = QHBoxLayout(h_container)
            h_layout.setContentsMargins(0, 0, 0, 0)
            h_layout.setSpacing(12)

            # Vertical timeline widget (left side - narrower)
            self.timeline = VerticalTimelineWidget(self)
            self.timeline.setSizePolicy(QSizePolicy.Preferred, QSizePolicy.Expanding)
            self.timeline.setMinimumWidth(200)
            self.timeline.setMaximumWidth(280)
            h_layout.addWidget(self.timeline)

            # Admission clerking panel (right side - wider)
            self.clerking_panel = AdmissionClerkingPanel(self)
            self.clerking_panel.setSizePolicy(QSizePolicy.Expanding, QSizePolicy.Expanding)
            self.clerking_panel.setStyleSheet("""
                QWidget {
                    background: transparent;
                    border: none;
                }
            """)
            # Connect signal to filter timeline when clerking notes are found
            self.clerking_panel.admissionsWithClerkings.connect(self._on_clerkings_found)
            h_layout.addWidget(self.clerking_panel, 1)

            layout.addWidget(h_container, 1)

            self.timeline.episodeClicked.connect(self.episodeClicked.emit)
            self.timeline.episodeClicked.connect(self._on_timeline_episode_clicked)

            # Store all episodes for reference
            self._all_episodes = []

            # No backdrop, close button, or size grip needed
            self.backdrop = None
            self.close_btn = None
            self.size_grip = None

        else:
            # FLOATING MODE - original behavior
            self.setWindowFlags(
                Qt.FramelessWindowHint |
                Qt.SubWindow |
                Qt.WindowStaysOnTopHint
            )
            self.setAttribute(Qt.WA_TranslucentBackground, True)
            self.setStyleSheet("QWidget { background: transparent; }")
            self.setMinimumSize(480, 240)

            layout = QVBoxLayout(self)
            layout.setContentsMargins(0, 0, 0, 0)
            layout.setSpacing(0)

            # BACKDROP FRAME (frosted)
            self.backdrop = BackdropFrame(self)
            self.backdrop.setCursor(Qt.CursorShape.OpenHandCursor)
            layout.addWidget(self.backdrop)

            # Title + Close button
            self.title = QLabel("Admissions / Community Timeline", self.backdrop)
            self.title.setGeometry(12, 6, 500, 24)
            self.title.setStyleSheet("font-size: 14px; font-weight: bold; color: #333;")

            self.close_btn = QPushButton("✕", self.backdrop)
            self.close_btn.setGeometry(self.DEFAULT_WIDTH - 40, 4, 30, 28)
            self.close_btn.setStyleSheet("""
                QPushButton {
                    background: white;
                    border-radius: 6px;
                    font-size: 14px;
                    font-weight: bold;
                }
                QPushButton:hover { background: #eee; }
            """)
            self.close_btn.clicked.connect(self._close_panel)

            # Timeline panel
            self.timeline = TimelinePanel(self.backdrop)
            self.timeline.setGeometry(
                10,
                self.TITLE_BAR_HEIGHT + 4,
                self.DEFAULT_WIDTH - 20,
                self.DEFAULT_HEIGHT - self.TITLE_BAR_HEIGHT - 20
            )

            self.timeline.episodeClicked.connect(self.episodeClicked.emit)

            # Resize grip
            self.size_grip = QSizeGrip(self.backdrop)

            # Hand cursor for dragging
            self.setCursor(Qt.CursorShape.OpenHandCursor)

            self.resize(self.DEFAULT_WIDTH, self.DEFAULT_HEIGHT)

    # ------------------------------------------------------------
    def set_episodes(self, episodes, notes=None):
        # Store all episodes for reference in embedded mode
        if self.embedded:
            self._all_episodes = episodes or []

        self.timeline.set_episodes(episodes)
        # Pass data to clerking panel in embedded mode
        if self.embedded and hasattr(self, 'clerking_panel') and notes is not None:
            self.clerking_panel.set_data(episodes, notes)

    def _on_clerkings_found(self, matched_admissions):
        """Filter timeline to only show admissions with clerking notes."""
        if not self.embedded or not matched_admissions:
            return

        # Get the start dates of matched admissions
        matched_starts = {adm.get("start") for adm in matched_admissions}

        # Filter episodes: keep community periods + only matched inpatient admissions
        filtered_episodes = []
        for ep in self._all_episodes:
            if ep.get("type") == "inpatient":
                # Only include if it has a clerking note
                if ep.get("start") in matched_starts:
                    filtered_episodes.append(ep)
            else:
                # Keep community periods
                filtered_episodes.append(ep)

        # Update timeline with filtered episodes
        self.timeline.set_episodes(filtered_episodes)

    def _on_timeline_episode_clicked(self, clicked_date):
        """When timeline episode is clicked, expand corresponding clerking note."""
        if not self.embedded or not hasattr(self, 'clerking_panel'):
            return

        # Find the episode that was clicked
        for ep in self._all_episodes:
            if ep.get("type") == "inpatient" and ep.get("start") == clicked_date:
                # Expand the clerking for this admission
                self.clerking_panel.expand_clerking_for_date(clicked_date)
                break

    # ------------------------------------------------------------
    def resizeEvent(self, event):
        # Skip for embedded mode - layout handles resizing
        if self.embedded:
            return super().resizeEvent(event)

        w = self.width()
        h = self.height()

        # Resize backdrop to fill the widget
        self.backdrop.setGeometry(0, 0, w, h)

        # Title
        self.close_btn.setGeometry(w - 40, 4, 30, 28)

        # Timeline content
        self.timeline.setGeometry(
            10,
            self.TITLE_BAR_HEIGHT + 4,
            w - 20,
            h - self.TITLE_BAR_HEIGHT - 20
        )

        # Resize grip
        self.size_grip.setGeometry(w - 22, h - 22, 16, 16)

    # ------------------------------------------------------------
    # DRAGGING WINDOW - drag from anywhere (floating mode only)
    # ------------------------------------------------------------
    def mousePressEvent(self, event):
        if self.embedded:
            return super().mousePressEvent(event)
        if event.button() == Qt.MouseButton.LeftButton:
            self._drag = True
            self._drag_offset = event.globalPosition().toPoint() - self.frameGeometry().topLeft()
            self.setCursor(Qt.CursorShape.ClosedHandCursor)

    def mouseMoveEvent(self, event):
        if self.embedded:
            return super().mouseMoveEvent(event)
        if self._drag:
            newpos = event.globalPosition().toPoint() - self._drag_offset
            self.move(newpos)

    def mouseReleaseEvent(self, event):
        if self.embedded:
            return super().mouseReleaseEvent(event)
        self._drag = False
        self.setCursor(Qt.CursorShape.OpenHandCursor)

    # ------------------------------------------------------------
    def _close_panel(self):
        try:
            self.close()
        except Exception as e:
            print("FloatingTimelinePanel close error:", e)
