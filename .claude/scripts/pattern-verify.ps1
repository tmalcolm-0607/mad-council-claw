<#
.SYNOPSIS
  Pattern-verification pass on Council findings. Two passes:
    1. Evidence verification — cited file:line resolves and (if quoted) matches snippet
    2. Improvement annotation — findings flagged as "deviation is improvement"
       get annotated and demoted to OBSERVATION
  Phase-2 implementation per iter-39 audit (CHK-064).

.DESCRIPTION
  Invoked by skills/council-review/plan.md Step 7. Runs two independent checks:

  **Pass 1 — Evidence verification** (per wiki/patterns/evidence-beats-assertion.md)

  For each finding with an `evidence` field of shape "file:line" or
  "file:line-range" or "file:line 'quoted snippet'":
    - Resolve file path against -RepoRoot (or treat as absolute if exists).
    - Verify file exists.
    - Verify line number within file bounds.
    - If a quoted snippet is present, verify it appears within ±3 lines of
      the cited line.
    - On failure: demote severity to OBSERVATION, set verification_status='failed',
      add `verification` annotation with the failure reason.
    - On success: set verification_status='verified'.
    - On missing cite or malformed: skip (pass through, no status set).

  **Pass 2 — Improvement annotation** (per skills/council-review/SKILL.md §Step 6,
  wiki/patterns/multi-role-review.md §5.7)

  For each finding with `is_improvement=$true` flag:
    - Demote severity to OBSERVATION.
    - Add `pattern_improvement_note` annotation: "deviation matches an improvement
      over the cited pattern; consider adopting."
    - Add `demotion` record (filter=pattern-verify, reason=improvement).

  Findings without `is_improvement` are untouched by pass 2.

.PARAMETER Findings
  Array of finding PSCustomObjects. Required.

.PARAMETER RepoRoot
  Path to the repo for resolving cited file paths. Required for pass 1 unless
  -EvidenceResolver override is provided.

.PARAMETER EvidenceResolver
  Optional scriptblock for test isolation. Signature:
    param([string] $File, [int] $Line, [string] $QuotedSnippet, [string] $RepoRoot)
    returns $null on success or a string describing the failure reason.

.PARAMETER SkipEvidenceVerification
  If set, skip pass 1 entirely. Useful when evidence verification is handled
  elsewhere in the pipeline. Pass 2 (improvement annotation) still runs.

.OUTPUTS
  Findings array (same length). Modified findings have:
    - verification_status: 'verified'|'failed' (pass 1)
    - verification: @{ reason } (pass 1, on failure only)
    - pattern_improvement_note: string (pass 2)
    - demotion: @{ filter='pattern-verify'; ... } (when demoted by either pass)

.NOTES
  Rule anchor: wiki/patterns/evidence-beats-assertion.md,
  skills/council-review/SKILL.md §Step 6, wiki/patterns/multi-role-review.md §5.7.
  Test coverage: scripts/pattern-verify.Tests.ps1 (T1-18 from
  skills/council-review/tests.md plus evidence-verification cases).
#>

Set-StrictMode -Version Latest

function script:Parse-EvidenceCite {
    <#
    .SYNOPSIS
      Internal: parse an evidence string into { file, line, quote }.
      Supports:
        'file.cs:42'            → file=file.cs, line=42, quote=$null
        'file.cs:42-50'         → file=file.cs, line=42 (start), quote=$null
        "file.cs:42 'some code'"→ file=file.cs, line=42, quote='some code'
        'file.cs:42 "text"'     → same, double-quoted
      Returns $null on unparseable.
    #>
    param([Parameter(Mandatory)] [string] $Evidence)

    if ([string]::IsNullOrWhiteSpace($Evidence)) { return $null }
    $s = $Evidence.Trim()

    # Extract quoted snippet first (if present)
    $quote = $null
    $q = [regex]::Match($s, "['""]([^'""]+)['""]")
    if ($q.Success) {
        $quote = $q.Groups[1].Value
        $s = $s.Substring(0, $q.Index).Trim()
    }

    # Parse file:line[-end]
    $m = [regex]::Match($s, '^(.+?):(\d+)(?:-(\d+))?$')
    if (-not $m.Success) { return $null }

    return [pscustomobject]@{
        file  = $m.Groups[1].Value
        line  = [int]$m.Groups[2].Value
        quote = $quote
    }
}

