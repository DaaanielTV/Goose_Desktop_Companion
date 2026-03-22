# Desktop Goose File Organizer System
# Auto-categorize and organize files

class GooseFileOrganizer {
    [hashtable]$Config
    [hashtable]$Rules
    [hashtable]$OrganizationHistory
    [bool]$IsEnabled
    [datetime]$LastRun
    [string]$Schedule
    
    GooseFileOrganizer() {
        $this.Config = $this.LoadConfig()
        $this.Rules = @{}
        $this.OrganizationHistory = @{}
        $this.LastRun = Get-Date
        $this.Schedule = "daily"
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
        
        if (-not $this.Config.ContainsKey("FileOrganizerEnabled")) {
            $this.Config["FileOrganizerEnabled"] = $false
        }
        if (-not $this.Config.ContainsKey("FileOrganizerWatchFolders")) {
            $this.Config["FileOrganizerWatchFolders"] = "$env:USERPROFILE\Downloads"
        }
        if (-not $this.Config.ContainsKey("FileOrganizerAutoOrganize")) {
            $this.Config["FileOrganizerAutoOrganize"] = $false
        }
        if (-not $this.Config.ContainsKey("FileOrganizerSchedule")) {
            $this.Config["FileOrganizerSchedule"] = "daily"
        }
        
        return $this.Config
    }
    
    [void] LoadData() {
        $dataFile = "goose_fileorganizer.json"
        
        if (Test-Path $dataFile) {
            try {
                $data = Get-Content $dataFile -Raw | ConvertFrom-Json
                
                if ($data.rules) {
                    $this.Rules = @{}
                    $data.rules.PSObject.Properties | ForEach-Object {
                        $this.Rules[$_.Name] = $_.Value
                    }
                }
                
                if ($data.organizationHistory) {
                    $this.OrganizationHistory = @{}
                    $data.organizationHistory.PSObject.Properties | ForEach-Object {
                        $this.OrganizationHistory[$_.Name] = $_.Value
                    }
                }
                
                if ($data.lastRun) {
                    $this.LastRun = [datetime]::Parse($data.lastRun)
                }
                
                if ($data.schedule) {
                    $this.Schedule = $data.schedule
                }
            } catch {}
        }
        
        $this.IsEnabled = $this.Config["FileOrganizerEnabled"]
        $this.LoadDefaultRules()
    }
    
    [void] LoadDefaultRules() {
        if ($this.Rules.Count -eq 0) {
            $this.Rules = @{
                "Images" = @{
                    "name" = "Images"
                    "extensions" = @(".jpg", ".jpeg", ".png", ".gif", ".bmp", ".webp", ".svg", ".ico", ".tiff")
                    "destination" = "Pictures"
                    "enabled" = $true
                }
                "Videos" = @{
                    "name" = "Videos"
                    "extensions" = @(".mp4", ".mkv", ".avi", ".mov", ".wmv", ".flv", ".webm")
                    "destination" = "Videos"
                    "enabled" = $true
                }
                "Audio" = @{
                    "name" = "Audio"
                    "extensions" = @(".mp3", ".wav", ".flac", ".aac", ".ogg", ".wma", ".m4a")
                    "destination" = "Music"
                    "enabled" = $true
                }
                "Documents" = @{
                    "name" = "Documents"
                    "extensions" = @(".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx", ".txt", ".rtf", ".odt")
                    "destination" = "Documents"
                    "enabled" = $true
                }
                "Archives" = @{
                    "name" = "Archives"
                    "extensions" = @(".zip", ".rar", ".7z", ".tar", ".gz", ".bz2")
                    "destination" = "Documents\Archives"
                    "enabled" = $true
                }
                "Executables" = @{
                    "name" = "Executables"
                    "extensions" = @(".exe", ".msi", ".bat", ".cmd", ".ps1", ".sh")
                    "destination" = "Documents\Installers"
                    "enabled" = $false
                }
            }
        }
    }
    
