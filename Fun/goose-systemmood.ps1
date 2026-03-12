# Desktop Goose Mood System - Enhanced
# Goose emotions based on user behavior and system state

enum SystemMood {
    Happy
    Angry
    Bored
    Sleepy
    Curious
    Mischievous
    Chaotic
    Neutral
}

class GooseSystemMood {
    [hashtable]$Config
    [SystemMood]$CurrentMood
    [datetime]$LastMoodChange
    [int]$IdleMinutes
    [float]$CpuUsage
    [bool]$IsMusicPlaying
    [datetime]$LastUserActivity
    [hashtable]$MoodHistory
    [hashtable]$MoodTriggers
    
    GooseSystemMood() {
        $this.Config = $this.LoadConfig()
        $this.CurrentMood = [SystemMood]::Neutral
        $this.LastMoodChange = Get-Date
        $this.IdleMinutes = 0
        $this.CpuUsage = 0
        $this.IsMusicPlaying = $false
        $this.LastUserActivity = Get-Date
        $this.MoodHistory = @{}
        $this.MoodTriggers = $this.InitializeTriggers()
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
        
        if (-not $this.Config.ContainsKey("MoodSystemEnabled")) {
            $this.Config["MoodSystemEnabled"] = $true
        }
        if (-not $this.Config.ContainsKey("MoodReactToCPU")) {
            $this.Config["MoodReactToCPU"] = $true
        }
        if (-not $this.Config.ContainsKey("MoodReactToMusic")) {
            $this.Config["MoodReactToMusic"] = $true
        }
        if (-not $this.Config.ContainsKey("MoodReactToIdle")) {
            $this.Config["MoodReactToIdle"] = $true
        }
        if (-not $this.Config.ContainsKey("MoodCPUThreshold")) {
            $this.Config["MoodCPUThreshold"] = 80
        }
        if (-not $this.Config.ContainsKey("MoodIdleThreshold")) {
            $this.Config["MoodIdleThreshold"] = 10
        }
        
        return $this.Config
    }
    
    [hashtable] InitializeTriggers() {
        return @{
            "CPUHigh" = @{
                Mood = [SystemMood]::Angry
                Threshold = 80
                Message = "HONK! Computer too hot! 🫠"
                CooldownMinutes = 5
                LastTriggered = [datetime]::MinValue
            }
            "CPUNormal" = @{
                Mood = [SystemMood]::Neutral
                Threshold = 50
                Message = "*chill goose noises* 😌"
                CooldownMinutes = 5
                LastTriggered = [datetime]::MinValue
            }
            "MusicPlaying" = @{
                Mood = [SystemMood]::Happy
                Threshold = 0
                Message = "*dances* 🎵🎵🎵"
                CooldownMinutes = 2
                LastTriggered = [datetime]::MinValue
            }
            "MusicStopped" = @{
                Mood = [SystemMood]::Bored
                Threshold = 0
                Message = "Aww, music stopped... 😢"
                CooldownMinutes = 5
                LastTriggered = [datetime]::MinValue
            }
            "IdleLong" = @{
                Mood = [SystemMood]::Sleepy
                Threshold = 10
                Message = "*yawn* So bored... 💤"
                CooldownMinutes = 10
                LastTriggered = [datetime]::MinValue
            }
            "UserActive" = @{
                Mood = [SystemMood]::Curious
                Threshold = 0
                Message = "What are we doing today? 🧐"
                CooldownMinutes = 5
                LastTriggered = [datetime]::MinValue
            }
            "Mischievous" = @{
                Mood = [SystemMood]::Mischievous
                Threshold = 10
                Message = "Hehe... 🤭 *goose noises*"
                CooldownMinutes = 15
                LastTriggered = [datetime]::MinValue
            }
            "Chaotic" = @{
                Mood = [SystemMood]::Chaotic
                Threshold = 5
                Message = "HONK! CHAOS MODE! 🎉"
                CooldownMinutes = 30
                LastTriggered = [datetime]::MinValue
            }
        }
    }
    
    [float] GetCpuUsage() {
        try {
            $cpu = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue
            if ($cpu) {
                return [math]::Round($cpu.CounterSamples[0].CookedValue, 1)
            }
        } catch {}
        return 0
    }
    
