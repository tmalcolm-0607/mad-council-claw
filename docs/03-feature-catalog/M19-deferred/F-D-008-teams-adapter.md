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
feature-id: F-D-008
short-slug: teams-adapter
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
depends-on: [F-076, F-080]
out-of-scope-notes: |
  Deferred per user decision; not part of v1. v1's F-080 WorkIQ adapter READS Teams chat
  context (per existing WorkIQ MCP capability) but the engine does NOT post to Teams as a
  bot, app, or channel destination. F-103 briefing-destination explicitly notes Teams-channel
  delivery is deferred to F-D-008.
confidence: high
---

# F-D-008 — Teams adapter (post / direct-message) (DEFERRED)

## Status

**Deferred to v1.5+ per `rules/no-silent-deferrals.md`.**

## Summary

Outbound Teams integration: the engine can post a message to a Teams channel or direct-message a user, surface a daily briefing (F-101) into a Teams thread, or accept Teams replies as engine input. v1 reads Teams via WorkIQ but does not write to Teams. Distinct from F-D-018 (Activity Protocol Teams + Outlook unified) which addresses the read-write Activity Protocol approach for both surfaces simultaneously.

## Re-open trigger

Re-open this item when ANY of the following user-acknowledged conditions are met:

1. The user explicitly requests Teams-channel briefing delivery (F-103 destination expansion).
2. A multi-user shared-channel collaboration story emerges where the engine acts as a participant rather than a private terminal.
3. Microsoft Bot Framework or Activity Protocol path (F-D-010 / F-D-018) is itself re-opened — Teams adapter overlaps both and re-opening one without the others is fragmented.

Until then, this ledger remains `status: deferred` and SHOULD NOT be transitioned to RED.

## Provenance

`kit:foundational-plan.md M19 row F-D-008`, `kit:rules/no-silent-deferrals.md`.
