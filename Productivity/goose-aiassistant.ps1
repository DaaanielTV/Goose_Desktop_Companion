# Desktop Goose AI Assistant System
# Local AI assistant for quick actions and help

class GooseAIAssistant {
    [hashtable]$Config
    [bool]$IsEnabled
    [bool]$VoiceEnabled
    [array]$ConversationHistory
    [hashtable]$QuickActions
    [int]$MaxHistory
    [string]$ResponseStyle
    
    GooseAIAssistant() {
        $this.Config = $this.LoadConfig()
        $this.IsEnabled = $false
        $this.VoiceEnabled = $false
        $this.ConversationHistory = @()
        $this.QuickActions = @{}
        $this.MaxHistory = 50
        $this.ResponseStyle = "helpful"
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
        
        if (-not $this.Config.ContainsKey("AIAssistantEnabled")) {
            $this.Config["AIAssistantEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("AIVoiceEnabled")) {
            $this.Config["AIVoiceEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("AIResponseStyle")) {
            $this.Config["AIResponseStyle"] = "helpful"
        }
        
        return $this.Config
    }
    
    [void] LoadData() {
        $dataFile = "goose_aiassistant.json"
        
        if (Test-Path $dataFile) {
            try {
                $data = Get-Content $dataFile -Raw | ConvertFrom-Json
                
                if ($data.conversationHistory) {
                    $this.ConversationHistory = @($data.conversationHistory)
                }
                
                if ($data.quickActions) {
                    $this.QuickActions = @{}
                    $data.quickActions.PSObject.Properties | ForEach-Object {
                        $this.QuickActions[$_.Name] = $_.Value
                    }
                }
                
                if ($data.responseStyle) {
                    $this.ResponseStyle = $data.responseStyle
                }
            } catch {}
        }
        
        $this.IsEnabled = $this.Config["AIAssistantEnabled"]
        $this.VoiceEnabled = $this.Config["AIVoiceEnabled"]
        $this.LoadDefaultQuickActions()
    }
    
    [void] LoadDefaultQuickActions() {
        if ($this.QuickActions.Count -eq 0) {
            $this.QuickActions = @{
                "add_task" = @{
                    "name" = "Add Task"
                    "pattern" = "add task|new task|create task"
                    "action" = "task_add"
                    "description" = "Add a new task"
                }
                "show_tasks" = @{
                    "name" = "Show Tasks"
                    "pattern" = "show tasks|my tasks|list tasks"
                    "action" = "task_list"
                    "description" = "List pending tasks"
                }
                "set_reminder" = @{
                    "name" = "Set Reminder"
                    "pattern" = "remind me|set reminder|reminder"
                    "action" = "reminder_set"
                    "description" = "Set a reminder"
                }
                "check_weather" = @{
                    "name" = "Check Weather"
                    "pattern" = "weather|forecast|temperature"
                    "action" = "weather_check"
                    "description" = "Get weather information"
                }
                "take_break" = @{
                    "name" = "Take Break"
                    "pattern" = "take a break|break time|need rest"
                    "action" = "break_take"
                    "description" = "Start a break timer"
                }
                "focus_mode" = @{
                    "name" = "Focus Mode"
                    "pattern" = "focus|concentrate|work mode"
                    "action" = "focus_start"
                    "description" = "Start focus mode"
                }
                "open_app" = @{
                    "name" = "Open Application"
                    "pattern" = "open|launch|start"
                    "action" = "app_open"
                    "description" = "Open an application"
                }
                "get_time" = @{
                    "name" = "Get Time"
                    "pattern" = "what time|time is it|current time"
                    "action" = "time_get"
                    "description" = "Get current time"
                }
            }
        }
    }
    
    [void] SaveData() {
        $data = @{
            "conversationHistory" = $this.ConversationHistory
            "quickActions" = $this.QuickActions
            "responseStyle" = $this.ResponseStyle
            "settings" = @{
                "maxHistory" = $this.MaxHistory
                "voiceEnabled" = $this.VoiceEnabled
            }
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content "goose_aiassistant.json"
    }
    
    [hashtable] ProcessMessage([string]$message) {
        $result = @{
            "success" = $false
            "response" = ""
            "action" = $null
            "data" = $null
        }
        
        $message = $message.Trim()
        $messageLower = $message.ToLower()
        
        $this.AddToHistory("user", $message)
        
        $action = $this.DetectAction($messageLower)
        
        if ($action) {
            $result.action = $action.action
            $result.data = $action.data
            
            switch ($action.action) {
                "task_add" {
                    $result.response = "I'll help you add a task. What would you like to do?"
                }
                "task_list" {
                    $result.response = "Here are your pending tasks..."
                }
                "reminder_set" {
                    $result.response = "What would you like to be reminded about?"
                }
                "weather_check" {
                    $result.response = "Checking the weather for you..."
                }
                "break_take" {
                    $result.response = "Let's take a break! I'll start a timer for you."
                }
                "focus_start" {
                    $result.response = "Starting focus mode. Good luck with your work!"
                }
                "app_open" {
                    $result.response = "Which application would you like to open?"
                }
                "time_get" {
                    $now = Get-Date
                    $result.response = "The current time is $($now.ToString('h:mm tt'))"
                }
                "greeting" {
                    $greetings = @(
                        "Hello! I'm your desktop assistant. How can I help you today?",
                        "Hi there! What can I do for you?",
                        "Hey! I'm here to help. What would you like to do?"
                    )
                    $result.response = $greetings | Get-Random
                }
                "help" {
                    $result.response = $this.GetHelpText()
                }
                "status" {
                    $result.response = $this.GetStatusResponse()
                }
                "unknown" {
                    $result.response = $this.GetUnknownResponse()
                }
            }
        }
        
        $result.success = $true
        $this.AddToHistory("assistant", $result.response)
        
        return $result
    }
    
    [hashtable] DetectAction([string]$message) {
        foreach ($action in $this.QuickActions.Values) {
            if ($message -match $action.pattern) {
                return @{
                    "action" = $action.action
                    "data" = $null
                }
            }
        }
        
        if ($message -match "hi|hello|hey|greetings") {
            return @{ "action" = "greeting"; "data" = $null }
        }
        
        if ($message -match "help|what can you do|commands") {
            return @{ "action" = "help"; "data" = $null }
        }
        
        if ($message -match "how are you|status|how do you do") {
            return @{ "action" = "status"; "data" = $null }
        }
        
        return @{ "action" = "unknown"; "data" = $null }
    }
    
    [string] GetHelpText() {
        return @"
I can help you with:

📝 **Tasks**
- Add, view, and manage tasks
- Mark tasks as complete

⏰ **Reminders**
- Set reminders for yourself
- Get notified at specific times

🍅 **Focus**
- Start focus / Pomodoro sessions
- Take breaks

🌤️ **Weather**
- Check current weather
- Get forecasts

📱 **Apps**
- Open applications
- Launch programs

🕐 **Time**
- Get current time
- Set timers

Just tell me what you'd like to do!
"@
    }
    
    [string] GetStatusResponse() {
        return "I'm doing great! Always happy to help you stay productive. The goose is also here, waddling around!"
    }
    
    [string] GetUnknownResponse() {
        $responses = @(
            "I'm not sure I understood that. Try 'help' to see what I can do!",
            "Could you try rephrasing that? I'm still learning!",
            "Hmm, I didn't get that. Ask me for 'help' to see available commands."
        )
        return $responses | Get-Random
    }
    
    [void] AddToHistory([string]$role, [string]$content) {
        $entry = @{
            "role" = $role
            "content" = $content
            "timestamp" = (Get-Date).ToString("o")
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
    
    [hashtable[]] GetConversationHistory([int]$count = 20) {
        if ($count -gt 0 -and $count -lt $this.ConversationHistory.Count) {
            return @($this.ConversationHistory[-$count..-1])
        }
        return @($this.ConversationHistory)
    }
    
    [hashtable] AddQuickAction([string]$name, [string]$pattern, [string]$action, [string]$description) {
        $quickAction = @{
            "name" = $name
            "pattern" = $pattern
            "action" = $action
            "description" = $description
        }
        
        $this.QuickActions[$name] = $quickAction
        $this.SaveData()
        
        return $quickAction
    }
    
    [bool] RemoveQuickAction([string]$name) {
        if ($this.QuickActions.ContainsKey($name)) {
            $this.QuickActions.Remove($name)
            $this.SaveData()
            return $true
        }
        return $false
    }
    
    [hashtable] GetQuickActions() {
        return $this.QuickActions
    }
    
    [void] SetVoiceEnabled([bool]$enabled) {
        $this.VoiceEnabled = $enabled
        $this.Config["AIVoiceEnabled"] = $enabled
    }
    
    [void] SetResponseStyle([string]$style) {
        $validStyles = @("helpful", "concise", "friendly", "professional")
        if ($validStyles -contains $style) {
            $this.ResponseStyle = $style
            $this.Config["AIResponseStyle"] = $style
            $this.SaveData()
        }
    }
    
    [void] SetEnabled([bool]$enabled) {
        $this.IsEnabled = $enabled
        $this.Config["AIAssistantEnabled"] = $enabled
    }
    
    [void] Toggle() {
        $this.IsEnabled = -not $this.IsEnabled
        $this.Config["AIAssistantEnabled"] = $this.IsEnabled
    }
    
    [hashtable] GetAIAssistantState() {
        return @{
            "Enabled" = $this.IsEnabled
            "VoiceEnabled" = $this.VoiceEnabled
            "ResponseStyle" = $this.ResponseStyle
            "ConversationCount" = $this.ConversationHistory.Count
            "QuickActionsCount" = $this.QuickActions.Count
            "QuickActions" = $this.QuickActions
            "RecentConversation" = $this.GetConversationHistory(5)
        }
    }
}

$gooseAIAssistant = [GooseAIAssistant]::new()

function Get-GooseAIAssistant {
    return $gooseAIAssistant
}

function Send-AIMessage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        $Assistant = $gooseAIAssistant
    )
    return $Assistant.ProcessMessage($Message)
}

function Get-AIConversationHistory {
    param(
        [int]$Count = 20,
        $Assistant = $gooseAIAssistant
    )
    return $Assistant.GetConversationHistory($Count)
}

function Clear-AIHistory {
    param($Assistant = $gooseAIAssistant)
    $Assistant.ClearHistory()
}

function Add-AIQuickAction {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$Pattern,
        [Parameter(Mandatory=$true)]
        [string]$Action,
        [string]$Description = "",
        $Assistant = $gooseAIAssistant
    )
    return $Assistant.AddQuickAction($Name, $Pattern, $Action, $Description)
}

function Remove-AIQuickAction {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        $Assistant = $gooseAIAssistant
    )
    return $Assistant.RemoveQuickAction($Name)
}

function Get-AIQuickActions {
    param($Assistant = $gooseAIAssistant)
    return $Assistant.GetQuickActions()
}

function Enable-AIVoice {
    param($Assistant = $gooseAIAssistant)
    $Assistant.SetVoiceEnabled($true)
}

function Disable-AIVoice {
    param($Assistant = $gooseAIAssistant)
    $Assistant.SetVoiceEnabled($false)
}

function Set-AIResponseStyle {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Style,
        $Assistant = $gooseAIAssistant
    )
    $Assistant.SetResponseStyle($Style)
}

function Enable-AIAssistant {
    param($Assistant = $gooseAIAssistant)
    $Assistant.SetEnabled($true)
}

function Disable-AIAssistant {
    param($Assistant = $gooseAIAssistant)
    $Assistant.SetEnabled($false)
}

function Toggle-AIAssistant {
    param($Assistant = $gooseAIAssistant)
    $Assistant.Toggle()
}

function Get-AIAssistantState {
    param($Assistant = $gooseAIAssistant)
    return $Assistant.GetAIAssistantState()
}

Write-Host "Desktop Goose AI Assistant System Initialized"
$state = Get-AIAssistantState
Write-Host "AI Assistant Enabled: $($state['Enabled'])"
Write-Host "Quick Actions: $($state['QuickActionsCount'])"
