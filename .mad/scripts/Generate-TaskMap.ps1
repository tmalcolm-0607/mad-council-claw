<#
.SYNOPSIS
    Parse all specs/*/tasks.md files to produce a unified task map.

.DESCRIPTION
    Extracts task structure from markdown checkboxes grouped by phase and user
    story headers. Generates .mad/task-map.json and .mad/task-map.md with
    cross-feature computed views (conflicts, blocked queue, next available).

.PARAMETER RepoRoot
    Root directory of the CCGHCP repository. Default: C:\source\CCGHCP

.PARAMETER JsonOnly
    Output JSON to stdout instead of writing files.

.EXAMPLE
    .\Generate-TaskMap.ps1
    .\Generate-TaskMap.ps1 -RepoRoot C:\source\CCGHCP -JsonOnly

.NOTES
    Run from repository root or specify -RepoRoot.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepoRoot = "C:\source\CCGHCP",

    [Parameter()]
    [switch]$JsonOnly
)

$ErrorActionPreference = 'Stop'

# Validate repo root
if (-not (Test-Path (Join-Path $RepoRoot "specs"))) {
    Write-Error "specs/ directory not found under '$RepoRoot'. Specify -RepoRoot."
}

$specsDir = Join-Path $RepoRoot "specs"
$outputDir = Join-Path $RepoRoot ".mad"

# --- Parse tasks from all spec directories ---
$allTasks = [System.Collections.ArrayList]::new()
$fileToTasks = @{}

$specDirs = Get-ChildItem $specsDir -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne "ideas" -and $_.Name -ne "shared" -and $_.Name -ne "main" }

foreach ($dir in $specDirs) {
    $tasksPath = Join-Path $dir.FullName "tasks.md"
    if (-not (Test-Path $tasksPath)) { continue }

    $featureId = $dir.Name
    # Extract the numeric prefix for global IDs
    $specNumber = if ($featureId -match '^(\d+)') { $Matches[1] } else { $featureId }

    $tasksContent = Get-Content $tasksPath -ErrorAction SilentlyContinue
    if (-not $tasksContent) { continue }

    [int]$currentPhase = 0
    $currentUserStory = ""
    [int]$taskSequence = 0
    $lastTaskIndex = -1

    foreach ($line in $tasksContent) {
        # Phase headers: ## Phase N or ## Phase N:
        if ($line -match '^##\s+Phase\s+(\d+)') {
            $currentPhase = [int]$Matches[1]
            $currentUserStory = ""
            continue
        }

        # User story headers: ### US1 or ### User Story 1 or ### US1 + US2
        if ($line -match '^###\s+(?:US|User\s*Story\s*)(\d+)') {
            $currentUserStory = "US$($Matches[1])"
            continue
        }
        # Also detect user story subsections like ### UI Tasks or ### API Tasks
        if ($line -match '^###\s+(UI|API|Shared|Infrastructure)\s+Tasks') {
            # Keep current user story, these are sub-groupings
            continue
        }

        # Task lines: - [x] or - [ ] with **T###** or **GATE-###**
        if ($line -match '^\s*-\s+\[(x|X|\s|!)\]\s+\*\*((T|GATE-)[\w.-]+)\*\*(.*)') {
            $taskSequence++
            $checkState = $Matches[1]
            $taskId = $Matches[2]
            $taskBody = $Matches[4].Trim()

            # Determine status
            $taskStatus = switch ($checkState) {
                'x' { "completed"; break }
                'X' { "completed"; break }
                '!' { "blocked"; break }
                default { "pending" }
            }

            # Check for [P] parallel marker
            $isParallel = ($taskBody -match '\[P\]')

            # Check for [!SURFACE] marker
            $isSurface = ($taskBody -match '\[!SURFACE\]')

            # Extract user story markers from task body: [US1], [US2], [US1][US2]
            $taskUserStories = [System.Collections.ArrayList]::new()
            $usMatches = [regex]::Matches($taskBody, '\[US(\d+)\]')
            foreach ($m in $usMatches) {
                [void]$taskUserStories.Add("US$($m.Groups[1].Value)")
            }
            # Fall back to section-level user story
            if ($taskUserStories.Count -eq 0 -and $currentUserStory) {
                [void]$taskUserStories.Add($currentUserStory)
            }
            $userStoryStr = if ($taskUserStories.Count -gt 0) { $taskUserStories -join "," } else { "" }

            # Clean the subject text: remove markers like [P], [US1], [!SURFACE]
            $subject = $taskBody -replace '\[P\]\s*', '' -replace '\[US\d+\]\s*', '' -replace '\[!SURFACE\]\s*', ''
            # Remove leading colon or dash
            $subject = $subject -replace '^\s*[:\-]\s*', ''
            $subject = $subject.Trim()

            # Extract file references from the task body
            $taskFiles = [System.Collections.ArrayList]::new()
            $filePatterns = [regex]::Matches($taskBody, '`([A-Za-z][\w\-]+\.(?:cs|ts|tsx|js|jsx|json|csproj|sln|ps1|yml|yaml))`')
            foreach ($m in $filePatterns) {
                [void]$taskFiles.Add($m.Groups[1].Value)
            }

            # Build global ID
            $globalId = "$specNumber/$taskId"

            $task = [ordered]@{
                global_id      = $globalId
                feature_id     = $featureId
                task_id        = $taskId
                subject        = $subject
                status         = $taskStatus
                phase          = $currentPhase
                user_story     = $userStoryStr
                parallel       = [bool]$isParallel
                depends_on     = [System.Collections.ArrayList]::new()
                files          = $taskFiles
                verify_command = $null
                is_surface     = [bool]$isSurface
            }
            $lastTaskIndex = $allTasks.Add($task)

            # Track file-to-task mapping
            foreach ($f in $taskFiles) {
                if (-not $fileToTasks.ContainsKey($f)) {
                    $fileToTasks[$f] = [System.Collections.ArrayList]::new()
                }
                [void]$fileToTasks[$f].Add($globalId)
            }

            continue
        }

        # Pick up file references and verify commands from indented sub-lines
        if ($lastTaskIndex -ge 0 -and $line -match '^\s{2,}-\s+') {
            $lastTask = $allTasks[$lastTaskIndex]

            # Extract files from sub-bullets
            $subFiles = [regex]::Matches($line, '`([A-Za-z][\w\-./\\]+\.(?:cs|ts|tsx|js|jsx|json|csproj|sln|ps1|yml|yaml))`')
            foreach ($m in $subFiles) {
                $fileName = Split-Path $m.Groups[1].Value -Leaf
                if (-not $lastTask.files.Contains($fileName)) {
                    [void]$lastTask.files.Add($fileName)
                    if (-not $fileToTasks.ContainsKey($fileName)) {
                        $fileToTasks[$fileName] = [System.Collections.ArrayList]::new()
                    }
                    [void]$fileToTasks[$fileName].Add($lastTask.global_id)
                }
            }

            # Extract verify command
            if ($line -match '\*\*Verify\*\*:\s*(.+)') {
                $verifyText = $Matches[1].Trim()
                # Extract the backtick-quoted command if present
                if ($verifyText -match '^`([^`]+)`') {
                    $lastTask.verify_command = $Matches[1]
                }
                else {
                    $lastTask.verify_command = $verifyText
                }
            }

            # Extract dependencies from "Connects to" or "Intake" lines referencing T### IDs
            if ($line -match 'Connects\s+to|Intake|depends_on|Depends\s+on') {
                $depMatches = [regex]::Matches($line, '\b(T\d{3,4})\b')
                foreach ($m in $depMatches) {
                    $depId = "$specNumber/$($m.Groups[1].Value)"
                    if (-not $lastTask.depends_on.Contains($depId) -and $depId -ne $lastTask.global_id) {
                        [void]$lastTask.depends_on.Add($depId)
                    }
                }
            }
        }
    }
}

# --- Compute cross-feature views ---

# File conflicts: files touched by tasks from different features
$fileConflicts = [System.Collections.ArrayList]::new()
foreach ($key in $fileToTasks.Keys) {
    $taskIds = $fileToTasks[$key]
    $featureIds = @($taskIds | ForEach-Object { ($_ -split '/')[0] } | Sort-Object -Unique)
    if ($featureIds.Count -ge 2) {
        [void]$fileConflicts.Add([ordered]@{
            file     = $key
            features = $featureIds
            tasks    = @($taskIds | Sort-Object -Unique)
        })
    }
}

# Completed task set for dependency resolution
$completedSet = @{}
foreach ($t in $allTasks) {
    if ($t.status -eq "completed") {
        $completedSet[$t.global_id] = $true
    }
}

# Blocked queue: tasks with unsatisfied dependencies
$blockedQueue = [System.Collections.ArrayList]::new()
foreach ($t in $allTasks) {
    if ($t.status -ne "pending") { continue }
    if ($t.depends_on.Count -eq 0) { continue }

    $unsatisfied = [System.Collections.ArrayList]::new()
    foreach ($dep in $t.depends_on) {
        if (-not $completedSet.ContainsKey($dep)) {
            [void]$unsatisfied.Add($dep)
        }
    }
    if ($unsatisfied.Count -gt 0) {
        [void]$blockedQueue.Add([ordered]@{
            task_id      = $t.global_id
            feature_id   = $t.feature_id
            subject      = $t.subject
            waiting_on   = @($unsatisfied)
        })
    }
}

# Next available: pending tasks with all deps met (or no deps)
$nextAvailable = [System.Collections.ArrayList]::new()
foreach ($t in $allTasks) {
    if ($t.status -ne "pending") { continue }

    $allDepsMet = $true
    foreach ($dep in $t.depends_on) {
        if (-not $completedSet.ContainsKey($dep)) {
            $allDepsMet = $false
            break
        }
    }
    if ($allDepsMet) {
        [void]$nextAvailable.Add([ordered]@{
            task_id    = $t.global_id
            feature_id = $t.feature_id
            subject    = $t.subject
            phase      = $t.phase
            parallel   = $t.parallel
        })
    }
}

# Surface inventory: all [!SURFACE] tasks
$surfaceInventory = [System.Collections.ArrayList]::new()
foreach ($t in $allTasks) {
    if ($t.is_surface) {
        [void]$surfaceInventory.Add([ordered]@{
            task_id    = $t.global_id
            feature_id = $t.feature_id
            subject    = $t.subject
            status     = $t.status
        })
    }
}

# --- Status counts ---
$taskStatusCounts = @{}
foreach ($t in $allTasks) {
    $s = [string]$t.status
    if (-not $taskStatusCounts.ContainsKey($s)) {
        $taskStatusCounts[$s] = 0
    }
    $taskStatusCounts[$s] = $taskStatusCounts[$s] + 1
}

# --- Build output ---
$output = [ordered]@{
    generated_at      = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    task_count        = $allTasks.Count
    status_summary    = $taskStatusCounts
    tasks             = @($allTasks)
    file_conflicts    = @($fileConflicts)
    blocked_queue     = @($blockedQueue)
    next_available    = @($nextAvailable)
    surface_inventory = @($surfaceInventory)
}

$json = $output | ConvertTo-Json -Depth 10

if ($JsonOnly) {
    Write-Output $json
}
else {
    # Write JSON
    $jsonPath = Join-Path $outputDir "task-map.json"
    $json | Set-Content -Path $jsonPath -Encoding UTF8
    Write-Host "Written: $jsonPath" -ForegroundColor Green

    # Write Markdown
    $mdPath = Join-Path $outputDir "task-map.md"
    $mdLines = [System.Collections.ArrayList]::new()
    [void]$mdLines.Add("# Task Map")
    [void]$mdLines.Add("")
    [void]$mdLines.Add("Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    [void]$mdLines.Add("")

    # Status summary
    [void]$mdLines.Add("## Status Summary")
    [void]$mdLines.Add("")
    [void]$mdLines.Add("| Status | Count |")
    [void]$mdLines.Add("|--------|------:|")
    foreach ($key in ($taskStatusCounts.Keys | Sort-Object)) {
        [void]$mdLines.Add("| $key | $($taskStatusCounts[$key]) |")
    }
    $totalTasks = $allTasks.Count
    [void]$mdLines.Add("| **Total** | **$totalTasks** |")
    [void]$mdLines.Add("")

    # Next available tasks
    if ($nextAvailable.Count -gt 0) {
        [void]$mdLines.Add("## Next Available Tasks ($($nextAvailable.Count))")
        [void]$mdLines.Add("")
        [void]$mdLines.Add("| Task | Feature | Phase | Subject | Parallel |")
        [void]$mdLines.Add("|------|---------|------:|---------|:--------:|")
        foreach ($t in ($nextAvailable | Sort-Object { $_.phase })) {
            $par = if ($t.parallel) { "Y" } else { "" }
            [void]$mdLines.Add("| $($t.task_id) | $($t.feature_id) | $($t.phase) | $($t.subject) | $par |")
        }
        [void]$mdLines.Add("")
    }

    # Blocked tasks
    if ($blockedQueue.Count -gt 0) {
        [void]$mdLines.Add("## Blocked Tasks ($($blockedQueue.Count))")
        [void]$mdLines.Add("")
        [void]$mdLines.Add("| Task | Feature | Subject | Waiting On |")
        [void]$mdLines.Add("|------|---------|---------|------------|")
        foreach ($t in $blockedQueue) {
            $waiting = $t.waiting_on -join ", "
            [void]$mdLines.Add("| $($t.task_id) | $($t.feature_id) | $($t.subject) | $waiting |")
        }
        [void]$mdLines.Add("")
    }

    # File conflicts
    if ($fileConflicts.Count -gt 0) {
        [void]$mdLines.Add("## File Conflicts ($($fileConflicts.Count))")
        [void]$mdLines.Add("")
        [void]$mdLines.Add("| File | Features | Tasks |")
        [void]$mdLines.Add("|------|----------|-------|")
        foreach ($c in $fileConflicts) {
            $feats = $c.features -join ", "
            $tasks = $c.tasks -join ", "
            [void]$mdLines.Add("| ``$($c.file)`` | $feats | $tasks |")
        }
        [void]$mdLines.Add("")
    }

    # Surface inventory
    if ($surfaceInventory.Count -gt 0) {
        [void]$mdLines.Add("## Integration Surfaces ($($surfaceInventory.Count))")
        [void]$mdLines.Add("")
        [void]$mdLines.Add("| Task | Feature | Subject | Status |")
        [void]$mdLines.Add("|------|---------|---------|--------|")
        foreach ($s in $surfaceInventory) {
            [void]$mdLines.Add("| $($s.task_id) | $($s.feature_id) | $($s.subject) | $($s.status) |")
        }
        [void]$mdLines.Add("")
    }

    # All tasks by feature
    [void]$mdLines.Add("## All Tasks by Feature")
    [void]$mdLines.Add("")

    $grouped = $allTasks | Group-Object { $_.feature_id }
    foreach ($group in ($grouped | Sort-Object Name)) {
        $completedCount = @($group.Group | Where-Object { $_.status -eq "completed" }).Count
        $totalCount = $group.Group.Count
        [void]$mdLines.Add("### $($group.Name) ($completedCount/$totalCount)")
        [void]$mdLines.Add("")
        [void]$mdLines.Add("| Task | Phase | Status | Subject |")
        [void]$mdLines.Add("|------|------:|--------|---------|")
        foreach ($t in $group.Group) {
            $statusIcon = switch ($t.status) {
                "completed" { "[x]" }
                "blocked"   { "[!]" }
                default     { "[ ]" }
            }
            [void]$mdLines.Add("| $($t.task_id) | $($t.phase) | $statusIcon | $($t.subject) |")
        }
        [void]$mdLines.Add("")
    }

    ($mdLines -join "`n") | Set-Content -Path $mdPath -Encoding UTF8
    Write-Host "Written: $mdPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "Tasks: $totalTasks" -ForegroundColor Cyan
    foreach ($key in ($taskStatusCounts.Keys | Sort-Object)) {
        Write-Host "  $key`: $($taskStatusCounts[$key])"
    }
    if ($nextAvailable.Count -gt 0) {
        Write-Host "Next available: $($nextAvailable.Count)" -ForegroundColor Yellow
    }
    if ($fileConflicts.Count -gt 0) {
        Write-Host "File conflicts: $($fileConflicts.Count)" -ForegroundColor Red
    }
}
