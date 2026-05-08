<#
.SYNOPSIS
    Provision Azure infrastructure for LRMS in the tonym environment. Idempotent - checks
    if resources exist before creating them.

.DESCRIPTION
    Creates all Azure resources needed for LRMS: resource group, managed identity, subnets
    (in the CMS VNet), App Service, Cosmos DB (serverless), private endpoint, blob storage,
    and Application Insights. Assigns Cosmos RBAC to the managed identity.

.PARAMETER Environment
    Target environment: tonym

.PARAMETER WhatIf
    Show what would be created without making changes

.PARAMETER SkipCosmos
    Skip Cosmos DB provisioning (if already exists)

.PARAMETER SkipNetwork
    Skip VNet/subnet/PE provisioning (if already exists)

.EXAMPLE
    .\Provision-LrmsInfra.ps1 -Environment tonym
    .\Provision-LrmsInfra.ps1 -Environment tonym -WhatIf
    .\Provision-LrmsInfra.ps1 -Environment tonym -SkipCosmos -SkipNetwork
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidateSet("tonym")]
    [string]$Environment,

    [switch]$SkipCosmos,

    [switch]$SkipNetwork
)

$ErrorActionPreference = "Stop"

# --- Constants ---
$SubscriptionId = "d27c8315-7947-43ea-88ed-1f1c34860559"
$Region = "westus3"
$LrmsRg = "rg-lenslrms-$Environment"
$CmsRg = "rg-lenscms-$Environment"
$MiName = "id-lrms-$Environment"
$VnetName = "vnet-cms-$Environment-$Region"
$AppSubnet = "snet-lrms-app"
$PeSubnet = "snet-lrms-pe"
$AppSubnetCidr = "10.1.4.0/24"
$PeSubnetCidr = "10.1.5.0/24"
$PlanName = "plan-lrms-$Environment"
$AppName = "app-lrms-$Environment-$Region"
$CosmosName = "cosmos-lrms-$Environment-$Region"
$CosmosDb = "lrmsportal"
$PeName = "pe-cosmos-lrms-$Environment"
$DnsZoneName = "privatelink.documents.azure.com"
$StorageName = "stlrms$Environment"
$AppInsightsName = "appi-lrms-$Environment"
$CosmosDataContributorRole = "00000000-0000-0000-0000-000000000002"

# Cosmos containers: name -> partition key
$CosmosContainers = @{
    'requests'           = '/id'
    'registrations'      = '/id'
    'verification-codes' = '/id'
    'session-state'      = '/id'
}

# Collected outputs
$OutputValues = @{}

Write-Host ""
Write-Host "=== LRMS Infrastructure Provisioning ===" -ForegroundColor Cyan
Write-Host "Environment:    $Environment"
Write-Host "Subscription:   $SubscriptionId"
Write-Host "Region:         $Region"
Write-Host "LRMS RG:        $LrmsRg"
Write-Host "CMS RG (VNet):  $CmsRg"
Write-Host ""

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

# --- Step 1: Resource Group ---
Write-Host "--- Step 1: Resource Group ---" -ForegroundColor Yellow

$rgExists = Invoke-AzCli -ArgumentList @('group', 'exists', '--name', $LrmsRg, '--subscription', $SubscriptionId)
if ($rgExists -eq 'true') {
    Write-Host "  SKIP: Resource group '$LrmsRg' already exists" -ForegroundColor DarkYellow
} else {
    if ($PSCmdlet.ShouldProcess($LrmsRg, "Create resource group")) {
        Invoke-AzCli -ArgumentList @(
            'group', 'create',
            '--name', $LrmsRg,
            '--location', $Region,
            '--subscription', $SubscriptionId
        ) | Out-Null
        Write-Host "  CREATED: $LrmsRg" -ForegroundColor Green
    }
}
Write-Host ""

# --- Step 2: Managed Identity ---
Write-Host "--- Step 2: Managed Identity ---" -ForegroundColor Yellow

