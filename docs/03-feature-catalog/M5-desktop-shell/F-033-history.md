---
artifact-class: feature-ledger
generated-by: hand-authored (wave-003 / lane-a)
status: green
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-003 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: red
    at: 2026-05-07
    by: wave-019 / lane-a
    note: "RED test authored at tests/unit/F-033-chat-history-pane.test.ts (6 structural scenarios per the wave-019 / lane-a brief that simplifies the ledger's 3 launch-Electron browser-suite scenarios to a structural / interface-based shape contract — mirrors F-032's wave-018/lane-c idiom). Test fails with module-resolution error: @mad-council-claw/desktop-shell exports do not yet include `buildHistoryPane` / `resolveHistoryEntry` / `DEFAULT_HISTORY_PANE` / `HISTORY_PANE_DEFAULT_VIRTUALIZATION_THRESHOLD` / `HistoryPaneOptions` / `HistoryPaneDescriptor` / `HistoryEntry` / `HistoryEntryLifecycle`. Implementation will land buildHistoryPane() + resolveHistoryEntry() + DEFAULT_HISTORY_PANE + HISTORY_PANE_DEFAULT_VIRTUALIZATION_THRESHOLD + HistoryEntry/HistoryEntryLifecycle types in packages/desktop-shell/src/history-pane.ts."
  - status: green
    at: 2026-05-07
    by: wave-019 / lane-a
    note: "GREEN. New packages/desktop-shell/src/history-pane.ts (~165 LOC) lands buildHistoryPane() + resolveHistoryEntry() + DEFAULT_HISTORY_PANE + HISTORY_PANE_DEFAULT_VIRTUALIZATION_THRESHOLD (=100) + types (HistoryPaneOptions / HistoryPaneDescriptor / HistoryEntry / HistoryEntryLifecycle / HistoryPaneVirtualization). Pure-data descriptor (JSON-cloneable; no functions, no class instances) sorted by lastActivityUtc DESC; virtualization toggles on entries.length >= threshold; lifecycle badge type-safe ('active' | 'closed' | 'halted'); selectedRunId + liveUpdateChannel pass-through with default 'history.run.progress' channel. package.json exports map gains `./history-pane` subpath; barrel src/index.ts re-exports history-pane.ts. 6/6 PASS at GREEN time; full suite 323/323 PASS across 38 test files; pnpm build exits 0."
feature-id: F-033
short-slug: history
milestone: M5
provenance:
  surfaces:
    - foundational-plan:CP:m-main/ (multi-session left rail)
    - cp:src/features/chat/
fr-coverage: []
test-files:
  unit:
    - tests/unit/F-033-chat-history-pane.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - unit
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

### Wave-019 / Lane A — RED → GREEN flip (2026-05-07)

