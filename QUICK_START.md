# 🦆 Quick Start Guide - Goose Desktop Companion

**Choose your path below:**

---

## 🆕 I'm new - What should I do?

**Start with the Python UI (recommended):**
```bash
cd goose-ui-python
python main.py
```

See [goose-ui-python/SETUP.md](goose-ui-python/SETUP.md) for 5-minute setup.

---

## 🪟 I use Windows only and want the original

```bash
run.bat
# or
goose.vbs
```

---

## 💻 I want to develop/extend features

### Adding PowerShell Modules

All 78+ modules work with **both** C# and Python UI. Start here:

1. Study existing module in `Productivity/`, `Health/`, `Fun/` folders
2. Follow the PowerShell class pattern
3. Add config.ini entries
4. Test with either UI

**No UI knowledge required!** The UI is a thin rendering layer only.

### Adding Python UI Features

For rendering, UI, or animation improvements:

1. See [goose-ui-python/DEVELOPER.md](goose-ui-python/DEVELOPER.md)
2. Study [goose-ui-python/ARCHITECTURE.md](goose-ui-python/ARCHITECTURE.md)
3. Extend animation_engine.py, renderer.py, config.py
4. Build with `goose-ui-python/build/build.bat`

---

## 📱 I need cross-platform (Mac/Linux)

**Only option**: Python UI
```bash
cd goose-ui-python
python main.py
```

Build standalone:
```bash
bash build/build.sh  # macOS/Linux
```

---

## 📦 I want a standalone .exe (no Python)

**Build the Python UI**:
```bash
cd goose-ui-python
build\build.bat
# Creates: dist\GooseDesktop\GooseDesktop.exe (~80 MB, no Python needed)
```

---

## 🎯 Quick Reference

| Need | Solution | Time |
|------|----------|------|
| Try it out | `cd goose-ui-python && python main.py` | 5 min |
| Windows legacy | `run.bat` | 1 min |
| Build standalone | `cd goose-ui-python && build\build.bat` | 5 min |
| Add feature | Create `.ps1` in `Productivity/`, `Health/`, `Fun/` | 30 min |
| Customize animations | Edit `goose-ui-python/src/animation_engine.py` | 15 min |
| Deploy on Mac | `cd goose-ui-python && bash build/build.sh` | 5 min |

---

## 📚 Documentation

**Quick Reads:**
- [goose-ui-python/README.md](goose-ui-python/README.md) - Python UI overview
- [goose-ui-python/SETUP.md](goose-ui-python/SETUP.md) - Getting started

**Deep Dives:**
- [goose-ui-python/ARCHITECTURE.md](goose-ui-python/ARCHITECTURE.md) - Design & internals
- [goose-ui-python/DEVELOPER.md](goose-ui-python/DEVELOPER.md) - Extending features
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) - PowerShell core design
- [docs/MODULES.md](docs/MODULES.md) - Module reference

---

## ❓ Troubleshooting

**Window won't appear?**
→ See [goose-ui-python/SETUP.md#troubleshooting](goose-ui-python/SETUP.md#troubleshooting)

**Animation stuttering?**
→ Lower `framerate` in `goose-ui-python/assets/config.ini`

**Antivirus blocking?**
→ Use Python UI (fully open source, inspectable)

---

## 🎨 Feature Comparison

| Feature | C# EXE | Python UI |
|---------|--------|-----------|
| Windows | ✅ | ✅ |
| macOS | ❌ | ✅ |
| Linux | ❌ | ✅ |
| Open source | ❌ | ✅ |
| No redistributables | ❌ | ✅ |
| Animation moods | ✅ | ✅ (enhanced) |
| Configuration | ✅ | ✅ |
| All 78+ modules | ✅ | ✅ |

---

**Happy Goosing! 🦆**
