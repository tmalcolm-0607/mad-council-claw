<#
.SYNOPSIS
    Scan spec directories and work items to produce a feature map.

.DESCRIPTION
    Enumerates specs/*/spec.md, parses titles/status, correlates with
    .mad/work-items/*/manifest.json, aggregates task progress and file ownership.
    Outputs .mad/feature-map.json and .mad/feature-map.md.

.PARAMETER RepoRoot
    Root directory of the CCGHCP repository. Default: C:\source\CCGHCP

.PARAMETER JsonOnly
    Output JSON to stdout instead of writing files.

.EXAMPLE
    .\Generate-FeatureMap.ps1
    .\Generate-FeatureMap.ps1 -RepoRoot C:\source\CCGHCP -JsonOnly

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
$workItemsDir = Join-Path (Join-Path $RepoRoot ".mad") "work-items"
$outputDir = Join-Path $RepoRoot ".mad"

# --- Load all work item manifests ---
$manifests = @{}
if (Test-Path $workItemsDir) {
    Get-ChildItem $workItemsDir -Directory -ErrorAction SilentlyContinue |
        ForEach-Object {
            $manifestPath = Join-Path $_.FullName "manifest.json"
            if (Test-Path $manifestPath) {
                try {
                    $manifest = Get-Content $manifestPath -Raw -ErrorAction SilentlyContinue | ConvertFrom-Json
                    if ($manifest.spec_directory) {
                        $manifests[$manifest.spec_directory] = $manifest
                    }
                }
                catch {
                    Write-Warning "Failed to parse manifest: $manifestPath"
                }
            }
        }
}

# --- Parse each spec directory ---
$features = @()
$globalFileOwnership = @{}
$globalDependencyDag = @{}
$statusCounts = @{}

$specDirs = Get-ChildItem $specsDir -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -ne "ideas" -and $_.Name -ne "shared" -and $_.Name -ne "main" }

