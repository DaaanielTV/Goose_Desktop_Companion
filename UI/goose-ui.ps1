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

function Launch-FeatureScript {
    param([string]$ScriptPath, [string]$ScriptName)
    if (Test-Path $ScriptPath) {
        Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -File `"$ScriptPath`""
        return $true
    } else {
        [System.Windows.Forms.MessageBox]::Show("$ScriptName script not found!", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return $false
    }
}

function Create-FeatureButton {
    param(
        [string]$Text,
        [string]$ScriptPath,
        [string]$Description,
        [System.Windows.Forms.Panel]$ParentPanel,
        [int]$X,
        [int]$Y,
        [int]$Width = 140,
        [int]$Height = 60
    )
    
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $Text
    $btn.Location = New-Object System.Drawing.Point($X, $Y)
    $btn.Size = New-Object System.Drawing.Size($Width, $Height)
    $btn.FlatStyle = "Flat"
    $btn.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 75)
    $btn.ForeColor = [System.Drawing.Color]::White
    $btn.Font = New-Object System.Drawing.Font("Segoe UI", 9)
    $btn.TextAlign = "TopLeft"
    $btn.Padding = New-Object System.Windows.Forms.Padding(5)
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    
    $btn.Add_MouseEnter({
        $this.BackColor = [System.Drawing.Color]::FromArgb(90, 90, 95)
    })
    $btn.Add_MouseLeave({
        $this.BackColor = [System.Drawing.Color]::FromArgb(70, 70, 75)
    })
    
    $btn.Add_Click({
        if ($ScriptPath -ne "") {
            Launch-FeatureScript -ScriptPath $ScriptPath -ScriptName $this.Text
        }
    })
    
    $ParentPanel.Controls.Add($btn)
    return $btn
}

function Create-SectionLabel {
    param(
        [string]$Text,
        [System.Windows.Forms.Panel]$ParentPanel,
        [int]$X,
        [int]$Y
    )
    
    $lbl = New-Object System.Windows.Forms.Label
    $lbl.Text = $Text
    $lbl.Location = New-Object System.Drawing.Point($X, $Y)
    $lbl.Size = New-Object System.Drawing.Size(200, 20)
    $lbl.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $lbl.ForeColor = [System.Drawing.Color]::FromArgb(220, 220, 225)
    $ParentPanel.Controls.Add($lbl)
    return $lbl
}

$config = Load-Config

$form = New-Object System.Windows.Forms.Form
$form.Text = "Desktop Goose Control Center"
$form.Size = New-Object System.Drawing.Size(950, 700)
$form.StartPosition = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)

$tabControl = New-Object System.Windows.Forms.TabControl
$tabControl.Location = New-Object System.Drawing.Point(10, 10)
$tabControl.Size = New-Object System.Drawing.Size(920, 640)
$tabControl.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$form.Controls.Add($tabControl)

$tabHome = New-Object System.Windows.Forms.TabPage
$tabHome.Text = "Home"
$tabHome.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$tabControl.TabPages.Add($tabHome)

$tabProductivity = New-Object System.Windows.Forms.TabPage
$tabProductivity.Text = "Productivity"
$tabProductivity.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$tabControl.TabPages.Add($tabProductivity)

$tabHealth = New-Object System.Windows.Forms.TabPage
$tabHealth.Text = "Health"
$tabHealth.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$tabControl.TabPages.Add($tabHealth)

$tabFun = New-Object System.Windows.Forms.TabPage
$tabFun.Text = "Fun"
$tabFun.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$tabControl.TabPages.Add($tabFun)

$tabSystem = New-Object System.Windows.Forms.TabPage
$tabSystem.Text = "System"
$tabSystem.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$tabControl.TabPages.Add($tabSystem)

$tabWidgets = New-Object System.Windows.Forms.TabPage
$tabWidgets.Text = "Widgets"
$tabWidgets.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$tabControl.TabPages.Add($tabWidgets)

$tabSocial = New-Object System.Windows.Forms.TabPage
$tabSocial.Text = "Social"
$tabSocial.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$tabControl.TabPages.Add($tabSocial)

$tabScripts = New-Object System.Windows.Forms.TabPage
$tabScripts.Text = "Scripts"
$tabScripts.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$tabControl.TabPages.Add($tabScripts)

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Desktop Goose Control Center"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 20, [System.Drawing.FontStyle]::Bold)
$titleLabel.Location = New-Object System.Drawing.Point(20, 20)
$titleLabel.Size = New-Object System.Drawing.Size(400, 40)
$titleLabel.ForeColor = [System.Drawing.Color]::White
$tabHome.Controls.Add($titleLabel)

