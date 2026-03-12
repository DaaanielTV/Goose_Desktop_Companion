# Desktop Goose Multi-Goose Chaos Mode
# Spawn multiple geese with unique personalities

enum GoosePersonality {
    Normal
    Hacker
    Lazy
    Evil
}

enum GooseMood {
    Happy
    Angry
    Bored
    Sleepy
    Curious
    Mischievous
    Chaotic
    Neutral
}

class GoosePersonalityConfig {
    [string]$Name
    [GoosePersonality]$Type
    [string[]]$Behaviors
    [string[]]$SpeechBubbles
    [string]$Skin
    [int]$ChaosLevel
    [bool]$CanInteract
    
    static [GoosePersonalityConfig] CreateNormal() {
        return [GoosePersonalityConfig]@{
            Name = "Goosey"
            Type = [GoosePersonality]::Normal
            Behaviors = @("wander", "follow", "sleep", "groom")
            SpeechBubbles = @("HONK!", "Hello friend!", "Waddle waddle", "Need bread?")
            Skin = "default"
            ChaosLevel = 1
            CanInteract = $true
        }
    }
    
    static [GoosePersonalityConfig] CreateHacker() {
        return [GoosePersonalityConfig]@{
            Name = "Hack Goose"
            Type = [GoosePersonality]::Hacker
            Behaviors = @("type", "hack", "code", "monitor")
            SpeechBubbles = @("sudo honk", "Compiling...", "rm -rf /", "404 HONK not found", "git commit -m 'honk'")
            Skin = "hacker"
            ChaosLevel = 3
            CanInteract = $true
        }
    }
    
    static [GoosePersonalityConfig] CreateLazy() {
        return [GoosePersonalityConfig]@{
            Name = "Sleepy Goose"
            Type = [GoosePersonality]::Lazy
            Behaviors = @("sleep", "snore", "dream", "stretch")
            SpeechBubbles = @("*yawn*", "Zzz...", "5 more minutes", "I'm sleeping", "Don't wake me")
            Skin = "sleepy"
            ChaosLevel = 1
            CanInteract = $true
        }
    }
    
    static [GoosePersonalityConfig] CreateEvil() {
        return [GoosePersonalityConfig]@{
            Name = "Evil Goose"
            Type = [GoosePersonality]::Evil
            Behaviors = @("steal", "hide", "prank", "laugh")
            SpeechBubbles = @("HONK HONK!", "Your files are mine!", "MUAHAHA!", "Oops?", "Run, human!")
            Skin = "evil"
            ChaosLevel = 5
            CanInteract = $true
        }
    }
}

class ChaosGoose {
    [string]$Id
    [GoosePersonalityConfig]$Personality
    [GooseMood]$CurrentMood
    [int]$X
    [int]$Y
    [int]$ChaosPoints
    [datetime]$LastAction
    [bool]$IsActive
    
    ChaosGoose([string]$id, [GoosePersonalityConfig]$config) {
        $this.Id = $id
        $this.Personality = $config
        $this.CurrentMood = [GooseMood]::Neutral
        $this.ChaosPoints = 0
        $this.LastAction = Get-Date
        $this.IsActive = $true
        $this.X = 0
        $this.Y = 0
    }
    
    [string] GetSpeechBubble() {
        return $this.Personality.SpeechBubbles | Get-Random
    }
    
    [string] GetNextBehavior() {
        return $this.Personality.Behaviors | Get-Random
    }
    
    [void] AddChaosPoints([int]$points) {
        $this.ChaosPoints += $points * $this.Personality.ChaosLevel
    }
    
    [void] SetMood([GooseMood]$mood) {
        $this.CurrentMood = $mood
        $this.LastAction = Get-Date
    }
}

class GooseMultiGoose {
    [hashtable]$Config
    [System.Collections.ArrayList]$Gooses
    [string]$DataFile
    [int]$MaxGooseCount
    [bool]$ChaosModeEnabled
    
