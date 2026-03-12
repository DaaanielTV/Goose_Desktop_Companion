# Desktop Goose Command System
# Provides interactive commands the goose responds to

class GooseCommands {
    [hashtable]$Config
    [hashtable]$Commands
    [hashtable]$CommandHistory
    [int]$HistoryLimit
    [datetime]$LastCommandTime
    
    GooseCommands() {
        $this.Config = $this.LoadConfig()
        $this.CommandHistory = @{}
        $this.HistoryLimit = 50
        $this.LastCommandTime = Get-Date
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
                    } elseif ($value -match '^\d+\.\d+$') {
                        $this.Config[$key] = [double]$value
                    } else {
                        $this.Config[$key] = $value
                    }
                }
            }
        }
        
        return $this.Config
    }
    
    [void] InitializeCommands() {
        $this.Commands = @{
            # Fun commands
            "dance" = @{
                "Action" = "dance"
                "Response" = " honk honk *wiggles* "
                "Animation" = "happy_bounce"
                "Cooldown" = 5
            }
            "joke" = @{
                "Action" = "joke"
                "Responses" = @(
                    "Why do geese never get lost? They always follow the honking!",
                    "What do you call a goose that tells jokes? A giggly gander!",
                    "Why was the goose so bad at poker? It couldn't keep a straight face!",
                    "What do geese and computers have in common? They both need a mouse!",
                    "Why don't geese like talking about their age? That's a touchy subject!"
                )
                "Animation" = "happy_bounce"
                "Cooldown" = 10
            }
            "honk" = @{
                "Action" = "honk"
                "Response" = "HONK! "
                "Animation" = "head_tilt"
                "Cooldown" = 3
            }
            "pet" = @{
                "Action" = "pet"
                "Response" = " *wags tail* thank you! "
                "Animation" = "happy_bounce"
                "Cooldown" = 5
            }
            "treat" = @{
                "Action" = "treat"
                "Response" = " *munch munch* yum! "
                "Animation" = "happy_bounce"
                "Cooldown" = 15
            }
            "sleep" = @{
                "Action" = "sleep"
                "Response" = " zzz... "
                "Animation" = "sleep_mode"
                "Cooldown" = 30
            }
            "wake" = @{
                "Action" = "wake"
                "Response" = " *yawns* good morning! "
                "Animation" = "sleepy_yawn"
                "Cooldown" = 5
            }
            
            # Info commands
            "help" = @{
                "Action" = "help"
                "Response" = "Available commands: !dance, !joke, !honk, !pet, !treat, !sleep, !wake, !time, !date, !weather, !stats, !pomodoro, !focus, !notes, !music"
                "Animation" = "head_tilt"
                "Cooldown" = 2
            }
            "time" = @{
                "Action" = "time"
                "Response" = "The current time is: "
                "Animation" = "looking_around"
                "Cooldown" = 2
            }
            "date" = @{
                "Action" = "date"
                "Response" = "Today's date is: "
                "Animation" = "looking_around"
                "Cooldown" = 2
            }
            "weather" = @{
                "Action" = "weather"
                "Response" = "Checking weather... "
                "Animation" = "curious_peek"
                "Cooldown" = 30
            }
            "stats" = @{
                "Action" = "stats"
                "Response" = "Fetching your stats... "
                "Animation" = "head_tilt"
                "Cooldown" = 5
            }
            "pomodoro" = @{
                "Action" = "pomodoro"
                "Response" = "Pomodoro timer: "
                "Animation" = "looking_at_clock"
                "Cooldown" = 2
            }
            "focus" = @{
                "Action" = "focus"
                "Response" = "Focus mode: "
                "Animation" = "head_tilt"
                "Cooldown" = 2
            }
            "notes" = @{
                "Action" = "notes"
                "Response" = "Notes: "
                "Animation" = "looking_at_text"
                "Cooldown" = 2
            }
            "music" = @{
                "Action" = "music"
                "Response" = "Music status: "
                "Animation" = "happy_bounce"
                "Cooldown" = 5
            }
            
            # Behavior commands
            "come" = @{
                "Action" = "come"
                "Response" = " *waddles over* "
                "Animation" = "walk_subtle"
                "Cooldown" = 3
            }
            "stay" = @{
                "Action" = "stay"
                "Response" = " *sits still* "
                "Animation" = "sit_still"
                "Cooldown" = 5
            }
            "follow" = @{
                "Action" = "follow"
                "Response" = " *follows you* "
                "Animation" = "walk_subtle"
                "Cooldown" = 3
            }
            "attack" = @{
                "Action" = "attack"
                "Response" = " *charges at mouse* "
                "Animation" = "quick_jump"
                "Cooldown" = 10
            }
            "hide" = @{
                "Action" = "hide"
                "Response" = " *ducks down* "
                "Animation" = "sit_still"
                "Cooldown" = 10
            }
            
            # Personality commands
            "good" = @{
                "Action" = "good"
                "Response" = " *beams with joy* thank you! "
                "Animation" = "happy_bounce"
                "Cooldown" = 5
            }
            "bad" = @{
                "Action" = "bad"
                "Response" = " *looks sad* "
                "Animation" = "sleepy_yawn"
                "Cooldown" = 10
            }
            "angry" = @{
                "Action" = "angry"
                "Response" = " HONK! *ruffles feathers* "
                "Animation" = "head_tilt"
                "Cooldown" = 15
            }
            "love" = @{
                "Action" = "love"
                "Response" = " *nuzzles* I love you too! "
                "Animation" = "happy_bounce"
                "Cooldown" = 10
            }
            
            # Easter eggs
            "treats" = @{
                "Action" = "treats"
                "Response" = " *eyes light up* treats?! "
                "Animation" = "happy_bounce"
                "Cooldown" = 20
            }
            "bread" = @{
                "Action" = "bread"
                "Response" = " BREAD!! *excited honking* "
                "Animation" = "happy_bounce"
                "Cooldown" = 30
            }
            "pond" = @{
                "Action" = "pond"
                "Response" = " *looks wistful* I miss the pond... "
                "Animation" = "head_tilt"
                "Cooldown" = 60
            }
        }
    }
    
    [bool] IsCommand([string]$input) {
        return $input.StartsWith("!")
    }
    
    [string] GetCommand([string]$input) {
        if (-not $this.IsCommand($input)) {
            return ""
        }
        return $input.Substring(1).ToLower()
    }
    
    [bool] HasCooldown([string]$command) {
        if (-not $this.Commands.ContainsKey($command)) {
            return $false
        }
        
        $cmd = $this.Commands[$command]
        if (-not $cmd.ContainsKey("Cooldown")) {
            return $false
        }
        
        $lastTime = $this.CommandHistory[$command]
        if ($null -eq $lastTime) {
            return $false
        }
        
        $cooldownSeconds = $cmd["Cooldown"]
        $elapsed = ((Get-Date) - $lastTime).TotalSeconds
        
        return $elapsed -lt $cooldownSeconds
    }
    
    [void] RecordCommand([string]$command) {
        $this.CommandHistory[$command] = Get-Date
        $this.LastCommandTime = Get-Date
        
        # Trim history if needed
        if ($this.CommandHistory.Count -gt $this.HistoryLimit) {
            $oldest = ($this.CommandHistory.GetEnumerator() | Sort-Object Value | Select-Object -First 1)
            $this.CommandHistory.Remove($oldest.Key)
        }
    }
    
    [hashtable] ProcessCommand([string]$input) {
        $command = $this.GetCommand($input)
        
        if ($command -eq "") {
            return @{
                "Success" = $false
                "Error" = "Not a command"
            }
        }
        
        if (-not $this.Commands.ContainsKey($command)) {
            return @{
                "Success" = $false
                "Error" = "Unknown command: !$command"
                "Hint" = "Type !help for available commands"
            }
        }
        
        if ($this.HasCooldown($command)) {
            return @{
                "Success" = $false
                "Error" = "Command on cooldown"
                "Cooldown" = $true
            }
        }
        
        $cmd = $this.Commands[$command]
        $response = ""
        
        # Get response
        if ($cmd.ContainsKey("Response")) {
            $response = $cmd["Response"]
        } elseif ($cmd.ContainsKey("Responses")) {
            $responses = $cmd["Responses"]
            $response = $responses[(Get-Random -Minimum 0 -Maximum $responses.Count)]
        }
        
        # Add dynamic content
        switch ($command) {
            "time" { $response += (Get-Date).ToString("h:mm tt") }
            "date" { $response += (Get-Date).ToString("dddd, MMMM d, yyyy") }
        }
        
        $this.RecordCommand($command)
        
        return @{
            "Success" = $true
            "Command" = $command
            "Response" = $response
            "Animation" = $cmd["Animation"]
            "Action" = $cmd["Action"]
            "Cooldown" = $cmd["Cooldown"]
        }
    }
    
    [string] GetCommandList() {
        $cmdList = @()
        foreach ($cmd in $this.Commands.Keys) {
            $cmdList += "!" + $cmd
        }
        return ($cmdList | Sort-Object) -join ", "
    }
    
    [hashtable] GetStatus() {
        return @{
            "TotalCommands" = $this.Commands.Count
            "CommandHistoryCount" = $this.CommandHistory.Count
            "LastCommandTime" = $this.LastCommandTime
            "AvailableCommands" = $this.GetCommandList()
        }
    }
}

# Initialize command system
$gooseCommands = [GooseCommands]::new()

# Export functions
function Get-GooseCommands {
    return $gooseCommands
}

function Invoke-GooseCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Input,
        $Commands = $gooseCommands
    )
    return $Commands.ProcessCommand($Input)
}

function Get-GooseCommandList {
    param($Commands = $gooseCommands)
    return $Commands.GetCommandList()
}

# Example usage
Write-Host "Desktop Goose Command System Initialized"
Write-Host "Available commands: $(Get-GooseCommandList)"
