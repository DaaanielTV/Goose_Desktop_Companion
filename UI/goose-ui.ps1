Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$LoggingScriptPath = Join-Path $PSScriptRoot "..\Core\GooseLogging.ps1"
if (Test-Path $LoggingScriptPath) {
    . $LoggingScriptPath
}

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $scriptDir "config.ini"
$exePath = Join-Path $scriptDir "GooseDesktop.exe"
$gooseProcesses = @()

function Load-Config {
    $config = @{}
    if (Test-Path $configPath) {
        Get-Content $configPath | ForEach-Object {
            if ($_ -match '^([^=]+)=(.*)$') {
                $config[$matches[1].Trim()] = $matches[2].Trim()
            }
        }
    }
    return $config
}

function Save-Config {
    param([hashtable]$config)
    $content = ""
    foreach ($key in $config.Keys) {
        $content += "$key=$($config[$key])`n"
    }
    Set-Content -Path $configPath -Value $content
}

function Get-RunningGooseCount {
    $count = 0
    $gooseProcesses = @()
    $procs = Get-Process -Name "GooseDesktop" -ErrorAction SilentlyContinue
    if ($procs) {
        $count = $procs.Count
        $gooseProcesses = @($procs)
    }
    return @{
        Count = $count
        Processes = $gooseProcesses
    }
}

function Sync-GooseCount {
    param([int]$desiredCount, [System.Windows.Forms.Form]$form)
    if (-not (Test-Path $exePath)) {
        [System.Windows.Forms.MessageBox]::Show("GooseDesktop.exe not found!", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    $running = Get-RunningGooseCount
    $currentCount = $running.Count
    $diff = $desiredCount - $currentCount

    if ($diff -gt 0) {
        for ($i = 0; $i -lt $diff; $i++) {
            Start-Process -FilePath $exePath -PassThru | Out-Null
        }
    } elseif ($diff -lt 0) {
        $procsToKill = $running.Processes | Select-Object -First ([Math]::Abs($diff))
        foreach ($p in $procsToKill) {
            try { $p.Kill() } catch { }
        }
    }

    Update-Status -form $form
}

function Update-Status {
    param([System.Windows.Forms.Form]$form)
    $running = Get-RunningGooseCount
    $lblStatus.Text = "Running: $($running.Count) goose(es)"
    $lblStatus.ForeColor = if ($running.Count -gt 0) { [System.Drawing.Color]::Green } else { [System.Drawing.Color]::Gray }
    $numDesired.Value = $running.Count
}

$config = Load-Config

$form = New-Object System.Windows.Forms.Form
$form.Text = "Desktop Goose Launcher"
$form.Size = New-Object System.Drawing.Size(450, 380)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(240, 240, 245)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Desktop Goose"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
$titleLabel.Location = New-Object System.Drawing.Point(20, 20)
$titleLabel.Size = New-Object System.Drawing.Size(250, 35)
$form.Controls.Add($titleLabel)

$iconLabel = New-Object System.Windows.Forms.Label
$iconLabel.Text = "🦆"
$iconLabel.Font = New-Object System.Drawing.Font("Segoe UI", 30)
$iconLabel.Location = New-Object System.Drawing.Point(350, 15)
$iconLabel.Size = New-Object System.Drawing.Size(60, 45)
$form.Controls.Add($iconLabel)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Running: 0 goose(es)"
$lblStatus.Location = New-Object System.Drawing.Point(20, 60)
$lblStatus.Size = New-Object System.Drawing.Size(200, 25)
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$lblStatus.ForeColor = [System.Drawing.Color]::Gray
$form.Controls.Add($lblStatus)

$gooseGroup = New-Object System.Windows.Forms.GroupBox
$gooseGroup.Text = "Goose Count"
$gooseGroup.Location = New-Object System.Drawing.Point(20, 95)
$gooseGroup.Size = New-Object System.Drawing.Size(400, 70)
$form.Controls.Add($gooseGroup)

$lblDesired = New-Object System.Windows.Forms.Label
$lblDesired.Text = "Number of geese:"
$lblDesired.Location = New-Object System.Drawing.Point(15, 25)
$lblDesired.Size = New-Object System.Drawing.Size(120, 25)
$lblDesired.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$gooseGroup.Controls.Add($lblDesired)

$numDesired = New-Object System.Windows.Forms.NumericUpDown
$numDesired.Location = New-Object System.Drawing.Point(140, 23)
$numDesired.Size = New-Object System.Drawing.Size(60, 25)
$numDesired.Minimum = 0
$numDesired.Maximum = 10
$numDesired.Value = 0
$numDesired.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$gooseGroup.Controls.Add($numDesired)

$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = "Apply"
$btnApply.Location = New-Object System.Drawing.Point(220, 20)
$btnApply.Size = New-Object System.Drawing.Size(80, 30)
$btnApply.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnApply.ForeColor = [System.Drawing.Color]::White
$btnApply.FlatStyle = "Flat"
$btnApply.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$gooseGroup.Controls.Add($btnApply)

$btnApply.Add_Click({
    Sync-GooseCount -desiredCount $numDesired.Value -form $form
})

$btnAddOne = New-Object System.Windows.Forms.Button
$btnAddOne.Text = "+ Add One"
$btnAddOne.Location = New-Object System.Drawing.Point(310, 20)
$btnAddOne.Size = New-Object System.Drawing.Size(75, 30)
$btnAddOne.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 80)
$btnAddOne.ForeColor = [System.Drawing.Color]::White
$btnAddOne.FlatStyle = "Flat"
$btnAddOne.Font = New-Object System.Drawing.Font("Segoe UI", 9)
$gooseGroup.Controls.Add($btnAddOne)

$btnAddOne.Add_Click({
    $current = (Get-RunningGooseCount).Count
    Sync-GooseCount -desiredCount ($current + 1) -form $form
})

$settingsGroup = New-Object System.Windows.Forms.GroupBox
$settingsGroup.Text = "Quick Settings"
$settingsGroup.Location = New-Object System.Drawing.Point(20, 175)
$settingsGroup.Size = New-Object System.Drawing.Size(400, 120)
$form.Controls.Add($settingsGroup)

$chkSilence = New-Object System.Windows.Forms.CheckBox
$chkSilence.Text = "Silence Sounds"
$chkSilence.Location = New-Object System.Drawing.Point(15, 25)
$chkSilence.Size = New-Object System.Drawing.Size(150, 20)
$chkSilence.Checked = ($config["SilenceSounds"] -eq "True")
$settingsGroup.Controls.Add($chkSilence)

$chkAttack = New-Object System.Windows.Forms.CheckBox
$chkAttack.Text = "Mouse Attack"
$chkAttack.Location = New-Object System.Drawing.Point(15, 50)
$chkAttack.Size = New-Object System.Drawing.Size(150, 20)
$chkAttack.Checked = ($config["Task_CanAttackMouse"] -eq "True")
$settingsGroup.Controls.Add($chkAttack)

$chkRandom = New-Object System.Windows.Forms.CheckBox
$chkRandom.Text = "Attack Randomly"
$chkRandom.Location = New-Object System.Drawing.Point(15, 75)
$chkRandom.Size = New-Object System.Drawing.Size(150, 20)
$chkRandom.Checked = ($config["AttackRandomly"] -eq "True")
$settingsGroup.Controls.Add($chkRandom)

$chkTimeBehavior = New-Object System.Windows.Forms.CheckBox
$chkTimeBehavior.Text = "Time-Based Behavior"
$chkTimeBehavior.Location = New-Object System.Drawing.Point(180, 25)
$chkTimeBehavior.Size = New-Object System.Drawing.Size(180, 20)
$chkTimeBehavior.Checked = ($config["TimeBasedBehavior"] -eq "True")
$settingsGroup.Controls.Add($chkTimeBehavior)

$chkContext = New-Object System.Windows.Forms.CheckBox
$chkContext.Text = "Context Awareness"
$chkContext.Location = New-Object System.Drawing.Point(180, 50)
$chkContext.Size = New-Object System.Drawing.Size(180, 20)
$chkContext.Checked = ($config["ContextAwareness"] -eq "True")
$settingsGroup.Controls.Add($chkContext)

$chkPersonality = New-Object System.Windows.Forms.CheckBox
$chkPersonality.Text = "Personality System"
$chkPersonality.Location = New-Object System.Drawing.Point(180, 75)
$chkPersonality.Size = New-Object System.Drawing.Size(180, 20)
$chkPersonality.Checked = ($config["PersonalitySystem"] -eq "True")
$settingsGroup.Controls.Add($chkPersonality)

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "Save Settings"
$btnSave.Location = New-Object System.Drawing.Point(300, 305)
$btnSave.Size = New-Object System.Drawing.Size(120, 30)
$btnSave.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 80)
$btnSave.ForeColor = [System.Drawing.Color]::White
$btnSave.FlatStyle = "Flat"
$form.Controls.Add($btnSave)

