<#
.SYNOPSIS
Compute the FR count of a spec.md and emit a parallel/serial fan-out decision
+ lane partition. Replaces conversational LLM emission of "should we fan out?"
reasoning in /mad-plan, /mad-tasks, /testplan, and any skill that needs to
decide between serial and parallel iteration over FRs.

.DESCRIPTION
Per CLAUDE.md > Speed pathologies:

  Per-FR serial gate iteration on large specs. /mad-spec Step 7.1
  (implementability gate) runs 5 sub-checks against every FR. At 45 FRs that's
  a ~7-8 min serial loop inside a single subagent. Fix: when FR count >= 20,
  the skill body returns a parallel-fan-out directive; orchestrator dispatches
  3 lanes in a single message per
  .claude/skills/mad-spec/references/implementability-gate.md.

This script is the deterministic FR-count + partition emitter. Same regex as
.claude/scripts/Verify-SourceCoverage.ps1 (FR-[A-Z][A-Z0-9-]*-\d+) so the two
scripts agree on what an FR-ID looks like. Round-robin partition keeps lane
sizes balanced.

.PARAMETER SpecPath
Mandatory. Path to the spec.md (or any artifact containing FR IDs). Must
exist - missing spec exits 3.

.PARAMETER IdRegex
Optional. Regex to extract FR IDs. Default matches FR-CORE-001,
FR-AUDIT-PRIVACY-001, FR-EXT-WRITE-RATE-001, etc.

.PARAMETER FanoutThreshold
Optional. Minimum FR count to trigger parallel fan-out. Default 20 (matches
the /mad-spec Step 7.1 threshold).

.PARAMETER LaneCount
Optional. Number of lanes to partition into when parallel. Default 3 (matches
agent-teams.md mandatory minimum for parallel implementation).

.EXAMPLE
pwsh -NoProfile -File .claude/scripts/Compute-FrCount.ps1 `
  -SpecPath specs/15-collab-engine-canonical-e/spec.md

Returns JSON:
  {
    "spec_path": "specs/15-collab-engine-canonical-e/spec.md",
    "fr_count": 58,
    "decision": "parallel",
    "lane_partition": [
      {"lane": 1, "fr_ids": ["FR-CORE-001", ...], "count": 20},
      {"lane": 2, "fr_ids": [...], "count": 19},
      {"lane": 3, "fr_ids": [...], "count": 19}
    ],
    ...
  }

.NOTES
Wave 1 Lane gamma deliverable. Used by skill bodies BEFORE deciding whether
to spawn parallel Task subagents. If decision == "parallel", the skill body
calls Stage-SubagentBundle.ps1 + Get-SubagentPromptBoilerplate.ps1 to set up
the fan-out; if decision == "serial", the skill body iterates inline.

Exit codes:
  0  success (regardless of parallel/serial decision)
  1  invalid params
  3  spec missing
#>

[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)] [string]$SpecPath,
  [string]$IdRegex = 'FR-[A-Z][A-Z0-9-]*-\d+',
  [int]$FanoutThreshold = 20,
  [int]$LaneCount = 3
)

$ErrorActionPreference = 'Stop'

# ---- Param validation ------------------------------------------------------

if ([string]::IsNullOrWhiteSpace($SpecPath)) {
  Write-Error "SpecPath is required and must be non-empty."
  exit 1
}

if (-not (Test-Path $SpecPath)) {
  Write-Error "Spec not found: $SpecPath"
  exit 3
}

if ($FanoutThreshold -lt 1) {
  Write-Error "FanoutThreshold must be >= 1."
  exit 1
}

if ($LaneCount -lt 1) {
  Write-Error "LaneCount must be >= 1."
  exit 1
}

if ([string]::IsNullOrWhiteSpace($IdRegex)) {
  Write-Error "IdRegex must be non-empty."
  exit 1
}

# ---- Extract distinct FR IDs ----------------------------------------------

# Using Select-String + regex captures, sorted unique. Same shape as
# Verify-SourceCoverage.ps1.
$matches = Select-String -Path $SpecPath -Pattern $IdRegex -AllMatches |
  ForEach-Object { $_.Matches } |
  ForEach-Object { $_.Value }

if ($null -eq $matches) {
  $distinctFrs = @()
} else {
  $distinctFrs = @($matches | Sort-Object -Unique)
}

$frCount = $distinctFrs.Count

# ---- Decide parallel vs serial --------------------------------------------

if ($frCount -ge $FanoutThreshold) {
  $decision = 'parallel'
} else {
  $decision = 'serial'
}

# ---- Partition into lanes (round-robin) ------------------------------------

$lanes = @()
if ($decision -eq 'parallel' -and $frCount -gt 0) {
  # Initialize empty arrays for each lane
  $bucket = @{}
  for ($i = 1; $i -le $LaneCount; $i++) {
    $bucket[$i] = @()
  }
  # Round-robin: FR i goes to lane ((i % LaneCount) + 1)
  for ($i = 0; $i -lt $frCount; $i++) {
    $laneIdx = ($i % $LaneCount) + 1
    $bucket[$laneIdx] += $distinctFrs[$i]
  }
  for ($i = 1; $i -le $LaneCount; $i++) {
    $lanes += [pscustomobject]@{
      lane    = $i
      fr_ids  = $bucket[$i]
      count   = @($bucket[$i]).Count
    }
  }
} elseif ($decision -eq 'serial' -and $frCount -gt 0) {
  # Single lane containing all FRs - useful for callers that want a
  # consistent shape regardless of decision.
  $lanes += [pscustomobject]@{
    lane    = 1
    fr_ids  = $distinctFrs
    count   = $frCount
  }
}
# If frCount == 0, lanes stays empty.

# ---- Emit JSON -------------------------------------------------------------

$result = [pscustomobject]@{
  spec_path        = $SpecPath
  fr_count         = $frCount
  decision         = $decision
  fanout_threshold = $FanoutThreshold
  lane_count       = $LaneCount
  lane_partition   = $lanes
  id_regex         = $IdRegex
  generated_at     = (Get-Date).ToString('o')
}

# ConvertTo-Json with depth 6 to capture nested fr_ids arrays.
$json = $result | ConvertTo-Json -Depth 6
Write-Output $json

exit 0
