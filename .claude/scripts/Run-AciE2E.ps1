<#
.SYNOPSIS
    On-demand ACI-based E2E integration test runner for LENS-DCS rings.

.DESCRIPTION
    Spins up a transient Azure Container Instance (ACI) under a pre-provisioned
    user-assigned managed identity, runs the unmodified Ev2 integration-test
    script (`Invoke-IntegrationTests.ps1` or `Invoke-SecurityTests.ps1`) inside
    that container, polls until the container reaches a terminal state, captures
    full logs to `.mad/reports/`, and tears the container down.

    Why ACI (and not the developer's machine)?
      - Private VNet reachability from inside the AzureCloud service tag
        (matches the Ev2 deploymentScripts topology).
      - The pre-provisioned UAMI `id-lensdcs-npe-inttest` already has the
        Website Contributor + Service Bus + app-role assignments for npe rings.
      - The Ev2 PowerShell scripts use `Get-AzAccessToken`, `Get-AzWebApp`,
        `Add-AzWebAppAccessRestrictionRule`, and `Invoke-AzRestMethod` — all
        of which require the Az PowerShell modules (baked into the Az
        PowerShell container image, NOT into ad-hoc dev machines).

    Differences from a release-time Ev2 run:
      - We set SKIP_DUAL_SB_FLOW=true so `Invoke-IntegrationTests.ps1` skips
        Test 2 (Traffic Manager submit + dual-Service-Bus status updates).
        That test path requires the caller IP to be propagated through the
        SB NSP allow-list, which can take 5-15 minutes from a cold start
        (Microsoft documented NSP propagation window). On-demand ACI runs
        spawn a fresh container with a new egress IP every time, so the
        runtime Add-NspIp + retry window is structurally insufficient.
        Test 1 (Regional Submit) still runs and exercises the full submit
        + persist + getStatus contract on the deployed binary — that's the
        load-bearing on-demand smoke.
      - We wire SKIP_VERSION_CHECK=true so the test doesn't gate on a fresh
        BuildVersion match. We pass through the deployed BuildVersion for
        diagnostic logging only.

    The Ev2 scripts themselves are unchanged from the LENS-DCS reference
    repo. The SKIP_DUAL_SB_FLOW kill switch was added to Invoke-IntegrationTests.ps1
    on PR 5159603 (kit-fix follow-up) to make the doc-vs-code contract honest.
    The container needs `Connect-AzAccount -Identity` prepended (Ev2's
    deploymentScripts container does this implicitly; ACI does not), so we
    emit a tiny shim before the Ev2 body.

.PARAMETER Environment
    Ring name: npe | npe2 | npe3 | npe4 | npe5 | npe6.

.PARAMETER Subscription
    Azure subscription ID (default: c750c7f5-7730-4c7c-99aa-47dc6b50c914 — LENS-DCS-NPE).

.PARAMETER ResourceGroup
    Host RG for the transient ACI. Default: rg-lensdcs-{env}-westcentralus
    (matches where the secondary app lives — same VNet zone).

.PARAMETER UamiResourceId
    Full ARM resource ID of the user-assigned managed identity.
    Default: the pre-provisioned id-lensdcs-npe-inttest in rg-lensdcs-npe-westus3.

.PARAMETER AciName
    ACI name. Default: aci-dcs-e2e-{env}-{utctimestamp}.

.PARAMETER ScriptKind
    Integration | Security. Picks which Ev2 script to run.

.PARAMETER Image
    Container image. Default: an Az-PowerShell-bundled Linux image.

.PARAMETER TimeoutSeconds
    Hard timeout for the polling loop (terminates the container if exceeded).
    Default: 1800 (30 min).

.PARAMETER PollIntervalSeconds
    Polling interval. Default: 10.

.PARAMETER DryRun
    Print resolved env vars + planned `az container create` command and exit 0.
    No az calls are made.

.PARAMETER ReferenceRepoRoot
    Override path to the LENS-DCS reference clone. Default: the path under
    references/LENS-DCS in this repo.

.EXAMPLE
    pwsh -NoProfile -File .claude/scripts/Run-AciE2E.ps1 -Environment npe4 -DryRun

.EXAMPLE
    pwsh -NoProfile -File .claude/scripts/Run-AciE2E.ps1 -Environment npe4

.EXAMPLE
    pwsh -NoProfile -File .claude/scripts/Run-AciE2E.ps1 -Environment npe4 -ScriptKind Security

.NOTES
    Exit codes:
      0 = PASS (container reached Succeeded; tests passed)
      1 = FAIL (container reached Failed; tests failed)
      2 = SETUP_ERROR (couldn't even launch ACI — config missing, az not
          authenticated, RG missing, etc.)
      3 = TIMEOUT (container did not reach a terminal state in TimeoutSeconds)
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('npe','npe2','npe3','npe4','npe5','npe6')]
    [string]$Environment,

    [string]$Subscription = 'c750c7f5-7730-4c7c-99aa-47dc6b50c914',

    [string]$ResourceGroup = '',

    [string]$UamiResourceId = '',

    [string]$AciName = '',

    [ValidateSet('Integration','Security')]
    [string]$ScriptKind = 'Integration',

    [string]$Image = 'mcr.microsoft.com/azure-powershell:latest',

    [int]$TimeoutSeconds = 1800,

    [int]$PollIntervalSeconds = 10,

    [switch]$DryRun,

    [string]$ReferenceRepoRoot = ''
)

