<#
.SYNOPSIS
    Deploy and manage an ACI container to run agent eval scenarios.
    Follows the same ACI deployment pattern as Test-E2E-ACI.ps1.

.DESCRIPTION
    Creates an ACI container with the .NET SDK, clones the repo at a specific commit,
    runs eval scenarios via Eval-Entrypoint.sh, captures results, and optionally uploads
    them via Store-EvalResults.ps1.

.PARAMETER Environment
    Target environment: tonym, npe

.PARAMETER CommitSha
    Git commit SHA to evaluate. Default: HEAD

.PARAMETER Scenario
    Comma-separated list of scenario names. Default: all scenarios.

.PARAMETER EvalRunId
    Unique run identifier. Default: auto-generated eval-{timestamp}-{shortsha}

.PARAMETER SkipCleanup
    Leave the ACI container after eval completes (for log inspection)

.PARAMETER SkipUpload
    Skip uploading results via Store-EvalResults.ps1

.PARAMETER WhatIf
    Show what would be executed without creating any Azure resources

.EXAMPLE
    .\Deploy-EvalContainer.ps1 -Environment tonym
    .\Deploy-EvalContainer.ps1 -Environment tonym -Scenario "investigate-and-implement"
    .\Deploy-EvalContainer.ps1 -Environment tonym -CommitSha abc1234 -SkipCleanup
    .\Deploy-EvalContainer.ps1 -Environment tonym -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [ValidateSet("tonym", "npe")]
    [string]$Environment = "tonym",

    [Parameter()]
    [string]$CommitSha,

    [Parameter()]
    [string]$Scenario,

    [Parameter()]
    [string]$EvalRunId,

    [switch]$SkipCleanup,

    [switch]$SkipUpload
)

$ErrorActionPreference = "Continue"
$env:MSYS_NO_PATHCONV = "1"

# --- Constants ---
$SubscriptionId = "d27c8315-7947-43ea-88ed-1f1c34860559"
$ResourceGroup = "rg-lenscms-$Environment"
$Region = "westus3"
$MiName = "id-cms-$Environment-$Region"
$VnetName = "vnet-cms-$Environment-$Region"
$SubnetName = "snet-aci"
$Image = "mcr.microsoft.com/dotnet/sdk:10.0"
$MaxPollSeconds = 1200   # 20 minutes
$PollIntervalSeconds = 30

$ScriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { "C:\source\CCGHCP\.mad\scripts" }
$ProjectRoot = Split-Path (Split-Path $ScriptRoot -Parent) -Parent
$TestsDir = Join-Path $ProjectRoot ".mad\tests"
$ResultsDir = Join-Path $TestsDir "results"
$EntrypointScript = Join-Path $TestsDir "Eval-Entrypoint.sh"

# --- Step 0: Resolve parameters ---
Write-Host ""
Write-Host "=== Eval Container Deployment ===" -ForegroundColor Cyan
Write-Host ""

# Resolve commit SHA
if (-not $CommitSha) {
    $CommitSha = git -C $ProjectRoot rev-parse HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $CommitSha) {
        Write-Error "Failed to resolve HEAD commit SHA. Provide -CommitSha explicitly."
        exit 1
    }
    $CommitSha = "$CommitSha".Trim()
}
$ShortSha = $CommitSha.Substring(0, [Math]::Min(7, $CommitSha.Length))

# Resolve branch name
$GitBranch = git -C $ProjectRoot rev-parse --abbrev-ref HEAD 2>$null
if ($LASTEXITCODE -ne 0 -or -not $GitBranch) { $GitBranch = "unknown" }
$GitBranch = "$GitBranch".Trim()

# Generate EvalRunId
$Timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if (-not $EvalRunId) {
    $EvalRunId = "eval-$Timestamp-$ShortSha"
}

# Container name (unique per run, avoids collisions)
$ContainerName = "aci-eval-$Environment-$(Get-Date -Format 'yyyyMMddHHmmss')"

# Resolve repo URL for cloning inside container
$RepoUrl = git -C $ProjectRoot remote get-url origin 2>$null
if ($LASTEXITCODE -ne 0 -or -not $RepoUrl) { $RepoUrl = "" }
$RepoUrl = "$RepoUrl".Trim()

# Default scenario to "all"
if (-not $Scenario) { $Scenario = "all" }

Write-Host "Environment:    $Environment"
Write-Host "Commit SHA:     $CommitSha ($ShortSha)"
Write-Host "Branch:         $GitBranch"
Write-Host "Eval Run ID:    $EvalRunId"
Write-Host "Container:      $ContainerName"
Write-Host "Scenarios:      $Scenario"
Write-Host "Image:          $Image"
Write-Host "Resource Group: $ResourceGroup"
Write-Host ""

