---
paths:
  - "**/*.Tests/**/*.cs"
  - "**/e2e/**/*.spec.ts"
  - "**/tests/**/*.spec.ts"
  - "**/spec.md"
  - "**/plan.md"
---

# Behavioral Testing Patterns

Comprehensive patterns for API behavioral testing, state machine validation, E2E testing, and contract compliance testing across backend (.NET) and frontend (React/Playwright).

---

## Overview

Behavioral tests validate **how the system behaves** under various conditions, not just individual units. These patterns were extracted from the `001-behavioral-test-coverage` feature implementation.

**Key Principles**:
- Test complete workflows, not just units
- Validate state transitions exhaustively
- Ensure API contracts conform to standards (RFC 7807)
- Use real dependencies (databases, event stores, backend APIs) - minimal mocking
- Gracefully skip tests for unimplemented features
- Test user-visible behavior, not implementation details

---

# Backend Testing Patterns (.NET)

## 1. State Transition Validation

Test all valid transitions and explicitly test invalid transitions are rejected.

### Pattern: Valid Transition Test

```csharp
/// <summary>
/// Checkpoint 5: Starting a session transitions it from Created to Active.
/// Valid transition: Created -> Active via POST /v1/sessions/{id}/start.
/// </summary>
[SkippableFact]
public async Task SessionStatus_ValidTransition_CreatedToActive_Succeeds()
{
    // Arrange - Create entity in initial state
    var sessionId = await CreateTestSessionAsync();
    Skip.If(sessionId == Guid.Empty, "Could not create test session");

    // Act - Trigger transition
    var response = await _client.PostAsJsonAsync(
        $"/v1/sessions/{sessionId}/start",
        new { initial_scene_id = Guid.NewGuid() });

    // Assert - Endpoint exists and transition succeeds
    Skip.If(response.StatusCode == HttpStatusCode.NotFound,
        "Session start endpoint not yet implemented");

    response.StatusCode.Should().BeInRange(
        HttpStatusCode.OK,
        HttpStatusCode.NoContent,
        "starting a Created session should succeed");
}
```

### Pattern: Invalid Transition Test

```csharp
/// <summary>
/// Checkpoint 5: Attempting to end a Created session (skipping Active) should fail.
/// Invalid transition: Created -> Concluded (must go through Active first).
/// </summary>
[SkippableFact]
public async Task SessionStatus_InvalidTransition_CreatedToConcluded_Returns400Or409()
{
    // Arrange - Create entity in initial state
    var sessionId = await CreateTestSessionAsync();
    Skip.If(sessionId == Guid.Empty, "Could not create test session");

    // Act - Attempt invalid transition (skip intermediate state)
    var response = await _client.PostAsJsonAsync(
        $"/v1/sessions/{sessionId}/end",
        new { reason = "test" });

    // Assert - Endpoint rejects invalid transition
    Skip.If(response.StatusCode == HttpStatusCode.NotFound,
        "Session end endpoint not yet implemented");

    var statusCode = (int)response.StatusCode;
    statusCode.Should().BeInRange(400, 422,
        "ending a session that hasn't been started should return client error");

    // Validate RFC 7807 error response
    var content = await response.Content.ReadAsStringAsync();
    AssertProblemDetailsCoreMinimal(content, statusCode);
}
```

### Transition Matrix Coverage

For each state machine, test:
1. ✅ Every valid transition (one test per transition)
2. ❌ Every invalid transition (explicit rejection tests)
3. 🔄 State consistency after event replay (event sourcing validation)

**Example State Machine**: Session Status
- States: `Created → Active → Concluded → Archived`
- Valid transitions: 3 tests
- Invalid transitions: 9 tests (all other combinations)
- Event replay: 1 test

---

## 2. RFC 7807 Error Contract Testing

All API error responses MUST conform to RFC 7807 Problem Details format.

### Pattern: Error Response Validation

