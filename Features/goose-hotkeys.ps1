# Desktop Goose Hotkey Command System
# Global hotkey commands

class GooseHotkeySystem {
    [hashtable]$Config
    [hashtable]$Hotkeys
    [string]$HotkeysFile
    
    GooseHotkeySystem() {
        $this.Config = $this.LoadConfig()
        $this.HotkeysFile = "goose_hotkeys.json"
        $this.Hotkeys = @{}
        $this.LoadHotkeys()
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
        
        return $this.Config
    }
    
    [void] LoadHotkeys() {
        if (Test-Path $this.HotkeysFile) {
            try {
                $loaded = Get-Content $this.HotkeysFile | ConvertFrom-Json
                $this.Hotkeys = $loaded
            } catch {
                $this.Hotkeys = @{}
            }
        }
        
        if ($this.Hotkeys.Count -eq 0) {
            $this.SetDefaultHotkeys()
        }
    }
    
    [void] SaveHotkeys() {
        $this.Hotkeys | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.HotkeysFile -Encoding UTF8
    }
    
    [void] SetDefaultHotkeys() {
        $this.Hotkeys = @{
            "Ctrl+Shift+G" = @{ "Action" = "toggle"; "Description" = "Toggle goose visibility" }
            "Ctrl+Shift+H" = @{ "Action" = "honk"; "Description" = "Make goose honk" }
            "Ctrl+Shift+F" = @{ "Action" = "focus"; "Description" = "Start focus mode" }
            "Ctrl+Shift+S" = @{ "Action" = "screenshot"; "Description" = "Screenshot pose" }
            "Ctrl+Shift+T" = @{ "Action" = "timer"; "Description" = "Quick timer" }
        }
        $this.SaveHotkeys()
    }
    
    [hashtable] AddHotkey([string]$keyCombo, [string]$action, [string]$description = "") {
        $this.Hotkeys[$keyCombo] = @{
            "Action" = $action
            "Description" = $description
            "Created" = (Get-Date).ToString("o")
        }
        
        $this.SaveHotkeys()
        
        return @{
            "Success" = $true
            "Hotkey" = $keyCombo
            "Action" = $action
            "Message" = "Hotkey $keyCombo mapped to $action"
        }
    }
    
    [hashtable] RemoveHotkey([string]$keyCombo) {
        if ($this.Hotkeys.ContainsKey($keyCombo)) {
            $this.Hotkeys.Remove($keyCombo)
            $this.SaveHotkeys()
            
            return @{
                "Success" = $true
                "Message" = "Hotkey removed: $keyCombo"
            }
        }
        
        return @{
            "Success" = $false
            "Message" = "Hotkey not found: $keyCombo"
        }
    }
    
    [string] GetAction([string]$keyCombo) {
        if ($this.Hotkeys.ContainsKey($keyCombo)) {
            return $this.Hotkeys[$keyCombo].Action
        }
        return ""
    }
    
    [array] GetAllHotkeys() {
        $list = @()
        foreach ($key in $this.Hotkeys.Keys) {
            $list += @{
                "KeyCombo" = $key
                "Action" = $this.Hotkeys[$key].Action
                "Description" = $this.Hotkeys[$key].Description
            }
        }
        return $list
    }
    
    [hashtable] ResetToDefaults() {
        $this.SetDefaultHotkeys()
        
        return @{
            "Success" = $true
            "Message" = "Hotkeys reset to defaults"
        }
    }
    
    [hashtable] GetHotkeySystemState() {
        return @{
            "Hotkeys" = $this.GetAllHotkeys()
            "HotkeyCount" = $this.Hotkeys.Count
        }
    }
}

$gooseHotkeys = [GooseHotkeySystem]::new()

function Get-GooseHotkeys {
    return $gooseHotkeys
}

function Add-Hotkey {
    param(
        [string]$KeyCombo,
        [string]$Action,
        [string]$Description = "",
        $Hotkeys = $gooseHotkeys
    )
    return $Hotkeys.AddHotkey($KeyCombo, $Action, $Description)
}

function Remove-Hotkey {
    param(
        [string]$KeyCombo,
        $Hotkeys = $gooseHotkeys
    )
    return $Hotkeys.RemoveHotkey($KeyCombo)
}

function Get-AllHotkeys {
    param($Hotkeys = $gooseHotkeys)
    return $Hotkeys.GetAllHotkeys()
}

function Get-HotkeyState {
    param($Hotkeys = $gooseHotkeys)
    return $Hotkeys.GetHotkeySystemState()
}

Write-Host "Desktop Goose Hotkey System Initialized"
$state = Get-HotkeyState
Write-Host "Total Hotkeys: $($state['HotkeyCount'])"
