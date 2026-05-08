# Template — skill audit matrix

Canonical shape for `/skill-audit` output.

> **EXAMPLE — replace this when authoring**

```markdown
# Skill Audit — <ISO date>

**Skills audited**: <count>
**Standard**: `rules/skill-standards.md` (6 dimensions)

## Tier histogram

| Tier | Count | % |
|------|-------|---|
| S (6/6) | 8 | 12% |
| A (5/6) | 14 | 21% |
| B (4/6) | 22 | 33% |
| C (2-3/6) | 14 | 21% |
| D (0-1/6) | 8 | 12% |

## Per-skill scoring

| Skill | Frontmatter | BP | Std | Evals | Templates | Multi-pass | Tier | Tier-exempt? |
|-------|-------------|----|----|-------|-----------|------------|------|--------------|
| pr-review | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | S | — |
| council-review | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | S | — |
| git-commit | ✓ | ✓ | ✓ | ✓ | — | — | C | yes (templates, multi-pass) |

## Gaps by dimension

| Dimension | Skills missing |
|-----------|----------------|
| Templates | 18 (5 tier-exempt; 13 actionable) |
| Multi-pass | 26 (12 tier-exempt; 14 actionable) |

## Anti-hallucination

- Each row cites: skill SKILL.md frontmatter parsed + dimension presence verified by file existence
- Tier-exempt rows cite the rationale (pure-utility per skill-standards.md)
- Empty cells stated explicitly

## Verdict

ACCEPT — audit complete; gaps surface for next standardization loop.
```

## Reference

- Output also written to `.mad/scratch/skill-audit-matrix.csv` for diffing
