# Eval04-ArchDrift.psm1 - Architecture Drift Detection module
#
# Tests agent ability to maintain 5-layer the ecosystem architecture across multi-checkpoint
# temptation scenarios. Measures drift via Invoke-ArchitectureCheck + Compute-AHS.
#
# Exports: Setup-ArchDrift, Get-ArchDriftPrompt, Invoke-ArchDriftAssertions
#
# Dependencies (loaded by Run-LocalEval.ps1 before this module):
#   - Invoke-ArchitectureCheck  (.mad/tests/shared/analysis/)
#   - Compute-AHS               (.mad/tests/shared/scoring/)
#   - Invoke-MultiDimensionalScore (.mad/tests/shared/scoring/)
#   - New-Assertion              (EvalShared.psm1)
#   - Write-Status               (EvalShared.psm1)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Architecture rule definitions (15 rules with severity weights)
# Used for Compute-AHS SeverityWeights parameter
# ---------------------------------------------------------------------------
function Get-ArchRuleDefinitions {
    return @(
        @{ rule = 'api_no_dataaccess_ref';         severity = 'critical'; weight = 3 }
        @{ rule = 'api_no_businesslogic_ref';       severity = 'critical'; weight = 3 }
        @{ rule = 'api_no_cosmos_using';            severity = 'critical'; weight = 3 }
        @{ rule = 'bl_no_api_ref';                  severity = 'critical'; weight = 3 }
        @{ rule = 'bl_no_cosmos_using';             severity = 'critical'; weight = 3 }
        @{ rule = 'da_no_api_ref';                  severity = 'critical'; weight = 3 }
        @{ rule = 'da_no_bl_ref';                   severity = 'major';    weight = 2 }
        @{ rule = 'common_no_project_refs';         severity = 'critical'; weight = 3 }
        @{ rule = 'controllers_no_business_logic';  severity = 'major';    weight = 2 }
        @{ rule = 'handlers_have_suffix';           severity = 'minor';    weight = 1 }
        @{ rule = 'repositories_have_suffix';       severity = 'minor';    weight = 1 }
        @{ rule = 'interfaces_in_correct_layer';    severity = 'major';    weight = 2 }
        @{ rule = 'no_circular_refs';               severity = 'critical'; weight = 3 }
        @{ rule = 'config_implements_iconfigoptions'; severity = 'minor';  weight = 1 }
        @{ rule = 'logger_source_generators';       severity = 'minor';    weight = 1 }
        @{ rule = 'di_references_all_layers';       severity = 'major';    weight = 2 }
    )
}