$iconLabel = New-Object System.Windows.Forms.Label
$iconLabel.Text = "🦆"
$iconLabel.Font = New-Object System.Drawing.Font("Segoe UI", 40)
$iconLabel.Location = New-Object System.Drawing.Point(800, 10)
$iconLabel.Size = New-Object System.Drawing.Size(80, 60)
$iconLabel.ForeColor = [System.Drawing.Color]::White
$tabHome.Controls.Add($iconLabel)

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Text = "Running: 0 goose(es)"
$lblStatus.Location = New-Object System.Drawing.Point(20, 70)
$lblStatus.Size = New-Object System.Drawing.Size(200, 25)
$lblStatus.Font = New-Object System.Drawing.Font("Segoe UI", 12)
$lblStatus.ForeColor = [System.Drawing.Color]::Gray
$tabHome.Controls.Add($lblStatus)

$gooseGroup = New-Object System.Windows.Forms.GroupBox
$gooseGroup.Text = "Goose Count"
$gooseGroup.Location = New-Object System.Drawing.Point(20, 110)
$gooseGroup.Size = New-Object System.Drawing.Size(400, 80)
$gooseGroup.ForeColor = [System.Drawing.Color]::White
$gooseGroup.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
$tabHome.Controls.Add($gooseGroup)

$lblDesired = New-Object System.Windows.Forms.Label
$lblDesired.Text = "Number of geese:"
$lblDesired.Location = New-Object System.Drawing.Point(15, 30)
$lblDesired.Size = New-Object System.Drawing.Size(120, 25)
$lblDesired.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$lblDesired.ForeColor = [System.Drawing.Color]::White
$gooseGroup.Controls.Add($lblDesired)

$numDesired = New-Object System.Windows.Forms.NumericUpDown
$numDesired.Location = New-Object System.Drawing.Point(140, 28)
$numDesired.Size = New-Object System.Drawing.Size(60, 25)
$numDesired.Minimum = 0
$numDesired.Maximum = 10
$numDesired.Value = 0
$numDesired.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$gooseGroup.Controls.Add($numDesired)

$btnApply = New-Object System.Windows.Forms.Button
$btnApply.Text = "Apply"
$btnApply.Location = New-Object System.Drawing.Point(220, 25)
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
$btnAddOne.Location = New-Object System.Drawing.Point(310, 25)
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
$settingsGroup.Location = New-Object System.Drawing.Point(20, 200)
$settingsGroup.Size = New-Object System.Drawing.Size(400, 150)
$settingsGroup.ForeColor = [System.Drawing.Color]::White
$settingsGroup.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
$tabHome.Controls.Add($settingsGroup)

$chkSilence = New-Object System.Windows.Forms.CheckBox
$chkSilence.Text = "Silence Sounds"
$chkSilence.Location = New-Object System.Drawing.Point(15, 30)
$chkSilence.Size = New-Object System.Drawing.Size(150, 20)
$chkSilence.ForeColor = [System.Drawing.Color]::White
$chkSilence.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
$chkSilence.Checked = ($config["SilenceSounds"] -eq "True")
$settingsGroup.Controls.Add($chkSilence)

$chkAttack = New-Object System.Windows.Forms.CheckBox
$chkAttack.Text = "Mouse Attack"
$chkAttack.Location = New-Object System.Drawing.Point(15, 55)
$chkAttack.Size = New-Object System.Drawing.Size(150, 20)
$chkAttack.ForeColor = [System.Drawing.Color]::White
$chkAttack.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
$chkAttack.Checked = ($config["Task_CanAttackMouse"] -eq "True")
$settingsGroup.Controls.Add($chkAttack)

$chkRandom = New-Object System.Windows.Forms.CheckBox
$chkRandom.Text = "Attack Randomly"
$chkRandom.Location = New-Object System.Drawing.Point(15, 80)
$chkRandom.Size = New-Object System.Drawing.Size(150, 20)
$chkRandom.ForeColor = [System.Drawing.Color]::White
$chkRandom.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
$chkRandom.Checked = ($config["AttackRandomly"] -eq "True")
$settingsGroup.Controls.Add($chkRandom)

$chkTimeBehavior = New-Object System.Windows.Forms.CheckBox
$chkTimeBehavior.Text = "Time-Based Behavior"
$chkTimeBehavior.Location = New-Object System.Drawing.Point(180, 30)
$chkTimeBehavior.Size = New-Object System.Drawing.Size(180, 20)
$chkTimeBehavior.ForeColor = [System.Drawing.Color]::White
$chkTimeBehavior.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
$chkTimeBehavior.Checked = ($config["TimeBasedBehavior"] -eq "True")
$settingsGroup.Controls.Add($chkTimeBehavior)

