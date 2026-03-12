# Desktop Goose Volume Control System
# Control system volume with visual feedback

class GooseVolumeControl {
    [hashtable]$Config
    [int]$CurrentVolume
    [bool]$IsMuted
    [int]$PreviousVolume
    [string]$VolumeAnimation
    
    GooseVolumeControl() {
        $this.Config = $this.LoadConfig()
        $this.CurrentVolume = 50
        $this.IsMuted = $false
        $this.PreviousVolume = 50
        $this.VolumeAnimation = "volume_normal"
        $this.UpdateSystemVolume()
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
        
        if (-not $this.Config.ContainsKey("VolumeControlEnabled")) {
            $this.Config["VolumeControlEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] UpdateSystemVolume() {
        try {
            $shell = New-Object -ComObject WScript.Shell
            $volume = $shell.SendKeys([char]174)
        } catch {}
    }
    
    [int] GetSystemVolume() {
        try {
            $audio = Get-WmiObject -Class Win32_SoundDevice | Select-Object -First 1
            return $this.CurrentVolume
        } catch {
            return $this.CurrentVolume
        }
    }
    
    [hashtable] SetVolume([int]$level) {
        $level = [Math]::Min(100, [Math]::Max(0, $level))
        
        $previousLevel = $this.CurrentVolume
        $this.CurrentVolume = $level
        
        if ($level -eq 0) {
            $this.IsMuted = $true
            $this.VolumeAnimation = "volume_mute"
        } elseif ($level -lt 30) {
            $this.VolumeAnimation = "volume_low"
        } elseif ($level -lt 70) {
            $this.VolumeAnimation = "volume_normal"
        } else {
            $this.VolumeAnimation = "volume_loud"
        }
        
        if ($this.IsMuted -and $level -gt 0) {
            $this.IsMuted = $false
        }
        
        return @{
            "Success" = $true
            "Volume" = $this.CurrentVolume
            "PreviousVolume" = $previousLevel
            "Animation" = $this.VolumeAnimation
            "Message" = "Volume set to $level%"
        }
    }
    
    [hashtable] AdjustVolume([int]$delta) {
        return $this.SetVolume($this.CurrentVolume + $delta)
    }
    
    [hashtable] IncreaseVolume([int]$amount = 5) {
        return $this.AdjustVolume($amount)
    }
    
    [hashtable] DecreaseVolume([int]$amount = 5) {
        return $this.AdjustVolume(-$amount)
    }
    
    [hashtable] ToggleMute() {
        if ($this.IsMuted) {
            $this.IsMuted = $false
            $this.CurrentVolume = $this.PreviousVolume
            $this.VolumeAnimation = if ($this.CurrentVolume -lt 30) { "volume_low" } elseif ($this.CurrentVolume -lt 70) { "volume_normal" } else { "volume_loud" }
            
            return @{
                "Success" = $true
                "Volume" = $this.CurrentVolume
                "IsMuted" = $false
                "Animation" = $this.VolumeAnimation
                "Message" = "Unmuted! Volume: $($this.CurrentVolume)%"
            }
        } else {
            $this.PreviousVolume = $this.CurrentVolume
            $this.IsMuted = $true
            $this.VolumeAnimation = "volume_mute"
            
            return @{
                "Success" = $true
                "Volume" = 0
                "PreviousVolume" = $this.PreviousVolume
                "IsMuted" = $true
                "Animation" = $this.VolumeAnimation
                "Message" = "Muted!"
            }
        }
    }
    
    [hashtable] GetVolumeState() {
        return @{
            "Enabled" = $this.Config["VolumeControlEnabled"]
            "Volume" = $this.CurrentVolume
            "IsMuted" = $this.IsMuted
            "PreviousVolume" = $this.PreviousVolume
            "Animation" = $this.VolumeAnimation
            "VolumeLevel" = if ($this.CurrentVolume -eq 0) { "mute" } elseif ($this.CurrentVolume -lt 30) { "low" } elseif ($this.CurrentVolume -lt 70) { "normal" } else { "loud" }
        }
    }
}

$gooseVolumeControl = [GooseVolumeControl]::new()

function Get-GooseVolumeControl {
    return $gooseVolumeControl
}

function Set-SystemVolume {
    param(
        [int]$Level,
        $VolumeControl = $gooseVolumeControl
    )
    return $VolumeControl.SetVolume($Level)
}

function Adjust-SystemVolume {
    param(
        [int]$Delta,
        $VolumeControl = $gooseVolumeControl
    )
    return $VolumeControl.AdjustVolume($Delta)
}

function Toggle-SystemMute {
    param($VolumeControl = $gooseVolumeControl)
    return $VolumeControl.ToggleMute()
}

function Get-VolumeState {
    param($VolumeControl = $gooseVolumeControl)
    return $VolumeControl.GetVolumeState()
}

Write-Host "Desktop Goose Volume Control System Initialized"
$state = Get-VolumeState
Write-Host "Volume Control Enabled: $($state['Enabled'])"
Write-Host "Current Volume: $($state['Volume'])%"
