# Desktop Goose Focus Session Leaderboard System
# Track and display focus session achievements

class GooseFocusLeaderboard {
    [hashtable]$Config
    [hashtable]$DailyStats
    [hashtable]$WeeklyStats
    [hashtable]$AllTimeStats
    [string]$LeaderboardFile
    
    GooseFocusLeaderboard() {
        $this.Config = $this.LoadConfig()
        $this.LeaderboardFile = "goose_leaderboard.json"
        $this.DailyStats = @{}
        $this.WeeklyStats = @{}
        $this.AllTimeStats = @{
            "TotalSessions" = 0
            "TotalMinutes" = 0
            "BestDay" = ""
            "BestDayMinutes" = 0
            "CurrentStreak" = 0
            "LongestStreak" = 0
        }
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
                    } else {
                        $this.Config[$key] = $value
                    }
                }
            }
        }
        
        return $this.Config
    }
    
    [void] LoadStats() {
        if (Test-Path $this.LeaderboardFile) {
            try {
                $data = Get-Content $this.LeaderboardFile | ConvertFrom-Json
                $this.DailyStats = $data.DailyStats
                $this.WeeklyStats = $data.WeeklyStats
                $this.AllTimeStats = $data.AllTimeStats
            } catch {}
        }
    }
    
    [void] SaveStats() {
        $data = @{
            "DailyStats" = $this.DailyStats
            "WeeklyStats" = $this.WeeklyStats
            "AllTimeStats" = $this.AllTimeStats
            "LastUpdated" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.LeaderboardFile -Encoding UTF8
    }
    
    [hashtable] RecordSession([int]$minutes) {
        $today = (Get-Date).ToString("yyyy-MM-dd")
        
        if (-not $this.DailyStats.ContainsKey($today)) {
            $this.DailyStats[$today] = @{
                "Sessions" = 0
                "Minutes" = 0
            }
        }
        
        $this.DailyStats[$today].Sessions++
        $this.DailyStats[$today].Minutes += $minutes
        
        $this.AllTimeStats.TotalSessions++
        $this.AllTimeStats.TotalMinutes += $minutes
        
        if ($this.DailyStats[$today].Minutes -gt $this.AllTimeStats.BestDayMinutes) {
            $this.AllTimeStats.BestDay = $today
            $this.AllTimeStats.BestDayMinutes = $this.DailyStats[$today].Minutes
        }
        
        $this.UpdateStreak()
        $this.CleanupOldStats()
        $this.SaveStats()
        
        return @{
            "true
            "Success" = $SessionMinutes" = $minutes
            "TodayStats" = $this.DailyStats[$today]
            "AllTimeStats" = $this.AllTimeStats
        }
    }
    
    [void] UpdateStreak() {
        $today = Get-Date
        $streak = 0
        
        for ($i = 0; $i -lt 365; $i++) {
            $date = $today.AddDays(-$i).ToString("yyyy-MM-dd")
            
            if ($this.DailyStats.ContainsKey($date) -and $this.DailyStats[$date].Minutes -gt 0) {
                $streak++
            } elseif ($i -gt 0) {
                break
            }
        }
        
        $this.AllTimeStats.CurrentStreak = $streak
        
        if ($streak -gt $this.AllTimeStats.LongestStreak) {
            $this.AllTimeStats.LongestStreak = $streak
        }
    }
    
    [void] CleanupOldStats() {
        $cutoff = (Get-Date).AddDays(-30).ToString("yyyy-MM-dd")
        
        $keysToRemove = @()
        foreach ($key in $this.DailyStats.Keys) {
            if ($key -lt $cutoff) {
                $keysToRemove += $key
            }
        }
        
        foreach ($key in $keysToRemove) {
            $this.DailyStats.Remove($key)
        }
    }
    
    [hashtable] GetTodayStats() {
        $today = (Get-Date).ToString("yyyy-MM-dd")
        
        if ($this.DailyStats.ContainsKey($today)) {
            return $this.DailyStats[$today]
        }
        
        return @{
            "Sessions" = 0
            "Minutes" = 0
        }
    }
    
    [array] GetWeeklyStats() {
        $week = @()
        
        for ($i = 6; $i -ge 0; $i--) {
            $date = (Get-Date).AddDays(-$i).ToString("yyyy-MM-dd")
            $dayStats = @{
                "Date" = $date
                "DayName" = (Get-Date).AddDays(-$i).DayOfWeek.ToString()
                "Minutes" = 0
                "Sessions" = 0
            }
            
            if ($this.DailyStats.ContainsKey($date)) {
                $dayStats.Minutes = $this.DailyStats[$date].Minutes
                $dayStats.Sessions = $this.DailyStats[$date].Sessions
            }
            
            $week += $dayStats
        }
        
        return $week
    }
    
    [hashtable] GetRank() {
        $todayMinutes = $this.GetTodayStats().Minutes
        
        $ranks = @(
            @{ MinMinutes = 0; Rank = "Novice Goose"; Emoji = "🐣" }
            @{ MinMinutes = 30; Rank = "Apprentice Goose"; Emoji = "🐤" }
            @{ MinMinutes = 60; Rank = "Focus Goose"; Emoji = "🦆" }
            @{ MinMinutes = 120; Rank = "Master Goose"; Emoji = "🦢" }
            @{ MinMinutes = 240; Rank = "Legendary Goose"; Emoji = "👑" }
        )
        
        $currentRank = $ranks[0]
        foreach ($r in $ranks) {
            if ($todayMinutes -ge $r.MinMinutes) {
                $currentRank = $r
            }
        }
        
        return @{
            "TodayMinutes" = $todayMinutes
            "Rank" = $currentRank.Rank
            "Emoji" = $currentRank.Emoji
            "NextRank" = $ranks | Where-Object { $_.MinMinutes -gt $todayMinutes } | Select-Object -First 1
        }
    }
    
    [hashtable] GetLeaderboardState() {
        return @{
            "TodayStats" = $this.GetTodayStats()
            "WeeklyStats" = $this.GetWeeklyStats()
            "AllTimeStats" = $this.AllTimeStats
            "CurrentRank" = $this.GetRank()
        }
    }
}

$gooseFocusLeaderboard = [GooseFocusLeaderboard]::new()

function Get-GooseFocusLeaderboard {
    return $gooseFocusLeaderboard
}

function Record-FocusSession {
    param(
        [int]$Minutes,
        $Leaderboard = $gooseFocusLeaderboard
    )
    return $Leaderboard.RecordSession($Minutes)
}

function Get-TodayFocusStats {
    param($Leaderboard = $gooseFocusLeaderboard)
    return $Leaderboard.GetTodayStats()
}

function Get-FocusRank {
    param($Leaderboard = $gooseFocusLeaderboard)
    return $Leaderboard.GetRank()
}

function Get-FocusLeaderboard {
    param($Leaderboard = $gooseFocusLeaderboard)
    return $Leaderboard.GetLeaderboardState()
}

Write-Host "Desktop Goose Focus Leaderboard System Initialized"
$state = Get-FocusLeaderboard
Write-Host "Current Rank: $($state['CurrentRank']['Rank'])"
Write-Host "Today's Focus: $($state['TodayStats']['Minutes']) minutes"