$miJson = Invoke-AzCli -ArgumentList @(
    'identity', 'show',
    '--name', $MiName,
    '--resource-group', $LrmsRg,
    '--subscription', $SubscriptionId,
    '--query', '{id: id, clientId: clientId, principalId: principalId}',
    '--output', 'json'
) -JsonOutput -AllowFailure

if ($miJson -and $miJson.principalId) {
    Write-Host "  SKIP: Managed identity '$MiName' already exists" -ForegroundColor DarkYellow
} else {
    if ($PSCmdlet.ShouldProcess($MiName, "Create managed identity")) {
        $miJson = Invoke-AzCli -ArgumentList @(
            'identity', 'create',
            '--name', $MiName,
            '--resource-group', $LrmsRg,
            '--location', $Region,
            '--subscription', $SubscriptionId,
            '--query', '{id: id, clientId: clientId, principalId: principalId}',
            '--output', 'json'
        ) -JsonOutput
        Write-Host "  CREATED: $MiName" -ForegroundColor Green
    }
}

if ($miJson) {
    $OutputValues['MiClientId'] = $miJson.clientId
    $OutputValues['MiPrincipalId'] = $miJson.principalId
    $OutputValues['MiResourceId'] = $miJson.id
    Write-Host "  Client ID:    $($miJson.clientId)" -ForegroundColor Green
    Write-Host "  Principal ID: $($miJson.principalId)" -ForegroundColor Green
}
Write-Host ""

# --- Step 3: Subnets in CMS VNet ---
if ($SkipNetwork) {
    Write-Host "--- Step 3: Subnets (SKIPPED) ---" -ForegroundColor DarkYellow
} else {
    Write-Host "--- Step 3: Subnets in CMS VNet ---" -ForegroundColor Yellow

    # App subnet (delegated to Microsoft.Web/serverFarms)
    $appSubnetExists = Invoke-AzCli -ArgumentList @(
        'network', 'vnet', 'subnet', 'show',
        '--name', $AppSubnet,
        '--vnet-name', $VnetName,
        '--resource-group', $CmsRg,
        '--subscription', $SubscriptionId,
        '--query', 'id',
        '--output', 'tsv'
    ) -AllowFailure

    if ($LASTEXITCODE -eq 0 -and $appSubnetExists) {
        Write-Host "  SKIP: Subnet '$AppSubnet' already exists" -ForegroundColor DarkYellow
    } else {
        if ($PSCmdlet.ShouldProcess("$AppSubnet ($AppSubnetCidr)", "Create app subnet with Web delegation")) {
            Invoke-AzCli -ArgumentList @(
                'network', 'vnet', 'subnet', 'create',
                '--name', $AppSubnet,
                '--vnet-name', $VnetName,
                '--resource-group', $CmsRg,
                '--subscription', $SubscriptionId,
                '--address-prefixes', $AppSubnetCidr,
                '--delegations', 'Microsoft.Web/serverFarms'
            ) | Out-Null
            Write-Host "  CREATED: $AppSubnet ($AppSubnetCidr) with Web delegation" -ForegroundColor Green
        }
    }

    # PE subnet (no delegation)
    $peSubnetExists = Invoke-AzCli -ArgumentList @(
        'network', 'vnet', 'subnet', 'show',
        '--name', $PeSubnet,
        '--vnet-name', $VnetName,
        '--resource-group', $CmsRg,
        '--subscription', $SubscriptionId,
        '--query', 'id',
        '--output', 'tsv'
    ) -AllowFailure

    if ($LASTEXITCODE -eq 0 -and $peSubnetExists) {
        Write-Host "  SKIP: Subnet '$PeSubnet' already exists" -ForegroundColor DarkYellow
    } else {
        if ($PSCmdlet.ShouldProcess("$PeSubnet ($PeSubnetCidr)", "Create PE subnet")) {
            Invoke-AzCli -ArgumentList @(
                'network', 'vnet', 'subnet', 'create',
                '--name', $PeSubnet,
                '--vnet-name', $VnetName,
                '--resource-group', $CmsRg,
                '--subscription', $SubscriptionId,
                '--address-prefixes', $PeSubnetCidr
            ) | Out-Null
            Write-Host "  CREATED: $PeSubnet ($PeSubnetCidr)" -ForegroundColor Green
        }
    }
}
Write-Host ""

