class GooseAchievements {
    [hashtable]$Config
    [string]$DataPath
    [object]$Telemetry
    [array]$Achievements
    [hashtable]$UnlockedAchievements
    [int]$TotalPoints
    
    GooseAchievements([string]$configFile = "config.ini", [object]$telemetry = $null) {
        $this.Telemetry = $telemetry
        $this.LoadConfig($configFile)
        $this.DataPath = Join-Path $PSScriptRoot "achievements_data"
        if (-not (Test-Path $this.DataPath)) {
            New-Item -ItemType Directory -Path $this.DataPath -Force | Out-Null
        }
        $this.Achievements = $this.InitializeAchievements()
        $this.UnlockedAchievements = @{}
        $this.TotalPoints = 0
        $this.LoadProgress()
    }
    
    [void] LoadConfig([string]$configFile) {
        $this.Config = @{
            Enabled = $true
            ShowNotifications = $true
            PlaySound = $false
            PointsMultiplier = 1.0
        }
        if (Test-Path $configFile) {
            Get-Content $configFile | ForEach-Object {
                if ($_ -match '^([^=]+)=(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    if ($this.Config.ContainsKey($key)) {
                        if ($value -eq 'True' -or $value -eq 'False') {
                            $this.Config[$key] = [bool]$value
                        } elseif ($value -match '^\d+\.?\d*$') {
                            $this.Config[$key] = [double]$value
                        } else {
                            $this.Config[$key] = $value
                        }
                    }
                }
            }
        }
    }
    
    [array] InitializeAchievements() {
        return @(
            @{id="first_honk"; name="First Honk"; description="Make the goose honk"; icon="🦆"; points=10; category="basic"},
            @{id="honk_master"; name="Honk Master"; description="Honk 50 times"; icon="📯"; points=50; category="basic"},
            @{id="first_screenshot"; name="Snappy Goose"; description="Take your first screenshot"; icon="📸"; points=15; category="productivity"},
            @{id="screenshot_pro"; name="Screenshot Pro"; description="Take 100 screenshots"; icon="🎬"; points=100; category="productivity"},
            @{id="focus_rookie"; name="Focus Rookie"; description="Complete first focus session"; icon="🎯"; points=20; category="productivity"},
            @{id="focus_master"; name="Focus Master"; description="Complete 50 focus sessions"; icon="🧘"; points=150; category="productivity"},
            @{id="note_taker"; name="Note Taker"; description="Create 10 notes"; icon="📝"; points=30; category="productivity"},
            @{id="organized"; name="Organized"; description="Create 5 window presets"; icon="🗂️"; points=40; category="productivity"},
            @{id="first_dance"; name="Dance Machine"; description="Make the goose dance"; icon="💃"; points=10; category="fun"},
            @{id="joke_teller"; name="Comedy Goose"; description="Hear 10 jokes"; icon="😄"; points=30; category="fun"},
            @{id="voice_user"; name="Voice Activated"; description="Use voice commands"; icon="🎤"; points=25; category="fun"},
            @{id="early_bird"; name="Early Bird"; description="Use Goose before 7 AM"; icon="🐦"; points=15; category="special"},
            @{id="night_owl"; name="Night Owl"; description="Use Goose after 11 PM"; icon="🦉"; points=15; category="special"},
            @{id="memory_master"; name="Memory Master"; description="Store 100 memories"; icon="🧠"; points=75; category="special"},
            @{id="script_kiddie"; name="Script Kiddie"; description="Create your first script"; icon="📜"; points=20; category="advanced"},
            @{id="script_surgeon"; name="Script Surgeon"; description="Create 20 scripts"; icon="⚕️"; points=100; category="advanced"},
            @{id="streak_3"; name="Getting Started"; description="Use Goose 3 days in a row"; icon="🔥"; points=25; category="streaks"},
            @{id="streak_7"; name="Week Warrior"; description="Use Goose 7 days in a row"; icon="⚔️"; points=75; category="streaks"},
            @{id="streak_30"; name="Monthly Dedication"; description="Use Goose 30 days in a row"; icon="🏆"; points=300; category="streaks"},
            @{id="notification_manager"; name="Inbox Zero"; description="Dismiss 100 notifications"; icon="📬"; points=40; category="productivity"},
            @{id="window_whiz"; name="Window Whisperer"; description="Snap 50 windows"; icon="🪟"; points=50; category="productivity"},
            @{id="briefing_reader"; name="Informed"; description="View 20 daily briefings"; icon="📰"; points=40; category="productivity"}
        )
    }
    
    [void] LoadProgress() {
        $progressFile = Join-Path $this.DataPath "progress.json"
        if (Test-Path $progressFile) {
            try {
                $data = Get-Content $progressFile -Raw | ConvertFrom-Json
                $this.UnlockedAchievements = @{}
                foreach ($prop in $data.PSObject.Properties) {
                    if ($prop.Name -eq "TotalPoints") {
                        $this.TotalPoints = $prop.Value
                    } else {
                        $this.UnlockedAchievements[$prop.Name] = $prop.Value
                    }
                }
            } catch {
                $this.UnlockedAchievements = @{}
            }
        }
    }
    
    [void] SaveProgress() {
        $progressFile = Join-Path $this.DataPath "progress.json"
        $data = @{ TotalPoints = $this.TotalPoints }
        foreach ($key in $this.UnlockedAchievements.Keys) {
            $data[$key] = $this.UnlockedAchievements[$key]
        }
        $data | ConvertTo-Json -Depth 10 | Set-Content -Path $progressFile
    }
    
    [void] CheckAchievement([string]$achievementId, [int]$currentValue) {
        $achievement = $this.Achievements | Where-Object { $_.id -eq $achievementId } | Select-Object -First 1
        if (-not $achievement) { return }
        if ($this.UnlockedAchievements.ContainsKey($achievementId)) { return }
        if ($currentValue -ge 1 -and $achievementId -match "^(first_|_rookie|_user|_kiddie)$") {
            $this.Unlock($achievementId)
        } elseif ($currentValue -ge 50 -and $achievementId -match "^(honk_master|screenshot_pro|focus_master|window_whiz)$") {
            $this.Unlock($achievementId)
        } elseif ($currentValue -ge 10 -and $achievementId -match "^(note_taker|joke_teller)$") {
            $this.Unlock($achievementId)
        } elseif ($currentValue -ge 5 -and $achievementId -eq "organized") {
            $this.Unlock($achievementId)
        } elseif ($currentValue -ge 20 -and $achievementId -match "^(script_surgeon|notification_manager|briefing_reader)$") {
            $this.Unlock($achievementId)
        } elseif ($currentValue -ge 100 -and $achievementId -match "^(memory_master)$") {
            $this.Unlock($achievementId)
        }
    }
    
    [void] CheckTimeBasedAchievement([string]$achievementId) {
        $achievement = $this.Achievements | Where-Object { $_.id -eq $achievementId } | Select-Object -First 1
        if (-not $achievement) { return }
        if ($this.UnlockedAchievements.ContainsKey($achievementId)) { return }
        $hour = (Get-Date).Hour
        switch ($achievementId) {
            "early_bird" { if ($hour -lt 7) { $this.Unlock($achievementId) } }
            "night_owl" { if ($hour -ge 23) { $this.Unlock($achievementId) } }
        }
    }
    
    [void] CheckStreakAchievement([int]$streak) {
        if ($streak -ge 3) { $this.TryUnlock("streak_3") }
        if ($streak -ge 7) { $this.TryUnlock("streak_7") }
        if ($streak -ge 30) { $this.TryUnlock("streak_30") }
    }
    
    [void] TryUnlock([string]$achievementId) {
        $achievement = $this.Achievements | Where-Object { $_.id -eq $achievementId } | Select-Object -First 1
        if ($achievement -and -not $this.UnlockedAchievements.ContainsKey($achievementId)) {
            $this.Unlock($achievementId)
        }
    }
    
    [void] Unlock([string]$achievementId) {
        $achievement = $this.Achievements | Where-Object { $_.id -eq $achievementId } | Select-Object -First 1
        if (-not $achievement) { return }
        $this.Telemetry?.IncrementCounter("achievements.unlocked", 1, @{achievement=$achievementId})
        $this.UnlockedAchievements[$achievementId] = @{
            unlockedAt = (Get-Date).ToString("o")
            pointsAwarded = $achievement.points
        }
        $this.TotalPoints += $achievement.points
        $this.Telemetry?.SetTelemetryGauge("achievements.total_points", $this.TotalPoints)
        $this.SaveProgress()
        if ($this.Config["ShowNotifications"]) {
            $this.ShowUnlockNotification($achievement)
        }
    }
    
    [void] ShowUnlockNotification([hashtable]$achievement) {
        Add-Type -AssemblyName System.Windows.Forms
        $form = New-Object System.Windows.Forms.Form
        $form.Text = "Achievement Unlocked!"
        $form.Size = New-Object System.Drawing.Size(400, 150)
        $form.StartPosition = "CenterScreen"
        $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
        $form.FormBorderStyle = "FixedDialog"
        $icon = New-Object System.Windows.Forms.Label
        $icon.Text = $achievement.icon
        $icon.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 36)
        $icon.Location = New-Object System.Drawing.Point(30, 30)
        $icon.Size = New-Object System.Drawing.Size(80, 80)
        $form.Controls.Add($icon)
        $title = New-Object System.Windows.Forms.Label
        $title.Text = "Achievement Unlocked!"
        $title.Location = New-Object System.Drawing.Point(120, 20)
        $title.Size = New-Object System.Drawing.Size(250, 30)
        $title.Font = New-Object System.Drawing.Font("Segoe UI", 12, [System.Drawing.FontStyle]::Bold)
        $title.ForeColor = [System.Drawing.Color]::FromArgb(255, 200, 0)
        $form.Controls.Add($title)
        $name = New-Object System.Windows.Forms.Label
        $name.Text = $achievement.name
        $name.Location = New-Object System.Drawing.Point(120, 50)
        $name.Size = New-Object System.Drawing.Size(250, 25)
        $name.Font = New-Object System.Drawing.Font("Segoe UI", 11)
        $name.ForeColor = [System.Drawing.Color]::White
        $form.Controls.Add($name)
        $desc = New-Object System.Windows.Forms.Label
        $desc.Text = $achievement.description
        $desc.Location = New-Object System.Drawing.Point(120, 75)
        $desc.Size = New-Object System.Drawing.Size(250, 25)
        $desc.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 185)
        $form.Controls.Add($desc)
        $points = New-Object System.Windows.Forms.Label
        $points.Text = "+$($achievement.points) points"
        $points.Location = New-Object System.Drawing.Point(120, 100)
        $points.Size = New-Object System.Drawing.Size(250, 25)
        $points.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $points.ForeColor = [System.Drawing.Color]::FromArgb(0, 200, 120)
        $form.Controls.Add($points)
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 3000
        $timer.Add_Tick({ $form.Close(); $timer.Stop() })
        $timer.Start()
        $form.ShowDialog()
    }
    
    [void] ShowAchievementsPanel() {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $form = New-Object System.Windows.Forms.Form
        $form.Text = "Desktop Goose - Achievements"
        $form.Size = New-Object System.Drawing.Size(600, 500)
        $form.StartPosition = "CenterScreen"
        $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
        $header = New-Object System.Windows.Forms.Label
        $header.Text = "Achievements"
        $header.Location = New-Object System.Drawing.Point(20, 20)
        $header.Size = New-Object System.Drawing.Size(300, 35)
        $header.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
        $header.ForeColor = [System.Drawing.Color]::White
        $form.Controls.Add($header)
        $pointsLabel = New-Object System.Windows.Forms.Label
        $pointsLabel.Text = "Total Points: $($this.TotalPoints)"
        $pointsLabel.Location = New-Object System.Drawing.Point(450, 25)
        $pointsLabel.Size = New-Object System.Drawing.Size(130, 25)
        $pointsLabel.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $pointsLabel.ForeColor = [System.Drawing.Color]::FromArgb(255, 200, 0)
        $form.Controls.Add($pointsLabel)
        $panel = New-Object System.Windows.Forms.Panel
        $panel.Location = New-Object System.Drawing.Point(20, 60)
        $panel.Size = New-Object System.Drawing.Size(560, 400)
        $panel.AutoScroll = $true
        $form.Controls.Add($panel)
        $y = 0
        $categories = @("basic", "productivity", "fun", "special", "advanced", "streaks")
        foreach ($cat in $categories) {
            $catAchievements = $this.Achievements | Where-Object { $_.category -eq $cat }
            if ($catAchievements) {
                $catLabel = New-Object System.Windows.Forms.Label
                $catLabel.Text = $cat.ToUpper()
                $catLabel.Location = New-Object System.Drawing.Point(0, $y)
                $catLabel.Size = New-Object System.Drawing.Size(200, 20)
                $catLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
                $catLabel.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 155)
                $panel.Controls.Add($catLabel)
                $y += 25
                foreach ($ach in $catAchievements) {
                    $unlocked = $this.UnlockedAchievements.ContainsKey($ach.id)
                    $item = New-Object System.Windows.Forms.Panel
                    $item.Location = New-Object System.Drawing.Point(0, $y)
                    $item.Size = New-Object System.Drawing.Size(540, 50)
                    $item.BackColor = if ($unlocked) { [System.Drawing.Color]::FromArgb(50, 50, 55) } else { [System.Drawing.Color]::FromArgb(35, 35, 40) }
                    $iconLabel = New-Object System.Windows.Forms.Label
                    $iconLabel.Text = if ($unlocked) { $ach.icon } else { "🔒" }
                    $iconLabel.Location = New-Object System.Drawing.Point(10, 10)
                    $iconLabel.Size = New-Object System.Drawing.Size(30, 30)
                    $iconLabel.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 16)
                    $item.Controls.Add($iconLabel)
                    $nameLabel = New-Object System.Windows.Forms.Label
                    $nameLabel.Text = $ach.name
                    $nameLabel.Location = New-Object System.Drawing.Point(50, 5)
                    $nameLabel.Size = New-Object System.Drawing.Size(300, 20)
                    $nameLabel.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
                    $nameLabel.ForeColor = if ($unlocked) { [System.Drawing.Color]::White } else { [System.Drawing.Color]::Gray }
                    $item.Controls.Add($nameLabel)
                    $descLabel = New-Object System.Windows.Forms.Label
                    $descLabel.Text = $ach.description
                    $descLabel.Location = New-Object System.Drawing.Point(50, 25)
                    $descLabel.Size = New-Object System.Drawing.Size(300, 20)
                    $descLabel.ForeColor = if ($unlocked) { [System.Drawing.Color]::FromArgb(180, 180, 185) } else { [System.Drawing.Color]::FromArgb(100, 100, 105) }
                    $item.Controls.Add($descLabel)
                    $ptsLabel = New-Object System.Windows.Forms.Label
                    $ptsLabel.Text = "$($ach.points) pts"
                    $ptsLabel.Location = New-Object System.Drawing.Point(470, 15)
                    $ptsLabel.Size = New-Object System.Drawing.Size(60, 20)
                    $ptsLabel.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Bold)
                    $ptsLabel.ForeColor = if ($unlocked) { [System.Drawing.Color]::FromArgb(0, 200, 120) } else { [System.Drawing.Color]::FromArgb(80, 80, 85) }
                    $item.Controls.Add($ptsLabel)
                    $panel.Controls.Add($item)
                    $y += 55
                }
                $y += 10
            }
        }
        $form.ShowDialog()
    }
    
    [hashtable] GetProgress() {
        $unlocked = $this.UnlockedAchievements.Count
        $total = $this.Achievements.Count
        return @{
            unlocked = $unlocked
            total = $total
            percentage = [math]::Round(($unlocked / $total) * 100, 1)
            totalPoints = $this.TotalPoints
        }
    }
}

$gooseAchievements = $null

function Get-Achievements {
    param([object]$Telemetry = $null)
    if ($script:gooseAchievements -eq $null) {
        $script:gooseAchievements = [GooseAchievements]::new("config.ini", $Telemetry)
    }
    return $script:gooseAchievements
}

function Show-AchievementsPanel {
    $achievements = Get-Achievements
    $achievements.ShowAchievementsPanel()
}

function Unlock-Achievement {
    param([string]$AchievementId, [int]$CurrentValue = 1)
    $achievements = Get-Achievements
    $achievements.CheckAchievement($AchievementId, $CurrentValue)
}

Write-Host "Achievements Module Initialized"
