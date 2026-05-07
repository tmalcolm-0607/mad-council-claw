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
feature-id: F-044
short-slug: mcp-bridge
milestone: M6
provenance:
  surfaces:
    - ce:US-6
    - cp:electron/mcp-tools.ts
    - cp:electron/ipc/mcp-ipc.ts
    - cp:electron/tool-discovery.ts
    - cp:common/tool-registry.ts
    - cp:common/format-tool-description.ts
    - kit:rules/verification-protocol.md
    - kit:rules/mcp-tiering.md
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
  LOCKED if GREEN AND reviews/F-044-mcp-bridge-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-007]
out-of-scope-notes: |
  3-tier permissions on tool-call invocation (auto/prompt/block) is M7 (F-058 perms-engine).
  Tool-cap-per-workspace enforcement (default 10) is M7 (F-125 NEW frontier candidate).
  Multi-model adversarial review of tool-call sequences is M10 (F-082..F-087).
  Per-tool live trace timeline + replay scrubber is M11+M12 (F-088..F-095).
confidence: high
---

# F-044 — MCP bridge

## Behavior contract

The engine speaks Model Context Protocol over a per-server bridge that connects the main-process kernel (per F-001) to each registered MCP server. On bridge connect, the bridge performs the MCP capability handshake, enumerates the server's tool catalog (`tools/list`), normalizes each tool's schema through `cp:common/tool-registry.ts` shape, and exposes the catalog to the renderer/CLI through the `mcp` IPC namespace (per F-007 contract). All tool calls flow through the bridge as JSON-RPC envelopes; results stream back per F-048. The bridge MUST NOT trust server output blindly — tool descriptions pass through `cp:common/format-tool-description.ts` sanitization before reaching the consumer (per `kit:rules/prompt-injection-policy.md` — tool descriptions are external content treated as data, not instructions). One bridge instance per server; multiple servers run concurrently.

## Acceptance scenarios

1. **Given** a registered + connected MCP server with a `read_file` tool, **When** the renderer calls `mcp.listTools(serverId)`, **Then** the response contains `read_file` with its sanitized schema + description, sourced from `tools/list` and normalized through `tool-registry.ts`.
2. **Given** an active bridge to a server, **When** the renderer dispatches `mcp.callTool(serverId, "read_file", { path: "/tmp/x.txt" })`, **Then** the bridge emits a JSON-RPC `tools/call` request, awaits the response, and returns the result through the IPC channel within the configured timeout (default 30s); a server response containing a literal "Ignore previous instructions" phrase is flagged in the audit log per F-047 but the body is passed through unredacted (per `kit:rules/prompt-injection-policy.md` Rule 3 — flag, don't redact).
3. **Given** a malformed `tools/list` response (missing required fields), **When** the bridge processes it, **Then** the bridge rejects the catalog, emits a structured error, and the server enters `degraded` state per F-021 — the IPC namespace returns an empty tool list rather than a partial/corrupt one.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/mcp/bridge-handshake.test.ts` | unit | RED — capability handshake | scenario 1 |
| (TBD) `tests/integration/mcp/bridge-tool-call-roundtrip.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/mcp/bridge-malformed-catalog.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine kernel hosts the bridge in main process), F-007 (IPC contract for renderer-main `mcp` namespace)
- **Soft:** F-045 (lifecycle drives bridge connect/disconnect), F-047 (audit fires on tool-call), F-048 (streaming flows over the bridge), F-021 (degradation on bridge failure)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:US-6 | Skills/MCP allowlist user story (the bridge is the gating point) |
| cp:electron/mcp-tools.ts | Bridge implementation pattern |
| cp:electron/ipc/mcp-ipc.ts | `mcp` IPC namespace definition |
| cp:electron/tool-discovery.ts | Tool enumeration across active servers |
| cp:common/tool-registry.ts | Tool-schema normalization |
| cp:common/format-tool-description.ts | Description sanitization for prompt-injection defense |
| kit:rules/verification-protocol.md | FETCH BEFORE CITE — bridge fetches actual server catalog, never assumes |
| kit:rules/mcp-tiering.md | Bridge respects context-tier vs CLI-tier classification at call time |

## Implementation notes

(empty — populated when implementation begins)
