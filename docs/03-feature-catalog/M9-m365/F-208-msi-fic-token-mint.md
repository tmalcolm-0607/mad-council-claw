---
artifact-class: feature-ledger
generated-by: hand-authored (silent-deferral surfacing 2026-05-07)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: silent-deferral surfacing audit (.mad/reports/mad-council-claw-audit-2026-05-07.md in MAD - Clean kit)
    note: "Initial creation surfacing a silent-deferral. The MSI-Federated-Identity-Credential token mint flow at m-relay-main/src/bot.ts:125-175 was inventoried in the 2026-05-07 audit (Lane C, agentId a762840e5a17233e0) but never tracked as an F-NNN — it is a precursor to F-D-008 teams-adapter re-open, and an explicit example of the secret-less Bot Framework auth pattern (no MicrosoftAppPassword stored anywhere). Per .claude/rules/no-silent-deferrals.md, surfacing here as F-208. Sibling ledgers F-206/F-207/F-209/F-210."
feature-id: F-208
short-slug: msi-fic-token-mint
milestone: M9
provenance:
  surfaces:
    - mr:m-relay-main/src/bot.ts:79-82
    - mr:m-relay-main/src/bot.ts:125-175
    - kit:rules/single-owner-accountability.md
    - kit:rules/dangerous-operations-policy.md
    - kit:rules/concurrency-safety.md
fr-coverage: []
test-files:
  unit: []
  node:
    - tests/node/F-208-msi-fic-token-mint.test.ts
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - node
red-green-rule: |
  RED   if ANY of the 7 acceptance items (a)-(g) below fails OR test file is missing OR runner returns non-zero exit.
  GREEN if ALL 7 acceptance items pass AND tests/node/F-208-msi-fic-token-mint.test.ts exists AND runner returns zero exit.
  LOCKED if GREEN AND docs/05-design-reviews/council-reviews/F-208-msi-fic-token-mint-review.md exists with verdict: ACCEPT (median confidence ≥ 80).
depends-on: [F-205, F-D-008-pending-reopen]
out-of-scope-notes: |
  Per .claude/rules/no-silent-deferrals.md, every adjacent surface NOT covered by this ledger is
  enumerated below with explicit rationale. None of these are silently dropped:

  1. **MSAL user-context auth (F-076 msal-auth)** is for USER tokens (delegated). F-208 is
     for the BOT's app-only token via federated identity. Both surfaces coexist in v1; they
     authenticate different actors (user vs bot service principal).
  2. **WAM broker (F-077)** is user-context Windows-only; no overlap with F-208.
  3. **Encrypted token cache (F-079)** is for user tokens (msal-node-extensions). F-208's
     bot-token cache is in-process module-scoped (`let cachedToken`, `bot.ts:80,170-173`)
     — single-instance App Service Linux, refreshed on demand, no cross-instance sharing.
     Cross-instance cache (Service Bus, Cosmos, Redis) is OUT OF SCOPE for v1.
  4. **Client-secret fallback (`MicrosoftAppPassword` env var)** — the m-relay-main
     baseline DOES NOT use a client secret; FIC is the ONLY production auth path. v1
     follows the same shape. Re-open trigger: explicit no-FIC-available environment.
  5. **Workload Identity (Kubernetes)** as a FIC source is OUT OF SCOPE for v1; m-relay-main
     uses App Service `IDENTITY_ENDPOINT` / `IDENTITY_HEADER` (`bot.ts:131-135`). Workload
     Identity is a future-platform concern.
  6. **Token expiry refresh-margin** — current code uses a 60-second skew (`bot.ts:126`:
     `Date.now() < cachedToken.expiresAt - 60_000`). v1 lifts the 60s margin verbatim.
     Tunable refresh-margin per environment is deferred.
  7. **Scope handling** — current code requests `https://api.botframework.com/.default`
     scope ONLY (`bot.ts:158`). v1 lifts this scope. Multi-scope (Graph + Bot Framework
     in one token) is OUT OF SCOPE; that requires a separate exchange.
  8. **Secret-rotation alerting** — when MSI exchange fails on auth (`bot.ts:147` /
     `bot.ts:166`), `BotAuthError` is thrown. F-018 failure-pattern-halt MAY consume this
     for governance; the integration is a follow-on cross-feature concern, not scoped here.
confidence: high
---

# F-208 — MSI-Federated-Identity Bot Framework token mint

## Rationale

`m-relay-main/src/bot.ts:125-175` implements `getBotToken()`, a two-step federated-identity-credential (FIC) token-acquisition flow:

