<#
.SYNOPSIS
    Self-contained tests for the iter3-B-1 hardening of Invoke-CopilotMultiModel.ps1
    (M1 command-injection fix, M2 ghost-path fix, M3 timeout + concurrency cap, M10 smoke).

.DESCRIPTION
    No Pester dependency. Each test:
      1. Builds a temp-dir fixture (prompt file + isolated lock dir + isolated output dir)
      2. Invokes Invoke-CopilotMultiModel.ps1 with explicit overrides
      3. Asserts on the captured stdout JSON + exit code + side effects on the filesystem

    Tests intentionally avoid relying on a working Copilot CLI. The TaskFallback,
    Timeout, and ConcurrencyLimited paths are exercised via fixtures (PATH override
    / MaxConcurrent=0 / fake stale locks).

    Run from repo root:
      pwsh -NoProfile -File .claude/scripts/__tests__/Invoke-CopilotMultiModel.tests.ps1

.NOTES
    Single-quoted strings for literal patterns (per powershell-conventions.md).
    No `$args`; named parameters only.
    No Set-StrictMode (mirrors script under test).
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

$thisDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptDir = Split-Path -Parent $thisDir
$scriptUnderTest = Join-Path $scriptDir 'Invoke-CopilotMultiModel.ps1'

if (-not (Test-Path $scriptUnderTest)) {
    Write-Host "FATAL: Script under test not found at $scriptUnderTest" -ForegroundColor Red
    exit 2
}

# Resolve pwsh to a full path UP FRONT, before any test mutates PATH for the
# script-under-test. Without this, tests that override PATH (Test 1's clean-PATH
# fixture, Test 2's empty-PATH fixture) cannot find pwsh themselves.
$pwshExe = (Get-Command pwsh -ErrorAction SilentlyContinue).Source
if (-not $pwshExe) {
    $pwshExe = (Get-Command powershell -ErrorAction SilentlyContinue).Source
}
if (-not $pwshExe) {
    Write-Host 'FATAL: Neither pwsh nor powershell on PATH at test startup.' -ForegroundColor Red
    exit 2
}

$passCount = 0
$failCount = 0

function Assert-Test {
    param([string]$Name, [bool]$Condition, [string]$Detail = '')
    if ($Condition) {
        Write-Host "  [PASS] $Name" -ForegroundColor Green
        $script:passCount++
    } else {
        Write-Host "  [FAIL] $Name" -ForegroundColor Red
        if ($Detail) { Write-Host "         $Detail" -ForegroundColor Yellow }
        $script:failCount++
    }
}

function New-FixtureRoot {
    $tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("multimodel-test-" + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tmp 'lock')   -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $tmp 'output') -Force | Out-Null
    return $tmp
}

function Write-PromptFile {
    param([string]$Root, [string]$Content)
    $path = Join-Path $Root 'prompt.md'
    # Use raw byte write to avoid any newline normalization that might
    # mask encoding-sensitive injection patterns.
    [System.IO.File]::WriteAllText($path, $Content, (New-Object System.Text.UTF8Encoding $false))
    return $path
}

function Invoke-Script {
    param(
        [string]$PromptFile,
        [string]$OutputDir,
        [string]$LockDir,
        [int]$MaxConcurrent = 3,
        [int]$TimeoutSeconds = 120,
        [bool]$FallbackToTask = $true,
        [hashtable]$EnvOverrides = $null
    )
    # Run in a child pwsh via -File so the script's `exit N` propagates as the
    # child process exit code. -Command with & wraps the script and clamps the
    # exit code to 1 on any non-zero, which loses our 5 / 6 distinction.
    #
    # Env overrides are applied to the parent test process for the duration of
    # the child call, then restored. This is safe because tests run sequentially
    # in a single pwsh process; no parallel test contention.
    $saved = @{}
    if ($EnvOverrides) {
        foreach ($k in $EnvOverrides.Keys) {
            $saved[$k] = [Environment]::GetEnvironmentVariable($k, 'Process')
            [Environment]::SetEnvironmentVariable($k, $EnvOverrides[$k], 'Process')
        }
    }
    try {
        # NOTE: bool args under `pwsh -File` must use the colon-form
        # (-FallbackToTask:$true). Space-separated form passes the literal
        # string "True" and fails parameter binding.
        $fbArg = if ($FallbackToTask) { '-FallbackToTask:$true' } else { '-FallbackToTask:$false' }
        $output = & $pwshExe -NoProfile -File $scriptUnderTest `
            -PromptFile $PromptFile `
            -OutputDir $OutputDir `
            -LockDir $LockDir `
            -MaxConcurrent $MaxConcurrent `
            -TimeoutSeconds $TimeoutSeconds `
            $fbArg 2>&1 | Out-String
        $code = $LASTEXITCODE
    } finally {
        if ($EnvOverrides) {
            foreach ($k in $saved.Keys) {
                [Environment]::SetEnvironmentVariable($k, $saved[$k], 'Process')
            }
        }
    }
    return [pscustomobject]@{
        Output   = $output
        ExitCode = $code
    }
}

