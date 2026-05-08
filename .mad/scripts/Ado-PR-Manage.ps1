<#
.SYNOPSIS
    Create, publish, or complete Azure DevOps pull requests.
    Single script replaces inline az repos pr create/update commands.

.PARAMETER Action
    Operation: create, publish (remove draft), complete (merge), update (title/description)

.PARAMETER PrId
    PR ID (required for publish/complete)

.PARAMETER SourceBranch
    Source branch (required for create)

.PARAMETER TargetBranch
    Target branch (default: main)

.PARAMETER Title
    PR title (required for create)

.PARAMETER Description
    PR description body (single-line; use DescriptionFile for multi-line)

.PARAMETER DescriptionFile
    Path to file containing multi-line PR description (uses az CLI @filename syntax)

.PARAMETER Draft
    Create as draft PR

.PARAMETER Squash
    Squash merge on complete

.PARAMETER DeleteSourceBranch
    Delete source branch on complete

.PARAMETER WorkItems
    Comma-separated work item IDs to link

.PARAMETER Repository
    Repository name (default: LENS-CMS)

.PARAMETER WhatIf
    Show what would be executed without making changes

.EXAMPLE
    .\Ado-PR-Manage.ps1 -Action create -SourceBranch "users/tonym/feature" -Title "feat: add health"
    .\Ado-PR-Manage.ps1 -Action create -SourceBranch "users/tonym/feature" -Title "feat: add health" -Draft
    .\Ado-PR-Manage.ps1 -Action publish -PrId 12345
    .\Ado-PR-Manage.ps1 -Action complete -PrId 12345 -Squash -DeleteSourceBranch
    .\Ado-PR-Manage.ps1 -Action update -PrId 12345 -Title "new title" -Description "new body"
    .\Ado-PR-Manage.ps1 -Action create -SourceBranch "users/tonym/test" -Title "test" -Draft -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet("create", "publish", "complete", "update")]
    [string]$Action,

    [int]$PrId = 0,

    [string]$SourceBranch,

    [string]$TargetBranch = "main",

    [string]$Title,

    [string]$Description,

    [switch]$Draft,

    [switch]$Squash,

    [switch]$DeleteSourceBranch,

    [string]$WorkItems,

    [string]$DescriptionFile,

    [string]$Repository = "LENS-CMS"
)

$ErrorActionPreference = "Stop"
$env:MSYS_NO_PATHCONV = "1"

Write-Host ""
Write-Host "=== ADO PR Manage ===" -ForegroundColor Cyan
Write-Host "Action:     $Action"
Write-Host "Repository: $Repository"
Write-Host ""

