# Desktop Goose Companion Journal System
# Logs daily interactions with the goose

class GooseCompanionJournal {
    [hashtable]$Config
    [string]$JournalFile
    [array]$Entries
    [int]$MaxEntries
    
    GooseCompanionJournal() {
        $this.Config = $this.LoadConfig()
        $this.JournalFile = "goose_journal.json"
        $this.MaxEntries = 1000
        $this.Entries = @()
        $this.LoadJournal()
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
        
        if (-not $this.Config.ContainsKey("CompanionJournalEnabled")) {
            $this.Config["CompanionJournalEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] LoadJournal() {
        if (Test-Path $this.JournalFile) {
            try {
                $this.Entries = Get-Content $this.JournalFile | ConvertFrom-Json
                if ($this.Entries -isnot [array]) {
                    $this.Entries = @()
                }
            } catch {
                $this.Entries = @()
            }
        }
    }
    
    [void] SaveJournal() {
        $this.Entries | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.JournalFile -Encoding UTF8
    }
    
    [hashtable] AddEntry([string]$category, [string]$description, [hashtable]$metadata = @{}) {
        $entry = @{
            "Id" = [guid]::NewGuid().ToString()
            "Timestamp" = (Get-Date).ToString("o")
            "Date" = (Get-Date).ToString("yyyy-MM-dd")
            "Time" = (Get-Date).ToString("HH:mm:ss")
            "Category" = $category
            "Description" = $description
            "Metadata" = $metadata
        }
        
        $this.Entries += $entry
        
        if ($this.Entries.Count -gt $this.MaxEntries) {
            $this.Entries = $this.Entries[-$this.MaxEntries..-1]
        }
        
        $this.SaveJournal()
        
        return @{
            "Success" = $true
            "Entry" = $entry
            "Message" = "Journal entry added"
        }
    }
    
    [array] GetEntries([int]$count = 10, [string]$date = "") {
        $filtered = $this.Entries
        
        if ($date -ne "") {
            $filtered = $filtered | Where-Object { $_.Date -eq $date }
        }
        
        if ($count -gt 0 -and $count -lt $filtered.Count) {
            return $filtered[-$count..-1]
        }
        
        return $filtered
    }
    
    [array] GetEntriesByCategory([string]$category) {
        return $this.Entries | Where-Object { $_.Category -eq $category }
    }
    
    [hashtable] GetTodayStats() {
        $today = (Get-Date).ToString("yyyy-MM-dd")
        $todayEntries = $this.Entries | Where-Object { $_.Date -eq $today }
        
        $categories = $todayEntries | Group-Object -Property Category
        
        return @{
            "Date" = $today
            "TotalEntries" = $todayEntries.Count
            "Categories" = $categories | ForEach-Object {
                @{
                    "Category" = $_.Name
                    "Count" = $_.Count
                }
            }
        }
    }
    
    [hashtable] GetWeeklyStats() {
        $weekStart = (Get-Date).AddDays(-7).ToString("yyyy-MM-dd")
        $weekEntries = $this.Entries | Where-Object { $_.Date -ge $weekStart }
        
        $dailyCounts = @{}
        for ($i = 0; $i -lt 7; $i++) {
            $day = (Get-Date).AddDays(-$i).ToString("yyyy-MM-dd")
            $dailyCounts[$day] = ($weekEntries | Where-Object { $_.Date -eq $day }).Count
        }
        
        return @{
            "WeekStart" = $weekStart
            "WeekEnd" = (Get-Date).ToString("yyyy-MM-dd")
            "TotalEntries" = $weekEntries.Count
            "DailyCounts" = $dailyCounts
        }
    }
    
    [hashtable] GetAllTimeStats() {
        $categories = $this.Entries | Group-Object -Property Category
        
        return @{
            "TotalEntries" = $this.Entries.Count
            "DateRange" = @{
                "First" = if ($this.Entries.Count -gt 0) { $this.Entries[0].Date } else { "" }
                "Last" = if ($this.Entries.Count -gt 0) { $this.Entries[-1].Date } else { "" }
            }
            "Categories" = $categories | ForEach-Object {
                @{
                    "Category" = $_.Name
                    "Count" = $_.Count
                }
            }
        }
    }
    
    [void] ClearJournal() {
        $this.Entries = @()
        if (Test-Path $this.JournalFile) {
            Remove-Item $this.JournalFile
        }
    }
    
    [hashtable] GetJournalState() {
        return @{
            "Enabled" = $this.Config["CompanionJournalEnabled"]
            "TotalEntries" = $this.Entries.Count
            "TodayStats" = $this.GetTodayStats()
            "AllTimeStats" = $this.GetAllTimeStats()
        }
    }
}

$gooseCompanionJournal = [GooseCompanionJournal]::new()

function Get-GooseCompanionJournal {
    return $gooseCompanionJournal
}

function Add-JournalEntry {
    param(
        [string]$Category,
        [string]$Description,
        [hashtable]$Metadata = @{},
        $Journal = $gooseCompanionJournal
    )
    return $Journal.AddEntry($Category, $Description, $Metadata)
}

function Get-JournalEntries {
    param(
        [int]$Count = 10,
        [string]$Date = "",
        $Journal = $gooseCompanionJournal
    )
    return $Journal.GetEntries($Count, $Date)
}

function Get-JournalStats {
    param($Journal = $gooseCompanionJournal)
    return $Journal.GetAllTimeStats()
}

function Get-JournalState {
    param($Journal = $gooseCompanionJournal)
    return $Journal.GetJournalState()
}

Write-Host "Desktop Goose Companion Journal System Initialized"
$state = Get-JournalState
Write-Host "Journal Enabled: $($state['Enabled'])"
Write-Host "Total Entries: $($state['TotalEntries'])"
