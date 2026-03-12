# Desktop Goose Cloud Sync Module
# Supabase Self-Hosted Integration
# Provides offline-first sync with conflict resolution

$LoggingScriptPath = Join-Path $PSScriptRoot "..\Core\GooseLogging.ps1"
if (Test-Path $LoggingScriptPath) {
    . $LoggingScriptPath
}

enum SyncStatus {
    Idle
    Syncing
    Success
    Error
    Offline
}

enum SyncDirection {
    Push
    Pull
    Bidirectional
}

class SyncQueueItem {
    [string]$Id
    [string]$DataType
    [string]$Operation  # Create, Update, Delete
    [object]$Data
    [datetime]$Timestamp
    [int]$RetryCount
    [string]$Error

    SyncQueueItem([string]$dataType, [string]$operation, [object]$data) {
        $this.Id = [guid]::NewGuid().ToString()
        $this.DataType = $dataType
        $this.Operation = $operation
        $this.Data = $data
        $this.Timestamp = Get-Date
        $this.RetryCount = 0
        $this.Error = $null
    }
}

class GooseSyncClient {
    [hashtable]$Config
    [string]$SupabaseUrl
    [string]$SupabaseAnonKey
    [string]$SupabaseServiceKey
    [string]$DeviceId
    [string]$DeviceName
    [bool]$IsEnabled
    [bool]$IsOnline
    [SyncStatus]$Status
    [datetime]$LastSync
    [System.Collections.ArrayList]$SyncQueue
    [System.Collections.ArrayList]$PendingChanges
    [object]$SyncTimer
    
    GooseSyncClient() {
        $this.Config = $this.LoadConfig()
        $this.SupabaseUrl = $this.Config["SupabaseUrl"]
        $this.SupabaseAnonKey = $this.Config["SupabaseAnonKey"]
        $this.SupabaseServiceKey = $this.Config["SupabaseServiceKey"]
        $this.DeviceName = $this.Config["DeviceName"]
        $this.IsEnabled = $this.Config["CloudSyncEnabled"]
        $this.IsOnline = $false
        $this.Status = [SyncStatus]::Idle
        $this.LastSync = $null
        $this.SyncQueue = New-Object System.Collections.ArrayList
        $this.PendingChanges = New-Object System.Collections.ArrayList
        
        $this.InitializeDeviceId()
        $this.LoadPendingChanges()
        
        if ($this.IsEnabled) {
            $this.TestConnection()
            $this.StartAutoSync()
        }
    }
    
    [hashtable] LoadConfig() {
        $config = @{}
        $configFile = "config.ini"
        
        if (Test-Path $configFile) {
            Get-Content $configFile | ForEach-Object {
                if ($_ -match '^([^=]+)=(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    
                    if ($value -eq 'True' -or $value -eq 'False') {
                        $config[$key] = [bool]$value
                    } elseif ($value -match '^\d+$') {
                        $config[$key] = [int]$value
                    } elseif ($value -match '^\d+\.\d+$') {
                        $config[$key] = [double]$value
                    } else {
                        $config[$key] = $value
                    }
                }
            }
        }
        
        if (-not $config.ContainsKey("CloudSyncEnabled")) { $config["CloudSyncEnabled"] = $false }
        if (-not $config.ContainsKey("SyncIntervalMinutes")) { $config["SyncIntervalMinutes"] = 5 }
        if (-not $config.ContainsKey("SyncOnStartup")) { $config["SyncOnStartup"] = $false }
        if (-not $config.ContainsKey("AutoSync")) { $config["AutoSync"] = $true }
        if (-not $config.ContainsKey("DeviceName")) { $config["DeviceName"] = "Desktop-Goose" }
        
        return $config
    }
    
    [void] InitializeDeviceId() {
        $deviceIdFile = "goose_device.id"
        
        if (Test-Path $deviceIdFile) {
            $this.DeviceId = Get-Content $deviceIdFile -Raw
        } else {
            $this.DeviceId = [guid]::NewGuid().ToString()
            $this.DeviceId | Set-Content $deviceIdFile
        }
        
        if ($this.Config["DeviceId"] -and $this.Config["DeviceId"] -ne "") {
            $this.DeviceId = $this.Config["DeviceId"]
        }
    }
    
