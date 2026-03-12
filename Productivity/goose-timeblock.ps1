# Desktop Goose Time Blocking System
# Schedule and manage time blocks for productivity

class GooseTimeBlock {
    [hashtable]$Config
    [hashtable]$Blocks
    [hashtable]$Templates
    [int]$BlockIdCounter
    [bool]$IsEnabled
    [string]$CurrentView
    [datetime]$CurrentWeekStart
    
    GooseTimeBlock() {
        $this.Config = $this.LoadConfig()
        $this.Blocks = @{}
        $this.Templates = @{}
        $this.BlockIdCounter = 1
        $this.IsEnabled = $false
        $this.CurrentView = "week"
        $this.CurrentWeekStart = $this.GetWeekStart((Get-Date))
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
        
        if (-not $this.Config.ContainsKey("TimeBlockEnabled")) {
            $this.Config["TimeBlockEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("TimeBlockDefaultDuration")) {
            $this.Config["TimeBlockDefaultDuration"] = 30
        }
        if (-not $this.Config.ContainsKey("BreakReminderMinutes")) {
            $this.Config["BreakReminderMinutes"] = 25
        }
        if (-not $this.Config.ContainsKey("TimeBlockShowPomodoro")) {
            $this.Config["TimeBlockShowPomodoro"] = $true
        }
        
        return $this.Config
    }
    
    [void] LoadData() {
        $dataFile = "goose_timeblocks.json"
        
        if (Test-Path $dataFile) {
            try {
                $data = Get-Content $dataFile -Raw | ConvertFrom-Json
                
                if ($data.blocks) {
                    $this.Blocks = @{}
                    $data.blocks.PSObject.Properties | ForEach-Object {
                        $this.Blocks[$_.Name] = $_.Value
                    }
                }
                
                if ($data.templates) {
                    $this.Templates = @{}
                    $data.templates.PSObject.Properties | ForEach-Object {
                        $this.Templates[$_.Name] = $_.Value
                    }
                }
                
                if ($data.blockIdCounter) {
                    $this.BlockIdCounter = $data.blockIdCounter
                }
            } catch {}
        }
        
        $this.IsEnabled = $this.Config["TimeBlockEnabled"]
        $this.LoadDefaultTemplates()
    }
    
    [void] LoadDefaultTemplates() {
        if ($this.Templates.Count -eq 0) {
            $this.Templates = @{
                "Deep Work" = @{
                    "name" = "Deep Work"
                    "color" = "#4A90D9"
                    "duration" = 60
                    "icon" = "brain"
                }
                "Meeting" = @{
                    "name" = "Meeting"
                    "color" = "#E74C3C"
                    "duration" = 30
                    "icon" = "users"
                }
                "Break" = @{
                    "name" = "Break"
                    "color" = "#27AE60"
                    "duration" = 15
                    "icon" = "coffee"
                }
                "Email" = @{
                    "name" = "Email"
                    "color" = "#9B59B6"
                    "duration" = 30
                    "icon" = "mail"
                }
                "Planning" = @{
                    "name" = "Planning"
                    "color" = "#F39C12"
                    "duration" = 15
                    "icon" = "clipboard"
                }
            }
        }
    }
    
    [void] SaveData() {
        $data = @{
            "blocks" = $this.Blocks
            "templates" = $this.Templates
            "blockIdCounter" = $this.BlockIdCounter
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content "goose_timeblocks.json"
    }
    
    [datetime] GetWeekStart([datetime]$date) {
        $dayOfWeek = [int]$date.DayOfWeek
        return $date.AddDays(-$dayOfWeek).Date
    }
    
    [string] AddBlock([datetime]$startTime, [int]$durationMinutes, [string]$title, [string]$color = "#4A90D9", [string]$type = "custom") {
        $blockId = "block_" + $this.BlockIdCounter++
        $endTime = $startTime.AddMinutes($durationMinutes)
        
        $block = @{
            "id" = $blockId
            "title" = $title
            "startTime" = $startTime.ToString("o")
            "endTime" = $endTime.ToString("o")
            "duration" = $durationMinutes
            "color" = $color
            "type" = $type
            "completed" = $false
            "pomodoroCount" = 0
            "createdAt" = (Get-Date).ToString("o")
        }
        
        $this.Blocks[$blockId] = $block
        $this.SaveData()
        
        return $blockId
    }
    
    [string] AddBlockFromTemplate([string]$templateName, [datetime]$startTime) {
        if (-not $this.Templates.ContainsKey($templateName)) {
            return $null
        }
        
        $template = $this.Templates[$templateName]
        return $this.AddBlock($startTime, $template.duration, $template.name, $template.color, $template.type)
    }
    
    [bool] UpdateBlock([string]$blockId, [datetime]$startTime = $null, [int]$durationMinutes = $null, [string]$title = $null, [string]$color = $null) {
        if (-not $this.Blocks.ContainsKey($blockId)) {
            return $false
        }
        
        $block = $this.Blocks[$blockId]
        
        if ($startTime) { $block.startTime = $startTime.ToString("o") }
        if ($durationMinutes) {
            $block.duration = $durationMinutes
            $block.endTime = [datetime]::Parse($block.startTime).AddMinutes($durationMinutes).ToString("o")
        }
        if ($title) { $block.title = $title }
        if ($color) { $block.color = $color }
        
        $this.Blocks[$blockId] = $block
        $this.SaveData()
        
        return $true
    }
    
    [bool] DeleteBlock([string]$blockId) {
        if ($this.Blocks.ContainsKey($blockId)) {
            $this.Blocks.Remove($blockId)
            $this.SaveData()
            return $true
        }
        return $false
    }
    
    [bool] CompleteBlock([string]$blockId) {
        if (-not $this.Blocks.ContainsKey($blockId)) {
            return $false
        }
        
        $this.Blocks[$blockId].completed = $true
        $this.SaveData()
        
        return $true
    }
    
    [bool] UncompleteBlock([string]$blockId) {
        if (-not $this.Blocks.ContainsKey($blockId)) {
            return $false
        }
        
        $this.Blocks[$blockId].completed = $false
        $this.SaveData()
        
        return $true
    }
    
    [hashtable] GetBlock([string]$blockId) {
        if ($this.Blocks.ContainsKey($blockId)) {
            return $this.Blocks[$blockId]
        }
        return $null
    }
    
    [hashtable[]] GetBlocksForDay([datetime]$date) {
        $dateStr = $date.ToString("yyyy-MM-dd")
        $result = @()
        
        foreach ($block in $this.Blocks.Values) {
            $blockDate = [datetime]::Parse($block.startTime).ToString("yyyy-MM-dd")
            if ($blockDate -eq $dateStr) {
                $result += $block
            }
        }
        
        return $result | Sort-Object { $_.startTime }
    }
    
    [hashtable[]] GetBlocksForWeek([datetime]$weekStart) {
        $result = @()
        
        for ($i = 0; $i -lt 7; $i++) {
            $date = $weekStart.AddDays($i)
            $result += $this.GetBlocksForDay($date)
        }
        
        return $result
    }
    
    [hashtable[]] GetTodayBlocks() {
        return $this.GetBlocksForDay((Get-Date).Date)
    }
    
    [hashtable[]] GetCurrentBlock() {
        $now = Get-Date
        
        foreach ($block in $this.Blocks.Values) {
            $start = [datetime]::Parse($block.startTime)
            $end = [datetime]::Parse($block.endTime)
            
            if ($now -ge $start -and $now -lt $end -and -not $block.completed) {
                return $block
            }
        }
        
        return $null
    }
    
    [hashtable[]] GetUpcomingBlocks([int]$hours = 2) {
        $now = Get-Date
        $endTime = $now.AddHours($hours)
        $result = @()
        
        foreach ($block in $this.Blocks.Values) {
            $start = [datetime]::Parse($block.startTime)
            if ($start -ge $now -and $start -le $endTime -and -not $block.completed) {
                $result += $block
            }
        }
        
        return $result | Sort-Object { $_.startTime }
    }
    
    [void] NavigateNextWeek() {
        $this.CurrentWeekStart = $this.CurrentWeekStart.AddDays(7)
    }
    
    [void] NavigatePreviousWeek() {
        $this.CurrentWeekStart = $this.CurrentWeekStart.AddDays(-7)
    }
    
    [void] NavigateToCurrentWeek() {
        $this.CurrentWeekStart = $this.GetWeekStart((Get-Date))
    }
    
    [hashtable] AddTemplate([string]$name, [int]$duration, [string]$color, [string]$icon = "clock") {
        $template = @{
            "name" = $name
            "color" = $color
            "duration" = $duration
            "icon" = $icon
        }
        
        $this.Templates[$name] = $template
        $this.SaveData()
        
        return $template
    }
    
    [bool] DeleteTemplate([string]$name) {
        if ($this.Templates.ContainsKey($name)) {
            $this.Templates.Remove($name)
            $this.SaveData()
            return $true
        }
        return $false
    }
    
    [hashtable[]] GetWeekData() {
        $weekData = @()
        
        for ($i = 0; $i -lt 7; $i++) {
            $date = $this.CurrentWeekStart.AddDays($i)
            $dayBlocks = $this.GetBlocksForDay($date)
            
            $dayData = @{
                "date" = $date
                "dateStr" = $date.ToString("yyyy-MM-dd")
                "dayName" = $date.DayOfWeek.ToString()
                "dayNumber" = $date.Day
                "isToday" = $date.Date -eq (Get-Date).Date
                "blocks" = $dayBlocks
                "totalMinutes" = ($dayBlocks | Measure-Object -Property duration -Sum).Sum
                "completedMinutes" = (($dayBlocks | Where-Object { $_.completed }) | Measure-Object -Property duration -Sum).Sum
            }
            
            $weekData += $dayData
        }
        
        return $weekData
    }
    
    [hashtable] GetStats() {
        $today = (Get-Date).Date
        $todayBlocks = $this.GetBlocksForDay($today)
        
        $totalMinutes = ($todayBlocks | Measure-Object -Property duration -Sum).Sum
        $completedMinutes = (($todayBlocks | Where-Object { $_.completed }) | Measure-Object -Property duration -Sum).Sum
        
        return @{
            "todayBlocks" = $todayBlocks.Count
            "completedBlocks" = ($todayBlocks | Where-Object { $_.completed }).Count
            "totalMinutes" = $totalMinutes
            "completedMinutes" = $completedMinutes
            "remainingMinutes" = $totalMinutes - $completedMinutes
            "completionPercent" = if ($totalMinutes -gt 0) { [Math]::Round(($completedMinutes / $totalMinutes) * 100) } else { 0 }
        }
    }
    
    [void] SetEnabled([bool]$enabled) {
        $this.IsEnabled = $enabled
        $this.Config["TimeBlockEnabled"] = $enabled
    }
    
    [void] Toggle() {
        $this.IsEnabled = -not $this.IsEnabled
        $this.Config["TimeBlockEnabled"] = $this.IsEnabled
    }
    
    [hashtable] GetTimeBlockState() {
        return @{
            "Enabled" = $this.IsEnabled
            "CurrentView" = $this.CurrentView
            "CurrentWeekStart" = $this.CurrentWeekStart
            "WeekData" = $this.GetWeekData()
            "TodayBlocks" = $this.GetTodayBlocks()
            "CurrentBlock" = $this.GetCurrentBlock()
            "UpcomingBlocks" = $this.GetUpcomingBlocks(2)
            "Templates" = $this.Templates
            "Stats" = $this.GetStats()
            "DefaultDuration" = $this.Config["TimeBlockDefaultDuration"]
            "ShowPomodoro" = $this.Config["TimeBlockShowPomodoro"]
        }
    }
    
    [string] GetWidgetHtml() {
        $state = $this.GetTimeBlockState()
        
        $html = "<div class='timeblock-widget'>"
        $html += "<div class='timeblock-header'>"
        $html += "<button onclick='prevWeek()'>◀</button>"
        $html += "<span>Week of $($state.CurrentWeekStart.ToString('MMM d'))</span>"
        $html += "<button onclick='nextWeek()'>▶</button>"
        $html += "</div>"
        
        foreach ($day in $state.WeekData) {
            $todayClass = if ($day.isToday) { "today" } else { "" }
            $html += "<div class='timeblock-day $todayClass'>"
            $html += "<div class='day-header'>$($day.dayName) $($day.dayNumber)</div>"
            
            if ($day.blocks.Count -gt 0) {
                foreach ($block in $day.blocks) {
                    $completedClass = if ($block.completed) { "completed" } else { "" }
                    $html += "<div class='timeblock-item $completedClass' style='border-left-color: $($block.color)'>"
                    $startTime = [datetime]::Parse($block.startTime).ToString("HH:mm")
                    $html += "<span class='block-time'>$startTime</span>"
                    $html += "<span class='block-title'>$($block.title)</span>"
                    $html += "<span class='block-duration'>$($block.duration)m</span>"
                    $html += "</div>"
                }
            } else {
                $html += "<div class='no-blocks'>No blocks</div>"
            }
            
            $html += "</div>"
        }
        
        $html += "<div class='timeblock-stats'>"
        $stats = $state.Stats
        $html += "<span>Today: $($stats.completedMinutes)/$($stats.totalMinutes) min</span>"
        $html += "<span>$($stats.completionPercent)% complete</span>"
        $html += "</div>"
        
        $html += "</div>"
        
        return $html
    }
}

$gooseTimeBlock = [GooseTimeBlock]::new()

function Get-GooseTimeBlock {
    return $gooseTimeBlock
}

function Add-TimeBlock {
    param(
        [Parameter(Mandatory=$true)]
        [datetime]$StartTime,
        [Parameter(Mandatory=$true)]
        [int]$DurationMinutes,
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [string]$Color = "#4A90D9",
        [string]$Type = "custom",
        $TimeBlock = $gooseTimeBlock
    )
    return $TimeBlock.AddBlock($StartTime, $DurationMinutes, $Title, $Color, $Type)
}

function Add-TimeBlockFromTemplate {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TemplateName,
        [Parameter(Mandatory=$true)]
        [datetime]$StartTime,
        $TimeBlock = $gooseTimeBlock
    )
    return $TimeBlock.AddBlockFromTemplate($TemplateName, $StartTime)
}

function Update-TimeBlock {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BlockId,
        [datetime]$StartTime,
        [int]$DurationMinutes,
        [string]$Title,
        [string]$Color,
        $TimeBlock = $gooseTimeBlock
    )
    return $TimeBlock.UpdateBlock($BlockId, $StartTime, $DurationMinutes, $Title, $Color)
}

