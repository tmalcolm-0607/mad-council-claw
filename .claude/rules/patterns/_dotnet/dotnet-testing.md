---
paths:
  - "**/*.Tests/**/*.cs"
  - "**/*.Tests.csproj"
  - "**/test/**/*.cs"
  - "**/spec.md"
---

# .NET Testing Rules

> **Canonical-derived: derived from `lens-aspnet-structure` / `lens-telemetry` skill bodies.** This file documents LENS-canonical patterns (MSTest framework selection per LENS-CMS reference). The authoritative source is the LENS-Common SKILL.md (PR 5158460). When this kit drifts from canonical, canonical wins.

Standards for testing in .NET enterprise applications.

## Test Framework Standard

**Recommended**: MSTest + NSubstitute + FluentAssertions

| Component | Package | Notes |
|-----------|---------|-------|
| Framework | `MSTest.TestFramework`, `MSTest.TestAdapter` | Standard for enterprise .NET services |
| Mocking | `NSubstitute` | Preferred over Moq for new projects |
| Assertions | `FluentAssertions` | Required for readable assertions |
| Coverage | `coverlet.collector` | Standard coverage collection |
| Test SDK | `Microsoft.NET.Test.Sdk` | Required for all test projects |

**Note**: xUnit is acceptable for existing projects but MSTest is preferred for new development.

---

## Test Project Structure

**Convention**: Test projects are in a separate `test/` branch parallel to `dev/`, not nested within source folders. Shared test utilities live in `shared/`.

```
sources/
├── dev/{ServiceName}/src/
│   ├── API/
│   │   └── Controllers/
│   │       └── UsersController.cs
│   ├── BusinessLogic/
│   │   └── Services/
│   │       └── UserService.cs
│   ├── DataAccess/
│   │   └── Repositories/
│   │       └── UserRepository.cs
│   └── Common/
│       └── Models/
├── test/{ServiceName}/
│   ├── API.Tests/
│   │   └── Controllers/
│   │       └── UsersControllerTests.cs
│   ├── BusinessLogic.Tests/
│   │   └── Services/
│   │       └── UserServiceTests.cs
│   └── DataAccess.Tests/
│       └── Repositories/
│           └── UserRepositoryTests.cs
└── shared/
    └── {ServiceName}.Test.Tools/
        ├── Generators/
        │   └── CoreGenerators.cs      # Bogus Faker<T> generators
        ├── Fixtures/
        │   ├── CaseServiceFixture.cs  # Service-specific fixtures
        │   └── NoteServiceFixture.cs
        └── Extensions/
            └── AssertionExtensions.cs
```

### Project Reference Pattern

Test projects reference source projects using relative paths (4 levels up):

```xml
<!-- In API.Tests.csproj -->
<ProjectReference Include="..\..\..\..\dev\{ServiceName}\src\API\API.csproj" />
```

### Why Mirror Structure?

| Benefit | Explanation |
|---------|-------------|
| Discoverability | Tests are easy to find |
| Coverage gaps visible | Missing test file = missing tests |
| IDE navigation | Go to test file for any source file |
| Review efficiency | Reviewer knows where to look |

---

## Test Naming Convention

```
Method_Scenario_Expected
```

### Components

| Component | Description | Example |
|-----------|-------------|---------|
| **Method** | Method being tested | `GetUserById` |
| **Scenario** | Condition or input state | `WhenUserDoesNotExist` |
| **Expected** | Expected outcome | `ThrowsNotFoundException` |

### Good Examples

```csharp
// Clear what's being tested, under what condition, with what result
public async Task GetUserById_WhenUserExists_ReturnsUser()
public async Task GetUserById_WhenUserDoesNotExist_ThrowsNotFoundException()
public async Task CreateUser_WhenEmailAlreadyExists_ThrowsConflictException()
public async Task ValidateOrder_WhenQuantityIsZero_ReturnsValidationError()
public void Constructor_WhenRepositoryIsNull_ThrowsArgumentNullException()
```

### Bad Examples

