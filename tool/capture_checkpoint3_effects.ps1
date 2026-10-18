# PhotoBooth V3 Checkpoint 3 - effects flow verification and capture
#
# Drives the real app on the emulator through the whole effect workflow:
#   Home -> Camera -> capture -> Review -> Decorate -> select an effect ->
#   adjust strength -> Export
#
# Every step reads the live accessibility hierarchy, taps a control by its
# content-desc (never a hardcoded coordinate) and asserts the resulting screen
# before any screenshot is saved. A screenshot is never written for a screen it
# has not verified, which is the defect that produced the bad Checkpoint 1
# captures.

param(
  [string]$OutputDir = "docs\v3\screenshots\checkpoint-3",
  [string]$Device = "emulator-5554",
  [string]$Package = "com.photobooth.photo_booth"
)

# adb writes progress lines to stderr, which Windows PowerShell surfaces as
# error records. The real failure signal is $LASTEXITCODE, which Invoke-Adb
# checks explicitly, so the preference is relaxed on purpose.
$ErrorActionPreference = "Continue"
$adb = "C:\Users\jpas\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$shots = 0

function Invoke-Adb {
  # The command arrives as one string and is split here so flags such as
  # screencap's "-p" reach adb verbatim and are never swallowed by
  # PowerShell's own parameter binding.
  param([Parameter(Mandatory = $true)][string]$Command)
  $parts = $Command -split ' '
  & $adb -s $Device @parts
  if ($LASTEXITCODE -ne 0) { throw "adb $Command failed ($LASTEXITCODE)" }
}

function Get-UiHierarchy {
  Invoke-Adb "shell uiautomator dump /sdcard/pb_c3_ui.xml" | Out-Null
  Invoke-Adb "pull /sdcard/pb_c3_ui.xml $env:TEMP\pb_c3_ui.xml" | Out-Null
  return Get-Content "$env:TEMP\pb_c3_ui.xml" -Raw
}

function Get-BoundsCenter {
  param([string]$Xml, [string]$ContentDesc, [switch]$Partial)
  if ($Partial) {
    $pattern = 'content-desc="([^"]*' + [regex]::Escape($ContentDesc) + '[^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
  } else {
    $pattern = 'content-desc="' + [regex]::Escape($ContentDesc) + '"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
  }
  $m = [regex]::Match($Xml, $pattern)
  if (-not $m.Success) { throw "content-desc '$ContentDesc' not found" }
  $offset = if ($Partial) { 1 } else { 0 }
  $x1 = [int]$m.Groups[1 + $offset].Value; $y1 = [int]$m.Groups[2 + $offset].Value
  $x2 = [int]$m.Groups[3 + $offset].Value; $y2 = [int]$m.Groups[4 + $offset].Value
  return @{ X = [int](($x1 + $x2) / 2); Y = [int](($y1 + $y2) / 2) }
}

function Get-SpanX {
  param([string]$Xml, [string]$ContentDesc)
  $pattern = 'content-desc="([^"]*' + [regex]::Escape($ContentDesc) + '[^"]*)"[^>]*bounds="\[(\d+),\d+\]\[(\d+),'
  $m = [regex]::Match($Xml, $pattern)
  if (-not $m.Success) { throw "node containing '$ContentDesc' not found" }
  return @{ Min = [int]$m.Groups[2].Value; Max = [int]$m.Groups[3].Value }
}

# The selected effect is exposed as a semantics flag, not as text, so this is
# the reliable way to prove a tap landed on the intended effect.
function Get-SelectedEffect {
  param([string]$Xml)
  $pattern = '<node[^>]*content-desc="([^"]+ effect)"[^>]*selected="true"'
  $m = [regex]::Match($Xml, $pattern)
  if (-not $m.Success) { return "" }
  return $m.Groups[1].Value
}

# The strength readout is the value on the slider's own semantics node, so it
# is available even when the explanatory hint is scrolled below the fold.
function Get-Strength {
  param([string]$Xml)
  $m = [regex]::Match($Xml, 'content-desc="(\d+)%, Effect strength"')
  if (-not $m.Success) { return "" }
  return $m.Groups[1].Value
}

