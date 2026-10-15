# PhotoBooth V3 Checkpoint 2 correction — verified screenshots.
#
# Drives a real session and saves one screenshot per stage. Every capture is
# checked against the live accessibility hierarchy first, so a wrong or stale
# screen can never be reported as a pass. No fixed tap coordinates.

param(
  [string]$OutputDir = "docs\v3\screenshots\checkpoint-2-correction",
  [string]$Device = "emulator-5554",
  [string]$Package = "com.photobooth.photo_booth"
)

$ErrorActionPreference = "Stop"
$adb = "C:\Users\jpas\AppData\Local\Android\Sdk\platform-tools\adb.exe"

function Invoke-Adb {
  param([Parameter(Mandatory = $true)][string]$Command)
  $parts = $Command -split ' '
  & $adb -s $Device @parts
  if ($LASTEXITCODE -ne 0) { throw "adb $Command failed ($LASTEXITCODE)" }
}

function Get-Ui {
  Invoke-Adb "shell uiautomator dump /sdcard/pb_ui.xml" | Out-Null
  Invoke-Adb "pull /sdcard/pb_ui.xml $env:TEMP\pb_ui.xml" | Out-Null
  $raw = Get-Content "$env:TEMP\pb_ui.xml" -Raw
  return ($raw -replace '&amp;','&' -replace '&lt;','<' -replace '&gt;','>' `
              -replace '&quot;','"' -replace '&#10;',' ')
}

function Get-Centre {
  param([string]$Xml, [string]$Desc)
  # Prefix match: Flutter merges a Semantics label with its Text child.
  $p = 'content-desc="' + [regex]::Escape($Desc) + '[^"]*"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
  $m = [regex]::Match($Xml, $p)
  if (-not $m.Success) { throw "content-desc '$Desc' not found" }
  return @{ X = [int](([int]$m.Groups[1].Value + [int]$m.Groups[3].Value) / 2)
            Y = [int](([int]$m.Groups[2].Value + [int]$m.Groups[4].Value) / 2) }
}

function Save-Shot {
  param([string]$Name)
  $path = Join-Path $OutputDir $Name
  Invoke-Adb "shell screencap -p /sdcard/$Name"
  Invoke-Adb "pull /sdcard/$Name $path" | Out-Null
  if (-not (Test-Path $path)) { throw "screenshot $Name was not written" }
  Write-Host "  saved $Name"
}

function Assert-Has {
  param([string]$Xml, [string]$Needle, [string]$Label)
  if ($Xml -notmatch [regex]::Escape($Needle)) {
    throw "VERIFICATION FAILED: '$Needle' absent on $Label"
  }
  Write-Host "  verified $Label contains '$Needle'"
}

function Assert-Lacks {
  param([string]$Xml, [string]$Needle, [string]$Label)
  if ($Xml -match [regex]::Escape($Needle)) {
    throw "VERIFICATION FAILED: '$Needle' still present on $Label"
  }
  Write-Host "  verified $Label no longer shows '$Needle'"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

Write-Host "== Camera framing =="
Invoke-Adb "shell am force-stop $Package"
Invoke-Adb "shell pm grant $Package android.permission.CAMERA" | Out-Null
Invoke-Adb "shell am start -n $Package/.MainActivity" | Out-Null
Start-Sleep -Seconds 8

$ui = Get-Ui
Assert-Has -Xml $ui -Needle "Start Photo Booth" -Label "Home"
$start = Get-Centre -Xml $ui -Desc "Start Photo Booth"
Invoke-Adb "shell input tap $($start.X) $($start.Y)"
Start-Sleep -Seconds 9
$ui = Get-Ui
Assert-Has -Xml $ui -Needle "Take photos" -Label "Camera"
Save-Shot "camera-framing.png"

Write-Host "== Capture the four-shot session =="
$shutter = Get-Centre -Xml $ui -Desc "Take photos"
Invoke-Adb "shell input tap $($shutter.X) $($shutter.Y)"

$review = $null
for ($i = 0; $i -lt 24; $i++) {
  Start-Sleep -Seconds 5
  $probe = Get-Ui
  if ($probe -match 'content-desc="Next"') { $review = $probe; break }
}
if ($null -eq $review) { throw "VERIFICATION FAILED: session never reached Review" }
Assert-Has -Xml $review -Needle "Review" -Label "Review"
Assert-Lacks -Xml $review -Needle "Take photos" -Label "Review"
Save-Shot "review-orientation.png"

Write-Host "== Continue to Decorate =="
$next = Get-Centre -Xml $review -Desc "Next"
Invoke-Adb "shell input tap $($next.X) $($next.Y)"
Start-Sleep -Seconds 8
$decorate = Get-Ui
Assert-Has -Xml $decorate -Needle "Decorate" -Label "Decorate"
Assert-Has -Xml $decorate -Needle "Finish & Save" -Label "Decorate"
Save-Shot "decorate-overview.png"

Write-Host "== Open the Stickers tool =="
$stickers = Get-Centre -Xml $decorate -Desc "Stickers"
Invoke-Adb "shell input tap $($stickers.X) $($stickers.Y)"
Start-Sleep -Seconds 3
$tools = Get-Ui
Assert-Has -Xml $tools -Needle "Stickers" -Label "Decorate tools"
Save-Shot "decorate-tools.png"

Write-Host "== done =="