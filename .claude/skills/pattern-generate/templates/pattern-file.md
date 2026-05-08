# Template — pattern file (output of /pattern-generate)

Canonical shape for new files written under `rules/patterns/<lang>/<pattern>.md`.

> **EXAMPLE — replace this when authoring**

```markdown
---
title: "<Pattern name>"
status: preview
since: <ISO date>
last_reviewed: <ISO date>
applies_to:
  - paths/glob/**/*.cs
  - paths/glob/**/*.ts
---

# <Pattern name>

## Rule

<One-sentence rule. Imperative mood.>

## Why

<2-3 sentences. Cite the failure mode this prevents OR the consistency this enforces.>

## Do

```csharp
// good example, ≤6 lines, from real source
```

## Don't

```csharp
// anti-pattern example, ≤6 lines
```

## Examples in this codebase

- `src/api/FooHandler.cs:42` — canonical instance
- `src/api/BarHandler.cs:38` — variant

## Anti-patterns observed

- `src/api/BazHandler.cs:51` — drifts from rule by <reason>

## Cross-references

- `rules/<related>.md`
- `rules/skill-standards.md` § <relevant dimension>

## Promotion

When ready: change `status: preview` → `status: stable` per `rules/_status-convention.md`.
```

## Anti-hallucination

- Examples must be cited from real code, never fabricated for symmetry
- Status defaults to `preview`; promote only after one rollout cycle
- `applies_to` paths must match real files in the project
