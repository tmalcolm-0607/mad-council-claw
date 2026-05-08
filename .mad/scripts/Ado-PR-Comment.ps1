<#
.SYNOPSIS
    Post comments, replies, votes, and resolve threads on Azure DevOps PRs.
    Single script replaces 3+ inline az devops invoke POST commands.

.PARAMETER PrId
    Pull request ID (mandatory)

.PARAMETER Action
    Operation to perform: comment, reply, vote, resolve

.PARAMETER Content
    Comment or reply text (required for comment/reply actions)

.PARAMETER FilePath
    File path for inline comments (e.g., /sources/dev/SMS/src/File.cs)

.PARAMETER LineStart
    Start line for inline comments

.PARAMETER LineEnd
    End line for inline comments (defaults to LineStart + 5)

.PARAMETER ThreadId
    Thread ID (required for reply/resolve actions)

.PARAMETER Vote
    Vote value for vote action: approve, approve-with-suggestions, wait-for-author, reject

.PARAMETER Project
    Azure DevOps project (default: O365 Core)

.PARAMETER WhatIf
    Show what would be posted without making changes

.EXAMPLE
    .\Ado-PR-Comment.ps1 -PrId 4895118 -Action comment -Content "Missing null check"
    .\Ado-PR-Comment.ps1 -PrId 4895118 -Action comment -Content "Fix this" -FilePath "/src/File.cs" -LineStart 42
    .\Ado-PR-Comment.ps1 -PrId 4895118 -Action reply -ThreadId 123 -Content "Fixed in latest commit"
    .\Ado-PR-Comment.ps1 -PrId 4895118 -Action vote -Vote approve
    .\Ado-PR-Comment.ps1 -PrId 4895118 -Action resolve -ThreadId 123
    .\Ado-PR-Comment.ps1 -PrId 4895118 -Action comment -Content "Test" -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [int]$PrId,

    [Parameter(Mandatory)]
    [ValidateSet("comment", "reply", "vote", "resolve")]
    [string]$Action,

    [string]$Content,

    [string]$FilePath,

    [int]$LineStart = 0,

    [int]$LineEnd = 0,

    [int]$ThreadId = 0,

    [ValidateSet("approve", "approve-with-suggestions", "wait-for-author", "reject")]
    [string]$Vote,

    [string]$Project = "O365 Core"
)

$ErrorActionPreference = "Stop"
$env:MSYS_NO_PATHCONV = "1"

Write-Host ""
Write-Host "=== ADO PR Comment ===" -ForegroundColor Cyan
Write-Host "PR ID:   $PrId"
Write-Host "Action:  $Action"
Write-Host ""

# --- Resolve repo ID from the PR itself (authoritative) ---
$ErrorActionPreference = "Continue"
$repoId = az repos pr show --id $PrId --query "repository.id" -o tsv 2>&1
$ErrorActionPreference = "Stop"
if ($LASTEXITCODE -ne 0) {
    Write-Error "Could not resolve repository for PR #$PrId. Ensure PR exists and az CLI is authenticated."
}
$repoId = $repoId.Trim()

