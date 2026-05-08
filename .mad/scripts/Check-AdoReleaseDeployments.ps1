<#
.SYNOPSIS
Diagnose an ADO release pipeline deploy by inspecting ARM deployment results in the target resource group.

.DESCRIPTION
ADO release pipelines that wrap Ev2 (or ARM) report "Rollout: succeeded" the moment they
SUBMIT a rollout, while the actual ARM deployments execute asynchronously inside Azure
and can fail silently. The pipeline's own "Monitoring" task polls Ev2 and may stay
inProgress for hours even when ARM deployments have already failed.

This script answers "did the deploy actually work?" by checking the resource group's
deployment history directly, which is the source of truth.

.PARAMETER ResourceGroup
Target resource group (e.g. rg-lenscms-tonym-westus3).

.PARAMETER Subscription
Azure subscription ID containing the resource group.

.PARAMETER Since
Only inspect deployments started after this UTC timestamp (ISO 8601). Defaults to 2 hours ago.

.PARAMETER FailedOnly
Only show failed deployments. Default: show summary + all failures.

.EXAMPLE
.\Check-AdoReleaseDeployments.ps1 -ResourceGroup rg-lenscms-tonym-westus3 -Subscription d27c8315-7947-43ea-88ed-1f1c34860559

.EXAMPLE
.\Check-AdoReleaseDeployments.ps1 -ResourceGroup rg-lenscms-npe-westus3 -Subscription d27c8315-7947-43ea-88ed-1f1c34860559 -Since 2026-04-30T00:00:00Z -FailedOnly

.NOTES
Use this IMMEDIATELY when an ADO release shows "succeeded" but the App Service env vars,
container images, or other resources haven't actually updated. Trusting the pipeline status
alone has cost hours of debugging — see rules/deployment-failure-diagnosis.md.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$ResourceGroup,

    [Parameter(Mandatory)]
    [string]$Subscription,

    [string]$Since = (Get-Date).ToUniversalTime().AddHours(-2).ToString("yyyy-MM-ddTHH:mm:ssZ"),

    [switch]$FailedOnly
)

$ErrorActionPreference = 'Stop'
$env:MSYS_NO_PATHCONV = '1'

Write-Host "=== ADO Release Deployment Diagnostic ===" -ForegroundColor Cyan
Write-Host "Resource group: $ResourceGroup"
Write-Host "Subscription:   $Subscription"
Write-Host "Since:          $Since"
Write-Host ""

# Pull all ARM deployments started since the cutoff.
$query = "[?properties.timestamp >= '$Since'].{name:name,state:properties.provisioningState,timestamp:properties.timestamp,error:properties.error.details[0]}"
$rawJson = az deployment group list --resource-group $ResourceGroup --subscription $Subscription --query $query 2>$null
if (-not $rawJson) {
    Write-Warning "No ARM deployments found in $ResourceGroup since $Since."
    exit 0
}
$deployments = $rawJson | ConvertFrom-Json

$succeeded = @($deployments | Where-Object { $_.state -eq 'Succeeded' })
$failed    = @($deployments | Where-Object { $_.state -eq 'Failed' })
$running   = @($deployments | Where-Object { $_.state -eq 'Running' })
$other     = @($deployments | Where-Object { $_.state -notin @('Succeeded','Failed','Running') })

Write-Host "--- Summary ---" -ForegroundColor Yellow
Write-Host "  Succeeded: $($succeeded.Count)"
Write-Host "  Failed:    $($failed.Count)" -ForegroundColor $(if ($failed.Count -gt 0) {'Red'} else {'Green'})
Write-Host "  Running:   $($running.Count)"
if ($other.Count -gt 0) { Write-Host "  Other:     $($other.Count)" }
Write-Host ""

if ($failed.Count -gt 0) {
    Write-Host "--- FAILED DEPLOYMENTS ---" -ForegroundColor Red
    foreach ($d in $failed) {
        Write-Host ""
        Write-Host "  Name:      $($d.name)" -ForegroundColor Red
        Write-Host "  Timestamp: $($d.timestamp)"
        if ($d.error) {
            Write-Host "  Error code:    $($d.error.code)" -ForegroundColor Yellow
            $msg = $d.error.message
            if ($msg.Length -gt 400) { $msg = $msg.Substring(0, 400) + '...' }
            Write-Host "  Error message: $msg"
        }
    }
    Write-Host ""
    Write-Host "Diagnosis: at least one ARM deployment failed inside the rollout. The pipeline" -ForegroundColor Yellow
    Write-Host "may still report 'inProgress' or even 'succeeded' for the rollout submission." -ForegroundColor Yellow
    Write-Host "Fix the bicep/parameter issue and redeploy. Do not trust pipeline status alone." -ForegroundColor Yellow
    exit 1
}

if (-not $FailedOnly -and $succeeded.Count -gt 0) {
    Write-Host "--- Recent succeeded deployments (most recent 10) ---" -ForegroundColor Green
    $succeeded |
        Sort-Object timestamp -Descending |
        Select-Object -First 10 |
        ForEach-Object { Write-Host ("  {0,-25} {1}" -f $_.timestamp, $_.name) }
}

if ($failed.Count -eq 0) {
    Write-Host ""
    Write-Host "All ARM deployments succeeded since $Since." -ForegroundColor Green
    exit 0
}
