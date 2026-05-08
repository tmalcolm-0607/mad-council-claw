# Program.cs and ASP.NET Core Startup Reference

> Canonical structure for `Program.cs` in all LENS ASP.NET Core services. Covers the five-step startup sequence, DI registration grouping, and middleware pipeline ordering.

---

## Canonical Structure

`Program.cs` does exactly three things: builds the app, calls one DI extension method, configures the middleware pipeline. All registration detail lives in the `DependencyInjection` project; all pipeline detail lives in `ConfigureMiddlewarePipeline`.

```csharp
[ExcludeFromCodeCoverage]
internal sealed class Program
{
    private static void Main(string[] args)
    {
        // ASP.NET Core Startup Sequence (order matters — do not reorder):
        // 1. Create WebApplicationBuilder  — initialises DI container and configuration
        // 2. ConfigureServices             — register services with the DI container
        // 3. Build WebApplication          — finalises the service provider
        // 4. ConfigureMiddlewarePipeline   — set up the request processing pipeline
        // 5. Run                           — start listening for requests
        var builder = WebApplication.CreateBuilder(args);
        ConfigureServices(builder);
        var app = builder.Build();
        ConfigureMiddlewarePipeline(app);
        app.Run();
    }

    // Order within ConfigureServices does NOT matter — all registrations complete
    // before Build() is called. Group by category for clarity.
    private static void ConfigureServices(WebApplicationBuilder builder)
    {
        // 1. Core Framework
        builder.Services.AddControllers()
            .AddJsonOptions(options =>
            {
                options.JsonSerializerOptions.Converters.Add(new LenientEnumConverterFactory());
            });
        builder.Services.AddEndpointsApiExplorer();
        builder.Services.AddSingleton<IExceptionHandler, ExceptionHandler>();

        // 2. Authentication & Authorization
        AuthApiExtensions.AddAuthenticationAndAuthorization(builder.Services, builder.Configuration);

        // 3. LENS telemetry — wires OTel providers, Geneva exporters, structured-logger
        //    source-gen mappings, middleware DI. AddMiseAuthContextBuilder is REPLACE-
        //    semantics + idempotent; order relative to AddLensTelemetry does not matter.
        builder.Services.AddMiseAuthContextBuilder();
        builder.Services.AddLensTelemetry<MyServiceStructuredLogger>(
            builder.Configuration.GetSection("GenevaTelemetry"));
        builder.Services.AddCosmosDbTelemetry();    // no-op if Cosmos isn't used
        builder.Services.AddBlobClientTelemetry();  // no-op if Blob isn't used

        // 4. Domain services — single call; all detail lives in DependencyInjection project
        builder.Services.AddServiceNameServices(builder.Configuration, builder.Environment);

        // 5. API features (Swagger, rate limiting, CORS)
        builder.Services.AddSwaggerWithAuth(builder.Configuration);
        builder.Services.AddRateLimitingPolicies(builder.Configuration);
        builder.Services.AddFrontendCors(builder.Configuration, builder.Environment);
    }

    // Order within ConfigureMiddlewarePipeline DOES matter — each middleware runs
    // in registration sequence on every inbound request.
    private static void ConfigureMiddlewarePipeline(WebApplication app)
    {
        app.UseMiddleware<GlobalErrorHandlingMiddleware>();  // (1) Catch unhandled exceptions first
        app.UseHttpsRedirection();                           // (2) Enforce TLS
        app.UseCors();                                       // (3) CORS before auth — preflight must not be blocked
        app.UseRateLimiter();                                // (4) Throttle before expensive auth
        app.UseAuthentication();                             // (5) Establish identity
        app.UseAuthorization();                              // (6) Enforce policy
        app.UseMise();                                       // (7) MISE S2S enrichment — runs after identity is established
        app.MapControllers();                                // (8) Attribute-routed endpoints last
    }
}
```

---

## Why a Class, Not Top-Level Statements

Top-level statements are the default in modern .NET but LENS services use an explicit `Program` class because:

- `[ExcludeFromCodeCoverage]` requires a type to annotate — top-level statements cannot carry it
- `internal sealed` restricts visibility and signals intent: this is not a public API surface
- Private static methods (`ConfigureServices`, `ConfigureMiddlewarePipeline`) are explicit, named, and independently readable; floating top-level code is not

---

## The Five-Step Sequence

```
WebApplication.CreateBuilder(args)
  ↓  initialises configuration (appsettings.json, environment variables, command-line args)
  ↓  creates the DI service collection

ConfigureServices(builder)
  ↓  all services registered here
  ↓  order does NOT matter within this step

builder.Build()
  ↓  service provider is finalised — no more registrations after this point

ConfigureMiddlewarePipeline(app)
  ↓  middleware added in pipeline order
  ↓  order DOES matter — every request runs middleware in registration sequence

app.Run()
  ↓  starts Kestrel, begins accepting requests
```

**The critical rule:** `builder.Build()` finalises the DI container. Any service registration attempt after `Build()` throws. Any middleware added before `Build()` is silently ignored. Keep the sequence strict.

---

## Pre-Builder Requirements

Some configuration must happen before `WebApplication.CreateBuilder(args)` — before the DI container exists. The only current requirement is CDT token support.

**Preferred approach — use `Microsoft.LENS.Common.Auth`:** `AddLensAuth()` sets the CDT switch internally as part of its registration sequence. No pre-builder code is needed and the ordering is guaranteed correct.

**Manual auth only:** If a service wires authentication without `AddLensAuth()`, set the switch explicitly before `CreateBuilder`:

```csharp
private static void Main(string[] args)
{
    // Must run before CreateBuilder — sets the CDT switch before the DI container is initialised.
    // Not needed if using AddLensAuth() — it handles this internally.
    AppContext.SetSwitch("Switch.Microsoft.IdentityModel.S2S.SupportCdtTokens", true);

    var builder = WebApplication.CreateBuilder(args);
    ConfigureServices(builder);
    var app = builder.Build();
    ConfigureMiddlewarePipeline(app);
    app.Run();
}
```

If the switch is placed after `CreateBuilder` or inside `ConfigureServices`, CDT token validation fails silently — every authenticated request returns 401 with no exception thrown and no obvious error in logs.

---

## ConfigureServices — Two Distinct Concerns

`ConfigureServices` wires two fundamentally different categories of registration, each with a different home:

| Category | What it contains | Where it lives |
|----------|-----------------|---------------|
| **Domain services** | Handlers, repositories, external service clients, typed options for domain config | `{ServiceName}.DependencyInjection` project — one `Add{ServiceName}Services(...)` call |
| **API infrastructure features** | Swagger/OpenAPI, CORS policies, rate limiting, auth | `{ServiceName}.Api/Features/` — one extension method per concern, called from `Program.cs` |

```csharp
private static void ConfigureServices(WebApplicationBuilder builder)
{
    // 1. Core Framework
    builder.Services.AddControllers()
        .AddJsonOptions(options =>
            options.JsonSerializerOptions.Converters.Add(new LenientEnumConverterFactory()));
    builder.Services.AddEndpointsApiExplorer();
    builder.Services.AddMetrics();

    // 2. Telemetry — AddMiseAuthContextBuilder is order-independent (REPLACE-semantics, idempotent)
    builder.Services.AddMiseAuthContextBuilder();
    builder.Services.AddLensTelemetry<ServiceStructuredLogger>(
        builder.Configuration.GetSection("GenevaTelemetry"),
        enableConsoleLogging: builder.Environment.IsDevelopment());
    builder.Services.AddCosmosDbTelemetry();    // no-op if Cosmos isn't used
    builder.Services.AddBlobClientTelemetry();  // no-op if Blob isn't used

    // 3. Authentication & Authorization
    AuthApiExtensions.AddAuthenticationAndAuthorization(builder.Services, builder.Configuration);

    // 4. Domain services — all detail in DependencyInjection project
    builder.Services.AddServiceNameServices(builder.Configuration, builder.Environment);

    // 5. API infrastructure features — each defined in API/Features/
    builder.Services.AddSwaggerWithAuth(builder.Configuration);
    builder.Services.AddRateLimitingPolicies(builder.Configuration);
    builder.Services.AddFrontendCors(builder.Configuration, builder.Environment);
}
```

