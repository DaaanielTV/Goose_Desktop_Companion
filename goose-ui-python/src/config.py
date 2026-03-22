"""
Configuration loader for Goose Desktop Companion

Reads from:
1. ../config.ini (main configuration)
2. Environment variables
3. Defaults
"""

import configparser
import os
import json
from pathlib import Path
from typing import Any, Dict, Optional
import logging

logger = logging.getLogger(__name__)


class GooseConfig:
    """Configuration management for Goose Desktop Companion"""

    def __init__(self, config_path: Optional[Path] = None):
        """
        Initialize configuration loader.
        
        Args:
            config_path: Path to config.ini. If None, searches parent directories.
        """
        self.config = configparser.ConfigParser()
        self.base_path = Path(__file__).parent.parent.parent  # goose-ui-python parent dir
        
        # Locate config.ini
        if config_path is None:
            config_path = self.base_path / "config.ini"
        
        self.config_path = Path(config_path)
        self._load_config()
        self._set_defaults()
        
        logger.info(f"Configuration loaded from {self.config_path}")

    def _load_config(self):
        """Load configuration from config.ini"""
        if self.config_path.exists():
            self.config.read(self.config_path)
            logger.info(f"Loaded config from {self.config_path}")
        else:
            logger.warning(f"Config file not found at {self.config_path}, using defaults only")

    def _set_defaults(self):
        """Set default values for required settings"""
        defaults = {
            'UI': {
                'window_width': '800',
                'window_height': '600',
                'always_on_top': 'True',
                'framerate': '60',
                'animation_quality': 'high',
                'render_quality': '2',  # Scaling factor
            },
            'ANIMATION': {
                'SubtleAnimations': 'True',
                'breathing_enabled': 'True',
                'blinking_enabled': 'True',
                'breathing_amplitude': '2',  # pixels
                'breathing_frequency': '0.05',  # radians per frame
                'blink_interval': '300',  # frames
                'blink_duration': '5',  # frames
                'animation_speed_multiplier': '1.0',
            },
            'POWERSHELL': {
                'script_path': '../Core/GooseCore.ps1',
                'animation_data_polling_interval': '16',  # milliseconds (60 Hz)
                'ipc_timeout': '5000',  # milliseconds
            },
            'DEBUG': {
                'debug_mode': 'False',
                'log_level': 'INFO',
                'show_hitboxes': 'False',
            }
        }
        
        for section, values in defaults.items():
            if not self.config.has_section(section):
                self.config.add_section(section)
            for key, value in values.items():
                if not self.config.has_option(section, key):
                    self.config.set(section, key, value)

    def get(self, section: str, key: str, fallback: Any = None) -> Any:
        """Get configuration value with type conversion"""
        try:
            return self.config.get(section, key)
        except (configparser.NoSectionError, configparser.NoOptionError):
            if fallback is not None:
                return fallback
            raise KeyError(f"Configuration key not found: {section}.{key}")

    def get_bool(self, section: str, key: str, fallback: bool = False) -> bool:
        """Get boolean configuration value"""
        try:
            return self.config.getboolean(section, key)
        except (configparser.NoSectionError, configparser.NoOptionError):
            return fallback

    def get_int(self, section: str, key: str, fallback: int = 0) -> int:
        """Get integer configuration value"""
        try:
            return self.config.getint(section, key)
        except (configparser.NoSectionError, configparser.NoOptionError):
            return fallback

    def get_float(self, section: str, key: str, fallback: float = 0.0) -> float:
        """Get float configuration value"""
        try:
            return self.config.getfloat(section, key)
        except (configparser.NoSectionError, configparser.NoOptionError):
            return fallback

    @property
    def ui_config(self) -> Dict[str, Any]:
        """Get all UI configuration as dictionary"""
        return {
            'window_width': self.get_int('UI', 'window_width', 800),
            'window_height': self.get_int('UI', 'window_height', 600),
            'always_on_top': self.get_bool('UI', 'always_on_top', True),
            'framerate': self.get_int('UI', 'framerate', 60),
            'animation_quality': self.get('UI', 'animation_quality', 'high'),
            'render_quality': self.get_float('UI', 'render_quality', 2.0),
        }

    @property
    def animation_config(self) -> Dict[str, Any]:
        """Get all animation configuration as dictionary"""
        return {
            'subtle_animations': self.get_bool('ANIMATION', 'SubtleAnimations', True),
            'breathing_enabled': self.get_bool('ANIMATION', 'breathing_enabled', True),
            'blinking_enabled': self.get_bool('ANIMATION', 'blinking_enabled', True),
            'breathing_amplitude': self.get_float('ANIMATION', 'breathing_amplitude', 2.0),
            'breathing_frequency': self.get_float('ANIMATION', 'breathing_frequency', 0.05),
            'blink_interval': self.get_int('ANIMATION', 'blink_interval', 300),
            'blink_duration': self.get_int('ANIMATION', 'blink_duration', 5),
            'animation_speed_multiplier': self.get_float('ANIMATION', 'animation_speed_multiplier', 1.0),
        }

    @property
    def powershell_config(self) -> Dict[str, Any]:
        """Get PowerShell IPC configuration"""
        return {
            'script_path': self.get('POWERSHELL', 'script_path', '../Core/GooseCore.ps1'),
            'polling_interval': self.get_int('POWERSHELL', 'animation_data_polling_interval', 16),
            'ipc_timeout': self.get_int('POWERSHELL', 'ipc_timeout', 5000),
        }


    @property
    def app_state_dir(self) -> Path:
        """Get the directory for persisted application state."""
        state_dir = Path.home() / ".goose_desktop_companion"
        state_dir.mkdir(parents=True, exist_ok=True)
        return state_dir

    @property
    def onboarding_state_path(self) -> Path:
        """Get the path for persisted onboarding state."""
        return self.app_state_dir / "onboarding_state.json"

    def should_show_onboarding(self) -> bool:
        """Return True when onboarding has not been completed yet."""
        state_path = self.onboarding_state_path
        if not state_path.exists():
            return True

        try:
            state = json.loads(state_path.read_text(encoding="utf-8"))
        except (OSError, json.JSONDecodeError) as exc:
            logger.warning(f"Failed to read onboarding state from {state_path}: {exc}")
            return True

        return not state.get("completed", False)

    def mark_onboarding_completed(self):
        """Persist onboarding completion so it is only shown once."""
        state_path = self.onboarding_state_path
        state = {"completed": True}
        state_path.write_text(json.dumps(state, indent=2), encoding="utf-8")
        logger.info(f"Stored onboarding completion in {state_path}")

    @property
    def debug_config(self) -> Dict[str, bool]:
        """Get debug configuration"""
        return {
            'debug_mode': self.get_bool('DEBUG', 'debug_mode', False),
            'show_hitboxes': self.get_bool('DEBUG', 'show_hitboxes', False),
        }


# Global config instance
_config_instance: Optional[GooseConfig] = None


def get_config() -> GooseConfig:
    """Get or create global configuration instance (singleton)"""
    global _config_instance
    if _config_instance is None:
        _config_instance = GooseConfig()
    return _config_instance
