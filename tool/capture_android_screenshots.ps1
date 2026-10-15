# PhotoBooth V3 screenshot capture
#
# Root cause of the Checkpoint 1 failure was a hardcoded tap coordinate
# (540,560) that landed on the Home subtitle, which is not clickable. This
# script instead reads the live accessibility hierarchy, locates the control by
# its content-desc, taps its real centre, and asserts the resulting screen
# before saving a screenshot. It never saves a screenshot it has not verified.

param(
  [string]$OutputDir = "docs\v3\screenshots\checkpoint-1",
  [string]$Device = "emulator-5554",
  [string]$Package = "com.photobooth.photo_booth"
)

$ErrorActionPreference = "Stop"
$adb = "C:\Users\jpas\AppData\Local\Android\Sdk\platform-tools\adb.exe"

function Invoke-Adb {
  # The command arrives as one string and is split here so that flags such as
  # screencap's "-p" are passed to adb verbatim and never swallowed by
  # PowerShell's own parameter binding.
  param([Parameter(Mandatory = $true)][string]$Command)
  $parts = $Command -split ' '
  & $adb -s $Device @parts
  if ($LASTEXITCODE -ne 0) { throw "adb $Command failed ($LASTEXITCODE)" }
}

function Get-UiHierarchy {
  Invoke-Adb "shell uiautomator dump /sdcard/pb_ui.xml" | Out-Null
  Invoke-Adb "pull /sdcard/pb_ui.xml $env:TEMP\pb_ui.xml" | Out-Null
  return Get-Content "$env:TEMP\pb_ui.xml" -Raw
}

function Get-BoundsCenter {
  param([string]$Xml, [string]$ContentDesc)
  $pattern = 'content-desc="' + [regex]::Escape($ContentDesc) + '"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
  $m = [regex]::Match($Xml, $pattern)
  if (-not $m.Success) { throw "content-desc '$ContentDesc' not found in hierarchy" }
  $x1 = [int]$m.Groups[1].Value; $y1 = [int]$m.Groups[2].Value
  $x2 = [int]$m.Groups[3].Value; $y2 = [int]$m.Groups[4].Value
  return @{ X = [int](($x1 + $x2) / 2); Y = [int](($y1 + $y2) / 2) }
}

function Save-Screenshot {
  param([string]$Name)
  $path = Join-Path $OutputDir $Name
  # screencap runs on-device, then the PNG is pulled to the repo. Both steps
  # are single command strings so screencap's "-p" flag survives.
  Invoke-Adb "shell screencap -p /sdcard/$Name"
  # Repo and temp paths contain no spaces, so no quoting is needed and the
  # simple space split inside Invoke-Adb is safe.
  Invoke-Adb "pull /sdcard/$Name $path" | Out-Null
  Write-Host "saved $path"
}

function Assert-Screen {
  param([string]$Xml, [string]$Expected, [string]$Label)
  if ($Xml -notmatch [regex]::Escape($Expected)) {
    throw "verification failed: '$Expected' absent on $Label"
  }
  Write-Host "verified $Label contains '$Expected'"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

Write-Host "== resetting app to Home =="
Invoke-Adb "shell am force-stop $Package"
Invoke-Adb "shell pm grant $Package android.permission.CAMERA" | Out-Null
Invoke-Adb "shell am start -n $Package/.MainActivity" | Out-Null
Start-Sleep -Seconds 8

$homeXml = Get-UiHierarchy
Assert-Screen -Xml $homeXml -Expected "Start Photo Booth" -Label "Home"
Save-Screenshot "home.png"

Write-Host "== navigating to Camera =="
$start = Get-BoundsCenter -Xml $homeXml -ContentDesc "Start Photo Booth"
Write-Host "Start Photo Booth centre = $($start.X),$($start.Y)"
Invoke-Adb "shell input tap $($start.X) $($start.Y)"
Start-Sleep -Seconds 8

$camera = Get-UiHierarchy
Assert-Screen -Xml $camera -Expected "CUT" -Label "Camera"
Save-Screenshot "camera.png"

Write-Host "== waiting for camera preview to initialise =="
Start-Sleep -Seconds 8
$preview = Get-UiHierarchy
Assert-Screen -Xml $preview -Expected "Take photos" -Label "Camera preview"
Save-Screenshot "camera-preview.png"

Write-Host "== done =="
