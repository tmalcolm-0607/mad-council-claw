---
paths:
  - "**/*.cs"
  - "**/appsettings*.json"
  - "**/runtimesettings*.json"
  - "**/Directory.Build.props"
  - "**/Directory.Packages.props"
  - "**/spec.md"
  - "**/plan.md"
  - "**/tasks.md"
---

# .NET Configuration Patterns

> **Canonical-derived: derived from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** This file documents LENS-canonical patterns. The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

Standards for configuration management in .NET projects, extracted from enterprise .NET patterns.

## IConfigOptions Interface Pattern

All configuration classes MUST implement `IConfigOptions` with a `ConfigSectionKey`:

```csharp
// CORRECT: Implements IConfigOptions with section key
public class CosmosOptions : IConfigOptions
{
    public const string ConfigSectionKey = "Cosmos";

    [Required]
    public string Endpoint { get; set; } = string.Empty;

    [Required]
    public string DatabaseId { get; set; } = string.Empty;

    [Range(1, 10000)]
    public int MaxRetryAttempts { get; set; } = 9;

    [Range(1, 120)]
    public int MaxRetryWaitTimeSeconds { get; set; } = 30;

    public bool AllowBulkExecution { get; set; } = false;
}

// WRONG: Plain POCO without interface
public class CosmosOptions
{
    public string Endpoint { get; set; }
}
```

### Registration Pattern

```csharp
// In Program.cs or extension method
services.AddOptions<CosmosOptions>()
    .Bind(configuration.GetSection(CosmosOptions.ConfigSectionKey))
    .ValidateDataAnnotations()
    .ValidateOnStart();  // MANDATORY: Fail fast on misconfiguration
```

### Additional Configuration Examples

```csharp
// Storage options for attachments
public class StorageOptions : IConfigOptions
{
    public const string ConfigSectionKey = "Storage";

    [Required]
    public string AccountName { get; set; } = string.Empty;

    [Required]
    public string ContainerName { get; set; } = string.Empty;

    [Range(1, 24)]
    public int SasTokenExpirationHours { get; set; } = 1;
}

// Project management options
public class ProjectManagementOptions : IConfigOptions
{
    public const string ConfigSectionKey = "ProjectManagement";

    [Range(1, 365)]
    public int RetentionDays { get; set; } = 90;

    [Range(1, 1000)]
    public int MaxNotesPerProject { get; set; } = 100;

    [Range(1, 100)]
    public int MaxAttachmentsPerProject { get; set; } = 50;

    public bool AutoCloseInactiveProjects { get; set; } = true;
}
```

---

## GenevaTelemetry footguns

`GenevaTelemetryOptions` (the `"GenevaTelemetry"` configuration section read by `AddLensTelemetry<TLogger>(...)`) ships with several silent failure modes that data-annotations validation does NOT catch. Cite: `lens-telemetry` SKILL.md v1.3.0 Standard 1 (config table); advanced-patterns.md:10-20.

### LongRequestThresholdMs — default `0` emits an event on EVERY request

`LoggingAndMetricsMiddleware` emits an `InboundQOSEvent` when `latency > LongRequestThresholdMs`. The data annotation is `[Range(1, int.MaxValue)]` — but the validator only fires when the key is **present** in configuration. Omit the key and the runtime sees `0`, meaning every request is "long". You get one Geneva event per request, paying ingestion cost across the entire fleet.

```json
// CORRECT — set explicitly
{
  "GenevaTelemetry": {
    "LongRequestThresholdMs": 500
  }
}

// WRONG — key missing
{ "GenevaTelemetry": { /* nothing */ } }   // runtime LongRequestThresholdMs = 0 → every request emits
```

### MetricsAccount + MetricsNamespace — effectively REQUIRED for export

The library starts cleanly without these two values (no `[Required]` annotation on either), but the Geneva metrics exporter has nothing to send to and **silently exports nothing**. `InboundRequestQoSMetric` and `InboundRequestLatencyMetric` produce zero data in Jarvis. The code path looks healthy; only metric absence flags the gap.

```json
// CORRECT — both set per environment
{
  "GenevaTelemetry": {
    "MetricsAccount": "MyServiceAccount",
    "MetricsNamespace": "MyServiceNamespace",
    "MdsRoleInstance": "...",
    "MonitoringRole": "..."
  }
}

// WRONG — startup succeeds, zero metrics in Jarvis
{ "GenevaTelemetry": { "MetricsAccount": "" } }   // empty = silent zero-export
```

Add MetricsAccount/MetricsNamespace to your local IValidateOptions validator if you want startup to fail fast — the library doesn't.

### MonitoringRole + MdsRoleInstance — local-dev fallback to blank

On Geneva Hosting / Azure App Service, `WEBSITE_SITE_NAME` and `WEBSITE_INSTANCE_ID` populate `MonitoringRole` and `MdsRoleInstance` automatically. On a developer machine these env vars are absent — `MonitoringRole` falls back to `""` and `MdsRoleInstance` to `null`. Geneva drops or quarantines records with blank role names, making local dev appear to "work" while telemetry is actually being thrown away.

