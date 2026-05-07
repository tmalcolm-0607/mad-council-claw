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
feature-id: F-D-004
short-slug: archive-encryption
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
depends-on: [F-026, F-070, F-071]
out-of-scope-notes: |
  Deferred per user decision; not part of v1. v1's idle archive (F-026) writes plaintext
  channel state to the archive directory, relying on OS-level filesystem permissions for
  confidentiality. v1 does encrypt secrets at rest (F-070 encrypted-storage), but archived
  channel transcripts are not yet wrapped in the same envelope.
confidence: high
---

# F-D-004 — Archive encryption (DEFERRED)

## Status

**Deferred to v1.5+ per `rules/no-silent-deferrals.md`.**

## Summary

Encrypt archived channel transcripts at rest using the same key-management substrate as F-070 / F-071. v1's F-026 idle archive writes plaintext under OS file permissions; this item layers a confidentiality envelope on top so an OS-level read of the archive directory does not expose channel content.

## Re-open trigger

Re-open this item when ANY of the following user-acknowledged conditions are met:

1. The user (or a regulated-environment policy) requires archive confidentiality beyond OS file permissions.
2. A multi-user / shared-machine deployment story emerges where the archive directory is readable by unintended OS principals.
3. A compliance trigger (Microsoft-internal data classification, customer-data residency rules) demands encryption at rest for all stored conversation content, not just secrets.

Until then, this ledger remains `status: deferred` and SHOULD NOT be transitioned to RED.

## Provenance

`kit:foundational-plan.md M19 row F-D-004`, `kit:rules/no-silent-deferrals.md`.
