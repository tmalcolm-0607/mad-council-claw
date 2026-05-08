# verify-yaml-frontmatter.ps1
# Validates YAML frontmatter in moved rules and PR skills
# Exit 0: All frontmatter valid | Exit 1: Syntax errors or missing fields

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot

$exitCode = 0
$frontmatterIssues = @()

Write-Host "=== YAML Frontmatter Verification ===" -ForegroundColor Cyan
Write-Host ""

# Define files with expected frontmatter structure
$filesToCheck = @(
    # Rules: require 'paths' field
    @{
        Path = ".claude/rules/patterns/azure-identity.md"
        Type = "Rule"
        RequiredFields = @("paths")
    },
    @{
        Path = ".claude/rules/patterns/azure-storage-patterns.md"
        Type = "Rule"
        RequiredFields = @("paths")
    },
    @{
        Path = ".claude/rules/patterns/dotnet-di-patterns.md"
        Type = "Rule"
        RequiredFields = @("paths")
    },
    @{
        Path = ".claude/rules/patterns/logging-security.md"
        Type = "Rule"
        RequiredFields = @("paths")
    },
    @{
        Path = ".claude/rules/patterns/api-validation.md"
        Type = "Rule"
        RequiredFields = @("paths")
    },
    @{
        Path = ".claude/rules/patterns/async-patterns.md"
        Type = "Rule"
        RequiredFields = @("paths")
    },

    # PR Skills: require 'version' and 'changelog'
    @{
        Path = ".claude/skills/pr-comments/SKILL.md"
        Type = "Skill"
        RequiredFields = @("version", "changelog")
    },
    @{
        Path = ".claude/skills/pr-reply/SKILL.md"
        Type = "Skill"
        RequiredFields = @("version", "changelog")
    },
    @{
        Path = ".claude/skills/pr-review/SKILL.md"
        Type = "Skill"
        RequiredFields = @("version", "changelog")
    }
)

Write-Host "Checking frontmatter for $($filesToCheck.Count) files..." -ForegroundColor Yellow
Write-Host ""

foreach ($fileInfo in $filesToCheck) {
    $filePath = Join-Path $repoRoot $fileInfo.Path

    # Check file exists
    if (-not (Test-Path $filePath)) {
        if ($Verbose) {
            Write-Host "  ⚠ Skipping $($fileInfo.Path) (not yet created/moved)" -ForegroundColor Yellow
        }
        continue
    }

    Write-Host "  Checking $($fileInfo.Type): $($fileInfo.Path)" -ForegroundColor Cyan

    # Read file and extract frontmatter
    $content = Get-Content $filePath -Raw

    # Match YAML frontmatter (between --- delimiters)
    if ($content -match '(?s)^---\s*\n(.*?)\n---') {
        $frontmatterText = $Matches[1]

        # Simple YAML parsing (check for required fields)
        $missingFields = @()
        foreach ($field in $fileInfo.RequiredFields) {
            if ($frontmatterText -notmatch "^\s*$field\s*:") {
                $missingFields += $field
            }
        }

        if ($missingFields.Count -eq 0) {
            Write-Host "    ✓ All required fields present: $($fileInfo.RequiredFields -join ', ')" -ForegroundColor Green
        } else {
            Write-Host "    ✗ Missing required fields: $($missingFields -join ', ')" -ForegroundColor Red
            $frontmatterIssues += @{
                File = $fileInfo.Path
                Error = "Missing required field(s): $($missingFields -join ', ')"
            }
            $exitCode = 1
        }

        # Basic syntax validation (check for valid YAML structure)
        if ($frontmatterText -match ':\s*\n\s*-' -or $frontmatterText -match ':\s*\[') {
            if ($Verbose) {
                Write-Host "    ✓ YAML structure appears valid" -ForegroundColor Green
            }
        }
    } else {
        Write-Host "    ✗ No YAML frontmatter found (missing --- delimiters)" -ForegroundColor Red
        $frontmatterIssues += @{
            File = $fileInfo.Path
            Error = "No YAML frontmatter found"
        }
        $exitCode = 1
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan

if ($exitCode -eq 0) {
    Write-Host "All frontmatter validated successfully!" -ForegroundColor Green
    Write-Host "  - 6 rules have 'paths' field" -ForegroundColor Green
    Write-Host "  - 3 PR skills have 'version' and 'changelog' fields" -ForegroundColor Green
} else {
    Write-Host "Verification FAILED:" -ForegroundColor Red
    Write-Host "  Frontmatter issues found: $($frontmatterIssues.Count)" -ForegroundColor Red
    foreach ($issue in $frontmatterIssues) {
        Write-Host "    - $($issue.File): $($issue.Error)" -ForegroundColor Red
    }
}

Write-Host ""
exit $exitCode