```csharp
/// <summary>
/// Helper to validate RFC 7807 Problem Details response.
/// Checks for type, title, status, and detail fields.
/// NOTE: ASP.NET model validation returns 'errors' instead of 'detail'.
/// </summary>
private static void AssertProblemDetailsCoreMinimal(string content, int expectedStatus)
{
    content.Should().NotBeNullOrEmpty("error responses should have a body");

    var json = JsonDocument.Parse(content);
    var root = json.RootElement;

    // Required fields per RFC 7807
    root.TryGetProperty("type", out var type).Should().BeTrue(
        "RFC 7807 requires 'type' field");
    type.GetString().Should().NotBeNullOrEmpty();

    root.TryGetProperty("title", out var title).Should().BeTrue(
        "RFC 7807 requires 'title' field");
    title.GetString().Should().NotBeNullOrEmpty();

    root.TryGetProperty("status", out var status).Should().BeTrue(
        "RFC 7807 requires 'status' field");
    status.GetInt32().Should().Be(expectedStatus);

    // 'detail' is optional but common - OR 'errors' for model validation
    var hasDetail = root.TryGetProperty("detail", out _);
    var hasErrors = root.TryGetProperty("errors", out _);
    (hasDetail || hasErrors).Should().BeTrue(
        "RFC 7807 should include 'detail' or 'errors' for context");
}
```

### Pattern: Shared ProblemDetails Assertions

Create reusable assertion helpers in `Tests.Shared/Assertions/`:

```csharp
public static class ProblemDetailsAssertions
{
    public static void ShouldBeProblemDetails(
        this HttpResponseMessage response,
        HttpStatusCode expectedStatus,
        string? expectedType = null)
    {
        response.StatusCode.Should().Be(expectedStatus);

        var content = response.Content.ReadAsStringAsync().GetAwaiter().GetResult();
        var problem = JsonSerializer.Deserialize<ProblemDetails>(content);

        problem.Should().NotBeNull();
        problem!.Type.Should().NotBeNullOrEmpty();
        problem.Title.Should().NotBeNullOrEmpty();
        problem.Status.Should().Be((int)expectedStatus);

        if (expectedType != null)
            problem.Type.Should().Contain(expectedType);
    }
}
```

Usage:
```csharp
response.ShouldBeProblemDetails(HttpStatusCode.BadRequest, "validation-error");
```

---

## 3. Graceful Endpoint Skipping (.NET)

Use `[SkippableFact]` and `Skip.If()` to mark tests for unimplemented features.

### Pattern: Feature Detection

```csharp
[SkippableFact]
public async Task FeatureName_Scenario_ExpectedBehavior()
{
    // Arrange
    var testData = await SetupTestDataAsync();

    // Act
    var response = await _client.PostAsJsonAsync(url, request);

    // Assert - Check if endpoint exists
    Skip.If(response.StatusCode == HttpStatusCode.NotFound,
        "Endpoint not yet implemented");
    Skip.If(response.StatusCode == HttpStatusCode.MethodNotAllowed,
        "Endpoint does not accept POST method - may not exist");
    Skip.If(response.StatusCode == HttpStatusCode.UnsupportedMediaType,
        "Endpoint returned 415 - request format may have changed");

    // If endpoint exists, verify behavior
    response.IsSuccessStatusCode.Should().BeTrue(
        "endpoint should succeed for valid request");
}
```

### Pattern: Infrastructure Availability Check

```csharp
public class DatabaseDependentTests : IAsyncLifetime
{
    public async Task InitializeAsync()
    {
        // Check if required infrastructure is available
        if (!await IsCosmosEmulatorAvailable())
            Skip.If(true, "Cosmos emulator not available - skipping database tests");

        // Initialize test fixtures only if infrastructure available
        await SetupDatabaseAsync();
    }

    private static async Task<bool> IsCosmosEmulatorAvailable()
    {
        try
        {
            using var client = new CosmosClient(
                TestCosmosEmulator.Endpoint,
                TestCosmosEmulator.AuthKey,
                new CosmosClientOptions { ConnectionMode = ConnectionMode.Gateway });
            await client.ReadAccountAsync();
            return true;
        }
        catch
        {
            return false;
        }
    }
}
```

---

## 4. Validation Checkpoint Matrix

Map each validation rule to specific test methods for traceability.

### Pattern: Checkpoint Test Documentation

