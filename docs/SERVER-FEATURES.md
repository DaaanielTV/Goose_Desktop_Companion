# Server-seitige Features Übersicht

Dieses Dokument beschreibt die erweiterten server-seitigen Features für Desktop Goose, die auf dem Supabase Self-Hosted Backend aufbauen.

## Architektur

```
┌─────────────────────────────────────────────────────────────────┐
│                    Desktop Goose Client                          │
│  ┌──────────┐  ┌──────────────┐  ┌─────────┐  ┌──────────┐    │
│  │Analytics │  │Notifications │  │ Security│  │  Sync    │    │
│  │          │  │              │  │         │  │          │    │
│  └────┬─────┘  └──────┬───────┘  └────┬────┘  └────┬─────┘    │
└───────┼───────────────┼───────────────┼────────────┼───────────┘
        │               │               │            │
        ▼               ▼               ▼            ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Supabase Backend                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │   REST API  │  │  PostgreSQL │  │   Kong     │             │
│  │  (PostgREST)│  │  Database   │  │   Gateway   │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
└─────────────────────────────────────────────────────────────────┘
```

## Features Übersicht

### 1. Analytics & Reporting
- Tägliche/wochentliche Zusammenfassungen
- Goals & Ziel-Tracking
- Achievements & Gamification
- Dashboard Analytics

### 2. Notifications & Events
- Push-Benachrichtigungen (WebPush)
- Webhooks für externe Integrationen
- Geplante Tasks (Cron-basiert)
- Event-Sourcing & Audit Trail

### 3. Security & Storage
- OAuth-Integration (Google, GitHub, Apple, Microsoft)
- API Keys für externe Apps
- Audit-Logs für Compliance
- File Storage Metadaten
- Session Management
- Rate Limiting

---

## Schnellstart

### 1. Datenbank aktualisieren

Führen Sie das aktualisierte SQL-Schema aus:

```bash
docker exec -i goose-supabase-db psql -U postgres < supabase-setup.sql
```

### 2. Konfiguration

Aktivieren Sie die Features in `config.ini`:

```ini
# Analytics & Reporting
AnalyticsEnabled=True
AnalyticsAutoReport=True
AnalyticsDays=7

# Notifications & Events  
NotificationsEnabled=True
WebPushEnabled=True

# Security & Storage
SecurityEnabled=True
ApiKeyRateLimit=100
```

### 3. Module laden

```powershell
# Alle Module laden
. "$PSScriptRoot\Analytics\goose-analytics.ps1"
. "$PSScriptRoot\Notifications\goose-notifications.ps1"
. "$PSScriptRoot\Security\goose-security.ps1"

# Oder einzeln
. "$PSScriptRoot\Analytics\goose-analytics.ps1"
```

---

## Feature-Details

| Feature | Beschreibung | Konfiguration |
|---------|--------------|---------------|
| Analytics | Metriken, Goals, Achievements | `AnalyticsEnabled` |
| Notifications | Push, Webhooks, Scheduled Tasks | `NotificationsEnabled` |
| Security | OAuth, API Keys, Audit Logs | `SecurityEnabled` |

Weitere Details finden Sie in den einzelnen Dokumentationsdateien.
