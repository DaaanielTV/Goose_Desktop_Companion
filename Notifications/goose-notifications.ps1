# Desktop Goose Notifications & Events Module
# Provides push notifications, webhooks, scheduled tasks, and event logging

enum NotificationType {
    Push
    Webhook
    InApp
}

enum EventType {
    SyncStarted
    SyncCompleted
    SyncFailed
    HabitCompleted
    HabitStreak
    GoalAchieved
    ReportGenerated
    DeviceConnected
    DeviceDisconnected
}

enum TaskType {
    Reminder
    Backup
    Report
    HabitCheck
    Sync
}

enum TaskStatus {
    Pending
    Running
    Success
    Failed
}

class PushSubscription {
    [string]$Id
    [string]$Endpoint
    [string]$P256dh
    [string]$Auth
    [datetime]$SubscribedAt
    [datetime]$ExpiresAt
    [bool]$IsActive
}

class Webhook {
    [string]$Id
    [string]$Name
    [string]$Url
    [string[]]$Events
    [string]$Secret
    [bool]$Enabled
    [datetime]$LastTriggeredAt
    [int]$FailureCount
}

class ScheduledTask {
    [string]$Id
    [string]$TaskName
    [TaskType]$TaskType
    [string]$CronExpression
    [object]$Payload
    [bool]$Enabled
    [datetime]$LastRun
    [datetime]$NextRun
    [int]$RunCount
    [int]$FailureCount
}

class GooseNotificationsClient {
    [hashtable]$Config
    [string]$SupabaseUrl
    [string]$SupabaseAnonKey
    [string]$SupabaseServiceKey
    [string]$DeviceId
    [bool]$IsEnabled
    [bool]$IsOnline
    [System.Collections.ArrayList]$Webhooks
    [System.Collections.ArrayList]$ScheduledTasks

    GooseNotificationsClient() {
        $this.Config = $this.LoadConfig()
        $this.SupabaseUrl = $this.Config["SupabaseUrl"]
        $this.SupabaseAnonKey = $this.Config["SupabaseAnonKey"]
        $this.SupabaseServiceKey = $this.Config["SupabaseServiceKey"]
        $this.IsEnabled = $this.Config["NotificationsEnabled"]
        $this.IsOnline = $false
        $this.Webhooks = New-Object System.Collections.ArrayList
        $this.ScheduledTasks = New-Object System.Collections.ArrayList

        $this.InitializeDeviceId()

        if ($this.IsEnabled) {
            $this.TestConnection()
            $this.LoadWebhooks()
            $this.LoadScheduledTasks()
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

        if (-not $config.ContainsKey("NotificationsEnabled")) { $config["NotificationsEnabled"] = $false }
        if (-not $config.ContainsKey("WebPushEnabled")) { $config["WebPushEnabled"] = $false }

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
            return $true
        } catch {
            $this.IsOnline = $false
            return $false
        }
    }

