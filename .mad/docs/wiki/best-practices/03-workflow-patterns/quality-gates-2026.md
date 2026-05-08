---
category: workflow-patterns
subcategory: quality-gates
last_updated: 2026-02-16
sources_checked: 2026-02-16
next_refresh: 2026-05-16
confidence: HIGH
---

# Quality Gates (2026)

## Overview

Quality gate execution patterns, profile selection, enforcement rules, and progressive validation integration for ensuring code quality.

**2026 Update**: Hooks for CI/CD enforcement, automated profile selection, status checks required for merge, and integration with GitHub Actions for AI-authored change reviews.

## Core Principles

| Principle | Description |
|-----------|-------------|
| **No Skipping** | All gates must execute, no exceptions |
| **Proof Required** | Paste actual command output |
| **Fix Before Proceed** | Gate failures block next phase |
| **Auto Profile Selection** | Backend/frontend/full based on changed files |
| **E2E Enforcement** | Frontend commits require E2E within 4 hours |
| **Hooks as Enforcement** | Transform guidelines into enforced rules |
| **Status Checks Required** | AI-authored changes need reviews before merge |

## Patterns (Current)

### Gate Execution

**Standard gate sequence**:

| Gate | Purpose | Success Criteria |
|------|---------|------------------|
| **Build** | Compile/transpile code | Exit 0, no errors |
| **Test** | Run unit/integration tests | All pass, 0 failed |
| **Coverage** | Measure code coverage | >= threshold (typically 90%) |
| **Lint/Format** | Check code style | Exit 0, no errors |
| **Security** | Check for vulnerabilities | No high/critical issues |

**Enforcement rules**:
1. **NO SKIPPING**: Every gate must be executed
2. **PROOF REQUIRED**: Paste actual command output
3. **FIX BEFORE PROCEED**: If tests fail → fix with targeted `--filter` runs first → then re-run ALL gates once
4. **COMMIT AFTER GATES**: Only commit code that passes ALL gates
5. **ZERO TOLERANCE FOR "PRE-EXISTING" EXCUSES**: All test failures discovered during your session are YOUR responsibility

### Profile Selection

**Auto-detection based on changed files**:

| Changed Files | Profile Selected | Execution Time |
|---------------|-----------------|----------------|
| Only `src/**/*.cs`, `tests/**/*.cs` | `backend` | ~2 min |
| Only `frontend/**/*.{ts,tsx,css}` | `frontend` | ~3 min |
| Both backend + frontend files | `full` | ~5 min |
| Only docs/config (no code changes) | `backend` (default) | ~2 min |

**Manual override**:
```bash
powershell -File scripts/run-quality-gates.ps1 -Profile backend
powershell -File scripts/run-quality-gates.ps1 -Profile frontend
powershell -File scripts/run-quality-gates.ps1 -Profile full
```

### Progressive Validation Integration

**Match test tier to work phase**:

| Work Phase | Test Tier | Time | Gates |
|------------|-----------|------|-------|
| TDD cycle (red-green) | Tier 0 (single test) | <1s | Build + single test method |
| Development (after task) | Tier 1 (fast unit) | 1s | Build + Domain + Application tests |
| Pre-commit | Tier 2 (full unit) | 81s | Build + all unit tests (+ Infrastructure) |
| Phase gate | Tier 3 (core + integration) | 1m 30s | All gates except E2E |
| PR gate | Tier 4 (full suite) | 7m 40s | ALL gates including E2E |

**test-selector agent** analyzes git diff and recommends minimum tier (invoked automatically during `mad-implement`).

### Hooks for CI/CD Enforcement (2026)

**Released early 2026**: "Hooks are user-defined commands, prompts, or agents that execute automatically at specific points in Claude Code's lifecycle."

**Transform guidelines into enforced rules**:

```yaml
# GitLab CI example
quality-gates:
  stage: test
  script:
    - powershell -File scripts/run-quality-gates.ps1
  only:
    - merge_requests
  allow_failure: false  # Block merge if gates fail

# Post results as comment on MR
  after_script:
    - curl -X POST "$CI_API_V4_URL/projects/$CI_PROJECT_ID/merge_requests/$CI_MERGE_REQUEST_IID/notes"
      --header "PRIVATE-TOKEN: $GITLAB_TOKEN"
      --form "body=Quality gates: $(cat gate-results.txt)"
```