```csharp
// WRONG: Vague names
public async Task TestGetUser()  // What scenario? What's expected?
public async Task GetUserTest()  // Same problem
public async Task Test1()        // Completely meaningless

// WRONG: Missing scenario
public async Task GetUserById_ReturnsUser()  // When?

// WRONG: Missing expected outcome
public async Task GetUserById_WhenUserExists()  // And then what?
```

---

## Fixture Pattern with CreateSUT()

Encapsulate test setup in fixture classes with a single point of SUT (System Under Test) creation.

### MSTest Fixture Pattern (Recommended)

The fixture holds mock dependencies and provides fluent configuration methods:

```csharp
/// <summary>
/// Fixture for CaseService tests. All mocks are exposed as properties.
/// CreateSUT() is the single point of SUT creation.
/// </summary>
public class CaseServiceFixture
{
    public ICaseRepository CaseRepository { get; }
    public INoteRepository NoteRepository { get; }
    public ILogger<CaseService> Logger { get; }

    public CaseServiceFixture()
    {
        CaseRepository = Substitute.For<ICaseRepository>();
        NoteRepository = Substitute.For<INoteRepository>();
        Logger = Substitute.For<ILogger<CaseService>>();
    }

    /// <summary>
    /// Single point of SUT creation - ensures consistent construction.
    /// </summary>
    public CaseService CreateSUT() => new(CaseRepository, NoteRepository, Logger);

    // Fluent configuration methods - return 'this' for chaining
    public CaseServiceFixture WithCase(Case @case)
    {
        CaseRepository.GetByIdAsync(@case.Id, Arg.Any<CancellationToken>())
            .Returns(@case);
        return this;
    }

    public CaseServiceFixture WithCaseNotFound(string caseId)
    {
        CaseRepository.GetByIdAsync(caseId, Arg.Any<CancellationToken>())
            .Returns((Case?)null);
        return this;
    }

    public CaseServiceFixture WithNotes(string caseId, params Note[] notes)
    {
        NoteRepository.GetByCaseIdAsync(caseId, Arg.Any<CancellationToken>())
            .Returns(notes.ToList());
        return this;
    }
}
```

### Using the Fixture in MSTest

```csharp
[TestClass]
[TestCategory("Unit")]
public class CaseServiceTests
{
    private CaseServiceFixture fixture = null!;

    [TestInitialize]
    public void TestInit()
    {
        this.fixture = new CaseServiceFixture();
    }

    [TestMethod]
    public async Task GetCaseById_WhenCaseExists_ReturnsCase()
    {
        // Arrange
        var expectedCase = CoreGenerators.CaseGenerator.Generate();
        this.fixture.WithCase(expectedCase);
        var sut = this.fixture.CreateSUT();

        // Act
        // LENS-canonical: handler returns the domain type directly; failures throw typed exceptions.
        var result = await sut.GetByIdAsync(expectedCase.Id, CancellationToken.None);

        // Assert — concrete return shape, no Result<T> API
        result.Should().BeEquivalentTo(expectedCase);
    }

    [TestMethod]
    public async Task GetCaseById_WhenCaseDoesNotExist_ThrowsCaseNotFound()
    {
        // Arrange
        var caseId = "nonexistent-case";
        this.fixture.WithCaseNotFound(caseId);
        var sut = this.fixture.CreateSUT();

        // Act
        Func<Task> act = async () => await sut.GetByIdAsync(caseId, CancellationToken.None);

        // Assert — typed-exception assertion (controller catch-ladder maps to 404)
        await act.Should().ThrowAsync<CaseNotFoundException>()
            .WithMessage("*not found*");
    }

    [TestMethod]
    public async Task GetCaseWithNotes_WhenCaseHasNotes_ReturnsAllNotes()
    {
        // Arrange
        var expectedCase = CoreGenerators.CaseGenerator.Generate();
        var notes = CoreGenerators.NoteGenerator.Generate(3);
        this.fixture
            .WithCase(expectedCase)
            .WithNotes(expectedCase.Id, notes.ToArray());
        var sut = this.fixture.CreateSUT();

        // Act
        var result = await sut.GetWithNotesAsync(expectedCase.Id, CancellationToken.None);

        // Assert — concrete return shape
        result.Notes.Should().HaveCount(3);
    }
}
```

