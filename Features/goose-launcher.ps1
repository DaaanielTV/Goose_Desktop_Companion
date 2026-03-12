# Desktop Goose App Launcher System
# Quick app launcher menu

class GooseAppLauncher {
    [hashtable]$Config
    [array]$Apps
    [string]$AppsFile
    
    GooseAppLauncher() {
        $this.Config = $this.LoadConfig()
        $this.AppsFile = "goose_apps.json"
        $this.Apps = @()
        $this.LoadApps()
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
        
        return $this.Config
    }
    
    [void] LoadApps() {
        if (Test-Path $this.AppsFile) {
            try {
                $this.Apps = Get-Content $this.AppsFile | ConvertFrom-Json
                if ($this.Apps -isnot [array]) {
                    $this.Apps = @()
                }
            } catch {
                $this.Apps = @()
            }
        }
        
        if ($this.Apps.Count -eq 0) {
            $this.AddDefaultApps()
        }
    }
    
    [void] SaveApps() {
        $this.Apps | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.AppsFile -Encoding UTF8
    }
    
    [void] AddDefaultApps() {
        $this.Apps = @(
            @{
                "Name" = "Notepad"
                "Path" = "notepad.exe"
                "Icon" = "📝"
            },
            @{
                "Name" = "Calculator"
                "Path" = "calc.exe"
                "Icon" = "🧮"
            },
            @{
                "Name" = "Browser"
                "Path" = "msedge.exe"
                "Icon" = "🌐"
            },
            @{
                "Name" = "File Explorer"
                "Path" = "explorer.exe"
                "Icon" = "📁"
            }
        )
        $this.SaveApps()
    }
    
    [hashtable] AddApp([string]$name, [string]$path, [string]$icon = "📦") {
        $app = @{
            "Name" = $name
            "Path" = $path
            "Icon" = $icon
            "LaunchCount" = 0
        }
        
        $this.Apps += $app
        $this.SaveApps()
        
        return @{
            "Success" = $true
            "App" = $app
            "Message" = "App '$name' added"
        }
    }
    
    [hashtable] RemoveApp([string]$name) {
        $initialCount = $this.Apps.Count
        $this.Apps = $this.Apps | Where-Object { $_.Name -ne $name }
        
        if ($this.Apps.Count -lt $initialCount) {
            $this.SaveApps()
            return @{
                "Success" = $true
                "Message" = "App '$name' removed"
            }
        }
        
        return @{
            "Success" = $false
            "Message" = "App not found"
        }
    }
    
    [hashtable] LaunchApp([string]$name) {
        $app = $this.Apps | Where-Object { $_.Name -eq $name } | Select-Object -First 1
        
        if (-not $app) {
            return @{
                "Success" = $false
                "Message" = "App '$name' not found"
            }
        }
        
        try {
            Start-Process -FilePath $app.Path
            $app.LaunchCount++
            $this.SaveApps()
            
            return @{
                "Success" = $true
                "App" = $app
                "Message" = "Launched $($app.Name)"
            }
        } catch {
            return @{
                "Success" = $false
                "Message" = "Failed to launch: $($_.Exception.Message)"
            }
        }
    }
    
    [array] GetApps() {
        return $this.Apps
    }
    
    [array] SearchApps([string]$query) {
        return $this.Apps | Where-Object { $_.Name -like "*$query*" }
    }
    
    [hashtable] GetAppLauncherState() {
        return @{
            "Apps" = $this.Apps
            "AppCount" = $this.Apps.Count
            "MostLaunched" = ($this.Apps | Sort-Object LaunchCount -Descending | Select-Object -First 3)
        }
    }
}

$gooseAppLauncher = [GooseAppLauncher]::new()

function Get-GooseAppLauncher {
    return $gooseAppLauncher
}

function Add-AppToLauncher {
    param(
        [string]$Name,
        [string]$Path,
        [string]$Icon = "📦",
        $Launcher = $gooseAppLauncher
    )
    return $Launcher.AddApp($Name, $Path, $Icon)
}

function Launch-App {
    param(
        [string]$Name,
        $Launcher = $gooseAppLauncher
    )
    return $Launcher.LaunchApp($Name)
}

function Get-LauncherApps {
    param($Launcher = $gooseAppLauncher)
    return $Launcher.GetApps()
}

function Get-AppLauncherState {
    param($Launcher = $gooseAppLauncher)
    return $Launcher.GetAppLauncherState()
}

Write-Host "Desktop Goose App Launcher System Initialized"
$state = Get-AppLauncherState
Write-Host "Available Apps: $($state['AppCount'])"