    [void] LoadWebhooks() {
        if (-not $this.IsOnline) { return }

        $endpoint = "$($this.SupabaseUrl)/rest/v1/webhooks?user_id=eq.$($this.DeviceId)&select=*"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseAnonKey)"
        }

        try {
            $data = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method GET
            foreach ($wh in $data) {
                $webhook = [Webhook]::new()
                $webhook.Id = $wh.id
                $webhook.Name = $wh.name
                $webhook.Url = $wh.url
                $webhook.Events = $wh.events
                $webhook.Secret = $wh.secret
                $webhook.Enabled = $wh.enabled
                $webhook.LastTriggeredAt = $wh.last_triggered_at
                $webhook.FailureCount = $wh.failure_count
                $this.Webhooks.Add($webhook)
            }
        } catch {
        }
    }

    [void] LoadScheduledTasks() {
        if (-not $this.IsOnline) { return }

        $endpoint = "$($this.SupabaseUrl)/rest/v1/scheduled_tasks?user_id=eq.$($this.DeviceId)&enabled=eq.true&select=*"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseAnonKey)"
        }

        try {
            $data = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method GET
            foreach ($task in $data) {
                $t = [ScheduledTask]::new()
                $t.Id = $task.id
                $t.TaskName = $task.task_name
                $t.TaskType = $task.task_type
                $t.CronExpression = $task.cron_expression
                $t.Payload = $task.payload
                $t.Enabled = $task.enabled
                $t.LastRun = $task.last_run
                $t.NextRun = $task.next_run
                $t.RunCount = $task.run_count
                $t.FailureCount = $task.failure_count
                $this.ScheduledTasks.Add($t)
            }
        } catch {
        }
    }

    [hashtable] RegisterPushSubscription([string]$endpoint, [string]$p256dh, [string]$auth) {
        $dbEndpoint = "$($this.SupabaseUrl)/rest/v1/rpc/register_push_subscription"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseServiceKey)"
            "Content-Type" = "application/json"
        }

        $body = @{
            "p_user_id" = $this.DeviceId
            "p_device_id" = $this.DeviceId
            "p_endpoint" = $endpoint
            "p_p256dh" = $p256dh
            "p_auth" = $auth
        } | ConvertTo-Json

        try {
            $result = Invoke-RestMethod -Uri $dbEndpoint -Headers $headers -Method POST -Body $body
            return @{
                "Success" = $true
                "SubscriptionId" = $result
            }
        } catch {
            return @{
                "Success" = $false
                "Error" = $_.Exception.Message
            }
        }
    }

    [hashtable] AddWebhook([string]$name, [string]$url, [string[]]$events) {
        $endpoint = "$($this.SupabaseUrl)/rest/v1/webhooks"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseServiceKey)"
            "Content-Type" = "application/json"
            "Prefer" = "return=minimal"
        }

        $secret = [guid]::NewGuid().ToString()

        $body = @{
            "user_id" = $this.DeviceId
            "name" = $name
            "url" = $url
            "events" = $events
            "secret" = $secret
            "enabled" = $true
        } | ConvertTo-Json

        try {
            Invoke-RestMethod -Uri $endpoint -Headers $headers -Method POST -Body $body | Out-Null

            $webhook = [Webhook]::new()
            $webhook.Id = [guid]::NewGuid().ToString()
            $webhook.Name = $name
            $webhook.Url = $url
            $webhook.Events = $events
            $webhook.Secret = $secret
            $webhook.Enabled = $true
            $this.Webhooks.Add($webhook)

            return @{
                "Success" = $true
                "WebhookId" = $webhook.Id
                "Secret" = $secret
            }
        } catch {
            return @{
                "Success" = $false
                "Error" = $_.Exception.Message
            }
        }
    }

    [hashtable] RemoveWebhook([string]$webhookId) {
        $endpoint = "$($this.SupabaseUrl)/rest/v1/webhooks?id=eq.$($webhookId)"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseServiceKey)"
        }

        try {
            Invoke-RestMethod -Uri $endpoint -Headers $headers -Method DELETE | Out-Null

            $this.Webhooks = $this.Webhooks | Where-Object { $_.Id -ne $webhookId }

            return @{
                "Success" = $true
            }
        } catch {
            return @{
                "Success" = $false
                "Error" = $_.Exception.Message
            }
        }
    }

    [hashtable] CreateScheduledTask([string]$taskName, [TaskType]$taskType, [string]$cronExpression, [object]$payload) {
        $endpoint = "$($this.SupabaseUrl)/rest/v1/rpc/create_scheduled_task"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseServiceKey)"
            "Content-Type" = "application/json"
        }

        $body = @{
            "p_user_id" = $this.DeviceId
            "p_device_id" = $this.DeviceId
            "p_task_type" = $taskType.ToString().ToLower()
            "p_task_name" = $taskName
            "p_cron_expression" = $cronExpression
            "p_payload" = ($payload | ConvertTo-Json -Compress)
        } | ConvertTo-Json

        try {
            $result = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method POST -Body $body

            $task = [ScheduledTask]::new()
            $task.Id = $result
            $task.TaskName = $taskName
            $task.TaskType = $taskType
            $task.CronExpression = $cronExpression
            $task.Payload = $payload
            $task.Enabled = $true
            $this.ScheduledTasks.Add($task)

            return @{
                "Success" = $true
                "TaskId" = $result
            }
        } catch {
            return @{
                "Success" = $false
                "Error" = $_.Exception.Message
            }
        }
    }

    [hashtable] LogEvent([EventType]$eventType, [object]$payload) {
        $endpoint = "$($this.SupabaseUrl)/rest/v1/rpc/log_event"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseServiceKey)"
            "Content-Type" = "application/json"
        }

        $body = @{
            "p_user_id" = $this.DeviceId
            "p_device_id" = $this.DeviceId
            "p_event_type" = $eventType.ToString().ToLower()
            "p_event_source" = "client"
            "p_payload" = ($payload | ConvertTo-Json -Compress)
        } | ConvertTo-Json

        try {
            $result = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method POST -Body $body
            return @{
                "Success" = $true
                "EventId" = $result
            }
        } catch {
            return @{
                "Success" = $false
                "Error" = $_.Exception.Message
            }
        }
    }

    [hashtable] TriggerEvent([EventType]$eventType, [object]$payload) {
        $logResult = $this.LogEvent($eventType, $payload)

        if (-not $logResult.Success) {
            return $logResult
        }

        $eventName = $eventType.ToString().ToLower()
        $matchingWebhooks = $this.Webhooks | Where-Object { $_.Enabled -and ($_.Events -contains $eventName -or $_.Events -contains "*") }

        $triggeredCount = 0
        foreach ($webhook in $matchingWebhooks) {
            $triggerResult = $this.TriggerWebhook($webhook, $eventType, $payload)
            if ($triggerResult.Success) {
                $triggeredCount++
            }
        }

        return @{
            "Success" = $true
            "EventId" = $logResult.EventId
            "WebhooksTriggered" = $triggeredCount
        }
    }

    [hashtable] TriggerWebhook([Webhook]$webhook, [EventType]$eventType, [object]$payload) {
        $headers = @{
            "Content-Type" = "application/json"
            "X-Webhook-Event" = $eventType.ToString()
            "X-Device-Id" = $this.DeviceId
        }

        if ($webhook.Secret) {
            $headers["X-Webhook-Secret"] = $webhook.Secret
        }

        $body = @{
            "event" = $eventType.ToString()
            "device_id" = $this.DeviceId
            "timestamp" = (Get-Date).ToString("o")
            "data" = $payload
        } | ConvertTo-Json

        try {
            $response = Invoke-RestMethod -Uri $webhook.Url -Headers $headers -Method POST -Body $body -TimeoutSec 30

            return @{
                "Success" = $true
                "Response" = $response
            }
        } catch {
            $this.UpdateWebhookFailureCount($webhook.Id, $true)

            return @{
                "Success" = $false
                "Error" = $_.Exception.Message
            }
        }
    }

    [void] UpdateWebhookFailureCount([string]$webhookId, [bool]$increment) {
        $endpoint = "$($this.SupabaseUrl)/rest/v1/webhooks?id=eq.$($webhookId)"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseServiceKey)"
            "Content-Type" = "application/json"
        }

        $current = $this.Webhooks | Where-Object { $_.Id -eq $webhookId }
        $newCount = if ($increment) { $current.FailureCount + 1 } else { 0 }

        $body = @{
            "failure_count" = $newCount
            "last_triggered_at" = (Get-Date).ToString("o")
        } | ConvertTo-Json

        try {
            Invoke-RestMethod -Uri $endpoint -Headers $headers -Method PATCH -Body $body | Out-Null
        } catch {
        }
    }

    [hashtable] RecordNotification([string]$title, [string]$body, [object]$data) {
        $endpoint = "$($this.SupabaseUrl)/rest/v1/rpc/record_notification"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseServiceKey)"
            "Content-Type" = "application/json"
        }

        $body = @{
            "p_user_id" = $this.DeviceId
            "p_device_id" = $this.DeviceId
            "p_notification_type" = "push"
            "p_title" = $title
            "p_body" = $body
            "p_data" = ($data | ConvertTo-Json -Compress)
        } | ConvertTo-Json

        try {
            $result = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method POST -Body $body
            return @{
                "Success" = $true
                "NotificationId" = $result
            }
        } catch {
            return @{
                "Success" = $false
                "Error" = $_.Exception.Message
            }
        }
    }

    [object] GetNotificationHistory([int]$limit = 50) {
        if (-not $this.IsOnline) {
            return @{
                "Success" = $false
                "Error" = "Offline"
            }
        }

        $endpoint = "$($this.SupabaseUrl)/rest/v1/notification_history?user_id=eq.$($this.DeviceId)&order=created_at.desc&limit=$($limit)"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseAnonKey)"
        }

        try {
            $data = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method GET
            return @{
                "Success" = $true
                "Data" = $data
            }
        } catch {
            return @{
                "Success" = $false
                "Error" = $_.Exception.Message
            }
        }
    }

    [object] GetScheduledTasks() {
        return @{
            "Total" = $this.ScheduledTasks.Count
            "Enabled" = ($this.ScheduledTasks | Where-Object { $_.Enabled }).Count
            "Tasks" = $this.ScheduledTasks
        }
    }

    [object] GetWebhooks() {
        return @{
            "Total" = $this.Webhooks.Count
            "Enabled" = ($this.Webhooks | Where-Object { $_.Enabled }).Count
            "Webhooks" = $this.Webhooks
        }
    }

    [hashtable] CreateDailyReminder([string]$time, [string]$message) {
        $cronParts = $time -split ':'
        $hour = $cronParts[0]
        $minute = $cronParts[1]

        return $this.CreateScheduledTask(
            "Daily Reminder",
            [TaskType]::Reminder,
            "$minute $hour * * *",
            @{ "message" = $message }
        )
    }

    [hashtable] CreateWeeklyReportTask([string]$dayOfWeek = "monday", [int]$hour = 9) {
        $dayMap = @{
            "sunday" = 0
            "monday" = 1
            "tuesday" = 2
            "wednesday" = 3
            "thursday" = 4
            "friday" = 5
            "saturday" = 6
        }

        $dayNum = $dayMap[$dayOfWeek.ToLower()]

        return $this.CreateScheduledTask(
            "Weekly Report",
            [TaskType]::Report,
            "0 $hour * * $dayNum",
            @{ "report_type" = "weekly_summary" }
        )
    }
}

