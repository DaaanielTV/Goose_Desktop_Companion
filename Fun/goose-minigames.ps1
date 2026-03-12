# Desktop Goose Mini Games System
# Fun mini games to play with the goose

class GooseMiniGames {
    [hashtable]$Config
    [bool]$IsEnabled
    [string]$CurrentGame
    [hashtable]$HighScores
    [hashtable]$GameHistory
    [int]$TotalGamesPlayed
    
    GooseMiniGames() {
        $this.Config = $this.LoadConfig()
        $this.IsEnabled = $false
        $this.CurrentGame = ""
        $this.HighScores = @{}
        $this.GameHistory = @{}
        $this.TotalGamesPlayed = 0
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
        
        return $this.Config
    }
    
    [void] LoadData() {
        $dataFile = "goose_minigames.json"
        
        if (Test-Path $dataFile) {
            try {
                $data = Get-Content $dataFile -Raw | ConvertFrom-Json
                
                if ($data.highScores) {
                    $this.HighScores = @{}
                    $data.highScores.PSObject.Properties | ForEach-Object {
                        $this.HighScores[$_.Name] = $_.Value
                    }
                }
                
                if ($data.gameHistory) {
                    $this.GameHistory = @{}
                    $data.gameHistory.PSObject.Properties | ForEach-Object {
                        $this.GameHistory[$_.Name] = $_.Value
                    }
                }
                
                if ($data.totalGamesPlayed) {
                    $this.TotalGamesPlayed = $data.totalGamesPlayed
                }
            } catch {}
        }
        
        $this.IsEnabled = $this.Config["MiniGamesEnabled"]
    }
    
