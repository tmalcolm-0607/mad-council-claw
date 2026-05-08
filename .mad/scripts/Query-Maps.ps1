<#
.SYNOPSIS
    Query interface for feature-map.json and task-map.json.

.DESCRIPTION
    Provides 6 query actions against the generated map files:
    - conflicts: Files owned by 2+ features
    - next-tasks: Pending tasks with all dependencies satisfied
    - file-owners: Features that touch a specific file
    - blocked: Tasks with unsatisfied dependencies
    - surfaces: Integration surface task inventory
    - status: Feature status dashboard

.PARAMETER Action
    Query action to perform. Required.

.PARAMETER File
    File name to query ownership for. Required for 'file-owners' action.

.PARAMETER FeatureId
    Optional filter to scope results to a specific feature.

.PARAMETER RepoRoot
    Root directory of the CCGHCP repository. Default: C:\source\CCGHCP

.PARAMETER Json
    Output raw JSON instead of formatted table.

.EXAMPLE
    .\Query-Maps.ps1 -Action status
    .\Query-Maps.ps1 -Action conflicts
    .\Query-Maps.ps1 -Action next-tasks -FeatureId 038-eval-system-redesign
    .\Query-Maps.ps1 -Action file-owners -File CaseController.cs
    .\Query-Maps.ps1 -Action blocked
    .\Query-Maps.ps1 -Action surfaces

.NOTES
    Requires Generate-FeatureMap.ps1 and/or Generate-TaskMap.ps1 to have run first.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('conflicts', 'next-tasks', 'file-owners', 'blocked', 'surfaces', 'status')]
    [string]$Action,

    [Parameter()]
    [string]$File,

    [Parameter()]
    [string]$FeatureId,

    [Parameter()]
    [string]$RepoRoot = "C:\source\CCGHCP",

    [Parameter()]
    [switch]$Json
)

$ErrorActionPreference = 'Stop'

$madDir = Join-Path $RepoRoot ".mad"
$featureMapPath = Join-Path $madDir "feature-map.json"
$taskMapPath = Join-Path $madDir "task-map.json"

function Load-FeatureMap {
    if (-not (Test-Path $featureMapPath)) {
        Write-Error "feature-map.json not found. Run Generate-FeatureMap.ps1 first."
    }
    return Get-Content $featureMapPath -Raw | ConvertFrom-Json
}

function Load-TaskMap {
    if (-not (Test-Path $taskMapPath)) {
        Write-Error "task-map.json not found. Run Generate-TaskMap.ps1 first."
    }
    return Get-Content $taskMapPath -Raw | ConvertFrom-Json
}

