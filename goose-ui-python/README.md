# Goose Desktop Companion - Python UI Layer

Modern cross-platform UI for Goose Desktop Companion, replacing the legacy C# WinForms implementation with a pure Python + PyQt5 solution.

## Features

✨ **Cross-Platform**: Windows, macOS, Linux support  
🎨 **Procedural Animation Engine**: Complex animated goose with breathing, blinking, and mood system  
🔌 **PowerShell Integration**: Seamless IPC communication with PowerShell core modules  
⚡ **High Performance**: 60+ FPS rendering with optimizations  
📦 **Zero Dependencies**: Single executable with PyInstaller (no .NET Framework required)  
🎮 **Interactive**: Mouse dragging, keyboard shortcuts, double-click animations  

## Quick Start

### Prerequisites
- Python 3.9+
- pip package manager

### Installation

```bash
# Clone or download the project
cd goose-ui-python

# Create virtual environment (optional but recommended)
python -m venv venv
# On Windows:
venv\Scripts\activate
# On macOS/Linux:
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### Running

```bash
# Development mode
python main.py

# Or with direct module execution
python -m src.app
```

### Building Standalone Executable

```bash
# Windows
build\build.bat

# macOS/Linux
bash build/build.sh
```

This creates a standalone `dist/GooseDesktop/GooseDesktop.exe` (Windows) or `GooseDesktop` (macOS/Linux) that requires no Python installation.

## Architecture

```
┌─────────────────────────────────────────┐
│     Goose Desktop Companion UI          │
│        (Python + PyQt5)                 │
├─────────────────────────────────────────┤
│  GooseApplication (app.py)              │
│  ├── GooseMainWindow (window.py)        │
│  │   └── GooseRenderer (renderer.py)    │
│  ├── AnimationEngine (animation_engine)|
│  └── PowerShellIPC (powershell_ipc.py) │
├─────────────────────────────────────────┤
│  Configuration (config.py)              │
│  └── config.ini / Environment vars      │
├─────────────────────────────────────────┤
│  PowerShell Layer (unchanged)           │
│  ├── GooseCore.ps1                      │
│  ├── 78+ Feature Modules                │
│  └── JSON State Management              │
└─────────────────────────────────────────┘
```

## Key Components

### `app.py` - Application Orchestrator
- Initializes all components
- Manages lifecycle and cleanup
- Sets up PowerShell communication

### `window.py` - PyQt5 Main Window
- Window creation and positioning
- Mouse event handling (dragging)
- Animation loop management
- Keyboard shortcuts

### `animation_engine.py` - Procedural Animation System
- Sine-wave breathing
- Timer-based blinking
- Mood system with animation triggers
- Animation queue management
- Complex procedural generation utilities

### `renderer.py` - Goose Sprite Rendering
- Custom QPainter-based rendering
- Procedural goose sprite (no sprite sheets required)
- Mood-based color variations
- Eye animations and gaze directions
- Optional debug hitbox display

### `powershell_ipc.py` - Inter-Process Communication
- PowerShell subprocess management
- JSON state polling
- Command sending to PowerShell
- Callback system for state updates

### `config.py` - Configuration Management
- Reads `config.ini`
- Environment variable override support
- Type-safe config accessors
- Singleton pattern

## Animation System

The animation engine implements:

### Procedural Animations
- **Breathing**: Sine wave oscillation (±2px, ~0.8 Hz)
- **Blinking**: Natural 5-second intervals with 5-frame blink

### Mood System
| Mood | Animation | Duration |
|------|-----------|----------|
| Happy | happy_bounce | 0.3s |
| Sleepy | sleepy_yawn | 1.0s |
| Curious | head_tilt | 0.8s |
| Startled | quick_jump | 0.2s |
| Content | idle | 0.5s |
| Playful | waddle | 0.6s |

### Procedural Generation Functions
- `generate_wave_animation()` - Sinusoidal motion
- `generate_bounce_animation()` - Physics-based bouncing
- `generate_spiral_animation()` - Spiral path motion

## PowerShell Integration

The Python UI communicates with PowerShell core by:

1. **Spawning PowerShell subprocess** with GooseCore.ps1
2. **Polling animation state** every ~16ms (60 Hz)
3. **Sending animation commands** via subprocess stdin
4. **Receiving JSON state** from subprocess stdout

Example state update from PowerShell:
```json
{
  "position": {"x": 100, "y": 100},
  "mood": "happy",
  "is_blinking": false,
  "vertical_offset": 1.2,
  "animation_queue": ["happy_bounce"]
}
```

## Configuration

Edit `assets/config.ini` or use environment variables:

```ini
[UI]
window_width=256
window_height=256
always_on_top=True
framerate=60

