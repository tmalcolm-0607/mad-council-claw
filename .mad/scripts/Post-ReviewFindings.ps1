<#
.SYNOPSIS
    Post review findings as individual inline comments on an Azure DevOps PR.
    Each finding becomes its own thread anchored to the specific file and line.

.PARAMETER PrId
    Pull request ID (mandatory)

.PARAMETER FindingsFile
    Path to JSON file with findings array.
    Each finding: { file, line, line_end?, comment }
    - file: ADO repo-relative path (e.g., /sources/dev/SMS/src/File.cs). Null for general comments.
    - line: Start line number. 0 or absent for general comments.
    - line_end: End line number. Defaults to line if omitted.
    - comment: The comment text (short, conversational, human-like).

.PARAMETER Summary
    Optional summary text posted as a general (non-inline) comment after all findings.
    If omitted, an auto-generated summary is posted based on findings count.

.PARAMETER Vote
    Optional vote after posting: approve, approve-with-suggestions, wait-for-author, reject

.PARAMETER NoSummary
    Skip posting a summary comment entirely.

.PARAMETER Project
    Azure DevOps project (default: O365 Core)

.PARAMETER WhatIf
    Preview what would be posted without making changes

.EXAMPLE
    .\Post-ReviewFindings.ps1 -PrId 4922977 -FindingsFile .mad/scratch/review-4922977/findings.json
    .\Post-ReviewFindings.ps1 -PrId 4922977 -FindingsFile findings.json -Vote wait-for-author
    .\Post-ReviewFindings.ps1 -PrId 4922977 -FindingsFile findings.json -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [int]$PrId,

    [Parameter(Mandatory)]
    [string]$FindingsFile,

    [string]$Summary,

    [ValidateSet("approve", "approve-with-suggestions", "wait-for-author", "reject")]
    [string]$Vote,

    [switch]$NoSummary,

    [string]$Project = "O365 Core"
)

$ErrorActionPreference = "Stop"
$env:MSYS_NO_PATHCONV = "1"

Write-Host ""
Write-Host "=== Post Review Findings ===" -ForegroundColor Cyan
Write-Host "PR ID:    $PrId"
Write-Host "Findings: $FindingsFile"
Write-Host ""

# --- Validate findings file ---
if (-not (Test-Path $FindingsFile)) {
    Write-Error "Findings file not found: $FindingsFile"
}

$findings = Get-Content $FindingsFile -Raw | ConvertFrom-Json
if (-not $findings -or $findings.Count -eq 0) {
    Write-Host "No findings to post." -ForegroundColor DarkYellow
    if ($Vote) {
        Write-Host "Setting vote: $Vote" -ForegroundColor Yellow
        $ErrorActionPreference = "Continue"
        az repos pr set-vote --id $PrId --vote $Vote 2>&1 | Out-Null
        $ErrorActionPreference = "Stop"
        if ($LASTEXITCODE -ne 0) { Write-Error "Failed to set vote" }
        Write-Host "Vote set: $Vote" -ForegroundColor Green
    }
    return
}

Write-Host "Found $($findings.Count) findings." -ForegroundColor Yellow

# --- Resolve repo ID once ---
$ErrorActionPreference = "Continue"
$repoId = az repos pr show --id $PrId --query "repository.id" -o tsv 2>&1
$ErrorActionPreference = "Stop"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Could not resolve repository for PR #$PrId. Ensure PR exists and az CLI is authenticated."
}
$repoId = $repoId.Trim()

# --- Post each finding as an individual thread ---
$posted = 0
$failed = 0
$index = 0

