# Desktop Goose Task Integration System
# Sync tasks with external providers (Todoist, Microsoft To-Do, Google Tasks)

class GooseTaskIntegration {
    [hashtable]$Config
    [string]$Provider
    [string]$ApiKey
    [bool]$IsEnabled
    [bool]$AutoSync
    [int]$SyncIntervalMinutes
    [datetime]$LastSync
    [hashtable]$TaskCache
    [hashtable]$SyncHistory
    
    GooseTaskIntegration() {
        $this.Config = $this.LoadConfig()
        $this.Provider = "none"
        $this.ApiKey = ""
        $this.IsEnabled = $false
        $this.AutoSync = $false
        $this.SyncIntervalMinutes = 15
        $this.LastSync = Get-Date
        $this.TaskCache = @{}
        $this.SyncHistory = @{}
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
        
        if (-not $this.Config.ContainsKey("TaskIntegrationEnabled")) {
            $this.Config["TaskIntegrationEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("TaskProvider")) {
            $this.Config["TaskProvider"] = "none"
        }
        if (-not $this.Config.ContainsKey("TaskApiKey")) {
            $this.Config["TaskApiKey"] = ""
        }
        if (-not $this.Config.ContainsKey("TaskAutoSync")) {
            $this.Config["TaskAutoSync"] = $false
        }
        if (-not $this.Config.ContainsKey("TaskSyncIntervalMinutes")) {
            $this.Config["TaskSyncIntervalMinutes"] = 15
        }
        
        return $this.Config
    }
    
    [void] LoadData() {
        $dataFile = "goose_taskintegration.json"
        
        if (Test-Path $dataFile) {
            try {
                $data = Get-Content $dataFile -Raw | ConvertFrom-Json
                
                if ($data.taskCache) {
                    $this.TaskCache = @{}
                    $data.taskCache.PSObject.Properties | ForEach-Object {
                        $this.TaskCache[$_.Name] = $_.Value
                    }
                }
                
                if ($data.syncHistory) {
                    $this.SyncHistory = @{}
                    $data.syncHistory.PSObject.Properties | ForEach-Object {
                        $this.SyncHistory[$_.Name] = $_.Value
                    }
                }
                
                if ($data.lastSync) {
                    $this.LastSync = [datetime]::Parse($data.lastSync)
                }
            } catch {}
        }
        
        $this.IsEnabled = $this.Config["TaskIntegrationEnabled"]
        $this.Provider = $this.Config["TaskProvider"]
        $this.ApiKey = $this.Config["TaskApiKey"]
        $this.AutoSync = $this.Config["TaskAutoSync"]
        $this.SyncIntervalMinutes = $this.Config["TaskSyncIntervalMinutes"]
    }
    
    [void] SaveData() {
        $data = @{
            "taskCache" = $this.TaskCache
            "syncHistory" = $this.SyncHistory
            "lastSync" = $this.LastSync.ToString("o")
            "settings" = @{
                "provider" = $this.Provider
                "autoSync" = $this.AutoSync
                "syncIntervalMinutes" = $this.SyncIntervalMinutes
            }
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content "goose_taskintegration.json"
    }
    
    [void] SetProvider([string]$provider) {
        $validProviders = @("none", "todoist", "microsoft", "google")
        if ($validProviders -contains $provider) {
            $this.Provider = $provider
            $this.Config["TaskProvider"] = $provider
            $this.TaskCache = @{}
            $this.SaveData()
        }
    }
    
    [void] SetApiKey([string]$apiKey) {
        $this.ApiKey = $apiKey
        $this.Config["TaskApiKey"] = $apiKey
    }
    
    [hashtable] FetchFromTodoist() {
        $result = @{
            "success" = $false
            "tasks" = @()
            "message" = ""
        }
        
        if ([string]::IsNullOrEmpty($this.ApiKey)) {
            $result.message = "API key not configured"
            return $result
        }
        
        try {
            $headers = @{
                "Authorization" = "Bearer $($this.ApiKey)"
                "Content-Type" = "application/json"
            }
            
            $response = Invoke-RestMethod -Uri "https://api.todoist.com/rest/v2/tasks" -Headers $headers -Method Get
            
            $tasks = @()
            foreach ($task in $response) {
                $tasks += @{
                    "id" = $task.id
                    "title" = $task.content
                    "description" = $task.description
                    "completed" = $task.is_completed
                    "dueDate" = if ($task.due) { $task.due.datetime } else { $null }
                    "priority" = $task.priority
                    "projectId" = $task.project_id
                    "provider" = "todoist"
                }
            }
            
            $result.success = $true
            $result.tasks = $tasks
            $result.message = "Fetched $($tasks.Count) tasks from Todoist"
            
        } catch {
            $result.message = "Error: $($_.Exception.Message)"
        }
        
        return $result
    }
    
    [hashtable] FetchFromMicrosoft() {
        $result = @{
            "success" = $false
            "tasks" = @()
            "message" = ""
        }
        
        if ([string]::IsNullOrEmpty($this.ApiKey)) {
            $result.message = "API key not configured"
            return $result
        }
        
        try {
            $headers = @{
                "Authorization" = "Bearer $($this.ApiKey)"
                "Content-Type" = "application/json"
            }
            
            $response = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/todo/lists" -Headers $headers -Method Get
            
            $tasks = @()
            foreach ($list in $response.value) {
                $tasksResponse = Invoke-RestMethod -Uri "https://graph.microsoft.com/v1.0/me/todo/lists/$($list.id)/tasks" -Headers $headers -Method Get
                
                foreach ($task in $tasksResponse.value) {
                    $tasks += @{
                        "id" = $task.id
                        "title" = $task.title
                        "description" = $task.body.content
                        "completed" = $task.completedDateTime -ne $null
                        "dueDate" = if ($task.dueDateTime) { $task.dueDateTime.dateTime } else { $null }
                        "priority" = switch ($task.importance) {
                            "high" { 4 }
                            "normal" { 3 }
                            "low" { 1 }
                            default { 2 }
                        }
                        "listId" = $task.parentListId
                        "provider" = "microsoft"
                    }
                }
            }
            
            $result.success = $true
            $result.tasks = $tasks
            $result.message = "Fetched $($tasks.Count) tasks from Microsoft To-Do"
            
        } catch {
            $result.message = "Error: $($_.Exception.Message)"
        }
        
        return $result
    }
    
    [hashtable] FetchFromGoogle() {
        $result = @{
            "success" = $false
            "tasks" = @()
            "message" = ""
        }
        
        if ([string]::IsNullOrEmpty($this.ApiKey)) {
            $result.message = "API key not configured"
            return $result
        }
        
        try {
            $headers = @{
                "Authorization" = "Bearer $($this.ApiKey)"
                "Content-Type" = "application/json"
            }
            
            $response = Invoke-RestMethod -Uri "https://tasks.googleapis.com/tasks/v1/users/@me/lists" -Headers $headers -Method Get
            
            $tasks = @()
            foreach ($list in $response.items) {
                $tasksResponse = Invoke-RestMethod -Uri "https://tasks.googleapis.com/tasks/v1/lists/$($list.id)/tasks" -Headers $headers -Method Get
                
                if ($tasksResponse.items) {
                    foreach ($task in $tasksResponse.items) {
                        $tasks += @{
                            "id" = $task.id
                            "title" = $task.title
                            "description" = $task.notes
                            "completed" = $task.status -eq "completed"
                            "dueDate" = $task.due
                            "priority" = switch ($task.priority) {
                                "high" { 4 }
                                "medium" { 3 }
                                "low" { 1 }
                                default { 2 }
                            }
                            "listId" = $task.tasklist
                            "provider" = "google"
                        }
                    }
                }
            }
            
            $result.success = $true
            $result.tasks = $tasks
            $result.message = "Fetched $($tasks.Count) tasks from Google Tasks"
            
        } catch {
            $result.message = "Error: $($_.Exception.Message)"
        }
        
        return $result
    }
    
    [hashtable] FetchTasks() {
        if ($this.Provider -eq "todoist") {
            return $this.FetchFromTodoist()
        } elseif ($this.Provider -eq "microsoft") {
            return $this.FetchFromMicrosoft()
        } elseif ($this.Provider -eq "google") {
            return $this.FetchFromGoogle()
        }
        return @{
            "success" = $false
            "tasks" = @()
            "message" = "No provider configured"
        }
    }
    
    [hashtable] SyncTasks() {
        $fetchResult = $this.FetchTasks()
        
        if ($fetchResult.success) {
            $this.TaskCache = @{}
            foreach ($task in $fetchResult.tasks) {
                $this.TaskCache[$task.id] = $task
            }
            
            $this.LastSync = Get-Date
            $this.RecordSync("success", $fetchResult.message)
            $this.SaveData()
        } else {
            $this.RecordSync("failed", $fetchResult.message)
        }
        
        return $fetchResult
    }
    
    [void] RecordSync([string]$status, [string]$message) {
        $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm")
        
        $this.SyncHistory[$timestamp] = @{
            "timestamp" = (Get-Date).ToString("o")
            "status" = $status
            "message" = $message
            "provider" = $this.Provider
        }
        
        if ($this.SyncHistory.Count -gt 100) {
            $keys = $this.SyncHistory.Keys | Sort-Object
            $keysToRemove = $keys[0..($keys.Count - 101)]
            foreach ($key in $keysToRemove) {
                $this.SyncHistory.Remove($key)
            }
        }
    }
    
    [hashtable[]] GetCachedTasks([bool]$includeCompleted = $true) {
        $tasks = @()
        
        foreach ($task in $this.TaskCache.Values) {
            if ($includeCompleted -or -not $task.completed) {
                $tasks += $task
            }
        }
        
        return $tasks
    }
    
    [hashtable[]] GetPendingTasks() {
        return $this.GetCachedTasks($false)
    }
    
    [hashtable[]] GetOverdueTasks() {
        $overdue = @()
        $now = Get-Date
        
        foreach ($task in $this.TaskCache.Values) {
            if (-not $task.completed -and $task.dueDate) {
                $due = if ($task.dueDate -is [string]) { [datetime]::Parse($task.dueDate) } else { $task.dueDate }
                if ($due -lt $now) {
                    $overdue += $task
                }
            }
        }
        
        return $overdue
    }
    
    [hashtable[]] GetTasksByProject([string]$projectId) {
        $tasks = @()
        
        foreach ($task in $this.TaskCache.Values) {
            if ($task.projectId -eq $projectId -or $task.listId -eq $projectId) {
                $tasks += $task
            }
        }
        
        return $tasks
    }
    
    [hashtable] GetStats() {
        $total = $this.TaskCache.Count
        $completed = (@($this.TaskCache.Values) | Where-Object { $_.completed }).Count
        $pending = $total - $completed
        $overdue = $this.GetOverdueTasks().Count
        
        return @{
            "totalTasks" = $total
            "completedTasks" = $completed
            "pendingTasks" = $pending
            "overdueTasks" = $overdue
            "completionRate" = if ($total -gt 0) { [Math]::Round(($completed / $total) * 100, 1) } else { 0 }
        }
    }
    
    [hashtable[]] GetRecentSyncHistory([int]$count = 10) {
        $history = @()
        $keys = $this.SyncHistory.Keys | Sort-Object -Descending
        
        foreach ($key in $keys | Select-Object -First $count) {
            $history += $this.SyncHistory[$key]
        }
        
        return $history
    }
    
    [bool] ShouldSync() {
        if (-not $this.AutoSync -or $this.Provider -eq "none") {
            return $false
        }
        
        $timeSinceSync = (Get-Date) - $this.LastSync
        return $timeSinceSync.TotalMinutes -ge $this.SyncIntervalMinutes
    }
    
    [void] SetEnabled([bool]$enabled) {
        $this.IsEnabled = $enabled
        $this.Config["TaskIntegrationEnabled"] = $enabled
    }
    
    [void] SetAutoSync([bool]$autoSync) {
        $this.AutoSync = $autoSync
        $this.Config["TaskAutoSync"] = $autoSync
    }
    
    [void] Toggle() {
        $this.IsEnabled = -not $this.IsEnabled
        $this.Config["TaskIntegrationEnabled"] = $this.IsEnabled
    }
    
    [hashtable] GetTaskIntegrationState() {
        return @{
            "Enabled" = $this.IsEnabled
            "Provider" = $this.Provider
            "ApiKeyConfigured" = -not [string]::IsNullOrEmpty($this.ApiKey)
            "AutoSync" = $this.AutoSync
            "SyncIntervalMinutes" = $this.SyncIntervalMinutes
            "LastSync" = $this.LastSync
            "ShouldSync" = $this.ShouldSync()
            "CachedTasks" = $this.GetCachedTasks($true)
            "PendingTasks" = $this.GetPendingTasks()
            "OverdueTasks" = $this.GetOverdueTasks()
            "Stats" = $this.GetStats()
            "SyncHistory" = $this.GetRecentSyncHistory(10)
        }
    }
}

$gooseTaskIntegration = [GooseTaskIntegration]::new()

function Get-GooseTaskIntegration {
    return $gooseTaskIntegration
}

function Set-TaskProvider {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Provider,
        $Integration = $gooseTaskIntegration
    )
    $Integration.SetProvider($Provider)
}

function Set-TaskApiKey {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ApiKey,
        $Integration = $gooseTaskIntegration
    )
    $Integration.SetApiKey($ApiKey)
}

