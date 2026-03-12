# Desktop Goose Seasonal/Holiday Themes System
# Automatic theme changes for holidays and seasons

class GooseSeasonal {
    [hashtable]$Config
    [hashtable]$CurrentTheme
    [string]$CurrentSeason
    [string]$CurrentHoliday
    [datetime]$LastThemeCheck
    
    GooseSeasonal() {
        $this.Config = $this.LoadConfig()
        $this.CurrentTheme = $this.GetDefaultTheme()
        $this.CurrentSeason = ""
        $this.CurrentHoliday = ""
        $this.LastThemeCheck = Get-Date
        $this.UpdateTheme()
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
        
        if (-not $this.Config.ContainsKey("SeasonalThemes")) {
            $this.Config["SeasonalThemes"] = $false
        }
        
        return $this.Config
    }
    
    [string] GetCurrentSeason() {
        $month = (Get-Date).Month
        
        if ($month -ge 3 -and $month -le 5) { return "Spring" }
        if ($month -ge 6 -and $month -le 8) { return "Summer" }
        if ($month -ge 9 -and $month -le 11) { return "Fall" }
        return "Winter"
    }
    
    [string] GetCurrentHoliday() {
        $date = Get-Date
        $month = $date.Month
        $day = $date.Day
        
        if ($month -eq 1 -and $day -eq 1) { return "NewYear" }
        if ($month -eq 2 -and $day -eq 14) { return "Valentines" }
        if ($month -eq 3 -and $day -ge 17 -and $day -le 20) { return "StPatricks" }
        if ($month -eq 4 -and $day -eq 22) { return "EarthDay" }
        if ($month -eq 10 -and $day -eq 31) { return "Halloween" }
        if ($month -eq 11 -and $day -ge 20 -and $day -le 30) { return "Thanksgiving" }
        if ($month -eq 12 -and $day -eq 24) { return "ChristmasEve" }
        if ($month -eq 12 -and $day -eq 25) { return "Christmas" }
        if ($month -eq 12 -and $day -eq 31) { return "NewYearsEve" }
        
        $dayOfYear = $date.DayOfYear
        if ($dayOfYear -ge 355 -or $dayOfYear -le 5) { return "HolidaySeason" }
        
        return ""
    }
    
    [hashtable] GetDefaultTheme() {
        return @{
            "Name" = "Default"
            "PrimaryColor" = "#ffffff"
            "SecondaryColor" = "#ffa500"
            "AccentColor" = "#d3d3d3"
            "BackgroundEffect" = "none"
            "SpecialAnimation" = ""
            "Mood" = "neutral"
        }
    }
    
    [hashtable] GetSeasonTheme([string]$season) {
        switch ($season) {
            "Spring" {
                return @{
                    "Name" = "Spring"
                    "PrimaryColor" = "#f0fff0"
                    "SecondaryColor" = "#98fb98"
                    "AccentColor" = "#ffb6c1"
                    "BackgroundEffect" = "falling_petals"
                    "SpecialAnimation" = "flower_bloom"
                    "Mood" = "happy"
                }
            }
            "Summer" {
                return @{
                    "Name" = "Summer"
                    "PrimaryColor" = "#fffacd"
                    "SecondaryColor" = "#ffd700"
                    "AccentColor" = "#87ceeb"
                    "BackgroundEffect" = "sunny"
                    "SpecialAnimation" = "splash"
                    "Mood" = "happy"
                }
            }
            "Fall" {
                return @{
                    "Name" = "Fall"
                    "PrimaryColor" = "#ffe4c4"
                    "SecondaryColor" = "#d2691e"
                    "AccentColor" = "#b22222"
                    "BackgroundEffect" = "falling_leaves"
                    "SpecialAnimation" = "rustle"
                    "Mood" = "neutral"
                }
            }
            "Winter" {
                return @{
                    "Name" = "Winter"
                    "PrimaryColor" = "#f0f8ff"
                    "SecondaryColor" = "#b0c4de"
                    "AccentColor" = "#add8e6"
                    "BackgroundEffect" = "snowflakes"
                    "SpecialAnimation" = "shiver"
                    "Mood" = "sleepy"
                }
            }
            default {
                return $this.GetDefaultTheme()
            }
        }
    }
    
