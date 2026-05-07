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
feature-id: F-D-012
short-slug: byok-per-tenant-routing
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
depends-on: [F-009, F-070, F-074, F-076]
out-of-scope-notes: |
  Deferred per user decision; not part of v1. v1's F-009 IBackendProvider holds one
  Anthropic + one Copilot credential at a time per workspace; F-074 workspace + F-070
  encrypted-storage already isolate credentials per-workspace, but multi-tenant routing
  (route THIS workspace's calls through the customer-supplied keys, not the developer's
  defaults) is not part of v1.
confidence: high
---

# F-D-012 — BYOK + per-tenant model routing (DEFERRED)

## Status

**Deferred to v1.5+ per `rules/no-silent-deferrals.md`.**

## Summary

Bring-your-own-key + per-tenant routing: a workspace can supply its own Anthropic / Azure OpenAI / Copilot credentials so all backend calls in that workspace are billed + authenticated against the customer's tenant, not the engine developer's. Routing rules can also pin specific tenants to specific backends or model variants. v1 ships per-workspace credentials per F-074; this item formalizes the multi-tenant routing layer on top.

## Re-open trigger

Re-open this item when ANY of the following user-acknowledged conditions are met:

1. A real customer / consumer of the engine asks "can I use my own Anthropic key here so the bill goes to me?"
2. A regulated-environment requirement emerges (Microsoft-internal data residency, customer-tenant data isolation) where the engine developer's key cannot legally process the customer's prompts.
3. F-D-007 (Entra principal-binding) is re-opened — per-tenant routing keyed by Entra tenant only makes sense when the binding is itself first-class.
4. A revenue model emerges where customer-supplied billing is a core monetization story.

Until then, this ledger remains `status: deferred` and SHOULD NOT be transitioned to RED.

## Provenance

`kit:foundational-plan.md M19 row F-D-012`, `kit:rules/no-silent-deferrals.md`.
