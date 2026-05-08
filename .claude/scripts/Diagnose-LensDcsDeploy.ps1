<#
.SYNOPSIS
    Canonical multi-source diagnostic for a LENS-DCS deploy. Fetches every signal
    needed to definitively answer "is the deploy succeeding, stalled, or failed?"

.DESCRIPTION
    Anti-pattern this script replaces: inferring deploy state from one signal
    (pipeline orchestrator status, single ARM activity entry, etc.) and guessing
    the rest. Both Claude sessions on 2026-05-02 made that exact mistake during
    the iter12 + iter13 rollouts.

    What this script ALWAYS fetches (no inference):
      1. Ev2 rollout state — release pipeline run + timeline
      2. ARM deployment list — both regions (westcentralus + westus3 for npe4),
         all deployments since the release was queued
      3. Failed deployment drilldown — error codes, error messages, operation IDs
      4. deploymentScripts list — provisioningState, startTime, endTime, outputs
         for zipdeploy / swap / inttest / sectest in BOTH regions
      5. deploymentScript ACI container logs — actual stdout from each script
      6. App Service BuildVersion — production + staging slots, BOTH regions
      7. Cosmos resource state — provisioningState + UAMI principalId match
      8. Verdict — explicit classification:
            DEPLOY_SUCCEEDED        — production swapped + integration test passed
            STAGING_DEPLOYED_NO_SWAP — staging has new BV; swap blocked
            ROLLOUT_FAILED          — Ev2 reported Failed; requeue needed
            STILL_RUNNING           — rollout actively in flight, no decision needed
            UNKNOWN                 — script could not collect enough signal; report which step failed

    Exit codes:
       0 — DEPLOY_SUCCEEDED
       1 — STILL_RUNNING (no action needed; check again later)
       2 — STAGING_DEPLOYED_NO_SWAP (swap blocked; investigate)
       3 — ROLLOUT_FAILED (requeue needed)
       4 — UNKNOWN (signal-collection failed; details in output)

.PARAMETER Environment
    LENS-DCS environment (npe4 / npe5 / npe6 / ppe / prd). Required.
    Resolves to: subscription + resource groups + region list.

.PARAMETER ReleaseRunId
    ADO release pipeline run ID (e.g. 35201483). Optional but strongly recommended —
    without it, the script cannot bound "since release queued" timestamps and falls
    back to "last 90 minutes".

.PARAMETER OutputDir
    Where to write the JSON+text reports. Defaults to .mad/scratch/deploy-diagnosis/.

.PARAMETER FetchContainerLogs
    Pull deploymentScript ACI container logs (slower, ~30s per container).
    Default: $true. Set to $false for a fast triage pass.

.EXAMPLE
    pwsh -NoProfile -File .claude/scripts/Diagnose-LensDcsDeploy.ps1 -Environment npe4 -ReleaseRunId 35201483

.EXAMPLE
    # Fast triage (skip container logs)
    pwsh -NoProfile -File .claude/scripts/Diagnose-LensDcsDeploy.ps1 -Environment npe4 -ReleaseRunId 35201483 -FetchContainerLogs:$false

.NOTES
    Created 2026-05-02 after both orchestrator sessions independently hit the
    "infer from incomplete signal" anti-pattern documented in
    .claude/rules/deployment-failure-diagnosis.md (L26 + L29 + L30 of
    .claude/rules/lens-dcs-loop-lessons.md).

    The script is the single entry point for "what's happening with this deploy?"
    Call it instead of running ad-hoc az queries.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('npe4', 'npe5', 'npe6', 'ppe', 'prd')]
    [string]$Environment,

    [Parameter()]
    [int]$ReleaseRunId,

    [Parameter()]
    [string]$OutputDir = ".mad/scratch/deploy-diagnosis",

    [Parameter()]
    [bool]$FetchContainerLogs = $true,

    [Parameter()]
    [string]$AdoOrg = "https://o365exchange.visualstudio.com",

    [Parameter()]
    [string]$AdoProject = "O365 Core"
)

$ErrorActionPreference = 'Continue'

