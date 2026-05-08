# Parse-DebugLogs.ps1
# Parse Claude Code debug logs for comprehensive analysis
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File Parse-DebugLogs.ps1 [options]
#
# Options:
#   -Path <dir>       Debug log directory (default: $CLAUDE_CONFIG_DIR/debug)
#   -Recent <n>       Analyze only the last n sessions
#   -Days <n>         Analyze only logs from the last n days
#   -Tool <name>      Filter to specific tool (e.g., Bash, Read)
#   -Reason <pattern> Filter to reasons matching pattern (e.g., "copilot", "safe")
#   -Details          Show per-session breakdown
#   -Reasons <bool>   Show permission decision reasons (default: $true)
#   -Performance      Show performance metrics (cache breaks, stalls)
#   -Errors           Show error/warning summary
#   -Health           Quick health check - returns exit code (0=ok, 1=warn, 2=error)
#   -Summary          One-line summary output
#   -Json             Output as JSON (for programmatic use)
#   -Quiet            Filter out noise errors (optional files, Windows symlink issues)
#   -All              Enable all analysis options
#
# Examples:
#   Parse-DebugLogs.ps1                         # Standard summary
#   Parse-DebugLogs.ps1 -Recent 5               # Last 5 sessions (reasons on by default)
#   Parse-DebugLogs.ps1 -Days 3 -All            # Full analysis of last 3 days
#   Parse-DebugLogs.ps1 -Health                  # Quick health check
#   Parse-DebugLogs.ps1 -Tool Bash -Recent 10   # Bash calls in last 10 sessions
#   Parse-DebugLogs.ps1 -Reason copilot         # Calls using Copilot fallback
#   Parse-DebugLogs.ps1 -Summary -Days 1        # One-line today's summary

param(
    [string]$Path = "",
    [int]$Recent = 0,
    [int]$Days = 0,
    [string]$Tool = "",
    [string]$Reason = "",
    [switch]$Details,
    [bool]$Reasons = $true,
    [switch]$Performance,
    [switch]$Errors,
    [switch]$Health,
    [switch]$Summary,
    [switch]$Json,
    [switch]$Quiet,
    [switch]$All
)

if ($All) {
    $Details = $true
    $Reasons = $true
    $Performance = $true
    $Errors = $true
}

# Health mode implies errors, performance, and quiet (to suppress noise)
if ($Health) {
    $Errors = $true
    $Performance = $true
    $Quiet = $true
}

# Resolve debug directory
if (-not $Path) {
    $Path = if ($env:CLAUDE_CONFIG_DIR) {
        Join-Path $env:CLAUDE_CONFIG_DIR "debug"
    } else {
        Join-Path $env:USERPROFILE ".claude\debug"
    }
}

if (-not (Test-Path $Path)) {
    Write-Host "Debug directory not found: $Path" -ForegroundColor Red
    exit 1
}

# Get log files, sorted by modification time (newest first)
$logFiles = Get-ChildItem -Path $Path -Filter "*.txt" | Sort-Object LastWriteTime -Descending

if ($Days -gt 0) {
    $cutoff = (Get-Date).AddDays(-$Days)
    $logFiles = $logFiles | Where-Object { $_.LastWriteTime -ge $cutoff }
}

if ($Recent -gt 0) {
    $logFiles = $logFiles | Select-Object -First $Recent
}

if ($logFiles.Count -eq 0) {
    if ($Json) {
        Write-Output ('{"error":"No debug logs found","path":"' + $Path + '"}')
    } elseif (-not $Summary -and -not $Health) {
        Write-Host "No debug logs found in: $Path" -ForegroundColor Yellow
    }
    exit 0
}

# Suppress header for Summary/Json/Health modes
if (-not $Summary -and -not $Json -and -not $Health) {
    Write-Host ""
    Write-Host "Analyzing $($logFiles.Count) debug log(s)" -ForegroundColor Cyan
    if ($Days -gt 0) { Write-Host "  Time range: last $Days day(s)" -ForegroundColor Gray }
    if ($Recent -gt 0) { Write-Host "  Limited to: $Recent most recent" -ForegroundColor Gray }
    if ($Tool) { Write-Host "  Tool filter: $Tool" -ForegroundColor Gray }
    if ($Reason) { Write-Host "  Reason filter: $Reason" -ForegroundColor Gray }
    Write-Host ""
}

# Aggregate statistics
$toolCounts = @{}
$reasonCounts = @{}
$toolReasonCounts = @{}
$decisionCounts = @{ allow = 0; deny = 0; ask = 0 }
$errorCounts = @{}
$warningCounts = @{}
$cacheBreaks = 0
$streamingStalls = @()
$startupTimes = @{}
$sessionStats = @()

