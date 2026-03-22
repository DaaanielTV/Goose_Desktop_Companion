"""
Procedural Animation Engine for Goose

Implements:
- Procedural breathing (sine wave)
- Procedural blinking (timer)
- Animation state machine
- Mood system
- Complex procedural generation
"""

import math
import time
from dataclasses import dataclass, field
from enum import Enum
from typing import Dict, Optional, Tuple, Any
from datetime import datetime
import logging

logger = logging.getLogger(__name__)


class Mood(Enum):
    """Goose mood states"""
    NEUTRAL = "neutral"
    HAPPY = "happy"
    SLEEPY = "sleepy"
    CURIOUS = "curious"
    STARTLED = "startled"
    CONTENT = "content"
    PLAYFUL = "playful"


class EyeDirection(Enum):
    """Eye gaze directions"""
    FORWARD = "forward"
    LOOKING_AROUND = "looking_around"
    CLOSED = "closed"
    LEFT = "left"
    RIGHT = "right"


@dataclass
class AnimationState:
    """Current animation state of the goose"""
    position: Tuple[float, float] = (100.0, 100.0)  # (x, y) in pixels
    rotation: float = 0.0  # degrees
    scale: float = 1.0  # 0.5-2.0
    opacity: float = 1.0  # 0.0-1.0
    
    current_animation: str = "idle"
    animation_frame: int = 0
    animation_progress: float = 0.0  # 0.0-1.0
    
    mood: Mood = Mood.NEUTRAL
    energy: float = 1.0  # 0.3-1.5 multiplier
    
    is_breathing: bool = True
    breathing_offset: float = 0.0  # Calculated vertical offset
    
    eye_direction: EyeDirection = EyeDirection.FORWARD
    is_blinking: bool = False
    blink_timer: int = 0


@dataclass
class AnimationQueueEntry:
    """Animation queue entry"""
    animation_type: str
    start_time: datetime = field(default_factory=datetime.now)
    duration: float = 0.5  # seconds
    progress: float = 0.0  # 0.0-1.0


