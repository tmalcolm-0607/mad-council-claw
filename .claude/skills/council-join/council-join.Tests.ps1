#Requires -Version 7
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

<#
.SYNOPSIS
  Integration tests for skills/council-join/council-join.ps1.

.DESCRIPTION
  Layer-2 integration covering the four canonical reclaim cases:
    A — fresh join (no prior member)
    B — silent reclaim of disconnected/idle
    C — active-alias conflict (rejected without -ForceReclaim; allowed with)
    D — idempotent re-invoke by same session
  Plus validation errors + channel-not-found + read-marker preservation.
#>

BeforeAll {
    $script:SkillPath  = Join-Path $PSScriptRoot 'council-join.ps1'
    $script:OpenSkill  = Join-Path (Split-Path -Parent $PSScriptRoot) 'council-open' 'council-open.ps1'
    # MAD root — two levels up from skills/<skill>/ — cross-platform (host + container).
    $script:MadRoot    = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).ProviderPath
    $script:ChannelSchemaJson = Get-Content -LiteralPath (Join-Path $script:MadRoot 'schemas' 'channel.schema.json') -Raw -Encoding UTF8
    $env:MAD_CRONCREATE_OK = 'true'

    # Dot-source helpers used by test setup (Update-ChannelMember, Read/Write-AtomicJson).
    $scriptsDir = Join-Path $script:MadRoot 'scripts'
    . (Join-Path $scriptsDir 'atomic-write.ps1')
    . (Join-Path $scriptsDir 'channel-helpers.ps1')

    function script:New-TestRoot {
        $r = Join-Path ([System.IO.Path]::GetTempPath()) "mad-cj-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $r -Force | Out-Null
        return $r
    }

    function script:Open-Channel {
        param([string] $Root, [string] $Name = 'svc', [string] $Owner = 'Owner', [string] $OwnerSession = 'sess-owner')
        & $script:OpenSkill -Name $Name -Purpose 'join-test channel' -Tier local `
            -Alias $Owner -SessionId $OwnerSession -ClaudeDataRoot $Root | Out-Null
    }
}

Describe 'Case A — fresh join' {
    BeforeAll {
        $script:Root = script:New-TestRoot
        script:Open-Channel -Root $script:Root
    }
    AfterAll { if (Test-Path $script:Root) { Remove-Item -LiteralPath $script:Root -Recurse -Force } }

    It 'adds a new member + read-marker' {
        $r = & $script:SkillPath -Name 'svc' -Alias 'Bob' -SessionId 'sess-bob' -ClaudeDataRoot $script:Root
        $r.status | Should -Be 'OK'
        $r.reclaim_case | Should -Be 'A'

        $ch = Get-Content (Join-Path $script:Root 'channels' 'svc' 'channel.json') -Raw | ConvertFrom-Json
        @($ch.members).Count | Should -Be 2
        ($ch.members | Where-Object alias -eq 'Bob').session_id | Should -Be 'sess-bob'

        Test-Path (Join-Path $script:Root 'channels' 'svc' 'read-markers' 'Bob.json') | Should -BeTrue
    }

    It 'channel.json still conforms to schema after join' {
        $json = Get-Content (Join-Path $script:Root 'channels' 'svc' 'channel.json') -Raw
        Test-Json -Json $json -Schema $script:ChannelSchemaJson | Should -BeTrue
    }
}

Describe 'Case B — silent reclaim of disconnected alias' {
    BeforeAll {
        $script:Root = script:New-TestRoot
        script:Open-Channel -Root $script:Root
        # Add Bob and mark as disconnected
        & $script:SkillPath -Name 'svc' -Alias 'Bob' -SessionId 'sess-bob-old' -ClaudeDataRoot $script:Root | Out-Null
        Update-ChannelMember -Name 'svc' -Root (Join-Path $script:Root 'channels') -Alias 'Bob' -Patch @{ status = 'disconnected' }

        # Give Bob a non-zero last_read_seq to prove preservation.
        $markerPath = Join-Path $script:Root 'channels' 'svc' 'read-markers' 'Bob.json'
        $m = Read-AtomicJson -Path $markerPath
        $m | Add-Member -NotePropertyName 'last_read_seq' -NotePropertyValue 5 -Force
        Write-AtomicJson -Path $markerPath -Content $m
    }
    AfterAll { if (Test-Path $script:Root) { Remove-Item -LiteralPath $script:Root -Recurse -Force } }

    It 'silently reclaims and reports case B' {
        $r = & $script:SkillPath -Name 'svc' -Alias 'Bob' -SessionId 'sess-bob-NEW' -ClaudeDataRoot $script:Root
        $r.status | Should -Be 'OK'
        $r.reclaim_case | Should -Be 'B'

        $ch = Get-Content (Join-Path $script:Root 'channels' 'svc' 'channel.json') -Raw | ConvertFrom-Json
        ($ch.members | Where-Object alias -eq 'Bob').session_id | Should -Be 'sess-bob-NEW'
        ($ch.members | Where-Object alias -eq 'Bob').status | Should -Be 'active'
    }

    It 'preserves read-marker last_read_seq across reclaim' {
        $marker = Get-Content (Join-Path $script:Root 'channels' 'svc' 'read-markers' 'Bob.json') -Raw | ConvertFrom-Json
        $marker.last_read_seq | Should -Be 5
        $marker.session_id | Should -Be 'sess-bob-NEW'
    }
}

Describe 'Case C — active-alias conflict' {
    BeforeAll {
        $script:Root = script:New-TestRoot
        script:Open-Channel -Root $script:Root
        & $script:SkillPath -Name 'svc' -Alias 'Bob' -SessionId 'sess-bob-active' -ClaudeDataRoot $script:Root | Out-Null
    }
    AfterAll { if (Test-Path $script:Root) { Remove-Item -LiteralPath $script:Root -Recurse -Force } }

    It 'rejects without -ForceReclaim' {
        $r = & $script:SkillPath -Name 'svc' -Alias 'Bob' -SessionId 'sess-bob-intruder' -ClaudeDataRoot $script:Root
        $r.status | Should -Be 'Failed'
        $r.error_code | Should -Be 'ALIAS_ACTIVE_CONFLICT'
        $r.exit_code | Should -Be 2

        # Member session_id NOT overwritten
        $ch = Get-Content (Join-Path $script:Root 'channels' 'svc' 'channel.json') -Raw | ConvertFrom-Json
        ($ch.members | Where-Object alias -eq 'Bob').session_id | Should -Be 'sess-bob-active'
    }

    It 'allows reclaim with -ForceReclaim' {
        $r = & $script:SkillPath -Name 'svc' -Alias 'Bob' -SessionId 'sess-bob-owner-return' `
            -ForceReclaim -ClaudeDataRoot $script:Root
        $r.status | Should -Be 'OK'
        $r.reclaim_case | Should -Be 'C-force'

        $ch = Get-Content (Join-Path $script:Root 'channels' 'svc' 'channel.json') -Raw | ConvertFrom-Json
        ($ch.members | Where-Object alias -eq 'Bob').session_id | Should -Be 'sess-bob-owner-return'
    }
}

