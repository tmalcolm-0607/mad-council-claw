#Requires -Version 7
<#
.SYNOPSIS
  Single-command health check for the MAD unified repo. Proves current state
  is what STATUS.md claims — no "trust me" required.

.DESCRIPTION
  Runs in sequence:
    1. Git state check (branch, HEAD, clean working tree)
    2. Key file presence check (STATUS.md, ADRs, helpers, skill designs)
    3. Full Pester test suite (all *.Tests.ps1 under repo root)
    4. Phase 1 E2E smoke (invokes Verify-Phase1Smoke.ps1)
    5. Summary: PASS if everything green, else list failures

  Exit code 0 = all green. 1 = any failure. Useful in CI + for human operators
  resuming work after a break.

.PARAMETER SkipTests
  Skip the Pester run (fast path for humans who just want state/file checks).
  Default: run everything.

.PARAMETER SkipSmoke
  Skip the Phase 1 E2E roundtrip. Default: run it.

.OUTPUTS
  PSCustomObject with individual check results + overall pass/fail.
  Also prints a human-readable summary to stdout.

.EXAMPLE
  .\scripts\Verify-Health.ps1
  # Runs full health check: git + files + tests + smoke.

.EXAMPLE
  .\scripts\Verify-Health.ps1 -SkipTests
  # Just git + file checks. ~2 seconds.

.NOTES
  Invoked by future sessions as the first step in resuming work.
  See STATUS.md "How to resume" section.
#>