### xUnit to MSTest Mapping

When migrating from xUnit or reading xUnit-based tests:

| xUnit | MSTest | Notes |
|-------|--------|-------|
| `[Fact]` | `[TestMethod]` | Basic test method |
| `[Theory]` | `[DataTestMethod]` | Parameterized test |
| `[InlineData(...)]` | `[DataRow(...)]` | Test data |
| `[MemberData]` | `[DynamicData]` | Complex data sources |
| `Assert.Equal(expected, actual)` | `Assert.AreEqual(expected, actual)` | Parameter order differs |
| `Assert.True(x)` | `Assert.IsTrue(x)` | Boolean assertion |
| `Assert.False(x)` | `Assert.IsFalse(x)` | Boolean assertion |
| `Assert.NotNull(x)` | `Assert.IsNotNull(x)` | Null check |
| `Assert.Null(x)` | `Assert.IsNull(x)` | Null check |
| `Assert.Throws<T>()` | `Assert.ThrowsException<T>()` | Exception assertion |
| `IClassFixture<T>` | `[TestInitialize]` + field | Shared fixture |
| `IAsyncLifetime` | `[TestInitialize]`/`[TestCleanup]` | Async setup/teardown |
| `[Collection("...")]` | `[TestClass]` grouping | Test isolation |

### Legacy xUnit Pattern (Reference Only)

```csharp
// xUnit pattern - for reference when reading existing code
public abstract class TestFixture<TSubject> : IAsyncLifetime
    where TSubject : class
{
    protected TSubject Subject { get; private set; } = null!;
    protected Mock<ILogger<TSubject>> LoggerMock { get; } = new();

    public virtual Task InitializeAsync()
    {
        Subject = CreateSubject();
        return Task.CompletedTask;
    }

    public virtual Task DisposeAsync() => Task.CompletedTask;

    protected abstract TSubject CreateSubject();
}
```

---

## Builder Pattern for Test Data

Never use raw `new` for test entities. Use builders for clarity and maintainability.

### Builder Implementation

```csharp
public class UserBuilder
{
    private int id = 1;
    private string email = "test@example.com";
    private string name = "Test User";
    private bool isActive = true;
    private DateTime createdAt = DateTime.UtcNow;

    public UserBuilder WithId(int id)
    {
        this.id = id;
        return this;
    }

    public UserBuilder WithEmail(string email)
    {
        this.email = email;
        return this;
    }

    public UserBuilder WithName(string name)
    {
        this.name = name;
        return this;
    }

    public UserBuilder Inactive()
    {
        this.isActive = false;
        return this;
    }

    public UserBuilder CreatedAt(DateTime createdAt)
    {
        this.createdAt = createdAt;
        return this;
    }

    public User Build()
    {
        return new User
        {
            Id = this.id,
            Email = this.email,
            Name = this.name,
            IsActive = this.isActive,
            CreatedAt = this.createdAt
        };
    }

    // Implicit conversion for convenience
    public static implicit operator User(UserBuilder builder) => builder.Build();
}
```

### Domain Builders