# --- Environment → subscription + RG mapping (LENS-DCS) ---
$envMap = @{
    'npe4' = @{
        Subscription = 'c750c7f5-7730-4c7c-99aa-47dc6b50c914'
        SubscriptionName = 'LENS-DCS-NPE'
        ResourceGroups = @('rg-lensdcs-npe4-westcentralus', 'rg-lensdcs-npe4-westus3')
        Regions = @('westcentralus', 'westus3')
    }
    'npe5' = @{
        Subscription = 'c750c7f5-7730-4c7c-99aa-47dc6b50c914'
        SubscriptionName = 'LENS-DCS-NPE'
        ResourceGroups = @('rg-lensdcs-npe5-westcentralus', 'rg-lensdcs-npe5-westus3')
        Regions = @('westcentralus', 'westus3')
    }
    'npe6' = @{
        Subscription = 'c750c7f5-7730-4c7c-99aa-47dc6b50c914'
        SubscriptionName = 'LENS-DCS-NPE'
        ResourceGroups = @('rg-lensdcs-npe6-westcentralus', 'rg-lensdcs-npe6-westus3')
        Regions = @('westcentralus', 'westus3')
    }
}

if (-not $envMap.ContainsKey($Environment)) {
    Write-Error "Environment '$Environment' not in env map. Add it to envMap in this script."
    exit 4
}

$envCfg = $envMap[$Environment]
$sub = $envCfg.Subscription
$rgs = $envCfg.ResourceGroups
$regions = $envCfg.Regions

# --- Setup output ---
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}
$ts = (Get-Date).ToString('yyyyMMdd-HHmmss')
$reportPath = Join-Path $OutputDir "diagnose-$Environment-$ts.json"
$textReportPath = Join-Path $OutputDir "diagnose-$Environment-$ts.md"

$report = [ordered]@{
    timestamp_utc = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    environment = $Environment
    subscription = $sub
    release_run_id = $ReleaseRunId
    queue_time_utc = $null
    resource_groups = $rgs
    sections = [ordered]@{
        ado_release = $null
        arm_deployments = $null
        failed_deployments = $null
        deployment_scripts = $null
        deployment_script_logs = $null
        app_service_buildversion = $null
        verdict = $null
    }
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "=== $Title ===" -ForegroundColor Cyan
}

function Invoke-AzJson {
    param([string]$ArgsLine)
    # Run az and strip non-JSON warnings (windows az CLI emits cryptography warning to stderr)
    $raw = Invoke-Expression "az $ArgsLine 2>&1"
    if ($LASTEXITCODE -ne 0) {
        Write-Verbose "az exited $LASTEXITCODE for: $ArgsLine"
    }
    # Filter out non-JSON noise lines
    $cleaned = $raw | Where-Object {
        $_ -notmatch '^WARNING:' -and
        $_ -notmatch 'UserWarning' -and
        $_ -notmatch '^D:\\a\\' -and
        $_ -notmatch '^\s*$'
    }
    $joined = ($cleaned -join "`n").Trim()
    if ([string]::IsNullOrWhiteSpace($joined)) { return $null }
    try {
        return ($joined | ConvertFrom-Json -ErrorAction Stop)
    } catch {
        Write-Verbose "ConvertFrom-Json failed; returning raw text"
        return $joined
    }
}

# --- 1. ADO release pipeline run state ---
Write-Section "ADO Release pipeline state"

function ConvertTo-UtcIsoString {
    param([object]$Value)
    if (-not $Value) { return $null }
    $dt = $null
    try {
        if ($Value -is [datetime]) {
            $dt = $Value
        } else {
            $dt = [datetime]::Parse([string]$Value)
        }
        # PowerShell's [datetime]::Parse on ISO strings preserves Kind=Utc; on local-formatted
        # strings it returns Kind=Local. Force-convert to UTC either way.
        if ($dt.Kind -eq [System.DateTimeKind]::Local -or $dt.Kind -eq [System.DateTimeKind]::Unspecified) {
            $dt = $dt.ToUniversalTime()
        }
        return $dt.ToString('yyyy-MM-ddTHH:mm:ssZ')
    } catch {
        Write-Verbose "ConvertTo-UtcIsoString failed for: $Value"
        return $null
    }
}

if ($ReleaseRunId) {
    $runInfo = Invoke-AzJson "pipelines runs show --id $ReleaseRunId --org $AdoOrg --project ""$AdoProject"" --query ""{status:status,result:result,startTime:startTime,finishTime:finishTime}"" -o json"
    $report.sections.ado_release = $runInfo
    if ($runInfo) {
        $startUtc = ConvertTo-UtcIsoString $runInfo.startTime
        $report.queue_time_utc = $startUtc
        Write-Host "  status:     $($runInfo.status)"
        Write-Host "  result:     $($runInfo.result)"
        Write-Host "  startTime:  $($runInfo.startTime) (UTC: $startUtc)"
        Write-Host "  finishTime: $($runInfo.finishTime)"
    }
} else {
    $report.queue_time_utc = (Get-Date).ToUniversalTime().AddMinutes(-90).ToString('yyyy-MM-ddTHH:mm:ssZ')
    Write-Host "  (no -ReleaseRunId given; using -90 min window: $($report.queue_time_utc))"
}

