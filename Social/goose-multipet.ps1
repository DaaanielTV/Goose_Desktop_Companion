# Desktop Goose Multi-Pet System
# Support for multiple pets

class GooseMultiPet {
    [hashtable]$Config
    [array]$Pets
    [string]$ActivePet
    [string]$PetFile
    
    GooseMultiPet() {
        $this.Config = $this.LoadConfig()
        $this.PetFile = "goose_pets.json"
        $this.Pets = @()
        $this.ActivePet = "goose"
        $this.LoadPets()
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
        
        return $this.Config
    }
    
    [void] LoadPets() {
        if (Test-Path $this.PetFile) {
            try {
                $this.Pets = Get-Content $this.PetFile | ConvertFrom-Json
                if ($this.Pets -isnot [array]) {
                    $this.Pets = @()
                }
            } catch {
                $this.Pets = @()
            }
        }
        
        if ($this.Pets.Count -eq 0) {
            $this.AddDefaultPets()
        }
    }
    
    [void] SavePets() {
        $this.Pets | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.PetFile -Encoding UTF8
    }
    
    [void] AddDefaultPets() {
        $this.Pets = @(
            @{
                "Id" = "goose"
                "Name" = "Desktop Goose"
                "Type" = "goose"
                "Emoji" = "🦆"
                "Active" = $true
            }
        )
        $this.SavePets()
    }
    
    [hashtable] AddPet([string]$name, [string]$type, [string]$emoji) {
        $pet = @{
            "Id" = $name.ToLower() -replace ' ', '_'
            "Name" = $name
            "Type" = $type
            "Emoji" = $emoji
            "Active" = $false
        }
        
        $this.Pets += $pet
        $this.SavePets()
        
        return @{
            "Success" = $true
            "Pet" = $pet
            "Message" = "Added new pet: $name"
        }
    }
    
    [hashtable] SwitchPet([string]$petId) {
        $pet = $this.Pets | Where-Object { $_.Id -eq $petId } | Select-Object -First 1
        
        if (-not $pet) {
            return @{
                "Success" = $false
                "Message" = "Pet not found: $petId"
            }
        }
        
        foreach ($p in $this.Pets) {
            $p.Active = ($p.Id -eq $petId)
        }
        
        $this.ActivePet = $petId
        $this.SavePets()
        
        return @{
            "Success" = $true
            "Pet" = $pet
            "Message" = "Switched to: $($pet.Name) $($pet.Emoji)"
        }
    }
    
    [hashtable] RemovePet([string]$petId) {
        if ($petId -eq "goose") {
            return @{
                "Success" = $false
                "Message" = "Cannot remove the default goose"
            }
        }
        
        $initialCount = $this.Pets.Count
        $this.Pets = $this.Pets | Where-Object { $_.Id -ne $petId }
        
        if ($this.Pets.Count -lt $initialCount) {
            if ($this.ActivePet -eq $petId) {
                $this.SwitchPet("goose") | Out-Null
            }
            $this.SavePets()
            return @{
                "Success" = $true
                "Message" = "Pet removed"
            }
        }
        
        return @{
            "Success" = $false
            "Message" = "Pet not found"
        }
    }
    
    [array] GetAvailablePets() {
        return $this.Pets
    }
    
    [hashtable] GetActivePet() {
        return $this.Pets | Where-Object { $_.Active } | Select-Object -First 1
    }
    
    [hashtable] GetMultiPetState() {
        return @{
            "Enabled" = $this.Config["MultiPetEnabled"]
            "Pets" = $this.Pets
            "ActivePet" = $this.GetActivePet()
            "PetCount" = $this.Pets.Count
        }
    }
}

$gooseMultiPet = [GooseMultiPet]::new()

function Get-GooseMultiPet {
    return $gooseMultiPet
}

function Add-NewPet {
    param(
        [string]$Name,
        [string]$Type,
        [string]$Emoji,
        $MultiPet = $gooseMultiPet
    )
    return $MultiPet.AddPet($Name, $Type, $Emoji)
}

function Switch-ToPet {
    param(
        [string]$PetId,
        $MultiPet = $gooseMultiPet
    )
    return $MultiPet.SwitchPet($PetId)
}

function Get-AvailablePets {
    param($MultiPet = $gooseMultiPet)
    return $MultiPet.GetAvailablePets()
}

function Get-MultiPetState {
    param($MultiPet = $gooseMultiPet)
    return $MultiPet.GetMultiPetState()
}

Write-Host "Desktop Goose Multi-Pet System Initialized"
$state = Get-MultiPetState
Write-Host "Available Pets: $($state['PetCount'])"
Write-Host "Active Pet: $($state['ActivePet']['Name'])"
