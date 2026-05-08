# Template — PR pattern extraction report

Canonical shape for `/pr-pattern-extract` output.

> **EXAMPLE — replace this when authoring**

```markdown
# PR Pattern Extraction — <window>

**Date**: <ISO date>
**Window**: last <N> days
**PRs sampled**: <count>
**Comments analyzed**: <count>

## Recurring topics (≥3 instances threshold)

### RT-1: validator wiring missing on new handler

**Frequency**: 5 PRs (across 4 distinct authors)
**Excerpts**:
- PR-5157551#thread123: "missing IValidator<T> wire-up in handler constructor"
- PR-5155516#thread88: "ValidateAsync not called before business logic"
- PR-5152099#thread44: same

**Proposed pattern**: `rules/patterns/_dotnet/validator-wiring.md`

### RT-2: ETag propagation drop on UpdateAsync

(same shape)

## Anti-hallucination

- Each excerpt cited verbatim with PR + thread URL
- Frequency = distinct PRs, not raw comments (avoids self-thread inflation)
- Author diversity tracked separately from frequency

## Verdict

ACCEPT — N candidates queued for /apply-learnings review.
```
