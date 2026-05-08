# Migration Analysis Reference

> Structured process for analysing an existing LENS service against the layered architecture standards and producing a minimum-disruption phased migration plan.

---

## Overview

The analysis has two stages:

1. **Triage** — discover all violations by reading project files and code
2. **Plan** — order fixes into phases, starting with the minimum changes to achieve correct layering

Do not mix phases. Phase 1 creates the layer scaffold — no code moves. Phase 2 fixes structural violations — code moves to the correct layer. Phase 3+ are qualitative — they improve *how* code in the correct location works. Mixing phases increases the scope of the most disruptive phase and makes rollback harder.

---

## Before You Start

Capture a baseline test count before touching any project structure:

```powershell
dotnet test --list-tests | Measure-Object -Line
```

Record the line count. Verify it is identical after the migration is complete. Silent test loss can hide behind a green build.

---

## Stage 1: Triage

### 1.1 Read the Project Dependency Graph

Glob for all `*.csproj` files in the service. For each, list `<ProjectReference>` entries and compare against the allowed dependency matrix:

```
{Service}.Api             → BusinessLogic, Common, DependencyInjection
{Service}.BusinessLogic   → DataAccess, Common
{Service}.DataAccess      → Common
{Service}.Common          → (nothing)
{Service}.DependencyInjection → all four above
```

**Critical signal:** `{Service}.Api.csproj` contains a reference to `{Service}.DataAccess` → Phase 2 violation (layer skip).

---

### 1.2 Phase 1 — Project Scaffold

Phase 1 establishes the layer structure. No code moves yet. The goal is a compilable solution with the correct projects and test projects in place, ready to receive migrated code.

| Check | How to find it | What to look for |
|-------|---------------|-----------------|
| Missing layer project | Glob `src/` for `*.csproj`, compare against expected layers | Any of `{Service}.Api`, `{Service}.BusinessLogic`, `{Service}.DataAccess`, `{Service}.Common`, `{Service}.DependencyInjection` absent |
| Missing test project | Glob `tests/` for `*.csproj` | A test project for each source layer: `{Service}.Api.Tests`, `{Service}.BusinessLogic.Tests`, `{Service}.DataAccess.Tests`, `{Service}.Common.Tests` |
| Service is a monolith | Single `.csproj` in `src/` containing all code | All layer projects must be created; all four test projects must be created before any code moves |

When creating layer projects, follow the folder structure and namespace conventions in [layer-responsibilities.md](layer-responsibilities.md). Set `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` in every new `.csproj`. This enforces clean code as it arrives in each layer rather than after. If the original project suppressed WaE, do not carry that suppression forward — fix warnings as code moves.

When creating test projects, add `<ProjectReference>` entries to all new layer projects in dependency order **before** trimming any existing test project reference to the original monolith. Removing the old reference first breaks transitive type resolution even while the original project is still present.

---

### 1.3 Phase 2 — Structural Violations

These block all subsequent fixes. Nothing else is valid until the layer model is structurally correct.

| Violation | How to find it | What to look for |
|-----------|---------------|-----------------|
| Api → DataAccess project reference | Read `{Service}.Api.csproj` | `{Service}.DataAccess` in `<ProjectReference>` |
| Presentation type in BusinessLogic | Grep BusinessLogic source for `*Request`, `*Response` type names defined in `API/Presentation/` | API type in handler interface signature or handler body |
| Presentation type in DataAccess | Same grep in DataAccess source | API type in repository interface or implementation |
| Inter-service presentation model in BusinessLogic | Grep for types from `Microsoft.LENS.Common.DataModels` (e.g. `DataPipelineRequest`, `DataPipelineResponse`) in handler interfaces or handler bodies | DataModels types belong at the API layer (inbound) and DataAccess layer (outbound calls to other LENS services) only — finding them in BusinessLogic means the handler is doing boundary mapping work that belongs elsewhere |
| Business logic in controller | Grep controllers for conditional logic (`if`, `switch`) beyond null-check or status routing | Any branch that *decides* an outcome rather than *maps* a result |
| DataAccess interface injected into controller | Grep controller constructors for `I*Repository`, `ICosmosDb*` | DataAccess interface in constructor parameters instead of handler interface |
| CDT switch not set before DI registration | Search `Program.cs` for `AppContext.SetSwitch("Switch.Microsoft.IdentityModel.S2S.SupportCdtTokens", true)` — only relevant if **not** using `AddLensAuth()` | If the service uses `Microsoft.LENS.Common.Auth`, `AddLensAuth()` sets the switch internally and no action is needed. If auth is wired manually, the switch must appear before the master `Add*Services` call; placing it after causes CDT token validation to fail silently with every authenticated request returning 401. |

