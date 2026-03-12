# Desktop Goose Core System
# Unified module combining: Behavior, Context, Animations, Personality, Productivity

$TelemetryScriptPath = Join-Path $PSScriptRoot "..\System\goose-telemetry.ps1"
if (Test-Path $TelemetryScriptPath) {
    . $TelemetryScriptPath
}

$LoggingScriptPath = Join-Path $PSScriptRoot "GooseLogging.ps1"
if (Test-Path $LoggingScriptPath) {
    . $LoggingScriptPath
}

class GooseConfig {
    static [hashtable] Load([string]$configFile = "config.ini") {
        $config = @{}
        if (Test-Path $configFile) {
            Get-Content $configFile | ForEach-Object {
                if ($_ -match '^([^=]+)=(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    if ($value -eq 'True' -or $value -eq 'False') {
                        $config[$key] = [bool]$value
                    } elseif ($value -match '^\d+$') {
                        $config[$key] = [int]$value
                    } elseif ($value -match '^\d+\.\d+$') {
                        $config[$key] = [double]$value
                    } else {
                        $config[$key] = $value
                    }
                }
            }
        }
        return $config
    }
}

class GooseBehavior {
    [hashtable]$Config
    [datetime]$StartTime
    [int]$InteractionCount
    [hashtable]$Personality
    [hashtable]$ApplicationMemory
    
    GooseBehavior([hashtable]$config) {
        $this.Config = $config
        $this.StartTime = Get-Date
        $this.InteractionCount = 0
        $this.Personality = @{
            "Energy" = 1.0; "Curiosity" = 0.8; "Friendliness" = 0.9; "Playfulness" = 0.7
        }
        $this.ApplicationMemory = @{}
    }
    
    [bool] IsWorkHours() {
        if (-not $this.Config["TimeBasedBehavior"]) { return $true }
        $currentHour = (Get-Date).Hour
        return ($currentHour -ge $this.Config["WorkHoursStart"] -and $currentHour -lt $this.Config["WorkHoursEnd"])
    }
    
    [bool] IsWeekend() {
        if (-not $this.Config["WeekendMode"]) { return $false }
        $dayOfWeek = (Get-Date).DayOfWeek
        return ($dayOfWeek -eq "Saturday" -or $dayOfWeek -eq "Sunday")
    }
    
    [bool] ShouldBeQuiet() {
        if ($this.Config["MeetingQuietMode"]) {
            $meetingApps = @("Zoom", "Teams", "Skype", "WebEx")
            foreach ($app in $meetingApps) {
                if (Get-Process -Name $app -ErrorAction SilentlyContinue) { return $true }
            }
        }
        if ($this.Config["FullscreenFocusMode"]) {
            Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public class User32 {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
}
public struct RECT { public int Left, Top, Right, Bottom; }
"@
            $hwnd = [User32]::GetForegroundWindow()
            if ($hwnd -ne [IntPtr]::Zero) {
                $windowRect = New-Object RECT
                if ([User32]::GetWindowRect($hwnd, [ref]$windowRect)) {
                    $ww = $windowRect.Right - $windowRect.Left
                    $wh = $windowRect.Bottom - $windowRect.Top
                    $sw = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
                    $sh = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
                    if ($ww -ge ($sw * 0.9) -and $wh -ge ($sh * 0.9)) { return $true }
                }
            }
        }
        return $false
    }
    
    [double] GetActivityLevel() {
        $baseLevel = 1.0
        if ($this.IsWorkHours()) { $baseLevel *= $this.Config["WorkHourActivityLevel"] }
        if ($this.IsWeekend()) { $baseLevel *= $this.Config["WeekendActivityLevel"] }
        if ($this.ShouldBeQuiet()) { $baseLevel *= 0.3 }
        $baseLevel *= $this.Personality["Energy"]
        return [Math]::Max(0.1, [Math]::Min(2.0, $baseLevel))
    }
    
