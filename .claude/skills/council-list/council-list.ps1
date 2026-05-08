#Requires -Version 7

<#
.SYNOPSIS
  List channels the current session is a member of. Pure read.

.DESCRIPTION
  Reads .sessions.json + each channel's channel.json + digest.json + this
  session's read-marker, renders a summary row per channel. No writes.

.PARAMETER SessionId
  The session to list memberships for. Required — the registry may have been
  written by a different session recently; the caller supplies identity.

.PARAMETER Verbose2
  (aliased to -Expand to avoid clashing with PS's built-in -Verbose) Expand
  each row with purpose, created_utc, full member list, A2A/MAD flags.

.PARAMETER ClaudeDataRoot
  Override root.

.OUTPUTS
  PSCustomObject: status, channel_count, context_gap_count, channels (array
  of row objects), exit_code, report (pre-rendered text), error_code, message.

  Exit codes:
    0 — success
    1 — partial (Context Gaps on ≥1 channel)
    2 — no memberships OR sessions-registry unreadable
    4 — channels root inaccessible
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $SessionId,

    [Parameter(Mandatory = $false)]
    [Alias('Verbose2')]
    [switch] $Expand,

    [Parameter(Mandatory = $false)]
    [string] $ClaudeDataRoot = $null
)

Set-StrictMode -Version Latest

$scriptsDir = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'scripts')).ProviderPath
. (Join-Path $scriptsDir 'atomic-write.ps1')
. (Join-Path $scriptsDir 'channel-helpers.ps1')

function script:Fail {
    param([int] $Code, [string] $ErrorCode, [string] $Message)
    return [pscustomobject]@{
        status            = 'Failed'
        channel_count     = 0
        context_gap_count = 0
        channels          = @()
        exit_code         = $Code
        error_code        = $ErrorCode
        message           = $Message
        report            = ''
    }
}

function script:Format-Elapsed {
    param([datetime] $From)
    $delta = (Get-Date).ToUniversalTime() - $From.ToUniversalTime()
    if ($delta.TotalMinutes -lt 1) { return '<1m ago' }
    if ($delta.TotalMinutes -lt 60) { return "$([int]$delta.TotalMinutes)m ago" }
    if ($delta.TotalHours -lt 24) { return "$([int]$delta.TotalHours)h ago" }
    return "$([int]$delta.TotalDays)d ago"
}

function script:Format-Unread {
    param([int] $Count)
    if ($Count -le 0) { return '0' }
    if ($Count -ge 100) { return '99+' }
    return "$Count"
}

