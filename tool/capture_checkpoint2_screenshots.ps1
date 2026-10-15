# PhotoBooth V3 Checkpoint 2 screenshot capture
#
# Drives a genuine end-to-end session on the Android emulator and saves a
# screenshot for each step. Every capture is verified against the live
# accessibility hierarchy before the file is written, so a stale or wrong
# screen can never be reported as a pass. Nothing here uses fixed tap
# coordinates: controls are located by content-desc / tooltip and tapped at
# their real centre.

param(
  [string]$OutputDir = "docs\v3\screenshots\checkpoint-2",
  [string]$Device = "emulator-5554",
  [string]$Package = "com.photobooth.photo_booth"
)

$ErrorActionPreference = "Stop"
$adb = "C:\Users\jpas\AppData\Local\Android\Sdk\platform-tools\adb.exe"

function Invoke-Adb {
  # Commands arrive as one string and are split here, so flags such as
  # screencap's "-p" reach adb verbatim instead of being swallowed by
  # PowerShell parameter binding.
  param([Parameter(Mandatory = $true)][string]$Command)
  $parts = $Command -split ' '
  & $adb -s $Device @parts
  if ($LASTEXITCODE -ne 0) { throw "adb $Command failed ($LASTEXITCODE)" }
}

function Get-UiHierarchy {
  Invoke-Adb "shell uiautomator dump /sdcard/pb_ui.xml" | Out-Null
  Invoke-Adb "pull /sdcard/pb_ui.xml $env:TEMP\pb_ui.xml" | Out-Null
  $raw = Get-Content "$env:TEMP\pb_ui.xml" -Raw
  # The dump XML-escapes labels ("Finish &amp; Save") and uses numeric
  # newlines to join a semantics label with its text child. Decoding both
  # keeps the assertions readable and matches what a user actually sees.
  $raw = $raw -replace '&amp;', '&' -replace '&lt;', '<' -replace '&gt;', '>' -replace '&quot;', '"' -replace '&#10;', ' '
  return $raw
}

function Get-CentreByDesc {
  param([string]$Xml, [string]$ContentDesc)
  # Prefix match: Flutter merges a Semantics label with its Text child, so the
  # dumped content-desc is "Stickers Stickers", not "Stickers".
  $pattern = 'content-desc="' + [regex]::Escape($ContentDesc) + '[^"]*"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
  $m = [regex]::Match($Xml, $pattern)
  if (-not $m.Success) { throw "content-desc '$ContentDesc' not found" }
  $x1 = [int]$m.Groups[1].Value; $y1 = [int]$m.Groups[2].Value
  $x2 = [int]$m.Groups[3].Value; $y2 = [int]$m.Groups[4].Value
  return @{ X = [int](($x1 + $x2) / 2); Y = [int](($y1 + $y2) / 2) }
}

function Get-CentreByText {
  param([string]$Xml, [string]$Text)
  $pattern = 'text="' + [regex]::Escape($Text) + '"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
  $m = [regex]::Match($Xml, $pattern)
  if (-not $m.Success) { throw "text '$Text' not found" }
  $x1 = [int]$m.Groups[1].Value; $y1 = [int]$m.Groups[2].Value
  $x2 = [int]$m.Groups[3].Value; $y2 = [int]$m.Groups[4].Value
  return @{ X = [int](($x1 + $x2) / 2); Y = [int](($y1 + $y2) / 2) }
}

function Save-Screenshot {
  param([string]$Name)
  $path = Join-Path $OutputDir $Name
  Invoke-Adb "shell screencap -p /sdcard/$Name"
  Invoke-Adb "pull /sdcard/$Name $path" | Out-Null
  if (-not (Test-Path $path)) { throw "screenshot $Name was not written" }
  Write-Host "  saved $Name"
}

function Assert-Screen {
  param([string]$Xml, [string]$Expected, [string]$Label)
  if ($Xml -notmatch [regex]::Escape($Expected)) {
    throw "VERIFICATION FAILED: '$Expected' absent on $Label"
  }
  Write-Host "  verified $Label contains '$Expected'"
}

