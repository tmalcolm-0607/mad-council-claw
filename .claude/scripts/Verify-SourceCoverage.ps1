<#
.SYNOPSIS
Verify that every FR-prefixed identifier in the source spec appears at least
once in the produced spec. Replaces the LLM-driven Step 6 source-coverage
scan in /mad-spec body with a deterministic grep pass.

.DESCRIPTION
Backward-compatible thin wrapper around .claude/scripts/Verify-Coverage.ps1.

The unified Verify-Coverage.ps1 engine handles arbitrary regex-based
coverage verification. This wrapper preserves the original FR-specific
contract (legacy JSON shape, ExpectedPrefixes parameter, exit codes) so
existing callers of /mad-spec Step 6 continue to work unchanged.

The wrapper:
  1. Calls Verify-Coverage.ps1 with FR regex hardcoded.
  2. Reads the engine's JSON output.
  3. Translates the structured result to the legacy JSON shape:
        - source_fr_count, produced_fr_count
        - source_minus_produced, produced_minus_source
        - expected_prefixes, expected_prefix_gaps
        - rows with fr_id / in_source / in_produced / ok
  4. Adds the ExpectedPrefixes prefix-coverage check (the engine does
     not handle this; it is FR-specific).
  5. Writes the legacy JSON to OutputJson and prints the same human-
     readable summary the original script printed.

Exit codes: 0 = full coverage; 2 = gaps; 3 = setup error.

.PARAMETER SourcePath
Path to the source feature description / iter-N spec.

.PARAMETER ProducedPath
Path to the produced canonical spec.md.

.PARAMETER OutputJson
Path to write the JSON result. Defaults to .mad/scratch/source-coverage-{ts}.json.

.PARAMETER ExpectedPrefixes
Optional comma-separated list of FR prefixes to require (e.g.
"CORE,COST,AUDIT,RING"). If provided, a missing prefix is itself a gap.

.EXAMPLE
pwsh -NoProfile -File .claude/scripts/Verify-SourceCoverage.ps1 `
  -SourcePath .mad/work-items/collab-engine/inline-snapshot/spec.md `
  -ProducedPath specs/15-collab-engine-canonical-e/spec.md

.NOTES
This wrapper exists for backward compatibility. New skills should call
Verify-Coverage.ps1 directly with their own SourceIdRegex.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string]$SourcePath,
  [Parameter(Mandatory = $true)] [string]$ProducedPath,
  [string]$OutputJson = "",
  [string]$ExpectedPrefixes = ""
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $SourcePath)) {
  Write-Error "Source spec not found: $SourcePath"
  exit 3
}
if (-not (Test-Path $ProducedPath)) {
  Write-Error "Produced spec not found: $ProducedPath"
  exit 3
}

# Default output path under .mad/scratch/
if ([string]::IsNullOrWhiteSpace($OutputJson)) {
  $ts = (Get-Date).ToString("yyyyMMdd-HHmmss")
  $ScratchDir = ".mad/scratch"
  if (-not (Test-Path $ScratchDir)) {
    New-Item -ItemType Directory -Path $ScratchDir -Force | Out-Null
  }
  $OutputJson = Join-Path $ScratchDir "source-coverage-$ts.json"
}

$FrRegex = 'FR-[A-Z][A-Z0-9-]*-\d+'

# --- 1. Delegate to unified engine ---------------------------------------

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnginePath = Join-Path $ScriptDir 'Verify-Coverage.ps1'

if (-not (Test-Path $EnginePath)) {
  Write-Error "Unified engine not found: $EnginePath"
  exit 3
}

# Engine writes its own JSON; we capture path and re-read for translation.
$ts2 = (Get-Date).ToString("yyyyMMdd-HHmmss-fff")
$engineJsonPath = Join-Path ([System.IO.Path]::GetDirectoryName($OutputJson)) "engine-$ts2.json"

# Toggle to Continue for native PS-script invocation; check $LASTEXITCODE.
$prevPref = $ErrorActionPreference
$ErrorActionPreference = 'Continue'

