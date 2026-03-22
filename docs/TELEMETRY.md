# Telemetry (OpenTelemetry)

## Übersicht

Das Telemetry-Modul implementiert OpenTelemetry für Desktop Goose und sammelt Metriken, Traces und Logs lokal. Alle 7 Tage werden die gesammelten Daten automatisch an eine Supabase-Instanz gesendet.

**Hinweis:** Telemetrie ist standardmäßig **aktiviert**.

## Features

- **Metriken**: Counter, Gauges, Histograms für System- und Anwendungsdaten
- **Traces**: Distributed Tracing für Performance-Analyse
- **Logs**: Strukturierte Logging-Events
- **Auto-Sync**: Automatischer Upload alle 7 Tage
- **Offline-First**: Lokale Speicherung bei fehlender Verbindung
- **Feature Metrics**: Automatische Metriken für alle neuen Features

## Konfiguration

In `config.ini`:

```ini
# Telemetry (OpenTelemetry) - Standardmäßig aktiviert
TelemetryEnabled=True
TelemetrySyncIntervalDays=7
TelemetryMaxBufferSize=1000
TelemetryCollectMetrics=True
TelemetryCollectTraces=True
TelemetryCollectLogs=True

# Supabase (für Telemetry-Upload)
SupabaseUrl=http://localhost:8000
SupabaseAnonKey=your-anon-key
DeviceId=
```

## Gesammelte Metriken

### System-Metriken

| Metrik | Typ | Beschreibung |
|--------|-----|--------------|
| `system.cpu.usage_percent` | gauge | CPU-Auslastung in Prozent |
| `system.memory.usage_percent` | gauge | RAM-Auslastung in Prozent |
| `system.uptime.minutes` | gauge | System-Uptime in Minuten |

### Goose-Metriken

| Metrik | Typ | Beschreibung |
|--------|-----|--------------|
| `goose.activity_level` | gauge | Aktuelles Aktivitätslevel (0.1-2.0) |
| `goose.interactions` | gauge | Anzahl Interaktionen |
| `goose.happiness` | gauge | Glückslevel der Gans (0.0-1.0) |
| `goose.trust` | gauge | Vertrauenslevel (0.0-1.0) |
| `goose.energy` | gauge | Energie-Level (0.0-1.0) |

## API

### PowerShell-Funktionen

```powershell
# Telemetry-Instanz abrufen
$telemetry = Get-Telemetry

# Span starten (für Tracing)
$span = Start-TelemetrySpan -Name "mein-operation" -Service "desktop-goose"
# ... Operation ausführen ...
Stop-TelemetrySpan -Span $span -Status "ok"

# Log-Eintrag
Write-TelemetryLog -Level "info" -Message "Hinweis-Nachricht" -Source "MeinModul"

# Counter erhöhen
Increment-TelemetryCounter -Name "events.processed" -Value 1 -Tags @{module="test"}

# Gauge setzen
Set-TelemetryGauge -Name "custom.metric" -Value 42.5 -Tags @{env="prod"}

# Histogram aufzeichnen
Record-TelemetryHistogram -Name "request.duration_ms" -Value 150 -Unit "ms"

# Manueller Sync
$result = Sync-Telemetry
# $result.Success, $result.MetricsUploaded, $result.SpansUploaded, etc.

# Sync-Status prüfen
if (Test-TelemetrySync) { ... }

# Konfiguration abrufen
$config = Get-TelemetryConfig
```

### Klassen

```powershell
# TelemetryMetric
$metric = [TelemetryMetric]::new("name", "counter", 1.0, "count", @{tag="value"})

# TelemetrySpan
$span = [TelemetrySpan]::new("operationName", "serviceName", $parentSpanId)
$span.SetAttribute("key", "value")
$span.AddEvent("eventName", @{attr="value"})
$span.End("ok")

# TelemetryLog
$log = [TelemetryLog]::new("info", "Nachricht", "Source", $traceId, $spanId)
```

## Supabase-Datenbank

### Tabellen

```sql
-- Metriken (Counter, Gauges, Histograms)
telemetry_metrics (
    device_id TEXT,
    metric_name TEXT,
    metric_type TEXT,
    value DOUBLE PRECISION,
    unit TEXT,
    tags JSONB,
    timestamp TIMESTAMPTZ
)

-- Traces (Distributed Tracing)
telemetry_spans (
    device_id TEXT,
    trace_id UUID,
    span_id UUID,
    parent_span_id UUID,
    operation_name TEXT,
    service_name TEXT,
    duration_ms DOUBLE PRECISION,
    status TEXT,
    attributes JSONB,
    events JSONB,
    timestamp TIMESTAMPTZ
)

-- Logs
telemetry_logs (
    device_id TEXT,
    trace_id UUID,
    span_id UUID,
    log_level TEXT,
    message TEXT,
    source TEXT,
    attributes JSONB,
    timestamp TIMESTAMPTZ
)

-- Batch-Uploads
telemetry_batches (
    device_id TEXT,
    batch_type TEXT,
    record_count INTEGER,
    data JSONB,
    uploaded_at TIMESTAMPTZ,
    status TEXT
)
```

### Einrichtung

1. Supabase-Projekt erstellen
2. SQL aus `supabase-setup.sql` ausführen
3. `SupabaseUrl` und `SupabaseAnonKey` in `config.ini` setzen
4. `TelemetryEnabled=True` setzen

## Lokale Datenspeicherung

Daten werden lokal gespeichert im Ordner `telemetry_data/`:

```
telemetry_data/
├── device_id.txt    # Eindeutige Geräte-ID
├── last_sync.txt    # Zeitstempel letzter Sync
├── metrics.json    # Gesammelte Metriken
├── spans.json      # Gesammelte Spans
└── logs.json       # Gesammelte Logs
```

