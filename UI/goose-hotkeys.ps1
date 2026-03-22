Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$form = New-Object System.Windows.Forms.Form
$form.Text = "Desktop Goose - Global Hotkeys"
$form.Size = New-Object System.Drawing.Size(600, 500)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox = $false

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Global Hotkeys Configuration"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$titleLabel.Location = New-Object System.Drawing.Point(20, 20)
$titleLabel.Size = New-Object System.Drawing.Size(350, 30)
$titleLabel.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($titleLabel)

$keyboardIcon = New-Object System.Windows.Forms.Label
$keyboardIcon.Text = "⌨️"
$keyboardIcon.Font = New-Object System.Drawing.Font("Segoe UI", 30)
$keyboardIcon.Location = New-Object System.Drawing.Point(520, 10)
$keyboardIcon.Size = New-Object System.Drawing.Size(50, 50)
$form.Controls.Add($keyboardIcon)

$hotkeysListView = New-Object System.Windows.Forms.ListView
$hotkeysListView.Location = New-Object System.Drawing.Point(20, 60)
$hotkeysListView.Size = New-Object System.Drawing.Size(550, 280)
$hotkeysListView.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$hotkeysListView.ForeColor = [System.Drawing.Color]::White
$hotkeysListView.FullRowSelect = $true
$hotkeysListView.GridLines = $true
$hotkeysListView.View = "Details"
$hotkeysListView.Columns.Add("Hotkey", 150)
$hotkeysListView.Columns.Add("Action", 150)
$hotkeysListView.Columns.Add("Description", 240)
$form.Controls.Add($hotkeysListView)

$defaultHotkeys = @(
    @{Hotkey="Ctrl+Shift+G"; Action="toggle"; Description="Toggle goose visibility"},
    @{Hotkey="Ctrl+Shift+H"; Action="honk"; Description="Make goose honk"},
    @{Hotkey="Ctrl+Shift+F"; Action="focus"; Description="Start focus mode"},
    @{Hotkey="Ctrl+Shift+S"; Action="screenshot"; Description="Screenshot pose"},
    @{Hotkey="Ctrl+Shift+T"; Action="timer"; Description="Quick timer"},
    @{Hotkey="Ctrl+Shift+N"; Action="notes"; Description="Open notes"},
    @{Hotkey="Ctrl+Shift+P"; Action="pomodoro"; Description="Start pomodoro"},
    @{Hotkey="Ctrl+Shift+L"; Action="stats"; Description="Show stats"}
)

foreach ($hk in $defaultHotkeys) {
    $item = New-Object System.Windows.Forms.ListViewItem
    $item.Text = $hk.Hotkey
    $item.SubItems.Add($hk.Action)
    $item.SubItems.Add($hk.Description)
    $hotkeysListView.Items.Add($item)
}

$addGroup = New-Object System.Windows.Forms.GroupBox
$addGroup.Text = "Add New Hotkey"
$addGroup.Location = New-Object System.Drawing.Point(20, 350)
$addGroup.Size = New-Object System.Drawing.Size(550, 90)
$addGroup.ForeColor = [System.Drawing.Color]::White
$addGroup.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$form.Controls.Add($addGroup)

$lblNewHotkey = New-Object System.Windows.Forms.Label
$lblNewHotkey.Text = "Hotkey:"
$lblNewHotkey.Location = New-Object System.Drawing.Point(15, 25)
$lblNewHotkey.Size = New-Object System.Drawing.Size(60, 22)
$lblNewHotkey.ForeColor = [System.Drawing.Color]::LightGray
$addGroup.Controls.Add($lblNewHotkey)

$txtNewHotkey = New-Object System.Windows.Forms.TextBox
$txtNewHotkey.Location = New-Object System.Drawing.Point(80, 23)
$txtNewHotkey.Size = New-Object System.Drawing.Size(120, 25)
$txtNewHotkey.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 65)
$txtNewHotkey.ForeColor = [System.Drawing.Color]::White
$txtNewHotkey.PlaceholderText = "e.g. Ctrl+Shift+K"
$addGroup.Controls.Add($txtNewHotkey)

$lblNewAction = New-Object System.Windows.Forms.Label
$lblNewAction.Text = "Action:"
$lblNewAction.Location = New-Object System.Drawing.Point(220, 25)
$lblNewAction.Size = New-Object System.Drawing.Size(60, 22)
$lblNewAction.ForeColor = [System.Drawing.Color]::LightGray
$addGroup.Controls.Add($lblNewAction)

