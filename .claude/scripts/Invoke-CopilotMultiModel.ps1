<#
.SYNOPSIS
    Shared Copilot CLI multi-model dispatcher. Runs Claude Opus + GPT-5.5 in parallel
    on the same prompt and returns paths to both result files for cross-model synthesis.

.DESCRIPTION
    Implements the lens-multi-model-review pattern (Shayon Gupta, LENS-Common PR
    #5138039) as a reusable kit primitive. Skills that document `--copilot` mode call
    this script to dispatch the actual cross-model run.

    Hardening (iter3-B-1, per d7-council-verdict-iter3b-2026-05-02.md):
      * M1 — uses the call operator (`& $cliCmd ... -p $promptContent`) instead of
        Invoke-Expression so prompt content with PowerShell metacharacters
        (backticks, $(), ;) is never re-parsed by the shell.
      * M2 — TaskFallback mode returns OpusResultPath / GptResultPath as $null so
        downstream skills cannot blindly Read non-existent files.
      * M3 — Wait-Job is bounded by -TimeoutSeconds (default 120). A timeout fires
        Stop-Job and emits a Context Gap line per degradation-fallback-policy.md
        Rule 3 + returns a TaskFallback-equivalent shape.
      * M3 — concurrency cap (default 3) tracked via .mad/scratch/multimodel-concurrent.lock.
        A 4th simultaneous invocation from this machine is refused with a clear error.

.PARAMETER PromptFile
    Path to the markdown file containing the review prompt. Required.

.PARAMETER OutputDir
    Directory where the two result files (opus-result.json, gpt-result.json)
    will be written. Defaults to a fresh `mktemp -d` style dir under `.mad/scratch/`.

.PARAMETER Model1
    First model to dispatch. Default: `claude-opus-4.7` (or whatever the local CLI
    defaults to when the flag is absent).

.PARAMETER Model2
    Second model to dispatch. Default: `gpt-5.5`.

.PARAMETER FallbackToTask
    If Copilot CLI is unavailable, fall back to two parallel Task subagent calls on
    the same model with role-distinguishing prompts. Default: $true.

.PARAMETER TimeoutSeconds
    Maximum wall-clock seconds to wait for both Copilot jobs to finish.
    On timeout, both jobs are stopped and the script returns a TaskFallback-shaped
    result with $null paths and Mode = 'Timeout'. Default: 600.
    Was 120 before 2026-05 calibration; raised after PR 5160086 review where
    240s was insufficient for two parallel Copilot calls on a ~3KB brief.

.PARAMETER MaxConcurrent
    Maximum number of concurrent dispatcher invocations on this machine. The 4th
    simultaneous call is refused with exit code 5. Default: 3.

.PARAMETER LockDir
    Directory used for the concurrency-cap sentinel files. Default:
    `.mad/scratch/multimodel-concurrent.lock`. Tests override this.

.OUTPUTS
    JSON object with: OpusResultPath, GptResultPath, ModelsRun (array), Mode.
    Mode is one of: CopilotCLI | TaskFallback | Timeout | ConcurrencyLimited.
    In every non-CopilotCLI mode, OpusResultPath and GptResultPath are $null
    so callers can detect "no real result" without trying to Read the paths.

.EXAMPLE
    $r = & .\Invoke-CopilotMultiModel.ps1 -PromptFile review-prompt.md | ConvertFrom-Json
    if ($r.Mode -ne 'CopilotCLI') {
        # degrade gracefully — paths are $null
    } else {
        $opusFindings = Get-Content $r.OpusResultPath -Raw
        $gptFindings  = Get-Content $r.GptResultPath  -Raw
    }
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$PromptFile,

    [string]$OutputDir,

    [string]$Model1 = 'claude-opus-4.7',

    [string]$Model2 = 'gpt-5.5',

    [bool]$FallbackToTask = $true,

    [int]$TimeoutSeconds = 600,

    [int]$MaxConcurrent = 3,

    [string]$LockDir = (Join-Path '.mad/scratch' 'multimodel-concurrent.lock')
)

# Hybrid error handling per powershell-conventions.md: 'Stop' for cmdlets,
# explicit $LASTEXITCODE checks for native commands. We stay on 'Continue'
# for the native-command sections.
$ErrorActionPreference = 'Stop'

