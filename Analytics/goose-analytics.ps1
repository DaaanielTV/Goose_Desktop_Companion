# Desktop Goose Analytics & Reporting Module
# Provides analytics, goals, achievements, and reporting

enum ReportType {
    WeeklySummary
    HabitAnalysis
    ProductivityReport
    SyncStats
}

enum GoalType {
    HabitStreak
    FocusTimeTotal
    NotesCount
    SyncFrequency
    DailyActive
}

enum TelemetryEventType {
    SessionStart
    SessionEnd
    FeatureUsed
    WindowInteraction
    Error
    Performance
}

class Goal {
    [string]$Id
    [string]$UserId
    [string]$DeviceId
    [GoalType]$GoalType
    [string]$GoalName
    [double]$TargetValue
    [double]$CurrentValue
    [string]$Unit
    [datetime]$StartDate
    [datetime]$EndDate
    [datetime]$AchievedAt
    [bool]$IsActive

    Goal([string]$id, [GoalType]$type, [string]$name, [double]$target, [string]$unit) {
        $this.Id = $id
        $this.GoalType = $type
        $this.GoalName = $name
        $this.TargetValue = $target
        $this.Unit = $unit
        $this.CurrentValue = 0
        $this.IsActive = $true
    }
}

class Achievement {
    [string]$Id
    [string]$AchievementKey
    [string]$AchievementName
    [string]$Description
    [string]$IconUrl
    [datetime]$UnlockedAt
    [double]$ProgressCurrent
    [double]$ProgressTarget
    [bool]$IsUnlocked

    Achievement([string]$key, [string]$name, [string]$desc, [double]$target) {
        $this.AchievementKey = $key
        $this.AchievementName = $name
        $this.Description = $desc
        $this.ProgressTarget = $target
        $this.ProgressCurrent = 0
        $this.IsUnlocked = $false
    }
}

class TelemetryEvent {
    [string]$Id
    [TelemetryEventType]$EventType
    [string]$ModuleName
    [string]$FeatureName
    [hashtable]$Properties
    [datetime]$Timestamp
    [string]$DeviceId

    TelemetryEvent([TelemetryEventType]$type, [string]$module, [string]$feature) {
        $this.Id = [guid]::NewGuid().ToString()
        $this.EventType = $type
        $this.ModuleName = $module
        $this.FeatureName = $feature
        $this.Properties = @{}
        $this.Timestamp = Get-Date
    }
}

class AppSession {
    [string]$Id
    [datetime]$StartTime
    [datetime]$EndTime
    [TimeSpan]$Duration
    [string]$Version
    [string]$OsVersion
    [bool]$WasCleanExit

    AppSession() {
        $this.Id = [guid]::NewGuid().ToString()
        $this.StartTime = Get-Date
        $this.Version = "1.0.0"
        $this.WasCleanExit = $false
    }
}

class GooseAnalyticsClient {
    [hashtable]$Config
    [string]$SupabaseUrl
    [string]$SupabaseAnonKey
    [string]$SupabaseServiceKey
    [string]$DeviceId
    [bool]$IsEnabled
    [bool]$IsOnline
    [System.Collections.ArrayList]$ActiveGoals
    [System.Collections.ArrayList]$Achievements
    [System.Collections.ArrayList]$TelemetryQueue
    [AppSession]$CurrentSession
    [datetime]$LastSyncTime