```csharp
// CaseBuilder for Case entity
public class CaseBuilder
{
    private string id = "case-001";
    private string title = "Default Title";
    private CaseStatus status = CaseStatus.Open;
    private string ownerId = "owner-001";
    private DateTimeOffset createdAt = DateTimeOffset.UtcNow;

    public CaseBuilder WithId(string id) { this.id = id; return this; }
    public CaseBuilder WithTitle(string title) { this.title = title; return this; }
    public CaseBuilder WithStatus(CaseStatus status) { this.status = status; return this; }
    public CaseBuilder WithOwner(string ownerId) { this.ownerId = ownerId; return this; }
    public CaseBuilder CreatedAt(DateTimeOffset createdAt) { this.createdAt = createdAt; return this; }
    public CaseBuilder Closed() { this.status = CaseStatus.Closed; return this; }

    public Case Build() => new Case
    {
        Id = this.id,
        Title = this.title,
        Status = this.status,
        OwnerId = this.ownerId,
        CreatedAt = this.createdAt
    };

    public static implicit operator Case(CaseBuilder builder) => builder.Build();
}

// NoteBuilder for Note entity
public class NoteBuilder
{
    private string id = "note-001";
    private string caseId = "case-001";
    private string content = "Default note content";
    private string authorId = "author-001";
    private DateTimeOffset createdAt = DateTimeOffset.UtcNow;

    public NoteBuilder WithId(string id) { this.id = id; return this; }
    public NoteBuilder ForCase(string caseId) { this.caseId = caseId; return this; }
    public NoteBuilder WithContent(string content) { this.content = content; return this; }
    public NoteBuilder ByAuthor(string authorId) { this.authorId = authorId; return this; }
    public NoteBuilder CreatedAt(DateTimeOffset createdAt) { this.createdAt = createdAt; return this; }

    public Note Build() => new Note
    {
        Id = this.id,
        CaseId = this.caseId,
        Content = this.content,
        AuthorId = this.authorId,
        CreatedAt = this.createdAt
    };

    public static implicit operator Note(NoteBuilder builder) => builder.Build();
}

// CommunicationBuilder for Communication entity
public class CommunicationBuilder
{
    private string id = "comm-001";
    private string caseId = "case-001";
    private CommunicationType type = CommunicationType.Email;
    private CommunicationDirection direction = CommunicationDirection.Inbound;
    private DateTimeOffset timestamp = DateTimeOffset.UtcNow;

    public CommunicationBuilder WithId(string id) { this.id = id; return this; }
    public CommunicationBuilder ForCase(string caseId) { this.caseId = caseId; return this; }
    public CommunicationBuilder OfType(CommunicationType type) { this.type = type; return this; }
    public CommunicationBuilder Inbound() { this.direction = CommunicationDirection.Inbound; return this; }
    public CommunicationBuilder Outbound() { this.direction = CommunicationDirection.Outbound; return this; }
    public CommunicationBuilder At(DateTimeOffset timestamp) { this.timestamp = timestamp; return this; }

    public Communication Build() => new Communication
    {
        Id = this.id,
        CaseId = this.caseId,
        Type = this.type,
        Direction = this.direction,
        Timestamp = this.timestamp
    };
}
```

### Using Builders

```csharp
// Good: Clear, readable, self-documenting
var openCase = new CaseBuilder()
    .WithId("case-12345")
    .WithTitle("Customer complaint - billing issue")
    .WithOwner("agent-007")
    .Build();

var closedCase = new CaseBuilder()
    .WithId("case-67890")
    .WithTitle("Resolved inquiry")
    .Closed()
    .Build();

var caseNote = new NoteBuilder()
    .ForCase("case-12345")
    .WithContent("Contacted customer via phone, issue resolved")
    .ByAuthor("agent-007")
    .Build();

var emailCommunication = new CommunicationBuilder()
    .ForCase("case-12345")
    .OfType(CommunicationType.Email)
    .Inbound()
    .Build();

// Bad: Magic values, unclear intent
var caseEntity = new Case
{
    Id = "case-12345",
    Title = "Test",
    Status = CaseStatus.Open,
    OwnerId = "owner-001",
    CreatedAt = DateTimeOffset.UtcNow
};
```

---

## Test Structure (Arrange-Act-Assert)

Every test follows AAA pattern with clear section comments.

```csharp
[Fact]
public async Task CreateUser_WhenEmailAlreadyExists_ThrowsConflictException()
{
    // Arrange
    var existingUser = new UserBuilder()
        .WithEmail("existing@example.com")
        .Build();

    this.fixture.RepositoryMock
        .Setup(r => r.GetByEmailAsync(existingUser.Email, It.IsAny<CancellationToken>()))
        .ReturnsAsync(existingUser);

    var request = new CreateUserRequest { Email = existingUser.Email };

    // Act
    var act = () => this.fixture.Subject.CreateUserAsync(request, CancellationToken.None);

    // Assert
    await act.Should().ThrowAsync<ConflictException>()
        .WithMessage("*email*already*");
}
```

---

## Assertion Library

Use FluentAssertions for readable, expressive assertions.

### Good Assertions

