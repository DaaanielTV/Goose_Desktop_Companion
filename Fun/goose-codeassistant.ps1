# Desktop Goose Code Assistant
# AI-powered code help and review

enum CodeLanguage {
    Unknown
    PowerShell
    JavaScript
    Python
    CSharp
    Java
    Cpp
    HTML
    CSS
    SQL
    Bash
    JSON
    YAML
    Markdown
}

class CodeSnippet {
    [string]$Id
    [string]$Code
    [CodeLanguage]$Language
    [datetime]$CreatedAt
    [string]$Review
    [hashtable]$Suggestions
    
    CodeSnippet([string]$code) {
        $this.Id = [guid]::NewGuid().ToString().Substring(0, 8)
        $this.Code = $code
        $this.Language = [CodeLanguage]::Unknown
        $this.CreatedAt = Get-Date
        $this.Review = ""
        $this.Suggestions = @{}
        $this.DetectLanguage()
    }
    
    [void] DetectLanguage() {
        $code = $this.Code.Trim()
        
        if ($code -match '^#.*script' -or $code -match 'param\(' -or $code -match '\[.*\]\::new') {
            $this.Language = [CodeLanguage]::PowerShell
        } elseif ($code -match 'function\s+\w+' -or $code -match '\$\w+\s*=') {
            $this.Language = [CodeLanguage]::PowerShell
        } elseif ($code -match 'def\s+\w+\s*\(' -or $code -match 'import\s+\w+' -or $code -match 'print\(') {
            $this.Language = [CodeLanguage]::Python
        } elseif ($code -match 'function\s+\w+\s*\(' -or $code -match 'const\s+\w+' -or $code -match '=>\s*{') {
            $this.Language = [CodeLanguage]::JavaScript
        } elseif ($code -match 'public\s+class' -or $code -match 'using\s+System') {
            $this.Language = [CodeLanguage]::CSharp
        } elseif ($code -match 'SELECT|INSERT|UPDATE|DELETE|CREATE\s+TABLE') {
            $this.Language = [CodeLanguage]::SQL
        } elseif ($code -match '<\?php' -or $code -match '\$\w+\s*=') {
            $this.Language = [CodeLanguage]::PHP
        } elseif ($code -match '<html|<div|<span|<!DOCTYPE') {
            $this.Language = [CodeLanguage]::HTML
        } elseif ($code -match '^\s*\{' -and $code -match ':') {
            $this.Language = [CodeLanguage]::JSON
        } elseif ($code -match '^#!/bin/bash|^#!/bin/sh') {
            $this.Language = [CodeLanguage]::Bash
        }
    }
}

class GooseCodeAssistant {
    [hashtable]$Config
    [System.Collections.ArrayList]$Snippets
    [string]$DataFile
    [bool]$Enabled
    [string]$AIEndpoint
    [string]$Model
    
