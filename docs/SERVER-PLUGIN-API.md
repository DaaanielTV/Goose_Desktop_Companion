# Server-seitige Plugin API

Dieses Dokument beschreibt die server-seitige Implementierung der Plugin API für Desktop Goose.

## Architektur

```
┌──────────────────┐     ┌──────────────────┐
│  Desktop Goose   │────▶│  Supabase        │
│  Client          │     │  Backend         │
│                  │     │                  │
│ • Plugin Manager │     │ • Edge Functions │
│ • Plugin Loader  │     │ • Database       │
│ • Hook System    │     │ • Realtime       │
└──────────────────┘     └──────────────────┘
```

## Datenbank Schema

### Plugin Registry

```sql
CREATE TABLE plugin_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plugin_id VARCHAR(100) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    author VARCHAR(255),
    version VARCHAR(50),
    category VARCHAR(50), -- plugin, skin, behavior, theme
    download_url TEXT,
    image_url TEXT,
    tags TEXT[],
    downloads INTEGER DEFAULT 0,
    rating DECIMAL(3,2) DEFAULT 0,
    is_verified BOOLEAN DEFAULT false,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Plugin Versions

```sql
CREATE TABLE plugin_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    plugin_id VARCHAR(100) REFERENCES plugin_registry(plugin_id),
    version VARCHAR(50) NOT NULL,
    min_goose_version VARCHAR(50),
    download_url TEXT,
    changelog TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### User Plugins

```sql
CREATE TABLE user_plugins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id),
    plugin_id VARCHAR(100) REFERENCES plugin_registry(plugin_id),
    installed_at TIMESTAMPTZ DEFAULT NOW(),
    enabled BOOLEAN DEFAULT true,
    config JSONB DEFAULT '{}'
);
```

## Edge Functions

### Get Plugins

```typescript
// supabase/functions/get-plugins/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

serve(async (req) => {
  const { category, limit, offset } = await req.json()
  
  let query = supabase
    .from('plugin_registry')
    .select('*')
    .order('downloads', { ascending: false })
  
  if (category) {
    query = query.eq('category', category)
  }
  
  const { data, error } = await query
    .range(offset || 0, (limit || 20) - 1)
  
  if (error) return new Response(JSON.stringify({ error }), { status: 500 })
  
  return new Response(JSON.stringify({ plugins: data }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

### Submit Plugin

```typescript
// supabase/functions/submit-plugin/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { v4 as uuidv4 } from 'https://esm.sh/uuid@9'

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

serve(async (req) => {
  const authHeader = req.headers.get('Authorization')
  if (!authHeader) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
  }
  
  const token = authHeader.replace('Bearer ', '')
  const { data: { user }, error: authError } = await supabase.auth.getUser(token)
  
  if (authError || !user) {
    return new Response(JSON.stringify({ error: 'Invalid token' }), { status: 401 })
  }
  
  const plugin = await req.json()
  
  const { data, error } = await supabase
    .from('plugin_registry')
    .insert({
      plugin_id: plugin.pluginId || uuidv4(),
      name: plugin.name,
      description: plugin.description,
      author: user.email,
      version: plugin.version,
      category: plugin.category,
      download_url: plugin.downloadUrl,
      image_url: plugin.imageUrl,
      tags: plugin.tags || []
    })
    .select()
    .single()
  
  if (error) return new Response(JSON.stringify({ error }), { status: 500 })
  
  return new Response(JSON.stringify({ success: true, plugin: data }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

### Rate Plugin

```typescript
// supabase/functions/rate-plugin/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

serve(async (req) => {
  const { plugin_id, rating, review } = await req.json()
  
  const { data: existing } = await supabase
    .from('marketplace_ratings')
    .select('*')
    .eq('plugin_id', plugin_id)
    .single()
  
  if (existing) {
    await supabase
      .from('marketplace_ratings')
      .update({ rating, review })
      .eq('id', existing.id)
  } else {
    await supabase
      .from('marketplace_ratings')
      .insert({ plugin_id, rating, review })
  }
  
  // Update average rating
  const { data: ratings } = await supabase
    .from('marketplace_ratings')
    .select('rating')
    .eq('plugin_id', plugin_id)
  
  const avgRating = ratings.reduce((a, b) => a + b.rating, 0) / ratings.length
  
  await supabase
    .from('plugin_registry')
    .update({ rating: avgRating })
    .eq('plugin_id', plugin_id)
  
  return new Response(JSON.stringify({ success: true, rating: avgRating }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

## API Endpoints

| Method | Endpoint | Beschreibung |
|--------|----------|--------------|
| GET | `/rest/v1/plugin_registry` | Alle Plugins abrufen |
| POST | `/rest/v1/plugin_registry` | Plugin einreichen |
| GET | `/functions/v1/get-plugins` | Plugins mit Filter |
| POST | `/functions/v1/submit-plugin` | Plugin einreichen |
| POST | `/functions/v1/rate-plugin` | Plugin bewerten |
| GET | `/functions/v1/search-plugins?q=` | Plugins suchen |

## Client-Integration

### Plugin herunterladen

```powershell
function Install-PluginFromServer {
    param(
        [string]$PluginId
    )
    
    $response = Invoke-RestMethod -Uri "http://localhost:8000/functions/v1/download-plugin" `
        -Method Post `
        -Headers @{
            "Authorization" = "Bearer $env:GOOSE_TOKEN"
            "Content-Type" = "application/json"
        } `
        -Body (@{ pluginId = $PluginId } | ConvertTo-Json)
    
    # Plugin herunterladen und entpacken
    $zipPath = "$env:TEMP\$PluginId.zip"
    Invoke-WebRequest -Uri $response.downloadUrl -OutFile $zipPath
    
    Expand-Archive -Path $zipPath -DestinationPath "$PSScriptRoot\plugins\$PluginId" -Force
    
    return $response
}
```

### Plugin Registry synchronisieren

```powershell
function Sync-PluginRegistry {
    $response = Invoke-RestMethod -Uri "http://localhost:8000/rest/v1/plugin_registry?select=*" `
        -Headers @{
            "apikey" = $env:SUPABASE_ANON_KEY
        }
    
    return $response
}
```

## Sicherheit

### RLS Policies

```sql
-- Plugins sind öffentlich lesbar
CREATE POLICY "Plugins are public readable"
ON plugin_registry FOR SELECT
USING (true);

-- Nur authentifizierte Benutzer können Plugins einreichen
CREATE POLICY "Users can insert plugins"
ON plugin_registry FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- Plugins können nur vom Autor aktualisiert werden
CREATE POLICY "Authors can update own plugins"
ON plugin_registry FOR UPDATE
USING (auth.uid() = author_id);
```

---

*Weitere Details finden Sie in [SERVER-FEATURES.md](./SERVER-FEATURES.md)*
