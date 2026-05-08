# Layer Responsibilities Reference

> Detailed folder structure, namespace conventions, and file organisation rules for each LENS service layer.

---

## Folder Tree per Layer

```
src/
├── {ServiceName}.Api/
│   ├── Controllers/            ← one controller per resource type
│   ├── Middleware/              ← cross-cutting pipeline components
│   ├── Presentation/           ← external HTTP contract; never flows into inner layers
│   │   ├── Models/             ← inbound request types + outbound response types
│   │   │   CreateFooRequest.cs    ← DataAnnotations on inbound types
│   │   │   FooResponse.cs         ← outbound presentation types
│   │   │   FooListResponse.cs
│   │   ├── IPresentationModelFactory.cs
│   │   └── PresentationModelFactory.cs  ← maps Common domain types → presentation types
│   ├── Features/               ← API infrastructure registrations; one file per concern
│   │   SwaggerServiceCollectionExtensions.cs      ← AddSwaggerWithAuth(...)
│   │   CorsServiceCollectionExtensions.cs         ← AddFrontendCors(...)
│   │   RateLimitingServiceCollectionExtensions.cs ← AddRateLimitingPolicies(...)
│   ├── Authorization/          ← custom auth policy handlers
│   └── Program.cs              ← calls DI project + API/Features/ extensions; configures middleware pipeline
│
├── {ServiceName}.BusinessLogic/
│   ├── Handlers/               ← sealed handler implementations; one file per domain area
│   │   FooHandler.cs
│   │   BarHandler.cs
│   │   BazHandler.cs
│   └── Interfaces/             ← handler interfaces; one file per handler class
│       IFooHandler.cs
│       IBarHandler.cs
│       IBazHandler.cs
│
├── {ServiceName}.DataAccess/
│   ├── Interfaces/             ← all DataAccess interfaces
│   │   IFooRepository.cs              ← Tier 1: entity-typed CosmosDB (what handlers inject)
│   │   IBazRepository.cs
│   │   ICosmosDbResourceRepository.cs      ← Tier 2: generic CRUD
│   │   ICosmosClientProvider.cs
│   │   IBarRepository.cs                  ← external HTTP service repo (Tier 1)
│   │   IGraphClientProvider.cs            ← SDK client provider (Tier 2, Singleton)
│   │   IOrganizationRepository.cs         ← SDK service repo (Tier 1, Scoped)
│   ├── CosmosDB/               ← CosmosDB implementations
│   │   FooRepository.cs                    ← Tier 1 implementations
│   │   BazRepository.cs
│   │   CosmosDbResourceRepository.cs      ← Tier 2 implementation
│   │   CosmosClientProvider.cs
│   │   ContainerContext.cs               ← context/query value objects
│   │   FooCosmosDbQueryBuilder.cs        ← query builder implementations
│   └── ExternalServices/       ← HTTP and SDK service implementations
│       BarRepository.cs                   ← HTTP service repo
│       GraphClientProvider.cs             ← SDK client provider
│       OrganizationRepository.cs          ← SDK service repo
│
├── {ServiceName}.Common/
│   ├── Models/                 ← domain entities + shared types
│   ├── Configuration/          ← options classes with DataAnnotations + ConfigSectionKey
│   ├── Constants/              ← shared constant values
│   └── Exceptions/             ← domain exception types
│
└── {ServiceName}.DependencyInjection/
    └── {ServiceName}ServiceCollectionExtensions.cs    ← single file; public + private helpers
```

---

## Namespace Convention

C# namespaces follow the project name exactly:

| Project | Namespace |
|---------|-----------|
| `{ServiceName}.Api` | `Microsoft.LENS.{ServiceName}.Api.Controllers` |
| `{ServiceName}.BusinessLogic` | `Microsoft.LENS.{ServiceName}.BusinessLogic.Handlers` |
| `{ServiceName}.DataAccess` | `Microsoft.LENS.{ServiceName}.DataAccess.Repositories` |
| `{ServiceName}.Common` | `Microsoft.LENS.{ServiceName}.Common.Models` |
| `{ServiceName}.DependencyInjection` | `Microsoft.LENS.{ServiceName}.DependencyInjection` |

