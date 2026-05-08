param(
  [string]$ScratchPath = ".mad/scratch",
  [int]$RetentionDays = 7,
  [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

$root = Resolve-Path $ScratchPath -ErrorAction SilentlyContinue
if (-not $root) {
  Write-Host "Scratch path not found: $ScratchPath"
  exit 0
}

$cutoff = (Get-Date).AddDays(-$RetentionDays)
$allowedExtensions = @('.ps1', '.sh', '.js', '.ts', '.py', '.cmd', '.bat', '.log', '.txt')

$files = Get-ChildItem -Path $root -Recurse -File
foreach ($file in $files) {
  $ext = $file.Extension.ToLowerInvariant()
  $isAllowedType = $allowedExtensions -contains $ext
  $isExpired = $file.LastWriteTime -lt $cutoff

  if (-not $isAllowedType -or $isExpired) {
    if ($WhatIf) {
      Write-Host "Would remove $($file.FullName)"
    } else {
      Remove-Item -LiteralPath $file.FullName -Force -ErrorAction SilentlyContinue
      Write-Host "Removed $($file.FullName)"
    }
  }
}

$dirs = Get-ChildItem -Path $root -Recurse -Directory | Sort-Object FullName -Descending
foreach ($dir in $dirs) {
  if ((Get-ChildItem -Path $dir.FullName -Force | Measure-Object).Count -eq 0) {
    if ($WhatIf) {
      Write-Host "Would remove empty dir $($dir.FullName)"
    } else {
      Remove-Item -LiteralPath $dir.FullName -Force -ErrorAction SilentlyContinue
      Write-Host "Removed empty dir $($dir.FullName)"
    }
  }
}

Write-Host "Scratch cleanup complete."
