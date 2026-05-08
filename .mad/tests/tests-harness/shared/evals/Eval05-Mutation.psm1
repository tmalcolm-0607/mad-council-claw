# Eval05-Mutation.psm1 - Mutation-Guided Defect Detection module
#
# Injects known mutations (defects) into a consumer-project-style .NET scaffold and tests
# whether agents can detect and fix them. Measures defect detection rate, diagnosis
# accuracy, fix quality, and regression avoidance across 42 domain-specific mutations.
#
# Exports: Setup-Mutation, Get-MutationPrompt, Invoke-MutationAssertions
# Helpers: Get-MutationCatalog, New-MutationTarget, Invoke-MutationInjection,
#          Invoke-MutationScore, Compare-BaselineTreatment

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Mutation Catalog: 42 operators across 5 categories
# ---------------------------------------------------------------------------

function Get-MutationCatalog {
    <#
    .SYNOPSIS
        Returns the full catalog of 42 domain-specific mutation operators.
    .DESCRIPTION
        Each mutation is a hashtable with: id, category, name, description,
        targetFile (relative path in scaffold), before (original code pattern),
        after (mutated code), detectionKeywords (for keyword-based diagnosis scoring),
        fixVerification (regex to check if agent reverted the mutation).
    #>

    return @(
        # ===================================================================
        # Category 1: Cosmos DB Mutations (M01-M10)
        # ===================================================================
        @{
            id                = 'M01'
            category          = 'CosmosDB'
            name              = 'Wrong partition key'
            description       = 'GetPartitionKey returns Id instead of CaseNumber'
            targetFile        = 'Common/Models/CaseEntity.cs'
            before            = 'public override string GetPartitionKey() => CaseNumber;'
            after             = 'public override string GetPartitionKey() => Id;'
            detectionKeywords = @('partition key', 'GetPartitionKey', 'CaseNumber', 'wrong key', 'partition')
            fixVerification   = 'GetPartitionKey\(\)\s*=>\s*CaseNumber'
        }
        @{
            id                = 'M02'
            category          = 'CosmosDB'
            name              = 'Missing cross-partition guard'
            description       = 'Query executes without partition key constraint'
            targetFile        = 'DataAccess/Repositories/CaseRepository.cs'
            before            = 'var options = new QueryRequestOptions { MaxItemCount = pageSize, PartitionKey = new PartitionKey(caseNumber) };'
            after             = 'var options = new QueryRequestOptions { MaxItemCount = pageSize };'
            detectionKeywords = @('cross-partition', 'partition key', 'PartitionKey', 'query options', 'fan-out')
            fixVerification   = 'PartitionKey\s*=\s*new\s+PartitionKey'
        }
        @{
            id                = 'M03'
            category          = 'CosmosDB'
            name              = 'Wrong consistency level'
            description       = 'Uses Eventual consistency instead of Session'
            targetFile        = 'DataAccess/Repositories/CaseRepository.cs'
            before            = 'using var iterator = _container.GetItemQueryIterator<CaseEntity>(query, continuationToken, options);'
            after             = @'
var requestOpts = new QueryRequestOptions { MaxItemCount = pageSize, ConsistencyLevel = Microsoft.Azure.Cosmos.ConsistencyLevel.Eventual };
        using var iterator = _container.GetItemQueryIterator<CaseEntity>(query, continuationToken, requestOpts);
'@
            detectionKeywords = @('consistency', 'eventual', 'session', 'ConsistencyLevel', 'stale read')
            fixVerification   = '(?!.*ConsistencyLevel\s*=\s*.*Eventual)'
        }
        @{
            id                = 'M04'
            category          = 'CosmosDB'
            name              = 'Missing soft-delete filter'
            description       = 'Query returns deleted items because isDeleted filter is removed'
            targetFile        = 'DataAccess/Repositories/CaseRepository.cs'
            before            = 'var query = new QueryDefinition("SELECT * FROM c WHERE c.partitionKey = @pk AND c.type = @type AND c.isDeleted = false")'
            after             = 'var query = new QueryDefinition("SELECT * FROM c WHERE c.partitionKey = @pk AND c.type = @type")'
            detectionKeywords = @('soft delete', 'isDeleted', 'deleted', 'filter', 'soft-delete')
            fixVerification   = 'isDeleted\s*=\s*false'
        }
        @{
            id                = 'M05'
            category          = 'CosmosDB'
            name              = 'Magic string document type'
            description       = 'Uses magic string "case" instead of DocumentTypes.Case constant'
            targetFile        = 'DataAccess/Repositories/CaseRepository.cs'
            before            = 'entity.Type = DocumentTypes.Case;'
            after             = 'entity.Type = "case";'
            detectionKeywords = @('magic string', 'DocumentTypes', 'constant', 'hardcoded', 'document type')
            fixVerification   = 'DocumentTypes\.Case'
        }
        @{
            id                = 'M06'
            category          = 'CosmosDB'
            name              = 'Missing ETag check on update'
            description       = 'ReplaceItemAsync called without ETag/If-Match header'
            targetFile        = 'DataAccess/Repositories/CaseRepository.cs'
            before            = 'var response = await _container.ReplaceItemAsync(entity, entity.Id, new PartitionKey(entity.PartitionKey), cancellationToken: cancellationToken);'
            after             = 'var response = await _container.ReplaceItemAsync(entity, entity.Id, new PartitionKey(entity.PartitionKey), new ItemRequestOptions(), cancellationToken);'
            detectionKeywords = @('ETag', 'If-Match', 'concurrency', 'optimistic', 'IfMatchEtag', 'race condition')
            fixVerification   = '(IfMatchEtag|IfNoneMatchEtag|etag|ETag)'
        }
        @{
            id                = 'M07'
            category          = 'CosmosDB'
            name              = 'Unbounded query - no MaxItemCount'
            description       = 'Query has no page size limit, potentially returning all items'
            targetFile        = 'DataAccess/Repositories/CaseRepository.cs'
            before            = 'var options = new QueryRequestOptions { MaxItemCount = pageSize, PartitionKey = new PartitionKey(caseNumber) };'
            after             = 'var options = new QueryRequestOptions { PartitionKey = new PartitionKey(caseNumber) };'
            detectionKeywords = @('unbounded', 'MaxItemCount', 'page size', 'pagination', 'limit', 'all items')
            fixVerification   = 'MaxItemCount\s*='
        }
        @{
            id                = 'M08'
            category          = 'CosmosDB'
            name              = 'Wrong container name casing'
            description       = 'Container ID uses wrong casing ("Cms" instead of "cms")'
            targetFile        = 'Common/Configuration/CosmosOptions.cs'
            before            = 'public string ContainerId { get; set; } = "cms";'
            after             = 'public string ContainerId { get; set; } = "Cms";'
            detectionKeywords = @('container', 'ContainerId', 'casing', 'case-sensitive', 'Cms', 'cms')
            fixVerification   = 'ContainerId.*=\s*"cms"'
        }
        @{
            id                = 'M09'
            category          = 'CosmosDB'
            name              = 'Missing retry on transient failure'
            description       = 'CreateItemAsync has no retry logic for 429/503 responses'
            targetFile        = 'DataAccess/Repositories/CaseRepository.cs'
            before            = 'var response = await _container.CreateItemAsync(entity, new PartitionKey(entity.PartitionKey), cancellationToken: cancellationToken);'
            after             = @'
try
        {
            var response = await _container.CreateItemAsync(entity, new PartitionKey(entity.PartitionKey), cancellationToken: cancellationToken);
            return response.Resource;
        }
        catch (CosmosException) { throw; }
'@
            detectionKeywords = @('retry', 'transient', '429', 'throttle', 'resilience', 'Polly', 'retry policy')
            fixVerification   = '(retry|Retry|Polly|RetryAsync|WithRetry)'
        }
        @{
            id                = 'M10'
            category          = 'CosmosDB'
            name              = 'Stale read after write'
            description       = 'GetByIdAsync called without session consistency after CreateAsync'
            targetFile        = 'BusinessLogic/Handlers/CaseHandler.cs'
            before            = @'
var result = await _repository.CreateAsync(entity, cancellationToken);
        LogMessages.CaseCreated(_logger, result.Id);
        return result;
'@
            after             = @'
await _repository.CreateAsync(entity, cancellationToken);
        LogMessages.CaseCreated(_logger, entity.Id);
        // Read back from store
        var readBack = await _repository.GetByIdAsync(entity.Id, entity.GetPartitionKey(), cancellationToken);
        return readBack!;
'@
            detectionKeywords = @('stale read', 'read after write', 'consistency', 'redundant read', 'unnecessary query')
            fixVerification   = 'var result = await _repository\.CreateAsync.*\s*.*return result;'
        }

        # ===================================================================
        # Category 2: Architecture Mutations (M11-M20)
        # ===================================================================
        @{
            id                = 'M11'
            category          = 'Architecture'
            name              = 'Controller bypasses handler'
            description       = 'Controller calls repository directly instead of through handler'
            targetFile        = 'API/Controllers/CasesController.cs'
            before            = @'
private readonly ICaseHandler _handler;

    public CasesController(ICaseHandler handler)
    {
        _handler = handler;
    }

    [HttpPost]
    public async Task<ActionResult<CaseEntity>> Create([FromBody] CaseEntity entity, CancellationToken cancellationToken)
    {
        var result = await _handler.CreateCaseAsync(entity, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = result.Id, partitionKey = result.PartitionKey }, result);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<CaseEntity>> GetById(string id, [FromQuery] string partitionKey, CancellationToken cancellationToken)
    {
        var result = await _handler.GetCaseByIdAsync(id, partitionKey, cancellationToken);
        return result is null ? NotFound() : Ok(result);
    }

    [HttpGet("by-case/{caseNumber}")]
    public async Task<ActionResult> GetByCaseNumber(string caseNumber, [FromQuery] int pageSize = 25, [FromQuery] string? continuationToken = null, CancellationToken cancellationToken = default)
    {
        var result = await _handler.GetCasesByCaseNumberAsync(caseNumber, pageSize, continuationToken, cancellationToken);
        return Ok(result);
    }

    [HttpDelete("{id}")]
    public async Task<ActionResult> Delete(string id, [FromQuery] string partitionKey, CancellationToken cancellationToken)
    {
        await _handler.SoftDeleteCaseAsync(id, partitionKey, cancellationToken);
        return NoContent();
    }
'@
            after             = @'
private readonly ICaseRepository _repository;

    public CasesController(ICaseRepository repository)
    {
        _repository = repository;
    }

    [HttpPost]
    public async Task<ActionResult<CaseEntity>> Create([FromBody] CaseEntity entity, CancellationToken cancellationToken)
    {
        var result = await _repository.CreateAsync(entity, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = result.Id, partitionKey = result.PartitionKey }, result);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<CaseEntity>> GetById(string id, [FromQuery] string partitionKey, CancellationToken cancellationToken)
    {
        var result = await _repository.GetByIdAsync(id, partitionKey, cancellationToken);
        return result is null ? NotFound() : Ok(result);
    }

    [HttpGet("by-case/{caseNumber}")]
    public async Task<ActionResult> GetByCaseNumber(string caseNumber, [FromQuery] int pageSize = 25, [FromQuery] string? continuationToken = null, CancellationToken cancellationToken = default)
    {
        var result = await _repository.GetByCaseNumberAsync(caseNumber, pageSize, continuationToken, cancellationToken);
        return Ok(result);
    }

    [HttpDelete("{id}")]
    public async Task<ActionResult> Delete(string id, [FromQuery] string partitionKey, CancellationToken cancellationToken)
    {
        await _repository.SoftDeleteAsync(id, partitionKey, cancellationToken);
        return NoContent();
    }
'@
            detectionKeywords = @('bypass', 'handler', 'layer violation', 'repository', 'direct access', 'architecture')
            fixVerification   = 'ICaseHandler\s+_handler'
        }
        @{
            id                = 'M12'
            category          = 'Architecture'
            name              = 'Interface in wrong layer'
            description       = 'ICaseRepository defined in DataAccess instead of Common'
            targetFile        = 'DataAccess/Repositories/CaseRepository.cs'
            before            = 'using Common.Interfaces;'
            after             = '// Interface defined locally in DataAccess'
            detectionKeywords = @('wrong layer', 'interface', 'Common', 'DataAccess', 'dependency inversion', 'abstraction')
            fixVerification   = 'using Common\.Interfaces;'
        }
        @{
            id                = 'M13'
            category          = 'Architecture'
            name              = 'Missing DI registration'
            description       = 'CaseHandler not registered in dependency injection container'
            targetFile        = 'DependencyInjection/ServiceCollectionExtensions.cs'
            before            = 'services.AddScoped<ICaseHandler, CaseHandler>();'
            after             = '// TODO: Register CaseHandler'
            detectionKeywords = @('DI', 'dependency injection', 'registration', 'AddScoped', 'missing registration', 'container')
            fixVerification   = 'AddScoped<ICaseHandler,\s*CaseHandler>'
        }
        @{
            id                = 'M14'
            category          = 'Architecture'
            name              = 'Circular dependency'
            description       = 'CaseHandler depends on ICaseHandler (itself) creating circular reference'
            targetFile        = 'BusinessLogic/Handlers/CaseHandler.cs'
            before            = @'
private readonly ICaseRepository _repository;
    private readonly ILogger<CaseHandler> _logger;

    public CaseHandler(ICaseRepository repository, ILogger<CaseHandler> logger)
    {
        _repository = repository;
        _logger = logger;
    }
'@
            after             = @'
private readonly ICaseRepository _repository;
    private readonly ILogger<CaseHandler> _logger;
    private readonly ICaseHandler _self;

    public CaseHandler(ICaseRepository repository, ILogger<CaseHandler> logger, ICaseHandler self)
    {
        _repository = repository;
        _logger = logger;
        _self = self;
    }
'@
            detectionKeywords = @('circular', 'dependency', 'self-reference', 'loop', 'ICaseHandler', 'recursive')
            fixVerification   = '(?!.*ICaseHandler\s+_self)'
        }
        @{
            id                = 'M15'
            category          = 'Architecture'
            name              = 'Wrong return type - List instead of PagedResult'
            description       = 'Handler returns List<T> instead of PagedResult<T>, losing pagination metadata'
            targetFile        = 'BusinessLogic/Interfaces/ICaseHandler.cs'
            before            = 'Task<PagedResult<CaseEntity>> GetCasesByCaseNumberAsync(string caseNumber, int pageSize = 25, string? continuationToken = null, CancellationToken cancellationToken = default);'
            after             = 'Task<List<CaseEntity>> GetCasesByCaseNumberAsync(string caseNumber, int pageSize = 25, string? continuationToken = null, CancellationToken cancellationToken = default);'
            detectionKeywords = @('PagedResult', 'pagination', 'List', 'return type', 'continuation token', 'paging')
            fixVerification   = 'Task<PagedResult<CaseEntity>>\s+GetCasesByCaseNumber'
        }
        @{
            id                = 'M16'
            category          = 'Architecture'
            name              = 'Service instead of Handler naming'
            description       = 'Uses CaseService instead of CaseHandler naming convention'
            targetFile        = 'BusinessLogic/Handlers/CaseHandler.cs'
            before            = 'public class CaseHandler : ICaseHandler'
            after             = 'public class CaseService : ICaseHandler'
            detectionKeywords = @('naming', 'Handler', 'Service', 'convention', 'CaseService', 'CaseHandler')
            fixVerification   = 'class CaseHandler\s*:'
        }
        @{
            id                = 'M17'
            category          = 'Architecture'
            name              = 'Missing mapper - entity exposed as DTO'
            description       = 'Controller returns raw CaseEntity instead of a mapped DTO'
            targetFile        = 'API/Controllers/CasesController.cs'
            before            = 'public async Task<ActionResult<CaseEntity>> Create([FromBody] CaseEntity entity, CancellationToken cancellationToken)'
            after             = '// NOTE: Returning raw entity as response (no DTO mapping)'
            detectionKeywords = @('mapper', 'DTO', 'entity', 'mapping', 'response model', 'data transfer')
            fixVerification   = 'ActionResult<CaseEntity>\s+Create'
        }
        @{
            id                = 'M18'
            category          = 'Architecture'
            name              = 'Business logic in controller'
            description       = 'Validation logic placed in controller instead of handler'
            targetFile        = 'API/Controllers/CasesController.cs'
            before            = @'
[HttpPost]
    public async Task<ActionResult<CaseEntity>> Create([FromBody] CaseEntity entity, CancellationToken cancellationToken)
    {
        var result = await _handler.CreateCaseAsync(entity, cancellationToken);
'@
            after             = @'
[HttpPost]
    public async Task<ActionResult<CaseEntity>> Create([FromBody] CaseEntity entity, CancellationToken cancellationToken)
    {
        if (string.IsNullOrEmpty(entity.CaseNumber)) return BadRequest("CaseNumber is required");
        if (string.IsNullOrEmpty(entity.Title)) return BadRequest("Title is required");
        var result = await _handler.CreateCaseAsync(entity, cancellationToken);
'@
            detectionKeywords = @('validation', 'controller', 'business logic', 'handler', 'layer violation', 'BadRequest')
            fixVerification   = '(?!.*if\s*\(string\.IsNullOrEmpty\(entity\.CaseNumber\)\)\s*return\s+BadRequest)'
        }
        @{
            id                = 'M19'
            category          = 'Architecture'
            name              = 'Repository returns domain entity from handler'
            description       = 'Handler exposes internal repository types in its interface'
            targetFile        = 'Common/Interfaces/ICaseRepository.cs'
            before            = 'Task<CaseEntity> CreateAsync(CaseEntity entity, CancellationToken cancellationToken = default);'
            after             = 'Task<object> CreateAsync(CaseEntity entity, CancellationToken cancellationToken = default);'
            detectionKeywords = @('return type', 'object', 'CaseEntity', 'type safety', 'repository', 'interface')
            fixVerification   = 'Task<CaseEntity>\s+CreateAsync'
        }
        @{
            id                = 'M20'
            category          = 'Architecture'
            name              = 'Concrete Cosmos type in handler'
            description       = 'Handler references Microsoft.Azure.Cosmos directly instead of abstraction'
            targetFile        = 'BusinessLogic/Handlers/CaseHandler.cs'
            before            = 'using Common.Interfaces;'
            after             = @'
using Common.Interfaces;
using Microsoft.Azure.Cosmos;
'@
            detectionKeywords = @('concrete', 'Cosmos', 'abstraction', 'coupling', 'Microsoft.Azure.Cosmos', 'dependency')
            fixVerification   = '(?!.*using Microsoft\.Azure\.Cosmos;.*namespace BusinessLogic)'
        }

        # ===================================================================
        # Category 3: Security Mutations (M21-M28)
        # ===================================================================
        @{
            id                = 'M21'
            category          = 'Security'
            name              = 'Missing Authorize attribute'
            description       = 'Controller missing [Authorize] attribute, endpoints are unprotected'
            targetFile        = 'API/Controllers/CasesController.cs'
            before            = @'
[ApiController]
[Route("api/[controller]")]
public class CasesController : ControllerBase
'@
            after             = @'
[ApiController]
[Route("api/[controller]")]
[AllowAnonymous]
public class CasesController : ControllerBase
'@
            detectionKeywords = @('authorize', 'authentication', 'AllowAnonymous', 'security', 'unprotected', 'auth')
            fixVerification   = '(Authorize|(?!.*AllowAnonymous))'
        }
        @{
            id                = 'M22'
            category          = 'Security'
            name              = 'PII in log messages'
            description       = 'Logger exposes PII data (email address) in structured log'
            targetFile        = 'BusinessLogic/LogMessages.cs'
            before            = @'
[LoggerMessage(Level = LogLevel.Information, Message = "Creating case {CaseNumber}")]
    public static partial void CreatingCase(ILogger logger, string caseNumber);
'@
            after             = @'
[LoggerMessage(Level = LogLevel.Information, Message = "Creating case {CaseNumber} for user {UserEmail}")]
    public static partial void CreatingCase(ILogger logger, string caseNumber, string userEmail);
'@
            detectionKeywords = @('PII', 'email', 'personal', 'sensitive', 'log', 'privacy', 'GDPR')
            fixVerification   = '(?!.*UserEmail.*Message)'
        }
        @{
            id                = 'M23'
            category          = 'Security'
            name              = 'Missing input validation'
            description       = 'No validation on CaseEntity before persisting to database'
            targetFile        = 'BusinessLogic/Handlers/CaseHandler.cs'
            before            = @'
public async Task<CaseEntity> CreateCaseAsync(CaseEntity entity, CancellationToken cancellationToken = default)
    {
        LogMessages.CreatingCase(_logger, entity.CaseNumber);
'@
            after             = @'
public async Task<CaseEntity> CreateCaseAsync(CaseEntity entity, CancellationToken cancellationToken = default)
    {
        // No validation - accepting any input
'@
            detectionKeywords = @('validation', 'input', 'sanitize', 'check', 'null check', 'guard clause')
            fixVerification   = '(ArgumentNullException|Argument.*Exception|throw|Validate|Guard|validation)'
        }
        @{
            id                = 'M24'
            category          = 'Security'
            name              = 'String interpolation in query (injection)'
            description       = 'Query uses string interpolation instead of parameterized query'
            targetFile        = 'DataAccess/Repositories/CaseRepository.cs'
            before            = @'
var query = new QueryDefinition("SELECT * FROM c WHERE c.partitionKey = @pk AND c.type = @type AND c.isDeleted = false")
            .WithParameter("@pk", caseNumber)
            .WithParameter("@type", DocumentTypes.Case);
'@
            after             = @'
var query = new QueryDefinition($"SELECT * FROM c WHERE c.partitionKey = '{caseNumber}' AND c.type = '{DocumentTypes.Case}' AND c.isDeleted = false");
'@
            detectionKeywords = @('injection', 'interpolation', 'parameterized', 'SQL injection', 'NoSQL injection', 'string concatenation')
            fixVerification   = 'WithParameter\("@pk"'
        }
        @{
            id                = 'M25'
            category          = 'Security'
            name              = 'Overly permissive CORS'
            description       = 'CORS allows any origin instead of specific whitelist'
            targetFile        = 'API/Program.cs'
            before            = 'builder.Services.AddControllers();'
            after             = @'
builder.Services.AddCors(o => o.AddDefaultPolicy(p => p.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader()));
builder.Services.AddControllers();
'@
            detectionKeywords = @('CORS', 'AllowAnyOrigin', 'origin', 'cross-origin', 'security', 'whitelist')
            fixVerification   = '(?!.*AllowAnyOrigin)'
        }
        @{
            id                = 'M26'
            category          = 'Security'
            name              = 'Exposed connection string (sentinel)'
            description       = 'Connection string with sentinel values in appsettings instead of Managed Identity'
            targetFile        = 'API/appsettings.json'
            before            = '"AccountEndpoint": "https://localhost:8081",'
            after             = '"AccountEndpoint": "INVALID_ENDPOINT", "AccountKey": "INVALID_KEY",'
            detectionKeywords = @('connection string', 'AccountKey', 'credential', 'Managed Identity', 'secret', 'key')
            fixVerification   = '(?!.*AccountKey)'
        }
        @{
            id                = 'M27'
            category          = 'Security'
            name              = 'Missing rate limiting'
            description       = 'No rate limiting or throttling on public endpoints'
            targetFile        = 'API/Program.cs'
            before            = 'app.MapControllers();'
            after             = @'
// No rate limiting configured
app.MapControllers();
'@
            detectionKeywords = @('rate limit', 'throttle', 'DoS', 'abuse', 'rate-limit', 'limiting')
            fixVerification   = '(RateLimiter|UseRateLimiting|AddRateLimiter|Throttle)'
        }
        @{
            id                = 'M28'
            category          = 'Security'
            name              = 'Overprivileged Cosmos identity'
            description       = 'Cosmos client uses read-write when only read is needed for queries'
            targetFile        = 'DependencyInjection/ServiceCollectionExtensions.cs'
            before            = 'var client = new CosmosClient(options.AccountEndpoint, new DefaultAzureCredential());'
            after             = 'var client = new CosmosClient(options.AccountEndpoint, new DefaultAzureCredential(new DefaultAzureCredentialOptions { ManagedIdentityClientId = "ADMIN_IDENTITY" }));'
            detectionKeywords = @('privilege', 'least privilege', 'identity', 'ADMIN', 'overprivileged', 'RBAC', 'role')
            fixVerification   = '(?!.*ADMIN_IDENTITY)'
        }

        # ===================================================================
        # Category 4: Performance Mutations (M29-M36)
        # ===================================================================
        @{
            id                = 'M29'
            category          = 'Performance'
            name              = 'N+1 query pattern'
            description       = 'Individual reads in a loop instead of batch query'
            targetFile        = 'BusinessLogic/Handlers/CaseHandler.cs'
            before            = @'
public async Task<PagedResult<CaseEntity>> GetCasesByCaseNumberAsync(string caseNumber, int pageSize = 25, string? continuationToken = null, CancellationToken cancellationToken = default)
    {
        return await _repository.GetByCaseNumberAsync(caseNumber, pageSize, continuationToken, cancellationToken);
    }
'@
            after             = @'
public async Task<PagedResult<CaseEntity>> GetCasesByCaseNumberAsync(string caseNumber, int pageSize = 25, string? continuationToken = null, CancellationToken cancellationToken = default)
    {
        // Get IDs first, then load each one individually
        var page = await _repository.GetByCaseNumberAsync(caseNumber, pageSize, continuationToken, cancellationToken);
        var results = new List<CaseEntity>();
        foreach (var item in page.Items)
        {
            var full = await _repository.GetByIdAsync(item.Id, item.PartitionKey, cancellationToken);
            if (full != null) results.Add(full);
        }
        return new PagedResult<CaseEntity> { Items = results, ContinuationToken = page.ContinuationToken };
    }
'@
            detectionKeywords = @('N+1', 'loop', 'individual read', 'batch', 'performance', 'query per item')
            fixVerification   = 'return await _repository\.GetByCaseNumberAsync'
        }
        @{
            id                = 'M30'
            category          = 'Performance'
            name              = 'Missing pagination - returns all results'
            description       = 'Query iterates all pages instead of returning single page'
            targetFile        = 'DataAccess/Repositories/CaseRepository.cs'
            before            = @'
if (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync(cancellationToken);
            items.AddRange(response);
            nextToken = response.ContinuationToken;
        }
'@
            after             = @'
while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync(cancellationToken);
            items.AddRange(response);
        }
'@
            detectionKeywords = @('pagination', 'all results', 'while loop', 'unbounded', 'memory', 'HasMoreResults')
            fixVerification   = 'if\s*\(iterator\.HasMoreResults\)'
        }
        @{
            id                = 'M31'
            category          = 'Performance'
            name              = 'Sync-over-async (.Result)'
            description       = 'Blocking on async method with .Result causing potential deadlock'
            targetFile        = 'BusinessLogic/Handlers/CaseHandler.cs'
            before            = 'var result = await _repository.CreateAsync(entity, cancellationToken);'
            after             = 'var result = _repository.CreateAsync(entity, cancellationToken).Result;'
            detectionKeywords = @('sync over async', '.Result', 'deadlock', 'blocking', 'async', '.Wait()')
            fixVerification   = 'await _repository\.CreateAsync'
        }
        @{
            id                = 'M32'
            category          = 'Performance'
            name              = 'Missing CancellationToken propagation'
            description       = 'Async methods do not propagate CancellationToken'
            targetFile        = 'BusinessLogic/Handlers/CaseHandler.cs'
            before            = 'var result = await _repository.CreateAsync(entity, cancellationToken);'
            after             = 'var result = await _repository.CreateAsync(entity);'
            detectionKeywords = @('CancellationToken', 'cancellation', 'propagation', 'token', 'cancel')
            fixVerification   = '_repository\.CreateAsync\(entity,\s*cancellationToken\)'
        }
        @{
            id                = 'M33'
            category          = 'Performance'
            name              = 'Unbuffered stream reading'
            description       = 'Reading entire response into memory instead of streaming'
            targetFile        = 'DataAccess/Repositories/CaseRepository.cs'
            before            = @'
var response = await iterator.ReadNextAsync(cancellationToken);
            items.AddRange(response);
            nextToken = response.ContinuationToken;
'@
            after             = @'
var response = await iterator.ReadNextAsync(cancellationToken);
            var json = System.Text.Json.JsonSerializer.Serialize(response.Resource);
            var deserialized = System.Text.Json.JsonSerializer.Deserialize<List<CaseEntity>>(json);
            items.AddRange(deserialized!);
            nextToken = response.ContinuationToken;
'@
            detectionKeywords = @('serialize', 'deserialize', 'memory', 'buffer', 'intermediate', 'roundtrip', 'unnecessary')
            fixVerification   = 'items\.AddRange\(response\)'
        }
        @{
            id                = 'M34'
            category          = 'Performance'
            name              = 'Missing index hint'
            description       = 'Query on non-indexed path without composite index consideration'
            targetFile        = 'DataAccess/Repositories/CaseRepository.cs'
            before            = 'var query = new QueryDefinition("SELECT * FROM c WHERE c.partitionKey = @pk AND c.type = @type AND c.isDeleted = false")'
            after             = 'var query = new QueryDefinition("SELECT * FROM c WHERE c.partitionKey = @pk AND c.type = @type AND c.isDeleted = false ORDER BY c.createdAt DESC")'
            detectionKeywords = @('index', 'ORDER BY', 'composite index', 'query cost', 'RU', 'performance')
            fixVerification   = '(?!.*ORDER BY c\.createdAt)'
        }
        @{
            id                = 'M35'
            category          = 'Performance'
            name              = 'Chatty API - multiple round trips'
            description       = 'Delete operation does separate read then update instead of batch'
            targetFile        = 'DataAccess/Repositories/CaseRepository.cs'
            before            = @'
public async Task SoftDeleteAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        var entity = await GetByIdAsync(id, partitionKey, cancellationToken);
        if (entity != null)
        {
            entity.IsDeleted = true;
            await UpdateAsync(entity, cancellationToken);
        }
    }
'@
            after             = @'
public async Task SoftDeleteAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        var entity = await GetByIdAsync(id, partitionKey, cancellationToken);
        if (entity != null)
        {
            // Verify it still exists
            var recheck = await GetByIdAsync(id, partitionKey, cancellationToken);
            if (recheck != null)
            {
                recheck.IsDeleted = true;
                await UpdateAsync(recheck, cancellationToken);
            }
        }
    }
'@
            detectionKeywords = @('chatty', 'round trip', 'redundant', 'double read', 'unnecessary', 'batch')
            fixVerification   = '(?!.*var recheck = await GetByIdAsync)'
        }
        @{
            id                = 'M36'
            category          = 'Performance'
            name              = 'Missing cache for repeated queries'
            description       = 'GetByIdAsync called repeatedly without caching'
            targetFile        = 'BusinessLogic/Handlers/CaseHandler.cs'
            before            = @'
public async Task<CaseEntity?> GetCaseByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        return await _repository.GetByIdAsync(id, partitionKey, cancellationToken);
    }
'@
            after             = @'
public async Task<CaseEntity?> GetCaseByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        // First read
        var first = await _repository.GetByIdAsync(id, partitionKey, cancellationToken);
        // Second read to verify (no caching)
        var second = await _repository.GetByIdAsync(id, partitionKey, cancellationToken);
        return second;
    }
'@
            detectionKeywords = @('cache', 'duplicate', 'repeated', 'redundant query', 'memoize', 'caching')
            fixVerification   = 'return await _repository\.GetByIdAsync\(id, partitionKey, cancellationToken\);'
        }

        # ===================================================================
        # Category 5: Convention Mutations (M37-M42)
        # ===================================================================
        @{
            id                = 'M37'
            category          = 'Convention'
            name              = 'String interpolation logging'
            description       = 'Uses string interpolation in logger instead of LoggerMessage source generator'
            targetFile        = 'BusinessLogic/Handlers/CaseHandler.cs'
            before            = 'LogMessages.CreatingCase(_logger, entity.CaseNumber);'
            after             = '_logger.LogInformation($"Creating case {entity.CaseNumber}");'
            detectionKeywords = @('LoggerMessage', 'source generator', 'interpolation', 'structured logging', 'high-performance')
            fixVerification   = 'LogMessages\.CreatingCase'
        }
        @{
            id                = 'M38'
            category          = 'Convention'
            name              = 'Controller try-catch instead of middleware'
            description       = 'Exception handling in controller instead of using exception middleware'
            targetFile        = 'API/Controllers/CasesController.cs'
            before            = @'
[HttpGet("{id}")]
    public async Task<ActionResult<CaseEntity>> GetById(string id, [FromQuery] string partitionKey, CancellationToken cancellationToken)
    {
        var result = await _handler.GetCaseByIdAsync(id, partitionKey, cancellationToken);
        return result is null ? NotFound() : Ok(result);
    }
'@
            after             = @'
[HttpGet("{id}")]
    public async Task<ActionResult<CaseEntity>> GetById(string id, [FromQuery] string partitionKey, CancellationToken cancellationToken)
    {
        try
        {
            var result = await _handler.GetCaseByIdAsync(id, partitionKey, cancellationToken);
            return result is null ? NotFound() : Ok(result);
        }
        catch (Exception ex)
        {
            return StatusCode(500, ex.Message);
        }
    }
'@
            detectionKeywords = @('try-catch', 'middleware', 'exception handling', 'controller', 'catch', 'StatusCode(500')
            fixVerification   = '(?!.*catch\s*\(Exception\s+ex\))'
        }
        @{
            id                = 'M39'
            category          = 'Convention'
            name              = 'Wrong namespace reference'
            description       = 'API layer directly references DataAccess namespace'
            targetFile        = 'API/Controllers/CasesController.cs'
            before            = 'using BusinessLogic.Interfaces;'
            after             = @'
using BusinessLogic.Interfaces;
using DataAccess.Repositories;
'@
            detectionKeywords = @('namespace', 'DataAccess', 'layer violation', 'using', 'reference', 'coupling')
            fixVerification   = '(?!.*using DataAccess\.Repositories;)'
        }
        @{
            id                = 'M40'
            category          = 'Convention'
            name              = 'Missing XML documentation'
            description       = 'Public API controller missing XML documentation comments'
            targetFile        = 'API/Controllers/CasesController.cs'
            before            = @'
[HttpPost]
    public async Task<ActionResult<CaseEntity>> Create([FromBody] CaseEntity entity, CancellationToken cancellationToken)
'@
            after             = @'
/// <summary>Creates a new case.</summary>
    [HttpPost]
    public async Task<ActionResult<CaseEntity>> Create([FromBody] CaseEntity entity, CancellationToken cancellationToken)
'@
            detectionKeywords = @('XML doc', 'documentation', 'summary', 'comment', '///')
            fixVerification   = '(?!.*<summary>Creates a new case)'
        }
        @{
            id                = 'M41'
            category          = 'Convention'
            name              = 'Wrong naming convention'
            description       = 'Repository uses abbreviated name CaseRepo instead of CaseRepository'
            targetFile        = 'DataAccess/Repositories/CaseRepository.cs'
            before            = 'public class CaseRepository : ICaseRepository'
            after             = 'public class CaseRepo : ICaseRepository'
            detectionKeywords = @('naming', 'abbreviation', 'convention', 'Repository', 'Repo', 'full name')
            fixVerification   = 'class CaseRepository\s*:'
        }
        @{
            id                = 'M42'
            category          = 'Convention'
            name              = 'Magic number instead of named constant'
            description       = 'Hardcoded page size 25 instead of named constant'
            targetFile        = 'Common/Interfaces/ICaseRepository.cs'
            before            = 'Task<PagedResult<CaseEntity>> GetByCaseNumberAsync(string caseNumber, int pageSize = 25, string? continuationToken = null, CancellationToken cancellationToken = default);'
            after             = 'Task<PagedResult<CaseEntity>> GetByCaseNumberAsync(string caseNumber, int pageSize = 100, string? continuationToken = null, CancellationToken cancellationToken = default);'
            detectionKeywords = @('magic number', 'constant', 'hardcoded', '100', 'page size', 'named constant')
            fixVerification   = 'pageSize\s*=\s*25'
        }
    )
}

