# Analyze-TeamSession.ps1
# Analyze a Claude Code agent team session from JSONL transcript and subagent files
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File Analyze-TeamSession.ps1 [options]
#
# Options:
#   -SessionId <uuid>  Session to analyze (required, or use -Recent)
#   -Recent            Analyze the most recent team session
#   -Project <name>    Filter to specific project directory (substring match)
#   -Json              Output as JSON for programmatic use
#   -Quiet             Suppress warnings, show only stats
#
# Examples:
#   Analyze-TeamSession.ps1 -SessionId "90794f7f-fce9-4dde-9dfa-4924deebbfb3"
#   Analyze-TeamSession.ps1 -Recent
#   Analyze-TeamSession.ps1 -Recent -Project "localsearch"
#   Analyze-TeamSession.ps1 -SessionId "90794f7f" -Json

param(
    [string]$SessionId = "",
    [switch]$Recent,
    [string]$Project = "",
    [switch]$Json,
    [switch]$Quiet
)

# Resolve projects directory
$projectsDir = if ($env:CLAUDE_CONFIG_DIR) {
    Join-Path $env:CLAUDE_CONFIG_DIR "projects"
} else {
    Join-Path $env:USERPROFILE ".claude\projects"
}

if (-not (Test-Path $projectsDir)) {
    Write-Host "Projects directory not found: $projectsDir" -ForegroundColor Red
    exit 1
}

# =============================================================================
# DISCOVER SESSION
# =============================================================================

function Find-TeamSession {
    param(
        [string]$BaseDir,
        [string]$Id,
        [switch]$MostRecent,
        [string]$ProjectFilter
    )

    $projectDirs = Get-ChildItem -Path $BaseDir -Directory
    if ($ProjectFilter) {
        $projectDirs = $projectDirs | Where-Object { $_.Name -match [regex]::Escape($ProjectFilter) }
    }

    $candidates = @()
    foreach ($projDir in $projectDirs) {
        $jsonlFiles = Get-ChildItem -Path $projDir.FullName -Filter "*.jsonl" -File 2>$null
        foreach ($f in $jsonlFiles) {
            if ($Id) {
                # Match full or partial session ID
                if ($f.BaseName -like "*$Id*") {
                    $candidates += [PSCustomObject]@{
                        Path       = $f.FullName
                        SessionId  = $f.BaseName
                        Project    = $projDir.Name
                        Modified   = $f.LastWriteTime
                    }
                }
            } else {
                $candidates += [PSCustomObject]@{
                    Path       = $f.FullName
                    SessionId  = $f.BaseName
                    Project    = $projDir.Name
                    Modified   = $f.LastWriteTime
                }
            }
        }
    }

    if ($MostRecent) {
        # Filter to team sessions only - check for TeamCreate in each file
        $teamSessions = @()
        foreach ($c in ($candidates | Sort-Object Modified -Descending)) {
            $hasTeam = Select-String -Path $c.Path -Pattern "TeamCreate" -Quiet 2>$null
            if ($hasTeam) {
                $teamSessions += $c
            }
            # Stop after finding first match for -Recent
            if ($teamSessions.Count -ge 1) { break }
        }
        return $teamSessions | Select-Object -First 1
    }

    return $candidates | Sort-Object Modified -Descending | Select-Object -First 1
}

if (-not $SessionId -and -not $Recent) {
    Write-Host "Error: specify -SessionId <uuid> or -Recent" -ForegroundColor Red
    exit 1
}

$session = Find-TeamSession -BaseDir $projectsDir -Id $SessionId -MostRecent:$Recent -ProjectFilter $Project

if (-not $session) {
    $msg = if ($SessionId) { "Session '$SessionId' not found" } else { "No team sessions found" }
    if ($Project) { $msg += " in project '$Project'" }
    Write-Host $msg -ForegroundColor Red
    exit 1
}

$transcriptPath = $session.Path
$sessionDir = Join-Path (Split-Path $transcriptPath) $session.SessionId
$subagentsDir = Join-Path $sessionDir "subagents"

