# Desktop Goose Desktop Cleanliness Gamification System
# Gamify desktop organization

class GooseDesktopGamification {
    [hashtable]$Config
    [hashtable]$Stats
    [string]$StatsFile
    
    GooseDesktopGamification() {
        $this.Config = $this.LoadConfig()
        $this.StatsFile = "goose_gamification.json"
        $this.Stats = @{
            "TotalPoints" = 0
            "Level" = 1
            "Achievements" = @()
            "DailyStreak" = 0
            "BestStreak" = 0
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
        if (Test-Path $this.StatsFile) {
            try {
                $loaded = Get-Content $this.StatsFile | ConvertFrom-Json
                $this.Stats = $loaded
            } catch {}
        }
    }
    
    [void] SaveStats() {
        $this.Stats | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.StatsFile -Encoding UTF8
    }
    
    [int] GetPointsForLevel([int]$level) {
        return $level * 100
    }
    
    [hashtable] AddPoints([int]$points, [string]$reason) {
        $this.Stats.TotalPoints += $points
        
        $newLevel = [Math]::Floor($this.Stats.TotalPoints / 100) + 1
        $leveledUp = ($newLevel -gt $this.Stats.Level)
        $this.Stats.Level = $newLevel
        
        $this.SaveStats()
        
        return @{
            "Success" = $true
            "PointsAdded" = $points
            "TotalPoints" = $this.Stats.TotalPoints
            "Level" = $this.Stats.Level
            "LeveledUp" = $leveledUp
            "Message" = if ($leveledUp) { "Level up! Now level $($this.Stats.Level)!" } else { "+$points points for $reason" }
        }
    }
    
    [hashtable] UnlockAchievement([string]$id, [string]$name, [string]$description) {
        if ($this.Stats.Achievements -contains $id) {
            return @{
                "Success" = $false
                "AlreadyUnlocked" = $true
                "Message" = "Achievement already unlocked"
            }
        }
        
        $this.Stats.Achievements += @{
            "Id" = $id
            "Name" = $name
            "Description" = $description
            "UnlockedAt" = (Get-Date).ToString("o")
        }
        
        $this.SaveStats()
        
        return @{
            "Success" = $true
            "Achievement" = @{ "Name" = $name; "Description" = $description }
            "Message" = "Achievement unlocked: $name!"
        }
    }
    
    [hashtable] GetLevelProgress() {
        $currentLevelPoints = ($this.Stats.Level - 1) * 100
        $nextLevelPoints = $this.Stats.Level * 100
        $progress = ($this.Stats.TotalPoints - $currentLevelPoints) / ($nextLevelPoints - $currentLevelPoints) * 100
        
        return @{
            "Level" = $this.Stats.Level
            "TotalPoints" = $this.Stats.TotalPoints
            "PointsToNextLevel" = $nextLevelPoints - $this.Stats.TotalPoints
            "Progress" = [Math]::Round($progress, 1)
        }
    }
    
    [array] GetAchievements() {
        return $this.Stats.Achievements
    }
    
    [hashtable] GetGamificationState() {
        return @{
            "Stats" = $this.Stats
            "LevelProgress" = $this.GetLevelProgress()
            "AvailableAchievements" = $this.GetAvailableAchievements()
        }
    }
    
    [array] GetAvailableAchievements() {
        return @(
            @{ "Id" = "first_honor"; "Name" = "First Honor"; "Description" = "Earn your first 10 points" }
            @{ "Id" = "clean_desk"; "Name" = "Clean Desk"; "Description" = "Clean your desktop" }
            @{ "Id" = "focus_master"; "Name" = "Focus Master"; "Description" = "Complete 10 focus sessions" }
            @{ "Id" = "streak_warrior"; "Name" = "Streak Warrior"; "Description" = "Maintain a 7-day streak" }
        )
    }
}

$gooseGamification = [GooseDesktopGamification]::new()

function Get-GooseGamification {
    return $gooseGamification
}

function Add-GamificationPoints {
    param(
        [int]$Points,
        [string]$Reason,
        $Gamification = $gooseGamification
    )
    return $Gamification.AddPoints($Points, $Reason)
}

function Unlock-Achievement {
    param(
        [string]$Id,
        [string]$Name,
        [string]$Description,
        $Gamification = $gooseGamification
    )
    return $Gamification.UnlockAchievement($Id, $Name, $Description)
}

function Get-LevelProgress {
    param($Gamification = $gooseGamification)
    return $Gamification.GetLevelProgress()
}

function Get-GamificationState {
    param($Gamification = $gooseGamification)
    return $Gamification.GetGamificationState()
}

Write-Host "Desktop Goose Gamification System Initialized"
$state = Get-GamificationState
Write-Host "Level: $($state['LevelProgress']['Level'])"
Write-Host "Points: $($state['LevelProgress']['TotalPoints'])"