    [bool] TestConnection() {
        try {
            $response = Invoke-RestMethod -Uri "$($this.SupabaseUrl)/rest/v1/" `
                -Headers @{
                    "apikey" = $this.SupabaseAnonKey
                    "Authorization" = "Bearer $($this.SupabaseAnonKey)"
                } `
                -Method GET `
                -TimeoutSec 10
            
            $this.IsOnline = $true
            $this.Status = [SyncStatus]::Idle
            return $true
        } catch {
            $this.IsOnline = $false
            $this.Status = [SyncStatus]::Offline
            return $false
        }
    }
    
    [void] StartAutoSync() {
        if (-not $this.Config["AutoSync"]) { return }
        
        $intervalMs = $this.Config["SyncIntervalMinutes"] * 60 * 1000
        
        $scriptBlock = {
            param($syncClient)
            $syncClient.SyncAll()
        }
        
        $this.SyncTimer = New-Object System.Timers.Timer
        $this.SyncTimer.Interval = $intervalMs
        $this.SyncTimer.AutoReset = $true
        $this.SyncTimer.Elapsed.Add({ param($s, $e) $this.SyncAll() })
        $this.SyncTimer.Start()
    }
    
    [void] StopAutoSync() {
        if ($this.SyncTimer) {
            $this.SyncTimer.Stop()
            $this.SyncTimer.Dispose()
        }
    }
    
    [hashtable] QueueChange([string]$dataType, [string]$operation, [object]$data) {
        $item = [SyncQueueItem]::new($dataType, $operation, $data)
        $this.SyncQueue.Add($item)
        $this.SavePendingChanges()
        
        if ($this.IsOnline -and $this.Config["AutoSync"]) {
            $this.ProcessSyncQueue()
        }
        
        return @{
            "Success" = $true
            "Queued" = $true
            "ItemId" = $item.Id
            "QueueSize" = $this.SyncQueue.Count
        }
    }
    
    [void] ProcessSyncQueue() {
        if (-not $this.IsOnline) {
            $this.Status = [SyncStatus]::Offline
            return
        }
        
        if ($this.SyncQueue.Count -eq 0) { return }
        
        $this.Status = [SyncStatus]::Syncing
        
        $processedItems = @()
        
        foreach ($item in $this.SyncQueue) {
            try {
                $success = $this.ProcessQueueItem($item)
                
                if ($success) {
                    $processedItems += $item.Id
                } else {
                    $item.RetryCount++
                    if ($item.RetryCount -ge 3) {
                        $item.Error = "Max retries exceeded"
                        $processedItems += $item.Id
                    }
                }
            } catch {
                $item.Error = $_.Exception.Message
                $item.RetryCount++
            }
        }
        
        foreach ($id in $processedItems) {
            $this.SyncQueue = $this.SyncQueue | Where-Object { $_.Id -ne $id }
        }
        
        $this.SavePendingChanges()
        
        if ($this.SyncQueue.Count -eq 0) {
            $this.Status = [SyncStatus]::Success
            $this.LastSync = Get-Date
        } else {
            $this.Status = [SyncStatus]::Error
        }
    }
    
    [bool] ProcessQueueItem([SyncQueueItem]$item) {
        $endpoint = "$($this.SupabaseUrl)/rest/v1/sync_data"
        
        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseServiceKey)"
            "Content-Type" = "application/json"
            "Prefer" = "return=minimal"
        }
        
        switch ($item.Operation) {
            "Create" {
                $body = @{
                    "user_id" = $this.DeviceId
                    "device_id" = $this.DeviceId
                    "data_type" = $item.DataType
                    "data" = ($item.Data | ConvertTo-Json -Compress)
                    "local_modified" = $item.Timestamp.ToString("o")
                    "server_modified" = (Get-Date).ToString("o")
                } | ConvertTo-Json
                
                try {
                    Invoke-RestMethod -Uri $endpoint -Headers $headers -Method POST -Body $body | Out-Null
                    return $true
                } catch {
                    return $false
                }
            }
            "Update" {
                $existing = $this.GetRemoteData($item.DataType)
                
                if ($existing) {
                    $headers["Prefer"] = "return=minimal"
                    $body = @{
                        "data" = ($item.Data | ConvertTo-Json -Compress)
                        "local_modified" = $item.Timestamp.ToString("o")
                        "server_modified" = (Get-Date).ToString("o")
                    } | ConvertTo-Json
                    
                    try {
                        Invoke-RestMethod -Uri "$endpoint?user_id=eq.$($this.DeviceId)&data_type=eq.$($item.DataType)" `
                            -Headers $headers -Method PATCH -Body $body | Out-Null
                        return $true
                    } catch {
                        return $false
                    }
                } else {
                    return $this.ProcessQueueItem([SyncQueueItem]::new($item.DataType, "Create", $item.Data))
                }
            }
            "Delete" {
                try {
                    Invoke-RestMethod -Uri "$endpoint?user_id=eq.$($this.DeviceId)&data_type=eq.$($item.DataType)" `
                        -Headers $headers -Method DELETE | Out-Null
                    return $true
                } catch {
                    return $false
                }
            }
        }
        
        return $false
    }
    
    [object] GetRemoteData([string]$dataType) {
        $endpoint = "$($this.SupabaseUrl)/rest/v1/sync_data?user_id=eq.$($this.DeviceId)&data_type=eq.$($dataType)&select=data,local_modified,server_modified"
        
        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseAnonKey)"
        }
        
        try {
            $response = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method GET
            if ($response -and $response.Count -gt 0) {
                return @{
                    "Data" = $response[0].data | ConvertFrom-Json
                    "LocalModified" = $response[0].local_modified
                    "ServerModified" = $response[0].server_modified
                }
            }
        } catch {
            return $null
        }
        
        return $null
    }
    
    [hashtable] PullData([string]$dataType) {
        if (-not $this.IsOnline) {
            return @{
                "Success" = $false
                "Error" = "Offline"
                "Data" = $null
            }
        }
        
        $this.Status = [SyncStatus]::Syncing
        
        $remoteData = $this.GetRemoteData($dataType)
        
        if ($remoteData) {
            $localData = $this.GetLocalData($dataType)
            
            $resolved = $this.ResolveConflict($localData, $remoteData, $dataType)
            
            $this.Status = [SyncStatus]::Success
            $this.LastSync = Get-Date
            
            return @{
                "Success" = $true
                "Data" = $resolved
                "Source" = "remote"
            }
        }
        
        $this.Status = [SyncStatus]::Idle
        
        return @{
            "Success" = $true
            "Data" = $this.GetLocalData($dataType)
            "Source" = "local"
        }
    }
    
    [object] GetLocalData([string]$dataType) {
        $fileMap = @{
            "notes" = "goose_notes.json"
            "habits" = "goose_habits.json"
            "stats" = "goose_stats.json"
            "personality" = "goose_personality.json"
            "timetracking" = "goose_timetracking.json"
            "settings" = "config.ini"
        }
        
        $file = $fileMap[$dataType]
        
        if (-not $file) { return $null }
        
        if (Test-Path $file) {
            if ($file -eq "config.ini") {
                return $this.LoadConfig()
            } else {
                return Get-Content $file -Raw | ConvertFrom-Json
            }
        }
        
        return $null
    }
    
    [object] ResolveConflict([object]$local, [object]$remote, [string]$dataType) {
        if (-not $local) { return $remote.Data }
        if (-not $remote) { return $local }
        if (-not $remote.Data) { return $local }
        
        $localModified = if ($local.UpdatedAt) { [DateTime]::Parse($local.UpdatedAt) } else { Get-Date }
        if ($remote.LocalModified) { $remoteModified = [DateTime]::Parse($remote.LocalModified) } else { $remoteModified = [DateTime]::Parse($remote.ServerModified) }
        
        if ($localModified -gt $remoteModified) {
            return $local
        } else {
            return $remote.Data
        }
    }
    
    [void] SavePendingChanges() {
        $queueData = @()
        
        foreach ($item in $this.SyncQueue) {
            $queueData += @{
                "Id" = $item.Id
                "DataType" = $item.DataType
                "Operation" = $item.Operation
                "Data" = $item.Data
                "Timestamp" = $item.Timestamp.ToString("o")
                "RetryCount" = $item.RetryCount
                "Error" = $item.Error
            }
        }
        
        $queueData | ConvertTo-Json -Depth 10 | Set-Content "goose_sync_queue.json"
    }
    
    [void] LoadPendingChanges() {
        $queueFile = "goose_sync_queue.json"
        
        if (Test-Path $queueFile) {
            try {
                $queueData = Get-Content $queueFile -Raw | ConvertFrom-Json
                
                foreach ($item in $queueData) {
                    $queueItem = [SyncQueueItem]::new($item.DataType, $item.Operation, $item.Data)
                    $queueItem.Id = $item.Id
                    $queueItem.Timestamp = [DateTime]::Parse($item.Timestamp)
                    $queueItem.RetryCount = $item.RetryCount
                    $queueItem.Error = $item.Error
                    $this.SyncQueue.Add($queueItem)
                }
            } catch {
            }
        }
    }
    
    [hashtable] SyncAll() {
        $results = @{
            "Notes" = $null
            "Habits" = $null
            "Stats" = $null
            "Personality" = $null
            "Status" = $this.Status
            "LastSync" = $this.LastSync
        }
        
        if (-not $this.IsEnabled) {
            $results["Status"] = "Disabled"
            return $results
        }
        
        if (-not $this.TestConnection()) {
            $this.Status = [SyncStatus]::Offline
            $results["Status"] = "Offline"
            return $results
        }
        
        $this.ProcessSyncQueue()
        
        $dataTypes = @("notes", "habits", "stats", "personality")
        
        foreach ($type in $dataTypes) {
            $results[$type] = $this.PullData($type)
        }
        
        $this.Status = [SyncStatus]::Success
        $this.LastSync = Get-Date
        $results["Status"] = "Success"
        
        return $results
    }
    
    [hashtable] GetSyncStatus() {
        return @{
            "Enabled" = $this.IsEnabled
            "Online" = $this.IsOnline
            "Status" = $this.Status.ToString()
            "LastSync" = $this.LastSync
            "QueueSize" = $this.SyncQueue.Count
            "DeviceId" = $this.DeviceId
            "DeviceName" = $this.DeviceName
            "SupabaseUrl" = $this.SupabaseUrl
        }
    }
    
    [void] SetEnabled([bool]$enabled) {
        $this.IsEnabled = $enabled
        
        if ($enabled) {
            $this.TestConnection()
            $this.StartAutoSync()
        } else {
            $this.StopAutoSync()
        }
    }
    
    [void] ForceSyncNow() {
        if ($this.TestConnection()) {
            $this.SyncAll()
        }
    }
    
    [void] ClearQueue() {
        $this.SyncQueue.Clear()
        $this.SavePendingChanges()
    }
}

$gooseSyncClient = [GooseSyncClient]::new()

function Get-GooseSyncClient {
    return $gooseSyncClient
}

function Get-SyncStatus {
    param($Client = $gooseSyncClient)
    return $Client.GetSyncStatus()
}

function Sync-AllData {
    param($Client = $gooseSyncClient)
    return $Client.SyncAll()
}

function Queue-SyncChange {
    param(
        [Parameter(Mandatory=$true)]
        [string]$DataType,
        [Parameter(Mandatory=$true)]
        [string]$Operation,
        [Parameter(Mandatory=$true)]
        [object]$Data,
        $Client = $gooseSyncClient
    )
    return $Client.QueueChange($DataType, $Operation, $Data)
}

function Set-SyncEnabled {
    param(
        [Parameter(Mandatory=$true)]
        [bool]$Enabled,
        $Client = $gooseSyncClient
    )
    $Client.SetEnabled($Enabled)
}

function Test-SyncConnection {
    param($Client = $gooseSyncClient)
    return $Client.TestConnection()
}

function Clear-SyncQueue {
    param($Client = $gooseSyncClient)
    $Client.ClearQueue()
}

Write-Host "Desktop Goose Cloud Sync Module Initialized"
Write-LogInfo "Desktop Goose Cloud Sync Module Initialized"
$status = Get-SyncStatus
Write-Host "Sync Enabled: $($status['Enabled'])"
Write-LogInfo "Sync Enabled: $($status['Enabled'])"
Write-Host "Online: $($status['Online'])"
Write-LogInfo "Online: $($status['Online'])"
