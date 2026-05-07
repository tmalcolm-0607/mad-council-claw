---
artifact-class: milestone-overview
generated-by: hand-authored (wave-004 / lane-a)
status: red
milestone: M6
short-slug: mcp-tools
features: F-044..F-050
authored: 2026-05-06
---

# M6 — MCP & tool execution

The tool plane (`foundational-plan.md` § Architecture — Tool plane). MCP (Model Context Protocol) is the engine's external-tool substrate: filesystem, browser automation (Playwright), Microsoft 365 (WorkIQ), and any user-supplied servers. M6 makes every MCP server a first-class lifecycle citizen — registered, started/stopped under engine supervision, audited per tool call, surface-streamed back to the run, and persisted across launches. M6 builds on M0 (kernel + storage + logging + IPC) and M2 (governance: kill-switch, audit log, cost ledger, degradation, tool-quota) and is consumed by M5 (Extensions panel UI) + M7 (Skills + Permissions, which gate tool calls). Without M6, the engine is conversation-only: no filesystem ops, no browser, no M365.

## Features

| ID | Slug | One-liner |
|---|---|---|
| F-044 | mcp-bridge | MCP client bridge per server: capability handshake, JSON-RPC envelope, tool discovery, IPC namespace `mcp` |
| F-045 | mcp-server-lifecycle | Sidecar-spawned servers (Windows `node-runner.exe`, POSIX `/usr/bin/env`); register → start → ready → drain → stop; `windowsHide: true` |
| F-046 | mcp-reconnect-health | Bounded reconnect (≤3 attempts, exponential backoff); health probe on cadence; circuit-break on repeated failure → degraded state per F-021 |
| F-047 | tool-call-audit | Every tool invocation appended to the run's hash-chained audit log per F-015: `tool_name`, `server_id`, `args_sha256`, `result_sha256`, `started_utc`, `completed_utc` |
| F-048 | tool-result-streaming | Tool results stream incrementally to the renderer/CLI consumer through F-007 IPC; partial results flushed; cancel propagates to MCP server within ≤500ms |
| F-049 | byo-mcp-server | User-supplied MCP server registration: URL/command validation, encrypted credential store, OAuth flows, default-deny capability gate |
| F-050 | mcp-registry-persistence | Registry persisted to `<state-dir>/mcp/registry.json` (atomic write); credentials in `mcp-credentials.enc` (per-machine key); registry survives restart |

## Dependency DAG

```
F-001 (kernel)        ──→ F-044 (MCP bridge runs in main process)
F-007 (IPC contract)  ──→ F-044, F-048 (renderer consumes via mcp namespace)
F-006 (logger)        ──→ F-047 (audit log is a logger output)
F-008 (storage)       ──→ F-050 (registry + credentials path layout)

F-044 (bridge)        ──→ F-045 (lifecycle drives bridge connect/disconnect)
F-045 (lifecycle)     ──→ F-046 (reconnect uses lifecycle start/stop)
                      └──→ F-049 (BYO server is just a registered server lifecycle)
F-044 (bridge)        ──→ F-047 (audit fires on bridge tool-call)
F-044 (bridge)        ──→ F-048 (streaming flows over the same bridge)

F-015 (hash-chain)    ──→ F-047 (tool-call entries chained into the run audit log)
F-019 (cost ledger)   ──→ F-047 (tool-call cost — if backend exposes — recorded alongside)
F-020 (kill-switch)   ──→ F-045 (halt tears down all MCP servers in drain order)
                      └──→ F-048 (kill cancels streaming)
F-021 (degradation)   ──→ F-046 (circuit-break enters degraded state with Context Gap)
                      └──→ F-049 (BYO server unreachable → fall back to last-known capability list)
F-022 (tool-quota)    ──→ F-047 (per-spawn tool count quota enforced before tool-call audit emits)
F-017 (PII redaction) ──→ F-047 (audit log entries pass through redaction before persist)

F-049 (BYO)           ──→ F-050 (BYO registrations persist with the rest)
```

