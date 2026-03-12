# Desktop Goose Plugin API System
# Allow custom plugins to extend functionality

enum PluginState {
    Disabled
    Enabled
    Error
    Loading
}

enum HookType {
    OnStartup
    OnShutdown
    OnTick
    OnIdle
    OnActive
    OnAppChange
    OnInteract
    OnMoodChange
    OnMusicPlay
    OnMusicPause
    OnNotification
}

class PluginManifest {
    [string]$Id
    [string]$Name
    [string]$Version
    [string]$Author
    [string]$Description
    [string]$MinGooseVersion
    [string[]]$Hooks
    [string[]]$Permissions
    
    PluginManifest([string]$id, [string]$name) {
        $this.Id = $id
        $this.Name = $name
        $this.Version = "1.0.0"
        $this.Author = ""
        $this.Description = ""
        $this.MinGooseVersion = "2.0.0"
        $this.Hooks = @()
        $this.Permissions = @()
    }
}

class PluginHook {
    [HookType]$Type
    [scriptblock]$Callback
    [string]$PluginId
    
    PluginHook([HookType]$type, [scriptblock]$callback, [string]$pluginId) {
        $this.Type = $type
        $this.Callback = $callback
        $this.PluginId = $pluginId
    }
}

class GoosePlugin {
    [string]$Id
    [string]$Name
    [string]$Path
    [PluginManifest]$Manifest
    [PluginState]$State
    [string]$ErrorMessage
    [datetime]$LoadedAt
    
    GoosePlugin([string]$id, [string]$path) {
        $this.Id = $id
        $this.Path = $path
        $this.State = [PluginState]::Disabled
        $this.LoadedAt = [datetime]::MinValue
    }
}

class GoosePluginAPI {
    [hashtable]$Config
    [System.Collections.ArrayList]$Plugins
    [System.Collections.ArrayList]$RegisteredHooks
    [string]$PluginDirectory
    [bool]$APIEnabled
    [hashtable]$HookHandlers
    
