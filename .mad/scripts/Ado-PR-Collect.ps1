<#
.SYNOPSIS
    Collect PR metadata, diff, and threads from Azure DevOps into local files.
    Single script replaces 5+ inline az repos pr / az devops invoke commands.

.PARAMETER PrId
    Pull request ID (mandatory)

.PARAMETER Repository
    Repository name (default: LENS-CMS)

.PARAMETER Project
    Azure DevOps project (default: O365 Core)

.PARAMETER OutputDir
    Directory for output files (default: .mad/scratch/review-{PrId})

.EXAMPLE
    .\Ado-PR-Collect.ps1 -PrId 4895118
    .\Ado-PR-Collect.ps1 -PrId 4895118 -OutputDir C:\temp\review
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [int]$PrId,

    [string]$Repository = "LENS-CMS",

    [string]$Project = "O365 Core",

    [string]$OutputDir
)

$ErrorActionPreference = "Stop"
$env:MSYS_NO_PATHCONV = "1"

if (-not $OutputDir) {
    $OutputDir = "C:\source\CCGHCP\.mad\scratch\review-$PrId"
}

Write-Host ""
Write-Host "=== ADO PR Collect ===" -ForegroundColor Cyan
Write-Host "PR ID:       $PrId"
Write-Host "Repository:  $Repository"
Write-Host "Project:     $Project"
Write-Host "Output Dir:  $OutputDir"
Write-Host ""

# --- Ensure output directory ---
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "Created output directory." -ForegroundColor Green
}

# --- Step 1: PR metadata ---
Write-Host "--- Step 1: Fetching PR metadata ---" -ForegroundColor Yellow
$ErrorActionPreference = "Continue"
$prRaw = az repos pr show --id $PrId --output json 2>&1
$ErrorActionPreference = "Stop"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to fetch PR #${PrId}: ${prRaw}"
}
# Filter out WARNING/INFO lines that az CLI may emit before JSON
$prJson = ($prRaw | Where-Object { $_ -notmatch '^\s*(WARNING|INFO|DEBUG):' }) -join "`n"
$pr = $prJson | ConvertFrom-Json

$metaFile = Join-Path $OutputDir "pr-meta.md"
$meta = @"
# PR #$PrId

- **Title**: $($pr.title)
- **Author**: $($pr.createdBy.displayName) ($($pr.createdBy.uniqueName))
- **Source**: ``$($pr.sourceRefName -replace 'refs/heads/','')``
- **Target**: ``$($pr.targetRefName -replace 'refs/heads/','')``
- **Status**: $($pr.status)
- **Created**: $($pr.creationDate)
- **Description**: $($pr.description)
"@
$meta | Out-File -FilePath $metaFile -Encoding utf8
Write-Host "  Saved: pr-meta.md" -ForegroundColor Green

# --- Resolve repository ID (needed by Steps 2 and 3) ---
$ErrorActionPreference = "Continue"
$repoInfo = az repos show --repository $Repository --project $Project --query "id" -o tsv 2>&1
$ErrorActionPreference = "Stop"
if ($LASTEXITCODE -ne 0) {
    Write-Host "  WARN: Could not resolve repo ID, using name" -ForegroundColor DarkYellow
    $repoId = $Repository
} else {
    $repoId = $repoInfo.Trim()
}

# --- Step 2: PR diff ---
Write-Host ""
Write-Host "--- Step 2: Fetching PR diff ---" -ForegroundColor Yellow
$diffFile = Join-Path $OutputDir "pr-diff.md"

