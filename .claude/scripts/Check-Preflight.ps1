<#
.SYNOPSIS
    Mechanical pre-flight checks using grep/find. Zero LLM cost, runs in seconds.
    Catches structural issues that agents consistently miss.

.DESCRIPTION
    Runs 9 deterministic checks on a project directory:
    1. UNUSED EXPORTS: Exported functions/components with 0 imports elsewhere
    2. API CALL COVERAGE: Frontend fetch URLs found in source
    3. CSS FRAMEWORK: Tailwind classes without Tailwind installed
    4. ERROR BOUNDARIES: Missing ErrorBoundary in React apps
    5. TODO/FIXME COUNT: Threshold-based (warn >10, fail >25)
    6. TEST COVERAGE GAP: Source files missing corresponding test files
    7. MOCK/REAL DRIFT: Mock API classes vs real API client method counts
    8. INTEGRATION SURFACE: NotImplementedException count + interface/implementation ratio
    9. FEATURE MAP STALENESS: .mad/feature-map.json freshness vs newest spec file

.PARAMETER ProjectRoot
    Root directory of the project to check. Required.

.PARAMETER Check
    Run only specific check(s). Comma-separated list of check numbers (1-9).
    Default: run all checks.

.PARAMETER GitDiffBase
    Git ref to diff against for test coverage gap check (default: HEAD~10).
    Use 'none' to check all files instead of just changed ones.

.PARAMETER FailOnWarn
    Treat warnings as failures (exit code 1).

.EXAMPLE
    .\Check-Preflight.ps1 -ProjectRoot C:\source\consumer-project\sources\dev\WebClient
    .\Check-Preflight.ps1 -ProjectRoot C:\source\project -Check 1,3,5
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ProjectRoot,

    [string]$Check = "",

    [string]$GitDiffBase = "HEAD~10",

    [switch]$FailOnWarn
)

$ErrorActionPreference = 'Continue'
$ProjectRoot = (Resolve-Path $ProjectRoot -ErrorAction Stop).Path

$results = @()
$warnings = 0
$failures = 0

function Add-Result {
    param([string]$CheckName, [string]$Status, [string]$Detail)
    $script:results += [PSCustomObject]@{ Check = $CheckName; Status = $Status; Detail = $Detail }
    if ($Status -eq 'FAIL') { $script:failures++ }
    elseif ($Status -eq 'WARN') { $script:warnings++ }
}

function Should-Run {
    param([int]$Number)
    if ($Check -eq "") { return $true }
    return ($Check -split ',' | ForEach-Object { $_.Trim() }) -contains "$Number"
}

# Detect project type
$srcDir = Join-Path $ProjectRoot "src"
$hasSrc = Test-Path $srcDir
$pkgJsonPath = Join-Path $ProjectRoot "package.json"
$isReact = Test-Path $pkgJsonPath
$isDotNet = ($null -ne (Get-ChildItem $ProjectRoot -Filter "*.csproj" -Recurse -Depth 3 -ErrorAction SilentlyContinue | Select-Object -First 1))

# Helper: search files for pattern, return match count
function Count-Matches {
    param([string]$Path, [string]$Pattern, [string[]]$Include)
    $count = 0
    Get-ChildItem $Path -Recurse -Include $Include -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch 'node_modules|\.test\.|\.spec\.|__mocks__|bin[\\/]|obj[\\/]' } |
        ForEach-Object {
            $matches = Select-String -Path $_.FullName -Pattern $Pattern -AllMatches -ErrorAction SilentlyContinue
            $count += ($matches | Measure-Object).Count
        }
    return $count
}

