# Desktop Goose - Enhanced Edition

A lightweight, feature-rich desktop companion that brings a playful goose to your desktop with productivity, wellness, and fun features.

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

## 📋 System Requirements

- Windows operating system
- PowerShell 5.0+
- Minimal system resources required

## 🚀 Installation

1. Download the entire folder to your desired location
2. Run `goose.vbs` to launch the goose silently in the background
   - Alternatively, run `run.bat` for a minimized window launch
   - Or directly execute `GooseDesktop.exe`

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
DesktopGoose/
├── Core/                     # Core systems
│   └── GooseCore.ps1       # Behavior + Context + Animations + Personality
├── Widgets/                 # Desktop widgets
│   ├── ClockWidget.ps1      # Clock
│   ├── WeatherWidget.ps1   # Weather
│   ├── StockTicker.ps1     # NEW: Stock prices
│   └── Calendar.ps1        # NEW: Calendar
├── Productivity/            # Productivity tools
│   ├── Tasks.ps1           # Task management
│   ├── Pomodoro.ps1       # Pomodoro timer
│   ├── TimeBlock.ps1      # NEW: Time blocking
│   ├── TaskIntegration.ps1 # NEW: External task sync
│   └── AIAssistant.ps1    # NEW: AI chatbot
├── System/                  # System integration
│   ├── Clipboard.ps1       # Clipboard manager (enhanced)
│   ├── FileOrganizer.ps1  # NEW: Auto-organize files
│   └── Automation.ps1     # NEW: Automation hub
├── Health/                  # Wellness
│   ├── ScreenTime.ps1      # Screen time
│   ├── EyeStrain.ps1      # NEW: 20-20-20 rule
│   └── Posture.ps1        # NEW: Posture checks
├── Social/                  # Social features
│   ├── PetInteractions.ps1 # Pet interactions
│   └── GooseRPG.ps1       # NEW: RPG progression
├── Fun/                     # Fun features
│   ├── MiniGames.ps1       # Mini games (expanded)
│   ├── ARMode.ps1         # AR camera mode
│   └── CodeAssistant.ps1 # NEW: AI code assistant
├── System/                  # System integration
│   ├── PluginAPI.ps1       # NEW: Plugin system
│   └── Marketplace.ps1    # NEW: Plugin marketplace
├── Health/                  # Wellness
│   └── Learning.ps1       # NEW: Learning system
├── docs/                   # Documentation
│   ├── FEATURES.md        # Feature roadmap
│   ├── ROADMAP.md         # Project roadmap
│   ├── PLUGIN-API.md      # Plugin development
│   ├── MODULES.md         # Module reference
│   └── ARCHITECTURE.md    # Architecture
├── config.ini               # Configuration
├── goose.vbs               # Silent launch
├── run-all.ps1            # Run all modules
├── plugins/               # Plugin directory (NEW)
└── README.md              # This file
```

---

## 🛠️ Development

### Architecture

The Desktop Goose features a modular PowerShell-based architecture:

#### Core Systems
- **Behavior Engine**: Time-based activity modulation
- **Context System**: Real-time environment awareness
- **Animation Framework**: Performance-optimized visuals
- **Personality Core**: Trait development system
- **Wellness Module**: Health and productivity tracking

#### Module Structure
Each module follows a consistent pattern:
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

### Goose doesn't appear
- Ensure `GooseDesktop.exe` is not blocked by antivirus
- Try running as administrator
- Check if process is running in Task Manager

### Configuration not applying
- Ensure `config.ini` is in the same directory as `GooseDesktop.exe`
- Restart the application after making changes
- Check for syntax errors in config file

### Module not working
- Verify the module .ps1 file exists
- Check PowerShell execution policy
- Review module-specific settings in config.ini

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## 🤝 Contributing

Contributions welcome! Please ensure:
- Follow existing module patterns
- Add configuration options to config.ini
- Test modules before submitting

## 📝 Credits

Original Desktop Goose concept by Samperson. Enhanced with new features.

---

**Enjoy your desktop companion! 🦆**
