<#
.SYNOPSIS
Normalize a findings JSON file (any common agent schema) into the canonical shape Post-ReviewFindings.ps1 expects.

.DESCRIPTION
Calibration finding from the 2026-05-01 LENS-CMS batch-2 review: agents emit findings with inconsistent
field names — `line` vs `line_start`, extra keys like `severity`/`confidence`/`category`/`rationale`/`title`/
`suggested_fix`, etc. Post-ReviewFindings.ps1 only reads `file/line/line_end/comment`. Without normalization,
mis-keyed `line_start` defaults to 0 and the comment posts as a general (non-inline) comment.

This script accepts any of the common variants and emits the canonical 4-key shape.

.PARAMETER InputFile
Path to the agent-emitted JSON file (array of findings).

.PARAMETER OutputFile
Where to write the normalized JSON. Defaults to `<input>.normalized.json` next to the input.

.PARAMETER InPlace
Overwrite the input file. Mutually exclusive with OutputFile.

.EXAMPLE
pwsh -NoProfile -File .claude/scripts/Normalize-Findings.ps1 -InputFile .mad/scratch/review-5155516/findings-council.json -InPlace

.NOTES
Per `rules/prescriptive-content-review.md`. Recognized variant fields:
  file       <- file | path | filePath | file_path | filename
  line       <- line | line_start | lineStart | startLine | start_line | line_number
  line_end   <- line_end | lineEnd | endLine | end_line
  comment    <- comment | body | message | text | description (preferred order)

Discarded fields (kept in `extras` for audit if -KeepExtras): id, severity, confidence, category, rationale,
title, suggested_fix, kind, evidence, rule, etc.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$InputFile,

  [string]$OutputFile,

  [switch]$InPlace,

  [switch]$KeepExtras
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $InputFile)) {
  Write-Error "Input not found: $InputFile"
  exit 2
}

if ($InPlace -and $OutputFile) {
  Write-Error "Cannot use both -InPlace and -OutputFile"
  exit 2
}

$raw = Get-Content $InputFile -Raw
try {
  $findings = $raw | ConvertFrom-Json
} catch {
  Write-Error "Failed to parse JSON: $_"
  exit 2
}

if ($findings -isnot [array]) {
  if ($null -eq $findings) {
    $findings = @()
  } else {
    $findings = @($findings)
  }
}

# Field aliasing (first match wins per category)
$fileAliases = @('file', 'path', 'filePath', 'file_path', 'filename')
$lineAliases = @('line', 'line_start', 'lineStart', 'startLine', 'start_line', 'line_number')
$lineEndAliases = @('line_end', 'lineEnd', 'endLine', 'end_line')
$commentAliases = @('comment', 'body', 'message', 'text', 'description')

function Get-FirstAvailable {
  param($obj, $aliases)
  foreach ($a in $aliases) {
    if ($obj.PSObject.Properties.Name -contains $a) {
      $v = $obj.$a
      if ($null -ne $v -and "$v".Trim() -ne '') {
        return $v
      }
    }
  }
  return $null
}

$normalized = @()
$dropped = 0

foreach ($f in $findings) {
  $file = Get-FirstAvailable $f $fileAliases
  $line = Get-FirstAvailable $f $lineAliases
  $lineEnd = Get-FirstAvailable $f $lineEndAliases
  $comment = Get-FirstAvailable $f $commentAliases

  if (-not $comment -or "$comment".Trim() -eq '') {
    $dropped++
    Write-Warning "Dropping finding with empty comment (file=$file, line=$line)"
    continue
  }

  # Coerce types
  $lineNum = if ($line) { [int]$line } else { 0 }
  $lineEndNum = if ($lineEnd) { [int]$lineEnd } else { $lineNum }

  # Normalize file path: ensure ADO-style absolute path (leading /) when present
  $filePath = if ($file) { "$file" } else { $null }
  if ($filePath -and -not $filePath.StartsWith('/')) {
    $filePath = "/$filePath"
  }

  $row = [ordered]@{
    file = $filePath
    line = $lineNum
    line_end = $lineEndNum
    comment = "$comment".Trim()
  }

  if ($KeepExtras) {
    $extras = @{}
    foreach ($prop in $f.PSObject.Properties) {
      if (($fileAliases + $lineAliases + $lineEndAliases + $commentAliases) -notcontains $prop.Name) {
        $extras[$prop.Name] = $prop.Value
      }
    }
    if ($extras.Count -gt 0) {
      $row['extras'] = $extras
    }
  }

  $normalized += [pscustomobject]$row
}

$json = ConvertTo-Json -InputObject $normalized -Depth 10

$target = if ($InPlace) { $InputFile } elseif ($OutputFile) { $OutputFile } else { "$InputFile.normalized.json" }
$dir = Split-Path -Parent $target
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

Set-Content -Path $target -Value $json -Encoding UTF8

Write-Host "Wrote: $target"
Write-Host "  Findings normalized: $($normalized.Count)"
Write-Host "  Findings dropped (empty comment): $dropped"
