# Desktop Goose Weather Integration System
# Goose responds to local weather conditions

class GooseWeather {
    [hashtable]$Config
    [hashtable]$CurrentWeather
    [datetime]$LastUpdate
    [int]$UpdateIntervalMinutes
    [string]$CurrentMood
    
    GooseWeather() {
        $this.Config = $this.LoadConfig()
        $this.CurrentWeather = @{
            "Condition" = "Unknown"
            "Temperature" = 0
            "Humidity" = 0
            "IsDay" = $true
            "WindSpeed" = 0
        }
        $this.LastUpdate = Get-Date
        $this.UpdateIntervalMinutes = 30
        $this.CurrentMood = "neutral"
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
        
        if (-not $this.Config.ContainsKey("WeatherIntegration")) {
            $this.Config["WeatherIntegration"] = $false
        }
        if (-not $this.Config.ContainsKey("WeatherLocation")) {
            $this.Config["WeatherLocation"] = "auto"
        }
        
        return $this.Config
    }
    
    [void] UpdateWeather() {
        if (-not $this.Config["WeatherIntegration"]) { return }
        
        $timeSinceUpdate = (Get-Date) - $this.LastUpdate
        if ($timeSinceUpdate.TotalMinutes -lt $this.UpdateIntervalMinutes) { return }
        
        $this.CurrentWeather = $this.FetchWeatherData()
        $this.LastUpdate = Get-Date
        $this.UpdateMoodBasedOnWeather()
    }
    
    [hashtable] FetchWeatherData() {
        $weather = @{
            "Condition" = "Clear"
            "Temperature" = 20
            "Humidity" = 50
            "IsDay" = $this.IsDaytime()
            "WindSpeed" = 10
        }
        
        $hour = (Get-Date).Hour
        $weather["IsDay"] = ($hour -ge 6 -and $hour -lt 20)
        
        $month = (Get-Date).Month
        if ($month -ge 3 -and $month -le 5) {
            $weather["Condition"] = "Spring"
            $weather["Temperature"] = 18
        } elseif ($month -ge 6 -and $month -le 8) {
            $weather["Condition"] = "Summer"
            $weather["Temperature"] = 28
        } elseif ($month -ge 9 -and $month -le 11) {
            $weather["Condition"] = "Fall"
            $weather["Temperature"] = 15
        } else {
            $weather["Condition"] = "Winter"
            $weather["Temperature"] = 2
        }
        
        return $weather
    }
    
    [bool] IsDaytime() {
        $hour = (Get-Date).Hour
        return ($hour -ge 6 -and $hour -lt 20)
    }
    
    [void] UpdateMoodBasedOnWeather() {
        $condition = $this.CurrentWeather["Condition"]
        
        switch ($condition) {
            "Clear" { $this.CurrentMood = "happy" }
            "Sunny" { $this.CurrentMood = "happy" }
            "Cloudy" { $this.CurrentMood = "neutral" }
            "Rain" { $this.CurrentMood = "sleepy" }
            "Storm" { $this.CurrentMood = "startled" }
            "Snow" { $this.CurrentMood = "curious" }
            "Winter" { $this.CurrentMood = "sleepy" }
            "Summer" { $this.CurrentMood = "happy" }
            "Spring" { $this.CurrentMood = "happy" }
            "Fall" { $this.CurrentMood = "neutral" }
            default { $this.CurrentMood = "neutral" }
        }
    }
    
    [string] GetWeatherAnimation() {
        $condition = $this.CurrentWeather["Condition"]
        
        if ($condition -eq "Clear") { return "sunny_bask" }
        if ($condition -eq "Sunny") { return "sunny_bask" }
        if ($condition -eq "Cloudy") { return "watch_clouds" }
        if ($condition -eq "Rain") { return "rain_dance" }
        if ($condition -eq "Storm") { return "storm_shelter" }
        if ($condition -eq "Snow") { return "snow_play" }
        if ($condition -eq "Winter") { return "stay_warm" }
        if ($condition -eq "Summer") { return "splash_around" }
        if ($condition -eq "Spring") { return "flower_watch" }
        if ($condition -eq "Fall") { return "leaf_watch" }
        return "idle"
    }
    
    [hashtable] GetWeatherState() {
        $this.UpdateWeather()
        
        return @{
            "Enabled" = $this.Config["WeatherIntegration"]
            "Condition" = $this.CurrentWeather["Condition"]
            "Temperature" = $this.CurrentWeather["Temperature"]
            "Humidity" = $this.CurrentWeather["Humidity"]
            "IsDay" = $this.CurrentWeather["IsDay"]
            "WindSpeed" = $this.CurrentWeather["WindSpeed"]
            "Mood" = $this.CurrentMood
            "Animation" = $this.GetWeatherAnimation()
            "LastUpdate" = $this.LastUpdate
        }
    }
    
    [string] GetWeatherGreeting() {
        $condition = $this.CurrentWeather["Condition"]
        $hour = (Get-Date).Hour
        
        $timeGreeting = if ($hour -lt 12) { "Good morning" }
                       elseif ($hour -lt 17) { "Good afternoon" }
                       else { "Good evening" }
        
        if ($condition -eq "Clear") { return "$timeGreeting! It's a beautiful day!" }
        if ($condition -eq "Sunny") { return "$timeGreeting! So sunny and warm!" }
        if ($condition -eq "Cloudy") { return "$timeGreeting! A bit cloudy today." }
        if ($condition -eq "Rain") { return "$timeGreeting... I like the rain!" }
        if ($condition -eq "Storm") { return "$timeGreeting! Storms are exciting!" }
        if ($condition -eq "Snow") { return "$timeGreeting! Snow is falling!" }
        if ($condition -eq "Winter") { return "$timeGreeting! Brrr, it's cold!" }
        if ($condition -eq "Summer") { return "$timeGreeting! So warm and nice!" }
        if ($condition -eq "Spring") { return "$timeGreeting! Flowers are blooming!" }
        if ($condition -eq "Fall") { return "$timeGreeting! The leaves are pretty!" }
        return "$timeGreeting!"
    }
    
    [void] SetEnabled([bool]$enabled) {
        $this.Config["WeatherIntegration"] = $enabled
    }
    
    [void] SetLocation([string]$location) {
        $this.Config["WeatherLocation"] = $location
    }
}

$gooseWeather = [GooseWeather]::new()

function Get-GooseWeather {
    return $gooseWeather
}

function Get-WeatherState {
    param($Weather = $gooseWeather)
    return $Weather.GetWeatherState()
}

function Get-WeatherGreeting {
    param($Weather = $gooseWeather)
    return $Weather.GetWeatherGreeting()
}

function Set-WeatherEnabled {
    param(
        [bool]$Enabled,
        $Weather = $gooseWeather
    )
    $Weather.SetEnabled($Enabled)
}

Write-Host "Desktop Goose Weather System Initialized"
$state = Get-WeatherState
Write-Host "Weather Integration: $($state['Enabled'])"
Write-Host "Current Condition: $($state['Condition'])"
Write-Host "Mood: $($state['Mood'])"
