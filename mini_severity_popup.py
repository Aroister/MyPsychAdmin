from __future__ import annotations

from PySide6.QtCore import Qt, Signal, QPropertyAnimation
from PySide6.QtWidgets import (
    QWidget, QLabel, QPushButton, QVBoxLayout, QHBoxLayout,
    QTextEdit, QSlider, QFrame
)
from spell_check_textedit import enable_spell_check_on_textedit


# ============================================================
# NO-WHEEL SLIDER (prevents scroll from changing value)
# ============================================================
class NoWheelSlider(QSlider):
    def wheelEvent(self, event):
        event.ignore()


# ============================================================
# CLICKABLE LABEL
# ============================================================
class ClickableLabel(QLabel):
    clicked = Signal()

    def mousePressEvent(self, event):
        if event.button() == Qt.LeftButton:
            self.clicked.emit()
        super().mousePressEvent(event)


# ============================================================
# MINI SEVERITY POPUP
# ============================================================
class MiniSeverityPopup(QWidget):
    """
    Severity scale (single source of truth):

        0 = Normal
        1 = Mild
        2 = Moderate
        3 = Severe
    """

    saved = Signal(str, int, str)   # label, severity, details

    def __init__(self, label: str, severity: int, details: str, parent=None):
        super().__init__(parent)

        self.label = label
        self.current_severity = severity if severity in (0, 1, 2, 3) else 0

        self.setWindowFlags(Qt.FramelessWindowHint | Qt.Tool)
        self.setMinimumWidth(380)

        self.setStyleSheet("""
            QWidget {
                background: rgba(255,255,255,0.92);
                border-radius: 14px;
                border: 1px solid rgba(0,0,0,0.25);
            }
            QLabel {
                color:#003c32;
                background: transparent;
                border: none;
            }
            QLabel.sevLabel {
                font-weight:600;
            }
        """)

        outer = QVBoxLayout(self)
        outer.setContentsMargins(16, 16, 16, 16)
        outer.setSpacing(12)

        # ─────────────────────────────────────────────
        # TITLE ROW
        # ─────────────────────────────────────────────
        trow = QHBoxLayout()

        title_lbl = QLabel(label)
        title_lbl.setStyleSheet(
            "font-size:21px; font-weight:700; color:#003c32;"
        )
        trow.addWidget(title_lbl)
        trow.addStretch()

        close_btn = QPushButton("×")
        close_btn.setFixedSize(28, 28)
        close_btn.clicked.connect(self.close)
        close_btn.setStyleSheet("""
            QPushButton {
                background: rgba(0,0,0,0.07);
                border-radius: 6px;
                font-size: 21px;
            }
        """)
        trow.addWidget(close_btn)

        outer.addLayout(trow)

        # ─────────────────────────────────────────────
        # SEVERITY LABELS (CLICKABLE)
        # ─────────────────────────────────────────────
        lab_row = QHBoxLayout()

        self.lbl_normal = ClickableLabel("Normal")
        self.lbl_mild = ClickableLabel("Mild")
        self.lbl_moderate = ClickableLabel("Moderate")
        self.lbl_severe = ClickableLabel("Severe")

        for lbl in (
            self.lbl_normal,
            self.lbl_mild,
            self.lbl_moderate,
            self.lbl_severe,
        ):
            lbl.setObjectName("sevLabel")
            lbl.setProperty("class", "sevLabel")

        lab_row.addWidget(self.lbl_normal)
        lab_row.addStretch()
        lab_row.addWidget(self.lbl_mild)
        lab_row.addStretch()
        lab_row.addWidget(self.lbl_moderate)
        lab_row.addStretch()
        lab_row.addWidget(self.lbl_severe)

        outer.addLayout(lab_row)

        # ─────────────────────────────────────────────
        # SEVERITY SLIDER
        # ─────────────────────────────────────────────
        self.slider = NoWheelSlider(Qt.Horizontal)
        self.slider.setMinimum(0)
        self.slider.setMaximum(3)
        self.slider.setSingleStep(1)
        self.slider.setPageStep(1)
        self.slider.setValue(self.current_severity)
        self.slider.valueChanged.connect(self._on_slider_changed)
        outer.addWidget(self.slider)

        # ─────────────────────────────────────────────
        # CONNECT LABELS → SLIDER
        # ─────────────────────────────────────────────
        self.lbl_normal.clicked.connect(lambda: self.slider.setValue(0))
        self.lbl_mild.clicked.connect(lambda: self.slider.setValue(1))
        self.lbl_moderate.clicked.connect(lambda: self.slider.setValue(2))
        self.lbl_severe.clicked.connect(lambda: self.slider.setValue(3))

        # ─────────────────────────────────────────────
        # DETAILS
        # ─────────────────────────────────────────────
        self.details_box = QTextEdit()
        self.details_box.setPlaceholderText("Add optional details…")
        self.details_box.setText(details or "")
        self._details_height = 100
        self.details_box.setMinimumHeight(self._details_height)
        self.details_box.setMaximumHeight(self._details_height)
        enable_spell_check_on_textedit(self.details_box)
        outer.addWidget(self.details_box)

        # Drag bar for resizing details box
        self.details_drag_bar = QFrame()
        self.details_drag_bar.setFixedHeight(8)
        self.details_drag_bar.setCursor(Qt.CursorShape.SizeVerCursor)
        self.details_drag_bar.setStyleSheet("""
            QFrame {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 rgba(0,0,0,0.03), stop:0.5 rgba(0,0,0,0.1), stop:1 rgba(0,0,0,0.03));
                border-radius: 2px;
                margin: 0px 30px;
            }
            QFrame:hover {
                background: qlineargradient(x1:0, y1:0, x2:0, y2:1,
                    stop:0 rgba(37,99,235,0.15), stop:0.5 rgba(37,99,235,0.4), stop:1 rgba(37,99,235,0.15));
            }
        """)
        self.details_drag_bar.installEventFilter(self)
        self._details_dragging = False
        outer.addWidget(self.details_drag_bar)

        # ─────────────────────────────────────────────
        # SAVE BUTTON
        # ─────────────────────────────────────────────
        save_btn = QPushButton("Save & Close")
        save_btn.clicked.connect(self._save)
        save_btn.setStyleSheet("""
            QPushButton {
                padding: 8px;
                background:#008C7E;
                color:white;
                border-radius:6px;
            }
        """)
        outer.addWidget(save_btn)

    # ─────────────────────────────────────────────
    # DRAG BAR EVENT FILTER
    # ─────────────────────────────────────────────
    def eventFilter(self, obj, event):
        from PySide6.QtCore import QEvent
        if obj == self.details_drag_bar:
            if event.type() == QEvent.Type.MouseButtonPress:
                self._details_dragging = True
                self._drag_start_y = event.globalPosition().y()
                self._drag_start_height = self._details_height
                return True
            elif event.type() == QEvent.Type.MouseMove and self._details_dragging:
                delta = event.globalPosition().y() - self._drag_start_y
                new_height = max(60, min(300, int(self._drag_start_height + delta)))
                self._details_height = new_height
                self.details_box.setMinimumHeight(new_height)
                self.details_box.setMaximumHeight(new_height)
                return True
            elif event.type() == QEvent.Type.MouseButtonRelease:
                self._details_dragging = False
                return True
        return super().eventFilter(obj, event)

    # ─────────────────────────────────────────────
    # SLIDER HANDLER
    # ─────────────────────────────────────────────
    def _on_slider_changed(self, value: int):
        self.current_severity = value

    # ─────────────────────────────────────────────
    # SAVE EMIT
    # ─────────────────────────────────────────────
    def _save(self):
        details = self.details_box.toPlainText().strip()
        self.saved.emit(self.label, self.current_severity, details)
        self.close()

    # ─────────────────────────────────────────────
    # FADE IN
    # ─────────────────────────────────────────────
    def show_centered(self, parent: QWidget):
        rect = parent.rect()
        tl = parent.mapToGlobal(rect.topLeft())
        x = tl.x() + rect.width() // 2 - self.width() // 2
        y = tl.y() + rect.height() // 2 - self.height() // 2
        self.move(x, y)

        self.setWindowOpacity(0)
        self.show()

        anim = QPropertyAnimation(self, b"windowOpacity")
        anim.setDuration(150)
        anim.setStartValue(0.0)
        anim.setEndValue(1.0)
        anim.start()

        self._anim = anim
