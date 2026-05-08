# Template — skill refresh proposal

Canonical shape for `/skill-refresh <target>` output.

> **EXAMPLE — replace this when authoring**

```markdown
# Skill Refresh — <target>

**Date**: <ISO date>
**Current tier**: C (3/6)
**Tier-exempt?**: no

## Gap analysis

| Dimension | Status | Severity | Source template |
|-----------|--------|----------|-----------------|
| Frontmatter | ✓ | — | — |
| Best Practices | ✓ | — | — |
| Standards | ✓ | — | — |
| Evals | ✗ | MUST-FIX | `_template/evals/` |
| Templates | ✗ | SHOULD-FIX | `_template/templates/` |
| Multi-pass | ✗ | CONSIDER | `_template/SKILL.md` § flag taxonomy |

## Proposed patches (ordered by tier-delta)

### P-1: Add evals/ scaffold + basic-input fixture pair (delta: C → B)

Action: copy `_template/evals/test.ps1`, create fixtures/expected dirs, author `basic-input.md` pair.

### P-2: Add templates/ with skill-specific output template (delta: B → A)

(same shape)

### P-3: Add multi-pass mode (e.g., --council, --copilot) (delta: A → S)

(same shape)

## Anti-hallucination

- Each patch cites: matching reference template + expected tier delta
- Apply happens only after user-confirm

## Verdict

ACCEPT_WITH_CAVEATS — N patches proposed; user approves before apply.
```
