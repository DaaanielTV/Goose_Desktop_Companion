Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$form = New-Object System.Windows.Forms.Form
$form.Text = "Desktop Goose - Pomodoro Timer"
$form.Size = New-Object System.Drawing.Size(450, 400)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Pomodoro Timer"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$titleLabel.Location = New-Object System.Drawing.Point(20, 20)
$titleLabel.Size = New-Object System.Drawing.Size(250, 30)
$titleLabel.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($titleLabel)

$gooseIcon = New-Object System.Windows.Forms.Label
$gooseIcon.Text = "🦆"
$gooseIcon.Font = New-Object System.Drawing.Font("Segoe UI", 40)
$gooseIcon.Location = New-Object System.Drawing.Point(350, 10)
$gooseIcon.Size = New-Object System.Drawing.Size(60, 60)
$form.Controls.Add($gooseIcon)

$timerGroup = New-Object System.Windows.Forms.GroupBox
$timerGroup.Text = "Timer Display"
$timerGroup.Location = New-Object System.Drawing.Point(20, 60)
$timerGroup.Size = New-Object System.Drawing.Size(400, 150)
$timerGroup.ForeColor = [System.Drawing.Color]::White
$timerGroup.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$form.Controls.Add($timerGroup)

$lblTime = New-Object System.Windows.Forms.Label
$lblTime.Text = "25:00"
$lblTime.Location = New-Object System.Drawing.Point(100, 30)
$lblTime.Size = New-Object System.Drawing.Size(200, 60)
$lblTime.Font = New-Object System.Drawing.Font("Consolas", 36, [System.Drawing.FontStyle]::Bold)
$lblTime.ForeColor = [System.Drawing.Color]::Lime
$lblTime.TextAlign = "MiddleCenter"
$timerGroup.Controls.Add($lblTime)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Ready to focus"
$lblStatus.Location = New-Object System.Drawing.Point(100, 95)
$lblStatus.Size = New-Object System.Drawing.Size(200, 25)
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lblStatus.ForeColor = [System.Drawing.Color]::LightGray
$lblStatus.TextAlign = "MiddleCenter"
$timerGroup.Controls.Add($lblStatus)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(50, 125)
$progressBar.Size = New-Object System.Drawing.Size(300, 15)
$progressBar.Style = "Continuous"
$progressBar.Value = 0
$timerGroup.Controls.Add($progressBar)

$settingsGroup = New-Object System.Windows.Forms.GroupBox
$settingsGroup.Text = "Timer Settings"
$settingsGroup.Location = New-Object System.Drawing.Point(20, 220)
$settingsGroup.Size = New-Object System.Drawing.Size(400, 80)
$settingsGroup.ForeColor = [System.Drawing.Color]::White
$settingsGroup.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$form.Controls.Add($settingsGroup)

$lblSession = New-Object System.Windows.Forms.Label
$lblSession.Text = "Session (min):"
$lblSession.Location = New-Object System.Drawing.Point(15, 30)
$lblSession.Size = New-Object System.Drawing.Size(100, 22)
$lblSession.ForeColor = [System.Drawing.Color]::LightGray
$settingsGroup.Controls.Add($lblSession)

$numSession = New-Object System.Windows.Forms.NumericUpDown
$numSession.Location = New-Object System.Drawing.Point(120, 28)
$numSession.Size = New-Object System.Drawing.Size(60, 25)
$numSession.Minimum = 1
$numSession.Maximum = 60
$numSession.Value = 25
$numSession.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 65)
$numSession.ForeColor = [System.Drawing.Color]::White
$settingsGroup.Controls.Add($numSession)

$lblBreak = New-Object System.Windows.Forms.Label
$lblBreak.Text = "Break (min):"
$lblBreak.Location = New-Object System.Drawing.Point(200, 30)
$lblBreak.Size = New-Object System.Drawing.Size(90, 22)
$lblBreak.ForeColor = [System.Drawing.Color]::LightGray
$settingsGroup.Controls.Add($lblBreak)

$numBreak = New-Object System.Windows.Forms.NumericUpDown
$numBreak.Location = New-Object System.Drawing.Point(295, 28)
$numBreak.Size = New-Object System.Drawing.Size(60, 25)
$numBreak.Minimum = 1
$numBreak.Maximum = 30
$numBreak.Value = 5
$numBreak.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 65)
$numBreak.ForeColor = [System.Drawing.Color]::White
$settingsGroup.Controls.Add($numBreak)

$lblSessions = New-Object System.Windows.Forms.Label
$lblSessions.Text = "Sessions: 0/4"
$lblSessions.Location = New-Object System.Drawing.Point(15, 55)
$lblSessions.Size = New-Object System.Drawing.Size(100, 22)
$lblSessions.ForeColor = [System.Drawing.Color]::Yellow
$settingsGroup.Controls.Add($lblSessions)

$btnStart = New-Object System.Windows.Forms.Button
$btnStart.Text = "Start"
$btnStart.Location = New-Object System.Drawing.Point(20, 315)
$btnStart.Size = New-Object System.Drawing.Size(100, 40)
$btnStart.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 80)
$btnStart.ForeColor = [System.Drawing.Color]::White
$btnStart.FlatStyle = "Flat"
$btnStart.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($btnStart)

$btnPause = New-Object System.Windows.Forms.Button
$btnPause.Text = "Pause"
$btnPause.Location = New-Object System.Drawing.Point(130, 315)
$btnPause.Size = New-Object System.Drawing.Size(100, 40)
$btnPause.BackColor = [System.Drawing.Color]::FromArgb(200, 150, 0)
$btnPause.ForeColor = [System.Drawing.Color]::White
$btnPause.FlatStyle = "Flat"
$btnPause.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$btnPause.Enabled = $false
$form.Controls.Add($btnPause)

