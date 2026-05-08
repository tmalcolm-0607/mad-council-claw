---
paths:
  - "**/*.cs"
---

# MVC Controller Patterns

> **Canonical-derived: derived from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** This file documents LENS-canonical patterns. The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

.NET services use MVC Controllers with `[ApiController]` attribute for all business logic endpoints.

## Rule

| Check | Status |
|-------|--------|
| Controller has `[ApiController]` attribute | REJECT if missing |
| Controller inherits `ControllerBase` | REJECT if missing |
| Routes use `/api/v1/` prefix | WARN if missing |
| Actions are async with CancellationToken | WARN if sync |

## Correct

LENS controllers are **thin** — they extract identity, call **one** handler method, map the domain result through `IPresentationModelFactory`, and catch typed `HandlerException` subclasses to map them to HTTP responses. The handler **throws** on failure (typed exceptions); the controller `catch`-ladder is the routing table. See `.claude/skills/lens-aspnet-structure/references/handler-pattern.md` for the canonical pattern and `dotnet-repository-two-tier.md` for the data tier.

```csharp
[ApiController]
[Route("api/v1/cases")]
public sealed class CasesController : ControllerBase
{
    private readonly ICaseHandler caseHandler;
    private readonly IPresentationModelFactory presentationFactory;
    private readonly IAppServices appContext;

    public CasesController(
        ICaseHandler caseHandler,
        IPresentationModelFactory presentationFactory,
        IAppServices appContext)
    {
        ParameterContracts.CheckIsNotNull(caseHandler, nameof(caseHandler));
        ParameterContracts.CheckIsNotNull(presentationFactory, nameof(presentationFactory));
        ParameterContracts.CheckIsNotNull(appContext, nameof(appContext));
        this.caseHandler = caseHandler;
        this.presentationFactory = presentationFactory;
        this.appContext = appContext;
    }

    [HttpGet("{caseId}")]
    public async Task<IActionResult> GetCaseAsync(Guid caseId, CancellationToken cancellationToken)
    {
        // tenantId is read from the per-request auth context populated by MiseAuthContextBuilder
        // (see lens-telemetry Standard 14 + dotnet-appservices-pattern.md PostAuthMiddleware step 8)
        var tenantId = this.appContext.AuthContext.TenantId;

        try
        {
            var caseEntity = await this.caseHandler.GetCaseAsync(tenantId, caseId);
            return Ok(this.presentationFactory.GetCaseResponse(caseEntity));
        }
        catch (CaseNotFoundException ex)
        {
            // QOS error-code wiring — tags the request's QOS metric with a typed error code
            // Required by lens-aspnet-structure SKILL.md:116-128; REJECT trigger per dotnet-error-handling.md § "QOS Error-Code Wiring"
            RequestContextItems.ErrorCode.SetItem(this.appContext.RequestContext, ErrorCodes.CaseNotFound);
            return NotFound(new { error = ex.Message });
        }
        // Anything else propagates to GlobalErrorHandlingMiddleware → 500
    }
}
```

> **Note on `ErrorCodes.CaseNotFound`:** the `ErrorCodes` class is consumer-defined — typically in `Common/Constants/ErrorCodes.cs` per `dotnet-architecture.md:285`. The values shown here (e.g. `ErrorCodes.CaseNotFound`) are illustrative for a CMS-style consumer; substitute your project's actual error-code constants. The kit-canonical placeholder in fully generic patterns is `ServiceErrorCodes.<TypedError>`.

## ProducesResponseType (Required)

All controller actions MUST declare `[ProducesResponseType]` for at minimum the success code and expected error codes. This enables accurate Swagger/OpenAPI documentation.

```csharp
[HttpGet("{caseId}")]
[ProducesResponseType(typeof(CaseResponse), StatusCodes.Status200OK)]
[ProducesResponseType(StatusCodes.Status404NotFound)]
[ProducesResponseType(StatusCodes.Status401Unauthorized)]
public async Task<IActionResult> GetCaseAsync(Guid caseId, CancellationToken cancellationToken)
{
    var tenantId = this.appContext.AuthContext.TenantId;

    try
    {
        var caseEntity = await this.caseHandler.GetCaseAsync(tenantId, caseId);
        return Ok(this.presentationFactory.GetCaseResponse(caseEntity));
    }
    catch (CaseNotFoundException ex)
    {
        RequestContextItems.ErrorCode.SetItem(this.appContext.RequestContext, ErrorCodes.CaseNotFound);
        return NotFound(new { error = ex.Message });
    }
}

[HttpPost]
[ProducesResponseType(typeof(CaseResponse), StatusCodes.Status201Created)]
[ProducesResponseType(StatusCodes.Status400BadRequest)]
[ProducesResponseType(StatusCodes.Status401Unauthorized)]
public async Task<IActionResult> CreateCaseAsync(
    CreateCaseRequest request, CancellationToken cancellationToken)
{
    var caseEntity = await this.caseHandler.CreateCaseAsync(MapToCase(request));
    var response = this.presentationFactory.GetCaseResponse(caseEntity);
    return CreatedAtAction(nameof(GetCaseAsync), new { caseId = caseEntity.Id }, response);
}
```

