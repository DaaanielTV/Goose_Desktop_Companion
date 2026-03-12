# Desktop Goose RPG Progression System
# Level up your goose with stats and unlockables

enum GooseStat {
    Mischief
    Intelligence
    Speed
    Chaos
}

enum UnlockableType {
    Animation
    Skin
    Ability
    Feature
}

class GooseStats {
    [int]$Mischief
    [int]$Intelligence
    [int]$Speed
    [int]$Chaos
    
    GooseStats() {
        $this.Mischief = 10
        $this.Intelligence = 10
        $this.Speed = 10
        $this.Chaos = 10
    }
    
    [int] GetAverage() {
        return [int](($this.Mischief + $this.Intelligence + $this.Speed + $this.Chaos) / 4)
    }
    
    [void] Increase([GooseStat]$stat, [int]$amount = 1) {
        switch ($stat) {
            ([GooseStat]::Mischief) { $this.Mischief = [Math]::Min(100, $this.Mischief + $amount) }
            ([GooseStat]::Intelligence) { $this.Intelligence = [Math]::Min(100, $this.Intelligence + $amount) }
            ([GooseStat]::Speed) { $this.Speed = [Math]::Min(100, $this.Speed + $amount) }
            ([GooseStat]::Chaos) { $this.Chaos = [Math]::Min(100, $this.Chaos + $amount) }
        }
    }
    
    [void] Decrease([GooseStat]$stat, [int]$amount = 1) {
        switch ($stat) {
            ([GooseStat]::Mischief) { $this.Mischief = [Math]::Max(0, $this.Mischief - $amount) }
            ([GooseStat]::Intelligence) { $this.Intelligence = [Math]::Max(0, $this.Intelligence - $amount) }
            ([GooseStat]::Speed) { $this.Speed = [Math]::Max(0, $this.Speed - $amount) }
            ([GooseStat]::Chaos) { $this.Chaos = [Math]::Max(0, $this.Chaos - $amount) }
        }
    }
}

class Unlockable {
    [string]$Id
    [string]$Name
    [string]$Description
    [UnlockableType]$Type
    [int]$RequiredLevel
    [bool]$Unlocked
    
    Unlockable([string]$id, [string]$name, [string]$desc, [UnlockableType]$type, [int]$level) {
        $this.Id = $id
        $this.Name = $name
        $this.Description = $desc
        $this.Type = $type
        $this.RequiredLevel = $level
        $this.Unlocked = $false
    }
}

class Achievement {
    [string]$Id
    [string]$Name
    [string]$Description
    [string]$Icon
    [int]$XPReward
    [bool]$Earned
    [datetime]$EarnedAt
    
    Achievement([string]$id, [string]$name, [string]$desc, [string]$icon, [int]$xp) {
        $this.Id = $id
        $this.Name = $name
        $this.Description = $desc
        $this.Icon = icon
        $this.XPReward = xp
        $this.Earned = $false
        $this.EarnedAt = [datetime]::MinValue
    }
}

class GooseRPG {
    [hashtable]$Config
    [GooseStats]$Stats
    [int]$Level
    [int]$XP
    [int]$TotalXP
    [System.Collections.ArrayList]$Unlockables
    [System.Collections.ArrayList]$Achievements
    [hashtable]$ActionHistory
    [string]$DataFile
    
