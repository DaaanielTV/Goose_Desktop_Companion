Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$form = New-Object System.Windows.Forms.Form
$form.Text = "Desktop Goose - Notes"
$form.Size = New-Object System.Drawing.Size(700, 500)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
$form.FormBorderStyle = "FixedDialog"

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Sticky Notes"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$titleLabel.Location = New-Object System.Drawing.Point(20, 20)
$titleLabel.Size = New-Object System.Drawing.Size(200, 30)
$titleLabel.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($titleLabel)

$notesIcon = New-Object System.Windows.Forms.Label
$notesIcon.Text = "📝"
$notesIcon.Font = New-Object System.Drawing.Font("Segoe UI", 30)
$notesIcon.Location = New-Object System.Drawing.Point(600, 10)
$notesIcon.Size = New-Object System.Drawing.Size(50, 50)
$form.Controls.Add($notesIcon)

$notesListBox = New-Object System.Windows.Forms.ListBox
$notesListBox.Location = New-Object System.Drawing.Point(20, 60)
$notesListBox.Size = New-Object System.Drawing.Size(250, 350)
$notesListBox.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$notesListBox.ForeColor = [System.Drawing.Color]::White
$notesListBox.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$notesListBox.ItemHeight = 25
$form.Controls.Add($notesListBox)

$editorGroup = New-Object System.Windows.Forms.GroupBox
$editorGroup.Text = "Note Editor"
$editorGroup.Location = New-Object System.Drawing.Point(285, 60)
$editorGroup.Size = New-Object System.Drawing.Size(380, 350)
$editorGroup.ForeColor = [System.Drawing.Color]::White
$editorGroup.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$form.Controls.Add($editorGroup)

$txtTitle = New-Object System.Windows.Forms.TextBox
$txtTitle.Location = New-Object System.Drawing.Point(15, 25)
$txtTitle.Size = New-Object System.Drawing.Size(350, 30)
$txtTitle.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 65)
$txtTitle.ForeColor = [System.Drawing.Color]::White
$txtTitle.Font = New-Object System.Drawing.Font("Segoe UI", 11)
$txtTitle.PlaceholderText = "Note title..."
$editorGroup.Controls.Add($txtTitle)

$txtContent = New-Object System.Windows.Forms.TextBox
$txtContent.Location = New-Object System.Drawing.Point(15, 65)
$txtContent.Size = New-Object System.Drawing.Size(350, 200)
$txtContent.Multiline = $true
$txtContent.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 65)
$txtContent.ForeColor = [System.Drawing.Color]::White
$txtContent.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$txtContent.ScrollBars = "Vertical"
$txtContent.PlaceholderText = "Write your note here..."
$editorGroup.Controls.Add($txtContent)

$lblColor = New-Object System.Windows.Forms.Label
$lblColor.Text = "Color:"
$lblColor.Location = New-Object System.Drawing.Point(15, 275)
$lblColor.Size = New-Object System.Drawing.Size(60, 25)
$lblColor.ForeColor = [System.Drawing.Color]::LightGray
$editorGroup.Controls.Add($lblColor)

$cmbColor = New-Object System.Windows.Forms.ComboBox
$cmbColor.Location = New-Object System.Drawing.Point(80, 273)
$cmbColor.Size = New-Object System.Drawing.Size(120, 25)
$cmbColor.Items.Add("Yellow")
$cmbColor.Items.Add("Green")
$cmbColor.Items.Add("Blue")
$cmbColor.Items.Add("Pink")
$cmbColor.Items.Add("Orange")
$cmbColor.SelectedIndex = 0
$editorGroup.Controls.Add($cmbColor)

$chkPinned = New-Object System.Windows.Forms.CheckBox
$chkPinned.Text = "Pin Note"
$chkPinned.Location = New-Object System.Drawing.Point(220, 275)
$chkPinned.Size = New-Object System.Drawing.Size(100, 25)
$chkPinned.ForeColor = [System.Drawing.Color]::White
$chkPinned.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$editorGroup.Controls.Add($chkPinned)

$lblReminder = New-Object System.Windows.Forms.Label
$lblReminder.Text = "Reminder (min):"
$lblReminder.Location = New-Object System.Drawing.Point(15, 305)
$lblReminder.Size = New-Object System.Drawing.Size(110, 25)
$lblReminder.ForeColor = [System.Drawing.Color]::LightGray
$editorGroup.Controls.Add($lblReminder)

$numReminder = New-Object System.Windows.Forms.NumericUpDown
$numReminder.Location = New-Object System.Drawing.Point(130, 303)
$numReminder.Size = New-Object System.Drawing.Size(70, 25)
$numReminder.Minimum = 0
$numReminder.Maximum = 1440
$numReminder.Value = 0
$numReminder.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 65)
$numReminder.ForeColor = [System.Drawing.Color]::White
$editorGroup.Controls.Add($numReminder)

