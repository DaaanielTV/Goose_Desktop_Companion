# Desktop Goose Security & Storage Module
# Provides OAuth, API Keys, Audit Logs, and File Management

enum AuthProvider {
    Google
    GitHub
    Apple
    Microsoft
}

enum AuditAction {
    Login
    Logout
    Sync
    FileUpload
    FileDownload
    FileDelete
    SettingsChange
    ApiKeyCreated
    ApiKeyUsed
    ApiKeyRevoked
    WebhookTriggered
    GoalAchieved
}

class ApiKey {
    [string]$Id
    [string]$KeyPrefix
    [string]$Name
    [string]$Description
    [string[]]$Permissions
    [int]$RateLimit
    [datetime]$LastUsedAt
    [datetime]$ExpiresAt
    [bool]$IsActive
}

class AuditLogEntry {
    [string]$Id
    [datetime]$CreatedAt
    [string]$Action
    [string]$ResourceType
    [string]$ResourceId
    [string]$IpAddress
    [string]$UserAgent
    [bool]$Success
    [object]$Details
}

class GooseSecurityClient {
    [hashtable]$Config
    [string]$SupabaseUrl
    [string]$SupabaseAnonKey
    [string]$SupabaseServiceKey
    [string]$DeviceId
    [bool]$IsEnabled
    [bool]$IsOnline
    [System.Collections.ArrayList]$ApiKeys

