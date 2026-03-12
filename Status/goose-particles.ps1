# Desktop Goose Particle Effects System
# Provides subtle environmental particle effects

class GooseParticles {
    [hashtable]$Config
    [System.Collections.ArrayList]$Particles
    [string]$CurrentEffect
    [bool]$IsActive
    [int]$MaxParticles
    
    GooseParticles() {
        $this.Config = $this.LoadConfig()
        $this.Particles = [System.Collections.ArrayList]::new()
        $this.CurrentEffect = "none"
        $this.IsActive = $false
        $this.MaxParticles = 50
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
    
    [void] StartEffect([string]$effectName) {
        $this.CurrentEffect = $effectName
        $this.IsActive = $true
        $this.Particles.Clear()
        
        $this.SetEffectSettings($effectName)
    }
    
    [void] SetEffectSettings([string]$effect) {
        switch ($effect) {
            "snow" {
                $this.MaxParticles = 30
            }
            "rain" {
                $this.MaxParticles = 50
            }
            "leaves" {
                $this.MaxParticles = 15
            }
            "fireflies" {
                $this.MaxParticles = 20
            }
            "petals" {
                $this.MaxParticles = 25
            }
            "stars" {
                $this.MaxParticles = 40
            }
            default {
                $this.MaxParticles = 50
            }
        }
    }
    
    [void] StopEffect() {
        $this.IsActive = $false
        $this.CurrentEffect = "none"
        $this.Particles.Clear()
    }
    
    [void] SpawnParticle() {
        if (-not $this.IsActive) { return }
        if ($this.Particles.Count -ge $this.MaxParticles) { return }
        
        $particle = @{
            "X" = Get-Random -Minimum 0 -Maximum 1920
            "Y" = -20
            "VX" = 0
            "VY" = 0
            "Size" = 0
            "Opacity" = 1.0
            "Rotation" = 0
            "RotationSpeed" = 0
            "Color" = "#FFFFFF"
            "Life" = 100
            "Type" = $this.CurrentEffect
        }
        
        switch ($this.CurrentEffect) {
            "snow" {
                $particle["VX"] = (Get-Random -Minimum -1 -Maximum 2) * 0.5
                $particle["VY"] = Get-Random -Minimum 1 -Maximum 3
                $particle["Size"] = Get-Random -Minimum 2 -Maximum 6
                $particle["Color"] = "#FFFFFF"
                $particle["RotationSpeed"] = (Get-Random -Minimum -5 -Maximum 5) * 0.1
            }
            "rain" {
                $particle["X"] = Get-Random -Minimum 0 -Maximum 1920
                $particle["Y"] = -50
                $particle["VX"] = Get-Random -Minimum -1 -Maximum 1
                $particle["VY"] = Get-Random -Minimum 8 -Maximum 15
                $particle["Size"] = 1
                $particle["Color"] = "#8899AA"
                $particle["Rotation"] = 10
            }
            "leaves" {
                $particle["VX"] = (Get-Random -Minimum -2 -Maximum 3) * 0.5
                $particle["VY"] = Get-Random -Minimum 0.5 -Maximum 2
                $particle["Size"] = Get-Random -Minimum 5 -Maximum 12
                $particle["Color"] = @("#8B4513", "#D2691E", "#CD853F", "#DEB887") | Get-Random
                $particle["RotationSpeed"] = (Get-Random -Minimum -3 -Maximum 3) * 0.1
            }
            "fireflies" {
                $particle["VX"] = (Get-Random -Minimum -1 -Maximum 2)
                $particle["VY"] = (Get-Random -Minimum -1 -Maximum 2)
                $particle["Size"] = Get-Random -Minimum 2 -Maximum 5
                $particle["Color"] = "#FFFF66"
                $particle["Opacity"] = 1.0
            }
            "petals" {
                $particle["VX"] = (Get-Random -Minimum -1 -Maximum 2) * 0.8
                $particle["VY"] = Get-Random -Minimum 1 -Maximum 3
                $particle["Size"] = Get-Random -Minimum 4 -Maximum 10
                $particle["Color"] = @("#FFB7C5", "#FFC0CB", "#FF69B4", "#FF1493") | Get-Random
                $particle["RotationSpeed"] = (Get-Random -Minimum -5 -Maximum 5) * 0.2
            }
            "stars" {
                $particle["X"] = Get-Random -Minimum 0 -Maximum 1920
                $particle["Y"] = Get-Random -Minimum 0 -Maximum 1080
                $particle["VX"] = 0
                $particle["VY"] = 0
                $particle["Size"] = Get-Random -Minimum 1 -Maximum 3
                $particle["Color"] = "#FFFFFF"
                $particle["Opacity"] = Get-Random -Minimum 0.3 -Maximum 1.0
            }
        }
        
        $this.Particles.Add($particle)
    }
    
    [void] Update() {
        if (-not $this.IsActive) { return }
        
        # Spawn new particles occasionally
        if ((Get-Random -Minimum 0 -Maximum 10) -lt 3) {
            $this.SpawnParticle()
        }
        
        # Update existing particles
        $toRemove = @()
        
        for ($i = 0; $i -lt $this.Particles.Count; $i++) {
            $p = $this.Particles[$i]
            
            # Apply physics based on effect type
            switch ($p["Type"]) {
                "snow" {
                    $p["X"] += $p["VX"]
                    $p["Y"] += $p["VY"]
                    $p["Rotation"] += $p["RotationSpeed"]
                    $p["VY"] += 0.01 # Slight gravity
                    if ((Get-Random -Minimum 0 -Maximum 10) -lt 2) {
                        $p["VX"] += (Get-Random -Minimum -0.5 -Maximum 0.5) * 0.3
                    }
                }
                "rain" {
                    $p["X"] += $p["VX"]
                    $p["Y"] += $p["VY"]
                }
                "leaves" {
                    $p["X"] += $p["VX"]
                    $p["Y"] += $p["VY"]
                    $p["Rotation"] += $p["RotationSpeed"]
                    $p["VX"] += (Get-Random -Minimum -0.1 -Maximum 0.1)
                    $p["VY"] += 0.02
                }
                "fireflies" {
                    $p["X"] += $p["VX"] * 0.5
                    $p["Y"] += $p["VY"] * 0.5
                    $p["Opacity"] = [Math]::Sin((Get-Random -Minimum 0 -Maximum 100) * 0.1) * 0.5 + 0.5
                    # Random direction changes
                    if ((Get-Random -Minimum 0 -Maximum 10) -lt 3) {
                        $p["VX"] = (Get-Random -Minimum -1 -Maximum 2)
                        $p["VY"] = (Get-Random -Minimum -1 -Maximum 2)
                    }
                }
                "petals" {
                    $p["X"] += $p["VX"]
                    $p["Y"] += $p["VY"]
                    $p["Rotation"] += $p["RotationSpeed"]
                    $p["VY"] += 0.01
                }
                "stars" {
                    # Stars twinkle in place
                    $p["Opacity"] = [Math]::Sin((Get-Random -Minimum 0 -Maximum 100) * 0.05) * 0.4 + 0.6
                }
            }
            
            $p["Life"]--
            
            # Check if particle should be removed
            $shouldRemove = $false
            
            switch ($p["Type"]) {
                "snow" { $shouldRemove = $p["Y"] -gt 1100 }
                "rain" { $shouldRemove = $p["Y"] -gt 1100 }
                "leaves" { $shouldRemove = $p["Y"] -gt 1100 -or $p["X"] -gt 2000 -or $p["X"] -lt -100 }
                "fireflies" { $shouldRemove = $p["X"] -gt 2000 -or $p["X"] -lt -100 -or $p["Y"] -gt 1100 -or $p["Y"] -lt -100 }
                "petals" { $shouldRemove = $p["Y"] -gt 1100 }
                "stars" { $shouldRemove = $false } # Stars stay
            }
            
            if ($shouldRemove -or $p["Life"] -le 0) {
                $toRemove += $i
            }
        }
        
        # Remove dead particles
        foreach ($idx in ($toRemove | Sort-Object -Descending)) {
            $this.Particles.RemoveAt($idx)
        }
    }
    
    [hashtable] GetParticles() {
        $this.Update()
        
        $particleList = @()
        foreach ($p in $this.Particles) {
            $particleList += @{
                "X" = [int]$p["X"]
                "Y" = [int]$p["Y"]
                "Size" = [int]$p["Size"]
                "Opacity" = [double]$p["Opacity"]
                "Rotation" = [double]$p["Rotation"]
                "Color" = $p["Color"]
            }
        }
        
        return @{
            "Particles" = $particleList
            "Count" = $particleList.Count
            "Effect" = $this.CurrentEffect
            "IsActive" = $this.IsActive
        }
    }
    
    [void] AutoDetectSeasonalEffect() {
        $month = (Get-Date).Month
        
        switch ($month) {
            { $_ -eq 12 -or $_ -eq 1 -or $_ -eq 2 } {
                $this.StartEffect("snow")
            }
            { $_ -eq 3 -or $_ -eq 4 } {
                $this.StartEffect("petals")
            }
            { $_ -eq 9 -or $_ -eq 10 } {
                $this.StartEffect("leaves")
            }
            { $_ -eq 7 -or $_ -eq 8 } {
                $this.StartEffect("fireflies")
            }
            default {
                $this.StartEffect("stars")
            }
        }
    }
    
    [string[]] GetAvailableEffects() {
        return @("snow", "rain", "leaves", "fireflies", "petals", "stars", "none")
    }
    
    [void] SetEffectByName([string]$effectName) {
        $available = $this.GetAvailableEffects()
        if ($available -contains $effectName) {
            if ($effectName -eq "none") {
                $this.StopEffect()
            } else {
                $this.StartEffect($effectName)
            }
        }
    }
}

# Initialize particle system
$gooseParticles = [GooseParticles]::new()

# Export functions
function Get-GooseParticles {
    return $gooseParticles
}

function Start-ParticleEffect {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Effect,
        $Particles = $gooseParticles
    )
    $Particles.StartEffect($Effect)
}

function Stop-ParticleEffect {
    param($Particles = $gooseParticles)
    $Particles.StopEffect()
}

function Get-ParticleData {
    param($Particles = $gooseParticles)
    return $Particles.GetParticles()
}

function Get-AvailableEffects {
    param($Particles = $gooseParticles)
    return $Particles.GetAvailableEffects()
}

# Example usage
Write-Host "Desktop Goose Particle Effects Initialized"
Write-Host "Available effects: $($gooseParticles.GetAvailableEffects() -join ', ')"
