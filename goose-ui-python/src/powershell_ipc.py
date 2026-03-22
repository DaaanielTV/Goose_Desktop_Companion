"""
PowerShell IPC (Inter-Process Communication) Layer

Handles communication between Python UI and PowerShell core:
- Sending animation commands to PowerShell
- Receiving animation state from PowerShell
- Executing PowerShell scripts
- Management of subprocess
"""

import subprocess
import json
import threading
import queue
import time
import logging
import sys
from pathlib import Path
from typing import Dict, Any, Optional, Callable
import os

logger = logging.getLogger(__name__)


class PowerShellIPC:
    """
    Manages IPC with PowerShell core via subprocess.
    
    Architecture:
    - Python spawns PowerShell.exe subprocess
    - Communicates via named pipes or subprocess stdin/stdout
    - Sends JSON commands, receives JSON state updates
    """

    def __init__(self, script_path: str, config: Dict[str, Any]):
        """
        Initialize PowerShell IPC.
        
        Args:
            script_path: Path to PowerShell script (relative or absolute)
            config: PowerShell configuration dictionary
        """
        self.script_path = Path(script_path)
        self.config = config
        self.process: Optional[subprocess.Popen] = None
        self.is_running = False
        self.polling_interval = config['polling_interval'] / 1000.0  # Convert ms to seconds
        
        self.state_queue: queue.Queue = queue.Queue()
        self.command_queue: queue.Queue = queue.Queue()
        
        self._reader_thread: Optional[threading.Thread] = None
        self._writer_thread: Optional[threading.Thread] = None
        
        self.callbacks: Dict[str, Callable] = {}
        
        logger.info("PowerShell IPC initialized")

    def start(self):
        """Start PowerShell subprocess and communication threads"""
        if self.is_running:
            logger.warning("PowerShell IPC already running")
            return
        
        try:
            self._start_subprocess()
            self.is_running = True
            
            # Start reader and writer threads
            self._reader_thread = threading.Thread(target=self._read_loop, daemon=True)
            self._writer_thread = threading.Thread(target=self._write_loop, daemon=True)
            
            self._reader_thread.start()
            self._writer_thread.start()
            
            logger.info("PowerShell IPC started successfully")
        except Exception as e:
            logger.error(f"Failed to start PowerShell IPC: {e}")
            self.is_running = False
            raise

    def _start_subprocess(self):
        """Start PowerShell subprocess"""
        
        # Resolve script path
        if not self.script_path.is_absolute():
            script_path = Path(__file__).parent.parent.parent / self.script_path
        else:
            script_path = self.script_path
        
        if not script_path.exists():
            raise FileNotFoundError(f"PowerShell script not found: {script_path}")
        
        logger.info(f"Starting PowerShell subprocess with script: {script_path}")
        
        # Windows PowerShell or pwsh (cross-platform)
        ps_cmd = "pwsh" if sys.platform != "win32" else "powershell.exe"
        
        # PowerShell command to execute script and emit JSON state
        ps_script = f"""
        $ErrorActionPreference = 'Stop'
        . '{script_path}'
        
        # Main loop: get visual state and emit JSON
        while ($true) {{
            try {{
                if ($null -ne $GooseCore) {{
                    $state = $GooseCore.GetVisualState()
                    $json = $state | ConvertTo-Json -Compress
                    Write-Host "STATE:$json"
                }}
            }} catch {{
                Write-Error "Animation state error: $_"
            }}
            Start-Sleep -Milliseconds {self.polling_interval * 1000}
        }}
        """
        
        try:
            self.process = subprocess.Popen(
                [ps_cmd, "-NoProfile", "-Command", ps_script],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                stdin=subprocess.PIPE,
                text=True,
                bufsize=1,  # Line buffered
            )
        except FileNotFoundError:
            logger.error(f"PowerShell executable not found: {ps_cmd}")
            raise

    def stop(self):
        """Stop PowerShell subprocess and communication threads"""
        if not self.is_running:
            logger.warning("PowerShell IPC not running")
            return
        
        self.is_running = False
        
        if self.process:
            try:
                self.process.terminate()
                self.process.wait(timeout=5)
            except subprocess.TimeoutExpired:
                self.process.kill()
            logger.info("PowerShell subprocess terminated")
        
        if self._reader_thread:
            self._reader_thread.join(timeout=2)
        if self._writer_thread:
            self._writer_thread.join(timeout=2)
        
        logger.info("PowerShell IPC stopped")

    def _read_loop(self):
        """Read animation state from PowerShell subprocess"""
        if not self.process:
            return
        
        try:
            while self.is_running and self.process.stdout:
                line = self.process.stdout.readline()
                if not line:
                    break
                
                line = line.strip()
                if not line:
                    continue
                
                # Parse STATE: JSON format
                if line.startswith("STATE:"):
                    try:
                        json_str = line[6:]  # Remove "STATE:" prefix
                        state = json.loads(json_str)
                        self.state_queue.put(state)
                        
                        # Call callbacks
                        if "state_received" in self.callbacks:
                            self.callbacks["state_received"](state)
                    except json.JSONDecodeError as e:
                        logger.error(f"Failed to parse JSON state: {e}")
                else:
                    logger.debug(f"PowerShell: {line}")
        except Exception as e:
            logger.error(f"Error in PowerShell read loop: {e}")

    def _write_loop(self):
        """Write commands to PowerShell subprocess"""
        if not self.process:
            return
        
        try:
            while self.is_running:
                try:
                    command = self.command_queue.get(timeout=0.5)
                    if self.process.stdin:
                        self.process.stdin.write(command + "\n")
                        self.process.stdin.flush()
                        logger.debug(f"Sent command: {command}")
                except queue.Empty:
                    pass
        except Exception as e:
            logger.error(f"Error in PowerShell write loop: {e}")

    def send_command(self, command: str):
        """
        Send command to PowerShell core.
        
        Args:
            command: PowerShell command or script
        """
        if not self.is_running:
            logger.warning("PowerShell IPC not running, command not sent")
            return
        
        self.command_queue.put(command)

    def get_state(self, timeout: float = 1.0) -> Optional[Dict[str, Any]]:
        """
        Get latest animation state from PowerShell.
        
        Args:
            timeout: How long to wait for state in seconds
            
        Returns:
            Animation state dictionary, or None if timeout
        """
        try:
            # Drain old states, keep newest
            state = None
            while True:
                try:
                    state = self.state_queue.get(block=False)
                except queue.Empty:
                    break
            
            if state:
                return state
            
            # If no state in queue, wait for next one
            state = self.state_queue.get(timeout=timeout)
            return state
        except queue.Empty:
            return None

    def register_callback(self, event: str, callback: Callable):
        """
        Register callback for events.
        
        Args:
            event: Event name ("state_received", etc.)
            callback: Function to call on event
        """
        self.callbacks[event] = callback
        logger.debug(f"Registered callback for event: {event}")

    def trigger_animation(self, animation_name: str, duration: float = 0.5):
        """
        Trigger animation in PowerShell core.
        
        Args:
            animation_name: Name of animation
            duration: Duration in seconds
        """
        command = f"$GooseCore.AnimationEngine.QueueAnimation('{animation_name}', {duration})"
        self.send_command(command)

    def set_mood(self, mood: str):
        """
        Set goose mood from Python.
        
        Args:
            mood: Mood name (neutral, happy, sleepy, etc.)
        """
        command = f"$GooseCore.SetMood('{mood}')"
        self.send_command(command)

    def __enter__(self):
        """Context manager entry"""
        self.start()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        """Context manager exit"""
        self.stop()