# Hybrid error handling per .claude/rules/patterns/powershell-conventions.md:
# 'Stop' for cmdlets, $LASTEXITCODE for native commands.
$ErrorActionPreference = 'Stop'

function Write-Info  ([string]$Message) { Write-Host "[Run-AciE2E] $Message" }
function Write-Warn  ([string]$Message) { Write-Host "[Run-AciE2E] WARN: $Message" -ForegroundColor Yellow }
function Write-Err   ([string]$Message) { Write-Host "[Run-AciE2E] ERROR: $Message" -ForegroundColor Red }

# ---------------------------------------------------------------------------
# 1. Resolve defaults that depend on -Environment
# ---------------------------------------------------------------------------
$utc = [DateTime]::UtcNow.ToString('yyyyMMddHHmmss')
if (-not $ResourceGroup)  { $ResourceGroup  = "rg-lensdcs-$Environment-westcentralus" }
if (-not $AciName)        { $AciName        = "aci-dcs-e2e-$Environment-$utc" }
if (-not $UamiResourceId) {
    $UamiResourceId = "/subscriptions/$Subscription/resourceGroups/rg-lensdcs-npe-westus3/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-lensdcs-npe-inttest"
}

# ReferenceRepoRoot defaults to the well-known clone in this kit.
if (-not $ReferenceRepoRoot) {
    # The script lives at .claude/scripts/Run-AciE2E.ps1; back up two levels to repo root.
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $ReferenceRepoRoot = Join-Path $repoRoot 'references/LENS-DCS'
}

$ev2Root = Join-Path $ReferenceRepoRoot 'sources/dev/DataCollector/Ev2/ServiceGroupRoot'
$configPath = Join-Path (Join-Path $ev2Root 'Configuration') "Microsoft.M365.LENS.DataCollector.$Environment.json"
$scriptName = if ($ScriptKind -eq 'Integration') { 'Invoke-IntegrationTests.ps1' } else { 'Invoke-SecurityTests.ps1' }
$scriptPath = Join-Path (Join-Path $ev2Root 'Scripts') $scriptName

# ---------------------------------------------------------------------------
# 2. Load + parse the Ev2 environment config
# ---------------------------------------------------------------------------
if (-not (Test-Path $configPath)) {
    Write-Err "Config file not found: $configPath"
    Write-Err "Did you clone references/LENS-DCS? Did you pass -ReferenceRepoRoot?"
    exit 2
}
if (-not (Test-Path $scriptPath)) {
    Write-Err "Ev2 test script not found: $scriptPath"
    exit 2
}

try {
    $configRaw = Get-Content -Raw -Path $configPath
    $config = ($configRaw | ConvertFrom-Json).settings
} catch {
    Write-Err "Failed to parse config: $($_.Exception.Message)"
    exit 2
}

# The Ev2 config uses $(token) substitutions (lensEnvironment, subscriptionId).
# We need to resolve them ourselves since we're reading the raw file, not the
# rendered version that the deployment-pipeline produces.
function Resolve-Token {
    param([string]$Value, [hashtable]$Vars)
    if ($null -eq $Value) { return $null }
    $resolved = $Value
    # Iterate twice to catch nested references (e.g. keyVaultId references subscriptionId + lensEnvironment).
    for ($i = 0; $i -lt 3; $i++) {
        foreach ($k in $Vars.Keys) {
            $resolved = $resolved -replace [Regex]::Escape("`$($k)"), $Vars[$k]
        }
        if ($resolved -notmatch '\$\(') { break }
    }
    return $resolved
}

