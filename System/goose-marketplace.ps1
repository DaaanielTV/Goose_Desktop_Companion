# Desktop Goose Marketplace
# Download and manage skins, plugins, and behaviors

enum MarketplaceItemType {
    Plugin
    Skin
    Behavior
    Theme
}

class MarketplaceItem {
    [string]$Id
    [string]$Name
    [string]$Description
    [MarketplaceItemType]$Type
    [string]$Author
    [string]$Version
    [string]$DownloadUrl
    [string]$ImageUrl
    [int]$Downloads
    [float]$Rating
    [string[]]$Tags
    [datetime]$LastUpdated
    
    [string] GetTypeString() {
        return $this.Type.ToString().ToLower()
    }
}

class GooseMarketplace {
    [hashtable]$Config
    [System.Collections.ArrayList]$AvailableItems
    [hashtable]$InstalledItems
    [string]$CacheFile
    [string]$DownloadDirectory
    [bool]$Enabled
    
    GooseMarketplace() {
        $this.Config = $this.LoadConfig()
        $this.AvailableItems = [System.Collections.ArrayList]::new()
        $this.InstalledItems = @{}
        $this.CacheFile = "goose_marketplace_cache.json"
        $this.DownloadDirectory = "downloads"
        $this.Enabled = $false
        $this.LoadCache()
        $this.InitializeFeaturedItems()
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
        
        if (-not $this.Config.ContainsKey("MarketplaceEnabled")) {
            $this.Config["MarketplaceEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] LoadCache() {
        if (Test-Path $this.CacheFile) {
            try {
                $data = Get-Content $this.CacheFile -Raw | ConvertFrom-Json
                if ($data.installedItems) {
                    $this.InstalledItems = @{}
                    $data.installedItems.PSObject.Properties | ForEach-Object {
                        $this.InstalledItems[$_.Name] = $_.Value
                    }
                }
            } catch {}
        }
        
        $this.Enabled = $this.Config["MarketplaceEnabled"]
    }
    
    [void] SaveCache() {
        $data = @{
            installedItems = $this.InstalledItems
            lastUpdated = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.CacheFile -Encoding UTF8
    }
    
    [void] InitializeFeaturedItems() {
        $featured = @(
            [MarketplaceItem]@{
                Id = "spotify-goose"
                Name = "Spotify Goose"
                Description = "Goose reacts to Spotify playback - dances, shows current track"
                Type = [MarketplaceItemType]::Plugin
                Author = "Community"
                Version = "1.0.0"
                DownloadUrl = ""
                ImageUrl = ""
                Downloads = 1523
                Rating = 4.8
                Tags = @("music", "spotify", "reactions")
                LastUpdated = Get-Date
            },
            [MarketplaceItem]@{
                Id = "discord-goose"
                Name = "Discord Goose"
                Description = "Goose notifies about Discord messages and shows status"
                Type = [MarketplaceItemType]::Plugin
                Author = "Community"
                Version = "1.2.0"
                DownloadUrl = ""
                ImageUrl = ""
                Downloads = 892
                Rating = 4.5
                Tags = @("discord", "notifications", "chat")
                LastUpdated = Get-Date
            },
            [MarketplaceItem]@{
                Id = "weather-goose"
                Name = "Weather Goose"
                Description = "Goose shows current weather and changes based on conditions"
                Type = [MarketplaceItemType]::Plugin
                Author = "Community"
                Version = "1.0.0"
                DownloadUrl = ""
                ImageUrl = ""
                Downloads = 2341
                Rating = 4.7
                Tags = @("weather", "widget", "information")
                LastUpdated = Get-Date
            },
            [MarketplaceItem]@{
                Id = "meme-goose"
                Name = "Meme Goose"
                Description = "Goose drags random memes across your screen"
                Type = [MarketplaceItemType]::Behavior
                Author = "Community"
                Version = "2.0.0"
                DownloadUrl = ""
                ImageUrl = ""
                Downloads = 3421
                Rating = 4.9
                Tags = @("memes", "fun", "chaos")
                LastUpdated = Get-Date
            },
            [MarketplaceItem]@{
                Id = "golden-goose"
                Name = "Golden Goose"
                Description = "A shiny golden goose skin - shows dedication!"
                Type = [MarketplaceItemType]::Skin
                Author = "Official"
                Version = "1.0.0"
                DownloadUrl = ""
                ImageUrl = ""
                Downloads = 5672
                Rating = 5.0
                Tags = @("skin", "gold", "premium")
                LastUpdated = Get-Date
            },
            [MarketplaceItem]@{
                Id = "ninja-goose"
                Name = "Ninja Goose"
                Description = "Sneaky ninja goose with stealth abilities"
                Type = [MarketplaceItemType]::Skin
                Author = "Community"
                Version = "1.0.0"
                DownloadUrl = ""
                ImageUrl = ""
                Downloads = 2156
                Rating = 4.6
                Tags = @("skin", "ninja", "stealth")
                LastUpdated = Get-Date
            },
            [MarketplaceItem]@{
                Id = "hacker-goose"
                Name = "Hacker Goose"
                Description = "Matrix-style hacker goose with green effects"
                Type = [MarketplaceItemType]::Skin
                Author = "Community"
                Version = "1.5.0"
                DownloadUrl = ""
                ImageUrl = ""
                Downloads = 4523
                Rating = 4.8
                Tags = @("skin", "hacker", "matrix", "code")
                LastUpdated = Get-Date
            },
            [MarketplaceItem]@{
                Id = "dark-theme-goose"
                Name = "Dark Theme"
                Description = "Dark mode for all goose UI elements"
                Type = [MarketplaceItemType]::Theme
                Author = "Official"
                Version = "1.0.0"
                DownloadUrl = ""
                ImageUrl = ""
                Downloads = 3211
                Rating = 4.4
                Tags = @("theme", "dark", "ui")
                LastUpdated = Get-Date
            }
        )
        
        foreach ($item in $featured) {
            $this.AvailableItems.Add($item)
        }
    }
    
    [hashtable] Search([string]$query = "", [MarketplaceItemType]$type = $null) {
        $results = $this.AvailableItems
        
        if ($query) {
            $queryLower = $query.ToLower()
            $results = $results | Where-Object {
                $_.Name.ToLower().Contains($queryLower) -or
                $_.Description.ToLower().Contains($queryLower) -or
                $_.Tags -contains $queryLower
            }
        }
        
        if ($type) {
            $results = $results | Where-Object { $_.Type -eq $type }
        }
        
        return @($results | ForEach-Object {
            @{
                Id = $_.Id
                Name = $_.Name
                Description = $_.Description
                Type = $_.GetTypeString()
                Author = $_.Author
                Version = $_.Version
                Downloads = $_.Downloads
                Rating = $_.Rating
                Tags = $_.Tags
                Installed = $this.InstalledItems.ContainsKey($_.Id)
            }
        })
    }
    
    [hashtable] GetByType([MarketplaceItemType]$type) {
        return $this.Search("", $type)
    }
    
    [hashtable] GetFeatured() {
        return @($this.AvailableItems | Sort-Object -Property Downloads -Descending | Select-Object -First 10 | ForEach-Object {
            @{
                Id = $_.Id
                Name = $_.Name
                Description = $_.Description
                Type = $_.GetTypeString()
                Author = $_.Author
                Rating = $_.Rating
                Downloads = $_.Downloads
                Installed = $this.InstalledItems.ContainsKey($_.Id)
            }
        })
    }
    
    [hashtable] GetPlugins() {
        return $this.GetByType([MarketplaceItemType]::Plugin)
    }
    
    [hashtable] GetSkins() {
        return $this.GetByType([MarketplaceItemType]::Skin)
    }
    
    [hashtable] GetBehaviors() {
        return $this.GetByType([MarketplaceItemType]::Behavior)
    }
    
    [hashtable] GetThemes() {
        return $this.GetByType([MarketplaceItemType]::Theme)
    }
    
    [hashtable] Install([string]$itemId) {
        $result = @{
            success = $false
            message = ""
        }
        
        $item = $this.AvailableItems | Where-Object { $_.Id -eq $itemId } | Select-Object -First 1
        
        if (-not $item) {
            $result.message = "Item not found: $itemId"
            return $result
        }
        
        if ($this.InstalledItems.ContainsKey($itemId)) {
            $result.message = "Already installed: $($item.Name)"
            return $result
        }
        
        $installPath = switch ($item.Type) {
            ([MarketplaceItemType]::Plugin) { "plugins\$($itemId)" }
            ([MarketplaceItemType]::Skin) { "skins\$($itemId)" }
            ([MarketplaceItemType]::Behavior) { "behaviors\$($itemId)" }
            ([MarketplaceItemType]::Theme) { "themes\$($itemId)" }
            default { "downloads\$($itemId)" }
        }
        
        $this.InstalledItems[$itemId] = @{
            name = $item.Name
            version = $item.Version
            installedAt = (Get-Date).ToString("o")
            path = $installPath
        }
        
        $this.SaveCache()
        
        $result.success = $true
        $result.message = "Installed: $($item.Name)"
        
        return $result
    }
    
    [hashtable] Uninstall([string]$itemId) {
        $result = @{
            success = $false
            message = ""
        }
        
        if (-not $this.InstalledItems.ContainsKey($itemId)) {
            $result.message = "Not installed: $itemId"
            return $result
        }
        
        $itemName = $this.InstalledItems[$itemId].name
        $this.InstalledItems.Remove($itemId)
        
        $this.SaveCache()
        
        $result.success = $true
        $result.message = "Uninstalled: $itemName"
        
        return $result
    }
    
    [hashtable] GetInstalled() {
        return @{
            Plugins = @($this.InstalledItems.Keys | Where-Object {
                $this.AvailableItems | Where-Object { $_.Id -eq $_ -and $_.Type -eq [MarketplaceItemType]::Plugin }
            } | ForEach-Object {
                $item = $this.InstalledItems[$_]
                @{
                    Id = $_
                    Name = $item.name
                    Version = $item.version
                    InstalledAt = $item.installedAt
                }
            })
            Skins = @($this.InstalledItems.Keys | Where-Object {
                $this.AvailableItems | Where-Object { $_.Id -eq $_ -and $_.Type -eq [MarketplaceItemType]::Skin }
            })
            Behaviors = @($this.InstalledItems.Keys | Where-Object {
                $this.AvailableItems | Where-Object { $_.Id -eq $_ -and $_.Type -eq [MarketplaceItemType]::Behavior }
            })
            Themes = @($this.InstalledItems.Keys | Where-Object {
                $this.AvailableItems | Where-Object { $_.Id -eq $_ -and $_.Type -eq [MarketplaceItemType]::Theme }
            })
            TotalCount = $this.InstalledItems.Count
        }
    }
    
    [hashtable] GetMarketplaceState() {
        return @{
            Enabled = $this.Enabled
            AvailableCount = $this.AvailableItems.Count
            InstalledCount = $this.InstalledItems.Count
            Featured = $this.GetFeatured()
            Recent = @($this.AvailableItems | Sort-Object -Property LastUpdated -Descending | Select-Object -First 5 | ForEach-Object {
                @{
                    Id = $_.Id
                    Name = $_.Name
                    Type = $_.GetTypeString()
                }
            })
        }
    }
}

$gooseMarketplace = [GooseMarketplace]::new()

function Get-GooseMarketplace {
    return $gooseMarketplace
}

function Search-Marketplace {
    param(
        [string]$Query,
        [ValidateSet("", "plugin", "skin", "behavior", "theme")]
        [string]$Type = "",
        $Marketplace = $gooseMarketplace
    )
    
    $typeEnum = $null
    if ($Type) {
        $typeEnum = [MarketplaceItemType]$Type
    }
    
    return $Marketplace.Search($Query, $typeEnum)
}

function Get-FeaturedItems {
    param($Marketplace = $gooseMarketplace)
    return $Marketplace.GetFeatured()
}

function Get-AvailablePlugins {
    param($Marketplace = $gooseMarketplace)
    return $Marketplace.GetPlugins()
}

function Get-AvailableSkins {
    param($Marketplace = $gooseMarketplace)
    return $Marketplace.GetSkins()
}

function Install-MarketplaceItem {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ItemId,
        $Marketplace = $gooseMarketplace
    )
    return $Marketplace.Install($ItemId)
}

function Uninstall-MarketplaceItem {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ItemId,
        $Marketplace = $gooseMarketplace
    )
    return $Marketplace.Uninstall($ItemId)
}

function Get-InstalledItems {
    param($Marketplace = $gooseMarketplace)
    return $Marketplace.GetInstalled()
}

function Get-MarketplaceState {
    param($Marketplace = $gooseMarketplace)
    return $Marketplace.GetMarketplaceState()
}

Write-Host "Desktop Goose Marketplace Initialized"
$state = Get-MarketplaceState
Write-Host "Marketplace Enabled: $($state['Enabled']) | Available: $($state['AvailableCount']) | Installed: $($state['InstalledCount'])"
