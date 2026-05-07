---
artifact-class: feature-ledger
generated-by: hand-authored (wave-007 / lane-b)
status: deferred
status-since: 2026-05-06
status-history:
  - status: deferred
    at: 2026-05-06
    by: wave-007 / lane-b
    note: "Initial creation in deferred state; M19 catalog item per foundational-plan; never transitions to red unless user explicitly re-opens"
feature-id: F-D-005
short-slug: schema-migration
milestone: M19
provenance:
  surfaces:
    - kit:foundational-plan.md M19 row
    - kit:rules/no-silent-deferrals.md
fr-coverage: []
test-files:
  unit: []
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects: []
red-green-rule: |
  N/A while status: deferred. If re-opened, the standard contract applies.
depends-on: [F-008, F-070, F-088, F-089]
out-of-scope-notes: |
  Deferred per user decision; not part of v1. v1's persistent shapes (storage layout F-008,
  encrypted-storage F-070, soul snapshots F-088/F-089) are versioned in their own frontmatter
  but no engine-driven migration runner upgrades older shapes to newer ones. A v1 engine
  encountering a v0.x shape will reject with a structured error, not auto-migrate.
confidence: high
---

# F-D-005 — Schema migration runner (DEFERRED)

## Status

**Deferred to v1.5+ per `rules/no-silent-deferrals.md`.**

## Summary

Engine-driven schema migration: detect version skew between on-disk shapes (storage / soul / settings / audit-chain frame format) and the running engine's expected version, run the appropriate migration in-place, and emit a MIGRATION audit-chain entry per shape per version delta. v1 surfaces version skew as a structured rejection; this item adds the upgrade path.

## Re-open trigger

Re-open this item when ANY of the following user-acknowledged conditions are met:

1. v1 ships and reaches an older user trying to open a workspace produced by a newer engine (or vice versa).
2. The first breaking-shape change lands in a minor version (e.g. soul-snapshot v2 introduces a field v1 readers do not understand) and the engineering cost of "fail vs migrate" begins to favor migrate.
3. The user explicitly requests "I want my old workspace to keep working with new engine versions."

Until then, this ledger remains `status: deferred` and SHOULD NOT be transitioned to RED.

## Provenance

`kit:foundational-plan.md M19 row F-D-005`, `kit:rules/no-silent-deferrals.md`.
