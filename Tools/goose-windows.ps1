# Desktop Goose Window Management System
# Minimize/restore windows

class GooseWindowManager {
    [hashtable]$Config
    [array]$WindowHistory
    
    GooseWindowManager() {
        $this.Config = $this.LoadConfig()
        $this.WindowHistory = @()
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
        
        if (-not $this.Config.ContainsKey("WindowManagementEnabled")) {
            $this.Config["WindowManagementEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [array] GetOpenWindows() {
        $windows = @()
        
        Get-Process | Where-Object { $_.MainWindowTitle -ne "" } | ForEach-Object {
            $windows += @{
                "ProcessName" = $_.ProcessName
                "Title" = $_.MainWindowTitle
                "Handle" = $_.MainWindowHandle
            }
        }
        
        return $windows
    }
    
    [hashtable] MinimizeWindow([string]$processName) {
        try {
            $process = Get-Process -Name $processName -ErrorAction Stop
            $window = $process.MainWindowHandle
            
            if ($window -ne [IntPtr]::Zero) {
                Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WindowHelper {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    public const int SW_MINIMIZE = 6;
}
"@
                [WindowHelper]::ShowWindow($window, [WindowHelper]::SW_MINIMIZE) | Out-Null
                
                $this.WindowHistory += @{
                    "Action" = "minimize"
                    "ProcessName" = $processName
                    "Title" = $process.MainWindowTitle
                    "Timestamp" = (Get-Date).ToString("o")
                }
                
                return @{
                    "Success" = $true
                    "Message" = "Minimized $processName"
                }
            }
            
            return @{
                "Success" = $false
                "Message" = "No window found for $processName"
            }
        } catch {
            return @{
                "Success" = $false
                "Message" = "Error: $($_.Exception.Message)"
            }
        }
    }
    
    [hashtable] RestoreLastWindow() {
        if ($this.WindowHistory.Count -eq 0) {
            return @{
                "Success" = $false
                "Message" = "No window history"
            }
        }
        
        $lastAction = $this.WindowHistory[-1]
        
        try {
            $process = Get-Process -Name $lastAction.ProcessName -ErrorAction Stop
            $window = $process.MainWindowHandle
            
            if ($window -ne [IntPtr]::Zero) {
                Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WindowHelper {
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    public const int SW_RESTORE = 9;
}
"@
                [WindowHelper]::ShowWindow($window, [WindowHelper]::SW_RESTORE) | Out-Null
                
                return @{
                    "Success" = $true
                    "Message" = "Restored $($lastAction.ProcessName)"
                }
            }
            
            return @{
                "Success" = $false
                "Message" = "Window no longer available"
            }
        } catch {
            return @{
                "Success" = $false
                "Message" = "Error: $($_.Exception.Message)"
            }
        }
    }
    
    [hashtable] MinimizeAllWindows() {
        Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WindowHelper {
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern int GetWindowTextLength(IntPtr hWnd);
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, System.Text.StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    public const int SW_MINIMIZE = 6;
}
"@
        
        $minimized = 0
        
        $callback = {
            param($hwnd, $param)
            
            if ([WindowHelper]::IsWindowVisible($hwnd)) {
                $length = [WindowHelper]::GetWindowTextLength($hwnd)
                if ($length -gt 0) {
                    $sb = New-Object System.Text.StringBuilder($length + 1)
                    [WindowHelper]::GetWindowText($hwnd, $sb, $sb.Capacity) | Out-Null
                    $title = $sb.ToString()
                    
                    if ($title.Length -gt 0) {
                        [WindowHelper]::ShowWindow($hwnd, [WindowHelper]::SW_MINIMIZE) | Out-Null
                        $script:minimized++
                    }
                }
            }
            return $true
        }
        
        [WindowHelper]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null
        
        return @{
            "Success" = $true
            "MinimizedCount" = $minimized
            "Message" = "Minimized $minimized windows"
        }
    }
    
    [hashtable] GetWindowManagerState() {
        return @{
            "Enabled" = $this.Config["WindowManagementEnabled"]
            "OpenWindows" = $this.GetOpenWindows()
            "HistoryCount" = $this.WindowHistory.Count
            "LastAction" = if ($this.WindowHistory.Count -gt 0) { $this.WindowHistory[-1] } else { $null }
        }
    }
}

$gooseWindowManager = [GooseWindowManager]::new()

function Get-GooseWindowManager {
    return $gooseWindowManager
}

function Get-OpenWindows {
    param($Manager = $gooseWindowManager)
    return $Manager.GetOpenWindows()
}

function Minimize-Window {
    param(
        [string]$ProcessName,
        $Manager = $gooseWindowManager
    )
    return $Manager.MinimizeWindow($ProcessName)
}

function Restore-LastWindow {
    param($Manager = $gooseWindowManager)
    return $Manager.RestoreLastWindow()
}

function Minimize-AllWindows {
    param($Manager = $gooseWindowManager)
    return $Manager.MinimizeAllWindows()
}

function Get-WindowManagerState {
    param($Manager = $gooseWindowManager)
    return $Manager.GetWindowManagerState()
}

Write-Host "Desktop Goose Window Management System Initialized"
$state = Get-WindowManagerState
Write-Host "Window Management Enabled: $($state['Enabled'])"
Write-Host "Open Windows: $($state['OpenWindows'].Count)"