foreach ($dir in $specDirs) {
    $specPath = Join-Path $dir.FullName "spec.md"
    if (-not (Test-Path $specPath)) { continue }

    $featureId = $dir.Name

    # --- Parse spec.md ---
    $specContent = Get-Content $specPath -Raw -ErrorAction SilentlyContinue
    if (-not $specContent) { continue }
    $specLines = $specContent -split "`r?`n"

    # Title: first # heading
    $title = ""
    foreach ($line in $specLines) {
        if ($line -match '^#\s+(.+)') {
            $rawTitle = $Matches[1]
            # Strip common prefixes like "Feature Specification:"
            $title = $rawTitle -replace '^Feature Specification:\s*', ''
            break
        }
    }

    # Status: look for **Status**: or Status: line
    $status = "Unknown"
    foreach ($line in $specLines) {
        if ($line -match '\*\*Status\*\*:\s*(.+)') {
            $status = $Matches[1].Trim()
            break
        }
        elseif ($line -match '^Status:\s*(.+)') {
            $status = $Matches[1].Trim()
            break
        }
    }

    # Dependencies: look for **Dependencies** or depends_on lines
    $dependencies = @()
    foreach ($line in $specLines) {
        if ($line -match 'depends[_\s]?on.*?(\d{3}-[\w-]+)') {
            $dependencies += $Matches[1]
        }
        elseif ($line -match 'prerequisite.*?(\d{3}-[\w-]+)') {
            $dependencies += $Matches[1]
        }
    }
    $dependencies = $dependencies | Sort-Object -Unique

    # Integration surfaces: look for API endpoint patterns
    $integrationSurfaces = @()
    $surfaceMatches = [regex]::Matches($specContent, '((?:GET|POST|PUT|PATCH|DELETE)\s+/api/[^\s\)]+)')
    foreach ($m in $surfaceMatches) {
        $integrationSurfaces += $m.Groups[1].Value
    }
    $integrationSurfaces = $integrationSurfaces | Sort-Object -Unique

    # --- Check which spec artifacts exist ---
    $specArtifacts = @()
    foreach ($artifact in @("spec.md", "plan.md", "tasks.md", "data-model.md", "research.md", "quickstart.md")) {
        if (Test-Path (Join-Path $dir.FullName $artifact)) {
            $specArtifacts += $artifact
        }
    }
    if (Test-Path (Join-Path $dir.FullName "contracts")) {
        $specArtifacts += "contracts/"
    }
    if (Test-Path (Join-Path $dir.FullName "checklists")) {
        $specArtifacts += "checklists/"
    }

    # --- Parse tasks.md for progress and file references ---
    $taskProgress = @{ total = 0; completed = 0; in_progress = 0; blocked = 0 }
    $affectedFiles = @()
    $tasksPath = Join-Path $dir.FullName "tasks.md"

    if (Test-Path $tasksPath) {
        $tasksContent = Get-Content $tasksPath -Raw -ErrorAction SilentlyContinue
        if ($tasksContent) {
            # Count checkboxes - match task lines (- [x] or - [ ] with bold task ID)
            $completedMatches = [regex]::Matches($tasksContent, '(?mi)^-\s+\[x\]\s+\*\*T\d+')
            $pendingMatches = [regex]::Matches($tasksContent, '(?mi)^-\s+\[\s\]\s+\*\*T\d+')
            # Also count GATE checkboxes
            $completedGates = [regex]::Matches($tasksContent, '(?mi)^-\s+\[x\]\s+\*\*GATE')
            $pendingGates = [regex]::Matches($tasksContent, '(?mi)^-\s+\[\s\]\s+\*\*GATE')

            $taskProgress.completed = $completedMatches.Count + $completedGates.Count
            $taskProgress.total = $taskProgress.completed + $pendingMatches.Count + $pendingGates.Count

            # Look for [!] blocked markers
            $blockedMatches = [regex]::Matches($tasksContent, '(?mi)^-\s+\[!\]')
            $taskProgress.blocked = $blockedMatches.Count

            # In-progress = total - completed - blocked - pending (approximate)
            $remaining = $taskProgress.total - $taskProgress.completed - $taskProgress.blocked
            $taskProgress.in_progress = 0  # Cannot determine from static text

            # Extract file paths from task bodies
            # Pattern: backtick-quoted paths or common source file patterns
            $filePatterns = [regex]::Matches($tasksContent, '`([A-Za-z][\w\-]+\.(?:cs|ts|tsx|js|jsx|json|csproj|sln|md|ps1|yml|yaml))`')
            foreach ($m in $filePatterns) {
                $affectedFiles += $m.Groups[1].Value
            }
            $affectedFiles = $affectedFiles | Sort-Object -Unique
        }
    }

    # --- Determine applicable patterns ---
    $applicablePatterns = @()
    foreach ($file in $affectedFiles) {
        if ($file -match '\.cs$') {
            $applicablePatterns += "dotnet-architecture"
            if ($file -match 'Controller') { $applicablePatterns += "dotnet-mvc-controllers" }
            if ($file -match 'Test') { $applicablePatterns += "dotnet-testing-patterns" }
        }
        if ($file -match '\.tsx?$') {
            if ($file -match '\.test\.') { $applicablePatterns += "lrms-ux-testing" }
        }
    }
    $applicablePatterns = $applicablePatterns | Sort-Object -Unique

    # --- Match to work item ---
    $specRelPath = "specs/$featureId"
    $workItemId = $null
    $branch = $null

    foreach ($key in $manifests.Keys) {
        if ($key -eq $specRelPath) {
            $wi = $manifests[$key]
            $workItemId = $wi.id
            $branch = $wi.branch
            break
        }
    }

    # Also check if spec.md contains a work item reference
    if (-not $workItemId) {
        if ($specContent -match 'Work\s*Item.*?:\s*(WI-[\w-]+)') {
            $workItemId = $Matches[1]
        }
    }
    if (-not $branch) {
        if ($specContent -match 'Feature\s*Branch.*?:\s*`?([^`\s]+)`?') {
            $branch = $Matches[1]
        }
    }

    # --- Build feature record ---
    $feature = [ordered]@{
        id                    = $featureId
        title                 = $title
        status                = $status
        work_item_id          = $workItemId
        branch                = $branch
        spec_artifacts        = $specArtifacts
        task_progress         = [ordered]@{
            total      = $taskProgress.total
            completed  = $taskProgress.completed
            in_progress = $taskProgress.in_progress
            blocked    = $taskProgress.blocked
        }
        affected_files        = $affectedFiles
        dependencies          = $dependencies
        integration_surfaces  = $integrationSurfaces
        applicable_patterns   = $applicablePatterns
    }
    $features += $feature

    # --- Accumulate global aggregates ---
    foreach ($file in $affectedFiles) {
        if (-not $globalFileOwnership.ContainsKey($file)) {
            $globalFileOwnership[$file] = @()
        }
        $globalFileOwnership[$file] += $featureId
    }

    if ($dependencies.Count -gt 0) {
        $globalDependencyDag[$featureId] = $dependencies
    }

    if (-not $statusCounts.ContainsKey($status)) {
        $statusCounts[$status] = 0
    }
    $statusCounts[$status]++
}

