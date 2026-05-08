# Template — CLAUDE.md refresh report

Canonical shape for `/claude-md-refresh` output. Per-section drift + proposed patches.

> **EXAMPLE — replace this when authoring**

```markdown
# CLAUDE.md Refresh — <ISO date>

**Operator**: <alias>
**CLAUDE.md path**: <absolute>

## Section audit

| Section | Last drift evidence | Severity |
|---------|---------------------|----------|
| Quality Gates | rules/quality-gates.md updated 2026-04 (5-tier table) | MUST-FIX |
| Orchestration | matches current rule | OK |
| Some Stale Section | references `.claude/scripts/` (paths moved to `.mad/scripts/` 2026-02) | BLOCKING (broken paths) |

## Proposed patches

### P-1: Quality Gates — add tier-0

```diff
-## Quality Gates
-Run all gates before commit.
+## Quality Gates
+Run all gates before commit. Use `test-selector` agent for tier selection (Tier 0-4).
+
+| Tier | Scope | Time | Use case |
+|------|-------|------|----------|
+| 0 | single test | <1s | TDD red-green |
+...
```

### P-2: Stale Section — fix paths

```diff
-References scripts under `.claude/scripts/`...
+References scripts under `.mad/scripts/` (moved 2026-02)...
```

## Verdict

ACCEPT_WITH_CAVEATS — patches proposed; user reviews before apply.
```

## Anti-hallucination

- Every proposed patch cites: matching rule file + line, or current code state
- Path references verified by Read or Grep, never assumed
