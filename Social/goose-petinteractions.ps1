# Desktop Goose Pet Interactions System
# Interactive pet features for the goose

class GoosePetInteractions {
    [hashtable]$Config
    [bool]$IsEnabled
    [int]$Happiness
    [int]$Energy
    [int]$Hunger
    [int]$Affection
    [string]$Mood
    [hashtable]$Tricks
    [hashtable]$InteractionHistory
    [datetime]$LastFed
    [datetime]$LastPlayed
    
    GoosePetInteractions() {
        $this.Config = $this.LoadConfig()
        $this.IsEnabled = $false
        $this.Happiness = 50
        $this.Energy = 50
        $this.Hunger = 50
        $this.Affection = 50
        $this.Mood = "neutral"
        $this.Tricks = @{}
        $this.InteractionHistory = @{}
        $this.LastFed = Get-Date
        $this.LastPlayed = Get-Date
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
                    } else {
                        $this.Config[$key] = $value
                    }
                }
            }
        }
        
        if (-not $this.Config.ContainsKey("PetInteractionsEnabled")) {
            $this.Config["PetInteractionsEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("PetHungerDecayMinutes")) {
            $this.Config["PetHungerDecayMinutes"] = 30
        }
        if (-not $this.Config.ContainsKey("PetMoodChanges")) {
            $this.Config["PetMoodChanges"] = $true
        }
        
        return $this.Config
    }
    
    [void] LoadData() {
        $dataFile = "goose_petinteractions.json"
        
        if (Test-Path $dataFile) {
            try {
                $data = Get-Content $dataFile -Raw | ConvertFrom-Json
                
                if ($data.stats) {
                    $this.Happiness = $data.stats.happiness
                    $this.Energy = $data.stats.energy
                    $this.Hunger = $data.stats.hunger
                    $this.Affection = $data.stats.affection
                    $this.Mood = $data.stats.mood
                }
                
                if ($data.tricks) {
                    $this.Tricks = @{}
                    $data.tricks.PSObject.Properties | ForEach-Object {
                        $this.Tricks[$_.Name] = $_.Value
                    }
                }
                
                if ($data.lastFed) {
                    $this.LastFed = [datetime]::Parse($data.lastFed)
                }
                
                if ($data.lastPlayed) {
                    $this.LastPlayed = [datetime]::Parse($data.lastPlayed)
                }
            } catch {}
        }
        
        $this.IsEnabled = $this.Config["PetInteractionsEnabled"]
        $this.LoadDefaultTricks()
    }
    
    [void] LoadDefaultTricks() {
        if ($this.Tricks.Count -eq 0) {
            $this.Tricks = @{
                "sit" = @{
                    "name" = "Sit"
                    "description" = "The goose sits down"
                    "difficulty" = 1
                    "trained" = $false
                    "timesTrained" = 0
                }
                "shake" = @{
                    "name" = "Shake"
                    "description" = "The goose shakes your hand"
                    "difficulty" = 2
                    "trained" = $false
                    "timesTrained" = 0
                }
                "dance" = @{
                    "name" = "Dance"
                    "description" = "The goose dances around"
                    "difficulty" = 3
                    "trained" = $false
                    "timesTrained" = 0
                }
                "roll_over" = @{
                    "name" = "Roll Over"
                    "description" = "The goose rolls over"
                    "difficulty" = 3
                    "trained" = $false
                    "timesTrained" = 0
                }
                "spin" = @{
                    "name" = "Spin"
                    "description" = "The goose spins in a circle"
                    "difficulty" = 2
                    "trained" = $false
                    "timesTrained" = 0
                }
                "high_five" = @{
                    "name" = "High Five"
                    "description" = "The goose gives you a high five"
                    "difficulty" = 4
                    "trained" = $false
                    "timesTrained" = 0
                }
            }
        }
    }
    
    [void] SaveData() {
        $data = @{
            "stats" = @{
                "happiness" = $this.Happiness
                "energy" = $this.Energy
                "hunger" = $this.Hunger
                "affection" = $this.Affection
                "mood" = $this.Mood
            }
            "tricks" = $this.Tricks
            "lastFed" = $this.LastFed.ToString("o")
            "lastPlayed" = $this.LastPlayed.ToString("o")
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content "goose_petinteractions.json"
    }
    
    [void] UpdateMood() {
        $avgStats = ($this.Happiness + $this.Energy + $this.Affection) / 3
        
        if ($this.Hunger -lt 20) {
            $this.Mood = "hungry"
        } elseif ($this.Energy -lt 20) {
            $this.Mood = "tired"
        } elseif ($avgStats -ge 80) {
            $this.Mood = "happy"
        } elseif ($avgStats -ge 60) {
            $this.Mood = "content"
        } elseif ($avgStats -ge 40) {
            $this.Mood = "neutral"
        } elseif ($avgStats -ge 20) {
            $this.Mood = "sad"
        } else {
            $this.Mood = "unhappy"
        }
    }
    
    [hashtable] PetGoose() {
        $this.Affection = [Math]::Min(100, $this.Affection + 5)
        $this.Happiness = [Math]::Min(100, $this.Happiness + 3)
        
        $reactions = @(
            "The goose honks happily!",
            "The goose nuzzles your hand.",
            "The goose seems to enjoy being petted.",
            "The goose closes its eyes contentedly.",
            "The goose wiggles happily!"
        )
        
        $reaction = $reactions | Get-Random
        $this.UpdateMood()
        $this.RecordInteraction("pet", $reaction)
        $this.SaveData()
        
        return @{
            "success" = $true
            "message" = $reaction
            "affection" = $this.Affection
            "happiness" = $this.Happiness
            "mood" = $this.Mood
        }
    }
    
    [hashtable] FeedGoose([string]$foodType = "generic") {
        $hungerValues = @{
            "bread" = 20
            "grass" = 15
            "corn" = 25
            "lettuce" = 10
            "seeds" = 15
            "fruit" = 20
            "generic" = 15
        }
        
        $value = $hungerValues[$foodType]
        if (-not $value) { $value = 15 }
        
        $this.Hunger = [Math]::Min(100, $this.Hunger + $value)
        $this.Energy = [Math]::Min(100, $this.Energy + 5)
        
        $reactions = @(
            "The goose eagerly eats the $foodType!",
            "The goose gobbles up the $foodType!",
            "The goose seems to enjoy the $foodType!",
            "The goose quacks happily while eating!",
            "The goose eats contentedly."
        )
        
        $reaction = $reactions | Get-Random
        $this.LastFed = Get-Date
        $this.UpdateMood()
        $this.RecordInteraction("feed", $reaction)
        $this.SaveData()
        
        return @{
            "success" = $true
            "message" = $reaction
            "hunger" = $this.Hunger
            "energy" = $this.Energy
            "mood" = $this.Mood
        }
    }
    
    [hashtable] PlayWithGoose([string]$toy = "ball") {
        if ($this.Energy -lt 10) {
            return @{
                "success" = $false
                "message" = "The goose is too tired to play."
                "energy" = $this.Energy
            }
        }
        
        $toys = @{}
        $toys["ball"] = @{ "reaction" = "The goose chases the ball around!"; "happinessGain" = 10; "energyLoss" = 15 }
        $toys["stick"] = @{ "reaction" = "The goose fetches the stick!"; "happinessGain" = 12; "energyLoss" = 20 }
        $toys["feather"] = @{ "reaction" = "The goose plays with the feather!"; "happinessGain" = 8; "energyLoss" = 10 }
        $toys["bubble"] = @{ "reaction" = "The goose tries to catch the bubbles!"; "happinessGain" = 15; "energyLoss" = 12 }
        
        $toyData = $toys[$toy]
        if (-not $toyData) {
            $toyData = $toys["ball"]
        }
        
        $this.Happiness = [Math]::Min(100, $this.Happiness + $toyData.happinessGain)
        $this.Energy = [Math]::Max(0, $this.Energy - $toyData.energyLoss)
        $this.Affection = [Math]::Min(100, $this.Affection + 5)
        
        $this.LastPlayed = Get-Date
        $this.UpdateMood()
        $this.RecordInteraction("play", $toyData.reaction)
        $this.SaveData()
        
        return @{
            "success" = $true
            "message" = $toyData.reaction
            "happiness" = $this.Happiness
            "energy" = $this.Energy
            "mood" = $this.Mood
        }
    }
    
    [hashtable] TeachTrick([string]$trickName) {
        if (-not $this.Tricks.ContainsKey($trickName)) {
            return @{
                "success" = $false
                "message" = "Trick not found."
            }
        }
        
        $trick = $this.Tricks[$trickName]
        
        if ($trick.trained) {
            return @{
                "success" = $false
                "message" = "The goose already knows this trick!"
            }
        }
        
        $successChance = 0.5 + ($this.Affection * 0.005) - ($trick.difficulty * 0.05)
        $roll = Get-Random -Minimum 0 -Maximum 1
        
        if ($roll -lt $successChance) {
            $trick.trained = $true
            $trick.timesTrained++
            $this.Tricks[$trickName] = $trick
            
            $this.Happiness = [Math]::Min(100, $this.Happiness + 10)
            $this.Affection = [Math]::Min(100, $this.Affection + 5)
            $this.UpdateMood()
            $this.RecordInteraction("teach", "The goose learned to $($trick.name)!")
            $this.SaveData()
            
            return @{
                "success" = $true
                "message" = "The goose learned to $($trick.name)!"
                "trick" = $trick
            }
        } else {
            $trick.timesTrained++
            $this.Tricks[$trickName] = $trick
            $this.SaveData()
            
            return @{
                "success" = $false
                "message" = "The goose couldn't learn this trick yet. Try again!"
                "progress" = "$($trick.timesTrained) attempts"
            }
        }
    }
    
    [hashtable] PerformTrick([string]$trickName) {
        if (-not $this.Tricks.ContainsKey($trickName)) {
            return @{
                "success" = $false
                "message" = "Trick not found."
            }
        }
        
        $trick = $this.Tricks[$trickName]
        
        if (-not $trick.trained) {
            return @{
                "success" = $false
                "message" = "The goose hasn't learned this trick yet!"
            }
        }
        
        if ($this.Energy -lt 10) {
            return @{
                "success" = $false
                "message" = "The goose is too tired to perform."
                "energy" = $this.Energy
            }
        }
        
        $trickReactions = @{
            "sit" = "The goose sits down obediently!"
            "shake" = "The goose offers its wing for a shake!"
            "dance" = "The goose waddles around in a funny dance!"
            "roll_over" = "The goose rolls over on the ground!"
            "spin" = "The goose spins around in a circle!"
            "high_five" = "The goose gives you a enthusiastic high five!"
        }
        
        $reaction = $trickReactions[$trickName]
        
        $this.Energy = [Math]::Max(0, $this.Energy - 5)
        $this.Happiness = [Math]::Min(100, $this.Happiness + 3)
        $this.UpdateMood()
        $this.RecordInteraction("trick", $reaction)
        $this.SaveData()
        
        return @{
            "success" = $true
            "message" = $reaction
            "energy" = $this.Energy
        }
    }
    
    [void] RecordInteraction([string]$type, [string]$message) {
        $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm")
        
        $this.InteractionHistory[$timestamp] = @{
            "timestamp" = (Get-Date).ToString("o")
            "type" = $type
            "message" = $message
        }
        
        if ($this.InteractionHistory.Count -gt 50) {
            $keys = $this.InteractionHistory.Keys | Sort-Object
            $keysToRemove = $keys[0..($keys.Count - 51)]
            foreach ($key in $keysToRemove) {
                $this.InteractionHistory.Remove($key)
            }
        }
    }
    
    [void] DecayStats() {
        $decayMinutes = $this.Config["PetHungerDecayMinutes"]
        
        $timeSinceFed = (Get-Date) - $this.LastFed
        $hungerDecay = [Math]::Floor($timeSinceFed.TotalMinutes / $decayMinutes)
        
        $this.Hunger = [Math]::Max(0, $this.Hunger - $hungerDecay)
        $this.Energy = [Math]::Min(100, $this.Energy + 2)
        
        $timeSincePlayed = (Get-Date) - $this.LastPlayed
        if ($timeSincePlayed.TotalMinutes -gt 60) {
            $this.Happiness = [Math]::Max(0, $this.Happiness - 1)
        }
        
        $this.UpdateMood()
        $this.SaveData()
    }
    
    [hashtable] GetStats() {
        return @{
            "happiness" = $this.Happiness
            "energy" = $this.Energy
            "hunger" = $this.Hunger
            "affection" = $this.Affection
            "mood" = $this.Mood
            "lastFed" = $this.LastFed
            "lastPlayed" = $this.LastPlayed
            "tricksLearned" = (($this.Tricks.Values | Where-Object { $_.trained })).Count
            "totalTricks" = $this.Tricks.Count
        }
    }
    
    [hashtable[]] GetTricks() {
        return @($this.Tricks.Values)
    }
    
    [hashtable[]] GetLearnedTricks() {
        $learned = @()
        foreach ($trick in $this.Tricks.Values) {
            if ($trick.trained) {
                $learned += $trick
            }
        }
        return $learned
    }
    
    [hashtable[]] GetRecentInteractions([int]$count = 10) {
        $interactions = @()
        $keys = $this.InteractionHistory.Keys | Sort-Object -Descending
        
        foreach ($key in $keys | Select-Object -First $count) {
            $interactions += $this.InteractionHistory[$key]
        }
        
        return $interactions
    }
    
    [void] SetEnabled([bool]$enabled) {
        $this.IsEnabled = $enabled
        $this.Config["PetInteractionsEnabled"] = $enabled
    }
    
    [void] Toggle() {
        $this.IsEnabled = -not $this.IsEnabled
        $this.Config["PetInteractionsEnabled"] = $this.IsEnabled
    }
    
    [hashtable] GetPetInteractionsState() {
        return @{
            "Enabled" = $this.IsEnabled
            "Stats" = $this.GetStats()
            "Tricks" = $this.GetTricks()
            "LearnedTricks" = $this.GetLearnedTricks()
            "RecentInteractions" = $this.GetRecentInteractions(10)
        }
    }
}