- **Step 1**: Acquire an MSI access token for the audience `api://AzureADTokenExchange` from the App Service Linux managed identity endpoint (`IDENTITY_ENDPOINT` + `IDENTITY_HEADER`). This is an **assertion** token — not a Bot Framework token, but a JWT proving "I am the App Service identity `MicrosoftAppMSIClientId`".
- **Step 2**: Exchange the MSI assertion at the AAD `/oauth2/v2.0/token` endpoint with `grant_type: client_credentials` + `client_assertion_type: urn:ietf:params:oauth:client-assertion-type:jwt-bearer` + `client_assertion: <step-1-token>` + `scope: https://api.botframework.com/.default`. AAD validates the assertion against the User-Assigned Managed Identity's federated credential binding to the Bot Framework App Registration's `MicrosoftAppId`, and returns a Bot Framework access token.

The flow is **secret-less** — no `MicrosoftAppPassword` anywhere. This is the production posture every Bot Framework integration should have. Per `.mad/reports/mad-council-claw-audit-2026-05-07.md` Lane C: "FIC is the highest-value security primitive in m-relay-main; without F-208 the bot must store a client secret in App Service config".

In-process token cache: `cachedToken` module variable holds `{token, expiresAt}`; `getBotToken()` returns the cached token if `Date.now() < expiresAt - 60_000` (60-second early-refresh skew). On expiry, both steps re-run. Single-instance only — no cross-instance cache.

This ledger is RED on creation and **soft-blocked on F-D-008 teams-adapter re-open** (same as F-206/F-207). F-208 is meaningless without F-D-008 active.

## Behavior contract

The mad-council-claw engine MUST provide a Bot Framework FIC token-mint primitive that:

1. **Acquires** an MSI assertion token from `${IDENTITY_ENDPOINT}?resource=api://AzureADTokenExchange&client_id=${MicrosoftAppMSIClientId}&api-version=2019-08-01` with the `X-IDENTITY-HEADER: ${IDENTITY_HEADER}` header (per `bot.ts:141-149`).
2. **Exchanges** the MSI assertion at `https://login.microsoftonline.com/${MicrosoftAppTenantId}/oauth2/v2.0/token` via POST `application/x-www-form-urlencoded` with the form fields per `bot.ts:152-159` exactly: `grant_type=client_credentials`, `client_id=${MicrosoftAppId}`, `client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer`, `client_assertion=${step-1-token}`, `scope=https://api.botframework.com/.default`.
3. **Caches** the returned `{access_token, expires_in}` as `cachedToken = {token, expiresAt: Date.now() + expires_in * 1000}`; returns the cached token on subsequent calls until `Date.now() >= expiresAt - 60_000`.
4. **Returns null** when ANY of `MicrosoftAppMSIClientId`, `MicrosoftAppId`, `MicrosoftAppTenantId`, `IDENTITY_ENDPOINT`, `IDENTITY_HEADER` env vars is absent (local Playground path; per `bot.ts:131-139`).
5. **Throws `BotAuthError`** with body preview when MSI step fails non-2xx (per `bot.ts:147`).
6. **Throws `BotAuthError`** with body preview when AAD exchange fails non-2xx (per `bot.ts:166`).
7. **Is concurrency-safe**: simultaneous callers in the same process invoking `getBotToken()` while no cache is warm should result in a single MSI+AAD exchange (or two acceptable benign exchanges); they MUST NOT corrupt the `cachedToken` state. (m-relay-main does NOT lock here; the in-process behavior is "last writer wins" — acceptable per single-instance App Service.) v1 lifts this behavior; explicit lock-free concurrency assertion in test.
8. **Logs nothing sensitive**: token strings MUST NOT appear in logs; identity-endpoint URLs MAY be logged; error bodies are bounded preview only via the same convention as `BotConnectorError` (200-char ellipsis).

## Acceptance scenarios (7 items, exhaustively enumerated)

1. **(a) Cold cache → both steps run.** Test mocks fetch with two responses: MSI returns `{access_token: "msi-token-A"}`; AAD returns `{access_token: "bf-token-A", expires_in: 3600}`. Test invokes `getBotToken()`. Result: `"bf-token-A"`. Test asserts BOTH fetches happened in order, with the right URLs + bodies + headers.

2. **(b) Warm cache → no fetch.** After (a), test invokes `getBotToken()` again immediately. Result: `"bf-token-A"`. Test asserts NO additional fetch happened (mock fetch call count unchanged).

3. **(c) Near-expiry triggers refresh.** After (a), test fast-forwards mock clock to `expiresAt - 30_000` (within the 60s margin). `getBotToken()` triggers both steps again; mock returns `{access_token: "bf-token-B", expires_in: 3600}`. Result: `"bf-token-B"`. Test asserts a fresh fetch happened.