## Milestone exit criteria

- All 7 ledgers GREEN
- Bundled filesystem MCP server starts via sidecar on Windows + macOS + Linux without a console-window flash (per `cp:sidecar/node-runner.exe` lesson, lessons-learned tier-1)
- Three MCP servers (filesystem + Playwright + WorkIQ) coexist + each tool call lands a hash-chained audit entry per F-015
- Killing an MCP server mid-tool-call produces a clean cancel within ≤500ms + a `tool_calls_exhausted`-class run-end with the partial result preserved
- Reconnect circuit opens after 3 consecutive failures + run continues with Context Gap per F-021 (no hard halt)
- A BYO MCP server URL is validated against `mcp-url-validation.ts` regression suite + invalid URL rejected with structured error
- Encrypted credential store round-trips a sample OAuth token via per-machine key + restart preserves the encrypted blob
- Tool-quota gate (per F-022 / `ce:FR-QUOTA-001`) blocks `QUOTA_EXCEEDED_TOOL_CALLS` before audit emits — no audit for blocked calls
- Restart loads `registry.json` + reconnects all enabled servers; disabled servers stay disabled

## Out of scope (tracked elsewhere)

- Skill marketplace install + catalog browse for MCP servers → M7 (F-051..F-066) + M18 (F-119..F-121 local marketplace)
- 3-tier permissions on tool calls (auto / prompt / block) → M7 (F-058 perms-engine)
- Per-workspace tool-cap enforcement (default 10) → M7 (F-125 mcp-tool-cap-per-workspace, NEW frontier candidate)
- Scheduled-automation invocation of MCP tools (fail-closed for unclassified custom tools) → M7 (F-061..F-064 automations)
- Multi-model adversarial review of tool-call sequences → M10 (F-082..F-087)
- Cross-machine MCP server discovery (network share, A2A endpoint) → M-19 deferred (F-D-007..F-D-010 + F-122 a2a-endpoint-exposure NEW)
- Cloud marketplace for MCP server distribution → M19 deferred (F-D-001 cloud marketplace)
- Sandboxing MCP servers in OS-level containers → M19 deferred (F-D-012 sandboxing)
- Per-tool live trace timeline + step-by-step replay → M11 (F-088..F-092) + M12 (F-093..F-095)
- BYOK (bring-your-own-key) for tool-call-cost attribution → M19 deferred (F-D-011 BYOK)
- Multimodal tool inputs (voice, screenshot) → M13 (F-096..F-100)

## Provenance

`ce:US-6` (Skills/MCP allowlist + version pinning user story, P2), `ce:FR-QUOTA-001` (per-spawn tool count quota), `ce:FR-COST-003` (failure-pattern halt on 3 consecutive `tool_error`), `ce:tool_calls_exhausted` (run-end reason), `ce:QUOTA_EXCEEDED_TOOL_CALLS` (failure mode), `cp:electron/{mcp-store,mcp-tools,mcp-crypto,mcp-disabled}.ts`, `cp:electron/ipc/{mcp-ipc,mcp-oauth-ipc}.ts`, `cp:bundled-mcp/filesystem-server.mjs`, `cp:sidecar/node-runner.{cs,exe}`, `cp:common/{mcp-url-validation,tool-registry,format-tool-description}.ts`, `cp:electron/tool-discovery.ts`, `cp:src/features/extensions/{AddMcpDialog,McpServersTab,parseCatalogContent}.tsx`, `kit:rules/{degradation-fallback-policy,dangerous-operations-policy,concurrency-safety,verification-protocol,prompt-injection-policy,mcp-tiering}.md`, `wave-1 lane-c lessons-learned.md` (default-deny at every capability boundary; bounded retries with explicit timeouts; sidecar spawning to avoid Windows console flash; refresh-token contention prevention). Per-ledger `provenance.surfaces`.