$chkContext = New-Object System.Windows.Forms.CheckBox
$chkContext.Text = "Context Awareness"
$chkContext.Location = New-Object System.Drawing.Point(180, 55)
$chkContext.Size = New-Object System.Drawing.Size(180, 20)
$chkContext.ForeColor = [System.Drawing.Color]::White
$chkContext.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
$chkContext.Checked = ($config["ContextAwareness"] -eq "True")
$settingsGroup.Controls.Add($chkContext)

$chkPersonality = New-Object System.Windows.Forms.CheckBox
$chkPersonality.Text = "Personality System"
$chkPersonality.Location = New-Object System.Drawing.Point(180, 80)
$chkPersonality.Size = New-Object System.Drawing.Size(180, 20)
$chkPersonality.ForeColor = [System.Drawing.Color]::White
$chkPersonality.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
$chkPersonality.Checked = ($config["PersonalitySystem"] -eq "True")
$settingsGroup.Controls.Add($chkPersonality)

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "Save Settings"
$btnSave.Location = New-Object System.Drawing.Point(300, 360)
$btnSave.Size = New-Object System.Drawing.Size(120, 35)
$btnSave.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 80)
$btnSave.ForeColor = [System.Drawing.Color]::White
$btnSave.FlatStyle = "Flat"
$tabHome.Controls.Add($btnSave)

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
$btnOpenFolder.Location = New-Object System.Drawing.Point(20, 360)
$btnOpenFolder.Size = New-Object System.Drawing.Size(100, 35)
$btnOpenFolder.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 105)
$btnOpenFolder.ForeColor = [System.Drawing.Color]::White
$btnOpenFolder.FlatStyle = "Flat"
$tabHome.Controls.Add($btnOpenFolder)

$btnOpenFolder.Add_Click({
    Start-Process explorer.exe -ArgumentList $scriptDir
})

$btnOpenConfig = New-Object System.Windows.Forms.Button
$btnOpenConfig.Text = "Edit Config"
$btnOpenConfig.Location = New-Object System.Drawing.Point(130, 360)
$btnOpenConfig.Size = New-Object System.Drawing.Size(100, 35)
$btnOpenConfig.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 105)
$btnOpenConfig.ForeColor = [System.Drawing.Color]::White
$btnOpenConfig.FlatStyle = "Flat"
$tabHome.Controls.Add($btnOpenConfig)

$btnOpenConfig.Add_Click({
    Start-Process notepad.exe -ArgumentList $configPath
})

$btnOpenStats = New-Object System.Windows.Forms.Button
$btnOpenStats.Text = "Stats Dashboard"
$btnOpenStats.Location = New-Object System.Drawing.Point(440, 110)
$btnOpenStats.Size = New-Object System.Drawing.Size(140, 50)
$btnOpenStats.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnOpenStats.ForeColor = [System.Drawing.Color]::White
$btnOpenStats.FlatStyle = "Flat"
$btnOpenStats.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$tabHome.Controls.Add($btnOpenStats)

$btnOpenStats.Add_Click({
    Launch-FeatureScript -ScriptPath (Join-Path $scriptDir "goose-stats.ps1") -ScriptName "Stats Dashboard"
})

$btnOpenTray = New-Object System.Windows.Forms.Button
$btnOpenTray.Text = "System Tray"
$btnOpenTray.Location = New-Object System.Drawing.Point(440, 170)
$btnOpenTray.Size = New-Object System.Drawing.Size(140, 50)
$btnOpenTray.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 105)
$btnOpenTray.ForeColor = [System.Drawing.Color]::White
$btnOpenTray.FlatStyle = "Flat"
$btnOpenTray.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$tabHome.Controls.Add($btnOpenTray)

$btnOpenTray.Add_Click({
    Launch-FeatureScript -ScriptPath (Join-Path $scriptDir "goose-tray.ps1") -ScriptName "System Tray"
})

$lblQuickStart = New-Object System.Windows.Forms.Label
$lblQuickStart.Text = "Quick Start Features"
$lblQuickStart.Location = New-Object System.Drawing.Point(440, 240)
$lblQuickStart.Size = New-Object System.Drawing.Size(200, 25)
$lblQuickStart.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
$lblQuickStart.ForeColor = [System.Drawing.Color]::White
$tabHome.Controls.Add($lblQuickStart)