$lblNoteCount = New-Object System.Windows.Forms.Label
$lblNoteCount.Text = "Notes: 0"
$lblNoteCount.Location = New-Object System.Drawing.Point(15, 420)
$lblNoteCount.Size = New-Object System.Drawing.Size(100, 25)
$lblNoteCount.ForeColor = [System.Drawing.Color]::LightGray
$form.Controls.Add($lblNoteCount)

$btnNew = New-Object System.Windows.Forms.Button
$btnNew.Text = "New Note"
$btnNew.Location = New-Object System.Drawing.Point(20, 450)
$btnNew.Size = New-Object System.Drawing.Size(100, 35)
$btnNew.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnNew.ForeColor = [System.Drawing.Color]::White
$btnNew.FlatStyle = "Flat"
$btnNew.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($btnNew)

$btnSave = New-Object System.Windows.Forms.Button
$btnSave.Text = "Save Note"
$btnSave.Location = New-Object System.Drawing.Point(130, 450)
$btnSave.Size = New-Object System.Drawing.Size(100, 35)
$btnSave.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 80)
$btnSave.ForeColor = [System.Drawing.Color]::White
$btnSave.FlatStyle = "Flat"
$btnSave.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($btnSave)

$btnDelete = New-Object System.Windows.Forms.Button
$btnDelete.Text = "Delete"
$btnDelete.Location = New-Object System.Drawing.Point(240, 450)
$btnDelete.Size = New-Object System.Drawing.Size(100, 35)
$btnDelete.BackColor = [System.Drawing.Color]::FromArgb(180, 60, 60)
$btnDelete.ForeColor = [System.Drawing.Color]::White
$btnDelete.FlatStyle = "Flat"
$btnDelete.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($btnDelete)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Location = New-Object System.Drawing.Point(550, 450)
$btnClose.Size = New-Object System.Drawing.Size(100, 35)
$btnClose.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 105)
$btnClose.ForeColor = [System.Drawing.Color]::White
$btnClose.FlatStyle = "Flat"
$btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($btnClose)

$notesData = New-Object System.Collections.ArrayList
$selectedNoteIndex = -1

function Refresh-Notes-List {
    $notesListBox.Items.Clear()
    foreach ($note in $notesData) {
        $displayText = "$($note.Title) [$($note.Color)]"
        if ($note.IsPinned) {
            $displayText = "📌 $displayText"
        }
        $notesListBox.Items.Add($displayText)
    }
    $lblNoteCount.Text = "Notes: $($notesData.Count)"
}

function Clear-Editor {
    $txtTitle.Text = ""
    $txtContent.Text = ""
    $cmbColor.SelectedIndex = 0
    $chkPinned.Checked = $false
    $numReminder.Value = 0
}

$btnNew.Add_Click({
    Clear-Editor
    $script:selectedNoteIndex = -1
    $notesListBox.SelectedIndex = -1
})

$btnSave.Add_Click({
    if ([string]::IsNullOrWhiteSpace($txtTitle.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a title", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $note = @{
        Id = [guid]::NewGuid().ToString()
        Title = $txtTitle.Text
        Content = $txtContent.Text
        Color = $cmbColor.Text
        IsPinned = $chkPinned.Checked
        CreatedAt = (Get-Date).ToString("o")
        ReminderMinutes = $numReminder.Value
    }
    
    if ($selectedNoteIndex -ge 0 -and $selectedNoteIndex -lt $notesData.Count) {
        $notesData[$selectedNoteIndex] = $note
    } else {
        $notesData.Add($note)
    }
    
    Refresh-Notes-List
    [System.Windows.Forms.MessageBox]::Show("Note saved!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

$btnDelete.Add_Click({
    if ($selectedNoteIndex -lt 0 -or $selectedNoteIndex -ge $notesData.Count) {
        [System.Windows.Forms.MessageBox]::Show("Please select a note to delete", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }
    
    $result = [System.Windows.Forms.MessageBox]::Show("Delete this note?", "Confirm", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($result -eq "Yes") {
        $notesData.RemoveAt($selectedNoteIndex)
        Clear-Editor
        $script:selectedNoteIndex = -1
        Refresh-Notes-List
    }
})

$notesListBox.Add_SelectedIndexChanged({
    $script:selectedNoteIndex = $notesListBox.SelectedIndex
    if ($selectedNoteIndex -ge 0 -and $selectedNoteIndex -lt $notesData.Count) {
        $note = $notesData[$selectedNoteIndex]
        $txtTitle.Text = $note.Title
        $txtContent.Text = $note.Content
        
        $colorIndex = switch ($note.Color) {
            "Yellow" { 0 }
            "Green" { 1 }
            "Blue" { 2 }
            "Pink" { 3 }
            "Orange" { 4 }
            default { 0 }
        }
        $cmbColor.SelectedIndex = $colorIndex
        $chkPinned.Checked = $note.IsPinned
        $numReminder.Value = $note.ReminderMinutes
    }
})

$btnClose.Add_Click({
    $form.Close()
})

Refresh-Notes-List

[void]$form.ShowDialog()
