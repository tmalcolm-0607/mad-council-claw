<#
.SYNOPSIS
    Work Item management script for MAD (Model-Assisted Development) workflow.

.DESCRIPTION
    Manages work items and artifacts for tracking MAD feature development.

    Commands:
      create <slug> [--spec-dir <path>] [--branch <name>]  Create a new work item and set ACTIVE
      set-active <WorkItemId>                               Set the active work item
      clear-active                                          Clear the ACTIVE pointer
      add-artifact <type> <path>                            Record an artifact in manifest
      route-artifact <type> <source-path>                   Move artifact into work item folder
      new-artifact <type> <name>                            Get path for new artifact file
      status                                                Show current work item status
      complete <summary>                                    Mark work item as completed

.EXAMPLE
    .\work-item.ps1 create user-auth --spec-dir specs/003-user-auth --branch 003-user-auth
    .\work-item.ps1 set-active WI-20260121-1430-user-auth
    .\work-item.ps1 add-artifact investigation "artifacts/investigation/auth-patterns.md"
    .\work-item.ps1 status
    .\work-item.ps1 complete "Implemented OAuth2 authentication"

.NOTES
    All timestamps are UTC. WorkItemId is generated using UTC time.
    Integrates with MAD workflow: /mad-spec, /mad-plan, /mad-implement, /mad-validate
#>

param(
    [Parameter(Position = 0, Mandatory = $true)]
    [ValidateSet('create', 'set-active', 'clear-active', 'add-artifact', 'route-artifact', 'new-artifact', 'status', 'complete')]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$Arg1,

    [Parameter(Position = 2)]
    [string]$Arg2,

    [string]$SpecDir,
    [string]$Branch,
    [string]$Worktree,
    [string]$Type = "feature"
)

# Configuration
$WorkItemsRoot = Join-Path $PSScriptRoot "..\work-items"
$ActiveFile = Join-Path $WorkItemsRoot "ACTIVE"
$TemplateDir = Join-Path $WorkItemsRoot "_TEMPLATE"
$ChangelogFile = Join-Path $WorkItemsRoot "CHANGELOG.md"

# Ensure work-items directory exists
if (-not (Test-Path $WorkItemsRoot)) {
    New-Item -ItemType Directory -Path $WorkItemsRoot -Force | Out-Null
}

