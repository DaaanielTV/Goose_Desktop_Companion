Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$LoggingScriptPath = Join-Path $PSScriptRoot "..\Core\GooseLogging.ps1"
if (Test-Path $LoggingScriptPath) {
    . $LoggingScriptPath
}

$StatsScriptPath = Join-Path $PSScriptRoot "goose-stats.ps1"
if (Test-Path $StatsScriptPath) {
    . $StatsScriptPath
}

function Load-Stats {
    $statsFile = Join-Path $PSScriptRoot "goose_stats.json"
    if (Test-Path $statsFile) {
        try {
            return Get-Content $statsFile -Raw | ConvertFrom-Json
        } catch {
            return $null
        }
    }
    return $null
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Desktop Goose - Daily Stats Dashboard"
$form.Size = New-Object System.Drawing.Size(800, 600)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(25, 25, 30)
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Daily Stats Dashboard"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$titleLabel.Location = New-Object System.Drawing.Point(20, 20)
$titleLabel.Size = New-Object System.Drawing.Size(350, 35)
$titleLabel.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($titleLabel)

$gooseEmoji = New-Object System.Windows.Forms.Label
$gooseEmoji.Text = "🦆"
$gooseEmoji.Font = New-Object System.Drawing.Font("Segoe UI", 30)
$gooseEmoji.Location = New-Object System.Drawing.Point(700, 15)
$gooseEmoji.Size = New-Object System.Drawing.Size(60, 50)
$gooseEmoji.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($gooseEmoji)

$todayGroup = New-Object System.Windows.Forms.GroupBox
$todayGroup.Text = "Today's Progress"
$todayGroup.Location = New-Object System.Drawing.Point(20, 70)
$todayGroup.Size = New-Object System.Drawing.Size(350, 200)
$todayGroup.ForeColor = [System.Drawing.Color]::White
$todayGroup.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 40)
$form.Controls.Add($todayGroup)

$lblFocusTime = New-Object System.Windows.Forms.Label
$lblFocusTime.Text = "Focus Time:"
$lblFocusTime.Location = New-Object System.Drawing.Point(20, 30)
$lblFocusTime.Size = New-Object System.Drawing.Size(120, 25)
$lblFocusTime.ForeColor = [System.Drawing.Color]::LightGray
$todayGroup.Controls.Add($lblFocusTime)

$lblFocusValue = New-Object System.Windows.Forms.Label
$lblFocusValue.Text = "0 minutes"
$lblFocusValue.Location = New-Object System.Drawing.Point(150, 30)
$lblFocusValue.Size = New-Object System.Drawing.Size(100, 25)
$lblFocusValue.ForeColor = [System.Drawing.Color]::Lime
$lblFocusValue.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$todayGroup.Controls.Add($lblFocusValue)

$lblCommands = New-Object System.Windows.Forms.Label
$lblCommands.Text = "Commands Used:"
$lblCommands.Location = New-Object System.Drawing.Point(20, 60)
$lblCommands.Size = New-Object System.Drawing.Size(120, 25)
$lblCommands.ForeColor = [System.Drawing.Color]::LightGray
$todayGroup.Controls.Add($lblCommands)

$lblCommandsValue = New-Object System.Windows.Forms.Label
$lblCommandsValue.Text = "0"
$lblCommandsValue.Location = New-Object System.Drawing.Point(150, 60)
$lblCommandsValue.Size = New-Object System.Drawing.Size(100, 25)
$lblCommandsValue.ForeColor = [System.Drawing.Color]::Cyan
$lblCommandsValue.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$todayGroup.Controls.Add($lblCommandsValue)

$lblInteractions = New-Object System.Windows.Forms.Label
$lblInteractions.Text = "Interactions:"
$lblInteractions.Location = New-Object System.Drawing.Point(20, 90)
$lblInteractions.Size = New-Object System.Drawing.Size(120, 25)
$lblInteractions.ForeColor = [System.Drawing.Color]::LightGray
$todayGroup.Controls.Add($lblInteractions)

$lblInteractionsValue = New-Object System.Windows.Forms.Label
$lblInteractionsValue.Text = "0"
$lblInteractionsValue.Location = New-Object System.Drawing.Point(150, 90)
$lblInteractionsValue.Size = New-Object System.Drawing.Size(100, 25)
$lblInteractionsValue.ForeColor = [System.Drawing.Color]::Orange
$lblInteractionsValue.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$todayGroup.Controls.Add($lblInteractionsValue)

$lblPomodoro = New-Object System.Windows.Forms.Label
$lblPomodoro.Text = "Pomodoro Sessions:"
$lblPomodoro.Location = New-Object System.Drawing.Point(20, 120)
$lblPomodoro.Size = New-Object System.Drawing.Size(130, 25)
$lblPomodoro.ForeColor = [System.Drawing.Color]::LightGray
$todayGroup.Controls.Add($lblPomodoro)

