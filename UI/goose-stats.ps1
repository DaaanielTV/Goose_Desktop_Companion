# Desktop Goose Daily Stats Dashboard
# Provides comprehensive daily statistics and insights

class GooseStatsDashboard {
    [hashtable]$Config
    [hashtable]$DailyStats
    [hashtable]$WeeklyStats
    [hashtable]$AllTimeStats
    [datetime]$SessionStart
    [datetime]$Today
    
    GooseStatsDashboard() {
        $this.Config = $this.LoadConfig()
        $this.DailyStats = @{}
        $this.WeeklyStats = @{}
        $this.AllTimeStats = @{
            "TotalSessions" = 0
            "TotalFocusMinutes" = 0
            "TotalCommands" = 0
            "FavoriteCommand" = ""
            "DaysActive" = 0
            "FirstSession" = Get-Date
        }
        $this.SessionStart = Get-Date
        $this.Today = (Get-Date).Date
        $this.LoadStats()
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
    
    [void] LoadStats() {
        $statsFile = "goose_stats.json"
        
        if (Test-Path $statsFile) {
            try {
                $data = Get-Content $statsFile -Raw | ConvertFrom-Json
                $this.AllTimeStats["TotalSessions"] = $data.TotalSessions
                $this.AllTimeStats["TotalFocusMinutes"] = $data.TotalFocusMinutes
                $this.AllTimeStats["TotalCommands"] = $data.TotalCommands
                $this.AllTimeStats["FavoriteCommand"] = $data.FavoriteCommand
                $this.AllTimeStats["DaysActive"] = $data.DaysActive
                if ($data.FirstSession) {
                    $this.AllTimeStats["FirstSession"] = [datetime]$data.FirstSession
                }
            } catch {
                # Start fresh if error
            }
        }
    }
    
    [void] SaveStats() {
        $statsFile = "goose_stats.json"
        
        $data = @{
            "TotalSessions" = $this.AllTimeStats["TotalSessions"]
            "TotalFocusMinutes" = $this.AllTimeStats["TotalFocusMinutes"]
            "TotalCommands" = $this.AllTimeStats["TotalCommands"]
            "FavoriteCommand" = $this.AllTimeStats["FavoriteCommand"]
            "DaysActive" = $this.AllTimeStats["DaysActive"]
            "FirstSession" = $this.AllTimeStats["FirstSession"]
            "LastUpdated" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json | Set-Content $statsFile
    }
    
    [void] UpdateDailyStats([string]$key, [int]$value) {
        $dateKey = $this.Today.ToString("yyyy-MM-dd")
        
        if (-not $this.DailyStats.ContainsKey($dateKey)) {
            $this.DailyStats[$dateKey] = @{
                "FocusMinutes" = 0
                "CommandsUsed" = 0
                "Interactions" = 0
                "PomodoroSessions" = 0
                "TopApp" = ""
                "TopAppMinutes" = 0
            }
        }
        
        switch ($key) {
            "FocusMinutes" { $this.DailyStats[$dateKey]["FocusMinutes"] += $value }
            "CommandsUsed" { $this.DailyStats[$dateKey]["CommandsUsed"] += $value }
            "Interactions" { $this.DailyStats[$dateKey]["Interactions"] += $value }
            "PomodoroSessions" { $this.DailyStats[$dateKey]["PomodoroSessions"] += $value }
            "AppTime" { 
                $this.DailyStats[$dateKey]["TopAppMinutes"] += $value
                if ($this.DailyStats[$dateKey]["TopAppMinutes"] -gt $value) {
                    $this.DailyStats[$dateKey]["TopApp"] = $value
                }
            }
        }
    }
    
    [void] RecordFocusSession([int]$minutes) {
        $this.UpdateDailyStats("FocusMinutes", $minutes)
        $this.AllTimeStats["TotalFocusMinutes"] += $minutes
        $this.AllTimeStats["TotalSessions"]++
        $this.SaveStats()
    }
    
    [void] RecordCommand([string]$command) {
        $this.UpdateDailyStats("CommandsUsed", 1)
        $this.AllTimeStats["TotalCommands"]++
        
        if ($this.AllTimeStats["FavoriteCommand"] -eq "") {
            $this.AllTimeStats["FavoriteCommand"] = $command
        }
        
        $this.SaveStats()
    }
    
    [void] RecordInteraction() {
        $this.UpdateDailyStats("Interactions", 1)
    }
    
    [void] RecordPomodoroSession([int]$minutes) {
        $this.RecordFocusSession($minutes)
        $this.UpdateDailyStats("PomodoroSessions", 1)
    }
    
    [void] CheckDayChange() {
        if ((Get-Date).Date -ne $this.Today) {
            $oldDate = $this.Today
            $this.Today = (Get-Date).Date
            
            if (-not $this.AllTimeStats["DaysActive"]) {
                $this.AllTimeStats["DaysActive"] = 1
            }
            
            $this.SaveStats()
        }
    }
    
    [hashtable] GetTodaySummary() {
        $this.CheckDayChange()
        $dateKey = $this.Today.ToString("yyyy-MM-dd")
        
        if (-not $this.DailyStats.ContainsKey($dateKey)) {
            return @{
                "Date" = $dateKey
                "FocusMinutes" = 0
                "CommandsUsed" = 0
                "Interactions" = 0
                "PomodoroSessions" = 0
                "TopApp" = ""
                "SessionTime" = ((Get-Date) - $this.SessionStart).Minutes
            }
        }
        
        $stats = $this.DailyStats[$dateKey]
        
        return @{
            "Date" = $dateKey
            "FocusMinutes" = $stats["FocusMinutes"]
            "CommandsUsed" = $stats["CommandsUsed"]
            "Interactions" = $stats["Interactions"]
            "PomodoroSessions" = $stats["PomodoroSessions"]
            "TopApp" = $stats["TopApp"]
            "TopAppMinutes" = $stats["TopAppMinutes"]
            "SessionTime" = ((Get-Date) - $this.SessionStart).Minutes
        }
    }
    
    [hashtable] GetAllTimeStats() {
        return @{
            "TotalSessions" = $this.AllTimeStats["TotalSessions"]
            "TotalFocusMinutes" = $this.AllTimeStats["TotalFocusMinutes"]
            "TotalCommands" = $this.AllTimeStats["TotalCommands"]
            "FavoriteCommand" = $this.AllTimeStats["FavoriteCommand"]
            "DaysActive" = $this.AllTimeStats["DaysActive"]
            "FirstSession" = $this.AllTimeStats["FirstSession"]
            "AverageFocusPerSession" = if ($this.AllTimeStats["TotalSessions"] -gt 0) { [int]($this.AllTimeStats["TotalFocusMinutes"] / $this.AllTimeStats["TotalSessions"]) } else { 0 }
        }
    }
    
    [string] GetGooseDailyComment() {
        $todaySummary = $this.GetTodaySummary()
        
        if ($todaySummary["FocusMinutes"] -eq 0) {
            return "No focus time recorded today. Let's get started!"
        }
        
        if ($todaySummary["PomodoroSessions"] -ge 8) {
            return "Amazing! $($_['PomodoroSessions']) pomodoro sessions today! You're a focus champion!"
        }
        
        if ($todaySummary["FocusMinutes"] -ge 120) {
            return "Wow! $($_['FocusMinutes']) minutes of focused work today!"
        }
        
        if ($todaySummary["FocusMinutes"] -ge 60) {
            return "Great job! You've been focused for over an hour today!"
        }
        
        if ($todaySummary["FocusMinutes"] -ge 30) {
            return "Nice work! Keep it up!"
        }
        
        return "Good start! Every minute of focus counts!"
    }
    
    [hashtable] GetDashboardData() {
        return @{
            "Today" = $this.GetTodaySummary()
            "AllTime" = $this.GetAllTimeStats()
            "SessionStart" = $this.SessionStart
            "GooseComment" = $this.GetGooseDailyComment()
        }
    }
    
    [string] GenerateDailyReport() {
        $todaySummary = $this.GetTodaySummary()
        $allTime = $this.GetAllTimeStats()
        
        $report = @"
=== Daily Goose Report ===
Date: $($todaySummary['Date'])

FOCUS TIME
- Today's Focus: $($todaySummary['FocusMinutes']) minutes
- Pomodoro Sessions: $($todaySummary['PomodoroSessions'])
- Session Time: $($todaySummary['SessionTime']) minutes

INTERACTIONS
- Commands Used: $($todaySummary['CommandsUsed'])
- Interactions: $($todaySummary['Interactions'])

ALL-TIME STATS
- Total Sessions: $($allTime['TotalSessions'])
- Total Focus: $($allTime['TotalFocusMinutes']) minutes
- Total Commands: $($allTime['TotalCommands'])
- Days Active: $($allTime['DaysActive'])
- Favorite Command: $($allTime['FavoriteCommand'])

$($this.GetGooseDailyComment())
"@
        
        return $report
    }
    
    [void] SyncFromCloud([object]$cloudData) {
        if ($cloudData) {
            if ($cloudData.TotalSessions) { $this.AllTimeStats["TotalSessions"] = $cloudData.TotalSessions }
            if ($cloudData.TotalFocusMinutes) { $this.AllTimeStats["TotalFocusMinutes"] = $cloudData.TotalFocusMinutes }
            if ($cloudData.TotalCommands) { $this.AllTimeStats["TotalCommands"] = $cloudData.TotalCommands }
            if ($cloudData.FavoriteCommand) { $this.AllTimeStats["FavoriteCommand"] = $cloudData.FavoriteCommand }
            if ($cloudData.DaysActive) { $this.AllTimeStats["DaysActive"] = $cloudData.DaysActive }
            $this.SaveStats()
        }
    }
    
    [object] GetStatsForSync() {
        return @{
            "TotalSessions" = $this.AllTimeStats["TotalSessions"]
            "TotalFocusMinutes" = $this.AllTimeStats["TotalFocusMinutes"]
            "TotalCommands" = $this.AllTimeStats["TotalCommands"]
            "FavoriteCommand" = $this.AllTimeStats["FavoriteCommand"]
            "DaysActive" = $this.AllTimeStats["DaysActive"]
            "FirstSession" = $this.AllTimeStats["FirstSession"]
        }
    }
}

# Initialize stats dashboard
$gooseStatsDashboard = [GooseStatsDashboard]::new()

# Export functions
function Get-GooseStatsDashboard {
    return $gooseStatsDashboard
}

function Get-DailySummary {
    param($Dashboard = $gooseStatsDashboard)
    return $Dashboard.GetTodaySummary()
}

function Get-AllTimeStats {
    param($Dashboard = $gooseStatsDashboard)
    return $Dashboard.GetAllTimeStats()
}

function Get-DashboardData {
    param($Dashboard = $gooseStatsDashboard)
    return $Dashboard.GetDashboardData()
}

function Get-DailyReport {
    param($Dashboard = $gooseStatsDashboard)
    return $Dashboard.GenerateDailyReport()
}

function Record-FocusSession {
    param(
        [int]$Minutes,
        $Dashboard = $gooseStatsDashboard
    )
    $Dashboard.RecordFocusSession($Minutes)
}

function Record-GooseCommand {
    param(
        [string]$Command,
        $Dashboard = $gooseStatsDashboard
    )
    $Dashboard.RecordCommand($Command)
}

function Sync-GooseStats {
    param(
        [object]$SyncClient,
        $Dashboard = $gooseStatsDashboard
    )
    
    $pullResult = $SyncClient.PullData("stats")
    
    if ($pullResult.Success -and $pullResult.Source -eq "remote") {
        $Dashboard.SyncFromCloud($pullResult.Data)
        return @{
            "Success" = $true
            "Synced" = $true
            "Source" = "cloud"
        }
    }
    
    $syncResult = $SyncClient.QueueChange("stats", "Update", $Dashboard.GetStatsForSync())
    
    return @{
        "Success" = $true
        "Synced" = $false
        "Queued" = $true
    }
}

Write-Host "Desktop Goose Stats Dashboard Initialized"
$dashboard = Get-DashboardData
Write-Host "Today's Focus: $($dashboard.Today.FocusMinutes) minutes"
