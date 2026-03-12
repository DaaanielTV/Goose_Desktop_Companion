# Desktop Goose Learning System
# Gamified productivity with quizzes and coding streaks

class QuizQuestion {
    [string]$Id
    [string]$Question
    [string[]]$Options
    [int]$CorrectIndex
    [string]$Explanation
    [string]$Category
    
    QuizQuestion([string]$id, [string]$q, [string[]]$opts, [int]$correct, [string]$explanation, [string]$category) {
        $this.Id = $id
        $this.Question = $q
        $this.Options = $opts
        $this.CorrectIndex = $correct
        $this.Explanation = $explanation
        $this.Category = $category
    }
}

class UserStreak {
    [int]$CurrentStreak
    [int]$LongestStreak
    [datetime]$LastActivity
    [int]$TotalDays
    
    UserStreak() {
        $this.CurrentStreak = 0
        $this.LongestStreak = 0
        $this.LastActivity = [datetime]::MinValue
        $this.TotalDays = 0
    }
}

class GooseLearning {
    [hashtable]$Config
    [UserStreak]$Streak
    [System.Collections.ArrayList]$Questions
    [System.Collections.ArrayList]$QuizHistory
    [int]$TotalXP
    [int]$Level
    [hashtable]$Stats
    [string]$DataFile
    
