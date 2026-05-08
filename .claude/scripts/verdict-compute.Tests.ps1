#Requires -Version 7
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

<#
.SYNOPSIS
  Unit tests for scripts/verdict-compute.ps1.

.DESCRIPTION
  Covers test cases T1-06 through T1-15 from skills/council-review/tests.md
  (the verdict-compute logic subset of /council-review Layer 1 unit tests).

  Does NOT cover T1-16 through T1-18 (YAGNI + pattern-verify — separate
  scripts have their own Tests.ps1) or T1-19 through T1-21 (dedup + sort
  live in the /council-review orchestrator, not in verdict-compute).
#>

BeforeAll {
    . (Join-Path $PSScriptRoot 'verdict-compute.ps1')

    function script:New-Finding {
        param(
            [Parameter(Mandatory)] [string] $Severity,
            [bool] $EvidenceIncomplete = $false,
            [string] $Cite = 'file.cs:42',
            [double] $Confidence = 0.9
        )
        $obj = [pscustomobject]@{
            severity            = $Severity
            cite                = $Cite
            confidence          = $Confidence
            evidence_incomplete = $EvidenceIncomplete
        }
        return $obj
    }

    function script:New-Role {
        param(
            [Parameter(Mandatory)] [string] $Name,
            [double] $Confidence = 0.9,
            [bool] $TimedOut = $false
        )
        return [pscustomobject]@{
            role       = $Name
            confidence = $Confidence
            timed_out  = $TimedOut
        }
    }

    function script:Default-Roles {
        return @(
            (New-Role -Name 'advocate'  -Confidence 0.9),
            (New-Role -Name 'skeptic'   -Confidence 0.9),
            (New-Role -Name 'architect' -Confidence 0.9)
        )
    }
}

Describe 'verdict-compute :: FIX decisions (T1-06, T1-07)' {
    It 'T1-06: 1 CRITICAL finding → FIX' {
        $f = @((New-Finding -Severity 'CRITICAL'))
        $r = Default-Roles
        $result = Invoke-VerdictCompute -Findings $f -Roles $r
        $result.verdict | Should -Be 'FIX'
        $result.rationale_seed | Should -Match 'CRITICAL'
        $result.escalate_trigger | Should -BeNullOrEmpty
    }

    It 'T1-07: 3 HIGH findings → FIX' {
        $f = @(
            (New-Finding -Severity 'HIGH'),
            (New-Finding -Severity 'HIGH'),
            (New-Finding -Severity 'HIGH')
        )
        $r = Default-Roles
        $result = Invoke-VerdictCompute -Findings $f -Roles $r
        $result.verdict | Should -Be 'FIX'
        $result.rationale_seed | Should -Match 'HIGH'
    }

    It '2 HIGH findings (below threshold) alone → NOT FIX' {
        $f = @(
            (New-Finding -Severity 'HIGH'),
            (New-Finding -Severity 'HIGH')
        )
        $r = Default-Roles
        $result = Invoke-VerdictCompute -Findings $f -Roles $r
        $result.verdict | Should -Not -Be 'FIX'
    }
}

Describe 'verdict-compute :: ACCEPT decisions (T1-08, T1-13, T1-14)' {
    It 'T1-08: 2 HIGH findings, otherwise clean, high confidence → ACCEPT' {
        $f = @(
            (New-Finding -Severity 'HIGH'),
            (New-Finding -Severity 'HIGH')
        )
        $r = Default-Roles  # all 0.9
        $result = Invoke-VerdictCompute -Findings $f -Roles $r
        $result.verdict | Should -Be 'ACCEPT'
        $result.caveats | Should -Be $false
    }

    It 'T1-13: 0 CRITICAL, 0 HIGH, some MEDIUM, high confidence → ACCEPT (no caveats)' {
        $f = @(
            (New-Finding -Severity 'MEDIUM'),
            (New-Finding -Severity 'LOW')
        )
        $r = Default-Roles
        $result = Invoke-VerdictCompute -Findings $f -Roles $r
        $result.verdict | Should -Be 'ACCEPT'
        $result.caveats | Should -Be $false
    }

    It 'T1-14: 0 CRITICAL, 0 HIGH, some MEDIUM, borderline confidence → ACCEPT with caveats' {
        $f = @(
            (New-Finding -Severity 'MEDIUM')
        )
        $r = @(
            (New-Role -Name 'advocate'  -Confidence 0.9),
            (New-Role -Name 'skeptic'   -Confidence 0.7),  # borderline
            (New-Role -Name 'architect' -Confidence 0.9)
        )
        $result = Invoke-VerdictCompute -Findings $f -Roles $r
        $result.verdict | Should -Be 'ACCEPT'
        $result.caveats | Should -Be $true
    }

    It 'Empty findings array + high-confidence roles → ACCEPT' {
        $result = Invoke-VerdictCompute -Findings @() -Roles (Default-Roles)
        $result.verdict | Should -Be 'ACCEPT'
        $result.caveats | Should -Be $false
    }
}