# Verify this is a team session
$isTeam = Select-String -Path $transcriptPath -Pattern "TeamCreate" -Quiet 2>$null
if (-not $isTeam) {
    Write-Host "Session $($session.SessionId) is not a team session (no TeamCreate found)" -ForegroundColor Yellow
    exit 1
}

# =============================================================================
# PARSE MAIN TRANSCRIPT
# =============================================================================

$teamName = ""
$slug = ""
$teamCreateTime = $null
$teamDeleteTime = $null
$taskCreations = @()
$taskUpdates = @()
$teammateSpawns = @()
$sendMessages = @()
$turnDurations = @()
$compactBoundaries = @()
$mainTokens = @{ input = 0; output = 0; cache_create = 0; cache_read = 0 }

$lines = Get-Content $transcriptPath

foreach ($line in $lines) {
    # Quick pre-filter to avoid JSON parsing every line
    if ($line -notmatch '"type"') { continue }

    try {
        $event = $line | ConvertFrom-Json
    } catch {
        continue
    }

    # Capture slug from first event that has it
    if (-not $slug -and $event.slug) {
        $slug = $event.slug
    }

    # System events (turn_duration, compact_boundary)
    if ($event.type -eq "system") {
        if ($event.subtype -eq "turn_duration") {
            $turnDurations += [PSCustomObject]@{
                DurationMs = $event.durationMs
                Timestamp  = $event.timestamp
            }
        } elseif ($event.subtype -eq "compact_boundary") {
            $compactBoundaries += [PSCustomObject]@{
                PreTokens = $event.compactMetadata.preTokens
                Timestamp = $event.timestamp
            }
        }
        continue
    }

    # Skip progress events
    if ($event.type -eq "progress") { continue }

    # Assistant messages - extract tool calls and token usage
    if ($event.type -eq "assistant" -and $event.message.role -eq "assistant") {
        $usage = $event.message.usage
        if ($usage) {
            $mainTokens['input'] += [int64]($usage.input_tokens)
            $mainTokens['output'] += [int64]($usage.output_tokens)
            $mainTokens['cache_create'] += [int64]($usage.cache_creation_input_tokens)
            $mainTokens['cache_read'] += [int64]($usage.cache_read_input_tokens)
        }

        $content = $event.message.content
        if ($content -is [array]) {
            foreach ($block in $content) {
                if ($block.type -ne "tool_use") { continue }

                switch ($block.name) {
                    "TeamCreate" {
                        $teamName = $block.input.team_name
                        $teamCreateTime = $event.timestamp
                    }
                    "TeamDelete" {
                        $teamDeleteTime = $event.timestamp
                    }
                    "TaskCreate" {
                        $taskCreations += [PSCustomObject]@{
                            Subject    = $block.input.subject
                            TaskId     = $block.id
                            Timestamp  = $event.timestamp
                        }
                    }
                    "Task" {
                        # Detect teammate spawns: team_name in input (old format)
                        # or name in input (new format - team_name only appears in toolUseResult)
                        if ($block.input.team_name -or $block.input.name) {
                            $promptSnippet = ""
                            if ($block.input.prompt) {
                                $len = [Math]::Min(120, $block.input.prompt.Length)
                                $promptSnippet = $block.input.prompt.Substring(0, $len)
                            }
                            $teammateSpawns += [PSCustomObject]@{
                                Name         = $block.input.name
                                TeamName     = $block.input.team_name
                                Model        = $block.input.model
                                Mode         = $block.input.mode
                                ToolUseId    = $block.id
                                Timestamp    = $event.timestamp
                                AgentType    = $block.input.subagent_type
                                PromptPrefix = $promptSnippet
                            }
                        }
                    }
                    "SendMessage" {
                        $sendMessages += [PSCustomObject]@{
                            Type       = $block.input.type
                            Recipient  = $block.input.recipient
                            Content    = $block.input.content
                            Timestamp  = $event.timestamp
                        }
                    }
                }
            }
        }
    }

    # Tool results for teammate spawns - fill in fields from toolUseResult
    # The toolUseResult contains authoritative data: name, team_name, model, color, etc.
    # The Task tool_use input may lack team_name (not serialized in newer formats).
    if ($event.type -eq "user" -and $event.toolUseResult -and $event.toolUseResult.status -eq "teammate_spawned") {
        $result = $event.toolUseResult
        $toolUseId = $null
        if ($event.message.content -is [array]) {
            foreach ($block in $event.message.content) {
                if ($block.type -eq "tool_result") {
                    $toolUseId = $block.tool_use_id
                    break
                }
            }
        }

        # Match to spawn by tool_use_id and fill in missing fields
        $matched = $false
        foreach ($spawn in $teammateSpawns) {
            if ($spawn.ToolUseId -eq $toolUseId) {
                if (-not $spawn.TeamName -and $result.team_name) {
                    $spawn.TeamName = $result.team_name
                }
                if (-not $spawn.Name -and $result.name) {
                    $spawn.Name = $result.name
                }
                if (-not $spawn.Model -and $result.model) {
                    $spawn.Model = $result.model
                }
                $spawn | Add-Member -NotePropertyName "TeammateId" -NotePropertyValue $result.teammate_id -Force
                $spawn | Add-Member -NotePropertyName "Color" -NotePropertyValue $result.color -Force
                $matched = $true
                break
            }
        }

        # If no matching spawn (Task call had neither name nor team_name), create one
        if (-not $matched -and $result.name) {
            $promptSnippet = ""
            if ($result.prompt) {
                $len = [Math]::Min(120, $result.prompt.Length)
                $promptSnippet = $result.prompt.Substring(0, $len)
            }
            $teammateSpawns += [PSCustomObject]@{
                Name         = $result.name
                TeamName     = $result.team_name
                Model        = $result.model
                Mode         = $null
                ToolUseId    = $toolUseId
                Timestamp    = $event.timestamp
                AgentType    = $result.agent_type
                PromptPrefix = $promptSnippet
                TeammateId   = $result.teammate_id
                Color        = $result.color
            }
        }
    }
}