function Get-UtcTimestamp {
    return (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
}

function Get-UtcDate {
    return (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Content
    )
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
}

function Get-WorkItemId {
    param([string]$Slug)
    $now = (Get-Date).ToUniversalTime()
    return "WI-{0:yyyyMMdd}-{0:HHmm}-{1}" -f $now, $Slug
}

function Get-ActiveWorkItemId {
    if (-not (Test-Path $ActiveFile)) {
        return $null
    }

    $content = Get-Content $ActiveFile -ErrorAction SilentlyContinue | Select-Object -First 1
    if ([string]::IsNullOrWhiteSpace($content)) {
        return $null
    }

    # Strip UTF-8 BOM if present
    $content = $content.TrimStart([char]0xFEFF)
    return $content.Trim()
}

function Get-ActiveManifestPath {
    $workItemId = Get-ActiveWorkItemId
    if (-not $workItemId) {
        return $null
    }

    return Join-Path $WorkItemsRoot "$workItemId\manifest.json"
}

function Get-Manifest {
    $manifestPath = Get-ActiveManifestPath
    if (-not $manifestPath -or -not (Test-Path $manifestPath)) {
        return $null
    }

    $content = Get-Content $manifestPath -Raw
    $content = $content.TrimStart([char]0xFEFF)
    return $content | ConvertFrom-Json
}

function Save-Manifest {
    param([PSObject]$Manifest)

    $manifestPath = Get-ActiveManifestPath
    if (-not $manifestPath) {
        Write-Error "No active work item set"
        return $false
    }

    $jsonContent = $Manifest | ConvertTo-Json -Depth 10
    Write-Utf8NoBom -Path $manifestPath -Content $jsonContent
    return $true
}

# Artifact type to subfolder mapping
$ArtifactFolderMapping = @{
    'investigation'         = 'artifacts/investigation'
    'implementation'        = 'artifacts/implementation'
    'review'                = 'artifacts/review'
    'verification'          = 'artifacts/verification'
    'research'              = 'artifacts/research'
    'unknown'               = 'artifacts/unknown'
}

function Get-ArtifactDestinationFolder {
    param([string]$ArtifactType)

    if ($ArtifactFolderMapping.ContainsKey($ArtifactType)) {
        return $ArtifactFolderMapping[$ArtifactType]
    }
    return 'artifacts/unknown'
}

function Invoke-Create {
    param(
        [string]$Slug,
        [string]$SpecDirectory,
        [string]$BranchName,
        [string]$WorktreePath,
        [string]$WorkType
    )

    if ([string]::IsNullOrWhiteSpace($Slug)) {
        Write-Error "Usage: work-item.ps1 create <slug> [--spec-dir <path>] [--branch <name>]"
        Write-Error "  <slug> should be lowercase, kebab-case (e.g., 'user-auth')"
        exit 1
    }

    # Validate slug format
    if ($Slug -notmatch '^[a-z0-9]+(-[a-z0-9]+)*$') {
        Write-Error "Invalid slug format. Use lowercase letters, numbers, and hyphens only."
        exit 1
    }

    # Generate IDs and paths
    $workItemId = Get-WorkItemId -Slug $Slug
    $workItemDir = Join-Path $WorkItemsRoot $workItemId
    $timestamp = Get-UtcTimestamp

    # Create work item directory with artifacts subfolders
    New-Item -ItemType Directory -Path $workItemDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $workItemDir "artifacts/investigation") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $workItemDir "artifacts/implementation") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $workItemDir "artifacts/review") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $workItemDir "artifacts/verification") -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $workItemDir "artifacts/research") -Force | Out-Null

    # Create manifest.json
    $manifest = @{
        id = $workItemId
        type = $WorkType
        status = "Active"
        created_utc = $timestamp
        title = ($Slug -replace '-', ' ')
        description = ""
        spec_directory = $SpecDirectory
        branch = $BranchName
        worktree = $WorktreePath
        verification_spec = $null
        artifacts = @()
        outcome = $null
    }

    $manifestPath = Join-Path $workItemDir "manifest.json"
    $jsonContent = $manifest | ConvertTo-Json -Depth 10
    Write-Utf8NoBom -Path $manifestPath -Content $jsonContent

    # Set as active
    Write-Utf8NoBom -Path $ActiveFile -Content $workItemId

    Write-Host "Created work item: $workItemId"
    Write-Host "  Directory: $workItemDir"
    if ($SpecDirectory) {
        Write-Host "  Spec directory: $SpecDirectory"
    }
    if ($BranchName) {
        Write-Host "  Branch: $BranchName"
    }
    Write-Host "  Set as ACTIVE"

    # Return the work item ID for scripting
    return $workItemId
}

function Invoke-SetActive {
    param([string]$WorkItemId)

    if ([string]::IsNullOrWhiteSpace($WorkItemId)) {
        Write-Error "Usage: work-item.ps1 set-active <WorkItemId>"
        exit 1
    }

    # Validate WorkItemId format
    if ($WorkItemId -notmatch '^WI-\d{8}-\d{4}-.+$') {
        Write-Error "Invalid WorkItemId format. Expected: WI-YYYYMMDD-HHMM-slug"
        exit 1
    }

    # Check if work item exists
    $workItemDir = Join-Path $WorkItemsRoot $WorkItemId
    if (-not (Test-Path $workItemDir)) {
        Write-Error "Work item not found: $workItemDir"
        exit 1
    }

    Write-Utf8NoBom -Path $ActiveFile -Content $WorkItemId
    Write-Host "Set active work item: $WorkItemId"
}

function Invoke-ClearActive {
    Write-Utf8NoBom -Path $ActiveFile -Content ""
    Write-Host "Cleared ACTIVE pointer"
}

