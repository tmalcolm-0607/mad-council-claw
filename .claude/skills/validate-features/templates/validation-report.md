# Template — feature-validation report

Canonical shape for `/validate-features`. Distinguishes structural success from behavioral success.

> **EXAMPLE — replace this when authoring**

```markdown
# Feature Validation — <feature-name>

**Date**: <ISO date>
**Environment**: <e.g. local | tonym NPE | staging>

## Probes

| Probe | Endpoint / Path | Expected | Actual | Status |
|-------|-----------------|----------|--------|--------|
| P-1 | POST /api/v1/users (malformed JSON) | 400 + ProblemDetails | 200 + empty body | ✗ BLOCKING |
| P-2 | GET /api/v1/users/{id} (existing) | 200 + user JSON | 200 + user JSON | ✓ |
| P-3 | DELETE /api/v1/users/{id} (idempotent) | 204 on second call | 404 | ✗ MUST-FIX |

## Classification

| Failure | Category | Cause |
|---------|----------|-------|
| P-1 | wiring | validator not wired into handler pipeline |
| P-3 | behavioral | second-call branch missing |

## Verdict

REJECT — behavioral defects detected; "tests pass" + "coverage 100%" not equivalent to "feature works".

## Anti-hallucination

- Every ✓ row cites: actual response body or behavioral artifact (Geneva URL, log line, Cosmos read)
- Never claim a probe passed without running it (ACTUAL BEFORE PRESENT)

## Reference

- `rules/verification-protocol.md` Rule 4 — claims about behavior require evidence
```