# --- Step 1: Resolve managed identity ---
Write-Host "--- Step 1: Resolve managed identity ---" -ForegroundColor Yellow
$mi = az identity show `
    --name $MiName `
    --resource-group $ResourceGroup `
    --subscription $SubscriptionId `
    --query "{id: id, clientId: clientId}" `
    --output json 2>&1 | ConvertFrom-Json

if (-not $mi.id) {
    Write-Error "Could not find managed identity '$MiName' in '$ResourceGroup'"
    exit 1
}
Write-Host "MI Resource ID: $($mi.id)" -ForegroundColor Green
Write-Host "MI Client ID:   $($mi.clientId)" -ForegroundColor Green

# --- Step 2: Resolve ACI subnet ---
Write-Host ""
Write-Host "--- Step 2: Resolve ACI subnet ---" -ForegroundColor Yellow
$subnetId = az network vnet subnet show `
    --name $SubnetName `
    --vnet-name $VnetName `
    --resource-group $ResourceGroup `
    --subscription $SubscriptionId `
    --query "id" -o tsv 2>&1

if (-not $subnetId -or $subnetId -like "*ERROR*") {
    Write-Error "Could not find subnet '$SubnetName' in VNet '$VnetName'"
    exit 1
}
Write-Host "Subnet ID: $subnetId" -ForegroundColor Green

# --- Step 3: Resolve Key Vault ---
Write-Host ""
Write-Host "--- Step 3: Resolve Key Vault ---" -ForegroundColor Yellow
$KeyVaultName = "kv-cms-$Environment-$Region"
Write-Host "Key Vault: $KeyVaultName" -ForegroundColor Green

# --- WhatIf: Print resolved parameters and exit ---
if (-not $PSCmdlet.ShouldProcess($ContainerName, "Create eval ACI container")) {
    Write-Host ""
    Write-Host "WHATIF: Would create container '$ContainerName' with:" -ForegroundColor DarkYellow
    Write-Host "  Image:        $Image" -ForegroundColor DarkYellow
    Write-Host "  CPU:          4 cores" -ForegroundColor DarkYellow
    Write-Host "  Memory:       8 GB" -ForegroundColor DarkYellow
    Write-Host "  Subnet:       $subnetId" -ForegroundColor DarkYellow
    Write-Host "  Identity:     $($mi.id)" -ForegroundColor DarkYellow
    Write-Host "  Client ID:    $($mi.clientId)" -ForegroundColor DarkYellow
    Write-Host "  Key Vault:    $KeyVaultName" -ForegroundColor DarkYellow
    Write-Host "  Commit SHA:   $CommitSha" -ForegroundColor DarkYellow
    Write-Host "  Scenarios:    $Scenario" -ForegroundColor DarkYellow
    Write-Host "  Eval Run ID:  $EvalRunId" -ForegroundColor DarkYellow
    Write-Host "  Repo URL:     $RepoUrl" -ForegroundColor DarkYellow
    Write-Host "  Entrypoint:   $EntrypointScript" -ForegroundColor DarkYellow
    Write-Host ""
    Write-Host "=== DRY RUN COMPLETE ===" -ForegroundColor Cyan
    exit 0
}

# --- Step 4: Delete existing container (if any) ---
Write-Host ""
Write-Host "--- Step 4: Delete existing container (if any) ---" -ForegroundColor Yellow
$existing = $null
try {
    $existing = az container show `
        --name $ContainerName `
        --resource-group $ResourceGroup `
        --subscription $SubscriptionId `
        --query "name" -o tsv 2>$null
} catch { }

if ($existing) {
    az container delete `
        --name $ContainerName `
        --resource-group $ResourceGroup `
        --subscription $SubscriptionId `
        --yes 2>&1 | Out-Null
    Write-Host "Deleted existing container." -ForegroundColor DarkYellow
} else {
    Write-Host "No existing container found." -ForegroundColor DarkYellow
}

# --- Step 5: Base64-encode entrypoint script ---
Write-Host ""
Write-Host "--- Step 5: Encode entrypoint script ---" -ForegroundColor Yellow
if (-not (Test-Path $EntrypointScript)) {
    Write-Error "Entrypoint script not found at $EntrypointScript"
    exit 1
}
$b64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Content $EntrypointScript -Raw)))
Write-Host "Encoded $EntrypointScript ($($b64.Length) chars)" -ForegroundColor Green