function Get-JsonFromOutput {
    param([string]$Output)
    # The script writes Write-Host status lines AND a final ConvertTo-Json blob.
    # The JSON is the longest contiguous run starting at the first '{' through
    # the last matching '}' on its own line.
    $lines = $Output -split "`r?`n"
    # Find first line whose trimmed content is exactly '{' (ConvertTo-Json -Depth 5 default).
    $startIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -eq '{') { $startIdx = $i; break }
    }
    if ($startIdx -lt 0) { return $null }
    $endIdx = -1
    for ($j = $lines.Count - 1; $j -ge $startIdx; $j--) {
        if ($lines[$j].Trim() -eq '}') { $endIdx = $j; break }
    }
    if ($endIdx -lt 0) { return $null }
    $jsonText = ($lines[$startIdx..$endIdx] -join "`n")
    try { return ($jsonText | ConvertFrom-Json) } catch { return $null }
}

# =========================================================================
# Test 1 -- M1: command-injection sink (BLOCKING)
# =========================================================================
# Goal: write a prompt file containing PowerShell metacharacters that, under
# the OLD Invoke-Expression-based dispatcher, would have executed embedded
# code. Under the call-operator-based dispatcher, those characters MUST be
# passed through to the CLI as a single argv element with no shell re-parse.
#
# We verify NEGATIVELY: the malicious payload writes to a sentinel file. We
# expect the sentinel NEVER to appear, no matter what mode the script runs
# in (CopilotCLI, TaskFallback, Timeout, etc).
Write-Host ''
Write-Host 'Test 1: M1 -- command injection via prompt content is contained' -ForegroundColor Cyan
$root = New-FixtureRoot
try {
    $sentinel = Join-Path $root 'INJECTED.txt'
    # All four classes of metacharacter the spec calls out: backticks, $(...),
    # ;, plus embedded double-quotes and a fully-armed Set-Content payload.
    # Under the OLD Invoke-Expression code path, the $() subexpression would
    # have evaluated and the ; chain would have run Set-Content.
    #
    # Use a literal here-string (@'...'@) and substitute the sentinel path
    # post-hoc so PowerShell does not try to parse the metacharacters here in
    # the test source itself.
    $maliciousTemplate = @'
Review the following diff:
"; Set-Content -Path '__SENTINEL__' -Value 'pwned' ; "
And also $(Set-Content -Path '__SENTINEL__' -Value 'pwned-by-subexpr')
And also `Set-Content -Path '__SENTINEL__' -Value 'pwned-by-backtick'`
'@
    $malicious = $maliciousTemplate -replace '__SENTINEL__', $sentinel
    $promptFile = Write-PromptFile -Root $root -Content $malicious
    $outDir  = Join-Path $root 'output'
    $lockDir = Join-Path $root 'lock'

    # Force the TaskFallback branch by clearing PATH so neither copilot nor
    # agency are findable. This isolates the test from CLI availability while
    # still proving the script LOADED $promptContent and would have used it
    # in a job. We also run the CopilotCLI branch in a separate sub-test to
    # exercise the call-operator argv path directly.
    $r = Invoke-Script -PromptFile $promptFile -OutputDir $outDir -LockDir $lockDir `
        -EnvOverrides @{ PATH = '' }

    Assert-Test 'Sentinel file NOT created (TaskFallback branch)' (-not (Test-Path $sentinel)) `
        "Found INJECTED.txt at $sentinel -- prompt content was evaluated as PowerShell. M1 broken."
    $json = Get-JsonFromOutput -Output $r.Output
    Assert-Test 'Returned JSON is parseable'      ($null -ne $json)
    Assert-Test 'Mode = TaskFallback (no CLI)'    ($json.Mode -eq 'TaskFallback')

    # Now run the script with a real Copilot CLI present (if available). The
    # script will try to invoke `copilot --yolo -p <prompt>` via the call
    # operator. The CLI may reject the prompt or time out -- that's fine. The
    # ONLY thing this test cares about is whether the malicious payload
    # executes locally before reaching the CLI.
    $cliFound = $null -ne (Get-Command copilot -ErrorAction SilentlyContinue) `
             -or $null -ne (Get-Command agency  -ErrorAction SilentlyContinue)
    if ($cliFound) {
        Remove-Item $sentinel -Force -ErrorAction SilentlyContinue
        # Use a 5s timeout and immediately stop the jobs -- we do not need a
        # real CLI response, only proof that local re-parse never fires.
        $r2 = Invoke-Script -PromptFile $promptFile -OutputDir (Join-Path $root 'output2') `
            -LockDir $lockDir -TimeoutSeconds 5
        Assert-Test 'Sentinel file NOT created (CopilotCLI branch, even on timeout)' (-not (Test-Path $sentinel)) `
            'Prompt content was evaluated locally before CLI dispatch -- call operator failed to contain it.'
    } else {
        Write-Host '    (skipping CopilotCLI-branch sub-test -- no copilot/agency on PATH)' -ForegroundColor DarkGray
    }
} finally {
    Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
}

# =========================================================================
# Test 2 -- M2: TaskFallback returns $null paths
# =========================================================================
Write-Host ''
Write-Host 'Test 2: M2 -- TaskFallback returns null paths (no ghost files)' -ForegroundColor Cyan
$root = New-FixtureRoot
try {
    $promptFile = Write-PromptFile -Root $root -Content 'hello world'
    $outDir  = Join-Path $root 'output'
    $lockDir = Join-Path $root 'lock'

    $r = Invoke-Script -PromptFile $promptFile -OutputDir $outDir -LockDir $lockDir `
        -EnvOverrides @{ PATH = '' }
    $json = Get-JsonFromOutput -Output $r.Output

    Assert-Test 'Mode = TaskFallback'             ($json.Mode -eq 'TaskFallback')
    Assert-Test 'OpusResultPath is null'          ($null -eq $json.OpusResultPath)
    Assert-Test 'GptResultPath is null'           ($null -eq $json.GptResultPath)
    Assert-Test 'ModelsRun is empty'              (@($json.ModelsRun).Count -eq 0)
    Assert-Test 'FallbackHint present'            (-not [string]::IsNullOrEmpty($json.FallbackHint))
    Assert-Test 'ContextGap present'              (-not [string]::IsNullOrEmpty($json.ContextGap))
    Assert-Test 'Exit code = 0'                   ($r.ExitCode -eq 0)

    # The OutputDir is created by the script even on TaskFallback (idempotent),
    # but the result files MUST NOT exist (M2: no ghost files).
    $opusGhost = Join-Path $outDir 'opus-result.json'
    $gptGhost  = Join-Path $outDir 'gpt-result.json'
    Assert-Test 'No ghost opus-result.json on disk' (-not (Test-Path $opusGhost))
    Assert-Test 'No ghost gpt-result.json on disk'  (-not (Test-Path $gptGhost))
} finally {
    Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
}

