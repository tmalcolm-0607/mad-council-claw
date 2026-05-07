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
feature-id: F-049
short-slug: byo-mcp-server
milestone: M6
provenance:
  surfaces:
    - ce:US-6
    - cp:electron/mcp-store.ts
    - cp:electron/mcp-crypto.ts
    - cp:electron/ipc/mcp-oauth-ipc.ts
    - cp:common/mcp-url-validation.ts
    - cp:src/features/extensions/AddMcpDialog.tsx
    - cp:src/features/extensions/McpServersTab.tsx
    - kit:rules/dangerous-operations-policy.md
    - kit:rules/prompt-injection-policy.md
    - "wave-1 lane-c lessons-learned.md (default-deny at every capability boundary)"
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
  LOCKED if GREEN AND reviews/F-049-byo-mcp-server-review.md exists with verdict: ACCEPT.
depends-on: [F-007, F-044, F-045, F-050]
out-of-scope-notes: |
  Marketplace-style discovery + browse for shareable MCP servers is M18 local-v1 (F-119..F-121) + M19 deferred (F-D-001 cloud marketplace).
  Cross-machine A2A endpoint registration as an MCP-equivalent surface is M19 deferred (F-122 a2a-endpoint-exposure NEW frontier candidate).
  Per-workspace tool-cap enforcement (default 10) at registration time is M7 (F-125 NEW frontier candidate).
  Sandboxing the BYO server in an OS-level container is M19 deferred (F-D-012).
  Identity-bound credential keying (Entra-managed, per-user) beyond per-machine key is M19 deferred (F-D-005 + F-D-006).
confidence: high
---

# F-049 — Bring-your-own MCP server

## Behavior contract

Users may register additional MCP servers beyond the bundled filesystem server. Registration accepts either a launch command (path + args, executed via the sidecar pattern per F-045) or a URL (HTTP/SSE transport per MCP spec). URLs MUST pass `cp:common/mcp-url-validation.ts` (https-only for non-localhost; reject `file://`, `javascript:`, malformed schemes). Commands MUST point to executables on the user's PATH or an absolute file path; relative paths are rejected. Registration is a Dangerous Operation per `kit:rules/dangerous-operations-policy.md` — the user explicitly confirms via a preview prompt (`AddMcpDialog`) that surfaces the server name, transport, capabilities-on-first-handshake, and whether OAuth credentials will be requested. Default-deny applies per `wave-1 lane-c lessons-learned.md`: a freshly registered server starts disabled; the user must explicitly enable it before its bridge connects. OAuth flows go through `cp:electron/ipc/mcp-oauth-ipc.ts` (separate IPC namespace from the main `mcp` namespace, so OAuth state never bleeds into tool dispatch). Tokens are encrypted at rest via `cp:electron/mcp-crypto.ts` with a per-machine key (per F-050 storage). Tool descriptions from BYO servers pass the same `kit:rules/prompt-injection-policy.md` Rule 1 scan as bundled servers.

## Acceptance scenarios

1. **Given** a user pasting `https://example.com/mcp` into AddMcpDialog, **When** the user clicks Register, **Then** the URL passes `mcp-url-validation.ts`, the dialog presents a preview (server name, transport=`http`, capabilities=`<unknown until first connect>`, no OAuth), the user confirms, and a registration entry lands in the registry per F-050 with `enabled: false` (default-deny). The bridge does NOT yet connect.
2. **Given** a registered BYO server requiring OAuth, **When** the user clicks Enable, **Then** the OAuth flow runs through `mcp-oauth-ipc.ts`, on success the access token + refresh token are encrypted via `mcp-crypto.ts` with the per-machine key, persisted to `mcp-credentials.enc` (per F-050), and the server transitions to `ready` per F-045 lifecycle.
3. **Given** an attempted registration with `file:///etc/passwd` as the URL, **When** the user submits, **Then** `mcp-url-validation.ts` rejects with `MCP_URL_INVALID_SCHEME`, the registration does NOT land in the registry, no consent prompt appears (the dialog rejects synchronously), and the audit log per F-047 records the rejected attempt — no encrypted blob is created.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/mcp/byo-url-validation.test.ts` | unit | RED — port `cp:common/mcp-url-validation` regression suite | scenario 1 + scenario 3 |
| (TBD) `tests/integration/mcp/byo-oauth-roundtrip.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/mcp/byo-default-deny-on-register.test.ts` | unit | RED | scenario 1 (default-deny check) |

## Dependencies

- **Hard:** F-007 (IPC contract for AddMcpDialog ↔ main), F-044 (bridge connects when enabled), F-045 (lifecycle starts the server), F-050 (registry + encrypted credential persistence)
- **Soft:** F-046 (reconnect for BYO servers behind flaky networks), F-047 (audit records BYO tool calls), F-021 (degradation when BYO unreachable), M5 F-038 + F-041 (UI primitives + menu hooks for AddMcpDialog)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:US-6 | Skills/MCP allowlist user story (BYO is the user-driven extension path) |
| cp:electron/mcp-store.ts | Registry data shape for BYO servers |
| cp:electron/mcp-crypto.ts | Per-machine key encryption of OAuth tokens |
| cp:electron/ipc/mcp-oauth-ipc.ts | Separate IPC namespace for OAuth flows |
| cp:common/mcp-url-validation.ts | URL validation (regression suite ports straight) |
| cp:src/features/extensions/AddMcpDialog.tsx | Registration UX shape |
| cp:src/features/extensions/McpServersTab.tsx | Enable/disable + OAuth-status surface |
| kit:rules/dangerous-operations-policy.md | Registration is a Dangerous Operation requiring consent |
| kit:rules/prompt-injection-policy.md | BYO tool descriptions go through the same Rule 1 scan |
| wave-1 lane-c lessons-learned.md | Default-deny at every capability boundary |

## Implementation notes

(empty — populated when implementation begins)