    GooseLearning() {
        $this.Config = $this.LoadConfig()
        $this.Streak = [UserStreak]::new()
        $this.Questions = [System.Collections.ArrayList]::new()
        $this.QuizHistory = [System.Collections.ArrayList]::new()
        $this.TotalXP = 0
        $this.Level = 1
        $this.Stats = @{}
        $this.DataFile = "goose_learning.json"
        $this.LoadData()
        $this.InitializeQuestions()
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
        
        if (-not $this.Config.ContainsKey("LearningEnabled")) {
            $this.Config["LearningEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("LearningXPPerCorrect")) {
            $this.Config["LearningXPPerCorrect"] = 10
        }
        if (-not $this.Config.ContainsKey("LearningXPPerQuiz")) {
            $this.Config["LearningXPPerQuiz"] = 5
        }
        
        return $this.Config
    }
    
    [void] LoadData() {
        if (Test-Path $this.DataFile) {
            try {
                $data = Get-Content $this.DataFile -Raw | ConvertFrom-Json
                
                $this.Streak.CurrentStreak = $data.streak.current
                $this.Streak.LongestStreak = $data.streak.longest
                $this.Streak.LastActivity = [datetime]::Parse($data.streak.lastActivity)
                $this.Streak.TotalDays = $data.streak.totalDays
                
                $this.TotalXP = $data.xp
                $this.Level = $data.level
                
                if ($data.quizHistory) {
                    $this.QuizHistory = [System.Collections.ArrayList]::new($data.quizHistory)
                }
                
                if ($data.stats) {
                    $this.Stats = @{}
                    $data.stats.PSObject.Properties | ForEach-Object {
                        $this.Stats[$_.Name] = $_.Value
                    }
                }
                
                $this.UpdateLevel()
            } catch {}
        }
    }
    
    [void] SaveData() {
        $data = @{
            streak = @{
                current = $this.Streak.CurrentStreak
                longest = $this.Streak.LongestStreak
                lastActivity = $this.Streak.LastActivity.ToString("o")
                totalDays = $this.Streak.TotalDays
            }
            xp = $this.TotalXP
            level = $this.Level
            quizHistory = @($this.QuizHistory)
            stats = $this.Stats
            lastSaved = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.DataFile -Encoding UTF8
    }
    
    [void] InitializeQuestions() {
        if ($this.Questions.Count -gt 0) { return }
        
        $this.Questions.Add([QuizQuestion]::new(
            "ps1", 
            "Welches Cmdlet in PowerShell gibt Prozesse zurück?",
            @("Get-Service", "Get-Process", "Get-ChildItem", "Get-Content"),
            1,
            "Get-Process gibt die aktuell laufenden Prozesse zurück.",
            "PowerShell"
        ))
        
        $this.Questions.Add([QuizQuestion]::new(
            "ps2",
            "Wie definierst du einen Parameter in PowerShell?",
            @("param()", "parameter", "args", "function param"),
            0,
            "Der param()-Block wird am Anfang eines Skripts oder einer Funktion verwendet.",
            "PowerShell"
        ))
        
        $this.Questions.Add([QuizQuestion]::new(
            "ps3",
            "Was macht -ErrorAction SilentlyContinue?",
            @("Beendet das Skript", "Unterdrückt Fehlermeldungen", "Loggt Fehler", "Wirft Exception"),
            1,
            "Es unterdrückt die Fehlerausgabe aber behandelt den Fehler weiter.",
            "PowerShell"
        ))
        
        $this.Questions.Add([QuizQuestion]::new(
            "py1",
            "Wie importierst du ein Modul in Python?",
            @("import module", "require module", "using module", "include module"),
            0,
            "Python nutzt das 'import' Keyword.",
            "Python"
        ))
        
        $this.Questions.Add([QuizQuestion]::new(
            "py2",
            "Was ist der Unterschied zwischen list und tuple?",
            @("Keins", "Tuple ist mutable, List nicht", "List ist mutable, Tuple nicht", "Beide sind immutable"),
            2,
            "Listen sind mutable (veränderbar), Tupel sind immutable.",
            "Python"
        ))
        
        $this.Questions.Add([QuizQuestion]::new(
            "js1",
            "Wie deklariert man eine Konstante in JavaScript?",
            @("constant x = 5", "const x = 5", "let x = 5", "var x = 5"),
            1,
            "const wird für Konstanten verwendet, die nicht überschrieben werden sollen.",
            "JavaScript"
        ))
        
        $this.Questions.Add([QuizQuestion]::new(
            "js2",
            "Was ist eine Arrow Function?",
            @("Eine Funktion die fliegt", "Eine anonyme Funktion mit => Syntax", "Eine rekursive Funktion", "Eine built-in Funktion"),
            1,
            "Arrow Functions sind eine kürzere Syntax für Funktionen in JavaScript.",
            "JavaScript"
        ))
        
        $this.Questions.Add([QuizQuestion]::new(
            "git1",
            "Welcher Befehl lädt Änderungen vom Remote herunter?",
            @("git push", "git pull", "git commit", "git status"),
            1,
            "git pull holt Änderungen vom Remote Repository.",
            "Git"
        ))
        
        $this.Questions.Add([QuizQuestion]::new(
            "git2",
            "Was macht 'git stash'?",
            @("Löscht Dateien", "Speichert Änderungen temporär", "Erstellt Branch", "Merge Changes"),
            1,
            "git stash speichert uncommitted Änderungen temporär.",
            "Git"
        ))
        
        $this.Questions.Add([QuizQuestion]::new(
            "algo1",
            "Was ist die Zeitkomplexität von Binary Search?",
            @("O(n)", "O(n²)", "O(log n)", "O(1)"),
            2,
            "Binary Search hat logarithmische Komplexität O(log n).",
            "Algorithmen"
        ))
        
        $this.Questions.Add([QuizQuestion]::new(
            "algo2",
            "Welche Datenstruktur nutzt LIFO?",
            @("Queue", "Stack", "Array", "HashMap"),
            1,
            "Stack nutzt Last-In-First-Out (LIFO).",
            "Algorithmen"
        ))
        
        $this.Questions.Add([QuizQuestion]::new(
            "sec1",
            "Was ist SQL Injection?",
            @("Ein SQL Server Fehler", "Bösartiger Code in SQL-Abfragen", "Ein Datenbank-Backup", "Ein Index-Problem"),
            1,
            "SQL Injection fügt bösartigen Code in SQL-Abfragen ein.",
            "Security"
        ))
    }
    
    [hashtable] GetRandomQuestion([string]$category = $null) {
        $available = $this.Questions
        
        if ($category) {
            $available = $available | Where-Object { $_.Category -eq $category }
        }
        
        if ($available.Count -eq 0) {
            return $null
        }
        
        $question = $available | Get-Random
        
        return @{
            id = $question.Id
            question = $question.Question
            options = $question.Options
            category = $question.Category
        }
    }
    
    [hashtable] AnswerQuestion([string]$questionId, [int]$answerIndex) {
        $question = $this.Questions | Where-Object { $_.Id -eq $questionId } | Select-Object -First 1
        
        $result = @{
            success = $false
            correct = $false
            xpEarned = 0
            explanation = ""
            streakUpdated = $false
        }
        
        if (-not $question) {
            $result.explanation = "Frage nicht gefunden!"
            return $result
        }
        
        $isCorrect = ($answerIndex -eq $question.CorrectIndex)
        $result.correct = $isCorrect
        $result.explanation = $question.Explanation
        
        if ($isCorrect) {
            $xp = $this.Config["LearningXPPerCorrect"]
            $this.TotalXP += $xp
            $result.xpEarned = $xp
            
            $this.RecordActivity("quiz_correct")
        } else {
            $xp = 2
            $this.TotalXP += $xp
            $result.xpEarned = $xp
        }
        
        $this.UpdateLevel()
        
        $historyEntry = @{
            questionId = $questionId
            answerIndex = $answerIndex
            correct = $isCorrect
            timestamp = (Get-Date).ToString("o")
            xpEarned = $result.xpEarned
        }
        $this.QuizHistory.Insert(0, $historyEntry)
        
        if ($this.QuizHistory.Count -gt 100) {
            $this.QuizHistory.RemoveAt($this.QuizHistory.Count - 1)
        }
        
        $this.SaveData()
        $result.success = $true
        
        return $result
    }
    
    [void] RecordActivity([string]$activityType) {
        $now = Get-Date
        $today = $now.Date
        
        if ($this.Streak.LastActivity -eq [datetime]::MinValue) {
            $this.Streak.CurrentStreak = 1
            $this.Streak.TotalDays = 1
            $this.Streak.LastActivity = $now
            return
        }
        
        $lastDate = $this.Streak.LastActivity.Date
        $daysDiff = ($today - $lastDate).Days
        
        if ($daysDiff -eq 0) {
            return
        } elseif ($daysDiff -eq 1) {
            $this.Streak.CurrentStreak++
            $this.Streak.TotalDays++
        } else {
            $this.Streak.CurrentStreak = 1
            $this.Streak.TotalDays++
        }
        
        if ($this.Streak.CurrentStreak -gt $this.Streak.LongestStreak) {
            $this.Streak.LongestStreak = $this.Streak.CurrentStreak
        }
        
        $this.Streak.LastActivity = $now
        
        $this.Stats[$activityType]++
        
        $xp = switch ($activityType) {
            "coding" { 10 }
            "break" { 5 }
            "quiz_correct" { 10 }
            "quiz_wrong" { 2 }
            default { 1 }
        }
        
        $this.TotalXP += $xp
        $this.UpdateLevel()
        $this.SaveData()
    }
    
    [void] UpdateLevel() {
        $this.Level = [int]([Math]::Floor([Math]::Sqrt($this.TotalXP / 100)) + 1)
    }
    
    [hashtable] GetLevelInfo() {
        $xpForCurrentLevel = (($this.Level - 1) * ($this.Level - 1)) * 100
        $xpForNextLevel = ($this.Level * $this.Level) * 100
        $xpProgress = $this.TotalXP - $xpForCurrentLevel
        $xpNeeded = $xpForNextLevel - $xpForCurrentLevel
        
        return @{
            level = $this.Level
            totalXP = $this.TotalXP
            xpProgress = $xpProgress
            xpNeeded = $xpNeeded
            progressPercent = [Math]::Round(($xpProgress / $xpNeeded) * 100, 1)
        }
    }
    
    [hashtable] GetLearningState() {
        return @{
            Enabled = $this.Config["LearningEnabled"]
            Streak = @{
                Current = $this.Streak.CurrentStreak
                Longest = $this.Streak.LongestStreak
                TotalDays = $this.Streak.TotalDays
                LastActivity = $this.Streak.LastActivity
            }
            Level = $this.GetLevelInfo()
            QuizStats = @{
                TotalQuizzes = $this.QuizHistory.Count
                CorrectAnswers = ($this.QuizHistory | Where-Object { $_.correct }).Count
                WrongAnswers = ($this.QuizHistory | Where-Object { -not $_.correct }).Count
            }
            Stats = $this.Stats
        }
    }
    
    [string] GetMotivationalMessage() {
        $messages = @()
        
        if ($this.Streak.CurrentStreak -ge 7) {
            $messages += "WOW! $($this.Streak.CurrentStreak) Tage in Folge! Du bist ein Wahnsinniger! HONK! 🦆"
        } elseif ($this.Streak.CurrentStreak -ge 3) {
            $messages += "Super! $($this.Streak.CurrentStreak) Tage Streak! Weiter so!"
        } elseif ($this.Level -ge 10) {
            $messages += "Level $($this.Level)! Du bist ein wahrer Goose Master!"
        } elseif ($this.TotalXP -ge 1000) {
            $messages += "1000 XP! Die Gans ist stolz auf dich!"
        } else {
            $messages += @(
                "Jeder Anfang ist schwer! HONK!",
                "Bleib dran! Die Gans glaubt an dich!",
                "Ein Tag nach dem anderen!",
                "DU kannst das! 🦆💪"
            ) | Get-Random
        }
        
        return $messages | Get-Random
    }
}

$gooseLearning = [GooseLearning]::new()

function Get-GooseLearning {
    return $gooseLearning
}

function Get-RandomQuizQuestion {
    param(
        [string]$Category,
        $Learning = $gooseLearning
    )
    return $Learning.GetRandomQuestion($Category)
}

function Submit-QuizAnswer {
    param(
        [Parameter(Mandatory=$true)]
        [string]$QuestionId,
        [Parameter(Mandatory=$true)]
        [int]$AnswerIndex,
        $Learning = $gooseLearning
    )
    return $Learning.AnswerQuestion($QuestionId, $AnswerIndex)
}

function Record-LearningActivity {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ActivityType,
        $Learning = $gooseLearning
    )
    $Learning.RecordActivity($ActivityType)
    return $Learning.GetLearningState()
}

function Get-LearningState {
    param($Learning = $gooseLearning)
    return $Learning.GetLearningState()
}

function Get-MotivationalMessage {
    param($Learning = $gooseLearning)
    return $Learning.GetMotivationalMessage()
}

Write-Host "Desktop Goose Learning System Initialized"
$state = Get-LearningState
Write-Host "Learning Enabled: $($state['Enabled']) | Level: $($state['Level']['level']) | XP: $($state['Level']['totalXP']) | Streak: $($state['Streak']['Current'])"
