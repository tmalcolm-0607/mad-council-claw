<#
.SYNOPSIS
    Discover patterns from .NET codebases.

.DESCRIPTION
    Analyzes .NET projects to identify common patterns, conventions, and
    architecture decisions. Outputs pattern candidates for review.

.PARAMETER Paths
    Array of codebase paths to analyze. Default: reference projects.

.PARAMETER OutputDir
    Output directory for discovery reports. Default: .mad/scratch/pattern-discovery

.PARAMETER Depth
    Analysis depth: "quick" or "thorough". Default: quick

.EXAMPLE
    .\Discover-Patterns.ps1
    # Analyzes default reference projects

.EXAMPLE
    .\Discover-Patterns.ps1 -Paths @("C:\source\my-project")
    # Analyzes specific project

.EXAMPLE
    .\Discover-Patterns.ps1 -Depth thorough
    # Deep analysis of all reference projects

.NOTES
    Run from repository root.
#>

[CmdletBinding()]
param(
    [Parameter(Position = 0)]
    [string[]]$Paths = @(),

    [Parameter()]
    [string]$OutputDir = ".mad/scratch/pattern-discovery",

    [Parameter()]
    [ValidateSet("quick", "thorough")]
    [string]$Depth = "quick"
)

# Ensure output directory exists
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    Write-Host "Created output directory: $OutputDir" -ForegroundColor Green
}

# Default to reference projects if no paths specified
if ($Paths.Count -eq 0) {
    $refDir = ".mad/scratch/references"
    if (Test-Path $refDir) {
        $Paths = Get-ChildItem -Path $refDir -Directory | Select-Object -ExpandProperty FullName
    }

    if ($Paths.Count -eq 0) {
        Write-Warning "No paths specified and no reference projects found."
        Write-Host "Run '/refresh-references' first or specify paths with -Paths parameter."
        exit 1
    }
}

# Pattern detection functions
function Find-ProjectStructure {
    param([string]$Path)

    $result = @{
        Layers = @()
        CentralPackages = $false
        CentralBuildProps = $false
    }

    # Check for central package management
    if (Test-Path (Join-Path $Path "Directory.Packages.props")) {
        $result.CentralPackages = $true
    }

    # Check for central build props
    if (Test-Path (Join-Path $Path "Directory.Build.props")) {
        $result.CentralBuildProps = $true
    }

    # Find project layers
    $csprojFiles = Get-ChildItem -Path $Path -Filter "*.csproj" -Recurse
    foreach ($proj in $csprojFiles) {
        $projName = $proj.BaseName
        $layer = switch -Regex ($projName) {
            "\.API$|\.Web$" { "API" }
            "\.BusinessLogic$|\.Services$|\.Application$" { "BusinessLogic" }
            "\.DataAccess$|\.Infrastructure$|\.Data$" { "DataAccess" }
            "\.Common$|\.Shared$|\.Core$" { "Common" }
            "\.Tests$" { "Tests" }
            default { "Other" }
        }
        $result.Layers += [PSCustomObject]@{
            Name = $projName
            Layer = $layer
            Path = $proj.FullName
        }
    }

    return $result
}