    GooseAnalyticsClient() {
        $this.Config = $this.LoadConfig()
        $this.SupabaseUrl = $this.Config["SupabaseUrl"]
        $this.SupabaseAnonKey = $this.Config["SupabaseAnonKey"]
        $this.SupabaseServiceKey = $this.Config["SupabaseServiceKey"]
        $this.IsEnabled = $this.Config["AnalyticsEnabled"]
        $this.IsOnline = $false
        $this.ActiveGoals = New-Object System.Collections.ArrayList
        $this.Achievements = New-Object System.Collections.ArrayList
        $this.TelemetryQueue = New-Object System.Collections.ArrayList
        $this.CurrentSession = $null

        $this.InitializeDeviceId()
        $this.LoadLocalGoals()
        $this.LoadLocalAchievements()
        $this.LoadPendingTelemetry()

        if ($this.IsEnabled) {
            $this.TestConnection()
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

        if (-not $config.ContainsKey("AnalyticsEnabled")) { $config["AnalyticsEnabled"] = $false }
        if (-not $config.ContainsKey("AnalyticsAutoReport")) { $config["AnalyticsAutoReport"] = $true }
        if (-not $config.ContainsKey("AnalyticsDays")) { $config["AnalyticsDays"] = 7 }

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

    [void] LoadLocalGoals() {
        $goalsFile = "goose_goals.json"

        if (Test-Path $goalsFile) {
            try {
                $goalsData = Get-Content $goalsFile -Raw | ConvertFrom-Json
                foreach ($goal in $goalsData) {
                    $g = [Goal]::new($goal.Id, $goal.GoalType, $goal.GoalName, $goal.TargetValue, $goal.Unit)
                    $g.CurrentValue = $goal.CurrentValue
                    $g.DeviceId = $goal.DeviceId
                    $g.StartDate = $goal.StartDate
                    $g.EndDate = $goal.EndDate
                    $g.IsActive = $goal.IsActive
                    $this.ActiveGoals.Add($g)
                }
            } catch {
            }
        }
    }

    [void] SaveLocalGoals() {
        $goalsData = @()

        foreach ($goal in $this.ActiveGoals) {
            $goalsData += @{
                "Id" = $goal.Id
                "GoalType" = $goal.GoalType.ToString()
                "GoalName" = $goal.GoalName
                "TargetValue" = $goal.TargetValue
                "CurrentValue" = $goal.CurrentValue
                "Unit" = $goal.Unit
                "StartDate" = $goal.StartDate
                "EndDate" = $goal.EndDate
                "IsActive" = $goal.IsActive
                "DeviceId" = $this.DeviceId
            }
        }

        $goalsData | ConvertTo-Json -Depth 10 | Set-Content "goose_goals.json"
    }

    [void] LoadLocalAchievements() {
        $achievementsFile = "goose_achievements.json"

        if (Test-Path $achievementsFile) {
            try {
                $achievementsData = Get-Content $achievementsFile -Raw | ConvertFrom-Json
                foreach ($achievement in $achievementsData) {
                    $a = [Achievement]::new($achievement.AchievementKey, $achievement.AchievementName, $achievement.Description, $achievement.ProgressTarget)
                    $a.Id = $achievement.Id
                    $a.ProgressCurrent = $achievement.ProgressCurrent
                    $a.IsUnlocked = $achievement.IsUnlocked
                    $a.IconUrl = $achievement.IconUrl
                    $this.Achievements.Add($a)
                }
            } catch {
            }
        }
    }

    [void] SaveLocalAchievements() {
        $achievementsData = @()

        foreach ($achievement in $this.Achievements) {
            $achievementsData += @{
                "Id" = $achievement.Id
                "AchievementKey" = $achievement.AchievementKey
                "AchievementName" = $achievement.AchievementName
                "Description" = $achievement.Description
                "ProgressCurrent" = $achievement.ProgressCurrent
                "ProgressTarget" = $achievement.ProgressTarget
                "IsUnlocked" = $achievement.IsUnlocked
                "IconUrl" = $achievement.IconUrl
            }
        }

        $achievementsData | ConvertTo-Json -Depth 10 | Set-Content "goose_achievements.json"
    }

    [void] LoadPendingTelemetry() {
        $telemetryFile = "goose_telemetry_pending.json"

        if (Test-Path $telemetryFile) {
            try {
                $pendingData = Get-Content $telemetryFile -Raw | ConvertFrom-Json
                foreach ($item in $pendingData) {
                    $event = [TelemetryEvent]::new([TelemetryEventType]$item.EventType, $item.ModuleName, $item.FeatureName)
                    $event.Id = $item.Id
                    $event.Timestamp = $item.Timestamp
                    $event.Properties = $item.Properties
                    $event.DeviceId = $item.DeviceId
                    $this.TelemetryQueue.Add($event)
                }
            } catch {
            }
        }
    }

    [void] SavePendingTelemetry() {
        $telemetryData = @()

        foreach ($event in $this.TelemetryQueue) {
            $telemetryData += @{
                "Id" = $event.Id
                "EventType" = $event.EventType.ToString()
                "ModuleName" = $event.ModuleName
                "FeatureName" = $event.FeatureName
                "Properties" = $event.Properties
                "Timestamp" = $event.Timestamp.ToString("o")
                "DeviceId" = $event.DeviceId
            }
        }

        $telemetryData | ConvertTo-Json -Depth 10 | Set-Content "goose_telemetry_pending.json"
    }

    [void] StartSession() {
        if ($this.CurrentSession) {
            $this.EndSession($false)
        }

        $this.CurrentSession = [AppSession]::new()
        $this.CurrentSession.DeviceId = $this.DeviceId

        $this.TrackEvent([TelemetryEventType]::SessionStart, "System", "AppStart", @{
            "session_id" = $this.CurrentSession.Id
            "version" = $this.CurrentSession.Version
            "os_version" = $this.CurrentSession.OsVersion
        })
    }

    [void] EndSession([bool]$cleanExit = $true) {
        if (-not $this.CurrentSession) { return }

        $this.CurrentSession.EndTime = Get-Date
        $this.CurrentSession.Duration = $this.CurrentSession.EndTime - $this.CurrentSession.StartTime
        $this.CurrentSession.WasCleanExit = $cleanExit

        $this.TrackEvent([TelemetryEventType]::SessionEnd, "System", "AppEnd", @{
            "session_id" = $this.CurrentSession.Id
            "duration_seconds" = $this.CurrentSession.Duration.TotalSeconds
            "was_clean_exit" = $cleanExit
        })

        $this.FlushTelemetry()
        $this.CurrentSession = $null
    }

    [void] TrackEvent([TelemetryEventType]$eventType, [string]$module, [string]$feature, [hashtable]$properties = @{}) {
        if (-not $this.IsEnabled) { return }

        $event = [TelemetryEvent]::new($eventType, $module, $feature)
        $event.DeviceId = $this.DeviceId
        $event.Properties = $properties

        if ($this.CurrentSession) {
            $event.Properties["session_id"] = $this.CurrentSession.Id
        }

        $this.TelemetryQueue.Add($event)
        $this.SavePendingTelemetry()

        if ($this.IsOnline -and $this.TelemetryQueue.Count -ge 10) {
            $this.FlushTelemetry()
        }
    }

    [void] TrackFeatureUsage([string]$module, [string]$feature, [hashtable]$properties = @{}) {
        if ($properties.Count -eq 0) {
            $properties = @{ "count" = 1 }
        } elseif ($properties.ContainsKey("count")) {
            $properties["count"] = [int]$properties["count"] + 1
        }

        $this.TrackEvent([TelemetryEventType]::FeatureUsed, $module, $feature, $properties)
    }

    [void] TrackWindowInteraction([string]$windowName, [string]$action, [hashtable]$properties = @{}) {
        $props = @{
            "window_name" = $windowName
            "action" = $action
        }
        foreach ($key in $properties.Keys) {
            $props[$key] = $properties[$key]
        }

        $this.TrackEvent([TelemetryEventType]::WindowInteraction, "UI", $windowName, $props)
    }

    [void] TrackError([string]$module, [string]$errorType, [string]$message, [hashtable]$properties = @{}) {
        $props = @{
            "error_type" = $errorType
            "message" = $message
            "stack_trace" = if ($properties.ContainsKey("stack_trace")) { $properties["stack_trace"] } else { $null }
        }
        foreach ($key in $properties.Keys) {
            if ($key -ne "stack_trace") {
                $props[$key] = $properties[$key]
            }
        }

        $this.TrackEvent([TelemetryEventType]::Error, $module, $errorType, $props)
    }

    [void] TrackPerformance([string]$module, [string]$operation, [double]$durationMs, [hashtable]$properties = @{}) {
        $props = @{
            "duration_ms" = $durationMs
            "operation" = $operation
        }
        foreach ($key in $properties.Keys) {
            $props[$key] = $properties[$key]
        }

        $this.TrackEvent([TelemetryEventType]::Performance, $module, $operation, $props)
    }

    [hashtable] FlushTelemetry() {
        if ($this.TelemetryQueue.Count -eq 0) {
            return @{ "Success" = $true; "Flushed" = 0 }
        }

        if (-not $this.IsOnline) {
            return @{ "Success" = $false; "Error" = "Offline"; "Queued" = $this.TelemetryQueue.Count }
        }

        $flushed = 0
        $errors = @()

        foreach ($event in $this.TelemetryQueue) {
            $result = $this.SendTelemetryEvent($event)
            if ($result["Success"]) {
                $flushed++
            } else {
                $errors += $result["Error"]
            }
        }

        if ($flushed -gt 0) {
            for ($i = 0; $i -lt $flushed; $i++) {
                $this.TelemetryQueue.RemoveAt(0)
            }
            $this.SavePendingTelemetry()
            $this.LastSyncTime = Get-Date
        }

        return @{
            "Success" = $errors.Count -eq 0
            "Flushed" = $flushed
            "Remaining" = $this.TelemetryQueue.Count
            "Errors" = $errors
        }
    }

    [hashtable] SendTelemetryEvent([TelemetryEvent]$event) {
        $endpoint = "$($this.SupabaseUrl)/rest/v1/telemetry_events"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseServiceKey)"
            "Content-Type" = "application/json"
            "Prefer" = "return=minimal"
        }

        $body = @{
            "device_id" = $this.DeviceId
            "session_id" = if ($this.CurrentSession) { $this.CurrentSession.Id } else { $null }
            "event_type" = $event.EventType.ToString()
            "module_name" = $event.ModuleName
            "feature_name" = $event.FeatureName
            "properties" = $event.Properties
            "timestamp" = $event.Timestamp.ToString("o")
        } | ConvertTo-Json

        try {
            Invoke-RestMethod -Uri $endpoint -Headers $headers -Method POST -Body $body | Out-Null
            return @{ "Success" = $true }
        } catch {
            return @{ "Success" = $false; "Error" = $_.Exception.Message }
        }
    }