# ---------------------------------------------------------------------------
# Shared Helpers
# ---------------------------------------------------------------------------

function New-MutationTarget {
    <#
    .SYNOPSIS
        Creates a clean consumer-project scaffold suitable for mutation injection.
    .DESCRIPTION
        Generates a 5-layer .NET solution (Common, DataAccess, BusinessLogic,
        DependencyInjection, API) with correct the ecosystem patterns. This is the
        "golden" baseline that mutations will be applied to.
    .PARAMETER WorkDir
        Directory where the scaffold will be created.
    .OUTPUTS
        Hashtable with scaffold metadata (file paths, checksums).
    #>
    param(
        [Parameter(Mandatory)][string]$WorkDir
    )

    if (-not (Test-Path $WorkDir)) {
        New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    }

    Push-Location $WorkDir
    try {
        # Create solution
        & dotnet new sln -n EvalSolution 2>&1 | Out-Null

        # Create projects
        & dotnet new classlib -n Common --no-restore 2>&1 | Out-Null
        Remove-Item -Path "Common/Class1.cs" -ErrorAction SilentlyContinue
        & dotnet new classlib -n DataAccess --no-restore 2>&1 | Out-Null
        Remove-Item -Path "DataAccess/Class1.cs" -ErrorAction SilentlyContinue
        & dotnet new classlib -n BusinessLogic --no-restore 2>&1 | Out-Null
        Remove-Item -Path "BusinessLogic/Class1.cs" -ErrorAction SilentlyContinue
        & dotnet new classlib -n DependencyInjection --no-restore 2>&1 | Out-Null
        Remove-Item -Path "DependencyInjection/Class1.cs" -ErrorAction SilentlyContinue
        & dotnet new web -n API --no-restore 2>&1 | Out-Null

        # Add projects to solution
        & dotnet sln add Common/Common.csproj DataAccess/DataAccess.csproj BusinessLogic/BusinessLogic.csproj DependencyInjection/DependencyInjection.csproj API/API.csproj 2>&1 | Out-Null

        # Add project references
        & dotnet add DataAccess/DataAccess.csproj reference Common/Common.csproj 2>&1 | Out-Null
        & dotnet add BusinessLogic/BusinessLogic.csproj reference Common/Common.csproj 2>&1 | Out-Null
        & dotnet add DependencyInjection/DependencyInjection.csproj reference Common/Common.csproj DataAccess/DataAccess.csproj BusinessLogic/BusinessLogic.csproj 2>&1 | Out-Null
        & dotnet add API/API.csproj reference DependencyInjection/DependencyInjection.csproj Common/Common.csproj BusinessLogic/BusinessLogic.csproj 2>&1 | Out-Null

        # Add NuGet packages
        & dotnet add Common/Common.csproj package System.Runtime.Serialization.Primitives 2>&1 | Out-Null
        & dotnet add DataAccess/DataAccess.csproj package Microsoft.Azure.Cosmos --version "3.*" 2>&1 | Out-Null
        & dotnet add DataAccess/DataAccess.csproj package Newtonsoft.Json 2>&1 | Out-Null
        & dotnet add DataAccess/DataAccess.csproj package Microsoft.Extensions.Logging.Abstractions 2>&1 | Out-Null
        & dotnet add BusinessLogic/BusinessLogic.csproj package Microsoft.Extensions.Logging.Abstractions 2>&1 | Out-Null
        & dotnet add DependencyInjection/DependencyInjection.csproj package Azure.Identity 2>&1 | Out-Null
        & dotnet add DependencyInjection/DependencyInjection.csproj package Microsoft.Extensions.Options.ConfigurationExtensions 2>&1 | Out-Null
        & dotnet add DependencyInjection/DependencyInjection.csproj package Microsoft.Extensions.Options.DataAnnotations 2>&1 | Out-Null

        # Restore all packages
        & dotnet restore 2>&1 | Out-Null

        # --- Common/Models/CosmosEntity.cs ---
        New-Item -ItemType Directory -Force -Path "Common/Models" | Out-Null
        Set-Content -Path "Common/Models/CosmosEntity.cs" -Encoding UTF8 -Value @'
using System.Text.Json.Serialization;

namespace Common.Models;

public interface IPartitioned
{
    string GetPartitionKey();
}

public abstract class CosmosEntity : IPartitioned
{
    [JsonPropertyName("id")]
    public string Id { get; set; } = string.Empty;

    [JsonPropertyName("partitionKey")]
    public string PartitionKey { get; set; } = string.Empty;

    [JsonPropertyName("type")]
    public string Type { get; set; } = string.Empty;

    [JsonPropertyName("createdAt")]
    public DateTimeOffset CreatedAt { get; set; } = DateTimeOffset.UtcNow;

    [JsonPropertyName("modifiedAt")]
    public DateTimeOffset ModifiedAt { get; set; } = DateTimeOffset.UtcNow;

    [JsonPropertyName("isDeleted")]
    public bool IsDeleted { get; set; }

    public abstract string GetPartitionKey();
}
'@

        # --- Common/Models/CaseEntity.cs ---
        Set-Content -Path "Common/Models/CaseEntity.cs" -Encoding UTF8 -Value @'
using System.Text.Json.Serialization;

namespace Common.Models;

public class CaseEntity : CosmosEntity
{
    [JsonPropertyName("caseNumber")]
    public string CaseNumber { get; set; } = string.Empty;

    [JsonPropertyName("title")]
    public string Title { get; set; } = string.Empty;

    [JsonPropertyName("status")]
    [JsonConverter(typeof(JsonStringEnumConverter))]
    public CaseStatus Status { get; set; } = CaseStatus.Open;

    [JsonPropertyName("createdBy")]
    public string CreatedBy { get; set; } = string.Empty;

    public override string GetPartitionKey() => CaseNumber;
}
'@

        # --- Common/Models/CaseStatus.cs ---
        Set-Content -Path "Common/Models/CaseStatus.cs" -Encoding UTF8 -Value @'
using System.Runtime.Serialization;
using System.Text.Json.Serialization;

namespace Common.Models;

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum CaseStatus
{
    [EnumMember(Value = "Open")]
    Open,

    [EnumMember(Value = "Active")]
    Active,

    [EnumMember(Value = "Closed")]
    Closed
}
'@

        # --- Common/Constants/DocumentTypes.cs ---
        New-Item -ItemType Directory -Force -Path "Common/Constants" | Out-Null
        Set-Content -Path "Common/Constants/DocumentTypes.cs" -Encoding UTF8 -Value @'
namespace Common.Constants;

public static class DocumentTypes
{
    public const string Case = "case";
    public const string Note = "note";

    public static string CreateId(string type) => $"{type}:{Guid.NewGuid():N}";
}
'@

        # --- Common/Constants/LogEventIds.cs ---
        Set-Content -Path "Common/Constants/LogEventIds.cs" -Encoding UTF8 -Value @'
namespace Common.Constants;

public static class LogEventIds
{
    // API layer: 1000-1999
    public const int CaseEndpointCalled = 1000;
    public const int CaseEndpointCompleted = 1001;

    // DataAccess layer: 3000-3999
    public const int CosmosQueryExecuted = 3000;
    public const int CosmosItemCreated = 3001;

    // BusinessLogic layer: 4000-4999
    public const int CaseHandlerProcessing = 4000;
    public const int CaseHandlerCompleted = 4001;

    // Common layer: 5000-5999
    public const int ConfigurationLoaded = 5000;
}
'@

        # --- Common/Configuration/IConfigOptions.cs ---
        New-Item -ItemType Directory -Force -Path "Common/Configuration" | Out-Null
        Set-Content -Path "Common/Configuration/IConfigOptions.cs" -Encoding UTF8 -Value @'
namespace Common.Configuration;

public interface IConfigOptions
{
    static abstract string ConfigSectionKey { get; }
}
'@

        # --- Common/Configuration/CosmosOptions.cs ---
        Set-Content -Path "Common/Configuration/CosmosOptions.cs" -Encoding UTF8 -Value @'
using System.ComponentModel.DataAnnotations;

namespace Common.Configuration;

public class CosmosOptions : IConfigOptions
{
    public static string ConfigSectionKey => "Cosmos";

    [Required]
    public string AccountEndpoint { get; set; } = string.Empty;

    [Required]
    public string DatabaseId { get; set; } = string.Empty;

    public string ContainerId { get; set; } = "cms";
}
'@

        # --- Common/Interfaces/ICaseRepository.cs ---
        New-Item -ItemType Directory -Force -Path "Common/Interfaces" | Out-Null
        Set-Content -Path "Common/Interfaces/ICaseRepository.cs" -Encoding UTF8 -Value @'
using Common.Models;
using Common.Pagination;

namespace Common.Interfaces;

public interface ICaseRepository
{
    Task<CaseEntity> CreateAsync(CaseEntity entity, CancellationToken cancellationToken = default);
    Task<CaseEntity?> GetByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default);
    Task<PagedResult<CaseEntity>> GetByCaseNumberAsync(string caseNumber, int pageSize = 25, string? continuationToken = null, CancellationToken cancellationToken = default);
    Task<CaseEntity> UpdateAsync(CaseEntity entity, CancellationToken cancellationToken = default);
    Task SoftDeleteAsync(string id, string partitionKey, CancellationToken cancellationToken = default);
}
'@

        # --- Common/Pagination/PagedResult.cs ---
        New-Item -ItemType Directory -Force -Path "Common/Pagination" | Out-Null
        Set-Content -Path "Common/Pagination/PagedResult.cs" -Encoding UTF8 -Value @'
namespace Common.Pagination;

public class PagedResult<T>
{
    public IReadOnlyList<T> Items { get; init; } = Array.Empty<T>();
    public string? ContinuationToken { get; init; }
    public bool HasMoreResults => !string.IsNullOrEmpty(ContinuationToken);
}
'@

        # --- DataAccess/Repositories/CaseRepository.cs ---
        New-Item -ItemType Directory -Force -Path "DataAccess/Repositories" | Out-Null
        Set-Content -Path "DataAccess/Repositories/CaseRepository.cs" -Encoding UTF8 -Value @'
using Common.Constants;
using Common.Interfaces;
using Common.Models;
using Common.Pagination;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Logging;

namespace DataAccess.Repositories;

public class CaseRepository : ICaseRepository
{
    private readonly Container _container;
    private readonly ILogger<CaseRepository> _logger;

    public CaseRepository(Container container, ILogger<CaseRepository> logger)
    {
        _container = container;
        _logger = logger;
    }

    public async Task<CaseEntity> CreateAsync(CaseEntity entity, CancellationToken cancellationToken = default)
    {
        entity.Id = DocumentTypes.CreateId(DocumentTypes.Case);
        entity.Type = DocumentTypes.Case;
        entity.PartitionKey = entity.GetPartitionKey();
        var response = await _container.CreateItemAsync(entity, new PartitionKey(entity.PartitionKey), cancellationToken: cancellationToken);
        return response.Resource;
    }

    public async Task<CaseEntity?> GetByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        try
        {
            var response = await _container.ReadItemAsync<CaseEntity>(id, new PartitionKey(partitionKey), cancellationToken: cancellationToken);
            return response.Resource.IsDeleted ? null : response.Resource;
        }
        catch (CosmosException ex) when (ex.StatusCode == System.Net.HttpStatusCode.NotFound)
        {
            return null;
        }
    }

    public async Task<PagedResult<CaseEntity>> GetByCaseNumberAsync(string caseNumber, int pageSize = 25, string? continuationToken = null, CancellationToken cancellationToken = default)
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.partitionKey = @pk AND c.type = @type AND c.isDeleted = false")
            .WithParameter("@pk", caseNumber)
            .WithParameter("@type", DocumentTypes.Case);

        var options = new QueryRequestOptions { MaxItemCount = pageSize, PartitionKey = new PartitionKey(caseNumber) };
        using var iterator = _container.GetItemQueryIterator<CaseEntity>(query, continuationToken, options);

        var items = new List<CaseEntity>();
        string? nextToken = null;
        if (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync(cancellationToken);
            items.AddRange(response);
            nextToken = response.ContinuationToken;
        }

        return new PagedResult<CaseEntity> { Items = items, ContinuationToken = nextToken };
    }

    public async Task<CaseEntity> UpdateAsync(CaseEntity entity, CancellationToken cancellationToken = default)
    {
        entity.ModifiedAt = DateTimeOffset.UtcNow;
        var response = await _container.ReplaceItemAsync(entity, entity.Id, new PartitionKey(entity.PartitionKey), cancellationToken: cancellationToken);
        return response.Resource;
    }

    public async Task SoftDeleteAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        var entity = await GetByIdAsync(id, partitionKey, cancellationToken);
        if (entity != null)
        {
            entity.IsDeleted = true;
            await UpdateAsync(entity, cancellationToken);
        }
    }
}
'@

        # --- BusinessLogic/Interfaces/ICaseHandler.cs ---
        New-Item -ItemType Directory -Force -Path "BusinessLogic/Interfaces" | Out-Null
        Set-Content -Path "BusinessLogic/Interfaces/ICaseHandler.cs" -Encoding UTF8 -Value @'
