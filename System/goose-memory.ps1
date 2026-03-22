class GooseMemory {
    [hashtable]$Config
    [string]$DataPath
    [object]$Telemetry
    [hashtable]$Memories
    [hashtable]$Patterns
    [datetime]$LastSave
    
    GooseMemory([string]$configFile = "config.ini", [object]$telemetry = $null) {
        $this.Telemetry = $telemetry
        $this.LoadConfig($configFile)
        $this.DataPath = Join-Path $PSScriptRoot "memory_data"
        if (-not (Test-Path $this.DataPath)) {
            New-Item -ItemType Directory -Path $this.DataPath -Force | Out-Null
        }
        $this.Memories = @{}
        $this.Patterns = @{}
        $this.LastSave = [datetime]::MinValue
        $this.LoadData()
    }
    
    [void] LoadConfig([string]$configFile) {
        $this.Config = @{
            Enabled = $true
            MaxMemories = 1000
            MaxPatternAge = 30
            LearnFromInteractions = $true
            ForgetProbability = 0.05
            RememberPreferences = $true
            StoreConversations = $true
            PatternDetection = $true
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
        $memoriesFile = Join-Path $this.DataPath "memories.json"
        if (Test-Path $memoriesFile) {
            try {
                $this.Memories = @{}
                $data = Get-Content $memoriesFile -Raw | ConvertFrom-Json
                foreach ($prop in $data.PSObject.Properties) {
                    $this.Memories[$prop.Name] = $prop.Value
                }
            } catch {
                $this.Memories = @{}
            }
        }
        $patternsFile = Join-Path $this.DataPath "patterns.json"
        if (Test-Path $patternsFile) {
            try {
                $this.Patterns = @{}
                $data = Get-Content $patternsFile -Raw | ConvertFrom-Json
                foreach ($prop in $data.PSObject.Properties) {
                    $this.Patterns[$prop.Name] = $prop.Value
                }
            } catch {
                $this.Patterns = @{}
            }
        }
    }
    
    [void] SaveData() {
        $memoriesFile = Join-Path $this.DataPath "memories.json"
        $this.Memories | ConvertTo-Json -Depth 10 | Set-Content -Path $memoriesFile
        $patternsFile = Join-Path $this.DataPath "patterns.json"
        $this.Patterns | ConvertTo-Json -Depth 10 | Set-Content -Path $patternsFile
        $this.LastSave = Get-Date
    }
    
    [void] Remember([string]$key, [object]$value, [string]$category = "general") {
        $this.Telemetry?.IncrementCounter("memory.interactions_logged", 1, @{category=$category})
        $memory = @{
            key = $key
            value = $value
            category = $category
            createdAt = (Get-Date).ToString("o")
            lastAccessed = (Get-Date).ToString("o")
            accessCount = 0
        }
        $this.Memories[$key] = $memory
        if ($this.Memories.Count -gt $this.Config["MaxMemories"]) {
            $this.ForgetOldest()
        }
        if ($this.Config["LearnFromInteractions"] -and $this.Config["PatternDetection"]) {
            $this.DetectPattern($key, $value)
        }
        $this.AutoSave()
    }
    
    [object] Recall([string]$key) {
        $this.Telemetry?.IncrementCounter("memory.recalls", 1, @{key=$key})
        if ($this.Memories.ContainsKey($key)) {
            $memory = $this.Memories[$key]
            $memory.lastAccessed = (Get-Date).ToString("o")
            $memory.accessCount++
            $this.AutoSave()
            return $memory.value
        }
        return $null
    }
    
    [void] Forget([string]$key) {
        if ($this.Memories.ContainsKey($key)) {
            $this.Memories.Remove($key)
            $this.Telemetry?.IncrementCounter("memory.forgotten", 1, @{key=$key})
            $this.AutoSave()
        }
    }
    
    [void] ForgetOldest() {
        $oldestKey = $null
        $oldestDate = [datetime]::MaxValue
        foreach ($key in $this.Memories.Keys) {
            $mem = $this.Memories[$key]
            $created = [datetime]::Parse($mem.createdAt)
            if ($created -lt $oldestDate) {
                $oldestDate = $created
                $oldestKey = $key
            }
        }
        if ($oldestKey) {
            $this.Forget($oldestKey)
        }
    }
    
    [void] DetectPattern([string]$key, [object]$value) {
        $dayOfWeek = (Get-Date).DayOfWeek.ToString()
        $hour = (Get-Date).Hour
        $patternKey = "$dayOfWeek-$hour"
        if (-not $this.Patterns.ContainsKey($patternKey)) {
            $this.Patterns[$patternKey] = @{
                key = $patternKey
                type = "time_based"
                occurrences = 0
                associatedKeys = @()
                confidence = 0
            }
        }
        $pattern = $this.Patterns[$patternKey]
        $pattern.occurrences++
        $pattern.confidence = [math]::Min(1.0, $pattern.occurrences / 10)
        if ($pattern.associatedKeys -notcontains $key) {
            $pattern.associatedKeys += $key
        }
        if ($pattern.associatedKeys.Count -gt 5) {
            $pattern.associatedKeys = $pattern.associatedKeys[-5..-1]
        }
        $this.Telemetry?.IncrementCounter("memory.patterns_learned", 1, @{pattern_type="time_based"})
    }
    
    [array] GetPattern([string]$dayOfWeek, [int]$hour) {
        $patternKey = "$dayOfWeek-$hour"
        if ($this.Patterns.ContainsKey($patternKey)) {
            $pattern = $this.Patterns[$patternKey]
            if ($pattern.confidence -gt 0.5) {
                $this.Telemetry?.IncrementCounter("memory.pattern_matched", 1)
                return $pattern.associatedKeys
            }
        }
        return @()
    }
    
    [array] GetMemoriesByCategory([string]$category) {
        return @($this.Memories.Values | Where-Object { $_.category -eq $category })
    }
    
    [hashtable] GetRecentMemories([int]$count = 10) {
        $sorted = $this.Memories.Values | Sort-Object { [datetime]::Parse($_.lastAccessed) } -Descending
        $recent = @{}
        $i = 0
        foreach ($mem in $sorted) {
            if ($i -ge $count) { break }
            $recent[$mem.key] = $mem
            $i++
        }
        return $recent
    }
    
    [void] StoreConversation([string]$role, [string]$message) {
        if (-not $this.Config["StoreConversations"]) { return }
        $convoKey = "convo_$(Get-Date -Format 'yyyyMMdd')"
        if (-not $this.Memories.ContainsKey($convoKey)) {
            $this.Memories[$convoKey] = @{
                key = $convoKey
                value = @{messages=@()}
                category = "conversation"
                createdAt = (Get-Date).ToString("o")
                lastAccessed = (Get-Date).ToString("o")
                accessCount = 0
            }
        }
        $convo = $this.Memories[$convoKey].value
        $convo.messages += @{
            role = $role
            message = $message
            timestamp = (Get-Date).ToString("o")
        }
        if ($convo.messages.Count -gt 100) {
            $convo.messages = $convo.messages[-100..-1]
        }
        $this.Telemetry?.IncrementCounter("memory.conversations_stored", 1)
        $this.AutoSave()
    }
    
    [array] GetConversation() {
        $convoKey = "convo_$(Get-Date -Format 'yyyyMMdd')"
        if ($this.Memories.ContainsKey($convoKey)) {
            return $this.Memories[$convoKey].value.messages
        }
        return @()
    }
    
    [void] RememberPreference([string]$name, [object]$value) {
        $this.Remember("pref_$name", $value, "preference")
        $this.Telemetry?.IncrementCounter("memory.preferences_stored", 1, @{name=$name})
    }
    
    [object] GetPreference([string]$name) {
        return $this.Recall("pref_$name")
    }
    
    [void] AutoSave() {
        if ((Get-Date) - $this.LastSave -gt [timespan]::FromMinutes(5)) {
            $this.SaveData()
        }
    }
    
    [void] ExportMemories([string]$filePath) {
        $export = @{
            exportedAt = (Get-Date).ToString("o")
            memories = $this.Memories
            patterns = $this.Patterns
        }
        $export | ConvertTo-Json -Depth 10 | Set-Content -Path $filePath
    }
    
    [void] ImportMemories([string]$filePath) {
        try {
            $import = Get-Content $filePath -Raw | ConvertFrom-Json
            if ($import.memories) {
                foreach ($prop in $import.memories.PSObject.Properties) {
                    $this.Memories[$prop.Name] = $prop.Value
                }
            }
            if ($import.patterns) {
                foreach ($prop in $import.patterns.PSObject.Properties) {
                    $this.Patterns[$prop.Name] = $prop.Value
                }
            }
            $this.SaveData()
            $this.Telemetry?.IncrementCounter("memory.imports", 1)
        } catch {
            Write-Host "Failed to import memories: $($_.Exception.Message)"
        }
    }
    
    [void] ClearMemories() {
        $this.Memories = @{}
        $this.Patterns = @{}
        $this.SaveData()
        $this.Telemetry?.IncrementCounter("memory.cleared", 1)
    }
    
    [hashtable] GetStats() {
        $categories = @{}
        foreach ($mem in $this.Memories.Values) {
            $cat = $mem.category
            if (-not $categories.ContainsKey($cat)) {
                $categories[$cat] = 0
            }
            $categories[$cat]++
        }
        return @{
            totalMemories = $this.Memories.Count
            totalPatterns = $this.Patterns.Count
            categories = $categories
            lastSave = $this.LastSave.ToString("o")
        }
    }
}

$gooseMemory = $null

function Get-GooseMemory {
    param([object]$Telemetry = $null)
    if ($script:gooseMemory -eq $null) {
        $script:gooseMemory = [GooseMemory]::new("config.ini", $Telemetry)
    }
    return $script:gooseMemory
}

function Remember-Goose {
    param([string]$Key, [object]$Value, [string]$Category = "general")
    $memory = Get-GooseMemory
    $memory.Remember($Key, $Value, $Category)
}

function Recall-Goose {
    param([string]$Key)
    $memory = Get-GooseMemory
    return $memory.Recall($Key)
}

function Show-GooseMemory {
    $memory = Get-GooseMemory
    $stats = $memory.GetStats()
    Add-Type -AssemblyName System.Windows.Forms
    [System.Windows.Forms.MessageBox]::Show(
        "Goose Memory Stats:`n`nTotal Memories: $($stats.totalMemories)`nTotal Patterns: $($stats.totalPatterns)",
        "Goose Memory",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Information
    )
}

Write-Host "Goose Memory Module Initialized"
