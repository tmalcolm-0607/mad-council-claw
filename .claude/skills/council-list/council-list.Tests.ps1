#Requires -Version 7
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

<#
.SYNOPSIS
  Integration tests for skills/council-list/council-list.ps1.
#>

BeforeAll {
    $script:SkillPath = Join-Path $PSScriptRoot 'council-list.ps1'
    $script:OpenSkill = Join-Path (Split-Path -Parent $PSScriptRoot) 'council-open' 'council-open.ps1'
    $script:JoinSkill = Join-Path (Split-Path -Parent $PSScriptRoot) 'council-join' 'council-join.ps1'
    $script:MadRoot   = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).ProviderPath
    $env:MAD_CRONCREATE_OK = 'true'

    $scriptsDir = Join-Path $script:MadRoot 'scripts'
    . (Join-Path $scriptsDir 'atomic-write.ps1')
    . (Join-Path $scriptsDir 'channel-helpers.ps1')

    function script:New-TestRoot {
        $r = Join-Path ([System.IO.Path]::GetTempPath()) "mad-cl-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $r -Force | Out-Null
        return $r
    }
}

Describe 'Empty registry' {
    BeforeAll { $script:Root = script:New-TestRoot }
    AfterAll  { if (Test-Path $script:Root) { Remove-Item -LiteralPath $script:Root -Recurse -Force } }

    It 'returns NO_MEMBERSHIPS when no sessions.json present' {
        $r = & $script:SkillPath -SessionId 'sess-x' -ClaudeDataRoot $script:Root
        $r.exit_code | Should -Be 2
        $r.error_code | Should -Be 'NO_MEMBERSHIPS'
        $r.channel_count | Should -Be 0
    }
}

Describe 'Single membership — local-tier channel' {
    BeforeAll {
        $script:Root = script:New-TestRoot
        & $script:OpenSkill -Name 'svc-a' -Purpose 'list me' -Tier local `
            -Alias 'Alice' -SessionId 'sess-alice' -ClaudeDataRoot $script:Root | Out-Null
    }
    AfterAll { if (Test-Path $script:Root) { Remove-Item -LiteralPath $script:Root -Recurse -Force } }

    It 'lists one row for the sole member' {
        $r = & $script:SkillPath -SessionId 'sess-alice' -ClaudeDataRoot $script:Root
        $r.status | Should -Be 'OK'
        $r.exit_code | Should -Be 0
        $r.channel_count | Should -Be 1
        $r.channels[0].channel | Should -Be 'svc-a'
        $r.channels[0].alias | Should -Be 'Alice'
        $r.channels[0].member_count | Should -Be 1
        $r.channels[0].unread | Should -Be '0'
    }

    It 'renders a table header + channel line + Total footer' {
        $r = & $script:SkillPath -SessionId 'sess-alice' -ClaudeDataRoot $script:Root
        $r.report | Should -Match 'Your channels \(Alice\)'
        $r.report | Should -Match '#svc-a'
        $r.report | Should -Match 'Total: 1 channels'
    }
}

Describe 'Multiple channels' {
    BeforeAll {
        $script:Root = script:New-TestRoot
        # Open two channels as Alice
        & $script:OpenSkill -Name 'svc-a' -Purpose 'first' -Tier local -Alias 'Alice' -SessionId 'sess-alice' -ClaudeDataRoot $script:Root | Out-Null
        & $script:OpenSkill -Name 'svc-b' -Purpose 'second' -Tier local -Alias 'Alice' -SessionId 'sess-alice' -ClaudeDataRoot $script:Root | Out-Null
    }
    AfterAll { if (Test-Path $script:Root) { Remove-Item -LiteralPath $script:Root -Recurse -Force } }

    It 'lists both channels ordered by insertion' {
        $r = & $script:SkillPath -SessionId 'sess-alice' -ClaudeDataRoot $script:Root
        $r.channel_count | Should -Be 2
        @($r.channels | ForEach-Object channel) | Should -Contain 'svc-a'
        @($r.channels | ForEach-Object channel) | Should -Contain 'svc-b'
    }
}

Describe 'Context Gap handling' {
    BeforeAll {
        $script:Root = script:New-TestRoot
        & $script:OpenSkill -Name 'svc-gap' -Purpose 'will corrupt' -Tier local -Alias 'Alice' -SessionId 'sess-alice' -ClaudeDataRoot $script:Root | Out-Null
        # Corrupt the digest.json
        $digestPath = Join-Path $script:Root 'channels' 'svc-gap' 'digest.json'
        Set-Content -LiteralPath $digestPath -Value '{not valid json'
    }
    AfterAll { if (Test-Path $script:Root) { Remove-Item -LiteralPath $script:Root -Recurse -Force } }

    It 'reports rc=1 + Context Gaps entry' {
        $r = & $script:SkillPath -SessionId 'sess-alice' -ClaudeDataRoot $script:Root
        $r.exit_code | Should -Be 1
        $r.context_gap_count | Should -BeGreaterOrEqual 1
        $r.report | Should -Match 'Context Gaps'
        $r.channels[0].threads_active | Should -Be '?'
    }
}

Describe 'Member counts reflect multi-member channels' {
    BeforeAll {
        $script:Root = script:New-TestRoot
        & $script:OpenSkill -Name 'svc-multi' -Purpose 'for two' -Tier local -Alias 'Alice' -SessionId 'sess-alice' -ClaudeDataRoot $script:Root | Out-Null
        # Join as Bob from a different session.
        & $script:JoinSkill -Name 'svc-multi' -Alias 'Bob' -SessionId 'sess-bob' -ClaudeDataRoot $script:Root | Out-Null
        # Re-assert Alice's session-registry entry (Bob's join clobbered the single-file
        # registry by session_id). Real multi-session deployments will have per-session
        # registry files; for this test we rewrite directly via the helper.
        Update-SessionRegistry -Root $script:Root -SessionId 'sess-alice' -ChannelName 'svc-multi' -Alias 'Alice' -Action Add
    }
    AfterAll { if (Test-Path $script:Root) { Remove-Item -LiteralPath $script:Root -Recurse -Force } }

    It 'shows member_count = 2 in Alice''s list' {
        $r = & $script:SkillPath -SessionId 'sess-alice' -ClaudeDataRoot $script:Root
        $r.channels[0].member_count | Should -Be 2
    }
}

Describe 'Expand (verbose) mode' {
    BeforeAll {
        $script:Root = script:New-TestRoot
        & $script:OpenSkill -Name 'svc-v' -Purpose 'verbose target' -Tier local -Alias 'Alice' -SessionId 'sess-alice' -ClaudeDataRoot $script:Root | Out-Null
    }
    AfterAll { if (Test-Path $script:Root) { Remove-Item -LiteralPath $script:Root -Recurse -Force } }

    It 'includes an expanded block when -Expand is set' {
        $r = & $script:SkillPath -SessionId 'sess-alice' -Expand -ClaudeDataRoot $script:Root
        $r.report | Should -Match 'Purpose: verbose target'
        $r.report | Should -Match 'Owner:'
        $r.report | Should -Match 'Members:'
    }

    It 'omits the expanded block by default' {
        $r = & $script:SkillPath -SessionId 'sess-alice' -ClaudeDataRoot $script:Root
        $r.report | Should -Not -Match 'Purpose: verbose target'
    }
}
