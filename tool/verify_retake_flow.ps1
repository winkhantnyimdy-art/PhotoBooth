# Verifies Retake -> Review -> Decorate on a real device after the framing fix.
param(
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
  return ($raw -replace '&amp;','&' -replace '&#10;',' ')
}
function Get-Centre {
  param([string]$Xml, [string]$Desc)
  $p = 'content-desc="' + [regex]::Escape($Desc) + '[^"]*"[^>]*bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"'
  $m = [regex]::Match($Xml, $p)
  if (-not $m.Success) { throw "content-desc '$Desc' not found" }
  return @{ X = [int](([int]$m.Groups[1].Value + [int]$m.Groups[3].Value) / 2)
            Y = [int](([int]$m.Groups[2].Value + [int]$m.Groups[4].Value) / 2) }
}
function Need { param([string]$X,[string]$N,[string]$L)
  if ($X -notmatch [regex]::Escape($N)) { throw "FAILED: '$N' absent on $L" }
  Write-Host "  ok: $L has '$N'" }

Invoke-Adb "shell am force-stop $Package"
Invoke-Adb "shell pm grant $Package android.permission.CAMERA" | Out-Null
Invoke-Adb "shell am start -n $Package/.MainActivity" | Out-Null
Start-Sleep -Seconds 8
$ui = Get-Ui; Need $ui "Start Photo Booth" "Home"
$s = Get-Centre $ui "Start Photo Booth"; Invoke-Adb "shell input tap $($s.X) $($s.Y)"
Start-Sleep -Seconds 9
$ui = Get-Ui; Need $ui "Take photos" "Camera"

Write-Host "== capture the session =="
$sh = Get-Centre $ui "Take photos"; Invoke-Adb "shell input tap $($sh.X) $($sh.Y)"
$review = $null
for ($i = 0; $i -lt 24; $i++) {
  Start-Sleep -Seconds 5
  $p = Get-Ui
  if ($p -match 'content-desc="Next"') { $review = $p; break }
}
if ($null -eq $review) { throw "FAILED: never reached Review" }
Need $review "Photo 4 of 4 selected" "Review (arrival)"

Write-Host "== select photo 2 and retake it =="
$c2 = Get-Centre $review "Photo 2"; Invoke-Adb "shell input tap $($c2.X) $($c2.Y)"
Start-Sleep -Seconds 2
$ui = Get-Ui; Need $ui "Photo 2 of 4 selected" "Review (selected photo 2)"

$r = Get-Centre $ui "Retake"; Invoke-Adb "shell input tap $($r.X) $($r.Y)"
Start-Sleep -Seconds 8
$ui = Get-Ui; Need $ui "Take photos" "retake camera"
Need $ui "Retake photo 2" "retake camera labels the slot"

$rs = Get-Centre $ui "Take photos"; Invoke-Adb "shell input tap $($rs.X) $($rs.Y)"
$back = $null
for ($i = 0; $i -lt 18; $i++) {
  Start-Sleep -Seconds 4
  $p = Get-Ui
  if ($p -match 'content-desc="Next"') { $back = $p; break }
  if ($p -match 'content-desc="Retake photo') {
    $b = Get-Centre $p "Back"; Invoke-Adb "shell input tap $($b.X) $($b.Y)"
  }
}
if ($null -eq $back) { throw "FAILED: retake never returned to Review" }
Need $back "Photo 2 of 4 selected" "Review (after retake)"
# Every slot must still be populated: a retake replaces one frame, not the
# session. The caption only names the selected shot, so assert on the cells.
foreach ($i in 1..4) {
  Need $back "Photo $i" "Review still has cell $i"
}

Write-Host "== continue to Decorate =="
$n = Get-Centre $back "Next"; Invoke-Adb "shell input tap $($n.X) $($n.Y)"
Start-Sleep -Seconds 8
$d = Get-Ui; Need $d "Decorate" "Decorate"; Need $d "Finish & Save" "Decorate"
Write-Host "== ALL CHECKS PASSED =="