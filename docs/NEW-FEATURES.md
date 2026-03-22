# Desktop Goose - Neue Features (Phase 7)

> **Letzte Aktualisierung:** März 2026
> **Version:** 2.1.0

---

## Übersicht

Diese Phase fügt 10 neue Features hinzu, darunter ein PowerShell Script Hub, Desktop-Capture, Focus Companion, Voice Commands und mehr.

---

## Feature 1: PowerShell Script Hub

**Datei:** `System/goose-script-hub.ps1`
**Kategorie:** System Tools
**UI-Tab:** Scripts

### Beschreibung

Ein vollständiger Script-Manager zum Erstellen, Verwalten und Ausführen eigener PowerShell-Skripte direkt aus dem Desktop Goose Control Center.

### Features

- Script-Editor mit Code-Speicherung
- Script-Bibliothek (gespeichert als JSON)
- Ausführungs-Historie mit Logs
- Kategorien für Organisation
- Import/Export von Scripts
- Parameter-Unterstützung

### Konfiguration

```ini
# Script Hub
ScriptHubEnabled=True
ScriptHubScriptsFolder=scripts
```

### API

```powershell
# Script Hub abrufen
$hub = Get-ScriptHub

# Script erstellen
New-GooseScript -Name "Mein Script" -Description "Beschreibung" -Code "Write-Host 'Hallo'"

# Script ausführen
$result = Invoke-GooseScript -ScriptId "guid-here"

# Alle Scripts abrufen
$scripts = Get-GooseScripts

# Script löschen
Remove-GooseScript -ScriptId "guid-here"
```

### Telemetrie

| Metrik | Beschreibung |
|--------|--------------|
| `scripts.created` | Erstellte Scripts |
| `scripts.executed` | Ausgeführte Scripts |
| `scripts.execution_duration_ms` | Ausführungsdauer |
| `scripts.errors` | Script-Fehler |

---

## Feature 2: Desktop Capture & Annotate

**Datei:** `Media/goose-capture.ps1`
**Kategorie:** Media/Productivity
**UI-Tab:** Fun

### Beschreibung

Screenshots erstellen und mit der Gans annotieren. Die Gans kann auf Screenshots reagieren und lustige Kommentare hinzufügen.

### Features

- Vollbild-Screenshot
- Regions-Auswahl
- Annotationen (Rechtecke, Kreise, Pfeile, Text)
- Highlight-Tool
- Speichern als PNG/JPG/BMP
- Direkt in Clipboard kopieren
- Goose-Reaktionen

### Konfiguration

```ini
# Desktop Capture
CaptureEnabled=True
CaptureHotkey=Win+Shift+G
CaptureSaveFormat=png
CaptureSaveFolder=Screenshots
CaptureAnnotationColor=#FF5722
```

### API

```powershell
# Screenshot aufnehmen
$capture = Get-Capture
$img = $capture.CaptureScreen()

# Region erfassen
$img = $capture.CaptureRegion((New-Object System.Drawing.Rectangle(100, 100, 400, 300)))

# Annotation hinzufügen
$capture.AddAnnotation("rectangle", @{x=10; y=10; width=100; height=50})
$capture.AddAnnotation("text", @{x=20; y=20; content="Wichtig!"; size=14})

# Screenshot speichern
$path = $capture.SaveScreenshot($img, "MeinScreenshot.png")

# In Clipboard kopieren
$capture.CopyToClipboard($img)
```

### Telemetrie

| Metrik | Beschreibung |
|--------|--------------|
| `capture.screenshots_taken` | Aufgenommene Screenshots |
| `capture.annotations_made` | Annotationen |
| `capture.screenshots_saved` | Gespeicherte Screenshots |

---

## Feature 3: Focus Companion

**Datei:** `Productivity/goose-focus-companion.ps1`
**Kategorie:** Productivity
**UI-Tab:** Productivity

### Beschreibung

