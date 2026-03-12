# Desktop Goose Easter Eggs System
# Hidden commands and surprises

class GooseEasterEggs {
    [hashtable]$Config
    [hashtable]$EasterEggs
    [int]$DiscoveryCount
    
    GooseEasterEggs() {
        $this.Config = $this.LoadConfig()
        $this.DiscoveryCount = 0
        $this.InitializeEasterEggs()
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
        
        if (-not $this.Config.ContainsKey("EasterEggsEnabled")) {
            $this.Config["EasterEggsEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] InitializeEasterEggs() {
        $this.EasterEggs = @{
            "honk" = @{
                "Trigger" = "honk"
                "Response" = "HONK! *The goose honks back at you*"
                "Animation" = "honk_excited"
                "Unlocked" = $false
            }
            "pet" = @{
                "Trigger" = "pet"
                "Response" = "*The goose makes a happy cooing sound*"
                "Animation" = "pet_happy"
                "Unlocked" = $false
            }
            "treat" = @{
                "Trigger" = "treat"
                "Response" = "*The goose eagerly eats the treat*"
                "Animation" = "eating"
                "Unlocked" = $false
            }
            "dance" = @{
                "Trigger" = "dance"
                "Response" = "*The goose starts doing the funky goose*"
                "Animation" = "dance_funky"
                "Unlocked" = $false
            }
            "spin" = @{
                "Trigger" = "spin"
                "Response" = "*The goose spins in circles*"
                "Animation" = "spin_around"
                "Unlocked" = $false
            }
            "hide" = @{
                "Trigger" = "hide"
                "Response" = "*The goose hides behind a metaphorical bush*"
                "Animation" = "hide_shy"
                "Unlocked" = $false
            }
            "attack" = @{
                "Trigger" = "attack"
                "Response" = "*The goose charges aggressively!* Just kidding, geese are friendly."
                "Animation" = "charge_playful"
                "Unlocked" = $false
            }
            "feather" = @{
                "Trigger" = "feather"
                "Response" = "Here's a feather! *The goose plucks a feather and offers it to you*"
                "Animation" = "present_feather"
                "Unlocked" = $false
            }
            "nap" = @{
                "Trigger" = "nap"
                "Response" = "*The goose curls up for a quick snooze*"
                "Animation" = "sleep_tiny"
                "Unlocked" = $false
            }
            "mirror" = @{
                "Trigger" = "mirror"
                "Response" = "*The goose admires its reflection* Who's a pretty goose? You are!"
                "Animation" = "admire_self"
                "Unlocked" = $false
            }
            "rain" = @{
                "Trigger" = "rain"
                "Response" = "*The goose splashes happily in the rain*"
                "Animation" = "splash_rain"
                "Unlocked" = $false
            }
            "sunbath" = @{
                "Trigger" = "sunbath"
                "Response" = "*The goose spreads its wings for a sunbath* So warm..."
                "Animation" = "sunbathe_relax"
                "Unlocked" = $false
            }
            "escape" = @{
                "Trigger" = "escape"
                "Response" = "Where is the goose going? To the pond! *The goose waddles off-screen*"
                "Animation" = "waddle_away"
                "Unlocked" = $false
            }
            "back" = @{
                "Trigger" = "back"
                "Response" = "*The goose returns from its adventure* I brought you a shiny rock!"
                "Animation" = "waddle_back"
                "Unlocked" = $false
            }
            "angry" = @{
                "Trigger" = "angry"
                "Response" = "*The goose puffs up angrily* Hmph! *turns away*"
                "Animation" = "angry_puffed"
                "Unlocked" = $false
            }
            "forgive" = @{
                "Trigger" = "forgive"
                "Response" = "*The goose turns back around* I forgive you! *nuzzles*"
                "Animation" = "forgive_happy"
                "Unlocked" = $false
            }
            "zoom" = @{
                "Trigger" = "zoom"
                "Response" = "*The goose zooms across the screen at supernatural speed*"
                "Animation" = "zoom_fast"
                "Unlocked" = $false
            }
            "slow" = @{
                "Trigger" = "slow"
                "Response" = "*The goose moves in extreme slow motion*"
                "Animation" = "move_slow"
                "Unlocked" = $false
            }
            "freeze" = @{
                "Trigger" = "freeze"
                "Response" = "*The goose freezes completely still* Like a statue!"
                "Animation" = "freeze_rigid"
                "Unlocked" = $false
            }
            "ghost" = @{
                "Trigger" = "ghost"
                "Response" = "*The goose becomes a ghost* Boooooo!"
                "Animation" = "ghost_float"
                "Unlocked" = $false
            }
            "king" = @{
                "Trigger" = "king"
                "Response" = "*The goose crowns itself King of the Desktop* All shall bow!"
                "Animation" = "crown_pose"
                "Unlocked" = $false
            }
            "joke" = @{
                "Trigger" = "joke"
                "Response" = "Why did the goose cross the road? To prove it wasn't chicken!"
                "Animation" = "joke_tell"
                "Unlocked" = $false
            }
            "sing" = @{
                "Trigger" = "sing"
                "Response" = "*The goose sings a beautiful song* La la laaaa!"
                "Animation" = "sing_song"
                "Unlocked" = $false
            }
            "magic" = @{
                "Trigger" = "magic"
                "Response" = "*The goose pulls a quarter from behind your ear* Presto!"
                "Animation" = "magic_trick"
                "Unlocked" = $false
            }
            "count" = @{
                "Trigger" = "count"
                "Response" = "The goose can count! 1 goose, 2 goose, 3 goose..."
                "Animation" = "count_numbers"
                "Unlocked" = $false
            }
        }
    }
    
    [hashtable] TriggerEasterEgg([string]$command) {
        $command = $command.ToLower().Trim()
        
        if ($this.EasterEggs.ContainsKey($command)) {
            $egg = $this.EasterEggs[$command]
            $egg["Unlocked"] = $true
            $this.DiscoveryCount++
            
            return @{
                "Found" = $true
                "Trigger" = $command
                "Response" = $egg["Response"]
                "Animation" = $egg["Animation"]
                "TotalDiscoveries" = $this.DiscoveryCount
            }
        }
        
        $similar = $this.FindSimilarCommands($command)
        
        return @{
            "Found" = $false
            "Similar" = $similar
            "Hint" = "Type 'help easter' to see available commands"
        }
    }
    
    [array] FindSimilarCommands([string]$input) {
        $similar = @()
        $threshold = 2
        
        foreach ($egg in $this.EasterEggs.Keys) {
            if ($this.LevenshteinDistance($input, $egg) -le $threshold) {
                $similar += $egg
            }
        }
        
        return $similar
    }
    
    [int] LevenshteinDistance([string]$s1, [string]$s2) {
        if ($s1.Length -eq 0) { return $s2.Length }
        if ($s2.Length -eq 0) { return $s1.Length }
        
        $matrix = New-Object 'int[,]' ($s1.Length + 1, $s2.Length + 1)
        
        for ($i = 0; $i -le $s1.Length; $i++) { $matrix[$i, 0] = $i }
        for ($j = 0; $j -le $s2.Length; $j++) { $matrix[0, $j] = $j }
        
        for ($i = 1; $i -le $s1.Length; $i++) {
            for ($j = 1; $j -le $s2.Length; $j++) {
                $cost = if ($s1[$i-1] -eq $s2[$j-1]) { 0 } else { 1 }
                $matrix[$i, $j] = [Math]::Min(
                    [Math]::Min($matrix[$i-1, $j] + 1, $matrix[$i, $j-1] + 1),
                    $matrix[$i-1, $j-1] + $cost
                )
            }
        }
        
        return $matrix[$s1.Length, $s2.Length]
    }
    
    [array] GetUnlockedEasterEggs() {
        $unlocked = @()
        foreach ($key in $this.EasterEggs.Keys) {
            if ($this.EasterEggs[$key]["Unlocked"]) {
                $unlocked += $key
            }
        }
        return $unlocked
    }
    
    [array] GetAllEasterEggs() {
        $all = @()
        foreach ($key in $this.EasterEggs.Keys) {
            $all += @{
                "Trigger" = $key
                "Unlocked" = $this.EasterEggs[$key]["Unlocked"]
            }
        }
        return $all
    }
    
    [hashtable] GetEasterEggsState() {
        return @{
            "Enabled" = $this.Config["EasterEggsEnabled"]
            "DiscoveryCount" = $this.DiscoveryCount
            "TotalEasterEggs" = $this.EasterEggs.Count
            "UnlockedCount" = $this.GetUnlockedEasterEggs().Count
            "UnlockedEasterEggs" = $this.GetUnlockedEasterEggs()
        }
    }
}

$gooseEasterEggs = [GooseEasterEggs]::new()

function Get-GooseEasterEggs {
    return $gooseEasterEggs
}

function Invoke-EasterEgg {
    param(
        [string]$Command,
        $EasterEggs = $gooseEasterEggs
    )
    return $EasterEggs.TriggerEasterEgg($Command)
}

function Get-EasterEggsState {
    param($EasterEggs = $gooseEasterEggs)
    return $EasterEggs.GetEasterEggsState()
}

function Get-AllEasterEggs {
    param($EasterEggs = $gooseEasterEggs)
    return $EasterEggs.GetAllEasterEggs()
}

Write-Host "Desktop Goose Easter Eggs System Initialized"
$state = Get-EasterEggsState
Write-Host "Easter Eggs Enabled: $($state['Enabled'])"
Write-Host "Total Easter Eggs: $($state['TotalEasterEggs'])"
Write-Host "Discovered: $($state['UnlockedCount')}"
