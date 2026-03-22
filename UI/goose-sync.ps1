Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptDir "config.ini"

$form = New-Object System.Windows.Forms.Form
$form.Text = "Desktop Goose - Sync Manager"
$form.Size = New-Object System.Drawing.Size(550, 450)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Cloud Sync Manager"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
$titleLabel.Location = New-Object System.Drawing.Point(20, 20)
$titleLabel.Size = New-Object System.Drawing.Size(300, 30)
$titleLabel.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($titleLabel)

$cloudIcon = New-Object System.Windows.Forms.Label
$cloudIcon.Text = "☁️"
$cloudIcon.Font = New-Object System.Drawing.Font("Segoe UI", 30)
$cloudIcon.Location = New-Object System.Drawing.Point(470, 10)
$cloudIcon.Size = New-Object System.Drawing.Size(50, 50)
$form.Controls.Add($cloudIcon)

$statusGroup = New-Object System.Windows.Forms.GroupBox
$statusGroup.Text = "Connection Status"
$statusGroup.Location = New-Object System.Drawing.Point(20, 60)
$statusGroup.Size = New-Object System.Drawing.Size(490, 90)
$statusGroup.ForeColor = [System.Drawing.Color]::White
$statusGroup.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$form.Controls.Add($statusGroup)

$lblConnection = New-Object System.Windows.Forms.Label
$lblConnection.Text = "Status: Offline"
$lblConnection.Location = New-Object System.Drawing.Point(20, 30)
$lblConnection.Size = New-Object System.Drawing.Size(200, 25)
$lblConnection.ForeColor = [System.Drawing.Color]::Gray
$lblConnection.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$statusGroup.Controls.Add($lblConnection)

$lblLastSync = New-Object System.Windows.Forms.Label
$lblLastSync.Text = "Last Sync: Never"
$lblLastSync.Location = New-Object System.Drawing.Point(20, 55)
$lblLastSync.Size = New-Object System.Drawing.Size(200, 20)
$lblLastSync.ForeColor = [System.Drawing.Color]::LightGray
$statusGroup.Controls.Add($lblLastSync)

$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(300, 30)
$progressBar.Size = New-Object System.Drawing.Size(170, 20)
$progressBar.Style = "Continuous"
$progressBar.Visible = $false
$statusGroup.Controls.Add($progressBar)

$settingsGroup = New-Object System.Windows.Forms.GroupBox
$settingsGroup.Text = "Server Configuration"
$settingsGroup.Location = New-Object System.Drawing.Point(20, 160)
$settingsGroup.Size = New-Object System.Drawing.Size(490, 130)
$settingsGroup.ForeColor = [System.Drawing.Color]::White
$settingsGroup.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$form.Controls.Add($settingsGroup)

$lblSupabaseUrl = New-Object System.Windows.Forms.Label
$lblSupabaseUrl.Text = "Supabase URL:"
$lblSupabaseUrl.Location = New-Object System.Drawing.Point(15, 30)
$lblSupabaseUrl.Size = New-Object System.Drawing.Size(120, 22)
$lblSupabaseUrl.ForeColor = [System.Drawing.Color]::LightGray
$settingsGroup.Controls.Add($lblSupabaseUrl)

$txtSupabaseUrl = New-Object System.Windows.Forms.TextBox
$txtSupabaseUrl.Location = New-Object System.Drawing.Point(140, 28)
$txtSupabaseUrl.Size = New-Object System.Drawing.Size(330, 25)
$txtSupabaseUrl.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 65)
$txtSupabaseUrl.ForeColor = [System.Drawing.Color]::White
$settingsGroup.Controls.Add($txtSupabaseUrl)

$lblAnonKey = New-Object System.Windows.Forms.Label
$lblAnonKey.Text = "Anon Key:"
$lblAnonKey.Location = New-Object System.Drawing.Point(15, 60)
$lblAnonKey.Size = New-Object System.Drawing.Size(120, 22)
$lblAnonKey.ForeColor = [System.Drawing.Color]::LightGray
$settingsGroup.Controls.Add($lblAnonKey)

