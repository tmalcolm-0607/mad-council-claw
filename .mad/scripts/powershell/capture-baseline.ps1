<#
.SYNOPSIS
    Capture baseline file hashes for staleness detection.

.DESCRIPTION
    Creates a hash manifest (hash-manifest.json) in the work item directory by computing
    git hash-object hashes for tracked files. This baseline is used by staleness detection
    to identify files that have changed since the baseline was captured.

.PARAMETER WorkItem
    Required. The work item ID (e.g., "WI-20260121-1430-unified-kit").
    The manifest will be stored at .claude/work-items/<WorkItem>/hash-manifest.json

.PARAMETER IncludePatterns
    Optional. Array of glob patterns for files to track.
    Default: @("src/**/*", ".claude/**/*.md")

.PARAMETER ExcludePatterns
    Optional. Array of glob patterns to exclude from tracking.
    Default: @("**/*.test.*", "**/node_modules/**", "**/.git/**")

.PARAMETER BasePath
    Optional. Repository root path. Defaults to current directory.

.EXAMPLE
    .\capture-baseline.ps1 -WorkItem "WI-20260121-1430-unified-kit"

    Captures baseline with default patterns.

.EXAMPLE
    .\capture-baseline.ps1 -WorkItem "WI-20260121-1430-feature" -IncludePatterns @("src/**/*.ts", "lib/**/*.ts")

    Captures baseline for specific file patterns.

.NOTES
    Schema: .claude/schemas/hash-manifest.md
    Output: .claude/work-items/<WorkItem>/hash-manifest.json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, HelpMessage = "Work item ID")]
    [string]$WorkItem,

    [Parameter(Mandatory = $false, HelpMessage = "Glob patterns for files to track")]
    [string[]]$IncludePatterns = @("src/**/*", ".claude/**/*.md"),

    [Parameter(Mandatory = $false, HelpMessage = "Glob patterns to exclude from tracking")]
    [string[]]$ExcludePatterns = @("**/*.test.*", "**/node_modules/**", "**/.git/**"),

    [Parameter(Mandatory = $false, HelpMessage = "Repository root path")]
    [string]$BasePath = (Get-Location).Path
)

# Ensure we're in a git repository
function Test-GitRepository {
    param([string]$Path)
    try {
        $gitDir = git -C $Path rev-parse --git-dir 2>$null
        return $null -ne $gitDir
    }
    catch {
        return $false
    }
}

# Get current git commit hash
function Get-GitCommitHash {
    param([string]$Path)
    try {
        $hash = git -C $Path rev-parse HEAD 2>$null
        if ($hash -match "^[a-f0-9]{40}$") {
            return $hash
        }
        return $null
    }
    catch {
        return $null
    }
}

# Compute git hash-object for a file
function Get-GitHashObject {
    param(
        [string]$FilePath,
        [string]$RepoPath
    )
    try {
        $hash = git -C $RepoPath hash-object $FilePath 2>$null
        if ($hash -match "^[a-f0-9]{40}$") {
            return $hash
        }
        return $null
    }
    catch {
        Write-Warning "Failed to hash file: $FilePath"
        return $null
    }
}

# Convert glob pattern to regex
function Convert-GlobToRegex {
    param([string]$Pattern)

    $regex = $Pattern
    # Escape regex special characters except * and ?
    $regex = $regex -replace '\.', '\.'
    $regex = $regex -replace '\^', '\^'
    $regex = $regex -replace '\$', '\$'
    $regex = $regex -replace '\+', '\+'
    $regex = $regex -replace '\(', '\('
    $regex = $regex -replace '\)', '\)'
    $regex = $regex -replace '\[', '\['
    $regex = $regex -replace '\]', '\]'
    $regex = $regex -replace '\{', '\{'
    $regex = $regex -replace '\}', '\}'
    $regex = $regex -replace '\|', '\|'

    # Convert glob patterns to regex
    $regex = $regex -replace '\*\*/', '.*'  # **/ matches any directory depth
    $regex = $regex -replace '\*\*', '.*'   # ** matches anything
    $regex = $regex -replace '\*', '[^/]*'  # * matches anything except /
    $regex = $regex -replace '\?', '.'      # ? matches single character

    return "^$regex$"
}

# Check if file matches any pattern in the list
function Test-FileMatchesPatterns {
    param(
        [string]$RelativePath,
        [string[]]$Patterns
    )

    # Normalize path separators to forward slashes
    $normalizedPath = $RelativePath -replace '\\', '/'

    foreach ($pattern in $Patterns) {
        $regex = Convert-GlobToRegex -Pattern $pattern
        if ($normalizedPath -match $regex) {
            return $true
        }
    }
    return $false
}

