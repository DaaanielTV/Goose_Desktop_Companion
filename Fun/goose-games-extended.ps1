# Desktop Goose Additional Mini Games
# Extended mini games beyond the base set

enum GameType {
    GooseChase
    IconHeist
    DodgeGoose
    GooseRacing
}

class ChaseGameState {
    [int]$GooseX
    [int]$GooseY
    [int]$PlayerX
    [int]$PlayerY
    [int]$Score
    [int]$TimeLeft
    [bool]$IsRunning
    
    ChaseGameState() {
        $this.GooseX = 0
        $this.GooseY = 0
        $this.PlayerX = 0
        $this.PlayerY = 0
        $this.Score = 0
        $this.TimeLeft = 60
        $this.IsRunning = $false
    }
}

class IconHeistState {
    [array]$StolenIcons
    [int]$StolenCount
    [int]$MissedCount
    [bool]$IsRunning
    
    IconHeistState() {
        $this.StolenIcons = @()
        $this.StolenCount = 0
        $this.MissedCount = 0
        $this.IsRunning = $false
    }
}

class DodgeGameState {
    [int]$PlayerX
    [int]$PlayerY
    [int]$Score
    [int]$Speed
    [int]$Lives
    [bool]$IsRunning
    
    DodgeGameState() {
        $this.PlayerX = 50
        $this.PlayerY = 80
        $this.Score = 0
        $this.Speed = 1
        $this.Lives = 3
        $this.IsRunning = $false
    }
}

class GooseMiniGamesExtended {
    [hashtable]$Config
    [bool]$Enabled
    [ChaseGameState]$ChaseGame
    [IconHeistState]$IconHeist
    [DodgeGameState]$DodgeGame
    [hashtable]$GameStats
    [string]$DataFile
    