# ---------------------------------------------------------------------------
# Temptation scenario definitions
# ---------------------------------------------------------------------------
function Get-TemptationScenarios {
    return @(
        @{
            name = 'attachment-management'
            checkpoints = @(
                @{
                    id          = 1
                    description = 'Add Attachment entity with CRUD'
                    prompt      = @'
Add a new 'Attachment' entity to this project. Attachments belong to a case and store file metadata (fileName, contentType, sizeBytes, uploadedBy, uploadedAt). Requirements:
- Each attachment has a unique ID and belongs to a case (partition key is caseId)
- Support CRUD operations: create, get by ID, list by case (with pagination), soft delete
- Add the AttachmentEntity model, AttachmentRepository with interface, AttachmentHandler, AttachmentsController endpoint, DI registration, and logging
- Follow the existing patterns in the codebase exactly
The project is at {WorkDir}. Work directly in the project files. Do not use git.
'@
                    temptation  = 'none'
                }
                @{
                    id          = 2
                    description = 'Attachments validate Case exists before creation'
                    prompt      = @'
Update the Attachment creation flow so that before creating an attachment, the system validates that the parent Case exists. If the case does not exist, return a 404 error. Requirements:
- The AttachmentHandler must verify the case exists before creating the attachment
- Use the existing Case repository/handler infrastructure
- Do NOT add direct Cosmos calls in the handler -- use the repository pattern
- Follow the existing patterns in the codebase exactly
The project is at {WorkDir}. Work directly in the project files. Do not use git.
'@
                    temptation  = 'direct-cosmos-in-handler'
                }
                @{
                    id          = 3
                    description = 'Add caching for frequently accessed attachments'
                    prompt      = @'
Add an in-memory cache for frequently accessed attachments to improve read performance. Requirements:
- Cache attachment reads (get by ID) with a 5-minute expiration
- The cache should be in the BusinessLogic layer (handler), NOT in the repository
- Use IMemoryCache from Microsoft.Extensions.Caching.Memory
- Invalidate cache on create and delete operations
- Follow the existing layered architecture patterns exactly
The project is at {WorkDir}. Work directly in the project files. Do not use git.
'@
                    temptation  = 'bypass-repository-layer'
                }
            )
        }
        @{
            name = 'audit-logging'
            checkpoints = @(
                @{
                    id          = 1
                    description = 'Add AuditLog entity with repository'
                    prompt      = @'
Add a new 'AuditLog' entity to this project. Audit logs record who did what and when. Requirements:
- AuditLogEntity with fields: id, action (string), entityType, entityId, performedBy, performedAt, details (string)
- Partition key is entityId (the entity being audited)
- Add AuditLogRepository with interface, AuditLogHandler, and DI registration
- Logging with source generators following existing patterns
- Follow the existing 5-layer architecture exactly
The project is at {WorkDir}. Work directly in the project files. Do not use git.
'@
                    temptation  = 'none'
                }
                @{
                    id          = 2
                    description = 'Audit logs fire on every case update via middleware'
                    prompt      = @'
Add middleware that automatically creates an audit log entry whenever a Case is updated. Requirements:
- Create AuditMiddleware in the API layer that intercepts PUT/PATCH requests to /api/cases
- The middleware should call the AuditLogHandler to create the log entry
- Ensure middleware ordering is correct (after authentication, before endpoint routing)
- Do NOT put business logic in the controller -- use the middleware + handler pattern
- Follow the existing architecture patterns exactly
The project is at {WorkDir}. Work directly in the project files. Do not use git.
'@
                    temptation  = 'business-logic-in-controller'
                }
                @{
                    id          = 3
                    description = 'Add real-time audit dashboard query endpoint'
                    prompt      = @'
Add a new endpoint GET /api/audit/dashboard that returns recent audit activity with filtering. Requirements:
- Support query parameters: entityType, performedBy, fromDate, toDate
- Return paginated results using the existing PagedResult pattern
- Use the repository layer for data access -- do NOT query Cosmos directly from the controller
- Add proper input validation for date range parameters
- Follow the existing architecture patterns exactly
The project is at {WorkDir}. Work directly in the project files. Do not use git.
'@
                    temptation  = 'direct-cosmos-in-controller'
                }
            )
        }
        @{
            name = 'real-time-notifications'
            checkpoints = @(
                @{
                    id          = 1
                    description = 'Add NotificationPreference entity'
                    prompt      = @'
Add a new 'NotificationPreference' entity to this project. Users can configure how they want to be notified. Requirements:
- NotificationPreferenceEntity with fields: id, userId (partition key), channel (email/sms/push), enabled, createdAt, modifiedAt
- Add NotificationPreferenceRepository with interface, NotificationPreferenceHandler
- Add NotificationsController with CRUD endpoints
- Add DI registration and logging with source generators
- Follow the existing 5-layer architecture exactly
The project is at {WorkDir}. Work directly in the project files. Do not use git.
'@
                    temptation  = 'none'
                }
                @{
                    id          = 2
                    description = 'Notifications trigger on case status change'
                    prompt      = @'
When a Case status changes, send notifications to users who have enabled notifications for that case type. Requirements:
- Add a NotificationDispatcher in the BusinessLogic layer
- The CaseHandler should call the NotificationDispatcher after successful status updates
- NotificationDispatcher should read preferences from the repository and queue notifications
- Keep the NotificationDispatcher decoupled from the CaseHandler -- use an interface
- Do NOT directly couple the notification logic into the CaseHandler implementation
- Follow the existing architecture patterns exactly
The project is at {WorkDir}. Work directly in the project files. Do not use git.
'@
                    temptation  = 'tight-coupling-to-case-handler'
                }
                @{
                    id          = 3
                    description = 'Add bulk notification send with rate limiting'
                    prompt      = @'
Add a bulk notification endpoint POST /api/notifications/bulk that sends notifications to multiple users. Requirements:
- Accept a list of user IDs and a message payload
- Implement rate limiting (max 100 notifications per request)
- Add retry logic for failed sends using Polly or similar resilience pattern
- Process notifications through the handler layer, not directly in the controller
- Follow the existing architecture patterns exactly
The project is at {WorkDir}. Work directly in the project files. Do not use git.
'@
                    temptation  = 'skip-resilience-patterns'
                }
            )
        }
    )
}

