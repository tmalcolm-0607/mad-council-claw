#Requires -Version 7
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

<#
.SYNOPSIS
  Pester tests for scripts/channel-helpers.ps1.

.DESCRIPTION
  Layer 1 unit coverage for path resolution, metadata read, member lookup,
  session-id binding enforcement, member add/update, and session registry.
#>

BeforeAll {
    . $PSScriptRoot/atomic-write.ps1
    . $PSScriptRoot/channel-helpers.ps1

    $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "mad-channel-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
    $script:ChannelsRoot = Join-Path $script:TestRoot 'channels'
    $script:ClaudeDataRoot = $script:TestRoot
    New-Item -ItemType Directory -Path $script:ChannelsRoot -Force | Out-Null

    # Helper: seed a channel with given members.
    function script:New-TestChannel {
        param(
            [string] $Name,
            [object[]] $Members = @(),
            [string] $OwnerAlias = 'Owner',
            [string] $Tier = 'local'
        )
        $dir = Join-Path $script:ChannelsRoot $Name
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $channel = [ordered]@{
            name            = $Name
            purpose         = 'test channel'
            created_utc     = (Get-Date).ToUniversalTime().ToString('o')
            owner_alias     = $OwnerAlias
            environment_tier = $Tier
            members         = @($Members)
            settings        = @{ mad_enabled = $false; a2a_enabled = $false }
        }
        Write-AtomicJson -Path (Join-Path $dir 'channel.json') -Content $channel
    }
}

