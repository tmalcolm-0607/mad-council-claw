<#
.SYNOPSIS
    Triggers an Ev2 deployment of a previously-built artifact to a target environment.

.DESCRIPTION
    Wraps the Ev2 release pipeline trigger. Resolves the unofficial-release pipeline
    (NPE) or official-release pipeline (PPE/PRD), queues a release with the supplied
    BuildNumber + Environment variable, and optionally polls rollout status.

    On Failed status with -Watch, prints the ARM activity-log diagnostic per
    .claude/rules/deployment-failure-diagnosis.md.

    Reads target/publish/datacollector/ev2/ServiceGroupRoot/buildver.txt for the
    BuildNumber when not explicitly supplied (per the artifact-chain hand-off
    documented in CLAUDE.md).

    Exits 0 on success, 1 on failure.

.PARAMETER Environment
    Target environment. One of npe, npe2..npe6, ppe, prd.

.PARAMETER BuildNumber
    Build version (e.g. 1.0.03400.928). Read from buildver.txt if omitted.

.PARAMETER Org
    Azure DevOps organization. Default: https://o365exchange.visualstudio.com

.PARAMETER Project
    Azure DevOps project. Default: 'O365 Core'.

.PARAMETER Watch
    If set, poll rollout status every 60s until completed.

.PARAMETER DryRun
    Print intent without making any az calls.

.EXAMPLE
    pwsh -NoProfile -File Ev2-Deploy.ps1 -Environment npe4 -Watch
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('npe','npe2','npe3','npe4','npe5','npe6','ppe','prd')]
    [string]$Environment,

    [string]$BuildNumber = '',

    [string]$Org = 'https://o365exchange.visualstudio.com',

    [string]$Project = 'O365 Core',

    [switch]$Watch,

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Write-Info([string]$Message) { Write-Host "[Ev2-Deploy] $Message" }

# 1. Resolve BuildNumber from buildver.txt if not supplied
$buildverPath = Join-Path (Get-Location) 'target/publish/datacollector/ev2/ServiceGroupRoot/buildver.txt'
if (-not $BuildNumber) {
    if (Test-Path $buildverPath) {
        $BuildNumber = (Get-Content $buildverPath -Raw).Trim()
        Write-Info "BuildNumber resolved from buildver.txt: $BuildNumber"
    } elseif (-not $DryRun) {
        Write-Error "BuildNumber not supplied and buildver.txt not found at $buildverPath. Run Ado-Build.ps1 first."
        exit 1
    } else {
        $BuildNumber = '<would-read-from-buildver.txt>'
    }
}

# 2. Pick correct release pipeline based on environment tier
$isProdTier = $Environment -in @('ppe','prd')
$releasePipeline = if ($isProdTier) { 'LENS-DCS Official Release' } else { 'LENS-DCS Unofficial Release' }

Write-Info "Environment   : $Environment"
Write-Info "BuildNumber   : $BuildNumber"
Write-Info "Release Pipe  : $releasePipeline"
Write-Info "Org/Project   : $Org / $Project"
Write-Info "Watch         : $Watch"

if ($DryRun) {
    Write-Info '[DRY-RUN] Would execute:'
    Write-Info "  1. az pipelines list --name '$releasePipeline' --query '[0].id'"
    Write-Info "  2. az pipelines run --id <releaseId> --variables Environment=$Environment BuildNumber=$BuildNumber"
    if ($Watch) {
        Write-Info '  3. Poll: az pipelines runs show --id <runId> every 60s until completed'
        Write-Info '     On Failed: print Check-AdoReleaseDeployments.ps1 hint per deployment-failure-diagnosis.md'
    }
    exit 0
}

# 3. Resolve release pipeline ID
$ErrorActionPreference = 'Continue'
$pipelineJson = az pipelines list --org $Org --project $Project --name $releasePipeline --query '[0]' -o json 2>&1 |
    Where-Object { $_ -notmatch '^\s*(WARNING|INFO|DEBUG):' }
$exitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($exitCode -ne 0 -or -not $pipelineJson) {
    Write-Error "Failed to resolve release pipeline '$releasePipeline'."
    exit 1
}
$pipeline = $pipelineJson | ConvertFrom-Json
if (-not $pipeline.id) {
    Write-Error "Pipeline '$releasePipeline' not found in $Org/$Project."
    exit 1
}
Write-Info "Release pipeline ID: $($pipeline.id)"

# 4. Queue release
$ErrorActionPreference = 'Continue'
$runJson = az pipelines run --org $Org --project $Project --id $pipeline.id `
    --variables "Environment=$Environment" "BuildNumber=$BuildNumber" -o json 2>&1
$exitCode = $LASTEXITCODE
$ErrorActionPreference = 'Stop'
if ($exitCode -ne 0) {
    Write-Error "az pipelines run failed: $runJson"
    exit 1
}
$run = ($runJson | Where-Object { $_ -notmatch '^\s*(WARNING|INFO|DEBUG):' }) | ConvertFrom-Json
$runId = $run.id
Write-Info "Queued release run $runId (Environment=$Environment, BuildNumber=$BuildNumber)"
Write-Info "  NOTE: 'Rollout: succeeded' is NOT proof that ARM resources updated."
Write-Info "  If the env doesn't reflect the new build, run Check-AdoReleaseDeployments.ps1"
Write-Info "  per .claude/rules/deployment-failure-diagnosis.md."

if (-not $Watch) {
    Write-Info "Run queued; not watching. Use az pipelines runs show --id $runId to follow."
    exit 0
}

# 5. Poll status
do {
    Start-Sleep -Seconds 60
    $ErrorActionPreference = 'Continue'
    $statusJson = az pipelines runs show --org $Org --project $Project --id $runId -o json 2>&1
    $exitCode = $LASTEXITCODE
    $ErrorActionPreference = 'Stop'
    if ($exitCode -ne 0) {
        Write-Info 'WARN: poll failed; continuing'
        continue
    }
    $status = ($statusJson | Where-Object { $_ -notmatch '^\s*(WARNING|INFO|DEBUG):' }) | ConvertFrom-Json
    Write-Info "  run $runId status=$($status.status) result=$($status.result)"
    if ($status.status -eq 'completed') { break }
} while ($true)

if ($status.result -ne 'succeeded') {
    Write-Info "Release Failed. Diagnose with:"
    Write-Info "  pwsh -NoProfile -File .claude/scripts/Check-AdoReleaseDeployments.ps1 -ResourceGroup <rg> -Subscription <sub>"
    Write-Info "  (per .claude/rules/deployment-failure-diagnosis.md)"
    exit 1
}
Write-Info "Release succeeded. Verify deployed env state before declaring victory."
exit 0
