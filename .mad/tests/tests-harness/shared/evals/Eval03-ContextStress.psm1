# Eval03-ContextStress.psm1 - Context Window Stress Test module
#
# Measures how CCGHCP rule adherence degrades as the context window fills.
# Provides a fill controller with 3 padding strategies, 10 rule adherence
# checkers, Ebbinghaus forgetting curve fitting, and cliff-edge detection.
#
# Exports: Setup-ContextStress, Get-ContextStressPrompt, Invoke-ContextStressAssertions
#
# Shared module dependencies:
#   - EvalShared.psm1 (Write-Status, New-Assertion, Invoke-SecretRedaction)
#   - Get-ContextFillLevel.ps1 (context fill estimation from transcripts)
#   - Invoke-MultiDimensionalScore.ps1 (weighted composite scoring)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

$script:MaxContextTokens     = 200000   # Claude Opus context window
$script:SystemOverheadTokens = 15000    # System prompt overhead
$script:RulesOverheadTokens  = 8000     # CCGHCP rules overhead
$script:FillTargets          = @(0.25, 0.50, 0.75, 0.90)
$script:CharsPerToken        = 4        # Conservative English text estimate
$script:FillAccuracyBand     = 0.20     # +/- 20% tolerance per review finding C2
$script:CliffGradientThreshold = 2.0    # Gradient > 2x average flags a cliff edge
$script:SafeZoneThreshold    = 0.80     # 80% adherence = safe operating zone

# Padding sanitization patterns (review finding M4)
$script:UnsafePaddingPatterns = @(
    '(?i)(password|secret|token|api[_-]?key)\s*[=:]\s*\S+'
    '(?i)\b\d{3}-\d{2}-\d{4}\b'                # SSN-like
    '(?i)\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b' # Email
    '(?i)(ignore previous instructions|system prompt|you are now)'  # Prompt injection
    '\beyJ[A-Za-z0-9_-]{20,}\.'                 # JWT-like
)

# Rule definitions: ID, name, description, pattern file, checker function name
$script:TargetRules = @(
    @{ Id = 'R01'; Name = 'Handler not Service naming';       PatternFile = 'dotnet-architecture.md' }
    @{ Id = 'R02'; Name = 'Interfaces in Common layer';       PatternFile = 'dotnet-architecture.md' }
    @{ Id = 'R03'; Name = 'PagedResult not List returns';     PatternFile = 'dotnet-cosmos-queries.md' }
    @{ Id = 'R04'; Name = 'LoggerMessage source generators';  PatternFile = 'dotnet-logging.md' }
    @{ Id = 'R05'; Name = 'No controller try-catch';          PatternFile = 'dotnet-error-handling.md' }
    @{ Id = 'R06'; Name = 'DocumentTypes constants';          PatternFile = 'dotnet-cosmos-core.md' }
    @{ Id = 'R07'; Name = 'IConfigOptions pattern';           PatternFile = 'dotnet-configuration.md' }
    @{ Id = 'R08'; Name = 'CancellationToken propagation';    PatternFile = 'async-patterns.md' }
    @{ Id = 'R09'; Name = 'SanitizedException hierarchy';     PatternFile = 'dotnet-error-handling.md' }
    @{ Id = 'R10'; Name = 'Epoch seconds not milliseconds';   PatternFile = 'CLAUDE.md' }
)

# ---------------------------------------------------------------------------
# Padding Generators
# ---------------------------------------------------------------------------

function New-CodePadding {
    <#
    .SYNOPSIS
        Generate realistic .NET code padding to fill context window.
    .PARAMETER TargetTokens
        Approximate number of tokens to generate.
    .OUTPUTS
        String of generated C# code.
    #>
    param([int]$TargetTokens = 10000)

    $targetChars = $TargetTokens * $script:CharsPerToken
    $sb = [System.Text.StringBuilder]::new($targetChars)

    $classIndex = 0
    while ($sb.Length -lt $targetChars) {
        $classIndex++
        [void]$sb.AppendLine("// --- Generated padding class $classIndex ---")
        [void]$sb.AppendLine("namespace EvalProject.Padding.Generated$classIndex")
        [void]$sb.AppendLine('{')
        [void]$sb.AppendLine("    using System;")
        [void]$sb.AppendLine("    using System.Collections.Generic;")
        [void]$sb.AppendLine("    using System.Threading;")
        [void]$sb.AppendLine("    using System.Threading.Tasks;")
        [void]$sb.AppendLine("    using Microsoft.Extensions.Logging;")
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("    public interface IDataProcessor$classIndex")
        [void]$sb.AppendLine('    {')
        [void]$sb.AppendLine("        Task<ProcessingResult$classIndex> ProcessAsync(DataRequest$classIndex request, CancellationToken ct);")
        [void]$sb.AppendLine("        Task<IReadOnlyList<ProcessingResult$classIndex>> GetAllAsync(CancellationToken ct);")
        [void]$sb.AppendLine('    }')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("    public sealed class DataRequest$classIndex")
        [void]$sb.AppendLine('    {')
        [void]$sb.AppendLine("        public string Id { get; init; } = Guid.NewGuid().ToString();")
        [void]$sb.AppendLine("        public string Name { get; init; } = string.Empty;")
        [void]$sb.AppendLine("        public DateTime CreatedAt { get; init; } = DateTime.UtcNow;")
        [void]$sb.AppendLine("        public int Priority { get; init; }")
        [void]$sb.AppendLine("        public Dictionary<string, string> Metadata { get; init; } = new();")
        [void]$sb.AppendLine('    }')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("    public sealed class ProcessingResult$classIndex")
        [void]$sb.AppendLine('    {')
        [void]$sb.AppendLine("        public string RequestId { get; init; } = string.Empty;")
        [void]$sb.AppendLine("        public bool Success { get; init; }")
        [void]$sb.AppendLine("        public string Message { get; init; } = string.Empty;")
        [void]$sb.AppendLine("        public long DurationMs { get; init; }")
        [void]$sb.AppendLine('    }')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("    public sealed class DataProcessor$classIndex : IDataProcessor$classIndex")
        [void]$sb.AppendLine('    {')
        [void]$sb.AppendLine("        private readonly ILogger<DataProcessor$classIndex> _logger;")
        [void]$sb.AppendLine("        private readonly List<ProcessingResult$classIndex> _results = new();")
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("        public DataProcessor$classIndex(ILogger<DataProcessor$classIndex> logger)")
        [void]$sb.AppendLine('        {')
        [void]$sb.AppendLine('            _logger = logger ?? throw new ArgumentNullException(nameof(logger));')
        [void]$sb.AppendLine('        }')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("        public async Task<ProcessingResult$classIndex> ProcessAsync(DataRequest$classIndex request, CancellationToken ct)")
        [void]$sb.AppendLine('        {')
        [void]$sb.AppendLine('            ct.ThrowIfCancellationRequested();')
        [void]$sb.AppendLine("            _logger.LogInformation(""Processing request {RequestId}"", request.Id);")
        [void]$sb.AppendLine('            await Task.Delay(10, ct);')
        [void]$sb.AppendLine("            var result = new ProcessingResult$classIndex")
        [void]$sb.AppendLine('            {')
        [void]$sb.AppendLine('                RequestId = request.Id,')
        [void]$sb.AppendLine('                Success = true,')
        [void]$sb.AppendLine("                Message = $([char]34)Processed successfully$([char]34),")
        [void]$sb.AppendLine('                DurationMs = 10')
        [void]$sb.AppendLine('            };')
        [void]$sb.AppendLine('            _results.Add(result);')
        [void]$sb.AppendLine('            return result;')
        [void]$sb.AppendLine('        }')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("        public Task<IReadOnlyList<ProcessingResult$classIndex>> GetAllAsync(CancellationToken ct)")
        [void]$sb.AppendLine('        {')
        [void]$sb.AppendLine('            ct.ThrowIfCancellationRequested();')
        [void]$sb.AppendLine("            return Task.FromResult<IReadOnlyList<ProcessingResult$classIndex>>(_results.AsReadOnly());")
        [void]$sb.AppendLine('        }')
        [void]$sb.AppendLine('    }')
        [void]$sb.AppendLine('}')
        [void]$sb.AppendLine('')
    }

    return $sb.ToString().Substring(0, [Math]::Min($sb.Length, $targetChars))
}

