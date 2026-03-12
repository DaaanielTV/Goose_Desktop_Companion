# Desktop Goose Focus Mode System
# Provides distraction-free focus periods

class GooseFocus {
    [hashtable]$Config
    [bool]$IsFocusActive
    [datetime]$FocusStartTime
    [int]$FocusDurationMinutes
    [int]$FocusCyclesCompleted
    [hashtable]$FocusHistory
    [string]$CurrentFocusMode
    
    GooseFocus() {
        $this.Config = $this.LoadConfig()
        $this.IsFocusActive = $false
        $this.FocusStartTime = Get-Date
        $this.FocusDurationMinutes = 25
        $this.FocusCyclesCompleted = 0
        $this.FocusHistory = @{}
        $this.CurrentFocusMode = "Normal"
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
        
        if (-not $this.Config.ContainsKey("FocusModeEnabled")) {
            $this.Config["FocusModeEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("FocusDurationMinutes")) {
            $this.Config["FocusDurationMinutes"] = 25
        }
        if (-not $this.Config.ContainsKey("AutoFocusApps")) {
            $this.Config["AutoFocusApps"] = "vscode,idea,visualstudio,sublime"
        }
        
        return $this.Config
    }
    
    [hashtable] StartFocus([int]$durationMinutes = 0) {
        if ($durationMinutes -gt 0) {
            $this.FocusDurationMinutes = $durationMinutes
        } else {
            $this.FocusDurationMinutes = $this.Config["FocusDurationMinutes"]
        }
        
        $this.IsFocusActive = $true
        $this.FocusStartTime = Get-Date
        $this.CurrentFocusMode = "Focus"
        
        return @{
            "Success" = $true
            "StartedAt" = $this.FocusStartTime
            "Duration" = $this.FocusDurationMinutes
            "EndsAt" = $this.FocusStartTime.AddMinutes($this.FocusDurationMinutes)
            "Mode" = $this.CurrentFocusMode
        }
    }
    
    [hashtable] EndFocus([bool]$completed = $true) {
        $focusDuration = ((Get-Date) - $this.FocusStartTime).TotalMinutes
        
        $session = @{
            "StartTime" = $this.FocusStartTime.ToString("o")
            "EndTime" = (Get-Date).ToString("o")
            "DurationMinutes" = $focusDuration
            "Completed" = $completed
            "Mode" = $this.CurrentFocusMode
        }
        
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        if (-not $this.FocusHistory.ContainsKey($dateKey)) {
            $this.FocusHistory[$dateKey] = @()
        }
        $this.FocusHistory[$dateKey] += $session
        
        if ($completed) {
            $this.FocusCyclesCompleted++
        }
        
        $this.IsFocusActive = $false
        $this.CurrentFocusMode = "Normal"
        
        return @{
            "Success" = $true
            "Session" = $session
            "CyclesCompleted" = $this.FocusCyclesCompleted
            "Message" = if ($completed) { "Great focus session!" } else { "Focus ended." }
        }
    }
    
    [hashtable] GetFocusStatus() {
        $status = @{
            "IsActive" = $this.IsFocusActive
            "Mode" = $this.CurrentFocusMode
            "Duration" = $this.FocusDurationMinutes
            "CyclesCompleted" = $this.FocusCyclesCompleted
        }
        
        if ($this.IsFocusActive) {
            $elapsed = (Get-Date) - $this.FocusStartTime
            $remaining = $this.FocusDurationMinutes - $elapsed.TotalMinutes
            
            $status["ElapsedMinutes"] = [Math]::Round($elapsed.TotalMinutes, 1)
            $status["RemainingMinutes"] = [Math]::Max(0, [Math]::Round($remaining, 1))
            $status["Progress"] = [Math]::Min(100, [Math]::Round(($elapsed.TotalMinutes / $this.FocusDurationMinutes) * 100))
            $status["EndsAt"] = $this.FocusStartTime.AddMinutes($this.FocusDurationMinutes)
        }
        
        return $status
    }
    
    [bool] CheckAutoFocus() {
        if ($this.IsFocusActive) { return $true }
        
        $autoApps = $this.Config["AutoFocusApps"] -split ","
        $currentApp = $this.GetActiveApplication()
        
        foreach ($app in $autoApps) {
            if ($currentApp -like "*$app*") {
                return $true
            }
        }
        
        return $false
    }
    
    [string] GetActiveApplication() {
        try {
            $process = Get-Process | Where-Object { $_.MainWindowTitle -ne "" } | Select-Object -First 1
            if ($process) {
                return $process.ProcessName
            }
        } catch {}
        
        return ""
    }
    
    [void] SetFocusMode([string]$mode) {
        $validModes = @("Normal", "Focus", "DeepWork", "Break", "Study")
        
        if ($validModes -contains $mode) {
            $this.CurrentFocusMode = $mode
            
            switch ($mode) {
                "Focus" { $this.FocusDurationMinutes = 25 }
                "DeepWork" { $this.FocusDurationMinutes = 90 }
                "Break" { $this.FocusDurationMinutes = 5 }
                "Study" { $this.FocusDurationMinutes = 45 }
                "Normal" { $this.IsFocusActive = $false }
            }
        }
    }
    
    [hashtable] GetTodayStats() {
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        $todaySessions = @()
        
        if ($this.FocusHistory.ContainsKey($dateKey)) {
            $todaySessions = $this.FocusHistory[$dateKey]
        }
        
        $totalMinutes = 0
        $completedCount = 0
        
        foreach ($session in $todaySessions) {
            $totalMinutes += $session.DurationMinutes
            if ($session.Completed) { $completedCount++ }
        }
        
        return @{
            "Date" = $dateKey
            "Sessions" = $todaySessions.Count
            "CompletedSessions" = $completedCount
            "TotalFocusMinutes" = [Math]::Round($totalMinutes, 1)
            "CyclesToday" = $completedCount
        }
    }
    
    [hashtable] GetFocusState() {
        return @{
            "Enabled" = $this.Config["FocusModeEnabled"]
            "Status" = $this.GetFocusStatus()
            "Mode" = $this.CurrentFocusMode
            "TodayStats" = $this.GetTodayStats()
            "AutoApps" = $this.Config["AutoFocusApps"]
        }
    }
    
    [void] ToggleFocus() {
        if ($this.IsFocusActive) {
            $this.EndFocus($false)
        } else {
            $this.StartFocus()
        }
    }
    
    [void] SetDuration([int]$minutes) {
        $this.FocusDurationMinutes = $minutes
        $this.Config["FocusDurationMinutes"] = $minutes
    }
}

$gooseFocus = [GooseFocus]::new()

function Get-GooseFocus {
    return $gooseFocus
}

function Start-FocusMode {
    param(
        [int]$Duration = 0,
        $Focus = $gooseFocus
    )
    return $Focus.StartFocus($Duration)
}

function Stop-FocusMode {
    param(
        [bool]$Completed = $true,
        $Focus = $gooseFocus
    )
    return $Focus.EndFocus($Completed)
}

function Get-FocusStatus {
    param($Focus = $gooseFocus)
    return $Focus.GetFocusStatus()
}

function Toggle-FocusMode {
    param($Focus = $gooseFocus)
    $Focus.ToggleFocus()
    return $Focus.GetFocusStatus()
}

Write-Host "Desktop Goose Focus Mode System Initialized"
$state = $gooseFocus.GetFocusState()
Write-Host "Focus Mode Enabled: $($state['Enabled'])"
Write-Host "Current Mode: $($state['Mode'])"
