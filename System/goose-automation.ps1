# Desktop Goose Automation Hub System
# Create automations with triggers and actions

class GooseAutomation {
    [hashtable]$Config
    [bool]$IsEnabled
    [hashtable]$Automations
    [int]$AutomationIdCounter
    [hashtable]$ExecutionLog
    
    GooseAutomation() {
        $this.Config = $this.LoadConfig()
        $this.IsEnabled = $false
        $this.Automations = @{}
        $this.AutomationIdCounter = 1
        $this.ExecutionLog = @{}
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
        
        if (-not $this.Config.ContainsKey("AutomationEnabled")) {
            $this.Config["AutomationEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] LoadData() {
        $dataFile = "goose_automation.json"
        
        if (Test-Path $dataFile) {
            try {
                $data = Get-Content $dataFile -Raw | ConvertFrom-Json
                
                if ($data.automations) {
                    $this.Automations = @{}
                    $data.automations.PSObject.Properties | ForEach-Object {
                        $this.Automations[$_.Name] = $_.Value
                    }
                }
                
                if ($data.automationIdCounter) {
                    $this.AutomationIdCounter = $data.automationIdCounter
                }
                
                if ($data.executionLog) {
                    $this.ExecutionLog = @{}
                    $data.executionLog.PSObject.Properties | ForEach-Object {
                        $this.ExecutionLog[$_.Name] = $_.Value
                    }
                }
            } catch {}
        }
        
        $this.IsEnabled = $this.Config["AutomationEnabled"]
    }
    
    [void] SaveData() {
        $data = @{
            "automations" = $this.Automations
            "automationIdCounter" = $this.AutomationIdCounter
            "executionLog" = $this.ExecutionLog
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content "goose_automation.json"
    }
    
    [string] CreateAutomation([string]$name, [hashtable]$trigger, [hashtable[]]$actions, [bool]$enabled = $true) {
        $id = "auto_" + $this.AutomationIdCounter++
        
        $automation = @{
            "id" = $id
            "name" = $name
            "trigger" = $trigger
            "actions" = $actions
            "enabled" = $enabled
            "lastTriggered" = $null
            "triggerCount" = 0
            "createdAt" = (Get-Date).ToString("o")
        }
        
        $this.Automations[$id] = $automation
        $this.SaveData()
        
        return $id
    }
    
    [bool] UpdateAutomation([string]$id, [string]$name = $null, [hashtable]$trigger = $null, [hashtable[]]$actions = $null, [bool]$enabled = $null) {
        if (-not $this.Automations.ContainsKey($id)) {
            return $false
        }
        
        $automation = $this.Automations[$id]
        
        if ($name) { $automation.name = $name }
        if ($trigger) { $automation.trigger = $trigger }
        if ($actions) { $automation.actions = $actions }
        if ($null -ne $enabled) { $automation.enabled = $enabled }
        
        $this.Automations[$id] = $automation
        $this.SaveData()
        
        return $true
    }
    
    [bool] DeleteAutomation([string]$id) {
        if ($this.Automations.ContainsKey($id)) {
            $this.Automations.Remove($id)
            $this.SaveData()
            return $true
        }
        return $false
    }
    
    [bool] ToggleAutomation([string]$id) {
        if (-not $this.Automations.ContainsKey($id)) {
            return $false
        }
        
        $this.Automations[$id].enabled = -not $this.Automations[$id].enabled
        $this.SaveData()
        
        return $this.Automations[$id].enabled
    }
    
    [hashtable] GetAutomation([string]$id) {
        if ($this.Automations.ContainsKey($id)) {
            return $this.Automations[$id]
        }
        return $null
    }
    
    [hashtable[]] GetAllAutomations() {
        return @($this.Automations.Values)
    }
    
    [hashtable[]] GetEnabledAutomations() {
        $enabled = @()
        
        foreach ($auto in $this.Automations.Values) {
            if ($auto.enabled) {
                $enabled += $auto
            }
        }
        
        return $enabled
    }
    
    [bool] CheckTrigger([hashtable]$automation) {
        $trigger = $automation.trigger
        
        switch ($trigger.type) {
            "time" {
                $now = Get-Date
                $triggerTime = $trigger.time
                $days = $trigger.days
                
                if ($now.ToString("HH:mm") -eq $triggerTime) {
                    if ($days -contains $now.DayOfWeek.ToString()) {
                        return $true
                    }
                }
            }
            "app_launch" {
                $runningApps = Get-Process | Select-Object -ExpandProperty ProcessName
                if ($runningApps -contains $trigger.appName) {
                    return $true
                }
            }
            "clipboard" {
                try {
                    $clipboard = Get-Clipboard
                    if ($clipboard -match $trigger.pattern) {
                        return $true
                    }
                } catch {}
            }
            "hotkey" {
            }
            "file_created" {
                if (Test-Path $trigger.folderPath) {
                    $recentFiles = Get-ChildItem -Path $trigger.folderPath -File | Where-Object { $_.LastWriteTime -gt (Get-Date).AddMinutes(-5) }
                    if ($recentFiles) {
                        return $true
                    }
                }
            }
        }
        
        return $false
    }
    
    [hashtable] ExecuteActions([hashtable[]]$actions, [hashtable]$context = @{}) {
        $results = @{
            "success" = $true
            "executed" = 0
            "failed" = 0
            "details" = @()
        }
        
        foreach ($action in $actions) {
            $actionResult = @{
                "action" = $action.type
                "success" = $false
                "message" = ""
            }
            
            try {
                switch ($action.type) {
                    "notification" {
                        $title = if ($action.title) { $action.title } else { "Desktop Goose" }
                        $message = if ($action.message) { $action.message } else { "Automation triggered!" }
                        
                        Write-Host "[$title] $message"
                        
                        $actionResult.success = $true
                        $actionResult.message = "Notification shown"
                    }
                    "run_script" {
                        if ($action.script) {
                            $actionResult.message = "Script execution disabled for security"
                            $actionResult.success = $false
                        }
                    }
                    "open_app" {
                        if ($action.path) {
                            Start-Process $action.path
                            $actionResult.success = $true
                            $actionResult.message = "Application started"
                        }
                    }
                    "copy_clipboard" {
                        if ($action.content) {
                            Set-Clipboard -Value $action.content
                            $actionResult.success = $true
                            $actionResult.message = "Clipboard set"
                        }
                    }
                    "play_sound" {
                        if ($action.soundFile -and (Test-Path $action.soundFile)) {
                            $sound = New-Object System.Media.SoundPlayer $action.soundFile
                            $sound.Play()
                            $actionResult.success = $true
                            $actionResult.message = "Sound played"
                        }
                    }
                    "log_message" {
                        $this.LogMessage($action.message, $action.level)
                        $actionResult.success = $true
                        $actionResult.message = "Message logged"
                    }
                }
            } catch {
                $actionResult.success = $false
                $actionResult.message = $_.Exception.Message
                $results.success = $false
            }
            
            if ($actionResult.success) {
                $results.executed++
            } else {
                $results.failed++
            }
            
            $results.details += $actionResult
        }
        
        return $results
    }
    
    [void] TriggerAutomation([string]$id, [hashtable]$context = @{}) {
        if (-not $this.Automations.ContainsKey($id)) {
            return
        }
        
        $automation = $this.Automations[$id]
        
        if (-not $automation.enabled) {
            return
        }
        
        $results = $this.ExecuteActions($automation.actions, $context)
        
        $automation.lastTriggered = (Get-Date).ToString("o")
        $automation.triggerCount++
        
        $this.RecordExecution($id, $results)
        $this.SaveData()
    }
    
    [void] CheckAndTrigger() {
        foreach ($automation in $this.GetEnabledAutomations()) {
            if ($this.CheckTrigger($automation)) {
                $this.TriggerAutomation($automation.id)
            }
        }
    }
    
    [void] RecordExecution([string]$automationId, [hashtable]$results) {
        $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        
        $this.ExecutionLog[$timestamp] = @{
            "timestamp" = (Get-Date).ToString("o")
            "automationId" = $automationId
            "automationName" = $this.Automations[$automationId].name
            "success" = $results.success
            "executed" = $results.executed
            "failed" = $results.failed
        }
        
        if ($this.ExecutionLog.Count -gt 100) {
            $keys = $this.ExecutionLog.Keys | Sort-Object
            $keysToRemove = $keys[0..($keys.Count - 101)]
            foreach ($key in $keysToRemove) {
                $this.ExecutionLog.Remove($key)
            }
        }
    }
    
    [void] LogMessage([string]$message, [string]$level = "info") {
        $timestamp = Get-Date.ToString("yyyy-MM-dd HH:mm:ss")
        $logEntry = "[$timestamp] [$level] $message"
        
        $logFile = "goose_automation.log"
        Add-Content -Path $logFile -Value $logEntry
    }
    
    [hashtable[]] GetExecutionLog([int]$count = 20) {
        $log = @()
        $keys = $this.ExecutionLog.Keys | Sort-Object -Descending
        
        foreach ($key in $keys | Select-Object -First $count) {
            $log += $this.ExecutionLog[$key]
        }
        
        return $log
    }
    
    [hashtable] GetStats() {
        $total = $this.Automations.Count
        $enabled = ($this.Automations.Values | Where-Object { $_.enabled }).Count
        $totalTriggers = ($this.Automations.Values | Measure-Object -Property triggerCount -Sum).Sum
        
        return @{
            "totalAutomations" = $total
            "enabledAutomations" = $enabled
            "disabledAutomations" = $total - $enabled
            "totalTriggers" = $totalTriggers
            "executionLogCount" = $this.ExecutionLog.Count
        }
    }
    
    [hashtable] CreateTemplate([string]$templateName) {
        $templates = @{
            "morning_startup" = @{
                "name" = "Morning Startup"
                "trigger" = @{
                    "type" = "time"
                    "time" = "09:00"
                    "days" = @("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")
                }
                "actions" = @(
                    @{ "type" = "notification"; "title" = "Good Morning!"; "message" = "Time to start your day!" }
                )
            }
            "clipboard_save" = @{
                "name" = "Save Clipboard"
                "trigger" = @{
                    "type" = "clipboard"
                    "pattern" = ".*"
                }
                "actions" = @(
                    @{ "type" = "log_message"; "message" = "Clipboard captured"; "level" = "info" }
                )
            }
            "downloads_organize" = @{
                "name" = "Organize Downloads"
                "trigger" = @{
                    "type" = "file_created"
                    "folderPath" = "$env:USERPROFILE\Downloads"
                }
                "actions" = @(
                    @{ "type" = "notification"; "title" = "New File"; "message" = "File downloaded!" }
                )
            }
        }
        
        if ($templates.ContainsKey($templateName)) {
            $template = $templates[$templateName]
            return $this.CreateAutomation($template.name, $template.trigger, $template.actions)
        }
        
        return $null
    }
    
    [void] SetEnabled([bool]$enabled) {
        $this.IsEnabled = $enabled
        $this.Config["AutomationEnabled"] = $enabled
    }
    
    [void] Toggle() {
        $this.IsEnabled = -not $this.IsEnabled
        $this.Config["AutomationEnabled"] = $this.IsEnabled
    }
    
    [hashtable] GetAutomationState() {
        return @{
            "Enabled" = $this.IsEnabled
            "Automations" = $this.GetAllAutomations()
            "EnabledAutomations" = $this.GetEnabledAutomations()
            "Stats" = $this.GetStats()
            "ExecutionLog" = $this.GetExecutionLog(20)
        }
    }
}

$gooseAutomation = [GooseAutomation]::new()

function Get-GooseAutomation {
    return $gooseAutomation
}

function New-Automation {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [hashtable]$Trigger,
        [Parameter(Mandatory=$true)]
        [hashtable[]]$Actions,
        [bool]$Enabled = $true,
        $Automation = $gooseAutomation
    )
    return $Automation.CreateAutomation($Name, $Trigger, $Actions, $Enabled)
}

function Update-Automation {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Id,
        [string]$Name,
        [hashtable]$Trigger,
        [hashtable[]]$Actions,
        [bool]$Enabled,
        $Automation = $gooseAutomation
    )
    return $Automation.UpdateAutomation($Id, $Name, $Trigger, $Actions, $Enabled)
}

function Remove-Automation {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Id,
        $Automation = $gooseAutomation
    )
    return $Automation.DeleteAutomation($Id)
}

