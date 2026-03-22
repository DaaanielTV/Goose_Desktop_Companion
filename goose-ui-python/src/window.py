"""
PyQt5 Main Window for Goose Desktop Companion

Handles:
- Window creation and positioning
- Event handling (mouse, keyboard, clicks)
- Integration of renderer and animation engine
"""

import logging
from PyQt5.QtCore import Qt, QTimer, QPoint, QRect, QScreen
from PyQt5.QtGui import QMouseEvent, QIcon
from PyQt5.QtWidgets import QMainWindow, QVBoxLayout, QWidget
from typing import Optional, Dict, Any

from .renderer import GooseRenderer
from .animation_engine import AnimationEngine, Mood

logger = logging.getLogger(__name__)


class GooseMainWindow(QMainWindow):
    """
    Main application window for Goose Desktop Companion.
    """

    def __init__(self, width: int = 256, height: int = 256, config: Optional[Dict[str, Any]] = None):
        """
        Initialize main window.
        
        Args:
            width: Window width
            height: Window height
            config: Configuration dictionary
        """
        super().__init__()
        self.config = config or {}
        self.width = width
        self.height = height
        
        # Create renderer
        self.renderer = GooseRenderer(width, height)
        
        # Create animation engine
        self.animation_engine = AnimationEngine(
            self.config.get('animation_config', {})
        )
        
        # Mouse tracking
        self.mouse_pressed = False
        self.mouse_offset = QPoint(0, 0)
        
        # Setup window
        self._setup_window()
        
        # Animation timer
        self.animation_timer = QTimer()
        self.animation_timer.timeout.connect(self._on_animation_update)
        
        logger.info("GooseMainWindow initialized")

    def _setup_window(self):
        """Setup window properties and layout"""
        # Create central widget
        central_widget = QWidget()
        layout = QVBoxLayout()
        layout.setContentsMargins(0, 0, 0, 0)
        layout.addWidget(self.renderer)
        central_widget.setLayout(layout)
        self.setCentralWidget(central_widget)
        
        # Window properties
        self.setWindowTitle("Goose Desktop Companion")
        self.setGeometry(100, 100, self.width, self.height)
        self.setFixedSize(self.width, self.height)
        
        # Transparent window (if supported)
        self.setAttribute(Qt.WA_TranslucentBackground)
        
        # Always on top
        if self.config.get('ui_config', {}).get('always_on_top', True):
            self.setWindowFlags(
                self.windowFlags() | Qt.WindowStaysOnTopHint | Qt.FramelessWindowHint
            )
        else:
            self.setWindowFlags(self.windowFlags() | Qt.FramelessWindowHint)
        
        self.show()

    def start_animation_loop(self, framerate: int = 60):
        """
        Start animation update loop.
        
        Args:
            framerate: Target framerate in Hz
        """
        interval_ms = 1000 // framerate
        self.animation_timer.start(interval_ms)
        logger.info(f"Animation loop started at {framerate} FPS")

    def stop_animation_loop(self):
        """Stop animation update loop"""
        self.animation_timer.stop()
        logger.info("Animation loop stopped")

    def _on_animation_update(self):
        """Handle animation frame update"""
        # Update animation engine
        delta_time = 1.0 / self.config.get('ui_config', {}).get('framerate', 60)
        self.animation_engine.update(delta_time)
        
        # Get visual state and update renderer
        visual_state = self.animation_engine.get_visual_state()
        self.renderer.set_visual_state(visual_state)

    def mousePressEvent(self, event: QMouseEvent):
        """Handle mouse press - enable dragging"""
        if event.button() == Qt.LeftButton:
            self.mouse_pressed = True
            self.mouse_offset = event.pos() - self.frameGeometry().topLeft()

    def mouseReleaseEvent(self, event: QMouseEvent):
        """Handle mouse release"""
        if event.button() == Qt.LeftButton:
            self.mouse_pressed = False

    def mouseMoveEvent(self, event: QMouseEvent):
        """Handle mouse move - drag window"""
        if self.mouse_pressed:
            new_pos = event.globalPos() - self.mouse_offset
            self.move(new_pos)

    def mouseDoubleClickEvent(self, event: QMouseEvent):
        """Handle double-click - trigger animation"""
        self.animation_engine.queue_animation("happy_bounce")
        logger.debug("Triggered animation via double-click")

    def keyPressEvent(self, event):
        """Handle keyboard shortcuts"""
        if event.key() == Qt.Key_Escape:
            self.close()
        elif event.key() == Qt.Key_Space:
            # Cycle moods
            moods = list(Mood)
            current_idx = list(Mood).index(self.animation_engine.state.mood)
            next_mood = moods[(current_idx + 1) % len(moods)]
            self.animation_engine.set_mood(next_mood)
            logger.debug(f"Mood cycled to: {next_mood.value}")
        else:
            super().keyPressEvent(event)

    def set_always_on_top(self, always_on_top: bool):
        """Toggle always-on-top window flag"""
        flags = self.windowFlags()
        if always_on_top:
            flags |= Qt.WindowStaysOnTopHint
        else:
            flags &= ~Qt.WindowStaysOnTopHint
        self.setWindowFlags(flags)
        self.show()  # Need to show again after changing flags

    def closeEvent(self, event):
        """Handle window close"""
        self.stop_animation_loop()
        logger.info("GooseMainWindow closed")
        super().closeEvent(event)
