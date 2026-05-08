# Template — best-practices refresh report

Canonical shape for `/refresh-best-practices` output. Diff vs external sources + proposed patches with severity.

> **EXAMPLE — replace this when authoring**

```markdown
# Best Practices Refresh — <ISO date>

**Sources scanned**:
- LENS-Common (commit `<sha>`)
- Marketplace plugins (`<list>`)
- Web (OWASP LLM Top 10 2026, etc.)

## Drift summary

| Severity | Count |
|----------|-------|
| BLOCKING | 0 |
| MUST-FIX | 2 |
| SHOULD-FIX | 5 |
| CONSIDER | 3 |

## Findings

### MF-1: rules/quality-gates.md missing 5-tier validation

**Source**: LENS-Common `quality-gates.md` (commit `<sha>`)
**Local**: 4-tier table; new tier-0 (single-test `--filter`) added in source 2026-04
**Patch**: append tier-0 row + commentary
**Confidence**: 0.86

(repeat per finding)

## Proposed patches (ordered)

For each: cite the source + the diff + rationale. User reviews before apply.

## Anti-hallucination

- Every cited external source must be reachable + recent
- FETCH BEFORE CITE: rules content read, not paraphrased

## Verdict

ACCEPT_WITH_CAVEATS — N patches awaiting user approval.
```

## Reference

- `rules/skill-standards.md` — taxonomy of dimensions audited
- `rules/_status-convention.md` — status frontmatter on rules