function Find-CodePatterns {
    param([string]$Path, [string]$Depth)

    $patterns = @()

    # Pattern: IConfigOptions
    $configOptions = Get-ChildItem -Path $Path -Filter "*.cs" -Recurse |
        Select-String -Pattern "IConfigOptions|ConfigSectionKey" -SimpleMatch |
        Select-Object -First ($Depth -eq "quick" ? 5 : 100)

    if ($configOptions.Count -gt 0) {
        $patterns += [PSCustomObject]@{
            Name = "IConfigOptions"
            Category = "Configuration"
            FileCount = $configOptions.Count
            Example = $configOptions[0].Line.Trim()
        }
    }

    # Pattern: LoggerMessage
    $loggerMessage = Get-ChildItem -Path $Path -Filter "*.cs" -Recurse |
        Select-String -Pattern "\[LoggerMessage" |
        Select-Object -First ($Depth -eq "quick" ? 5 : 100)

    if ($loggerMessage.Count -gt 0) {
        $patterns += [PSCustomObject]@{
            Name = "LoggerMessage"
            Category = "Logging"
            FileCount = $loggerMessage.Count
            Example = $loggerMessage[0].Line.Trim()
        }
    }

    # Pattern: Repository
    $repository = Get-ChildItem -Path $Path -Filter "*.cs" -Recurse |
        Select-String -Pattern "IRepository|Repository.*:" |
        Select-Object -First ($Depth -eq "quick" ? 5 : 100)

    if ($repository.Count -gt 0) {
        $patterns += [PSCustomObject]@{
            Name = "Repository"
            Category = "DataAccess"
            FileCount = $repository.Count
            Example = $repository[0].Line.Trim()
        }
    }

    # Pattern: Cosmos SDK
    $cosmos = Get-ChildItem -Path $Path -Filter "*.cs" -Recurse |
        Select-String -Pattern "CosmosClient|Container\.|PartitionKey|FeedIterator" |
        Select-Object -First ($Depth -eq "quick" ? 5 : 100)

    if ($cosmos.Count -gt 0) {
        $patterns += [PSCustomObject]@{
            Name = "CosmosSDK"
            Category = "DataAccess"
            FileCount = $cosmos.Count
            Example = $cosmos[0].Line.Trim()
        }
    }

    # Pattern: Result<T>
    $result = Get-ChildItem -Path $Path -Filter "*.cs" -Recurse |
        Select-String -Pattern "Result<|\.IsSuccess|\.IsFailure" |
        Select-Object -First ($Depth -eq "quick" ? 5 : 100)

    if ($result.Count -gt 0) {
        $patterns += [PSCustomObject]@{
            Name = "ResultPattern"
            Category = "ErrorHandling"
            FileCount = $result.Count
            Example = $result[0].Line.Trim()
        }
    }

    return $patterns
}

# Process each path
$results = @()

foreach ($path in $Paths) {
    $projectName = Split-Path -Leaf $path
    Write-Host "`nAnalyzing: $projectName" -ForegroundColor Cyan

    if (-not (Test-Path $path)) {
        Write-Warning "  Path not found: $path"
        continue
    }

    # Analyze structure
    Write-Host "  Analyzing project structure..." -ForegroundColor Gray
    $structure = Find-ProjectStructure -Path $path

    # Find code patterns
    Write-Host "  Scanning for code patterns..." -ForegroundColor Gray
    $codePatterns = Find-CodePatterns -Path $path -Depth $Depth

    # Generate report
    $reportPath = Join-Path $OutputDir "$projectName.md"
    $report = @"
# Pattern Discovery: $projectName

## Summary
- Path: $path
- Analyzed: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
- Analysis Depth: $Depth
- Patterns Found: $($codePatterns.Count)

## Project Structure

### Central Configuration
- Directory.Packages.props: $(if ($structure.CentralPackages) { "Yes" } else { "No" })
- Directory.Build.props: $(if ($structure.CentralBuildProps) { "Yes" } else { "No" })

### Layers
| Project | Layer |
|---------|-------|
$($structure.Layers | ForEach-Object { "| $($_.Name) | $($_.Layer) |" } | Out-String)

## Code Patterns

| Pattern | Category | Files | Example |
|---------|----------|-------|---------|
$($codePatterns | ForEach-Object { "| $($_.Name) | $($_.Category) | $($_.FileCount) | ``$($_.Example.Substring(0, [Math]::Min(50, $_.Example.Length)))...`` |" } | Out-String)

## Recommendations

$(if ($codePatterns.Count -eq 0) {
"No patterns detected. This may indicate:
- Non-standard project structure
- Different technology stack
- Analysis depth too shallow (try --depth thorough)"
} else {
"Review patterns above and compare against existing rule files in ``.claude/rules/patterns/``."
})
"@

    $report | Out-File $reportPath -Encoding utf8
    Write-Host "  Report saved to: $reportPath" -ForegroundColor Green

    $results += [PSCustomObject]@{
        Project = $projectName
        Layers = $structure.Layers.Count
        Patterns = $codePatterns.Count
        Report = $reportPath
    }
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Discovery Complete" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

$results | Format-Table -AutoSize

Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "  1. Review reports in $OutputDir"
Write-Host "  2. Compare patterns against .claude/rules/patterns/*.md"
Write-Host "  3. Use '/apply-learnings' to incorporate approved patterns"
