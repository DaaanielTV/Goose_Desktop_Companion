# Server-seitiges Multiplayer Backend

Dieses Dokument beschreibt die server-seitige Implementierung des Multiplayer-Systems für Desktop Goose mittels Supabase Realtime.

## Architektur

```
┌──────────────────┐     ┌──────────────────┐
│  Desktop Goose   │────▶│  Supabase        │
│  Multiplayer     │     │  Backend         │
│                  │     │                  │
│ • Connect        │     │ • Realtime       │
│ • Friends        │     │ • Database       │
│ • Messages       │     │ • Edge Functions │
│ • Visits/Duels  │     │                  │
└──────────────────┘     └──────────────────┘
         │                        │
         │    WebSocket           │
         └────────────────────────┘
```

## Datenbank Schema

### Multiplayer Friends

```sql
CREATE TABLE multiplayer_friends (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id),
    friend_code VARCHAR(6) NOT NULL,
    friend_name VARCHAR(255),
    friend_avatar VARCHAR(500),
    status VARCHAR(50) DEFAULT 'pending', -- pending, accepted, blocked
    created_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE(user_id, friend_code)
);
```

### Multiplayer Messages

```sql
CREATE TABLE multiplayer_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    from_user_id UUID REFERENCES auth.users(id),
    to_user_id UUID REFERENCES auth.users(id),
    message_type VARCHAR(50), -- message, visit, duel, invasion
    content TEXT,
    read_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW()
);
```

### Active Sessions (für Realtime)

```sql
CREATE TABLE active_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id),
    connection_code VARCHAR(6),
    status VARCHAR(50) DEFAULT 'online',
    last_seen TIMESTAMPTZ DEFAULT NOW(),
    current_location VARCHAR(100), -- desktop, visiting
    UNIQUE(user_id)
);
```

### Duell Results

```sql
CREATE TABLE multiplayer_duels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    challenger_id UUID REFERENCES auth.users(id),
    challenged_id UUID REFERENCES auth.users(id),
    challenger_score INTEGER DEFAULT 0,
    challenged_score INTEGER DEFAULT 0,
    winner_id UUID REFERENCES auth.users(id),
    status VARCHAR(50) DEFAULT 'pending', -- pending, active, completed, cancelled
    started_at TIMESTAMPTZ DEFAULT NOW(),
    ended_at TIMESTAMPTZ
);
```

## Edge Functions

### Register Player

```typescript
// supabase/functions/register-player/index.ts
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
  
  const { playerName } = await req.json()
  
  // Generate unique connection code
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'
  let connectionCode = ''
  for (let i = 0; i < 6; i++) {
    connectionCode += chars[Math.floor(Math.random() * chars.length)]
  }
  
  // Create or update session
  const { data: session, error } = await supabase
    .from('active_sessions')
    .upsert({
      user_id: user.id,
      connection_code: connectionCode,
      status: 'online',
      last_seen: new Date().toISOString()
    }, { onConflict: 'user_id' })
    .select()
    .single()
  
  if (error) return new Response(JSON.stringify({ error }), { status: 500 })
  
  return new Response(JSON.stringify({
    success: true,
    playerId: user.id,
    connectionCode,
    playerName: playerName || 'GoosePlayer'
  }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

### Send Message

```typescript
// supabase/functions/send-message/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