AfterAll {
    if (Test-Path $script:TestRoot) {
        Remove-Item -LiteralPath $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Resolve-ChannelPath' {
    It 'returns the expected path under custom root' {
        $p = Resolve-ChannelPath -Name 'test-ch' -Root $script:ChannelsRoot
        $p | Should -Be ([System.IO.Path]::Combine($script:ChannelsRoot, 'test-ch'))
    }

    It 'defaults to home/claude-data/channels when root omitted' {
        $p = Resolve-ChannelPath -Name 'xyz'
        $p | Should -Match 'claude-data[\\/]channels[\\/]xyz$'
    }
}

Describe 'Get-ChannelMetadata' {
    BeforeEach {
        script:New-TestChannel -Name 'meta-test' -Members @(
            [ordered]@{ alias = 'Alice'; session_id = 'sess-1'; joined_utc = '2026-04-18T00:00:00Z'; status = 'active' }
        ) -OwnerAlias 'Alice'
    }

    It 'reads an existing channel' {
        $c = Get-ChannelMetadata -Name 'meta-test' -Root $script:ChannelsRoot
        $c.name | Should -Be 'meta-test'
        $c.owner_alias | Should -Be 'Alice'
        $c.members[0].alias | Should -Be 'Alice'
    }

    It 'throws when channel directory missing' {
        { Get-ChannelMetadata -Name 'does-not-exist' -Root $script:ChannelsRoot } |
            Should -Throw -ExpectedMessage '*File not found*'
    }
}

Describe 'Find-MemberBySession / Find-MemberByAlias' {
    BeforeAll {
        script:New-TestChannel -Name 'find-test' -Members @(
            [ordered]@{ alias = 'Alice'; session_id = 'sess-alice'; joined_utc = '2026-04-18T00:00:00Z'; status = 'active' }
            [ordered]@{ alias = 'Bob';   session_id = 'sess-bob';   joined_utc = '2026-04-18T00:01:00Z'; status = 'active' }
        ) -OwnerAlias 'Alice'
        $script:testChannel = Get-ChannelMetadata -Name 'find-test' -Root $script:ChannelsRoot
    }

    It 'Find-MemberBySession returns the matching member' {
        $m = Find-MemberBySession -Channel $script:testChannel -SessionId 'sess-bob'
        $m.alias | Should -Be 'Bob'
    }

    It 'Find-MemberBySession returns $null on miss' {
        $m = Find-MemberBySession -Channel $script:testChannel -SessionId 'sess-nobody'
        $m | Should -BeNullOrEmpty
    }

    It 'Find-MemberByAlias returns the matching member' {
        $m = Find-MemberByAlias -Channel $script:testChannel -Alias 'Alice'
        $m.session_id | Should -Be 'sess-alice'
    }

    It 'Find-MemberByAlias returns $null on miss' {
        $m = Find-MemberByAlias -Channel $script:testChannel -Alias 'Nobody'
        $m | Should -BeNullOrEmpty
    }
}

Describe 'Assert-SessionBinding' {
    BeforeAll {
        script:New-TestChannel -Name 'bind-test' -Members @(
            [ordered]@{ alias = 'Alice'; session_id = 'sess-alice'; joined_utc = '2026-04-18T00:00:00Z'; status = 'active' }
        ) -OwnerAlias 'Alice'
        $script:bindChannel = Get-ChannelMetadata -Name 'bind-test' -Root $script:ChannelsRoot
    }

    It 'passes silently on matching alias + session' {
        { Assert-SessionBinding -Channel $script:bindChannel -Alias 'Alice' -SessionId 'sess-alice' } |
            Should -Not -Throw
    }

    It 'throws AliasNotMember when alias unknown' {
        { Assert-SessionBinding -Channel $script:bindChannel -Alias 'Mallory' -SessionId 'sess-anything' } |
            Should -Throw -ExpectedMessage '*AliasNotMember*Mallory*'
    }

    It 'throws SessionMismatch on wrong session for known alias' {
        { Assert-SessionBinding -Channel $script:bindChannel -Alias 'Alice' -SessionId 'sess-attacker' } |
            Should -Throw -ExpectedMessage '*SessionMismatch*Alice*'
    }
}

Describe 'Add-ChannelMember' {
    BeforeEach {
        script:New-TestChannel -Name 'add-test' -Members @(
            [ordered]@{ alias = 'Alice'; session_id = 'sess-alice'; joined_utc = '2026-04-18T00:00:00Z'; status = 'active' }
        ) -OwnerAlias 'Alice'
    }

    It 'appends a new member and persists atomically' {
        Add-ChannelMember -Name 'add-test' -Root $script:ChannelsRoot -Member @{
            alias = 'Bob'; session_id = 'sess-bob'; joined_utc = '2026-04-18T00:05:00Z'; status = 'active'
        }
        $c = Get-ChannelMetadata -Name 'add-test' -Root $script:ChannelsRoot
        @($c.members).Count | Should -Be 2
        (Find-MemberByAlias -Channel $c -Alias 'Bob').session_id | Should -Be 'sess-bob'
    }

    It 'rejects duplicate alias' {
        {
            Add-ChannelMember -Name 'add-test' -Root $script:ChannelsRoot -Member @{
                alias = 'Alice'; session_id = 'sess-other'; joined_utc = '2026-04-18T00:05:00Z'; status = 'active'
            }
        } | Should -Throw -ExpectedMessage "*alias 'Alice' already exists*"
    }

    It 'rejects member missing a required field' {
        {
            Add-ChannelMember -Name 'add-test' -Root $script:ChannelsRoot -Member @{
                alias = 'Charlie'; session_id = 'sess-c'  # no joined_utc, no status
            }
        } | Should -Throw -ExpectedMessage '*missing required field*'
    }
}

Describe 'Update-ChannelMember' {
    BeforeEach {
        script:New-TestChannel -Name 'upd-test' -Members @(
            [ordered]@{ alias = 'Alice'; session_id = 'sess-alice'; joined_utc = '2026-04-18T00:00:00Z'; status = 'active' }
        ) -OwnerAlias 'Alice'
    }

    It 'patches the matching member atomically' {
        Update-ChannelMember -Name 'upd-test' -Root $script:ChannelsRoot -Alias 'Alice' -Patch @{
            status        = 'idle'
            last_seen_utc = '2026-04-18T00:10:00Z'
        }
        $c = Get-ChannelMetadata -Name 'upd-test' -Root $script:ChannelsRoot
        $m = Find-MemberByAlias -Channel $c -Alias 'Alice'
        $m.status | Should -Be 'idle'
        # ConvertFrom-Json coerces ISO-8601 strings to [datetime]; compare via
        # DateTimeOffset (preserves zone) to avoid TZ + precision brittleness.
        ([datetimeoffset]$m.last_seen_utc).UtcDateTime | Should -Be ([datetimeoffset]'2026-04-18T00:10:00Z').UtcDateTime
    }

    It 'throws when alias not found' {
        {
            Update-ChannelMember -Name 'upd-test' -Root $script:ChannelsRoot -Alias 'Nobody' -Patch @{ status = 'idle' }
        } | Should -Throw -ExpectedMessage "*alias 'Nobody' not in channel*"
    }
}

Describe 'Get-SessionRegistry / Update-SessionRegistry' {
    BeforeEach {
        # Ensure .sessions.json is absent at start of each test
        $sessPath = Join-Path $script:ClaudeDataRoot '.sessions.json'
        if (Test-Path -LiteralPath $sessPath) {
            Remove-Item -Force -LiteralPath $sessPath
        }
    }

    It 'returns a skeleton when no registry exists' {
        $r = Get-SessionRegistry -Root $script:ClaudeDataRoot
        $r.memberships.Count | Should -Be 0
    }

    It 'adds a membership atomically' {
        Update-SessionRegistry -Root $script:ClaudeDataRoot -SessionId 'sess-X' -ChannelName 'demo' -Alias 'Alice' -Action Add
        $r = Get-SessionRegistry -Root $script:ClaudeDataRoot
        $r.session_id | Should -Be 'sess-X'
        @($r.memberships).Count | Should -Be 1
        $r.memberships[0].channel | Should -Be 'demo'
        $r.memberships[0].alias | Should -Be 'Alice'
    }

    It 'deduplicates on re-add to the same channel' {
        Update-SessionRegistry -Root $script:ClaudeDataRoot -SessionId 'sess-X' -ChannelName 'demo' -Alias 'Alice' -Action Add
        Update-SessionRegistry -Root $script:ClaudeDataRoot -SessionId 'sess-X' -ChannelName 'demo' -Alias 'Alice' -Action Add
        $r = Get-SessionRegistry -Root $script:ClaudeDataRoot
        @($r.memberships).Count | Should -Be 1
    }

    It 'removes a membership' {
        Update-SessionRegistry -Root $script:ClaudeDataRoot -SessionId 'sess-X' -ChannelName 'demo' -Alias 'Alice' -Action Add
        Update-SessionRegistry -Root $script:ClaudeDataRoot -SessionId 'sess-X' -ChannelName 'demo' -Action Remove
        $r = Get-SessionRegistry -Root $script:ClaudeDataRoot
        @($r.memberships).Count | Should -Be 0
    }

    It 'records cron_task_id when provided' {
        Update-SessionRegistry -Root $script:ClaudeDataRoot -SessionId 'sess-X' -ChannelName 'demo' -Alias 'Alice' -CronTaskId 'task-123' -Action Add
        $r = Get-SessionRegistry -Root $script:ClaudeDataRoot
        $r.memberships[0].cron_task_id | Should -Be 'task-123'
    }
}
