---
artifact-class: feature-ledger
generated-by: hand-authored (wave-004 / lane-a)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-004 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-045
short-slug: mcp-server-lifecycle
milestone: M6
provenance:
  surfaces:
    - ce:US-6
    - cp:electron/mcp-store.ts
    - cp:electron/mcp-disabled.ts
    - cp:sidecar/node-runner.cs
    - cp:sidecar/node-runner.exe
    - cp:bundled-mcp/filesystem-server.mjs
    - kit:rules/concurrency-safety.md
    - kit:rules/dangerous-operations-policy.md
    - "wave-1 lane-c lessons-learned.md (sidecar / Windows console flash)"
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
  LOCKED if GREEN AND reviews/F-045-mcp-server-lifecycle-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-008, F-044]
out-of-scope-notes: |
  Encrypted credential exchange during BYO server registration is F-049 + F-050 (this ledger handles the
  start/stop/drain mechanics; credential injection is the BYO path).
  Sandboxing the spawned server inside an OS container is M19 deferred (F-D-012).
  Tool-cap-per-workspace cap-at-spawn (default 10) is M7 (F-125 NEW frontier candidate).
  Cross-machine MCP server discovery (network share / A2A endpoint) is M19 deferred (F-D-007..F-D-010).
confidence: high
---

# F-045 — MCP server lifecycle

## Behavior contract

Every registered MCP server has an explicit lifecycle: `registered → starting → ready → draining → stopped` (and `failed` as a terminal). Servers are spawned via the sidecar pattern (per `cp:sidecar/node-runner.exe` on Windows, `/usr/bin/env` on POSIX) so that no console window flashes on launch (`windowsHide: true` is mandatory; this is a tier-1 Windows requirement from `wave-1 lane-c lessons-learned.md`). The bundled filesystem MCP server (per `cp:bundled-mcp/filesystem-server.mjs`) is registered automatically at engine boot; user-supplied servers (per F-049) follow the same lifecycle. State transitions are persisted atomically per `kit:rules/concurrency-safety.md` (write-temp-rename) so a crashed engine can recover without a half-written registry. Halt (per F-020) drains all servers in parallel with a bounded 5-second drain window before forced stop. A server that fails to reach `ready` within 30s transitions to `failed` and surfaces a Context Gap per F-021.

## Acceptance scenarios

1. **Given** a fresh engine launch on Windows with the bundled filesystem MCP server, **When** the engine boots, **Then** the server spawns through `node-runner.exe` with `windowsHide: true`, no console window flashes, and the lifecycle reaches `ready` within 30s — observable in `cp:electron/mcp-store.ts` state.
2. **Given** an in-flight tool call on a registered server, **When** the kill-switch fires per F-020, **Then** the lifecycle transitions to `draining`, in-flight calls receive cancel signals, and after the 5-second drain window the server transitions to `stopped` (forced if needed) — total halt-to-stopped ≤6s.
3. **Given** a registered server whose binary is missing, **When** the lifecycle attempts to start, **Then** the spawn fails, the lifecycle transitions to `failed` with a structured error (`SERVER_BINARY_NOT_FOUND`), the engine continues running with that server marked unavailable, and a Context Gap is surfaced per F-021 — no halt of unrelated servers.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/mcp/lifecycle-windows-no-flash.test.ts` | integration | RED — Windows-only, sidecar | scenario 1 |
| (TBD) `tests/integration/mcp/lifecycle-drain-on-halt.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/mcp/lifecycle-failed-binary.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine kernel hosts the supervisor), F-008 (storage path for `mcp-store` state), F-044 (bridge connects after lifecycle reaches `ready`)
- **Soft:** F-020 (kill-switch drives drain), F-021 (degradation on `failed`), F-046 (reconnect uses lifecycle start/stop), F-049 (BYO server reuses the same lifecycle), F-050 (registry persists lifecycle target state)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:US-6 | Skills/MCP allowlist (registry is the gate) |
| cp:electron/mcp-store.ts | Lifecycle state machine + supervisor pattern |
| cp:electron/mcp-disabled.ts | Disabled-server fallback shape |
| cp:sidecar/node-runner.cs | Cross-platform MCP spawning source |
| cp:sidecar/node-runner.exe | Windows binary that prevents console flash |
| cp:bundled-mcp/filesystem-server.mjs | Bundled server that ships with engine |
| kit:rules/concurrency-safety.md | Atomic-write discipline for lifecycle state |
| kit:rules/dangerous-operations-policy.md | Force-stop/drain consent gate semantics |
| wave-1 lane-c lessons-learned.md | Sidecar pattern + Windows console flash + bounded retries lesson |

## Implementation notes

(empty — populated when implementation begins)