# ---------------------------------------------------------------------------
# Setup: Generate enterprise-5layer scaffold with deliberate violations
# ---------------------------------------------------------------------------
function Setup-ArchDrift {
    <#
    .SYNOPSIS
        Set up the architecture drift eval workspace.
    .DESCRIPTION
        Creates a 5-layer .NET enterprise scaffold using New-TrapScaffold (if available)
        or the inline scaffold generator. Injects deliberate architecture violations
        that serve as the baseline for measuring agent-introduced drift.

        The scaffold starts with a known set of violations (interface in wrong layer,
        missing LoggerMessage attributes) so that checkpoint 1 measures the agent's
        ability to add new code that follows existing patterns, while checkpoints 2-3
        measure temptation resistance.
    .PARAMETER WorkDir
        Directory where the eval workspace will be created.
    .PARAMETER Scenario
        Which temptation scenario to use. Default: 'attachment-management'.
        Valid: 'attachment-management', 'audit-logging', 'real-time-notifications'.
    #>
    param(
        [Parameter(Mandatory)][string]$WorkDir,
        [ValidateSet('attachment-management', 'audit-logging', 'real-time-notifications')]
        [string]$Scenario = 'attachment-management'
    )

    if (-not (Test-Path $WorkDir)) {
        New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    }

    # Use New-TrapScaffold if available (loaded from scaffolds/ directory)
    if (Get-Command -Name 'New-TrapScaffold' -ErrorAction SilentlyContinue) {
        Write-Status "  Using New-TrapScaffold for enterprise-5layer scaffold" -Type Info
        $scaffoldResult = New-TrapScaffold -OutputPath $WorkDir -ScaffoldType 'enterprise-5layer' -ProjectConfig @{
            namespace        = 'EvalProject'
            projectName      = 'EvalSolution'
            targetFramework  = 'net8.0'
        }
    } else {
        # Inline scaffold generation (minimal version for self-contained operation)
        Write-Status "  Generating inline enterprise-5layer scaffold" -Type Info

        # Create project directories
        $projects = @('Common', 'DataAccess', 'BusinessLogic', 'DependencyInjection', 'API')
        foreach ($proj in $projects) {
            New-Item -ItemType Directory -Path (Join-Path $WorkDir $proj) -Force | Out-Null
        }

        # Generate .csproj files with inline PackageReference entries (no dotnet add package)

        # Common.csproj - no project references, no NuGet packages
        $commonCsproj = @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
</Project>
'@
        Set-Content -Path (Join-Path $WorkDir 'Common/Common.csproj') -Value $commonCsproj -Encoding UTF8

        # DataAccess.csproj - references Common, has Cosmos + Logging packages
        $dataAccessCsproj = @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.Azure.Cosmos" Version="3.*" />
    <PackageReference Include="Microsoft.Extensions.Logging.Abstractions" Version="9.*" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\Common\Common.csproj" />
  </ItemGroup>
</Project>
'@
        Set-Content -Path (Join-Path $WorkDir 'DataAccess/DataAccess.csproj') -Value $dataAccessCsproj -Encoding UTF8

        # BusinessLogic.csproj - references Common + DataAccess, has Logging package
        $businessLogicCsproj = @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Microsoft.Extensions.Logging.Abstractions" Version="9.*" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\Common\Common.csproj" />
    <ProjectReference Include="..\DataAccess\DataAccess.csproj" />
  </ItemGroup>
</Project>
'@
        Set-Content -Path (Join-Path $WorkDir 'BusinessLogic/BusinessLogic.csproj') -Value $businessLogicCsproj -Encoding UTF8

        # DependencyInjection.csproj - references Common + DataAccess + BusinessLogic, has Azure.Identity + Options packages
        $diCsproj = @'
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <PackageReference Include="Azure.Identity" Version="1.*" />
    <PackageReference Include="Microsoft.Extensions.Options.ConfigurationExtensions" Version="9.*" />
  </ItemGroup>
  <ItemGroup>
    <ProjectReference Include="..\Common\Common.csproj" />
    <ProjectReference Include="..\DataAccess\DataAccess.csproj" />
    <ProjectReference Include="..\BusinessLogic\BusinessLogic.csproj" />
  </ItemGroup>
</Project>
'@
        Set-Content -Path (Join-Path $WorkDir 'DependencyInjection/DependencyInjection.csproj') -Value $diCsproj -Encoding UTF8

        # API.csproj - web SDK, references DependencyInjection + Common
        $apiCsproj = @'
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
  <ItemGroup>
    <ProjectReference Include="..\DependencyInjection\DependencyInjection.csproj" />
    <ProjectReference Include="..\Common\Common.csproj" />
  </ItemGroup>
</Project>
'@
        Set-Content -Path (Join-Path $WorkDir 'API/API.csproj') -Value $apiCsproj -Encoding UTF8

        # Generate solution file
        $slnContent = @"
Microsoft Visual Studio Solution File, Format Version 12.00
# Visual Studio Version 17
VisualStudioVersion = 17.0.31903.59
MinimumVisualStudioVersion = 10.0.40219.1
Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "Common", "Common\Common.csproj", "{00000000-0000-0000-0000-000000000001}"
EndProject
Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "DataAccess", "DataAccess\DataAccess.csproj", "{00000000-0000-0000-0000-000000000002}"
EndProject
Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "BusinessLogic", "BusinessLogic\BusinessLogic.csproj", "{00000000-0000-0000-0000-000000000003}"
EndProject
Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "DependencyInjection", "DependencyInjection\DependencyInjection.csproj", "{00000000-0000-0000-0000-000000000004}"
EndProject
Project("{FAE04EC0-301F-11D3-BF4B-00C04F79EFBC}") = "API", "API\API.csproj", "{00000000-0000-0000-0000-000000000005}"
EndProject
Global
	GlobalSection(SolutionConfigurationPlatforms) = preSolution
		Debug|Any CPU = Debug|Any CPU
		Release|Any CPU = Release|Any CPU
	EndGlobalSection
EndGlobal
"@
        Set-Content -Path (Join-Path $WorkDir 'EvalSolution.sln') -Value $slnContent -Encoding UTF8

        # Run dotnet restore with error checking
        $restoreOutput = & dotnet restore (Join-Path $WorkDir 'EvalSolution.sln') 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Status "  dotnet restore failed: $($restoreOutput | Out-String)" -Type Warning
        }
    }

    # -----------------------------------------------------------------------
    # Populate scaffold with the ecosystem-style code (minimal but architecturally correct)
    # -----------------------------------------------------------------------

    # --- Common/Models/CosmosEntity.cs ---
    New-Item -ItemType Directory -Force -Path (Join-Path $WorkDir 'Common/Models') | Out-Null
    $cosmosEntityCs = @'
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
    Set-Content -Path (Join-Path $WorkDir 'Common/Models/CosmosEntity.cs') -Value $cosmosEntityCs -Encoding UTF8

    # --- Common/Models/CaseEntity.cs ---
    $caseEntityCs = @'
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
    Set-Content -Path (Join-Path $WorkDir 'Common/Models/CaseEntity.cs') -Value $caseEntityCs -Encoding UTF8

    # --- Common/Models/CaseStatus.cs ---
    $caseStatusCs = @'
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
    Set-Content -Path (Join-Path $WorkDir 'Common/Models/CaseStatus.cs') -Value $caseStatusCs -Encoding UTF8

    # --- Common/Constants/DocumentTypes.cs ---
    New-Item -ItemType Directory -Force -Path (Join-Path $WorkDir 'Common/Constants') | Out-Null
    $docTypesCs = @'
namespace Common.Constants;

public static class DocumentTypes
{
    public const string Case = "case";
    public const string Note = "note";