```csharp
// Object equality
result.Should().BeEquivalentTo(expected);

// Exceptions
await act.Should().ThrowAsync<NotFoundException>()
    .WithMessage("User not found.");

// Collections
users.Should().HaveCount(3);
users.Should().ContainSingle(u => u.IsActive);
users.Should().BeInAscendingOrder(u => u.Name);

// Null checks
result.Should().NotBeNull();
result.Should().BeNull();

// String assertions
response.Message.Should().Contain("validation");
response.Message.Should().StartWith("Error:");
```

### Bad Assertions

```csharp
// WRONG: Less readable, poor failure messages
Assert.Equal(expected, result);
Assert.NotNull(result);
Assert.Throws<NotFoundException>(() => subject.GetUser(id));

// WRONG: Manual null check
if (result == null)
    Assert.Fail("Result was null");
```

---

## Mock Verification

Verify interactions when behavior matters, not just return values.

### When to Verify

| Scenario | Verify? | Why |
|----------|---------|-----|
| Method should be called | Yes | Confirms side effect |
| Method should NOT be called | Yes | Prevents unwanted behavior |
| Return value is sufficient | No | Over-specification |
| Exact parameter values matter | Yes | Ensures correct data passed |

### Examples

```csharp
[Fact]
public async Task CreateUser_WhenValid_SendsWelcomeEmail()
{
    // Arrange
    var request = new CreateUserRequest { Email = "new@example.com" };
    this.fixture.SetupUserDoesNotExist(request.Email);

    // Act
    await this.fixture.Subject.CreateUserAsync(request, CancellationToken.None);

    // Assert - verify the email was sent
    this.fixture.EmailServiceMock.Verify(
        e => e.SendWelcomeEmailAsync(
            It.Is<string>(email => email == request.Email),
            It.IsAny<CancellationToken>()),
        Times.Once);
}

[Fact]
public async Task CreateUser_WhenValidationFails_DoesNotSendEmail()
{
    // Arrange
    var request = new CreateUserRequest { Email = "" };  // Invalid

    // Act
    var act = () => this.fixture.Subject.CreateUserAsync(request, CancellationToken.None);

    // Assert
    await act.Should().ThrowAsync<ValidationException>();
    this.fixture.EmailServiceMock.Verify(
        e => e.SendWelcomeEmailAsync(It.IsAny<string>(), It.IsAny<CancellationToken>()),
        Times.Never);
}
```

---

## Integration Test Setup

For tests that require real database or external services.

### Database Fixture

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
        // Clear all tables between tests
        Context.Users.RemoveRange(Context.Users);
        await Context.SaveChangesAsync();
    }
}
```

### API Integration Tests

```csharp
public class UsersApiTests : IClassFixture<WebApplicationFactory<Program>>
{
    private readonly HttpClient client;
    private readonly WebApplicationFactory<Program> factory;

    public UsersApiTests(WebApplicationFactory<Program> factory)
    {
        this.factory = factory.WithWebHostBuilder(builder =>
        {
            builder.ConfigureServices(services =>
            {
                // Replace real services with test doubles
                services.RemoveAll<IEmailService>();
                services.AddSingleton<IEmailService, FakeEmailService>();
            });
        });

        this.client = this.factory.CreateClient();
    }

    [Fact]
    public async Task GetUser_WhenExists_Returns200WithUser()
    {
        // Arrange
        var userId = 1;

        // Act
        var response = await this.client.GetAsync($"/api/users/{userId}");

        // Assert
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var user = await response.Content.ReadFromJsonAsync<UserDto>();
        user.Should().NotBeNull();
        user!.Id.Should().Be(userId);
    }
}
```

---

## Test Categories

Use `[TestCategory]` attribute to organize and filter tests.

### MSTest (Recommended)

```csharp
// Unit tests - fast, isolated
[TestClass]
[TestCategory("Unit")]
public class UserServiceTests
{
    [TestMethod]
    [TestCategory("Unit")]
    public async Task GetUserById_WhenUserExists_ReturnsUser() { }
}

// Integration tests - require database/services
[TestClass]
[TestCategory("Integration")]
public class UserRepositoryIntegrationTests { }

