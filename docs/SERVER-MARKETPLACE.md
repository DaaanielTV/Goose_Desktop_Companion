# Server-seitiges Marketplace Backend

Dieses Dokument beschreibt die server-seitige Implementierung des Marketplace-Systems für Desktop Goose.

## Architektur

```
┌──────────────────┐     ┌──────────────────┐
│  Desktop Goose   │────▶│  Supabase        │
│  Marketplace     │     │  Backend         │
│                  │     │                  │
│ • Browse         │     │ • Storage        │
│ • Search         │     │ • Edge Functions │
│ • Install/Uninstall     │ • CDN (optional) │
└──────────────────┘     └──────────────────┘
```

## Datenbank Schema

### Marketplace Ratings

```sql
CREATE TABLE marketplace_ratings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plugin_id VARCHAR(100) REFERENCES plugin_registry(plugin_id),
    user_id UUID REFERENCES auth.users(id),
    rating INTEGER CHECK (rating >= 1 AND rating <= 5),
    review TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(plugin_id, user_id)
);
```

### Featured Items

```sql
CREATE TABLE featured_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plugin_id VARCHAR(100) REFERENCES plugin_registry(plugin_id),
    featured_date DATE,
    position INTEGER,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Categories

```sql
CREATE TABLE plugin_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(100) UNIQUE NOT NULL,
    description TEXT,
    icon VARCHAR(50),
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Standard-Kategorien
INSERT INTO plugin_categories (name, description, icon) VALUES
('Plugins', 'Erweitere die Funktionalität', '🔌'),
('Skins', 'Ändere das Aussehen der Gans', '🎨'),
('Behaviors', 'Neues Verhalten für die Gans', '🎭'),
('Themes', 'UI-Themen und Stile', '🌈');
```

## Storage Struktur

```
storage/
├── plugins/
│   ├── {plugin_id}/
│   │   ├── manifest.json
│   │   ├── main.ps1
│   │   ├── config.ini
│   │   └── assets/
│   │       └── sprites/
├── skins/
│   ├── {skin_id}/
│   │   ├── manifest.json
│   │   └── sprites/
├── behaviors/
│   └── {behavior_id}/
└── themes/
    └── {theme_id}/
```

## Edge Functions

### Search Plugins

```typescript
// supabase/functions/search-plugins/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

