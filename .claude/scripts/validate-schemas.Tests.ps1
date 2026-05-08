#Requires -Version 7
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

<#
.SYNOPSIS
  Pester tests for scripts/validate-schemas.ps1.
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot 'validate-schemas.ps1'
    $script:MadRoot    = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
    $script:TestRoot   = Join-Path ([System.IO.Path]::GetTempPath()) "mad-vs-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
}

AfterAll {
    if (Test-Path $script:TestRoot) {
        Remove-Item -LiteralPath $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'validate-schemas basic behavior' {

    It 'returns OK on an empty directory' {
        $emptyDir = Join-Path $script:TestRoot 'empty'
        New-Item -ItemType Directory -Path $emptyDir -Force | Out-Null
        $r = & $script:ScriptPath -MadRoot $script:MadRoot -Path $emptyDir
        $r.status | Should -Be 'OK'
        $r.files_scanned | Should -Be 0
    }

    It 'validates a well-formed channel.json fixture' {
        $fx = Join-Path $script:TestRoot 'good-channel'
        New-Item -ItemType Directory -Path $fx -Force | Out-Null
        $channel = @{
            schema_version   = 2
            name             = 'test-ch'
            purpose          = 'validate-schemas test'
            created_utc      = (Get-Date).ToUniversalTime().ToString('o')
            owner_alias      = 'Alice'
            environment_tier = 'local'
            members          = @(@{
                alias         = 'Alice'
                session_id    = 'sess-a'
                joined_utc    = (Get-Date).ToUniversalTime().ToString('o')
                status        = 'active'
            })
            settings         = @{ mad_enabled = $false; a2a_enabled = $false }
        }
        $channel | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $fx 'channel.json') -Encoding UTF8

        $r = & $script:ScriptPath -MadRoot $script:MadRoot -Path $fx
        $r.status | Should -Be 'OK'
        $r.valid | Should -Be 1
        $r.invalid | Should -Be 0
    }

    It 'flags a channel.json missing required fields as invalid' {
        $fx = Join-Path $script:TestRoot 'bad-channel'
        New-Item -ItemType Directory -Path $fx -Force | Out-Null
        # Missing several required fields
        @{ name = 'broken' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $fx 'channel.json') -Encoding UTF8

        $r = & $script:ScriptPath -MadRoot $script:MadRoot -Path $fx
        $r.status | Should -Be 'Fail'
        $r.invalid | Should -BeGreaterOrEqual 1
    }

    It 'skips files with no schema match' {
        $fx = Join-Path $script:TestRoot 'skipfile'
        New-Item -ItemType Directory -Path $fx -Force | Out-Null
        @{ anything = 'here' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $fx 'unknown-thing.json') -Encoding UTF8

        $r = & $script:ScriptPath -MadRoot $script:MadRoot -Path $fx
        $r.skipped | Should -Be 1
        $r.status | Should -Be 'OK'
    }

    It 'validates a seq.json by direct filename match' {
        $fx = Join-Path $script:TestRoot 'good-seq'
        New-Item -ItemType Directory -Path $fx -Force | Out-Null
        @{
            current              = 0
            last_incremented_utc = (Get-Date).ToUniversalTime().ToString('o')
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $fx 'seq.json') -Encoding UTF8

        $r = & $script:ScriptPath -MadRoot $script:MadRoot -Path $fx
        $r.valid | Should -Be 1
        $r.invalid | Should -Be 0
    }

    It 'matches messages under messages/ parent dir by convention' {
        $fx = Join-Path $script:TestRoot 'good-msg' 'messages'
        New-Item -ItemType Directory -Path $fx -Force | Out-Null
        @{
            id              = 'msg-001'
            seq             = 1
            thread_id       = 'test'
            from            = @{ alias = 'Alice'; session_id = 'sess-a' }
            timestamp_utc   = (Get-Date).ToUniversalTime().ToString('o')
            type            = 'fyi'
            body            = 'hi'
            body_size_bytes = 2
        } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $fx '1-2026-04-18T00-00-00Z-Alice.json') -Encoding UTF8

        $r = & $script:ScriptPath -MadRoot $script:MadRoot -Path (Join-Path $script:TestRoot 'good-msg')
        $r.valid | Should -Be 1
        ($r.results | Where-Object status -eq 'valid')[0].schema | Should -Be 'message.schema.json'
    }

    It 'returns an empty-result object when target path is missing' {
        $nope = Join-Path $script:TestRoot 'does-not-exist-at-all'
        $r = & $script:ScriptPath -MadRoot $script:MadRoot -Path $nope
        $r.status | Should -Be 'OK'
        $r.files_scanned | Should -Be 0
    }

    It 'writes a JSON report when -ReportPath is given' {
        $fx = Join-Path $script:TestRoot 'report-path'
        New-Item -ItemType Directory -Path $fx -Force | Out-Null
        $reportPath = Join-Path $script:TestRoot 'validate-report.json'
        & $script:ScriptPath -MadRoot $script:MadRoot -Path $fx -ReportPath $reportPath | Out-Null
        Test-Path $reportPath | Should -BeTrue
        (Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json).status | Should -Be 'OK'
    }
}