When a service is renamed, update all namespaces in the same commit as the rename to avoid double churn.

---

## File Organisation Rules

**One type per file. Always.** Every interface, class, record, and enum gets its own `.cs` file named after the type.

```
IFooRepository.cs
FooRepository.cs
IFooHandler.cs
FooHandler.cs
CreateFooRequest.cs
FooResponse.cs
FooNotFoundException.cs
FooLockedForDeletionException.cs
FooDataAccessException.cs
```

The narrow exception: a tiny supporting type tightly coupled to its primary type and never independently referenced. When in doubt, split.

---

## Project References (`.csproj`)

```xml
<!-- {ServiceName}.DataAccess -->
<ItemGroup>
  <ProjectReference Include="..\{ServiceName}.Common\{ServiceName}.Common.csproj" />
</ItemGroup>

<!-- {ServiceName}.BusinessLogic -->
<ItemGroup>
  <ProjectReference Include="..\{ServiceName}.Common\{ServiceName}.Common.csproj" />
  <ProjectReference Include="..\{ServiceName}.DataAccess\{ServiceName}.DataAccess.csproj" />
</ItemGroup>

<!-- {ServiceName}.DependencyInjection -->
<ItemGroup>
  <ProjectReference Include="..\{ServiceName}.Common\{ServiceName}.Common.csproj" />
  <ProjectReference Include="..\{ServiceName}.DataAccess\{ServiceName}.DataAccess.csproj" />
  <ProjectReference Include="..\{ServiceName}.BusinessLogic\{ServiceName}.BusinessLogic.csproj" />
</ItemGroup>

<!-- {ServiceName}.Api -->
<ItemGroup>
  <ProjectReference Include="..\{ServiceName}.Common\{ServiceName}.Common.csproj" />
  <ProjectReference Include="..\{ServiceName}.BusinessLogic\{ServiceName}.BusinessLogic.csproj" />
  <ProjectReference Include="..\{ServiceName}.DependencyInjection\{ServiceName}.DependencyInjection.csproj" />
</ItemGroup>
```

**Never add `{ServiceName}.DataAccess` as a reference in `{ServiceName}.Api.csproj`.** This is the most common architecture violation — it lets controllers inject repositories directly and bypasses the handler layer entirely.

---

## LENS-Common NuGet Packages

| Package | Layer(s) that reference it | What it provides |
|---------|---------------------------|-----------------|
| `Microsoft.LENS.Common.Core` | All layers | `ParameterContracts`, `RequestContextItems` |
| `Microsoft.LENS.Common.Telemetry` | `Common` and all layers above | Structured event types (`ExceptionEvent`, `QOSEvent`), service-specific structured logger — defined in `Common` so every layer can emit structured events (see `lens-telemetry` skill) |

### Logger and event types MUST live in the same assembly

The `[StructuredEventLogger]` source generator only emits `LogEvent(TEvent)` overloads for `[StructuredEvent]` classes that live in the **same assembly** as the logger class. Splitting events across multiple projects produces no overload — `telemetryContext.StructuredLogger.LogEvent(myEvent)` fails to compile or silently falls through to a base reflective path.

**Canonical placement:** `MyServiceStructuredLogger` (the `[StructuredEventLogger]`-decorated class) AND every `[StructuredEvent]` event class go in `{ServiceName}.Common`. BusinessLogic, DataAccess, and Api all reference Common and inject `ITelemetryContext<MyServiceStructuredLogger>` to call `LogEvent(...)`.

If you must split — e.g. cross-service contract events shared via a NuGet package — you have to register them in the consuming service's logger via the (deprecated) `Register<TEvent>()` shim, which loses LENS0001/LENS0003 generator-time error checking. Prefer keeping events in `Common`.
| `Microsoft.LENS.Common.Auth` | `Api` | MISE authentication middleware and configuration |

Source: Enzyme NuGet feed (`o365exchange.pkgs.visualstudio.com`)