Die Gans wird zum aktiven Fokus-Begleiter während Pomodoro-Sessions. Sie überwacht deine Fokussierung und erinnert dich an Pausen.

### Features

- Konfigurierbare Session-Dauer (Standard: 25 Min)
- Kurze Pausen (5 Min) und lange Pausen (15 Min)
- Interruptions-Tracking
- Warnungen bei zu vielen Unterbrechungen
- Statistiken: Sessions, Streaks, Gesamtfokuszeit
- Automatischer Pausen-Start

### Konfiguration

```ini
# Focus Companion
FocusCompanionEnabled=True
FocusDefaultSessionMinutes=25
FocusShortBreakMinutes=5
FocusLongBreakMinutes=15
FocusSessionsBeforeLongBreak=4
FocusDisturbanceThreshold=5
```

### API

```powershell
# Focus-Session starten
$companion = Get-FocusCompanion
$companion.StartSession(30)  # 30 Minuten

# Session beenden
$companion.EndSession($true)  # $false für abgebrochen

# Statistiken abrufen
$stats = $companion.GetTodayStats()
# Returns: sessionsToday, completedToday, totalFocusMinutes, currentStreak
```

### Telemetrie

| Metrik | Beschreibung |
|--------|--------------|
| `focus.sessions_started` | Gestartete Sessions |
| `focus.sessions_completed` | Abgeschlossene Sessions |
| `focus.interruptions` | Unterbrechungen |
| `focus.duration_minutes` | Fokus-Dauer |

---

## Feature 4: Voice Commands

**Datei:** `System/goose-voice.ps1`
**Kategorie:** Fun/AI
**UI-Tab:** System

### Beschreibung

Spracherkennung für Goose-Befehle via Windows Speech API. Aktiviere die Gans mit "Hey Goose" und gib Sprachbefehle.

### Features

- Wake-Word Erkennung ("Hey Goose")
- Sprachbefehle: Honk, Dance, Screenshot, Joke, Weather, Time, Focus
- Text-to-Speech für Antworten
- Konfigurierbare Stimme (Rate, Volume)
- Custom Command Support
- Hilfe-System

### Konfiguration

```ini
# Voice Commands
VoiceCommandsEnabled=False
VoiceWakeWord=Hey Goose
VoiceLanguage=en-US
VoiceConfidenceThreshold=0.7
VoiceEnabled=True
VoiceRate=0
VoiceVolume=100
```

### Befehle

| Befehl | Aktion |
|--------|--------|
| "honk" / "make a sound" | Gans macht Geräusch |
| "dance" / "do a dance" | Gans tanzt |
| "screenshot" | Screenshot aufnehmen |
| "tell me a joke" | Gans erzählt einen Witz |
| "weather" | Wetter abfragen |
| "time" | Uhrzeit ansagen |
| "focus" / "start focus" | Fokus-Modus starten |
| "help" | Hilfe anzeigen |

### API

```powershell
# Spracherkennung starten
$voice = Get-VoiceCommands
$voice.StartListening()

# Spracherkennung stoppen
$voice.StopListening()

# Custom Command hinzufügen
$voice.AddCustomCommand("my command", {
    # Script-Block ausführen
}, "Antwort-Text")
```

### Telemetrie

| Metrik | Beschreibung |
|--------|--------------|
| `voice.wake_word_activations` | Wake-Word Aktivierungen |
| `voice.commands_recognized` | Erkannte Befehle |
| `voice.animations_triggered` | Animationen |

---

## Feature 5: Smart Notifications

**Datei:** `System/goose-smart-notifications.ps1`
**Kategorie:** System
**UI-Tab:** System

### Beschreibung

Intelligente Benachrichtigungs-Verwaltung mit Kategorisierung und Snooze-Funktion. Die Gans reagiert auf Benachrichtigungen.

### Features