$cmbNewAction = New-Object System.Windows.Forms.ComboBox
$cmbNewAction.Location = New-Object System.Drawing.Point(285, 23)
$cmbNewAction.Size = New-Object System.Drawing.Size(120, 25)
$cmbNewAction.Items.Add("toggle")
$cmbNewAction.Items.Add("honk")
$cmbNewAction.Items.Add("focus")
$cmbNewAction.Items.Add("screenshot")
$cmbNewAction.Items.Add("timer")
$cmbNewAction.Items.Add("notes")
$cmbNewAction.Items.Add("pomodoro")
$cmbNewAction.Items.Add("custom")
$cmbNewAction.SelectedIndex = 0
$addGroup.Controls.Add($cmbNewAction)

$lblNewDesc = New-Object System.Windows.Forms.Label
$lblNewDesc.Text = "Description:"
$lblNewDesc.Location = New-Object System.Drawing.Point(15, 55)
$lblNewDesc.Size = New-Object System.Drawing.Size(80, 22)
$lblNewDesc.ForeColor = [System.Drawing.Color]::LightGray
$addGroup.Controls.Add($lblNewDesc)

$txtNewDesc = New-Object System.Windows.Forms.TextBox
$txtNewDesc.Location = New-Object System.Drawing.Point(100, 53)
$txtNewDesc.Size = New-Object System.Drawing.Size(440, 25)
$txtNewDesc.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 65)
$txtNewDesc.ForeColor = [System.Drawing.Color]::White
$txtNewDesc.PlaceholderText = "Enter description..."
$addGroup.Controls.Add($txtNewDesc)

$btnAdd = New-Object System.Windows.Forms.Button
$btnAdd.Text = "Add Hotkey"
$btnAdd.Location = New-Object System.Drawing.Point(20, 455)
$btnAdd.Size = New-Object System.Drawing.Size(120, 35)
$btnAdd.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 80)
$btnAdd.ForeColor = [System.Drawing.Color]::White
$btnAdd.FlatStyle = "Flat"
$btnAdd.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($btnAdd)

$btnRemove = New-Object System.Windows.Forms.Button
$btnRemove.Text = "Remove Selected"
$btnRemove.Location = New-Object System.Drawing.Point(150, 455)
$btnRemove.Size = New-Object System.Drawing.Size(120, 35)
$btnRemove.BackColor = [System.Drawing.Color]::FromArgb(180, 60, 60)
$btnRemove.ForeColor = [System.Drawing.Color]::White
$btnRemove.FlatStyle = "Flat"
$btnRemove.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($btnRemove)

$btnReset = New-Object System.Windows.Forms.Button
$btnReset.Text = "Reset to Defaults"
$btnReset.Location = New-Object System.Drawing.Point(280, 455)
$btnReset.Size = New-Object System.Drawing.Size(130, 35)
$btnReset.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 105)
$btnReset.ForeColor = [System.Drawing.Color]::White
$btnReset.FlatStyle = "Flat"
$btnReset.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($btnReset)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Location = New-Object System.Drawing.Point(450, 455)
$btnClose.Size = New-Object System.Drawing.Size(120, 35)
$btnClose.BackColor = [System.Drawing.Color]::FromArgb(80, 80, 85)
$btnClose.ForeColor = [System.Drawing.Color]::White
$btnClose.FlatStyle = "Flat"
$btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($btnClose)

$btnAdd.Add_Click({
    if ([string]::IsNullOrWhiteSpace($txtNewHotkey.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a hotkey", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $item = New-Object System.Windows.Forms.ListViewItem
    $item.Text = $txtNewHotkey.Text
    $item.SubItems.Add($cmbNewAction.Text)
    $item.SubItems.Add($txtNewDesc.Text)
    $hotkeysListView.Items.Add($item)
    
    $txtNewHotkey.Text = ""
    $txtNewDesc.Text = ""
    
    [System.Windows.Forms.MessageBox]::Show("Hotkey added successfully!", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
})

$btnRemove.Add_Click({
    if ($hotkeysListView.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select a hotkey to remove", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }
    
    $result = [System.Windows.Forms.MessageBox]::Show("Remove selected hotkey?", "Confirm", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($result -eq "Yes") {
        $hotkeysListView.SelectedItems[0].Remove()
    }
})

$btnReset.Add_Click({
    $result = [System.Windows.Forms.MessageBox]::Show("Reset all hotkeys to defaults?", "Confirm", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($result -eq "Yes") {
        $hotkeysListView.Items.Clear()
        foreach ($hk in $defaultHotkeys) {
            $item = New-Object System.Windows.Forms.ListViewItem
            $item.Text = $hk.Hotkey
            $item.SubItems.Add($hk.Action)
            $item.SubItems.Add($hk.Description)
            $hotkeysListView.Items.Add($item)
        }
        [System.Windows.Forms.MessageBox]::Show("Hotkeys reset to defaults", "Success", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
})

$btnClose.Add_Click({
    $form.Close()
})

[void]$form.ShowDialog()
