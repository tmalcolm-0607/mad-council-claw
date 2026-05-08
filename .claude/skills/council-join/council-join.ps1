#Requires -Version 7

<#
.SYNOPSIS
  Join an existing MAD.Council channel as a named member. Handles fresh join,
  silent reclaim of disconnected/idle aliases, and active-alias-conflict
  rejection (with --ForceReclaim bypass for same-user restart scenarios).

.DESCRIPTION
  Second executable skill in the vertical slice. Implements the spec per:
    - skills/council-join/SKILL.md
    - skills/council-join/plan.md
    - operations/dry-run-happy-path.md §Step 3
    - rules/concurrency-safety.md (atomic member-list update)

  Scope cut for the vertical slice:
    - No Agent Card loading (Phase-4 A2A concern).
    - No CronCreate wiring — cron_task_id stays null; caller arms polling separately.
    - No interactive consent prompt on --ForceReclaim — the switch itself is
      treated as same-session consent. Full AskUserQuestion integration lands
      with the Phase-1 full-scope consent-gate work.

.PARAMETER Name
  Channel name.

.PARAMETER Alias
  Alias to join as.

.PARAMETER SessionId
  This session's ID (bound to alias per spec §7.2).

.PARAMETER PollSeconds
  Default poll interval for CronCreate setup (recorded on member entry;
  actual CronCreate setup deferred).

.PARAMETER ForceReclaim
  Bypass active-alias conflict. Treated as same-session consent in this slice.

.PARAMETER Project
  Optional project identifier stored on member entry.

.PARAMETER ClaudeDataRoot
  Override root. Default $HOME/claude-data.

.PARAMETER RunId
  Optional GUID. Auto-generated if omitted.

.OUTPUTS
  Completion object: status, channel, alias, reclaim_case (A|B|C-force|D), run_id,
  exit_code, error_code (on failure), message.

  Exit codes:
    0 — joined / reclaimed / no-op
    2 — validation error OR active-alias conflict without --ForceReclaim
    3 — channel not found
    4 — filesystem / concurrency error
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Name,

    [Parameter(Mandatory = $true)]
    [string] $Alias,

    [Parameter(Mandatory = $true)]
    [string] $SessionId,

    [Parameter(Mandatory = $false)]
    [ValidateRange(60, 600)]
    [int] $PollSeconds = 60,

    [Parameter(Mandatory = $false)]
    [switch] $ForceReclaim,

    [Parameter(Mandatory = $false)]
    [string] $Project = '',

    [Parameter(Mandatory = $false)]
    [string] $ClaudeDataRoot = $null,

    [Parameter(Mandatory = $false)]
    [string] $RunId = $null
)

Set-StrictMode -Version Latest

$scriptsDir = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'scripts')).ProviderPath
. (Join-Path $scriptsDir 'atomic-write.ps1')
. (Join-Path $scriptsDir 'channel-helpers.ps1')

function script:Fail {
    param([int] $Code, [string] $ErrorCode, [string] $Message, [string] $ReclaimCase = '')
    return [pscustomobject]@{
        status       = 'Failed'
        channel      = $Name
        alias        = $Alias
        reclaim_case = $ReclaimCase
        run_id       = $RunId
        exit_code    = $Code
        error_code   = $ErrorCode
        message      = $Message
    }
}

