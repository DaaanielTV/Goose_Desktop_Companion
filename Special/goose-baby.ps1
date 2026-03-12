# Desktop Goose Baby Companion System
# Allows spawning a baby goose that follows the parent

class GooseBaby {
    [hashtable]$Config
    [bool]$IsBabyActive
    [hashtable]$BabyState
    [int]$FollowDistance
    [string]$BabyMood
    
    GooseBaby() {
        $this.Config = $this.LoadConfig()
        $this.IsBabyActive = $false
        $this.FollowDistance = 50
        $this.BabyMood = "neutral"
        $this.BabyState = @{
            "Position" = @{ "X" = 0; "Y" = 0 }
            "Scale" = 0.5
            "Animation" = "following"
            "TrustLevel" = 0
            "IsFollowing" = $true
            "LastInteraction" = Get-Date
        }
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
        
        if (-not $this.Config.ContainsKey("EnableBabyGoose")) {
            $this.Config["EnableBabyGoose"] = $false
        }
        
        return $this.Config
    }
    
    [void] SpawnBaby([int]$x, [int]$y) {
        if (-not $this.Config["EnableBabyGoose"]) { return }
        
        $this.IsBabyActive = $true
        $this.BabyState.Position.X = $x
        $this.BabyState.Position.Y = $y
        $this.BabyState.TrustLevel = 0
        $this.BabyMood = "curious"
    }
    
    [void] DismissBaby() {
        $this.IsBabyActive = $false
        $this.BabyState.TrustLevel = 0
    }
    
    [void] UpdatePosition([int]$parentX, [int]$parentY) {
        if (-not $this.IsBabyActive) { return }
        
        $targetX = $parentX + $this.FollowDistance
        $targetY = $parentY + 20
        
        $this.BabyState.Position.X = $targetX
        $this.BabyState.Position.Y = $targetY
    }
    
    [void] UpdateBabyMood([string]$mood) {
        $this.BabyMood = $mood
        
        switch ($mood) {
            "happy" { $this.BabyState.Animation = "hop" }
            "sleepy" { $this.BabyState.Animation = "sleeping" }
            "curious" { $this.BabyState.Animation = "looking" }
            "playful" { $this.BabyState.Animation = "chasing" }
            "startled" { $this.BabyState.Animation = "hide" }
        }
    }
    
    [void] InteractWithBaby() {
        if (-not $this.IsBabyActive) { return }
        
        $this.BabyState.TrustLevel = [Math]::Min(100, $this.BabyState.TrustLevel + 10)
        $this.BabyState.LastInteraction = Get-Date
        $this.UpdateBabyMood("happy")
        
        if ($this.BabyState.TrustLevel -ge 50) {
            $this.UpdateBabyMood("playful")
        }
    }
    
    [hashtable] GetBabyState() {
        return @{
            "Enabled" = $this.Config["EnableBabyGoose"]
            "IsActive" = $this.IsBabyActive
            "Position" = $this.BabyState.Position.Clone()
            "Scale" = $this.BabyState.Scale
            "Animation" = $this.BabyState.Animation
            "TrustLevel" = $this.BabyState.TrustLevel
            "Mood" = $this.BabyMood
            "IsFollowing" = $this.BabyState.IsFollowing
            "FollowDistance" = $this.FollowDistance
        }
    }
    
    [void] SetFollowDistance([int]$distance) {
        $this.FollowDistance = [Math]::Max(20, [Math]::Min(200, $distance))
    }
    
    [void] ToggleFollowing() {
        $this.BabyState.IsFollowing = -not $this.BabyState.IsFollowing
    }
    
    [string] GetBabyGreeting() {
        if (-not $this.IsBabyActive) { return "" }
        
        $trust = $this.BabyState.TrustLevel
        if ($trust -ge 80) { return "The baby goose loves you!" }
        if ($trust -ge 50) { return "The baby goose likes you!" }
        if ($trust -ge 20) { return "The baby goose is getting comfortable." }
        return "The baby goose is shy..."
    }
}

$gooseBaby = [GooseBaby]::new()

function Get-GooseBaby {
    return $gooseBaby
}

function Spawn-BabyGoose {
    param(
        [int]$X = 100,
        [int]$Y = 100,
        $Baby = $gooseBaby
    )
    $Baby.SpawnBaby($X, $Y)
}

function Dismiss-BabyGoose {
    param($Baby = $gooseBaby)
    $Baby.DismissBaby()
}

function Update-BabyPosition {
    param(
        [int]$ParentX,
        [int]$ParentY,
        $Baby = $gooseBaby
    )
    $Baby.UpdatePosition($ParentX, $ParentY)
}

function Interact-BabyGoose {
    param($Baby = $gooseBaby)
    $Baby.InteractWithBaby()
}

function Get-BabyState {
    param($Baby = $gooseBaby)
    return $Baby.GetBabyState()
}

Write-Host "Desktop Goose Baby Companion System Initialized"
$state = $gooseBaby.GetBabyState()
Write-Host "Baby Goose Enabled: $($state['Enabled'])"
Write-Host "Active: $($state['IsActive'])"
