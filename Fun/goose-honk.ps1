# Desktop Goose Voice Honk Reactions System
# Goose makes honk sounds on user actions

class GooseVoiceHonk {
    [hashtable]$Config
    [bool]$HonkEnabled
    [int]$HonkVolume
    [hashtable]$ActionHonks
    
    GooseVoiceHonk() {
        $this.Config = $this.LoadConfig()
        $this.HonkEnabled = $false
        $this.HonkVolume = 50
        $this.InitializeHonks()
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
        
        if (-not $this.Config.ContainsKey("VoiceHonkEnabled")) {
            $this.Config["VoiceHonkEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] InitializeHonks() {
        $this.ActionHonks = @{
            "click" = @{
                "Trigger" = "click"
                "HonkType" = "short"
                "Probability" = 30
                "Message" = "*honk*"
            }
            "doubleclick" = @{
                "Trigger" = "doubleclick"
                "HonkType" = "excited"
                "Probability" = 50
                "Message" = "*HONK HONK!*"
            }
            "drag" = @{
                "Trigger" = "drag"
                "HonkType" = "curious"
                "Probability" = 20
                "Message" = "*honk?*"
            }
            "drop" = @{
                "Trigger" = "drop"
                "HonkType" = "happy"
                "Probability" = 40
                "Message" = "*honk!*"
            }
            "startwork" = @{
                "Trigger" = "startwork"
                "HonkType" = "encouraging"
                "Probability" = 60
                "Message" = "*HONK!* Good luck!"
            }
            "endwork" = @{
                "Trigger" = "endwork"
                "HonkType" = "celebration"
                "Probability" = 70
                "Message" = "*HONK HONK!* Time to rest!"
            }
            "notification" = @{
                "Trigger" = "notification"
                "HonkType" = "alert"
                "Probability" = 25
                "Message" = "*honk*"
            }
            "meeting" = @{
                "Trigger" = "meeting"
                "HonkType" = "quiet"
                "Probability" = 40
                "Message" = "*soft honk*"
            }
            "break" = @{
                "Trigger" = "break"
                "HonkType" = "excited"
                "Probability" = 80
                "Message" = "*HONK HONK!* Break time!"
            }
            "error" = @{
                "Trigger" = "error"
                "HonkType" = "worried"
                "Probability" = 50
                "Message" = "*honk honk* Are you okay?"
            }
            "success" = @{
                "Trigger" = "success"
                "HonkType" = "happy"
                "Probability" = 60
                "Message" = "*HONK!* Great job!"
            }
            "typing" = @{
                "Trigger" = "typing"
                "HonkType" = "rhythmic"
                "Probability" = 15
                "Message" = "*honk honk honk*"
            }
        }
    }
    
    [hashtable] TriggerHonk([string]$action) {
        if (-not $this.HonkEnabled) {
            return @{
                "Success" = $false
                "HonkPlayed" = $false
                "Message" = "Honks are disabled"
            }
        }
        
        if (-not $this.ActionHonks.ContainsKey($action)) {
            return @{
                "Success" = $false
                "Message" = "Unknown action: $action"
            }
        }
        
        $honkConfig = $this.ActionHonks[$action]
        $roll = Get-Random -Minimum 1 -Maximum 101
        
        if ($roll -le $honkConfig.Probability) {
            return @{
                "Success" = $true
                "HonkPlayed" = $true
                "HonkType" = $honkConfig.HonkType
                "Message" = $honkConfig.Message
                "Volume" = $this.HonkVolume
            }
        }
        
        return @{
            "Success" = $true
            "HonkPlayed" = $false
            "Message" = "Goose decided not to honk this time"
        }
    }
    
    [void] SetHonkEnabled([bool]$enabled) {
        $this.HonkEnabled = $enabled
    }
    
    [void] SetHonkVolume([int]$volume) {
        $this.HonkVolume = [Math]::Min(100, [Math]::Max(0, $volume))
    }
    
    [void] SetActionProbability([string]$action, [int]$probability) {
        if ($this.ActionHonks.ContainsKey($action)) {
            $this.ActionHonks[$action].Probability = [Math]::Min(100, [Math]::Max(0, $probability))
        }
    }
    
    [array] GetActionHonks() {
        $honks = @()
        foreach ($key in $this.ActionHonks.Keys) {
            $honks += @{
                "Action" = $key
                "HonkType" = $this.ActionHonks[$key].HonkType
                "Probability" = $this.ActionHonks[$key].Probability
            }
        }
        return $honks
    }
    
    [hashtable] GetVoiceHonkState() {
        return @{
            "HonkEnabled" = $this.HonkEnabled
            "HonkVolume" = $this.HonkVolume
            "AvailableHonks" = $this.GetActionHonks()
        }
    }
}

$gooseVoiceHonk = [GooseVoiceHonk]::new()

function Get-GooseVoiceHonk {
    return $gooseVoiceHonk
}

function Invoke-Honk {
    param(
        [string]$Action,
        $VoiceHonk = $gooseVoiceHonk
    )
    return $VoiceHonk.TriggerHonk($Action)
}

function Enable-Honks {
    param(
        [bool]$Enabled = $true,
        $VoiceHonk = $gooseVoiceHonk
    )
    $VoiceHonk.SetHonkEnabled($Enabled)
}

function Set-HonkVolume {
    param(
        [int]$Volume,
        $VoiceHonk = $gooseVoiceHonk
    )
    $VoiceHonk.SetHonkVolume($Volume)
}

function Get-VoiceHonkState {
    param($VoiceHonk = $gooseVoiceHonk)
    return $VoiceHonk.GetVoiceHonkState()
}

Write-Host "Desktop Goose Voice Honk System Initialized"
$state = Get-VoiceHonkState
Write-Host "Honks Enabled: $($state['HonkEnabled'])"
Write-Host "Honk Volume: $($state['HonkVolume'])"
