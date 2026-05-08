# Template — references refresh report

Canonical shape for `/refresh-references` output. One row per cloned reference repo.

> **EXAMPLE — replace this when authoring**

```markdown
# References Refresh — <ISO date>

**Operator**: <alias>

## Per-repo

| Repo | Status | Behind | Ahead | New branches | Last commit | Notes |
|------|--------|--------|-------|--------------|-------------|-------|
| reference-foo | UPDATED | 0 | 12 | 0 | abc1234 | clean |
| reference-bar | UP-TO-DATE | 0 | 0 | 0 | def5678 | — |
| reference-baz | FETCH-FAILED | — | — | — | — | auth error: re-pim and retry |

## Summary

- N repos refreshed
- M up-to-date
- K failed (re-pim recommended)

## Failed repos

For each failure: cite the error verbatim + retry guidance.

## Anti-hallucination

- Empty `references/` stated explicitly, not silently passed
- Status reflects actual `git fetch` exit code, never assumption
```

## Reference

- See `rules/deployment-failure-diagnosis.md` for the broader "actual state vs reported state" discipline
