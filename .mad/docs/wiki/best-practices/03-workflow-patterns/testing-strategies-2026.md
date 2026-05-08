---
category: workflow-patterns
subcategory: testing-strategies
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# Testing Strategies (2026)

## Overview

Testing pyramid, progressive validation tiers, test-driven development patterns, and test selection strategies for efficient validation.

**2026 Update**: Intelligent test handling with flaky test diagnosis, skills-based framework for autonomous test scenarios, and QA as human-supervised collaborative process.

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Testing Pyramid** | 70% unit, 20% integration, 10% E2E (critical journeys only) |
| **TDD Default** | Write tests first (red-green-refactor) |
| **No Mocking in Integration** | Integration tests use real dependencies |
| **E2E Smoke Tests** | @p0 tests for critical paths |
| **Behavioral Testing** | Test user-facing behavior, not implementation |
| **Iterative Testing** | Test after every task during coding phase |
| **QA as Collaboration** | Claude as second engineer who reasons and proposes fixes |

## Patterns (Current)

### Testing Pyramid

Distribution for optimal coverage vs speed:

| Layer | Percentage | Purpose | Characteristics |
|-------|-----------|---------|-----------------|
| **Unit** | 70% | Fast feedback on logic | Isolated, no I/O, <1ms per test |
| **Integration** | 20% | Real dependencies | Database, API calls, <100ms per test |
| **E2E** | 10% | Critical journeys | Full stack, UI automation, <10s per test |

**Rationale**: Unit tests provide rapid feedback (Tier 0-1), integration tests catch real-world issues (Tier 2-3), E2E tests verify user flows (Tier 4).

### TDD Cycle

**Red-Green-Refactor Pattern**:

1. **Red**: Write failing test first
   - Define expected behavior
   - Verify test fails for right reason
   - Use Tier 0 (single test method filter) for <1s feedback

2. **Green**: Implement minimum code to pass
   - Write simplest implementation
   - Run same test to verify pass
   - No premature optimization

3. **Refactor**: Improve code quality
   - Extract methods, improve names
   - Re-run test to verify behavior unchanged
   - Commit when clean

**2026 best practice**: "Test after every task during coding phase" - tight feedback loops prevent bugs from compounding.

### Progressive Validation (5-Tier)

Match test scope to work phase for efficiency:

| Tier | Scope | Time | Use Case |
|------|-------|------|----------|
| **Tier 0** | Single test method | <1s | TDD red-green cycle |
| **Tier 1** | Fast unit (Domain + Application) | 1s | Development (after task) |
| **Tier 2** | Full unit (+ Infrastructure) | 81s | Pre-commit (Infrastructure changed) |
| **Tier 3** | Core + Integration | 1m 30s | Phase gate (current baseline) |
| **Tier 4** | Full suite (E2E) | 7m 40s | PR gate, nightly builds |

**Time savings**: Tier 1 vs Tier 3 = 99% faster (1s vs 1m 30s)

**Staleness thresholds** (escalate to higher tier when):
- Last full suite run >24 hours → Tier 3 minimum
- Last full suite run >7 days → Tier 4 (full E2E)
- Previously failing tests exist → ALWAYS include
- Config files changed → Tier 3

### Intelligent Flaky Test Diagnosis (2026)

**Skills-based framework** for autonomous test handling:

1. **Analyze failures**: Claude reads failure logs
2. **Diagnose root causes**: Classify by type
   - **Selector-based**: Element locators brittle
   - **Timing-based**: Race conditions, async timing
   - **Async-based**: Promise handling, event sequencing
   - **Mock-based**: Mock state leakage between tests
3. **Apply appropriate fixes**: Context-aware decisions
   - Improve selectors (data-testid over class names)
   - Add explicit waits (waitFor over arbitrary timeouts)
   - Fix async handling (await all promises)
   - Isolate mocks (beforeEach cleanup)

**Key insight (2026)**: "Claude Code fits best into QA workflows when it is used as a second engineer who reads failures, reasons about intent, and proposes fixes that humans can review."

### QA as Human-Supervised Process

**NOT fully autonomous testing** - collaborative QA partner model:

| Role | Responsibility |
|------|----------------|
| **Claude** | Read failures, diagnose root cause, propose fixes, execute retry logic |
| **Human** | Review proposed fixes, approve changes, verify edge cases |

**Skills leverage Claude's reasoning** for:
- Complex multi-step test scenarios
- Edge case identification
- Timeout and retry logic decisions
- Interpreting flaky failure patterns

## Changed Patterns (2025 → 2026)

| Pattern | 2025 | 2026 | Migration |
|---------|------|------|-----------|
| **Flaky test handling** | Manual analysis | Intelligent diagnosis (selector/timing/async/mock) | Let Claude diagnose root cause type |
| **Test autonomy** | Attempt full automation | QA as collaborative partner | Review Claude's proposed fixes |
| **Iterative testing** | Manual | Built into workflow (test after every task) | Enable tight feedback loops |
| **Test selection** | Manual tier choice | `test-selector` agent analyzes git diff | Let agent recommend tier |

