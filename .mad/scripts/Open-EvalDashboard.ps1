<#
.SYNOPSIS
    Bundle eval results into dashboard and open in browser.

.DESCRIPTION
    Reads all eval result JSON files from the results directory, validates them,
    embeds them into the dashboard HTML template as a JavaScript variable, and
    opens the bundled dashboard in the default browser.

    Only JSON files containing a 'run_id' field are included (non-eval files are skipped).
    Results are sorted by timestamp (newest first) in the bundled output.

.PARAMETER ResultsDir
    Directory containing eval result JSON files (default: .mad/tests/results).

.PARAMETER DashboardTemplate
    Path to dashboard HTML template (default: .mad/tests/dashboard/index.html).

.PARAMETER OutputPath
    Path for bundled output HTML (default: .mad/tests/dashboard/dashboard.html).

.PARAMETER NoOpen
    Skip opening the browser.

.PARAMETER GenerateDataFile
    Also write eval-data.js alongside the dashboard template for auto-loading on
    file:// protocol. Enabled by default. Use -GenerateDataFile:$false to skip.

.EXAMPLE
    .\Open-EvalDashboard.ps1

.EXAMPLE
    .\Open-EvalDashboard.ps1 -ResultsDir "path/to/results"

.EXAMPLE
    .\Open-EvalDashboard.ps1 -NoOpen
#>

[CmdletBinding()]
param(
    [string]$ResultsDir,
    [string]$DashboardTemplate,
    [string]$OutputPath,
    [int]$MaxBundled = 30,
    [switch]$NoOpen,
    [switch]$GenerateDataFile = $true
)

$ErrorActionPreference = "Stop"

# --- Resolve defaults relative to script location ---
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptRoot)

if (-not $ResultsDir) {
    $ResultsDir = Join-Path $ProjectRoot ".mad/tests/results"
}
if (-not $DashboardTemplate) {
    $DashboardTemplate = Join-Path $ProjectRoot ".mad/tests/dashboard/index.html"
}
if (-not $OutputPath) {
    $OutputPath = Join-Path $ProjectRoot ".mad/tests/dashboard/dashboard.html"
}

# --- Validate inputs ---
if (-not (Test-Path $ResultsDir)) {
    Write-Error "Results directory not found: $ResultsDir"
    exit 1
}
if (-not (Test-Path $DashboardTemplate)) {
    Write-Error "Dashboard template not found: $DashboardTemplate"
    exit 1
}

# --- Collect eval result JSON files ---
$JsonFiles = Get-ChildItem -Path $ResultsDir -Filter "*.json" -File
if ($JsonFiles.Count -eq 0) {
    Write-Warning "No JSON files found in $ResultsDir"
    exit 0
}

Write-Host "Found $($JsonFiles.Count) JSON file(s) in $ResultsDir"

$EvalResults = @()
$SkippedCount = 0

foreach ($File in $JsonFiles) {
    try {
        $Content = Get-Content -Path $File.FullName -Raw
        $Parsed = $Content | ConvertFrom-Json

        # Filter: only include files with a run_id field (eval results)
        if (-not $Parsed.run_id) {
            Write-Verbose "Skipping $($File.Name): no run_id field"
            $SkippedCount++
            continue
        }

        # Include partial results - dashboard JS will handle filtering
        # Note: partial results have "partial": true in their JSON

        $EvalResults += @{
            Parsed    = $Parsed
            RawJson   = $Content
            Timestamp = $Parsed.timestamp_utc
        }
    }
    catch {
        Write-Warning "Failed to parse $($File.Name): $_"
        $SkippedCount++
    }
}

if ($EvalResults.Count -eq 0) {
    Write-Warning "No valid eval result files found (all $($JsonFiles.Count) files skipped)"
    exit 0
}

# --- Sort by timestamp descending (newest first) ---
$EvalResults = $EvalResults | Sort-Object { [DateTime]$_.Timestamp } -Descending

# --- Limit bundled results ---
if ($MaxBundled -gt 0 -and $EvalResults.Count -gt $MaxBundled) {
    Write-Host "  Limiting to $MaxBundled most recent results (from $($EvalResults.Count))"
    $EvalResults = $EvalResults[0..($MaxBundled - 1)]
}

# --- Build the bundled JSON array ---
# Re-serialize each result at consistent depth to ensure valid JSON
$JsonArray = @()
foreach ($Result in $EvalResults) {
    $JsonArray += ($Result.Parsed | ConvertTo-Json -Depth 20 -Compress)
}
$BundledJson = "[`n  " + ($JsonArray -join ",`n  ") + "`n]"

# --- Build the injection script block ---
$ScriptBlock = @"
<script>
window.BUNDLED_EVAL_RESULTS = $BundledJson;
</script>
"@

# --- Read the dashboard template ---
$TemplateHtml = Get-Content -Path $DashboardTemplate -Raw

# --- Inject before </head> ---
if ($TemplateHtml -notmatch '</head>') {
    Write-Error "Dashboard template missing </head> tag: $DashboardTemplate"
    exit 1
}

$BundledHtml = $TemplateHtml -replace '</head>', "$ScriptBlock`n</head>"

# --- Ensure output directory exists ---
$OutputDir = Split-Path -Parent $OutputPath
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# --- Write bundled output ---
Set-Content -Path $OutputPath -Value $BundledHtml -Encoding UTF8

# --- Write eval-data.js for auto-loading via <script src="eval-data.js"> ---
if ($GenerateDataFile) {
    $DataFileDir = Split-Path -Parent $DashboardTemplate
    $DataFilePath = Join-Path $DataFileDir "eval-data.js"
    $DataFileContent = "window.BUNDLED_EVAL_RESULTS = $BundledJson;"
    Set-Content -Path $DataFilePath -Value $DataFileContent -Encoding UTF8
    Write-Host "  Data file: $DataFilePath"
}

Write-Host ""
Write-Host "Bundled $($EvalResults.Count) eval result(s) into dashboard"
if ($SkippedCount -gt 0) {
    Write-Host "  Skipped: $SkippedCount file(s) (no run_id or parse error)"
}
Write-Host "  Output:  $OutputPath"

# --- Open in browser ---
if (-not $NoOpen) {
    Write-Host "  Opening in browser..."
    Start-Process $OutputPath
}

Write-Host "Done."