**GitHub Actions example**:
```yaml
name: Quality Gates
on:
  pull_request:
    types: [opened, synchronize]

jobs:
  quality-gates:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run quality gates
        run: powershell -File scripts/run-quality-gates.ps1
      - name: Post results
        if: always()
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const results = fs.readFileSync('gate-results.txt', 'utf8');
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: `## Quality Gates\n\n${results}`
            });
```

**Benefits**:
- Automatic execution on PR/MR events
- Results posted as comments
- Merges blocked until all gates pass
- Consistent enforcement (no manual bypass)

### Security Best Practices (2026)

**For CI/CD integration**:

| Practice | Reason |
|----------|--------|
| **Least-privilege permissions** | Avoid `contents: write` unless must open PRs |
| **Require status checks** | AI-authored changes need reviews |
| **Block merges until gates pass** | Enforce quality standards |
| **Review AI-generated code** | Claude as second engineer, humans approve |

**Hook configuration** (GitLab/GitHub CI):
- Configure hooks in pipeline
- Automatic execution on PR/MR events
- Status checks required for merge

## Risk-Tiered Verification

Tasks in `tasks.md` may include an optional `Risk Tier` field that classifies their security impact. This determines which additional gates are required beyond the standard build/test/lint/coverage gates.

### Risk Tiers

| Tier | Meaning | Additional Gates |
|------|---------|------------------|
| `SECURITY-CRITICAL` | Touches auth, crypto, secrets, PII, or payments | Security audit + mandatory human sign-off |
| `STANDARD` | Normal business logic, UI, utilities | Standard gates only |
| (absent) | Field not specified | Treated as `STANDARD` |

### What Happens for SECURITY-CRITICAL Tasks

When `mad-implement` encounters a task with `Risk Tier: SECURITY-CRITICAL`:

1. **Pre-implementation**: `security-auditor` agent produces a threat assessment
2. **Post-implementation**: `security-auditor` agent performs a character-level code review
3. **Manual approval**: Orchestrator pauses for explicit user sign-off before marking task complete

Standard quality gates (build, test, lint, coverage) still apply to **all** tasks regardless of risk tier.

### When to Assign SECURITY-CRITICAL

Assign to tasks that modify:
- Authentication (login, tokens, sessions)
- Authorization (roles, permissions, access control)
- Cryptography (encryption, hashing, key management)
- Secrets (API keys, connection strings, vault access)
- Payment processing (PCI-scoped code)
- PII handling (user data, GDPR, data export)
- Input sanitization (SQL construction, HTML rendering, command execution)
- Infrastructure security (CORS, CSP, TLS, firewall rules)

### Task Example

```markdown
## T010: Update session token validation
Risk Tier: SECURITY-CRITICAL
...
```

See `.claude/docs/risk-tiered-verification-guide.md` for the full classification guide with examples, and `.claude/docs/mad-implement-risk-routing.md` for dispatch logic.

## Changed Patterns (2025 → 2026)

| Pattern | 2025 | 2026 | Migration |
|---------|------|------|-----------|
| **Hooks** | Conceptual | Production-ready (Q1 2026) | Configure hooks in CI pipeline |
| **Manual CI integration** | Inconsistent enforcement | Hooks for automatic quality gates | Use hooks for automatic enforcement |
| **Profile selection** | Manual | Auto-detection based on changed files | Let gates script detect profile |
| **E2E enforcement** | Optional | Required for frontend commits (4-hour window) | Configure E2E staleness threshold |

## Anti-Patterns

| Anti-Pattern | Problem | Correct |
|--------------|---------|---------|
| Skipping gates | Quality gaps compound | NO SKIPPING - all gates must execute |
| Dismissing pre-existing failures | Unreliable test suite | All failures are YOUR responsibility - fix, track, or skip properly |
| Running wrong profile | Wastes time (full when backend-only) | Let auto-detection choose profile |
| Manual CI integration | Inconsistent enforcement | Use hooks for automatic gates |
| Bypassing E2E staleness | Untested UI changes reach production | Run E2E within 4 hours or fix staleness |
| Claiming "hours to minutes" savings | Baseline is 1m 30s (Tier 3) | Cite audit-validated metrics |

## Examples

### Example 1: Backend Gates

```bash
# Auto-detected profile (backend only changes)
powershell -File scripts/run-quality-gates.ps1