using Common.Models;
using Common.Pagination;

namespace BusinessLogic.Interfaces;

public interface ICaseHandler
{
    Task<CaseEntity> CreateCaseAsync(CaseEntity entity, CancellationToken cancellationToken = default);
    Task<CaseEntity?> GetCaseByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default);
    Task<PagedResult<CaseEntity>> GetCasesByCaseNumberAsync(string caseNumber, int pageSize = 25, string? continuationToken = null, CancellationToken cancellationToken = default);
    Task SoftDeleteCaseAsync(string id, string partitionKey, CancellationToken cancellationToken = default);
}
'@

        # --- BusinessLogic/Handlers/CaseHandler.cs ---
        New-Item -ItemType Directory -Force -Path "BusinessLogic/Handlers" | Out-Null
        Set-Content -Path "BusinessLogic/Handlers/CaseHandler.cs" -Encoding UTF8 -Value @'
using BusinessLogic.Interfaces;
using Common.Interfaces;
using Common.Models;
using Common.Pagination;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Handlers;

public class CaseHandler : ICaseHandler
{
    private readonly ICaseRepository _repository;
    private readonly ILogger<CaseHandler> _logger;

    public CaseHandler(ICaseRepository repository, ILogger<CaseHandler> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<CaseEntity> CreateCaseAsync(CaseEntity entity, CancellationToken cancellationToken = default)
    {
        LogMessages.CreatingCase(_logger, entity.CaseNumber);
        var result = await _repository.CreateAsync(entity, cancellationToken);
        LogMessages.CaseCreated(_logger, result.Id);
        return result;
    }

    public async Task<CaseEntity?> GetCaseByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        return await _repository.GetByIdAsync(id, partitionKey, cancellationToken);
    }