```csharp
/// <summary>
/// Tests validation checkpoints 5-8: State Transition validation
/// - Checkpoint 5: Session status transitions (Created -> Active -> Concluded -> Archived)
/// - Checkpoint 6: Scene lifecycle transitions (Pending -> Active -> Closing -> Complete)
/// - Checkpoint 7: Combat state transitions (Initiative -> PlayerTurn -> GMTurn -> Resolution)
/// - Checkpoint 8: Character state transitions (Healthy -> Injured -> Downed -> Dead)
/// </summary>
/// <remarks>
/// Each checkpoint maps to 3-4 test methods validating valid/invalid transitions.
/// See docs/08-TESTING-VALIDATION/validation-checkpoints.md for full matrix.
/// </remarks>
[Collection("Integration")]
[Trait("Category", "Validation")]
public sealed class StateTransitionValidationTests { }
```

### Pattern: Coverage Matrix

Maintain a mapping document (e.g., `validation-coverage-matrix.md`):

```markdown
| Checkpoint | Rule | Test Method | Status |
|------------|------|-------------|--------|
| 5.1 | Session: Created -> Active allowed | `SessionStatus_ValidTransition_CreatedToActive_Succeeds` | ✅ Pass |
| 5.2 | Session: Created -> Concluded forbidden | `SessionStatus_InvalidTransition_CreatedToConcluded_Returns400` | ✅ Pass |
| 5.3 | Session: Active -> Concluded allowed | `SessionStatus_ValidTransition_ActiveToConcluded_Succeeds` | ✅ Pass |
| 6.1 | Scene: Pending -> Active allowed | `SceneLifecycle_ValidTransition_PendingToActive_Succeeds` | ⏭️ Skipped (endpoint missing) |
```

---

## 5. API Behavioral Testing

Test all scenarios for each API endpoint: success, errors, edge cases.

### Pattern: Controller Test Suite Structure

```csharp
/// <summary>
/// Integration tests for SessionsController API endpoints.
/// Tests full request/response cycle with real database and event store.
///
/// URL patterns (no /api prefix):
///   POST /v1/sessions - Create session
///   GET  /v1/sessions/{id} - Get session
///   POST /v1/sessions/{id}/start - Start session
///   POST /v1/sessions/{id}/end - End session
///   DELETE /v1/sessions/{id} - Delete session
/// </summary>
[Collection("Integration")]
[Trait("Category", "Integration")]
public sealed class SessionsControllerTests : IClassFixture<IntegrationTestFixture>
{
    private readonly IntegrationTestFixture _fixture;
    private HttpClient _client = null!;
    private string _accessToken = null!;

    // Test structure: One region per endpoint
    #region POST /v1/sessions - Create Session

    [SkippableFact]
    public async Task CreateSession_ValidRequest_Returns201Created() { }

    [SkippableFact]
    public async Task CreateSession_MissingRequiredField_Returns400BadRequest() { }

    [SkippableFact]
    public async Task CreateSession_Unauthenticated_Returns401Unauthorized() { }

    #endregion

    #region POST /v1/sessions/{id}/start - Start Session

    [SkippableFact]
    public async Task StartSession_ValidRequest_Returns200OK() { }

    [SkippableFact]
    public async Task StartSession_NonExistentSession_Returns404NotFound() { }

    [SkippableFact]
    public async Task StartSession_AlreadyActive_Returns409Conflict() { }

    #endregion
}
```

### Pattern: Test Scenarios per Endpoint

For each endpoint, test:
1. ✅ **Success scenarios** (200, 201, 204)
2. ❌ **Client errors** (400, 401, 403, 404, 409, 422)
3. 🔍 **Edge cases** (empty lists, boundary values, race conditions)
4. 🔒 **Authorization** (unauthenticated, forbidden, owner-only)

---

## 6. AI Output Validation Testing

Test AI validators with mock responses (deterministic, no external API calls).

### Pattern: Mock AI Service

```csharp
public class MockAIService : IAIService
{
    private readonly Dictionary<string, string> _responses = new();

    public void AddMockResponse(string prompt, string response)
    {
        _responses[prompt] = response;
    }

    public async Task<string> GenerateAsync(string prompt, CancellationToken ct = default)
    {
        if (_responses.TryGetValue(prompt, out var response))
            return await Task.FromResult(response);

        throw new InvalidOperationException($"No mock response for prompt: {prompt}");
    }
}
```

### Pattern: Grounding Validator Test

