# API Referenz

Vollständige API-Referenz für alle server-seitigen Features.

## Base URL

```
http://localhost:8000
```

## Authentication

### Anon Key (Client)
```
apikey: your-anon-key
Authorization: Bearer your-anon-key
```

### Service Key (Server)
```
apikey: your-service-key
Authorization: Bearer your-service-key
```

---

## Analytics API

### Metriken aufzeichnen

**POST** `/rest/v1/analytics_summaries`

```json
{
  "user_id": "uuid",
  "device_id": "device-uuid",
  "date": "2024-01-15",
  "metric_name": "focus_time",
  "metric_category": "productivity",
  "value": { "minutes": 25, "hours": 0.42 }
}
```

### Dashboard-Daten abrufen

**GET** `/rest/v1/analytics_summaries?user_id=eq.{id}&device_id=eq.{id}&date=gte.{date}`

### Berichte abrufen

**GET** `/rest/v1/reports?user_id=eq.{id}&order=generated_at.desc&limit=10`

### Ziele verwalten

**POST** `/rest/v1/goals`
```json
{
  "user_id": "uuid",
  "device_id": "device-uuid",
  "goal_type": "focus_time_total",
  "goal_name": "100 Hours Focus",
  "target_value": 6000,
  "current_value": 0,
  "unit": "minutes",
  "start_date": "2024-01-01",
  "end_date": "2025-01-01",
  "is_active": true
}
```

**PATCH** `/rest/v1/goals?id=eq.{id}`
```json
{
  "current_value": 120,
  "achieved_at": "2024-01-15T10:00:00Z"
}
```

### Achievements abrufen

**GET** `/rest/v1/achievements?user_id=eq.{id}`

---

## Notifications API

### Push-Abonnement registrieren

**POST** `/rest/v1/rpc/register_push_subscription`

```json
{
  "p_user_id": "uuid",
  "p_device_id": "device-uuid",
  "p_endpoint": "https://push.service/v1/endpoint",
  "p_p256dh": "BEl62iUYgUivxIkv69yViEuiBIa-Ib9-SkvMeAtA3LFgDzkrxZJjSgSnfckjBJuBkr3qBUYIHBQFLXYp5Nksh8U",
  "p_auth": "tBHItJr5soHb0CkvuV7oDw"
}
```

### Webhooks verwalten

**POST** `/rest/v1/webhooks`
```json
{
  "user_id": "uuid",
  "name": "My Webhook",
  "url": "https://api.example.com/webhook",
  "events": ["sync.completed", "goal.achieved"],
  "secret": "webhook-secret-key",
  "enabled": true
}
```

**GET** `/rest/v1/webhooks?user_id=eq.{id}`

**PATCH** `/rest/v1/webhooks?id=eq.{id}`
```json
{
  "enabled": false
}
```

**DELETE** `/rest/v1/webhooks?id=eq.{id}`

### Geplante Tasks

**POST** `/rest/v1/rpc/create_scheduled_task`
```json
{
  "p_user_id": "uuid",
  "p_device_id": "device-uuid",
  "p_task_type": "reminder",
  "p_task_name": "Daily Reminder",
  "p_cron_expression": "0 9 * * *",
  "p_payload": { "message": "Check your habits!" }
}
```

**GET** `/rest/v1/scheduled_tasks?user_id=eq.{id}&enabled=eq.true`

### Events

**POST** `/rest/v1/rpc/log_event`
```json
{
  "p_user_id": "uuid",
  "p_device_id": "device-uuid",
  "p_event_type": "goal.achieved",
  "p_event_source": "client",
  "p_payload": { "goal_name": "100 Hours Focus" }
}
```

**GET** `/rest/v1/events?user_id=eq.{id}&processed=eq.false&order=created_at.asc`

### Event verarbeiten

**POST** `/rest/v1/rpc/mark_events_processed`
```json
{
  "p_event_ids": ["uuid1", "uuid2", "uuid3"]
}
```

---

## Security API

### API-Key generieren

**POST** `/rest/v1/rpc/generate_api_key`
```json
{
  "p_user_id": "uuid",
  "p_name": "My Integration",
  "p_description": "API for external app",
  "p_permissions": ["read", "write"],
  "p_expires_at": "2025-01-01T00:00:00Z"
}
```

### API-Key validieren

**POST** `/rest/v1/rpc/validate_api_key`
```json
{
  "p_api_key": "gk_xxxxxxxxxxxxxxxxxxxxx"
}
```

### API-Keys auflisten

**GET** `/rest/v1/api_keys?user_id=eq.{id}&is_active=eq.true&select=id,name,key_prefix,permissions,last_used_at,expires_at`

### API-Key widerrufen

**PATCH** `/rest/v1/api_keys?id=eq.{id}`
```json
{
  "is_active": false
}
```

### Audit-Log

**POST** `/rest/v1/rpc/log_audit_event`
```json
{
  "p_user_id": "uuid",
  "p_device_id": "device-uuid",
  "p_action": "sync",
  "p_resource_type": "sync_data",
  "p_resource_id": "uuid",
  "p_ip_address": "192.168.1.1",
  "p_user_agent": "Mozilla/5.0...",
  "p_details": { "records": 10 },
  "p_success": true
}
```

