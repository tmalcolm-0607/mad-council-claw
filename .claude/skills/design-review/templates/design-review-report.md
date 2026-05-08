# Template — design review report

Canonical shape for `/design-review` output on a design document.

> **EXAMPLE — replace this when authoring**

```markdown
# Design Review — <design-doc-title>

**Reviewer**: <name or "automated">
**Document**: <path-to-design-doc>
**Mode**: <standard | --council | --deep>
**Date**: <ISO date>

## Implementability gates (BLOCKING)

| # | Gate | Status |
|---|------|--------|
| 1 | Vision/Contract flag — every FR Logical Proof points to a file/endpoint/command | ✓ / ✗ |
| 2 | Newspaper Test — "what file confirms this FR?" has a concrete answer | ✓ / ✗ |
| 3 | 3 Nouns Test — each user story has ≥3 concrete artifacts | ✓ / ✗ |
| 4 | Implementation Squeeze — top 3 FRs yield a first verification command | ✓ / ✗ |
| 5 | Concept Density — ≤5 new coined terms undefined via primitives | ✓ / ✗ |
| 6 | Test Plan Generation — blocking for contract specs, non-blocking for ideas/ | ✓ / ✗ |

If any gate fails → **REJECT** until addressed.

## Findings

[Apply Output Contract format from pr-review/templates/review-findings.md]

## Open questions ([NEEDS CLARIFICATION] markers)

- [ ] Q1: ...
- [ ] Q2: ...

These are NOT findings to fix; they are explicit unknowns that must be answered before implementation.

## Anti-hallucination check

- [x] Categories with no findings stated explicitly
- [x] Vision-vs-Contract flag set; vision docs aren't reviewed as contracts

## Verdict

ACCEPT | ACCEPT_WITH_CAVEATS | REJECT (with gate failure reasons)
```

Reference `pr-review/templates/review-findings.md` for the per-finding shape.
