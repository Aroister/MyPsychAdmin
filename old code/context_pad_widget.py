from __future__ import annotations

import math
from PySide6.QtCore import Qt, QPointF, Signal
from PySide6.QtGui import QColor, QPainter, QPen, QBrush
from PySide6.QtWidgets import QWidget


class ContextPadWidget(QWidget):
    """
    2D contextual selector:
    X = stability (chaotic → stable)
    Y = valence (adverse → supportive)
    """

    changed = Signal(dict)

    def __init__(self, parent=None):
        super().__init__(parent)
        self.setMinimumSize(220, 220)
        self.setMaximumSize(260, 260)

        # Normalised coordinates (-1 → +1)
        self.x = 0.0
        self.y = 0.0

        self._dragging = False

    # --------------------------------------------------
    # Core maths
    # --------------------------------------------------
    def _normalise(self, pos: QPointF):
        r = min(self.width(), self.height()) / 2 - 14
        cx = self.width() / 2
        cy = self.height() / 2

        dx = (pos.x() - cx) / r
        dy = (cy - pos.y()) / r  # invert Y

        dist = math.sqrt(dx * dx + dy * dy)
        if dist > 1:
            dx /= dist
            dy /= dist

        return dx, dy

    def _colour(self) -> QColor:
        """
        Smooth red → amber → green based on Y axis
        """
        if self.y < 0:
            t = min(abs(self.y), 1.0)
            return QColor.fromRgbF(1.0, 0.4 + 0.4 * (1 - t), 0.4)
        else:
            t = min(self.y, 1.0)
            return QColor.fromRgbF(0.4, 0.8, 0.4 + 0.4 * t)

    # --------------------------------------------------
    # Interpretation
    # --------------------------------------------------
    def interpret(self) -> dict:
        dist = math.sqrt(self.x * self.x + self.y * self.y)

        if self.y < -0.35:
            valence = "adverse"
            rag = "red"
        elif self.y > 0.35:
            valence = "supportive"
            rag = "green"
        else:
            valence = "mixed"
            rag = "amber"

        if self.x < -0.35:
            stability = "chaotic"
        elif self.x > 0.35:
            stability = "stable"
        else:
            stability = "inconsistent"

        return {
            "x": round(self.x, 3),
            "y": round(self.y, 3),
            "distance": round(dist, 3),
            "valence": valence,
            "stability": stability,
            "rag": rag,
        }

    # --------------------------------------------------
    # State
    # --------------------------------------------------
    def get_state(self) -> dict:
        return self.interpret()

    def set_state(self, state: dict):
        self.x = float(state.get("x", 0))
        self.y = float(state.get("y", 0))
        self.update()

    # --------------------------------------------------
    # Events
    # --------------------------------------------------
    def mousePressEvent(self, e):
        if e.button() == Qt.LeftButton:
            self._dragging = True
            self.x, self.y = self._normalise(e.position())
            self.changed.emit(self.get_state())
            self.update()

    def mouseMoveEvent(self, e):
        if self._dragging:
            self.x, self.y = self._normalise(e.position())
            self.changed.emit(self.get_state())
            self.update()

    def mouseReleaseEvent(self, e):
        self._dragging = False

    # --------------------------------------------------
    # Paint
    # --------------------------------------------------
    def paintEvent(self, e):
        p = QPainter(self)
        p.setRenderHint(QPainter.Antialiasing)

        cx = self.width() / 2
        cy = self.height() / 2
        r = min(self.width(), self.height()) / 2 - 12

        # Circle
        p.setPen(QPen(QColor(0, 0, 0, 80), 1))
        p.setBrush(QBrush(QColor(255, 255, 255, 40)))
        p.drawEllipse(QPointF(cx, cy), r, r)

        # Crosshair
        p.setPen(QPen(QColor(0, 0, 0, 60), 1, Qt.DashLine))
        p.drawLine(cx - r, cy, cx + r, cy)
        p.drawLine(cx, cy - r, cx, cy + r)

        # Dot
        dot_x = cx + self.x * r
        dot_y = cy - self.y * r

        p.setPen(Qt.NoPen)
        p.setBrush(self._colour())
        p.drawEllipse(QPointF(dot_x, dot_y), 8, 8)
