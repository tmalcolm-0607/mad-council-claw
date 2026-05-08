# Template — decomposition.md

Canonical shape for `/mad-decompose` output. Used when a feature is too large for one MAD pass; produces N sub-features each runnable as `/mad-spec → /mad-plan → /mad-tasks`.

> **EXAMPLE — replace this when authoring**

```markdown
# Decomposition — <epic-name>

**Source**: specs/ideas/<slug>.md OR a spec/plan that exceeded scope
**Date**: <ISO date>
**Author**: <alias>

## Vertical slice rule

Each sub-feature must be a **vertical slice**: independently shippable end-to-end (DB → API → UI/CLI), tested, observable. Horizontal layers (a "data layer feature" without API or UI) are rejected.

## Sub-features

### S1: <name>

**Slice**: DB schema + handler + integration test + minimal UI/CLI surface
**Spec target**: `specs/<N>-<slug>/spec.md`
**Estimated effort**: <hours>
**Dependencies**: none (or: requires S2 first)
**Security-critical?**: yes/no

### S2: <name>

(same shape)

## Dependency graph

```
S1 ─┬─> S3
S2 ─┘
S4 (independent)
```

## Sequencing guidance

1. S1 + S2 in parallel (no shared files; disjoint owners)
2. S3 after both S1 and S2 land
3. S4 any time

## Cross-slice coordination

| Concern | Owner slice | How addressed |
|---------|-------------|---------------|
| Shared DB schema | S1 (creator); S3 ALTERs | Migration numbering pre-assigned |
| Auth contract | S2 (defines); S3, S4 (consume) | TypeScript type in coordination doc |
| Observability hooks | each slice | per-slice metrics; shared correlation ID format |

## Out-of-scope (intentionally deferred)

- <Item 1: why deferred>
- <Item 2: why deferred>
```

## Acceptance criterion

A decomposition is acceptable if:
- Every sub-feature is a vertical slice (per the rule above).
- Dependencies are explicit and acyclic.
- Cross-slice coordination has named owner per concern.
- Out-of-scope is documented (not silently dropped).

## Reference templates

- `mad-spec/templates/spec.md` — downstream output (one per slice)
