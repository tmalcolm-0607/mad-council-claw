<#
.SYNOPSIS
    Validates a Connect draft against character limits and style rules.

.DESCRIPTION
    Reads a Connect draft (markdown), measures each section against the
    Microsoft Connect form character limits, and runs the style-lint pass
    on the content. Reports a per-section status table.

    Section limits (per Connect form, plain-text body):
        - "What results have you delivered, and how did you do it?" : 6000
        - "Reflect on recent setbacks - what did you learn and how did you grow?" : 1000
        - "How will your actions and behaviors help you reach your goals?" : 1000

.PARAMETER Path
    Path to the connect-draft.md file. Required.

.PARAMETER NoStyleLint
    Skip the style-lint pass; only check character limits.

.PARAMETER Json
    Output structured JSON instead of human-readable report.

.EXAMPLE
    .\connect-validate.ps1 -Path .mad/reports/connect-prep-2026/connect-draft.md
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Path,

    [Parameter(Mandatory)]
    [string]$Profile,

    [switch]$NoStyleLint,
    [switch]$Json
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $Path)) {
    Write-Error "File not found: $Path"
    exit 2
}

$lines = Get-Content -Path $Path -Encoding UTF8

# --- Section definitions ---
$sections = @(
    @{
        Name        = "Results"
        Header      = "### What results have you delivered, and how did you do it?"
        NextHeader  = "### Reflect on recent setbacks"
        Limit       = 6000
    },
    @{
        Name        = "Setbacks"
        Header      = "### Reflect on recent setbacks"
        NextHeader  = "### What are your goals"
        Limit       = 1000
    },
    @{
        Name        = "Goals"
        Header      = "### What are your goals"
        NextHeader  = "### How will your actions"
        Limit       = $null  # No limit specified
    },
    @{
        Name        = "How"
        Header      = "### How will your actions"
        NextHeader  = "---"
        Limit       = 1000
    }
)

# --- Extract sections ---
$results = @()
foreach ($section in $sections) {
    $startIdx = -1
    $endIdx = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($startIdx -eq -1 -and $lines[$i] -like "$($section.Header)*") {
            $startIdx = $i + 1  # skip the header line itself
        } elseif ($startIdx -ne -1 -and $lines[$i] -like "$($section.NextHeader)*") {
            $endIdx = $i
            break
        }
    }
    if ($startIdx -eq -1) {
        $results += [PSCustomObject]@{
            Section   = $section.Name
            Found     = $false
            Limit     = $section.Limit
            CharCount = 0
            Status    = "missing"
            Variance  = $null
        }
        continue
    }
    $bodyLines = $lines[$startIdx..($endIdx - 1)]
    $body = ($bodyLines -join "`n").Trim()
    $charCount = $body.Length

    $status = if ($null -eq $section.Limit) {
        "no-limit"
    } elseif ($charCount -le $section.Limit) {
        "under"
    } else {
        "OVER"
    }
    $variance = if ($null -ne $section.Limit) { $charCount - $section.Limit } else { $null }

    $results += [PSCustomObject]@{
        Section   = $section.Name
        Found     = $true
        Limit     = $section.Limit
        CharCount = $charCount
        Status    = $status
        Variance  = $variance
    }
}

# --- Style lint pass ---
$lintViolations = @()
if (-not $NoStyleLint) {
    $lintScript = Join-Path $PSScriptRoot "style-lint.ps1"
    if (Test-Path $lintScript) {
        $lintTmp = New-TemporaryFile
        $tmpJson = "$($lintTmp.FullName).json"
        try {
            $oldDir = Get-Location
            Set-Location -Path (Split-Path $Path -Parent)
            $relPath = Split-Path $Path -Leaf
            & powershell.exe -NoProfile -File $lintScript -Path $relPath -Profile $Profile -OutputJson 2>&1 | Out-Null
        } finally {
            Set-Location -Path $oldDir
        }
        # Find the most recent style-lint output
        $latest = Get-ChildItem ".mad/scratch/style-lint-*.json" -ErrorAction SilentlyContinue |
                    Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if ($latest) {
            $lintReport = Get-Content $latest.FullName -Raw | ConvertFrom-Json
            $lintViolations = $lintReport.Violations
        }
    }
}

# --- Output ---
if ($Json) {
    $report = [PSCustomObject]@{
        File              = $Path
        Generated         = (Get-Date -Format "o")
        Sections          = $results
        StyleViolations   = $lintViolations
        OverallPass       = (-not ($results | Where-Object Status -eq "OVER")) -and
                            (-not ($lintViolations | Where-Object Severity -eq "error"))
    }
    $report | ConvertTo-Json -Depth 5
} else {
    Write-Host ""
    Write-Host "=== Connect Validation: $Path ===" -ForegroundColor Cyan
    Write-Host ""
    Write-Host ("{0,-12} {1,-7} {2,8} {3,8} {4}" -f "Section", "Status", "Chars", "Limit", "Variance")
    Write-Host ("{0,-12} {1,-7} {2,8} {3,8} {4}" -f "-------", "------", "-----", "-----", "--------")
    foreach ($r in $results) {
        $color = switch ($r.Status) {
            "OVER"     { "Red" }
            "under"    { "Green" }
            "no-limit" { "Gray" }
            "missing"  { "Yellow" }
        }
        $varDisplay = if ($null -eq $r.Variance) { "-" } elseif ($r.Variance -gt 0) { "+$($r.Variance)" } else { "$($r.Variance)" }
        $limitDisplay = if ($null -eq $r.Limit) { "-" } else { "$($r.Limit)" }
        Write-Host ("{0,-12} {1,-7} {2,8} {3,8} {4}" -f $r.Section, $r.Status, $r.CharCount, $limitDisplay, $varDisplay) -ForegroundColor $color
    }
    Write-Host ""
    if ($lintViolations.Count -gt 0) {
        Write-Host "=== Style violations ===" -ForegroundColor Yellow
        $errCount = ($lintViolations | Where-Object Severity -eq "error").Count
        $warnCount = ($lintViolations | Where-Object Severity -eq "warning").Count
        Write-Host ("  Errors: {0}, Warnings: {1}" -f $errCount, $warnCount)
        Write-Host ""
    }

    $allUnder = -not ($results | Where-Object Status -eq "OVER")
    $cleanLint = -not ($lintViolations | Where-Object Severity -eq "error")
    if ($allUnder -and $cleanLint) {
        Write-Host "PASS: all section limits met and no style errors." -ForegroundColor Green
    } else {
        Write-Host "FAIL: see violations above." -ForegroundColor Red
    }
    Write-Host ""
}

# --- Exit code ---
$failCount = ($results | Where-Object Status -eq "OVER").Count
$errCount = ($lintViolations | Where-Object Severity -eq "error").Count
if ($failCount -gt 0 -or $errCount -gt 0) { exit 1 }
exit 0