# ---- Result shape helper -----------------------------------------------
# Single source of truth for the returned JSON shape. Per M2: every non-
# CopilotCLI mode returns $null paths.
function New-DispatcherResult {
    # NOTE: untyped parameters on purpose. Typing $OpusPath/$GptPath as [string]
    # causes PowerShell to coerce $null to '', which violates M2 (callers must
    # see literal null when no real path was produced).
    param(
        [Parameter(Mandatory)][string]$Mode,
        $OpusPath            = $null,
        $GptPath             = $null,
        [string[]]$ModelsRun = @(),
        $FallbackHint        = $null,
        $ContextGap          = $null,
        [int]$TimeoutSecondsUsed = 0
    )
    $obj = [ordered]@{
        OpusResultPath = $OpusPath
        GptResultPath  = $GptPath
        ModelsRun      = $ModelsRun
        Mode           = $Mode
    }
    if ($FallbackHint)        { $obj['FallbackHint']        = $FallbackHint }
    if ($ContextGap)          { $obj['ContextGap']          = $ContextGap }
    if ($TimeoutSecondsUsed)  { $obj['TimeoutSecondsUsed']  = $TimeoutSecondsUsed }
    return $obj
}

if (-not (Test-Path $PromptFile)) {
    Write-Error "PromptFile not found: $PromptFile"
    exit 2
}

# Resolve output directory
if (-not $OutputDir) {
    $OutputDir = Join-Path -Path '.mad/scratch' -ChildPath ("multimodel-" + (Get-Date -Format 'yyyyMMdd-HHmmss') + "-" + (Get-Random -Maximum 99999))
}
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$opusOut = Join-Path $OutputDir 'opus-result.json'
$gptOut  = Join-Path $OutputDir 'gpt-result.json'

# ---- M3: Concurrency cap ------------------------------------------------
# Each active invocation drops a sentinel file in $LockDir. A 4th call sees
# 3 sentinels and refuses. Sentinels are removed on exit (best-effort; stale
# sentinels >10 minutes old are swept here as well).
New-Item -ItemType Directory -Path $LockDir -Force | Out-Null

# Sweep stale sentinels (>10 min). Best-effort.
$staleCutoff = (Get-Date).AddMinutes(-10)
Get-ChildItem -Path $LockDir -Filter 'lock-*.json' -ErrorAction SilentlyContinue |
    Where-Object { $_.LastWriteTime -lt $staleCutoff } |
    ForEach-Object { Remove-Item $_.FullName -Force -ErrorAction SilentlyContinue }

$activeLocks = @(Get-ChildItem -Path $LockDir -Filter 'lock-*.json' -ErrorAction SilentlyContinue)
if ($activeLocks.Count -ge $MaxConcurrent) {
    $msg = "Concurrency cap reached ($($activeLocks.Count) active >= $MaxConcurrent). Refusing dispatch."
    Write-Host $msg -ForegroundColor Yellow
    Write-Host "Context Gap: multi-model dispatcher concurrency cap hit; degrading to single-model path." -ForegroundColor Yellow
    New-DispatcherResult `
        -Mode 'ConcurrencyLimited' `
        -ContextGap "Concurrency cap $MaxConcurrent reached; $($activeLocks.Count) dispatcher calls already in flight." `
        -FallbackHint 'Caller should retry after current dispatches complete, or fall back to single-model review.' `
        | ConvertTo-Json -Depth 5
    exit 5
}

# Acquire a lock sentinel for the lifetime of this invocation.
$lockId   = [Guid]::NewGuid().ToString('N')
$lockFile = Join-Path $LockDir ("lock-" + $lockId + ".json")
@{
    pid           = $PID
    started_utc   = (Get-Date).ToUniversalTime().ToString('o')
    prompt_file   = $PromptFile
    output_dir    = $OutputDir
} | ConvertTo-Json -Depth 3 | Set-Content -Path $lockFile -Encoding UTF8

