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

### Phase 1: Fun Interaction

#### Multi-Goose System (Social/goose-multigoose.ps1)
- Personality types: Hacker, Lazy, Evil, Normal
- Speech bubble system
- Inter-goose communication
- Skin collection

#### Goose Mood System (Fun/goose-mood.ps1)
- CPU-triggered moods (angry when hot)
- Music-reactive moods (happy when playing)
- Idle detection (bored, sleepy)
- Context-aware mood transitions

#### App Reactions (Core/GooseCore.ps1)
- Window title detection
- Process monitoring
- Context-specific behaviors

### Phase 2: AI & Smart Features

#### AI Chat Goose (Productivity/goose-aiassistant.ps1)
- Local LLM support (Ollama)
- Personality prompts
- Sarkastic responses
- Speech bubble UI
- Conversation history

#### Code Assistant (Fun/goose-codeassistant.ps1)
- Code snippet analysis
- Error explanation
- Comment generation
- StackOverflow integration

#### Learning Goose (Health/goose-learning.ps1)
- Break reminders
- Programming quizzes
- Daily streak tracking
- XP system

### Phase 3: Gamification

#### Mini Games (Fun/goose-minigames.ps1)
- Whack-a-Goose
- Memory Match
- Quiz
- Word Game
- Goose Chase (NEW)
- Icon Heist (NEW)

#### RPG Progression (Social/goose-rpg.ps1)
- Stats: Mischief, Intelligence, Speed, Chaos
- Level system
- Unlockables
- Skin collection

### Phase 4: Plugin System

#### Plugin API (System/goose-pluginapi.ps1)
- Plugin structure: manifest.json, main.ps1
- Hook system: onTick, onAppChange, onIdle, onInteract
- Plugin API functions
- Permission system

#### Marketplace
- Skin marketplace
- Plugin marketplace
- Behavior packs

### Phase 5: Advanced Features

#### Multiplayer Goose
- P2P connections
- Goose invasions
- Goose messages
- Goose duels

#### Streamer Mode
- Twitch integration
- Chat controls
- Donation events
- Alert reactions

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

### Phase 1: Fun Interaction
```ini
# Multi-Goose
MultiGooseEnabled=False
MaxGooseCount=3

# Mood System
MoodSystemEnabled=True
MoodReactToCPU=True
MoodReactToMusic=True

# App Reactions
AppReactionEnabled=False
```

### Phase 2: AI Features
```ini
AIChatEnabled=False
AIProvider=ollama
AIModel=llama2

CodeAssistantEnabled=False
LearningEnabled=False
```

### Phase 3: Gamification
```ini
RPGEnabled=False
MiniGamesEnabled=True
```

### Phase 4: Plugins
```ini
PluginAPIEnabled=False
PluginDirectory=plugins
MarketplaceEnabled=False
```

### Phase 5: Advanced
```ini
StreamerModeEnabled=False
MultiplayerEnabled=False
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
