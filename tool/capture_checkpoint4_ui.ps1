# PhotoBooth V3 Checkpoint 4 - final UI verification and capture
#
# Drives the real app on the emulator through the redesigned surfaces:
#   Home -> Camera -> capture -> Review -> Decorate (default / filters /
#   zoomed / inspection) -> Export (Save & Share, success state) ->
#   Make Another -> Album (grid, full-screen inspection) -> Settings
#
# Same rules as the Checkpoint 3 driver: every step reads the live
# accessibility hierarchy and asserts the screen it is on before saving a
# screenshot for it.

param(
  [string]$OutputDir = "docs\v3\screenshots\checkpoint-4",
  [string]$Device = "emulator-5554",
  [string]$Package = "com.photobooth.photo_booth",
  [string]$VmPort = "",
  [string]$VmToken = "",
  [switch]$NoReset
)

$ErrorActionPreference = "Continue"
$adb = "C:\Users\jpas\AppData\Local\Android\Sdk\platform-tools\adb.exe"
$shots = 0

# event devices belong to root; the emulator image allows adb root, which
# restarts adbd with the privileges sendevent needs.
& $adb -s $Device root | Out-Null
Start-Sleep -Seconds 3

# Sets the editor preview to a 2.2x zoom through the app's own Dart VM
# service. The console `event send` channel never reaches the kernel on this
# image, adbd cannot run as root so `sendevent` is denied, and the framework
# `input` injector is single-pointer - so a raw two-finger pinch cannot be
# synthesised from the outside. The evaluation drives the very
# TransformationController the pinch would drive, which arms panning, shows
# the Fit bar and changes the strip exactly like a gesture does.
function Set-EditorZoom {
  # `tool/vm_call_ext.py` opens the app's DebugMode service extension
  # (ext.flutter.photoBooth.previewZoom) and drives the preview's own
  # TransformationController - the object an actual pinch moves.
  $out = & python (Join-Path $PSScriptRoot "vm_call_ext.py") $VmPort $VmToken "2.2" 2>&1
  Write-Host "  $out"
  if ($LASTEXITCODE -ne 0) { throw "zoom extension call failed" }
}

function Invoke-Adb {
  param([Parameter(Mandatory = $true)][string]$Command)
  $parts = $Command -split ' '
  & $adb -s $Device @parts
  if ($LASTEXITCODE -ne 0) { throw "adb $Command failed ($LASTEXITCODE)" }
}

function Get-UiHierarchy {
  for ($a = 0; $a -lt 5; $a++) {
    & $adb -s $Device shell uiautomator dump /sdcard/pb_c4_ui.xml | Out-Null
    & $adb -s $Device pull /sdcard/pb_c4_ui.xml "$env:TEMP\pb_c4_ui.xml" | Out-Null
    if ($LASTEXITCODE -eq 0 -and (Test-Path "$env:TEMP\pb_c4_ui.xml")) {
      return (Get-Content "$env:TEMP\pb_c4_ui.xml" -Raw)
    }
    Start-Sleep -Seconds 2
  }
  throw "uiautomator dump failed repeatedly"
}

# uiautomator escapes '&' as '&amp;' in content-desc, which broke a name
# match in an earlier checkpoint, so matches are substring-tolerant.
function Get-BoundsCenter {
  param([string]$Xml, [string]$ContentDesc, [switch]$Text)
  if ($Text) {
    $pattern = 'text="([^"]*' + [regex]::Escape($ContentDesc) + '[^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
    $offset = 0
  } else {
    $pattern = 'content-desc="([^"]*' + [regex]::Escape($ContentDesc) + '[^"]*)"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
    $offset = 1
  }
  $m = [regex]::Match($Xml, $pattern)
  if (-not $m.Success) { throw "node '$ContentDesc' not found" }
  $o = $offset
  $x1 = [int]$m.Groups[1 + $o].Value; $y1 = [int]$m.Groups[2 + $o].Value
  $x2 = [int]$m.Groups[3 + $o].Value; $y2 = [int]$m.Groups[4 + $o].Value
  return @{ X = [int](($x1 + $x2) / 2); Y = [int](($y1 + $y2) / 2) }
}

function Assert-Screen {
  param([string]$Xml, [string[]]$Expected, [string]$Label)
  foreach ($e in $Expected) {
    if ($Xml -notmatch [regex]::Escape($e)) {
      throw "verification failed: '$e' absent on $Label"
    }
  }
  Write-Host "  verified $Label contains: $($Expected -join ', ')"
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
  param([string]$Xml, [string]$ContentDesc, [switch]$Text, [int]$SettleSeconds = 5)
  $c = Get-BoundsCenter -Xml $Xml -ContentDesc $ContentDesc -Text:$Text
  Write-Host "  tap '$ContentDesc' at $($c.X),$($c.Y)"
  Invoke-Adb "shell input tap $($c.X) $($c.Y)"
  Start-Sleep -Seconds $SettleSeconds
  return Get-UiHierarchy
}

