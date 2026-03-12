class GooseKindness {
    [hashtable]$Config
    [hashtable]$CompletedActs
    [datetime]$LastActTime
    [int]$Streak
    [hashtable]$ActsOfKindness
    
    GooseKindness() {
        $this.Config = $this.LoadConfig()
        $this.CompletedActs = @{}
        $this.LastActTime = Get-Date
        $this.Streak = 0
        $this.InitActsOfKindness()
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
        
        if (-not $this.Config.ContainsKey("KindnessEnabled")) {
            $this.Config["KindnessEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] InitActsOfKindness() {
        $this.ActsOfKindness = @{
            "Send a thank you message" = @{
                "Category" = "Gratitude"
                "Difficulty" = "Easy"
                "Time" = "5 min"
            }
            "Compliment a stranger" = @{
                "Category" = "Social"
                "Difficulty" = "Medium"
                "Time" = "2 min"
            }
            "Hold the door for someone" = @{
                "Category" = "Social"
                "Difficulty" = "Easy"
                "Time" = "1 min"
            }
            "Donate to a charity" = @{
                "Category" = "Giving"
                "Difficulty" = "Medium"
                "Time" = "10 min"
            }
            "Write a positive review" = @{
                "Category" = "Gratitude"
                "Difficulty" = "Easy"
                "Time" = "5 min"
            }
            "Call a friend you haven't talked to" = @{
                "Category" = "Social"
                "Difficulty" = "Medium"
                "Time" = "30 min"
            }
            "Help someone with their groceries" = @{
                "Category" = "Social"
                "Difficulty" = "Easy"
                "Time" = "10 min"
            }
            "Leave a kind note for someone" = @{
                "Category" = "Gratitude"
                "Difficulty" = "Easy"
                "Time" = "5 min"
            }
            "Share your umbrella" = @{
                "Category" = "Social"
                "Difficulty" = "Easy"
                "Time" = "5 min"
            }
            "Give a genuine compliment" = @{
                "Category" = "Social"
                "Difficulty" = "Easy"
                "Time" = "1 min"
            }
            "Let someone go ahead of you in line" = @{
                "Category" = "Social"
                "Difficulty" = "Easy"
                "Time" = "1 min"
            }
            "Write a letter to your past self" = @{
                "Category" = "Self"
                "Difficulty" = "Medium"
                "Time" = "20 min"
            }
            "Forgive someone (including yourself)" = @{
                "Category" = "Self"
                "Difficulty" = "Hard"
                "Time" = " varies"
            }
            "Leave a positive sticky note" = @{
                "Category" = "Gratitude"
                "Difficulty" = "Easy"
                "Time" = "2 min"
            }
            "Smile at 5 people today" = @{
                "Category" = "Social"
                "Difficulty" = "Easy"
                "Time" = "5 min"
            }
            "Tell someone you appreciate them" = @{
                "Category" = "Gratitude"
                "Difficulty" = "Easy"
                "Time" = "2 min"
            }
            "Cook a meal for someone" = @{
                "Category" = "Giving"
                "Difficulty" = "Hard"
                "Time" = "60 min"
            }
            "Listen without interrupting" = @{
                "Category" = "Social"
                "Difficulty" = "Medium"
                "Time" = "15 min"
            }
            "Offer to help with a chore" = @{
                "Category" = "Social"
                "Difficulty" = "Easy"
                "Time" = "15 min"
            }
            "Leave a generous tip" = @{
                "Category" = "Giving"
                "Difficulty" = "Medium"
                "Time" = "1 min"
            }
            "Plant something and watch it grow" = @{
                "Category" = "Self"
                "Difficulty" = "Easy"
                "Time" = "15 min"
            }
            "Meditate on gratitude" = @{
                "Category" = "Self"
                "Difficulty" = "Easy"
                "Time" = "10 min"
            }
            "Share your lunch" = @{
                "Category" = "Giving"
                "Difficulty" = "Medium"
                "Time" = "10 min"
            }
            "Check on an elderly neighbor" = @{
                "Category" = "Social"
                "Difficulty" = "Medium"
                "Time" = "30 min"
            }
            "Pick up litter in your area" = @{
                "Category" = "Community"
                "Difficulty" = "Easy"
                "Time" = "20 min"
            }
        }
    }
    
    [void] LoadData() {
        $dataFile = "goose_kindness.json"
        
        if (Test-Path $dataFile) {
            try {
                $data = Get-Content $dataFile -Raw | ConvertFrom-Json
                $this.CompletedActs = @{}
                
                if ($data.CompletedActs) {
                    $data.CompletedActs.PSObject.Properties | ForEach-Object {
                        $this.CompletedActs[$_.Name] = $_.Value
                    }
                }
                
                if ($data.Streak) {
                    $this.Streak = $data.Streak
                }
                
                $this.CheckStreak()
            } catch {}
        }
    }
    
    [void] SaveData() {
        $data = @{
            "CompletedActs" = $this.CompletedActs
            "Streak" = $this.Streak
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content "goose_kindness.json"
    }
    
    [void] CheckStreak() {
        $lastDate = $null
        $dates = $this.CompletedActs.Keys | Sort-Object
        
        if ($dates.Count -gt 0) {
            $lastDate = [datetime]::Parse($dates[-1])
            $daysSince = ((Get-Date) - $lastDate).Days
            
            if ($daysSince -gt 1) {
                $this.Streak = 0
            }
        }
    }
    
    [hashtable] GetRandomAct() {
        $acts = @($this.ActsOfKindness.Keys)
        $randomAct = $acts | Get-Random
        
        return @{
            "Name" = $randomAct
            "Category" = $this.ActsOfKindness[$randomAct].Category
            "Difficulty" = $this.ActsOfKindness[$randomAct].Difficulty
            "EstimatedTime" = $this.ActsOfKindness[$randomAct].Time
        }
    }
    
    [hashtable[]] GetActsByCategory([string]$category) {
        $filtered = @()
        
        foreach ($act in $this.ActsOfKindness.GetEnumerator()) {
            if ($act.Value.Category -eq $category) {
                $filtered += @{
                    "Name" = $act.Key
                    "Category" = $act.Value.Category
                    "Difficulty" = $act.Value.Difficulty
                    "EstimatedTime" = $act.Value.Time
                }
            }
        }
        
        return $filtered
    }
    
    [bool] CompleteAct([string]$actName) {
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        
        if (-not $this.CompletedActs.ContainsKey($dateKey)) {
            $this.CompletedActs[$dateKey] = @()
        }
        
        $this.CompletedActs[$dateKey] += @{
            "Act" = $actName
            "CompletedAt" = (Get-Date).ToString("o")
        }
        
        $this.LastActTime = Get-Date
        $this.Streak++
        $this.SaveData()
        
        return $true
    }
    
    [int] GetTodayCompletedCount() {
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        
        if ($this.CompletedActs.ContainsKey($dateKey)) {
            return $this.CompletedActs[$dateKey].Count
        }
        
        return 0
    }
    
    [int] GetTotalCompletedCount() {
        $total = 0
        
        foreach ($date in $this.CompletedActs.Keys) {
            $total += $this.CompletedActs[$date].Count
        }
        
        return $total
    }
    
    [hashtable] GetWeeklyProgress() {
        $weekProgress = @{}
        
        for ($i = 6; $i -ge 0; $i--) {
            $date = (Get-Date).AddDays(-$i)
            $dateKey = $date.ToString("yyyy-MM-dd")
            
            if ($this.CompletedActs.ContainsKey($dateKey)) {
                $weekProgress[$dateKey] = $this.CompletedActs[$dateKey].Count
            } else {
                $weekProgress[$dateKey] = 0
            }
        }
        
        return $weekProgress
    }
    
    [hashtable] GetStats() {
        return @{
            "Streak" = $this.Streak
            "TodayCompleted" = $this.GetTodayCompletedCount()
            "TotalCompleted" = $this.GetTotalCompletedCount()
            "WeeklyProgress" = $this.GetWeeklyProgress()
        }
    }
    
    [string[]] GetCategories() {
        $categories = @()
        
        foreach ($act in $this.ActsOfKindness.Values) {
            if ($categories -notcontains $act.Category) {
                $categories += $act.Category
            }
        }
        
        return $categories
    }
    
    [hashtable] GetKindnessState() {
        return @{
            "Enabled" = $this.Config["KindnessEnabled"]
            "RandomAct" = $this.GetRandomAct()
            "Categories" = $this.GetCategories()
            "Stats" = $this.GetStats()
            "TodayMessage" = if ($this.GetTodayCompletedCount() -gt 0) { "Great job spreading kindness today!" } else { "Ready for today's act of kindness?" }
        }
    }
}

$gooseKindness = [GooseKindness]::new()

function Get-GooseKindness {
    return $gooseKindness
}

function Get-RandomActOfKindness {
    param($Kindness = $gooseKindness)
    return $Kindness.GetRandomAct()
}

function Complete-ActOfKindness {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ActName,
        $Kindness = $gooseKindness
    )
    return $Kindness.CompleteAct($ActName)
}

function Get-KindnessStatus {
    param($Kindness = $gooseKindness)
    return $Kindness.GetKindnessState()
}

Write-Host "Desktop Goose Kindness System Initialized"
$state = Get-KindnessStatus
Write-Host "Kindness Tracking: $($state['Enabled'])"
Write-Host "Current Streak: $($state['Stats']['Streak']) days"