# -- Resolve defaults ---------------------------------------------------------
if (-not $RunId) { $RunId = [guid]::NewGuid().ToString() }
if (-not $ClaudeDataRoot) {
    $homeDir = if ($env:HOME) { $env:HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { [System.Environment]::GetFolderPath('UserProfile') }
    $ClaudeDataRoot = Join-Path $homeDir 'claude-data'
}
$channelsRoot = Join-Path $ClaudeDataRoot 'channels'
$channelDir   = Join-Path $channelsRoot $Name
$channelJson  = Join-Path $channelDir 'channel.json'
$nowUtc = (Get-Date).ToUniversalTime().ToString('o')

# -- 1. Validate args ---------------------------------------------------------
$aliasTrimmed = $Alias.Trim()
if ($aliasTrimmed -ne $Alias -or $Alias.Length -lt 1 -or $Alias.Length -gt 64) {
    return script:Fail -Code 2 -ErrorCode 'INVALID_ALIAS' -Message "Alias must be 1-64 chars without leading/trailing whitespace (got '$Alias')."
}

# -- 2. Channel-exists check --------------------------------------------------
if (-not (Test-Path -LiteralPath $channelJson)) {
    return script:Fail -Code 3 -ErrorCode 'CHANNEL_NOT_FOUND' -Message "Channel '$Name' not found at $channelDir."
}

# -- 3. Read + validate channel.json ------------------------------------------
try {
    $channel = Get-ChannelMetadata -Name $Name -Root $channelsRoot
} catch {
    return script:Fail -Code 4 -ErrorCode 'CHANNEL_JSON_CORRUPT' -Message "channel.json read failed: $($_.Exception.Message)"
}

# -- 4. Alias conflict resolution --------------------------------------------
$existing = Find-MemberByAlias -Channel $channel -Alias $Alias
$reclaimCase = $null
if (-not $existing) {
    # Case A — fresh join
    $reclaimCase = 'A'
} elseif ($existing.session_id -eq $SessionId) {
    # Case D — idempotent re-invoke
    $reclaimCase = 'D'
} elseif ($existing.status -in 'disconnected', 'idle') {
    # Case B — silent reclaim
    $reclaimCase = 'B'
} else {
    # Case C — active collision
    if (-not $ForceReclaim) {
        $lastSeen = if ($existing.PSObject.Properties['last_seen_utc']) { $existing.last_seen_utc } else { '(unknown)' }
        return script:Fail -Code 2 -ErrorCode 'ALIAS_ACTIVE_CONFLICT' -ReclaimCase 'C-reject' `
            -Message "Alias '$Alias' is active (session '$($existing.session_id)', last seen $lastSeen). Use -ForceReclaim to override."
    }
    $reclaimCase = 'C-force'
}

# -- 5. Short-circuit Case D --------------------------------------------------
if ($reclaimCase -eq 'D') {
    return [pscustomobject]@{
        status       = 'OK'
        channel      = $Name
        alias        = $Alias
        reclaim_case = 'D'
        run_id       = $RunId
        exit_code    = 0
        message      = "Already joined as '$Alias' (same session); no-op."
    }
}

# -- 6. Materialize member change ---------------------------------------------
try {
    if ($reclaimCase -eq 'A') {
        $member = [ordered]@{
            alias         = $Alias
            session_id    = $SessionId
            joined_utc    = $nowUtc
            status        = 'active'
            last_seen_utc = $nowUtc
        }
        if ($Project) { $member['project'] = $Project }
        Add-ChannelMember -Name $Name -Root $channelsRoot -Member $member
    } else {
        # Cases B + C-force: reclaim the existing entry.
        $patch = @{
            session_id    = $SessionId
            status        = 'active'
            last_seen_utc = $nowUtc
        }
        if ($Project) { $patch['project'] = $Project }
        Update-ChannelMember -Name $Name -Root $channelsRoot -Alias $Alias -Patch $patch
    }

    # -- 7. Create read-marker (fresh) OR preserve (reclaim) ------------------
    $markerPath = Join-Path $channelDir 'read-markers' "$Alias.json"
    if ($reclaimCase -eq 'A' -or -not (Test-Path -LiteralPath $markerPath)) {
        New-Item -ItemType Directory -Path (Split-Path -Parent $markerPath) -Force -ErrorAction SilentlyContinue | Out-Null
        Write-AtomicJson -Path $markerPath -Content ([ordered]@{
            alias         = $Alias
            session_id    = $SessionId
            last_read_seq = 0
            updated_utc   = $nowUtc
        })
    } else {
        # Reclaim path: update session_id + updated_utc but preserve last_read_seq.
        $marker = Read-AtomicJson -Path $markerPath
        $marker | Add-Member -NotePropertyName 'session_id' -NotePropertyValue $SessionId -Force
        $marker | Add-Member -NotePropertyName 'updated_utc' -NotePropertyValue $nowUtc -Force
        Write-AtomicJson -Path $markerPath -Content $marker
    }

    # -- 8. Update .sessions.json --------------------------------------------
    Update-SessionRegistry -Root $ClaudeDataRoot -SessionId $SessionId -ChannelName $Name -Alias $Alias -Action Add
} catch {
    return script:Fail -Code 4 -ErrorCode 'MATERIALIZE_FAILED' -ReclaimCase $reclaimCase `
        -Message "Failed to materialize join for '$Alias' in '$Name': $($_.Exception.Message)"
}

$msg = switch ($reclaimCase) {
    'A'       { "Joined '$Name' as '$Alias' (fresh)." }
    'B'       { "Reclaimed '$Alias' in '$Name' (was disconnected/idle); read-marker preserved." }
    'C-force' { "Force-reclaimed '$Alias' in '$Name' from prior active session." }
}

return [pscustomobject]@{
    status       = 'OK'
    channel      = $Name
    alias        = $Alias
    reclaim_case = $reclaimCase
    run_id       = $RunId
    exit_code    = 0
    message      = $msg
}
