#Requires -Version 7
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

<#
.SYNOPSIS
  Unit tests for scripts/yagni-filter.ps1.

.DESCRIPTION
  Covers T1-16 and T1-17 from skills/council-review/tests.md plus
  edge cases (non-Skeptic findings, no suggested symbol, explicit field
  vs regex extraction, scanner injection for test isolation).
#>

BeforeAll {
    . (Join-Path $PSScriptRoot 'yagni-filter.ps1')

    function script:Make-Finding {
        param(
            [string] $Role = 'skeptic',
            [string] $Severity = 'MEDIUM',
            [string] $Summary = '',
            [string] $Description = '',
            [string] $SuggestedSymbol = $null
        )
        $obj = [pscustomobject]@{
            role        = $Role
            severity    = $Severity
            summary     = $Summary
            description = $Description
            cite        = 'file.cs:10'
            confidence  = 0.8
        }
        if ($SuggestedSymbol) {
            $obj | Add-Member -MemberType NoteProperty -Name 'suggested_symbol' -Value $SuggestedSymbol
        }
        return $obj
    }

    # Scanner injection: returns N callers for symbols we whitelist.
    function script:Make-MockScanner {
        param([hashtable] $SymbolCounts)
        $h = $SymbolCounts
        return {
            param($sym, $root)
            if ($h.ContainsKey($sym)) { return [int]$h[$sym] }
            return 0
        }.GetNewClosure()
    }
}

Describe 'yagni-filter :: demotion (T1-16)' {
    It 'T1-16: skeptic finding suggests add processBatch(), 0 callers → demoted to LOW' {
        $f = @(Make-Finding -Role 'skeptic' -Severity 'MEDIUM' -SuggestedSymbol 'processBatch')
        $scanner = Make-MockScanner -SymbolCounts @{}  # all symbols return 0 callers
        $result = Invoke-YagniFilter -Findings $f -RepoRoot 'C:/fake' -CallerScanner $scanner
        $result.Count | Should -Be 1
        $result[0].severity | Should -Be 'LOW'
        $result[0].demotion.filter | Should -Be 'YAGNI'
        $result[0].demotion.reason | Should -Be 'no callers found'
        $result[0].demotion.demoted_from | Should -Be 'MEDIUM'
        $result[0].demotion.symbol | Should -Be 'processBatch'
    }

    It 'CRITICAL skeptic finding with 0 callers → demoted to LOW (severity collapses)' {
        $f = @(Make-Finding -Role 'skeptic' -Severity 'CRITICAL' -SuggestedSymbol 'neverCalled')
        $scanner = Make-MockScanner -SymbolCounts @{}
        $result = Invoke-YagniFilter -Findings $f -RepoRoot 'C:/fake' -CallerScanner $scanner
        $result[0].severity | Should -Be 'LOW'
        $result[0].demotion.demoted_from | Should -Be 'CRITICAL'
    }
}

Describe 'yagni-filter :: retention (T1-17)' {
    It 'T1-17: skeptic finding suggests add processBatch(), 2 callers → retain severity' {
        $f = @(Make-Finding -Role 'skeptic' -Severity 'MEDIUM' -SuggestedSymbol 'processBatch')
        $scanner = Make-MockScanner -SymbolCounts @{ 'processBatch' = 2 }
        $result = Invoke-YagniFilter -Findings $f -RepoRoot 'C:/fake' -CallerScanner $scanner
        $result[0].severity | Should -Be 'MEDIUM'
        $result[0].PSObject.Properties['demotion'] | Should -BeNullOrEmpty
    }

    It 'skeptic finding with 1 caller → retain (>= 1 is the threshold)' {
        $f = @(Make-Finding -Role 'skeptic' -Severity 'HIGH' -SuggestedSymbol 'foo')
        $scanner = Make-MockScanner -SymbolCounts @{ 'foo' = 1 }
        $result = Invoke-YagniFilter -Findings $f -RepoRoot 'C:/fake' -CallerScanner $scanner
        $result[0].severity | Should -Be 'HIGH'
    }
}

Describe 'yagni-filter :: pass-through (non-Skeptic roles)' {
    It 'advocate finding with 0-caller symbol → NOT filtered (passes through)' {
        $f = @(Make-Finding -Role 'advocate' -Severity 'HIGH' -SuggestedSymbol 'unused')
        $scanner = Make-MockScanner -SymbolCounts @{}
        $result = Invoke-YagniFilter -Findings $f -RepoRoot 'C:/fake' -CallerScanner $scanner
        $result[0].severity | Should -Be 'HIGH'
        $result[0].PSObject.Properties['demotion'] | Should -BeNullOrEmpty
    }

    It 'architect finding with 0-caller symbol → NOT filtered' {
        $f = @(Make-Finding -Role 'architect' -Severity 'MEDIUM' -SuggestedSymbol 'unused')
        $scanner = Make-MockScanner -SymbolCounts @{}
        $result = Invoke-YagniFilter -Findings $f -RepoRoot 'C:/fake' -CallerScanner $scanner
        $result[0].severity | Should -Be 'MEDIUM'
    }

    It 'role casing (Skeptic vs skeptic) treated case-insensitively' {
        $f = @(Make-Finding -Role 'SKEPTIC' -Severity 'MEDIUM' -SuggestedSymbol 'foo')
        $scanner = Make-MockScanner -SymbolCounts @{}
        $result = Invoke-YagniFilter -Findings $f -RepoRoot 'C:/fake' -CallerScanner $scanner
        $result[0].severity | Should -Be 'LOW'  # demoted
    }
}