    [void] RecordInteraction([string]$type) {
        $this.InteractionCount++
        switch ($type) {
            "mouse_click" { $this.Personality["Curiosity"] = [Math]::Min(1.0, $this.Personality["Curiosity"] + 0.01) }
            "ignore" { $this.Personality["Energy"] = [Math]::Max(0.3, $this.Personality["Energy"] - 0.02) }
            "pet" { $this.Personality["Friendliness"] = [Math]::Min(1.0, $this.Personality["Friendliness"] + 0.05) }
        }
    }
    
    [string] GetSuggestedAction() {
        if ($this.ShouldBeQuiet()) { return "rest_quietly" }
        $al = $this.GetActivityLevel()
        if ($al -lt 0.5) { return "rest_or_sleep" }
        if ($al -gt 1.5) { return "play_or_explore" }
        return "normal_wandering"
    }
    
    [hashtable] GetReport() {
        return @{
            "CurrentActivityLevel" = $this.GetActivityLevel()
            "IsWorkHours" = $this.IsWorkHours()
            "IsWeekend" = $this.IsWeekend()
            "ShouldBeQuiet" = $this.ShouldBeQuiet()
            "SuggestedAction" = $this.GetSuggestedAction()
            "InteractionCount" = $this.InteractionCount
            "Personality" = $this.Personality.Clone()
        }
    }
}

class GooseContext {
    [hashtable]$Config
    [hashtable]$CurrentContext
    [datetime]$LastActivity
    [string]$LastActiveApplication
    
    GooseContext([hashtable]$config) {
        $this.Config = $config
        $this.CurrentContext = @{}
        $this.LastActivity = Get-Date
        $this.LastActiveApplication = ""
        $this.UpdateContext()
    }
    
    [string] GetTimeOfDay() {
        $h = (Get-Date).Hour
        if ($h -ge 6 -and $h -lt 9) { return "Early Morning" }
        if ($h -ge 9 -and $h -lt 12) { return "Morning" }
        if ($h -ge 12 -and $h -lt 14) { return "Lunch" }
        if ($h -ge 14 -and $h -lt 17) { return "Afternoon" }
        if ($h -ge 17 -and $h -lt 20) { return "Evening" }
        if ($h -ge 20 -and $h -lt 23) { return "Night" }
        return "Late Night"
    }
    
    [string] GetActiveApplication() {
        try {
            Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices; using System.Text;
public class User32 {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] public static extern int GetWindowText(IntPtr hWnd, StringBuilder text, int count);
    [DllImport("user32.dll")] public static extern IntPtr GetWindowThreadProcessId(IntPtr hWnd, out IntPtr processId);
}
"@
            $hwnd = [User32]::GetForegroundWindow()
            if ($hwnd -ne [IntPtr]::Zero) {
                $pid = [IntPtr]::Zero
                [User32]::GetWindowThreadProcessId($hwnd, [ref]$pid)
                if ($pid -ne [IntPtr]::Zero) {
                    $proc = Get-Process -Id $pid -ErrorAction SilentlyContinue
                    if ($proc) { return $proc.ProcessName }
                }
            }
        } catch { return "Unknown" }
        return "Unknown"
    }
    
    [bool] IsFullscreenApplication() {
        try {
            Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public class User32 {
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
}
public struct RECT { public int Left, Top, Right, Bottom; }
"@
            $hwnd = [User32]::GetForegroundWindow()
            if ($hwnd -ne [IntPtr]::Zero) {
                $rect = New-Object RECT
                if ([User32]::GetWindowRect($hwnd, [ref]$rect)) {
                    $w = $rect.Right - $rect.Left
                    $h = $rect.Bottom - $rect.Top
                    $sw = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
                    $sh = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
                    return ($w -ge ($sw * 0.95) -and $h -ge ($sh * 0.95))
                }
            }
        } catch { return $false }
        return $false
    }
    
    [bool] IsInMeeting() {
        if (-not $this.Config["MeetingQuietMode"]) { return $false }
        $app = $this.GetActiveApplication()
        $keywords = @("zoom", "teams", "skype", "meet", "webex", "jabber")
        foreach ($kw in $keywords) { if ($app -like "*$kw*") { return $true } }
        return $false
    }
    
    [bool] IsUserActive() { return $true }
    
    [void] UpdateContext() {
        $this.CurrentContext["TimeOfDay"] = $this.GetTimeOfDay()
        $this.CurrentContext["DayOfWeek"] = (Get-Date).DayOfWeek.ToString()
        $this.CurrentContext["IsActive"] = $this.IsUserActive()
        $this.CurrentContext["CurrentApplication"] = $this.GetActiveApplication()
        $this.CurrentContext["IsFullscreen"] = $this.IsFullscreenApplication()
        $this.CurrentContext["IsMeeting"] = $this.IsInMeeting()
        $this.CurrentContext["FocusLevel"] = if ($this.IsFullscreenApplication() -or $this.IsInMeeting()) { "High" } else { "Normal" }
    }
    
    [hashtable] GetContext() {
        $this.UpdateContext()
        return $this.CurrentContext.Clone()
    }
}

