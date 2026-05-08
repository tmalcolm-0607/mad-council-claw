<#
.SYNOPSIS
  Create, update, or query ADO work items for the ado-sync skill.

.DESCRIPTION
  Helper script for managing Feature, User Story, and Task work items in Azure DevOps.
  Returns JSON with the work item ID and URL.

.PARAMETER Action
  create | update | link-parent | show | delete

.PARAMETER Type
  Feature | "User Story" | Task

.PARAMETER Title
  Work item title

.PARAMETER Description
  Work item description (HTML allowed)

.PARAMETER AcceptanceCriteria
  Acceptance criteria for User Stories (HTML allowed)

.PARAMETER Priority
  Priority (1=Critical, 2=High, 3=Medium, 4=Low)

.PARAMETER State
  Work item state (New, Active, Closed)

.PARAMETER ParentId
  Parent work item ID for hierarchy link

.PARAMETER EpicId
  Epic work item ID (for Feature parent link)

.PARAMETER Id
  Work item ID (for show/delete/link-parent/update actions)

.PARAMETER Tags
  Comma-separated tags (e.g., "US1,Phase3,P0")

.PARAMETER Org
  ADO organization URL

.PARAMETER Project
  ADO project name

.PARAMETER AreaPath
  Area path for the work item

.PARAMETER IterationPath
  Iteration path for the work item
#>

param(
    [Parameter(Mandatory)]
    [ValidateSet('create', 'update', 'link-parent', 'show', 'delete')]
    [string]$Action,

    [string]$Type,
    [string]$Title,
    [string]$Description,
    [string]$AcceptanceCriteria,
    [int]$Priority,
    [string]$State,
    [int]$ParentId,
    [int]$EpicId,
    [int]$Id,
    [string]$Tags,
    [string]$Org = "https://o365exchange.visualstudio.com",
    [string]$Project = "LENS",
    [string]$AreaPath = "LENS\Case Management",
    [string]$IterationPath = "LENS"
)

$ErrorActionPreference = 'Continue'

function Create-WorkItem {
    $args_list = @(
        "boards", "work-item", "create",
        "--type", $Type,
        "--title", $Title,
        "--project", $Project,
        "--org", $Org,
        "--area", $AreaPath,
        "--iteration", $IterationPath,
        "-o", "json"
    )

    if ($Description) {
        $args_list += @("--description", $Description)
    }

    $env:MSYS_NO_PATHCONV = "1"
    $result = & az @args_list 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create work item: $result"
        return $null
    }

    $wi = $result | ConvertFrom-Json
    $wiId = $wi.id
    $wiUrl = "https://o365exchange.visualstudio.com/LENS/_workitems/edit/$wiId"

    # Add parent link if specified
    if ($ParentId -gt 0) {
        $linkResult = & az boards work-item relation add --id $wiId --relation-type parent --target-id $ParentId --org $Org -o json 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to add parent link: $linkResult"
        }
    }
    elseif ($EpicId -gt 0) {
        $linkResult = & az boards work-item relation add --id $wiId --relation-type parent --target-id $EpicId --org $Org -o json 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to add epic link: $linkResult"
        }
    }

    # Add tags if specified
    if ($Tags) {
        $tagResult = & az boards work-item update --id $wiId --org $Org --fields "System.Tags=$Tags" -o json 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Failed to add tags: $tagResult"
        }
    }

    return @{
        id = $wiId
        type = $Type
        title = $Title
        url = $wiUrl
        parentId = if ($ParentId -gt 0) { $ParentId } elseif ($EpicId -gt 0) { $EpicId } else { $null }
    }
}

function Update-WorkItem {
    $fields = @()

    if ($Description) {
        $fields += "System.Description=$Description"
    }
    if ($AcceptanceCriteria) {
        $fields += "Microsoft.VSTS.Common.AcceptanceCriteria=$AcceptanceCriteria"
    }
    if ($Priority -gt 0) {
        $fields += "Microsoft.VSTS.Common.Priority=$Priority"
    }
    if ($State) {
        $fields += "System.State=$State"
    }
    if ($Title) {
        $fields += "System.Title=$Title"
    }

    if ($fields.Count -eq 0) {
        Write-Error "No fields to update"
        return $null
    }

    $args_list = @(
        "boards", "work-item", "update",
        "--id", $Id,
        "--org", $Org,
        "-o", "json"
    )

    foreach ($f in $fields) {
        $args_list += @("--fields", $f)
    }

    if ($Tags) {
        $args_list += @("--fields", "System.Tags=$Tags")
    }

    $env:MSYS_NO_PATHCONV = "1"
    $result = & az @args_list 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to update work item $Id - $result"
        return $null
    }

    $wi = $result | ConvertFrom-Json
    return @{
        id = $wi.id
        title = $wi.fields.'System.Title'
        state = $wi.fields.'System.State'
        url = "https://o365exchange.visualstudio.com/LENS/_workitems/edit/$($wi.id)"
        updated = $true
    }
}

function Show-WorkItem {
    $env:MSYS_NO_PATHCONV = "1"
    $result = & az boards work-item show --id $Id --org $Org -o json 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to show work item $Id - $result"
        return $null
    }
    return $result | ConvertFrom-Json
}

function Delete-WorkItem {
    $env:MSYS_NO_PATHCONV = "1"
    $result = & az boards work-item delete --id $Id --project $Project --org $Org --yes 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to delete work item $Id - $result"
        return $null
    }
    Write-Host "Deleted work item $Id"
}

function LinkParent {
    $env:MSYS_NO_PATHCONV = "1"
    $result = & az boards work-item relation add --id $Id --relation-type parent --target-id $ParentId --org $Org -o json 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to link $Id to parent $ParentId - $result"
        return $null
    }
    Write-Host "Linked $Id -> parent $ParentId"
}

# Execute
switch ($Action) {
    'create' {
        $item = Create-WorkItem
        if ($item) {
            $item | ConvertTo-Json -Compress
        }
    }
    'update' {
        $item = Update-WorkItem
        if ($item) {
            $item | ConvertTo-Json -Compress
        }
    }
    'show' {
        Show-WorkItem
    }
    'delete' {
        Delete-WorkItem
    }
    'link-parent' {
        LinkParent
    }
}
