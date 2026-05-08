---
paths:
  - "**/*.cs"
  - "**/*.csproj"
  - "**/Directory.Build.props"
  - "**/spec.md"
  - "**/plan.md"
---

# .NET Layered Architecture

> **Canonical-derived: derived from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** This file documents LENS-canonical patterns. The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

Standards for .NET enterprise architecture based on the canonical LENS five-layer model. See `.claude/skills/lens-aspnet-structure/SKILL.md` Standard 1 (lines 43-72) and `references/layer-responsibilities.md` for the authoritative source.

## Layer Structure

LENS services use **five** layers — four data-flow layers plus a single **DependencyInjection** aggregator project that references all four.

```
API  →  BusinessLogic  →  DataAccess  →  Common
API  →  DependencyInjection
DependencyInjection → BusinessLogic, DataAccess, Common  (NOT API — see Caveat below)
```

| Layer | May reference | Responsibility |
|-------|---------------|----------------|
| `API` | `BusinessLogic`, `Common`, `DependencyInjection` | HTTP surface: thin controllers, request/response models, DataAnnotations, auth middleware |
| `BusinessLogic` | `DataAccess`, `Common` | All business rules via the Handler pattern; throws typed `HandlerException` subclasses |
| `DataAccess` | `Common` | Repository interfaces and concrete implementations; wraps infrastructure exceptions |
| `Common` | Nothing — LEAF, zero internal project refs | Shared models, constants, configuration option classes, structured exception types, telemetry events, utilities |
| `DependencyInjection` | `BusinessLogic`, `DataAccess`, `Common` (NOT `API` — would be circular; see Caveat below) | The **only** project that simultaneously knows every concretion; single public registration entry point per service |

**Critical**: Data-flow dependencies flow DOWN only (API → BusinessLogic → DataAccess → Common). Never reference upward. `DependencyInjection` is the single sink — nothing references it except `Program.cs`.

---

## ⚠️ Caveat — canonical layout has a circular dependency

The canonical `lens-aspnet-structure` SKILL.md (LENS-Common PR 5158460, lines 49, 56, and 60) AND the layer-references summary above contain a **`dotnet build`-breaking circular dependency** if used as a literal copy-paste template. Three prescriptions exist simultaneously:

> 1. `DependencyInjection → references all four data-flow layers (API, BusinessLogic, DataAccess, Common)` — so the aggregator can register every concretion (line 49).
> 2. `API → ... → DependencyInjection` — the API layer references DependencyInjection so `Program.cs` can call `AddServiceNameServices(...)` (line 56).
> 3. `API → references DependencyInjection` — restated explicitly at line 60.

Combined, items (1) and (2)/(3) form a cycle:

```
API → DependencyInjection → API   (FAILS dotnet build with a circular ProjectReference error
                                    — typical MSBuild messages: MSB4006 "circular dependency
                                    detected" or NU1108 "Cycle detected")
```

### How real LENS services resolve this — pick ONE resolution

Pick **Resolution A** (LENS-CMS fleet pattern) unless you have a specific reason to introduce a separate Host project. The canonical prescription as literal copy-paste is structurally wrong; both observed resolutions break the cycle by removing exactly one of the three links.

**Resolution A — `DependencyInjection` does NOT reference `API`** (LENS-CMS pattern, RECOMMENDED):

The aggregator references only `{BusinessLogic, DataAccess, Common}`. `Program.cs` lives inside the `API` project, calls `AddServiceNameServices(builder.Configuration, builder.Environment)` via the `DependencyInjection` reference. The API's controllers are discovered via `AddControllers()` (convention-based scanning of the `API` project assembly itself, no DI-side registration needed). API-layer middleware and options classes still need explicit registration where they're used (typically `Program.cs` or a `Startup`-style extension on `IApplicationBuilder`/`IServiceCollection`); they are not auto-discovered by `AddControllers()`. Resolution A keeps that registration inside the `API` project, which is consistent with the cycle-break.

