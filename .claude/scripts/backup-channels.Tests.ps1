#Requires -Version 7
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

<#
.SYNOPSIS
  Pester tests for scripts/backup-channels.ps1.
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot 'backup-channels.ps1'
    $script:TestRoot   = Join-Path ([System.IO.Path]::GetTempPath()) "mad-bkp-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null

    function script:Seed-Source {
        param([string] $Root)
        $channels = Join-Path $Root 'channels'
        $ch1 = Join-Path $channels 'svc-a'
        New-Item -ItemType Directory -Path (Join-Path $ch1 'threads' 't1' 'messages') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $ch1 'read-markers') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $ch1 'channel.json') -Value '{"name":"svc-a"}'
        Set-Content -LiteralPath (Join-Path $ch1 'seq.json') -Value '{"current":0}'
        Set-Content -LiteralPath (Join-Path $ch1 'digest.json') -Value '{"channel_seq":0}'
        Set-Content -LiteralPath (Join-Path $ch1 'threads' 't1' 'thread.json') -Value '{"thread_id":"t1"}'
        Set-Content -LiteralPath (Join-Path $ch1 'threads' 't1' 'messages' '1-2026-04-18-Alice.json') -Value '{"seq":1}'
        Set-Content -LiteralPath (Join-Path $ch1 'read-markers' 'Alice.json') -Value '{"last_read_seq":0}'

        # Excluded artifacts
        Set-Content -LiteralPath (Join-Path $ch1 'channel.json.abc123.tmp') -Value 'orphan'
        Set-Content -LiteralPath (Join-Path $Root '.sessions.json') -Value '{"session_id":"sess-a"}'

        # Archive subtree
        $arch = Join-Path $Root 'archive' '2026-04-17-old-ch'
        New-Item -ItemType Directory -Path $arch -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $arch 'channel.json') -Value '{"archived":true}'
    }
}

AfterAll {
    if (Test-Path $script:TestRoot) {
        Remove-Item -LiteralPath $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'backup-channels basic behavior' {

    It 'copies source tree to a timestamped dest dir' {
        $src = Join-Path $script:TestRoot 'src-happy'
        $dst = Join-Path $script:TestRoot 'dst-happy'
        script:Seed-Source -Root $src

        $r = & $script:ScriptPath -Source $src -Dest $dst
        $r.status | Should -Be 'OK'
        $r.files_copied | Should -BeGreaterOrEqual 6   # channel + seq + digest + thread + message + marker + archived-channel = 7
        $r.dest | Should -Match 'backup-\d{4}-\d{2}-\d{2}'
        Test-Path (Join-Path $r.dest 'channels' 'svc-a' 'channel.json') | Should -BeTrue
    }

    It 'excludes *.tmp files' {
        $src = Join-Path $script:TestRoot 'src-tmp'
        $dst = Join-Path $script:TestRoot 'dst-tmp'
        script:Seed-Source -Root $src

        $r = & $script:ScriptPath -Source $src -Dest $dst
        # Orphan .tmp should NOT appear in the destination
        Test-Path (Join-Path $r.dest 'channels' 'svc-a' 'channel.json.abc123.tmp') | Should -BeFalse
        $r.files_skipped | Should -BeGreaterOrEqual 2   # tmp + .sessions.json
    }

    It 'excludes .sessions.json' {
        $src = Join-Path $script:TestRoot 'src-sess'
        $dst = Join-Path $script:TestRoot 'dst-sess'
        script:Seed-Source -Root $src

        $r = & $script:ScriptPath -Source $src -Dest $dst
        Test-Path (Join-Path $r.dest '.sessions.json') | Should -BeFalse
    }

    It 'includes the archive subtree by default' {
        $src = Join-Path $script:TestRoot 'src-arch-yes'
        $dst = Join-Path $script:TestRoot 'dst-arch-yes'
        script:Seed-Source -Root $src

        $r = & $script:ScriptPath -Source $src -Dest $dst
        Test-Path (Join-Path $r.dest 'archive' '2026-04-17-old-ch' 'channel.json') | Should -BeTrue
    }

    It 'skips archive when -IncludeArchive:$false' {
        $src = Join-Path $script:TestRoot 'src-arch-no'
        $dst = Join-Path $script:TestRoot 'dst-arch-no'
        script:Seed-Source -Root $src

        $r = & $script:ScriptPath -Source $src -Dest $dst -IncludeArchive:$false
        Test-Path (Join-Path $r.dest 'archive') | Should -BeFalse
    }

    It 'returns a DryRun report without copying' {
        $src = Join-Path $script:TestRoot 'src-dry'
        $dst = Join-Path $script:TestRoot 'dst-dry'
        script:Seed-Source -Root $src

        $r = & $script:ScriptPath -Source $src -Dest $dst -DryRun
        $r.status | Should -Be 'DryRun'
        $r.dry_run | Should -BeTrue
        $r.files_planned | Should -BeGreaterOrEqual 6
        $r.files_copied | Should -Be 0
        Test-Path $r.dest | Should -BeFalse
    }

    It 'throws when source is missing' {
        $dst = Join-Path $script:TestRoot 'dst-missing'
        { & $script:ScriptPath -Source (Join-Path $script:TestRoot 'does-not-exist') -Dest $dst } |
            Should -Throw -ExpectedMessage '*Source not found*'
    }

    It 'creates dest root if absent' {
        $src = Join-Path $script:TestRoot 'src-autocreate'
        $dst = Join-Path $script:TestRoot 'dst-autocreate-fresh'
        script:Seed-Source -Root $src

        Test-Path $dst | Should -BeFalse
        $r = & $script:ScriptPath -Source $src -Dest $dst
        Test-Path $r.dest | Should -BeTrue
    }
}