serve(async (req) => {
  const { q, category, sort, limit } = await req.json()
  
  let query = supabase
    .from('plugin_registry')
    .select('*, marketplace_ratings(rating)')
  
  if (q) {
    query = query.or(`name.ilike.%${q}%,description.ilike.%${q}%`)
  }
  
  if (category) {
    query = query.eq('category', category)
  }
  
  switch (sort) {
    case 'rating':
      query = query.order('rating', { ascending: false })
      break
    case 'newest':
      query = query.order('created_at', { ascending: false })
      break
    default:
      query = query.order('downloads', { ascending: false })
  }
  
  const { data, error } = await query.limit(limit || 20)
  
  if (error) return new Response(JSON.stringify({ error }), { status: 500 })
  
  return new Response(JSON.stringify({ results: data }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

### Get Featured

```typescript
// supabase/functions/get-featured/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

serve(async () => {
  const today = new Date().toISOString().split('T')[0]
  
  const { data: featured } = await supabase
    .from('featured_items')
    .select('plugin_id, position')
    .eq('featured_date', today)
    .order('position')
  
  if (!featured || featured.length === 0) {
    // Fallback zu populären Plugins
    const { data: popular } = await supabase
      .from('plugin_registry')
      .select('*')
      .order('downloads', { ascending: false })
      .limit(10)
    
    return new Response(JSON.stringify({ featured: popular }), {
      headers: { 'Content-Type': 'application/json' }
    })
  }
  
  const pluginIds = featured.map(f => f.plugin_id)
  
  const { data: plugins } = await supabase
    .from('plugin_registry')
    .select('*')
    .in('plugin_id', pluginIds)
  
  return new Response(JSON.stringify({ featured: plugins }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

### Download Plugin

```typescript
// supabase/functions/download-plugin/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { createBucketClient } from 'https://esm.sh/@supabase/storage-js@2'

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
const storage = createBucketClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

serve(async (req) => {
  const { plugin_id } = await req.json()
  
  // Get plugin info
  const { data: plugin } = await supabase
    .from('plugin_registry')
    .select('*')
    .eq('plugin_id', plugin_id)
    .single()
  
  if (!plugin) {
    return new Response(JSON.stringify({ error: 'Plugin not found' }), { status: 404 })
  }
  
  // Generate signed URL
  const { data: url } = await storage
    .from('plugins')
    .createSignedUrl(`${plugin_id}/main.ps1`, 3600) // 1 hour
  
  // Increment download count
  await supabase
    .from('plugin_registry')
    .update({ downloads: plugin.downloads + 1 })
    .eq('plugin_id', plugin_id)
  
  return new Response(JSON.stringify({
    downloadUrl: url.signedUrl,
    version: plugin.version,
    name: plugin.name
  }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

## API Endpoints

| Method | Endpoint | Beschreibung |
|--------|----------|--------------|
| GET | `/functions/v1/search-plugins` | Plugins durchsuchen |
| GET | `/functions/v1/get-featured` | Featured Items |
| POST | `/functions/v1/download-plugin` | Download-URL generieren |
| POST | `/functions/v1/rate-plugin` | Plugin bewerten |
| GET | `/functions/v1/get-categories` | Kategorien abrufen |

## Client-Integration

### Marketplace durchsuchen

```powershell
function Search-MarketplaceServer {
    param(
        [string]$Query,
        [string]$Category = "",
        [string]$SortBy = "downloads"
    )
    
    $response = Invoke-RestMethod -Uri "http://localhost:8000/functions/v1/search-plugins" `
        -Method Post `
        -Headers @{
            "Content-Type" = "application/json"
            "apikey" = $env:SUPABASE_ANON_KEY
        } `
        -Body (@{
            q = $Query
            category = $Category
            sort = $SortBy
            limit = 20
        } | ConvertTo-Json)
    
    return $response.results
}
```

### Featured Items abrufen

```powershell
function Get-FeaturedFromServer {
    $response = Invoke-RestMethod -Uri "http://localhost:8000/functions/v1/get-featured" `
        -Method Get `
        -Headers @{
            "apikey" = $env:SUPABASE_ANON_KEY
        }
    
    return $response.featured
}
```

### Plugin installieren

```powershell
function Install-PluginFromMarketplace {
    param(
        [string]$PluginId
    )
    
    # Download URL holen
    $download = Invoke-RestMethod -Uri "http://localhost:8000/functions/v1/download-plugin" `
        -Method Post `
        -Headers @{
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $env:GOOSE_TOKEN"
        } `
        -Body (@{ pluginId = $PluginId } | ConvertTo-Json)
    
    # Herunterladen
    $zipPath = "$env:TEMP\$PluginId.zip"
    Invoke-WebRequest -Uri $download.downloadUrl -OutFile $zipPath
    
    # Entpacken
    $installPath = "$PSScriptRoot\plugins\$PluginId"
    Expand-Archive -Path $zipPath -DestinationPath $installPath -Force
    
    # Manifest lesen
    $manifest = Get-Content "$installPath\manifest.json" | ConvertFrom-Json
    
    return @{
        Success = $true
        Name = $manifest.name
        Version = $download.version
    }
}
```

## Sicherheit

### Upload Security

```sql
-- Nur authentifizierte Benutzer können hochladen
CREATE POLICY "Users can upload plugins"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'plugins' AND 
  auth.role() = 'authenticated'
);

-- Nur Plugin-Autor kann aktualisieren
CREATE POLICY "Authors can update plugins"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'plugins' AND 
  auth.uid()::text = (storage.foldername(name))[1]
);
```

### Rate Limiting

```typescript
// In Edge Function
const { data: requestCount } = await supabase
  .from('api_usage')
  .select('count')
  .eq('user_id', user.id)
  .gte('created_at', new Date(Date.now() - 60000))
  
if (requestCount >= 10) {
  return new Response(JSON.stringify({ error: 'Rate limit exceeded' }), { 
    status: 429,
    headers: { 'Retry-After': '60' }
  })
}
```

---

*Weitere Details finden Sie in [SERVER-FEATURES.md](./SERVER-FEATURES.md)*
