# Desktop Goose System Tray System
# Minimize goose to system tray

class GooseSystemTray {
    [hashtable]$Config
    [bool]$MinimizedToTray
    [string]$TrayIconPath
    [string]$TrayTooltip
    [bool]$ShowBalloonNotifications
    
    GooseSystemTray() {
        $this.Config = $this.LoadConfig()
        $this.MinimizedToTray = $false
        $this.TrayIconPath = ""
        $this.TrayTooltip = "Desktop Goose"
        $this.ShowBalloonNotifications = $true
    }
    
    [hashtable] LoadConfig() {
        $this.Config = @{}
        $configFile = "config.ini"
        
        if (Test-Path $configFile) {
            Get-Content $configFile | ForEach-Object {
                if ($_ -match '^([^=]+)=(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    
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
        
        if (-not $this.Config.ContainsKey("SystemTrayEnabled")) {
            $this.Config["SystemTrayEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [hashtable] MinimizeToTray() {
        $this.MinimizedToTray = $true
        
        if ($this.ShowBalloonNotifications) {
            $this.ShowBalloon("Desktop Goose", "I'm in the tray! Click to bring me back.", "info")
        }
        
        return @{
            "Success" = $true
            "MinimizedToTray" = $true
            "Message" = "Goose minimized to system tray"
        }
    }
    
    [hashtable] RestoreFromTray() {
        $this.MinimizedToTray = $false
        
        return @{
            "Success" = $true
            "MinimizedToTray" = $false
            "Message" = "Goose restored from system tray"
        }
    }
    
    [void] ShowBalloon([string]$title, [string]$message, [string]$icon = "info") {
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $notifyIcon = New-Object System.Windows.Forms.NotifyIcon
            $notifyIcon.Icon = [System.Drawing.SystemIcons]::Information
            $notifyIcon.BalloonTipTitle = $title
            $notifyIcon.BalloonTipText = $message
            $notifyIcon.BalloonTipIcon = $icon
            $notifyIcon.Visible = $true
            $notifyIcon.ShowBalloonTip(5000)
            
            Start-Sleep -Seconds 6
            $notifyIcon.Dispose()
        } catch {}
    }
    
    [void] SetTooltip([string]$tooltip) {
        $this.TrayTooltip = $tooltip
    }
    
    [void] SetBalloonNotifications([bool]$enabled) {
        $this.ShowBalloonNotifications = $enabled
    }
    
    [hashtable] GetSystemTrayState() {
        return @{
            "Enabled" = $this.Config["SystemTrayEnabled"]
            "MinimizedToTray" = $this.MinimizedToTray
            "TrayTooltip" = $this.TrayTooltip
            "ShowBalloonNotifications" = $this.ShowBalloonNotifications
        }
    }
    
    [void] ToggleTray() {
        if ($this.MinimizedToTray) {
            $this.RestoreFromTray() | Out-Null
        } else {
            $this.MinimizeToTray() | Out-Null
        }
    }
    
    [string] GetSyncStatusTooltip([object]$SyncClient) {
        $status = $SyncClient.GetSyncStatus()
        
        $statusText = switch ($status.Status) {
            "Idle" { "Sync: Bereit" }
            "Syncing" { "Sync: Synchronisiere..." }
            "Success" { "Sync: Erfolgreich" }
            "Error" { "Sync: Fehler" }
            "Offline" { "Sync: Offline" }
            default { "Sync: Unbekannt" }
        }
        
        $lastSync = if ($status.LastSync) { $status.LastSync.ToString("HH:mm") } else { "Nie" }
        
        return "Desktop Goose`n$statusText`nLetzte Sync: $lastSync`nGerät: $($status.DeviceName)"
    }
}

$gooseSystemTray = [GooseSystemTray]::new()

function Get-GooseSystemTray {
    return $gooseSystemTray
}

function Minimize-ToTray {
    param($SystemTray = $gooseSystemTray)
    return $SystemTray.MinimizeToTray()
}

function Restore-FromTray {
    param($SystemTray = $gooseSystemTray)
    return $SystemTray.RestoreFromTray()
}

function Toggle-SystemTray {
    param($SystemTray = $gooseSystemTray)
    $SystemTray.ToggleTray()
}

function Get-SystemTrayState {
    param($SystemTray = $gooseSystemTray)
    return $SystemTray.GetSystemTrayState()
}

Write-Host "Desktop Goose System Tray System Initialized"
$state = Get-SystemTrayState
Write-Host "System Tray Enabled: $($state['Enabled'])"
Write-Host "Currently in Tray: $($state['MinimizedToTray'])"