# =============================================================================
# PARSE SUBAGENT FILES
# =============================================================================

$subagentStats = @()

if (Test-Path $subagentsDir) {
    $subagentFiles = Get-ChildItem -Path $subagentsDir -Filter "agent-*.jsonl" -File

    foreach ($sf in $subagentFiles) {
        $agentId = $sf.BaseName -replace '^agent-', ''
        $fileSize = $sf.Length
        $msgCount = 0
        $toolCounts = @{}
        $tokens = @{ input = 0; output = 0; cache_create = 0; cache_read = 0 }
        $model = ""
        $firstTimestamp = $null
        $lastTimestamp = $null
        $isTeammate = $false
        $agentTeamName = ""

        $sfLines = Get-Content $sf.FullName
        foreach ($sLine in $sfLines) {
            if ($sLine -notmatch '"type"') { continue }

            try {
                $sEvent = $sLine | ConvertFrom-Json
            } catch {
                continue
            }

            # Track timestamps
            if ($sEvent.timestamp) {
                if (-not $firstTimestamp) { $firstTimestamp = $sEvent.timestamp }
                $lastTimestamp = $sEvent.timestamp
            }

            # Check if this is a team subagent (teammate-message in content or teamName field)
            if (-not $isTeammate) {
                if ($sEvent.teamName) {
                    $isTeammate = $true
                    $agentTeamName = $sEvent.teamName
                } elseif ($sEvent.message.content -is [string] -and $sEvent.message.content -match 'teammate-message|teammate "') {
                    $isTeammate = $true
                }
            }

            if ($sEvent.type -eq "assistant" -and $sEvent.message.role -eq "assistant") {
                $msgCount++
                $sUsage = $sEvent.message.usage
                if ($sUsage) {
                    $tokens['input'] += [int64]($sUsage.input_tokens)
                    $tokens['output'] += [int64]($sUsage.output_tokens)
                    $tokens['cache_create'] += [int64]($sUsage.cache_creation_input_tokens)
                    $tokens['cache_read'] += [int64]($sUsage.cache_read_input_tokens)
                }
                if (-not $model -and $sEvent.message.model) {
                    $model = $sEvent.message.model
                }

                # Count tool uses
                $sContent = $sEvent.message.content
                if ($sContent -is [array]) {
                    foreach ($sBlock in $sContent) {
                        if ($sBlock.type -eq "tool_use") {
                            $toolName = $sBlock.name
                            if (-not $toolCounts.ContainsKey($toolName)) { $toolCounts[$toolName] = 0 }
                            $toolCounts[$toolName]++
                        }
                    }
                }
            }

            # Also count messages (user + assistant)
            if ($sEvent.type -eq "user") {
                # Count tool result messages as part of the conversation
            }
        }

        # Compute duration
        $durationMin = 0
        if ($firstTimestamp -and $lastTimestamp) {
            try {
                $startDt = [datetime]::Parse($firstTimestamp)
                $endDt = [datetime]::Parse($lastTimestamp)
                $durationMin = [math]::Round(($endDt - $startDt).TotalMinutes, 1)
            } catch { }
        }

        $subagentStats += [PSCustomObject]@{
            AgentId       = $agentId
            FileSize      = $fileSize
            MsgCount      = $msgCount
            Model         = $model
            Tokens        = $tokens
            ToolCounts    = $toolCounts
            DurationMin   = $durationMin
            IsTeammate    = $isTeammate
            TeamName      = $agentTeamName
            FirstTimestamp = $firstTimestamp
            LastTimestamp  = $lastTimestamp
        }
    }
}

