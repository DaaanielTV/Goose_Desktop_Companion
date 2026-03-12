# Desktop Goose Streamer Mode
# Twitch/YouTube integration for streamers

enum StreamEvent {
    Follow
    Subscription
    Donation
    Raid
    Host
    ChatMessage
    HypeTrain
    Bits
}

enum ChaosEvent {
    ScreenSpin
    IconRain
    FakeError
    HonkStorm
    WindowTeleport
    EmojiExplosion
    GooseDance
    ScreenShake
    ReverseScroll
    VoiceHonk
}

class StreamConfig {
    [string]$Platform
    [string]$ChannelName
    [string]$OAuthToken
    [bool]$ChatEnabled
    [bool]$AlertEnabled
    [bool]$ChaosEnabled
    [int]$MinDonationForChaos
    [int]$MinBitsForChaos
    
    StreamConfig() {
        $this.Platform = "twitch"
        $this.ChannelName = ""
        $this.OAuthToken = ""
        $this.ChatEnabled = $true
        $this.AlertEnabled = $true
        $this.ChaosEnabled = $true
        $this.MinDonationForChaos = 5
        $this.MinBitsForChaos = 100
    }
}

class StreamEventRecord {
    [StreamEvent]$Type
    [string]$Username
    [string]$Message
    [decimal]$Amount
    [datetime]$Timestamp
    
    StreamEventRecord([StreamEvent]$type, [string]$username, [string]$message, [decimal]$amount = 0) {
        $this.Type = $type
        $this.Username = $username
        $this.Message = $message
        $this.Amount = $amount
        $this.Timestamp = Get-Date
    }
}

class GooseStreamerMode {
    [hashtable]$Config
    [bool]$Enabled
    [StreamConfig]$StreamConfig
    [System.Collections.ArrayList]$EventHistory
    [hashtable]$ChatCommands
    [bool]$IsLive
    [string]$DataFile
    
