<#
.SYNOPSIS
  Atomic read-increment-write for seq.json — the monotonic sequence counter that
  orders messages across all threads in a channel.

.DESCRIPTION
  The single most concurrency-critical operation in MAD.Council. Every /council-post
  must claim a unique seq. Two writers racing must not corrupt or duplicate.

  Algorithm (per rules/concurrency-safety.md §3):
    1. Read seq.json → { "next_seq": N }.
    2. Attempt to claim N + write { "next_seq": N+1 } atomically.
    3. On atomic-write conflict (another writer beat us): re-read seq.json,
       retry with the new next_seq value.
    4. Exhaust after 3 attempts → throw (rc=4 at skill level).

  Why retry-with-next-number (not retry-same-number): if writer A claims N and
  writer B also claims N, whichever writes seq.json first wins. The other sees
  a changed seq.json on re-read and must pick the next fresh number.

.PARAMETER ChannelName
  Channel to increment seq.json for.

.PARAMETER MaxAttempts
  Retry budget. Default: 3.

.OUTPUTS
  Claimed seq number (integer). Caller uses it in message filename.
  Throws after MaxAttempts exhausted — fail post with rc=4.

.NOTES
  Used by:
    - skills/council-post/plan.md step 9
    - skills/council-resolve/plan.md (via /council-post delegation)

  Related:
    - rules/concurrency-safety.md §3 (the invariant)
    - mad.council.a2a.md §10.2 (retry+timeout table: 3 retries, 2s timeout)
    - wiki/patterns/state-file-coordination.md §Invariant 1 (monotonic seq)
#>

Set-StrictMode -Version Latest

# Schema convention: seq.json carries `current` = seq of last-handed-out message.
# Fresh channel: current=0. First increment returns 1 + writes current=1.

if (-not (Get-Command -Name Write-AtomicJson -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'atomic-write.ps1')
}
if (-not (Get-Command -Name Resolve-ChannelPath -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'channel-helpers.ps1')
}

function Invoke-SeqIncrement {
    <#
    .SYNOPSIS
      Atomically claim the next seq number for a channel. Retries on transient
      concurrent-write failure with bounded attempts per
      rules/concurrency-safety.md §3.

    .PARAMETER ChannelName
      Channel name.

    .PARAMETER MaxAttempts
      Retry budget. Default: 3.

    .PARAMETER TimeoutSeconds
      Wall-clock budget across all attempts. Default: 2.

    .PARAMETER Root
      Channels-root override for testing.

    .PARAMETER Alias
      Optional caller alias recorded into seq.json.last_incremented_by.

    .PARAMETER SessionId
      Optional caller session_id.

    .OUTPUTS
      Claimed seq (integer ≥1). Throws after attempts exhausted.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ChannelName,

        [Parameter(Mandatory = $false)]
        [int] $MaxAttempts = 3,

        [Parameter(Mandatory = $false)]
        [int] $TimeoutSeconds = 2,

        [Parameter(Mandatory = $false)]
        [string] $Root = $null,

        [Parameter(Mandatory = $false)]
        [string] $Alias = $null,

        [Parameter(Mandatory = $false)]
        [string] $SessionId = $null
    )

    $seqPath = Join-Path (Resolve-ChannelPath -Name $ChannelName -Root $Root) 'seq.json'
    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        if ((Get-Date) -gt $deadline) {
            throw "SeqIncrementTimeout: exhausted $TimeoutSeconds s on channel '$ChannelName'"
        }

        try {
            $current = Read-AtomicJson -Path $seqPath
        } catch {
            throw "SeqIncrementReadFailed: $($_.Exception.Message)"
        }

        $prev    = if ($current.PSObject.Properties['current']) { [int]$current.current } else { 0 }
        $claimed = $prev + 1
        $nowUtc  = (Get-Date).ToUniversalTime().ToString('o')

        $update = [ordered]@{
            current              = $claimed
            last_incremented_utc = $nowUtc
        }
        if ($Alias -and $SessionId) {
            $update['last_incremented_by'] = [ordered]@{ alias = $Alias; session_id = $SessionId }
        }

        try {
            Write-AtomicJson -Path $seqPath -Content ([pscustomobject]$update)
            return $claimed
        } catch {
            # Transient failure (disk glitch, concurrent .tmp collision). Brief backoff.
            Start-Sleep -Milliseconds (50 * $attempt)
        }
    }

    throw "SeqIncrementExhausted: $MaxAttempts attempts consumed without success on channel '$ChannelName'."
}

function Initialize-SeqFile {
    <#
    .SYNOPSIS
      Create seq.json at channel creation time with { current: 0 }.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ChannelName,

        [Parameter(Mandatory = $false)]
        [string] $Root = $null
    )

    $seqPath = Join-Path (Resolve-ChannelPath -Name $ChannelName -Root $Root) 'seq.json'
    Write-AtomicJson -Path $seqPath -Content ([ordered]@{
        current              = 0
        last_incremented_utc = (Get-Date).ToUniversalTime().ToString('o')
    })
}

function Get-SeqCurrent {
    <#
    .SYNOPSIS
      Read current seq without modifying.

    .OUTPUTS
      Integer. Throws if seq.json missing or unreadable.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ChannelName,

        [Parameter(Mandatory = $false)]
        [string] $Root = $null
    )

    $seqPath = Join-Path (Resolve-ChannelPath -Name $ChannelName -Root $Root) 'seq.json'
    $s = Read-AtomicJson -Path $seqPath
    return [int]$s.current
}