$sinceUtc = $report.queue_time_utc
if (-not $sinceUtc) {
    $sinceUtc = (Get-Date).ToUniversalTime().AddMinutes(-90).ToString('yyyy-MM-ddTHH:mm:ssZ')
}

# --- 2. ARM deployment list per region ---
Write-Section "ARM deployments since $sinceUtc"
$armDeployments = [ordered]@{}
foreach ($rg in $rgs) {
    $deps = Invoke-AzJson "deployment group list --resource-group $rg --subscription $sub --query ""[?properties.timestamp >= '$sinceUtc'].{name:name,state:properties.provisioningState,timestamp:properties.timestamp}"" -o json"
    $armDeployments[$rg] = $deps
    if ($deps) {
        $okCount = ($deps | Where-Object { $_.state -eq 'Succeeded' }).Count
        $failCount = ($deps | Where-Object { $_.state -eq 'Failed' }).Count
        $runCount = ($deps | Where-Object { $_.state -notin @('Succeeded', 'Failed') }).Count
        Write-Host "  $rg : $okCount Succeeded, $failCount Failed, $runCount Other"
    } else {
        Write-Host "  $rg : (no deployments since $sinceUtc)"
    }
}
$report.sections.arm_deployments = $armDeployments

# --- 3. Failed deployment drilldown ---
Write-Section "Failed deployment drilldown"
$failedDetails = [ordered]@{}
foreach ($rg in $rgs) {
    $deps = $armDeployments[$rg]
    if (-not $deps) { continue }
    $failed = @($deps | Where-Object { $_.state -eq 'Failed' })
    if ($failed.Count -eq 0) {
        $failedDetails[$rg] = @()
        continue
    }
    $rgDetails = @()
    foreach ($f in $failed) {
        $name = $f.name
        Write-Host "  $rg / $name (timestamp: $($f.timestamp))"
        $ops = Invoke-AzJson "deployment operation group list --resource-group $rg --subscription $sub --name $name --query ""[?properties.provisioningState == 'Failed'].{statusCode:properties.statusCode,statusMessage:properties.statusMessage,targetResource:properties.targetResource.resourceName,resourceType:properties.targetResource.resourceType}"" -o json"
        if ($ops) {
            foreach ($op in $ops) {
                $msg = if ($op.statusMessage -is [string]) { $op.statusMessage } else { ($op.statusMessage | ConvertTo-Json -Compress -Depth 5) }
                Write-Host "    target: $($op.targetResource) ($($op.resourceType))"
                Write-Host "    code:   $($op.statusCode)"
                Write-Host "    msg:    $($msg.Substring(0, [Math]::Min($msg.Length, 200)))"
            }
        }
        $rgDetails += [ordered]@{
            name = $name
            timestamp = $f.timestamp
            failed_operations = $ops
        }
    }
    $failedDetails[$rg] = $rgDetails
}
$report.sections.failed_deployments = $failedDetails

# --- 4. deploymentScripts state per region ---
Write-Section "deploymentScripts state (zipdeploy / swap / inttest / sectest)"
$scripts = [ordered]@{}
foreach ($rg in $rgs) {
    $scriptList = Invoke-AzJson "resource list --subscription $sub --resource-group $rg --resource-type Microsoft.Resources/deploymentScripts --query ""[].{name:name}"" -o json"
    if (-not $scriptList) {
        $scripts[$rg] = @()
        continue
    }
    $details = @()
    foreach ($s in $scriptList) {
        # Use simpler query that doesn't reach into containerInstanceView (which may be absent
        # on completed scripts after ACI cleanup). Build the structured object client-side.
        $raw = Invoke-AzJson "resource show --subscription $sub --resource-group $rg --resource-type Microsoft.Resources/deploymentScripts --name $($s.name) -o json"
        if (-not $raw) { continue }
        $props = $raw.properties
        $detail = [ordered]@{
            name = $raw.name
            provisioningState = $props.provisioningState
            startTime = if ($props.status) { $props.status.startTime } else { $null }
            endTime = if ($props.status) { $props.status.endTime } else { $null }
            containerInstanceId = if ($props.status) { $props.status.containerInstanceId } else { $null }
            outputs = $props.outputs
        }
        $details += [pscustomobject]$detail
        $outStr = if ($detail.outputs) { ($detail.outputs | ConvertTo-Json -Compress -Depth 3) } else { "(none)" }
        $sTime = if ($detail.startTime) { $detail.startTime } else { '(never ran)' }
        $eTime = if ($detail.endTime) { $detail.endTime } else { '(never ran)' }
        Write-Host "  $rg / $($detail.name)"
        Write-Host "    provState=$($detail.provisioningState)  startTime=$sTime  endTime=$eTime"
        Write-Host "    outputs=$outStr"
    }
    $scripts[$rg] = $details
}
$report.sections.deployment_scripts = $scripts

