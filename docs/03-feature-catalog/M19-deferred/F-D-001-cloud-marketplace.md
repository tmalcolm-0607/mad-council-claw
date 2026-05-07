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
feature-id: F-D-001
short-slug: cloud-marketplace
milestone: M19
provenance:
  surfaces:
    - kit:foundational-plan.md M19 row + Message 11 marketplace ask
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
  N/A while status: deferred. If re-opened, the standard contract applies:
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-D-001-cloud-marketplace-review.md exists with verdict: ACCEPT.
depends-on: [F-119, F-120, F-121]
out-of-scope-notes: |
  Deferred per user decision; not part of v1. v1 marketplace is local-only (M18 / F-119..F-121).
  Re-open requires the user to explicitly request and a council-review verdict transitioning
  this item to RED with a target milestone + ledger expansion.
confidence: high
---

# F-D-001 — Cloud-hosted skill marketplace (DEFERRED)

## Status

**Deferred to v1.5+ per `rules/no-silent-deferrals.md`.** Captured at v1 catalog finalization (wave-007 / lane-b) so the deferral is explicit, not a silent drop. v1's marketplace plane is local-only (M18 / F-119..F-121); this item names the cloud-hosted successor.

## Summary

A cloud-hosted skill registry with searchable index, accounts (read-only consumer accounts at minimum; publisher accounts for skill authors), discoverable catalog API, and install-from-cloud flow that pulls a SKILL.md bundle by name + version into the user's local F-119 marketplace. Successor to M18's local-only v1.

## Re-open trigger

Re-open this item when ALL of the following user-acknowledged conditions are met:

1. The user explicitly requests cloud marketplace functionality (verbal or written ask).
2. v1 ships with M18 local marketplace GREEN and at least one external skill author has expressed desire to publish a discoverable bundle.
3. Identity / publisher-trust story (overlaps F-D-006 / F-D-007) has at least a v1.5 design — cloud marketplace without trust-anchored publishing is not a meaningful improvement over the local model.
4. A hosting / cost / privacy decision has been made (Microsoft-internal vs public cloud vs both).

Until then, this ledger remains `status: deferred` and SHOULD NOT be transitioned to RED.

## Provenance

`kit:foundational-plan.md M19 row F-D-001 cloud-marketplace`, `kit:rules/no-silent-deferrals.md` (this deferral is explicit; the rule is what makes the asymmetry — "silent additions easy to revert; silent deferrals erase user intent" — operationally visible).
