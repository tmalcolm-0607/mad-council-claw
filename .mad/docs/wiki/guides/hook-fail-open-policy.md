# Hook Fail-Open Policy

## Overview

All 36 hooks in `.claude/hooks/` currently implement a **fail-open** design pattern where errors in hook execution result in allowing the operation to proceed (exit 0) rather than blocking it.

This document explains the design trade-offs, identifies which hooks should fail-closed, and outlines the remediation plan.

---

## Current Design Pattern

All hooks follow this pattern:

```javascript
async function main() {
  try {
    // Hook logic here
    // ...
  } catch (err) {
    console.error(`[${hookName}] Error:`, err.message);
    process.exit(0);  // Fail-open: Allow operation on error
  }
}
```

**Behavior**: When a hook encounters an error (malformed JSON, file system error, logic exception), it logs the error to stderr and exits with code 0, allowing the operation to proceed.

---

## Trade-offs

### Advantages of Fail-Open

1. **Workflow Continuity**: Broken hooks don't halt development
2. **Graceful Degradation**: Infrastructure issues don't block work
3. **Lower Support Burden**: Developers aren't blocked by hook bugs
4. **Safe Experimentation**: New hooks can be tested without risk

### Disadvantages of Fail-Open

1. **Security Bypass**: Malicious input could trigger errors that bypass security checks
2. **Silent Failures**: Enforcement hooks fail silently, undermining their purpose
3. **False Confidence**: Developers assume checks ran when they didn't
4. **Audit Gaps**: No record of bypassed checks

---

## Hooks That SHOULD Fail-Closed

These hooks enforce critical security, quality, or correctness constraints and should **block operations on error** rather than allowing them to proceed:

### Security Hooks (5)
- `pre-bash-validate.js` - Blocks dangerous commands (rm -rf, etc.)
- `enforce-orchestration.js` - Enforces "agents work, main coordinates" pattern
- `enforce-e2e-smoke.js` - Blocks commits without E2E test coverage
- `e2e-mock-check.js` - Prevents mocking in E2E tests
- `pre-commit-validate.js` - Validates commit message format

### Quality Gates (3)
- `validate-baseline-size.js` - Enforces baseline size limits
- `validate-agent-deliverable.js` - Validates agent output completeness
- `validate-phase-structure.js` - Validates MAD phase structure

### Critical Workflow (2)
- `pre-compact.js` - Ensures work is saved before context compaction
- `scope-guard.js` - Prevents scope creep during implementation

**Total**: 10 hooks should fail-closed (exit 1 or 2 on error)

---

## Hooks That Can Remain Fail-Open

These hooks provide guidance, warnings, or monitoring. Failures are annoying but not security-critical:

### Monitoring & Metrics (3)
- `update-context-failure.js`
- `update-work-item.js`
- `update-summary-file.js`

### Advisory Warnings (5)
- `context-warning.js`
- `detect-anomaly.js`
- `parallel-opportunity-detector.js`
- `plan-mode-warning.js`
- `add-context.js`

### Learning & Analysis (1)
- `capture-learning.js`

> Note: previous revisions of this doc listed `failure-analyze.js` and `pattern-updates.js` here, but those hooks were never implemented or were removed. The `failure-analyze` *skill* lives at `.claude/skills/failure-analyze/` (now deprecated; subsumed by `/session-improve analyze`).

### Session Management (2)
- `session-start.js`
- `session-end.js`

### Quality Helpers (3)
- `auto-run-quality-gates.js` (advisory, not enforcement)
- `on-gate-fail.js` (reporting only)
- `pre-commit-tokens.js` (warn-only mode per user decision)

**Total**: 16 hooks can remain fail-open

---

## Hybrid Approach: Warn-Then-Block

Some hooks should provide **warnings before blocking**:

### `enforce-e2e-smoke.js` (Environment-Gated)
- **Default**: Warn via stderr, allow commit (fail-open)
- **With `ENFORCE_E2E=1`**: Block commit (fail-closed)
- **Rationale**: Gradual rollout, opt-in enforcement

### `pre-commit-tokens.js` (Warn-Only)
- **Always**: Warn via stderr, allow commit (fail-open)
- **Rationale**: Natural file growth shouldn't block commits (per user decision)

---

## Remediation Plan

**Status**: Phase 1 Task 1.6 (MAJOR EFFORT - 6-8 hours)

All 36 hooks will be updated to fail-closed per user decision. The pattern will change to:

```javascript
async function main() {
  try {
    // Hook logic here
    // ...
  } catch (err) {
    console.error(`[${hookName}] FATAL ERROR:`, err.message);
    console.error(`[${hookName}] Hook failed - operation blocked for safety.`);
    console.log(JSON.stringify({
      exit: 2,
      message: `${hookName} failed: ${err.message}. Operation blocked for safety.`
    }));
    process.exit(1);  // Fail-closed: Block operation on error
  }
}
```

### Circuit Breaker Mechanism

To allow temporary bypass of problematic hooks:

```bash
# To bypass a specific hook temporarily:
touch .mad/scratch/disable-enforce-orchestration

# Each hook checks at startup:
if (fs.existsSync('.mad/scratch/disable-' + hookName)) {
  console.error('[CIRCUIT BREAKER] Hook disabled via file');
  process.exit(0);
}
```

---

## Logging Enhancement

To make silent failures visible (even when fail-open), all catch blocks should log:

```javascript
catch (err) {
  console.error(`[${hookName}] ERROR:`, err.message);
  // Fail-open or fail-closed depending on hook type
}
```

**Rationale**: Even advisory hooks should log errors so operators can identify broken hooks.

---

## Testing Requirements

Before deploying fail-closed hooks, each must be tested with:

1. **Happy path**: Normal operation succeeds
2. **Malformed input**: Invalid JSON, missing fields
3. **File system errors**: Missing files, permission denied
4. **Logic errors**: Null reference, type errors

Test harness created in Phase 0.5 (`.claude/hooks/__tests__/`).

---

## Rollback Strategy

If fail-closed hooks cause operational issues:

1. **Per-Hook Bypass**: Use circuit breaker file (see above)
2. **Emergency Disable**: Unregister hook from `.claude/settings.json`
3. **Revert to Fail-Open**: Change exit 1 back to exit 0 for specific hooks

All changes tracked with annotated git tags for safe rollback.

---

## References

- **Phase -1 Security Fixes**: This documentation task
- **Phase 1 Task 1.6**: Convert all 36 hooks to fail-closed
- **Hook Test Harness**: `.claude/hooks/__tests__/`
- **Circuit Breaker Implementation**: Phase 1 (included in fail-closed conversion)

---

## Revision History

- **2026-02-16**: Initial documentation (Phase -1 Task 3)
- **Future**: Updated after Phase 1 Task 1.6 completion with fail-closed conversion results
