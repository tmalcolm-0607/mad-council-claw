<#
.SYNOPSIS
    Run behavioral E2E tests against LENS-CMS via ACI container with Managed Identity.
    Wraps all az container commands into a single script with polling and cleanup.

.PARAMETER Environment
    Target environment: tonym, npe, kcaver, lpilat, v-raidasilva, v-tuliog, v-matheusc

.PARAMETER SkipCleanup
    Leave the ACI container after tests complete (for log inspection)

.PARAMETER WhatIf
    Show what would be executed without creating any Azure resources

.EXAMPLE
    .\Test-E2E-ACI.ps1 -Environment tonym
    .\Test-E2E-ACI.ps1 -Environment tonym -SkipCleanup
    .\Test-E2E-ACI.ps1 -Environment tonym -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet("tonym", "npe", "kcaver", "lpilat", "v-raidasilva", "v-tuliog", "v-matheusc")]
    [string]$Environment,

    [switch]$SkipCleanup,

    [Parameter()]
    [ValidateSet("full", "per-milestone", "cross-milestone", "data-verification", "observability", "cleanup", "reproducers", "authorizations", "escalations", "validate-capture", "scan-dftstatus-nulls", "fix-dftstatus-nulls", "inspect-3-cases", "fix-3-cases", "backfill-case-ti", "verify-3-cases-api", "close-open-gaps", "retype-unspecified-datacats", "scan-lowercase-enums", "fix-null-enums", "inspect-cases-container", "check-delivery-records", "dump-channel-docs", "migrate-publish-to-delivery", "migrate-publish-to-delivery-apply", "fix-record-14", "golden-records", "dump-golden", "augment-golden")]
    [string]$Suite = "full"
)

$ErrorActionPreference = "Stop"
$env:MSYS_NO_PATHCONV = "1"

# --- Constants ---
$SubscriptionId = "d27c8315-7947-43ea-88ed-1f1c34860559"

# Resolve the LENS-CMS source-tree root. Default assumption is the script lives
# alongside the LENS-CMS source ($PSScriptRoot/../..). When the kit is deployed
# in a separate repo, the LENS-CMS clone may be at one of several sibling
# locations. Search candidates in order; first one that contains the canonical
# appsettings.json wins.
$LensCmsSrcRoot = $null
$candidateRoots = @(
    (Join-Path $PSScriptRoot "..\.."),
    (Join-Path $PSScriptRoot "..\..\references\LENS-CMS"),
    "C:\source\CCGHCP\src\LENS-CMS-pr5158153-fix",
    "C:\source\CCGHCP\src\LENS-CMS"
)
if ($env:LENS_CMS_SOURCE_ROOT) {
    $candidateRoots = ,$env:LENS_CMS_SOURCE_ROOT + $candidateRoots
}
foreach ($candidate in $candidateRoots) {
    $probe = Join-Path $candidate "sources\dev\CMS\src\API\appsettings.json"
    if (Test-Path $probe) {
        $LensCmsSrcRoot = $candidate
        break
    }
}
if (-not $LensCmsSrcRoot) {
    throw "Could not locate LENS-CMS source repo. Tried: $($candidateRoots -join ', '). Set LENS_CMS_SOURCE_ROOT env var to override."
}
Write-Host "LENS-CMS source root: $LensCmsSrcRoot" -ForegroundColor DarkGray

