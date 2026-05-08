<#
.SYNOPSIS
Auto-emits Step 1.7 reference-repo cross-check findings by diffing prescriptions in input against the actual reference-repo state.

.DESCRIPTION
Drives Step 1.7 of `rules/prescriptive-content-review.md` Gap 2.

For each prescription extracted from the input artifact (code blocks ≥3 lines,
"should/must/always/never" statements, named patterns), the script searches
references/ for the matching implementation. Emits a findings JSON with:
  - prescription_text + extraction location
  - reference_match (or "not found in any reference repo")
  - severity hint per `rules/prescriptive-content-review.md` Gap 2

.PARAMETER InputFile
Path to artifact text (PR description + diff body + doc body concatenated).

.PARAMETER ReferencesRoot
Path to references/ root. Defaults to ./references.

.PARAMETER OutputJson
Path to write findings JSON. Required.

.PARAMETER MaxPrescriptions
Cap on prescriptions to extract. Defaults to 50 (above this, the artifact
is too prescription-dense for automated cross-check; orchestrator should
handle manually).

.EXAMPLE
pwsh -NoProfile -File .claude/scripts/Detect-PrescriptionShift.ps1 \
  -InputFile .mad/scratch/review-123/artifact.txt \
  -ReferencesRoot ./references \
  -OutputJson .mad/scratch/review-123/prescription-shift.json

.NOTES
Per `rules/prescriptive-content-review.md` Gap 2.
This script handles the *grep* and *report shape* mechanics; the orchestrator
makes severity decisions per the rule's table when no specific finding emerges.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$InputFile,

  [string]$ReferencesRoot = './references',

  [Parameter(Mandatory=$true)]
  [string]$OutputJson,

  [int]$MaxPrescriptions = 50
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $InputFile)) {
  Write-Error "Input file not found: $InputFile"
  exit 2
}

$text = Get-Content -Path $InputFile -Raw
$findings = @()

# Extract code blocks ≥3 lines
$codeBlocks = [regex]::Matches($text, '```[a-z]*\r?\n([\s\S]*?)```', 'IgnoreCase')
$prescriptions = @()

$reservedWords = @('class','interface','public','private','protected','internal','sealed','async','await','task','void','string','int','long','bool','var','this','base','new','return','using','namespace','if','else','for','foreach','while','switch','case','default','break','continue','throw','try','catch','finally','true','false','null','readonly','static','virtual','override','abstract','partial','record','struct','enum','delegate','event','where','select','from','let','orderby','group','join','equals','into','on','by','ascending','descending','as','is','typeof','sizeof','checked','unchecked','lock','yield','remove','add','get','set','dynamic')

foreach ($cb in $codeBlocks) {
  $body = $cb.Groups[1].Value
  $lines = ($body -split "`n").Count
  if ($lines -ge 3) {
    # Pull PascalCase identifiers preceded by class/interface/method/Task<...> declarations.
    # Use case-sensitive regex on PascalCase to avoid capturing reserved words via -i alternatives.
    $signatures = [regex]::Matches($body, '(?:class|interface|public|private|protected|internal|sealed|async|Task)\s+([A-Z][A-Za-z0-9_]{2,})')
    $seen = @{}
    foreach ($sig in $signatures) {
      $name = $sig.Groups[1].Value
      # Skip lowercase reserved words (case-insensitive blacklist)
      if ($reservedWords -contains $name.ToLower()) { continue }
      # Dedup within block
      if ($seen.ContainsKey($name)) { continue }
      $seen[$name] = $true
      $prescriptions += [pscustomobject]@{
        kind = 'code_signature'
        text = $name
        block_excerpt = ($body -split "`n" | Select-Object -First 6) -join "`n"
      }
    }
  }
}

# Extract "should/must/always/never" prescriptions (sentence-level)
$prescriptiveSentences = [regex]::Matches($text, '(?m)^[^.\r\n]*\b(?:should|must|always|never)\b[^.\r\n]*\.', 'IgnoreCase')
foreach ($s in $prescriptiveSentences) {
  $sentence = $s.Value.Trim()
  if ($sentence.Length -gt 200) { continue }
  $prescriptions += [pscustomobject]@{
    kind = 'prescriptive_sentence'
    text = $sentence
    block_excerpt = $sentence
  }
}