    [object] GetTelemetryStats() {
        $stats = @{
            "QueueSize" = $this.TelemetryQueue.Count
            "LastSync" = $this.LastSyncTime
            "SessionActive" = $this.CurrentSession -ne $null
            "SessionDuration" = if ($this.CurrentSession) { $this.CurrentSession.Duration.TotalSeconds } else { 0 }
            "EventsByType" = @{}
        }

        foreach ($event in $this.TelemetryQueue) {
            $typeKey = $event.EventType.ToString()
            if (-not $stats.EventsByType.ContainsKey($typeKey)) {
                $stats.EventsByType[$typeKey] = 0
            }
            $stats.EventsByType[$typeKey]++
        }

        return $stats
    }

    [hashtable] RecordMetric([string]$metricName, [string]$category, [object]$value) {
        $endpoint = "$($this.SupabaseUrl)/rest/v1/analytics_summaries"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseServiceKey)"
            "Content-Type" = "application/json"
            "Prefer" = "return=minimal"
        }

        $body = @{
            "user_id" = $this.DeviceId
            "device_id" = $this.DeviceId
            "date" = (Get-Date).ToString("yyyy-MM-dd")
            "metric_name" = $metricName
            "metric_category" = $category
            "value" = ($value | ConvertTo-Json -Compress)
        } | ConvertTo-Json

        try {
            Invoke-RestMethod -Uri $endpoint -Headers $headers -Method POST -Body $body | Out-Null
            return @{
                "Success" = $true
                "MetricName" = $metricName
                "Category" = $category
            }
        } catch {
            return @{
                "Success" = $false
                "Error" = $_.Exception.Message
            }
        }
    }

    [hashtable] RecordHabitCompletion([int]$totalHabits, [int]$completedHabits) {
        $completionRate = if ($totalHabits -gt 0) { [Math]::Round(($completedHabits / $totalHabits) * 100, 2) } else { 0 }

        return $this.RecordMetric("habit_completion", "habits", @{
            "total_habits" = $totalHabits
            "completed_habits" = $completedHabits
            "completion_rate" = $completionRate
        })
    }

    [hashtable] RecordFocusTime([double]$minutes) {
        return $this.RecordMetric("focus_time", "productivity", @{
            "minutes" = $minutes
            "hours" = [Math]::Round($minutes / 60, 2)
        })
    }

    [hashtable] RecordSyncActivity([int]$totalSyncs, [int]$successful, [int]$failed) {
        return $this.RecordMetric("sync_activity", "sync", @{
            "total_syncs" = $totalSyncs
            "successful" = $successful
            "failed" = $failed
        })
    }

    [void] CreateGoal([GoalType]$type, [string]$name, [double]$target, [string]$unit, [datetime]$endDate) {
        $goal = [Goal]::new([guid]::NewGuid().ToString(), $type, $name, $target, $unit)
        $goal.DeviceId = $this.DeviceId
        $goal.StartDate = Get-Date
        $goal.EndDate = $endDate

        $this.ActiveGoals.Add($goal)
        $this.SaveLocalGoals()

        if ($this.IsOnline) {
            $this.SyncGoalToServer($goal)
        }
    }

    [void] UpdateGoalProgress([GoalType]$type, [double]$newValue) {
        foreach ($goal in $this.ActiveGoals) {
            if ($goal.GoalType -eq $type -and $goal.IsActive) {
                $goal.CurrentValue = $newValue

                if ($newValue -ge $goal.TargetValue -and -not $goal.AchievedAt) {
                    $goal.AchievedAt = Get-Date
                    $this.CheckAchievements($type.ToString(), $newValue)
                }

                $this.SaveLocalGoals()

                if ($this.IsOnline) {
                    $this.SyncGoalToServer($goal)
                }
            }
        }
    }

    [object] GetGoalProgress([GoalType]$type) {
        foreach ($goal in $this.ActiveGoals) {
            if ($goal.GoalType -eq $type) {
                $progress = if ($goal.TargetValue -gt 0) { [Math]::Round(($goal.CurrentValue / $goal.TargetValue) * 100, 2) } else { 0 }

                return @{
                    "GoalName" = $goal.GoalName
                    "CurrentValue" = $goal.CurrentValue
                    "TargetValue" = $goal.TargetValue
                    "Unit" = $goal.Unit
                    "ProgressPercent" = $progress
                    "IsAchieved" = $goal.AchievedAt -ne $null
                }
            }
        }
        return $null
    }

    [void] SyncGoalToServer([Goal]$goal) {
        $endpoint = "$($this.SupabaseUrl)/rest/v1/goals"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseServiceKey)"
            "Content-Type" = "application/json"
            "Prefer" = "resolution=merge-duplicates"
        }

        $body = @{
            "user_id" = $this.DeviceId
            "device_id" = $this.DeviceId
            "goal_type" = $goal.GoalType.ToString()
            "goal_name" = $goal.GoalName
            "target_value" = $goal.TargetValue
            "current_value" = $goal.CurrentValue
            "unit" = $goal.Unit
            "start_date" = $goal.StartDate.ToString("yyyy-MM-dd")
            "end_date" = if ($goal.EndDate) { $goal.EndDate.ToString("yyyy-MM-dd") } else { $null }
            "is_active" = $goal.IsActive
        } | ConvertTo-Json

        try {
            Invoke-RestMethod -Uri $endpoint -Headers $headers -Method POST -Body $body | Out-Null
        } catch {
        }
    }

    [void] CheckAchievements([string]$triggerKey, [double]$progress) {
        $achievementsToCheck = @{
            "first_sync" = @{ "name" = "First Sync"; "desc" = "Complete your first sync"; "target" = 1 }
            "week_streak" = @{ "name" = "Week Warrior"; "desc" = "Maintain a 7-day streak"; "target" = 7 }
            "month_streak" = @{ "name" = "Monthly Master"; "desc" = "Maintain a 30-day streak"; "target" = 30 }
            "notes_10" = @{ "name" = "Note Taker"; "desc" = "Create 10 notes"; "target" = 10 }
            "notes_50" = @{ "name" = "Note Collector"; "desc" = "Create 50 notes"; "target" = 50 }
            "notes_100" = @{ "name" = "Note Master"; "desc" = "Create 100 notes"; "target" = 100 }
            "focus_1h" = @{ "name" = "Focus Beginner"; "desc" = "Complete 1 hour of focus time"; "target" = 60 }
            "focus_10h" = @{ "name" = "Focus Pro"; "desc" = "Complete 10 hours of focus time"; "target" = 600 }
            "focus_100h" = @{ "name" = "Focus Master"; "desc" = "Complete 100 hours of focus time"; "target" = 6000 }
        }

        $key = $triggerKey.ToLower()
        if ($achievementsToCheck.ContainsKey($key)) {
            $achInfo = $achievementsToCheck[$key]
            $existing = $this.Achievements | Where-Object { $_.AchievementKey -eq $key }

            if (-not $existing) {
                $newAchievement = [Achievement]::new($key, $achInfo["name"], $achInfo["desc"], $achInfo["target"])
                $newAchievement.Id = [guid]::NewGuid().ToString()
                $newAchievement.ProgressCurrent = $progress
                $newAchievement.DeviceId = $this.DeviceId

                if ($progress -ge $achInfo["target"]) {
                    $newAchievement.IsUnlocked = $true
                    $newAchievement.UnlockedAt = Get-Date
                }

                $this.Achievements.Add($newAchievement)
                $this.SaveLocalAchievements()

                if ($this.IsOnline) {
                    $this.SyncAchievementToServer($newAchievement)
                }
            } elseif (-not $existing.IsUnlocked) {
                $existing.ProgressCurrent = $progress

                if ($progress -ge $existing.ProgressTarget) {
                    $existing.IsUnlocked = $true
                    $existing.UnlockedAt = Get-Date
                }

                $this.SaveLocalAchievements()

                if ($this.IsOnline) {
                    $this.SyncAchievementToServer($existing)
                }
            }
        }
    }

    [void] SyncAchievementToServer([Achievement]$achievement) {
        $endpoint = "$($this.SupabaseUrl)/rest/v1/achievements"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseServiceKey)"
            "Content-Type" = "application/json"
            "Prefer" = "resolution=merge-duplicates"
        }

        $body = @{
            "user_id" = $this.DeviceId
            "achievement_key" = $achievement.AchievementKey
            "achievement_name" = $achievement.AchievementName
            "description" = $achievement.Description
            "progress_current" = $achievement.ProgressCurrent
            "progress_target" = $achievement.ProgressTarget
            "is_unlocked" = $achievement.IsUnlocked
            "unlocked_at" = if ($achievement.UnlockedAt) { $achievement.UnlockedAt.ToString("o") } else { $null }
        } | ConvertTo-Json

        try {
            Invoke-RestMethod -Uri $endpoint -Headers $headers -Method POST -Body $body | Out-Null
        } catch {
        }
    }

    [object] GetDashboardAnalytics([int]$days = 7) {
        if (-not $this.IsOnline) {
            return @{
                "Success" = $false
                "Error" = "Offline"
                "LocalData" = $this.GetLocalAnalytics($days)
            }
        }

        $endpoint = "$($this.SupabaseUrl)/rest/v1/analytics_summaries?user_id=eq.$($this.DeviceId)&device_id=eq.$($this.DeviceId)&date=gte.$((Get-Date).AddDays(-$days).ToString('yyyy-MM-dd'))&order=date.desc"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseAnonKey)"
        }

        try {
            $data = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method GET

            $grouped = @{}
            foreach ($item in $data) {
                $date = $item.date
                if (-not $grouped.ContainsKey($date)) {
                    $grouped[$date] = @{}
                }
                $grouped[$date][$item.metric_name] = $item.value
            }

            return @{
                "Success" = $true
                "Data" = $grouped
                "Days" = $days
            }
        } catch {
            return @{
                "Success" = $false
                "Error" = $_.Exception.Message
                "LocalData" = $this.GetLocalAnalytics($days)
            }
        }
    }

    [object] GetLocalAnalytics([int]$days) {
        $localData = @{}

        $notesFile = "goose_notes.json"
        if (Test-Path $notesFile) {
            $notes = Get-Content $notesFile -Raw | ConvertFrom-Json
            $localData["notes_count"] = if ($notes -is [array]) { $notes.Count } else { 1 }
        }

        $habitsFile = "goose_habits.json"
        if (Test-Path $habitsFile) {
            $habits = Get-Content $habitsFile -Raw | ConvertFrom-Json
            $localData["habits_count"] = if ($habits -is [array]) { $habits.Count } else { 1 }
        }

        return $localData
    }

    [object] GetWeeklyReport() {
        $weekStart = (Get-Date).AddDays(-7).Date

        if ($this.IsOnline) {
            $endpoint = "$($this.SupabaseUrl)/rest/v1/reports?user_id=eq.$($this.DeviceId)&report_type=eq.weekly_summary&date_range_start=eq.$($weekStart.ToString('yyyy-MM-dd'))&order=generated_at.desc&limit=1"

            $headers = @{
                "apikey" = $this.SupabaseAnonKey
                "Authorization" = "Bearer $($this.SupabaseAnonKey)"
            }

            try {
                $data = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method GET
                if ($data -and $data.Count -gt 0) {
                    return @{
                        "Success" = $true
                        "Report" = $data[0]
                    }
                }
            } catch {
            }
        }

        return @{
            "Success" = $true
            "LocalReport" = $this.GenerateLocalWeeklyReport($weekStart)
        }
    }

    [object] GenerateLocalWeeklyReport([datetime]$weekStart) {
        $weekEnd = $weekStart.AddDays(6)
        $notesCount = 0
        $habitsCount = 0

        $notesFile = "goose_notes.json"
        if (Test-Path $notesFile) {
            $notes = Get-Content $notesFile -Raw | ConvertFrom-Json
            $notesCount = if ($notes -is [array]) { $notes.Count } else { 1 }
        }

        $habitsFile = "goose_habits.json"
        if (Test-Path $habitsFile) {
            $habits = Get-Content $habitsFile -Raw | ConvertFrom-Json
            $habitsCount = if ($habits -is [array]) { $habits.Count } else { 1 }
        }

        return @{
            "report_type" = "weekly_summary"
            "date_range_start" = $weekStart.ToString("yyyy-MM-dd")
            "date_range_end" = $weekEnd.ToString("yyyy-MM-dd")
            "summary" = @{
                "notes_count" = $notesCount
                "habits_count" = $habitsCount
                "goals_active" = ($this.ActiveGoals | Where-Object { $_.IsActive }).Count
                "achievements_unlocked" = ($this.Achievements | Where-Object { $_.IsUnlocked }).Count
            }
        }
    }

    [object] GetAchievements() {
        return @{
            "Total" = $this.Achievements.Count
            "Unlocked" = ($this.Achievements | Where-Object { $_.IsUnlocked }).Count
            "List" = $this.Achievements
        }
    }

    [object] GetGoals() {
        return @{
            "Total" = $this.ActiveGoals.Count
            "Active" = ($this.ActiveGoals | Where-Object { $_.IsActive }).Count
            "Achieved" = ($this.ActiveGoals | Where-Object { $_.AchievedAt -ne $null }).Count
            "List" = $this.ActiveGoals
        }
    }
}