$btnSave.Add_Click({
    $config["SilenceSounds"] = $chkSilence.Checked.ToString()
    $config["Task_CanAttackMouse"] = $chkAttack.Checked.ToString()
    $config["AttackRandomly"] = $chkRandom.Checked.ToString()
    $config["TimeBasedBehavior"] = $chkTimeBehavior.Checked.ToString()
    $config["ContextAwareness"] = $chkContext.Checked.ToString()
    $config["PersonalitySystem"] = $chkPersonality.Checked.ToString()
    Save-Config -config $config
    [System.Windows.Forms.MessageBox]::Show("Settings saved successfully!", "Saved", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

$btnOpenFolder = New-Object System.Windows.Forms.Button
$btnOpenFolder.Text = "Open Folder"
$btnOpenFolder.Location = New-Object System.Drawing.Point(20, 305)
$btnOpenFolder.Size = New-Object System.Drawing.Size(100, 30)
$btnOpenFolder.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
$btnOpenFolder.ForeColor = [System.Drawing.Color]::White
$btnOpenFolder.FlatStyle = "Flat"
$form.Controls.Add($btnOpenFolder)

$btnOpenFolder.Add_Click({
    Start-Process explorer.exe -ArgumentList $scriptDir
})

$btnOpenConfig = New-Object System.Windows.Forms.Button
$btnOpenConfig.Text = "Edit Config"
$btnOpenConfig.Location = New-Object System.Drawing.Point(130, 305)
$btnOpenConfig.Size = New-Object System.Drawing.Size(100, 30)
$btnOpenConfig.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 100)
$btnOpenConfig.ForeColor = [System.Drawing.Color]::White
$btnOpenConfig.FlatStyle = "Flat"
$form.Controls.Add($btnOpenConfig)

$btnOpenConfig.Add_Click({
    Start-Process notepad.exe -ArgumentList $configPath
})

Update-Status -form $form

$form.Add_FormClosing({
    $running = Get-RunningGooseCount
    if ($running.Count -gt 0) {
        $result = [System.Windows.Forms.MessageBox]::Show("$($running.Count) goose(es) still running. Exit anyway?", "Confirm Exit", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($result -ne "Yes") {
            $_.Cancel = $true
        }
    }
})

[void]$form.ShowDialog()