$tokens = @{
    'lensEnvironment'   = $config.lensEnvironment
    'subscriptionId'    = $config.subscriptionId
    'appName'           = (Resolve-Token $config.appName @{ 'lensEnvironment' = $config.lensEnvironment })
    'primaryLocation'   = $config.primaryLocation
    'secondaryLocation' = $config.secondaryLocation
}

$appName        = $tokens.appName
$primaryRG      = "rg-lensdcs-$($tokens.lensEnvironment)-$($tokens.primaryLocation)"
$secondaryRG    = "rg-lensdcs-$($tokens.lensEnvironment)-$($tokens.secondaryLocation)"
$primaryAppName   = "$appName-$($tokens.primaryLocation)"
$secondaryAppName = "$appName-$($tokens.secondaryLocation)"
$apiClientId    = $config.apiClientId
$queueName      = $config.serviceBusQueueName
$sbPrimary      = "sb-$appName-$($tokens.primaryLocation)"
$sbSecondary    = "sb-$appName-$($tokens.secondaryLocation)"
$baseUrl        = Resolve-Token $config.trafficManagerUrl $tokens

# ---------------------------------------------------------------------------
# 3. Resolve the live BuildVersion from the deployed app (informational)
# ---------------------------------------------------------------------------
$buildVersion = '0.0.0.0'
if (-not $DryRun) {
    Write-Info "Resolving BuildVersion from $secondaryAppName in $secondaryRG..."
    $ErrorActionPreference = 'Continue'
    $bvRaw = az webapp config appsettings list `
        --name $secondaryAppName `
        --resource-group $secondaryRG `
        --subscription $Subscription `
        --query "[?name=='BuildVersion'].value | [0]" -o tsv 2>&1
    $bvExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    # Filter az CLI noise (WARNING/UserWarning/cryptography path leaks) per
    # rules/patterns/powershell-conventions.md "az CLI WARNING Filtering".
    $bvJson = ($bvRaw | Where-Object {
        $_ -notmatch '^\s*WARNING:' -and
        $_ -notmatch 'UserWarning' -and
        $_ -notmatch '^D:\\a\\' -and
        $_ -notmatch '^\s*$'
    }) -join "`n"
    if ($bvExit -eq 0 -and $bvJson -and $bvJson -notmatch '^\s*$') {
        $buildVersion = ($bvJson | Out-String).Trim()
        Write-Info "Resolved BuildVersion: $buildVersion"
    } else {
        Write-Warn "Could not resolve BuildVersion (exit $bvExit). Falling back to '0.0.0.0' (informational only since SKIP_VERSION_CHECK=true)."
    }
} else {
    Write-Info "[DRY-RUN] Skipping BuildVersion resolution. Would call: az webapp config appsettings list --name $secondaryAppName --resource-group $secondaryRG"
}

# ---------------------------------------------------------------------------
# 4. Build the inline script: Az login shim + Ev2 script body, base64-encoded
# ---------------------------------------------------------------------------
$ev2Body = Get-Content -Raw -Path $scriptPath

# UAMI client ID is needed for Connect-AzAccount -Identity in some image variants.
# We'll pass it as an env var (UAMI_CLIENT_ID) and use -AccountId in the shim.
# The shim runs BEFORE the Ev2 body and only handles login + an env-var sanity log.
$shim = @'
$ErrorActionPreference = 'Stop'
Write-Host "[ACI shim] PowerShell version: $($PSVersionTable.PSVersion)"
Write-Host "[ACI shim] Connecting to Azure with managed identity..."
$connectAttempts = 4
$connected = $false
for ($i = 1; $i -le $connectAttempts; $i++) {
    try {
        if ($env:UAMI_CLIENT_ID) {
            Connect-AzAccount -Identity -AccountId $env:UAMI_CLIENT_ID -Subscription $env:AZURE_SUBSCRIPTION_ID | Out-Null
        } else {
            Connect-AzAccount -Identity -Subscription $env:AZURE_SUBSCRIPTION_ID | Out-Null
        }
        $connected = $true
        Write-Host "[ACI shim] Connected on attempt $i."
        break
    } catch {
        $wait = 5 * $i
        Write-Host "[ACI shim] Connect-AzAccount attempt $i/$connectAttempts failed: $($_.Exception.Message). Sleeping ${wait}s..."
        Start-Sleep -Seconds $wait
    }
}
if (-not $connected) { throw "[ACI shim] Could not Connect-AzAccount after $connectAttempts attempts." }
Write-Host "[ACI shim] Az context:"
Get-AzContext | Format-List Account,Subscription,Tenant | Out-String | Write-Host
Write-Host "[ACI shim] === Ev2 script begins ==="

