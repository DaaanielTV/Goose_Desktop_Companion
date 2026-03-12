# Developer Documentation

## Overview

Desktop Goose Enhanced Edition features a modular PowerShell-based architecture with 78+ modules. This guide covers how to create, test, and integrate new modules.

## Module Structure

### Basic Template

```powershell
# Module Name: YourModuleName
# Description: What your module does

class GooseYourModule {
    [hashtable]$Config
    [type]$Property1
    [type]$Property2
    
    # Constructor
    GooseYourModule() {
        $this.Config = $this.LoadConfig()
        # Initialize properties
        $this.LoadData()
    }
    
    # Configuration loading (required)
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
        
        # Set defaults
        if (-not $this.Config.ContainsKey("YourModuleEnabled")) {
            $this.Config["YourModuleEnabled"] = $false
        }
        
        return $this.Config
    }
    
    # Data persistence (optional)
    [void] LoadData() {
        $dataFile = "goose_yourmodule.json"
        
        if (Test-Path $dataFile) {
            try {
                $data = Get-Content $dataFile -Raw | ConvertFrom-Json
                # Load properties from JSON
            } catch {}
        }
    }
    
    [void] SaveData() {
        $data = @{
            # Save properties to JSON
            "LastSaved" = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Set-Content "goose_yourmodule.json"
    }
    
    # Core methods
    [returnType] YourMethod() {
        # Implementation
    }
    
    # State (required)
    [hashtable] GetYourModuleState() {
        return @{
            "Enabled" = $this.Config["YourModuleEnabled"]
            # Return current state
        }
    }
}

# Create singleton
$gooseYourModule = [GooseYourModule]::new()

# Export functions (required)
function Get-GooseYourModule {
    return $gooseYourModule
}

# Module initialization output
Write-Host "Desktop Goose Your Module Initialized"
$state = Get-YourModuleState
Write-Host "Your Module Enabled: $($state['Enabled'])"
```

### Configuration Pattern

Always include these settings in your LoadConfig method:

```powershell
if (-not $this.Config.ContainsKey("YourModuleEnabled")) {
    $this.Config["YourModuleEnabled"] = $false
}
```

### Adding Config to config.ini

Add a new section:
```ini
# Your Module
YourModuleEnabled=False
YourModuleSetting1=value1
YourModuleSetting2=value2
```

## Naming Conventions

### Files
- Module: `goose-[modulename].ps1`
- Data: `goose_[modulename].json`
- Test: `test-[modulename].ps1`

### Functions
- Get module: `Get-Goose[Module]`
- Start: `Start-[Module]`
- Stop: `Stop-[Module]`
- Get state: `Get-[Module]State`
- Enable: `Enable-[Module]`
- Disable: `Disable-[Module]`

### Variables
- Class property: `$this.PropertyName`
- Local variable: `$localVar`
- Function parameter: `$ParamName`

## Best Practices

### Error Handling
```powershell
try {
    # Risky operation
} catch {
    Write-Host "Error: $($_.Exception.Message)"
    # Handle gracefully
}
```

### Type Safety
```powershell
# Always use explicit types
[hashtable]$config = @{}
[array]$items = @()
[int]$count = 0
[string]$name = ""
[bool]$enabled = $false
```

### Variable Naming in Loops
Avoid naming conflicts with class properties:
```powershell
# BAD - conflicts with $this.Blocks
$blocks = @()
foreach ($block in $this.Blocks.Values) { }

# GOOD - use different name
$result = @()
foreach ($block in $this.Blocks.Values) { }
```

### Method Return Types
```powershell
# Return hashtable for complex data
[hashtable] GetState() { ... }

# Return array for lists
[hashtable[]] GetItems() { ... }

# Return bool for boolean operations
[bool] DeleteItem($id) { ... }
```

### Optional Parameters
```powershell
function DoSomething {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RequiredParam,
        [string]$OptionalParam = "default",
        $Module = $gooseModule  # Allow injection for testing
    )
}
```

## Testing

### Manual Testing
```powershell
# Run module
powershell -ExecutionPolicy Bypass -File "path/to/module.ps1"

# Test functions
$module = Get-ModuleName
$module.YourMethod()
$state = Get-ModuleState
$state.Enabled
```

### Test Script Pattern
```powershell
# test-yourmodule.ps1

# Load module
. "./goose-yourmodule.ps1"

# Test enable/disable
Enable-YourModule
$state = Get-YourModuleState
if (-not $state.Enabled) { 
    Write-Host "FAIL: Module not enabled"
    exit 1 
}

# Test methods
$result = $module.YourMethod()
if (-not $result.Success) {
    Write-Host "FAIL: Method failed"
    exit 1
}

Write-Host "PASS: All tests passed"
exit 0
```

## Integration

### Adding to run-all.ps1
```powershell
# Add at the end
& "$PSScriptRoot\YourModule\goose-yourmodule.ps1"
```

### Module Categories
Place modules in appropriate folders:
- `Widgets/` - Desktop widgets
- `Productivity/` - Task/ productivity tools
- `System/` - System integration
- `Health/` - Wellness features
- `Fun/` - Entertainment
- `Social/` - Social features

## Common Patterns

### Timer/Countdown
```powershell
[datetime]$NextTrigger
[int]$IntervalMinutes

[bool] ShouldTrigger() {
    return (Get-Date) -ge $this.NextTrigger
}

[void] Trigger() {
    # Do something
    $this.NextTrigger = (Get-Date).AddMinutes($this.IntervalMinutes)
}
```

### History with Limits
```powershell
[array]$History
[int]$MaxItems = 50

[void] AddToHistory($item) {
    $this.History = @($item) + $this.History
    if ($this.History.Count -gt $this.MaxItems) {
        $this.History = $this.History[0..($this.MaxItems - 1)]
    }
}
```

### External API Calls
```powershell
[hashtable] FetchData() {
    try {
        $response = Invoke-RestMethod -Uri $url -TimeoutSec 10
        return @{
            "success" = $true
            "data" = $response
        }
    } catch {
        return @{
            "success" = $false
            "error" = $_.Exception.Message
        }
    }
}
```

## Troubleshooting

### Parser Errors
- Check variable naming conflicts
- Verify return types match
- Ensure all paths are correct

### Null Reference
- Initialize collections: `@()` not `null`
- Check if file exists before reading
- Validate JSON structure

### Type Conversion
- Use explicit casts: `[int]$value`, `[bool]$value`
- Handle null values: `$null -ne $value`

## Documentation

### Module Header
```powershell
# Desktop Goose Your Module
# Description of what the module does
# Dependencies (if any)
```

### Function Help
```powershell
function Your-Function {
    <#
    .SYNOPSIS
        Brief description
    
    .DESCRIPTION
        Detailed description
    
    .PARAMETER ParamName
        Parameter description
    
    .EXAMPLE
        Example usage
    
    #>
    param(...)
}
```

---

## API Reference

See [API-REFERENCE.md](API-REFERENCE.md) for detailed API documentation.

## Examples

See existing modules for complete examples:
- `Widgets/goose-stockticker.ps1` - API integration
- `Health/goose-eyestrain.ps1` - Timer system
- `Social/goose-petinteractions.ps1` - Game mechanics
- `System/goose-clipboard.ps1` - History management