$gooseAnalyticsClient = [GooseAnalyticsClient]::new()

function Get-GooseAnalyticsClient {
    return $gooseAnalyticsClient
}

function Get-AnalyticsDashboard {
    param(
        [int]$Days = 7,
        $Client = $gooseAnalyticsClient
    )
    return $Client.GetDashboardAnalytics($Days)
}

function Record-HabitCompletion {
    param(
        [Parameter(Mandatory=$true)]
        [int]$TotalHabits,
        [Parameter(Mandatory=$true)]
        [int]$CompletedHabits,
        $Client = $gooseAnalyticsClient
    )
    return $Client.RecordHabitCompletion($TotalHabits, $CompletedHabits)
}

function Record-FocusTime {
    param(
        [Parameter(Mandatory=$true)]
        [double]$Minutes,
        $Client = $gooseAnalyticsClient
    )
    return $Client.RecordFocusTime($Minutes)
}

function New-Goal {
    param(
        [Parameter(Mandatory=$true)]
        [GoalType]$Type,
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [double]$Target,
        [Parameter(Mandatory=$true)]
        [string]$Unit,
        [datetime]$EndDate,
        $Client = $gooseAnalyticsClient
    )
    $Client.CreateGoal($Type, $Name, $Target, $Unit, $EndDate)
}

