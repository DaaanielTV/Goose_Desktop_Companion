Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$LoggingScriptPath = Join-Path $PSScriptRoot "..\Core\GooseLogging.ps1"
if (Test-Path $LoggingScriptPath) {
    . $LoggingScriptPath
}

$form = New-Object System.Windows.Forms.Form
$form.Text = "Desktop Goose - System Tray"
$form.Size = New-Object System.Drawing.Size(400, 300)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.MinimizeBox = $false

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "System Tray Settings"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$titleLabel.Location = New-Object System.Drawing.Point(20, 20)
$titleLabel.Size = New-Object System.Drawing.Size(250, 30)
$titleLabel.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($titleLabel)

$gooseEmoji = New-Object System.Windows.Forms.Label
$gooseEmoji.Text = "🦆"
$gooseEmoji.Font = New-Object System.Drawing.Font("Segoe UI", 30)
$gooseEmoji.Location = New-Object System.Drawing.Point(300, 10)
$gooseEmoji.Size = New-Object System.Drawing.Size(60, 50)
$gooseEmoji.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($gooseEmoji)

$statusGroup = New-Object System.Windows.Forms.GroupBox
$statusGroup.Text = "Current Status"
$statusGroup.Location = New-Object System.Drawing.Point(20, 60)
$statusGroup.Size = New-Object System.Drawing.Size(350, 80)
$statusGroup.ForeColor = [System.Drawing.Color]::White
$statusGroup.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$form.Controls.Add($statusGroup)

$lblTrayStatus = New-Object System.Windows.Forms.Label
$lblTrayStatus.Text = "System Tray: Active"
$lblTrayStatus.Location = New-Object System.Drawing.Point(20, 30)
$lblTrayStatus.Size = New-Object System.Drawing.Size(200, 25)
$lblTrayStatus.ForeColor = [System.Drawing.Color]::Lime
$lblTrayStatus.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$statusGroup.Controls.Add($lblTrayStatus)

$lblMinimizeStatus = New-Object System.Windows.Forms.Label
$lblMinimizeStatus.Text = "Minimized to Tray: No"
$lblMinimizeStatus.Location = New-Object System.Drawing.Point(20, 50)
$lblMinimizeStatus.Size = New-Object System.Drawing.Size(200, 20)
$lblMinimizeStatus.ForeColor = [System.Drawing.Color]::LightGray
$statusGroup.Controls.Add($lblMinimizeStatus)

$settingsGroup = New-Object System.Windows.Forms.GroupBox
$settingsGroup.Text = "Tray Settings"
$settingsGroup.Location = New-Object System.Drawing.Point(20, 150)
$settingsGroup.Size = New-Object System.Drawing.Size(350, 100)
$settingsGroup.ForeColor = [System.Drawing.Color]::White
$settingsGroup.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$form.Controls.Add($settingsGroup)

$chkTrayEnabled = New-Object System.Windows.Forms.CheckBox
$chkTrayEnabled.Text = "Enable System Tray"
$chkTrayEnabled.Location = New-Object System.Drawing.Point(15, 25)
$chkTrayEnabled.Size = New-Object System.Drawing.Size(200, 20)
$chkTrayEnabled.ForeColor = [System.Drawing.Color]::White
$chkTrayEnabled.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$chkTrayEnabled.Checked = $true
$settingsGroup.Controls.Add($chkTrayEnabled)

$chkBalloon = New-Object System.Windows.Forms.CheckBox
$chkBalloon.Text = "Show Balloon Notifications"
$chkBalloon.Location = New-Object System.Drawing.Point(15, 50)
$chkBalloon.Size = New-Object System.Drawing.Size(200, 20)
$chkBalloon.ForeColor = [System.Drawing.Color]::White
$chkBalloon.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$chkBalloon.Checked = $true
$settingsGroup.Controls.Add($chkBalloon)