## Anti-Patterns

| Anti-Pattern | Problem | Correct |
|--------------|---------|---------|
| Running Tier 4 (E2E) during TDD cycles | Wastes 7+ minutes per cycle, kills flow state | Use Tier 0 or Tier 1 for rapid feedback (<1s) |
| Skipping iterative testing | Bugs compound | Test after every task during coding |
| Mocking in integration tests | Misses real integration issues | Use real dependencies (database, APIs) |
| Dismissing flaky tests | Unreliable test suite | Diagnose root cause (selector/timing/async/mock) |
| Fully autonomous testing | Claude proposes fixes without human review | QA as collaborative partner - review all fixes |
| Claiming "hours to minutes" savings | Baseline is 1m 30s (Tier 3), not "3+ hours" | Cite audit-validated metrics: 99% savings for Tier 1 |

## Examples

### Example 1: TDD Cycle (Red-Green-Refactor)

```bash
# RED: Write failing test
# File: tests/Domain.Tests/UserTests.cs
dotnet test --filter FullyQualifiedName~UserTests.CreateUser_ValidInput_ReturnsUser
# Output: FAILED (expected - test written first)
# Time: <1 second (Tier 0)

# GREEN: Implement minimum code
# File: src/Domain/User.cs
public static User CreateUser(string name) => new User { Name = name };

# Re-run same test
dotnet test --filter FullyQualifiedName~UserTests.CreateUser_ValidInput_ReturnsUser
# Output: PASSED
# Time: <1 second (Tier 0)

# REFACTOR: Improve code quality (if needed)
# Re-run test to verify behavior unchanged

# COMMIT: Tests passing, feature complete
git add tests/Domain.Tests/UserTests.cs src/Domain/User.cs
git commit -m "feat(domain): add User.CreateUser method"
```

### Example 2: Integration Test (No Mocks)

```csharp
// CORRECT: Real database, no mocks
public class CampaignRepositoryTests : IAsyncLifetime
{
    private IDocumentStore _store;
    private IDocumentSession _session;

    public async Task InitializeAsync()
    {
        _store = DocumentStore.For(opts =>
        {
            opts.Connection(TestConnectionString);
            opts.DatabaseSchemaName = "test";
        });
        await _store.Advanced.Clean.CompletelyRemoveAllAsync();
        _session = _store.LightweightSession();
    }

    [Fact]
    public async Task SaveCampaign_ValidCampaign_PersistsToDatabase()
    {
        // Arrange: Real Marten session
        var campaign = new Campaign { Name = "Test Campaign" };
        var repo = new CampaignRepository(_session);

        // Act: Real database write
        await repo.SaveAsync(campaign);

        // Assert: Real database read
        var loaded = await _session.LoadAsync<Campaign>(campaign.Id);
        loaded.Should().NotBeNull();
        loaded.Name.Should().Be("Test Campaign");
    }
}
```

### Example 3: Flaky Test Diagnosis (2026)

```bash
# Test fails intermittently
npm run test:e2e -- auth.spec.ts
# Output: FAILED (ElementNotFoundError: button[data-testid="login"])

# Claude analyzes failure
# Diagnosis: Selector-based (element not ready when queried)

# Proposed fix: Add explicit wait
await page.waitForSelector('button[data-testid="login"]', { state: 'visible' });
await page.click('button[data-testid="login"]');

# Human reviews, approves
# Re-run test
npm run test:e2e -- auth.spec.ts
# Output: PASSED (stable now)
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Tests taking too long | Use progressive tiers - Tier 1 for development, Tier 4 for PR gate |
| Flaky tests | Run intelligent diagnosis - classify as selector/timing/async/mock, apply targeted fix |
| Integration tests failing | Check infrastructure dependencies (PostgreSQL, Docker) - add skip logic if unavailable |
| E2E tests slow | Reserve Tier 4 for PR gate and nightly builds only, use @p0 smoke tests during development |
| Test-selector wrong tier | Review git diff analysis, manually override with `--force-full` if needed |

## See Also

- `quality-gates-2026.md` - Gate execution
- `verification-patterns-2026.md` - Progressive validation
- `.claude/rules/patterns/behavioral-testing.md` - Behavioral patterns
- `.claude/agents/test-selector.md` - Test tier selection agent
- `.claude/rules/test-failure-protocol.md` - Handling test failures

## Research Metadata

**Sources consulted**:
- https://code.claude.com/docs/en/best-practices (official)
- https://apidog.com/blog/claude-code-ai-pair-programmer/ (flaky test diagnosis)
- https://www.secondtalent.com/blog/claude-code-qa-testing/ (QA collaboration)

**Research date**: 2026-02-16
**Confidence level**: HIGH (validated across official docs + community implementations)
**Frequency validation**: 85%+ (patterns appear in official docs + 2+ community sources)
