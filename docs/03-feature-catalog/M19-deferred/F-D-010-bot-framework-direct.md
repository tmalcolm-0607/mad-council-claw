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
feature-id: F-D-010
short-slug: bot-framework-direct
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
depends-on: [F-076, F-D-008, F-D-018]
out-of-scope-notes: |
  Deferred per user decision; not part of v1. v1 ships as an Electron desktop shell + CLI;
  the engine is invoked locally, not by remote channels-of-conversation registered through
  Microsoft Bot Framework / Azure Bot Service. F-D-008 (Teams adapter) and F-D-018 (Activity
  Protocol Teams+Outlook) are alternative paths to similar outbound surfaces.
confidence: high
---

# F-D-010 — Bot Framework direct integration (DEFERRED)

## Status

**Deferred to v1.5+ per `rules/no-silent-deferrals.md`.**

## Summary

Run the engine as a Microsoft Bot Framework / Azure Bot Service bot: register a bot, expose a messaging endpoint, accept turn contexts from any Bot-Framework-supported channel (Teams, Slack-via-bot, web-chat, custom Direct Line), drive engine runs from those turns. v1 is desktop + CLI only; this item makes the engine a remote conversational endpoint.

## Re-open trigger

Re-open this item when ALL of the following user-acknowledged conditions are met:

1. The user explicitly requests "I want to use this engine from Teams as a bot, not just from the desktop app."
2. F-D-008 (Teams adapter) and / or F-D-018 (Activity Protocol path) are themselves re-opened — these are alternate strategies to the same Teams-integration goal and should be designed together.
3. A hosting story exists (where does the bot endpoint live; who pays for the always-on compute; how do user-Entra-binding and tenant isolation work).
4. Adversarial-input controls (Bot Framework attack surface is wide) have a design that meets `rules/prompt-injection-policy.md` + `rules/stride-threat-model.md` thresholds.

Until then, this ledger remains `status: deferred` and SHOULD NOT be transitioned to RED.

## Provenance

`kit:foundational-plan.md M19 row F-D-010`, `kit:rules/no-silent-deferrals.md`.
