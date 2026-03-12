class GooseAppStats {
    [hashtable]$Config
    [hashtable]$AppUsage
    [string]$CurrentApp
    [datetime]$CurrentAppStart
    [bool]$IsTracking
    
    GooseAppStats() {
        $this.Config = $this.LoadConfig()
        $this.AppUsage = @{}
        $this.CurrentApp = ""
        $this.CurrentAppStart = Get-Date
        $this.IsTracking = $false
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
        
        if (-not $this.Config.ContainsKey("AppStatsEnabled")) {
            $this.Config["AppStatsEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] LoadData() {
        $dataFile = "goose_appstats.json"
        
        if (Test-Path $dataFile) {
            try {
                $data = Get-Content $dataFile -Raw | ConvertFrom-Json
                $this.AppUsage = @{}
                
                if ($data.AppUsage) {
                    $data.AppUsage.PSObject.Properties | ForEach-Object {
                        $this.AppUsage[$_.Name] = $_.Value
                    }
                }
                
                $this.CleanOldData()
            } catch {}
        }
    }
    
    [void] SaveData() {
        $this.CleanOldData()
        
        $data = @{
            "AppUsage" = $this.AppUsage
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content "goose_appstats.json"
    }
    
    [void] CleanOldData() {
        $cutoffDate = (Get-Date).AddDays(-30).ToString("yyyy-MM-dd")
        $keysToRemove = @()
        
        foreach ($key in $this.AppUsage.Keys) {
            if ($key -lt $cutoffDate) {
                $keysToRemove += $key
            }
        }
        
        foreach ($key in $keysToRemove) {
            $this.AppUsage.Remove($key)
        }
    }
    
    [void] StartTracking() {
        $this.IsTracking = $true
        $this.CurrentAppStart = Get-Date
    }
    
    [void] StopTracking() {
        $this.IsTracking = $false
    }
    
    [void] RecordAppSwitch([string]$appName) {
        if ($this.CurrentApp -ne "" -and $this.IsTracking) {
            $duration = ((Get-Date) - $this.CurrentAppStart).TotalSeconds
            $this.AddUsage($this.CurrentApp, $duration)
        }
        
        $this.CurrentApp = $appName
        $this.CurrentAppStart = Get-Date
    }
    
    [void] AddUsage([string]$appName, [double]$seconds) {
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        
        if (-not $this.AppUsage.ContainsKey($dateKey)) {
            $this.AppUsage[$dateKey] = @{}
        }
        
        if (-not $this.AppUsage[$dateKey].ContainsKey($appName)) {
            $this.AppUsage[$dateKey][$appName] = 0
        }
        
        $this.AppUsage[$dateKey][$appName] += $seconds
        $this.SaveData()
    }
    
    [hashtable] GetTodayStats() {
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        
        if (-not $this.AppUsage.ContainsKey($dateKey)) {
            return @{
                "Date" = $dateKey
                "TotalApps" = 0
                "TotalTime" = 0
                "TopApps" = @()
                "Categories" = @{}
            }
        }
        
        $apps = $this.AppUsage[$dateKey]
        $totalTime = ($apps.Values | Measure-Object -Sum).Sum
        
        $sortedApps = $apps.GetEnumerator() | Sort-Object { $_.Value } -Descending
        
        $topApps = @()
        foreach ($app in $sortedApps | Select-Object -First 5) {
            $topApps += @{
                "Name" = $app.Key
                "Minutes" = [Math]::Round($app.Value / 60, 1)
                "Hours" = [Math]::Round($app.Value / 3600, 2)
                "Percent" = if ($totalTime -gt 0) { [Math]::Round(($app.Value / $totalTime) * 100, 1) } else { 0 }
            }
        }
        
        return @{
            "Date" = $dateKey
            "TotalApps" = $apps.Count
            "TotalTime" = [Math]::Round($totalTime / 3600, 2)
            "TopApps" = $topApps
        }
    }
    
    [hashtable] GetWeeklyStats() {
        $weekStats = @{}
        
        for ($i = 6; $i -ge 0; $i--) {
            $date = (Get-Date).AddDays(-$i)
            $dateKey = $date.ToString("yyyy-MM-dd")
            
            if ($this.AppUsage.ContainsKey($dateKey)) {
                $apps = $this.AppUsage[$dateKey]
                $totalTime = ($apps.Values | Measure-Object -Sum).Sum
                
                $weekStats[$dateKey] = @{
                    "TotalHours" = [Math]::Round($totalTime / 3600, 2)
                    "AppCount" = $apps.Count
                }
            } else {
                $weekStats[$dateKey] = @{
                    "TotalHours" = 0
                    "AppCount" = 0
                }
            }
        }
        
        return $weekStats
    }
    
    [hashtable] GetAllTimeStats() {
        $allTimeStats = @{}
        
        foreach ($date in $this.AppUsage.Keys) {
            foreach ($app in $this.AppUsage[$date].Keys) {
                if (-not $allTimeStats.ContainsKey($app)) {
                    $allTimeStats[$app] = 0
                }
                $allTimeStats[$app] += $this.AppUsage[$date][$app]
            }
        }
        
        $sortedApps = $allTimeStats.GetEnumerator() | Sort-Object { $_.Value } -Descending
        
        $topApps = @()
        foreach ($app in $sortedApps | Select-Object -First 10) {
            $topApps += @{
                "Name" = $app.Key
                "Hours" = [Math]::Round($app.Value / 3600, 1)
            }
        }
        
        $totalTime = ($allTimeStats.Values | Measure-Object -Sum).Sum
        
        return @{
            "TotalApps" = $allTimeStats.Count
            "TotalHours" = [Math]::Round($totalTime / 3600, 1)
            "TopApps" = $topApps
        }
    }
    
    [string] GetProductivityInsight() {
        $today = $this.GetTodayStats()
        
        if ($today.TotalApps -eq 0) {
            return "Start using some apps to get insights!"
        }
        
        $productiveApps = @("code", "studio", "terminal", "powershell", "excel", "word", "outlook")
        $distractingApps = @("youtube", "netflix", "facebook", "twitter", "reddit", "tiktok", "discord")
        
        $productiveTime = 0
        $distractingTime = 0
        
        foreach ($app in $today.TopApps) {
            $appLower = $app.Name.ToLower()
            
            foreach ($prod in $productiveApps) {
                if ($appLower -like "*$prod*") {
                    $productiveTime += $app.Minutes
                    break
                }
            }
            
            foreach ($dist in $distractingApps) {
                if ($appLower -like "*$dist*") {
                    $distractingTime += $app.Minutes
                    break
                }
            }
        }
        
        if ($productiveTime -gt $distractingTime * 2) {
            return "Great productivity today! Keep it up!"
        } elseif ($distractingTime -gt $productiveTime) {
            return "Consider balancing your app usage with some focused work."
        } else {
            return "A good mix of productive and leisure time today!"
        }
    }
    
    [hashtable] GetCurrentSession() {
        $sessionTime = 0
        
        if ($this.CurrentApp -ne "") {
            $sessionTime = ((Get-Date) - $this.CurrentAppStart).TotalSeconds
        }
        
        return @{
            "CurrentApp" = $this.CurrentApp
            "SessionStart" = $this.CurrentAppStart
            "SessionMinutes" = [Math]::Round($sessionTime / 60, 1)
            "IsTracking" = $this.IsTracking
        }
    }
    
    [hashtable] GetAppStatsState() {
        return @{
            "Enabled" = $this.Config["AppStatsEnabled"]
            "IsTracking" = $this.IsTracking
            "CurrentSession" = $this.GetCurrentSession()
            "TodayStats" = $this.GetTodayStats()
            "WeeklyStats" = $this.GetWeeklyStats()
            "AllTimeStats" = $this.GetAllTimeStats()
            "ProductivityInsight" = $this.GetProductivityInsight()
        }
    }
}

$gooseAppStats = [GooseAppStats]::new()

function Get-GooseAppStats {
    return $gooseAppStats
}

function Start-AppTracking {
    param($AppStats = $gooseAppStats)
    $AppStats.StartTracking()
}

function Stop-AppTracking {
    param($AppStats = $gooseAppStats)
    $AppStats.StopTracking()
}

function Record-AppUsage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$AppName,
        $AppStats = $gooseAppStats
    )
    $AppStats.RecordAppSwitch($AppName)
}

function Get-AppStatsStatus {
    param($AppStats = $gooseAppStats)
    return $AppStats.GetAppStatsState()
}

Write-Host "Desktop Goose App Stats System Initialized"
$state = Get-AppStatsStatus
Write-Host "App Stats Enabled: $($state['Enabled'])"
Write-Host "Today's Top App: $($state['TodayStats']['TopApps'][0]['Name'])"