```xml
<!-- DependencyInjection.csproj — references three data-flow layers (NOT API) -->
<ProjectReference Include="..\BusinessLogic\BusinessLogic.csproj" />
<ProjectReference Include="..\DataAccess\DataAccess.csproj" />
<ProjectReference Include="..\Common\Common.csproj" />

<!-- API.csproj — references DependencyInjection (one-way; no cycle) -->
<ProjectReference Include="..\DependencyInjection\DependencyInjection.csproj" />
<ProjectReference Include="..\BusinessLogic\BusinessLogic.csproj" />
<ProjectReference Include="..\Common\Common.csproj" />
```

**Resolution B — `Program.cs` lives in a separate Host project** (less common):

Extract `Program.cs` into a `Host` (or `Service`) project that references `DependencyInjection.csproj`. The `API` project (controllers, models, middleware) becomes a class library; `DependencyInjection` may then reference all four data-flow layers including `API` without forming a cycle.

### Action for kit consumers

- **Do NOT blindly copy-paste the canonical project-reference graph** from `lens-aspnet-structure` SKILL.md. Use Resolution A unless you have a specific reason to add a `Host` project.
- Tracked separately: upstream issue against LENS-Common PR 5158460 (lines 49 + 60). Refresh this caveat after the PR is corrected.

---

## Project References

```xml
<!-- API.csproj -->
<ProjectReference Include="..\DependencyInjection\DependencyInjection.csproj" />
<ProjectReference Include="..\BusinessLogic\BusinessLogic.csproj" />
<ProjectReference Include="..\Common\Common.csproj" />

<!-- BusinessLogic.csproj -->
<ProjectReference Include="..\DataAccess\DataAccess.csproj" />
<ProjectReference Include="..\Common\Common.csproj" />

<!-- DataAccess.csproj -->
<ProjectReference Include="..\Common\Common.csproj" />

<!-- Common.csproj - NO project references -->

<!-- DependencyInjection.csproj — references THREE data-flow layers (NOT API; see Caveat above) -->
<ProjectReference Include="..\BusinessLogic\BusinessLogic.csproj" />
<ProjectReference Include="..\DataAccess\DataAccess.csproj" />
<ProjectReference Include="..\Common\Common.csproj" />
```

### Transitive Dependency Pinning

Enable `CentralPackageTransitivePinningEnabled` in `Directory.Packages.props` to prevent transitive dependency version drift across projects:

```xml
<!-- Directory.Packages.props -->
<Project>
  <PropertyGroup>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
    <CentralPackageTransitivePinningEnabled>true</CentralPackageTransitivePinningEnabled>
  </PropertyGroup>
</Project>
```

Without this, each project may resolve different versions of shared transitive dependencies (e.g., `System.Text.Json`), causing runtime conflicts.

---

## Interface-Based Contracts

Interfaces defined in **consuming** layer, implemented in **lower** layer. Note: in LENS the convention places repository interfaces in `DataAccess/Interfaces/` (and the domain-typed Tier-1 interface beneath the handler — see `dotnet-repository-two-tier.md`). The general principle holds — the consumer depends on the interface, not the implementation:

```csharp
// DataAccess/Interfaces/ICaseRepository.cs
public interface ICaseRepository
{
    Task<Case?> GetCaseAsync(Guid partitionId, Guid caseId);
    Task<Case> CreateCaseAsync(Case caseEntity);
}

// DataAccess/CosmosDB/CaseRepository.cs
internal sealed class CaseRepository : ICaseRepository { ... }
```

---

## Parameter Validation

Use `ParameterContracts` from `Microsoft.LENS.Common.Core` in every constructor and at the entry point of every public method receiving external input. Calls are **standalone statements** — never assignment targets — and `ArgumentNullException.ThrowIfNull(...)` is forbidden (it bypasses the centralised check).