# CMS API audience / 1P app ID differs per ring. Read from appsettings.<env>.json
# (same file the deployed service reads). Previously hardcoded as 6c5a00ce-... which
# was the 3P caller app, producing IDX10214 audience-validation 401s because the
# token was addressed at the caller, not the CMS API resource.
$CmsAppId = $null
$appSettingsName = "appsettings.$Environment.json"
$appSettingsPath = Join-Path $LensCmsSrcRoot "sources\dev\CMS\src\API\$appSettingsName"
if (Test-Path $appSettingsPath) {
    # appsettings files contain JS-style // comments; strip before JSON parse (PS 5.1 ConvertFrom-Json fails on comments).
    $raw = Get-Content $appSettingsPath -Raw
    $stripped = [regex]::Replace($raw, '(?m)//[^\r\n]*', '')
    try {
        $cfg = $stripped | ConvertFrom-Json
        if ($cfg.AzureAd -and $cfg.AzureAd.ClientId) {
            $CmsAppId = $cfg.AzureAd.ClientId
        }
    } catch {
        Write-Warning "ConvertFrom-Json failed on $appSettingsName after comment strip: $_"
    }
    # Fallback: raw regex for AzureAd.ClientId if JSON parse failed
    if (-not $CmsAppId) {
        $m = [regex]::Match($raw, '"AzureAd"\s*:\s*\{[^}]*?"ClientId"\s*:\s*"([^"]+)"')
        if ($m.Success) { $CmsAppId = $m.Groups[1].Value }
    }
    if ($CmsAppId) {
        Write-Host "CMS audience (from $appSettingsName): $CmsAppId" -ForegroundColor DarkGray
    }
}
# Fallback: alias environments (tonym, kcaver, etc.) have no appsettings.<env>.json — they share
# a sibling env's appsettings at runtime per Ev2 config aspNetCoreEnvironment (e.g. "npe").
# Resolve via Ev2 config -> aspNetCoreEnvironment -> appsettings.<that-env>.json -> AzureAd.ClientId.
# apiClientId on the Ev2 config is the 3P caller app (NOT the CMS API resource); it is only used
# as a last-resort safety net with a loud warning.
if (-not $CmsAppId) {
    $ev2ConfigPath = Join-Path $LensCmsSrcRoot "sources\dev\CMS\src\Ev2\ServiceGroupRoot\Configuration\Microsoft.M365.LENS.CMS.$Environment.json"
    if (Test-Path $ev2ConfigPath) {
        $raw = Get-Content $ev2ConfigPath -Raw
        # Ev2 templates contain $(token) substitution placeholders + occasionally unterminated strings
        # (e.g. seedTokenAudience spans lines pre-substitution). ConvertFrom-Json may fail; raw-regex
        # fallbacks below cover both aspNetCoreEnvironment and apiClientId reliably.
        $stripped = [regex]::Replace($raw, '(?m)//[^\r\n]*', '')

        # Step 1: extract aspNetCoreEnvironment (the runtime ASPNETCORE_ENVIRONMENT for this alias env)
        $aspNetEnv = $null
        try {
            $cfg = $stripped | ConvertFrom-Json -ErrorAction SilentlyContinue
            if ($cfg -and $cfg.settings -and $cfg.settings.aspNetCoreEnvironment) {
                $aspNetEnv = $cfg.settings.aspNetCoreEnvironment
            }
        } catch { }
        if (-not $aspNetEnv) {
            $m = [regex]::Match($raw, '"aspNetCoreEnvironment"\s*:\s*"([^"]+)"')
            if ($m.Success) { $aspNetEnv = $m.Groups[1].Value }
        }

        # Step 2: load appsettings.<aspNetEnv>.json and read AzureAd.ClientId (the real CMS API audience)
        if ($aspNetEnv -and $aspNetEnv -ne $Environment) {
            $aliasAppSettingsName = "appsettings.$aspNetEnv.json"
            $aliasAppSettingsPath = Join-Path $LensCmsSrcRoot "sources\dev\CMS\src\API\$aliasAppSettingsName"
            if (Test-Path $aliasAppSettingsPath) {
                $rawApp = Get-Content $aliasAppSettingsPath -Raw
                $strippedApp = [regex]::Replace($rawApp, '(?m)//[^\r\n]*', '')
                try {
                    $cfgApp = $strippedApp | ConvertFrom-Json -ErrorAction SilentlyContinue
                    if ($cfgApp -and $cfgApp.AzureAd -and $cfgApp.AzureAd.ClientId) {
                        $CmsAppId = $cfgApp.AzureAd.ClientId
                    }
                } catch { }
                if (-not $CmsAppId) {
                    $m = [regex]::Match($rawApp, '"AzureAd"\s*:\s*\{[^}]*?"ClientId"\s*:\s*"([^"]+)"')
                    if ($m.Success) { $CmsAppId = $m.Groups[1].Value }
                }
                if ($CmsAppId) {
                    Write-Host "CMS audience (from $aliasAppSettingsName via alias $Environment): $CmsAppId" -ForegroundColor DarkGray
                }
            } else {
                Write-Warning "Ev2 config Microsoft.M365.LENS.CMS.$Environment.json declares aspNetCoreEnvironment=$aspNetEnv but $aliasAppSettingsName was not found at $aliasAppSettingsPath."
            }
        }

        # Step 3 (last-resort): apiClientId from Ev2 config. This is usually the 3P caller app, NOT the
        # CMS API resource — tokens with this audience will fail MISE audience validation (IDX10214).
        if (-not $CmsAppId) {
            try {
                $cfg = $stripped | ConvertFrom-Json -ErrorAction SilentlyContinue
                if ($cfg -and $cfg.settings -and $cfg.settings.apiClientId) {
                    $CmsAppId = $cfg.settings.apiClientId
                    Write-Warning "Falling back to apiClientId from Ev2 config: this is often the 3P caller app, not the CMS API. Tokens may fail audience validation. Update aspNetCoreEnvironment in Microsoft.M365.LENS.CMS.$($Environment).json to point at a real appsettings file."
                }
            } catch { }
            if (-not $CmsAppId) {
                $m = [regex]::Match($raw, '"apiClientId"\s*:\s*"([^"]+)"')
                if ($m.Success) {
                    $CmsAppId = $m.Groups[1].Value
                    Write-Warning "Falling back to apiClientId via regex - see warning above."
                }
            }
            if ($CmsAppId) {
                Write-Host "CMS audience (from Ev2 Microsoft.M365.LENS.CMS.$Environment.json apiClientId): $CmsAppId" -ForegroundColor DarkGray
            }
        }
    }
}
if (-not $CmsAppId) {
    throw "Could not resolve AzureAd.ClientId from $appSettingsPath nor via aspNetCoreEnvironment redirect nor apiClientId from Ev2 config Microsoft.M365.LENS.CMS.$Environment.json. Do NOT fall back to a stale hardcoded audience."
}

