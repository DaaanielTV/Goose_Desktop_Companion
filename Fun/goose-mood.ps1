class GooseMood {
    [hashtable]$Config
    [string]$CurrentMood
    [int]$MoodScore
    [datetime]$LastMoodUpdate
    [hashtable]$MoodHistory
    [string[]]$MoodPrompts
    
    GooseMood() {
        $this.Config = $this.LoadConfig()
        $this.CurrentMood = "neutral"
        $this.MoodScore = 5
        $this.LastMoodUpdate = Get-Date
        $this.MoodHistory = @{}
        $this.MoodPrompts = @(
            "How are you feeling today?",
            "What's your mood right now?",
            "How's your day going?",
            "How do you feel?",
            "What's on your mind?"
        )
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
        
        if (-not $this.Config.ContainsKey("MoodTrackingEnabled")) {
            $this.Config["MoodTrackingEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("MoodReminderHours")) {
            $this.Config["MoodReminderHours"] = 4
        }
        
        return $this.Config
    }
    
    [void] SetMood([string]$mood, [int]$score = 5) {
        $validMoods = @("happy", "excited", "neutral", "sad", "anxious", "tired", "stressed", "calm", "frustrated", "grateful")
        
        if ($validMoods -contains $mood) {
            $this.CurrentMood = $mood
            $this.MoodScore = [Math]::Clamp($score, 1, 10)
            $this.LastMoodUpdate = Get-Date
            
            $this.SaveMoodEntry()
        }
    }
    
    [void] SaveMoodEntry() {
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        $entry = @{
            "Mood" = $this.CurrentMood
            "Score" = $this.MoodScore
            "Timestamp" = $this.LastMoodUpdate.ToString("o")
        }
        
        if (-not $this.MoodHistory.ContainsKey($dateKey)) {
            $this.MoodHistory[$dateKey] = @()
        }
        $this.MoodHistory[$dateKey] += $entry
    }
    
    [string] GetRandomPrompt() {
        return $this.MoodPrompts | Get-Random
    }
    
    [string] GetMoodEmoji() {
        switch ($this.CurrentMood) {
            "happy" { return "😊" }
            "excited" { return "🤩" }
            "neutral" { return "😐" }
            "sad" { return "😢" }
            "anxious" { return "😰" }
            "tired" { return "😴" }
            "stressed" { return "😫" }
            "calm" { return "😌" }
            "frustrated" { return "😤" }
            "grateful" { return "🙏" }
            default { return "🦆" }
        }
    }
    
    [string] GetMoodResponse() {
        switch ($this.CurrentMood) {
            "happy" { return "I'm glad you're happy! That's wonderful!" }
            "excited" { return "Your energy is contagious! Exciting!" }
            "neutral" { return "A balanced day is a good day." }
            "sad" { return "I'm here for you. Things will get better." }
            "anxious" { return "Take a deep breath. I'm here with you." }
            "tired" { return "Rest is important. Maybe take a break?" }
            "stressed" { return "One step at a time. You've got this!" }
            "calm" { return "Peace is a beautiful state. Enjoy it!" }
            "frustrated" { return "Frustration is temporary. Keep going!" }
            "grateful" { return "Gratitude brings more good things!" }
            default { return "I'm here for you, friend!" }
        }
    }
    
    [hashtable] GetTodayMood() {
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        $todayEntries = @()
        
        if ($this.MoodHistory.ContainsKey($dateKey)) {
            $todayEntries = $this.MoodHistory[$dateKey]
        }
        
        $avgScore = 0
        if ($todayEntries.Count -gt 0) {
            $avgScore = ($todayEntries | ForEach-Object { $_.Score } | Measure-Object -Average).Average
        }
        
        return @{
            "CurrentMood" = $this.CurrentMood
            "MoodScore" = $this.MoodScore
            "MoodEmoji" = $this.GetMoodEmoji()
            "Response" = $this.GetMoodResponse()
            "LastUpdate" = $this.LastMoodUpdate
            "TodayEntries" = $todayEntries.Count
            "AverageScore" = [Math]::Round($avgScore, 1)
        }
    }
    
    [hashtable] GetWeeklyMoodStats() {
        $weekStats = @{}
        
        for ($i = 6; $i -ge 0; $i--) {
            $date = (Get-Date).AddDays(-$i)
            $dateKey = $date.ToString("yyyy-MM-dd")
            
            if ($this.MoodHistory.ContainsKey($dateKey)) {
                $entries = $this.MoodHistory[$dateKey]
                $avgScore = ($entries | ForEach-Object { $_.Score } | Measure-Object -Average).Average
                $weekStats[$dateKey] = @{
                    "AverageScore" = [Math]::Round($avgScore, 1)
                    "EntryCount" = $entries.Count
                    "PrimaryMood" = $entries[-1].Mood
                }
            }
        }
        
        return $weekStats
    }
    
    [void] IncrementMood([int]$amount = 1) {
        $this.MoodScore = [Math]::Clamp($this.MoodScore + $amount, 1, 10)
    }
    
    [void] DecrementMood([int]$amount = 1) {
        $this.MoodScore = [Math]::Clamp($this.MoodScore - $amount, 1, 10)
    }
    
    [bool] ShouldPromptMood() {
        $hoursSinceUpdate = ((Get-Date) - $this.LastMoodUpdate).TotalHours
        return $hoursSinceUpdate -ge $this.Config["MoodReminderHours"]
    }
    
    [hashtable] GetMoodState() {
        return @{
            "Enabled" = $this.Config["MoodTrackingEnabled"]
            "CurrentMood" = $this.GetTodayMood()
            "WeeklyStats" = $this.GetWeeklyMoodStats()
            "Prompt" = $this.GetRandomPrompt()
            "ShouldPrompt" = $this.ShouldPromptMood()
        }
    }
}

$gooseMood = [GooseMood]::new()

function Get-GooseMood {
    return $gooseMood
}

function Set-Mood {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Mood,
        [int]$Score = 5,
        $MoodSystem = $gooseMood
    )
    $MoodSystem.SetMood($Mood, $Score)
    return $MoodSystem.GetTodayMood()
}

function Get-MoodStatus {
    param($MoodSystem = $gooseMood)
    return $MoodSystem.GetMoodState()
}

Write-Host "Desktop Goose Mood System Initialized"
$state = Get-MoodStatus
Write-Host "Mood Tracking: $($state['Enabled'])"
Write-Host "Current Mood: $($state['CurrentMood']['CurrentMood'])"
