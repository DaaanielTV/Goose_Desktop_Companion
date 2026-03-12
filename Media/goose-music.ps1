# Desktop Goose Music Reactivity System
# Responds to music playing on the system

class GooseMusic {
    [hashtable]$Config
    [string]$CurrentPlayer
    [string]$CurrentTrack
    [string]$CurrentArtist
    [bool]$IsPlaying
    [hashtable]$PlayerStates
    [datetime]$LastCheck
    
    GooseMusic() {
        $this.Config = $this.LoadConfig()
        $this.CurrentPlayer = ""
        $this.CurrentTrack = ""
        $this.CurrentArtist = ""
        $this.IsPlaying = $false
        $this.PlayerStates = @{}
        $this.LastCheck = Get-Date
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
    
    [void] CheckSpotify() {
        try {
            $spotify = Get-Process -Name "Spotify" -ErrorAction SilentlyContinue
            if ($spotify) {
                $this.CurrentPlayer = "Spotify"
                $this.CurrentTrack = "Playing"
                $this.IsPlaying = $true
            }
        } catch {
            # Ignore errors
        }
    }
    
    [void] CheckWindowsMediaPlayer() {
        try {
            $wmp = Get-Process -Name "wmplayer" -ErrorAction SilentlyContinue
            if ($wmp) {
                $shell = New-Object -ComObject Shell.Application
                $wmpShell = $shell.NameSpace(28)
                if ($wmpShell) {
                    $this.CurrentPlayer = "Windows Media Player"
                    $this.CurrentTrack = $wmpShell.ParseName($null).Name
                    $this.IsPlaying = $true
                }
            }
        } catch {
            # Ignore errors
        }
    }
    
    [void] CheckVLC() {
        try {
            $vlc = Get-Process -Name "vlc" -ErrorAction SilentlyContinue
            if ($vlc) {
                $this.CurrentPlayer = "VLC"
                $this.CurrentTrack = "Media Playing"
                $this.IsPlaying = $true
            }
        } catch {
            # Ignore errors
        }
    }
    
    [void] CheckGenericAudio() {
        try {
            # Check for any media player processes
            $mediaPlayers = @("Spotify", "vlc", "wmplayer", "Music", "Groove", "Audacity", "foobar2000", "Winamp")
            
            foreach ($player in $mediaPlayers) {
                $process = Get-Process -Name $player -ErrorAction SilentlyContinue
                if ($process) {
                    if ($this.CurrentPlayer -eq "") {
                        $this.CurrentPlayer = $player
                        $this.IsPlaying = $true
                    }
                    break
                }
            }
        } catch {
            # Ignore errors
        }
    }
    
    [void] Update() {
        $this.CurrentPlayer = ""
        $this.CurrentTrack = ""
        $this.CurrentArtist = ""
        $this.IsPlaying = $false
        
        $this.CheckSpotify()
        
        if ($this.CurrentPlayer -eq "") {
            $this.CheckVLC()
        }
        
        if ($this.CurrentPlayer -eq "") {
            $this.CheckWindowsMediaPlayer()
        }
        
        if ($this.CurrentPlayer -eq "") {
            $this.CheckGenericAudio()
        }
        
        $this.LastCheck = Get-Date
    }
    
    [bool] IsMusicPlaying() {
        $this.Update()
        return $this.IsPlaying
    }
    
    [hashtable] GetNowPlaying() {
        $this.Update()
        
        return @{
            "Player" = $this.CurrentPlayer
            "Track" = $this.CurrentTrack
            "Artist" = $this.CurrentArtist
            "IsPlaying" = $this.IsPlaying
            "LastCheck" = $this.LastCheck
        }
    }
    
    [string] GetGooseReaction() {
        $nowPlaying = $this.GetNowPlaying()
        
        if (-not $nowPlaying["IsPlaying"]) {
            return ""
        }
        
        $player = $nowPlaying["Player"]
        $track = $nowPlaying["Track"]
        
        $reactions = @()
        
        if ($player -eq "Spotify") {
            $reactions += " *bops along to* $track"
        } elseif ($player -eq "VLC") {
            $reactions += " *watches* $track"
        } else {
            $reactions += " *listens to* $track"
        }
        
        return ($reactions | Get-Random)
    }
    
    [string] GetGooseMoodFromMusic() {
        if (-not $this.IsPlaying) {
            return "idle"
        }
        
        $track = $this.CurrentTrack.ToLower()
        
        if ($track -match "jazz|classical|ambient|relax|chill|sleep") {
            return "calm"
        }
        
        if ($track -match "rock|metal|punk|energy|party|dance") {
            return "energetic"
        }
        
        if ($track -match "sad|tears|blue|rain|lonely") {
            return "sympathetic"
        }
        
        return "happy"
    }
    
    [hashtable] GetMusicContext() {
        return @{
            "NowPlaying" = $this.GetNowPlaying()
            "GooseReaction" = $this.GetGooseReaction()
            "GooseMood" = $this.GetGooseMoodFromMusic()
            "IsPlaying" = $this.IsPlaying
        }
    }
}

# Initialize music system
$gooseMusic = [GooseMusic]::new()

# Export functions
function Get-GooseMusic {
    return $gooseMusic
}

function Get-NowPlaying {
    param($Music = $gooseMusic)
    return $Music.GetNowPlaying()
}

function Get-MusicContext {
    param($Music = $gooseMusic)
    return $Music.GetMusicContext()
}

function Test-MusicPlaying {
    param($Music = $gooseMusic)
    return $Music.IsPlaying()
}

# Example usage
Write-Host "Desktop Goose Music Reactivity Initialized"
$nowPlaying = Get-NowPlaying
Write-Host "Player: $($nowPlaying.Player), Playing: $($nowPlaying.IsPlaying)"
