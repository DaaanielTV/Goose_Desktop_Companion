# Desktop Goose Multiplayer System
# Visit friends' computers and interact with other geese

enum ConnectionStatus {
    Disconnected
    Connecting
    Connected
    Error
}

enum MultiplayerEvent {
    GooseVisit
    GooseMessage
    GooseDuell
    GooseChat
}

class MultiplayerGoose {
    [string]$Id
    [string]$Name
    [string]$OwnerName
    [string]$ConnectionCode
    [ConnectionStatus]$Status
    
    MultiplayerGoose([string]$id, [string]$name) {
        $this.Id = $id
        $this.Name = $name
        $this.OwnerName = ""
        $this.ConnectionCode = ""
        $this.Status = [ConnectionStatus]::Disconnected
    }
}

class GooseMessage {
    [string]$Id
    [string]$FromGoose
    [string]$FromOwner
    [string]$Content
    [MultiplayerEvent]$Type
    [datetime]$Timestamp
    [bool]$Read
    
    GooseMessage([string]$fromGoose, [string]$fromOwner, [string]$content, [MultiplayerEvent]$type) {
        $this.Id = [guid]::NewGuid().ToString().Substring(0, 8)
        $this.FromGoose = $fromGoose
        $this.FromOwner = $fromOwner
        $this.Content = $content
        $this.Type = $type
        $this.Timestamp = Get-Date
        $this.Read = $false
    }
}

class GooseMultiplayer {
    [hashtable]$Config
    [bool]$Enabled
    [string]$PlayerId
    [string]$PlayerName
    [string]$ConnectionCode
    [ConnectionStatus]$Status
    [System.Collections.ArrayList]$ConnectedFriends
    [System.Collections.ArrayList]$Messages
    [hashtable]$PendingInvites
    [string]$DataFile
    
    GooseMultiplayer() {
        $this.Config = $this.LoadConfig()
        $this.Enabled = $false
        $this.PlayerId = [guid]::NewGuid().ToString().Substring(0, 8)
        $this.PlayerName = "GoosePlayer"
        $this.ConnectionCode = $this.GenerateConnectionCode()
        $this.Status = [ConnectionStatus]::Disconnected
        $this.ConnectedFriends = [System.Collections.ArrayList]::new()
        $this.Messages = [System.Collections.ArrayList]::new()
        $this.PendingInvites = @{}
        $this.DataFile = "goose_multiplayer.json"
        $this.LoadData()
    }
    