    [int] GetIdleMinutes() {
        try {
            $idle = Get-Counter '\User Input\Idle Time (ms)' -ErrorAction SilentlyContinue
            if ($idle) {
                $idleMs = $idle.CounterSamples[0].CookedValue
                return [int]($idleMs / 60000)
            }
        } catch {}
        
        $lastInput = [Environment]::TickCount
        $idleTime = (Get-Date) - [System.Diagnostics.Process]::GetCurrentProcess().StartTime
        return [int]$idleTime.TotalMinutes
    }
    
    [bool] IsMusicPlaying() {
        $musicProcesses = @("Spotify", "wmplayer", "Music", "Audacity", "VLC")
        foreach ($proc in $musicProcesses) {
            if (Get-Process -Name $proc -ErrorAction SilentlyContinue) {
                return $true
            }
        }
        return $false
    }
    
    [bool] CanTrigger([string]$triggerName) {
        if (-not $this.MoodTriggers.ContainsKey($triggerName)) { return $false }
        $trigger = $this.MoodTriggers[$triggerName]
        $minutesSince = ((Get-Date) - $trigger.LastTriggered).TotalMinutes
        return $minutesSince -ge $trigger.CooldownMinutes
    }
    
    [void] UpdateSystemState() {
        $this.CpuUsage = $this.GetCpuUsage()
        $this.IdleMinutes = $this.GetIdleMinutes()
        $musicNow = $this.IsMusicPlaying()
        
        if ($this.Config["MoodReactToCPU"]) {
            $this.ProcessCPUMood()
        }
        
        if ($this.Config["MoodReactToMusic"]) {
            $this.ProcessMusicMood($musicNow)
        }
        
        if ($this.Config["MoodReactToIdle"]) {
            $this.ProcessIdleMood()
        }
        
        $this.ProcessRandomMoods()
    }
    
    [void] ProcessCPUMood() {
        $threshold = $this.Config["MoodCPUThreshold"]
        
        if ($this.CpuUsage -gt $threshold -and $this.CanTrigger("CPUHigh")) {
            if ($this.CurrentMood -ne [SystemMood]::Angry) {
                $this.SetMood([SystemMood]::Angry)
                $this.MoodTriggers["CPUHigh"].LastTriggered = Get-Date
            }
        } elseif ($this.CpuUsage -lt 50 -and $this.CurrentMood -eq [SystemMood]::Angry) {
            if ($this.CanTrigger("CPUNormal")) {
                $this.SetMood([SystemMood]::Neutral)
                $this.MoodTriggers["CPUNormal"].LastTriggered = Get-Date
            }
        }
    }
    
    [void] ProcessMusicMood([bool]$isPlaying) {
        if ($isPlaying -and $this.CurrentMood -ne [SystemMood]::Happy -and $this.CanTrigger("MusicPlaying")) {
            $this.SetMood([SystemMood]::Happy)
            $this.MoodTriggers["MusicPlaying"].LastTriggered = Get-Date
        } elseif (-not $isPlaying -and $this.CurrentMood -eq [SystemMood]::Happy -and $this.CanTrigger("MusicStopped")) {
            $this.SetMood([SystemMood]::Bored)
            $this.MoodTriggers["MusicStopped"].LastTriggered = Get-Date
        }
        $this.IsMusicPlaying = $isPlaying
    }
    
    [void] ProcessIdleMood() {
        $threshold = $this.Config["MoodIdleThreshold"]
        
        if ($this.IdleMinutes -gt $threshold -and $this.CurrentMood -ne [SystemMood]::Sleepy -and $this.CanTrigger("IdleLong")) {
            $this.SetMood([SystemMood]::Sleepy)
            $this.MoodTriggers["IdleLong"].LastTriggered = Get-Date
        } elseif ($this.IdleMinutes -lt 2 -and $this.CurrentMood -eq [SystemMood]::Sleepy -and $this.CanTrigger("UserActive")) {
            $this.SetMood([SystemMood]::Curious)
            $this.MoodTriggers["UserActive"].LastTriggered = Get-Date
        }
    }
    
    [void] ProcessRandomMoods() {
        $random = Get-Random -Maximum 100
        
        if ($random -lt 5 -and $this.CanTrigger("Mischievous")) {
            $this.SetMood([SystemMood]::Mischievous)
            $this.MoodTriggers["Mischievous"].LastTriggered = Get-Date
        } elseif ($random -lt 2 -and $this.CanTrigger("Chaotic")) {
            $this.SetMood([SystemMood]::Chaotic)
            $this.MoodTriggers["Chaotic"].LastTriggered = Get-Date
        }
    }
    
