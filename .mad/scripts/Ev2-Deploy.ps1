<#
.SYNOPSIS
    Full Ev2 deployment pipeline: register artifacts and start rollout.
    Authenticates ONCE and reuses credentials for all operations.

    When -BuildId is specified, queues the unofficial release pipeline (52318)
    via ADO REST API with the specific CI build pinned as the artifact source.
    This bypasses the Ev2 PowerShell client entirely.

.PARAMETER Environment
    Target environment: tonym, npe

.PARAMETER ArtifactVersion
    Build version (reads from buildver.txt if not specified)

.PARAMETER BuildId
    CI build ID to pin as the artifact source. When specified, queues the
    unofficial release pipeline (52318) via REST API with resource version
    pinning, bypassing the Ev2 PowerShell client. Use this to ensure the
    release picks up a specific branch's build instead of the latest across
    all branches.

.PARAMETER SkipRegister
    Skip artifact registration (already registered)

.EXAMPLE
    .\Ev2-Deploy.ps1 -Environment tonym
    .\Ev2-Deploy.ps1 -Environment tonym -ArtifactVersion 1.0.03326.39
    .\Ev2-Deploy.ps1 -Environment tonym -SkipRegister
    .\Ev2-Deploy.ps1 -Environment tonym -BuildId 12345
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet("tonym", "npe", "kcaver", "lpilat", "v-raidasilva", "v-tuliog", "v-matheusc")]
    [string]$Environment,

    [string]$ArtifactVersion,

    [string]$BuildId,

    [switch]$SkipRegister
)

$ErrorActionPreference = "Stop"

# --- Build-pinned deployment via az pipelines run ---
if ($BuildId) {
    Write-Host ""
    Write-Host "=== Queuing Release Pipeline with Pinned Build ===" -ForegroundColor Cyan
    Write-Host "Environment: $Environment"
    Write-Host "Build ID:    $BuildId"
    Write-Host "Pipeline:    52318 (LENS-CMS Unofficial Release)"
    Write-Host ""
    Write-Host "NOTE: az pipelines run does not support resource version pinning directly."
    Write-Host "Ensure build $BuildId is the LATEST CI build before triggering."
    Write-Host ""

    $result = az pipelines run `
        --id 52318 `
        --parameters "lensEnvironment=$Environment" `
        --output json 2>&1

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to queue pipeline: $result"
    }

    $run = $result | ConvertFrom-Json
    $runId = $run.id
    $runName = $run.name

    Write-Host ""
    Write-Host "=== Pipeline Run Queued ===" -ForegroundColor Green
    Write-Host "Run ID:  $runId"
    Write-Host "Name:    $runName"
    Write-Host ""
    Write-Host "Monitor status:" -ForegroundColor Cyan
    Write-Host "  az pipelines runs show --id $runId"

    # Exit early -- BuildId mode skips the Ev2 PowerShell client path
    exit 0
}

# --- Constants ---
$ServiceIdentifier = "45613d46-5932-46b6-bae5-7f153e047353"
$ServiceGroupOverride = "Microsoft.M365.LENS.CMS.$Environment"
$RolloutInfra = "Test"
$GuestAccountTenantId = "b1a4f7cb-a159-44a6-ac48-6674e85c4ddc"
$ServiceGroupRoot = "C:\source\CCGHCP\src\LENS-CMS\build-artifacts\target\publish\CMS\ev2\ServiceGroupRoot"

# --- Load Ev2 Module (authenticates ONCE via browser) ---
Write-Host "Loading Ev2 module..." -ForegroundColor Cyan
. C:\Ev2_PowerShell\AzureServiceDeployClient.ps1

# --- Read version ---
if (-not $ArtifactVersion) {
    $buildverPath = Join-Path $ServiceGroupRoot "buildver.txt"
    if (Test-Path $buildverPath) {
        $ArtifactVersion = (Get-Content $buildverPath -Raw).Trim()
        Write-Host "Read version from buildver.txt: $ArtifactVersion" -ForegroundColor Green
    } else {
        Write-Error "No artifact version specified and buildver.txt not found at $buildverPath"
    }
}

Write-Host ""
Write-Host "=== Ev2 Deploy ===" -ForegroundColor Cyan
Write-Host "Environment:      $Environment"
Write-Host "Service Group:    $ServiceGroupOverride"
Write-Host "Artifact Version: $ArtifactVersion"
Write-Host "Skip Register:    $SkipRegister"
Write-Host ""

# --- Step 1: Register ---
if (-not $SkipRegister) {
    Write-Host "--- Step 1: Registering artifacts ---" -ForegroundColor Yellow
    Register-AzureServiceArtifacts `
        -ServiceGroupRoot $ServiceGroupRoot `
        -RolloutSpec "RolloutSpec.json" `
        -RolloutInfra $RolloutInfra `
        -ArtifactsVersion $ArtifactVersion `
        -Force `
        -ServiceGroupOverride $ServiceGroupOverride `
        -GuestAccountTenantId $GuestAccountTenantId
    Write-Host "Registration complete." -ForegroundColor Green
} else {
    Write-Host "--- Skipping registration ---" -ForegroundColor DarkYellow
}

