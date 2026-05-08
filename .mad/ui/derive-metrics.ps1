#Requires -Version 7
<#
.SYNOPSIS
  Walk `~/claude-data/channels/` and derive aggregated metrics for the UI.
  Phase-1c Day 3 deliverable per `plans/phase-1c-local-ui.md`.

.DESCRIPTION
  Pure read-only scan. No schema validation — that's `scripts/validate-schemas.ps1`.
  Returns an object suitable for `ConvertTo-Json -Depth 6`.

  Output shape:
    {
      scanned_utc,
      root,
      channels:    { total, by_tier: {...}, by_status: {...}, active_members_total },
      threads:     { total, with_verdict, without_verdict, by_status: {...} },
      messages:    { total, suspicious_count, types: {...} },
      verdicts:    { total, by_verdict: {...} },
      unread_histogram: { '0': N, '1-5': N, '6-20': N, '21+': N },
      dogfood:     { channel: 'mad-self-hosting'|null, acceptance_met_bool, verdicts_count }
    }

  The UI's `/api/metrics` route wraps this.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string] $Root = $null
)

Set-StrictMode -Version Latest

if (-not $Root) {
    $homeDir = if ($env:HOME) { $env:HOME } elseif ($env:USERPROFILE) { $env:USERPROFILE } else { [System.Environment]::GetFolderPath('UserProfile') }
    $Root = Join-Path $homeDir 'claude-data'
}