try {
    # Detect Copilot CLI flavor
    function Find-CopilotCli {
        $candidates = @('copilot', 'agency')
        foreach ($cmd in $candidates) {
            $found = Get-Command $cmd -ErrorAction SilentlyContinue
            if ($found) {
                if ($cmd -eq 'agency') { return @{ Cmd = 'agency'; Subcommand = 'copilot' } }
                return @{ Cmd = 'copilot'; Subcommand = '' }
            }
        }
        return $null
    }

    $cli = Find-CopilotCli

    if ($null -eq $cli) {
        if (-not $FallbackToTask) {
            Write-Error 'Copilot CLI not found and FallbackToTask is disabled.'
            exit 3
        }
        # M2: TaskFallback returns $null paths so downstream skills cannot Read ghost files.
        Write-Host 'Copilot CLI not found - returning Task-fallback signal.' -ForegroundColor Yellow
        New-DispatcherResult `
            -Mode 'TaskFallback' `
            -FallbackHint 'Caller should spawn two parallel Task subagent calls with role-distinguishing prompts on the same model.' `
            -ContextGap 'Copilot CLI not found on PATH; cross-model verification unavailable.' `
            | ConvertTo-Json -Depth 5
        exit 0
    }

    $cliCmd = $cli.Cmd
    $cliSub = $cli.Subcommand

    $promptContent = Get-Content -Path $PromptFile -Raw

    # ---- M1: Call operator instead of Invoke-Expression -----------------
    # Pass each argv element as a discrete arg so PowerShell metacharacters
    # in $promptContent are never re-parsed by the shell.
    $jobScript = {
        param($cmd, $sub, $model, $prompt, $out, $isModel2)
        try {
            if ($sub) {
                if ($isModel2) {
                    $raw = & $cmd $sub --yolo --model $model -p $prompt 2>&1 | Out-String
                } else {
                    $raw = & $cmd $sub --yolo                    -p $prompt 2>&1 | Out-String
                }
            } else {
                if ($isModel2) {
                    $raw = & $cmd     --yolo --model $model -p $prompt 2>&1 | Out-String
                } else {
                    $raw = & $cmd     --yolo                    -p $prompt 2>&1 | Out-String
                }
            }
            $payload = @{ model = $model; raw_output = $raw; exit_code = $LASTEXITCODE } | ConvertTo-Json -Depth 5
        } catch {
            $payload = @{ model = $model; raw_output = ''; error = ($_ | Out-String); exit_code = -1 } | ConvertTo-Json -Depth 5
        }
        # UTF-8 BOM-less per powershell-conventions.md
        [System.IO.File]::WriteAllText($out, $payload, (New-Object System.Text.UTF8Encoding $false))
    }

    Write-Host "Dispatching $Model1 via $cliCmd $cliSub..." -ForegroundColor Cyan
    $opusJob = Start-Job -ScriptBlock $jobScript `
        -ArgumentList $cliCmd, $cliSub, $Model1, $promptContent, $opusOut, $false

    Write-Host "Dispatching $Model2 via $cliCmd $cliSub --model $Model2..." -ForegroundColor Cyan
    $gptJob  = Start-Job -ScriptBlock $jobScript `
        -ArgumentList $cliCmd, $cliSub, $Model2, $promptContent, $gptOut, $true

    # ---- M3: Bounded wait + on-timeout cleanup --------------------------
    $finished = Wait-Job -Job @($opusJob, $gptJob) -Timeout $TimeoutSeconds
    $timedOut = ($finished.Count -lt 2)

    if ($timedOut) {
        Write-Host "Wait-Job timeout after ${TimeoutSeconds}s. Stopping jobs." -ForegroundColor Yellow
        Stop-Job  -Job @($opusJob, $gptJob) -ErrorAction SilentlyContinue
        Receive-Job -Job @($opusJob, $gptJob) -ErrorAction SilentlyContinue | Out-Null
        Remove-Job  -Job @($opusJob, $gptJob) -ErrorAction SilentlyContinue
        $gap = "Multi-model dispatcher timed out after ${TimeoutSeconds}s; both Copilot CLI calls stopped."
        Write-Host "Context Gap: $gap" -ForegroundColor Yellow
        New-DispatcherResult `
            -Mode 'Timeout' `
            -ContextGap $gap `
            -FallbackHint 'Caller should fall back to TaskFallback shape (two parallel Task subagent calls).' `
            -TimeoutSecondsUsed $TimeoutSeconds `
            | ConvertTo-Json -Depth 5
        exit 6
    }

    Receive-Job -Job @($opusJob, $gptJob) -ErrorAction SilentlyContinue | Out-Null
    Remove-Job  -Job @($opusJob, $gptJob)

    if (-not (Test-Path $opusOut) -or -not (Test-Path $gptOut)) {
        Write-Error "One or both model results missing. Inspect $OutputDir for partial output."
        exit 4
    }

    New-DispatcherResult `
        -Mode 'CopilotCLI' `
        -OpusPath $opusOut `
        -GptPath  $gptOut  `
        -ModelsRun @($Model1, $Model2) `
        | ConvertTo-Json -Depth 5
}
finally {
    # Best-effort lock cleanup. Stale sweep at the next invocation handles process-kill cases.
    if (Test-Path $lockFile) {
        Remove-Item $lockFile -Force -ErrorAction SilentlyContinue
    }
}