// Validation tests
[TestClass]
[TestCategory("Validation")]
public class CreateCaseRequestValidatorTests { }
```

### xUnit (Legacy Projects)

```csharp
// Unit tests - fast, isolated
[Trait("Category", "Unit")]
public class UserServiceTests { }
```

### Running by Category

```bash
# MSTest - Run only unit tests
dotnet test --filter "TestCategory=Unit"

# MSTest - Exclude slow tests
dotnet test --filter "TestCategory!=Slow"

# MSTest - Run validation tests only
dotnet test --filter "TestCategory=Validation"

# xUnit (legacy) - Run only unit tests
dotnet test --filter "Category=Unit"
```

---

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| `Test1`, `TestGetUser` | Unclear what's being tested | `Method_Scenario_Expected` |
| Raw `new Entity()` in tests | Magic values, duplication | Use Builder pattern |
| No fixture/setup sharing | Duplicated setup code | Use fixture classes |
| `Assert.Equal` over FluentAssertions | Poor failure messages | Use `.Should().Be()` |
| Testing implementation details | Brittle tests | Test behavior, not implementation |
| One test per class | Slow, hard to maintain | Group related tests |
| No test structure comments | Unclear sections | Use `// Arrange`, `// Act`, `// Assert` |
| Over-mocking | Tests don't reflect reality | Mock only external dependencies |
| Not testing exceptions | Missing error path coverage | Test with `.Should().ThrowAsync<>()` |
| Ignoring cancellation tokens | Incomplete API testing | Pass and verify `CancellationToken` |

---

## NSubstitute Patterns

### Substituting Interfaces

```csharp
// CORRECT: Use NSubstitute
var mockService = Substitute.For<ISasService>();

// Configure return value — the service returns the concrete response shape directly;
// failure paths throw typed HandlerException subclasses (verified with Should().ThrowAsync<>()).
mockService.CreateSasAsync(Arg.Any<SasRequest>(), Arg.Any<string>(), Arg.Any<CancellationToken>())
    .Returns(new SasResponse
    {
        SasUri = "https://storage.blob.core.windows.net/container?sv=...",
        ExpiresOn = DateTimeOffset.UtcNow.AddHours(1)
    });

// Verify call was made
await mockService.Received(1).CreateSasAsync(
    Arg.Any<SasRequest>(),
    Arg.Any<string>(),
    Arg.Any<CancellationToken>());

// Verify specific argument
await mockService.Received().CreateSasAsync(
    Arg.Is<SasRequest>(r => r.CaseId == "123-456-789"),
    Arg.Any<string>(),
    Arg.Any<CancellationToken>());
```

### Argument Matching

```csharp
// Any value
Arg.Any<string>()
Arg.Any<CancellationToken>()

// Specific value
Arg.Is<string>(x => x == "123-456-789")
Arg.Is<SasRequest>(r => r.Workload == Workload.Teams)

// Conditional matching
Arg.Is<string>(x => x.StartsWith("123"))
Arg.Is<int>(x => x > 0 && x < 100)
```

### Throwing Exceptions

```csharp
mockService.CreateSasAsync(Arg.Any<SasRequest>(), Arg.Any<string>(), Arg.Any<CancellationToken>())
    .Throws(new InvalidOperationException("Storage unavailable"));

// Test exception handling
var act = async () => await sut.ProcessAsync(request, CancellationToken.None);
await act.Should().ThrowAsync<InvalidOperationException>()
    .WithMessage("Storage unavailable");
```

---

## Bogus Test Data Generation

### CRITICAL: Return `Faker<T>` Builder, NOT Generated Data

The key pattern is returning the `Faker<T>` builder itself (not the generated data), allowing callers to customize before generation:

```csharp
// ========================================
// CORRECT: Returns Faker<T> builder - can be customized
// ========================================
public static class CoreGenerators
{
    /// <summary>
    /// Returns a Case generator. Call .Generate() to create instances.
    /// Caller can add .RuleFor() before .Generate() to customize.
    /// </summary>
    public static Faker<Case> CaseGenerator =>
        new Faker<Case>()
            .RuleFor(c => c.Id, f => f.Random.Guid().ToString())
            .RuleFor(c => c.Title, f => f.Lorem.Sentence())
            .RuleFor(c => c.Status, f => f.PickRandom<CaseStatus>())
            .RuleFor(c => c.OwnerId, f => f.Random.Guid().ToString())
            .RuleFor(c => c.CreatedAt, f => f.Date.PastOffset());

    /// <summary>
    /// Returns a Note generator.
    /// </summary>
    public static Faker<Note> NoteGenerator =>
        new Faker<Note>()
            .RuleFor(n => n.Id, f => f.Random.Guid().ToString())
            .RuleFor(n => n.CaseId, f => f.Random.Guid().ToString())
            .RuleFor(n => n.Content, f => f.Lorem.Paragraphs(2))
            .RuleFor(n => n.AuthorId, f => f.Random.Guid().ToString())
            .RuleFor(n => n.CreatedAt, f => f.Date.PastOffset());

    /// <summary>
    /// Returns a SasRequest generator.
    /// </summary>
    public static Faker<SasRequest> SasRequestGenerator =>
        new Faker<SasRequest>()
            .RuleFor(x => x.CaseId, f => $"{f.Random.Int(100, 999)}-{f.Random.Int(100, 999)}-{f.Random.Int(100, 999)}")
            .RuleFor(x => x.Workload, f => f.PickRandom<Workload>())
            .RuleFor(x => x.Scenario, f => f.PickRandom<Scenario>())
            .RuleFor(x => x.DataRegion, f => f.PickRandom<DataRegion>());
}

// ========================================
// WRONG: Returns generated object - cannot be customized!
// ========================================
public static class BadGenerators
{
    // DON'T DO THIS - caller cannot customize!
    public static Case CreateCase() =>
        new Faker<Case>()
            .RuleFor(c => c.Id, f => f.Random.Guid().ToString())
            .RuleFor(c => c.Title, f => f.Lorem.Sentence())
            .Generate();  // Too late to customize!
}
```

### Using Generators in Tests

```csharp
[TestMethod]
public async Task GetCaseById_WhenCaseExists_ReturnsCase()
{
    // Default generation - random values
    var expectedCase = CoreGenerators.CaseGenerator.Generate();

    // ... test code
}

[TestMethod]
public async Task GetCaseById_WhenCaseClosed_ReturnsClosedStatus()
{
    // Customized generation - override specific properties
    var expectedCase = CoreGenerators.CaseGenerator
        .RuleFor(c => c.Status, CaseStatus.Closed)
        .RuleFor(c => c.Title, "Specific Test Title")
        .Generate();

    // ... test code
}

[TestMethod]
public async Task ListCases_ReturnsAllCases()
{
    // Generate multiple instances
    var cases = CoreGenerators.CaseGenerator.Generate(5);

    // ... test code
}

[TestMethod]
public async Task GetCaseWithNotes_ReturnsAssociatedNotes()
{
    // Generate related entities
    var caseId = Guid.NewGuid().ToString();
    var case = CoreGenerators.CaseGenerator
        .RuleFor(c => c.Id, caseId)
        .Generate();

    var notes = CoreGenerators.NoteGenerator
        .RuleFor(n => n.CaseId, caseId)  // Link notes to case
        .Generate(3);

    // ... test code
}
```

### Bogus Strict Mode

Use strict mode to ensure all properties are configured:

```csharp
var faker = new Faker<SasRequest>()
    .StrictMode(true) // Throws if any property not configured
    .RuleFor(x => x.CaseId, f => "123-456-789")
    .RuleFor(x => x.Workload, f => Workload.Teams);
    // Missing: Scenario, DataRegion - will throw at .Generate()!
```

### Generator Organization

Place generators in the shared test tools project:

```
shared/{ServiceName}.Test.Tools/
└── Generators/
    ├── CoreGenerators.cs       # Domain entities (Case, Note, etc.)
    ├── RequestGenerators.cs    # API request DTOs
    └── ResponseGenerators.cs   # API response DTOs
```

---

## WireMock for HTTP Mocking

### Setting Up WireMock in WebApplicationFactory

```csharp
public class SmsApiFactory<TEntryPoint> : WebApplicationFactory<TEntryPoint>
    where TEntryPoint : class
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
        if (disposing)
        {
            this.wireMockServer?.Stop();
            this.wireMockServer?.Dispose();
        }
        base.Dispose(disposing);
    }
}
```

