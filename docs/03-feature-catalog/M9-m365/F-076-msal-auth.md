---
artifact-class: feature-ledger
generated-by: hand-authored (wave-005 / lane-a)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-005 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-076
short-slug: msal-auth
milestone: M9
provenance:
  surfaces:
    - cp:electron/auth/msal-provider.ts
    - cp:@azure/msal-node ^5.1.2
    - cp:@azure/msal-node-extensions ^5.1.2
    - cp:src/features/auth/gateway/PairingDialog.tsx
    - kit:rules/single-owner-accountability.md
    - R:microsoft-2026/agent-365-sdk.md
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
  LOCKED if GREEN AND reviews/F-076-msal-auth-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-002, F-008]
out-of-scope-notes: |
  WAM silent-broker path on Windows is F-077 (separate ledger; F-076 covers
  the MSAL fallback used everywhere and the primary path on macOS / Linux /
  non-AAD-joined Windows). Encrypted token cache shape is F-079.
  Multi-tenant switcher UX deferred to M8 (F-067..F-075).
confidence: high
---

# F-076 — MSAL authentication

## Behavior contract

The engine MUST acquire user-context tokens via `@azure/msal-node` using the authorization-code flow with PKCE. The redirect URI is the engine's custom protocol (`ms-mad-council://auth/callback` or equivalent) and the deep-link handler completes the flow without requiring an embedded browser. Token acquisition is bound to the engine's agent identity (per F-002): the resulting access token + refresh token are scoped to the agent's session and not shared across sessions. On first launch the user is sent to the auth screen (F-078) which initiates the MSAL flow; subsequent launches reuse cached tokens via F-079. MSAL is the primary path on macOS, Linux, and non-AAD-joined Windows; on AAD-joined Windows it acts as fallback when WAM (F-077) is unavailable.

## Acceptance scenarios

1. **Given** a fresh install on macOS with no cached tokens, **When** the user clicks "Sign in to Microsoft 365" on the auth screen, **Then** MSAL opens the system browser, the user authenticates, the deep-link callback fires, and the engine receives a valid access token + refresh token bound to its session_id.
2. **Given** an AAD-joined Windows machine where WAM (F-077) returns `WAM_UNAVAILABLE` (e.g., user not on console session), **When** the auth flow runs, **Then** the engine falls back to the MSAL browser flow without a hard error.
3. **Given** a successful MSAL token acquisition, **When** the engine inspects the access token, **Then** the `oid` (object ID) claim matches the authenticated user, and the token + refresh token are persisted via F-079's encrypted cache.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/auth/msal-deep-link-roundtrip.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/auth/msal-fallback-from-wam.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/auth/msal-token-bound-to-session.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine kernel; auth flow runs in `opening` lifecycle), F-002 (agent identity; token bound to session_id), F-008 (storage layout; encrypted cache location)
- **Soft:** F-077 (WAM fallback path), F-078 (auth screen drives MSAL flow), F-079 (token cache + refresh)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:electron/auth/msal-provider.ts | MSAL provider module shape; deep-link callback handler; PKCE flow orchestration |
| cp:@azure/msal-node ^5.1.2 | MSAL Node.js SDK version pin (clawpilot baseline) |
| cp:@azure/msal-node-extensions ^5.1.2 | encrypted-cache extension version pin |
| cp:src/features/auth/gateway/PairingDialog.tsx | OpenClaw device pairing pattern (commit 8c39a277) — informs deep-link UX |
| kit:rules/single-owner-accountability.md | session_id binding ensures tokens are accountable to the engine's identity, not free-floating |
| R:microsoft-2026/agent-365-sdk.md | Entra Agent ID context — frames why MSAL token must bind to agent identity for future Agent 365 layering |

## Implementation notes

(empty — populated when implementation begins)