**Scope simplification vs ledger §Acceptance scenarios.** The wave-019 / lane-a brief instructs a STRUCTURAL / INTERFACE-BASED test that asserts the shape `buildHistoryPane(opts)` returns, rather than booting the desktop renderer in headless Chromium. The three browser-suite scenarios in §Acceptance scenarios bind to the M5 integration suite (a future feature wave that wires the F-008 storage layout to the renderer-process via the F-007 IPC bridge; per F-004 vitest-playwright-config's "browser project runtime wiring deferred to first DOM-rendering spec consumer wave"). v1 ships:

- `HistoryEntry` — the shape per-row in the rail (`runId` / `agentLabel` / `lifecycle` / `lastActivityUtc` / `costTotalUsd`).
- `HistoryEntryLifecycle` — the typed badge enum (`'active' | 'closed' | 'halted'`).
- `HistoryPaneVirtualization` — `{ enabled: boolean; threshold: number }`; threshold drives the boolean.
- `HistoryPaneDescriptor` — the plain-data descriptor (entries DESC by `lastActivityUtc` + virtualization + selectedRunId + liveUpdateChannel).
- `DEFAULT_HISTORY_PANE` — the canonical default for fresh installs (empty entries; threshold=100; null selection; default IPC channel).
- `HISTORY_PANE_DEFAULT_VIRTUALIZATION_THRESHOLD` — the integer (=100) that toggles virtualization ON.
- `buildHistoryPane(opts)` — pure function returning the descriptor.
- `resolveHistoryEntry(partial | null | undefined)` — never-throws hydrator that fills safe defaults; unknown lifecycle → `'closed'` fallback (the safest read-only default per F-014/F-015 retro emission discipline).

**Substantive guarantees preserved by the structural test (per `verification-protocol.md` Rule 1):**

- Sort order: descriptor.entries DESC by `lastActivityUtc` (ledger scenario 1).
- Virtualization predicate: `enabled === true` ONLY when `entries.length >= threshold` (ledger scenario 3 — rail virtualizes for >100 runs).
- Lifecycle-badge type-safety: `HistoryEntryLifecycle` union; unknown strings fall back to `'closed'`.
- `selectedRunId` + `liveUpdateChannel` pass-through (ledger scenario 2 — live updates via IPC).
- IPC channel registration intent: default channel name `'history.run.progress'`; future M5 features extend `IpcInvokeMap` and the channel name resolves against `keyof IpcInvokeMap` at the consumer call site.

**Deferred to M5 integration wave per `no-silent-deferrals.md`:**

- Actual DOM render of the rail (react-virtuoso / tanstack/react-virtual / hand-rolled) — belongs in the M5 integration consumer.
- On-disk read of `<state-dir>/runs/` + `<state-dir>/archive/runs/<YYYY>/<MM>/` — caller resolves entries via F-008 atomic-read helpers and passes the array to `buildHistoryPane({ entries })`.
- F-007 IPC handler runtime wiring for live updates — the channel name + threshold declaration is the v1 contract; the SLA (≤2s update per ledger scenario 2) is observed at the consumer wave's e2e harness.
- Full-text search / filter — v1.5 per ledger out-of-scope-notes.
- History export/import — v1.5 per ledger out-of-scope-notes.
- Server-synced multi-device history — out of v1 per ledger out-of-scope-notes.

**Cross-feature composition:**

- F-032 (window, GREEN) — sibling M5 surface; the `MainWindowDescriptor.ipcChannels` array will eventually include the rail's `liveUpdateChannel` once the consumer wires it in.
- F-007 (ipc-contract-scaffold, LOCKED) — `liveUpdateChannel` types as a string (the well-known `'history.run.progress'` is documented; future M5 features may extend `IpcInvokeMap` with a typed entry).
- F-008 (local-storage-layout, LOCKED) — caller reads the runs + archive directories via F-008's atomic-read helpers and passes the parsed values as `HistoryEntry[]`.
- F-001 (engine-bootstrap-loop, LOCKED), F-019 (cost-ledger, LOCKED) — supply the data the rail rows display (lifecycle, cost-total).
- F-034 (info-panel, paired in same wave) — composes against the rail's `selectedRunId` (info panel reads selection; rail writes it).

**Inherits the F-032 idiom "descriptor-as-data, instantiation-deferred"** registered wave-018 / lane-c. F-033's deliverable IS the plain-object descriptor + helper functions; the consumer step ("hand the descriptor to a virtualization library") is deferred. The idiom enables structural testing without a DOM runtime.

**Test files at GREEN:**

- `tests/unit/F-033-chat-history-pane.test.ts` — 6 scenarios, all PASS at GREEN time.

**Source files at GREEN:**

- `packages/desktop-shell/src/history-pane.ts` — ~95 LOC (buildHistoryPane + resolveHistoryEntry + types + constants).
- `packages/desktop-shell/package.json` — exports map gains `./history-pane` subpath.
- `packages/desktop-shell/src/index.ts` — barrel re-exports history-pane.ts.

**Second feature in `packages/desktop-shell/`** after F-032. Wave-011 / lane-a's "shared types live with their FIRST owner" convention applies: `HistoryEntry` + `HistoryEntryLifecycle` + `HistoryPaneDescriptor` + `HistoryPaneVirtualization` + `HistoryPaneOptions` + `DEFAULT_HISTORY_PANE` + `HISTORY_PANE_DEFAULT_VIRTUALIZATION_THRESHOLD` + `buildHistoryPane` + `resolveHistoryEntry` live with F-033. Future M5 features will compose against this surface without changing it.
