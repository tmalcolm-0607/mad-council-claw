---
paths:
  - "**/e2e/**/*.spec.ts"
  - "**/playwright.config.ts"
  - "**/spec.md"
  - "**/plan.md"
---

# E2E UI Testing Patterns

Journey-focused end-to-end testing patterns for validating critical user workflows with Playwright.

---

## Overview

E2E UI tests validate complete user journeys through the browser, from authentication to business-critical workflows. Unlike unit or integration tests, E2E tests:

- Run in real browsers (Chromium, Firefox, WebKit)
- Interact with the full UI stack (React → API → Database)
- Validate user-visible behavior, not implementation details
- Are expensive (minutes vs seconds) and should be selective

**Philosophy**: Test critical user journeys, not exhaustive coverage.

---

## When to Write E2E Tests (Automatic Triggers)

### ALWAYS Write E2E Tests For

| Scenario | Test Type | Example |
|----------|-----------|---------|
| **Authentication flows** | Smoke | Login, logout, registration, OAuth, password reset |
| **Money paths** | Critical | Payment, checkout, order placement, billing |
| **Core user journeys** | Critical | Create/edit/delete primary entities, search/filter |
| **Multi-actor workflows** | Critical | Case creation, reviewer assignment, multi-party handoffs |
| **New UI features in spec** | Feature | Any user story with UI acceptance criteria |

### NEVER Write E2E Tests For

| Scenario | Use Instead | Reason |
|----------|-------------|--------|
| **Validation logic** | Unit tests | Fast, deterministic, no browser needed |
| **API response formats** | Integration tests | No UI involved |
| **Edge cases** | Unit/integration | E2E too slow/expensive for edge coverage |
| **Internal utilities** | Unit tests | Not user-facing |

---

## Testing Pyramid for UI Features

```
        E2E (10%)           ← Critical user journeys only
       /         \
  Integration (20%)        ← API + database interactions
     /             \
   Unit (70%)               ← Business logic, validation, utilities
```

**Target Distribution**:
- **70% Unit**: Fast feedback on logic (< 1s per test)
- **20% Integration**: API contracts with real database (< 5s per test)
- **10% E2E**: Critical workflows end-to-end (1-5min per test)

**For UI features**: Aim for 50-200 well-designed E2E tests covering critical journeys, not 1,000+ redundant tests.

---

## Journey-Focused Approach

### Step 1: Identify Critical Journeys (During `/mad-spec`)

Every spec MUST include a "Critical User Journeys" section:

```markdown
## Critical User Journeys

### Journey 1: Case Creation (P0 - Smoke Test)
**Actor**: Case Manager
**Steps**:
1. Login as Case Manager
2. Navigate to "New Case"
3. Enter case details and request type
4. Select jurisdiction
5. Save case
6. Verify case appears in dashboard

**Success Criteria**:
- Case saved to database
- User redirected to case dashboard
- Case visible in "My Cases" list

**E2E Test**: `e2e/cases/create-case.spec.ts`

### Journey 2: Document Submission Flow (P1 - Critical Path)
...
```

### Step 2: Categorize by Priority

| Priority | Tier | Run When | Examples |
|----------|------|----------|----------|
| **P0** | Smoke | Every deployment | Auth, core navigation, health checks |
| **P1** | Critical Path | Pre-release | Money paths, primary workflows |
| **P2** | Regression | Nightly | Secondary features, edge workflows |
| **P3** | Optional | Manual | Nice-to-have, experimental features |

### Step 3: Map to Test Files (During `/mad-implement`)

Create 1 test file per journey (not per component):

```
frontend/e2e/
├── auth/
│   ├── login.spec.ts          # P0 Smoke
│   ├── registration.spec.ts   # P0 Smoke
│   └── oauth.spec.ts          # P1 Critical
├── cases/
│   ├── create-case.spec.ts       # P0 Smoke
│   ├── edit-case.spec.ts         # P1 Critical
│   └── close-case.spec.ts        # P2 Regression
└── documents/
    ├── submit-document.spec.ts   # P1 Critical
    └── review-document.spec.ts   # P2 Regression
```

