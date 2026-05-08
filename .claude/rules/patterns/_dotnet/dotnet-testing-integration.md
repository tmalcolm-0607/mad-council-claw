---
paths:
  - "**/*.Tests/**/*.cs"
  - "**/test/**/*.cs"
  - "**/spec.md"
---

# .NET Integration Testing

> **Canonical-derived: derived from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** This file documents LENS-canonical patterns. The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

Database fixtures, API testing, WireMock, and HTTP client mocking.

---

## Database Fixture

```csharp
public class DatabaseFixture : IAsyncLifetime
{
    public AppDbContext Context { get; private set; } = null!;
    private readonly string connectionString;

    public DatabaseFixture()
    {
        this.connectionString = $"Server=(localdb)\\mssqllocaldb;Database=TestDb_{Guid.NewGuid()};Trusted_Connection=True";
    }

    public async Task InitializeAsync()
    {
        var options = new DbContextOptionsBuilder<AppDbContext>()
            .UseSqlServer(this.connectionString)
            .Options;

        Context = new AppDbContext(options);
        await Context.Database.EnsureCreatedAsync();
    }

    public async Task DisposeAsync()
    {
        await Context.Database.EnsureDeletedAsync();
        await Context.DisposeAsync();
    }

    public async Task ResetAsync()
    {
        Context.Users.RemoveRange(Context.Users);
        await Context.SaveChangesAsync();
    }
}
```

---

## API Integration Tests

```csharp
public class UsersApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient client;

    public UsersApiTests(WebApplicationFactory<Program> factory)
    {
        var configuredFactory = factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                services.RemoveAll<IEmailService>();
                services.AddSingleton<IEmailService, FakeEmailService>();
            });
        });

        this.client = configuredFactory.CreateClient();
    }

    [Fact]
    public async Task GetUser_WhenExists_Returns200WithUser()
    {
        var response = await this.client.GetAsync("/api/users/1");

        response.StatusCode.Should().Be(HttpStatusCode.OK);
        var user = await response.Content.ReadFromJsonAsync<UserDto>();
        user.Should().NotBeNull();
        user!.Id.Should().Be(1);
    }
}
```

---

## WireMock for HTTP Mocking

### Setup in WebApplicationFactory

```csharp
public class SmsApiFactory<T> : WebApplicationFactory<T> where T : class
{
    private WireMockServer wireMockServer;

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureTestServices(services =>
        {
            this.wireMockServer = WireMockServer.Start();
            ConfigureHttpClients(services, this.wireMockServer);
            services.AddSingleton(this.wireMockServer);
        });
    }

    protected override void Dispose(bool disposing)
    {
        if (disposing) { this.wireMockServer?.Stop(); this.wireMockServer?.Dispose(); }
        base.Dispose(disposing);
    }
}
```

### Stub Patterns

```csharp
// Stub GET request
wireMockServer
    .Given(Request.Create().WithPath("/api/cases/123").UsingGet())
    .RespondWith(Response.Create()
        .WithStatusCode(200)
        .WithBodyAsJson(new { caseId = "123", status = "Active" }));

// Stub POST request
wireMockServer
    .Given(Request.Create().WithPath("/api/cases/validate").UsingPost())
    .RespondWith(Response.Create()
        .WithStatusCode(200)
        .WithBodyAsJson(new { isValid = true }));
```

### Stub Helper Extensions

```csharp
public static class CaseManagementStubs
{
    public static void StubValidateCaseSuccess(this WireMockServer server, string caseId)
    {
        server
            .Given(Request.Create().WithPath($"/api/cases/{caseId}/validate").UsingPost())
            .RespondWith(Response.Create()
                .WithStatusCode(200)
                .WithBodyAsJson(new { isValid = true, caseId }));
    }

    public static void StubCaseNotFound(this WireMockServer server, string caseId)
    {
        server
            .Given(Request.Create().WithPath($"/api/cases/{caseId}/validate").UsingPost())
            .RespondWith(Response.Create()
                .WithStatusCode(404)
                .WithBodyAsJson(new { error = "Case not found" }));
    }
}
```

---

## HttpClient Mocking Fixture

For mocking downstream HTTP service calls:

```csharp
public class HttpClientFixture
{
    private readonly MockHttpMessageHandler handler = new();

    public HttpClientFixture SetupJson(
        string method, string path,
        object payload, HttpStatusCode statusCode = HttpStatusCode.OK)
    {
        this.handler.When(new HttpMethod(method), path)
            .Respond(statusCode, "application/json",
                JsonSerializer.Serialize(payload));
        return this;
    }

    public HttpClientFixture SetupStatus(
        string method, string path, HttpStatusCode statusCode)
    {
        this.handler.When(new HttpMethod(method), path)
            .Respond(statusCode);
        return this;
    }

    public HttpClient CreateClient() => this.handler.ToHttpClient();
}
```

### Usage

```csharp
var fixture = new HttpClientFixture()
    .SetupStatus("POST", "api/cases/123/validate", HttpStatusCode.OK);

var httpClient = fixture.CreateClient();
var sut = new CaseValidationService(httpClient, NullLogger<CaseValidationService>.Instance);
```

---

## Review Checklist

**Structure**: Test file mirrors source, naming follows convention.

**Setup**: Fixture classes, Builder pattern, no magic values.

**Test Body**: Clear AAA sections, FluentAssertions, verify side effects.

**Mocking**: NSubstitute (not Moq), return Faker builders, WireMock for HTTP.

**Coverage**: Happy path, error paths, edge cases.

---

## Integration Test Resource Lifecycle

Static test fixtures implementing `IDisposable`/`IAsyncDisposable` MUST be disposed in `[AssemblyCleanup]` or equivalent teardown.

Rules:
- `WebApplicationFactory` instances MUST be disposed after all tests complete
- `HttpClient` instances from factory MUST create fresh instances per call (not cached in static field)
- `TimeoutException` in readiness loops MUST include the inner exception from the last health check attempt
- Cosmos SDK takes ownership of `HttpClient` passed to `CosmosClientOptions.HttpClientFactory` -- do not share or dispose externally

Anti-pattern: Static `WebApplicationFactory` never disposed. `HttpClient` reused across tests but Cosmos SDK disposes it internally, causing `ObjectDisposedException`.
