# verify-kit-structure.ps1
# Verifies all expected files exist in correct locations after kit reorganization
# Exit 0: All files verified | Exit 1: Files missing or misplaced

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Expected file locations after reorganization
$expectedFiles = @{
    # Phase 1: Rules moved to patterns/
    "Rules" = @(
        ".claude/rules/patterns/azure-identity.md",
        ".claude/rules/patterns/azure-storage-patterns.md",
        ".claude/rules/patterns/dotnet-di-patterns.md",
        ".claude/rules/patterns/logging-security.md",
        ".claude/rules/patterns/api-validation.md",
        ".claude/rules/patterns/async-patterns.md"
    )
    # Phase 3: Templates moved to .mad/templates/ado/
    "Templates" = @(
        ".mad/templates/ado/epic-template.json",
        ".mad/templates/ado/feature-template.json",
        ".mad/templates/ado/user-story-template.json",
        ".mad/templates/ado/cli-commands.md",
        ".mad/templates/ado/agent-instructions.md",
        ".mad/templates/ado/README.md"
    )
    # Phase 4: PR skills moved to .claude/skills/
    "PR Skills" = @(
        ".claude/skills/pr-comments/SKILL.md",
        ".claude/skills/pr-reply/SKILL.md",
        ".claude/skills/pr-review/SKILL.md"
    )
}

# Files that should NOT exist (old locations)
$obsoleteFiles = @(
    # Old rule locations
    ".claude/rules/azure-identity.md",
    ".claude/rules/azure-storage-patterns.md",
    ".claude/rules/dotnet-di-patterns.md",
    ".claude/rules/logging-security.md",
    ".claude/rules/api-validation.md",
    ".claude/rules/async-patterns.md",
    # Old template directory
    "work-item-templates/epic-template.json",
    "work-item-templates/feature-template.json",
    "work-item-templates/user-story-template.json",
    "work-item-templates/cli-commands.md",
    "work-item-templates/agent-instructions.md",
    "work-item-templates/README.md",
    # Old PR skill locations (root)
    "pr-comments/SKILL.md",
    "pr-reply/SKILL.md"
)

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot

$exitCode = 0
$missingFiles = @()
$misplacedFiles = @()

Write-Host "=== Kit Structure Verification ===" -ForegroundColor Cyan
Write-Host ""

# Check expected files exist
foreach ($category in $expectedFiles.Keys) {
    Write-Host "Checking $category..." -ForegroundColor Yellow
    foreach ($file in $expectedFiles[$category]) {
        $fullPath = Join-Path $repoRoot $file
        if (Test-Path $fullPath) {
            if ($Verbose) {
                Write-Host "  ✓ $file" -ForegroundColor Green
            }
        } else {
            Write-Host "  ✗ File not found: $file" -ForegroundColor Red
            $missingFiles += $file
            $exitCode = 1
        }
    }
}

Write-Host ""

# Check obsolete files do NOT exist
Write-Host "Checking for obsolete files..." -ForegroundColor Yellow
foreach ($file in $obsoleteFiles) {
    $fullPath = Join-Path $repoRoot $file
    if (Test-Path $fullPath) {
        Write-Host "  ✗ File misplaced: $file (should be moved)" -ForegroundColor Red
        $misplacedFiles += $file
        $exitCode = 1
    } elseif ($Verbose) {
        Write-Host "  ✓ Correctly removed: $file" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan

if ($exitCode -eq 0) {
    Write-Host "All files verified successfully!" -ForegroundColor Green
    Write-Host "  - 6 rules in patterns/" -ForegroundColor Green
    Write-Host "  - 6 templates in .mad/templates/ado/" -ForegroundColor Green
    Write-Host "  - 3 PR skills in .claude/skills/" -ForegroundColor Green
} else {
    Write-Host "Verification FAILED:" -ForegroundColor Red
    if ($missingFiles.Count -gt 0) {
        Write-Host "  Missing files ($($missingFiles.Count)):" -ForegroundColor Red
        $missingFiles | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
    }
    if ($misplacedFiles.Count -gt 0) {
        Write-Host "  Misplaced files ($($misplacedFiles.Count)):" -ForegroundColor Red
        $misplacedFiles | ForEach-Object { Write-Host "    - $_" -ForegroundColor Red }
    }
}

Write-Host ""
exit $exitCode