function Invoke-AddArtifact {
    param(
        [string]$ArtifactType,
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($ArtifactType) -or [string]::IsNullOrWhiteSpace($Path)) {
        Write-Error "Usage: work-item.ps1 add-artifact <type> <path>"
        Write-Error "  type: investigation, implementation, review, verification, research"
        exit 1
    }

    $workItemId = Get-ActiveWorkItemId
    if (-not $workItemId) {
        Write-Host "No active work item. Artifact not recorded."
        exit 0
    }

    $manifest = Get-Manifest
    if (-not $manifest) {
        Write-Error "Could not load manifest for active work item: $workItemId"
        exit 1
    }

    $timestamp = Get-UtcTimestamp
    $newArtifact = @{
        path = $Path
        type = $ArtifactType
        created_utc = $timestamp
        agent = ""
    }

    if ($null -eq $manifest.artifacts) {
        $manifest.artifacts = @()
    }
    $manifest.artifacts = @($manifest.artifacts) + $newArtifact

    Save-Manifest -Manifest $manifest

    Write-Host "Added artifact: $ArtifactType"
    Write-Host "  Path: $Path"
}

function Invoke-RouteArtifact {
    param(
        [string]$ArtifactType,
        [string]$SourcePath
    )

    if ([string]::IsNullOrWhiteSpace($ArtifactType) -or [string]::IsNullOrWhiteSpace($SourcePath)) {
        Write-Error "Usage: work-item.ps1 route-artifact <type> <source-path>"
        exit 1
    }

    $workItemId = Get-ActiveWorkItemId
    if (-not $workItemId) {
        Write-Host "No active work item. Cannot route artifact."
        exit 0
    }

    # Resolve source path
    $projectRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    if (-not [System.IO.Path]::IsPathRooted($SourcePath)) {
        $SourcePath = Join-Path $projectRoot $SourcePath
    }

    if (-not (Test-Path $SourcePath)) {
        Write-Error "Source file not found: $SourcePath"
        exit 1
    }

    # Compute destination
    $workItemDir = Join-Path $WorkItemsRoot $workItemId
    $artifactSubfolder = Get-ArtifactDestinationFolder -ArtifactType $ArtifactType
    $destDir = Join-Path $workItemDir $artifactSubfolder

    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    $fileName = Split-Path -Leaf $SourcePath
    $destPath = Join-Path $destDir $fileName

    # Handle name collision
    if (Test-Path $destPath) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)
        $extension = [System.IO.Path]::GetExtension($fileName)
        $timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
        $fileName = "${baseName}-${timestamp}${extension}"
        $destPath = Join-Path $destDir $fileName
    }

    Move-Item -Path $SourcePath -Destination $destPath -Force

    # Add to manifest
    $relPath = $destPath.Substring((Split-Path -Parent (Split-Path -Parent $PSScriptRoot)).Length).TrimStart('\', '/')
    $relPath = $relPath -replace '\\', '/'

    Invoke-AddArtifact -ArtifactType $ArtifactType -Path $relPath

    Write-Host "Routed artifact: $ArtifactType"
    Write-Host "  From: $SourcePath"
    Write-Host "  To: $destPath"
}

function Invoke-NewArtifact {
    param(
        [string]$ArtifactType,
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($ArtifactType) -or [string]::IsNullOrWhiteSpace($Name)) {
        Write-Error "Usage: work-item.ps1 new-artifact <type> <name>"
        exit 1
    }

    $workItemId = Get-ActiveWorkItemId
    if (-not $workItemId) {
        Write-Error "No active work item. Cannot create artifact path."
        exit 1
    }

    $workItemDir = Join-Path $WorkItemsRoot $workItemId
    $artifactSubfolder = Get-ArtifactDestinationFolder -ArtifactType $ArtifactType
    $destDir = Join-Path $workItemDir $artifactSubfolder

    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }

    $fullPath = Join-Path $destDir $Name

    # Handle name collision
    if (Test-Path $fullPath) {
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($Name)
        $extension = [System.IO.Path]::GetExtension($Name)
        $timestamp = (Get-Date).ToUniversalTime().ToString("yyyyMMdd-HHmmss")
        $Name = "${baseName}-${timestamp}${extension}"
        $fullPath = Join-Path $destDir $Name
    }

    Write-Output $fullPath
}

