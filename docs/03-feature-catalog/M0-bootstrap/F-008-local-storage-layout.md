---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-008
short-slug: local-storage-layout
milestone: M0
provenance:
  surfaces:
    - cp:userData layout
    - ce:FR-AUDIT-001
    - kit:rules/concurrency-safety.md
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
  LOCKED if GREEN AND reviews/F-008-local-storage-layout-review.md exists with verdict: ACCEPT.
depends-on: []
out-of-scope-notes: |
  Encrypted-at-rest storage of secrets/keys is owned by M8 (F-070 encrypted-storage,
  F-071 key-mgmt). This feature defines the on-disk directory layout + atomic-write
  helpers; it does not perform encryption.
confidence: high
---

# F-008 — Local storage layout

## Behavior contract

The engine writes all persistent state under a single `userData/mad-council-claw/` root. Subdirectories: `runs/<run_id>/` (per-run audit log + cost ledger + manifest), `skills/` (allowlist + pinned bundles), `verdicts/` (manual + automated verdicts), `kill-switch.json` (read-time-propagating halt), `automations/` (cron + condition + multistep state). Every mutable JSON file is written atomically via the write-temp-then-rename pattern from `concurrency-safety.md` §2; readers never observe a half-written file. The layout is documented in `RUNBOOK.md`.

## Acceptance scenarios

1. **Given** a fresh engine boot with `run_id=R1`, **When** the engine writes the first audit entry, **Then** the path `userData/mad-council-claw/runs/R1/audit.ndjson` exists and contains exactly one line.
2. **Given** a write of `verdicts/manual-2026-05-07.json`, **When** the writer is interrupted between temp-write and rename, **Then** no readable file exists at the target path (only the `.tmp` orphan, swept on next boot per `concurrency-safety.md` §Edge cases).
3. **Given** two concurrent writes to `kill-switch.json`, **When** both complete, **Then** the final file content equals one of the two inputs (last-write-wins) and the file always parses as valid JSON.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/storage/layout.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/integration/storage/atomic-write.test.ts` | integration | RED | scenarios 2, 3 |

## Dependencies

- **Hard:** none (foundational)
- **Soft:** F-001 (engine consumes this layout), F-006 (logger writes here)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:userData layout | clawpilot Electron `app.getPath('userData')` pattern |
| ce:FR-AUDIT-001 | hash-chained audit log lives at `runs/<run_id>/audit.ndjson` |
| kit:rules/concurrency-safety.md | atomic write-temp-then-rename pattern |

## Implementation notes

(empty — populated when implementation begins)
