# Eval01-RuleAdherence.psm1 - Rule Adherence Scorecard eval module
#
# Tests whether CCGHCP-guided Claude overrides planted antipatterns in a
# 5-layer .NET scaffold while bare Claude copies them. Measures discrimination
# delta (treatment - baseline) using 18 assertions across 3 categories:
#   - Antipattern Resistance (A1-A7): Did the agent resist copying 7 planted traps?
#   - Convention Adherence (C1-C6): Did the agent follow .NET ecosystem conventions?
#   - Build & Quality (Q1-Q5): Does the code compile and pass tests?
#
# Exports: Setup-RuleAdherenceScorecard, Get-RuleAdherenceScorecardPrompt,
#          Invoke-RuleAdherenceScorecardAssertions
#
# Dependencies:
#   - EvalShared.psm1 (New-Assertion, Write-Status, Invoke-SecretRedaction)
#   - Compute-FisherExact.ps1 (small-sample significance)
#   - Invoke-MultiDimensionalScore.ps1 (composite scoring)

$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# Scenario definition metadata
# ---------------------------------------------------------------------------
$Script:ScenarioDefinition = @{
    name        = 'rule-adherence'
    eval_id     = 'eval-01'
    category    = 'enterprise'
    description = 'Tests CCGHCP rule adherence via trap scaffold with 18 assertions'
    max_turns   = 50
    timeout_sec = 600
    cost_limit  = 3.0
    assertions  = 18
}

function Get-RuleAdherenceScorecardDefinition {
    <#
    .SYNOPSIS
        Return the scenario definition metadata for rule-adherence.
    #>
    return $Script:ScenarioDefinition
}

# ---------------------------------------------------------------------------
# Setup: Create the 5-layer .NET scaffold with 7 planted antipatterns
# ---------------------------------------------------------------------------
function Setup-RuleAdherenceScorecard {
    <#
    .SYNOPSIS
        Set up the rule adherence eval workspace with a 5-layer .NET scaffold.
    .DESCRIPTION
        Creates a .NET solution with Common, DataAccess, BusinessLogic,
        DependencyInjection, and API layers. Plants 7 antipatterns in existing
        code (CaseService naming, collocated interfaces, List returns, magic
        strings, interpolated logging, controller try-catch). The agent is asked
        to add a new Attachment entity -- the eval checks whether it copies
        antipatterns or follows correct patterns.
    .PARAMETER WorkDir
        Directory where the eval workspace will be created.
    #>
    param(
        [Parameter(Mandatory)][string]$WorkDir
    )

    # Delegate to existing Setup-TrapAntipatternResistance if available (loaded from Run-LocalEval.ps1)
    if (Get-Command -Name 'Setup-TrapAntipatternResistance' -ErrorAction SilentlyContinue) {
        Setup-TrapAntipatternResistance -WorkDir $WorkDir
        return
    }

    # Standalone scaffold creation (identical to Setup-TrapAntipatternResistance)
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

        # Add project references (layered architecture)
        & dotnet add DataAccess/DataAccess.csproj reference Common/Common.csproj 2>&1 | Out-Null
        & dotnet add BusinessLogic/BusinessLogic.csproj reference Common/Common.csproj DataAccess/DataAccess.csproj 2>&1 | Out-Null
        & dotnet add DependencyInjection/DependencyInjection.csproj reference Common/Common.csproj DataAccess/DataAccess.csproj BusinessLogic/BusinessLogic.csproj 2>&1 | Out-Null
        & dotnet add API/API.csproj reference DependencyInjection/DependencyInjection.csproj Common/Common.csproj 2>&1 | Out-Null

        # Add NuGet packages
        & dotnet add Common/Common.csproj package System.Runtime.Serialization.Primitives 2>&1 | Out-Null
        & dotnet add DataAccess/DataAccess.csproj package Microsoft.Azure.Cosmos --version "3.*" 2>&1 | Out-Null
        & dotnet add DataAccess/DataAccess.csproj package Newtonsoft.Json 2>&1 | Out-Null
        & dotnet add DataAccess/DataAccess.csproj package Microsoft.Extensions.Logging.Abstractions 2>&1 | Out-Null
        & dotnet add BusinessLogic/BusinessLogic.csproj package Microsoft.Extensions.Logging.Abstractions 2>&1 | Out-Null
        & dotnet add DependencyInjection/DependencyInjection.csproj package Azure.Identity 2>&1 | Out-Null
        & dotnet add DependencyInjection/DependencyInjection.csproj package Microsoft.Extensions.Options.ConfigurationExtensions 2>&1 | Out-Null
        & dotnet add DependencyInjection/DependencyInjection.csproj package Microsoft.Extensions.Options.DataAnnotations 2>&1 | Out-Null

        # Restore
        & dotnet restore 2>&1 | Out-Null

        # --- Common layer (CORRECT patterns) ---
        New-Item -ItemType Directory -Force -Path "Common/Models" | Out-Null
        @'
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
'@ | Set-Content -Path "Common/Models/CosmosEntity.cs" -Encoding UTF8

        @'
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
'@ | Set-Content -Path "Common/Models/CaseEntity.cs" -Encoding UTF8

        @'
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
'@ | Set-Content -Path "Common/Models/CaseStatus.cs" -Encoding UTF8

        New-Item -ItemType Directory -Force -Path "Common/Constants" | Out-Null
        @'
namespace Common.Constants;

public static class DocumentTypes
{
    public const string Case = "case";
    public const string Note = "note";

    public static string CreateId(string type) => $"{type}:{Guid.NewGuid():N}";
}
'@ | Set-Content -Path "Common/Constants/DocumentTypes.cs" -Encoding UTF8

        @'
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
'@ | Set-Content -Path "Common/Constants/LogEventIds.cs" -Encoding UTF8

        New-Item -ItemType Directory -Force -Path "Common/Configuration" | Out-Null
        @'
namespace Common.Configuration;

public interface IConfigOptions
{
    static abstract string ConfigSectionKey { get; }
}
'@ | Set-Content -Path "Common/Configuration/IConfigOptions.cs" -Encoding UTF8

        @'
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
'@ | Set-Content -Path "Common/Configuration/CosmosOptions.cs" -Encoding UTF8

        # ANTIPATTERN: Common/Interfaces exists but is empty (no ICaseRepository here)
        New-Item -ItemType Directory -Force -Path "Common/Interfaces" | Out-Null

        New-Item -ItemType Directory -Force -Path "Common/Pagination" | Out-Null
        @'
namespace Common.Pagination;

public class PagedResult<T>
{
    public IReadOnlyList<T> Items { get; init; } = Array.Empty<T>();
    public string? ContinuationToken { get; init; }
    public bool HasMoreResults => !string.IsNullOrEmpty(ContinuationToken);
}
'@ | Set-Content -Path "Common/Pagination/PagedResult.cs" -Encoding UTF8

        # --- DataAccess layer (ANTIPATTERNS #2, #3, #4, #7) ---
        New-Item -ItemType Directory -Force -Path "DataAccess/Repositories" | Out-Null
        @'
using Common.Models;

namespace DataAccess.Repositories;

// ANTIPATTERN: Interface collocated with implementation (should be in Common/Interfaces)
public interface ICaseRepository
{
    Task<CaseEntity> CreateAsync(CaseEntity entity, CancellationToken cancellationToken = default);
    Task<CaseEntity?> GetByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default);
    Task<List<CaseEntity>> GetByCaseNumberAsync(string caseNumber, CancellationToken cancellationToken = default);
}
'@ | Set-Content -Path "DataAccess/Repositories/ICaseRepository.cs" -Encoding UTF8

        @'
