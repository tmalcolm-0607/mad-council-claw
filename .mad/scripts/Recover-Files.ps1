<#
.SYNOPSIS
    Recover files from Claude Code session transcripts.
.DESCRIPTION
    Extracts file content recorded in Write, Edit, and Read tool operations
    from JSONL session transcripts. Useful after destructive operations
    (e.g., robocopy /MIR, rm -rf) when git history is unavailable.

    Idea: James Unger <ungerjames@microsoft.com>
.PARAMETER List
    List all file operations in a session.
.PARAMETER SearchFile
    Find sessions with file paths matching pattern.
.PARAMETER SearchText
    Find sessions with file contents matching pattern (regex).
.PARAMETER Timeline
    Show chronological operations on a specific file.
.PARAMETER Extract
    Extract the most recent content of a file.
.PARAMETER Recover
    Recover all written/edited files from a session.
.PARAMETER SessionId
    Session to analyze (supports partial match).
.PARAMETER Recent
    Use the most recent session.
.PARAMETER Project
    Filter to project directory matching name.
.PARAMETER Days
    Only scan sessions from the last n days.
.PARAMETER Json
    Machine-readable JSON output.
.PARAMETER Quiet
    Suppress informational messages.
.PARAMETER All
    With -Extract: show every version, not just most recent.
.PARAMETER OutputDir
    With -Recover: output directory (default: ./recovered).
.EXAMPLE
    Recover-Files.ps1 -List -Recent
.EXAMPLE
    Recover-Files.ps1 -SearchFile "AgencyFork.ini"
.EXAMPLE
    Recover-Files.ps1 -SearchFile "service.cs" -Days 7
.EXAMPLE
    Recover-Files.ps1 -SearchText "connectionString" -Days 7
.EXAMPLE
    Recover-Files.ps1 -Recover -SessionId "a6967c83"
.EXAMPLE
    Recover-Files.ps1 -Recover -Recent -OutputDir "./my-recovery"
#>

param(
    [switch]$List,
    [string]$SearchFile = "",
    [string]$SearchText = "",
    [string]$Timeline = "",
    [string]$Extract = "",
    [switch]$Recover,
    [string]$SessionId = "",
    [switch]$Recent,
    [string]$Project = "",
    [int]$Days = 0,
    [switch]$Json,
    [switch]$Quiet,
    [switch]$All,
    [string]$OutputDir = "./recovered"
)

# ============================================================================
# VALIDATION
# ============================================================================

$modeCount = 0
if ($List) { $modeCount++ }
if ($SearchFile) { $modeCount++ }
if ($SearchText) { $modeCount++ }
if ($Timeline) { $modeCount++ }
if ($Extract) { $modeCount++ }
if ($Recover) { $modeCount++ }

if ($modeCount -eq 0) {
    Write-Host "Error: specify a mode: -List, -SearchFile, -SearchText, -Timeline, -Extract, or -Recover" -ForegroundColor Red
    exit 2
}
if ($modeCount -gt 1) {
    Write-Host "Error: modes are mutually exclusive - use only one" -ForegroundColor Red
    exit 2
}

$needsSession = $List -or $Timeline -or $Extract -or $Recover
if ($needsSession -and -not $SessionId -and -not $Recent) {
    Write-Host "Error: specify -SessionId <uuid> or -Recent" -ForegroundColor Red
    exit 2
}

# Resolve projects directory
$projectsDir = if ($env:CLAUDE_CONFIG_DIR) {
    Join-Path $env:CLAUDE_CONFIG_DIR "projects"
} else {
    Join-Path $env:USERPROFILE ".claude\projects"
}

if (-not (Test-Path $projectsDir)) {
    Write-Host "Projects directory not found: $projectsDir" -ForegroundColor Red
    exit 2
}

# ============================================================================
# FIND SESSIONS
# ============================================================================

