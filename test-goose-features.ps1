# Desktop Goose Unit Tests
# Tests all new feature modules

$ErrorActionPreference = "Continue"
$testResults = @{
    "Passed" = 0
    "Failed" = 0
    "Tests" = @()
}

function Test-Function {
    param(
        [string]$Name,
        [scriptblock]$Test
    )
    
    $result = @{
        "Name" = $Name
        "Passed" = $false
        "Error" = $null
    }
    
    try {
        $Test.Invoke()
        $result["Passed"] = $true
        $testResults.Passed++
        Write-Host "[PASS] $Name" -ForegroundColor Green
    } catch {
        $result["Passed"] = $false
        $result["Error"] = $_.Exception.Message
        $testResults.Failed++
        Write-Host "[FAIL] $Name : $($result['Error'])" -ForegroundColor Red
    }
    
    $testResults.Tests += $result
}

function Assert-Equal {
    param($Expected, $Actual, $Message = "")
    if ($Expected -ne $Actual) {
        throw "Expected '$Expected' but got '$Actual'. $Message"
    }
}

function Assert-True {
    param($Value, $Message = "")
    if (-not $Value) {
        throw "Expected `$true but got `$false. $Message"
    }
}

function Assert-False {
    param($Value, $Message = "")
    if ($Value) {
        throw "Expected `$false but got `$true. $Message"
    }
}

function Assert-NotNull {
    param($Value, $Message = "")
    if ($null -eq $Value) {
        throw "Expected not null but got null. $Message"
    }
}

Write-Host "`n=== Desktop Goose Unit Tests ===`n" -ForegroundColor Cyan

Write-Host "--- Testing goose-weather.ps1 ---" -ForegroundColor Yellow
. "$PSScriptRoot\goose-weather.ps1"

Test-Function "Weather System - Initialization" {
    $weather = [GooseWeather]::new()
    Assert-NotNull $weather.Config
    Assert-NotNull $weather.CurrentWeather
}

Test-Function "Weather System - Get Weather State" {
    $state = Get-WeatherState
    Assert-NotNull $state
    Assert-NotNull $state.Enabled
    Assert-NotNull $state.Condition
    Assert-NotNull $state.Mood
}

Test-Function "Weather System - Get Weather Animation" {
    $weather = Get-GooseWeather
    $anim = $weather.GetWeatherAnimation()
    Assert-NotNull $anim
}

Test-Function "Weather System - Weather Greeting" {
    $weather = Get-GooseWeather
    $greeting = $weather.GetWeatherGreeting()
    Assert-NotNull $greeting
}

Test-Function "Weather System - Set Enabled" {
    $weather = Get-GooseWeather
    $weather.SetEnabled($false)
    Assert-False $weather.Config["WeatherIntegration"]
    $weather.SetEnabled($true)
    Assert-True $weather.Config["WeatherIntegration"]
}

Write-Host "`n--- Testing goose-quickactions.ps1 ---" -ForegroundColor Yellow
. "$PSScriptRoot\goose-quickactions.ps1"

Test-Function "QuickActions - Initialization" {
    $qa = [GooseQuickActions]::new()
    Assert-NotNull $qa.Config
    Assert-NotNull $qa.Actions
}

Test-Function "QuickActions - Get Available Actions" {
    $available = Get-AvailableActions
    Assert-True ($available.Count -gt 0)
}

Test-Function "QuickActions - Execute Action" {
    $qa = Get-GooseQuickActions
    $result = $qa.ExecuteAction("Pet")
    Assert-True $result.Success
}

Test-Function "QuickActions - Get Menu Structure" {
    $menu = Get-MenuStructure
    Assert-NotNull $menu
    Assert-NotNull $menu.items
    Assert-True ($menu.items.Count -gt 0)
}

Test-Function "QuickActions - Set Action Enabled" {
    $qa = Get-GooseQuickActions
    $qa.SetActionEnabled("Pet", $false)
    $result = $qa.ExecuteAction("Pet")
    Assert-False $result.Success
}

Write-Host "`n--- Testing goose-notes.ps1 ---" -ForegroundColor Yellow
. "$PSScriptRoot\goose-notes.ps1"

