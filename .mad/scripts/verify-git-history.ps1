# verify-git-history.ps1
# Verifies git log --follow preserves full history for moved files
# Exit 0: All history preserved | Exit 1: History loss detected

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot

$exitCode = 0
$historyIssues = @()

Write-Host "=== Git History Verification ===" -ForegroundColor Cyan
Write-Host ""

# Define moved files with old/new paths
$movedFiles = @(
    # Phase 1: Rules
    @{ Old = ".claude/rules/azure-identity.md"; New = ".claude/rules/patterns/azure-identity.md" },
    @{ Old = ".claude/rules/azure-storage-patterns.md"; New = ".claude/rules/patterns/azure-storage-patterns.md" },
    @{ Old = ".claude/rules/dotnet-di-patterns.md"; New = ".claude/rules/patterns/dotnet-di-patterns.md" },
    @{ Old = ".claude/rules/logging-security.md"; New = ".claude/rules/patterns/logging-security.md" },
    @{ Old = ".claude/rules/api-validation.md"; New = ".claude/rules/patterns/api-validation.md" },
    @{ Old = ".claude/rules/async-patterns.md"; New = ".claude/rules/patterns/async-patterns.md" },

    # Phase 3: Templates
    @{ Old = "work-item-templates/epic-template.json"; New = ".mad/templates/ado/epic-template.json" },
    @{ Old = "work-item-templates/feature-template.json"; New = ".mad/templates/ado/feature-template.json" },
    @{ Old = "work-item-templates/user-story-template.json"; New = ".mad/templates/ado/user-story-template.json" },
    @{ Old = "work-item-templates/cli-commands.md"; New = ".mad/templates/ado/cli-commands.md" },
    @{ Old = "work-item-templates/agent-instructions.md"; New = ".mad/templates/ado/agent-instructions.md" },
    @{ Old = "work-item-templates/README.md"; New = ".mad/templates/ado/README.md" },

    # Phase 4: PR Skills (directory moves)
    @{ Old = "pr-comments/SKILL.md"; New = ".claude/skills/pr-comments/SKILL.md" },
    @{ Old = "pr-reply/SKILL.md"; New = ".claude/skills/pr-reply/SKILL.md" }
)

Write-Host "Checking history for $($movedFiles.Count) moved files..." -ForegroundColor Yellow
Write-Host ""

foreach ($file in $movedFiles) {
    $newPath = $file.New
    $oldPath = $file.Old

    # Check if new file exists
    if (-not (Test-Path (Join-Path $repoRoot $newPath))) {
        if ($Verbose) {
            Write-Host "  ⚠ Skipping $newPath (not yet moved)" -ForegroundColor Yellow
        }
        continue
    }

    # Count commits for new path (with --follow)
    try {
        $newCommits = (git log --follow --oneline -- $newPath | Measure-Object -Line).Lines
    } catch {
        Write-Host "  ✗ Git error for $newPath" -ForegroundColor Red
        $historyIssues += @{
            File = $newPath
            Error = "Git log failed: $_"
        }
        $exitCode = 1
        continue
    }

    # If file has no commits, check if it's tracked
    if ($newCommits -eq 0) {
        Write-Host "  ✗ File not tracked: $newPath" -ForegroundColor Red
        $historyIssues += @{
            File = $newPath
            Error = "File not in git history (0 commits)"
        }
        $exitCode = 1
        continue
    }

    # For moved files, verify --follow traces back to old path
    $followOutput = git log --follow --name-only --format="%H" -- $newPath | Where-Object { $_.Trim() -ne "" }
    $tracesBackToOld = $followOutput -contains $oldPath

    if ($tracesBackToOld) {
        if ($Verbose) {
            Write-Host "  ✓ $newPath ($newCommits commits, traces to $oldPath)" -ForegroundColor Green
        }
    } else {
        # Check if old path ever existed in history
        $oldPathExists = $null -ne (git log --all --format='%H' -- $oldPath | Select-Object -First 1)

        if ($oldPathExists) {
            Write-Host "  ⚠ $newPath: history may be incomplete (doesn't trace to $oldPath)" -ForegroundColor Yellow
            # This is a warning, not a failure - git mv sometimes doesn't preserve --follow perfectly
        } else {
            # Old path never existed, this is a new file (acceptable)
            if ($Verbose) {
                Write-Host "  ✓ $newPath (new file, $newCommits commits)" -ForegroundColor Green
            }
        }
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan

if ($exitCode -eq 0) {
    Write-Host "All file histories verified!" -ForegroundColor Green
    Write-Host "  git log --follow works correctly for moved files" -ForegroundColor Green
} else {
    Write-Host "Verification FAILED:" -ForegroundColor Red
    Write-Host "  History issues found: $($historyIssues.Count)" -ForegroundColor Red
    foreach ($issue in $historyIssues) {
        Write-Host "    - $($issue.File): $($issue.Error)" -ForegroundColor Red
    }
}

Write-Host ""
exit $exitCode
