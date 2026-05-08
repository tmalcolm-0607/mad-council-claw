<#
.SYNOPSIS
Drives Step 1.5 (production grounding) per `rules/prescriptive-content-review.md` § Gap 1.

.DESCRIPTION
Scans an input artifact (PR description, diff body, doc body) for grounding triggers:
  1. Explicit work-item / PR / incident IDs
  2. Topic keywords from `.mad/learning/topic-grounding-keywords.json`
  3. Reference-repo path mentions

Emits a JSON plan of what queries to run against WorkIQ (or other grounding sources).
The actual query execution is left to the caller (skills handle WorkIQ themselves;
this script identifies WHAT to ask, not HOW).

.PARAMETER InputFile
Path to a file containing the artifact text (PR meta + diff + doc body concatenated).

.PARAMETER ContentTypeJson
Optional path to the content-type.json from Detect-ContentType.ps1. When supplied,
adds content-type-specific grounding queries (e.g. doc-change → "lessons-learned + topic-area").

.PARAMETER OutputJson
Path to write JSON output. If omitted, writes to stdout.

.PARAMETER KeywordsFile
Path to topic-grounding-keywords.json. Defaults to .mad/learning/topic-grounding-keywords.json.

.EXAMPLE
pwsh -NoProfile -File .claude/scripts/Pull-ProductionGrounding.ps1 \
  -InputFile .mad/scratch/review-123/artifact-text.txt \
  -ContentTypeJson .mad/scratch/review-123/content-type.json \
  -OutputJson .mad/scratch/review-123/grounding-plan.json

.NOTES
Per `rules/prescriptive-content-review.md` Gap 1.
This script does NOT call WorkIQ; it produces a plan of queries the orchestrator runs.
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory=$true)]
  [string]$InputFile,

  [string]$ContentTypeJson,

  [string]$OutputJson,

  [string]$KeywordsFile = '.mad/learning/topic-grounding-keywords.json'
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $InputFile)) {
  Write-Error "Input file not found: $InputFile"
  exit 2
}

$text = Get-Content -Path $InputFile -Raw

# Load keywords
$keywords = $null
if (Test-Path $KeywordsFile) {
  $keywords = Get-Content -Path $KeywordsFile -Raw | ConvertFrom-Json
}

# Load content-type if provided
$contentType = $null
if ($ContentTypeJson -and (Test-Path $ContentTypeJson)) {
  $contentType = Get-Content -Path $ContentTypeJson -Raw | ConvertFrom-Json
}

$triggers = @()
$queries = @()

# Trigger 1 — Explicit IDs
$idPatterns = @(
  @{ Name = 'ado_workitem'; Regex = '\b(?:WI|AB|US|Bug|Task|PBI)[\s#-]*(\d{4,8})\b' }
  @{ Name = 'ado_pr';        Regex = '\b(?:PR|pullrequest)[\s#-]*(\d{6,8})\b' }
  @{ Name = 'github_issue';  Regex = '#(\d{1,5})\b' }
  @{ Name = 'incident';      Regex = '\b(?:incident|outage|sev[\s-]?\d)[\s:#-]*([\w-]+)\b' }
)

foreach ($p in $idPatterns) {
  $matchInstances = [regex]::Matches($text, $p.Regex, 'IgnoreCase')
  foreach ($m in $matchInstances) {
    $val = $m.Value
    $triggers += [pscustomobject]@{ kind = 'id'; pattern = $p.Name; matched = $val }
    $queries += [pscustomobject]@{
      source = 'workiq'
      query = "any chats/emails/meetings about $val or its title"
      reason = "Explicit $($p.Name) reference"
      priority = 'high'
    }
  }
}

# Trigger 2 — Topic keywords
if ($keywords -and $keywords.keywords) {
  foreach ($category in $keywords.keywords.PSObject.Properties) {
    $catName = $category.Name
    $kwList = $category.Value
    foreach ($kw in $kwList) {
      # Case-insensitive substring match (case-insensitive substring; multi-word allowed)
      if ($text -match [regex]::Escape($kw)) {
        $triggers += [pscustomobject]@{ kind = 'keyword'; category = $catName; matched = $kw }
        $queries += [pscustomobject]@{
          source = 'workiq'
          query = "lessons-learned and recent incidents on $kw last 60 days"
          reason = "Topic keyword '$kw' (category: $catName)"
          priority = 'medium'
        }
      }
    }
  }
}

# Trigger 3 — Reference-repo mentions
$refRepoMatches = [regex]::Matches($text, 'references[\\/]([A-Za-z0-9_-]+)', 'IgnoreCase')
$seenRepos = @{}
foreach ($m in $refRepoMatches) {
  $repo = $m.Groups[1].Value
  if (-not $seenRepos.ContainsKey($repo)) {
    $seenRepos[$repo] = $true
    $triggers += [pscustomobject]@{ kind = 'reference_repo'; matched = $repo }
    $queries += [pscustomobject]@{
      source = 'workiq'
      query = "discussions about $repo patterns last 60 days"
      reason = "Reference-repo mention: $repo"
      priority = 'medium'
    }
  }
}

# Trigger 4 — Content-type-specific
if ($contentType) {
  $primary = $contentType.primary_content_type
  switch ($primary) {
    'doc-change' {
      $queries += [pscustomobject]@{
        source = 'workiq'
        query = "doc reviewers' recent objections and approval criteria for prescriptive content"
        reason = "doc-change content-type"
        priority = 'low'
      }
    }
    'skill-md-change' {
      $queries += [pscustomobject]@{
        source = 'local'
        query = "review .mad/scratch/skill-standardization-loop-log.md for recent skill-shape decisions"
        reason = "skill-md-change content-type"
        priority = 'medium'
      }
    }
    'rule-md-change' {
      $queries += [pscustomobject]@{
        source = 'local'
        query = "review rules/_status-convention.md for status promotion expectations"
        reason = "rule-md-change content-type"
        priority = 'medium'
      }
    }
    default { }
  }
}

# Deduplicate queries (same text + source)
$seen = @{}
$dedupQueries = @()
foreach ($q in $queries) {
  $key = "$($q.source)|$($q.query)"
  if (-not $seen.ContainsKey($key)) {
    $seen[$key] = $true
    $dedupQueries += $q
  }
}

# Build result
$result = [pscustomobject]@{
  schema_version = 1
  generated_utc  = (Get-Date -AsUTC).ToString('o')
  input_file     = $InputFile
  triggers_fired = @($triggers)
  queries_planned = @($dedupQueries)
  trigger_count  = $triggers.Count
  query_count    = $dedupQueries.Count
  fired          = $triggers.Count -gt 0
  notes          = @(
    'This script plans queries; it does not execute them.',
    'Skills consume queries_planned[] and call WorkIQ (or other source) themselves.',
    'When fired=false, Step 1.5 still runs but with no targeted queries (catch-all only).'
  )
}

$json = $result | ConvertTo-Json -Depth 10

if ($OutputJson) {
  $dir = Split-Path -Parent $OutputJson
  if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  Set-Content -Path $OutputJson -Value $json -Encoding UTF8
  Write-Host "Wrote: $OutputJson"
  Write-Host "Triggers: $($triggers.Count); Queries: $($dedupQueries.Count); Fired: $($result.fired)"
} else {
  Write-Output $json
}