    GooseMultiGoose() {
        $this.Config = $this.LoadConfig()
        $this.DataFile = "goose_multigoose.json"
        $this.Gooses = [System.Collections.ArrayList]::new()
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
        
        if (-not $this.Config.ContainsKey("MultiGooseEnabled")) {
            $this.Config["MultiGooseEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("MaxGooseCount")) {
            $this.Config["MaxGooseCount"] = 3
        }
        if (-not $this.Config.ContainsKey("ChaosModeEnabled")) {
            $this.Config["ChaosModeEnabled"] = $false
        }
        
        $this.MaxGooseCount = $this.Config["MaxGooseCount"]
        $this.ChaosModeEnabled = $this.Config["ChaosModeEnabled"]
        
        return $this.Config
    }
    
    [void] LoadData() {
        if (Test-Path $this.DataFile) {
            try {
                $data = Get-Content $this.DataFile -Raw | ConvertFrom-Json
                $this.Gooses.Clear()
                foreach ($g in $data.Gooses) {
                    $config = [GoosePersonalityConfig]::CreateNormal()
                    $goose = [ChaosGoose]::new($g.Id, $config)
                    $goose.CurrentMood = [GooseMood]$g.CurrentMood
                    $goose.ChaosPoints = $g.ChaosPoints
                    $goose.X = $g.X
                    $goose.Y = $g.Y
                    $this.Gooses.Add($goose)
                }
            } catch {
                $this.AddDefaultGoose()
            }
        } else {
            $this.AddDefaultGoose()
        }
    }
    
    [void] SaveData() {
        $data = @{
            "Gooses" = @($this.Gooses | ForEach-Object {
                @{
                    Id = $_.Id
                    PersonalityType = $_.Personality.Type.ToString()
                    CurrentMood = $_.CurrentMood.ToString()
                    ChaosPoints = $_.ChaosPoints
                    X = $_.X
                    Y = $_.Y
                }
            })
            "LastSaved" = (Get-Date).ToString("o")
        }
        $data | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.DataFile -Encoding UTF8
    }
    
    [void] AddDefaultGoose() {
        $this.Gooses.Clear()
        $defaultConfig = [GoosePersonalityConfig]::CreateNormal()
        $goose = [ChaosGoose]::new("goose_1", $defaultConfig)
        $this.Gooses.Add($goose)
        $this.SaveData()
    }
    
    [hashtable] AddGoose([string]$personalityType) {
        if ($this.Gooses.Count -ge $this.MaxGooseCount) {
            return @{
                Success = $false
                Message = "Maximum goose count ($($this.MaxGooseCount)) reached"
            }
        }
        
        $config = switch ($personalityType.ToLower()) {
            "hacker" { [GoosePersonalityConfig]::CreateHacker() }
            "lazy" { [GoosePersonalityConfig]::CreateLazy() }
            "evil" { [GoosePersonalityConfig]::CreateEvil() }
            default { [GoosePersonalityConfig]::CreateNormal() }
        }
        
        $id = "goose_" + ($this.Gooses.Count + 1)
        $goose = [ChaosGoose]::new($id, $config)
        $this.Gooses.Add($goose)
        $this.SaveData()
        
        return @{
            Success = $true
            Message = "Added $($config.Name)!"
            Goose = @{
                Id = $id
                Name = $config.Name
                Personality = $config.Type.ToString()
            }
        }
    }
    
    [hashtable] RemoveGoose([string]$gooseId) {
        $initialCount = $this.Gooses.Count
        $this.Gooses.RemoveAll( { $args[0].Id -eq $gooseId })
        
        if ($this.Gooses.Count -lt $initialCount) {
            $this.SaveData()
            return @{
                Success = $true
                Message = "Removed $gooseId"
            }
        }
        
        return @{
            Success = $false
            Message = "Goose not found: $gooseId"
        }
    }
    
    [hashtable] SetGooseMood([string]$gooseId, [string]$moodStr) {
        $goose = $this.Gooses | Where-Object { $_.Id -eq $gooseId } | Select-Object -First 1
        
        if (-not $goose) {
            return @{
                Success = $false
                Message = "Goose not found: $gooseId"
            }
        }
        
        try {
            $mood = [GooseMood]$moodStr
            $goose.SetMood($mood)
            $this.SaveData()
            return @{
                Success = $true
                Message = "$($goose.Personality.Name) is now $mood"
                Mood = $moodStr
            }
        } catch {
            return @{
                Success = $false
                Message = "Invalid mood: $moodStr"
            }
        }
    }
    
    [string] GetRandomInteraction() {
        if ($this.Gooses.Count -eq 0) { return "No geese available" }
        
        $goose = $this.Gooses | Get-Random
        $behavior = $goose.GetNextBehavior()
        $speech = $goose.GetSpeechBubble()
        
        $goose.AddChaosPoints(1)
        
        return "$($goose.Personality.Name) wants to $behavior: $speech"
    }
    
    [hashtable] GetAllGooses() {
        return @($this.Gooses | ForEach-Object {
            @{
                Id = $_.Id
                Name = $_.Personality.Name
                Personality = $_.Personality.Type.ToString()
                Mood = $_.CurrentMood.ToString()
                ChaosPoints = $_.ChaosPoints
                Speech = $_.GetSpeechBubble()
            }
        })
    }
    
    [hashtable] GetMultiGooseState() {
        return @{
            Enabled = $this.Config["MultiGooseEnabled"]
            ChaosMode = $this.ChaosModeEnabled
            MaxCount = $this.MaxGooseCount
            CurrentCount = $this.Gooses.Count
            Gooses = $this.GetAllGooses()
        }
    }
}

$gooseMultiGoose = [GooseMultiGoose]::new()

function Get-GooseMultiGoose {
    return $gooseMultiGoose
}

function Add-Goose {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Normal", "Hacker", "Lazy", "Evil")]
        [string]$Personality,
        $MultiGoose = $gooseMultiGoose
    )
    return $MultiGoose.AddGoose($Personality)
}

function Remove-Goose {
    param(
        [Parameter(Mandatory=$true)]
        [string]$GooseId,
        $MultiGoose = $gooseMultiGoose
    )
    return $MultiGoose.RemoveGoose($GooseId)
}

function Set-GooseMood {
    param(
        [Parameter(Mandatory=$true)]
        [string]$GooseId,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Happy", "Angry", "Bored", "Sleepy", "Curious", "Mischievous", "Chaotic", "Neutral")]
        [string]$Mood,
        $MultiGoose = $gooseMultiGoose
    )
    return $MultiGoose.SetGooseMood($GooseId, $Mood)
}

function Get-MultiGooseState {
    param($MultiGoose = $gooseMultiGoose)
    return $MultiGoose.GetMultiGooseState()
}

function Invoke-GooseInteraction {
    param($MultiGoose = $gooseMultiGoose)
    return $MultiGoose.GetRandomInteraction()
}

Write-Host "Desktop Goose Multi-Goose Chaos Mode Initialized"
$state = Get-MultiGooseState
Write-Host "Enabled: $($state['Enabled']) | Geese: $($state['CurrentCount'])/$($state['MaxCount'])"
