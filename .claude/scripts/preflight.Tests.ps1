#Requires -Version 7
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

<#
.SYNOPSIS
  Pester tests for scripts/preflight.ps1.

.DESCRIPTION
  Covers Invoke-Preflight with writable / unwritable roots, orphan .tmp sweep,
  A2A bridge probing, and report rendering.
#>

BeforeAll {
    . $PSScriptRoot/preflight.ps1

    $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "mad-preflight-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
}

AfterAll {
    if (Test-Path $script:TestRoot) {
        Remove-Item -LiteralPath $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Invoke-Preflight' {
    It 'returns Status=OK on a writable root' {
        $env:MAD_CRONCREATE_OK = 'true'    # suppress CronCreate warn
        $env:MAD_CHECK_CLOCK = $null       # skip network-dependent clock check
        $r = Invoke-Preflight -Context council-open -ClaudeDataRoot $script:TestRoot
        $r.Status | Should -Be 'OK'
        $r.Checks | Where-Object name -eq 'claude-data-writable' | ForEach-Object { $_.status | Should -Be 'OK' }
    }

    It 'returns Warn when CronCreate availability is not confirmed' {
        $env:MAD_CRONCREATE_OK = $null
        $r = Invoke-Preflight -Context council-open -ClaudeDataRoot $script:TestRoot
        $r.Status | Should -Be 'Warn'
        $r.Checks | Where-Object name -eq 'croncreate-available' | ForEach-Object { $_.status | Should -Be 'Warn' }
        $env:MAD_CRONCREATE_OK = 'true'  # restore
    }

    It 'includes A2A bridge reachability check when enabled' {
        $r = Invoke-Preflight -Context council-open -ClaudeDataRoot $script:TestRoot `
            -A2aEnabled $true -A2aBridgeUrl 'http://127.0.0.1:1'  # deliberate bad port
        $a2aCheck = $r.Checks | Where-Object name -eq 'a2a-bridge-reachable'
        $a2aCheck | Should -Not -BeNullOrEmpty
        $a2aCheck.status | Should -Be 'Warn'
    }

    It 'omits A2A check when A2aEnabled is false' {
        $r = Invoke-Preflight -Context council-open -ClaudeDataRoot $script:TestRoot -A2aEnabled $false
        $r.Checks | Where-Object name -eq 'a2a-bridge-reachable' | Should -BeNullOrEmpty
    }

    It 'fails when claude-data root is unwritable (mocked)' {
        Mock -CommandName Set-Content -MockWith { throw 'permission denied' }
        # Need the check: fresh root must be created AND probe must fail on write.
        $badRoot = Join-Path $script:TestRoot "unwritable-$([guid]::NewGuid().ToString('N').Substring(0,4))"
        $r = Invoke-Preflight -Context council-open -ClaudeDataRoot $badRoot
        $r.Status | Should -Be 'Fail'
        ($r.Checks | Where-Object name -eq 'claude-data-writable').status | Should -Be 'Fail'
    }

    It 'includes orphan-tmp-sweep in every run' {
        $r = Invoke-Preflight -Context council-open -ClaudeDataRoot $script:TestRoot
        $r.Checks | Where-Object name -eq 'orphan-tmp-sweep' | Should -Not -BeNullOrEmpty
    }
}

Describe 'Invoke-OrphanTmpSweep' {
    BeforeEach {
        $script:SweepRoot = Join-Path $script:TestRoot "sweep-$([guid]::NewGuid().ToString('N').Substring(0,4))"
        New-Item -ItemType Directory -Path $script:SweepRoot -Force | Out-Null
    }

    It 'removes .tmp files older than threshold' {
        $old = Join-Path $script:SweepRoot 'stale.tmp'
        Set-Content -LiteralPath $old -Value 'x'
        # Force the file's LastWriteTime back by 120 seconds
        (Get-Item -LiteralPath $old).LastWriteTime = (Get-Date).AddSeconds(-120)

        $r = Invoke-OrphanTmpSweep -ChannelsRoot $script:SweepRoot -MaxAgeSeconds 60
        $r.removed_count | Should -Be 1
        Test-Path -LiteralPath $old | Should -BeFalse
    }

    It 'keeps .tmp files newer than threshold' {
        $fresh = Join-Path $script:SweepRoot 'fresh.tmp'
        Set-Content -LiteralPath $fresh -Value 'x'

        $r = Invoke-OrphanTmpSweep -ChannelsRoot $script:SweepRoot -MaxAgeSeconds 60
        $r.removed_count | Should -Be 0
        Test-Path -LiteralPath $fresh | Should -BeTrue
    }

    It 'handles missing channels root gracefully' {
        $r = Invoke-OrphanTmpSweep -ChannelsRoot (Join-Path $script:TestRoot 'nope') -MaxAgeSeconds 60
        $r.removed_count | Should -Be 0
    }
}

Describe 'Format-PreflightReport' {
    It 'renders a summary line with check counts' {
        $result = [pscustomobject]@{
            Status = 'Warn'
            Checks = @(
                [pscustomobject]@{ name='x'; required=$true;  status='OK';   message='alive' }
                [pscustomobject]@{ name='y'; required=$false; status='Warn'; message='meh' }
            )
            ContextGaps = @()
        }
        $report = Format-PreflightReport -PreflightResult $result -Context 'council-open'
        $report | Should -Match 'Preflight Checks for /council-open'
        $report | Should -Match '1/2 OK, 1 warnings'
        $report | Should -Match 'Overall: Warn'
    }
}
