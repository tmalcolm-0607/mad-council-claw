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
feature-id: F-D-015
short-slug: mobile-companion
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
depends-on: [F-D-001, F-D-008, F-D-018]
out-of-scope-notes: |
  Deferred per user decision; not part of v1. v1 ships desktop (Electron — macOS/Windows/Linux)
  and CLI; iOS / Android native or web-mobile companion apps that surface engine state, accept
  inputs, or notify on remote events are post-v1.
confidence: high
---

# F-D-015 — Mobile companion app (DEFERRED)

## Status

**Deferred to v1.5+ per `rules/no-silent-deferrals.md`.**

## Summary

A mobile-form-factor companion (iOS / Android native, or PWA mobile-optimized) that surfaces selected engine state remotely: read briefings (F-101), receive halt / verdict notifications, kick off pre-defined automations (F-061+), read replays (F-091). Requires a remote endpoint the mobile client connects to — likely overlaps F-D-010 (Bot Framework) or F-D-018 (Activity Protocol) for the transport, and F-D-001 cloud marketplace's account substrate for identity binding.

## Re-open trigger

Re-open this item when ALL of the following user-acknowledged conditions are met:

1. The user explicitly requests "I want to see / drive the engine from my phone."
2. F-D-001 (cloud marketplace + account substrate) and / or F-D-008 / F-D-010 / F-D-018 (Teams / Bot / Activity Protocol transport) are themselves re-opened — a mobile companion on top of pure-local v1 has no transport.
3. A native mobile distribution story exists (App Store + Play Store presence, code-signing, identity binding) — not just "we'll figure it out."
4. F-D-007 (Entra principal-binding) is re-opened — mobile clients without verifiable owner-binding open trust questions v1 deliberately avoids.

Until then, this ledger remains `status: deferred` and SHOULD NOT be transitioned to RED.

## Provenance

`kit:foundational-plan.md M19 row F-D-015`, `kit:rules/no-silent-deferrals.md`.