# -- Resolve defaults ---------------------------------------------------------
if (-not $ClaudeDataRoot) {
    $homeDir = if ($env:HOME) { $env:HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { [System.Environment]::GetFolderPath('UserProfile') }
    $ClaudeDataRoot = Join-Path $homeDir 'claude-data'
}
$channelsRoot = Join-Path $ClaudeDataRoot 'channels'

if (-not (Test-Path -LiteralPath $ClaudeDataRoot)) {
    return script:Fail -Code 4 -ErrorCode 'CLAUDE_DATA_MISSING' -Message "~/claude-data/ not present at $ClaudeDataRoot."
}

# -- 1. Read .sessions.json --------------------------------------------------
$registry = $null
try {
    $registry = Get-SessionRegistry -Root $ClaudeDataRoot
} catch {
    return script:Fail -Code 2 -ErrorCode 'SESSIONS_UNREADABLE' -Message ".sessions.json read failed: $($_.Exception.Message)"
}

$memberships = @()
if ($registry.session_id -eq $SessionId) {
    $memberships = @($registry.memberships)
}
# If the registry is held by a different session, we treat that as "this session has
# no memberships yet." Matches the multi-session posture where each session owns its
# own registry; a session that hasn't written yet gets an empty list.

if (@($memberships).Count -eq 0) {
    $report = "No memberships for session '$SessionId'. Use /council-open or /council-join first."
    return [pscustomobject]@{
        status            = 'OK'
        channel_count     = 0
        context_gap_count = 0
        channels          = @()
        exit_code         = 2
        error_code        = 'NO_MEMBERSHIPS'
        message           = $report
        report            = $report
    }
}

# -- 2. Per-channel state collection -----------------------------------------
$rows = [System.Collections.ArrayList]::new()
$contextGaps = [System.Collections.ArrayList]::new()

foreach ($m in $memberships) {
    $row = [ordered]@{
        channel         = $m.channel
        alias           = $m.alias
        threads_active  = '?'
        threads_stale   = 0
        unread          = '?'
        mad_phase       = '—'
        activity        = '?'
        member_count    = '?'
        member_detail   = ''
        context_gaps    = [System.Collections.ArrayList]::new()
        expand          = $null
    }

    $channelDir = Join-Path $channelsRoot $m.channel

    # -- channel.json
    $channel = $null
    try {
        $channel = Get-ChannelMetadata -Name $m.channel -Root $channelsRoot
    } catch {
        [void]$row.context_gaps.Add("channel.json unreadable: $($_.Exception.Message)")
        [void]$contextGaps.Add(@{ channel = $m.channel; source = 'channel.json'; error = $_.Exception.Message })
    }

    if ($channel) {
        $members = @($channel.members)
        $active = @($members | Where-Object status -eq 'active').Count
        $idle = @($members | Where-Object status -eq 'idle').Count
        $disc = @($members | Where-Object status -eq 'disconnected').Count
        $row.member_count = $members.Count
        $detail = @()
        if ($idle -gt 0) { $detail += "$idle idle" }
        if ($disc -gt 0) { $detail += "$disc disconnected" }
        $row.member_detail = if ($detail.Count) { " ($($detail -join ', '))" } else { '' }
    }

    # -- digest.json
    $digestPath = Join-Path $channelDir 'digest.json'
    $digest = $null
    if (Test-Path -LiteralPath $digestPath) {
        try {
            $digest = Read-AtomicJson -Path $digestPath
        } catch {
            [void]$row.context_gaps.Add("digest.json unreadable: $($_.Exception.Message)")
            [void]$contextGaps.Add(@{ channel = $m.channel; source = 'digest.json'; error = $_.Exception.Message })
        }
    } else {
        [void]$row.context_gaps.Add('digest.json missing')
        [void]$contextGaps.Add(@{ channel = $m.channel; source = 'digest.json'; error = 'missing' })
    }

    if ($digest) {
        $threads = @($digest.threads)
        $active = @($threads | Where-Object status -eq 'active').Count
        $stale  = @($threads | Where-Object status -eq 'stale').Count
        $row.threads_active = $active
        $row.threads_stale  = $stale
        if ($digest.PSObject.Properties['rebuilt_utc'] -and $digest.rebuilt_utc) {
            try {
                $row.activity = script:Format-Elapsed -From ([datetimeoffset]$digest.rebuilt_utc).UtcDateTime
            } catch {
                $row.activity = '?'
            }
        }
        if ($digest.PSObject.Properties['mad_state'] -and $digest.mad_state -and $digest.mad_state.phase) {
            $row.mad_phase = $digest.mad_state.phase
        }

        # -- unread from read-marker
        $markerPath = Join-Path $channelDir 'read-markers' "$($m.alias).json"
        if (Test-Path -LiteralPath $markerPath) {
            try {
                $marker = Read-AtomicJson -Path $markerPath
                $lastRead = if ($marker.PSObject.Properties['last_read_seq']) { [int]$marker.last_read_seq } else { 0 }
                $seq = if ($digest.PSObject.Properties['channel_seq']) { [int]$digest.channel_seq } else { 0 }
                $row.unread = script:Format-Unread -Count ($seq - $lastRead)
            } catch {
                [void]$row.context_gaps.Add("read-marker unreadable: $($_.Exception.Message)")
            }
        } else {
            $row.unread = '0'  # Fresh join had seq=0 and no events.
        }
    }

    # -- Expand detail
    if ($Expand -and $channel) {
        $memberLines = @($channel.members | ForEach-Object {
            $seen = if ($_.PSObject.Properties['last_seen_utc'] -and $_.last_seen_utc) {
                try { script:Format-Elapsed -From ([datetimeoffset]$_.last_seen_utc).UtcDateTime } catch { '?' }
            } else { '?' }
            $youMarker = if ($_.alias -eq $m.alias) { ' (you)' } else { '' }
            "    - $($_.alias)$youMarker  $($_.status) - last seen $seen"
        })
        $row.expand = [ordered]@{
            purpose          = $channel.purpose
            created_utc      = $channel.created_utc
            environment_tier = $channel.environment_tier
            status           = if ($channel.PSObject.Properties['status']) { $channel.status } else { 'active' }
            owner_alias      = $channel.owner_alias
            mad_enabled      = $channel.settings.mad_enabled
            a2a_enabled      = $channel.settings.a2a_enabled
            members          = $memberLines
        }
    }

    [void]$rows.Add([pscustomobject]$row)
}

# -- 3. Render the table ------------------------------------------------------
$lines = [System.Collections.ArrayList]::new()
$aliasSet = @($memberships | ForEach-Object { $_.alias } | Sort-Object -Unique)
[void]$lines.Add("Your channels ($($aliasSet -join ', ')):")
[void]$lines.Add('')
[void]$lines.Add(('  {0,-20} {1,-12} {2,-10} {3,-16} {4,-12} {5,-20}' -f 'Channel', 'Threads', 'Unread', 'MAD Phase', 'Activity', 'Members'))
[void]$lines.Add('  ' + ('-' * 90))
foreach ($r in $rows) {
    $threads = if ($r.threads_stale -gt 0) { "$($r.threads_active) active ($($r.threads_stale) stale)" } else { "$($r.threads_active) active" }
    $members = "$($r.member_count)$($r.member_detail)"
    [void]$lines.Add(('  #{0,-19} {1,-12} {2,-10} {3,-16} {4,-12} {5,-20}' -f $r.channel, $threads, $r.unread, $r.mad_phase, $r.activity, $members))
}
[void]$lines.Add('')
$totalUnread = 0
foreach ($r in $rows) {
    if ($r.unread -eq '?') { continue }
    $n = 0
    if ([int]::TryParse($r.unread, [ref]$n)) { $totalUnread += $n }
    elseif ($r.unread -eq '99+') { $totalUnread += 99 }
}
[void]$lines.Add("Total: $(@($rows).Count) channels, $totalUnread unread messages across all.")

if ($contextGaps.Count -gt 0) {
    [void]$lines.Add('')
    [void]$lines.Add('Context Gaps:')
    foreach ($g in $contextGaps) {
        [void]$lines.Add("  - #$($g.channel): $($g.source) - $($g.error)")
    }
}

if ($Expand) {
    [void]$lines.Add('')
    foreach ($r in $rows) {
        if (-not $r.expand) { continue }
        [void]$lines.Add("#$($r.channel)")
        [void]$lines.Add("  Purpose: $($r.expand.purpose)")
        [void]$lines.Add("  Owner:   $($r.expand.owner_alias)")
        [void]$lines.Add("  Tier:    $($r.expand.environment_tier)  Status: $($r.expand.status)")
        [void]$lines.Add("  MAD: $(if ($r.expand.mad_enabled) { 'enabled' } else { 'disabled' })   A2A: $(if ($r.expand.a2a_enabled) { 'enabled' } else { 'disabled' })")
        [void]$lines.Add('  Members:')
        foreach ($ml in $r.expand.members) { [void]$lines.Add($ml) }
        [void]$lines.Add('')
    }
}

$report = ($lines -join [Environment]::NewLine)
$exit = if ($contextGaps.Count -gt 0) { 1 } else { 0 }

return [pscustomobject]@{
    status            = 'OK'
    channel_count     = @($rows).Count
    context_gap_count = $contextGaps.Count
    channels          = @($rows)
    exit_code         = $exit
    message           = "Rendered $(@($rows).Count) channel(s)."
    report            = $report
}
