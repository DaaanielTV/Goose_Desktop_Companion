class GooseWindowManager {
    [hashtable]$Config
    [string]$DataPath
    [object]$Telemetry
    [array]$Presets
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    static extern bool SetWindowPos(IntPtr hWnd, IntPtr hWndInsertAfter, int X, int Y, int cx, int cy, uint uFlags);
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    
    GooseWindowManager([string]$configFile = "config.ini", [object]$telemetry = $null) {
        $this.Telemetry = $telemetry
        $this.LoadConfig($configFile)
        $this.DataPath = Join-Path $PSScriptRoot "windowmanager_data"
        if (-not (Test-Path $this.DataPath)) {
            New-Item -ItemType Directory -Path $this.DataPath -Force | Out-Null
        }
        $this.Presets = @()
        $this.LoadPresets()
    }
    
    [void] LoadConfig([string]$configFile) {
        $this.Config = @{
            Enabled = $true
            AnimationSpeed = 100
            SnapThreshold = 50
            RememberPositions = $true
            MultiMonitorSupport = $true
        }
        if (Test-Path $configFile) {
            Get-Content $configFile | ForEach-Object {
                if ($_ -match '^([^=]+)=(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    if ($this.Config.ContainsKey($key)) {
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
        }
    }
    
    [void] LoadPresets() {
        $presetsFile = Join-Path $this.DataPath "presets.json"
        if (Test-Path $presetsFile) {
            try {
                $this.Presets = @(Get-Content $presetsFile -Raw | ConvertFrom-Json)
                if ($this.Presets -isnot [array]) { $this.Presets = @() }
            } catch {
                $this.Presets = @()
            }
        }
    }
    
    [void] SavePresets() {
        $presetsFile = Join-Path $this.DataPath "presets.json"
        $this.Presets | ConvertTo-Json -Depth 10 | Set-Content -Path $presetsFile
    }
    
    [void] SnapLeft([string]$windowTitle = "") {
        $this.Telemetry?.IncrementCounter("window.snap_actions", 1, @{direction="left"})
        $window = $this.FindWindow($windowTitle)
        if ($window) {
            $screen = [System.Windows.Forms.Screen]::FromHandle($window)
            $rect = $screen.WorkingArea
            $width = [int]($rect.Width / 2)
            $this.SetWindowPosition($window, $rect.Left, $rect.Top, $width, $rect.Height)
        }
    }
    
    [void] SnapRight([string]$windowTitle = "") {
        $this.Telemetry?.IncrementCounter("window.snap_actions", 1, @{direction="right"})
        $window = $this.FindWindow($windowTitle)
        if ($window) {
            $screen = [System.Windows.Forms.Screen]::FromHandle($window)
            $rect = $screen.WorkingArea
            $width = [int]($rect.Width / 2)
            $this.SetWindowPosition($window, $rect.Left + $width, $rect.Top, $width, $rect.Height)
        }
    }
    
    [void] SnapTop([string]$windowTitle = "") {
        $this.Telemetry?.IncrementCounter("window.snap_actions", 1, @{direction="top"})
        $window = $this.FindWindow($windowTitle)
        if ($window) {
            $screen = [System.Windows.Forms.Screen]::FromHandle($window)
            $rect = $screen.WorkingArea
            $this.SetWindowPosition($window, $rect.Left, $rect.Top, $rect.Width, [int]($rect.Height / 2))
        }
    }
    
    [void] SnapBottom([string]$windowTitle = "") {
        $this.Telemetry?.IncrementCounter("window.snap_actions", 1, @{direction="bottom"})
        $window = $this.FindWindow($windowTitle)
        if ($window) {
            $screen = [System.Windows.Forms.Screen]::FromHandle($window)
            $rect = $screen.WorkingArea
            $this.SetWindowPosition($window, $rect.Left, $rect.Top + [int]($rect.Height / 2), $rect.Width, [int]($rect.Height / 2))
        }
    }
    
    [void] MaximizeWindow([string]$windowTitle = "") {
        $this.Telemetry?.IncrementCounter("window.maximize_actions", 1)
        $window = $this.FindWindow($windowTitle)
        if ($window) {
            ShowWindow($window, 3)
        }
    }
    
    [void] MinimizeWindow([string]$windowTitle = "") {
        $this.Telemetry?.IncrementCounter("window.minimize_actions", 1)
        $window = $this.FindWindow($windowTitle)
        if ($window) {
            ShowWindow($window, 6)
        }
    }
    
    [void] CenterWindow([string]$windowTitle = "") {
        $this.Telemetry?.IncrementCounter("window.center_actions", 1)
        $window = $this.FindWindow($windowTitle)
        if ($window) {
            $screen = [System.Windows.Forms.Screen]::FromHandle($window)
            $rect = $screen.WorkingArea
            $bounds = $this.GetWindowBounds($window)
            $x = [int](($rect.Width - $bounds.Width) / 2) + $rect.Left
            $y = [int](($rect.Height - $bounds.Height) / 2) + $rect.Top
            $this.SetWindowPosition($window, $x, $y, $bounds.Width, $bounds.Height)
        }
    }
    
    [void] TileAllWindows() {
        $this.Telemetry?.IncrementCounter("window.tile_all", 1)
        Add-Type -AssemblyName System.Windows.Forms
        $windows = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle } | Select-Object -First 8
        if ($windows.Count -eq 0) { return }
        $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
        $cols = [Math]::Ceiling([Math]::Sqrt($windows.Count))
        $rows = [Math]::Ceiling($windows.Count / $cols)
        $cellWidth = [int]($screen.Width / $cols)
        $cellHeight = [int]($screen.Height / $rows)
        $i = 0
        foreach ($proc in $windows) {
            $col = $i % $cols
            $row = [Math]::Floor($i / $cols)
            $x = $screen.Left + ($col * $cellWidth)
            $y = $screen.Top + ($row * $cellHeight)
            $this.SetWindowPosition($proc.MainWindowHandle, $x, $y, $cellWidth, $cellHeight)
            $i++
        }
    }
    
    [void] SetWindowPosition([IntPtr]$hwnd, [int]$x, [int]$y, [int]$width, [int]$height) {
        SetWindowPos($hwnd, [IntPtr]::Zero, $x, $y, $width, $height, 0x0040)
    }
    
    [IntPtr] FindWindow([string]$title) {
        Add-Type -AssemblyName Microsoft.VisualBasic
        if ($title) {
            $proc = Get-Process | Where-Object { $_.MainWindowTitle -like "*$title*" } | Select-Object -First 1
            if ($proc) {
                return $proc.MainWindowHandle
            }
        }
        $activeWindow = [System.Runtime.InteropServices.Marshal]::GetActiveObject("Shell.Application")
        return [IntPtr]::Zero
    }
    
    [hashtable] GetWindowBounds([IntPtr]$hwnd) {
        $rect = New-Object System.Runtime.InteropServices.Structures.RECT
        [System.Runtime.InteropServices.Marshal]::PtrToStructure(
            (Add-Type -MemberDefinition '[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, ref RECT lpRect);' -Name "Win32" -Namespace "Win32API" -PassThru)::GetWindowRect($hwnd, [ref]$rect),
            [System.Runtime.InteropServices.Structures.RECT]
        )
        return @{
            Width = $rect.Right - $rect.Left
            Height = $rect.Bottom - $rect.Top
            Left = $rect.Left
            Top = $rect.Top
            Right = $rect.Right
            Bottom = $rect.Bottom
        }
    }
    
    [hashtable] SavePreset([string]$name) {
        $this.Telemetry?.IncrementCounter("window.presets_saved", 1)
        $preset = @{
            id = [guid]::NewGuid().ToString()
            name = $name
            createdAt = (Get-Date).ToString("o")
            windows = @()
        }
        $windows = Get-Process | Where-Object { $_.MainWindowHandle -ne 0 -and $_.MainWindowTitle } | Select-Object -First 10
        foreach ($w in $windows) {
            $bounds = $this.GetWindowBounds($w.MainWindowHandle)
            $preset.windows += @{
                processName = $w.ProcessName
                title = $w.MainWindowTitle
                bounds = $bounds
            }
        }
        $this.Presets += $preset
        $this.SavePresets()
        return $preset
    }
    
    [void] ApplyPreset([string]$presetId) {
        $this.Telemetry?.IncrementCounter("window.presets_applied", 1)
        $preset = $this.Presets | Where-Object { $_.id -eq $presetId } | Select-Object -First 1
        if (-not $preset) { return }
        foreach ($w in $preset.windows) {
            $proc = Get-Process | Where-Object { $_.ProcessName -eq $w.processName -and $_.MainWindowTitle -like "*$($w.title)*" } | Select-Object -First 1
            if ($proc) {
                $b = $w.bounds
                $this.SetWindowPosition($proc.MainWindowHandle, $b.left, $b.top, $b.width, $b.height)
            }
        }
    }
    
    [void] DeletePreset([string]$presetId) {
        $this.Presets = @($this.Presets | Where-Object { $_.id -ne $presetId })
        $this.SavePresets()
    }
    
    [void] ShowWindowPicker() {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $form = New-Object System.Windows.Forms.Form
        $form.Text = "Desktop Goose - Window Manager"
        $form.Size = New-Object System.Drawing.Size(500, 400)
        $form.StartPosition = "CenterScreen"
        $form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 35)
        $title = New-Object System.Windows.Forms.Label
        $title.Text = "Window Manager"
        $title.Font = New-Object System.Drawing.Font("Segoe UI", 14, [System.Drawing.FontStyle]::Bold)
        $title.Location = New-Object System.Drawing.Point(20, 20)
        $title.Size = New-Object System.Drawing.Size(300, 30)
        $title.ForeColor = [System.Drawing.Color]::White
        $form.Controls.Add($title)
        $snapPanel = New-Object System.Windows.Forms.GroupBox
        $snapPanel.Text = "Snap Actions"
        $snapPanel.Location = New-Object System.Drawing.Point(20, 60)
        $snapPanel.Size = New-Object System.Drawing.Size(220, 150)
        $snapPanel.ForeColor = [System.Drawing.Color]::White
        $snapPanel.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
        $form.Controls.Add($snapPanel)
        $btnSnapLeft = New-Object System.Windows.Forms.Button
        $btnSnapLeft.Text = "Snap Left"
        $btnSnapLeft.Location = New-Object System.Drawing.Point(10, 25)
        $btnSnapLeft.Size = New-Object System.Drawing.Size(95, 35)
        $btnSnapLeft.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
        $btnSnapLeft.ForeColor = [System.Drawing.Color]::White
        $btnSnapLeft.FlatStyle = "Flat"
        $btnSnapLeft.Add_Click({ $this.SnapLeft(); $form.Close() })
        $snapPanel.Controls.Add($btnSnapLeft)
        $btnSnapRight = New-Object System.Windows.Forms.Button
        $btnSnapRight.Text = "Snap Right"
        $btnSnapRight.Location = New-Object System.Drawing.Point(115, 25)
        $btnSnapRight.Size = New-Object System.Drawing.Size(95, 35)
        $btnSnapRight.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
        $btnSnapRight.ForeColor = [System.Drawing.Color]::White
        $btnSnapRight.FlatStyle = "Flat"
        $btnSnapRight.Add_Click({ $this.SnapRight(); $form.Close() })
        $snapPanel.Controls.Add($btnSnapRight)
        $btnTileAll = New-Object System.Windows.Forms.Button
        $btnTileAll.Text = "Tile All"
        $btnTileAll.Location = New-Object System.Drawing.Point(10, 70)
        $btnTileAll.Size = New-Object System.Drawing.Size(200, 35)
        $btnTileAll.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 80)
        $btnTileAll.ForeColor = [System.Drawing.Color]::White
        $btnTileAll.FlatStyle = "Flat"
        $btnTileAll.Add_Click({ $this.TileAllWindows(); $form.Close() })
        $snapPanel.Controls.Add($btnTileAll)
        $btnMaximize = New-Object System.Windows.Forms.Button
        $btnMaximize.Text = "Maximize"
        $btnMaximize.Location = New-Object System.Drawing.Point(10, 115)
        $btnMaximize.Size = New-Object System.Drawing.Size(95, 30)
        $btnMaximize.BackColor = [System.Drawing.Color]::FromArgb(180, 150, 0)
        $btnMaximize.ForeColor = [System.Drawing.Color]::White
        $btnMaximize.FlatStyle = "Flat"
        $btnMaximize.Add_Click({ $this.MaximizeWindow(); $form.Close() })
        $snapPanel.Controls.Add($btnMaximize)
        $btnMinimize = New-Object System.Windows.Forms.Button
        $btnMinimize.Text = "Minimize"
        $btnMinimize.Location = New-Object System.Drawing.Point(115, 115)
        $btnMinimize.Size = New-Object System.Drawing.Size(95, 30)
        $btnMinimize.BackColor = [System.Drawing.Color]::FromArgb(100, 100, 105)
        $btnMinimize.ForeColor = [System.Drawing.Color]::White
        $btnMinimize.FlatStyle = "Flat"
        $btnMinimize.Add_Click({ $this.MinimizeWindow(); $form.Close() })
        $snapPanel.Controls.Add($btnMinimize)
        $presetsPanel = New-Object System.Windows.Forms.GroupBox
        $presetsPanel.Text = "Saved Presets"
        $presetsPanel.Location = New-Object System.Drawing.Point(260, 60)
        $presetsPanel.Size = New-Object System.Drawing.Size(220, 280)
        $presetsPanel.ForeColor = [System.Drawing.Color]::White
        $presetsPanel.BackColor = [System.Drawing.Color]::FromArgb(50, 50, 55)
        $form.Controls.Add($presetsPanel)
        $btnSavePreset = New-Object System.Windows.Forms.Button
        $btnSavePreset.Text = "+ Save Current Layout"
        $btnSavePreset.Location = New-Object System.Drawing.Point(10, 25)
        $btnSavePreset.Size = New-Object System.Drawing.Size(200, 35)
        $btnSavePreset.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 80)
        $btnSavePreset.ForeColor = [System.Drawing.Color]::White
        $btnSavePreset.FlatStyle = "Flat"
        $presetsPanel.Controls.Add($btnSavePreset)
        $y = 70
        foreach ($preset in $this.Presets) {
            $btnPreset = New-Object System.Windows.Forms.Button
            $btnPreset.Text = $preset.name
            $btnPreset.Location = New-Object System.Drawing.Point(10, $y)
            $btnPreset.Size = New-Object System.Drawing.Size(200, 35)
            $btnPreset.Tag = $preset.id
            $btnPreset.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
            $btnPreset.ForeColor = [System.Drawing.Color]::White
            $btnPreset.FlatStyle = "Flat"
            $btnPreset.Add_Click({
                $this.ApplyPreset($this.Tag)
                $form.Close()
            })
            $presetsPanel.Controls.Add($btnPreset)
            $y += 40
        }
        $btnClose = New-Object System.Windows.Forms.Button
        $btnClose.Text = "Close"
        $btnClose.Location = New-Object System.Drawing.Point(190, 350)
        $btnClose.Size = New-Object System.Drawing.Size(100, 35)
        $btnClose.BackColor = [System.Drawing.Color]::FromArgb(180, 60, 60)
        $btnClose.ForeColor = [System.Drawing.Color]::White
        $btnClose.FlatStyle = "Flat"
        $btnClose.Add_Click({ $form.Close() })
        $form.Controls.Add($btnClose)
        $form.ShowDialog()
    }
    
    [array] GetPresets() {
        return $this.Presets
    }
}

$gooseWindowManager = $null

function Get-WindowManager {
    param([object]$Telemetry = $null)
    if ($script:gooseWindowManager -eq $null) {
        $script:gooseWindowManager = [GooseWindowManager]::new("config.ini", $Telemetry)
    }
    return $script:gooseWindowManager
}

function Show-WindowManager {
    $wm = Get-WindowManager
    $wm.ShowWindowPicker()
}

function Save-WindowPreset {
    param([string]$Name)
    $wm = Get-WindowManager
    return $wm.SavePreset($Name)
}

function Invoke-WindowTileAll {
    $wm = Get-WindowManager
    $wm.TileAllWindows()
}

Write-Host "Window Manager Module Initialized"