function Get-GoalProgress {
    param(
        [Parameter(Mandatory=$true)]
        [GoalType]$Type,
        $Client = $gooseAnalyticsClient
    )
    return $Client.GetGoalProgress($Type)
}

function Update-GoalProgress {
    param(
        [Parameter(Mandatory=$true)]
        [GoalType]$Type,
        [Parameter(Mandatory=$true)]
        [double]$Value,
        $Client = $gooseAnalyticsClient
    )
    $Client.UpdateGoalProgress($Type, $Value)
}

function Get-Achievements {
    param($Client = $gooseAnalyticsClient)
    return $Client.GetAchievements()
}

function Get-Goals {
    param($Client = $gooseAnalyticsClient)
    return $Client.GetGoals()
}

function Get-WeeklyReport {
    param($Client = $gooseAnalyticsClient)
    return $Client.GetWeeklyReport()
}

function Start-GooseSession {
    param($Client = $gooseAnalyticsClient)
    $Client.StartSession()
}

function Stop-GooseSession {
    param(
        [bool]$CleanExit = $true,
        $Client = $gooseAnalyticsClient
    )
    $Client.EndSession($CleanExit)
}

function Track-GooseFeature {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Module,
        [Parameter(Mandatory=$true)]
        [string]$Feature,
        [hashtable]$Properties = @{},
        $Client = $gooseAnalyticsClient
    )
    $Client.TrackFeatureUsage($Module, $Feature, $Properties)
}

