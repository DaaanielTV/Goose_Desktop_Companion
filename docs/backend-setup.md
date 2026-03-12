# Cloud Sync Backend Setup

Dieses Dokument beschreibt die Einrichtung der Supabase Self-Hosted Backend-Infrastruktur für Desktop Goose.

## Voraussetzungen

- Docker & Docker Compose
- PostgreSQL Kenntnisse
- (Optional) Domain/SSL für Produktion

---

## Schnellstart

### 1. Supabase starten

```bash
# Verzeichnis erstellen
mkdir -p supabase/data

# Docker Compose Datei erstellen
cat > supabase/docker-compose.yml << 'EOF'
version: '3.8'

services:
  db:
    image: supabase/postgres:15.1.0.147
    container_name: goose-supabase-db
    environment:
      POSTGRES_PASSWORD: your-secure-password
      POSTGRES_DB: postgres
    volumes:
      - ./data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  kong:
    image: kong:3.4
    container_name: goose-supabase-kong
    environment:
      KONG_DATABASE: "off"
      KONG_DECLARATIVE_CONFIG: /var/lib/kong/kong.yml
      KONG_DNS_ORDER: LAST,A,CNAME
      KONG_PLUGINS: request-transformer,cors,key-auth,acl
      KONG_PROXY_ACCESS_LOG: /dev/stdout
      KONG_ADMIN_ACCESS_LOG: /dev/stdout
      KONG_PROXY_ERROR_LOG: /stderr
      KONG_ADMIN_ERROR_LOG: /stderr
      KONG_ADMIN_LISTEN: 0.0.0.0:8001
    ports:
      - "8000:8000"
      - "8001:8001"
    volumes:
      - ./kong.yml:/var/lib/kong/kong.yml:ro
    depends_on:
      db:
        condition: service_healthy

  auth:
    image: supabase/gotrue:v2.151.0
    container_name: goose-supabase-auth
    environment:
      GOTRUE_API_HOST: 0.0.0.0
      GOTRUE_API_PORT: 9999
      API_EXTERNAL_URL: http://localhost:8000
      GOTRUE_DB_DRIVER: postgres
      GOTRUE_DB_DSN: postgres://postgres:your-secure-password@db:5432/postgres?search_path=auth
      GOTRUE_SITE_URL: http://localhost:8000
      GOTRUE_URI_ALLOW_LIST: '*'
      GOTRUE_DISABLE_SIGNUP: "false"
      GOTRUE_JWT_ADMIN_ROLES: service_role
      GOTRUE_JWT_AUD: authenticated
      GOTRUE_JWT_DEFAULT_GROUP_NAME: authenticated
      GOTRUE_JWT_EXP: 3600
      GOTRUE_JWT_SECRET: your-jwt-secret-at-least-32-chars
      GOTRUE_EXTERNAL_EMAIL_ENABLED: "true"
      GOTRUE_MAILER_AUTOCONFIRM: "true"
    ports:
      - "9999:9999"
    depends_on:
      db:
        condition: service_healthy

  meta:
    image: supabase/postgres-meta:v0.83.2
    container_name: goose-supabase-meta
    environment:
      PG_META_PORT: 8080
      PG_META_DB_HOST: db
      PG_META_DB_PORT: 5432
      PG_META_DB_NAME: postgres
      PG_META_DB_USER: postgres
      PG_META_DB_PASS: your-secure-password
    ports:
      - "8080:8080"
    depends_on:
      db:
        condition: service_healthy

  storage:
    image: supabase/storage-api:v1.11.7
    container_name: goose-supabase-storage
    environment:
      ANON_KEY: your-anon-key
      SERVICE_KEY: your-service-key
      POSTGREST_URL: http://kong:8000
      PGRST_JWT_SECRET: your-jwt-secret-at-least-32-chars
      DATABASE_URL: postgres://postgres:your-secure-password@db:5432/postgres
      FILE_SIZE_LIMIT: 52428800
      STORAGE_BACKEND: file
      FILE_STORAGE_BACKEND_PATH: /var/lib/storage
      TENANT_ID: stub
      REGION: stub
      GLOBAL_S3_BUCKET: stub
    ports:
      - "5000:5000"
    volumes:
      - ./storage:/var/lib/storage
    depends_on:
      db:
        condition: service_healthy

networks:
  default:
    name: goose-network
EOF
```

### 2. Kong Konfiguration erstellen