Test-Function "Notes - Initialization" {
    $notes = [GooseNotes]::new()
    Assert-NotNull $notes.Config
    Assert-NotNull $notes.Notes
}

Test-Function "Notes - Create Note" {
    $notes = Get-GooseNotes
    $result = $notes.CreateNote("Test note content", "yellow")
    Assert-True $result.Success
    Assert-NotNull $result.Note
    Assert-Equal "Test note content" $result.Note.Content
}

Test-Function "Notes - Get Notes" {
    $notesList = Get-GooseNotesList
    Assert-True ($notesList.Count -gt 0)
}

Test-Function "Notes - Delete Note" {
    $notes = Get-GooseNotes
    $createResult = $notes.CreateNote("To be deleted", "yellow")
    $noteId = $createResult.Note.Id
    $deleteResult = $notes.DeleteNote($noteId)
    Assert-True $deleteResult.Success
}

Test-Function "Notes - Toggle Pin" {
    $notes = Get-GooseNotes
    $createResult = $notes.CreateNote("Pinned note", "yellow")
    $noteId = $createResult.Note.Id
    $toggleResult = $notes.TogglePin($noteId)
    Assert-True $toggleResult.Success
    Assert-True $toggleResult.IsPinned
}

Test-Function "Notes - Create Reminder" {
    $notes = Get-GooseNotes
    $result = $notes.CreateReminder("Test reminder", 60)
    Assert-True $result.Success
    Assert-NotNull $result.Reminder
    Assert-True $result.Reminder.IsReminder
}

Write-Host "`n--- Testing goose-focus.ps1 ---" -ForegroundColor Yellow
. "$PSScriptRoot\goose-focus.ps1"

Test-Function "Focus - Initialization" {
    $focus = [GooseFocus]::new()
    Assert-NotNull $focus.Config
    Assert-False $focus.IsFocusActive
}

Test-Function "Focus - Start Focus" {
    $focus = Get-GooseFocus
    $result = $focus.StartFocus(10)
    Assert-True $result.Success
    Assert-True $focus.IsFocusActive
    $focus.EndFocus($true) | Out-Null
}

Test-Function "Focus - End Focus" {
    $focus = Get-GooseFocus
    $focus.StartFocus(5) | Out-Null
    $result = $focus.EndFocus($true)
    Assert-True $result.Success
    Assert-False $focus.IsFocusActive
}

Test-Function "Focus - Get Focus Status" {
    $status = Get-FocusStatus
    Assert-NotNull $status
    Assert-NotNull $status.IsActive
    Assert-NotNull $status.CyclesCompleted
}

Test-Function "Focus - Toggle Focus" {
    $focus = Get-GooseFocus
    $focus.StartFocus(5) | Out-Null
    $focus.ToggleFocus()
    Assert-False $focus.IsFocusActive
}

Test-Function "Focus - Set Focus Mode" {
    $focus = Get-GooseFocus
    $focus.SetFocusMode("DeepWork")
    Assert-Equal "DeepWork" $focus.CurrentFocusMode
}

Test-Function "Focus - Get Today Stats" {
    $focus = Get-GooseFocus
    $stats = $focus.GetTodayStats()
    Assert-NotNull $stats
    Assert-NotNull $stats.TotalFocusMinutes
}

Write-Host "`n--- Testing goose-pet.ps1 ---" -ForegroundColor Yellow
. "$PSScriptRoot\goose-pet.ps1"

Test-Function "Pet - Initialization" {
    $pet = [GoosePet]::new()
    Assert-NotNull $pet.Config
    Assert-Equal 50 $pet.TrustLevel
    Assert-Equal 50 $pet.HappinessLevel
}

Test-Function "Pet - Start Petting" {
    $pet = Get-GoosePet
    $pet.StartPetting()
    Assert-True $pet.IsBeingPet
}

Test-Function "Pet - Continue Petting" {
    $pet = Get-GoosePet
    $pet.StartPetting()
    $result = $pet.ContinuePetting(2)
    Assert-True $result.Success
    Assert-True ($result.TrustLevel -ge 50)
}

Test-Function "Pet - Stop Petting" {
    $pet = Get-GoosePet
    $pet.StartPetting()
    $pet.ContinuePetting(3) | Out-Null
    $result = $pet.StopPetting()
    Assert-True $result.Success
    Assert-False $pet.IsBeingPet
}