Describe 'verdict-compute :: ESCALATE mechanical triggers (T1-09, T1-10, T1-11)' {
    It 'T1-09: all roles confidence <0.5 → ESCALATE (all_low_confidence)' {
        $f = @((New-Finding -Severity 'MEDIUM'))
        $r = @(
            (New-Role -Name 'advocate'  -Confidence 0.3),
            (New-Role -Name 'skeptic'   -Confidence 0.4),
            (New-Role -Name 'architect' -Confidence 0.2)
        )
        $result = Invoke-VerdictCompute -Findings $f -Roles $r
        $result.verdict | Should -Be 'ESCALATE'
        $result.escalate_trigger | Should -Be 'all_low_confidence'
    }

    It 'T1-10: 3/3 severity disagreement signal → ESCALATE (severity_disagreement)' {
        $f = @((New-Finding -Severity 'HIGH'))
        $r = Default-Roles
        $result = Invoke-VerdictCompute -Findings $f -Roles $r -HasSeverityDisagreement
        $result.verdict | Should -Be 'ESCALATE'
        $result.escalate_trigger | Should -Be 'severity_disagreement'
    }

    It 'T1-11: 1 role timed out + some remaining borderline → ESCALATE (timeout_with_borderline)' {
        $f = @((New-Finding -Severity 'MEDIUM'))
        $r = @(
            (New-Role -Name 'advocate'  -Confidence 0.7),   # borderline
            (New-Role -Name 'skeptic'   -Confidence 0.95),  # high
            (New-Role -Name 'architect' -TimedOut $true -Confidence 0)
        )
        $result = Invoke-VerdictCompute -Findings $f -Roles $r
        $result.verdict | Should -Be 'ESCALATE'
        $result.escalate_trigger | Should -Be 'timeout_with_borderline'
    }

    It 'Ensemble all disagree signal → ESCALATE (ensemble_all_disagree)' {
        $f = @((New-Finding -Severity 'MEDIUM'))
        $r = Default-Roles
        $result = Invoke-VerdictCompute -Findings $f -Roles $r -EnsembleAllDisagree
        $result.verdict | Should -Be 'ESCALATE'
        $result.escalate_trigger | Should -Be 'ensemble_all_disagree'
    }

    It 'Role timed out but remaining all high-confidence (no borderline) → NOT ESCALATE via timeout trigger' {
        $f = @((New-Finding -Severity 'MEDIUM'))
        $r = @(
            (New-Role -Name 'advocate'  -Confidence 0.95),
            (New-Role -Name 'skeptic'   -Confidence 0.95),
            (New-Role -Name 'architect' -TimedOut $true -Confidence 0)
        )
        $result = Invoke-VerdictCompute -Findings $f -Roles $r
        $result.verdict | Should -Be 'ACCEPT'
        $result.escalate_trigger | Should -BeNullOrEmpty
    }
}

Describe 'verdict-compute :: INVESTIGATE (T1-12)' {
    It 'T1-12: finding with evidence_incomplete=true → INVESTIGATE' {
        $f = @(
            (New-Finding -Severity 'MEDIUM' -EvidenceIncomplete $true)
        )
        $r = Default-Roles
        $result = Invoke-VerdictCompute -Findings $f -Roles $r
        $result.verdict | Should -Be 'INVESTIGATE'
        $result.rationale_seed | Should -Match 'evidence_incomplete'
    }

    It 'evidence_incomplete on LOW severity → still INVESTIGATE' {
        $f = @(
            (New-Finding -Severity 'LOW' -EvidenceIncomplete $true)
        )
        $r = Default-Roles
        $result = Invoke-VerdictCompute -Findings $f -Roles $r
        $result.verdict | Should -Be 'INVESTIGATE'
    }
}

Describe 'verdict-compute :: priority ordering (T1-15)' {
    It 'T1-15: CRITICAL finding + severity disagreement signal → FIX wins (not ESCALATE)' {
        $f = @((New-Finding -Severity 'CRITICAL'))
        $r = Default-Roles
        $result = Invoke-VerdictCompute -Findings $f -Roles $r -HasSeverityDisagreement
        $result.verdict | Should -Be 'FIX'
    }

    It 'CRITICAL finding + all_low_confidence → FIX wins' {
        $f = @((New-Finding -Severity 'CRITICAL'))
        $r = @(
            (New-Role -Name 'advocate'  -Confidence 0.2),
            (New-Role -Name 'skeptic'   -Confidence 0.2),
            (New-Role -Name 'architect' -Confidence 0.2)
        )
        $result = Invoke-VerdictCompute -Findings $f -Roles $r
        $result.verdict | Should -Be 'FIX'
    }

    It 'ESCALATE trigger + evidence_incomplete → ESCALATE wins over INVESTIGATE' {
        $f = @((New-Finding -Severity 'MEDIUM' -EvidenceIncomplete $true))
        $r = Default-Roles
        $result = Invoke-VerdictCompute -Findings $f -Roles $r -HasSeverityDisagreement
        $result.verdict | Should -Be 'ESCALATE'
    }

    It 'No triggers → ACCEPT (baseline)' {
        $f = @((New-Finding -Severity 'LOW'))
        $r = Default-Roles
        $result = Invoke-VerdictCompute -Findings $f -Roles $r
        $result.verdict | Should -Be 'ACCEPT'
    }
}

Describe 'verdict-compute :: input validation' {
    It 'Throws when Roles is empty' {
        # PowerShell param binding rejects empty Roles array before our body check.
        # Either message is acceptable — just confirm it throws.
        { Invoke-VerdictCompute -Findings @() -Roles @() } | Should -Throw
    }

    It 'Accepts empty findings array' {
        { Invoke-VerdictCompute -Findings @() -Roles (Default-Roles) } | Should -Not -Throw
    }

    It 'Ignores unrecognized severity values' {
        $f = @(
            [pscustomobject]@{ severity = 'UNKNOWN_SEV'; cite = 'x:1' }
        )
        $r = Default-Roles
        $result = Invoke-VerdictCompute -Findings $f -Roles $r
        $result.verdict | Should -Be 'ACCEPT'
    }
}