# ============================================================
# CHECK 1: UNUSED EXPORTS (React/TS projects)
# ============================================================
if ((Should-Run 1) -and $isReact -and $hasSrc) {
    Write-Host "`n--- Check 1: Unused Exports ---" -ForegroundColor Cyan
    $unusedCount = 0
    $unusedList = @()

    $sourceFiles = Get-ChildItem $srcDir -Recurse -Include "*.ts","*.tsx" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -notmatch '\.(test|spec|stories|d)\.' -and $_.FullName -notmatch 'node_modules|__mocks__' }

    foreach ($file in $sourceFiles) {
        $exportLines = Select-String -Path $file.FullName -Pattern '^export (function|const|class|default|enum|interface|type) (\w+)' -ErrorAction SilentlyContinue
        foreach ($exportLine in $exportLines) {
            if ($exportLine.Matches[0].Groups.Count -ge 3) {
                $name = $exportLine.Matches[0].Groups[2].Value
                if ($name -match '^(App|main|index|Root|default)$') { continue }

                $importMatches = Get-ChildItem $srcDir -Recurse -Include "*.ts","*.tsx" -ErrorAction SilentlyContinue |
                    Where-Object { $_.FullName -ne $file.FullName -and $_.FullName -notmatch 'node_modules' } |
                    Select-String -Pattern "\b$name\b" -ErrorAction SilentlyContinue |
                    Select-Object -First 1

                if ($null -eq $importMatches) {
                    $unusedCount++
                    $relPath = $file.FullName.Replace($ProjectRoot, '').TrimStart('\', '/')
                    $unusedList += "  $relPath : $name"
                }
            }
        }
        # Performance: limit to first 100 files
        if ($unusedCount -gt 20) { break }
    }

    if ($unusedCount -gt 10) {
        Add-Result "1. Unused Exports" "WARN" "$unusedCount exported symbols with 0 imports found"
        $unusedList | Select-Object -First 5 | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
    }
    else {
        Add-Result "1. Unused Exports" "PASS" "$unusedCount unused exports (under threshold)"
    }
}
elseif (Should-Run 1) {
    Add-Result "1. Unused Exports" "SKIP" "Not a React/TS project or no src/"
}

# ============================================================
# CHECK 2: API CALL COVERAGE
# ============================================================
if ((Should-Run 2) -and $isReact -and $hasSrc) {
    Write-Host "`n--- Check 2: API Call Coverage ---" -ForegroundColor Cyan

    $apiUrls = @()
    Get-ChildItem $srcDir -Recurse -Include "*.ts","*.tsx" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch 'node_modules|\.test\.|\.spec\.' } |
        ForEach-Object {
            $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
            $urlMatches = [regex]::Matches($content, '[''"`](/api/[^''"`\s]+)[''"`]')
            foreach ($m in $urlMatches) { $apiUrls += $m.Groups[1].Value }
        }

    $unique = $apiUrls | Sort-Object -Unique
    $urlCount = ($unique | Measure-Object).Count

    if ($urlCount -gt 0) {
        Add-Result "2. API Call Coverage" "PASS" "$urlCount unique API URL patterns found"
        $unique | Select-Object -First 10 | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
    }
    else {
        Add-Result "2. API Call Coverage" "PASS" "No /api/ URLs found (may use abstraction layer)"
    }
}
elseif (Should-Run 2) {
    Add-Result "2. API Call Coverage" "SKIP" "Not a frontend project"
}

# ============================================================
# CHECK 3: CSS FRAMEWORK MISMATCH
# ============================================================
if ((Should-Run 3) -and $isReact -and $hasSrc) {
    Write-Host "`n--- Check 3: CSS Framework Mismatch ---" -ForegroundColor Cyan

    $tailwindCount = Count-Matches -Path $srcDir -Pattern '\b(flex|grid|p-\d|m-\d|text-\w+-\d|bg-\w+-\d|rounded-\w|shadow-\w|border-\w)\b' -Include "*.tsx","*.jsx"

    $hasTailwindConfig = (Test-Path (Join-Path $ProjectRoot "tailwind.config.js")) -or
                         (Test-Path (Join-Path $ProjectRoot "tailwind.config.ts")) -or
                         (Test-Path (Join-Path $ProjectRoot "tailwind.config.mjs"))

    $hasTailwindDep = $false
    if (Test-Path $pkgJsonPath) {
        $hasTailwindDep = (Get-Content $pkgJsonPath -Raw) -match '"tailwindcss"'
    }

    if ($tailwindCount -gt 5 -and -not $hasTailwindConfig -and -not $hasTailwindDep) {
        Add-Result "3. CSS Framework" "FAIL" "$tailwindCount Tailwind-like classes found but no tailwind config or dependency"
    }
    elseif ($tailwindCount -gt 0 -and ($hasTailwindConfig -or $hasTailwindDep)) {
        Add-Result "3. CSS Framework" "PASS" "Tailwind classes found with config present"
    }
    else {
        Add-Result "3. CSS Framework" "PASS" "No Tailwind class usage detected"
    }
}
elseif (Should-Run 3) {
    Add-Result "3. CSS Framework" "SKIP" "Not a React project"
}