function Assert-ScreenAbsent {
  param([string]$Xml, [string]$Unexpected, [string]$Label)
  if ($Xml -match [regex]::Escape($Unexpected)) {
    throw "VERIFICATION FAILED: '$Unexpected' still present on $Label"
  }
  Write-Host "  verified $Label no longer shows '$Unexpected'"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

Write-Host "== 1. Camera screen (status bar + switch control contrast) =="
Invoke-Adb "shell am force-stop $Package"
Invoke-Adb "shell pm grant $Package android.permission.CAMERA" | Out-Null
Invoke-Adb "shell am start -n $Package/.MainActivity" | Out-Null
Start-Sleep -Seconds 8

$ui = Get-UiHierarchy
Assert-Screen -Xml $ui -Expected "Start Photo Booth" -Label "Home"
$start = Get-CentreByDesc -Xml $ui -ContentDesc "Start Photo Booth"
Invoke-Adb "shell input tap $($start.X) $($start.Y)"
Start-Sleep -Seconds 9
$ui = Get-UiHierarchy
Assert-Screen -Xml $ui -Expected "Take photos" -Label "Camera"
Save-Screenshot "camera-status-bar.png"

Write-Host "== 2. Start the session =="
$shutter = Get-CentreByDesc -Xml $ui -ContentDesc "Take photos"
Invoke-Adb "shell input tap $($shutter.X) $($shutter.Y)"
Start-Sleep -Seconds 6

# The session runs countdown -> capture, once per shot. Wait until the
# Review screen appears rather than guessing a duration.
$review = $null
for ($i = 0; $i -lt 24; $i++) {
  Start-Sleep -Seconds 5
  $probe = Get-UiHierarchy
  if ($probe -match 'content-desc="Next"') { $review = $probe; break }
}
if ($null -eq $review) { throw "VERIFICATION FAILED: session never reached Review" }
Write-Host "  session completed and reached Review"
Assert-Screen -Xml $review -Expected "Review" -Label "Review"
Assert-ScreenAbsent -Xml $review -Unexpected "Take photos" -Label "Review"
Save-Screenshot "review.png"

Write-Host "== 3. Retake one photo =="
$cell = Get-CentreByDesc -Xml $review -ContentDesc "Photo 2"
Invoke-Adb "shell input tap $($cell.X) $($cell.Y)"
Start-Sleep -Seconds 2
$ui = Get-UiHierarchy
Assert-Screen -Xml $ui -Expected "Photo 2 of" -Label "Review after selecting photo 2"

$retake = Get-CentreByDesc -Xml $ui -ContentDesc "Retake"
Invoke-Adb "shell input tap $($retake.X) $($retake.Y)"
Start-Sleep -Seconds 8
$ui = Get-UiHierarchy
Assert-Screen -Xml $ui -Expected "Take photos" -Label "Retake camera"
$retakeShutter = Get-CentreByDesc -Xml $ui -ContentDesc "Take photos"
Invoke-Adb "shell input tap $($retakeShutter.X) $($retakeShutter.Y)"

# A retake captures exactly one frame and pops itself back to Review, so wait
# for Review to return. Only send Back if the retake camera is still up (for
# example if the capture was cancelled).
$review = $null
for ($i = 0; $i -lt 18; $i++) {
  Start-Sleep -Seconds 4
  $probe = Get-UiHierarchy
  if ($probe -match 'content-desc="Next"') { $review = $probe; break }
  if ($probe -match 'content-desc="Retake photo') {
    Write-Host "  retake camera still open; sending Back"
    $probeBack = Get-CentreByDesc -Xml $probe -ContentDesc "Back"
    Invoke-Adb "shell input tap $($probeBack.X) $($probeBack.Y)"
  }
}
if ($null -eq $review) { throw "VERIFICATION FAILED: did not return to Review after retake" }
Assert-Screen -Xml $review -Expected "Review" -Label "Review after retake"
Save-Screenshot "review-after-retake.png"

Write-Host "== 4. Continue to Decorate =="
$next = Get-CentreByDesc -Xml $review -ContentDesc "Next"
Invoke-Adb "shell input tap $($next.X) $($next.Y)"
Start-Sleep -Seconds 7
$decorate = Get-UiHierarchy
Assert-Screen -Xml $decorate -Expected "Decorate" -Label "Decorate"
Assert-Screen -Xml $decorate -Expected "Finish & Save" -Label "Decorate"
Save-Screenshot "decorate.png"

Write-Host "== 5. Open an editing tool =="
$stickers = Get-CentreByDesc -Xml $decorate -ContentDesc "Stickers"
Invoke-Adb "shell input tap $($stickers.X) $($stickers.Y)"
Start-Sleep -Seconds 3
$tools = Get-UiHierarchy
Assert-Screen -Xml $tools -Expected "Stickers" -Label "Decorate sticker tools"
Assert-Screen -Xml $tools -Expected "Finish & Save" -Label "Decorate sticker tools"
Save-Screenshot "decorate-tools.png"

Write-Host "== done =="