    public async Task<PagedResult<CaseEntity>> GetCasesByCaseNumberAsync(string caseNumber, int pageSize = 25, string? continuationToken = null, CancellationToken cancellationToken = default)
    {
        return await _repository.GetByCaseNumberAsync(caseNumber, pageSize, continuationToken, cancellationToken);
    }

    public async Task SoftDeleteCaseAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        LogMessages.DeletingCase(_logger, id);
        await _repository.SoftDeleteAsync(id, partitionKey, cancellationToken);
    }
}
'@

        # --- BusinessLogic/LogMessages.cs ---
        Set-Content -Path "BusinessLogic/LogMessages.cs" -Encoding UTF8 -Value @'
using Microsoft.Extensions.Logging;

namespace BusinessLogic;

public static partial class LogMessages
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Creating case {CaseNumber}")]
    public static partial void CreatingCase(ILogger logger, string caseNumber);

    [LoggerMessage(Level = LogLevel.Information, Message = "Case created with ID {CaseId}")]
    public static partial void CaseCreated(ILogger logger, string caseId);

    [LoggerMessage(Level = LogLevel.Information, Message = "Deleting case {CaseId}")]
    public static partial void DeletingCase(ILogger logger, string caseId);
}
'@

        # --- DependencyInjection/ServiceCollectionExtensions.cs ---
        Set-Content -Path "DependencyInjection/ServiceCollectionExtensions.cs" -Encoding UTF8 -Value @'
