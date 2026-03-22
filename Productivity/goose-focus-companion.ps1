class GooseFocusCompanion {
    [hashtable]$Config
    [string]$DataPath
    [object]$Telemetry
    [bool]$IsActive
    [datetime]$SessionStart
    [int]$CurrentSessionMinutes
    [int]$Interruptions
    [System.Windows.Forms.Form]$FocusForm
    [System.Windows.Forms.Timer]$SessionTimer
    [System.Windows.Forms.Timer]$GooseTimer
    
    GooseFocusCompanion([string]$configFile = "config.ini", [object]$telemetry = $null) {
        $this.Telemetry = $telemetry
        $this.LoadConfig($configFile)
        $this.DataPath = Join-Path $PSScriptRoot "focus_data"
        if (-not (Test-Path $this.DataPath)) {
            New-Item -ItemType Directory -Path $this.DataPath -Force | Out-Null
        }
        $this.IsActive = $false
        $this.CurrentSessionMinutes = 0
        $this.Interruptions = 0
        $this.SessionStart = [datetime]::MinValue
        $this.SessionTimer = $null
        $this.GooseTimer = $null
    }
    
    [void] LoadConfig([string]$configFile) {
        $this.Config = @{
            Enabled = $true
            DefaultSessionMinutes = 25
            ShortBreakMinutes = 5
            LongBreakMinutes = 15
            SessionsBeforeLongBreak = 4
            GooseQuietDuringFocus = $true
            ShowProgress = $true
            AutoStartBreaks = $true
            DisturbanceThreshold = 5
            MotivationalMessages = $true
        }
        if (Test-Path $configFile) {
            Get-Content $configFile | ForEach-Object {
                if ($_ -match '^([^=]+)=(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    if ($this.Config.ContainsKey($key)) {
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
        }
    }
    
    [void] StartSession([int]$minutes = 0) {
        if ($minutes -eq 0) {
            $minutes = $this.Config["DefaultSessionMinutes"]
        }
        $this.Telemetry?.IncrementCounter("focus.sessions_started", 1)
        $this.Telemetry?.IncrementCounter("focus.requested_duration_minutes", $minutes)
        $this.IsActive = $true
        $this.SessionStart = Get-Date
        $this.CurrentSessionMinutes = $minutes
        $this.Interruptions = 0
        $span = $this.Telemetry?.StartSpan("focus.session", "focus-companion")
        $this.ShowFocusUI()
    }
    
    [void] StartBreak([bool]$isLongBreak = $false) {
        $minutes = if ($isLongBreak) { $this.Config["LongBreakMinutes"] } else { $this.Config["ShortBreakMinutes"] }
        $this.Telemetry?.IncrementCounter("focus.breaks_started", 1, @{type=if($isLongBreak){"long"}else{"short"}})
        $this.ShowBreakUI($minutes, $isLongBreak)
    }
    
    [void] RecordInterruption() {
        $this.Interruptions++
        $this.Telemetry?.IncrementCounter("focus.interruptions", 1)
        if ($this.Interruptions -ge $this.Config["DisturbanceThreshold"]) {
            $this.ShowWarning()
        }
    }
    
    [void] EndSession([bool]$completed = $true) {
        if ($completed) {
            $this.Telemetry?.IncrementCounter("focus.sessions_completed", 1)
            $duration = ((Get-Date) - $this.SessionStart).TotalMinutes
            $this.Telemetry?.RecordHistogram("focus.duration_minutes", $duration, "minutes")
            $this.SaveSession($duration, $completed)
        } else {
            $this.Telemetry?.IncrementCounter("focus.sessions_abandoned", 1)
        }
        $this.IsActive = $false
        if ($this.FocusForm) {
            $this.FocusForm.Close()
            $this.FocusForm = $null
        }
        if ($this.SessionTimer) {
            $this.SessionTimer.Stop()
            $this.SessionTimer = $null
        }
    }
    
    [void] ShowFocusUI() {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $form = New-Object System.Windows.Forms.Form
        $form.Text = "Desktop Goose - Focus Mode"
        $form.Size = New-Object System.Drawing.Size(400, 300)
        $form.StartPosition = "CenterScreen"
        $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
        $form.FormBorderStyle = "FixedDialog"
        $form.MaximizeBox = $false
        $lblTitle = New-Object System.Windows.Forms.Label
        $lblTitle.Text = "Focus Mode Active"
        $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
        $lblTitle.Location = New-Object System.Drawing.Point(20, 20)
        $lblTitle.Size = New-Object System.Drawing.Size(360, 40)
        $lblTitle.ForeColor = [System.Drawing.Color]::White
        $form.Controls.Add($lblTitle)
        $lblEmoji = New-Object System.Windows.Forms.Label
        $lblEmoji.Text = "🦆"
        $lblEmoji.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 40)
        $lblEmoji.Location = New-Object System.Drawing.Point(280, 20)
        $lblEmoji.Size = New-Object System.Drawing.Size(80, 60)
        $form.Controls.Add($lblEmoji)
        $lblTime = New-Object System.Windows.Forms.Label
        $lblTime.Name = "lblTime"
        $lblTime.Text = "$($this.CurrentSessionMinutes):00"
        $lblTime.Font = New-Object System.Drawing.Font("Segoe UI", 36)
        $lblTime.Location = New-Object System.Drawing.Point(20, 80)
        $lblTime.Size = New-Object System.Drawing.Size(360, 60)
        $lblTime.ForeColor = [System.Drawing.Color]::FromArgb(0, 200, 120)
        $lblTime.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $form.Controls.Add($lblTime)
        $lblStatus = New-Object System.Windows.Forms.Label
        $lblStatus.Text = "Stay focused! The goose is watching you."
        $lblStatus.Location = New-Object System.Drawing.Point(20, 150)
        $lblStatus.Size = New-Object System.Drawing.Size(360, 30)
        $lblStatus.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 185)
        $lblStatus.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $form.Controls.Add($lblStatus)
        $btnEnd = New-Object System.Windows.Forms.Button
        $btnEnd.Text = "End Session"
        $btnEnd.Location = New-Object System.Drawing.Point(130, 200)
        $btnEnd.Size = New-Object System.Drawing.Size(140, 40)
        $btnEnd.BackColor = [System.Drawing.Color]::FromArgb(180, 60, 60)
        $btnEnd.ForeColor = [System.Drawing.Color]::White
        $btnEnd.FlatStyle = "Flat"
        $form.Controls.Add($btnEnd)
        $btnEnd.Add_Click({
            $this.EndSession($false)
        })
        $progressBar = New-Object System.Windows.Forms.ProgressBar
        $progressBar.Name = "progressBar"
        $progressBar.Location = New-Object System.Drawing.Point(20, 260)
        $progressBar.Size = New-Object System.Drawing.Size(360, 20)
        $progressBar.Maximum = $this.CurrentSessionMinutes * 60
        $progressBar.Value = 0
        $progressBar.Style = "Continuous"
        $form.Controls.Add($progressBar)
        $this.SessionTimer = New-Object System.Windows.Forms.Timer
        $this.SessionTimer.Interval = 1000
        $remaining = $this.CurrentSessionMinutes * 60
        $startTime = Get-Date
        $this.SessionTimer.Add_Tick({
            $elapsed = ((Get-Date) - $startTime).TotalSeconds
            $remaining = ($this.CurrentSessionMinutes * 60) - $elapsed
            if ($remaining -le 0) {
                $this.EndSession($true)
                if ($this.Config["AutoStartBreaks"]) {
                    $this.StartBreak($false)
                }
            } else {
                $mins = [math]::Floor($remaining / 60)
                $secs = [math]::Floor($remaining % 60)
                $lblTime.Text = "$mins$([char]58)$($secs.ToString('00'))"
                $progressBar.Value = [math]::Min($progressBar.Maximum, $elapsed)
            }
        })
        $this.SessionTimer.Start()
        $this.FocusForm = $form
        $form.Add_FormClosing({ $this.EndSession($false) })
        $form.ShowDialog()
    }
    
    [void] ShowBreakUI([int]$minutes, [bool]$isLong) {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $form = New-Object System.Windows.Forms.Form
        $form.Text = "Desktop Goose - Break Time"
        $form.Size = New-Object System.Drawing.Size(400, 250)
        $form.StartPosition = "CenterScreen"
        $form.BackColor = [System.Drawing.Color]::FromArgb(40, 50, 40)
        $form.FormBorderStyle = "FixedDialog"
        $form.MaximizeBox = $false
        $lblTitle = New-Object System.Windows.Forms.Label
        $lblTitle.Text = if ($isLong) { "Long Break!" } else { "Short Break" }
        $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
        $lblTitle.Location = New-Object System.Drawing.Point(20, 20)
        $lblTitle.Size = New-Object System.Drawing.Size(360, 40)
        $lblTitle.ForeColor = [System.Drawing.Color]::FromArgb(100, 200, 100)
        $form.Controls.Add($lblTitle)
        $lblGoose = New-Object System.Windows.Forms.Label
        $lblGoose.Text = "🪖"
        $lblGoose.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 48)
        $lblGoose.Location = New-Object System.Drawing.Point(140, 60)
        $lblGoose.Size = New-Object System.Drawing.Size(100, 80)
        $form.Controls.Add($lblGoose)
        $lblTime = New-Object System.Windows.Forms.Label
        $lblTime.Name = "lblBreakTime"
        $lblTime.Text = "$minutes:00"
        $lblTime.Font = New-Object System.Drawing.Font("Segoe UI", 28)
        $lblTime.Location = New-Object System.Drawing.Point(20, 140)
        $lblTime.Size = New-Object System.Drawing.Size(360, 40)
        $lblTime.ForeColor = [System.Drawing.Color]::White
        $lblTime.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $form.Controls.Add($lblTime)
        $btnSkip = New-Object System.Windows.Forms.Button
        $btnSkip.Text = "Skip Break"
        $btnSkip.Location = New-Object System.Drawing.Point(130, 190)
        $btnSkip.Size = New-Object System.Drawing.Size(140, 35)
        $btnSkip.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 105)
        $btnSkip.ForeColor = [System.Drawing.Color]::White
        $btnSkip.FlatStyle = "Flat"
        $form.Controls.Add($btnSkip)
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 1000
        $remaining = $minutes * 60
        $timer.Add_Tick({
            $remaining--
            if ($remaining -le 0) {
                $form.Close()
                $timer.Stop()
            } else {
                $mins = [math]::Floor($remaining / 60)
                $secs = $remaining % 60
                $lblTime.Text = "$mins$([char]58)$($secs.ToString('00'))"
            }
        })
        $timer.Start()
        $btnSkip.Add_Click({ $form.Close() })
        $form.ShowDialog()
    }
    
    [void] ShowWarning() {
        $this.Telemetry?.IncrementCounter("focus.warnings_shown", 1)
        [System.Windows.Forms.MessageBox]::Show(
            "You've been interrupted $($this.Interruptions) times. Try to stay focused!",
            "Focus Warning",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning
        )
    }
    
    [void] SaveSession([double]$duration, [bool]$completed) {
        $sessionsFile = Join-Path $this.DataPath "sessions.json"
        $sessions = @()
        if (Test-Path $sessionsFile) {
            try { $sessions = @(Get-Content $sessionsFile -Raw | ConvertFrom-Json) } catch { }
        }
        $session = @{
            date = (Get-Date).ToString("yyyy-MM-dd")
            startTime = $this.SessionStart.ToString("HH:mm")
            duration = $duration
            completed = $completed
            interruptions = $this.Interruptions
        }
        $sessions = @($session) + $sessions
        if ($sessions.Count -gt 100) {
            $sessions = $sessions[0..99]
        }
        $sessions | ConvertTo-Json -Depth 10 | Set-Content -Path $sessionsFile
    }
    
    [hashtable] GetTodayStats() {
        $sessionsFile = Join-Path $this.DataPath "sessions.json"
        $sessions = @()
        if (Test-Path $sessionsFile) {
            try { $sessions = @(Get-Content $sessionsFile -Raw | ConvertFrom-Json) } catch { }
        }
        $today = (Get-Date).ToString("yyyy-MM-dd")
        $todaySessions = $sessions | Where-Object { $_.date -eq $today }
        $completed = $todaySessions | Where-Object { $_.completed }
        $totalMinutes = ($completed | Measure-Object -Property duration -Sum).Sum
        return @{
            sessionsToday = $todaySessions.Count
            completedToday = $completed.Count
            totalFocusMinutes = [math]::Round($totalMinutes, 0)
            currentStreak = $this.GetStreak($sessions)
        }
    }
    
    [int] GetStreak([array]$sessions) {
        if ($sessions.Count -eq 0) { return 0 }
        $streak = 0
        $date = Get-Date
        for ($i = 0; $i -lt 365; $i++) {
            $dateStr = $date.AddDays(-$i).ToString("yyyy-MM-dd")
            $hasSession = $sessions | Where-Object { $_.date -eq $dateStr -and $_.completed }
            if ($hasSession) {
                $streak++
            } elseif ($i -gt 0) {
                break
            }
        }
        return $streak
    }
}

$gooseFocusCompanion = $null

function Get-FocusCompanion {
    param([object]$Telemetry = $null)
    if ($script:gooseFocusCompanion -eq $null) {
        $script:gooseFocusCompanion = [GooseFocusCompanion]::new("config.ini", $Telemetry)
    }
    return $script:gooseFocusCompanion
}

function Start-FocusSession {
    param([int]$Minutes = 0)
    $companion = Get-FocusCompanion
    $companion.StartSession($Minutes)
}

function Stop-FocusSession {
    param([bool]$Completed = $true)
    $companion = Get-FocusCompanion
    $companion.EndSession($Completed)
}

function Get-FocusStats {
    $companion = Get-FocusCompanion
    return $companion.GetTodayStats()
}

Write-Host "Focus Companion Module Initialized"
