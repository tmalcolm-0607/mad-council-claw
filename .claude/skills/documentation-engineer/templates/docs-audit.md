# Template — documentation audit

Canonical shape for `/documentation-engineer` output.

> **EXAMPLE — replace this when authoring**

```markdown
# Documentation Audit — <ISO date>

## Per-doc

| File | Last touched | Stale references | Severity |
|------|--------------|------------------|----------|
| README.md | 2 mo ago | `--old-flag` removed; new flag is `--new-flag` | MUST-FIX |
| docs/ARCHITECTURE.md | 3 mo ago | mentions deprecated service `Foo` | SHOULD-FIX |
| CONTRIBUTING.md | absent | — | CONSIDER (project has informal contribution conventions) |

## Proposed patches

For each: cite source-of-truth (code grep, git log, ADR) + diff.

## Anti-hallucination

- Every code reference verified by Read or Grep
- Never claim "added in vX" without git tag / commit evidence

## Verdict

ACCEPT_WITH_CAVEATS — N patches proposed; user approves before write.
```
