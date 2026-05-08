---
name: lens-aspnet-structure
description: >
  Use this skill when creating or reviewing the structure of a LENS ASP.NET Core service.
  Apply when scaffolding a new LENS service, adding a new layer (API, BusinessLogic, DataAccess,
  Common, DependencyInjection), implementing a handler or repository, wiring DI
  registrations, setting up configuration validation, or answering questions about dependency
  rules, layer boundaries, or project structure in a LENS .NET backend. Also apply when
  reviewing code for layer violations such as business logic in controllers, API layer
  referencing DataAccess directly, or missing ParameterContracts in constructors.
license: private
compatibility: Designed for LENS ASP.NET Core services (.NET/C#). Best used in a LENS service repository with access to C# source files.
version: 1.0.0
metadata:
  version: "1.0.0"
  author: jacote@microsoft.com
  release_date: "2026-04-24"
allowed-tools:
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Bash
# scaffolder/reference, not a reviewer; cross-model verification fires at the consuming reviewer skill
tier-exempt: [multi-pass]
user-invocable: true
---

<!-- TODO(iter1-F1): synced from LENS-Common PR 5158460 branch u/jacote/lens-aspnet-structure-skill commit 78adb49027e3ed89dbc8cdc6fd1db423b21c48c8. Refresh after merge via `git -C references/LENS-Common show origin/master:"sources/plugins/LENS/Common/Project Patterns/lens-aspnet-structure/skills/lens-aspnet-structure/SKILL.md" > .claude/skills/lens-aspnet-structure/SKILL.md`. -->

# LENS ASP.NET Core Service Structure

Enforce strict dependency boundaries and consistent patterns across all LENS ASP.NET Core services.

> **Meta-rule — conventions are defaults, deviations are discussions.**
> Every standard here is the default. If a rule creates a genuinely worse outcome in your context, raise it as a discussion before deviating — never silently work around it.

> **Coming from standard ASP.NET Core?** See [references/aspnet-mapping.md](references/aspnet-mapping.md) for a direct mapping from familiar patterns (`XxxService`, `IRepository`, `Program.cs` wiring) to their LENS equivalents and the reasoning behind each naming choice.

---

## Standard 1: The Layer Model

**Rule:** LENS services are structured in five layers with strict, unidirectional dependency rules. No layer may skip a level. No circular dependencies are permitted.

```
API  →  BusinessLogic  →  DataAccess  →  Common
DependencyInjection → all four layers above
```

### Dependency Matrix

| Layer | May reference |
|-------|--------------|
| `API` | `BusinessLogic`, `Common`, `DependencyInjection` |
| `BusinessLogic` | `DataAccess`, `Common` |
| `DataAccess` | `Common` |
| `Common` | Nothing — zero internal project dependencies |
| `DependencyInjection` | All four layers — it is the only place that sees all concretions simultaneously |

### Layer Responsibilities (one line each)

| Layer | Responsibility |
|-------|---------------|
| `API` | HTTP surface: thin controllers, request/response models, DataAnnotations, auth middleware |
| `BusinessLogic` | All business rules, implemented via the Handler pattern; throws typed `HandlerException` subclasses |
| `DataAccess` | Data operations only; repository interfaces and their concrete implementations |
| `Common` | Shared models, constants, configuration classes, utilities; only `Microsoft.LENS.Common.*` NuGet packages permitted |
| `DependencyInjection` | Maps interfaces to implementations; single public entry point per service |

> Full folder trees and namespace conventions: [references/layer-responsibilities.md](references/layer-responsibilities.md)

---

## Standard 2: API Layer — Thin Controllers

**Rule:** Controllers do exactly four things: extract identity/request data, call one handler method, map the domain result to a presentation type, and catch typed handler exceptions to map them to HTTP responses. Zero business logic. Zero direct DataAccess references.

```csharp
// ✅ GOOD — thin controller with explicit presentation mapping
[ApiController]
[Route("api/v1/[controller]")]
[Authorize(Policy = "ApplicationAuthorizationPolicy")]
public sealed class FooController : ControllerBase
{
    private readonly IFooHandler fooHandler;
    private readonly IPresentationModelFactory presentationFactory;
    private readonly ILogger<FooController> logger;

    public FooController(
        IFooHandler fooHandler,
        IPresentationModelFactory presentationFactory,
        ILogger<FooController> logger)
    {
        ParameterContracts.CheckIsNotNull(fooHandler, nameof(fooHandler));
        ParameterContracts.CheckIsNotNull(presentationFactory, nameof(presentationFactory));
        ParameterContracts.CheckIsNotNull(logger, nameof(logger));
        this.fooHandler = fooHandler;
        this.presentationFactory = presentationFactory;
        this.logger = logger;
    }

    [HttpGet("{fooId}")]
    public async Task<IActionResult> GetFooAsync(Guid fooId)
    {
        try
        {
            // Handler returns a Common domain type
            var foo = await this.fooHandler.GetFooAsync(this.tenantId, fooId);
            // Factory maps it to the API presentation type before serialising
            return Ok(this.presentationFactory.GetFooResponse(foo));
        }
        catch (FooNotFoundException ex)
        {
            RequestContextItems.ErrorCode.SetItem(this.appContext.RequestContext, ErrorCodes.FooNotFound);
            return NotFound(new { error = ex.Message });
        }
        catch (FooDataAccessException ex) when (ex.RetryAfter.HasValue)
        {
            Response.Headers[HeaderNames.RetryAfter] = DateTime.UtcNow.Add(ex.RetryAfter.Value).ToString("R");
            RequestContextItems.ErrorCode.SetItem(this.appContext.RequestContext, ErrorCodes.FooRateLimited);
            return StatusCode(429);
        }
        catch (FooDataAccessException)
        {
            RequestContextItems.ErrorCode.SetItem(this.appContext.RequestContext, ErrorCodes.FooDataAccessError);
            return StatusCode(503);
        }
        // Anything not caught here bubbles to GlobalErrorHandlingMiddleware → 500
    }
}

// ❌ BAD — returning the domain type directly over HTTP
var foo = await this.fooHandler.GetFooAsync(this.tenantId, fooId);
return Ok(foo); // ← leaks internal domain type as the HTTP contract

// ❌ BAD — direct DataAccess call; missing the handler and presentation layers
var foo = await this.dataStore.GetFooAsync(this.tenantId, fooId);
return Ok(foo);
```

**API Layer rules:**
- All constructors use `ParameterContracts.CheckIsNotNull` — never `ArgumentNullException` directly
- Inbound request types live in `API/Presentation/` and carry DataAnnotations attributes (`[Required]`, `[MaxLength]`, `[Range]`, etc.)
- ASP.NET Core validates annotated models automatically; a failed model state returns HTTP 400 before the controller action executes
- Handlers return Common domain types — controllers always map these to a presentation type before returning an HTTP response
- The presentation type is the external contract; domain types from Common are internal and must not be serialised directly to callers
- `PresentationModelFactory` (or equivalent extension methods) in the API layer owns all mappings from domain types to presentation types
- Types from `Microsoft.LENS.Common.DataModels` (or any cross-service LENS contract package) are **inter-service presentation models**. They appear at exactly two layer boundaries and nowhere else:
  - **API layer** — inbound inter-service requests; map to a local Common domain type before passing to the handler
  - **DataAccess layer** — outbound calls to other LENS services; DataAccess maps the local domain type to a DataModels request, calls the service, maps the DataModels response back to a local domain type, and returns that to the handler
  - **BusinessLogic must never see DataModels types** — the handler always works with local Common domain types regardless of whether the data originated from HTTP or a LENS service call

> Validation attributes, configuration validation, and cross-property rules: [references/validation.md](references/validation.md)

---

## Standard 3: BusinessLogic Layer — Handler Pattern

**Rule:** All business rules live in handlers — never in controllers, never in repositories. Each domain area has one handler interface + one sealed implementation, with one async method per verb. Business rule violations throw typed `HandlerException` subclasses; DataAccess failures are caught, wrapped, and rethrown.

Each `HandlerException` subclass is a **sentinel for a unique failure scenario**. The controller's catch ladder is a deterministic routing table: one exception type → one catch clause → one HTTP response. This is what makes system behaviour predictable — every known failure has an explicit type and an explicit outcome; anything else is middleware → 500.

```csharp
// ✅ GOOD — handler interface (in BusinessLogic/Interfaces/)
// partitionId is a generic placeholder — name it after your entity's actual partition key (e.g. tenantId, customerId)
public interface IFooHandler
{
    Task<Foo> GetFooAsync(Guid partitionId, Guid fooId);
    Task<Foo> CreateFooAsync(Foo foo);  // entity carries its own partition key value
}

// ✅ GOOD — sealed handler implementation
public sealed class FooHandler : IFooHandler
{
    private readonly IFooRepository repository;
    private readonly ILogger<FooHandler> logger;

    public FooHandler(IFooRepository repository, ILogger<FooHandler> logger)
    {
        ParameterContracts.CheckIsNotNull(repository, nameof(repository));
        ParameterContracts.CheckIsNotNull(logger, nameof(logger));
        this.repository = repository;
        this.logger = logger;
    }

    public async Task<Foo> GetFooAsync(Guid partitionId, Guid fooId)
    {
        var foo = await this.repository.GetFooAsync(partitionId, fooId); // null for 404
        if (foo is null)
            throw new FooNotFoundException("Foo not found.");

        return foo;
    }

    public async Task<Foo> CreateFooAsync(Foo foo)
    {
        try
        {
            return await this.repository.CreateFooAsync(foo);
        }
        catch (DataStoreException ex)
        {
            throw new FooDataAccessException("Data access failed.", ex.RetryAfter, ex);
        }
    }
}
```

**BusinessLogic Layer rules:**
- All concrete implementations are `sealed`
- All constructors use `ParameterContracts`
- Each `HandlerException` subclass represents one unique failure scenario — create a new type when the controller needs a new routing outcome, not just to group failures by domain
- Business rule violations → throw the specific scenario-named `HandlerException` subclass (e.g. `FooNotFoundException`, `FooLockedForDeletionException`); no `HttpStatusCode` on the exception
- `DataStoreException` from DataAccess → catch, wrap into `FooDataAccessException`, pass `ex.RetryAfter` through as a neutral duration; the controller decides what to do with it
- Handlers do not catch-all — only the specific exception types they know how to wrap; everything else propagates

> Full handler pattern, exception hierarchy, and controller catch patterns: [references/handler-pattern.md](references/handler-pattern.md)
> Exception flow, middleware behaviour, and status code mapping: [references/exception-handling-reference.md](references/exception-handling-reference.md)

---

## Standard 4: DataAccess Layer — Repository Pattern

**Rule:** All data access lives in the DataAccess layer behind a domain-specific interface. The interface boundary uses only local Common domain types — no SDK types, no infrastructure exceptions, no DataModels from other LENS services. Infrastructure concerns (Cosmos client, HTTP client, ARM client, Graph client) are confined to the concrete implementation body.

The pattern has two tiers regardless of the backing technology:

```
Handler
  ↓ injects
I{Domain}Repository              ← Tier 1: Scoped; domain-typed; wraps all infrastructure exceptions
  ↓ injects
ICosmosDbResourceRepository      ← Tier 2: Singleton; generic Cosmos CRUD
IHttpClientFactory               ← Tier 2: Singleton; HTTP (framework-provided)
I{Service}ClientProvider         ← Tier 2: Singleton; SDK client (Graph, ARM, etc.)
```

Tier 1 always looks the same to the handler regardless of backing technology:

```csharp
// CosmosDB-backed entity
public interface IFooRepository
{
    Task<Foo?> GetFooAsync(Guid partitionId, Guid fooId);
    Task<Foo> CreateFooAsync(Foo foo);
}

// Outbound HTTP service
public interface IBarRepository
{
    Task<Bar> GetBarAsync(Guid barId);
}

// SDK-backed service (Graph, ARM, etc.)
public interface IOrganizationRepository
{
    Task<Organization> GetOrganizationAsync(string tenantId);
}
```

The backing technology (Cosmos, HTTP, Graph SDK) is entirely hidden inside the Tier 1 implementation. The Tier 2 split exists because Cosmos clients and SDK clients are expensive to initialise and must be Singleton.

**DataAccess Layer rules:**
- Interfaces use only local Common domain types — no SDK types, no `DataModels` from other LENS services in the interface signature
- Infrastructure exceptions (`CosmosException`, `HttpRequestException`, SDK-specific exceptions) are caught in the concrete implementation and wrapped into `DataStoreException` or `ExternalServiceCallException` — never allowed to escape to handlers
- 404 on a CosmosDB point-read GET → `null`; the handler checks for null and throws a typed `HandlerException` subclass. 404 on delete/update → throw `DataStoreException(NotFound)`
- Outbound HTTP message construction, DataModels mapping, and SDK client usage are confined to the implementation body — a breaking upstream contract change touches one class only
- No business logic — the repository never decides what data means

> CosmosDB two-tier details, query builder, and `DataStoreException`: [references/repository-pattern-cosmos.md](references/repository-pattern-cosmos.md)
> Outbound HTTP pattern, SDK client providers, and DI registration: [references/repository-pattern-external.md](references/repository-pattern-external.md)

---

## Standard 5: Common Layer — No External Dependencies Outside LENS Common

**Rule:** `Common` is the leaf node. It has zero project references. The only permitted NuGet packages are from the `Microsoft.LENS.Common.*` family — no third-party or infrastructure packages. It contains models, constants, configuration option classes, structured telemetry event definitions, and shared utilities.

```csharp
// ✅ GOOD — config options class in Common/Configuration
public sealed class CosmosDbSettingsOptions
{
    public const string ConfigSectionKey = "ExternalServices:CosmosDb";

    [Required(ErrorMessage = "ExternalServices:CosmosDb:AccountEndpoint is required.")]
    public string AccountEndpoint { get; set; } = string.Empty;

    [Required(ErrorMessage = "ExternalServices:CosmosDb:DatabaseName is required.")]
    public string DatabaseName { get; set; } = string.Empty;

    [Required(ErrorMessage = "ExternalServices:CosmosDb:ContainerName is required.")]
    public string ContainerName { get; set; } = string.Empty;
}
```

**Common Layer rules:**
- Only `Microsoft.LENS.Common.*` packages are permitted — no third-party or infrastructure NuGet packages
- Structured telemetry event types (e.g. `ExceptionEvent`, `QOSEvent`) and the service-specific structured logger belong here so they can be used at every layer
- If a model needs a Cosmos SDK attribute, that attribute is wrong — handle mapping in DataAccess instead
- Types belong in `Common` only if they are *values or utilities* (model, enum, exception, options record, telemetry event)
- Interfaces that define *behavioural contracts* belong in the layer that owns that contract — not here

> Configuration validation startup registration: [references/validation.md](references/validation.md)

---

## Standard 6: DependencyInjection Layer — Single Entry Point

**Rule:** `DependencyInjection` is the only layer that simultaneously knows about all concrete implementations. It has one file and one public entry point. Registration is split into private static helper methods within that same file — no subfolders, no internal classes.

```csharp
// ✅ GOOD — {ServiceName}ServiceCollectionExtensions.cs (single file, flat)
[ExcludeFromCodeCoverage]
public static class ServiceNameServiceCollectionExtensions
{
    public static IServiceCollection AddServiceNameServices(
        this IServiceCollection services,
        IConfiguration configuration,
        IHostEnvironment environment)
    {
        services.AddDataAccessServices(configuration, environment);
        services.AddBusinessLogicServices();
        services.AddAppOptions(configuration);

        return services;
    }

    private static void AddBusinessLogicServices(this IServiceCollection services)
    {
        services.AddScoped<IFooHandler, FooHandler>();
        services.AddScoped<IBarHandler, BarHandler>();
    }

    private static void AddDataAccessServices(
        this IServiceCollection services,
        IConfiguration configuration,
        IHostEnvironment environment)
    {
        services.AddSingleton<ICosmosClientProvider, CosmosClientProvider>();
        services.AddSingleton<ICosmosDbResourceRepository, CosmosDbResourceRepository>();
        services.AddScoped<IFooRepository, FooRepository>();
    }

    private static void AddAppOptions(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<CosmosDbSettingsOptions>()
            .Bind(configuration.GetSection(CosmosDbSettingsOptions.ConfigSectionKey))
            .ValidateDataAnnotations()
            .ValidateOnStart();
    }
}

// Program.cs
builder.Services.AddServiceNameServices(builder.Configuration, builder.Environment);
```

> Full DI pattern with lifetime guidance: [references/di-pattern.md](references/di-pattern.md)
> Program.cs structure, startup sequence, and middleware pipeline ordering: [references/program-startup.md](references/program-startup.md)

---

## Standard 7: Anti-Patterns

| Anti-Pattern | Symptom | Correct Fix |
|-------------|---------|-------------|
| Business logic in controllers | Controller has `if/else` beyond result mapping, or calls a repository directly | Move logic to a handler in `BusinessLogic` |
| Business logic in DataAccess | Repository decides what the data "means" or applies rules | Move decisions to the handler that calls the repository |
| `API` referencing `DataAccess` directly | Controller or API model injects an `IRepository` | The missing piece is a handler method — create it |
| Layer skipping | `API` calls `DataAccess` without going through `BusinessLogic` | Respect the dependency chain — always go through the next layer |
| Returning domain types as HTTP responses | Controller passes the Common domain type directly to `Ok()` | Map through `PresentationModelFactory` first — the external contract must be an API Presentation type |
| Presentation types flowing inward | A `*Response` or `*Record` type from `API/Presentation/` appears in a handler or repository | Presentation types are API-only; create a Common domain type and map at the boundary |
| Inter-service presentation model in BusinessLogic | A `Microsoft.LENS.Common.DataModels` type (e.g. `DataPipelineRequest<T>`) appears in a handler interface or handler body | DataModels types belong at the API layer (inbound) and DataAccess layer (outbound) only — the handler must receive and return local Common domain types |
| Infrastructure types leaking up | `CosmosException`, Cosmos SDK types, or `HttpRequestException` appear in BusinessLogic or API | Wrap in `DataStoreException` / `ExternalServiceCallException` within DataAccess; they must not cross the boundary |
| Swallowing exceptions | `catch (Exception ex) { }` with no rethrow or wrap | Always catch specific types; log, then rethrow or wrap into a domain exception |
| Missing `ParameterContracts` | Constructor takes a dependency but doesn't validate it | Add `ParameterContracts.CheckIsNotNull` for every dependency |
| Concrete types in DI | Service registered as its concrete type, not its interface | Register against the interface: `services.AddScoped<IFoo, FooImpl>()` |
| Non-LENS NuGet in `Common` | `Common` references a third-party or infrastructure NuGet (Cosmos SDK, MSAL, etc.) | Only `Microsoft.LENS.Common.*` packages are permitted in `Common`; move anything else to the layer that owns it |

---

## Standard 8: Migration Analysis — Phased Path to Alignment

**Rule:** When analysing an existing codebase, discover all violations first, then produce a minimum-disruption phased plan. Fix structural layering before fixing code quality — refactoring code that is in the wrong layer is wasted work.

### Analysis Process

**Step 1 — Map the dependency graph.** Read every `.csproj` file and list `<ProjectReference>` entries. Any reference that violates the dependency matrix in Standard 1 is a Phase 1 violation.

**Step 2 — Identify and categorise violations.**

| Phase | What it corrects | Why this phase comes first |
|-------|-----------------|---------------------------|
| 1: Structural | Illegal project references; layer skipping; presentation types flowing into inner layers | The layer model must be structurally correct before any other fix is valid. Code in the wrong layer stays wrong no matter how clean it is. |
| 2: Exception boundaries | Infrastructure exceptions leaking past DataAccess; `DataStoreException` not wrapped into `HandlerException`; swallowed catches | Exception contracts are the layer contract at runtime — they enforce encapsulation just as project references do |
| 3: Pattern completeness | Missing `ParameterContracts`; non-`sealed` handlers; domain types returned as HTTP responses without `PresentationModelFactory` | Correctness issues within otherwise correct layers |
| 4: Best-practices polish | Two-tier DataAccess structure; `AddOptions` startup validation; DI registration organisation | Quality improvements once the structure is sound |

**Step 3 — Produce the phased plan.** For each phase: list the specific files to change, the minimal change per file, and any new files to create. Explicitly list what is deferred — changes outside the current phase scope must not slip in.

**Phasing rules:**
- Never move code and rewrite it in the same phase — move first, improve in a later phase
- Each phase is independently reviewable (one PR per phase where possible)
- A phase is complete when every violation in its category has been resolved
- Name phases after what they achieve: "Structural Corrections", not "FooHandler refactor"

> Full violation checklist, analysis queries, and plan output template: [references/migration-analysis.md](references/migration-analysis.md)

---

## What NOT to Do

- ❌ Skip the handler — put logic directly in the controller action
- ❌ Inject `IConfiguration` into services or repositories — use the Options pattern (`IOptions<T>`)
- ❌ Return `null` from a handler when an entity is not found — throw a typed `HandlerException` subclass (e.g. `FooNotFoundException`)
- ❌ Put `HttpStatusCode` on `HandlerException` — HTTP status codes are protocol-layer concerns; the controller decides them from the exception type
- ❌ Catch `Exception` generically without rethrowing — always use specific types or `when` guards
- ❌ Return a Common domain type directly from a controller action — always map to a Presentation type first
- ❌ Use a Presentation type in a handler or repository — it belongs to the API layer only
- ❌ Use a `Microsoft.LENS.Common.DataModels` type in a handler interface or handler body — DataModels types belong at the API layer (inbound mapping) and DataAccess layer (outbound call construction) only; BusinessLogic works exclusively with local Common domain types
- ❌ Add a non-`Microsoft.LENS.Common.*` NuGet package to `Common` — third-party and infrastructure packages belong in the layer that uses them
- ❌ Catch `HandlerException` generically in a controller — always catch the specific subclass; catching the base type collapses all failure scenarios into one undifferentiated handler and destroys the deterministic routing guarantee
- ❌ Expose raw infrastructure exception messages to callers — only `SanitizedMessageException.Message` is included in HTTP responses; all others are suppressed