    [hashtable] LoadConfig() {
        $this.Config = @{}
        $configFile = "config.ini"
        
        if (Test-Path $configFile) {
            Get-Content $configFile | ForEach-Object {
                if ($_ -match '^([^=]+)=(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    
                    if ($value -eq 'True' -or $value -eq 'False') {
                        $this.Config[$key] = [bool]$value
                    } elseif ($value -match '^\d+$') {
                        $this.Config[$key] = [int]$value
                    } else {
                        $this.Config[$key] = $value
                    }
                }
            }
        }
        
        if (-not $this.Config.ContainsKey("MultiplayerEnabled")) {
            $this.Config["MultiplayerEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("MultiplayerPlayerName")) {
            $this.Config["MultiplayerPlayerName"] = "GoosePlayer"
        }
        
        return $this.Config
    }
    
    [void] LoadData() {
        if (Test-Path $this.DataFile) {
            try {
                $data = Get-Content $this.DataFile -Raw | ConvertFrom-Json
                
                $this.PlayerId = $data.playerId
                $this.PlayerName = $data.playerName
                $this.ConnectionCode = $data.connectionCode
                
                if ($data.messages) {
                    $this.Messages.Clear()
                    foreach ($m in $data.messages) {
                        $msg = [GooseMessage]::new($m.fromGoose, $m.fromOwner, $m.content, [MultiplayerEvent]$m.type)
                        $msg.Read = $m.read
                        $this.Messages.Add($msg)
                    }
                }
            } catch {}
        }
        
        $this.Enabled = $this.Config["MultiplayerEnabled"]
        $this.PlayerName = $this.Config["MultiplayerPlayerName"]
    }
    
    [void] SaveData() {
        $data = @{
            playerId = $this.PlayerId
            playerName = $this.PlayerName
            connectionCode = $this.ConnectionCode
            messages = @($this.Messages | ForEach-Object {
                @{
                    id = $_.Id
                    fromGoose = $_.FromGoose
                    fromOwner = $_.FromOwner
                    content = $_.Content
                    type = $_.Type.ToString()
                    timestamp = $_.Timestamp.ToString("o")
                    read = $_.Read
                }
            })
            lastSaved = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.DataFile -Encoding UTF8
    }
    
    [string] GenerateConnectionCode() {
        $chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
        $code = ""
        $rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
        $bytes = New-Object byte[] 1
        for ($i = 0; $i -lt 6; $i++) {
            $rng.GetBytes($bytes)
            $code += $chars[$bytes[0] % $chars.Length]
        }
        return $code
    }
    
    [hashtable] Connect() {
        $result = @{
            success = $false
            message = ""
            connectionCode = ""
        }
        
        if ($this.Status -eq [ConnectionStatus]::Connected) {
            $result.message = "Already connected"
            return $result
        }
        
        $this.Status = [ConnectionStatus]::Connecting
        
        Start-Sleep -Milliseconds 500
        
        $this.Status = [ConnectionStatus]::Connected
        
        $result.success = $true
        $result.message = "Connected to multiplayer network"
        $result.connectionCode = $this.ConnectionCode
        
        $this.SaveData()
        
        return $result
    }
    
    [hashtable] Disconnect() {
        $result = @{
            success = $false
            message = ""
        }
        
        $this.Status = [ConnectionStatus]::Disconnected
        $this.ConnectedFriends.Clear()
        
        $result.success = $true
        $result.message = "Disconnected from multiplayer network"
        
        return $result
    }
    
    [hashtable] SetPlayerName([string]$name) {
        $this.PlayerName = $name
        $this.Config["MultiplayerPlayerName"] = $name
        $this.SaveData()
        
        return @{
            success = $true
            message = "Player name set to: $name"
            playerName = $name
        }
    }
    
    [hashtable] InviteFriend([string]$friendCode) {
        $result = @{
            success = $false
            message = ""
        }
        
        if ($this.Status -ne [ConnectionStatus]::Connected) {
            $result.message = "Not connected to multiplayer network"
            return $result
        }
        
        $invite = @{
            fromCode = $this.ConnectionCode
            fromName = $this.PlayerName
            timestamp = (Get-Date).ToString("o")
            status = "pending"
        }
        
        $this.PendingInvites[$friendCode] = $invite
        
        $result.success = $true
        $result.message = "Invitation sent to $friendCode"
        
        return $result
    }
    
    [hashtable] AcceptInvite([string]$inviteCode) {
        $result = @{
            success = $false
            message = ""
        }
        
        if ($this.PendingInvites.ContainsKey($inviteCode)) {
            $invite = $this.PendingInvites[$inviteCode]
            
            $friend = [MultiplayerGoose]::new($inviteCode, "Friend's Goose")
            $friend.OwnerName = $invite.fromName
            $friend.ConnectionCode = $inviteCode
            $friend.Status = [ConnectionStatus]::Connected
            
            $this.ConnectedFriends.Add($friend)
            
            $this.PendingInvites.Remove($inviteCode)
            
            $result.success = $true
            $result.message = "Now connected with $($invite.fromName)"
        } else {
            $result.message = "No pending invitation from $inviteCode"
        }
        
        return $result
    }
    
    [hashtable] SendMessage([string]$friendId, [string]$content) {
        $result = @{
            success = $false
            message = ""
        }
        
        if ($this.Status -ne [ConnectionStatus]::Connected) {
            $result.message = "Not connected"
            return $result
        }
        
        $message = [GooseMessage]::new("MyGoose", $this.PlayerName, $content, [MultiplayerEvent]::GooseMessage)
        $this.Messages.Add($message)
        
        $result.success = $true
        $result.message = "Message sent"
        
        $this.SaveData()
        
        return $result
    }
    
    [hashtable] VisitFriend([string]$friendCode) {
        $result = @{
            success = $false
            message = ""
            visitType = ""
        }
        
        if ($this.Status -ne [ConnectionStatus]::Connected) {
            $result.message = "Not connected"
            return $result
        }
        
        $message = [GooseMessage]::new($this.PlayerName, $this.PlayerName, "is visiting!", [MultiplayerEvent]::GooseVisit)
        $this.Messages.Add($message)
        
        $result.success = $true
        $result.message = "Visiting friend with code $friendCode"
        $result.visitType = "invasion"
        
        $this.SaveData()
        
        return $result
    }
    
    [hashtable] StartDuell([string]$friendId) {
        $result = @{
            success = $false
            message = ""
            duellId = ""
        }
        
        if ($this.Status -ne [ConnectionStatus]::Connected) {
            $result.message = "Not connected"
            return $result
        }
        
        $duellId = [guid]::NewGuid().ToString().Substring(0, 8)
        
        $message = [GooseMessage]::new($this.PlayerName, $this.PlayerName, "challenged you to a DUELL!", [MultiplayerEvent]::GooseDuell)
        $this.Messages.Add($message)
        
        $result.success = $true
        $result.message = "Duell challenge sent!"
        $result.duellId = $duellId
        
        $this.SaveData()
        
        return $result
    }
    
    [hashtable] GetMessages() {
        $unread = @($this.Messages | Where-Object { -not $_.Read })
        foreach ($m in $unread) { $m.Read = $true }
        
        return @{
            total = $this.Messages.Count
            unread = $unread.Count
            messages = @($this.Messages | Select-Object -Last 20 | ForEach-Object {
                @{
                    id = $_.Id
                    fromGoose = $_.FromGoose
                    fromOwner = $_.FromOwner
                    content = $_.Content
                    type = $_.Type.ToString()
                    timestamp = $_.Timestamp
                    read = $_.Read
                }
            })
        }
    }
    
    [hashtable] GetMultiplayerState() {
        return @{
            Enabled = $this.Enabled
            Status = $this.Status.ToString()
            PlayerId = $this.PlayerId
            PlayerName = $this.PlayerName
            ConnectionCode = $this.ConnectionCode
            ConnectedFriends = @($this.ConnectedFriends | ForEach-Object {
                @{
                    id = $_.Id
                    name = $_.Name
                    ownerName = $_.OwnerName
                    status = $_.Status.ToString()
                }
            })
            PendingInvites = $this.PendingInvites.Keys
            Messages = @($this.Messages | Select-Object -Last 5 | ForEach-Object {
                @{
                    from = $_.FromGoose
                    content = $_.Content
                    type = $_.Type.ToString()
                }
            })
        }
    }
}

$gooseMultiplayer = [GooseMultiplayer]::new()

function Get-GooseMultiplayer {
    return $gooseMultiplayer
}

function Connect-Multiplayer {
    param($Multiplayer = $gooseMultiplayer)
    return $Multiplayer.Connect()
}

function Disconnect-Multiplayer {
    param($Multiplayer = $gooseMultiplayer)
    return $Multiplayer.Disconnect()
}

function Set-PlayerName {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        $Multiplayer = $gooseMultiplayer
    )
    return $Multiplayer.SetPlayerName($Name)
}

function Invite-Friend {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FriendCode,
        $Multiplayer = $gooseMultiplayer
    )
    return $Multiplayer.InviteFriend($FriendCode)
}

