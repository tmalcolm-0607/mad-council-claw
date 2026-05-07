---
artifact-class: feature-ledger
generated-by: hand-authored (silent-deferral surfacing 2026-05-07)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: silent-deferral surfacing audit (.mad/reports/mad-council-claw-audit-2026-05-07.md in MAD - Clean kit)
    note: "Initial creation surfacing a silent-deferral. The Bot Connector REST + JWT validation surface at m-relay-main/src/bot.ts:33-321 was inventoried in the 2026-05-07 audit (Lane C, agentId a762840e5a17233e0) but never tracked as an F-NNN — it is a precursor to F-D-008 teams-adapter re-open. Per .claude/rules/no-silent-deferrals.md, surfacing here as F-207. Sibling ledgers F-206/F-208/F-209/F-210. This ledger covers the inbound Bot Framework JWT validation (jose JWKS-based) AND the outbound Bot Connector REST client (send reply / send card / send typing / update card activity) ONLY; the MSI-FIC token mint that backs the outbound auth is its own ledger F-208."
feature-id: F-207
short-slug: bot-connector-rest-jwt
milestone: M9
provenance:
  surfaces:
    - mr:m-relay-main/src/bot.ts:33-77
    - mr:m-relay-main/src/bot.ts:177-321
    - mr:m-relay-main/package.json (jose ^6.1.3)
    - kit:rules/prompt-injection-policy.md
    - kit:rules/dangerous-operations-policy.md
fr-coverage: []
test-files:
  unit: []
  node:
    - tests/node/F-207-bot-connector-rest-jwt.test.ts
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - node
red-green-rule: |
  RED   if ANY of the 8 acceptance items (a)-(h) below fails OR test file is missing OR runner returns non-zero exit.
  GREEN if ALL 8 acceptance items pass AND tests/node/F-207-bot-connector-rest-jwt.test.ts exists AND runner returns zero exit.
  LOCKED if GREEN AND docs/05-design-reviews/council-reviews/F-207-bot-connector-rest-jwt-review.md exists with verdict: ACCEPT (median confidence ≥ 80).
depends-on: [F-205, F-D-008-pending-reopen]
out-of-scope-notes: |
  Per .claude/rules/no-silent-deferrals.md, every adjacent surface NOT covered by this ledger is
  enumerated below with explicit rationale. None of these are silently dropped:

  1. **MSI-FIC token mint (`bot.ts:125-175`)** is its own ledger F-208 msi-fic-token-mint.
     F-207 covers JWT validation (inbound) + REST send/update (outbound assuming a token
     is already obtainable); the token-acquisition flow itself is F-208.
  2. **Adaptive Card construction (`cards.ts`)** is its own ledger F-209
     adaptive-card-permission-lifecycle. F-207 covers `sendCardReply` (the REST POST that
     delivers an arbitrary `CardAttachment` payload); the card builders + Action.Execute
     verb routing + result-card replacement on user response are F-209.
  3. **Conversation-ref Map persistence** is F-210; F-207's `handleProactive` path uses
     the relay's `getConversationRef(userId)` accessor but does NOT own the persistence.
  4. **`handleMessage` activity-routing dispatch (`bot.ts:422-617`)** that consumes
     `Activity.type === "message" | "invoke" | "conversationUpdate"` is partially in
     F-207 scope (the `message` and `conversationUpdate` paths) and partially in F-209
     (the `invoke` permission_respond path). The split is documented per-acceptance-item.
  5. **Single-tenant vs multi-tenant issuer list (`bot.ts:62-67`)** — single-tenant only
     for v1 per m-relay-main baseline. Multi-tenant issuer + tenant-discovery is deferred.
     Re-open trigger: explicit multi-tenant deployment requirement.
  6. **Bot Framework Activity Protocol replacement** (the F-D-018 deferred surface) is
     OUT OF SCOPE; v1 lifts the existing `/v3/conversations` REST surface as-is. If the
     user re-opens F-D-018, F-207 may be partially superseded; track via re-open trigger.
  7. **`m-relay-main/src/log-safe.ts` (`hashUserId`, `errLabel`)** is referenced verbatim
     by `bot.ts` for diagnostic output. Lift the helper module 1:1 in the same commit
     that lands F-207's GREEN; not a separate F-NNN (helper-module scope).
  8. **OpenID metadata cache invalidation** — `getBotFrameworkJWKS` caches `jwks` for
     process lifetime (`bot.ts:37,40-44`). On JWKS rotation Bot Framework can return 401;
     manual restart is the recovery path in m-relay-main. Cache-rotation handling is a
     follow-on hardening item; out of scope here.
confidence: high
---

# F-207 — Bot Connector REST + JWT validation

## Rationale

`m-relay-main/src/bot.ts:33-321` implements two interlocking surfaces:

- **Inbound JWT validation (`bot.ts:33-77`)**: `validateBotFrameworkToken(authHeader, appId)` uses `jose` (`createRemoteJWKSet` + `jwtVerify`) against `https://login.botframework.com/v1/.well-known/openidconfiguration` to verify each incoming Activity from Azure Bot Service. Validates issuer (`https://api.botframework.com` OR tenant-specific `https://login.microsoftonline.com/{tenant}/v2.0` OR `https://sts.windows.net/{tenant}/`) and audience (the bot's `MicrosoftAppId`).

- **Outbound REST client (`bot.ts:177-321`)**: `sendReply`, `sendCardReply`, `sendTyping`, `updateCardActivity` all POST/PUT to the Bot Connector `/v3/conversations/{id}/activities[/{activityId}]` REST surface, attaching the Bot Framework token from F-208's mint. Returns the `activityId` (used by F-209 for cross-device card updates).

These two surfaces are the load-bearing primitive that makes a Bot Framework integration actually work — without inbound validation, the relay accepts forged Bot activities (Spoofing per `kit:rules/stride-threat-model.md` Category 1); without outbound REST, the desktop's response cannot reach Teams (Azure Bot Service does not forward inline HTTP response bodies).

Per `.mad/reports/mad-council-claw-audit-2026-05-07.md` Lane C § "Lift surface — m-relay-main": this is one of 5 high-value lift candidates. F-207 is the second of the 5 lift ledgers (F-206 first; F-208/F-209/F-210 follow).

## Behavior contract

The mad-council-claw engine MUST provide a Bot Connector REST + JWT validation primitive that:

1. **Validates** every inbound `POST /api/messages` Authorization header against the Bot Framework JWKS, issuer set, and audience claim BEFORE acting on the activity body.
2. **Caches** the JWKS (process-lifetime; `let jwks: ReturnType<typeof createRemoteJWKSet> | null = null` per `bot.ts:37`); first call lazy-initializes from the OpenID metadata URL.
3. **Posts** a text reply via `POST {serviceUrl}/v3/conversations/{conversationId}/activities` with `{type: "message", text}` body and `Authorization: Bearer <bot-fw-token>` header (per `bot.ts:177-203`).
4. **Posts** a card reply via the same endpoint with `{type: "message", text?, attachments: [{contentType, content}]}` body; returns the activity `id` from response JSON (per `bot.ts:206-251`).
5. **Posts** a typing indicator best-effort (no error propagation) via the same endpoint with `{type: "typing"}` body (per `bot.ts:253-268`).
6. **Updates** an existing card activity via `PUT {serviceUrl}/v3/conversations/{id}/activities/{activityId}` with the new card payload; logs error on failure but does NOT throw (cross-device update is best-effort) (per `bot.ts:284-321`).
7. **Wraps** REST failures in typed exceptions: `BotConnectorError(operation, status, statusText, bodyPreview)` for non-2xx responses; `BotAuthError` for token-acquisition failures (per `bot.ts:82-103`).
8. **Skips** outbound auth when `MicrosoftAppMSIClientId` / `MicrosoftAppId` / `MicrosoftAppTenantId` / `IDENTITY_ENDPOINT` / `IDENTITY_HEADER` env vars are absent (per `bot.ts:131-139`) — this is the local-Playground path; production Azure runs always have all five env vars set.

## Acceptance scenarios (8 items, exhaustively enumerated)

1. **(a) Valid Bot Framework token → activity accepted.** Test signs a fake JWT against a test JWKS with the expected issuer + audience and POSTs to `/api/messages`. The handler's `validateBotFrameworkToken` returns true; the activity proceeds to dispatch. Test asserts the dispatch ran (e.g., a mock `relay.sendToDesktop` was called).

2. **(b) Missing Bearer token → reject 401.** Test POSTs with no `Authorization` header; handler returns 401 `{error: "Unauthorized"}`. Test asserts response status + body.

3. **(c) Wrong audience → reject 401.** Test signs a JWT with `audience: "wrong-app-id"`; handler returns 401. Test asserts `validateBotFrameworkToken` returns false AND the dispatch did NOT run.

4. **(d) Wrong issuer → reject 401.** Test signs a JWT with `issuer: "https://attacker.example.com"`; handler returns 401. Test asserts rejection.

5. **(e) Outbound `sendReply` builds correct URL + headers.** Test invokes `sendReply("https://smba.trafficmanager.net/", "convId-123", "hello")` against a mock fetch. Test asserts the fetch URL is `https://smba.trafficmanager.net/v3/conversations/convId-123/activities`, body is `{"type":"message","text":"hello"}`, header `Content-Type: application/json` AND `Authorization: Bearer <token>` are present.

6. **(f) Outbound `sendCardReply` returns activityId.** Test invokes against a mock fetch that returns `{"id":"act-789"}`; the call resolves to `"act-789"`. If the mock returns `{}`, the call rejects with "Bot Connector card reply missing activityId". Test asserts both branches.

7. **(g) Non-2xx outbound → `BotConnectorError`.** Test mocks fetch to return `{status: 403, statusText: "Forbidden", text: () => "missing scope"}`. `sendReply` rejects with `BotConnectorError("reply", 403, "Forbidden", "missing scope")`. Test asserts the error is instance-of BotConnectorError AND fields match.

8. **(h) Trailing slashes in `serviceUrl` are normalized.** Test invokes `sendReply("https://smba.trafficmanager.net///", "c", "t")`. The fetch URL is exactly one slash before `v3/` — i.e. `https://smba.trafficmanager.net/v3/conversations/c/activities`. Test asserts URL normalization (per `bot.ts:179` `serviceUrl.replace(/\/+$/, "")`).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| `tests/node/F-207-bot-connector-rest-jwt.test.ts` | node | RED — module does not exist; jose import fails; mock fetch infrastructure absent | acceptance items (a)-(h); structural via `existsSync` + `import`; behavioral via mock JWKS server + mock fetch instrumented at module boundary |

## Dependencies

- **Hard:** F-205 (kit-bootstrap — `jose` and `node-fetch`-equivalent runtime must be present per kit baseline; antipattern hooks live).
- **Hard cross-feature:** F-208 (MSI-FIC token mint — `getBotToken()` is invoked by `sendReply`/`sendCardReply`/`sendTyping`/`updateCardActivity`; without F-208, every outbound call returns null token and the local-Playground path is the only working route).
- **Soft (BLOCKING for RED→GREEN):** F-D-008 teams-adapter re-open — this surface is meaningless without an active commitment to ship Teams integration.
- **Independent:** F-209 cards.ts (built atop F-207 `sendCardReply`), F-210 conversation-ref-atomic-persist (consumed by F-207's `handleProactive` REST handler).

## Lift contract

**Direct lift** of `m-relay-main/src/bot.ts:33-321` per Lane C audit. Adapter requirements:

- Replace top-level `let cachedToken` and `let jwks` module-scoped state with a class-scoped state IF the kit favors single-instance composition; alternative is to keep module-scoped (matches m-relay-main).
- Inbound: keep the `jose` JWKS verification verbatim. The `OPENID_METADATA_URL` constant lifts unchanged.
- Outbound: `sendReply` / `sendCardReply` / `sendTyping` / `updateCardActivity` lift verbatim. The `BotConnectorError` / `BotAuthError` typed exceptions lift verbatim into `packages/engine-relay/errors.ts` or equivalent.
- The `errLabel` / `hashUserId` log helpers from `m-relay-main/src/log-safe.ts` lift in the same commit (helper module).

The `handleMessage` Express handler at `bot.ts:422-617` is partially F-207 scope (the validation gate at lines 425-435; the `message` activity dispatch at 468-520; the `conversationUpdate` welcome at 584-602). The `invoke` permission_respond path at 521-583 is F-209 scope; the `BotHandler` class skeleton (constructor at 323-356) lifts here.

## Surface trace

| surface-id | what it contributes |
|---|---|
| mr:m-relay-main/src/bot.ts:33-77 | `validateBotFrameworkToken` + `getBotFrameworkJWKS`; jose JWKS validation pattern |
| mr:m-relay-main/src/bot.ts:82-103 | `BotAuthError` + `BotConnectorError` typed exception shape |
| mr:m-relay-main/src/bot.ts:177-251 | `sendReply` + `sendCardReply` REST orchestration; activity-id capture |
| mr:m-relay-main/src/bot.ts:253-321 | `sendTyping` (best-effort) + `updateCardActivity` (PUT, best-effort) |
| mr:m-relay-main/package.json | `jose ^6.1.3` runtime dep version pin |
| kit:rules/prompt-injection-policy.md | Bot activity bodies are external content; treat as data, validate JWT before consuming |
| kit:rules/dangerous-operations-policy.md | Outbound REST to a third-party endpoint is a side-effect surface; consent gates fire on cross-org dispatch |

## References

- `.mad/reports/mad-council-claw-audit-2026-05-07.md` (in `C:\Users\tonym\Repos\MAD - Clean`) — Lane C inventory.
- `m-relay-main/src/bot.ts:33-321` — direct source.
- `m-relay-main/package.json:23` — `jose ^6.1.3`.
- `docs/03-feature-catalog/M19-deferred/F-D-008-teams-adapter.md` — soft-blocking re-open.
- `docs/03-feature-catalog/M0-bootstrap/F-205-kit-bootstrap.md` — hard-dep substrate.
- `docs/03-feature-catalog/M9-m365/F-208-msi-fic-token-mint.md` — sibling, hard cross-feature dep.
- `.claude/rules/no-silent-deferrals.md` (in MAD - Clean kit).