class AnimationEngine:
    """
    Core animation engine implementing procedural generation and animation state machine.
    
    Handles:
    - Breathing simulation (sine wave)
    - Blinking simulation (timer-based)
    - Mood transitions
    - Animation queue management
    - Complex procedural animation generation
    """

    def __init__(self, config: Dict[str, Any]):
        """
        Initialize animation engine.
        
        Args:
            config: Animation configuration dictionary from GooseConfig.animation_config
        """
        self.config = config
        self.state = AnimationState()
        self.animation_queue: Dict[str, AnimationQueueEntry] = {}
        self.frame_count = 0
        self.last_blink_time = time.time()
        
        logger.info("Animation engine initialized")

    def update(self, delta_time: float = 0.016) -> AnimationState:
        """
        Update animation state (call once per frame).
        
        Args:
            delta_time: Time since last frame in seconds (default ~60 Hz)
            
        Returns:
            Current animation state
        """
        if not self.config['subtle_animations']:
            return self.state

        self.frame_count += 1
        
        # Update procedural animations
        self._update_breathing()
        self._update_blinking()
        self._update_animation_queue(delta_time)
        
        return self.state

    def _update_breathing(self):
        """
        Update breathing animation (procedural sine wave).
        
        Breathing: ±2 pixels vertical oscillation at ~0.8 Hz
        Formula: offset = sin(frame_count * frequency) * amplitude
        """
        if not self.config['breathing_enabled']:
            self.state.breathing_offset = 0.0
            return
        
        frequency = self.config['breathing_frequency']  # radians per frame
        amplitude = self.config['breathing_amplitude']  # pixels
        
        # Sine wave: smooth vertical bob
        self.state.breathing_offset = math.sin(self.frame_count * frequency) * amplitude
        
        # Apply breathing to Y position
        x, y = self.state.position
        self.state.position = (x, y + self.state.breathing_offset)

    def _update_blinking(self):
        """
        Update blinking animation (procedural timer).
        
        Natural 5-second blink interval with 5-frame blink duration
        """
        if not self.config['blinking_enabled']:
            self.state.is_blinking = False
            self.state.blink_timer = 0
            return
        
        blink_interval = self.config['blink_interval']  # frames
        blink_duration = self.config['blink_duration']  # frames
        
        self.state.blink_timer += 1
        
        if self.state.blink_timer > blink_interval:
            # Trigger blink
            self.state.is_blinking = True
            self.state.blink_timer = 0
        elif self.state.is_blinking and self.state.blink_timer > blink_duration:
            # End blink
            self.state.is_blinking = False

    def _update_animation_queue(self, delta_time: float):
        """
        Update queued animations and remove expired ones.
        
        Args:
            delta_time: Time since last frame in seconds
        """
        expired = []
        
        for anim_type, entry in self.animation_queue.items():
            elapsed = (datetime.now() - entry.start_time).total_seconds()
            entry.progress = min(elapsed / entry.duration, 1.0)
            
            if entry.progress >= 1.0:
                expired.append(anim_type)
        
        for anim_type in expired:
            del self.animation_queue[anim_type]

    def queue_animation(self, animation_type: str, duration: float = 0.5):
        """
        Queue an animation.
        
        Args:
            animation_type: Name of animation (e.g., "happy_bounce", "walk")
            duration: Duration in seconds
        """
        if not self.config['subtle_animations']:
            return
        
        entry = AnimationQueueEntry(
            animation_type=animation_type,
            duration=duration
        )
        self.animation_queue[animation_type] = entry
        logger.debug(f"Queued animation: {animation_type} ({duration}s)")

    def set_mood(self, mood: Mood):
        """
        Set mood and trigger associated animations.
        
        Args:
            mood: New mood state
        """
        if mood == self.state.mood:
            return
        
        old_mood = self.state.mood
        self.state.mood = mood
        
        # Trigger mood-based animations
        mood_animations = {
            Mood.HAPPY: ("happy_bounce", 0.3),
            Mood.SLEEPY: ("sleepy_yawn", 1.0),
            Mood.CURIOUS: ("head_tilt", 0.8),
            Mood.STARTLED: ("quick_jump", 0.2),
            Mood.CONTENT: ("idle", 0.5),
            Mood.PLAYFUL: ("waddle", 0.6),
        }
        
        if mood in mood_animations:
            anim_type, duration = mood_animations[mood]
            self.queue_animation(anim_type, duration)
        
        logger.debug(f"Mood changed: {old_mood.value} → {mood.value}")

    def set_position(self, x: float, y: float):
        """Set goose position"""
        self.state.position = (x, y)

    def get_visual_state(self) -> Dict[str, Any]:
        """
        Get complete visual state for rendering.
        
        Returns:
            Dictionary with all rendering parameters
        """
        return {
            "position": {
                "x": self.state.position[0],
                "y": self.state.position[1],
            },
            "rotation": self.state.rotation,
            "scale": self.state.scale,
            "opacity": self.state.opacity,
            "current_animation": self.state.current_animation,
            "animation_progress": self.state.animation_progress,
            "mood": self.state.mood.value,
            "energy": self.state.energy,
            "vertical_offset": self.state.breathing_offset,
            "is_blinking": self.state.is_blinking,
            "eye_direction": self.state.eye_direction.value,
            "animation_queue": list(self.animation_queue.keys()),
        }

    @staticmethod
    def generate_wave_animation(
        amplitude: float = 10.0,
        frequency: float = 0.1,
        duration: float = 2.0,
        frame_count: int = None
    ) -> Dict[int, Tuple[float, float]]:
        """
        Generate wave motion animation procedurally.
        
        Args:
            amplitude: Wave height in pixels
            frequency: Wave frequency in radians/frame
            duration: Total duration in seconds
            frame_count: Override frame count
            
        Returns:
            Dictionary mapping frame to (x_offset, y_offset)
        """
        frames = frame_count or int(duration * 60)
        motion = {}
        
        for frame in range(frames):
            x_offset = amplitude * math.sin(frame * frequency)
            y_offset = amplitude * math.cos(frame * frequency * 0.7)  # Different phase
            motion[frame] = (x_offset, y_offset)
        
        return motion

    @staticmethod
    def generate_bounce_animation(
        gravity: float = 9.8,
        initial_velocity: float = 200.0,
        duration: float = 0.5,
        frame_count: int = None
    ) -> Dict[int, float]:
        """
        Generate bounce animation based on physics.
        
        Args:
            gravity: Gravity acceleration pixels/frame²
            initial_velocity: Initial upward velocity pixels/frame
            duration: Bounce duration in seconds
            frame_count: Override frame count
            
        Returns:
            Dictionary mapping frame to y_offset
        """
        frames = frame_count or int(duration * 60)
        motion = {}
        
        for frame in range(frames):
            # Simple kinematic: y = y0 + v0*t - 0.5*g*t²
            t = frame / 60.0  # Convert frames to seconds
            y_offset = initial_velocity * t - 0.5 * gravity * t * t
            motion[frame] = max(y_offset, 0.0)  # Don't go below ground
        
        return motion

    @staticmethod
    def generate_spiral_animation(
        radius: float = 50.0,
        rotations: float = 2.0,
        duration: float = 1.0,
        frame_count: int = None
    ) -> Dict[int, Tuple[float, float]]:
        """
        Generate spiral motion procedurally.
        
        Args:
            radius: Maximum spiral radius in pixels
            rotations: Number of rotations
            duration: Total duration in seconds
            frame_count: Override frame count
            
        Returns:
            Dictionary mapping frame to (x_offset, y_offset)
        """
        frames = frame_count or int(duration * 60)
        motion = {}
        
        for frame in range(frames):
            t = frame / frames  # 0.0 to 1.0
            angle = t * rotations * 2 * math.pi
            r = radius * t  # Spiral outward
            
            x_offset = r * math.cos(angle)
            y_offset = r * math.sin(angle)
            motion[frame] = (x_offset, y_offset)
        
        return motion

    def set_energy(self, energy: float):
        """Set energy level (0.3-1.5)"""
        self.state.energy = max(0.3, min(1.5, energy))
