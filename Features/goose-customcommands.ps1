class GooseCommands {
    [hashtable]$Config
    [hashtable]$CustomCommands
    [hashtable]$CommandHistory
    [int]$TotalCommandsExecuted
    
    GooseCommands() {
        $this.Config = $this.LoadConfig()
        $this.CustomCommands = @{}
        $this.CommandHistory = @{}
        $this.TotalCommandsExecuted = 0
        $this.InitDefaultCommands()
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
                    } elseif ($value -match '^\d+\.\d+$') {
                        $this.Config[$key] = [double]$value
                    } else {
                        $this.Config[$key] = $value
                    }
                }
            }
        }
        
        if (-not $this.Config.ContainsKey("CustomCommandsEnabled")) {
            $this.Config["CustomCommandsEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] InitDefaultCommands() {
        $defaults = @{
            "hello" = @{
                "Name" = "hello"
                "Trigger" = "hello"
                "Response" = "Hello! How can I help you today?"
                "Category" = "Greeting"
                "Action" = ""
            }
            "help" = @{
                "Name" = "help"
                "Trigger" = "help"
                "Response" = "I can help with: tasks, weather, focus, mood, goals, battery, time, inspiration, kindness, and more!"
                "Category" = "System"
                "Action" = ""
            }
            "time" = @{
                "Name" = "time"
                "Trigger" = "time"
                "Response" = ""
                "Category" = "Information"
                "Action" = "Get-Time"
            }
            "date" = @{
                "Name" = "date"
                "Trigger" = "date"
                "Response" = ""
                "Category" = "Information"
                "Action" = "Get-Date"
            }
            "status" = @{
                "Name" = "status"
                "Trigger" = "status"
                "Response" = ""
                "Category" = "System"
                "Action" = "Get-Status"
            }
            "quote" = @{
                "Name" = "quote"
                "Trigger" = "quote"
                "Response" = ""
                "Category" = "Inspiration"
                "Action" = "Get-Quotes"
            }
            "focus" = @{
                "Name" = "focus"
                "Trigger" = "focus"
                "Response" = "Starting focus mode for 25 minutes. Good luck!"
                "Category" = "Productivity"
                "Action" = "Start-Focus"
            }
            "break" = @{
                "Name" = "break"
                "Trigger" = "break"
                "Response" = "Time for a break! Stand up, stretch, and rest your eyes."
                "Category" = "Wellness"
                "Action" = ""
            }
            "water" = @{
                "Name" = "water"
                "Trigger" = "water"
                "Response" = "Remember to drink some water! Stay hydrated!"
                "Category" = "Wellness"
                "Action" = ""
            }
            "joke" = @{
                "Name" = "joke"
                "Trigger" = "joke"
                "Response" = ""
                "Category" = "Fun"
                "Action" = "Tell-Joke"
            }
        }
        
        foreach ($key in $defaults.Keys) {
            if (-not $this.CustomCommands.ContainsKey($key)) {
                $this.CustomCommands[$key] = $defaults[$key]
            }
        }
    }
    
    [void] LoadData() {
        $dataFile = "goose_commands.json"
        
        if (Test-Path $dataFile) {
            try {
                $data = Get-Content $dataFile -Raw | ConvertFrom-Json
                
                if ($data.CustomCommands) {
                    foreach ($cmd in $data.CustomCommands.PSObject.Properties) {
                        $this.CustomCommands[$cmd.Name] = $cmd.Value
                    }
                }
                
                if ($data.CommandHistory) {
                    $this.CommandHistory = @{}
                    $data.CommandHistory.PSObject.Properties | ForEach-Object {
                        $this.CommandHistory[$_.Name] = $_.Value
                    }
                }
                
                if ($data.TotalCommandsExecuted) {
                    $this.TotalCommandsExecuted = $data.TotalCommandsExecuted
                }
            } catch {}
        }
    }
    
    [void] SaveData() {
        $data = @{
            "CustomCommands" = $this.CustomCommands
            "CommandHistory" = $this.CommandHistory
            "TotalCommandsExecuted" = $this.TotalCommandsExecuted
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content "goose_commands.json"
    }
    
    [bool] AddCommand([string]$trigger, [string]$response, [string]$category = "Custom", [string]$action = "") {
        $triggerLower = $trigger.ToLower()
        
        if ($this.CustomCommands.ContainsKey($triggerLower)) {
            return $false
        }
        
        $this.CustomCommands[$triggerLower] = @{
            "Name" = $triggerLower
            "Trigger" = $triggerLower
            "Response" = $response
            "Category" = $category
            "Action" = $action
            "CreatedAt" = (Get-Date).ToString("o")
            "UsageCount" = 0
        }
        
        $this.SaveData()
        return $true
    }
    
    [bool] RemoveCommand([string]$trigger) {
        $triggerLower = $trigger.ToLower()
        
        if ($this.CustomCommands.ContainsKey($triggerLower)) {
            $this.CustomCommands.Remove($triggerLower)
            $this.SaveData()
            return $true
        }
        
        return $false
    }
    
    [bool] UpdateCommand([string]$trigger, [string]$response, [string]$action = "") {
        $triggerLower = $trigger.ToLower()
        
        if ($this.CustomCommands.ContainsKey($triggerLower)) {
            $this.CustomCommands[$triggerLower].Response = $response
            if ($action -ne "") {
                $this.CustomCommands[$triggerLower].Action = $action
            }
            $this.SaveData()
            return $true
        }
        
        return $false
    }
    
    [hashtable] ExecuteCommand([string]$input) {
        $inputLower = $input.ToLower().Trim()
        $response = ""
        $success = $false
        $action = ""
        
        if ($this.CustomCommands.ContainsKey($inputLower)) {
            $cmd = $this.CustomCommands[$inputLower]
            $response = $cmd.Response
            $action = $cmd.Action
            $success = $true
            
            if (-not $cmd.UsageCount) {
                $cmd.UsageCount = 0
            }
            $cmd.UsageCount++
            
            $this.TotalCommandsExecuted++
            $this.RecordCommand($inputLower)
            $this.SaveData()
        } else {
            $similar = $this.FindSimilarCommand($inputLower)
            
            if ($similar) {
                $response = "Did you mean '$($similar.Trigger)'? $($similar.Response)"
            } else {
                $response = "Unknown command. Type 'help' for available commands."
            }
        }
        
        return @{
            "Input" = $input
            "Response" = $response
            "Success" = $success
            "Action" = $action
            "Timestamp" = (Get-Date).ToString("o")
        }
    }
    
    [void] RecordCommand([string]$trigger) {
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        
        if (-not $this.CommandHistory.ContainsKey($dateKey)) {
            $this.CommandHistory[$dateKey] = @()
        }
        
        $this.CommandHistory[$dateKey] += @{
            "Command" = $trigger
            "Timestamp" = (Get-Date).ToString("o")
        }
    }
    
    [object] FindSimilarCommand([string]$input) {
        $bestMatch = $null
        $bestScore = 0
        
        foreach ($cmd in $this.CustomCommands.Values) {
            $score = 0
            
            if ($cmd.Trigger -like "$input*") {
                $score = 100
            } elseif ($input -like "$($cmd.Trigger)*") {
                $score = 80
            } elseif ($cmd.Trigger -match $input) {
                $score = 60
            }
            
            if ($score -gt $bestScore) {
                $bestScore = $score
                $bestMatch = $cmd
            }
        }
        
        if ($bestScore -ge 60) {
            return $bestMatch
        }
        
        return $null
    }
    
    [hashtable[]] GetAllCommands() {
        $commands = @()
        
        foreach ($cmd in $this.CustomCommands.Values) {
            $commands += @{
                "Trigger" = $cmd.Trigger
                "Response" = $cmd.Response
                "Category" = $cmd.Category
                "Action" = $cmd.Action
                "UsageCount" = if ($cmd.UsageCount) { $cmd.UsageCount } else { 0 }
            }
        }
        
        return $commands | Sort-Object { $_.Trigger }
    }
    
    [hashtable[]] GetCommandsByCategory([string]$category) {
        return $this.GetAllCommands() | Where-Object { $_.Category -eq $category }
    }
    
    [hashtable[]] GetMostUsedCommands([int]$count = 5) {
        return $this.GetAllCommands() | Sort-Object { -$_.UsageCount } | Select-Object -First $count
    }
    
    [hashtable] GetTodayCommandStats() {
        $dateKey = (Get-Date).ToString("yyyy-MM-dd")
        
        $stats = @{
            "Date" = $dateKey
            "TotalCommands" = 0
            "TopCommands" = @()
        }
        
        if ($this.CommandHistory.ContainsKey($dateKey)) {
            $commands = $this.CommandHistory[$dateKey]
            $stats.TotalCommands = $commands.Count
            
            $grouped = @{}
            foreach ($cmd in $commands) {
                if (-not $grouped.ContainsKey($cmd.Command)) {
                    $grouped[$cmd.Command] = 0
                }
                $grouped[$cmd.Command]++
            }
            
            $sorted = $grouped.GetEnumerator() | Sort-Object { $_.Value } -Descending
            $stats.TopCommands = @()
            
            foreach ($item in $sorted | Select-Object -First 5) {
                $stats.TopCommands += @{
                    "Command" = $item.Key
                    "Count" = $item.Value
                }
            }
        }
        
        return $stats
    }
    
    [string[]] GetCategories() {
        $categories = @()
        
        foreach ($cmd in $this.CustomCommands.Values) {
            if ($categories -notcontains $cmd.Category) {
                $categories += $cmd.Category
            }
        }
        
        return $categories
    }
    
    [hashtable] GetCommandsState() {
        return @{
            "Enabled" = $this.Config["CustomCommandsEnabled"]
            "TotalCommands" = $this.CustomCommands.Count
            "TotalExecuted" = $this.TotalCommandsExecuted
            "AllCommands" = $this.GetAllCommands()
            "Categories" = $this.GetCategories()
            "MostUsed" = $this.GetMostUsedCommands()
            "TodayStats" = $this.GetTodayCommandStats()
        }
    }
}

$gooseCommands = [GooseCommands]::new()

function Get-GooseCommands {
    return $gooseCommands
}

function Add-CustomCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Trigger,
        [Parameter(Mandatory=$true)]
        [string]$Response,
        [string]$Category = "Custom",
        [string]$Action = "",
        $Commands = $gooseCommands
    )
    return $Commands.AddCommand($Trigger, $Response, $Category, $Action)
}

function Remove-CustomCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Trigger,
        $Commands = $gooseCommands
    )
    return $Commands.RemoveCommand($Trigger)
}

function Invoke-GooseCommand {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Input,
        $Commands = $gooseCommands
    )
    return $Commands.ExecuteCommand($Input)
}

function Get-CommandsList {
    param(
        [string]$Category = "",
        $Commands = $gooseCommands
    )
    if ($Category) {
        return $Commands.GetCommandsByCategory($Category)
    }
    return $Commands.GetAllCommands()
}

function Get-CommandsStatus {
    param($Commands = $gooseCommands)
    return $Commands.GetCommandsState()
}

Write-Host "Desktop Goose Custom Commands System Initialized"
$state = Get-CommandsStatus
Write-Host "Custom Commands: $($state['Enabled'])"
Write-Host "Available Commands: $($state['TotalCommands'])"