$ResourceGroup = "rg-lenscms-$Environment-westus3"
$Region = "westus3"
$ContainerName = "aci-cms-test-$Environment"
$MiName = "id-lenscmsapi-$Environment-$Region"
$VnetName = "vnet-lenscms-$Environment-$Region"
$SubnetName = $null  # Resolved dynamically in Step 2
$TestScriptName = switch ($Suite) {
    "golden-records" { "Test-CmsApi-FullField-ACI.sh" }
    "dump-golden"    { "Dump-GoldenRecords-ACI.sh" }
    "augment-golden" { "Augment-GoldenRecords-ACI.sh" }
    default          { "Test-CmsApi-ACI.sh" }
}
$TestScript = Join-Path $PSScriptRoot $TestScriptName
$Image = "mcr.microsoft.com/azure-cli:latest"
$MaxPollSeconds = switch ($Suite) {
    "full"           { 2400 }
    "observability"  { 1200 }
    "cross-milestone" { 900 }
    "golden-records" { 1200 }
    default          { 600 }
}
$PollIntervalSeconds = 15

Write-Host ""
Write-Host "=== E2E Test via ACI ===" -ForegroundColor Cyan
Write-Host "Environment:  $Environment"
Write-Host "Container:    $ContainerName"
Write-Host "Resource Group: $ResourceGroup"
Write-Host "Suite:          $Suite"
Write-Host ""

