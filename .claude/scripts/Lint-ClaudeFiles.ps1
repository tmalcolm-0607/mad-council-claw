<#
.SYNOPSIS
    Validate Claude Code configuration files (agents, skills, patterns).

.DESCRIPTION
    Scans .claude/ directory for configuration files and validates:
    - YAML frontmatter presence and format
    - Required fields for each file type
    - Token count estimates

.PARAMETER Path
    Root path to scan. Default: current directory

.PARAMETER AgentTokenLimit
    Maximum tokens for agent files. Default: 800

.PARAMETER SkillTokenLimit
    Maximum tokens for skill files. Default: 2000

.PARAMETER PatternTokenLimit
    Maximum tokens for pattern files. Default: 1500

.PARAMETER Strict
    Treat warnings as errors. Default: false

.EXAMPLE
    .\Lint-ClaudeFiles.ps1
    # Validates all Claude files in current directory

.EXAMPLE
    .\Lint-ClaudeFiles.ps1 -Strict
    # Validates with warnings as errors

.NOTES
    Run from repository root.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$Path = ".",

    [Parameter()]
    [int]$AgentTokenLimit = 800,

    [Parameter()]
    [int]$SkillTokenLimit = 2000,

    [Parameter()]
    [int]$PatternTokenLimit = 1500,

    [Parameter()]
    [switch]$Strict
)

$ErrorActionPreference = "Continue"

# Results collection
$results = @{
    Agents = @()
    Skills = @()
    Patterns = @()
}

$errors = 0
$warnings = 0

function Get-TokenEstimate {
    param([string]$Content)
    # Rough estimate: 1 token ≈ 0.75 words
    $wordCount = ($Content -split '\s+').Count
    return [math]::Ceiling($wordCount * 1.3)
}

function Test-YamlFrontmatter {
    param([string]$Content)

    if ($Content -match "^---\r?\n([\s\S]*?)\r?\n---") {
        return @{
            Valid = $true
            Frontmatter = $Matches[1]
        }
    }
    return @{ Valid = $false; Frontmatter = $null }
}

function Get-FrontmatterField {
    param([string]$Frontmatter, [string]$Field)

    if ($Frontmatter -match "(?m)^${Field}:\s*(.+)$") {
        return $Matches[1].Trim()
    }
    return $null
}

function Test-AgentFile {
    param([string]$FilePath)

    $content = Get-Content $FilePath -Raw
    $fileName = Split-Path -Leaf $FilePath
    $issues = @()

    # Check frontmatter
    $fm = Test-YamlFrontmatter -Content $content
    if (-not $fm.Valid) {
        $issues += "ERROR: Missing or invalid YAML frontmatter"
    }
    else {
        # Required fields for agents
        $requiredFields = @("name", "version", "tags", "category", "model")
        foreach ($field in $requiredFields) {
            $value = Get-FrontmatterField -Frontmatter $fm.Frontmatter -Field $field
            if (-not $value) {
                $issues += "ERROR: Missing required field: $field"
            }
        }

        # Recommended fields (warnings)
        $recommendedFields = @("tools", "model_rationale", "estimated_tokens")
        foreach ($field in $recommendedFields) {
            $value = Get-FrontmatterField -Frontmatter $fm.Frontmatter -Field $field
            if (-not $value) {
                $issues += "WARN: Missing recommended field: $field"
            }
        }
    }

    # Check token estimate
    $tokens = Get-TokenEstimate -Content $content
    if ($tokens -gt $AgentTokenLimit) {
        $issues += "WARN: Token estimate ($tokens) exceeds limit ($AgentTokenLimit)"
    }

    return [PSCustomObject]@{
        File = $fileName
        Path = $FilePath
        Tokens = $tokens
        Issues = $issues
        HasErrors = ($issues | Where-Object { $_ -like "ERROR:*" }).Count -gt 0
        HasWarnings = ($issues | Where-Object { $_ -like "WARN:*" }).Count -gt 0
    }
}

