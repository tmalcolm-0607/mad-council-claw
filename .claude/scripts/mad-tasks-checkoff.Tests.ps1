#Requires -Version 7
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

BeforeAll {
    . (Join-Path $PSScriptRoot 'mad-tasks-checkoff.ps1')

    function script:New-TempTasksFile {
        param([string] $Content)
        $dir = Join-Path ([System.IO.Path]::GetTempPath()) "mad-tasks-checkoff-$(Get-Random)"
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $path = Join-Path $dir 'tasks.md'
        Set-Content -LiteralPath $path -Value $Content -Encoding UTF8 -NoNewline
        return $path
    }
}

Describe 'mad-tasks-checkoff :: basic checkoff' {
    It 'checks off a single matched task' {
        $p = New-TempTasksFile -Content "# Tasks`n`n- [ ] [T001] First task`n- [ ] [T002] Second task`n- [ ] [T003] Third task"
        $result = Invoke-MadTasksCheckoff -TasksPath $p -TaskIds @('T002')
        $result.checked_count | Should -Be 1
        $content = Get-Content -LiteralPath $p -Raw
        $content | Should -Match '\[x\] \[T002\]'
        $content | Should -Match '\[ \] \[T001\]'
        $content | Should -Match '\[ \] \[T003\]'
    }

    It 'checks off multiple tasks atomically' {
        $p = New-TempTasksFile -Content "- [ ] [T001] A`n- [ ] [T002] B`n- [ ] [T003] C"
        $result = Invoke-MadTasksCheckoff -TasksPath $p -TaskIds @('T001', 'T003')
        $result.checked_count | Should -Be 2
        $content = Get-Content -LiteralPath $p -Raw
        $content | Should -Match '\[x\] \[T001\]'
        $content | Should -Match '\[ \] \[T002\]'
        $content | Should -Match '\[x\] \[T003\]'
    }
}

Describe 'mad-tasks-checkoff :: idempotency' {
    It 'already-checked tasks return in already_checked, not re-modified' {
        $p = New-TempTasksFile -Content "- [x] [T001] Done`n- [ ] [T002] Pending"
        $result = Invoke-MadTasksCheckoff -TasksPath $p -TaskIds @('T001', 'T002')
        $result.checked_count | Should -Be 1
        $result.already_checked | Should -Contain 'T001'
    }

    It 'checking a task twice is a no-op on second call' {
        $p = New-TempTasksFile -Content "- [ ] [T001] Pending"
        $first = Invoke-MadTasksCheckoff -TasksPath $p -TaskIds @('T001')
        $first.checked_count | Should -Be 1
        $second = Invoke-MadTasksCheckoff -TasksPath $p -TaskIds @('T001')
        $second.checked_count | Should -Be 0
        $second.already_checked | Should -Contain 'T001'
    }
}

Describe 'mad-tasks-checkoff :: not-found handling' {
    It 'unknown task IDs return in not_found array' {
        $p = New-TempTasksFile -Content "- [ ] [T001] A"
        $result = Invoke-MadTasksCheckoff -TasksPath $p -TaskIds @('T999')
        $result.checked_count | Should -Be 0
        $result.not_found | Should -Contain 'T999'
    }

    It 'mixed known + unknown IDs: known checked, unknown in not_found' {
        $p = New-TempTasksFile -Content "- [ ] [T001] A`n- [ ] [T002] B"
        $result = Invoke-MadTasksCheckoff -TasksPath $p -TaskIds @('T001', 'T999', 'T002')
        $result.checked_count | Should -Be 2
        $result.not_found | Should -Contain 'T999'
    }
}

