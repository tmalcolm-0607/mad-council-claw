#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Quick automated checks for post-phase review
.DESCRIPTION
    Runs TypeScript compilation, tests, Docker health checks, and git status
    to verify phase completion and readiness for next phase.
.EXAMPLE
    .\.specify\scripts\powershell\phase-review.ps1
#>

param(
    [switch]$Verbose,
    [switch]$SkipTests,
    [switch]$SkipDocker
)

$ErrorActionPreference = 'Continue'
$script:FailCount = 0

function Write-Check {
    param([string]$Message, [string]$Status)
    $color = switch ($Status) {
        'PASS' { 'Green' }
        'FAIL' { 'Red' }
        'WARN' { 'Yellow' }
        'INFO' { 'Cyan' }
        default { 'White' }
    }
    Write-Host "[$Status] $Message" -ForegroundColor $color
    if ($Status -eq 'FAIL') { $script:FailCount++ }
}

Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║       Post-Phase Review               ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Cyan

# 1. TypeScript Compilation
Write-Host "1. TypeScript Compilation" -ForegroundColor Yellow
Write-Host "   Running: npm run typecheck`n" -ForegroundColor Gray
$typecheckResult = npm run typecheck 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Check "TypeScript compiles without errors" "PASS"
} else {
    Write-Check "TypeScript compilation failed" "FAIL"
    if ($Verbose) { $typecheckResult | Select-Object -Last 20 }
}

# 2. Linting
Write-Host "`n2. Code Linting" -ForegroundColor Yellow
Write-Host "   Running: npm run lint`n" -ForegroundColor Gray
$lintResult = npm run lint 2>&1
if ($LASTEXITCODE -eq 0) {
    Write-Check "Linting passed" "PASS"
} else {
    Write-Check "Linting found issues" "WARN"
    if ($Verbose) { $lintResult | Select-Object -Last 10 }
}

# 3. Backend Tests
if (-not $SkipTests) {
    Write-Host "`n3. Backend Tests" -ForegroundColor Yellow
    Write-Host "   Running: npm test --workspace=backend`n" -ForegroundColor Gray
    $testResult = npm test --workspace=backend 2>&1
    if ($LASTEXITCODE -eq 0) {
        $passing = ($testResult | Select-String "(\d+) passing" | ForEach-Object { $_.Matches.Groups[1].Value })
        Write-Check "Backend tests passed ($passing tests)" "PASS"
    } else {
        Write-Check "Backend tests failed" "FAIL"
        if ($Verbose) { $testResult | Select-Object -Last 20 }
    }
} else {
    Write-Check "Backend tests skipped" "INFO"
}

# 4. Docker Status
if (-not $SkipDocker) {
    Write-Host "`n4. Docker Deployment" -ForegroundColor Yellow
    Write-Host "   Running: docker compose ps`n" -ForegroundColor Gray
    $dockerPs = docker compose ps 2>&1
    if ($LASTEXITCODE -eq 0) {
        $healthy = ($dockerPs | Select-String "healthy" | Measure-Object).Count
        $unhealthy = ($dockerPs | Select-String "unhealthy" | Measure-Object).Count
        
        if ($unhealthy -gt 0) {
            Write-Check "Docker services unhealthy ($unhealthy services)" "FAIL"
        } elseif ($healthy -gt 0) {
            Write-Check "Docker services healthy ($healthy services)" "PASS"
        } else {
            Write-Check "Docker services not running" "WARN"
        }
        
        if ($Verbose) {
            Write-Host "`n   Docker Services:" -ForegroundColor Gray
            $dockerPs | Out-String | Write-Host -ForegroundColor Gray
        }
    } else {
        Write-Check "Docker not running or not installed" "WARN"
    }
} else {
    Write-Check "Docker checks skipped" "INFO"
}

# 5. Git Status
Write-Host "`n5. Git Repository Status" -ForegroundColor Yellow
Write-Host "   Running: git status --short`n" -ForegroundColor Gray
$gitStatus = git status --short 2>&1
if ($gitStatus) {
    $uncommitted = ($gitStatus | Measure-Object).Count
    Write-Check "Uncommitted changes detected ($uncommitted files)" "WARN"
    if ($Verbose) {
        Write-Host "`n   Uncommitted files:" -ForegroundColor Gray
        $gitStatus | Out-String | Write-Host -ForegroundColor Gray
    }
} else {
    Write-Check "Working tree clean" "PASS"
}

# 6. Port Usage Check
Write-Host "`n6. Standard Port Usage" -ForegroundColor Yellow
$ports = @(3001, 5173, 4173, 5432)
$portsInUse = @()
foreach ($port in $ports) {
    $conn = Get-NetTCPConnection -LocalPort $port -ErrorAction SilentlyContinue
    if ($conn) {
        $portsInUse += $port
    }
}

if ($portsInUse.Count -gt 0) {
    Write-Check "Ports in use: $($portsInUse -join ', ')" "INFO"
} else {
    Write-Check "No standard ports in use (services not running)" "WARN"
}

# 7. Documentation Files Check
Write-Host "`n7. Documentation Files" -ForegroundColor Yellow
$docs = @{
    'README.md' = (Test-Path 'README.md')
    'AGENTS.md' = (Test-Path 'AGENTS.md')
    'docs/api.md' = (Test-Path 'docs/api.md')
}

foreach ($doc in $docs.Keys) {
    if ($docs[$doc]) {
        Write-Check "$doc exists" "PASS"
    } else {
        Write-Check "$doc missing" "FAIL"
    }
}

# 8. Schema Consistency Check (Basic)
Write-Host "`n8. Schema Consistency (Basic Check)" -ForegroundColor Yellow
$migrations = Get-ChildItem db/migrations/*.sql -ErrorAction SilentlyContinue
$sharedTypes = Test-Path shared/src/types.ts

if ($migrations -and $sharedTypes) {
    Write-Check "Database migrations and shared types exist" "PASS"
    
    # Count tables in migrations
    $migrationContent = Get-Content db/migrations/*.sql -Raw -ErrorAction SilentlyContinue
    $tableCount = ([regex]::Matches($migrationContent, "CREATE TABLE")).Count
    Write-Host "   Tables defined: $tableCount" -ForegroundColor Gray
} else {
    Write-Check "Schema files incomplete" "WARN"
}

# Summary
Write-Host "`n╔════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║            Review Summary             ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════╝`n" -ForegroundColor Cyan

if ($script:FailCount -eq 0) {
    Write-Host "✅ All checks passed! Ready for next phase.`n" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⚠️  $script:FailCount check(s) failed. Review issues before proceeding.`n" -ForegroundColor Yellow
    exit 1
}
