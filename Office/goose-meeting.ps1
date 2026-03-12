# Desktop Goose Meeting Silence Mode
# Auto-trigger silence during meetings

class GooseMeetingSilence {
    [hashtable]$Config
    [bool]$IsInMeeting
    [bool]$AutoDetect
    [array]$MeetingKeywords
    [string]$MeetingApp
    
    GooseMeetingSilence() {
        $this.Config = $this.LoadConfig()
        $this.IsInMeeting = $false
        $this.AutoDetect = $true
        $this.MeetingKeywords = @("meeting", "zoom", "teams", "webex", "meet", "call", "conference")
        $this.MeetingApp = ""
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
        
        if (-not $this.Config.ContainsKey("MeetingSilenceEnabled")) {
            $this.Config["MeetingSilenceEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [bool] DetectMeeting() {
        if (-not $this.AutoDetect) {
            return $this.IsInMeeting
        }
        
        $runningProcesses = Get-Process | Select-Object -ExpandProperty ProcessName
        
        $meetingApps = @("zoom", "teams", "slack", "webex", "discord", "skype", "meet", "zoomus")
        
        foreach ($process in $runningProcesses) {
            foreach ($app in $meetingApps) {
                if ($process -like "*$app*") {
                    $this.MeetingApp = $process
                    return $true
                }
            }
        }
        
        return $false
    }
    
    [hashtable] StartMeetingMode() {
        $this.IsInMeeting = $true
        
        return @{
            "Success" = $true
            "MeetingStarted" = $true
            "Message" = "Meeting mode activated. Goose will be quiet!"
        }
    }
    
    [hashtable] EndMeetingMode() {
        $this.IsInMeeting = $false
        $previousApp = $this.MeetingApp
        
        return @{
            "Success" = $true
            "MeetingEnded" = $true
            "MeetingApp" = $previousApp
            "Message" = "Meeting mode ended. Hello again!"
        }
    }
    
    [hashtable] CheckMeetingStatus() {
        $wasInMeeting = $this.IsInMeeting
        $nowInMeeting = $this.DetectMeeting()
        
        if ($nowInMeeting -and -not $wasInMeeting) {
            return @{
                "IsInMeeting" = $true
                "MeetingDetected" = $true
                "MeetingApp" = $this.MeetingApp
                "Transition" = "started"
                "ShouldActivate" = $true
            }
        }
        
        if (-not $nowInMeeting -and $wasInMeeting) {
            return @{
                "IsInMeeting" = $false
                "MeetingDetected" = $false
                "Transition" = "ended"
                "ShouldDeactivate" = $true
            }
        }
        
        return @{
            "IsInMeeting" = $nowInMeeting
            "MeetingDetected" = $nowInMeeting
            "MeetingApp" = if ($nowInMeeting) { $this.MeetingApp } else { "" }
            "Transition" = "none"
        }
    }
    
    [void] SetAutoDetect([bool]$enabled) {
        $this.AutoDetect = $enabled
    }
    
    [hashtable] GetMeetingSilenceState() {
        return @{
            "Enabled" = $this.Config["MeetingSilenceEnabled"]
            "IsInMeeting" = $this.IsInMeeting
            "AutoDetect" = $this.AutoDetect
            "MeetingApp" = $this.MeetingApp
            "MeetingKeywords" = $this.MeetingKeywords
        }
    }
}

$gooseMeetingSilence = [GooseMeetingSilence]::new()

function Get-GooseMeetingSilence {
    return $gooseMeetingSilence
}

function Test-MeetingStatus {
    param($MeetingSilence = $gooseMeetingSilence)
    return $MeetingSilence.CheckMeetingStatus()
}

function Start-MeetingMode {
    param($MeetingSilence = $gooseMeetingSilence)
    return $MeetingSilence.StartMeetingMode()
}

function Stop-MeetingMode {
    param($MeetingSilence = $gooseMeetingSilence)
    return $MeetingSilence.EndMeetingMode()
}

function Get-MeetingSilenceState {
    param($MeetingSilence = $gooseMeetingSilence)
    return $MeetingSilence.GetMeetingSilenceState()
}

Write-Host "Desktop Goose Meeting Silence System Initialized"
$state = Get-MeetingSilenceState
Write-Host "Meeting Silence Enabled: $($state['Enabled'])"
Write-Host "In Meeting: $($state['IsInMeeting'])"
