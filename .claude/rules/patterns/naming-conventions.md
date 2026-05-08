---
paths:
  - "**/*.cs"
  - "**/*.tsx"
  - "**/*.ts"
  - "**/*.csproj"
  - "**/*.yml"
---

# Naming Conventions

> **Canonical-derived: derived from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** This file documents LENS-canonical patterns. The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

Consistent naming conventions for .NET and TypeScript projects.

## Quick Reference

| Element | Convention | Example |
|---------|------------|---------|
| Controller | `{Feature}Controller` | `AccountCreationController` |
| **Handler (business logic)** | `{Feature}Handler` — one per use case; `sealed` | `AccountCreationHandler`, `CaseHandler` |
| Repository | `{Domain}Repository` | `UserRepository`, `CaseRepository` |
| **Service (infrastructure only)** | `{Feature}Service` — NEVER for business logic | `ServiceBusQueueProcessorService`, structured-logger Service, cache Service |
| Interface | `I{Name}` | `IAccountCreationHandler` |
| **Private field** | camelCase (NO underscore) | `private readonly ILogger logger;` |
| Async method | `{Action}Async` | `CreateAsync`, `GetByIdAsync` |
| Options class | `{Feature}Options` | `DatabaseOptions`, `CosmosDbSettingsOptions` |
| Feature flag | `{Service}.{FeatureName}` | `MyService.EnableBulkOperations` |
| Test class | `{ClassUnderTest}Tests` | `AccountHandlerTests` |
| Test method | `{Method}_{Scenario}_{Expected}` | `CreateAsync_ValidInput_ReturnsSuccess` |
| React component | PascalCase | `AccountCreationForm.tsx` |
| React hook | `use{Feature}` | `useAccountCreation.ts` |
| TS service | camelCase | `accountService.ts` |
| API route | `api/v{n}/{resource}[/{id}/{compound-segment}]` — fleet uses MULTIPLE conventions; document service choice in service-level CLAUDE.md (see API Routes section below) | `api/v1/cases` (lowercase plural majority), `api/v1/targetSelectors` (camelCase), `api/v1/deliverybatch` (concatenated), `api/v1/cases/{id}/fulfillment-summary` (kebab compound) |

> **Feature flag naming**: see `_dotnet/dotnet-feature-flags.md` for the constants-class pattern.

## Handler vs Service (load-bearing distinction)

LENS services use **Handler** for business logic and **Service** for infrastructure-only concerns. They are **not interchangeable**.

| | Handler | Service |
|---|---|---|
| **Owns business rules?** | Yes — every business rule lives in a handler | No — never decides what data means |
| **Layer** | `BusinessLogic/Handlers/` | `Common/Services/` (logger, cache) or `API/HostedServices/` (queue processor) |
| **Modifier** | `sealed` (always) | `sealed` (default) |
| **Throws** | Typed `HandlerException` subclasses | Infrastructure exceptions (rare; usually no throw surface) |
| **DI lifetime** | Scoped | Singleton (most), Scoped for `IAppServices`-like per-request types |
| **Examples** | `CaseHandler`, `AccountCreationHandler`, `NdoHandler` | `ServiceBusQueueProcessorService`, `MemoryCacheService`, structured-logger Service |

**REJECT**: a class named `*Service` in `BusinessLogic/` containing business rules. Rename to `*Handler` and move it under `BusinessLogic/Handlers/`. See `.claude/skills/lens-aspnet-structure/references/handler-pattern.md` for the canonical handler implementation.

---

## C# Field Naming (Critical)

```csharp
// CORRECT: camelCase, no underscore
private readonly ILogger<Handler> logger;
private readonly IUserRepository userRepository;

// WRONG: underscore prefix
private readonly ILogger<Handler> _logger;  // NO
```

---

## Async Methods

All async methods MUST end with `Async`:

```csharp
// CORRECT
public async Task<User> GetByIdAsync(string id) { }

// WRONG
public async Task<User> GetById(string id) { }
```

---

## Options Classes

LENS services name binding-target option classes with the `*Options` suffix and expose the configuration section key as `ConfigSectionKey` (NOT `SectionName`). Both names are load-bearing for `services.AddOptions<T>().Bind(configuration.GetSection(T.ConfigSectionKey))` wiring.

```csharp
// CORRECT
public sealed class AuthOptions
{
    public const string ConfigSectionKey = "Authentication";
    public string Authority { get; set; } = string.Empty;
}

// WRONG: legacy `Configuration` suffix and `SectionName` constant
public class AuthConfiguration
{
    public const string SectionName = "Authentication";
    public string Authority { get; set; }
}
```

See `_dotnet/dotnet-configuration.md` for `IConfigOptions` binding patterns and `_dotnet/dotnet-di-patterns.md` for `AddOptions<T>().ValidateDataAnnotations().ValidateOnStart()` registration.

---

## API Routes

**LENS fleet uses MULTIPLE route conventions.** There is no single canonical pattern — different services pick different conventions. Document your service's chosen convention in your service-level CLAUDE.md, then apply it consistently within that service.

### Common patterns observed across the fleet

<!-- Provenance: 6 LENS services enumerated independently; at least 4 distinct naming conventions found in active use. Detailed evidence: .mad/reports/lens-cleanup/iter8-multiModelVerification.md (D-D17 finding). -->