function Sync-Tasks {
    param($Integration = $gooseTaskIntegration)
    return $Integration.SyncTasks()
}

function Fetch-Tasks {
    param($Integration = $gooseTaskIntegration)
    return $Integration.FetchTasks()
}

function Get-CachedTasks {
    param(
        [bool]$IncludeCompleted = $true,
        $Integration = $gooseTaskIntegration
    )
    return $Integration.GetCachedTasks($IncludeCompleted)
}

function Get-PendingTasks {
    param($Integration = $gooseTaskIntegration)
    return $Integration.GetPendingTasks()
}

function Get-OverdueTasks {
    param($Integration = $gooseTaskIntegration)
    return $Integration.GetOverdueTasks()
}

function Get-TaskIntegrationStats {
    param($Integration = $gooseTaskIntegration)
    return $Integration.GetStats()
}

function Get-SyncHistory {
    param(
        [int]$Count = 10,
        $Integration = $gooseTaskIntegration
    )
    return $Integration.GetRecentSyncHistory($Count)
}

function Enable-TaskIntegration {
    param($Integration = $gooseTaskIntegration)
    $Integration.SetEnabled($true)
}

function Disable-TaskIntegration {
    param($Integration = $gooseTaskIntegration)
    $Integration.SetEnabled($false)
}

function Enable-TaskAutoSync {
    param($Integration = $gooseTaskIntegration)
    $Integration.SetAutoSync($true)
}

function Disable-TaskAutoSync {
    param($Integration = $gooseTaskIntegration)
    $Integration.SetAutoSync($false)
}

function Toggle-TaskIntegration {
    param($Integration = $gooseTaskIntegration)
    $Integration.Toggle()
}

function Get-TaskIntegrationState {
    param($Integration = $gooseTaskIntegration)
    return $Integration.GetTaskIntegrationState()
}

Write-Host "Desktop Goose Task Integration System Initialized"
$state = Get-TaskIntegrationState
Write-Host "Task Integration Enabled: $($state['Enabled'])"
Write-Host "Provider: $($state['Provider'])"
Write-Host "Cached Tasks: $($state['Stats']['totalTasks'])"
