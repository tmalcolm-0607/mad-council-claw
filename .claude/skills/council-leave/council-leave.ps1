#Requires -Version 7

<#
.SYNOPSIS
  Leave a MAD.Council channel. Produces a Completion Report, removes the member
  from channel.json, and — if this session is the last active member — archives
  the channel when -ConfirmArchive is explicit.

.DESCRIPTION
  Scope cut for the vertical slice:
    - Archive consent is a -ConfirmArchive switch (no AskUserQuestion prompt yet).
    - CronDelete teardown is outside this skill (caller detaches its own poller).
    - Owner-leave-without-transfer is rejected per rules/single-owner-accountability.md
      unless the channel is resolved/closed — matches the ADOPT-001 contract.

.PARAMETER Channel
  Channel name.

.PARAMETER Alias
  Leaving alias.

.PARAMETER SessionId
  Caller session id (must match member record).

.PARAMETER ConfirmArchive
  Same-session consent to archive when last-active-member. Absent → channel stays
  dormant (members[].status='disconnected' for all; no archive move).

.PARAMETER RunId
  Optional run_id stamped on the Completion Report.

.PARAMETER ClaudeDataRoot
  Override root.

.OUTPUTS
  Completion object with the report + final_state, exit_code, error_code, message.
  Exit codes:
    0 — left cleanly (or last-member-archived or last-member-dormant)
    2 — validation / not-a-member / session-mismatch
    3 — channel not found
    4 — filesystem error
    6 — OWNER_LEAVING_WITHOUT_TRANSFER (ADOPT-001)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $Channel,
    [Parameter(Mandatory = $true)] [string] $Alias,
    [Parameter(Mandatory = $true)] [string] $SessionId,
    [Parameter()] [switch] $ConfirmArchive,
    [Parameter()] [string] $RunId = $null,
    [Parameter()] [string] $ClaudeDataRoot = $null
)

Set-StrictMode -Version Latest

$scriptsDir = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'scripts')).ProviderPath
. (Join-Path $scriptsDir 'atomic-write.ps1')
. (Join-Path $scriptsDir 'channel-helpers.ps1')
. (Join-Path $scriptsDir 'completion-report.ps1')

function script:Fail {
    param([int] $Code, [string] $ErrorCode, [string] $Message)
    return [pscustomobject]@{
        status     = 'Failed'
        channel    = $Channel
        alias      = $Alias
        exit_code  = $Code
        error_code = $ErrorCode
        message    = $Message
    }
}