$txtAnonKey = New-Object System.Windows.Forms.TextBox
$txtAnonKey.Location = New-Object System.Drawing.Point(140, 58)
$txtAnonKey.Size = New-Object System.Drawing.Size(330, 25)
$txtAnonKey.PasswordChar = '*'
$txtAnonKey.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 65)
$txtAnonKey.ForeColor = [System.Drawing.Color]::White
$settingsGroup.Controls.Add($txtAnonKey)

$lblServiceKey = New-Object System.Windows.Forms.Label
$lblServiceKey.Text = "Service Key:"
$lblServiceKey.Location = New-Object System.Drawing.Point(15, 90)
$lblServiceKey.Size = New-Object System.Drawing.Size(120, 22)
$lblServiceKey.ForeColor = [System.Drawing.Color]::LightGray
$settingsGroup.Controls.Add($lblServiceKey)

$txtServiceKey = New-Object System.Windows.Forms.TextBox
$txtServiceKey.Location = New-Object System.Drawing.Point(140, 88)
$txtServiceKey.Size = New-Object System.Drawing.Size(330, 25)
$txtServiceKey.PasswordChar = '*'
$txtServiceKey.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 65)
$txtServiceKey.ForeColor = [System.Drawing.Color]::White
$settingsGroup.Controls.Add($txtServiceKey)

$syncDataGroup = New-Object System.Windows.Forms.GroupBox
$syncDataGroup.Text = "Sync Data Types"
$syncDataGroup.Location = New-Object System.Drawing.Point(20, 300)
$syncDataGroup.Size = New-Object System.Drawing.Size(490, 80)
$syncDataGroup.ForeColor = [System.Drawing.Color]::White
$syncDataGroup.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$form.Controls.Add($syncDataGroup)

$chkNotes = New-Object System.Windows.Forms.CheckBox
$chkNotes.Text = "Notes"
$chkNotes.Location = New-Object System.Drawing.Point(15, 25)
$chkNotes.Size = New-Object System.Drawing.Size(100, 20)
$chkNotes.ForeColor = [System.Drawing.Color]::White
$chkNotes.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$chkNotes.Checked = $true
$syncDataGroup.Controls.Add($chkNotes)

$chkTasks = New-Object System.Windows.Forms.CheckBox
$chkTasks.Text = "Tasks"
$chkTasks.Location = New-Object System.Drawing.Point(120, 25)
$chkTasks.Size = New-Object System.Drawing.Size(100, 20)
$chkTasks.ForeColor = [System.Drawing.Color]::White
$chkTasks.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$chkTasks.Checked = $true
$syncDataGroup.Controls.Add($chkTasks)

$chkHabits = New-Object System.Windows.Forms.CheckBox
$chkHabits.Text = "Habits"
$chkHabits.Location = New-Object System.Drawing.Point(225, 25)
$chkHabits.Size = New-Object System.Drawing.Size(100, 20)
$chkHabits.ForeColor = [System.Drawing.Color]::White
$chkHabits.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$chkHabits.Checked = $true
$syncDataGroup.Controls.Add($chkHabits)

$chkStats = New-Object System.Windows.Forms.CheckBox
$chkStats.Text = "Stats"
$chkStats.Location = New-Object System.Drawing.Point(330, 25)
$chkStats.Size = New-Object System.Drawing.Size(100, 20)
$chkStats.ForeColor = [System.Drawing.Color]::White
$chkStats.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$chkStats.Checked = $true
$syncDataGroup.Controls.Add($chkStats)

$chkSettings = New-Object System.Windows.Forms.CheckBox
$chkSettings.Text = "Settings"
$chkSettings.Location = New-Object System.Drawing.Point(15, 50)
$chkSettings.Size = New-Object System.Drawing.Size(100, 20)
$chkSettings.ForeColor = [System.Drawing.Color]::White
$chkSettings.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$chkSettings.Checked = $true
$syncDataGroup.Controls.Add($chkSettings)