Test-Function "Pet - Get Unlocked Animations" {
    $pet = Get-GoosePet
    $unlocked = $pet.GetUnlockedAnimations()
    Assert-NotNull $unlocked
}

Test-Function "Pet - Get Trust Rank" {
    $pet = Get-GoosePet
    $rank = $pet.GetTrustRank()
    Assert-NotNull $rank
}

Test-Function "Pet - Get Pet State" {
    $state = Get-PetStatus
    Assert-NotNull $state
    Assert-NotNull $state.TrustLevel
    Assert-NotNull $state.HappinessLevel
}

Write-Host "`n--- Testing goose-sysinfo.ps1 ---" -ForegroundColor Yellow
. "$PSScriptRoot\goose-sysinfo.ps1"

Test-Function "SysInfo - Initialization" {
    $sysinfo = [GooseSysInfo]::new()
    Assert-NotNull $sysinfo.Config
    Assert-NotNull $sysinfo.DisplaySettings
}

Test-Function "SysInfo - Get System Info" {
    $info = Get-SystemInfo
    Assert-NotNull $info
}

Test-Function "SysInfo - Toggle Visibility" {
    $sysinfo = Get-GooseSysInfo
    $initialState = $sysinfo.IsVisible
    $sysinfo.ToggleVisibility()
    Assert-True ($sysinfo.IsVisible -ne $initialState)
}

Test-Function "SysInfo - Get Quick Summary" {
    $summary = Get-QuickSystemSummary
    Assert-NotNull $summary
    Assert-NotNull $summary.CPU
    Assert-NotNull $summary.Memory
}

Test-Function "SysInfo - Get State" {
    $sysinfo = Get-GooseSysInfo
    $state = $sysinfo.GetSysInfoState()
    Assert-NotNull $state
    Assert-NotNull $state.Enabled
}

Write-Host "`n--- Testing goose-seasonal.ps1 ---" -ForegroundColor Yellow
. "$PSScriptRoot\goose-seasonal.ps1"

Test-Function "Seasonal - Initialization" {
    $seasonal = [GooseSeasonal]::new()
    Assert-NotNull $seasonal.Config
    Assert-NotNull $seasonal.CurrentTheme
}

Test-Function "Seasonal - Get Current Season" {
    $seasonal = Get-GooseSeasonal
    $season = $seasonal.GetCurrentSeason()
    $validSeasons = @("Spring", "Summer", "Fall", "Winter")
    Assert-True ($validSeasons -contains $season)
}

Test-Function "Seasonal - Get Current Holiday" {
    $seasonal = Get-GooseSeasonal
    $holiday = $seasonal.GetCurrentHoliday()
    Assert-NotNull $holiday
}

Test-Function "Seasonal - Get Theme State" {
    $state = Get-CurrentTheme
    Assert-NotNull $state
    Assert-NotNull $state.CurrentTheme
    Assert-NotNull $state.CurrentSeason
}

Test-Function "Seasonal - Set Theme" {
    $seasonal = Get-GooseSeasonal
    $seasonal.SetTheme("Summer")
    Assert-Equal "Summer" $seasonal.CurrentTheme.Name
}

Test-Function "Seasonal - Is Special Day" {
    $seasonal = Get-GooseSeasonal
    $isSpecial = $seasonal.IsSpecialDay()
    Assert-NotNull $isSpecial
}

Test-Function "Seasonal - Get Greeting" {
    $greeting = Get-SeasonalGreeting
    Assert-NotNull $greeting
}

Write-Host "`n--- Testing goose-baby.ps1 ---" -ForegroundColor Yellow
. "$PSScriptRoot\goose-baby.ps1"

Test-Function "Baby - Initialization" {
    $baby = [GooseBaby]::new()
    Assert-NotNull $baby.Config
    Assert-False $baby.IsBabyActive
}

Test-Function "Baby - Spawn Baby" {
    $baby = Get-GooseBaby
    $baby.SpawnBaby(100, 100)
    Assert-True $baby.IsBabyActive
    Assert-Equal 100 $baby.BabyState.Position.X
    Assert-Equal 100 $baby.BabyState.Position.Y
}

