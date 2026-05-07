---
artifact-class: feature-ledger
generated-by: hand-authored (wave-003 / lane-a)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-003 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-033
short-slug: history
milestone: M5
provenance:
  surfaces:
    - foundational-plan:CP:m-main/ (multi-session left rail)
    - cp:src/features/chat/
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
  LOCKED if GREEN AND reviews/F-033-history-review.md exists with verdict: ACCEPT.
depends-on: [F-032, F-008, F-001]
out-of-scope-notes: |
  Server-synced multi-device history is out of scope for v1 (local-only).
  History search (full-text indexing) is v1.5.
  History export/import (e.g., to JSON archive) is v1.5.
confidence: high
---

# F-033 — History (multi-session left rail)

## Behavior contract

The desktop shell renders a left-rail list of all runs from `<state-dir>/runs/` + `<state-dir>/archive/runs/<YYYY>/<MM>/`, ordered by `last_activity_utc` descending. Each rail entry shows: run_id (truncated), agent label, lifecycle badge (active/closed/halted), last cycle timestamp, cost-ledger total. Selecting a rail entry loads that run's audit + cost + retro into the main pane (read-only for closed/halted runs; live-updating for active runs via IPC events from F-007). The rail virtualizes — no full DOM render for >100 runs; pagination/scrolling. New runs spawned (CLI per F-029, cron per F-023, or in-shell per F-039) appear in the rail within ≤2s.

## Acceptance scenarios

1. **Given** a state-dir with 3 runs, **When** the desktop opens, **Then** the left rail shows all 3 sorted by last activity + selecting any loads its detail pane.
2. **Given** an active run + the rail open, **When** the run progresses one cycle, **Then** the rail entry's last-activity timestamp updates within 2s without full-rail rerender.
3. **Given** a state-dir with 500 runs, **When** the desktop opens, **Then** the rail virtualizes (only ~30 DOM nodes for visible entries) + scrolling renders the rest on-demand without jank.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/browser/desktop/history-rail-basic.test.ts` | browser | RED | scenario 1 |
| (TBD) `tests/browser/desktop/history-rail-live-update.test.ts` | browser | RED | scenario 2 |
| (TBD) `tests/browser/desktop/history-rail-virtualization.test.ts` | browser | RED | scenario 3 |

## Dependencies

- **Hard:** F-032 (window to render in), F-008 (storage layout — runs + archive paths), F-001 (run lifecycle for active-state badges)
- **Soft:** F-019 (cost-ledger total per rail entry), F-007 (IPC for live updates)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:CP:m-main/ | "multi-session left rail" |
| cp:src/features/chat/ | Chat history component patterns from clawpilot |

## Implementation notes

(empty — populated when implementation begins)