- Benachrichtigungs-History (max 100)
- Kategorien: Work, Social, System, Personal, Urgent
- Snooze-Funktion (15 Min Standard)
- Toast-Benachrichtigungen
- Dashboard mit Übersicht
- Goose-Reaktionen basierend auf Kategorie

### Konfiguration

```ini
# Smart Notifications
SmartNotificationsEnabled=True
SmartNotificationsMaxHistory=100
SmartNotificationsSnoozeMinutes=15
SmartNotificationsShowDashboard=True
SmartNotificationsGooseReaction=True
```

### API

```powershell
# Benachrichtigung senden
$notifications = Get-SmartNotifications
$notifications.AddNotification("Neue E-Mail", "Du hast eine neue E-Mail von Max", "Work")

# Dashboard anzeigen
Show-NotificationDashboard

# Benachrichtigung snoozen
$notifications.SnoozeNotification("notification-id", 30)

# Benachrichtigung verwerfen
$notifications.DismissNotification("notification-id")
```

### Telemetrie

| Metrik | Beschreibung |
|--------|--------------|
| `notifications.received` | Empfangene Benachrichtigungen |
| `notifications.snoozed` | Stilisierte |
| `notifications.dismissed` | Verworfene |

---

## Feature 6: Quick Notes Overlay

**Datei:** `Productivity/goose-quick-notes.ps1`
**Kategorie:** Productivity
**UI-Tab:** Productivity

### Beschreibung

Desktop-Overlay für schnelle Notizen mit Drag & Drop Positionierung. Notizen werden automatisch als JSON gespeichert.

### Features

- Transparentes Overlay
- Drag & Drop Positionierung
- Rich Text (Titel + Content)
- Anheften von Notizen
- Farben für Notizen
- Auto-Save zu JSON
- CRUD-Operationen

### Konfiguration

```ini
# Quick Notes
QuickNotesEnabled=True
QuickNotesDefaultWidth=300
QuickNotesDefaultHeight=200
QuickNotesOpacity=0.95
QuickNotesFontSize=12
```

### API

```powershell
# Overlay anzeigen
$notes = Get-QuickNotes
$notes.ShowOverlay()

# Neue Notiz erstellen
$note = $notes.CreateNote("Einkaufsliste", "Milch, Brot, Eier")

# Notiz bearbeiten
$notes.UpdateNote("note-id", @{title="Neuer Titel"; content="Neuer Inhalt"})

# Notiz löschen
$notes.DeleteNote("note-id")

# Notiz anheften
$notes.TogglePin("note-id")
```

### Telemetrie

| Metrik | Beschreibung |
|--------|--------------|
| `notes.created` | Erstellte Notizen |
| `notes.edited` | Bearbeitete Notizen |
| `notes.characters_written` | Zeichen geschrieben |

---

## Feature 7: Window Manager

**Datei:** `System/goose-window-manager.ps1`
**Kategorie:** System
**UI-Tab:** System

### Beschreibung

Die Gans hilft beim Organisieren von Fenstern mit Snap-Aktionen und speicherbaren Presets.

### Features

- Snap Left/Right/Top/Bottom
- Fenster maximieren/minimieren
- Fenster zentrieren
- Tile All Windows
- Presets speichern/anwenden
- Multi-Monitor-Support
- Preset-Management

### Konfiguration

```ini
# Window Manager
WindowManagerEnabled=True
WindowManagerAnimationSpeed=100
WindowManagerSnapThreshold=50
WindowManagerRememberPositions=True
```

### API

```powershell
# Window Manager abrufen
$wm = Get-WindowManager

# Fenster snap
$wm.SnapLeft()
$wm.SnapRight()
$wm.SnapTop()
$wm.SnapBottom()

# Alle Fenster tile
$wm.TileAllWindows()

# Preset speichern
$preset = $wm.SavePreset("Arbeits-Layout")

# Preset anwenden
$wm.ApplyPreset("preset-id")

# Window Picker UI anzeigen
Show-WindowManager
```