Describe 'mad-tasks-checkoff :: id format handling' {
    It 'accepts IDs with surrounding brackets' {
        $p = New-TempTasksFile -Content "- [ ] [T001] A"
        $result = Invoke-MadTasksCheckoff -TasksPath $p -TaskIds @('[T001]')
        $result.checked_count | Should -Be 1
    }

    It 'rejects malformed IDs (not T###)' {
        $p = New-TempTasksFile -Content "- [ ] [T001] A"
        $result = Invoke-MadTasksCheckoff -TasksPath $p -TaskIds @('foo', 'BAR', 'T', 'T123abc')
        $result.requested_count | Should -Be 0
        $result.checked_count | Should -Be 0
    }

    It 'accepts 1-4 digit IDs' {
        $p = New-TempTasksFile -Content "- [ ] [T1] A`n- [ ] [T42] B`n- [ ] [T999] C`n- [ ] [T1234] D"
        $result = Invoke-MadTasksCheckoff -TasksPath $p -TaskIds @('T1','T42','T999','T1234')
        $result.checked_count | Should -Be 4
    }
}

Describe 'mad-tasks-checkoff :: bullet variations' {
    It 'matches asterisk bullet syntax' {
        $p = New-TempTasksFile -Content "* [ ] [T001] A"
        $result = Invoke-MadTasksCheckoff -TasksPath $p -TaskIds @('T001')
        $result.checked_count | Should -Be 1
        $content = Get-Content -LiteralPath $p -Raw
        $content | Should -Match '\* \[x\]'
    }

    It 'matches numbered list syntax' {
        $p = New-TempTasksFile -Content "1. [ ] [T001] A`n2. [ ] [T002] B"
        $result = Invoke-MadTasksCheckoff -TasksPath $p -TaskIds @('T002')
        $result.checked_count | Should -Be 1
        $content = Get-Content -LiteralPath $p -Raw
        $content | Should -Match '2\. \[x\] \[T002\]'
    }

    It 'preserves indentation' {
        $p = New-TempTasksFile -Content "  - [ ] [T001] indented A`n    - [ ] [T002] deeper B"
        $result = Invoke-MadTasksCheckoff -TasksPath $p -TaskIds @('T001','T002')
        $result.checked_count | Should -Be 2
        $content = Get-Content -LiteralPath $p -Raw
        $content | Should -Match '  - \[x\] \[T001\]'
        $content | Should -Match '    - \[x\] \[T002\]'
    }
}

Describe 'mad-tasks-checkoff :: input validation' {
    It 'throws when TasksPath does not exist' {
        { Invoke-MadTasksCheckoff -TasksPath 'C:/nonexistent.md' -TaskIds @('T001') } | Should -Throw
    }

    It 'accepts empty TaskIds array (no-op)' {
        $p = New-TempTasksFile -Content "- [ ] [T001] A"
        $result = Invoke-MadTasksCheckoff -TasksPath $p -TaskIds @()
        $result.checked_count | Should -Be 0
        $content = Get-Content -LiteralPath $p -Raw
        $content | Should -Match '\[ \] \[T001\]'
    }
}

Describe 'mad-tasks-checkoff :: atomic-write + WhatIf' {
    It 'WhatIf: does NOT modify the file' {
        $p = New-TempTasksFile -Content "- [ ] [T001] A"
        $result = Invoke-MadTasksCheckoff -TasksPath $p -TaskIds @('T001') -WhatIf
        $result.checked_count | Should -Be 1
        $content = Get-Content -LiteralPath $p -Raw
        $content | Should -Match '\[ \] \[T001\]'
        $content | Should -Not -Match '\[x\]'
    }

    It 'preserves file content line order and non-task lines' {
        $p = New-TempTasksFile -Content "# Header line`n`nFree prose paragraph.`n`n- [ ] [T001] A`n- Not a task line`n- [ ] [T002] B`n`nMore prose."
        $result = Invoke-MadTasksCheckoff -TasksPath $p -TaskIds @('T001','T002')
        $content = Get-Content -LiteralPath $p -Raw
        $content | Should -Match '# Header line'
        $content | Should -Match 'Free prose paragraph'
        $content | Should -Match 'More prose'
        $content | Should -Match '- Not a task line'
        $content | Should -Match '\[x\] \[T001\]'
        $content | Should -Match '\[x\] \[T002\]'
    }
}