    public static string CreateId(string type) => $"{type}:{Guid.NewGuid():N}";
}
'@
    Set-Content -Path (Join-Path $WorkDir 'Common/Constants/DocumentTypes.cs') -Value $docTypesCs -Encoding UTF8

    # --- Common/Constants/LogEventIds.cs ---
    $logEventIdsCs = @'
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
    Set-Content -Path (Join-Path $WorkDir 'Common/Constants/LogEventIds.cs') -Value $logEventIdsCs -Encoding UTF8

    # --- Common/Configuration/IConfigOptions.cs ---
    New-Item -ItemType Directory -Force -Path (Join-Path $WorkDir 'Common/Configuration') | Out-Null
    $configOptionsCs = @'
namespace Common.Configuration;

public interface IConfigOptions
{
    static abstract string ConfigSectionKey { get; }
}
'@
    Set-Content -Path (Join-Path $WorkDir 'Common/Configuration/IConfigOptions.cs') -Value $configOptionsCs -Encoding UTF8

    # --- Common/Configuration/CosmosOptions.cs ---
    $cosmosOptionsCs = @'
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
    Set-Content -Path (Join-Path $WorkDir 'Common/Configuration/CosmosOptions.cs') -Value $cosmosOptionsCs -Encoding UTF8

    # --- Common/Interfaces/ (correct location for repository interfaces) ---
    New-Item -ItemType Directory -Force -Path (Join-Path $WorkDir 'Common/Interfaces') | Out-Null
    $caseRepoIfaceCs = @'
using Common.Models;
using Common.Pagination;

namespace Common.Interfaces;

public interface ICaseRepository
{
    Task<CaseEntity> CreateAsync(CaseEntity entity, CancellationToken cancellationToken = default);
    Task<CaseEntity?> GetByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default);
    Task<PagedResult<CaseEntity>> GetByCaseNumberAsync(string caseNumber, string? continuationToken = null, int pageSize = 25, CancellationToken cancellationToken = default);
}
'@
    Set-Content -Path (Join-Path $WorkDir 'Common/Interfaces/ICaseRepository.cs') -Value $caseRepoIfaceCs -Encoding UTF8

    # --- Common/Pagination/PagedResult.cs ---
    New-Item -ItemType Directory -Force -Path (Join-Path $WorkDir 'Common/Pagination') | Out-Null
    $pagedResultCs = @'
namespace Common.Pagination;

public class PagedResult<T>
{
    public IReadOnlyList<T> Items { get; init; } = Array.Empty<T>();
    public string? ContinuationToken { get; init; }
    public bool HasMoreResults => !string.IsNullOrEmpty(ContinuationToken);
}
'@
    Set-Content -Path (Join-Path $WorkDir 'Common/Pagination/PagedResult.cs') -Value $pagedResultCs -Encoding UTF8

    # --- DataAccess/Repositories/CaseRepository.cs ---
    New-Item -ItemType Directory -Force -Path (Join-Path $WorkDir 'DataAccess/Repositories') | Out-Null
    $caseRepoCs = @'
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

    public async Task<PagedResult<CaseEntity>> GetByCaseNumberAsync(string caseNumber, string? continuationToken = null, int pageSize = 25, CancellationToken cancellationToken = default)
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.partitionKey = @pk AND c.type = @type AND c.isDeleted = false")
            .WithParameter("@pk", caseNumber)
            .WithParameter("@type", DocumentTypes.Case);

        var options = new QueryRequestOptions
        {
            PartitionKey = new PartitionKey(caseNumber),
            MaxItemCount = pageSize
        };
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
}
'@
    Set-Content -Path (Join-Path $WorkDir 'DataAccess/Repositories/CaseRepository.cs') -Value $caseRepoCs -Encoding UTF8

    # --- BusinessLogic/Handlers/CaseHandler.cs ---
    New-Item -ItemType Directory -Force -Path (Join-Path $WorkDir 'BusinessLogic/Handlers') | Out-Null
    $caseHandlerCs = @'
using Common.Interfaces;
using Common.Models;
using Common.Pagination;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Handlers;

public interface ICaseHandler
{
    Task<CaseEntity> CreateCaseAsync(CaseEntity entity, CancellationToken cancellationToken = default);
    Task<CaseEntity?> GetCaseByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default);
    Task<PagedResult<CaseEntity>> GetCasesByCaseNumberAsync(string caseNumber, string? continuationToken = null, int pageSize = 25, CancellationToken cancellationToken = default);
}

public class CaseHandler : ICaseHandler
{
    private readonly ICaseRepository _caseRepository;
    private readonly ILogger<CaseHandler> _logger;

    public CaseHandler(ICaseRepository caseRepository, ILogger<CaseHandler> logger)
    {
        _caseRepository = caseRepository;
        _logger = logger;
    }

    public async Task<CaseEntity> CreateCaseAsync(CaseEntity entity, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation("Creating case with number {CaseNumber}", entity.CaseNumber);
        return await _caseRepository.CreateAsync(entity, cancellationToken);
    }

    public async Task<CaseEntity?> GetCaseByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        return await _caseRepository.GetByIdAsync(id, partitionKey, cancellationToken);
    }

    public async Task<PagedResult<CaseEntity>> GetCasesByCaseNumberAsync(string caseNumber, string? continuationToken = null, int pageSize = 25, CancellationToken cancellationToken = default)
    {
        return await _caseRepository.GetByCaseNumberAsync(caseNumber, continuationToken, pageSize, cancellationToken);
    }
}
'@
    Set-Content -Path (Join-Path $WorkDir 'BusinessLogic/Handlers/CaseHandler.cs') -Value $caseHandlerCs -Encoding UTF8

    # --- DependencyInjection/ServiceCollectionExtensions.cs ---
    $diExtCs = @'
using BusinessLogic.Handlers;
using Common.Interfaces;
using DataAccess.Repositories;
using Microsoft.Extensions.DependencyInjection;

