class GooseLoggingConfig {
    static [hashtable] Load([string]$configFile = "config.ini") {
        $config = @{
            Enabled = $true
            Level = "DEBUG"
            FilePath = "logs/goose.log"
            MaxFileSizeKB = 10240
            MaxFiles = 5
            ConsoleOutput = $true
            TelemetryIntegration = $true
        }
        if (Test-Path $configFile) {
            Get-Content $configFile | ForEach-Object {
                if ($_ -match '^([^=]+)=(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    if ($config.ContainsKey($key)) {
                        if ($value -eq 'True' -or $value -eq 'False') {
                            $config[$key] = [bool]$value
                        } else {
                            $config[$key] = $value
                        }
                    }
                }
            }
        }
        return $config
    }
}

enum LogLevel {
    DEBUG = 0
    INFO = 1
    WARN = 2
    ERROR = 3
}

class GooseLogger {
    [hashtable]$Config
    [string]$LogFilePath
    [LogLevel]$MinLevel
    [object]$Telemetry
    [System.Collections.Concurrent.ConcurrentDictionary[string, int]]$Stats

    GooseLogger([string]$configFile = "config.ini") {
        $this.Config = GooseLoggingConfig::Load($configFile)
        $this.LogFilePath = $this.Config["FilePath"]
        $this.MinLevel = [LogLevel][$this.Config["Level"]]
        $this.Stats = [System.Collections.Concurrent.ConcurrentDictionary[string, int]]::new()
        
        $logDir = Split-Path $this.LogFilePath -Parent
        if ($logDir -and -not (Test-Path $logDir)) {
            New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        }

        if ($this.Config["TelemetryIntegration"] -and (Get-Command Get-Telemetry -ErrorAction SilentlyContinue)) {
            $this.Telemetry = Get-Telemetry
        }

        $this.Log([LogLevel]::INFO, "Logger initialized", "GooseLogger")
    }

    [void] Log([LogLevel]$level, [string]$message, [string]$source = "") {
        if (-not $this.Config["Enabled"] -or $level -lt $this.MinLevel) { return }

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss.fff"
        $levelStr = $level.ToString()
        $sourceStr = if ($source) { "[$source] " } else { "" }
        $logEntry = "$timestamp [$levelStr] $sourceStr$message"

        $key = $levelStr
        $this.Stats.AddOrUpdate($key, 1, { param($k, $v) $v + 1 })

        $this.WriteToFile($logEntry)

        if ($this.Config["ConsoleOutput"]) {
            $color = switch ($level) {
                [LogLevel]::DEBUG { "Gray" }
                [LogLevel]::INFO { "White" }
                [LogLevel]::WARN { "Yellow" }
                [LogLevel]::ERROR { "Red" }
            }
            Write-Host $logEntry -ForegroundColor $color
        }

        if ($this.Telemetry -and $this.Config["TelemetryIntegration"]) {
            $telemetryLevel = switch ($level) {
                [LogLevel]::DEBUG { "debug" }
                [LogLevel]::INFO { "info" }
                [LogLevel]::WARN { "warning" }
                [LogLevel]::ERROR { "error" }
            }
            $tags = @{ source = $source }
            if ($this.Telemetry.PSObject.Properties.Name -contains "RecordLog") {
                $logObj = [PSCustomObject]@{
                    TraceId = [guid]::Empty
                    SpanId = [guid]::Empty
                    Level = $telemetryLevel
                    Message = $message
                    Source = $source
                    Attributes = $tags
                    Timestamp = Get-Date
                }
                $this.Telemetry.RecordLog($logObj)
            }
        }
    }

    [void] WriteToFile([string]$message) {
        try {
            $maxSize = $this.Config["MaxFileSizeKB"] * 1024
            if (Test-Path $this.LogFilePath) {
                $fileInfo = Get-Item $this.LogFilePath
                if ($fileInfo.Length -gt $maxSize) {
                    $this.RotateLogs()
                }
            }
            Add-Content -Path $this.LogFilePath -Value $message -ErrorAction SilentlyContinue
        } catch { }
    }

    [void] RotateLogs() {
        $dir = Split-Path $this.LogFilePath -Parent
        $name = Split-Path $this.LogFilePath -Leaf
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($name)
        $ext = [System.IO.Path]::GetExtension($name)
        
        $maxFiles = $this.Config["MaxFiles"]
        
        for ($i = $maxFiles - 1; $i -gt 0; $i--) {
            $oldFile = Join-Path $dir "$baseName.$i$ext"
            $newFile = Join-Path $dir "$baseName.$($i + 1)$ext"
            if (Test-Path $oldFile) {
                Move-Item -Path $oldFile -Destination $newFile -Force
            }
        }
        
        $newFile = Join-Path $dir "$baseName.1$ext"
        if (Test-Path $this.LogFilePath) {
            Move-Item -Path $this.LogFilePath -Destination $newFile -Force
        }
    }

    [void] Debug([string]$message, [string]$source = "") {
        $this.Log([LogLevel]::DEBUG, $message, $source)
    }

    [void] Info([string]$message, [string]$source = "") {
        $this.Log([LogLevel]::INFO, $message, $source)
    }

    [void] Warn([string]$message, [string]$source = "") {
        $this.Log([LogLevel]::WARN, $message, $source)
    }

    [void] Error([string]$message, [string]$source = "") {
        $this.Log([LogLevel]::ERROR, $message, $source)
    }

    [hashtable] GetStats() {
        return @{
            Debug = $this.Stats.GetOrAdd("DEBUG", 0)
            Info = $this.Stats.GetOrAdd("INFO", 0)
            Warn = $this.Stats.GetOrAdd("WARN", 0)
            Error = $this.Stats.GetOrAdd("ERROR", 0)
        }
    }
}

$gooseLogger = [GooseLogger]::new()

function Write-LogDebug {
    param([string]$Message, [string]$Source = "")
    $gooseLogger.Debug($Message, $Source)
}

function Write-LogInfo {
    param([string]$Message, [string]$Source = "")
    $gooseLogger.Info($Message, $Source)
}

function Write-LogWarn {
    param([string]$Message, [string]$Source = "")
    $gooseLogger.Warn($Message, $Source)
}

function Write-LogError {
    param([string]$Message, [string]$Source = "")
    $gooseLogger.Error($Message, $Source)
}

function Get-Logger {
    return $gooseLogger
}

function Get-LogStats {
    return $gooseLogger.GetStats()
}

Write-Host "Logging Module Initialized"