foreach ($file in $logFiles) {
    $lines = Get-Content $file.FullName
    $sessionId = $file.BaseName
    $sessionToolCounts = @{}
    $sessionErrors = 0
    $sessionWarnings = 0

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]

        # Tool calls: "Hook PreToolUse:<Tool> (PreToolUse) success:"
        # Next line contains JSON with permissionDecisionReason
        if ($line -match 'Hook PreToolUse:(\w+)\s+\(PreToolUse\)\s+success:') {
            $toolName = $matches[1]

            # Apply tool filter if specified
            if ($Tool -and $toolName -ne $Tool) { continue }

            # Check next line for reason (before counting, in case we need to filter)
            $reasonText = ""
            $decision = ""
            if ($i + 1 -lt $lines.Count) {
                $nextLine = $lines[$i + 1]
                if ($nextLine -match '"permissionDecisionReason"\s*:\s*"([^"]+)"') {
                    $reasonText = $matches[1]
                }
                if ($nextLine -match '"permissionDecision"\s*:\s*"(allow|deny|ask)"') {
                    $decision = $matches[1]
                }
            }

            # Apply reason filter if specified
            if ($Reason -and $reasonText -notmatch $Reason) { continue }

            # Count tool
            if (-not $toolCounts.ContainsKey($toolName)) { $toolCounts[$toolName] = 0 }
            $toolCounts[$toolName]++

            if (-not $sessionToolCounts.ContainsKey($toolName)) { $sessionToolCounts[$toolName] = 0 }
            $sessionToolCounts[$toolName]++

            # Count reason
            if ($reasonText) {
                if (-not $reasonCounts.ContainsKey($reasonText)) { $reasonCounts[$reasonText] = 0 }
                $reasonCounts[$reasonText]++

                $key = "$toolName|$reasonText"
                if (-not $toolReasonCounts.ContainsKey($key)) { $toolReasonCounts[$key] = 0 }
                $toolReasonCounts[$key]++
            }

            # Count decision
            if ($decision) {
                $decisionCounts[$decision]++
            }
        }

        # Errors
        if ($Errors -and $line -match '\[ERROR\]\s*(.+)') {
            $errorMsg = $matches[1]

            # Skip noise errors when -Quiet is specified
            $isNoise = $errorMsg -match 'scandir.*skills|remote-settings\.json|EPERM.*symlink'
            if ($Quiet -and $isNoise) { continue }

            $sessionErrors++

            # Extract error type with better categorization
            $errorType = switch -Regex ($errorMsg) {
                'MaxFileReadTokenExceededError' { 'MaxFileReadTokenExceededError'; break }
                'AbortError|aborted' { 'AbortError'; break }
                'RipgrepTimeout' { 'RipgrepTimeoutError'; break }
                'ENOENT.*skills|ENOENT.*remote-settings' { 'ENOENT (optional file - noise)'; break }
                'ENOENT' { 'ENOENT (file not found)'; break }
                'EPERM.*symlink' { 'EPERM (symlink - Windows noise)'; break }
                'EPERM' { 'EPERM (permission denied)'; break }
                'Lock file' { 'LockFileError'; break }
                'AxiosError|network' { 'NetworkError'; break }
                'SyntaxError' { 'SyntaxError'; break }
                default {
                    if ($errorMsg -match '^(\w+Error):') { $matches[1] }
                    else { "Other" }
                }
            }
            if (-not $errorCounts.ContainsKey($errorType)) { $errorCounts[$errorType] = 0 }
            $errorCounts[$errorType]++
        }

        # Plugin loading errors (from DEBUG lines, common noise)
        if ($Errors -and -not $Quiet -and $line -match 'Plugin.*not found in marketplace') {
            if (-not $errorCounts.ContainsKey('PluginNotFound (noise)')) { $errorCounts['PluginNotFound (noise)'] = 0 }
            $errorCounts['PluginNotFound (noise)']++
        }

        # Warnings
        if ($Errors -and $line -match '\[WARN\]\s*(.+)') {
            $sessionWarnings++
            $warnMsg = $matches[1]
            $warnType = if ($warnMsg -match '^(\[[\w\s]+\])') { $matches[1] } else { "General" }
            if (-not $warningCounts.ContainsKey($warnType)) { $warningCounts[$warnType] = 0 }
            $warningCounts[$warnType]++
        }

        # Cache breaks
        if ($Performance -and $line -match 'PROMPT CACHE BREAK') {
            $cacheBreaks++
        }

        # Streaming stalls
        if ($Performance -and $line -match 'Streaming stall detected:\s*([\d.]+)s') {
            $streamingStalls += [double]$matches[1]
        }

        # Startup timing
        if ($Performance -and $line -match '\[STARTUP\]\s*(.+)\s+(?:completed|loaded) in\s+(\d+)ms') {
            $phase = $matches[1].Trim()
            $ms = [int]$matches[2]
            if (-not $startupTimes.ContainsKey($phase)) { $startupTimes[$phase] = @() }
            $startupTimes[$phase] += $ms
        }
    }

    $sessionStats += [PSCustomObject]@{
        SessionId = $sessionId
        Date = $file.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
        TotalTools = ($sessionToolCounts.Values | Measure-Object -Sum).Sum
        Tools = $sessionToolCounts
        Errors = $sessionErrors
        Warnings = $sessionWarnings
    }
}

