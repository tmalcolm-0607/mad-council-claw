<#
.SYNOPSIS
    Updates reference repositories from Azure DevOps.

.DESCRIPTION
    This script manages the reference repositories in the references directory.
    It can clone repos that don't exist, convert downloaded archives to proper git repos,
    and pull latest changes for existing repos.

.PARAMETER ReferencesPath
    Path to the references directory. Defaults to ../references relative to script location.

.PARAMETER Force
    If specified, will re-clone repos even if they already exist as git repos.

.PARAMETER CleanNames
    If specified, renames directories with "(1)" suffix to clean names.
    For example: "LENS-DCS (1)" -> "LENS-DCS"

.PARAMETER DryRun
    If specified, shows what would be done without making changes.

.EXAMPLE
    .\Update-ReferenceRepos.ps1

.EXAMPLE
    .\Update-ReferenceRepos.ps1 -DryRun

.EXAMPLE
    .\Update-ReferenceRepos.ps1 -CleanNames

.EXAMPLE
    .\Update-ReferenceRepos.ps1 -Force
#>

[CmdletBinding()]
param(
    [string]$ReferencesPath,
    [switch]$Force,
    [switch]$CleanNames,
    [switch]$DryRun
)

# Handle default path - $PSScriptRoot may be empty when run via -File
if (-not $ReferencesPath) {
    if ($PSScriptRoot) {
        $ReferencesPath = Join-Path $PSScriptRoot "..\references"
    } else {
        # Fallback: assume script is in scripts/ under repo root
        $ReferencesPath = "C:\source\CCGHCP\references"
    }
}

# Use Continue (not Stop) because git writes progress to stderr,
# and Stop would treat that as a terminating error.
# Check $LASTEXITCODE after git commands instead.
$ErrorActionPreference = "Continue"

# Azure DevOps organization and project
$AzureDevOpsOrg = "https://o365exchange.visualstudio.com"
$AzureDevOpsProject = "O365%20Core"

# Repository mapping: local directory name -> Azure DevOps repo name
# Handles directories with "(1)" suffix from duplicate downloads
$RepoMapping = @{
    "LENS-CMS"          = "LENS-CMS"
    "LENS-DCS (1)"      = "LENS-DCS"
    "LENS-DCS"          = "LENS-DCS"
    "LENS-Delivery"     = "LENS-Delivery"
    "LENS-Docs (1)"     = "LENS-Docs"
    "LENS-Docs"         = "LENS-Docs"
    "LensExchange"      = "LensExchange"
    "LENS-LEAPI"        = "LENS-LEAPI"
    "LENS-LEPortal (1)" = "LENS-LEPortal"
    "LENS-LEPortal"     = "LENS-LEPortal"
    "LENS-LRMS (1)"     = "LENS-LRMS"
    "LENS-LRMS"         = "LENS-LRMS"
    "LENS-Publish"      = "LENS-Publish"
    "LENS-SMS"          = "LENS-SMS"
    "LENS-Teams"        = "LENS-Teams"
    "LENS-*"              = "LENS-*"
    "MDEP"                = "MDEP"
}

function Get-RepoUrl {
    param([string]$RepoName)
    return "$AzureDevOpsOrg/$AzureDevOpsProject/_git/$RepoName"
}

function Test-GitRepo {
    param([string]$Path)
    return Test-Path (Join-Path $Path ".git")
}

function Write-Status {
    param(
        [string]$Message,
        [ValidateSet("Info", "Success", "Warning", "Error")]
        [string]$Type = "Info"
    )

    $color = switch ($Type) {
        "Info"    { "Cyan" }
        "Success" { "Green" }
        "Warning" { "Yellow" }
        "Error"   { "Red" }
    }

    $prefix = switch ($Type) {
        "Info"    { "[*]" }
        "Success" { "[+]" }
        "Warning" { "[!]" }
        "Error"   { "[-]" }
    }

    Write-Host "$prefix $Message" -ForegroundColor $color
}

