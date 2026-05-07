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
feature-id: F-D-007
short-slug: identity-entra-binding
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
depends-on: [F-002, F-076, F-077]
out-of-scope-notes: |
  Deferred per user decision; not part of v1. v1's F-002 agent_id is engine-local (UUID v7);
  F-076 / F-077 (MSAL / WAM) authenticate the human user but do not bind agent identity to
  the user's Entra principal. ce:FR-IDENTITY-003 is the explicit upgrade: agents created in
  this user's workspace carry a verifiable claim of which Entra tenant + principal owns them.
confidence: high
---

# F-D-007 — Entra principal-binding for agent identity (DEFERRED)

## Status

**Deferred to v1.5+ per `rules/no-silent-deferrals.md`.** ce:FR-IDENTITY-003.

## Summary

Bind each agent's `agent_id` to the authenticated Entra principal of the workspace owner via a verifiable claim (signed JWT-like assertion or STS-issued token). Cross-workspace / cross-machine consumers of an agent artifact can verify "this agent was created in tenant T by user U" without trusting only the audit-chain. v1 keeps agent identity engine-local; this item federates it.

## Re-open trigger

Re-open this item when ANY of the following user-acknowledged conditions are met:

1. The user explicitly requests "I want this artifact to prove it came from my work, not just my engine."
2. Cross-tenant or cross-org artifact exchange becomes a real workflow (not just a hypothetical).
3. F-D-006 (cryptographic spawn signing) lands first — Entra binding without spawn proofs is half a story.
4. Microsoft-internal compliance requires Entra-bound provenance on all generated artifacts in a regulated workflow.

Until then, this ledger remains `status: deferred` and SHOULD NOT be transitioned to RED.

## Provenance

`kit:foundational-plan.md M19 row F-D-007`, `kit:rules/no-silent-deferrals.md`, `ce:FR-IDENTITY-003`.
