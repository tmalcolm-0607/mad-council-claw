#Requires -Version 7
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

<#
.SYNOPSIS
  Pester tests for scripts/digest-rebuild.ps1.
#>

BeforeAll {
    . $PSScriptRoot/atomic-write.ps1
    . $PSScriptRoot/channel-helpers.ps1
    . $PSScriptRoot/digest-rebuild.ps1

    $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "mad-dig-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
    $script:ChannelsRoot = Join-Path $script:TestRoot 'channels'
    New-Item -ItemType Directory -Path $script:ChannelsRoot -Force | Out-Null

    function script:Seed-Channel {
        param([string] $Name)
        $dir = Join-Path $script:ChannelsRoot $Name
        New-Item -ItemType Directory -Path (Join-Path $dir 'threads')      -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $dir 'read-markers') -Force | Out-Null
        Initialize-DigestFile -ChannelName $Name -Root $script:ChannelsRoot
    }

    function script:Seed-Thread {
        param(
            [string] $Channel,
            [string] $ThreadId,
            [string] $Status = 'active',
            [int[]] $MessageSeqs = @()
        )
        $tdir = Join-Path $script:ChannelsRoot $Channel 'threads' $ThreadId
        $mdir = Join-Path $tdir 'messages'
        New-Item -ItemType Directory -Path $mdir -Force | Out-Null

        Write-AtomicJson -Path (Join-Path $tdir 'thread.json') -Content ([ordered]@{
            thread_id   = $ThreadId
            status      = $Status
            created_utc = (Get-Date).ToUniversalTime().ToString('o')
        })
        foreach ($seq in $MessageSeqs) {
            $msgName = "$seq-2026-04-18T00-00-00Z-Alice.json"
            Write-AtomicJson -Path (Join-Path $mdir $msgName) -Content ([ordered]@{
                id  = "msg-$([string]$seq).PadLeft(3,'0')"
                seq = $seq
                thread_id = $ThreadId
                from = @{ alias = 'Alice'; session_id = 'sess-a' }
                type = 'fyi'
                body = 'test'
                timestamp_utc = '2026-04-18T00:00:00Z'
                body_size_bytes = 4
            })
        }
    }
}

AfterAll {
    if (Test-Path $script:TestRoot) {
        Remove-Item -LiteralPath $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Initialize-DigestFile' {
    It 'writes a zero-state digest' {
        script:Seed-Channel -Name 'd-init'
        $d = Get-DigestPayload -ChannelName 'd-init' -Root $script:ChannelsRoot
        $d.channel_seq | Should -Be 0
        $d.total_messages | Should -Be 0
        @($d.threads).Count | Should -Be 0
    }

    It 'includes mad_state skeleton when MadEnabled is true' {
        script:Seed-Channel -Name 'd-mad'
        Initialize-DigestFile -ChannelName 'd-mad' -MadEnabled $true -Root $script:ChannelsRoot
        $d = Get-DigestPayload -ChannelName 'd-mad' -Root $script:ChannelsRoot
        $d.mad_state.phase | Should -Be 'spec-drafting'
    }
}

Describe 'Invoke-DigestRebuild — empty channel' {
    It 'produces threads=[] and channel_seq=0 on fresh channel' {
        script:Seed-Channel -Name 'd-empty'
        $d = Invoke-DigestRebuild -ChannelName 'd-empty' -Root $script:ChannelsRoot
        $d.channel_seq | Should -Be 0
        @($d.threads).Count | Should -Be 0
        $d.total_messages | Should -Be 0
    }
}

Describe 'Invoke-DigestRebuild — one thread, three messages' {
    BeforeAll {
        script:Seed-Channel -Name 'd-one'
        script:Seed-Thread -Channel 'd-one' -ThreadId 't1' -MessageSeqs @(1, 2, 3)
    }

    It 'computes channel_seq = max of message seqs (3)' {
        $d = Invoke-DigestRebuild -ChannelName 'd-one' -Root $script:ChannelsRoot
        $d.channel_seq | Should -Be 3
        $d.total_messages | Should -Be 3
        @($d.threads).Count | Should -Be 1
        $d.threads[0].thread_id | Should -Be 't1'
        $d.threads[0].last_msg_seq | Should -Be 3
        $d.threads[0].message_count | Should -Be 3
        $d.threads[0].status | Should -Be 'active'
    }
}

Describe 'Invoke-DigestRebuild — two threads, different status' {
    BeforeAll {
        script:Seed-Channel -Name 'd-two'
        script:Seed-Thread -Channel 'd-two' -ThreadId 't-a' -Status 'active'   -MessageSeqs @(1, 2)
        script:Seed-Thread -Channel 'd-two' -ThreadId 't-r' -Status 'resolved' -MessageSeqs @(3, 4, 5)
    }

    It 'channel_seq = max across both threads (5)' {
        $d = Invoke-DigestRebuild -ChannelName 'd-two' -Root $script:ChannelsRoot
        $d.channel_seq | Should -Be 5
        $d.total_messages | Should -Be 5
        @($d.threads).Count | Should -Be 2
    }

    It 'preserves per-thread status' {
        $d = Invoke-DigestRebuild -ChannelName 'd-two' -Root $script:ChannelsRoot
        ($d.threads | Where-Object thread_id -eq 't-a').status | Should -Be 'active'
        ($d.threads | Where-Object thread_id -eq 't-r').status | Should -Be 'resolved'
    }
}

Describe 'Invoke-DigestRebuild — context gaps' {
    It 'records a context gap for a thread with unreadable thread.json' {
        script:Seed-Channel -Name 'd-gap'
        script:Seed-Thread -Channel 'd-gap' -ThreadId 't-good' -MessageSeqs @(1)

        # Create a broken thread.json
        $broken = Join-Path $script:ChannelsRoot 'd-gap' 'threads' 't-broken'
        New-Item -ItemType Directory -Path (Join-Path $broken 'messages') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $broken 'thread.json') -Value '{ not-json'

        $d = Invoke-DigestRebuild -ChannelName 'd-gap' -Root $script:ChannelsRoot
        @($d.threads | ForEach-Object thread_id) | Should -Contain 't-good'
        @($d.threads | ForEach-Object thread_id) | Should -Not -Contain 't-broken'
        $d.context_gaps | Should -Not -BeNullOrEmpty
        $d.context_gaps[0].source | Should -Match 't-broken'
    }
}