$gooseNotificationsClient = [GooseNotificationsClient]::new()

function Get-GooseNotificationsClient {
    return $gooseNotificationsClient
}

function Register-PushSubscription {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,
        [Parameter(Mandatory=$true)]
        [string]$P256dh,
        [Parameter(Mandatory=$true)]
        [string]$Auth,
        $Client = $gooseNotificationsClient
    )
    return $Client.RegisterPushSubscription($Endpoint, $P256dh, $Auth)
}

function Add-Webhook {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$Url,
        [Parameter(Mandatory=$true)]
        [string[]]$Events,
        $Client = $gooseNotificationsClient
    )
    return $Client.AddWebhook($Name, $Url, $Events)
}

function Remove-Webhook {
    param(
        [Parameter(Mandatory=$true)]
        [string]$WebhookId,
        $Client = $gooseNotificationsClient
    )
    return $Client.RemoveWebhook($WebhookId)
}

function New-ScheduledTask {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TaskName,
        [Parameter(Mandatory=$true)]
        [TaskType]$TaskType,
        [Parameter(Mandatory=$true)]
        [string]$CronExpression,
        [object]$Payload,
        $Client = $gooseNotificationsClient
    )
    return $Client.CreateScheduledTask($TaskName, $TaskType, $CronExpression, $Payload)
}

