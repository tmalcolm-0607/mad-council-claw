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
feature-id: F-D-002
short-slug: skill-votes-reviews-downloads
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
depends-on: [F-D-001, F-119, F-120]
out-of-scope-notes: |
  Deferred per user decision; not part of v1. Aggregate signals (votes, reviews, downloads)
  presuppose a cloud-hosted catalog (F-D-001) where the signals are aggregated across users.
  In a local-only world they do not exist as a meaningful concept.
confidence: high
---

# F-D-002 — Skill votes / reviews / download counters (DEFERRED)

## Status

**Deferred to v1.5+ per `rules/no-silent-deferrals.md`.**

## Summary

Aggregate community signals attached to each skill in the cloud marketplace: thumbs-up votes, free-text reviews, install/download counters. Drives F-D-001's search ranking and discovery surfaces. v1's local marketplace (M18 / F-121) deliberately avoids these — without a cloud catalog, the signals are meaningless.

## Re-open trigger

Re-open this item when ALL of the following user-acknowledged conditions are met:

1. F-D-001 cloud marketplace is itself re-opened or shipping.
2. The user explicitly requests social-signal aggregation (or a v1.5 user explicitly asks "why can't I see what other people think of this skill?").
3. A privacy + abuse-resistance design exists (anonymous vs identified votes; review moderation; vote-stuffing prevention) — community signals without trust controls become noise.

Until then, this ledger remains `status: deferred` and SHOULD NOT be transitioned to RED.

## Provenance

`kit:foundational-plan.md M19 row F-D-002`, `kit:rules/no-silent-deferrals.md`.
