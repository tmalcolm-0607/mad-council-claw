<#
.SYNOPSIS
Classifies input file paths into a content-type taxonomy used by skills inheriting `rules/prescriptive-content-review.md`.

.DESCRIPTION
Reads a list of file paths (one per line) from -InputFile or stdin and emits JSON with:
- detected content-types (one of: code-change, doc-change, skill-md-change, rule-md-change, template-change, config-change, spec-change, plan-change, tasks-change, infra-change, mixed)
- per-file classification
- recommended oracle paths under .mad/templates/coverage-oracles/
- blast_radius axis value (0-10) per Gap 5 of the rule
- whether --council mode auto-escalation fires (blast_radius >= 7)

.PARAMETER InputFile
Path to a file containing newline-separated paths to classify. If omitted, reads from stdin.

.PARAMETER OutputJson
Path to write JSON output. If omitted, writes to stdout.

.EXAMPLE
pwsh -NoProfile -File .claude/scripts/Detect-ContentType.ps1 -InputFile changed-files.txt -OutputJson .mad/scratch/content-type.json

.NOTES
Per `rules/prescriptive-content-review.md` Gap 6.
Skills call this in Step 0.5 (right after preflight).
#>

[CmdletBinding()]
param(
  [string]$InputFile,
  [string]$OutputJson
)

$ErrorActionPreference = 'Stop'

# Read paths
if ($InputFile -and (Test-Path $InputFile)) {
  $paths = Get-Content -Path $InputFile | Where-Object { $_.Trim() -ne '' }
} else {
  $paths = $input | Where-Object { $_.Trim() -ne '' }
}

if (-not $paths -or $paths.Count -eq 0) {
  Write-Error "No paths provided (use -InputFile or pipe stdin)."
  exit 2
}

# Classification rules (ordered most-specific first; first match wins)
$rules = @(
  @{ Type = 'skill-md-change';  Match = '\.claude[\\/]skills[\\/][^\\/]+[\\/]SKILL\.md$' }
  @{ Type = 'rule-md-change';   Match = '(\.claude[\\/])?rules[\\/].*\.md$' }
  @{ Type = 'template-change';  Match = '(templates[\\/].*\.md$)|(\.mad[\\/]templates[\\/])' }
  @{ Type = 'spec-change';      Match = 'specs[\\/].*[\\/](spec|idea)\.md$' }
  @{ Type = 'plan-change';      Match = 'specs[\\/].*[\\/]plan\.md$' }
  @{ Type = 'tasks-change';     Match = 'specs[\\/].*[\\/]tasks\.md$' }
  @{ Type = 'infra-change';     Match = '\.(bicep|bicepparam|tf|tfvars|yaml|yml|csproj|props|targets|sln)$' }
  @{ Type = 'ev2-config-change';Match = '[\\/]Ev2[\\/].*\.json$' }
  @{ Type = 'config-change';    Match = '(settings.*\.json$)|(mcp\.json$)|(.*\.config\.json$)|(package\.json$)|(NuGet\.[Cc]onfig$)|(Directory\.[A-Za-z]+\.props$)' }
  @{ Type = 'doc-change';       Match = '(docs[\\/].*\.md$)|(README(\.md)?$)|(CONTRIBUTING\.md$)|(CHANGELOG\.md$)|(ARCHITECTURE\.md$)|(NOTICE(\.md)?$)|(ACTION[_ ]?REQUIRED.*\.md$)|(SECURITY\.md$)|(LICENSE(\.md)?$)' }
  @{ Type = 'code-change';      Match = '\.(cs|ts|tsx|js|jsx|py|go|rs|java|rb|php|sh|ps1)$' }
)

# Topic-grounding keywords (for Gap 1)
$topicKeywords = @(
  'cosmos repository', 'cosmos partition', 'etag propagation', 'validator wiring',
  'enum serialization', 'mise auth', 'managed identity', 'rbac assignment',
  'event sourcing', 'change feed', 'idempotency', 'optimistic concurrency',
  'feature flag', 'circuit breaker', 'retry policy', 'bulkhead'
)

$perFile = @()
$typesSeen = New-Object System.Collections.Generic.HashSet[string]

