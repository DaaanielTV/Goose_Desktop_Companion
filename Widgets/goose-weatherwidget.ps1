# Desktop Goose Weather Widget System
# Display weather info as a widget

class GooseWeatherWidget {
    [hashtable]$Config
    [string]$DisplayLocation
    [bool]$ShowTemperature
    [bool]$ShowCondition
    [bool]$ShowHumidity
    [string]$WidgetPosition
    [string]$TemperatureUnit
    
    GooseWeatherWidget() {
        $this.Config = $this.LoadConfig()
        $this.DisplayLocation = "bottom-right"
        $this.ShowTemperature = $true
        $this.ShowCondition = $true
        $this.ShowHumidity = $false
        $this.WidgetPosition = "bottom-right"
        $this.TemperatureUnit = "C"
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
        
        if (-not $this.Config.ContainsKey("WeatherWidgetEnabled")) {
            $this.Config["WeatherWidgetEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [hashtable] GetWeatherData() {
        $hour = (Get-Date).Hour
        $month = (Get-Date).Month
        
        $condition = "Clear"
        $temperature = 20
        
        if ($month -ge 3 -and $month -le 5) {
            $condition = "Partly Cloudy"
            $temperature = 18
        } elseif ($month -ge 6 -and $month -le 8) {
            $condition = "Sunny"
            $temperature = 28
        } elseif ($month -ge 9 -and $month -le 11) {
            $condition = "Cloudy"
            $temperature = 15
        } else {
            $condition = "Cold"
            $temperature = 5
        }
        
        if ($hour -lt 6 -or $hour -gt 20) {
            $condition = "Clear Night"
            $temperature = $temperature - 5
        }
        
        return @{
            "Condition" = $condition
            "Temperature" = $temperature
            "TemperatureF" = ($temperature * 9/5) + 32
            "Humidity" = Get-Random -Minimum 40 -Maximum 70
            "WindSpeed" = Get-Random -Minimum 5 -Maximum 20
            "Location" = "Local"
            "LastUpdated" = (Get-Date).ToString("HH:mm")
        }
    }
    
    [string] GetFormattedTemperature([int]$temp, [string]$unit) {
        if ($unit -eq "F") {
            return "$temp°F"
        }
        return "$temp°C"
    }
    
    [string] GetWeatherIcon([string]$condition) {
        $icons = @{
            "Clear" = "☀️"
            "Sunny" = "☀️"
            "Clear Night" = "🌙"
            "Partly Cloudy" = "⛅"
            "Cloudy" = "☁️"
            "Rain" = "🌧️"
            "Storm" = "⛈️"
            "Snow" = "❄️"
            "Cold" = "🥶"
            "Hot" = "🥵"
        }
        
        return $icons[$condition]
    }
    
    [hashtable] GetWeatherWidgetDisplay() {
        $weather = $this.GetWeatherData()
        
        $display = @{
            "Enabled" = $this.Config["WeatherWidgetEnabled"]
            "Position" = $this.WidgetPosition
            "Icon" = $this.GetWeatherIcon($weather.Condition)
            "Temperature" = $this.GetFormattedTemperature($weather.Temperature, $this.TemperatureUnit)
            "Condition" = $weather.Condition
        }
        
        if ($this.ShowHumidity) {
            $display["Humidity"] = "$($weather.Humidity)%"
        }
        
        $display["LastUpdated"] = $weather.LastUpdated
        
        return $display
    }
    
    [void] SetPosition([string]$position) {
        $validPositions = @("top-left", "top-right", "bottom-left", "bottom-right")
        if ($validPositions -contains $position) {
            $this.WidgetPosition = $position
        }
    }
    
    [void] SetTemperatureUnit([string]$unit) {
        if ($unit -eq "C" -or $unit -eq "F") {
            $this.TemperatureUnit = $unit
        }
    }
    
    [void] ToggleTemperature([bool]$show) {
        $this.ShowTemperature = $show
    }
    
    [void] ToggleHumidity([bool]$show) {
        $this.ShowHumidity = $show
    }
    
    [hashtable] GetWeatherWidgetState() {
        return @{
            "Enabled" = $this.Config["WeatherWidgetEnabled"]
            "ShowTemperature" = $this.ShowTemperature
            "ShowCondition" = $this.ShowCondition
            "ShowHumidity" = $this.ShowHumidity
            "WidgetPosition" = $this.WidgetPosition
            "TemperatureUnit" = $this.TemperatureUnit
            "CurrentDisplay" = $this.GetWeatherWidgetDisplay()
        }
    }
}

$gooseWeatherWidget = [GooseWeatherWidget]::new()

function Get-GooseWeatherWidget {
    return $gooseWeatherWidget
}

function Get-WeatherWidgetDisplay {
    param($WeatherWidget = $gooseWeatherWidget)
    return $WeatherWidget.GetWeatherWidgetDisplay()
}

function Set-WeatherWidgetPosition {
    param(
        [string]$Position,
        $WeatherWidget = $gooseWeatherWidget
    )
    $WeatherWidget.SetPosition($Position)
}

function Get-WeatherWidgetState {
    param($WeatherWidget = $gooseWeatherWidget)
    return $WeatherWidget.GetWeatherWidgetState()
}

Write-Host "Desktop Goose Weather Widget System Initialized"
$state = Get-WeatherWidgetState
Write-Host "Weather Widget Enabled: $($state['Enabled'])"
Write-Host "Current Weather: $($state['CurrentDisplay']['Condition']) $($state['CurrentDisplay']['Temperature'])"