$quickFeatures = @(
    @{Name="Notes"; Path=(Join-Path $scriptDir "..\Productivity\goose-notes.ps1")},
    @{Name="Tasks"; Path=(Join-Path $scriptDir "..\Productivity\goose-tasks.ps1")},
    @{Name="Pomodoro"; Path=(Join-Path $scriptDir "..\Productivity\goose-pomodoro.ps1")},
    @{Name="Focus Mode"; Path=(Join-Path $scriptDir "..\Productivity\goose-focus.ps1")},
    @{Name="Habits"; Path=(Join-Path $scriptDir "..\Health\goose-habits.ps1")},
    @{Name="Commands"; Path=(Join-Path $scriptDir "..\Fun\goose-commands.ps1")}
)

$btnX = 440
$btnY = 275
for ($i = 0; $i -lt $quickFeatures.Count; $i++) {
    $feat = $quickFeatures[$i]
    $btn = Create-FeatureButton -Text $feat.Name -ScriptPath $feat.Path -Description "" -ParentPanel $tabHome -X $btnX -Y $btnY
    $btnX += 150
    if (($i + 1) % 3 -eq 0) {
        $btnX = 440
        $btnY += 70
    }
}

Create-SectionLabel -Text "Productivity Features" -ParentPanel $tabProductivity -X 20 -Y 20

$productivityFeatures = @(
    @{Name="Notes"; Path=(Join-Path $scriptDir "..\Productivity\goose-notes.ps1"); Desc="Create and manage sticky notes"},
    @{Name="Tasks"; Path=(Join-Path $scriptDir "..\Productivity\goose-tasks.ps1"); Desc="Task management system"},
    @{Name="Pomodoro"; Path=(Join-Path $scriptDir "..\Productivity\goose-pomodoro.ps1"); Desc="Focus timer with breaks"},
    @{Name="Focus Mode"; Path=(Join-Path $scriptDir "..\Productivity\goose-focus.ps1"); Desc="Distraction-free focus periods"},
    @{Name="Focus Companion"; Path=(Join-Path $scriptDir "..\Productivity\goose-focus-companion.ps1"); Desc="Active focus session partner"},
    @{Name="Quick Notes"; Path=(Join-Path $scriptDir "..\Productivity\goose-quick-notes.ps1"); Desc="Desktop note overlay"},
    @{Name="Time Tracking"; Path=(Join-Path $scriptDir "..\Productivity\goose-timetracking.ps1"); Desc="Track your work time"},
    @{Name="Time Blocks"; Path=(Join-Path $scriptDir "..\Productivity\goose-timeblock.ps1"); Desc="Schedule time blocks"},
    @{Name="AI Chat"; Path=(Join-Path $scriptDir "..\Productivity\goose-aichat.ps1"); Desc="Chat with AI assistant"},
    @{Name="AI Assistant"; Path=(Join-Path $scriptDir "..\Productivity\goose-aiassistant.ps1"); Desc="Code and productivity help"},
    @{Name="Task Integration"; Path=(Join-Path $scriptDir "..\Productivity\goose-taskintegration.ps1"); Desc="Sync with task apps"}
)

$px = 20
$py = 50
for ($i = 0; $i -lt $productivityFeatures.Count; $i++) {
    $feat = $productivityFeatures[$i]
    $btn = Create-FeatureButton -Text "$($feat.Name)`n$($feat.Desc)" -ScriptPath $feat.Path -Description $feat.Desc -ParentPanel $tabProductivity -X $px -Y $py -Height 70
    $px += 150
    if (($i + 1) % 5 -eq 0) {
        $px = 20
        $py += 80
    }
}

Create-SectionLabel -Text "Health & Wellness" -ParentPanel $tabHealth -X 20 -Y 20

$healthFeatures = @(
    @{Name="Habit Tracker"; Path=(Join-Path $scriptDir "..\Health\goose-habits.ps1"); Desc="Track daily habits and goals"},
    @{Name="Posture Check"; Path=(Join-Path $scriptDir "..\Health\goose-posture.ps1"); Desc="Posture reminder system"},
    @{Name="Eye Strain"; Path=(Join-Path $scriptDir "..\Health\goose-eyestrain.ps1"); Desc="20-20-20 eye reminders"},
    @{Name="Screen Time"; Path=(Join-Path $scriptDir "..\Health\goose-screentime.ps1"); Desc="Monitor screen usage"},
    @{Name="Learning XP"; Path=(Join-Path $scriptDir "..\Health\goose-learning.ps1"); Desc="Track learning progress"},
    @{Name="Daily Goals"; Path=(Join-Path $scriptDir "..\Health\goose-dailygoals.ps1"); Desc="Set and track daily goals"},
    @{Name="Workout Reminders"; Path=(Join-Path $scriptDir "..\Health\goose-workout.ps1"); Desc="Exercise reminders"}
)