function Remove-TimeBlock {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BlockId,
        $TimeBlock = $gooseTimeBlock
    )
    return $TimeBlock.DeleteBlock($BlockId)
}

function Complete-TimeBlock {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BlockId,
        $TimeBlock = $gooseTimeBlock
    )
    return $TimeBlock.CompleteBlock($BlockId)
}

function Get-TimeBlock {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BlockId,
        $TimeBlock = $gooseTimeBlock
    )
    return $TimeBlock.GetBlock($BlockId)
}

function Get-TodayBlocks {
    param($TimeBlock = $gooseTimeBlock)
    return $TimeBlock.GetTodayBlocks()
}

function Get-CurrentBlock {
    param($TimeBlock = $gooseTimeBlock)
    return $TimeBlock.GetCurrentBlock()
}

function Get-UpcomingBlocks {
    param(
        [int]$Hours = 2,
        $TimeBlock = $gooseTimeBlock
    )
    return $TimeBlock.GetUpcomingBlocks($Hours)
}

function Navigate-NextWeek {
    param($TimeBlock = $gooseTimeBlock)
    $TimeBlock.NavigateNextWeek()
}

function Navigate-PreviousWeek {
    param($TimeBlock = $gooseTimeBlock)
    $TimeBlock.NavigatePreviousWeek()
}