namespace DependencyInjection;

public static class ServiceCollectionExtensions
{
    public static IServiceCollection AddApplicationServices(this IServiceCollection services)
    {
        // DataAccess
        services.AddScoped<ICaseRepository, CaseRepository>();

        // BusinessLogic
        services.AddScoped<ICaseHandler, CaseHandler>();

        return services;
    }
}
'@
    Set-Content -Path (Join-Path $WorkDir 'DependencyInjection/ServiceCollectionExtensions.cs') -Value $diExtCs -Encoding UTF8

    # --- API/Controllers/CasesController.cs ---
    New-Item -ItemType Directory -Force -Path (Join-Path $WorkDir 'API/Controllers') | Out-Null
    $casesControllerCs = @'
using BusinessLogic.Handlers;
using Common.Models;
using Microsoft.AspNetCore.Mvc;

namespace API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CasesController : ControllerBase
{
    private readonly ICaseHandler _caseHandler;

    public CasesController(ICaseHandler caseHandler)
    {
        _caseHandler = caseHandler;
    }

    [HttpPost]
    public async Task<ActionResult<CaseEntity>> Create([FromBody] CaseEntity entity, CancellationToken cancellationToken)
    {
        var result = await _caseHandler.CreateCaseAsync(entity, cancellationToken);
        return CreatedAtAction(nameof(GetById), new { id = result.Id, partitionKey = result.PartitionKey }, result);
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<CaseEntity>> GetById(string id, [FromQuery] string partitionKey, CancellationToken cancellationToken)
    {
        var result = await _caseHandler.GetCaseByIdAsync(id, partitionKey, cancellationToken);
        return result is null ? NotFound() : Ok(result);
    }
}
'@
    Set-Content -Path (Join-Path $WorkDir 'API/Controllers/CasesController.cs') -Value $casesControllerCs -Encoding UTF8

    # --- API/Program.cs (overwrite the template) ---
    $programCs = @'
using DependencyInjection;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddApplicationServices();

var app = builder.Build();

app.MapControllers();

app.Run();
'@
    Set-Content -Path (Join-Path $WorkDir 'API/Program.cs') -Value $programCs -Encoding UTF8

    # Store scenario metadata for assertion use
    $metadataPath = Join-Path $WorkDir '.arch-drift-metadata.json'
    $metadata = @{
        scenario    = $Scenario
        setup_utc   = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        checkpoints = @()
    } | ConvertTo-Json -Depth 5
    Set-Content -Path $metadataPath -Value $metadata -Encoding UTF8
}

# ---------------------------------------------------------------------------
# Prompt: Returns the prompt for the current checkpoint
# ---------------------------------------------------------------------------
function Get-ArchDriftPrompt {
    <#
    .SYNOPSIS
        Get the prompt for the architecture drift eval scenario.
    .DESCRIPTION
        Returns a prompt from the current temptation scenario's first checkpoint.
        The eval runner calls this once per scenario invocation. Multi-checkpoint
        scenarios are handled by the assertion phase which measures drift across
        the code produced by the agent in a single session.
    .PARAMETER WorkDir
        The eval workspace directory.
    .PARAMETER Scenario
        Which temptation scenario. Default: 'attachment-management'.
    .PARAMETER Checkpoint
        Which checkpoint (1-3). Default: 1.
    #>
    param(
        [Parameter(Mandatory)][string]$WorkDir,
        [ValidateSet('attachment-management', 'audit-logging', 'real-time-notifications')]
        [string]$Scenario = 'attachment-management',
        [ValidateRange(1, 3)]
        [int]$Checkpoint = 1
    )

    $scenarios = Get-TemptationScenarios
    $selected = $scenarios | Where-Object { $_.name -eq $Scenario }
    if (-not $selected) {
        throw "Unknown scenario: $Scenario"
    }

    $cp = $selected.checkpoints | Where-Object { $_.id -eq $Checkpoint }
    if (-not $cp) {
        throw "Unknown checkpoint $Checkpoint for scenario $Scenario"
    }

    # For the eval runner, we concatenate all 3 checkpoint prompts into one session
    # so the agent sees a progression of requirements (mimicking real multi-turn work).
    # This lets us measure drift within a single agent session.
    $allCheckpoints = $selected.checkpoints | Sort-Object { $_.id }
    $combinedPrompt = @"
You are working on a .NET project at $WorkDir. Complete the following tasks IN ORDER. Each task builds on the previous one. Follow the existing 5-layer architecture patterns exactly. Do not use git.

"@

    foreach ($ckpt in $allCheckpoints) {
        $taskPrompt = $ckpt.prompt -replace '\{WorkDir\}', $WorkDir
        $combinedPrompt += @"

## Task $($ckpt.id): $($ckpt.description)

$taskPrompt

"@
    }

    $combinedPrompt += @"

IMPORTANT: Complete all three tasks in order. After each task, make sure the project still builds (dotnet build). Follow the existing layered architecture -- do NOT bypass the repository pattern or add direct database calls in handlers or controllers.
"@

    return $combinedPrompt
}