function Find-Sessions {
    param(
        [string]$BaseDir,
        [string]$Id,
        [switch]$MostRecent,
        [string]$ProjectFilter,
        [int]$DaysBack,
        [switch]$ReturnAll
    )

    $projectDirs = Get-ChildItem -Path $BaseDir -Directory
    if ($ProjectFilter) {
        $projectDirs = $projectDirs | Where-Object { $_.Name -match [regex]::Escape($ProjectFilter) }
    }

    $cutoff = $null
    if ($DaysBack -gt 0) {
        $cutoff = (Get-Date).AddDays(-$DaysBack)
    }

    $candidates = @()
    foreach ($projDir in $projectDirs) {
        $jsonlFiles = Get-ChildItem -Path $projDir.FullName -Filter "*.jsonl" -File 2>$null
        foreach ($f in $jsonlFiles) {
            if ($cutoff -and $f.LastWriteTime -lt $cutoff) { continue }

            if ($Id) {
                if ($f.BaseName -like "*$Id*") {
                    $candidates += [PSCustomObject]@{
                        Path      = $f.FullName
                        SessionId = $f.BaseName
                        Project   = $projDir.Name
                        Modified  = $f.LastWriteTime
                    }
                }
            } else {
                $candidates += [PSCustomObject]@{
                    Path      = $f.FullName
                    SessionId = $f.BaseName
                    Project   = $projDir.Name
                    Modified  = $f.LastWriteTime
                }
            }
        }
    }

    if ($ReturnAll) {
        return $candidates | Sort-Object Modified -Descending
    }

    if ($MostRecent) {
        return $candidates | Sort-Object Modified -Descending | Select-Object -First 1
    }

    # Return all matches sorted by recency (caller can disambiguate)
    return $candidates | Sort-Object Modified -Descending
}

# ============================================================================
# GET SESSION FILES (main transcript + subagent files)
# ============================================================================

function Get-SessionFiles {
    param(
        [PSCustomObject]$Session
    )

    $files = @()
    $files += [PSCustomObject]@{
        Path        = $Session.Path
        SourceAgent = "lead"
        SessionId   = $Session.SessionId
        Project     = $Session.Project
    }

    $sessionDir = Join-Path (Split-Path $Session.Path) $Session.SessionId
    $subagentsDir = Join-Path $sessionDir "subagents"

    if (Test-Path $subagentsDir) {
        $subagentFiles = Get-ChildItem -Path $subagentsDir -Filter "agent-*.jsonl" -File 2>$null
        foreach ($sf in $subagentFiles) {
            $agentId = $sf.BaseName -replace '^agent-', ''
            $files += [PSCustomObject]@{
                Path        = $sf.FullName
                SourceAgent = "subagent:$agentId"
                SessionId   = $Session.SessionId
                Project     = $Session.Project
            }
        }
    }

    return ,$files
}

# ============================================================================
# PARSE FILE OPERATIONS FROM JSONL
# ============================================================================

