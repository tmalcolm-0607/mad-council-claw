# Get-ReferenceRepoFingerprint.ps1 - Pattern fingerprinting for reference repos
#
# Scans a repository for the presence/absence of architectural patterns
# across multiple dimensions. Used by Eval07 (Cross-Repo Consistency)
# to build a pattern baseline for comparison.
#
# Security: Excludes .git/, secrets/, .env*, test-data/, obj/, bin/,
#           node_modules/, publish-output/, distrib/ from scanning.

$ErrorActionPreference = 'Stop'

function Get-ReferenceRepoFingerprint {
    <#
    .SYNOPSIS
        Scan a reference repo for pattern presence/absence across dimensions.
    .DESCRIPTION
        Analyzes a repository to detect which architectural patterns are present
        (DI registration, error handling, config, logging, testing, security,
        resilience, Cosmos). Returns a fingerprint object with variant
        classification that can be cached and compared across repos.

        Variant classification normalizes minor syntax differences before
        consensus voting (e.g., ILogger<T> and ILogger both map to
        'structured_logging' variant).
    .PARAMETER RepoPath
        Absolute path to the repository root.
    .PARAMETER Dimensions
        Array of dimension names to check. Defaults to the standard 8 dimensions.
    .PARAMETER CachePath
        Optional path to cache the fingerprint as JSON for reuse.
    .PARAMETER CommitSha
        Optional commit SHA for cache invalidation. If provided and a cached
        fingerprint exists with the same commit_sha, returns cached result.
    .EXAMPLE
        Get-ReferenceRepoFingerprint -RepoPath 'C:\source\a shared service'
    .PARAMETER MaxFiles
        Maximum number of files to scan per repo. Prevents hangs on large repos. Default: 5000.
    .PARAMETER TimeoutSeconds
        Maximum seconds to spend scanning a single repo. Repos exceeding this are skipped. Default: 30.
    .EXAMPLE
        Get-ReferenceRepoFingerprint -RepoPath 'C:\source\a shared service' -CachePath '.cache\a shared service.json' -CommitSha 'abc1234'
    .EXAMPLE
        Get-ReferenceRepoFingerprint -RepoPath 'C:\source\a shared service' -MaxFiles 3000 -TimeoutSeconds 20
    #>
    param(
        [Parameter(Mandatory)][string]$RepoPath,
        [string[]]$Dimensions = @(
            'di-registration',
            'error-handling',
            'config-pattern',
            'logging',
            'testing',
            'security',
            'resilience',
            'cosmos'
        ),
        [string]$CachePath,
        [string]$CommitSha,
        [int]$MaxFiles = 5000,
        [int]$TimeoutSeconds = 30
    )

    if (-not (Test-Path $RepoPath)) {
        throw "Repository path does not exist: $RepoPath"
    }

    # --- Cache check: return cached fingerprint if commit_sha matches ---
    if ($CachePath -and $CommitSha -and (Test-Path $CachePath)) {
        try {
            $cached = Get-Content $CachePath -Raw -ErrorAction Stop | ConvertFrom-Json
            if ($cached.commit_sha -eq $CommitSha) {
                return @{
                    repo       = $cached.repo
                    dimensions = $cached.dimensions
                    variants   = $cached.variants
                    timestamp  = $cached.timestamp
                    commit_sha = $cached.commit_sha
                    from_cache = $true
                }
            }
        } catch {
            # Cache corrupted -- proceed with fresh scan
        }
    }

    # --- Security exclusion pattern ---
    # Excludes .git, secrets, .env files, test-data, build output, node_modules
    $excludePattern = '[\\/](\.git|obj|bin|node_modules|target|publish-output|distrib|secrets|test-data)[\\/]'

    # --- Detect if repo has .cs files (exclude non-.NET repos) ---
    # Use timeout to prevent hangs on large repos
    $repoName = Split-Path $RepoPath -Leaf
    $scanJob = $null
    $csProbeFiles = $null

    try {
        # Quick probe: just check if any .cs file exists (limit to first file found)
        $csProbeFiles = Get-ChildItem -Path $RepoPath -Recurse -Filter '*.cs' -File -ErrorAction SilentlyContinue -Depth 10 |
            Where-Object {
                $_.FullName -notmatch $excludePattern -and
                $_.Name -notlike '.env*'
            } | Select-Object -First 1
    } catch {
        # Timeout or access error during probe
        $csProbeFiles = $null
    }

    if (-not $csProbeFiles) {
        return @{
            repo         = $repoName
            dimensions   = @{}
            variants     = @{}
            timestamp    = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
            commit_sha   = $CommitSha
            status       = 'not_applicable'
            reason       = 'No .cs files found -- not a .NET repository'
            from_cache   = $false
        }
    }

    # --- Pattern detection rules per dimension ---
    # Each dimension has:
    #   patterns: raw string patterns to search for
    #   variants: mapping from pattern matches to canonical variant names
    #   fileGlob: file extension to scan
    $detectors = @{
        'di-registration' = @{
            patterns  = @('AddSingleton', 'AddScoped', 'AddTransient', 'TryAddSingleton', 'TryAddScoped',
                          'IServiceCollection', 'ServiceCollectionExtensions', 'AddHostedService')
            variants  = @{
                explicit_registration = @('AddSingleton', 'AddScoped', 'AddTransient', 'TryAddSingleton', 'TryAddScoped')
                extension_methods     = @('ServiceCollectionExtensions', 'IServiceCollection')
                hosted_services       = @('AddHostedService')
            }
            fileGlob  = '*.cs'
        }
        'error-handling' = @{
            patterns  = @('ExceptionMiddleware', 'SanitizedException', 'ProblemDetails', 'IExceptionHandler',
                          'UseExceptionHandler', 'ExceptionFilter', 'BusinessException', 'ValidationException',
                          'NotFoundException', 'Result<')
            variants  = @{
                sanitized_exception_hierarchy = @('SanitizedException', 'BusinessException', 'ValidationException', 'NotFoundException')
                dual_middleware               = @('ExceptionMiddleware', 'UseExceptionHandler')
                exception_filter              = @('ExceptionFilter', 'IExceptionHandler')
                problem_details               = @('ProblemDetails')
                result_type                   = @('Result<')
            }
            fileGlob  = '*.cs'
        }
        'config-pattern' = @{
            patterns  = @('IConfigOptions', 'IOptions<', 'IOptionsMonitor<', 'IOptionsSnapshot<',
                          'Configure<', 'OptionsBuilder', 'ValidateDataAnnotations',
                          'appsettings', 'runtimesettings', 'SectionName')
            variants  = @{
                iconfigoptions       = @('IConfigOptions', 'SectionName')
                options_pattern      = @('IOptions<', 'IOptionsMonitor<', 'IOptionsSnapshot<', 'Configure<')
                validated_options    = @('OptionsBuilder', 'ValidateDataAnnotations')
                dual_config          = @('appsettings', 'runtimesettings')
            }
            fileGlob  = '*.cs'
        }
        'logging' = @{
            patterns  = @('LoggerMessage', 'LogMessages', 'ILogger<', 'LogEventIds', 'LoggerMessageAttribute',
                          'LoggerMessage.Define', 'partial.*Log', 'CorrelationId')
            variants  = @{
                source_generators     = @('LoggerMessage', 'LoggerMessageAttribute', 'partial.*Log')
                structured_logging    = @('ILogger<', 'LogMessages', 'LogEventIds')
                log_message_define    = @('LoggerMessage.Define')
                correlation           = @('CorrelationId')
            }
            fileGlob  = '*.cs'
        }
        'testing' = @{
            patterns  = @('[Fact]', '[Theory]', '[InlineData]', 'NSubstitute', 'Substitute.For',
                          'FluentAssertions', 'Should()', 'Moq', 'Mock<', 'WireMock',
                          'WebApplicationFactory', 'TestServer')
            variants  = @{
                xunit                = @('[Fact]', '[Theory]', '[InlineData]')
                nsubstitute          = @('NSubstitute', 'Substitute.For')
                fluent_assertions    = @('FluentAssertions', 'Should()')
                moq                  = @('Moq', 'Mock<')
                integration_testing  = @('WebApplicationFactory', 'TestServer', 'WireMock')
            }
            fileGlob  = '*.cs'
        }
        'security' = @{
            patterns  = @('DefaultAzureCredential', 'ManagedIdentity', 'TokenCredential',
                          'AddAuthentication', '[Authorize]', 'AuthorizationPolicy',
                          'RequireScope', 'AddMicrosoftIdentityWebApi', 'JwtBearerDefaults')
            variants  = @{
                managed_identity     = @('DefaultAzureCredential', 'ManagedIdentity', 'TokenCredential')
                jwt_bearer           = @('AddAuthentication', 'JwtBearerDefaults', 'AddMicrosoftIdentityWebApi')
                policy_auth          = @('[Authorize]', 'AuthorizationPolicy', 'RequireScope')
            }
            fileGlob  = '*.cs'
        }
        'resilience' = @{
            patterns  = @('AddResiliencePipeline', 'RetryPolicy', 'CircuitBreaker', 'Polly',
                          'ResilienceHandler', 'AddStandardResilienceHandler', 'Timeout',
                          'BulkheadPolicy', 'AddStandardHedgingHandler')
            variants  = @{
                polly_v8             = @('AddResiliencePipeline', 'AddStandardResilienceHandler', 'AddStandardHedgingHandler')
                polly_classic        = @('RetryPolicy', 'CircuitBreaker', 'BulkheadPolicy')
                polly_general        = @('Polly', 'ResilienceHandler', 'Timeout')
            }
            fileGlob  = '*.cs'
        }
        'cosmos' = @{
            patterns  = @('CosmosClient', 'Container.', 'PartitionKey', 'CosmosOptions',
                          'ItemResponse', 'FeedIterator', 'QueryDefinition',
                          'TransactionalBatch', 'ChangeFeedProcessor', 'HierarchicalPartitionKey')
            variants  = @{
                core_sdk             = @('CosmosClient', 'Container.', 'PartitionKey', 'CosmosOptions')
                query_patterns       = @('FeedIterator', 'QueryDefinition', 'ItemResponse')
                advanced_features    = @('TransactionalBatch', 'ChangeFeedProcessor', 'HierarchicalPartitionKey')
            }
            fileGlob  = '*.cs'
        }
    }

    $dimensionResults = @{}
    $variantResults = @{}

    # Pre-collect all .cs files once (with MaxFiles limit and depth constraint to prevent hangs)
    $scanStartTime = [System.Diagnostics.Stopwatch]::StartNew()
    $allCsFiles = [System.Collections.ArrayList]::new()
    try {
        $fileEnum = Get-ChildItem -Path $RepoPath -Recurse -Filter '*.cs' -File -ErrorAction SilentlyContinue -Depth 15 |
            Where-Object {
                $_.FullName -notmatch $excludePattern -and
                $_.Name -notlike '.env*'
            }
        foreach ($f in $fileEnum) {
            [void]$allCsFiles.Add($f)
            if ($allCsFiles.Count -ge $MaxFiles) {
                break
            }
            # Check timeout during enumeration
            if ($scanStartTime.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
                break
            }
        }
    } catch {
        # Access or enumeration error -- proceed with what we have
    }
    $scanStartTime.Stop()

    # Pre-read file contents (with timeout protection)
    $allFileContents = @{}
    $readStartTime = [System.Diagnostics.Stopwatch]::StartNew()
    foreach ($f in $allCsFiles) {
        if ($readStartTime.Elapsed.TotalSeconds -ge $TimeoutSeconds) {
            break
        }
        $allFileContents[$f.FullName] = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
    }
    $readStartTime.Stop()

    foreach ($dim in $Dimensions) {
        if (-not $detectors.ContainsKey($dim)) {
            $dimensionResults[$dim] = @{ present = $false; matches = 0; note = 'Unknown dimension' }
            $variantResults[$dim] = @{}
            continue
        }

        $detector = $detectors[$dim]
        $totalMatches = 0
        $matchedPatterns = [System.Collections.ArrayList]::new()

        # Use pre-collected and pre-read file contents (already filtered)
        $fileContents = $allFileContents

        foreach ($pattern in $detector.patterns) {
            $found = $false
            foreach ($filePath in $fileContents.Keys) {
                if ($fileContents[$filePath] -and $fileContents[$filePath] -match [regex]::Escape($pattern)) {
                    $found = $true
                    break  # One match per pattern is sufficient
                }
            }
            if ($found) {
                $totalMatches++
                [void]$matchedPatterns.Add($pattern)
            }
        }

        $dimensionResults[$dim] = @{
            present        = ($totalMatches -gt 0)
            matches        = $totalMatches
            total_patterns = $detector.patterns.Count
        }

        # --- Variant classification ---
        # Map matched patterns to canonical variant names
        $dimVariants = @{}
        if ($detector.ContainsKey('variants')) {
            foreach ($variantName in $detector.variants.Keys) {
                $variantPatterns = $detector.variants[$variantName]
                $variantMatchCount = 0
                foreach ($vp in $variantPatterns) {
                    if ($matchedPatterns -contains $vp) {
                        $variantMatchCount++
                    } else {
                        # Check regex patterns (e.g., 'partial.*Log')
                        foreach ($mp in $matchedPatterns) {
                            if ($mp -match [regex]::Escape($vp) -or $vp -match '\.\*' -and $mp -match $vp) {
                                $variantMatchCount++
                                break
                            }
                        }
                    }
                }
                $dimVariants[$variantName] = @{
                    present     = ($variantMatchCount -gt 0)
                    match_count = $variantMatchCount
                    total       = $variantPatterns.Count
                    strength    = if ($variantPatterns.Count -gt 0) {
                        [Math]::Round($variantMatchCount / $variantPatterns.Count, 2)
                    } else { 0.0 }
                }
            }
        }
        $variantResults[$dim] = $dimVariants
    }

    $repoName = Split-Path $RepoPath -Leaf

    # Resolve commit SHA if not provided
    if (-not $CommitSha) {
        $gitDir = Join-Path $RepoPath '.git'
        if (Test-Path $gitDir) {
            try {
                $CommitSha = (git -C $RepoPath rev-parse HEAD 2>$null)
                if ($LASTEXITCODE -ne 0) { $CommitSha = 'unknown' }
            } catch {
                $CommitSha = 'unknown'
            }
        } else {
            $CommitSha = 'no-git'
        }
    }

    $fingerprint = @{
        repo          = $repoName
        dimensions    = $dimensionResults
        variants      = $variantResults
        timestamp     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        commit_sha    = $CommitSha
        from_cache    = $false
        files_scanned = $allCsFiles.Count
        max_files     = $MaxFiles
    }

    # Cache if requested
    if ($CachePath) {
        $json = $fingerprint | ConvertTo-Json -Depth 10
        $parentDir = Split-Path $CachePath -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        [System.IO.File]::WriteAllText($CachePath, $json, (New-Object System.Text.UTF8Encoding $false))
    }

    return $fingerprint
}
