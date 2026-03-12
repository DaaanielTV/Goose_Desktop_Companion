# Desktop Goose Habit Tracker System
# Track daily habits and goals

$LoggingScriptPath = Join-Path $PSScriptRoot "..\Core\GooseLogging.ps1"
if (Test-Path $LoggingScriptPath) {
    . $LoggingScriptPath
}

class GooseHabitTracker {
    [hashtable]$Config
    [array]$Habits
    [string]$HabitFile
    
    GooseHabitTracker() {
        $this.Config = $this.LoadConfig()
        $this.HabitFile = "goose_habits.json"
        $this.Habits = @()
        $this.LoadHabits()
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
    
    [void] LoadHabits() {
        if (Test-Path $this.HabitFile) {
            try {
                $this.Habits = Get-Content $this.HabitFile | ConvertFrom-Json
                if ($this.Habits -isnot [array]) {
                    $this.Habits = @()
                }
            } catch {
                $this.Habits = @()
            }
        }
    }
    
    [void] SaveHabits() {
        $this.Habits | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.HabitFile -Encoding UTF8
    }
    
    [hashtable] AddHabit([string]$name, [string]$frequency = "daily", [int]$goal = 1) {
        $habit = @{
            "Id" = [guid]::NewGuid().ToString()
            "Name" = $name
            "Frequency" = $frequency
            "Goal" = $goal
            "Created" = (Get-Date).ToString("yyyy-MM-dd")
            "Completed" = 0
            "Streak" = 0
            "BestStreak" = 0
            "History" = @()
        }
        
        $this.Habits += $habit
        $this.SaveHabits()
        
        return @{
            "Success" = $true
            "Habit" = $habit
            "Message" = "Habit '$name' created!"
        }
    }
    
    [hashtable] CompleteHabit([string]$habitId, [int]$amount = 1) {
        $habit = $this.Habits | Where-Object { $_.Id -eq $habitId } | Select-Object -First 1
        
        if (-not $habit) {
            return @{
                "Success" = $false
                "Message" = "Habit not found"
            }
        }
        
        $habit.Completed += $amount
        $today = (Get-Date).ToString("yyyy-MM-dd")
        
        $todayEntry = $habit.History | Where-Object { $_.Date -eq $today } | Select-Object -First 1
        
        if ($todayEntry) {
            $todayEntry.Count += $amount
        } else {
            $habit.History += @{
                "Date" = $today
                "Count" = $amount
            }
        }
        
        if ($habit.Completed -ge $habit.Goal) {
            $habit.Streak++
            if ($habit.Streak -gt $habit.BestStreak) {
                $habit.BestStreak = $habit.Streak
            }
            $message = "Habit completed! $($habit.Streak) day streak!"
        } else {
            $message = "$($habit.Completed)/$($habit.Goal) completed"
        }
        
        $this.SaveHabits()
        
        return @{
            "Success" = $true
            "Habit" = $habit
            "Completed" = $habit.Completed
            "Goal" = $habit.Goal
            "Streak" = $habit.Streak
            "Message" = $message
        }
    }
    
    [hashtable] RemoveHabit([string]$habitId) {
        $initialCount = $this.Habits.Count
        $this.Habits = $this.Habits | Where-Object { $_.Id -ne $habitId }
        
        if ($this.Habits.Count -lt $initialCount) {
            $this.SaveHabits()
            return @{
                "Success" = $true
                "Message" = "Habit removed"
            }
        }
        
        return @{
            "Success" = $false
            "Message" = "Habit not found"
        }
    }
    
    [array] GetTodayHabits() {
        $today = (Get-Date).ToString("yyyy-MM-dd")
        
        return $this.Habits | ForEach-Object {
            $habit = $_
            $todayEntry = $habit.History | Where-Object { $_.Date -eq $today } | Select-Object -First 1
            
            @{
                "Id" = $habit.Id
                "Name" = $habit.Name
                "Goal" = $habit.Goal
                "Completed" = if ($todayEntry) { $todayEntry.Count } else { 0 }
                "Streak" = $habit.Streak
                "IsComplete" = $todayEntry.Count -ge $habit.Goal
            }
        }
    }
    
    [hashtable] GetHabitStats() {
        $totalHabits = $this.Habits.Count
        $today = (Get-Date).ToString("yyyy-MM-dd")
        
        $completedToday = 0
        $totalGoal = 0
        $totalCompleted = 0
        
        foreach ($habit in $this.Habits) {
            $todayEntry = $habit.History | Where-Object { $_.Date -eq $today } | Select-Object -First 1
            $totalGoal += $habit.Goal
            $totalCompleted += if ($todayEntry) { $todayEntry.Count } else { 0 }
            
            if ($todayEntry -and $todayEntry.Count -ge $habit.Goal) {
                $completedToday++
            }
        }
        
        return @{
            "TotalHabits" = $totalHabits
            "CompletedToday" = $completedToday
            "TodayProgress" = "$totalCompleted/$totalGoal"
            "TodayPercentage" = if ($totalGoal -gt 0) { [Math]::Round(($totalCompleted / $totalGoal) * 100) } else { 0 }
        }
    }
    
    [hashtable] GetHabitTrackerState() {
        return @{
            "Habits" = $this.GetTodayHabits()
            "Stats" = $this.GetHabitStats()
            "AllHabits" = $this.Habits
        }
    }
    
    [void] SyncFromCloud([object]$cloudData) {
        if ($cloudData -and $cloudData -is [array]) {
            $this.Habits = $cloudData
            $this.SaveHabits()
        }
    }
    
    [object] GetHabitsForSync() {
        return $this.Habits
    }
}

$gooseHabitTracker = [GooseHabitTracker]::new()

function Get-GooseHabitTracker {
    return $gooseHabitTracker
}

function Add-Habit {
    param(
        [string]$Name,
        [string]$Frequency = "daily",
        [int]$Goal = 1,
        $Tracker = $gooseHabitTracker
    )
    return $Tracker.AddHabit($Name, $Frequency, $Goal)
}

function Complete-Habit {
    param(
        [string]$HabitId,
        [int]$Amount = 1,
        $Tracker = $gooseHabitTracker
    )
    return $Tracker.CompleteHabit($HabitId, $Amount)
}

function Get-TodayHabits {
    param($Tracker = $gooseHabitTracker)
    return $Tracker.GetTodayHabits()
}

function Get-HabitTrackerState {
    param($Tracker = $gooseHabitTracker)
    return $Tracker.GetHabitTrackerState()
}

function Sync-GooseHabits {
    param(
        [object]$SyncClient,
        $Tracker = $gooseHabitTracker
    )
    
    $pullResult = $SyncClient.PullData("habits")
    
    if ($pullResult.Success -and $pullResult.Source -eq "remote") {
        $Tracker.SyncFromCloud($pullResult.Data)
        return @{
            "Success" = $true
            "Synced" = $true
            "Source" = "cloud"
            "HabitsCount" = $Tracker.Habits.Count
        }
    }
    
    $syncResult = $SyncClient.QueueChange("habits", "Update", $Tracker.GetHabitsForSync())
    
    return @{
        "Success" = $true
        "Synced" = $false
        "Queued" = $true
        "HabitsCount" = $Tracker.Habits.Count
    }
}

Write-Host "Desktop Goose Habit Tracker System Initialized"
Write-LogInfo "Desktop Goose Habit Tracker System Initialized"
$state = Get-HabitTrackerState
Write-Host "Total Habits: $($state['Stats']['TotalHabits'])"
Write-LogInfo "Total Habits: $($state['Stats']['TotalHabits'])"
Write-Host "Completed Today: $($state['Stats']['CompletedToday'])"
Write-LogInfo "Completed Today: $($state['Stats']['CompletedToday'])"