```csharp
[Trait("Category", "AIValidation")]
public class GroundingValidatorTests
{
    [Fact]
    public async Task Validate_MentionsNonExistentCharacter_ReturnsViolation()
    {
        // Arrange - Set up known game state
        var gameState = new GameState { Characters = new[] { "Theron", "Lyra" } };
        var validator = new GroundingValidator();
        var aiOutput = "Gandalf casts a spell on the orc.";

        // Act
        var result = await validator.ValidateAsync(aiOutput, gameState);

        // Assert
        result.IsValid.Should().BeFalse();
        result.Violations.Should().Contain(v =>
            v.Contains("Gandalf") && v.Contains("unknown entity"));
    }
}
```

---

## 7. Backend Test Fixtures and Builders

### Pattern: Integration Test Fixture

```csharp
public class IntegrationTestFixture : IAsyncLifetime
{
    private readonly WebApplicationFactory<Program> _factory;

    public IntegrationTestFixture()
    {
        _factory = new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.ConfigureServices(services =>
                {
                    // Replace real dependencies with test doubles
                    services.AddSingleton<IAIService, MockAIService>();

                    // Use Cosmos DB emulator for integration tests
                    // Docker image: mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:vnext-preview
                    // (per kit CLAUDE.md root file — Cosmos emulator vnext-preview)
                    services.AddSingleton<CosmosClient>(_ =>
                        new CosmosClient(
                            TestCosmosEmulator.Endpoint,
                            TestCosmosEmulator.AuthKey,
                            new CosmosClientOptions { ConnectionMode = ConnectionMode.Gateway }));
                });
            });
    }

    public HttpClient CreateClient() => _factory.CreateClient();
}
```

### Pattern: Test Data Builder

```csharp
public class CharacterBuilder
{
    private string _name = "Test Character";
    private string _ancestry = "Human";
    private Dictionary<string, int> _attributes = new();

    public CharacterBuilder WithName(string name)
    {
        _name = name;
        return this;
    }

    public CharacterBuilder WithAttribute(string name, int value)
    {
        _attributes[name] = value;
        return this;
    }

    public PlayerCharacter Build()
    {
        var character = new PlayerCharacter(_name, _ancestry);
        foreach (var (attr, value) in _attributes)
            character.SetAttribute(attr, value);
        return character;
    }
}
```

---

# Frontend Testing Patterns (React/Playwright)

## 8. Feature Detection with test.fixme()

Mark tests for unimplemented features to prevent false failures.

### Pattern: Feature Not Implemented

```typescript
// FIXME: Requires player config backend implementation -- see BACKEND-GAPS.md
test.fixme('player config page structure', async ({ hostPage: page }) => {
  const campaignId = SEED.campaigns.sablewoodId
  await page.goto(`/host/campaigns/${campaignId}/players`)
  await page.waitForLoadState('networkidle')

  // Page either shows heading (backend up) or alert (backend down)
  const heading = page.getByRole('heading', { name: /player/i })
  const alert = page.locator('[role="alert"]')
  await expect(heading.or(alert).first()).toBeVisible({ timeout: 15000 })
})
```

**When to use `test.fixme()`**:
- Backend endpoint returns 404 (not implemented)
- UI page exists but backend logic missing
- Feature stub in place awaiting implementation
- Cross-reference with `BACKEND-GAPS.md` for tracking

---

## 9. Playwright Strict Mode Compliance

Ensure all selectors are unambiguous and work in strict mode.

### Pattern: Unique Locators

```typescript
// ❌ WRONG - Ambiguous selector (fails in strict mode)
await page.getByRole('button').click()

// ✅ CORRECT - Unique selector
await page.getByRole('button', { name: /save/i }).click()

// ❌ WRONG - Multiple matches
await page.locator('.card')

// ✅ CORRECT - Use .first() or .nth() explicitly
await page.locator('.card').first()

// ❌ WRONG - Ambiguous OR chain
await page.getByText('Submit').or(page.getByText('Save'))

// ✅ CORRECT - Explicit first() on OR chain
await page.getByText('Submit').or(page.getByText('Save')).first()
```

### Common Strict Mode Violations