    GooseRPG() {
        $this.Config = $this.LoadConfig()
        $this.Stats = [GooseStats]::new()
        $this.Level = 1
        $this.XP = 0
        $this.TotalXP = 0
        $this.Unlockables = [System.Collections.ArrayList]::new()
        $this.Achievements = [System.Collections.ArrayList]::new()
        $this.ActionHistory = @{}
        $this.DataFile = "goose_rpg.json"
        $this.LoadData()
        $this.InitializeUnlockables()
        $this.InitializeAchievements()
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
        
        if (-not $this.Config.ContainsKey("RPGEnabled")) {
            $this.Config["RPGEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] LoadData() {
        if (Test-Path $this.DataFile) {
            try {
                $data = Get-Content $this.DataFile -Raw | ConvertFrom-Json
                
                $this.Stats.Mischief = $data.stats.mischief
                $this.Stats.Intelligence = $data.stats.intelligence
                $this.Stats.Speed = $data.stats.speed
                $this.Stats.Chaos = $data.stats.chaos
                
                $this.Level = $data.level
                $this.XP = $data.xp
                $this.TotalXP = $data.totalXP
                
                if ($data.unlockables) {
                    $this.Unlockables.Clear()
                    foreach ($u in $data.unlockables) {
                        $unlock = [Unlockable]::new($u.id, $u.name, $u.description, [UnlockableType]$u.type, $u.requiredLevel)
                        $unlock.Unlocked = $u.unlocked
                        $this.Unlockables.Add($unlock)
                    }
                }
                
                if ($data.achievements) {
                    $this.Achievements.Clear()
                    foreach ($a in $data.achievements) {
                        $achievement = [Achievement]::new($a.id, $a.name, $a.description, $a.icon, $a.xpReward)
                        $achievement.Earned = $a.earned
                        if ($a.earnedAt) { $achievement.EarnedAt = [datetime]::Parse($a.earnedAt) }
                        $this.Achievements.Add($achievement)
                    }
                }
                
                if ($data.actionHistory) {
                    $this.ActionHistory = @{}
                    $data.actionHistory.PSObject.Properties | ForEach-Object {
                        $this.ActionHistory[$_.Name] = $_.Value
                    }
                }
            } catch {}
        }
    }
    
    [void] SaveData() {
        $data = @{
            stats = @{
                mischief = $this.Stats.Mischief
                intelligence = $this.Stats.Intelligence
                speed = $this.Stats.Speed
                chaos = $this.Stats.Chaos
            }
            level = $this.Level
            xp = $this.XP
            totalXP = $this.TotalXP
            unlockables = @($this.Unlockables | ForEach-Object {
                @{
                    id = $_.Id
                    name = $_.Name
                    description = $_.Description
                    type = $_.Type.ToString()
                    requiredLevel = $_.RequiredLevel
                    unlocked = $_.Unlocked
                }
            })
            achievements = @($this.Achievements | ForEach-Object {
                @{
                    id = $_.Id
                    name = $_.Name
                    description = $_.Description
                    icon = $_.Icon
                    xpReward = $_.XPReward
                    earned = $_.Earned
                    earnedAt = $_.EarnedAt.ToString("o")
                }
            })
            actionHistory = $this.ActionHistory
            lastSaved = (Get-Date).ToString("o")
        }
        
        $data | ConvertTo-Json -Depth 10 | Out-File -FilePath $this.DataFile -Encoding UTF8
    }
    
    [void] InitializeUnlockables() {
        if ($this.Unlockables.Count -gt 0) { return }
        
        $unlocks = @(
            [Unlockable]::new("anim_dance", "Dance Animation", "Unlock dance animation", [UnlockableType]::Animation, 5),
            [Unlockable]::new("anim_spin", "Spin Animation", "Unlock spin animation", [UnlockableType]::Animation, 8),
            [Unlockable]::new("anim_fly", "Fly Animation", "Unlock fly animation", [UnlockableType]::Animation, 12),
            [Unlockable]::new("skin_golden", "Golden Goose", "Golden goose skin", [UnlockableType]::Skin, 10),
            [Unlockable]::new("skin_ninja", "Ninja Goose", "Ninja goose skin", [UnlockableType]::Skin, 15),
            [Unlockable]::new("skin_hacker", "Hacker Goose", "Hacker theme skin", [UnlockableType]::Skin, 20),
            [Unlockable]::new("skin_ghost", "Ghost Goose", "Spooky ghost skin", [UnlockableType]::Skin, 25),
            [Unlockable]::new("skin_rainbow", "Rainbow Goose", "Rainbow gradient skin", [UnlockableType]::Skin, 30),
            [Unlockable]::new("ability_vip", "VIP Honk", "Special honk sound", [UnlockableType]::Ability, 7),
            [Unlockable]::new("ability_speed", "Speed Boost", "Move faster", [UnlockableType]::Ability, 10),
            [Unlockable]::new("ability_stealth", "Stealth Mode", "Hide from user", [UnlockableType]::Ability, 15),
            [Unlockable]::new("feature_multigoose", "Multi-Goose", "Spawn multiple geese", [UnlockableType]::Feature, 15),
            [Unlockable]::new("feature_chat", "AI Chat", "Chat with goose", [UnlockableType]::Feature, 12),
            [Unlockable]::new("feature_code", "Code Helper", "Code assistance", [UnlockableType]::Feature, 18),
            [Unlockable]::new("feature_chaos", "Chaos Mode", "Maximum chaos", [UnlockableType]::Feature, 25)
        )
        
        foreach ($u in $unlocks) {
            $this.Unlockables.Add($u)
        }
    }
    
    [void] InitializeAchievements() {
        if ($this.Achievements.Count -gt 0) { return }
        
        $achievements = @(
            [Achievement]::new("first_honk", "First Honk", "Honk for the first time", "🦆", 10),
            [Achievement]::new("curious_cat", "Curious Cat", "Check 10 different windows", "🧐", 25),
            [Achievement]::new("code_ninja", "Code Ninja", "Use code assistant 10 times", "💻", 50),
            [Achievement]::new("quiz_master", "Quiz Master", "Answer 50 quizzes correctly", "📚", 100),
            [Achievement]::new("streak_warrior", "Streak Warrior", "Maintain a 7-day streak", "🔥", 75),
            [Achievement]::new("chaos_agent", "Chaos Agent", "Reach 50 chaos stat", "🤪", 50),
            [Achievement]::new("speed_demon", "Speed Demon", "Reach 80 speed stat", "⚡", 50),
            [Achievement]::new("smart_goose", "Smart Goose", "Reach 80 intelligence stat", "🧠", 50),
            [Achievement]::new("mischief_maker", "Mischief Maker", "Reach 80 mischief stat", "😈", 50),
            [Achievement]::new("level_10", "Level 10", "Reach level 10", "🌟", 100),
            [Achievement]::new("level_25", "Level 25", "Reach level 25", "🌟🌟", 250),
            [Achievement]::new("max_level", "Max Level", "Reach level 50", "👑", 500)
        )
        
        foreach ($a in $achievements) {
            $this.Achievements.Add($a)
        }
    }
    
    [void] AddXP([int]$amount) {
        $this.XP += $amount
        $this.TotalXP += $amount
        
        $this.CheckLevelUp()
        $this.CheckUnlockables()
        $this.CheckAchievements()
        $this.SaveData()
    }
    
    [void] CheckLevelUp() {
        $xpNeeded = $this.GetXPForNextLevel()
        
        while ($this.XP -ge $xpNeeded) {
            $this.XP -= $xpNeeded
            $this.Level++
            $xpNeeded = $this.GetXPForNextLevel()
        }
    }
    
    [int] GetXPForNextLevel() {
        return $this.Level * 100
    }
    
    [void] IncreaseStat([GooseStat]$stat, [int]$amount = 1) {
        $this.Stats.Increase($stat, $amount)
        
        $statName = $stat.ToString()
        if (-not $this.ActionHistory.ContainsKey("stat_$statName")) {
            $this.ActionHistory["stat_$statName"] = 0
        }
        $this.ActionHistory["stat_$statName"] += $amount
        
        $xpGain = $amount * 2
        $this.AddXP($xpGain)
    }
    
    [void] PerformAction([string]$action) {
        if (-not $this.ActionHistory.ContainsKey($action)) {
            $this.ActionHistory[$action] = 0
        }
        $this.ActionHistory[$action]++
        
        $xpGain = switch ($action) {
            "honk" { 1 }
            "wander" { 2 }
            "interact" { 5 }
            "code_help" { 10 }
            "quiz_correct" { 15 }
            "game_win" { 20 }
            "trick_learned" { 25 }
            default { 1 }
        }
        
        $this.AddXP($xpGain)
    }
    
    [void] CheckUnlockables() {
        foreach ($u in $this.Unlockables) {
            if (-not $u.Unlocked -and $this.Level -ge $u.RequiredLevel) {
                $u.Unlocked = $true
            }
        }
    }
    
    [void] CheckAchievements() {
        foreach ($a in $this.Achievements) {
            if ($a.Earned) { continue }
            
            $earned = $false
            
            switch ($a.Id) {
                "first_honk" { $earned = $true }
                "level_10" { $earned = $this.Level -ge 10 }
                "level_25" { $earned = $this.Level -ge 25 }
                "max_level" { $earned = $this.Level -ge 50 }
                "chaos_agent" { $earned = $this.Stats.Chaos -ge 50 }
                "speed_demon" { $earned = $this.Stats.Speed -ge 80 }
                "smart_goose" { $earned = $this.Stats.Intelligence -ge 80 }
                "mischief_maker" { $earned = $this.Stats.Mischief -ge 80 }
            }
            
            if ($a.ActionHistory -and $this.ActionHistory.ContainsKey($a.Id)) {
                $earned = $true
            }
            
            if ($earned) {
                $a.Earned = $true
                $a.EarnedAt = Get-Date
                $this.AddXP($a.XPReward)
            }
        }
    }
    
    [hashtable] GetRPGState() {
        return @{
            Enabled = $this.Config["RPGEnabled"]
            Level = $this.Level
            XP = $this.XP
            TotalXP = $this.TotalXP
            XPForNextLevel = $this.GetXPForNextLevel()
            Stats = @{
                Mischief = $this.Stats.Mischief
                Intelligence = $this.Stats.Intelligence
                Speed = $this.Stats.Speed
                Chaos = $this.Stats.Chaos
            }
            Unlockables = @($this.Unlockables | ForEach-Object {
                @{
                    Id = $_.Id
                    Name = $_.Name
                    Description = $_.Description
                    Type = $_.Type.ToString()
                    RequiredLevel = $_.RequiredLevel
                    Unlocked = $_.Unlocked
                }
            })
            Achievements = @($this.Achievements | ForEach-Object {
                @{
                    Id = $_.Id
                    Name = $_.Name
                    Description = $_.Description
                    Icon = $_.Icon
                    XPReward = $_.XPReward
                    Earned = $_.Earned
                }
            })
            RecentActions = $this.ActionHistory
        }
    }
    
    [hashtable] GetUnlockedItems() {
        return @($this.Unlockables | Where-Object { $_.Unlocked })
    }
    
    [hashtable] GetAvailableUnlockables() {
        return @($this.Unlockables | Where-Object { -not $_.Unlocked })
    }
    
    [hashtable] GetEarnedAchievements() {
        return @($this.Achievements | Where-Object { $_.Earned })
    }
}

$gooseRPG = [GooseRPG]::new()

function Get-GooseRPG {
    return $gooseRPG
}

function Add-GooseXP {
    param(
        [Parameter(Mandatory=$true)]
        [int]$Amount,
        $RPG = $gooseRPG
    )
    $RPG.AddXP($Amount)
    return $RPG.GetRPGState()
}

function Increase-GooseStat {
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Mischief", "Intelligence", "Speed", "Chaos")]
        [string]$Stat,
        [int]$Amount = 1,
        $RPG = $gooseRPG
    )
    $RPG.IncreaseStat([GooseStat]$Stat, $Amount)
    return $RPG.GetRPGState()
}

function Perform-GooseAction {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Action,
        $RPG = $gooseRPG
    )
    $RPG.PerformAction($Action)
    return $RPG.GetRPGState()
}

function Get-RPGState {
    param($RPG = $gooseRPG)
    return $RPG.GetRPGState()
}

function Get-UnlockedItems {
    param($RPG = $gooseRPG)
    return $RPG.GetUnlockedItems()
}

function Get-Achievements {
    param(
        [bool]$EarnedOnly = $false,
        $RPG = $gooseRPG
    )
    if ($EarnedOnly) {
        return $RPG.GetEarnedAchievements()
    }
    return $RPG.GetRPGState().Achievements
}

Write-Host "Desktop Goose RPG System Initialized"
$state = Get-RPGState
Write-Host "RPG Enabled: $($state['Enabled']) | Level: $($state['Level']) | XP: $($state['TotalXP'])"
