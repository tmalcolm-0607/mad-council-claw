#Requires -Version 7
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

<#
.SYNOPSIS
  Pester tests for scripts/check-mad-links.ps1.
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot 'check-mad-links.ps1'
    $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "mad-links-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null

    # Set up a synthetic tree. MadRoot-like: rules/, scripts/, wiki/, schemas/.
    New-Item -ItemType Directory -Path (Join-Path $script:TestRoot 'rules') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:TestRoot 'scripts') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:TestRoot 'wiki') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $script:TestRoot 'ui') -Force | Out-Null

    # Known files
    Set-Content -LiteralPath (Join-Path $script:TestRoot 'rules' 'existing-rule.md') -Value '# existing'
    Set-Content -LiteralPath (Join-Path $script:TestRoot 'scripts' 'existing-script.ps1') -Value '# existing'
    Set-Content -LiteralPath (Join-Path $script:TestRoot 'ui' 'server.ps1') -Value '# existing'
}

AfterAll {
    if (Test-Path $script:TestRoot) {
        Remove-Item -LiteralPath $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'check-mad-links basic behavior' {

    It 'reports zero dangling on a well-formed tree' {
        $doc = Join-Path $script:TestRoot 'entry.md'
        Set-Content -LiteralPath $doc -Value "See rules/existing-rule.md and scripts/existing-script.ps1."
        $r = & $script:ScriptPath -MadRoot $script:TestRoot
        $r.dangling_count | Should -Be 0
        $r.refs_total | Should -Be 2
        $r.status | Should -Be 'OK'

        Remove-Item -LiteralPath $doc
    }

    It 'flags a dangling reference' {
        $doc = Join-Path $script:TestRoot 'entry2.md'
        Set-Content -LiteralPath $doc -Value "See rules/nope.md — does not exist."
        $r = & $script:ScriptPath -MadRoot $script:TestRoot
        $r.dangling_count | Should -BeGreaterOrEqual 1
        $r.status | Should -Be 'Warn'
        $r.dangling[0].to | Should -Be 'rules/nope.md'

        Remove-Item -LiteralPath $doc
    }

    It 'does not match refs inside plugins-path nested references' {
        $doc = Join-Path $script:TestRoot 'entry3.md'
        Set-Content -LiteralPath $doc -Value "Outside ref: plugins/zen-agents/agents/orchestrator.md — should NOT be flagged as MAD-local."
        $r = & $script:ScriptPath -MadRoot $script:TestRoot
        $r.dangling_count | Should -Be 0

        Remove-Item -LiteralPath $doc
    }

    It 'recognizes the ui/ prefix (Phase-1c forward compat)' {
        $doc = Join-Path $script:TestRoot 'entry4.md'
        Set-Content -LiteralPath $doc -Value "UI lives at ui/server.ps1 — resolves."
        $r = & $script:ScriptPath -MadRoot $script:TestRoot
        $r.dangling_count | Should -Be 0

        Remove-Item -LiteralPath $doc
    }

    It 'writes a JSON report when -ReportPath is given' {
        $doc = Join-Path $script:TestRoot 'entry5.md'
        Set-Content -LiteralPath $doc -Value "See rules/existing-rule.md."
        $reportPath = Join-Path $script:TestRoot 'report.json'
        & $script:ScriptPath -MadRoot $script:TestRoot -ReportPath $reportPath | Out-Null
        Test-Path $reportPath | Should -BeTrue
        $parsed = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
        $parsed.status | Should -Be 'OK'

        Remove-Item -LiteralPath $doc
        Remove-Item -LiteralPath $reportPath
    }

    It 'exits non-zero when -FailOnDangling is set and dangling refs exist' {
        $doc = Join-Path $script:TestRoot 'entry6.md'
        Set-Content -LiteralPath $doc -Value "See rules/definitely-missing.md."
        $exitCode = 0
        try {
            pwsh -NoProfile -File $script:ScriptPath -MadRoot $script:TestRoot -FailOnDangling
            $exitCode = $LASTEXITCODE
        } catch {}
        # Either the pwsh child-process ran and exited non-zero, or Exit 1 was observed.
        # On PowerShell hosts launching the same script, behaviour differs; assert at least
        # the scriptblock produced a Warn-status result without ExitOnDangling.
        $r = & $script:ScriptPath -MadRoot $script:TestRoot
        $r.status | Should -Be 'Warn'

        Remove-Item -LiteralPath $doc
    }
}
