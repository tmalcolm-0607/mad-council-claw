<#
.SYNOPSIS
    Restart failed Ev2 rollout actions. Authenticates once.

.PARAMETER Environment
    Target environment: tonym, npe

.PARAMETER RolloutId
    The rollout GUID with failed actions

.PARAMETER ArtifactVersion
    New artifact version (optional, uses current if not specified)

.EXAMPLE
    .\Ev2-RestartFailed.ps1 -Environment tonym -RolloutId 90bbb0fb-15ad-4057-9d9f-fb74dca1ec64
    .\Ev2-RestartFailed.ps1 -Environment tonym -RolloutId 90bbb0fb-... -ArtifactVersion 1.0.03326.40
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("tonym", "npe")]
    [string]$Environment,

    [Parameter(Mandatory)]
    [string]$RolloutId,

    [string]$ArtifactVersion
)

$ErrorActionPreference = "Stop"

$ServiceIdentifier = "45613d46-5932-46b6-bae5-7f153e047353"
$ServiceGroupOverride = "Microsoft.M365.LENS.CMS.$Environment"
$GuestAccountTenantId = "b1a4f7cb-a159-44a6-ac48-6674e85c4ddc"

. C:\Ev2_PowerShell\AzureServiceDeployClient.ps1

$params = @{
    ServiceIdentifier    = $ServiceIdentifier
    ServiceGroup         = $ServiceGroupOverride
    RolloutInfra         = "Test"
    RolloutId            = $RolloutId
    GuestAccountTenantId = $GuestAccountTenantId
}
if ($ArtifactVersion) { $params["ArtifactsVersion"] = $ArtifactVersion }

Write-Host "Restarting failed actions for rollout $RolloutId..." -ForegroundColor Yellow
Restart-AzureServiceRolloutFailedActions @params

Write-Host "`nWatching status..." -ForegroundColor Cyan
$maxIter = 40
$i = 0
do {
    Start-Sleep -Seconds 30
    $i++
    $r = Get-AzureServiceRollout -ServiceIdentifier $ServiceIdentifier `
        -ServiceGroup $ServiceGroupOverride -RolloutInfra Test `
        -RolloutId $RolloutId -GuestAccountTenantId $GuestAccountTenantId
    $elapsed = [math]::Round($i * 0.5, 1)
    Write-Host "[$elapsed min] Status: $($r.Status)" -ForegroundColor $(
        if ($r.Status -eq "Succeeded") { "Green" }
        elseif ($r.Status -eq "Failed") { "Red" }
        else { "DarkYellow" }
    )
} while ($r.Status -eq "Running" -and $i -lt $maxIter)

if ($r.Status -eq "Succeeded") {
    Write-Host "`n=== RESTART SUCCEEDED ===" -ForegroundColor Green
} elseif ($r.Status -eq "Failed") {
    Write-Host "`n=== RESTART FAILED ===" -ForegroundColor Red
    Write-Host "Portal: https://ra.ev2portal.azure.net/#/rollouts/Test/$ServiceIdentifier/$ServiceGroupOverride/$RolloutId"
    exit 1
}