$goosePetInteractions = [GoosePetInteractions]::new()

function Get-GoosePetInteractions {
    return $goosePetInteractions
}

function Pet-Goose {
    param($Interactions = $goosePetInteractions)
    return $Interactions.PetGoose()
}

function Feed-Goose {
    param(
        [string]$FoodType = "generic",
        $Interactions = $goosePetInteractions
    )
    return $Interactions.FeedGoose($FoodType)
}

function Play-Goose {
    param(
        [string]$Toy = "ball",
        $Interactions = $goosePetInteractions
    )
    return $Interactions.PlayWithGoose($Toy)
}

function Teach-Trick {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TrickName,
        $Interactions = $goosePetInteractions
    )
    return $Interactions.TeachTrick($TrickName)
}

function Perform-Trick {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TrickName,
        $Interactions = $goosePetInteractions
    )
    return $Interactions.PerformTrick($TrickName)
}

function Get-PetStats {
    param($Interactions = $goosePetInteractions)
    return $Interactions.GetStats()
}

function Get-PetTricks {
    param($Interactions = $goosePetInteractions)
    return $Interactions.GetTricks()
}

function Get-LearnedTricks {
    param($Interactions = $goosePetInteractions)
    return $Interactions.GetLearnedTricks()
}

function Get-PetInteractions {
    param($Interactions = $goosePetInteractions)
    return $Interactions.GetRecentInteractions()
}

function Enable-PetInteractions {
    param($Interactions = $goosePetInteractions)
    $Interactions.SetEnabled($true)
}

function Disable-PetInteractions {
    param($Interactions = $goosePetInteractions)
    $Interactions.SetEnabled($false)
}

function Toggle-PetInteractions {
    param($Interactions = $goosePetInteractions)
    $Interactions.Toggle()
}

function Get-PetInteractionsState {
    param($Interactions = $goosePetInteractions)
    return $Interactions.GetPetInteractionsState()
}

Write-Host "Desktop Goose Pet Interactions System Initialized"
$state = Get-PetInteractionsState
Write-Host "Pet Interactions Enabled: $($state['Enabled'])"
Write-Host "Mood: $($state['Stats']['mood'])"
Write-Host "Tricks Learned: $($state['Stats']['tricksLearned'])/$($state['Stats']['totalTricks'])"
