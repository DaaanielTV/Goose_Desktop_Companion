# Security & Storage

Dieses Modul bietet OAuth-Integration, API-Keys, Audit-Logs und File-Management.

## Datenbank-Tabellen

### auth_providers
OAuth-Provider-Verknüpfungen.

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| id | UUID | Primärschlüssel |
| user_id | UUID | Benutzer-ID |
| provider | TEXT | Provider-Name |
| provider_id | TEXT | Provider-Benutzer-ID |
| provider_email | TEXT | E-Mail vom Provider |
| access_token | TEXT | Access Token (verschlüsselt) |
| refresh_token | TEXT | Refresh Token (verschlüsselt) |
| token_expires_at | TIMESTAMPTZ | Ablaufzeitpunkt |
| linked_at | TIMESTAMPTZ | Verknüpfungszeitpunkt |

### api_keys
API-Keys für externe Integrationen.

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| id | UUID | Primärschlüssel |
| user_id | UUID | Benutzer-ID |
| key_hash | TEXT | SHA256-Hash des Keys |
| key_prefix | TEXT | Erste 12 Zeichen (Anzeige) |
| name | TEXT | Key-Name |
| description | TEXT | Beschreibung |
| permissions | TEXT[] | Berechtigungen |
| rate_limit | INTEGER | Rate-Limit |
| last_used_at | TIMESTAMPTZ | Letzte Nutzung |
| expires_at | TIMESTAMPTZ | Ablaufzeitpunkt |
| is_active | BOOLEAN | Aktiv |

### audit_logs
Audit-Trail für Compliance.

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| id | UUID | Primärschlüssel |
| user_id | UUID | Benutzer-ID |
| device_id | TEXT | Geräte-ID |
| action | TEXT | Aktion |
| resource_type | TEXT | Ressourcentyp |
| resource_id | UUID | Ressourcen-ID |
| ip_address | INET | IP-Adresse |
| user_agent | TEXT | User-Agent |
| location | JSONB | Standort |
| details | JSONB | Details |
| success | BOOLEAN | Erfolgreich |
| created_at | TIMESTAMPTZ | Zeitstempel |

### files
File-Metadaten.

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| id | UUID | Primärschlüssel |
| user_id | UUID | Benutzer-ID |
| team_id | UUID | Team-ID |
| file_name | TEXT | Dateiname |
| file_path | TEXT | Speicherpfad |
| mime_type | TEXT | MIME-Typ |
| file_size | BIGINT | Dateigröße |
| checksum | TEXT | SHA256-Prüfsumme |
| storage_backend | TEXT | Backend (local/s3) |
| is_public | BOOLEAN | Öffentlich |
| expires_at | TIMESTAMPTZ | Ablaufzeitpunkt |
| access_count | INTEGER | Zugriffszähler |

### sessions
User-Sessions.

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| id | UUID | Primärschlüssel |
| user_id | UUID | Benutzer-ID |
| device_id | TEXT | Geräte-ID |
| session_token | TEXT | Session-Token |
| refresh_token | TEXT | Refresh-Token |
| ip_address | INET | IP-Adresse |
| expires_at | TIMESTAMPTZ | Ablaufzeitpunkt |
| is_active | BOOLEAN | Aktiv |

### rate_limits
Rate-Limiting.

| Spalte | Typ | Beschreibung |
|--------|-----|--------------|
| id | UUID | Primärschlüssel |
| user_id | UUID | Benutzer-ID |
| endpoint | TEXT | Endpunkt |
| request_count | INTEGER | Anfragenanzahl |
| limit_value | INTEGER | Limit |
| blocked_until | TIMESTAMPTZ | Blockiert bis |

## Server-Funktionen

### generate_api_key
Generiert einen neuen API-Key.

```sql
SELECT * FROM generate_api_key(
    'user-uuid',
    'My Integration',
    'API for external app',
    ARRAY['read', 'write'],
    NOW() + INTERVAL '1 year'
);
```

Rückgabe:
- `key_id` - UUID des Keys
- `api_key` - Der echte Key (nur einmal sichtbar!)
- `key_prefix` - Anzeige-Präfix

### validate_api_key
Validiert einen API-Key.

```sql
SELECT * FROM validate_api_key('gk_xxxxxxxxxxxx');
```

### log_audit_event
Protokolliert eine Audit-Aktion.

```sql
SELECT id FROM log_audit_event(
    'user-uuid',
    'device-id',
    'sync',              -- action
    'sync_data',         -- resource_type
    'uuid',              -- resource_id
    '192.168.1.1'::inet, -- ip
    'Mozilla/5.0...',    -- user_agent
    '{"records": 10}',   -- details
    true                 -- success
);
```

### create_session
Erstellt eine neue Session.