# --- Step 4: App Service Plan ---
Write-Host "--- Step 4: App Service Plan ---" -ForegroundColor Yellow

$planExists = Invoke-AzCli -ArgumentList @(
    'appservice', 'plan', 'show',
    '--name', $PlanName,
    '--resource-group', $LrmsRg,
    '--subscription', $SubscriptionId,
    '--query', 'id',
    '--output', 'tsv'
) -AllowFailure

if ($LASTEXITCODE -eq 0 -and $planExists) {
    Write-Host "  SKIP: App Service Plan '$PlanName' already exists" -ForegroundColor DarkYellow
} else {
    if ($PSCmdlet.ShouldProcess($PlanName, "Create App Service Plan (B1 Linux)")) {
        Invoke-AzCli -ArgumentList @(
            'appservice', 'plan', 'create',
            '--name', $PlanName,
            '--resource-group', $LrmsRg,
            '--location', $Region,
            '--subscription', $SubscriptionId,
            '--sku', 'B1',
            '--is-linux'
        ) | Out-Null
        Write-Host "  CREATED: $PlanName (B1, Linux)" -ForegroundColor Green
    }
}
Write-Host ""

# --- Step 5: App Service ---
Write-Host "--- Step 5: App Service ---" -ForegroundColor Yellow

$appExists = Invoke-AzCli -ArgumentList @(
    'webapp', 'show',
    '--name', $AppName,
    '--resource-group', $LrmsRg,
    '--subscription', $SubscriptionId,
    '--query', 'id',
    '--output', 'tsv'
) -AllowFailure

if ($LASTEXITCODE -eq 0 -and $appExists) {
    Write-Host "  SKIP: App Service '$AppName' already exists" -ForegroundColor DarkYellow
} else {
    if ($PSCmdlet.ShouldProcess($AppName, "Create App Service (.NET 10, Linux)")) {
        Invoke-AzCli -ArgumentList @(
            'webapp', 'create',
            '--name', $AppName,
            '--resource-group', $LrmsRg,
            '--plan', $PlanName,
            '--subscription', $SubscriptionId,
            '--runtime', 'DOTNETCORE:10.0',
            '--https-only', 'true'
        ) | Out-Null
        Write-Host "  CREATED: $AppName" -ForegroundColor Green
    }
}

# Assign managed identity to app service
if ($miJson -and $miJson.id) {
    Write-Host "  Assigning managed identity to app service..." -ForegroundColor DarkYellow
    if ($PSCmdlet.ShouldProcess($AppName, "Assign MI '$MiName'")) {
        Invoke-AzCli -ArgumentList @(
            'webapp', 'identity', 'assign',
            '--name', $AppName,
            '--resource-group', $LrmsRg,
            '--subscription', $SubscriptionId,
            '--identities', $miJson.id
        ) | Out-Null
        Write-Host "  ASSIGNED: MI '$MiName' to '$AppName'" -ForegroundColor Green
    }
}
Write-Host ""

