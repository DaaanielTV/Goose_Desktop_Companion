# Analytics & Reporting

Dieses Modul bietet umfassende Analysen, Ziel-Tracking und Gamification-Features.

## Datenbank-Tabellen

### analytics_summaries
Tägliche aggregierte Metriken.

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| id | UUID | Primärschlüssel |
| user_id | UUID | Benutzer-ID |
| device_id | TEXT | Geräte-ID |
| date | DATE | Datum |
| metric_name | TEXT | Metrik-Name |
| metric_category | TEXT | Kategorie (productivity, habits, sync, telemetry) |
| value | JSONB | Metrik-Wert |
| computed_at | TIMESTAMPTZ | Berechnungszeitpunkt |

### reports
Generierte Berichte.

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| id | UUID | Primärschlüssel |
| user_id | UUID | Benutzer-ID |
| report_type | TEXT | Berichtstyp |
| date_range_start | DATE | Startdatum |
| date_range_end | DATE | Enddatum |
| title | TEXT | Berichtstitel |
| summary | JSONB | Zusammenfassung |
| details | JSONB | Details |

### goals
Benutzerziele.

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| id | UUID | Primärschlüssel |
| user_id | UUID | Benutzer-ID |
| goal_type | TEXT | Ziel-Typ |
| goal_name | TEXT | Ziel-Name |
| target_value | DOUBLE | Zielwert |
| current_value | DOUBLE | Aktueller Wert |
| unit | TEXT | Einheit |
| start_date | DATE | Startdatum |
| end_date | DATE | Enddatum |
| achieved_at | TIMESTAMPTZ | Zeitpunkt der Zielerreichung |

### achievements
Gamification-Badges.

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| id | UUID | Primärschlüssel |
| user_id | UUID | Benutzer-ID |
| achievement_key | TEXT | Eindeutiger Schlüssel |
| achievement_name | TEXT | Name |
| description | TEXT | Beschreibung |
| progress_current | DOUBLE | Aktueller Fortschritt |
| progress_target | DOUBLE | Ziel-Fortschritt |
| is_unlocked | BOOLEAN | Freigeschaltet |

## Server-Funktionen

### compute_daily_summary
Berechnet tägliche Zusammenfassungen für einen Benutzer.

```sql
SELECT * FROM compute_daily_summary(
    'user-uuid',
    'device-id',
    '2024-01-15'
);
```

### generate_weekly_report
Generiert einen Wochenbericht.

```sql
SELECT id FROM generate_weekly_report(
    'user-uuid',
    'device-id',
    '2024-01-08'  -- week start
);
```

### update_goal_progress
Aktualisiert den Fortschritt eines Ziels.

```sql
SELECT * FROM update_goal_progress(
    'user-uuid',
    'device-id',
    'focus_time_total',
    120  -- neue Minuten
);
```

### get_dashboard_analytics
Liefert Dashboard-Daten.

```sql
SELECT * FROM get_dashboard_analytics(
    'user-uuid',
    'device-id',
    7  -- Tage
);
```

## PowerShell Verwendung

### Metriken aufzeichnen

```powershell
. "$PSScriptRoot\Analytics\goose-analytics.ps1"

# Focus Time aufzeichnen
Record-FocusTime -Minutes 25

# Habit Completion aufzeichnen
Record-HabitCompletion -TotalHabits 5 -CompletedHabits 4

# Sync Activity aufzeichnen
Record-SyncActivity -TotalSyncs 10 -Successful 9 -Failed 1
```

### Ziele verwalten

```powershell
# Neues Ziel erstellen
New-Goal -Type FocusTimeTotal -Name "100 Hours Focus" -Target 6000 -Unit "minutes" -EndDate (Get-Date).AddYears(1)

# Fortschritt abfragen
Get-GoalProgress -Type FocusTimeTotal

# Fortschritt aktualisieren
Update-GoalProgress -Type FocusTimeTotal -Value 120
```

### Verfügbare GoalTypes
- `HabitStreak` - Tägliche Streaks
- `FocusTimeTotal` - Gesamt-Focuszeit
- `NotesCount` - Anzahl Notizen
- `SyncFrequency` - Sync-Häufigkeit

### Berichte & Dashboard

```powershell
# Dashboard-Daten abrufen
Get-AnalyticsDashboard -Days 7

# Wochenbericht abrufen
Get-WeeklyReport

# Achievements abrufen
Get-Achievements

# Alle Ziele abrufen
Get-Goals
```

### Goals abrufen

```powershell
# Alle aktiven Ziele
$goals = Get-Goals
$goals.List | Where-Object { $_.IsActive }

# Abgeschlossene Ziele
$goals.List | Where-Object { $_.AchievedAt -ne $null }
```

## Vordefinierte Achievements

| Key | Name | Beschreibung | Ziel |
|-----|------|--------------|------|
| first_sync | First Sync | Erste Synchronisierung | 1 |
| week_streak | Week Warrior | 7-Tage-Streak | 7 |
| month_streak | Monthly Master | 30-Tage-Streak | 30 |
| notes_10 | Note Taker | 10 Notizen erstellen | 10 |
| notes_50 | Note Collector | 50 Notizen erstellen | 50 |
| notes_100 | Note Master | 100 Notizen erstellen | 100 |
| focus_1h | Focus Beginner | 1 Stunde Focus | 60 |
| focus_10h | Focus Pro | 10 Stunden Focus | 600 |
| focus_100h | Focus Master | 100 Stunden Focus | 6000 |

## Konfiguration

In `config.ini`:

```ini
# Analytics & Reporting
AnalyticsEnabled=True
AnalyticsAutoReport=True
AnalyticsDays=7
```

## Offline-Support

Das Analytics-Modul funktioniert auch offline:
- Ziele werden lokal in `goose_goals.json` gespeichert
- Achievements werden lokal in `goose_achievements.json` gespeichert
- Bei Online-Verbindung werden Daten mit dem Server synchronisiert
