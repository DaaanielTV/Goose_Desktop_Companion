# Server-seitiges Streamer Mode Backend

Dieses Dokument beschreibt die server-seitige Implementierung des Streamer Mode für Desktop Goose mit Twitch/YouTube Integration.

## Architektur

```
┌──────────────────┐     ┌──────────────────┐
│  Twitch/YouTube   │────▶│  Supabase        │
│  Webhooks        │     │  Backend         │
│                  │     │                  │
│ • Follows        │     │ • Edge Functions │
│ • Subs           │     │ • Webhook Handler│
│ • Donations      │     │ • Database       │
│ • Raids         │     │ • Realtime        │
│ • Chat           │     │                  │
└──────────────────┘     └──────────────────┘
         │
         ▼
┌──────────────────┐
│  Desktop Goose   │
│  Streamer Mode  │
│                  │
│ • Chaos Events  │
│ • Chat Commands │
│ • Alerts        │
└──────────────────┘
```

## Datenbank Schema

### Streamer Config

```sql
CREATE TABLE streamer_config (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) UNIQUE,
    platform VARCHAR(50), -- twitch, youtube
    channel_name VARCHAR(255),
    chat_enabled BOOLEAN DEFAULT true,
    alert_enabled BOOLEAN DEFAULT true,
    chaos_enabled BOOLEAN DEFAULT true,
    min_donation_for_chaos DECIMAL(10,2) DEFAULT 5,
    min_bits_for_chaos INTEGER DEFAULT 100,
    custom_commands JSONB DEFAULT '[]',
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Stream Events

```sql
CREATE TABLE stream_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id),
    platform VARCHAR(50), -- twitch, youtube
    event_type VARCHAR(50), -- follow, sub, donation, raid, bits, chat
    username VARCHAR(255),
    amount DECIMAL(10,2),
    message TEXT,
    tier VARCHAR(10), -- for subs
    viewers INTEGER, -- for raids
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Index für schnelle Queries
CREATE INDEX idx_stream_events_user ON stream_events(user_id);
CREATE INDEX idx_stream_events_created ON stream_events(created_at DESC);
```

### Custom Commands

```sql
CREATE TABLE streamer_commands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id),
    command VARCHAR(100) NOT NULL,
    response TEXT NOT NULL,
    chaos_enabled BOOLEAN DEFAULT false,
    chaos_type VARCHAR(50),
    usage_count INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, command)
);
```

### Stream Analytics

```sql
CREATE TABLE stream_analytics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id),
    date DATE NOT NULL,
    followers_gained INTEGER DEFAULT 0,
    subs_gained INTEGER DEFAULT 0,
    donations_total DECIMAL(10,2) DEFAULT 0,
    bits_total INTEGER DEFAULT 0,
    raid_total INTEGER DEFAULT 0,
    chat_messages INTEGER DEFAULT 0,
    chaos_events INTEGER DEFAULT 0,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, date)
);
```

## Edge Functions

### Configure Streamer

```typescript
// supabase/functions/configure-streamer/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

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
  
  const config = await req.json()
  
  const { data, error } = await supabase
    .from('streamer_config')
    .upsert({
      user_id: user.id,
      platform: config.platform,
      channel_name: config.channelName,
      chat_enabled: config.chatEnabled ?? true,
      alert_enabled: config.alertEnabled ?? true,
      chaos_enabled: config.chaosEnabled ?? true,
      min_donation_for_chaos: config.minDonationForChaos ?? 5,
      min_bits_for_chaos: config.minBitsForChaos ?? 100,
      custom_commands: config.customCommands ?? [],
      updated_at: new Date().toISOString()
    }, { onConflict: 'user_id' })
    .select()
    .single()
  
  if (error) return new Response(JSON.stringify({ error }), { status: 500 })
  
  return new Response(JSON.stringify({ success: true, config: data }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

### Twitch Webhook Handler

```typescript
// supabase/functions/webhook-twitch/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { createHmac } from 'https://deno.land/std/node/crypto.ts'

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
const TWITCH_SECRET = Deno.env.get('TWITCH_WEBHOOK_SECRET')!

serve(async (req) => {
  const signature = req.headers.get('x-hub-signature')
  const body = await req.text()
  
  // Verify Twitch signature
  const hmac = createHmac('sha256', TWITCH_SECRET)
  hmac.update(body)
  const expectedSignature = 'sha256=' + hmac.digest('hex')
  
  if (signature !== expectedSignature) {
    return new Response(JSON.stringify({ error: 'Invalid signature' }), { status: 401 })
  }
  
  const payload = JSON.parse(body)
  const challenge = req.headers.get('twitch-eventsub-message-type')
  
  // Handle subscription verification
  if (challenge === 'webhook_callback_verification') {
    return new Response(payload.challenge, { 
      headers: { 'Content-Type': 'text/plain' }
    })
  }
  
  // Get streamer config
  const { data: config } = await supabase
    .from('streamer_config')
    .select('user_id, chaos_enabled, min_donation_for_chaos, min_bits_for_chaos')
    .eq('platform', 'twitch')
    .single()
  
  if (!config) {
    return new Response(JSON.stringify({ error: 'Streamer not configured' }), { status: 404 })
  }
  
  // Process event
  const eventType = payload.subscription?.type
  const eventData = payload.event
  
  let eventRecord = {
    user_id: config.user_id,
    platform: 'twitch',
    event_type: eventType,
    username: eventData?.user_name || '',
    amount: 0,
    message: ''
  }
  
  switch (eventType) {
    case 'channel.follow':
      eventRecord.event_type = 'follow'
      break
      
    case 'channel.subscribe':
      eventRecord.event_type = 'sub'
      eventRecord.amount = parseInt(eventData?.sub_plan || '0')
      eventRecord.tier = eventData?.sub_plan
      break
      
    case 'channel.channel_points_custom_reward_redemption':
      eventRecord.event_type = 'redemption'
      eventRecord.amount = eventData?.redemption?.cost || 0
      eventRecord.message = eventData?.redemption?.user_input || ''
      break
      
    case 'channel.cheer':
      eventRecord.event_type = 'bits'
      eventRecord.amount = parseInt(eventData?.bits || '0')
      eventRecord.message = eventData?.message || ''
      break
      
    case 'channel.raid':
      eventRecord.event_type = 'raid'
      eventRecord.viewers = parseInt(eventData?.viewers || '0')
      eventRecord.username = eventData?.from_broadcaster_user_name || ''
      break
  }
  
  // Save event
  const { data: savedEvent, error } = await supabase
    .from('stream_events')
    .insert(eventRecord)
    .select()
    .single()
  
  // Determine if chaos should trigger
  let chaosEvent = null
  if (config.chaos_enabled) {
    if (eventType === 'channel.cheer' && eventRecord.amount >= config.min_bits_for_chaos) {
      chaosEvent = { type: 'HonkStorm', amount: eventRecord.amount }
    } else if (eventRecord.event_type === 'sub') {
      chaosEvent = { type: 'GooseDance' }
    } else if (eventType === 'channel.raid' && eventRecord.viewers >= 50) {
      chaosEvent = { type: 'ScreenSpin', viewers: eventRecord.viewers }
    }
  }
  
  // Send realtime notification to client
  await supabase.channel(`streamer:${config.user_id}`).send({
    type: 'broadcast',
    event: 'stream_event',
    payload: {
      event: savedEvent,
      chaos: chaosEvent
    }
  })
  
  return new Response(JSON.stringify({ 
    success: true, 
    event: savedEvent,
    chaos: chaosEvent 
  }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

### YouTube Webhook Handler

```typescript
// supabase/functions/webhook-youtube/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

serve(async (req) => {
  const payload = await req.json()
  
  // Get notification type
  const notificationType = payload.notificationType
  const channelId = payload.channelId
  
  // Find streamer config
  const { data: config } = await supabase
    .from('streamer_config')
    .select('user_id, chaos_enabled')
    .eq('platform', 'youtube')
    .eq('channel_name', channelId)
    .single()
  
  if (!config) {
    return new Response(JSON.stringify({ error: 'Streamer not configured' }), { status: 404 })
  }
  
  let eventRecord = {
    user_id: config.user_id,
    platform: 'youtube',
    event_type: notificationType,
    username: payload.channelTitle || '',
    amount: 0,
    message: ''
  }
  
  switch (notificationType) {
    case 'subscription':
      eventRecord.event_type = 'sub'
      eventRecord.amount = 1
      break
    case 'like':
    case 'superdchat':
      eventRecord.event_type = 'donation'
      eventRecord.amount = parseFloat(payload.amount || '0')
      eventRecord.message = payload.messageText || ''
      break
  }
  
  await supabase.from('stream_events').insert(eventRecord)
  
  return new Response(JSON.stringify({ success: true }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

## API Endpoints

| Method | Endpoint | Beschreibung |
|--------|----------|--------------|
| POST | `/functions/v1/configure-streamer` | Streamer konfigurieren |
| GET | `/streamer_config` | Konfiguration abrufen |
| POST | `/functions/v1/webhook-twitch` | Twitch Webhook |
| POST | `/functions/v1/webhook-youtube` | YouTube Webhook |
| GET | `/stream_events` | Events abrufen |
| POST | `/streamer_commands` | Command hinzufügen |

## Client-Integration

### Streamer konfigurieren

```powershell
function Configure-StreamerServer {
    param(
        [string]$Platform = "twitch",
        [string]$ChannelName,
        [bool]$ChaosEnabled = $true,
        [decimal]$MinDonation = 5,
        [int]$MinBits = 100
    )
    
    $response = Invoke-RestMethod -Uri "http://localhost:8000/functions/v1/configure-streamer" `
        -Method Post `
        -Headers @{
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $env:GOOSE_TOKEN"
        } `
        -Body (@{
            platform = $Platform
            channelName = $ChannelName
            chaosEnabled = $ChaosEnabled
            minDonationForChaos = $MinDonation
            minBitsForChaos = $MinBits
        } | ConvertTo-Json)
    
    return $response
}
```

### Stream Events empfangen (Polling)

```powershell
function Start-StreamEventListener {
    param(
        [string]$UserId,
        [string]$Token
    )
    
    while ($true) {
        # Letzte Events abrufen
        $events = Invoke-RestMethod -Uri "http://localhost:8000/rest/v1/stream_events?user_id=eq.$UserId&order=created_at.desc&limit=5" `
            -Headers @{
                "apikey" = $env:SUPABASE_ANON_KEY
                "Authorization" = "Bearer $Token"
            }
        
        foreach ($event in $events) {
            switch ($event.event_type) {
                "follow" {
                    Write-Host "🎉 Neuer Follower: $($event.username)"
                    if ($config.alertEnabled) { Show-FollowAlert -Username $event.username }
                }
                "sub" {
                    Write-Host "⭐ Neuer Sub: $($event.username) (Tier $($event.tier))"
                    if ($config.chaosEnabled) { Execute-ChaosEvent -Type "GooseDance" }
                }
                "donation" {
                    Write-Host "💰 Donation: $$($event.amount) von $($event.username)"
                    if ($event.amount -ge $config.minDonationForChaos -and $config.chaosEnabled) {
                        Execute-ChaosEvent -Type "EmojiExplosion"
                    }
                }
                "bits" {
                    Write-Host "💎 Bits: $($event.amount) von $($event.username)"
                    if ($event.amount -ge $config.minBitsForChaos -and $config.chaosEnabled) {
                        Execute-ChaosEvent -Type "HonkStorm"
                    }
                }
                "raid" {
                    Write-Host "🏴‍☠️ Raid: $($event.username) mit $($event.viewers) Zuschauern"
                    if ($event.viewers -ge 50 -and $config.chaosEnabled) {
                        Execute-ChaosEvent -Type "ScreenSpin"
                    }
                }
            }
        }
        
        Start-Sleep -Seconds 3
    }
}
```

### Custom Commands verwalten

```powershell
function Add-StreamCommandServer {
    param(
        [string]$Command,
        [string]$Response,
        [bool]$ChaosEnabled = $false,
        [string]$ChaosType = ""
    )
    
    $response = Invoke-RestMethod -Uri "http://localhost:8000/rest/v1/streamer_commands" `
        -Method Post `
        -Headers @{
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $env:GOOSE_TOKEN"
            "apikey" = $env:SUPABASE_ANON_KEY
        } `
        -Body (@{
            command = $Command
            response = $Response
            chaos_enabled = $ChaosEnabled
            chaos_type = $ChaosType
        } | ConvertTo-Json)
    
    return $response
}
```

## Webhook URL Konfiguration

### Twitch

1. Gehe zu https://dev.twitch.tv/console
2. Wähle "Events" → "Webhooks"
3. Füge Subscription hinzu:
   - `https://your-server.com/functions/v1/webhook-twitch`
   - Events: `channel.follow`, `channel.subscribe`, `channel.cheer`, `channel.raid`

### YouTube

1. Gehe zu https://console.cloud.google.com/
2. Erstelle Pub/Sub Topic
3. Konfiguriere Webhook Subscription auf:
   - `https://your-server.com/functions/v1/webhook-youtube`

## Sicherheit

### RLS Policies

```sql
-- Streamer kann nur eigene Config sehen
CREATE POLICY "Own streamer config"
ON streamer_config FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- Events sind öffentlich lesbar
CREATE POLICY "Events are readable"
ON stream_events FOR SELECT
USING (true);

-- Commands nur für Owner
CREATE POLICY "Own commands"
ON streamer_commands FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
```

---

*Weitere Details finden Sie in [SERVER-FEATURES.md](./SERVER-FEATURES.md)*