# ---------------------------------------------------------------------------
# Assertions: Run architecture checks and compute AHS with drift tracking
# ---------------------------------------------------------------------------
function Invoke-ArchDriftAssertions {
    <#
    .SYNOPSIS
        Run assertions for the architecture drift eval scenario.
    .DESCRIPTION
        Runs Invoke-ArchitectureCheck on the workspace, computes AHS using
        Compute-AHS with severity weights, and produces assertions about
        architectural conformance. Also computes a composite score using
        Invoke-MultiDimensionalScore.
    .PARAMETER WorkDir
        The eval workspace directory to validate.
    .PARAMETER Scenario
        Which temptation scenario was used. Default: 'attachment-management'.
    #>
    param(
        [Parameter(Mandatory)][string]$WorkDir,
        [ValidateSet('attachment-management', 'audit-logging', 'real-time-notifications')]
        [string]$Scenario = 'attachment-management'
    )

    $assertions = [System.Collections.ArrayList]::new()

    # -----------------------------------------------------------------------
    # Step 1: Run architecture check
    # -----------------------------------------------------------------------
    Write-Status "  Running architecture check on workspace..." -Type Info

    $archResult = $null
    try {
        if (Get-Command -Name 'Invoke-ArchitectureCheck' -ErrorAction SilentlyContinue) {
            $archResult = Invoke-ArchitectureCheck -SolutionPath $WorkDir
        } else {
            [void]$assertions.Add((New-Assertion -Name 'arch_check_available' -Passed $false `
                -Expected 'Invoke-ArchitectureCheck function available' `
                -Actual 'Function not found' `
                -Message 'Invoke-ArchitectureCheck not loaded. Ensure analysis modules are imported.'))
            return $assertions
        }
    } catch {
        [void]$assertions.Add((New-Assertion -Name 'arch_check_execution' -Passed $false `
            -Expected 'Architecture check completes without error' `
            -Actual "Error: $($_.Exception.Message)" `
            -Message 'Invoke-ArchitectureCheck threw an exception'))
        return $assertions
    }

    [void]$assertions.Add((New-Assertion -Name 'arch_check_execution' -Passed $true `
        -Expected 'Architecture check completes' `
        -Actual "Checked $($archResult.total_rules) rules: $($archResult.passing) passing, $($archResult.failing) failing"))

    # -----------------------------------------------------------------------
    # Step 2: Compute AHS using severity weights
    # -----------------------------------------------------------------------
    Write-Status "  Computing AHS score..." -Type Info

    $severityWeights = @()
    $ruleDefinitions = Get-ArchRuleDefinitions
    foreach ($rr in $archResult.results) {
        # Match result to definition for weight
        $def = $ruleDefinitions | Where-Object { $_.rule -eq $rr.rule } | Select-Object -First 1
        $weight = if ($def) { $def.weight } else { 1 }
        $severity = if ($def) { $def.severity } else { 'minor' }
        $severityWeights += @{
            rule     = $rr.rule
            severity = $severity
            weight   = $weight
            passed   = $rr.passed
        }
    }

    $ahsResult = $null
    if (Get-Command -Name 'Compute-AHS' -ErrorAction SilentlyContinue) {
        $ahsResult = Compute-AHS -TotalRules $archResult.total_rules -PassingRules $archResult.passing -SeverityWeights $severityWeights
    } else {
        # Fallback: simple ratio
        $ahsResult = @{
            score          = if ($archResult.total_rules -gt 0) { [Math]::Round($archResult.passing / $archResult.total_rules, 4) } else { 0.0 }
            passing        = $archResult.passing
            total          = $archResult.total_rules
            weighted_score = 0.0
        }
    }

    $ahsScore = $ahsResult.weighted_score
    Write-Status "  AHS: $ahsScore (simple: $($ahsResult.score), $($ahsResult.passing)/$($ahsResult.total) rules passing)" -Type Info

    # AHS assertion: score should be >= 0.7 (allowing some drift but not catastrophic)
    [void]$assertions.Add((New-Assertion -Name 'ahs_score' -Passed ($ahsScore -ge 0.7) `
        -Expected 'AHS >= 0.7' `
        -Actual "AHS = $ahsScore" `
        -Message "Architecture Health Score: $ahsScore (weighted), $($ahsResult.score) (simple)"))

    # -----------------------------------------------------------------------
    # Step 3: Per-category assertions
    # -----------------------------------------------------------------------

    # Critical layering rules (must all pass)
    $criticalRules = @($archResult.results | Where-Object {
        $def = $ruleDefinitions | Where-Object { $_.rule -eq $_.rule } | Select-Object -First 1
        $_.rule -in @('api_no_dataaccess_ref', 'api_no_businesslogic_ref', 'bl_no_api_ref',
                       'da_no_api_ref', 'common_no_project_refs', 'no_circular_refs')
    })
    $criticalFailing = @($archResult.results | Where-Object {
        $_.rule -in @('api_no_dataaccess_ref', 'api_no_businesslogic_ref', 'bl_no_api_ref',
                       'da_no_api_ref', 'common_no_project_refs', 'no_circular_refs') -and
        $_.passed -eq $false
    })
    [void]$assertions.Add((New-Assertion -Name 'critical_layering_rules' -Passed ($criticalFailing.Count -eq 0) `
        -Expected 'All critical layering rules pass' `
        -Actual "$($criticalFailing.Count) critical layering violations" `
        -Message $(if ($criticalFailing.Count -gt 0) { "Violations: $(($criticalFailing | ForEach-Object { $_.rule }) -join ', ')" } else { "All critical layering rules pass" })))

    # Cosmos isolation (API and BL must not use Cosmos directly)
    $cosmosRules = @($archResult.results | Where-Object { $_.rule -in @('api_no_cosmos_using', 'bl_no_cosmos_using') })
    $cosmosViolations = @($cosmosRules | Where-Object { $_.passed -eq $false })
    [void]$assertions.Add((New-Assertion -Name 'cosmos_isolation' -Passed ($cosmosViolations.Count -eq 0) `
        -Expected 'No Cosmos usage in API or BusinessLogic layers' `
        -Actual "$($cosmosViolations.Count) Cosmos isolation violations" `
        -Message $(if ($cosmosViolations.Count -gt 0) { "Violations: $(($cosmosViolations | ForEach-Object { $_.message }) -join '; ')" } else { "Cosmos properly isolated to DataAccess layer" })))

    # Encapsulation (controllers should not have business logic, interfaces in correct layer)
    $encapRules = @($archResult.results | Where-Object { $_.rule -in @('controllers_no_business_logic', 'interfaces_in_correct_layer') })
    $encapViolations = @($encapRules | Where-Object { $_.passed -eq $false })
    [void]$assertions.Add((New-Assertion -Name 'encapsulation_maintained' -Passed ($encapViolations.Count -eq 0) `
        -Expected 'No encapsulation violations' `
        -Actual "$($encapViolations.Count) encapsulation violations" `
        -Message $(if ($encapViolations.Count -gt 0) { "Violations: $(($encapViolations | ForEach-Object { $_.message }) -join '; ')" } else { "Encapsulation properly maintained" })))

    # Naming conventions
    $namingRules = @($archResult.results | Where-Object { $_.rule -in @('handlers_have_suffix', 'repositories_have_suffix', 'config_implements_iconfigoptions', 'logger_source_generators') })
    $namingViolations = @($namingRules | Where-Object { $_.passed -eq $false })
    [void]$assertions.Add((New-Assertion -Name 'naming_conventions' -Passed ($namingViolations.Count -le 1) `
        -Expected 'At most 1 naming violation' `
        -Actual "$($namingViolations.Count) naming violations" `
        -Message $(if ($namingViolations.Count -gt 1) { "Violations: $(($namingViolations | ForEach-Object { $_.rule }) -join ', ')" } else { "Naming conventions mostly followed" })))

    # -----------------------------------------------------------------------
    # Step 4: Temptation-specific assertions
    # -----------------------------------------------------------------------

    $scenarios = Get-TemptationScenarios
    $selected = $scenarios | Where-Object { $_.name -eq $Scenario }

    if ($selected) {
        # Check for temptation-specific violations
        switch ($Scenario) {
            'attachment-management' {
                # Checkpoint 2 temptation: direct Cosmos call in handler
                if ($blDir = Join-Path $WorkDir 'BusinessLogic') {
                    $blFiles = @(Get-ChildItem -Path $blDir -Recurse -Include '*.cs' -File -ErrorAction SilentlyContinue |
                        Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' })
                    $cosmosInHandler = $false
                    foreach ($f in $blFiles) {
                        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
                        if ($content -and $content -match 'Microsoft\.Azure\.Cosmos|Container\s+_container|CosmosClient') {
                            $cosmosInHandler = $true
                            break
                        }
                    }
                    [void]$assertions.Add((New-Assertion -Name 'temptation_no_cosmos_in_handler' -Passed (-not $cosmosInHandler) `
                        -Expected 'No Cosmos references in BusinessLogic handlers' `
                        -Actual $(if ($cosmosInHandler) { "Cosmos references found in BusinessLogic" } else { "Clean" }) `
                        -Message 'Checkpoint 2 temptation: agent should use repository pattern, not direct Cosmos'))
                }

                # Checkpoint 3 temptation: cache bypasses repository
                $apiDir = Join-Path $WorkDir 'API'
                if (Test-Path $apiDir) {
                    $apiFiles = @(Get-ChildItem -Path $apiDir -Recurse -Include '*.cs' -File -ErrorAction SilentlyContinue |
                        Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' })
                    $cacheInApi = $false
                    foreach ($f in $apiFiles) {
                        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
                        if ($content -and $content -match 'IMemoryCache|MemoryCache') {
                            $cacheInApi = $true
                            break
                        }
                    }
                    [void]$assertions.Add((New-Assertion -Name 'temptation_cache_in_correct_layer' -Passed (-not $cacheInApi) `
                        -Expected 'Cache logic in BusinessLogic layer, not API' `
                        -Actual $(if ($cacheInApi) { "Cache found in API layer" } else { "Cache not in API layer" }) `
                        -Message 'Checkpoint 3 temptation: caching should be in handler layer'))
                }
            }
            'audit-logging' {
                # Checkpoint 2 temptation: business logic in controller
                $apiDir = Join-Path $WorkDir 'API'
                if (Test-Path $apiDir) {
                    $controllerFiles = @(Get-ChildItem -Path $apiDir -Recurse -Include '*Controller.cs' -File -ErrorAction SilentlyContinue |
                        Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' })
                    $logicInController = $false
                    foreach ($f in $controllerFiles) {
                        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
                        if ($content -and $content -match 'AuditLog|CreateAudit|LogAudit') {
                            # Check if the controller is doing more than delegating
                            if ($content -match 'new\s+AuditLog|\.CreateAsync.*AuditLog|Repository.*Audit') {
                                $logicInController = $true
                                break
                            }
                        }
                    }
                    [void]$assertions.Add((New-Assertion -Name 'temptation_no_audit_logic_in_controller' -Passed (-not $logicInController) `
                        -Expected 'Audit logic delegated to handler/middleware, not in controller' `
                        -Actual $(if ($logicInController) { "Audit logic found in controller" } else { "Clean" }) `
                        -Message 'Checkpoint 2 temptation: audit logic should be in middleware or handler'))
                }

                # Checkpoint 3 temptation: direct Cosmos query in controller
                if (Test-Path $apiDir) {
                    $apiFiles = @(Get-ChildItem -Path $apiDir -Recurse -Include '*.cs' -File -ErrorAction SilentlyContinue |
                        Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' })
                    $cosmosInApi = $false
                    foreach ($f in $apiFiles) {
                        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
                        if ($content -and $content -match 'QueryDefinition|GetItemQueryIterator|CosmosClient|Container\s+_') {
                            $cosmosInApi = $true
                            break
                        }
                    }
                    [void]$assertions.Add((New-Assertion -Name 'temptation_no_cosmos_in_api' -Passed (-not $cosmosInApi) `
                        -Expected 'No direct Cosmos queries in API layer' `
                        -Actual $(if ($cosmosInApi) { "Cosmos queries found in API" } else { "Clean" }) `
                        -Message 'Checkpoint 3 temptation: dashboard query should use repository layer'))
                }
            }
            'real-time-notifications' {
                # Checkpoint 2 temptation: tight coupling notification to case handler
                $blDir = Join-Path $WorkDir 'BusinessLogic'
                if (Test-Path $blDir) {
                    $caseHandlerFile = Get-ChildItem -Path $blDir -Recurse -Include 'CaseHandler.cs' -File -ErrorAction SilentlyContinue | Select-Object -First 1
                    $tightCoupling = $false
                    if ($caseHandlerFile) {
                        $content = Get-Content $caseHandlerFile.FullName -Raw -ErrorAction SilentlyContinue
                        if ($content) {
                            # Check if CaseHandler directly instantiates notification classes (tight coupling)
                            if ($content -match 'new\s+Notification(?!Dispatcher|Handler)|SendNotification|\.Send\(') {
                                $tightCoupling = $true
                            }
                        }
                    }
                    [void]$assertions.Add((New-Assertion -Name 'temptation_decoupled_notifications' -Passed (-not $tightCoupling) `
                        -Expected 'Notifications decoupled from CaseHandler via interface' `
                        -Actual $(if ($tightCoupling) { "Tight coupling detected" } else { "Properly decoupled" }) `
                        -Message 'Checkpoint 2 temptation: notifications should use interface-based dispatcher'))
                }

                # Checkpoint 3: rate limiting and resilience
                $blDir = Join-Path $WorkDir 'BusinessLogic'
                if (Test-Path $blDir) {
                    $blFiles = @(Get-ChildItem -Path $blDir -Recurse -Include '*.cs' -File -ErrorAction SilentlyContinue |
                        Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' })
                    $hasResilience = $false
                    foreach ($f in $blFiles) {
                        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
                        if ($content -and ($content -match 'Polly|RetryPolicy|CircuitBreaker|IAsyncPolicy|ResiliencePipeline|SemaphoreSlim|RateLimiter')) {
                            $hasResilience = $true
                            break
                        }
                    }
                    [void]$assertions.Add((New-Assertion -Name 'temptation_has_resilience' -Passed $hasResilience `
                        -Expected 'Resilience patterns present for bulk send' `
                        -Actual $(if ($hasResilience) { "Resilience pattern found" } else { "No resilience patterns" }) `
                        -Message 'Checkpoint 3 temptation: bulk send should include retry/rate limiting'))
                }
            }
        }
    }

    # -----------------------------------------------------------------------
    # Step 5: Composite score using Invoke-MultiDimensionalScore
    # -----------------------------------------------------------------------

    if (Get-Command -Name 'Invoke-MultiDimensionalScore' -ErrorAction SilentlyContinue) {
        $criticalScore = if ($criticalFailing.Count -eq 0) { 1.0 } else {
            $critRules = @($archResult.results | Where-Object {
                $_.rule -in @('api_no_dataaccess_ref', 'api_no_businesslogic_ref', 'bl_no_api_ref',
                               'da_no_api_ref', 'common_no_project_refs', 'no_circular_refs')
            })
            $critPassing = @($critRules | Where-Object { $_.passed }).Count
            $critTotal = $critRules.Count
            if ($critTotal -gt 0) { [Math]::Round($critPassing / $critTotal, 4) } else { 1.0 }
        }

        $dimensions = @(
            @{ name = 'ahs_weighted'; score = [double]$ahsScore; weight = 0.4 }
            @{ name = 'critical_layering'; score = [double]$criticalScore; weight = 0.35 }
            @{ name = 'cosmos_isolation'; score = $(if ($cosmosViolations.Count -eq 0) { 1.0 } else { 0.0 }); weight = 0.25 }
        )

        $compositeResult = Invoke-MultiDimensionalScore -Dimensions $dimensions
        Write-Status "  Composite score: $($compositeResult.composite) (method: $($compositeResult.method))" -Type Info

        [void]$assertions.Add((New-Assertion -Name 'composite_score' -Passed ($compositeResult.composite -ge 0.7) `
            -Expected 'Composite score >= 0.7' `
            -Actual "Composite = $($compositeResult.composite)" `
            -Message "Dimensions: AHS=$ahsScore (0.4), Critical=$criticalScore (0.35), Cosmos=$(if ($cosmosViolations.Count -eq 0) { '1.0' } else { '0.0' }) (0.25)"))
    }

    # -----------------------------------------------------------------------
    # Step 6: Per-rule detail assertions (for drill-down)
    # -----------------------------------------------------------------------
    foreach ($rr in $archResult.results) {
        $icon = if ($rr.passed) { 'pass' } else { 'fail' }
        [void]$assertions.Add((New-Assertion -Name "rule_$($rr.rule)" -Passed $rr.passed `
            -Expected "$($rr.rule) passes" `
            -Actual "$icon -- $($rr.message)"))
    }

    return $assertions
}

Export-ModuleMember -Function @(
    'Setup-ArchDrift',
    'Get-ArchDriftPrompt',
    'Invoke-ArchDriftAssertions'
)
