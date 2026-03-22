# Developer Guide - Goose Desktop Companion Python UI

Comprehensive guide for contributing to and extending the Python UI implementation.

## Development Environment Setup

### 1. Clone the Repository
```bash
git clone https://github.com/[repo]/Goose_Desktop_Companion
cd Goose_Desktop_Companion/goose-ui-python
```

### 2. Create Virtual Environment (Recommended)
```bash
# Windows
python -m venv venv
venv\Scripts\activate

# macOS/Linux
python3 -m venv venv
source venv/bin/activate
```

### 3. Install Development Dependencies
```bash
# Base dependencies
pip install -r requirements.txt

# Development tools
pip install pytest pytest-cov black flake8 mypy
```

### 4. Running Tests
```bash
pytest tests/ -v --cov=src
```

### 5. Code Quality Checks
```bash
# Format code
black src/ tests/

# Lint
flake8 src/ tests/

# Type checking
mypy src/
```

## Architecture Deep Dive

### Component Interaction Flow

```
main.py (entry point)
    ↓
GooseApplication.setup()
    ├── Load config (config.py)
    ├── Create Qt app
    ├── Create GooseMainWindow
    │   ├── Initialize AnimationEngine
    │   ├── Create GooseRenderer
    │   └── Connect signals/slots
    ├── Start PowerShellIPC
    │   ├── Spawn PowerShell subprocess
    │   ├── Start reader thread (poll state)
    │   └── Start writer thread (send commands)
    └── Start animation timer (16ms at 60 Hz)

Animation Loop (every frame):
    ├── AnimationEngine.update()
    │   ├── Update breathing (sine wave)
    │   ├── Update blinking (timer)
    │   ├── Update animation queue
    │   └── Return visual state
    ├── Renderer.set_visual_state()
    ├── Renderer.paintEvent()
    │   ├── Render to buffer (double-buffering)
    │   ├── Draw goose sprite
    │   └── Draw to screen
    └── Repeat
```

### Animation Engine State Machine

```
┌─────────────────┐
│  AnimationState │
├─────────────────┤
│ position (x,y)  │
│ mood            │
│ energy          │
│ breathing_offset│
│ is_blinking     │
│ animation_queue │
└─────────────────┘
         ↑
         │ update()
         │ called each frame
         │
┌────────────────────────────────────┐
│  AnimationEngine.update()          │
├────────────────────────────────────┤
│ 1. Calculate breathing offset      │
│    offset = sin(frame * freq) * amp│
│ 2. Update blinking state           │
│    if timer > interval → blink     │
│ 3. Process animation queue         │
│    remove expired animations       │
│ 4. Return get_visual_state()       │
└────────────────────────────────────┘
```

## Extending the Animation System

### Adding a New Animation Type

**Step 1: Define in AnimationEngine**
```python
# animation_engine.py
mood_animations = {
    Mood.DANCING: ("dance_spin", 1.5),  # New!
    # ...
}
```

**Step 2: Generate motion data**
```python
# Create a procedural generator for complex move
@staticmethod
def generate_spin_animation(rotations=2.0, duration=1.5):
    """Generate spinning motion"""
    frames = int(duration * 60)
    motion = {}
    for frame in range(frames):
        angle = (frame / frames) * rotations * 2 * math.pi
        motion[frame] = angle  # Rotation in degrees
    return motion
```

**Step 3: Update renderer**
```python
# renderer.py
def _draw_goose(self, painter):
    # Get animation progress
    if current_anim == "dance_spin":
        rotation = animation_progress * 360
        painter.rotate(rotation)
```

**Step 4: Test**
```python
# Press SPACE to cycle moods and verify
# Or create test:
def test_dance_animation():
    engine = AnimationEngine(config)
    engine.set_mood(Mood.DANCING)
    assert "dance_spin" in engine.animation_queue
```

### Adding Complex Procedural Effects

Example: Sinusoidal wave motion for a "confused" mood

```python
@staticmethod
def generate_confusion_animation(
    amplitude=15.0,
    frequency=0.15,
    duration=2.0
):
    """Generate confused head-tilt animation"""
    frames = int(duration * 60)
    motion = {}
    for frame in range(frames):
        # Head tilts side-to-side
        x_offset = amplitude * math.sin(frame * frequency)
        # Slight up-down as well
        y_offset = amplitude * 0.3 * math.cos(frame * frequency * 1.5)
        motion[frame] = (x_offset, y_offset)
    return motion
```

## PowerShell Integration

### How IPC Works

**PowerShell → Python**: State polling
```
PowerShell: Generate visual state
         ↓
PowerShell: Emit JSON: "STATE:{...}"
         ↓
PowerShellIPC._read_loop(): Read from stdout
         ↓
Re-queue to state_queue
         ↓
AnimationEngine consumes state
```

**Python → PowerShell**: Command injection
```
Python: Queue command
     ↓
PowerShellIPC._write_loop(): Write to stdin
     ↓
PowerShell: Execute command
     ↓
PowerShell: Update internal state
```

### Custom PowerShell Commands

To add a new Python→PowerShell command:

```python
# powershell_ipc.py
def set_custom_mood(self, mood_name: str, intensity: float):
    """Custom command example"""
    command = f"$GooseCore.SetMood('{mood_name}', {intensity})"
    self.send_command(command)

# Usage in window.py
def keyPressEvent(self, event):
    if event.key() == Qt.Key_Plus:
        self.ipc.set_custom_mood("excited", 1.5)
```

### Debugging IPC

Enable debug logging in config.ini:
```ini
[DEBUG]
debug_mode=True
log_level=DEBUG
```

Then check for IPC messages in terminal output:
```
2024-03-22 10:15:42 - powershell_ipc - DEBUG - Sent command: $GooseCore.SetMood('happy')
2024-03-22 10:15:42 - powershell_ipc - DEBUG - Received state: {'mood': 'happy', ...}
```

