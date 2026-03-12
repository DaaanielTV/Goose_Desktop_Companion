# Desktop Goose Screenshot Pose Mode System
# Goose poses for screenshots

class GooseScreenshotPose {
    [hashtable]$Config
    [bool]$IsPosing
    [string]$CurrentPose
    [array]$AvailablePoses
    
    GooseScreenshotPose() {
        $this.Config = $this.LoadConfig()
        $this.IsPosing = $false
        $this.CurrentPose = ""
        $this.InitializePoses()
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
    
    [void] InitializePoses() {
        $this.AvailablePoses = @(
            @{
                "Name" = "victory"
                "Description" = "Both wings raised in victory"
                "Animation" = "pose_victory"
            },
            @{
                "Name" = "cheer"
                "Description" = "Cheering with one wing"
                "Animation" = "pose_cheer"
            },
            @{
                "Name" = "bow"
                "Description" = "Bowing politely"
                "Animation" = "pose_bow"
            },
            @{
                "Name" = "wave"
                "Description" = "Waving hello"
                "Animation" = "pose_wave"
            },
            @{
                "Name" = "think"
                "Description" = "Looking thoughtful"
                "Animation" = "pose_think"
            },
            @{
                "Name" = "sleepy"
                "Description" = "Yawning and sleepy"
                "Animation" = "pose_sleepy"
            },
            @{
                "Name" = "dance"
                "Description" = "Dancing pose"
                "Animation" = "pose_dance"
            },
            @{
                "Name" = "salute"
                "Description" = "Military salute"
                "Animation" = "pose_salute"
            },
            @{
                "Name" = "heart"
                "Description" = "Making a heart shape with wings"
                "Animation" = "pose_heart"
            },
            @{
                "Name" = "shrug"
                "Description" = "Confused shrug"
                "Animation" = "pose_shrug"
            },
            @{
                "Name" = "clap"
                "Description" = "Clapping wings"
                "Animation" = "pose_clap"
            },
            @{
                "Name" = "fist"
                "Description" = "Goose fist bump"
                "Animation" = "pose_fist"
            }
        )
    }
    
    [hashtable] StrikePose([string]$poseName = "") {
        if ($poseName -eq "") {
            $pose = Get-Random -InputObject $this.AvailablePoses
        } else {
            $pose = $this.AvailablePoses | Where-Object { $_.Name -eq $poseName } | Select-Object -First 1
            
            if (-not $pose) {
                return @{
                    "Success" = $false
                    "Message" = "Pose '$poseName' not found"
                    "AvailablePoses" = ($this.AvailablePoses | ForEach-Object { $_.Name })
                }
            }
        }
        
        $this.IsPosing = $true
        $this.CurrentPose = $pose.Name
        
        return @{
            "Success" = $true
            "Pose" = $pose
            "Message" = "Say cheese! *strikes $('{0}' -f $pose.Name) pose*"
        }
    }
    
    [hashtable] StopPosing() {
        $this.IsPosing = $false
        $previousPose = $this.CurrentPose
        $this.CurrentPose = ""
        
        return @{
            "Success" = $true
            "PreviousPose" = $previousPose
            "Message" = "*returns to normal*"
        }
    }
    
    [array] GetAvailablePoses() {
        return $this.AvailablePoses
    }
    
    [hashtable] GetScreenshotPoseState() {
        return @{
            "IsPosing" = $this.IsPosing
            "CurrentPose" = $this.CurrentPose
            "AvailablePoses" = $this.AvailablePoses
            "PoseCount" = $this.AvailablePoses.Count
        }
    }
}

$gooseScreenshotPose = [GooseScreenshotPose]::new()

function Get-GooseScreenshotPose {
    return $gooseScreenshotPose
}

function Invoke-ScreenshotPose {
    param(
        [string]$PoseName = "",
        $ScreenshotPose = $gooseScreenshotPose
    )
    return $ScreenshotPose.StrikePose($PoseName)
}

function Stop-ScreenshotPose {
    param($ScreenshotPose = $gooseScreenshotPose)
    return $ScreenshotPose.StopPosing()
}

function Get-AvailablePoses {
    param($ScreenshotPose = $gooseScreenshotPose)
    return $ScreenshotPose.GetAvailablePoses()
}

function Get-ScreenshotPoseState {
    param($ScreenshotPose = $gooseScreenshotPose)
    return $ScreenshotPose.GetScreenshotPoseState()
}

Write-Host "Desktop Goose Screenshot Pose System Initialized"
$state = Get-ScreenshotPoseState
Write-Host "Available Poses: $($state['PoseCount'])"
Write-Host "Currently Posing: $($state['IsPosing'])"