function Test-SkillFile {
    param([string]$FilePath)

    $content = Get-Content $FilePath -Raw
    $fileName = Split-Path -Leaf $FilePath
    $issues = @()

    # Check frontmatter
    $fm = Test-YamlFrontmatter -Content $content
    if (-not $fm.Valid) {
        $issues += "ERROR: Missing or invalid YAML frontmatter"
    }
    else {
        # Required fields for skills
        $requiredFields = @("name", "version")
        foreach ($field in $requiredFields) {
            $value = Get-FrontmatterField -Frontmatter $fm.Frontmatter -Field $field
            if (-not $value) {
                $issues += "ERROR: Missing required field: $field"
            }
        }

        # Recommended fields
        $recommendedFields = @("tags", "invocation", "description")
        foreach ($field in $recommendedFields) {
            $value = Get-FrontmatterField -Frontmatter $fm.Frontmatter -Field $field
            if (-not $value) {
                $issues += "WARN: Missing recommended field: $field"
            }
        }
    }

    # Check token estimate
    $tokens = Get-TokenEstimate -Content $content
    if ($tokens -gt $SkillTokenLimit) {
        $issues += "WARN: Token estimate ($tokens) exceeds limit ($SkillTokenLimit)"
    }

    return [PSCustomObject]@{
        File = $fileName
        Path = $FilePath
        Tokens = $tokens
        Issues = $issues
        HasErrors = ($issues | Where-Object { $_ -like "ERROR:*" }).Count -gt 0
        HasWarnings = ($issues | Where-Object { $_ -like "WARN:*" }).Count -gt 0
    }
}

function Test-PatternFile {
    param([string]$FilePath)

    $content = Get-Content $FilePath -Raw
    $fileName = Split-Path -Leaf $FilePath
    $issues = @()

    # Check frontmatter (patterns must have paths)
    $fm = Test-YamlFrontmatter -Content $content
    if (-not $fm.Valid) {
        $issues += "ERROR: Missing or invalid YAML frontmatter"
    }
    else {
        # Patterns should have paths
        if ($fm.Frontmatter -notmatch "paths:") {
            $issues += "WARN: Missing paths field (pattern won't be auto-loaded)"
        }
    }

    # Check token estimate
    $tokens = Get-TokenEstimate -Content $content
    if ($tokens -gt $PatternTokenLimit) {
        $issues += "WARN: Token estimate ($tokens) exceeds limit ($PatternTokenLimit)"
    }

    # Check for required sections
    $requiredSections = @("## Enforcement", "## Anti-Pattern")
    foreach ($section in $requiredSections) {
        if ($content -notmatch [regex]::Escape($section)) {
            $issues += "WARN: Missing recommended section: $section"
        }
    }

    return [PSCustomObject]@{
        File = $fileName
        Path = $FilePath
        Tokens = $tokens
        Issues = $issues
        HasErrors = ($issues | Where-Object { $_ -like "ERROR:*" }).Count -gt 0
        HasWarnings = ($issues | Where-Object { $_ -like "WARN:*" }).Count -gt 0
    }
}

# Header
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Claude Configuration File Linter" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Scan agents
$agentPath = Join-Path $Path ".claude/agents"
if (Test-Path $agentPath) {
    Write-Host "Scanning agents..." -ForegroundColor Gray
    $agentFiles = Get-ChildItem -Path $agentPath -Filter "*.md" | Where-Object { $_.Name -ne "README.md" }
    foreach ($file in $agentFiles) {
        $result = Test-AgentFile -FilePath $file.FullName
        $results.Agents += $result
        if ($result.HasErrors) { $errors++ }
        if ($result.HasWarnings) { $warnings++ }
    }
}