| Violation | Fix | Example |
|-----------|-----|---------|
| Multiple role matches | Add `{ name }` filter | `.getByRole('button', { name: /save/i })` |
| Ambiguous locators | Use `.first()` or `.nth(i)` | `.locator('.card').first()` |
| Broad text matches | Narrow with regex anchors | `/^exact text$/i` |
| Chained OR without first() | Add `.first()` | `.or(...).first()` |

---

## 10. Backend Availability Checks

Handle both backend-available and backend-unavailable scenarios gracefully.

### Pattern: Flexible Assertions

```typescript
test('page structure (backend-flexible)', async ({ page }) => {
  await page.goto('/campaigns')
  await page.waitForLoadState('networkidle')

  // Accept either success content OR error alert
  const heading = page.getByRole('heading', { name: /campaign/i })
  const alert = page.locator('[role="alert"]')

  await expect(heading.or(alert).first()).toBeVisible({ timeout: 15000 })
})
```

### Pattern: Backend Health Check

```typescript
import { test as base } from '@playwright/test'

const test = base.extend({
  backendAvailable: async ({ request }, use) => {
    let isAvailable = false
    try {
      const response = await request.get('/health')
      isAvailable = response.ok()
    } catch {
      isAvailable = false
    }
    await use(isAvailable)
  }
})

test('feature requiring backend', async ({ page, backendAvailable }) => {
  if (!backendAvailable) {
    test.skip(true, 'Backend not available')
  }

  await page.goto('/feature')
  // Test real backend functionality
})
```

---

## 11. Seed Data Patterns

Use consistent seed data for predictable test scenarios.

### Pattern: Centralized Seed Data

```typescript
// e2e/seed-data.ts
export const SEED = {
  campaigns: {
    sablewoodId: 'camp-001',
    forestHeartId: 'camp-002'
  },
  characters: {
    theron: {
      id: 'char-001',
      name: 'Theron',
      ancestry: 'Wildborne'
    }
  },
  users: {
    host: {
      email: 'host@test.com',
      password: 'password123'
    }
  }
}

// Usage in tests
import { SEED } from '../seed-data'

test('navigate to campaign', async ({ page }) => {
  const campaignId = SEED.campaigns.sablewoodId
  await page.goto(`/campaigns/${campaignId}`)
})
```

---

## 12. Page Object Patterns

Centralize selectors and page interactions for maintainability.

### Pattern: Page Object Base Class

```typescript
export class BasePage {
  constructor(protected page: Page) {}

  async goto(path: string) {
    await this.page.goto(path)
    await this.page.waitForLoadState('networkidle')
  }

  async hasBackendError() {
    try {
      const alert = this.page.locator('[role="alert"]')
      await alert.waitFor({ state: 'visible', timeout: 5000 })
      const text = await alert.textContent()
      return text?.includes('error') || text?.includes('failed')
    } catch {
      return false
    }
  }
}
```

### Pattern: Feature Page Object

```typescript
export class CampaignPage extends BasePage {
  readonly campaignTitle = this.page.getByRole('heading', { name: /campaign/i })
  readonly createButton = this.page.getByRole('button', { name: /create/i })

  async createCampaign(name: string) {
    await this.createButton.click()
    await this.page.getByLabel(/name/i).fill(name)
    await this.page.getByRole('button', { name: /submit/i }).click()
  }
}

// Usage
test('create campaign', async ({ page }) => {
  const campaignPage = new CampaignPage(page)
  await campaignPage.goto('/campaigns')
  await campaignPage.createCampaign('Test Campaign')
})
```

---

## 13. Waiting Strategies

Proper waiting prevents flaky tests.

### Pattern: Network Idle

```typescript
test('page loads completely', async ({ page }) => {
  await page.goto('/dashboard')
  await page.waitForLoadState('networkidle')
  await expect(page.getByRole('heading')).toBeVisible()
})
```

### Pattern: Element Visibility

```typescript
test('waits for dynamic content', async ({ page }) => {
  await page.goto('/data')
  const dataTable = page.locator('[data-testid="data-table"]')
  await dataTable.waitFor({ state: 'visible', timeout: 10000 })
  await expect(dataTable.locator('tbody tr')).toHaveCount(5)
})
```

### Anti-Pattern: Arbitrary Timeouts