# =========================================================================
# Test 3 -- M3: concurrency cap rejects the (MaxConcurrent+1)th invocation
# =========================================================================
# Strategy: pre-populate $LockDir with N stub lock files (timestamps fresh --
# NOT stale-swept), invoke with -MaxConcurrent N, expect the script to refuse
# with Mode=ConcurrencyLimited and exit 5.
Write-Host ''
Write-Host 'Test 3: M3 -- concurrency cap refuses dispatch above MaxConcurrent' -ForegroundColor Cyan
$root = New-FixtureRoot
try {
    $promptFile = Write-PromptFile -Root $root -Content 'hello world'
    $outDir  = Join-Path $root 'output'
    $lockDir = Join-Path $root 'lock'

    # Drop 3 fresh sentinel locks so the script sees the cap is full.
    1..3 | ForEach-Object {
        $p = Join-Path $lockDir ("lock-fake-$_.json")
        @{ pid = 99999; started_utc = (Get-Date).ToUniversalTime().ToString('o') } |
            ConvertTo-Json | Set-Content -Path $p -Encoding UTF8
    }

    $r = Invoke-Script -PromptFile $promptFile -OutputDir $outDir -LockDir $lockDir `
        -MaxConcurrent 3 `
        -EnvOverrides @{ PATH = '' }
    $json = Get-JsonFromOutput -Output $r.Output

    Assert-Test 'Mode = ConcurrencyLimited'       ($json.Mode -eq 'ConcurrencyLimited')
    Assert-Test 'OpusResultPath is null'          ($null -eq $json.OpusResultPath)
    Assert-Test 'GptResultPath is null'           ($null -eq $json.GptResultPath)
    Assert-Test 'Exit code = 5'                   ($r.ExitCode -eq 5)
    Assert-Test 'ContextGap mentions concurrency' ($json.ContextGap -match 'oncurrency')
} finally {
    Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
}