# =============================================================================
# OUTPUT
# =============================================================================

$totalTools = ($toolCounts.Values | Measure-Object -Sum).Sum
$totalDecisions = ($decisionCounts.Values | Measure-Object -Sum).Sum
$totalErrors = ($sessionStats | Measure-Object -Property Errors -Sum).Sum
$totalWarnings = ($sessionStats | Measure-Object -Property Warnings -Sum).Sum

# JSON Output Mode
if ($Json) {
    $output = @{
        sessions = $logFiles.Count
        toolCalls = $totalTools
        decisions = $totalDecisions
        errors = $totalErrors
        warnings = $totalWarnings
        tools = $toolCounts
        reasons = $reasonCounts
        decisionBreakdown = $decisionCounts
        cacheBreaks = $cacheBreaks
        streamingStalls = $streamingStalls.Count
    }
    Write-Output (ConvertTo-Json -Compress $output)
    $exitCode = if ($totalErrors -gt 0) { 2 } elseif ($totalWarnings -gt 10 -or $cacheBreaks -gt 5) { 1 } else { 0 }
    exit $exitCode
}

# Summary Output Mode (one-line)
if ($Summary) {
    $status = if ($totalErrors -gt 0) { "ERROR" } elseif ($totalWarnings -gt 10 -or $cacheBreaks -gt 5) { "WARN" } else { "OK" }
    Write-Output "${status}: $($logFiles.Count) sessions, $totalTools tools, $totalDecisions decisions, $totalErrors errors, $totalWarnings warnings, $cacheBreaks cache breaks"
    $exitCode = if ($totalErrors -gt 0) { 2 } elseif ($totalWarnings -gt 10 -or $cacheBreaks -gt 5) { 1 } else { 0 }
    exit $exitCode
}

# Health Check Mode
if ($Health) {
    $issues = @()

    if ($totalErrors -gt 0) {
        $issues += "$totalErrors errors"
    }
    if ($cacheBreaks -gt 5) {
        $issues += "$cacheBreaks cache breaks (>5)"
    }
    if ($streamingStalls.Count -gt 0) {
        $maxStall = ($streamingStalls | Measure-Object -Maximum).Maximum
        if ($maxStall -gt 30) {
            $issues += "streaming stall ${maxStall}s (>30s)"
        }
    }
    if ($totalWarnings -gt 20) {
        $issues += "$totalWarnings warnings (>20)"
    }

    if ($issues.Count -eq 0) {
        Write-Host "HEALTHY" -ForegroundColor Green
        Write-Host "  $($logFiles.Count) sessions analyzed, $totalTools tool calls, no issues detected" -ForegroundColor Gray
        exit 0
    } else {
        $severity = if ($totalErrors -gt 0) { "ERROR" } else { "WARNING" }
        $color = if ($totalErrors -gt 0) { "Red" } else { "Yellow" }
        Write-Host $severity -ForegroundColor $color
        foreach ($issue in $issues) {
            Write-Host "  - $issue" -ForegroundColor $color
        }
        $exitCode = if ($totalErrors -gt 0) { 2 } else { 1 }
        exit $exitCode
    }
}

# Tool Usage Summary
Write-Host "=== Tool Usage ===" -ForegroundColor Yellow
if ($totalTools -gt 0) {
    $toolCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        $pct = [math]::Round(($_.Value / $totalTools) * 100, 1)
        Write-Host ("  {0,-15} {1,6}  ({2,5}%)" -f $_.Key, $_.Value, $pct)
    }
} else {
    Write-Host "  No tool calls found" -ForegroundColor Gray
}
Write-Host ""

# Hook Decisions
if ($totalDecisions -gt 0) {
    Write-Host "=== Hook Decisions ===" -ForegroundColor Yellow
    Write-Host ("  Allow:  {0,6}  ({1}%)" -f $decisionCounts['allow'], [math]::Round($decisionCounts['allow'] / $totalDecisions * 100, 1))
    Write-Host ("  Deny:   {0,6}  ({1}%)" -f $decisionCounts['deny'], [math]::Round($decisionCounts['deny'] / $totalDecisions * 100, 1))
    Write-Host ("  Ask:    {0,6}  ({1}%)" -f $decisionCounts['ask'], [math]::Round($decisionCounts['ask'] / $totalDecisions * 100, 1))
    Write-Host ""
}

