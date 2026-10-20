$ErrorActionPreference = "Stop"

function Remove-Utf8BomFromFile {
  param([Parameter(Mandatory = $true)][string]$Path)

  $bytes = [System.IO.File]::ReadAllBytes($Path)
  if ($bytes.Length -lt 2) { return $false }

  $changed = $false

  while ($true) {
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
      $bytes = $bytes[3..($bytes.Length - 1)]
      $changed = $true
      continue
    }

    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFF -and $bytes[1] -eq 0xFE) {
      $bytes = $bytes[2..($bytes.Length - 1)]
      $changed = $true
      continue
    }

    if ($bytes.Length -ge 2 -and $bytes[0] -eq 0xFE -and $bytes[1] -eq 0xFF) {
      $bytes = $bytes[2..($bytes.Length - 1)]
      $changed = $true
      continue
    }

    break
  }

  if (-not $changed) { return $false }

  [System.IO.File]::WriteAllBytes($Path, $bytes)
  return $true
}

$Root = Split-Path -Parent $PSScriptRoot

$targets = @(
  (Join-Path $Root "lib"),
  (Join-Path $Root "test"),
  (Join-Path $Root "integration_test")
) | Where-Object { Test-Path $_ }

$changed = New-Object System.Collections.Generic.List[string]

foreach ($dir in $targets) {
  $files = Get-ChildItem -Path $dir -Recurse -File -Filter "*.dart" -Force
  foreach ($f in $files) {
    if (Remove-Utf8BomFromFile -Path $f.FullName) {
      $relative = $f.FullName.Substring($Root.Length).TrimStart('\')
      $changed.Add($relative) | Out-Null
    }
  }
}

if ($changed.Count -eq 0) {
  Write-Output "No UTF-8 BOM found in scanned Dart files."
} else {
  Write-Output "Removed UTF-8 BOM from:"
  $changed | Sort-Object | ForEach-Object { Write-Output $_ }
}