switch ($Action) {
    "comment" {
        if (-not $Content) { Write-Error "Content is required for comment action" }

        # Build thread JSON
        $thread = @{
            comments = @(@{
                parentCommentId = 0
                content = $Content
                commentType = 1
            })
            status = 1
        }

        # Add file context if specified
        if ($FilePath) {
            $endLine = if ($LineEnd -gt 0) { $LineEnd } elseif ($LineStart -gt 0) { $LineStart + 5 } else { 1 }
            $startLine = if ($LineStart -gt 0) { $LineStart } else { 1 }

            $thread.threadContext = @{
                filePath = $FilePath
                rightFileStart = @{ line = $startLine; offset = 1 }
                rightFileEnd = @{ line = $endLine; offset = 1 }
            }
            Write-Host "File:    $FilePath (lines $startLine-$endLine)" -ForegroundColor DarkYellow
        }

        $bodyJson = $thread | ConvertTo-Json -Depth 5 -Compress
        $bodyFile = [System.IO.Path]::GetTempFileName()
        $bodyJson | ForEach-Object { [System.IO.File]::WriteAllText($bodyFile, $_, (New-Object System.Text.UTF8Encoding $false)) }

        if ($PSCmdlet.ShouldProcess("PR #$PrId", "Post comment thread")) {
            $ErrorActionPreference = "Continue"
            $result = az devops invoke `
                --area git --resource pullRequestThreads `
                --route-parameters project="$Project" repositoryId=$repoId pullRequestId=$PrId `
                --http-method POST --api-version 7.0 `
                --in-file $bodyFile --output json 2>&1
            $ErrorActionPreference = "Stop"

            if ($LASTEXITCODE -ne 0) {
                Write-Host "  ERROR: $result" -ForegroundColor Red
                Remove-Item $bodyFile -Force
                Write-Error "Failed to post comment"
            }
            Write-Host "Comment posted." -ForegroundColor Green
        } else {
            Write-Host "WHATIF: Would post:" -ForegroundColor DarkYellow
            Write-Host $bodyJson -ForegroundColor DarkYellow
        }
        Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue
    }

    "reply" {
        if (-not $Content) { Write-Error "Content is required for reply action" }
        if ($ThreadId -eq 0) { Write-Error "ThreadId is required for reply action" }

        $reply = @{
            content = $Content
            parentCommentId = 1
            commentType = 1
        }

        $bodyJson = $reply | ConvertTo-Json -Compress
        $bodyFile = [System.IO.Path]::GetTempFileName()
        $bodyJson | ForEach-Object { [System.IO.File]::WriteAllText($bodyFile, $_, (New-Object System.Text.UTF8Encoding $false)) }

        if ($PSCmdlet.ShouldProcess("Thread #$ThreadId on PR #$PrId", "Post reply")) {
            $ErrorActionPreference = "Continue"
            $result = az devops invoke `
                --area git --resource pullRequestThreadComments `
                --route-parameters project="$Project" repositoryId=$repoId pullRequestId=$PrId threadId=$ThreadId `
                --http-method POST --api-version 7.0 `
                --in-file $bodyFile --output json 2>&1
            $ErrorActionPreference = "Stop"

            if ($LASTEXITCODE -ne 0) {
                Write-Host "  ERROR: $result" -ForegroundColor Red
                Remove-Item $bodyFile -Force
                Write-Error "Failed to post reply"
            }
            Write-Host "Reply posted to thread #${ThreadId}." -ForegroundColor Green
        } else {
            Write-Host "WHATIF: Would reply to thread #${ThreadId}:" -ForegroundColor DarkYellow
            Write-Host $bodyJson -ForegroundColor DarkYellow
        }
        Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue
    }

    "vote" {
        if (-not $Vote) { Write-Error "Vote is required for vote action" }

        if ($PSCmdlet.ShouldProcess("PR #$PrId", "Set vote to '$Vote'")) {
            $ErrorActionPreference = "Continue"
            $result = az repos pr set-vote --id $PrId --vote $Vote 2>&1
            $ErrorActionPreference = "Stop"
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  ERROR: $result" -ForegroundColor Red
                Write-Error "Failed to set vote"
            }
            Write-Host "Vote set: $Vote" -ForegroundColor Green
        } else {
            Write-Host "WHATIF: Would set vote to '$Vote' on PR #$PrId" -ForegroundColor DarkYellow
        }
    }

    "resolve" {
        if ($ThreadId -eq 0) { Write-Error "ThreadId is required for resolve action" }

        $body = @{ status = "fixed" }
        $bodyJson = $body | ConvertTo-Json -Compress
        $bodyFile = [System.IO.Path]::GetTempFileName()
        $bodyJson | ForEach-Object { [System.IO.File]::WriteAllText($bodyFile, $_, (New-Object System.Text.UTF8Encoding $false)) }

        if ($PSCmdlet.ShouldProcess("Thread #$ThreadId on PR #$PrId", "Resolve thread")) {
            $ErrorActionPreference = "Continue"
            $result = az devops invoke `
                --area git --resource pullRequestThreads `
                --route-parameters project="$Project" repositoryId=$repoId pullRequestId=$PrId threadId=$ThreadId `
                --http-method PATCH --api-version 7.0 `
                --in-file $bodyFile --output json 2>&1
            $ErrorActionPreference = "Stop"

            if ($LASTEXITCODE -ne 0) {
                Write-Host "  ERROR: $result" -ForegroundColor Red
                Remove-Item $bodyFile -Force
                Write-Error "Failed to resolve thread"
            }
            Write-Host "Thread #${ThreadId} resolved." -ForegroundColor Green
        } else {
            Write-Host "WHATIF: Would resolve thread #${ThreadId} on PR #${PrId}" -ForegroundColor DarkYellow
        }
        Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue
    }
}

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