    GoosePluginAPI() {
        $this.Config = $this.LoadConfig()
        $this.Plugins = [System.Collections.ArrayList]::new()
        $this.RegisteredHooks = [System.Collections.ArrayList]::new()
        $this.PluginDirectory = "plugins"
        $this.APIEnabled = $false
        $this.InitializeHookHandlers()
        $this.LoadPlugins()
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
        
        if (-not $this.Config.ContainsKey("PluginAPIEnabled")) {
            $this.Config["PluginAPIEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("PluginDirectory")) {
            $this.Config["PluginDirectory"] = "plugins"
        }
        
        $this.PluginDirectory = $this.Config["PluginDirectory"]
        $this.APIEnabled = $this.Config["PluginAPIEnabled"]
        
        return $this.Config
    }
    
    [void] InitializeHookHandlers() {
        $this.HookHandlers = @{
            "onStartup" = @()
            "onShutdown" = @()
            "onTick" = @()
            "onIdle" = @()
            "onActive" = @()
            "onAppChange" = @()
            "onInteract" = @()
            "onMoodChange" = @()
            "onMusicPlay" = @()
            "onMusicPause" = @()
            "onNotification" = @()
        }
    }
    
    [void] LoadPlugins() {
        if (-not (Test-Path $this.PluginDirectory)) {
            New-Item -ItemType Directory -Path $this.PluginDirectory -Force | Out-Null
        }
        
        $pluginFolders = Get-ChildItem -Path $this.PluginDirectory -Directory -ErrorAction SilentlyContinue
        
        foreach ($folder in $pluginFolders) {
            $manifestFile = Join-Path $folder.FullName "manifest.json"
            
            if (Test-Path $manifestFile) {
                try {
                    $manifest = Get-Content $manifestFile -Raw | ConvertFrom-Json
                    $plugin = [GoosePlugin]::new($manifest.id, $folder.FullName)
                    $plugin.Name = $manifest.name
                    
                    $pluginManifest = [PluginManifest]::new($manifest.id, $manifest.name)
                    $pluginManifest.Version = $manifest.version
                    $pluginManifest.Author = $manifest.author
                    $pluginManifest.Description = $manifest.description
                    $pluginManifest.MinGooseVersion = $manifest.minGooseVersion
                    $pluginManifest.Hooks = @($manifest.hooks)
                    $pluginManifest.Permissions = @($manifest.permissions)
                    
                    $plugin.Manifest = $pluginManifest
                    $plugin.State = [PluginState]::Disabled
                    
                    $this.Plugins.Add($plugin)
                } catch {
                    Write-Host "Failed to load plugin from $($folder.Name): $_"
                }
            }
        }
    }
    
    [hashtable] EnablePlugin([string]$pluginId) {
        $result = @{
            success = $false
            message = ""
        }
        
        $plugin = $this.Plugins | Where-Object { $_.Id -eq $pluginId } | Select-Object -First 1
        
        if (-not $plugin) {
            $result.message = "Plugin not found: $pluginId"
            return $result
        }
        
        $mainScript = Join-Path $plugin.Path "main.ps1"
        
        if (-not (Test-Path $mainScript)) {
            $plugin.State = [PluginState]::Error
            $plugin.ErrorMessage = "main.ps1 not found"
            $result.message = "main.ps1 not found in plugin"
            return $result
        }
        
        try {
            $plugin.State = [PluginState]::Loading
            
            $scriptContent = Get-Content $mainScript -Raw -ErrorAction Stop
            
            $plugin.State = [PluginState]::Enabled
            $plugin.LoadedAt = Get-Date
            
            $result.success = $true
            $result.message = "Plugin enabled: $($plugin.Name)"
        } catch {
            $plugin.State = [PluginState]::Error
            $plugin.ErrorMessage = $_.Exception.Message
            $result.message = "Failed to load: $($_.Exception.Message)"
        }
        
        return $result
    }
    
    [hashtable] DisablePlugin([string]$pluginId) {
        $result = @{
            success = $false
            message = ""
        }
        
        $plugin = $this.Plugins | Where-Object { $_.Id -eq $pluginId } | Select-Object -First 1
        
        if (-not $plugin) {
            $result.message = "Plugin not found: $pluginId"
            return $result
        }
        
        $plugin.State = [PluginState]::Disabled
        
        $this.UnregisterPluginHooks($pluginId)
        
        $result.success = $true
        $result.message = "Plugin disabled: $($plugin.Name)"
        
        return $result
    }
    
    [void] RegisterHook([string]$hookName, [scriptblock]$callback, [string]$pluginId) {
        $hookType = $null
        
        try {
            $hookType = [HookType]$hookName
        } catch {
            return
        }
        
        $hook = [PluginHook]::new($hookType, $callback, $pluginId)
        $this.RegisteredHooks.Add($hook)
        
        $handlerKey = $hookName.ToLower()
        if ($this.HookHandlers.ContainsKey($handlerKey)) {
            $this.HookHandlers[$handlerKey] += @($hook)
        }
    }
    
    [void] UnregisterPluginHooks([string]$pluginId) {
        $hooksToRemove = $this.RegisteredHooks | Where-Object { $_.PluginId -eq $pluginId }
        
        foreach ($hook in $hooksToRemove) {
            $this.RegisteredHooks.Remove($hook)
            
            $handlerKey = $hook.Type.ToString().ToLower()
            if ($this.HookHandlers.ContainsKey($handlerKey)) {
                $this.HookHandlers[$handlerKey] = @($this.HookHandlers[$handlerKey] | Where-Object { $_.PluginId -ne $pluginId })
            }
        }
    }
    
    [void] TriggerHook([string]$hookName, $params = $null) {
        $handlerKey = $hookName.ToLower()
        
        if (-not $this.HookHandlers.ContainsKey($handlerKey)) { return }
        
        foreach ($hook in $this.HookHandlers[$handlerKey]) {
            try {
                if ($params) {
                    & $hook.Callback @params
                } else {
                    & $hook.Callback
                }
            } catch {
                Write-Host "Hook error in $($hook.PluginId): $_"
            }
        }
    }
    
    [void] TriggerStartup() {
        $this.TriggerHook("onStartup")
    }
    
    [void] TriggerShutdown() {
        $this.TriggerHook("onShutdown")
    }
    
    [void] TriggerTick([int]$interval) {
        $this.TriggerHook("onTick", @{Interval = $interval})
    }
    
    [void] TriggerIdle([int]$idleMinutes) {
        $this.TriggerHook("onIdle", @{IdleMinutes = $idleMinutes})
    }
    
    [void] TriggerAppChange([string]$appName, [string]$windowTitle) {
        $this.TriggerHook("onAppChange", @{AppName = $appName; WindowTitle = $windowTitle})
    }
    
    [void] TriggerInteract([int]$x, [int]$y) {
        $this.TriggerHook("onInteract", @{X = $x; Y = $y})
    }
    
    [void] TriggerMoodChange([string]$oldMood, [string]$newMood) {
        $this.TriggerHook("onMoodChange", @{OldMood = $oldMood; NewMood = $newMood})
    }
    
    [void] TriggerMusicPlay([string]$trackName, [string]$artist) {
        $this.TriggerHook("onMusicPlay", @{TrackName = $trackName; Artist = $artist})
    }
    
    [hashtable] GetPluginState([string]$pluginId) {
        $plugin = $this.Plugins | Where-Object { $_.Id -eq $pluginId } | Select-Object -First 1
        
        if (-not $plugin) {
            return @{ Exists = $false }
        }
        
        return @{
            Exists = $true
            Id = $plugin.Id
            Name = $plugin.Name
            Path = $plugin.Path
            State = $plugin.State.ToString()
            Version = $plugin.Manifest.Version
            Author = $plugin.Manifest.Author
            Description = $plugin.Manifest.Description
            LoadedAt = $plugin.LoadedAt
            ErrorMessage = $plugin.ErrorMessage
        }
    }
    
    [hashtable] GetPluginAPIState() {
        return @{
            Enabled = $this.APIEnabled
            PluginDirectory = $this.PluginDirectory
            PluginCount = $this.Plugins.Count
            EnabledPlugins = @($this.Plugins | Where-Object { $_.State -eq [PluginState]::Enabled }).Count
            RegisteredHooks = $this.RegisteredHooks.Count
            Plugins = @($this.Plugins | ForEach-Object {
                @{
                    Id = $_.Id
                    Name = $_.Name
                    State = $_.State.ToString()
                    Version = $_.Manifest.Version
                }
            })
        }
    }
}

$goosePluginAPI = [GoosePluginAPI]::new()

function Get-GoosePluginAPI {
    return $goosePluginAPI
}

function Register-Hook {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Hook,
        [Parameter(Mandatory=$true)]
        [scriptblock]$Callback,
        [string]$PluginId = "default",
        $API = $goosePluginAPI
    )
    $API.RegisterHook($Hook, $Callback, $PluginId)
}

function Enable-Plugin {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PluginId,
        $API = $goosePluginAPI
    )
    return $API.EnablePlugin($PluginId)
}

function Disable-Plugin {
    param(
        [Parameter(Mandatory=$true)]
        [string]$PluginId,
        $API = $goosePluginAPI
    )
    return $API.DisablePlugin($PluginId)
}

function Get-PluginState {
    param(
        [string]$PluginId,
        $API = $goosePluginAPI
    )
    if ($PluginId) {
        return $API.GetPluginState($PluginId)
    }
    return $API.GetPluginAPIState()
}

function Get-RegisteredHooks {
    param($API = $goosePluginAPI)
    return $API.RegisteredHooks
}

Write-Host "Desktop Goose Plugin API System Initialized"
$state = Get-PluginState
Write-Host "Plugin API Enabled: $($state['Enabled']) | Plugins: $($state['PluginCount']) | Enabled: $($state['EnabledPlugins'])"