# --- Step 6: Create ACI container via az rest --method PUT ---
Write-Host ""
Write-Host "--- Step 6: Create ACI container ---" -ForegroundColor Yellow

# Build the ARM body using a PowerShell hashtable, then serialize to JSON
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
                            cpu = 4
                            memoryInGb = 8
                        }
                    }
                    environmentVariables = @(
                        @{ name = "COMMIT_SHA";       value = $CommitSha }
                        @{ name = "KEY_VAULT_NAME";   value = $KeyVaultName }
                        @{ name = "CLIENT_ID";        value = $mi.clientId }
                        @{ name = "SCENARIOS";        value = $Scenario }
                        @{ name = "EVAL_RUN_ID";      value = $EvalRunId }
                        @{ name = "EVAL_SCRIPT_B64";  value = $b64 }
                        @{ name = "REPO_URL";         value = $RepoUrl }
                    )
                    command = @("bash", "-c", 'echo $EVAL_SCRIPT_B64 | base64 -d | tr -d "\r" | bash')
                }
            }
        )
    }
}

$jsonPath = Join-Path $env:TEMP "aci-eval-$EvalRunId.json"
$aciBody | ConvertTo-Json -Depth 10 | Set-Content -Path $jsonPath -Encoding utf8

$aciUrl = "https://management.azure.com/subscriptions/$SubscriptionId/resourceGroups/$ResourceGroup/providers/Microsoft.ContainerInstance/containerGroups/${ContainerName}?api-version=2023-05-01"
az rest --method PUT --url $aciUrl --body "@$jsonPath" --output none 2>&1

Remove-Item $jsonPath -ErrorAction SilentlyContinue

if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to create ACI container '$ContainerName'"
    exit 1
}
Write-Host "Container created successfully." -ForegroundColor Green

# --- Step 7: Poll for completion ---
Write-Host ""
Write-Host "--- Step 7: Waiting for eval to complete (timeout: ${MaxPollSeconds}s) ---" -ForegroundColor Yellow
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
    $color = if ($state -eq "Succeeded") { "Green" }
             elseif ($state -eq "Failed") { "Red" }
             else { "DarkYellow" }
    Write-Host "  [${mins}m ${secs}s] State: $state" -ForegroundColor $color

    if ($elapsed -ge $MaxPollSeconds) {
        Write-Host "  Timed out after ${MaxPollSeconds}s" -ForegroundColor Red
        break
    }
}

# --- Step 7b: Read container exit code ---
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
    $ecColor = if ($containerExitCode -eq 0) { "Green" } else { "Red" }
    Write-Host "  Container exit code: $containerExitCode" -ForegroundColor $ecColor
}

# --- Step 8: Capture logs ---
Write-Host ""
Write-Host "--- Step 8: Capture logs ---" -ForegroundColor Yellow
$logs = az container logs `
    --name $ContainerName `
    --resource-group $ResourceGroup `
    --subscription $SubscriptionId 2>&1

# Ensure results directory exists
if (-not (Test-Path $ResultsDir)) {
    New-Item -Path $ResultsDir -ItemType Directory -Force | Out-Null
}

# Save raw logs
$rawLogPath = Join-Path $ResultsDir "$EvalRunId-raw.log"
$logs | Set-Content -Path $rawLogPath -Encoding utf8
Write-Host "Raw logs saved to: $rawLogPath" -ForegroundColor Green

# Attempt to parse JSON result from logs
# The entrypoint script is expected to emit a JSON block as its final output.
# Look for the last JSON object in the log output.
$resultJsonPath = Join-Path $ResultsDir "$EvalRunId.json"
$parsedJson = $null

try {
    # Try to find JSON block: look for lines that start with { and find the last complete JSON object
    $logLines = ($logs -join "`n") -split "`n"
    $jsonStartIdx = -1
    $braceDepth = 0
    $jsonCandidate = ""

    # Scan from the end to find the last JSON block
    for ($i = $logLines.Count - 1; $i -ge 0; $i--) {
        $line = $logLines[$i].Trim()
        if ($line -eq "}") {
            # Found potential end of JSON, scan backward to find start
            $jsonEndIdx = $i
            $braceDepth = 0
            for ($j = $i; $j -ge 0; $j--) {
                foreach ($ch in $logLines[$j].ToCharArray()) {
                    if ($ch -eq '{') { $braceDepth-- }
                    if ($ch -eq '}') { $braceDepth++ }
                }
                if ($braceDepth -eq 0) {
                    $jsonStartIdx = $j
                    break
                }
            }
            if ($jsonStartIdx -ge 0) {
                $jsonCandidate = ($logLines[$jsonStartIdx..$jsonEndIdx]) -join "`n"
                break
            }
        }
    }

    if ($jsonCandidate) {
        $parsedJson = $jsonCandidate | ConvertFrom-Json
        $jsonCandidate | Set-Content -Path $resultJsonPath -Encoding utf8
        Write-Host "Parsed JSON results saved to: $resultJsonPath" -ForegroundColor Green
    } else {
        Write-Host "No JSON result block found in container logs." -ForegroundColor Yellow
        Write-Host "Raw logs saved for manual inspection." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Failed to parse JSON from logs: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "Raw logs saved for manual inspection." -ForegroundColor Yellow
}

