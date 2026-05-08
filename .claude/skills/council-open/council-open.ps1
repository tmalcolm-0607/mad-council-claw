#Requires -Version 7

<#
.SYNOPSIS
  Create a new MAD.Council channel with single owner + environment tier,
  optionally at triage status. Executable body for the /council-open skill.

.DESCRIPTION
  First executable skill in the vertical slice. Implements the spec per:
    - skills/council-open/SKILL.md        (behavior contract)
    - skills/council-open/plan.md          (step-by-step)
    - operations/dry-run-happy-path.md §Step 1
    - rules/single-owner-accountability.md (ADOPT-001)
    - rules/triage-gate.md                 (ADOPT-002)
    - operations/environment-tiers.md      (ADOPT-004)

  Produces a schema-valid channel.json + seq.json + digest.json + .sessions.json
  update. All writes go through atomic-write.ps1.

.PARAMETER Name
  Channel name. Lowercase, alphanumeric + hyphens, 1-64 chars.

.PARAMETER Purpose
  Human-readable purpose (1-500 chars). Scanned against literal-phrase ban list.

.PARAMETER Tier
  Environment tier: local | ci | prod.

.PARAMETER Alias
  The opener's alias — becomes the first (and only, in this slice) member.

.PARAMETER SessionId
  The opener's Claude Code session id. Bound to alias per spec §7.2.

.PARAMETER Owner
  Owner alias. Defaults to $Alias. Must match the sole member in this slice.

.PARAMETER Triage
  Open the channel at status: triage. Requires -AcceptanceCriteria.

.PARAMETER AcceptanceCriteria
  Required when -Triage. 10-2000 chars. Scanned against ban list.

.PARAMETER EffortEstimate
  Optional hours estimate.

.PARAMETER Project
  Optional project identifier stored in the member record.

.PARAMETER ClaudeDataRoot
  Override root. Default $HOME/claude-data. Used by tests.

.PARAMETER RunId
  Optional GUID for created_with_run_id. Auto-generated if omitted.

.OUTPUTS
  Completion object with keys: status (OK/Failed), channel (name), tier, owner,
  run_id, error_code (on failure), message.

  Exit codes (when invoked as script):
    0 — success
    1 — validation error (args, purpose size, etc.)
    2 — TRIAGE_MISSING_CRITERIA
    3 — PROD_TRIAGE_REQUIRED
    4 — preflight failed (root not writable, etc.)
    5 — channel already exists
    6 — literal-phrase ban hit (suspicious purpose or acceptance-criteria)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string] $Name,

    [Parameter(Mandatory = $true)]
    [string] $Purpose,

    [Parameter(Mandatory = $true)]
    [ValidateSet('local', 'ci', 'prod')]
    [string] $Tier,

    [Parameter(Mandatory = $true)]
    [string] $Alias,

    [Parameter(Mandatory = $true)]
    [string] $SessionId,

    [Parameter(Mandatory = $false)]
    [string] $Owner = $null,

    [Parameter(Mandatory = $false)]
    [switch] $Triage,

    [Parameter(Mandatory = $false)]
    [string] $AcceptanceCriteria,

    [Parameter(Mandatory = $false)]
    [double] $EffortEstimate,

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
. (Join-Path $scriptsDir 'literal-phrase-scan.ps1')
. (Join-Path $scriptsDir 'preflight.ps1')

function script:Fail {
    param([int] $Code, [string] $ErrorCode, [string] $Message)
    return [pscustomobject]@{
        status     = 'Failed'
        channel    = $Name
        tier       = $Tier
        owner      = $Owner
        run_id     = $RunId
        exit_code  = $Code
        error_code = $ErrorCode
        message    = $Message
    }
}