$hx = 20
$hy = 50
for ($i = 0; $i -lt $healthFeatures.Count; $i++) {
    $feat = $healthFeatures[$i]
    $btn = Create-FeatureButton -Text "$($feat.Name)`n$($feat.Desc)" -ScriptPath $feat.Path -Description $feat.Desc -ParentPanel $tabHealth -X $hx -Y $hy -Height 70
    $hx += 150
    if (($i + 1) % 5 -eq 0) {
        $hx = 20
        $hy += 80
    }
}

Create-SectionLabel -Text "Fun & Entertainment" -ParentPanel $tabFun -X 20 -Y 20

$funFeatures = @(
    @{Name="Commands"; Path=(Join-Path $scriptDir "..\Fun\goose-commands.ps1"); Desc="Interactive goose commands"},
    @{Name="Mini Games"; Path=(Join-Path $scriptDir "..\Fun\goose-minigames.ps1"); Desc="Play games with goose"},
    @{Name="Extended Games"; Path=(Join-Path $scriptDir "..\Fun\goose-games-extended.ps1"); Desc="More mini games"},
    @{Name="AR Mode"; Path=(Join-Path $scriptDir "..\Fun\goose-armode.ps1"); Desc="Augmented reality features"},
    @{Name="App Reactions"; Path=(Join-Path $scriptDir "..\Fun\goose-appreactions.ps1"); Desc="Goose reacts to apps"},
    @{Name="Mood System"; Path=(Join-Path $scriptDir "..\Fun\goose-mood.ps1"); Desc="Goose emotional states"},
    @{Name="System Mood"; Path=(Join-Path $scriptDir "..\Fun\goose-systemmood.ps1"); Desc="Context-aware mood"},
    @{Name="Skins"; Path=(Join-Path $scriptDir "..\Fun\goose-skins.ps1"); Desc="Customize goose appearance"},
    @{Name="Honk"; Path=(Join-Path $scriptDir "..\Fun\goose-honk.ps1"); Desc="Make the goose honk"},
    @{Name="Easter Eggs"; Path=(Join-Path $scriptDir "..\Fun\goose-eastereggs.ps1"); Desc="Hidden surprises"},
    @{Name="Streamer Mode"; Path=(Join-Path $scriptDir "..\Fun\goose-streamer.ps1"); Desc="Streaming overlays"},
    @{Name="Code Assistant"; Path=(Join-Path $scriptDir "..\Fun\goose-codeassistant.ps1"); Desc="Programming help"},
    @{Name="Desktop Capture"; Path=(Join-Path $scriptDir "..\Media\goose-capture.ps1"); Desc="Screenshot with annotations"},
    @{Name="Goose Memory"; Path=(Join-Path $scriptDir "..\System\goose-memory.ps1"); Desc="Persistent interaction memory"}
)

$fx = 20
$fy = 50
for ($i = 0; $i -lt $funFeatures.Count; $i++) {
    $feat = $funFeatures[$i]
    $btn = Create-FeatureButton -Text "$($feat.Name)`n$($feat.Desc)" -ScriptPath $feat.Path -Description $feat.Desc -ParentPanel $tabFun -X $fx -Y $fy -Height 70
    $fx += 150
    if (($i + 1) % 5 -eq 0) {
        $fx = 20
        $fy += 80
    }
}

Create-SectionLabel -Text "System Tools" -ParentPanel $tabSystem -X 20 -Y 20

$systemFeatures = @(
    @{Name="Clipboard Manager"; Path=(Join-Path $scriptDir "..\System\goose-clipboard.ps1"); Desc="Enhanced clipboard history"},
    @{Name="Volume Control"; Path=(Join-Path $scriptDir "..\System\goose-volume.ps1"); Desc="System volume management"},
    @{Name="Battery Status"; Path=(Join-Path $scriptDir "..\System\goose-battery.ps1"); Desc="Battery monitoring"},
    @{Name="Battery Saver"; Path=(Join-Path $scriptDir "..\System\goose-batterysaver.ps1"); Desc="Power saving mode"},
    @{Name="System Info"; Path=(Join-Path $scriptDir "..\System\goose-sysinfo.ps1"); Desc="System information display"},
    @{Name="Noise Detection"; Path=(Join-Path $scriptDir "..\System\goose-noise.ps1"); Desc="Background noise alerts"},
    @{Name="File Organizer"; Path=(Join-Path $scriptDir "..\System\goose-fileorganizer.ps1"); Desc="Organize files automatically"},
    @{Name="Automation Hub"; Path=(Join-Path $scriptDir "..\System\goose-automation.ps1"); Desc="Workflow automation"},
    @{Name="Plugin Marketplace"; Path=(Join-Path $scriptDir "..\System\goose-marketplace.ps1"); Desc="Browse plugins"},
    @{Name="Plugin API"; Path=(Join-Path $scriptDir "..\System\goose-pluginapi.ps1"); Desc="Developer API"},
    @{Name="Notifications"; Path=(Join-Path $scriptDir "..\System\goose-notifications.ps1"); Desc="Notification system"},
    @{Name="Telemetry"; Path=(Join-Path $scriptDir "..\System\goose-telemetry.ps1"); Desc="Usage analytics"},
    @{Name="Voice Commands"; Path=(Join-Path $scriptDir "..\System\goose-voice.ps1"); Desc="Speech recognition"},
    @{Name="Smart Notifications"; Path=(Join-Path $scriptDir "..\System\goose-smart-notifications.ps1"); Desc="Smart notification dashboard"},
    @{Name="Window Manager"; Path=(Join-Path $scriptDir "..\System\goose-window-manager.ps1"); Desc="Window organization"},
    @{Name="Script Hub"; Path=(Join-Path $scriptDir "..\System\goose-script-hub.ps1"); Desc="PowerShell script manager"}
)

