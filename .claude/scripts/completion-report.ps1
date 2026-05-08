<#
.SYNOPSIS
  Scan channel state and build a structured Completion Report for a leaving member.
  Implements the Completion Report Protocol per wiki/patterns/completion-report-protocol.md.

.DESCRIPTION
  Called by /council-leave immediately before the departing member's status is
  changed. Scans thread + message files to derive contribution counts for this
  member, plus `run_ids` touched and any context gaps encountered.

  Output shape matches `schemas/completion-report.schema.json`.

.NOTES
  Used by:
    - skills/council-leave/plan.md step 3

  Heuristics (accepted approximations):
    - tasks_completed: (my task in thread X) AND (resolve message exists in X, any author)
    - tasks_dropped:   (my task in thread X) AND (thread still active) AND (no msg in X for 24h)
    - questions_answered: my answer-type messages (regardless of who asked)

  Failure isolation: per-thread try/catch; any unreadable thread lands in
  context_gaps with the rest of the report returned intact.
#>

Set-StrictMode -Version Latest

if (-not (Get-Command -Name Read-AtomicJson -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'atomic-write.ps1')
}
if (-not (Get-Command -Name Resolve-ChannelPath -ErrorAction SilentlyContinue)) {
    . (Join-Path $PSScriptRoot 'channel-helpers.ps1')
}