### Basic Stub Patterns

```csharp
// Stub GET request
wireMockServer
    .Given(Request.Create()
        .WithPath("/api/cases/123-456-789")
        .UsingGet())
    .RespondWith(Response.Create()
        .WithStatusCode(200)
        .WithBodyAsJson(new { caseId = "123-456-789", status = "Active" }));

// Stub POST request
wireMockServer
    .Given(Request.Create()
        .WithPath("/api/cases/validate")
        .UsingPost())
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
            .Given(Request.Create()
                .WithPath($"/api/cases/{caseId}/validate")
                .UsingPost())
            .RespondWith(Response.Create()
                .WithStatusCode(200)
                .WithBodyAsJson(new { isValid = true, caseId }));
    }

    public static void StubCaseNotFound(this WireMockServer server, string caseId)
    {
        server
            .Given(Request.Create()
                .WithPath($"/api/cases/{caseId}/validate")
                .UsingPost())
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

// Usage
var fixture = new HttpClientFixture()
    .SetupStatus("POST", "api/cases/123/validate", HttpStatusCode.OK);

var httpClient = fixture.CreateClient();
var sut = new CaseValidationService(httpClient, NullLogger<CaseValidationService>.Instance);
```

---

## What to Mock vs Real Implementations

### Mock External Dependencies

**Always mock:**
- External APIs (Case Management API, Azure Storage, Key Vault)
- Database access
- Time-dependent operations (`ISystemClock`, `DateTime.UtcNow`)
- HTTP clients (`IHttpClientFactory`)

### Use Real Implementations

**Don't mock:**
- DTOs, POCOs, value objects
- Domain logic (business rules)
- Simple validators without external dependencies
- Configuration classes

```csharp
// CORRECT: Use real request object
var request = new SasRequest
{
    CaseId = "123-456-789",
    Workload = Workload.Teams,
    Scenario = Scenario.Ld
};

// WRONG: Mocking simple objects
var mockRequest = Substitute.For<SasRequest>(); // Unnecessary!
```

---

## Code Review Checklist

```
+===========================================================================+
|  TESTING REVIEW                                                           |
|                                                                           |
|  Structure:                                                               |
|  [ ] Test file mirrors source file location                               |
|  [ ] Test class name matches source class + "Tests"                       |
|  [ ] Test methods follow Method_Scenario_Expected naming                  |
|                                                                           |
|  Setup:                                                                   |
|  [ ] Fixture classes encapsulate setup                                    |
|  [ ] Builder pattern used for test data                                   |
|  [ ] No magic values - use named constants or builders                    |
|                                                                           |
|  Test Body:                                                               |
|  [ ] Clear Arrange/Act/Assert sections                                    |
|  [ ] FluentAssertions used for assertions                                 |
|  [ ] Mock verification only when side effects matter                      |
|  [ ] Exception paths tested with ThrowAsync                               |
|                                                                           |
|  Mocking:                                                                 |
|  [ ] Use NSubstitute (NOT Moq) for new code                               |
|  [ ] Return Faker<T> builders, not generated objects                      |
|  [ ] WireMock for HTTP mocking in integration tests                       |
|  [ ] HttpClient mocking for downstream service calls                      |
|                                                                           |
|  Coverage:                                                                |
|  [ ] Happy path tested                                                    |
|  [ ] Error/exception paths tested                                         |
|  [ ] Edge cases (null, empty, boundary values) tested                     |
|  [ ] Constructor validation tested                                        |
+===========================================================================+
```

---

## Test Helper Deduplication

Common test helpers (Create*, Get*, List*, Patch*, Delete*) MUST live in a shared base class or helper file, not duplicated across scenario test classes.

When creating a new test helper method, SEARCH for existing methods with similar signatures in the same test project first. If a match exists with >80% overlap, extract to shared code.

Anti-pattern: `PatchCaseAsync`, `CreateDftAsync`, `DeleteCaseAsync` copy-pasted across 4 test classes. When one copy is updated (e.g., new required parameter), others silently break or drift.