    [hashtable] GetHolidayTheme([string]$holiday) {
        switch ($holiday) {
            "NewYear" {
                return @{
                    "Name" = "NewYear"
                    "PrimaryColor" = "#ffffff"
                    "SecondaryColor" = "#ffd700"
                    "AccentColor" = "#ff4500"
                    "BackgroundEffect" = "confetti"
                    "SpecialAnimation" = "celebration"
                    "Mood" = "happy"
                }
            }
            "Valentines" {
                return @{
                    "Name" = "Valentines"
                    "PrimaryColor" = "#fff0f5"
                    "SecondaryColor" = "#ff69b4"
                    "AccentColor" = "#ff1493"
                    "BackgroundEffect" = "hearts"
                    "SpecialAnimation" = "love"
                    "Mood" = "affectionate"
                }
            }
            "StPatricks" {
                return @{
                    "Name" = "StPatricks"
                    "PrimaryColor" = "#f0fff0"
                    "SecondaryColor" = "#228b22"
                    "AccentColor" = "#00ff00"
                    "BackgroundEffect" = "clovers"
                    "SpecialAnimation" = "dance"
                    "Mood" = "happy"
                }
            }
            "EarthDay" {
                return @{
                    "Name" = "EarthDay"
                    "PrimaryColor" = "#98fb98"
                    "SecondaryColor" = "#228b22"
                    "AccentColor" = "#006400"
                    "BackgroundEffect" = "leaves"
                    "SpecialAnimation" = "grow"
                    "Mood" = "happy"
                }
            }
            "Halloween" {
                return @{
                    "Name" = "Halloween"
                    "PrimaryColor" = "#2f2f2f"
                    "SecondaryColor" = "#ff6600"
                    "AccentColor" = "#9932cc"
                    "BackgroundEffect" = "pumpkins"
                    "SpecialAnimation" = "spooky"
                    "Mood" = "startled"
                }
            }
            "Thanksgiving" {
                return @{
                    "Name" = "Thanksgiving"
                    "PrimaryColor" = "#deb887"
                    "SecondaryColor" = "#d2691e"
                    "AccentColor" = "#8b4513"
                    "BackgroundEffect" = "leaves"
                    "SpecialAnimation" = "grateful"
                    "Mood" = "neutral"
                }
            }
            "ChristmasEve" {
                return @{
                    "Name" = "ChristmasEve"
                    "PrimaryColor" = "#fff"
                    "SecondaryColor" = "#228b22"
                    "AccentColor" = "#ffd700"
                    "BackgroundEffect" = "snow"
                    "SpecialAnimation" = "anticipate"
                    "Mood" = "happy"
                }
            }
            "Christmas" {
                return @{
                    "Name" = "Christmas"
                    "PrimaryColor" = "#fff"
                    "SecondaryColor" = "#ff0000"
                    "AccentColor" = "#228b22"
                    "BackgroundEffect" = "snow"
                    "SpecialAnimation" = "celebration"
                    "Mood" = "veryhappy"
                }
            }
            "NewYearsEve" {
                return @{
                    "Name" = "NewYearsEve"
                    "PrimaryColor" = "#1a1a2e"
                    "SecondaryColor" = "#ffd700"
                    "AccentColor" = "#ff4500"
                    "BackgroundEffect" = "fireworks"
                    "SpecialAnimation" = "countdown"
                    "Mood" = "happy"
                }
            }
            "HolidaySeason" {
                return @{
                    "Name" = "HolidaySeason"
                    "PrimaryColor" = "#fff"
                    "SecondaryColor" = "#c41e3a"
                    "AccentColor" = "#228b22"
                    "BackgroundEffect" = "twinkling_lights"
                    "SpecialAnimation" = "cheerful"
                    "Mood" = "happy"
                }
            }
            default {
                return $null
            }
        }
    }
    
