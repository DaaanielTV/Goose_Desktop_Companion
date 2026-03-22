# Architecture - Goose Desktop Companion Python UI Rewrite

Complete technical architecture of the Python + PyQt5 UI layer replacement for the legacy C# WinForms executable.

## Executive Summary

**Goal**: Replace `GooseDesktop.exe` (C# WinForms) with a cross-platform Python + PyQt5 application that:
- Eliminates .NET Framework dependency
- Supports Windows, macOS, and Linux
- Maintains feature parity with original EXE
- Preserves all PowerShell module functionality
- Improves development velocity

**Architecture Pattern**: Layered modular design with clear separation of concerns
- **Presentation Layer**: PyQt5 UI (window, renderer, event handling)
- **Animation Layer**: Procedural animation engine with state machine
- **IPC Layer**: PowerShell cross-process communication
- **Bootstrap Layer**: Configuration and application lifecycle

## System Architecture

```
┌────────────────────────────────────────────────────────────────┐
│                    Goose Desktop Application                    │
│                   (Python + PyQt5 Executable)                  │
└────────────────────────────────────────────────────────────────┘

                              ↓

┌────────────────────────────────────────────────────────────────┐
│                    GooseApplication (app.py)                    │
│  ──────────────────────────────────────────────────────────── │
│  Responsibilities:                                             │
│  • Bootstrap and initialization                               │
│  • Component orchestration                                    │
│  • Lifecycle management                                       │
│  • Error handling                                             │
└────────────────────────────────────────────────────────────────┘

         ↙              ↓              ↘
    
    ┌─────────┐    ┌──────────┐    ┌──────────────┐
    │ Config  │    │ Qt App   │    │ IPC Manager  │
    │ (config)│    │(window.py)    │ (powershell_ │
    └─────────┘    │          │    │ ipc.py)      │
                   │ ┌──────┐ │    └──────────────┘
                   │ │Window│ │
                   │ │(main)│ │
                   │ └──────┘ │
                   │ ┌──────┐ │
                   │ │Render│ │
                   │ │(GPU) │ │
                   │ └──────┘ │
                   │ ┌──────┐ │
                   │ │Anim  │ │
                   │ │Engine│ │
                   │ └──────┘ │
                   └──────────┘

         ↓              ↓              ↓

    ┌─────────────────────────────────────────────┐
    │    PowerShell Core (GooseCore.ps1)          │
    │  + 78+ Feature Modules                      │
    │  ──────────────────────────────────────────│
    │  • All business logic (UNCHANGED)           │
    │  • Feature modules (Productivity, etc.)    │
    │  • State management                        │
    └─────────────────────────────────────────────┘
```

## Component Breakdown

### 1. Bootstrap Layer (`app.py`)

**Class**: `GooseApplication`

**Responsibilities**:
- Parse and load configuration
- Create Qt application instance
- Initialize all subsystems
- Manage application lifecycle
- Error recovery and logging

**Flow**:
```
GooseApplication()
    ├── __init__()
    │   ├── Load config (GooseConfig)
    │   └── Setup logging
    ├── setup()
    │   ├── Create QApplication
    │   ├── Create GooseMainWindow
    │   ├── Initialize AnimationEngine
    │   ├── Start PowerShellIPC
    │   └── Connect signals/slots
    └── run()
        └── qt_app.exec()  # Main event loop
```

**Key Methods**:
- `setup()` - Initialize all components with error handling
- `run()` - Start Qt event loop
- `cleanup()` - Graceful shutdown
- Context manager support (`__enter__`, `__exit__`)

### 2. Configuration Layer (`config.py`)

**Class**: `GooseConfig` (Singleton pattern)

**Responsibilities**:
- Load `config.ini` from parent directories
- Parse and validate settings
- Provide typed config accessors
- Support environment variable overrides
- Set intelligent defaults

**Configuration Sections**:
```ini
[UI]
- window_width, window_height
- always_on_top (boolean)
- framerate (Hz)
- animation_quality (high/medium/low)
- render_quality (scale factor)

[ANIMATION]
- SubtleAnimations (boolean)
- breathing_enabled, blinking_enabled
- breathing_amplitude (pixels)
- breathing_frequency (radians/frame)
- blink_interval, blink_duration (frames)
- animation_speed_multiplier

[POWERSHELL]
- script_path (path to GooseCore.ps1)
- animation_data_polling_interval (ms)
- ipc_timeout (ms)

[DEBUG]
- debug_mode (boolean)
- log_level (INFO, DEBUG, ERROR)
- show_hitboxes (boolean)
```

**Access Pattern**:
```python
config = get_config()  # Singleton
width = config.get_int('UI', 'window_width', 256)
enabled = config.get_bool('ANIMATION', 'breathing_enabled')
```

### 3. Window Layer (`window.py`)

**Class**: `GooseMainWindow` extends `QMainWindow`

**Responsibilities**:
- Create and manage Qt window
- Handle user input (mouse, keyboard)
- Coordinate renderer and animation engine
- Manage animation frame timer
- Implement window interactions

**Event Handlers**:
- `mousePressEvent()` - Enable dragging
- `mouseMoveEvent()` - Drag window
- `mouseReleaseEvent()` - Stop dragging
- `mouseDoubleClickEvent()` - Trigger animation
- `keyPressEvent()` - Keyboard shortcuts
- `closeEvent()` - Cleanup on exit

**Keyboard Shortcuts**:
```
ESC          → Close application
SPACE        → Cycle through moods
Double-click → Trigger happy_bounce animation
Left-drag    → Move window
```

**Animation Loop**:
```
Qt Timer (16ms interval @ 60 Hz)
    ├── AnimationEngine.update(delta_time)
    ├── Get visual state
    ├── Renderer.set_visual_state()
    ├── Request repaint
    └── Repeat
```

### 4. Animation Engine (`animation_engine.py`)

**Classes**:
- `AnimationState` - Immutable animation state dataclass
- `Mood` - Enum of mood states
- `EyeDirection` - Enum of gaze directions
- `AnimationQueueEntry` - Queued animation metadata
- `AnimationEngine` - Core animation processor

**AnimationState Fields**:
```python
position: Tuple[float, float]          # (x, y) pixels
rotation: float                        # degrees
scale: float                          # 0.5-2.0
opacity: float                        # 0.0-1.0
current_animation: str                # animation name
animation_progress: float             # 0.0-1.0
mood: Mood                           # current mood
energy: float                        # 0.3-1.5 multiplier
is_breathing: bool                   # breathing enabled
breathing_offset: float              # calculated offset
eye_direction: EyeDirection          # gaze target
is_blinking: bool                    # eye state
blink_timer: int                     # frame counter
```

**Procedural Animation Algorithms**:

1. **Breathing (Sine Wave)**
   ```python
   offset = sin(frame_count * frequency) * amplitude
   # Default: amplitude=2px, frequency=0.05 rad/frame
   # Result: ±2px vertical oscillation at ~0.8 Hz
   ```

2. **Blinking (Timer)**
   ```python
   if blink_timer > interval:
       is_blinking = True
       blink_timer = 0
   if is_blinking and blink_timer > duration:
       is_blinking = False
   # Default: interval=300 frames (~5 sec), duration=5 frames
   ```

3. **Mood-based Animations**
   ```python
   mood_animations = {
       Mood.HAPPY: ("happy_bounce", 0.3),
       Mood.SLEEPY: ("sleepy_yawn", 1.0),
       Mood.CURIOUS: ("head_tilt", 0.8),
       Mood.STARTLED: ("quick_jump", 0.2),
   }
   ```

**Procedural Generation Functions**:
- `generate_wave_animation()` - Sinusoidal motion paths
- `generate_bounce_animation()` - Physics-based bouncing
- `generate_spiral_animation()` - Spiral paths with expanding radius

**Animation Queue**:
- Flat queue structure (one animation per type)
- Time-based progress tracking
- Automatic expiration on completion
- Can be overwritten with new animation

**Public API**:
- `update(delta_time)` - Called each frame
- `queue_animation(type, duration)` - Queue animation
- `set_mood(mood)` - Change mood and trigger animation
- `set_position(x, y)` - Update goose position
- `get_visual_state()` - Return current state as dict

### 5. Renderer (`renderer.py`)

**Class**: `GooseRenderer` extends `QWidget`

**Responsibilities**:
- Render animated goose sprite to screen
- Handle custom Qt painting
- Implement procedural sprite drawing
- Support mood-based color variations
- Optional debug overlays

**Rendering Pipeline**:
```
paintEvent()
    ├── _render_to_buffer()
    │   ├── Clear buffer (transparent)
    │   ├── Create QPainter
    │   └── _draw_goose()
    │       ├── _draw_goose_body()      # Oval (40x50 px)
    │       ├── _draw_head()             # Circle (36x35 px)
    │       ├── _draw_beak()             # Triangle
    │       └── _draw_eyes()             # Circles + pupils
    └── Draw scaled buffer to screen
```

**Procedural Goose Sprite**:
- No sprite sheets or images required
- Drawn using QPainter shapes (ellipse, polygon, etc.)
- Mood-based color variations
- Blink animation (eye horizontal line)
- Pupil gaze tracking

**Mood Colors**:
```python
{
    'neutral': RGB(100, 150, 200),    # Blue
    'happy': RGB(150, 200, 100),      # Green
    'sleepy': RGB(180, 150, 100),     # Brown
    'curious': RGB(200, 150, 100),    # Orange
    'startled': RGB(200, 100, 100),   # Red
    'content': RGB(120, 180, 120),    # Light green
    'playful': RGB(200, 150, 200),    # Magenta
}
```

**Double-buffering**: Off-screen buffer for smooth animation
- Renders to buffer first
- Then draws scaled buffer to screen
- Eliminates flicker

**Debug Features**:
- Draw hitbox around goose
- Draw center point
- Option to show semi-transparent overlay

**Performance Optimizations**:
- Scale factor control (render_quality)
- Caching of colors
- Minimal shape count
- No complex path operations

### 6. IPC Layer (`powershell_ipc.py`)

**Class**: `PowerShellIPC`

**Responsibilities**:
- Spawn PowerShell subprocess
- Manage subprocess lifecycle
- Coordinate async I/O (stdin/stdout)
- Serialize/deserialize state messages
- Implement callback system

**Subprocess Architecture**:
```
Python Process                PowerShell Process
─────────────────────────────────────────────────────
│                                    │
├─ stdin pipe ──────────────────────→ stdout reader
│                                    │
├─ stdout pipe ←──────────────────── emit "STATE:JSON"
│                                    │
└─ stderr pipe ←──────────────────── Errors/logs
```

**Threading Model**:
```
Main Thread
    ├── PowerShellIPC.start() [blocking init]
    │
    ├── Reader Thread (daemon)
    │   ├── Read from process.stdout
    │   ├── Parse JSON lines
    │   ├── Queue to state_queue
    │   └── Call registered callbacks
    │
    └── Writer Thread (daemon)
        ├── Monitor command_queue
        ├── Write commands to process.stdin
        └── Log sent commands
```

**State Polling Flow**:
```
PowerShell.ps1:
    while ($true) {
        $state = $GooseCore.GetVisualState()
        Write-Host "STATE:$(ConvertTo-Json $state)"
        Start-Sleep -Milliseconds 16  # 60 Hz
    }

Python:
    _read_loop() → Parse JSON → Queue → get_state()
```

**Command Sending Flow**:
```
Python: queue_animation("happy_bounce", 0.3)
    ↓
command_queue.put()
    ↓
_write_loop() reads from queue
    ↓
Write to process.stdin:
    $GooseCore.AnimationEngine.QueueAnimation('happy_bounce', 0.3)
    ↓
PowerShell: Execute command
    ↓
Update internal animation state
```

**Public API**:
- `start()` - Start subprocess and threads
- `stop()` - Cleanup
- `send_command(cmd)` - Send arbitrary command
- `get_state(timeout)` - Retrieve latest state
- `trigger_animation(name, duration)` - Convenience method
- `set_mood(mood)` - Convenience method
- `register_callback(event, fn)` - Register callbacks

**Error Handling**:
- Non-blocking JSON parse failures (logged, continue)
- Process crash detection (logs error)
- Timeout on get_state() returns None
- Invalid commands logged to stderr

## Data Flow

### Initialization Sequence
```
1. main.py: GooseApplication()
2. app.py: setup()
3. config.py: Load config.ini
4. window.py: Create QMainWindow
5. animation_engine.py: Initialize state machine
6. powershell_ipc.py: Spawn subprocess threads
7. window.py: Start animation timer (16ms)
8. Main event loop starts
```

### Animation Frame Sequence (every 16ms @ 60Hz)
```
1. Qt Timer fires _on_animation_update()
2. AnimationEngine.update(delta_time=0.0167)
   ├── frame_count++
   ├── _update_breathing()
   │   └── Calculate sin wave offset
   ├── _update_blinking()
   │   └── Increment blink_timer
   └── _update_animation_queue(delta_time)
       └── Progress queued animations
3. engine.get_visual_state()
   └── Return dict with current state
4. renderer.set_visual_state(state)
5. renderer.update() [requests repaint]
6. Qt calls paintEvent()
7. GooseRenderer._render_to_buffer()
   ├── Clear buffer
   ├── _draw_goose() using state
   └── Draw to screen
```

### PowerShell State Update Sequence (optional async)
```
1. PowerShell subprocess emits: "STATE:{json}"
2. IPC._read_loop() reads from stdout
3. Parse JSON → state dict
4. Queue to state_queue
5. Call registered callbacks
6. (Optional) Python animation updates based on PS state
```

## Communication Protocols

### JSON State Format (PowerShell → Python)
```json
{
  "position": {"x": 100, "y": 100},
  "rotation": 0,
  "scale": 1.0,
  "opacity": 1.0,
  "current_animation": "idle",
  "animation_frame": 0,
  "mood": "neutral",
  "energy": 1.0,
  "vertical_offset": 0.5,
  "is_blinking": false,
  "eye_direction": "forward",
  "animation_queue": ["happy_bounce"]
}
```

### Command Format (Python → PowerShell)
```powershell
# Simple command
$GooseCore.SetMood('happy')

# Animation queue
$GooseCore.AnimationEngine.QueueAnimation('happy_bounce', 0.3)

# Complex command
$GooseCore.SetPosition(150, 200)
```

## Class Diagram

```
┌─────────────────────────────────┐
│      GooseApplication           │
├─────────────────────────────────┤
│ - config: GooseConfig           │
│ - qt_app: QApplication          │
│ - main_window: GooseMainWindow  │
│ - powershell_ipc: PowerShellIPC │
├─────────────────────────────────┤
│ + setup()                       │
│ + run()                         │
│ + cleanup()                     │
└─────────────────────────────────┘
              │
              ├─→ contains ─→ ┌─────────────────────────────────┐
              │               │    GooseConfig                  │
              │               ├─────────────────────────────────┤
              │               │ - config: ConfigParser          │
              │               │ - config_path: Path             │
              │               ├─────────────────────────────────┤
              │               │ + get(section, key)             │
              │               │ + get_bool(...)                 │
              │               │ + get_int(...)                  │
              │               │ + get_float(...)                │
              │               │ + ui_config: property           │
              │               │ + animation_config: property    │
              │               │ + powershell_config: property   │
              │               └─────────────────────────────────┘
              │
              ├─→ creates ──→ ┌─────────────────────────────────┐
              │               │    GooseMainWindow              │
              │               ├─────────────────────────────────┤
              │               │ - renderer: GooseRenderer       │
              │               │ - animation_engine: AnimEngine  │
              │               │ - animation_timer: QTimer       │
              │               │ - config: Dict                  │
              │               ├─────────────────────────────────┤
              │               │ + start_animation_loop()        │
              │               │ + stop_animation_loop()         │
              │               │ + mousePressEvent(...)          │
              │               │ + keyPressEvent(...)            │
              │               │ - _on_animation_update()        │
              │               └─────────────────────────────────┘
              │                      │
              │                      ├─→ contains ─→ ┌──────────────────────────┐
              │                      │               │   GooseRenderer          │
              │                      │               ├──────────────────────────┤
              │                      │               │ - buffer: QImage         │
              │                      │               │ - visual_state: Dict     │
              │                      │               ├──────────────────────────┤
              │                      │               │ + set_visual_state()     │
              │                      │               │ + paintEvent()           │
              │                      │               │ - _render_to_buffer()    │
              │                      │               │ - _draw_goose()          │
              │                      │               │ - _draw_eyes()           │
              │                      │               └──────────────────────────┘
              │                      │
              │                      └─→ contains ─→ ┌──────────────────────────┐
              │                                      │   AnimationEngine        │
              │                                      ├──────────────────────────┤
              │                                      │ - state: AnimationState  │
              │                                      │ - animation_queue: Dict  │
              │                                      │ - frame_count: int       │
              │                                      │ - config: Dict           │
              │                                      ├──────────────────────────┤
              │                                      │ + update(delta_time)     │
              │                                      │ + queue_animation()      │
              │                                      │ + set_mood()             │
              │                                      │ + get_visual_state()     │
              │                                      │ - _update_breathing()    │
              │                                      │ - _update_blinking()     │
              │                                      │ + generate_*_animation() │
              │                                      └──────────────────────────┘
              │
              └─→ creates ──→ ┌─────────────────────────────────┐
                              │    PowerShellIPC                │
                              ├─────────────────────────────────┤
                              │ - process: Popen                │
                              │ - state_queue: Queue            │
                              │ - command_queue: Queue          │
                              │ - _reader_thread: Thread        │
                              │ - _writer_thread: Thread        │
                              │ - callbacks: Dict               │
                              ├─────────────────────────────────┤
                              │ + start()                       │
                              │ + stop()                        │
                              │ + send_command()                │
                              │ + get_state()                   │
                              │ + trigger_animation()           │
                              │ + set_mood()                    │
                              │ + register_callback()           │
                              │ - _read_loop()                  │
                              │ - _write_loop()                 │
                              │ - _start_subprocess()           │
                              └─────────────────────────────────┘
```

## Execution Context

### Process Model
- **Single process** with multiple threads:
  - Main thread: Qt event loop
  - Reader thread: PowerShell stdout polling
  - Writer thread: PowerShell stdin commands
  - Animation thread: (Qt Timer runs on main thread)

### Memory Model
- **Animation State**: ~1-2 KB (dataclass instances)
- **Buffer**: 256×256×4 bytes = 256 KB (render buffer)
- **Queues**: <<1 KB (typically 1-2 entries)
- **Total**: ~100-150 MB (includes Python runtime + PyQt5)

### Timing Model
- **Frame time**: 16.67ms @ 60 Hz
- **Animation update**: <1ms (procedural calculations)
- **Rendering**: <5ms (simple shapes)
- **IPC polling**: ~1ms (async threads)

## Extensibility Points

### Adding New Moods
1. Add to `Mood` enum in animation_engine.py
2. Add animation mapping in `mood_animations`
3. Add color mapping in renderer._draw_goose()

### Adding New Animations
1. Generate motion data with procedural function
2. Queue via `queue_animation()`
3. Update renderer to handle new animation type

### Adding New Procedural Effects
1. Create static method in AnimationEngine
2. Return motion dict or offset values
3. Apply in renderer based on animation_progress

### Custom Rendering
1. Extend GooseRenderer._draw_goose()
2. Add custom drawing methods
3. Reference visual_state for animation parameters

### IPC Extensions
1. Add methods to PowerShellIPC
2. Send commands via send_command()
3. Register callbacks for state updates

## Performance Characteristics

| Metric | Value | Notes |
|--------|-------|-------|
| FPS | 60 | Configurable in config.ini |
| Frame time | 16.67ms | Target per frame |
| CPU (idle) | <5% | Single core usage |
| Memory | 100-150 MB | Including Python runtime |
| Binary size | 80-100 MB | PyInstaller output |
| Startup time | 2-3s | Python + Qt initialization |
| IPC latency | 16ms | One frame @ 60 Hz |

## Security Considerations

1. **PowerShell Execution**: Subprocess runs with user permissions
   - No elevation requested
   - Inherits parent environment
   - Standard input/output limited to JSON

2. **Configuration**: config.ini is plaintext
   - No sensitive data should be stored
   - User-writable after installation
   - Validate all float/int parsesan

3. **IPC Communication**: JSON over pipes
   - No authentication required (same process user)
   - No encryption (local only)
   - Input validation on JSON parsing

## Future Improvements

### Phase 2
- [ ] Sprite sheet rendering support
- [ ] GPU acceleration (OpenGL backend)
- [ ] Multi-monitor detection and placement
- [ ] Persistent window position
- [ ] Custom skin loading from JSON

### Phase 3
- [ ] Settings UI dialog (PyQt5 UI)
- [ ] Sound integration (PyAudio)
- [ ] Plugin system for custom animations
- [ ] Performance profiling tools
- [ ] Crash recovery and logging

### Phase 4
- [ ] Mobile companion app (companion to desktop)
- [ ] Web dashboard for remote control
- [ ] Analytics integration
- [ ] A/B testing framework
- [ ] Advanced gesture recognition

## Migration Guide (C# → Python)

### For C# WinForms Devs:
```csharp
// C#: Window initialization
public partial class GooseForm : Form { ... }

// Python equivalent:
class GooseMainWindow(QMainWindow): ...
```

### For PowerShell Module Devs:
- **No changes required**: All PowerShell modules work unchanged
- IPC now via subprocess instead of in-process API
- Communication is JSON-based state polling

### Porting Strategies:
1. Keep all PowerShell logic intact
2. Replace only rendering layer (.exe)
3. New IPC layer bridges communication
4. Gradual feature parity verification

---

**Document Version**: 2.0.0  
**Last Updated**: 2026-03-22  
**Status**: Complete - Ready for Development
