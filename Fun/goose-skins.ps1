# Desktop Goose Custom Skins System
# Load custom goose sprites and colors

class GooseCustomSkins {
    [hashtable]$Config
    [string]$SkinsDirectory
    [string]$CurrentSkin
    [hashtable]$AvailableSkins
    [hashtable]$SkinDefaults
    
    GooseCustomSkins() {
        $this.Config = $this.LoadConfig()
        $this.SkinsDirectory = "Skins"
        $this.CurrentSkin = "default"
        $this.AvailableSkins = @{}
        $this.SkinDefaults = @{
            "default" = @{
                "Name" = "Classic White"
                "Description" = "The original goose look"
                "WhiteColor" = "#ffffff"
                "OrangeColor" = "#ffa500"
                "OutlineColor" = "#d3d3d3"
            }
        }
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
        
        if (-not $this.Config.ContainsKey("CustomSkinsEnabled")) {
            $this.Config["CustomSkinsEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("CurrentSkin")) {
            $this.Config["CurrentSkin"] = "default"
        }
        
        return $this.Config
    }
    
    [void] InitializeSkinsDirectory() {
        if (-not (Test-Path $this.SkinsDirectory)) {
            New-Item -ItemType Directory -Path $this.SkinsDirectory | Out-Null
        }
        
        $defaultSkinPath = Join-Path $this.SkinsDirectory "default"
        if (-not (Test-Path $defaultSkinPath)) {
            New-Item -ItemType Directory -Path $defaultSkinPath | Out-Null
            
            $skinConfig = @{
                "Name" = "Classic White"
                "Description" = "The original goose look"
                "WhiteColor" = "#ffffff"
                "OrangeColor" = "#ffa500"
                "OutlineColor" = "#d3d3d3"
            }
            
            $skinConfig | ConvertTo-Json | Out-File -FilePath (Join-Path $defaultSkinPath "skin.json") -Encoding UTF8
        }
    }
    
    [void] ScanAvailableSkins() {
        $this.InitializeSkinsDirectory()
        
        $this.AvailableSkins = @{}
        
        $skinDirs = Get-ChildItem -Path $this.SkinsDirectory -Directory
        foreach ($skinDir in $skinDirs) {
            $skinConfigPath = Join-Path $skinDir.FullName "skin.json"
            
            if (Test-Path $skinConfigPath) {
                $skinData = Get-Content $skinConfigPath | ConvertFrom-Json
                $this.AvailableSkins[$skinDir.Name] = $skinData
            }
        }
        
        if ($this.AvailableSkins.Count -eq 0) {
            $this.AvailableSkins = $this.SkinDefaults
        }
    }
    
    [hashtable] ApplySkin([string]$skinName) {
        if ($this.AvailableSkins.Count -eq 0) {
            $this.ScanAvailableSkins()
        }
        
        if (-not $this.AvailableSkins.ContainsKey($skinName)) {
            return @{
                "Success" = $false
                "Message" = "Skin '$skinName' not found"
                "AvailableSkins" = ($this.AvailableSkins.Keys | ForEach-Object { $_ })
            }
        }
        
        $skin = $this.AvailableSkins[$skinName]
        $this.CurrentSkin = $skinName
        $this.Config["CurrentSkin"] = $skinName
        
        return @{
            "Success" = $true
            "Skin" = $skin
            "Message" = "Applied skin: $($skin.Name)"
        }
    }
    
    [hashtable] CreateSkin([string]$name, [string]$description, [string]$whiteColor, [string]$orangeColor, [string]$outlineColor) {
        $skinId = $name.ToLower() -replace '[^\w]', ''
        
        $this.InitializeSkinsDirectory()
        
        $skinPath = Join-Path $this.SkinsDirectory $skinId
        if (Test-Path $skinPath) {
            return @{
                "Success" = $false
                "Message" = "Skin already exists"
            }
        }
        
        New-Item -ItemType Directory -Path $skinPath | Out-Null
        
        $skinConfig = @{
            "Name" = $name
            "Description" = $description
            "WhiteColor" = $whiteColor
            "OrangeColor" = $orangeColor
            "OutlineColor" = $outlineColor
            "Created" = (Get-Date).ToString("o")
        }
        
        $skinConfig | ConvertTo-Json | Out-File -FilePath (Join-Path $skinPath "skin.json") -Encoding UTF8
        
        $this.AvailableSkins[$skinId] = $skinConfig
        
        return @{
            "Success" = $true
            "SkinId" = $skinId
            "Skin" = $skinConfig
            "Message" = "Created skin: $name"
        }
    }
    
    [hashtable] DeleteSkin([string]$skinId) {
        if ($skinId -eq "default") {
            return @{
                "Success" = $false
                "Message" = "Cannot delete default skin"
            }
        }
        
        $skinPath = Join-Path $this.SkinsDirectory $skinId
        
        if (-not (Test-Path $skinPath)) {
            return @{
                "Success" = $false
                "Message" = "Skin not found"
            }
        }
        
        Remove-Item -Path $skinPath -Recurse -Force
        
        if ($this.AvailableSkins.ContainsKey($skinId)) {
            $this.AvailableSkins.Remove($skinId)
        }
        
        if ($this.CurrentSkin -eq $skinId) {
            $this.ApplySkin("default") | Out-Null
        }
        
        return @{
            "Success" = $true
            "Message" = "Deleted skin: $skinId"
        }
    }
    
    [hashtable] GetCustomSkinsState() {
        if ($this.AvailableSkins.Count -eq 0) {
            $this.ScanAvailableSkins()
        }
        
        return @{
            "Enabled" = $this.Config["CustomSkinsEnabled"]
            "CurrentSkin" = $this.CurrentSkin
            "SkinsDirectory" = $this.SkinsDirectory
            "AvailableSkins" = $this.AvailableSkins
            "SkinCount" = $this.AvailableSkins.Count
        }
    }
    
    [hashtable] GetCurrentSkinColors() {
        if ($this.AvailableSkins.Count -eq 0) {
            $this.ScanAvailableSkins()
        }
        
        if ($this.AvailableSkins.ContainsKey($this.CurrentSkin)) {
            $skin = $this.AvailableSkins[$this.CurrentSkin]
            return @{
                "WhiteColor" = $skin.WhiteColor
                "OrangeColor" = $skin.OrangeColor
                "OutlineColor" = $skin.OutlineColor
            }
        }
        
        return @{
            "WhiteColor" = "#ffffff"
            "OrangeColor" = "#ffa500"
            "OutlineColor" = "#d3d3d3"
        }
    }
}

$gooseCustomSkins = [GooseCustomSkins]::new()

function Get-GooseCustomSkins {
    return $gooseCustomSkins
}

function Get-CustomSkinsState {
    param($Skins = $gooseCustomSkins)
    return $Skins.GetCustomSkinsState()
}

function Apply-GooseSkin {
    param(
        [string]$SkinName,
        $Skins = $gooseCustomSkins
    )
    return $Skins.ApplySkin($SkinName)
}

function New-GooseSkin {
    param(
        [string]$Name,
        [string]$Description = "",
        [string]$WhiteColor = "#ffffff",
        [string]$OrangeColor = "#ffa500",
        [string]$OutlineColor = "#d3d3d3",
        $Skins = $gooseCustomSkins
    )
    return $Skins.CreateSkin($Name, $Description, $WhiteColor, $OrangeColor, $OutlineColor)
}

function Get-CurrentSkinColors {
    param($Skins = $gooseCustomSkins)
    return $Skins.GetCurrentSkinColors()
}

Write-Host "Desktop Goose Custom Skins System Initialized"
$state = Get-CustomSkinsState
Write-Host "Custom Skins Enabled: $($state['Enabled'])"
Write-Host "Current Skin: $($state['CurrentSkin'])"
Write-Host "Available Skins: $($state['SkinCount'])"