    GooseCodeAssistant() {
        $this.Config = $this.LoadConfig()
        $this.Snippets = [System.Collections.ArrayList]::new()
        $this.DataFile = "goose_codeassistant.json"
        $this.AIEndpoint = "http://localhost:11434/api/generate"
        $this.Model = "codellama"
        $this.Enabled = $false
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
        
        if (-not $this.Config.ContainsKey("CodeAssistantEnabled")) {
            $this.Config["CodeAssistantEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] LoadData() {
        if (Test-Path $this.DataFile) {
            try {
                $data = Get-Content $this.DataFile -Raw | ConvertFrom-Json
                $this.Snippets.Clear()
                foreach ($s in $data.snippets) {
                    $snippet = [CodeSnippet]::new($s.code)
                    $snippet.Language = [CodeLanguage]$s.language
                    $snippet.Review = $s.review
                    $this.Snippets.Add($snippet)
                }
            } catch {}
        }
        
        $this.Enabled = $this.Config["CodeAssistantEnabled"]
    }
    
    [void] SaveData() {
        $data = @{
            "snippets" = @($this.Snippets | ForEach-Object {
                @{
                    id = $_.Id
                    code = $_.Code
                    language = $_.Language.ToString()
                    review = $_.Review
                    createdAt = $_.CreatedAt.ToString("o")
                }
            })
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.DataFile -Encoding UTF8
    }
    
    [hashtable] AnalyzeCode([string]$code) {
        $result = @{
            success = $false
            snippetId = ""
            language = "Unknown"
            review = ""
            suggestions = @()
            honkComment = ""
        }
        
        $snippet = [CodeSnippet]::new($code)
        $result.snippetId = $snippet.Id
        $result.language = $snippet.Language.ToString()
        
        $review = $this.GenerateReview($code, $snippet.Language)
        $suggestions = $this.GenerateSuggestions($code, $snippet.Language)
        
        $snippet.Review = $review
        $snippet.Suggestions = $suggestions
        
        $this.Snippets.Insert(0, $snippet)
        
        if ($this.Snippets.Count -gt 50) {
            $this.Snippets.RemoveAt($this.Snippets.Count - 1)
        }
        
        $this.SaveData()
        
        $result.success = $true
        $result.review = $review
        $result.suggestions = $suggestions
        $result.honkComment = $this.GenerateHonkComment($code, $snippet.Language)
        
        return $result
    }
    
    [string] GenerateReview([string]$code, [CodeLanguage]$language) {
        $issues = @()
        
        if ($code.Length -lt 10) {
            $issues += "Code ist zu kurz für eine vernünftige Analyse."
        }
        
        if ($code -match 'TODO|FIXME|HACK|XXX') {
            $issues += "Es gibt offene TODO-Kommentare im Code."
        }
        
        if ($language -eq [CodeLanguage]::PowerShell) {
            if ($code -match 'Get-Process|Get-Service' -and $code -notmatch 'ErrorAction') {
                $issues += "Fehlende ErrorHandling für Cmdlets."
            }
            if ($code -match 'Write-Host' -and $code -match 'pipeline') {
                $issues += "Write-Host sollte vermieden werden, nutze Write-Output."
            }
            if ($code.Length -gt 200 -and $code -notmatch 'function') {
                $issues += "Code sollte in Funktionen organisiert werden."
            }
        }
        
        if ($language -eq [CodeLanguage]::JavaScript -or $language -eq [CodeLanguage]::Python) {
            if ($code -match 'var\s+\w+' -and $language -eq [CodeLanguage]::JavaScript) {
                $issues += "Nutze 'const' oder 'let' statt 'var'."
            }
            if ($code -match 'print\s+' -and $language -eq [CodeLanguage]::Python) {
                $issues += "Print() ist okay, aber logging wäre besser."
            }
        }
        
        if ($issues.Count -eq 0) {
            return "Sieht okay aus! HONK! 🦆"
        }
        
        return ($issues -join "`n- ")
    }
    
    [hashtable] GenerateSuggestions([string]$code, [CodeLanguage]$language) {
        $suggestions = @()
        
        if ($language -eq [CodeLanguage]::PowerShell) {
            if ($code -notmatch 'param\(' -and $code.Length -gt 50) {
                $suggestions += @{
                    type = "structure"
                    text = "Füge einen param()-Block hinzu für Parameter"
                    example = "param([string]$Name)"
                }
            }
            
            if ($code -match 'Get-.*\|.*Get-' -or $code.Length -gt 300) {
                $suggestions += @{
                    type = "performance"
                    text = "Überlege dir Pipeline-Ketten zu reduzieren"
                }
            }
        }
        
        if ($language -eq [CodeLanguage]::JavaScript) {
            if ($code -match 'function\s+\w+\s*\(' -and $code -notmatch '=>') {
                $suggestions += @{
                    type = "modern"
                    text = "Nutze Arrow Functions wo möglich"
                }
            }
        }
        
        if ($code -match 'password|secret|api[_-]?key|token' -and $code -notmatch 'env|config') {
            $suggestions += @{
                type = "security"
                text = "Sensible Daten nicht hardcodieren!"
                severity = "high"
            }
        }
        
        return $suggestions
    }
    
    [string] GenerateHonkComment([string]$code, [CodeLanguage]$language) {
        $comments = @()
        
        switch ($language) {
            ([CodeLanguage]::PowerShell) {
                $comments = @(
                    "# HONK! This script runs!",
                    "# TODO: Make it not crash HONK",
                    "# This works. Don't touch it. - The Goose",
                    "# Powered by CHAOS and HONK",
                    "# If it works, don't fix it! 🦆"
                )
            }
            ([CodeLanguage]::JavaScript) {
                $comments = @(
                    "// HONK! It works somehow!",
                    "// const HONK = 'honk';",
                    "// TODO: Add more HONK",
                    "// console.log('🦆')",
                    "// Powered by Goose Inc."
                )
            }
            ([CodeLanguage]::Python) {
                $comments = @(
                    "# HONK: It runs!",
                    "# TODO: Fix later, maybe",
                    "# Powered by Goose",
                    "# Works on my machine™"
                )
            }
            default {
                $comments = @(
                    "// HONK!",
                    "# Powered by Duck typing 🦆",
                    "/* HONK */"
                )
            }
        }
        
        return $comments | Get-Random
    }
    
    [string] ExplainError([string]$errorMessage) {
        $errorLower = $errorMessage.ToLower()
        
        if ($errorLower -match "null.*reference|object.*reference") {
            return "HONK! Du greifst auf etwas zu, das null ist! Prüfe ob deine Variable initialisiert ist."
        }
        
        if ($errorLower -match "index.*out.*of.*range|argument.*out.*of.*range") {
            return "Array-Index außerhalb der Grenzen! Dein Index ist zu groß oder negativ. HONK!"
        }
        
        if ($errorLower -match "syntax.*error|parse.*error") {
            return "Syntaxfehler! Da fehlt irgendwas oder ist zuviel. Klammern, Semikolons, Anführungszeichen - alles prüfen!"
        }
        
        if ($errorLower -match "permission.*denied|access.*denied") {
            return "Keine Berechtigung! Du brauchst Admin-Rechte oder die Datei ist schreibgeschützt. HONK!"
        }
        
        if ($errorLower -match "file.*not.*found|cannot.*find") {
            return "Datei nicht gefunden! Pfad stimmt nicht oder Datei existiert nicht. HONK!"
        }
        
        if ($errorLower -match "timeout") {
            return "Zeitüberschreitung! Server zu langsam oder Netzwerkprobleme. HONK - Geduld!"
        }
        
        if ($errorLower -match "type.*error|cast.*exception") {
            return "Typfehler! Du versuchst einen Typ in einen anderen zu konvertieren, das geht nicht. HONK!"
        }
        
        $funnyExplanations = @(
            "HONK! Das sagt mir auch nichts. Google ist dein Freund!",
            "Irgendwas ist kaputt. Aber was? Die Gans weiß es auch nicht!",
            "Fehler! HONK! Das ist alles was ich weiß!",
            "Da hat sich ein Bug eingeschlichen! 🐛→🦆",
            "Computer sagt nein. Und die Gans auch!"
        )
        
        return $funnyExplanations | Get-Random
    }
    
    [string] GenerateComments([string]$code) {
        $snippet = [CodeSnippet]::new($code)
        $language = $snippet.Language
        
        $lines = $code -split "`n"
        $commentedLines = @()
        
        foreach ($line in $lines) {
            if ($line.Trim() -eq "") {
                $commentedLines += ""
                continue
            }
            
            $comment = switch ($language) {
                ([CodeLanguage]::PowerShell) { "# " }
                ([CodeLanguage]::JavaScript) { "// " }
                ([CodeLanguage]::Python) { "# " }
                ([CodeLanguage]::CSharp) { "// " }
                ([CodeLanguage]::SQL) { "-- " }
                default { "# " }
            }
            
            if ($line.Trim() -match '^(function|def|class|public|private|async)') {
                $comment += "[FUNC] "
            } elseif ($line.Trim() -match '^(if|else|for|while|switch)') {
                $comment += "[LOGIC] "
            } elseif ($line.Trim() -match '^(var|let|const|int|string|bool)') {
                $comment += "[VAR] "
            } elseif ($line.Trim() -match 'return') {
                $comment += "[RET] "
            }
            
            $comment += switch (Get-Random -Maximum 5) {
                0 { "HONK: This does something" }
                1 { "TODO: Figure this out later" }
                2 { "Magic happens here ✨" }
                3 { "Don't touch! It works!" }
                4 { "Ancient wisdom" }
            }
            
            $commentedLines += "$comment`n$line"
        }
        
        return $commentedLines -join "`n"
    }
    
    [hashtable] GetCodeAssistantState() {
        return @{
            Enabled = $this.Enabled
            SnippetCount = $this.Snippets.Count
            Model = $this.Model
            RecentReviews = @($this.Snippets | Select-Object -First 5 | ForEach-Object {
                @{
                    Id = $_.Id
                    Language = $_.Language.ToString()
                    Review = $_.Review.Substring(0, [Math]::Min(50, $_.Review.Length))
                }
            })
        }
    }
}

$gooseCodeAssistant = [GooseCodeAssistant]::new()

function Get-GooseCodeAssistant {
    return $gooseCodeAssistant
}

function Analyze-Code {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Code,
        $CodeAssistant = $gooseCodeAssistant
    )
    return $CodeAssistant.AnalyzeCode($Code)
}

function Explain-Error {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ErrorMessage,
        $CodeAssistant = $gooseCodeAssistant
    )
    return $CodeAssistant.ExplainError($ErrorMessage)
}

function Generate-CodeComments {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Code,
        $CodeAssistant = $gooseCodeAssistant
    )
    return $CodeAssistant.GenerateComments($Code)
}

function Get-CodeAssistantState {
    param($CodeAssistant = $gooseCodeAssistant)
    return $CodeAssistant.GetCodeAssistantState()
}

Write-Host "Desktop Goose Code Assistant Initialized"
$state = Get-CodeAssistantState
Write-Host "Code Assistant Enabled: $($state['Enabled']) | Reviews: $($state['SnippetCount'])"