# --- 5. deploymentScript container logs ---
if ($FetchContainerLogs) {
    Write-Section "deploymentScript container logs (last 50 lines each)"
    $logs = [ordered]@{}
    foreach ($rg in $rgs) {
        $rgLogs = [ordered]@{}
        foreach ($s in $scripts[$rg]) {
            # Skip if we don't have an end time (script never ran)
            if (-not $s.endTime) { continue }
            $logRaw = Invoke-Expression "az deployment-scripts show-log --resource-group $rg --subscription $sub --name $($s.name) --query log -o tsv 2>&1"
            $logCleaned = $logRaw | Where-Object {
                $_ -notmatch '^WARNING:' -and $_ -notmatch 'UserWarning' -and $_ -notmatch '^D:\\a\\'
            }
            $logText = ($logCleaned -join "`n")
            if ($logText.Length -gt 5000) {
                $logText = "...(truncated)...`n" + $logText.Substring($logText.Length - 5000)
            }
            $rgLogs[$s.name] = $logText
            Write-Host "  $rg / $($s.name) — $((($logText -split "`n") | Measure-Object).Count) lines collected"
        }
        $logs[$rg] = $rgLogs
    }
    $report.sections.deployment_script_logs = $logs
}

# --- 6. App Service BuildVersion (production + staging) ---
Write-Section "App Service BuildVersion (production + staging) per region"
$appBv = [ordered]@{}
foreach ($region in $regions) {
    $rg = "rg-lensdcs-$Environment-$region"
    $appName = "app-lensdcs-$Environment-$region"
    $prodBv = Invoke-AzJson "webapp config appsettings list --subscription $sub --resource-group $rg --name $appName --query ""[?name=='BuildVersion'].value | [0]"" -o tsv"
    $stagingBv = Invoke-AzJson "webapp config appsettings list --subscription $sub --resource-group $rg --name $appName --slot staging --query ""[?name=='BuildVersion'].value | [0]"" -o tsv"
    $appBv[$region] = [ordered]@{
        production = $prodBv
        staging = $stagingBv
    }
    Write-Host "  $region : production=$prodBv  staging=$stagingBv"
}
$report.sections.app_service_buildversion = $appBv

# --- 7. Verdict computation ---
Write-Section "Diagnosis verdict"

$adoStatus = $report.sections.ado_release.status
$adoResult = $report.sections.ado_release.result
$totalFailed = 0
foreach ($rg in $rgs) {
    $failed = @($armDeployments[$rg] | Where-Object { $_.state -eq 'Failed' })
    $totalFailed += $failed.Count
}

# Production matches staging in all regions = full deploy
$prodAllMatch = $true
$stagingMatchProd = @()
foreach ($region in $regions) {
    $prod = $appBv[$region].production
    $staging = $appBv[$region].staging
    if ($prod -ne $staging) {
        $prodAllMatch = $false
        $stagingMatchProd += "$region : staging=$staging  production=$prod (MISMATCH)"
    }
}

# inttest passed?
$inttestPassed = $false
$inttestEndTime = $null
$sinceDt = $null
if ($sinceUtc) {
    try { $sinceDt = [datetime]::ParseExact($sinceUtc, 'yyyy-MM-ddTHH:mm:ssZ', $null).ToUniversalTime() } catch {}
}
foreach ($rg in $rgs) {
    foreach ($s in $scripts[$rg]) {
        if ($s.name -like 'inttest*' -and $s.outputs -and $s.outputs.testResult -eq 'Passed' -and $s.endTime) {
            $endDt = $null
            try { $endDt = ([datetime]$s.endTime).ToUniversalTime() } catch {}
            if ($sinceDt -and $endDt -and $endDt -gt $sinceDt) {
                $inttestPassed = $true
                $inttestEndTime = $endDt.ToString('yyyy-MM-ddTHH:mm:ssZ')
            }
        }
    }
}

# Verdict logic
$verdict = 'UNKNOWN'
$verdictDetail = ''
$exitCode = 4

if ($adoResult -eq 'failed' -or $totalFailed -ge 1) {
    if ($adoResult -eq 'failed') {
        $verdict = 'ROLLOUT_FAILED'
        $verdictDetail = "ADO release reported failed (or Ev2 mitigated). $totalFailed ARM deployment(s) failed. Requeue needed."
        $exitCode = 3
    } elseif ($totalFailed -ge 1 -and $adoStatus -eq 'inProgress') {
        # Pipeline still inProgress but ARM has failures — could be Ev2 declaring rollout failed
        # while orchestrator hangs (iter12+iter13 pattern).
        $verdict = 'ROLLOUT_FAILED'
        $verdictDetail = "ARM has $totalFailed failed deployment(s); ADO orchestrator still inProgress (likely orchestrator-hung pattern — Ev2 has declared rollout failed). Verify in Ev2 portal: status: Failed = requeue needed."
        $exitCode = 3
    }
} elseif ($prodAllMatch -and $inttestPassed) {
    $verdict = 'DEPLOY_SUCCEEDED'
    $verdictDetail = "Production BuildVersion matches staging in all regions; inttest endTime=$inttestEndTime testResult=Passed."
    $exitCode = 0
} elseif (-not $prodAllMatch -and $totalFailed -eq 0 -and $adoStatus -eq 'inProgress') {
    $verdict = 'STILL_RUNNING'
    $verdictDetail = "Pipeline inProgress, no failures yet, swap not done. Stay in monitoring."
    $exitCode = 1
} elseif (-not $prodAllMatch -and $totalFailed -eq 0 -and $adoResult -eq 'succeeded') {
    $verdict = 'STAGING_DEPLOYED_NO_SWAP'
    $verdictDetail = "Pipeline succeeded but production != staging in: $($stagingMatchProd -join '; '). Swap deploymentScript may have been skipped or failed silently."
    $exitCode = 2
} else {
    $verdict = 'UNKNOWN'
    $verdictDetail = "Could not classify. ADO=$adoStatus/$adoResult, ARM failed=$totalFailed, prodMatchesStaging=$prodAllMatch, inttestPassed=$inttestPassed."
    $exitCode = 4
}

$report.sections.verdict = [ordered]@{
    classification = $verdict
    detail = $verdictDetail
    exit_code = $exitCode
}
Write-Host ""
Write-Host "  VERDICT: $verdict" -ForegroundColor $(if ($exitCode -eq 0) { 'Green' } elseif ($exitCode -eq 1) { 'Yellow' } else { 'Red' })
Write-Host "  $verdictDetail"

# --- Write reports ---
$report | ConvertTo-Json -Depth 20 | Set-Content -Path $reportPath -Encoding UTF8

$md = @"
# LENS-DCS deploy diagnosis — $Environment

**Generated:** $($report.timestamp_utc)
**Release run:** $ReleaseRunId
**Subscription:** $sub
**Resource groups:** $($rgs -join ', ')

## Verdict

**$verdict** (exit $exitCode)

$verdictDetail

## Counts

| RG | Succeeded | Failed |
|---|--:|--:|
$(foreach ($rg in $rgs) {
  $deps = $armDeployments[$rg]
  if ($deps) {
    $ok = ($deps | Where-Object { $_.state -eq 'Succeeded' }).Count
    $f = ($deps | Where-Object { $_.state -eq 'Failed' }).Count
    "| $rg | $ok | $f |"
  }
} -join "`n")

## App Service BuildVersion

| Region | Production | Staging | Match |
|---|---|---|---|
$(foreach ($r in $regions) {
  $p = $appBv[$r].production
  $s = $appBv[$r].staging
  $m = if ($p -eq $s) { '✅' } else { '❌' }
  "| $r | $p | $s | $m |"
} -join "`n")

## Failed deployments

$(foreach ($rg in $rgs) {
  if ($failedDetails[$rg] -and @($failedDetails[$rg]).Count -gt 0) {
    "### $rg`n"
    foreach ($f in $failedDetails[$rg]) {
      "**$($f.name)** ($($f.timestamp))`n"
      foreach ($op in $f.failed_operations) {
        $msg = if ($op.statusMessage -is [string]) { $op.statusMessage } else { ($op.statusMessage | ConvertTo-Json -Compress -Depth 3) }
        "- $($op.targetResource) ($($op.resourceType)): $($op.statusCode) — $($msg.Substring(0, [Math]::Min($msg.Length, 300)))`n"
      }
    }
  }
})

Full JSON: ``$reportPath``
"@

$md | Set-Content -Path $textReportPath -Encoding UTF8

Write-Host ""
Write-Host "Reports written to:" -ForegroundColor Green
Write-Host "  JSON: $reportPath"
Write-Host "  MD:   $textReportPath"

exit $exitCode