# Get all tracked files based on include/exclude patterns
function Get-TrackedFiles {
    param(
        [string]$BasePath,
        [string[]]$IncludePatterns,
        [string[]]$ExcludePatterns
    )

    $trackedFiles = @()

    # Get all files recursively
    $allFiles = Get-ChildItem -Path $BasePath -Recurse -File -ErrorAction SilentlyContinue

    foreach ($file in $allFiles) {
        # Get relative path from base
        $relativePath = $file.FullName.Substring($BasePath.Length + 1)
        $relativePath = $relativePath -replace '\\', '/'

        # Check if file matches include patterns
        $included = Test-FileMatchesPatterns -RelativePath $relativePath -Patterns $IncludePatterns

        if ($included) {
            # Check if file matches exclude patterns
            $excluded = Test-FileMatchesPatterns -RelativePath $relativePath -Patterns $ExcludePatterns

            if (-not $excluded) {
                $trackedFiles += @{
                    FullPath = $file.FullName
                    RelativePath = $relativePath
                    Size = $file.Length
                }
            }
        }
    }

    return $trackedFiles
}

# Main execution
function Main {
    Write-Host "=== Baseline Capture for Staleness Detection ===" -ForegroundColor Cyan
    Write-Host "Work Item: $WorkItem" -ForegroundColor White
    Write-Host "Base Path: $BasePath" -ForegroundColor White
    Write-Host ""

    # Validate base path exists
    if (-not (Test-Path $BasePath)) {
        Write-Error "Base path does not exist: $BasePath"
        exit 1
    }

    # Validate git repository
    $isGitRepo = Test-GitRepository -Path $BasePath
    if (-not $isGitRepo) {
        Write-Warning "Not a git repository. Using timestamp-based fallback for hashing."
    }

    # Create work item directory if it doesn't exist
    $workItemDir = Join-Path $BasePath ".claude/work-items/$WorkItem"
    if (-not (Test-Path $workItemDir)) {
        Write-Host "Creating work item directory: $workItemDir" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $workItemDir -Force | Out-Null
    }

    # Get current git commit if available
    $gitCommit = $null
    if ($isGitRepo) {
        $gitCommit = Get-GitCommitHash -Path $BasePath
        if ($gitCommit) {
            Write-Host "Git commit: $gitCommit" -ForegroundColor Gray
        }
    }

    # Get tracked files
    Write-Host ""
    Write-Host "Scanning files with patterns:" -ForegroundColor Cyan
    Write-Host "  Include: $($IncludePatterns -join ', ')" -ForegroundColor Gray
    Write-Host "  Exclude: $($ExcludePatterns -join ', ')" -ForegroundColor Gray
    Write-Host ""

    $trackedFiles = Get-TrackedFiles -BasePath $BasePath -IncludePatterns $IncludePatterns -ExcludePatterns $ExcludePatterns

    if ($trackedFiles.Count -eq 0) {
        Write-Warning "No files matched the include patterns."
        Write-Host "Creating empty manifest."
    }
    else {
        Write-Host "Found $($trackedFiles.Count) files to track." -ForegroundColor Green
    }

    # Build file hash array
    $fileHashes = @()
    $skippedCount = 0

    foreach ($file in $trackedFiles) {
        $hash = $null

        if ($isGitRepo) {
            $hash = Get-GitHashObject -FilePath $file.FullPath -RepoPath $BasePath
        }

        if ($null -eq $hash) {
            # Fallback: use file content hash via PowerShell
            try {
                $hash = (Get-FileHash -Path $file.FullPath -Algorithm SHA1).Hash.ToLower()
            }
            catch {
                Write-Warning "Skipping unreadable file: $($file.RelativePath)"
                $skippedCount++
                continue
            }
        }

        $fileHashes += @{
            path = $file.RelativePath
            hash = $hash
            size = $file.Size
        }
    }

    if ($skippedCount -gt 0) {
        Write-Warning "Skipped $skippedCount unreadable files."
    }

    # Build manifest object
    $manifest = [ordered]@{
        work_item_id = $WorkItem
        captured_at = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        include_patterns = $IncludePatterns
        exclude_patterns = $ExcludePatterns
        files = $fileHashes
    }

    # Add git commit if available
    if ($gitCommit) {
        $manifest.git_commit = $gitCommit
    }

    # Write manifest to file
    $manifestPath = Join-Path $workItemDir "hash-manifest.json"
    $manifestJson = $manifest | ConvertTo-Json -Depth 10

    try {
        $manifestJson | Out-File -FilePath $manifestPath -Encoding utf8 -Force
        Write-Host ""
        Write-Host "=== Baseline Captured ===" -ForegroundColor Green
        Write-Host "Manifest: $manifestPath" -ForegroundColor White
        Write-Host "Files tracked: $($fileHashes.Count)" -ForegroundColor White
        Write-Host "Captured at: $($manifest.captured_at)" -ForegroundColor White
    }
    catch {
        Write-Error "Failed to write manifest: $_"
        exit 1
    }

    # Return manifest path for pipeline usage
    return $manifestPath
}

# Execute main function
Main