Test-Function "Baby - Update Position" {
    $baby = Get-GooseBaby
    $baby.SpawnBaby(100, 100)
    $baby.UpdatePosition(200, 150)
    Assert-Equal 250 $baby.BabyState.Position.X
}

Test-Function "Baby - Interact" {
    $baby = Get-GooseBaby
    $baby.SpawnBaby(100, 100)
    $baby.InteractWithBaby()
    Assert-True ($baby.BabyState.TrustLevel -gt 0)
}

Test-Function "Baby - Dismiss" {
    $baby = Get-GooseBaby
    $baby.SpawnBaby(100, 100)
    $baby.DismissBaby()
    Assert-False $baby.IsBabyActive
}

Test-Function "Baby - Get State" {
    $state = Get-BabyState
    Assert-NotNull $state
    Assert-NotNull $state.Enabled
    Assert-NotNull $state.IsActive
}

Test-Function "Baby - Get Greeting" {
    $baby = Get-GooseBaby
    $greeting = $baby.GetBabyGreeting()
    Assert-NotNull $greeting
}

Write-Host "`n--- Testing goose-pomodoro.ps1 ---" -ForegroundColor Yellow
. "$PSScriptRoot\goose-pomodoro.ps1"

Test-Function "Pomodoro - Initialization" {
    $pomodoro = [GoosePomodoro]::new()
    Assert-NotNull $pomodoro.Config
    Assert-False $pomodoro.IsActive
}

Test-Function "Pomodoro - Start Session" {
    $pomodoro = Get-GoosePomodoro
    $pomodoro.StartSession()
    Assert-True $pomodoro.IsActive
    Assert-False $pomodoro.IsBreak
}

Test-Function "Pomodoro - Get Status" {
    $status = Get-PomodoroStatus
    Assert-NotNull $status
    Assert-NotNull $status.RemainingMinutes
    Assert-NotNull $status.Progress
}

Test-Function "Pomodoro - Complete Session" {
    $pomodoro = Get-GoosePomodoro
    $pomodoro.StartSession()
    $pomodoro.CompleteSession()
    Assert-True ($pomodoro.CompletedSessions -gt 0)
}

Test-Function "Pomodoro - Get Goose Action" {
    $pomodoro = Get-GoosePomodoro
    $action = $pomodoro.GetGooseAction()
    Assert-NotNull $action
}

Write-Host "`n--- Testing goose-timetracking.ps1 ---" -ForegroundColor Yellow
. "$PSScriptRoot\goose-timetracking.ps1"

Test-Function "TimeTracking - Initialization" {
    $tracker = [GooseTimeTracker]::new()
    Assert-NotNull $tracker.Config
    Assert-NotNull $tracker.DailyTracking
}

Test-Function "TimeTracking - Get Today Stats" {
    $stats = Get-TodayStats
    Assert-NotNull $stats
    Assert-NotNull $stats.TotalMinutes
}

Test-Function "TimeTracking - Get Productivity Score" {
    $score = Get-ProductivityScore
    Assert-NotNull $score
    Assert-NotNull $score.Score
}

Test-Function "TimeTracking - Get Current Session" {
    $session = Get-CurrentSession
    Assert-NotNull $session
    Assert-NotNull $session.CurrentApp
}

Write-Host "`n--- Testing goose-commands.ps1 ---" -ForegroundColor Yellow
. "$PSScriptRoot\goose-commands.ps1"

Test-Function "Commands - Initialization" {
    $commands = [GooseCommands]::new()
    Assert-NotNull $commands.Config
    Assert-NotNull $commands.Commands
}

Test-Function "Commands - Is Command" {
    $commands = Get-GooseCommands
    Assert-True $commands.IsCommand("!dance")
    Assert-False $commands.IsCommand("dance")
}

Test-Function "Commands - Process Command" {
    $commands = Get-GooseCommands
    $result = $commands.ProcessCommand("!help")
    Assert-True $result.Success
    Assert-NotNull $result.Response
}

Test-Function "Commands - Get Command List" {
    $list = Get-GooseCommandList
    Assert-NotNull $list
    Assert-True ($list.Length -gt 0)
}