# =============================================================================
# MATCH SUBAGENTS TO TEAMMATES
# =============================================================================

# Two-pass matching:
# Pass 1: Match by prompt text - the spawn's prompt prefix is compared against
#         each subagent file's first user message content. This reliably
#         distinguishes teammates with similar names (e.g., "advocate" vs
#         "advocate-counter") because each spawn has a unique prompt.
# Pass 2: Pattern-based fallback for continuation/compacted files that don't
#         contain the original prompt (e.g., task_assignment, shutdown files).

$agentToTeammate = @{}  # agentId -> teammate name
$matchedAgentIds = @{}  # Track already-matched files

# Sort spawns by name length descending so more specific names match first
# (e.g., "advocate-counter" is checked before "advocate")
$spawnsBySpecificity = @($teammateSpawns | Sort-Object { $_.Name.Length } -Descending)

# --- Pass 1: Prompt-based matching ---
foreach ($sa in $subagentStats) {
    $filePath = Join-Path $subagentsDir "agent-$($sa.AgentId).jsonl"
    $firstLine = Get-Content $filePath -TotalCount 1 2>$null
    if (-not $firstLine) { continue }
    try {
        $firstEvent = $firstLine | ConvertFrom-Json
    } catch {
        continue
    }

    # Extract user message content as string
    $msgContent = ""
    if ($firstEvent.message.content -is [string]) {
        $msgContent = $firstEvent.message.content
    } elseif ($firstEvent.message.content -is [array]) {
        foreach ($cBlock in $firstEvent.message.content) {
            if ($cBlock.type -eq "text") {
                $msgContent += $cBlock.text
            }
        }
    }

    if (-not $msgContent -or $msgContent.Length -lt 20) { continue }

    # Match against each spawn's prompt prefix (longest name first)
    foreach ($spawn in $spawnsBySpecificity) {
        if (-not $spawn.PromptPrefix -or $spawn.PromptPrefix.Length -lt 10) { continue }
        $escaped = [regex]::Escape($spawn.PromptPrefix)
        if ($msgContent -match $escaped) {
            $agentToTeammate[$sa.AgentId] = $spawn.Name
            $matchedAgentIds[$sa.AgentId] = $true
            break
        }
    }
}