## Datenschutz

- Alle Daten sind pro Gerät aggregiert (anonym)
- Keine persönlichen Daten werden automatisch erfasst
- Nutzer kann Telemetry jederzeit deaktivieren
- Lokale Daten werden nach erfolgreichem Upload gelöscht

## Sync-Intervall

- **Standard**: 7 Tage
- **Konfigurierbar**: `TelemetrySyncIntervalDays` in `config.ini`
- Manueller Sync jederzeit möglich mit `Sync-Telemetry`

---

## Feature-Metriken (Phase 7)

### Script Hub

| Metrik | Typ | Beschreibung |
|--------|-----|--------------|
| `scripts.created` | counter | Erstellte Scripts |
| `scripts.executed` | counter | Ausgeführte Scripts |
| `scripts.execution_duration_ms` | histogram | Ausführungsdauer in ms |
| `scripts.errors` | counter | Script-Fehler |

### Desktop Capture

| Metrik | Typ | Beschreibung |
|--------|-----|--------------|
| `capture.screenshots_taken` | counter | Aufgenommene Screenshots |
| `capture.screenshots_saved` | counter | Gespeicherte Screenshots |
| `capture.regions_captured` | counter | Region-Captures |
| `capture.annotations_made` | counter | Annotationen erstellt |
| `capture.copied_to_clipboard` | counter | In Clipboard kopiert |

### Focus Companion

| Metrik | Typ | Beschreibung |
|--------|-----|--------------|
| `focus.sessions_started` | counter | Gestartete Sessions |
| `focus.sessions_completed` | counter | Abgeschlossene Sessions |
| `focus.sessions_abandoned` | counter | Abgebrochene Sessions |
| `focus.breaks_started` | counter | Gestartete Pausen |
| `focus.interruptions` | counter | Unterbrechungen |
| `focus.duration_minutes` | histogram | Fokus-Dauer in Minuten |
| `focus.warnings_shown` | counter | Warnungen angezeigt |

### Voice Commands

| Metrik | Typ | Beschreibung |
|--------|-----|--------------|
| `voice.listening_started` | counter | Spracherkennung gestartet |
| `voice.listening_stopped` | counter | Spracherkennung gestoppt |
| `voice.wake_word_activations` | counter | Wake-Word Aktivierungen |
| `voice.commands_recognized` | counter | Erkannte Befehle |
| `voice.commands_failed` | counter | Fehlgeschlagene Befehle |
| `voice.speech_detected` | counter | Spracherkennung-Events |
| `voice.speeches` | counter | Sprachausgaben |
| `voice.animations_triggered` | counter | Animationen ausgelöst |
| `voice.jokes_told` | counter | Witze erzählt |
| `voice.weather_requests` | counter | Wetter-Anfragen |
| `voice.focus_commands` | counter | Fokus-Befehle |
| `voice.help_requests` | counter | Hilfe-Anfragen |

### Smart Notifications

| Metrik | Typ | Beschreibung |
|--------|-----|--------------|
| `notifications.received` | counter | Empfangene Benachrichtigungen |
| `notifications.snoozed` | counter | Stilisierte Benachrichtigungen |
| `notifications.dismissed` | counter | Verworfene Benachrichtigungen |
| `notifications.marked_read` | counter | Als gelesen markiert |
| `notifications.marked_all_read` | counter | Alle als gelesen |
| `notifications.goose_reactions` | counter | Gans-Reaktionen |

### Quick Notes

| Metrik | Typ | Beschreibung |
|--------|-----|--------------|
| `notes.created` | counter | Erstellte Notizen |
| `notes.edited` | counter | Bearbeitete Notizen |
| `notes.deleted` | counter | Gelöschte Notizen |
| `notes.pinned` | counter | Angeheftete Notizen |
| `notes.characters_written` | histogram | Geschriebene Zeichen |
| `notes.created_from_ui` | counter | UI-Notiz-Erstellung |

### Window Manager

| Metrik | Typ | Beschreibung |
|--------|-----|--------------|
| `window.snap_actions` | counter | Fenster-Snap-Aktionen |
| `window.maximize_actions` | counter | Maximieren-Aktionen |
| `window.minimize_actions` | counter | Minimieren-Aktionen |
| `window.center_actions` | counter | Zentrieren-Aktionen |
| `window.tile_all` | counter | Alle-Fenster-Tiling |
| `window.presets_saved` | counter | Gespeicherte Presets |
| `window.presets_applied` | counter | Angewendete Presets |

### Daily Briefing

| Metrik | Typ | Beschreibung |
|--------|-----|--------------|
| `briefing.viewed` | counter | Angesehene Briefings |
| `briefing.weather_fetched` | counter | Abgerufene Wetterdaten |
| `briefing.quotes_fetched` | counter | Abgerufene Zitate |

### Goose Memory

| Metrik | Typ | Beschreibung |
|--------|-----|--------------|
| `memory.interactions_logged` | counter | Loggte Interaktionen |
| `memory.recalls` | counter | Erinnerungs-Abrufe |
| `memory.forgotten` | counter | Vergessene Erinnerungen |
| `memory.patterns_learned` | counter | Erkannte Muster |
| `memory.pattern_matched` | counter | Übereinstimmungen |
| `memory.conversations_stored` | counter | Gespeicherte Konversationen |
| `memory.preferences_stored` | counter | Gespeicherte Präferenzen |
| `memory.imports` | counter | Importe |
| `memory.cleared` | counter | Löschungen |

### Achievements

| Metrik | Typ | Beschreibung |
|--------|-----|--------------|
| `achievements.unlocked` | counter | Freigeschaltete Achievements |
| `achievements.total_points` | gauge | Gesamtpunktzahl |