# -- Resolve defaults ---------------------------------------------------------
if (-not $Owner) { $Owner = $Alias }
if (-not $RunId) { $RunId = [guid]::NewGuid().ToString() }
if (-not $ClaudeDataRoot) {
    $homeDir = if ($env:HOME) { $env:HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { [System.Environment]::GetFolderPath('UserProfile') }
    $ClaudeDataRoot = Join-Path $homeDir 'claude-data'
}
$ChannelsRoot = Join-Path $ClaudeDataRoot 'channels'
$nowUtc = (Get-Date).ToUniversalTime().ToString('o')

# -- 1. Validate args ---------------------------------------------------------
if ($Name -cnotmatch '^[a-z0-9][a-z0-9-]{0,63}$') {
    return script:Fail -Code 1 -ErrorCode 'INVALID_CHANNEL_NAME' -Message "Channel name must match ^[a-z0-9][a-z0-9-]{0,63}$ (got '$Name')."
}
if ($Purpose.Length -lt 1 -or $Purpose.Length -gt 500) {
    return script:Fail -Code 1 -ErrorCode 'INVALID_PURPOSE_LENGTH' -Message "Purpose must be 1-500 chars (got $($Purpose.Length))."
}
if ($Alias.Length -lt 1 -or $Alias.Length -gt 64) {
    return script:Fail -Code 1 -ErrorCode 'INVALID_ALIAS_LENGTH' -Message "Alias must be 1-64 chars (got $($Alias.Length))."
}
if ($Owner -ne $Alias) {
    # In the vertical slice, the opener IS the sole member. --Owner X only accepted
    # if X is the creator's alias. Multi-member opens defer to Phase 1 full scope.
    return script:Fail -Code 1 -ErrorCode 'OWNER_MUST_BE_CREATOR' -Message "Owner '$Owner' must match the creator's alias '$Alias' in vertical slice; multi-opener deferred to Phase 1 full."
}

# -- 2. ADOPT-002 triage gate -------------------------------------------
if ($Tier -eq 'prod' -and -not $Triage) {
    return script:Fail -Code 3 -ErrorCode 'PROD_TRIAGE_REQUIRED' -Message 'prod-tier channels MUST be opened with --Triage (ADOPT-002).'
}
if ($Triage) {
    if (-not $AcceptanceCriteria -or $AcceptanceCriteria.Length -lt 10 -or $AcceptanceCriteria.Length -gt 2000) {
        return script:Fail -Code 2 -ErrorCode 'TRIAGE_MISSING_CRITERIA' -Message '--Triage requires -AcceptanceCriteria (10-2000 chars) per ADOPT-002.'
    }
}

# -- 3. Literal-phrase scan --------------------------------------------------
$purposeScan = Test-LiteralPhraseScan -Text $Purpose
if ($purposeScan.Matched) {
    return script:Fail -Code 6 -ErrorCode 'SUSPICIOUS_PURPOSE' -Message "Purpose tripped ban-list: $(@($purposeScan.Matches)[0].phrase). See rules/prompt-injection-policy.md."
}
if ($Triage) {
    $critScan = Test-LiteralPhraseScan -Text $AcceptanceCriteria
    if ($critScan.Matched) {
        return script:Fail -Code 6 -ErrorCode 'SUSPICIOUS_ACCEPTANCE_CRITERIA' -Message "AcceptanceCriteria tripped ban-list: $(@($critScan.Matches)[0].phrase)."
    }
}

# -- 4. Preflight ------------------------------------------------------------
$pf = Invoke-Preflight -Context council-open -ClaudeDataRoot $ClaudeDataRoot
if ($pf.Status -eq 'Fail') {
    return script:Fail -Code 4 -ErrorCode 'PREFLIGHT_FAILED' -Message "Preflight Fail: $($pf.Report)"
}

# -- 5. Channel-doesn't-already-exist check ----------------------------------
$channelDir = Join-Path $ChannelsRoot $Name
if (Test-Path -LiteralPath $channelDir) {
    return script:Fail -Code 5 -ErrorCode 'CHANNEL_ALREADY_EXISTS' -Message "Channel directory already exists: $channelDir"
}

# -- 6. Compose channel.json -------------------------------------------------
$status = if ($Triage) { 'triage' } else { 'active' }
$member = [ordered]@{
    alias         = $Alias
    session_id    = $SessionId
    joined_utc    = $nowUtc
    status        = 'active'
    last_seen_utc = $nowUtc
}
if ($Project) { $member['project'] = $Project }

$channel = [ordered]@{
    schema_version     = 2
    name               = $Name
    purpose            = $Purpose
    created_utc        = $nowUtc
    created_with_run_id = $RunId
    owner_alias        = $Owner
    environment_tier   = $Tier
    status             = $status
    members            = @([pscustomobject]$member)
    settings           = [ordered]@{
        mad_enabled = $false
        a2a_enabled = $false
    }
}
if ($Triage) {
    $channel['acceptance_criteria'] = $AcceptanceCriteria
    if ($PSBoundParameters.ContainsKey('EffortEstimate')) {
        $channel['effort_estimate_hours'] = [double]$EffortEstimate
    }
}

# -- 7. Materialize ----------------------------------------------------------
try {
    New-Item -ItemType Directory -Path $channelDir -Force -ErrorAction Stop | Out-Null
    Write-AtomicJson -Path (Join-Path $channelDir 'channel.json') -Content ([pscustomobject]$channel)
    Write-AtomicJson -Path (Join-Path $channelDir 'seq.json')     -Content ([ordered]@{
        current               = 0
        last_incremented_utc  = $nowUtc
        last_incremented_by   = [ordered]@{ alias = $Alias; session_id = $SessionId }
    })
    Write-AtomicJson -Path (Join-Path $channelDir 'digest.json')  -Content ([ordered]@{
        channel_seq    = 0
        rebuilt_utc    = $nowUtc
        total_messages = 0
        threads        = @()
    })
    New-Item -ItemType Directory -Path (Join-Path $channelDir 'threads')      -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $channelDir 'read-markers') -Force | Out-Null

    Update-SessionRegistry -Root $ClaudeDataRoot -SessionId $SessionId -ChannelName $Name -Alias $Alias -Action Add
} catch {
    # Best-effort rollback: clean up a partially-created channel dir so the operator
    # can retry cleanly.
    if (Test-Path -LiteralPath $channelDir) {
        Remove-Item -Recurse -Force -LiteralPath $channelDir -ErrorAction SilentlyContinue
    }
    return script:Fail -Code 1 -ErrorCode 'MATERIALIZE_FAILED' -Message "Failed to materialize channel: $($_.Exception.Message)"
}

return [pscustomobject]@{
    status    = 'OK'
    channel   = $Name
    tier      = $Tier
    owner     = $Owner
    run_id    = $RunId
    exit_code = 0
    message   = "Channel '$Name' created at status '$status' under tier '$Tier'."
}