Describe 'Case D — idempotent re-invoke' {
    BeforeAll {
        $script:Root = script:New-TestRoot
        script:Open-Channel -Root $script:Root
        & $script:SkillPath -Name 'svc' -Alias 'Bob' -SessionId 'sess-bob' -ClaudeDataRoot $script:Root | Out-Null
    }
    AfterAll { if (Test-Path $script:Root) { Remove-Item -LiteralPath $script:Root -Recurse -Force } }

    It 'no-ops on same-session re-invoke' {
        $r = & $script:SkillPath -Name 'svc' -Alias 'Bob' -SessionId 'sess-bob' -ClaudeDataRoot $script:Root
        $r.status | Should -Be 'OK'
        $r.reclaim_case | Should -Be 'D'
        $r.message | Should -Match 'same session'
    }
}

Describe 'Validation + not-found' {
    BeforeAll {
        $script:Root = script:New-TestRoot
        script:Open-Channel -Root $script:Root
    }
    AfterAll { if (Test-Path $script:Root) { Remove-Item -LiteralPath $script:Root -Recurse -Force } }

    It 'rejects channel-not-found with rc=3' {
        $r = & $script:SkillPath -Name 'nope' -Alias 'Bob' -SessionId 'sess-bob' -ClaudeDataRoot $script:Root
        $r.error_code | Should -Be 'CHANNEL_NOT_FOUND'
        $r.exit_code | Should -Be 3
    }

    It 'rejects alias with leading whitespace' {
        $r = & $script:SkillPath -Name 'svc' -Alias ' Bob' -SessionId 'sess-bob' -ClaudeDataRoot $script:Root
        $r.error_code | Should -Be 'INVALID_ALIAS'
    }

    It 'rejects alias over 64 chars' {
        $long = 'x' * 65
        $r = & $script:SkillPath -Name 'svc' -Alias $long -SessionId 'sess' -ClaudeDataRoot $script:Root
        $r.error_code | Should -Be 'INVALID_ALIAS'
    }
}

Describe 'Session registry update' {
    BeforeAll {
        $script:Root = script:New-TestRoot
        script:Open-Channel -Root $script:Root
    }
    AfterAll { if (Test-Path $script:Root) { Remove-Item -LiteralPath $script:Root -Recurse -Force } }

    It 'adds the channel to .sessions.json memberships on fresh join' {
        & $script:SkillPath -Name 'svc' -Alias 'Carol' -SessionId 'sess-carol' -ClaudeDataRoot $script:Root | Out-Null
        $sess = Get-Content (Join-Path $script:Root '.sessions.json') -Raw | ConvertFrom-Json
        # Sessions registry was last written by the open step (sess-owner). New join resets session_id.
        $sess.session_id | Should -Be 'sess-carol'
        @($sess.memberships | Where-Object channel -eq 'svc').Count | Should -Be 1
    }
}
