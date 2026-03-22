class GooseSmartNotifications {
    [hashtable]$Config
    [string]$DataPath
    [object]$Telemetry
    [array]$Notifications
    [hashtable]$Categories
    [System.Windows.Forms.Form]$DashboardForm
    
    GooseSmartNotifications([string]$configFile = "config.ini", [object]$telemetry = $null) {
        $this.Telemetry = $telemetry
        $this.LoadConfig($configFile)
        $this.DataPath = Join-Path $PSScriptRoot "notifications_data"
        if (-not (Test-Path $this.DataPath)) {
            New-Item -ItemType Directory -Path $this.DataPath -Force | Out-Null
        }
        $this.Notifications = @()
        $this.Categories = @{
            "Work" = @{Icon="💼"; Color=[System.Drawing.Color]::FromArgb(0, 120, 215)}
            "Social" = @{Icon="💬"; Color=[System.Drawing.Color]::FromArgb(0, 180, 120)}
            "System" = @{Icon="⚙️"; Color=[System.Drawing.Color]::FromArgb(180, 180, 0)}
            "Personal" = @{Icon="📝"; Color=[System.Drawing.Color]::FromArgb(180, 100, 180)}
            "Urgent" = @{Icon="🚨"; Color=[System.Drawing.Color]::FromArgb(220, 60, 60)}
        }
        $this.LoadData()
    }
    
    [void] LoadConfig([string]$configFile) {
        $this.Config = @{
            Enabled = $true
            MaxHistory = 100
            SnoozeDurationMinutes = 15
            ShowDashboard = $true
            EnableGooseReaction = $true
            GroupByCategory = $true
            SoundEnabled = $false
            DarkMode = $true
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
    
    [void] LoadData() {
        $dataFile = Join-Path $this.DataPath "notifications.json"
        if (Test-Path $dataFile) {
            try {
                $this.Notifications = @(Get-Content $dataFile -Raw | ConvertFrom-Json)
                if ($this.Notifications -isnot [array]) { $this.Notifications = @() }
            } catch {
                $this.Notifications = @()
            }
        }
    }
    
    [void] SaveData() {
        $dataFile = Join-Path $this.DataPath "notifications.json"
        $this.Notifications | ConvertTo-Json -Depth 10 | Set-Content -Path $dataFile
    }
    
    [void] AddNotification([string]$title, [string]$message, [string]$category = "System", [int]$priority = 0) {
        $this.Telemetry?.IncrementCounter("notifications.received", 1, @{category=$category})
        $notification = @{
            id = [guid]::NewGuid().ToString()
            title = $title
            message = $message
            category = $category
            priority = $priority
            timestamp = (Get-Date).ToString("o")
            isRead = $false
            isSnoozed = $false
            snoozeUntil = $null
            isDismissed = $false
        }
        $this.Notifications = @($notification) + $this.Notifications
        if ($this.Notifications.Count -gt $this.Config["MaxHistory"]) {
            $this.Notifications = $this.Notifications[0..($this.Config["MaxHistory"]-1)]
        }
        $this.SaveData()
        if ($this.Config["ShowDashboard"]) {
            $this.ShowToast($notification)
        }
        if ($this.Config["EnableGooseReaction"]) {
            $this.GooseReact($category)
        }
    }
    
    [void] SnoozeNotification([string]$notificationId, [int]$minutes = 0) {
        if ($minutes -eq 0) {
            $minutes = $this.Config["SnoozeDurationMinutes"]
        }
        $notification = $this.Notifications | Where-Object { $_.id -eq $notificationId } | Select-Object -First 1
        if ($notification) {
            $notification.isSnoozed = $true
            $notification.snoozeUntil = (Get-Date).AddMinutes($minutes).ToString("o")
            $this.SaveData()
            $this.Telemetry?.IncrementCounter("notifications.snoozed", 1, @{category=$notification.category})
        }
    }
    
    [void] DismissNotification([string]$notificationId) {
        $notification = $this.Notifications | Where-Object { $_.id -eq $notificationId } | Select-Object -First 1
        if ($notification) {
            $notification.isDismissed = $true
            $notification.isRead = $true
            $this.SaveData()
            $this.Telemetry?.IncrementCounter("notifications.dismissed", 1, @{category=$notification.category})
        }
    }
    
    [void] MarkAsRead([string]$notificationId) {
        $notification = $this.Notifications | Where-Object { $_.id -eq $notificationId } | Select-Object -First 1
        if ($notification) {
            $notification.isRead = $true
            $this.SaveData()
            $this.Telemetry?.IncrementCounter("notifications.marked_read", 1)
        }
    }
    
    [void] MarkAllAsRead() {
        foreach ($n in $this.Notifications) {
            $n.isRead = $true
        }
        $this.SaveData()
        $this.Telemetry?.IncrementCounter("notifications.marked_all_read", 1)
    }
    
    [void] ShowToast([hashtable]$notification) {
        Add-Type -AssemblyName System.Windows.Forms
        $toast = New-Object System.Windows.Forms.Form
        $toast.Text = $notification.title
        $toast.Size = New-Object System.Drawing.Size(350, 120)
        $toast.StartPosition = "Manual"
        $toast.FormBorderStyle = "FixedSingle"
        $toast.TopMost = $true
        $toast.ShowInTaskbar = $false
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        $toast.Location = New-Object System.Drawing.Point($screen.Right - 360, $screen.Bottom - 130)
        $toast.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
        $cat = $this.Categories[$notification.category]
        if (-not $cat) {
            $cat = $this.Categories["System"]
        }
        $lblIcon = New-Object System.Windows.Forms.Label
        $lblIcon.Text = $cat.Icon
        $lblIcon.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 20)
        $lblIcon.Location = New-Object System.Drawing.Point(10, 10)
        $lblIcon.Size = New-Object System.Drawing.Size(40, 40)
        $toast.Controls.Add($lblIcon)
        $lblTitle = New-Object System.Windows.Forms.Label
        $lblTitle.Text = $notification.title
        $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $lblTitle.Location = New-Object System.Drawing.Point(55, 10)
        $lblTitle.Size = New-Object System.Drawing.Size(280, 25)
        $lblTitle.ForeColor = [System.Drawing.Color]::White
        $toast.Controls.Add($lblTitle)
        $lblMessage = New-Object System.Windows.Forms.Label
        $lblMessage.Text = $notification.message
        $lblMessage.Location = New-Object System.Drawing.Point(55, 35)
        $lblMessage.Size = New-Object System.Drawing.Size(280, 40)
        $lblMessage.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 185)
        $toast.Controls.Add($lblMessage)
        $btnSnooze = New-Object System.Windows.Forms.Button
        $btnSnooze.Text = "Snooze"
        $btnSnooze.Location = New-Object System.Drawing.Point(180, 80)
        $btnSnooze.Size = New-Object System.Drawing.Size(75, 28)
        $btnSnooze.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 105)
        $btnSnooze.ForeColor = [System.Drawing.Color]::White
        $btnSnooze.FlatStyle = "Flat"
        $toast.Controls.Add($btnSnooze)
        $btnSnooze.Add_Click({
            $this.SnoozeNotification($notification.id)
            $toast.Close()
        })
        $btnDismiss = New-Object System.Windows.Forms.Button
        $btnDismiss.Text = "Dismiss"
        $btnDismiss.Location = New-Object System.Drawing.Point(260, 80)
        $btnDismiss.Size = New-Object System.Drawing.Size(75, 28)
        $btnDismiss.BackColor = [System.Drawing.Color]::FromArgb(180, 60, 60)
        $btnDismiss.ForeColor = [System.Drawing.Color]::White
        $btnDismiss.FlatStyle = "Flat"
        $toast.Controls.Add($btnDismiss)
        $btnDismiss.Add_Click({
            $this.DismissNotification($notification.id)
            $toast.Close()
        })
        $toast.Show()
        $timer = New-Object System.Windows.Forms.Timer
        $timer.Interval = 5000
        $timer.Add_Tick({
            $toast.Close()
            $timer.Stop()
        })
        $timer.Start()
    }
    
    [void] GooseReact([string]$category) {
        $this.Telemetry?.IncrementCounter("notifications.goose_reactions", 1, @{category=$category})
    }
    
    [void] ShowDashboard() {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $form = New-Object System.Windows.Forms.Form
        $form.Text = "Desktop Goose - Notification Dashboard"
        $form.Size = New-Object System.Drawing.Size(600, 500)
        $form.StartPosition = "CenterScreen"
        $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
        $panel = New-Object System.Windows.Forms.Panel
        $panel.Dock = "Fill"
        $panel.AutoScroll = $true
        $form.Controls.Add($panel)
        $title = New-Object System.Windows.Forms.Label
        $title.Text = "Notifications"
        $title.Font = New-Object System.Drawing.Font("Segoe UI", 16, [System.Drawing.FontStyle]::Bold)
        $title.Location = New-Object System.Drawing.Point(20, 20)
        $title.Size = New-Object System.Drawing.Size(300, 35)
        $title.ForeColor = [System.Drawing.Color]::White
        $panel.Controls.Add($title)
        $unread = $this.Notifications | Where-Object { -not $_.isRead -and -not $_.isDismissed }
        $lblCount = New-Object System.Windows.Forms.Label
        $lblCount.Text = "$($unread.Count) unread"
        $lblCount.Location = New-Object System.Drawing.Point(500, 25)
        $lblCount.Size = New-Object System.Drawing.Size(80, 25)
        $lblCount.ForeColor = [System.Drawing.Color]::FromArgb(0, 180, 120)
        $panel.Controls.Add($lblCount)
        $btnMarkAll = New-Object System.Windows.Forms.Button
        $btnMarkAll.Text = "Mark All Read"
        $btnMarkAll.Location = New-Object System.Drawing.Point(20, 60)
        $btnMarkAll.Size = New-Object System.Drawing.Size(120, 30)
        $btnMarkAll.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
        $btnMarkAll.ForeColor = [System.Drawing.Color]::White
        $btnMarkAll.FlatStyle = "Flat"
        $panel.Controls.Add($btnMarkAll)
        $btnMarkAll.Add_Click({
            $this.MarkAllAsRead()
            $form.Close()
            $this.ShowDashboard()
        })
        $y = 100
        $visible = $this.Notifications | Where-Object { -not $_.isDismissed } | Select-Object -First 15
        foreach ($notif in $visible) {
            $cat = $this.Categories[$notif.category]
            if (-not $cat) { $cat = $this.Categories["System"] }
            $item = New-Object System.Windows.Forms.Panel
            $item.Location = New-Object System.Drawing.Point(20, $y)
            $item.Size = New-Object System.Drawing.Size(540, 60)
            $item.BackColor = if (-not $notif.isRead) { [System.Drawing.Color]::FromArgb(50, 50, 55) } else { [System.Drawing.Color]::FromArgb(40, 40, 45) }
            $icon = New-Object System.Windows.Forms.Label
            $icon.Text = $cat.Icon
            $icon.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 16)
            $icon.Location = New-Object System.Drawing.Point(10, 15)
            $icon.Size = New-Object System.Drawing.Size(30, 30)
            $item.Controls.Add($icon)
            $lblTitle = New-Object System.Windows.Forms.Label
            $lblTitle.Text = $notif.title
            $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
            $lblTitle.Location = New-Object System.Drawing.Point(50, 8)
            $lblTitle.Size = New-Object System.Drawing.Size(350, 20)
            $lblTitle.ForeColor = [System.Drawing.Color]::White
            $item.Controls.Add($lblTitle)
            $lblMsg = New-Object System.Windows.Forms.Label
            $lblMsg.Text = $notif.message
            $lblMsg.Location = New-Object System.Drawing.Point(50, 30)
            $lblMsg.Size = New-Object System.Drawing.Size(350, 25)
            $lblMsg.ForeColor = [System.Drawing.Color]::FromArgb(150, 150, 155)
            $item.Controls.Add($lblMsg)
            $btnDismiss = New-Object System.Windows.Forms.Button
            $btnDismiss.Text = "X"
            $btnDismiss.Location = New-Object System.Drawing.Point(490, 15)
            $btnDismiss.Size = New-Object System.Drawing.Size(30, 30)
            $btnDismiss.Tag = $notif.id
            $btnDismiss.BackColor = [System.Drawing.Color]::FromArgb(180, 60, 60)
            $btnDismiss.ForeColor = [System.Drawing.Color]::White
            $btnDismiss.FlatStyle = "Flat"
            $btnDismiss.Add_Click({
                $this.DismissNotification($this.Tag)
                $form.Close()
                $this.ShowDashboard()
            })
            $item.Controls.Add($btnDismiss)
            $panel.Controls.Add($item)
            $y += 65
        }
        $form.ShowDialog()
    }
    
    [array] GetNotificationsByCategory([string]$category) {
        return @($this.Notifications | Where-Object { $_.category -eq $category -and -not $_.isDismissed })
    }
    
    [hashtable] GetStats() {
        $unread = $this.Notifications | Where-Object { -not $_.isRead -and -not $_.isDismissed }
        $today = $this.Notifications | Where-Object { $_.timestamp -like "*$(Get-Date -Format 'yyyy-MM-dd')*" }
        return @{
            total = $this.Notifications.Count
            unread = $unread.Count
            today = $today.Count
            categories = $this.Categories.Keys
        }
    }
}

$gooseSmartNotifications = $null

function Get-SmartNotifications {
    param([object]$Telemetry = $null)
    if ($script:gooseSmartNotifications -eq $null) {
        $script:gooseSmartNotifications = [GooseSmartNotifications]::new("config.ini", $Telemetry)
    }
    return $script:gooseSmartNotifications
}

function Show-NotificationDashboard {
    $notifications = Get-SmartNotifications
    $notifications.ShowDashboard()
}

function Send-GooseNotification {
    param([string]$Title, [string]$Message, [string]$Category = "System")
    $notifications = Get-SmartNotifications
    $notifications.AddNotification($Title, $Message, $Category)
}

Write-Host "Smart Notifications Module Initialized"
