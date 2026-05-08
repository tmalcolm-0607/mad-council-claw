#Requires -Version 7

<#
.SYNOPSIS
  Read unread messages in a MAD.Council channel. Applies post-read session-id
  verification (defense-in-depth vs post-time check) and Rule-1 literal-phrase
  flagging. Updates read-marker + last_seen_utc.

.DESCRIPTION
  Scope cut for the vertical slice:
    - Single -Channel only; `--all` (fan out over .sessions.json) deferred.
    - No CronCreate polling lifecycle — caller arms the cron separately.
    - Rendering is a structured object; CLI pretty-print deferred.

.PARAMETER Channel
  Target channel.

.PARAMETER Alias
  Caller alias.

.PARAMETER SessionId
  Caller session id.

.PARAMETER ShowAllActive
  Include already-read messages from active threads (diagnostic mode).

.PARAMETER ClaudeDataRoot
  Override root.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $Channel,
    [Parameter(Mandatory = $true)] [string] $Alias,
    [Parameter(Mandatory = $true)] [string] $SessionId,
    [Parameter()] [switch] $ShowAllActive,
    [Parameter()] [string] $ClaudeDataRoot = $null
)

Set-StrictMode -Version Latest

$scriptsDir = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'scripts')).ProviderPath
. (Join-Path $scriptsDir 'atomic-write.ps1')
. (Join-Path $scriptsDir 'channel-helpers.ps1')
. (Join-Path $scriptsDir 'literal-phrase-scan.ps1')

function script:Fail {
    param([int] $Code, [string] $ErrorCode, [string] $Message)
    return [pscustomobject]@{
        status     = 'Failed'
        channel    = $Channel
        exit_code  = $Code
        error_code = $ErrorCode
        message    = $Message
        messages   = @()
    }
}

