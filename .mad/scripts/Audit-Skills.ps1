<#
.SYNOPSIS
Audit all skills under .claude/skills against the 6-dimension `rules/skill-standards.md` scorecard.

.DESCRIPTION
Reads each SKILL.md, parses tier-exempt frontmatter, scores each skill on:
  1. Frontmatter integrity (mandatory)
  2. Best Practices section
  3. Standards section
  4. Evals fixtures
  5. Templates dir
  6. Multi-pass / Copilot CLI wired

`tier-exempt: [...]` declarations count exempt dimensions as covered.

Produces:
  - .mad/reports/skill-audit-<ts>.csv (per-skill detail)
  - .mad/reports/skill-audit-<ts>.md (human-readable summary)

.PARAMETER SkillsRoot
Root to scan. Defaults to .claude/skills/.

.PARAMETER OutputDir
Reports directory. Defaults to .mad/reports/.

.PARAMETER FailBelowTier
If set to S/A/B/C/D, exits non-zero when any non-exempt skill scores below that tier. Use in CI.

.EXAMPLE
pwsh -NoProfile -File .mad/scripts/Audit-Skills.ps1
pwsh -NoProfile -File .mad/scripts/Audit-Skills.ps1 -FailBelowTier B
#>

[CmdletBinding()]
param(
  [string]$SkillsRoot = '.claude/skills',
  [string]$OutputDir = '.mad/reports',
  [string]$FailBelowTier
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $SkillsRoot)) {
  Write-Error "Skills root not found: $SkillsRoot"
  exit 2
}
if (-not (Test-Path $OutputDir)) {
  New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

$ts = Get-Date -Format 'yyyyMMdd-HHmmss'
$csvPath = Join-Path $OutputDir "skill-audit-$ts.csv"
$mdPath  = Join-Path $OutputDir "skill-audit-$ts.md"

$skills = Get-ChildItem -Path $SkillsRoot -Directory | Where-Object { $_.Name -ne '_template' } | Sort-Object Name

$rows = @()
$tierCounts = @{ 'S'=0; 'A'=0; 'B'=0; 'C'=0; 'D'=0 }

foreach ($s in $skills) {
  $name = $s.Name
  $f = Join-Path $s.FullName 'SKILL.md'
  if (-not (Test-Path $f)) {
    Write-Warning "$name : SKILL.md missing"
    continue
  }
  $c = Get-Content -Path $f -Raw

  # Parse tier-exempt
  $exempt = @()
  if ($c -match 'tier-exempt:\s*\[([^\]]*)\]') {
    $exempt = ($matches[1] -split ',' | ForEach-Object { $_.Trim() })
  }

  $score = 0

  # Dim 1 — Frontmatter integrity (mandatory; tier-exempt: [frontmatter] is rejected)
  if ($exempt -contains 'frontmatter') {
    Write-Warning "$name : tier-exempt: [frontmatter] is not allowed; ignoring"
    $exempt = $exempt | Where-Object { $_ -ne 'frontmatter' }
  }
  $hasFM = ($c -match '^---') -and ($c -match 'name:')
  if ($hasFM) { $score++ }

  # Dim 2 — Best Practices
  $hasBP = ($c -match '## Best Practices') -or ($c -match '## Best practices') -or ($exempt -contains 'best-practices')
  if ($hasBP) { $score++ }

  # Dim 3 — Standards
  $hasStd = ($c -match '## Standards') -or ($exempt -contains 'standards')
  if ($hasStd) { $score++ }

  # Dim 4 — Evals
  $evDir = Join-Path $s.FullName 'evals\fixtures'
  $hasEv = $false
  if (Test-Path $evDir) {
    $files = Get-ChildItem -Path $evDir -Filter '*.md' -File -ErrorAction SilentlyContinue
    if ($files.Count -gt 0) { $hasEv = $true }
  }
  $evRoot = Join-Path $s.FullName 'evals'
  if (-not $hasEv -and (Test-Path $evRoot)) {
    $rmd = Get-ChildItem -Path $evRoot -Filter '*.md' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'README.md' }
    if ($rmd.Count -gt 0) { $hasEv = $true }
  }
  if ($exempt -contains 'evals') { $hasEv = $true }
  if ($hasEv) { $score++ }

  # Dim 5 — Templates
  $tDir = Join-Path $s.FullName 'templates'
  $hasT = $false
  if (Test-Path $tDir) {
    $files = Get-ChildItem -Path $tDir -File -ErrorAction SilentlyContinue
    if ($files.Count -gt 0) { $hasT = $true }
  }
  if ($exempt -contains 'templates') { $hasT = $true }
  if ($hasT) { $score++ }

  # Dim 6 — Multi-pass / Copilot CLI
  $hasMP = ($c -match 'Invoke-CopilotMultiModel') -or ($c -match 'lens-multi-model-review-pattern') -or ($exempt -contains 'multi-pass')
  if ($hasMP) { $score++ }

  $tier = switch ($score) {
    6 { 'S' }
    5 { 'A' }
    4 { 'B' }
    { $_ -ge 2 -and $_ -le 3 } { 'C' }
    default { 'D' }
  }
  $tierCounts[$tier]++

  $rows += [pscustomobject]@{
    skill          = $name
    frontmatter    = $hasFM
    best_practices = $hasBP
    standards      = $hasStd
    evals          = $hasEv
    templates      = $hasT
    multi_pass     = $hasMP
    score          = $score
    tier           = $tier
    tier_exempt    = ($exempt -join ';')
  }
}

