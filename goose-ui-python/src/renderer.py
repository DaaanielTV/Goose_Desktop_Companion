"""
Goose Sprite Renderer

Renders the animated goose using:
- QPainter for custom shapes and procedural rendering
- Supports both sprite-based and procedurally generated graphics
- Hardware acceleration via OpenGL (future)
"""

import math
from typing import Dict, Any, Tuple
from PyQt5.QtCore import Qt, QTimer, QRect, QPoint
from PyQt5.QtGui import QPainter, QColor, QBrush, QPen, QImage, QPixmap
from PyQt5.QtWidgets import QWidget
import logging

logger = logging.getLogger(__name__)


class GooseRenderer(QWidget):
    """
    Custom widget for rendering the animated goose.
    """

    def __init__(self, width: int = 256, height: int = 256, parent=None):
        """
        Initialize goose renderer.
        
        Args:
            width: Render width in pixels
            height: Render height in pixels
            parent: Parent Qt widget
        """
        super().__init__(parent)
        self.width = width
        self.height = height
        self.visual_state: Dict[str, Any] = {}
        
        # Rendering settings
        self.render_quality = 2  # Scaling factor for anti-aliasing
        self.debug_hitboxes = False
        
        # Create off-screen buffer for double-buffering
        self.buffer = QImage(
            width * self.render_quality,
            height * self.render_quality,
            QImage.Format_ARGB32_Premultiplied
        )
        
        self.setMinimumSize(width, height)
        logger.info(f"GooseRenderer initialized: {width}x{height}")

    def set_visual_state(self, state: Dict[str, Any]):
        """
        Update visual state for rendering.
        
        Args:
            state: Animation state dictionary from AnimationEngine
        """
        self.visual_state = state
        self.update()  # Request repaint

    def paintEvent(self, event):
        """
        Handle paint event - render the goose.
        
        Args:
            event: QPaintEvent
        """
        # Render to buffer
        self._render_to_buffer()
        
        # Draw buffer to screen
        painter = QPainter(self)
        painter.setRenderHint(QPainter.SmoothPixmapTransform)
        painter.drawImage(0, 0, self.buffer.scaledToWidth(self.width))
        painter.end()

    def _render_to_buffer(self):
        """Render animated goose to off-screen buffer"""
        self.buffer.fill(QColor(0, 0, 0, 0))  # Transparent
        painter = QPainter(self.buffer)
        painter.setRenderHint(QPainter.Antialiasing)
        painter.setRenderHint(QPainter.SmoothPixmapTransform)
        
        # Scale for high-DPI rendering
        painter.scale(self.render_quality, self.render_quality)
        
        if self.visual_state:
            self._draw_goose(painter)
            
            if self.debug_hitboxes:
                self._draw_debug_info(painter)
        
        painter.end()

    def _draw_goose(self, painter: QPainter):
        """
        Draw animated goose sprite.
        
        Args:
            painter: QPainter for drawing
        """
        # Get state
        pos = self.visual_state.get('position', {'x': 100, 'y': 100})
        mood = self.visual_state.get('mood', 'neutral')
        is_blinking = self.visual_state.get('is_blinking', False)
        animation_progress = self.visual_state.get('animation_progress', 0.0)
        
        x = pos.get('x', 100)
        y = pos.get('y', 100) + self.visual_state.get('vertical_offset', 0.0)
        
        # Get color based on mood
        mood_colors = {
            'neutral': QColor(100, 150, 200),
            'happy': QColor(150, 200, 100),
            'sleepy': QColor(180, 150, 100),
            'curious': QColor(200, 150, 100),
            'startled': QColor(200, 100, 100),
            'content': QColor(120, 180, 120),
            'playful': QColor(200, 150, 200),
        }
        goose_color = mood_colors.get(mood, mood_colors['neutral'])
        
        # Draw goose body (simplified procedural)
        self._draw_goose_body(painter, x, y, goose_color)
        
        # Draw head
        self._draw_head(painter, x, y, goose_color, is_blinking)
        
        # Draw beak
        self._draw_beak(painter, x, y)
        
        # Draw eyes
        eye_offset = self.visual_state.get('eye_direction', 'forward')
        self._draw_eyes(painter, x, y, is_blinking, eye_offset)

    def _draw_goose_body(self, painter: QPainter, x: float, y: float, color: QColor):
        """Draw goose body (oval shape)"""
        painter.setBrush(QBrush(color))
        pen = QPen(Qt.darkGray)
        pen.setWidth(2)
        painter.setPen(pen)
        painter.drawEllipse(int(x - 20), int(y + 20), 40, 50)

    def _draw_head(self, painter: QPainter, x: float, y: float, body_color: QColor, is_blinking: bool):
        """Draw goose head (circle)"""
        painter.setBrush(QBrush(body_color))
        pen = QPen(Qt.darkGray)
        pen.setWidth(2)
        painter.setPen(pen)
        painter.drawEllipse(int(x - 18), int(y - 20), 36, 35)

    def _draw_beak(self, painter: QPainter, x: float, y: float):
        """Draw goose beak"""
        painter.setBrush(QBrush(QColor(255, 200, 100)))
        pen = QPen(Qt.darkYellow)
        pen.setWidth(1)
        painter.setPen(pen)
        
        # Triangle for beak
        beak_x = int(x + 18)
        beak_y = int(y - 5)
        painter.drawPolygon([
            QPoint(beak_x, beak_y),
            QPoint(beak_x + 15, beak_y - 3),
            QPoint(beak_x + 15, beak_y + 3)
        ])

    def _draw_eyes(
        self,
        painter: QPainter,
        x: float,
        y: float,
        is_blinking: bool,
        eye_direction: str
    ):
        """Draw goose eyes"""
        left_eye_x = x - 7
        right_eye_x = x + 7
        eye_y = y - 10
        
        if is_blinking:
            # Draw closed eyes (horizontal lines)
            painter.setPen(QPen(Qt.black, 2))
            painter.drawLine(int(left_eye_x - 4), int(eye_y), int(left_eye_x + 4), int(eye_y))
            painter.drawLine(int(right_eye_x - 4), int(eye_y), int(right_eye_x + 4), int(eye_y))
        else:
            # Draw open eyes (circles with pupils)
            painter.setBrush(QBrush(QColor(255, 255, 255)))
            painter.setPen(QPen(Qt.black, 1))
            painter.drawEllipse(int(left_eye_x - 3), int(eye_y - 3), 6, 6)
            painter.drawEllipse(int(right_eye_x - 3), int(eye_y - 3), 6, 6)
            
            # Draw pupils based on eye direction
            pupil_offset = self._get_pupil_offset(eye_direction)
            painter.setBrush(QBrush(QColor(0, 0, 0)))
            painter.setPen(Qt.NoPen)
            painter.drawEllipse(
                int(left_eye_x + pupil_offset[0] - 1.5),
                int(eye_y + pupil_offset[1] - 1.5),
                3, 3
            )
            painter.drawEllipse(
                int(right_eye_x + pupil_offset[0] - 1.5),
                int(eye_y + pupil_offset[1] - 1.5),
                3, 3
            )

    @staticmethod
    def _get_pupil_offset(eye_direction: str) -> Tuple[float, float]:
        """Get pupil offset based on eye direction"""
        offsets = {
            'forward': (0, 0),
            'left': (-2, 0),
            'right': (2, 0),
            'looking_around': (1.5, -0.5),
            'closed': (0, 0),
        }
        return offsets.get(eye_direction, (0, 0))

    def _draw_debug_info(self, painter: QPainter):
        """Draw debug hitbox and info"""
        if not self.visual_state:
            return
        
        # Draw position point
        pos = self.visual_state.get('position', {'x': 100, 'y': 100})
        x = pos.get('x', 100)
        y = pos.get('y', 100)
        
        painter.setBrush(Qt.NoBrush)
        painter.setPen(QPen(QColor(255, 0, 0, 128), 1))
        painter.drawRect(int(x - 25), int(y - 30), 50, 80)  # Hitbox
        
        # Draw center point
        painter.setPen(QPen(QColor(0, 255, 0), 2))
        painter.drawPoint(int(x), int(y))

    def resizeEvent(self, event):
        """Handle resize event"""
        self.width = event.size().width()
        self.height = event.size().height()
        self.buffer = QImage(
            self.width * self.render_quality,
            self.height * self.render_quality,
            QImage.Format_ARGB32_Premultiplied
        )