Write-Host "`n--- Testing goose-calendar.ps1 ---" -ForegroundColor Yellow
. "$PSScriptRoot\goose-calendar.ps1"

Test-Function "Calendar - Initialization" {
    $calendar = [GooseCalendar]::new()
    Assert-NotNull $calendar.Config
    Assert-NotNull $calendar.TodayEvents
}

Test-Function "Calendar - Get Today Schedule" {
    $schedule = Get-TodaySchedule
    Assert-NotNull $schedule
    Assert-NotNull $schedule.EventCount
}

Test-Function "Calendar - Get Goose Reminder" {
    $reminder = Get-GooseCalendarReminder
    Assert-NotNull $reminder
}

Write-Host "`n--- Testing goose-stats.ps1 ---" -ForegroundColor Yellow
. "$PSScriptRoot\goose-stats.ps1"

Test-Function "Stats - Initialization" {
    $stats = [GooseStatsDashboard]::new()
    Assert-NotNull $stats.Config
    Assert-NotNull $stats.AllTimeStats
}

Test-Function "Stats - Get Today Summary" {
    $summary = Get-DailySummary
    Assert-NotNull $summary
    Assert-NotNull $summary.Date
}

Test-Function "Stats - Get All Time Stats" {
    $allTime = Get-AllTimeStats
    Assert-NotNull $allTime
    Assert-NotNull $allTime.TotalSessions
}

Test-Function "Stats - Get Dashboard Data" {
    $dashboard = Get-DashboardData
    Assert-NotNull $dashboard
    Assert-NotNull $dashboard.Today
}

Write-Host "`n--- Testing goose-music.ps1 ---" -ForegroundColor Yellow
. "$PSScriptRoot\goose-music.ps1"

Test-Function "Music - Initialization" {
    $music = [GooseMusic]::new()
    Assert-NotNull $music.Config
    Assert-NotNull $music.CurrentPlayer
}

Test-Function "Music - Get Now Playing" {
    $nowPlaying = Get-NowPlaying
    Assert-NotNull $nowPlaying
    Assert-NotNull $nowPlaying.Player
}

Test-Function "Music - Get Music Context" {
    $context = Get-MusicContext
    Assert-NotNull $context
    Assert-NotNull $context.NowPlaying
}

Write-Host "`n--- Testing goose-particles.ps1 ---" -ForegroundColor Yellow
. "$PSScriptRoot\goose-particles.ps1"

Test-Function "Particles - Initialization" {
    $particles = [GooseParticles]::new()
    Assert-NotNull $particles.Config
    Assert-False $particles.IsActive
}

Test-Function "Particles - Start Effect" {
    $particles = Get-GooseParticles
    $particles.StartEffect("snow")
    Assert-True $particles.IsActive
    Assert-Equal "snow" $particles.CurrentEffect
}

Test-Function "Particles - Stop Effect" {
    $particles = Get-GooseParticles
    $particles.StartEffect("snow")
    $particles.StopEffect()
    Assert-False $particles.IsActive
}

Test-Function "Particles - Get Available Effects" {
    $effects = Get-AvailableEffects
    Assert-True ($effects.Count -gt 0)
}

Test-Function "Particles - Get Particle Data" {
    $particles = Get-GooseParticles
    $particles.StartEffect("stars")
    Start-Sleep -Milliseconds 100
    $data = Get-ParticleData
    Assert-NotNull $data
    Assert-NotNull $data.Count
}

Write-Host "`n=== Test Summary ===" -ForegroundColor Cyan
Write-Host "Passed: $($testResults.Passed)" -ForegroundColor Green
Write-Host "Failed: $($testResults.Failed)" -ForegroundColor $(if ($testResults.Failed -gt 0) { "Red" } else { "Green" })
Write-Host "Total:  $($testResults.Passed + $testResults.Failed)" -ForegroundColor White

if ($testResults.Failed -gt 0) {
    Write-Host "`nFailed Tests:" -ForegroundColor Red
    foreach ($test in $testResults.Tests) {
        if (-not $test.Passed) {
            Write-Host "  - $($test.Name): $($test.Error)" -ForegroundColor Red
        }
    }
    exit 1
} else {
    Write-Host "`nAll tests passed!" -ForegroundColor Green
    exit 0
}
