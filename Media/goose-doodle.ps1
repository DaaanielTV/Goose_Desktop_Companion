# Desktop Goose Screen Doodle System
# Draw on screen

class GooseScreenDoodle {
    [hashtable]$Config
    [bool]$IsDrawing
    [string]$CurrentTool
    [string]$CurrentColor
    [int]$BrushSize
    [array]$Doodles
    [string]$DoodleFile
    
    GooseScreenDoodle() {
        $this.Config = $this.LoadConfig()
        $this.IsDrawing = $false
        $this.CurrentTool = "pen"
        $this.CurrentColor = "#FF0000"
        $this.BrushSize = 3
        $this.DoodleFile = "goose_doodles.json"
        $this.Doodles = @()
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
        
        if (-not $this.Config.ContainsKey("ScreenDoodleEnabled")) {
            $this.Config["ScreenDoodleEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] StartDoodle() {
        $this.IsDrawing = $true
    }
    
    [void] StopDoodle() {
        $this.IsDrawing = $false
    }
    
    [void] SetTool([string]$tool) {
        $validTools = @("pen", "highlighter", "eraser", "arrow", "circle", "rectangle")
        if ($validTools -contains $tool) {
            $this.CurrentTool = $tool
        }
    }
    
    [void] SetColor([string]$color) {
        $this.CurrentColor = $color
    }
    
    [void] SetBrushSize([int]$size) {
        $this.BrushSize = [Math]::Max(1, [Math]::Min(20, $size))
    }
    
    [hashtable] DrawLine([int]$x1, [int]$y1, [int]$x2, [int]$y2) {
        $point = @{
            "Tool" = $this.CurrentTool
            "Color" = $this.CurrentColor
            "Size" = $this.BrushSize
            "Type" = "line"
            "X1" = $x1
            "Y1" = $y1
            "X2" = $x2
            "Y2" = $y2
            "Timestamp" = (Get-Date).ToString("o")
        }
        
        $this.Doodles += $point
        
        return @{
            "Success" = $true
            "Point" = $point
        }
    }
    
    [void] ClearDoodles() {
        $this.Doodles = @()
    }
    
    [void] UndoLastDoodle() {
        if ($this.Doodles.Count -gt 0) {
            $this.Doodles = $this.Doodles[0..($this.Doodles.Count - 2)]
        }
    }
    
    [hashtable] GetScreenDoodleState() {
        return @{
            "Enabled" = $this.Config["ScreenDoodleEnabled"]
            "IsDrawing" = $this.IsDrawing
            "CurrentTool" = $this.CurrentTool
            "CurrentColor" = $this.CurrentColor
            "BrushSize" = $this.BrushSize
            "DoodleCount" = $this.Doodles.Count
        }
    }
}

$gooseScreenDoodle = [GooseScreenDoodle]::new()

function Get-GooseScreenDoodle {
    return $gooseScreenDoodle
}

function Start-Doodling {
    param($Doodle = $gooseScreenDoodle)
    $Doodle.StartDoodle()
}

function Stop-Doodling {
    param($Doodle = $gooseScreenDoodle)
    $Doodle.StopDoodle()
}

function Set-DoodleTool {
    param(
        [string]$Tool,
        $Doodle = $gooseScreenDoodle
    )
    $Doodle.SetTool($Tool)
}

function Get-DoodleState {
    param($Doodle = $gooseScreenDoodle)
    return $Doodle.GetScreenDoodleState()
}

Write-Host "Desktop Goose Screen Doodle System Initialized"
$state = Get-DoodleState
Write-Host "Screen Doodle Enabled: $($state['Enabled'])"
Write-Host "Current Tool: $($state['CurrentTool'])"