    [void] SaveData() {
        $data = @{
            "highScores" = $this.HighScores
            "gameHistory" = $this.GameHistory
            "totalGamesPlayed" = $this.TotalGamesPlayed
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content "goose_minigames.json"
    }
    
    [string[]] GetAvailableGames() {
        return @("whack_goose", "memory_match", "quiz", "word_game")
    }
    
    [hashtable] StartGame([string]$gameName) {
        $validGames = $this.GetAvailableGames()
        
        if ($validGames -notcontains $gameName) {
            return @{
                "success" = $false
                "message" = "Game not found"
            }
        }
        
        $this.CurrentGame = $gameName
        $this.TotalGamesPlayed++
        
        switch ($gameName) {
            "whack_goose" {
                return @{
                    "success" = $true
                    "game" = $gameName
                    "name" = "Whack-a-Goose"
                    "description" = "Click on the goose when it pops up!"
                    "instructions" = "Click the goose as fast as you can when it appears. You have 30 seconds."
                    "duration" = 30
                    "maxScore" = 20
                }
            }
            "memory_match" {
                return @{
                    "success" = $true
                    "game" = $gameName
                    "name" = "Memory Match"
                    "description" = "Match pairs of cards!"
                    "instructions" = "Flip cards to find matching pairs. Match all pairs to win!"
                    "cards" = 8
                    "pairs" = 4
                }
            }
            "quiz" {
                return @{
                    "success" = $true
                    "game" = $gameName
                    "name" = "Goose Quiz"
                    "description" = "Answer questions about the goose!"
                    "instructions" = "Answer 10 questions about Desktop Goose. Each correct answer is 10 points."
                    "questions" = 10
                }
            }
            "word_game" {
                return @{
                    "success" = $true
                    "game" = $gameName
                    "name" = "Word Game"
                    "description" = "Form words from letters!"
                    "instructions" = "Given 6 letters, form as many words as you can. Minimum 3 letters."
                    "letters" = 6
                    "time" = 60
                }
            }
        }
        
        return @{
            "success" = $false
            "message" = "Game not implemented"
        }
    }
    
    [hashtable] EndGame([string]$gameName, [int]$score) {
        $this.RecordGameResult($gameName, $score)
        
        $isNewHighScore = $this.UpdateHighScore($gameName, $score)
        
        $message = "Game over! Score: $score"
        if ($isNewHighScore) {
            $message += " NEW HIGH SCORE!"
        }
        
        $this.CurrentGame = ""
        
        return @{
            "success" = $true
            "score" = $score
            "highScore" = $this.HighScores[$gameName]
            "isNewHighScore" = $isNewHighScore
            "message" = $message
            "totalPlayed" = $this.TotalGamesPlayed
        }
    }
    
    [bool] UpdateHighScore([string]$gameName, [int]$score) {
        $currentHigh = $this.HighScores[$gameName]
        
        if (-not $currentHigh -or $score -gt $currentHigh.score) {
            $this.HighScores[$gameName] = @{
                "score" = $score
                "date" = (Get-Date).ToString("o")
                "player" = "Player"
            }
            $this.SaveData()
            return $true
        }
        
        return $false
    }
    
    [void] RecordGameResult([string]$gameName, [int]$score) {
        $timestamp = Get-Date.ToString("yyyy-MM-dd HH:mm")
        
        if (-not $this.GameHistory.ContainsKey($gameName)) {
            $this.GameHistory[$gameName] = @{
                "game" = $gameName
                "plays" = 0
                "totalScore" = 0
                "results" = @()
            }
        }
        
        $gameStats = $this.GameHistory[$gameName]
        $gameStats.plays++
        $gameStats.totalScore += $score
        
        $result = @{
            "timestamp" = (Get-Date).ToString("o")
            "score" = $score
        }
        
        $gameStats.results += $result
        
        if ($gameStats.results.Count -gt 20) {
            $gameStats.results = $gameStats.results[-20..-1]
        }
        
        $this.GameHistory[$gameName] = $gameStats
        $this.SaveData()
    }
    
    [hashtable] GetHighScore([string]$gameName) {
        if ($this.HighScores.ContainsKey($gameName)) {
            return $this.HighScores[$gameName]
        }
        return @{
            "score" = 0
            "date" = $null
            "player" = ""
        }
    }
    
    [hashtable] GetAllHighScores() {
        return $this.HighScores
    }
    
    [hashtable] GetGameStats([string]$gameName) {
        if ($this.GameHistory.ContainsKey($gameName)) {
            return $this.GameHistory[$gameName]
        }
        return @{
            "plays" = 0
            "totalScore" = 0
            "averageScore" = 0
        }
    }
    
    [hashtable] GetLeaderboard([string]$gameName, [int]$top = 10) {
        if ($this.GameHistory.ContainsKey($gameName)) {
            $results = $this.GameHistory[$gameName].results | Sort-Object { $_.score } -Descending | Select-Object -First $top
            return $results
        }
        return @()
    }
    
    [hashtable] GetWhackGooseQuestion() {
        return @{
            "question" = "Where did the goose appear?"
            "options" = @("Top-left", "Top-right", "Bottom-left", "Bottom-right")
            "answer" = 0
        }
    }
    
    [hashtable[]] GetQuizQuestions() {
        return @(
            @{
                "question" = "What sound does a goose make?"
                "options" = @("Moo", "Honk", "Quack", "Woof")
                "answer" = 1
            },
            @{
                "question" = "What is a baby goose called?"
                "options" = @("Chick", "Gosling", "Duckling", "Fawn")
                "answer" = 1
            },
            @{
                "question" = "How many legs does a goose have?"
                "options" = @("2", "4", "6", "8")
                "answer" = 0
            },
            @{
                "question" = "What do geese eat?"
                "options" = @("Meat", "Grass", "Fish", "Insects")
                "answer" = 1
            },
            @{
                "question" = "Where do geese build nests?"
                "options" = @("Trees", "Underground", "On the ground", "In caves")
                "answer" = 2
            },
            @{
                "question" = "How long can geese live?"
                "options" = @("5-10 years", "10-20 years", "20-30 years", "30-40 years")
                "answer" = 2
            },
            @{
                "question" = "Do geese migrate?"
                "options" = @("No", "Sometimes", "Yes", "Only once")
                "answer" = 2
            },
            @{
                "question" = "What is a group of geese called?"
                "options" = @("Flock", "Herd", "Pack", "School")
                "answer" = 0
            },
            @{
                "question" = "Can geese swim?"
                "options" = @("No", "Yes", "Only in salt water", "Only in rivers")
                "answer" = 1
            },
            @{
                "question" = "What color are most geese?"
                "options" = @("Brown only", "White only", "Black and white", "Gray and white")
                "answer" = 3
            }
        )
    }
    
    [hashtable] GetOverallStats() {
        $totalPlays = 0
        $totalScore = 0
        
        foreach ($game in $this.GameHistory.Values) {
            $totalPlays += $game.plays
            $totalScore += $game.totalScore
        }
        
        return @{
            "totalGamesPlayed" = $this.TotalGamesPlayed
            "totalGames" = $this.GameHistory.Count
            "totalScore" = $totalScore
            "averageScore" = if ($totalPlays -gt 0) { [Math]::Round($totalScore / $totalPlays) } else { 0 }
            "uniqueGamesPlayed" = $this.GameHistory.Count
        }
    }
    
    [void] ResetHighScores() {
        $this.HighScores = @{}
        $this.SaveData()
    }
    
    [void] SetEnabled([bool]$enabled) {
        $this.IsEnabled = $enabled
        $this.Config["MiniGamesEnabled"] = $enabled
    }
    
    [void] Toggle() {
        $this.IsEnabled = -not $this.IsEnabled
        $this.Config["MiniGamesEnabled"] = $this.IsEnabled
    }
    
    [hashtable] GetMiniGamesState() {
        return @{
            "Enabled" = $this.IsEnabled
            "CurrentGame" = $this.CurrentGame
            "AvailableGames" = $this.GetAvailableGames()
            "HighScores" = $this.GetAllHighScores()
            "Stats" = $this.GetOverallStats()
        }
    }
}

$gooseMiniGames = [GooseMiniGames]::new()

function Get-GooseMiniGames {
    return $gooseMiniGames
}

function Start-MiniGame {
    param(
        [Parameter(Mandatory=$true)]
        [string]$GameName,
        $MiniGames = $gooseMiniGames
    )
    return $MiniGames.StartGame($GameName)
}

function End-MiniGame {
    param(
        [Parameter(Mandatory=$true)]
        [string]$GameName,
        [Parameter(Mandatory=$true)]
        [int]$Score,
        $MiniGames = $gooseMiniGames
    )
    return $MiniGames.EndGame($GameName, $Score)
}

function Get-GameHighScore {
    param(
        [Parameter(Mandatory=$true)]
        [string]$GameName,
        $MiniGames = $gooseMiniGames
    )
    return $MiniGames.GetHighScore($GameName)
}

function Get-AllHighScores {
    param($MiniGames = $gooseMiniGames)
    return $MiniGames.GetAllHighScores()
}

function Get-GameStats {
    param(
        [Parameter(Mandatory=$true)]
        [string]$GameName,
        $MiniGames = $gooseMiniGames
    )
    return $MiniGames.GetGameStats($GameName)
}

function Get-Leaderboard {
    param(
        [Parameter(Mandatory=$true)]
        [string]$GameName,
        [int]$Top = 10,
        $MiniGames = $gooseMiniGames
    )
    return $MiniGames.GetLeaderboard($GameName, $Top)
}

function Get-QuizQuestions {
    param($MiniGames = $gooseMiniGames)
    return $MiniGames.GetQuizQuestions()
}

function Get-OverallStats {
    param($MiniGames = $gooseMiniGames)
    return $MiniGames.GetOverallStats()
}

function Reset-HighScores {
    param($MiniGames = $gooseMiniGames)
    $MiniGames.ResetHighScores()
}

function Enable-MiniGames {
    param($MiniGames = $gooseMiniGames)
    $MiniGames.SetEnabled($true)
}

function Disable-MiniGames {
    param($MiniGames = $gooseMiniGames)
    $MiniGames.SetEnabled($false)
}

function Toggle-MiniGames {
    param($MiniGames = $gooseMiniGames)
    $MiniGames.Toggle()
}

function Get-MiniGamesState {
    param($MiniGames = $gooseMiniGames)
    return $MiniGames.GetMiniGamesState()
}

Write-Host "Desktop Goose Mini Games System Initialized"
$state = Get-MiniGamesState
Write-Host "Mini Games Enabled: $($state['Enabled'])"
Write-Host "Games Available: $($state['AvailableGames'].Count)"
Write-Host "Total Games Played: $($state['Stats']['totalGamesPlayed'])"