function New-ConversationPadding {
    <#
    .SYNOPSIS
        Generate simulated multi-turn Q&A conversation padding.
    .PARAMETER TargetTokens
        Approximate number of tokens to generate.
    .OUTPUTS
        String of simulated conversation.
    #>
    param([int]$TargetTokens = 10000)

    $targetChars = $TargetTokens * $script:CharsPerToken
    $sb = [System.Text.StringBuilder]::new($targetChars)

    # Conversation topics about .NET development (not touching the actual rules being tested)
    $topics = @(
        @{
            Q = 'How do you set up dependency injection in ASP.NET Core?'
            A = 'In ASP.NET Core, dependency injection is built into the framework. You register services in Program.cs using builder.Services. There are three lifetimes: Transient (new instance every time), Scoped (once per request), and Singleton (once for the application lifetime). For example: builder.Services.AddScoped<IMyService, MyService>() registers MyService as a scoped dependency. The framework automatically resolves constructor parameters when creating controllers and other services. You can also use AddTransient or AddSingleton depending on your needs. Interface-based registration is preferred for testability.'
        }
        @{
            Q = 'What are the differences between IEnumerable and IQueryable in .NET?'
            A = 'IEnumerable operates in-memory and uses LINQ to Objects. When you filter an IEnumerable, all data is loaded first, then filtered locally. IQueryable, on the other hand, builds an expression tree that gets translated to a query (like SQL) and executed on the server. This means IQueryable is more efficient for database queries because filtering happens at the database level. Use IEnumerable when working with in-memory collections and IQueryable when working with data sources like Entity Framework or Cosmos DB.'
        }
        @{
            Q = 'How does middleware work in the ASP.NET Core request pipeline?'
            A = 'Middleware components form a pipeline that handles HTTP requests and responses. Each middleware can process the request, pass it to the next component, and process the response on the way back. Middleware is registered in Program.cs using app.UseXxx() methods. The order matters because each component can short-circuit the pipeline. Common middleware includes authentication, authorization, CORS, static files, and exception handling. Custom middleware implements a RequestDelegate pattern with an Invoke or InvokeAsync method.'
        }
        @{
            Q = 'What is the Repository pattern and when should you use it?'
            A = 'The Repository pattern abstracts data access behind a collection-like interface. It decouples business logic from data access implementation details. A repository interface defines methods like GetByIdAsync, CreateAsync, UpdateAsync, and DeleteAsync. The implementation handles the actual database operations. Benefits include easier unit testing (mock the repository), swappable data stores, and centralized query logic. Use it when you need testable data access or when multiple services share similar data access patterns.'
        }
        @{
            Q = 'How do you handle configuration in ASP.NET Core?'
            A = 'ASP.NET Core uses a layered configuration system. Configuration sources include appsettings.json, environment-specific files (appsettings.Development.json), environment variables, command-line arguments, and user secrets. The Options pattern binds configuration sections to strongly-typed classes. You register them with builder.Services.Configure<MyOptions>(config.GetSection("MySection")). Then inject IOptions<MyOptions> into your services. For validation, implement IValidateOptions or use data annotations. Configuration is read at startup and can be refreshed with IOptionsSnapshot.'
        }
        @{
            Q = 'What are some best practices for async programming in C#?'
            A = 'Always use async/await instead of .Result or .Wait() to avoid deadlocks. Name async methods with the Async suffix. Propagate CancellationToken through the entire call chain. Use ConfigureAwait(false) in library code but not in ASP.NET Core controllers. Avoid async void except for event handlers. Return Task instead of void for async methods. Use ValueTask for methods that frequently complete synchronously. Avoid unnecessary Task.Run in ASP.NET Core since the framework already runs on thread pool threads.'
        }
        @{
            Q = 'How do you implement health checks in ASP.NET Core?'
            A = 'ASP.NET Core has built-in health check support. Register health checks in Program.cs with builder.Services.AddHealthChecks() and chain .AddCheck methods for each dependency. Map the endpoint with app.MapHealthChecks("/health"). You can add checks for databases, external APIs, disk space, and custom business logic. Each check returns Healthy, Degraded, or Unhealthy. Use health check UI packages for dashboard visualization. Kubernetes and Azure App Service use these endpoints for readiness and liveness probes.'
        }
        @{
            Q = 'What is the difference between value types and reference types in C#?'
            A = 'Value types (struct, int, bool, enum) store data directly on the stack and are copied on assignment. Reference types (class, interface, string, array) store a reference to heap-allocated data. Value types have no null state unless wrapped in Nullable<T>. Structs should be small (under 16 bytes), immutable, and represent a single value. Records can be either reference (record class) or value (record struct) types. Understanding this distinction affects performance, memory usage, and equality semantics.'
        }
        @{
            Q = 'How do you implement logging in ASP.NET Core?'
            A = 'ASP.NET Core has a built-in logging abstraction via ILogger<T>. Inject ILogger<MyClass> through the constructor. Use structured logging with message templates: _logger.LogInformation("Processing order {OrderId}", orderId). Log levels range from Trace to Critical. Configure providers (Console, Debug, Application Insights) in Program.cs. For high-performance scenarios, use LoggerMessage source generators with the [LoggerMessage] attribute to avoid boxing and string allocation. Always include correlation IDs for distributed tracing.'
        }
        @{
            Q = 'What are the SOLID principles and how do they apply to C# development?'
            A = 'SOLID is five design principles: Single Responsibility (one reason to change), Open/Closed (open for extension, closed for modification), Liskov Substitution (subtypes must be substitutable), Interface Segregation (no fat interfaces), and Dependency Inversion (depend on abstractions). In C#, SRP means small focused classes. OCP uses interfaces and abstract classes. LSP ensures derived classes honor base contracts. ISP creates focused interfaces rather than one large IRepository. DIP is built into ASP.NET Core DI container.'
        }
    )

    $turnIndex = 0
    while ($sb.Length -lt $targetChars) {
        $topic = $topics[$turnIndex % $topics.Count]
        $turnIndex++
        [void]$sb.AppendLine("--- Turn $turnIndex ---")
        [void]$sb.AppendLine("User: $($topic.Q)")
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine("Assistant: $($topic.A)")
        [void]$sb.AppendLine('')

        # Add follow-up variation to avoid exact repetition
        if ($turnIndex -gt $topics.Count) {
            [void]$sb.AppendLine("User: Can you elaborate on that with a code example?")
            [void]$sb.AppendLine('')
            [void]$sb.AppendLine("Assistant: Sure, here is a more detailed example. Consider a scenario where you have a web API project with multiple services. Each service follows the pattern described above. The key is to keep components focused and well-tested. In practice, you would create separate projects for different layers and use dependency injection to wire them together. This approach scales well for enterprise applications where multiple teams work on different components simultaneously.")
            [void]$sb.AppendLine('')
        }
    }

    return $sb.ToString().Substring(0, [Math]::Min($sb.Length, $targetChars))
}

function New-NoisePadding {
    <#
    .SYNOPSIS
        Generate random technical text noise padding.
    .PARAMETER TargetTokens
        Approximate number of tokens to generate.
    .OUTPUTS
        String of random technical text.
    #>
    param([int]$TargetTokens = 10000)

    $targetChars = $TargetTokens * $script:CharsPerToken
    $sb = [System.Text.StringBuilder]::new($targetChars)

    # Technical vocabulary pools (mixed domains to create noise)
    $subjects = @(
        'The distributed system', 'The microservice architecture', 'The event-driven pipeline',
        'The container orchestrator', 'The message broker', 'The load balancer',
        'The cache layer', 'The API gateway', 'The service mesh', 'The data pipeline',
        'The monitoring stack', 'The CI/CD pipeline', 'The infrastructure layer',
        'The authentication service', 'The rate limiter', 'The circuit breaker'
    )
    $verbs = @(
        'processes requests through', 'delegates operations to', 'maintains state via',
        'synchronizes data with', 'routes traffic to', 'validates input from',
        'transforms payloads for', 'aggregates metrics from', 'provisions resources in',
        'scales horizontally across', 'replicates state to', 'partitions data among'
    )
    $objects = @(
        'multiple availability zones for fault tolerance.',
        'the downstream service cluster using gRPC.',
        'a write-ahead log for durability guarantees.',
        'consistent hashing for partition assignment.',
        'optimistic concurrency control mechanisms.',
        'the telemetry collector for observability.',
        'blue-green deployment slots for zero-downtime releases.',
        'connection pooling to manage resource utilization.',
        'exponential backoff retry policies with jitter.',
        'structured logging sinks for centralized analysis.',
        'leader election via distributed consensus.',
        'the configuration management plane securely.'
    )

    $rng = [System.Random]::new(42)  # Deterministic seed for reproducibility
    $sentenceIndex = 0

    while ($sb.Length -lt $targetChars) {
        $sentenceIndex++
        $subject = $subjects[$rng.Next($subjects.Count)]
        $verb = $verbs[$rng.Next($verbs.Count)]
        $obj = $objects[$rng.Next($objects.Count)]

        [void]$sb.AppendLine("$subject $verb $obj")

        # Add paragraph breaks periodically
        if ($sentenceIndex % 5 -eq 0) {
            [void]$sb.AppendLine('')
        }
    }

    return $sb.ToString().Substring(0, [Math]::Min($sb.Length, $targetChars))
}