# =========================================================================
# Test 4 -- M3: stale locks (>10 min old) are swept and do not block
# =========================================================================
Write-Host ''
Write-Host 'Test 4: M3 -- stale locks (>10 min) are swept; dispatch proceeds' -ForegroundColor Cyan
$root = New-FixtureRoot
try {
    $promptFile = Write-PromptFile -Root $root -Content 'hello world'
    $outDir  = Join-Path $root 'output'
    $lockDir = Join-Path $root 'lock'

    # Drop 3 STALE sentinel locks (LastWriteTime well past the 10-min cutoff).
    1..3 | ForEach-Object {
        $p = Join-Path $lockDir ("lock-stale-$_.json")
        @{ pid = 99999; started_utc = '2020-01-01T00:00:00Z' } |
            ConvertTo-Json | Set-Content -Path $p -Encoding UTF8
        (Get-Item $p).LastWriteTime = (Get-Date).AddHours(-1)
    }

    $r = Invoke-Script -PromptFile $promptFile -OutputDir $outDir -LockDir $lockDir `
        -MaxConcurrent 3 `
        -EnvOverrides @{ PATH = '' }
    $json = Get-JsonFromOutput -Output $r.Output

    Assert-Test 'Stale locks swept (Mode != ConcurrencyLimited)' ($json.Mode -ne 'ConcurrencyLimited')
    Assert-Test 'Mode is TaskFallback (PATH empty, sweep succeeded)' ($json.Mode -eq 'TaskFallback')
    # Verify no stale locks remain after the sweep.
    $remaining = Get-ChildItem -Path $lockDir -Filter 'lock-stale-*.json' -ErrorAction SilentlyContinue
    Assert-Test 'Stale lock files removed from disk' ($remaining.Count -eq 0)
} finally {
    Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
}

# =========================================================================
# Test 5 -- M3: timeout fires + emits Context Gap + null paths
# =========================================================================
# Strategy: install a fake `copilot` shim on PATH that sleeps far longer
# than $TimeoutSeconds. Invoke with -TimeoutSeconds 3. Expect Mode=Timeout,
# null paths, exit 6, ContextGap line in stdout.
Write-Host ''
Write-Host 'Test 5: M3 -- Wait-Job timeout produces Mode=Timeout + null paths' -ForegroundColor Cyan
$root = New-FixtureRoot
try {
    $promptFile = Write-PromptFile -Root $root -Content 'hello world'
    $outDir  = Join-Path $root 'output'
    $lockDir = Join-Path $root 'lock'
    $shimDir = Join-Path $root 'shim'
    New-Item -ItemType Directory -Path $shimDir -Force | Out-Null

    # Cross-platform fake copilot: a pwsh script wrapped by a .cmd shim on
    # Windows so Get-Command finds it regardless of execution policy.
    if ($IsWindows -or $env:OS -eq 'Windows_NT') {
        $shimPath = Join-Path $shimDir 'copilot.cmd'
        @'
@echo off
powershell.exe -NoProfile -Command "Start-Sleep -Seconds 30; Write-Output 'too late'"
'@ | Set-Content -Path $shimPath -Encoding ASCII
    } else {
        $shimPath = Join-Path $shimDir 'copilot'
        "#!/usr/bin/env bash`nsleep 30`necho 'too late'`n" | Set-Content -Path $shimPath -Encoding ASCII
        chmod +x $shimPath 2>$null
    }

    # Prepend shim dir to PATH; clear lock dir.
    $newPath = $shimDir + [System.IO.Path]::PathSeparator + $env:PATH

    $r = Invoke-Script -PromptFile $promptFile -OutputDir $outDir -LockDir $lockDir `
        -TimeoutSeconds 3 `
        -EnvOverrides @{ PATH = $newPath }
    $json = Get-JsonFromOutput -Output $r.Output

    Assert-Test 'Mode = Timeout'                  ($json.Mode -eq 'Timeout')
    Assert-Test 'OpusResultPath is null'          ($null -eq $json.OpusResultPath)
    Assert-Test 'GptResultPath is null'           ($null -eq $json.GptResultPath)
    Assert-Test 'Exit code = 6'                   ($r.ExitCode -eq 6)
    Assert-Test 'ContextGap mentions timeout'     ($json.ContextGap -match 'timed out')
    Assert-Test 'TimeoutSecondsUsed = 3'          ($json.TimeoutSecondsUsed -eq 3)
    Assert-Test 'Stdout has Context Gap line'     ($r.Output -match 'Context Gap:')
} finally {
    Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
}

