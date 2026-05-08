---
category: integration-patterns
subcategory: testing-frameworks
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# Testing Frameworks (2026)

## Overview

Integration patterns for xUnit (backend), Vitest (frontend unit), and Playwright (E2E) testing frameworks in AI-assisted workflows. Includes 2026 skills-based testing and autonomous test diagnosis.

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Framework-Specific Patterns** | Follow framework conventions |
| **No Mocking in Integration** | Integration tests use real dependencies |
| **Playwright Page Objects** | Use page object model for E2E |
| **Fixture Reuse** | Share test fixtures across test files |
| **Parallel Execution** | Configure tests for parallel runs |
| **Verification-Driven** | Include test cases as verification criteria |

## Patterns (Current)

### Test-Driven Prompting

**Give Claude way to verify**: Include tests as verification criteria in prompts.

**Pattern**:
```
Implement {feature}. Test cases:
- {input1} → {expected_output1}
- {input2} → {expected_output2}

Run tests after implementing.
```

**Example**:
```
Write validateEmail function. Test cases:
- user@example.com → true
- invalid-email → false
- @example.com → false

Run tests after implementing.
```

**Benefit**: Claude writes implementation and verifies it immediately.

### Playwright E2E Testing (2026)

**Skills-based framework** (community analysis):

**Capabilities**:
- Custom, reusable AI workflows
- Execute complex multi-step test scenarios autonomously
- Context-aware decisions about retry logic, timeouts
- Leverage Claude's reasoning for edge cases

**Flaky test diagnosis**:
- Analyze failures automatically
- Diagnose root causes:
  - Selector-based (element not found)
  - Timing-based (race conditions)
  - Async-based (promises not resolved)
  - Mock-based (test doubles not configured)
- Apply appropriate fixes

**Example diagnostic prompt**:
```
Analyze Playwright test failure:
[paste error output]

Diagnose root cause (selector/timing/async/mock) and suggest fix.
```

### UI Verification Pattern

**Use Claude in Chrome extension**:
- Opens new tabs
- Tests UI interactions
- Iterates until functionality works

**When to use**:
- Visual regression testing
- Complex UI workflows
- Accessibility validation

**Integration**: Combine with Playwright for automated UI verification.

### xUnit Integration Testing

**No mocking in integration tests**: Use real dependencies (databases, APIs, services).

**Pattern**:
```csharp
public class MyIntegrationTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _postgres;

    public async Task InitializeAsync()
    {
        await _postgres.StartAsync();
    }

    [Fact]
    public async Task MyTest()
    {
        // Real database, no mocks
    }
}
```

### Vitest Frontend Unit Testing

**Framework conventions**:
- Use `describe` blocks for grouping
- Use `it` or `test` for individual cases
- Mock external dependencies (APIs, services)
- Use `vi.fn()` for mocks

**Pattern**:
```typescript
describe('MyComponent', () => {
  it('renders correctly', () => {
    const { getByText } = render(<MyComponent />);
    expect(getByText('Hello')).toBeInTheDocument();
  });
});
```

## Changed Patterns (2025 → 2026)

| Pattern | 2025 | 2026 | Migration |
|---------|------|------|-----------|
| Playwright usage | Manual test writing | Skills-based autonomous testing | Use Claude for complex scenarios |
| Flaky test diagnosis | Manual debugging | Automated root cause analysis | Prompt Claude with failure output |
| Test verification | Post-implementation | Inline in prompts | Include test cases in feature requests |

## Anti-Patterns

| Anti-Pattern | Problem | Correct |
|--------------|---------|---------|
| Mocking in integration tests | False confidence (URL/CORS bugs missed) | Use real dependencies |
| Manual flaky test debugging | Time-consuming | Use Claude for automated diagnosis |
| No test cases in prompts | Implementation without verification | Include expected outputs in prompts |
| Skipping UI verification | Visual bugs missed | Use Chrome extension + Playwright |
| Sequential test execution | Slow feedback | Configure parallel execution |

## Examples

### Example 1: xUnit Integration Test (No Mocks)

```csharp
public class CampaignServiceIntegrationTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _postgres;
    private readonly IDocumentStore _store;

    public async Task InitializeAsync()
    {
        _postgres = new PostgreSqlBuilder().Build();
        await _postgres.StartAsync();

        _store = DocumentStore.For(options =>
        {
            options.Connection(_postgres.GetConnectionString());
        });
    }

    [Fact]
    public async Task CreateCampaign_StoresInDatabase()
    {
        // Arrange
        var service = new CampaignService(_store);
        var campaign = new Campaign { Name = "Test" };

        // Act
        await service.CreateAsync(campaign);

        // Assert
        using var session = _store.QuerySession();
        var stored = await session.LoadAsync<Campaign>(campaign.Id);
        stored.Should().NotBeNull();
        stored.Name.Should().Be("Test");
    }

    public async Task DisposeAsync()
    {
        _store.Dispose();
        await _postgres.DisposeAsync();
    }
}
```

### Example 2: Playwright Flaky Test Diagnosis

**Failing test**:
```
Error: locator.click: Timeout 30000ms exceeded.
=========================== logs ===========================
waiting for locator('.submit-button')
  locator resolved to <button class="submit-button">Submit</button>
============================================================
```

**Prompt**:
```
Analyze this Playwright test failure and diagnose root cause:

Error: locator.click: Timeout 30000ms exceeded.
waiting for locator('.submit-button')
  locator resolved to <button class="submit-button">Submit</button>

Diagnose whether this is selector-based, timing-based, async-based, or mock-based.
```

**Claude diagnosis**:
- Root cause: Timing-based (button found but not clickable)
- Likely cause: Overlay or loading spinner blocking click
- Fix: Wait for button to be enabled or visible before click

**Applied fix**:
```typescript
await page.locator('.submit-button').click({ force: false });
// Change to:
await page.waitForLoadState('networkidle');
await page.locator('.submit-button').waitFor({ state: 'visible' });
await page.locator('.submit-button').click();
```

### Example 3: Test-Driven Prompt

**Prompt**:
```
Implement parseDate function that handles multiple formats.

Test cases:
- "2026-02-16" → Date(2026, 1, 16)
- "02/16/2026" → Date(2026, 1, 16)
- "Feb 16, 2026" → Date(2026, 1, 16)
- "invalid" → throw Error("Invalid date format")

Use date-fns library. Write Vitest tests first (TDD), then implementation.
Run tests after implementing.
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Flaky Playwright tests | Use Claude diagnostic prompt with error output |
| Integration tests failing | Check real dependencies are running (DB, services) |
| UI tests brittle | Use semantic selectors (role, label) not CSS classes |
| Slow test feedback | Configure parallel execution, use watch mode |

## See Also

- `.claude/rules/patterns/playwright-e2e-patterns.md` - Playwright specific patterns
- `.claude/rules/quality-gates.md` - Progressive validation tiers
- `.claude/rules/code-review.md` - Test quality criteria

## Research Metadata

**Sources consulted**:
- https://code.claude.com/docs/en/best-practices (test verification patterns)
- https://apidog.com (Playwright skills-based testing)
- Community implementations (Second Talent, flaky test diagnosis)

**Research date**: 2026-02-16
**Confidence level**: HIGH (validated across official docs + community implementations)
**Frequency validation**: 90%+ (patterns appear in official docs + testing guides)
