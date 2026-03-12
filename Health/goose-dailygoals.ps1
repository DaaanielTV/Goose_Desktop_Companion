class GooseDailyGoals {
    [hashtable]$Config
    [hashtable]$Goals
    [hashtable]$DailyProgress
    [datetime]$DayStart
    
    GooseDailyGoals() {
        $this.Config = $this.LoadConfig()
        $this.Goals = @{}
        $this.DailyProgress = @{}
        $this.DayStart = Get-Date
        $this.InitDefaultGoals()
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
        
        if (-not $this.Config.ContainsKey("DailyGoalsEnabled")) {
            $this.Config["DailyGoalsEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] InitDefaultGoals() {
        $defaultGoals = @{
            "Water" = @{
                "Name" = "Drink 8 glasses of water"
                "Target" = 8
                "Current" = 0
                "Unit" = "glasses"
                "Category" = "Health"
            }
            "Steps" = @{
                "Name" = "Take 10,000 steps"
                "Target" = 10000
                "Current" = 0
                "Unit" = "steps"
                "Category" = "Health"
            }
            "Focus" = @{
                "Name" = "Complete 4 focus sessions"
                "Target" = 4
                "Current" = 0
                "Unit" = "sessions"
                "Category" = "Productivity"
            }
            "Reading" = @{
                "Name" = "Read for 30 minutes"
                "Target" = 30
                "Current" = 0
                "Unit" = "minutes"
                "Category" = "Learning"
            }
            "Sleep" = @{
                "Name" = "Get 8 hours of sleep"
                "Target" = 8
                "Current" = 0
                "Unit" = "hours"
                "Category" = "Health"
            }
            "Kindness" = @{
                "Name" = "Complete 1 act of kindness"
                "Target" = 1
                "Current" = 0
                "Unit" = "acts"
                "Category" = "Personal"
            }
            "Exercise" = @{
                "Name" = "Exercise for 30 minutes"
                "Target" = 30
                "Current" = 0
                "Unit" = "minutes"
                "Category" = "Health"
            }
            "Meditation" = @{
                "Name" = "Meditate for 10 minutes"
                "Target" = 10
                "Current" = 0
                "Unit" = "minutes"
                "Category" = "Wellness"
            }
        }
        
        foreach ($key in $defaultGoals.Keys) {
            if (-not $this.Goals.ContainsKey($key)) {
                $this.Goals[$key] = $defaultGoals[$key]
            }
        }
    }
    
    [void] LoadData() {
        $dataFile = "goose_dailygoals.json"
        
        if (Test-Path $dataFile) {
            try {
                $data = Get-Content $dataFile -Raw | ConvertFrom-Json
                
                if ($data.Goals) {
                    foreach ($goal in $data.Goals.PSObject.Properties) {
                        $this.Goals[$goal.Name] = $goal.Value
                    }
                }
                
                if ($data.DayStart) {
                    $savedDay = [datetime]::Parse($data.DayStart)
                    if ($savedDay.Date -ne (Get-Date).Date) {
                        $this.ResetDailyProgress()
                    } else {
                        $this.DailyProgress = @{}
                        if ($data.DailyProgress) {
                            $data.DailyProgress.PSObject.Properties | ForEach-Object {
                                $this.DailyProgress[$_.Name] = $_.Value
                            }
                        }
                    }
                }
            } catch {}
        }
    }
    
    [void] SaveData() {
        $data = @{
            "Goals" = $this.Goals
            "DailyProgress" = $this.DailyProgress
            "DayStart" = $this.DayStart.ToString("o")
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content "goose_dailygoals.json"
    }
    
    [void] ResetDailyProgress() {
        $this.DayStart = Get-Date
        
        foreach ($goal in $this.Goals.Values) {
            $goal.Current = 0
        }
        
        $this.DailyProgress = @{}
        $this.SaveData()
    }
    
    [bool] UpdateProgress([string]$goalKey, [int]$amount) {
        if ($this.Goals.ContainsKey($goalKey)) {
            $goal = $this.Goals[$goalKey]
            $goal.Current = [Math]::Max(0, $goal.Current + $amount)
            $this.DailyProgress[$goalKey] = $goal.Current
            $this.SaveData()
            return $true
        }
        
        return $false
    }
    
    [bool] SetProgress([string]$goalKey, [int]$value) {
        if ($this.Goals.ContainsKey($goalKey)) {
            $goal = $this.Goals[$goalKey]
            $goal.Current = [Math]::Max(0, [Math]::Min($value, $goal.Target * 2))
            $this.DailyProgress[$goalKey] = $goal.Current
            $this.SaveData()
            return $true
        }
        
        return $false
    }
    
    [bool] CompleteGoal([string]$goalKey) {
        if ($this.Goals.ContainsKey($goalKey)) {
            $goal = $this.Goals[$goalKey]
            $goal.Current = $goal.Target
            $this.DailyProgress[$goalKey] = $goal.Current
            $this.SaveData()
            return $true
        }
        
        return $false
    }
    
    [void] AddCustomGoal([string]$key, [string]$name, [int]$target, [string]$unit, [string]$category = "Personal") {
        $this.Goals[$key] = @{
            "Name" = $name
            "Target" = $target
            "Current" = 0
            "Unit" = $unit
            "Category" = $category
        }
        $this.SaveData()
    }
    
    [bool] RemoveGoal([string]$key) {
        if ($this.Goals.ContainsKey($key)) {
            $this.Goals.Remove($key)
            $this.SaveData()
            return $true
        }
        
        return $false
    }
    
    [hashtable[]] GetAllGoals() {
        $goalsList = @()
        
        foreach ($goal in $this.Goals.Values) {
            $progress = if ($goal.Target -gt 0) { [Math]::Round(($goal.Current / $goal.Target) * 100) } else { 0 }
            
            $goalsList += @{
                "Key" = $goal
                "Name" = $goal.Name
                "Target" = $goal.Target
                "Current" = $goal.Current
                "Unit" = $goal.Unit
                "Category" = $goal.Category
                "Progress" = $progress
                "IsComplete" = $goal.Current -ge $goal.Target
            }
        }
        
        return $goalsList
    }
    
    [hashtable[]] GetIncompleteGoals() {
        return $this.GetAllGoals() | Where-Object { -not $_.IsComplete }
    }
    
    [hashtable[]] GetCompleteGoals() {
        return $this.GetAllGoals() | Where-Object { $_.IsComplete }
    }
    
    [hashtable] GetTodayProgress() {
        $allGoals = $this.GetAllGoals()
        $completed = ($allGoals | Where-Object { $_.IsComplete }).Count
        $total = $allGoals.Count
        
        $overallProgress = if ($total -gt 0) { [Math]::Round(($completed / $total) * 100) } else { 0 }
        
        return @{
            "Date" = (Get-Date).ToString("yyyy-MM-dd")
            "TotalGoals" = $total
            "CompletedGoals" = $completed
            "IncompleteGoals" = $total - $completed
            "OverallProgress" = $overallProgress
            "Goals" = $allGoals
        }
    }
    
    [string] GetMotivationalMessage() {
        $progress = $this.GetTodayProgress()
        
        if ($progress.CompletedGoals -eq 0) {
            return "Let's make today count! Start working on your goals!"
        } elseif ($progress.CompleteGoals -eq $progress.TotalGoals) {
            return "Amazing! You've completed all your daily goals!"
        } elseif ($progress.OverallProgress -ge 75) {
            return "Almost there! Keep pushing!"
        } elseif ($progress.OverallProgress -ge 50) {
            return "Halfway done! You're doing great!"
        } elseif ($progress.OverallProgress -ge 25) {
            return "Good start! Keep the momentum going!"
        } else {
            return "You've got this! Every step counts!"
        }
    }
    
    [hashtable] GetGoalsByCategory([string]$category) {
        return $this.GetAllGoals() | Where-Object { $_.Category -eq $category }
    }
    
    [string[]] GetCategories() {
        $categories = @()
        
        foreach ($goal in $this.Goals.Values) {
            if ($categories -notcontains $goal.Category) {
                $categories += $goal.Category
            }
        }
        
        return $categories
    }
    
    [hashtable] GetDailyGoalsState() {
        return @{
            "Enabled" = $this.Config["DailyGoalsEnabled"]
            "TodayProgress" = $this.GetTodayProgress()
            "IncompleteGoals" = $this.GetIncompleteGoals()
            "CompleteGoals" = $this.GetCompleteGoals()
            "Categories" = $this.GetCategories()
            "MotivationalMessage" = $this.GetMotivationalMessage()
        }
    }
}

$gooseDailyGoals = [GooseDailyGoals]::new()

function Get-GooseDailyGoals {
    return $gooseDailyGoals
}

function Update-GoalProgress {
    param(
        [Parameter(Mandatory=$true)]
        [string]$GoalKey,
        [int]$Amount,
        $Goals = $gooseDailyGoals
    )
    return $Goals.UpdateProgress($GoalKey, $Amount)
}

function Set-GoalProgress {
    param(
        [Parameter(Mandatory=$true)]
        [string]$GoalKey,
        [int]$Value,
        $Goals = $gooseDailyGoals
    )
    return $Goals.SetProgress($GoalKey, $Value)
}

function Complete-DailyGoal {
    param(
        [Parameter(Mandatory=$true)]
        [string]$GoalKey,
        $Goals = $gooseDailyGoals
    )
    return $Goals.CompleteGoal($GoalKey)
}

function Get-DailyGoalsStatus {
    param($Goals = $gooseDailyGoals)
    return $Goals.GetDailyGoalsState()
}

Write-Host "Desktop Goose Daily Goals System Initialized"
$state = Get-DailyGoalsStatus
Write-Host "Daily Goals Enabled: $($state['Enabled'])"
Write-Host "Today: $($state['TodayProgress']['CompletedGoals'])/$($state['TodayProgress']['TotalGoals']) goals completed"