class GooseAnimations {
    [hashtable]$Config
    [hashtable]$CurrentState
    [hashtable]$AnimationQueue
    [int]$FrameCount
    
    GooseAnimations([hashtable]$config) {
        $this.Config = $config
        $this.CurrentState = @{
            "Position" = @{ "X" = 100; "Y" = 100 }
            "Rotation" = 0; "Scale" = 1.0; "Opacity" = 1.0
            "CurrentAnimation" = "idle"; "AnimationFrame" = 0
            "Mood" = "neutral"; "Energy" = 1.0
            "IsBreathing" = $true; "BreatheOffset" = 0
            "EyeDirection" = "forward"; "BlinkTimer" = 0; "IsBlinking" = $false
        }
        $this.AnimationQueue = @{}
        $this.FrameCount = 0
    }
    
    [void] UpdatePosition([int]$x, [int]$y) {
        $this.CurrentState["Position"]["X"] = $x
        $this.CurrentState["Position"]["Y"] = $y
        if ($this.Config["SubtleAnimations"]) { $this.QueueAnimation("walk_subtle", 0.5) }
    }
    
    [void] UpdateMood([string]$mood) {
        $this.CurrentState["Mood"] = $mood
        switch ($mood) {
            "happy" { $this.CurrentState["Energy"] = [Math]::Min(1.2, $this.CurrentState["Energy"] + 0.1); $this.QueueAnimation("happy_bounce", 0.3) }
            "sleepy" { $this.CurrentState["Energy"] = [Math]::Max(0.3, $this.CurrentState["Energy"] - 0.2); $this.QueueAnimation("sleepy_yawn", 1.0) }
            "curious" { $this.QueueAnimation("head_tilt", 0.8); $this.CurrentState["EyeDirection"] = "looking_around" }
            "startled" { $this.QueueAnimation("quick_jump", 0.2); $this.CurrentState["Energy"] = 1.5 }
        }
    }
    
    [void] QueueAnimation([string]$type, [double]$duration) {
        if (-not $this.Config["SubtleAnimations"]) { return }
        $this.AnimationQueue[$type] = @{ "StartTime" = Get-Date; "Duration" = $duration; "Progress" = 0.0 }
    }
    
    [hashtable] ProcessAnimations() {
        if ($this.CurrentState["IsBreathing"]) {
            $this.CurrentState["BreatheOffset"] = [Math]::Sin($this.FrameCount * 0.05) * 2
        }
        $this.CurrentState["BlinkTimer"]++
        if ($this.CurrentState["BlinkTimer"] -gt 300) {
            $this.CurrentState["IsBlinking"] = $true
            $this.CurrentState["BlinkTimer"] = 0
        } elseif ($this.CurrentState["IsBlinking"] -and $this.CurrentState["BlinkTimer"] -gt 5) {
            $this.CurrentState["IsBlinking"] = $false
        }
        $this.FrameCount++
        return @{ "CurrentState" = $this.CurrentState.Clone(); "FrameCount" = $this.FrameCount }
    }
    
    [hashtable] GetVisualState() {
        $this.ProcessAnimations()
        return @{
            "Position" = $this.CurrentState["Position"]
            "VerticalOffset" = $this.CurrentState["BreatheOffset"]
            "Mood" = $this.CurrentState["Mood"]
            "Energy" = $this.CurrentState["Energy"]
            "IsBlinking" = $this.CurrentState["IsBlinking"]
        }
    }
}