| Pattern | Status |
|---------|--------|
| Action without `[ProducesResponseType]` | **WARN** |

## Wrong

```csharp
// Missing [ApiController], not inheriting ControllerBase
public class CasesController : Controller
{
    // Sync action, no CancellationToken, no Async suffix, no presentation mapping
    [HttpGet("{caseId}")]
    public CaseResponse GetCase(string caseId)
    {
        return _caseHandler.GetById(caseId);  // also: leaks domain type as HTTP contract
    }
}
```

## Anti-Patterns

| Anti-Pattern | Fix |
|--------------|-----|
| Minimal APIs for business logic | Use MVC Controllers |
| Sync actions | Add `async` + CancellationToken |
| Missing validation | Add DataAnnotation attributes (`[Required]`, `[StringLength]`, etc.) on the request DTO; rely on `[ApiController]` auto-validation. See `api-validation.md`. |
| No version prefix | Add `/api/v1/` route |

---

## Controller Base Class

Use a shared `ApiControllerBase` to centralize versioned routing and common attributes:

```csharp
[ApiController]
[Route("api/v1/[controller]")]
[Produces("application/json")]
public abstract class ApiControllerBase : ControllerBase
{
}

// Controllers inherit shared config
public sealed class CasesController : ApiControllerBase
{
    // Route resolves to: api/v1/cases
    [HttpGet("{caseId}")]
    [ProducesResponseType(typeof(CaseResponse), StatusCodes.Status200OK)]
    public async Task<IActionResult> GetCaseAsync(
        Guid caseId, CancellationToken cancellationToken) { ... }
}
```

**Benefits**: Single place to update route prefix, common attributes, or add global filters.

---

## IPresentationModelFactory Pattern

External HTTP contract types (`*Response`, `*Record`) live in `API/Presentation/`. Mapping from internal `Common` domain types to these external types is owned by **`IPresentationModelFactory`** — controllers never construct presentation types directly, and presentation types never flow inward into BusinessLogic or DataAccess.

The factory is the only place in the API layer that knows how a domain type maps to a wire-format type. The output types (`FooResponse`, etc.) are API-only — a `*Response` or `*Record` from `API/Presentation/` appearing in a handler or repository is a Phase-2 boundary violation per `lens-aspnet-structure` Standard 7. See SKILL.md:147,372-373 + `references/handler-pattern.md:261-271`.

```csharp
// API/Presentation/IPresentationModelFactory.cs
public interface IPresentationModelFactory
{
    FooResponse GetFooResponse(Foo domain);
    FooListResponse GetFooListResponse(IList<Foo> domains);
}

// API/Presentation/PresentationModelFactory.cs
internal sealed class PresentationModelFactory : IPresentationModelFactory
{
    public FooResponse GetFooResponse(Foo domain) => new()
    {
        FooId = domain.Id,
        Name = domain.Name,
        // ... explicit mapping; no AutoMapper-style reflection
    };

    public FooListResponse GetFooListResponse(IList<Foo> domains) => new()
    {
        Items = domains.Select(this.GetFooResponse).ToList(),
    };
}

// CORRECT - controller threads domain -> presentation through the factory
[HttpGet("{fooId}")]
public async Task<IActionResult> GetFooAsync(Guid fooId, CancellationToken ct)
{
    var tenantId = this.appContext.AuthContext.TenantId;
    var domain = await this.fooHandler.GetFooAsync(tenantId, fooId);
    return Ok(this.presentationFactory.GetFooResponse(domain));
}

// REJECT - returning the domain type directly (leaks internal contract)
return Ok(domain);

// REJECT - presentation type in handler signature/body
public Task<FooResponse> GetFooAsync(...)  // <- handler must return Foo (domain), not FooResponse
```

**REJECT triggers** (per `implementation-checklist.md`): domain type returned directly without `IPresentationModelFactory`; `*Response`/`*Record` type from `API/Presentation/` referenced in `BusinessLogic/` or `DataAccess/`.

---

## Route vs Body Parameter Conflicts

Request DTOs MUST NOT include properties that duplicate route parameters. If a property must exist in both (backward compat), the handler MUST validate `body.PropertyValue == routeParameter` or throw `ServiceValidationException`.

Anti-pattern: `CreateNdoRequest.CaseId` carries a `[Required]` attribute but the handler reads from the route `caseId`. Client sends `{"caseId": "XYZ"}` to `/cases/ABC/ndos`, NDO created under ABC with no error.
