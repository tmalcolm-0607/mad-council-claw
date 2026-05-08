#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Audit-AllLensRepos.ps1 - Exhaustively enumerate every references/LENS-*
    and references/Lens-* repo with per-repo metadata.

.DESCRIPTION
    Auto-detector for "user had to flag missing inventory items". The
    iter-41 LENS audit initially listed 5 services and skipped 8 variant
    branches + Lens-Common library + LENS-Docs without explanation. User
    flagged: "your report doesn't have all /lens-* services :(". This
    script enumerates every matching directory exhaustively — no Top-N,
    no silent skips.

    For each repo:
      - Branch (current HEAD)
      - Last commit SHA + date
      - Build status (csproj count, last successful local build if any)
      - Whether each of the 4 LENS gate skills applies
        (lens-aspnet-structure, lens-pipeline-audit, lens-telemetry,
         lens-standards-audit)
      - Variant indicator (vs origin/master)
      - Repo type (service / library / docs / variant-branch)

    Output: .mad/reports/lens-inventory-{ts}.md

.PARAMETER ReferencesRoot
    Path to references/ root (default: <RepoRoot>/references)

.PARAMETER OutputDir
    Where to write the inventory report (default: <RepoRoot>/.mad/reports)

.PARAMETER IncludeBuildStatus
    Run dotnet build per repo. Slow (~30s/repo). Default off.

.EXAMPLE
    .\Audit-AllLensRepos.ps1
#>

[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$ReferencesRoot,
    [string]$OutputDir,
    [switch]$IncludeBuildStatus
)

if (-not $RepoRoot) {
    $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } elseif ($MyInvocation.MyCommand.Path) { Split-Path -Parent $MyInvocation.MyCommand.Path } else { $PWD.Path }
    $RepoRoot = (Resolve-Path (Join-Path $scriptDir '..\..')).Path
}

$ErrorActionPreference = 'Continue'

if (-not $ReferencesRoot) {
    $ReferencesRoot = Join-Path $RepoRoot 'references'
}
if (-not $OutputDir) {
    $OutputDir = Join-Path $RepoRoot '.mad/reports'
}
New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

if (-not (Test-Path $ReferencesRoot)) {
    Write-Warning "references/ directory not found at $ReferencesRoot"
    exit 0
}

Write-Host "Scanning $ReferencesRoot for LENS-* and Lens-* repos..."

# Enumerate ALL matching directories — no Top-N filter
$repos = Get-ChildItem -Path $ReferencesRoot -Directory -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^(LENS-|Lens-)' } |
    Sort-Object Name

if ($repos.Count -eq 0) {
    Write-Warning "No LENS-* or Lens-* repos found under $ReferencesRoot"
    exit 0
}

Write-Host "Found $($repos.Count) candidate repo(s). Auditing each..."

$inventory = @()

foreach ($repo in $repos) {
    Write-Host "  Auditing: $($repo.Name)"

    $entry = [ordered]@{
        name = $repo.Name
        full_path = $repo.FullName
        is_git_repo = (Test-Path (Join-Path $repo.FullName '.git'))
        branch = $null
        head_sha = $null
        head_date = $null
        ahead_of_master = $null
        behind_master = $null
        files_diff_vs_master = $null
        csproj_count = 0
        sln_count = 0
        type = 'unknown'
        gate_skills_applicable = @()
        notes = @()
    }

    # Git metadata
    if ($entry.is_git_repo) {
        try {
            $entry.branch = (& git -C $repo.FullName rev-parse --abbrev-ref HEAD 2>$null).Trim()
            $entry.head_sha = (& git -C $repo.FullName rev-parse --short HEAD 2>$null).Trim()
            $entry.head_date = (& git -C $repo.FullName log -1 --format=%ci HEAD 2>$null).Trim()

            # Compare against origin/master (if exists)
            $originMaster = (& git -C $repo.FullName rev-parse --verify origin/master 2>$null)
            if ($LASTEXITCODE -eq 0 -and $originMaster) {
                $aheadBehind = (& git -C $repo.FullName rev-list --left-right --count origin/master...HEAD 2>$null).Trim()
                if ($aheadBehind -match '^(\d+)\s+(\d+)$') {
                    $entry.behind_master = [int]$matches[1]
                    $entry.ahead_of_master = [int]$matches[2]
                }
                $diffStat = (& git -C $repo.FullName diff origin/master --shortstat 2>$null).Trim()
                if ($diffStat -match '(\d+)\s+files?\s+changed') {
                    $entry.files_diff_vs_master = [int]$matches[1]
                }
            }
        } catch {
            $entry.notes += "git metadata extraction error: $_"
        }
    }

    # File structure
    $csprojFiles = @(Get-ChildItem -Path $repo.FullName -Recurse -Filter '*.csproj' -ErrorAction SilentlyContinue)
    $slnFiles = @(Get-ChildItem -Path $repo.FullName -Recurse -Filter '*.sln' -ErrorAction SilentlyContinue)
    $entry.csproj_count = $csprojFiles.Count
    $entry.sln_count = $slnFiles.Count

    # Type heuristic
    if ($repo.Name -match '-pr\d+|-fix$|-merge$|-pj$|-publishjobid$|-geneva') {
        $entry.type = 'variant-branch'
    } elseif ($entry.csproj_count -eq 0) {
        $entry.type = 'docs-or-non-dotnet'
    } elseif ($repo.Name -eq 'Lens-Common' -or $repo.Name -match '^LENS-Common($|-)') {
        $entry.type = 'shared-library'
    } else {
        $entry.type = 'service'
    }

    # Gate skill applicability
    if ($entry.type -eq 'service') {
        $entry.gate_skills_applicable = @(
            'lens-aspnet-structure',
            'lens-pipeline-audit',
            'lens-telemetry',
            'lens-standards-audit'
        )
    } elseif ($entry.type -eq 'shared-library') {
        $entry.gate_skills_applicable = @('lens-standards-audit')
        $entry.notes += 'lens-aspnet-structure not directly applicable (library); only Standard 5 (Common layer) checks apply'
    } elseif ($entry.type -eq 'variant-branch') {
        $entry.gate_skills_applicable = @(
            'lens-aspnet-structure',
            'lens-pipeline-audit',
            'lens-telemetry',
            'lens-standards-audit'
        )
        $entry.notes += "variant of parent service; scores typically track parent ±1-2pts unless architectural restructure"
    } elseif ($entry.type -eq 'docs-or-non-dotnet') {
        $entry.gate_skills_applicable = @()
        $entry.notes += 'no .csproj files; service-shaped gate skills not applicable'
    }

    # Optional: actual build status
    if ($IncludeBuildStatus -and $entry.csproj_count -gt 0) {
        Write-Host "    Running dotnet build (slow)..."
        try {
            $buildOut = & dotnet build $repo.FullName --no-restore --nologo 2>&1
            $entry.build_succeeded = ($LASTEXITCODE -eq 0)
            $entry.build_summary = ($buildOut | Select-Object -Last 5) -join "`n"
        } catch {
            $entry.build_succeeded = $false
            $entry.build_summary = "build invocation error: $_"
        }
    }

    $inventory += $entry
}