# --- Step 6: VNet Integration ---
if ($SkipNetwork) {
    Write-Host "--- Step 6: VNet Integration (SKIPPED) ---" -ForegroundColor DarkYellow
} else {
    Write-Host "--- Step 6: VNet Integration ---" -ForegroundColor Yellow

    # Build full subnet resource ID for cross-RG reference
    $appSubnetId = "/subscriptions/$SubscriptionId/resourceGroups/$CmsRg/providers/Microsoft.Network/virtualNetworks/$VnetName/subnets/$AppSubnet"

    if ($PSCmdlet.ShouldProcess($AppName, "Add VNet integration to $AppSubnet")) {
        Invoke-AzCli -ArgumentList @(
            'webapp', 'vnet-integration', 'add',
            '--name', $AppName,
            '--resource-group', $LrmsRg,
            '--subscription', $SubscriptionId,
            '--vnet', $appSubnetId,
            '--subnet', $AppSubnet
        ) -AllowFailure | Out-Null

        if ($LASTEXITCODE -eq 0) {
            Write-Host "  CONFIGURED: VNet integration ($AppSubnet)" -ForegroundColor Green
        } else {
            Write-Host "  NOTE: VNet integration may already be configured (non-fatal)" -ForegroundColor DarkYellow
        }
    }
}
Write-Host ""

