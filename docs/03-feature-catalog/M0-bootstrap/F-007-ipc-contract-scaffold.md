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
feature-id: F-007
short-slug: ipc-contract-scaffold
milestone: M0
provenance:
  surfaces:
    - cp:src/main/ipc
    - cp:src/preload
    - kit:rules/orchestrator-identity.md
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
  LOCKED if GREEN AND reviews/F-007-ipc-contract-scaffold-review.md exists with verdict: ACCEPT.
depends-on: [F-003]
out-of-scope-notes: |
  Specific IPC handlers for chat / settings / skills are owned by the M5 desktop-shell
  features (F-032..F-043). This feature scaffolds the contract types + the
  contextBridge pattern that those features plug into.
confidence: high
---

# F-007 — IPC contract scaffold

## Behavior contract

Every IPC channel between the Electron main process and renderer is declared in a single TypeScript contract module: each channel has a typed request shape, a typed response shape, and a unique string name. The renderer accesses IPC ONLY through a `contextBridge`-exposed API; `nodeIntegration` stays disabled and `contextIsolation` enabled. Adding a new channel without updating the contract module fails type-check. The contract is the single source of truth — both main and renderer import the same types.

## Acceptance scenarios

1. **Given** a contract `chat.send` with request `{message: string}` and response `{reply: string}`, **When** the renderer calls `window.api.chat.send({message: "hi"})`, **Then** the call is type-safe and the main-process handler receives the same typed payload.
2. **Given** a renderer that tries to call `ipcRenderer.send('foo', ...)` directly, **When** the bundle builds, **Then** the build fails (because `ipcRenderer` is not exposed in the renderer context).
3. **Given** a developer adds a handler in main without registering it in the contract module, **When** `npm run build` runs, **Then** TypeScript fails with "no overload matches" on the handler registration.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/ipc/contract-types.test.ts` | unit | RED | scenarios 1, 3 |
| (TBD) `tests/integration/ipc/context-bridge.test.ts` | integration | RED | scenario 2 |

## Dependencies

- **Hard:** F-003 (packages must exist to host main + renderer code)
- **Soft:** F-002 (identity is propagated across IPC), F-006 (IPC errors flow to logger)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:src/main/ipc | clawpilot main-process IPC handler pattern |
| cp:src/preload | clawpilot contextBridge API surface |
| kit:rules/orchestrator-identity.md | renderer is orchestrator-shape; main is worker-tools shape |

## Implementation notes

(empty — populated when implementation begins)
