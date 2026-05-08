#Requires -Version 7
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

BeforeAll {
    $script:LeaveSkill = Join-Path $PSScriptRoot 'council-leave.ps1'
    $script:OpenSkill  = Join-Path (Split-Path -Parent $PSScriptRoot) 'council-open' 'council-open.ps1'
    $script:JoinSkill  = Join-Path (Split-Path -Parent $PSScriptRoot) 'council-join' 'council-join.ps1'
    $script:PostSkill  = Join-Path (Split-Path -Parent $PSScriptRoot) 'council-post' 'council-post.ps1'
    $script:MadRoot    = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).ProviderPath
    $env:MAD_CRONCREATE_OK = 'true'

    $scriptsDir = Join-Path $script:MadRoot 'scripts'
    . (Join-Path $scriptsDir 'atomic-write.ps1')
    . (Join-Path $scriptsDir 'channel-helpers.ps1')

    function script:New-TestRoot {
        $r = Join-Path ([System.IO.Path]::GetTempPath()) "mad-cl2-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $r -Force | Out-Null
        return $r
    }
}

Describe 'Non-owner leave' {
    BeforeAll {
        $script:Root = script:New-TestRoot
        # Alice opens (becomes owner); Bob joins.
        & $script:OpenSkill -Name 'svc' -Purpose 't' -Tier local -Alias 'Alice' -SessionId 'sess-a' -ClaudeDataRoot $script:Root | Out-Null
        & $script:JoinSkill -Name 'svc' -Alias 'Bob' -SessionId 'sess-b' -ClaudeDataRoot $script:Root | Out-Null
    }
    AfterAll { if (Test-Path $script:Root) { Remove-Item -LiteralPath $script:Root -Recurse -Force } }

    It 'non-owner can leave cleanly' {
        $r = & $script:LeaveSkill -Channel 'svc' -Alias 'Bob' -SessionId 'sess-b' -ClaudeDataRoot $script:Root
        $r.status | Should -Be 'OK'
        $r.final_state | Should -Be 'left'
        $r.archived | Should -BeFalse

        # Bob's member record now disconnected
        $ch = Get-ChannelMetadata -Name 'svc' -Root (Join-Path $script:Root 'channels')
        ($ch.members | Where-Object alias -eq 'Bob').status | Should -Be 'disconnected'
    }
}

Describe 'Owner-leave-without-transfer is rejected (ADOPT-001)' {
    BeforeAll {
        $script:Root = script:New-TestRoot
        & $script:OpenSkill -Name 'svc' -Purpose 't' -Tier local -Alias 'Owner' -SessionId 'sess-own' -ClaudeDataRoot $script:Root | Out-Null
    }
    AfterAll { if (Test-Path $script:Root) { Remove-Item -LiteralPath $script:Root -Recurse -Force } }

    It 'rejects owner leaving an active channel' {
        $r = & $script:LeaveSkill -Channel 'svc' -Alias 'Owner' -SessionId 'sess-own' -ClaudeDataRoot $script:Root
        $r.error_code | Should -Be 'OWNER_LEAVING_WITHOUT_TRANSFER'
        $r.exit_code | Should -Be 6
    }
}

Describe 'Last-member-dormant (no archive consent)' {
    BeforeAll {
        $script:Root = script:New-TestRoot
        & $script:OpenSkill -Name 'svc' -Purpose 't' -Tier local -Alias 'Alice' -SessionId 'sess-a' -ClaudeDataRoot $script:Root | Out-Null
        & $script:JoinSkill -Name 'svc' -Alias 'Bob' -SessionId 'sess-b' -ClaudeDataRoot $script:Root | Out-Null
        # Bob leaves
        & $script:LeaveSkill -Channel 'svc' -Alias 'Bob' -SessionId 'sess-b' -ClaudeDataRoot $script:Root | Out-Null
        # Simulate owner transferring ownership to Bob (already disconnected — so Alice can leave as non-owner)
        # Easier path: flip the owner_alias manually to a non-Alice value so Alice can leave.
        Update-ChannelMember -Name 'svc' -Root (Join-Path $script:Root 'channels') -Alias 'Alice' -Patch @{ status = 'active' } | Out-Null
        $ch = Get-ChannelMetadata -Name 'svc' -Root (Join-Path $script:Root 'channels')
        $ch | Add-Member -NotePropertyName 'owner_alias' -NotePropertyValue 'Bob' -Force
        Write-AtomicJson -Path (Join-Path $script:Root 'channels' 'svc' 'channel.json') -Content $ch
    }
    AfterAll { if (Test-Path $script:Root) { Remove-Item -LiteralPath $script:Root -Recurse -Force } }

    It 'goes dormant (not archived) when -ConfirmArchive is absent' {
        $r = & $script:LeaveSkill -Channel 'svc' -Alias 'Alice' -SessionId 'sess-a' -ClaudeDataRoot $script:Root
        $r.status | Should -Be 'OK'
        $r.final_state | Should -Be 'last-member-dormant'
        $r.archived | Should -BeFalse
        Test-Path (Join-Path $script:Root 'channels' 'svc') | Should -BeTrue
    }
}