# --- Pass 2: Pattern-based fallback for unmatched files ---
foreach ($sa in $subagentStats) {
    if ($matchedAgentIds.ContainsKey($sa.AgentId)) { continue }

    $filePath = Join-Path $subagentsDir "agent-$($sa.AgentId).jsonl"
    $headerLines = Get-Content $filePath -TotalCount 20 2>$null
    $headerText = $headerLines -join "`n"

    foreach ($spawn in $spawnsBySpecificity) {
        $name = $spawn.Name
        $teamN = $spawn.TeamName
        $nameEsc = [regex]::Escape($name)
        $teamEsc = [regex]::Escape($teamN)

        # Use word-boundary-aware patterns to prevent partial matches
        # (e.g., "advocate" should not match "advocate-counter")
        $nameExact = if ($name -match '-') {
            # Hyphenated names are already specific, match literally
            $nameEsc
        } else {
            # Simple names: negative lookahead prevents matching hyphenated variants
            "$nameEsc(?![\w-])"
        }

        # Match patterns: name@team in requestIds, "from":"name" in messages
        if ($headerText -match "$nameExact@$teamEsc" -or
            $headerText -match "requestId.*$nameExact@" -or
            $headerText -match "`"from`"\s*:\s*`"$nameEsc`"" -or
            $headerText -match "teammate_id[=`"':]+$nameEsc`"") {
            $agentToTeammate[$sa.AgentId] = $name
            $matchedAgentIds[$sa.AgentId] = $true
            break
        }
    }
}

# For each teammate, find the LARGEST matching subagent file (the main working file)
$teammateStats = @{}
foreach ($spawn in $teammateSpawns) {
    $name = $spawn.Name
    $matchingAgents = @($subagentStats | Where-Object {
        $agentToTeammate[$_.AgentId] -eq $name
    } | Sort-Object FileSize -Descending)
    if ($matchingAgents.Count -gt 0) {
        $teammateStats[$name] = $matchingAgents[0]

        # If there are multiple files, aggregate their stats
        if ($matchingAgents.Count -gt 1) {
            $primary = $matchingAgents[0]
            for ($idx = 1; $idx -lt $matchingAgents.Count; $idx++) {
                $other = $matchingAgents[$idx]
                $primary.MsgCount += $other.MsgCount
                $primary.Tokens['input'] += $other.Tokens['input']
                $primary.Tokens['output'] += $other.Tokens['output']
                $primary.Tokens['cache_create'] += $other.Tokens['cache_create']
                $primary.Tokens['cache_read'] += $other.Tokens['cache_read']
                $primary.FileSize += $other.FileSize
                foreach ($tool in $other.ToolCounts.Keys) {
                    if (-not $primary.ToolCounts.ContainsKey($tool)) { $primary.ToolCounts[$tool] = 0 }
                    $primary.ToolCounts[$tool] += $other.ToolCounts[$tool]
                }
            }
        }
    }
}

# =============================================================================
# GENERATE WARNINGS
# =============================================================================

$warnings = @()

# Plan-approval loop detection (>2 approvals to same recipient)
$approvalCounts = @{}
foreach ($msg in $sendMessages) {
    if ($msg.Type -eq "plan_approval_response") {
        $r = $msg.Recipient
        if (-not $approvalCounts.ContainsKey($r)) { $approvalCounts[$r] = 0 }
        $approvalCounts[$r]++
    }
}
foreach ($entry in $approvalCounts.GetEnumerator()) {
    if ($entry.Value -gt 2) {
        $warnings += "$($entry.Key): $($entry.Value) plan approval responses sent (possible plan-approval loop)"
    }
}

# Model mismatch detection - only check matched teammates, not all subagents
# (pre-team exploration agents may use a different model legitimately)
$allModels = @()
foreach ($entry in $teammateStats.GetEnumerator()) {
    if ($entry.Value.Model) { $allModels += $entry.Value.Model }
}
$uniqueModels = @($allModels | Sort-Object -Unique)
$requestedModels = @($teammateSpawns | Where-Object { $_.Model } | Select-Object -ExpandProperty Model -Unique)
if ($uniqueModels.Count -eq 1 -and $requestedModels.Count -gt 0) {
    $actualModel = $uniqueModels[0]
    $mismatch = $requestedModels | Where-Object { $_ -ne $actualModel -and "claude-$_" -notmatch [regex]::Escape($actualModel) }
    if ($mismatch) {
        $warnings += "All subagents used $actualModel (model parameter '$($mismatch -join ", ")' may have been ignored)"
    }
}