---

## Playwright MCP Integration (MANDATORY)

**All E2E tests MUST use the Playwright MCP server for browser automation and visual verification.**

### Why Playwright MCP?

| Benefit | Description |
|---------|-------------|
| **Centralized Control** | Single source of truth for browser automation |
| **Automatic Screenshots** | Captures screenshots on test failures automatically |
| **Better Debugging** | Rich debugging context and trace files |
| **Consistent Patterns** | Enforces best practices across all E2E tests |
| **Visual Regression** | Built-in support for visual comparison |

### MCP Setup

**1. Verify MCP Server** (should already be configured):
```bash
# Check MCP server availability
claude code mcp list | grep playwright
```

**2. Use MCP in Tests**:
```typescript
import { test, expect } from '@playwright/test';

test('user can create case @p0', async ({ page }) => {
  // Navigate using standard Playwright
  await page.goto('/cases/new');

  // Visual verification - MCP automatically captures screenshots
  await expect(page.locator('.case-form')).toBeVisible();
  await expect(page.locator('button[type="submit"]')).toBeEnabled();

  // Interactions use standard Playwright (MCP observes)
  await page.fill('input[name="requestType"]', 'SubpoenaSummons');
  await page.click('button[type="submit"]');

  // Verify success state
  await expect(page.locator('.success-message')).toBeVisible();
});
```

### Visual Verification Requirements

| Requirement | Why | Enforcement |
|-------------|-----|-------------|
| **Screenshot on failure** | Debugging | Automatic via MCP |
| **Video recording** | Reproduce flaky tests | Enable in playwright.config.ts |
| **Trace on failure** | Step-by-step debugging | `trace: 'on-first-retry'` |
| **No manual screenshots** | Consistency | Use MCP, not `page.screenshot()` |

### Configuration

```typescript
// frontend/playwright.config.ts
export default defineConfig({
  use: {
    // MCP integration
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    trace: 'on-first-retry',

    // Browser context
    viewport: { width: 1280, height: 720 },
    ignoreHTTPSErrors: true,
  },
});
```

### Enforcement Rules

| Rule | Severity | Action |
|------|----------|--------|
| No visual verification assertions | ERROR | Test rejected in code review |
| Manual `page.screenshot()` calls | WARNING | Suggest removing (MCP handles automatically) |
| Missing trace/video config | ERROR | Update playwright.config.ts |
| Tests without MCP observation | ERROR | Ensure MCP server is running |

---

## Playwright Best Practices

### 1. Test Isolation (MANDATORY)

Each test MUST be completely isolated with its own browser context:

```typescript
// ✅ CORRECT: Each test gets clean state
test('create case', async ({ page }) => {
  // Fresh browser context, no shared state
  await page.goto('/cases/new');
  // ...
});

test('edit case', async ({ page }) => {
  // Different browser context, isolated storage
  await page.goto('/cases/1/edit');
  // ...
});

// ❌ WRONG: Shared state between tests
let sharedPage;
test.beforeAll(async ({ browser }) => {
  sharedPage = await browser.newPage(); // Shared across tests!
});
```

**Why**: Prevents auth state race conditions (like you just fixed).

### 2. Auto-Waiting (MANDATORY)

Rely on Playwright's built-in auto-waiting, NEVER use hard-coded timeouts:

```typescript
// ✅ CORRECT: Auto-waits for element to be visible and actionable
await page.click('button:has-text("Save")');
await expect(page.locator('.success-message')).toBeVisible();

// ❌ WRONG: Hard-coded waits are flaky
await page.waitForTimeout(2000); // Brittle!
await page.click('button:has-text("Save")');
```

**Built-in waits handle**:
- Element visibility
- Actionability (not covered, not disabled)
- Network events
- Navigation completion

### 3. Page Object Model (MANDATORY)

Extract locators and actions into page objects for maintainability:

```typescript
// ✅ CORRECT: Page Object Model
// e2e/pages/case-page.ts
export class CasePage {
  constructor(private page: Page) {}

  async createCase(requestType: string, jurisdiction: string) {
    await this.page.click('button:has-text("New Case")');
    await this.page.fill('input[name="requestType"]', requestType);
    await this.page.selectOption('select[name="jurisdiction"]', jurisdiction);
    await this.page.click('button[type="submit"]');
  }

  async getCaseId() {
    return this.page.locator('.case-id').textContent();
  }
}

// e2e/cases/create-case.spec.ts
test('create case', async ({ page }) => {
  const casePage = new CasePage(page);
  await casePage.createCase('SubpoenaSummons', 'US-WA');
  expect(await casePage.getCaseId()).toBeTruthy();
});

// ❌ WRONG: Locators duplicated across tests
test('create case', async ({ page }) => {
  await page.click('button:has-text("New Case")');
  await page.fill('input[name="requestType"]', 'SubpoenaSummons');
  // If UI changes, must update EVERY test file
});
```

### 4. Semantic Locators (MANDATORY)

Prioritize user-facing locators over implementation details:

```typescript
// ✅ CORRECT: User-visible text and roles
await page.click('button:has-text("Save Case")');
await page.getByRole('heading', { name: 'My Cases' });
await page.getByLabel('Request Type').fill('SubpoenaSummons');

// ❌ WRONG: Brittle CSS selectors tied to implementation
await page.click('.btn-primary.case-save-button');
await page.locator('div.cases-header > h1').click();
```

**Priority**:
1. `getByRole()` - accessible roles (button, heading, textbox)
2. `getByText()` / `has-text()` - visible text
3. `getByLabel()` - form labels
4. `getByTestId()` - stable test IDs (only when above fail)
5. CSS/XPath - last resort

---

## Flakiness Prevention

### Strategy 1: Run Tests 3-5 Times Locally Before CI

Before committing new E2E tests:

```bash
# Run new test 5 times to confirm stability
for i in {1..5}; do npm run test:e2e -- cases/create-case.spec.ts; done
```

**If any run fails**: Fix flakiness BEFORE committing. Don't ship flaky tests to CI.

### Strategy 2: Quarantine Flaky Tests

If a test becomes flaky in CI:

```typescript
// Quarantine with .fixme() - excludes from CI runs
test.fixme('flaky test that needs investigation', async ({ page }) => {
  // Test code...
});
```

**Don't block pipelines**. Quarantine first, fix later.

### Strategy 3: Monitor Flaky Rate

Target: **0% flaky rate** (tests requiring retries).

If flaky rate > 5%:
1. Identify root cause (race conditions, timing, shared state)
2. Fix with better waits, isolation, or test data setup
3. Re-run 5 times locally to confirm

---

## Test Execution Strategy (Automatic)

### Development Cycle (During `/mad-implement`)

| Phase | Run | Command | Pass Criteria |
|-------|-----|---------|---------------|
| **After UI implementation** | Smoke tests only | `npm run test:e2e -- --grep @p0` | 100% pass required |
| **Phase gate** | Smoke tests only | `npm run test:e2e -- --grep @p0` | 100% pass required |
| **Pre-commit** | Smoke tests only | `npm run test:e2e -- --grep @p0` | 100% pass required |

**Never run full E2E suite during development** - too slow, kills velocity.

### Pre-Release (During `/mad-validate`)

| Phase | Run | Command | Pass Criteria |
|-------|-----|---------|---------------|
| **mad-validate** | Full E2E suite | `npm run test:e2e` | ≥90% pass rate |
| **mad-validate** | Smoke tests | `npm run test:e2e -- --grep @p0` | 100% pass required (blocking) |

### CI/CD Pipeline

| Trigger | Run | Pass Criteria |
|---------|-----|---------------|
| **Every commit** | Smoke tests (@p0) | 100% required |
| **Pre-merge (PR)** | Critical path (@p0, @p1) | ≥95% required |
| **Nightly** | Full suite (all tests) | ≥90% required |
| **Pre-release** | Full suite + visual regression | 100% required |

---

## Feature Map Traceability (Automatic)

Every spec MUST include an E2E coverage matrix:

