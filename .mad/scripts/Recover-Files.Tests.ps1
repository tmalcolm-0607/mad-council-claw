# Pester tests for Recover-Files.ps1 functions
# Run: Invoke-Pester -Path .\Recover-Files.Tests.ps1
#
# Requires Pester 5.x (uses BeforeAll for run-phase scoping)
#
# NOTE on array handling:
# Get-FileOperations uses `return ,$operations` (unary comma) to preserve
# the array through the pipeline. Do NOT wrap calls in @() - that creates
# a nested array because @(pipeline-yielding-one-item) wraps the array
# inside another array. The unary comma already handles the PS 5.1
# single-element .Count issue.

BeforeAll {
    $scriptPath = Join-Path $PSScriptRoot "Recover-Files.ps1"
    $scriptContent = Get-Content $scriptPath -Raw

    # Helper to extract functions with nested braces via brace counting
    function Extract-FunctionDef {
        param([string]$Source, [string]$Name)
        $marker = "function $Name {"
        $start = $Source.IndexOf($marker)
        if ($start -lt 0) {
            $marker = "function $Name`r`n{"
            $start = $Source.IndexOf($marker)
        }
        if ($start -lt 0) { return $null }
        $depth = 0; $inFunc = $false
        for ($i = $start; $i -lt $Source.Length; $i++) {
            if ($Source[$i] -eq '{') { $depth++; $inFunc = $true }
            if ($Source[$i] -eq '}') { $depth-- }
            if ($inFunc -and $depth -eq 0) {
                return $Source.Substring($start, $i + 1 - $start)
            }
        }
        return $null
    }

    # Extract testable functions
    foreach ($funcName in @('Find-Sessions', 'Get-SessionFiles', 'Get-FileOperations')) {
        $funcDef = Extract-FunctionDef -Source $scriptContent -Name $funcName
        if ($funcDef) {
            Invoke-Expression $funcDef
        } else {
            Write-Warning "Could not extract $funcName - skipping those tests"
        }
    }

    # Helper: create a minimal JSONL session with Write then Edit on the same file
    function New-TestSession {
        param(
            [string]$Dir,
            [string]$SessionId = "test-session-001"
        )

        $sessionFile = Join-Path $Dir "$SessionId.jsonl"
        $toolUseId1 = "toolu_write_001"
        $toolUseId2 = "toolu_edit_001"
        $filePath = "C:/repo/src/app.js"
        $writeContent = "function hello() {`n  console.log('hello');`n}`n"
        $editOld = "console.log('hello');"
        $editNew = "console.log('world');"

        $lines = @(
            # Write tool_use (assistant message)
            (@{
                type = "assistant"
                timestamp = "2025-01-01T10:00:00Z"
                message = @{
                    role = "assistant"
                    content = @(
                        @{
                            type = "tool_use"
                            id = $toolUseId1
                            name = "Write"
                            input = @{
                                file_path = $filePath
                                content = $writeContent
                            }
                        }
                    )
                }
            } | ConvertTo-Json -Depth 10 -Compress),

            # Write tool result (user message)
            (@{
                type = "user"
                timestamp = "2025-01-01T10:00:01Z"
                message = @{
                    role = "user"
                    content = @(
                        @{
                            type = "tool_result"
                            tool_use_id = $toolUseId1
                        }
                    )
                }
                toolUseResult = @{
                    content = "File written successfully"
                }
            } | ConvertTo-Json -Depth 10 -Compress),

            # Edit tool_use (assistant message)
            (@{
                type = "assistant"
                timestamp = "2025-01-01T10:01:00Z"
                message = @{
                    role = "assistant"
                    content = @(
                        @{
                            type = "tool_use"
                            id = $toolUseId2
                            name = "Edit"
                            input = @{
                                file_path = $filePath
                                old_string = $editOld
                                new_string = $editNew
                            }
                        }
                    )
                }
            } | ConvertTo-Json -Depth 10 -Compress),

            # Edit tool result (user message) - originalFile is pre-edit content
            (@{
                type = "user"
                timestamp = "2025-01-01T10:01:01Z"
                message = @{
                    role = "user"
                    content = @(
                        @{
                            type = "tool_result"
                            tool_use_id = $toolUseId2
                        }
                    )
                }
                toolUseResult = @{
                    originalFile = $writeContent
                }
            } | ConvertTo-Json -Depth 10 -Compress)
        )

        $lines -join "`n" | Set-Content $sessionFile -NoNewline
        return $sessionFile
    }
}

