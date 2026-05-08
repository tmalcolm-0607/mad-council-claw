# Template — validation-report.md

Canonical shape for `/mad-validate` output. One report per feature; written at the end of the implement phase before moving to /apply-learnings.

> **EXAMPLE — replace this when authoring**

```markdown
# Validation Report — <feature-name>

**Spec**: specs/<N>-<slug>/spec.md
**Plan**: specs/<N>-<slug>/plan.md
**Date**: <ISO date>

## Summary

| Category | Result |
|----------|--------|
| FRs verified | N/M |
| Phases completed | N/M |
| Quality gates green | N/M |
| Behavioural probes captured | N |
| Open follow-ups | N |

## Feature Verification

For each FR:

| FR | Verification path (from plan.md Verification Spec) | Result | Evidence |
|----|---------------------------------------------------|--------|----------|
| FR-1 | curl POST /api/v1/foo → 201 | ✓ | response body excerpt + status |
| FR-2 | xUnit FooHandlerTests.HappyPath | ✓ | test runner output |
| FR-3 | Geneva p95 over 100 reqs | ⏸ | not yet captured (post-deploy) |

## Quality gates

- [x] Build (all 5 test projects)
- [x] Test (4 of 5 — IntegrationTests requires Cosmos; ran in ADO)
- [x] Coverage 100% diff (verified against ADO Update tab)
- [x] Bicep lint
- [ ] Pre-flight checks (1 minor warning — see follow-up FU-3)

## Pre-existing failures encountered

| Test | Status | Action |
|------|--------|--------|
| Worker.Tests/* | NU1900 (Enzyme auth) | known-local-only; passes in ADO |

## Follow-ups

- [ ] FU-1: Capture Geneva p95 after first prod deploy
- [ ] FU-2: Address SHOULD-FIX from /code-reviewer
- [ ] FU-3: Resolve Pre-flight warning in next iteration

## Verdict

ACCEPT | ACCEPT_WITH_CAVEATS | REJECT

Cite the determining factor:
- ACCEPT: all FRs verified, all gates green, no blocking follow-ups
- ACCEPT_WITH_CAVEATS: FRs verified but some follow-ups deferred; document explicitly
- REJECT: ≥1 FR unverified or ≥1 gate red — return to /mad-implement
```

## Anti-hallucination

Never mark an FR `✓` without quoted evidence (test output, response body, dashboard URL). FETCH BEFORE CITE applies.

## Reference templates

- `mad-implement/templates/implementation-report.md` — upstream input
