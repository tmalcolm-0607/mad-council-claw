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
feature-id: F-D-003
short-slug: ring-distribution
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
depends-on: [F-D-001, F-105]
out-of-scope-notes: |
  Deferred per user decision; not part of v1. v1 ships F-105 STABLE-default + BETA opt-in for
  the engine itself (D-7); ring-based distribution for skills (alpha / beta / stable channels
  per skill, gradual rollout, fast-ring rollback) is a v1.5+ ask that overlaps cloud marketplace
  infrastructure.
confidence: high
---

# F-D-003 — Ring-based distribution (DEFERRED)

## Status

**Deferred to v1.5+ per `rules/no-silent-deferrals.md`.**

## Summary

Per-skill release rings (alpha / beta / stable / canary), gradual rollout to a percentage of users, fast-ring rollback if telemetry detects regression. Mirrors LENS-style ring promotion at the skill plane. v1 ships the engine's auto-update channels (F-105 STABLE / BETA) but does NOT ring-promote individual skills.

## Re-open trigger

Re-open this item when ALL of the following user-acknowledged conditions are met:

1. F-D-001 cloud marketplace is itself re-opened or shipping (no centralized publishing → no ring concept).
2. M16 telemetry is shipping enough signal to detect skill-level regressions (per-skill error rates, halt counts, user-reported issues).
3. The user explicitly requests safer-than-binary skill rollout — i.e. "I want to test this on 10% of installs first."

Until then, this ledger remains `status: deferred` and SHOULD NOT be transitioned to RED.

## Provenance

`kit:foundational-plan.md M19 row F-D-003`, `kit:rules/no-silent-deferrals.md`.