function New-CompletionReport {
    <#
    .SYNOPSIS
      Build a Completion Report object for a leaving member.

    .OUTPUTS
      PSCustomObject matching schemas/completion-report.schema.json.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)] [string] $ChannelName,
        [Parameter(Mandatory = $true)] [string] $Alias,
        [Parameter(Mandatory = $true)] [string] $SessionId,
        [Parameter(Mandatory = $false)] [string] $RunId = $null,
        [Parameter(Mandatory = $false)] [string] $Root = $null,
        [Parameter(Mandatory = $false)] [int] $StaleHours = 24
    )

    $channelDir = Resolve-ChannelPath -Name $ChannelName -Root $Root
    $threadsDir = Join-Path $channelDir 'threads'
    $nowUtc = (Get-Date).ToUniversalTime()
    $staleCutoff = $nowUtc.AddHours(-$StaleHours)

    $contextGaps = [System.Collections.ArrayList]::new()
    $runIds = [System.Collections.Generic.HashSet[string]]::new()

    $threadsCreated = 0
    $threadsResolved = 0
    $threadsParticipated = 0
    $tasksPickedUp = 0
    $tasksCompleted = 0
    $tasksDropped = 0
    $questionsAsked = 0
    $questionsAnswered = 0
    $verdictPending = 0

    $joinedUtc = $null
    try {
        $channelObj = Get-ChannelMetadata -Name $ChannelName -Root $Root
        foreach ($m in @($channelObj.members)) {
            if ($m.alias -eq $Alias) {
                if ($m.PSObject.Properties['joined_utc']) { $joinedUtc = $m.joined_utc }
                break
            }
        }
    } catch {
        [void]$contextGaps.Add([pscustomobject]@{ source = 'channel.json'; status = 'unreadable'; impact = 'member joined_utc lost' })
    }
    if (-not $joinedUtc) { $joinedUtc = $nowUtc.ToString('o') }

    if (Test-Path -LiteralPath $threadsDir) {
        foreach ($td in (Get-ChildItem -LiteralPath $threadsDir -Directory)) {
            try {
                $tjPath = Join-Path $td.FullName 'thread.json'
                $thread = $null
                if (Test-Path -LiteralPath $tjPath) {
                    $thread = Read-AtomicJson -Path $tjPath
                }

                $msgDir = Join-Path $td.FullName 'messages'
                $msgFiles = @()
                if (Test-Path -LiteralPath $msgDir) {
                    $msgFiles = @(Get-ChildItem -LiteralPath $msgDir -Filter '*.json' -File)
                }

                $myMessages = [System.Collections.ArrayList]::new()
                $hasResolve = $false
                $lastActivityUtc = $null

                foreach ($mf in $msgFiles) {
                    try {
                        $msg = Read-AtomicJson -Path $mf.FullName
                    } catch { continue }

                    if ($msg.PSObject.Properties['timestamp_utc']) {
                        try {
                            $t = ([datetimeoffset]$msg.timestamp_utc).UtcDateTime
                            if (-not $lastActivityUtc -or $t -gt $lastActivityUtc) { $lastActivityUtc = $t }
                        } catch { }
                    }

                    if ($msg.type -eq 'resolve') { $hasResolve = $true }

                    if ($msg.from.alias -eq $Alias) {
                        [void]$myMessages.Add($msg)
                        if ($msg.PSObject.Properties['run_id'] -and $msg.run_id) {
                            [void]$runIds.Add([string]$msg.run_id)
                        }
                        switch ($msg.type) {
                            'task'     { $tasksPickedUp++ }
                            'question' { $questionsAsked++ }
                            'answer'   { $questionsAnswered++ }
                        }
                    }
                }

                if ($myMessages.Count -gt 0) {
                    # Thread-creation: thread.created_by.alias == me
                    $isCreator = $false
                    if ($thread -and $thread.PSObject.Properties['created_by'] -and $thread.created_by -and $thread.created_by.alias -eq $Alias) {
                        $isCreator = $true
                        $threadsCreated++
                    }

                    # Thread-resolution: last resolve message in thread is from me
                    $resolvedByMe = $false
                    $lastResolve = @($msgFiles | ForEach-Object {
                        try { Read-AtomicJson -Path $_.FullName } catch { $null }
                    } | Where-Object { $_ -and $_.type -eq 'resolve' } | Select-Object -Last 1)
                    if ($lastResolve -and $lastResolve.from.alias -eq $Alias) {
                        $resolvedByMe = $true
                        $threadsResolved++
                    }

                    if (-not $isCreator -and -not $resolvedByMe) { $threadsParticipated++ }

                    # task heuristics per-thread
                    $myTasksInThread = @($myMessages | Where-Object type -eq 'task').Count
                    if ($myTasksInThread -gt 0) {
                        if ($hasResolve) {
                            $tasksCompleted += $myTasksInThread
                        } elseif ($thread -and $thread.PSObject.Properties['status'] -and $thread.status -eq 'active') {
                            if ($lastActivityUtc -and $lastActivityUtc -lt $staleCutoff) {
                                $tasksDropped += $myTasksInThread
                            }
                        }
                    }

                    # verdict pending
                    $verdictJson = Join-Path $td.FullName 'verdict.json'
                    $threadStatus = if ($thread -and $thread.PSObject.Properties['status']) { $thread.status } else { 'active' }
                    if (-not (Test-Path -LiteralPath $verdictJson) -and $threadStatus -eq 'active') {
                        $verdictPending++
                    }
                }
            } catch {
                [void]$contextGaps.Add([pscustomobject]@{
                    source = "threads/$($td.Name)"
                    status = $_.Exception.Message
                    impact = 'contribution counts may be incomplete for this thread'
                })
            }
        }
    }

    return [pscustomobject]@{
        alias        = $Alias
        session_id   = $SessionId
        channel      = $ChannelName
        joined_utc   = $joinedUtc
        left_utc     = $nowUtc.ToString('o')
        threads      = [pscustomobject]@{
            created          = $threadsCreated
            resolved         = $threadsResolved
            participated    = $threadsParticipated
            verdict_pending = $verdictPending
        }
        tasks        = [pscustomobject]@{
            picked_up = $tasksPickedUp
            completed = $tasksCompleted
            dropped   = $tasksDropped
        }
        questions    = [pscustomobject]@{
            asked     = $questionsAsked
            answered  = $questionsAnswered
        }
        final_state  = 'left'      # caller (council-leave) overwrites for last-member cases
        run_ids      = @($runIds)
        context_gaps = @($contextGaps)
    }
}

function Format-CompletionReport {
    <#
    .SYNOPSIS
      Render the report object as plain-text summary.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object] $Report
    )

    $lines = @(
        "Completion Report — $($Report.alias) leaving #$($Report.channel)"
        "  Joined:  $($Report.joined_utc)"
        "  Left:    $($Report.left_utc)"
        ''
        "  Threads: created $($Report.threads.created), resolved $($Report.threads.resolved), participated $($Report.threads.participated), verdict-pending $($Report.threads.verdict_pending)"
        "  Tasks:   picked-up $($Report.tasks.picked_up), completed $($Report.tasks.completed), dropped $($Report.tasks.dropped)"
        "  Q&A:     asked $($Report.questions.asked), answered $($Report.questions.answered)"
        "  Run IDs: $(@($Report.run_ids).Count) distinct"
        "  State:   $($Report.final_state)"
    )
    if (@($Report.context_gaps).Count -gt 0) {
        $lines += ''
        $lines += '  Context Gaps:'
        foreach ($g in $Report.context_gaps) {
            $lines += "    - $($g.source): $($g.status)"
        }
    }
    return ($lines -join [Environment]::NewLine)
}