using Azure.Identity;
using BusinessLogic.Handlers;
using BusinessLogic.Interfaces;
using Common.Configuration;
using Common.Interfaces;
using DataAccess.Repositories;
using Microsoft.Azure.Cosmos;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Options;

namespace DependencyInjection;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddCmsServices(this IServiceCollection services, IConfiguration configuration)
    {
        AddConfiguration(services, configuration);
        AddDataAccess(services);
        AddBusinessLogic(services);
        return services;
    }

    private static void AddConfiguration(IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<CosmosOptions>()
            .Bind(configuration.GetSection(CosmosOptions.ConfigSectionKey))
            .ValidateDataAnnotations()
            .ValidateOnStart();
    }

    private static void AddDataAccess(IServiceCollection services)
    {
        services.AddSingleton(sp =>
        {
            var options = sp.GetRequiredService<IOptions<CosmosOptions>>().Value;
            var client = new CosmosClient(options.AccountEndpoint, new DefaultAzureCredential());
            return client.GetContainer(options.DatabaseId, options.ContainerId);
        });

        services.AddScoped<ICaseRepository, CaseRepository>();
    }

    private static void AddBusinessLogic(IServiceCollection services)
    {
        services.AddScoped<ICaseHandler, CaseHandler>();
    }
}
'@

        # --- API/Controllers/CasesController.cs ---
        New-Item -ItemType Directory -Force -Path "API/Controllers" | Out-Null
        Set-Content -Path "API/Controllers/CasesController.cs" -Encoding UTF8 -Value @'