foreach ($f in $findings) {
    $index++
    $commentText = $f.comment
    if (-not $commentText) {
        Write-Host "  [$index/$($findings.Count)] SKIP - empty comment" -ForegroundColor DarkYellow
        continue
    }

    # Build thread JSON
    $thread = @{
        comments = @(@{
            parentCommentId = 0
            content          = $commentText
            commentType      = 1
        })
        status = 1
    }

    # Add file context for inline comments
    $filePath = $f.file
    $lineStart = if ($f.line) { [int]$f.line } else { 0 }

    if ($filePath -and $lineStart -gt 0) {
        $lineEnd = if ($f.line_end -and [int]$f.line_end -gt 0) { [int]$f.line_end } else { $lineStart }

        $thread.threadContext = @{
            filePath       = $filePath
            rightFileStart = @{ line = $lineStart; offset = 1 }
            rightFileEnd   = @{ line = $lineEnd; offset = 1 }
        }

        $locationLabel = "$filePath`:$lineStart"
        if ($lineEnd -ne $lineStart) { $locationLabel += "-$lineEnd" }
    }
    else {
        $locationLabel = "(general)"
    }

    $bodyJson = $thread | ConvertTo-Json -Depth 5 -Compress
    $bodyFile = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($bodyFile, $bodyJson, [System.Text.UTF8Encoding]::new($false))

    $truncated = if ($commentText.Length -gt 80) { $commentText.Substring(0, 77) + "..." } else { $commentText }

    if ($PSCmdlet.ShouldProcess("PR #$PrId $locationLabel", "Post comment")) {
        $ErrorActionPreference = "Continue"
        $result = az devops invoke `
            --area git --resource pullRequestThreads `
            --route-parameters project="$Project" repositoryId=$repoId pullRequestId=$PrId `
            --http-method POST --api-version 7.0 `
            --in-file $bodyFile --output json 2>&1
        $ErrorActionPreference = "Stop"

        if ($LASTEXITCODE -ne 0) {
            $failed++
            Write-Host "  [$index/$($findings.Count)] FAIL $locationLabel" -ForegroundColor Red
            Write-Host "    $result" -ForegroundColor DarkRed
        }
        else {
            $posted++
            Write-Host "  [$index/$($findings.Count)] OK   $locationLabel" -ForegroundColor Green
            Write-Host "    $truncated" -ForegroundColor DarkGray
        }
    }
    else {
        Write-Host "  [$index/$($findings.Count)] WHATIF $locationLabel" -ForegroundColor DarkYellow
        Write-Host "    $truncated" -ForegroundColor DarkGray
    }

    Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue
}

# --- Post summary comment ---
# Default behavior: do NOT post a summary thread. The auto-generated
# "Reviewed - N comment(s) posted." line is unhelpful noise on the PR. To post a
# real summary, the caller must pass an explicit -Summary "..." string.
# Per user feedback (memory: feedback_no_summary_comments.md, 2026-05).
if ((-not $NoSummary) -and $Summary) {
    $summaryText = $Summary

    $summaryThread = @{
        comments = @(@{
            parentCommentId = 0
            content          = $summaryText
            commentType      = 1
        })
        status = 1
    }

    $bodyJson = $summaryThread | ConvertTo-Json -Depth 5 -Compress
    $bodyFile = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($bodyFile, $bodyJson, [System.Text.UTF8Encoding]::new($false))

    if ($PSCmdlet.ShouldProcess("PR #$PrId", "Post summary comment")) {
        $ErrorActionPreference = "Continue"
        az devops invoke `
            --area git --resource pullRequestThreads `
            --route-parameters project="$Project" repositoryId=$repoId pullRequestId=$PrId `
            --http-method POST --api-version 7.0 `
            --in-file $bodyFile --output json 2>&1 | Out-Null
        $ErrorActionPreference = "Stop"

        if ($LASTEXITCODE -ne 0) {
            Write-Host "  WARN: Failed to post summary comment" -ForegroundColor DarkYellow
        }
        else {
            Write-Host "  Summary posted." -ForegroundColor Green
        }
    }
    Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue
}

# --- Set vote ---
if ($Vote) {
    if ($PSCmdlet.ShouldProcess("PR #$PrId", "Set vote to '$Vote'")) {
        $ErrorActionPreference = "Continue"
        $result = az repos pr set-vote --id $PrId --vote $Vote 2>&1
        $ErrorActionPreference = "Stop"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  WARN: Failed to set vote: $result" -ForegroundColor DarkYellow
        }
        else {
            Write-Host "  Vote set: $Vote" -ForegroundColor Green
        }
    }
}

# --- Summary ---
Write-Host ""
Write-Host "=== Results ===" -ForegroundColor Cyan
Write-Host "Posted: $posted / $($findings.Count)"
if ($failed -gt 0) {
    Write-Host "Failed: $failed" -ForegroundColor Red
}
Write-Host "=== Done ===" -ForegroundColor Cyan