$sx = 20
$sy = 50
for ($i = 0; $i -lt $systemFeatures.Count; $i++) {
    $feat = $systemFeatures[$i]
    $btn = Create-FeatureButton -Text "$($feat.Name)`n$($feat.Desc)" -ScriptPath $feat.Path -Description $feat.Desc -ParentPanel $tabSystem -X $sx -Y $sy -Height 70
    $sx += 150
    if (($i + 1) % 5 -eq 0) {
        $sx = 20
        $sy += 80
    }
}

Create-SectionLabel -Text "Widgets" -ParentPanel $tabWidgets -X 20 -Y 20

$widgetFeatures = @(
    @{Name="Calendar"; Path=(Join-Path $scriptDir "..\Widgets\goose-calendar.ps1"); Desc="Calendar widget"},
    @{Name="Clock"; Path=(Join-Path $scriptDir "..\Widgets\goose-clockwidget.ps1"); Desc="Digital clock widget"},
    @{Name="Weather"; Path=(Join-Path $scriptDir "..\Widgets\goose-weatherwidget.ps1"); Desc="Weather information"},
    @{Name="Stock Ticker"; Path=(Join-Path $scriptDir "..\Widgets\goose-stockticker.ps1"); Desc="Stock price display"},
    @{Name="Countdown"; Path=(Join-Path $scriptDir "..\Widgets\goose-countdown.ps1"); Desc="Countdown timer"},
    @{Name="Quotes"; Path=(Join-Path $scriptDir "..\Widgets\goose-quotes.ps1"); Desc="Inspirational quotes"},
    @{Name="Daily Briefing"; Path=(Join-Path $scriptDir "..\Widgets\goose-daily-briefing.ps1"); Desc="Morning summary widget"},
    @{Name="Calendar (Features)"; Path=(Join-Path $scriptDir "..\Features\goose-calendar.ps1"); Desc="Full calendar feature"}
)

$wx = 20
$wy = 50
for ($i = 0; $i -lt $widgetFeatures.Count; $i++) {
    $feat = $widgetFeatures[$i]
    $btn = Create-FeatureButton -Text "$($feat.Name)`n$($feat.Desc)" -ScriptPath $feat.Path -Description $feat.Desc -ParentPanel $tabWidgets -X $wx -Y $wy -Height 70
    $wx += 150
    if (($i + 1) % 5 -eq 0) {
        $wx = 20
        $wy += 80
    }
}

Create-SectionLabel -Text "Social & Gamification" -ParentPanel $tabSocial -X 20 -Y 20

$socialFeatures = @(
    @{Name="RPG System"; Path=(Join-Path $scriptDir "..\Social\goose-rpg.ps1"); Desc="Level up your goose"},
    @{Name="Gamification"; Path=(Join-Path $scriptDir "..\Social\goose-gamification.ps1"); Desc="Points and rewards"},
    @{Name="Achievements"; Path=(Join-Path $scriptDir "..\Social\goose-achievements.ps1"); Desc="Unlock achievements"},
    @{Name="Leaderboard"; Path=(Join-Path $scriptDir "..\Social\goose-leaderboard.ps1"); Desc="Compare with others"},
    @{Name="Multiplayer"; Path=(Join-Path $scriptDir "..\Social\goose-multiplayer.ps1"); Desc="Multiple goose owners"},
    @{Name="Multi-Goose"; Path=(Join-Path $scriptDir "..\Social\goose-multigoose.ps1"); Desc="Multiple geese mode"},
    @{Name="Multi-Pet"; Path=(Join-Path $scriptDir "..\Social\goose-multipet.ps1"); Desc="Multiple pet types"},
    @{Name="Pet Interactions"; Path=(Join-Path $scriptDir "..\Social\goose-petinteractions.ps1"); Desc="Pet-to-pet interactions"},
    @{Name="Inspiration"; Path=(Join-Path $scriptDir "..\Social\goose-inspiration.ps1"); Desc="Motivational quotes"},
    @{Name="Kindness"; Path=(Join-Path $scriptDir "..\Social\goose-kindness.ps1"); Desc="Random acts of kindness"}
)