**Why the split matters:** Swagger needs to know about auth scopes and frontend app IDs — that is an API-layer concern. CORS knows about allowed frontend origins — also API-layer. Rate limiting knows about request shapes — API-layer. None of these belong in the `DependencyInjection` project because they are HTTP/presentation infrastructure, not domain services. Putting them in `API/Features/` keeps the DI project focused on domain wiring and makes the API project's own infrastructure self-contained.

### API/Features/ Extension Methods

Each feature gets its own file in `{ServiceName}.Api/Features/`:

```
API/Features/
  SwaggerServiceCollectionExtensions.cs     — AddSwaggerWithAuth(...)
  CorsServiceCollectionExtensions.cs        — AddFrontendCors(...)
  RateLimitingServiceCollectionExtensions.cs — AddRateLimitingPolicies(...)
```

Each is a `[ExcludeFromCodeCoverage]` `public static` class in the `{ServiceName}.Api.Features` namespace. One public extension method per file, with private helpers as needed.

`Program.cs` must not contain inline `AddScoped<>`, `AddSingleton<>`, or `AddOptions<>` calls for domain types — those belong in the `DependencyInjection` project. If you find yourself writing one in `Program.cs`, move it.

---

## ConfigureMiddlewarePipeline — Ordering Rules

Middleware order is a hard constraint, not a style preference. Each rule below has a consequence if violated.

| Position | Middleware | Why this position |
|----------|-----------|------------------|
| 1 | `GlobalErrorHandlingMiddleware` | Must be first to catch exceptions from all subsequent middleware |
| 2 | `UseHttpsRedirection()` | Redirect before any processing — no point running auth on a plain-HTTP request |
| 3 | `UseCors()` | Must precede auth so that browser CORS preflight (`OPTIONS`) requests are not blocked by auth middleware |
| 4 | `UseRateLimiter()` | Throttle before auth — authentication is expensive; reject over-quota requests first |
| 5 | `UseAuthentication()` | Establishes identity from the token; must precede authorization |
| 6 | `UseAuthorization()` | Enforces policy; requires identity from step 5 |
| 7 | `UseMise()` | MISE S2S enrichment adds service-to-service auth context claims; runs after identity is established |
| 8 | `MapControllers()` | Attribute-routed endpoints execute last — all cross-cutting concerns have already run |

Swagger `UseSwagger()` / `UseSwaggerUI()` is conditionally added inside `ConfigureMiddlewarePipeline` for development environments only and is placed after HTTPS redirect but before auth (Swagger UI must be reachable without a bearer token in dev).

---

## Swagger in Development Only

```csharp
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(options =>
    {
        options.SwaggerEndpoint("/swagger/v1/swagger.json", "Service API v1");
        options.RoutePrefix = "swagger";

        // OAuth2 implicit flow for Swagger UI
        options.OAuthClientId(authOptions.FrontendAppId);
        options.OAuthScopes($"api://{authOptions.FrontendAppId}/user_impersonation");
    });
}
```

Swagger is never enabled in production. The `IsDevelopment()` guard is the mechanism — do not use feature flags or config keys to control this.

---

## What Does NOT Belong in Program.cs

| Anti-pattern | Where it belongs |
|---|---|
| `services.AddScoped<IFooHandler, FooHandler>()` | `DependencyInjection` project |
| `services.AddOptions<XxxOptions>().Bind(...).ValidateDataAnnotations()` | `DependencyInjection` project |
| `configuration.GetValue<string>("...")` for service config | `DependencyInjection` project, via typed options |
| Business logic or conditional wiring based on config values | `DependencyInjection` project; if environment-specific, use `IHostEnvironment` passed in |
| More than ~50 lines total | The file is too large — extract into `ConfigureServices` helper groups or move to `DependencyInjection` |