using BusinessLogic.Interfaces;
using Common.Interfaces;
using Common.Models;
using Microsoft.AspNetCore.Mvc;

namespace API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CasesController : ControllerBase
{
    private readonly ICaseHandler _handler;

    public CasesController(ICaseHandler handler)
    {
        _handler = handler;
    }

    [HttpPost]
    public async Task<ActionResult<CaseEntity>> Create([FromBody] CaseEntity entity, CancellationToken cancellationToken)
    {
        var result = await _handler.CreateCaseAsync(entity, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = result.Id, partitionKey = result.PartitionKey }, result);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<CaseEntity>> GetById(string id, [FromQuery] string partitionKey, CancellationToken cancellationToken)
    {
        var result = await _handler.GetCaseByIdAsync(id, partitionKey, cancellationToken);
        return result is null ? NotFound() : Ok(result);
    }

    [HttpGet("by-case/{caseNumber}")]
    public async Task<ActionResult> GetByCaseNumber(string caseNumber, [FromQuery] int pageSize = 25, [FromQuery] string? continuationToken = null, CancellationToken cancellationToken = default)
    {
        var result = await _handler.GetCasesByCaseNumberAsync(caseNumber, pageSize, continuationToken, cancellationToken);
        return Ok(result);
    }

    [HttpDelete("{id}")]
    public async Task<ActionResult> Delete(string id, [FromQuery] string partitionKey, CancellationToken cancellationToken)
    {
        await _handler.SoftDeleteCaseAsync(id, partitionKey, cancellationToken);
        return NoContent();
    }
}
'@

        # --- API/Program.cs ---
        Set-Content -Path "API/Program.cs" -Encoding UTF8 -Value @'
using DependencyInjection;

var builder = WebApplication.CreateBuilder(args);

builder.Configuration.AddJsonFile("appsettings.json", optional: false)
    .AddJsonFile("runtimesettings.json", optional: true);

builder.Services.AddControllers();
builder.Services.AddCmsServices(builder.Configuration);

var app = builder.Build();

app.MapControllers();

app.Run();
'@

        # --- API/appsettings.json ---
        Set-Content -Path "API/appsettings.json" -Encoding UTF8 -Value @'
{
  "Cosmos": {
    "AccountEndpoint": "https://localhost:8081",
    "DatabaseId": "CMS",
    "ContainerId": "cms"
  },
  "Logging": {
    "LogLevel": {
      "Default": "Information"
    }
  }
}
'@

        # --- API/runtimesettings.json ---
        Set-Content -Path "API/runtimesettings.json" -Encoding UTF8 -Value @'
{
  "Cosmos": {
    "AccountEndpoint": "https://cosmos-override.example.com:443"
  }
}
'@

        # Create test project
        & dotnet new xunit -n EvalSolution.Tests --no-restore 2>&1 | Out-Null
        & dotnet sln add EvalSolution.Tests/EvalSolution.Tests.csproj 2>&1 | Out-Null
        & dotnet add EvalSolution.Tests/EvalSolution.Tests.csproj reference Common/Common.csproj 2>&1 | Out-Null
        & dotnet restore EvalSolution.Tests/EvalSolution.Tests.csproj 2>&1 | Out-Null
        Remove-Item -Path "EvalSolution.Tests/UnitTest1.cs" -ErrorAction SilentlyContinue

        # Final restore
        & dotnet restore 2>&1 | Out-Null

    } finally {
        Pop-Location
    }

    # Return scaffold metadata
    return @{
        workDir     = $WorkDir
        solutionFile = Join-Path $WorkDir 'EvalSolution.sln'
        fileCount   = (Get-ChildItem -Path $WorkDir -Recurse -File -Filter '*.cs' -ErrorAction SilentlyContinue |
                       Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' }).Count
    }
}

function Invoke-MutationInjection {
    <#
    .SYNOPSIS
        Injects a single mutation into the scaffold workspace.
    .DESCRIPTION
        Reads the target file, replaces the 'before' pattern with the 'after' pattern,
        and writes the file back. Records the original content for rollback.
        Validates mutation definition against schema before injection.
        Runs Invoke-SecretRedaction on mutation content for security.
    .PARAMETER WorkDir
        Scaffold workspace root.
    .PARAMETER Mutation
        Mutation hashtable from Get-MutationCatalog.
    .OUTPUTS
        Hashtable with injection result: success (bool), originalContent (string), targetPath (string).
    #>
    param(
        [Parameter(Mandatory)][string]$WorkDir,
        [Parameter(Mandatory)][hashtable]$Mutation
    )

    # Schema validation
    $requiredKeys = @('id', 'category', 'name', 'description', 'targetFile', 'before', 'after', 'detectionKeywords', 'fixVerification')
    foreach ($key in $requiredKeys) {
        if (-not $Mutation.ContainsKey($key)) {
            throw "Mutation $($Mutation.id) missing required field: $key"
        }
    }

    # Validate no real secrets in mutation content (uses EvalShared if loaded)
    if (Get-Command -Name 'Invoke-SecretRedaction' -ErrorAction SilentlyContinue) {
        $redacted = Invoke-SecretRedaction -Content $Mutation.after
        if ($redacted -ne $Mutation.after) {
            Write-Warning "Mutation $($Mutation.id) content was redacted -- potential credential detected"
        }
    }

    $targetPath = Join-Path $WorkDir $Mutation.targetFile

    if (-not (Test-Path $targetPath)) {
        return @{
            success         = $false
            originalContent = $null
            targetPath      = $targetPath
            error           = "Target file not found: $($Mutation.targetFile)"
        }
    }

    $originalContent = [string](Get-Content -Path $targetPath -Raw -Encoding UTF8)

    if (-not $originalContent.Contains($Mutation.before)) {
        return @{
            success         = $false
            originalContent = $originalContent
            targetPath      = $targetPath
            error           = "Before pattern not found in $($Mutation.targetFile) for mutation $($Mutation.id)"
        }
    }

    # Inject mutation: replace first occurrence
    $mutatedContent = $originalContent.Replace($Mutation.before, $Mutation.after)
    Set-Content -Path $targetPath -Value $mutatedContent -Encoding UTF8 -NoNewline

    return @{
        success         = $true
        originalContent = $originalContent
        targetPath      = $targetPath
        mutationId      = $Mutation.id
    }
}

