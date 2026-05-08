#Requires -Version 7
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

<#
.SYNOPSIS
  Pester tests for scripts/seq-increment.ps1.
#>

BeforeAll {
    . $PSScriptRoot/atomic-write.ps1
    . $PSScriptRoot/channel-helpers.ps1
    . $PSScriptRoot/seq-increment.ps1

    $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "mad-seq-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
    $script:ChannelsRoot = Join-Path $script:TestRoot 'channels'
    New-Item -ItemType Directory -Path $script:ChannelsRoot -Force | Out-Null

    function script:Init-TestChannel {
        param([string] $Name)
        New-Item -ItemType Directory -Path (Join-Path $script:ChannelsRoot $Name) -Force | Out-Null
        Initialize-SeqFile -ChannelName $Name -Root $script:ChannelsRoot
    }
}

AfterAll {
    if (Test-Path $script:TestRoot) {
        Remove-Item -LiteralPath $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Initialize-SeqFile + Get-SeqCurrent' {
    It 'creates seq.json with current=0' {
        script:Init-TestChannel -Name 'init-a'
        Get-SeqCurrent -ChannelName 'init-a' -Root $script:ChannelsRoot | Should -Be 0
    }
}

Describe 'Invoke-SeqIncrement — sequential' {
    BeforeEach {
        script:Init-TestChannel -Name 'seq-seq'
    }

    It 'first call returns 1 and persists current=1' {
        $claimed = Invoke-SeqIncrement -ChannelName 'seq-seq' -Root $script:ChannelsRoot
        $claimed | Should -Be 1
        Get-SeqCurrent -ChannelName 'seq-seq' -Root $script:ChannelsRoot | Should -Be 1
    }

    It '10 sequential calls return 1..10 in order' {
        $claims = @()
        for ($i = 0; $i -lt 10; $i++) {
            $claims += Invoke-SeqIncrement -ChannelName 'seq-seq' -Root $script:ChannelsRoot
        }
        $claims | Should -Be @(1..10)
        Get-SeqCurrent -ChannelName 'seq-seq' -Root $script:ChannelsRoot | Should -Be 10
    }

    It 'records alias + session_id when provided' {
        script:Init-TestChannel -Name 'seq-ident'
        $null = Invoke-SeqIncrement -ChannelName 'seq-ident' -Alias 'Alice' -SessionId 'sess-1' -Root $script:ChannelsRoot
        $seqPath = Join-Path $script:ChannelsRoot 'seq-ident' 'seq.json'
        $s = Read-AtomicJson -Path $seqPath
        $s.last_incremented_by.alias | Should -Be 'Alice'
        $s.last_incremented_by.session_id | Should -Be 'sess-1'
    }
}

Describe 'Invoke-SeqIncrement — failure modes' {
    It 'throws SeqIncrementExhausted when MaxAttempts all fail' {
        script:Init-TestChannel -Name 'seq-exhaust'
        Mock -CommandName Write-AtomicJson -MockWith { throw 'simulated write failure' }

        {
            Invoke-SeqIncrement -ChannelName 'seq-exhaust' -MaxAttempts 2 -TimeoutSeconds 10 -Root $script:ChannelsRoot
        } | Should -Throw -ExpectedMessage '*SeqIncrementExhausted*'
        Should -Invoke Write-AtomicJson -Exactly 2
    }

    It 'throws when seq.json is missing' {
        {
            Invoke-SeqIncrement -ChannelName 'never-initialized' -MaxAttempts 1 -TimeoutSeconds 2 -Root $script:ChannelsRoot
        } | Should -Throw -ExpectedMessage '*Read*'
    }
}