4. **(d) Missing env vars → returns null (Playground path).** Test runs with one of `MicrosoftAppMSIClientId` / `MicrosoftAppId` / `MicrosoftAppTenantId` / `IDENTITY_ENDPOINT` / `IDENTITY_HEADER` unset. `getBotToken()` returns `null` synchronously without any fetch call. Test asserts each missing-env-var case (5 sub-cases).

5. **(e) MSI step fails → `BotAuthError`.** Test mocks MSI fetch to return `{ok: false, status: 500, text: () => "Internal Server Error"}`. `getBotToken()` rejects with `BotAuthError` whose message contains `"Failed to get MSI assertion token: 500"`. AAD fetch is NOT called. Test asserts.

6. **(f) AAD exchange fails → `BotAuthError`.** Test mocks MSI ok, AAD `{ok: false, status: 401, text: () => "AADSTS70021"}`. `getBotToken()` rejects with `BotAuthError` whose message contains `"Failed to exchange token for Bot Framework: 401"`. Test asserts.

7. **(g) Concurrent callers do not corrupt cache.** Test invokes `Promise.all([getBotToken(), getBotToken(), getBotToken()])` against a cold cache. Mock fetch counts: at most 6 (3 callers × 2 steps each = max acceptable benign-redundant-exchange ceiling for the unlocked variant). All three resolve to a non-null token. Final `cachedToken` is internally consistent (`token + expiresAt` from the same response). Test asserts cache integrity post-race.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| `tests/node/F-208-msi-fic-token-mint.test.ts` | node | RED — module + `getBotToken` export does not exist; mock fetch + clock infrastructure absent | acceptance items (a)-(g); structural via `existsSync` + `import`; behavioral via mock fetch + fake clock (`vi.useFakeTimers()` or equivalent) |

## Dependencies

- **Hard:** F-205 (kit-bootstrap — fetch + clock-mock test infrastructure live; antipattern hooks live).
- **Hard cross-feature:** Required by F-207 (`getBotToken()` is invoked at the top of every outbound REST call). F-207 cannot pass acceptance without F-208 passing first OR a stub-token mode for the local Playground path.
- **Soft (BLOCKING for RED→GREEN):** F-D-008 teams-adapter re-open — F-208 has no production utility without an active Teams integration commitment.
- **Independent:** F-076 (MSAL user-context auth — different actor; coexists).
- **Cross-link:** F-018 failure-pattern-halt (consumes `BotAuthError` as a halt-trigger candidate; integration is follow-on).

## Lift contract

**Direct lift** of `m-relay-main/src/bot.ts:79-82,125-175` per Lane C audit. Adapter requirements:

- The `cachedToken` module-scoped state lifts verbatim (or moves to class-scoped if F-207 chose class-scoped state — pair them in the same shape).
- The `BotAuthError` typed exception is shared with F-207; declare in F-207's lift to avoid duplication.
- `IDENTITY_ENDPOINT` / `IDENTITY_HEADER` env-var reads are App Service Linux conventions; lift verbatim.
- The `URLSearchParams` form-encoding for the AAD POST is correct as-is; do not switch to JSON (AAD `/oauth2/v2.0/token` requires form encoding).
- The federated-credential binding lives in Azure (App Registration → Federated credentials → "AzureADTokenExchange" with subject = MSI principal id); F-208 covers the runtime token mint ONLY. Bicep / IaC for the federated credential binding is out of scope (Bicep work is M15 packaging or future infra).

## Surface trace

| surface-id | what it contributes |
|---|---|
| mr:m-relay-main/src/bot.ts:79-82 | `cachedToken` module-state shape `{token, expiresAt}` |
| mr:m-relay-main/src/bot.ts:125-175 | `getBotToken()` two-step MSI-FIC exchange flow |
| kit:rules/single-owner-accountability.md | Bot service-principal accountability; bot-token bound to the FIC binding's MSI principal |
| kit:rules/dangerous-operations-policy.md | Cross-org token exchange (App Service → AAD → Bot Framework) is a cross-org-egress surface; consent at deploy-time, not per-call |
| kit:rules/concurrency-safety.md | Token cache `{token, expiresAt}` mutation under concurrent callers; in-process unlocked acceptable |

## References

- `.mad/reports/mad-council-claw-audit-2026-05-07.md` (in `C:\Users\tonym\Repos\MAD - Clean`) — Lane C inventory.
- `m-relay-main/src/bot.ts:79-82,125-175` — direct source.
- `docs/03-feature-catalog/M9-m365/F-207-bot-connector-rest-jwt.md` — sibling, hard cross-feature consumer.
- `docs/03-feature-catalog/M19-deferred/F-D-008-teams-adapter.md` — soft-blocking re-open.
- `docs/03-feature-catalog/M0-bootstrap/F-205-kit-bootstrap.md` — hard-dep substrate.
- `.claude/rules/no-silent-deferrals.md` (in MAD - Clean kit).