---

### 1.4 Phase 3 — Exception Boundary Violations

| Violation | How to find it | What to look for |
|-----------|---------------|-----------------|
| `CosmosException` in BusinessLogic | Grep BusinessLogic source for `CosmosException` | Any reference — it must not cross the DataAccess boundary |
| `HttpRequestException` in BusinessLogic or Api | Grep both source trees | Any reference — should be wrapped in `ExternalServiceCallException` at the DataAccess boundary |
| Swallowed exception | Grep for `catch (` without a following `throw` | Any catch that logs only, or does nothing, with no rethrow or wrap |
| `DataStoreException` not wrapped | Grep handlers for `DataStoreException` — verify a `throw new *HandlerException` follows | Handler lets `DataStoreException` propagate raw instead of wrapping |
| Missing typed `HandlerException` subclass | Check `Common/Exceptions/` — is there a scenario-named exception for each routing outcome? | Handler throwing generic `HandlerException` directly, or single `FooHandlerException` for all failures |
| `HttpStatusCode` on `HandlerException` | Grep `Common/Exceptions/` for `HttpStatusCode? StatusCode` property | Handler exception carries status code — protocol concern leaking into BusinessLogic |

---

### 1.5 Phase 4 — Pattern Completeness

| Violation | How to find it | What to look for |
|-----------|---------------|-----------------|
| Missing `ParameterContracts` | Grep constructors with `readonly` dependency fields — check each has `ParameterContracts.CheckIsNotNull` | Constructor that assigns a dependency without validating it |
| Non-`sealed` handler | Grep `class.*Handler` without the `sealed` modifier | Handler implementation missing `sealed` |
| Domain type returned as HTTP response | Grep controller actions for `return Ok(` — check the argument type | Common domain type passed directly instead of being mapped by `PresentationModelFactory` |
| `IConfiguration` injected into service | Grep handlers, repositories, and services for `IConfiguration` constructor parameter | Should use `IOptions<T>` from the Options pattern |
| Handler returns `null` for not-found | Grep handler implementations for `return null` | Should throw a typed `HandlerException` subclass (e.g. `FooNotFoundException`) |

---

### 1.6 Phase 5 — Best-Practices Gaps

| Violation | How to find it | What to look for |
|-----------|---------------|-----------------|
| Single-tier DataAccess | Check if DataAccess has only one interface tier (no `ICosmosDbResourceRepository`) | Handler injects a repository that calls Cosmos directly without the generic Tier 2 beneath it |
| Config not validated at startup | Grep DI file for `ValidateDataAnnotations` and `ValidateOnStart` | Options registered with `Bind()` only |
| DI registration in multiple files | Glob `{Service}.DependencyInjection/` for `.cs` files | More than one file — should be a single flat file |
| Non-LENS NuGet in Common | Read `{Service}.Common.csproj` for `<PackageReference>` | Any package outside `Microsoft.LENS.Common.*` |
| Service-specific structured logger not in Common | Grep all layer projects for `[StructuredEventLogger]` — verify the decorated class lives in `{Service}.Common` | The structured logger and its event types must be in `{Service}.Common`. Placing them in BusinessLogic, DataAccess, or Api means other layers that need to emit structured events would have to take a reference to that layer — introducing illegal dependencies that violate the dependency matrix. `Common` is the correct home because every layer already references it. |

---

### 1.7 Phase 6 — Cleanup

Phase 6 hardens the migrated service: every project enforces warnings-as-errors, logic-free types are excluded from coverage metrics, and all layers meet the 90% coverage bar.

