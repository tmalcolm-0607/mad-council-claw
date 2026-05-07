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
feature-id: F-077
short-slug: wam-silent-auth
milestone: M9
provenance:
  surfaces:
    - cp:electron/m365-token.ts
    - cp:electron/m365-token-wam.ts
    - cp:electron/m365-token-wam-gate.ts
    - cp:electron/tenant-policy.ts
    - cp:commit 89be5fa5 (macOS broker / WAM tenant filter)
    - kit:rules/degradation-fallback-policy.md
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
  LOCKED if GREEN AND reviews/F-077-wam-silent-auth-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-076]
out-of-scope-notes: |
  WAM is a Windows-only silent broker. macOS-broker work (clawpilot has a recent
  fix at commit 89be5fa5 / 9f7989a4 / d6b15b21 for tenant filtering on the
  macOS broker path) is out of scope for v1 — engine v1 ships with WAM on
  Windows and MSAL everywhere else. macOS broker is a v1.5 follow-up.
  Tenant-filter UX (selecting which tenant to bind to) deferred to M8 settings.
confidence: high
---

# F-077 — WAM silent authentication (Windows)

## Behavior contract

On Windows with an AAD-joined device, valid PRT (Primary Refresh Token), and a console session, the engine MUST attempt token acquisition via WAM (Web Account Manager) before falling back to MSAL (F-076). The WAM path returns a token silently — no UI prompt, no browser launch — when the OS-level identity matches the requested tenant. The WAM gate enforces tenant filtering: if the device's signed-in identity is in an out-of-org tenant, the gate rejects with `WAM_TENANT_REJECTED` and the flow falls back to MSAL. WAM failures (`WAM_UNAVAILABLE`, `WAM_TENANT_REJECTED`, `WAM_PRT_EXPIRED`) are non-fatal and gracefully degrade to F-076 per `degradation-fallback-policy.md` Rule 1.

## Acceptance scenarios

1. **Given** an AAD-joined Windows device with valid PRT and console session, **When** the engine requests an M365 token via the entry point (`m365-token.ts`), **Then** WAM returns a valid access token in < 2 s without showing any UI.
2. **Given** a Windows device where the signed-in OS identity is in a non-allowed tenant, **When** WAM is invoked, **Then** the WAM gate (per `m365-token-wam-gate.ts`) rejects with `WAM_TENANT_REJECTED` and the flow falls back to MSAL (F-076) without a hard error.
3. **Given** a Windows device where WAM returns `WAM_UNAVAILABLE` (e.g., RDP session, no console), **When** the engine retries, **Then** the engine logs a Context Gap entry per `degradation-fallback-policy.md` Rule 3 and uses MSAL (F-076) for this acquisition.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/auth/wam-silent-success.test.ts` | integration | RED | scenario 1 (Windows-only; skip on other OS) |
| (TBD) `tests/integration/auth/wam-tenant-gate-rejects.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/auth/wam-unavailable-context-gap.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine kernel), F-076 (MSAL fallback path; WAM cannot be the sole path)
- **Soft:** F-021 (degradation-fallback-policy provides the Context Gap framing for WAM failures), F-079 (refresh path checks WAM first when available)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:electron/m365-token.ts | WAM-first entry point with MSAL fallback orchestration |
| cp:electron/m365-token-wam.ts | WAM broker invocation; expiry handling |
| cp:electron/m365-token-wam-gate.ts | tenant filter (org-only enforcement) |
| cp:electron/tenant-policy.ts | tenant-policy module that drives the gate decisions |
| cp:commit 89be5fa5 | macOS broker / WAM tenant filter recent fix — informs out-of-scope notes |
| kit:rules/degradation-fallback-policy.md | Rules 1 + 3: WAM unavailability is degradation, not failure |

## Implementation notes

(empty — populated when implementation begins)
