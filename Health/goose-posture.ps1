# Desktop Goose Posture Check System
# Remind users to maintain good posture

$LoggingScriptPath = Join-Path $PSScriptRoot "..\Core\GooseLogging.ps1"
if (Test-Path $LoggingScriptPath) {
    . $LoggingScriptPath
}

class GoosePosture {
    [hashtable]$Config
    [bool]$IsEnabled
    [bool]$IsRunning
    [datetime]$SessionStart
    [datetime]$LastCheck
    [datetime]$NextCheck
    [int]$CheckIntervalMinutes
    [bool]$IsCheckActive
    [int]$TodayChecks
    [int]$GoodPostureCount
    [int]$PoorPostureCount
    [int]$StreakDays
    [int]$StandBreaks
    [bool]$CameraBasedDetection
    [datetime]$LastActiveDate
    
    GoosePosture() {
        $this.Config = $this.LoadConfig()
        $this.IsEnabled = $false
        $this.IsRunning = $false
        $this.SessionStart = Get-Date
        $this.LastCheck = Get-Date
        $this.NextCheck = Get-Date
        $this.CheckIntervalMinutes = 30
        $this.IsCheckActive = $false
        $this.TodayChecks = 0
        $this.GoodPostureCount = 0
        $this.PoorPostureCount = 0
        $this.StreakDays = 0
        $this.StandBreaks = 0
        $this.CameraBasedDetection = $false
        $this.LastActiveDate = Get-Date
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
                    } else {
                        $this.Config[$key] = $value
                    }
                }
            }
        }
        
        if (-not $this.Config.ContainsKey("PostureEnabled")) {
            $this.Config["PostureEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("PostureCheckIntervalMinutes")) {
            $this.Config["PostureCheckIntervalMinutes"] = 30
        }
        if (-not $this.Config.ContainsKey("PostureCameraDetection")) {
            $this.Config["PostureCameraDetection"] = $false
        }
        if (-not $this.Config.ContainsKey("PostureStandReminder")) {
            $this.Config["PostureStandReminder"] = $true
        }
        if (-not $this.Config.ContainsKey("PostureStandIntervalMinutes")) {
            $this.Config["PostureStandIntervalMinutes"] = 60
        }
        
        $this.CheckIntervalMinutes = $this.Config["PostureCheckIntervalMinutes"]
        $this.CameraBasedDetection = $this.Config["PostureCameraDetection"]
        
        return $this.Config
    }
    
    [void] LoadData() {
        $dataFile = "goose_posture.json"
        
        if (Test-Path $dataFile) {
            try {
                $data = Get-Content $dataFile -Raw | ConvertFrom-Json
                
                if ($data.stats) {
                    $this.TodayChecks = $data.stats.todayChecks
                    $this.GoodPostureCount = $data.stats.goodPostureCount
                    $this.PoorPostureCount = $data.stats.poorPostureCount
                    $this.StreakDays = $data.stats.streak
                    $this.StandBreaks = $data.stats.standBreaks
                }
                
                if ($data.lastCheck) {
                    $this.LastCheck = [datetime]::Parse($data.lastCheck)
                }
                
                if ($data.lastActiveDate) {
                    $lastDate = [datetime]::Parse($data.lastActiveDate)
                    $today = (Get-Date).Date
                    
                    if ($lastDate.Date -eq $today.AddDays(-1)) {
                        $this.StreakDays = $data.stats.streak
                    } elseif ($lastDate.Date -lt $today.AddDays(-1)) {
                        $this.StreakDays = 0
                        $this.TodayChecks = 0
                        $this.GoodPostureCount = 0
                        $this.PoorPostureCount = 0
                        $this.StandBreaks = 0
                    }
                }
            } catch {}
        }
        
        $this.IsEnabled = $this.Config["PostureEnabled"]
        $this.NextCheck = $this.LastCheck.AddMinutes($this.CheckIntervalMinutes)
    }
    
    [void] SaveData() {
        $data = @{
            "stats" = @{
                "todayChecks" = $this.TodayChecks
                "goodPostureCount" = $this.GoodPostureCount
                "poorPostureCount" = $this.PoorPostureCount
                "streak" = $this.StreakDays
                "standBreaks" = $this.StandBreaks
            }
            "lastCheck" = $this.LastCheck.ToString("o")
            "lastActiveDate" = (Get-Date).ToString("o")
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content "goose_posture.json"
    }
    
    [void] StartTimer() {
        $this.IsRunning = $true
        $this.SessionStart = Get-Date
        $this.LastCheck = Get-Date
        $this.NextCheck = $this.LastCheck.AddMinutes($this.CheckIntervalMinutes)
        $this.IsCheckActive = $false
    }
    
    [void] StopTimer() {
        $this.IsRunning = $false
    }
    
    [bool] ShouldCheck() {
        if (-not $this.IsRunning -or $this.IsCheckActive) {
            return $false
        }
        
        $now = Get-Date
        return $now -ge $this.NextCheck
    }
    
    [hashtable] TriggerCheck() {
        $this.IsCheckActive = $true
        
        $exercises = $this.GetPostureExercises()
        $randomExercise = $exercises | Get-Random
        
        return @{
            "active" = $true
            "exercise" = $randomExercise
            "message" = "Time for a posture check!"
            "timestamp" = (Get-Date).ToString("o")
        }
    }
    
    [hashtable] RecordPosture([string]$posture) {
        $this.TodayChecks++
        
        if ($posture -eq "good") {
            $this.GoodPostureCount++
            $message = "Great posture! Keep it up!"
            
            if ($this.TodayChecks -ge 3 -and $this.GoodPostureCount -ge $this.TodayChecks / 2) {
                $this.StreakDays++
            }
        } else {
            $this.PoorPostureCount++
            $message = "Try to improve your posture. Sit up straight!"
            $this.StreakDays = 0
        }
        
        $this.LastCheck = Get-Date
        $this.NextCheck = $this.LastCheck.AddMinutes($this.CheckIntervalMinutes)
        $this.IsCheckActive = $false
        $this.SaveData()
        
        return @{
            "success" = $true
            "posture" = $posture
            "message" = $message
            "todayChecks" = $this.TodayChecks
            "goodPostureCount" = $this.GoodPostureCount
            "poorPostureCount" = $this.PoorPostureCount
            "streakDays" = $this.StreakDays
        }
    }
    
    [hashtable] SkipCheck() {
        $this.LastCheck = Get-Date
        $this.NextCheck = $this.LastCheck.AddMinutes($this.CheckIntervalMinutes)
        $this.IsCheckActive = $false
        $this.SaveData()
        
        return @{
            "success" = $true
            "message" = "Check skipped"
            "nextCheck" = $this.NextCheck
        }
    }
    
    [hashtable] RecordStandBreak() {
        $this.StandBreaks++
        $this.SaveData()
        
        return @{
            "success" = $true
            "standBreaks" = $this.StandBreaks
            "message" = "Great job taking a stand break!"
        }
    }
    
    [hashtable[]] GetPostureExercises() {
        return @(
            @{
                "name" = "Shoulder Rolls"
                "description" = "Roll your shoulders forward 5 times, then backward 5 times"
                "duration" = 20
            },
            @{
                "name" = "Neck Stretch"
                "description" = "Tilt your head to the right, hold 15 seconds, then left"
                "duration" = 30
            },
            @{
                "name" = "Chin Tucks"
                "description" = "Pull your chin back as if making a double chin, hold 5 seconds"
                "duration" = 15
            },
            @{
                "name" = "Chest Opener"
                "description" = "Clasp hands behind back and lift chest"
                "duration" = 20
            },
            @{
                "name" = "Spinal Twist"
                "description" = "Sit up straight, twist to the right, hold 15 seconds, then left"
                "duration" = 30
            },
            @{
                "name" = "Wall Angels"
                "description" = "Stand against wall, raise arms like snow angel"
                "duration" = 30
            },
            @{
                "name" = "Cat-Cow Stretch"
                "description" = "On chair, arch back, then round spine alternately"
                "duration" = 30
            }
        )
    }
    
    [hashtable] GetRandomExercise() {
        $exercises = $this.GetPostureExercises()
        return $exercises | Get-Random
    }
    
    [hashtable] GetCountdown() {
        $now = Get-Date
        
        if ($this.IsCheckActive) {
            return @{
                "Phase" = "check"
                "Active" = $true
                "Exercise" = $this.GetRandomExercise()
                "Message" = "Posture check time!"
            }
        }
        
        $timeUntilCheck = $this.NextCheck - $now
        if ($timeUntilCheck.TotalSeconds -lt 0) {
            $timeUntilCheck = [TimeSpan]::Zero
        }
        
        return @{
            "Phase" = "work"
            "Active" = $false
            "TimeRemaining" = $timeUntilCheck
            "TimeRemainingFormatted" = "{0:D2}:{1:D2}" -f [int]$timeUntilCheck.TotalMinutes, $timeUntilCheck.Seconds
            "Interval" = $this.CheckIntervalMinutes
            "Message" = "Next posture check"
        }
    }
    
    [void] SetCheckInterval([int]$minutes) {
        $this.CheckIntervalMinutes = $minutes
        $this.Config["PostureCheckIntervalMinutes"] = $minutes
        $this.NextCheck = $this.LastCheck.AddMinutes($minutes)
    }
    
    [void] SetCameraDetection([bool]$enabled) {
        $this.CameraBasedDetection = $enabled
        $this.Config["PostureCameraDetection"] = $enabled
    }
    
    [hashtable] GetDailyScore() {
        if ($this.TodayChecks -eq 0) {
            return @{
                "score" = 0
                "grade" = "N/A"
                "message" = "No checks recorded today"
            }
        }
        
        $goodPercent = ($this.GoodPostureCount / $this.TodayChecks) * 100
        
        $grade = "F"
        $message = "Needs improvement"
        
        if ($goodPercent -ge 90) {
            $grade = "A"
            $message = "Excellent posture!"
        } elseif ($goodPercent -ge 80) {
            $grade = "B"
            $message = "Great posture!"
        } elseif ($goodPercent -ge 70) {
            $grade = "C"
            $message = "Good, but room for improvement"
        } elseif ($goodPercent -ge 60) {
            $grade = "D"
            $message = "Fair - try to sit up straighter"
        }
        
        return @{
            "score" = $goodPercent
            "grade" = $grade
            "message" = $message
        }
    }
    
    [void] ResetDailyStats() {
        $this.TodayChecks = 0
        $this.GoodPostureCount = 0
        $this.PoorPostureCount = 0
        $this.SaveData()
    }
    
    [hashtable] GetStats() {
        return @{
            "todayChecks" = $this.TodayChecks
            "goodPostureCount" = $this.GoodPostureCount
            "poorPostureCount" = $this.PoorPostureCount
            "goodPercent" = if ($this.TodayChecks -gt 0) { [Math]::Round(($this.GoodPostureCount / $this.TodayChecks) * 100) } else { 0 }
            "streakDays" = $this.StreakDays
            "standBreaks" = $this.StandBreaks
            "dailyScore" = $this.GetDailyScore()
        }
    }
    
    [void] SetEnabled([bool]$enabled) {
        $this.IsEnabled = $enabled
        $this.Config["PostureEnabled"] = $enabled
        
        if ($enabled -and -not $this.IsRunning) {
            $this.StartTimer()
        } elseif (-not $enabled -and $this.IsRunning) {
            $this.StopTimer()
        }
    }
    
    [void] Toggle() {
        $this.SetEnabled(-not $this.IsEnabled)
    }
    
    [hashtable] GetPostureState() {
        return @{
            "Enabled" = $this.IsEnabled
            "IsRunning" = $this.IsRunning
            "IsCheckActive" = $this.IsCheckActive
            "SessionStart" = $this.SessionStart
            "LastCheck" = $this.LastCheck
            "NextCheck" = $this.NextCheck
            "CheckIntervalMinutes" = $this.CheckIntervalMinutes
            "CameraBasedDetection" = $this.CameraBasedDetection
            "StandReminderEnabled" = $this.Config["PostureStandReminder"]
            "Countdown" = $this.GetCountdown()
            "Stats" = $this.GetStats()
            "ShouldCheck" = $this.ShouldCheck()
            "DailyScore" = $this.GetDailyScore()
        }
    }
    
    [string] GetWidgetHtml() {
        $state = $this.GetPostureState()
        $countdown = $state.Countdown
        $stats = $state.Stats
        $score = $state.DailyScore
        
        $phaseClass = if ($countdown.Phase -eq "check") { "check" } else { "work" }
        
        $html = "<div class='posture-widget $phaseClass'>"
        $html += "<div class='posture-header'>"
        $html += "<span>Posture Check</span>"
        if ($state.Enabled) {
            $buttonText = if ($state.IsRunning) { "Pause" } else { "Resume" }
            $html += "<button onclick='togglePosture()'>$buttonText</button>"
        }
        $html += "</div>"
        
        $html += "<div class='posture-score'>"
        $html += "<div class='score-grade'>$($score.grade)</div>"
        $html += "<div class='score-label'>$($score.message)</div>"
        $html += "</div>"
        
        $html += "<div class='posture-timer'>"
        if ($state.Enabled) {
            if ($state.IsCheckActive) {
                $exercise = $countdown.Exercise
                $html += "<div class='exercise-title'>Try this:</div>"
                $html += "<div class='exercise-name'>$($exercise.name)</div>"
                $html += "<div class='exercise-desc'>$($exercise.description)</div>"
                $html += "<div class='posture-buttons'>"
                $html += "<button class='good-btn' onclick='recordPosture(""good"")'>Good Posture</button>"
                $html += "<button class='poor-btn' onclick='recordPosture(""poor"")'>Needs Work</button>"
                $html += "<button onclick='skipPosture()'>Skip</button>"
                $html += "</div>"
            } else {
                $html += "<div class='timer-countdown'>$($countdown.TimeRemainingFormatted)</div>"
                $html += "<div class='timer-message'>$($countdown.Message)</div>"
                $html += "<button onclick='triggerPostureCheck()'>Check Now</button>"
            }
        } else {
            $html += "<div class='timer-disabled'>Disabled</div>"
            $html += "<button onclick='enablePosture()'>Enable</button>"
        }
        $html += "</div>"
        
        $html += "<div class='posture-stats'>"
        $html += "<div class='stat'>"
        $html += "<span class='stat-value'>$($stats.todayChecks)</span>"
        $html += "<span class='stat-label'>Checks</span>"
        $html += "</div>"
        $html += "<div class='stat'>"
        $html += "<span class='stat-value'>$($stats.goodPercent)%</span>"
        $html += "<span class='stat-label'>Good</span>"
        $html += "</div>"
        $html += "<div class='stat'>"
        $html += "<span class='stat-value'>$($stats.streakDays)</span>"
        $html += "<span class='stat-label'>Streak</span>"
        $html += "</div>"
        $html += "<div class='stat'>"
        $html += "<span class='stat-value'>$($stats.standBreaks)</span>"
        $html += "<span class='stat-label'>Stands</span>"
        $html += "</div>"
        $html += "</div>"
        
        $html += "</div>"
        
        return $html
    }
}