class GoosePersonality {
    [hashtable]$Config
    [hashtable]$PersonalityTraits
    [hashtable]$InteractionHistory
    [datetime]$PersonalityStartTime
    [int]$TotalInteractions
    
    GoosePersonality([hashtable]$config) {
        $this.Config = $config
        $this.PersonalityTraits = @{
            "Energy" = 0.8; "Curiosity" = 0.7; "Friendliness" = 0.9; "Playfulness" = 0.6
            "Laziness" = 0.3; "Bravery" = 0.5; "Intelligence" = 0.7; "Patience" = 0.6
            "Mischievousness" = 0.4; "Loyalty" = 0.8
            "Happiness" = 0.7; "Excitement" = 0.5; "Calmness" = 0.6; "Anxiety" = 0.2; "Trust" = 0.7
        }
        $this.InteractionHistory = @{}
        $this.PersonalityStartTime = Get-Date
        $this.TotalInteractions = 0
    }
    
    [void] RecordInteraction([string]$type, [hashtable]$context = @{}) {
        if (-not $this.Config["PersonalitySystem"]) { return }
        $this.TotalInteractions++
        $key = "{0:yyyyMMddHHmmss}" -f (Get-Date)
        $this.InteractionHistory[$key] = @{ "Type" = $type; "Timestamp" = Get-Date; "Context" = $context }
        switch ($type) {
            "mouse_click" { $this.AdjustTrait("Curiosity", 0.01); $this.AdjustTrait("Playfulness", 0.005) }
            "pet" { $this.AdjustTrait("Friendliness", 0.02); $this.AdjustTrait("Happiness", 0.015) }
            "scare" { $this.AdjustTrait("Anxiety", 0.02); $this.AdjustTrait("Trust", -0.01) }
        }
    }
    
    [void] AdjustTrait([string]$trait, [double]$amount) {
        if (-not $this.PersonalityTraits.ContainsKey($trait)) { return }
        $this.PersonalityTraits[$trait] = [Math]::Max(0.0, [Math]::Min(1.0, $this.PersonalityTraits[$trait] + $amount))
    }
    
    [string] GetPersonalityType() {
        $e = $this.PersonalityTraits["Energy"]; $f = $this.PersonalityTraits["Friendliness"]; $p = $this.PersonalityTraits["Playfulness"]
        if ($e -gt 0.7 -and $p -gt 0.7) { return "Energetic Playful" }
        if ($f -gt 0.8 -and $e -lt 0.5) { return "Gentle Companion" }
        if ($this.PersonalityTraits["Mischievousness"] -gt 0.7) { return "Playful Trickster" }
        return "Balanced Companion"
    }
    
    [hashtable] GetReport() {
        return @{
            "PersonalityType" = $this.GetPersonalityType()
            "TotalInteractions" = $this.TotalInteractions
            "DaysTogether" = ((Get-Date) - $this.PersonalityStartTime).Days
            "CoreTraits" = $this.PersonalityTraits.Clone()
            "TrustLevel" = $this.PersonalityTraits["Trust"]
            "HappinessLevel" = $this.PersonalityTraits["Happiness"]
        }
    }
}

class GooseProductivity {
    [hashtable]$Config
    [datetime]$SessionStart
    [datetime]$LastBreak
    [hashtable]$ProductivityStats
    
    GooseProductivity([hashtable]$config) {
        $this.Config = $config
        $this.SessionStart = Get-Date
        $this.LastBreak = Get-Date
        $this.ProductivityStats = @{
            "TotalWorkTime" = 0; "TotalBreakTime" = 0; "BreaksTaken" = 0
            "ProductiveSessions" = 0; "CurrentStreak" = 0
        }
    }
    
    [void] UpdateActivity([hashtable]$context) {
        if (-not $this.Config["ProductivityReminders"]) { return }
        if ($context["IsActive"] -and -not $context["IsMeeting"]) {
            $this.ProductivityStats["TotalWorkTime"]++
        }
    }
    
