Add-Type -AssemblyName System.Windows.Forms
Add-ObjectSystemDrawing

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$form = New-Object System.Windows.Forms.Form
$form.Text = "Desktop Goose - Task Manager"
$form.Size = New-Object System.Drawing.Size(700, 550)
$form.StartPosition = "CenterScreen"
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
$form.FormBorderStyle = "FixedDialog"

$titleLabel = New-Object System.Windows.Forms.Label
$titleLabel.Text = "Task Manager"
$titleLabel.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
$titleLabel.Location = New-Object System.Drawing.Point(20, 20)
$titleLabel.Size = New-Object System.Drawing.Size(200, 30)
$titleLabel.ForeColor = [System.Drawing.Color]::White
$form.Controls.Add($titleLabel)

$taskIcon = New-Object System.Windows.Forms.Label
$taskIcon.Text = "✅"
$taskIcon.Font = New-Object System.Drawing.Font("Segoe UI", 30)
$taskIcon.Location = New-Object System.Drawing.Point(600, 10)
$taskIcon.Size = New-Object System.Drawing.Size(50, 50)
$form.Controls.Add($taskIcon)

$statsPanel = New-Object System.Windows.Forms.Panel
$statsPanel.Location = New-Object System.Drawing.Point(20, 55)
$statsPanel.Size = New-Object System.Drawing.Size(640, 50)
$statsPanel.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$form.Controls.Add($statsPanel)

$lblTotal = New-Object System.Windows.Forms.Label
$lblTotal.Text = "Total: 0"
$lblTotal.Location = New-Object System.Drawing.Point(20, 15)
$lblTotal.Size = New-Object System.Drawing.Size(100, 25)
$lblTotal.ForeColor = [System.Drawing.Color]::LightGray
$statsPanel.Controls.Add($lblTotal)

$lblPending = New-Object System.Windows.Forms.Label
$lblPending.Text = "Pending: 0"
$lblPending.Location = New-Object System.Drawing.Point(130, 15)
$lblPending.Size = New-Object System.Drawing.Size(100, 25)
$lblPending.ForeColor = [System.Drawing.Color]::Yellow
$lblPending.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$statsPanel.Controls.Add($lblPending)

$lblCompleted = New-Object System.Windows.Forms.Label
$lblCompleted.Text = "Completed: 0"
$lblCompleted.Location = New-Object System.Drawing.Point(240, 15)
$lblCompleted.Size = New-Object System.Drawing.Size(110, 25)
$lblCompleted.ForeColor = [System.Drawing.Color]::Lime
$lblCompleted.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$statsPanel.Controls.Add($lblCompleted)

$lblOverdue = New-Object System.Windows.Forms.Label
$lblOverdue.Text = "Overdue: 0"
$lblOverdue.Location = New-Object System.Drawing.Point(360, 15)
$lblOverdue.Size = New-Object System.Drawing.Size(100, 25)
$lblOverdue.ForeColor = [System.Drawing.Color]::Red
$lblOverdue.Font = New-Object System.Drawing.Font("Segoe UI", 10, [System.Drawing.FontStyle]::Bold)
$statsPanel.Controls.Add($lblOverdue)

$tasksListView = New-Object System.Windows.Forms.ListView
$tasksListView.Location = New-Object System.Drawing.Point(20, 115)
$tasksListView.Size = New-Object System.Drawing.Size(640, 280)
$tasksListView.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$tasksListView.ForeColor = [System.Drawing.Color]::White
$tasksListView.FullRowSelect = $true
$tasksListView.GridLines = $true
$tasksListView.View = "Details"
$tasksListView.CheckBoxes = $true
$tasksListView.Columns.Add("Status", 50)
$tasksListView.Columns.Add("Title", 250)
$tasksListView.Columns.Add("Priority", 80)
$tasksListView.Columns.Add("Due Date", 120)
$tasksListView.Columns.Add("Created", 120)
$form.Controls.Add($tasksListView)

$addGroup = New-Object System.Windows.Forms.GroupBox
$addGroup.Text = "Add/Edit Task"
$addGroup.Location = New-Object System.Drawing.Point(20, 405)
$addGroup.Size = New-Object System.Drawing.Size(640, 90)
$addGroup.ForeColor = [System.Drawing.Color]::White
$addGroup.BackColor = [System.Drawing.Color]::FromArgb(40, 40, 45)
$form.Controls.Add($addGroup)