if (-not $ClaudeDataRoot) {
    $homeDir = if ($env:HOME) { $env:HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { [System.Environment]::GetFolderPath('UserProfile') }
    $ClaudeDataRoot = Join-Path $homeDir 'claude-data'
}
$channelsRoot = Join-Path $ClaudeDataRoot 'channels'
$channelDir   = Join-Path $channelsRoot $Channel
$nowUtc       = (Get-Date).ToUniversalTime()

# -- 1. Preflight -----------------------------------------------------------
if (-not (Test-Path -LiteralPath $channelDir)) {
    return script:Fail -Code 3 -ErrorCode 'CHANNEL_NOT_FOUND' -Message "Channel '$Channel' not found."
}

try {
    $channelObj = Get-ChannelMetadata -Name $Channel -Root $channelsRoot
} catch {
    return script:Fail -Code 4 -ErrorCode 'CHANNEL_JSON_CORRUPT' -Message $_.Exception.Message
}

$member = Find-MemberByAlias -Channel $channelObj -Alias $Alias
if (-not $member) {
    return script:Fail -Code 2 -ErrorCode 'NOT_A_MEMBER' -Message "'$Alias' not in '$Channel' members[]."
}
if ($member.session_id -ne $SessionId) {
    return script:Fail -Code 2 -ErrorCode 'SESSION_MISMATCH' -Message "Alias '$Alias' is held by a different session."
}

# -- 2. Owner-leaving check (ADOPT-001) --------------------------------
$isOwner = ($channelObj.PSObject.Properties['owner_alias'] -and $channelObj.owner_alias -eq $Alias)
$channelStatus = if ($channelObj.PSObject.Properties['status']) { $channelObj.status } else { 'active' }
if ($isOwner -and $channelStatus -notin 'resolved', 'closed') {
    return script:Fail -Code 6 -ErrorCode 'OWNER_LEAVING_WITHOUT_TRANSFER' `
        -Message "Owner '$Alias' cannot leave channel '$Channel' (status=$channelStatus) without an OWNERSHIP_TRANSFER verdict. See rules/single-owner-accountability.md."
}

# -- 3. Completion Report ---------------------------------------------------
$report = New-CompletionReport -ChannelName $Channel -Alias $Alias -SessionId $SessionId -RunId $RunId -Root $channelsRoot

# -- 4. Mark member disconnected -------------------------------------------
try {
    Update-ChannelMember -Name $Channel -Root $channelsRoot -Alias $Alias -Patch @{
        status        = 'disconnected'
        last_seen_utc = $nowUtc.ToString('o')
    }
} catch {
    return script:Fail -Code 4 -ErrorCode 'MEMBER_UPDATE_FAILED' -Message $_.Exception.Message
}

# -- 5. Last-active-member detection ---------------------------------------
$channelObj = Get-ChannelMetadata -Name $Channel -Root $channelsRoot
$activeCount = @($channelObj.members | Where-Object status -eq 'active').Count
$isLastActive = ($activeCount -eq 0)

$archived = $false
$finalState = 'left'
if ($isLastActive) {
    if ($ConfirmArchive) {
        try {
            $archiveRoot = Join-Path $ClaudeDataRoot 'archive'
            New-Item -ItemType Directory -Path $archiveRoot -Force | Out-Null
            $stamp = (Get-Date -Format 'yyyy-MM-dd')
            $archiveDest = Join-Path $archiveRoot "$stamp-$Channel"
            $suffix = 2
            while (Test-Path -LiteralPath $archiveDest) {
                $archiveDest = Join-Path $archiveRoot "$stamp-$Channel-$suffix"
                $suffix++
            }
            Move-Item -LiteralPath $channelDir -Destination $archiveDest -ErrorAction Stop
            $archived = $true
            $finalState = 'last-member-archived'
        } catch {
            return script:Fail -Code 4 -ErrorCode 'ARCHIVE_MOVE_FAILED' -Message $_.Exception.Message
        }
    } else {
        $finalState = 'last-member-dormant'
    }
}

# -- 6. .sessions.json — remove this channel from this session ---------------
try {
    Update-SessionRegistry -Root $ClaudeDataRoot -SessionId $SessionId -ChannelName $Channel -Action Remove
} catch {
    # Non-fatal; log but don't fail the leave.
}

# -- 7. Write the completion report to the (still-reachable) archive or dormant channel
if (-not $archived) {
    $reportDir = Join-Path $channelDir 'leave-reports'
    try {
        New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
        $reportPath = Join-Path $reportDir "$Alias-$($nowUtc.ToString('yyyy-MM-ddTHH-mm-ssZ')).json"
        $report | Add-Member -NotePropertyName 'final_state' -NotePropertyValue $finalState -Force
        Write-AtomicJson -Path $reportPath -Content $report
    } catch { }
} else {
    # Write inside the archived copy so it travels with the audit trail.
    $reportDir = Join-Path $archiveDest 'leave-reports'
    New-Item -ItemType Directory -Path $reportDir -Force | Out-Null
    $reportPath = Join-Path $reportDir "$Alias-$($nowUtc.ToString('yyyy-MM-ddTHH-mm-ssZ')).json"
    $report | Add-Member -NotePropertyName 'final_state' -NotePropertyValue $finalState -Force
    Write-AtomicJson -Path $reportPath -Content $report
}

return [pscustomobject]@{
    status      = 'OK'
    channel     = $Channel
    alias       = $Alias
    final_state = $finalState
    archived    = $archived
    report      = $report
    exit_code   = 0
    message     = "Left '$Channel' cleanly (final_state=$finalState)."
}
