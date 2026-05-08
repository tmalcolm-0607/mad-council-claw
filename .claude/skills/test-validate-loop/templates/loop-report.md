# Template — test-validate-loop report

Canonical shape for `/test-validate-loop` output.

> **EXAMPLE — replace this when authoring**

```markdown
# Test-Validate Loop — <project>

**Project**: <test-project-path>
**Date**: <ISO date>
**Stop conditions**: green OR no-progress-for-2 OR max-5-iterations

## Per-iteration

| Iter | Failures at start | Failures at end | Action |
|------|-------------------|-----------------|--------|
| 1 | 3 | 2 | fixed null-handling in FooHandler |
| 2 | 2 | 1 | fixed retry policy bug |
| 3 | 1 | 0 | green |

## Final state

- Tests run: 87
- Passed: 87
- Failed: 0
- Skipped: 4 (infra-dependent — `Skip.IfNot(IsDockerRunning, "...")`)

## Pre-existing failures encountered

| Test | Status | Action |
|------|--------|--------|
| Worker.Tests/* | local-only NU1900 | known; runs in ADO |

## Anti-hallucination

- Each iter cites: actual test runner output (stdout excerpt)
- Pre-existing failures tracked separately, never dismissed
- Loop bound enforced; never claims green without runner confirmation

## Verdict

ACCEPT — green achieved. (or REJECT with retained failure list if stop condition hit.)
```
