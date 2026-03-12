class GooseCalendar {
    [hashtable]$Config
    [hashtable]$Events
    [int]$EventIdCounter
    [datetime]$CurrentMonth
    [bool]$IsEnabled
    
    GooseCalendar() {
        $this.Config = $this.LoadConfig()
        $this.Events = @{}
        $this.EventIdCounter = 1
        $this.CurrentMonth = (Get-Date).Date
        $this.IsEnabled = $false
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
        
        if (-not $this.Config.ContainsKey("CalendarEnabled")) {
            $this.Config["CalendarEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("CalendarShowWeekNumbers")) {
            $this.Config["CalendarShowWeekNumbers"] = $true
        }
        if (-not $this.Config.ContainsKey("CalendarFirstDayOfWeek")) {
            $this.Config["CalendarFirstDayOfWeek"] = 0
        }
        if (-not $this.Config.ContainsKey("CalendarDefaultView")) {
            $this.Config["CalendarDefaultView"] = "month"
        }
        if (-not $this.Config.ContainsKey("CalendarShowTasks")) {
            $this.Config["CalendarShowTasks"] = $true
        }
        
        return $this.Config
    }
    
    [void] LoadData() {
        $dataFile = "goose_calendar.json"
        
        if (Test-Path $dataFile) {
            try {
                $data = Get-Content $dataFile -Raw | ConvertFrom-Json
                
                if ($data.events) {
                    $this.Events = @{}
                    $data.events.PSObject.Properties | ForEach-Object {
                        $this.Events[$_.Name] = $_.Value
                    }
                }
                
                if ($data.eventIdCounter) {
                    $this.EventIdCounter = $data.eventIdCounter
                }
            } catch {}
        }
        
        $this.IsEnabled = $this.Config["CalendarEnabled"]
    }
    
    [void] SaveData() {
        $data = @{
            "events" = $this.Events
            "eventIdCounter" = $this.EventIdCounter
            "settings" = @{
                "showWeekNumbers" = $this.Config["CalendarShowWeekNumbers"]
                "firstDayOfWeek" = $this.Config["CalendarFirstDayOfWeek"]
                "defaultView" = $this.Config["CalendarDefaultView"]
                "showTasks" = $this.Config["CalendarShowTasks"]
            }
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content "goose_calendar.json"
    }
    
    [string] AddEvent([string]$title, [datetime]$date, [string]$time = "", [string]$type = "event", [string]$description = "") {
        $eventId = "evt_" + $this.EventIdCounter++
        
        $event = @{
            "id" = $eventId
            "title" = $title
            "date" = $date.ToString("yyyy-MM-dd")
            "time" = $time
            "type" = $type
            "description" = $description
            "createdAt" = (Get-Date).ToString("o")
            "reminder" = $null
            "completed" = $false
        }
        
        $this.Events[$eventId] = $event
        $this.SaveData()
        
        return $eventId
    }
    
    [bool] UpdateEvent([string]$eventId, [string]$title = $null, [datetime]$date = $null, [string]$time = $null, [string]$type = $null, [string]$description = $null) {
        if (-not $this.Events.ContainsKey($eventId)) {
            return $false
        }
        
        $event = $this.Events[$eventId]
        
        if ($title) { $event.title = $title }
        if ($date) { $event.date = $date.ToString("yyyy-MM-dd") }
        if ($time) { $event.time = $time }
        if ($type) { $event.type = $type }
        if ($description) { $event.description = $description }
        
        $this.Events[$eventId] = $event
        $this.SaveData()
        
        return $true
    }
    
    [bool] DeleteEvent([string]$eventId) {
        if ($this.Events.ContainsKey($eventId)) {
            $this.Events.Remove($eventId)
            $this.SaveData()
            return $true
        }
        return $false
    }
    
    [hashtable] GetEvent([string]$eventId) {
        if ($this.Events.ContainsKey($eventId)) {
            return $this.Events[$eventId]
        }
        return $null
    }
    
    [hashtable[]] GetEventsForDate([datetime]$date) {
        $dateStr = $date.ToString("yyyy-MM-dd")
        $result = @()
        
        foreach ($event in $this.Events.Values) {
            if ($event.date -eq $dateStr) {
                $result += $event
            }
        }
        
        return $result | Sort-Object { $_.time }
    }
    
    [hashtable[]] GetEventsForMonth([int]$year, [int]$month) {
        $result = @()
        $monthStr = "{0:D2}" -f $month
        
        foreach ($event in $this.Events.Values) {
            if ($event.date.StartsWith("$year-$monthStr")) {
                $result += $event
            }
        }
        
        return $result | Sort-Object { $_.date }, { $_.time }
    }
    
    [hashtable[]] GetEventsForWeek([datetime]$startDate) {
        $result = @()
        
        for ($i = 0; $i -lt 7; $i++) {
            $date = $startDate.AddDays($i)
            $result += $this.GetEventsForDate($date)
        }
        
        return $result
    }
    
    [hashtable] GetMonthData([int]$year, [int]$month) {
        $firstDay = Get-Date -Year $year -Month $month -Day 1
        $daysInMonth = [DateTime]::DaysInMonth($year, $month)
        $firstDayOfWeek = $this.Config["CalendarFirstDayOfWeek"]
        
        $startOffset = ($firstDay.DayOfWeek.Value__ - $firstDayOfWeek + 7) % 7
        
        $monthData = @{
            "year" = $year
            "month" = $month
            "monthName" = $firstDay.ToString("MMMM")
            "daysInMonth" = $daysInMonth
            "firstDayOfWeek" = $firstDayOfWeek
            "startOffset" = $startOffset
            "weeks" = @()
        }
        
        $day = 1
        $week = @()
        
        for ($i = 0; $i -lt $startOffset; $i++) {
            $week += $null
        }
        
        while ($day -le $daysInMonth) {
            $currentDate = Get-Date -Year $year -Month $month -Day $day
            $dateStr = $currentDate.ToString("yyyy-MM-dd")
            $dayEvents = @($this.Events.Values | Where-Object { $_.date -eq $dateStr })
            
            $dayData = @{
                "day" = $day
                "date" = $dateStr
                "isToday" = $currentDate.ToString("yyyy-MM-dd") -eq (Get-Date).ToString("yyyy-MM-dd")
                "isWeekend" = ($currentDate.DayOfWeek.Value__ -eq 0 -or $currentDate.DayOfWeek.Value__ -eq 6)
                "eventCount" = $dayEvents.Count
                "events" = $dayEvents
            }
            
            $week += $dayData
            $day++
            
            if ($week.Count -eq 7) {
                $monthData.weeks += ,@($week)
                $week = @()
            }
        }
        
        if ($week.Count -gt 0) {
            while ($week.Count -lt 7) {
                $week += $null
            }
            $monthData.weeks += ,@($week)
        }
        
        return $monthData
    }
    
    [hashtable] GetCalendarMonth() {
        return $this.GetMonthData($this.CurrentMonth.Year, $this.CurrentMonth.Month)
    }
    
    [void] NavigateNextMonth() {
        $this.CurrentMonth = $this.CurrentMonth.AddMonths(1)
    }
    
    [void] NavigatePreviousMonth() {
        $this.CurrentMonth = $this.CurrentMonth.AddMonths(-1)
    }
    
    [void] NavigateToMonth([int]$year, [int]$month) {
        $this.CurrentMonth = Get-Date -Year $year -Month $month -Day 1
    }
    
    [void] NavigateToToday() {
        $this.CurrentMonth = (Get-Date).Date
    }
    
    [int] GetWeekNumber([datetime]$date) {
        $cal = [System.Globalization.CultureInfo]::CurrentCulture.Calendar
        $weekRule = [System.Globalization.CalendarWeekRule]::FirstFourDayWeek
        $firstDayOfWeek = [System.DayOfWeek]::Sunday
        
        return $cal.GetWeekOfYear($date, $weekRule, $firstDayOfWeek)
    }
    
    [void] SetEnabled([bool]$enabled) {
        $this.IsEnabled = $enabled
        $this.Config["CalendarEnabled"] = $enabled
    }
    
    [void] Toggle() {
        $this.IsEnabled = -not $this.IsEnabled
        $this.Config["CalendarEnabled"] = $this.IsEnabled
    }
    
    [hashtable[]] GetUpcomingEvents([int]$days = 7) {
        $today = (Get-Date).Date
        $endDate = $today.AddDays($days)
        $upcoming = @()
        
        foreach ($event in $this.Events.Values) {
            $eventDate = [datetime]::Parse($event.date)
            if ($eventDate -ge $today -and $eventDate -le $endDate) {
                $upcoming += $event
            }
        }
        
        return $upcoming | Sort-Object { $_.date }
    }
    
    [hashtable] GetCalendarState() {
        return @{
            "Enabled" = $this.IsEnabled
            "CurrentMonth" = $this.CurrentMonth
            "MonthData" = $this.GetCalendarMonth()
            "ShowWeekNumbers" = $this.Config["CalendarShowWeekNumbers"]
            "FirstDayOfWeek" = $this.Config["CalendarFirstDayOfWeek"]
            "DefaultView" = $this.Config["CalendarDefaultView"]
            "ShowTasks" = $this.Config["CalendarShowTasks"]
            "UpcomingEvents" = $this.GetUpcomingEvents(7)
            "TotalEvents" = $this.Events.Count
        }
    }
    
    [string] GetWidgetHtml() {
        $state = $this.GetCalendarState()
        $monthData = $state.MonthData
        
        $html = "<div class='calendar-widget'>"
        $html += "<div class='calendar-header'>"
        $html += "<button onclick='prevMonth()'>◀</button>"
        $html += "<span>$($monthData.monthName) $($monthData.year)</span>"
        $html += "<button onclick='nextMonth()'>▶</button>"
        $html += "</div>"
        
        $days = @("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")
        $html += "<div class='calendar-days'>"
        foreach ($day in $days) {
            $html += "<div class='calendar-day-header'>$day</div>"
        }
        $html += "</div>"
        
        $html += "<div class='calendar-grid'>"
        foreach ($week in $monthData.weeks) {
            $html += "<div class='calendar-week'>"
            foreach ($dayData in $week) {
                if ($dayData -eq $null) {
                    $html += "<div class='calendar-day empty'></div>"
                } else {
                    $classes = "calendar-day"
                    if ($dayData.isToday) { $classes += " today" }
                    if ($dayData.isWeekend) { $classes += " weekend" }
                    if ($dayData.eventCount -gt 0) { $classes += " has-events" }
                    
                    $html += "<div class='$classes'>"
                    $html += "<span class='day-number'>$($dayData.day)</span>"
                    if ($dayData.eventCount -gt 0) {
                        $html += "<span class='event-dots'>"
                        for ($i = 0; $i -lt [Math]::Min($dayData.eventCount, 3); $i++) {
                            $html += "<span class='event-dot'></span>"
                        }
                        $html += "</span>"
                    }
                    $html += "</div>"
                }
            }
            $html += "</div>"
        }
        $html += "</div>"
        $html += "</div>"
        
        return $html
    }
}

$gooseCalendar = [GooseCalendar]::new()

function Get-GooseCalendar {
    return $gooseCalendar
}

function Get-CalendarMonth {
    param($Calendar = $gooseCalendar)
    return $Calendar.GetCalendarMonth()
}

function Add-CalendarEvent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [Parameter(Mandatory=$true)]
        [datetime]$Date,
        [string]$Time = "",
        [string]$Type = "event",
        [string]$Description = "",
        $Calendar = $gooseCalendar
    )
    return $Calendar.AddEvent($Title, $Date, $Time, $Type, $Description)
}