'@

$fullScript = $shim + $ev2Body

# Base64-encode as UTF-16LE (PowerShell EncodedCommand requirement).
$bytes = [System.Text.Encoding]::Unicode.GetBytes($fullScript)
$encoded = [Convert]::ToBase64String($bytes)

# ---------------------------------------------------------------------------
# 5. Build the env-var list for the container
# ---------------------------------------------------------------------------
# Force the "secondary stage" path of Invoke-IntegrationTests.ps1:
#   CURRENT_LOCATION != PRIMARY_LOCATION → tests only $SecondaryAppName,
#   skips Traffic Manager + dual-Service-Bus flow.
$currentLocation = $tokens.secondaryLocation
$envVars = @(
    @{ name = 'AZURE_SUBSCRIPTION_ID';            value = $Subscription }
    @{ name = 'PRIMARY_APP_NAME';                 value = $primaryAppName }
    @{ name = 'PRIMARY_RESOURCE_GROUP';           value = $primaryRG }
    @{ name = 'SECONDARY_APP_NAME';               value = $secondaryAppName }
    @{ name = 'SECONDARY_RESOURCE_GROUP';         value = $secondaryRG }
    @{ name = 'BASE_URL';                         value = $baseUrl }
    @{ name = 'API_CLIENT_ID';                    value = $apiClientId }
    @{ name = 'SERVICE_BUS_PRIMARY_NAMESPACE';    value = $sbPrimary }
    @{ name = 'SERVICE_BUS_SECONDARY_NAMESPACE';  value = $sbSecondary }
    @{ name = 'QUEUE';                            value = $queueName }
    @{ name = 'BUILD_VERSION';                    value = $buildVersion }
    @{ name = 'SKIP_VERSION_CHECK';               value = 'true' }
    @{ name = 'SKIP_TEST';                        value = 'false' }
    # SKIP_DUAL_SB_FLOW=true skips Test 2 (TM + dual-SB) inside Invoke-IntegrationTests.ps1.
    # Required because on-demand validation spawns a fresh ACI whose egress IP hasn't
    # propagated through the SB NSP yet — Test 2's runtime Add-NspIp + 10-min retry
    # window is structurally insufficient for cold-cache propagation (5-15 min per
    # Microsoft NSP docs). Test 1 (Regional Submit) covers the deployed-binary contract
    # without touching SB NSP. Without this flag, SKIP_VERSION_CHECK=true above would
    # force runFullFlow=true and Test 2 would 401 on every retry.
    @{ name = 'SKIP_DUAL_SB_FLOW';                value = 'true' }
    @{ name = 'CURRENT_LOCATION';                 value = $currentLocation }
    @{ name = 'PRIMARY_LOCATION';                 value = $tokens.primaryLocation }
    # The SB NSP env vars are intentionally blank — the on-demand path takes
    # the secondary-only branch which does not touch the NSPs. Setting them
    # empty matches the script's `if ($SbPrimaryNspName) { ... }` no-op guard.
    @{ name = 'SB_PRIMARY_NSP_NAME';              value = '' }
    @{ name = 'SB_PRIMARY_NSP_RG';                value = '' }
    @{ name = 'SB_PRIMARY_NSP_PROFILE_NAME';      value = '' }
    @{ name = 'SB_SECONDARY_NSP_NAME';            value = '' }
    @{ name = 'SB_SECONDARY_NSP_RG';              value = '' }
    @{ name = 'SB_SECONDARY_NSP_PROFILE_NAME';    value = '' }
)