| Check | How to find it | What to look for |
|-------|---------------|-----------------|
| `TreatWarningsAsErrors` missing or suppressed | Read every `.csproj` in the solution | Any project without `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>`, or that overrides it to `false` — including the original Api project if it was never updated |
| Remaining build warnings | Run `dotnet build` and scan output | Any CS* or SA* warning — each one is a Phase 6 fix target |
| Logic-free type missing `[ExcludeFromCodeCoverage]` | Grep source for classes with no methods beyond constructors and property getters | DTOs, options/configuration classes, constants classes, and exception types that contain no branching logic should be decorated — they inflate the denominator and make the 90% bar harder to reach without adding test value |
| Coverage below 90% | Run `dotnet test --collect:"XPlat Code Coverage"` and generate a report | Any layer project below 90% line coverage needs additional tests or `[ExcludeFromCodeCoverage]` on genuinely untestable infrastructure code |

---

## Stage 2: Produce the Phased Plan

### Output Format

For each phase, produce:

1. **Scope statement** — one sentence: what this phase achieves when complete
2. **Files to change** — explicit list with the minimal change per file
3. **New files to create** — if required (e.g., a new `HandlerException` subclass, a missing interface)
4. **Deferred to next phase** — explicitly call out any tempting cleanup that is out of scope here

### Example Phase 1 Output

```
Phase 1 — Project Scaffold

Scope: Create all missing layer projects and test projects with correct project references,
folder structure, and TreatWarningsAsErrors=true. No code moves in this phase.

New projects to create:
  FooService.Common/FooService.Common.csproj
    No ProjectReferences; TreatWarningsAsErrors=true
    Empty folders: Models/, Configuration/, Constants/, Exceptions/

  FooService.DataAccess/FooService.DataAccess.csproj
    Ref → FooService.Common; TreatWarningsAsErrors=true
    Empty folders: Interfaces/, CosmosDB/, ExternalServices/

  FooService.BusinessLogic/FooService.BusinessLogic.csproj
    Ref → FooService.Common, FooService.DataAccess; TreatWarningsAsErrors=true
    Empty folders: Handlers/, Interfaces/

  FooService.DependencyInjection/FooService.DependencyInjection.csproj
    Ref → all four layers above; TreatWarningsAsErrors=true

  FooService.Common.Tests/FooService.Common.Tests.csproj
    Ref → FooService.Common

  FooService.DataAccess.Tests/FooService.DataAccess.Tests.csproj
    Ref → FooService.DataAccess, FooService.Common

  FooService.BusinessLogic.Tests/FooService.BusinessLogic.Tests.csproj
    Ref → FooService.BusinessLogic, FooService.Common

Files to change:
  FooService.Tests/FooService.Tests.csproj  (existing test project)
    Add refs: FooService.Common, FooService.DataAccess, FooService.BusinessLogic
    Do NOT remove FooService.Api ref yet — remove it only after all code has moved

New files: see new projects above

Deferred to Phase 2:
  - Moving code into the correct layers (structural violations)
  - Removing the FooService.Api ref from the test project
```

### Example Phase 2 Output

```
Phase 2 — Structural Corrections

Scope: Remove the Api→DataAccess project reference and eliminate all handler and
repository signatures that accept Presentation types.

Files to change:
  FooService.Api.csproj
    Remove: <ProjectReference Include="..\FooService.DataAccess\..." />

  BusinessLogic/Interfaces/IFooHandler.cs
    Change: CreateFooAsync(CreateFooRequest request) → CreateFooAsync(Foo foo)

  BusinessLogic/Handlers/FooHandler.cs
    Change: method signature; pass Foo to repository, not request object

  DataAccess/Interfaces/IFooRepository.cs
    Change: CreateFooAsync(CreateFooRequest request) → CreateFooAsync(Foo foo)

  DataAccess/CosmosDB/FooRepository.cs
    Change: method signature only — body already reads Cosmos fields, not request properties

New files: (none)

Deferred to Phase 3:
  - FooHandler does not wrap DataStoreException (exception boundary issue)

Deferred to Phase 4:
  - ParameterContracts missing in FooHandler constructor
  - FooController returns Foo domain type directly (no PresentationModelFactory)
```

---

## Quick Reference: Violation Patterns by Phase