# Scan skills
$skillPath = Join-Path $Path ".claude/skills"
if (Test-Path $skillPath) {
    Write-Host "Scanning skills..." -ForegroundColor Gray
    $skillDirs = Get-ChildItem -Path $skillPath -Directory | Where-Object { $_.Name -ne "_template" }
    foreach ($dir in $skillDirs) {
        $skillFile = Join-Path $dir.FullName "SKILL.md"
        if (Test-Path $skillFile) {
            $result = Test-SkillFile -FilePath $skillFile
            $results.Skills += $result
            if ($result.HasErrors) { $errors++ }
            if ($result.HasWarnings) { $warnings++ }
        }
    }
}

# Scan patterns
$patternPath = Join-Path $Path ".claude/rules/patterns"
if (Test-Path $patternPath) {
    Write-Host "Scanning patterns..." -ForegroundColor Gray
    $patternFiles = Get-ChildItem -Path $patternPath -Filter "*.md" | Where-Object { $_.Name -ne "README.md" }
    foreach ($file in $patternFiles) {
        $result = Test-PatternFile -FilePath $file.FullName
        $results.Patterns += $result
        if ($result.HasErrors) { $errors++ }
        if ($result.HasWarnings) { $warnings++ }
    }
}

# Report results
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Results" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Agents
Write-Host "AGENTS ($($results.Agents.Count) files):" -ForegroundColor Yellow
foreach ($agent in $results.Agents) {
    $status = if ($agent.HasErrors) { "X" } elseif ($agent.HasWarnings) { "!" } else { "+" }
    $color = if ($agent.HasErrors) { "Red" } elseif ($agent.HasWarnings) { "Yellow" } else { "Green" }
    Write-Host "  [$status] $($agent.File) ($($agent.Tokens) tokens)" -ForegroundColor $color
    foreach ($issue in $agent.Issues) {
        $issueColor = if ($issue -like "ERROR:*") { "Red" } else { "Yellow" }
        Write-Host "      $issue" -ForegroundColor $issueColor
    }
}

# Skills
Write-Host "`nSKILLS ($($results.Skills.Count) files):" -ForegroundColor Yellow
foreach ($skill in $results.Skills) {
    $status = if ($skill.HasErrors) { "X" } elseif ($skill.HasWarnings) { "!" } else { "+" }
    $color = if ($skill.HasErrors) { "Red" } elseif ($skill.HasWarnings) { "Yellow" } else { "Green" }
    Write-Host "  [$status] $($skill.File) ($($skill.Tokens) tokens)" -ForegroundColor $color
    foreach ($issue in $skill.Issues) {
        $issueColor = if ($issue -like "ERROR:*") { "Red" } else { "Yellow" }
        Write-Host "      $issue" -ForegroundColor $issueColor
    }
}

# Patterns
Write-Host "`nPATTERNS ($($results.Patterns.Count) files):" -ForegroundColor Yellow
foreach ($pattern in $results.Patterns) {
    $status = if ($pattern.HasErrors) { "X" } elseif ($pattern.HasWarnings) { "!" } else { "+" }
    $color = if ($pattern.HasErrors) { "Red" } elseif ($pattern.HasWarnings) { "Yellow" } else { "Green" }
    Write-Host "  [$status] $($pattern.File) ($($pattern.Tokens) tokens)" -ForegroundColor $color
    foreach ($issue in $pattern.Issues) {
        $issueColor = if ($issue -like "ERROR:*") { "Red" } else { "Yellow" }
        Write-Host "      $issue" -ForegroundColor $issueColor
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Agents:   $($results.Agents.Count)"
Write-Host "  Skills:   $($results.Skills.Count)"
Write-Host "  Patterns: $($results.Patterns.Count)"
Write-Host "  Errors:   $errors"
Write-Host "  Warnings: $warnings"

# Exit code
if ($errors -gt 0) {
    Write-Host "`nSTATUS: FAIL (errors found)" -ForegroundColor Red
    exit 1
}
elseif ($Strict -and $warnings -gt 0) {
    Write-Host "`nSTATUS: FAIL (strict mode, warnings found)" -ForegroundColor Yellow
    exit 1
}
else {
    Write-Host "`nSTATUS: PASS" -ForegroundColor Green
    exit 0
}
