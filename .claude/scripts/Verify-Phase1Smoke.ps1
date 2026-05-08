#Requires -Version 7
<#
.SYNOPSIS
  Phase 1 MVP end-to-end smoke test. Exercises open → post → check → list
  against a throwaway ~/claude-data/ equivalent, proves schema-valid artifacts
  land on disk, then cleans up.

.DESCRIPTION
  Used by Verify-Health.ps1 step 4. Can also be run standalone.

  Creates a temp data root under the repo (gitignored), runs the 4-command
  roundtrip, inspects filesystem artifacts, returns pass/fail + details.

.PARAMETER RepoRoot
  Path to the MAD unified repo root. Default: one level up from this script.

.PARAMETER KeepData
  Don't delete the temp data root on exit. Useful for debugging failures.

.OUTPUTS
  PSCustomObject {
    pass:        bool
    steps:       array of per-step records (step, status, message)
    artifacts:   array of produced file paths
    failed_at:   string | null
    data_root:   string (path used)
  }
#>

[CmdletBinding()]
param(
    [string] $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).ProviderPath,
    [switch] $KeepData
)

Set-StrictMode -Version Latest

$RepoRoot = (Resolve-Path $RepoRoot).ProviderPath
$dataRoot = Join-Path $RepoRoot ".smoke-data-health-$([guid]::NewGuid().ToString('N').Substring(0,8))"
New-Item -ItemType Directory -Path (Join-Path $dataRoot 'channels') -Force | Out-Null

$channelName = 'health-smoke'
$alias       = 'healthcheck'
$sessionId   = 'sess-health'
$threadId    = 'health-thread'

$steps = [System.Collections.ArrayList]::new()
$failedAt = $null

function script:Record-Step {
    param(
        [string] $Name,
        [bool] $Pass,
        [string] $Detail = ''
    )
    [void]$steps.Add([pscustomobject]@{
        step    = $Name
        pass    = $Pass
        detail  = $Detail
    })
    return $Pass
}

try {
    # --- 1) council-open ---
    $openScript = Join-Path $RepoRoot '.claude/skills/council-open/council-open.ps1'
    if (-not (Test-Path -LiteralPath $openScript)) {
        [void](Record-Step -Name 'council-open' -Pass $false -Detail "script not found: $openScript")
        $failedAt = 'council-open'
    } else {
        $openResult = & $openScript -Name $channelName -Purpose 'Verify-Health smoke' -Tier 'local' -Alias $alias -SessionId $sessionId -ClaudeDataRoot $dataRoot
        $okOpen = ($openResult -and $openResult.status -eq 'OK')
        [void](Record-Step -Name 'council-open' -Pass $okOpen -Detail "status=$($openResult.status); run_id=$($openResult.run_id)")
        if (-not $okOpen) { $failedAt = 'council-open' }
    }

    # --- 2) council-post ---
    if (-not $failedAt) {
        $postScript = Join-Path $RepoRoot '.claude/skills/council-post/council-post.ps1'
        $postResult = & $postScript -Channel $channelName -Alias $alias -SessionId $sessionId -Type 'status' -Body 'Verify-Health smoke roundtrip' -NewThread $threadId -ClaudeDataRoot $dataRoot
        $okPost = ($postResult -and $postResult.status -eq 'OK')
        [void](Record-Step -Name 'council-post' -Pass $okPost -Detail "status=$($postResult.status); seq=$($postResult.seq)")
        if (-not $okPost) { $failedAt = 'council-post' }
    }

    # --- 3) council-check ---
    if (-not $failedAt) {
        $checkScript = Join-Path $RepoRoot '.claude/skills/council-check/council-check.ps1'
        $checkResult = & $checkScript -Channel $channelName -Alias $alias -SessionId $sessionId -ClaudeDataRoot $dataRoot
        $okCheck = ($checkResult -and $checkResult.status -eq 'OK' -and $checkResult.unread_count -ge 1)
        [void](Record-Step -Name 'council-check' -Pass $okCheck -Detail "status=$($checkResult.status); unread_count=$($checkResult.unread_count)")
        if (-not $okCheck) { $failedAt = 'council-check' }
    }

    # --- 4) council-list ---
    if (-not $failedAt) {
        $listScript = Join-Path $RepoRoot '.claude/skills/council-list/council-list.ps1'
        $listResult = & $listScript -SessionId $sessionId -ClaudeDataRoot $dataRoot
        $okList = ($listResult -and $listResult.status -eq 'OK' -and $listResult.channel_count -ge 1)
        [void](Record-Step -Name 'council-list' -Pass $okList -Detail "status=$($listResult.status); channel_count=$($listResult.channel_count)")
        if (-not $okList) { $failedAt = 'council-list' }
    }

    # --- collect artifacts produced ---
    $artifacts = @(Get-ChildItem -Path $dataRoot -Recurse -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName.Substring($dataRoot.Length + 1) } | Sort-Object)

    $pass = ($failedAt -eq $null)

    return [pscustomobject]@{
        pass       = $pass
        steps      = $steps.ToArray()
        artifacts  = $artifacts
        failed_at  = $failedAt
        data_root  = $dataRoot
    }
} finally {
    if (-not $KeepData) {
        Remove-Item -LiteralPath $dataRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}