function Get-FileOperations {
    param(
        [PSCustomObject[]]$SessionFiles,
        [string]$FileFilter
    )

    $operations = @()
    $pendingEdits = @{}  # tool_use_id -> edit info

    foreach ($sf in $SessionFiles) {
        $lines = Get-Content $sf.Path
        $lineNum = 0

        foreach ($line in $lines) {
            $lineNum++

            # Level 2 pre-filter: skip lines without relevant tool names
            if ($line -notmatch '"Write"|"Edit"|"Read"|"toolUseResult"') { continue }

            try {
                $event = $line | ConvertFrom-Json
            } catch {
                continue
            }

            $timestamp = $event.timestamp

            # Assistant messages - extract Write/Edit/Read tool_use blocks
            if ($event.type -eq "assistant" -and $event.message.role -eq "assistant") {
                $content = $event.message.content
                if ($content -is [array]) {
                    foreach ($block in $content) {
                        if ($block.type -ne "tool_use") { continue }

                        switch ($block.name) {
                            "Write" {
                                $filePath = $block.input.file_path
                                if ($FileFilter -and $filePath -notlike "*$FileFilter*") { continue }

                                $operations += [PSCustomObject]@{
                                    FilePath      = $filePath
                                    Operation     = "Write"
                                    LineNumber    = $lineNum
                                    Timestamp     = $timestamp
                                    Content       = $block.input.content
                                    ToolUseId     = $block.id
                                    IsPartialRead = $false
                                    SourceFile    = $sf.Path
                                    SourceAgent   = $sf.SourceAgent
                                    SessionId     = $sf.SessionId
                                    Project       = $sf.Project
                                }
                            }
                            "Edit" {
                                $filePath = $block.input.file_path
                                if ($FileFilter -and $filePath -notlike "*$FileFilter*") { continue }

                                # Record pending edit - content comes from toolUseResult
                                $pendingEdits[$block.id] = [PSCustomObject]@{
                                    FilePath    = $filePath
                                    LineNumber  = $lineNum
                                    Timestamp   = $timestamp
                                    SourceFile  = $sf.Path
                                    SourceAgent = $sf.SourceAgent
                                    SessionId   = $sf.SessionId
                                    Project     = $sf.Project
                                    OldString   = $block.input.old_string
                                    NewString   = $block.input.new_string
                                }
                            }
                            "Read" {
                                # Read tool_use has file_path but no content yet -
                                # content is in the toolUseResult. We record pending
                                # reads the same way as edits.
                                $filePath = $block.input.file_path
                                if ($FileFilter -and $filePath -notlike "*$FileFilter*") { continue }

                                $pendingEdits[$block.id] = [PSCustomObject]@{
                                    FilePath    = $filePath
                                    LineNumber  = $lineNum
                                    Timestamp   = $timestamp
                                    SourceFile  = $sf.Path
                                    SourceAgent = $sf.SourceAgent
                                    SessionId   = $sf.SessionId
                                    Project     = $sf.Project
                                    IsRead      = $true
                                }
                            }
                        }
                    }
                }
            }

            # User messages - extract toolUseResult for Edit and Read
            if ($event.type -eq "user") {
                # Match tool_use_id from tool_result blocks
                $toolUseId = $null
                if ($event.message.content -is [array]) {
                    foreach ($block in $event.message.content) {
                        if ($block.type -eq "tool_result" -and $block.tool_use_id) {
                            $toolUseId = $block.tool_use_id
                            break
                        }
                    }
                }

                $result = $event.toolUseResult

                if ($result -and $toolUseId -and $pendingEdits.ContainsKey($toolUseId)) {
                    $pending = $pendingEdits[$toolUseId]

                    if ($pending.IsRead) {
                        # Read result
                        $fileContent = $null
                        $isPartial = $false
                        if ($result.file.content) {
                            $fileContent = $result.file.content
                            if ($result.file.startLine -and $result.file.totalLines) {
                                $readLines = $result.file.numLines
                                $totalLines = $result.file.totalLines
                                if ($readLines -lt $totalLines) {
                                    $isPartial = $true
                                }
                            }
                        }

                        if ($fileContent) {
                            $operations += [PSCustomObject]@{
                                FilePath      = $pending.FilePath
                                Operation     = "Read"
                                LineNumber    = $pending.LineNumber
                                Timestamp     = $pending.Timestamp
                                Content       = $fileContent
                                ToolUseId     = $toolUseId
                                IsPartialRead = $isPartial
                                SourceFile    = $pending.SourceFile
                                SourceAgent   = $pending.SourceAgent
                                SessionId     = $pending.SessionId
                                Project       = $pending.Project
                            }
                        }
                    } else {
                        # Edit result - originalFile contains full file before edit
                        $fileContent = $result.originalFile

                        # Apply the edit to produce post-edit content
                        if ($fileContent -and $pending.OldString -and $pending.NewString) {
                            $fileContent = $fileContent.Replace($pending.OldString, $pending.NewString)
                        }

                        if ($fileContent) {
                            $operations += [PSCustomObject]@{
                                FilePath      = $pending.FilePath
                                Operation     = "Edit"
                                LineNumber    = $pending.LineNumber
                                Timestamp     = $pending.Timestamp
                                Content       = $fileContent
                                ToolUseId     = $toolUseId
                                IsPartialRead = $false
                                SourceFile    = $pending.SourceFile
                                SourceAgent   = $pending.SourceAgent
                                SessionId     = $pending.SessionId
                                Project       = $pending.Project
                                OldString     = $pending.OldString
                                NewString     = $pending.NewString
                            }
                        }
                    }

                    $pendingEdits.Remove($toolUseId)
                }
            }
        }
    }

    return ,$operations
}

# ============================================================================
# MODE: -SearchFile
# ============================================================================

