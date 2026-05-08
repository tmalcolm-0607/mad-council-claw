<#
.SYNOPSIS
    Check Ev2 rollout status. Authenticates once and polls.

.PARAMETER Environment
    Target environment: tonym, npe

.PARAMETER RolloutId
    The rollout GUID to check

.PARAMETER Watch
    Continuously poll every 30s until completion

.EXAMPLE
    .\Ev2-Status.ps1 -Environment tonym -RolloutId 90bbb0fb-15ad-4057-9d9f-fb74dca1ec64
    .\Ev2-Status.ps1 -Environment tonym -RolloutId 90bbb0fb-15ad-4057-9d9f-fb74dca1ec64 -Watch
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("tonym", "npe", "kcaver", "lpilat", "v-raidasilva", "v-tuliog", "v-matheusc")]
    [string]$Environment,

    [Parameter(Mandatory)]
    [string]$RolloutId,

    [switch]$Watch,

    [switch]$EmbedDetails
)

$ErrorActionPreference = "Stop"

$ServiceIdentifier = "45613d46-5932-46b6-bae5-7f153e047353"
$ServiceGroupOverride = "Microsoft.M365.LENS.CMS.$Environment"
$GuestAccountTenantId = "b1a4f7cb-a159-44a6-ac48-6674e85c4ddc"

. C:\Ev2_PowerShell\AzureServiceDeployClient.ps1

$params = @{
    ServiceIdentifier = $ServiceIdentifier
    ServiceGroup      = $ServiceGroupOverride
    RolloutInfra      = "Test"
    RolloutId         = $RolloutId
    GuestAccountTenantId = $GuestAccountTenantId
}
if ($EmbedDetails) { $params["EmbedDetails"] = $true }

if ($Watch) {
    $maxIter = 40  # 40 * 30s = 20 min
    $i = 0
    do {
        $r = Get-AzureServiceRollout @params
        $elapsed = [math]::Round($i * 0.5, 1)
        Write-Host "[$elapsed min] Status: $($r.Status)" -ForegroundColor $(
            if ($r.Status -eq "Succeeded") { "Green" }
            elseif ($r.Status -eq "Failed") { "Red" }
            else { "DarkYellow" }
        )
        if ($r.Status -ne "Running") { break }
        Start-Sleep -Seconds 30
        $i++
    } while ($i -lt $maxIter)

    if ($r.Status -eq "Succeeded") {
        Write-Host "`n=== SUCCEEDED ===" -ForegroundColor Green
    } elseif ($r.Status -eq "Failed") {
        Write-Host "`n=== FAILED ===" -ForegroundColor Red
        Write-Host "Portal: https://ra.ev2portal.azure.net/#/rollouts/Test/$ServiceIdentifier/$ServiceGroupOverride/$RolloutId"
        exit 1
    }
} else {
    Get-AzureServiceRollout @params
}