$lblTaskTitle = New-Object System.Windows.Forms.Label
$lblTaskTitle.Text = "Title:"
$lblTaskTitle.Location = New-Object System.Drawing.Point(15, 25)
$lblTaskTitle.Size = New-Object System.Drawing.Size(50, 22)
$lblTaskTitle.ForeColor = [System.Drawing.Color]::LightGray
$addGroup.Controls.Add($lblTaskTitle)

$txtTaskTitle = New-Object System.Windows.Forms.TextBox
$txtTaskTitle.Location = New-Object System.Drawing.Point(70, 23)
$txtTaskTitle.Size = New-Object System.Drawing.Size(280, 25)
$txtTaskTitle.BackColor = [System.Drawing.Color]::FromArgb(60, 60, 65)
$txtTaskTitle.ForeColor = [System.Drawing.Color]::White
$txtTaskTitle.PlaceholderText = "Enter task title..."
$addGroup.Controls.Add($txtTaskTitle)

$lblPriority = New-Object System.Windows.Forms.Label
$lblPriority.Text = "Priority:"
$lblPriority.Location = New-Object System.Drawing.Point(370, 25)
$lblPriority.Size = New-Object System.Drawing.Size(60, 22)
$lblPriority.ForeColor = [System.Drawing.Color]::LightGray
$addGroup.Controls.Add($lblPriority)

$cmbPriority = New-Object System.Windows.Forms.ComboBox
$cmbPriority.Location = New-Object System.Drawing.Point(435, 23)
$cmbPriority.Size = New-Object System.Drawing.Size(100, 25)
$cmbPriority.Items.Add("Low")
$cmbPriority.Items.Add("Normal")
$cmbPriority.Items.Add("High")
$cmbPriority.SelectedIndex = 1
$addGroup.Controls.Add($cmbPriority)

$lblDueDate = New-Object System.Windows.Forms.Label
$lblDueDate.Text = "Due Date:"
$lblDueDate.Location = New-Object System.Drawing.Point(15, 55)
$lblDueDate.Size = New-Object System.Drawing.Size(70, 22)
$lblDueDate.ForeColor = [System.Drawing.Color]::LightGray
$addGroup.Controls.Add($lblDueDate)

$dateTimePicker = New-Object System.Windows.Forms.DateTimePicker
$dateTimePicker.Location = New-Object System.Drawing.Point(90, 53)
$dateTimePicker.Size = New-Object System.Drawing.Size(180, 25)
$dateTimePicker.Format = "Short"
$dateTimePicker.ShowCheckBox = $true
$dateTimePicker.Checked = $false
$addGroup.Controls.Add($dateTimePicker)

$btnAddTask = New-Object System.Windows.Forms.Button
$btnAddTask.Text = "Add Task"
$btnAddTask.Location = New-Object System.Drawing.Point(290, 50)
$btnAddTask.Size = New-Object System.Drawing.Size(100, 30)
$btnAddTask.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
$btnAddTask.ForeColor = [System.Drawing.Color]::White
$btnAddTask.FlatStyle = "Flat"
$addGroup.Controls.Add($btnAddTask)

$btnComplete = New-Object System.Windows.Forms.Button
$btnComplete.Text = "Complete"
$btnComplete.Location = New-Object System.Drawing.Point(20, 505)
$btnComplete.Size = New-Object System.Drawing.Size(100, 35)
$btnComplete.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 80)
$btnComplete.ForeColor = [System.Drawing.Color]::White
$btnComplete.FlatStyle = "Flat"
$btnComplete.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($btnComplete)

$btnDelete = New-Object System.Windows.Forms.Button
$btnDelete.Text = "Delete"
$btnDelete.Location = New-Object System.Drawing.Point(130, 505)
$btnDelete.Size = New-Object System.Drawing.Size(100, 35)
$btnDelete.BackColor = [System.Drawing.Color]::FromArgb(180, 60, 60)
$btnDelete.ForeColor = [System.Drawing.Color]::White
$btnDelete.FlatStyle = "Flat"
$btnDelete.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($btnDelete)

$btnClearCompleted = New-Object System.Windows.Forms.Button
$btnClearCompleted.Text = "Clear Completed"
$btnClearCompleted.Location = New-Object System.Drawing.Point(240, 505)
$btnClearCompleted.Size = New-Object System.Drawing.Size(120, 35)
$btnClearCompleted.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 105)
$btnClearCompleted.ForeColor = [System.Drawing.Color]::White
$btnClearCompleted.FlatStyle = "Flat"
$btnClearCompleted.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($btnClearCompleted)