# ============================================================
# CHECK 4: ERROR BOUNDARIES (React)
# ============================================================
if ((Should-Run 4) -and $isReact -and $hasSrc) {
    Write-Host "`n--- Check 4: Error Boundaries ---" -ForegroundColor Cyan

    $ebCount = Count-Matches -Path $srcDir -Pattern 'ErrorBoundary|errorBoundary|error-boundary' -Include "*.ts","*.tsx"

    if ($ebCount -eq 0) {
        Add-Result "4. Error Boundaries" "WARN" "No ErrorBoundary found in React app"
    }
    else {
        Add-Result "4. Error Boundaries" "PASS" "$ebCount ErrorBoundary references found"
    }
}
elseif (Should-Run 4) {
    Add-Result "4. Error Boundaries" "SKIP" "Not a React project"
}

# ============================================================
# CHECK 5: TODO/FIXME/HACK COUNT (with categorization)
# ============================================================
if (Should-Run 5) {
    Write-Host "`n--- Check 5: TODO/FIXME/HACK Count ---" -ForegroundColor Cyan

    $searchDir = if ($hasSrc) { $srcDir } else { $ProjectRoot }
    $includes = @("*.ts","*.tsx","*.cs","*.py","*.go")

    # Total count
    $todoCount = Count-Matches -Path $searchDir -Pattern 'TODO|FIXME|HACK|XXX' -Include $includes

    # Categorize: integration gaps (count separately)
    $integrationGapCount = Count-Matches -Path $searchDir -Pattern 'TODO:?\s*(implement|wire.?up|real.?API|connect|integrate|register)' -Include $includes

    # Categorize: quality gaps
    $qualityGapCount = Count-Matches -Path $searchDir -Pattern 'TODO:?\s*(error.?handling|validation|sanitiz|logging|retry)' -Include $includes

    $nonBlockingCount = $todoCount - $integrationGapCount - $qualityGapCount

    $detail = "$todoCount total ($integrationGapCount integration, $qualityGapCount quality, $nonBlockingCount other)"

    if ($integrationGapCount -gt 5 -or $todoCount -gt 25) {
        Add-Result "5. TODO/FIXME Count" "FAIL" $detail
    }
    elseif ($integrationGapCount -gt 0 -or $todoCount -gt 10) {
        Add-Result "5. TODO/FIXME Count" "WARN" $detail
    }
    else {
        Add-Result "5. TODO/FIXME Count" "PASS" $detail
    }
}

# ============================================================
# CHECK 6: TEST COVERAGE GAP
# ============================================================
if ((Should-Run 6) -and $hasSrc) {
    Write-Host "`n--- Check 6: Test Coverage Gap ---" -ForegroundColor Cyan

    $missingTests = @()

    if ($GitDiffBase -eq 'none') {
        $sourceFiles = Get-ChildItem $srcDir -Recurse -Include "*.tsx","*.ts" -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -notmatch '\.(test|spec|stories|d)\.' -and $_.FullName -notmatch 'node_modules|__mocks__' }
    }
    else {
        $changedNames = & git -C $ProjectRoot diff --name-only $GitDiffBase -- "src/" 2>$null
        $sourceFiles = @()
        foreach ($name in $changedNames) {
            if ($name -match '\.(tsx?)$' -and $name -notmatch '\.(test|spec|stories|d)\.') {
                $fullPath = Join-Path $ProjectRoot $name
                if (Test-Path $fullPath) { $sourceFiles += Get-Item $fullPath }
            }
        }
    }

    foreach ($file in $sourceFiles) {
        if ($null -eq $file) { continue }
        $ext = $file.Extension
        $testFile = $file.FullName -replace [regex]::Escape($ext), ".test$ext"
        $specFile = $file.FullName -replace [regex]::Escape($ext), ".spec$ext"

        if (-not (Test-Path $testFile) -and -not (Test-Path $specFile)) {
            $missingTests += $file.FullName.Replace($ProjectRoot, '').TrimStart('\', '/')
        }
    }

    $total = ($sourceFiles | Measure-Object).Count
    $missing = ($missingTests | Measure-Object).Count

    if ($total -eq 0) {
        Add-Result "6. Test Coverage Gap" "PASS" "No source files to check"
    }
    else {
        $pct = [math]::Round(($missing / $total) * 100)
        if ($pct -gt 50) {
            Add-Result "6. Test Coverage Gap" "WARN" "$missing of $total files have no test ($pct%)"
        }
        else {
            Add-Result "6. Test Coverage Gap" "PASS" "$missing of $total files without tests ($pct%)"
        }
        $missingTests | Select-Object -First 5 | ForEach-Object { Write-Host "  No test: $_" -ForegroundColor Yellow }
    }
}
elseif (Should-Run 6) {
    Add-Result "6. Test Coverage Gap" "SKIP" "No src/ directory"
}