[ANIMATION]
SubtleAnimations=True
breathing_enabled=True
blink_interval=300

[POWERSHELL]
script_path=../Core/GooseCore.ps1
animation_data_polling_interval=16

[DEBUG]
debug_mode=False
log_level=INFO
```

## Keyboard Shortcuts

| Key | Action |
|-----|--------|
| `ESC` | Close application |
| `SPACE` | Cycle through moods |
| Double-click | Trigger happy_bounce animation |
| Left-click + drag | Move window |

## Development

### Project Structure
```
goose-ui-python/
├── src/
│   ├── __init__.py
│   ├── app.py              # Application orchestrator
│   ├── window.py           # Main window
│   ├── renderer.py         # Goose sprite rendering
│   ├── animation_engine.py # Animation state machine
│   ├── config.py           # Configuration
│   └── powershell_ipc.py   # PowerShell communication
├── build/
│   ├── build.spec          # PyInstaller config
│   ├── build.bat           # Windows build script
│   └── build.sh            # macOS/Linux build script
├── tests/
│   └── (test files here)
├── assets/
│   └── config.ini
├── main.py                 # Entry point
├── requirements.txt        # Python dependencies
└── README.md
```

### Running in Debug Mode

```python
# In config.ini
[DEBUG]
debug_mode=True
show_hitboxes=True
log_level=DEBUG
```

Then run: `python main.py`

### Adding New Animations

1. Update `animation_engine.py` mood_animations dictionary:
```python
mood_animations = {
    Mood.HAPPY: ("happy_bounce", 0.3),
    # Add new:
    Mood.EXCITED: ("excited_jump", 0.4),
}
```

2. Update renderer `_draw_goose()` to handle new animation state

3. Test with keyboard shortcut (SPACE to cycle)

## Cross-Platform Building

### Windows
```bash
build\build.bat
# Output: dist\GooseDesktop\GooseDesktop.exe (~80MB)
```

### macOS
```bash
bash build/build.sh
# Output: dist/GooseDesktop/GooseDesktop (~90MB)
# Code signing optional
```

### Linux
```bash
bash build/build.sh
# Output: dist/GooseDesktop/GooseDesktop (~85MB)
```

## Performance

- **Framerate**: 60 FPS target (configurable)
- **Memory**: ~100-150 MB (minimal overhead)
- **CPU**: <5% idle (scaling with animation complexity)
- **Binary Size**: 80-100 MB (PyInstaller + embedded Python)

## Dependencies

- **PyQt5**: GUI framework
- **NumPy**: Math operations for procedural generation
- **Pillow**: Image handling
- **python-dotenv**: Environment variable support
- **psutil**: System introspection

See `requirements.txt` for exact versions.

## Troubleshooting

### "Python not found"
- Install Python 3.9+
- Add Python to system PATH
- Restart terminal

### "PyQt5 import errors"
```bash
pip install --upgrade PyQt5
```

### PowerShell not found
- Windows: Should be built-in
- macOS/Linux: Install `pwsh` (PowerShell Core)

### Slow animation rendering
- Reduce `render_quality` in config.ini
- Lower `framerate` setting
- Disable `debug_mode`

## Contributing

1. Create feature branch
2. Make changes with tests
3. Submit pull request
4. Ensure cross-platform compatibility

## License

Same as parent Goose Desktop Companion project

## Next Steps

- [ ] Add sprite sheet rendering support
- [ ] Implement GPU acceleration (OpenGL backend)
- [ ] Add sound effects integration
- [ ] Multi-monitor support
- [ ] Settings UI dialog
- [ ] Plugin system for custom animations
