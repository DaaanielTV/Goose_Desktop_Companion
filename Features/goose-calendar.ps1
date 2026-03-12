# Desktop Goose Calendar Integration System
# Provides calendar event awareness and integration

class GooseCalendar {
    [hashtable]$Config
    [hashtable]$TodayEvents
    [hashtable]$UpcomingEvents
    [datetime]$LastUpdate
    [int]$UpdateIntervalMinutes
    
    GooseCalendar() {
        $this.Config = $this.LoadConfig()
        $this.TodayEvents = @{}
        $this.UpcomingEvents = @{}
        $this.LastUpdate = Get-Date
        $this.UpdateIntervalMinutes = 5
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
        
        return $this.Config
    }
    
    [void] LoadOutlookEvents() {
        try {
            $outlook = New-Object -ComObject Outlook.Application
            $namespace = $outlook.GetNamespace("MAPI")
            $calendar = $namespace.GetDefaultFolder(9)
            
            $startDate = (Get-Date).Date
            $endDate = $startDate.AddDays(1)
            
            $filter = "[Start] >= '$($startDate.ToString('g'))' AND [Start] < '$($endDate.ToString('g'))'"
            $appointments = $calendar.Items.Restrict($filter)
            $appointments.Sort("[Start]")
            
            $events = @{}
            foreach ($apt in $appointments) {
                $startTime = $apt.Start
                $endTime = $apt.End
                $title = $apt.Subject
                $isAllDay = $apt.AllDayEvent
                
                if ($title -ne "") {
                    $events[$title] = @{
                        "Start" = $startTime
                        "End" = $endTime
                        "Title" = $title
                        "Location" = $apt.Location
                        "IsAllDay" = $isAllDay
                        "IsMeeting" = $apt.Meeting
                        "Organizer" = $apt.Organizer
                    }
                }
            }
            
            $this.TodayEvents = $events
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($outlook) | Out-Null
        } catch {
            $this.TodayEvents = @{}
        }
    }
    
    [void] LoadUpcomingEvents() {
        try {
            $outlook = New-Object -ComObject Outlook.Application
            $namespace = $outlook.GetNamespace("MAPI")
            $calendar = $namespace.GetDefaultFolder(9)
            
            $startDate = (Get-Date)
            $endDate = $startDate.AddDays(7)
            
            $filter = "[Start] >= '$($startDate.ToString('g'))' AND [Start] < '$($endDate.ToString('g'))'"
            $appointments = $calendar.Items.Restrict($filter)
            $appointments.Sort("[Start]")
            
            $events = @{}
            $count = 0
            foreach ($apt in $appointments) {
                if ($count -ge 10) { break }
                
                $startTime = $apt.Start
                $title = $apt.Subject
                
                if ($title -ne "") {
                    $events[$title] = @{
                        "Start" = $startTime
                        "Title" = $title
                        "Location" = $apt.Location
                        "IsAllDay" = $apt.AllDayEvent
                    }
                    $count++
                }
            }
            
            $this.UpcomingEvents = $events
            [System.Runtime.Interopservices.Marshal]::ReleaseComObject($outlook) | Out-Null
        } catch {
            $this.UpcomingEvents = @{}
        }
    }
    
    [void] Update() {
        $elapsed = ((Get-Date) - $this.LastUpdate).TotalMinutes
        if ($elapsed -ge $this.UpdateIntervalMinutes) {
            $this.LoadOutlookEvents()
            $this.LoadUpcomingEvents()
            $this.LastUpdate = Get-Date
        }
    }
    
    [bool] HasCurrentMeeting() {
        $now = Get-Date
        
        foreach ($event in $this.TodayEvents.Values) {
            if ($now -ge $event["Start"] -and $now -lt $event["End"]) {
                return $true
            }
        }
        
        return $false
    }
    
    [hashtable] GetCurrentMeeting() {
        $now = Get-Date
        
        foreach ($event in $this.TodayEvents.Values) {
            if ($now -ge $event["Start"] -and $now -lt $event["End"]) {
                return $event
            }
        }
        
        return $null
    }
    
    [hashtable] GetNextMeeting() {
        $now = Get-Date
        $nextMeeting = $null
        $minDiff = [int]::MaxValue
        
        foreach ($event in $this.TodayEvents.Values) {
            $diff = ($event["Start"] - $now).TotalMinutes
            if ($diff -gt 0 -and $diff -lt $minDiff) {
                $minDiff = $diff
                $nextMeeting = $event
            }
        }
        
        return $nextMeeting
    }
    
    [int] GetMinutesUntilNextMeeting() {
        $next = $this.GetNextMeeting()
        if ($null -eq $next) { return -1 }
        
        return [int]($next["Start"] - (Get-Date)).TotalMinutes
    }
    
    [hashtable] GetTodaySchedule() {
        return @{
            "Events" = $this.TodayEvents.Clone()
            "EventCount" = $this.TodayEvents.Count
            "HasCurrentMeeting" = $this.HasCurrentMeeting()
            "CurrentMeeting" = $this.GetCurrentMeeting()
            "NextMeeting" = $this.GetNextMeeting()
            "MinutesUntilNext" = $this.GetMinutesUntilNextMeeting()
        }
    }
    
    [hashtable] GetUpcomingSchedule() {
        return @{
            "Events" = $this.UpcomingEvents.Clone()
            "EventCount" = $this.UpcomingEvents.Count
        }
    }
    
    [string] GetGooseReminder() {
        if ($this.HasCurrentMeeting()) {
            $meeting = $this.GetCurrentMeeting()
            return "Shhh! You're in a meeting: $($meeting["Title"])"
        }
        
        $mins = $this.GetMinutesUntilNextMeeting()
        if ($mins -gt 0 -and $mins -le 15) {
            return "Your meeting starts in $mins minutes!"
        }
        
        $count = $this.TodayEvents.Count
        if ($count -gt 0) {
            return "You have $count event(s) today"
        }
        
        return "No more events today - free time!"
    }
    
    [void] ForceUpdate() {
        $this.LoadOutlookEvents()
        $this.LoadUpcomingEvents()
        $this.LastUpdate = Get-Date
    }
}

# Initialize calendar system
$gooseCalendar = [GooseCalendar]::new()

# Export functions
function Get-GooseCalendar {
    return $gooseCalendar
}

function Get-TodaySchedule {
    param($Calendar = $gooseCalendar)
    $Calendar.Update()
    return $Calendar.GetTodaySchedule()
}

function Get-UpcomingEvents {
    param($Calendar = $gooseCalendar)
    $Calendar.Update()
    return $Calendar.GetUpcomingSchedule()
}

function Get-GooseCalendarReminder {
    param($Calendar = $gooseCalendar)
    $Calendar.Update()
    return $Calendar.GetGooseReminder()
}

# Example usage
Write-Host "Desktop Goose Calendar Integration Initialized"
$schedule = Get-TodaySchedule
Write-Host "Today's events: $($schedule.EventCount)"
