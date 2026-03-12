# Desktop Goose App Reactions
# Goose reacts to what applications you're using

class AppReaction {
    [string]$ProcessName
    [string]$WindowTitle
    [string]$Reaction
    [string]$Message
    [string]$Animation
    [bool]$Enabled
    
    AppReaction([string]$process, [string]$reaction, [string]$message, [string]$animation) {
        $this.ProcessName = $process
        $this.Reaction = $reaction
        $this.Message = $message
        $this.Animation = $animation
        $this.Enabled = $true
    }
}

class GooseAppReactions {
    [hashtable]$Config
    [System.Collections.Hashtable]$Reactions
    [string]$LastApp
    [datetime]$LastReaction
    [int]$CooldownSeconds
    
    GooseAppReactions() {
        $this.Config = $this.LoadConfig()
        $this.Reactions = [System.Collections.Hashtable]::new()
        $this.LastApp = ""
        $this.LastReaction = Get-Date
        $this.CooldownSeconds = 30
        $this.InitializeReactions()
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
        
        if (-not $this.Config.ContainsKey("AppReactionEnabled")) {
            $this.Config["AppReactionEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("AppReactionCooldown")) {
            $this.Config["AppReactionCooldown"] = 30
        }
        
        $this.CooldownSeconds = $this.Config["AppReactionCooldown"]
        
        return $this.Config
    }
    
    [void] InitializeReactions() {
        $this.Reactions["code"] = [AppReaction]::new(
            "Code",
            "code",
            "// TODO: HONK - fix this later",
            "type"
        )
        $this.Reactions["vscode"] = [AppReaction]::new(
            "Code",
            "code",
            "// const HONK = 'honk';",
            "type"
        )
        $this.Reactions["jetbrains"] = [AppReaction]::new(
            "jetbrains",
            "code",
            "console.log('HONK!');",
            "type"
        )
        $this.Reactions["powershell"] = [AppReaction]::new(
            "powershell",
            "hack",
            "sudo honk",
            "type"
        )
        $this.Reactions["pwsh"] = [AppReaction]::new(
            "pwsh",
            "hack",
            "Get-Honks | Format-Table",
            "type"
        )
        $this.Reactions["windowsterminal"] = [AppReaction]::new(
            "WindowsTerminal",
            "hack",
            "rm -rf /problems",
            "type"
        )
        $this.Reactions["steam"] = [AppReaction]::new(
            "Steam",
            "game",
            "GAME OVER! 🏆",
            "cheer"
        )
        $this.Reactions["epicgames"] = [AppReaction]::new(
            "EpicGamesLauncher",
            "game",
            "Let's play! 🎮",
            "cheer"
        )
        $this.Reactions["chrome"] = [AppReaction]::new(
            "chrome",
            "meme",
            "🦆💻",
            "drag"
        )
        $this.Reactions["firefox"] = [AppReaction]::new(
            "firefox",
            "meme",
            "🐊🦆",
            "drag"
        )
        $this.Reactions["msedge"] = [AppReaction]::new(
            "msedge",
            "meme",
            "HONK.exe has stopped working",
            "drag"
        )
        $this.Reactions["discord"] = [AppReaction]::new(
            "Discord",
            "chat",
            "HONK! 🦆",
            "follow"
        )
        $this.Reactions["slack"] = [AppReaction]::new(
            "slack",
            "chat",
            "New honk mentions! 📢",
            "follow"
        )
        $this.Reactions["spotify"] = [AppReaction]::new(
            "Spotify",
            "music",
            "*dances to the beat* 🎵",
            "dance"
        )
        $this.Reactions["vlc"] = [AppReaction]::new(
            "vlc",
            "movie",
            "Shhh! Watching... 🎬",
            "watch"
        )
        $this.Reactions["obs"] = [AppReaction]::new(
            "obs64",
            "stream",
            "LIVE NOW! 📹",
            "wave"
        )
        $this.Reactions["excel"] = [AppReaction]::new(
            "EXCEL",
            "work",
            "So many cells... 📊",
            "sigh"
        )
        $this.Reactions["outlook"] = [AppReaction]::new(
            "OUTLOOK",
            "email",
            "You've got mail! 📧",
            "follow"
        )
        $this.Reactions["teams"] = [AppReaction]::new(
            "Teams",
            "meeting",
            "Is this on mute? 🔇",
            "confused"
        )
        $this.Reactions["zoom"] = [AppReaction]::new(
            "zoom",
            "meeting",
            "You're on mute! 📵",
            "point"
        )
        $this.Reactions["notepad"] = [AppReaction]::new(
            "notepad",
            "write",
            "Honk.txt",
            "type"
        )
        $this.Reactions["photoshop"] = [AppReaction]::new(
            "Photoshop",
            "art",
            "Make it pink! 🎨",
            "watch"
        )
        $this.Reactions["git"] = [AppReaction]::new(
            "git",
            "code",
            "git add . && git commit -m 'honk'",
            "type"
        )
        $this.Reactions["docker"] = [AppReaction]::new(
            "docker",
            "tech",
            "Building... 🐳",
            "wait"
        )
    }
    
    [string] GetActiveProcess() {
        try {
            $processes = Get-Process | Where-Object { $_.MainWindowTitle -ne "" } | Select-Object -First 1
            if ($processes) {
                return $processes.ProcessName
            }
        } catch {}
        return ""
    }
    
    [string] GetActiveWindowTitle() {
        try {
            $processes = Get-Process | Where-Object { $_.MainWindowTitle -ne "" } | Select-Object -First 1
            if ($processes) {
                return $processes.MainWindowTitle
            }
        } catch {}
        return ""
    }
    
    [bool] CanReact() {
        $secondsSince = ((Get-Date) - $this.LastReaction).TotalSeconds
        return $secondsSince -ge $this.CooldownSeconds
    }
    
    [hashtable] CheckAndReact() {
        if (-not $this.Config["AppReactionEnabled"]) {
            return @{
                Reacted = $false
                Reason = "Disabled"
            }
        }
        
        if (-not $this.CanReact()) {
            return @{
                Reacted = $false
                Reason = "Cooldown"
            }
        }
        
        $currentProcess = $this.GetActiveProcess()
        
        if ($currentProcess -eq "" -or $currentProcess -eq $this.LastApp) {
            return @{
                Reacted = $false
                Reason = "No change"
            }
        }
        
        $reaction = $this.GetReaction($currentProcess)
        
        if ($reaction) {
            $this.LastApp = $currentProcess
            $this.LastReaction = Get-Date
            
            return @{
                Reacted = $true
                Process = $currentProcess
                Reaction = $reaction.Reaction
                Message = $reaction.Message
                Animation = $reaction.Animation
            }
        }
        
        return @{
            Reacted = $false
            Reason = "No reaction for $currentProcess"
        }
    }
    
    [AppReaction] GetReaction([string]$processName) {
        $processLower = $processName.ToLower()
        
        foreach ($key in $this.Reactions.Keys) {
            if ($processLower -like "*$key*") {
                return $this.Reactions[$key]
            }
        }
        
        return $null
    }
    
    [void] AddCustomReaction([string]$processName, [string]$reaction, [string]$message, [string]$animation) {
        $this.Reactions[$processName.ToLower()] = [AppReaction]::new(
            $processName,
            $reaction,
            $message,
            $animation
        )
    }
    
    [hashtable] GetReactionState() {
        return @{
            Enabled = $this.Config["AppReactionEnabled"]
            CooldownSeconds = $this.CooldownSeconds
            LastApp = $this.LastApp
            AvailableReactions = @($this.Reactions.Keys)
            CurrentProcess = $this.GetActiveProcess()
            WindowTitle = $this.GetActiveWindowTitle()
        }
    }
    
    [hashtable] GetAllReactions() {
        $result = @()
        foreach ($key in $this.Reactions.Keys) {
            $r = $this.Reactions[$key]
            $result += @{
                Process = $key
                Reaction = $r.Reaction
                Message = $r.Message
                Animation = $r.Animation
            }
        }
        return $result
    }
}

$gooseAppReactions = [GooseAppReactions]::new()

function Get-GooseAppReactions {
    return $gooseAppReactions
}

function Test-AppReaction {
    param($AppReactions = $gooseAppReactions)
    return $AppReactions.CheckAndReact()
}

function Get-AppReactionState {
    param($AppReactions = $gooseAppReactions)
    return $AppReactions.GetReactionState()
}

function Add-CustomAppReaction {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProcessName,
        [Parameter(Mandatory=$true)]
        [string]$Reaction,
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Animation = "default",
        $AppReactions = $gooseAppReactions
    )
    $AppReactions.AddCustomReaction($ProcessName, $Reaction, $Message, $Animation)
    return @{
        Success = $true
        Message = "Added reaction for $ProcessName"
    }
}

function Get-AvailableReactions {
    param($AppReactions = $gooseAppReactions)
    return $AppReactions.GetAllReactions()
}

Write-Host "Desktop Goose App Reactions Initialized"
$state = Get-AppReactionState
Write-Host "Enabled: $($state['Enabled']) | Reactions: $($state['AvailableReactions'].Count)"