### Telemetrie

| Metrik | Beschreibung |
|--------|--------------|
| `window.snap_actions` | Snap-Aktionen |
| `window.tile_all` | Tile-Aktionen |
| `window.presets_saved` | Gespeicherte Presets |

---

## Feature 8: Daily Briefing

**Datei:** `Widgets/goose-daily-briefing.ps1`
**Kategorie:** Widgets
**UI-Tab:** Widgets

### Beschreibung

Morgen-Zusammenfassung mit Wetter, Kalender-Terminen und Tasks. Die Gans startet informiert in den Tag.

### Features

- Wetter-Anzeige (simuliert)
- Kalender-Übersicht
- Task-Liste des Tages
- Motivations-Zitat
- Personalisierte Gans-Nachricht
- Events und Tasks hinzufügen

### Konfiguration

```ini
# Daily Briefing
DailyBriefingEnabled=True
DailyBriefingLocation=
DailyBriefingTemperatureUnit=Celsius
DailyBriefingShowWeather=True
DailyBriefingShowCalendar=True
DailyBriefingShowTasks=True
DailyBriefingShowQuote=True
DailyBriefingAutoShowOnStartup=False
```

### API

```powershell
# Briefing abrufen
$briefing = Get-DailyBriefing
$data = $briefing.GetBriefingData()

# Briefing UI anzeigen
Show-DailyBriefing

# Event hinzufügen
$briefing.AddEvent("Team Meeting", "14:00", "2026-03-22")

# Task hinzufügen
$briefing.AddTask("Report abschließen")
```

### Telemetrie

| Metrik | Beschreibung |
|--------|--------------|
| `briefing.viewed` | Angesehene Briefings |
| `briefing.weather_fetched` | Wetter-Abrufe |
| `briefing.quotes_fetched` | Zitat-Abrufe |

---

## Feature 9: Goose Memory

**Datei:** `System/goose-memory.ps1`
**Kategorie:** AI/Context
**UI-Tab:** Fun

### Beschreibung

Die Gans erinnert sich an Benutzerinteraktionen und -präferenzen. Sie lernt Patterns und personalisiert Reaktionen.

### Features

- Memories speichern/abhrufen
- Konversations-Historie
- Pattern-Detection (Zeit-basiert)
- Präferenzen merken
- Vergessens-Mechanismus
- Import/Export
- Kategorien

### Konfiguration

```ini
# Goose Memory
GooseMemoryEnabled=True
GooseMemoryMaxMemories=1000
GooseMemoryMaxPatternAge=30
GooseMemoryLearnFromInteractions=True
GooseMemoryRememberPreferences=True
GooseMemoryStoreConversations=True
GooseMemoryPatternDetection=True
```

### API

```powershell
# Memory abrufen
$memory = Get-GooseMemory

# Erinnerung speichern
$memory.Remember("favorite_color", "Blue", "preference")

# Erinnerung abrufen
$value = $memory.Recall("favorite_color")

# Erinnerung löschen
$memory.Forget("favorite_color")

# Konversation speichern
$memory.StoreConversation("user", "Hello goose")
$memory.StoreConversation("goose", "HONK! Hello!")

# Konversation abrufen
$msgs = $memory.GetConversation()

# Pattern abrufen
$patterns = $memory.GetPattern("Monday", 9)

# Statistiken
$stats = $memory.GetStats()
```

### Telemetrie

| Metrik | Beschreibung |
|--------|--------------|
| `memory.interactions_logged` | Loggte Interaktionen |
| `memory.patterns_learned` | Erkannte Muster |
| `memory.recalls` | Abrufe |

---

## Feature 10: Achievement System

**Datei:** `Social/goose-achievements.ps1`
**Kategorie:** Gamification
**UI-Tab:** Social

### Beschreibung

Achievements für interaktive Goose-Nutzung. 22+ Achievements mit Badge-Animationen bei Freischaltung.

