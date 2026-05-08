#Requires -Version 7
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

<#
.SYNOPSIS
  Unit tests for scripts/pattern-verify.ps1.

.DESCRIPTION
  Covers T1-18 from skills/council-review/tests.md plus evidence-verification
  cases per wiki/patterns/evidence-beats-assertion.md.
#>

BeforeAll {
    . (Join-Path $PSScriptRoot 'pattern-verify.ps1')

    function script:Make-Finding {
        param(
            [string] $Role = 'skeptic',
            [string] $Severity = 'MEDIUM',
            [string] $Summary = 'finding summary',
            [string] $Evidence = $null,
            [bool] $IsImprovement = $false
        )
        $obj = [pscustomobject]@{
            role       = $Role
            severity   = $Severity
            summary    = $Summary
            confidence = 0.8
        }
        if ($Evidence) {
            $obj | Add-Member -MemberType NoteProperty -Name 'evidence' -Value $Evidence
        }
        if ($IsImprovement) {
            $obj | Add-Member -MemberType NoteProperty -Name 'is_improvement' -Value $true
        }
        return $obj
    }

    # Mock resolver: returns $null (success) or failure string
    function script:Make-MockResolver {
        param([hashtable] $PathToFailure = @{})
        $h = $PathToFailure
        return {
            param($file, $line, $quote, $root)
            $key = "$file`:$line"
            if ($h.ContainsKey($key)) { return $h[$key] }
            return $null  # success
        }.GetNewClosure()
    }
}

Describe 'pattern-verify :: improvement annotation (T1-18)' {
    It 'T1-18: finding with is_improvement=true → annotation added + demoted to OBSERVATION' {
        $f = @(Make-Finding -Severity 'MEDIUM' -IsImprovement $true -Evidence 'file.cs:42')
        $resolver = Make-MockResolver
        $result = Invoke-PatternVerify -Findings $f -RepoRoot 'C:/fake' -EvidenceResolver $resolver
        $result[0].severity | Should -Be 'OBSERVATION'
        $result[0].pattern_improvement_note | Should -Match 'improvement'
        $result[0].demotion.filter | Should -Be 'pattern-verify'
        $result[0].demotion.reason | Should -Match 'improvement'
    }

    It 'improvement annotation + successful evidence verification coexist' {
        $f = @(Make-Finding -Severity 'HIGH' -IsImprovement $true -Evidence 'file.cs:10')
        $resolver = Make-MockResolver
        $result = Invoke-PatternVerify -Findings $f -RepoRoot 'C:/fake' -EvidenceResolver $resolver
        $result[0].severity | Should -Be 'OBSERVATION'
        $result[0].verification_status | Should -Be 'verified'
        $result[0].pattern_improvement_note | Should -Not -BeNullOrEmpty
    }

    It 'no is_improvement flag → no annotation' {
        $f = @(Make-Finding -Severity 'MEDIUM' -Evidence 'file.cs:10')
        $resolver = Make-MockResolver
        $result = Invoke-PatternVerify -Findings $f -RepoRoot 'C:/fake' -EvidenceResolver $resolver
        $result[0].PSObject.Properties['pattern_improvement_note'] | Should -BeNullOrEmpty
        $result[0].severity | Should -Be 'MEDIUM'
    }
}

Describe 'pattern-verify :: evidence verification passes' {
    It 'valid cite (file exists, line in bounds) → verification_status=verified, severity unchanged' {
        $f = @(Make-Finding -Severity 'HIGH' -Evidence 'src/foo.cs:42')
        $resolver = Make-MockResolver  # default: all succeed
        $result = Invoke-PatternVerify -Findings $f -RepoRoot 'C:/fake' -EvidenceResolver $resolver
        $result[0].verification_status | Should -Be 'verified'
        $result[0].severity | Should -Be 'HIGH'
    }

    It 'quoted snippet match still counts as verified' {
        $f = @(Make-Finding -Severity 'MEDIUM' -Evidence "foo.cs:10 'var x = 1'")
        $resolver = Make-MockResolver
        $result = Invoke-PatternVerify -Findings $f -RepoRoot 'C:/fake' -EvidenceResolver $resolver
        $result[0].verification_status | Should -Be 'verified'
    }

    It 'line-range cite parses and verifies' {
        $f = @(Make-Finding -Severity 'MEDIUM' -Evidence 'foo.cs:42-50')
        $resolver = Make-MockResolver
        $result = Invoke-PatternVerify -Findings $f -RepoRoot 'C:/fake' -EvidenceResolver $resolver
        $result[0].verification_status | Should -Be 'verified'
    }
}

