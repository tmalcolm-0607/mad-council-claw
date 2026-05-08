#!/usr/bin/env pwsh
# Setup implementation plan for a feature

[CmdletBinding()]
param(
    [switch]$Json,
    [switch]$Help,
    [string]$FeatureDir,
    [switch]$SkipBranchCheck,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Show help if requested
if ($Help) {
    Write-Output "Usage: ./setup-plan.ps1 [-Json] [-FeatureDir <path>] [-SkipBranchCheck] [-Force] [-Help]"
    Write-Output "  -Json             Output results in JSON format"
    Write-Output "  -FeatureDir       Explicit path to the feature directory (bypasses branch-based detection)"
    Write-Output "  -SkipBranchCheck  Skip feature-branch-naming validation (use with caution)"
    Write-Output "  -Force            Overwrite an existing plan.md with the blank template. Default: skip copy if plan.md already exists."
    Write-Output "  -Help             Show this help message"
    exit 0
}

# Load common functions
. "$PSScriptRoot/common.ps1"

# Get all paths and variables from common functions (-FeatureDir wires through if provided)
$paths = if ($FeatureDir) { Get-FeaturePathsEnv -FeatureDir $FeatureDir } else { Get-FeaturePathsEnv }

# Check if we're on a proper feature branch (only for git repos; bypassed with -SkipBranchCheck or -FeatureDir)
if (-not $SkipBranchCheck -and -not $FeatureDir) {
    if (-not (Test-FeatureBranch -Branch $paths.CURRENT_BRANCH -HasGit $paths.HAS_GIT)) {
        exit 1
    }
}

# Ensure the feature directory exists
New-Item -ItemType Directory -Path $paths.FEATURE_DIR -Force | Out-Null

# Copy plan template only if target is absent OR -Force is set.
# Non-destructive by default: prior bug (GAP #23) clobbered filled-in plan.md when
# setup-plan.ps1 was re-invoked during verification or resume flows.
$template = Join-Path $paths.REPO_ROOT '.mad/templates/plan-template.md'
$planExists = Test-Path $paths.IMPL_PLAN -PathType Leaf
$planSkipped = $false
if ($planExists -and -not $Force) {
    $planSkipped = $true
    Write-Output "Plan already exists at $($paths.IMPL_PLAN); template copy SKIPPED (pass -Force to overwrite)."
} elseif (Test-Path $template) {
    if ($planExists) {
        # User explicitly passed -Force; back up the existing file before clobbering.
        $backup = "$($paths.IMPL_PLAN).bak"
        Copy-Item $paths.IMPL_PLAN $backup -Force
        Write-Output "Backed up existing plan to $backup"
    }
    Copy-Item $template $paths.IMPL_PLAN -Force
    Write-Output "Copied plan template to $($paths.IMPL_PLAN)"
} else {
    Write-Warning "Plan template not found at $template"
    if (-not $planExists) {
        New-Item -ItemType File -Path $paths.IMPL_PLAN -Force | Out-Null
    }
}

# Output results
if ($Json) {
    $result = [PSCustomObject]@{
        FEATURE_SPEC = $paths.FEATURE_SPEC
        IMPL_PLAN    = $paths.IMPL_PLAN
        SPECS_DIR    = $paths.FEATURE_DIR
        BRANCH       = $paths.CURRENT_BRANCH
        HAS_GIT      = $paths.HAS_GIT
        PLAN_SKIPPED = [bool]$planSkipped
    }
    $result | ConvertTo-Json -Compress
} else {
    Write-Output "FEATURE_SPEC: $($paths.FEATURE_SPEC)"
    Write-Output "IMPL_PLAN: $($paths.IMPL_PLAN)"
    Write-Output "SPECS_DIR: $($paths.FEATURE_DIR)"
    Write-Output "BRANCH: $($paths.CURRENT_BRANCH)"
    Write-Output "HAS_GIT: $($paths.HAS_GIT)"
    Write-Output "PLAN_SKIPPED: $planSkipped"
}
