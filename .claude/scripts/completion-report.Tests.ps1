#Requires -Version 7
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

BeforeAll {
    # MAD root is one level up from scripts/ — works on host AND inside Docker.
    $script:MadRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath
    . $PSScriptRoot/atomic-write.ps1
    . $PSScriptRoot/channel-helpers.ps1
    . $PSScriptRoot/completion-report.ps1

    $script:OpenSkill = Join-Path $script:MadRoot 'skills' 'council-open' 'council-open.ps1'
    $script:PostSkill = Join-Path $script:MadRoot 'skills' 'council-post' 'council-post.ps1'
    $env:MAD_CRONCREATE_OK = 'true'

    function script:New-TestRoot {
        $r = Join-Path ([System.IO.Path]::GetTempPath()) "mad-cr-$([guid]::NewGuid().ToString('N').Substring(0,8))"
        New-Item -ItemType Directory -Path $r -Force | Out-Null
        return $r
    }
}

Describe 'New-CompletionReport on empty channel' {
    BeforeAll {
        $script:Root = script:New-TestRoot
        & $script:OpenSkill -Name 'empty' -Purpose 'test' -Tier local -Alias 'Alice' -SessionId 'sess-alice' -ClaudeDataRoot $script:Root | Out-Null
    }
    AfterAll { if (Test-Path $script:Root) { Remove-Item -LiteralPath $script:Root -Recurse -Force } }

    It 'produces zero-state counters' {
        $r = New-CompletionReport -ChannelName 'empty' -Alias 'Alice' -SessionId 'sess-alice' -Root (Join-Path $script:Root 'channels')
        $r.alias | Should -Be 'Alice'
        $r.channel | Should -Be 'empty'
        $r.threads.created | Should -Be 0
        $r.tasks.picked_up | Should -Be 0
        $r.questions.asked | Should -Be 0
        @($r.run_ids).Count | Should -Be 0
    }
}

Describe 'Thread-creation + task counting' {
    BeforeAll {
        $script:Root = script:New-TestRoot
        $script:ChannelsRoot = Join-Path $script:Root 'channels'
        & $script:OpenSkill -Name 'work' -Purpose 'test' -Tier local -Alias 'Alice' -SessionId 'sess-alice' -ClaudeDataRoot $script:Root | Out-Null
        # Alice posts a task in new thread (she's the creator).
        & $script:PostSkill -Channel 'work' -Alias 'Alice' -SessionId 'sess-alice' -Type 'task' -Body 'do X' -NewThread 'work-1' -ClaudeDataRoot $script:Root | Out-Null
        # Alice posts a question in another new thread.
        & $script:PostSkill -Channel 'work' -Alias 'Alice' -SessionId 'sess-alice' -Type 'question' -Body 'huh?' -NewThread 'work-2' -ClaudeDataRoot $script:Root | Out-Null
        # Alice posts an answer.
        & $script:PostSkill -Channel 'work' -Alias 'Alice' -SessionId 'sess-alice' -Type 'answer' -Body 'yes' -Thread 'work-2' -ClaudeDataRoot $script:Root | Out-Null
    }
    AfterAll { if (Test-Path $script:Root) { Remove-Item -LiteralPath $script:Root -Recurse -Force } }

    It 'counts threads_created=2, tasks_picked_up=1, questions_asked=1, questions_answered=1' {
        $r = New-CompletionReport -ChannelName 'work' -Alias 'Alice' -SessionId 'sess-alice' -Root $script:ChannelsRoot
        $r.threads.created | Should -Be 2
        $r.tasks.picked_up | Should -Be 1
        $r.questions.asked | Should -Be 1
        $r.questions.answered | Should -Be 1
    }

    It 'captures distinct run_ids' {
        $r = New-CompletionReport -ChannelName 'work' -Alias 'Alice' -SessionId 'sess-alice' -Root $script:ChannelsRoot
        @($r.run_ids).Count | Should -BeGreaterThan 0
    }
}

Describe 'tasks_completed heuristic (resolve in same thread)' {
    BeforeAll {
        $script:Root = script:New-TestRoot
        & $script:OpenSkill -Name 'tc' -Purpose 'test' -Tier local -Alias 'Alice' -SessionId 'sess-alice' -ClaudeDataRoot $script:Root | Out-Null
        # Alice's task + resolve in same thread
        & $script:PostSkill -Channel 'tc' -Alias 'Alice' -SessionId 'sess-alice' -Type 'task' -Body 't' -NewThread 'done' -ClaudeDataRoot $script:Root | Out-Null
        & $script:PostSkill -Channel 'tc' -Alias 'Alice' -SessionId 'sess-alice' -Type 'resolve' -Body 'fin' -Thread 'done' -ClaudeDataRoot $script:Root | Out-Null
    }
    AfterAll { if (Test-Path $script:Root) { Remove-Item -LiteralPath $script:Root -Recurse -Force } }

    It 'counts tasks_completed=1 when thread has a resolve message' {
        $r = New-CompletionReport -ChannelName 'tc' -Alias 'Alice' -SessionId 'sess-alice' -Root (Join-Path $script:Root 'channels')
        $r.tasks.completed | Should -Be 1
    }
}

Describe 'Format-CompletionReport' {
    It 'renders a plain-text summary with all categories' {
        $report = [pscustomobject]@{
            alias       = 'Alice'; session_id = 'sess-a'; channel = 'demo'
            joined_utc  = '2026-04-18T00:00:00Z'
            left_utc    = '2026-04-18T01:00:00Z'
            threads     = [pscustomobject]@{ created = 1; resolved = 0; participated = 0; verdict_pending = 0 }
            tasks       = [pscustomobject]@{ picked_up = 1; completed = 0; dropped = 0 }
            questions   = [pscustomobject]@{ asked = 0; answered = 1 }
            final_state = 'left'
            run_ids     = @('r1','r2')
            context_gaps = @()
        }
        $txt = Format-CompletionReport -Report $report
        $txt | Should -Match 'Completion Report'
        $txt | Should -Match 'threads: created 1'
        $txt | Should -Match 'Tasks:   picked-up 1'
        $txt | Should -Match '2 distinct'
    }
}