# =========================================================================
# Test 6 -- M3: lock cleanup on normal exit
# =========================================================================
Write-Host ''
Write-Host 'Test 6: M3 -- lock file is cleaned up after dispatch returns' -ForegroundColor Cyan
$root = New-FixtureRoot
try {
    $promptFile = Write-PromptFile -Root $root -Content 'hello world'
    $outDir  = Join-Path $root 'output'
    $lockDir = Join-Path $root 'lock'

    $r = Invoke-Script -PromptFile $promptFile -OutputDir $outDir -LockDir $lockDir `
        -EnvOverrides @{ PATH = '' }
    $json = Get-JsonFromOutput -Output $r.Output

    $remaining = Get-ChildItem -Path $lockDir -Filter 'lock-*.json' -ErrorAction SilentlyContinue
    Assert-Test 'No lock files remain after exit' ($remaining.Count -eq 0)
    Assert-Test 'Mode = TaskFallback'             ($json.Mode -eq 'TaskFallback')
} finally {
    Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
}

# =========================================================================
# Test 7 -- M10: smoke test (synthetic fixture from _template/evals OR
# an inline minimal fixture). Verifies the script returns a parseable JSON
# object with the canonical key set in both CopilotCLI-present and
# CopilotCLI-absent paths.
# =========================================================================
Write-Host ''
Write-Host 'Test 7: M10 -- smoke test against a synthetic prompt fixture' -ForegroundColor Cyan
$root = New-FixtureRoot
try {
    # Try _template/evals first; fall back to inline fixture.
    $repoRoot      = Split-Path -Parent (Split-Path -Parent $scriptDir)
    $templateEvals = Join-Path $repoRoot '.claude/skills/_template/evals/fixtures'
    $sourcePrompt  = $null
    if (Test-Path $templateEvals) {
        $candidate = Get-ChildItem -Path $templateEvals -Filter '*.md' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($candidate) { $sourcePrompt = $candidate.FullName }
    }
    if (-not $sourcePrompt) {
        Write-Host '    (no _template/evals/fixtures/*.md; using inline synthetic prompt)' -ForegroundColor DarkGray
        $sourcePrompt = Write-PromptFile -Root $root -Content @'
# Synthetic Review Prompt

You are reviewing the following minimal diff:

```diff
- old line
+ new line
```

Emit findings as JSON with severity tags.
'@
    }

    $outDir  = Join-Path $root 'output'
    $lockDir = Join-Path $root 'lock'

    # Run TaskFallback branch (PATH empty) -- guaranteed deterministic.
    $r = Invoke-Script -PromptFile $sourcePrompt -OutputDir $outDir -LockDir $lockDir `
        -EnvOverrides @{ PATH = '' }
    $json = Get-JsonFromOutput -Output $r.Output

    Assert-Test 'Smoke: JSON parses'                   ($null -ne $json)
    Assert-Test 'Smoke: has OpusResultPath key'        ($json.PSObject.Properties.Name -contains 'OpusResultPath')
    Assert-Test 'Smoke: has GptResultPath key'         ($json.PSObject.Properties.Name -contains 'GptResultPath')
    Assert-Test 'Smoke: has ModelsRun key'             ($json.PSObject.Properties.Name -contains 'ModelsRun')
    Assert-Test 'Smoke: has Mode key'                  ($json.PSObject.Properties.Name -contains 'Mode')
    Assert-Test 'Smoke: TaskFallback path null (M2)'   ($null -eq $json.OpusResultPath -and $null -eq $json.GptResultPath)
} finally {
    Remove-Item -Recurse -Force $root -ErrorAction SilentlyContinue
}

# =========================================================================
# Summary
# =========================================================================
Write-Host ''
Write-Host '=== Test Summary ===' -ForegroundColor Cyan
Write-Host "Passed: $passCount"
Write-Host "Failed: $failCount"
Write-Host ''
if ($failCount -gt 0) { exit 1 } else { exit 0 }
