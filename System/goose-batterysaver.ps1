# Desktop Goose Battery Saver Mode
# Reduce activity when on battery

class GooseBatterySaver {
    [hashtable]$Config
    [bool]$IsOnBattery
    [int]$BatteryThreshold
    [bool]$IsActive
    [int]$OriginalActivityLevel
    
    GooseBatterySaver() {
        $this.Config = $this.LoadConfig()
        $this.BatteryThreshold = 20
        $this.IsActive = $false
        $this.OriginalActivityLevel = 100
        $this.CheckBatteryStatus()
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
        
        if (-not $this.Config.ContainsKey("BatterySaverEnabled")) {
            $this.Config["BatterySaverEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [bool] CheckBatteryStatus() {
        try {
            $battery = Get-WmiObject -Class Win32_Battery -ErrorAction Stop
            
            if ($null -eq $battery) {
                $this.IsOnBattery = $false
                return $false
            }
            
            $this.IsOnBattery = ($battery.BatteryStatus -eq 2)
            
            return $this.IsOnBattery
        } catch {
            $this.IsOnBattery = $false
            return $false
        }
    }
    
    [int] GetBatteryPercentage() {
        try {
            $battery = Get-WmiObject -Class Win32_Battery -ErrorAction Stop
            if ($battery) {
                return $battery.EstimatedChargeRemaining
            }
        } catch {}
        
        return 100
    }
    
    [hashtable] ActivateBatterySaver() {
        if ($this.IsActive) {
            return @{
                "Success" = $false
                "AlreadyActive" = $true
                "Message" = "Battery saver already active"
            }
        }
        
        $this.OriginalActivityLevel = 100
        $this.IsActive = $true
        
        return @{
            "Success" = $true
            "PreviousActivityLevel" = $this.OriginalActivityLevel
            "NewActivityLevel" = 30
            "Message" = "Battery saver activated! Activity reduced to save power."
        }
    }
    
    [hashtable] DeactivateBatterySaver() {
        if (-not $this.IsActive) {
            return @{
                "Success" = $false
                "AlreadyInactive" = $true
                "Message" = "Battery saver already inactive"
            }
        }
        
        $this.IsActive = $false
        
        return @{
            "Success" = $true
            "PreviousActivityLevel" = 30
            "NewActivityLevel" = $this.OriginalActivityLevel
            "Message" = "Battery saver deactivated. Back to normal activity!"
        }
    }
    
    [hashtable] CheckAndUpdate() {
        $this.CheckBatteryStatus()
        $batteryPercent = $this.GetBatteryPercentage()
        
        if ($batteryPercent -le $this.BatteryThreshold -and -not $this.IsOnBattery) {
            return @{
                "BatteryLow" = $true
                "Percentage" = $batteryPercent
                "OnBattery" = $this.IsOnBattery
                "BatterySaverActive" = $this.IsActive
                "ShouldActivate" = $true
            }
        }
        
        if ($this.IsOnBattery -and -not $this.IsActive) {
            return @{
                "BatteryLow" = $false
                "Percentage" = $batteryPercent
                "OnBattery" = $this.IsOnBattery
                "BatterySaverActive" = $this.IsActive
                "ShouldActivate" = $true
            }
        }
        
        if (-not $this.IsOnBattery -and $this.IsActive) {
            return @{
                "BatteryLow" = $false
                "Percentage" = $batteryPercent
                "OnBattery" = $this.IsOnBattery
                "BatterySaverActive" = $this.IsActive
                "ShouldDeactivate" = $true
            }
        }
        
        return @{
            "BatteryLow" = $false
            "Percentage" = $batteryPercent
            "OnBattery" = $this.IsOnBattery
            "BatterySaverActive" = $this.IsActive
        }
    }
    
    [void] SetThreshold([int]$percent) {
        $this.BatteryThreshold = [Math]::Min(100, [Math]::Max(5, $percent))
    }
    
    [hashtable] GetBatterySaverState() {
        return @{
            "Enabled" = $this.Config["BatterySaverEnabled"]
            "IsActive" = $this.IsActive
            "IsOnBattery" = $this.IsOnBattery
            "BatteryPercentage" = $this.GetBatteryPercentage()
            "Threshold" = $this.BatteryThreshold
        }
    }
}

$gooseBatterySaver = [GooseBatterySaver]::new()

function Get-GooseBatterySaver {
    return $gooseBatterySaver
}

function Test-BatterySaver {
    param($BatterySaver = $gooseBatterySaver)
    return $BatterySaver.CheckAndUpdate()
}

function Enable-BatterySaver {
    param($BatterySaver = $gooseBatterySaver)
    return $BatterySaver.ActivateBatterySaver()
}

function Disable-BatterySaver {
    param($BatterySaver = $gooseBatterySaver)
    return $BatterySaver.DeactivateBatterySaver()
}

function Get-BatterySaverState {
    param($BatterySaver = $gooseBatterySaver)
    return $BatterySaver.GetBatterySaverState()
}

Write-Host "Desktop Goose Battery Saver System Initialized"
$state = Get-BatterySaverState
Write-Host "Battery Saver Active: $($state['IsActive'])"
Write-Host "On Battery: $($state['IsOnBattery'])"
Write-Host "Battery: $($state['BatteryPercentage'])%"
