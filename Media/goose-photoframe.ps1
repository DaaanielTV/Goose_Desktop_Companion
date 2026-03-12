# Desktop Goose Photo Frame System
# Display photos on desktop

class GoosePhotoFrame {
    [hashtable]$Config
    [string]$PhotosDirectory
    [array]$Photos
    [int]$CurrentPhotoIndex
    [bool]$IsDisplaying
    [int]$DisplayDurationSeconds
    
    GoosePhotoFrame() {
        $this.Config = $this.LoadConfig()
        $this.PhotosDirectory = "Photos"
        $this.Photos = @()
        $this.CurrentPhotoIndex = 0
        $this.IsDisplaying = $false
        $this.DisplayDurationSeconds = 30
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
        
        if (-not $this.Config.ContainsKey("PhotoFrameEnabled")) {
            $this.Config["PhotoFrameEnabled"] = $false
        }
        
        return $this.Config
    }
    
    [void] ScanPhotos() {
        if (-not (Test-Path $this.PhotosDirectory)) {
            New-Item -ItemType Directory -Path $this.PhotosDirectory | Out-Null
        }
        
        $extensions = @("*.jpg", "*.jpeg", "*.png", "*.gif", "*.bmp")
        $this.Photos = @()
        
        foreach ($ext in $extensions) {
            $files = Get-ChildItem -Path $this.PhotosDirectory -Filter $ext -File
            $this.Photos += $files
        }
        
        $this.Photos = $this.Photos | Sort-Object LastWriteTime -Descending
    }
    
    [hashtable] StartDisplay([string]$photoPath = "") {
        if ($this.Photos.Count -eq 0) {
            $this.ScanPhotos()
        }
        
        if ($this.Photos.Count -eq 0) {
            return @{
                "Success" = $false
                "Message" = "No photos found in $this.PhotosDirectory"
            }
        }
        
        if ($photoPath -ne "") {
            $photo = $this.Photos | Where-Object { $_.FullName -eq $photoPath } | Select-Object -First 1
            if ($photo) {
                $this.CurrentPhotoIndex = [array]::IndexOf($this.Photos, $photo)
            }
        }
        
        $this.IsDisplaying = $true
        $currentPhoto = $this.Photos[$this.CurrentPhotoIndex]
        
        return @{
            "Success" = $true
            "PhotoPath" = $currentPhoto.FullName
            "PhotoName" = $currentPhoto.Name
            "Index" = $this.CurrentPhotoIndex
            "TotalPhotos" = $this.Photos.Count
            "Message" = "Displaying: $($currentPhoto.Name)"
        }
    }
    
    [hashtable] StopDisplay() {
        $this.IsDisplaying = $false
        
        return @{
            "Success" = $true
            "Message" = "Photo frame closed"
        }
    }
    
    [hashtable] NextPhoto() {
        if ($this.Photos.Count -eq 0) {
            return @{
                "Success" = $false
                "Message" = "No photos available"
            }
        }
        
        $this.CurrentPhotoIndex = ($this.CurrentPhotoIndex + 1) % $this.Photos.Count
        $photo = $this.Photos[$this.CurrentPhotoIndex]
        
        return @{
            "Success" = $true
            "PhotoPath" = $photo.FullName
            "PhotoName" = $photo.Name
            "Index" = $this.CurrentPhotoIndex
        }
    }
    
    [hashtable] PreviousPhoto() {
        if ($this.Photos.Count -eq 0) {
            return @{
                "Success" = $false
                "Message" = "No photos available"
            }
        }
        
        $this.CurrentPhotoIndex = ($this.CurrentPhotoIndex - 1 + $this.Photos.Count) % $this.Photos.Count
        $photo = $this.Photos[$this.CurrentPhotoIndex]
        
        return @{
            "Success" = $true
            "PhotoPath" = $photo.FullName
            "PhotoName" = $photo.Name
            "Index" = $this.CurrentPhotoIndex
        }
    }
    
    [void] SetDisplayDuration([int]$seconds) {
        $this.DisplayDurationSeconds = $seconds
    }
    
    [array] GetAllPhotos() {
        if ($this.Photos.Count -eq 0) {
            $this.ScanPhotos()
        }
        
        return $this.Photos | ForEach-Object {
            @{
                "Name" = $_.Name
                "FullPath" = $_.FullName
                "Size" = $_.Length
                "LastModified" = $_.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
            }
        }
    }
    
    [hashtable] GetPhotoFrameState() {
        if ($this.Photos.Count -eq 0) {
            $this.ScanPhotos()
        }
        
        return @{
            "Enabled" = $this.Config["PhotoFrameEnabled"]
            "IsDisplaying" = $this.IsDisplaying
            "CurrentPhotoIndex" = $this.CurrentPhotoIndex
            "TotalPhotos" = $this.Photos.Count
            "PhotosDirectory" = $this.PhotosDirectory
            "DisplayDuration" = $this.DisplayDurationSeconds
            "CurrentPhoto" = if ($this.IsDisplaying -and $this.Photos.Count -gt 0) { $this.Photos[$this.CurrentPhotoIndex].Name } else { "" }
        }
    }
}

$goosePhotoFrame = [GoosePhotoFrame]::new()

function Get-GoosePhotoFrame {
    return $goosePhotoFrame
}

function Start-PhotoFrame {
    param(
        [string]$PhotoPath = "",
        $PhotoFrame = $goosePhotoFrame
    )
    return $PhotoFrame.StartDisplay($PhotoPath)
}

function Stop-PhotoFrame {
    param($PhotoFrame = $goosePhotoFrame)
    return $PhotoFrame.StopDisplay()
}

function Next-Photo {
    param($PhotoFrame = $goosePhotoFrame)
    return $PhotoFrame.NextPhoto()
}

function Get-AllPhotos {
    param($PhotoFrame = $goosePhotoFrame)
    return $PhotoFrame.GetAllPhotos()
}

function Get-PhotoFrameState {
    param($PhotoFrame = $goosePhotoFrame)
    return $PhotoFrame.GetPhotoFrameState()
}

Write-Host "Desktop Goose Photo Frame System Initialized"
$state = Get-PhotoFrameState
Write-Host "Photo Frame Enabled: $($state['Enabled'])"
Write-Host "Available Photos: $($state['TotalPhotos'])"