    GooseStreamerMode() {
        $this.Config = $this.LoadConfig()
        $this.Enabled = $false
        $this.StreamConfig = [StreamConfig]::new()
        $this.EventHistory = [System.Collections.ArrayList]::new()
        $this.ChatCommands = @{}
        $this.IsLive = $false
        $this.DataFile = "goose_streamer.json"
        $this.LoadData()
        $this.InitializeCommands()
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
        
        if (-not $this.Config.ContainsKey("StreamerModeEnabled")) {
            $this.Config["StreamerModeEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("StreamerChannel")) {
            $this.Config["StreamerChannel"] = ""
        }
        
        return $this.Config
    }
    
    [void] LoadData() {
        if (Test-Path $this.DataFile) {
            try {
                $data = Get-Content $this.DataFile -Raw | ConvertFrom-Json
                
                if ($data.eventHistory) {
                    $this.EventHistory.Clear()
                    foreach ($e in $data.eventHistory) {
                        $event = [StreamEventRecord]::new([StreamEvent]$e.type, $e.username, $e.message, $e.amount)
                        $this.EventHistory.Add($event)
                    }
                }
                
                if ($data.chatCommands) {
                    $this.ChatCommands = @{}
                    $data.chatCommands.PSObject.Properties | ForEach-Object {
                        $this.ChatCommands[$_.Name] = $_.Value
                    }
                }
            } catch {}
        }
        
        $this.Enabled = $this.Config["StreamerModeEnabled"]
        $this.StreamConfig.ChannelName = $this.Config["StreamerChannel"]
    }
    
    [void] SaveData() {
        $data = @{
            eventHistory = @($this.EventHistory | Select-Object -Last 50 | ForEach-Object {
                @{
                    type = $_.Type.ToString()
                    username = $_.Username
                    message = $_.Message
                    amount = $_.Amount
                    timestamp = $_.Timestamp.ToString("o")
                }
            })
            chatCommands = $this.ChatCommands
            lastSaved = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.DataFile -Encoding UTF8
    }
    
    [void] InitializeCommands() {
        if ($this.ChatCommands.Count -eq 0) {
            $this.ChatCommands = @{
                "!honk" = @{ response = "HONK! 🦆"; chaos = $false }
                "!dance" = @{ response = "*dances* 🎵"; chaos = $true; chaosType = "GooseDance" }
                "!attack" = @{ response = "GOOSE ATTACK!"; chaos = $true; chaosType = "IconRain" }
                "!sleep" = @{ response = "*goose sleeps* 💤"; chaos = $false }
                "!pet" = @{ response = "*petting the goose* ❤️"; chaos = $false }
                "!chaos" = @{ response = "CHAOS MODE ACTIVATED!"; chaos = $true; chaosType = "ScreenShake" }
                "!rip" = @{ response = "Rest in peace, tabs. 🪦"; chaos = $true; chaosType = "FakeError" }
            }
        }
    }
    
    [hashtable] Connect([string]$platform, [string]$channel, [string]$oauth = "") {
        $result = @{
            success = $false
            message = ""
        }
        
        if (-not $channel) {
            $result.message = "Channel name required"
            return $result
        }
        
        $this.StreamConfig.Platform = $platform
        $this.StreamConfig.ChannelName = $channel
        $this.StreamConfig.OAuthToken = $oauth
        
        $this.Enabled = $true
        $this.IsLive = $true
        
        $result.success = $true
        $result.message = "Connected to $platform channel: $channel"
        
        return $result
    }
    
    [hashtable] Disconnect() {
        $result = @{
            success = $false
            message = ""
        }
        
        $this.Enabled = $false
        $this.IsLive = $false
        
        $result.success = $true
        $result.message = "Disconnected from stream"
        
        return $result
    }
    
    [hashtable] ProcessChatMessage([string]$username, [string]$message) {
        $result = @{
            success = $false
            response = ""
            shouldChaos = $false
            chaosType = ""
        }
        
        if (-not $this.Enabled -or -not $this.StreamConfig.ChatEnabled) {
            return $result
        }
        
        $msgLower = $message.ToLower()
        
        if ($this.ChatCommands.ContainsKey($msgLower)) {
            $cmd = $this.ChatCommands[$msgLower]
            $result.response = $cmd.response
            $result.success = $true
            
            if ($cmd.chaos -and $this.StreamConfig.ChaosEnabled) {
                $result.shouldChaos = $true
                $result.chaosType = $cmd.chaosType
            }
            
            $event = [StreamEventRecord]::new([StreamEvent]::ChatMessage, $username, $message, 0)
            $this.EventHistory.Add($event)
        }
        
        return $result
    }
    
    [hashtable] ProcessFollow([string]$username) {
        $result = @{
            success = $false
            message = ""
            shouldChaos = $false
        }
        
        if (-not $this.Enabled) { return $result }
        
        $event = [StreamEventRecord]::new([StreamEvent]::Follow, $username, "New follower!", 0)
        $this.EventHistory.Add($event)
        
        $result.success = $true
        $result.message = "New follower: $username"
        
        if ($this.StreamConfig.AlertEnabled) {
            $result.shouldChaos = $true
        }
        
        $this.SaveData()
        
        return $result
    }
    
    [hashtable] ProcessSubscription([string]$username, [string]$tier = "1") {
        $result = @{
            success = $false
            message = ""
            shouldChaos = $false
            chaosType = ""
        }
        
        if (-not $this.Enabled) { return $result }
        
        $event = [StreamEventRecord]::new([StreamEvent]::Subscription, $username, "Subscribed (Tier $tier)", [decimal]$tier)
        $this.EventHistory.Add($event)
        
        $result.success = $true
        $result.message = "New sub: $username (Tier $tier)"
        $result.shouldChaos = $true
        $result.chaosType = "GooseDance"
        
        $this.SaveData()
        
        return $result
    }
    
    [hashtable] ProcessDonation([string]$username, [decimal]$amount, [string]$message = "") {
        $result = @{
            success = $false
            message = ""
            shouldChaos = $false
            chaosType = ""
        }
        
        if (-not $this.Enabled) { return $result }
        
        $event = [StreamEventRecord]::new([StreamEvent]::Donation, $username, $message, $amount)
        $this.EventHistory.Add($event)
        
        $result.success = $true
        $result.message = "Donation: $$amount from $username"
        
        if ($amount -ge $this.StreamConfig.MinDonationForChaos -and $this.StreamConfig.ChaosEnabled) {
            $result.shouldChaos = $true
            
            $chaosTypes = @("ScreenShake", "EmojiExplosion", "HonkStorm", "IconRain")
            $result.chaosType = $chaosTypes | Get-Random
        }
        
        $this.SaveData()
        
        return $result
    }
    
    [hashtable] ProcessRaid([string]$username, [int]$viewers) {
        $result = @{
            success = $false
            message = ""
            shouldChaos = $false
            chaosType = ""
        }
        
        if (-not $this.Enabled) { return $result }
        
        $event = [StreamEventRecord]::new([StreamEvent]::Raid, $username, "Raided with $viewers viewers", $viewers)
        $this.EventHistory.Add($event)
        
        $result.success = $true
        $result.message = "Raid: $username with $viewers viewers"
        $result.shouldChaos = $viewers -ge 50
        $result.chaosType = "ScreenSpin"
        
        $this.SaveData()
        
        return $result
    }
    
    [hashtable] ProcessBits([string]$username, [int]$bits, [string]$message = "") {
        $result = @{
            success = $false
            message = ""
            shouldChaos = $false
            chaosType = ""
        }
        
        if (-not $this.Enabled) { return $result }
        
        $event = [StreamEventRecord]::new([StreamEvent]::Bits, $username, "$message ($bits bits)", $bits)
        $this.EventHistory.Add($event)
        
        $result.success = $true
        $result.message = "Bits: $bits from $username"
        
        if ($bits -ge $this.StreamConfig.MinBitsForChaos -and $this.StreamConfig.ChaosEnabled) {
            $result.shouldChaos = $true
            $result.chaosType = "HonkStorm"
        }
        
        $this.SaveData()
        
        return $result
    }
    
    [hashtable] ExecuteChaos([string]$chaosType) {
        $result = @{
            success = $false
            chaosType = ""
            message = ""
        }
        
        $result.chaosType = $chaosType
        
        switch ($chaosType) {
            "ScreenSpin" {
                $result.message = "Screen will spin! 🌀"
            }
            "IconRain" {
                $result.message = "Icons rain from the sky! 🌧️"
            }
            "FakeError" {
                $result.message = "Fake error popup! 💻"
            }
            "HonkStorm" {
                $result.message = "HONK STORM! 🦆💨"
            }
            "WindowTeleport" {
                $result.message = "Windows will teleport! 👻"
            }
            "EmojiExplosion" {
                $result.message = "EMOJI EXPLOSION! 💥"
            }
            "GooseDance" {
                $result.message = "GOOSE DANCE! 💃🦆"
            }
            "ScreenShake" {
                $result.message = "Screen SHAKE! 📳"
            }
            "ReverseScroll" {
                $result.message = "Reverse scroll! 🔄"
            }
            "VoiceHonk" {
                $result.message = "VOICE HONK! 🔊"
            }
            default {
                $result.message = "Unknown chaos!"
            }
        }
        
        $result.success = $true
        
        return $result
    }
    
    [void] AddCommand([string]$command, [string]$response, [bool]$chaos = $false, [string]$chaosType = "") {
        $this.ChatCommands[$command] = @{
            response = $response
            chaos = $chaos
            chaosType = $chaosType
        }
        $this.SaveData()
    }
    
    [void] RemoveCommand([string]$command) {
        if ($this.ChatCommands.ContainsKey($command)) {
            $this.ChatCommands.Remove($command)
            $this.SaveData()
        }
    }
    
    [hashtable] GetStreamerState() {
        return @{
            Enabled = $this.Enabled
            IsLive = $this.IsLive
            Platform = $this.StreamConfig.Platform
            Channel = $this.StreamConfig.ChannelName
            ChatEnabled = $this.StreamConfig.ChatEnabled
            AlertEnabled = $this.StreamConfig.AlertEnabled
            ChaosEnabled = $this.StreamConfig.ChaosEnabled
            MinDonationForChaos = $this.StreamConfig.MinDonationForChaos
            MinBitsForChaos = $this.StreamConfig.MinBitsForChaos
            Commands = $this.ChatCommands.Keys
            RecentEvents = @($this.EventHistory | Select-Object -Last 10 | ForEach-Object {
                @{
                    type = $_.Type.ToString()
                    username = $_.Username
                    message = $_.Message
                    amount = $_.Amount
                    timestamp = $_.Timestamp
                }
            })
        }
    }
}

$gooseStreamerMode = [GooseStreamerMode]::new()

function Get-GooseStreamerMode {
    return $gooseStreamerMode
}

function Connect-Stream {
    param(
        [string]$Platform = "twitch",
        [Parameter(Mandatory=$true)]
        [string]$Channel,
        [string]$OAuth = "",
        $Streamer = $gooseStreamerMode
    )
    return $Streamer.Connect($Platform, $Channel, $OAuth)
}

function Disconnect-Stream {
    param($Streamer = $gooseStreamerMode)
    return $Streamer.Disconnect()
}

function Process-StreamChat {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Username,
        [Parameter(Mandatory=$true)]
        [string]$Message,
        $Streamer = $gooseStreamerMode
    )
    return $Streamer.ProcessChatMessage($Username, $Message)
}

function Process-StreamFollow {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Username,
        $Streamer = $gooseStreamerMode
    )
    return $Streamer.ProcessFollow($Username)
}

