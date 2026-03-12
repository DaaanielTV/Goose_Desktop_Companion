# Desktop Goose Clock Widget System
# Displays a clock on or near the goose

class GooseClockWidget {
    [hashtable]$Config
    [bool]$ShowClock
    [string]$ClockPosition
    [string]$ClockFormat
    [string]$ClockColor
    [bool]$ShowDate
    [bool]$ShowSeconds
    
    GooseClockWidget() {
        $this.Config = $this.LoadConfig()
        $this.ShowClock = $false
        $this.ClockPosition = "bottom"
        $this.ClockFormat = "HH:mm"
        $this.ClockColor = "#ffffff"
        $this.ShowDate = $false
        $this.ShowSeconds = $false
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
        
        if (-not $this.Config.ContainsKey("ClockWidgetEnabled")) {
            $this.Config["ClockWidgetEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] SetShowClock([bool]$show) {
        $this.ShowClock = $show
    }
    
    [void] SetClockFormat([string]$format) {
        $validFormats = @("HH:mm", "hh:mm tt", "HH:mm:ss", "h:mm:ss tt")
        if ($validFormats -contains $format) {
            $this.ClockFormat = $format
        }
    }
    
    [void] SetClockPosition([string]$position) {
        $validPositions = @("top", "bottom", "left", "right", "floating")
        if ($validPositions -contains $position) {
            $this.ClockPosition = $position
        }
    }
    
    [string] GetCurrentTime() {
        return Get-Date -Format $this.ClockFormat
    }
    
    [string] GetCurrentDate() {
        return Get-Date -Format "dddd, MMMM d, yyyy"
    }
    
    [string] GetCurrentDateShort() {
        return Get-Date -Format "MMM d, yyyy"
    }
    
    [hashtable] GetClockDisplay() {
        $display = @{
            "Time" = $this.GetCurrentTime()
            "Date" = if ($this.ShowDate) { $this.GetCurrentDate() } else { $null }
            "DateShort" = if ($this.ShowDate) { $this.GetCurrentDateShort() } else { $null }
            "Position" = $this.ClockPosition
            "Format" = $this.ClockFormat
            "Color" = $this.ClockColor
            "ShowSeconds" = $this.ShowSeconds
        }
        
        return $display
    }
    
    [hashtable] GetClockWidgetState() {
        return @{
            "Enabled" = $this.Config["ClockWidgetEnabled"]
            "ShowClock" = $this.ShowClock
            "ClockPosition" = $this.ClockPosition
            "ClockFormat" = $this.ClockFormat
            "ClockColor" = $this.ClockColor
            "ShowDate" = $this.ShowDate
            "ShowSeconds" = $this.ShowSeconds
            "CurrentTime" = $this.GetCurrentTime()
            "CurrentDate" = $this.GetCurrentDate()
        }
    }
    
    [void] ToggleClock() {
        $this.ShowClock = -not $this.ShowClock
    }
    
    [void] ToggleDate() {
        $this.ShowDate = -not $this.ShowDate
    }
    
    [void] ToggleSeconds() {
        $this.ShowSeconds = -not $this.ShowSeconds
        if ($this.ShowSeconds -and $this.ClockFormat -notmatch "ss") {
            $this.ClockFormat = "HH:mm:ss"
        } elseif (-not $this.ShowSeconds -and $this.ClockFormat -match "ss") {
            $this.ClockFormat = "HH:mm"
        }
    }
}

$gooseClockWidget = [GooseClockWidget]::new()

function Get-GooseClockWidget {
    return $gooseClockWidget
}

function Get-ClockDisplay {
    param($ClockWidget = $gooseClockWidget)
    return $ClockWidget.GetClockDisplay()
}

function Get-ClockWidgetState {
    param($ClockWidget = $gooseClockWidget)
    return $ClockWidget.GetClockWidgetState()
}

function Show-GooseClock {
    param(
        [bool]$Show = $true,
        $ClockWidget = $gooseClockWidget
    )
    $ClockWidget.SetShowClock($Show)
}

function Set-ClockFormat {
    param(
        [string]$Format,
        $ClockWidget = $gooseClockWidget
    )
    $ClockWidget.SetClockFormat($Format)
}

Write-Host "Desktop Goose Clock Widget System Initialized"
$state = Get-ClockWidgetState
Write-Host "Clock Widget Enabled: $($state['Enabled'])"
Write-Host "Current Time: $($state['CurrentTime'])"
