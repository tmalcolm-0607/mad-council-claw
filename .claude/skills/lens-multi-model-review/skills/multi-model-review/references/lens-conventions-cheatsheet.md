# LENS Coding Conventions — Quick Reference for Reviewers

This is the condensed reference injected into multi-model review prompts. It captures the org-wide LENS standards that ALL repos must follow, plus repo-specific overrides.

## Org-Wide Standards (All LENS Repos)

### Critical Rules (MUST enforce — violations are blocking)

Rules below are shown in their canonical form. Permitted carve-outs (e.g. `var` in LINQ continuations, LF in non-`.cs` files) are listed in § False Positive Avoidance at the bottom of this file — consult that section before flagging.

> **"Async all the way."** Once a code path goes async, every layer above must `await`. Sync-over-async (`.Result`, `.Wait()`, `GetAwaiter().GetResult()`) deadlocks under sync contexts and starves the threadpool. This applies to rules 10 and 11 below.

| # | Rule | Correct Pattern | Violation Pattern |
|---|------|----------------|-------------------|
| 1 | **Explicit types (no `var`)** | `List<Item> items = new();` | `var items = new List<Item>();` |
| 2 | **ParameterContracts** | `ParameterContracts.CheckIsNotNull(svc, nameof(svc));` | `svc ?? throw new ArgumentNullException(...)` |
| 3 | **CRLF line endings (`.cs` files)** | `\r\n` (Windows) | `\n` (Unix) |
| 4 | **One class per file** | `MyClass.cs` contains only `MyClass` | Multiple types in one file |
| 5 | **No nested IFs** | Guard clauses, early returns | `if (a) { if (b) { if (c) { ... } } }` |
| 6 | **Sealed classes** | `public sealed class MyHandler` | `public class MyHandler` (if not inherited) |
| 7 | **No `_` prefix** | `this.logger` | `_logger` |
| 8 | **Copyright header** | Every .cs file has the header block | Missing header |
| 9 | **Layered architecture** | API → BusinessLogic → DataAccess → Common | API calling DataAccess directly |
| 10 | **CancellationToken** | Pass through all async ops | Missing CancellationToken parameter |
| 11 | **Async patterns** | `await` + `ConfigureAwait(false)` in libraries (see [ConfigureAwait FAQ](https://devblogs.microsoft.com/dotnet/configureawait-faq/) — .NET Core does not exempt library code) | `.Result`, `.Wait()`, sync-over-async |
| 12 | **XML documentation** | All public types and members documented | Missing XML docs on public API |
| 13 | **No business logic in controllers** | Controllers delegate to handlers | Logic in controller action methods |
| 14 | **Structured logging** | `LoggerMessage` source generators or message templates | String interpolation in log messages |
| 15 | **Package versions centralized** | Version in `Directory.Packages.props` only | Version in `.csproj` file |

> Rules 12–15 will be expanded in a forthcoming LENS patterns document by Jamie Cote (link will be folded in once published). Until then, this cheatsheet is the working source of truth.

### Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| Handler | `{Feature}Handler` | `OnboardingRequestHandler` |
| Repository | `{DataSource}Repository` | `CosmosDbResourceRepository` |
| Interface | `I{ClassName}` in `Interfaces/` folder | `IOnboardingHandler` |
| Settings | `{Section}Settings` in `Common/Settings/` | `StorageSettings` |
| Test | `{ClassName}Tests` with `{Method}_{Scenario}_{Expected}` | `GetAsync_NullId_ThrowsArgumentNullException` |
| Controller | `{Feature}Controller` (thin, delegates to handlers) | `RequestsController` |

### Testing Standards

- Framework: MSTest (`[TestClass]`, `[TestMethod]`, `[TestInitialize]`)
- Mocking: **NSubstitute, restored from the Enzyme feed** (the only supported NuGet source per the repo's `NuGet.config` — see [aka.ms/m365coral](https://aka.ms/m365coral)). Adding `nuget.org` or other public feeds to a LENS project's NuGet config is a compliance violation and is flagged by the `lens-standards-audit` skill. Plain Moq is also out — use NSubstitute in all new code.
- Logger: `NullLogger<T>.Instance` (never mock ILogger)
- Structure: Arrange-Act-Assert with explicit comments
- Categories: `[TestCategory("Unit")]`, `[TestCategory("Integration")]`
- Naming: `{Method}_{Scenario}_{Expected}`
- Explicit types in tests (no `var`)

### Error Handling

- Specific exceptions (never catch generic `Exception` unless rethrowing)
- No swallowed exceptions (no empty catch blocks)
- Structured logging with EventIds
- `GlobalErrorHandlingMiddleware` handles unhandled exceptions
- 401 for auth failure, 403 for authz failure, 404 for routing authz

## Repo-Specific Overrides

### LENS-LEPortal Additional Rules
- Old backend (SQL/EF Core) and new backend (Cosmos) must NEVER cross-reference
- `ParameterContracts.CheckNonWhitespace` (slightly different API than other repos)
- `FluentProvider` with `lePortalLightTheme`/`lePortalDarkTheme` for theming
- React Hook Form + Zod for form validation (not manual useState)
- `@fluentui/react-components` ONLY (not v8 `@fluentui/react`)

### LENS-LRMS Additional Rules
- DI registration in dedicated `DependencyInjection/` project (not Program.cs)
- Repository interfaces in BusinessLogic (consuming layer), not DataAccess
- Enum source of truth: MetadataController only (no frontend enum definitions)
- 70% minimum code coverage
- `[LoggerMessage]` source generators for structured logging
- MISE v2 authentication (not standard JWT Bearer)

### LENS-LEAPI Additional Rules
- Block-scoped namespaces (not file-scoped)
- `using` directives inside namespace block
- `BaseController` pattern (all controllers inherit from it)
- ETSI HI1 interface — XML serialization support
- Strong-named assemblies required
- `InternalsVisibleTo` for test access to internal members

### LENS-Common Additional Rules
- `netstandard2.0` for DataModels, `net10.0` for Telemetry
- Generic contracts pattern: `DataPipelineRequest<T>`, `DataFulfillmentRequest<T>`
- File-scoped namespaces mandatory
- NuGet packaging via separate `.Package.csproj` (not library csproj)
- Source generators for structured logging ([StructuredEventLogger], [StructuredEvent])

## False Positive Avoidance

The following are NOT violations — do not flag:
- `var` in LINQ query continuations where the type is obvious from the query
- Missing `ConfigureAwait(false)` in API layer (only required in library code)
- Missing XML docs on test classes/methods
- `public` (not `sealed`) on classes that are inherited (check for subclasses)
- Missing ParameterContracts on private methods (only required on public/internal entry points)
- Missing copyright header on auto-generated files
- LF line endings in `.md`, `.json`, `.yml` files (CRLF only enforced on `.cs`)