function Process-StreamSub {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Username,
        [string]$Tier = "1",
        $Streamer = $gooseStreamerMode
    )
    return $Streamer.ProcessSubscription($Username, $Tier)
}

function Process-StreamDonation {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Username,
        [Parameter(Mandatory=$true)]
        [decimal]$Amount,
        [string]$Message = "",
        $Streamer = $gooseStreamerMode
    )
    return $Streamer.ProcessDonation($Username, $Amount, $Message)
}

function Process-StreamRaid {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Username,
        [Parameter(Mandatory=$true)]
        [int]$Viewers,
        $Streamer = $gooseStreamerMode
    )
    return $Streamer.ProcessRaid($Username, $Viewers)
}

function Process-StreamBits {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Username,
        [Parameter(Mandatory=$true)]
        [int]$Bits,
        [string]$Message = "",
        $Streamer = $gooseStreamerMode
    )
    return $Streamer.ProcessBits($Username, $Bits, $Message)
}

function Execute-Chaos {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ChaosType,
        $Streamer = $gooseStreamerMode
    )
    return $Streamer.ExecuteChaos($ChaosType)
}

function Add-StreamCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,
        [Parameter(Mandatory=$true)]
        [string]$Response,
        [bool]$Chaos = $false,
        [string]$ChaosType = "",
        $Streamer = $gooseStreamerMode
    )
    $Streamer.AddCommand($Command, $Response, $Chaos, $ChaosType)
    return @{ success = $true; message = "Command added: $Command" }
}

function Get-StreamerState {
    param($Streamer = $gooseStreamerMode)
    return $Streamer.GetStreamerState()
}

Write-Host "Desktop Goose Streamer Mode Initialized"
$state = Get-StreamerState
Write-Host "Streamer Mode Enabled: $($state['Enabled']) | Platform: $($state['Platform']) | Channel: $($state['Channel'])"
