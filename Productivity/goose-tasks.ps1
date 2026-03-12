$LoggingScriptPath = Join-Path $PSScriptRoot "..\Core\GooseLogging.ps1"
if (Test-Path $LoggingScriptPath) {
    . $LoggingScriptPath
}

class GooseTasks {
    [hashtable]$Config
    [hashtable]$Tasks
    [hashtable]$Notes
    [int]$TaskIdCounter
    
    GooseTasks() {
        $this.Config = $this.LoadConfig()
        $this.Tasks = @{}
        $this.Notes = @{}
        $this.TaskIdCounter = 1
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
                    } elseif ($value -match '^\d+\.\d+$') {
                        $this.Config[$key] = [double]$value
                    } else {
                        $this.Config[$key] = $value
                    }
                }
            }
        }
        
        if (-not $this.Config.ContainsKey("TasksEnabled")) {
            $this.Config["TasksEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] LoadData() {
        $dataFile = "goose_tasks.json"
        
        if (Test-Path $dataFile) {
            try {
                $data = Get-Content $dataFile -Raw | ConvertFrom-Json
                $this.Tasks = @{}
                $this.Notes = @{}
                
                if ($data.Tasks) {
                    $data.Tasks.PSObject.Properties | ForEach-Object {
                        $this.Tasks[$_.Name] = $_.Value
                    }
                }
                
                if ($data.Notes) {
                    $data.Notes.PSObject.Properties | ForEach-Object {
                        $this.Notes[$_.Name] = $_.Value
                    }
                }
                
                if ($data.TaskIdCounter) {
                    $this.TaskIdCounter = $data.TaskIdCounter
                }
            } catch {}
        }
    }
    
    [void] SaveData() {
        $data = @{
            "Tasks" = $this.Tasks
            "Notes" = $this.Notes
            "TaskIdCounter" = $this.TaskIdCounter
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content "goose_tasks.json"
    }
    
    [int] AddTask([string]$title, [string]$priority = "normal", [datetime]$dueDate = $null) {
        $taskId = $this.TaskIdCounter++
        
        $task = @{
            "Id" = $taskId
            "Title" = $title
            "Priority" = $priority
            "Completed" = $false
            "CreatedAt" = (Get-Date).ToString("o")
            "CompletedAt" = $null
            "DueDate" = if ($dueDate) { $dueDate.ToString("o") } else { $null }
        }
        
        $this.Tasks[$taskId.ToString()] = $task
        $this.SaveData()
        
        return $taskId
    }
    
    [bool] CompleteTask([int]$taskId) {
        $taskKey = $taskId.ToString()
        
        if ($this.Tasks.ContainsKey($taskKey)) {
            $this.Tasks[$taskKey].Completed = $true
            $this.Tasks[$taskKey].CompletedAt = (Get-Date).ToString("o")
            $this.SaveData()
            return $true
        }
        
        return $false
    }
    
    [bool] DeleteTask([int]$taskId) {
        $taskKey = $taskId.ToString()
        
        if ($this.Tasks.ContainsKey($taskKey)) {
            $this.Tasks.Remove($taskKey)
            $this.SaveData()
            return $true
        }
        
        return $false
    }
    
    [hashtable] GetTask([int]$taskId) {
        $taskKey = $taskId.ToString()
        
        if ($this.Tasks.ContainsKey($taskKey)) {
            return $this.Tasks[$taskKey]
        }
        
        return $null
    }
    
    [hashtable[]] GetAllTasks([bool]$includeCompleted = $true) {
        $taskList = @()
        
        foreach ($task in $this.Tasks.Values) {
            if ($includeCompleted -or -not $task.Completed) {
                $taskList += $task
            }
        }
        
        return $taskList | Sort-Object { $_.Priority }, { $_.CreatedAt }
    }
    
    [hashtable[]] GetPendingTasks() {
        return $this.GetAllTasks($false)
    }
    
    [hashtable[]] GetOverdueTasks() {
        $overdue = @()
        $now = Get-Date
        
        foreach ($task in $this.Tasks.Values) {
            if (-not $task.Completed -and $task.DueDate) {
                $due = [datetime]::Parse($task.DueDate)
                if ($due -lt $now) {
                    $overdue += $task
                }
            }
        }
        
        return $overdue
    }
    
    [int] AddNote([string]$title, [string]$content) {
        $noteId = (Get-Date).ToString("yyyyMMddHHmmss")
        
        $note = @{
            "Id" = $noteId
            "Title" = $title
            "Content" = $content
            "CreatedAt" = (Get-Date).ToString("o")
            "UpdatedAt" = (Get-Date).ToString("o")
        }
        
        $this.Notes[$noteId] = $note
        $this.SaveData()
        
        return $noteId
    }
    
    [bool] UpdateNote([string]$noteId, [string]$content) {
        if ($this.Notes.ContainsKey($noteId)) {
            $this.Notes[$noteId].Content = $content
            $this.Notes[$noteId].UpdatedAt = (Get-Date).ToString("o")
            $this.SaveData()
            return $true
        }
        
        return $false
    }
    
    [bool] DeleteNote([string]$noteId) {
        if ($this.Notes.ContainsKey($noteId)) {
            $this.Notes.Remove($noteId)
            $this.SaveData()
            return $true
        }
        
        return $false
    }
    
    [hashtable[]] GetAllNotes() {
        return @($this.Notes.Values) | Sort-Object { $_.UpdatedAt } -Descending
    }
    
    [hashtable] GetTaskStats() {
        $total = $this.Tasks.Count
        $completed = (@($this.Tasks.Values) | Where-Object { $_.Completed }).Count
        $pending = $total - $completed
        $overdue = $this.GetOverdueTasks().Count
        
        return @{
            "Total" = $total
            "Completed" = $completed
            "Pending" = $pending
            "Overdue" = $overdue
            "CompletionRate" = if ($total -gt 0) { [Math]::Round(($completed / $total) * 100, 1) } else { 0 }
        }
    }
    
    [string] GetReminderMessage() {
        $pending = $this.GetPendingTasks()
        
        if ($pending.Count -eq 0) {
            return "You have no pending tasks! Great job!"
        }
        
        $urgent = $pending | Where-Object { $_.Priority -eq "high" }
        
        if ($urgent.Count -gt 0) {
            return "You have $($urgent.Count) important task(s) to do!"
        }
        
        return "You have $($pending.Count) pending task(s)."
    }
    
    [hashtable] GetTasksState() {
        return @{
            "Enabled" = $this.Config["TasksEnabled"]
            "Tasks" = $this.GetAllTasks()
            "PendingTasks" = $this.GetPendingTasks()
            "OverdueTasks" = $this.GetOverdueTasks()
            "Notes" = $this.GetAllNotes()
            "Stats" = $this.GetTaskStats()
            "ReminderMessage" = $this.GetReminderMessage()
        }
    }
}

$gooseTasks = [GooseTasks]::new()

function Get-GooseTasks {
    return $gooseTasks
}

function Add-Task {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [string]$Priority = "normal",
        [datetime]$DueDate = $null,
        $Tasks = $gooseTasks
    )
    return $Tasks.AddTask($Title, $Priority, $DueDate)
}

function Complete-Task {
    param(
        [Parameter(Mandatory=$true)]
        [int]$TaskId,
        $Tasks = $gooseTasks
    )
    return $Tasks.CompleteTask($TaskId)
}

function Get-TasksList {
    param(
        [bool]$IncludeCompleted = $true,
        $Tasks = $gooseTasks
    )
    return $Tasks.GetAllTasks($IncludeCompleted)
}

function Add-Note {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [Parameter(Mandatory=$true)]
        [string]$Content,
        $Tasks = $gooseTasks
    )
    return $Tasks.AddNote($Title, $Content)
}

function Get-TasksStatus {
    param($Tasks = $gooseTasks)
    return $Tasks.GetTasksState()
}

Write-Host "Desktop Goose Tasks System Initialized"
Write-LogInfo -Message "Tasks System Initialized" -Source "GooseTasks"
$state = Get-TasksStatus
Write-Host "Tasks Enabled: $($state['Enabled'])"
Write-Host "Pending Tasks: $($state['Stats']['Pending'])"
Write-LogInfo -Message "Tasks Enabled: $($state['Enabled']), Pending: $($state['Stats']['Pending'])" -Source "GooseTasks"
