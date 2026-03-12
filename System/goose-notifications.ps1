# Desktop Goose Notification Mimicry System
# Goose mimics notification popups

class GooseNotificationMimicry {
    [hashtable]$Config
    [bool]$IsMimicking
    [string]$CurrentNotificationType
    [array]$NotificationTypes
    [int]$MimicChance
    [int]$CooldownMinutes
    
    GooseNotificationMimicry() {
        $this.Config = $this.LoadConfig()
        $this.IsMimicking = $false
        $this.CurrentNotificationType = ""
        $this.MimicChance = 10
        $this.CooldownMinutes = 15
        
        $this.InitializeNotificationTypes()
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
        
        if (-not $this.Config.ContainsKey("NotificationMimicryEnabled")) {
            $this.Config["NotificationMimicryEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] InitializeNotificationTypes() {
        $this.NotificationTypes = @(
            @{
                "Type" = "email"
                "Title" = "New Email"
                "Message" = "You have a new message!"
                "Icon" = "email"
                "Animation" = "notify_email"
            },
            @{
                "Type" = "message"
                "Type" = "message"
                "Title" = "New Message"
                "Message" = "Someone sent you a message"
                "Icon" = "chat"
                "Animation" = "notify_message"
            },
            @{
                "Type" = "reminder"
                "Title" = "Reminder"
                "Message" = "Don't forget to take a break!"
                "Icon" = "alarm"
                "Animation" = "notify_reminder"
            },
            @{
                "Type" = "update"
                "Title" = "Update Available"
                "Message" = "A new version is ready"
                "Icon" = "download"
                "Animation" = "notify_update"
            },
            @{
                "Type" = "success"
                "Title" = "Success!"
                "Message" = "Task completed successfully"
                "Icon" = "check"
                "Animation" = "notify_success"
            },
            @{
                "Type" = "warning"
                "Title" = "Warning"
                "Message" = "Something needs attention"
                "Icon" = "alert"
                "Animation" = "notify_warning"
            },
            @{
                "Type" = "achievement"
                "Title" = "Achievement Unlocked!"
                "Message" = "You earned a new achievement"
                "Icon" = "trophy"
                "Animation" = "notify_achievement"
            },
            @{
                "Type" = "social"
                "Title" = "New Follower"
                "Message" = "Someone followed you!"
                "Icon" = "user"
                "Animation" = "notify_social"
            }
        )
    }
    
    [hashtable] TriggerMimicry([string]$type = "") {
        if ($this.IsMimicking) {
            return @{
                "Success" = $false
                "Message" = "Already mimicking a notification"
            }
        }
        
        $notification = $null
        
        if ($type -ne "") {
            $notification = $this.NotificationTypes | Where-Object { $_.Type -eq $type } | Select-Object -First 1
        }
        
        if (-not $notification) {
            $notification = Get-Random -InputObject $this.NotificationTypes
        }
        
        $this.IsMimicking = $true
        $this.CurrentNotificationType = $notification.Type
        
        return @{
            "Success" = $true
            "Notification" = $notification
            "Animation" = $notification.Animation
            "Message" = $notification.Message
            "Title" = $notification.Title
        }
    }
    
    [bool] ShouldAutoMimic() {
        $roll = Get-Random -Minimum 1 -Maximum 101
        return ($roll -le $this.MimicChance)
    }
    
    [void] StopMimicry() {
        $this.IsMimicking = $false
        $this.CurrentNotificationType = ""
    }
    
    [void] SetMimicChance([int]$chance) {
        $this.MimicChance = [Math]::Min(100, [Math]::Max(0, $chance))
    }
    
    [void] SetCooldown([int]$minutes) {
        $this.CooldownMinutes = $minutes
    }
    
    [hashtable] GetNotificationTypes() {
        return $this.NotificationTypes
    }
    
    [hashtable] GetNotificationMimicryState() {
        return @{
            "Enabled" = $this.Config["NotificationMimicryEnabled"]
            "IsMimicking" = $this.IsMimicking
            "CurrentNotificationType" = $this.CurrentNotificationType
            "MimicChance" = $this.MimicChance
            "CooldownMinutes" = $this.CooldownMinutes
            "AvailableTypes" = ($this.NotificationTypes | ForEach-Object { $_.Type })
        }
    }
}

$gooseNotificationMimicry = [GooseNotificationMimicry]::new()

function Get-GooseNotificationMimicry {
    return $gooseNotificationMimicry
}

function Invoke-NotificationMimicry {
    param(
        [string]$Type = "",
        $Mimicry = $gooseNotificationMimicry
    )
    return $Mimicry.TriggerMimicry($Type)
}

function Stop-NotificationMimicry {
    param($Mimicry = $gooseNotificationMimicry)
    $Mimicry.StopMimicry()
}

function Get-NotificationMimicryState {
    param($Mimicry = $gooseNotificationMimicry)
    return $Mimicry.GetNotificationMimicryState()
}

Write-Host "Desktop Goose Notification Mimicry System Initialized"
$state = Get-NotificationMimicryState
Write-Host "Notification Mimicry Enabled: $($state['Enabled'])"
Write-Host "Mimic Chance: $($state['MimicChance'])%"
