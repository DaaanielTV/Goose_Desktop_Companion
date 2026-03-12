# Desktop Goose Sleep/Wake Cycle System
# Goose sleeps when user is idle, wakes on activity

class GooseSleepWake {
    [hashtable]$Config
    [bool]$IsSleeping
    [datetime]$SleepStartTime
    [datetime]$LastActivityTime
    [int]$IdleTimeoutSeconds
    [int]$WakeUpDelaySeconds
    [string]$SleepAnimation
    [string]$WakeAnimation
    
    GooseSleepWake() {
        $this.Config = $this.LoadConfig()
        $this.IsSleeping = $false
        $this.SleepStartTime = Get-Date
        $this.LastActivityTime = Get-Date
        $this.IdleTimeoutSeconds = 300
        $this.WakeUpDelaySeconds = 2
        $this.SleepAnimation = "sleeping"
        $this.WakeAnimation = "stretching"
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
        
        if (-not $this.Config.ContainsKey("SleepWakeEnabled")) {
            $this.Config["SleepWakeEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("IdleTimeoutSeconds")) {
            $this.Config["IdleTimeoutSeconds"] = 300
        }
        
        return $this.Config
    }
    
    [void] UpdateIdleTime() {
        $this.LastActivityTime = Get-Date
    }
    
    [bool] CheckIdleTimeout() {
        $idleTime = (Get-Date) - $this.LastActivityTime
        return ($idleTime.TotalSeconds -ge $this.IdleTimeoutSeconds)
    }
    
    [hashtable] GoToSleep() {
        if ($this.IsSleeping) {
            return @{
                "Success" = $false
                "AlreadySleeping" = $true
                "Message" = "Goose is already sleeping"
            }
        }
        
        $this.IsSleeping = $true
        $this.SleepStartTime = Get-Date
        
        return @{
            "Success" = $true
            "Animation" = $this.SleepAnimation
            "Message" = "Goodnight!"
            "SleepDuration" = 0
        }
    }
    
    [hashtable] WakeUp() {
        if (-not $this.IsSleeping) {
            return @{
                "Success" = $false
                "AlreadyAwake" = $true
                "Message" = "Goose is already awake"
            }
        }
        
        $sleepDuration = (Get-Date) - $this.SleepStartTime
        $this.IsSleeping = $false
        
        $greeting = $this.GetWakeGreeting($sleepDuration)
        
        return @{
            "Success" = $true
            "Animation" = $this.WakeAnimation
            "Message" = $greeting
            "SleepDurationSeconds" = $sleepDuration.TotalSeconds
        }
    }
    
    [string] GetWakeGreeting([TimeSpan]$sleepDuration) {
        if ($sleepDuration.TotalMinutes -lt 5) {
            return "Just resting my eyes!"
        }
        elseif ($sleepDuration.TotalMinutes -lt 15) {
            return "That was a nice nap!"
        }
        elseif ($sleepDuration.TotalHours -lt 1) {
            return "I had a great sleep!"
        }
        else {
            return "Good morning... wait, is it still today?"
        }
    }
    
    [void] SetIdleTimeout([int]$seconds) {
        $this.IdleTimeoutSeconds = $seconds
        $this.Config["IdleTimeoutSeconds"] = $seconds
    }
    
    [hashtable] GetSleepWakeState() {
        $state = @{
            "Enabled" = $this.Config["SleepWakeEnabled"]
            "IsSleeping" = $this.IsSleeping
            "IdleTimeoutSeconds" = $this.IdleTimeoutSeconds
            "LastActivityTime" = $this.LastActivityTime
            "CurrentAnimation" = if ($this.IsSleeping) { $this.SleepAnimation } else { "wandering" }
        }
        
        if ($this.IsSleeping) {
            $state["SleepStartTime"] = $this.SleepStartTime
            $state["SleepDurationSeconds"] = ((Get-Date) - $this.SleepStartTime).TotalSeconds
        }
        
        return $state
    }
    
    [void] ToggleSleep() {
        if ($this.IsSleeping) {
            $this.WakeUp() | Out-Null
        } else {
            $this.GoToSleep() | Out-Null
        }
    }
    
    [bool] ShouldSleep() {
        if (-not $this.Config["SleepWakeEnabled"]) { return $false }
        if ($this.IsSleeping) { return $false }
        return $this.CheckIdleTimeout()
    }
    
    [bool] ShouldWake() {
        if (-not $this.IsSleeping) { return $false }
        
        $idleTime = (Get-Date) - $this.LastActivityTime
        return ($idleTime.TotalSeconds -lt $this.WakeUpDelaySeconds)
    }
}

$gooseSleepWake = [GooseSleepWake]::new()

function Get-GooseSleepWake {
    return $gooseSleepWake
}

function Invoke-GooseSleep {
    param($SleepWake = $gooseSleepWake)
    return $SleepWake.GoToSleep()
}

function Invoke-GooseWake {
    param($SleepWake = $gooseSleepWake)
    return $SleepWake.WakeUp()
}

function Test-ShouldSleep {
    param($SleepWake = $gooseSleepWake)
    return $SleepWake.ShouldSleep()
}

function Test-ShouldWake {
    param($SleepWake = $gooseSleepWake)
    return $SleepWake.ShouldWake()
}

function Update-UserActivity {
    param($SleepWake = $gooseSleepWake)
    $SleepWake.UpdateIdleTime()
}

function Get-SleepWakeState {
    param($SleepWake = $gooseSleepWake)
    return $SleepWake.GetSleepWakeState()
}

Write-Host "Desktop Goose Sleep/Wake System Initialized"
$state = Get-SleepWakeState
Write-Host "Sleep/Wake Enabled: $($state['Enabled'])"
Write-Host "Current State: $(if ($state['IsSleeping']) { 'Sleeping' } else { 'Awake' })"
