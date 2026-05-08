# DI Registration Pattern Reference

> How to wire dependency injection in LENS services.

---

## Structure

One file. Flat. No subfolders.

```
{ServiceName}.DependencyInjection/
└── {ServiceName}ServiceCollectionExtensions.cs    ← single file; public entry point + private helpers
```

The file has one `public static class` with one public method. Everything else is private.

---

## Full Example

```csharp
// {ServiceName}ServiceCollectionExtensions.cs
[ExcludeFromCodeCoverage]
public static class ServiceNameServiceCollectionExtensions
{
    /// <summary>Registers all {ServiceName} domain services.</summary>
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

    private static void AddDataAccessServices(
        this IServiceCollection services,
        IConfiguration configuration,
        IHostEnvironment environment)
    {
        services.AddHttpClient();

        // CosmosDB — Tier 2 Singleton (generic infrastructure), Tier 1 Scoped (domain interface)
        services.AddSingleton<ICosmosClientProvider, CosmosClientProvider>();
        services.AddSingleton<ICosmosDbResourceRepository, CosmosDbResourceRepository>();
        services.AddScoped<IFooRepository, FooRepository>();
        services.AddScoped<IBazRepository, BazRepository>();

        // Outbound LENS service clients
        services.AddScoped<IFooServiceClient, FooServiceClient>();
    }

    private static void AddBusinessLogicServices(this IServiceCollection services)
    {
        services.AddScoped<IFooHandler, FooHandler>();
        services.AddScoped<IBarHandler, BarHandler>();
        services.AddScoped<IBazHandler, BazHandler>();
    }

    private static void AddAppOptions(this IServiceCollection services, IConfiguration configuration)
    {
        services.AddOptions<CosmosDbSettingsOptions>()
            .Bind(configuration.GetSection(CosmosDbSettingsOptions.SectionName))
            .ValidateDataAnnotations()
            .ValidateOnStart();

        services.AddOptions<FooServiceOptions>()
            .Bind(configuration.GetSection(FooServiceOptions.SectionName))
            .ValidateDataAnnotations()
            .ValidateOnStart();
    }
}
```

---

## Configuration Registration

Use native `AddOptions<T>()` — never `Configure<T>()`.

```csharp
// ✅ GOOD — fails fast at startup if required values are missing
services.AddOptions<CosmosDbSettingsOptions>()
    .Bind(configuration.GetSection(CosmosDbSettingsOptions.ConfigSectionKey))
    .ValidateDataAnnotations()
    .ValidateOnStart();

// ❌ BAD — silently binds; missing values are only discovered at first use
services.Configure<CosmosDbSettingsOptions>(
    configuration.GetSection(CosmosDbSettingsOptions.ConfigSectionKey));
```

`ValidateDataAnnotations()` runs all `[Required]`, `[Range]`, etc. attributes on the options class. `ValidateOnStart()` runs validation before the first request is served rather than lazily on first `IOptions<T>` access.

For cross-property rules, implement `IValidatableObject` on the options class — `ValidateDataAnnotations()` calls `IValidatableObject.Validate` automatically.

---

## Service Lifetime Guidance

| Lifetime | When to use |
|----------|------------|
| `Scoped` | Handlers, domain repositories — one instance per HTTP request |
| `Singleton` | `ICosmosClientProvider`, `ICosmosDbResourceRepository`, auth credential providers, `HttpClient` factories — thread-safe, expensive to construct |
| `Transient` | Rarely needed; only for lightweight, stateless components with no shared state |

**Rule:** If a service depends on a scoped service, it must also be `Scoped`. Singletons cannot safely hold scoped dependencies.