# Cap
if ($prescriptions.Count -gt $MaxPrescriptions) {
  Write-Warning "Found $($prescriptions.Count) prescriptions; capping at $MaxPrescriptions"
  $prescriptions = $prescriptions | Select-Object -First $MaxPrescriptions
}

# References resolution
if (-not (Test-Path $ReferencesRoot)) {
  $references_present = $false
  Write-Warning "References root not found: $ReferencesRoot — emitting no-references finding only"
} else {
  $references_present = $true
}

foreach ($p in $prescriptions) {
  if (-not $references_present) {
    $findings += [pscustomobject]@{
      severity = 'CONSIDER'
      kind = $p.kind
      prescription = $p.text
      reference_match = $null
      message = "References root unavailable; cannot cross-check this prescription."
    }
    continue
  }

  if ($p.kind -eq 'code_signature') {
    # Grep for the signature in references/
    try {
      $matches = Get-ChildItem -Path $ReferencesRoot -Recurse -Include *.cs,*.ts,*.js,*.py,*.md -ErrorAction SilentlyContinue |
        Select-String -Pattern ([regex]::Escape($p.text)) -SimpleMatch -List -ErrorAction SilentlyContinue
      if ($matches -and $matches.Count -gt 0) {
        $first = $matches | Select-Object -First 1
        $findings += [pscustomobject]@{
          severity = 'PRAISE'
          kind = $p.kind
          prescription = $p.text
          reference_match = "$($first.Path):$($first.LineNumber)"
          message = "Prescription `"$($p.text)`" exists in references."
        }
      } else {
        $findings += [pscustomobject]@{
          severity = 'MUST-FIX'
          kind = $p.kind
          prescription = $p.text
          reference_match = $null
          message = "Prescription `"$($p.text)`" does not appear in any reference repo. Either the prescription is novel (revise to acknowledge or document), or it's hallucinated."
        }
      }
    } catch {
      $findings += [pscustomobject]@{
        severity = 'CONSIDER'
        kind = $p.kind
        prescription = $p.text
        reference_match = $null
        message = "Could not search references: $($_.Exception.Message)"
      }
    }
  } elseif ($p.kind -eq 'prescriptive_sentence') {
    # We can't grep a sentence directly; flag for orchestrator review
    $findings += [pscustomobject]@{
      severity = 'SHOULD-FIX'
      kind = $p.kind
      prescription = $p.text
      reference_match = $null
      message = "Prescriptive sentence detected; orchestrator should manually verify against reference repos."
    }
  }
}

# Aggregate
$summary = @{
  total_prescriptions = $prescriptions.Count
  code_signature_count = ($prescriptions | Where-Object { $_.kind -eq 'code_signature' }).Count
  prescriptive_sentence_count = ($prescriptions | Where-Object { $_.kind -eq 'prescriptive_sentence' }).Count
  unverified_count = ($findings | Where-Object { $_.reference_match -eq $null -and $_.severity -in 'MUST-FIX','SHOULD-FIX' }).Count
  matched_count = ($findings | Where-Object { $_.reference_match -ne $null }).Count
}

$result = [pscustomobject]@{
  schema_version = 1
  generated_utc = (Get-Date -AsUTC).ToString('o')
  input_file = $InputFile
  references_root = $ReferencesRoot
  references_available = $references_present
  summary = $summary
  findings = @($findings)
  notes = @(
    'This script greps reference repos for prescription matches.',
    'A "MUST-FIX" finding means the prescription names something that does not appear in any reference repo — either it is novel (acknowledge it) or hallucinated.',
    'A "PRAISE" finding means the prescription is grounded in real code.',
    'Sentence-level prescriptions need orchestrator interpretation; the script can only flag them.'
  )
}

$dir = Split-Path -Parent $OutputJson
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$result | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputJson -Encoding UTF8

Write-Host "Wrote: $OutputJson"
Write-Host "Prescriptions: $($prescriptions.Count); Findings: $($findings.Count); Unverified: $($summary.unverified_count); Matched: $($summary.matched_count)"