$goosePosture = [GoosePosture]::new()

function Get-GoosePosture {
    return $goosePosture
}

function Start-PostureTimer {
    param($Posture = $goosePosture)
    $Posture.StartTimer()
}

function Stop-PostureTimer {
    param($Posture = $goosePosture)
    $Posture.StopTimer()
}

function Trigger-PostureCheck {
    param($Posture = $goosePosture)
    return $Posture.TriggerCheck()
}

function Record-Posture {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Posture,
        $PostureSystem = $goosePosture
    )
    return $PostureSystem.RecordPosture($Posture)
}

function Skip-PostureCheck {
    param($Posture = $goosePosture)
    return $Posture.SkipCheck()
}

function Record-StandBreak {
    param($Posture = $goosePosture)
    return $Posture.RecordStandBreak()
}

function Get-PostureExercises {
    param($Posture = $goosePosture)
    return $Posture.GetPostureExercises()
}

function Get-RandomPostureExercise {
    param($Posture = $goosePosture)
    return $Posture.GetRandomExercise()
}

function Set-PostureInterval {
    param(
        [int]$Minutes,
        $Posture = $goosePosture
    )
    $Posture.SetCheckInterval($Minutes)
}

function Get-PostureDailyScore {
    param($Posture = $goosePosture)
    return $Posture.GetDailyScore()
}

function Get-PostureStats {
    param($Posture = $goosePosture)
    return $Posture.GetStats()
}

function Enable-Posture {
    param($Posture = $goosePosture)
    $Posture.SetEnabled($true)
}

function Disable-Posture {
    param($Posture = $goosePosture)
    $Posture.SetEnabled($false)
}

function Toggle-Posture {
    param($Posture = $goosePosture)
    $Posture.Toggle()
}

function Get-PostureState {
    param($Posture = $goosePosture)
    return $Posture.GetPostureState()
}

function Reset-PostureDailyStats {
    param($Posture = $goosePosture)
    $Posture.ResetDailyStats()
}

Write-Host "Desktop Goose Posture Check System Initialized"
Write-LogInfo "Desktop Goose Posture Check System Initialized"
$state = Get-PostureState
Write-Host "Posture Enabled: $($state['Enabled'])"
Write-LogInfo "Posture Enabled: $($state['Enabled'])"
Write-Host "Today's Checks: $($state['Stats']['todayChecks'])"
Write-LogInfo "Today's Checks: $($state['Stats']['todayChecks'])"
Write-Host "Streak: $($state['Stats']['streakDays']) days"
Write-LogInfo "Streak: $($state['Stats']['streakDays']) days"