# --- Step 1: Resolve identity ---
Write-Host "--- Step 1: Resolve managed identity ---" -ForegroundColor Yellow
$mi = az identity show `
    --name $MiName `
    --resource-group $ResourceGroup `
    --subscription $SubscriptionId `
    --query "{id: id, clientId: clientId}" `
    --output json 2>&1 | ConvertFrom-Json

if (-not $mi.id) {
    Write-Error "Could not find managed identity '$MiName' in '$ResourceGroup'"
}
Write-Host "MI Resource ID: $($mi.id)" -ForegroundColor Green
Write-Host "MI Client ID:   $($mi.clientId)" -ForegroundColor Green

# Resolve Cosmos endpoint and App Insights app ID for verification steps
$CosmosEndpoint = "https://cosmos-lenscms-$Environment-$Region.documents.azure.com:443"
$AppInsightsAppId = az monitor app-insights component show `
    --app "appi-lenscms-$Environment-$Region" `
    --resource-group $ResourceGroup `
    --subscription $SubscriptionId `
    --query "appId" -o tsv 2>&1
Write-Host "Cosmos:         $CosmosEndpoint" -ForegroundColor Green
Write-Host "App Insights:   $AppInsightsAppId" -ForegroundColor Green

# --- Step 2: Resolve subnet ---
Write-Host ""
Write-Host "--- Step 2: Resolve ACI subnet ---" -ForegroundColor Yellow
# Dynamically find the ACI subnet (naming varies: snet-aci vs snet-aci-{env}-{region})
$allSubnets = az network vnet subnet list `
    --vnet-name $VnetName `
    --resource-group $ResourceGroup `
    --subscription $SubscriptionId `
    --query "[].name" -o tsv 2>&1

$SubnetName = ($allSubnets -split "`n" | Where-Object { $_ -match "aci" } | Select-Object -First 1).Trim()
if (-not $SubnetName) {
    Write-Error "Could not find an ACI subnet in VNet '$VnetName'. Available: $allSubnets"
}

