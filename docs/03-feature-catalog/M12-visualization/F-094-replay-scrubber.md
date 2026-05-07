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
feature-id: F-094
short-slug: replay-scrubber
milestone: M12
provenance:
  surfaces:
    - kit:foundational-plan.md M12 NEW Message 11
    - kit:rules/verification-protocol.md
    - ce:FR-REPLAY-001
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
  LOCKED if GREEN AND reviews/F-094-replay-scrubber-review.md exists with verdict: ACCEPT.
depends-on: [F-092, F-093]
out-of-scope-notes: |
  Live-replay (re-executing the run server-side from the scrubber position) is post-v1;
  v1 scrubber is read-only state inspection only — it does NOT call the engine to
  re-run anything. Editing past entries is FORBIDDEN by F-015 audit-chain immutability;
  the scrubber is a viewer, not an editor. Cross-run scrub (jump from run A index 12
  to run B index 5) is post-v1 (single-run scrubber only). Branching replay (fork at
  scrub position) is post-v1.
confidence: high
---

# F-094 — Replay scrubber

## Behavior contract

The scrubber is an interactive control overlay on the F-093 timeline that lets the user **scrub through a completed run's state** by audit-entry index. Dragging the scrubber to index N reconstructs the engine state AS-OF entry N: which agents were active, the cost-ledger total at that point, the introspection snapshot most recently emitted before N, and any open verdicts. State reconstruction reads from the F-092 replay manifest's frozen-input snapshot plus the audit chain up to index N. Scrubbing is purely read-only — no state is mutated and no engine code re-runs.

## Acceptance scenarios

1. **Given** a run with 100 audit entries and the user has scrubbed to index 50, **When** the side panel renders, **Then** it shows: the cost-ledger total computed from F-019 entries 1-50 (excluding 51-100), the most recent introspection snapshot at-or-before index 50, and the set of agents marked active per audit entries 1-50.
2. **Given** the user scrubs from index 50 to index 75, **When** the rendering updates, **Then** the engine binary is NOT invoked (no replay execution), the data is read from the audit chain + replay manifest only, AND the side-panel state matches what F-090 introspection snapshots emitted between indexes 50-75.
3. **Given** the user attempts to edit an audit entry while scrubbed to index 30, **When** the edit operation is invoked, **Then** the operation rejects with `AUDIT_IMMUTABLE` AND no entry payload changes (F-015 chain-hash invariant preserved).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/browser/scrubber/scrubber-reconstructs-state-at-index.test.ts` | browser | RED | scenario 1 |
| (TBD) `tests/browser/scrubber/scrubber-no-engine-reexecution.test.ts` | browser | RED | scenario 2 |
| (TBD) `tests/browser/scrubber/scrubber-rejects-edit.test.ts` | browser | RED | scenario 3 |

## Dependencies

- **Hard:** F-092 (replay manifest is the determinism anchor for scrubber state), F-093 (scrubber overlays the timeline UI)
- **Soft:** F-090 (introspection snapshots are the state checkpoints scrubbing snaps to), F-019 (cost-ledger summed up-to-index for scrub state), F-015 (audit chain is the source of state events)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md M12 NEW Message 11 | "replay scrubber" verbatim from user's NEW-features answer |
| kit:rules/verification-protocol.md | "ACTUAL BEFORE PRESENT" — scrubber shows actual past state, never speculative state |
| ce:FR-REPLAY-001 | Replay determinism is the foundation that makes scrubber state reconstruction valid |

## Implementation notes

(empty — populated when implementation begins; D-7 closure per M11 README; scrub granularity vs cost trade-off deferred to M12 design wave)