# --- Step 7-11: Cosmos DB ---
if ($SkipCosmos) {
    Write-Host "--- Steps 7-11: Cosmos DB (SKIPPED) ---" -ForegroundColor DarkYellow
} else {
    # Step 7: Cosmos account
    Write-Host "--- Step 7: Cosmos DB Account ---" -ForegroundColor Yellow

    $cosmosExists = Invoke-AzCli -ArgumentList @(
        'cosmosdb', 'show',
        '--name', $CosmosName,
        '--resource-group', $LrmsRg,
        '--subscription', $SubscriptionId,
        '--query', 'id',
        '--output', 'tsv'
    ) -AllowFailure

    if ($LASTEXITCODE -eq 0 -and $cosmosExists) {
        Write-Host "  SKIP: Cosmos account '$CosmosName' already exists" -ForegroundColor DarkYellow
    } else {
        if ($PSCmdlet.ShouldProcess($CosmosName, "Create Cosmos DB (serverless, Session consistency)")) {
            Invoke-AzCli -ArgumentList @(
                'cosmosdb', 'create',
                '--name', $CosmosName,
                '--resource-group', $LrmsRg,
                '--location', $Region,
                '--subscription', $SubscriptionId,
                '--capabilities', 'EnableServerless',
                '--default-consistency-level', 'Session',
                '--kind', 'GlobalDocumentDB'
            ) | Out-Null
            Write-Host "  CREATED: $CosmosName (serverless, Session)" -ForegroundColor Green
        }
    }
    Write-Host ""

    # Step 8: Cosmos database
    Write-Host "--- Step 8: Cosmos Database ---" -ForegroundColor Yellow

    $dbExists = Invoke-AzCli -ArgumentList @(
        'cosmosdb', 'sql', 'database', 'show',
        '--name', $CosmosDb,
        '--account-name', $CosmosName,
        '--resource-group', $LrmsRg,
        '--subscription', $SubscriptionId,
        '--query', 'id',
        '--output', 'tsv'
    ) -AllowFailure

    if ($LASTEXITCODE -eq 0 -and $dbExists) {
        Write-Host "  SKIP: Database '$CosmosDb' already exists" -ForegroundColor DarkYellow
    } else {
        if ($PSCmdlet.ShouldProcess($CosmosDb, "Create Cosmos database")) {
            Invoke-AzCli -ArgumentList @(
                'cosmosdb', 'sql', 'database', 'create',
                '--name', $CosmosDb,
                '--account-name', $CosmosName,
                '--resource-group', $LrmsRg,
                '--subscription', $SubscriptionId
            ) | Out-Null
            Write-Host "  CREATED: $CosmosDb" -ForegroundColor Green
        }
    }
    Write-Host ""

    # Step 9: Cosmos containers
    Write-Host "--- Step 9: Cosmos Containers ---" -ForegroundColor Yellow

    foreach ($containerEntry in $CosmosContainers.GetEnumerator()) {
        $containerName = $containerEntry.Key
        $partitionKey = $containerEntry.Value

        $containerExists = Invoke-AzCli -ArgumentList @(
            'cosmosdb', 'sql', 'container', 'show',
            '--name', $containerName,
            '--database-name', $CosmosDb,
            '--account-name', $CosmosName,
            '--resource-group', $LrmsRg,
            '--subscription', $SubscriptionId,
            '--query', 'id',
            '--output', 'tsv'
        ) -AllowFailure

        if ($LASTEXITCODE -eq 0 -and $containerExists) {
            Write-Host "  SKIP: Container '$containerName' already exists" -ForegroundColor DarkYellow
        } else {
            if ($PSCmdlet.ShouldProcess("$containerName (PK: $partitionKey)", "Create Cosmos container")) {
                Invoke-AzCli -ArgumentList @(
                    'cosmosdb', 'sql', 'container', 'create',
                    '--name', $containerName,
                    '--database-name', $CosmosDb,
                    '--account-name', $CosmosName,
                    '--resource-group', $LrmsRg,
                    '--subscription', $SubscriptionId,
                    '--partition-key-path', $partitionKey
                ) | Out-Null
                Write-Host "  CREATED: $containerName (PK: $partitionKey)" -ForegroundColor Green
            }
        }
    }
    Write-Host ""

    # Step 10: Private Endpoint (in CMS RG where VNet lives)
    if (-not $SkipNetwork) {
        Write-Host "--- Step 10: Cosmos Private Endpoint ---" -ForegroundColor Yellow
        Write-Host "  NOTE: PE created in CMS RG ($CmsRg) where VNet lives" -ForegroundColor DarkYellow

        $peExists = Invoke-AzCli -ArgumentList @(
            'network', 'private-endpoint', 'show',
            '--name', $PeName,
            '--resource-group', $CmsRg,
            '--subscription', $SubscriptionId,
            '--query', 'id',
            '--output', 'tsv'
        ) -AllowFailure

        if ($LASTEXITCODE -eq 0 -and $peExists) {
            Write-Host "  SKIP: Private endpoint '$PeName' already exists" -ForegroundColor DarkYellow
        } else {
            # Get Cosmos resource ID
            $cosmosResourceId = Invoke-AzCli -ArgumentList @(
                'cosmosdb', 'show',
                '--name', $CosmosName,
                '--resource-group', $LrmsRg,
                '--subscription', $SubscriptionId,
                '--query', 'id',
                '--output', 'tsv'
            )

            $peSubnetId = "/subscriptions/$SubscriptionId/resourceGroups/$CmsRg/providers/Microsoft.Network/virtualNetworks/$VnetName/subnets/$PeSubnet"

            if ($PSCmdlet.ShouldProcess($PeName, "Create Cosmos private endpoint in $CmsRg")) {
                Invoke-AzCli -ArgumentList @(
                    'network', 'private-endpoint', 'create',
                    '--name', $PeName,
                    '--resource-group', $CmsRg,
                    '--subscription', $SubscriptionId,
                    '--location', $Region,
                    '--vnet-name', $VnetName,
                    '--subnet', $PeSubnet,
                    '--private-connection-resource-id', $cosmosResourceId.Trim(),
                    '--group-ids', 'Sql',
                    '--connection-name', "$PeName-conn"
                ) | Out-Null
                Write-Host "  CREATED: $PeName in $CmsRg" -ForegroundColor Green
            }

            # DNS zone group
            Write-Host "  Linking to DNS zone $DnsZoneName..." -ForegroundColor DarkYellow
            if ($PSCmdlet.ShouldProcess($PeName, "Create DNS zone group")) {
                $dnsZoneId = "/subscriptions/$SubscriptionId/resourceGroups/$CmsRg/providers/Microsoft.Network/privateDnsZones/$DnsZoneName"

                Invoke-AzCli -ArgumentList @(
                    'network', 'private-endpoint', 'dns-zone-group', 'create',
                    '--name', 'default',
                    '--endpoint-name', $PeName,
                    '--resource-group', $CmsRg,
                    '--subscription', $SubscriptionId,
                    '--private-dns-zone', $dnsZoneId,
                    '--zone-name', 'cosmos'
                ) | Out-Null
                Write-Host "  LINKED: DNS zone group to $DnsZoneName" -ForegroundColor Green
            }
        }
        Write-Host ""

        # Step 11: Disable Cosmos public access
        Write-Host "--- Step 11: Disable Cosmos Public Access ---" -ForegroundColor Yellow
        if ($PSCmdlet.ShouldProcess($CosmosName, "Disable public network access")) {
            Invoke-AzCli -ArgumentList @(
                'cosmosdb', 'update',
                '--name', $CosmosName,
                '--resource-group', $LrmsRg,
                '--subscription', $SubscriptionId,
                '--public-network-access', 'DISABLED'
            ) | Out-Null
            Write-Host "  DISABLED: Public network access on $CosmosName" -ForegroundColor Green
        }
    } else {
        Write-Host "--- Steps 10-11: Private Endpoint / Public Access (SKIPPED - SkipNetwork) ---" -ForegroundColor DarkYellow
    }
    Write-Host ""
}