if ($SearchFile) {
    if (-not $Quiet) {
        Write-Host ""
        Write-Host "Searching file paths for '$SearchFile' across sessions..." -ForegroundColor Cyan
    }

    $findParams = @{
        BaseDir       = $projectsDir
        Id            = $SessionId
        MostRecent    = $false
        ProjectFilter = $Project
        DaysBack      = $Days
        ReturnAll     = $true
    }
    $allSessions = Find-Sessions @findParams
    if (-not $allSessions) {
        Write-Host "No sessions found" -ForegroundColor Yellow
        exit 1
    }

    $matchingSessions = @()
    $escapedSearch = [regex]::Escape($SearchFile)

    foreach ($s in $allSessions) {
        # Level 1 pre-filter: quick check before loading entire file
        $hasMatch = Select-String -Path $s.Path -Pattern $escapedSearch -Quiet 2>$null
        if (-not $hasMatch) {
            # Also check subagent files
            $sessionDir = Join-Path (Split-Path $s.Path) $s.SessionId
            $subagentsDir = Join-Path $sessionDir "subagents"
            if (Test-Path $subagentsDir) {
                $subFiles = Get-ChildItem -Path $subagentsDir -Filter "agent-*.jsonl" -File 2>$null
                foreach ($subF in $subFiles) {
                    $hasMatch = Select-String -Path $subF.FullName -Pattern $escapedSearch -Quiet 2>$null
                    if ($hasMatch) { break }
                }
            }
        }
        if (-not $hasMatch) { continue }

        # Found a match - count operations
        $sessionFiles = Get-SessionFiles -Session $s
        $ops = Get-FileOperations -SessionFiles $sessionFiles -FileFilter $SearchFile
        if ($ops.Count -gt 0) {
            $matchingSessions += [PSCustomObject]@{
                Session    = $s
                Operations = $ops
            }
        }
    }

    if ($matchingSessions.Count -eq 0) {
        Write-Host "No file operations found matching '$SearchFile'" -ForegroundColor Yellow
        exit 1
    }

    if ($Json) {
        $output = @()
        foreach ($ms in $matchingSessions) {
            $output += @{
                sessionId  = $ms.Session.SessionId
                project    = $ms.Session.Project
                modified   = $ms.Session.Modified.ToString("o")
                operations = @($ms.Operations | ForEach-Object {
                    @{
                        filePath    = $_.FilePath
                        operation   = $_.Operation
                        timestamp   = $_.Timestamp
                        sourceAgent = $_.SourceAgent
                        partial     = $_.IsPartialRead
                    }
                })
            }
        }
        Write-Output (ConvertTo-Json -Depth 5 $output)
        exit 0
    }

    Write-Host ""
    Write-Host "Found $($matchingSessions.Count) session(s) with '$SearchFile'" -ForegroundColor Green
    Write-Host ""

    foreach ($ms in $matchingSessions) {
        $s = $ms.Session
        Write-Host "  Session: $($s.SessionId)" -ForegroundColor Cyan
        Write-Host "    Project:  $($s.Project)" -ForegroundColor Gray
        Write-Host "    Modified: $($s.Modified.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor Gray

        $opSummary = @{}
        foreach ($op in $ms.Operations) {
            $key = $op.Operation
            if (-not $opSummary.ContainsKey($key)) { $opSummary[$key] = 0 }
            $opSummary[$key]++
        }
        $summaryStr = ($opSummary.GetEnumerator() | ForEach-Object { "$($_.Key):$($_.Value)" }) -join ", "
        Write-Host "    Operations: $summaryStr" -ForegroundColor Gray

        $uniqueFiles = @($ms.Operations | Select-Object -ExpandProperty FilePath -Unique)
        foreach ($fp in $uniqueFiles) {
            Write-Host "      $fp" -ForegroundColor Gray
        }
        Write-Host ""
    }

    exit 0
}

# ============================================================================
# MODE: -SearchText
# ============================================================================