if (-not $ClaudeDataRoot) {
    $homeDir = if ($env:HOME) { $env:HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { [System.Environment]::GetFolderPath('UserProfile') }
    $ClaudeDataRoot = Join-Path $homeDir 'claude-data'
}
$channelsRoot = Join-Path $ClaudeDataRoot 'channels'
$channelDir   = Join-Path $channelsRoot $Channel
$nowUtc       = (Get-Date).ToUniversalTime()

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
    return script:Fail -Code 2 -ErrorCode 'NOT_A_MEMBER' -Message "Not a member of '$Channel'."
}
if ($member.session_id -ne $SessionId) {
    return script:Fail -Code 2 -ErrorCode 'SESSION_MISMATCH' `
        -Message "session_id does not match member registration for '$Alias'."
}

$contextGaps = [System.Collections.ArrayList]::new()

# Read digest
$digestPath = Join-Path $channelDir 'digest.json'
$digest = $null
try {
    $digest = Read-AtomicJson -Path $digestPath
} catch {
    [void]$contextGaps.Add([pscustomobject]@{ source = 'digest.json'; status = 'unreadable'; impact = 'unread list may be incomplete' })
}
$channelSeq = if ($digest -and $digest.PSObject.Properties['channel_seq']) { [int]$digest.channel_seq } else { 0 }

# Read own marker
$markerPath = Join-Path $channelDir 'read-markers' "$Alias.json"
$marker = $null
$lastRead = 0
if (Test-Path -LiteralPath $markerPath) {
    try {
        $marker = Read-AtomicJson -Path $markerPath
        if ($marker.PSObject.Properties['last_read_seq']) { $lastRead = [int]$marker.last_read_seq }
    } catch {
        [void]$contextGaps.Add([pscustomobject]@{ source = "read-markers/$Alias.json"; status = 'unreadable'; impact = 'last_read_seq defaulted to 0' })
    }
}

# Short-circuit
if (-not $ShowAllActive -and $channelSeq -le $lastRead) {
    # Update last_seen_utc on member entry for liveness signal
    try {
        Update-ChannelMember -Name $Channel -Root $channelsRoot -Alias $Alias -Patch @{
            last_seen_utc = $nowUtc.ToString('o')
        }
    } catch { }
    return [pscustomobject]@{
        status             = 'OK'
        channel            = $Channel
        unread_count       = 0
        messages           = @()
        context_gap_count  = $contextGaps.Count
        context_gaps       = @($contextGaps)
        exit_code          = 0
        message            = "No unread messages. channel_seq=$channelSeq, last_read=$lastRead."
    }
}

# Enumerate messages across threads
$threadsDir = Join-Path $channelDir 'threads'
$rendered = [System.Collections.ArrayList]::new()
$highestSeenSeq = $lastRead

if (Test-Path -LiteralPath $threadsDir) {
    foreach ($td in (Get-ChildItem -LiteralPath $threadsDir -Directory)) {
        $msgDir = Join-Path $td.FullName 'messages'
        if (-not (Test-Path -LiteralPath $msgDir)) { continue }

        $mFiles = @(Get-ChildItem -LiteralPath $msgDir -Filter '*.json' -File | Sort-Object Name)
        foreach ($mf in $mFiles) {
            $seq = 0
            if ($mf.BaseName -match '^(\d+)-') { $seq = [int]$Matches[1] }

            $unread = $seq -gt $lastRead
            if (-not $unread -and -not $ShowAllActive) { continue }

            try {
                $m = Read-AtomicJson -Path $mf.FullName
            } catch {
                [void]$contextGaps.Add([pscustomobject]@{
                    source = "threads/$($td.Name)/messages/$($mf.Name)"
                    status = 'unreadable'
                    impact = 'message skipped'
                })
                continue
            }

            # Post-read session-id verification
            $authorMember = Find-MemberByAlias -Channel $channelObj -Alias $m.from.alias
            $spoofFlag = $false
            if ($authorMember) {
                if ($authorMember.session_id -ne $m.from.session_id) {
                    $spoofFlag = $true
                }
            } else {
                # Author not in current members (left). Not a spoof per-se; annotate.
                $spoofFlag = $null
            }

            # Read-time Rule-1 scan (defense-in-depth)
            $scan = Test-LiteralPhraseScan -Text $m.body
            $readTimeSuspicious = $scan.Matched

            $render = [ordered]@{
                thread_id          = $td.Name
                seq                = $seq
                id                 = if ($m.PSObject.Properties['id']) { $m.id } else { '' }
                from_alias         = $m.from.alias
                type               = $m.type
                timestamp_utc      = $m.timestamp_utc
                body               = $m.body
                body_size_bytes    = if ($m.PSObject.Properties['body_size_bytes']) { $m.body_size_bytes } else { 0 }
                mentions           = @(if ($m.PSObject.Properties['mentions']) { $m.mentions } else { })
                suspicious_post    = if ($m.PSObject.Properties['suspicious']) { [bool]$m.suspicious } else { $false }
                suspicious_read    = $readTimeSuspicious
                spoof_flag         = $spoofFlag
                run_id             = if ($m.PSObject.Properties['run_id']) { $m.run_id } else { $null }
                unread             = $unread
                mentions_self      = if ($m.PSObject.Properties['mentions']) { @($m.mentions) -contains $Alias } else { $false }
            }
            [void]$rendered.Add([pscustomobject]$render)
            if ($seq -gt $highestSeenSeq) { $highestSeenSeq = $seq }
        }
    }
}

# Priority sort: mentions-self → suspicious → type-weighted → seq ascending
$typeOrder = @{ 'question' = 0; 'task' = 1; 'answer' = 2; 'status' = 3; 'fyi' = 4; 'resolve' = 5; 'triage-question' = 0; 'triage-context' = 1 }
$sorted = $rendered | Sort-Object `
    @{ Expression = { -[int]$_.mentions_self }; Ascending = $true },
    @{ Expression = { -[int]([bool]$_.suspicious_post -or [bool]$_.suspicious_read -or [bool]$_.spoof_flag) }; Ascending = $true },
    @{ Expression = { if ($typeOrder.ContainsKey($_.type)) { $typeOrder[$_.type] } else { 99 } }; Ascending = $true },
    @{ Expression = { [int]$_.seq }; Ascending = $true }

# Update read-marker to the highest seq we saw
if ($highestSeenSeq -gt $lastRead) {
    $updatedMarker = if ($marker) { $marker } else { [pscustomobject]@{ alias = $Alias; session_id = $SessionId; last_read_seq = 0 } }
    $updatedMarker | Add-Member -NotePropertyName 'last_read_seq' -NotePropertyValue $highestSeenSeq -Force
    $updatedMarker | Add-Member -NotePropertyName 'session_id' -NotePropertyValue $SessionId -Force
    $updatedMarker | Add-Member -NotePropertyName 'updated_utc' -NotePropertyValue $nowUtc.ToString('o') -Force
    try {
        New-Item -ItemType Directory -Path (Split-Path -Parent $markerPath) -Force | Out-Null
        Write-AtomicJson -Path $markerPath -Content $updatedMarker
    } catch {
        [void]$contextGaps.Add([pscustomobject]@{ source = 'read-marker.write'; status = 'failed'; impact = 'messages may re-display on next check' })
    }
}

# last_seen_utc bump
try {
    Update-ChannelMember -Name $Channel -Root $channelsRoot -Alias $Alias -Patch @{
        last_seen_utc = $nowUtc.ToString('o')
    }
} catch { }

$unreadCount = @($rendered | Where-Object { $_.unread }).Count
$exit = if ($contextGaps.Count -gt 0) { 1 } else { 0 }

return [pscustomobject]@{
    status             = 'OK'
    channel            = $Channel
    unread_count       = $unreadCount
    total_rendered     = @($rendered).Count
    messages           = @($sorted)
    context_gap_count  = $contextGaps.Count
    context_gaps       = @($contextGaps)
    channel_seq        = $channelSeq
    new_last_read_seq  = $highestSeenSeq
    exit_code          = $exit
    message            = "Rendered $unreadCount unread (total $(@($rendered).Count))."
}