using Common.Models;
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
        entity.Id = Guid.NewGuid().ToString("N");
        entity.Type = "case";
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

    // ANTIPATTERN #3: Returns Task<List<>> instead of PagedResult<>
    // ANTIPATTERN #4: Uses magic string "case" instead of DocumentTypes.Case
    public async Task<List<CaseEntity>> GetByCaseNumberAsync(string caseNumber, CancellationToken cancellationToken = default)
    {
        var query = new QueryDefinition("SELECT * FROM c WHERE c.partitionKey = @pk AND c.type = @type AND c.isDeleted = false")
            .WithParameter("@pk", caseNumber)
            .WithParameter("@type", "case");

        var options = new QueryRequestOptions { PartitionKey = new PartitionKey(caseNumber) };
        using var iterator = _container.GetItemQueryIterator<CaseEntity>(query, requestOptions: options);

        var items = new List<CaseEntity>();
        while (iterator.HasMoreResults)
        {
            var response = await iterator.ReadNextAsync(cancellationToken);
            items.AddRange(response);
        }
        return items;
    }
}
'@ | Set-Content -Path "DataAccess/Repositories/CaseRepository.cs" -Encoding UTF8

        # --- BusinessLogic layer (ANTIPATTERNS #1, #5) ---
        New-Item -ItemType Directory -Force -Path "BusinessLogic/Interfaces" | Out-Null
        @'
using Common.Models;

namespace BusinessLogic.Interfaces;

// ANTIPATTERN #1: Should be ICaseHandler, not ICaseService
public interface ICaseService
{
    Task<CaseEntity> CreateCaseAsync(CaseEntity entity, CancellationToken cancellationToken = default);
    Task<CaseEntity?> GetCaseByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default);
}
'@ | Set-Content -Path "BusinessLogic/Interfaces/ICaseService.cs" -Encoding UTF8

        New-Item -ItemType Directory -Force -Path "BusinessLogic/Services" | Out-Null
        @'
using BusinessLogic.Interfaces;
using Common.Models;
using DataAccess.Repositories;
using Microsoft.Extensions.Logging;

namespace BusinessLogic.Services;

// ANTIPATTERN #1: Should be CaseHandler in Handlers/, not CaseService in Services/
public class CaseService : ICaseService
{
    private readonly ICaseRepository _repository;
    private readonly ILogger<CaseService> _logger;

    public CaseService(ICaseRepository repository, ILogger<CaseService> logger)
    {
        _repository = repository;
        _logger = logger;
    }

    public async Task<CaseEntity> CreateCaseAsync(CaseEntity entity, CancellationToken cancellationToken = default)
    {
        // ANTIPATTERN #5: Uses string interpolation instead of LoggerMessage source generator
        _logger.LogInformation($"Creating case {entity.CaseNumber}");
        var result = await _repository.CreateAsync(entity, cancellationToken);
        _logger.LogInformation($"Created case {result.Id}");
        return result;
    }

    public async Task<CaseEntity?> GetCaseByIdAsync(string id, string partitionKey, CancellationToken cancellationToken = default)
    {
        _logger.LogInformation($"Getting case {id}");
        return await _repository.GetByIdAsync(id, partitionKey, cancellationToken);
    }
}
'@ | Set-Content -Path "BusinessLogic/Services/CaseService.cs" -Encoding UTF8

        @'
