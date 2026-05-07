---
artifact-class: milestone-overview
generated-by: hand-authored (wave-005 / lane-a)
status: red
milestone: M9
short-slug: m365
features: F-076..F-081
authored: 2026-05-06
---

# M9 — M365 integration

The Microsoft 365 integration plane. MSAL/WAM identity for the engine's user-context, an auth screen UX matching clawpilot's stage-card pattern, token refresh + cache encryption, a WorkIQ adapter for read-only internal context (Teams chats / emails / calendar / SharePoint), and a rate-limit + circuit-breaker layer protecting downstream Microsoft Graph + WorkIQ surfaces from abuse.

This milestone consumes the auth identity output and feeds context into the engine's run-time grounding loop. It is the load-bearing surface for "WorkIQ + readonly Microsoft solutions" per G12 (foundational-plan.md V:17).

## Features

| ID | Slug | One-liner |
|---|---|---|
| F-076 | msal-auth | `@azure/msal-node` + `@azure/msal-node-extensions` (encrypted token cache); deep-link redirect URI `ms-mad-council://auth/callback`; primary on all platforms |
| F-077 | wam-silent-auth | Windows-only WAM broker (`m365-token-wam.ts`); requires AAD-joined device + valid PRT + console session; falls back to MSAL on failure |
| F-078 | auth-screen-initial | Stage-card auth screen (10 cards: AuthCheckingCard, ConnectM365Card, M365SigningInCard, M365AccessDeniedCard, etc.); telemetry per stage |
| F-079 | token-refresh-cache | Silent refresh via MSAL `acquireTokenSilent`; encrypted cache via `msal-node-extensions`; refresh-before-expiry margin 5 min |
| F-080 | workiq-adapter | `@microsoft/workiq` SDK adapter (read-only): Teams chats / emails / calendar / SharePoint; surfaces internal context to engine |
| F-081 | workiq-rate-limit-cb | Per-resource rate limit (token bucket) + circuit breaker (3 fails / 60s window) on Graph + WorkIQ surfaces; rejection logged to audit |

## Dependency DAG

```
M0 (F-001 kernel, F-002 identity, F-006 logger, F-008 storage) ──→ all M9 features

F-076 (MSAL)        ──┬──→ F-077 (WAM falls back to MSAL on Windows; otherwise MSAL only)
                      ├──→ F-079 (token refresh uses MSAL acquireTokenSilent)
                      └──→ F-078 (auth screen drives MSAL flow on first launch)

F-077 (WAM)        ──┬──→ F-078 (auth screen routes Windows users to WAM-first stages)
                     └──→ F-079 (refresh path checks WAM first when available)

F-079 (refresh)    ──→ F-080 (WorkIQ adapter consumes refreshed tokens for Graph)
                  └──→ F-081 (rate limiter sees token age for prioritization)

F-080 (WorkIQ)     ──→ F-081 (CB wraps WorkIQ + Graph calls)

F-021 degradation ──→ F-081 (CB pattern reuses degradation-fallback-policy.md rules)
F-015 audit       ──→ F-081 (rate-limit / CB rejections logged)
F-022 tool-quota  ──→ F-081 (per-cycle / per-run quotas apply to WorkIQ tool calls)
F-002 identity    ──→ F-076, F-077 (MSAL/WAM tokens bound to engine's agent identity)
```

## Milestone exit criteria

- All 6 ledgers GREEN
- A first-launch flow on Windows with AAD-joined device acquires a token via WAM in < 2 s without prompting
- A first-launch flow on macOS / Linux / non-AAD-joined Windows acquires a token via MSAL with deep-link redirect
- Auth screen renders all 10 stage cards reachable via state transitions; per-card telemetry emits
- Token cache survives app restart (encrypted at rest); refresh fires automatically 5 min before expiry
- WorkIQ adapter returns Teams chat / email / calendar / SharePoint context for the authenticated user (read-only)
- 3 consecutive 429s from Graph within 60 s opens the CB; 4th call returns `CIRCUIT_OPEN` immediately
- Rate-limit and CB rejections appear in `audit-log.jsonl` with `prev_sha256` chain intact (per F-015)

## Out of scope (tracked elsewhere)

- WorkIQ write operations (post Teams message, send email, create event) — v1.5; v1 is read-only by G12
- Tenant filter UX / multi-tenant switcher — deferred to M8 settings (F-067..F-075)
- M365 sensitivity-label elevation (MIP) — v1.5 follow-up; clawpilot has it but engine v1 ships read-only context
- Outbound webhook / push-notification surface for Teams / Outlook — Agent 365 SDK territory; M11+ if pursued
- Agent 365 SDK Entra Agent ID provisioning — separate identity plane; deferred to M11 introspect/replay milestone
- Teams chat / email send tooling (clawpilot has this; engine v1 read-only) — v1.5
- BYOK / customer-managed keys for token cache — v1.5 enterprise feature

## Provenance

`ce:FR-AUTH-*` (MSAL/WAM identity surface), `cp:electron/auth/msal-provider.ts`, `cp:electron/m365-token.ts`, `cp:electron/m365-token-wam.ts`, `cp:electron/m365-token-wam-gate.ts`, `cp:src/features/auth/AuthScreen.tsx` + 10 stage cards, `cp:src/features/auth/useM365Auth.ts`, `cp:electron/m365/` (Graph tools, ~25 files), `cp:@microsoft/workiq ^0.4.1`, `cp:@azure/msal-node ^5.1.2`, `cp:@azure/msal-node-extensions ^5.1.2`, `kit:rules/degradation-fallback-policy.md` (F-081 CB rules), `kit:rules/anomaly-thresholds.md` (F-081 sliding-window thresholds), `kit:rules/single-owner-accountability.md` (F-076/F-077 session-id binding), `R:microsoft-2026/agent-365-sdk.md` (Entra Agent ID context), `R:microsoft-2026/workiq-internal-context.md` (Lobster + read-only patterns), `R:openclaw-clawpilot/clawpilot-architecture.md` (auth lifecycle), `R:openclaw-clawpilot/clawpilot-features-inventory.md` § 8 + § 16 (MSAL/WAM + M365 Graph). Per-ledger `provenance.surfaces`.