LENS services across the fleet use multiple route conventions. The table below summarizes the patterns observed in active codebases.

| Pattern | Where used (verified) | Example |
|---|---|---|
| **Lowercase plural** (most common for single-noun resources) | LENS-CMS, LENS-LRMS, LENS-DCS, LENS-Common templates | `api/v1/cases`, `api/v1/lookups`, `api/v1/agencies` |
| **camelCase resource segment** | observed in fleet (LENS-LEAPI / LENS-DFS family) | `api/v1/targetSelectors` |
| **PascalCase action segment** | observed in fleet (older service handler routes) | `api/v1/Cases/Create` shape |
| **Concatenated-lowercase compounds** | LENS-CMS-derived services (delivery + preservation flows) | `api/v1/deliverybatch`, `api/v1/preservationextension` |
| **Slash-separated compounds** | LENS-LRMS | `api/v1/cases/{caseId}/fulfillment/summary` |
| **Kebab compounds (minority — 2 of 60+ paths fleet-wide)** | LENS-CMS, LENS-LRMS internal endpoints | `api/v1/cases/{caseId}/fulfillment-summary`, `api/v1/internal/diagnostics/auth-modes` |

The "lowercase plural single-noun resource segment" majority pattern dominates the top-level resource axis. Compound segments diverge: each service picks one of concatenated-lowercase, slash-separated, or kebab — none is canonical fleet-wide.

### Recommendation for new services

For NEW services without an established convention:

1. **Resource segment** (top-level noun after `api/v{n}/`): lowercase plural single-word noun. Use lowercase singular noun or abbreviation for RPC/singleton endpoints (`sas`, `cleanup`).
2. **Compound nested segments**: pick ONE of the 4+ observed conventions (concatenated-lowercase, slash-separated, kebab, camelCase) and document it in your service-level CLAUDE.md. Apply consistently.
3. **Versioning**: always include `api/v{n}/` prefix.
4. **Casing on resource segment**: avoid PascalCase for new services (the older fleet examples are legacy patterns kept for compatibility).

```csharp
// CORRECT: versioned + lowercase plural single-noun resource (majority pattern)
[Route("api/v1/cases")]
[Route("api/v1/lookups")]
[Route("api/v1/agencies")]

// CORRECT: RPC/singleton endpoint (lowercase singular noun or abbreviation)
[Route("api/v1/sas")]
[Route("api/v1/cleanup")]

// ACCEPTABLE per service-level convention — examples of the 4+ compound styles in fleet use
[Route("api/v1/cases/{caseId}/fulfillment-summary")]      // kebab compound (LENS-CMS)
[Route("api/v1/cases/{caseId}/fulfillment/summary")]       // slash-separated (LENS-LRMS)
[Route("api/v1/deliverybatch")]                            // concatenated-lowercase (CMS family)
[Route("api/v1/targetSelectors")]                          // camelCase resource (LRMS family)
[Route("api/v1/internal/diagnostics/auth-modes")]          // kebab compound (LENS-LRMS)

// WRONG: no version
[Route("api/cases")]

// WRONG: not lowercase at the resource segment for new services (legacy services may have PascalCase)
[Route("api/v1/AccountCreation")]    // legacy shape; prefer `api/v1/accounts` or domain-driven plural
```

<!-- Provenance: 6 LENS services enumerated independently across the fleet; 4+ distinct conventions found. Concrete examples: camelCase resources (`targetSelectors`), PascalCase actions, concatenated-lowercase compounds (`deliverybatch`, `preservationextension`), slash-separated compounds, kebab compounds. Kebab is the minority compound form (estimated 2 of 60+ compound paths fleet-wide). Detailed enumeration: .mad/reports/lens-cleanup/iter8-multiModelVerification.md (D-D17). -->

> **Note on count ratios**: the "2 of 60+" figure is a sampled estimate from per-service file enumeration, not a fleet-wide census. Treat it as an approximate signal of "kebab is the minority compound form," not as an authoritative ratio.

---

## Enum Naming

```csharp
// CORRECT: Singular, explicit values, Unknown default
public enum AccountStatus
{
    Unknown = 100,
    Active = 0,
    Inactive = 1
}

// WRONG: Plural, no Unknown
public enum AccountStatuses { Active, Inactive }
```

---

## TypeScript Naming

| Type | Convention | Example |
|------|------------|---------|
| Component | PascalCase file | `AccountForm.tsx` |
| Hook | `use` prefix | `useAccountCreation.ts` |
| Service | camelCase file | `accountService.ts` |
| Interface | No `I` prefix | `interface User {}` |

---

## Anti-Patterns

| Anti-Pattern | Correct |
|--------------|---------|
| `private readonly ILogger _logger;` | `logger` (no underscore) |
| `public async Task GetById()` | `GetByIdAsync` |
| `public interface AccountHandler` | `IAccountHandler` |
| `[Route("api/accountCreation")]` | versioned `api/v1/{resource}` per service convention (e.g. lowercase plural `api/v1/cases`) |
| `public class CreateAccountDTO` | `CreateAccountRequest` |
| `enum AccountStatuses` | `AccountStatus` (singular) |
