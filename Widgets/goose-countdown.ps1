# Desktop Goose Countdown Timer Widget System
# Countdown timer widget

class GooseCountdownTimer {
    [hashtable]$Config
    [bool]$IsRunning
    [datetime]$EndTime
    [string]$Label
    [int]$DurationMinutes
    
    GooseCountdownTimer() {
        $this.Config = $this.LoadConfig()
        $this.IsRunning = $false
        $this.EndTime = Get-Date
        $this.Label = ""
        $this.DurationMinutes = 0
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
        
        return $this.Config
    }
    
    [hashtable] StartTimer([int]$minutes, [string]$label = "") {
        $this.DurationMinutes = $minutes
        $this.Label = $label
        $this.EndTime = (Get-Date).AddMinutes($minutes)
        $this.IsRunning = $true
        
        return @{
            "Success" = $true
            "DurationMinutes" = $minutes
            "Label" = $label
            "EndTime" = $this.EndTime.ToString("o")
            "Message" = if ($label) { "Timer started: $label" } else { "Timer started for $minutes minutes" }
        }
    }
    
    [hashtable] StopTimer() {
        $remaining = $this.GetRemaining()
        
        $this.IsRunning = $false
        $this.Label = ""
        
        return @{
            "Success" = $true
            "Message" = "Timer stopped"
            "WasRunning" = $true
        }
    }
    
    [hashtable] GetRemaining() {
        if (-not $this.IsRunning) {
            return @{
                "IsRunning" = $false
                "TotalSeconds" = 0
                "Formatted" = "00:00"
            }
        }
        
        $remaining = $this.EndTime - (Get-Date)
        
        if ($remaining.TotalSeconds -le 0) {
            $this.IsRunning = $false
            return @{
                "IsRunning" = $false
                "TotalSeconds" = 0
                "Formatted" = "00:00"
                "Completed" = $true
                "Label" = $this.Label
            }
        }
        
        $hours = [Math]::Floor($remaining.TotalHours)
        $minutes = $remaining.Minutes
        $seconds = $remaining.Seconds
        
        $formatted = if ($hours -gt 0) {
            "{0:D2}:{1:D2}:{2:D2}" -f $hours, $minutes, $seconds
        } else {
            "{0:D2}:{1:D2}" -f $minutes, $seconds
        }
        
        return @{
            "IsRunning" = $true
            "TotalSeconds" = $remaining.TotalSeconds
            "Hours" = $hours
            "Minutes" = $minutes
            "Seconds" = $seconds
            "Formatted" = $formatted
            "Label" = $this.Label
            "EndTime" = $this.EndTime.ToString("o")
        }
    }
    
    [hashtable] GetCountdownTimerState() {
        return @{
            "IsRunning" = $this.IsRunning
            "Label" = $this.Label
            "DurationMinutes" = $this.DurationMinutes
            "Remaining" = $this.GetRemaining()
        }
    }
}

$gooseCountdownTimer = [GooseCountdownTimer]::new()

function Get-GooseCountdownTimer {
    return $gooseCountdownTimer
}

function Start-CountdownTimer {
    param(
        [int]$Minutes,
        [string]$Label = "",
        $Timer = $gooseCountdownTimer
    )
    return $Timer.StartTimer($Minutes, $Label)
}

function Stop-CountdownTimer {
    param($Timer = $gooseCountdownTimer)
    return $Timer.StopTimer()
}

function Get-TimerRemaining {
    param($Timer = $gooseCountdownTimer)
    return $Timer.GetRemaining()
}

function Get-CountdownTimerState {
    param($Timer = $gooseCountdownTimer)
    return $Timer.GetCountdownTimerState()
}

Write-Host "Desktop Goose Countdown Timer System Initialized"
$state = Get-CountdownTimerState
Write-Host "Timer Running: $($state['IsRunning'])"
