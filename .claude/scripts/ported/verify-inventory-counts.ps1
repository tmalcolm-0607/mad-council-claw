# verify-inventory-counts.ps1
# Validates documented counts match actual file counts in inventory files
# Exit 0: All counts accurate | Exit 1: Count mismatches found

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
Set-Location $repoRoot

$exitCode = 0
$mismatches = @()

Write-Host "=== Inventory Count Verification ===" -ForegroundColor Cyan
Write-Host ""

# Define inventory locations and what they document
$inventories = @(
    @{
        Name = "patterns/README.md"
        Path = ".claude/rules/patterns/README.md"
        CountPattern = '## .NET / C# \(Reference Library\)\s+Reusable .NET patterns.*\s+\*\*(\d+) files\*\*'
        ActualCount = (Get-ChildItem ".claude/rules/patterns/*.md" -Exclude "README.md" | Measure-Object).Count
        Description = ".NET pattern files"
    },
    @{
        Name = "component-scanner.md"
        Path = ".claude/agents/component-scanner.md"
        CountPattern = 'dotnet.*?(\d+)\s+files'
        ActualCount = (Get-ChildItem ".claude/rules/patterns/*dotnet*.md", ".claude/rules/patterns/*azure*.md", ".claude/rules/patterns/*csharp*.md", ".claude/rules/patterns/api-validation.md", ".claude/rules/patterns/async-patterns.md", ".claude/rules/patterns/logging-security.md" -ErrorAction SilentlyContinue | Measure-Object).Count
        Description = ".NET-specific patterns"
    },
    @{
        Name = "component-cleaner.md"
        Path = ".claude/agents/component-cleaner.md"
        CountPattern = '## \.NET Components.*?Patterns:.*?\n((?:- .*\n)+)'
        ActualCount = 6  # The 6 moved rules
        Description = ".NET components in cleaner inventory"
    },
    @{
        Name = "project-init/SKILL.md"
        Path = ".claude/skills/project-init/SKILL.md"
        CountPattern = 'Protected.*?\.NET.*?(\d+)\s+(?:files|patterns)'
        ActualCount = 6  # The 6 moved rules that should be protected
        Description = ".NET protected patterns"
    }
)

foreach ($inventory in $inventories) {
    Write-Host "Checking $($inventory.Name)..." -ForegroundColor Yellow

    $filePath = Join-Path $repoRoot $inventory.Path

    if (-not (Test-Path $filePath)) {
        Write-Host "  ✗ Inventory file not found: $($inventory.Path)" -ForegroundColor Red
        $mismatches += @{
            File = $inventory.Name
            Error = "File not found"
        }
        $exitCode = 1
        continue
    }

    $content = Get-Content $filePath -Raw

    # Try to extract documented count
    if ($content -match $inventory.CountPattern) {
        $documentedCount = [int]$Matches[1]
        $actualCount = $inventory.ActualCount

        if ($documentedCount -eq $actualCount) {
            Write-Host "  ✓ $($inventory.Description): documented=$documentedCount, actual=$actualCount" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Inventory mismatch: documented=$documentedCount, actual=$actualCount" -ForegroundColor Red
            $mismatches += @{
                File = $inventory.Name
                Description = $inventory.Description
                Documented = $documentedCount
                Actual = $actualCount
            }
            $exitCode = 1
        }
    } else {
        Write-Host "  ⚠ Cannot parse count pattern in $($inventory.Name)" -ForegroundColor Yellow
        if ($Verbose) {
            Write-Host "    Pattern: $($inventory.CountPattern)" -ForegroundColor Gray
        }
        $mismatches += @{
            File = $inventory.Name
            Error = "Cannot parse count pattern"
        }
        $exitCode = 1
    }
}

Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan

if ($exitCode -eq 0) {
    Write-Host "All inventory counts accurate!" -ForegroundColor Green
} else {
    Write-Host "Verification FAILED:" -ForegroundColor Red
    Write-Host "  Mismatches found: $($mismatches.Count)" -ForegroundColor Red
    foreach ($mismatch in $mismatches) {
        if ($mismatch.Error) {
            Write-Host "    - $($mismatch.File): $($mismatch.Error)" -ForegroundColor Red
        } else {
            Write-Host "    - $($mismatch.File) ($($mismatch.Description)): documented=$($mismatch.Documented), actual=$($mismatch.Actual)" -ForegroundColor Red
        }
    }
}

Write-Host ""
exit $exitCode