```csharp
// ❌ Phase 2 — Presentation type traversing into BusinessLogic
// BusinessLogic/Interfaces/IFooHandler.cs
Task<Foo> CreateFooAsync(CreateFooRequest request);
// CreateFooRequest belongs to API/Presentation/ — must not appear here

// ❌ Phase 2 — Controller injecting DataAccess directly (layer skip)
public FooController(IFooRepository repository) // must be IFooHandler

// ❌ Phase 3 — Infrastructure exception crossing the DataAccess boundary
// BusinessLogic/Handlers/FooHandler.cs
catch (CosmosException ex) { ... } // CosmosException must never appear in BusinessLogic

// ❌ Phase 3 — DataStoreException not wrapped into typed HandlerException subclass
catch (DataStoreException ex)
{
    this.logger.LogError(ex, "...");
    // missing: throw new FooDataAccessException("Data access failed.", ex.RetryAfter, ex);
}

// ❌ Phase 4 — ParameterContracts missing
public FooHandler(IFooRepository repository)
{
    this.repository = repository; // CheckIsNotNull missing
}

// ❌ Phase 4 — Domain type returned directly as HTTP response
var foo = await this.fooHandler.GetFooAsync(this.tenantId, fooId);
return Ok(foo); // foo is Common.Models.Foo — must go through PresentationModelFactory first

// ❌ Phase 5 — Config bound without startup validation
services.AddOptions<CosmosDbSettingsOptions>()
    .Bind(configuration.GetSection(CosmosDbSettingsOptions.ConfigSectionKey));
// missing: .ValidateDataAnnotations().ValidateOnStart()

// ❌ Phase 6 — Logic-free type inflating coverage denominator
public class CreateFooRequest  // no methods, no branches
{
    public string Name { get; set; }
}
// missing: [ExcludeFromCodeCoverage]

// ❌ Phase 6 — TreatWarningsAsErrors not set (original project never updated)
// FooService.Api.csproj has no <TreatWarningsAsErrors> element, or overrides to false
```

---

## Analysis Checklist (Copy-Paste Format)

Use this checklist when producing a migration plan. Mark each item found, then group by phase in the output.

```
BEFORE YOU START
[ ] Baseline test count captured (dotnet test --list-tests | Measure-Object -Line)

PHASE 1 — PROJECT SCAFFOLD
[ ] Any layer project missing (Api, BusinessLogic, DataAccess, Common, DependencyInjection)
[ ] Any test project missing (Api.Tests, BusinessLogic.Tests, DataAccess.Tests, Common.Tests)
[ ] TreatWarningsAsErrors=true set in all new .csproj files
[ ] Existing test project ProjectReferences not updated before removing monolith ref

PHASE 2 — STRUCTURAL
[ ] Api.csproj references DataAccess directly
[ ] Presentation type (*Request / *Response) in handler interface or body
[ ] Presentation type in repository interface or body
[ ] Microsoft.LENS.Common.DataModels type in handler interface or handler body (DataAccess is OK — outbound LENS service calls live there)
[ ] Business logic in controller (conditional beyond result mapping)
[ ] DataAccess interface injected directly into controller
[ ] CDT switch missing before DI registration (skip if using AddLensAuth() — it handles this internally)

PHASE 3 — EXCEPTION BOUNDARIES
[ ] CosmosException referenced outside DataAccess
[ ] HttpRequestException referenced outside DataAccess
[ ] DataStoreException propagates from handler without being wrapped
[ ] Handler throws HandlerException base class directly (not a scenario-named subclass)
[ ] HandlerException subclass carries HttpStatusCode? StatusCode property (protocol leak)
[ ] Swallowed catch (no rethrow, no wrap)

PHASE 4 — PATTERN COMPLETENESS
[ ] Constructor missing ParameterContracts.CheckIsNotNull for a dependency
[ ] Handler implementation not sealed
[ ] Controller returns Common domain type directly (no PresentationModelFactory)
[ ] IConfiguration injected into a service, handler, or repository
[ ] Handler returns null for not-found instead of throwing a typed HandlerException subclass

PHASE 5 — BEST-PRACTICES
[ ] DataAccess is single-tier (handler calls Cosmos directly)
[ ] Options not validated at startup (missing ValidateDataAnnotations / ValidateOnStart)
[ ] DI registrations spread across multiple files
[ ] Non-Microsoft.LENS.Common.* NuGet in Common project
[ ] Service-specific structured logger ([StructuredEventLogger]) not in {Service}.Common

PHASE 6 — CLEANUP
[ ] Any project missing TreatWarningsAsErrors=true (including the original Api project)
[ ] Any remaining build warnings
[ ] Logic-free types (DTOs, options classes, constants, simple exceptions) missing [ExcludeFromCodeCoverage]
[ ] Any layer project below 90% line coverage
```
