#Requires -Version 7
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot 'Parse-SlashArgs.ps1'
}

Describe 'Parse-SlashArgs' {

    It 'returns empty collections on empty input' {
        $r = & $script:ScriptPath -ArgumentsString ''
        @($r.positional).Count | Should -Be 0
        @($r.flags).Count | Should -Be 0
        $r.named.Count | Should -Be 0
    }

    It 'splits bare tokens into positional[]' {
        $r = & $script:ScriptPath -ArgumentsString 'svc-a purpose-here'
        @($r.positional).Count | Should -Be 2
        $r.positional[0] | Should -Be 'svc-a'
        $r.positional[1] | Should -Be 'purpose-here'
    }

    It 'treats quoted strings as single atoms' {
        $r = & $script:ScriptPath -ArgumentsString 'svc-a "my purpose with spaces"'
        @($r.positional).Count | Should -Be 2
        $r.positional[1] | Should -Be 'my purpose with spaces'
    }

    It 'maps --flag value into named{}' {
        $r = & $script:ScriptPath -ArgumentsString '--tier local --alias me'
        $r.named['tier'] | Should -Be 'local'
        $r.named['alias'] | Should -Be 'me'
    }

    It 'collects bare switches into flags[]' {
        $r = & $script:ScriptPath -ArgumentsString 'svc --triage --force-raw'
        $r.flags | Should -Contain 'triage'
        $r.flags | Should -Contain 'force-raw'
        @($r.positional).Count | Should -Be 1
    }

    It 'mixes positional + named + flags correctly' {
        $r = & $script:ScriptPath `
            -ArgumentsString 'my-channel "purpose here" --tier prod --alias tester --triage'
        @($r.positional).Count | Should -Be 2
        $r.positional[0] | Should -Be 'my-channel'
        $r.positional[1] | Should -Be 'purpose here'
        $r.named['tier'] | Should -Be 'prod'
        $r.named['alias'] | Should -Be 'tester'
        $r.flags | Should -Contain 'triage'
    }

    It 'handles escaped quotes inside a quoted atom' {
        $r = & $script:ScriptPath -ArgumentsString '"she said \"hi\""'
        $r.positional[0] | Should -Be 'she said "hi"'
    }

    It 'accepts -flag shorthand the same as --flag' {
        $r = & $script:ScriptPath -ArgumentsString '-tier ci'
        $r.named['tier'] | Should -Be 'ci'
    }
}