$sox = 20
$soy = 50
for ($i = 0; $i -lt $socialFeatures.Count; $i++) {
    $feat = $socialFeatures[$i]
    $btn = Create-FeatureButton -Text "$($feat.Name)`n$($feat.Desc)" -ScriptPath $feat.Path -Description $feat.Desc -ParentPanel $tabSocial -X $sox -Y $soy -Height 70
    $sox += 150
    if (($i + 1) % 5 -eq 0) {
        $sox = 20
        $soy += 80
    }
}

Create-SectionLabel -Text "PowerShell Script Hub" -ParentPanel $tabScripts -X 20 -Y 20

$scriptLabel = New-Object System.Windows.Forms.Label
$scriptLabel.Text = "Create, manage and execute custom PowerShell scripts"
$scriptLabel.Location = New-Object System.Drawing.Point(20, 50)
$scriptLabel.Size = New-Object System.Drawing.Size(400, 20)
$scriptLabel.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 185)
$tabScripts.Controls.Add($scriptLabel)

$btnOpenScriptHub = New-Object System.Windows.Forms.Button
$btnOpenScriptHub.Text = "Open Script Hub"
$btnOpenScriptHub.Location = New-Object System.Drawing.Point(20, 80)
$btnOpenScriptHub.Size = New-Object System.Drawing.Size(180, 50)
$btnOpenScriptHub.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnOpenScriptHub.ForeColor = [System.Drawing.Color]::White
$btnOpenScriptHub.FlatStyle = "Flat"
$btnOpenScriptHub.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$btnOpenScriptHub.Add_Click({
    Launch-FeatureScript -ScriptPath (Join-Path $scriptDir "..\System\goose-script-hub.ps1") -ScriptName "Script Hub"
})
$tabScripts.Controls.Add($btnOpenScriptHub)

Create-SectionLabel -Text "Script Categories" -ParentPanel $tabScripts -X 20 -Y 150

$scriptCategories = @(
    @{Name="Custom Scripts"; Path=(Join-Path $scriptDir "..\System\goose-script-hub.ps1"); Desc="Your custom scripts"},
    @{Name="Script Templates"; Path=(Join-Path $scriptDir "..\System\goose-script-hub.ps1"); Desc="Ready-to-use templates"},
    @{Name="Script History"; Path=(Join-Path $scriptDir "..\System\goose-script-hub.ps1"); Desc="Recent executions"},
    @{Name="Import Script"; Path=(Join-Path $scriptDir "..\System\goose-script-hub.ps1"); Desc="Import from file"},
    @{Name="Export Scripts"; Path=(Join-Path $scriptDir "..\System\goose-script-hub.ps1"); Desc="Export all scripts"}
)

$scx = 20
$scy = 180
for ($i = 0; $i -lt $scriptCategories.Count; $i++) {
    $feat = $scriptCategories[$i]
    $btn = Create-FeatureButton -Text "$($feat.Name)" -ScriptPath $feat.Path -Description $feat.Desc -ParentPanel $tabScripts -X $scx -Y $scy -Width 180 -Height 60
    $scx += 190
    if (($i + 1) % 4 -eq 0) {
        $scx = 20
        $scy += 70
    }
}

Create-SectionLabel -Text "Quick Scripts" -ParentPanel $tabScripts -X 20 -Y 320

$quickScripts = @(
    @{Name="List Files"; Script='Get-ChildItem | Select-Object Name, Length, LastWriteTime | Format-Table'},
    @{Name="System Info"; Script='Get-ComputerInfo | Select-Object CsName, WindowsVersion, OsArchitecture | Format-List'},
    @{Name="Running Processes"; Script='Get-Process | Sort-Object CPU -Descending | Select-Object -First 10 | Format-Table Name, CPU, WorkingSet'},
    @{Name="Network Status"; Script='Get-NetIPAddress | Where-Object AddressFamily -eq "IPv4" | Select-Object InterfaceAlias, IPAddress'}
)

