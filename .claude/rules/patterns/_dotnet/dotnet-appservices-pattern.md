---
paths:
  - "**/Program.cs"
  - "**/Startup.cs"
  - "**/DependencyInjection/**/*.cs"
  - "**/spec.md"
  - "**/plan.md"
---

# AppServices Request-Scoped Container

> **Canonical-derived: derived from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** This file documents LENS-canonical patterns. The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

The AppServices pattern provides a request-scoped container carrying `RequestContext`, `AuthContext`, and `ILogger`. It flows through the middleware pipeline and is injected into controllers and handlers via DI.

---

## Overview

> **Cross-reference consensus**: IAppServices is confirmed in the majority of audited ecosystem services. One audited service uses a different architecture (DTF/Singleton) and does not use IAppServices. Two-phase initialization (InitializeAppServicesMiddleware step 2 + PostAuthMiddleware step 8) is the established flow.

```
Request arrives
  → InitializeAppServicesMiddleware (step 2) — creates AppServices, sets RequestContext
  → PostAuthMiddleware (step 8) — populates AuthContext from claims
  → Controller / Handler — receives IAppServices via DI
```

---

## IAppServices Interface

```csharp
public interface IAppServices
{
    RequestContext RequestContext { get; }
    AuthContext AuthContext { get; set; }
    ILogger Logger { get; }
}

public sealed class AppServices : IAppServices
{
    public RequestContext RequestContext { get; }
    public AuthContext AuthContext { get; set; } = new();
    public ILogger Logger { get; }

    public AppServices(RequestContext requestContext, ILogger<AppServices> logger)
    {
        RequestContext = requestContext;
        Logger = logger;
    }
}
```

---

## RequestContext

Captures per-request metadata established early in the pipeline:

```csharp
public sealed class RequestContext
{
    public string CorrelationId { get; init; } = string.Empty;
    public string RequestId { get; init; } = string.Empty;
    public DateTimeOffset RequestTimestamp { get; init; } = DateTimeOffset.UtcNow;
}
```

---

## AuthContext

Populated by `PostAuthMiddleware` after authentication. See `dotnet-auth.md` for the full model and claims extraction.

```csharp
public sealed class AuthContext
{
    public string AppId { get; set; } = string.Empty;
    public string TenantId { get; set; } = string.Empty;
    public string ObjectId { get; set; } = string.Empty;
    public IReadOnlyList<string> Roles { get; set; } = Array.Empty<string>();
    public IReadOnlyCollection<string> Scopes { get; set; } = Array.Empty<string>();

    public bool IsAuthenticated => !string.IsNullOrEmpty(AppId);
    public bool IsUserContext => !string.IsNullOrEmpty(ObjectId);
    public string CurrentAppId => AppId;
}
```

---

## InitializeAppServicesMiddleware

Creates the `AppServices` instance early in the pipeline (step 2), before any business logic runs:

```csharp
public sealed class InitializeAppServicesMiddleware
{
    private readonly RequestDelegate next;

    public InitializeAppServicesMiddleware(RequestDelegate next)
    {
        this.next = next;
    }

    public async Task InvokeAsync(HttpContext context, IAppServices appServices)
    {
        // RequestContext is set via DI factory — this middleware ensures
        // AppServices is resolved and available for downstream middleware
        context.Items["AppServices"] = appServices;

        await this.next(context);
    }
}
```

---

## DI Registration

```csharp
// In DependencyInjection/ServiceCollectionExtensions.cs
services.AddScoped<IAppServices>(sp =>
{
    var httpContext = sp.GetRequiredService<IHttpContextAccessor>().HttpContext;
    var logger = sp.GetRequiredService<ILogger<AppServices>>();

    var requestContext = new RequestContext
    {
        CorrelationId = httpContext?.TraceIdentifier ?? Guid.NewGuid().ToString(),
        RequestId = Guid.NewGuid().ToString()
    };

    return new AppServices(requestContext, logger);
});
```

---

## Usage in Handlers

```csharp
public sealed class CaseHandler : ICaseHandler
{
    private readonly ICaseRepository caseRepository;
    private readonly IAppServices appServices;

    public CaseHandler(ICaseRepository caseRepository, IAppServices appServices)
    {
        ParameterContracts.CheckIsNotNull(caseRepository, nameof(caseRepository));
        ParameterContracts.CheckIsNotNull(appServices, nameof(appServices));
        this.caseRepository = caseRepository;
        this.appServices = appServices;
    }

    public async Task<Case> CreateCaseAsync(Case request, CancellationToken ct)
    {
        // Access auth context
        var currentAppId = this.appServices.AuthContext.CurrentAppId;

        // Access request context
        var correlationId = this.appServices.RequestContext.CorrelationId;

        // Use logger from AppServices
        this.appServices.Logger.LogInformation("Creating case. AppId: {AppId}", currentAppId);

        // Handler returns the domain type directly; throws typed HandlerException on failure.
        // Result<T> is NOT the LENS pattern — see references/handler-pattern.md.
        // ...
    }
}
```

---

## Consumer-project Mapping

A consumer project commonly has these types in its Common project:

| Ecosystem name | Consumer-project name (example) | Location |
|-----------|----------|----------|
| `IAppServices` | `IAppServices` | `Common/Services/` |
| `AppServices` | `AppServices` | `Common/Services/` |
| `AuthContext` | `AuthContext` / `OAuthClaims` | `Common/Auth/` |
| `PostAuthMiddleware` | `AuthContextBuilderMiddleware` | `API/Middleware/` |
| `InitializeAppServicesMiddleware` | `InitializeAppServicesMiddleware` | `API/Middleware/` |

---

## Enforcement

| Pattern | Status |
|---------|--------|
| Accessing `HttpContext.User` directly in handlers | **REJECT** — use `AppServices.AuthContext` |
| Creating `AppServices` outside DI | **REJECT** — must be scoped via DI |
| Missing `InitializeAppServicesMiddleware` in pipeline | **REJECT** |
| `AppServices` registered as Singleton | **REJECT** — must be Scoped |

---

## Anti-Patterns

| Anti-Pattern | Correct Approach |
|--------------|------------------|
| Passing `HttpContext` to handlers | Inject `IAppServices` |
| Reading claims in business logic | Use `AppServices.AuthContext` |
| Creating auth context per method | Populate once in PostAuthMiddleware |
| Skipping AppServices initialization | Always include step 2 middleware |
