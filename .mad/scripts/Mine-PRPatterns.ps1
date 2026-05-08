<#
.SYNOPSIS
    Mine patterns from Azure DevOps PR review comments.

.DESCRIPTION
    Fetches PR comment threads from Azure DevOps and saves them for pattern analysis.
    Supports batch processing, dynamic PR discovery via --recent, and multi-repo scanning via --all-lens.

.PARAMETER PRIds
    Array of PR IDs to process. Ignored when -Recent is specified.

.PARAMETER Recent
    Fetch N most recent completed PRs from the target repository (or each repo if -AllLens).

.PARAMETER AllLens
    Iterate all LENS repositories. Applies -Recent per repo (default 3 per repo).

.PARAMETER ReposToScan
    Subset of LENS repos to scan. Defaults to all 10 LENS repos when -AllLens is used.

.PARAMETER MaxPRs
    Total PR cap across all repos. Default: 15.

.PARAMETER MaxThreadsPerPR
    Cap threads fetched per PR via $top query parameter. Default: 100.

.PARAMETER MaxCommentLength
    Truncate individual comment content to this many characters. Default: 2000.

.PARAMETER SkipMined
    Skip PRs already present in manifest.json. Default: true.

.PARAMETER Repository
    Repository name. Default: LENS-CMS

.PARAMETER Project
    Azure DevOps project. Default: O365 Core

.PARAMETER Organization
    Azure DevOps organization URL. Default: https://dev.azure.com/o365exchange

.PARAMETER OutputDir
    Output directory for JSON files. Default: .mad/scratch/pr-patterns

.EXAMPLE
    .\Mine-PRPatterns.ps1
    # Processes default PRs (4860830, 4881371, 4871858)

.EXAMPLE
    .\Mine-PRPatterns.ps1 -PRIds @(1234567, 2345678)
    # Processes specific PRs

.EXAMPLE
    .\Mine-PRPatterns.ps1 -Recent 5 -Repository "LENS-CMS"
    # Fetches 5 most recent completed PRs from LENS-CMS

.EXAMPLE
    .\Mine-PRPatterns.ps1 -AllLens -Recent 3
    # Fetches 3 most recent PRs from each of 10 LENS repos (capped at -MaxPRs)

.EXAMPLE
    .\Mine-PRPatterns.ps1 -AllLens -ReposToScan @("LENS-CMS", "LENS-Delivery")
    # Scans only specified repos

.NOTES
    Requires Azure CLI with azure-devops extension.
    Run 'az login' before first use.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [int[]]$PRIds = @(4860830, 4881371, 4871858),

    [Parameter()]
    [int]$Recent = 0,

    [Parameter()]
    [switch]$AllLens,

    [Parameter()]
    [string[]]$ReposToScan = @(
        "LENS-CMS", "LENS-DCS", "LENS-Delivery", "LENS-Docs", "LENS-LEAPI",
        "LENS-LEPortal", "LENS-LRMS", "LENS-Publish", "LENS-SMS", "LENS-Teams"
    ),

    [Parameter()]
    [int]$MaxPRs = 15,

    [Parameter()]
    [int]$MaxThreadsPerPR = 100,

    [Parameter()]
    [int]$MaxCommentLength = 2000,

    [Parameter()]
    [bool]$SkipMined = $true,

    [Parameter()]
    [string]$Repository = "LENS-CMS",

    [Parameter()]
    [string]$Project = "O365 Core",

    [Parameter()]
    [string]$Organization = "https://dev.azure.com/o365exchange",

    [Parameter()]
    [string]$OutputDir = ".mad/scratch/pr-patterns"
)

# Ensure output directory exists
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "Created output directory: $OutputDir" -ForegroundColor Green
}

# Verify Azure CLI authentication
Write-Host "Verifying Azure CLI authentication..." -ForegroundColor Cyan
try {
    $account = az account show --query name -o tsv 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Azure CLI not authenticated. Run 'az login' first."
        exit 1
    }
    Write-Host "Authenticated as: $account" -ForegroundColor Green
}
catch {
    Write-Error "Azure CLI not found. Install from https://aka.ms/azure-cli"
    exit 1
}

# Configure defaults
az devops configure --defaults organization=$Organization project=$Project | Out-Null

# --- Manifest tracking ---
$manifestPath = Join-Path $OutputDir "manifest.json"

