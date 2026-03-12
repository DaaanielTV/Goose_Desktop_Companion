class GooseBattery {
    [hashtable]$Config
    [int]$LastBatteryLevel
    [bool]$IsCharging
    [datetime]$LastCheckTime
    [hashtable]$BatteryHistory
    
    GooseBattery() {
        $this.Config = $this.LoadConfig()
        $this.LastBatteryLevel = 100
        $this.IsCharging = $false
        $this.LastCheckTime = Get-Date
        $this.BatteryHistory = @{}
        $this.LoadData()
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
        
        if (-not $this.Config.ContainsKey("BatteryMonitorEnabled")) {
            $this.Config["BatteryMonitorEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("LowBatteryThreshold")) {
            $this.Config["LowBatteryThreshold"] = 20
        }
        if (-not $this.Config.ContainsKey("CriticalBatteryThreshold")) {
            $this.Config["CriticalBatteryThreshold"] = 10
        }
        
        return $this.Config
    }
    
    [void] LoadData() {
        $dataFile = "goose_battery.json"
        
        if (Test-Path $dataFile) {
            try {
                $data = Get-Content $dataFile -Raw | ConvertFrom-Json
                $this.BatteryHistory = @{}
                
                if ($data.BatteryHistory) {
                    $data.BatteryHistory.PSObject.Properties | ForEach-Object {
                        $this.BatteryHistory[$_.Name] = $_.Value
                    }
                }
                
                $this.CleanOldData()
            } catch {}
        }
    }
    
    [void] SaveData() {
        $this.CleanOldData()
        
        $data = @{
            "BatteryHistory" = $this.BatteryHistory
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content "goose_battery.json"
    }
    
    [void] CleanOldData() {
        $cutoffDate = (Get-Date).AddDays(-30).ToString("yyyy-MM-dd")
        $keysToRemove = @()
        
        foreach ($key in $this.BatteryHistory.Keys) {
            if ($key -lt $cutoffDate) {
                $keysToRemove += $key
            }
        }
        
        foreach ($key in $keysToRemove) {
            $this.BatteryHistory.Remove($key)
        }
    }
    
    [hashtable] GetBatteryStatus() {
        $battery = @{
            "Level" = 100
            "IsCharging" = $false
            "IsLaptop" = $false
            "TimeRemaining" = "Unknown"
            "Status" = "Unknown"
        }
        
        try {
            $batteryInfo = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
            
            if ($batteryInfo) {
                $battery.IsLaptop = $true
                $battery.Level = [int]$batteryInfo.EstimatedChargeRemaining
                $battery.IsCharging = $batteryInfo.BatteryStatus -eq 2
                
                if ($batteryInfo.EstimatedRunTime -and $batteryInfo.EstimatedRunTime -lt 71582788) {
                    $battery.TimeRemaining = [math]::Round($batteryInfo.EstimatedRunTime / 60, 1)
                }
                
                if ($battery.IsCharging) {
                    $battery.Status = "Charging ($battery.Level -ge"
                } elseif 80) {
                    $battery.Status = "Full"
                } elseif ($battery.Level -ge 50) {
                    $battery.Status = "Good"
                } elseif ($battery.Level -ge 20) {
                    $battery.Status = "Normal"
                } elseif ($battery.Level -ge 10) {
                    $battery.Status = "Low"
                } else {
                    $battery.Status = "Critical"
                }
            }
        } catch {
            $battery.Status = "Desktop"
        }
        
        $this.LastBatteryLevel = $battery.Level
        $this.IsCharging = $battery.IsCharging
        $this.LastCheckTime = Get-Date
        
        $this.RecordBatteryLevel($battery.Level)
        
        return $battery
    }
    
    [void] RecordBatteryLevel([int]$level) {
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        
        if (-not $this.BatteryHistory.ContainsKey($dateKey)) {
            $this.BatteryHistory[$dateKey] = @{
                "Readings" = @()
                "LowPoints" = @()
                "HighPoints" = @()
                "ChargingSessions" = 0
            }
        }
        
        $this.BatteryHistory[$dateKey].Readings += @{
            "Time" = (Get-Date).ToString("HH:mm")
            "Level" = $level
        }
        
        if ($level -le $this.Config["LowBatteryThreshold"] -and $level -gt $this.Config["CriticalBatteryThreshold"]) {
            $this.BatteryHistory[$dateKey].LowPoints += (Get-Date).ToString("HH:mm")
        }
        
        if ($level -le $this.Config["CriticalBatteryThreshold"]) {
            $this.BatteryHistory[$dateKey].CriticalPoints += (Get-Date).ToString("HH:mm")
        }
        
        $this.SaveData()
    }
    
    [void] RecordChargingSession() {
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        
        if ($this.BatteryHistory.ContainsKey($dateKey)) {
            $this.BatteryHistory[$dateKey].ChargingSessions++
            $this.SaveData()
        }
    }
    
    [bool] ShouldAlertLow() {
        $status = $this.GetBatteryStatus()
        
        return $status.Level -le $this.Config["LowBatteryThreshold"] -and
               -not $status.IsCharging -and
               $status.IsLaptop
    }
    
    [bool] ShouldAlertCritical() {
        $status = $this.GetBatteryStatus()
        
        return $status.Level -le $this.Config["CriticalBatteryThreshold"] -and
               -not $status.IsCharging -and
               $status.IsLaptop
    }
    
    [string] GetBatteryMessage() {
        $status = $this.GetBatteryStatus()
        
        if (-not $status.IsLaptop) {
            return "Desktop PC - no battery to worry about!"
        }
        
        if ($status.IsCharging) {
            if ($status.Level -ge 90) {
                return "Almost fully charged! Ready to go!"
            }
            return "Charging... $($status.Level)%"
        }
        
        switch ($status.Status) {
            "Full" { return "Battery is full and ready!" }
            "Good" { return "Battery is in good shape." }
            "Normal" { return "Battery level is normal." }
            "Low" { return "Battery is getting low. Consider charging soon." }
            "Critical" { return "Battery critical! Find a charger ASAP!" }
            default { return "Battery at $($status.Level)%" }
        }
    }
    
    [hashtable] GetTodayBatteryStats() {
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        
        $stats = @{
            "Date" = $dateKey
            "AverageLevel" = 0
            "LowPoints" = 0
            "ChargingSessions" = 0
            "MinLevel" = 100
            "MaxLevel" = 0
        }
        
        if ($this.BatteryHistory.ContainsKey($dateKey)) {
            $history = $this.BatteryHistory[$dateKey]
            
            if ($history.Readings.Count -gt 0) {
                $levels = $history.Readings | ForEach-Object { $_.Level }
                $stats.AverageLevel = [Math]::Round(($levels | Measure-Object -Average).Average, 1)
                $stats.MinLevel = ($levels | Measure-Object -Minimum).Minimum
                $stats.MaxLevel = ($levels | Measure-Object -Maximum).Maximum
            }
            
            $stats.LowPoints = $history.LowPoints.Count
            $stats.ChargingSessions = $history.ChargingSessions
        }
        
        return $stats
    }
    
    [hashtable] GetWeeklyBatteryStats() {
        $weekStats = @{}
        
        for ($i = 6; $i -ge 0; $i--) {
            $date = (Get-Date).AddDays(-$i)
            $dateKey = $date.ToString("yyyy-MM-dd")
            
            if ($this.BatteryHistory.ContainsKey($dateKey)) {
                $history = $this.BatteryHistory[$dateKey]
                
                $avgLevel = 0
                if ($history.Readings.Count -gt 0) {
                    $levels = $history.Readings | ForEach-Object { $_.Level }
                    $avgLevel = [Math]::Round(($levels | Measure-Object -Average).Average, 1)
                }
                
                $weekStats[$dateKey] = @{
                    "AverageLevel" = $avgLevel
                    "ChargingSessions" = $history.ChargingSessions
                    "LowPoints" = $history.LowPoints.Count
                }
            } else {
                $weekStats[$dateKey] = @{
                    "AverageLevel" = 0
                    "ChargingSessions" = 0
                    "LowPoints" = 0
                }
            }
        }
        
        return $weekStats
    }
    
    [void] SetLowThreshold([int]$threshold) {
        $this.Config["LowBatteryThreshold"] = [Math]::Clamp($threshold, 5, 50)
    }
    
    [void] SetCriticalThreshold([int]$threshold) {
        $this.Config["CriticalBatteryThreshold"] = [Math]::Clamp($threshold, 1, 20)
    }
    
    [hashtable] GetBatteryState() {
        $status = $this.GetBatteryStatus()
        
        return @{
            "Enabled" = $this.Config["BatteryMonitorEnabled"]
            "Status" = $status
            "Message" = $this.GetBatteryMessage()
            "ShouldAlertLow" = $this.ShouldAlertLow()
            "ShouldAlertCritical" = $this.ShouldAlertCritical()
            "TodayStats" = $this.GetTodayBatteryStats()
            "WeeklyStats" = $this.GetWeeklyBatteryStats()
            "LowThreshold" = $this.Config["LowBatteryThreshold"]
            "CriticalThreshold" = $this.Config["CriticalBatteryThreshold"]
        }
    }
}

$gooseBattery = [GooseBattery]::new()

function Get-GooseBattery {
    return $gooseBattery
}

function Get-BatteryStatus {
    param($Battery = $gooseBattery)
    return $Battery.GetBatteryState()
}

function Set-BatteryThresholds {
    param(
        [int]$Low = 20,
        [int]$Critical = 10,
        $Battery = $gooseBattery
    )
    $Battery.SetLowThreshold($Low)
    $Battery.SetCriticalThreshold($Critical)
}

Write-Host "Desktop Goose Battery Monitor Initialized"
$state = Get-BatteryStatus
Write-Host "Battery Monitor: $($state['Enabled'])"
Write-Host "Battery Status: $($state['Status']['Level'])% ($($state['Status']['Status']))"
