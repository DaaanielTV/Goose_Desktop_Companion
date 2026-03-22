"""
Goose Desktop Companion - Main Application Class

Orchestrates:
- Configuration loading
- Animation engine creation
- PowerShell IPC setup
- Main window initialization
- Application lifecycle
"""

import logging
import sys
from pathlib import Path
from typing import Optional

from PyQt5.QtWidgets import QApplication, QMessageBox
from PyQt5.QtCore import Qt

from .config import get_config, GooseConfig
from .animation_engine import AnimationEngine
from .window import GooseMainWindow
from .powershell_ipc import PowerShellIPC

logger = logging.getLogger(__name__)


class GooseApplication:
    """
    Main application class orchestrating all components.
    """

    def __init__(self, config_path: Optional[Path] = None):
        """
        Initialize Goose application.
        
        Args:
            config_path: Path to config.ini
        """
        self.config = GooseConfig(config_path)
        self.qt_app: Optional[QApplication] = None
        self.main_window: Optional[GooseMainWindow] = None
        self.powershell_ipc: Optional[PowerShellIPC] = None
        
        self._setup_logging()
        logger.info("Goose Application initialized")

    def _setup_logging(self):
        """Setup logging configuration"""
        debug_config = self.config.debug_config
        log_level = getattr(logging, debug_config.get('log_level', 'INFO'))
        
        # Configure root logger
        root_logger = logging.getLogger()
        root_logger.setLevel(log_level)

    def setup(self):
        """Setup application components"""
        try:
            # Create Qt application if needed
            if not QApplication.instance():
                self.qt_app = QApplication(sys.argv)
            else:
                self.qt_app = QApplication.instance()
            
            # Create main window
            ui_config = self.config.ui_config
            self.main_window = GooseMainWindow(
                width=ui_config['window_width'],
                height=ui_config['window_height'],
                config={
                    'ui_config': ui_config,
                    'animation_config': self.config.animation_config,
                    'debug_config': self.config.debug_config,
                }
            )
            
            # Setup PowerShell IPC (optional)
            ps_config = self.config.powershell_config
            try:
                self.powershell_ipc = PowerShellIPC(
                    ps_config['script_path'],
                    ps_config
                )
                self.powershell_ipc.start()
                logger.info("PowerShell IPC started")
                
                # Register state update callback
                if self.main_window and self.main_window.animation_engine:
                    def on_ps_state(state):
                        # Update Python animation engine from PowerShell state
                        logger.debug(f"Received PowerShell state: {state}")
                    
                    self.powershell_ipc.register_callback("state_received", on_ps_state)
            except Exception as e:
                logger.warning(f"PowerShell IPC not available (running in demo mode): {e}")
            
            # Start animation loop
            framerate = ui_config.get('framerate', 60)
            self.main_window.start_animation_loop(framerate)

            if self.config.should_show_onboarding() and self.main_window:
                self._show_onboarding()
            
            logger.info("Application setup complete")
            return True
        except Exception as e:
            logger.error(f"Failed to setup application: {e}", exc_info=True)
            return False


    def _show_onboarding(self):
        """Display a first-run onboarding dialog and persist completion."""
        if not self.main_window:
            return

        message_box = QMessageBox(self.main_window)
        message_box.setWindowTitle("Welcome to Goose Desktop Companion")
        message_box.setIcon(QMessageBox.Information)
        message_box.setText("Your goose is ready to explore your desktop.")
        message_box.setInformativeText(
            "This onboarding is only shown once.\n\n"
            "• Drag the goose with the left mouse button.\n"
            "• Double-click to trigger a happy bounce.\n"
            "• Press Space to cycle through moods.\n"
            "• Press Esc anytime to close the companion."
        )
        message_box.setStandardButtons(QMessageBox.Ok)
        message_box.exec()

        try:
            self.config.mark_onboarding_completed()
        except OSError as exc:
            logger.warning(f"Failed to persist onboarding completion: {exc}")

    def run(self):
        """Run the application"""
        if not self.setup():
            logger.error("Failed to setup application")
            return 1
        
        logger.info("Starting application event loop")
        return self.qt_app.exec() if self.qt_app else 1

    def cleanup(self):
        """Cleanup resources"""
        if self.main_window:
            self.main_window.close()
        
        if self.powershell_ipc:
            self.powershell_ipc.stop()
        
        logger.info("Application cleanup complete")

    def __enter__(self):
        """Context manager entry"""
        self.setup()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.cleanup()


def main():
    """Entry point for Goose application"""
    import os
    
    # Change to script directory
    os.chdir(Path(__file__).parent.parent)
    
    app = GooseApplication()
    return app.run()


if __name__ == "__main__":
    sys.exit(main())
