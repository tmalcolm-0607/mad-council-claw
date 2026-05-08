<#
.SYNOPSIS
    Measure diff coverage by comparing git diff hunks against Cobertura XML coverage data.

.DESCRIPTION
    Calculates what percentage of changed executable lines (vs a base branch) are
    covered by tests. This enforces the 100% diff coverage target locally before
    pushing to ADO.

.PARAMETER SolutionPath
    Path to .sln file. Auto-discovers LENS-CMS if not specified.

.PARAMETER BaseBranch
    Branch to diff against (default: origin/master).

.PARAMETER Threshold
    Minimum diff coverage percentage to pass (default: 100).

.PARAMETER Json
    Output JSON for programmatic consumption.

.PARAMETER Verbose
    Show per-line detail.

.EXAMPLE
    .\Measure-DiffCoverage.ps1
    .\Measure-DiffCoverage.ps1 -BaseBranch "origin/main" -Threshold 90
    .\Measure-DiffCoverage.ps1 -Json | ConvertFrom-Json
#>
[CmdletBinding()]
param(
    [string]$SolutionPath,
    [string]$BaseBranch = "origin/master",
    [int]$Threshold = 100,
    [switch]$Json,
    [switch]$ShowVerbose
)

$ErrorActionPreference = "Stop"

# --- Auto-discover solution ---
if (-not $SolutionPath) {
    $candidates = @(
        "C:\source\CCGHCP\src\LENS-CMS\sources\dev\CMS\src\CMS.sln",
        "C:\source\CCGHCP\src\LENS-CMS\src\CMS.sln",
        "C:\source\LENS-CMS\src\CMS.sln"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) {
            $SolutionPath = $c
            break
        }
    }
    if (-not $SolutionPath) {
        Write-Error "Could not auto-discover solution. Specify -SolutionPath."
    }
}

$SolutionDir = Split-Path $SolutionPath -Parent

# --- Step 1: Get changed .cs files ---
$repoRoot = git -C $SolutionDir rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    Write-Error "Not inside a git repository."
}

$changedFiles = git -C $repoRoot diff $BaseBranch --name-only --diff-filter=d -- '*.cs' 2>$null
if (-not $changedFiles) {
    # No changed .cs files - pass
    if ($Json) {
        $result = @{
            baseBranch = $BaseBranch
            totalChangedLines = 0
            coveredLines = 0
            uncoveredLines = 0
            diffCoveragePercent = 100.0
            threshold = $Threshold
            pass = $true
            files = @()
            uncoveredDetails = @()
        }
        $result | ConvertTo-Json -Depth 5
    } else {
        Write-Host ""
        Write-Host "=== Diff Coverage Report ===" -ForegroundColor Cyan
        Write-Host "Base: $BaseBranch"
        Write-Host "Changed .cs files: 0"
        Write-Host ""
        Write-Host "No changed .cs files. Nothing to measure." -ForegroundColor Green
        Write-Host "Result: PASS"
    }
    exit 0
}

$changedFileList = $changedFiles -split "`n" | Where-Object { $_.Trim() -ne "" }

# --- Step 2: Parse diff hunks to get exact changed line numbers ---
$diffOutput = git -C $repoRoot diff $BaseBranch -U0 -- '*.cs' 2>$null
$changedLinesByFile = @{}

$currentFile = $null
foreach ($line in ($diffOutput -split "`n")) {
    $line = $line.TrimEnd("`r")

    # Match +++ b/path/to/file.cs
    if ($line -match '^\+\+\+ b/(.+)$') {
        $currentFile = $Matches[1]
        if (-not $changedLinesByFile.ContainsKey($currentFile)) {
            $changedLinesByFile[$currentFile] = [System.Collections.Generic.List[int]]::new()
        }
        continue
    }

    # Match @@ -old,count +new,count @@ context
    if ($line -match '^@@ .+ \+(\d+)(?:,(\d+))? @@') {
        $startLine = [int]$Matches[1]
        $count = if ($Matches[2]) { [int]$Matches[2] } else { 1 }
        if ($currentFile -and $count -gt 0) {
            for ($i = $startLine; $i -lt ($startLine + $count); $i++) {
                $changedLinesByFile[$currentFile].Add($i)
            }
        }
    }
}

