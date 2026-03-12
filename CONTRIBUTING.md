# Contributing to Desktop Goose

Thank you for your interest in contributing! This document will help you get started.

## Project Overview

Desktop Goose is a Windows desktop companion application. The core executable (`GooseDesktop.exe`) is closed-source, but the project extends functionality through:

- **PowerShell Modules** - Feature implementations in `*.ps1` files (organized by category)
- **Configuration** - `config.ini` for runtime settings
- **Modding API** - `GooseModdingAPI.dll` for mod support

## Architecture

```
DesktopGoose/
├── Core/                   # Core systems
│   └── GooseCore.ps1     # Unified core (Behavior + Context + Animations + Personality + Productivity)
├── Widgets/                # Desktop widgets
├── Productivity/           # Productivity tools
├── System/                 # System integration
├── Features/               # Extended features
├── Fun/                    # Fun features
├── Health/                 # Wellness & health
├── UI/                     # User interface
├── Social/                 # Social features
├── Media/                  # Media integration
├── Office/                 # Office integration
├── Tools/                  # Tools
├── Status/                 # Status monitoring
├── Special/                # Special features
├── docs/                   # Documentation
│   ├── MODULES.md        # Module reference
│   └── ARCHITECTURE.md   # Architecture overview
└── Assets/                 # Images and sounds
```

### Core System

The unified core system (`Core/GooseCore.ps1`) combines five subsystems:

| Subsystem | Purpose |
|-----------|---------|
| `GooseBehavior` | Time-based activity, work/weekend detection |
| `GooseContext` | Meeting detection, fullscreen, user presence |
| `GooseAnimations` | Visual states, mood, breathing, blinking |
| `GoosePersonality` | Interaction tracking, trait development |
| `GooseProductivity` | Wellness reminders, break prompts |

## Development Setup

1. Clone the repository
2. Ensure PowerShell 5.1+ is installed (Windows built-in)
3. Review `config.ini` for available options
4. Run `goose.vbs` or `run.bat` to launch

## Creating a New Module

### Option 1: Standalone Module (Legacy)

Follow this pattern:

```powershell
# Category/MyFeature.ps1

class GooseMyFeature {
    [hashtable]$Config
    [hashtable]$State
    
    GooseMyFeature() {
        $this.Config = $this.LoadConfig()
        $this.State = @{}
    }
    
    [hashtable] LoadConfig() {
        $config = @{}
        $configFile = "config.ini"
        
        if (Test-Path $configFile) {
            Get-Content $configFile | ForEach-Object {
                if ($_ -match '^([^=]+)=(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    
                    if ($value -eq 'True' -or $value -eq 'False') {
                        $config[$key] = [bool]$value
                    } elseif ($value -match '^\d+$') {
                        $config[$key] = [int]$value
                    } elseif ($value -match '^\d+\.\d+$') {
                        $config[$key] = [double]$value
                    } else {
                        $config[$key] = $value
                    }
                }
            }
        }
        
        return $config
    }
    
    # Add your feature methods here
}

$gooseMyFeature = [GooseMyFeature]::new()

function Get-GooseMyFeature { return $gooseMyFeature }
function Do-Something {
    param($Feature = $gooseMyFeature)
    # implementation
}
```

### Option 2: Integrate with Core

```powershell
# Import core
. "$PSScriptRoot\Core\GooseCore.ps1"

# Access core systems
$core = Get-GooseCore
$behavior = $core.Behavior
$context = $core.Context.GetContext()

# Add custom logic
function Get-MyFeatureData {
    param($Core = (Get-GooseCore))
    # Use Core.Animations, Core.Personality, etc.
    return @{}
}
```

## Code Style

- Use **PowerShell classes** for new modules
- Prefix functions with `Get-`, `Set-`, `Update-`, `Should-`, `Is-`
- Use `$this.Config` to access settings from `config.ini`
- Return **hashtables** for complex data
- Use `[hashtable] LoadConfig()` or reuse `GooseConfig::Load()` for config

## Configuration

Add new options to `config.ini`:

```ini
# Category
FeatureName=False
FeatureSetting=default_value
```

Access in code:

```powershell
if ($this.Config["FeatureName"]) {
    # Feature enabled
}
```

## Testing

Run the test script:

```powershell
.\test-goose-features.ps1
```

Or test individual modules:

```powershell
. .\Core\GooseCore.ps1
```

## Module Categories

Place new modules in the appropriate folder:

| Category | Folder | Examples |
|----------|--------|----------|
| Desktop Widgets | `Widgets/` | Clock, Weather, StockTicker, Calendar |
| Productivity | `Productivity/` | Tasks, Notes, Focus, TimeBlock, TaskIntegration, AIAssistant |
| System | `System/` | Battery, Volume, Clipboard, FileOrganizer, Automation |
| Features | `Features/` | Settings, Hotkeys, Sync |
| Fun | `Fun/` | Commands, Honk, MiniGames, ARMode |
| Health | `Health/` | Workout, Habits, ScreenTime, EyeStrain, Posture |
| UI | `UI/` | Tray, Stats |
| Social | `Social/` | Gamification, Leaderboard, PetInteractions |
| Media | `Media/` | PhotoFrame, Music |
| Office | `Office/` | Meeting, Journal |
| Tools | `Tools/` | FileFeeder, MultiMonitor |
| Status | `Status/` | SleepWake, Particles |
| Special | `Special/` | Weather, Seasonal |

## Documentation

- [Module Reference](docs/MODULES.md) - All available modules
- [Architecture](docs/ARCHITECTURE.md) - System design
- [Developer Guide](docs/DEVELOPER.md) - How to create modules
- [API Reference](docs/API-REFERENCE.md) - Function documentation

## Pull Request Guidelines

1. Test your changes locally
2. Follow the code style above
3. Update documentation if adding features
4. Keep changes focused and minimal

## Additional Resources

- Original Desktop Goose: https://samperson.itch.io/desktop-goose
- PowerShell Docs: https://docs.microsoft.com/powershell/