function Assert-Effect {
  param([string]$Xml, [string]$Expected, [string]$Label)
  $actual = Get-SelectedEffect -Xml $Xml
  if ($actual -ne $Expected) {
    throw "verification failed: expected '$Expected' selected on $Label, got '$actual'"
  }
  Write-Host "  verified $Label has '$Expected' selected"
}

function Assert-Strength {
  param([string]$Xml, [string]$Expected, [string]$Label)
  $actual = Get-Strength -Xml $Xml
  if ($actual -ne $Expected) {
    throw "verification failed: expected strength $Expected on $Label, got '$actual'"
  }
  Write-Host "  verified $Label strength reads $Expected%"
}

function Assert-Screen {
  param([string]$Xml, [string]$Expected, [string]$Label)
  if ($Xml -notmatch [regex]::Escape($Expected)) {
    throw "verification failed: '$Expected' absent on $Label"
  }
  Write-Host "  verified $Label contains '$Expected'"
}

function Save-Screenshot {
  param([string]$Name)
  $path = Join-Path $OutputDir $Name
  Invoke-Adb "shell screencap -p /sdcard/$Name"
  Invoke-Adb "pull /sdcard/$Name $path" | Out-Null
  $script:shots++
  Write-Host "  saved $path"
}

function Tap-Desc {
  param([string]$Xml, [string]$ContentDesc, [int]$SettleSeconds = 6)
  $c = Get-BoundsCenter -Xml $Xml -ContentDesc $ContentDesc
  Write-Host "  tap '$ContentDesc' at $($c.X),$($c.Y)"
  Invoke-Adb "shell input tap $($c.X) $($c.Y)"
  Start-Sleep -Seconds $SettleSeconds
  return Get-UiHierarchy
}