switch ($Action) {

    'status' {
        $featureMap = Load-FeatureMap

        if ($Json) {
            $result = [ordered]@{
                generated_at   = $featureMap.generated_at
                feature_count  = $featureMap.feature_count
                status_summary = $featureMap.status_summary
                features       = @()
            }
            foreach ($f in $featureMap.features) {
                $entry = [ordered]@{
                    id       = $f.id
                    title    = $f.title
                    status   = $f.status
                    progress = "$($f.task_progress.completed)/$($f.task_progress.total)"
                    branch   = $f.branch
                }
                if (-not $FeatureId -or $f.id -eq $FeatureId) {
                    $result.features += $entry
                }
            }
            $result | ConvertTo-Json -Depth 5
        }
        else {
            Write-Host ""
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "Feature Status Dashboard" -ForegroundColor Cyan
            Write-Host "========================================" -ForegroundColor Cyan
            Write-Host "Generated: $($featureMap.generated_at)"
            Write-Host ""

            # Status summary
            Write-Host "STATUS SUMMARY:" -ForegroundColor Yellow
            $statusProps = $featureMap.status_summary.PSObject.Properties
            foreach ($prop in $statusProps) {
                Write-Host "  $($prop.Name): $($prop.Value)"
            }
            Write-Host ""

            # Feature list
            Write-Host ("{0,-35} {1,-12} {2,-10} {3}" -f "ID", "Status", "Progress", "Branch") -ForegroundColor White
            Write-Host ("{0,-35} {1,-12} {2,-10} {3}" -f "--", "------", "--------", "------") -ForegroundColor DarkGray

            foreach ($f in $featureMap.features) {
                if ($FeatureId -and $f.id -ne $FeatureId) { continue }

                $prog = "$($f.task_progress.completed)/$($f.task_progress.total)"
                $branch = if ($f.branch) { $f.branch } else { "-" }
                $color = switch -Wildcard ($f.status) {
                    'Complete*' { 'Green' }
                    'Draft*'    { 'Yellow' }
                    'Active*'   { 'Cyan' }
                    default     { 'White' }
                }
                Write-Host ("{0,-35} {1,-12} {2,-10} {3}" -f $f.id, $f.status, $prog, $branch) -ForegroundColor $color
            }
        }
    }

    'conflicts' {
        $featureMap = Load-FeatureMap

        # Filter file_ownership to files with 2+ owners
        $conflicts = @()
        $ownershipProps = $featureMap.file_ownership.PSObject.Properties
        foreach ($prop in $ownershipProps) {
            $owners = @($prop.Value)
            if ($FeatureId) {
                if ($owners -notcontains $FeatureId) { continue }
            }
            if ($owners.Count -ge 2) {
                $conflicts += [ordered]@{
                    file   = $prop.Name
                    owners = $owners
                    count  = $owners.Count
                }
            }
        }

        if ($Json) {
            $conflicts | ConvertTo-Json -Depth 5
        }
        else {
            if ($conflicts.Count -eq 0) {
                Write-Host "No file conflicts found." -ForegroundColor Green
            }
            else {
                Write-Host ""
                Write-Host "FILE CONFLICTS ($($conflicts.Count) files with 2+ owners):" -ForegroundColor Red
                Write-Host ""
                Write-Host ("{0,-40} {1,-6} {2}" -f "File", "Count", "Owners") -ForegroundColor White
                Write-Host ("{0,-40} {1,-6} {2}" -f "----", "-----", "------") -ForegroundColor DarkGray
                foreach ($c in ($conflicts | Sort-Object { $_.count } -Descending)) {
                    $owners = $c.owners -join ", "
                    Write-Host ("{0,-40} {1,-6} {2}" -f $c.file, $c.count, $owners) -ForegroundColor Yellow
                }
            }
        }
    }

    'next-tasks' {
        $taskMap = Load-TaskMap

        $nextTasks = @($taskMap.next_available)
        if ($FeatureId) {
            $nextTasks = @($nextTasks | Where-Object { $_.feature_id -eq $FeatureId })
        }

        if ($Json) {
            $nextTasks | ConvertTo-Json -Depth 5
        }
        else {
            if ($nextTasks.Count -eq 0) {
                Write-Host "No available tasks found." -ForegroundColor Yellow
            }
            else {
                Write-Host ""
                Write-Host "NEXT AVAILABLE TASKS ($($nextTasks.Count)):" -ForegroundColor Green
                Write-Host ""
                Write-Host ("{0,-15} {1,-30} {2,-6} {3,-4} {4}" -f "Task", "Feature", "Phase", "[P]", "Subject") -ForegroundColor White
                Write-Host ("{0,-15} {1,-30} {2,-6} {3,-4} {4}" -f "----", "-------", "-----", "---", "-------") -ForegroundColor DarkGray
                foreach ($t in ($nextTasks | Sort-Object { $_.phase })) {
                    $par = if ($t.parallel) { "Y" } else { "" }
                    $subjectTrunc = if ($t.subject.Length -gt 60) { $t.subject.Substring(0, 57) + "..." } else { $t.subject }
                    Write-Host ("{0,-15} {1,-30} {2,-6} {3,-4} {4}" -f $t.task_id, $t.feature_id, $t.phase, $par, $subjectTrunc) -ForegroundColor Cyan
                }
            }
        }
    }

    'file-owners' {
        if (-not $File) {
            Write-Error "The -File parameter is required for the 'file-owners' action."
        }

        $featureMap = Load-FeatureMap

        $results = @()
        $ownershipProps = $featureMap.file_ownership.PSObject.Properties
        foreach ($prop in $ownershipProps) {
            # Match by exact name or partial match
            if ($prop.Name -eq $File -or $prop.Name -like "*$File*") {
                $results += [ordered]@{
                    file     = $prop.Name
                    features = @($prop.Value)
                }
            }
        }

        if ($Json) {
            $results | ConvertTo-Json -Depth 5
        }
        else {
            if ($results.Count -eq 0) {
                Write-Host "No features found touching '$File'." -ForegroundColor Yellow
            }
            else {
                Write-Host ""
                Write-Host "FILE OWNERS for '$File':" -ForegroundColor Cyan
                Write-Host ""
                foreach ($r in $results) {
                    Write-Host "  $($r.file):" -ForegroundColor White
                    foreach ($fId in $r.features) {
                        Write-Host "    - $fId" -ForegroundColor Green
                    }
                }
            }
        }
    }

    'blocked' {
        $taskMap = Load-TaskMap

        $blocked = @($taskMap.blocked_queue)
        if ($FeatureId) {
            $blocked = @($blocked | Where-Object { $_.feature_id -eq $FeatureId })
        }

        if ($Json) {
            $blocked | ConvertTo-Json -Depth 5
        }
        else {
            if ($blocked.Count -eq 0) {
                Write-Host "No blocked tasks found." -ForegroundColor Green
            }
            else {
                Write-Host ""
                Write-Host "BLOCKED TASKS ($($blocked.Count)):" -ForegroundColor Red
                Write-Host ""
                Write-Host ("{0,-15} {1,-30} {2,-30} {3}" -f "Task", "Feature", "Subject", "Waiting On") -ForegroundColor White
                Write-Host ("{0,-15} {1,-30} {2,-30} {3}" -f "----", "-------", "-------", "----------") -ForegroundColor DarkGray
                foreach ($t in $blocked) {
                    $waiting = $t.waiting_on -join ", "
                    $subjectTrunc = if ($t.subject.Length -gt 28) { $t.subject.Substring(0, 25) + "..." } else { $t.subject }
                    Write-Host ("{0,-15} {1,-30} {2,-30} {3}" -f $t.task_id, $t.feature_id, $subjectTrunc, $waiting) -ForegroundColor Yellow
                }
            }
        }
    }

    'surfaces' {
        $taskMap = Load-TaskMap

        $surfaces = @($taskMap.surface_inventory)
        if ($FeatureId) {
            $surfaces = @($surfaces | Where-Object { $_.feature_id -eq $FeatureId })
        }

        if ($Json) {
            $surfaces | ConvertTo-Json -Depth 5
        }
        else {
            if ($surfaces.Count -eq 0) {
                Write-Host "No integration surface tasks found." -ForegroundColor Yellow
            }
            else {
                Write-Host ""
                Write-Host "INTEGRATION SURFACES ($($surfaces.Count)):" -ForegroundColor Cyan
                Write-Host ""
                Write-Host ("{0,-15} {1,-30} {2,-10} {3}" -f "Task", "Feature", "Status", "Subject") -ForegroundColor White
                Write-Host ("{0,-15} {1,-30} {2,-10} {3}" -f "----", "-------", "------", "-------") -ForegroundColor DarkGray
                foreach ($s in $surfaces) {
                    $statusColor = switch ($s.status) {
                        "completed" { "Green" }
                        "blocked"   { "Red" }
                        default     { "Yellow" }
                    }
                    Write-Host ("{0,-15} {1,-30} {2,-10} {3}" -f $s.task_id, $s.feature_id, $s.status, $s.subject) -ForegroundColor $statusColor
                }
            }
        }
    }
}