Describe "Get-FileOperations" {

    Context "Edit recovery produces post-edit content" {

        It "applies OldString->NewString replacement to Edit content" {
            $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "recover-test-$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

            try {
                $sessionFile = New-TestSession -Dir $tempDir

                $sessionFiles = @(
                    [PSCustomObject]@{
                        Path        = $sessionFile
                        SourceAgent = "lead"
                        SessionId   = "test-session-001"
                        Project     = "test"
                    }
                )

                # Don't wrap in @() - return ,$operations preserves the array
                $ops = Get-FileOperations -SessionFiles $sessionFiles

                # Should have 2 operations: Write + Edit
                $ops.Count | Should -Be 2

                $writeOp = $ops | Where-Object { $_.Operation -eq "Write" }
                $editOp = $ops | Where-Object { $_.Operation -eq "Edit" }

                $writeOp | Should -Not -BeNullOrEmpty
                $editOp | Should -Not -BeNullOrEmpty

                # Write content should be original
                $writeOp.Content | Should -BeLike "*console.log('hello')*"

                # Edit content should be POST-edit (with replacement applied)
                $editOp.Content | Should -BeLike "*console.log('world')*"
                $editOp.Content | Should -Not -BeLike "*console.log('hello')*"
            } finally {
                Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "Single-result .Count handling" {

        It "returns operations even when only one exists" {
            $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "recover-test-$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

            try {
                # Create a session with only one Write operation
                $sessionFile = Join-Path $tempDir "single-op.jsonl"
                $toolUseId = "toolu_single_001"

                $lines = @(
                    (@{
                        type = "assistant"
                        timestamp = "2025-01-01T10:00:00Z"
                        message = @{
                            role = "assistant"
                            content = @(
                                @{
                                    type = "tool_use"
                                    id = $toolUseId
                                    name = "Write"
                                    input = @{
                                        file_path = "C:/repo/single.txt"
                                        content = "only file"
                                    }
                                }
                            )
                        }
                    } | ConvertTo-Json -Depth 10 -Compress)
                )

                $lines -join "`n" | Set-Content $sessionFile -NoNewline

                $sessionFiles = @(
                    [PSCustomObject]@{
                        Path        = $sessionFile
                        SourceAgent = "lead"
                        SessionId   = "single-op"
                        Project     = "test"
                    }
                )

                # return ,$operations preserves the array - .Count works for single results
                $ops = Get-FileOperations -SessionFiles $sessionFiles

                $ops.Count | Should -Be 1
                $ops[0].FilePath | Should -Be "C:/repo/single.txt"
            } finally {
                Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Context "FileFilter parameter" {

        It "filters operations by file path pattern" {
            $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "recover-test-$(Get-Random)"
            New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

            try {
                $sessionFile = New-TestSession -Dir $tempDir

                $sessionFiles = @(
                    [PSCustomObject]@{
                        Path        = $sessionFile
                        SourceAgent = "lead"
                        SessionId   = "test-session-001"
                        Project     = "test"
                    }
                )

                # Filter for "app.js" should return results
                $ops = Get-FileOperations -SessionFiles $sessionFiles -FileFilter "app.js"
                $ops.Count | Should -BeGreaterThan 0

                # Filter for "nonexistent.py" should return nothing
                $ops = Get-FileOperations -SessionFiles $sessionFiles -FileFilter "nonexistent.py"
                $ops.Count | Should -Be 0
            } finally {
                Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe "Find-Sessions" {

    Context "MostRecent vs default behavior" {

        It "returns only one session when MostRecent is set" {
            $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "recover-test-$(Get-Random)"
            $projDir = Join-Path $tempDir "proj1"
            New-Item -ItemType Directory -Path $projDir -Force | Out-Null

            try {
                # Create two session files with different timestamps
                "line1" | Set-Content (Join-Path $projDir "session-aaa.jsonl")
                Start-Sleep -Milliseconds 100
                "line2" | Set-Content (Join-Path $projDir "session-bbb.jsonl")

                $result = Find-Sessions -BaseDir $tempDir -MostRecent
                # Find-Sessions uses Select-Object -First 1 (not unary comma),
                # so @() is needed here for safe .Count on single PSCustomObject
                @($result).Count | Should -Be 1
            } finally {
                Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }

        It "returns all sessions when MostRecent is not set" {
            $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "recover-test-$(Get-Random)"
            $projDir = Join-Path $tempDir "proj1"
            New-Item -ItemType Directory -Path $projDir -Force | Out-Null

            try {
                "line1" | Set-Content (Join-Path $projDir "session-aaa.jsonl")
                Start-Sleep -Milliseconds 100
                "line2" | Set-Content (Join-Path $projDir "session-bbb.jsonl")

                $result = Find-Sessions -BaseDir $tempDir
                @($result).Count | Should -Be 2
            } finally {
                Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    }
}
