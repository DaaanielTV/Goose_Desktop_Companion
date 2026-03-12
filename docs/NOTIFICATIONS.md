# Notifications & Events

Dieses Modul bietet Push-Benachrichtigungen, Webhooks und geplante Tasks.

## Datenbank-Tabellen

### notification_subscriptions
WebPush-Abonnements.

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| id | UUID | Primärschlüssel |
| user_id | UUID | Benutzer-ID |
| device_id | TEXT | Geräte-ID |
| endpoint | TEXT | Push-Endpoint-URL |
| p256dh | TEXT | VAPID Public Key |
| auth | TEXT | Auth Secret |
| subscribed_at | TIMESTAMPTZ | Abonnementzeitpunkt |
| expires_at | TIMESTAMPTZ | Ablaufzeitpunkt |

### webhooks
Benutzerdefinierte Webhook-Endpoints.

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| id | UUID | Primärschlüssel |
| user_id | UUID | Benutzer-ID |
| name | TEXT | Webhook-Name |
| url | TEXT | Ziel-URL |
| events | TEXT[] | Event-Typen |
| secret | TEXT | Geheimer Schlüssel für Signatur |
| enabled | BOOLEAN | Aktiviert |
| last_triggered_at | TIMESTAMPTZ | Letzte Auslösung |
| failure_count | INTEGER | Fehleranzahl |

### scheduled_tasks
Geplante Aufgaben.

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| id | UUID | Primärschlüssel |
| user_id | UUID | Benutzer-ID |
| task_type | TEXT | Aufgabentyp |
| task_name | TEXT | Aufgabenname |
| cron_expression | TEXT | Cron-Ausdruck |
| payload | JSONB | Aufgabendaten |
| enabled | BOOLEAN | Aktiviert |
| last_run | TIMESTAMPTZ | Letzte Ausführung |
| next_run | TIMESTAMPTZ | Nächste Ausführung |

### events
Event-Log für Event-Sourcing.

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| id | UUID | Primärschlüssel |
| user_id | UUID | Benutzer-ID |
| device_id | TEXT | Geräte-ID |
| event_type | TEXT | Event-Typ |
| event_source | TEXT | Quelle (client/server/scheduler) |
| payload | JSONB | Event-Daten |
| processed | BOOLEAN | Verarbeitet |

### notification_history
Benachrichtigungsverlauf.

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| id | UUID | Primärschlüssel |
| user_id | UUID | Benutzer-ID |
| notification_type | TEXT | Typ (push/webhook/in_app) |
| title | TEXT | Titel |
| body | TEXT | Inhalt |
| data | JSONB | Zusatzdaten |
| status | TEXT | Status |
| sent_at | TIMESTAMPTZ | Sendezeitpunkt |

## Server-Funktionen

### register_push_subscription
Registriert ein neues Push-Abonnement.

```sql
SELECT id FROM register_push_subscription(
    'user-uuid',
    'device-id',
    'https://push-service.endpoint/v1/...'  -- endpoint
);
```

### log_event
Protokolliert ein Event.

```sql
SELECT id FROM log_event(
    'user-uuid',
    'device-id',
    'goal.achieved',    -- event_type
    'client',           -- source
    '{"goal_name": "100 Hours"}'  -- payload
);
```

### create_scheduled_task
Erstellt einen geplanten Task.

```sql
SELECT id FROM create_scheduled_task(
    'user-uuid',
    'device-id',
    'reminder',           -- task_type
    'Daily Reminder',
    '0 9 * * *',         -- cron: daily at 9am
    '{"message": "Check habits!"}'
);
```

### get_webhooks_for_event
Liefert passende Webhooks für ein Event.

```sql
SELECT * FROM get_webhooks_for_event(
    'user-uuid',
    'goal.achieved'
);
```

## PowerShell Verwendung

### Push-Benachrichtigungen

```powershell
. "$PSScriptRoot\Notifications\goose-notifications.ps1"

# Push-Abonnement registrieren (typischerweise vom Browser)
Register-PushSubscription -Endpoint "https://..." -P256dh "xxx" -Auth "xxx"
```

### Webhooks

```powershell
# Webhook hinzufügen
Add-Webhook -Name "My API" -Url "https://api.example.com/webhook" -Events @("sync.completed", "goal.achieved")

# Webhooks auflisten
Get-Webhooks

# Webhook entfernen
Remove-Webhook -WebhookId "xxx-xxx-xxx"
```

### Verfügbare Events

| Event | Beschreibung |
|-------|--------------|
| sync.started | Synchronisierung gestartet |
| sync.completed | Synchronisierung abgeschlossen |
| sync.failed | Synchronisierung fehlgeschlagen |
| habit.completed | Habit abgeschlossen |
| habit.streak | Streak erreicht |
| goal.achieved | Ziel erreicht |
| report.generated | Bericht generiert |
| device.connected | Gerät verbunden |
| device.disconnected | Gerät getrennt |

### Geplante Tasks

```powershell
# Tägliche Erinnerung erstellen
New-DailyReminder -Time "09:00" -Message "Time to check your habits!"

# Wöchentlichen Bericht erstellen
New-WeeklyReportTask -DayOfWeek "monday" -Hour 9

# Benutzerdefinierten Task erstellen
New-ScheduledTask -TaskName "Custom Task" -TaskType Reminder -CronExpression "0 */2 * * *" -Payload @{ "data" = "value" }

# Tasks auflisten
Get-ScheduledTasks
```

### Cron-Ausdrücke

| Ausdruck | Bedeutung |
|----------|-----------|
| `0 * * * *` | Jede Stunde |
| `0 9 * * *` | Täglich um 9:00 |
| `0 9 * * 1` | Jeden Montag um 9:00 |
| `0 0 * * *` | Mitternacht |
| `*/15 * * * *` | Alle 15 Minuten |

### TaskTypes
- `Reminder` - Erinnerungen
- `Backup` - Backups
- `Report` - Berichte
- `HabitCheck` - Habit-Prüfungen
- `Sync` - Synchronisierungen

### Events auslösen

```powershell
# Event protokollieren
Write-Event -EventType GoalAchieved -Payload @{ "goal_name" = "100 Hours Focus"; "progress" = 100 }

# Event mit Webhook-Auslösung
Trigger-Event -EventType SyncCompleted -Payload @{ "records" = 50; "duration_ms" = 1200 }
```

### EventTypes
- `SyncStarted`, `SyncCompleted`, `SyncFailed`
- `HabitCompleted`, `HabitStreak`
- `GoalAchieved`
- `ReportGenerated`
- `DeviceConnected`, `DeviceDisconnected`

### Benachrichtigungsverlauf

```powershell
# History abrufen
Get-NotificationHistory -Limit 50
```

## Konfiguration

In `config.ini`:

```ini
# Notifications & Events
NotificationsEnabled=True
WebPushEnabled=True
```

## Webhook-Sicherheit

Webhooks werden mit einem `X-Webhook-Secret` Header signiert. Empfänger können die Signatur verifizieren:

```powershell
# Signatur in PowerShell prüfen
$payload = Get-Content "request-body" -Raw
$secret = "webhook-secret"
$signature = "sha256=" + (Get-FileHash -InputStream ([IO.MemoryStream][Text.Encoding]::UTF8.GetBytes($payload)) -Algorithm SHA256).Hash
```

## Offline-Support

- Events werden in der lokalen Datenbank zwischengespeichert
- Bei Online-Verbindung werden Events an den Server übertragen
- Webhooks werden bei Ausfall automatisch erneut versucht (max. 3 Versuche)