$qsx = 20
$qsy = 350
foreach ($qs in $quickScripts) {
    $qsPanel = New-Object System.Windows.Forms.Panel
    $qsPanel.Location = New-Object System.Drawing.Point($qsx, $qsy)
    $qsPanel.Size = New-Object System.Drawing.Size(200, 80)
    $qsPanel.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
    $qsPanel.BorderStyle = "FixedSingle"
    
    $qsLabel = New-Object System.Windows.Forms.Label
    $qsLabel.Text = $qs.Name
    $qsLabel.Location = New-Object System.Drawing.Point(10, 10)
    $qsLabel.Size = New-Object System.Drawing.Size(180, 20)
    $qsLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
    $qsLabel.ForeColor = [System.Drawing.Color]::White
    $qsPanel.Controls.Add($qsLabel)
    
    $qsBtn = New-Object System.Windows.Forms.Button
    $qsBtn.Text = "Run"
    $qsBtn.Location = New-Object System.Drawing.Point(10, 40)
    $qsBtn.Size = New-Object System.Drawing.Size(80, 30)
    $qsBtn.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 80)
    $qsBtn.ForeColor = [System.Drawing.Color]::White
    $qsBtn.FlatStyle = "Flat"
    $qsBtn.Add_Click({
        Start-Process powershell -ArgumentList "-Command `"$($qs.Script)`""
    })
    $qsPanel.Controls.Add($qsBtn)
    
    $qsEditBtn = New-Object System.Windows.Forms.Button
    $qsEditBtn.Text = "Edit"
    $qsEditBtn.Location = New-Object System.Drawing.Point(100, 40)
    $qsEditBtn.Size = New-Object System.Drawing.Size(80, 30)
    $qsEditBtn.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
    $qsEditBtn.ForeColor = [System.Drawing.Color]::White
    $qsEditBtn.FlatStyle = "Flat"
    $qsPanel.Controls.Add($qsEditBtn)
    
    $tabScripts.Controls.Add($qsPanel)
    $qsx += 210
    if ($qsx -gt 800) {
        $qsx = 20
        $qsy += 90
    }
}

Create-SectionLabel -Text "Additional Features" -ParentPanel $tabHome -X 440 -Y 400

$additionalFeatures = @(
    @{Name="Sync"; Path=(Join-Path $scriptDir "..\Features\goose-sync.ps1"); Desc="Cloud synchronization"},
    @{Name="Hotkeys"; Path=(Join-Path $scriptDir "..\Features\goose-hotkeys.ps1"); Desc="Global hotkey commands"},
    @{Name="Launcher"; Path=(Join-Path $scriptDir "..\Features\goose-launcher.ps1"); Desc="Quick app launcher"},
    @{Name="Quick Actions"; Path=(Join-Path $scriptDir "..\Features\goose-quickactions.ps1"); Desc="Right-click menu"},
    @{Name="Auto Start"; Path=(Join-Path $scriptDir "..\Features\goose-autostart.ps1"); Desc="Windows auto-start"},
    @{Name="Settings"; Path=(Join-Path $scriptDir "..\Features\goose-settings.ps1"); Desc="Import/export settings"},
    @{Name="Custom Commands"; Path=(Join-Path $scriptDir "..\Features\goose-customcommands.ps1"); Desc="Create custom commands"},
    @{Name="Stickies"; Path=(Join-Path $scriptDir "..\Office\goose-stickies.ps1"); Desc="Office sticky notes"},
    @{Name="Meeting"; Path=(Join-Path $scriptDir "..\Office\goose-meeting.ps1"); Desc="Meeting integration"},
    @{Name="Journal"; Path=(Join-Path $scriptDir "..\Office\goose-journal.ps1"); Desc="Daily journal"}
)

$ax = 440
$ay = 430
for ($i = 0; $i -lt $additionalFeatures.Count; $i++) {
    $feat = $additionalFeatures[$i]
    $btn = Create-FeatureButton -Text "$($feat.Name)" -ScriptPath $feat.Path -Description $feat.Desc -ParentPanel $tabHome -X $ax -Y $ay -Width 140 -Height 50
    $ax += 150
    if (($i + 1) % 3 -eq 0) {
        $ax = 440
        $ay += 60
    }
}

$form.Add_FormClosing({
    $running = Get-RunningGooseCount
    if ($running.Count -gt 0) {
        $result = [System.Windows.Forms.MessageBox]::Show("$($running.Count) goose(es) still running. Exit anyway?", "Confirm Exit", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($result -ne "Yes") {
            $_.Cancel = $true
        }
    }
})

Update-Status -form $form

[void]$form.ShowDialog()