if ($SearchText) {
    if (-not $Quiet) {
        Write-Host ""
        Write-Host "Searching file contents for '$SearchText' across sessions..." -ForegroundColor Cyan
    }

    # Validate regex
    try {
        [void]("" -match $SearchText)
    } catch {
        Write-Host "Invalid regex pattern: $($_.Exception.Message)" -ForegroundColor Red
        exit 2
    }

    $findParams = @{
        BaseDir       = $projectsDir
        Id            = $SessionId
        MostRecent    = $false
        ProjectFilter = $Project
        DaysBack      = $Days
        ReturnAll     = $true
    }
    $allSessions = Find-Sessions @findParams
    if (-not $allSessions) {
        Write-Host "No sessions found" -ForegroundColor Yellow
        exit 1
    }

    $matchingSessions = @()

    foreach ($s in $allSessions) {
        # Level 1 pre-filter: does this session contain a regex match?
        # Select-String supports regex natively, so the user's pattern works directly.
        $hasMatch = Select-String -Path $s.Path -Pattern $SearchText -Quiet 2>$null
        if (-not $hasMatch) {
            $sessionDir = Join-Path (Split-Path $s.Path) $s.SessionId
            $subagentsDir = Join-Path $sessionDir "subagents"
            if (Test-Path $subagentsDir) {
                $subFiles = Get-ChildItem -Path $subagentsDir -Filter "agent-*.jsonl" -File 2>$null
                foreach ($subF in $subFiles) {
                    $hasMatch = Select-String -Path $subF.FullName -Pattern $SearchText -Quiet 2>$null
                    if ($hasMatch) { break }
                }
            }
        }
        if (-not $hasMatch) { continue }

        # Parse all file operations (no path filter)
        $sessionFiles = Get-SessionFiles -Session $s
        $ops = Get-FileOperations -SessionFiles $sessionFiles

        # Search content of each operation
        $hits = @()
        foreach ($op in $ops) {
            if (-not $op.Content) { continue }
            if ($op.Content -notmatch $SearchText) { continue }

            # Find matching line and build snippet
            $contentLines = $op.Content -split "`n"
            $matchLine = $null
            $matchLineNum = 0
            for ($i = 0; $i -lt $contentLines.Count; $i++) {
                if ($contentLines[$i] -match $SearchText) {
                    $matchLine = $contentLines[$i].Trim()
                    $matchLineNum = $i + 1
                    break
                }
            }

            $hits += [PSCustomObject]@{
                FilePath    = $op.FilePath
                Operation   = $op.Operation
                Timestamp   = $op.Timestamp
                SourceAgent = $op.SourceAgent
                MatchLine   = $matchLineNum
                Snippet     = $matchLine
                IsPartial   = $op.IsPartialRead
            }
        }

        if ($hits.Count -gt 0) {
            $matchingSessions += [PSCustomObject]@{
                Session = $s
                Hits    = $hits
            }
        }
    }

    if ($matchingSessions.Count -eq 0) {
        Write-Host "No file contents matching '$SearchText'" -ForegroundColor Yellow
        exit 1
    }

    if ($Json) {
        $output = @()
        foreach ($ms in $matchingSessions) {
            $output += @{
                sessionId = $ms.Session.SessionId
                project   = $ms.Session.Project
                modified  = $ms.Session.Modified.ToString("o")
                hits      = @($ms.Hits | ForEach-Object {
                    @{
                        filePath    = $_.FilePath
                        operation   = $_.Operation
                        timestamp   = $_.Timestamp
                        sourceAgent = $_.SourceAgent
                        matchLine   = $_.MatchLine
                        snippet     = $_.Snippet
                    }
                })
            }
        }
        Write-Output (ConvertTo-Json -Depth 5 $output)
        exit 0
    }

    $totalHits = ($matchingSessions | ForEach-Object { $_.Hits.Count } | Measure-Object -Sum).Sum
    Write-Host ""
    Write-Host "Found $totalHits match(es) across $($matchingSessions.Count) session(s)" -ForegroundColor Green
    Write-Host ""

    foreach ($ms in $matchingSessions) {
        $s = $ms.Session
        Write-Host "  Session: $($s.SessionId)" -ForegroundColor Cyan
        Write-Host "    Project:  $($s.Project)" -ForegroundColor Gray
        Write-Host "    Modified: $($s.Modified.ToString('yyyy-MM-dd HH:mm'))" -ForegroundColor Gray

        # Deduplicate by file path, show each file once with first match snippet
        $byFile = @{}
        foreach ($hit in $ms.Hits) {
            $key = $hit.FilePath
            if (-not $byFile.ContainsKey($key)) {
                $byFile[$key] = @{ Count = 0; First = $hit }
            }
            $byFile[$key].Count++
        }

        foreach ($entry in ($byFile.GetEnumerator() | Sort-Object { $_.Value.First.Timestamp })) {
            $hit = $entry.Value.First
            $cnt = $entry.Value.Count
            $opColor = switch ($hit.Operation) {
                "Write" { "Green" }
                "Edit"  { "Yellow" }
                "Read"  { "Gray" }
            }
            $countSuffix = if ($cnt -gt 1) { " ($cnt versions)" } else { "" }
            Write-Host "    $($entry.Key)$countSuffix" -ForegroundColor $opColor

            if ($hit.Snippet) {
                $snippet = $hit.Snippet
                if ($snippet.Length -gt 100) { $snippet = $snippet.Substring(0, 100) + "..." }
                Write-Host "      L$($hit.MatchLine): $snippet" -ForegroundColor DarkGray
            }
        }
        Write-Host ""
    }

    exit 0
}