function Wait-ForScreen {
  param([string[]]$Markers, [string]$Label, [int]$TimeoutSeconds = 90)
  for ($t = 0; $t -lt $TimeoutSeconds; $t += 3) {
    $xml = Get-UiHierarchy
    $ok = $true
    foreach ($m in $Markers) {
      if ($xml -notmatch [regex]::Escape($m)) { $ok = $false; break }
    }
    if ($ok) {
      Write-Host "  verified $Label contains: $($Markers -join ', ')"
      return $xml
    }
    Start-Sleep -Seconds 3
  }
  throw "timed out after $TimeoutSeconds s waiting for $Label ($($Markers -join ', '))"
}

# A real two-finger pinch, written straight to the virtio touchscreen, since
# the framework-level `input` injector is single-pointer. The gesture moves
# both pointers apart over [steps] frames so the pinch out is sampled.
function Pinch-Out {
  param(
    [string]$DevPath,
    [int]$StartAx, [int]$StartBx, [int]$Y, [int]$EndAx, [int]$EndBx,
    [int]$Steps = 8
  )
  $xa0 = [int]([math]::Round($StartAx * 32767 / 1080))
  $xb0 = [int]([math]::Round($StartBx * 32767 / 1080))
  $xa1 = [int]([math]::Round($EndAx * 32767 / 1080))
  $xb1 = [int]([math]::Round($EndBx * 32767 / 1080))
  $yr = [int]([math]::Round($Y * 32767 / 2400))
  $script = @"
#!/system/bin/sh
se() { sendevent $DevPath `$1 `$2 `$3; }
se 3 47 0
se 3 57 100
se 3 53 $xa0
se 3 54 $yr
se 3 58 50
se 1 330 1
se 0 0 0
se 3 47 1
se 3 57 101
se 3 53 $xb0
se 3 54 $yr
se 3 58 50
se 0 0 0
i=0
while [ `$i -lt $Steps ]; do
  i=`$((i+1))
  xa=`$(( $xa0 + ( $xa1 - $xa0 ) * `$i / $Steps ))
  xb=`$(( $xb0 + ( $xb1 - $xb0 ) * `$i / $Steps ))
  se 3 47 0
  se 3 53 `$xa
  se 3 54 $yr
  se 3 47 1
  se 3 53 `$xb
  se 0 0 0
  sleep 0.06
done
se 3 47 0
se 3 57 4294967295
se 0 0 0
se 3 47 1
se 3 57 4294967295
se 0 0 0
se 1 330 0
se 0 0 0
"@
  Set-Content -Path "$env:TEMP\pinch.sh" -Value $script -NoNewline -Encoding Ascii
  Invoke-Adb "push $env:TEMP\pinch.sh /data/local/tmp/pinch.sh" | Out-Null
  Invoke-Adb "shell sh /data/local/tmp/pinch.sh" | Out-Null
  Start-Sleep -Seconds 2
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

if (-not $NoReset) {
  Write-Host "== resetting app to Home =="
  Invoke-Adb "shell am force-stop $Package"
  Invoke-Adb "shell pm grant $Package android.permission.CAMERA" | Out-Null
  Invoke-Adb "shell am start -n $Package/.MainActivity" | Out-Null
}
$ui = Wait-ForScreen -Markers @("Start Photo Booth") -Label "Home" -TimeoutSeconds 120

Write-Host "== Home -> Camera =="
$c = Get-BoundsCenter -Xml $ui -ContentDesc "Start Photo Booth"
Invoke-Adb "shell input tap $($c.X) $($c.Y)"
$ui = Wait-ForScreen -Markers @("Take photos") -Label "Camera preview" -TimeoutSeconds 120

Write-Host "== capturing the 4 CUT grid =="
$c = Get-BoundsCenter -Xml $ui -ContentDesc "Take photos"
Invoke-Adb "shell input tap $($c.X) $($c.Y)"
$ui = Wait-ForScreen -Markers @("Review", "4 photos", "Photo 4") -Label "post-capture Review"

Write-Host "== Review -> Decorate =="
$c = Get-BoundsCenter -Xml $ui -ContentDesc "Next"
Invoke-Adb "shell input tap $($c.X) $($c.Y)"
$ui = Wait-ForScreen -Markers @("Filters", "Original effect", "No effect") -Label "Decorate default"
Write-Host "  verified Original shows the 'No effect' readout"
Save-Screenshot -Name "05-decorate-default.png"

Write-Host "== selecting an effect for the filter capture =="
$c = Get-BoundsCenter -Xml $ui -ContentDesc "Warm effect"
Invoke-Adb "shell input tap $($c.X) $($c.Y)"
$ui = Wait-ForScreen -Markers @("Warm effect", "100%, Effect strength") -Label "Decorate with Warm selected"
Save-Screenshot -Name "07-decorate-filters.png"

Write-Host "== zooming the preview through the app's own VM service =="
if ($VmPort -eq "") { throw "VmPort/VmToken required: pinch gestures cannot be synthesised outside flutter run on this emulator" }
Set-EditorZoom
$ui = Wait-ForScreen -Markers @("Preview zoomed", "Reset preview zoom") -Label "zoomed editor" -TimeoutSeconds 45
Save-Screenshot -Name "06-decorate-zoomed.png"
Write-Host "== Fit restores =="
$c = Get-BoundsCenter -Xml $ui -ContentDesc "Reset preview zoom"
Invoke-Adb "shell input tap $($c.X) $($c.Y)"
Start-Sleep -Seconds 3

Write-Host "== inspecting the strip full screen =="
$ui = Get-UiHierarchy
$c = Get-BoundsCenter -Xml $ui -ContentDesc "Inspect the photostrip full screen"
Invoke-Adb "shell input tap $($c.X) $($c.Y)"
$ui = Wait-ForScreen -Markers @("Pinch to zoom, drag to pan", "Close") -Label "Decorate inspection"
Save-Screenshot -Name "03-decorate-inspection.png"
$c = Get-BoundsCenter -Xml $ui -ContentDesc "Close"
Invoke-Adb "shell input tap $($c.X) $($c.Y)"
Start-Sleep -Seconds 4

Write-Host "== Decorate -> Export =="
$ui = Get-UiHierarchy
$try = @("Finish &amp; Save", "Finish")
foreach ($t in $try) {
  try {
    $c = Get-BoundsCenter -Xml $ui -ContentDesc $t
    break
  } catch {
    Write-Host "  '$t' not found, trying next"
  }
}
Invoke-Adb "shell input tap $($c.X) $($c.Y)"
$ui = Wait-ForScreen -Markers @("Ready!", "Save to Photos", "Save or share it") -Label "Save & Share"
Save-Screenshot -Name "01-save-share.png"

Write-Host "== Save to gallery, capture the success state =="
$c = Get-BoundsCenter -Xml $ui -ContentDesc "Save to Photos"
Invoke-Adb "shell input tap $($c.X) $($c.Y)"
$ui = Wait-ForScreen -Markers @("Saved to Photos!", "Saved") -Label "save success"
Save-Screenshot -Name "08-save-success.png"

Write-Host "== Save to album so the album grid has content =="
$c = Get-BoundsCenter -Xml $ui -ContentDesc "Save to album"
Invoke-Adb "shell input tap $($c.X) $($c.Y)"
$ui = Wait-ForScreen -Markers @("Saved to album") -Label "album save" -TimeoutSeconds 120

Write-Host "== Make Another returns home =="
# The auto-dismissing snackbar floats above the bottom bar for ~4 s and can
# swallow the tap, so let it clear before pressing Make Another.
Start-Sleep -Seconds 7
$ui = Get-UiHierarchy
$c = Get-BoundsCenter -Xml $ui -ContentDesc "Make Another"
Invoke-Adb "shell input tap $($c.X) $($c.Y)"
$ui = Wait-ForScreen -Markers @("Start Photo Booth") -Label "Home again" -TimeoutSeconds 60

Write-Host "== Home -> Album =="
$c = Get-BoundsCenter -Xml $ui -ContentDesc "Album"
Invoke-Adb "shell input tap $($c.X) $($c.Y)"
$ui = Wait-ForScreen -Markers @("4 photos", "4 CUT", "Saved on this device only") -Label "Album grid"
Save-Screenshot -Name "02-album.png"

Write-Host "== Album -> full-screen inspection =="
$ui = Get-UiHierarchy
$c = Get-BoundsCenter -Xml $ui -ContentDesc "full screen"
Invoke-Adb "shell input tap $($c.X) $($c.Y)"
$ui = Wait-ForScreen -Markers @("Pinch to zoom, drag to pan", "Preview") -Label "album inspection" -TimeoutSeconds 120
Save-Screenshot -Name "03-album-inspection.png"
$c = Get-BoundsCenter -Xml $ui -ContentDesc "Close"
Invoke-Adb "shell input tap $($c.X) $($c.Y)"
Start-Sleep -Seconds 4
$ui = Get-UiHierarchy

Write-Host "== Album -> Home -> Settings =="
Invoke-Adb "shell input keyevent 4"
Start-Sleep -Seconds 3
$ui = Wait-ForScreen -Markers @("Start Photo Booth") -Label "Home" -TimeoutSeconds 60
$c = Get-BoundsCenter -Xml $ui -ContentDesc "Settings"
Invoke-Adb "shell input tap $($c.X) $($c.Y)"
$ui = Wait-ForScreen -Markers @("Camera", "Countdown", "Storage") -Label "Settings" -TimeoutSeconds 60
Save-Screenshot -Name "04-settings.png"

Write-Host ""
Write-Host "captured $shots screenshots under $OutputDir"
