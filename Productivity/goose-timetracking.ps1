# Desktop Goose Time Tracking System
# Tracks time spent in different applications

$LoggingScriptPath = Join-Path $PSScriptRoot "..\Core\GooseLogging.ps1"
if (Test-Path $LoggingScriptPath) {
    . $LoggingScriptPath
}

class GooseTimeTracker {
    [hashtable]$Config
    [hashtable]$DailyTracking
    [hashtable]$WeeklyTracking
    [hashtable]$AppHistory
    [string]$CurrentApp
    [datetime]$CurrentAppStart
    [datetime]$Today
    [int]$TotalTrackedMinutes
    
    GooseTimeTracker() {
        $this.Config = $this.LoadConfig()
        $this.DailyTracking = @{}
        $this.WeeklyTracking = @{}
        $this.AppHistory = @{}
        $this.CurrentApp = ""
        $this.CurrentAppStart = Get-Date
        $this.Today = (Get-Date).Date
        $this.TotalTrackedMinutes = 0
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
    
    [void] CheckCurrentApp() {
        try {
            $foreground = Get-Process | Where-Object { $_.MainWindowTitle -ne "" } | Select-Object -First 1
            if ($foreground) {
                $newApp = $foreground.ProcessName
                if ($newApp -ne $this.CurrentApp -and $newApp -ne "Unknown") {
                    $this.SwitchApp($newApp)
                }
            }
        } catch {
            # Silently ignore errors
        }
    }
    
    [void] SwitchApp([string]$newApp) {
        if ($this.CurrentApp -ne "" -and $this.CurrentApp -ne $newApp) {
            $this.RecordTime($this.CurrentApp)
        }
        
        $this.CurrentApp = $newApp
        $this.CurrentAppStart = Get-Date
    }
    
    [void] RecordTime([string]$appName) {
        $duration = ((Get-Date) - $this.CurrentAppStart).TotalMinutes
        $minutes = [int]$duration
        
        if ($minutes -lt 1) { return }
        
        $dateKey = $this.Today.ToString("yyyy-MM-dd")
        $dayOfWeek = (Get-Date).DayOfWeek.ToString()
        
        # Daily tracking
        if (-not $this.DailyTracking.ContainsKey($dateKey)) {
            $this.DailyTracking[$dateKey] = @{}
        }
        
        if ($this.DailyTracking[$dateKey].ContainsKey($appName)) {
            $this.DailyTracking[$dateKey][$appName] += $minutes
        } else {
            $this.DailyTracking[$dateKey][$appName] = $minutes
        }
        
        # Weekly tracking
        if (-not $this.WeeklyTracking.ContainsKey($dayOfWeek)) {
            $this.WeeklyTracking[$dayOfWeek] = @{}
        }
        
        if ($this.WeeklyTracking[$dayOfWeek].ContainsKey($appName)) {
            $this.WeeklyTracking[$dayOfWeek][$appName] += $minutes
        } else {
            $this.WeeklyTracking[$dayOfWeek][$appName] = $minutes
        }
        
        # App history
        if (-not $this.AppHistory.ContainsKey($appName)) {
            $this.AppHistory[$appName] = @{
                "TotalMinutes" = 0
                "Sessions" = 0
                "FirstSeen" = Get-Date
                "LastSeen" = Get-Date
            }
        }
        
        $this.AppHistory[$appName]["TotalMinutes"] += $minutes
        $this.AppHistory[$appName]["Sessions"]++
        $this.AppHistory[$appName]["LastSeen"] = Get-Date
        
        $this.TotalTrackedMinutes += $minutes
    }
    
    [void] Update() {
        # Check if day changed
        if ((Get-Date).Date -ne $this.Today) {
            $this.Today = (Get-Date).Date
        }
        
        # Track current app
        $this.CheckCurrentApp()
    }
    
    [hashtable] GetTodayStats() {
        $dateKey = $this.Today.ToString("yyyy-MM-dd")
        
        if (-not $this.DailyTracking.ContainsKey($dateKey)) {
            return @{
                "TotalMinutes" = 0
                "Apps" = @{}
                "TopApp" = ""
                "MostTime" = 0
            }
        }
        
        $apps = $this.DailyTracking[$dateKey]
        $total = ($apps.Values | Measure-Object -Sum).Sum
        $topApp = ($apps.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 1)
        
        return @{
            "TotalMinutes" = $total
            "Apps" = $apps.Clone()
            "TopApp" = if ($topApp) { $topApp.Key } else { "" }
            "MostTime" = if ($topApp) { $topApp.Value } else { 0 }
        }
    }
    
    [hashtable] GetWeeklyStats() {
        return @{
            "WeeklyData" = $this.WeeklyTracking.Clone()
            "TotalDaysTracked" = $this.WeeklyTracking.Count
        }
    }
    
    [hashtable] GetAppHistory() {
        return @{
            "Apps" = $this.AppHistory.Clone()
            "TotalApps" = $this.AppHistory.Count
        }
    }
    
    [hashtable] GetCurrentSession() {
        $duration = ((Get-Date) - $this.CurrentAppStart).TotalMinutes
        
        return @{
            "CurrentApp" = $this.CurrentApp
            "SessionStart" = $this.CurrentAppStart
            "SessionMinutes" = [int]$duration
        }
    }
    
    [hashtable] GetProductivityScore() {
        $todayStats = $this.GetTodayStats()
        
        if ($todayStats["TotalMinutes"] -eq 0) {
            return @{
                "Score" = 0
                "Rating" = "No data"
                "Breakdown" = @{}
            }
        }
        
        # Define productive vs unproductive categories
        $productiveApps = @("code", "visualstudio", "vscode", "idea", "excel", "word", "powerpoint", "outlook", "teams", "slack")
        $unproductiveApps = @("chrome", "firefox", "spotify", "vlc", "steam", "games", "solitaire", "minesweeper")
        
        $productive = 0
        $unproductive = 0
        $neutral = 0
        
        foreach ($app in $todayStats["Apps"].Keys) {
            $time = $todayStats["Apps"][$app]
            $isProductive = $false
            $isUnproductive = $false
            
            foreach ($prod in $productiveApps) {
                if ($app -like "*$prod*") { $isProductive = $true; break }
            }
            
            foreach ($unprod in $unproductiveApps) {
                if ($app -like "*$unprod*") { $isUnproductive = $true; break }
            }
            
            if ($isProductive) { $productive += $time }
            elseif ($isUnproductive) { $unproductive += $time }
            else { $neutral += $time }
        }
        
        $total = $productive + $unproductive + $neutral
        if ($total -eq 0) {
            return @{ "Score" = 50; "Rating" = "Neutral"; "Breakdown" = @{ "Productive" = 0; "Neutral" = 0; "Unproductive" = 0 } }
        }
        
        $score = [int](($productive * 100 + $neutral * 50) / $total)
        
        $rating = if ($score -ge 80) { "Excellent" }
                  elseif ($score -ge 60) { "Good" }
                  elseif ($score -ge 40) { "Fair" }
                  else { "Needs Improvement" }
        
        return @{
            "Score" = $score
            "Rating" = $rating
            "Breakdown" = @{
                "Productive" = $productive
                "Neutral" = $neutral
                "Unproductive" = $unproductive
            }
        }
    }
    
    [string] GetGooseComment() {
        $score = $this.GetProductivityScore()
        
        if ($score["Score"] -ge 80) {
            return "You're being super productive! I'm proud of you!"
        } elseif ($score["Score"] -ge 60) {
            return "Good focus today! Keep it up!"
        } elseif ($score["Score"] -ge 40) {
            return "Balanced work and breaks. That's healthy!"
        } else {
            return "Having fun? Just remember to get some work done too!"
        }
    }
    
    [void] ResetDaily() {
        $dateKey = $this.Today.ToString("yyyy-MM-dd")
        $this.DailyTracking[$dateKey] = @{}
    }
}

# Initialize time tracker
$gooseTimeTracker = [GooseTimeTracker]::new()

# Export functions
function Get-GooseTimeTracker {
    return $gooseTimeTracker
}

function Get-TodayStats {
    param($Tracker = $gooseTimeTracker)
    $Tracker.Update()
    return $Tracker.GetTodayStats()
}

function Get-WeeklyStats {
    param($Tracker = $gooseTimeTracker)
    return $Tracker.GetWeeklyStats()
}

function Get-ProductivityScore {
    param($Tracker = $gooseTimeTracker)
    return $Tracker.GetProductivityScore()
}

function Get-CurrentSession {
    param($Tracker = $gooseTimeTracker)
    $Tracker.Update()
    return $Tracker.GetCurrentSession()
}

function Get-GooseComment {
    param($Tracker = $gooseTimeTracker)
    return $Tracker.GetGooseComment()
}

# Example usage
Write-Host "Desktop Goose Time Tracking Initialized"
Write-Host "Tracking enabled: $($gooseTimeTracker.Config["TimeTrackingEnabled"])"