Describe 'yagni-filter :: no symbol detected (pass-through)' {
    It 'skeptic finding without suggested_symbol and non-matching text → pass through' {
        $f = @(Make-Finding -Role 'skeptic' -Severity 'MEDIUM' -Summary 'missing null check on line 42')
        $scanner = Make-MockScanner -SymbolCounts @{}
        $result = Invoke-YagniFilter -Findings $f -RepoRoot 'C:/fake' -CallerScanner $scanner
        $result[0].severity | Should -Be 'MEDIUM'
        $result[0].PSObject.Properties['demotion'] | Should -BeNullOrEmpty
    }
}

Describe 'yagni-filter :: regex fallback extraction' {
    It 'extracts symbol from "add Foo(" pattern in summary' {
        $f = @(Make-Finding -Role 'skeptic' -Severity 'MEDIUM' -Summary 'We should add processBatch() to handle bulk inputs')
        $scanner = Make-MockScanner -SymbolCounts @{}
        $result = Invoke-YagniFilter -Findings $f -RepoRoot 'C:/fake' -CallerScanner $scanner
        $result[0].severity | Should -Be 'LOW'
        $result[0].demotion.symbol | Should -Be 'processBatch'
    }

    It 'extracts symbol from "introduce X" pattern in description' {
        $f = @(Make-Finding -Role 'skeptic' -Severity 'HIGH' -Description 'Need to introduce ResultPattern for error flow')
        $scanner = Make-MockScanner -SymbolCounts @{}
        $result = Invoke-YagniFilter -Findings $f -RepoRoot 'C:/fake' -CallerScanner $scanner
        $result[0].severity | Should -Be 'LOW'
        $result[0].demotion.symbol | Should -Be 'ResultPattern'
    }

    It 'regex fallback with caller ≥1 → retains severity' {
        $f = @(Make-Finding -Role 'skeptic' -Severity 'MEDIUM' -Summary 'add processBatch() to the API')
        $scanner = Make-MockScanner -SymbolCounts @{ 'processBatch' = 3 }
        $result = Invoke-YagniFilter -Findings $f -RepoRoot 'C:/fake' -CallerScanner $scanner
        $result[0].severity | Should -Be 'MEDIUM'
    }
}

Describe 'yagni-filter :: batching + mixed roles' {
    It 'mixed findings: filters only skeptic suggestions, passes rest' {
        $f = @(
            (Make-Finding -Role 'advocate' -Severity 'HIGH' -SuggestedSymbol 'A'),
            (Make-Finding -Role 'skeptic' -Severity 'HIGH' -SuggestedSymbol 'B'),
            (Make-Finding -Role 'architect' -Severity 'MEDIUM' -SuggestedSymbol 'C'),
            (Make-Finding -Role 'skeptic' -Severity 'CRITICAL' -SuggestedSymbol 'D')
        )
        $scanner = Make-MockScanner -SymbolCounts @{ 'B' = 5 }  # B has callers; D doesn't
        $result = Invoke-YagniFilter -Findings $f -RepoRoot 'C:/fake' -CallerScanner $scanner
        $result.Count | Should -Be 4
        $result[0].severity | Should -Be 'HIGH'  # advocate, untouched
        $result[1].severity | Should -Be 'HIGH'  # skeptic B has callers, retained
        $result[2].severity | Should -Be 'MEDIUM'  # architect, untouched
        $result[3].severity | Should -Be 'LOW'  # skeptic D demoted
        $result[3].demotion.demoted_from | Should -Be 'CRITICAL'
    }

    It 'empty findings array → empty result' {
        $result = Invoke-YagniFilter -Findings @() -RepoRoot 'C:/fake' -CallerScanner { param($s, $r) 0 }
        $result.Count | Should -Be 0
    }
}

Describe 'yagni-filter :: input validation' {
    It 'Throws when neither RepoRoot nor CallerScanner provided' {
        $f = @(Make-Finding -Role 'skeptic' -Severity 'MEDIUM' -SuggestedSymbol 'foo')
        { Invoke-YagniFilter -Findings $f } | Should -Throw
    }

    It 'Succeeds with CallerScanner alone (no RepoRoot)' {
        $f = @(Make-Finding -Role 'skeptic' -Severity 'MEDIUM' -SuggestedSymbol 'foo')
        $scanner = { param($s, $r) 0 }
        { Invoke-YagniFilter -Findings $f -CallerScanner $scanner } | Should -Not -Throw
    }

    It 'Already-demoted finding passes through (not re-demoted)' {
        $existingDemotion = [pscustomobject]@{ filter = 'pattern-verify'; reason = 'improvement'; demoted_from = 'MEDIUM' }
        $f = @(
            [pscustomobject]@{
                role             = 'skeptic'
                severity         = 'LOW'
                summary          = 'add foo()'
                suggested_symbol = 'foo'
                demotion         = $existingDemotion
            }
        )
        $scanner = Make-MockScanner -SymbolCounts @{}
        $result = Invoke-YagniFilter -Findings $f -RepoRoot 'C:/fake' -CallerScanner $scanner
        $result[0].demotion.filter | Should -Be 'pattern-verify'  # unchanged
    }
}
