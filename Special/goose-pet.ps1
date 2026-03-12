# Desktop Goose Pet Interaction System
# Click-and-hold petting interaction with trust system

class GoosePet {
    [hashtable]$Config
    [int]$TrustLevel
    [int]$HappinessLevel
    [int]$AffectionStreak
    [datetime]$LastPetTime
    [hashtable]$PetHistory
    [bool]$IsBeingPet
    [int]$PetHoldDuration
    [string]$CurrentMood
    
    GoosePet() {
        $this.Config = $this.LoadConfig()
        $this.TrustLevel = 50
        $this.HappinessLevel = 50
        $this.AffectionStreak = 0
        $this.LastPetTime = Get-Date
        $this.PetHistory = @{}
        $this.IsBeingPet = $false
        $this.PetHoldDuration = 0
        $this.CurrentMood = "neutral"
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
        
        if (-not $this.Config.ContainsKey("PetInteractionEnabled")) {
            $this.Config["PetInteractionEnabled"] = $true
        }
        
        return $this.Config
    }
    
    [void] StartPetting() {
        if (-not $this.Config["PetInteractionEnabled"]) { return }
        
        $this.IsBeingPet = $true
        $this.PetHoldDuration = 0
        
        $this.TrustLevel = [Math]::Min(100, $this.TrustLevel + 2)
        $this.HappinessLevel = [Math]::Min(100, $this.HappinessLevel + 3)
        $this.AffectionStreak++
        
        if ($this.AffectionStreak -ge 5) {
            $this.CurrentMood = "veryhappy"
        } elseif ($this.AffectionStreak -ge 2) {
            $this.CurrentMood = "happy"
        }
    }
    
    [hashtable] ContinuePetting([int]$holdSeconds) {
        if (-not $this.IsBeingPet) {
            return @{
                "Success" = $false
                "Message" = "Not being petted"
            }
        }
        
        $this.PetHoldDuration = $holdSeconds
        
        $bonusTrust = 0
        $bonusHappiness = 0
        
        if ($holdSeconds -ge 3) {
            $bonusTrust = 5
            $bonusHappiness = 8
            $this.CurrentMood = "veryhappy"
        } elseif ($holdSeconds -ge 1) {
            $bonusTrust = 3
            $bonusHappiness = 5
            $this.CurrentMood = "happy"
        }
        
        $this.TrustLevel = [Math]::Min(100, $this.TrustLevel + $bonusTrust)
        $this.HappinessLevel = [Math]::Min(100, $this.HappinessLevel + $bonusHappiness)
        
        return @{
            "Success" = $true
            "HoldDuration" = $holdSeconds
            "TrustLevel" = $this.TrustLevel
            "HappinessLevel" = $this.HappinessLevel
            "Mood" = $this.CurrentMood
            "UnlockedAnimations" = $this.GetUnlockedAnimations()
        }
    }
    
    [hashtable] StopPetting() {
        $result = @{
            "Success" = $true
            "TotalHoldTime" = $this.PetHoldDuration
            "TrustGained" = 0
            "HappinessGained" = 0
            "UnlockedNew" = $false
        }
        
        if ($this.PetHoldDuration -ge 1) {
            $result["TrustGained"] = [Math]::Min(20, $this.PetHoldDuration * 5)
            $result["HappinessGained"] = [Math]::Min(25, $this.PetHoldDuration * 8)
            
            $this.TrustLevel = [Math]::Min(100, $this.TrustLevel + $result["TrustGained"])
            $this.HappinessLevel = [Math]::Min(100, $this.HappinessLevel + $result["HappinessGained"])
            
            $newUnlocks = $this.CheckNewUnlocks()
            $result["UnlockedNew"] = $newUnlocks.Count -gt 0
            $result["NewUnlocks"] = $newUnlocks
            
            $this.RecordPetSession()
        }
        
        $this.IsBeingPet = $false
        $this.PetHoldDuration = 0
        $this.LastPetTime = Get-Date
        
        if ($this.AffectionStreak -ge 3) {
            $this.CurrentMood = "affectionate"
        } else {
            $this.CurrentMood = "neutral"
        }
        
        return $result
    }
    
    [void] RecordPetSession() {
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        
        if (-not $this.PetHistory.ContainsKey($dateKey)) {
            $this.PetHistory[$dateKey] = @{
                "Sessions" = 0
                "TotalDuration" = 0
            }
        }
        
        $this.PetHistory[$dateKey].Sessions++
        $this.PetHistory[$dateKey].TotalDuration += $this.PetHoldDuration
    }
    