function Get-MadMetrics {
    [CmdletBinding()]
    param([string] $Root)

    $scannedUtc = (Get-Date).ToUniversalTime().ToString('o')
    $channelsDir = Join-Path $Root 'channels'

    $out = [ordered]@{
        scanned_utc = $scannedUtc
        root        = $Root
        channels    = [ordered]@{
            total                = 0
            by_tier              = [ordered]@{}
            by_status            = [ordered]@{}
            active_members_total = 0
        }
        threads     = [ordered]@{
            total           = 0
            with_verdict    = 0
            without_verdict = 0
            by_status       = [ordered]@{}
        }
        messages    = [ordered]@{
            total            = 0
            suspicious_count = 0
            types            = [ordered]@{}
        }
        verdicts    = [ordered]@{
            total      = 0
            by_verdict = [ordered]@{}
        }
        unread_histogram = [ordered]@{
            '0'    = 0
            '1-5'  = 0
            '6-20' = 0
            '21+'  = 0
        }
        dogfood          = [ordered]@{
            channel             = $null
            acceptance_met_bool = $false
            verdicts_count      = 0
        }
    }

    if (-not (Test-Path -LiteralPath $channelsDir)) {
        return [pscustomobject]$out
    }

    $channelDirs = Get-ChildItem -LiteralPath $channelsDir -Directory -ErrorAction SilentlyContinue
    foreach ($chDir in $channelDirs) {
        $chJson = Join-Path $chDir.FullName 'channel.json'
        if (-not (Test-Path -LiteralPath $chJson)) { continue }
        try {
            $ch = Get-Content -LiteralPath $chJson -Raw -Encoding UTF8 | ConvertFrom-Json
        } catch { continue }

        $out.channels.total++

        $tier = if ($ch.PSObject.Properties['environment_tier']) { [string]$ch.environment_tier } else { 'local' }
        $out.channels.by_tier[$tier] = 1 + ($out.channels.by_tier[$tier] ?? 0)

        $status = if ($ch.PSObject.Properties['status']) { [string]$ch.status } else { 'active' }
        $out.channels.by_status[$status] = 1 + ($out.channels.by_status[$status] ?? 0)

        $activeMembers = 0
        if ($ch.PSObject.Properties['members'] -and $ch.members) {
            $activeMembers = @($ch.members | Where-Object status -eq 'active').Count
        }
        $out.channels.active_members_total += $activeMembers

        # Dogfood detection: channel named mad-self-hosting gets special roll-up
        if ($chDir.Name -eq 'mad-self-hosting') {
            $out.dogfood.channel = 'mad-self-hosting'
        }

        # Threads
        $threadsDir = Join-Path $chDir.FullName 'threads'
        if (Test-Path -LiteralPath $threadsDir) {
            $threadDirs = Get-ChildItem -LiteralPath $threadsDir -Directory -ErrorAction SilentlyContinue
            foreach ($td in $threadDirs) {
                $out.threads.total++

                # Thread status
                $threadStatus = 'active'
                $tjPath = Join-Path $td.FullName 'thread.json'
                if (Test-Path -LiteralPath $tjPath) {
                    try {
                        $tj = Get-Content -LiteralPath $tjPath -Raw -Encoding UTF8 | ConvertFrom-Json
                        if ($tj.PSObject.Properties['status']) { $threadStatus = [string]$tj.status }
                    } catch { }
                }
                $out.threads.by_status[$threadStatus] = 1 + ($out.threads.by_status[$threadStatus] ?? 0)

                # Verdict presence
                $vPath = Join-Path $td.FullName 'verdict.json'
                if (Test-Path -LiteralPath $vPath) {
                    $out.threads.with_verdict++
                    try {
                        $v = Get-Content -LiteralPath $vPath -Raw -Encoding UTF8 | ConvertFrom-Json
                        if ($v.PSObject.Properties['verdict']) {
                            $vKey = [string]$v.verdict
                            $out.verdicts.by_verdict[$vKey] = 1 + ($out.verdicts.by_verdict[$vKey] ?? 0)
                            $out.verdicts.total++
                            if ($out.dogfood.channel -eq 'mad-self-hosting' -and $chDir.Name -eq 'mad-self-hosting') {
                                $out.dogfood.verdicts_count++
                            }
                        }
                    } catch { }
                } else {
                    $out.threads.without_verdict++
                }

                # Messages
                $msgDir = Join-Path $td.FullName 'messages'
                if (Test-Path -LiteralPath $msgDir) {
                    foreach ($mf in (Get-ChildItem -LiteralPath $msgDir -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
                        try {
                            $m = Get-Content -LiteralPath $mf.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                            $out.messages.total++
                            if ($m.PSObject.Properties['type']) {
                                $tKey = [string]$m.type
                                $out.messages.types[$tKey] = 1 + ($out.messages.types[$tKey] ?? 0)
                            }
                            if ($m.PSObject.Properties['suspicious'] -and $m.suspicious) {
                                $out.messages.suspicious_count++
                            }
                        } catch { }
                    }
                }
            }
        }

        # Read-marker → unread histogram (against digest.channel_seq)
        $digestJson = Join-Path $chDir.FullName 'digest.json'
        if (Test-Path -LiteralPath $digestJson) {
            try {
                $d = Get-Content -LiteralPath $digestJson -Raw -Encoding UTF8 | ConvertFrom-Json
                $chSeq = if ($d.PSObject.Properties['channel_seq']) { [int]$d.channel_seq } else { 0 }
                $rmDir = Join-Path $chDir.FullName 'read-markers'
                if (Test-Path -LiteralPath $rmDir) {
                    foreach ($rmFile in (Get-ChildItem -LiteralPath $rmDir -Filter '*.json' -File -ErrorAction SilentlyContinue)) {
                        try {
                            $rm = Get-Content -LiteralPath $rmFile.FullName -Raw -Encoding UTF8 | ConvertFrom-Json
                            $seen = if ($rm.PSObject.Properties['last_channel_seq_seen']) { [int]$rm.last_channel_seq_seen } else { 0 }
                            $unread = [Math]::Max(0, $chSeq - $seen)
                            # Explicit if-elseif — PowerShell `switch` falls through on
                            # every matching clause, so a scriptblock like `{ $_ -le 5 }`
                            # would match unread=0 as well.
                            $bucket = if ($unread -eq 0) { '0' }
                                      elseif ($unread -le 5) { '1-5' }
                                      elseif ($unread -le 20) { '6-20' }
                                      else { '21+' }
                            $out.unread_histogram[$bucket]++
                        } catch { }
                    }
                }
            } catch { }
        }

        # Dogfood acceptance: $ch.acceptance_criteria non-empty + 1+ verdicts
        if ($chDir.Name -eq 'mad-self-hosting') {
            $hasAC = $ch.PSObject.Properties['acceptance_criteria'] -and [string]::IsNullOrEmpty([string]$ch.acceptance_criteria) -eq $false
            if ($hasAC -and $out.dogfood.verdicts_count -ge 1) {
                $out.dogfood.acceptance_met_bool = $true
            }
        }
    }

    return [pscustomobject]$out
}

# -- Script-level entry (only when NOT dot-sourced) -------------------------
if ($MyInvocation.InvocationName -ne '.') {
    Get-MadMetrics -Root $Root | ConvertTo-Json -Depth 6
}
