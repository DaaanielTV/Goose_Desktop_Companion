class GooseQuickNotes {
    [hashtable]$Config
    [string]$DataPath
    [object]$Telemetry
    [array]$Notes
    [System.Windows.Forms.Form]$OverlayForm
    [bool]$IsVisible
    
    GooseQuickNotes([string]$configFile = "config.ini", [object]$telemetry = $null) {
        $this.Telemetry = $telemetry
        $this.LoadConfig($configFile)
        $this.DataPath = Join-Path $PSScriptRoot "quicknotes_data"
        if (-not (Test-Path $this.DataPath)) {
            New-Item -ItemType Directory -Path $this.DataPath -Force | Out-Null
        }
        $this.Notes = @()
        $this.IsVisible = $false
        $this.LoadData()
    }
    
    [void] LoadConfig([string]$configFile) {
        $this.Config = @{
            Enabled = $true
            DefaultWidth = 300
            DefaultHeight = 200
            DefaultX = 100
            DefaultY = 100
            Opacity = 0.95
            AlwaysOnTop = $true
            AutoSave = $true
            ShowInTaskbar = $false
            FontSize = 12
            FontFamily = "Segoe UI"
        }
        if (Test-Path $configFile) {
            Get-Content $configFile | ForEach-Object {
                if ($_ -match '^([^=]+)=(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    if ($this.Config.ContainsKey($key)) {
                        if ($value -eq 'True' -or $value -eq 'False') {
                            $this.Config[$key] = [bool]$value
                        } elseif ($value -match '^\d+\.?\d*$') {
                            $this.Config[$key] = [double]$value
                        } else {
                            $this.Config[$key] = $value
                        }
                    }
                }
            }
        }
    }
    
    [void] LoadData() {
        $dataFile = Join-Path $this.DataPath "notes.json"
        if (Test-Path $dataFile) {
            try {
                $this.Notes = @(Get-Content $dataFile -Raw | ConvertFrom-Json)
                if ($this.Notes -isnot [array]) { $this.Notes = @() }
            } catch {
                $this.Notes = @()
            }
        }
    }
    
    [void] SaveData() {
        $dataFile = Join-Path $this.DataPath "notes.json"
        $this.Notes | ConvertTo-Json -Depth 10 | Set-Content -Path $dataFile
    }
    
    [hashtable] CreateNote([string]$title = "", [string]$content = "") {
        $this.Telemetry?.IncrementCounter("notes.created", 1)
        $note = @{
            id = [guid]::NewGuid().ToString()
            title = $title
            content = $content
            createdAt = (Get-Date).ToString("o")
            updatedAt = (Get-Date).ToString("o")
            color = "#FFFFCC"
            width = $this.Config["DefaultWidth"]
            height = $this.Config["DefaultHeight"]
            x = $this.Config["DefaultX"]
            y = $this.Config["DefaultY"]
            isPinned = $false
        }
        $this.Notes += $note
        $this.SaveData()
        return $note
    }
    
    [void] UpdateNote([string]$noteId, [hashtable]$updates) {
        $note = $this.Notes | Where-Object { $_.id -eq $noteId } | Select-Object -First 1
        if ($note) {
            foreach ($key in $updates.Keys) {
                $note[$key] = $updates[$key]
            }
            $note.updatedAt = (Get-Date).ToString("o")
            $this.SaveData()
            $this.Telemetry?.IncrementCounter("notes.edited", 1)
            $charCount = if ($updates.content) { $updates.content.Length } else { 0 }
            $this.Telemetry?.RecordHistogram("notes.characters_written", $charCount, "chars")
        }
    }
    
    [void] DeleteNote([string]$noteId) {
        $this.Notes = @($this.Notes | Where-Object { $_.id -ne $noteId })
        $this.SaveData()
        $this.Telemetry?.IncrementCounter("notes.deleted", 1)
    }
    
    [void] TogglePin([string]$noteId) {
        $note = $this.Notes | Where-Object { $_.id -eq $noteId } | Select-Object -First 1
        if ($note) {
            $note.isPinned = -not $note.isPinned
            $this.SaveData()
            $this.Telemetry?.IncrementCounter("notes.pinned", 1, @{pinned=$note.isPinned})
        }
    }
    
    [void] ShowOverlay() {
        if ($this.IsVisible) {
            $this.HideOverlay()
            return
        }
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $this.OverlayForm = New-Object System.Windows.Forms.Form
        $this.OverlayForm.Text = "Desktop Goose - Quick Notes"
        $this.OverlayForm.Size = New-Object System.Drawing.Size(800, 600)
        $this.OverlayForm.StartPosition = "CenterScreen"
        $this.OverlayForm.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
        $this.OverlayForm.FormBorderStyle = "None"
        $titleBar = New-Object System.Windows.Forms.Panel
        $titleBar.Dock = "Top"
        $titleBar.Height = 40
        $titleBar.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
        $this.OverlayForm.Controls.Add($titleBar)
        $lblTitle = New-Object System.Windows.Forms.Label
        $lblTitle.Text = "Quick Notes"
        $lblTitle.Dock = "Left"
        $lblTitle.Padding = New-Object System.Windows.Forms.Padding(10, 0, 0, 0)
        $lblTitle.Font = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
        $lblTitle.ForeColor = [System.Drawing.Color]::White
        $titleBar.Controls.Add($lblTitle)
        $btnClose = New-Object System.Windows.Forms.Button
        $btnClose.Text = "X"
        $btnClose.Dock = "Right"
        $btnClose.Width = 40
        $btnClose.BackColor = [System.Drawing.Color]::FromArgb(180, 60, 60)
        $btnClose.ForeColor = [System.Drawing.Color]::White
        $btnClose.FlatStyle = "Flat"
        $btnClose.Add_Click({ $this.HideOverlay() })
        $titleBar.Controls.Add($btnClose)
        $btnNew = New-Object System.Windows.Forms.Button
        $btnNew.Text = "+ New Note"
        $btnNew.Location = New-Object System.Drawing.Point(20, 50)
        $btnNew.Size = New-Object System.Drawing.Size(120, 35)
        $btnNew.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
        $btnNew.ForeColor = [System.Drawing.Color]::White
        $btnNew.FlatStyle = "Flat"
        $this.OverlayForm.Controls.Add($btnNew)
        $btnNew.Add_Click({ $this.CreateNoteAndShow() })
        $notesPanel = New-Object System.Windows.Forms.Panel
        $notesPanel.Location = New-Object System.Drawing.Point(20, 95)
        $notesPanel.Size = New-Object System.Drawing.Size(760, 480)
        $notesPanel.AutoScroll = $true
        $this.OverlayForm.Controls.Add($notesPanel)
        $y = 0
        foreach ($note in $this.Notes) {
            $noteCard = $this.CreateNoteCard($note)
            $noteCard.Location = New-Object System.Drawing.Point(0, $y)
            $notesPanel.Controls.Add($noteCard)
            $y += 110
        }
        $this.IsVisible = $true
        $this.OverlayForm.ShowDialog()
    }
    
    [System.Windows.Forms.Panel] CreateNoteCard([hashtable]$note) {
        $card = New-Object System.Windows.Forms.Panel
        $card.Size = New-Object System.Drawing.Size(740, 100)
        $bgColor = [System.Drawing.ColorTranslator]::FromHtml($note.color)
        $card.BackColor = $bgColor
        $card.BorderStyle = "FixedSingle"
        $titleBox = New-Object System.Windows.Forms.TextBox
        $titleBox.Text = $note.title
        $titleBox.Location = New-Object System.Drawing.Point(10, 10)
        $titleBox.Size = New-Object System.Drawing.Size(600, 25)
        $titleBox.BackColor = $bgColor
        $titleBox.BorderStyle = "None"
        $titleBox.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
        $titleBox.Tag = $note.id
        $titleBox.Add_TextChanged({
            $this.Parent.Tag = $this.Text
        })
        $titleBox.Add_LostFocus({
            $n = $script:gooseQuickNotes.Notes | Where-Object { $_.id -eq $this.Tag } | Select-Object -First 1
            if ($n) { $script:gooseQuickNotes.UpdateNote($this.Tag, @{title=$this.Text}) }
        })
        $card.Controls.Add($titleBox)
        $contentBox = New-Object System.Windows.Forms.TextBox
        $contentBox.Text = $note.content
        $contentBox.Location = New-Object System.Drawing.Point(10, 40)
        $contentBox.Size = New-Object System.Drawing.Size(600, 50)
        $contentBox.BackColor = $bgColor
        $contentBox.BorderStyle = "None"
        $contentBox.Multiline = $true
        $contentBox.Tag = $note.id
        $contentBox.Add_TextChanged({
            $this.Parent.Tag = $this.Text
        })
        $contentBox.Add_LostFocus({
            $script:gooseQuickNotes.UpdateNote($this.Tag, @{content=$this.Text})
        })
        $card.Controls.Add($contentBox)
        $btnDelete = New-Object System.Windows.Forms.Button
        $btnDelete.Text = "Delete"
        $btnDelete.Location = New-Object System.Drawing.Point(620, 10)
        $btnDelete.Size = New-Object System.Drawing.Size(70, 30)
        $btnDelete.BackColor = [System.Drawing.Color]::FromArgb(180, 60, 60)
        $btnDelete.ForeColor = [System.Drawing.Color]::White
        $btnDelete.FlatStyle = "Flat"
        $btnDelete.Tag = $note.id
        $btnDelete.Add_Click({
            $script:gooseQuickNotes.DeleteNote($this.Tag)
            $this.Parent.Parent.Refresh()
        })
        $card.Controls.Add($btnDelete)
        $btnPin = New-Object System.Windows.Forms.Button
        $btnPin.Text = if ($note.isPinned) { "Unpin" } else { "Pin" }
        $btnPin.Location = New-Object System.Drawing.Point(620, 45)
        $btnPin.Size = New-Object System.Drawing.Size(70, 30)
        $btnPin.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 105)
        $btnPin.ForeColor = [System.Drawing.Color]::White
        $btnPin.FlatStyle = "Flat"
        $btnPin.Tag = $note.id
        $btnPin.Add_Click({
            $script:gooseQuickNotes.TogglePin($this.Tag)
            $this.Text = if ($this.Text -eq "Pin") { "Unpin" } else { "Pin" }
        })
        $card.Controls.Add($btnPin)
        return $card
    }
    
    [void] CreateNoteAndShow() {
        $note = $this.CreateNote("New Note", "")
        $this.Telemetry?.IncrementCounter("notes.created_from_ui", 1)
        $this.ShowOverlay()
    }
    
    [void] HideOverlay() {
        if ($this.OverlayForm) {
            $this.OverlayForm.Close()
            $this.OverlayForm = $null
        }
        $this.IsVisible = $false
    }
    
    [array] GetNotes() {
        return $this.Notes
    }
    
    [hashtable] GetStats() {
        return @{
            totalNotes = $this.Notes.Count
            pinnedNotes = ($this.Notes | Where-Object { $_.isPinned }).Count
            totalCharacters = ($this.Notes | ForEach-Object { $_.content.Length } | Measure-Object -Sum).Sum
        }
    }
}

$gooseQuickNotes = $null

function Get-QuickNotes {
    param([object]$Telemetry = $null)
    if ($script:gooseQuickNotes -eq $null) {
        $script:gooseQuickNotes = [GooseQuickNotes]::new("config.ini", $Telemetry)
    }
    return $script:gooseQuickNotes
}

function Show-QuickNotesOverlay {
    $notes = Get-QuickNotes
    $notes.ShowOverlay()
}

function New-QuickNote {
    param([string]$Title = "", [string]$Content = "")
    $notes = Get-QuickNotes
    return $notes.CreateNote($Title, $Content)
}

Write-Host "Quick Notes Module Initialized"
