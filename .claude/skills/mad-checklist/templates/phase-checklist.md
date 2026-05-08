# Template — phase checklist

Canonical shape for `/mad-checklist <phase>` output. Phase-aware items derived from active WI + applicable rules.

> **EXAMPLE — replace this when authoring**

```markdown
# Checklist — <phase>

**Active WI**: <WI-id>
**Phase**: <spec | plan | tasks | implement | validate>
**Date**: <ISO date>

## Items

| # | Item | Status | Source |
|---|------|--------|--------|
| 1 | All `[ ]` tasks resolved or marked `[!]` | ⏸ | tasks.md |
| 2 | Quality gates green (latest run) | ⏸ | rules/quality-gates.md |
| 3 | No commits behind main on feature branch | ✓ | git status |
| 4 | `[!]` blockers acknowledged + tracked | ⚠ | tasks.md (1 unacknowledged) |

## Status legend

- ✓ verified satisfied
- ⏸ pending action
- ⚠ uncertain — needs verification
- ✗ explicitly violated

## Anti-hallucination

- Each ✓ cites: actual probe (file read, git query, command output)
- Never claim ✓ without observable evidence
- Source column maps every item to a specific rule or artifact

## Verdict

ACCEPT (all ✓) | ACCEPT_WITH_CAVEATS (some ⏸) | REJECT (any ✗ or ⚠)
```
