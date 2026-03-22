class GooseDailyBriefing {
    [hashtable]$Config
    [string]$DataPath
    [object]$Telemetry
    [hashtable]$WeatherCache
    [datetime]$WeatherCacheTime
    
    GooseDailyBriefing([string]$configFile = "config.ini", [object]$telemetry = $null) {
        $this.Telemetry = $telemetry
        $this.LoadConfig($configFile)
        $this.DataPath = Join-Path $PSScriptRoot "briefing_data"
        if (-not (Test-Path $this.DataPath)) {
            New-Item -ItemType Directory -Path $this.DataPath -Force | Out-Null
        }
        $this.WeatherCache = @{}
        $this.WeatherCacheTime = [datetime]::MinValue
    }
    
    [void] LoadConfig([string]$configFile) {
        $this.Config = @{
            Enabled = $true
            Location = ""
            TemperatureUnit = "Celsius"
            ShowCalendar = $true
            ShowTasks = $true
            ShowWeather = $true
            ShowQuote = $true
            BriefingTime = "08:00"
            AutoShowOnStartup = $false
        }
        if (Test-Path $configFile) {
            Get-Content $configFile | ForEach-Object {
                if ($_ -match '^([^=]+)=(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    if ($this.Config.ContainsKey($key)) {
                        if ($value -eq 'True' -or $value -eq 'False') {
                            $this.Config[$key] = [bool]$value
                        } else {
                            $this.Config[$key] = $value
                        }
                    }
                }
            }
        }
    }
    
    [hashtable] GetWeather([string]$location = "") {
        $this.Telemetry?.IncrementCounter("briefing.weather_fetched", 1)
        if ($location -eq "") {
            $location = $this.Config["Location"]
        }
        if (-not $location) {
            return @{temp=0; condition="Unknown"; icon="🌤️"; location="Not set"}
        }
        if ($this.WeatherCache[$location] -and ((Get-Date) - $this.WeatherCacheTime).TotalMinutes -lt 30) {
            return $this.WeatherCache[$location]
        }
        try {
            $temp = Get-Random -Minimum 15 -Maximum 30
            $conditions = @("Sunny", "Cloudy", "Partly Cloudy", "Rainy", "Clear")
            $condition = $conditions | Get-Random
            $icons = @{
                "Sunny" = "☀️"
                "Cloudy" = "☁️"
                "Partly Cloudy" = "⛅"
                "Rainy" = "🌧️"
                "Clear" = "🌙"
            }
            $result = @{
                temp = $temp
                condition = $condition
                icon = $icons[$condition]
                location = $location
                humidity = Get-Random -Minimum 30 -Maximum 80
            }
            $this.WeatherCache[$location] = $result
            $this.WeatherCacheTime = Get-Date
            return $result
        } catch {
            return @{temp=0; condition="Error"; icon="❓"; location=$location}
        }
    }
    
    [array] GetTodayEvents() {
        $eventsFile = Join-Path $this.DataPath "events.json"
        $events = @()
        if (Test-Path $eventsFile) {
            try {
                $events = @(Get-Content $eventsFile -Raw | ConvertFrom-Json)
            } catch { }
        }
        $today = (Get-Date).ToString("yyyy-MM-dd")
        return @($events | Where-Object { $_.date -eq $today })
    }
    
    [array] GetTasks() {
        $tasksFile = Join-Path $this.DataPath "tasks.json"
        $tasks = @()
        if (Test-Path $tasksFile) {
            try {
                $tasks = @(Get-Content $tasksFile -Raw | ConvertFrom-Json)
            } catch { }
        }
        return @($tasks | Where-Object { -not $_.completed })
    }
    
    [string] GetMotivationalQuote() {
        $this.Telemetry?.IncrementCounter("briefing.quotes_fetched", 1)
        $quotes = @(
            @{text="The only way to do great work is to love what you do."; author="Steve Jobs"},
            @{text="Believe you can and you're halfway there."; author="Theodore Roosevelt"},
            @{text="Success is not final, failure is not fatal."; author="Winston Churchill"},
            @{text="The best time to plant a tree was 20 years ago. The second best time is now."; author="Chinese Proverb"},
            @{text="Your time is limited, don't waste it living someone else's life."; author="Steve Jobs"},
            @{text="Stay hungry, stay foolish."; author="Steve Jobs"},
            @{text="The future belongs to those who believe in the beauty of their dreams."; author="Eleanor Roosevelt"},
            @{text="It does not matter how slowly you go as long as you do not stop."; author="Confucius"},
            @{text="Quality is not an act, it is a habit."; author="Aristotle"},
            @{text="The only impossible journey is the one you never begin."; author="Tony Robbins"}
        )
        return ($quotes | Get-Random | ForEach-Object { "$($_.text) - $($_.author)" })
    }
    
    [hashtable] GetBriefingData() {
        $this.Telemetry?.IncrementCounter("briefing.viewed", 1)
        $data = @{
            date = Get-Date -Format "dddd, MMMM d, yyyy"
            greeting = $this.GetGreeting()
            weather = if ($this.Config["ShowWeather"]) { $this.GetWeather() } else { $null }
            events = if ($this.Config["ShowCalendar"]) { $this.GetTodayEvents() } else { @() }
            tasks = if ($this.Config["ShowTasks"]) { $this.GetTasks() } else { @() }
            quote = if ($this.Config["ShowQuote"]) { $this.GetMotivationalQuote() } else { "" }
            gooseMessage = $this.GetGooseMessage()
        }
        return $data
    }
    
    [string] GetGreeting() {
        $hour = (Get-Date).Hour
        if ($hour -lt 12) { return "Good Morning!" }
        elseif ($hour -lt 17) { return "Good Afternoon!" }
        else { return "Good Evening!" }
    }
    
    [string] GetGooseMessage() {
        $messages = @(
            "Let's make today count! 🦆",
            "Ready for a productive day?",
            "The goose believes in you!",
            "Time to honk some code!",
            "You've got this!"
        )
        return $messages | Get-Random
    }
    
    [void] ShowBriefing() {
        $data = $this.GetBriefingData()
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $form = New-Object System.Windows.Forms.Form
        $form.Text = "Desktop Goose - Daily Briefing"
        $form.Size = New-Object System.Drawing.Size(500, 600)
        $form.StartPosition = "CenterScreen"
        $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
        $form.FormBorderStyle = "FixedDialog"
        $form.MaximizeBox = $false
        $headerPanel = New-Object System.Windows.Forms.Panel
        $headerPanel.Dock = "Top"
        $headerPanel.Height = 80
        $headerPanel.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
        $form.Controls.Add($headerPanel)
        $lblGreeting = New-Object System.Windows.Forms.Label
        $lblGreeting.Text = $data.greeting
        $lblGreeting.Dock = "Top"
        $lblGreeting.Padding = New-Object System.Windows.Forms.Padding(20, 15, 0, 0)
        $lblGreeting.Font = New-Object System.Drawing.Font("Segoe UI", 18, [System.Drawing.FontStyle]::Bold)
        $lblGreeting.ForeColor = [System.Drawing.Color]::White
        $headerPanel.Controls.Add($lblGreeting)
        $lblDate = New-Object System.Windows.Forms.Label
        $lblDate.Text = $data.date
        $lblDate.Dock = "Top"
        $lblDate.Padding = New-Object System.Windows.Forms.Padding(20, 5, 0, 0)
        $lblDate.Font = New-Object System.Drawing.Font("Segoe UI", 10)
        $lblDate.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 205)
        $headerPanel.Controls.Add($lblDate)
        $gooseIcon = New-Object System.Windows.Forms.Label
        $gooseIcon.Text = "🦆"
        $gooseIcon.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 24)
        $gooseIcon.Location = New-Object System.Drawing.Point(400, 15)
        $gooseIcon.Size = New-Object System.Drawing.Size(60, 50)
        $headerPanel.Controls.Add($gooseIcon)
        $contentPanel = New-Object System.Windows.Forms.Panel
        $contentPanel.Dock = "Fill"
        $contentPanel.AutoScroll = $true
        $form.Controls.Add($contentPanel)
        $y = 20
        if ($data.weather) {
            $weatherPanel = $this.CreateSection("Weather", $contentPanel, 20, $y)
            $weatherIcon = New-Object System.Windows.Forms.Label
            $weatherIcon.Text = $data.weather.icon
            $weatherIcon.Font = New-Object System.Drawing.Font("Segoe UI Emoji", 32)
            $weatherIcon.Location = New-Object System.Drawing.Point(30, 30)
            $weatherIcon.Size = New-Object System.Drawing.Size(50, 50)
            $weatherPanel.Controls.Add($weatherIcon)
            $weatherTemp = New-Object System.Windows.Forms.Label
            $weatherTemp.Text = "$($data.weather.temp)°"
            $weatherTemp.Font = New-Object System.Drawing.Font("Segoe UI", 24, [System.Drawing.FontStyle]::Bold)
            $weatherTemp.Location = New-Object System.Drawing.Point(90, 30)
            $weatherTemp.Size = New-Object System.Drawing.Size(100, 40)
            $weatherTemp.ForeColor = [System.Drawing.Color]::White
            $weatherPanel.Controls.Add($weatherTemp)
            $weatherCond = New-Object System.Windows.Forms.Label
            $weatherCond.Text = "$($data.weather.condition) in $($data.weather.location)"
            $weatherCond.Location = New-Object System.Drawing.Point(90, 70)
            $weatherCond.Size = New-Object System.Drawing.Size(200, 20)
            $weatherCond.ForeColor = [System.Drawing.Color]::FromArgb(180, 180, 185)
            $weatherPanel.Controls.Add($weatherCond)
            $y += 120
        }
        if ($data.events.Count -gt 0) {
            $eventsPanel = $this.CreateSection("Today's Events", $contentPanel, 20, $y)
            $eventY = 30
            foreach ($event in $data.events) {
                $lblEvent = New-Object System.Windows.Forms.Label
                $lblEvent.Text = "📅 $($event.time) - $($event.title)"
                $lblEvent.Location = New-Object System.Drawing.Point(30, $eventY)
                $lblEvent.Size = New-Object System.Drawing.Size(400, 25)
                $lblEvent.ForeColor = [System.Drawing.Color]::White
                $eventsPanel.Controls.Add($lblEvent)
                $eventY += 25
            }
            $y += ($data.events.Count * 25) + 50
        }
        if ($data.tasks.Count -gt 0) {
            $tasksPanel = $this.CreateSection("Tasks for Today", $contentPanel, 20, $y)
            $taskY = 30
            foreach ($task in $data.tasks | Select-Object -First 5) {
                $lblTask = New-Object System.Windows.Forms.Label
                $lblTask.Text = "☐ $($task.title)"
                $lblTask.Location = New-Object System.Drawing.Point(30, $taskY)
                $lblTask.Size = New-Object System.Drawing.Size(400, 25)
                $lblTask.ForeColor = [System.Drawing.Color]::White
                $tasksPanel.Controls.Add($lblTask)
                $taskY += 25
            }
            $y += ($data.tasks.Count * 25) + 50
        }
        if ($data.quote) {
            $quotePanel = $this.CreateSection("Daily Motivation", $contentPanel, 20, $y)
            $lblQuote = New-Object System.Windows.Forms.Label
            $lblQuote.Text = "`"$($data.quote -replace ' - ', "`"`n- ")"
            $lblQuote.Location = New-Object System.Drawing.Point(30, 35)
            $lblQuote.Size = New-Object System.Drawing.Size(400, 60)
            $lblQuote.Font = New-Object System.Drawing.Font("Segoe UI", 9, [System.Drawing.FontStyle]::Italic)
            $lblQuote.ForeColor = [System.Drawing.Color]::FromArgb(200, 200, 205)
            $quotePanel.Controls.Add($lblQuote)
            $y += 100
        }
        $gooseMsg = New-Object System.Windows.Forms.Label
        $gooseMsg.Text = $data.gooseMessage
        $gooseMsg.Location = New-Object System.Drawing.Point(20, $y)
        $gooseMsg.Size = New-Object System.Drawing.Size(460, 30)
        $gooseMsg.Font = New-Object System.Drawing.Font("Segoe UI", 11)
        $gooseMsg.ForeColor = [System.Drawing.Color]::FromArgb(0, 200, 120)
        $gooseMsg.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
        $contentPanel.Controls.Add($gooseMsg)
        $btnClose = New-Object System.Windows.Forms.Button
        $btnClose.Text = "Let's Go!"
        $btnClose.Location = New-Object System.Drawing.Point(180, ($y + 40))
        $btnClose.Size = New-Object System.Drawing.Size(140, 40)
        $btnClose.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
        $btnClose.ForeColor = [System.Drawing.Color]::White
        $btnClose.FlatStyle = "Flat"
        $btnClose.Add_Click({ $form.Close() })
        $contentPanel.Controls.Add($btnClose)
        $form.ShowDialog()
    }
    
    [System.Windows.Forms.GroupBox] CreateSection([string]$title, [System.Windows.Forms.Panel]$parent, [int]$x, [int]$y) {
        $section = New-Object System.Windows.Forms.GroupBox
        $section.Text = $title
        $section.Location = New-Object System.Drawing.Point($x, $y)
        $section.Size = New-Object System.Drawing.Size(460, 100)
        $section.ForeColor = [System.Drawing.Color]::White
        $section.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
        $parent.Controls.Add($section)
        return $section
    }
    
    [void] AddEvent([string]$title, [string]$time, [string]$date = "") {
        if ($date -eq "") {
            $date = (Get-Date).ToString("yyyy-MM-dd")
        }
        $eventsFile = Join-Path $this.DataPath "events.json"
        $events = @()
        if (Test-Path $eventsFile) {
            try { $events = @(Get-Content $eventsFile -Raw | ConvertFrom-Json) } catch { }
        }
        $events += @{
            id = [guid]::NewGuid().ToString()
            title = $title
            time = $time
            date = $date
            createdAt = (Get-Date).ToString("o")
        }
        $events | ConvertTo-Json -Depth 10 | Set-Content -Path $eventsFile
    }
    
    [void] AddTask([string]$title) {
        $tasksFile = Join-Path $this.DataPath "tasks.json"
        $tasks = @()
        if (Test-Path $tasksFile) {
            try { $tasks = @(Get-Content $tasksFile -Raw | ConvertFrom-Json) } catch { }
        }
        $tasks += @{
            id = [guid]::NewGuid().ToString()
            title = $title
            completed = $false
            createdAt = (Get-Date).ToString("o")
        }
        $tasks | ConvertTo-Json -Depth 10 | Set-Content -Path $tasksFile
    }
}

$gooseDailyBriefing = $null

function Get-DailyBriefing {
    param([object]$Telemetry = $null)
    if ($script:gooseDailyBriefing -eq $null) {
        $script:gooseDailyBriefing = [GooseDailyBriefing]::new("config.ini", $Telemetry)
    }
    return $script:gooseDailyBriefing
}

function Show-DailyBriefing {
    $briefing = Get-DailyBriefing
    $briefing.ShowBriefing()
}

function Add-BriefingEvent {
    param([string]$Title, [string]$Time, [string]$Date = "")
    $briefing = Get-DailyBriefing
    $briefing.AddEvent($Title, $Time, $Date)
}

function Add-BriefingTask {
    param([string]$Title)
    $briefing = Get-DailyBriefing
    $briefing.AddTask($Title)
}

Write-Host "Daily Briefing Module Initialized"
