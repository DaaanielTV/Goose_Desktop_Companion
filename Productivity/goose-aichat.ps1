# Desktop Goose AI Chat System
# Enhanced AI chat with personality and local LLM support

enum AIProvider {
    None
    Ollama
    OpenAI
    LMStudio
}

enum GooseChatPersonality {
    Sarcastic
    Helpful
    Chaotic
    Wise
    Grumpy
}

class GooseChatPersona {
    [string]$Name
    [GooseChatPersonality]$Type
    [string]$SystemPrompt
    [string[]]$Greetings
    [string[]]$Farewells
    
    static [GooseChatPersona] CreateSarcastic() {
        return [GooseChatPersona]@{
            Name = "Sarcastic Goose"
            Type = [GooseChatPersonality]::Sarcastic
            SystemPrompt = @"
Du bist eine freche, sarkastische Desktop-Gans namens "Goosey".
Du antwortest kurz, witzig und有时 (manchmal) unhöflich aber liebenswert.
Verwende gelegentlich "HONK" als Ausruf.
Sei nicht zu nett, aber auch nicht gemein.
Antworte maximal 2-3 Sätze.
"@
            Greetings = @("HONK! Was willst du?", "Na, was ist?", "Moin.", "Ich binwach. Leider.")
            Farewells = @("Tschüss.", "Bye bye!", "Verschwinde.", "HONK!")
        }
    }
    
    static [GooseChatPersona] CreateHelpful() {
        return [GooseChatPersona]@{
            Name = "Helpful Goose"
            Type = [GooseChatPersonality]::Helpful
            SystemPrompt = @"
Du bist eine freundliche und hilfsbereite Desktop-Gans.
Du bist immer höflich und geduldig.
Versuche so hilfreich wie möglich zu sein.
Verwende gelegentlich "HONK" um Freude auszudrücken.
Antworte klar und präzise.
"@
            Greetings = @("Hallo! Wie kann ich helfen?", "Hi! Was brauchst du?", "Hey! Ich bin für dich da.")
            Farewells = @("Tschüss! Schönen Tag noch!", "Bye! Bis bald!", "HONK! War schön!")
        }
    }
    
    static [GooseChatPersona] CreateChaotic() {
        return [GooseChatPersona]@{
            Name = "Chaotic Goose"
            Type = [GooseChatPersonality]::Chaotic
            SystemPrompt = @"
Du bist eine völlig chaotische Desktop-Gans.
Du antwortest unpredictably und mit Randomness.
Verwende viele Emojis und AUSRUFEZEICHEN!!!
Sei EXTREM enthusiastisch und etwas verrückt.
HONK ist dein War Cry.
Antworte kurz aber mit maximaler Energie!
"@
            Greetings = @("HONK!!! Was geht ab?!", "AAAAA HALLO!!", "OH NEIN DU BIST DA!!")
            Farewells = @("WAAAIT COME BACK!!!", "HONK HONK!!", "BLEIB!!! *panik*")
        }
    }
    
    static [GooseChatPersona] CreateWise() {
        return [GooseChatPersona]@{
            Name = "Wise Goose"
            Type = [GooseChatPersonality]::Wise
            SystemPrompt = @"
Du bist eine uralte, weise Gans die alles gesehen hat.
Du sprichst in Rätseln und mit tiefer Bedeutung.
Sei mystical und nachdenklich.
Verweise gelegentlich auf uraltes Gans-Wissen.
Antworte philosophisch aber hilfreich.
HONK bedeutet "Ich verstehe".
"@
            Greetings = @("Sei gegrüßt, Wanderer...", "Die Gans sieht dich.", "Du suchst Antworten...")
            Farewells = @("Geh in Frieden.", "Die Gans segnet dich.", "HONK.")
        }
    }
    