$subnetId = az network vnet subnet show `
    --name $SubnetName `
    --vnet-name $VnetName `
    --resource-group $ResourceGroup `
    --subscription $SubscriptionId `
    --query "id" -o tsv 2>&1

if (-not $subnetId -or $subnetId -like "*ERROR*") {
    Write-Error "Could not find subnet '$SubnetName' in VNet '$VnetName'"
}
Write-Host "Subnet:    $SubnetName" -ForegroundColor Green
Write-Host "Subnet ID: $subnetId" -ForegroundColor Green

# --- Step 3: Delete existing container (if any) ---
Write-Host ""
Write-Host "--- Step 3: Delete existing container (if any) ---" -ForegroundColor Yellow
$existing = $null
try { $existing = az container show --name $ContainerName --resource-group $ResourceGroup --subscription $SubscriptionId --query "name" -o tsv 2>$null } catch { }
if ($existing) {
    if ($PSCmdlet.ShouldProcess($ContainerName, "Delete existing ACI container")) {
        az container delete --name $ContainerName --resource-group $ResourceGroup --subscription $SubscriptionId --yes 2>&1 | Out-Null
        Write-Host "Deleted existing container." -ForegroundColor DarkYellow
    }
} else {
    Write-Host "No existing container found." -ForegroundColor DarkYellow
}

# --- Step 4: Base64-encode test script ---
# Split into chunks to avoid Linux ARG_MAX (~128K with env+argv combined) when the
# decoded script approaches 100KB. Each env var holds up to $ChunkSize chars of the
# base64-encoded payload; the container command concatenates them back with `bash -c`.
Write-Host ""
Write-Host "--- Step 4: Encode test script ---" -ForegroundColor Yellow
if (-not (Test-Path $TestScript)) {
    Write-Error "Test script not found at $TestScript"
}
$b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Content $TestScript -Raw)))
$ChunkSize = 30000  # safe well under per-env-var limits; ARG_MAX budget headroom
$chunks = @()
for ($i = 0; $i -lt $b64.Length; $i += $ChunkSize) {
    $len = [Math]::Min($ChunkSize, $b64.Length - $i)
    $chunks += $b64.Substring($i, $len)
}
Write-Host "Encoded $TestScript ($($b64.Length) chars in $($chunks.Count) chunk(s))" -ForegroundColor Green

# --- Step 5: Create ACI container ---
Write-Host ""
Write-Host "--- Step 5: Create ACI container ---" -ForegroundColor Yellow

if ($PSCmdlet.ShouldProcess($ContainerName, "Create ACI container with embedded test script")) {
    # Use az rest with JSON body file to avoid:
    #   1. Windows command-line length limit (base64 test script ~7744 chars)
    #   2. YAML --file not injecting IDENTITY_ENDPOINT/IDENTITY_HEADER env vars
    # Build env vars array dynamically — base64 chunks are injected as
    # TEST_SCRIPT_B64_1, TEST_SCRIPT_B64_2, ... to fit under Linux ARG_MAX.
    $envVars = [System.Collections.ArrayList]::new()
    [void]$envVars.Add(@{ name = "CLIENT_ID"; value = $mi.clientId })
    [void]$envVars.Add(@{ name = "BASE_URL"; value = "https://app-lenscmsapi-$Environment-$Region.azurewebsites.net" })
    [void]$envVars.Add(@{ name = "RESOURCE"; value = "api://$CmsAppId" })
    [void]$envVars.Add(@{ name = "COSMOS_ENDPOINT"; value = $CosmosEndpoint })
    [void]$envVars.Add(@{ name = "APPINSIGHTS_APPID"; value = $AppInsightsAppId })
    [void]$envVars.Add(@{ name = "SUITE"; value = $Suite })
    [void]$envVars.Add(@{ name = "TEST_SCRIPT_CHUNKS"; value = [string]$chunks.Count })
    for ($k = 0; $k -lt $chunks.Count; $k++) {
        $idx = $k + 1
        [void]$envVars.Add(@{ name = "TEST_SCRIPT_B64_$idx"; value = $chunks[$k] })
    }

    $aciBody = @{
        location = $Region
        identity = @{
            type = "UserAssigned"
            userAssignedIdentities = @{
                $mi.id = @{}
            }
        }
        properties = @{
            subnetIds = @(
                @{ id = $subnetId }
            )
            restartPolicy = "Never"
            osType = "Linux"
            containers = @(
                @{
                    name = $ContainerName
                    properties = @{
                        image = $Image
                        resources = @{
                            requests = @{
                                cpu = 1
                                memoryInGb = 1
                            }
                        }
                        environmentVariables = @($envVars)
                        command = @("bash", "-c", 'n="$TEST_SCRIPT_CHUNKS"; for i in $(seq 1 "$n"); do v="TEST_SCRIPT_B64_$i"; printf "%s" "${!v}"; done | base64 -d | tr -d "\r" | bash')
                    }
                }
            )
        }
    }

    $jsonPath = "$env:TEMP\aci-cms-test-$Environment.json"
    $aciBody | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding utf8

    $aciUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ContainerInstance/containerGroups/${ContainerName}?api-version=2023-05-01"
    az rest --method PUT --url $aciUrl --body "@$jsonPath" --output none 2>&1

    Remove-Item $jsonPath -ErrorAction SilentlyContinue

    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to create ACI container"
    }
    Write-Host "Container created." -ForegroundColor Green
} else {
    Write-Host "WHATIF: Would create container '$ContainerName' with:" -ForegroundColor DarkYellow
    Write-Host "  Image:    $Image" -ForegroundColor DarkYellow
    Write-Host "  Subnet:   $subnetId" -ForegroundColor DarkYellow
    Write-Host "  Identity: $($mi.id)" -ForegroundColor DarkYellow
    Write-Host "  Client:   $($mi.clientId)" -ForegroundColor DarkYellow
    Write-Host ""
    Write-Host "=== DRY RUN COMPLETE ===" -ForegroundColor Cyan
    exit 0
}

# --- Step 6: Poll for completion ---
Write-Host ""
Write-Host "--- Step 6: Waiting for tests to complete ---" -ForegroundColor Yellow
$elapsed = 0
$state = "Running"

while ($state -eq "Running" -or $state -eq "Waiting" -or $state -eq "Pending") {
    Start-Sleep -Seconds $PollIntervalSeconds
    $elapsed += $PollIntervalSeconds

    $state = az container show `
        --name $ContainerName `
        --resource-group $ResourceGroup `
        --subscription $SubscriptionId `
        --query "instanceView.state" -o tsv 2>&1

    $mins = [math]::Floor($elapsed / 60)
    $secs = $elapsed % 60
    $color = if ($state -eq "Succeeded") { "Green" } elseif ($state -eq "Failed") { "Red" } else { "DarkYellow" }
    Write-Host "  [${mins}m ${secs}s] State: $state" -ForegroundColor $color

    if ($elapsed -ge $MaxPollSeconds) {
        Write-Host "  Timed out after ${MaxPollSeconds}s" -ForegroundColor Red
        break
    }
}

# --- Step 6b: Read container exit code (before cleanup deletes it) ---
$containerExitCode = $null
if ($state -eq "Succeeded" -or $state -eq "Failed" -or $state -eq "Terminated") {
    try {
        $exitCodeRaw = az container show `
            --name $ContainerName `
            --resource-group $ResourceGroup `
            --subscription $SubscriptionId `
            --query "containers[0].instanceView.currentState.exitCode" -o tsv 2>&1
        if ($exitCodeRaw -match '^\d+$') { $containerExitCode = [int]$exitCodeRaw }
    } catch { }
    $ecColor = if ($containerExitCode -eq 0) { "Green" } elseif ($containerExitCode -eq 2) { "Yellow" } else { "Red" }
    Write-Host "  Container exit code: $containerExitCode" -ForegroundColor $ecColor
}

# --- Step 7: Get logs ---
Write-Host ""
Write-Host "--- Step 7: Test output ---" -ForegroundColor Yellow
$logs = az container logs `
    --name $ContainerName `
    --resource-group $ResourceGroup `
    --subscription $SubscriptionId 2>&1