function Update-Repository {
    param(
        [string]$LocalPath,
        [string]$RepoName,
        [string]$RepoUrl
    )

    $dirName = Split-Path $LocalPath -Leaf

    if (Test-GitRepo $LocalPath) {
        # Already a git repo - just pull
        Write-Status "Updating $dirName (git pull)..." -Type Info

        if (-not $DryRun) {
            Push-Location $LocalPath
            try {
                # Fetch and show status
                git fetch origin 2>&1 | Out-Null
                $status = git status -sb 2>&1

                # Check if behind
                if ($status -match "behind") {
                    git pull --ff-only 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        Write-Status "$dirName updated successfully" -Type Success
                    } else {
                        Write-Status "$dirName pull failed - may need manual merge" -Type Warning
                    }
                } else {
                    Write-Status "$dirName already up to date" -Type Success
                }
            }
            finally {
                Pop-Location
            }
        } else {
            Write-Status "[DRY-RUN] Would pull latest for $dirName" -Type Info
        }
    }
    elseif (Test-Path $LocalPath) {
        # Directory exists but not a git repo - need to convert
        Write-Status "$dirName exists but is not a git repo - converting..." -Type Warning

        if (-not $DryRun) {
            $backupPath = "$LocalPath.backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
            $tempClonePath = "$LocalPath.temp-clone"

            # Clone to temp location - use cmd to avoid PowerShell's stderr handling
            Write-Status "Cloning $RepoName to temp location..." -Type Info

            # Run git clone via cmd to avoid PowerShell stderr issues
            $null = cmd /c "git clone `"$RepoUrl`" `"$tempClonePath`" 2>&1"

            # Check if clone succeeded by verifying .git directory exists
            if (-not (Test-Path (Join-Path $tempClonePath ".git"))) {
                Write-Status "Clone failed for $RepoName - no .git directory created" -Type Error
                # Cleanup temp if exists
                if (Test-Path $tempClonePath) {
                    Remove-Item $tempClonePath -Recurse -Force
                }
            }
            else {
                try {
                    # Backup existing
                    Write-Status "Backing up existing directory to $backupPath" -Type Info
                    Move-Item $LocalPath $backupPath

                    # Move cloned repo to final location
                    Move-Item $tempClonePath $LocalPath

                    Write-Status "$dirName converted to git repo successfully" -Type Success
                    Write-Status "Backup saved at: $backupPath" -Type Info
                }
                catch {
                    Write-Status "Failed to convert $dirName`: $_" -Type Error
                    # Cleanup temp if exists
                    if (Test-Path $tempClonePath) {
                        Remove-Item $tempClonePath -Recurse -Force
                    }
                }
            }
        } else {
            Write-Status "[DRY-RUN] Would backup $dirName and clone fresh from $RepoUrl" -Type Info
        }
    }
    else {
        # Directory doesn't exist - clone fresh
        Write-Status "Cloning $RepoName..." -Type Info

        if (-not $DryRun) {
            git clone $RepoUrl $LocalPath 2>&1

            if ($LASTEXITCODE -eq 0) {
                Write-Status "$dirName cloned successfully" -Type Success
            } else {
                Write-Status "Failed to clone $RepoName" -Type Error
            }
        } else {
            Write-Status "[DRY-RUN] Would clone $RepoUrl to $LocalPath" -Type Info
        }
    }
}

# Main execution
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Azure DevOps Reference Repo Updater  " -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

if ($DryRun) {
    Write-Status "DRY RUN MODE - No changes will be made" -Type Warning
    Write-Host ""
}

$ReferencesPath = Resolve-Path $ReferencesPath -ErrorAction SilentlyContinue
if (-not $ReferencesPath) {
    Write-Status "References path not found: $ReferencesPath" -Type Error
    exit 1
}

Write-Status "References path: $ReferencesPath" -Type Info
Write-Host ""

# Get existing directories
$existingDirs = Get-ChildItem -Path $ReferencesPath -Directory |
    Where-Object { $_.Name -ne ".claude" } |
    Select-Object -ExpandProperty Name

# Process each mapped repo
$processed = @{}
foreach ($dir in $existingDirs) {
    if ($RepoMapping.ContainsKey($dir)) {
        $repoName = $RepoMapping[$dir]
        $repoUrl = Get-RepoUrl $repoName
        $localPath = Join-Path $ReferencesPath $dir

        # Skip if we already processed this repo (handles duplicates)
        if ($processed.ContainsKey($repoName)) {
            Write-Status "Skipping $dir (duplicate of $repoName, already processed)" -Type Warning
            continue
        }

        Update-Repository -LocalPath $localPath -RepoName $repoName -RepoUrl $repoUrl
        $processed[$repoName] = $dir
        Write-Host ""
    } else {
        Write-Status "Unknown repo: $dir (not in mapping)" -Type Warning
    }
}

# Clean up directory names if requested
if ($CleanNames) {
    Write-Host ""
    Write-Status "Cleaning directory names (removing '(1)' suffixes)..." -Type Info
    Write-Host ""

    $dirsToRename = Get-ChildItem -Path $ReferencesPath -Directory |
        Where-Object { $_.Name -match '\s*\(1\)$' }

    foreach ($dir in $dirsToRename) {
        $cleanName = $dir.Name -replace '\s*\(1\)$', ''
        $cleanPath = Join-Path $ReferencesPath $cleanName
        $currentPath = $dir.FullName

        if (Test-Path $cleanPath) {
            Write-Status "Cannot rename $($dir.Name) - $cleanName already exists" -Type Warning
        } else {
            if (-not $DryRun) {
                try {
                    Rename-Item -Path $currentPath -NewName $cleanName
                    Write-Status "Renamed: $($dir.Name) -> $cleanName" -Type Success
                }
                catch {
                    Write-Status "Failed to rename $($dir.Name): $_" -Type Error
                }
            } else {
                Write-Status "[DRY-RUN] Would rename: $($dir.Name) -> $cleanName" -Type Info
            }
        }
    }
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Status "Processed $($processed.Count) repositories" -Type Info

if ($DryRun) {
    Write-Host ""
    Write-Status "Run without -DryRun to apply changes" -Type Info
}
