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
feature-id: F-050
short-slug: mcp-registry-persistence
milestone: M6
provenance:
  surfaces:
    - ce:US-6
    - cp:electron/mcp-store.ts
    - cp:electron/mcp-crypto.ts
    - kit:rules/concurrency-safety.md
    - kit:rules/single-owner-accountability.md
    - "wave-1 lane-c lessons-learned.md (default-deny + atomic write)"
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
  LOCKED if GREEN AND reviews/F-050-mcp-registry-persistence-review.md exists with verdict: ACCEPT.
depends-on: [F-008, F-045, F-049]
out-of-scope-notes: |
  Encrypted import/export of the registry across machines is M8 (F-072 encrypted import/export).
  Cross-machine registry sync (network-share or cloud) is M19 deferred (F-D-001 cloud marketplace + F-D-007 cross-machine).
  Schema migration for registry shape changes between releases is M19 deferred (FR-MIGRATE-001 — schema migration tool).
  Identity-bound credential keying (Entra-managed) beyond per-machine key is M19 deferred (F-D-005 + F-D-006).
  Registry-level multi-owner with quorum on changes is v1.5 (F-NNN candidate).
confidence: high
---

# F-050 — MCP registry persistence

## Behavior contract

The MCP server registry is the durable source of truth for which servers exist, their configuration, and their last-known target state (`enabled` / `disabled`). The registry persists to `<state-dir>/mcp/registry.json` with atomic write per `kit:rules/concurrency-safety.md` (write `.tmp` + rename). Encrypted credentials (OAuth tokens, secrets per F-049) persist to `<state-dir>/mcp/mcp-credentials.enc` keyed via `cp:electron/mcp-crypto.ts` per-machine key. On engine launch, the engine reads `registry.json` synchronously before starting the supervisor (per F-045 lifecycle): each `enabled: true` server is queued for start; `enabled: false` servers are loaded into the registry but stay stopped. Half-written registry files are detected on read (JSON parse failure) and the engine falls back to the most recent `.tmp.bak` if available, otherwise enters a degraded state per F-021 with no auto-managed servers (the user can re-add). Registry mutations (add / enable / disable / remove) acquire the engine's single-owner write lock per `kit:rules/single-owner-accountability.md` so concurrent renderer windows cannot corrupt state. Removing a server purges its credential entry from the encrypted store atomically with the registry update.

## Acceptance scenarios

1. **Given** an engine with 3 MCP servers registered (1 bundled-enabled, 1 BYO-enabled, 1 BYO-disabled), **When** the engine restarts, **Then** `registry.json` parses, the bundled + 1 BYO transition through `starting` → `ready` per F-045, the disabled BYO server stays `stopped`, and the registry's `enabled` flags exactly match pre-restart values — no flag drift.
2. **Given** a registry write interrupted by a process kill mid-rename, **When** the engine relaunches, **Then** the engine detects the half-written state (parse failure on `registry.json`), falls back to `registry.json.bak` if present, otherwise enters a degraded mode per F-021 with the registry empty + a Context Gap surfaced — engine continues running without auto-started MCP servers; user can re-register.
3. **Given** two renderer windows (per F-043 multi-window) both attempting to disable the same server simultaneously, **When** the IPC writes race, **Then** the engine's single-owner write lock per `kit:rules/single-owner-accountability.md` serializes the writes, the final `enabled: false` state is persisted exactly once, and the registry never contains a half-merged conflict.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/mcp/registry-restart-state-fidelity.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/unit/mcp/registry-half-write-recovery.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/mcp/registry-multi-window-write-lock.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-008 (storage layout supplies `<state-dir>/mcp/` paths), F-045 (lifecycle reads target state from registry), F-049 (BYO registrations land here)
- **Soft:** F-021 (degradation on registry recovery failure), F-043 (multi-window write contention is the multi-renderer case), F-072 (encrypted import/export builds on this primitive)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:US-6 | Skills/MCP allowlist user story (allowlist persistence) |
| cp:electron/mcp-store.ts | Registry write/read shape |
| cp:electron/mcp-crypto.ts | Encrypted credential store paired with the registry |
| kit:rules/concurrency-safety.md | Atomic write-temp-rename pattern |
| kit:rules/single-owner-accountability.md | Single write-lock owner across renderer windows |
| wave-1 lane-c lessons-learned.md | Default-deny + atomic write + recovery from corrupted state |

## Implementation notes

(empty — populated when implementation begins)