# Resolve UAMI client ID for the connect shim (best-effort; on failure we
# rely on the system-default identity selection).
$uamiClientId = ''
if (-not $DryRun) {
    $ErrorActionPreference = 'Continue'
    $uamiClientId = (az identity show --ids $UamiResourceId --query 'clientId' -o tsv 2>&1) | Out-String
    $uamiExit = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($uamiExit -eq 0 -and $uamiClientId) {
        $uamiClientId = $uamiClientId.Trim()
        Write-Info "Resolved UAMI clientId: $uamiClientId"
    } else {
        Write-Warn "Could not resolve UAMI clientId (exit $uamiExit). Connect-AzAccount will use the default identity from the container's metadata endpoint."
        $uamiClientId = ''
    }
}
if ($uamiClientId) {
    $envVars += @{ name = 'UAMI_CLIENT_ID'; value = $uamiClientId }
}

# ---------------------------------------------------------------------------
# 6. Banner: print resolved values
# ---------------------------------------------------------------------------
Write-Info ""
Write-Info "Resolved configuration:"
Write-Info "  Environment        : $Environment"
Write-Info "  Subscription       : $Subscription"
Write-Info "  Host ResourceGroup : $ResourceGroup"
Write-Info "  ACI name           : $AciName"
Write-Info "  Image              : $Image"
Write-Info "  ScriptKind         : $ScriptKind ($scriptName)"
Write-Info "  UAMI resource id   : $UamiResourceId"
Write-Info "  UAMI client id     : $(if ($uamiClientId) { $uamiClientId } else { '(unresolved — using default)' })"
Write-Info "  Base URL           : $baseUrl"
Write-Info "  API Client ID      : $apiClientId"
Write-Info "  Build Version      : $buildVersion"
Write-Info "  Primary App        : $primaryAppName / $primaryRG"
Write-Info "  Secondary App      : $secondaryAppName / $secondaryRG"
Write-Info "  Service Bus (P/S)  : $sbPrimary / $sbSecondary"
Write-Info "  Queue              : $queueName"
Write-Info "  Forced 'secondary' branch: CURRENT_LOCATION=$currentLocation, PRIMARY_LOCATION=$($tokens.primaryLocation)"
Write-Info "  EncodedCommand     : $($encoded.Length) chars (base64-UTF16LE)"
Write-Info "  Timeout            : ${TimeoutSeconds}s"

# ---------------------------------------------------------------------------
# 7. Build the ACI definition as an ARM/REST JSON body
# ---------------------------------------------------------------------------
# Why `az rest --method PUT` instead of `az container create`:
# On Windows the inline `az container create --command-line` invocation exceeds
# the 8191-char command-line limit (encoded command alone is ~66KB).
# Per .claude/rules/patterns/deployment-troubleshooting.md
# § "ACI container creation fails on Windows", the canonical fix is `az rest`
# with a JSON body file. That moves the giant encoded command out of the
# process command-line into a file, then `az rest` reads the file via @path.
#
# ACI REST API: PUT containerGroups/{name}?api-version=2023-05-01
# https://learn.microsoft.com/azure/container-instances/container-instances-rest-api

$envVarsArray = @()
foreach ($kv in $envVars) {
    $envVarsArray += [ordered]@{
        name  = $kv.name
        value = [string]$kv.value
    }
}

# Derive ACI location from the host RG name (rg-lensdcs-<env>-<region>)
$aciLocation = if ($ResourceGroup -match 'rg-lensdcs-[^-]+-(.+)$') { $Matches[1] } else { 'westcentralus' }

$aciBody = [ordered]@{
    location = $aciLocation
    identity = [ordered]@{
        type                   = 'UserAssigned'
        userAssignedIdentities = [ordered]@{
            $UamiResourceId = @{}
        }
    }
    properties = [ordered]@{
        osType        = 'Linux'
        restartPolicy = 'Never'
        containers    = @(
            [ordered]@{
                name       = 'main'
                properties = [ordered]@{
                    image                = $Image
                    command              = @('pwsh', '-NoProfile', '-NonInteractive', '-EncodedCommand', $encoded)
                    environmentVariables = $envVarsArray
                    resources            = [ordered]@{
                        requests = [ordered]@{
                            cpu       = 1
                            memoryInGB = 2
                        }
                    }
                }
            }
        )
    }
}

# Write body to temp file (UTF-8 no BOM per rules/patterns/powershell-conventions.md
# "UTF-8 BOM Gotcha (PowerShell 5.1)" — `az rest --body @file` rejects BOM)
$bodyJson = $aciBody | ConvertTo-Json -Depth 20 -Compress
$bodyFile = Join-Path ([System.IO.Path]::GetTempPath()) "aci-body-$AciName.json"
[System.IO.File]::WriteAllText($bodyFile, $bodyJson, (New-Object System.Text.UTF8Encoding $false))