```sql
SELECT * FROM create_session(
    'user-uuid',
    'device-id',
    '192.168.1.1'::inet,
    'Mozilla/5.0...',
    30  -- days valid
);
```

### validate_session
Validiert eine Session.

```sql
SELECT * FROM validate_session('session-token-here');
```

### revoke_session
 Widerruft eine Session.

```sql
SELECT revoke_session('session-uuid');
```

### check_rate_limit
Prüft Rate-Limit.

```sql
SELECT check_rate_limit(
    'user-uuid',
    'device-id',
    '/rest/v1/sync_data',
    100,   -- limit
    1      -- window minutes
);
```

### link_oauth_provider
Verknüpft einen OAuth-Provider.

```sql
SELECT id FROM link_oauth_provider(
    'user-uuid',
    'google',
    'google-user-id-123',
    'user@gmail.com',
    'access-token',
    'refresh-token',
    NOW() + INTERVAL '1 hour'
);
```

## PowerShell Verwendung

### API-Keys

```powershell
. "$PSScriptRoot\Security\goose-security.ps1"

# Neuen API-Key erstellen
$key = New-ApiKey -Name "My App" -Permissions @("read", "write") -ExpiresInDays 365

# Der Key wird nur einmal zurückgegeben:
# $key.ApiKey -> "gk_xxxxxxxxxxxxxxxxxxxxx"

# Key merken! Er kann nicht erneut abgerufen werden.

# Alle Keys auflisten
Get-ApiKeys

# Key widerrufen
Revoke-ApiKey -KeyId "uuid-xxx"
```

### Permissions
- `read` - Lesezugriff
- `write` - Schreibzugriff
- `admin` - Admin-Zugriff

### Audit-Logs

```powershell
# Aktion protokollieren
Write-AuditLog -Action Sync -ResourceType "sync_data" -Details @{ "records" = 10; "duration_ms" = 500 }

# Logs abrufen
Get-AuditLogs -Limit 100
Get-AuditLogs -Limit 50 -Action "sync"

# Aktionen filtern nach Typ
Get-AuditLogs -Action "login"
Get-AuditLogs -Action "api_key_created"
```

### AuditAction Types
- `Login`, `Logout`
- `Sync`
- `FileUpload`, `FileDownload`, `FileDelete`
- `SettingsChange`
- `ApiKeyCreated`, `ApiKeyUsed`, `ApiKeyRevoked`
- `WebhookTriggered`
- `GoalAchieved`

### Files

```powershell
# File-Upload aufzeichnen
Record-FileUpload -FileName "backup.json" -MimeType "application/json" -FileSize 1024 -Checksum "abc123..."

# Files auflisten
Get-Files -Limit 20

# File löschen
Remove-File -FileId "uuid-xxx"
```

### OAuth

```powershell
# OAuth-Provider verknüpfen
Link-OAuthProvider -Provider Google -ProviderId "google-123" -ProviderEmail "user@gmail.com"

Link-OAuthProvider -Provider GitHub -ProviderId "github-456" -ProviderEmail "user@github.com"

# Verknüpfte Provider abrufen
Get-LinkedProviders
```

### AuthProvider Types
- `Google`
- `GitHub`
- `Apple`
- `Microsoft`

### Rate Limiting

```powershell
# Rate-Limit prüfen
$allowed = Test-RateLimit -Endpoint "sync" -Limit 100

if ($allowed) {
    # Anfrage durchführen
} else {
    # Rate-Limited - später erneut versuchen
}
```

### Sessions

Sessions werden automatisch vom System verwaltet. Für direkte Nutzung:

```sql
-- Session erstellen (via Direct SQL)
SELECT * FROM create_session('user-id', 'device-id');

-- Session validieren
SELECT * FROM validate_session('token');

-- Session widerrufen
SELECT revoke_session('session-id');
```

## Konfiguration

In `config.ini`:

```ini
# Security & Storage
SecurityEnabled=True
ApiKeyRateLimit=100
```

## Sicherheitshinweise

### API-Key Sicherheit
- API-Keys werden nur **einmal** bei der Erstellung angezeigt
- Speichern Sie den Key sofort sicher (z.B. Password Manager)
- Verwenden Sie Keys nicht in URLs (nutzen Sie Header)
- Rotieren Sie Keys regelmäßig

### Token-Verschlüsselung
- Access/Refresh-Tokens werden mit AES256 verschlüsselt
- Token haben definierte Ablaufzeiten
- Sessions können jederzeit widerrufen werden

### Audit-Compliance
- Alle sicherheitsrelevanten Aktionen werden protokolliert
- IP-Adressen und User-Agents werden erfasst
- Logs werden für 90 Tage aufbewahrt (konfigurierbar)

### Rate Limiting
- Standard: 100 Anfragen pro Minute
- Bei Überschreitung: 1 Minute Blockierung
- Keys mit `admin`-Permission haben höhere Limits