function Update-CalendarEvent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$EventId,
        [string]$Title = $null,
        [datetime]$Date = $null,
        [string]$Time = $null,
        [string]$Type = $null,
        [string]$Description = $null,
        $Calendar = $gooseCalendar
    )
    return $Calendar.UpdateEvent($EventId, $Title, $Date, $Time, $Type, $Description)
}

function Delete-CalendarEvent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$EventId,
        $Calendar = $gooseCalendar
    )
    return $Calendar.DeleteEvent($EventId)
}

function Get-CalendarEvent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$EventId,
        $Calendar = $gooseCalendar
    )
    return $Calendar.GetEvent($EventId)
}

function Get-EventsForDate {
    param(
        [Parameter(Mandatory=$true)]
        [datetime]$Date,
        $Calendar = $gooseCalendar
    )
    return $Calendar.GetEventsForDate($Date)
}

function Navigate-CalendarNext {
    param($Calendar = $gooseCalendar)
    $Calendar.NavigateNextMonth()
}

function Navigate-CalendarPrevious {
    param($Calendar = $gooseCalendar)
    $Calendar.NavigatePreviousMonth()
}

function Navigate-CalendarToday {
    param($Calendar = $gooseCalendar)
    $Calendar.NavigateToToday()
}

function Get-CalendarState {
    param($Calendar = $gooseCalendar)
    return $Calendar.GetCalendarState()
}

function Get-UpcomingEvents {
    param(
        [int]$Days = 7,
        $Calendar = $gooseCalendar
    )
    return $Calendar.GetUpcomingEvents($Days)
}

function Enable-Calendar {
    param($Calendar = $gooseCalendar)
    $Calendar.SetEnabled($true)
}

function Disable-Calendar {
    param($Calendar = $gooseCalendar)
    $Calendar.SetEnabled($false)
}

function Toggle-Calendar {
    param($Calendar = $gooseCalendar)
    $Calendar.Toggle()
}

Write-Host "Desktop Goose Calendar Widget Initialized"
$state = Get-CalendarState
Write-Host "Calendar Enabled: $($state['Enabled'])"
Write-Host "Total Events: $($state['TotalEvents'])"