# --- Filter file_ownership to only files with 2+ owners ---
$conflictFiles = @{}
foreach ($key in $globalFileOwnership.Keys) {
    $owners = $globalFileOwnership[$key] | Sort-Object -Unique
    if ($owners.Count -ge 1) {
        $conflictFiles[$key] = $owners
    }
}

# --- Build output ---
$output = [ordered]@{
    generated_at     = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ")
    feature_count    = $features.Count
    features         = $features
    file_ownership   = $conflictFiles
    dependency_dag   = $globalDependencyDag
    status_summary   = $statusCounts
}

$json = $output | ConvertTo-Json -Depth 10

if ($JsonOnly) {
    Write-Output $json
}
else {
    # Write JSON
    $jsonPath = Join-Path $outputDir "feature-map.json"
    $json | Set-Content -Path $jsonPath -Encoding UTF8
    Write-Host "Written: $jsonPath" -ForegroundColor Green

    # Write Markdown
    $mdPath = Join-Path $outputDir "feature-map.md"
    $mdLines = @()
    $mdLines += "# Feature Map"
    $mdLines += ""
    $mdLines += "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    $mdLines += ""

    # Status summary
    $mdLines += "## Status Summary"
    $mdLines += ""
    $mdLines += "| Status | Count |"
    $mdLines += "|--------|------:|"
    foreach ($key in ($statusCounts.Keys | Sort-Object)) {
        $mdLines += "| $key | $($statusCounts[$key]) |"
    }
    $mdLines += ""

    # Feature table
    $mdLines += "## Features"
    $mdLines += ""
    $mdLines += "| ID | Title | Status | Progress | Branch | Artifacts |"
    $mdLines += "|----|-------|--------|----------|--------|-----------|"

    foreach ($f in $features) {
        $prog = "$($f.task_progress.completed)/$($f.task_progress.total)"
        $arts = ($f.spec_artifacts -join ", ")
        $br = if ($f.branch) { "``$($f.branch)``" } else { "-" }
        $mdLines += "| $($f.id) | $($f.title) | $($f.status) | $prog | $br | $arts |"
    }
    $mdLines += ""

    # File conflicts (files owned by 2+ features)
    $conflicts = $conflictFiles.GetEnumerator() | Where-Object { $_.Value.Count -ge 2 }
    if ($conflicts) {
        $mdLines += "## File Conflicts (2+ owners)"
        $mdLines += ""
        $mdLines += "| File | Owners |"
        $mdLines += "|------|--------|"
        foreach ($entry in ($conflicts | Sort-Object { $_.Value.Count } -Descending)) {
            $owners = $entry.Value -join ", "
            $mdLines += "| ``$($entry.Key)`` | $owners |"
        }
        $mdLines += ""
    }

    # Dependency DAG
    if ($globalDependencyDag.Count -gt 0) {
        $mdLines += "## Dependency Graph"
        $mdLines += ""
        $mdLines += "| Feature | Depends On |"
        $mdLines += "|---------|------------|"
        foreach ($key in ($globalDependencyDag.Keys | Sort-Object)) {
            $deps = $globalDependencyDag[$key] -join ", "
            $mdLines += "| $key | $deps |"
        }
        $mdLines += ""
    }

    ($mdLines -join "`n") | Set-Content -Path $mdPath -Encoding UTF8
    Write-Host "Written: $mdPath" -ForegroundColor Green
    Write-Host ""
    Write-Host "Features: $($features.Count)" -ForegroundColor Cyan
    foreach ($key in ($statusCounts.Keys | Sort-Object)) {
        Write-Host "  $key`: $($statusCounts[$key])"
    }
}
