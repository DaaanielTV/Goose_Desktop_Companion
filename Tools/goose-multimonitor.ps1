# Desktop Goose Multi-Monitor Support System
# Allows goose to wander across multiple monitors

class GooseMultiMonitor {
    [hashtable]$Config
    [int]$PrimaryMonitorIndex
    [int]$CurrentMonitorIndex
    [hashtable]$MonitorInfo
    [bool]$EnableCrossMonitorWandering
    
    GooseMultiMonitor() {
        $this.Config = $this.LoadConfig()
        $this.EnableCrossMonitorWandering = $false
        $this.PrimaryMonitorIndex = 0
        $this.CurrentMonitorIndex = 0
        $this.MonitorInfo = @{}
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
        
        if (-not $this.Config.ContainsKey("MultiMonitorSupport")) {
            $this.Config["MultiMonitorSupport"] = $false
        }
        if (-not $this.Config.ContainsKey("CrossMonitorWandering")) {
            $this.Config["CrossMonitorWandering"] = $true
        }
        
        return $this.Config
    }
    
    [void] DetectMonitors() {
        Add-Type -AssemblyName System.Windows.Forms
        $screens = [System.Windows.Forms.Screen]::AllScreens
        
        $this.MonitorInfo = @{
            "Count" = $screens.Count
            "Monitors" = @()
            "PrimaryIndex" = 0
        }
        
        for ($i = 0; $i -lt $screens.Count; $i++) {
            $screen = $screens[$i]
            $monitorData = @{
                "Index" = $i
                "DeviceName" = $screen.DeviceName
                "Bounds" = @{
                    "X" = $screen.Bounds.X
                    "Y" = $screen.Bounds.Y
                    "Width" = $screen.Bounds.Width
                    "Height" = $screen.Bounds.Height
                }
                "WorkingArea" = @{
                    "X" = $screen.WorkingArea.X
                    "Y" = $screen.WorkingArea.Y
                    "Width" = $screen.WorkingArea.Width
                    "Height" = $screen.WorkingArea.Height
                }
                "IsPrimary" = $screen.Primary
                "BitsPerPixel" = $screen.BitsPerPixel
            }
            
            if ($screen.Primary) {
                $this.MonitorInfo["PrimaryIndex"] = $i
                $this.PrimaryMonitorIndex = $i
            }
            
            $this.MonitorInfo["Monitors"] += $monitorData
        }
        
        $this.EnableCrossMonitorWandering = $this.Config["CrossMonitorWandering"]
    }
    
    [hashtable] GetNextMonitorBounds([int]$currentX, [int]$currentY) {
        if ($this.MonitorInfo.Count -eq 0) {
            $this.DetectMonitors()
        }
        
        if ($this.MonitorInfo.Count -le 1 -or -not $this.EnableCrossMonitorWandering) {
            $primary = $this.MonitorInfo["Monitors"][$this.PrimaryMonitorIndex]
            return $primary["WorkingArea"]
        }
        
        $targetMonitor = $this.CurrentMonitorIndex
        $monitors = $this.MonitorInfo["Monitors"]
        
        $direction = Get-Random -Minimum 0
        switch -Maximum 4 ($direction) {
            0 { $targetMonitor = ($this.CurrentMonitorIndex + 1) % $monitors.Count }
            1 { $targetMonitor = ($this.CurrentMonitorIndex - 1 + $monitors.Count) % $monitors.Count }
            2 { $targetMonitor = $this.PrimaryMonitorIndex }
            3 { $targetMonitor = Get-Random -Minimum 0 -Maximum $monitors.Count }
        }
        
        $this.CurrentMonitorIndex = $targetMonitor
        $target = $monitors[$targetMonitor]
        
        return @{
            "X" = $target["WorkingArea"].X + (Get-Random -Minimum 0 -Maximum ($target["WorkingArea"].Width / 2))
            "Y" = $target["WorkingArea"].Y + (Get-Random -Minimum 0 -Maximum ($target["WorkingArea"].Height / 2))
            "Width" = $target["WorkingArea"].Width
            "Height" = $target["WorkingArea"].Height
        }
    }
    
    [bool] IsPositionOnCurrentMonitor([int]$x, [int]$y) {
        if ($this.MonitorInfo.Count -eq 0) {
            $this.DetectMonitors()
        }
        
        $currentMonitor = $this.MonitorInfo["Monitors"][$this.CurrentMonitorIndex]
        $bounds = $currentMonitor["WorkingArea"]
        
        return ($x -ge $bounds.X -and $x -lt ($bounds.X + $bounds.Width) -and
                $y -ge $bounds.Y -and $y -lt ($bounds.Y + $bounds.Height))
    }
    
    [void] SetCrossMonitorWandering([bool]$enabled) {
        $this.EnableCrossMonitorWandering = $enabled
        $this.Config["CrossMonitorWandering"] = $enabled
    }
    
    [hashtable] GetMonitorState() {
        if ($this.MonitorInfo.Count -eq 0) {
            $this.DetectMonitors()
        }
        
        return @{
            "Enabled" = $this.Config["MultiMonitorSupport"]
            "CrossMonitorWandering" = $this.EnableCrossMonitorWandering
            "MonitorCount" = $this.MonitorInfo.Count
            "PrimaryIndex" = $this.PrimaryMonitorIndex
            "CurrentIndex" = $this.CurrentMonitorIndex
            "Monitors" = $this.MonitorInfo["Monitors"]
        }
    }
    
    [hashtable] GetRandomPositionOnMonitor([int]$monitorIndex = -1) {
        if ($this.MonitorInfo.Count -eq 0) {
            $this.DetectMonitors()
        }
        
        if ($monitorIndex -lt 0 -or $monitorIndex -ge $this.MonitorInfo.Count) {
            $monitorIndex = Get-Random -Minimum 0 -Maximum $this.MonitorInfo.Count
        }
        
        $monitor = $this.MonitorInfo["Monitors"][$monitorIndex]
        $workArea = $monitor["WorkingArea"]
        
        $x = $workArea.X + (Get-Random -Minimum 0 -Maximum ($workArea.Width - 100))
        $y = $workArea.Y + (Get-Random -Minimum 0 -Maximum ($workArea.Height - 100))
        
        return @{
            "X" = $x
            "Y" = $y
            "MonitorIndex" = $monitorIndex
            "MonitorBounds" = $workArea
        }
    }
}

$gooseMultiMonitor = [GooseMultiMonitor]::new()

function Get-GooseMultiMonitor {
    return $gooseMultiMonitor
}

function Get-MonitorState {
    param($MultiMonitor = $gooseMultiMonitor)
    return $MultiMonitor.GetMonitorState()
}

function Get-NextMonitorPosition {
    param(
        [int]$CurrentX = 0,
        [int]$CurrentY = 0,
        $MultiMonitor = $gooseMultiMonitor
    )
    return $MultiMonitor.GetNextMonitorBounds($CurrentX, $CurrentY)
}

function Set-CrossMonitorWandering {
    param(
        [bool]$Enabled,
        $MultiMonitor = $gooseMultiMonitor
    )
    $MultiMonitor.SetCrossMonitorWandering($Enabled)
}

Write-Host "Desktop Goose Multi-Monitor System Initialized"
$state = Get-MonitorState
Write-Host "Multi-Monitor Support: $($state['Enabled'])"
Write-Host "Monitor Count: $($state['MonitorCount'])"
