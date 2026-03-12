# Desktop Goose Export/Import Settings System
# Backup and restore configuration

class GooseSettingsManager {
    [hashtable]$Config
    [string]$SettingsDirectory
    [string]$DefaultBackupName
    
    GooseSettingsManager() {
        $this.Config = $this.LoadConfig()
        $this.SettingsDirectory = "Backups"
        $this.DefaultBackupName = "goose_backup"
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
        
        return $this.Config
    }
    
    [void] EnsureBackupDirectory() {
        if (-not (Test-Path $this.SettingsDirectory)) {
            New-Item -ItemType Directory -Path $this.SettingsDirectory | Out-Null
        }
    }
    
    [hashtable] ExportSettings([string]$backupName = "") {
        $this.EnsureBackupDirectory()
        
        if ($backupName -eq "") {
            $backupName = $this.DefaultBackupName
        }
        
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $backupFileName = "${backupName}_${timestamp}.json"
        $backupPath = Join-Path $this.SettingsDirectory $backupFileName
        
        $backupData = @{
            "Version" = "1.0"
            "ExportDate" = (Get-Date).ToString("o")
            "ConfigFile" = @{}
            "PowerShellSettings" = @()
        }
        
        if (Test-Path "config.ini") {
            $backupData["ConfigFile"]["Path"] = "config.ini"
            $backupData["ConfigFile"]["Content"] = Get-Content "config.ini" -Raw
        }
        
        $ps1Files = Get-ChildItem -Path . -Filter "goose-*.ps1" -File
        foreach ($file in $ps1Files) {
            $settingInfo = @{
                "FileName" = $file.Name
                "LastModified" = $file.LastWriteTime.ToString("o")
                "Size" = $file.Length
            }
            $backupData["PowerShellSettings"] += $settingInfo
        }
        
        $backupData | ConvertTo-Json -Depth 10 | Out-File -FilePath $backupPath -Encoding UTF8
        
        return @{
            "Success" = $true
            "BackupFile" = $backupPath
            "BackupName" = $backupFileName
            "ExportDate" = $backupData["ExportDate"]
            "FilesIncluded" = $backupData["PowerShellSettings"].Count + 1
            "Message" = "Settings exported to $backupFileName"
        }
    }
    
    [hashtable] ImportSettings([string]$backupPath) {
        if (-not (Test-Path $backupPath)) {
            return @{
                "Success" = $false
                "Message" = "Backup file not found: $backupPath"
            }
        }
        
        try {
            $backupData = Get-Content $backupPath | ConvertFrom-Json
            
            if ($backupData.ConfigFile.Content) {
                $configPath = "config.ini"
                $backupData.ConfigFile.Content | Out-File -FilePath $configPath -Encoding UTF8
            }
            
            return @{
                "Success" = $true
                "ImportDate" = (Get-Date).ToString("o")
                "OriginalDate" = $backupData.ExportDate
                "FilesImported" = 1
                "Message" = "Settings imported successfully"
            }
        } catch {
            return @{
                "Success" = $false
                "Message" = "Failed to import settings: $($_.Exception.Message)"
            }
        }
    }
    
    [array] ListBackups() {
        $this.EnsureBackupDirectory()
        
        $backups = Get-ChildItem -Path $this.SettingsDirectory -Filter "*.json" | Sort-Object LastWriteTime -Descending
        
        return $backups | ForEach-Object {
            @{
                "FileName" = $_.Name
                "FullPath" = $_.FullName
                "LastModified" = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm:ss")
                "Size" = $_.Length
            }
        }
    }
    
    [hashtable] DeleteBackup([string]$backupPath) {
        if (-not (Test-Path $backupPath)) {
            return @{
                "Success" = $false
                "Message" = "Backup not found"
            }
        }
        
        Remove-Item -Path $backupPath -Force
        
        return @{
            "Success" = $true
            "Message" = "Backup deleted"
        }
    }
    
    [hashtable] GetSettingsManagerState() {
        $backups = $this.ListBackups()
        
        return @{
            "SettingsDirectory" = $this.SettingsDirectory
            "BackupCount" = $backups.Count
            "Backups" = $backups
        }
    }
}

$gooseSettingsManager = [GooseSettingsManager]::new()

function Get-GooseSettingsManager {
    return $gooseSettingsManager
}

function Export-GooseSettings {
    param(
        [string]$BackupName = "",
        $Manager = $gooseSettingsManager
    )
    return $Manager.ExportSettings($BackupName)
}

function Import-GooseSettings {
    param(
        [string]$BackupPath,
        $Manager = $gooseSettingsManager
    )
    return $Manager.ImportSettings($BackupPath)
}

function Get-BackupList {
    param($Manager = $gooseSettingsManager)
    return $Manager.ListBackups()
}

function Get-SettingsManagerState {
    param($Manager = $gooseSettingsManager)
    return $Manager.GetSettingsManagerState()
}

Write-Host "Desktop Goose Settings Manager System Initialized"
$state = Get-SettingsManagerState
Write-Host "Settings Directory: $($state['SettingsDirectory'])"
Write-Host "Available Backups: $($state['BackupCount'])"
