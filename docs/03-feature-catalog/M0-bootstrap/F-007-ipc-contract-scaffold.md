---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: green
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-011 / lane-a
    note: "Scaffold flip: common/ipc-contract.ts created with empty IpcInvokeMap + IpcInvokeChannel/Request/Response helper types; tests/unit/F-007-ipc-contract-scaffold.test.ts authored RED→GREEN (3/3 PASS); full suite 75/75 PASS. Build-time + runtime helpers for M5+ to fill in. Same wave that refactored packages/engine-core/src/index.ts into per-feature files."
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
  unit:
    - tests/unit/F-007-ipc-contract-scaffold.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - unit
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
| `tests/unit/F-007-ipc-contract-scaffold.test.ts` | unit | RED → **GREEN (wave-011/lane-a)** | scaffold-shape contract: IpcInvokeMap export + IpcInvokeChannel = keyof IpcInvokeMap + IpcInvokeRequest/Response helper types + module is importable at runtime |
| (deferred to M5) `tests/integration/ipc/context-bridge.test.ts` | integration | RED | scenario 2 — runtime contextBridge isolation verification (requires Electron harness; lands with M5 desktop-shell features F-032..F-043) |
| (deferred to M5) `tests/integration/ipc/handler-type-failure.test.ts` | integration | RED | scenario 3 — build-time TS failure when handler not registered in contract (requires actual handler call site) |

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

### Wave-011 / lane-a flip (2026-05-07)

`common/ipc-contract.ts` (new file at repo root) exports:

- `IpcInvokeMap` — empty type, populated by future channel additions
- `IpcInvokeChannel` — `keyof IpcInvokeMap` (= `never` until first channel)
- `IpcInvokeRequest<C>` / `IpcInvokeResponse<C>` — helper types for pulling
  request/response shapes by channel name

The scaffold lands the SHAPE contract that M5+ desktop-shell features and
later milestones extend. The integration scenarios (context-bridge isolation,
build-time type-check failure on missing handler) are deferred to M5 per the
test wire-up table — they require an actual handler call site + Electron
harness to verify.

`tsconfig.json` `include` extended to add `common/**/*.ts` so the scaffold
participates in the type-check sweep alongside `packages/*/src/` and `tests/`.

Scope co-shipped with the wave-011/lane-a refactor of
`packages/engine-core/src/index.ts` into per-feature files
(`bootstrap.ts`, `identity.ts`, `logger.ts`, `storage.ts`, `retro.ts`,
`audit.ts`, `halt.ts`, `cost.ts`, `killswitch.ts`, `quota.ts`) — that
refactor eliminated the cross-lane staging race that recurred 5+ times across
waves 5-10. F-007 was authored in the same wave because it doesn't touch
engine-core (separate file tree), so the lane was a natural pairing.