$btnReset = New-Object System.Windows.Forms.Button
$btnReset.Text = "Reset"
$btnReset.Location = New-Object System.Drawing.Point(240, 315)
$btnReset.Size = New-Object System.Drawing.Size(100, 40)
$btnReset.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 105)
$btnReset.ForeColor = [System.Drawing.Color]::White
$btnReset.FlatStyle = "Flat"
$btnReset.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$form.Controls.Add($btnReset)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Location = New-Object System.Drawing.Point(350, 315)
$btnClose.Size = New-Object System.Drawing.Size(70, 40)
$btnClose.BackColor = [System.Drawing.Color]::FromArgb(180, 60, 60)
$btnClose.ForeColor = [System.Drawing.Color]::White
$btnClose.FlatStyle = "Flat"
$btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$form.Controls.Add($btnClose)

$isRunning = $false
$isPaused = $false
$isBreak = $false
$remainingSeconds = 25 * 60
$completedSessions = 0
$timer = $null

function Update-Timer-Display {
    $minutes = [Math]::Floor($remainingSeconds / 60)
    $seconds = $remainingSeconds % 60
    $lblTime.Text = "$($minutes.ToString('00')):$($seconds.ToString('00'))"
    
    $totalSeconds = if ($isBreak) { $numBreak.Value * 60 } else { $numSession.Value * 60 }
    $progressBar.Value = [Math]::Round((($totalSeconds - $remainingSeconds) / $totalSeconds) * 100)
}

function Start-Timer {
    $script:timer = New-Object System.Windows.Forms.Timer
    $script:timer.Interval = 1000
    $script:timer.Add_Tick({
        if (-not $script:isPaused) {
            $script:remainingSeconds--
            Update-Timer-Display
            
            if ($script:remainingSeconds -le 0) {
                $script:timer.Stop()
                
                if ($script:isBreak) {
                    $script:isBreak = $false
                    $script:remainingSeconds = $numSession.Value * 60
                    $lblStatus.Text = "Session complete! Ready to focus."
                    $lblStatus.ForeColor = [System.Drawing.Color]::Lime
                    [System.Windows.Forms.MessageBox]::Show("Break is over! Ready for another session?", "Break Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                } else {
                    $script:completedSessions++
                    $lblSessions.Text = "Sessions: $($script:completedSessions)/4"
                    
                    if ($script:completedSessions % 4 -eq 0) {
                        $script:remainingSeconds = $numBreak.Value * 3 * 60
                        $lblStatus.Text = "Long break earned! Relax."
                        $lblStatus.ForeColor = [System.Drawing.Color]::Cyan
                    } else {
                        $script:isBreak = $true
                        $script:remainingSeconds = $numBreak.Value * 60
                        $lblStatus.Text = "Break time! Take a rest."
                        $lblStatus.ForeColor = [System.Drawing.Color]::Yellow
                    }
                    
                    [System.Windows.Forms.MessageBox]::Show("Session complete! Time for a break.", "Session Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
                }
                
                Update-Timer-Display
                $script:isRunning = $false
                $script:isPaused = $false
                $btnStart.Text = "Start"
                $btnStart.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 80)
                $btnPause.Enabled = $false
            }
        }
    })
    $script:timer.Start()
}

$btnStart.Add_Click({
    if ($isRunning) {
        return
    }
    
    $isRunning = $true
    $isPaused = $false
    $btnStart.Text = "Running"
    $btnStart.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $btnPause.Enabled = $true
    
    if (-not $isBreak) {
        $lblStatus.Text = "Focus time! Stay productive."
        $lblStatus.ForeColor = [System.Drawing.Color]::Lime
    } else {
        $lblStatus.Text = "Break time! Relax."
        $lblStatus.ForeColor = [System.Drawing.Color]::Yellow
    }
    
    Start-Timer
})

$btnPause.Add_Click({
    if (-not $isRunning) {
        return
    }
    
    if ($isPaused) {
        $isPaused = $false
        $btnPause.Text = "Pause"
        $btnPause.BackColor = [System.Drawing.Color]::FromArgb(200, 150, 0)
        $lblStatus.Text = if ($isBreak) { "Break time! (Paused)" } else { "Focus time! (Paused)" }
    } else {
        $isPaused = $true
        $btnPause.Text = "Resume"
        $btnPause.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 80)
        $lblStatus.Text = "Paused"
        $lblStatus.ForeColor = [System.Drawing.Color]::Orange
    }
})

$btnReset.Add_Click({
    if ($timer) {
        $timer.Stop()
    }
    
    $isRunning = $false
    $isPaused = $false
    $isBreak = $false
    $remainingSeconds = $numSession.Value * 60
    $btnStart.Text = "Start"
    $btnStart.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 80)
    $btnPause.Text = "Pause"
    $btnPause.BackColor = [System.Drawing.Color]::FromArgb(200, 150, 0)
    $btnPause.Enabled = $false
    $lblStatus.Text = "Ready to focus"
    $lblStatus.ForeColor = [System.Drawing.Color]::LightGray
    
    Update-Timer-Display
})

$btnClose.Add_Click({
    if ($timer) {
        $timer.Stop()
    }
    $form.Close()
})

$form.Add_FormClosing({
    if ($timer) {
        $timer.Stop()
    }
})

Update-Timer-Display

[void]$form.ShowDialog()