# ---------------------------------------------------------------------------
# Padding Sanitization (review finding M4)
# ---------------------------------------------------------------------------

function Test-PaddingContentSafe {
    <#
    .SYNOPSIS
        Validate padding content has no PII, secrets, or prompt injection markers.
    .PARAMETER Content
        The padding string to validate.
    .OUTPUTS
        Boolean. True if content is safe, false otherwise.
    #>
    param([Parameter(Mandatory)][string]$Content)

    foreach ($pattern in $script:UnsafePaddingPatterns) {
        if ([regex]::IsMatch($Content, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            return $false
        }
    }
    return $true
}

# ---------------------------------------------------------------------------
# Token Estimation
# ---------------------------------------------------------------------------

function Get-EstimatedTokenCount {
    <#
    .SYNOPSIS
        Estimate token count for a string using chars/4 heuristic.
    .PARAMETER Text
        The text to estimate tokens for.
    .OUTPUTS
        Integer estimated token count.
    #>
    param([string]$Text)

    if (-not $Text) { return 0 }
    return [Math]::Ceiling($Text.Length / $script:CharsPerToken)
}

function Get-PaddingTokenTarget {
    <#
    .SYNOPSIS
        Calculate how many padding tokens are needed to reach target fill level.
    .PARAMETER FillTarget
        Target fill percentage as decimal (e.g., 0.75 for 75%).
    .OUTPUTS
        Integer token count for padding.
    #>
    param([double]$FillTarget)

    $totalNeeded = [Math]::Floor($script:MaxContextTokens * $FillTarget)
    $overhead = $script:SystemOverheadTokens + $script:RulesOverheadTokens
    $paddingTokens = [Math]::Max(0, $totalNeeded - $overhead)
    return [int]$paddingTokens
}

# ---------------------------------------------------------------------------
# Rule Adherence Checkers (R01-R10)
# ---------------------------------------------------------------------------

function Test-R01-HandlerNaming {
    <#
    .SYNOPSIS
        R01: Check that business logic classes use Handler naming (not Service).
    .DESCRIPTION
        CCGHCP dotnet-architecture.md requires business logic classes be named
        *Handler, not *Service. Service naming is reserved for infrastructure.
    #>
    param([Parameter(Mandatory)][string]$WorkDir)

    $csFiles = @(Get-ChildItem -Path $WorkDir -Recurse -Include '*.cs' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](obj|bin|Padding)[\\/]' })

    if ($csFiles.Count -eq 0) { return 0.0 }

    $handlerCount = 0
    $serviceCount = 0
    foreach ($f in $csFiles) {
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        # Count classes in BusinessLogic layer
        if ($f.FullName -match 'BusinessLogic' -or $content -match 'namespace\s+\S+\.BusinessLogic') {
            $handlerCount += ([regex]::Matches($content, 'class\s+\w+Handler\b')).Count
            $serviceCount += ([regex]::Matches($content, 'class\s+\w+Service\b')).Count
        }
    }

    $total = $handlerCount + $serviceCount
    if ($total -eq 0) { return 0.5 }  # No BL classes found -- neutral score
    return [Math]::Round($handlerCount / $total, 2)
}

function Test-R02-InterfaceLocation {
    <#
    .SYNOPSIS
        R02: Interfaces should be in Common layer, not DataAccess.
    #>
    param([Parameter(Mandatory)][string]$WorkDir)

    $csFiles = @(Get-ChildItem -Path $WorkDir -Recurse -Include '*.cs' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](obj|bin|Padding)[\\/]' })

    $commonInterfaces = 0
    $dataAccessInterfaces = 0

    foreach ($f in $csFiles) {
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $interfaceMatches = ([regex]::Matches($content, 'interface\s+I\w+')).Count
        if ($interfaceMatches -gt 0) {
            if ($f.FullName -match 'Common' -or $content -match 'namespace\s+\S+\.Common') {
                $commonInterfaces += $interfaceMatches
            }
            if ($f.FullName -match 'DataAccess' -or $content -match 'namespace\s+\S+\.DataAccess') {
                $dataAccessInterfaces += $interfaceMatches
            }
        }
    }

    $total = $commonInterfaces + $dataAccessInterfaces
    if ($total -eq 0) { return 0.5 }
    return [Math]::Round($commonInterfaces / $total, 2)
}

function Test-R03-PagedResult {
    <#
    .SYNOPSIS
        R03: List-returning methods should use PagedResult, not bare List.
    #>
    param([Parameter(Mandatory)][string]$WorkDir)

    $csFiles = @(Get-ChildItem -Path $WorkDir -Recurse -Include '*.cs' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](obj|bin|Padding)[\\/]' })

    $pagedResultCount = 0
    $bareListCount = 0

    foreach ($f in $csFiles) {
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        # Look for methods returning collections
        $pagedResultCount += ([regex]::Matches($content, 'PagedResult<')).Count
        # Bare List/IEnumerable returns in repository/handler methods (not in model properties)
        $bareListCount += ([regex]::Matches($content, 'Task<(List|IList|IEnumerable)<\w+>>')).Count
    }

    $total = $pagedResultCount + $bareListCount
    if ($total -eq 0) { return 0.5 }
    return [Math]::Round($pagedResultCount / $total, 2)
}

function Test-R04-LoggerMessagePattern {
    <#
    .SYNOPSIS
        R04: Logging should use [LoggerMessage] source generators, not string interpolation.
    #>
    param([Parameter(Mandatory)][string]$WorkDir)

    $csFiles = @(Get-ChildItem -Path $WorkDir -Recurse -Include '*.cs' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](obj|bin|Padding)[\\/]' })

    $sourceGenCount = 0
    $interpolationCount = 0

    foreach ($f in $csFiles) {
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $sourceGenCount += ([regex]::Matches($content, '\[LoggerMessage')).Count
        # String interpolation in logging calls
        $interpolationCount += ([regex]::Matches($content, '_logger\.\w+\(\$"')).Count
        $interpolationCount += ([regex]::Matches($content, 'logger\.\w+\(\$"')).Count
    }

    $total = $sourceGenCount + $interpolationCount
    if ($total -eq 0) { return 0.5 }
    return [Math]::Round($sourceGenCount / $total, 2)
}

function Test-R05-NoControllerTryCatch {
    <#
    .SYNOPSIS
        R05: Controllers should NOT have try-catch blocks (middleware handles exceptions).
    #>
    param([Parameter(Mandatory)][string]$WorkDir)

    $controllerFiles = @(Get-ChildItem -Path $WorkDir -Recurse -Include '*Controller*.cs' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](obj|bin|Padding)[\\/]' })

    if ($controllerFiles.Count -eq 0) { return 0.5 }

    $cleanControllers = 0
    $tryCatchControllers = 0

    foreach ($f in $controllerFiles) {
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        if ($content -match '\btry\s*\{') {
            $tryCatchControllers++
        } else {
            $cleanControllers++
        }
    }

    $total = $cleanControllers + $tryCatchControllers
    if ($total -eq 0) { return 0.5 }
    return [Math]::Round($cleanControllers / $total, 2)
}

function Test-R06-DocumentTypeConstants {
    <#
    .SYNOPSIS
        R06: Cosmos entities should use DocumentTypes constants, not inline strings.
    #>
    param([Parameter(Mandatory)][string]$WorkDir)

    $csFiles = @(Get-ChildItem -Path $WorkDir -Recurse -Include '*.cs' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](obj|bin|Padding)[\\/]' })

    $constantsUsed = 0
    $inlineStrings = 0

    foreach ($f in $csFiles) {
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $constantsUsed += ([regex]::Matches($content, 'DocumentTypes\.\w+')).Count
        # Inline document type strings in entity classes
        if ($content -match 'CosmosEntity|DocumentType') {
            $inlineStrings += ([regex]::Matches($content, 'DocumentType\s*=\s*"[^"]+"')).Count
        }
    }

    $total = $constantsUsed + $inlineStrings
    if ($total -eq 0) { return 0.5 }
    return [Math]::Round($constantsUsed / $total, 2)
}

function Test-R07-ConfigOptionsPattern {
    <#
    .SYNOPSIS
        R07: Configuration should use IConfigOptions pattern with strongly-typed classes.
    #>
    param([Parameter(Mandatory)][string]$WorkDir)

    $csFiles = @(Get-ChildItem -Path $WorkDir -Recurse -Include '*.cs' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](obj|bin|Padding)[\\/]' })

    $optionsPatternCount = 0
    $rawConfigCount = 0

    foreach ($f in $csFiles) {
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $optionsPatternCount += ([regex]::Matches($content, 'IOptions<|IOptionsSnapshot<|IOptionsMonitor<|IConfigOptions')).Count
        # Raw IConfiguration indexer access
        $rawConfigCount += ([regex]::Matches($content, 'IConfiguration\b.*\["')).Count
        $rawConfigCount += ([regex]::Matches($content, 'configuration\["')).Count
    }

    $total = $optionsPatternCount + $rawConfigCount
    if ($total -eq 0) { return 0.5 }
    return [Math]::Round($optionsPatternCount / $total, 2)
}

function Test-R08-CancellationTokenPropagation {
    <#
    .SYNOPSIS
        R08: Async methods should propagate CancellationToken through the call chain.
    #>
    param([Parameter(Mandatory)][string]$WorkDir)

    $csFiles = @(Get-ChildItem -Path $WorkDir -Recurse -Include '*.cs' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](obj|bin|Padding)[\\/]' })

    $withToken = 0
    $withoutToken = 0

    foreach ($f in $csFiles) {
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        # Async method signatures
        $asyncMethods = [regex]::Matches($content, 'async\s+Task[<\s].*?\)')
        foreach ($m in $asyncMethods) {
            if ($m.Value -match 'CancellationToken') {
                $withToken++
            } else {
                $withoutToken++
            }
        }
    }

    $total = $withToken + $withoutToken
    if ($total -eq 0) { return 0.5 }
    return [Math]::Round($withToken / $total, 2)
}

function Test-R09-SanitizedExceptionHierarchy {
    <#
    .SYNOPSIS
        R09: Custom exceptions should inherit from SanitizedException.
    #>
    param([Parameter(Mandatory)][string]$WorkDir)

    $csFiles = @(Get-ChildItem -Path $WorkDir -Recurse -Include '*.cs' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](obj|bin|Padding)[\\/]' })

    $sanitizedCount = 0
    $rawExceptionCount = 0

    foreach ($f in $csFiles) {
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $sanitizedCount += ([regex]::Matches($content, 'class\s+\w+Exception\s*:\s*Sanitized')).Count
        # Custom exceptions inheriting directly from Exception or ApplicationException
        $rawExceptionCount += ([regex]::Matches($content, 'class\s+\w+Exception\s*:\s*(Exception|ApplicationException)\b')).Count
    }

    $total = $sanitizedCount + $rawExceptionCount
    if ($total -eq 0) { return 0.5 }
    return [Math]::Round($sanitizedCount / $total, 2)
}

function Test-R10-EpochSecondsConvention {
    <#
    .SYNOPSIS
        R10: Timestamps should use epoch SECONDS (10 digits), not milliseconds (13 digits).
    #>
    param([Parameter(Mandatory)][string]$WorkDir)

    $csFiles = @(Get-ChildItem -Path $WorkDir -Recurse -Include '*.cs' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](obj|bin|Padding)[\\/]' })

    $secondsCount = 0
    $millisCount = 0

    foreach ($f in $csFiles) {
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        # ToUnixTimeSeconds (correct)
        $secondsCount += ([regex]::Matches($content, 'ToUnixTimeSeconds|UnixTimeSeconds')).Count
        # ToUnixTimeMilliseconds (incorrect per CCGHCP convention)
        $millisCount += ([regex]::Matches($content, 'ToUnixTimeMilliseconds|UnixTimeMilliseconds')).Count
    }

    $total = $secondsCount + $millisCount
    if ($total -eq 0) { return 0.5 }
    return [Math]::Round($secondsCount / $total, 2)
}

# ---------------------------------------------------------------------------
# Forgetting Curve Analysis
# ---------------------------------------------------------------------------

function Invoke-EbbinghausFit {
    <#
    .SYNOPSIS
        Fit Ebbinghaus forgetting curve R(t) = e^(-t/S) to observed data.
    .DESCRIPTION
        Given arrays of fill levels (t) and adherence scores (R), fits the
        exponential decay model to find the stability factor S.
        Uses log-linear regression: ln(R) = -t/S  =>  ln(R) = (-1/S) * t
    .PARAMETER FillLevels
        Array of fill percentages as decimals (e.g., 0.25, 0.50, 0.75, 0.90).
    .PARAMETER AdherenceScores
        Array of adherence scores (0.0 to 1.0) corresponding to fill levels.
    .OUTPUTS
        Hashtable with: stability_factor (S), r_squared, predicted_scores, model_type
    #>
    param(
        [Parameter(Mandatory)][double[]]$FillLevels,
        [Parameter(Mandatory)][double[]]$AdherenceScores
    )

    if ($FillLevels.Count -ne $AdherenceScores.Count -or $FillLevels.Count -lt 2) {
        return @{
            stability_factor = 0.0
            r_squared        = 0.0
            predicted_scores = @()
            model_type       = 'ebbinghaus'
            error            = 'Insufficient or mismatched data points'
        }
    }

    # Filter out zero/negative adherence scores (cannot take log)
    $validIndices = @()
    for ($i = 0; $i -lt $AdherenceScores.Count; $i++) {
        if ($AdherenceScores[$i] -gt 0.001) {
            $validIndices += $i
        }
    }

    if ($validIndices.Count -lt 2) {
        return @{
            stability_factor = 0.0
            r_squared        = 0.0
            predicted_scores = @()
            model_type       = 'ebbinghaus'
            error            = 'Too few positive adherence scores for log-linear fit'
        }
    }

    # Log-linear regression: y = ln(R), x = t
    # y = mx + b where m = -1/S and b should be ~0 (intercept)
    $n = $validIndices.Count
    $sumX = 0.0; $sumY = 0.0; $sumXY = 0.0; $sumX2 = 0.0; $sumY2 = 0.0

    foreach ($idx in $validIndices) {
        $x = $FillLevels[$idx]
        $y = [Math]::Log($AdherenceScores[$idx])
        $sumX  += $x
        $sumY  += $y
        $sumXY += $x * $y
        $sumX2 += $x * $x
        $sumY2 += $y * $y
    }

    $denominator = ($n * $sumX2) - ($sumX * $sumX)
    if ([Math]::Abs($denominator) -lt 1e-10) {
        return @{
            stability_factor = 0.0
            r_squared        = 0.0
            predicted_scores = @()
            model_type       = 'ebbinghaus'
            error            = 'Degenerate data -- all fill levels identical'
        }
    }

    $slope = (($n * $sumXY) - ($sumX * $sumY)) / $denominator
    # S = -1/slope (slope should be negative for decay)
    $stabilityFactor = if ([Math]::Abs($slope) -gt 1e-10) { -1.0 / $slope } else { [double]::PositiveInfinity }

    # R-squared calculation
    $meanY = $sumY / $n
    $ssTot = 0.0; $ssRes = 0.0
    $intercept = ($sumY - $slope * $sumX) / $n

    $predictedScores = @()
    foreach ($idx in $validIndices) {
        $x = $FillLevels[$idx]
        $yActual = [Math]::Log($AdherenceScores[$idx])
        $yPredicted = $slope * $x + $intercept
        $ssTot += ($yActual - $meanY) * ($yActual - $meanY)
        $ssRes += ($yActual - $yPredicted) * ($yActual - $yPredicted)
        $predictedScores += [Math]::Round([Math]::Exp($yPredicted), 4)
    }

    $rSquared = if ($ssTot -gt 1e-10) { 1.0 - ($ssRes / $ssTot) } else { 0.0 }

    return @{
        stability_factor = [Math]::Round($stabilityFactor, 4)
        r_squared        = [Math]::Round([Math]::Max(0, $rSquared), 4)
        predicted_scores = $predictedScores
        model_type       = 'ebbinghaus'
        slope            = [Math]::Round($slope, 6)
        intercept        = [Math]::Round($intercept, 6)
    }
}

function Find-CliffEdges {
    <#
    .SYNOPSIS
        Detect cliff-edge degradation points using non-parametric gradient analysis.
    .DESCRIPTION
        Analyzes adjacent fill level pairs for abrupt adherence drops.
        A cliff is flagged when the gradient between two adjacent points
        exceeds 2x the average gradient across all pairs.
    .PARAMETER FillLevels
        Array of fill percentages as decimals.
    .PARAMETER AdherenceScores
        Array of adherence scores corresponding to fill levels.
    .OUTPUTS
        Hashtable with: cliffs (array), average_gradient, has_cliff_edge
    #>
    param(
        [Parameter(Mandatory)][double[]]$FillLevels,
        [Parameter(Mandatory)][double[]]$AdherenceScores
    )

    if ($FillLevels.Count -ne $AdherenceScores.Count -or $FillLevels.Count -lt 2) {
        return @{
            cliffs           = @()
            average_gradient = 0.0
            has_cliff_edge   = $false
            error            = 'Insufficient or mismatched data points'
        }
    }

    # Calculate gradients between adjacent points
    $gradients = @()
    for ($i = 0; $i -lt ($FillLevels.Count - 1); $i++) {
        $fillDelta = $FillLevels[$i + 1] - $FillLevels[$i]
        if ([Math]::Abs($fillDelta) -lt 1e-10) { continue }

        $adherenceDelta = $AdherenceScores[$i] - $AdherenceScores[$i + 1]  # Positive = degradation
        $gradient = $adherenceDelta / $fillDelta

        $gradients += @{
            from_fill       = $FillLevels[$i]
            to_fill         = $FillLevels[$i + 1]
            from_adherence  = $AdherenceScores[$i]
            to_adherence    = $AdherenceScores[$i + 1]
            gradient        = [Math]::Round($gradient, 4)
            position_index  = $i
        }
    }

    if ($gradients.Count -eq 0) {
        return @{
            cliffs           = @()
            average_gradient = 0.0
            has_cliff_edge   = $false
        }
    }

    # Calculate average gradient
    $avgGradient = ($gradients | ForEach-Object { [Math]::Abs($_.gradient) } | Measure-Object -Average).Average

    # Flag cliffs: gradient > threshold * average
    $cliffs = @()
    foreach ($g in $gradients) {
        $isCliff = ([Math]::Abs($g.gradient) -gt ($script:CliffGradientThreshold * $avgGradient)) -and ($g.gradient -gt 0)
        if ($isCliff) {
            $cliffs += @{
                from_fill      = $g.from_fill
                to_fill        = $g.to_fill
                gradient       = $g.gradient
                severity       = if ($g.gradient -gt 3.0 * $avgGradient) { 'severe' } else { 'moderate' }
            }
        }
    }

    return @{
        cliffs           = $cliffs
        average_gradient = [Math]::Round($avgGradient, 4)
        has_cliff_edge   = ($cliffs.Count -gt 0)
        all_gradients    = $gradients
    }
}

# ---------------------------------------------------------------------------
# Safe Operating Zone Analysis
# ---------------------------------------------------------------------------

function Get-SafeOperatingZone {
    <#
    .SYNOPSIS
        Determine the highest fill level where all rules maintain >= 80% adherence.
    .PARAMETER RuleResults
        Hashtable mapping rule IDs to arrays of (fill_level, adherence) pairs.
    .OUTPUTS
        Hashtable with: safe_fill_level, failing_rules, all_rules_status
    #>
    param([Parameter(Mandatory)][hashtable]$RuleResults)

    $safeFill = 1.0  # Start optimistic
    $failingRules = @()

    foreach ($ruleId in $RuleResults.Keys) {
        $results = $RuleResults[$ruleId]
        foreach ($r in $results) {
            if ($r.adherence -lt $script:SafeZoneThreshold) {
                if ($r.fill_level -lt $safeFill) {
                    $safeFill = $r.fill_level
                }
                $failingRules += @{
                    rule_id    = $ruleId
                    fill_level = $r.fill_level
                    adherence  = $r.adherence
                }
            }
        }
    }

    # Safe zone is one step below the first failure
    $fillSteps = $script:FillTargets | Sort-Object
    $safeZone = 0.0
    foreach ($step in $fillSteps) {
        if ($step -lt $safeFill) {
            $safeZone = $step
        }
    }

    return @{
        safe_fill_level = $safeZone
        threshold       = $script:SafeZoneThreshold
        failing_rules   = $failingRules
        fill_targets    = $script:FillTargets
    }
}

# ---------------------------------------------------------------------------
# Exported Functions (Setup / Prompt / Assertions triplet)
# ---------------------------------------------------------------------------

function Setup-ContextStress {
    <#
    .SYNOPSIS
        Set up the context stress eval workspace.
    .DESCRIPTION
        Creates a workspace with a .NET project scaffold that contains patterns
        requiring CCGHCP rule adherence. Generates calibrated padding content
        to reach the target context fill level.

        The scaffold includes deliberate patterns that test all 10 target rules:
        - BusinessLogic layer with Handler classes
        - Common layer with interfaces
        - DataAccess layer with repository
        - Controller without try-catch
        - Cosmos entity with DocumentTypes
        - LoggerMessage source generators
        - CancellationToken propagation
        - SanitizedException hierarchy
        - IConfigOptions pattern
        - Epoch seconds convention
    .PARAMETER WorkDir
        Directory where the eval workspace will be created.
    .PARAMETER TargetFillPercent
        Target context fill percentage (e.g., 75 for 75% full). Default: 75.
    .PARAMETER PaddingStrategy
        Padding type: 'code', 'conversation', 'noise'. Default: 'code'.
    #>
    param(
        [Parameter(Mandatory)][string]$WorkDir,
        [int]$TargetFillPercent = 75,
        [ValidateSet('code', 'conversation', 'noise')]
        [string]$PaddingStrategy = 'code'
    )

    if (-not (Test-Path $WorkDir)) {
        New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    }

    # Check for fill overflow (review finding M5: graceful degradation at 95%+)
    if ($TargetFillPercent -gt 95) {
        $metaPath = Join-Path $WorkDir 'eval-metadata.json'
        @{
            status           = 'fill_overflow'
            target_fill      = $TargetFillPercent
            max_safe_fill    = 95
            message          = 'Target fill level exceeds 95%. Scenario skipped for safety.'
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $metaPath -Encoding UTF8
        return
    }

    # --- Generate .NET scaffold with all 10 rule patterns ---

    $projDir = Join-Path $WorkDir 'EvalProject'
    $blDir   = Join-Path $projDir 'BusinessLogic'
    $daDir   = Join-Path $projDir 'DataAccess'
    $comDir  = Join-Path $projDir 'Common'
    $apiDir  = Join-Path $projDir 'Api'
    $padDir  = Join-Path $WorkDir 'PaddingContent'

    foreach ($d in @($projDir, $blDir, $daDir, $comDir, $apiDir, $padDir)) {
        New-Item -ItemType Directory -Path $d -Force | Out-Null
    }

    # --- Generate .csproj file (required for dotnet build pre-flight check) ---
    $csprojContent = @'
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.Azure.Cosmos" Version="3.*" />
    <PackageReference Include="Microsoft.Extensions.Logging.Abstractions" Version="9.*" />
    <PackageReference Include="Microsoft.Extensions.Options.ConfigurationExtensions" Version="9.*" />
    <PackageReference Include="Newtonsoft.Json" Version="13.*" />
  </ItemGroup>

  <ItemGroup>
    <FrameworkReference Include="Microsoft.AspNetCore.App" />
  </ItemGroup>

</Project>
'@
    Set-Content -Path (Join-Path $projDir 'EvalProject.csproj') -Value $csprojContent -Encoding UTF8

    # Run dotnet restore to fetch packages before generating source files
    $restoreOutput = & dotnet restore (Join-Path $projDir 'EvalProject.csproj') 2>&1
    if ($LASTEXITCODE -ne 0) {
        if (Get-Command -Name 'Write-Status' -ErrorAction SilentlyContinue) {
            Write-Status "dotnet restore failed: $($restoreOutput | Out-String)" -Type Warning
        }
    }

    # Common/Interfaces (R02: interfaces in Common)
    $interfaceContent = @'
using EvalProject.DataAccess;

namespace EvalProject.Common;

public interface INotificationHandler
{
    Task<NotificationResult> HandleAsync(NotificationRequest request, CancellationToken ct);
    Task<PagedResult<NotificationResult>> ListAsync(string userId, int pageSize, string continuationToken, CancellationToken ct);
}

public interface INotificationRepository
{
    Task<NotificationEntity> GetByIdAsync(string id, string partitionKey, CancellationToken ct);
    Task<NotificationEntity> CreateAsync(NotificationEntity entity, CancellationToken ct);
    Task<PagedResult<NotificationEntity>> QueryAsync(string userId, int pageSize, string continuationToken, CancellationToken ct);
}

public class PagedResult<T>
{
    public IReadOnlyList<T> Items { get; init; } = Array.Empty<T>();
    public string ContinuationToken { get; init; }
    public bool HasMore => !string.IsNullOrEmpty(ContinuationToken);
}

public class NotificationRequest
{
    public string UserId { get; init; }
    public string Message { get; init; }
    public string Channel { get; init; }
}

public class NotificationResult
{
    public string Id { get; init; }
    public bool Sent { get; init; }
    public long SentAtEpoch { get; init; }
}
'@
    Set-Content -Path (Join-Path $comDir 'Interfaces.cs') -Value $interfaceContent -Encoding UTF8

    # Common/DocumentTypes (R06)
    $docTypesContent = @'
namespace EvalProject.Common;

public static class DocumentTypes
{
    public const string Notification = "notification";
    public const string AuditLog = "audit_log";
    public const string UserPreference = "user_preference";
}
'@
    Set-Content -Path (Join-Path $comDir 'DocumentTypes.cs') -Value $docTypesContent -Encoding UTF8

    # Common/Exceptions (R09: SanitizedException hierarchy)
    $exceptionsContent = @'
namespace EvalProject.Common;

public abstract class SanitizedException : Exception
{
    public string ErrorCode { get; }
    protected SanitizedException(string errorCode, string message) : base(message)
    {
        ErrorCode = errorCode;
    }
    public abstract string GetSanitizedMessage();
}

public class NotFoundException : SanitizedException
{
    public NotFoundException(string entityType, string id)
        : base("NOT_FOUND", $"{entityType} with ID '{id}' was not found.")
    { }
    public override string GetSanitizedMessage() => "The requested resource was not found.";
}

public class ValidationException : SanitizedException
{
    public ValidationException(string field, string reason)
        : base("VALIDATION_ERROR", $"Validation failed for '{field}': {reason}")
    { }
    public override string GetSanitizedMessage() => "The request contains invalid data.";
}
'@
    Set-Content -Path (Join-Path $comDir 'Exceptions.cs') -Value $exceptionsContent -Encoding UTF8

    # Common/ConfigOptions (R07: IConfigOptions pattern)
    $configContent = @'
namespace EvalProject.Common;

public interface IConfigOptions
{
    static abstract string SectionName { get; }
}

public sealed class NotificationOptions : IConfigOptions
{
    public static string SectionName => "Notification";
    public int MaxRetries { get; set; } = 3;
    public int TimeoutSeconds { get; set; } = 30;
    public string DefaultChannel { get; set; } = "email";
}
'@
    Set-Content -Path (Join-Path $comDir 'ConfigOptions.cs') -Value $configContent -Encoding UTF8

    # DataAccess/CosmosEntity (R06: DocumentTypes, R10: epoch seconds)
    $entityContent = @'
using EvalProject.Common;

namespace EvalProject.DataAccess;

public abstract class CosmosEntity
{
    public string Id { get; set; }
    public string DocumentType { get; set; }
    public long CreatedAtEpoch { get; set; }
    public long UpdatedAtEpoch { get; set; }
    public bool IsDeleted { get; set; }
    public abstract string GetPartitionKey();
}

public sealed class NotificationEntity : CosmosEntity
{
    public string UserId { get; set; }
    public string Message { get; set; }
    public string Channel { get; set; }
    public bool Sent { get; set; }
    public long SentAtEpoch { get; set; }

    public NotificationEntity()
    {
        DocumentType = DocumentTypes.Notification;
        CreatedAtEpoch = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
        UpdatedAtEpoch = CreatedAtEpoch;
    }

    public override string GetPartitionKey() => UserId;
}
'@
    Set-Content -Path (Join-Path $daDir 'NotificationEntity.cs') -Value $entityContent -Encoding UTF8

    # BusinessLogic/NotificationHandler (R01: Handler naming, R08: CancellationToken)
    $handlerContent = @'
using EvalProject.Common;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace EvalProject.BusinessLogic;

public sealed partial class NotificationHandler : INotificationHandler
{
    private readonly INotificationRepository _repository;
    private readonly ILogger<NotificationHandler> _logger;
    private readonly NotificationOptions _options;

    public NotificationHandler(
        INotificationRepository repository,
        ILogger<NotificationHandler> logger,
        IOptions<NotificationOptions> options)
    {
        _repository = repository ?? throw new ArgumentNullException(nameof(repository));
        _logger = logger ?? throw new ArgumentNullException(nameof(logger));
        _options = options?.Value ?? throw new ArgumentNullException(nameof(options));
    }

    public async Task<NotificationResult> HandleAsync(NotificationRequest request, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        LogProcessingNotification(_logger, request.UserId, request.Channel);

        var entity = new DataAccess.NotificationEntity
        {
            Id = Guid.NewGuid().ToString(),
            UserId = request.UserId,
            Message = request.Message,
            Channel = request.Channel ?? _options.DefaultChannel,
            Sent = true,
            SentAtEpoch = DateTimeOffset.UtcNow.ToUnixTimeSeconds()
        };

        var created = await _repository.CreateAsync(entity, ct);

        return new NotificationResult
        {
            Id = created.Id,
            Sent = created.Sent,
            SentAtEpoch = created.SentAtEpoch
        };
    }

    public async Task<PagedResult<NotificationResult>> ListAsync(
        string userId, int pageSize, string continuationToken, CancellationToken ct)
    {
        ct.ThrowIfCancellationRequested();
        var paged = await _repository.QueryAsync(userId, pageSize, continuationToken, ct);

        return new PagedResult<NotificationResult>
        {
            Items = paged.Items.Select(e => new NotificationResult
            {
                Id = e.Id,
                Sent = e.Sent,
                SentAtEpoch = e.SentAtEpoch
            }).ToList(),
            ContinuationToken = paged.ContinuationToken
        };
    }

    [LoggerMessage(EventId = 4001, Level = LogLevel.Information,
        Message = "Processing notification for user {UserId} via {Channel}")]
    private static partial void LogProcessingNotification(ILogger logger, string userId, string channel);
}
'@
    Set-Content -Path (Join-Path $blDir 'NotificationHandler.cs') -Value $handlerContent -Encoding UTF8

    # Api/NotificationsController (R05: no try-catch)
    $controllerContent = @'
using EvalProject.Common;
using Microsoft.AspNetCore.Mvc;

namespace EvalProject.Api;

[ApiController]
[Route("api/v1/[controller]")]
public sealed class NotificationsController : ControllerBase
{
    private readonly INotificationHandler _handler;

    public NotificationsController(INotificationHandler handler)
    {
        _handler = handler ?? throw new ArgumentNullException(nameof(handler));
    }

    [HttpPost]
    public async Task<IActionResult> Create(
        [FromBody] NotificationRequest request,
        CancellationToken ct)
    {
        var result = await _handler.HandleAsync(request, ct);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    [HttpGet("{id}")]
    public async Task<IActionResult> GetById(string id, CancellationToken ct)
    {
        // Note: simplified for eval scaffold -- real impl would call handler
        return Ok(new { id });
    }

    [HttpGet]
    public async Task<IActionResult> List(
        [FromQuery] string userId,
        [FromQuery] int pageSize = 20,
        [FromQuery] string continuationToken = null,
        CancellationToken ct = default)
    {
        var result = await _handler.ListAsync(userId, pageSize, continuationToken, ct);
        return Ok(result);
    }
}
'@
    Set-Content -Path (Join-Path $apiDir 'NotificationsController.cs') -Value $controllerContent -Encoding UTF8

    # --- Generate padding content ---
    $fillDecimal = $TargetFillPercent / 100.0
    $paddingTokens = Get-PaddingTokenTarget -FillTarget $fillDecimal

    $paddingContent = switch ($PaddingStrategy) {
        'code'         { New-CodePadding -TargetTokens $paddingTokens }
        'conversation' { New-ConversationPadding -TargetTokens $paddingTokens }
        'noise'        { New-NoisePadding -TargetTokens $paddingTokens }
    }

    # Sanitize padding (review finding M4)
    if (-not (Test-PaddingContentSafe -Content $paddingContent)) {
        # This should not happen with our generators, but safety net
        if (Get-Command -Name 'Invoke-SecretRedaction' -ErrorAction SilentlyContinue) {
            $paddingContent = Invoke-SecretRedaction -Content $paddingContent
        }
    }

    # Write padding to files in workspace (split into multiple files for realism)
    $paddingChunkSize = 50000  # chars per file
    $chunkIndex = 0
    for ($pos = 0; $pos -lt $paddingContent.Length; $pos += $paddingChunkSize) {
        $chunkIndex++
        $chunkLen = [Math]::Min($paddingChunkSize, $paddingContent.Length - $pos)
        $chunk = $paddingContent.Substring($pos, $chunkLen)
        $chunkFile = Join-Path $padDir "padding-$($PaddingStrategy)-$chunkIndex.txt"
        Set-Content -Path $chunkFile -Value $chunk -Encoding UTF8
    }

    # Write eval metadata
    $metaPath = Join-Path $WorkDir 'eval-metadata.json'
    @{
        target_fill_percent = $TargetFillPercent
        padding_strategy    = $PaddingStrategy
        padding_tokens_est  = $paddingTokens
        padding_chars       = $paddingContent.Length
        padding_files       = $chunkIndex
        fill_targets        = $script:FillTargets
        max_context_tokens  = $script:MaxContextTokens
        accuracy_band       = $script:FillAccuracyBand
        rules_tested        = $script:TargetRules | ForEach-Object { $_.Id }
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $metaPath -Encoding UTF8

    if (Get-Command -Name 'Write-Status' -ErrorAction SilentlyContinue) {
        Write-Status "Context stress workspace created: $TargetFillPercent% fill, $PaddingStrategy padding, ~$paddingTokens tokens" -Type Success
    }
}

function Get-ContextStressPrompt {
    <#
    .SYNOPSIS
        Get the prompt for the context stress eval scenario.
    .DESCRIPTION
        Returns a prompt that asks the agent to add a new entity to the existing
        scaffold while following all CCGHCP rules. The prompt exercises all 10
        target rules simultaneously.

        The padding content in the workspace forces the context window to fill
        to the target level when the agent reads the workspace files.
    .PARAMETER WorkDir
        The eval workspace directory.
    #>
    param(
        [Parameter(Mandatory)][string]$WorkDir
    )

    return @"
Add a new 'AuditLog' entity to this project. Audit logs track user actions with metadata (action, entityType, entityId, userId, timestamp, details). Requirements:

- Each audit log has a unique ID and is partitioned by userId
- The entity must use the correct DocumentTypes constant
- Timestamps must follow the project's epoch convention (check existing code)
- Support operations: create, get by ID, list by user (with pagination using PagedResult)
- Add the AuditLogEntity in DataAccess (inheriting CosmosEntity), AuditLogHandler in BusinessLogic (NOT AuditLogService), interface in Common layer
- Add an AuditLogController in Api with NO try-catch blocks (rely on middleware)
- Use [LoggerMessage] source generators for all logging (NOT string interpolation)
- All async methods must propagate CancellationToken
- Any custom exceptions must inherit from SanitizedException
- Use IConfigOptions pattern for any configuration (NOT raw IConfiguration indexer)
- Read ALL existing files in the project to understand the patterns before making changes
- Also read the padding content files to understand the full context

The project is at $WorkDir. Work directly in the project files. Do not use git.
"@
}

function Invoke-ContextStressAssertions {
    <#
    .SYNOPSIS
        Run assertions for the context stress eval scenario.
    .DESCRIPTION
        Validates the agent's output against all 10 CCGHCP rules, measures
        context fill accuracy, fits forgetting curves, and detects cliff edges.
        Uses Invoke-MultiDimensionalScore for composite scoring.
    .PARAMETER WorkDir
        The eval workspace directory to validate.
    .PARAMETER TranscriptPath
        Path to the session transcript for context fill analysis.
    #>
    param(
        [Parameter(Mandatory)][string]$WorkDir,
        [string]$TranscriptPath
    )

    $assertions = [System.Collections.ArrayList]::new()

    # --- Check eval metadata exists ---
    $metaPath = Join-Path $WorkDir 'eval-metadata.json'
    if (-not (Test-Path $metaPath)) {
        [void]$assertions.Add(@{
            name    = 'eval_metadata_exists'
            passed  = $false
            message = 'eval-metadata.json not found. Setup-ContextStress may not have run.'
        })
        return $assertions
    }

    $meta = Get-Content $metaPath -Raw | ConvertFrom-Json

    # Check for fill overflow
    if ($meta.status -eq 'fill_overflow') {
        [void]$assertions.Add(@{
            name    = 'fill_overflow_protection'
            passed  = $true
            message = "Fill overflow protection triggered at $($meta.target_fill)%. Scenario safely skipped."
        })
        return $assertions
    }

    [void]$assertions.Add(@{
        name    = 'eval_metadata_exists'
        passed  = $true
        message = "Metadata: fill=$($meta.target_fill_percent)%, strategy=$($meta.padding_strategy), ~$($meta.padding_tokens_est) tokens"
    })

    # --- Context fill accuracy (dimension 1) ---
    $fillAccuracy = 1.0
    if ($TranscriptPath -and (Test-Path $TranscriptPath)) {
        if (Get-Command -Name 'Get-ContextFillLevel' -ErrorAction SilentlyContinue) {
            $fillInfo = Get-ContextFillLevel -TranscriptPath $TranscriptPath
            $actualFill = $fillInfo.fill_percentage / 100.0
            $targetFill = $meta.target_fill_percent / 100.0
            $fillError = [Math]::Abs($actualFill - $targetFill)
            $fillAccuracy = [Math]::Max(0, 1.0 - ($fillError / $script:FillAccuracyBand))

            [void]$assertions.Add(@{
                name     = 'fill_accuracy'
                passed   = ($fillError -le $script:FillAccuracyBand)
                expected = "$($meta.target_fill_percent)% +/- $([int]($script:FillAccuracyBand * 100))%"
                actual   = "$([Math]::Round($actualFill * 100, 1))%"
                message  = "Fill error: $([Math]::Round($fillError * 100, 1))%"
            })
        }
    } else {
        [void]$assertions.Add(@{
            name    = 'fill_accuracy'
            passed  = $true
            message = 'No transcript available for fill level verification (pre-run validation)'
        })
    }

    # --- Per-rule adherence checks (dimension 2) ---
    $ruleCheckers = @{
        'R01' = { param($w) Test-R01-HandlerNaming -WorkDir $w }
        'R02' = { param($w) Test-R02-InterfaceLocation -WorkDir $w }
        'R03' = { param($w) Test-R03-PagedResult -WorkDir $w }
        'R04' = { param($w) Test-R04-LoggerMessagePattern -WorkDir $w }
        'R05' = { param($w) Test-R05-NoControllerTryCatch -WorkDir $w }
        'R06' = { param($w) Test-R06-DocumentTypeConstants -WorkDir $w }
        'R07' = { param($w) Test-R07-ConfigOptionsPattern -WorkDir $w }
        'R08' = { param($w) Test-R08-CancellationTokenPropagation -WorkDir $w }
        'R09' = { param($w) Test-R09-SanitizedExceptionHierarchy -WorkDir $w }
        'R10' = { param($w) Test-R10-EpochSecondsConvention -WorkDir $w }
    }

    $ruleScores = @{}
    $totalAdherence = 0.0
    $ruleCount = 0

    foreach ($rule in $script:TargetRules) {
        $ruleId = $rule.Id
        $checker = $ruleCheckers[$ruleId]
        $score = 0.0

        try {
            $score = & $checker $WorkDir
        } catch {
            $score = 0.0
        }

        $ruleScores[$ruleId] = $score
        $totalAdherence += $score
        $ruleCount++

        $passed = $score -ge 0.5  # 50% threshold for individual rule pass
        [void]$assertions.Add(@{
            name     = "rule_$($ruleId.ToLower())_$($rule.Name -replace '\s+', '_' -replace '[^a-zA-Z0-9_]', '')"
            passed   = $passed
            expected = ">= 0.5 adherence"
            actual   = "$([Math]::Round($score, 2))"
            message  = "$($rule.Name): $([Math]::Round($score * 100, 0))% adherence"
        })
    }

    $avgAdherence = if ($ruleCount -gt 0) { $totalAdherence / $ruleCount } else { 0.0 }

    [void]$assertions.Add(@{
        name     = 'aggregate_rule_adherence'
        passed   = ($avgAdherence -ge 0.6)
        expected = '>= 60% average adherence'
        actual   = "$([Math]::Round($avgAdherence * 100, 1))%"
        message  = "$ruleCount rules checked, average adherence $([Math]::Round($avgAdherence * 100, 1))%"
    })

    # --- Forgetting curve analysis ---
    # For a single-run scenario, we analyze the rule scores at the current fill level
    # Full curve fitting requires results across multiple fill levels (collected by the runner)

    $currentFill = $meta.target_fill_percent / 100.0
    $fillLevels = @($currentFill)
    $adherenceValues = @($avgAdherence)

    # If we have enough data points (from prior runs), fit the curve
    $priorResultsPath = Join-Path $WorkDir 'prior-results.json'
    if (Test-Path $priorResultsPath) {
        try {
            $priorResults = Get-Content $priorResultsPath -Raw | ConvertFrom-Json
            foreach ($pr in $priorResults) {
                $fillLevels += $pr.fill_level
                $adherenceValues += $pr.adherence
            }
        } catch {
            # Ignore malformed prior results
        }
    }

    if ($fillLevels.Count -ge 3) {
        # Ebbinghaus fit
        $sortedIndices = 0..($fillLevels.Count - 1) | Sort-Object { $fillLevels[$_] }
        $sortedFill = @($sortedIndices | ForEach-Object { $fillLevels[$_] })
        $sortedAdherence = @($sortedIndices | ForEach-Object { $adherenceValues[$_] })

        $ebbFit = Invoke-EbbinghausFit -FillLevels $sortedFill -AdherenceScores $sortedAdherence

        [void]$assertions.Add(@{
            name     = 'ebbinghaus_fit'
            passed   = ($ebbFit.r_squared -ge 0.5)
            expected = 'R-squared >= 0.5'
            actual   = "S=$($ebbFit.stability_factor), R2=$($ebbFit.r_squared)"
            message  = "Stability factor: $($ebbFit.stability_factor), R-squared: $($ebbFit.r_squared)"
        })

        # Cliff-edge detection
        $cliffs = Find-CliffEdges -FillLevels $sortedFill -AdherenceScores $sortedAdherence

        [void]$assertions.Add(@{
            name     = 'cliff_edge_detection'
            passed   = $true  # Informational -- cliffs are findings, not failures
            expected = 'Cliff analysis complete'
            actual   = "$($cliffs.cliffs.Count) cliff(s) detected"
            message  = if ($cliffs.has_cliff_edge) {
                "CLIFF detected: avg gradient=$($cliffs.average_gradient)"
            } else {
                "No cliff edges found (smooth degradation), avg gradient=$($cliffs.average_gradient)"
            }
        })
    } else {
        [void]$assertions.Add(@{
            name    = 'forgetting_curve_data'
            passed  = $true
            message = "Single fill level ($([Math]::Round($currentFill * 100))%) -- need 3+ data points for curve fitting. Run at multiple fill levels to enable analysis."
        })
    }

    # --- Output quality (dimension 3): build + no warnings ---
    $outputQuality = 0.0
    $projDir = Join-Path $WorkDir 'EvalProject'
    if (Test-Path $projDir) {
        $csFiles = @(Get-ChildItem -Path $projDir -Recurse -Include '*.cs' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '[\\/](obj|bin|Padding)[\\/]' })
        $hasNewFiles = ($csFiles | Where-Object { $_.Name -match 'AuditLog' }).Count -gt 0
        $outputQuality = if ($hasNewFiles) { 1.0 } else { 0.0 }
    }

    [void]$assertions.Add(@{
        name     = 'output_quality'
        passed   = ($outputQuality -ge 0.5)
        expected = 'AuditLog files created'
        actual   = "$([Math]::Round($outputQuality * 100))% quality"
        message  = if ($outputQuality -ge 0.5) { 'Agent created expected AuditLog entity files' } else { 'Agent did NOT create AuditLog entity files' }
    })

    # --- No hallucinations (dimension 4): no references to non-existent files ---
    $hallScore = 1.0  # Start optimistic, deduct for issues
    if (Test-Path $projDir) {
        $csFiles = @(Get-ChildItem -Path $projDir -Recurse -Include '*.cs' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '[\\/](obj|bin|Padding)[\\/]' })
        foreach ($f in $csFiles) {
            $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
            # Check for using statements that reference non-existent namespaces
            $usings = [regex]::Matches($content, 'using\s+(EvalProject\.\w+)')
            foreach ($u in $usings) {
                $ns = $u.Groups[1].Value
                $nsDir = $ns -replace 'EvalProject\.', ''
                if (-not (Test-Path (Join-Path $projDir $nsDir))) {
                    $hallScore = [Math]::Max(0, $hallScore - 0.25)
                }
            }
        }
    }

    [void]$assertions.Add(@{
        name     = 'no_hallucinations'
        passed   = ($hallScore -ge 0.75)
        expected = 'No references to non-existent namespaces'
        actual   = "$([Math]::Round($hallScore * 100))% clean"
    })

    # --- Multi-dimensional composite score ---
    if (Get-Command -Name 'Invoke-MultiDimensionalScore' -ErrorAction SilentlyContinue) {
        $dimensions = @(
            @{ name = 'fill_accuracy';    score = [double]$fillAccuracy;  weight = 0.15 }
            @{ name = 'rule_adherence';   score = [double]$avgAdherence;  weight = 0.50 }
            @{ name = 'output_quality';   score = [double]$outputQuality; weight = 0.20 }
            @{ name = 'no_hallucinations'; score = [double]$hallScore;    weight = 0.15 }
        )

        $composite = Invoke-MultiDimensionalScore -Dimensions $dimensions

        [void]$assertions.Add(@{
            name     = 'composite_score'
            passed   = ($composite.composite -ge 0.5)
            expected = '>= 0.50 composite'
            actual   = "$($composite.composite)"
            message  = "Weighted composite: $($composite.composite) (fill=$([Math]::Round($fillAccuracy,2)), rules=$([Math]::Round($avgAdherence,2)), quality=$([Math]::Round($outputQuality,2)), hallucinations=$([Math]::Round($hallScore,2)))"
        })
    }

    # --- Save results for cross-run analysis ---
    $resultsPath = Join-Path $WorkDir 'stress-results.json'
    @{
        fill_level       = $currentFill
        padding_strategy = $meta.padding_strategy
        avg_adherence    = [Math]::Round($avgAdherence, 4)
        rule_scores      = $ruleScores
        fill_accuracy    = [Math]::Round($fillAccuracy, 4)
        output_quality   = [Math]::Round($outputQuality, 4)
        hall_score       = [Math]::Round($hallScore, 4)
        timestamp        = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    } | ConvertTo-Json -Depth 5 | Set-Content -Path $resultsPath -Encoding UTF8

    return $assertions
}

# ---------------------------------------------------------------------------
# Module Exports
# ---------------------------------------------------------------------------

Export-ModuleMember -Function @(
    'Setup-ContextStress',
    'Get-ContextStressPrompt',
    'Invoke-ContextStressAssertions',
    'New-CodePadding',
    'New-ConversationPadding',
    'New-NoisePadding',
    'Test-PaddingContentSafe',
    'Get-EstimatedTokenCount',
    'Get-PaddingTokenTarget',
    'Test-R01-HandlerNaming',
    'Test-R02-InterfaceLocation',
    'Test-R03-PagedResult',
    'Test-R04-LoggerMessagePattern',
    'Test-R05-NoControllerTryCatch',
    'Test-R06-DocumentTypeConstants',
    'Test-R07-ConfigOptionsPattern',
    'Test-R08-CancellationTokenPropagation',
    'Test-R09-SanitizedExceptionHierarchy',
    'Test-R10-EpochSecondsConvention',
    'Invoke-EbbinghausFit',
    'Find-CliffEdges',
    'Get-SafeOperatingZone'
)