# Output:
# Detected changes: src/Services/UserService.cs, tests/Services.Tests/UserServiceTests.cs
# Selected profile: backend
#
# Gate 1: Build
# dotnet build
# Build succeeded. 0 Warning(s), 0 Error(s)
#
# Gate 2: Tests (Tier 2 - full unit)
# dotnet test tests/Domain.Tests tests/Application.Tests tests/Infrastructure.Tests
# Total tests: 3651. Passed: 3651. Failed: 0. Skipped: 0.
# Time: 81 seconds
#
# Gate 3: Lint
# dotnet format --verify-no-changes
# No changes needed.
#
# Result: PASS - All gates passed
```

### Example 2: Frontend Gates with E2E

```bash
# Auto-detected profile (frontend changes)
powershell -File scripts/run-quality-gates.ps1

# Output:
# Detected changes: frontend/src/components/Auth.tsx, frontend/e2e/auth.spec.ts
# Selected profile: frontend
#
# Gate 1: Build
# npm run build
# Build completed successfully.
#
# Gate 2: Tests
# npm test
# Test Suites: 45 passed, 45 total
# Tests:       312 passed, 312 total
#
# Gate 3: E2E Smoke Tests
# npm run test:e2e -- --grep @p0
# ✓ [P0] Login flow (2.3s)
# ✓ [P0] Create campaign (3.1s)
# ✓ [P0] Join game (1.8s)
# 3 passed (7.2s)
#
# Gate 4: Lint
# npm run lint
# No issues found.
#
# Result: PASS - All gates passed (E2E last run: 2 minutes ago)
```

### Example 3: Hooks CI/CD Enforcement

```yaml
# .gitlab-ci.yml
stages:
  - test
  - merge-check

quality-gates:
  stage: test
  script:
    - powershell -File scripts/run-quality-gates.ps1 | tee gate-results.txt
  artifacts:
    reports:
      junit: test-results.xml
    paths:
      - gate-results.txt
  only:
    - merge_requests
  allow_failure: false  # BLOCK merge if gates fail

merge-readiness:
  stage: merge-check
  script:
    - echo "All quality gates passed - ready to merge"
  dependencies:
    - quality-gates
  only:
    - merge_requests
```

**Effect**: MR cannot be merged until `quality-gates` job passes. Results posted as MR comment automatically.

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "E2E tests required but not run recently" | Run frontend gates: `powershell -File scripts/run-quality-gates.ps1 -Profile frontend` OR bypass: `git commit --no-verify` (must run E2E within 4 hours) |
| "Quality gates taking too long" | Check profile selection - backend-only should run `backend` (~2min) not `full` (~5min) |
| Gates failing with pre-existing failures | ALL failures are YOUR responsibility - fix immediately, create bug spec, or add skip logic |
| Hooks not triggering in CI | Check pipeline configuration, verify hook script is executable, ensure `allow_failure: false` |
| Wrong tier selected by test-selector | Review git diff analysis, manually override with `--force-full` if needed |

## See Also

- `testing-strategies-2026.md` - Testing pyramid
- `verification-patterns-2026.md` - Progressive validation
- `.claude/rules/quality-gates.md` - Gate rules
- `.claude/rules/test-failure-protocol.md` - Handling test failures
- `git-workflow-2026.md` - Hooks for GitHub Actions

## Research Metadata

**Sources consulted**:
- https://www.pixelmojo.io/blogs/claude-code-hooks-production-quality-ci-cd-patterns (hooks)
- https://skywork.ai/blog/how-to-integrate-claude-code-ci-cd-guide-2025/ (CI/CD)
- https://code.claude.com/docs/en/best-practices (official)

**Research date**: 2026-02-16
**Confidence level**: HIGH (validated across official docs + community implementations)
**Frequency validation**: 85%+ (patterns appear in official docs + 2+ community sources)
