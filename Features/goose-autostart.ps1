# Desktop Goose Auto-Start System
# Auto-start with Windows

class GooseAutoStart {
    [hashtable]$Config
    [string]$AppName
    [string]$AppPath
    
    GooseAutoStart() {
        $this.Config = $this.LoadConfig()
        $this.AppName = "DesktopGoose"
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
    
    [bool] IsAutoStartEnabled() {
        $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        
        if (Test-Path $path) {
            $value = Get-ItemProperty -Path $path -Name $this.AppName -ErrorAction SilentlyContinue
            return ($null -ne $value)
        }
        
        return $false
    }
    
    [hashtable] EnableAutoStart([string]$exePath = "") {
        if ($exePath -eq "") {
            $exePath = Join-Path (Get-Location) "GooseDesktop.exe"
        }
        
        if (-not (Test-Path $exePath)) {
            return @{
                "Success" = $false
                "Message" = "Executable not found: $exePath"
            }
        }
        
        try {
            $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
            Set-ItemProperty -Path $path -Name $this.AppName -Value "`"$exePath`""
            
            return @{
                "Success" = $true
                "Message" = "Auto-start enabled"
                "ExePath" = $exePath
            }
        } catch {
            return @{
                "Success" = $false
                "Message" = "Failed to enable: $($_.Exception.Message)"
            }
        }
    }
    
    [hashtable] DisableAutoStart() {
        try {
            $path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
            Remove-ItemProperty -Path $path -Name $this.AppName -ErrorAction SilentlyContinue
            
            return @{
                "Success" = $true
                "Message" = "Auto-start disabled"
            }
        } catch {
            return @{
                "Success" = $false
                "Message" = "Failed to disable: $($_.Exception.Message)"
            }
        }
    }
    
    [hashtable] ToggleAutoStart([string]$exePath = "") {
        if ($this.IsAutoStartEnabled()) {
            return $this.DisableAutoStart()
        } else {
            return $this.EnableAutoStart($exePath)
        }
    }
    
    [hashtable] GetAutoStartState() {
        return @{
            "AppName" = $this.AppName
            "IsEnabled" = $this.IsAutoStartEnabled()
            "RegistryPath" = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
        }
    }
}

$gooseAutoStart = [GooseAutoStart]::new()

function Get-GooseAutoStart {
    return $gooseAutoStart
}

function Enable-GooseAutoStart {
    param(
        [string]$ExePath = "",
        $AutoStart = $gooseAutoStart
    )
    return $AutoStart.EnableAutoStart($ExePath)
}

function Disable-GooseAutoStart {
    param($AutoStart = $gooseAutoStart)
    return $AutoStart.DisableAutoStart()
}

function Toggle-GooseAutoStart {
    param(
        [string]$ExePath = "",
        $AutoStart = $gooseAutoStart
    )
    return $AutoStart.ToggleAutoStart($ExePath)
}

function Get-AutoStartState {
    param($AutoStart = $gooseAutoStart)
    return $AutoStart.GetAutoStartState()
}

Write-Host "Desktop Goose Auto-Start System Initialized"
$state = Get-AutoStartState
Write-Host "Auto-Start Enabled: $($state['IsEnabled'])"