| Method | Guards against |
|--------|----------------|
| `CheckIsNotNull(value, nameof(value))` | Null reference |
| `CheckNonWhitespace(value, nameof(value))` | Null, empty, or whitespace string |
| `CheckIsGuidEmpty(value, nameof(value))` | `Guid.Empty` |
| `Check(boolExpr, nameof(value), "message")` | Any boolean assertion |

```csharp
// CORRECT — standalone statements, then assign
public sealed class CaseHandler : ICaseHandler
{
    private readonly ICaseRepository repository;
    private readonly ILogger<CaseHandler> logger;

    public CaseHandler(ICaseRepository repository, ILogger<CaseHandler> logger)
    {
        ParameterContracts.CheckIsNotNull(repository, nameof(repository));
        ParameterContracts.CheckIsNotNull(logger, nameof(logger));
        this.repository = repository;
        this.logger = logger;
    }

    public async Task<Case> GetCaseAsync(Guid partitionId, string caseId)
    {
        ParameterContracts.CheckNonWhitespace(caseId, nameof(caseId));
        var caseEntity = await this.repository.GetCaseAsync(partitionId, Guid.Parse(caseId));
        if (caseEntity is null)
            throw new CaseNotFoundException("Case not found.");
        return caseEntity;
    }
}

// WRONG — never use these
_repository = ParameterContracts.RequireNotNull(repository);  // wrong API name; assignment-target
ArgumentNullException.ThrowIfNull(repository);                // bypasses LENS check
this.repository = repository ?? throw new ArgumentNullException(nameof(repository));  // also wrong
```

---

## Configuration Pattern

```csharp
public class DatabaseOptions
{
    public const string ConfigSectionKey = "Database";

    [Required] public string ConnectionString { get; set; } = string.Empty;
    [Range(1, 300)] public int CommandTimeoutSeconds { get; set; } = 30;
}

// Registration with fail-fast
services.AddOptions<DatabaseOptions>()
    .Bind(configuration.GetSection(DatabaseOptions.ConfigSectionKey))
    .ValidateDataAnnotations()
    .ValidateOnStart();
```

---

## Service Registration

Per `lens-aspnet-structure` Standard 6: the **DependencyInjection** project has **one file** with **one public entry point**. Registration is split into `private static` helper methods within that same file — no subfolders, no internal classes. `Program.cs` calls exactly one method.

```csharp
// DependencyInjection/{ServiceName}ServiceCollectionExtensions.cs
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
        services.AddScoped<ICaseHandler, CaseHandler>();
    }

    private static void AddDataAccessServices(
        this IServiceCollection services,
        IConfiguration configuration,
        IHostEnvironment environment)
    {
        // Tier 2 — Singleton; see dotnet-repository-two-tier.md
        services.AddSingleton<ICosmosClientProvider, CosmosClientProvider>();
        services.AddSingleton<ICosmosDbResourceRepository, CosmosDbResourceRepository>();
        // Tier 1 — Scoped (matches handler lifetime)
        services.AddScoped<ICaseRepository, CaseRepository>();
    }

    private static void AddAppOptions(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<CosmosDbSettingsOptions>()
            .Bind(configuration.GetSection(CosmosDbSettingsOptions.ConfigSectionKey))
            .ValidateDataAnnotations()
            .ValidateOnStart();
    }
}

// Program.cs — exactly ONE call
builder.Services.AddServiceNameServices(builder.Configuration, builder.Environment);
```

**REJECT**: `Program.cs` calling `AddDataAccess(...).AddBusinessLogic(...)` directly — that pattern bypasses the single-aggregator contract and fragments wiring across multiple projects.

---

## Code Style (PR-mined)

```csharp
// File-scoped namespace (reduce indentation)
namespace BusinessLogic.Handlers;

using Common.Validation;

// Using directives inside namespace
public sealed class CaseHandler { }

// Explicit enum values
public enum CaseStatus { Unknown = 0, Open = 1, Closed = 2 }
```

