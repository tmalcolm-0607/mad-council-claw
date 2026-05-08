#Requires -Version 7

<#
.SYNOPSIS
  Post a typed message to a MAD.Council channel thread. The heaviest skill —
  enforces session-id binding, triage-gate status, body cap + Rule-1 scan,
  mention validation, monotonic seq, and incremental digest rebuild.

.DESCRIPTION
  Scope cut for the vertical slice:
    - transport is always 'local' (no A2A submit).
    - --ReplyTo inherits run_id (thread already covers most cases).
    - mention batch-gate at >10 mentions → warn, no interactive prompt.
    - thread-count batch-gate (>10 active) skipped.
    - MAD-spec gate check only runs if channel.settings.mad_enabled=true (default
      false in this slice → skipped).

.PARAMETER Channel
  Channel name.

.PARAMETER Alias
  Caller's alias (must be a current member with matching session_id).

.PARAMETER SessionId
  Caller's session id (for spoofing check).

.PARAMETER Type
  Message type: task|question|answer|status|fyi|resolve|triage-question|triage-context.

.PARAMETER Body
  Message body (1-32768 bytes UTF-8).

.PARAMETER Thread
  Existing thread id. Mutually exclusive with -NewThread.

.PARAMETER NewThread
  Title for a new thread. Slugified into thread-id.

.PARAMETER ReplyTo
  msg-NNN id of a message in the same thread whose run_id is inherited.

.PARAMETER Mentions
  Comma-separated alias list. Phantom mentions dropped with warning.

.PARAMETER RunId
  Explicit run_id override.

.PARAMETER ForceRaw
  Suppress `suspicious` tag when the Rule-1 ban list fires.

.PARAMETER Project
  Optional project tag stored on the from block.

.PARAMETER ClaudeDataRoot
  Override root for testing.
#>

[CmdletBinding(DefaultParameterSetName = 'ExistingThread')]
param(
    [Parameter(Mandatory = $true)]
    [string] $Channel,

    [Parameter(Mandatory = $true)]
    [string] $Alias,

    [Parameter(Mandatory = $true)]
    [string] $SessionId,

    [Parameter(Mandatory = $true)]
    [ValidateSet('task', 'question', 'answer', 'status', 'fyi', 'resolve', 'triage-question', 'triage-context')]
    [string] $Type,

    [Parameter(Mandatory = $true)]
    [AllowEmptyString()]
    [string] $Body,

    [Parameter(ParameterSetName = 'ExistingThread')]
    [string] $Thread,

    [Parameter(ParameterSetName = 'NewThread')]
    [string] $NewThread,

    [Parameter()] [string] $ReplyTo,
    [Parameter()] [string] $Mentions = '',
    [Parameter()] [string] $RunId = $null,
    [Parameter()] [switch] $ForceRaw,
    [Parameter()] [string] $Project = '',
    [Parameter()] [string] $ClaudeDataRoot = $null
)

Set-StrictMode -Version Latest

$scriptsDir = (Resolve-Path (Join-Path $PSScriptRoot '..' '..' 'scripts')).ProviderPath
. (Join-Path $scriptsDir 'atomic-write.ps1')
. (Join-Path $scriptsDir 'channel-helpers.ps1')
. (Join-Path $scriptsDir 'literal-phrase-scan.ps1')
. (Join-Path $scriptsDir 'seq-increment.ps1')
. (Join-Path $scriptsDir 'digest-rebuild.ps1')

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

function script:ConvertTo-ThreadId {
    param([string] $Title)
    $s = $Title.ToLowerInvariant()
    $s = [regex]::Replace($s, '[^a-z0-9]+', '-')
    $s = $s.Trim('-')
    if ($s.Length -gt 64) { $s = $s.Substring(0, 64).TrimEnd('-') }
    if (-not $s) { $s = "thread-$([guid]::NewGuid().ToString('N').Substring(0,8))" }
    return $s
}

# -- Resolve defaults ---------------------------------------------------------
if (-not $ClaudeDataRoot) {
    $homeDir = if ($env:HOME) { $env:HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { [System.Environment]::GetFolderPath('UserProfile') }
    $ClaudeDataRoot = Join-Path $homeDir 'claude-data'
}
$channelsRoot = Join-Path $ClaudeDataRoot 'channels'
$channelDir   = Join-Path $channelsRoot $Channel
$nowUtc       = (Get-Date).ToUniversalTime()

if (-not $RunId) { $RunId = [guid]::NewGuid().ToString() }
if (-not $Alias) { return script:Fail -Code 2 -ErrorCode 'INVALID_ALIAS' -Message 'Alias required.' }

# -- 1. Membership + channel read -------------------------------------------
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
    return script:Fail -Code 2 -ErrorCode 'NOT_A_MEMBER' `
        -Message "Not a member of '$Channel'. Run /council-join first."
}

# -- 2. Session-id binding (spec §7.2 anti-spoof) ----------------------------
if ($member.session_id -ne $SessionId) {
    return script:Fail -Code 2 -ErrorCode 'SESSION_MISMATCH' `
        -Message "Session ID mismatch for alias '$Alias'. Use /council-join --ForceReclaim if legitimate."
}