```bash
cat > supabase/kong.yml << 'EOF'
_format_version: "3.0"

services:
  - name: auth
    url: http://auth:9999
    routes:
      - name: auth-route
        paths:
          - /auth/v1
        strip_path: true
        plugins:
          - name: cors

  - name: meta
    url: http://meta:8080
    routes:
      - name: meta-route
        paths:
          - /meta/v1
        strip_path: true
        plugins:
          - name: cors

  - name: storage
    url: http://storage:5000
    routes:
      - name: storage-route
        paths:
          - /storage/v1
        strip_path: true
        plugins:
          - name: cors

  - name: db
    url: http://db:5432
    routes:
      - name: db-route
        paths:
          - /rest/v1
        strip_path: true
        plugins:
          - name: cors
          - name: key-auth
            config:
              key_names:
                - apikey
              key_in_header: true
              key_in_query: true

plugins:
  - name: cors
    config:
      origins:
        - "*"
      methods:
        - GET
        - POST
        - PUT
        - PATCH
        - DELETE
        - OPTIONS
      headers:
        - Accept
        - Authorization
        - Content-Type
        - apikey
      credentials: true
      max_age: 3600
EOF
```

### 3. Container starten

```bash
cd supabase
docker-compose up -d
```

---

## Datenbank Schema installieren

### Option A: Direkt via psql

```bash
docker exec -i goose-supabase-db psql -U postgres < supabase-setup.sql
```

### Option B: Über pgAdmin

1. pgAdmin installieren oder Adminer Docker Container starten
2. Mit `localhost:5432` verbinden
3. `supabase-setup.sql` ausführen

---

## Desktop Goose konfigurieren

### Keys generieren

```bash
# JWT Secret generieren (mindestens 32 Zeichen)
openssl rand -base64 32
# Beispiel: dGhpcyBpcyBhIDMyIGNoYXJhY3RlciBzZWNyZXQga2V5ISEhISEhIQ==

# Anon Key generieren
openssl rand -base64 32
# Beispiel: YW5vbiBrZXkgZm9yIGNsaWVudCBzaWRlIGFjY2Vzcw==
```

### config.ini anpassen

```ini
CloudSyncEnabled=True
SupabaseUrl=http://localhost:8000
SupabaseAnonKey=your-anon-key
SupabaseServiceKey=your-service-key
DeviceName=My-Desktop-Goose
```

---

## API Endpoints

| Endpoint | Beschreibung |
|----------|-------------|
| `POST /rest/v1/sync_data` | Daten synchronisieren |
| `GET /rest/v1/sync_data?user_id=eq.xxx` | Daten abrufen |
| `PATCH /rest/v1/sync_data?id=eq.xxx` | Daten aktualisieren |
| `DELETE /rest/v1/sync_data?id=eq.xxx` | Daten löschen |

### Auth Header

```
apikey: your-anon-key
Authorization: Bearer your-anon-key
```

---

## Troubleshooting

### Connection verweigert

```bash
# Prüfen ob Container laufen
docker ps

# Logs anzeigen
docker logs goose-supabase-db
docker logs goose-supabase-kong
```

### Datenbank Schema fehlt

```bash
# In Container rein gehen
docker exec -it goose-supabase-db psql -U postgres

# Tables prüfen
\dt
```

### CORS Fehler

Kong CORS Konfiguration prüfen in `kong.yml`:

```yaml
plugins:
  - name: cors
    config:
      origins:
        - "*"
```

---

## Production Deployment

### Mit SSL/TLS

1. Nginx Reverse Proxy mit Let's Encrypt
2. Domain konfigurieren
3. HTTP zu HTTPS redirect

### Beispiel Nginx Config

```nginx
server {
    listen 80;
    server_name goose-api.yourdomain.com;
    
    location / {
        proxy_pass http://localhost:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### Security Checklist

- [ ] Starke PostgreSQL Passwörter
- [ ] JWT Secret ändern (nicht default)
- [ ] CORS auf spezifische Domains einschränken
- [ ] Rate Limiting aktivieren
- [ ] Regelmäßige Backups
- [ ] SSL/TLS erzwingen

---

## Backup & Restore

### Backup erstellen

```bash
docker exec goose-supabase-db pg_dump -U postgres goose_db > backup_$(date +%Y%m%d).sql
```

### Restore

```bash
docker exec -i goose-supabase-db psql -U postgres goose_db < backup_20240312.sql
```

---

## Monitoring

### Health Checks

```bash
# Datenbank
curl http://localhost:5432/health

# Kong Admin
curl http://localhost:8001/status
```

### Logs

```bash
docker logs -f goose-supabase-db
docker logs -f goose-supabase-kong
docker logs -f goose-supabase-auth
```