foreach ($p in $paths) {
  $p = $p.Trim()
  $matched = $null
  foreach ($r in $rules) {
    if ($p -match $r.Match) {
      $matched = $r.Type
      break
    }
  }
  if (-not $matched) { $matched = 'unknown' }
  $typesSeen.Add($matched) | Out-Null
  $perFile += [pscustomobject]@{
    path = $p
    content_type = $matched
  }
}

# Aggregate content-type
$primary = if ($typesSeen.Count -eq 1) { $typesSeen | Select-Object -First 1 } else { 'mixed' }

# Blast-radius axis per Gap 5
function Get-BlastRadius([string]$type, [string]$path) {
  switch ($type) {
    'skill-md-change'  { return 7 }   # cross-team prescriptive
    'rule-md-change'   { return 7 }
    'template-change'  { return 7 }
    'doc-change'       {
      # Top-level CLAUDE.md or onboarding doc → 10
      if ($path -match '(CLAUDE\.md$)|(README\.md$)|(ONBOARD)') { return 10 }
      return 5
    }
    'config-change'    { return 5 }
    'ev2-config-change' { return 5 }   # Ev2 ScopeBindings/ServiceSpec/RolloutSpec/StageMap/env-config — prod-deploy reach
    'spec-change'      { return 5 }
    'plan-change'      { return 3 }
    'tasks-change'     { return 3 }
    'infra-change'     { return 7 }   # one bicep change can affect prod
    'code-change'      { return 0 }
    default            { return 0 }
  }
}

$maxBlast = 0
foreach ($f in $perFile) {
  $b = Get-BlastRadius $f.content_type $f.path
  $f | Add-Member -MemberType NoteProperty -Name blast_radius -Value $b
  if ($b -gt $maxBlast) { $maxBlast = $b }
}

# Recommended oracle paths
$oracleMap = @{
  'skill-md-change'  = '.mad/templates/coverage-oracles/skill-md.md'
  'rule-md-change'   = '.mad/templates/coverage-oracles/rule-md.md'
  'template-change'  = '.mad/templates/coverage-oracles/template-md.md'
  'doc-change'       = '.mad/templates/coverage-oracles/doc-generic.md'
  'spec-change'      = '.mad/templates/coverage-oracles/spec.md'
  'plan-change'      = '.mad/templates/coverage-oracles/plan.md'
  'tasks-change'     = '.mad/templates/coverage-oracles/tasks.md'
  'infra-change'     = '.mad/templates/coverage-oracles/bicep.md'
  'config-change'    = '.mad/templates/coverage-oracles/config.md'
  'ev2-config-change'= '.mad/templates/coverage-oracles/ev2-config.md'
  'code-change'      = '.mad/templates/coverage-oracles/handler-tests.md'
}
$oracles = @()
foreach ($t in $typesSeen) {
  if ($oracleMap.ContainsKey($t)) {
    $oracles += $oracleMap[$t]
  }
}

# Same-type cross-file consistency trigger (Gap 4)
$sameTypeGroups = @{}
foreach ($f in $perFile) {
  if (-not $sameTypeGroups.ContainsKey($f.content_type)) {
    $sameTypeGroups[$f.content_type] = @()
  }
  $sameTypeGroups[$f.content_type] += $f.path
}
$crossFileGroups = @()
foreach ($k in $sameTypeGroups.Keys) {
  if ($sameTypeGroups[$k].Count -ge 2) {
    $crossFileGroups += [pscustomobject]@{
      content_type = $k
      paths = $sameTypeGroups[$k]
    }
  }
}

# Council auto-escalate gate
$councilEscalate = ($maxBlast -ge 7)

$result = [pscustomobject]@{
  primary_content_type = $primary
  content_types_seen   = @($typesSeen)
  per_file             = $perFile
  recommended_oracles  = $oracles
  blast_radius_max     = $maxBlast
  council_escalate     = $councilEscalate
  cross_file_groups    = $crossFileGroups
  topic_keywords_to_match = $topicKeywords
  generated_utc        = (Get-Date -AsUTC).ToString('o')
}

$json = $result | ConvertTo-Json -Depth 10

if ($OutputJson) {
  $dir = Split-Path -Parent $OutputJson
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  Set-Content -Path $OutputJson -Value $json -Encoding UTF8
  Write-Host "Wrote: $OutputJson"
} else {
  Write-Output $json
}
