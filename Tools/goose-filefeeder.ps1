# Desktop Goose File Feeding System
# Goose accepts files dragged to it and displays info

class GooseFileFeeder {
    [hashtable]$Config
    [string]$FeedHistoryFile
    [array]$RecentFeedings
    [int]$MaxHistory
    
    GooseFileFeeder() {
        $this.Config = $this.LoadConfig()
        $this.FeedHistoryFile = "goose_feed_history.json"
        $this.RecentFeedings = @()
        $this.MaxHistory = 50
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
        
        if (-not $this.Config.ContainsKey("FileFeedingEnabled")) {
            $this.Config["FileFeedingEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [hashtable] FeedFile([string]$filePath) {
        if (-not (Test-Path $filePath)) {
            return @{
                "Success" = $false
                "Message" = "File not found"
            }
        }
        
        $file = Get-Item $filePath
        $extension = $file.Extension.ToLower()
        
        $feedingInfo = @{
            "Timestamp" = (Get-Date).ToString("o")
            "FileName" = $file.Name
            "FilePath" = $file.FullName
            "FileSize" = $file.Length
            "FileSizeFormatted" = $this.FormatFileSize($file.Length)
            "Extension" = $extension
            "Created" = $file.CreationTime.ToString("yyyy-MM-dd HH:mm")
            "Modified" = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
            "IsDirectory" = $file.PSIsContainer
        }
        
        $response = $this.GetGooseReaction($extension, $file.Length)
        $feedingInfo["GooseReaction"] = $response["Reaction"]
        $feedingInfo["GooseMessage"] = $response["Message"]
        
        $this.RecentFeedings += $feedingInfo
        if ($this.RecentFeedings.Count -gt $this.MaxHistory) {
            $this.RecentFeedings = $this.RecentFeedings[-$this.MaxHistory..-1]
        }
        
        $this.SaveHistory()
        
        return @{
            "Success" = $true
            "FeedingInfo" = $feedingInfo
            "Message" = $feedingInfo["GooseMessage"]
        }
    }
    
    [hashtable] GetGooseReaction([string]$extension, [long]$fileSize) {
        $reactions = @{
            ".txt" = @{ Reaction = "curious"; Message = "Interesting reading material!" }
            ".doc" = @{ Reaction = "curious"; Message = "A document! Very professional." }
            ".docx" = @{ Reaction = "curious"; Message = "A document! Very professional." }
            ".pdf" = @{ Reaction = "impressed"; Message = "So much information!" }
            ".jpg" = @{ Reaction = "happy"; Message = "Ooh, a picture!" }
            ".jpeg" = @{ Reaction = "happy"; Message = "Ooh, a picture!" }
            ".png" = @{ Reaction = "happy"; Message = "Ooh, a picture!" }
            ".gif" = @{ Reaction = "excited"; Message = "Moving pictures!" }
            ".mp3" = @{ Reaction = "excited"; Message = "Music for my ears!" }
            ".wav" = @{ Reaction = "excited"; Message = "Music for my ears!" }
            ".mp4" = @{ Reaction = "curious"; Message = "A video! Let's watch together." }
            ".avi" = @{ Reaction = "curious"; Message = "A video! Let's watch together." }
            ".mkv" = @{ Reaction = "curious"; Message = "A video! Let's watch together." }
            ".zip" = @{ Reaction = "confused"; Message = "Compressed mystery!" }
            ".rar" = @{ Reaction = "confused"; Message = "Compressed mystery!" }
            ".exe" = @{ Reaction = "suspicious"; Message = "Run this? Be careful!" }
            ".dll" = @{ Reaction = "suspicious"; Message = "Mysterious system stuff." }
            ".ps1" = @{ Reaction = "excited"; Message = "PowerShell magic!" }
            ".py" = @{ Reaction = "excited"; Message = "Python code! So smart!" }
            ".js" = @{ Reaction = "excited"; Message = "JavaScript! Web magic!" }
            ".html" = @{ Reaction = "curious"; Message = "Web page building!" }
            ".css" = @{ Reaction = "curious"; Message = "Style and beauty!" }
            ".json" = @{ Reaction = "curious"; Message = "Data organized neatly!" }
            ".xml" = @{ Reaction = "curious"; Message = "Structured data!" }
            ".csv" = @{ Reaction = "impressed"; Message = "Spreadsheets! Numbers!" }
            ".xlsx" = @{ Reaction = "impressed"; Message = "Excel master!" }
            ".pptx" = @{ Reaction = "impressed"; Message = "Presentation time!" }
        }
        
        $defaultReaction = @{ Reaction = "neutral"; Message = "Thank you for the file!" }
        
        if ($reactions.ContainsKey($extension)) {
            return $reactions[$extension]
        }
        
        if ($extension -eq "") {
            return @{ Reaction = "confused"; Message = "A folder? So mysterious!" }
        }
        
        return $defaultReaction
    }
    
    [string] FormatFileSize([long]$bytes) {
        if ($bytes -lt 1KB) { return "$bytes B" }
        elseif ($bytes -lt 1MB) { return "{0:N1} KB" -f ($bytes / 1KB) }
        elseif ($bytes -lt 1GB) { return "{0:N1} MB" -f ($bytes / 1MB) }
        else { return "{0:N2} GB" -f ($bytes / 1GB) }
    }
    
    [void] SaveHistory() {
        $this.RecentFeedings | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.FeedHistoryFile -Encoding UTF8
    }
    
    [array] GetFeedHistory([int]$count = 10) {
        if ($this.RecentFeedings.Count -eq 0 -and (Test-Path $this.FeedHistoryFile)) {
            $this.RecentFeedings = Get-Content $this.FeedHistoryFile | ConvertFrom-Json
        }
        
        if ($count -gt 0 -and $count -lt $this.RecentFeedings.Count) {
            return $this.RecentFeedings[-$count..-1]
        }
        
        return $this.RecentFeedings
    }
    
    [hashtable] GetStatistics() {
        $totalFeedings = $this.RecentFeedings.Count
        $totalSize = ($this.RecentFeedings | ForEach-Object { $_.FileSize } | Measure-Object -Sum).Sum
        
        $extensions = $this.RecentFeedings | Group-Object -Property Extension | Sort-Object Count -Descending
        
        return @{
            "TotalFeedings" = $totalFeedings
            "TotalSizeBytes" = $totalSize
            "TotalSizeFormatted" = $this.FormatFileSize($totalSize)
            "TopExtensions" = $extensions | Select-Object -First 5
            "LastFeeding" = if ($totalFeedings -gt 0) { $this.RecentFeedings[-1] } else { $null }
        }
    }
    
    [hashtable] GetFileFeederState() {
        return @{
            "Enabled" = $this.Config["FileFeedingEnabled"]
            "RecentFeedings" = $this.GetFeedHistory(5)
            "Statistics" = $this.GetStatistics()
        }
    }
    
    [void] ClearHistory() {
        $this.RecentFeedings = @()
        if (Test-Path $this.FeedHistoryFile) {
            Remove-Item $this.FeedHistoryFile
        }
    }
}

$gooseFileFeeder = [GooseFileFeeder]::new()

function Get-GooseFileFeeder {
    return $gooseFileFeeder
}

function Feed-FileToGoose {
    param(
        [string]$FilePath,
        $FileFeeder = $gooseFileFeeder
    )
    return $FileFeeder.FeedFile($FilePath)
}

function Get-FeedHistory {
    param(
        [int]$Count = 10,
        $FileFeeder = $gooseFileFeeder
    )
    return $FileFeeder.GetFeedHistory($Count)
}

function Get-FileFeederStats {
    param($FileFeeder = $gooseFileFeeder)
    return $FileFeeder.GetStatistics()
}

Write-Host "Desktop Goose File Feeding System Initialized"
$state = $gooseFileFeeder.GetFileFeederState()
Write-Host "File Feeding Enabled: $($state['Enabled'])"
Write-Host "Total Feedings: $($state['Statistics']['TotalFeedings'])"
