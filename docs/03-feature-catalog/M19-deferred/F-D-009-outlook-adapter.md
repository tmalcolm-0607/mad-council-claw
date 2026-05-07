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
feature-id: F-D-009
short-slug: outlook-adapter
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
  Deferred per user decision; not part of v1. v1's F-080 WorkIQ adapter READS Outlook items
  (mail subjects + meta) but the engine does NOT send mail, RSVP to meetings, or write to a
  user's mailbox. F-103 briefing-destination notes email delivery would require an SMTP/Graph
  send adapter beyond F-080's read-only scope.
confidence: high
---

# F-D-009 — Outlook adapter (send / RSVP / mailbox-write) (DEFERRED)

## Status

**Deferred to v1.5+ per `rules/no-silent-deferrals.md`.**

## Summary

Outbound Outlook integration: the engine can send mail (Microsoft Graph `/me/sendMail`), RSVP to meetings, write a draft to the user's Drafts folder, or deliver a briefing artifact as an emailed report. v1 reads Outlook via WorkIQ; this item lets it write back.

## Re-open trigger

Re-open this item when ANY of the following user-acknowledged conditions are met:

1. The user explicitly requests email-destination briefing (F-103 expansion) or "auto-RSVP based on briefing context."
2. A workflow emerges where the engine acts on the user's behalf in mail (auto-replies, calendar negotiation) rather than just summarizing.
3. F-D-018 (Activity Protocol Teams + Outlook unified) is itself re-opened — overlap with that approach should drive a single coherent design.
4. Microsoft Graph permissions story (delegated `Mail.Send` scope, user consent ceremony) is well-understood and ready to ship.

Until then, this ledger remains `status: deferred` and SHOULD NOT be transitioned to RED.

## Provenance

`kit:foundational-plan.md M19 row F-D-009`, `kit:rules/no-silent-deferrals.md`.