    [void] SaveData() {
        $data = @{
            "rules" = $this.Rules
            "organizationHistory" = $this.OrganizationHistory
            "lastRun" = $this.LastRun.ToString("o")
            "schedule" = $this.Schedule
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content "goose_fileorganizer.json"
    }
    
    [hashtable] AddRule([string]$name, [string[]]$extensions, [string]$destination, [bool]$enabled = $true) {
        $rule = @{
            "name" = $name
            "extensions" = $extensions
            "destination" = $destination
            "enabled" = $enabled
            "createdAt" = (Get-Date).ToString("o")
        }
        
        $this.Rules[$name] = $rule
        $this.SaveData()
        
        return $rule
    }
    
    [bool] UpdateRule([string]$name, [string[]]$extensions = $null, [string]$destination = $null, [bool]$enabled = $null) {
        if (-not $this.Rules.ContainsKey($name)) {
            return $false
        }
        
        $rule = $this.Rules[$name]
        
        if ($extensions) { $rule.extensions = $extensions }
        if ($destination) { $rule.destination = $destination }
        if ($null -ne $enabled) { $rule.enabled = $enabled }
        
        $this.Rules[$name] = $rule
        $this.SaveData()
        
        return $true
    }
    
    [bool] DeleteRule([string]$name) {
        if ($this.Rules.ContainsKey($name)) {
            $this.Rules.Remove($name)
            $this.SaveData()
            return $true
        }
        return $false
    }
    
    [bool] ToggleRule([string]$name) {
        if (-not $this.Rules.ContainsKey($name)) {
            return $false
        }
        
        $this.Rules[$name].enabled = -not $this.Rules[$name].enabled
        $this.SaveData()
        
        return $this.Rules[$name].enabled
    }
    
    [string] GetDestinationPath([string]$ruleName) {
        if (-not $this.Rules.ContainsKey($ruleName)) {
            return $null
        }
        
        $rule = $this.Rules[$ruleName]
        
        if ($rule.destination -match '\.\.[/\\]') {
            return $null
        }
        
        $allowedDestinations = @("MyPictures", "MyDocuments", "MyMusic", "MyVideos", "Desktop", "Documents", "Pictures", "Music", "Videos")
        
        $destFolder = $rule.destination
        foreach ($allowed in $allowedDestinations) {
            $resolvedPath = [Environment]::GetFolderPath($allowed)
            if ($rule.destination -eq $allowed -or $rule.destination.StartsWith("$allowed\")) {
                $destFolder = $allowed
                break
            }
        }
        
        $basePath = [Environment]::GetFolderPath($destFolder)
        
        if ($basePath -and $rule.destination -ne $destFolder) {
            $basePath = Join-Path $basePath ($rule.destination -replace "^$destFolder[/\\]", "")
        }
        
        if (-not $basePath -or -not (Test-Path $basePath)) {
            try {
                New-Item -ItemType Directory -Path $basePath -Force | Out-Null
            } catch {
                return $null
            }
        }
        
        return $basePath
    }
    
    [string] GetMatchingRule([string]$filePath) {
        $extension = [System.IO.Path]::GetExtension($filePath).ToLower()
        
        foreach ($rule in $this.Rules.Values) {
            if (-not $rule.enabled) { continue }
            
            if ($rule.extensions -contains $extension) {
                return $rule.name
            }
        }
        
        return $null
    }
    
    [hashtable] OrganizeFile([string]$filePath, [bool]$move = $true) {
        $result = @{
            "success" = $false
            "file" = $filePath
            "rule" = $null
            "destination" = $null
            "message" = ""
        }
        
        if (-not (Test-Path $filePath)) {
            $result.message = "File not found"
            return $result
        }
        
        $ruleName = $this.GetMatchingRule($filePath)
        
        if (-not $ruleName) {
            $result.message = "No matching rule found"
            return $result
        }
        
        $destination = $this.GetDestinationPath($ruleName)
        
        if (-not $destination) {
            $result.message = "Could not resolve destination"
            return $result
        }
        
        $fileName = [System.IO.Path]::GetFileName($filePath)
        $destPath = Join-Path $destination $fileName
        
        if (Test-Path $destPath) {
            $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
            $ext = [System.IO.Path]::GetExtension($fileName)
            $counter = 1
            
            while (Test-Path $destPath) {
                $destPath = Join-Path $destination ("{0}_{1}{2}" -f $baseName, $counter, $ext)
                $counter++
            }
        }
        
        try {
            if ($move) {
                Move-Item -Path $filePath -Destination $destPath -Force
            } else {
                Copy-Item -Path $filePath -Destination $destPath -Force
            }
            
            $result.success = $true
            $result.rule = $ruleName
            $result.destination = $destPath
            $result.message = "File organized successfully"
            
            $this.RecordOrganization($filePath, $destPath, $ruleName)
            
        } catch {
            $result.message = "Error: $($_.Exception.Message)"
        }
        
        return $result
    }
    
    [hashtable] OrganizeFolder([string]$folderPath, [bool]$recursive = $false, [bool]$move = $true) {
        $results = @{
            "processed" = 0
            "organized" = 0
            "failed" = 0
            "details" = @()
        }
        
        if (-not (Test-Path $folderPath)) {
            $results.message = "Folder not found"
            return $results
        }
        
        $files = if ($recursive) {
            Get-ChildItem -Path $folderPath -File -Recurse
        } else {
            Get-ChildItem -Path $folderPath -File
        }
        
        foreach ($file in $files) {
            $results.processed++
            
            $orgResult = $this.OrganizeFile($file.FullName, $move)
            
            if ($orgResult.success) {
                $results.organized++
            } else {
                $results.failed++
            }
            
            $results.details += $orgResult
        }
        
        $this.LastRun = Get-Date
        $this.SaveData()
        
        return $results
    }
    
    [void] RecordOrganization([string]$source, [string]$destination, [string]$rule) {
        $timestamp = (Get-Date).ToString("yyyy-MM-dd")
        
        if (-not $this.OrganizationHistory.ContainsKey($timestamp)) {
            $this.OrganizationHistory[$timestamp] = @{
                "date" = $timestamp
                "files" = @()
                "totalFiles" = 0
            }
        }
        
        $this.OrganizationHistory[$timestamp].files += @{
            "source" = $source
            "destination" = $destination
            "rule" = $rule
            "time" = (Get-Date).ToString("o")
        }
        
        $this.OrganizationHistory[$timestamp].totalFiles++
    }
    
    [hashtable] GetHistory([int]$days = 7) {
        $history = @()
        $startDate = (Get-Date).AddDays(-$days)
        
        foreach ($entry in $this.OrganizationHistory.Values) {
            $entryDate = [datetime]::Parse($entry.date)
            if ($entryDate -ge $startDate) {
                $history += $entry
            }
        }
        
        return $history | Sort-Object { $_.date } -Descending
    }
    
    [hashtable] GetStats() {
        $totalFiles = 0
        $byRule = @{}
        
        foreach ($entry in $this.OrganizationHistory.Values) {
            $totalFiles += $entry.totalFiles
            
            foreach ($file in $entry.files) {
                $rule = $file.rule
                if (-not $byRule.ContainsKey($rule)) {
                    $byRule[$rule] = 0
                }
                $byRule[$rule]++
            }
        }
        
        return @{
            "totalFilesOrganized" = $totalFiles
            "byRule" = $byRule
            "lastRun" = $this.LastRun
            "rulesEnabled" = ($this.Rules.Values | Where-Object { $_.enabled }).Count
            "rulesTotal" = $this.Rules.Count
        }
    }
    
    [hashtable] PreviewOrganization([string]$folderPath, [bool]$recursive = $false) {
        $preview = @{
            "totalFiles" = 0
            "byRule" = @{}
            "unmatched" = @()
            "details" = @()
        }
        
        if (-not (Test-Path $folderPath)) {
            return $preview
        }
        
        $files = if ($recursive) {
            Get-ChildItem -Path $folderPath -File -Recurse
        } else {
            Get-ChildItem -Path $folderPath -File
        }
        
        foreach ($file in $files) {
            $preview.totalFiles++
            
            $ruleName = $this.GetMatchingRule($file.FullName)
            
            if ($ruleName) {
                if (-not $preview.byRule.ContainsKey($ruleName)) {
                    $preview.byRule[$ruleName] = 0
                }
                $preview.byRule[$ruleName]++
                
                $preview.details += @{
                    "file" = $file.Name
                    "rule" = $ruleName
                    "destination" = $this.GetDestinationPath($ruleName)
                }
            } else {
                $preview.unmatched += $file.Name
            }
        }
        
        return $preview
    }
    
    [void] SetSchedule([string]$schedule) {
        $validSchedules = @("daily", "weekly", "manual")
        if ($validSchedules -contains $schedule) {
            $this.Schedule = $schedule
            $this.Config["FileOrganizerSchedule"] = $schedule
            $this.SaveData()
        }
    }
    
    [bool] ShouldRun() {
        if ($this.Schedule -eq "daily") {
            return $this.LastRun.Date -lt (Get-Date).Date
        } elseif ($this.Schedule -eq "weekly") {
            $daysSinceLastRun = ((Get-Date) - $this.LastRun).Days
            return $daysSinceLastRun -ge 7
        }
        return $false
    }
    
    [void] SetEnabled([bool]$enabled) {
        $this.IsEnabled = $enabled
        $this.Config["FileOrganizerEnabled"] = $enabled
    }
    
    [void] Toggle() {
        $this.IsEnabled = -not $this.IsEnabled
        $this.Config["FileOrganizerEnabled"] = $this.IsEnabled
    }
    
    [hashtable] GetFileOrganizerState() {
        return @{
            "Enabled" = $this.IsEnabled
            "Rules" = $this.Rules
            "Schedule" = $this.Schedule
            "LastRun" = $this.LastRun
            "ShouldRun" = $this.ShouldRun()
            "Stats" = $this.GetStats()
            "WatchFolders" = $this.Config["FileOrganizerWatchFolders"]
            "AutoOrganize" = $this.Config["FileOrganizerAutoOrganize"]
        }
    }
}

$gooseFileOrganizer = [GooseFileOrganizer]::new()

function Get-GooseFileOrganizer {
    return $gooseFileOrganizer
}

function Add-FileOrganizerRule {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string[]]$Extensions,
        [Parameter(Mandatory=$true)]
        [string]$Destination,
        [bool]$Enabled = $true,
        $Organizer = $gooseFileOrganizer
    )
    return $Organizer.AddRule($Name, $Extensions, $Destination, $Enabled)
}

