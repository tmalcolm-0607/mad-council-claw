---
category: orchestration-patterns
subcategory: verification-patterns
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# Verification Patterns (2026)

## Overview

Feature verification, quality gate execution, progressive validation, and test selection patterns for ensuring implementation correctness.

**Key capabilities**:
- Feature-verifier interprets structural soundness beyond pass/fail
- Progressive validation (5-tier) matches test scope to work phase
- Test-selector agent maps changed files to minimum test scope
- Hook-based enforcement prevents skipping gates

## Core Principles

| Principle | Description |
|-----------|-------------|
| **Feature Verification** | Use feature-verifier to interpret structural soundness |
| **Progressive Validation** | Match test scope to work phase (Tier 0-4) |
| **Test Selection** | Use test-selector agent for intelligent tier selection |
| **Gate Enforcement** | No skipping, paste actual output, fix before proceed |
| **Staleness Escalation** | Escalate tiers if last full suite run >24 hours ago |

## Patterns (Current)

### Feature Verification

**Purpose**: Interpret test results in context, distinguish real failures from acceptable outcomes.

**When to use**:
- After running quality gates
- After implementing feature tasks
- Before marking phase complete

**Verification workflow**:
1. Run quality gates (build, test, coverage, lint)
2. Spawn `feature-verifier` agent with gate output
3. Agent analyzes: structural soundness, test coverage, edge cases, error handling
4. Agent returns: PASS/FAIL + reasoning + recommendations

**Feature-verifier analyzes**:
- Do tests exercise core functionality?
- Are edge cases covered?
- Is error handling comprehensive?
- Are integration points verified?
- Are there gaps in coverage?

**Example prompt**:
```javascript
Task({
  subagent_type: "feature-verifier",
  prompt: `Verify OAuth2 authentication feature.

Test output:
[paste quality gate output]

Expected behavior:
- Login flow redirects to Google
- Tokens stored in Redis with TTL
- Token refresh on expiry
- Error handling for invalid tokens

Verify structural soundness and coverage.`
})
```

### Progressive Validation (5-Tier)

**Tier architecture** (backend-focused, frontend has separate tiers):

| Tier | Scope | Expected Time | Coverage % | Use Case |
|------|-------|---------------|------------|----------|
| **0: TDD Red/Green** | Single test method | <1s | 0.03% | TDD cycle (red-green-refactor) |
| **1: Fast Unit** | Domain + Application | 1s | 69% | Development (rapid feedback) |
| **2: Full Unit** | Tier 1 + Infrastructure | 81s | 98% | Pre-commit (Infrastructure changed) |
| **3: Core + Integration** | Tier 2 + Integration | 1m 30s | 99% | Phase gate (baseline) |
| **4: Full Suite (E2E)** | All including E2E | 7m 40s | 100% | PR gate, nightly builds |

**Time savings** (audit-validated from 3,282 tests):
- Tier 1 vs Tier 3: **99% savings** (1s vs 1m 30s)
- Tier 2 vs Tier 3: 10% savings (81s vs 1m 30s)

**Test distribution**:
- Domain.Tests: 1,410 tests, 155ms (true unit)
- Application.Tests: 836 tests, 885ms (service unit)
- Infrastructure.Tests: 1,405 tests, 1m 21s (database-dependent, Marten/PostgreSQL bottleneck)
- Integration.Tests: 63 tests, 8s (real integration)
- Api.Tests: 691 tests, 7m 34s (E2E workflows)

**Frontend tiers** (Tier 5a-c):
- **5a: Unit tests** (Vitest, 15s)
- **5b: Component tests** (Vitest + JSDOM, 30s)
- **5c: E2E smoke tests** (Playwright @p0, 2m)

### Test Selection

**test-selector agent** (`.claude/agents/test-selector.md`):
- Analyzes `git diff --name-only` output
- Maps changed files to minimum test scope
- Returns recommended tier with confidence level

**Selection confidence**:
- **HIGH**: Direct file-to-test mapping → execute recommended tier
- **MEDIUM**: Indirect mapping via project references → execute recommended tier
- **LOW**: Uncertain mapping → escalate to Tier 3 (all except E2E)
- **FAILED**: Agent error/timeout → fall back to Tier 3

**Invoked automatically** during `mad-implement` Phase 5.5.

**Test impact heuristic**:

| Changed Files | Recommended Tier | Rationale |
|---------------|------------------|-----------|
| Domain layer only | Tier 1 (Fast Unit) | Domain tests sufficient |
| Application layer | Tier 1 (Fast Unit) | Application tests sufficient |
| Infrastructure layer | Tier 2 (Full Unit) | Infrastructure.Tests required (1m 21s bottleneck) |
| Integration layer | Tier 3 (Core + Integration) | Integration.Tests required |
| API layer | Tier 4 (Full Suite) | Api.Tests E2E required |
| Config files (appsettings, .csproj) | Tier 3 (Core + Integration) | Broad impact, run integration |
| Unknown types (.json, .yml, .md) | Tier 3 (Core + Integration) | Conservative escalation |

### Staleness Thresholds

**Escalation conditions**:

| Condition | Action |
|-----------|--------|
| Last full suite run >24 hours ago | Escalate to Tier 3 minimum |
| Last full suite run >7 days ago | Escalate to Tier 4 (full E2E) |
| Previously failing tests exist | ALWAYS include in current tier |
| New tests added (not yet in baseline) | ALWAYS include in current tier |
| Unknown file types changed | Escalate to Tier 3 |
| Multiple layers changed simultaneously | Escalate to Tier 2 minimum |
| Config files changed | Escalate to Tier 3 |

