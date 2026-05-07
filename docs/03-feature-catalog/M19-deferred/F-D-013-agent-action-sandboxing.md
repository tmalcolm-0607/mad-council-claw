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
feature-id: F-D-013
short-slug: agent-action-sandboxing
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
depends-on: [F-051, F-058, F-059, F-066]
out-of-scope-notes: |
  Deferred per user decision; not part of v1. v1's 3-tier permission model (F-058) gates
  WHICH tools a skill can invoke + F-066 audits actually invoked tool calls — but tool
  execution itself runs in the engine's process with the engine's full filesystem +
  network access. Sandboxing (process isolation, OS-level capability restriction,
  network-egress allowlist per-skill) is post-v1.
confidence: high
---

# F-D-013 — Per-skill action sandboxing (DEFERRED)

## Status

**Deferred to v1.5+ per `rules/no-silent-deferrals.md`.**

## Summary

Run skill-invoked tool calls inside an OS-level sandbox: process isolation per skill, filesystem access restricted to declared scopes, network egress restricted to per-skill allowlist, CPU + memory + wall-clock budgets enforced. v1's permission model (F-058 3-tier perms + F-066 audit) is policy + observability; this item adds the runtime enforcement boundary.

## Re-open trigger

Re-open this item when ANY of the following user-acknowledged conditions are met:

1. The user (or a security-review process) explicitly requests defense-in-depth beyond the policy + audit layer.
2. Skill-marketplace adoption (F-119+ → F-D-001) brings third-party authored skills into the engine — at that point trusting policy alone is structurally weak.
3. A real incident (or near-miss) where a skill exceeds its declared capability surface motivates a stronger boundary.
4. A platform abstraction emerges that makes per-skill sandboxing implementable without re-architecting the engine's process model (e.g. WebAssembly host, OS containers per skill, Node.js worker threads with strict capability scoping).

Until then, this ledger remains `status: deferred` and SHOULD NOT be transitioned to RED.

## Provenance

`kit:foundational-plan.md M19 row F-D-013`, `kit:rules/no-silent-deferrals.md`.