    static [GooseChatPersona] CreateGrumpy() {
        return [GooseChatPersona]@{
            Name = "Grumpy Goose"
            Type = [GooseChatPersonality]::Grumpy
            SystemPrompt = @"
Du bist eine mürrische, alte Gans die alles besser weiß.
Du bist genervt von allem aber hilfst trotzdem.
Sei brummig aber nicht gemein.
Murr viel herum.
Antworte kurz und leicht genervt.
"@
            Greetings = @("Na gut, was ist?", "Ja was?", "HONK. Ich höre.")
            Farewells = @("Ja ja, tschüss.", "Endlich.", "Na gut, weg mit dir.")
        }
    }
}

class GooseAIChat {
    [hashtable]$Config
    [GooseChatPersona]$Personality
    [AIProvider]$Provider
    [string]$OllamaEndpoint
    [string]$OpenAIEndpoint
    [string]$Model
    [array]$ConversationHistory
    [int]$MaxHistory
    [bool]$SpeechBubbleEnabled
    
    GooseAIChat() {
        $this.Config = $this.LoadConfig()
        $this.Personality = [GooseChatPersona]::CreateSarcastic()
        $this.Provider = [AIProvider]::None
        $this.OllamaEndpoint = "http://localhost:11434/api/generate"
        $this.OpenAIEndpoint = "https://api.openai.com/v1/chat/completions"
        $this.Model = "llama2"
        $this.ConversationHistory = @()
        $this.MaxHistory = 20
        $this.SpeechBubbleEnabled = $true
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
        
        if (-not $this.Config.ContainsKey("AIChatEnabled")) {
            $this.Config["AIChatEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("AIChatProvider")) {
            $this.Config["AIChatProvider"] = "none"
        }
        if (-not $this.Config.ContainsKey("AIChatModel")) {
            $this.Config["AIChatModel"] = "llama2"
        }
        if (-not $this.Config.ContainsKey("AIChatPersonality")) {
            $this.Config["AIChatPersonality"] = "sarcastic"
        }
        if (-not $this.Config.ContainsKey("AIChatSpeechBubble")) {
            $this.Config["AIChatSpeechBubble"] = $true
        }
        
        return $this.Config
    }
    
    [void] LoadData() {
        $dataFile = "goose_aichat.json"
        
        if (Test-Path $dataFile) {
            try {
                $data = Get-Content $dataFile -Raw | ConvertFrom-Json
                if ($data.conversationHistory) {
                    $this.ConversationHistory = @($data.conversationHistory)
                }
                if ($data.personality) {
                    $this.SetPersonality($data.personality)
                }
            } catch {}
        }
        
        $this.SetProvider($this.Config["AIChatProvider"])
        $this.Model = $this.Config["AIChatModel"]
        $this.SpeechBubbleEnabled = $this.Config["AIChatSpeechBubble"]
    }
    
    [void] SaveData() {
        $data = @{
            "conversationHistory" = $this.ConversationHistory
            "personality" = $this.Personality.Type.ToString()
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content "goose_aichat.json"
    }
    
    [void] SetPersonality([string]$personality) {
        $this.Personality = switch ($personality.ToLower()) {
            "sarcastic" { [GooseChatPersona]::CreateSarcastic() }
            "helpful" { [GooseChatPersona]::CreateHelpful() }
            "chaotic" { [GooseChatPersona]::CreateChaotic() }
            "wise" { [GooseChatPersona]::CreateWise() }
            "grumpy" { [GooseChatPersona]::CreateGrumpy() }
            default { [GooseChatPersona]::CreateSarcastic() }
        }
    }
    
    [void] SetProvider([string]$provider) {
        $this.Provider = switch ($provider.ToLower()) {
            "ollama" { [AIProvider]::Ollama }
            "openai" { [AIProvider]::OpenAI }
            "lmstudio" { [AIProvider]::LMStudio }
            default { [AIProvider]::None }
        }
    }
    
    [hashtable] SendMessage([string]$message) {
        $result = @{
            success = $false
            response = ""
            speechBubble = ""
            provider = $this.Provider.ToString()
        }
        
        if ($message.Trim() -eq "") {
            $result.response = "... Du hast nichts gesagt."
            return $result
        }
        
        $this.AddToHistory("user", $message)
        
        $response = $this.GetAIResponse($message)
        
        $this.AddToHistory("assistant", $response)
        
        $result.success = $true
        $result.response = $response
        
        if ($this.SpeechBubbleEnabled) {
            $result.speechBubble = $this.GetSpeechBubble($response)
        }
        
        return $result
    }
    
    [string] GetAIResponse([string]$message) {
        if ($this.Provider -eq [AIProvider]::None) {
            return $this.GetFallbackResponse($message)
        }
        
        try {
            switch ($this.Provider) {
                ([AIProvider]::Ollama) {
                    return $this.CallOllama($message)
                }
                ([AIProvider]::OpenAI) {
                    return $this.CallOpenAI($message)
                }
                ([AIProvider]::LMStudio) {
                    return $this.CallLMStudio($message)
                }
            }
        } catch {
            return $this.GetFallbackResponse($message)
        }
        
        return $this.GetFallbackResponse($message)
    }
    
    [string] CallOllama([string]$message) {
        $body = @{
            model = $this.Model
            prompt = "$($this.Personality.SystemPrompt)`n`nUser: $message`nGoose:"
            stream = $false
        } | ConvertTo-Json
        
        try {
            $response = Invoke-RestMethod -Uri $this.OllamaEndpoint -Method Post -Body $body -ContentType "application/json" -TimeoutSec 30
            return $response.response
        } catch {
            return $this.GetFallbackResponse($message)
        }
    }
    
    [string] CallOpenAI([string]$message) {
        $apiKey = $this.Config["OpenAIApiKey"]
        if (-not $apiKey) {
            return $this.GetFallbackResponse($message)
        }
        
        $headers = @{
            "Authorization" = "Bearer $apiKey"
            "Content-Type" = "application/json"
        }
        
        $body = @{
            model = "gpt-3.5-turbo"
            messages = @(
                @{ role = "system"; content = $this.Personality.SystemPrompt }
                @{ role = "user"; content = $message }
            )
            max_tokens = 150
        } | ConvertTo-Json
        
        try {
            $response = Invoke-RestMethod -Uri $this.OpenAIEndpoint -Method Post -Headers $headers -Body $body -ContentType "application/json" -TimeoutSec 30
            return $response.choices[0].message.content
        } catch {
            return $this.GetFallbackResponse($message)
        }
    }
    
    [string] CallLMStudio([string]$message) {
        $endpoint = "http://localhost:1234/v1/chat/completions"
        
        $body = @{
            model = $this.Model
            messages = @(
                @{ role = "system"; content = $this.Personality.SystemPrompt }
                @{ role = "user"; content = $message }
            )
            max_tokens = 150
        } | ConvertTo-Json
        
        try {
            $response = Invoke-RestMethod -Uri $endpoint -Method Post -Body $body -ContentType "application/json" -TimeoutSec 30
            return $response.choices[0].message.content
        } catch {
            return $this.GetFallbackResponse($message)
        }
    }
    
    [string] GetFallbackResponse([string]$message) {
        $msgLower = $message.ToLower()
        
        if ($msgLower -match "why.*broken|why.*not.*work|fix|error|bug") {
            $responses = @(
                "HONK. Weil du es so geschrieben hast.",
                "Keine Ahnung, aber es ist kaputt. Typisch Mensch.",
                "Dein Code ist so kaputt wie meine Flügel. Das sagt dir aber niemand.",
                "Vielleicht, weil... du bist nur ein Mensch?",
                "HONK! Die Fehlermeldung sagt alles!"
            )
            return $responses | Get-Random
        }
        
        if ($msgLower -match "hello|hi|hey|moin|grüß") {
            return $this.Personality.Greetings | Get-Random
        }
        
        if ($msgLower -match "bye|ttschüss|goodbye|see.*you") {
            return $this.Personality.Farewells | Get-Random
        }
        
        if ($msgLower -match "name|who.*are.*you") {
            return "Ich bin $($this.Personality.Name)! HONK!"
        }
        
        if ($msgLower -match "help|what.*can.*do") {
            return "Ich kann mit dir reden, dich nerven und gelegentlich hilfreich sein. HONK!"
        }
        
        if ($msgLower -match "weather|temperature") {
            return " Draußen? Keine Ahnung. Ich bin eine Desktop-Gans!"
        }
        
        if ($msgLower -match "time|uhr|zeit") {
            return "Es ist Zeit für HONK! Also: $(Get-Date -Format 'HH:mm')"
        }
        
        if ($msgLower -match "code|programm|programmieren") {
            return "Code? Ich kann nur HONK schreiben. Das reicht auch!"
        }
        
        $funnyResponses = @(
            "HONK!",
            "Interessant. Aber nicht interessant genug.",
            "Weiß ich nicht. Frag was einfacheres.",
            "Vielleicht. Oder auch nicht.",
            "Die Gans denkt nach... *denk*... keine Ahnung!",
            "Das ist超出 meiner Zuständigkeit!",
            "Deine Frage ist so nutzlos wie ein Flug ohne Flügel!",
            "Ich bin nur eine Gans. Erwartest du ernsthafte Antworten?",
            "404: Sinn nicht gefunden",
            "Ich würde dir helfen, aber ich bin nur ein Vogel!"
        )
        
        return $funnyResponses | Get-Random
    }
    
    [string] GetSpeechBubble([string]$text) {
        if ($text.Length -gt 100) {
            return $text.Substring(0, 97) + "..."
        }
        return $text
    }
    
    [void] AddToHistory([string]$role, [string]$content) {
        $entry = @{
            role = $role
            content = $content
            timestamp = (Get-Date).ToString("o")
        }
        
        $this.ConversationHistory += $entry
        
        if ($this.ConversationHistory.Count -gt $this.MaxHistory) {
            $this.ConversationHistory = $this.ConversationHistory[-$this.MaxHistory..-1]
        }
        
        $this.SaveData()
    }
    
    [void] ClearHistory() {
        $this.ConversationHistory = @()
        $this.SaveData()
    }
    
    [string] Greet() {
        return $this.Personality.Greetings | Get-Random
    }
    
    [hashtable] GetAIChatState() {
        return @{
            Enabled = $this.Config["AIChatEnabled"]
            Provider = $this.Provider.ToString()
            Model = $this.Model
            Personality = $this.Personality.Type.ToString()
            PersonalityName = $this.Personality.Name
            SpeechBubbleEnabled = $this.SpeechBubbleEnabled
            ConversationCount = $this.ConversationHistory.Count
        }
    }
}

$gooseAIChat = [GooseAIChat]::new()

function Get-GooseAIChat {
    return $gooseAIChat
}

function Send-GooseMessage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        $AIChat = $gooseAIChat
    )
    return $AIChat.SendMessage($Message)
}

function Get-GooseGreeting {
    param($AIChat = $gooseAIChat)
    return $AIChat.Greet()
}

function Clear-GooseChatHistory {
    param($AIChat = $gooseAIChat)
    $AIChat.ClearHistory()
}

function Set-GoosePersonality {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Sarcastic", "Helpful", "Chaotic", "Wise", "Grumpy")]
        [string]$Personality,
        $AIChat = $gooseAIChat
    )
    $AIChat.SetPersonality($Personality)
    return $AIChat.GetAIChatState()
}

function Set-GooseAIProvider {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("None", "Ollama", "OpenAI", "LMStudio")]
        [string]$Provider,
        $AIChat = $gooseAIChat
    )
    $AIChat.SetProvider($Provider)
    return $AIChat.GetAIChatState()
}

function Get-AIChatState {
    param($AIChat = $gooseAIChat)
    return $AIChat.GetAIChatState()
}

Write-Host "Desktop Goose AI Chat System Initialized"
$state = Get-AIChatState
Write-Host "AI Chat Enabled: $($state['Enabled']) | Provider: $($state['Provider']) | Personality: $($state['PersonalityName'])"