```typescript
// ❌ WRONG - Arbitrary wait
await page.waitForTimeout(3000)

// ✅ CORRECT - Wait for specific condition
await page.waitForLoadState('networkidle')
await page.locator('#content').waitFor({ state: 'visible' })
```

---

## 14. Authentication Fixtures

Centralize authentication for tests requiring logged-in users.

### Pattern: Auth Fixture

```typescript
// e2e/fixtures/auth.fixture.ts
import { test as base } from '@playwright/test'

export const test = base.extend({
  authenticatedPage: async ({ browser }, use) => {
    const context = await browser.newContext()
    const page = await context.newPage()

    // Login
    await page.goto('/login')
    await page.getByLabel(/email/i).fill('user@test.com')
    await page.getByLabel(/password/i).fill('password')
    await page.getByRole('button', { name: /login/i }).click()
    await page.waitForURL('/dashboard')

    await use(page)
    await context.close()
  }
})

// Usage
test('host creates campaign', async ({ authenticatedPage }) => {
  await authenticatedPage.goto('/host/campaigns')
  // Already logged in
})
```

---

## 15. Priority Tagging

Tag tests for tiered execution.

### Pattern: Priority Annotations

```typescript
// P0 = Smoke test - ALWAYS run, 100% pass required
test('login with valid credentials @p0', async ({ page }) => { })

// P1 = Critical path - Run pre-merge
test('create campaign with valid data @p1', async ({ page }) => { })

// P2 = Regression - Run nightly
test('edit campaign settings @p2', async ({ page }) => { })
```

Run by priority:
```bash
# Smoke tests only (critical path)
npm run test:e2e -- --grep @p0

# Smoke + important features
npm run test:e2e -- --grep "@p0|@p1"

# Full suite
npm run test:e2e
```

---

# Test Organization

## Backend Structure

```
tests/
├── Integration.Tests/
│   ├── Api/
│   │   ├── SessionsControllerTests.cs       # One file per controller
│   │   ├── CharactersControllerTests.cs
│   │   └── StoriesControllerTests.cs
│   ├── Validation/
│   │   ├── APIContractValidationTests.cs    # RFC 7807 compliance
│   │   ├── DataSchemaValidationTests.cs     # JSON schema validation
│   │   └── StateTransitionValidationTests.cs # State machine tests
│   └── Builders/
│       └── CharacterBuilderTests.cs         # Builder self-tests
├── Application.Tests/
│   └── Validation/
│       ├── GroundingValidatorTests.cs       # AI validation unit tests
│       ├── MechanicalFirewallTests.cs
│       └── IntentParserTests.cs
└── Tests.Shared/
    ├── Assertions/
    │   └── ProblemDetailsAssertions.cs      # Reusable assertions
    ├── Builders/
    │   └── CharacterBuilder.cs              # Reusable test data builders
    └── Mocks/
        └── MockAIService.cs                 # Reusable test doubles
```

## Frontend Structure

```
frontend/e2e/
├── pages/                    # Page Object Model (required)
│   ├── auth-page.ts
│   ├── campaign-page.ts
│   └── character-page.ts
├── auth/                     # Journey-focused (1 file per journey)
│   ├── login.spec.ts         # @p0 smoke
│   ├── registration.spec.ts  # @p0 smoke
│   └── oauth.spec.ts         # @p1 critical
└── campaigns/
    ├── create-campaign.spec.ts   # @p0 smoke
    └── edit-campaign.spec.ts     # @p1 critical
```

---

# Naming Conventions

## Backend (.NET)

| Test Type | Naming Pattern | Example |
|-----------|----------------|---------|
| Valid transition | `{State}_{ValidTransition}_{FromState}To{ToState}_Succeeds` | `SessionStatus_ValidTransition_CreatedToActive_Succeeds` |
| Invalid transition | `{State}_InvalidTransition_{FromState}To{ToState}_Returns{Code}` | `SessionStatus_InvalidTransition_CreatedToConcluded_Returns400` |
| Endpoint success | `{Action}_{Scenario}_Returns{Code}` | `CreateSession_ValidRequest_Returns201Created` |
| Endpoint error | `{Action}_{ErrorCondition}_Returns{Code}` | `CreateSession_MissingCampaignId_Returns400BadRequest` |
| Validator test | `Validate_{Condition}_{ExpectedResult}` | `Validate_MentionsNonExistentCharacter_ReturnsViolation` |

