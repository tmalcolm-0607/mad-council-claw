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
feature-id: F-079
short-slug: token-refresh-cache
milestone: M9
provenance:
  surfaces:
    - cp:@azure/msal-node-extensions ^5.1.2
    - cp:electron/auth/safe-storage-file.ts
    - cp:electron/m365-token.ts
    - cp:electron/m365-token-wam.ts (expiry handling)
    - kit:rules/concurrency-safety.md
    - kit:rules/single-owner-accountability.md
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
  LOCKED if GREEN AND reviews/F-079-token-refresh-cache-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-008, F-076]
out-of-scope-notes: |
  BYOK / customer-managed keys for token cache encryption are a v1.5 enterprise
  feature. Engine v1 uses the OS keychain via msal-node-extensions; cross-device
  token sync is explicitly OUT — tokens are local-only.
  Refresh-token rotation policy (force-rotate on suspicious activity) is a v1.5
  hardening item.
confidence: high
---

# F-079 — Token refresh + encrypted cache

## Behavior contract

The engine MUST persist acquired access tokens + refresh tokens via `@azure/msal-node-extensions` (encrypted cache backed by OS keychain — Keychain on macOS, DPAPI on Windows, libsecret on Linux). On every M365 token request the engine MUST first call `acquireTokenSilent` (MSAL) which transparently refreshes when the cached access token is within a 5-minute expiry margin. Refresh failures (refresh token expired, conditional-access change, account removed) gracefully degrade to a re-prompt via the auth screen (F-078). Cache writes use atomic write-temp-then-rename per `concurrency-safety.md` § 2 to prevent half-written state. Every cache entry is keyed by the engine's `session_id` (per F-002) so tokens are bound to identity and never reused across sessions.

## Acceptance scenarios

1. **Given** an engine with a valid cached access token (>5 min remaining), **When** the engine requests a token, **Then** `acquireTokenSilent` returns the cached token immediately without a network round trip and no refresh fires.
2. **Given** a cached access token within the 5-min refresh margin AND a valid refresh token, **When** the engine requests a token, **Then** MSAL silently refreshes via the refresh token, updates the cache atomically, and returns the new access token without UI.
3. **Given** a refresh token that has expired or been revoked, **When** the engine attempts silent refresh, **Then** MSAL throws `InteractionRequiredAuthError`, the engine clears the local cache entry, and the auth screen (F-078) re-renders to prompt the user to sign in again.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/auth/token-cache-hit-no-refresh.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/auth/token-silent-refresh.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/auth/token-interaction-required-reprompt.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine lifecycle), F-008 (storage layout for cache file location), F-076 (MSAL provides `acquireTokenSilent`)
- **Soft:** F-077 (WAM acquires its own tokens; refresh path is MSAL-only — WAM tokens carry their own expiry from the broker), F-078 (re-prompt UI on refresh failure)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:@azure/msal-node-extensions ^5.1.2 | encrypted token cache extension (OS keychain backing) |
| cp:electron/auth/safe-storage-file.ts | atomic file-write helper for cache persistence |
| cp:electron/m365-token.ts | refresh-before-expiry orchestration |
| cp:electron/m365-token-wam.ts (expiry handling) | WAM token expiry handling pattern |
| kit:rules/concurrency-safety.md | § 2 atomic writes for cache file integrity |
| kit:rules/single-owner-accountability.md | session_id keying ensures cache entries are accountable to identity |

## Implementation notes

(empty — populated when implementation begins)