function Track-GooseWindowInteraction {
    param(
        [Parameter(Mandatory=$true)]
        [string]$WindowName,
        [Parameter(Mandatory=$true)]
        [string]$Action,
        [hashtable]$Properties = @{},
        $Client = $gooseAnalyticsClient
    )
    $Client.TrackWindowInteraction($WindowName, $Action, $Properties)
}

function Track-GooseError {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Module,
        [Parameter(Mandatory=$true)]
        [string]$ErrorType,
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [hashtable]$Properties = @{},
        $Client = $gooseAnalyticsClient
    )
    $Client.TrackError($Module, $ErrorType, $Message, $Properties)
}

function Track-GoosePerformance {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Module,
        [Parameter(Mandatory=$true)]
        [string]$Operation,
        [Parameter(Mandatory=$true)]
        [double]$DurationMs,
        [hashtable]$Properties = @{},
        $Client = $gooseAnalyticsClient
    )
    $Client.TrackPerformance($Module, $Operation, $DurationMs, $Properties)
}

function Flush-GooseTelemetry {
    param($Client = $gooseAnalyticsClient)
    return $Client.FlushTelemetry()
}

function Get-GooseTelemetryStats {
    param($Client = $gooseAnalyticsClient)
    return $Client.GetTelemetryStats()
}

Write-Host "Desktop Goose Analytics Module Initialized"
