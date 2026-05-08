<#
.SYNOPSIS
    Deploy LRMS backend (and optionally frontend) to Azure App Service.

.DESCRIPTION
    Configures app settings (Cosmos, App Insights, CMS API, MI), publishes the .NET 10
    backend API, and optionally builds/deploys the frontend. Performs health check after
    deployment with retries.

.PARAMETER Environment
    Target environment: tonym

.PARAMETER BackendOnly
    Skip frontend deployment

.PARAMETER FrontendOnly
    Skip backend deployment

.PARAMETER LrmsSourcePath
    Path to LRMS source code (required)

.PARAMETER WhatIf
    Show what would be deployed without making changes

.EXAMPLE
    .\Deploy-Lrms.ps1 -Environment tonym -LrmsSourcePath "C:/source/LENS-LRMS"
    .\Deploy-Lrms.ps1 -Environment tonym -LrmsSourcePath "C:/source/LENS-LRMS" -BackendOnly
    .\Deploy-Lrms.ps1 -Environment tonym -LrmsSourcePath "C:/source/LENS-LRMS" -FrontendOnly
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet("tonym")]
    [string]$Environment,

    [switch]$BackendOnly,

    [switch]$FrontendOnly,

    [Parameter(Mandatory)]
    [string]$LrmsSourcePath
)

$ErrorActionPreference = "Stop"

# --- Constants ---
$SubscriptionId = "d27c8315-7947-43ea-88ed-1f1c34860559"
$Region = "westus3"
$LrmsRg = "rg-lenslrms-$Environment"
$AppName = "app-lrms-$Environment-$Region"
$MiName = "id-lrms-$Environment"
$CosmosName = "cosmos-lrms-$Environment-$Region"
$CosmosDb = "lrmsportal"
$AppInsightsName = "appi-lrms-$Environment"
$CmsAppName = "app-cms-$Environment-$Region"
$CmsResourceUri = 'api://6c5a00ce-8062-49d8-b568-b9bd0363340b'
$StorageName = "stlrms$Environment"

$WebClientAppName = "webclient-lrms-$Environment-$Region"
$ApiProject = "sources/dev/WebApi/src/API/API.csproj"
$WebClientDir = "sources/dev/WebClient"
$PublishDir = "$LrmsSourcePath/publish-output"
$ZipPath = "$LrmsSourcePath/deploy.zip"

$HealthCheckRetries = 3
$HealthCheckWaitSeconds = 10

Write-Host ""
Write-Host "=== LRMS Deployment ===" -ForegroundColor Cyan
Write-Host "Environment:    $Environment"
Write-Host "App Service:    $AppName"
Write-Host "Source Path:    $LrmsSourcePath"
Write-Host "Backend:        $(-not $FrontendOnly)"
Write-Host "Frontend:       $(-not $BackendOnly)"
Write-Host ""

# --- Validate source path ---
if (-not (Test-Path $LrmsSourcePath)) {
    Write-Error "LRMS source path not found: $LrmsSourcePath"
}

# --- Helper: Run az CLI with exit code checking ---
function Invoke-AzCli {
    param(
        [Parameter(Mandatory)]
        [string[]]$ArgumentList,
        [switch]$JsonOutput,
        [switch]$AllowFailure
    )
    $ErrorActionPreference = 'Continue'
    $rawOutput = & az @ArgumentList 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'

    if ($exitCode -ne 0 -and -not $AllowFailure) {
        $errorText = ($rawOutput | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }) -join "`n"
        if (-not $errorText) { $errorText = $rawOutput -join "`n" }
        throw "az CLI failed (exit $exitCode): $errorText"
    }

    if ($JsonOutput -and $exitCode -eq 0) {
        $jsonLines = $rawOutput | Where-Object { $_ -notmatch '^\s*(WARNING|INFO|DEBUG):' }
        return ($jsonLines | ConvertFrom-Json)
    }

    return $rawOutput
}

