#Requires -Version 7
# Pester 5.x suite for MAD/ui/derive-metrics.ps1.
# Builds a mock channel tree in a temp root and asserts aggregate shape.

BeforeAll {
    . (Join-Path $PSScriptRoot 'derive-metrics.ps1')

    $script:Root = Join-Path ([System.IO.Path]::GetTempPath()) ("mad-metrics-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path (Join-Path $script:Root 'channels') -Force | Out-Null

    # Channel A (local, active): 2 threads, 1 verdict, 3 messages (1 suspicious)
    $chA = Join-Path $script:Root 'channels' 'alpha'
    New-Item -ItemType Directory -Path (Join-Path $chA 'threads' 't-1' 'messages') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $chA 'threads' 't-2' 'messages') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $chA 'read-markers') -Force | Out-Null
    @{
        name = 'alpha'; environment_tier = 'local'; status = 'active'; owner_alias = 'alice'
        members = @(@{ alias = 'alice'; status = 'active' }, @{ alias = 'bob'; status = 'active' })
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $chA 'channel.json') -Encoding UTF8
    @{ channel_seq = 10; threads = @() } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $chA 'digest.json') -Encoding UTF8
    @{ thread_id = 't-1'; status = 'active' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $chA 'threads' 't-1' 'thread.json') -Encoding UTF8
    @{ thread_id = 't-2'; status = 'resolved' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $chA 'threads' 't-2' 'thread.json') -Encoding UTF8
    @{ seq = 1; type = 'question'; body = 'q1'; alias = 'alice' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $chA 'threads' 't-1' 'messages' '0001.json') -Encoding UTF8
    @{ seq = 2; type = 'answer';   body = 'a1'; alias = 'bob'; suspicious = $true } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $chA 'threads' 't-1' 'messages' '0002.json') -Encoding UTF8
    @{ seq = 3; type = 'question'; body = 'q2'; alias = 'alice' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $chA 'threads' 't-2' 'messages' '0003.json') -Encoding UTF8
    @{ thread_id = 't-1'; verdict = 'ACCEPT'; issued_utc = '2026-04-18T00:00:00Z' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $chA 'threads' 't-1' 'verdict.json') -Encoding UTF8
    @{ alias = 'alice'; last_channel_seq_seen = 8 } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $chA 'read-markers' 'alice.json') -Encoding UTF8
    @{ alias = 'bob';   last_channel_seq_seen = 10 } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $chA 'read-markers' 'bob.json') -Encoding UTF8

    # Channel B (prod, triage): 1 thread, 0 verdicts, 0 messages
    $chB = Join-Path $script:Root 'channels' 'beta'
    New-Item -ItemType Directory -Path (Join-Path $chB 'threads' 't-1' 'messages') -Force | Out-Null
    @{
        name = 'beta'; environment_tier = 'prod'; status = 'triage'; owner_alias = 'charlie'
        members = @(@{ alias = 'charlie'; status = 'active' })
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $chB 'channel.json') -Encoding UTF8
    @{ thread_id = 't-1'; status = 'active' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $chB 'threads' 't-1' 'thread.json') -Encoding UTF8

    # Dogfood channel: mad-self-hosting with 1 verdict
    $chDog = Join-Path $script:Root 'channels' 'mad-self-hosting'
    New-Item -ItemType Directory -Path (Join-Path $chDog 'threads' 'd-1' 'messages') -Force | Out-Null
    @{
        name = 'mad-self-hosting'; environment_tier = 'local'; status = 'triage'; owner_alias = 'tonym'
        members = @(@{ alias = 'tonym'; status = 'active' })
        acceptance_criteria = 'ship phase-1b'
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $chDog 'channel.json') -Encoding UTF8
    @{ thread_id = 'd-1' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $chDog 'threads' 'd-1' 'thread.json') -Encoding UTF8
    @{ thread_id = 'd-1'; verdict = 'ACCEPT'; issued_utc = '2026-04-18T00:00:00Z' } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $chDog 'threads' 'd-1' 'verdict.json') -Encoding UTF8

    $script:Metrics = Get-MadMetrics -Root $script:Root
}

AfterAll {
    if ($script:Root -and (Test-Path -LiteralPath $script:Root)) {
        Remove-Item -LiteralPath $script:Root -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'derive-metrics.ps1' {

    It 'counts channels correctly' {
        $script:Metrics.channels.total | Should -Be 3
    }

    It 'breaks down by tier' {
        $script:Metrics.channels.by_tier.local | Should -Be 2
        $script:Metrics.channels.by_tier.prod  | Should -Be 1
    }

    It 'breaks down by status' {
        $script:Metrics.channels.by_status.active | Should -Be 1
        $script:Metrics.channels.by_status.triage | Should -Be 2
    }

    It 'sums active members across channels' {
        # alpha: alice+bob = 2 active, beta: charlie = 1, dogfood: tonym = 1. Total 4.
        $script:Metrics.channels.active_members_total | Should -Be 4
    }

    It 'counts threads (total + by status + with/without verdict)' {
        $script:Metrics.threads.total | Should -Be 4
        # verdicts: alpha t-1 + mad-self-hosting d-1 = 2 with verdict
        $script:Metrics.threads.with_verdict    | Should -Be 2
        $script:Metrics.threads.without_verdict | Should -Be 2
        # alpha t-1 (active) + beta t-1 (active) + mad-self-hosting d-1 (default active) = 3
        $script:Metrics.threads.by_status.active | Should -Be 3
        $script:Metrics.threads.by_status.resolved | Should -Be 1
    }

    It 'counts messages (total + suspicious + by type)' {
        $script:Metrics.messages.total | Should -Be 3
        $script:Metrics.messages.suspicious_count | Should -Be 1
        $script:Metrics.messages.types.question | Should -Be 2
        $script:Metrics.messages.types.answer   | Should -Be 1
    }

    It 'counts verdicts by verdict value' {
        $script:Metrics.verdicts.total | Should -Be 2
        $script:Metrics.verdicts.by_verdict.ACCEPT | Should -Be 2
    }

    It 'bins unread into histogram' {
        # alpha: alice seen=8 chseq=10 → unread=2 → 1-5 bucket. bob seen=10 → unread=0 → 0 bucket.
        $script:Metrics.unread_histogram['0']   | Should -Be 1
        $script:Metrics.unread_histogram['1-5'] | Should -Be 1
    }

    It 'detects dogfood channel and acceptance' {
        $script:Metrics.dogfood.channel             | Should -Be 'mad-self-hosting'
        $script:Metrics.dogfood.verdicts_count      | Should -Be 1
        $script:Metrics.dogfood.acceptance_met_bool | Should -BeTrue
    }

    It 'returns an empty-but-well-formed object when root missing' {
        $emptyRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("mad-empty-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        $result = Get-MadMetrics -Root $emptyRoot
        $result.channels.total | Should -Be 0
        $result.threads.total  | Should -Be 0
    }
}