# Permission Reasons
if ($Reasons -and $reasonCounts.Count -gt 0) {
    Write-Host "=== Permission Reasons ===" -ForegroundColor Yellow
    $totalReasons = ($reasonCounts.Values | Measure-Object -Sum).Sum
    $reasonCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        $pct = [math]::Round(($_.Value / $totalReasons) * 100, 1)
        Write-Host ("  {0,6}  ({1,5}%)  {2}" -f $_.Value, $pct, $_.Key)
    }
    Write-Host ""

    # Tool -> Reason breakdown
    Write-Host "=== Tool -> Reason Mapping ===" -ForegroundColor Yellow
    $toolReasonCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 20 | ForEach-Object {
        $parts = $_.Key -split '\|'
        Write-Host ("  {0,6}  {1,-12} -> {2}" -f $_.Value, $parts[0], $parts[1])
    }
    Write-Host ""
}

# Performance Metrics
if ($Performance) {
    Write-Host "=== Performance ===" -ForegroundColor Yellow

    Write-Host ("  Cache breaks:     {0}" -f $cacheBreaks)

    if ($streamingStalls.Count -gt 0) {
        $avgStall = [math]::Round(($streamingStalls | Measure-Object -Average).Average, 1)
        $maxStall = [math]::Round(($streamingStalls | Measure-Object -Maximum).Maximum, 1)
        Write-Host ("  Streaming stalls: {0} (avg: {1}s, max: {2}s)" -f $streamingStalls.Count, $avgStall, $maxStall)
    } else {
        Write-Host "  Streaming stalls: 0"
    }

    if ($startupTimes.Count -gt 0) {
        Write-Host ""
        Write-Host "  Startup timing (avg):" -ForegroundColor Gray
        $startupTimes.GetEnumerator() | ForEach-Object {
            $avg = [math]::Round(($_.Value | Measure-Object -Average).Average, 0)
            Write-Host ("    {0,-30} {1,6}ms" -f $_.Key, $avg)
        }
    }
    Write-Host ""
}

# Error Summary
if ($Errors -and ($errorCounts.Count -gt 0 -or $warningCounts.Count -gt 0)) {
    Write-Host "=== Errors & Warnings ===" -ForegroundColor Yellow

    if ($errorCounts.Count -gt 0) {
        Write-Host "  Errors:" -ForegroundColor Red
        $errorCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10 | ForEach-Object {
            Write-Host ("    {0,6}  {1}" -f $_.Value, $_.Key)
        }
    }

    if ($warningCounts.Count -gt 0) {
        Write-Host "  Warnings:" -ForegroundColor DarkYellow
        $warningCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 10 | ForEach-Object {
            Write-Host ("    {0,6}  {1}" -f $_.Value, $_.Key)
        }
    }
    Write-Host ""
}

# Per-session details
if ($Details) {
    Write-Host "=== Per-Session Details ===" -ForegroundColor Yellow
    foreach ($session in $sessionStats | Sort-Object Date -Descending | Select-Object -First 10) {
        Write-Host ""
        $idPreview = $session.SessionId.Substring(0, [Math]::Min(8, $session.SessionId.Length))
        Write-Host "Session: $idPreview..." -ForegroundColor Cyan
        Write-Host ("  Date:     {0}" -f $session.Date)
        Write-Host ("  Tools:    {0}" -f $session.TotalTools)
        Write-Host ("  Errors:   {0}" -f $session.Errors)
        Write-Host ("  Warnings: {0}" -f $session.Warnings)
        if ($session.TotalTools -gt 0) {
            $topTools = $session.Tools.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 5
            Write-Host ("  Top:      {0}" -f (($topTools | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ", "))
        }
    }
    Write-Host ""
}

# Final summary
Write-Host "=== Summary ===" -ForegroundColor Yellow
Write-Host ("  Sessions:    {0}" -f $logFiles.Count)
Write-Host ("  Tool calls:  {0}" -f $totalTools)
Write-Host ("  Decisions:   {0}" -f $totalDecisions)
if ($Errors) {
    Write-Host ("  Errors:      {0}" -f $totalErrors)
    Write-Host ("  Warnings:    {0}" -f $totalWarnings)
}
Write-Host ""

# Exit with appropriate code
$exitCode = if ($totalErrors -gt 0) { 2 } elseif ($totalWarnings -gt 10 -or $cacheBreaks -gt 5) { 1 } else { 0 }
exit $exitCode