function Read-Manifest {
    if (Test-Path $manifestPath) {
        return Get-Content $manifestPath -Raw | ConvertFrom-Json
    }
    return [PSCustomObject]@{ mined = [PSCustomObject]@{} }
}

function Write-Manifest {
    param([PSCustomObject]$Manifest)
    $Manifest | ConvertTo-Json -Depth 5 | Out-File $manifestPath -Encoding utf8
}

function Test-AlreadyMined {
    param([int]$PrId, [PSCustomObject]$Manifest)
    return ($null -ne $Manifest.mined.PSObject.Properties[$PrId.ToString()])
}

function Add-ManifestEntry {
    param([int]$PrId, [string]$Repo, [int]$CommentCount, [PSCustomObject]$Manifest)
    $entry = [PSCustomObject]@{
        repo         = $Repo
        date         = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        commentCount = $CommentCount
    }
    $Manifest.mined | Add-Member -NotePropertyName $PrId.ToString() -NotePropertyValue $entry -Force
}

$manifest = Read-Manifest

# --- Build PR list based on mode ---
# Each entry: @{ PRId = [int]; Repo = [string] }
$prQueue = @()

if ($AllLens) {
    # -AllLens mode: iterate repos, fetch recent PRs from each
    $recentPerRepo = if ($Recent -gt 0) { $Recent } else { 3 }
    Write-Host "`nScanning $($ReposToScan.Count) LENS repositories ($recentPerRepo recent PRs each)..." -ForegroundColor Cyan

    foreach ($repo in $ReposToScan) {
        Write-Host "  Listing PRs from $repo..." -ForegroundColor Gray
        try {
            $prsJson = az repos pr list --repository $repo --status completed --top $recentPerRepo --output json 2>$null
            if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($prsJson)) {
                Write-Warning "  Could not list PRs from $repo - skipping"
                continue
            }
            $prs = $prsJson | ConvertFrom-Json
            foreach ($pr in $prs) {
                $prQueue += @{ PRId = $pr.pullRequestId; Repo = $repo }
            }
            Write-Host "  Found $($prs.Count) PRs in $repo" -ForegroundColor Gray
        }
        catch {
            Write-Warning "  Error listing PRs from ${repo}: $_"
        }
    }

    # Sort by comment count descending (approximate: use thread count from PR metadata if available)
    # Cap to MaxPRs
    if ($prQueue.Count -gt $MaxPRs) {
        Write-Host "  Capping from $($prQueue.Count) candidates to $MaxPRs PRs" -ForegroundColor Yellow
        $prQueue = @($prQueue | Select-Object -First $MaxPRs)
    }
}
elseif ($Recent -gt 0) {
    # -Recent N mode: fetch N most recent completed PRs from single repo
    Write-Host "`nFetching $Recent most recent completed PRs from $Repository..." -ForegroundColor Cyan
    try {
        $prsJson = az repos pr list --repository $Repository --status completed --top $Recent --output json 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($prsJson)) {
            Write-Error "Failed to list PRs from $Repository"
            exit 1
        }
        $prs = $prsJson | ConvertFrom-Json
        foreach ($pr in $prs) {
            $prQueue += @{ PRId = $pr.pullRequestId; Repo = $Repository }
        }
        Write-Host "Found $($prs.Count) PRs" -ForegroundColor Green
    }
    catch {
        Write-Error "Error listing PRs: $_"
        exit 1
    }
}
else {
    # Explicit PR IDs mode (original behavior)
    foreach ($id in $PRIds) {
        $prQueue += @{ PRId = $id; Repo = $Repository }
    }
}

# Filter out already-mined PRs if SkipMined is enabled
if ($SkipMined) {
    $beforeCount = $prQueue.Count
    $prQueue = @($prQueue | Where-Object { -not (Test-AlreadyMined -PrId $_.PRId -Manifest $manifest) })
    $skipped = $beforeCount - $prQueue.Count
    if ($skipped -gt 0) {
        Write-Host "Skipped $skipped already-mined PRs (manifest.json)" -ForegroundColor Yellow
    }
}

if ($prQueue.Count -eq 0) {
    Write-Host "`nNo PRs to process." -ForegroundColor Yellow
    exit 0
}

Write-Host "`nProcessing $($prQueue.Count) PRs..." -ForegroundColor Cyan

# --- Process each PR ---
$results = @()