---

## Common Layer Organization

### Constants Consolidation

ONE constants file per category in the Common layer. Do not scatter related constants across multiple files.

| File | Contents | Example |
|------|----------|---------|
| `ErrorCodes.cs` | All domain error codes | `public const string NotFound = "CASE_NOT_FOUND";` |
| `DocumentTypes.cs` | Cosmos document type discriminators | `public const string Case = "case";` |
| `PropertyNames.cs` | JSON property name constants | `public const string PartitionKey = "pk";` |
| `RouteConstants.cs` | API route template strings | `public const string CasesRoute = "api/v1/cases";` |

| Pattern | Status |
|---------|--------|
| Duplicate constant categories across files | **REJECT** |
| Constants in controller or service files | **WARN** |

### Controller Base Class

For versioned API controllers, use a shared base class to centralize routing and common behavior. See `dotnet-mvc-controllers.md` for the full pattern.

---

## DataModels Boundary Rule

`Microsoft.LENS.Common.DataModels` (and any cross-service LENS contract package) types are **inter-service presentation models**. They appear at exactly **two** layer boundaries and nowhere else:

| Boundary | Direction | Responsibility |
|----------|-----------|----------------|
| **API layer** | Inbound | Receive `DataModels.XRequest`; map to local `Common` domain type before calling the handler |
| **DataAccess layer** | Outbound | Map local domain → `DataModels.YRequest`, call the remote LENS service, map `DataModels.YResponse` → local domain, return |

**BusinessLogic must never see `DataModels` types.** The handler always works with local `Common` domain types regardless of whether the data originated from HTTP or a downstream LENS service call. This is a canonical Phase 2 violation per `lens-aspnet-structure` Standard 1 and `migration-analysis.md` Phase 2.

```csharp
// CORRECT - API controller maps DataModels -> domain at the boundary
[HttpPost]
public async Task<IActionResult> CreateFooAsync(
    Microsoft.LENS.Common.DataModels.CreateFooRequest request, // DataModels at API boundary
    CancellationToken ct)
{
    var domain = MapToDomain(request);                          // -> local Common.Foo
    var created = await this.fooHandler.CreateFooAsync(domain); // handler sees Common.Foo only
    return CreatedAtAction(
        nameof(GetFooAsync),
        new { fooId = created.Id },
        this.presentationFactory.GetFooResponse(created));      // -> FooResponse (API/Presentation)
}

// CORRECT - DataAccess maps domain -> DataModels at the outbound boundary
internal sealed class BarRepository : IBarRepository
{
    public async Task<Bar> GetBarAsync(Guid barId)
    {
        var dmRequest = new Microsoft.LENS.Common.DataModels.GetBarRequest(barId);
        var dmResponse = await this.barClient.GetBarAsync(dmRequest);
        return MapToDomain(dmResponse); // returns local Common.Bar
    }
}

// REJECT - DataModels in handler signature OR body
public sealed class FooHandler : IFooHandler
{
    public Task<Foo> CreateFooAsync(
        Microsoft.LENS.Common.DataModels.CreateFooRequest request) // <- BusinessLogic sees DataModels
    { ... }
}
```

**REJECT trigger**: any `Microsoft.LENS.Common.DataModels.*` (or equivalent cross-service contract type) referenced in a `BusinessLogic/` file. Cite SKILL.md:150-153, 374; `references/migration-analysis.md` Phase 2.

---

## Anti-Patterns

| Anti-Pattern | Correct |
|--------------|---------|
| Circular project references | Strict downward dependencies |
| Interface in implementation layer | Define in consumer |
| Business logic in controllers | Delegate to service layer |
| Repository returns DTOs | Return domain models |
| Missing ValidateOnStart() | Always validate on startup |
| Common layer has project refs | Common references only packages |
| `DataModels` type in `BusinessLogic/*.cs` | Map at API/DataAccess boundary; handler uses local domain types |