[CmdletBinding()]
param(
    [switch] $SkipTests,
    [switch] $SkipSmoke
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..' '..')).ProviderPath
$results = [ordered]@{
    git              = $null
    files            = $null
    tests            = $null
    smoke            = $null
    overall          = $null
    ran_at_utc       = (Get-Date).ToUniversalTime().ToString('o')
    repo_root        = $repoRoot
}

function script:Write-Section {
    param([string] $Title)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host $Title -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
}

# ---------------- 1. Git state ----------------
Write-Section "[1/4] Git state"
Push-Location $repoRoot
try {
    $branch    = (git rev-parse --abbrev-ref HEAD 2>$null).Trim()
    $head      = (git rev-parse HEAD 2>$null).Trim()
    $headShort = (git rev-parse --short HEAD 2>$null).Trim()
    $dirty     = (git status --short 2>$null)
    $isClean   = [string]::IsNullOrWhiteSpace($dirty)
    $commitCount = [int]((git rev-list --count HEAD 2>$null).Trim())

    Write-Host "  branch:       $branch"
    Write-Host "  HEAD:         $headShort ($head)"
    Write-Host "  commits:      $commitCount"
    Write-Host ("  working tree: {0}" -f ($(if ($isClean) { 'clean' } else { 'DIRTY' })))
    if (-not $isClean) {
        Write-Host "    uncommitted changes:" -ForegroundColor Yellow
        $dirty -split "`n" | Select-Object -First 10 | ForEach-Object { Write-Host "      $_" -ForegroundColor Yellow }
    }

    $results.git = [pscustomobject]@{
        branch       = $branch
        head         = $head
        head_short   = $headShort
        commit_count = $commitCount
        clean        = $isClean
        pass         = ($null -ne $branch -and $null -ne $head)
    }
} finally {
    Pop-Location
}

# ---------------- 2. Key files ----------------
Write-Section "[2/4] Key file presence"
$keyFiles = @(
    # Consumer-install layout: kit content lives under .claude/ + .mad/
    '.mad/STATUS.md'
    'CLAUDE.md'                                              # project-level Claude Code instructions
    '.mad/BACKLOG.md'
    '.mad/.claude-plugin/plugin.json'
    '.mad/mad.council.a2a.md'
    '.mad/decisions/001-fat-plugin-path-resolution.md'
    '.mad/decisions/002-exhaustive-enumeration-over-ruthless-filtering.md'
    '.mad/decisions/003-context-before-action-three-failure-modes.md'
    '.claude/scripts/verdict-compute.ps1'
    '.claude/scripts/verdict-compute.Tests.ps1'
    '.claude/scripts/yagni-filter.ps1'
    '.claude/scripts/yagni-filter.Tests.ps1'
    '.claude/scripts/pattern-verify.ps1'
    '.claude/scripts/pattern-verify.Tests.ps1'
    '.claude/scripts/mad-tasks-checkoff.ps1'
    '.claude/scripts/mad-tasks-checkoff.Tests.ps1'
    '.claude/scripts/council-review-integration.Tests.ps1'
    '.claude/skills/council-open/council-open.ps1'
    '.claude/skills/council-post/council-post.ps1'
    '.claude/skills/council-check/council-check.ps1'
    '.claude/skills/council-join/council-join.ps1'
    '.claude/skills/council-leave/council-leave.ps1'
    '.claude/skills/council-list/council-list.ps1'
    '.claude/skills/council-review/SKILL.md'
    '.claude/skills/council-verdict/SKILL.md'
    '.claude/skills/council-resolve/SKILL.md'
    '.claude/skills/council-retro/SKILL.md'
    '.claude/schemas/verdict.schema.json'
    '.claude/schemas/channel.schema.json'
    '.claude/schemas/message.schema.json'
)
$missing = @()
$present = 0
foreach ($f in $keyFiles) {
    $path = Join-Path $repoRoot $f
    if (Test-Path -LiteralPath $path -PathType Leaf) {
        $present++
    } else {
        $missing += $f
    }
}
Write-Host ("  {0}/{1} key files present" -f $present, $keyFiles.Count)
if ($missing.Count -gt 0) {
    Write-Host "  MISSING:" -ForegroundColor Red
    $missing | ForEach-Object { Write-Host "    $_" -ForegroundColor Red }
}
$results.files = [pscustomobject]@{
    expected = $keyFiles.Count
    present  = $present
    missing  = $missing
    pass     = ($missing.Count -eq 0)
}

# ---------------- 3. Pester test suite ----------------
if ($SkipTests) {
    Write-Section "[3/4] Pester test suite — SKIPPED"
    $results.tests = [pscustomobject]@{ skipped = $true; pass = $null }
} else {
    Write-Section "[3/4] Pester test suite"
    $testFiles = Get-ChildItem -Path $repoRoot -Filter '*.Tests.ps1' -Recurse -File |
        Where-Object { $_.FullName -notmatch '\\\.git\\' } |
        ForEach-Object { $_.FullName }
    Write-Host "  found $($testFiles.Count) test files; running..."
    Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
    $config = New-PesterConfiguration
    $config.Run.Path = $testFiles
    $config.Output.Verbosity = 'None'
    $config.Run.PassThru = $true
    $pesterResult = Invoke-Pester -Configuration $config
    $pesterPass = ($pesterResult.FailedCount -eq 0)

    $color = if ($pesterPass) { 'Green' } else { 'Red' }
    Write-Host ("  Total:    {0}" -f $pesterResult.TotalCount)   -ForegroundColor $color
    Write-Host ("  Passed:   {0}" -f $pesterResult.PassedCount)  -ForegroundColor $color
    Write-Host ("  Failed:   {0}" -f $pesterResult.FailedCount)  -ForegroundColor $color
    Write-Host ("  Skipped:  {0}" -f $pesterResult.SkippedCount) -ForegroundColor $color
    Write-Host ("  Duration: {0}" -f $pesterResult.Duration)

    $results.tests = [pscustomobject]@{
        files    = $testFiles.Count
        total    = $pesterResult.TotalCount
        passed   = $pesterResult.PassedCount
        failed   = $pesterResult.FailedCount
        skipped  = $pesterResult.SkippedCount
        duration = $pesterResult.Duration.ToString()
        pass     = $pesterPass
    }
}

# ---------------- 4. Phase 1 E2E smoke ----------------
if ($SkipSmoke) {
    Write-Section "[4/4] Phase 1 E2E smoke — SKIPPED"
    $results.smoke = [pscustomobject]@{ skipped = $true; pass = $null }
} else {
    Write-Section "[4/4] Phase 1 E2E smoke (open → post → check → list)"
    $smokeScript = Join-Path $PSScriptRoot 'Verify-Phase1Smoke.ps1'
    if (-not (Test-Path -LiteralPath $smokeScript -PathType Leaf)) {
        Write-Host "  Verify-Phase1Smoke.ps1 not found; skipping" -ForegroundColor Yellow
        $results.smoke = [pscustomobject]@{ pass = $false; reason = 'smoke script missing' }
    } else {
        try {
            $smokeResult = & $smokeScript -RepoRoot $repoRoot
            if ($smokeResult.pass) {
                Write-Host "  all 4 steps succeeded (open → post → check → list)" -ForegroundColor Green
            } else {
                Write-Host "  FAILED at step: $($smokeResult.failed_at)" -ForegroundColor Red
            }
            $results.smoke = $smokeResult
        } catch {
            Write-Host "  EXCEPTION: $($_.Exception.Message)" -ForegroundColor Red
            $results.smoke = [pscustomobject]@{ pass = $false; reason = $_.Exception.Message }
        }
    }
}

# ---------------- Overall verdict ----------------
$checks = @('git', 'files', 'tests', 'smoke')
$overall = $true
foreach ($c in $checks) {
    $r = $results[$c]
    if ($null -eq $r) { continue }
    if ($r.PSObject.Properties['skipped'] -and $r.skipped) { continue }
    if (-not $r.pass) { $overall = $false }
}
$results.overall = [pscustomobject]@{
    pass = $overall
    ran_at_utc = $results.ran_at_utc
}

Write-Section "OVERALL"
if ($overall) {
    Write-Host "  [PASS] HEALTHY - all runnable checks pass." -ForegroundColor Green
    Write-Host "  See STATUS.md for next-step priorities." -ForegroundColor Cyan
} else {
    Write-Host "  [FAIL] UNHEALTHY - see failures above. Do not start new work until resolved." -ForegroundColor Red
}

# Return structured result for scripting consumption
return [pscustomobject]$results
