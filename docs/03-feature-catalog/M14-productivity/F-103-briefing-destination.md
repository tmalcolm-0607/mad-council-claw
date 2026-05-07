---
artifact-class: feature-ledger
generated-by: hand-authored (wave-006 / lane-a)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-006 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-103
short-slug: briefing-destination
milestone: M14
provenance:
  surfaces:
    - kit:foundational-plan.md M14 NEW Message 11
    - kit:rules/degradation-fallback-policy.md
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
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-103-briefing-destination-review.md exists with verdict: ACCEPT.
depends-on: [F-101]
out-of-scope-notes: |
  Email-as-destination is post-v1 (would require an SMTP/Graph adapter beyond F-080
  scope). Teams-channel-as-destination is in F-D-017 deferred catalog (Teams adapter is
  v1.5). Slack/Discord/external-chat destinations are post-v1. Encrypted destination
  payloads (PGP/age) are post-v1 — v1 destinations are filesystem + clipboard only.
  Multi-destination fan-out (deliver to 2+ destinations from one schedule fire) is
  post-v1 — v1 is single destination per schedule.
confidence: high
---

# F-103 — Briefing destination

## Behavior contract

Every F-101 briefing (whether manually generated or scheduled per F-102) is delivered to a configured **destination**. v1 supports two destination types: (a) **filesystem** — write the briefing Markdown to a user-specified path with auto-generated filename `briefing-<YYYY-MM-DD>.md`, refusing to overwrite an existing file (returns `BRIEFING_DESTINATION_CONFLICT`); and (b) **clipboard** — copy the briefing Markdown to the OS clipboard via the Electron IPC layer. Destination dispatch failures are NEVER silent: a failed write or clipboard copy emits an audit-chain `BRIEFING_DELIVERY_FAILED` entry naming the destination + error class, and the briefing artifact is preserved at `runs/<run_id>/briefing.md` so the user can recover it manually per `rules/degradation-fallback-policy.md` Rule 2 (always offer a manual fallback).

## Acceptance scenarios

1. **Given** a briefing destination configured as `filesystem: ~/briefings/` and no existing `briefing-2026-05-06.md` in that directory, **When** the briefing dispatches on 2026-05-06, **Then** the file is written successfully AND an audit-chain `BRIEFING_DELIVERED` entry is appended naming the absolute path AND the file's content is byte-equivalent to the in-memory briefing.
2. **Given** the destination is `filesystem: ~/briefings/` AND `briefing-2026-05-06.md` already exists at that path, **When** the briefing dispatches on 2026-05-06, **Then** the operation rejects with `BRIEFING_DESTINATION_CONFLICT` AND the existing file is unchanged AND the briefing IS preserved at `runs/<run_id>/briefing.md` AND an audit-chain `BRIEFING_DELIVERY_FAILED` entry names the conflict.
3. **Given** the destination is `clipboard` AND the OS clipboard API returns an error (e.g. headless test environment), **When** the briefing dispatches, **Then** an audit-chain `BRIEFING_DELIVERY_FAILED` entry is appended naming the clipboard error AND the briefing IS preserved at `runs/<run_id>/briefing.md` AND no silent failure occurs per `rules/no-silent-deferrals.md`.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/briefing-destination/filesystem-write-success.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/briefing-destination/filesystem-conflict-preserves-artifact.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/briefing-destination/clipboard-failure-preserves-artifact.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-101 (daily-briefing produces the artifact this dispatches)
- **Soft:** F-102 (scheduled-fire path invokes destination), F-008 (storage layout for `runs/<run_id>/briefing.md` fallback artifact), F-015 (audit chain records delivery + failures)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md M14 NEW Message 11 | "destination" verbatim from user's NEW-features answer (M14 row) |
| kit:rules/degradation-fallback-policy.md | Failed delivery preserves the artifact + offers manual recovery — Rule 2 verbatim |
| kit:rules/no-silent-deferrals.md | Delivery failures emit explicit audit entries; never silently dropped |

## Implementation notes

(empty — populated when implementation begins; Electron clipboard IPC wiring deferred to F-046 IPC contract integration)