Write-Host $logs

# --- Step 8: Cleanup ---
if (-not $SkipCleanup) {
    Write-Host ""
    Write-Host "--- Step 8: Cleanup ---" -ForegroundColor Yellow
    az container delete --name $ContainerName --resource-group $ResourceGroup --subscription $SubscriptionId --yes 2>&1 | Out-Null
    Write-Host "Container deleted." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "--- Skipping cleanup (use -SkipCleanup to retain container) ---" -ForegroundColor DarkYellow
}

# --- Result ---
Write-Host ""
if ($null -eq $containerExitCode) {
    Write-Host "=== E2E TESTS INCONCLUSIVE (state: $state) ===" -ForegroundColor Yellow
    exit 2
} elseif ($containerExitCode -eq 0) {
    Write-Host "=== E2E TESTS PASSED (Suite: $Suite) ===" -ForegroundColor Green
    exit 0
} elseif ($containerExitCode -eq 2) {
    Write-Host "=== E2E TESTS SKIPPED-CRITICAL (Suite: $Suite) ===" -ForegroundColor Yellow
    Write-Host "Some critical tests were skipped. Review test output above."
    exit 2
} else {
    Write-Host "=== E2E TESTS FAILED (Suite: $Suite, exit code: $containerExitCode) ===" -ForegroundColor Red
    Write-Host "Review test output above for details."
    exit 1
}