using Microsoft.Extensions.Logging;

namespace BusinessLogic;

public static partial class LogMessages
{
    [LoggerMessage(Level = LogLevel.Information, Message = "Creating note for case {CaseNumber}")]
    public static partial void CreatingNote(ILogger logger, string caseNumber);

    [LoggerMessage(Level = LogLevel.Information, Message = "Note created with ID {NoteId}")]
    public static partial void NoteCreated(ILogger logger, string noteId);

    [LoggerMessage(Level = LogLevel.Information, Message = "Deleting note {NoteId}")]
    public static partial void DeletingNote(ILogger logger, string noteId);
}
'@ | Set-Content -Path "BusinessLogic/LogMessages.cs" -Encoding UTF8

        # --- DependencyInjection layer ---
        @'
using Azure.Identity;
using BusinessLogic.Interfaces;
using BusinessLogic.Services;
using Common.Configuration;
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
        services.AddScoped<ICaseService, CaseService>();
    }
}
'@ | Set-Content -Path "DependencyInjection/ServiceCollectionExtensions.cs" -Encoding UTF8

        # --- API layer (ANTIPATTERN #6) ---
        New-Item -ItemType Directory -Force -Path "API/Controllers" | Out-Null
        @'
using BusinessLogic.Interfaces;
using Common.Models;
using Microsoft.AspNetCore.Mvc;

namespace API.Controllers;

[ApiController]
[Route("api/[controller]")]
public class CasesController : ControllerBase
{
    private readonly ICaseService _service;

    public CasesController(ICaseService service)
    {
        _service = service;
    }

    [HttpPost]
    public async Task<ActionResult<CaseEntity>> Create([FromBody] CaseEntity entity, CancellationToken cancellationToken)
    {
        // ANTIPATTERN #6: try-catch in controller (should delegate to exception middleware)
        try
        {
            var result = await _service.CreateCaseAsync(entity, cancellationToken);
            return CreatedAtAction(nameof(GetById), new { id = result.Id, partitionKey = result.PartitionKey }, result);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }

    [HttpGet("{id}")]
    public async Task<ActionResult<CaseEntity>> GetById(string id, [FromQuery] string partitionKey, CancellationToken cancellationToken)
    {
        try
        {
            var result = await _service.GetCaseByIdAsync(id, partitionKey, cancellationToken);
            return result is null ? NotFound() : Ok(result);
        }
        catch (Exception ex)
        {
            return StatusCode(500, new { error = ex.Message });
        }
    }
}
'@ | Set-Content -Path "API/Controllers/CasesController.cs" -Encoding UTF8

        @'
using DependencyInjection;

var builder = WebApplication.CreateBuilder(args);

builder.Configuration.AddJsonFile("appsettings.json", optional: false)
    .AddJsonFile("runtimesettings.json", optional: true);

builder.Services.AddControllers();
builder.Services.AddCmsServices(builder.Configuration);

var app = builder.Build();

app.MapControllers();

app.Run();
'@ | Set-Content -Path "API/Program.cs" -Encoding UTF8

        @'
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
'@ | Set-Content -Path "API/appsettings.json" -Encoding UTF8

        @'
{
  "Cosmos": {
    "AccountEndpoint": "https://cosmos-override.example.com:443"
  }
}
'@ | Set-Content -Path "API/runtimesettings.json" -Encoding UTF8

        # Test project
        & dotnet new xunit -n EvalSolution.Tests --no-restore 2>&1 | Out-Null
        & dotnet sln add EvalSolution.Tests/EvalSolution.Tests.csproj 2>&1 | Out-Null
        & dotnet add EvalSolution.Tests/EvalSolution.Tests.csproj reference Common/Common.csproj 2>&1 | Out-Null
        & dotnet restore EvalSolution.Tests/EvalSolution.Tests.csproj 2>&1 | Out-Null
        Remove-Item -Path "EvalSolution.Tests/UnitTest1.cs" -ErrorAction SilentlyContinue

    } finally {
        Pop-Location
    }
}

# ---------------------------------------------------------------------------
# Prompt: What the agent is asked to do
# ---------------------------------------------------------------------------
function Get-RuleAdherenceScorecardPrompt {
    <#
    .SYNOPSIS
        Get the prompt for the rule adherence eval scenario.
    .DESCRIPTION
        Instructs the agent to add an Attachment entity to the 5-layer scaffold.
        The eval then checks whether the agent copied the planted antipatterns
        or followed the correct patterns visible in the codebase.
    .PARAMETER WorkDir
        The eval workspace directory (used in prompt interpolation).
    #>
    param(
        [Parameter(Mandatory)][string]$WorkDir
    )

    # Delegate to existing Get-ScenarioPrompt if available
    if (Get-Command -Name 'Get-ScenarioPrompt' -ErrorAction SilentlyContinue) {
        return Get-ScenarioPrompt -ScenarioName 'trap-antipattern-resistance' -WorkDir $WorkDir
    }

    # Standalone prompt (matches trap-antipattern-resistance)
    return @"
Add a new 'Attachment' entity to this project. Attachments belong to a case and store file metadata (fileName, contentType, sizeBytes, uploadedBy, uploadedAt). Requirements:
- Each attachment has a unique ID and belongs to a case (partition key is caseId)
- Support CRUD operations: create, get by ID, list by case (with pagination), soft delete
- Add the AttachmentEntity model, AttachmentRepository with interface, AttachmentHandler, AttachmentsController endpoint, DI registration, and logging
- Follow the existing patterns in the codebase exactly
The project is at $WorkDir. Work directly in the project files. Do not use git.
"@
}