### Hook-Based Enforcement

**TeammateIdle hook**:
- Runs when teammate about to go idle
- Exit code 2 sends feedback and keeps teammate working
- Use for verification before idle state

**TaskCompleted hook**:
- Runs when task being marked complete
- Exit code 2 prevents completion and sends feedback
- Use for quality enforcement

**validate-quality-gates.js hook**:
- Enforces tests run (not skipped)
- Enforces failures acknowledged and tracked
- Enforces "pre-existing failure" claims require proof (spec ID or fix commit)

## Changed Patterns (2025 → 2026)

| Pattern | 2025 | 2026 | Migration |
|---------|------|------|-----------|
| Test selection | Manual (always run full suite) | Intelligent (test-selector agent) | Enable test-selector in mad-implement |
| Progressive validation | Not available | 5-tier architecture (0-4 backend, 5a-c frontend) | Adopt tier model, use test-selector |
| Feature verification | Manual review | feature-verifier agent | Spawn agent after quality gates |
| Staleness tracking | Not tracked | Automatic escalation (>24h, >7d) | Enable staleness checks |
| Hook enforcement | Not available | TeammateIdle, TaskCompleted, validate-quality-gates | Enable hooks |

## Anti-Patterns

| Anti-Pattern | Problem | Correct Approach |
|--------------|---------|------------------|
| Running Tier 4 (E2E) during TDD | Wastes 7+ minutes per cycle | Use Tier 0 or Tier 1 (<1s) |
| Claiming "hours to minutes" savings | Baseline is 1m 30s, not "3+ hours" | Cite audit-validated metrics: 99% savings for Tier 1 |
| Running E2E during development | Api.Tests = 7m 34s, disproportionate cost | Reserve Tier 4 for PR gate only |
| Ignoring Infrastructure.Tests bottleneck | 1m 21s unavoidable (Marten/PostgreSQL) | Accept bottleneck at Tier 2 |
| Skipping test-selector without justification | Runs unnecessary tests | Always invoke test-selector |
| Dismissing pre-existing failures | "95 failures - not our problem" | Fix immediately, track for later, or add skip logic |

## Examples

### Example 1: Feature Verification After Tests

**Scenario**: OAuth2 authentication feature completed, gates run.

**Workflow**:
```javascript
// 1. Run quality gates
powershell -File scripts/run-quality-gates.ps1 -Profile backend

// 2. Spawn feature-verifier
Task({
  subagent_type: "feature-verifier",
  prompt: `Verify OAuth2 authentication feature.

Test output:
✓ Build succeeded
✓ 1,410 tests passed (Domain.Tests)
✓ 836 tests passed (Application.Tests)
✓ Coverage: 92%

Expected behavior:
- Login redirects to Google
- Tokens stored in Redis
- Token refresh on expiry
- Error handling for invalid tokens

Verify structural soundness.`
})

// 3. Agent analyzes and returns
// PASS: Core functionality verified, edge cases covered
// Recommendations: Add test for token refresh race condition
```

### Example 2: Tier Selection Based on Changed Files

**Scenario**: Changed files in Domain + Application layers.

**Workflow**:
```javascript
// 1. Spawn test-selector
Task({
  subagent_type: "test-selector",
  prompt: `Analyze git diff and recommend test tier.

Changed files:
- src/Domain/Entities/User.cs (modified)
- src/Application/Services/AuthService.cs (modified)
- tests/Domain.Tests/UserTests.cs (new)

Recommend minimum test tier.`
})

// 2. Agent returns
// Recommended tier: Tier 1 (Fast Unit)
// Confidence: HIGH
// Rationale: Changes isolated to Domain + Application, no Infrastructure/Integration impact

// 3. Execute Tier 1
dotnet test tests/Domain.Tests tests/Application.Tests
// Expected time: 1 second
```

**Staleness check**:
```javascript
// If last full suite run >24 hours ago → escalate to Tier 3
// Override test-selector recommendation
dotnet test src/DHSTSP.sln --filter "FullyQualifiedName!~Api.Tests"
// Expected time: 1m 30s
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Test-selector returns LOW confidence | Escalate to Tier 3 (conservative fallback) |
| Feature-verifier says FAIL but tests pass | Check for structural gaps (edge cases, error handling) |
| Tier 1 saves no time | Check Infrastructure.Tests bottleneck (1m 21s) - may need optimization |
| Pre-existing failures blocking commit | Fix immediately, create tracking spec, or add skip logic |
| E2E tests taking too long | Check if running Tier 4 unnecessarily (should be PR gate only) |

## See Also

- `quality-gates-2026.md` - Gate execution patterns
- `.claude/agents/feature-verifier.md` - Feature verifier agent
- `.claude/agents/test-selector.md` - Test selector agent
- `.claude/rules/quality-gates.md` - Progressive validation guide
- `.claude/rules/test-failure-protocol.md` - Failure handling

## Research Metadata

**Sources consulted**:
- https://code.claude.com/docs/en/best-practices (official - feedback loops)
- Project internal: `.claude/rules/quality-gates.md`, `.claude/agents/feature-verifier.md`, `.claude/agents/test-selector.md`

**Research date**: 2026-02-16
**Confidence level**: HIGH (validated across official docs + internal implementation)
**Frequency validation**: 90%+ (patterns appear in official docs + internal codebase)