**GET** `/rest/v1/audit_logs?user_id=eq.{id}&order=created_at.desc&limit=100`

### Session erstellen

**POST** `/rest/v1/rpc/create_session`
```json
{
  "p_user_id": "uuid",
  "p_device_id": "device-uuid",
  "p_ip_address": "192.168.1.1",
  "p_user_agent": "Mozilla/5.0...",
  "p_days_valid": 30
}
```

### Session validieren

**POST** `/rest/v1/rpc/validate_session`
```json
{
  "p_session_token": "session-token-here"
}
```

### Session widerrufen

**POST** `/rest/v1/rpc/revoke_session`
```json
{
  "p_session_id": "session-uuid"
}
```

### OAuth verknüpfen

**POST** `/rest/v1/rpc/link_oauth_provider`
```json
{
  "p_user_id": "uuid",
  "p_provider": "google",
  "p_provider_id": "google-user-id",
  "p_provider_email": "user@gmail.com"
}
```

### OAuth-Provider abrufen

**GET** `/rest/v1/auth_providers?user_id=eq.{id}&select=provider,provider_email,linked_at`

### Rate-Limit prüfen

**POST** `/rest/v1/rpc/check_rate_limit`
```json
{
  "p_user_id": "uuid",
  "p_device_id": "device-uuid",
  "p_endpoint": "/rest/v1/sync_data",
  "p_limit": 100,
  "p_window_minutes": 1
}
```

---

## Files API

### File-Upload aufzeichnen

**POST** `/rest/v1/rpc/record_file_upload`
```json
{
  "p_user_id": "uuid",
  "p_file_name": "backup.json",
  "p_file_path": "uploads/user-id/backup.json",
  "p_mime_type": "application/json",
  "p_file_size": 1024,
  "p_checksum": "sha256-checksum",
  "p_storage_backend": "local"
}
```

### Files auflisten

**GET** `/rest/v1/files?user_id=eq.{id}&order=uploaded_at.desc`

### File löschen

**DELETE** `/rest/v1/files?id=eq.{id}`

---

## Sync API

### Sync-Daten abrufen

**GET** `/rest/v1/sync_data?user_id=eq.{id}&device_id=eq.{id}&data_type=eq.{type}`

### Sync-Daten speichern

**POST** `/rest/v1/sync_data`
```json
{
  "user_id": "uuid",
  "device_id": "device-uuid",
  "data_type": "notes",
  "data": { "notes": [...] },
  "local_modified": "2024-01-15T10:00:00Z"
}
```

### Sync-Daten aktualisieren

**PATCH** `/rest/v1/sync_data?user_id=eq.{id}&data_type=eq.{type}`
```json
{
  "data": { "notes": [...] },
  "local_modified": "2024-01-15T10:00:00Z",
  "version": 2
}
```

### Sync-Verlauf

**GET** `/rest/v1/sync_history?user_id=eq.{id}&order=created_at.desc&limit=50`

---

## Server-Funktionen (RPC)

| Funktion | Beschreibung |
|----------|--------------|
| `compute_daily_summary` | Tägliche Zusammenfassung berechnen |
| `generate_weekly_report` | Wochenbericht generieren |
| `update_goal_progress` | Ziel fortschritt aktualisieren |
| `get_dashboard_analytics` | Dashboard-Daten abrufen |
| `register_push_subscription` | Push registrieren |
| `log_event` | Event protokollieren |
| `get_pending_events` | Ausstehende Events abrufen |
| `mark_events_processed` | Events als verarbeitet markieren |
| `create_scheduled_task` | Task erstellen |
| `get_due_scheduled_tasks` | Fällige Tasks abrufen |
| `record_notification` | Notification speichern |
| `get_webhooks_for_event` | Webhooks für Event abrufen |
| `generate_api_key` | API-Key generieren |
| `validate_api_key` | API-Key validieren |
| `log_audit_event` | Audit-Event loggen |
| `create_session` | Session erstellen |
| `validate_session` | Session validieren |
| `revoke_session` | Session widerrufen |
| `check_rate_limit` | Rate-Limit prüfen |
| `link_oauth_provider` | OAuth verknüpfen |
| `record_file_upload` | File-Upload speichern |

---

## Fehlercodes

| Code | Beschreibung |
|------|--------------|
| 200 | OK |
| 201 | Created |
| 400 | Bad Request |
| 401 | Unauthorized |
| 403 | Forbidden |
| 404 | Not Found |
| 422 | Unprocessable Entity |
| 429 | Too Many Requests |
| 500 | Server Error |

---

## Rate Limits

| Endpunkt | Limit |
|----------|-------|
| `/rest/v1/` (allgemein) | 100/min |
| `/rest/v1/sync_data` | 200/min |
| `/rest/v1/rpc/*` | 50/min |

Bei Überschreitung wird `429 Too Many Requests` zurückgegeben.