```json
// appsettings.Development.json — set explicitly to make local dev visible
{
  "GenevaTelemetry": {
    "MonitoringRole": "MyService.Local",
    "MdsRoleInstance": "dev-instance"
  }
}
```

| Footgun | Symptom | Fix |
|---------|---------|-----|
| `LongRequestThresholdMs` missing | Every request emits an `InboundQOSEvent` (huge ingest cost) | Set explicitly per environment |
| `MetricsAccount`/`MetricsNamespace` missing or blank | Zero metrics exported (no startup error) | Set per environment; add a `IValidateOptions<GenevaTelemetryOptions>` if fail-fast is wanted |
| `MonitoringRole`/`MdsRoleInstance` blank on dev | Records dropped silently in local dev | Set in `appsettings.Development.json` |

---

## IValidateOptions Pattern

Complex validation beyond data annotations MUST use `IValidateOptions<T>`:

```csharp
public class DatabaseOptionsValidator : IValidateOptions<DatabaseOptions>
{
    public ValidateOptionsResult Validate(string? name, DatabaseOptions options)
    {
        var failures = new List<string>();

        if (string.IsNullOrWhiteSpace(options.ConnectionString))
        {
            failures.Add($"{nameof(options.ConnectionString)} is required");
        }

        if (options.CommandTimeout < 1 || options.CommandTimeout > 300)
        {
            failures.Add($"{nameof(options.CommandTimeout)} must be between 1 and 300 seconds");
        }

        if (options.MaxRetryCount < 0 || options.MaxRetryCount > 10)
        {
            failures.Add($"{nameof(options.MaxRetryCount)} must be between 0 and 10");
        }

        return failures.Count > 0
            ? ValidateOptionsResult.Fail(failures)
            : ValidateOptionsResult.Success;
    }
}

// Registration
services.AddSingleton<IValidateOptions<DatabaseOptions>, DatabaseOptionsValidator>();
```

---

## Dual Configuration Files

Projects MUST use two configuration files:

| File | Purpose | Contains |
|------|---------|----------|
| `appsettings.json` | Application settings | Feature flags, timeouts, URLs |
| `runtimesettings.json` | Runtime/environment settings | Connection strings, secrets references |

### appsettings.json Structure

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "Features": {
    "EnableNewDashboard": false,
    "MaxConcurrentRequests": 100
  },
  "Timeouts": {
    "DefaultHttpClient": 30,
    "LongRunningOperation": 120
  }
}
```

### runtimesettings.json Structure

```json
{
  "Database": {
    "ConnectionString": "Server=...;Database=...;"
  },
  "AzureAd": {
    "TenantId": "...",
    "ClientId": "..."
  },
  "KeyVault": {
    "VaultUri": "https://my-vault.vault.azure.net/"
  }
}
```

### Loading Order

```csharp
builder.Configuration
    .AddJsonFile("appsettings.json", optional: false)
    .AddJsonFile($"appsettings.{env.EnvironmentName}.json", optional: true)
    .AddJsonFile("runtimesettings.json", optional: false)
    .AddJsonFile($"runtimesettings.{env.EnvironmentName}.json", optional: true)
    .AddEnvironmentVariables();
```

---

## Central Package Management

Projects MUST use central package management via `Directory.Packages.props`:

```xml
<!-- Directory.Packages.props (solution root) -->
<Project>
  <PropertyGroup>
    <ManagePackageVersionsCentrally>true</ManagePackageVersionsCentrally>
    <CentralPackageTransitivePinningEnabled>true</CentralPackageTransitivePinningEnabled>
  </PropertyGroup>

  <ItemGroup>
    <!-- Microsoft.Extensions -->
    <PackageVersion Include="Microsoft.Extensions.Options" Version="8.0.0" />
    <PackageVersion Include="Microsoft.Extensions.Configuration" Version="8.0.0" />

    <!-- Azure -->
    <PackageVersion Include="Azure.Identity" Version="1.10.4" />
    <PackageVersion Include="Azure.Security.KeyVault.Secrets" Version="4.5.0" />

    <!-- Testing -->
    <PackageVersion Include="xunit" Version="2.6.2" />
    <PackageVersion Include="Moq" Version="4.20.70" />
  </ItemGroup>
</Project>
```

### Project References (No Versions)

```xml
<!-- Individual .csproj files -->
<ItemGroup>
  <PackageReference Include="Microsoft.Extensions.Options" />
  <PackageReference Include="Azure.Identity" />
</ItemGroup>
```

---

## Directory.Build.props

Shared settings MUST be in `Directory.Build.props`:

```xml
<!-- Directory.Build.props (solution root) -->
<Project>
  <PropertyGroup>
    <TargetFramework>net10.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <EnforceCodeStyleInBuild>true</EnforceCodeStyleInBuild>
    <AnalysisLevel>latest-all</AnalysisLevel>
  </PropertyGroup>

  <PropertyGroup>
    <Company>Your Company</Company>
    <Copyright>Copyright (c) Your Company 2026</Copyright>
  </PropertyGroup>

  <ItemGroup>
    <!-- Analyzers for all projects -->
    <PackageReference Include="Microsoft.CodeAnalysis.NetAnalyzers" PrivateAssets="all" />
  </ItemGroup>