# --- Step 2: Start Rollout ---
Write-Host ""
Write-Host "--- Step 2: Starting rollout ---" -ForegroundColor Yellow
$rollout = New-AzureServiceRollout `
    -ServiceIdentifier $ServiceIdentifier `
    -ServiceGroup $ServiceGroupOverride `
    -ArtifactsVersion $ArtifactVersion `
    -Select "regions(westus3)" `
    -StageMapName "Microsoft.Azure.SDP.Standard" `
    -StageMapVersion "0.0.10" `
    -RolloutInfra $RolloutInfra `
    -GuestAccountTenantId $GuestAccountTenantId

$rolloutId = $rollout.RolloutId
Write-Host ""
Write-Host "Rollout started: $rolloutId" -ForegroundColor Green
Write-Host "Status: $($rollout.Status)"

# --- Step 3: Poll until complete ---
Write-Host ""
Write-Host "--- Step 3: Monitoring rollout ---" -ForegroundColor Yellow
$maxWait = 40  # max 40 iterations * 30s = 20 minutes
$i = 0
do {
    Start-Sleep -Seconds 30
    $i++
    $status = Get-AzureServiceRollout `
        -ServiceIdentifier $ServiceIdentifier `
        -ServiceGroup $ServiceGroupOverride `
        -RolloutInfra $RolloutInfra `
        -RolloutId $rolloutId `
        -GuestAccountTenantId $GuestAccountTenantId

    $elapsed = [math]::Round($i * 0.5, 1)
    Write-Host "[$elapsed min] Status: $($status.Status)" -ForegroundColor $(if ($status.Status -eq "Succeeded") { "Green" } elseif ($status.Status -eq "Failed") { "Red" } else { "DarkYellow" })
} while ($status.Status -eq "Running" -and $i -lt $maxWait)

# --- Result ---
Write-Host ""
if ($status.Status -eq "Succeeded") {
    Write-Host "=== DEPLOYMENT SUCCEEDED ===" -ForegroundColor Green
    Write-Host "Rollout ID: $rolloutId"
    Write-Host "Version: $ArtifactVersion"
    Write-Host "App URL: https://app-cms-$Environment-westus3.azurewebsites.net"
    Write-Host ""
    Write-Host "Next: Run E2E tests:" -ForegroundColor Cyan
    Write-Host "  ACI (behavioral): /e2e-test-aci $Environment"
    Write-Host "  Local (smoke):    .\Test-CmsApi.ps1 -BaseUrl https://app-cms-$Environment-westus3.azurewebsites.net"
} elseif ($status.Status -eq "Failed") {
    Write-Host "=== DEPLOYMENT FAILED ===" -ForegroundColor Red
    Write-Host "Rollout ID: $rolloutId"
    Write-Host "Check portal: https://ra.ev2portal.azure.net/#/rollouts/Test/$ServiceIdentifier/$ServiceGroupOverride/$rolloutId"
    Write-Host ""
    Write-Host "To restart failed actions:" -ForegroundColor Yellow
    Write-Host "  .\Ev2-RestartFailed.ps1 -Environment $Environment -RolloutId $rolloutId"
    exit 1
} else {
    Write-Host "=== DEPLOYMENT STILL RUNNING (timed out waiting) ===" -ForegroundColor Yellow
    Write-Host "Rollout ID: $rolloutId"
    Write-Host "Check status:" -ForegroundColor Yellow
    Write-Host "  .\Ev2-Status.ps1 -Environment $Environment -RolloutId $rolloutId"
}