# --- Step 1: Configure App Settings ---
if ($FrontendOnly) {
    Write-Host "--- Step 1: Configure App Settings (SKIPPED - FrontendOnly) ---" -ForegroundColor DarkYellow
} else {
Write-Host "--- Step 1: Configure App Settings ---" -ForegroundColor Yellow

# Read MI client ID
$mi = Invoke-AzCli -ArgumentList @(
    'identity', 'show',
    '--name', $MiName,
    '--resource-group', $LrmsRg,
    '--subscription', $SubscriptionId,
    '--query', '{clientId: clientId}',
    '--output', 'json'
) -JsonOutput

if (-not $mi.clientId) {
    Write-Error "Could not find managed identity '$MiName' in '$LrmsRg'"
}
Write-Host "  MI Client ID: $($mi.clientId)" -ForegroundColor Green

# Read App Insights connection string
$appi = Invoke-AzCli -ArgumentList @(
    'monitor', 'app-insights', 'component', 'show',
    '--app', $AppInsightsName,
    '--resource-group', $LrmsRg,
    '--subscription', $SubscriptionId,
    '--query', '{connectionString: connectionString}',
    '--output', 'json'
) -JsonOutput

if (-not $appi.connectionString) {
    Write-Host "  WARNING: Could not read App Insights connection string" -ForegroundColor Red
    $appiConnStr = ''
} else {
    $appiConnStr = $appi.connectionString
    Write-Host "  App Insights: connected" -ForegroundColor Green
}

$cosmosEndpoint = "https://$CosmosName.documents.azure.com:443/"
$cmsBaseUrl = "https://$CmsAppName.azurewebsites.net"

Write-Host "  Cosmos Endpoint: $cosmosEndpoint" -ForegroundColor Green
Write-Host "  CMS Base URL:    $cmsBaseUrl" -ForegroundColor Green

if ($PSCmdlet.ShouldProcess($AppName, "Configure app settings")) {
    # Build settings as key=value pairs
    $settings = @(
        "ASPNETCORE_ENVIRONMENT=$Environment",
        "AZURE_CLIENT_ID=$($mi.clientId)",
        "AzureAd__ClientCredentials__0__ManagedIdentityClientId=$($mi.clientId)",
        "ExternalServices__CosmosDb__AccountEndpoint=$cosmosEndpoint",
        "ExternalServices__CosmosDb__DatabaseName=$CosmosDb",
        "APPLICATIONINSIGHTS_CONNECTION_STRING=$appiConnStr",
        "ExternalServices__CaseManagement__Endpoint=$cmsBaseUrl",
        "ExternalServices__CaseManagement__AuthTokenType=ManagedIdentity",
        "ExternalServices__CaseManagement__ResourceUri=$CmsResourceUri",
        "ExternalServices__BlobStorage__AccountName=$StorageName",
        "ExternalServices__BlobStorage__AccountUrl=https://$StorageName.blob.core.windows.net",
        "ExternalServices__BlobStorage__ContainerName=lrmsportal"
    )

    $settingsArgs = @(
        'webapp', 'config', 'appsettings', 'set',
        '--name', $AppName,
        '--resource-group', $LrmsRg,
        '--subscription', $SubscriptionId,
        '--settings'
    ) + $settings

    Invoke-AzCli -ArgumentList $settingsArgs | Out-Null
    Write-Host "  CONFIGURED: $($settings.Count) app settings" -ForegroundColor Green
}
} # end if (-not $FrontendOnly)
Write-Host ""

