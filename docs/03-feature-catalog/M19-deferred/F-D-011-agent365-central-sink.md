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
feature-id: F-D-011
short-slug: agent365-central-sink
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
depends-on: [F-015, F-110]
out-of-scope-notes: |
  Deferred per user decision; not part of v1. v1's audit-chain (F-015) and local OTel
  (F-110) keep all telemetry + cost + governance signal on-device. Agent365 (Microsoft's
  central agent operations sink) is a multi-tenant aggregation surface that, if wired,
  exports per-agent signal centrally for cross-fleet observability + compliance.
confidence: high
---

# F-D-011 — Agent365 central sink integration (DEFERRED)

## Status

**Deferred to v1.5+ per `rules/no-silent-deferrals.md`.**

## Summary

Export the engine's per-run governance + telemetry signal to Microsoft's Agent365 central operations sink: per-agent cost ledgers, halt counts, verdict outcomes, audit-chain summaries, OTel spans. Lets a fleet operator see all engine instances across their tenant without per-machine collection. v1 is local-only telemetry; this item is the federated export.

## Re-open trigger

Re-open this item when ALL of the following user-acknowledged conditions are met:

1. The user (or a Microsoft-internal compliance / fleet-management policy) explicitly requests centralized agent observability.
2. Agent365's API surface is itself stable enough to depend on (it is an evolving Microsoft program as of 2026 mid-year).
3. F-D-007 (Entra principal-binding) is re-opened — Agent365 export without verifiable per-agent identity has limited value.
4. A privacy / data-residency design exists for what crosses the boundary (PII, query content, cost detail) — Agent365 export of unredacted content would conflict with `rules/no-silent-deferrals.md` PII discipline.

Until then, this ledger remains `status: deferred` and SHOULD NOT be transitioned to RED.

## Provenance

`kit:foundational-plan.md M19 row F-D-011`, `kit:rules/no-silent-deferrals.md`.