$btnTestBalloon = New-Object System.Windows.Forms.Button
$btnTestBalloon.Text = "Test Notification"
$btnTestBalloon.Location = New-Object System.Drawing.Point(220, 25)
$btnTestBalloon.Size = New-Object System.Drawing.Size(115, 30)
$btnTestBalloon.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnTestBalloon.ForeColor = [System.Drawing.Color]::White
$btnTestBalloon.FlatStyle = "Flat"
$settingsGroup.Controls.Add($btnTestBalloon)

$btnTestBalloon.Add_Click({
    Add-Type -AssemblyName System.Windows.Forms
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Information
    $notify.BalloonTipTitle = "Desktop Goose"
    $notify.BalloonTipText = "Hello! The goose is here!"
    $notify.BalloonTipIcon = "Info"
    $notify.Visible = $true
    $notify.ShowBalloonTip(3000)
    Start-Sleep -Seconds 4
    $notify.Dispose()
})

$btnMinimize = New-Object System.Windows.Forms.Button
$btnMinimize.Text = "Minimize to Tray"
$btnMinimize.Location = New-Object System.Drawing.Point(20, 260)
$btnMinimize.Size = New-Object System.Drawing.Size(140, 35)
$btnMinimize.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 80)
$btnMinimize.ForeColor = [System.Drawing.Color]::White
$btnMinimize.FlatStyle = "Flat"
$form.Controls.Add($btnMinimize)

$btnRestore = New-Object System.Windows.Forms.Button
$btnRestore.Text = "Restore from Tray"
$btnRestore.Location = New-Object System.Drawing.Point(170, 260)
$btnRestore.Size = New-Object System.Drawing.Size(140, 35)
$btnRestore.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 105)
$btnRestore.ForeColor = [System.Drawing.Color]::White
$btnRestore.FlatStyle = "Flat"
$form.Controls.Add($btnRestore)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Location = New-Object System.Drawing.Point(320, 260)
$btnClose.Size = New-Object System.Drawing.Size(50, 35)
$btnClose.BackColor = [System.Drawing.Color]::FromArgb(180, 60, 60)
$btnClose.ForeColor = [System.Drawing.Color]::White
$btnClose.FlatStyle = "Flat"
$form.Controls.Add($btnClose)

$minimizedToTray = $false

$btnMinimize.Add_Click({
    $minimizedToTray = $true
    $lblMinimizeStatus.Text = "Minimized to Tray: Yes"
    $lblMinimizeStatus.ForeColor = [System.Drawing.Color]::Lime
    $form.Hide()
    
    Add-Type -AssemblyName System.Windows.Forms
    $notify = New-Object System.Windows.Forms.NotifyIcon
    $notify.Icon = [System.Drawing.SystemIcons]::Information
    $notify.BalloonTipTitle = "Desktop Goose"
    $notify.BalloonTipText = "I'm in the tray! Click to bring me back."
    $notify.BalloonTipIcon = "Info"
    $notify.Visible = $true
    
    $notify.Add_Click({
        $form.Show()
        $form.Activate()
        $minimizedToTray = $false
        $lblMinimizeStatus.Text = "Minimized to Tray: No"
        $lblMinimizeStatus.ForeColor = [System.Drawing.Color]::LightGray
        $notify.Dispose()
    })
})

$btnRestore.Add_Click({
    if ($minimizedToTray) {
        $form.Show()
        $form.Activate()
        $minimizedToTray = $false
        $lblMinimizeStatus.Text = "Minimized to Tray: No"
        $lblMinimizeStatus.ForeColor = [System.Drawing.Color]::LightGray
    }
})

$btnClose.Add_Click({
    $form.Close()
})

$form.Add_FormClosing({
    if ($minimizedToTray) {
        $result = [System.Windows.Forms.MessageBox]::Show("Goose is minimized to tray. Close anyway?", "Confirm Exit", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($result -ne "Yes") {
            $_.Cancel = $true
        }
    }
})

[void]$form.ShowDialog()