function Write-Event {
    param(
        [Parameter(Mandatory=$true)]
        [EventType]$EventType,
        [object]$Payload,
        $Client = $gooseNotificationsClient
    )
    return $Client.LogEvent($EventType, $Payload)
}

function Trigger-Event {
    param(
        [Parameter(Mandatory=$true)]
        [EventType]$EventType,
        [object]$Payload,
        $Client = $gooseNotificationsClient
    )
    return $Client.TriggerEvent($EventType, $Payload)
}

function New-DailyReminder {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Time,
        [Parameter(Mandatory=$true)]
        [string]$Message,
        $Client = $gooseNotificationsClient
    )
    return $Client.CreateDailyReminder($Time, $Message)
}

function New-WeeklyReportTask {
    param(
        [string]$DayOfWeek = "monday",
        [int]$Hour = 9,
        $Client = $gooseNotificationsClient
    )
    return $Client.CreateWeeklyReportTask($DayOfWeek, $Hour)
}

function Get-NotificationHistory {
    param(
        [int]$Limit = 50,
        $Client = $gooseNotificationsClient
    )
    return $Client.GetNotificationHistory($Limit)
}

function Get-ScheduledTasks {
    param($Client = $gooseNotificationsClient)
    return $Client.GetScheduledTasks()
}

function Get-Webhooks {
    param($Client = $gooseNotificationsClient)
    return $Client.GetWebhooks()
}

Write-Host "Desktop Goose Notifications Module Initialized"
