# Desktop Goose Enhanced Clipboard Manager System
# Full clipboard history with pinning, search, and categories

class GooseClipboardManager {
    [hashtable]$Config
    [array]$History
    [array]$Pinned
    [int]$HistoryLimit
    [int]$PinnedLimit
    [string]$DataFile
    [bool]$IsEnabled
    [datetime]$LastClipboardChange
    
    GooseClipboardManager() {
        $this.Config = $this.LoadConfig()
        $this.DataFile = "goose_clipboard.json"
        $this.History = @()
        $this.Pinned = @()
        $this.HistoryLimit = 50
        $this.PinnedLimit = 10
        $this.LastClipboardChange = Get-Date
        $this.IsEnabled = $false
        $this.LoadData()
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
        
        if (-not $this.Config.ContainsKey("ClipboardManagerEnabled")) {
            $this.Config["ClipboardManagerEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("ClipboardHistoryLimit")) {
            $this.Config["ClipboardHistoryLimit"] = 50
        }
        if (-not $this.Config.ContainsKey("ClipboardPinnedLimit")) {
            $this.Config["ClipboardPinnedLimit"] = 10
        }
        if (-not $this.Config.ContainsKey("ClipboardAutoPaste")) {
            $this.Config["ClipboardAutoPaste"] = $false
        }
        if (-not $this.Config.ContainsKey("ClipboardImageStorage")) {
            $this.Config["ClipboardImageStorage"] = $true
        }
        
        $this.HistoryLimit = $this.Config["ClipboardHistoryLimit"]
        $this.PinnedLimit = $this.Config["ClipboardPinnedLimit"]
        
        return $this.Config
    }
    
    [void] LoadData() {
        if (Test-Path $this.DataFile) {
            try {
                $data = Get-Content $this.DataFile -Raw | ConvertFrom-Json
                
                if ($data.history) {
                    $this.History = @($data.history)
                }
                
                if ($data.pinned) {
                    $this.Pinned = @($data.pinned)
                }
            } catch {
                $this.History = @()
                $this.Pinned = @()
            }
        }
        
        $this.IsEnabled = $this.Config["ClipboardManagerEnabled"]
    }
    
    [void] SaveData() {
        $data = @{
            "history" = $this.History
            "pinned" = $this.Pinned
            "settings" = @{
                "historyLimit" = $this.HistoryLimit
                "pinnedLimit" = $this.PinnedLimit
                "autoPaste" = $this.Config["ClipboardAutoPaste"]
                "imageStorage" = $this.Config["ClipboardImageStorage"]
            }
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content $this.DataFile
    }
    
    [string] GetContentType([string]$content) {
        if ([string]::IsNullOrWhiteSpace($content)) {
            return "empty"
        }
        
        if ($content -match "^http[s]?://") {
            return "url"
        }
        
        if ($content -match "\.(jpg|jpeg|png|gif|bmp|webp)$" -or $content -match "^data:image") {
            return "image"
        }
        
        if ($content -match "^[A-Z]:\\|^\/") {
            return "file"
        }
        
        if ($content -match "^[\s\S]{100,}$") {
            return "longtext"
        }
        
        return "text"
    }
    
    [hashtable] AddToHistory([string]$content) {
        if ([string]::IsNullOrWhiteSpace($content)) {
            return @{
                "Success" = $false
                "Message" = "Empty content"
            }
        }
        
        $existing = $this.History | Where-Object { $_.content -eq $content } | Select-Object -First 1
        if ($existing) {
            $this.History = $this.History | Where-Object { $_.content -ne $content }
        }
        
        $contentType = $this.GetContentType($content)
        
        $item = @{
            "id" = [guid]::NewGuid().ToString()
            "content" = $content
            "type" = $contentType
            "timestamp" = (Get-Date).ToString("o")
            "preview" = if ($content.Length -gt 50) { $content.Substring(0, 50) + "..." } else { $content }
            "charCount" = $content.Length
            "pinned" = $false
        }
        
        $this.History = @($item) + $this.History
        
        if ($this.History.Count -gt $this.HistoryLimit) {
            $this.History = $this.History[0..($this.HistoryLimit - 1)]
        }
        
        $this.LastClipboardChange = Get-Date
        $this.SaveData()
        
        return @{
            "Success" = $true
            "Item" = $item
            "Message" = "Added to clipboard history"
        }
    }
    
    [hashtable] AddImageToHistory([string]$base64Image, [string]$format = "png") {
        $content = "data:image/$format;base64," + $base64Image
        
        return $this.AddToHistory($content)
    }
    
    [hashtable[]] GetHistory([int]$count = -1, [string]$type = $null) {
        $items = $this.History
        
        if ($type) {
            $items = $items | Where-Object { $_.type -eq $type }
        }
        
        if ($count -gt 0 -and $count -lt $items.Count) {
            return @($items[0..($count - 1)])
        }
        
        return @($items)
    }
    
    [hashtable[]] GetPinned() {
        return @($this.Pinned)
    }
    
    [hashtable[]] GetAllItems() {
        $pinnedWithIndex = @()
        for ($i = 0; $i -lt $this.Pinned.Count; $i++) {
            $item = $this.Pinned[$i]
            $item.index = $i + 1
            $pinnedWithIndex += $item
        }
        
        return @{
            "pinned" = $pinnedWithIndex
            "history" = $this.History
        }
    }
    
    [hashtable] PinItem([string]$itemId) {
        $item = $this.History | Where-Object { $_.id -eq $itemId } | Select-Object -First 1
        
        if (-not $item) {
            return @{
                "Success" = $false
                "Message" = "Item not found in history"
            }
        }
        
        if ($this.Pinned.Count -ge $this.PinnedLimit) {
            return @{
                "Success" = $false
                "Message" = "Pinned limit reached. Unpin an item first."
            }
        }
        
        if ($this.Pinned | Where-Object { $_.id -eq $itemId }) {
            return @{
                "Success" = $false
                "Message" = "Item already pinned"
            }
        }
        
        $pinnedItem = @{
            "id" = $item.id
            "content" = $item.content
            "type" = $item.type
            "timestamp" = $item.timestamp
            "preview" = $item.preview
            "charCount" = $item.charCount
            "pinned" = $true
            "pinnedAt" = (Get-Date).ToString("o")
        }
        
        $this.Pinned = @($pinnedItem) + $this.Pinned
        $this.History = $this.History | Where-Object { $_.id -ne $itemId }
        $this.SaveData()
        
        return @{
            "Success" = $true
            "Item" = $pinnedItem
            "Message" = "Item pinned"
        }
    }
    
    [hashtable] UnpinItem([string]$itemId) {
        $pinnedItem = $this.Pinned | Where-Object { $_.id -eq $itemId } | Select-Object -First 1
        
        if (-not $pinnedItem) {
            return @{
                "Success" = $false
                "Message" = "Item not found in pinned"
            }
        }
        
        $this.Pinned = $this.Pinned | Where-Object { $_.id -ne $itemId }
        
        $item = @{
            "id" = $pinnedItem.id
            "content" = $pinnedItem.content
            "type" = $pinnedItem.type
            "timestamp" = $pinnedItem.timestamp
            "preview" = $pinnedItem.preview
            "charCount" = $pinnedItem.charCount
            "pinned" = $false
        }
        
        $this.History = @($item) + $this.History
        $this.SaveData()
        
        return @{
            "Success" = $true
            "Message" = "Item unpinned"
        }
    }
    
    [hashtable] DeleteItem([string]$itemId) {
        $pinnedItem = $this.Pinned | Where-Object { $_.id -eq $itemId }
        if ($pinnedItem) {
            $this.Pinned = $this.Pinned | Where-Object { $_.id -ne $itemId }
            $this.SaveData()
            return @{
                "Success" = $true
                "Message" = "Item deleted from pinned"
            }
        }
        
        $this.History = $this.History | Where-Object { $_.id -ne $itemId }
        $this.SaveData()
        
        return @{
            "Success" = $true
            "Message" = "Item deleted from history"
        }
    }
    
    [hashtable[]] SearchHistory([string]$query) {
        if ([string]::IsNullOrWhiteSpace($query)) {
            return @()
        }
        
        $query = $query.ToLower()
        
        $results = @()
        
        foreach ($item in $this.Pinned) {
            if ($item.content.ToLower().Contains($query)) {
                $results += $item
            }
        }
        
        foreach ($item in $this.History) {
            if ($item.content.ToLower().Contains($query)) {
                if (-not ($results | Where-Object { $_.id -eq $item.id })) {
                    $results += $item
                }
            }
        }
        
        return $results
    }
    
    [hashtable] ClearHistory() {
        $this.History = @()
        $this.SaveData()
        
        return @{
            "Success" = $true
            "Message" = "Clipboard history cleared (pinned items preserved)"
        }
    }
    
    [hashtable] ClearPinned() {
        $this.Pinned = @()
        $this.SaveData()
        
        return @{
            "Success" = $true
            "Message" = "All pinned items cleared"
        }
    }
    
    [hashtable] ClearAll() {
        $this.History = @()
        $this.Pinned = @()
        $this.SaveData()
        
        return @{
            "Success" = $true
            "Message" = "All clipboard data cleared"
        }
    }
    
    [hashtable] CopyToClipboard([string]$itemId) {
        $item = $this.Pinned | Where-Object { $_.id -eq $itemId } | Select-Object -First 1
        
        if (-not $item) {
            $item = $this.History | Where-Object { $_.id -eq $itemId } | Select-Object -First 1
        }
        
        if (-not $item) {
            return @{
                "Success" = $false
                "Message" = "Item not found"
            }
        }
        
        try {
            Set-Clipboard -Value $item.content
            return @{
                "Success" = $true
                "Message" = "Copied to clipboard"
            }
        } catch {
            return @{
                "Success" = $false
                "Message" = "Failed to copy: $($_.Exception.Message)"
            }
        }
    }
    
    [hashtable] QuickPaste([int]$number) {
        if ($number -ge 1 -and $number -le 9 -and $number -le $this.Pinned.Count) {
            $item = $this.Pinned[$number - 1]
            return $this.CopyToClipboard($item.id)
        }
        
        return @{
            "Success" = $false
            "Message" = "Invalid quick paste number"
        }
    }
    
    [void] SetEnabled([bool]$enabled) {
        $this.IsEnabled = $enabled
        $this.Config["ClipboardManagerEnabled"] = $enabled
    }
    
    [void] Toggle() {
        $this.IsEnabled = -not $this.IsEnabled
        $this.Config["ClipboardManagerEnabled"] = $this.IsEnabled
    }
    
    [hashtable] GetStats() {
        $typeCounts = @{
            "text" = 0
            "url" = 0
            "image" = 0
            "file" = 0
            "longtext" = 0
        }
        
        foreach ($item in $this.History) {
            if ($typeCounts.ContainsKey($item.type)) {
                $typeCounts[$item.type]++
            }
        }
        
        return @{
            "totalHistory" = $this.History.Count
            "totalPinned" = $this.Pinned.Count
            "typeCounts" = $typeCounts
            "historyLimit" = $this.HistoryLimit
            "pinnedLimit" = $this.PinnedLimit
        }
    }
    
    [hashtable] GetClipboardManagerState() {
        return @{
            "Enabled" = $this.IsEnabled
            "History" = $this.GetHistory(20, $null)
            "Pinned" = $this.GetPinned()
            "Stats" = $this.GetStats()
            "LastChange" = $this.LastClipboardChange
            "AutoPaste" = $this.Config["ClipboardAutoPaste"]
            "ImageStorage" = $this.Config["ClipboardImageStorage"]
        }
    }
    
    [string] GetWidgetHtml() {
        $state = $this.GetClipboardManagerState()
        
        $html = "<div class='clipboard-widget'>"
        $html += "<div class='clipboard-header'>"
        $html += "<span>Clipboard Manager</span>"
        $html += "<button onclick='clearClipboardHistory()'>Clear</button>"
        $html += "</div>"
        
        if ($state.Pinned.Count -gt 0) {
            $html += "<div class='clipboard-section'>"
            $html += "<div class='clipboard-section-title'>Pinned (Press 1-$($state.Pinned.Count) to paste)</div>"
            for ($i = 0; $i -lt $state.Pinned.Count; $i++) {
                $item = $state.Pinned[$i]
                $html += "<div class='clipboard-item pinned' data-index='$($i + 1)'>"
                $html += "<span class='clipboard-key'>$($i + 1)</span>"
                $html += "<span class='clipboard-preview'>$($item.preview)</span>"
                $html += "<span class='clipboard-type'>$($item.type)</span>"
                $html += "</div>"
            }
            $html += "</div>"
        }
        
        $html += "<div class='clipboard-section'>"
        $html += "<div class='clipboard-section-title'>Recent History</div>"
        $displayCount = [Math]::Min(10, $state.History.Count)
        for ($i = 0; $i -lt $displayCount; $i++) {
            $item = $state.History[$i]
            $html += "<div class='clipboard-item'>"
            $html += "<span class='clipboard-preview'>$($item.preview)</span>"
            $html += "<span class='clipboard-type'>$($item.type)</span>"
            $html += "<button class='pin-btn' data-id='$($item.id)'>Pin</button>"
            $html += "</div>"
        }
        $html += "</div>"
        
        $html += "</div>"
        
        return $html
    }
}

$gooseClipboardManager = [GooseClipboardManager]::new()

function Get-GooseClipboardManager {
    return $gooseClipboardManager
}

function Add-ClipboardItem {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        $Manager = $gooseClipboardManager
    )
    return $Manager.AddToHistory($Content)
}

function Add-ClipboardImage {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Base64Image,
        [string]$Format = "png",
        $Manager = $gooseClipboardManager
    )
    return $Manager.AddImageToHistory($Base64Image, $Format)
}