& pwsh -NoProfile -File $EnginePath `
  -SourcePath $SourcePath `
  -TargetPaths $ProducedPath `
  -SourceIdRegex $FrRegex `
  -OutputJson $engineJsonPath `
  -Mode 'Strict' | Out-Null

$engineExit = $LASTEXITCODE
$ErrorActionPreference = $prevPref

if ($engineExit -eq 3) {
  Write-Error "Unified engine reported setup error (exit 3)"
  exit 3
}

if (-not (Test-Path $engineJsonPath)) {
  Write-Error "Engine did not produce JSON output at $engineJsonPath"
  exit 3
}

$engineResult = Get-Content -Raw -Path $engineJsonPath | ConvertFrom-Json

# --- 2. Translate to legacy JSON shape -----------------------------------

$sourceFrs   = @($engineResult.source_ids)
# In the legacy contract, "produced FRs" = all FR-IDs in the produced spec
# (not just those covering source). per_target_coverage[0].covers_source
# only includes those covering source. We need the full target reference set.
$producedFrs = @()
if ($engineResult.per_target_coverage -and $engineResult.per_target_coverage.Count -gt 0) {
  # Re-derive: total target refs = covers_source + orphan_target_refs
  $producedFrs = @($engineResult.per_target_coverage[0].covers_source) + @($engineResult.orphan_target_refs)
  $producedFrs = @($producedFrs | Sort-Object -Unique)
}

$gaps      = @($engineResult.missing_ids)
$additions = @($engineResult.orphan_target_refs)

# Prefix check (FR-specific - engine does not do this)
$prefixCheck = @()
$prefixGaps  = @()
if (-not [string]::IsNullOrWhiteSpace($ExpectedPrefixes)) {
  $expected = $ExpectedPrefixes -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  foreach ($prefix in $expected) {
    $count = @($producedFrs | Where-Object { $_ -like "FR-$prefix-*" -or $_ -like "FR-$prefix*" }).Count
    $prefixCheck += @{ prefix = $prefix; count_in_produced = $count }
    if ($count -eq 0) {
      $prefixGaps += $prefix
    }
  }
}

# Per-FR rows (legacy shape)
$allFrs = @($sourceFrs + $producedFrs | Sort-Object -Unique)
$rows = @()
foreach ($fr in $allFrs) {
  $rows += @{
    fr_id       = $fr
    in_source   = $sourceFrs   -contains $fr
    in_produced = $producedFrs -contains $fr
    ok          = ($sourceFrs -contains $fr) -and ($producedFrs -contains $fr)
  }
}

$result = @{
  source_path             = $SourcePath
  produced_path           = $ProducedPath
  source_fr_count         = $sourceFrs.Count
  produced_fr_count       = $producedFrs.Count
  fully_covered           = ($gaps.Count -eq 0 -and $prefixGaps.Count -eq 0)
  source_minus_produced   = $gaps
  produced_minus_source   = $additions
  expected_prefixes       = $prefixCheck
  expected_prefix_gaps    = $prefixGaps
  rows                    = $rows
  generated_at            = (Get-Date).ToString("o")
}

# Write UTF-8 without BOM
$jsonString = ($result | ConvertTo-Json -Depth 6)
[System.IO.File]::WriteAllText(
  $OutputJson,
  $jsonString,
  (New-Object System.Text.UTF8Encoding $false)
)

# Clean up engine's intermediate JSON (keep only legacy output)
try { Remove-Item -Path $engineJsonPath -Force -ErrorAction SilentlyContinue } catch {}
try { Remove-Item -Path ([System.IO.Path]::ChangeExtension($engineJsonPath, '.md')) -Force -ErrorAction SilentlyContinue } catch {}

# --- 3. Human-readable summary (matches legacy output exactly) -----------

"source_fr_count   = $($sourceFrs.Count)"
"produced_fr_count = $($producedFrs.Count)"
"gaps (in source, not in produced):"
if ($gaps.Count -eq 0) {
  "  (none)"
} else {
  foreach ($g in $gaps) { "  - $g" }
}
"additions (in produced, not in source):"
if ($additions.Count -eq 0) {
  "  (none)"
} else {
  foreach ($a in $additions) { "  - $a" }
}
if ($prefixGaps.Count -gt 0) {
  "expected prefixes missing entirely from produced spec:"
  foreach ($p in $prefixGaps) { "  - $p" }
}
"json written to: $OutputJson"

if ($gaps.Count -gt 0 -or $prefixGaps.Count -gt 0) {
  exit 2
}
exit 0