function script:Invoke-DefaultEvidenceResolver {
    param(
        [Parameter(Mandatory)] [string] $File,
        [Parameter(Mandatory)] [int] $Line,
        [AllowNull()] [string] $QuotedSnippet,
        [Parameter(Mandatory)] [string] $RepoRoot
    )
    # Resolve file path — try as absolute, then as repo-relative
    $resolved = $null
    if ([System.IO.Path]::IsPathRooted($File) -and (Test-Path -LiteralPath $File -PathType Leaf)) {
        $resolved = $File
    } else {
        $candidate = Join-Path $RepoRoot $File
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $resolved = $candidate
        }
    }
    if (-not $resolved) {
        return "file not found: $File (RepoRoot=$RepoRoot)"
    }

    # Line-bound check
    $content = Get-Content -LiteralPath $resolved -ErrorAction Stop
    $lineCount = @($content).Count
    if ($Line -lt 1 -or $Line -gt $lineCount) {
        return "line $Line out of range (file has $lineCount lines)"
    }

    # Quoted snippet check: search ±3 lines around the cited line
    if ($QuotedSnippet) {
        $from = [Math]::Max(0, $Line - 4)
        $to = [Math]::Min($lineCount - 1, $Line + 2)
        $window = $content[$from..$to] -join "`n"
        if ($window -notlike "*$QuotedSnippet*") {
            return "quoted snippet not found within +/-3 lines of line $Line"
        }
    }

    return $null  # success
}

function Invoke-PatternVerify {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [AllowEmptyCollection()] [object[]] $Findings,
        [Parameter(Mandatory = $false)] [string] $RepoRoot = $null,
        [Parameter(Mandatory = $false)] [scriptblock] $EvidenceResolver = $null,
        [Parameter(Mandatory = $false)] [switch] $SkipEvidenceVerification
    )

    if ($Findings.Count -eq 0) { return , @() }

    # Validate: pass 1 needs either RepoRoot or EvidenceResolver (unless skipped)
    if (-not $SkipEvidenceVerification) {
        if (-not $RepoRoot -and -not $EvidenceResolver) {
            throw "Invoke-PatternVerify pass 1 requires either -RepoRoot or -EvidenceResolver, or -SkipEvidenceVerification."
        }
    }

    $resolver = if ($EvidenceResolver) { $EvidenceResolver } else {
        { param($f, $l, $q, $r) Invoke-DefaultEvidenceResolver -File $f -Line $l -QuotedSnippet $q -RepoRoot $r }.GetNewClosure()
    }

    $out = foreach ($f in $Findings) {
        $current = $f | Select-Object -Property *
        $originalSeverity = [string]$current.severity

        # --- Pass 1: evidence verification ---
        if (-not $SkipEvidenceVerification) {
            $props = $current.PSObject.Properties
            $ev = if ($props['evidence']) { [string]$current.evidence } else { $null }

            if ($ev) {
                $parsed = Parse-EvidenceCite -Evidence $ev
                if ($parsed) {
                    $failure = & $resolver $parsed.file $parsed.line $parsed.quote $RepoRoot
                    if ($failure) {
                        # Failed — demote to OBSERVATION
                        $current | Add-Member -MemberType NoteProperty -Name 'verification_status' -Value 'failed' -Force
                        $current | Add-Member -MemberType NoteProperty -Name 'verification' -Value ([pscustomobject]@{
                            reason = $failure
                        }) -Force
                        # Demote only if not already demoted by prior pass
                        if ($originalSeverity -ne 'OBSERVATION') {
                            $current | Add-Member -MemberType NoteProperty -Name 'severity' -Value 'OBSERVATION' -Force
                            if (-not $current.PSObject.Properties['demotion']) {
                                $current | Add-Member -MemberType NoteProperty -Name 'demotion' -Value ([pscustomobject]@{
                                    filter       = 'pattern-verify'
                                    reason       = 'evidence verification failed'
                                    demoted_from = $originalSeverity
                                    detail       = $failure
                                }) -Force
                            }
                        }
                    } else {
                        $current | Add-Member -MemberType NoteProperty -Name 'verification_status' -Value 'verified' -Force
                    }
                }
                # unparseable evidence: skip (no status set)
            }
        }

        # --- Pass 2: improvement annotation ---
        $props2 = $current.PSObject.Properties
        $isImprovement = $false
        if ($props2['is_improvement']) {
            $isImprovement = [bool]$current.is_improvement
        }

        if ($isImprovement) {
            $current | Add-Member -MemberType NoteProperty -Name 'pattern_improvement_note' -Value 'deviation matches an improvement over the cited pattern; consider adopting.' -Force
            $sevNow = [string]$current.severity
            if ($sevNow -ne 'OBSERVATION') {
                $current | Add-Member -MemberType NoteProperty -Name 'severity' -Value 'OBSERVATION' -Force
                if (-not $current.PSObject.Properties['demotion']) {
                    $current | Add-Member -MemberType NoteProperty -Name 'demotion' -Value ([pscustomobject]@{
                        filter       = 'pattern-verify'
                        reason       = 'deviation is improvement'
                        demoted_from = $sevNow
                    }) -Force
                }
            }
        }

        $current
    }

    return , @($out)
}
