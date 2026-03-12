# Desktop Goose System Status Display
# Shows system information near the goose

class GooseSysInfo {
    [hashtable]$Config
    [bool]$IsVisible
    [hashtable]$DisplaySettings
    [datetime]$LastUpdate
    [int]$UpdateIntervalSeconds
    
    GooseSysInfo() {
        $this.Config = $this.LoadConfig()
        $this.IsVisible = $false
        $this.LastUpdate = Get-Date
        $this.UpdateIntervalSeconds = 5
        $this.DisplaySettings = @{
            "ShowCPU" = $true
            "ShowMemory" = $true
            "ShowTime" = $true
            "ShowDate" = $false
            "ShowBattery" = $true
            "Position" = "bottomright"
            "Opacity" = 0.7
            "FontSize" = 10
        }
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
                    } elseif ($value -match '^\d+\.\d+$') {
                        $this.Config[$key] = [double]$value
                    } else {
                        $this.Config[$key] = $value
                    }
                }
            }
        }
        
        if (-not $this.Config.ContainsKey("ShowSystemStatus")) {
            $this.Config["ShowSystemStatus"] = $false
        }
        
        return $this.Config
    }
    
    [hashtable] GetSystemInfo() {
        $timeSinceUpdate = (Get-Date) - $this.LastUpdate
        if ($timeSinceUpdate.TotalSeconds -lt $this.UpdateIntervalSeconds -and -not $this.IsVisible) {
            return $null
        }
        
        $cpu = $this.GetCPUUsage()
        $memory = $this.GetMemoryUsage()
        $battery = $this.GetBatteryStatus()
        $time = Get-Date -Format "HH:mm"
        $date = Get-Date -Format "yyyy-MM-dd"
        
        $info = @{}
        
        if ($this.DisplaySettings["ShowCPU"]) {
            $info["CPU"] = $cpu
        }
        if ($this.DisplaySettings["ShowMemory"]) {
            $info["Memory"] = $memory
        }
        if ($this.DisplaySettings["ShowTime"]) {
            $info["Time"] = $time
        }
        if ($this.DisplaySettings["ShowDate"]) {
            $info["Date"] = $date
        }
        if ($this.DisplaySettings["ShowBattery"] -and $battery) {
            $info["Battery"] = $battery
        }
        
        $this.LastUpdate = Get-Date
        
        return @{
            "Info" = $info
            "Timestamp" = $this.LastUpdate
            "IsVisible" = $this.IsVisible
        }
    }
    
    [int] GetCPUUsage() {
        try {
            $cpuCounter = Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue
            if ($cpuCounter) {
                return [Math]::Round($cpuCounter.CounterSamples[0].CookedValue)
            }
        } catch {}
        
        return -1
    }
    
    [string] GetMemoryUsage() {
        try {
            $os = Get-CimInstance -ClassName Win32_OperatingSystem
            $totalMemoryGB = [Math]::Round($os.TotalVisibleMemorySize / 1MB, 1)
            $freeMemoryGB = [Math]::Round($os.FreePhysicalMemory / 1MB, 1)
            $usedMemoryGB = [Math]::Round($totalMemoryGB - $freeMemoryGB, 1)
            $percentUsed = [Math]::Round(($usedMemoryGB / $totalMemoryGB) * 100)
            
            return "$usedMemoryGB GB / $totalMemoryGB GB ($percentUsed%)"
        } catch {
            return "Unknown"
        }
    }
    
    [hashtable] GetBatteryStatus() {
        try {
            $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
            
            if ($battery) {
                $status = @{
                    "Percent" = $battery.EstimatedChargeRemaining
                    "IsCharging" = $battery.BatteryStatus -eq 2
                    "TimeRemaining" = $battery.EstimatedRunTime
                }
                
                if ($status["TimeRemaining"] -eq 71582788) {
                    $status["TimeRemaining"] = $null
                }
                
                return $status
            }
        } catch {}
        
        return $null
    }
    
    [void] ToggleVisibility() {
        $this.IsVisible = -not $this.IsVisible
    }
    
    [void] SetVisibility([bool]$visible) {
        $this.IsVisible = $visible
    }
    
    [void] UpdateSetting([string]$setting, $value) {
        if ($this.DisplaySettings.ContainsKey($setting)) {
            $this.DisplaySettings[$setting] = $value
        }
    }
    
    [hashtable] GetSysInfoState() {
        return @{
            "Enabled" = $this.Config["ShowSystemStatus"]
            "IsVisible" = $this.IsVisible
            "DisplaySettings" = $this.DisplaySettings.Clone()
            "CurrentInfo" = $this.GetSystemInfo()
        }
    }
    
    [string] GetFormattedDisplay() {
        $info = $this.GetSystemInfo()
        
        if (-not $info -or -not $info["IsVisible"]) {
            return ""
        }
        
        $lines = @()
        
        foreach ($key in $info["Info"].Keys) {
            $value = $info["Info"][$key]
            
            if ($value -is [hashtable]) {
                $lines += "$key : $($value.Percent)%"
                if ($value.IsCharging) { $lines += "  (Charging)" }
            } else {
                $lines += "$key : $value"
            }
        }
        
        return $lines -join "`n"
    }
    
    [hashtable] GetQuickSummary() {
        $cpu = $this.GetCPUUsage()
        $mem = $this.GetMemoryUsage()
        
        return @{
            "CPU" = $cpu
            "Memory" = $mem
            "Time" = Get-Date -Format "HH:mm"
        }
    }
}

$gooseSysInfo = [GooseSysInfo]::new()

function Get-GooseSysInfo {
    return $gooseSysInfo
}

function Get-SystemInfo {
    param($SysInfo = $gooseSysInfo)
    return $SysInfo.GetSystemInfo()
}

function Toggle-SysInfoDisplay {
    param($SysInfo = $gooseSysInfo)
    $SysInfo.ToggleVisibility()
    return $SysInfo.GetSysInfoState()
}

function Get-QuickSystemSummary {
    param($SysInfo = $gooseSysInfo)
    return $SysInfo.GetQuickSummary()
}

Write-Host "Desktop Goose System Info System Initialized"
$state = $gooseSysInfo.GetSysInfoState()
Write-Host "System Info Enabled: $($state['Enabled'])"
Write-Host "Visible: $($state['IsVisible'])"
