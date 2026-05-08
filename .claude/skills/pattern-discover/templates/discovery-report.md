# Template — pattern discovery report

Canonical shape for `/pattern-discover` output.

> **EXAMPLE — replace this when authoring**

```markdown
# Pattern Discovery — <target-tree>

**Date**: <ISO date>
**Target**: <path>
**Languages**: <list>

## Pattern candidates

### PC-1: Validator wiring on request DTOs

**Frequency**: 12 of 14 handler classes
**Examples**:
- `src/api/FooHandler.cs:42`
- `src/api/BarHandler.cs:38`
- `src/api/BazHandler.cs:51`

**Shape**: handler ctor injects `IValidator<T>`; first line of method calls `await _validator.ValidateAsync(req); throw on failure`.

**De-dup vs existing**: not in `rules/patterns/_dotnet/*.md` — new candidate.

### PC-2: <name>

(same shape)

## Anti-hallucination

- Frequency counts come from grep, not estimation
- Each example cites file:line; ≥3 instances required for a candidate
- De-dup check is FETCH BEFORE CITE on existing pattern files

## Verdict

ACCEPT — N candidates surfaced; user reviews via /pattern-generate or /apply-learnings.
```
