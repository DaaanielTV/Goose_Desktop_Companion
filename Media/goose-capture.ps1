class GooseCapture {
    [hashtable]$Config
    [string]$DataPath
    [object]$Telemetry
    [System.Windows.Forms.Form]$OverlayForm
    [System.Drawing.Bitmap]$CurrentScreenshot
    [System.Drawing.Graphics]$AnnotationGraphics
    [bool]$IsCapturing
    [array]$Annotations
    
    GooseCapture([string]$configFile = "config.ini", [object]$telemetry = $null) {
        $this.Telemetry = $telemetry
        $this.LoadConfig($configFile)
        $this.DataPath = Join-Path $PSScriptRoot "capture_data"
        if (-not (Test-Path $this.DataPath)) {
            New-Item -ItemType Directory -Path $this.DataPath -Force | Out-Null
        }
        $this.Annotations = @()
        $this.IsCapturing = $false
        $this.CurrentScreenshot = $null
    }
    
    [void] LoadConfig([string]$configFile) {
        $this.Config = @{
            Enabled = $true
            Hotkey = "Win+Shift+G"
            SaveFormat = "png"
            SaveFolder = "Screenshots"
            AnnotationColor = "#FF5722"
            AnnotationSize = 3
            ShowGooseReaction = $true
        }
        if (Test-Path $configFile) {
            Get-Content $configFile | ForEach-Object {
                if ($_ -match '^([^=]+)=(.*)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    if ($this.Config.ContainsKey($key)) {
                        if ($value -eq 'True' -or $value -eq 'False') {
                            $this.Config[$key] = [bool]$value
                        } else {
                            $this.Config[$key] = $value
                        }
                    }
                }
            }
        }
        $saveFolder = Join-Path (Split-Path $PSScriptRoot -Parent) $this.Config["SaveFolder"]
        if (-not (Test-Path $saveFolder)) {
            New-Item -ItemType Directory -Path $saveFolder -Force | Out-Null
        }
    }
    
    [System.Drawing.Bitmap] CaptureScreen() {
        $this.Telemetry?.IncrementCounter("capture.screenshots_taken", 1)
        $bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
        $screenshot = New-Object System.Drawing.Bitmap($bounds.Width, $bounds.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($screenshot)
        $graphics.CopyFromScreen($bounds.Location, [System.Drawing.Point]::Empty, $bounds.Size)
        $graphics.Dispose()
        $this.CurrentScreenshot = $screenshot
        return $screenshot
    }
    
    [System.Drawing.Bitmap] CaptureRegion([System.Drawing.Rectangle]$region) {
        $this.Telemetry?.IncrementCounter("capture.regions_captured", 1)
        $screenshot = New-Object System.Drawing.Bitmap($region.Width, $region.Height)
        $graphics = [System.Drawing.Graphics]::FromImage($screenshot)
        $graphics.CopyFromScreen($region.Location, [System.Drawing.Point]::Empty, $region.Size)
        $graphics.Dispose()
        return $screenshot
    }
    
    [void] AddAnnotation([string]$type, [hashtable]$params) {
        $annotation = @{
            type = $type
            params = $params
            timestamp = (Get-Date).ToString("o")
        }
        $this.Annotations += $annotation
        $this.Telemetry?.IncrementCounter("capture.annotations_made", 1, @{type=$type})
    }
    
    [System.Drawing.Bitmap] DrawAnnotations([System.Drawing.Bitmap]$baseImage) {
        if ($this.Annotations.Count -eq 0) { return $baseImage }
        $annotated = New-Object System.Drawing.Bitmap($baseImage)
        $graphics = [System.Drawing.Graphics]::FromImage($annotated)
        $color = [System.Drawing.ColorTranslator]::FromHtml($this.Config["AnnotationColor"])
        $pen = New-Object System.Drawing.Pen($color, $this.Config["AnnotationSize"])
        $brush = New-Object System.Drawing.SolidBrush($color)
        foreach ($ann in $this.Annotations) {
            switch ($ann.type) {
                "rectangle" {
                    $rect = $ann.params
                    $graphics.DrawRectangle($pen, $rect.x, $rect.y, $rect.width, $rect.height)
                }
                "circle" {
                    $circ = $ann.params
                    $graphics.DrawEllipse($pen, $circ.x - $circ.radius, $circ.y - $circ.radius, $circ.radius * 2, $circ.radius * 2)
                }
                "arrow" {
                    $arrow = $ann.params
                    $graphics.DrawLine($pen, $arrow.x1, $arrow.y1, $arrow.x2, $arrow.y2)
                }
                "text" {
                    $text = $ann.params
                    $font = New-Object System.Drawing.Font("Segoe UI", $text.size)
                    $graphics.DrawString($text.content, $font, $brush, $text.x, $text.y)
                    $font.Dispose()
                }
                "highlight" {
                    $hl = $ann.params
                    $hlBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(80, 255, 255, 0))
                    $graphics.FillRectangle($hlBrush, $hl.x, $hl.y, $hl.width, $hl.height)
                    $hlBrush.Dispose()
                }
            }
        }
        $pen.Dispose()
        $brush.Dispose()
        $graphics.Dispose()
        return $annotated
    }
    
    [string] SaveScreenshot([System.Drawing.Bitmap]$image, [string]$filename = $null) {
        if (-not $filename) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $filename = "Screenshot_$timestamp.$($this.Config['SaveFormat'])"
        }
        $saveFolder = Join-Path (Split-Path $PSScriptRoot -Parent) $this.Config["SaveFolder"]
        $fullPath = Join-Path $saveFolder $filename
        $format = [System.Drawing.Imaging.ImageFormat]::PNG
        switch ($this.Config["SaveFormat"].ToLower()) {
            "jpg" { $format = [System.Drawing.Imaging.ImageFormat]::Jpeg }
            "jpeg" { $format = [System.Drawing.Imaging.ImageFormat]::Jpeg }
            "bmp" { $format = [System.Drawing.Imaging.ImageFormat]::Bmp }
        }
        $image.Save($fullPath, $format)
        $this.Telemetry?.IncrementCounter("capture.screenshots_saved", 1, @{format=$this.Config["SaveFormat"]})
        return $fullPath
    }
    
    [void] CopyToClipboard([System.Drawing.Bitmap]$image) {
        [System.Windows.Forms.Clipboard]::SetImage($image)
        $this.Telemetry?.IncrementCounter("capture.copied_to_clipboard", 1)
    }
    
    [void] AddGooseReaction([System.Drawing.Bitmap]$image) {
        $gooseEmoji = [System.Drawing.Bitmap]::new(32, 32)
        $g = [System.Drawing.Graphics]::FromImage($gooseEmoji)
        $font = New-Object System.Drawing.Font("Segoe UI Emoji", 16)
        $brush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
        $g.DrawString("🦆", $font, $brush, 0, 0)
        $g.Dispose()
        $font.Dispose()
        $brush.Dispose()
    }
    
    [void] StartAnnotationMode() {
        $this.IsCapturing = $true
        $this.Annotations = @()
        $span = $this.Telemetry?.StartSpan("capture.annotation_mode", "capture")
        $screen = $this.CaptureScreen()
        $annotated = $this.DrawAnnotations($screen)
        $this.ShowAnnotationOverlay($annotated)
    }
    
    [void] ShowAnnotationOverlay([System.Drawing.Bitmap]$image) {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing
        $form = New-Object System.Windows.Forms.Form
        $form.Text = "Desktop Goose - Annotation Mode"
        $form.Size = New-Object System.Drawing.Size(800, 600)
        $form.StartPosition = "CenterScreen"
        $form.BackColor = [System.Drawing.Color]::Black
        $pictureBox = New-Object System.Windows.Forms.PictureBox
        $pictureBox.Image = $image
        $pictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
        $pictureBox.Dock = [System.Windows.Forms.DockStyle]::Fill
        $form.Controls.Add($pictureBox)
        $btnSave = New-Object System.Windows.Forms.Button
        $btnSave.Text = "Save"
        $btnSave.Location = New-Object System.Drawing.Point(10, 10)
        $btnSave.BackColor = [System.Drawing.Color]::FromArgb(0, 120, 215)
        $btnSave.ForeColor = [System.Drawing.Color]::White
        $form.Controls.Add($btnSave)
        $btnSave.Add_Click({
            $saved = $this.SaveScreenshot($pictureBox.Image)
            [System.Windows.Forms.MessageBox]::Show("Saved to: $saved", "Saved", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        })
        $btnCopy = New-Object System.Windows.Forms.Button
        $btnCopy.Text = "Copy to Clipboard"
        $btnCopy.Location = New-Object System.Drawing.Point(90, 10)
        $btnCopy.BackColor = [System.Drawing.Color]::FromArgb(0, 150, 80)
        $btnCopy.ForeColor = [System.Drawing.Color]::White
        $form.Controls.Add($btnCopy)
        $btnCopy.Add_Click({
            $this.CopyToClipboard($pictureBox.Image)
        })
        $btnClose = New-Object System.Windows.Forms.Button
        $btnClose.Text = "Close"
        $btnClose.Location = New-Object System.Drawing.Point(220, 10)
        $btnClose.BackColor = [System.Drawing.Color]::FromArgb(180, 60, 60)
        $btnClose.ForeColor = [System.Drawing.Color]::White
        $form.Controls.Add($btnClose)
        $btnClose.Add_Click({ $form.Close() })
        $form.ShowDialog()
    }
    
    [hashtable] GetCaptureStats() {
        $saveFolder = Join-Path (Split-Path $PSScriptRoot -Parent) $this.Config["SaveFolder"]
        $count = 0
        if (Test-Path $saveFolder) {
            $count = (Get-ChildItem $saveFolder -File | Measure-Object).Count
        }
        return @{
            totalScreenshots = $count
            annotationsCount = $this.Annotations.Count
            isCapturing = $this.IsCapturing
        }
    }
}

$gooseCapture = $null

function Get-Capture {
    param([object]$Telemetry = $null)
    if ($script:gooseCapture -eq $null) {
        $script:gooseCapture = [GooseCapture]::new("config.ini", $Telemetry)
    }
    return $script:gooseCapture
}

function Start-ScreenCapture {
    param([string]$Mode = "full")
    $capture = Get-Capture
    if ($Mode -eq "full") {
        return $capture.CaptureScreen()
    } elseif ($Mode -eq "region") {
        [System.Windows.Forms.MessageBox]::Show("Draw a region to capture", "Region Capture", [System.Windows.Forms.MessageBoxButtons]::OK)
    }
}

function Add-CaptureAnnotation {
    param([string]$Type, [hashtable]$Params)
    $capture = Get-Capture
    $capture.AddAnnotation($Type, $Params)
}

function Save-CaptureScreenshot {
    param([System.Drawing.Bitmap]$Image, [string]$Filename = $null)
    $capture = Get-Capture
    return $capture.SaveScreenshot($Image, $Filename)
}

Write-Host "Capture Module Initialized"