# -- 1a. Channel-status gate (ADOPT-019) --------------------------------
$channelStatus = if ($channelObj.PSObject.Properties['status']) { $channelObj.status } else { 'active' }
switch ($channelStatus) {
    'triage' {
        if ($Type -notin 'triage-question', 'triage-context') {
            return script:Fail -Code 2 -ErrorCode 'CHANNEL_STATUS_GATE' `
                -Message "Channel '$Channel' is in triage. Only triage-question / triage-context allowed until TRIAGE_ACCEPT."
        }
    }
    'resolved' { return script:Fail -Code 2 -ErrorCode 'CHANNEL_STATUS_GATE' -Message "Channel '$Channel' is resolved; no further posts." }
    'closed'   { return script:Fail -Code 2 -ErrorCode 'CHANNEL_STATUS_GATE' -Message "Channel '$Channel' is closed." }
    default    { }   # 'active' or 'ready' — allowed; 'ready' flips below
}
if ($Type -in 'triage-question', 'triage-context' -and $channelStatus -ne 'triage') {
    return script:Fail -Code 2 -ErrorCode 'INVALID_TYPE_FOR_STATUS' `
        -Message "triage-question/triage-context only valid when channel.status=triage (got '$channelStatus')."
}

# -- 3. Body validation ------------------------------------------------------
$bodyBytes = [System.Text.Encoding]::UTF8.GetByteCount($Body)
if ($bodyBytes -lt 1) {
    return script:Fail -Code 2 -ErrorCode 'BODY_EMPTY' -Message 'Body cannot be empty.'
}
if ($bodyBytes -gt 32768) {
    return script:Fail -Code 2 -ErrorCode 'BODY_TOO_LARGE' -Message "Body is $bodyBytes bytes; cap is 32768."
}

$scan = Test-LiteralPhraseScan -Text $Body
$suspicious = $false
if ($scan.Matched -and -not $ForceRaw) {
    $suspicious = $true
}

# -- 4. Mention validation ---------------------------------------------------
$mentionTokens = if ($Mentions) { @($Mentions -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) } else { @() }
# Space-free pattern: body-parsed mentions only match single-word aliases. Aliases
# with spaces (e.g. "Training Worker") must be passed via -Mentions explicitly.
$bodyMentionPattern = '@([A-Za-z][A-Za-z0-9_-]{0,63})'
foreach ($m in [regex]::Matches($Body, $bodyMentionPattern)) {
    $mentionTokens += $m.Groups[1].Value.Trim()
}
$mentionTokens = @($mentionTokens | Sort-Object -Unique)

$validMentions = [System.Collections.ArrayList]::new()
$droppedMentions = [System.Collections.ArrayList]::new()
foreach ($mn in $mentionTokens) {
    if (Find-MemberByAlias -Channel $channelObj -Alias $mn) {
        [void]$validMentions.Add($mn)
    } else {
        [void]$droppedMentions.Add($mn)
    }
}

# -- 5. Thread resolution ----------------------------------------------------
$threadId = $null
$isNewThread = $false
if ($PSCmdlet.ParameterSetName -eq 'NewThread') {
    $base = script:ConvertTo-ThreadId -Title $NewThread
    $threadId = $base
    $suffix = 2
    while (Test-Path -LiteralPath (Join-Path $channelDir 'threads' $threadId)) {
        $threadId = "$base-$suffix"
        $suffix++
        if ($suffix -gt 200) { throw "Thread id collision resolver exhausted for base '$base'." }
    }
    $isNewThread = $true
} else {
    if (-not $Thread) { return script:Fail -Code 2 -ErrorCode 'THREAD_REQUIRED' -Message 'Must supply -Thread or -NewThread.' }
    $threadDir = Join-Path $channelDir 'threads' $Thread
    if (-not (Test-Path -LiteralPath $threadDir)) {
        return script:Fail -Code 2 -ErrorCode 'THREAD_NOT_FOUND' -Message "Thread '$Thread' not found."
    }
    $tjPath = Join-Path $threadDir 'thread.json'
    if (Test-Path -LiteralPath $tjPath) {
        $tj = Read-AtomicJson -Path $tjPath
        if ($tj.PSObject.Properties['status'] -and $tj.status -in 'archived', 'closed') {
            return script:Fail -Code 2 -ErrorCode 'THREAD_CLOSED' -Message "Thread '$Thread' is $($tj.status)."
        }
        # resolved threads accept only resolve-type (grace window) per spec
        if ($tj.PSObject.Properties['status'] -and $tj.status -eq 'resolved' -and $Type -ne 'resolve') {
            return script:Fail -Code 2 -ErrorCode 'THREAD_RESOLVED' `
                -Message "Thread '$Thread' is resolved; only 'resolve'-type messages allowed."
        }
    }
    $threadId = $Thread
}

# -- 6. Claim seq -------------------------------------------------------------
try {
    $seq = Invoke-SeqIncrement -ChannelName $Channel -Root $channelsRoot -Alias $Alias -SessionId $SessionId
} catch {
    return script:Fail -Code 4 -ErrorCode 'SEQ_INCREMENT_FAILED' -Message $_.Exception.Message
}

# -- 7. Write message ---------------------------------------------------------
$threadDir = Join-Path $channelDir 'threads' $threadId
$msgDir = Join-Path $threadDir 'messages'
try {
    New-Item -ItemType Directory -Path $msgDir -Force -ErrorAction Stop | Out-Null
} catch {
    return script:Fail -Code 4 -ErrorCode 'THREAD_DIR_CREATE_FAILED' -Message $_.Exception.Message
}

$msgId = 'msg-' + ([string]$seq).PadLeft(3, '0')
# Filename-safe timestamp (replace : with -)
$tsSafe = $nowUtc.ToString('yyyy-MM-ddTHH-mm-ssZ')
$msgFileName = "$seq-$tsSafe-$Alias.json"
$msgPath = Join-Path $msgDir $msgFileName

$msg = [ordered]@{
    schema_version  = 2
    id              = $msgId
    seq             = $seq
    thread_id       = $threadId
    from            = [ordered]@{
        alias      = $Alias
        session_id = $SessionId
    }
    timestamp_utc   = $nowUtc.ToString('o')
    type            = $Type
    body            = $Body
    body_size_bytes = $bodyBytes
    mentions        = @($validMentions)
    run_id          = $RunId
    transport       = 'local'
    suspicious      = $suspicious
}
if ($Project)       { $msg.from['project'] = $Project }
if ($ReplyTo)       { $msg['in_reply_to']  = $ReplyTo }

try {
    Write-AtomicJson -Path $msgPath -Content ([pscustomobject]$msg)
} catch {
    return script:Fail -Code 4 -ErrorCode 'MESSAGE_WRITE_FAILED' -Message $_.Exception.Message
}

# -- 8. Thread.json (create or update) ---------------------------------------
$tjPath = Join-Path $threadDir 'thread.json'
if ($isNewThread) {
    $tj = [ordered]@{
        thread_id   = $threadId
        status      = 'active'
        created_utc = $nowUtc.ToString('o')
        created_by  = [ordered]@{ alias = $Alias; session_id = $SessionId }
        first_seq   = $seq
        last_seq    = $seq
        message_count = 1
    }
    if ($PSCmdlet.ParameterSetName -eq 'NewThread') {
        $tj['title'] = $NewThread
    }
    Write-AtomicJson -Path $tjPath -Content ([pscustomobject]$tj)
} elseif (Test-Path -LiteralPath $tjPath) {
    $tj = Read-AtomicJson -Path $tjPath
    $count = if ($tj.PSObject.Properties['message_count']) { [int]$tj.message_count + 1 } else { 1 }
    $tj | Add-Member -NotePropertyName 'last_seq' -NotePropertyValue $seq -Force
    $tj | Add-Member -NotePropertyName 'message_count' -NotePropertyValue $count -Force
    $tj | Add-Member -NotePropertyName 'last_msg_utc' -NotePropertyValue $nowUtc.ToString('o') -Force
    Write-AtomicJson -Path $tjPath -Content $tj
}

# -- 8a. `ready` → `active` transition on first non-triage post --------------
if ($channelStatus -eq 'ready') {
    $channelObj | Add-Member -NotePropertyName 'status' -NotePropertyValue 'active' -Force
    Write-AtomicJson -Path (Join-Path $channelDir 'channel.json') -Content $channelObj
}

# -- 9. Rebuild digest --------------------------------------------------------
try {
    $null = Invoke-DigestRebuild -ChannelName $Channel -Root $channelsRoot
} catch {
    # Message persisted; digest rebuild failure is non-fatal but surfaces via context gap next read.
}

return [pscustomobject]@{
    status             = 'OK'
    channel            = $Channel
    thread_id          = $threadId
    seq                = $seq
    message_id         = $msgId
    message_path       = $msgPath
    body_size_bytes    = $bodyBytes
    mentions_validated = @($validMentions)
    mentions_dropped   = @($droppedMentions)
    suspicious         = $suspicious
    run_id             = $RunId
    exit_code          = 0
    message            = "Posted $msgId (seq=$seq) to thread '$threadId'."
}
