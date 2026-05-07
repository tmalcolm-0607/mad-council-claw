---
artifact-class: feature-ledger
generated-by: hand-authored (wave-004 / lane-b)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-004 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-065
short-slug: automations-persistence
milestone: M7
provenance:
  surfaces:
    - foundational-plan:M7-skills-perms-auto
    - cp:electron/automations/store.ts
    - cp:src/features/automations/AutomationHistoryView.tsx
    - kit:rules/concurrency-safety.md
    - kit:rules/resume-protocol.md
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
  LOCKED if GREEN AND reviews/F-065-automations-persistence-review.md exists with verdict: ACCEPT.
depends-on: [F-061, F-064, F-008]
out-of-scope-notes: |
  Settings shape (where automation data lives) is F-067 (M8); this feature is the AUTOMATIONS-specific persistence layer.
  Encrypted storage is F-070 (M8); persistence here is plaintext on local disk in v1, with encrypted-at-rest as M8 enhancement.
  Resume-from-checkpoint after crash is part of this feature (the checkpoint format itself is F-064).
  Settings export/import is F-072.
configurable: |
  Persistence is local filesystem only in v1; remote backup is OUT OF SCOPE.
  Run history retains the most recent 100 runs per automation; older runs archived to history-archive.jsonl.
confidence: high
---

# F-065 — Automations persistence

## Behavior contract

The automation store (`store.ts`-style) is the source of truth for automation definitions, run history, and resumable checkpoints. On engine start, the store loads `<state-dir>/automations/store.json` (atomic read-modify-write per `concurrency-safety.md` §2), validates against the Zod schema, and surfaces validation errors per-entry — invalid entries are quarantined to `<state-dir>/automations/store.invalid.json` rather than crashing the engine. For each automation that was mid-run when the engine stopped (checkpoint exists at `<state-dir>/automations/runs/<run_id>/checkpoint.json`), the store offers the manager a resume opportunity: cron-typed automations resume from `last_completed_step_id` if their `resume_after_crash` capability is set, else they discard the partial run and wait for the next trigger. Run history retains 100 most-recent entries per automation; older entries roll into `history-archive.jsonl`.

## Acceptance scenarios

1. **Given** `<state-dir>/automations/store.json` with 5 valid automations + 1 invalid entry (schema-rejected), **When** the engine starts, **Then** the 5 valid entries are loaded into the manager AND the invalid one is moved to `store.invalid.json` with the validation error attached.
2. **Given** an automation `auto-1` was running step 2 of 5 when the engine crashed (checkpoint records `last_completed_step_id: "step-2"`), **When** the engine restarts and `auto-1.capabilities.resume_after_crash === true`, **Then** the manager resumes from step 3 AND a `RUN_RESUMED` event records `{ run_id, resumed_at_step: "step-3" }`.
3. **Given** an automation has 150 entries in `history.jsonl`, **When** the store rotates, **Then** the file contains the most-recent 100 AND `history-archive.jsonl` gains the older 50.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/automations/persistence-load-quarantine-invalid.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/automations/persistence-resume-from-checkpoint.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/automations/persistence-history-rotation.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-061 (automations base — manager reads from this store), F-064 (checkpoint shape this feature consumes), F-008 (storage layout for `<state-dir>/automations/`)
- **Soft:** F-067 (settings shape parents this), F-070 (encrypted-at-rest is the M8 enhancement)
- **Independent:** F-062, F-063 (trigger types orthogonal to persistence)

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M7-skills-perms-auto | "persist" is item 15 of the M7 catalog list |
| cp:electron/automations/store.ts | Reference store pattern (test-covered) |
| cp:src/features/automations/AutomationHistoryView.tsx | UI consumer of run history |
| kit:rules/concurrency-safety.md | Atomic store + append-only history |
| kit:rules/resume-protocol.md | Resume-from-checkpoint discipline |

## Implementation notes

(empty — populated when implementation begins)
