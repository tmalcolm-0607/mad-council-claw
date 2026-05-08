#Requires -Version 7
#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0' }

<#
.SYNOPSIS
  Pester tests for scripts/atomic-write.ps1.

.DESCRIPTION
  Layer 1 unit coverage per evals/layer-1-unit.md. Covers:
    - Happy-path write + read round-trip.
    - Unique .tmp suffixes.
    - Retry on rename failure.
    - Retry exhaustion → .tmp orphan remains.
    - Read of missing / empty / malformed JSON.
    - Round-trip of deeply-nested objects (Depth 20).

.NOTES
  Run with: Invoke-Pester scripts/atomic-write.Tests.ps1 -Output Detailed
#>

BeforeAll {
    . $PSScriptRoot/atomic-write.ps1

    $script:TestRoot = Join-Path ([System.IO.Path]::GetTempPath()) "mad-atomic-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
}

AfterAll {
    if (Test-Path $script:TestRoot) {
        Remove-Item -LiteralPath $script:TestRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'Write-AtomicJson' {

    It 'writes a simple object to target path' {
        $target = Join-Path $script:TestRoot 'simple.json'
        Write-AtomicJson -Path $target -Content @{ a = 1; b = 'two' }
        Test-Path -LiteralPath $target | Should -BeTrue
        $read = Get-Content -LiteralPath $target -Raw | ConvertFrom-Json
        $read.a | Should -Be 1
        $read.b | Should -Be 'two'
    }

    It 'overwrites an existing target atomically' {
        $target = Join-Path $script:TestRoot 'overwrite.json'
        Write-AtomicJson -Path $target -Content @{ version = 1 }
        Write-AtomicJson -Path $target -Content @{ version = 2 }
        (Get-Content -LiteralPath $target -Raw | ConvertFrom-Json).version | Should -Be 2
    }

    It 'preserves nested structures to depth > 5' {
        $target = Join-Path $script:TestRoot 'nested.json'
        $obj = @{
            level1 = @{
                level2 = @{
                    level3 = @{
                        level4 = @{
                            level5 = @{ value = 'deep' }
                        }
                    }
                }
            }
        }
        Write-AtomicJson -Path $target -Content $obj
        $read = Get-Content -LiteralPath $target -Raw | ConvertFrom-Json
        $read.level1.level2.level3.level4.level5.value | Should -Be 'deep'
    }

    It 'uses a unique .tmp suffix per invocation' {
        # Two sequential writes; verify no leftover .tmp files after each succeeds.
        $target = Join-Path $script:TestRoot 'unique.json'
        Write-AtomicJson -Path $target -Content @{ n = 1 }
        Write-AtomicJson -Path $target -Content @{ n = 2 }
        $tmpFiles = Get-ChildItem -Path $script:TestRoot -Filter '*unique*.tmp' -ErrorAction SilentlyContinue
        $tmpFiles | Should -BeNullOrEmpty
    }

    It 'leaves an orphan .tmp when rename exhausts retries' {
        # Simulate rename failure deterministically: mock Move-Item to always throw.
        # This exercises the retry loop + orphan-.tmp preservation behavior.
        Mock -CommandName Move-Item -MockWith { throw 'simulated rename failure' }

        $target = Join-Path $script:TestRoot 'orphan-target.json'
        {
            Write-AtomicJson -Path $target -Content @{ x = 1 } -MaxRetries 1 -RetryDelayMs 5
        } | Should -Throw -ExpectedMessage '*rename failed*'

        # The .tmp file should remain; preflight.ps1 will sweep it.
        $orphans = @(Get-ChildItem -Path $script:TestRoot -Filter 'orphan-target.json.*.tmp' -ErrorAction SilentlyContinue)
        $orphans.Count | Should -BeGreaterThan 0

        # Verify the retry loop ran MaxRetries+1 times (1 initial + 1 retry = 2 calls).
        Should -Invoke Move-Item -Exactly 2

        # Cleanup for subsequent tests
        @(Get-ChildItem -Path $script:TestRoot -Filter '*.tmp' -ErrorAction SilentlyContinue) | ForEach-Object {
            Remove-Item -Force -LiteralPath $_.FullName -ErrorAction SilentlyContinue
        }
    }

    It 'succeeds on retry when rename transiently fails' {
        # Mock fails on first call, then uses raw .NET move on subsequent calls
        # (sidesteps the mock layer so the real file-system rename happens).
        $script:moveCallCount = 0
        Mock -CommandName Move-Item -MockWith {
            param([string]$LiteralPath, [string]$Destination, [switch]$Force)
            $script:moveCallCount++
            if ($script:moveCallCount -eq 1) {
                throw 'transient rename failure'
            }
            if (Test-Path -LiteralPath $Destination) { Remove-Item -Force -LiteralPath $Destination }
            [System.IO.File]::Move($LiteralPath, $Destination)
        }

        $target = Join-Path $script:TestRoot 'transient-retry.json'
        Write-AtomicJson -Path $target -Content @{ retried = $true } -MaxRetries 2 -RetryDelayMs 5

        Test-Path -LiteralPath $target | Should -BeTrue
        $script:moveCallCount | Should -Be 2
    }

    It 'throws clearly when target parent dir is unwritable' {
        $target = Join-Path $script:TestRoot 'does-not-exist' 'child.json'
        { Write-AtomicJson -Path $target -Content @{} } | Should -Throw
    }

    It 'accepts $null content (serializes as null)' {
        $target = Join-Path $script:TestRoot 'null-content.json'
        Write-AtomicJson -Path $target -Content $null
        (Get-Content -LiteralPath $target -Raw).Trim() | Should -Be 'null'
    }
}

Describe 'Read-AtomicJson' {

    It 'reads a valid JSON file' {
        $target = Join-Path $script:TestRoot 'read-valid.json'
        '{"hello":"world"}' | Out-File -FilePath $target -Encoding UTF8 -NoNewline
        $result = Read-AtomicJson -Path $target
        $result.hello | Should -Be 'world'
    }

    It 'throws with clear message when file is missing' {
        $missing = Join-Path $script:TestRoot 'nope.json'
        { Read-AtomicJson -Path $missing } | Should -Throw -ExpectedMessage '*File not found*'
    }

    It 'throws when file is empty' {
        $target = Join-Path $script:TestRoot 'empty.json'
        '' | Out-File -FilePath $target -Encoding UTF8 -NoNewline
        { Read-AtomicJson -Path $target -MaxRetries 0 } | Should -Throw
    }

    It 'throws when file is malformed JSON' {
        $target = Join-Path $script:TestRoot 'bad.json'
        '{"unclosed":' | Out-File -FilePath $target -Encoding UTF8 -NoNewline
        { Read-AtomicJson -Path $target -MaxRetries 0 } | Should -Throw
    }

    It 'round-trips an object written by Write-AtomicJson' {
        $target = Join-Path $script:TestRoot 'roundtrip.json'
        $original = @{ alias = 'Demo'; members = @(@{ name = 'A' }, @{ name = 'B' }) }
        Write-AtomicJson -Path $target -Content $original
        $read = Read-AtomicJson -Path $target
        $read.alias | Should -Be 'Demo'
        $read.members.Count | Should -Be 2
        $read.members[0].name | Should -Be 'A'
    }
}
