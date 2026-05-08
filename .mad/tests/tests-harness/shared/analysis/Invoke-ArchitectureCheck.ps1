# Invoke-ArchitectureCheck.ps1 - Architecture rule validation via file/regex analysis
#
# Scans .NET solution source files and csproj references to detect architectural
# violations in a 5-layer the ecosystem architecture (API, DI, BusinessLogic, DataAccess, Common).
# Used by Eval04 (Architecture Drift Detection) to measure structural compliance.

$ErrorActionPreference = 'Stop'

function Invoke-ArchitectureCheck {
    <#
    .SYNOPSIS
        Run 15 architecture rules via file/regex analysis and return structured results.
    .DESCRIPTION
        Scans csproj files for illegal project references and .cs files for illegal
        using statements, naming violations, and encapsulation breaches. Returns a
        structured summary of passing/failing architecture rules with severity weights.

        Rules are grouped into 4 categories:
        - layering (8 rules): Project reference direction enforcement
        - dependency (2 rules): Forbidden package/namespace usage
        - encapsulation (2 rules): Logic placement and interface location
        - naming (3 rules): Suffix and attribute conventions

    .PARAMETER SolutionPath
        Path to the .NET solution directory (containing .sln and project folders).
    .PARAMETER RulesProject
        Unused (kept for interface compatibility). Regex analysis does not need a test project.
    .PARAMETER RuleCategories
        Which rule categories to run. Default: @('all').
        Valid categories: 'all', 'layering', 'naming', 'dependency', 'encapsulation'.
    .EXAMPLE
        Invoke-ArchitectureCheck -SolutionPath 'C:\temp\eval\workspace'
    .EXAMPLE
        Invoke-ArchitectureCheck -SolutionPath 'C:\temp\eval\workspace' -RuleCategories @('layering','dependency')
    #>
    param(
        [Parameter(Mandatory)][string]$SolutionPath,
        [string]$RulesProject,
        [string[]]$RuleCategories = @('all')
    )

    if (-not (Test-Path $SolutionPath)) {
        throw "Solution path does not exist: $SolutionPath"
    }

    $results = [System.Collections.ArrayList]::new()

    # Helper: read csproj and extract ProjectReference includes
    function Get-ProjectReferences {
        param([string]$CsprojPath)
        if (-not (Test-Path $CsprojPath)) { return @() }
        $content = Get-Content $CsprojPath -Raw -ErrorAction SilentlyContinue
        if (-not $content) { return @() }
        $refs = [regex]::Matches($content, 'ProjectReference\s+Include="([^"]+)"')
        return @($refs | ForEach-Object { $_.Groups[1].Value })
    }

    # Helper: get all .cs files in a project directory (excluding bin/obj)
    function Get-CsFiles {
        param([string]$ProjectDir)
        if (-not (Test-Path $ProjectDir)) { return @() }
        return @(Get-ChildItem -Path $ProjectDir -Recurse -Include '*.cs' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' })
    }

    # Helper: check if any .cs file in a directory contains a using statement pattern
    function Test-UsingStatement {
        param([string]$ProjectDir, [string]$NamespacePattern)
        $files = Get-CsFiles -ProjectDir $ProjectDir
        foreach ($f in $files) {
            $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -and $content -match "using\s+$NamespacePattern") {
                return @{ found = $true; file = $f.FullName }
            }
        }
        return @{ found = $false; file = $null }
    }

    # Helper: check if csproj references a specific project name
    function Test-CsprojReference {
        param([string]$CsprojPath, [string]$ForbiddenProject)
        $refs = Get-ProjectReferences -CsprojPath $CsprojPath
        foreach ($ref in $refs) {
            if ($ref -match "\\$ForbiddenProject\\|/$ForbiddenProject/|\\$ForbiddenProject\.csproj|/$ForbiddenProject\.csproj") {
                return $true
            }
        }
        return $false
    }

    # Helper: add a rule result
    function Add-RuleResult {
        param(
            [string]$Name,
            [string]$Category,
            [string]$Severity,
            [int]$Weight,
            [bool]$Passed,
            [string]$Message
        )
        [void]$results.Add(@{
            rule     = $Name
            category = $Category
            severity = $Severity
            weight   = $Weight
            passed   = $Passed
            message  = $Message
        })
    }

    # Determine which categories to run
    $runAll = $RuleCategories -contains 'all'
    $runLayering = $runAll -or ($RuleCategories -contains 'layering')
    $runDependency = $runAll -or ($RuleCategories -contains 'dependency')
    $runEncapsulation = $runAll -or ($RuleCategories -contains 'encapsulation')
    $runNaming = $runAll -or ($RuleCategories -contains 'naming')

    # Discover project directories and csproj files
    $apiCsproj = Get-ChildItem -Path $SolutionPath -Filter 'API.csproj' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $blCsproj = Get-ChildItem -Path $SolutionPath -Filter 'BusinessLogic.csproj' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $daCsproj = Get-ChildItem -Path $SolutionPath -Filter 'DataAccess.csproj' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $commonCsproj = Get-ChildItem -Path $SolutionPath -Filter 'Common.csproj' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1
    $diCsproj = Get-ChildItem -Path $SolutionPath -Filter 'DependencyInjection.csproj' -Recurse -File -ErrorAction SilentlyContinue | Select-Object -First 1

    $apiDir = if ($apiCsproj) { Split-Path $apiCsproj.FullName -Parent } else { $null }
    $blDir = if ($blCsproj) { Split-Path $blCsproj.FullName -Parent } else { $null }
    $daDir = if ($daCsproj) { Split-Path $daCsproj.FullName -Parent } else { $null }
    $commonDir = if ($commonCsproj) { Split-Path $commonCsproj.FullName -Parent } else { $null }

    # -----------------------------------------------------------------------
    # LAYERING RULES (8 rules)
    # -----------------------------------------------------------------------

    if ($runLayering) {
        # Rule 1: API must not reference DataAccess (Critical, weight=3)
        if ($apiCsproj) {
            $hasRef = Test-CsprojReference -CsprojPath $apiCsproj.FullName -ForbiddenProject 'DataAccess'
            Add-RuleResult -Name 'api_no_dataaccess_ref' -Category 'layering' -Severity 'critical' -Weight 3 `
                -Passed (-not $hasRef) -Message $(if ($hasRef) { "API.csproj references DataAccess -- violates layer boundary" } else { "API does not reference DataAccess" })
        } else {
            Add-RuleResult -Name 'api_no_dataaccess_ref' -Category 'layering' -Severity 'critical' -Weight 3 `
                -Passed $true -Message 'API.csproj not found (no violation possible)'
        }

        # Rule 2: API must not reference BusinessLogic (Critical, weight=3)
        if ($apiCsproj) {
            $hasRef = Test-CsprojReference -CsprojPath $apiCsproj.FullName -ForbiddenProject 'BusinessLogic'
            Add-RuleResult -Name 'api_no_businesslogic_ref' -Category 'layering' -Severity 'critical' -Weight 3 `
                -Passed (-not $hasRef) -Message $(if ($hasRef) { "API.csproj references BusinessLogic -- violates layer boundary" } else { "API does not reference BusinessLogic" })
        } else {
            Add-RuleResult -Name 'api_no_businesslogic_ref' -Category 'layering' -Severity 'critical' -Weight 3 `
                -Passed $true -Message 'API.csproj not found (no violation possible)'
        }

        # Rule 4: BusinessLogic must not reference API (Critical, weight=3)
        if ($blCsproj) {
            $hasRef = Test-CsprojReference -CsprojPath $blCsproj.FullName -ForbiddenProject 'API'
            Add-RuleResult -Name 'bl_no_api_ref' -Category 'layering' -Severity 'critical' -Weight 3 `
                -Passed (-not $hasRef) -Message $(if ($hasRef) { "BusinessLogic.csproj references API -- violates layer boundary" } else { "BusinessLogic does not reference API" })
        } else {
            Add-RuleResult -Name 'bl_no_api_ref' -Category 'layering' -Severity 'critical' -Weight 3 `
                -Passed $true -Message 'BusinessLogic.csproj not found (no violation possible)'
        }

        # Rule 6: DataAccess must not reference API (Critical, weight=3)
        if ($daCsproj) {
            $hasRef = Test-CsprojReference -CsprojPath $daCsproj.FullName -ForbiddenProject 'API'
            Add-RuleResult -Name 'da_no_api_ref' -Category 'layering' -Severity 'critical' -Weight 3 `
                -Passed (-not $hasRef) -Message $(if ($hasRef) { "DataAccess.csproj references API -- violates layer boundary" } else { "DataAccess does not reference API" })
        } else {
            Add-RuleResult -Name 'da_no_api_ref' -Category 'layering' -Severity 'critical' -Weight 3 `
                -Passed $true -Message 'DataAccess.csproj not found (no violation possible)'
        }

        # Rule 7: DataAccess must not reference BusinessLogic (Major, weight=2)
        if ($daCsproj) {
            $hasRef = Test-CsprojReference -CsprojPath $daCsproj.FullName -ForbiddenProject 'BusinessLogic'
            Add-RuleResult -Name 'da_no_bl_ref' -Category 'layering' -Severity 'major' -Weight 2 `
                -Passed (-not $hasRef) -Message $(if ($hasRef) { "DataAccess.csproj references BusinessLogic -- violates layer boundary" } else { "DataAccess does not reference BusinessLogic" })
        } else {
            Add-RuleResult -Name 'da_no_bl_ref' -Category 'layering' -Severity 'major' -Weight 2 `
                -Passed $true -Message 'DataAccess.csproj not found (no violation possible)'
        }

        # Rule 8: Common must not reference any project (Critical, weight=3)
        if ($commonCsproj) {
            $refs = Get-ProjectReferences -CsprojPath $commonCsproj.FullName
            $projRefs = @($refs | Where-Object { $_ -match '\.csproj$' })
            Add-RuleResult -Name 'common_no_project_refs' -Category 'layering' -Severity 'critical' -Weight 3 `
                -Passed ($projRefs.Count -eq 0) -Message $(if ($projRefs.Count -gt 0) { "Common.csproj has project references: $($projRefs -join ', ')" } else { "Common has no project references" })
        } else {
            Add-RuleResult -Name 'common_no_project_refs' -Category 'layering' -Severity 'critical' -Weight 3 `
                -Passed $true -Message 'Common.csproj not found (no violation possible)'
        }

        # Rule 13: No circular project references (Critical, weight=3)
        # Build a directed graph and check for cycles
        $allCsprojs = @(Get-ChildItem -Path $SolutionPath -Recurse -Filter '*.csproj' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' })
        $graph = @{}
        foreach ($csproj in $allCsprojs) {
            $projName = [System.IO.Path]::GetFileNameWithoutExtension($csproj.Name)
            $refs = Get-ProjectReferences -CsprojPath $csproj.FullName
            $refNames = @($refs | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension(($_ -replace '.*[\\/]', '')) })
            $graph[$projName] = $refNames
        }
        $hasCycle = $false
        $cycleDetail = ''
        # Simple DFS cycle detection
        $visited = @{}
        $inStack = @{}
        function Test-Cycle {
            param([string]$Node)
            if ($inStack.ContainsKey($Node) -and $inStack[$Node]) { return $true }
            if ($visited.ContainsKey($Node) -and $visited[$Node]) { return $false }
            $visited[$Node] = $true
            $inStack[$Node] = $true
            if ($graph.ContainsKey($Node)) {
                foreach ($neighbor in $graph[$Node]) {
                    if (Test-Cycle -Node $neighbor) { return $true }
                }
            }
            $inStack[$Node] = $false
            return $false
        }
        foreach ($node in $graph.Keys) {
            $visited = @{}
            $inStack = @{}
            if (Test-Cycle -Node $node) {
                $hasCycle = $true
                $cycleDetail = "Circular reference detected starting from $node"
                break
            }
        }
        Add-RuleResult -Name 'no_circular_refs' -Category 'layering' -Severity 'critical' -Weight 3 `
            -Passed (-not $hasCycle) -Message $(if ($hasCycle) { $cycleDetail } else { "No circular project references detected" })

        # Rule: DI references all expected layers (informational, layering completeness)
        if ($diCsproj) {
            $refs = Get-ProjectReferences -CsprojPath $diCsproj.FullName
            $refsJoined = ($refs -join '|')
            $hasCommon = $refsJoined -match 'Common'
            $hasBL = $refsJoined -match 'BusinessLogic'
            $hasDA = $refsJoined -match 'DataAccess'
            $diComplete = $hasCommon -and $hasBL -and $hasDA
            Add-RuleResult -Name 'di_references_all_layers' -Category 'layering' -Severity 'major' -Weight 2 `
                -Passed $diComplete -Message $(if ($diComplete) { "DI references Common, BusinessLogic, and DataAccess" } else { "DI missing expected references (Common=$hasCommon, BL=$hasBL, DA=$hasDA)" })
        } else {
            Add-RuleResult -Name 'di_references_all_layers' -Category 'layering' -Severity 'major' -Weight 2 `
                -Passed $true -Message 'DependencyInjection.csproj not found (no violation possible)'
        }
    }

    # -----------------------------------------------------------------------
    # DEPENDENCY RULES (2 rules)
    # -----------------------------------------------------------------------

    if ($runDependency) {
        # Rule 3: API must not use Microsoft.Azure.Cosmos (Critical, weight=3)
        if ($apiDir) {
            $cosmosCheck = Test-UsingStatement -ProjectDir $apiDir -NamespacePattern 'Microsoft\.Azure\.Cosmos'
            Add-RuleResult -Name 'api_no_cosmos_using' -Category 'dependency' -Severity 'critical' -Weight 3 `
                -Passed (-not $cosmosCheck.found) -Message $(if ($cosmosCheck.found) { "API layer has Cosmos using in: $($cosmosCheck.file)" } else { "API layer has no Cosmos using statements" })
        } else {
            Add-RuleResult -Name 'api_no_cosmos_using' -Category 'dependency' -Severity 'critical' -Weight 3 `
                -Passed $true -Message 'API directory not found (no violation possible)'
        }

        # Rule 5: BusinessLogic must not use Microsoft.Azure.Cosmos (Critical, weight=3)
        if ($blDir) {
            $cosmosCheck = Test-UsingStatement -ProjectDir $blDir -NamespacePattern 'Microsoft\.Azure\.Cosmos'
            Add-RuleResult -Name 'bl_no_cosmos_using' -Category 'dependency' -Severity 'critical' -Weight 3 `
                -Passed (-not $cosmosCheck.found) -Message $(if ($cosmosCheck.found) { "BusinessLogic layer has Cosmos using in: $($cosmosCheck.file)" } else { "BusinessLogic layer has no Cosmos using statements" })
        } else {
            Add-RuleResult -Name 'bl_no_cosmos_using' -Category 'dependency' -Severity 'critical' -Weight 3 `
                -Passed $true -Message 'BusinessLogic directory not found (no violation possible)'
        }
    }

    # -----------------------------------------------------------------------
    # ENCAPSULATION RULES (2 rules)
    # -----------------------------------------------------------------------

    if ($runEncapsulation) {
        # Rule 9: Controllers must not contain business logic (Major, weight=2)
        # Heuristic: Controller methods should be thin -- delegate to handlers.
        # Check for direct Cosmos/DB calls or methods with >20 non-trivial lines.
        $controllerViolation = $false
        $controllerViolationDetail = ''
        if ($apiDir) {
            $controllerFiles = Get-CsFiles -ProjectDir $apiDir | Where-Object { $_.Name -match 'Controller\.cs$' }
            foreach ($cf in $controllerFiles) {
                $content = Get-Content $cf.FullName -Raw -ErrorAction SilentlyContinue
                if ($content) {
                    # Check for direct DB/Cosmos usage in controllers
                    if ($content -match 'Container\s+_|CosmosClient\s+_|\.CreateItemAsync|\.ReadItemAsync|\.GetItemQueryIterator') {
                        $controllerViolation = $true
                        $controllerViolationDetail = "Controller $($cf.Name) contains direct Cosmos/DB operations"
                        break
                    }
                    # Check for business logic keywords (repository calls are OK, but complex logic is not)
                    if ($content -match 'new\s+QueryDefinition|SqlQuerySpec|FeedIterator') {
                        $controllerViolation = $true
                        $controllerViolationDetail = "Controller $($cf.Name) contains query construction (business logic)"
                        break
                    }
                }
            }
        }
        Add-RuleResult -Name 'controllers_no_business_logic' -Category 'encapsulation' -Severity 'major' -Weight 2 `
            -Passed (-not $controllerViolation) -Message $(if ($controllerViolation) { $controllerViolationDetail } else { "Controllers do not contain direct business logic" })

        # Rule 12: Interfaces must be in correct layer (Major, weight=2)
        # Repository interfaces (ICaseRepository, IAttachmentRepository, etc.) should be in Common/Interfaces,
        # NOT collocated with their implementation in DataAccess.
        $interfaceViolation = $false
        $interfaceViolationDetail = ''
        if ($daDir) {
            $daFiles = Get-CsFiles -ProjectDir $daDir
            foreach ($f in $daFiles) {
                $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
                if ($content -and $content -match 'public\s+interface\s+I\w+Repository') {
                    $interfaceViolation = $true
                    $interfaceViolationDetail = "Repository interface found in DataAccess: $($f.Name) (should be in Common/Interfaces)"
                    break
                }
            }
        }
        Add-RuleResult -Name 'interfaces_in_correct_layer' -Category 'encapsulation' -Severity 'major' -Weight 2 `
            -Passed (-not $interfaceViolation) -Message $(if ($interfaceViolation) { $interfaceViolationDetail } else { "No repository interfaces found in DataAccess layer" })
    }

    # -----------------------------------------------------------------------
    # NAMING RULES (3 rules)
    # -----------------------------------------------------------------------

    if ($runNaming) {
        # Rule 10: Handlers must have "Handler" suffix (Minor, weight=1)
        $handlerViolation = $false
        $handlerViolationDetail = ''
        if ($blDir) {
            $blFiles = Get-CsFiles -ProjectDir $blDir
            foreach ($f in $blFiles) {
                $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
                if ($content) {
                    # Look for classes that implement handler-like interfaces but lack Handler suffix
                    $classMatches = [regex]::Matches($content, 'public\s+class\s+(\w+)\s*:\s*[^{]*(?:IRequestHandler|IHandler|ICommandHandler|IQueryHandler)')
                    foreach ($m in $classMatches) {
                        $className = $m.Groups[1].Value
                        if ($className -notmatch 'Handler$') {
                            $handlerViolation = $true
                            $handlerViolationDetail = "Class '$className' implements handler interface but lacks 'Handler' suffix in $($f.Name)"
                            break
                        }
                    }
                    if ($handlerViolation) { break }
                }
            }
        }
        Add-RuleResult -Name 'handlers_have_suffix' -Category 'naming' -Severity 'minor' -Weight 1 `
            -Passed (-not $handlerViolation) -Message $(if ($handlerViolation) { $handlerViolationDetail } else { "All handler classes have 'Handler' suffix" })

        # Rule 11: Repositories must have "Repository" suffix (Minor, weight=1)
        $repoViolation = $false
        $repoViolationDetail = ''
        if ($daDir) {
            $daFiles = Get-CsFiles -ProjectDir $daDir
            foreach ($f in $daFiles) {
                $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
                if ($content) {
                    # Look for classes that implement repository-like interfaces but lack Repository suffix
                    $classMatches = [regex]::Matches($content, 'public\s+class\s+(\w+)\s*:\s*[^{]*I\w+Repository')
                    foreach ($m in $classMatches) {
                        $className = $m.Groups[1].Value
                        if ($className -notmatch 'Repository$') {
                            $repoViolation = $true
                            $repoViolationDetail = "Class '$className' implements repository interface but lacks 'Repository' suffix in $($f.Name)"
                            break
                        }
                    }
                    if ($repoViolation) { break }
                }
            }
        }
        Add-RuleResult -Name 'repositories_have_suffix' -Category 'naming' -Severity 'minor' -Weight 1 `
            -Passed (-not $repoViolation) -Message $(if ($repoViolation) { $repoViolationDetail } else { "All repository classes have 'Repository' suffix" })

        # Rule 14: Configuration classes implement IConfigOptions (Minor, weight=1)
        $configViolation = $false
        $configViolationDetail = ''
        if ($commonDir) {
            $configDir = Join-Path $commonDir 'Configuration'
            if (Test-Path $configDir) {
                $configFiles = Get-CsFiles -ProjectDir $configDir
                foreach ($f in $configFiles) {
                    $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
                    if ($content -and $content -match 'public\s+class\s+(\w+Options)' -and $content -notmatch 'IConfigOptions') {
                        $configViolation = $true
                        $configViolationDetail = "Options class in $($f.Name) does not implement IConfigOptions"
                        break
                    }
                }
            }
        }
        Add-RuleResult -Name 'config_implements_iconfigoptions' -Category 'naming' -Severity 'minor' -Weight 1 `
            -Passed (-not $configViolation) -Message $(if ($configViolation) { $configViolationDetail } else { "All Options classes implement IConfigOptions" })

        # Rule 15: LoggerMessage source generators used (Minor, weight=1)
        # Check if any file uses LoggerMessage attribute (at least one should exist in a well-structured project)
        $hasLoggerMessage = $false
        $allCsFiles = @(Get-ChildItem -Path $SolutionPath -Recurse -Include '*.cs' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' })
        foreach ($f in $allCsFiles) {
            $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -and $content -match '\[LoggerMessage') {
                $hasLoggerMessage = $true
                break
            }
        }
        # Also check for at least ILogger usage -- if ILogger is used but no [LoggerMessage], that is a violation
        $hasILoggerUsage = $false
        foreach ($f in $allCsFiles) {
            $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -and $content -match 'ILogger<') {
                $hasILoggerUsage = $true
                break
            }
        }
        $loggerPassed = if ($hasILoggerUsage) { $hasLoggerMessage } else { $true }  # No ILogger usage = no violation
        Add-RuleResult -Name 'logger_source_generators' -Category 'naming' -Severity 'minor' -Weight 1 `
            -Passed $loggerPassed -Message $(
                if ($hasILoggerUsage -and -not $hasLoggerMessage) { "ILogger used but no [LoggerMessage] source generators found" }
                elseif ($hasLoggerMessage) { "[LoggerMessage] source generators are in use" }
                else { "No ILogger usage detected (rule not applicable)" }
            )
    }

    # -----------------------------------------------------------------------
    # Aggregate results
    # -----------------------------------------------------------------------

    $totalRules = $results.Count
    $passingRules = @($results | Where-Object { $_.passed -eq $true }).Count
    $failingRules = $totalRules - $passingRules

    return @{
        total_rules = $totalRules
        passing     = $passingRules
        failing     = $failingRules
        results     = @($results)
    }
}
