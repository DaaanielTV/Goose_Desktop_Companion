# Desktop Goose Eye Strain Prevention System
# 20-20-20 rule and break reminders for eye health

$LoggingScriptPath = Join-Path $PSScriptRoot "..\Core\GooseLogging.ps1"
if (Test-Path $LoggingScriptPath) {
    . $LoggingScriptPath
}

class GooseEyeStrain {
    [hashtable]$Config
    [bool]$IsEnabled
    [bool]$IsRunning
    [datetime]$SessionStart
    [datetime]$LastBreak
    [datetime]$NextBreak
    [int]$IntervalMinutes
    [int]$BreakDurationSeconds
    [bool]$IsBreakActive
    [int]$SnoozeCount
    [int]$TodayBreaks
    [int]$TotalRestSecondsToday
    [int]$StreakDays
    [datetime]$LastActiveDate
    
    GooseEyeStrain() {
        $this.Config = $this.LoadConfig()
        $this.IsEnabled = $false
        $this.IsRunning = $false
        $this.SessionStart = Get-Date
        $this.LastBreak = Get-Date
        $this.NextBreak = Get-Date
        $this.IntervalMinutes = 20
        $this.BreakDurationSeconds = 20
        $this.IsBreakActive = $false
        $this.SnoozeCount = 0
        $this.TodayBreaks = 0
        $this.TotalRestSecondsToday = 0
        $this.StreakDays = 0
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
        
        if (-not $this.Config.ContainsKey("EyeStrainEnabled")) {
            $this.Config["EyeStrainEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("EyeStrainIntervalMinutes")) {
            $this.Config["EyeStrainIntervalMinutes"] = 20
        }
        if (-not $this.Config.ContainsKey("EyeStrainBreakDurationSeconds")) {
            $this.Config["EyeStrainBreakDurationSeconds"] = 20
        }
        if (-not $this.Config.ContainsKey("EyeStrainShowCountdown")) {
            $this.Config["EyeStrainShowCountdown"] = $true
        }
        if (-not $this.Config.ContainsKey("EyeStrainSoundEnabled")) {
            $this.Config["EyeStrainSoundEnabled"] = $true
        }
        
        $this.IntervalMinutes = $this.Config["EyeStrainIntervalMinutes"]
        $this.BreakDurationSeconds = $this.Config["EyeStrainBreakDurationSeconds"]
        
        return $this.Config
    }
    
    [void] LoadData() {
        $dataFile = "goose_eyestrain.json"
        
        if (Test-Path $dataFile) {
            try {
                $data = Get-Content $dataFile -Raw | ConvertFrom-Json
                
                if ($data.stats) {
                    $this.TodayBreaks = $data.stats.todayBreaks
                    $this.TotalRestSecondsToday = $data.stats.totalRestSeconds
                    $this.StreakDays = $data.stats.streak
                }
                
                if ($data.lastBreak) {
                    $this.LastBreak = [datetime]::Parse($data.lastBreak)
                }
                
                if ($data.lastActiveDate) {
                    $lastDate = [datetime]::Parse($data.lastActiveDate)
                    $today = (Get-Date).Date
                    
                    if ($lastDate.Date -eq $today.AddDays(-1)) {
                        $this.StreakDays = $data.stats.streak
                    } elseif ($lastDate.Date -lt $today.AddDays(-1)) {
                        $this.StreakDays = 0
                        $this.TodayBreaks = 0
                        $this.TotalRestSecondsToday = 0
                    }
                }
            } catch {}
        }
        
        $this.IsEnabled = $this.Config["EyeStrainEnabled"]
        $this.NextBreak = $this.LastBreak.AddMinutes($this.IntervalMinutes)
    }
    
    [void] SaveData() {
        $data = @{
            "stats" = @{
                "todayBreaks" = $this.TodayBreaks
                "totalRestSeconds" = $this.TotalRestSecondsToday
                "streak" = $this.StreakDays
            }
            "lastBreak" = $this.LastBreak.ToString("o")
            "lastActiveDate" = (Get-Date).ToString("o")
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content "goose_eyestrain.json"
    }
    
    [void] StartTimer() {
        $this.IsRunning = $true
        $this.SessionStart = Get-Date
        $this.LastBreak = Get-Date
        $this.NextBreak = $this.LastBreak.AddMinutes($this.IntervalMinutes)
        $this.IsBreakActive = $false
        $this.SnoozeCount = 0
    }
    
    [void] StopTimer() {
        $this.IsRunning = $false
    }
    
    [void] PauseTimer() {
        $this.IsRunning = $false
    }
    
    [void] ResumeTimer() {
        if (-not $this.IsRunning) {
            $this.IsRunning = $true
        }
    }
    
    [bool] ShouldTakeBreak() {
        if (-not $this.IsRunning -or $this.IsBreakActive) {
            return $false
        }
        
        $now = Get-Date
        return $now -ge $this.NextBreak
    }
    
    [hashtable] TakeBreak([bool]$completed = $true) {
        $this.IsBreakActive = $true
        $breakEndTime = (Get-Date).AddSeconds($this.BreakDurationSeconds)
        
        if ($completed) {
            $this.TodayBreaks++
            $this.TotalRestSecondsToday += $this.BreakDurationSeconds
            
            if ($this.TodayBreaks -ge 3) {
                $this.StreakDays++
            }
            
            $this.LastBreak = Get-Date
            $this.NextBreak = $this.LastBreak.AddMinutes($this.IntervalMinutes)
            $this.SnoozeCount = 0
        }
        
        $this.SaveData()
        
        return @{
            "Success" = $true
            "BreakActive" = $this.IsBreakActive
            "BreakEndTime" = $breakEndTime
            "BreakDuration" = $this.BreakDurationSeconds
            "Message" = if ($completed) { "Break taken! Great job!" } else { "Break paused" }
        }
    }
    
    [hashtable] SnoozeBreak([int]$minutes = 5) {
        if ($this.SnoozeCount -ge 3) {
            return @{
                "Success" = $false
                "Message" = "Maximum snoozes reached. Take a break!"
            }
        }
        
        $this.SnoozeCount++
        $this.NextBreak = (Get-Date).AddMinutes($minutes)
        
        return @{
            "Success" = $true
            "SnoozeCount" = $this.SnoozeCount
            "NextBreak" = $this.NextBreak
            "Message" = "Break snoozed for $minutes minutes"
        }
    }
    
    [hashtable] EndBreak() {
        $this.IsBreakActive = $false
        
        return @{
            "Success" = $true
            "Message" = "Break ended"
        }
    }
    
    [void] SetInterval([int]$minutes) {
        $this.IntervalMinutes = $minutes
        $this.Config["EyeStrainIntervalMinutes"] = $minutes
        $this.NextBreak = $this.LastBreak.AddMinutes($minutes)
    }
    
    [void] SetBreakDuration([int]$seconds) {
        $this.BreakDurationSeconds = $seconds
        $this.Config["EyeStrainBreakDurationSeconds"] = $seconds
    }
    
    [hashtable] GetCountdown() {
        $now = Get-Date
        
        if ($this.IsBreakActive) {
            $timeRemaining = $this.NextBreak.AddSeconds($this.BreakDurationSeconds) - $now
            if ($timeRemaining.TotalSeconds -lt 0) {
                $timeRemaining = [TimeSpan]::Zero
            }
            
            return @{
                "Phase" = "break"
                "TimeRemaining" = $timeRemaining
                "TimeRemainingSeconds" = [int]$timeRemaining.TotalSeconds
                "TimeRemainingFormatted" = "{0:D2}:{1:D2}" -f [int]$timeRemaining.TotalMinutes, $timeRemaining.Seconds
                "BreakDuration" = $this.BreakDurationSeconds
                "Message" = "Look away from your screen!"
            }
        }
        
        $timeUntilBreak = $this.NextBreak - $now
        if ($timeUntilBreak.TotalSeconds -lt 0) {
            $timeUntilBreak = [TimeSpan]::Zero
        }
        
        return @{
            "Phase" = "work"
            "TimeRemaining" = $timeUntilBreak
            "TimeRemainingSeconds" = [int]$timeUntilBreak.TotalSeconds
            "TimeRemainingFormatted" = "{0:D2}:{1:D2}" -f [int]$timeUntilBreak.TotalMinutes, $timeUntilBreak.Seconds
            "Interval" = $this.IntervalMinutes
            "Message" = "Time until next break"
        }
    }
    
    [hashtable[]] GetStretches() {
        return @(
            @{
                "name" = "Eye Roll"
                "description" = "Slowly roll your eyes in a circle"
                "duration" = 10
            },
            @{
                "name" = "Palming"
                "description" = "Rub your palms together and cover your eyes"
                "duration" = 15
            },
            @{
                "name" = "Blinking"
                "description" = "Blink rapidly 20 times, then close for 10 seconds"
                "duration" = 20
            },
            @{
                "name" = "Focus Shift"
                "description" = "Look at something 20 feet away for 20 seconds"
                "duration" = 20
            },
            @{
                "name" = "Neck Stretch"
                "description" = "Slowly tilt your head side to side"
                "duration" = 15
            }
        )
    }
    
    [hashtable] GetRandomStretch() {
        $stretches = $this.GetStretches()
        return $stretches | Get-Random
    }
    
    [void] SetEnabled([bool]$enabled) {
        $this.IsEnabled = $enabled
        $this.Config["EyeStrainEnabled"] = $enabled
        
        if ($enabled -and -not $this.IsRunning) {
            $this.StartTimer()
        } elseif (-not $enabled -and $this.IsRunning) {
            $this.StopTimer()
        }
    }
    
    [void] Toggle() {
        $this.SetEnabled(-not $this.IsEnabled)
    }
    
    [hashtable] ResetDailyStats() {
        $this.TodayBreaks = 0
        $this.TotalRestSecondsToday = 0
        $this.SaveData()
        
        return @{
            "Success" = $true
            "Message" = "Daily stats reset"
        }
    }
    
    [hashtable] GetStats() {
        $today = Get-Date
        
        if ($this.LastActiveDate.Date -lt $today.Date) {
            $this.TodayBreaks = 0
            $this.TotalRestSecondsToday = 0
        }
        
        return @{
            "todayBreaks" = $this.TodayBreaks
            "totalRestSeconds" = $this.TotalRestSecondsToday
            "restMinutes" = [Math]::Floor($this.TotalRestSecondsToday / 60)
            "restSeconds" = $this.TotalRestSecondsToday % 60
            "streakDays" = $this.StreakDays
            "snoozeCount" = $this.SnoozeCount
            "snoozeLimit" = 3
        }
    }
    
    [hashtable] GetEyeStrainState() {
        return @{
            "Enabled" = $this.IsEnabled
            "IsRunning" = $this.IsRunning
            "IsBreakActive" = $this.IsBreakActive
            "SessionStart" = $this.SessionStart
            "LastBreak" = $this.LastBreak
            "NextBreak" = $this.NextBreak
            "IntervalMinutes" = $this.IntervalMinutes
            "BreakDurationSeconds" = $this.BreakDurationSeconds
            "ShowCountdown" = $this.Config["EyeStrainShowCountdown"]
            "SoundEnabled" = $this.Config["EyeStrainSoundEnabled"]
            "Countdown" = $this.GetCountdown()
            "Stats" = $this.GetStats()
            "ShouldTakeBreak" = $this.ShouldTakeBreak()
            "RandomStretch" = $this.GetRandomStretch()
        }
    }
    
    [string] GetWidgetHtml() {
        $state = $this.GetEyeStrainState()
        $countdown = $state.Countdown
        $stats = $state.Stats
        
        $phaseClass = if ($countdown.Phase -eq "break") { "break" } else { "work" }
        
        $html = "<div class='eyestrain-widget $phaseClass'>"
        $html += "<div class='eyestrain-header'>"
        $html += "<span>Eye Strain Prevention</span>"
        if ($state.Enabled) {
            $buttonText = if ($state.IsRunning) { "Pause" } else { "Resume" }
            $html += "<button onclick='toggleEyeStrain()'>$buttonText</button>"
        }
        $html += "</div>"
        
        $html += "<div class='eyestrain-timer'>"
        if ($state.Enabled) {
            $html += "<div class='timer-phase'>$($countdown.Phase.ToUpper())</div>"
            $html += "<div class='timer-countdown'>$($countdown.TimeRemainingFormatted)</div>"
            $html += "<div class='timer-message'>$($countdown.Message)</div>"
            
            if ($state.IsBreakActive) {
                $html += "<div class='break-exercises'>"
                $html += "<div class='exercise-title'>Try this:</div>"
                $html += "<div class='exercise-name'>$($state.RandomStretch.name)</div>"
                $html += "<div class='exercise-desc'>$($state.RandomStretch.description)</div>"
                $html += "<button onclick='endBreak()'>Done</button>"
                $html += "</div>"
            } else {
                $html += "<button class='snooze-btn' onclick='snoozeBreak()'>Snooze 5min</button>"
                $html += "<button class='break-btn' onclick='takeBreak()'>Take Break Now</button>"
            }
        } else {
            $html += "<div class='timer-disabled'>Disabled</div>"
            $html += "<button onclick='enableEyeStrain()'>Enable</button>"
        }
        $html += "</div>"
        
        $html += "<div class='eyestrain-stats'>"
        $html += "<div class='stat'>"
        $html += "<span class='stat-value'>$($stats.todayBreaks)</span>"
        $html += "<span class='stat-label'>Breaks Today</span>"
        $html += "</div>"
        $html += "<div class='stat'>"
        $html += "<span class='stat-value'>$($stats.restMinutes)m</span>"
        $html += "<span class='stat-label'>Rest Time</span>"
        $html += "</div>"
        $html += "<div class='stat'>"
        $html += "<span class='stat-value'>$($stats.streakDays)</span>"
        $html += "<span class='stat-label'>Day Streak</span>"
        $html += "</div>"
        $html += "</div>"
        
        $html += "</div>"
        
        return $html
    }
}

$gooseEyeStrain = [GooseEyeStrain]::new()

function Get-GooseEyeStrain {
    return $gooseEyeStrain
}

function Start-EyeStrainTimer {
    param($EyeStrain = $gooseEyeStrain)
    $EyeStrain.StartTimer()
}

function Stop-EyeStrainTimer {
    param($EyeStrain = $gooseEyeStrain)
    $EyeStrain.StopTimer()
}

function Pause-EyeStrainTimer {
    param($EyeStrain = $gooseEyeStrain)
    $EyeStrain.PauseTimer()
}

function Resume-EyeStrainTimer {
    param($EyeStrain = $gooseEyeStrain)
    $EyeStrain.ResumeTimer()
}

function Take-Break {
    param(
        [bool]$Completed = $true,
        $EyeStrain = $gooseEyeStrain
    )
    return $EyeStrain.TakeBreak($Completed)
}

function Snooze-Break {
    param(
        [int]$Minutes = 5,
        $EyeStrain = $gooseEyeStrain
    )
    return $EyeStrain.SnoozeBreak($Minutes)
}

function End-Break {
    param($EyeStrain = $gooseEyeStrain)
    return $EyeStrain.EndBreak()
}

function Get-EyeStrainCountdown {
    param($EyeStrain = $gooseEyeStrain)
    return $EyeStrain.GetCountdown()
}

function Get-EyeStrainStretches {
    param($EyeStrain = $gooseEyeStrain)
    return $EyeStrain.GetStretches()
}

function Set-EyeStrainInterval {
    param(
        [int]$Minutes,
        $EyeStrain = $gooseEyeStrain
    )
    $EyeStrain.SetInterval($Minutes)
}

function Set-EyeStrainBreakDuration {
    param(
        [int]$Seconds,
        $EyeStrain = $gooseEyeStrain
    )
    $EyeStrain.SetBreakDuration($Seconds)
}

function Get-EyeStrainStats {
    param($EyeStrain = $gooseEyeStrain)
    return $EyeStrain.GetStats()
}

function Enable-EyeStrain {
    param($EyeStrain = $gooseEyeStrain)
    $EyeStrain.SetEnabled($true)
}

function Disable-EyeStrain {
    param($EyeStrain = $gooseEyeStrain)
    $EyeStrain.SetEnabled($false)
}

function Toggle-EyeStrain {
    param($EyeStrain = $gooseEyeStrain)
    $EyeStrain.Toggle()
}

function Get-EyeStrainState {
    param($EyeStrain = $gooseEyeStrain)
    return $EyeStrain.GetEyeStrainState()
}

function Reset-EyeStrainDailyStats {
    param($EyeStrain = $gooseEyeStrain)
    return $EyeStrain.ResetDailyStats()
}

Write-Host "Desktop Goose Eye Strain Prevention System Initialized"
Write-LogInfo "Desktop Goose Eye Strain Prevention System Initialized"
$state = Get-EyeStrainState
Write-Host "Eye Strain Enabled: $($state['Enabled'])"
Write-LogInfo "Eye Strain Enabled: $($state['Enabled'])"
Write-Host "Breaks Today: $($state['Stats']['todayBreaks'])"
Write-LogInfo "Breaks Today: $($state['Stats']['todayBreaks'])"
Write-Host "Streak: $($state['Stats']['streakDays']) days"
Write-LogInfo "Streak: $($state['Stats']['streakDays']) days"