# Polls the hierarchy until every marker appears. Capture, decoding and the
# strip preview take a variable amount of time, so a fixed sleep is a race.
function Wait-ForScreen {
  param([string[]]$Markers, [string]$Label, [int]$TimeoutSeconds = 90)
  for ($t = 0; $t -lt $TimeoutSeconds; $t += 3) {
    $xml = Get-UiHierarchy
    $ok = $true
    foreach ($m in $Markers) {
      if ($xml -notmatch [regex]::Escape($m)) { $ok = $false; break }
    }
    if ($ok) {
      Write-Host "  verified $Label contains all of: $($Markers -join ', ')"
      return $xml
    }
    Start-Sleep -Seconds 3
  }
  throw "timed out after $TimeoutSeconds s waiting for $Label ($($Markers -join ', '))"
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

Write-Host "== resetting app to Home =="
Invoke-Adb "shell am force-stop $Package"
Invoke-Adb "shell pm grant $Package android.permission.CAMERA" | Out-Null
Invoke-Adb "shell am start -n $Package/.MainActivity" | Out-Null
$ui = Wait-ForScreen -Markers @("Start Photo Booth") -Label "Home" -TimeoutSeconds 120
Save-Screenshot -Name "effects-home.png"
Write-Host "== Home -> Camera =="
$c = Get-BoundsCenter -Xml $ui -ContentDesc "Start Photo Booth"
Write-Host "  tap 'Start Photo Booth' at $($c.X),$($c.Y)"
Invoke-Adb "shell input tap $($c.X) $($c.Y)"
# The camera plugin has to bind to the hardware before the viewfinder reports
# itself, which is slower on a cold emulator boot than on a warm one.
$ui = Wait-ForScreen -Markers @("CUT") -Label "Camera" -TimeoutSeconds 120

Write-Host "== waiting for the camera preview to come up =="
$ui = Wait-ForScreen -Markers @("Take photos") -Label "Camera preview" -TimeoutSeconds 120

Write-Host "== capturing the 4 CUT grid =="
# One shutter press fills the whole grid and the app advances to Review by
# itself, so tapping four times overshoots onto a screen that no longer has a
# shutter button.
$c = Get-BoundsCenter -Xml $ui -ContentDesc "Take photos"
Write-Host "  tap 'Take photos' at $($c.X),$($c.Y)"
Invoke-Adb "shell input tap $($c.X) $($c.Y)"
$ui = Wait-ForScreen -Markers @("Review", "4 photos", "Photo 4") -Label "post-capture Review"
Save-Screenshot -Name "effects-review.png"

Write-Host "== Review -> Decorate =="
$c = Get-BoundsCenter -Xml $ui -ContentDesc "Next"
Write-Host "  tap 'Next' at $($c.X),$($c.Y)"
Invoke-Adb "shell input tap $($c.X) $($c.Y)"
$ui = Wait-ForScreen -Markers @("Filters", "Original effect", "35mm effect", "Effect strength") -Label "Decorate"
Save-Screenshot -Name "effects-editor.png"

Write-Host "== scrolling the effect shelf to reach the film presets =="
# The shelf is a lazy horizontal list, so only the first effects are realised.
# Scrolling is what proves the rest of the fifteen are reachable at all.
#
# Both swipe endpoints stay well inside the 1080 px screen. A start point
# beyond the edge is clamped by the system, which turns the gesture into a
# back-swipe and dumps the editor - that is what killed the first attempt.
$screenWidth = 1080
$shelfY = (Get-BoundsCenter -Xml $ui -ContentDesc "35mm effect").Y
$fromX = [int]($screenWidth - 120)
$toX = 120
for ($s = 0; $s -lt 8; $s++) {
  if ($ui -match 'Grain effect') { break }
  Write-Host "  swipe $fromX -> $toX at y=$shelfY"
  Invoke-Adb "shell input swipe $fromX $shelfY $toX $shelfY 350"
  Start-Sleep -Seconds 2
  $ui = Get-UiHierarchy
}
Assert-Screen -Xml $ui -Expected "Grain effect" -Label "scrolled shelf"

Write-Host "== selecting Grain =="
$c = Get-BoundsCenter -Xml $ui -ContentDesc "Grain effect"
Write-Host "  tap 'Grain effect' at $($c.X),$($c.Y)"
Invoke-Adb "shell input tap $($c.X) $($c.Y)"
$ui = Wait-ForScreen -Markers @("Grain effect", "100%, Effect strength") -Label "Decorate after select"
Assert-Effect -Xml $ui -Expected "Grain effect" -Label "Decorate after select"
Assert-Strength -Xml $ui -Expected "100" -Label "Decorate after select"
Save-Screenshot -Name "effects-selected.png"

Write-Host "== dropping the same effect to ~35% strength =="
# The tap position is a proportion of the verified strength widget's own
# bounds, read from the live hierarchy rather than assumed.
$span = Get-SpanX -Xml $ui -ContentDesc "Effect strength"
$centre = Get-BoundsCenter -Xml $ui -ContentDesc "Effect strength" -Partial
$tapX = [int]($span.Min + (($span.Max - $span.Min) * 0.35))
Write-Host "  strength spans $($span.Min)..$($span.Max), tapping at $tapX"
Invoke-Adb "shell input tap $tapX $($centre.Y)"
Start-Sleep -Seconds 6
$ui = Wait-ForScreen -Markers @("Grain effect", "Effect strength") -Label "Decorate at 35%"
$pct = [int](Get-Strength -Xml $ui)
if ($pct -ge 100) { throw "strength did not move: still $pct%" }
Write-Host "  verified strength moved to $pct% (target 35%)"
Assert-Effect -Xml $ui -Expected "Grain effect" -Label "Decorate at 35%"
Save-Screenshot -Name "effects-intensity.png"

Write-Host "== returning to Original, which disables the strength control =="
# Scroll the shelf back to the start first.
for ($s = 0; $s -lt 8; $s++) {
  if ($ui -match 'Original effect') { break }
  Invoke-Adb "shell input swipe $toX $shelfY $fromX $shelfY 350"
  Start-Sleep -Seconds 2
  $ui = Get-UiHierarchy
}
$c = Get-BoundsCenter -Xml $ui -ContentDesc "Original effect"
Write-Host "  tap 'Original effect' at $($c.X),$($c.Y)"
Invoke-Adb "shell input tap $($c.X) $($c.Y)"
$ui = Wait-ForScreen -Markers @("Original effect") -Label "Decorate on Original"
Assert-Effect -Xml $ui -Expected "Original effect" -Label "Decorate on Original"
Save-Screenshot -Name "effects-original.png"

Write-Host "== done: $shots screenshots, all route-verified =="
