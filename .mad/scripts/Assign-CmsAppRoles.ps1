<#
.SYNOPSIS
    Assign CMS app roles to a managed identity. Idempotent — skips existing assignments.

.DESCRIPTION
    After Ev2 deploys a new environment, the managed identity needs Azure AD app roles
    (CMS.CaseReader, CMS.CaseWriter, CMS.SystemIntegration) to call the CMS API. Entra ID app roles cannot be
    deployed via Bicep/Ev2, so this script runs as a post-provisioning step.

    Supports two modes:
    - Environment mode (default): looks up the CMS API managed identity by name in the environment's resource group.
    - External UAMI mode (-PrincipalId): assigns roles to any service principal by object ID, for external
      services that need to call CMS (e.g., Publish Service 3P app).

.PARAMETER Environment
    Target environment: tonym, npe, kcaver, lpilat, v-raidasilva, v-tuliog, v-matheusc

.PARAMETER PrincipalId
    Object ID of an external service principal or UAMI. When provided, skips the MI lookup
    and assigns roles directly to this principal. Environment is still required for display purposes.

.PARAMETER Roles
    Optional list of role names to assign. Defaults to CMS.CaseReader, CMS.CaseWriter, CMS.SystemIntegration.

.PARAMETER WhatIf
    Show what would be assigned without making changes

.EXAMPLE
    .\Assign-CmsAppRoles.ps1 -Environment npe
    .\Assign-CmsAppRoles.ps1 -Environment npe -WhatIf
    .\Assign-CmsAppRoles.ps1 -Environment npe -PrincipalId "ce7832a1-3fc1-4273-863a-b25f005a27f1"
    .\Assign-CmsAppRoles.ps1 -Environment npe -PrincipalId "ce7832a1-3fc1-4273-863a-b25f005a27f1" -Roles @("CMS.CaseReader")
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet("tonym", "npe", "kcaver", "lpilat", "v-raidasilva", "v-tuliog", "v-matheusc", "v-nnunes")]
    [string]$Environment,

    [Parameter()]
    [string]$PrincipalId = '',

    [Parameter()]
    [string[]]$Roles = @()
)

$ErrorActionPreference = "Stop"

# --- Constants ---
$CmsAppId = "6c5a00ce-8062-49d8-b568-b9bd0363340b"
$SubscriptionId = "d27c8315-7947-43ea-88ed-1f1c34860559"
$ResourceGroup = "rg-lenscms-$Environment"
$MiName = "id-lenscmsapi-$Environment-westus3"

$RequiredRoles = if ($Roles.Count -gt 0) { $Roles } else {
    @(
        "CMS.CaseReader",
        "CMS.CaseWriter",
        "CMS.SystemIntegration"
    )
}
# Note: CMS.AttachmentReader, CMS.AttachmentWriter, CMS.AggregateReader are defined in
# CMS code (CmsRoles.cs) but not yet registered in the Azure AD app manifest.
# CMS.SystemIntegration satisfies ALL policies as a superuser role.

Write-Host "=== CMS App Role Assignment ===" -ForegroundColor Cyan
Write-Host "Environment:  $Environment"
Write-Host "CMS App ID:   $CmsAppId"

# --- Step 1: Resolve principal ID ---
Write-Host "--- Step 1: Get managed identity ---" -ForegroundColor Yellow

if ($PrincipalId -ne '') {
    Write-Host "Using external principal ID: $PrincipalId" -ForegroundColor Cyan
} else {
    Write-Host "MI Name:      $MiName"
    $mi = az identity show `
        --name $MiName `
        --resource-group $ResourceGroup `
        --subscription $SubscriptionId `
        --query "{principalId: principalId, clientId: clientId}" `
        --output json 2>&1 | ConvertFrom-Json

    if (-not $mi.principalId) {
        Write-Error "Could not find managed identity '$MiName' in resource group '$ResourceGroup'"
    }

    $PrincipalId = $mi.principalId
}

Write-Host "Principal ID:  $PrincipalId" -ForegroundColor Green
Write-Host "Roles:         $($RequiredRoles -join ', ')"
Write-Host ""

# --- Step 2: Get CMS service principal and app role IDs ---
Write-Host "--- Step 2: Get CMS service principal ---" -ForegroundColor Yellow
$sp = az ad sp show --id $CmsAppId --query "{id: id, appRoles: appRoles}" --output json 2>&1 | ConvertFrom-Json

if (-not $sp.id) {
    Write-Error "Could not find service principal for app ID '$CmsAppId'"
}

$spObjectId = $sp.id
Write-Host "CMS SP Object ID: $spObjectId" -ForegroundColor Green

# Build role name -> ID map
$roleMap = @{}
foreach ($role in $sp.appRoles) {
    $roleMap[$role.value] = $role.id
}

foreach ($roleName in $RequiredRoles) {
    if (-not $roleMap.ContainsKey($roleName)) {
        Write-Error "App role '$roleName' not found on CMS service principal. Available: $($roleMap.Keys -join ', ')"
    }
}
Write-Host "Required roles found: $($RequiredRoles -join ', ')" -ForegroundColor Green
Write-Host ""

# --- Step 3: Check existing assignments ---
Write-Host "--- Step 3: Check existing role assignments ---" -ForegroundColor Yellow
$existingRaw = az rest --method GET `
    --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$spObjectId/appRoleAssignedTo" `
    --query "value[?principalId=='$PrincipalId'].{roleId: appRoleId, principalId: principalId}" `
    --output json 2>&1

$existing = $existingRaw | ConvertFrom-Json
$existingRoleIds = @()
if ($existing) {
    $existingRoleIds = $existing | ForEach-Object { $_.roleId }
}

# --- Step 4: Assign missing roles ---
Write-Host "--- Step 4: Assign roles ---" -ForegroundColor Yellow
$assigned = 0
$skipped = 0

foreach ($roleName in $RequiredRoles) {
    $roleId = $roleMap[$roleName]

    if ($existingRoleIds -contains $roleId) {
        Write-Host "  SKIP: $roleName (already assigned)" -ForegroundColor DarkYellow
        $skipped++
        continue
    }

    if ($PSCmdlet.ShouldProcess("$roleName ($roleId) -> principal $PrincipalId", "Assign app role")) {
        $body = @{
            principalId = $PrincipalId
            resourceId  = $spObjectId
            appRoleId   = $roleId
        } | ConvertTo-Json -Compress

        $bodyFile = [System.IO.Path]::GetTempFileName()
        $body | Out-File -FilePath $bodyFile -Encoding utf8

        az rest --method POST `
            --uri "https://graph.microsoft.com/v1.0/servicePrincipals/$spObjectId/appRoleAssignedTo" `
            --body "@$bodyFile" `
            --headers "Content-Type=application/json" `
            --output json 2>&1 | Out-Null

        Remove-Item $bodyFile -Force

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ASSIGNED: $roleName" -ForegroundColor Green
            $assigned++
        } else {
            Write-Error "Failed to assign role '$roleName'"
        }
    }
}

# --- Summary ---
Write-Host ""
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Assigned: $assigned"
Write-Host "Skipped:  $skipped (already assigned)"
Write-Host "Total:    $($RequiredRoles.Count) required roles"

if ($assigned -eq 0 -and $skipped -eq $RequiredRoles.Count) {
    Write-Host ""
    Write-Host "All roles already assigned - no changes needed." -ForegroundColor Green
}
