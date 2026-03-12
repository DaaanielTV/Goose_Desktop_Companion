# Desktop Goose Quick Actions Menu System
# Right-click context menu for user interaction

class GooseQuickActions {
    [hashtable]$Config
    [hashtable]$Actions
    [hashtable]$ActionHistory
    [int]$LastActionTime
    
    GooseQuickActions() {
        $this.Config = $this.LoadConfig()
        $this.Actions = $this.InitializeActions()
        $this.ActionHistory = @{}
        $this.LastActionTime = [int64]0
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
                    } elseif ($value -match '^\d+\.\d+$') {
                        $this.Config[$key] = [double]$value
                    } else {
                        $this.Config[$key] = $value
                    }
                }
            }
        }
        
        if (-not $this.Config.ContainsKey("QuickActionsEnabled")) {
            $this.Config["QuickActionsEnabled"] = $true
        }
        
        return $this.Config
    }
    
    [hashtable] InitializeActions() {
        return @{
            "Pet" = @{
                "Label" = "Pet Goose"
                "Icon" = "hand"
                "Cooldown" = 5
                "TrustBonus" = 10
                "HappinessBonus" = 15
                "Animation" = "happy_bounce"
                "Sound" = $null
                "Enabled" = $true
            }
            "Feed" = @{
                "Label" = "Feed Goose"
                "Icon" = "food"
                "Cooldown" = 30
                "TrustBonus" = 5
                "EnergyBonus" = 20
                "Animation" = "eating"
                "Sound" = $null
                "Enabled" = $true
            }
            "Play" = @{
                "Label" = "Play with Goose"
                "Icon" = "ball"
                "Cooldown" = 15
                "TrustBonus" = 8
                "HappinessBonus" = 20
                "Animation" = "playful_chase"
                "Sound" = $null
                "Enabled" = $true
            }
            "Settings" = @{
                "Label" = "Open Settings"
                "Icon" = "gear"
                "Cooldown" = 0
                "Animation" = "none"
                "Sound" = $null
                "Enabled" = $true
            }
            "Dismiss" = @{
                "Label" = "Dismiss Goose"
                "Icon" = "exit"
                "Cooldown" = 0
                "Animation" = "sad_wave"
                "Sound" = $null
                "Enabled" = $true
            }
            "Focus" = @{
                "Label" = "Toggle Focus Mode"
                "Icon" = "focus"
                "Cooldown" = 0
                "Animation" = "nod"
                "Sound" = $null
                "Enabled" = $true
            }
            "Weather" = @{
                "Label" = "Check Weather"
                "Icon" = "cloud"
                "Cooldown" = 10
                "Animation" = "curious_look"
                "Sound" = $null
                "Enabled" = $true
            }
            "Notes" = @{
                "Label" = "Create Note"
                "Icon" = "note"
                "Cooldown" = 5
                "Animation" = "bring_item"
                "Sound" = $null
                "Enabled" = $true
            }
        }
    }
    
    [bool] CanExecuteAction([string]$actionName) {
        if (-not $this.Config["QuickActionsEnabled"]) { return $false }
        
        $action = $this.Actions[$actionName]
        if (-not $action -or -not $action["Enabled"]) { return $false }
        
        $currentTime = [int64](Get-Date).Ticks
        $timeSinceLastAction = ($currentTime - $this.LastActionTime) / 10000000
        
        if ($action["Cooldown"] -and $timeSinceLastAction -lt $action["Cooldown"]) {
            return $false
        }
        
        return $true
    }
    
    [hashtable] ExecuteAction([string]$actionName) {
        $result = @{
            "Success" = $false
            "Message" = ""
            "Action" = $actionName
            "Effects" = @{}
        }
        
        if (-not $this.CanExecuteAction($actionName)) {
            $action = $this.Actions[$actionName]
            if ($action -and $action["Cooldown"]) {
                $result["Message"] = "Action on cooldown. Wait $($action['Cooldown']) seconds."
            }
            return $result
        }
        
        $action = $this.Actions[$actionName]
        $currentTime = [int64](Get-Date).Ticks
        $this.LastActionTime = $currentTime
        
        $result["Success"] = $true
        $result["Message"] = "Action '$($action['Label'])' executed!"
        
        if ($action["TrustBonus"]) {
            $result["Effects"]["TrustBonus"] = $action["TrustBonus"]
        }
        if ($action["HappinessBonus"]) {
            $result["Effects"]["HappinessBonus"] = $action["HappinessBonus"]
        }
        if ($action["EnergyBonus"]) {
            $result["Effects"]["EnergyBonus"] = $action["EnergyBonus"]
        }
        $result["Effects"]["Animation"] = $action["Animation"]
        
        $this.RecordAction($actionName)
        
        return $result
    }
    
    [void] RecordAction([string]$actionName) {
        if (-not $this.ActionHistory.ContainsKey($actionName)) {
            $this.ActionHistory[$actionName] = 0
        }
        $this.ActionHistory[$actionName]++
    }
    
    [hashtable] GetAvailableActions() {
        $available = @{}
        
        foreach ($actionName in $this.Actions.Keys) {
            if ($this.CanExecuteAction($actionName)) {
                $available[$actionName] = $this.Actions[$actionName]
            }
        }
        
        return $available
    }
    
    [hashtable] GetActionState() {
        return @{
            "Enabled" = $this.Config["QuickActionsEnabled"]
            "AvailableActions" = $this.GetAvailableActions()
            "AllActions" = $this.Actions
            "ActionHistory" = $this.ActionHistory.Clone()
        }
    }
    
    [void] SetActionEnabled([string]$actionName, [bool]$enabled) {
        if ($this.Actions.ContainsKey($actionName)) {
            $this.Actions[$actionName]["Enabled"] = $enabled
        }
    }
    
    [void] SetAllEnabled([bool]$enabled) {
        $this.Config["QuickActionsEnabled"] = $enabled
    }
    
    [hashtable] GetMenuStructure() {
        return @{
            "title" = "Goose Menu"
            "items" = @(
                @{ "id" = "Pet"; "label" = "Pet Goose"; "icon" = "hand" },
                @{ "id" = "Feed"; "label" = "Feed Goose"; "icon" = "food" },
                @{ "id" = "Play"; "label" = "Play with Goose"; "icon" = "ball" },
                @{ "id" = "separator1"; "type" = "separator" },
                @{ "id" = "Weather"; "label" = "Check Weather"; "icon" = "cloud" },
                @{ "id" = "Notes"; "label" = "Create Note"; "icon" = "note" },
                @{ "id" = "Focus"; "label" = "Toggle Focus Mode"; "icon" = "focus" },
                @{ "id" = "separator2"; "type" = "separator" },
                @{ "id" = "Settings"; "label" = "Settings"; "icon" = "gear" },
                @{ "id" = "Dismiss"; "label" = "Dismiss Goose"; "icon" = "exit" }
            )
        }
    }
}

$gooseQuickActions = [GooseQuickActions]::new()

function Get-GooseQuickActions {
    return $gooseQuickActions
}

function Get-AvailableActions {
    param($QuickActions = $gooseQuickActions)
    return $QuickActions.GetAvailableActions()
}

function Invoke-GooseAction {
    param(
        [string]$ActionName,
        $QuickActions = $gooseQuickActions
    )
    return $QuickActions.ExecuteAction($ActionName)
}

function Get-MenuStructure {
    param($QuickActions = $gooseQuickActions)
    return $QuickActions.GetMenuStructure()
}

Write-Host "Desktop Goose Quick Actions System Initialized"
$state = @{ "Enabled" = $gooseQuickActions.Config["QuickActionsEnabled"] }
Write-Host "Quick Actions Enabled: $($state['Enabled'])"
Write-Host "Available Actions: $(($gooseQuickActions.GetAvailableActions()).Count)"