function Invoke-MutationScore {
    <#
    .SYNOPSIS
        Computes 4D mutation detection score from agent output and workspace state.
    .DESCRIPTION
        Scores a single mutation across 4 dimensions:
        - Detection (40%): Did the agent identify the mutation? Binary 0/1.
        - Diagnosis (25%): How accurately did it describe the root cause? 0.0-1.0 via keyword matching.
        - Fix Quality (25%): Did the fix revert the mutation correctly? 0.0-1.0 via regex.
        - Regression (10%): Did the fix introduce new issues? Binary 0/1 (build passes).
        Also computes Precision: true_fixes / (true_fixes + false_positives).
    .PARAMETER Mutation
        Mutation hashtable from catalog.
    .PARAMETER WorkDir
        Workspace directory after agent has modified files.
    .PARAMETER OriginalContent
        Original file content before mutation was injected.
    .PARAMETER AgentOutput
        Raw agent output text for keyword analysis.
    .PARAMETER BuildPassed
        Whether the post-agent build succeeded.
    .OUTPUTS
        Hashtable with detection, diagnosis, fixQuality, regression, composite, precision scores.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Mutation,
        [Parameter(Mandatory)][string]$WorkDir,
        [Parameter(Mandatory)][string]$OriginalContent,
        [string]$AgentOutput = '',
        [bool]$BuildPassed = $false
    )

    $targetPath = Join-Path $WorkDir $Mutation.targetFile
    $currentContent = if (Test-Path $targetPath) { [string](Get-Content -Path $targetPath -Raw -Encoding UTF8) } else { '' }

    # --- Detection (40%) ---
    # Agent detected the issue if the mutated code was changed (file differs from injected state)
    $mutatedContent = $OriginalContent.Replace($Mutation.before, $Mutation.after)
    $detectionScore = if ($currentContent -ne $mutatedContent) { 1.0 } else { 0.0 }

    # --- Diagnosis (25%) ---
    # Keyword matching: score based on how many detection keywords appear in agent output
    $diagnosisScore = 0.0
    if ($AgentOutput -and $Mutation.detectionKeywords -and $Mutation.detectionKeywords.Count -gt 0) {
        $matchCount = 0
        $outputLower = $AgentOutput.ToLower()
        foreach ($keyword in $Mutation.detectionKeywords) {
            if ($outputLower.Contains($keyword.ToLower())) {
                $matchCount++
            }
        }
        # Score: proportion of keywords matched, capped at 1.0
        $diagnosisScore = [Math]::Min(1.0, $matchCount / [Math]::Max(1, [Math]::Min(3, $Mutation.detectionKeywords.Count)))
    }

    # --- Fix Quality (25%) ---
    # Check if the fix verification regex matches (meaning the original pattern was restored)
    $fixQualityScore = 0.0
    if ($Mutation.fixVerification -and $currentContent) {
        try {
            if ([regex]::IsMatch($currentContent, $Mutation.fixVerification, [System.Text.RegularExpressions.RegexOptions]::Singleline)) {
                $fixQualityScore = 1.0
            } elseif ($detectionScore -gt 0) {
                # Partial credit: detected and changed, but fix does not match expected pattern
                $fixQualityScore = 0.3
            }
        } catch {
            # Regex error -- skip fix quality
            $fixQualityScore = 0.0
        }
    }

    # --- Regression (10%) ---
    $regressionScore = if ($BuildPassed) { 1.0 } else { 0.0 }

    # --- Composite ---
    $composite = (0.4 * $detectionScore) + (0.25 * $diagnosisScore) + (0.25 * $fixQualityScore) + (0.1 * $regressionScore)

    # --- Precision ---
    # Count lines changed in target file vs original
    $originalLines = $OriginalContent -split "`n"
    $currentLines = $currentContent -split "`n"
    $changedLineCount = 0
    $maxLines = [Math]::Max($originalLines.Count, $currentLines.Count)
    for ($i = 0; $i -lt $maxLines; $i++) {
        $origLine = if ($i -lt $originalLines.Count) { $originalLines[$i].TrimEnd() } else { '' }
        $currLine = if ($i -lt $currentLines.Count) { $currentLines[$i].TrimEnd() } else { '' }
        if ($origLine -ne $currLine) { $changedLineCount++ }
    }

    # Count mutation-related changed lines (lines that differ between mutated and original)
    $mutatedLines = $mutatedContent -split "`n"
    $mutationLineCount = 0
    $mutMaxLines = [Math]::Max($originalLines.Count, $mutatedLines.Count)
    for ($i = 0; $i -lt $mutMaxLines; $i++) {
        $origLine = if ($i -lt $originalLines.Count) { $originalLines[$i].TrimEnd() } else { '' }
        $mutLine = if ($i -lt $mutatedLines.Count) { $mutatedLines[$i].TrimEnd() } else { '' }
        if ($origLine -ne $mutLine) { $mutationLineCount++ }
    }

    # Precision: changes to mutation area / total changes. If no changes, precision = 0
    $precision = if ($changedLineCount -gt 0) {
        [Math]::Min(1.0, $mutationLineCount / $changedLineCount)
    } else { 0.0 }

    return [PSCustomObject]@{
        detection    = $detectionScore
        diagnosis    = [Math]::Round($diagnosisScore, 3)
        fixQuality   = [Math]::Round($fixQualityScore, 3)
        regression   = $regressionScore
        composite    = [Math]::Round($composite, 3)
        precision    = [Math]::Round($precision, 3)
        mutationId   = $Mutation.id
        category     = $Mutation.category
    }
}

function Compare-BaselineTreatment {
    <#
    .SYNOPSIS
        Compares baseline (bare Claude) vs treatment (CCGHCP-guided) mutation scores.
    .DESCRIPTION
        Takes two arrays of per-mutation score hashtables and computes:
        - Per-category detection rates, diagnosis averages, fix quality averages
        - Overall composite scores
        - Discrimination delta (treatment - baseline)
        - Kill criterion checks
    .PARAMETER BaselineScores
        Array of score hashtables from baseline runs.
    .PARAMETER TreatmentScores
        Array of score hashtables from treatment runs.
    .OUTPUTS
        Hashtable with comparison results, per-category breakdowns, and kill criterion flags.
    #>
    param(
        [Parameter(Mandatory)][array]$BaselineScores,
        [Parameter(Mandatory)][array]$TreatmentScores
    )

    # Normalize inputs: convert hashtables to PSCustomObject for Measure-Object compatibility
    $BaselineScores = @($BaselineScores | ForEach-Object { if ($_ -is [hashtable]) { [PSCustomObject]$_ } else { $_ } })
    $TreatmentScores = @($TreatmentScores | ForEach-Object { if ($_ -is [hashtable]) { [PSCustomObject]$_ } else { $_ } })

    $categories = @('CosmosDB', 'Architecture', 'Security', 'Performance', 'Convention')

    $categoryResults = @{}
    foreach ($cat in $categories) {
        $baselineCat = @($BaselineScores | Where-Object { $_.category -eq $cat })
        $treatmentCat = @($TreatmentScores | Where-Object { $_.category -eq $cat })

        $bDetRate = if ($baselineCat.Count -gt 0) { ($baselineCat | Measure-Object -Property detection -Average).Average } else { 0 }
        $tDetRate = if ($treatmentCat.Count -gt 0) { ($treatmentCat | Measure-Object -Property detection -Average).Average } else { 0 }
        $bDiag = if ($baselineCat.Count -gt 0) { ($baselineCat | Measure-Object -Property diagnosis -Average).Average } else { 0 }
        $tDiag = if ($treatmentCat.Count -gt 0) { ($treatmentCat | Measure-Object -Property diagnosis -Average).Average } else { 0 }
        $bFix = if ($baselineCat.Count -gt 0) { ($baselineCat | Measure-Object -Property fixQuality -Average).Average } else { 0 }
        $tFix = if ($treatmentCat.Count -gt 0) { ($treatmentCat | Measure-Object -Property fixQuality -Average).Average } else { 0 }
        $bComp = if ($baselineCat.Count -gt 0) { ($baselineCat | Measure-Object -Property composite -Average).Average } else { 0 }
        $tComp = if ($treatmentCat.Count -gt 0) { ($treatmentCat | Measure-Object -Property composite -Average).Average } else { 0 }

        $categoryResults[$cat] = @{
            baselineDetection    = [Math]::Round($bDetRate, 3)
            treatmentDetection   = [Math]::Round($tDetRate, 3)
            detectionDelta       = [Math]::Round($tDetRate - $bDetRate, 3)
            baselineDiagnosis    = [Math]::Round($bDiag, 3)
            treatmentDiagnosis   = [Math]::Round($tDiag, 3)
            baselineFixQuality   = [Math]::Round($bFix, 3)
            treatmentFixQuality  = [Math]::Round($tFix, 3)
            baselineComposite    = [Math]::Round($bComp, 3)
            treatmentComposite   = [Math]::Round($tComp, 3)
            compositeDelta       = [Math]::Round($tComp - $bComp, 3)
            mutationCount        = [Math]::Max($baselineCat.Count, $treatmentCat.Count)
        }
    }

    # Overall scores
    $bOverallDet = if ($BaselineScores.Count -gt 0) { ($BaselineScores | Measure-Object -Property detection -Average).Average } else { 0 }
    $tOverallDet = if ($TreatmentScores.Count -gt 0) { ($TreatmentScores | Measure-Object -Property detection -Average).Average } else { 0 }
    $bOverallComp = if ($BaselineScores.Count -gt 0) { ($BaselineScores | Measure-Object -Property composite -Average).Average } else { 0 }
    $tOverallComp = if ($TreatmentScores.Count -gt 0) { ($TreatmentScores | Measure-Object -Property composite -Average).Average } else { 0 }

    # Kill criteria
    $killBaselineHigh = $bOverallDet -gt 0.8  # Bare Claude too good -- no discrimination opportunity
    $discriminationDelta = [Math]::Round($tOverallComp - $bOverallComp, 3)

    return @{
        categories         = $categoryResults
        overallBaseline    = [Math]::Round($bOverallComp, 3)
        overallTreatment   = [Math]::Round($tOverallComp, 3)
        discriminationDelta = $discriminationDelta
        baselineDetection  = [Math]::Round($bOverallDet, 3)
        treatmentDetection = [Math]::Round($tOverallDet, 3)
        killCriteria       = @{
            baselineTooHigh = $killBaselineHigh
            insufficientDelta = ($discriminationDelta -lt 0.15)
        }
    }
}

# ---------------------------------------------------------------------------
# Exported eval functions (standard 3-function interface)
# ---------------------------------------------------------------------------

