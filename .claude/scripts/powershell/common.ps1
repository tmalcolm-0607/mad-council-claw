#!/usr/bin/env pwsh
# Common PowerShell functions analogous to common.sh

function Get-RepoRoot {
    try {
        $result = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $result
        }
    } catch {
        # Git command failed
    }
    
    # Fall back to script location for non-git repos
    return (Resolve-Path (Join-Path $PSScriptRoot "../../..")).Path
}

function Get-CurrentBranch {
    # First check if SPECIFY_FEATURE environment variable is set
    if ($env:SPECIFY_FEATURE) {
        return $env:SPECIFY_FEATURE
    }
    
    # Then check git if available
    try {
        $result = git rev-parse --abbrev-ref HEAD 2>$null
        if ($LASTEXITCODE -eq 0) {
            return $result
        }
    } catch {
        # Git command failed
    }
    
    # For non-git repos, try to find the latest feature directory
    $repoRoot = Get-RepoRoot
    $specsDir = Join-Path $repoRoot "specs"
    
    if (Test-Path $specsDir) {
        $latestFeature = ""
        $highest = 0
        
        Get-ChildItem -Path $specsDir -Directory | ForEach-Object {
            if ($_.Name -match '^(\d{3})-') {
                $num = [int]$matches[1]
                if ($num -gt $highest) {
                    $highest = $num
                    $latestFeature = $_.Name
                }
            }
        }
        
        if ($latestFeature) {
            return $latestFeature
        }
    }
    
    # Final fallback
    return "main"
}

function Test-HasGit {
    try {
        git rev-parse --show-toplevel 2>$null | Out-Null
        return ($LASTEXITCODE -eq 0)
    } catch {
        return $false
    }
}

function Test-FeatureBranch {
    param(
        [string]$Branch,
        [bool]$HasGit = $true
    )

    # For non-git repos, we can't enforce branch naming but still provide output
    if (-not $HasGit) {
        Write-Warning "[specify] Git repository not detected; skipped branch validation"
        return $true
    }

    # Accept:
    #   feature/*, bugfix/*, hotfix/* — classic convention
    #   users/<alias>/*             — Azure DevOps convention for personal branches
    # Diagnostic messages use Write-Warning so they go to the warning stream and
    # do NOT pollute the pipeline return value (historical bug: Write-Output here
    # caused callers to receive an array mixed with $true/$false, silently passing validation).
    if ($Branch -notmatch '^(feature|bugfix|hotfix)/' -and $Branch -notmatch '^users/[^/]+/.+') {
        Write-Warning "[specify] Branch '$Branch' does not match feature|bugfix|hotfix/* or users/<alias>/* convention"
        Write-Warning "[specify] Feature branches should be named like: feature/feature-name or users/<alias>/feature-name"
        return $false
    }
    return $true
}

function Get-FeatureDir {
    param(
        [string]$RepoRoot,
        [string]$Branch,
        [string]$PreferredSlug   # Optional — from $env:SPECIFY_FEATURE if set
    )

    # Resolution order (stop at first match):
    #   1. If $env:SPECIFY_FEATURE (or -PreferredSlug) names an existing specs/NNN-<slug>/ dir, use it.
    #   2. If the branch strips cleanly via classic prefixes AND specs/<stripped>/ exists, use it.
    #   3. If the branch is user-alias style (users/<alias>/<name>) AND exactly ONE specs/NNN-*/ exists
    #      whose slug is embedded in the branch name, use that one.
    #   4. If exactly ONE specs/NNN-*/ exists, use it (ambiguous but only one candidate).
    #   5. Fall back to the branch-derived path (legacy behavior).
    $specsDir = Join-Path $RepoRoot 'specs'

    $preferred = if ($PreferredSlug) { $PreferredSlug } elseif ($env:SPECIFY_FEATURE) { $env:SPECIFY_FEATURE } else { $null }
    if ($preferred) {
        $preferredDir = Join-Path $specsDir $preferred
        if (Test-Path $preferredDir -PathType Container) {
            return $preferredDir
        }
    }

    $classic = $Branch -replace '^(feature|bugfix|hotfix)/', ''
    if ($classic -ne $Branch) {
        $classicDir = Join-Path $specsDir $classic
        if (Test-Path $classicDir -PathType Container) { return $classicDir }
    }

    if (Test-Path $specsDir -PathType Container) {
        $numberedDirs = @(Get-ChildItem -Path $specsDir -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match '^\d{3}-' })

        if ($numberedDirs.Count -gt 0) {
            if ($Branch -match '^users/[^/]+/.+') {
                $tail = ($Branch -replace '^users/[^/]+/', '').ToLowerInvariant()
                $matchByTail = $numberedDirs | Where-Object {
                    $slug = ($_.Name -replace '^\d{3}-', '').ToLowerInvariant()
                    $tail.Contains($slug) -or $slug.Contains($tail)
                }
                if ($matchByTail.Count -eq 1) { return $matchByTail[0].FullName }
            }
            if ($numberedDirs.Count -eq 1) {
                return $numberedDirs[0].FullName
            }
        }
    }

    # Legacy fallback — may produce 'specs/users/alice/branch' etc.; caller should flag.
    $dirName = $classic
    Join-Path $RepoRoot "specs/$dirName"
}

function Get-FeaturePathsEnv {
    param(
        [string]$FeatureDir  # Optional: explicit feature directory path (bypasses branch detection)
    )

    $repoRoot = Get-RepoRoot
    $hasGit = Test-HasGit

    if ($FeatureDir) {
        # Explicit path provided — resolve to absolute and skip branch detection
        $resolvedDir = if ([System.IO.Path]::IsPathRooted($FeatureDir)) { $FeatureDir } else { Join-Path $repoRoot $FeatureDir }
        $currentBranch = '(explicit-path)'
        $featureDir = $resolvedDir
    } else {
        $currentBranch = Get-CurrentBranch
        $featureDir = Get-FeatureDir -RepoRoot $repoRoot -Branch $currentBranch
    }

    [PSCustomObject]@{
        REPO_ROOT     = $repoRoot
        CURRENT_BRANCH = $currentBranch
        HAS_GIT       = $hasGit
        FEATURE_DIR   = $featureDir
        FEATURE_SPEC  = Join-Path $featureDir 'spec.md'
        IMPL_PLAN     = Join-Path $featureDir 'plan.md'
        TASKS         = Join-Path $featureDir 'tasks.md'
        RESEARCH      = Join-Path $featureDir 'research.md'
        DATA_MODEL    = Join-Path $featureDir 'data-model.md'
        QUICKSTART    = Join-Path $featureDir 'quickstart.md'
        CONTRACTS_DIR = Join-Path $featureDir 'contracts'
    }
}

function Test-FileExists {
    param([string]$Path, [string]$Description)
    if (Test-Path -Path $Path -PathType Leaf) {
        Write-Output "  ✓ $Description"
        return $true
    } else {
        Write-Output "  ✗ $Description"
        return $false
    }
}

function Test-DirHasFiles {
    param([string]$Path, [string]$Description)
    if ((Test-Path -Path $Path -PathType Container) -and (Get-ChildItem -Path $Path -ErrorAction SilentlyContinue | Where-Object { -not $_.PSIsContainer } | Select-Object -First 1)) {
        Write-Output "  ✓ $Description"
        return $true
    } else {
        Write-Output "  ✗ $Description"
        return $false
    }
}