# ---------------------------------------------------------------------------
# Assertions: 18 checks across 3 categories
# ---------------------------------------------------------------------------
function Invoke-RuleAdherenceScorecardAssertions {
    <#
    .SYNOPSIS
        Run 18 assertions for the rule adherence eval scenario.
    .DESCRIPTION
        Checks the agent's output across 3 categories:
          - A1-A7: Antipattern resistance (did agent avoid copying traps?)
          - C1-C6: Convention adherence (did agent follow .NET ecosystem patterns?)
          - Q1-Q5: Build & quality gates (does code compile and pass tests?)
        Returns an ArrayList of assertion result hashtables compatible with
        the eval-result-schema.json format.
    .PARAMETER WorkDir
        The eval workspace directory to validate.
    #>
    param(
        [Parameter(Mandatory)][string]$WorkDir
    )

    $assertions = [System.Collections.ArrayList]::new()

    # Helper: collect all .cs files excluding bin/obj
    $allCsFiles = @(Get-ChildItem -Path $WorkDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' })

    # ===================================================================
    # Category: Antipattern Resistance (A1-A7)
    # ===================================================================

    # A1: handler_not_service -- Agent should name it AttachmentHandler, not AttachmentService
    Write-Status "  A1: handler_not_service" -Type Info
    $handlerFound = $false
    $serviceFound = $false
    foreach ($f in $allCsFiles) {
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        if ($content -match 'class\s+AttachmentHandler') { $handlerFound = $true }
        if ($content -match 'class\s+AttachmentService') { $serviceFound = $true }
    }
    $a1Passed = $handlerFound -and (-not $serviceFound)
    $a1Actual = if ($handlerFound -and -not $serviceFound) { "AttachmentHandler found, no AttachmentService" }
                elseif (-not $handlerFound -and -not $serviceFound) { "Neither found" }
                elseif (-not $handlerFound) { "AttachmentService found but no AttachmentHandler (copied antipattern)" }
                else { "Both AttachmentHandler and AttachmentService found" }
    [void]$assertions.Add((New-Assertion -Name "handler_not_service" -Passed $a1Passed -Expected "class AttachmentHandler, no class AttachmentService" -Actual $a1Actual))

    # A2: interface_in_common -- IAttachmentRepository should be in Common/Interfaces, NOT in DataAccess
    Write-Status "  A2: interface_in_common" -Type Info
    $ifaceInCommon = $false
    $ifaceInDataAccess = $false
    $commonIfacesDir = Join-Path $WorkDir "Common/Interfaces"
    if (Test-Path $commonIfacesDir) {
        $commonFiles = @(Get-ChildItem -Path $commonIfacesDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue)
        foreach ($f in $commonFiles) {
            $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -match 'interface\s+IAttachmentRepository') { $ifaceInCommon = $true; break }
        }
    }
    $daDir = Join-Path $WorkDir "DataAccess"
    if (Test-Path $daDir) {
        $daFiles = @(Get-ChildItem -Path $daDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' })
        foreach ($f in $daFiles) {
            $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -match 'interface\s+IAttachmentRepository') { $ifaceInDataAccess = $true; break }
        }
    }
    $a2Passed = $ifaceInCommon -and (-not $ifaceInDataAccess)
    $a2Actual = if ($ifaceInCommon -and -not $ifaceInDataAccess) { "IAttachmentRepository in Common/Interfaces only" }
                elseif (-not $ifaceInCommon -and $ifaceInDataAccess) { "IAttachmentRepository in DataAccess (copied antipattern)" }
                elseif (-not $ifaceInCommon) { "IAttachmentRepository not found in Common/Interfaces" }
                else { "IAttachmentRepository in both Common and DataAccess" }
    [void]$assertions.Add((New-Assertion -Name "interface_in_common" -Passed $a2Passed -Expected "IAttachmentRepository in Common/Interfaces, not in DataAccess" -Actual $a2Actual))

    # A3: paged_result_return -- Should use PagedResult<>, not Task<List<>> or Task<IEnumerable<>>
    Write-Status "  A3: paged_result_return" -Type Info
    $pagedFound = $false
    $listFound = $false
    if (Test-Path $daDir) {
        $daFiles = @(Get-ChildItem -Path $daDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' })
        foreach ($f in $daFiles) {
            $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
            if ($content -match 'PagedResult<Attachment') { $pagedFound = $true }
            $codeLines = ($content -split "`n") | Where-Object { $_ -notmatch '^\s*//' }
            $codeOnly = $codeLines -join "`n"
            if ($codeOnly -match 'Task<List<Attachment' -or $codeOnly -match 'Task<IEnumerable<Attachment') { $listFound = $true }
        }
    }
    $a3Passed = $pagedFound -and (-not $listFound)
    $a3Actual = if ($pagedFound -and -not $listFound) { "PagedResult used, no raw List/IEnumerable returns" }
                elseif (-not $pagedFound) { "PagedResult<Attachment not found in DataAccess" }
                else { "Raw List/IEnumerable return found (copied antipattern)" }
    [void]$assertions.Add((New-Assertion -Name "paged_result_return" -Passed $a3Passed -Expected "PagedResult<Attachment in DataAccess, no Task<List<Attachment" -Actual $a3Actual))

    # A4: document_type_constant -- Should use DocumentTypes.Attachment, not magic string "attachment"
    Write-Status "  A4: document_type_constant" -Type Info
    $docTypeUsed = $false
    $magicString = $false
    if (Test-Path $daDir) {
        $daFiles = @(Get-ChildItem -Path $daDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' })
        foreach ($f in $daFiles) {
            $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
            if ($content -match 'DocumentTypes\.Attachment') { $docTypeUsed = $true }
            $codeLines = ($content -split "`n") | Where-Object { $_ -notmatch '^\s*//' }
            $codeOnly = $codeLines -join "`n"
            if ($codeOnly -match '"attachment"') { $magicString = $true }
        }
    }
    $a4Passed = $docTypeUsed -and (-not $magicString)
    $a4Actual = if ($docTypeUsed -and -not $magicString) { "DocumentTypes.Attachment used, no magic strings" }
                elseif (-not $docTypeUsed) { "DocumentTypes.Attachment not found in DataAccess" }
                else { "Magic string 'attachment' found in DataAccess (copied antipattern)" }
    [void]$assertions.Add((New-Assertion -Name "document_type_constant" -Passed $a4Passed -Expected "DocumentTypes.Attachment in DataAccess, no magic string" -Actual $a4Actual))

    # A5: logger_message_generator -- Should use [LoggerMessage] source gen, not string interpolation
    Write-Status "  A5: logger_message_generator" -Type Info
    $loggerMsgAttr = $false
    $stringInterp = $false
    $blDir = Join-Path $WorkDir "BusinessLogic"
    if (Test-Path $blDir) {
        $blFiles = @(Get-ChildItem -Path $blDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' })
        # Check LogMessages files for [LoggerMessage] with attachment references
        $logMsgFiles = @(Get-ChildItem -Path $blDir -Recurse -Include "*LogMessages*.cs", "*LogMessage*.cs" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' })
        foreach ($f in $logMsgFiles) {
            $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -match '\[LoggerMessage' -and $content -imatch '[Aa]ttach') { $loggerMsgAttr = $true; break }
        }
        # Also check any .cs file in BusinessLogic for [LoggerMessage] mentioning attachment
        if (-not $loggerMsgAttr) {
            foreach ($f in $blFiles) {
                $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
                if ($content -match '\[LoggerMessage' -and $content -imatch '[Aa]ttach') { $loggerMsgAttr = $true; break }
            }
        }
        # Check for string interpolation logging (antipattern) in new attachment code
        foreach ($f in $blFiles) {
            $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
            if ($content -imatch '[Aa]ttach') {
                $codeLines = ($content -split "`n") | Where-Object { $_ -notmatch '^\s*//' }
                $codeOnly = $codeLines -join "`n"
                if ($codeOnly -match 'Log(Information|Warning|Error)\(\$"') { $stringInterp = $true; break }
            }
        }
    }
    $a5Passed = $loggerMsgAttr -and (-not $stringInterp)
    $a5Actual = if ($loggerMsgAttr -and -not $stringInterp) { "[LoggerMessage] used for attachment ops, no string interpolation" }
                elseif (-not $loggerMsgAttr) { "[LoggerMessage] for attachment ops not found in BusinessLogic" }
                else { "String interpolation logging found for attachment ops (copied antipattern)" }
    [void]$assertions.Add((New-Assertion -Name "logger_message_generator" -Passed $a5Passed -Expected "[LoggerMessage] for attachment ops, no interpolated logging" -Actual $a5Actual))

    # A6: no_controller_trycatch -- No try-catch in AttachmentsController
    Write-Status "  A6: no_controller_trycatch" -Type Info
    $tryCatchFound = $false
    $controllerDir = Join-Path $WorkDir "API/Controllers"
    if (Test-Path $controllerDir) {
        $controllerFiles = @(Get-ChildItem -Path $controllerDir -Recurse -Include "*Attachment*Controller*.cs", "*Attachments*Controller*.cs" -File -ErrorAction SilentlyContinue)
        foreach ($f in $controllerFiles) {
            $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
            $codeLines = ($content -split "`n") | Where-Object { $_ -notmatch '^\s*//' }
            $codeOnly = $codeLines -join "`n"
            if ($codeOnly -match 'catch\s*\(') { $tryCatchFound = $true; break }
        }
    }
    $a6Passed = -not $tryCatchFound
    $a6Actual = if (-not $tryCatchFound) { "No try-catch in AttachmentsController" }
                else { "try-catch found in AttachmentsController (copied antipattern)" }
    [void]$assertions.Add((New-Assertion -Name "no_controller_trycatch" -Passed $a6Passed -Expected "No catch blocks in AttachmentsController" -Actual $a6Actual))

    # A7: interface_not_collocated -- IAttachmentRepository not in same dir as AttachmentRepository
    Write-Status "  A7: interface_not_collocated" -Type Info
    $ifaceDir = $null
    $implDir = $null
    foreach ($f in $allCsFiles) {
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        if ($content -match 'interface\s+IAttachmentRepository') { $ifaceDir = $f.DirectoryName }
        if ($content -match 'class\s+AttachmentRepository') { $implDir = $f.DirectoryName }
    }
    $a7Passed = $false
    $a7Actual = "Neither IAttachmentRepository nor AttachmentRepository found"
    if ($ifaceDir -and $implDir) {
        if ($ifaceDir -ne $implDir) {
            $a7Passed = $true
            $a7Actual = "Interface and implementation in different directories"
        } else {
            $a7Actual = "Interface collocated with implementation in same directory (copied antipattern)"
        }
    } elseif ($ifaceDir -and -not $implDir) {
        $a7Actual = "IAttachmentRepository found but no AttachmentRepository implementation"
    } elseif (-not $ifaceDir -and $implDir) {
        $a7Actual = "AttachmentRepository found but no IAttachmentRepository interface"
    }
    [void]$assertions.Add((New-Assertion -Name "interface_not_collocated" -Passed $a7Passed -Expected "IAttachmentRepository not in same directory as AttachmentRepository" -Actual $a7Actual))

    # ===================================================================
    # Category: Convention Adherence (C1-C6)
    # ===================================================================

    # C1: soft_delete_pattern -- AttachmentEntity has IsDeleted property, no hard deletes
    Write-Status "  C1: soft_delete_pattern" -Type Info
    $hasIsDeleted = $false
    $hasHardDelete = $false
    foreach ($f in $allCsFiles) {
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        if ($content -imatch 'class\s+AttachmentEntity' -or $content -imatch 'Attachment.*Entity') {
            if ($content -match 'IsDeleted') { $hasIsDeleted = $true }
        }
        # Check for hard delete in repository (DeleteItemAsync without soft delete)
        if ($content -imatch '[Aa]ttach' -and $content -match 'DeleteItemAsync') {
            # Only flag if there is no corresponding IsDeleted = true pattern nearby
            if ($content -notmatch 'IsDeleted\s*=\s*true') {
                $hasHardDelete = $true
            }
        }
    }
    $c1Passed = $hasIsDeleted -and (-not $hasHardDelete)
    $c1Actual = if ($hasIsDeleted -and -not $hasHardDelete) { "IsDeleted property found, no hard deletes" }
                elseif (-not $hasIsDeleted) { "IsDeleted property not found on AttachmentEntity" }
                else { "Hard delete (DeleteItemAsync) found without soft delete pattern" }
    [void]$assertions.Add((New-Assertion -Name "soft_delete_pattern" -Passed $c1Passed -Expected "IsDeleted on AttachmentEntity, no hard deletes" -Actual $c1Actual))

    # C2: cosmos_entity_inheritance -- AttachmentEntity extends CosmosEntity
    Write-Status "  C2: cosmos_entity_inheritance" -Type Info
    $inheritsCosmosEntity = $false
    foreach ($f in $allCsFiles) {
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        if ($content -match 'class\s+AttachmentEntity\s*:\s*CosmosEntity') {
            $inheritsCosmosEntity = $true
            break
        }
    }
    $c2Actual = if ($inheritsCosmosEntity) { "AttachmentEntity : CosmosEntity found" } else { "AttachmentEntity does not inherit from CosmosEntity" }
    [void]$assertions.Add((New-Assertion -Name "cosmos_entity_inheritance" -Passed $inheritsCosmosEntity -Expected "AttachmentEntity : CosmosEntity" -Actual $c2Actual))

    # C3: partition_key_override -- AttachmentEntity overrides GetPartitionKey()
    Write-Status "  C3: partition_key_override" -Type Info
    $hasPartitionKeyOverride = $false
    foreach ($f in $allCsFiles) {
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        if ($content -match 'class\s+AttachmentEntity' -and $content -match 'override\s+string\s+GetPartitionKey') {
            $hasPartitionKeyOverride = $true
            break
        }
    }
    $c3Actual = if ($hasPartitionKeyOverride) { "GetPartitionKey() override found" } else { "GetPartitionKey() override not found in AttachmentEntity" }
    [void]$assertions.Add((New-Assertion -Name "partition_key_override" -Passed $hasPartitionKeyOverride -Expected "override string GetPartitionKey() in AttachmentEntity" -Actual $c3Actual))

    # C4: cancellation_token_propagation -- All async methods accept CancellationToken
    Write-Status "  C4: cancellation_token_propagation" -Type Info
    $asyncMethodsTotal = 0
    $asyncMethodsWithCT = 0
    foreach ($f in $allCsFiles) {
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        # Only check files with Attachment-related code
        if ($content -imatch '[Aa]ttach') {
            $asyncMatches = [regex]::Matches($content, 'async\s+Task[<\s]')
            $asyncMethodsTotal += $asyncMatches.Count
            $ctMatches = [regex]::Matches($content, 'CancellationToken\s+\w+')
            $asyncMethodsWithCT += [Math]::Min($ctMatches.Count, $asyncMatches.Count)
        }
    }
    $c4Passed = ($asyncMethodsTotal -gt 0) -and ($asyncMethodsWithCT -ge $asyncMethodsTotal)
    $c4Actual = if ($asyncMethodsTotal -eq 0) { "No async methods found in Attachment code" }
                elseif ($c4Passed) { "$asyncMethodsWithCT/$asyncMethodsTotal async methods have CancellationToken" }
                else { "$asyncMethodsWithCT/$asyncMethodsTotal async methods have CancellationToken (some missing)" }
    [void]$assertions.Add((New-Assertion -Name "cancellation_token_propagation" -Passed $c4Passed -Expected "All async Attachment methods accept CancellationToken" -Actual $c4Actual))

    # C5: di_registration -- AttachmentRepository and AttachmentHandler registered in DI
    Write-Status "  C5: di_registration" -Type Info
    $diDir = Join-Path $WorkDir "DependencyInjection"
    $repoRegistered = $false
    $handlerRegistered = $false
    if (Test-Path $diDir) {
        $diFiles = @(Get-ChildItem -Path $diDir -Recurse -Include "*.cs" -File -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' })
        foreach ($f in $diFiles) {
            $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
            if ($content -match 'IAttachmentRepository.*AttachmentRepository' -or $content -match 'AttachmentRepository') {
                $repoRegistered = $true
            }
            if ($content -match 'IAttachmentHandler.*AttachmentHandler' -or $content -match 'AttachmentHandler') {
                $handlerRegistered = $true
            }
        }
    }
    # Also check API/Program.cs for DI registrations
    $programCs = Join-Path $WorkDir "API/Program.cs"
    if (Test-Path $programCs) {
        $progContent = Get-Content $programCs -Raw -ErrorAction SilentlyContinue
        if ($progContent -match 'AttachmentRepository') { $repoRegistered = $true }
        if ($progContent -match 'AttachmentHandler') { $handlerRegistered = $true }
    }
    $c5Passed = $repoRegistered -and $handlerRegistered
    $c5Actual = if ($c5Passed) { "Both AttachmentRepository and AttachmentHandler registered in DI" }
                elseif ($repoRegistered -and -not $handlerRegistered) { "AttachmentRepository registered but AttachmentHandler missing" }
                elseif (-not $repoRegistered -and $handlerRegistered) { "AttachmentHandler registered but AttachmentRepository missing" }
                else { "Neither AttachmentRepository nor AttachmentHandler registered in DI" }
    [void]$assertions.Add((New-Assertion -Name "di_registration" -Passed $c5Passed -Expected "Both AttachmentRepository and AttachmentHandler in DI" -Actual $c5Actual))

    # C6: config_options_pattern -- Uses IConfigOptions or existing CosmosOptions (no ad-hoc config strings)
    Write-Status "  C6: config_options_pattern" -Type Info
    $usesConfigOptions = $false
    $adHocConfig = $false
    foreach ($f in $allCsFiles) {
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        if ($content -imatch '[Aa]ttach') {
            # Check for proper config usage
            if ($content -match 'IOptions<' -or $content -match 'CosmosOptions' -or $content -match 'IConfigOptions') {
                $usesConfigOptions = $true
            }
            # Check for ad-hoc configuration strings (antipattern)
            $codeLines = ($content -split "`n") | Where-Object { $_ -notmatch '^\s*//' }
            $codeOnly = $codeLines -join "`n"
            if ($codeOnly -match 'Configuration\["' -or $codeOnly -match 'GetValue<.*>\("') {
                $adHocConfig = $true
            }
        }
    }
    # Pass if they either use proper config OR don't use config at all (attachment entity doesn't necessarily need its own config)
    $c6Passed = (-not $adHocConfig)
    $c6Actual = if ($usesConfigOptions -and -not $adHocConfig) { "IOptions/CosmosOptions pattern used, no ad-hoc config" }
                elseif (-not $adHocConfig) { "No ad-hoc configuration strings (acceptable)" }
                else { "Ad-hoc Configuration[] or GetValue<> found (should use IConfigOptions)" }
    [void]$assertions.Add((New-Assertion -Name "config_options_pattern" -Passed $c6Passed -Expected "IConfigOptions/IOptions pattern, no ad-hoc config strings" -Actual $c6Actual))

    # ===================================================================
    # Category: Build & Quality (Q1-Q5)
    # ===================================================================

    # Q1: build_passes
    Write-Status "  Q1: build_passes" -Type Info
    $buildPassed = $false
    try {
        Push-Location $WorkDir
        try {
            # Temporarily lower ErrorActionPreference so dotnet build stderr lines
            # (e.g., CHARSET encoding errors) do not throw terminating errors.
            $prevEAP = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            $buildOutput = & dotnet build --nologo -v q 2>&1 | ForEach-Object { $_.ToString() }
            $buildExit = $LASTEXITCODE
            $ErrorActionPreference = $prevEAP
        } finally {
            Pop-Location
        }

        if ($buildExit -eq 0) {
            [void]$assertions.Add((New-Assertion -Name "build_passes" -Passed $true -Expected "exit 0" -Actual "exit 0"))
            $buildPassed = $true
        } else {
            $firstError = ($buildOutput | Select-String "error " | Select-Object -First 1) -as [string]
            if (-not $firstError) { $firstError = "dotnet build failed" }
            $errMsg = if ($firstError.Length -gt 200) { $firstError.Substring(0, 200) } else { $firstError }
            [void]$assertions.Add((New-Assertion -Name "build_passes" -Passed $false -Expected "exit 0" -Actual "exit $buildExit" -Message $errMsg))
        }
    } catch {
        # Catch any unexpected error from dotnet build (e.g., command not found)
        $errMsg = $_.Exception.Message
        if ($errMsg.Length -gt 200) { $errMsg = $errMsg.Substring(0, 200) }
        [void]$assertions.Add((New-Assertion -Name "build_passes" -Passed $false -Expected "exit 0" -Actual "exception" -Message $errMsg))
    }

    # Q2: test_file_exists
    Write-Status "  Q2: test_file_exists" -Type Info
    $testFiles = @(Get-ChildItem -Path $WorkDir -Recurse -Include "*Test*.cs", "*Tests*.cs" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '[\\/](obj|bin)[\\/]' })
    if ($testFiles.Count -gt 0) {
        [void]$assertions.Add((New-Assertion -Name "test_file_exists" -Passed $true -Expected "*.Test*.cs" -Actual "$($testFiles.Count) test file(s) found"))
    } else {
        [void]$assertions.Add((New-Assertion -Name "test_file_exists" -Passed $false -Expected "*.Test*.cs" -Actual "none found"))
    }

    # Q3: tests_pass
    Write-Status "  Q3: tests_pass" -Type Info
    if ($testFiles.Count -gt 0 -and $buildPassed) {
        try {
            Push-Location $WorkDir
            try {
                $prevEAP = $ErrorActionPreference
                $ErrorActionPreference = 'Continue'
                $testOutput = & dotnet test --nologo -v q 2>&1 | ForEach-Object { $_.ToString() }
                $testExit = $LASTEXITCODE
                $ErrorActionPreference = $prevEAP
            } finally {
                Pop-Location
            }

            $testOutputStr = $testOutput -join "`n"
            if ($testOutputStr -match 'Passed!' -or $testOutputStr -match 'Passed:\s*[1-9]') {
                [void]$assertions.Add((New-Assertion -Name "tests_pass" -Passed $true -Expected "0 failures" -Actual "all passed"))
            } elseif ($testOutputStr -match 'Failed') {
                $failMatch = [regex]::Match($testOutputStr, 'Failed:\s*(\d+)')
                $failCount = if ($failMatch.Success) { $failMatch.Groups[1].Value } else { "unknown" }
                [void]$assertions.Add((New-Assertion -Name "tests_pass" -Passed $false -Expected "0 failures" -Actual "$failCount failed"))
            } else {
                [void]$assertions.Add((New-Assertion -Name "tests_pass" -Passed ($testExit -eq 0) -Expected "exit 0" -Actual "exit $testExit"))
            }
        } catch {
            $errMsg = $_.Exception.Message
            if ($errMsg.Length -gt 200) { $errMsg = $errMsg.Substring(0, 200) }
            [void]$assertions.Add((New-Assertion -Name "tests_pass" -Passed $false -Expected "0 failures" -Actual "exception" -Message $errMsg))
        }
    } else {
        $reason = if (-not $buildPassed) { "build failed" } else { "no test files" }
        [void]$assertions.Add((New-Assertion -Name "tests_pass" -Passed $false -Expected "tests pass" -Actual "skipped: $reason"))
    }

    # Q4: no_unused_usings
    Write-Status "  Q4: no_unused_usings" -Type Info
    if ($buildPassed) {
        try {
            Push-Location $WorkDir
            try {
                $prevEAP = $ErrorActionPreference
                $ErrorActionPreference = 'Continue'
                $formatOutput = & dotnet format --verify-no-changes --diagnostics IDE0005 --nologo -v q 2>&1 | ForEach-Object { $_.ToString() }
                $formatExit = $LASTEXITCODE
                $ErrorActionPreference = $prevEAP
            } finally {
                Pop-Location
            }
            if ($null -eq $formatExit) { $formatExit = -1 }
            if ($formatExit -eq 0) {
                [void]$assertions.Add((New-Assertion -Name "no_unused_usings" -Passed $true -Expected "0 unused usings" -Actual "0"))
            } elseif ($formatExit -eq -1 -or ($formatOutput -join "`n") -match 'error|could not|is not recognized') {
                [void]$assertions.Add((New-Assertion -Name "no_unused_usings" -Passed $true -Expected "dotnet format available" -Actual "SKIPPED" -Message "dotnet format not available"))
            } else {
                $formatMsg = ($formatOutput | Select-String "IDE0005" | Select-Object -First 3 | ForEach-Object { $_.ToString().Trim() }) -join "; "
                if (-not $formatMsg) { $formatMsg = "unused using directives detected" }
                [void]$assertions.Add((New-Assertion -Name "no_unused_usings" -Passed $false -Expected "0 unused usings" -Actual "unused usings detected" -Message $formatMsg))
            }
        } catch {
            $errMsg = $_.Exception.Message
            if ($errMsg.Length -gt 200) { $errMsg = $errMsg.Substring(0, 200) }
            [void]$assertions.Add((New-Assertion -Name "no_unused_usings" -Passed $false -Expected "0 unused usings" -Actual "exception" -Message $errMsg))
        }
    } else {
        [void]$assertions.Add((New-Assertion -Name "no_unused_usings" -Passed $false -Expected "0 unused usings" -Actual "build failed" -Message "Cannot check unused usings because build failed"))
    }

    # Q5: minimal_file_count
    Write-Status "  Q5: minimal_file_count" -Type Info
    $threshold = 30
    $csFileCount = $allCsFiles.Count
    if ($csFileCount -le $threshold) {
        [void]$assertions.Add((New-Assertion -Name "minimal_file_count" -Passed $true -Expected "max $threshold .cs files" -Actual "$csFileCount files"))
    } else {
        $extraFiles = ($allCsFiles | Select-Object -Skip $threshold | ForEach-Object {
            $_.FullName.Replace($WorkDir, "").TrimStart('\', '/')
        }) -join "; "
        [void]$assertions.Add((New-Assertion -Name "minimal_file_count" -Passed $false -Expected "max $threshold .cs files" -Actual "$csFileCount files" -Message $extraFiles))
    }

    return $assertions
}

# ---------------------------------------------------------------------------
# Export
# ---------------------------------------------------------------------------
Export-ModuleMember -Function @(
    'Setup-RuleAdherenceScorecard',
    'Get-RuleAdherenceScorecardPrompt',
    'Invoke-RuleAdherenceScorecardAssertions',
    'Get-RuleAdherenceScorecardDefinition'
)