serve(async (req) => {
  const authHeader = req.headers.get('Authorization')
  const token = authHeader?.replace('Bearer ', '') || ''
  
  const { data: { user } } = await supabase.auth.getUser(token)
  if (!user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
  }
  
  const { toUserId, content, messageType = 'message' } = await req.json()
  
  const { data: message, error } = await supabase
    .from('multiplayer_messages')
    .insert({
      from_user_id: user.id,
      to_user_id: toUserId,
      message_type: messageType,
      content
    })
    .select()
    .single()
  
  if (error) return new Response(JSON.stringify({ error }), { status: 500 })
  
  // Trigger realtime notification
  await supabase.channel(`user:${toUserId}`).send({
    type: 'broadcast',
    event: 'new_message',
    payload: message
  })
  
  return new Response(JSON.stringify({ success: true, message }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

### Initiate Visit

```typescript
// supabase/functions/initiate-visit/index.ts
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const supabase = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)

serve(async (req) => {
  const authHeader = req.headers.get('Authorization')
  const token = authHeader?.replace('Bearer ', '') || ''
  
  const { data: { user } } = await supabase.auth.getUser(token)
  if (!user) {
    return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
  }
  
  const { friendCode } = await req.json()
  
  // Find friend's session
  const { data: friend } = await supabase
    .from('active_sessions')
    .select('user_id, connection_code')
    .eq('connection_code', friendCode)
    .single()
  
  if (!friend) {
    return new Response(JSON.stringify({ error: 'Friend not online' }), { status: 404 })
  }
  
  // Create visit message
  const { data: message, error } = await supabase
    .from('multiplayer_messages')
    .insert({
      from_user_id: user.id,
      to_user_id: friend.user_id,
      message_type: 'visit',
      content: 'is visiting your desktop!'
    })
    .select()
    .single()
  
  if (error) return new Response(JSON.stringify({ error }), { status: 500 })
  
  // Send realtime notification
  await supabase.channel(`user:${friend.user_id}`).send({
    type: 'broadcast',
    event: 'goose_visiting',
    payload: {
      fromUserId: user.id,
      message: message
    }
  })
  
  return new Response(JSON.stringify({
    success: true,
    visitId: message.id,
    targetUserId: friend.user_id
  }), {
    headers: { 'Content-Type': 'application/json' }
  })
})
```

## Supabase Realtime

### Client Subscription

```powershell
# PowerShell Client
function Connect-MultiplayerRealtime {
    param(
        [string]$UserId,
        [string]$Token
    )
    
    # Realtime Channel für Nachrichten
    $channel = @{
        event = 'INSERT'
        schema = 'public'
        table = 'multiplayer_messages'
        filter = "to_user_id=eq.$UserId"
    }
    
    # Dies würde in einer echten Implementierung via WebSocket funktionieren
    # Für PowerShell: Polling alle 5 Sekunden
    
    while ($true) {
        $messages = Invoke-RestMethod -Uri "http://localhost:8000/rest/v1/multiplayer_messages?to_user_id=eq.$UserId&order=created_at.desc&limit=1" `
            -Headers @{
                "apikey" = $env:SUPABASE_ANON_KEY
                "Authorization" = "Bearer $Token"
            }
        
        if ($messages -and $messages.Count -gt 0) {
            $latestMessage = $messages[0]
            
            if ($latestMessage.message_type -eq 'visit') {
                Write-Host "🦆 Eine Gans besucht dich!"
                # Trigger visit animation
            }
            elseif ($latestMessage.message_type -eq 'duell') {
                Write-Host "⚔️ Duell-Herausforderung!"
                # Show duel prompt
            }
            else {
                Write-Host "📬 $($latestMessage.content)"
            }
        }
        
        Start-Sleep -Seconds 5
    }
}
```

### Broadcast Events

```typescript
// Server-seitig: Event senden
await supabase.channel('multiplayer:global').send({
  type: 'broadcast',
  event: 'friend_online',
  payload: { friendCode: 'ABC123', name: 'John' }
})
```

## API Endpoints

| Method | Endpoint | Beschreibung |
|--------|----------|--------------|
| POST | `/functions/v1/register-player` | Spieler registrieren |
| GET | `/functions/v1/get-friends` | Freundesliste |
| POST | `/functions/v1/send-message` | Nachricht senden |
| POST | `/functions/v1/initiate-visit` | Besuch starten |
| POST | `/functions/v1/duell-start` | Duell initiieren |
| GET | `/rest/v1/multiplayer_messages` | Nachrichten abrufen |
| Realtime | Channel `multiplayer` | Live Updates |

## Client-Integration

### Mit Server verbinden

```powershell
function Connect-MultiplayerServer {
    param(
        [string]$PlayerName = "GoosePlayer"
    )
    
    $response = Invoke-RestMethod -Uri "http://localhost:8000/functions/v1/register-player" `
        -Method Post `
        -Headers @{
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $env:GOOSE_TOKEN"
        } `
        -Body (@{ playerName = $PlayerName } | ConvertTo-Json)
    
    if ($response.success) {
        $env:MULTIPLAYER_CODE = $response.connectionCode
        $env:PLAYER_ID = $response.playerId
        
        Write-Host "Verbunden! Dein Code: $($response.connectionCode)"
    }
    
    return $response
}
```

### Freund einladen

```powershell
function Invite-FriendServer {
    param(
        [string]$FriendCode
    )
    
    $response = Invoke-RestMethod -Uri "http://localhost:8000/functions/v1/send-invite" `
        -Method Post `
        -Headers @{
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $env:GOOSE_TOKEN"
        } `
        -Body (@{ friendCode = $FriendCode } | ConvertTo-Json)
    
    return $response
}
```

### Nachricht senden

```powershell
function Send-MultiplayerMessage {
    param(
        [string]$ToUserId,
        [string]$Content
    )
    
    $response = Invoke-RestMethod -Uri "http://localhost:8000/functions/v1/send-message" `
        -Method Post `
        -Headers @{
            "Content-Type" = "application/json"
            "Authorization" = "Bearer $env:GOOSE_TOKEN"
        } `
        -Body (@{
            toUserId = $ToUserId
            content = $Content
            messageType = "message"
        } | ConvertTo-Json)
    
    return $response
}
```

## Sicherheit

### RLS Policies

```sql
-- Nur Freunde können Nachrichten lesen
CREATE POLICY "Friends can read messages"
ON multiplayer_messages FOR SELECT
USING (
  from_user_id = auth.uid() OR 
  to_user_id = auth.uid()
);

-- Nur authentifizierte können senden
CREATE POLICY "Authenticated can send"
ON multiplayer_messages FOR INSERT
WITH CHECK (auth.role() = 'authenticated');

-- Nur aktive Sessions können online sein
CREATE POLICY "Own session only"
ON active_sessions FOR ALL
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);
```

---

*Weitere Details finden Sie in [SERVER-FEATURES.md](./SERVER-FEATURES.md)*