```markdown
## E2E Test Coverage

| User Story | Journey | E2E Test File | Priority | Status |
|------------|---------|---------------|----------|--------|
| US-001: Manager creates case | Case creation | `e2e/cases/create-case.spec.ts` | P0 | ✅ Passing |
| US-002: Manager assigns reviewer | Reviewer assignment | `e2e/cases/assign-reviewer.spec.ts` | P1 | ✅ Passing |
| US-003: Reviewer submits document | Document submission | `e2e/documents/submit-document.spec.ts` | P1 | ⚠️ Flaky (auth race) |
| US-004: Document review | Document review | `e2e/documents/review-document.spec.ts` | P1 | ✅ Passing |
```

**Generated automatically during `/mad-spec`** and **validated during `/mad-validate`**.

---

## Component Audit (Automatic)

For UI features, generate a component audit checklist:

```markdown
## Component Audit

| Component | Page Object | Accessibility | E2E Coverage | Status |
|-----------|-------------|---------------|--------------|--------|
| `CaseForm` | `CasePage.createCase()` | WCAG 2.1 AA | ✅ Covered | ✅ Pass |
| `ReviewerAssignModal` | `AssignModal.assignReviewer()` | WCAG 2.1 AA | ✅ Covered | ✅ Pass |
| `DocumentViewer` | `DocumentPage.reviewDocument()` | WCAG 2.1 AA | ⚠️ Partial | 🔴 Missing attachment tests |
```

**Generated during `/mad-implement`** when new UI components are added.

---

## Anti-Patterns (FORBIDDEN)

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| **Mocking API in E2E tests** | Not testing real integration | Use real backend (Docker) |
| **100% E2E coverage goal** | Wastes time, kills velocity | Target critical journeys only (50-200 tests) |
| **Hard-coded timeouts** | Flaky, brittle | Use Playwright auto-waiting |
| **Shared state between tests** | Race conditions, flakiness | Isolate with browser contexts |
| **Running full E2E during development** | Slow feedback (5-10min) | Run smoke tests only (30s-1min) |
| **E2E for validation logic** | Expensive, slow | Use unit tests |
| **Duplicated locators** | Maintenance nightmare | Use Page Object Model |
| **Committing flaky tests** | Blocks CI pipeline | Run 5 times locally first |
| **Ignoring flaky tests** | Degrades trust in suite | Quarantine + fix, or delete |

---

## Enforcement

### During `/mad-spec`

✅ **REQUIRED**:
- [ ] Critical user journeys identified
- [ ] E2E test coverage matrix created
- [ ] Component audit checklist generated
- [ ] Priority levels assigned (P0/P1/P2/P3)

### During `/mad-implement`

✅ **REQUIRED**:
- [ ] E2E test files created for all P0/P1 journeys
- [ ] Page objects created for new UI components
- [ ] Smoke tests run and pass (100%)
- [ ] New tests run 5 times locally (confirm stability)

### During `/mad-validate`

✅ **REQUIRED**:
- [ ] Smoke tests pass (100% - BLOCKING)
- [ ] Full E2E suite ≥90% pass rate
- [ ] All critical journeys have E2E coverage
- [ ] Component audit complete (all components covered)
- [ ] Flaky rate < 5%

**If E2E tests fail**: Auto-generate fixes and re-run until ≥90% pass rate achieved.

---

## References

- [Playwright Best Practices](https://playwright.dev/docs/best-practices)
- [Playwright Auto-Waiting](https://playwright.dev/docs/actionability)
- [Playwright Isolation](https://playwright.dev/docs/browser-contexts)
- [Claude Code E2E Testing](https://claudecn.com/en/docs/claude-code/workflows/e2e-testing/)
- [Testing Pyramid 2026](https://medium.com/@yashbatra11111/the-testing-pyramid-why-70-unit-20-integration-10-e2e-still-wins-fb25df39c18c)

---

## Integration Points

- **CLAUDE.md**: Quality gates include smoke tests
- **mad-spec**: Generates critical journeys and E2E coverage matrix
- **mad-implement**: Auto-generates E2E tests for UI features
- **mad-validate**: Runs E2E suite and verifies coverage
- **frontend/CLAUDE.md**: Playwright patterns and test isolation rules