Describe 'Last-member archive with -ConfirmArchive' {
    BeforeAll {
        $script:Root = script:New-TestRoot
        & $script:OpenSkill -Name 'svc' -Purpose 't' -Tier local -Alias 'Alice' -SessionId 'sess-a' -ClaudeDataRoot $script:Root | Out-Null
        & $script:JoinSkill -Name 'svc' -Alias 'Bob' -SessionId 'sess-b' -ClaudeDataRoot $script:Root | Out-Null
        & $script:LeaveSkill -Channel 'svc' -Alias 'Bob' -SessionId 'sess-b' -ClaudeDataRoot $script:Root | Out-Null
        # Flip owner to disconnected Bob so Alice can leave as non-owner.
        $ch = Get-ChannelMetadata -Name 'svc' -Root (Join-Path $script:Root 'channels')
        $ch | Add-Member -NotePropertyName 'owner_alias' -NotePropertyValue 'Bob' -Force
        Write-AtomicJson -Path (Join-Path $script:Root 'channels' 'svc' 'channel.json') -Content $ch
    }
    AfterAll { if (Test-Path $script:Root) { Remove-Item -LiteralPath $script:Root -Recurse -Force } }

    It 'moves channel to archive/ on -ConfirmArchive' {
        $r = & $script:LeaveSkill -Channel 'svc' -Alias 'Alice' -SessionId 'sess-a' `
            -ConfirmArchive -ClaudeDataRoot $script:Root
        $r.final_state | Should -Be 'last-member-archived'
        $r.archived | Should -BeTrue

        Test-Path (Join-Path $script:Root 'channels' 'svc') | Should -BeFalse

        $archiveRoot = Join-Path $script:Root 'archive'
        $archivedDirs = @(Get-ChildItem -LiteralPath $archiveRoot -Directory)
        $archivedDirs.Count | Should -Be 1
        $archivedDirs[0].Name | Should -Match 'svc$|svc-\d+$'
        # Report travels with the archive
        $reports = Get-ChildItem -LiteralPath (Join-Path $archivedDirs[0].FullName 'leave-reports')
        $reports.Count | Should -BeGreaterThan 0
    }
}

Describe 'Completion Report counts what Alice did' {
    BeforeAll {
        $script:Root = script:New-TestRoot
        & $script:OpenSkill -Name 'svc' -Purpose 't' -Tier local -Alias 'Alice' -SessionId 'sess-a' -ClaudeDataRoot $script:Root | Out-Null
        & $script:JoinSkill -Name 'svc' -Alias 'Bob' -SessionId 'sess-b' -ClaudeDataRoot $script:Root | Out-Null
        & $script:PostSkill -Channel 'svc' -Alias 'Bob' -SessionId 'sess-b' -Type 'task' `
            -Body 'run the thing' -NewThread 'work' -ClaudeDataRoot $script:Root | Out-Null
        & $script:PostSkill -Channel 'svc' -Alias 'Bob' -SessionId 'sess-b' -Type 'question' `
            -Body 'hmm?' -NewThread 'question-thread' -ClaudeDataRoot $script:Root | Out-Null
    }
    AfterAll { if (Test-Path $script:Root) { Remove-Item -LiteralPath $script:Root -Recurse -Force } }

    It 'Bob leaves with threads=2, tasks=1, questions-asked=1' {
        $r = & $script:LeaveSkill -Channel 'svc' -Alias 'Bob' -SessionId 'sess-b' -ClaudeDataRoot $script:Root
        $r.report.threads.created | Should -Be 2
        $r.report.tasks.picked_up | Should -Be 1
        $r.report.questions.asked | Should -Be 1
    }
}