# az repos pr diff does not exist; use REST API to get iterations and changes
try {
    $ErrorActionPreference = "Continue"
    $iterJson = az devops invoke `
        --area git --resource pullRequestIterations `
        --route-parameters project=$Project repositoryId=$repoId pullRequestId=$PrId `
        --api-version 7.0 --output json 2>&1
    $ErrorActionPreference = "Stop"

    if ($LASTEXITCODE -ne 0) { throw "iterations fetch failed" }

    # Filter out WARNING/ERROR lines from az output before JSON parse
    $iterJsonClean = ($iterJson | Where-Object { $_ -is [string] -and $_ -notmatch '^(WARNING|ERROR):' }) -join "`n"
    $iterations = ($iterJsonClean | ConvertFrom-Json).value
    $lastIter = $iterations[-1].id

    $ErrorActionPreference = "Continue"
    $changesJson = az devops invoke `
        --area git --resource pullRequestIterationChanges `
        --route-parameters project=$Project repositoryId=$repoId pullRequestId=$PrId iterationId=$lastIter `
        --api-version 7.0 --output json 2>&1
    $ErrorActionPreference = "Stop"

    if ($LASTEXITCODE -ne 0) { throw "changes fetch failed" }

    $changesJsonClean = ($changesJson | Where-Object { $_ -is [string] -and $_ -notmatch '^(WARNING|ERROR):' }) -join "`n"
    $changes = ($changesJsonClean | ConvertFrom-Json).changeEntries
    $diffLines = @("# PR #${PrId} Changed Files (Iteration ${lastIter})", "")
    foreach ($c in $changes) {
        $changeType = $c.changeTrackingId
        $path = if ($c.item.path) { $c.item.path } else { "(unknown)" }
        $diffLines += "- [$($c.changeType)] ``${path}``"
    }
    $diffLines -join "`n" | Out-File -FilePath $diffFile -Encoding utf8
    Write-Host "  Saved: pr-diff.md ($($changes.Count) changed files)" -ForegroundColor Green
} catch {
    Write-Host "  WARN: Could not fetch diff ($($_.Exception.Message))" -ForegroundColor DarkYellow
    "# Diff unavailable - fetch manually" | Out-File -FilePath $diffFile -Encoding utf8
}

# --- Step 3: PR threads (comments) ---
Write-Host ""
Write-Host "--- Step 3: Fetching PR threads ---" -ForegroundColor Yellow
$threadsFile = Join-Path $OutputDir "pr-threads.json"

try {
    $ErrorActionPreference = "Continue"
    $threads = az devops invoke `
        --area git --resource pullRequestThreads `
        --route-parameters project=$Project repositoryId=$repoId pullRequestId=$PrId `
        --api-version 7.0 --output json 2>&1
    $ErrorActionPreference = "Stop"

    if ($LASTEXITCODE -ne 0) { throw "threads fetch failed" }

    $threadsClean = ($threads | Where-Object { $_ -notmatch '^\s*(WARNING|INFO|DEBUG):' }) -join "`n"
    $threadsClean | Out-File -FilePath $threadsFile -Encoding utf8
    $threadCount = ($threadsClean | ConvertFrom-Json).value.Count
    Write-Host "  Saved: pr-threads.json (${threadCount} threads)" -ForegroundColor Green
} catch {
    $ErrorActionPreference = "Stop"
    Write-Host "  WARN: Could not fetch threads ($($_.Exception.Message))" -ForegroundColor DarkYellow
    "{}" | Out-File -FilePath $threadsFile -Encoding utf8
}

# --- Step 4: Pipeline status ---
Write-Host ""
Write-Host "--- Step 4: Fetching pipeline status ---" -ForegroundColor Yellow
$sourceBranch = $pr.sourceRefName -replace 'refs/heads/',''
try {
    $ErrorActionPreference = "Continue"
    $pipelineRuns = az pipelines runs list --branch $sourceBranch --top 5 --output json 2>&1
    $ErrorActionPreference = "Stop"

    if ($LASTEXITCODE -ne 0) { throw "pipeline runs fetch failed" }

    $pipelineRunsClean = ($pipelineRuns | Where-Object { $_ -notmatch '^\s*(WARNING|INFO|DEBUG):' }) -join "`n"
    $runs = $pipelineRunsClean | ConvertFrom-Json
    if ($runs.Count -gt 0) {
        $latest = $runs[0]
        $color = if ($latest.result -eq "succeeded") { "Green" } else { "DarkYellow" }
        Write-Host "  Latest: $($latest.definition.name) - $($latest.status)/$($latest.result)" -ForegroundColor $color
    } else {
        Write-Host "  No pipeline runs found for branch '$sourceBranch'" -ForegroundColor DarkYellow
    }
} catch {
    $ErrorActionPreference = "Stop"
    Write-Host "  WARN: Could not fetch pipeline status ($($_.Exception.Message))" -ForegroundColor DarkYellow
}

# --- Summary ---
Write-Host ""
Write-Host "=== Collection Summary ===" -ForegroundColor Cyan
Write-Host "PR:       #${PrId} - $($pr.title)"
Write-Host "Author:   $($pr.createdBy.displayName)"
Write-Host "Branch:   $sourceBranch -> $($pr.targetRefName -replace 'refs/heads/','')"
Write-Host "Status:   $($pr.status)"
Write-Host "Files:    $OutputDir"
Write-Host "  - pr-meta.md"
Write-Host "  - pr-diff.md"
Write-Host "  - pr-threads.json"