function Get-Automation {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Id,
        $Automation = $gooseAutomation
    )
    return $Automation.GetAutomation($Id)
}

function Get-AllAutomations {
    param($Automation = $gooseAutomation)
    return $Automation.GetAllAutomations()
}

function Enable-Automation {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Id,
        $Automation = $gooseAutomation
    )
    return $Automation.UpdateAutomation($Id, $null, $null, $null, $true)
}

function Disable-Automation {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Id,
        $Automation = $gooseAutomation
    )
    return $Automation.UpdateAutomation($Id, $null, $null, $null, $false)
}

function Toggle-Automation {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Id,
        $Automation = $gooseAutomation
    )
    return $Automation.ToggleAutomation($Id)
}

function Trigger-Automation {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Id,
        [hashtable]$Context = @{},
        $Automation = $gooseAutomation
    )
    return $Automation.TriggerAutomation($Id, $Context)
}

function Check-Automations {
    param($Automation = $gooseAutomation)
    return $Automation.CheckAndTrigger()
}

function Get-AutomationLog {
    param(
        [int]$Count = 20,
        $Automation = $gooseAutomation
    )
    return $Automation.GetExecutionLog($Count)
}

function Get-AutomationStats {
    param($Automation = $gooseAutomation)
    return $Automation.GetStats()
}

function New-AutomationFromTemplate {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TemplateName,
        $Automation = $gooseAutomation
    )
    return $Automation.CreateTemplate($TemplateName)
}

function Enable-AutomationHub {
    param($Automation = $gooseAutomation)
    $Automation.SetEnabled($true)
}

function Disable-AutomationHub {
    param($Automation = $gooseAutomation)
    $Automation.SetEnabled($false)
}

function Toggle-AutomationHub {
    param($Automation = $gooseAutomation)
    $Automation.Toggle()
}

function Get-AutomationState {
    param($Automation = $gooseAutomation)
    return $Automation.GetAutomationState()
}

Write-Host "Desktop Goose Automation Hub System Initialized"
$state = Get-AutomationState
Write-Host "Automation Hub Enabled: $($state['Enabled'])"
Write-Host "Total Automations: $($state['Stats']['totalAutomations'])"