# Print raw output for visibility
Write-Host ""
Write-Host "--- Container Output ---" -ForegroundColor Yellow
Write-Host $logs

# --- Step 9: Upload results ---
if (-not $SkipUpload -and (Test-Path $resultJsonPath)) {
    Write-Host ""
    Write-Host "--- Step 9: Upload results ---" -ForegroundColor Yellow
    $storeScript = Join-Path $ScriptRoot "Store-EvalResults.ps1"
    if (Test-Path $storeScript) {
        powershell.exe -NoProfile -File $storeScript -ResultFile $resultJsonPath
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Warning: Store-EvalResults.ps1 returned exit code $LASTEXITCODE" -ForegroundColor Yellow
        } else {
            Write-Host "Results uploaded successfully." -ForegroundColor Green
        }
    } else {
        Write-Host "Store-EvalResults.ps1 not found at $storeScript - skipping upload." -ForegroundColor Yellow
    }
} elseif ($SkipUpload) {
    Write-Host ""
    Write-Host "--- Step 9: Skipping upload (-SkipUpload) ---" -ForegroundColor DarkYellow
} else {
    Write-Host ""
    Write-Host "--- Step 9: No result JSON to upload ---" -ForegroundColor Yellow
}

# --- Step 10: Cleanup ---
if (-not $SkipCleanup) {
    Write-Host ""
    Write-Host "--- Step 10: Cleanup ---" -ForegroundColor Yellow
    az container delete `
        --name $ContainerName `
        --resource-group $ResourceGroup `
        --subscription $SubscriptionId `
        --yes 2>&1 | Out-Null
    Write-Host "Container deleted." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "--- Step 10: Skipping cleanup (-SkipCleanup) ---" -ForegroundColor DarkYellow
    Write-Host "Container '$ContainerName' is still running in '$ResourceGroup'."
    Write-Host "Delete manually: az container delete --name $ContainerName -g $ResourceGroup --subscription $SubscriptionId --yes"
}

# --- Summary ---
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Eval Run Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Eval Run ID:    $EvalRunId"
Write-Host "Commit:         $CommitSha ($ShortSha)"
Write-Host "Branch:         $GitBranch"
Write-Host "Environment:    $Environment"
Write-Host "Scenarios:      $Scenario"
Write-Host ""
Write-Host "Result files:"
Write-Host "  Raw logs: $rawLogPath"
if (Test-Path $resultJsonPath) {
    Write-Host "  JSON:     $resultJsonPath"
}
Write-Host ""

# Print pass/fail summary from parsed JSON (if available)
if ($parsedJson -and $parsedJson.summary) {
    $s = $parsedJson.summary
    $passRate = if ($s.assertion_pass_rate) { "{0:P0}" -f $s.assertion_pass_rate } else { "N/A" }
    Write-Host "Scenarios: $($s.total_scenarios) total, $($s.passed) passed, $($s.failed) failed, $($s.errors) errors" -ForegroundColor $(if ($s.failed -eq 0 -and $s.errors -eq 0) { "Green" } else { "Red" })
    Write-Host "Assertion pass rate: $passRate"
    Write-Host "Total duration: $($s.total_duration_seconds)s"
    Write-Host "Total tokens: $($s.total_tokens)"
    Write-Host ""
}

# Exit code determination
if ($null -eq $containerExitCode) {
    Write-Host "=== EVAL INCONCLUSIVE (state: $state) ===" -ForegroundColor Yellow
    exit 2
} elseif ($containerExitCode -eq 0) {
    Write-Host "=== EVAL PASSED ===" -ForegroundColor Green
    exit 0
} else {
    Write-Host "=== EVAL FAILED (exit code: $containerExitCode) ===" -ForegroundColor Red
    exit 1
}