    [bool] ShouldRemind([string]$type) {
        if (-not $this.Config["ProductivityReminders"]) { return $false }
        $interval = $this.Config["BreakReminderMinutes"]
        if (-not $interval) { $interval = 60 }
        $elapsed = ((Get-Date) - $this.LastBreak).TotalMinutes
        if ($elapsed -ge $interval) { return $true }
        return $false
    }
    
    [void] RecordBreak() {
        $this.LastBreak = Get-Date
        $this.ProductivityStats["BreaksTaken"]++
    }
    
    [hashtable] GetStats() {
        return $this.ProductivityStats.Clone()
    }
}

class GooseCore {
    [hashtable]$Config
    [GooseBehavior]$Behavior
    [GooseContext]$Context
    [GooseAnimations]$Animations
    [GoosePersonality]$Personality
    [GooseProductivity]$Productivity
    
    GooseCore([string]$configFile = "config.ini") {
        $this.Config = GooseConfig::Load($configFile)
        $this.Behavior = [GooseBehavior]::new($this.Config)
        $this.Context = [GooseContext]::new($this.Config)
        $this.Animations = [GooseAnimations]::new($this.Config)
        $this.Personality = [GoosePersonality]::new($this.Config)
        $this.Productivity = [GooseProductivity]::new($this.Config)
    }
    
    [void] Update() {
        $ctx = $this.Context.GetContext()
        $this.Productivity.UpdateActivity($ctx)
        $this.Animations.ProcessAnimations()
        
        if ($gooseTelemetry -and $gooseTelemetry.Config["Enabled"]) {
            $gooseTelemetry.RecordGooseMetrics($this.GetFullState())
            if ((Get-Random -Minimum 0 -Maximum 100) -lt 5) {
                $gooseTelemetry.RecordSystemMetrics()
            }
            if ($gooseTelemetry.ShouldSync()) {
                $syncResult = $gooseTelemetry.SyncToSupabase()
                if ($syncResult.Success) {
                    $gooseTelemetry.RecordLog([TelemetryLog]::new("info", "Telemetry synced: $($syncResult.MetricsUploaded) metrics, $($syncResult.SpansUploaded) spans, $($syncResult.LogsUploaded) logs", "GooseCore"))
                }
            }
        }
    }
    
    [hashtable] GetFullState() {
        return @{
            "Behavior" = $this.Behavior.GetReport()
            "Context" = $this.Context.GetContext()
            "Visual" = $this.Animations.GetVisualState()
            "Personality" = $this.Personality.GetReport()
            "Productivity" = $this.Productivity.GetStats()
        }
    }
}

$gooseCore = [GooseCore]::new()

function Get-GooseCore { return $gooseCore }
function Get-GooseState { param($Core = $gooseCore); return $Core.GetFullState() }
function Update-GooseCore { param($Core = $gooseCore); $Core.Update() }
function Get-ActivityLevel { param($Core = $gooseCore); return $Core.Behavior.GetActivityLevel() }
function Should-BeQuiet { param($Core = $gooseCore); return $Core.Behavior.ShouldBeQuiet() }
function Get-CurrentContext { param($Core = $gooseCore); return $Core.Context.GetContext() }
function Set-GooseMood { param([string]$Mood, $Core = $gooseCore); $Core.Animations.UpdateMood($Mood) }
function Get-VisualState { param($Core = $gooseCore); return $Core.Animations.GetVisualState() }
function Record-Interaction { param([string]$Type, $Core = $gooseCore); $Core.Personality.RecordInteraction($Type) }
function Get-PersonalityReport { param($Core = $gooseCore); return $Core.Personality.GetReport() }

Write-Host "Desktop Goose Core System Initialized"
Write-LogInfo -Message "Desktop Goose Core System Initialized" -Source "GooseCore"
Write-LogInfo -Message "Activity Level: $(Get-ActivityLevel)" -Source "GooseCore"
Write-LogInfo -Message "Suggested Action: $($gooseCore.Behavior.GetSuggestedAction())" -Source "GooseCore"