# --- Step 2: Build & Deploy Backend ---
if (-not $FrontendOnly) {
    Write-Host "--- Step 2: Build & Deploy Backend ---" -ForegroundColor Yellow

    $apiProjectPath = Join-Path $LrmsSourcePath $ApiProject
    if (-not (Test-Path $apiProjectPath)) {
        Write-Error "API project not found: $apiProjectPath"
    }

    if ($PSCmdlet.ShouldProcess($apiProjectPath, "dotnet publish")) {
        # Clean previous publish output
        if (Test-Path $PublishDir) {
            Remove-Item $PublishDir -Recurse -Force
        }

        Write-Host "  Publishing .NET project..." -ForegroundColor DarkYellow
        $ErrorActionPreference = 'Continue'
        dotnet publish $apiProjectPath `
            --configuration Release `
            --output $PublishDir `
            --no-restore
        $dotnetExit = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'

        if ($dotnetExit -ne 0) {
            # Retry with restore
            Write-Host "  Retrying with restore..." -ForegroundColor DarkYellow
            $ErrorActionPreference = 'Continue'
            dotnet publish $apiProjectPath `
                --configuration Release `
                --output $PublishDir
            $dotnetExit = $LASTEXITCODE
            $ErrorActionPreference = 'Stop'

            if ($dotnetExit -ne 0) {
                Write-Error "dotnet publish failed with exit code $dotnetExit"
            }
        }

        Write-Host "  Published to $PublishDir" -ForegroundColor Green
    }

    # Create zip
    if ($PSCmdlet.ShouldProcess($ZipPath, "Create deployment zip")) {
        if (Test-Path $ZipPath) {
            Remove-Item $ZipPath -Force
        }

        Write-Host "  Creating deployment zip..." -ForegroundColor DarkYellow
        Compress-Archive -Path "$PublishDir/*" -DestinationPath $ZipPath -Force
        $zipSize = [math]::Round((Get-Item $ZipPath).Length / 1MB, 2)
        Write-Host "  ZIP created: $ZipPath ($zipSize MB)" -ForegroundColor Green
    }

    # Deploy via Kudu ZIP deploy API (avoids basicPublishingCredentialsPolicies/read permission requirement)
    if ($PSCmdlet.ShouldProcess($AppName, "Deploy backend zip")) {
        Write-Host "  Deploying to $AppName via Kudu API..." -ForegroundColor DarkYellow
        $token = (Invoke-AzCli -ArgumentList @('account', 'get-access-token', '--resource', 'https://management.azure.com/', '--query', 'accessToken', '-o', 'tsv'))
        $kuduUrl = "https://$AppName.scm.azurewebsites.net/api/zipdeploy?isAsync=false"
        $ErrorActionPreference = 'Continue'
        curl.exe -s -w "`nHTTP_STATUS: %{http_code}" -X POST `
            -H "Authorization: Bearer $token" `
            -H "Content-Type: application/zip" `
            --data-binary "@$ZipPath" `
            $kuduUrl 2>&1 | ForEach-Object {
                if ($_ -match 'HTTP_STATUS: (\d+)') {
                    if ($Matches[1] -ne '200') {
                        $ErrorActionPreference = 'Stop'
                        throw "Kudu deploy failed with HTTP $($Matches[1])"
                    }
                }
            }
        $ErrorActionPreference = 'Stop'
        Write-Host "  DEPLOYED: Backend to $AppName" -ForegroundColor Green
    }
} else {
    Write-Host "--- Step 2: Backend (SKIPPED - FrontendOnly) ---" -ForegroundColor DarkYellow
}
Write-Host ""

# --- Step 3: Build & Deploy Frontend ---
if (-not $BackendOnly) {
    Write-Host "--- Step 3: Build & Deploy Frontend ---" -ForegroundColor Yellow

    $clientDir = Join-Path $LrmsSourcePath $WebClientDir
    if (-not (Test-Path $clientDir)) {
        Write-Host "  WARNING: WebClient directory not found at $clientDir" -ForegroundColor Red
        Write-Host "  Skipping frontend deployment" -ForegroundColor DarkYellow
    } else {
        if ($PSCmdlet.ShouldProcess($clientDir, "pnpm build")) {
            # Ensure pnpm is on PATH (npm global bin may not be in PowerShell PATH)
            # Note: -notlike "*$npmGlobalBin*" can false-match on subdirectories (e.g., npm/claude)
            # so we check for the exact pnpm.cmd instead
            $npmGlobalBin = Join-Path $env:APPDATA "npm"
            $pnpmCmd = Join-Path $npmGlobalBin "pnpm.cmd"
            if ((Test-Path $pnpmCmd) -and -not (Get-Command pnpm -ErrorAction SilentlyContinue)) {
                $env:PATH = "$env:PATH;$npmGlobalBin"
                Write-Host "  Added npm global bin to PATH: $npmGlobalBin" -ForegroundColor DarkYellow
            }

            Write-Host "  Installing dependencies..." -ForegroundColor DarkYellow
            $ErrorActionPreference = 'Continue'

            Push-Location $clientDir
            # --ignore-scripts: skip preinstall hooks (e.g. artifacts-npm-credprovider)
            # that require tools not available in all PowerShell contexts
            pnpm install --frozen-lockfile --ignore-scripts
            $pnpmInstallExit = $LASTEXITCODE

            if ($pnpmInstallExit -ne 0) {
                Write-Host "  WARNING: pnpm install failed (exit $pnpmInstallExit), trying without --frozen-lockfile" -ForegroundColor DarkYellow
                pnpm install --ignore-scripts
                $pnpmInstallExit = $LASTEXITCODE
            }

            if ($pnpmInstallExit -ne 0) {
                Pop-Location
                $ErrorActionPreference = 'Stop'
                Write-Error "pnpm install failed with exit code $pnpmInstallExit"
            }

            Write-Host "  Building frontend (mode=$Environment)..." -ForegroundColor DarkYellow
            npx vite build --mode $Environment
            $pnpmBuildExit = $LASTEXITCODE
            Pop-Location
            $ErrorActionPreference = 'Stop'

            if ($pnpmBuildExit -ne 0) {
                Write-Error "pnpm build failed with exit code $pnpmBuildExit"
            }

            $distDir = Join-Path $clientDir "dist"
            if (Test-Path $distDir) {
                # Copy dist into publish output wwwroot
                $wwwrootDist = Join-Path $PublishDir "wwwroot"
                if (-not (Test-Path $wwwrootDist)) {
                    New-Item -ItemType Directory -Path $wwwrootDist -Force | Out-Null
                }
                Copy-Item -Path "$distDir/*" -Destination $wwwrootDist -Recurse -Force
                Write-Host "  Frontend dist copied to wwwroot" -ForegroundColor Green

                # Re-zip and re-deploy if backend was also deployed
                if (-not $FrontendOnly) {
                    Write-Host "  Re-creating deployment zip with frontend..." -ForegroundColor DarkYellow
                    if (Test-Path $ZipPath) {
                        Remove-Item $ZipPath -Force
                    }
                    Compress-Archive -Path "$PublishDir/*" -DestinationPath $ZipPath -Force
                    $zipSize = [math]::Round((Get-Item $ZipPath).Length / 1MB, 2)
                    Write-Host "  ZIP updated: $ZipPath ($zipSize MB)" -ForegroundColor Green

                    Write-Host "  Re-deploying with frontend via Kudu API..." -ForegroundColor DarkYellow
                    $token = (Invoke-AzCli -ArgumentList @('account', 'get-access-token', '--resource', 'https://management.azure.com/', '--query', 'accessToken', '-o', 'tsv'))
                    $kuduUrl = "https://$AppName.scm.azurewebsites.net/api/zipdeploy?isAsync=false"
                    $ErrorActionPreference = 'Continue'
                    curl.exe -s -w "`nHTTP_STATUS: %{http_code}" -X POST `
                        -H "Authorization: Bearer $token" `
                        -H "Content-Type: application/zip" `
                        --data-binary "@$ZipPath" `
                        $kuduUrl 2>&1 | ForEach-Object {
                            if ($_ -match 'HTTP_STATUS: (\d+)') {
                                if ($Matches[1] -ne '200') {
                                    $ErrorActionPreference = 'Stop'
                                    throw "Kudu deploy failed with HTTP $($Matches[1])"
                                }
                            }
                        }
                    $ErrorActionPreference = 'Stop'
                    Write-Host "  DEPLOYED: Backend + Frontend to $AppName" -ForegroundColor Green
                } else {
                    # Frontend-only: zip and deploy to the BFF app service (NOT webclient)
                    # The BFF serves the SPA from wwwroot and proxies API calls
                    $feZipPath = "$LrmsSourcePath/deploy-frontend.zip"
                    if (Test-Path $feZipPath) {
                        Remove-Item $feZipPath -Force
                    }
                    Compress-Archive -Path "$distDir/*" -DestinationPath $feZipPath -Force
                    $feZipSize = [math]::Round((Get-Item $feZipPath).Length / 1MB, 2)
                    Write-Host "  Frontend ZIP: $feZipPath ($feZipSize MB)" -ForegroundColor Green

                    Write-Host "  Deploying frontend to $AppName (BFF) via Kudu API..." -ForegroundColor DarkYellow
                    $token = (Invoke-AzCli -ArgumentList @('account', 'get-access-token', '--resource', 'https://management.azure.com/', '--query', 'accessToken', '-o', 'tsv'))
                    $kuduUrl = "https://$AppName.scm.azurewebsites.net/api/zipdeploy?isAsync=false"
                    $ErrorActionPreference = 'Continue'
                    curl.exe -s -w "`nHTTP_STATUS: %{http_code}" -X POST `
                        -H "Authorization: Bearer $token" `
                        -H "Content-Type: application/zip" `
                        --data-binary "@$feZipPath" `
                        $kuduUrl 2>&1 | ForEach-Object {
                            if ($_ -match 'HTTP_STATUS: (\d+)') {
                                if ($Matches[1] -ne '200') {
                                    $ErrorActionPreference = 'Stop'
                                    throw "Kudu deploy failed with HTTP $($Matches[1])"
                                }
                            }
                        }
                    $ErrorActionPreference = 'Stop'
                    Write-Host "  DEPLOYED: Frontend to $AppName" -ForegroundColor Green
                }
            } else {
                Write-Host "  WARNING: dist directory not found after build at $distDir" -ForegroundColor Red
            }
        }
    }
} else {
    Write-Host "--- Step 3: Frontend (SKIPPED - BackendOnly) ---" -ForegroundColor DarkYellow
}
Write-Host ""

# --- Step 4: Health Check ---
Write-Host "--- Step 4: Health Check ---" -ForegroundColor Yellow

$appUrl = "https://$AppName.azurewebsites.net"
$healthUrl = "$appUrl/api/health"

Write-Host "  Checking: $healthUrl" -ForegroundColor DarkYellow

$healthy = $false
for ($attempt = 1; $attempt -le $HealthCheckRetries; $attempt++) {
    Write-Host "  Attempt $attempt/$HealthCheckRetries..." -ForegroundColor DarkYellow

    try {
        $response = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing -TimeoutSec 15 -ErrorAction SilentlyContinue
        if ($response.StatusCode -eq 200) {
            $healthy = $true
            Write-Host "  HEALTHY: $healthUrl returned 200" -ForegroundColor Green
            break
        } else {
            Write-Host "  Status: $($response.StatusCode) - retrying..." -ForegroundColor DarkYellow
        }
    } catch {
        Write-Host "  Error: $($_.Exception.Message) - retrying..." -ForegroundColor DarkYellow
    }

    if ($attempt -lt $HealthCheckRetries) {
        Write-Host "  Waiting ${HealthCheckWaitSeconds}s..." -ForegroundColor DarkYellow
        Start-Sleep -Seconds $HealthCheckWaitSeconds
    }
}

Write-Host ""

# --- Summary ---
Write-Host "=== Deployment Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Backend:        $AppName"
Write-Host "Backend URL:    $appUrl"
if (-not $BackendOnly) {
    Write-Host "Frontend:       $WebClientAppName"
    Write-Host "Frontend URL:   https://$WebClientAppName.azurewebsites.net"
}
Write-Host "Health:         $(if ($healthy) { 'HEALTHY' } else { 'UNHEALTHY - check logs' })"
Write-Host ""

if ($healthy) {
    Write-Host "=== DEPLOYMENT SUCCEEDED ===" -ForegroundColor Green
} else {
    Write-Host "=== DEPLOYMENT COMPLETED (health check failed) ===" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Troubleshooting:" -ForegroundColor Yellow
    Write-Host "  1. Check logs:   az webapp log tail --name $AppName --resource-group $LrmsRg --subscription $SubscriptionId"
    Write-Host "  2. Check config: az webapp config appsettings list --name $AppName --resource-group $LrmsRg --subscription $SubscriptionId"
    Write-Host "  3. App URL:      $appUrl"
    Write-Host ""
    exit 1
}

Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Test API:    curl $appUrl/api/v1/health"
Write-Host "  2. Check logs:  az webapp log tail --name $AppName --resource-group $LrmsRg --subscription $SubscriptionId"
Write-Host ""
