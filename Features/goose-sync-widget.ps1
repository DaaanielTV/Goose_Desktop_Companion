# Desktop Goose Sync Status Widget
# Displays sync status in the UI

class GooseSyncWidget {
    [hashtable]$Config
    [object]$SyncClient
    [bool]$IsVisible
    [string]$Position
    
    GooseSyncWidget([object]$syncClient) {
        $this.SyncClient = $syncClient
        $this.Config = $this.LoadConfig()
        $this.IsVisible = $false
        $this.Position = "bottom-right"
    }
    
    [hashtable] LoadConfig() {
        $config = @{}
        $configFile = "config.ini"
        
        if (Test-Path $configFile) {
            Get-Content $configFile | ForEach-Object {
                if ($_ -match '^([^=]+)=(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    
                    if ($value -eq 'True' -or $value -eq 'False') {
                        $config[$key] = [bool]$value
                    } elseif ($value -match '^\d+$') {
                        $config[$key] = [int]$value
                    } else {
                        $config[$key] = $value
                    }
                }
            }
        }
        
        return $config
    }
    
    [hashtable] GetWidgetData() {
        $status = $this.SyncClient.GetSyncStatus()
        
        $icon = switch ($status.Status) {
            "Idle" { "☁️" }
            "Syncing" { "🔄" }
            "Success" { "✅" }
            "Error" { "❌" }
            "Offline" { "📴" }
            default { "❓" }
        }
        
        $statusText = switch ($status.Status) {
            "Idle" { "Bereit" }
            "Syncing" { "Synchronisiere..." }
            "Success" { "Synchronisiert" }
            "Error" { "Fehler" }
            "Offline" { "Offline" }
            default { "Unbekannt" }
        }
        
        $lastSync = if ($status.LastSync) { 
            $status.LastSync.ToString("dd.MM HH:mm") 
        } else { 
            "Nie" 
        }
        
        return @{
            "Visible" = $this.IsVisible
            "Enabled" = $status.Enabled
            "Online" = $status.Online
            "Icon" = $icon
            "Status" = $statusText
            "LastSync" = $lastSync
            "QueueSize" = $status.QueueSize
            "DeviceName" = $status.DeviceName
            "SupabaseUrl" = $status.SupabaseUrl
        }
    }
    
    [void] Show() {
        $this.IsVisible = $true
    }
    
    [void] Hide() {
        $this.IsVisible = $false
    }
    
    [void] Toggle() {
        $this.IsVisible = -not $this.IsVisible
    }
    
    [string] GetWidgetHtml() {
        $data = $this.GetWidgetData()
        
        $bgColor = switch ($data.Status) {
            "Bereit" { "#4CAF50" }
            "Synchronisiere..." { "#2196F3" }
            "Synchronisiert" { "#4CAF50" }
            "Fehler" { "#f44336" }
            "Offline" { "#9e9e9e" }
            default { "#757575" }
        }
        
        $html = @"
<div id="goose-sync-widget" style="
    position: fixed;
    $($this.Position): 10px;
    background: $bgColor;
    color: white;
    padding: 8px 12px;
    border-radius: 8px;
    font-family: 'Segoe UI', sans-serif;
    font-size: 12px;
    z-index: 9999;
    display: $($data.Visible ? 'block' : 'none');
    box-shadow: 0 2px 10px rgba(0,0,0,0.2);
">
    <div style="display: flex; align-items: center; gap: 8px;">
        <span style="font-size: 16px;">$($data.Icon)</span>
        <div>
            <div style="font-weight: bold;">Goose Sync</div>
            <div>$($data.Status)</div>
            <div style="font-size: 10px; opacity: 0.8;">
                $($data.LastSync)
                $(if ($data.QueueSize -gt 0) { " | $($data.QueueSize) ausstehend" })
            </div>
        </div>
    </div>
</div>
"@
        
        return $html
    }
    
    [string] GetTrayMenuXml() {
        $data = $this.GetWidgetData()
        
        $menuXml = @"
<TrayMenu>
    <Item Id="sync-header" Text="Cloud Sync: $($data.Status)" Enabled="false" />
    <Separator />
    <Item Id="sync-last" Text="Letzte Sync: $($data.LastSync)" Enabled="false" />
    <Item Id="sync-device" Text="Gerät: $($data.DeviceName)" Enabled="false" />
    <Separator />
    <Item Id="sync-now" Text="Jetzt synchronisieren" 
          Callback="Sync-AllData" 
          Enabled="$($data.Online)" />
    <Item Id="sync-toggle" Text="$($data.Enabled ? 'Deaktivieren' : 'Aktivieren')" 
          Callback="Toggle-Sync" />
    <Separator />
    <Item Id="sync-queue" Text="Ausstehende Änderungen: $($data.QueueSize)" Enabled="false" />
    <Item Id="sync-clear" Text="Sync-Queue leeren" 
          Callback="Clear-SyncQueue" 
          Enabled="$($data.QueueSize -gt 0)" />
</TrayMenu>
"@
        
        return $menuXml
    }
}

function New-GooseSyncWidget {
    param([object]$SyncClient)
    return [GooseSyncWidget]::new($SyncClient)
}

function Get-SyncWidgetData {
    param([object]$Widget)
    return $Widget.GetWidgetData()
}

function Show-SyncWidget {
    param([object]$Widget)
    $Widget.Show()
}

function Hide-SyncWidget {
    param([object]$Widget)
    $Widget.Hide()
}

function Toggle-SyncWidget {
    param([object]$Widget)
    $Widget.Toggle()
}

function Get-SyncWidgetHtml {
    param([object]$Widget)
    return $Widget.GetWidgetHtml()
}

Write-Host "Desktop Goose Sync Widget Module Initialized"