Describe 'pattern-verify :: evidence verification failures' {
    It 'file not found → demoted to OBSERVATION with verification failure' {
        $f = @(Make-Finding -Severity 'HIGH' -Evidence 'nonexistent.cs:10')
        $resolver = Make-MockResolver -PathToFailure @{ 'nonexistent.cs:10' = 'file not found: nonexistent.cs' }
        $result = Invoke-PatternVerify -Findings $f -RepoRoot 'C:/fake' -EvidenceResolver $resolver
        $result[0].severity | Should -Be 'OBSERVATION'
        $result[0].verification_status | Should -Be 'failed'
        $result[0].verification.reason | Should -Match 'file not found'
        $result[0].demotion.filter | Should -Be 'pattern-verify'
        $result[0].demotion.demoted_from | Should -Be 'HIGH'
    }

    It 'line out of range → demoted + reason captured' {
        $f = @(Make-Finding -Severity 'MEDIUM' -Evidence 'foo.cs:9999')
        $resolver = Make-MockResolver -PathToFailure @{ 'foo.cs:9999' = 'line 9999 out of range (file has 100 lines)' }
        $result = Invoke-PatternVerify -Findings $f -RepoRoot 'C:/fake' -EvidenceResolver $resolver
        $result[0].severity | Should -Be 'OBSERVATION'
        $result[0].verification.reason | Should -Match 'out of range'
    }

    It 'quoted snippet not found → demoted' {
        $f = @(Make-Finding -Severity 'HIGH' -Evidence "foo.cs:42 'unexpected text'")
        $resolver = Make-MockResolver -PathToFailure @{ 'foo.cs:42' = 'quoted snippet not found within +/-3 lines of line 42' }
        $result = Invoke-PatternVerify -Findings $f -RepoRoot 'C:/fake' -EvidenceResolver $resolver
        $result[0].severity | Should -Be 'OBSERVATION'
        $result[0].verification.reason | Should -Match 'snippet not found'
    }
}

Describe 'pattern-verify :: findings without evidence' {
    It 'finding with no evidence field → no verification_status set, pass through' {
        $f = @(Make-Finding -Severity 'MEDIUM')  # no evidence
        $resolver = Make-MockResolver
        $result = Invoke-PatternVerify -Findings $f -RepoRoot 'C:/fake' -EvidenceResolver $resolver
        $result[0].severity | Should -Be 'MEDIUM'
        $result[0].PSObject.Properties['verification_status'] | Should -BeNullOrEmpty
    }

    It 'malformed evidence string → no verification attempted, pass through' {
        $f = @(Make-Finding -Severity 'HIGH' -Evidence 'just some text without file:line')
        $resolver = Make-MockResolver
        $result = Invoke-PatternVerify -Findings $f -RepoRoot 'C:/fake' -EvidenceResolver $resolver
        $result[0].severity | Should -Be 'HIGH'
        $result[0].PSObject.Properties['verification_status'] | Should -BeNullOrEmpty
    }
}

Describe 'pattern-verify :: SkipEvidenceVerification' {
    It 'flag skips pass 1 — improvement annotation still runs' {
        $f = @(Make-Finding -Severity 'HIGH' -IsImprovement $true -Evidence 'bogus:file')
        $result = Invoke-PatternVerify -Findings $f -SkipEvidenceVerification
        $result[0].severity | Should -Be 'OBSERVATION'
        $result[0].pattern_improvement_note | Should -Not -BeNullOrEmpty
        $result[0].PSObject.Properties['verification_status'] | Should -BeNullOrEmpty
    }

    It 'no RepoRoot / no resolver / SkipEvidenceVerification → does not throw' {
        $f = @(Make-Finding -Severity 'MEDIUM' -Evidence 'foo.cs:10')
        { Invoke-PatternVerify -Findings $f -SkipEvidenceVerification } | Should -Not -Throw
    }
}

Describe 'pattern-verify :: parsing edge cases' {
    It 'double-quoted snippet parses correctly' {
        $f = @(Make-Finding -Severity 'MEDIUM' -Evidence 'foo.cs:10 "quoted text"')
        $resolver = Make-MockResolver  # succeeds
        $result = Invoke-PatternVerify -Findings $f -RepoRoot 'C:/fake' -EvidenceResolver $resolver
        $result[0].verification_status | Should -Be 'verified'
    }

    It 'paths with spaces resolved correctly' {
        $f = @(Make-Finding -Severity 'MEDIUM' -Evidence 'src/my folder/foo.cs:42')
        $resolver = Make-MockResolver
        $result = Invoke-PatternVerify -Findings $f -RepoRoot 'C:/fake' -EvidenceResolver $resolver
        $result[0].verification_status | Should -Be 'verified'
    }
}

Describe 'pattern-verify :: batching' {
    It 'mixed findings: some verified, some failed, some improvement, some no-evidence' {
        $f = @(
            (Make-Finding -Severity 'HIGH'     -Evidence 'good.cs:10'),
            (Make-Finding -Severity 'CRITICAL' -Evidence 'bad.cs:99'),
            (Make-Finding -Severity 'MEDIUM'   -IsImprovement $true -Evidence 'good.cs:20'),
            (Make-Finding -Severity 'LOW')  # no evidence
        )
        $resolver = Make-MockResolver -PathToFailure @{ 'bad.cs:99' = 'file not found: bad.cs' }
        $result = Invoke-PatternVerify -Findings $f -RepoRoot 'C:/fake' -EvidenceResolver $resolver
        $result.Count | Should -Be 4
        $result[0].verification_status | Should -Be 'verified'
        $result[0].severity | Should -Be 'HIGH'
        $result[1].verification_status | Should -Be 'failed'
        $result[1].severity | Should -Be 'OBSERVATION'
        $result[2].severity | Should -Be 'OBSERVATION'
        $result[2].pattern_improvement_note | Should -Not -BeNullOrEmpty
        $result[3].severity | Should -Be 'LOW'  # no evidence, untouched
        $result[3].PSObject.Properties['verification_status'] | Should -BeNullOrEmpty
    }

    It 'empty findings → empty result' {
        $result = Invoke-PatternVerify -Findings @() -SkipEvidenceVerification
        $result.Count | Should -Be 0
    }
}

Describe 'pattern-verify :: input validation' {
    It 'no RepoRoot + no resolver + no skip → throws' {
        $f = @(Make-Finding -Severity 'MEDIUM' -Evidence 'foo.cs:10')
        { Invoke-PatternVerify -Findings $f } | Should -Throw
    }
}