switch ($Action) {
    "create" {
        if (-not $SourceBranch) { Write-Error "SourceBranch is required for create action" }
        if (-not $Title) { Write-Error "Title is required for create action" }

        Write-Host "--- Creating PR ---" -ForegroundColor Yellow
        Write-Host "Source:  $SourceBranch"
        Write-Host "Target:  $TargetBranch"
        Write-Host "Title:   $Title"
        Write-Host "Draft:   $Draft"

        $cmdArgs = @(
            "repos", "pr", "create",
            "--title", $Title,
            "--source-branch", $SourceBranch,
            "--target-branch", $TargetBranch,
            "--repository", $Repository
        )

        if ($Draft) { $cmdArgs += "--draft" }
        if ($Description) { $cmdArgs += @("--description", $Description) }
        if ($DescriptionFile) {
            if (-not (Test-Path $DescriptionFile)) { Write-Error "DescriptionFile not found: $DescriptionFile" }
            $descContent = Get-Content $DescriptionFile -Raw -Encoding UTF8
            $cmdArgs += @("--description", $descContent)
        }
        if ($WorkItems) { $cmdArgs += @("--work-items", $WorkItems) }

        if ($PSCmdlet.ShouldProcess("$Repository", "Create PR '$Title'")) {
            $result = az @cmdArgs --output json 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to create PR: $result"
            }
            $pr = $result | ConvertFrom-Json
            Write-Host ""
            Write-Host "PR created: #$($pr.pullRequestId)" -ForegroundColor Green
            $prUrl = $pr.url -replace 'pullRequests','pullrequest' -replace '_apis/git/repositories/[^/]+/',("_git/$Repository/pullrequest/")
            Write-Host "URL: $prUrl"
            Write-Host "Status: $($pr.status)"
        } else {
            Write-Host "WHATIF: Would create PR with:" -ForegroundColor DarkYellow
            Write-Host "  az $($cmdArgs -join ' ')" -ForegroundColor DarkYellow
        }
    }

    "publish" {
        if ($PrId -eq 0) { Write-Error "PrId is required for publish action" }

        Write-Host "--- Publishing PR #$PrId (removing draft status) ---" -ForegroundColor Yellow

        if ($PSCmdlet.ShouldProcess("PR #$PrId", "Publish (remove draft)")) {
            az repos pr update --id $PrId --status active --output none 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to publish PR #$PrId"
            }
            Write-Host "PR #$PrId published (draft removed)." -ForegroundColor Green
        } else {
            Write-Host "WHATIF: Would publish PR #$PrId" -ForegroundColor DarkYellow
        }
    }

    "update" {
        if ($PrId -eq 0) { Write-Error "PrId is required for update action" }

        Write-Host "--- Updating PR #$PrId ---" -ForegroundColor Yellow

        # Resolve description: prefer DescriptionFile (supports multi-line via @filename syntax)
        $descSource = $null
        if ($DescriptionFile) {
            if (-not (Test-Path $DescriptionFile)) { Write-Error "DescriptionFile not found: $DescriptionFile" }
            # az CLI @filename syntax reads file contents as the argument value, preserving newlines
            $descSource = "@$DescriptionFile"
            $charCount = (Get-Content $DescriptionFile -Raw).Length
            Write-Host "Description: from file ($charCount chars)"
        } elseif ($Description) {
            $descSource = $Description
            Write-Host "Description: inline ($($Description.Length) chars)"
        }

        $cmdArgs = @(
            "repos", "pr", "update",
            "--id", $PrId
        )

        if ($Title) {
            Write-Host "Title:       $Title"
            $cmdArgs += @("--title", $Title)
        }
        if ($descSource) {
            $cmdArgs += @("--description", $descSource)
        }

        if ($PSCmdlet.ShouldProcess("PR #$PrId", "Update")) {
            $ErrorActionPreference = "Continue"
            $result = az @cmdArgs --output json 2>&1
            $ErrorActionPreference = "Stop"
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to update PR #${PrId}: $result"
            }
            $pr = $result | ConvertFrom-Json
            Write-Host "PR #$PrId updated. Description: $($pr.description.Length) chars" -ForegroundColor Green
        } else {
            Write-Host "WHATIF: Would update PR #$PrId" -ForegroundColor DarkYellow
            Write-Host "  az $($cmdArgs -join ' ')" -ForegroundColor DarkYellow
        }
    }

    "complete" {
        if ($PrId -eq 0) { Write-Error "PrId is required for complete action" }

        Write-Host "--- Completing PR #$PrId ---" -ForegroundColor Yellow
        Write-Host "Squash:              $Squash"
        Write-Host "Delete source branch: $DeleteSourceBranch"

        $cmdArgs = @(
            "repos", "pr", "update",
            "--id", $PrId,
            "--status", "completed"
        )

        if ($Squash) { $cmdArgs += @("--squash", "true") }
        if ($DeleteSourceBranch) { $cmdArgs += @("--delete-source-branch", "true") }

        if ($PSCmdlet.ShouldProcess("PR #$PrId", "Complete (merge)")) {
            az @cmdArgs --output none 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Error "Failed to complete PR #$PrId"
            }
            Write-Host "PR #$PrId completed (merged)." -ForegroundColor Green
        } else {
            Write-Host "WHATIF: Would complete PR #$PrId" -ForegroundColor DarkYellow
            Write-Host "  az $($cmdArgs -join ' ')" -ForegroundColor DarkYellow
        }
    }
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