</Project>
```

---

## .NET SDK Version Management

Always target LTS (Long-Term Support) releases unless there is a critical reason for STS (Standard-Term Support). Use `global.json` to pin the SDK version across the team.

| Release | Type | Support Ends | Status |
|---------|------|--------------|--------|
| .NET 10 | LTS | November 2028 | **Current LTS — active for new and existing LENS services** |
| .NET 9 | STS | May 2026 | Retired — do not use |
| .NET 8 | LTS | November 2026 | Legacy — migrate to .NET 10 before support ends |

```json
// global.json — pin SDK version
// LENS-Common pins 10.0.103; LENS-CMS pins 10.0.102 — pin to a specific patch in your service
{
  "sdk": {
    "version": "10.0.102",
    "rollForward": "latestPatch"
  }
}
```

`rollForward: "latestPatch"` allows patch updates (10.0.103, 10.0.104...) but not minor/major jumps.

---

## Pagination Options (IConfigOptions Example)

Standard pagination configuration using the IConfigOptions pattern:

```csharp
public class PaginationOptions : IConfigOptions
{
    public const string ConfigSectionKey = "Pagination";

    [Range(1, 100)]
    public int DefaultPageSize { get; set; } = 25;

    [Range(1, 1000)]
    public int MaxPageSize { get; set; } = 100;
}

// Usage in controller
public class CasesController : ApiControllerBase
{
    private readonly PaginationOptions paginationOptions;

    public CasesController(IOptions<PaginationOptions> paginationOptions)
    {
        this.paginationOptions = paginationOptions.Value;
    }

    [HttpGet]
    public async Task<ActionResult<PagedResult<CaseResponse>>> List(
        [FromQuery] int? pageSize, [FromQuery] string? continuationToken, CancellationToken ct)
    {
        var effectivePageSize = Math.Min(
            pageSize ?? this.paginationOptions.DefaultPageSize,
            this.paginationOptions.MaxPageSize);
        // ...
    }
}
```

---

## Sealed Validators

All `IValidateOptions<T>` implementations MUST be `sealed`. Validators are infrastructure, not extensible base classes.

```csharp
// CORRECT: Sealed validator
public sealed class CosmosOptionsValidator : IValidateOptions<CosmosOptions>
{
    public ValidateOptionsResult Validate(string? name, CosmosOptions options)
    {
        // validation logic
    }
}

// WRONG: Non-sealed validator
public class CosmosOptionsValidator : IValidateOptions<CosmosOptions> { ... }
```

### Validator Lifetime

Validators MUST be registered as **Singleton**. They are stateless and shared across requests — no per-request allocation needed.

```csharp
// CORRECT: Singleton — validators are stateless
services.AddSingleton<IValidateOptions<CosmosOptions>, CosmosOptionsValidator>();

// WRONG: Scoped — unnecessary per-request allocation
services.AddScoped<IValidateOptions<CosmosOptions>, CosmosOptionsValidator>();
```

---

## Enforcement Table

| Rule | Severity | Check |
|------|----------|-------|
| Config class without `IConfigOptions` | **REJECT** | Must implement interface |
| Missing `ConfigSectionKey` constant | **REJECT** | Required for binding |
| Missing `ValidateOnStart()` | **REJECT** | Fail-fast is mandatory |
| Version in PackageReference | **REJECT** | Use central management |
| Complex validation without `IValidateOptions` | **WARN** | Prefer explicit validator |
| Secrets in appsettings.json | **REJECT** | Use runtimesettings.json |
| Missing Directory.Build.props | **WARN** | Standardize shared settings |
| STS .NET version without justification | **WARN** | Use LTS releases |
| Missing `global.json` SDK pin | **WARN** | Pin SDK version |
| Non-sealed `IValidateOptions<T>` implementation | **REJECT** | Validators must be sealed |
| Scoped/transient validator registration | **REJECT** | Validators must be singleton |

---

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| `IConfiguration` injection everywhere | Tight coupling, no validation | Inject `IOptions<T>` |
| Magic strings for section names | Typos cause silent failures | Use `ConfigSectionKey` constant |
| No startup validation | Runtime failures | `ValidateOnStart()` always |
| One giant config class | SRP violation | Split by domain |
| Environment-specific code | Deployment issues | Use configuration transforms |

---

## Code Review Checklist

```markdown
## Configuration Review

- [ ] Config class implements `IConfigOptions`
- [ ] `ConfigSectionKey` constant defined
- [ ] Data annotations for basic validation
- [ ] `IValidateOptions<T>` for complex rules
- [ ] `ValidateOnStart()` in registration
- [ ] No secrets in appsettings.json
- [ ] Central package versions used
- [ ] Nullable reference types enabled
```
