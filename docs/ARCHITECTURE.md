# Architecture Overview

## Project Structure

```
DesktopGoose/
├── Core/               # Core systems
├── Widgets/            # Desktop widgets (6 modules)
├── Productivity/       # Productivity tools (11 modules)
├── System/            # System integration (12 modules)
├── Features/          # Extended features (9 modules)
├── Fun/               # Fun features (7 modules)
├── Health/            # Wellness & health (6 modules)
├── UI/                # User interface (3 modules)
├── Social/            # Social features (6 modules)
├── Media/             # Media integration (3 modules)
├── Office/            # Office integration (3 modules)
├── Tools/             # Tools (4 modules)
├── Status/            # Status monitoring (3 modules)
├── Special/          # Special features (4 modules)
├── docs/              # Documentation
└── Assets/            # Images & sounds
```

## Core System (GooseCore.ps1)

The core system combines 5 subsystems:

### 1. GooseBehavior
- Time-based activity control
- Work hours/weekend detection
- Meeting quiet mode
- Activity level calculation

### 2. GooseContext
- Context recognition (time of day, weekday)
- Active application detection
- Fullscreen/meeting detection
- User activity tracking

### 3. GooseAnimations
- Mood-based animations
- Breathing/blinking effects
- Animation queue system
- Contextual animations

### 4. GoosePersonality
- Personality traits (0.0-1.0)
- Interaction history
- Trust/happiness tracking
- Personality type determination

### 5. GooseProductivity
- Work time tracking
- Break reminders
- Productivity statistics
- Wellness warnings

## New Features Architecture

### Phase 1: Widgets & Wellness

#### Stock Ticker (Widgets/goose-stockticker.ps1)
- Yahoo Finance API integration
- Real-time price updates
- Configurable refresh interval

#### Calendar Widget (Widgets/goose-calendar.ps1)
- Monthly calendar view
- Event CRUD operations
- Week number display

#### Clipboard Manager (System/goose-clipboard.ps1)
- History with 50 item limit
- Pin important clips
- Quick paste (keys 1-9)
- Type categorization

#### Eye Strain Prevention (Health/goose-eyestrain.ps1)
- 20-20-20 rule timer
- Break exercises
- Daily statistics

### Phase 2: Productivity & Organization

#### Time Blocking (Productivity/goose-timeblock.ps1)
- Weekly calendar view
- Time block templates
- Current/upcoming blocks

#### File Organizer (System/goose-fileorganizer.ps1)
- File type rules
- Auto-categorization
- Scheduled runs

#### Posture Checks (Health/goose-posture.ps1)
- Periodic reminders
- Exercise suggestions
- Daily score

### Phase 3: Integration & Automation

#### Task Integration (Productivity/goose-taskintegration.ps1)
- Todoist API
- Microsoft To-Do API
- Google Tasks API

#### AI Assistant (Productivity/goose-aiassistant.ps1)
- Message processing
- Quick actions
- Conversation history

#### Automation Hub (System/goose-automation.ps1)
- Time triggers
- App launch triggers
- Clipboard triggers
- Multiple action types

### Phase 4: Fun & Games

#### Pet Interactions (Social/goose-petinteractions.ps1)
- Pet/feed/play commands
- Trick teaching
- Mood system

#### Mini Games (Fun/goose-minigames.ps1)
- Whack-a-Goose
- Memory Match
- Quiz
- Word Game

#### AR Mode (Fun/goose-armode.ps1)
- Camera session
- Snapshot capture
- Face/hand tracking

## Data Flow

```
config.ini → [LoadConfig]
                   ↓
            [GooseCore]
                   ↓
      ┌────────────┼────────────┐
      ↓            ↓            ↓
Behavior    Context    Animations
      ↓            ↓            ↓
      └────────────┼────────────┘
                   ↓
             Personality
                   ↓
              Productivity
                   ↓
           GetFullState() → UI
```

## Configuration

All modules read settings from `config.ini`:

### Core
```ini
TimeBasedBehavior=True
ContextAwareness=True
SubtleAnimations=True
PersonalitySystem=True
ProductivityReminders=False
```

### Phase 1: Widgets
```ini
StockTickerEnabled=False
StockSymbols=AAPL,GOOGL,MSFT
CalendarEnabled=False
ClipboardManagerEnabled=False
EyeStrainEnabled=False
```

### Phase 2: Productivity
```ini
TimeBlockEnabled=False
FileOrganizerEnabled=False
PostureEnabled=False
```

### Phase 3: Integration
```ini
TaskIntegrationEnabled=False
AIAssistantEnabled=False
AutomationEnabled=False
```

### Phase 4: Fun
```ini
PetInteractionsEnabled=False
MiniGamesEnabled=False
ARModeEnabled=False
```

## Module Patterns

### Configuration Loading
```powershell
[hashtable] LoadConfig() {
    $this.Config = @{}
    # Load from config.ini
    # Set defaults
    return $this.Config
}
```

### Data Persistence
```powershell
[void] LoadData() {
    # Load from JSON file
}

[void] SaveData() {
    # Save to JSON file
}
```

### State Management
```powershell
[hashtable] GetModuleState() {
    return @{
        "Enabled" = $this.Config["ModuleEnabled"]
        # Return current state
    }
}
```

## Usage

```powershell
# Import module
. "$PSScriptRoot\Widgets\goose-stockticker.ps1"

# Get state
$state = Get-StockTickerState

# Use methods
Add-StockSymbol -Symbol "AAPL"
Refresh-StockData
```

## Modularity

- Each feature loads independently
- Config loading centralized
- Functions exported globally
- Graceful degradation

## Performance

- Lazy loading
- Minimal memory footprint
- Background processing
- Configurable intervals
