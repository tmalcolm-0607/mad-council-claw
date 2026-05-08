<#
.SYNOPSIS
  Recompute digest.json from the channel's current state (threads + messages +
  verdicts + MAD artifacts). Called after every message post, every thread
  resolution, and every verdict issuance.

.DESCRIPTION
  digest.json is the <2KB "polling target" — the cheap read that /council-check
  uses to decide if anything changed. It summarizes active threads, recent
  resolutions, stats, MAD state, and Context Gaps.

  This script scans thread directories and rebuilds digest.json atomically.
  Called synchronously from /council-post after message write succeeds, so it's
  on the critical path — should complete in <500ms for channels <100 threads.

.NOTES
  Used by:
    - skills/council-post/plan.md step 12 (incremental mode: just the touched thread)
    - skills/council-leave/plan.md (full rebuild after member leaves)
    - skills/council-review/plan.md step 11 (after verdict written, update mad_state + council_open)
    - CronCreate polling does NOT call this — readers just read the existing digest.

  Invariants the digest enforces:
    - channel_seq = max seq across all messages.
    - threads[] = per-thread summary with status (active|stale|resolved|archived).
    - total_messages = sum of message_count across all threads.
    - context_gaps[] = accumulated from this rebuild (any unreadable thread/message).

  Incremental mode is deferred to Phase-1 full scope; always runs full here.
  Full-rebuild is the safety net for correctness.
#>

Set-StrictMode -Version Latest

if (-not (Get-Command -Name Write-AtomicJson -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'atomic-write.ps1')
}
if (-not (Get-Command -Name Resolve-ChannelPath -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'channel-helpers.ps1')
}

# Stale threshold per spec §7.4 — 24h no message → stale.
$script:StaleHours = 24

function Invoke-DigestRebuild {
    <#
    .SYNOPSIS
      Full rebuild of digest.json from disk state.

    .DESCRIPTION
      Scans threads/<id>/ directories, reads thread.json when present, counts
      message files + computes max-seq from filenames (<seq>-<ts>-<alias>.json),
      partitions threads by status, populates context_gaps for any unreadable
      thread. Writes atomically.

    .PARAMETER ChannelName
      Channel to rebuild digest for.

    .PARAMETER IncrementalMode
      Reserved; currently always runs full rebuild.

    .PARAMETER ChangedThreadId
      Reserved; currently ignored.

    .PARAMETER Root
      Channels-root override for testing.

    .OUTPUTS
      The rebuilt digest object (also persisted on disk).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ChannelName,

        [Parameter(Mandatory = $false)]
        [switch] $IncrementalMode,

        [Parameter(Mandatory = $false)]
        [string] $ChangedThreadId,

        [Parameter(Mandatory = $false)]
        [string] $Root = $null
    )

    $channelDir = Resolve-ChannelPath -Name $ChannelName -Root $Root
    $threadsDir = Join-Path $channelDir 'threads'
    $digestPath = Join-Path $channelDir 'digest.json'
    $nowUtc     = (Get-Date).ToUniversalTime()
    $staleCutoff = $nowUtc.AddHours(-$script:StaleHours)

    $threadRows = [System.Collections.ArrayList]::new()
    $contextGaps = [System.Collections.ArrayList]::new()
    $totalMessages = 0
    $channelSeq = 0

    if (Test-Path -LiteralPath $threadsDir) {
        $threadDirs = @(Get-ChildItem -LiteralPath $threadsDir -Directory -ErrorAction SilentlyContinue)
        foreach ($td in $threadDirs) {
            $threadId = $td.Name
            $threadJsonPath = Join-Path $td.FullName 'thread.json'
            $thread = $null
            if (Test-Path -LiteralPath $threadJsonPath) {
                try {
                    $thread = Read-AtomicJson -Path $threadJsonPath
                } catch {
                    [void]$contextGaps.Add([pscustomobject]@{
                        source = "threads/$threadId/thread.json"
                        status = 'unreadable'
                        impact = "thread '$threadId' skipped; re-post to rebuild"
                    })
                    continue
                }
            }

            $messagesDir = Join-Path $td.FullName 'messages'
            $msgFiles = @()
            if (Test-Path -LiteralPath $messagesDir) {
                $msgFiles = @(Get-ChildItem -LiteralPath $messagesDir -Filter '*.json' -File -ErrorAction SilentlyContinue)
            }
            $messageCount = $msgFiles.Count
            $totalMessages += $messageCount

            # Max seq from filenames: `<seq>-<timestamp>-<alias>.json`
            $maxSeq = 0
            $maxMsgUtc = $null
            foreach ($mf in $msgFiles) {
                if ($mf.BaseName -match '^(\d+)-') {
                    $s = [int]$Matches[1]
                    if ($s -gt $maxSeq) { $maxSeq = $s }
                }
                if (-not $maxMsgUtc -or $mf.LastWriteTimeUtc -gt $maxMsgUtc) {
                    $maxMsgUtc = $mf.LastWriteTimeUtc
                }
            }
            if ($maxSeq -gt $channelSeq) { $channelSeq = $maxSeq }

            # Effective status — honor thread.json; promote active→stale if quiet for >24h
            $status = if ($thread -and $thread.PSObject.Properties['status']) { $thread.status } else { 'active' }
            if ($status -eq 'active' -and $maxMsgUtc -and $maxMsgUtc -lt $staleCutoff) {
                $status = 'stale'
            }

            $row = [ordered]@{
                thread_id     = $threadId
                status        = $status
                last_msg_seq  = $maxSeq
                message_count = $messageCount
            }
            if ($maxMsgUtc) {
                $row['last_msg_utc'] = $maxMsgUtc.ToString('o')
            }
            if ($thread -and $thread.PSObject.Properties['verdict_ref']) {
                $row['verdict_ref'] = $thread.verdict_ref
            }
            [void]$threadRows.Add([pscustomobject]$row)
        }
    }

    $digest = [ordered]@{
        channel_seq    = $channelSeq
        rebuilt_utc    = $nowUtc.ToString('o')
        total_messages = $totalMessages
        threads        = @($threadRows)
    }
    if ($contextGaps.Count -gt 0) {
        $digest['context_gaps'] = @($contextGaps)
    }

    Write-AtomicJson -Path $digestPath -Content ([pscustomobject]$digest)
    return [pscustomobject]$digest
}

function Get-DigestPayload {
    <#
    .SYNOPSIS
      Read digest.json and return it.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ChannelName,

        [Parameter(Mandatory = $false)]
        [string] $Root = $null
    )
    $p = Join-Path (Resolve-ChannelPath -Name $ChannelName -Root $Root) 'digest.json'
    return Read-AtomicJson -Path $p
}

function Initialize-DigestFile {
    <#
    .SYNOPSIS
      Create digest.json at channel creation time with zero-state structure.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $ChannelName,

        [Parameter(Mandatory = $false)]
        [bool] $MadEnabled = $false,

        [Parameter(Mandatory = $false)]
        [string] $Root = $null
    )

    $p = Join-Path (Resolve-ChannelPath -Name $ChannelName -Root $Root) 'digest.json'
    $d = [ordered]@{
        channel_seq    = 0
        rebuilt_utc    = (Get-Date).ToUniversalTime().ToString('o')
        total_messages = 0
        threads        = @()
    }
    if ($MadEnabled) {
        $d['mad_state'] = [ordered]@{ phase = 'spec-drafting'; gate_status = 'pending' }
    }
    Write-AtomicJson -Path $p -Content ([pscustomobject]$d)
}
