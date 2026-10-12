$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Push-Location $root
try {
  $issues = New-Object System.Collections.Generic.List[string]
  $files = Get-ChildItem -Recurse lib, test, web -File |
    Where-Object { $_.Extension -in '.dart', '.js', '.html', '.json' }
  foreach ($f in $files) {
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    $hasBom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    $hasReplacement = $text.Contains([char]0xFFFD)
    if ($hasBom -or $hasReplacement) {
      $rel = $f.FullName.Substring($PWD.Path.Length + 1)
      $issues.Add($rel + '  BOM=' + $hasBom + '  REPLACEMENT_CHAR=' + $hasReplacement)
    }
  }
  if ($issues.Count -eq 0) {
    Write-Output 'CLEAN: no BOMs and no replacement characters'
  } else {
    $issues | ForEach-Object { Write-Output $_ }
  }
} finally {
  Pop-Location
}