function Accept-Invite {
    param(
        [Parameter(Mandatory=$true)]
        [string]$InviteCode,
        $Multiplayer = $gooseMultiplayer
    )
    return $Multiplayer.AcceptInvite($InviteCode)
}

function Send-GooseMessage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FriendId,
        [Parameter(Mandatory=$true)]
        [string]$Content,
        $Multiplayer = $gooseMultiplayer
    )
    return $Multiplayer.SendMessage($FriendId, $Content)
}

function Visit-Friend {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FriendCode,
        $Multiplayer = $gooseMultiplayer
    )
    return $Multiplayer.VisitFriend($FriendCode)
}

function Start-GooseDuell {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FriendId,
        $Multiplayer = $gooseMultiplayer
    )
    return $Multiplayer.StartDuell($FriendId)
}

function Get-MultiplayerMessages {
    param($Multiplayer = $gooseMultiplayer)
    return $Multiplayer.GetMessages()
}

function Get-MultiplayerState {
    param($Multiplayer = $gooseMultiplayer)
    return $Multiplayer.GetMultiplayerState()
}

Write-Host "Desktop Goose Multiplayer System Initialized"
$state = Get-MultiplayerState
Write-Host "Multiplayer Enabled: $($state['Enabled']) | Status: $($state['Status']) | Code: $($state['ConnectionCode'])"