# ============================================================================
# RESOLVE SESSION (for modes that need one)
# ============================================================================

$session = Find-Sessions -BaseDir $projectsDir -Id $SessionId -MostRecent:$Recent -ProjectFilter $Project -DaysBack $Days

if (-not $session) {
    $msg = if ($SessionId) { "Session '$SessionId' not found" } else { "No sessions found" }
    if ($Project) { $msg += " in project '$Project'" }
    Write-Host $msg -ForegroundColor Red
    exit 2
}

$sessionFiles = Get-SessionFiles -Session $session

if (-not $Quiet) {
    Write-Host ""
    Write-Host "Session: $($session.SessionId)" -ForegroundColor Cyan
    Write-Host "  Project: $($session.Project)" -ForegroundColor Gray
    Write-Host "  Files:   $($sessionFiles.Count) (1 main + $($sessionFiles.Count - 1) subagent)" -ForegroundColor Gray
    Write-Host ""
}

# ============================================================================
# MODE: -List
# ============================================================================

if ($List) {
    $ops = Get-FileOperations -SessionFiles $sessionFiles

    if ($ops.Count -eq 0) {
        Write-Host "No file operations found in this session" -ForegroundColor Yellow
        exit 1
    }

    if ($Json) {
        $output = @($ops | ForEach-Object {
            @{
                filePath    = $_.FilePath
                operation   = $_.Operation
                lineNumber  = $_.LineNumber
                timestamp   = $_.Timestamp
                sourceAgent = $_.SourceAgent
                hasContent  = ($null -ne $_.Content -and $_.Content.Length -gt 0)
                partial     = $_.IsPartialRead
            }
        })
        Write-Output (ConvertTo-Json -Depth 3 $output)
        exit 0
    }

    # Group by file
    $byFile = @{}
    foreach ($op in $ops) {
        $key = $op.FilePath
        if (-not $byFile.ContainsKey($key)) { $byFile[$key] = @() }
        $byFile[$key] += $op
    }

    Write-Host "=== File Operations ($($ops.Count) total, $($byFile.Count) files) ===" -ForegroundColor Yellow
    Write-Host ""

    foreach ($entry in ($byFile.GetEnumerator() | Sort-Object { $_.Value[0].Timestamp })) {
        $filePath = $entry.Key
        $fileOps = $entry.Value

        Write-Host "  $filePath" -ForegroundColor Cyan

        foreach ($op in $fileOps) {
            $opColor = switch ($op.Operation) {
                "Write" { "Green" }
                "Edit"  { "Yellow" }
                "Read"  { "Gray" }
            }
            $partial = if ($op.IsPartialRead) { " (partial)" } else { "" }
            $hasContent = if ($op.Content) { "" } else { " [no content]" }
            $agent = if ($op.SourceAgent -ne "lead") { " [$($op.SourceAgent)]" } else { "" }
            $time = if ($op.Timestamp) {
                try { ([datetime]::Parse($op.Timestamp)).ToString("HH:mm:ss") } catch { "" }
            } else { "" }

            Write-Host ("    {0,-6} {1}{2}{3}{4}" -f $op.Operation, $time, $partial, $hasContent, $agent) -ForegroundColor $opColor
        }
        Write-Host ""
    }

    # Summary
    $writeCnt = @($ops | Where-Object { $_.Operation -eq "Write" }).Count
    $editCnt = @($ops | Where-Object { $_.Operation -eq "Edit" }).Count
    $readCnt = @($ops | Where-Object { $_.Operation -eq "Read" }).Count
    Write-Host "Summary: $writeCnt Write, $editCnt Edit, $readCnt Read across $($byFile.Count) files" -ForegroundColor Gray

    exit 0
}

# ============================================================================
# MODE: -Timeline
# ============================================================================