$aciUri = "https://management.azure.com/subscriptions/$Subscription/resourceGroups/$ResourceGroup/providers/Microsoft.ContainerInstance/containerGroups/${AciName}?api-version=2023-05-01"

# ---------------------------------------------------------------------------
# 8. Dry-run short-circuit
# ---------------------------------------------------------------------------
if ($DryRun) {
    Write-Info ""
    Write-Info "[DRY-RUN] Planned az rest PUT invocation:"
    Write-Info "  az rest --method PUT --uri ""$aciUri"" --body ""@$bodyFile"" --headers Content-Type=application/json"
    Write-Info ""
    Write-Info "[DRY-RUN] Env vars (count=$($envVars.Count)):"
    foreach ($kv in $envVars) {
        $display = if ($kv.value) { $kv.value } else { '(empty)' }
        Write-Info "    $($kv.name) = $display"
    }
    Write-Info ""
    Write-Info "[DRY-RUN] First 200 chars of EncodedCommand: $($encoded.Substring(0, [Math]::Min(200, $encoded.Length)))..."
    Write-Info "[DRY-RUN] Body file size: $((Get-Item $bodyFile).Length) bytes"
    Write-Info ""
    Write-Info "[DRY-RUN] No az calls were made. Exit 0."
    Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue
    exit 0
}

# ---------------------------------------------------------------------------
# 9. Live execution — create + poll + cleanup
# ---------------------------------------------------------------------------
$logFile = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) ".mad/reports/aci-e2e-$Environment-$utc.log"
$logDir = Split-Path -Parent $logFile
if (-not (Test-Path $logDir)) {
    New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}
Write-Info "Container log will be saved to: $logFile"

$cleanupNeeded = $false
$exitCode = 2  # SETUP_ERROR until we prove otherwise