$btnClose = New-Object System.Windows.Forms.Button
$btnClose.Text = "Close"
$btnClose.Location = New-Object System.Drawing.Point(560, 505)
$btnClose.Size = New-Object System.Drawing.Size(100, 35)
$btnClose.BackColor = [System.Drawing.Color]::FromArgb(80, 80, 85)
$btnClose.ForeColor = [System.Drawing.Color]::White
$btnClose.FlatStyle = "Flat"
$btnClose.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$form.Controls.Add($btnClose)

$tasksData = New-Object System.Collections.ArrayList
$selectedTaskIndex = -1

function Refresh-Tasks-List {
    $tasksListView.Items.Clear()
    $total = 0
    $pending = 0
    $completed = 0
    $overdue = 0
    $now = Get-Date
    
    foreach ($task in $tasksData) {
        $total++
        $item = New-Object System.Windows.Forms.ListViewItem
        
        if ($task.Completed) {
            $item.Text = "☑️"
            $completed++
            $item.BackColor = [System.Drawing.Color]::FromArgb(50, 60, 50)
        } else {
            $item.Text = "⬜"
            $pending++
            
            if ($task.DueDate -and (Get-Date $task.DueDate) -lt $now) {
                $overdue++
                $item.BackColor = [System.Drawing.Color]::FromArgb(60, 40, 40)
            }
        }
        
        $item.SubItems.Add($task.Title)
        
        $priorityColor = switch ($task.Priority) {
            "High" { "🔴" }
            "Normal" { "🟡" }
            "Low" { "🟢" }
            default { "🟡" }
        }
        $item.SubItems.Add("$priorityColor $($task.Priority)")
        
        if ($task.DueDate) {
            $item.SubItems.Add((Get-Date $task.DueDate).ToString("yyyy-MM-dd"))
        } else {
            $item.SubItems.Add("-")
        }
        
        $item.SubItems.Add((Get-Date $task.CreatedAt).ToString("yyyy-MM-dd"))
        $tasksListView.Items.Add($item)
    }
    
    $lblTotal.Text = "Total: $total"
    $lblPending.Text = "Pending: $pending"
    $lblCompleted.Text = "Completed: $completed"
    $lblOverdue.Text = "Overdue: $overdue"
}

$btnAddTask.Add_Click({
    if ([string]::IsNullOrWhiteSpace($txtTaskTitle.Text)) {
        [System.Windows.Forms.MessageBox]::Show("Please enter a task title", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
        return
    }
    
    $task = @{
        Id = $tasksData.Count + 1
        Title = $txtTaskTitle.Text
        Priority = $cmbPriority.Text
        Completed = $false
        CreatedAt = (Get-Date).ToString("o")
        DueDate = if ($dateTimePicker.Checked) { $dateTimePicker.Value.ToString("o") } else { $null }
    }
    
    $tasksData.Add($task)
    $txtTaskTitle.Text = ""
    $cmbPriority.SelectedIndex = 1
    $dateTimePicker.Checked = $false
    
    Refresh-Tasks-List
})

$btnComplete.Add_Click({
    if ($tasksListView.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select a task", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }
    
    $idx = $tasksListView.SelectedIndices[0]
    if ($idx -lt $tasksData.Count) {
        $tasksData[$idx].Completed = $true
        Refresh-Tasks-List
    }
})

$btnDelete.Add_Click({
    if ($tasksListView.SelectedItems.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("Please select a task", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }
    
    $result = [System.Windows.Forms.MessageBox]::Show("Delete this task?", "Confirm", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($result -eq "Yes") {
        $idx = $tasksListView.SelectedIndices[0]
        if ($idx -lt $tasksData.Count) {
            $tasksData.RemoveAt($idx)
            Refresh-Tasks-List
        }
    }
})

$btnClearCompleted.Add_Click({
    $completedTasks = @()
    for ($i = 0; $i -lt $tasksData.Count; $i++) {
        if ($tasksData[$i].Completed) {
            $completedTasks += $i
        }
    }
    
    if ($completedTasks.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show("No completed tasks to clear", "Info", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        return
    }
    
    $result = [System.Windows.Forms.MessageBox]::Show("Clear $($completedTasks.Count) completed tasks?", "Confirm", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($result -eq "Yes") {
        for ($i = $completedTasks.Count - 1; $i -ge 0; $i--) {
            $tasksData.RemoveAt($completedTasks[$i])
        }
        Refresh-Tasks-List
    }
})

$btnClose.Add_Click({
    $form.Close()
})

Refresh-Tasks-List

[void]$form.ShowDialog()
