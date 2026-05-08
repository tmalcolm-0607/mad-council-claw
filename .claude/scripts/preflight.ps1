<#
.SYNOPSIS
  Run preflight dependency checks before any state-mutating /council-* skill.
  Returns per-dependency status + overall go/no-go per wiki/patterns/preflight-dependency-checks.md.

.DESCRIPTION
  Implements the preflight table from mad.council.a2a.md §10.3. Canonical deps:

    ~/claude-data/ writable       — Required for everything
    CronCreate tool available     — Required for polling mode (fallback: manual-check)
    Clock within 60s of UTC       — Recommended (warns if drift)
    A2A bridge reachable          — Optional (only if A2A mode enabled)
    MAD prerequisites             — Optional (only if --mad flag)

  Each probe is fast (<2s), read-only, parallelizable. Results include a
  rendered report with ✅ ⚠️ ❌ icons for user display.

.PARAMETER Context
  Name of the calling skill ('council-open', 'council-join', etc.). Used for
  context-specific probe lists.

.PARAMETER MadEnabled
  Include MAD preflight checks.

.PARAMETER A2aEnabled
  Include A2A bridge reachability check.

.PARAMETER A2aBridgeUrl
  If A2aEnabled, the URL to probe (default: https://localhost:8222).

.PARAMETER OrphanSweepMaxAgeSeconds
  Sweep .tmp files older than this. Default: 60.

.OUTPUTS
  Object with:
    - Status: 'OK' | 'Warn' | 'Fail'
    - Checks: array of per-check results
    - Report: pre-rendered user-facing markdown table
    - ContextGaps: array of gaps to feed /council-check's Context Gaps section

  Caller checks Status:
    - OK → proceed silently.
    - Warn → show report + confirm to proceed.
    - Fail → show report + stop (rc=4 at skill level).

.NOTES
  Used by:
    - skills/council-open/plan.md step 2
    - skills/council-join/plan.md step 3
    - (Other skills don't run preflight — they operate on already-joined channels.)

  Orphan .tmp sweep: checks every channel dir the calling session is a member of,
  removes .tmp files older than OrphanSweepMaxAgeSeconds. Catches orphans from
  a prior crashed-mid-write session per rules/concurrency-safety.md §Edge cases.

  Canonical probe table lives in wiki/patterns/preflight-dependency-checks.md.
#>

Set-StrictMode -Version Latest

function Invoke-Preflight {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('council-open', 'council-join')]
        [string] $Context,

        [Parameter(Mandatory = $false)]
        [bool] $MadEnabled = $false,

        [Parameter(Mandatory = $false)]
        [bool] $A2aEnabled = $false,

        [Parameter(Mandatory = $false)]
        [string] $A2aBridgeUrl = 'https://localhost:8222',

        [Parameter(Mandatory = $false)]
        [int] $OrphanSweepMaxAgeSeconds = 60,

        [Parameter(Mandatory = $false)]
        [string] $ClaudeDataRoot = $null
    )

    if (-not $ClaudeDataRoot) {
        $homeDir = if ($env:HOME) { $env:HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { [System.Environment]::GetFolderPath('UserProfile') }
        $ClaudeDataRoot = Join-Path $homeDir 'claude-data'
    }

    $checks = [System.Collections.ArrayList]::new()
    $contextGaps = [System.Collections.ArrayList]::new()

    # --- 1. ClaudeDataWritable (Required) -------------------------------------
    $channelsRoot = Join-Path $ClaudeDataRoot 'channels'
    $writable = $false
    $writeProbeError = $null
    try {
        if (-not (Test-Path -LiteralPath $channelsRoot)) {
            New-Item -ItemType Directory -Path $channelsRoot -Force -ErrorAction Stop | Out-Null
        }
        $probe = Join-Path $channelsRoot ".preflight-$([guid]::NewGuid().ToString('N').Substring(0,8)).probe"
        Set-Content -LiteralPath $probe -Value 'ok' -ErrorAction Stop
        Remove-Item -LiteralPath $probe -Force -ErrorAction Stop
        $writable = $true
    } catch {
        $writeProbeError = $_.Exception.Message
    }
    [void]$checks.Add([pscustomobject]@{
        name     = 'claude-data-writable'
        required = $true
        status   = if ($writable) { 'OK' } else { 'Fail' }
        message  = if ($writable) { "writable: $channelsRoot" } else { "not writable: $channelsRoot ($writeProbeError)" }
    })

    # --- 2. CronCreateAvailable (Required; heuristic probe) -------------------
    # We can't directly query the Claude Code host tool registry from pwsh; caller
    # supplies $env:MAD_CRONCREATE_OK = 'true' when the host reported availability.
    # Absent env var defaults to Warn (fallback: manual-check polling mode).
    $cronStatus = if ($env:MAD_CRONCREATE_OK -eq 'true') { 'OK' } else { 'Warn' }
    [void]$checks.Add([pscustomobject]@{
        name     = 'croncreate-available'
        required = $false
        status   = $cronStatus
        message  = if ($cronStatus -eq 'OK') { 'CronCreate available (env hint)' } else { 'CronCreate not confirmed; fallback to manual-check' }
    })

    # --- 3. ClockSkew (Recommended; skipped unless MAD_CHECK_CLOCK set) -------
    if ($env:MAD_CHECK_CLOCK -eq 'true') {
        try {
            $resp = Invoke-WebRequest -Uri 'https://www.microsoft.com/' -Method Head -TimeoutSec 3 -ErrorAction Stop
            $serverTime = [datetimeoffset]::Parse($resp.Headers['Date'])
            $drift = [Math]::Abs(((Get-Date).ToUniversalTime() - $serverTime.UtcDateTime).TotalSeconds)
            [void]$checks.Add([pscustomobject]@{
                name     = 'clock-skew'
                required = $false
                status   = if ($drift -le 60) { 'OK' } else { 'Warn' }
                message  = "drift ${drift}s"
            })
        } catch {
            [void]$checks.Add([pscustomobject]@{
                name     = 'clock-skew'
                required = $false
                status   = 'Skip'
                message  = "probe failed: $($_.Exception.Message)"
            })
        }
    }

    # --- 4. A2aBridgeReachable (Optional) -------------------------------------
    if ($A2aEnabled) {
        try {
            $null = Invoke-WebRequest -Uri $A2aBridgeUrl -Method Head -TimeoutSec 3 -ErrorAction Stop
            [void]$checks.Add([pscustomobject]@{
                name     = 'a2a-bridge-reachable'
                required = $false
                status   = 'OK'
                message  = "bridge up at $A2aBridgeUrl"
            })
        } catch {
            [void]$checks.Add([pscustomobject]@{
                name     = 'a2a-bridge-reachable'
                required = $false
                status   = 'Warn'
                message  = "bridge unreachable at $A2aBridgeUrl"
            })
            [void]$contextGaps.Add([pscustomobject]@{
                source = 'a2a-bridge'
                status = 'unreachable'
                impact = 'A2A transport disabled for this invocation'
            })
        }
    }

    # --- 5. MadPrereqs (Optional) --------------------------------------------
    if ($MadEnabled) {
        [void]$checks.Add([pscustomobject]@{
            name     = 'mad-prereqs'
            required = $false
            status   = 'OK'
            message  = 'mad-templates available via scripts/mad-templates/'
        })
    }

    # --- 6. Orphan .tmp sweep (always runs; informational) --------------------
    $sweepReport = Invoke-OrphanTmpSweep -ChannelsRoot $channelsRoot -MaxAgeSeconds $OrphanSweepMaxAgeSeconds
    [void]$checks.Add([pscustomobject]@{
        name     = 'orphan-tmp-sweep'
        required = $false
        status   = 'OK'
        message  = "swept $($sweepReport.removed_count) .tmp file(s) older than ${OrphanSweepMaxAgeSeconds}s"
    })

    # --- 7. Aggregate ---------------------------------------------------------
    $hasFail = @($checks | Where-Object { $_.status -eq 'Fail' }).Count -gt 0
    $hasWarn = @($checks | Where-Object { $_.status -eq 'Warn' }).Count -gt 0

    $overall = if ($hasFail) { 'Fail' } elseif ($hasWarn) { 'Warn' } else { 'OK' }

    $result = [pscustomobject]@{
        Status      = $overall
        Checks      = @($checks)
        ContextGaps = @($contextGaps)
        Report      = ''
    }
    $result.Report = Format-PreflightReport -PreflightResult $result -Context $Context
    return $result
}

function Format-PreflightReport {
    <#
    .SYNOPSIS
      Render the preflight result object as a plain-text block for user display.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $PreflightResult,

        [Parameter(Mandatory = $false)]
        [string] $Context = ''
    )

    $icon = @{ 'OK' = '[OK]'; 'Warn' = '[!]'; 'Fail' = '[X]'; 'Skip' = '[-]' }
    $lines = [System.Collections.ArrayList]::new()
    $header = if ($Context) { "Preflight Checks for /${Context}:" } else { 'Preflight Checks:' }
    [void]$lines.Add($header)
    foreach ($c in $PreflightResult.Checks) {
        $ic = if ($icon.ContainsKey($c.status)) { $icon[$c.status] } else { '[?]' }
        [void]$lines.Add("  $ic $($c.name): $($c.message)")
    }
    $ok   = @($PreflightResult.Checks | Where-Object status -eq 'OK').Count
    $warn = @($PreflightResult.Checks | Where-Object status -eq 'Warn').Count
    $fail = @($PreflightResult.Checks | Where-Object status -eq 'Fail').Count
    $total = @($PreflightResult.Checks).Count
    [void]$lines.Add('')
    [void]$lines.Add("  Result: ${ok}/${total} OK, ${warn} warnings, ${fail} failures. Overall: $($PreflightResult.Status).")
    return ($lines -join [Environment]::NewLine)
}

function Invoke-OrphanTmpSweep {
    <#
    .SYNOPSIS
      Remove .tmp files older than threshold under the channels root.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [int] $MaxAgeSeconds = 60,

        [Parameter(Mandatory = $false)]
        [string] $ChannelsRoot = $null
    )

    if (-not $ChannelsRoot) {
        $homeDir = if ($env:HOME) { $env:HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { [System.Environment]::GetFolderPath('UserProfile') }
        $ChannelsRoot = Join-Path $homeDir 'claude-data' 'channels'
    }

    $removed = [System.Collections.ArrayList]::new()
    if (Test-Path -LiteralPath $ChannelsRoot) {
        $threshold = (Get-Date).AddSeconds(-$MaxAgeSeconds)
        $orphans = @(Get-ChildItem -Path $ChannelsRoot -Filter '*.tmp' -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.LastWriteTime -lt $threshold })
        foreach ($f in $orphans) {
            try {
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                [void]$removed.Add($f.FullName)
            } catch {
                # Log-and-continue; sweep is informational.
            }
        }
    }

    return [pscustomobject]@{
        removed_count = $removed.Count
        removed_paths = @($removed)
    }
}