# --- Step 3: Find Cobertura XML coverage files ---
$coverageFiles = Get-ChildItem -Path $SolutionDir -Recurse -Filter "coverage.cobertura.xml" -ErrorAction SilentlyContinue
if ($coverageFiles.Count -eq 0) {
    Write-Error "No coverage.cobertura.xml files found under $SolutionDir. Run 'dotnet test --collect:`"XPlat Code Coverage`"' first."
}

# Parse all Cobertura XMLs and merge line coverage
# Key: normalized relative path, Value: hashtable of line# -> max hits
$coverageByFile = @{}

foreach ($covFile in $coverageFiles) {
    [xml]$xml = Get-Content $covFile.FullName

    # Cobertura XML has packages/package/classes/class elements
    $classes = $xml.SelectNodes("//class")
    foreach ($class in $classes) {
        $filename = $class.GetAttribute("filename")
        if (-not $filename) { continue }

        # Normalize path separators to forward slashes for matching
        $normalizedPath = $filename -replace '\\', '/'

        if (-not $coverageByFile.ContainsKey($normalizedPath)) {
            $coverageByFile[$normalizedPath] = @{}
        }

        $lines = $class.SelectNodes("lines/line")
        foreach ($lineNode in $lines) {
            $lineNum = [int]$lineNode.GetAttribute("number")
            $hits = [int]$lineNode.GetAttribute("hits")

            if ($coverageByFile[$normalizedPath].ContainsKey($lineNum)) {
                # Merge: a line is covered if ANY test project covers it
                $existing = $coverageByFile[$normalizedPath][$lineNum]
                if ($hits -gt $existing) {
                    $coverageByFile[$normalizedPath][$lineNum] = $hits
                }
            } else {
                $coverageByFile[$normalizedPath][$lineNum] = $hits
            }
        }
    }
}

# --- Step 4: Cross-reference changed lines with coverage ---
$totalCovered = 0
$totalUncovered = 0
$fileResults = @()
$uncoveredDetails = @()

foreach ($file in $changedFileList) {
    $normalizedFile = $file -replace '\\', '/'
    $changedLines = $changedLinesByFile[$normalizedFile]
    if (-not $changedLines -or $changedLines.Count -eq 0) {
        continue
    }

    # Find matching coverage entry - try multiple path patterns
    $covEntry = $null
    foreach ($covPath in $coverageByFile.Keys) {
        $normalizedCovPath = $covPath -replace '\\', '/'
        if ($normalizedCovPath -eq $normalizedFile -or
            $normalizedCovPath.EndsWith("/$normalizedFile") -or
            $normalizedFile.EndsWith("/$normalizedCovPath") -or
            $normalizedCovPath.EndsWith($normalizedFile) -or
            $normalizedFile.EndsWith($normalizedCovPath)) {
            $covEntry = $coverageByFile[$covPath]
            break
        }
    }

    $fileCovered = 0
    $fileUncovered = 0
    $fileSkipped = 0
    $fileUncoveredLines = @()

    foreach ($lineNum in $changedLines) {
        if ($covEntry -and $covEntry.ContainsKey($lineNum)) {
            if ($covEntry[$lineNum] -gt 0) {
                $fileCovered++
            } else {
                $fileUncovered++
                $fileUncoveredLines += $lineNum
            }
        } else {
            # No line entry in coverage XML - non-executable (braces, comments, blank, declarations)
            $fileSkipped++
        }
    }

    $executableLines = $fileCovered + $fileUncovered

    if (-not $covEntry) {
        # File not in any Cobertura XML
        $fileResults += @{
            file = $normalizedFile
            coveredLines = 0
            uncoveredLines = 0
            skippedLines = $changedLines.Count
            executableLines = 0
            percent = -1
            warning = "File not found in coverage data"
        }
    } elseif ($executableLines -eq 0) {
        $fileResults += @{
            file = $normalizedFile
            coveredLines = 0
            uncoveredLines = 0
            skippedLines = $fileSkipped
            executableLines = 0
            percent = -1
            warning = $null
        }
    } else {
        $pct = [math]::Round(($fileCovered / $executableLines) * 100, 1)
        $fileResults += @{
            file = $normalizedFile
            coveredLines = $fileCovered
            uncoveredLines = $fileUncovered
            skippedLines = $fileSkipped
            executableLines = $executableLines
            percent = $pct
            warning = $null
        }
        $totalCovered += $fileCovered
        $totalUncovered += $fileUncovered

        foreach ($ln in $fileUncoveredLines) {
            $uncoveredDetails += @{
                file = $normalizedFile
                line = $ln
            }
        }
    }
}

# --- Step 5: Calculate totals ---
$totalExecutable = $totalCovered + $totalUncovered
$diffCoveragePct = if ($totalExecutable -gt 0) {
    [math]::Round(($totalCovered / $totalExecutable) * 100, 1)
} else {
    100.0
}

$pass = $diffCoveragePct -ge $Threshold

# --- Step 6: Output ---
if ($Json) {
    $result = @{
        baseBranch = $BaseBranch
        totalChangedLines = $totalExecutable
        coveredLines = $totalCovered
        uncoveredLines = $totalUncovered
        diffCoveragePercent = $diffCoveragePct
        threshold = $Threshold
        pass = $pass
        files = $fileResults
        uncoveredDetails = $uncoveredDetails
    }
    $result | ConvertTo-Json -Depth 5
} else {
    Write-Host ""
    Write-Host "=== Diff Coverage Report ===" -ForegroundColor Cyan
    Write-Host "Base: $BaseBranch"
    Write-Host "Changed .cs files: $($changedFileList.Count)"
    Write-Host ""

    foreach ($fr in $fileResults) {
        if ($fr.warning) {
            Write-Host "  $($fr.file)" -NoNewline
            Write-Host "    WARN: $($fr.warning)" -ForegroundColor DarkYellow
        } elseif ($fr.executableLines -eq 0) {
            Write-Host "  $($fr.file)" -NoNewline
            Write-Host "    0 executable lines (skip)" -ForegroundColor DarkGray
        } else {
            $color = if ($fr.percent -ge $Threshold) { "Green" } else { "Red" }
            $tag = if ($fr.uncoveredLines -gt 0) { "  <- UNCOVERED" } else { "" }
            Write-Host "  $($fr.file)" -NoNewline
            Write-Host "    $($fr.coveredLines)/$($fr.executableLines) lines ($($fr.percent)%)$tag" -ForegroundColor $color
        }
    }

    Write-Host ""
    $totalColor = if ($pass) { "Green" } else { "Red" }
    Write-Host "Total: $totalCovered/$totalExecutable changed executable lines covered ($diffCoveragePct%)" -ForegroundColor $totalColor
    Write-Host "Threshold: $Threshold%"

    if ($pass) {
        Write-Host "Result: PASS" -ForegroundColor Green
    } else {
        Write-Host "Result: FAIL - $totalUncovered uncovered line(s)" -ForegroundColor Red
        Write-Host ""
        Write-Host "Uncovered lines:" -ForegroundColor Red
        foreach ($ud in $uncoveredDetails) {
            Write-Host "  $($ud.file):$($ud.line)" -ForegroundColor DarkYellow
        }
    }
}

if (-not $pass) {
    exit 1
}