    [void] SetMood([SystemMood]$mood) {
        $this.CurrentMood = $mood
        $this.LastMoodChange = Get-Date
        $this.SaveMoodHistory()
    }
    
    [void] SaveMoodHistory() {
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        if (-not $this.MoodHistory.ContainsKey($dateKey)) {
            $this.MoodHistory[$dateKey] = @()
        }
        $this.MoodHistory[$dateKey] += @{
            Mood = $this.CurrentMood.ToString()
            Timestamp = (Get-Date).ToString("o")
            CpuUsage = $this.CpuUsage
            IdleMinutes = $this.IdleMinutes
            MusicPlaying = $this.IsMusicPlaying
        }
    }
    
    [string] GetMoodEmoji() {
        switch ($this.CurrentMood) {
            [SystemMood]::Happy { return "😊" }
            [SystemMood]::Angry { return "😠" }
            [SystemMood]::Bored { return "😑" }
            [SystemMood]::Sleepy { return "😴" }
            [SystemMood]::Curious { return "🧐" }
            [SystemMood]::Mischievous { return "😈" }
            [SystemMood]::Chaotic { return "🤪" }
            default { return "🦆" }
        }
    }
    
    [string] GetMoodMessage() {
        $trigger = $this.MoodTriggers.Values | Where-Object { $_.Mood -eq $this.CurrentMood } | Select-Object -First 1
        if ($trigger) { return $trigger.Message }
        
        switch ($this.CurrentMood) {
            [SystemMood]::Happy { return "Waddle waddle! 🎉" }
            [SystemMood]::Angry { return "HONK! 😤" }
            [SystemMood]::Bored { return "Sooo boring... 😒" }
            [SystemMood]::Sleepy { return "*naps* 💤" }
            [SystemMood]::Curious { return "What's that? 🐣" }
            [SystemMood]::Mischievous { return "Hehe... 😏" }
            [SystemMood]::Chaotic { return "CHAOS! 🎊" }
            default { return "🦆" }
        }
    }
    
    [string] GetAnimation() {
        switch ($this.CurrentMood) {
            [SystemMood]::Happy { return "dance" }
            [SystemMood]::Angry { return "stomp" }
            [SystemMood]::Bored { return "sigh" }
            [SystemMood]::Sleepy { return "sleep" }
            [SystemMood]::Curious { return "follow" }
            [SystemMood]::Mischievous { return "hide" }
            [SystemMood]::Chaotic { return "spin" }
            default { return "wander" }
        }
    }
    
    [hashtable] GetSystemMoodState() {
        return @{
            Enabled = $this.Config["MoodSystemEnabled"]
            CurrentMood = $this.CurrentMood.ToString()
            Emoji = $this.GetMoodEmoji()
            Message = $this.GetMoodMessage()
            Animation = $this.GetAnimation()
            LastChange = $this.LastMoodChange
            SystemState = @{
                CpuUsage = $this.CpuUsage
                IdleMinutes = $this.IdleMinutes
                MusicPlaying = $this.IsMusicPlaying
            }
        }
    }
}

$gooseSystemMood = [GooseSystemMood]::new()

function Get-GooseSystemMood {
    return $gooseSystemMood
}

function Update-GooseMood {
    param($MoodSystem = $gooseSystemMood)
    $MoodSystem.UpdateSystemState()
    return $MoodSystem.GetSystemMoodState()
}

function Set-GooseSystemMood {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Happy", "Angry", "Bored", "Sleepy", "Curious", "Mischievous", "Chaotic", "Neutral")]
        [string]$Mood,
        $MoodSystem = $gooseSystemMood
    )
    $MoodSystem.SetMood([SystemMood]$Mood)
    return $MoodSystem.GetSystemMoodState()
}

function Get-SystemMoodState {
    param($MoodSystem = $gooseSystemMood)
    return $MoodSystem.GetSystemMoodState()
}

Write-Host "Desktop Goose System Mood Initialized"
$state = Get-SystemMoodState
Write-Host "Mood: $($state['CurrentMood']) $($state['Emoji'])"