function Update-FileOrganizerRule {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string[]]$Extensions,
        [string]$Destination,
        [bool]$Enabled,
        $Organizer = $gooseFileOrganizer
    )
    return $Organizer.UpdateRule($Name, $Extensions, $Destination, $Enabled)
}

function Remove-FileOrganizerRule {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        $Organizer = $gooseFileOrganizer
    )
    return $Organizer.DeleteRule($Name)
}

function Toggle-FileOrganizerRule {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        $Organizer = $gooseFileOrganizer
    )
    return $Organizer.ToggleRule($Name)
}

function Organize-File {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        [bool]$Move = $true,
        $Organizer = $gooseFileOrganizer
    )
    return $Organizer.OrganizeFile($FilePath, $Move)
}

function Organize-Folder {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FolderPath,
        [bool]$Recursive = $false,
        [bool]$Move = $true,
        $Organizer = $gooseFileOrganizer
    )
    return $Organizer.OrganizeFolder($FolderPath, $Recursive, $Move)
}

function Preview-Organization {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FolderPath,
        [bool]$Recursive = $false,
        $Organizer = $gooseFileOrganizer
    )
    return $Organizer.PreviewOrganization($FolderPath, $Recursive)
}

function Get-OrganizationHistory {
    param(
        [int]$Days = 7,
        $Organizer = $gooseFileOrganizer
    )
    return $Organizer.GetHistory($Days)
}

function Get-FileOrganizerStats {
    param($Organizer = $gooseFileOrganizer)
    return $Organizer.GetStats()
}

function Set-FileOrganizerSchedule {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Schedule,
        $Organizer = $gooseFileOrganizer
    )
    $Organizer.SetSchedule($Schedule)
}

function Get-FileOrganizerState {
    param($Organizer = $gooseFileOrganizer)
    return $Organizer.GetFileOrganizerState()
}

function Enable-FileOrganizer {
    param($Organizer = $gooseFileOrganizer)
    $Organizer.SetEnabled($true)
}

function Disable-FileOrganizer {
    param($Organizer = $gooseFileOrganizer)
    $Organizer.SetEnabled($false)
}

function Toggle-FileOrganizer {
    param($Organizer = $gooseFileOrganizer)
    $Organizer.Toggle()
}

Write-Host "Desktop Goose File Organizer System Initialized"
$state = Get-FileOrganizerState
Write-Host "File Organizer Enabled: $($state['Enabled'])"
Write-Host "Rules: $($state['Stats']['rulesEnabled'])/$($state['Stats']['rulesTotal'])"