function Navigate-ThisWeek {
    param($TimeBlock = $gooseTimeBlock)
    $TimeBlock.NavigateToCurrentWeek()
}

function Get-TimeBlockState {
    param($TimeBlock = $gooseTimeBlock)
    return $TimeBlock.GetTimeBlockState()
}

function Get-TimeBlockStats {
    param($TimeBlock = $gooseTimeBlock)
    return $TimeBlock.GetStats()
}

function Add-TimeBlockTemplate {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [int]$Duration,
        [Parameter(Mandatory=$true)]
        [string]$Color,
        [string]$Icon = "clock",
        $TimeBlock = $gooseTimeBlock
    )
    return $TimeBlock.AddTemplate($Name, $Duration, $Color, $Icon)
}

function Remove-TimeBlockTemplate {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        $TimeBlock = $gooseTimeBlock
    )
    return $TimeBlock.DeleteTemplate($Name)
}

function Enable-TimeBlock {
    param($TimeBlock = $gooseTimeBlock)
    $TimeBlock.SetEnabled($true)
}

function Disable-TimeBlock {
    param($TimeBlock = $gooseTimeBlock)
    $TimeBlock.SetEnabled($false)
}

function Toggle-TimeBlock {
    param($TimeBlock = $gooseTimeBlock)
    $TimeBlock.Toggle()
}

Write-Host "Desktop Goose Time Blocking System Initialized"
$state = Get-TimeBlockState
Write-Host "Time Block Enabled: $($state['Enabled'])"
Write-Host "Today Blocks: $($state['Stats']['todayBlocks'])"