function Invoke-Status {
    $workItemId = Get-ActiveWorkItemId

    if (-not $workItemId) {
        Write-Host "No active work item."
        Write-Host ""
        Write-Host "To create a new work item:"
        Write-Host "  .\work-item.ps1 create <slug>"
        Write-Host ""
        Write-Host "To set an existing work item as active:"
        Write-Host "  .\work-item.ps1 set-active <WorkItemId>"
        exit 0
    }

    Write-Host "Active work item: $workItemId"

    $manifest = Get-Manifest
    if (-not $manifest) {
        Write-Host "  (manifest not found)"
        exit 0
    }

    Write-Host "  Status: $($manifest.status)"
    Write-Host "  Type: $($manifest.type)"
    Write-Host "  Title: $($manifest.title)"
    Write-Host "  Created: $($manifest.created_utc)"

    if ($manifest.spec_directory) {
        Write-Host "  Spec directory: $($manifest.spec_directory)"
    }
    if ($manifest.branch) {
        Write-Host "  Branch: $($manifest.branch)"
    }

    Write-Host ""
    Write-Host "  Artifacts: $($manifest.artifacts.Count)"
    foreach ($artifact in $manifest.artifacts) {
        Write-Host "    - [$($artifact.type)] $($artifact.path)"
    }
}

function Invoke-Complete {
    param([string]$Summary)

    if ([string]::IsNullOrWhiteSpace($Summary)) {
        Write-Error "Usage: work-item.ps1 complete <summary>"
        exit 1
    }

    $workItemId = Get-ActiveWorkItemId
    if (-not $workItemId) {
        Write-Error "No active work item to complete."
        exit 1
    }

    $manifest = Get-Manifest
    if (-not $manifest) {
        Write-Error "Could not load manifest for active work item: $workItemId"
        exit 1
    }

    $timestamp = Get-UtcTimestamp
    $manifest.status = "Completed"
    $manifest.outcome = @{
        summary = $Summary
        result = "Success"
        completed_utc = $timestamp
    }

    Save-Manifest -Manifest $manifest

    # Update CHANGELOG.md
    $date = Get-UtcDate
    $changelogEntry = @"

## $date

### $workItemId
- **Type**: $($manifest.type)
- **Status**: Completed
- **Summary**: $Summary
"@

    if (Test-Path $ChangelogFile) {
        $existingContent = Get-Content $ChangelogFile -Raw
        if ($existingContent -notmatch [regex]::Escape($workItemId)) {
            Add-Content -Path $ChangelogFile -Value $changelogEntry
        }
    } else {
        $header = "# Work Items Changelog`n"
        Write-Utf8NoBom -Path $ChangelogFile -Content ($header + $changelogEntry)
    }

    # Clear ACTIVE pointer
    Invoke-ClearActive

    Write-Host "Completed work item: $workItemId"
    Write-Host "  Summary: $Summary"
    Write-Host "  CHANGELOG.md updated"
    Write-Host "  ACTIVE pointer cleared"
}

# Main command dispatch
switch ($Command) {
    'create' {
        Invoke-Create -Slug $Arg1 -SpecDirectory $SpecDir -BranchName $Branch -WorktreePath $Worktree -WorkType $Type
    }
    'set-active' { Invoke-SetActive -WorkItemId $Arg1 }
    'clear-active' { Invoke-ClearActive }
    'add-artifact' { Invoke-AddArtifact -ArtifactType $Arg1 -Path $Arg2 }
    'route-artifact' { Invoke-RouteArtifact -ArtifactType $Arg1 -SourcePath $Arg2 }
    'new-artifact' { Invoke-NewArtifact -ArtifactType $Arg1 -Name $Arg2 }
    'status' { Invoke-Status }
    'complete' { Invoke-Complete -Summary $Arg1 }
    default {
        Write-Error "Unknown command: $Command"
        Write-Host ""
        Write-Host "Available commands:"
        Write-Host "  create <slug> [--spec-dir <path>] [--branch <name>]  Create work item"
        Write-Host "  set-active <WorkItemId>                               Set active work item"
        Write-Host "  clear-active                                          Clear ACTIVE pointer"
        Write-Host "  add-artifact <type> <path>                            Record artifact"
        Write-Host "  route-artifact <type> <source-path>                   Move artifact to work item"
        Write-Host "  new-artifact <type> <name>                            Get new artifact path"
        Write-Host "  status                                                Show status"
        Write-Host "  complete <summary>                                    Complete work item"
        exit 1
    }
}
