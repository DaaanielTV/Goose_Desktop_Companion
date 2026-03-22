class GooseTelemetryConfig {
    static [hashtable] Load([string]$configFile = "config.ini") {
        $config = @{
            Enabled = $true
            SyncIntervalDays = 7
            SupabaseUrl = ""
            SupabaseAnonKey = ""
            DeviceId = ""
            MaxBufferSize = 1000
            CollectMetrics = $true
            CollectTraces = $true
            CollectLogs = $true
        }
        if (Test-Path $configFile) {
            Get-Content $configFile | ForEach-Object {
                if ($_ -match '^([^=]+)=(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    if ($config.ContainsKey($key)) {
                        if ($value -eq 'True' -or $value -eq 'False') {
                            $config[$key] = [bool]$value
                        } elseif ($value -match '^\d+$') {
                            $config[$key] = [int]$value
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

class TelemetryMetric {
    [string]$Name
    [string]$Type
    [double]$Value
    [string]$Unit
    [hashtable]$Tags
    [datetime]$Timestamp

    TelemetryMetric([string]$name, [string]$type, [double]$value, [string]$unit = "", [hashtable]$tags = @{}) {
        $this.Name = $name
        $this.Type = $type
        $this.Value = $value
        $this.Unit = $unit
        $this.Tags = $tags
        $this.Timestamp = Get-Date
    }
}

class TelemetrySpan {
    [guid]$TraceId
    [guid]$SpanId
    [guid]$ParentSpanId
    [string]$OperationName
    [string]$ServiceName
    [double]$DurationMs
    [string]$Status
    [hashtable]$Attributes
    [array]$Events
    [datetime]$Timestamp
    [datetime]$StartTime

    TelemetrySpan([string]$operationName, [string]$serviceName = "desktop-goose", [guid]$parentSpanId = [guid]::Empty) {
        $this.TraceId = [guid]::NewGuid()
        $this.SpanId = [guid]::NewGuid()
        $this.ParentSpanId = $parentSpanId
        $this.OperationName = $operationName
        $this.ServiceName = $serviceName
        $this.DurationMs = 0
        $this.Status = "ok"
        $this.Attributes = @{}
        $this.Events = @()
        $this.StartTime = Get-Date
        $this.Timestamp = $this.StartTime
    }

    [void] SetAttribute([string]$key, [string]$value) {
        $this.Attributes[$key] = $value
    }

    [void] AddEvent([string]$name, [hashtable]$attributes = @{}) {
        $this.Events += @{
            Name = $name
            Timestamp = Get-Date
            Attributes = $attributes
        }
    }

    [void] End([string]$status = "ok") {
        $this.DurationMs = ((Get-Date) - $this.StartTime).TotalMilliseconds
        $this.Status = $status
        $this.Timestamp = Get-Date
    }
}

class TelemetryLog {
    [guid]$TraceId
    [guid]$SpanId
    [string]$Level
    [string]$Message
    [string]$Source
    [hashtable]$Attributes
    [datetime]$Timestamp

    TelemetryLog([string]$level, [string]$message, [string]$source = "", [guid]$traceId = [guid]::Empty, [guid]$spanId = [guid]::Empty) {
        $this.TraceId = $traceId
        $this.SpanId = $spanId
        $this.Level = $level
        $this.Message = $message
        $this.Source = $source
        $this.Attributes = @{}
        $this.Timestamp = Get-Date
    }
}

class GooseTelemetry {
    [hashtable]$Config
    [string]$DeviceId
    [string]$DataPath
    [array]$MetricsBuffer
    [array]$SpansBuffer
    [array]$LogsBuffer
    [datetime]$LastSync
    [System.Collections.Concurrent.ConcurrentDictionary[string, object]]$Counters

    GooseTelemetry([string]$configFile = "config.ini") {
        $this.Config = GooseTelemetryConfig::Load($configFile)
        $this.DeviceId = $this.GetOrCreateDeviceId()
        $this.DataPath = Join-Path $PSScriptRoot "telemetry_data"
        if (-not (Test-Path $this.DataPath)) {
            New-Item -ItemType Directory -Path $this.DataPath -Force | Out-Null
        }
        $this.MetricsBuffer = @()
        $this.SpansBuffer = @()
        $this.LogsBuffer = @()
        $this.LastSync = $this.LoadLastSyncTime()
        $this.Counters = [System.Collections.Concurrent.ConcurrentDictionary[string, object]]::new()
        $this.LoadBufferedData()
    }

    [string] GetOrCreateDeviceId() {
        if ($this.Config["DeviceId"] -and $this.Config["DeviceId"] -ne "") {
            return $this.Config["DeviceId"]
        }
        $deviceIdFile = Join-Path $this.DataPath "device_id.txt"
        if (Test-Path $deviceIdFile) {
            return (Get-Content $deviceIdFile -Raw).Trim()
        }
        $newId = [guid]::NewGuid().ToString()
        Set-Content -Path $deviceIdFile -Value $newId
        return $newId
    }

    [datetime] LoadLastSyncTime() {
        $syncFile = Join-Path $this.DataPath "last_sync.txt"
        if (Test-Path $syncFile) {
            $content = Get-Content $syncFile -Raw
            try {
                return [datetime]::Parse($content.Trim())
            } catch { }
        }
        return (Get-Date).AddDays(-8)
    }

    [void] SaveLastSyncTime() {
        $syncFile = Join-Path $this.DataPath "last_sync.txt"
        Set-Content -Path $syncFile -Value $this.LastSync.ToString("o")
    }

    [void] LoadBufferedData() {
        $metricsFile = Join-Path $this.DataPath "metrics.json"
        $spansFile = Join-Path $this.DataPath "spans.json"
        $logsFile = Join-Path $this.DataPath "logs.json"

        if (Test-Path $metricsFile) {
            try {
                $this.MetricsBuffer = (Get-Content $metricsFile -Raw | ConvertFrom-Json)
                if ($this.MetricsBuffer -isnot [array]) { $this.MetricsBuffer = @() }
            } catch { $this.MetricsBuffer = @() }
        }
        if (Test-Path $spansFile) {
            try {
                $this.SpansBuffer = (Get-Content $spansFile -Raw | ConvertFrom-Json)
                if ($this.SpansBuffer -isnot [array]) { $this.SpansBuffer = @() }
            } catch { $this.SpansBuffer = @() }
        }
        if (Test-Path $logsFile) {
            try {
                $this.LogsBuffer = (Get-Content $logsFile -Raw | ConvertFrom-Json)
                if ($this.LogsBuffer -isnot [array]) { $this.LogsBuffer = @() }
            } catch { $this.LogsBuffer = @() }
        }
    }

    [void] SaveBufferedData() {
        $metricsFile = Join-Path $this.DataPath "metrics.json"
        $spansFile = Join-Path $this.DataPath "spans.json"
        $logsFile = Join-Path $this.DataPath "logs.json"

        $this.MetricsBuffer | ConvertTo-Json -Depth 10 | Set-Content -Path $metricsFile
        $this.SpansBuffer | ConvertTo-Json -Depth 10 | Set-Content -Path $spansFile
        $this.LogsBuffer | ConvertTo-Json -Depth 10 | Set-Content -Path $logsFile
    }

    [void] RecordMetric([TelemetryMetric]$metric) {
        if (-not $this.Config["Enabled"] -or -not $this.Config["CollectMetrics"]) { return }
        
        $record = @{
            device_id = $this.DeviceId
            metric_name = $metric.Name
            metric_type = $metric.Type
            value = $metric.Value
            unit = $metric.Unit
            tags = $metric.Tags
            timestamp = $metric.Timestamp.ToString("o")
        }
        $this.MetricsBuffer += $record
        if ($this.MetricsBuffer.Count -gt $this.Config["MaxBufferSize"]) {
            $this.MetricsBuffer = $this.MetricsBuffer[-$this.Config["MaxBufferSize"]..-1]
        }
        $this.SaveBufferedData()
    }

    [TelemetrySpan] StartSpan([string]$operationName, [string]$serviceName = "desktop-goose", [guid]$parentSpanId = [guid]::Empty) {
        if (-not $this.Config["Enabled"] -or -not $this.Config["CollectTraces"]) { 
            return $null 
        }
        return [TelemetrySpan]::new($operationName, $serviceName, $parentSpanId)
    }

    [void] EndSpan([TelemetrySpan]$span) {
        if (-not $span -or -not $this.Config["Enabled"] -or -not $this.Config["CollectTraces"]) { return }
        
        $span.End()
        $record = @{
            device_id = $this.DeviceId
            trace_id = $span.TraceId.ToString()
            span_id = $span.SpanId.ToString()
            parent_span_id = if ($span.ParentSpanId -ne [guid]::Empty) { $span.ParentSpanId.ToString() } else { $null }
            operation_name = $span.OperationName
            service_name = $span.ServiceName
            duration_ms = $span.DurationMs
            status = $span.Status
            attributes = $span.Attributes
            events = $span.Events
            timestamp = $span.Timestamp.ToString("o")
        }
        $this.SpansBuffer += $record
        if ($this.SpansBuffer.Count -gt $this.Config["MaxBufferSize"]) {
            $this.SpansBuffer = $this.SpansBuffer[-$this.Config["MaxBufferSize"]..-1]
        }
        $this.SaveBufferedData()
    }

    [void] RecordLog([TelemetryLog]$log) {
        if (-not $this.Config["Enabled"] -or -not $this.Config["CollectLogs"]) { return }
        
        $record = @{
            device_id = $this.DeviceId
            trace_id = if ($log.TraceId -ne [guid]::Empty) { $log.TraceId.ToString() } else { $null }
            span_id = if ($log.SpanId -ne [guid]::Empty) { $log.SpanId.ToString() } else { $null }
            log_level = $log.Level
            message = $log.Message
            source = $log.Source
            attributes = $log.Attributes
            timestamp = $log.Timestamp.ToString("o")
        }
        $this.LogsBuffer += $record
        if ($this.LogsBuffer.Count -gt $this.Config["MaxBufferSize"]) {
            $this.LogsBuffer = $this.LogsBuffer[-$this.Config["MaxBufferSize"]..-1]
        }
        $this.SaveBufferedData()
    }

    [void] IncrementCounter([string]$name, [double]$value = 1, [hashtable]$tags = @{}) {
        $key = $name + ($tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" } -join "_")
        $current = $this.Counters.GetOrAdd($key, { 0 })
        $this.Counters[$key] = $current + $value
        
        $metric = [TelemetryMetric]::new($name, "counter", $this.Counters[$key], "count", $tags)
        $this.RecordMetric($metric)
    }

    [void] RecordGauge([string]$name, [double]$value, [hashtable]$tags = @{}) {
        $metric = [TelemetryMetric]::new($name, "gauge", $value, "", $tags)
        $this.RecordMetric($metric)
    }

    [void] RecordHistogram([string]$name, [double]$value, [string]$unit = "", [hashtable]$tags = @{}) {
        $metric = [TelemetryMetric]::new($name, "histogram", $value, $unit, $tags)
        $this.RecordMetric($metric)
    }

    [bool] ShouldSync() {
        $daysSinceSync = ((Get-Date) - $this.LastSync).Days
        return $daysSinceSync -ge $this.Config["SyncIntervalDays"]
    }

    [hashtable] SyncToSupabase() {
        $result = @{
            Success = $false
            MetricsUploaded = 0
            SpansUploaded = 0
            LogsUploaded = 0
            Error = $null
        }

        if (-not $this.Config["Enabled"]) {
            $result.Error = "Telemetry is disabled"
            return $result
        }

        if (-not $this.Config["SupabaseUrl"] -or -not $this.Config["SupabaseAnonKey"]) {
            $result.Error = "Supabase not configured"
            return $result
        }

        try {
            $headers = @{
                "apikey" = $this.Config["SupabaseAnonKey"]
                "Authorization" = "Bearer $($this.Config["SupabaseAnonKey"])"
                "Content-Type" = "application/json"
                "Prefer" = "return=minimal"
            }

            if ($this.MetricsBuffer.Count -gt 0) {
                $metricsPayload = @{
                    device_id = $this.DeviceId
                    batch_type = "metrics"
                    record_count = $this.MetricsBuffer.Count
                    data = $this.MetricsBuffer
                }
                $response = Invoke-RestMethod -Uri "$($this.Config['SupabaseUrl'])/rest/v1/telemetry_batches" -Method Post -Headers $headers -Body ($metricsPayload | ConvertTo-Json -Depth 10) -ErrorAction Stop
                $result.MetricsUploaded = $this.MetricsBuffer.Count
                $this.MetricsBuffer = @()
            }

            if ($this.SpansBuffer.Count -gt 0) {
                $spansPayload = @{
                    device_id = $this.DeviceId
                    batch_type = "spans"
                    record_count = $this.SpansBuffer.Count
                    data = $this.SpansBuffer
                }
                $response = Invoke-RestMethod -Uri "$($this.Config['SupabaseUrl'])/rest/v1/telemetry_batches" -Method Post -Headers $headers -Body ($spansPayload | ConvertTo-Json -Depth 10) -ErrorAction Stop
                $result.SpansUploaded = $this.SpansBuffer.Count
                $this.SpansBuffer = @()
            }

            if ($this.LogsBuffer.Count -gt 0) {
                $logsPayload = @{
                    device_id = $this.DeviceId
                    batch_type = "logs"
                    record_count = $this.LogsBuffer.Count
                    data = $this.LogsBuffer
                }
                $response = Invoke-RestMethod -Uri "$($this.Config['SupabaseUrl'])/rest/v1/telemetry_batches" -Method Post -Headers $headers -Body ($logsPayload | ConvertTo-Json -Depth 10) -ErrorAction Stop
                $result.LogsUploaded = $this.LogsBuffer.Count
                $this.LogsBuffer = @()
            }

            $this.SaveBufferedData()
            $this.LastSync = Get-Date
            $this.SaveLastSyncTime()
            $result.Success = $true

        } catch {
            $result.Error = $_.Exception.Message
        }

        return $result
    }

    [void] RecordSystemMetrics() {
        try {
            $cpu = (Get-Counter '\Processor(_Total)\% Processor Time' -ErrorAction SilentlyContinue).CounterSamples.CookedValue
            if ($cpu) { $this.RecordGauge("system.cpu.usage_percent", [math]::Round($cpu, 2)) }

            $mem = Get-CimInstance Win32_OperatingSystem
            $memUsed = $mem.TotalVisibleMemorySize - $mem.FreePhysicalMemory
            $memPercent = ($memUsed / $mem.TotalVisibleMemorySize) * 100
            $this.RecordGauge("system.memory.usage_percent", [math]::Round($memPercent, 2))

            $uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
            $this.RecordGauge("system.uptime.minutes", [math]::Round($uptime.TotalMinutes, 0))
        } catch { }
    }

    [void] RecordGooseMetrics([hashtable]$gooseState) {
        if ($gooseState.ContainsKey("Behavior")) {
            $this.RecordGauge("goose.activity_level", $gooseState.Behavior.CurrentActivityLevel)
            $this.RecordGauge("goose.interactions", $gooseState.Behavior.InteractionCount)
        }
        if ($gooseState.ContainsKey("Personality")) {
            $this.RecordGauge("goose.happiness", $gooseState.Personality.HappinessLevel)
            $this.RecordGauge("goose.trust", $gooseState.Personality.TrustLevel)
        }
        if ($gooseState.ContainsKey("Visual")) {
            $this.RecordGauge("goose.energy", $gooseState.Visual.Energy)
        }
    }
}

$gooseTelemetry = [GooseTelemetry]::new()

function Get-Telemetry { return $gooseTelemetry }
function Start-TelemetrySpan { param([string]$Name, [string]$Service = "desktop-goose", $ParentSpan); return $gooseTelemetry.StartSpan($Name, $Service, $ParentSpan) }
function Stop-TelemetrySpan { param([TelemetrySpan]$Span, [string]$Status = "ok"); $gooseTelemetry.EndSpan($Span) }
function Write-TelemetryLog { param([string]$Level, [string]$Message, [string]$Source = "", $TraceId, $SpanId); $gooseTelemetry.RecordLog([TelemetryLog]::new($Level, $Message, $Source, $TraceId, $SpanId)) }
function Increment-TelemetryCounter { param([string]$Name, [double]$Value = 1, [hashtable]$Tags = @{}); $gooseTelemetry.IncrementCounter($Name, $Value, $Tags) }
function Set-TelemetryGauge { param([string]$Name, [double]$Value, [hashtable]$Tags = @{}); $gooseTelemetry.RecordGauge($Name, $Value, $Tags) }
function Record-TelemetryHistogram { param([string]$Name, [double]$Value, [string]$Unit = "", [hashtable]$Tags = @{}); $gooseTelemetry.RecordHistogram($Name, $Value, $Unit, $Tags) }
function Sync-Telemetry { return $gooseTelemetry.SyncToSupabase() }
function Test-TelemetrySync { return $gooseTelemetry.ShouldSync() }
function Get-TelemetryConfig { return $gooseTelemetry.Config }

function Record-ScriptHubMetrics {
    param([string]$Action, [hashtable]$Tags = @{})
    $gooseTelemetry.IncrementCounter("script_hub.$Action", 1, $Tags)
}

function Record-CaptureMetrics {
    param([string]$Action, [hashtable]$Tags = @{})
    $gooseTelemetry.IncrementCounter("capture.$Action", 1, $Tags)
}

function Record-FocusMetrics {
    param([string]$Action, [double]$Value = 1, [hashtable]$Tags = @{})
    if ($Action -eq "duration") {
        $gooseTelemetry.RecordHistogram("focus.duration_minutes", $Value, "minutes", $Tags)
    } else {
        $gooseTelemetry.IncrementCounter("focus.$Action", $Value, $Tags)
    }
}

function Record-VoiceMetrics {
    param([string]$Action, [hashtable]$Tags = @{})
    $gooseTelemetry.IncrementCounter("voice.$Action", 1, $Tags)
}

function Record-NotificationMetrics {
    param([string]$Action, [hashtable]$Tags = @{})
    $gooseTelemetry.IncrementCounter("notifications.$Action", 1, $Tags)
}

function Record-NotesMetrics {
    param([string]$Action, [double]$Value = 1, [hashtable]$Tags = @{})
    if ($Action -eq "characters") {
        $gooseTelemetry.RecordHistogram("notes.characters_written", $Value, "chars", $Tags)
    } else {
        $gooseTelemetry.IncrementCounter("notes.$Action", $Value, $Tags)
    }
}

function Record-WindowMetrics {
    param([string]$Action, [hashtable]$Tags = @{})
    $gooseTelemetry.IncrementCounter("window.$Action", 1, $Tags)
}

function Record-BriefingMetrics {
    param([string]$Action, [hashtable]$Tags = @{})
    $gooseTelemetry.IncrementCounter("briefing.$Action", 1, $Tags)
}

function Record-MemoryMetrics {
    param([string]$Action, [hashtable]$Tags = @{})
    $gooseTelemetry.IncrementCounter("memory.$Action", 1, $Tags)
}

function Record-AchievementMetrics {
    param([string]$AchievementId)
    $gooseTelemetry.IncrementCounter("achievements.unlocked", 1, @{achievement=$AchievementId})
}

Write-Host "Telemetry Module Initialized"