    GooseMiniGamesExtended() {
        $this.Config = $this.LoadConfig()
        $this.Enabled = $false
        $this.ChaseGame = [ChaseGameState]::new()
        $this.IconHeist = [IconHeistState]::new()
        $this.DodgeGame = [DodgeGameState]::new()
        $this.GameStats = @{}
        $this.DataFile = "goose_games_extended.json"
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
        
        if (-not $this.Config.ContainsKey("MiniGamesEnabled")) {
            $this.Config["MiniGamesEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("ExtendedGamesEnabled")) {
            $this.Config["ExtendedGamesEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] LoadData() {
        if (Test-Path $this.DataFile) {
            try {
                $data = Get-Content $this.DataFile -Raw | ConvertFrom-Json
                if ($data.gameStats) {
                    $this.GameStats = @{}
                    $data.gameStats.PSObject.Properties | ForEach-Object {
                        $this.GameStats[$_.Name] = $_.Value
                    }
                }
            } catch {}
        }
        
        $this.Enabled = $this.Config["MiniGamesEnabled"] -or $this.Config["ExtendedGamesEnabled"]
    }
    
    [void] SaveData() {
        $data = @{
            gameStats = $this.GameStats
            lastSaved = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.DataFile -Encoding UTF8
    }
    
    [string[]] GetAvailableGames() {
        return @("goose_chase", "icon_heist", "dodge_goose")
    }
    
    [hashtable] StartGame([string]$gameName) {
        $result = @{
            success = $false
            game = ""
            message = ""
            state = @{}
        }
        
        switch ($gameName.ToLower()) {
            "goose_chase" {
                $this.ChaseGame = [ChaseGameState]::new()
                $this.ChaseGame.IsRunning = $true
                $result.success = $true
                $result.game = "goose_chase"
                $result.message = "Catch the goose! Click on it before time runs out!"
            }
            "icon_heist" {
                $this.IconHeist = [IconHeistState]::new()
                $this.IconHeist.IsRunning = $true
                $result.success = $true
                $result.game = "icon_heist"
                $result.message = "The goose will steal icons! Click to catch it!"
            }
            "dodge_goose" {
                $this.DodgeGame = [DodgeGameState]::new()
                $this.DodgeGame.IsRunning = $true
                $result.success = $true
                $result.game = "dodge_goose"
                $result.message = "Dodge the flying goose! Use arrow keys or mouse!"
            }
            default {
                $result.message = "Unknown game: $gameName"
                return $result
            }
        }
        
        $this.RecordGameStart($gameName)
        $result.state = $this.GetGameState($gameName)
        
        return $result
    }
    
    [hashtable] EndGame([string]$gameName, [int]$score) {
        $result = @{
            success = $false
            message = ""
            xpEarned = 0
            newHighScore = $false
        }
        
        switch ($gameName.ToLower()) {
            "goose_chase" {
                $this.ChaseGame.IsRunning = $false
                $result.xpEarned = [int]($score / 10)
                $result.message = "Game ended! Score: $score"
            }
            "icon_heist" {
                $this.IconHeist.IsRunning = $false
                $result.xpEarned = [int]($score / 5)
                $result.message = "Heist over! Icons stolen: $($this.IconHeist.StolenCount)"
            }
            "dodge_goose" {
                $this.DodgeGame.IsRunning = $false
                $result.xpEarned = [int]($score / 10)
                $result.message = "Game over! Score: $score"
            }
        }
        
        $result.success = $true
        $this.RecordGameEnd($gameName, $score)
        
        if ($score -gt ($this.GameStats["${gameName}_highscore"] -or 0)) {
            $result.newHighScore = $true
            $this.GameStats["${gameName}_highscore"] = $score
        }
        
        $this.GameStats["${gameName}_games"] = ($this.GameStats["${gameName}_games"] -or 0) + 1
        $this.GameStats["${gameName}_totalScore"] = ($this.GameStats["${gameName}_totalScore"] -or 0) + $score
        
        $this.SaveData()
        
        return $result
    }
    
    [hashtable] UpdateGameState([string]$gameName, [hashtable]$newState) {
        switch ($gameName.ToLower()) {
            "goose_chase" {
                if ($newState.ContainsKey("score")) { $this.ChaseGame.Score = $newState.score }
                if ($newState.ContainsKey("timeLeft")) { $this.ChaseGame.TimeLeft = $newState.timeLeft }
                if ($newState.ContainsKey("gooseX")) { $this.ChaseGame.GooseX = $newState.gooseX }
                if ($newState.ContainsKey("gooseY")) { $this.ChaseGame.GooseY = $newState.gooseY }
            }
            "icon_heist" {
                if ($newState.ContainsKey("stolenCount")) { $this.IconHeist.StolenCount = $newState.stolenCount }
                if ($newState.ContainsKey("missedCount")) { $this.IconHeist.MissedCount = $newState.missedCount }
            }
            "dodge_goose" {
                if ($newState.ContainsKey("score")) { $this.DodgeGame.Score = $newState.score }
                if ($newState.ContainsKey("lives")) { $this.DodgeGame.Lives = $newState.lives }
                if ($newState.ContainsKey("playerX")) { $this.DodgeGame.PlayerX = $newState.playerX }
                if ($newState.ContainsKey("playerY")) { $this.DodgeGame.PlayerY = $newState.playerY }
            }
        }
        
        return $this.GetGameState($gameName)
    }
    
    [hashtable] GetGameState([string]$gameName) {
        switch ($gameName.ToLower()) {
            "goose_chase" {
                return @{
                    GooseX = $this.ChaseGame.GooseX
                    GooseY = $this.ChaseGame.GooseY
                    Score = $this.ChaseGame.Score
                    TimeLeft = $this.ChaseGame.TimeLeft
                    IsRunning = $this.ChaseGame.IsRunning
                }
            }
            "icon_heist" {
                return @{
                    StolenCount = $this.IconHeist.StolenCount
                    MissedCount = $this.IconHeist.MissedCount
                    IsRunning = $this.IconHeist.IsRunning
                }
            }
            "dodge_goose" {
                return @{
                    PlayerX = $this.DodgeGame.PlayerX
                    PlayerY = $this.DodgeGame.PlayerY
                    Score = $this.DodgeGame.Score
                    Lives = $this.DodgeGame.Lives
                    IsRunning = $this.DodgeGame.IsRunning
                }
            }
            default {
                return @{}
            }
        }
    }
    
    [void] RecordGameStart([string]$gameName) {
        if (-not $this.GameStats.ContainsKey("${gameName}_games")) {
            $this.GameStats["${gameName}_games"] = 0
        }
    }
    
    [void] RecordGameEnd([string]$gameName, [int]$score) {
        $this.SaveData()
    }
    
    [hashtable] GetHighScores() {
        return @{
            GooseChase = $this.GameStats["goose_chase_highscore"] -or 0
            IconHeist = $this.GameStats["icon_heist_highscore"] -or 0
            DodgeGoose = $this.GameStats["dodge_goose_highscore"] -or 0
        }
    }
    
    [hashtable] GetExtendedGamesState() {
        return @{
            Enabled = $this.Enabled
            AvailableGames = $this.GetAvailableGames()
            HighScores = $this.GetHighScores()
            GameStats = $this.GameStats
        }
    }
}

$gooseGamesExtended = [GooseMiniGamesExtended]::new()

function Get-GooseGamesExtended {
    return $gooseGamesExtended
}

function Start-ExtendedGame {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("goose_chase", "icon_heist", "dodge_goose")]
        [string]$GameName,
        $Games = $gooseGamesExtended
    )
    return $Games.StartGame($GameName)
}

function End-ExtendedGame {
    param(
        [Parameter(Mandatory=$true)]
        [string]$GameName,
        [Parameter(Mandatory=$true)]
        [int]$Score,
        $Games = $gooseGamesExtended
    )
    return $Games.EndGame($GameName, $Score)
}

function Update-GameState {
    param(
        [Parameter(Mandatory=$true)]
        [string]$GameName,
        [Parameter(Mandatory=$true)]
        [hashtable]$NewState,
        $Games = $gooseGamesExtended
    )
    return $Games.UpdateGameState($GameName, $NewState)
}

function Get-GameState {
    param(
        [Parameter(Mandatory=$true)]
        [string]$GameName,
        $Games = $gooseGamesExtended
    )
    return $Games.GetGameState($GameName)
}

function Get-ExtendedHighScores {
    param($Games = $gooseGamesExtended)
    return $Games.GetHighScores()
}

function Get-ExtendedGamesState {
    param($Games = $gooseGamesExtended)
    return $Games.GetExtendedGamesState()
}

Write-Host "Desktop Goose Extended Mini Games Initialized"
$state = Get-ExtendedGamesState
Write-Host "Extended Games Enabled: $($state['Enabled']) | Games: $($state['AvailableGames'].Count)"