try {
    Write-Info ""
    Write-Info "Creating ACI via REST PUT (body file: $bodyFile, $((Get-Item $bodyFile).Length) bytes)..."
    # Diagnostic: confirm location is in the body before sending
    $rawBody = Get-Content $bodyFile -Raw
    $sampleLen = [Math]::Min(300, $rawBody.Length)
    Write-Info "  Body head: $($rawBody.Substring(0, $sampleLen))"
    Write-Info "  Body contains 'location': $($rawBody.Contains('""location""'))"
    $ErrorActionPreference = 'Continue'
    # MSYS_NO_PATHCONV=1 prevents Git Bash from mangling URI slashes.
    $oldMsys = $env:MSYS_NO_PATHCONV
    $env:MSYS_NO_PATHCONV = '1'
    # Use POSIX-style path for the @file ref — az rest's argparse rejects backslashes
    # in @file paths on some Windows builds (treats them as escape characters).
    $bodyFilePosix = $bodyFile -replace '\\','/'
    $createOutput = az rest --method PUT --uri $aciUri --body "@$bodyFilePosix" --headers "Content-Type=application/json" 2>&1 | Out-String
    $createExit = $LASTEXITCODE
    $env:MSYS_NO_PATHCONV = $oldMsys
    $ErrorActionPreference = 'Stop'

    if ($createExit -ne 0) {
        Write-Err "az rest PUT (container create) failed (exit $createExit):"
        Write-Err $createOutput
        Write-Err "  (body file kept at $bodyFile for inspection)"
        exit 2
    }
    Remove-Item $bodyFile -Force -ErrorAction SilentlyContinue
    $cleanupNeeded = $true
    Write-Info "ACI created. Polling state every ${PollIntervalSeconds}s (timeout ${TimeoutSeconds}s)..."

    $deadline = (Get-Date).AddSeconds($TimeoutSeconds)
    $finalState = $null
    $lastLogLength = 0

    while ((Get-Date) -lt $deadline) {
        Start-Sleep -Seconds $PollIntervalSeconds

        # Get container state
        $ErrorActionPreference = 'Continue'
        $stateRaw = az container show `
            --resource-group $ResourceGroup `
            --subscription $Subscription `
            --name $AciName `
            --query 'instanceView.state' -o tsv 2>&1
        $stateExit = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'

        if ($stateExit -ne 0) {
            Write-Warn "az container show failed (exit $stateExit). Will retry: $stateRaw"
            continue
        }
        $state = ($stateRaw | Out-String).Trim()
        Write-Info "  state=$state  (deadline in $([int](($deadline - (Get-Date)).TotalSeconds))s)"

        # Poll logs incrementally for live feedback
        $ErrorActionPreference = 'Continue'
        $logsRaw = az container logs `
            --resource-group $ResourceGroup `
            --subscription $Subscription `
            --name $AciName 2>&1
        $logsExit = $LASTEXITCODE
        $ErrorActionPreference = 'Stop'

        if ($logsExit -eq 0) {
            $logsStr = ($logsRaw | Out-String)
            if ($logsStr.Length -gt $lastLogLength) {
                $newChunk = $logsStr.Substring($lastLogLength)
                # Echo the new chunk verbatim (Ev2 script writes its own headers).
                $newChunk -split "`n" | ForEach-Object {
                    if ($_) { Write-Host "  | $_" }
                }
                $lastLogLength = $logsStr.Length
            }
        }

        if ($state -in @('Succeeded','Failed','Terminated')) {
            $finalState = $state
            break
        }
    }

    if (-not $finalState) {
        Write-Err "Container did not reach a terminal state in ${TimeoutSeconds}s. Capturing final logs and tearing down."
        $exitCode = 3
    } else {
        Write-Info "Container reached terminal state: $finalState"
    }

    # Capture full final logs.
    # Note: az.cmd emits CLIXML format when invoked from PowerShell, which
    # PowerShell then tries to deserialize as object stream and fails. Using
    # Start-Process with file redirection bypasses the PowerShell pipe entirely
    # so the raw text output reaches the file unmodified.
    $ErrorActionPreference = 'Continue'
    $oldMsys = $env:MSYS_NO_PATHCONV
    $env:MSYS_NO_PATHCONV = '1'
    $logTmp = [System.IO.Path]::GetTempFileName()
    $errTmp = [System.IO.Path]::GetTempFileName()
    $proc = Start-Process -FilePath 'az' -ArgumentList @(
        'container', 'logs',
        '--resource-group', $ResourceGroup,
        '--subscription',   $Subscription,
        '--name',           $AciName
    ) -NoNewWindow -Wait -PassThru -RedirectStandardOutput $logTmp -RedirectStandardError $errTmp
    $logsExit = $proc.ExitCode
    $finalLogs = Get-Content -Raw -Path $logTmp -ErrorAction SilentlyContinue
    if (-not $finalLogs) { $finalLogs = '' }
    Remove-Item $logTmp -Force -ErrorAction SilentlyContinue
    Remove-Item $errTmp -Force -ErrorAction SilentlyContinue
    $env:MSYS_NO_PATHCONV = $oldMsys
    $ErrorActionPreference = 'Stop'

    # Write to file without BOM (per powershell-conventions.md)
    [System.IO.File]::WriteAllText($logFile, $finalLogs, (New-Object System.Text.UTF8Encoding $false))
    Write-Info "Wrote $($finalLogs.Length) chars of logs to $logFile"

    if ($finalState -eq 'Succeeded') {
        Write-Info ""
        Write-Info "RESULT: PASS"
        $exitCode = 0
    } elseif ($finalState -eq 'Failed' -or $finalState -eq 'Terminated') {
        Write-Err ""
        Write-Err "RESULT: FAIL ($finalState). See log: $logFile"
        $exitCode = 1
    }
    # else: $exitCode already set to 3 (TIMEOUT)
}
catch {
    Write-Err "Unexpected error: $($_.Exception.Message)"
    Write-Err $_.ScriptStackTrace
    if ($exitCode -eq 2) { $exitCode = 2 } else { $exitCode = 1 }
}
finally {
    if ($cleanupNeeded) {
        Write-Info "Cleaning up ACI ($AciName)..."
        $ErrorActionPreference = 'Continue'
        $oldMsys2 = $env:MSYS_NO_PATHCONV
        $env:MSYS_NO_PATHCONV = '1'
        az container delete `
            --resource-group $ResourceGroup `
            --subscription $Subscription `
            --name $AciName `
            --yes --no-wait 2>&1 | Out-Null
        $delExit = $LASTEXITCODE
        $env:MSYS_NO_PATHCONV = $oldMsys2
        $ErrorActionPreference = 'Stop'
        if ($delExit -ne 0) {
            Write-Warn "az container delete returned exit $delExit (cleanup is best-effort)."
        } else {
            Write-Info "Cleanup queued (--no-wait)."
        }
    }
}

exit $exitCode