$lblPomodoroValue = New-Object System.Windows.Forms.Label
$lblPomodoroValue.Text = "0"
$lblPomodoroValue.Location = New-Object System.Drawing.Point(150, 120)
$lblPomodoroValue.Size = New-Object System.Drawing.Size(100, 25)
$lblPomodoroValue.ForeColor = [System.Drawing.Color]::Yellow
$lblPomodoroValue.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$todayGroup.Controls.Add($lblPomodoroValue)

$lblSession = New-Object System.Windows.Forms.Label
$lblSession.Text = "Session Time:"
$lblSession.Location = New-Object System.Drawing.Point(20, 150)
$lblSession.Size = New-Object System.Drawing.Size(120, 25)
$lblSession.ForeColor = [System.Drawing.Color]::LightGray
$todayGroup.Controls.Add($lblSession)

$lblSessionValue = New-Object System.Windows.Forms.Label
$lblSessionValue.Text = "0 min"
$lblSessionValue.Location = New-Object System.Drawing.Point(150, 150)
$lblSessionValue.Size = New-Object System.Drawing.Size(100, 25)
$lblSessionValue.ForeColor = [System.Drawing.Color]::Magenta
$lblSessionValue.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$todayGroup.Controls.Add($lblSessionValue)

$allTimeGroup = New-Object System.Windows.Forms.GroupBox
$allTimeGroup.Text = "All-Time Statistics"
$allTimeGroup.Location = New-Object System.Drawing.Point(390, 70)
$allTimeGroup.Size = New-Object System.Drawing.Size(350, 200)
$allTimeGroup.ForeColor = [System.Drawing.Color]::White
$allTimeGroup.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 40)
$form.Controls.Add($allTimeGroup)

$lblTotalSessions = New-Object System.Windows.Forms.Label
$lblTotalSessions.Text = "Total Sessions:"
$lblTotalSessions.Location = New-Object System.Drawing.Point(20, 30)
$lblTotalSessions.Size = New-Object System.Drawing.Size(140, 25)
$lblTotalSessions.ForeColor = [System.Drawing.Color]::LightGray
$allTimeGroup.Controls.Add($lblTotalSessions)

$lblTotalSessionsValue = New-Object System.Windows.Forms.Label
$lblTotalSessionsValue.Text = "0"
$lblTotalSessionsValue.Location = New-Object System.Drawing.Point(170, 30)
$lblTotalSessionsValue.Size = New-Object System.Drawing.Size(100, 25)
$lblTotalSessionsValue.ForeColor = [System.Drawing.Color]::Lime
$lblTotalSessionsValue.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$allTimeGroup.Controls.Add($lblTotalSessionsValue)

$lblTotalFocus = New-Object System.Windows.Forms.Label
$lblTotalFocus.Text = "Total Focus Minutes:"
$lblTotalFocus.Location = New-Object System.Drawing.Point(20, 60)
$lblTotalFocus.Size = New-Object System.Drawing.Size(140, 25)
$lblTotalFocus.ForeColor = [System.Drawing.Color]::LightGray
$allTimeGroup.Controls.Add($lblTotalFocus)

$lblTotalFocusValue = New-Object System.Windows.Forms.Label
$lblTotalFocusValue.Text = "0"
$lblTotalFocusValue.Location = New-Object System.Drawing.Point(170, 60)
$lblTotalFocusValue.Size = New-Object System.Drawing.Size(100, 25)
$lblTotalFocusValue.ForeColor = [System.Drawing.Color]::Cyan
$lblTotalFocusValue.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$allTimeGroup.Controls.Add($lblTotalFocusValue)

$lblTotalCommands = New-Object System.Windows.Forms.Label
$lblTotalCommands.Text = "Total Commands:"
$lblTotalCommands.Location = New-Object System.Drawing.Point(20, 90)
$lblTotalCommands.Size = New-Object System.Drawing.Size(140, 25)
$lblTotalCommands.ForeColor = [System.Drawing.Color]::LightGray
$allTimeGroup.Controls.Add($lblTotalCommands)

$lblTotalCommandsValue = New-Object System.Windows.Forms.Label
$lblTotalCommandsValue.Text = "0"
$lblTotalCommandsValue.Location = New-Object System.Drawing.Point(170, 90)
$lblTotalCommandsValue.Size = New-Object System.Drawing.Size(100, 25)
$lblTotalCommandsValue.ForeColor = [System.Drawing.Color]::Orange
$lblTotalCommandsValue.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$allTimeGroup.Controls.Add($lblTotalCommandsValue)

$lblFavorite = New-Object System.Windows.Forms.Label
$lblFavorite.Text = "Favorite Command:"
$lblFavorite.Location = New-Object System.Drawing.Point(20, 120)
$lblFavorite.Size = New-Object System.Drawing.Size(140, 25)
$lblFavorite.ForeColor = [System.Drawing.Color]::LightGray
$allTimeGroup.Controls.Add($lblFavorite)

$lblFavoriteValue = New-Object System.Windows.Forms.Label
$lblFavoriteValue.Text = "-"
$lblFavoriteValue.Location = New-Object System.Drawing.Point(170, 120)
$lblFavoriteValue.Size = New-Object System.Drawing.Size(150, 25)
$lblFavoriteValue.ForeColor = [System.Drawing.Color]::Yellow
$lblFavoriteValue.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$allTimeGroup.Controls.Add($lblFavoriteValue)

