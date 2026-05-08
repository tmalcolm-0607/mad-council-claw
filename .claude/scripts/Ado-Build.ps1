<#
.SYNOPSIS
    Queues an Azure DevOps pipeline build and polls until it completes.

.DESCRIPTION
    Wraps `az pipelines run` + `az pipelines runs show` polling into one idempotent call.
    Resolves the pipeline ID from a human-readable name, queues against the supplied
    branch, then waits for completion. Prints final result + buildNumber + drop URL.

    Exits 0 on success, 1 on failure.

.PARAMETER PipelineName
    Human-readable pipeline display name. Resolved to an ID via `az pipelines list`.

.PARAMETER Branch
    Source branch to build (e.g. users/tonym/lens-standardization).

.PARAMETER Org
    Azure DevOps organization URL. Default: https://o365exchange.visualstudio.com

.PARAMETER Project
    Azure DevOps project name. Default: 'O365 Core'.

.PARAMETER Variables
    Hashtable of pipeline variables (e.g. @{ Environment = 'npe4' }). Optional.

.PARAMETER PollSeconds
    Polling interval. Default: 60.

.PARAMETER MaxWaitMinutes
    Total max wait before giving up. Default: 60.

.PARAMETER DryRun
    Print the intent (resolved pipeline lookup, queue command, polling plan) without
    executing any az calls.

.EXAMPLE
    pwsh -NoProfile -File Ado-Build.ps1 `
        -PipelineName 'LENS-DCS Unofficial Build' `
        -Branch 'users/tonym/lens-standardization'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$PipelineName,

    [Parameter(Mandatory)]
    [string]$Branch,

    [string]$Org = 'https://o365exchange.visualstudio.com',

    [string]$Project = 'O365 Core',

    [hashtable]$Variables = @{},

    [int]$PollSeconds = 60,

    [int]$MaxWaitMinutes = 60,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) { Write-Host "[Ado-Build] $Message" }

function Format-Variables([hashtable]$Vars) {
    if (-not $Vars -or $Vars.Count -eq 0) { return '(none)' }
    ($Vars.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ', '
}

Write-Info "PipelineName : $PipelineName"
Write-Info "Branch       : $Branch"
Write-Info "Org/Project  : $Org / $Project"
Write-Info "Variables    : $(Format-Variables $Variables)"
Write-Info "Poll/MaxWait : ${PollSeconds}s / ${MaxWaitMinutes}m"

if ($DryRun) {
    Write-Info '[DRY-RUN] Would execute:'
    Write-Info "  1. az pipelines list --org '$Org' --project '$Project' --name '$PipelineName' --query '[0].id'"
    $varArgs = if ($Variables.Count -gt 0) {
        ' --variables ' + (($Variables.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join ' ')
    } else { '' }
    Write-Info "  2. az pipelines run --id <pipelineId> --branch '$Branch'$varArgs"
    Write-Info "  3. Poll: az pipelines runs show --id <buildId> every ${PollSeconds}s up to ${MaxWaitMinutes}m"
    Write-Info "  4. Print buildNumber + status + drop URL"
    exit 0
}

# 1. Resolve pipeline ID
Write-Info 'Resolving pipeline ID...'
$ErrorActionPreference = 'Continue'
$pipelineJson = az pipelines list --org $Org --project $Project --name $PipelineName --query '[0]' -o json 2>&1 |
    Where-Object { $_ -notmatch '^\s*(WARNING|INFO|DEBUG):' }
$exitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($exitCode -ne 0 -or -not $pipelineJson) {
    Write-Error "Failed to resolve pipeline '$PipelineName'. Is the user logged in via az devops login?"
    exit 1
}
$pipeline = $pipelineJson | ConvertFrom-Json
if (-not $pipeline.id) {
    Write-Error "No pipeline matched name '$PipelineName' in $Org/$Project."
    exit 1
}
Write-Info "Pipeline ID: $($pipeline.id)"

# 2. Queue build
$varArgList = @()
foreach ($entry in $Variables.GetEnumerator()) { $varArgList += "$($entry.Key)=$($entry.Value)" }
$ErrorActionPreference = 'Continue'
if ($varArgList.Count -gt 0) {
    $runJson = az pipelines run --org $Org --project $Project --id $pipeline.id --branch $Branch --variables @varArgList -o json 2>&1
} else {
    $runJson = az pipelines run --org $Org --project $Project --id $pipeline.id --branch $Branch -o json 2>&1
}
$exitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($exitCode -ne 0) {
    Write-Error "az pipelines run failed: $runJson"
    exit 1
}
$run = ($runJson | Where-Object { $_ -notmatch '^\s*(WARNING|INFO|DEBUG):' }) | ConvertFrom-Json
$buildId = $run.id
Write-Info "Queued build $buildId (buildNumber=$($run.buildNumber))"

# 3. Poll until completed
$deadline = (Get-Date).AddMinutes($MaxWaitMinutes)
do {
    Start-Sleep -Seconds $PollSeconds
    $ErrorActionPreference = 'Continue'
    $statusJson = az pipelines runs show --org $Org --project $Project --id $buildId -o json 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($exitCode -ne 0) {
        Write-Info "WARN: poll failed; continuing"
        continue
    }
    $status = ($statusJson | Where-Object { $_ -notmatch '^\s*(WARNING|INFO|DEBUG):' }) | ConvertFrom-Json
    Write-Info "  build $buildId status=$($status.status) result=$($status.result)"
    if ($status.status -eq 'completed') { break }
} while ((Get-Date) -lt $deadline)

if ($status.status -ne 'completed') {
    Write-Error "Build $buildId did not complete within ${MaxWaitMinutes} minutes (last status=$($status.status))."
    exit 1
}

# 4. Final report
Write-Info "Build complete. result=$($status.result) buildNumber=$($status.buildNumber)"
$dropUrl = $status._links.web.href
if ($dropUrl) { Write-Info "Web URL: $dropUrl" }
if ($status.result -ne 'succeeded') { exit 1 }
exit 0