## Frontend (Playwright)

| Test Type | Naming Pattern | Example |
|-----------|----------------|---------|
| User journey | `{action} {context}` | `login with valid credentials` |
| Page interaction | `{page} {action} {outcome}` | `campaign page shows active campaigns` |
| Error handling | `{action} {error condition}` | `login with invalid credentials shows error` |

---

# Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| **Mocking database in integration tests** | Doesn't validate real queries/events | Use Cosmos emulator (`mcr.microsoft.com/cosmosdb/linux/azure-cosmos-emulator:vnext-preview`) for real data-access verification |
| **Mocking backend in E2E tests** | Doesn't validate real integration | Use real backend, mock only external APIs |
| **Skipping invalid transition tests** | Only tests happy path, misses bugs | Explicitly test every invalid transition |
| **[Fact] for incomplete features** | Test shows as failed | Use `[SkippableFact]` or `test.fixme()` |
| **No validation checkpoint mapping** | Can't measure coverage | Maintain coverage matrix document |
| **Testing AI with real API calls** | Slow, non-deterministic, costly | Use `MockAIService` with canned responses |
| **Loose selectors (Playwright)** | Fails in strict mode, brittle tests | Use `getByRole` with `{ name }` filters |
| **Arbitrary timeouts** | Flaky tests, slow execution | Wait for specific conditions |
| **One giant test file** | Hard to navigate, slow test runs | One file per controller/feature |
| **Magic test data** | Hard to understand test intent | Use builder pattern or centralized SEED data |

---

# Enforcement Table

| Rule | Enforcement | Violates If |
|------|-------------|-------------|
| RFC 7807 compliance | All API error responses | Missing `type`, `title`, or `status` |
| State transition coverage | All state machines | Valid transition not tested |
| Invalid transition rejection | All state machines | No test for illegal transition |
| Graceful skipping | Unimplemented features | Test fails instead of skips |
| No database mocking | Backend integration tests | Mock in test fixture instead of testcontainers |
| No backend mocking | Frontend E2E tests | Uses `page.route()` to mock backend APIs |
| Strict mode compliance | All Playwright tests | Locator matches multiple elements without `.first()` |
| Real dependencies | Integration tests | Mock in test fixture instead of real infrastructure |
| Test independence | All tests | Test depends on another test running first |
| Validation checkpoint mapping | Backend validation tests | Test method not listed in coverage matrix |

---

# Quality Gate Integration

## Backend

```bash
# Run API behavioral tests only
dotnet test --filter "Category=Integration"

# Run validation checkpoint tests only
dotnet test --filter "Category=Validation"

# Run AI validation tests only
dotnet test --filter "Category=AIValidation"

# Run all behavioral tests (excludes unit tests)
dotnet test --filter "Category=Integration|Category=Validation|Category=AIValidation"
```

Time expectations (from audit):
- Integration tests: ~8s (63 tests)
- Validation tests: ~15s (subset of integration)
- AIValidation tests: <1s (unit tests with mocks)

## Frontend

```bash
# Smoke tests only (critical path, ~30s)
npm run test:e2e -- --grep @p0

# Smoke + regression (important features, ~2-3 min)
npm run test:e2e -- --grep "@p0|@p1"

# Full E2E suite (all tests, ~5-8 min)
npm run test:e2e
```

Time expectations (from audit):
- P0 smoke tests: ~30s (15-20 tests)
- P0 + P1 regression: ~90s (50-70 tests)
- Full suite: ~90s (186 tests, parallel execution)

---

# References

| Resource | Description |
|----------|-------------|
| RFC 7807 | Problem Details for HTTP APIs standard |
| Playwright Docs | Official E2E testing framework documentation |
| `specs/001-behavioral-test-coverage/` | Full feature spec with user scenarios |
| `specs/001-behavioral-test-coverage/COVERAGE-REPORT.md` | Audit results and metrics |
| `tests/Integration.Tests/Validation/` | Backend reference implementations |
| `frontend/e2e/BACKEND-GAPS.md` | Missing backend endpoints tracking |
| `tests/Tests.Shared/Assertions/` | Reusable assertion helpers |
| `.claude/rules/test-discipline.md` | TDD workflow and test failure protocol |