# Write report
$ts = (Get-Date).ToString('yyyy-MM-dd-HHmmss')
$reportPath = Join-Path $OutputDir "lens-inventory-$ts.md"

$lines = @()
$lines += "# LENS-* Repository Inventory"
$lines += ""
$lines += "**Generated:** $((Get-Date).ToString('o'))"
$lines += "**Source:** ``$ReferencesRoot``"
$lines += "**Scan policy:** EXHAUSTIVE — no Top-N capping; every matching directory enumerated."
$lines += ""
$lines += "## Summary"
$lines += ""
$lines += "Total repos: **$($inventory.Count)**"
$lines += ""

$byType = $inventory | Group-Object -Property type | Sort-Object Name
$lines += "| Type | Count |"
$lines += "|---|---:|"
foreach ($g in $byType) {
    $lines += "| $($g.Name) | $($g.Count) |"
}
$lines += ""

$lines += "## Per-Repo Detail"
$lines += ""
$lines += "| Repo | Type | Branch | HEAD | Diff vs master | csproj | Gate skills |"
$lines += "|---|---|---|---|---:|---:|---|"
foreach ($r in $inventory) {
    $diffSummary = if ($null -ne $r.files_diff_vs_master) { "$($r.files_diff_vs_master) files" } else { 'n/a' }
    $branch = if ($r.branch) { $r.branch } else { 'n/a' }
    $head = if ($r.head_sha) { $r.head_sha } else { 'n/a' }
    $gates = ($r.gate_skills_applicable -join ', ')
    if (-not $gates) { $gates = '(none — not applicable)' }
    $lines += "| **$($r.name)** | $($r.type) | $branch | ``$head`` | $diffSummary | $($r.csproj_count) | $gates |"
}
$lines += ""

$lines += "## Notes per repo"
$lines += ""
foreach ($r in $inventory) {
    if ($r.notes.Count -gt 0) {
        $lines += "**$($r.name):**"
        foreach ($n in $r.notes) {
            $lines += "- $n"
        }
        $lines += ""
    }
}

if ($IncludeBuildStatus) {
    $lines += "## Build status"
    $lines += ""
    $lines += "| Repo | Build OK |"
    $lines += "|---|---|"
    foreach ($r in $inventory) {
        if ($null -ne $r.build_succeeded) {
            $lines += "| $($r.name) | $(if ($r.build_succeeded) { 'PASS' } else { 'FAIL' }) |"
        }
    }
    $lines += ""
}

$lines += "---"
$lines += ""
$lines += "**Generated by:** ``Audit-AllLensRepos.ps1`` — exhaustive enumeration policy per ``.claude/rules/no-top-n-capping.md``."

$lines | Set-Content -Path $reportPath -Encoding UTF8

Write-Host ""
Write-Host "Inventory written: $reportPath"
Write-Host "Total: $($inventory.Count) repos / $(($byType | ForEach-Object { "$($_.Count) $($_.Name)" }) -join ', ')"
exit 0
