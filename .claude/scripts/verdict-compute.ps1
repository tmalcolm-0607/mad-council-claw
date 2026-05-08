<#
.SYNOPSIS
  Compute a binding verdict from aggregated role findings + confidence scores.
  Phase-2 deliverable per iter-39 audit (CHK-064).

.DESCRIPTION
  Referenced by mad.council.a2a.md §11 `/council-review` Step 8. Applies the
  severity rubric (CRITICAL/HIGH/MEDIUM/LOW/OBSERVATION) and mechanical
  ESCALATE triggers (arxiv 2601.07767 — LLMs don't self-abstain) to emit a
  binding verdict: FIX / ACCEPT / ESCALATE / INVESTIGATE.

  Priority: FIX > ESCALATE > INVESTIGATE > ACCEPT.

  Triggers:
    FIX        — >=1 CRITICAL or >=3 HIGH findings (post-YAGNI + post-pattern-verify).
    ESCALATE   — 3/3 roles disagree on severity of same finding (-HasSeverityDisagreement signal),
                 OR all completing roles have confidence <0.5,
                 OR >=1 role timed out AND some remaining role has borderline confidence (0.5-0.85),
                 OR ensemble mode and all models disagree (-EnsembleAllDisagree signal).
    INVESTIGATE — any finding has evidence_incomplete=true.
    ACCEPT     — no blocking findings AND no mechanical escalate trigger.
                 "ACCEPT with caveats" (caveats=true) when some role confidence is borderline.

.PARAMETER Findings
  Array of finding objects. Each is expected to have .severity and optionally
  .evidence_incomplete. May be empty array.

.PARAMETER Roles
  Array of role records with .confidence (0-1) and .timed_out (bool). May contain
  1-3 entries (ensemble variants still pass a single aggregated Skeptic).

.PARAMETER HasSeverityDisagreement
  Orchestrator-computed signal: 3/3 roles disagreed on severity of the same finding
  BEFORE dedup. Pre-computed because post-dedup the disagreement is flattened.

.PARAMETER EnsembleAllDisagree
  Orchestrator-computed signal: ensemble mode enabled and all 3 models produced
  disjoint findings. Phase-2 optional; callers without ensemble omit.

.OUTPUTS
  PSCustomObject {
    verdict:          'FIX'|'ACCEPT'|'ESCALATE'|'INVESTIGATE'
    rationale_seed:   string — 1-3 sentence explanation (orchestrator expands)
    escalate_trigger: string|null — 'severity_disagreement'|'all_low_confidence'|
                      'timeout_with_borderline'|'ensemble_all_disagree'|null
    caveats:          bool — only present when verdict=ACCEPT; true if some role
                      confidence was borderline
  }

.NOTES
  Callers: skills/council-review/plan.md Step 8.
  Rule anchor: wiki/patterns/multi-role-review.md §5.5; skills/council-review/SKILL.md §Step 8.
  Test coverage: scripts/verdict-compute.Tests.ps1 (T1-06 through T1-15 from
  skills/council-review/tests.md).

.EXAMPLE
  $f = @([pscustomobject]@{ severity = 'CRITICAL' })
  $r = @([pscustomobject]@{ role = 'advocate'; confidence = 0.9; timed_out = $false })
  Invoke-VerdictCompute -Findings $f -Roles $r
  # → verdict = 'FIX'
#>

Set-StrictMode -Version Latest

function Invoke-VerdictCompute {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [object[]] $Findings,
        [Parameter(Mandatory = $true)] [object[]] $Roles,
        [Parameter()] [switch] $HasSeverityDisagreement,
        [Parameter()] [switch] $EnsembleAllDisagree
    )

    # Normalize inputs: treat null/empty uniformly
    $findings = @($Findings)
    $roles = @($Roles)

    if ($roles.Count -eq 0) {
        throw "Invoke-VerdictCompute requires at least one role record. Received none."
    }

    # --- Severity counts (on filtered/deduped findings) ---
    $severityCount = @{
        CRITICAL    = 0
        HIGH        = 0
        MEDIUM      = 0
        LOW         = 0
        OBSERVATION = 0
    }
    foreach ($f in $findings) {
        $sev = [string]$f.severity
        if ($severityCount.ContainsKey($sev)) { $severityCount[$sev]++ }
    }

    # --- Evidence-incomplete detection ---
    $evidenceIncomplete = $false
    foreach ($f in $findings) {
        $props = $f.PSObject.Properties
        if ($props['evidence_incomplete'] -and [bool]$f.evidence_incomplete) {
            $evidenceIncomplete = $true
            break
        }
    }

    # --- Role confidence analysis ---
    $completedRoles = @($roles | Where-Object { -not [bool]$_.timed_out })
    $timedOutRoles  = @($roles | Where-Object { [bool]$_.timed_out })

    $allLowConf = $false
    $someBorderline = $false
    if ($completedRoles.Count -gt 0) {
        $allLowConf = (@($completedRoles | Where-Object { [double]$_.confidence -ge 0.5 }).Count -eq 0)
        $someBorderline = (@($completedRoles | Where-Object {
            [double]$_.confidence -ge 0.5 -and [double]$_.confidence -lt 0.85
        }).Count -gt 0)
    }

    # --- Decision tree in strict priority order ---
    # 1. FIX (takes precedence over everything else per T1-15)
    if ($severityCount.CRITICAL -ge 1) {
        return [pscustomobject]@{
            verdict          = 'FIX'
            rationale_seed   = "$($severityCount.CRITICAL) CRITICAL finding(s); FIX verdict per severity rubric."
            escalate_trigger = $null
        }
    }
    if ($severityCount.HIGH -ge 3) {
        return [pscustomobject]@{
            verdict          = 'FIX'
            rationale_seed   = "$($severityCount.HIGH) HIGH findings (≥3 threshold); FIX verdict."
            escalate_trigger = $null
        }
    }

    # 2. ESCALATE — mechanical triggers (ordered: disagreement > low-confidence > timeout-borderline > ensemble)
    if ($HasSeverityDisagreement.IsPresent) {
        return [pscustomobject]@{
            verdict          = 'ESCALATE'
            rationale_seed   = "3/3 role disagreement on severity of same finding; requires human judgment."
            escalate_trigger = 'severity_disagreement'
        }
    }
    if ($allLowConf) {
        return [pscustomobject]@{
            verdict          = 'ESCALATE'
            rationale_seed   = "All completing roles reported confidence <0.5; mechanical escalate per CHK-040 (LLMs rarely self-abstain)."
            escalate_trigger = 'all_low_confidence'
        }
    }
    if ($timedOutRoles.Count -ge 1 -and $someBorderline) {
        return [pscustomobject]@{
            verdict          = 'ESCALATE'
            rationale_seed   = "Role timeout ($($timedOutRoles.Count) timed out) combined with borderline confidence in remaining roles; mechanical escalate."
            escalate_trigger = 'timeout_with_borderline'
        }
    }
    if ($EnsembleAllDisagree.IsPresent) {
        return [pscustomobject]@{
            verdict          = 'ESCALATE'
            rationale_seed   = "Ensemble mode: all models produced disjoint findings; mechanical escalate per wiki/patterns/multi-model-ensemble.md §5.6."
            escalate_trigger = 'ensemble_all_disagree'
        }
    }

    # 3. INVESTIGATE — evidence incomplete
    if ($evidenceIncomplete) {
        return [pscustomobject]@{
            verdict          = 'INVESTIGATE'
            rationale_seed   = "At least one finding flagged evidence_incomplete; requires further research before verdict."
            escalate_trigger = $null
        }
    }

    # 4. ACCEPT — no blocking findings and no mechanical trigger
    $caveats = $someBorderline
    $rationale = if ($caveats) {
        "0 CRITICAL; <3 HIGH; some roles reported borderline confidence (0.5-0.85). ACCEPT with caveats rendered in report."
    } else {
        "No blocking findings; all completing roles reported high confidence (>=0.85). ACCEPT."
    }
    return [pscustomobject]@{
        verdict          = 'ACCEPT'
        rationale_seed   = $rationale
        escalate_trigger = $null
        caveats          = $caveats
    }
}