# CSV output
$rows | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8

# Markdown summary
$total = $rows.Count
$mdLines = @(
  "# Skill Audit — $ts"
  ""
  "**Skills audited**: $total"
  "**Standard**: ``rules/skill-standards.md``"
  ""
  "## Tier histogram"
  ""
  "| Tier | Count | % |"
  "|------|-------|---|"
)
foreach ($t in @('S','A','B','C','D')) {
  $pct = if ($total -gt 0) { [math]::Round($tierCounts[$t]*100/$total) } else { 0 }
  $mdLines += "| $t | $($tierCounts[$t]) | $pct% |"
}
$mdLines += ""
$mdLines += "## Below-Tier-S skills"
$mdLines += ""
$nonS = $rows | Where-Object { $_.tier -ne 'S' }
if ($nonS.Count -eq 0) {
  $mdLines += "_(none — all skills at Tier S when accounting for tier-exempt declarations.)_"
} else {
  $mdLines += "| Skill | Tier | Score | Missing |"
  $mdLines += "|-------|------|-------|---------|"
  foreach ($r in $nonS) {
    $missing = @()
    if (-not $r.best_practices) { $missing += 'best_practices' }
    if (-not $r.standards) { $missing += 'standards' }
    if (-not $r.evals) { $missing += 'evals' }
    if (-not $r.templates) { $missing += 'templates' }
    if (-not $r.multi_pass) { $missing += 'multi_pass' }
    $mdLines += "| ``$($r.skill)`` | $($r.tier) | $($r.score)/6 | $($missing -join ', ') |"
  }
}
$mdLines += ""
$mdLines += "## Audit details"
$mdLines += ""
$mdLines += "Per-skill detail: see ``$csvPath`` (CSV)."

Set-Content -Path $mdPath -Value ($mdLines -join "`n") -Encoding UTF8

Write-Host "Wrote: $csvPath"
Write-Host "Wrote: $mdPath"
Write-Host ""
Write-Host "Tier histogram:"
foreach ($t in @('S','A','B','C','D')) {
  $pct = if ($total -gt 0) { [math]::Round($tierCounts[$t]*100/$total) } else { 0 }
  Write-Host ("  {0}: {1} ({2}%)" -f $t, $tierCounts[$t], $pct)
}

# CI gate
if ($FailBelowTier) {
  $tierOrder = @{ 'S'=4; 'A'=3; 'B'=2; 'C'=1; 'D'=0 }
  $threshold = $tierOrder[$FailBelowTier]
  if ($null -eq $threshold) {
    Write-Error "Invalid -FailBelowTier value: $FailBelowTier (use S/A/B/C/D)"
    exit 2
  }
  $failures = $rows | Where-Object { $tierOrder[$_.tier] -lt $threshold }
  if ($failures.Count -gt 0) {
    Write-Host ""
    Write-Error ("$($failures.Count) skill(s) below Tier ${FailBelowTier}: " + ($failures.skill -join ', '))
    exit 1
  }
}