foreach ($entry in $prQueue) {
    $prId = $entry.PRId
    $repo = $entry.Repo

    Write-Host "`nMining PR #$prId ($repo)..." -ForegroundColor Cyan

    try {
        # Fetch PR details
        Write-Host "  Fetching PR details..." -ForegroundColor Gray
        $prJson = az repos pr show --id $prId --query "{title: title, status: status, repository: repository.name}" 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($prJson)) {
            Write-Warning "  Failed to fetch PR #$prId - skipping"
            $results += [PSCustomObject]@{
                PRId     = $prId
                Repo     = $repo
                Status   = "Failed"
                Comments = 0
                Error    = "PR not found or access denied"
            }
            continue
        }
        $prDetails = $prJson | ConvertFrom-Json

        Write-Host "  Title: $($prDetails.title)" -ForegroundColor Gray

        # Fetch PR threads (comments) with $top bounding
        Write-Host "  Fetching comment threads (max $MaxThreadsPerPR)..." -ForegroundColor Gray
        $threadsJson = az devops invoke `
            --area git `
            --resource pullRequestThreads `
            --route-parameters project=$Project repositoryId=$repo pullRequestId=$prId `
            --query-parameters "`$top=$MaxThreadsPerPR" `
            --api-version 7.0 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($threadsJson)) {
            Write-Warning "  Failed to fetch threads for PR #$prId"
            $results += [PSCustomObject]@{
                PRId     = $prId
                Repo     = $repo
                Status   = "Failed"
                Comments = 0
                Error    = "Thread fetch failed"
            }
            continue
        }
        $threads = $threadsJson | ConvertFrom-Json

        # Extract text comments (not system comments), with truncation
        $comments = @()
        foreach ($thread in $threads.value) {
            foreach ($comment in $thread.comments) {
                if ($comment.commentType -eq "text" -and $comment.content) {
                    $content = $comment.content
                    if ($content.Length -gt $MaxCommentLength) {
                        $content = $content.Substring(0, $MaxCommentLength) + "... [truncated]"
                    }
                    $comments += [PSCustomObject]@{
                        ThreadId   = $thread.id
                        CommentId  = $comment.id
                        Author     = $comment.author.displayName
                        Content    = $content
                        FilePath   = $thread.threadContext.filePath
                        Line       = $thread.threadContext.rightFileStart.line
                        Status     = $thread.status
                        IsResolved = ($thread.status -eq "fixed" -or $thread.status -eq "wontFix")
                    }
                }
            }
        }

        # Save to JSON
        $outputPath = Join-Path $OutputDir "$prId.json"
        $output = [PSCustomObject]@{
            PRId         = $prId
            Title        = $prDetails.title
            Repository   = $repo
            Status       = $prDetails.status
            ExtractedAt  = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
            CommentCount = $comments.Count
            Comments     = $comments
        }

        $output | ConvertTo-Json -Depth 10 | Out-File $outputPath -Encoding utf8

        Write-Host "  Saved $($comments.Count) comments to $outputPath" -ForegroundColor Green

        # Update manifest
        Add-ManifestEntry -PrId $prId -Repo $repo -CommentCount $comments.Count -Manifest $manifest

        $results += [PSCustomObject]@{
            PRId     = $prId
            Repo     = $repo
            Status   = "Success"
            Comments = $comments.Count
            Error    = $null
        }
    }
    catch {
        Write-Warning "  Error processing PR #$prId : $_"
        $results += [PSCustomObject]@{
            PRId     = $prId
            Repo     = $repo
            Status   = "Error"
            Comments = 0
            Error    = $_.Exception.Message
        }
    }
}

# Save updated manifest
Write-Manifest -Manifest $manifest

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Mining Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$results | Format-Table -AutoSize

$successful = ($results | Where-Object { $_.Status -eq "Success" }).Count
$totalComments = ($results | Measure-Object -Property Comments -Sum).Sum

Write-Host "`nResults:" -ForegroundColor Green
Write-Host "  PRs processed: $($results.Count)"
Write-Host "  Successful: $successful"
Write-Host "  Total comments: $totalComments"
Write-Host "  Output directory: $OutputDir"
Write-Host "  Manifest: $manifestPath"

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Run '/pr-pattern-extract --analyze' to process saved comments"
Write-Host "  2. Review generated reports in $OutputDir"
Write-Host "  3. Apply approved patterns using '/apply-learnings'"
