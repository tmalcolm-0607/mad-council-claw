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
feature-id: F-D-006
short-slug: identity-crypto-spawn-signing
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
depends-on: [F-002, F-070]
out-of-scope-notes: |
  Deferred per user decision; not part of v1. v1's F-002 per-agent identity stamps every
  artifact with {agent_id, run_id, parent_run_id} but the stamp is integrity-protected only
  by the audit-chain hash chain (F-015), not by per-spawn cryptographic signatures. ce:FR-IDENTITY-002
  (cryptographic spawn signing) is the explicit upgrade path documented in F-002 ledger and
  in wave-006 lane-d's "out of scope" note.
confidence: high
---

# F-D-006 — Cryptographic spawn signing (DEFERRED)

## Status

**Deferred to v1.5+ per `rules/no-silent-deferrals.md`.** ce:FR-IDENTITY-002.

## Summary

Per-spawn cryptographic signature: when an agent A spawns child agent B, A signs B's bootstrap manifest (including parent_run_id pointer) with a key bound to A's identity. Any later party can verify the spawn chain back to its root without trusting the audit-chain alone. v1 relies on append-only hash-chain integrity; this item upgrades to public-key spawn proofs.

## Re-open trigger

Re-open this item when ANY of the following user-acknowledged conditions are met:

1. The user explicitly requests cryptographic spawn proofs (often in security-review contexts).
2. A multi-process / multi-machine engine deployment makes hash-chain integrity insufficient (chains in different processes are not naturally comparable).
3. Adversarial replay forensics requirements (replay an agent's history to a third party who does not trust the audit-chain author) become first-class.
4. ce:FR-IDENTITY-002 is itself surfaced through a contract requirement.

Until then, this ledger remains `status: deferred` and SHOULD NOT be transitioned to RED.

## Provenance

`kit:foundational-plan.md M19 row F-D-006`, `kit:rules/no-silent-deferrals.md`, `ce:FR-IDENTITY-002`.