# ============================================================
# CHECK 7: MOCK/REAL API DRIFT
# ============================================================
if ((Should-Run 7) -and $isReact -and $hasSrc) {
    Write-Host "`n--- Check 7: Mock/Real API Drift ---" -ForegroundColor Cyan

    $mockFiles = Get-ChildItem $srcDir -Recurse -Filter "Mock*.ts" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch 'node_modules|\.test\.' }
    $driftIssues = @()

    foreach ($mock in $mockFiles) {
        $baseName = $mock.BaseName -replace '^Mock', ''
        $realFile = Get-ChildItem $srcDir -Recurse -Filter "$baseName.ts" -ErrorAction SilentlyContinue |
            Where-Object { $_.BaseName -eq $baseName -and $_.FullName -notmatch 'Mock|node_modules|\.test\.' } |
            Select-Object -First 1

        if ($realFile) {
            $mockMethods = (Select-String -Path $mock.FullName -Pattern 'async \w+\(' -AllMatches -ErrorAction SilentlyContinue | Measure-Object).Count
            $realMethods = (Select-String -Path $realFile.FullName -Pattern 'async \w+\(' -AllMatches -ErrorAction SilentlyContinue | Measure-Object).Count

            if ($mockMethods -ne $realMethods) {
                $driftIssues += "  $($mock.BaseName): $mockMethods methods vs $($realFile.BaseName): $realMethods methods"
            }
        }
    }

    if ($driftIssues.Count -gt 0) {
        Add-Result "7. Mock/Real Drift" "WARN" "$($driftIssues.Count) mock/real method count mismatches"
        $driftIssues | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
    }
    elseif (($mockFiles | Measure-Object).Count -eq 0) {
        Add-Result "7. Mock/Real Drift" "SKIP" "No mock API files found"
    }
    else {
        Add-Result "7. Mock/Real Drift" "PASS" "Mock and real API method counts match"
    }
}
elseif (Should-Run 7) {
    Add-Result "7. Mock/Real Drift" "SKIP" "Not a React project"
}

# ============================================================
# CHECK 8: INTEGRATION SURFACE AUDIT (.NET)
# ============================================================
if ((Should-Run 8) -and $isDotNet) {
    Write-Host "`n--- Check 8: Integration Surface Audit ---" -ForegroundColor Cyan

    $searchDir = if ($hasSrc) { $srcDir } else { $ProjectRoot }

    # 8a: Count NotImplementedException in non-test .cs files
    $stubCount = 0
    $stubList = @()
    Get-ChildItem $searchDir -Recurse -Include "*.cs" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\.Tests[\\/]|[\\/]obj[\\/]|[\\/]bin[\\/]|\.test\.' } |
        ForEach-Object {
            $matches = Select-String -Path $_.FullName -Pattern 'NotImplementedException' -ErrorAction SilentlyContinue
            foreach ($m in $matches) {
                $stubCount++
                $relPath = $_.FullName.Replace($ProjectRoot, '').TrimStart('\', '/')
                $stubList += "  $relPath`:$($m.LineNumber)"
            }
        }

    # 8b: Count interfaces vs implementations
    $interfaceCount = 0
    $implCount = 0
    Get-ChildItem $searchDir -Recurse -Include "*.cs" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '\.Tests[\\/]|[\\/]obj[\\/]|[\\/]bin[\\/]' } |
        ForEach-Object {
            $content = Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -match 'public\s+interface\s+I\w+') { $interfaceCount++ }
            if ($content -match 'public\s+class\s+\w+\s*:\s*I\w+') { $implCount++ }
        }

    $detail = "$stubCount NotImplementedException stubs"
    if ($interfaceCount -gt 0) {
        $detail += ", $implCount/$interfaceCount interfaces have implementations"
    }

    if ($stubCount -gt 10) {
        Add-Result "8. Integration Surface" "FAIL" $detail
        $stubList | Select-Object -First 5 | ForEach-Object { Write-Host $_ -ForegroundColor Red }
    }
    elseif ($stubCount -gt 3) {
        Add-Result "8. Integration Surface" "WARN" $detail
        $stubList | Select-Object -First 5 | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
    }
    else {
        Add-Result "8. Integration Surface" "PASS" $detail
    }
}
elseif (Should-Run 8) {
    Add-Result "8. Integration Surface" "SKIP" "Not a .NET project"
}