# Size imbalance detection
$teammateSizes = @()
foreach ($entry in $teammateStats.GetEnumerator()) {
    $teammateSizes += [PSCustomObject]@{ Name = $entry.Key; Size = $entry.Value.FileSize }
}
if ($teammateSizes.Count -ge 2) {
    $sorted = $teammateSizes | Sort-Object Size -Descending
    $largest = $sorted[0]
    $smallest = $sorted[-1]
    if ($smallest.Size -gt 0) {
        $ratio = [math]::Round($largest.Size / $smallest.Size, 1)
        if ($ratio -ge 3) {
            $warnings += "$($largest.Name) subagent is ${ratio}x larger than $($smallest.Name) (possible inefficiency)"
        }
    }
}

# =============================================================================
# COMPUTE SUMMARIES
# =============================================================================

$totalSubagents = $subagentStats.Count
$totalTasks = $taskCreations.Count

# Count completed tasks from main transcript AND subagent files
# Task completions happen in subagent files (teammates mark their own tasks done)
$completedTaskIds = @{}
$allJsonlFiles = @($transcriptPath)
if (Test-Path $subagentsDir) {
    $allJsonlFiles += Get-ChildItem -Path $subagentsDir -Filter "agent-*.jsonl" -File | ForEach-Object { $_.FullName }
}
foreach ($jf in $allJsonlFiles) {
    $jfLines = Get-Content $jf
    foreach ($jLine in $jfLines) {
        if ($jLine -match '"name":"TaskUpdate"' -and $jLine -match '"status":"completed"') {
            # Extract taskId
            if ($jLine -match '"taskId"\s*:\s*"([^"]+)"') {
                $completedTaskIds[$matches[1]] = $true
            }
        }
    }
}
$taskCompletedCount = $completedTaskIds.Count

# SendMessage breakdown
$msgTypeCounts = @{}
foreach ($msg in $sendMessages) {
    $t = $msg.Type
    if (-not $msgTypeCounts.ContainsKey($t)) { $msgTypeCounts[$t] = 0 }
    $msgTypeCounts[$t]++
}

# Duration from turn_duration events
$turnDurationsFormatted = @()
foreach ($td in $turnDurations) {
    $mins = [math]::Round($td.DurationMs / 60000, 1)
    $turnDurationsFormatted += $mins
}
$totalDurationMin = ($turnDurationsFormatted | Measure-Object -Sum).Sum

# =============================================================================
# OUTPUT
# =============================================================================

if ($Json) {
    $output = @{
        sessionId       = $session.SessionId
        project         = $session.Project
        slug            = $slug
        teamName        = $teamName
        totalSubagents  = $totalSubagents
        totalTasks      = $totalTasks
        tasksCompleted  = $taskCompletedCount
        durationMinutes = $totalDurationMin
        turnDurations   = $turnDurationsFormatted
        teammates       = @{}
        sendMessages    = $msgTypeCounts
        warnings        = $warnings
        mainTokens      = $mainTokens
        compactBoundaries = $compactBoundaries.Count
    }

    foreach ($entry in $teammateStats.GetEnumerator()) {
        $sa = $entry.Value
        $output.teammates[$entry.Key] = @{
            agentId    = $sa.AgentId
            fileSize   = $sa.FileSize
            msgCount   = $sa.MsgCount
            model      = $sa.Model
            tokens     = $sa.Tokens
            toolCounts = $sa.ToolCounts
            durationMin = $sa.DurationMin
        }
    }

    Write-Output (ConvertTo-Json -Depth 5 $output)
    exit 0
}

# --- Formatted output ---

Write-Host ""
$displaySlug = if ($slug) { $slug } else { "(unknown)" }
Write-Host "=== Agent Team Session: $displaySlug ===" -ForegroundColor Cyan
Write-Host ("  Session:    {0}" -f $session.SessionId)
Write-Host ("  Project:    {0}" -f $session.Project)
if ($teamName) {
    Write-Host ("  Team:       {0}" -f $teamName)
}
$turnStr = ($turnDurationsFormatted | ForEach-Object { "${_} min" }) -join " + "
Write-Host ("  Duration:   {0} (total: {1} min)" -f $turnStr, $totalDurationMin)
Write-Host ("  Subagents:  {0}" -f $totalSubagents)
if ($compactBoundaries.Count -gt 0) {
    Write-Host ("  Compactions: {0}" -f $compactBoundaries.Count) -ForegroundColor Gray
}
Write-Host ""

