class GooseScriptHub {
    [hashtable]$Config
    [string]$ScriptsFolder
    [string]$DataPath
    [array]$Scripts
    [object]$Telemetry
    
    GooseScriptHub([string]$configFile = "config.ini", [object]$telemetry = $null) {
        $this.Telemetry = $telemetry
        $this.LoadConfig($configFile)
        $this.ScriptsFolder = Join-Path $PSScriptRoot "..\scripts"
        $this.DataPath = Join-Path $PSScriptRoot "script_hub_data"
        if (-not (Test-Path $this.ScriptsFolder)) {
            New-Item -ItemType Directory -Path $this.ScriptsFolder -Force | Out-Null
        }
        if (-not (Test-Path $this.DataPath)) {
            New-Item -ItemType Directory -Path $this.DataPath -Force | Out-Null
        }
        $this.Scripts = @()
        $this.LoadData()
    }
    
    [void] LoadConfig([string]$configFile) {
        $this.Config = @{
            Enabled = $true
            ScriptsFolder = "scripts"
            MaxHistoryItems = 50
            AutoSave = $true
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
    
    [void] LoadData() {
        $dataFile = Join-Path $this.DataPath "scripts.json"
        if (Test-Path $dataFile) {
            try {
                $this.Scripts = @(Get-Content $dataFile -Raw | ConvertFrom-Json)
                if ($this.Scripts -isnot [array]) { $this.Scripts = @() }
            } catch {
                $this.Scripts = @()
            }
        }
        $this.ScriptsFolder = Join-Path (Split-Path $PSScriptRoot -Parent) $this.Config["ScriptsFolder"]
        if (-not (Test-Path $this.ScriptsFolder)) {
            New-Item -ItemType Directory -Path $this.ScriptsFolder -Force | Out-Null
        }
    }
    
    [void] SaveData() {
        $dataFile = Join-Path $this.DataPath "scripts.json"
        $this.Scripts | ConvertTo-Json -Depth 10 | Set-Content -Path $dataFile
    }
    
    [hashtable] CreateScript([string]$name, [string]$description, [string]$code, [string]$category = "Custom") {
        $this.Telemetry?.IncrementCounter("scripts.created", 1, @{category=$category})
        $script = @{
            id = [guid]::NewGuid().ToString()
            name = $name
            description = $description
            code = $code
            category = $category
            createdAt = (Get-Date).ToString("o")
            updatedAt = (Get-Date).ToString("o")
            executionCount = 0
            lastExecuted = $null
        }
        $this.Scripts += $script
        $this.SaveData()
        $this.ExportToFile($script)
        return $script
    }
    
    [void] ExportToFile([hashtable]$script) {
        $safeName = $script.name -replace '[^\w\-]', '_'
        $filePath = Join-Path $this.ScriptsFolder "$($safeName)_$($script.id).json"
        $script | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath
    }
    
    [hashtable] ExecuteScript([string]$scriptId, [hashtable]$parameters = @{}) {
        $script = $this.Scripts | Where-Object { $_.id -eq $scriptId } | Select-Object -First 1
        if (-not $script) {
            return @{success=$false; error="Script not found"}
        }
        $startTime = Get-Date
        $span = $this.Telemetry?.StartSpan("script.execution", "script-hub")
        $this.Telemetry?.IncrementCounter("scripts.executed", 1, @{script_name=$script.name; category=$script.category})
        try {
            $tempFile = Join-Path $env:TEMP "goose_script_$([guid]::NewGuid().ToString()).ps1"
            $code = $script.code
            foreach ($key in $parameters.Keys) {
                $code = $code -replace "\`$$key", $parameters[$key]
            }
            Set-Content -Path $tempFile -Value $code
            $output = & powershell -ExecutionPolicy Bypass -File $tempFile 2>&1 | Out-String
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
            $script.executionCount++
            $script.lastExecuted = (Get-Date).ToString("o")
            $this.SaveData()
            $duration = ((Get-Date) - $startTime).TotalMilliseconds
            $this.Telemetry?.RecordHistogram("scripts.execution_duration_ms", $duration, "ms", @{script_name=$script.name})
            $this.Telemetry?.StopSpan($span)
            return @{
                success = $true
                output = $output
                duration = $duration
                script = $script
            }
        } catch {
            $this.Telemetry?.IncrementCounter("scripts.errors", 1, @{script_name=$script.name; error_type=$_.Exception.GetType().Name})
            $this.Telemetry?.StopSpan($span)
            return @{
                success = $false
                error = $_.Exception.Message
                script = $script
            }
        }
    }
    
    [void] DeleteScript([string]$scriptId) {
        $this.Scripts = @($this.Scripts | Where-Object { $_.id -ne $scriptId })
        $this.SaveData()
    }
    
    [array] GetScriptsByCategory([string]$category) {
        return @($this.Scripts | Where-Object { $_.category -eq $category })
    }
    
    [hashtable] ImportFromFile([string]$filePath) {
        try {
            $content = Get-Content $filePath -Raw | ConvertFrom-Json
            $script = $this.CreateScript($content.name, $content.description, $content.code, $content.category)
            return @{success=$true; script=$script}
        } catch {
            return @{success=$false; error=$_.Exception.Message}
        }
    }
    
    [hashtable] GetExecutionHistory() {
        $historyFile = Join-Path $this.DataPath "history.json"
        if (Test-Path $historyFile) {
            try {
                return (Get-Content $historyFile -Raw | ConvertFrom-Json)
            } catch { }
        }
        return @()
    }
    
    [void] RecordExecution([hashtable]$result) {
        $historyFile = Join-Path $this.DataPath "history.json"
        $history = $this.GetExecutionHistory()
        $entry = @{
            timestamp = (Get-Date).ToString("o")
            scriptName = $result.script.name
            success = $result.success
            duration = $result.duration
            output = if ($result.output) { $result.output.Substring(0, [Math]::Min(500, $result.output.Length)) } else ""
        }
        $history = @($entry) + $history
        if ($history.Count -gt $this.Config["MaxHistoryItems"]) {
            $history = $history[0..($this.Config["MaxHistoryItems"]-1)]
        }
        $history | ConvertTo-Json -Depth 10 | Set-Content -Path $historyFile
    }
}

$gooseScriptHub = $null

function Get-ScriptHub {
    param([object]$Telemetry = $null)
    if ($script:gooseScriptHub -eq $null) {
        $script:gooseScriptHub = [GooseScriptHub]::new("config.ini", $Telemetry)
    }
    return $script:gooseScriptHub
}

function New-GooseScript {
    param(
        [string]$Name,
        [string]$Description = "",
        [string]$Code = "",
        [string]$Category = "Custom"
    )
    $hub = Get-ScriptHub
    return $hub.CreateScript($Name, $Description, $Code, $Category)
}

function Invoke-GooseScript {
    param(
        [string]$ScriptId,
        [hashtable]$Parameters = @{}
    )
    $hub = Get-ScriptHub
    $result = $hub.ExecuteScript($ScriptId, $Parameters)
    $hub.RecordExecution($result)
    return $result
}

function Get-GooseScripts {
    param([string]$Category = $null)
    $hub = Get-ScriptHub
    if ($Category) {
        return $hub.GetScriptsByCategory($Category)
    }
    return $hub.Scripts
}

function Remove-GooseScript {
    param([string]$ScriptId)
    $hub = Get-ScriptHub
    $hub.DeleteScript($ScriptId)
}

Write-Host "Script Hub Module Initialized"