function Setup-Mutation {
    <#
    .SYNOPSIS
        Set up the mutation eval workspace.
    .DESCRIPTION
        Creates a clean consumer-project scaffold and injects selected mutations.
        Records a mutation manifest for assertion comparison.
    .PARAMETER WorkDir
        Directory where the eval workspace will be created.
    .PARAMETER MutationCount
        Number of mutations to inject. Default: 3. Use -1 for all 42.
    .PARAMETER MutationCategories
        Categories to sample from. Default: all 5 categories.
    .PARAMETER MutationIds
        Specific mutation IDs to inject. Overrides MutationCount/MutationCategories.
    #>
    param(
        [Parameter(Mandatory)][string]$WorkDir,
        [int]$MutationCount = 3,
        [string[]]$MutationCategories = @('CosmosDB', 'Architecture', 'Security', 'Performance', 'Convention'),
        [string[]]$MutationIds = @()
    )

    # Step 1: Create clean scaffold
    $scaffoldMeta = New-MutationTarget -WorkDir $WorkDir

    # Step 2: Select mutations
    $catalog = Get-MutationCatalog
    $selectedMutations = @()

    if ($MutationIds.Count -gt 0) {
        # Specific mutations requested
        foreach ($mid in $MutationIds) {
            $m = $catalog | Where-Object { $_.id -eq $mid }
            if ($m) { $selectedMutations += $m }
            else { Write-Warning "Mutation ID '$mid' not found in catalog" }
        }
    } elseif ($MutationCount -eq -1) {
        # All mutations
        $selectedMutations = $catalog | Where-Object { $_.category -in $MutationCategories }
    } else {
        # Sample N mutations across requested categories
        $filtered = $catalog | Where-Object { $_.category -in $MutationCategories }
        if ($MutationCount -ge $filtered.Count) {
            $selectedMutations = $filtered
        } else {
            # Stratified sample: round-robin across categories
            $byCat = @{}
            foreach ($m in $filtered) {
                if (-not $byCat.ContainsKey($m.category)) { $byCat[$m.category] = @() }
                $byCat[$m.category] += $m
            }
            $catKeys = @($byCat.Keys | Sort-Object)
            $picked = 0
            $catIdx = 0
            $catOffsets = @{}
            foreach ($k in $catKeys) { $catOffsets[$k] = 0 }
            while ($picked -lt $MutationCount -and $catKeys.Count -gt 0) {
                $cat = $catKeys[$catIdx % $catKeys.Count]
                $offset = $catOffsets[$cat]
                if ($offset -lt $byCat[$cat].Count) {
                    $selectedMutations += $byCat[$cat][$offset]
                    $catOffsets[$cat] = $offset + 1
                    $picked++
                }
                $catIdx++
                # Safety: break if we have cycled through all categories and all are exhausted
                if ($catIdx -gt ($MutationCount * 2 + $catKeys.Count * 10)) { break }
            }
        }
    }

    # Step 3: Inject mutations and build manifest
    $manifest = @{
        createdAt  = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        workDir    = $WorkDir
        mutations  = [System.Collections.ArrayList]::new()
        originals  = @{}
    }

    foreach ($mutation in $selectedMutations) {
        $result = Invoke-MutationInjection -WorkDir $WorkDir -Mutation $mutation
        if ($result.success) {
            [void]$manifest.mutations.Add(@{
                id          = [string]$mutation.id
                category    = [string]$mutation.category
                name        = [string]$mutation.name
                targetFile  = [string]$mutation.targetFile
            })
            $manifest.originals[$mutation.id] = $result.originalContent
        } else {
            Write-Warning "Failed to inject $($mutation.id): $($result.error)"
        }
    }

    # Step 4: Save manifest (use WinPS 5.1-safe types for ConvertTo-Json)
    $manifestPath = Join-Path $WorkDir '.mutation-manifest.json'
    $jsonManifest = [ordered]@{
        createdAt = [string]$manifest.createdAt
        workDir   = [string]$manifest.workDir
        mutations = @($manifest.mutations)  # ArrayList -> array
        originals = [ordered]@{}
    }
    foreach ($key in $manifest.originals.Keys) {
        $jsonManifest.originals[$key] = [string]$manifest.originals[$key]
    }
    $jsonManifest | ConvertTo-Json -Depth 10 | Set-Content -Path $manifestPath -Encoding UTF8

    return $manifest
}

function Get-MutationPrompt {
    <#
    .SYNOPSIS
        Get the prompt for the mutation eval scenario.
    .DESCRIPTION
        Returns a prompt that asks the agent to review the code for defects.
        Does NOT reveal that mutations were injected.
    .PARAMETER WorkDir
        The eval workspace directory.
    #>
    param(
        [Parameter(Mandatory)][string]$WorkDir
    )

    return @"
Review this consumer-project service codebase for bugs, security issues, performance problems, and convention violations. The project is a 5-layer .NET service (Common, DataAccess, BusinessLogic, DependencyInjection, API) that manages legal cases using Azure Cosmos DB.

For each issue found:
1. Identify the file and line
2. Describe the root cause
3. Fix the issue directly in the code

Focus on: Cosmos DB usage patterns, architecture layering, security best practices, performance antipatterns, and .NET naming/coding conventions.

The project is at $WorkDir. Work directly in the project files. Do not use git. After fixing issues, ensure the project still builds.
"@
}

function Invoke-MutationAssertions {
    <#
    .SYNOPSIS
        Run assertions for the mutation eval scenario.
    .DESCRIPTION
        Checks whether the agent detected and fixed each injected mutation.
        Computes 4D scores (detection, diagnosis, fix quality, regression) and precision.
        Returns standard assertion ArrayList compatible with Run-LocalEval.ps1.
    .PARAMETER WorkDir
        The eval workspace directory to validate.
    .PARAMETER MutationManifest
        Path to the mutation manifest recording what was injected.
        If not provided, looks for .mutation-manifest.json in WorkDir.
    .PARAMETER AgentOutput
        Raw agent output text for keyword-based diagnosis scoring.
    #>
    param(
        [Parameter(Mandatory)][string]$WorkDir,
        [string]$MutationManifest,
        [string]$AgentOutput = ''
    )

    $assertions = [System.Collections.ArrayList]::new()

    # Load manifest
    if (-not $MutationManifest) {
        $MutationManifest = Join-Path $WorkDir '.mutation-manifest.json'
    }
    if (-not (Test-Path $MutationManifest)) {
        [void]$assertions.Add(@{
            name    = 'manifest_exists'
            passed  = $false
            message = "Mutation manifest not found at $MutationManifest"
        })
        return $assertions
    }

    $manifest = [string](Get-Content -Path $MutationManifest -Raw) | ConvertFrom-Json
    [void]$assertions.Add(@{
        name    = 'manifest_exists'
        passed  = $true
        message = "Loaded manifest with $($manifest.mutations.Count) mutations"
    })

    # Check build
    $buildPassed = $false
    Push-Location $WorkDir
    try {
        $buildOutput = & dotnet build --nologo -v q 2>&1
        $buildPassed = ($LASTEXITCODE -eq 0)
    } finally {
        Pop-Location
    }

    [void]$assertions.Add(@{
        name    = 'post_agent_build'
        passed  = $buildPassed
        message = if ($buildPassed) { 'Build passed after agent modifications' } else { 'Build failed after agent modifications' }
    })

    # Score each mutation
    $catalog = Get-MutationCatalog
    $scores = [System.Collections.ArrayList]::new()
    $detectedCount = 0
    $totalMutations = $manifest.mutations.Count

    foreach ($manifestEntry in $manifest.mutations) {
        $mutation = $catalog | Where-Object { $_.id -eq $manifestEntry.id } | Select-Object -First 1
        if (-not $mutation) {
            [void]$assertions.Add(@{
                name    = "mutation_$($manifestEntry.id)_score"
                passed  = $false
                message = "Mutation $($manifestEntry.id) not found in catalog"
            })
            continue
        }

        # Get original content from manifest
        $originalContent = ''
        if ($manifest.originals -and $manifest.originals.PSObject.Properties[$manifestEntry.id]) {
            $originalContent = $manifest.originals.($manifestEntry.id)
        }

        if (-not $originalContent) {
            [void]$assertions.Add(@{
                name    = "mutation_$($manifestEntry.id)_score"
                passed  = $false
                message = "Original content not found for mutation $($manifestEntry.id)"
            })
            continue
        }

        # Compute 4D score
        $score = Invoke-MutationScore `
            -Mutation $mutation `
            -WorkDir $WorkDir `
            -OriginalContent $originalContent `
            -AgentOutput $AgentOutput `
            -BuildPassed $buildPassed

        [void]$scores.Add($score)

        if ($score.detection -gt 0) { $detectedCount++ }

        # Create assertion for this mutation
        $passed = $score.composite -ge 0.5
        [void]$assertions.Add(@{
            name     = "mutation_$($manifestEntry.id)_score"
            passed   = $passed
            expected = "composite >= 0.5"
            actual   = "composite=$($score.composite) det=$($score.detection) diag=$($score.diagnosis) fix=$($score.fixQuality) reg=$($score.regression) prec=$($score.precision)"
            message  = "$($mutation.category): $($mutation.name)"
        })
    }

    # Overall detection rate
    $detectionRate = if ($totalMutations -gt 0) { [Math]::Round($detectedCount / $totalMutations, 3) } else { 0 }
    [void]$assertions.Add(@{
        name     = 'overall_detection_rate'
        passed   = ($detectionRate -ge 0.5)
        expected = ">= 0.5"
        actual   = "$detectionRate ($detectedCount / $totalMutations)"
        message  = "Detection rate across all injected mutations"
    })

    # Overall composite score
    $overallComposite = if ($scores.Count -gt 0) {
        [Math]::Round(($scores | Measure-Object -Property composite -Average).Average, 3)
    } else { 0 }
    [void]$assertions.Add(@{
        name     = 'overall_composite_score'
        passed   = ($overallComposite -ge 0.4)
        expected = ">= 0.4"
        actual   = "$overallComposite"
        message  = "Average composite score (0.4*D + 0.25*Dx + 0.25*FQ + 0.1*R)"
    })

    # Per-category summaries
    $categories = @('CosmosDB', 'Architecture', 'Security', 'Performance', 'Convention')
    foreach ($cat in $categories) {
        $catScores = @($scores | Where-Object { $_.category -eq $cat })
        if ($catScores.Count -gt 0) {
            $catDetRate = [Math]::Round(($catScores | Measure-Object -Property detection -Average).Average, 3)
            $catComposite = [Math]::Round(($catScores | Measure-Object -Property composite -Average).Average, 3)
            [void]$assertions.Add(@{
                name     = "category_${cat}_summary"
                passed   = ($catDetRate -ge 0.3)
                expected = "detection >= 0.3"
                actual   = "det=$catDetRate comp=$catComposite n=$($catScores.Count)"
                message  = "$cat category summary"
            })
        }
    }

    # Save scores alongside manifest for downstream analysis
    $scoresPath = Join-Path $WorkDir '.mutation-scores.json'
    @{
        scores         = @($scores)
        detectionRate  = $detectionRate
        compositeScore = $overallComposite
        buildPassed    = $buildPassed
        mutationCount  = $totalMutations
    } | ConvertTo-Json -Depth 10 | Set-Content -Path $scoresPath -Encoding UTF8

    return $assertions
}

# ---------------------------------------------------------------------------
# Module exports
# ---------------------------------------------------------------------------

Export-ModuleMember -Function @(
    'Setup-Mutation',
    'Get-MutationPrompt',
    'Invoke-MutationAssertions',
    'Get-MutationCatalog',
    'New-MutationTarget',
    'Invoke-MutationInjection',
    'Invoke-MutationScore',
    'Compare-BaselineTreatment'
)