### Features

- 22+ Achievements in 6 Kategorien
- Badge-Animation bei Freischaltung
- Punkte-System
- Progress-Tracking
- Kategorien: Basic, Productivity, Fun, Special, Advanced, Streaks

### Achievements

| ID | Name | Punkte | Kategorie |
|----|------|--------|-----------|
| first_honk | First Honk | 10 | basic |
| honk_master | Honk Master | 50 | basic |
| first_screenshot | Snappy Goose | 15 | productivity |
| focus_rookie | Focus Rookie | 20 | productivity |
| focus_master | Focus Master | 150 | productivity |
| note_taker | Note Taker | 30 | productivity |
| organized | Organized | 40 | productivity |
| first_dance | Dance Machine | 10 | fun |
| joke_teller | Comedy Goose | 30 | fun |
| voice_user | Voice Activated | 25 | fun |
| early_bird | Early Bird | 15 | special |
| night_owl | Night Owl | 15 | special |
| memory_master | Memory Master | 75 | special |
| script_kiddie | Script Kiddie | 20 | advanced |
| script_surgeon | Script Surgeon | 100 | advanced |
| streak_3 | Getting Started | 25 | streaks |
| streak_7 | Week Warrior | 75 | streaks |
| streak_30 | Monthly Dedication | 300 | streaks |
| ... | ... | ... | ... |

### Konfiguration

```ini
# Achievements
AchievementsEnabled=True
AchievementsShowNotifications=True
AchievementsPlaySound=False
AchievementsPointsMultiplier=1.0
```

### API

```powershell
# Achievements abrufen
$achievements = Get-Achievements

# Achievements-Panel anzeigen
Show-AchievementsPanel

# Achievement prüfen
$achievements.CheckAchievement("first_honk", 1)
$achievements.CheckAchievement("focus_master", 50)

# Streak-Achievement prüfen
$achievements.CheckStreakAchievement(7)

# Fortschritt abrufen
$progress = $achievements.GetProgress()
# Returns: unlocked, total, percentage, totalPoints
```

### Telemetrie

| Metrik | Beschreibung |
|--------|--------------|
| `achievements.unlocked` | Freigeschaltete Achievements |
| `achievements.total_points` | Gesamtpunktzahl |

---

## Dateistruktur

```
DesktopGoose/
├── System/
│   ├── goose-script-hub.ps1        # NEU: PowerShell Script Manager
│   ├── goose-voice.ps1           # NEU: Voice Commands
│   ├── goose-smart-notifications.ps1 # NEU: Smart Notifications
│   ├── goose-window-manager.ps1   # NEU: Window Management
│   └── goose-memory.ps1           # NEU: Memory System
├── Media/
│   └── goose-capture.ps1          # NEU: Screenshot & Annotate
├── Productivity/
│   ├── goose-focus-companion.ps1  # NEU: Focus Session Integration
│   └── goose-quick-notes.ps1      # NEU: Quick Notes Overlay
├── Widgets/
│   └── goose-daily-briefing.ps1   # NEU: Morning Briefing
├── Social/
│   └── goose-achievements.ps1     # NEU: Achievement System
├── UI/
│   └── goose-ui.ps1               # UPDATED: New Scripts tab + Features
├── docs/
│   ├── TELEMETRY.md              # UPDATED: New metrics
│   └── NEW-FEATURES.md           # NEU: Feature docs
└── config.ini                    # UPDATED: New config options
```

---

## Changelog

- **2026-03-22:** Phase 7 Features implementiert
  - PowerShell Script Hub
  - Desktop Capture & Annotate
  - Focus Companion
  - Voice Commands
  - Smart Notifications
  - Quick Notes Overlay
  - Window Manager
  - Daily Briefing
  - Goose Memory
  - Achievement System

---

*Desktop Goose Phase 7 - Neue Features 🦆*