## Rendering System

### Renderer Architecture

```
GooseRenderer (QWidget)
    ├── paintEvent()
    │   ├── Render to off-screen buffer
    │   └── Draw scaled buffer to screen
    ├── _render_to_buffer()
    │   └── Double-buffering for smooth animation
    └── _draw_goose()
        ├── Draw body (ellipse)
        ├── Draw head (circle)
        ├── Draw beak (polygon)
        └── Draw eyes (circles with pupils)
```

### Custom Rendering

To add custom rendering (e.g., aura effects):

```python
# renderer.py
def _draw_custom_aura(self, painter, x, y, mood):
    """Draw mood-based aura effect"""
    colors = {
        "happy": QColor(255, 255, 0, 80),    # Yellow
        "sleepy": QColor(100, 100, 255, 80), # Blue
        "angry": QColor(255, 100, 100, 80),  # Red
    }
    
    color = colors.get(mood, QColor(255, 255, 255, 0))
    painter.setBrush(QBrush(color))
    painter.setPen(Qt.NoPen)
    
    # Draw expanding circles
    for r in range(30, 60, 10):
        painter.drawEllipse(int(x - r), int(y - r), r * 2, r * 2)
```

Then call in `_draw_goose()`:
```python
def _draw_goose(self, painter):
    # ... existing code ...
    self._draw_custom_aura(painter, x, y, mood)
```

## Testing Strategy

### Unit Tests

```python
# tests/test_animation_engine.py
import pytest
from src.animation_engine import AnimationEngine, Mood

def test_breathing_oscillation():
    """Verify breathing follows sine wave"""
    config = {'breathing_enabled': True}
    engine = AnimationEngine(config)
    
    # Collect offset over time
    offsets = []
    for _ in range(300):
        engine.update()
        offsets.append(engine.state.breathing_offset)
    
    # Verify oscillates between ±2
    assert max(offsets) <= 2.1
    assert min(offsets) >= -2.1

def test_mood_animation_queue():
    """Verify mood triggers correct animation"""
    config = {'subtle_animations': True}
    engine = AnimationEngine(config)
    
    engine.set_mood(Mood.HAPPY)
    assert "happy_bounce" in engine.animation_queue
    
    happy_entry = engine.animation_queue["happy_bounce"]
    assert happy_entry.duration == 0.3
```

### Integration Tests

```python
# tests/test_window.py
from PyQt5.QtWidgets import QApplication
from src.window import GooseMainWindow

def test_window_creation():
    """Verify window initializes correctly"""
    app = QApplication.instance() or QApplication([])
    window = GooseMainWindow(256, 256)
    assert window.width == 256
    assert window.height == 256

def test_double_click_animation():
    """Verify double-click triggers animation"""
    app = QApplication.instance() or QApplication([])
    window = GooseMainWindow()
    
    initial_queue_size = len(window.animation_engine.animation_queue)
    # Simulate double-click
    window.mouseDoubleClickEvent(None)
    
    assert len(window.animation_engine.animation_queue) > initial_queue_size
```

## Performance Optimization

### Profiling

```bash
# Run with profiler
python -m cProfile -s cumulative main.py

# Analyze hot spots
# Focus on:
# - AnimationEngine.update() calls
# - Renderer.paintEvent() calls
# - PowerShellIPC read/write loops
```

### Optimization Tips

1. **Reduce render quality** if CPU is high:
   ```ini
   [UI]
   render_quality=1  # Was 2
   ```

2. **Lower framerate** if not needed:
   ```ini
   [UI]
   framerate=30  # Was 60
   ```

3. **Batch PyQt5 updates**:
   ```python
   # Instead of multiple updates
   painter.begin()
   # ... all drawing ...
   painter.end()
   ```

4. **Cache computed values**:
   ```python
   # Instead of:
   for i in range(1000):
       sin_val = math.sin(i * 0.05)
   
   # Pre-compute:
   sin_table = [math.sin(i * 0.05) for i in range(305)]
   sin_val = sin_table[frame_count % 305]
   ```

## Debugging

### Enable All Debug Output

```ini
[DEBUG]
debug_mode=True
log_level=DEBUG
show_hitboxes=True
```

### Common Issues

**1. Window doesn't appear**
```python
# Check if always_on_top is blocking on some desktop environments
# Try disabling in window.py:
# self.setWindowFlags(Qt.WindowStaysOnTopHint)
```

**2. Animation stutters**
```python
# Verify frame timing in animation_engine.py
# Add print statements in update():
print(f"Frame {self.frame_count}, Offset: {self.state.breathing_offset}")
```

**3. PowerShell IPC fails to start**
```python
# Verify PowerShell is available:
# Windows: Should always be available
# macOS/Linux: Install pwsh: brew install powershell
```

## Building & Distribution

### Cross-Platform Binary

```bash
# Currently builds for current OS
bash build/build.sh  # Or build.bat on Windows

# For true cross-platform, use:
# 1. GitHub Actions (CI/CD)
# 2. Multi-OS Docker containers
# 3. Manual builds on each platform
```

### Optimize Binary Size

```python
# PyInstaller options in build/build.spec
# Remove unused imports to reduce size

# Measure:
# Windows exe: ~80 MB
# macOS app: ~90 MB
# Linux binary: ~85 MB
```

## Next Development Tasks

- [ ] Sprite sheet rendering support
- [ ] GPU acceleration (OpenGL backend)
- [ ] Multi-monitor detection
- [ ] Settings UI dialog
- [ ] Persistent window position
- [ ] Custom skin loading
- [ ] Sound integration
- [ ] Plugin system for animations

---

For questions, open an issue or contact the maintainers.