$lblDaysActive = New-Object System.Windows.Forms.Label
$lblDaysActive.Text = "Days Active:"
$lblDaysActive.Location = New-Object System.Drawing.Point(20, 150)
$lblDaysActive.Size = New-Object System.Drawing.Size(140, 25)
$lblDaysActive.ForeColor = [System.Drawing.Color]::LightGray
$allTimeGroup.Controls.Add($lblDaysActive)

$lblDaysActiveValue = New-Object System.Windows.Forms.Label
$lblDaysActiveValue.Text = "0"
$lblDaysActiveValue.Location = New-Object System.Drawing.Point(170, 150)
$lblDaysActiveValue.Size = New-Object System.Drawing.Size(100, 25)
$lblDaysActiveValue.ForeColor = [System.Drawing.Color]::Magenta
$lblDaysActiveValue.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$allTimeGroup.Controls.Add($lblDaysActiveValue)

$commentGroup = New-Object System.Windows.Forms.GroupBox
$commentGroup.Text = "Goose Comment"
$commentGroup.Location = New-Object System.Drawing.Point(20, 290)
$commentGroup.Size = New-Object System.Drawing.Size(720, 150)
$commentGroup.ForeColor = [System.Drawing.Color]::White
$commentGroup.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 40)
$form.Controls.Add($commentGroup)

$lblComment = New-Object System.Windows.Forms.Label
$lblComment.Text = "No focus time recorded today. Let's get started!"
$lblComment.Location = New-Object System.Drawing.Point(20, 30)
$lblComment.Size = New-Object System.Drawing.Size(680, 100)
$lblComment.Font = New-Object System.Drawing.Font("Segoe UI", 14)
$lblComment.ForeColor = [System.Drawing.Color]::LightGreen
$lblComment.TextAlign = "MiddleCenter"
$commentGroup.Controls.Add($lblComment)

$btnRefresh = New-Object System.Windows.Forms.Button
$btnRefresh.Text = "Refresh Stats"
$btnRefresh.Location = New-Object System.Drawing.Point(20, 460)
$btnRefresh.Size = New-Object System.Drawing.Size(120, 35)
$btnRefresh.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnRefresh.ForeColor = [System.Drawing.Color]::White
$btnRefresh.FlatStyle = "Flat"
$btnRefresh.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($btnRefresh)

$btnExport = New-Object System.Windows.Forms.Button
$btnExport.Text = "Export Report"
$btnExport.Location = New-Object System.Drawing.Point(160, 460)
$btnExport.Size = New-Object System.Drawing.Size(120, 35)
$btnExport.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 105)
$btnExport.ForeColor = [System.Drawing.Color]::White
$btnExport.FlatStyle = "Flat"
$btnExport.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($btnExport)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Location = New-Object System.Drawing.Point(620, 460)
$btnClose.Size = New-Object System.Drawing.Size(120, 35)
$btnClose.BackColor = [System.Drawing.Color]::FromArgb(180, 60, 60)
$btnClose.ForeColor = [System.Drawing.Color]::White
$btnClose.FlatStyle = "Flat"
$btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($btnClose)

function Update-Stats-Display {
    $stats = Load-Stats
    
    if ($stats) {
        $lblTotalSessionsValue.Text = $stats.TotalSessions
        $lblTotalFocusValue.Text = "$($stats.TotalFocusMinutes) min"
        $lblTotalCommandsValue.Text = $stats.TotalCommands
        $lblFavoriteValue.Text = if ($stats.FavoriteCommand) { "!$($stats.FavoriteCommand)" } else { "-" }
        $lblDaysActiveValue.Text = $stats.DaysActive
    }
    
    try {
        $dashboard = Get-DashboardData
        $today = $dashboard.Today
        $allTime = $dashboard.AllTime
        
        $lblFocusValue.Text = "$($today.FocusMinutes) min"
        $lblCommandsValue.Text = $today.CommandsUsed
        $lblInteractionsValue.Text = $today.Interactions
        $lblPomodoroValue.Text = $today.PomodoroSessions
        $lblSessionValue.Text = "$($today.SessionTime) min"
        
        $lblComment.Text = $dashboard.GooseComment
    } catch {
    }
}

$btnRefresh.Add_Click({
    Update-Stats-Display
})

$btnExport.Add_Click({
    try {
        $report = Get-DailyReport
        $savePath = Join-Path $PSScriptRoot "goose_report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $report | Out-File -FilePath $savePath -Encoding UTF8
        [System.Windows.Forms.MessageBox]::Show("Report exported to:`n$savePath", "Export Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    } catch {
        [System.Windows.Forms.MessageBox]::Show("Failed to export report.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

$btnClose.Add_Click({
    $form.Close()
})

$form.Add_Load({
    Update-Stats-Display
})

[void]$form.ShowDialog()
