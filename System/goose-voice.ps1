class GooseVoiceCommands {
    [hashtable]$Config
    [string]$DataPath
    [object]$Telemetry
    [bool]$IsListening
    [hashtable]$Commands
    [object]$Recognizer
    [object]$Synthesizer
    [System.Windows.Forms.Timer]$WakeWordTimer
    
    GooseVoiceCommands([string]$configFile = "config.ini", [object]$telemetry = $null) {
        $this.Telemetry = $telemetry
        $this.LoadConfig($configFile)
        $this.DataPath = Join-Path $PSScriptRoot "voice_data"
        if (-not (Test-Path $this.DataPath)) {
            New-Item -ItemType Directory -Path $this.DataPath -Force | Out-Null
        }
        $this.IsListening = $false
        $this.Commands = $this.InitializeCommands()
        $this.Recognizer = $null
        $this.Synthesizer = $null
    }
    
    [void] LoadConfig([string]$configFile) {
        $this.Config = @{
            Enabled = $false
            WakeWord = "Hey Goose"
            Language = "en-US"
            ConfidenceThreshold = 0.7
            VoiceEnabled = $true
            VoiceRate = 0
            VoiceVolume = 100
            AutoStartListening = $false
            CommandTimeout = 5000
        }
        if (Test-Path $configFile) {
            Get-Content $configFile | ForEach-Object {
                if ($_ -match '^([^=]+)=(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    if ($this.Config.ContainsKey($key)) {
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
        }
    }
    
    [hashtable] InitializeCommands() {
        return @{
            "honk" = @{
                aliases = @("honk", "make a sound", "say something")
                action = { $this.Speak("HONK!") }
                response = "HONK!"
            }
            "dance" = @{
                aliases = @("dance", "do a dance", "show me a dance")
                action = { $this.TriggerAnimation("dance") }
                response = "Let's dance!"
            }
            "screenshot" = @{
                aliases = @("screenshot", "take a picture", "capture screen")
                action = { $this.TakeScreenshot() }
                response = "Cheese!"
            }
            "tell me a joke" = @{
                aliases = @("tell me a joke", "joke", "make me laugh")
                action = { $this.TellJoke() }
                response = ""
            }
            "weather" = @{
                aliases = @("weather", "what's the weather", "how's the weather")
                action = { $this.GetWeather() }
                response = ""
            }
            "time" = @{
                aliases = @("time", "what time is it", "what's the time")
                action = { $this.GetTime() }
                response = ""
            }
            "focus" = @{
                aliases = @("start focus", "focus mode", "help me focus")
                action = { $this.StartFocus() }
                response = "Focus mode activated!"
            }
            "sit" = @{
                aliases = @("sit", "sit down", "take a seat")
                action = { $this.TriggerAnimation("sit") }
                response = "*sits down*"
            }
            "stand" = @{
                aliases = @("stand", "stand up", "get up")
                action = { $this.TriggerAnimation("stand") }
                response = "*stands up*"
            }
            "spin" = @{
                aliases = @("spin", "turn around", "do a spin")
                action = { $this.TriggerAnimation("spin") }
                response = "*spins around*"
            }
            "help" = @{
                aliases = @("help", "what can you do", "commands")
                action = { $this.ShowHelp() }
                response = ""
            }
        }
    }
    
    [void] InitializeSpeechRecognition() {
        try {
            Add-Type -AssemblyName System.Speech
            $this.Recognizer = New-Object System.Speech.Recognition.SpeechRecognitionEngine
            $this.Recognizer.SetInputToDefaultAudioDevice()
            $grammarBuilder = New-Object System.Speech.Recognition.GrammarBuilder
            $grammarBuilder.Culture = [System.Globalization.CultureInfo]::GetCultureInfo($this.Config["Language"])
            $choices = New-Object System.Speech.Recognition.Choices
            $allPhrases = @($this.Config["WakeWord"])
            foreach ($cmd in $this.Commands.Values) {
                $allPhrases += $cmd.aliases
            }
            $choices.Add($allPhrases)
            $grammarBuilder.Append($choices)
            $grammar = New-Object System.Speech.Recognition.Grammar($grammarBuilder)
            $this.Recognizer.LoadGrammar($grammar)
            $this.Recognizer.Add_RecognizedUpdate({
                param($sender, $e)
                $this.Telemetry?.IncrementCounter("voice.recognized_updates", 1)
            })
        } catch {
            $this.Telemetry?.IncrementCounter("voice.initialization_errors", 1)
            Write-Host "Speech recognition not available: $($_.Exception.Message)"
        }
    }
    
    [void] InitializeSpeechSynthesis() {
        try {
            Add-Type -AssemblyName System.Speech
            $this.Synthesizer = New-Object System.Speech.Synthesis.SpeechSynthesizer
            $this.Synthesizer.Rate = $this.Config["VoiceRate"]
            $this.Synthesizer.Volume = $this.Config["VoiceVolume"]
        } catch {
            Write-Host "Speech synthesis not available: $($_.Exception.Message)"
        }
    }
    
    [void] StartListening() {
        if (-not $this.Recognizer) {
            $this.InitializeSpeechRecognition()
        }
        if (-not $this.Synthesizer) {
            $this.InitializeSpeechSynthesis()
        }
        if ($this.Recognizer) {
            $this.IsListening = $true
            $this.Telemetry?.IncrementCounter("voice.listening_started", 1)
            $this.Recognizer.Add_RecognizeCompleted({
                if ($this.IsListening) {
                    try { $this.Recognizer.RecognizeAsync() } catch { }
                }
            })
            $this.Recognizer.Add_SpeechRecognized({
                param($sender, $e)
                $text = $e.Result.Text
                $confidence = $e.Result.Confidence
                $this.Telemetry?.IncrementCounter("voice.speech_detected", 1, @{text=$text; confidence=[math]::Round($confidence, 2)})
                if ($confidence -ge $this.Config["ConfidenceThreshold"]) {
                    $this.ProcessCommand($text)
                }
            })
            try {
                $this.Recognizer.RecognizeAsync()
            } catch {
                $this.Telemetry?.IncrementCounter("voice.recognition_errors", 1)
            }
        } else {
            [System.Windows.Forms.MessageBox]::Show("Speech recognition is not available on this system.", "Voice Commands", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        }
    }
    
    [void] StopListening() {
        $this.IsListening = $false
        if ($this.Recognizer) {
            try {
                $this.Recognizer.RecognizeAsyncCancel()
            } catch { }
        }
        $this.Telemetry?.IncrementCounter("voice.listening_stopped", 1)
    }
    
    [void] ProcessCommand([string]$inputText) {
        $inputLower = $inputText.ToLower()
        if ($inputLower.Contains($this.Config["WakeWord"].ToLower())) {
            $this.Telemetry?.IncrementCounter("voice.wake_word_activations", 1)
            $this.Speak("Yes?")
            return
        }
        foreach ($cmdName in $this.Commands.Keys) {
            $cmd = $this.Commands[$cmdName]
            foreach ($alias in $cmd.aliases) {
                if ($inputLower.Contains($alias.ToLower())) {
                    $this.Telemetry?.IncrementCounter("voice.commands_recognized", 1, @{command=$cmdName})
                    if ($cmd.response) {
                        $this.Speak($cmd.response)
                    }
                    & $cmd.action
                    return
                }
            }
        }
        $this.Telemetry?.IncrementCounter("voice.commands_failed", 1, @{input=$inputText})
        $this.Speak("I didn't understand that. Say 'help' for commands.")
    }
    
    [void] Speak([string]$text) {
        if (-not $this.Config["VoiceEnabled"]) { return }
        if ($this.Synthesizer) {
            try {
                $this.Synthesizer.SpeakAsync($text) | Out-Null
                $this.Telemetry?.IncrementCounter("voice.speeches", 1)
            } catch { }
        }
    }
    
    [void] TriggerAnimation([string]$animation) {
        $this.Telemetry?.IncrementCounter("voice.animations_triggered", 1, @{animation=$animation})
        [System.Windows.Forms.MessageBox]::Show("🦆 *performs $animation animation*", "Goose Animation", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
    
    [void] TakeScreenshot() {
        $this.Telemetry?.IncrementCounter("voice.screenshot_commands", 1)
        try {
            Add-Type -AssemblyName System.Windows.Forms
            $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
            $screenshot = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
            $graphics = [System.Drawing.Graphics]::FromImage($screenshot)
            $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
            $graphics.Dispose()
            $saveFolder = Join-Path (Split-Path $PSScriptRoot -Parent) "Screenshots"
            if (-not (Test-Path $saveFolder)) {
                New-Item -ItemType Directory -Path $saveFolder -Force | Out-Null
            }
            $filename = Join-Path $saveFolder "VoiceScreenshot_$(Get-Date -Format 'yyyyMMdd_HHmmss').png"
            $screenshot.Save($filename, [System.Drawing.Imaging.ImageFormat]::Png)
            $screenshot.Dispose()
            $this.Speak("Screenshot saved!")
        } catch {
            $this.Speak("Failed to take screenshot.")
        }
    }
    
    [void] TellJoke() {
        $jokes = @(
            "Why don't scientists trust atoms? Because they make up everything!",
            "What do you call a goose that tells jokes? A honk- comedian!",
            "Why did the goose cross the road? To prove he wasn't chicken!",
            "How does a goose introduce itself? 'Hi, I'm Bill!'",
            "What do you call a sleeping dinosaur? A dino-snore!"
        )
        $joke = $jokes | Get-Random
        $this.Telemetry?.IncrementCounter("voice.jokes_told", 1)
        $this.Speak($joke)
    }
    
    [void] GetWeather() {
        $this.Telemetry?.IncrementCounter("voice.weather_requests", 1)
        $this.Speak("I don't have weather access yet, but it looks nice outside!")
    }
    
    [void] GetTime() {
        $time = Get-Date -Format "h:mm tt"
        $this.Speak("It's $time")
    }
    
    [void] StartFocus() {
        $this.Telemetry?.IncrementCounter("voice.focus_commands", 1)
        $this.Speak("Starting focus mode. Let's get productive!")
    }
    
    [void] ShowHelp() {
        $commands = $this.Commands.Keys -join ", "
        $this.Speak("Available commands: $commands")
        $this.Telemetry?.IncrementCounter("voice.help_requests", 1)
    }
    
    [void] AddCustomCommand([string]$phrase, [scriptblock]$action, [string]$response) {
        $this.Commands[$phrase] = @{
            aliases = @($phrase)
            action = $action
            response = $response
        }
        $this.Telemetry?.IncrementCounter("voice.custom_commands_added", 1)
    }
    
    [hashtable] GetVoiceStats() {
        return @{
            isListening = $this.IsListening
            commandsCount = $this.Commands.Count
            wakeWord = $this.Config["WakeWord"]
            voiceEnabled = $this.Config["VoiceEnabled"]
        }
    }
}

$gooseVoiceCommands = $null

function Get-VoiceCommands {
    param([object]$Telemetry = $null)
    if ($script:gooseVoiceCommands -eq $null) {
        $script:gooseVoiceCommands = [GooseVoiceCommands]::new("config.ini", $Telemetry)
    }
    return $script:gooseVoiceCommands
}

function Start-VoiceRecognition {
    $voice = Get-VoiceCommands
    $voice.StartListening()
}

function Stop-VoiceRecognition {
    $voice = Get-VoiceCommands
    $voice.StopListening()
}

function Add-VoiceCommand {
    param([string]$Phrase, [scriptblock]$Action, [string]$Response = "")
    $voice = Get-VoiceCommands
    $voice.AddCustomCommand($Phrase, $Action, $Response)
}

Write-Host "Voice Commands Module Initialized"