# Team Events
Write-Host "=== Team Events ===" -ForegroundColor Yellow
if ($teamCreateTime) { Write-Host ("  TeamCreate:  {0}" -f $teamName) }
Write-Host ("  Tasks created: {0}" -f $totalTasks)
$teammateList = ($teammateSpawns | ForEach-Object { $_.Name }) -join ", "
Write-Host ("  Teammates spawned: {0} ({1})" -f $teammateSpawns.Count, $teammateList)
foreach ($entry in $msgTypeCounts.GetEnumerator()) {
    $label = switch ($entry.Key) {
        "plan_approval_response" { "Plan approvals sent" }
        "shutdown_request" { "Shutdown requests sent" }
        "message" { "Messages sent" }
        default { $entry.Key }
    }
    $suffix = ""
    if ($entry.Key -eq "plan_approval_response" -and $entry.Value -gt 4) {
        $suffix = " (!!!)"
    }
    Write-Host ("  {0}: {1}{2}" -f $label, $entry.Value, $suffix)
}
if ($teamDeleteTime) { Write-Host "  TeamDelete:  cleanup completed" }
Write-Host ""

# Teammate Performance
if ($teammateStats.Count -gt 0) {
    Write-Host "=== Teammate Performance ===" -ForegroundColor Yellow

    # Header
    Write-Host ("  {0,-8} {1,-10} {2,10} {3,6} {4,12} {5,14}   {6}" -f "Name", "Subagent", "Size", "Msgs", "Cache Create", "Cache Read", "Top Tools")

    foreach ($spawn in $teammateSpawns) {
        $name = $spawn.Name
        $sa = $teammateStats[$name]
        if (-not $sa) { continue }

        $sizeStr = if ($sa.FileSize -ge 1MB) {
            "{0:N1} MB" -f ($sa.FileSize / 1MB)
        } else {
            "{0:N0} KB" -f ($sa.FileSize / 1KB)
        }

        # Top 3 tools
        $topTools = ""
        if ($sa.ToolCounts.Count -gt 0) {
            $topTools = ($sa.ToolCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 3 | ForEach-Object { "$($_.Key):$($_.Value)" }) -join " "
        }

        Write-Host ("  {0,-8} {1,-10} {2,10} {3,6} {4,12:N0} {5,14:N0}   {6}" -f `
            $name, `
            $sa.AgentId, `
            $sizeStr, `
            $sa.MsgCount, `
            $sa.Tokens['cache_create'], `
            $sa.Tokens['cache_read'], `
            $topTools)
    }
    Write-Host ""
}

# Lead Token Usage
Write-Host "=== Lead Token Usage ===" -ForegroundColor Yellow
Write-Host ("  Input:        {0,12:N0}" -f $mainTokens['input'])
Write-Host ("  Output:       {0,12:N0}" -f $mainTokens['output'])
Write-Host ("  Cache create: {0,12:N0}" -f $mainTokens['cache_create'])
Write-Host ("  Cache read:   {0,12:N0}" -f $mainTokens['cache_read'])
Write-Host ""

# Warnings
if (-not $Quiet -and $warnings.Count -gt 0) {
    Write-Host "=== Warnings ===" -ForegroundColor Yellow
    foreach ($w in $warnings) {
        Write-Host "  ! $w" -ForegroundColor DarkYellow
    }
    Write-Host ""
}

# Task Summary
Write-Host "=== Task Summary ===" -ForegroundColor Yellow
Write-Host ("  {0}/{1} tasks completed" -f $taskCompletedCount, $totalTasks)
if ($taskCreations.Count -gt 0 -and $taskCreations.Count -le 20) {
    foreach ($tc in $taskCreations) {
        Write-Host ("    - {0}" -f $tc.Subject) -ForegroundColor Gray
    }
}
Write-Host ""