# --- Step 12: Cosmos RBAC ---
if (-not $SkipCosmos -and $miJson -and $miJson.principalId) {
    Write-Host "--- Step 12: Cosmos RBAC ---" -ForegroundColor Yellow

    if ($PSCmdlet.ShouldProcess("$CosmosName -> $MiName", "Assign Cosmos Built-in Data Contributor")) {
        # Check for existing assignment (idempotency)
        $existingRoles = Invoke-AzCli -ArgumentList @(
            'cosmosdb', 'sql', 'role', 'assignment', 'list',
            '--account-name', $CosmosName,
            '--resource-group', $LrmsRg,
            '--subscription', $SubscriptionId,
            '--query', "[?principalId=='$($miJson.principalId)' && roleDefinitionId contains '$CosmosDataContributorRole'].id",
            '--output', 'json'
        ) -JsonOutput -AllowFailure

        if ($existingRoles -and $existingRoles.Count -gt 0) {
            Write-Host "  SKIP: Data Contributor role already assigned" -ForegroundColor DarkYellow
        } else {
            $cosmosScope = "/subscriptions/$SubscriptionId/resourceGroups/$LrmsRg/providers/Microsoft.DocumentDB/databaseAccounts/$CosmosName"

            Invoke-AzCli -ArgumentList @(
                'cosmosdb', 'sql', 'role', 'assignment', 'create',
                '--account-name', $CosmosName,
                '--resource-group', $LrmsRg,
                '--subscription', $SubscriptionId,
                '--role-definition-id', $CosmosDataContributorRole,
                '--principal-id', $miJson.principalId,
                '--scope', $cosmosScope
            ) | Out-Null
            Write-Host "  ASSIGNED: Built-in Data Contributor to $MiName" -ForegroundColor Green
        }
    }
} elseif (-not $SkipCosmos) {
    Write-Host "--- Step 12: Cosmos RBAC (SKIPPED - MI not resolved) ---" -ForegroundColor DarkYellow
}
Write-Host ""

# --- Step 13: Blob Storage ---
Write-Host "--- Step 13: Blob Storage ---" -ForegroundColor Yellow

$storageExists = Invoke-AzCli -ArgumentList @(
    'storage', 'account', 'show',
    '--name', $StorageName,
    '--resource-group', $LrmsRg,
    '--subscription', $SubscriptionId,
    '--query', 'id',
    '--output', 'tsv'
) -AllowFailure