# ============================================================
# CHECK 9: FEATURE MAP STALENESS
# ============================================================
if (Should-Run 9) {
    Write-Host "`n--- Check 9: Feature Map Staleness ---" -ForegroundColor Cyan

    $repoRoot = $ProjectRoot
    # Walk up from ProjectRoot to find the .mad directory (it may be at the repo root, not the project root)
    $searchPath = $repoRoot
    $madRoot = $null
    for ($i = 0; $i -lt 5; $i++) {
        if (Test-Path (Join-Path $searchPath ".mad")) {
            $madRoot = $searchPath
            break
        }
        $parent = Split-Path $searchPath -Parent
        if ($parent -eq $searchPath) { break }
        $searchPath = $parent
    }

    if ($null -eq $madRoot) {
        Add-Result "9. Feature Map Staleness" "SKIP" "No .mad directory found"
    }
    else {
        $featureMapPath = Join-Path $madRoot ".mad" "feature-map.json"
        $specsDir = Join-Path $madRoot "specs"

        if (-not (Test-Path $featureMapPath)) {
            # Check if any spec files exist - if they do, the map should exist too
            $specFiles = Get-ChildItem $specsDir -Filter "spec.md" -Recurse -ErrorAction SilentlyContinue
            if (($specFiles | Measure-Object).Count -gt 0) {
                Add-Result "9. Feature Map Staleness" "WARN" "feature-map.json does not exist but $($specFiles.Count) spec file(s) found. Run Generate-FeatureMap.ps1"
            }
            else {
                Add-Result "9. Feature Map Staleness" "PASS" "No feature-map.json and no spec files (nothing to track)"
            }
        }
        else {
            $mapTime = (Get-Item $featureMapPath).LastWriteTime
            $newestSpecTime = [DateTime]::MinValue
            $newestSpecFile = ""

            Get-ChildItem $specsDir -Filter "spec.md" -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
                if ($_.LastWriteTime -gt $newestSpecTime) {
                    $newestSpecTime = $_.LastWriteTime
                    $newestSpecFile = $_.FullName.Replace($madRoot, '').TrimStart('\', '/')
                }
            }

            if ($newestSpecTime -eq [DateTime]::MinValue) {
                Add-Result "9. Feature Map Staleness" "PASS" "feature-map.json exists, no spec files to compare"
            }
            elseif ($newestSpecTime -gt $mapTime) {
                $delta = $newestSpecTime - $mapTime
                $detail = "feature-map.json is $([math]::Round($delta.TotalMinutes)) min older than $newestSpecFile. Run Generate-FeatureMap.ps1"
                Add-Result "9. Feature Map Staleness" "WARN" $detail
            }
            else {
                Add-Result "9. Feature Map Staleness" "PASS" "feature-map.json is up to date with spec files"
            }
        }
    }
}

# ============================================================
# SUMMARY
# ============================================================
Write-Host "`n========================================" -ForegroundColor White
Write-Host "PRE-FLIGHT CHECK SUMMARY" -ForegroundColor White
Write-Host "========================================" -ForegroundColor White
Write-Host "Project: $ProjectRoot"
Write-Host ""

foreach ($r in $results) {
    $color = switch ($r.Status) {
        'PASS' { 'Green' }
        'WARN' { 'Yellow' }
        'FAIL' { 'Red' }
        'SKIP' { 'Gray' }
    }
    $icon = switch ($r.Status) {
        'PASS' { '[OK]  ' }
        'WARN' { '[WARN]' }
        'FAIL' { '[FAIL]' }
        'SKIP' { '[SKIP]' }
    }
    Write-Host "$icon $($r.Check): $($r.Detail)" -ForegroundColor $color
}

Write-Host ""
if ($failures -gt 0) {
    Write-Host "RESULT: FAIL ($failures failure(s), $warnings warning(s))" -ForegroundColor Red
    exit 1
}
elseif ($warnings -gt 0 -and $FailOnWarn) {
    Write-Host "RESULT: FAIL ($warnings warning(s), -FailOnWarn enabled)" -ForegroundColor Red
    exit 1
}
elseif ($warnings -gt 0) {
    Write-Host "RESULT: WARN ($warnings warning(s))" -ForegroundColor Yellow
    exit 0
}
else {
    Write-Host "RESULT: PASS (all checks passed)" -ForegroundColor Green
    exit 0
}
