# Desktop Goose Pomodoro Timer System
# Provides focus timer with goose involvement

$LoggingScriptPath = Join-Path $PSScriptRoot "..\Core\GooseLogging.ps1"
if (Test-Path $LoggingScriptPath) {
    . $LoggingScriptPath
}

class GoosePomodoro {
    [hashtable]$Config
    [datetime]$SessionStart
    [datetime]$BreakStart
    [int]$CompletedSessions
    [int]$TotalMinutesFocused
    [string]$CurrentState
    [bool]$IsActive
    [bool]$IsBreak
    [int]$SessionDuration
    [int]$ShortBreakDuration
    [int]$LongBreakDuration
    [int]$SessionsBeforeLongBreak
    
    GoosePomodoro() {
        $this.Config = $this.LoadConfig()
        $this.SessionStart = Get-Date
        $this.BreakStart = Get-Date
        $this.CompletedSessions = 0
        $this.TotalMinutesFocused = 0
        $this.CurrentState = "idle"
        $this.IsActive = $false
        $this.IsBreak = $false
        $this.SessionDuration = 25
        $this.ShortBreakDuration = 5
        $this.LongBreakDuration = 15
        $this.SessionsBeforeLongBreak = 4
        $this.LoadSettings()
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
    
    [void] LoadSettings() {
        if ($this.Config["PomodoroDuration"]) {
            $this.SessionDuration = $this.Config["PomodoroDuration"]
        }
        if ($this.Config["ShortBreakDuration"]) {
            $this.ShortBreakDuration = $this.Config["ShortBreakDuration"]
        }
        if ($this.Config["LongBreakDuration"]) {
            $this.LongBreakDuration = $this.Config["LongBreakDuration"]
        }
        if ($this.Config["SessionsBeforeLongBreak"]) {
            $this.SessionsBeforeLongBreak = $this.Config["SessionsBeforeLongBreak"]
        }
    }
    
    [void] StartSession() {
        $this.IsActive = $true
        $this.IsBreak = $false
        $this.SessionStart = Get-Date
        $this.CurrentState = "focusing"
    }
    
    [void] StartBreak() {
        $this.IsActive = $true
        $this.IsBreak = $true
        $this.BreakStart = Get-Date
        $this.CurrentState = "break"
    }
    
    [void] CompleteSession() {
        $this.CompletedSessions++
        $this.TotalMinutesFocused += $this.SessionDuration
        $this.IsActive = $false
        $this.CurrentState = "completed"
    }
    
    [void] SkipBreak() {
        $this.IsActive = $false
        $this.IsBreak = $false
        $this.CurrentState = "idle"
    }
    
    [void] Reset() {
        $this.CompletedSessions = 0
        $this.TotalMinutesFocused = 0
        $this.IsActive = $false
        $this.IsBreak = $false
        $this.CurrentState = "idle"
    }
    
    [int] GetRemainingMinutes() {
        if (-not $this.IsActive) { return 0 }
        
        $startTime = if ($this.IsBreak) { $this.BreakStart } else { $this.SessionStart }
        $duration = if ($this.IsBreak) { 
            if ($this.CompletedSessions % $this.SessionsBeforeLongBreak -eq 0 -and $this.CompletedSessions -gt 0) {
                $this.LongBreakDuration
            } else {
                $this.ShortBreakDuration
            }
        } else { 
            $this.SessionDuration 
        }
        
        $elapsed = ((Get-Date) - $startTime).TotalMinutes
        return [Math]::Max(0, $duration - [int]$elapsed)
    }
    
    [int] GetRemainingSeconds() {
        if (-not $this.IsActive) { return 0 }
        
        $startTime = if ($this.IsBreak) { $this.BreakStart } else { $this.SessionStart }
        $duration = if ($this.IsBreak) { 
            if ($this.CompletedSessions % $this.SessionsBeforeLongBreak -eq 0 -and $this.CompletedSessions -gt 0) {
                $this.LongBreakDuration
            } else {
                $this.ShortBreakDuration
            }
        } else { 
            $this.SessionDuration 
        }
        
        $elapsed = ((Get-Date) - $startTime).TotalSeconds
        return [Math]::Max(0, ($duration * 60) - [int]$elapsed)
    }
    
    [double] GetProgress() {
        if (-not $this.IsActive) { return 0 }
        
        $startTime = if ($this.IsBreak) { $this.BreakStart } else { $this.SessionStart }
        $duration = if ($this.IsBreak) { 
            if ($this.CompletedSessions % $this.SessionsBeforeLongBreak -eq 0 -and $this.CompletedSessions -gt 0) {
                $this.LongBreakDuration
            } else {
                $this.ShortBreakDuration
            }
        } else { 
            $this.SessionDuration 
        }
        
        $elapsed = ((Get-Date) - $startTime).TotalMinutes
        return [Math]::Min(1.0, $elapsed / $duration)
    }
    
    [bool] ShouldComplete() {
        return $this.GetRemainingMinutes() -le 0 -and $this.IsActive
    }
    
    [bool] IsLongBreak() {
        return $this.IsBreak -and ($this.CompletedSessions % $this.SessionsBeforeLongBreak -eq 0 -and $this.CompletedSessions -gt 0)
    }
    
    [string] GetGooseAction() {
        $progress = $this.GetProgress()
        
        if (-not $this.IsActive) {
            return "waiting"
        }
        
        if ($this.IsBreak) {
            if ($progress -lt 0.3) {
                return "stretching"
            } elseif ($progress -lt 0.7) {
                return "relaxing"
            } else {
                return "looking_at_clock"
            }
        } else {
            if ($progress -lt 0.25) {
                return "settling_in"
            } elseif ($progress -lt 0.5) {
                return "working_hard"
            } elseif ($progress -lt 0.75) {
                return "staying_focused"
            } elseif ($progress -lt 0.9) {
                return "almost_there"
            } else {
                return "final_push"
            }
        }
    }
    
    [hashtable] GetStatus() {
        return @{
            "IsActive" = $this.IsActive
            "IsBreak" = $this.IsBreak
            "CurrentState" = $this.CurrentState
            "RemainingMinutes" = $this.GetRemainingMinutes()
            "RemainingSeconds" = $this.GetRemainingSeconds()
            "Progress" = $this.GetProgress()
            "CompletedSessions" = $this.CompletedSessions
            "TotalMinutesFocused" = $this.TotalMinutesFocused
            "IsLongBreak" = $this.IsLongBreak()
            "GooseAction" = $this.GetGooseAction()
            "SessionDuration" = $this.SessionDuration
            "BreakDuration" = if ($this.IsLongBreak()) { $this.LongBreakDuration } else { $this.ShortBreakDuration }
        }
    }
    
    [void] Update() {
        if ($this.ShouldComplete()) {
            if ($this.IsBreak) {
                $this.SkipBreak()
            } else {
                $this.CompleteSession()
                $this.StartBreak()
            }
        }
    }
}

# Initialize pomodoro system
$goosePomodoro = [GoosePomodoro]::new()

# Export functions
function Get-GoosePomodoro {
    return $goosePomodoro
}

function Start-PomodoroSession {
    param($Pomodoro = $goosePomodoro)
    $Pomodoro.StartSession()
}

function Start-PomodoroBreak {
    param($Pomodoro = $goosePomodoro)
    $Pomodoro.StartBreak()
}

function Skip-PomodoroBreak {
    param($Pomodoro = $goosePomodoro)
    $Pomodoro.SkipBreak()
}

function Reset-Pomodoro {
    param($Pomodoro = $goosePomodoro)
    $Pomodoro.Reset()
}

function Get-PomodoroStatus {
    param($Pomodoro = $goosePomodoro)
    $Pomodoro.Update()
    return $Pomodoro.GetStatus()
}

# Example usage
Write-Host "Desktop Goose Pomodoro Timer Initialized"
Write-LogInfo "Desktop Goose Pomodoro Timer Initialized"
Write-Host "Session Duration: $($goosePomodoro.SessionDuration) minutes"
Write-LogInfo "Session Duration: $($goosePomodoro.SessionDuration) minutes"