function Get-ClipboardHistory {
    param(
        [int]$Count = -1,
        [string]$Type = $null,
        $Manager = $gooseClipboardManager
    )
    return $Manager.GetHistory($Count, $Type)
}

function Get-ClipboardPinned {
    param($Manager = $gooseClipboardManager)
    return $Manager.GetPinned()
}

function Get-ClipboardAllItems {
    param($Manager = $gooseClipboardManager)
    return $Manager.GetAllItems()
}

function Pin-ClipboardItem {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ItemId,
        $Manager = $gooseClipboardManager
    )
    return $Manager.PinItem($ItemId)
}

function Unpin-ClipboardItem {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ItemId,
        $Manager = $gooseClipboardManager
    )
    return $Manager.UnpinItem($ItemId)
}

function Delete-ClipboardItem {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ItemId,
        $Manager = $gooseClipboardManager
    )
    return $Manager.DeleteItem($ItemId)
}

function Search-Clipboard {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Query,
        $Manager = $gooseClipboardManager
    )
    return $Manager.SearchHistory($Query)
}

function Clear-ClipboardHistory {
    param($Manager = $gooseClipboardManager)
    return $Manager.ClearHistory()
}

function Clear-ClipboardPinned {
    param($Manager = $gooseClipboardManager)
    return $Manager.ClearPinned()
}

