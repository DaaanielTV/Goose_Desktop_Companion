# Setup Instructions - Goose Desktop Companion Python UI

Quick start guide for developers setting up the new Python UI environment.

## 🚀 Quick Start (5 minutes)

### 1. Windows

```bash
# Open Command Prompt or PowerShell in the goose-ui-python folder

# Create virtual environment
python -m venv venv
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt

# Run the application
python main.py
```

### 2. macOS / Linux

```bash
# Open Terminal in the goose-ui-python folder

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Run the application
python main.py
```

## 📦 Building Standalone Executable

### Windows
```bash
# Build is automated - just run:
build\build.bat

# Executable created: dist\GooseDesktop\GooseDesktop.exe
```

### macOS / Linux
```bash
# Build is automated - just run:
bash build/build.sh

# Executable created: dist/GooseDesktop/GooseDesktop
```

## ✅ Verification Checklist

After setup, verify everything works:

- [ ] Window appears with animated goose
- [ ] Window is draggable (mouse)
- [ ] Double-click triggers animation
- [ ] Press SPACE cycles through moods
- [ ] Goose changes color based on mood
- [ ] No errors in terminal output
- [ ] (Optional) Check config.ini is loaded

## 🔧 Configuration

Edit `assets/config.ini` to customize:

```ini
[UI]
window_width=256          # Window size
framerate=60              # Animation FPS

[ANIMATION]
SubtleAnimations=True     # Enable/disable animations
breathing_amplitude=2     # Breathing intensity

[DEBUG]
debug_mode=False          # Enable debug output
log_level=INFO            # Logging level
```

## 🐛 Troubleshooting

### "ModuleNotFoundError: No module named 'PyQt5'"
```bash
# Ensure venv is activated, then:
pip install --upgrade PyQt5
```

### "Window doesn't appear"
- Check if `always_on_top` is True in config.ini
- On some Linux DMs, try disabling with-compose
- Verify no Python errors in terminal

### "PowerShell not found" (macOS/Linux)
```bash
# Install PowerShell Core
# macOS:
brew install powershell

# Linux:
sudo snap install powershell --classic
```

### Animation is slow/stuttering
- Lower `framerate` in config.ini (e.g., 30 instead of 60)
- Reduce `render_quality` to 1 (was 2)
- Close other applications using GPU

## 📁 Project Structure

```
goose-ui-python/
├── src/
│   ├── app.py              ← Start here
│   ├── window.py           ← UI layer
│   ├── animation_engine.py ← Animation logic
│   ├── renderer.py         ← Graphics
│   ├── config.py           ← Settings
│   └── powershell_ipc.py   ← Communication
├── build/
│   ├── build.bat/build.sh  ← Build scripts
│   └── build.spec          ← PyInstaller config
├── main.py                 ← Entry point
├── requirements.txt        ← Dependencies
├── README.md               ← Overview
├── DEVELOPER.md            ← Dev guide
├── ARCHITECTURE.md         ← Technical design
└── assets/
    └── config.ini          ← Configuration
```

## 🎯 Common Tasks

### Run in development mode
```bash
python main.py
```

### Run with debug output
```ini
# Edit config.ini:
[DEBUG]
debug_mode=True
log_level=DEBUG
```

### Run tests
```bash
pytest tests/ -v
```

### Format code
```bash
black src/ tests/
```

### Check code quality
```bash
flake8 src/
```

## 📚 Documentation

- **README.md** - Overview and features
- **ARCHITECTURE.md** - Technical design details
- **DEVELOPER.md** - Extended dev guide
- **Code comments** - Inline documentation throughout

## 🚦 Next Steps

1. ✅ Setup complete - you can now run `python main.py`
2. 📖 Read DEVELOPER.md for extending the application
3. 🧪 Check tests/ for example usage
4. 🎨 Customize animations in animation_engine.py
5. 🏗️ Build executable with `build.bat` or `build.sh`

## 💬 Need Help?

- Check troubleshooting section above
- Review DEVELOPER.md for detailed guidance
- Run with `debug_mode=True` for verbose output
- Check terminal output for error messages

---

**Happy coding! 🦆**
