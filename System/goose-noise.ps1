class GooseNoiseAlert {
    [hashtable]$Config
    [bool]$IsMonitoring
    [datetime]$LastAlertTime
    [int]$AlertCount
    [hashtable]$AlertHistory
    [string]$CurrentEnvironment
    
    GooseNoiseAlert() {
        $this.Config = $this.LoadConfig()
        $this.IsMonitoring = $false
        $this.LastAlertTime = Get-Date
        $this.AlertCount = 0
        $this.AlertHistory = @{}
        $this.CurrentEnvironment = "Quiet"
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
        
        if (-not $this.Config.ContainsKey("NoiseAlertEnabled")) {
            $this.Config["NoiseAlertEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("NoiseSensitivity")) {
            $this.Config["NoiseSensitivity"] = "Medium"
        }
        
        return $this.Config
    }
    
    [void] StartMonitoring() {
        $this.IsMonitoring = $true
    }
    
    [void] StopMonitoring() {
        $this.IsMonitoring = $false
    }
    
    [void] ToggleMonitoring() {
        $this.IsMonitoring = -not $this.IsMonitoring
    }
    
    [string] DetectEnvironment() {
        $hour = (Get-Date).Hour
        
        if ($hour -ge 22 -or $hour -lt 6) {
            $this.CurrentEnvironment = "Night"
        } elseif ($hour -ge 18 -or $hour -lt 9) {
            $this.CurrentEnvironment = "Evening"
        } elseif ($hour -ge 9 -or $hour -lt 17) {
            $this.CurrentEnvironment = "WorkHours"
        } else {
            $this.CurrentEnvironment = "Morning"
        }
        
        return $this.CurrentEnvironment
    }
    
    [bool] ShouldAlert() {
        if (-not $this.IsMonitoring) { return $false }
        
        $minutesSinceAlert = ((Get-Date) - $this.LastAlertTime).TotalMinutes
        
        return $minutesSinceAlert -ge 5
    }
    
    [void] TriggerAlert([string]$alertType, [string]$message = "") {
        $this.LastAlertTime = Get-Date
        $this.AlertCount++
        
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        
        if (-not $this.AlertHistory.ContainsKey($dateKey)) {
            $this.AlertHistory[$dateKey] = @()
        }
        
        $this.AlertHistory[$dateKey] += @{
            "Type" = $alertType
            "Message" = $message
            "Timestamp" = (Get-Date).ToString("o")
            "Environment" = $this.CurrentEnvironment
        }
    }
    
    [hashtable] GetNoiseLevel() {
        $sensitivity = $this.Config["NoiseSensitivity"]
        $env = $this.DetectEnvironment()
        
        $baseLevel = 30
        
        switch ($sensitivity) {
            "High" { $baseLevel = 20 }
            "Medium" { $baseLevel = 30 }
            "Low" { $baseLevel = 45 }
        }
        
        switch ($env) {
            "Night" { $baseLevel = [Math]::Max(10, $baseLevel - 15) }
            "WorkHours" { $baseLevel = [Math]::Max(20, $baseLevel - 5) }
        }
        
        $timeOfDay = (Get-Date).Hour
        $isWeekend = (Get-Date).DayOfWeek -eq "Saturday" -or (Get-Date).DayOfWeek -eq "Sunday"
        
        if ($isWeekend) {
            $baseLevel += 10
        }
        
        return @{
            "Level" = $baseLevel
            "Environment" = $env
            "Sensitivity" = $sensitivity
            "IsQuietHours" = ($env -eq "Night")
        }
    }
    
    [string] GetAlertMessage([string]$type) {
        $messages = @{
            "Focus" = "Time to focus! I'll stay quiet."
            "Meeting" = "Meeting detected! Shhh..."
            "Quiet" = "It's quiet time. Being peaceful."
            "Break" = "You've been working hard. Take a moment!"
            "Night" = "Late night hours. Being extra quiet!"
        }
        
        if ($messages.ContainsKey($type)) {
            return $messages[$type]
        }
        
        return "Being a good companion!"
    }
    
    [hashtable] GetTodayAlerts() {
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        
        if ($this.AlertHistory.ContainsKey($dateKey)) {
            return $this.AlertHistory[$dateKey]
        }
        
        return @()
    }
    
    [hashtable] GetWeeklyAlertStats() {
        $weekStats = @{}
        
        for ($i = 6; $i -ge 0; $i--) {
            $date = (Get-Date).AddDays(-$i)
            $dateKey = $date.ToString("yyyy-MM-dd")
            
            if ($this.AlertHistory.ContainsKey($dateKey)) {
                $weekStats[$dateKey] = $this.AlertHistory[$dateKey].Count
            } else {
                $weekStats[$dateKey] = 0
            }
        }
        
        return $weekStats
    }
    
    [void] SetSensitivity([string]$sensitivity) {
        $valid = @("High", "Medium", "Low")
        
        if ($valid -contains $sensitivity) {
            $this.Config["NoiseSensitivity"] = $sensitivity
        }
    }
    
    [void] SetEnvironment([string]$env) {
        $valid = @("Quiet", "Normal", "Active", "Party")
        
        if ($valid -contains $env) {
            $this.CurrentEnvironment = $env
        }
    }
    
    [hashtable] GetNoiseAlertState() {
        return @{
            "Enabled" = $this.Config["NoiseAlertEnabled"]
            "IsMonitoring" = $this.IsMonitoring
            "CurrentEnvironment" = $this.DetectEnvironment()
            "NoiseLevel" = $this.GetNoiseLevel()
            "AlertCount" = $this.AlertCount
            "TodayAlerts" = $this.GetTodayAlerts()
            "WeeklyStats" = $this.GetWeeklyAlertStats()
            "LastAlertTime" = $this.LastAlertTime
            "ShouldAlert" = $this.ShouldAlert()
            "CurrentMessage" = $this.GetAlertMessage($this.CurrentEnvironment)
        }
    }
}

$gooseNoiseAlert = [GooseNoiseAlert]::new()

function Get-GooseNoiseAlert {
    return $gooseNoiseAlert
}

function Start-NoiseMonitoring {
    param($NoiseAlert = $gooseNoiseAlert)
    $NoiseAlert.StartMonitoring()
}

function Stop-NoiseMonitoring {
    param($NoiseAlert = $gooseNoiseAlert)
    $NoiseAlert.StopMonitoring()
}

function Toggle-NoiseMonitoring {
    param($NoiseAlert = $gooseNoiseAlert)
    $NoiseAlert.ToggleMonitoring()
    return $NoiseAlert.IsMonitoring
}

function Get-NoiseStatus {
    param($NoiseAlert = $gooseNoiseAlert)
    return $NoiseAlert.GetNoiseAlertState()
}

function Set-NoiseSensitivity {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Sensitivity,
        $NoiseAlert = $gooseNoiseAlert
    )
    $NoiseAlert.SetSensitivity($Sensitivity)
}

Write-Host "Desktop Goose Noise Alert System Initialized"
$state = Get-NoiseStatus
Write-Host "Noise Alert Enabled: $($state['Enabled'])"
Write-Host "Current Environment: $($state['CurrentEnvironment'])"