    [System.Collections.ArrayList] GetUnlockedAnimations() {
        $unlocked = New-Object System.Collections.ArrayList
        
        if ($this.TrustLevel -ge 20) {
            $unlocked.Add("happy_bounce") | Out-Null
        }
        if ($this.TrustLevel -ge 40) {
            $unlocked.Add("sleeping") | Out-Null
        }
        if ($this.TrustLevel -ge 60) {
            $unlocked.Add("happy_dance") | Out-Null
        }
        if ($this.TrustLevel -ge 80) {
            $unlocked.Add("cuddle") | Out-Null
        }
        if ($this.HappinessLevel -ge 50) {
            $unlocked.Add("playful_chase") | Out-Null
        }
        if ($this.HappinessLevel -ge 80) {
            $unlocked.Add("celebration") | Out-Null
        }
        
        if ($this.TrustLevel -ge 100 -and $this.HappinessLevel -ge 100) {
            $unlocked.Add("special_bond") | Out-Null
        }
        
        return $unlocked
    }
    
    [System.Collections.ArrayList] CheckNewUnlocks() {
        $previousUnlocks = @()
        $newUnlocks = New-Object System.Collections.ArrayList
        
        $currentUnlocks = $this.GetUnlockedAnimations()
        
        foreach ($anim in $currentUnlocks) {
            if ($anim -eq "happy_bounce" -and $this.TrustLevel -ge 20) { $newUnlocks.Add("Happy Bounce") | Out-Null }
            if ($anim -eq "sleeping" -and $this.TrustLevel -ge 40) { $newUnlocks.Add("Sleeping Animation") | Out-Null }
            if ($anim -eq "happy_dance" -and $this.TrustLevel -ge 60) { $newUnlocks.Add("Happy Dance") | Out-Null }
            if ($anim -eq "cuddle" -and $this.TrustLevel -ge 80) { $newUnlocks.Add("Cuddle Animation") | Out-Null }
            if ($anim -eq "celebration" -and $this.HappinessLevel -ge 80) { $newUnlocks.Add("Celebration") | Out-Null }
        }
        
        return $newUnlocks
    }
    
    [void] DecreaseStatsOverTime() {
        $timeSincePet = (Get-Date) - $this.LastPetTime
        
        if ($timeSincePet.TotalMinutes -ge 30) {
            $decayAmount = [Math]::Floor($timeSincePet.TotalMinutes / 30)
            
            $this.TrustLevel = [Math]::Max(0, $this.TrustLevel - ($decayAmount * 2))
            $this.HappinessLevel = [Math]::Max(0, $this.HappinessLevel - ($decayAmount * 3))
            $this.AffectionStreak = 0
            
            if ($this.TrustLevel -lt 30) {
                $this.CurrentMood = "sad"
            }
        }
    }
    
    [hashtable] GetPetState() {
        $this.DecreaseStatsOverTime()
        
        return @{
            "Enabled" = $this.Config["PetInteractionEnabled"]
            "TrustLevel" = $this.TrustLevel
            "HappinessLevel" = $this.HappinessLevel
            "AffectionStreak" = $this.AffectionStreak
            "IsBeingPet" = $this.IsBeingPet
            "CurrentMood" = $this.CurrentMood
            "UnlockedAnimations" = $this.GetUnlockedAnimations()
            "LastPetTime" = $this.LastPetTime
            "TodayStats" = $this.GetTodayStats()
        }
    }
    
    [hashtable] GetTodayStats() {
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        
        if ($this.PetHistory.ContainsKey($dateKey)) {
            return $this.PetHistory[$dateKey]
        }
        
        return @{
            "Sessions" = 0
            "TotalDuration" = 0
        }
    }
    
    [string] GetTrustRank() {
        if ($this.TrustLevel -ge 90) { return "Best Friend" }
        if ($this.TrustLevel -ge 70) { return "Close Companion" }
        if ($this.TrustLevel -ge 50) { return "Friend" }
        if ($this.TrustLevel -ge 30) { return "Acquaintance" }
        return "Stranger"
    }
    
    [void] ResetStats() {
        $this.TrustLevel = 50
        $this.HappinessLevel = 50
        $this.AffectionStreak = 0
    }
}

$goosePet = [GoosePet]::new()

function Get-GoosePet {
    return $goosePet
}

function Start-PettingGoose {
    param($Pet = $goosePet)
    $Pet.StartPetting()
}

function Continue-PettingGoose {
    param(
        [int]$Seconds,
        $Pet = $goosePet
    )
    return $Pet.ContinuePetting($Seconds)
}

function Stop-PettingGoose {
    param($Pet = $goosePet)
    return $Pet.StopPetting()
}

function Get-PetStatus {
    param($Pet = $goosePet)
    return $Pet.GetPetState()
}

function Get-TrustRank {
    param($Pet = $goosePet)
    return $Pet.GetTrustRank()
}

Write-Host "Desktop Goose Pet Interaction System Initialized"
$state = $goosePet.GetPetState()
Write-Host "Pet Interaction Enabled: $($state['Enabled'])"
Write-Host "Trust Level: $($state['TrustLevel']) ($($goosePet.GetTrustRank()))"
Write-Host "Happiness Level: $($state['HappinessLevel'])"
