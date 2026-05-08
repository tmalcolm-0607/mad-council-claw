$ErrorActionPreference = 'Stop'
$Fixtures = Get-ChildItem -Path "$PSScriptRoot/fixtures" -Filter "*.md" -ErrorAction SilentlyContinue
$Failures = 0
foreach ($f in $Fixtures) {
    $expectedPath = Join-Path $PSScriptRoot "expected/$($f.Name)"
    if (-not (Test-Path $expectedPath)) { Write-Warning "No expected for $($f.Name)"; $Failures++; continue }
    Write-Host "OK: $($f.Name)"
}
if ($Failures -gt 0) { Write-Error "$Failures missing expected"; exit 1 }
Write-Host "All present."