if ($LASTEXITCODE -eq 0 -and $storageExists) {
    Write-Host "  SKIP: Storage account '$StorageName' already exists" -ForegroundColor DarkYellow
} else {
    if ($PSCmdlet.ShouldProcess($StorageName, "Create storage account (Standard_LRS)")) {
        Invoke-AzCli -ArgumentList @(
            'storage', 'account', 'create',
            '--name', $StorageName,
            '--resource-group', $LrmsRg,
            '--location', $Region,
            '--subscription', $SubscriptionId,
            '--sku', 'Standard_LRS',
            '--allow-blob-public-access', 'false'
        ) | Out-Null
        Write-Host "  CREATED: $StorageName (Standard_LRS)" -ForegroundColor Green
    }
}
Write-Host ""

# --- Step 14: Application Insights ---
Write-Host "--- Step 14: Application Insights ---" -ForegroundColor Yellow

$appiExists = Invoke-AzCli -ArgumentList @(
    'monitor', 'app-insights', 'component', 'show',
    '--app', $AppInsightsName,
    '--resource-group', $LrmsRg,
    '--subscription', $SubscriptionId,
    '--query', '{instrumentationKey: instrumentationKey, connectionString: connectionString}',
    '--output', 'json'
) -JsonOutput -AllowFailure

if ($LASTEXITCODE -eq 0 -and $appiExists -and $appiExists.instrumentationKey) {
    Write-Host "  SKIP: App Insights '$AppInsightsName' already exists" -ForegroundColor DarkYellow
    $OutputValues['InstrumentationKey'] = $appiExists.instrumentationKey
    $OutputValues['ConnectionString'] = $appiExists.connectionString
} else {
    if ($PSCmdlet.ShouldProcess($AppInsightsName, "Create Application Insights")) {
        $appiResult = Invoke-AzCli -ArgumentList @(
            'monitor', 'app-insights', 'component', 'create',
            '--app', $AppInsightsName,
            '--resource-group', $LrmsRg,
            '--location', $Region,
            '--subscription', $SubscriptionId,
            '--kind', 'web',
            '--application-type', 'web',
            '--query', '{instrumentationKey: instrumentationKey, connectionString: connectionString}',
            '--output', 'json'
        ) -JsonOutput
        Write-Host "  CREATED: $AppInsightsName" -ForegroundColor Green
        $OutputValues['InstrumentationKey'] = $appiResult.instrumentationKey
        $OutputValues['ConnectionString'] = $appiResult.connectionString
    }
}
Write-Host ""

# --- Summary ---
Write-Host "=== Provisioning Summary ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Resource Group:         $LrmsRg"
Write-Host "Managed Identity:       $MiName"
if ($OutputValues['MiClientId']) {
    Write-Host "  Client ID:            $($OutputValues['MiClientId'])"
    Write-Host "  Principal ID:         $($OutputValues['MiPrincipalId'])"
}
Write-Host "App Service Plan:       $PlanName"
Write-Host "App Service:            $AppName"
Write-Host "  URL:                  https://$AppName.azurewebsites.net"
if (-not $SkipCosmos) {
    Write-Host "Cosmos DB:              $CosmosName"
    Write-Host "  Endpoint:             https://$CosmosName.documents.azure.com:443/"
    Write-Host "  Database:             $CosmosDb"
    Write-Host "  Containers:           $($CosmosContainers.Keys -join ', ')"
}
if (-not $SkipNetwork) {
    Write-Host "VNet Integration:       $VnetName/$AppSubnet"
    Write-Host "Private Endpoint:       $PeName (in $CmsRg)"
}
Write-Host "Storage:                $StorageName"
Write-Host "App Insights:           $AppInsightsName"
if ($OutputValues['InstrumentationKey']) {
    Write-Host "  Instrumentation Key:  $($OutputValues['InstrumentationKey'])"
}
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Cyan
Write-Host "  1. Deploy LRMS:  .\Deploy-Lrms.ps1 -Environment $Environment"
Write-Host "  2. Assign roles: .\Assign-CmsAppRoles.ps1 -Environment $Environment (if LRMS calls CMS)"
Write-Host ""