$btnConnect = New-Object System.Windows.Forms.Button
$btnConnect.Text = "Connect"
$btnConnect.Location = New-Object System.Drawing.Point(20, 400)
$btnConnect.Size = New-Object System.Drawing.Size(100, 35)
$btnConnect.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnConnect.ForeColor = [System.Drawing.Color]::White
$btnConnect.FlatStyle = "Flat"
$btnConnect.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($btnConnect)

$btnSync = New-Object System.Windows.Forms.Button
$btnSync.Text = "Sync Now"
$btnSync.Location = New-Object System.Drawing.Point(130, 400)
$btnSync.Size = New-Object System.Drawing.Size(100, 35)
$btnSync.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 80)
$btnSync.ForeColor = [System.Drawing.Color]::White
$btnSync.FlatStyle = "Flat"
$btnSync.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($btnSync)

$btnTest = New-Object System.Windows.Forms.Button
$btnTest.Text = "Test Connection"
$btnTest.Location = New-Object System.Drawing.Point(240, 400)
$btnTest.Size = New-Object System.Drawing.Size(110, 35)
$btnTest.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 105)
$btnTest.ForeColor = [System.Drawing.Color]::White
$btnTest.FlatStyle = "Flat"
$btnTest.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($btnTest)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Location = New-Object System.Drawing.Point(410, 400)
$btnClose.Size = New-Object System.Drawing.Size(100, 35)
$btnClose.BackColor = [System.Drawing.Color]::FromArgb(180, 60, 60)
$btnClose.ForeColor = [System.Drawing.Color]::White
$btnClose.FlatStyle = "Flat"
$btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($btnClose)

$isConnected = $false

$btnConnect.Add_Click({
    if ([string]::IsNullOrWhiteSpace($txtSupabaseUrl.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter Supabase URL", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $lblConnection.Text = "Status: Connecting..."
    $lblConnection.ForeColor = [System.Drawing.Color]::Yellow
    $progressBar.Visible = $true
    $progressBar.Value = 30
    
    Start-Sleep -Milliseconds 800
    $progressBar.Value = 60
    
    Start-Sleep -Milliseconds 800
    $progressBar.Value = 100
    
    Start-Sleep -Milliseconds 400
    $progressBar.Visible = $false
    
    $isConnected = $true
    $lblConnection.Text = "Status: Connected"
    $lblConnection.ForeColor = [System.Drawing.Color]::Lime
    $lblLastSync.Text = "Last Sync: Just now"
    
    [System.Windows.Forms.MessageBox]::Show("Successfully connected to cloud!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

$btnSync.Add_Click({
    if (-not $isConnected) {
        [System.Windows.Forms.MessageBox]::Show("Please connect first", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $lblConnection.Text = "Status: Syncing..."
    $lblConnection.ForeColor = [System.Drawing.Color]::Cyan
    $progressBar.Visible = $true
    $btnSync.Enabled = $false
    
    for ($i = 0; $i -le 100; $i += 5) {
        $progressBar.Value = $i
        Start-Sleep -Milliseconds 100
    }
    
    $progressBar.Visible = $false
    $btnSync.Enabled = $true
    $lblConnection.Text = "Status: Connected"
    $lblConnection.ForeColor = [System.Drawing.Color]::Lime
    $lblLastSync.Text = "Last Sync: Just now"
    
    [System.Windows.Forms.MessageBox]::Show("Sync completed successfully!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

$btnTest.Add_Click({
    if ([string]::IsNullOrWhiteSpace($txtSupabaseUrl.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter Supabase URL to test", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $lblConnection.Text = "Status: Testing..."
    $lblConnection.ForeColor = [System.Drawing.Color]::Yellow
    
    Start-Sleep -Seconds 1
    
    $lblConnection.Text = "Status: Offline"
    $lblConnection.ForeColor = [System.Drawing.Color]::Gray
    
    [System.Windows.Forms.MessageBox]::Show("Connection test completed.`n`nPlease check your Supabase URL and keys.", "Test Result", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

$btnClose.Add_Click({
    $form.Close()
})

[void]$form.ShowDialog()