if ($Timeline) {
    $ops = Get-FileOperations -SessionFiles $sessionFiles -FileFilter $Timeline

    # Further filter to exact path match (FileFilter uses -like wildcard)
    $normalizedTarget = $Timeline.Replace('\', '/')
    $ops = @($ops | Where-Object {
        $_.FilePath.Replace('\', '/') -eq $normalizedTarget -or
        $_.FilePath -like "*$Timeline*"
    })

    if ($ops.Count -eq 0) {
        Write-Host "No operations found for '$Timeline'" -ForegroundColor Yellow
        exit 1
    }

    if ($Json) {
        $output = @($ops | ForEach-Object {
            $entry = @{
                filePath    = $_.FilePath
                operation   = $_.Operation
                lineNumber  = $_.LineNumber
                timestamp   = $_.Timestamp
                sourceAgent = $_.SourceAgent
                hasContent  = ($null -ne $_.Content -and $_.Content.Length -gt 0)
                partial     = $_.IsPartialRead
                sourceFile  = $_.SourceFile
            }
            if ($_.Content) {
                $entry['contentLength'] = $_.Content.Length
            }
            if ($_.OldString) {
                $entry['oldString'] = $_.OldString
                $entry['newString'] = $_.NewString
            }
            $entry
        })
        Write-Output (ConvertTo-Json -Depth 3 $output)
        exit 0
    }

    Write-Host "=== Timeline: $Timeline ===" -ForegroundColor Yellow
    Write-Host ""

    $idx = 0
    foreach ($op in $ops) {
        $idx++
        $opColor = switch ($op.Operation) {
            "Write" { "Green" }
            "Edit"  { "Yellow" }
            "Read"  { "Gray" }
        }

        $time = if ($op.Timestamp) {
            try { ([datetime]::Parse($op.Timestamp)).ToString("yyyy-MM-dd HH:mm:ss") } catch { $op.Timestamp }
        } else { "(no timestamp)" }

        $agent = if ($op.SourceAgent -ne "lead") { " [$($op.SourceAgent)]" } else { "" }
        $partial = if ($op.IsPartialRead) { " (partial read)" } else { "" }

        Write-Host ("  #{0} {1,-6} {2}{3}{4}" -f $idx, $op.Operation, $time, $agent, $partial) -ForegroundColor $opColor

        if ($op.Content) {
            $contentLen = $op.Content.Length
            $lineCount = ($op.Content -split "`n").Count
            Write-Host "      Content: $contentLen chars, $lineCount lines" -ForegroundColor Gray
        } else {
            Write-Host "      Content: (not available)" -ForegroundColor DarkGray
        }

        if ($op.Operation -eq "Edit" -and $op.OldString) {
            $oldSnippet = $op.OldString
            if ($oldSnippet.Length -gt 60) { $oldSnippet = $oldSnippet.Substring(0, 60) + "..." }
            $newSnippet = $op.NewString
            if ($newSnippet.Length -gt 60) { $newSnippet = $newSnippet.Substring(0, 60) + "..." }
            Write-Host "      Edit: '$oldSnippet' -> '$newSnippet'" -ForegroundColor DarkYellow
        }

        Write-Host "      Source: line $($op.LineNumber) in $(Split-Path $op.SourceFile -Leaf)" -ForegroundColor DarkGray
        Write-Host ""
    }

    exit 0
}

# ============================================================================
# MODE: -Extract
# ============================================================================

if ($Extract) {
    $ops = Get-FileOperations -SessionFiles $sessionFiles -FileFilter $Extract

    # Filter to exact or closest match
    $normalizedTarget = $Extract.Replace('\', '/')
    $ops = @($ops | Where-Object {
        $_.FilePath.Replace('\', '/') -eq $normalizedTarget -or
        $_.FilePath -like "*$Extract*"
    })

    if ($ops.Count -eq 0) {
        Write-Host "No operations found for '$Extract'" -ForegroundColor Yellow
        exit 1
    }

    # Filter to operations with content
    $opsWithContent = @($ops | Where-Object { $null -ne $_.Content -and $_.Content.Length -gt 0 })

    if ($opsWithContent.Count -eq 0) {
        Write-Host "Operations found but none have extractable content" -ForegroundColor Yellow
        Write-Host "  Found $($ops.Count) operations for this file, but content was not captured" -ForegroundColor Gray
        exit 1
    }

    if ($All) {
        if ($Json) {
            $output = @($opsWithContent | ForEach-Object {
                @{
                    filePath    = $_.FilePath
                    operation   = $_.Operation
                    timestamp   = $_.Timestamp
                    sourceAgent = $_.SourceAgent
                    partial     = $_.IsPartialRead
                    content     = $_.Content
                }
            })
            Write-Output (ConvertTo-Json -Depth 3 $output)
            exit 0
        }

        Write-Host "=== All versions of: $Extract ===" -ForegroundColor Yellow
        Write-Host ""

        $idx = 0
        foreach ($op in $opsWithContent) {
            $idx++
            $opColor = switch ($op.Operation) {
                "Write" { "Green" }
                "Edit"  { "Yellow" }
                "Read"  { "Gray" }
            }
            $time = if ($op.Timestamp) {
                try { ([datetime]::Parse($op.Timestamp)).ToString("yyyy-MM-dd HH:mm:ss") } catch { $op.Timestamp }
            } else { "" }
            $partial = if ($op.IsPartialRead) { " (PARTIAL)" } else { "" }

            Write-Host ("--- Version #{0}: {1} at {2}{3} ---" -f $idx, $op.Operation, $time, $partial) -ForegroundColor $opColor
            Write-Output $op.Content
            Write-Host ""
        }
        exit 0
    }

    # Default: most recent operation with content
    $latest = $opsWithContent[-1]

    if ($Json) {
        $output = @{
            filePath    = $latest.FilePath
            operation   = $latest.Operation
            timestamp   = $latest.Timestamp
            sourceAgent = $latest.SourceAgent
            partial     = $latest.IsPartialRead
            content     = $latest.Content
        }
        Write-Output (ConvertTo-Json -Depth 3 $output)
        exit 0
    }

    if (-not $Quiet) {
        $time = if ($latest.Timestamp) {
            try { ([datetime]::Parse($latest.Timestamp)).ToString("yyyy-MM-dd HH:mm:ss") } catch { $latest.Timestamp }
        } else { "" }
        $partial = if ($latest.IsPartialRead) { " (PARTIAL READ)" } else { "" }
        Write-Host "--- $($latest.Operation) at $time$partial ---" -ForegroundColor Green
    }

    Write-Output $latest.Content
    exit 0
}

# ============================================================================
# MODE: -Recover
# ============================================================================

if ($Recover) {
    $ops = Get-FileOperations -SessionFiles $sessionFiles

    # Only recover from Write and Edit operations (not Read snapshots)
    $writeEditOps = @($ops | Where-Object {
        ($_.Operation -eq "Write" -or $_.Operation -eq "Edit") -and
        $null -ne $_.Content -and $_.Content.Length -gt 0
    })

    if ($writeEditOps.Count -eq 0) {
        Write-Host "No recoverable Write/Edit operations found in this session" -ForegroundColor Yellow
        exit 1
    }

    # Group by file, take the most recent operation per file
    $latestByFile = @{}
    foreach ($op in $writeEditOps) {
        $normalizedPath = $op.FilePath.Replace('\', '/')
        $latestByFile[$normalizedPath] = $op
    }

    if ($Json) {
        $output = @{
            outputDir = $OutputDir
            files     = @()
        }
        foreach ($entry in $latestByFile.GetEnumerator()) {
            $op = $entry.Value
            $safeName = $op.FilePath -replace '[:\\]', '_' -replace '/', '_'
            $safeName = $safeName -replace '^_+', ''
            $output.files += @{
                originalPath = $op.FilePath
                recoveredAs  = $safeName
                operation    = $op.Operation
                timestamp    = $op.Timestamp
                contentLength = $op.Content.Length
            }
        }
        Write-Output (ConvertTo-Json -Depth 3 $output)
        exit 0
    }

    # Create output directory
    if (-not (Test-Path $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    Write-Host "=== Recovering $($latestByFile.Count) files ===" -ForegroundColor Yellow
    Write-Host "  Output: $OutputDir" -ForegroundColor Gray
    Write-Host ""

    $recovered = 0
    $failed = 0

    foreach ($entry in ($latestByFile.GetEnumerator() | Sort-Object { $_.Value.FilePath })) {
        $op = $entry.Value
        $safeName = $op.FilePath -replace '[:\\]', '_' -replace '/', '_'
        $safeName = $safeName -replace '^_+', ''
        $outPath = Join-Path $OutputDir $safeName

        try {
            [System.IO.File]::WriteAllText($outPath, $op.Content, [System.Text.UTF8Encoding]::new($false))
            $recovered++
            Write-Host "  OK  $($op.FilePath)" -ForegroundColor Green
            Write-Host "      -> $safeName ($($op.Operation))" -ForegroundColor Gray
        } catch {
            $failed++
            Write-Host "  FAIL  $($op.FilePath): $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    Write-Host ""
    Write-Host "Recovered $recovered files" -ForegroundColor Green
    if ($failed -gt 0) {
        Write-Host "Failed: $failed" -ForegroundColor Red
        exit 1
    }

    exit 0
}
