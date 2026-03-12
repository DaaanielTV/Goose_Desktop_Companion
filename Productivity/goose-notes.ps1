# Desktop Goose Notes/Sticky Notes System
# Goose brings sticky notes to user

$LoggingScriptPath = Join-Path $PSScriptRoot "..\Core\GooseLogging.ps1"
if (Test-Path $LoggingScriptPath) {
    . $LoggingScriptPath
}

class GooseNotes {
    [hashtable]$Config
    [System.Collections.ArrayList]$Notes
    [string]$NotesStoragePath
    [int]$MaxNotes
    [datetime]$LastNoteCreated
    
    GooseNotes() {
        $this.Config = $this.LoadConfig()
        $this.Notes = New-Object System.Collections.ArrayList
        $this.NotesStoragePath = "goose_notes.json"
        $this.MaxNotes = 10
        $this.LastNoteCreated = Get-Date
        $this.LoadNotes()
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
        
        if (-not $this.Config.ContainsKey("NotesEnabled")) {
            $this.Config["NotesEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] LoadNotes() {
        if (Test-Path $this.NotesStoragePath) {
            try {
                $json = Get-Content $this.NotesStoragePath -Raw | ConvertFrom-Json
                foreach ($note in $json) {
                    $this.Notes.Add($note)
                }
            } catch {
                Write-Host "Failed to load notes: $_"
            }
        }
    }
    
    [void] SaveNotes() {
        try {
            $this.Notes | ConvertTo-Json | Set-Content $this.NotesStoragePath
        } catch {
            Write-Host "Failed to save notes: $_"
        }
    }
    
    [hashtable] CreateNote([string]$content, [string]$color = "yellow") {
        if ($this.Notes.Count -ge $this.MaxNotes) {
            return @{
                "Success" = $false
                "Message" = "Maximum notes reached. Delete some notes first."
            }
        }
        
        $note = @{
            "Id" = [guid]::NewGuid().ToString()
            "Content" = $content
            "Color" = $color
            "CreatedAt" = (Get-Date).ToString("o")
            "IsPinned" = $false
            "Position" = @{ "X" = -1; "Y" = -1 }
            "IsVisible" = $true
        }
        
        $this.Notes.Add($note)
        $this.SaveNotes()
        $this.LastNoteCreated = Get-Date
        
        return @{
            "Success" = $true
            "Note" = $note
            "Message" = "Note created!"
        }
    }
    
    [hashtable] DeleteNote([string]$noteId) {
        $noteToRemove = $null
        foreach ($note in $this.Notes) {
            if ($note.Id -eq $noteId) {
                $noteToRemove = $note
                break
            }
        }
        
        if ($noteToRemove) {
            $this.Notes.Remove($noteToRemove)
            $this.SaveNotes()
            return @{
                "Success" = $true
                "Message" = "Note deleted!"
            }
        }
        
        return @{
            "Success" = $false
            "Message" = "Note not found."
        }
    }
    
    [hashtable] UpdateNote([string]$noteId, [string]$newContent) {
        foreach ($note in $this.Notes) {
            if ($note.Id -eq $noteId) {
                $note.Content = $newContent
                $note.UpdatedAt = (Get-Date).ToString("o")
                $this.SaveNotes()
                return @{
                    "Success" = $true
                    "Note" = $note
                    "Message" = "Note updated!"
                }
            }
        }
        
        return @{
            "Success" = $false
            "Message" = "Note not found."
        }
    }
    
    [hashtable] TogglePin([string]$noteId) {
        foreach ($note in $this.Notes) {
            if ($note.Id -eq $noteId) {
                $note.IsPinned = -not $note.IsPinned
                $this.SaveNotes()
                return @{
                    "Success" = $true
                    "IsPinned" = $note.IsPinned
                }
            }
        }
        
        return @{
            "Success" = $false
            "Message" = "Note not found."
        }
    }
    
    [void] SetNotePosition([string]$noteId, [int]$x, [int]$y) {
        foreach ($note in $this.Notes) {
            if ($note.Id -eq $noteId) {
                $note.Position.X = $x
                $note.Position.Y = $y
                $this.SaveNotes()
                break
            }
        }
    }
    
    [object[]] GetNotes() {
        $visibleNotes = @()
        foreach ($note in $this.Notes) {
            if ($note.IsVisible) {
                $visibleNotes += $note
            }
        }
        return $visibleNotes
    }
    
    [hashtable] GetNoteState() {
        return @{
            "Enabled" = $this.Config["NotesEnabled"]
            "Notes" = $this.GetNotes()
            "TotalNotes" = $this.Notes.Count
            "MaxNotes" = $this.MaxNotes
            "LastCreated" = $this.LastNoteCreated
        }
    }
    
    [hashtable] CreateReminder([string]$content, [int]$minutesFromNow) {
        $reminderTime = (Get-Date).AddMinutes($minutesFromNow)
        
        $reminder = @{
            "Id" = [guid]::NewGuid().ToString()
            "Content" = $content
            "Color" = "orange"
            "CreatedAt" = (Get-Date).ToString("o")
            "ReminderTime" = $reminderTime.ToString("o")
            "IsPinned" = $false
            "IsVisible" = $true
            "IsReminder" = $true
            "Triggered" = $false
        }
        
        $this.Notes.Add($reminder)
        $this.SaveNotes()
        
        return @{
            "Success" = $true
            "Reminder" = $reminder
            "Message" = "Reminder set for $minutesFromNow minutes from now."
        }
    }
    
    [System.Collections.ArrayList] GetDueReminders() {
        $due = New-Object System.Collections.ArrayList
        $now = Get-Date
        
        foreach ($note in $this.Notes) {
            if ($note.IsReminder -and -not $note.Triggered) {
                $reminderTime = [DateTime]::Parse($note.ReminderTime)
                if ($reminderTime -le $now) {
                    $due.Add($note)
                }
            }
        }
        
        return $due
    }
    
    [void] MarkReminderTriggered([string]$noteId) {
        foreach ($note in $this.Notes) {
            if ($note.Id -eq $noteId) {
                $note.Triggered = $true
                $this.SaveNotes()
                break
            }
        }
    }
    
    [void] SetEnabled([bool]$enabled) {
        $this.Config["NotesEnabled"] = $enabled
    }
    
    [void] ClearAllNotes() {
        $this.Notes.Clear()
        $this.SaveNotes()
    }
    
    [void] SyncFromCloud([object]$cloudData) {
        if ($cloudData -and $cloudData -is [array]) {
            $this.Notes.Clear()
            foreach ($note in $cloudData) {
                $this.Notes.Add($note)
            }
            $this.SaveNotes()
        }
    }
    
    [object] GetNotesForSync() {
        return $this.Notes
    }
}

$gooseNotes = [GooseNotes]::new()

function Get-GooseNotes {
    return $gooseNotes
}

function New-GooseNote {
    param(
        [string]$Content,
        [string]$Color = "yellow",
        $Notes = $gooseNotes
    )
    return $Notes.CreateNote($Content, $Color)
}

function Remove-GooseNote {
    param(
        [string]$NoteId,
        $Notes = $gooseNotes
    )
    return $Notes.DeleteNote($NoteId)
}

function Get-GooseNotesList {
    param($Notes = $gooseNotes)
    return $Notes.GetNotes()
}

function Set-GooseNoteReminder {
    param(
        [string]$Content,
        [int]$MinutesFromNow,
        $Notes = $gooseNotes
    )
    return $Notes.CreateReminder($Content, $MinutesFromNow)
}

function Sync-GooseNotes {
    param(
        [object]$SyncClient,
        $Notes = $gooseNotes
    )
    
    $pullResult = $SyncClient.PullData("notes")
    
    if ($pullResult.Success -and $pullResult.Source -eq "remote") {
        $Notes.SyncFromCloud($pullResult.Data)
        return @{
            "Success" = $true
            "Synced" = $true
            "Source" = "cloud"
            "NotesCount" = $Notes.Notes.Count
        }
    }
    
    $syncResult = $SyncClient.QueueChange("notes", "Update", $Notes.GetNotesForSync())
    
    return @{
        "Success" = $true
        "Synced" = $false
        "Queued" = $true
        "NotesCount" = $Notes.Notes.Count
    }
}

Write-Host "Desktop Goose Notes System Initialized"
Write-LogInfo -Message "Notes System Initialized" -Source "GooseNotes"
$state = $gooseNotes.GetNoteState()
Write-Host "Notes Enabled: $($state['Enabled'])"
Write-Host "Total Notes: $($state['TotalNotes'])"
Write-LogInfo -Message "Notes Enabled: $($state['Enabled']), Total: $($state['TotalNotes'])" -Source "GooseNotes"
