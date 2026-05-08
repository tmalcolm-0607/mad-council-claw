<#
.SYNOPSIS
    Validate token limits for Claude Code configuration files.

.DESCRIPTION
    Checks all agents, skills, and patterns against token limits:
    - Agents: 800 tokens max
    - Skills: 2000 tokens max
    - Patterns: 1500 tokens max

.PARAMETER Path
    Root path to scan. Default: current directory

.PARAMETER Fix
    Suggest trimming for oversized files

.EXAMPLE
    .\Validate-TokenLimits.ps1
    # Validates all Claude files in current directory

.EXAMPLE
    .\Validate-TokenLimits.ps1 -Fix
    # Shows suggestions for trimming oversized files

.NOTES
    Run from repository root.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Path = ".",

    [Parameter()]
    [switch]$Fix
)

$ErrorActionPreference = "Continue"

# Token limits
$limits = @{
    Agents = 800
    Skills = 2000
    Patterns = 1500
}

# Results
$violations = @{
    Agents = @()
    Skills = @()
    Patterns = @()
}

function Get-TokenEstimate {
    param([string]$Content)
    $wordCount = ($Content -split '\s+').Count
    return [math]::Ceiling($wordCount * 1.3)
}

function Test-TokenLimit {
    param(
        [string]$FilePath,
        [int]$Limit,
        [string]$Category
    )

    $content = Get-Content $FilePath -Raw
    $tokens = Get-TokenEstimate -Content $content
    $fileName = Split-Path -Leaf $FilePath

    if ($tokens -gt $Limit) {
        return [PSCustomObject]@{
            File = $fileName
            Path = $FilePath
            Tokens = $tokens
            Limit = $Limit
            Over = $tokens - $Limit
            Category = $Category
        }
    }
    return $null
}

# Header
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Token Limit Validator" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Limits:" -ForegroundColor Gray
Write-Host "  Agents:   $($limits.Agents) tokens" -ForegroundColor Gray
Write-Host "  Skills:   $($limits.Skills) tokens" -ForegroundColor Gray
Write-Host "  Patterns: $($limits.Patterns) tokens" -ForegroundColor Gray
Write-Host ""

# Check agents
$agentPath = Join-Path $Path ".claude/agents"
if (Test-Path $agentPath) {
    Write-Host "Checking agents..." -ForegroundColor Gray
    $agentFiles = Get-ChildItem -Path $agentPath -Filter "*.md" | Where-Object { $_.Name -ne "README.md" }
    foreach ($file in $agentFiles) {
        $result = Test-TokenLimit -FilePath $file.FullName -Limit $limits.Agents -Category "Agent"
        if ($result) {
            $violations.Agents += $result
        }
    }
}

# Check skills
$skillPath = Join-Path $Path ".claude/skills"
if (Test-Path $skillPath) {
    Write-Host "Checking skills..." -ForegroundColor Gray
    $skillDirs = Get-ChildItem -Path $skillPath -Directory | Where-Object { $_.Name -ne "_template" }
    foreach ($dir in $skillDirs) {
        $skillFile = Join-Path $dir.FullName "SKILL.md"
        if (Test-Path $skillFile) {
            $result = Test-TokenLimit -FilePath $skillFile -Limit $limits.Skills -Category "Skill"
            if ($result) {
                $violations.Skills += $result
            }
        }
    }
}

# Check patterns
$patternPath = Join-Path $Path ".claude/rules/patterns"
if (Test-Path $patternPath) {
    Write-Host "Checking patterns..." -ForegroundColor Gray
    $patternFiles = Get-ChildItem -Path $patternPath -Filter "*.md" | Where-Object { $_.Name -ne "README.md" }
    foreach ($file in $patternFiles) {
        $result = Test-TokenLimit -FilePath $file.FullName -Limit $limits.Patterns -Category "Pattern"
        if ($result) {
            $violations.Patterns += $result
        }
    }
}

# Report
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Results" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

$totalViolations = $violations.Agents.Count + $violations.Skills.Count + $violations.Patterns.Count

if ($totalViolations -eq 0) {
    Write-Host "All files within token limits!" -ForegroundColor Green
}
else {
    Write-Host "Found $totalViolations files over limit:`n" -ForegroundColor Yellow

    # Agents
    if ($violations.Agents.Count -gt 0) {
        Write-Host "AGENTS ($($violations.Agents.Count) over limit):" -ForegroundColor Yellow
        foreach ($v in $violations.Agents | Sort-Object -Property Over -Descending) {
            Write-Host "  [!] $($v.File): $($v.Tokens) tokens (+$($v.Over) over)" -ForegroundColor Red
            if ($Fix) {
                Write-Host "      Suggestion: Remove verbose examples, consolidate sections" -ForegroundColor Gray
            }
        }
        Write-Host ""
    }

    # Skills
    if ($violations.Skills.Count -gt 0) {
        Write-Host "SKILLS ($($violations.Skills.Count) over limit):" -ForegroundColor Yellow
        foreach ($v in $violations.Skills | Sort-Object -Property Over -Descending) {
            Write-Host "  [!] $($v.File): $($v.Tokens) tokens (+$($v.Over) over)" -ForegroundColor Red
            if ($Fix) {
                $parentDir = Split-Path (Split-Path $v.Path -Parent) -Leaf
                Write-Host "      Skill: $parentDir" -ForegroundColor Gray
                Write-Host "      Suggestion: Move detailed examples to separate docs" -ForegroundColor Gray
            }
        }
        Write-Host ""
    }

    # Patterns
    if ($violations.Patterns.Count -gt 0) {
        Write-Host "PATTERNS ($($violations.Patterns.Count) over limit):" -ForegroundColor Yellow
        foreach ($v in $violations.Patterns | Sort-Object -Property Over -Descending) {
            Write-Host "  [!] $($v.File): $($v.Tokens) tokens (+$($v.Over) over)" -ForegroundColor Red
            if ($Fix) {
                Write-Host "      Suggestion: Split into focused sub-patterns" -ForegroundColor Gray
            }
        }
        Write-Host ""
    }
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Agents over limit:   $($violations.Agents.Count)"
Write-Host "  Skills over limit:   $($violations.Skills.Count)"
Write-Host "  Patterns over limit: $($violations.Patterns.Count)"
Write-Host "  Total violations:    $totalViolations"

# Exit code
if ($totalViolations -gt 0) {
    Write-Host "`nSTATUS: FAIL (files over token limit)" -ForegroundColor Red
    exit 1
}
else {
    Write-Host "`nSTATUS: PASS" -ForegroundColor Green
    exit 0
}