    GooseSecurityClient() {
        $this.Config = $this.LoadConfig()
        $this.SupabaseUrl = $this.Config["SupabaseUrl"]
        $this.SupabaseAnonKey = $this.Config["SupabaseAnonKey"]
        $this.SupabaseServiceKey = $this.Config["SupabaseServiceKey"]
        $this.IsEnabled = $this.Config["SecurityEnabled"]
        $this.IsOnline = $false
        $this.ApiKeys = New-Object System.Collections.ArrayList

        $this.InitializeDeviceId()

        if ($this.IsEnabled) {
            $this.TestConnection()
            $this.LoadApiKeys()
        }
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
                    } elseif ($value -match '^\d+\.\d+$') {
                        $config[$key] = [double]$value
                    } else {
                        $config[$key] = $value
                    }
                }
            }
        }

        if (-not $config.ContainsKey("SecurityEnabled")) { $config["SecurityEnabled"] = $false }

        return $config
    }

    [void] InitializeDeviceId() {
        $deviceIdFile = "goose_device.id"

        if (Test-Path $deviceIdFile) {
            $this.DeviceId = Get-Content $deviceIdFile -Raw
        } else {
            $this.DeviceId = [guid]::NewGuid().ToString()
            $this.DeviceId | Set-Content $deviceIdFile
        }

        if ($this.Config["DeviceId"] -and $this.Config["DeviceId"] -ne "") {
            $this.DeviceId = $this.Config["DeviceId"]
        }
    }

    [bool] TestConnection() {
        try {
            $response = Invoke-RestMethod -Uri "$($this.SupabaseUrl)/rest/v1/" `
                -Headers @{
                    "apikey" = $this.SupabaseAnonKey
                    "Authorization" = "Bearer $($this.SupabaseAnonKey)"
                } `
                -Method GET `
                -TimeoutSec 10

            $this.IsOnline = $true
            return $true
        } catch {
            $this.IsOnline = $false
            return $false
        }
    }

    [void] LoadApiKeys() {
        if (-not $this.IsOnline) { return }

        $endpoint = "$($this.SupabaseUrl)/rest/v1/api_keys?user_id=eq.$($this.DeviceId)&is_active=eq.true&select=*"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseAnonKey)"
        }

        try {
            $data = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method GET
            foreach ($key in $data) {
                $apiKey = [ApiKey]::new()
                $apiKey.Id = $key.id
                $apiKey.KeyPrefix = $key.key_prefix
                $apiKey.Name = $key.name
                $apiKey.Description = $key.description
                $apiKey.Permissions = $key.permissions
                $apiKey.RateLimit = $key.rate_limit
                $apiKey.LastUsedAt = $key.last_used_at
                $apiKey.ExpiresAt = $key.expires_at
                $apiKey.IsActive = $key.is_active
                $this.ApiKeys.Add($apiKey)
            }
        } catch {
        }
    }

    [hashtable] CreateApiKey([string]$name, [string[]]$permissions = @("read"), [int]$expiresInDays = 365) {
        $endpoint = "$($this.SupabaseUrl)/rest/v1/rpc/generate_api_key"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseServiceKey)"
            "Content-Type" = "application/json"
        }

        $expiresAt = (Get-Date).AddDays($expiresInDays).ToString("o")

        $body = @{
            "p_user_id" = $this.DeviceId
            "p_name" = $name
            "p_permissions" = $permissions
            "p_expires_at" = $expiresAt
        } | ConvertTo-Json

        try {
            $result = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method POST -Body $body

            $newKey = [ApiKey]::new()
            $newKey.Id = $result.key_id
            $newKey.KeyPrefix = $result.key_prefix
            $newKey.Name = $name
            $newKey.Permissions = $permissions
            $newKey.IsActive = $true
            $newKey.ExpiresAt = $expiresAt
            $this.ApiKeys.Add($newKey)

            $this.LogAuditEvent([AuditAction]::ApiKeyCreated, "api_key", $result.key_id, @{
                "key_name" = $name
                "key_prefix" = $result.key_prefix
            })

            return @{
                "Success" = $true
                "ApiKey" = $result.api_key
                "KeyId" = $result.key_id
                "KeyPrefix" = $result.key_prefix
                "ExpiresAt" = $expiresAt
            }
        } catch {
            return @{
                "Success" = $false
                "Error" = $_.Exception.Message
            }
        }
    }

    [hashtable] RevokeApiKey([string]$keyId) {
        $endpoint = "$($this.SupabaseUrl)/rest/v1/api_keys?id=eq.$($keyId)"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseServiceKey)"
            "Content-Type" = "application/json"
        }

        $body = @{
            "is_active" = $false
        } | ConvertTo-Json

        try {
            Invoke-RestMethod -Uri $endpoint -Headers $headers -Method PATCH -Body $body | Out-Null

            $this.ApiKeys = $this.ApiKeys | Where-Object { $_.Id -ne $keyId }

            $this.LogAuditEvent([AuditAction]::ApiKeyRevoked, "api_key", $keyId, @{})

            return @{
                "Success" = $true
            }
        } catch {
            return @{
                "Success" = $false
                "Error" = $_.Exception.Message
            }
        }
    }

    [object] GetApiKeys() {
        return @{
            "Total" = $this.ApiKeys.Count
            "Active" = ($this.ApiKeys | Where-Object { $_.IsActive }).Count
            "Keys" = $this.ApiKeys
        }
    }

    [hashtable] LogAuditEvent([AuditAction]$action, [string]$resourceType = $null, [string]$resourceId = $null, [object]$details = $null) {
        if (-not $this.IsOnline) {
            $this.SaveLocalAuditLog($action, $resourceType, $resourceId, $details)
            return @{
                "Success" = $true
                "Local" = $true
            }
        }

        $endpoint = "$($this.SupabaseUrl)/rest/v1/rpc/log_audit_event"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseServiceKey)"
            "Content-Type" = "application/json"
        }

        $detailsJson = if ($details) { $details | ConvertTo-Json -Compress } else { "{}" }

        $body = @{
            "p_user_id" = $this.DeviceId
            "p_device_id" = $this.DeviceId
            "p_action" = $action.ToString().ToLower()
            "p_resource_type" = $resourceType
            "p_resource_id" = if ($resourceId) { $resourceId } else { $null }
            "p_details" = $detailsJson
            "p_success" = $true
        } | ConvertTo-Json

        try {
            $result = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method POST -Body $body
            return @{
                "Success" = $true
                "AuditId" = $result
            }
        } catch {
            $this.SaveLocalAuditLog($action, $resourceType, $resourceId, $details)
            return @{
                "Success" = $true
                "Local" = $true
            }
        }
    }

    [void] SaveLocalAuditLog([AuditAction]$action, [string]$resourceType, [string]$resourceId, [object]$details) {
        $auditFile = "goose_audit_queue.json"
        $entries = @()

        if (Test-Path $auditFile) {
            try {
                $entries = Get-Content $auditFile -Raw | ConvertFrom-Json
                if ($entries -isnot [array]) { $entries = @($entries) }
            } catch {
                $entries = @()
            }
        }

        $entries += @{
            "Action" = $action.ToString()
            "ResourceType" = $resourceType
            "ResourceId" = $resourceId
            "Details" = $details
            "Timestamp" = (Get-Date).ToString("o")
        }

        $entries | ConvertTo-Json -Depth 10 | Set-Content $auditFile
    }

    [object] GetAuditLogs([int]$limit = 100, [string]$action = $null) {
        if (-not $this.IsOnline) {
            return @{
                "Success" = $false
                "Error" = "Offline"
                "LocalData" = $this.GetLocalAuditLogs($limit)
            }
        }

        $endpoint = "$($this.SupabaseUrl)/rest/v1/audit_logs?user_id=eq.$($this.DeviceId)&order=created_at.desc&limit=$($limit)"

        if ($action) {
            $endpoint += "&action=eq.$($action)"
        }

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseAnonKey)"
        }

        try {
            $data = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method GET
            return @{
                "Success" = $true
                "Data" = $data
            }
        } catch {
            return @{
                "Success" = $false
                "Error" = $_.Exception.Message
            }
        }
    }

    [object] GetLocalAuditLogs([int]$limit) {
        $auditFile = "goose_audit_queue.json"

        if (Test-Path $auditFile) {
            try {
                $entries = Get-Content $auditFile -Raw | ConvertFrom-Json
                if ($entries -is [array]) {
                    return $entries | Select-Object -First $limit
                }
                return @($entries) | Select-Object -First $limit
            } catch {
                return @()
            }
        }

        return @()
    }

    [hashtable] RecordFileUpload([string]$fileName, [string]$mimeType, [long]$fileSize, [string]$checksum) {
        if (-not $this.IsOnline) {
            return @{
                "Success" = $false
                "Error" = "Offline"
            }
        }

        $endpoint = "$($this.SupabaseUrl)/rest/v1/rpc/record_file_upload"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseServiceKey)"
            "Content-Type" = "application/json"
        }

        $body = @{
            "p_user_id" = $this.DeviceId
            "p_file_name" = $fileName
            "p_file_path" = "uploads/$($this.DeviceId)/$fileName"
            "p_mime_type" = $mimeType
            "p_file_size" = $fileSize
            "p_checksum" = $checksum
            "p_storage_backend" = "local"
        } | ConvertTo-Json

        try {
            $result = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method POST -Body $body

            $this.LogAuditEvent([AuditAction]::FileUpload, "file", $result, @{
                "file_name" = $fileName
                "mime_type" = $mimeType
                "file_size" = $fileSize
            })

            return @{
                "Success" = $true
                "FileId" = $result
            }
        } catch {
            return @{
                "Success" = $false
                "Error" = $_.Exception.Message
            }
        }
    }

    [object] GetFiles([int]$limit = 50) {
        if (-not $this.IsOnline) {
            return @{
                "Success" = $false
                "Error" = "Offline"
            }
        }

        $endpoint = "$($this.SupabaseUrl)/rest/v1/files?user_id=eq.$($this.DeviceId)&order=uploaded_at.desc&limit=$($limit)"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseAnonKey)"
        }

        try {
            $data = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method GET
            return @{
                "Success" = $true
                "Data" = $data
            }
        } catch {
            return @{
                "Success" = $false
                "Error" = $_.Exception.Message
            }
        }
    }

    [hashtable] DeleteFile([string]$fileId) {
        if (-not $this.IsOnline) {
            return @{
                "Success" = $false
                "Error" = "Offline"
            }
        }

        $endpoint = "$($this.SupabaseUrl)/rest/v1/files?id=eq.$($fileId)"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseServiceKey)"
        }

        try {
            Invoke-RestMethod -Uri $endpoint -Headers $headers -Method DELETE | Out-Null

            $this.LogAuditEvent([AuditAction]::FileDelete, "file", $fileId, @{})

            return @{
                "Success" = $true
            }
        } catch {
            return @{
                "Success" = $false
                "Error" = $_.Exception.Message
            }
        }
    }

    [hashtable] LinkOAuthProvider([AuthProvider]$provider, [string]$providerId, [string]$providerEmail = $null) {
        if (-not $this.IsOnline) {
            return @{
                "Success" = $false
                "Error" = "Offline"
            }
        }

        $endpoint = "$($this.SupabaseUrl)/rest/v1/rpc/link_oauth_provider"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseServiceKey)"
            "Content-Type" = "application/json"
        }

        $body = @{
            "p_user_id" = $this.DeviceId
            "p_provider" = $provider.ToString().ToLower()
            "p_provider_id" = $providerId
            "p_provider_email" = $providerEmail
        } | ConvertTo-Json

        try {
            $result = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method POST -Body $body

            return @{
                "Success" = $true
                "LinkId" = $result
                "Provider" = $provider.ToString()
            }
        } catch {
            return @{
                "Success" = $false
                "Error" = $_.Exception.Message
            }
        }
    }

    [object] GetLinkedProviders() {
        if (-not $this.IsOnline) {
            return @{
                "Success" = $false
                "Error" = "Offline"
            }
        }

        $endpoint = "$($this.SupabaseUrl)/rest/v1/auth_providers?user_id=eq.$($this.DeviceId)&select=provider,provider_email,linked_at"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseAnonKey)"
        }

        try {
            $data = Invoke-RestMethod -Uri $endpoint -Headers $headers -Method GET
            return @{
                "Success" = $true
                "Data" = $data
            }
        } catch {
            return @{
                "Success" = $false
                "Error" = $_.Exception.Message
            }
        }
    }

    [bool] CheckRateLimit([string]$endpoint, [int]$limit = 100) {
        if (-not $this.IsOnline) {
            return $true
        }

        $dbEndpoint = "$($this.SupabaseUrl)/rest/v1/rpc/check_rate_limit"

        $headers = @{
            "apikey" = $this.SupabaseAnonKey
            "Authorization" = "Bearer $($this.SupabaseServiceKey)"
            "Content-Type" = "application/json"
        }

        $body = @{
            "p_user_id" = $this.DeviceId
            "p_device_id" = $this.DeviceId
            "p_endpoint" = $endpoint
            "p_limit" = $limit
        } | ConvertTo-Json

        try {
            $result = Invoke-RestMethod -Uri $dbEndpoint -Headers $headers -Method POST -Body $body
            return $result
        } catch {
            return $true
        }
    }
}

$gooseSecurityClient = [GooseSecurityClient]::new()

function Get-GooseSecurityClient {
    return $gooseSecurityClient
}

function New-ApiKey {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string[]]$Permissions = @("read"),
        [int]$ExpiresInDays = 365,
        $Client = $gooseSecurityClient
    )
    return $Client.CreateApiKey($Name, $Permissions, $ExpiresInDays)
}

function Revoke-ApiKey {
    param(
        [Parameter(Mandatory=$true)]
        [string]$KeyId,
        $Client = $gooseSecurityClient
    )
    return $Client.RevokeApiKey($KeyId)
}

function Get-ApiKeys {
    param($Client = $gooseSecurityClient)
    return $Client.GetApiKeys()
}

function Write-AuditLog {
    param(
        [Parameter(Mandatory=$true)]
        [AuditAction]$Action,
        [string]$ResourceType,
        [string]$ResourceId,
        [object]$Details,
        $Client = $gooseSecurityClient
    )
    return $Client.LogAuditEvent($Action, $ResourceType, $ResourceId, $Details)
}

function Get-AuditLogs {
    param(
        [int]$Limit = 100,
        [string]$Action,
        $Client = $gooseSecurityClient
    )
    return $Client.GetAuditLogs($Limit, $Action)
}

function Record-FileUpload {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FileName,
        [Parameter(Mandatory=$true)]
        [string]$MimeType,
        [Parameter(Mandatory=$true)]
        [long]$FileSize,
        [Parameter(Mandatory=$true)]
        [string]$Checksum,
        $Client = $gooseSecurityClient
    )
    return $Client.RecordFileUpload($FileName, $MimeType, $FileSize, $Checksum)
}

function Get-Files {
    param(
        [int]$Limit = 50,
        $Client = $gooseSecurityClient
    )
    return $Client.GetFiles($Limit)
}

function Remove-File {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FileId,
        $Client = $gooseSecurityClient
    )
    return $Client.DeleteFile($FileId)
}

function Link-OAuthProvider {
    param(
        [Parameter(Mandatory=$true)]
        [AuthProvider]$Provider,
        [Parameter(Mandatory=$true)]
        [string]$ProviderId,
        [string]$ProviderEmail,
        $Client = $gooseSecurityClient
    )
    return $Client.LinkOAuthProvider($Provider, $ProviderId, $ProviderEmail)
}

function Get-LinkedProviders {
    param($Client = $gooseSecurityClient)
    return $Client.GetLinkedProviders()
}

function Test-RateLimit {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Endpoint,
        [int]$Limit = 100,
        $Client = $gooseSecurityClient
    )
    return $Client.CheckRateLimit($Endpoint, $Limit)
}

Write-Host "Desktop Goose Security Module Initialized"
