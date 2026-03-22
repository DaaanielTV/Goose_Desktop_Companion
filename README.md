# 🦆 Desktop Goose - Enhanced Edition

A lightweight, feature-rich desktop companion that brings a playful goose to your desktop with productivity, wellness, and fun features.

---

### 📍 **START HERE** (Choose Your Path)

- 🆕 **New to the project?** → [QUICK_START.md](QUICK_START.md) (2-minute decision tree)
- 🔧 **Want technical details?** → [IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)
- 💻 **Ready to code?** → [goose-ui-python/DEVELOPER.md](goose-ui-python/DEVELOPER.md)

---

> **✨ NEW: Cross-Platform Python UI**  
> The original C# executable has been rewritten in Python + PyQt5 for true cross-platform support (Windows, macOS, Linux). See [goose-ui-python/README.md](goose-ui-python/README.md) for details. The PowerShell module architecture remains unchanged—all features work identically.

**Choose Your Launch Method:**
- 🪟 **Windows (Legacy)**: `run.bat` or `goose.vbs` (C# executable)
- 🆕 **Cross-Platform Modern**: `python main.py` in `goose-ui-python/` (Python/PyQt5)
- 📦 **Standalone**: Build with `goose-ui-python/build/build.bat` (no Python needed)

---

## 🦆 Features

### Core Features
- **Single Goose Instance**: Only one goose spawns on your desktop
- **Multi-Goose Support**: Spawn multiple geese with unique personalities
- **Mood System**: Goose reacts to your behavior and system state
- **App Reactions**: Goose responds to what applications you're using
- **Silent Operation**: No sounds or honks for distraction-free use (configurable)
- **Minimal Resource Usage**: Optimized for performance
- **Modular Architecture**: 78+ modules available

### 🧠 Advanced Desktop Assistant Features

- **Time-Based Behavior**: Goose adapts activity based on work hours and weekends
- **Context Awareness**: Detects meetings, fullscreen apps, and user presence
- **Personality System**: Goose develops unique personality based on interactions
- **Subtle Animations**: Gentle breathing, blinking, and contextual animations
- **Productivity Reminders**: Non-intrusive break, posture, and hydration reminders
- **Learning & Memory**: Remembers user patterns and favorite applications
- **AI Chat Goose**: Chat with your goose using local LLM
- **Code Assistant**: Get code help and reviews from your goose

---

## 🚀 New Features (Phases 1-4)

### Phase 1 - Widgets & Wellness
| Feature | Description |
|---------|-------------|
| **Stock Ticker** | Real-time stock prices via Yahoo Finance API |
| **Calendar Widget** | Interactive monthly calendar with events |
| **Clipboard Manager** | History, pinning, quick-paste with number keys |
| **Eye Strain Prevention** | 20-20-20 rule timer with exercises |

### Phase 2 - Productivity & Organization
| Feature | Description |
|---------|-------------|
| **Time Blocking** | Weekly schedule view with templates |
| **File Organizer** | Auto-categorize downloads by file type |
| **Posture Checks** | Regular posture reminders with exercises |

### Phase 3 - Integration & Automation
| Feature | Description |
|---------|-------------|
| **Task Integration** | Sync with Todoist, Microsoft To-Do, Google Tasks |
| **AI Assistant** | Local chatbot with quick actions |
| **Automation Hub** | Triggers (time, app, clipboard) + actions |

### Phase 4 - Fun & Games
| Feature | Description |
|---------|-------------|
| **Pet Interactions** | Pet, feed, play, teach tricks to the goose |
| **Mini Games** | Whack-a-Goose, Memory Match, Quiz, Word Game, Goose Chase |
| **Multi-Goose Mode** | Spawn multiple geese with different personalities |
| **RPG Progression** | Level up your goose with stats and unlockables |
| **AR Mode** | Camera overlay with face/hand tracking |

### Phase 5 - Community & Extensibility
| Feature | Description |
|---------|-------------|
| **Plugin API** | Create custom plugins with hooks and events |
| **Marketplace** | Download skins, behaviors, and plugins |
| **Streamer Mode** | Twitch chat controls your goose |
| **Multiplayer** | Visit friends with your goose |

### Phase 6 - Crazy Ideas
| Feature | Description |
|---------|-------------|
| **Multiplayer Goose** | Goose invasions and duels |
| **Desktop Memes** | Goose drags memes across screen |
| **Fake Errors** | Goose creates fake error popups |

---

## ☁️ Server-Side Features (Optional)

Desktop Goose kann mit einem Self-Hosted Supabase Backend erweitert werden:

### Phase 4: Plugin & Marketplace
- **Plugin Registry API** - Verwalte Plugins zentral
- **Marketplace Backend** - Lade Skins, Plugins, Themes herunter
- **User Content** - Teile eigene Kreationen

### Phase 5: Multiplayer & Streamer
- **Multiplayer Server** - Besuche Freunde, Nachrichten, Duelle
- **Realtime Sync** - Echtzeit-Kommunikation
- **Streamer Integration** - Twitch/YouTube Webhooks
- **Chaos Events** - Streamer-Chaos auslösen

### Dokumentation

| Dokument | Beschreibung |
|----------|-------------|
| [docs/SERVER-FEATURES.md](docs/SERVER-FEATURES.md) | Server-Übersicht |
| [docs/SERVER-PLUGIN-API.md](docs/SERVER-PLUGIN-API.md) | Plugin API Server |
| [docs/SERVER-MARKETPLACE.md](docs/SERVER-MARKETPLACE.md) | Marketplace Backend |
| [docs/SERVER-MULTIPLAYER.md](docs/SERVER-MULTIPLAYER.md) | Multiplayer Server |
| [docs/SERVER-STREAMER.md](docs/SERVER-STREAMER.md) | Streamer Integration |
| [docs/backend-setup.md](docs/backend-setup.md) | Backend Setup |

---

## 📋 System Requirements

### C# Desktop EXE (Original)
- Windows 10+ operating system
- PowerShell 5.0+
- .NET Framework (usually pre-installed)
- Minimal system resources

### Python UI (NEW - Recommended)
- **Windows 10+, macOS 10.13+, or Linux** (Ubuntu 18.04+)
- Python 3.9+ (for development)
- Or: Pre-built standalone executable (no installation needed)
- Minimal system resources (~100-150 MB)

## 🚀 Installation

### Option 1: Python UI (Recommended - Cross-Platform) ⭐

**Fastest way** (5 minutes):
```bash
cd goose-ui-python
python -m venv venv
# Windows:
venv\Scripts\activate
# macOS/Linux:
source venv/bin/activate

pip install -r requirements.txt
python main.py
```

**Build standalone executable** (no Python needed):
```bash
# Windows
build\build.bat
# Output: dist\GooseDesktop\GooseDesktop.exe (~80 MB)

# macOS/Linux
bash build/build.sh
# Output: dist/GooseDesktop/GooseDesktop (~85-90 MB)
```

See [goose-ui-python/SETUP.md](goose-ui-python/SETUP.md) for detailed setup, troubleshooting, and advanced configuration.

### Option 2: Original C# EXE (Windows Only)

1. Download the entire folder to your desired location
2. Run `goose.vbs` to launch the goose silently in the background
   - Alternatively, run `run.bat` for a minimized window launch
   - Or directly execute `GooseDesktop.exe`

> **⚠️ Antivirus Warning**
> 
> Some antivirus programs may flag GooseDesktop as a potential threat (currently detected by ~6/72 security vendors as `pua.goosedesktop/joke` or similar).
> 
> **Important:** The original executable (`GooseDesktop.exe`) is not open source. The new **Python UI is fully open source** and can be inspected for security.
> 
> If your antivirus blocks GooseDesktop:
> - Try the **Python UI version instead** (fully open source)
> - Add an exclusion for the GooseDesktop folder
> - Report the false positive to your antivirus vendor
> - Check the [VirusTotal report](https://www.virustotal.com/gui/file/943fd1ea44266c5d7fa02f2b292db095a4e6ba8027a1f6c73fd60d1165e63aff)

## ⚙️ Configuration

The goose behavior can be customized by editing `config.ini`:

### Basic Configuration
```ini
Version_DoNotEdit=1
EnableMods=False
SilenceSounds=True
Task_CanAttackMouse=True
AttackRandomly=False
UseCustomColors=False
GooseDefaultWhite=#ffffff
GooseDefaultOrange=#ffa500
GooseDefaultOutline=#d3d3d3
MinWanderingTimeSeconds=20
MaxWanderingTimeSeconds=40
FirstWanderTimeSeconds=20
```

### Phase 1 - Widgets Configuration
```ini
# Stock Ticker
StockTickerEnabled=False
StockSymbols=AAPL,GOOGL,MSFT
StockRefreshMinutes=5

# Calendar Widget
CalendarEnabled=False
CalendarShowWeekNumbers=True

# Clipboard Manager
ClipboardManagerEnabled=False
ClipboardHistoryLimit=50

# Eye Strain Prevention
EyeStrainEnabled=False
EyeStrainIntervalMinutes=20
```

### Phase 2 - Productivity Configuration
```ini
# Time Blocking
TimeBlockEnabled=False
TimeBlockDefaultDuration=30

# File Organizer
FileOrganizerEnabled=False
FileOrganizerWatchFolders=%USERPROFILE%\Downloads

# Posture Checks
PostureEnabled=False
PostureCheckIntervalMinutes=30
```

### Phase 3 - Integration Configuration
```ini
# Task Integration
TaskIntegrationEnabled=False
TaskProvider=todoist
TaskApiKey=your-api-key

# AI Assistant
AIAssistantEnabled=False
AIResponseStyle=helpful

# Automation Hub
AutomationEnabled=False
```

### Phase 4 - Fun Configuration
```ini
# Pet Interactions
PetInteractionsEnabled=False

# Mini Games
MiniGamesEnabled=False

# AR Mode
ARModeEnabled=False
ARFaceTracking=False

# Multi-Goose Mode
MultiGooseEnabled=False
MaxGooseCount=3

# RPG Progression
RPGEnabled=False
AutoSaveXP=True
```

### Phase 5 - Community Configuration
```ini
# Plugin API
PluginAPIEnabled=False
PluginDirectory=plugins

# Marketplace
MarketplaceEnabled=False

# Streamer Mode
StreamerModeEnabled=False
TwitchChannel=

# Multiplayer
MultiplayerEnabled=False
```

### Phase 6 - Crazy Features
```ini
# Desktop Memes
MemeDragEnabled=False

# Fake Errors
FakeErrorEnabled=False

# Voice Honks
VoiceHonksEnabled=False
```

---

## 🎮 Usage

Once launched, the goose will appear on your desktop and:

### Basic Behavior
- Wander around your screen
- Occasionally interact with your mouse cursor (if enabled)
- Provide a delightful desktop companion experience

### Using New Features

#### Stock Ticker
```powershell
# Add a stock symbol
Add-StockSymbol -Symbol "AAPL"

# Refresh stock data
Refresh-StockData

# Get current quotes
Get-StockDisplayData
```

#### Calendar
```powershell
# Add an event
Add-CalendarEvent -Title "Meeting" -Date (Get-Date).AddDays(1) -Time "14:00"

# Get today's events
Get-EventsForDate -Date (Get-Date)
```

#### Clipboard Manager
```powershell
# Get clipboard history
Get-ClipboardHistory -Count 10

# Pin an item
Pin-ClipboardItem -ItemId "item-id"

# Quick paste (press 1-9)
Quick-Paste -Number 1
```

#### Eye Strain Prevention
```powershell
# Start the timer
Enable-EyeStrain

# Take a break
Take-Break

# Get stats
Get-EyeStrainStats
```

#### Time Blocking
```powershell
# Add a time block
Add-TimeBlock -StartTime "2026-03-15T09:00:00" -DurationMinutes 60 -Title "Deep Work"

# Get today's blocks
Get-TodayBlocks
```

#### Pet Interactions
```powershell
# Pet the goose
Pet-Goose

# Feed the goose
Feed-Goose -FoodType "bread"

# Play with the goose
Play-Goose -Toy "ball"

# Teach a trick
Teach-Trick -TrickName "sit"
```

#### Mini Games
```powershell
# Start a game
Start-MiniGame -GameName "whack_goose"

# End with score
End-MiniGame -GameName "whack_goose" -Score 15
```

---

## 📁 File Structure

```
Goose_Desktop_Companion/
├── goose-ui-python/            # 🆕 NEW: Cross-platform Python UI (RECOMMENDED)
│   ├── src/
│   │   ├── app.py              # Application orchestrator
│   │   ├── window.py           # PyQt5 main window
│   │   ├── animation_engine.py # Procedural animations
│   │   ├── renderer.py         # Goose sprite rendering
│   │   ├── config.py           # Configuration
│   │   └── powershell_ipc.py   # PowerShell communication
│   ├── build/
│   │   ├── build.spec          # PyInstaller config
│   │   ├── build.bat           # Windows build
│   │   └── build.sh            # macOS/Linux build
│   ├── main.py                 # Entry point
│   ├── requirements.txt        # Python dependencies
│   ├── README.md               # Python UI docs
│   ├── SETUP.md                # Setup guide
│   ├── ARCHITECTURE.md         # Technical design
│   ├── DEVELOPER.md            # Dev guide
│   └── PROJECT_MANIFEST.md     # Project summary
│
├── Core/                       # Core systems
│   └── GooseCore.ps1          # Behavior + Context + Animations + Personality
├── Widgets/                    # Desktop widgets
│   ├── ClockWidget.ps1        # Clock
│   ├── WeatherWidget.ps1      # Weather
│   ├── StockTicker.ps1        # Stock prices
│   └── Calendar.ps1           # Calendar
├── Productivity/              # Productivity tools
│   ├── Tasks.ps1              # Task management
│   ├── Pomodoro.ps1          # Pomodoro timer
│   ├── TimeBlock.ps1         # Time blocking
│   ├── TaskIntegration.ps1   # External task sync
│   └── AIAssistant.ps1       # AI chatbot
├── System/                    # System integration
│   ├── Clipboard.ps1         # Clipboard manager
│   ├── FileOrganizer.ps1    # Auto-organize files
│   └── Automation.ps1       # Automation hub
├── Health/                    # Wellness
│   ├── ScreenTime.ps1        # Screen time
│   ├── EyeStrain.ps1        # 20-20-20 rule
│   └── Posture.ps1          # Posture checks
├── Social/                    # Social features
│   ├── PetInteractions.ps1   # Pet interactions
│   └── GooseRPG.ps1         # RPG progression
├── Fun/                       # Fun features
│   ├── MiniGames.ps1          # Mini games
│   ├── ARMode.ps1            # AR camera mode
│   └── CodeAssistant.ps1    # AI code assistant
├── docs/                      # Documentation
│   ├── ARCHITECTURE.md        # Architecture
│   ├── FEATURES.md           # Features
│   ├── ROADMAP.md            # Roadmap
│   ├── MODULES.md            # Module reference
│   ├── PLUGIN-API.md         # Plugin API
│   ├── API-REFERENCE.md      # API reference
│   ├── SERVER-FEATURES.md    # Server features
│   ├── SERVER-PLUGIN-API.md  # Server plugin API
│   ├── SERVER-MARKETPLACE.md # Marketplace
│   ├── SERVER-MULTIPLAYER.md # Multiplayer
│   ├── SERVER-STREAMER.md    # Streamer mode
│   └── backend-setup.md      # Backend setup
├── config.ini                # Configuration
├── goose.vbs                 # Silent launch (C# EXE)
├── run.bat                   # Run C# EXE
├── run-all.bat              # Run all modules
├── run-all.ps1              # PowerShell runner
├── LICENSE                  # MIT License
└── README.md                # This file
```

---

## 🛠️ Development & Architecture

### UI Layer Architecture

Desktop Goose now offers **two rendering options**:

#### 1. Python UI Layer (NEW - Recommended) ⭐

**Location**: `goose-ui-python/`

- **Technology**: Python 3.9+ | PyQt5 5.15
- **Platform**: Windows, macOS, Linux
- **Features**:
  - ✅ Cross-platform compiled binary (single executable)
  - ✅ Procedural animation engine (breathing, blinking, 7 moods)
  - ✅ Transparent window with dragging
  - ✅ JSON-based PowerShell IPC communication
  - ✅ Hot-reload architecture (no rebuild needed)
  - ✅ No redistributables required
  - ✅ Fully open source

**Documentation**:
- [goose-ui-python/README.md](goose-ui-python/README.md) - Overview & quick start
- [goose-ui-python/ARCHITECTURE.md](goose-ui-python/ARCHITECTURE.md) - Technical design deep-dive
- [goose-ui-python/DEVELOPER.md](goose-ui-python/DEVELOPER.md) - Development guide & extensions
- [goose-ui-python/SETUP.md](goose-ui-python/SETUP.md) - Setup & troubleshooting
- [goose-ui-python/PROJECT_MANIFEST.md](goose-ui-python/PROJECT_MANIFEST.md) - Complete implementation details

**Project Structure**:
```
goose-ui-python/
├── src/
│   ├── app.py              # Application orchestrator
│   ├── window.py           # PyQt5 main window (mouse, keyboard, events)
│   ├── animation_engine.py # Procedural animations (1600+ lines)
│   ├── renderer.py         # Goose sprite rendering (procedural)
│   ├── config.py           # Configuration management
│   └── powershell_ipc.py   # PowerShell subprocess IPC
├── build/
│   ├── build.spec          # PyInstaller configuration
│   ├── build.bat           # Windows build script
│   └── build.sh            # macOS/Linux build script
├── assets/
│   └── config.ini          # Configuration file
├── main.py                 # Entry point
├── requirements.txt        # Python dependencies
└── [Documentation files]
```

#### 2. C# WinForms EXE (Original - Windows Only)

**Legacy option** for Windows-only deployment. See below for details.

---

### PowerShell Core Architecture

The business logic lives entirely in PowerShell modules (unchanged by UI layer choice):

#### PowerShell Core Systems

The business logic lives entirely in PowerShell modules (independent of UI choice):

- **Behavior Engine**: Time-based activity modulation
- **Context System**: Real-time environment awareness
- **Animation Framework**: Procedural animation support (breathing, blinking, moods)
- **Personality Core**: Trait development system
- **Wellness Module**: Health and productivity tracking
- **78+ Feature Modules**: Productivity, health, fun, social, media, widgets
  - All feature identically regardless of UI renderer (C# or Python)

#### Module Structure

Each PowerShell module follows a consistent pattern:

```powershell
class Goose[ModuleName] {
    [hashtable]$Config
    # ... properties
    
    # Configuration loading
    [hashtable] LoadConfig() { ... }
    
    # Data persistence
    [void] LoadData() { ... }
    [void] SaveData() { ... }
    
    # Core functionality
    [returnType] MethodName() { ... }
    
    # State
    [hashtable] GetModuleState() { ... }
}

# Singleton instance
$gooseModule = [GooseModule]::new()

# Export functions
function Get-GooseModule { return $gooseModule }
function Do-Something { param($Module = $gooseModule) ... }
```

**UI Layer Agnostic**: All PowerShell modules work identically whether using the Python UI or C# EXE. The UI is a thin rendering layer only. Module developers never need to worry about UI implementation.

#### Configuration
All modules load settings from `config.ini`:
- Boolean values: `True`/`False`
- Integer values: Numbers
- String values: Text

#### Data Storage
- JSON files for persistent data
- Named after module: `goose_[module].json`

### Design Philosophy
- **Non-Intrusive**: Features enhance without disrupting workflow
- **Adaptive Intelligence**: Learns from user patterns
- **Performance First**: Minimal resource usage
- **Privacy Respecting**: Local data storage
- **Professional Friendly**: Workplace appropriate

---

## 🔧 Troubleshooting

### Python UI Issues

For issues with the Python UI version, see [goose-ui-python/SETUP.md](goose-ui-python/SETUP.md) troubleshooting section:
- ModuleNotFoundError for dependencies
- Window not appearing
- Animation stuttering
- PowerShell communication errors

### C# EXE Issues

**Goose doesn't appear**
- Ensure `GooseDesktop.exe` is not blocked by antivirus
- Try running as administrator
- Check if process is running in Task Manager

**Configuration not applying**
- Ensure `config.ini` is in the same directory as `GooseDesktop.exe`
- Restart the application after making changes
- Check for syntax errors in config file

**Module not working**
- Verify the module .ps1 file exists
- Check PowerShell execution policy
- Review module-specific settings in config.ini

---

## 📚 Documentation Index

### Getting Started
- 🆕 **[goose-ui-python/README.md](goose-ui-python/README.md)** - Python UI quick start
- 🆕 **[goose-ui-python/SETUP.md](goose-ui-python/SETUP.md)** - Installation & setup

### Technical Documentation
- 🆕 **[goose-ui-python/ARCHITECTURE.md](goose-ui-python/ARCHITECTURE.md)** - Python UI design (300+ lines)
- 🆕 **[goose-ui-python/DEVELOPER.md](goose-ui-python/DEVELOPER.md)** - Development guide
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - PowerShell core architecture
- **[docs/MODULES.md](docs/MODULES.md)** - Module reference

### Features & Design
- **[docs/FEATURES.md](docs/FEATURES.md)** - Feature overview
- **[docs/ROADMAP.md](docs/ROADMAP.md)** - Project roadmap
- **[docs/API-REFERENCE.md](docs/API-REFERENCE.md)** - PowerShell API

### Advanced
- **[docs/PLUGIN-API.md](docs/PLUGIN-API.md)** - Plugin development
- **[docs/SERVER-FEATURES.md](docs/SERVER-FEATURES.md)** - Server-side features
- **[docs/backend-setup.md](docs/backend-setup.md)** - Backend setup

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

Contributions welcome! 

### For PowerShell Module Developers

Add new features to the 78+ existing modules:
- Follow existing module patterns
- Add configuration options to config.ini
- Test modules before submitting
- No need to worry about UI implementation—works with both C# and Python UI

### For UI/Renderer Developers

**Python UI** (recommended for new features):
- See [goose-ui-python/DEVELOPER.md](goose-ui-python/DEVELOPER.md)
- Extend animation engine, rendering, or configuration
- Cross-platform testing on Windows, macOS, Linux
- 300+ lines of architecture documentation provided

**C# EXE**: 
- Original codebase not open source
- Consider contributing to Python UI instead for visibility

### General Guidelines
- Keep PowerShell logic separate from UI layer
- Test cross-platform compatibility
- Update documentation with changes
- Add examples for new features

## 📝 Credits

Original Desktop Goose concept by Samperson. Enhanced with new features.

---

**Enjoy your desktop companion! 🦆**
