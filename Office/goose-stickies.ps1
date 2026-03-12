# Desktop Goose Sticky Note System
# Hold sticky notes on desktop

class GooseStickyNote {
    [hashtable]$Config
    [array]$Notes
    [string]$NotesFile
    
    GooseStickyNote() {
        $this.Config = $this.LoadConfig()
        $this.NotesFile = "goose_stickies.json"
        $this.Notes = @()
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
                    } else {
                        $this.Config[$key] = $value
                    }
                }
            }
        }
        
        return $this.Config
    }
    
    [void] LoadNotes() {
        if (Test-Path $this.NotesFile) {
            try {
                $this.Notes = Get-Content $this.NotesFile | ConvertFrom-Json
                if ($this.Notes -isnot [array]) {
                    $this.Notes = @()
                }
            } catch {
                $this.Notes = @()
            }
        }
    }
    
    [void] SaveNotes() {
        $this.Notes | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.NotesFile -Encoding UTF8
    }
    
    [hashtable] AddNote([string]$content, [string]$color = "yellow") {
        $note = @{
            "Id" = [guid]::NewGuid().ToString()
            "Content" = $content
            "Color" = $color
            "Created" = (Get-Date).ToString("o")
            "Modified" = (Get-Date).ToString("o")
        }
        
        $this.Notes += $note
        $this.SaveNotes()
        
        return @{
            "Success" = $true
            "Note" = $note
            "Message" = "Sticky note added"
        }
    }
    
    [hashtable] UpdateNote([string]$id, [string]$content) {
        $note = $this.Notes | Where-Object { $_.Id -eq $id } | Select-Object -First 1
        
        if (-not $note) {
            return @{
                "Success" = $false
                "Message" = "Note not found"
            }
        }
        
        $note.Content = $content
        $note.Modified = (Get-Date).ToString("o")
        $this.SaveNotes()
        
        return @{
            "Success" = $true
            "Note" = $note
            "Message" = "Note updated"
        }
    }
    
    [hashtable] DeleteNote([string]$id) {
        $initialCount = $this.Notes.Count
        $this.Notes = $this.Notes | Where-Object { $_.Id -ne $id }
        
        if ($this.Notes.Count -lt $initialCount) {
            $this.SaveNotes()
            return @{
                "Success" = $true
                "Message" = "Note deleted"
            }
        }
        
        return @{
            "Success" = $false
            "Message" = "Note not found"
        }
    }
    
    [array] GetAllNotes() {
        return $this.Notes
    }
    
    [hashtable] GetStickyNoteState() {
        return @{
            "Notes" = $this.Notes
            "NoteCount" = $this.Notes.Count
            "Colors" = @("yellow", "pink", "blue", "green", "purple")
        }
    }
}

$gooseStickyNote = [GooseStickyNote]::new()

function Get-GooseStickyNote {
    return $gooseStickyNote
}

function Add-StickyNote {
    param(
        [string]$Content,
        [string]$Color = "yellow",
        $StickyNote = $gooseStickyNote
    )
    return $StickyNote.AddNote($Content, $Color)
}

function Get-AllStickyNotes {
    param($StickyNote = $gooseStickyNote)
    return $StickyNote.GetAllNotes()
}

function Get-StickyNoteState {
    param($StickyNote = $gooseStickyNote)
    return $StickyNote.GetStickyNoteState()
}

Write-Host "Desktop Goose Sticky Note System Initialized"
$state = Get-StickyNoteState
Write-Host "Sticky Notes: $($state['NoteCount'])"