    [void] UpdateTheme() {
        if (-not $this.Config["SeasonalThemes"]) {
            $this.CurrentTheme = $this.GetDefaultTheme()
            return
        }
        
        $this.CurrentSeason = $this.GetCurrentSeason()
        $this.CurrentHoliday = $this.GetCurrentHoliday()
        
        if ($this.CurrentHoliday -ne "") {
            $holidayTheme = $this.GetHolidayTheme($this.CurrentHoliday)
            if ($holidayTheme) {
                $this.CurrentTheme = $holidayTheme
                return
            }
        }
        
        $this.CurrentTheme = $this.GetSeasonTheme($this.CurrentSeason)
        $this.LastThemeCheck = Get-Date
    }
    
    [hashtable] GetThemeState() {
        $this.UpdateTheme()
        
        return @{
            "Enabled" = $this.Config["SeasonalThemes"]
            "CurrentSeason" = $this.CurrentSeason
            "CurrentHoliday" = $this.CurrentHoliday
            "CurrentTheme" = $this.CurrentTheme
            "LastCheck" = $this.LastThemeCheck
        }
    }
    
    [void] SetTheme([string]$themeName) {
        $themes = @{
            "Default" = $this.GetDefaultTheme()
            "Spring" = $this.GetSeasonTheme("Spring")
            "Summer" = $this.GetSeasonTheme("Summer")
            "Fall" = $this.GetSeasonTheme("Fall")
            "Winter" = $this.GetSeasonTheme("Winter")
        }
        
        if ($themes.ContainsKey($themeName)) {
            $this.CurrentTheme = $themes[$themeName]
        }
    }
    
    [void] ForceHolidayTheme([string]$holiday) {
        $theme = $this.GetHolidayTheme($holiday)
        if ($theme) {
            $this.CurrentTheme = $theme
            $this.CurrentHoliday = $holiday
        }
    }
    
    [bool] IsSpecialDay() {
        return $this.CurrentHoliday -ne ""
    }
    
    [string] GetGreeting() {
        if ($this.CurrentHoliday -ne "") {
            switch ($this.CurrentHoliday) {
                "NewYear" { return "Happy New Year!" }
                "Valentines" { return "Happy Valentine's Day!" }
                "StPatricks" { return "Happy St. Patrick's Day!" }
                "EarthDay" { return "Happy Earth Day!" }
                "Halloween" { return "Happy Halloween!" }
                "Thanksgiving" { return "Happy Thanksgiving!" }
                "ChristmasEve" { return "Merry Christmas Eve!" }
                "Christmas" { return "Merry Christmas!" }
                "NewYearsEve" { return "Happy New Year's Eve!" }
                "HolidaySeason" { return "Happy Holidays!" }
            }
        }
        
        switch ($this.CurrentSeason) {
            "Spring" { return "It's springtime!" }
            "Summer" { return "It's summer!" }
            "Fall" { return "It's fall!" }
            "Winter" { return "It's winter!" }
        }
        
        return ""
    }
}

$gooseSeasonal = [GooseSeasonal]::new()

function Get-GooseSeasonal {
    return $gooseSeasonal
}

function Get-CurrentTheme {
    param($Seasonal = $gooseSeasonal)
    return $Seasonal.GetThemeState()
}

function Set-GooseTheme {
    param(
        [string]$ThemeName,
        $Seasonal = $gooseSeasonal
    )
    $Seasonal.SetTheme($ThemeName)
}

function Get-SeasonalGreeting {
    param($Seasonal = $gooseSeasonal)
    return $Seasonal.GetGreeting()
}

Write-Host "Desktop Goose Seasonal System Initialized"
$state = $gooseSeasonal.GetThemeState()
Write-Host "Seasonal Themes Enabled: $($state['Enabled'])"
Write-Host "Current Season: $($state['CurrentSeason'])"
Write-Host "Current Holiday: $($state['CurrentHoliday'])"
