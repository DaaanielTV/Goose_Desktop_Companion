class GooseScreenTime {
    [hashtable]$Config
    [hashtable]$DailyStats
    [datetime]$SessionStart
    [bool]$IsTracking
    [int]$TotalSecondsToday
    [int]$HealthyLimitMinutes
    
    GooseScreenTime() {
        $this.Config = $this.LoadConfig()
        $this.DailyStats = @{}
        $this.SessionStart = Get-Date
        $this.IsTracking = $false
        $this.TotalSecondsToday = 0
        $this.HealthyLimitMinutes = 480
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
                    } elseif ($value -match '^\d+\.\d+$') {
                        $this.Config[$key] = [double]$value
                    } else {
                        $this.Config[$key] = $value
                    }
                }
            }
        }
        
        if (-not $this.Config.ContainsKey("ScreenTimeEnabled")) {
            $this.Config["ScreenTimeEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("HealthyScreenLimitMinutes")) {
            $this.Config["HealthyScreenLimitMinutes"] = 480
        }
        
        return $this.Config
    }
    
    [void] LoadData() {
        $dataFile = "goose_screentime.json"
        
        if (Test-Path $dataFile) {
            try {
                $data = Get-Content $dataFile -Raw | ConvertFrom-Json
                $this.DailyStats = @{}
                
                if ($data.DailyStats) {
                    $data.DailyStats.PSObject.Properties | ForEach-Object {
                        $this.DailyStats[$_.Name] = $_.Value
                    }
                }
                
                $this.CleanOldData()
            } catch {}
        }
    }
    
    [void] SaveData() {
        $this.CleanOldData()
        
        $data = @{
            "DailyStats" = $this.DailyStats
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content "goose_screentime.json"
    }
    
    [void] CleanOldData() {
        $cutoffDate = (Get-Date).AddDays(-30).ToString("yyyy-MM-dd")
        $keysToRemove = @()
        
        foreach ($key in $this.DailyStats.Keys) {
            if ($key -lt $cutoffDate) {
                $keysToRemove += $key
            }
        }
        
        foreach ($key in $keysToRemove) {
            $this.DailyStats.Remove($key)
        }
    }
    
    [void] StartSession() {
        $this.SessionStart = Get-Date
        $this.IsTracking = $true
    }
    
    [void] EndSession() {
        if ($this.IsTracking) {
            $duration = ((Get-Date) - $this.SessionStart).TotalSeconds
            $this.TotalSecondsToday += [int]$duration
            $this.IsTracking = $false
            $this.SaveTodayStats()
        }
    }
    
    [void] SaveTodayStats() {
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        
        if (-not $this.DailyStats.ContainsKey($dateKey)) {
            $this.DailyStats[$dateKey] = @{
                "TotalSeconds" = 0
                "Sessions" = 0
                "LongestSession" = 0
            }
        }
        
        $this.DailyStats[$dateKey].TotalSeconds = $this.TotalSecondsToday
        $this.DailyStats[$dateKey].Sessions++
        
        $sessionDuration = ((Get-Date) - $this.SessionStart).TotalSeconds
        if ($sessionDuration -gt $this.DailyStats[$dateKey].LongestSession) {
            $this.DailyStats[$dateKey].LongestSession = $sessionDuration
        }
        
        $this.SaveData()
    }
    
    [void] UpdateCurrentSession() {
        if ($this.IsTracking) {
            $this.TotalSecondsToday += 1
        }
    }
    
    [hashtable] GetTodayStats() {
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        
        if (-not $this.DailyStats.ContainsKey($dateKey)) {
            $this.DailyStats[$dateKey] = @{
                "TotalSeconds" = 0
                "Sessions" = 0
                "LongestSession" = 0
            }
        }
        
        $totalSeconds = $this.DailyStats[$dateKey].TotalSeconds
        if ($this.IsTracking) {
            $totalSeconds += ((Get-Date) - $this.SessionStart).TotalSeconds
        }
        
        $healthyLimit = $this.Config["HealthyScreenLimitMinutes"]
        $usedPercent = ($totalSeconds / 60 / $healthyLimit) * 100
        
        return @{
            "Date" = $dateKey
            "TotalMinutes" = [Math]::Round($totalSeconds / 60, 1)
            "TotalHours" = [Math]::Round($totalSeconds / 3600, 2)
            "Sessions" = $this.DailyStats[$dateKey].Sessions
            "LongestSessionMinutes" = [Math]::Round($this.DailyStats[$dateKey].LongestSession / 60, 1)
            "HealthyLimitMinutes" = $healthyLimit
            "UsedPercent" = [Math]::Min(100, [Math]::Round($usedPercent, 1))
            "IsOverLimit" = ($totalSeconds / 60) -gt $healthyLimit
            "RemainingMinutes" = [Math]::Max(0, $healthyLimit - ($totalSeconds / 60))
            "IsTracking" = $this.IsTracking
        }
    }
    
    [hashtable] GetWeeklyStats() {
        $weekStats = @{}
        
        for ($i = 6; $i -ge 0; $i--) {
            $date = (Get-Date).AddDays(-$i)
            $dateKey = $date.ToString("yyyy-MM-dd")
            
            if ($this.DailyStats.ContainsKey($dateKey)) {
                $stats = $this.DailyStats[$dateKey]
                $weekStats[$dateKey] = @{
                    "TotalMinutes" = [Math]::Round($stats.TotalSeconds / 60, 1)
                    "TotalHours" = [Math]::Round($stats.TotalSeconds / 3600, 2)
                    "Sessions" = $stats.Sessions
                }
            } else {
                $weekStats[$dateKey] = @{
                    "TotalMinutes" = 0
                    "TotalHours" = 0
                    "Sessions" = 0
                }
            }
        }
        
        return $weekStats
    }
    
    [string] GetScreenTimeMessage() {
        $today = $this.GetTodayStats()
        
        if ($today.TotalMinutes -lt 30) {
            return "Just getting started today!"
        } elseif ($today.TotalMinutes -lt 120) {
            return "You've been productive today!"
        } elseif ($today.TotalMinutes -lt 240) {
            return "Taking breaks is important. Have you stretched lately?"
        } elseif ($today.UsedPercent -lt 100) {
            return "You're approaching your daily screen time limit."
        } else {
            return "You've exceeded your healthy screen time. Time for a break?"
        }
    }
    
    [bool] ShouldTakeBreak() {
        $today = $this.GetTodayStats()
        return $today.UsedPercent -ge 80 -and -not $today.IsOverLimit
    }
    
    [bool] NeedsBreakWarning() {
        $today = $this.GetTodayStats()
        return $today.IsOverLimit
    }
    
    [void] ResetToday() {
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        $this.DailyStats[$dateKey] = @{
            "TotalSeconds" = 0
            "Sessions" = 0
            "LongestSession" = 0
        }
        $this.TotalSecondsToday = 0
        $this.SaveData()
    }
    
    [hashtable] GetScreenTimeState() {
        return @{
            "Enabled" = $this.Config["ScreenTimeEnabled"]
            "TodayStats" = $this.GetTodayStats()
            "WeeklyStats" = $this.GetWeeklyStats()
            "Message" = $this.GetScreenTimeMessage()
            "ShouldTakeBreak" = $this.ShouldTakeBreak()
            "NeedsBreakWarning" = $this.NeedsBreakWarning()
        }
    }
}

$gooseScreenTime = [GooseScreenTime]::new()

function Get-GooseScreenTime {
    return $gooseScreenTime
}

function Start-ScreenTime {
    param($ScreenTime = $gooseScreenTime)
    $ScreenTime.StartSession()
}

function Stop-ScreenTime {
    param($ScreenTime = $gooseScreenTime)
    $ScreenTime.EndSession()
}

function Get-ScreenTimeStatus {
    param($ScreenTime = $gooseScreenTime)
    return $ScreenTime.GetScreenTimeState()
}

Write-Host "Desktop Goose Screen Time System Initialized"
$state = Get-ScreenTimeStatus
Write-Host "Screen Time Tracking: $($state['Enabled'])"
Write-Host "Today: $($state['TodayStats']['TotalHours']) hours"