function Clear-ClipboardAll {
    param($Manager = $gooseClipboardManager)
    return $Manager.ClearAll()
}

function Copy-ClipboardItem {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ItemId,
        $Manager = $gooseClipboardManager
    )
    return $Manager.CopyToClipboard($ItemId)
}

function Quick-Paste {
    param(
        [Parameter(Mandatory=$true)]
        [int]$Number,
        $Manager = $gooseClipboardManager
    )
    return $Manager.QuickPaste($Number)
}

function Get-ClipboardStats {
    param($Manager = $gooseClipboardManager)
    return $Manager.GetStats()
}

function Get-ClipboardManagerState {
    param($Manager = $gooseClipboardManager)
    return $Manager.GetClipboardManagerState()
}

function Enable-ClipboardManager {
    param($Manager = $gooseClipboardManager)
    $Manager.SetEnabled($true)
}

function Disable-ClipboardManager {
    param($Manager = $gooseClipboardManager)
    $Manager.SetEnabled($false)
}

function Toggle-ClipboardManager {
    param($Manager = $gooseClipboardManager)
    $Manager.Toggle()
}

Write-Host "Desktop Goose Enhanced Clipboard Manager Initialized"
$state = Get-ClipboardManagerState
Write-Host "Clipboard Manager Enabled: $($state['Enabled'])"
Write-Host "History Items: $($state['Stats']['totalHistory'])"
Write-Host "Pinned Items: $($state['Stats']['totalPinned'])"
