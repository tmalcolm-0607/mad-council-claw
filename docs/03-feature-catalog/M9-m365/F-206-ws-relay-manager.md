---
artifact-class: feature-ledger
generated-by: hand-authored (silent-deferral surfacing 2026-05-07)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: silent-deferral surfacing audit (.mad/reports/mad-council-claw-audit-2026-05-07.md in MAD - Clean kit)
    note: "Initial creation surfacing a silent-deferral. The m-relay-main reference repo was inventoried in the 2026-05-07 audit (Lane C, agentId a762840e5a17233e0) but never cited anywhere in mad-council-claw/docs/ pre-this-commit (zero grep matches). Per .claude/rules/no-silent-deferrals.md, an ungrounded reference repo containing 5 lift-eligible surfaces is the silent-deferral pattern. Surfaced as F-206 (first available beyond F-205 kit-bootstrap) at user instruction. Ledger covers the WebSocket relay manager surface only — the per-user connection map + pending-request correlation + rate limit + capability negotiation patterns at m-relay-main/src/relay.ts:84-235. Sibling ledgers F-207..F-210 cover bot-connector REST + JWT, MSI-FIC token mint, Adaptive-Card permission lifecycle, and conversation-ref atomic-persist. Each is a precursor to F-D-008 teams-adapter re-open."
feature-id: F-206
short-slug: ws-relay-manager
milestone: M9
provenance:
  surfaces:
    - mr:m-relay-main/src/relay.ts:84-235
    - mr:m-relay-main/src/protocol.ts:1-111
    - mr:m-relay-main/package.json (ws ^8.18.0)
    - kit:rules/concurrency-safety.md
    - kit:rules/single-owner-accountability.md
fr-coverage: []
test-files:
  unit: []
  node:
    - tests/node/F-206-ws-relay-manager.test.ts
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - node
red-green-rule: |
  RED   if ANY of the 9 acceptance items (a)-(i) below fails OR test file is missing OR runner returns non-zero exit.
  GREEN if ALL 9 acceptance items pass AND tests/node/F-206-ws-relay-manager.test.ts exists AND runner returns zero exit.
  LOCKED if GREEN AND docs/05-design-reviews/council-reviews/F-206-ws-relay-manager-review.md exists with verdict: ACCEPT (median confidence ≥ 80).
depends-on: [F-205, F-D-008-pending-reopen]
out-of-scope-notes: |
  Per .claude/rules/no-silent-deferrals.md, every adjacent surface NOT covered by this ledger is
  enumerated below with explicit rationale. None of these are silently dropped — each requires
  user discussion before promotion, and each will be tracked via its own F-NNN when promoted:

  1. **Token validation via Microsoft Graph (`relay.ts:420-474` handleAuth)** is covered by F-207
     bot-connector-rest-jwt's auth surface — the relay manager's `handleAuth` performs a
     Graph `/me` call and that path is referenced from F-207 as the inbound-validation pair
     to F-207's outbound Bot Framework JWT validation. Cross-ref but not duplicate.
  2. **Conversation-ref persistence (`relay.ts:262-331`)** is its own ledger F-210
     conversation-ref-atomic-persist. F-206 covers in-memory client + pendingRequests Maps
     only; disk persistence is F-210.
  3. **Permission card flow (`relay.ts:73-74,95-101,339-418,554-566`)** is its own ledger F-209
     adaptive-card-permission-lifecycle. F-206 covers the WebSocket transport + capability
     negotiation that gates the `permission_cards` capability; the actual TTL + sweeper +
     Action.Execute lifecycle is F-209.
  4. **Bot Connector REST (`bot.ts:177-321`)** is its own ledger F-207. F-206 covers the
     in-process channel between the Teams handler and the desktop app over WebSocket;
     the outbound REST that delivers the desktop's reply back to Teams is F-207.
  5. **Multi-relay clustering / horizontal scale-out** is OUT OF SCOPE for v1. m-relay-main
     is single-instance App Service Linux; m-council-claw v1 follows the same shape. Multi-
     instance routing (sticky sessions, Service Bus fan-out, Cosmos session state) is a
     v1.5+ scaling concern. Re-open trigger: when active concurrent users exceed an instance
     scale-out threshold.
  6. **WSS / TLS termination** is App Service responsibility (TLS terminates at the front
     door). v1 inherits that posture. BYO-cert or self-hosted WSS is deferred to packaging
     M15.
  7. **Cross-tenant routing** (a relay serving multiple tenants) is OUT OF SCOPE; v1 is
     single-tenant per the m-relay-main baseline. Re-open trigger: explicit multi-tenant
     deployment requirement from the user.
  8. **Reconnection / exponential backoff on the desktop client side** is the desktop
     responsibility (M5 desktop-shell or M9 sibling client lib); F-206 is the server side.
  9. **Audit-log emission of relay events (auth success/failure, rate-limit hits,
     timeouts)** to F-015 hash-chained-audit-log is a follow-on integration. Captured in
     §Surface trace as a future cross-link, not scoped here.
confidence: high
---

# F-206 — WebSocket relay manager

## Rationale

`m-relay-main/src/relay.ts:84-235` implements the `RelayManager` class — the load-bearing primitive that bridges Microsoft Teams Bot Framework activities to a user's running desktop instance over WebSocket. The relay maintains four in-memory Maps (`clients`, `pendingRequests`, `rateCounts`, `conversationRefs`) and orchestrates request/response correlation by `requestId` (UUID v4). This is the ONLY surface in the m-relay-main codebase that the audit (`.mad/reports/mad-council-claw-audit-2026-05-07.md` § Lift surface) classified as "directly liftable" without adapter — every other surface (bot.ts, cards.ts, conversation-refs) depends on this manager.

Per audit Decision 3: "add m-relay-main as tracked reference repo + lift the WS relay surface" — F-206 is the first of the 5 lift ledgers spawned from that decision. Per `.claude/rules/no-silent-deferrals.md`, the m-relay-main repo's invisibility in mad-council-claw (zero grep matches pre-this-commit) IS the silent-deferral pattern; F-206 surfaces it.

This ledger is RED on creation and **soft-blocked on F-D-008 teams-adapter re-open**. The depend-on relation is intentional: a Teams relay manager makes no sense without an active decision to ship Teams integration. F-D-008 is currently DEFERRED (status: deferred); F-206 RED→GREEN flip cannot happen until F-D-008 transitions to RED via the documented re-open protocol (`docs/03-feature-catalog/M19-deferred/F-D-008-teams-adapter.md:47-55`).

## Behavior contract

The mad-council-claw engine MUST provide a `RelayManager` primitive that:

1. Accepts WebSocket client connections on a configurable path (default `/ws`).
2. Authenticates each client within 10 seconds of connect via a token-bearing `auth` message; closes with code 4001 on timeout, 4002 on invalid JSON, 4003 on auth failure (per `m-relay-main/src/relay.ts:113-117,122-125,137`).
3. Negotiates capabilities via intersection of client-declared and server-supported (`SUPPORTED_CAPABILITIES` set); replies with `auth_ok` carrying the negotiated set (per `relay.ts:451-468`).
4. Maintains a per-user (Azure AD `oid`) client map (`Map<string, ConnectedClient>`); replaces an existing connection for the same user with WS close code 4004 "Replaced by new connection" (per `relay.ts:445-449`).
5. Correlates outbound requests to inbound responses via UUID v4 `requestId` in a `pendingRequests` Map; resolves the promise on `response` message arrival; rejects on `RESPONSE_TIMEOUT_MS` (5 minutes, per `relay.ts:70`); rejects with `OFFLINE` if no live client exists; rejects with `RATE_LIMITED` if a per-user rate budget is exhausted (per `relay.ts:192-235`).
6. Enforces a per-user rate limit of `RATE_LIMIT_PER_MINUTE = 100` messages (per `relay.ts:72`), keyed by user `oid` with a sliding 60-second window.
7. Issues keepalive pings every `PING_INTERVAL_MS = 30_000` to all connected clients (per `relay.ts:71,180-188`); accepts `pong` messages and updates `lastSeen` timestamp.
8. Exposes `isOnline(userId)`, `getStats()` (returns `{connectedClients, pendingRequests}`), and `shutdown()` lifecycle methods (per `relay.ts:237-259`).
9. Cleanly tears down on `shutdown()`: clears `pingInterval`, clears `permissionSweepInterval`, closes the WebSocketServer, rejects every pending request with "Server shutting down" (per `relay.ts:251-259`).

## Acceptance scenarios (9 items, exhaustively enumerated)

1. **(a) Client authenticates via valid token within 10s.** A WS client connects, sends `{type: "auth", userId, token, capabilities: ["permission_cards"]}` within 10 seconds. The manager validates the token (mock or real Graph `/me`), enters the client into `clients` Map keyed by Azure AD `oid`, replies with `auth_ok` carrying the negotiated capability set. Test asserts `isOnline(oid)` returns true.

2. **(b) Client misses auth window → close code 4001.** A WS client connects but sends no `auth` message; the manager closes the connection with WS code 4001 "Authentication timeout" after 10 seconds. Test asserts the close event fires with the expected code.

3. **(c) Invalid JSON → close code 4002.** A WS client sends raw bytes that fail `JSON.parse`; the manager closes with code 4002 "Invalid JSON". Test asserts close code.

4. **(d) Auth failure → close code 4003.** A WS client sends an `auth` message whose token validation returns null/false; the manager closes with code 4003 "Authentication failed". Test asserts close code AND the client is NOT in the `clients` Map.

5. **(e) Replacement connection → close code 4004 on prior.** With user U1 already connected, a second WS client sends an `auth` message for the same `oid`. The manager closes the prior connection with code 4004 "Replaced by new connection" and stores the new connection in the `clients` Map. Test asserts both: prior-close fires with 4004 AND `clients.get(U1).ws` is the new socket.

6. **(f) Capability negotiation respects intersection.** A client declares `capabilities: ["permission_cards", "video_call"]`. The manager's `SUPPORTED_CAPABILITIES = new Set(["permission_cards"])`. The `auth_ok` response carries `capabilities: ["permission_cards"]` only. Test asserts `video_call` is filtered out.

7. **(g) Request/response correlation by `requestId`.** `sendToDesktop(userId, "hello world")` is invoked. The manager generates a UUID requestId, sends `{type: "message", requestId, text: "hello world", userId}` to the WS client. The test client replies `{type: "response", requestId, text: "hi back", done: true}`. The promise resolves to "hi back". Test asserts `getStats().pendingRequests` is 0 after resolution.

8. **(h) Rate limit triggers `RATE_LIMITED` rejection.** A test connects user U1 and sends 101 requests within 60s. The 101st `sendToDesktop` rejects with `Error("RATE_LIMITED")`. Test asserts the first 100 enqueue successfully (or are bounded as designed) and the 101st fails with the expected reason.

9. **(i) `shutdown()` cleanly tears down.** Test connects 3 clients with 2 in-flight pending requests, then calls `shutdown()`. The 2 pending requests reject with `Error("Server shutting down")`, the WebSocketServer closes, `pingInterval` and `permissionSweepInterval` are cleared (no leaked timers detectable by Node `process._getActiveHandles()` count delta). Test asserts pendingRequest rejection AND zero leaked timers.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| `tests/node/F-206-ws-relay-manager.test.ts` | node | RED — `RelayManager` class does not exist; structural assertions on file path / class export fail; behavior assertions skipped | acceptance items (a)-(i); structural via `existsSync` + `import` + WS client probe; behavioral via in-process WS server + `ws` client |

## Dependencies

- **Hard:** F-205 (kit-bootstrap — antipattern hooks must be live before this ledger's RED test author work begins; the test file lives under `tests/node/` per kit conventions).
- **Soft (BLOCKING for RED→GREEN):** F-D-008 teams-adapter re-open per audit Decision 1. The relay manager is meaningless without an active commitment to ship Teams integration. F-D-008 currently DEFERRED; this ledger STAYS RED until F-D-008 transitions to RED.
- **Independent:** F-009 (IBackendProvider — orthogonal; relay is transport, backend is model).
- **Cross-link:** F-207 (bot.ts auth pair via Graph `/me`), F-208 (MSI-FIC token mint, used when relay's bot pair sends replies), F-209 (permission-card lifecycle uses relay capability negotiation), F-210 (conversation-ref atomic-persist; relay is the read/write owner).

## Lift contract

**Direct lift** per Lane C audit § "Reuse contracts" — `m-relay-main/src/relay.ts:84-235` is structurally TypeScript-compatible with mad-council-claw's `packages/engine-core/` workspace. Adapter requirements:

- Replace `import { Server } from "http"` with the engine's IPC scaffold (F-007) where appropriate, OR keep raw `http` if the relay is its own process.
- Replace `console.log/warn/error` with the engine's structured logger (F-006) — direct call-site swap.
- The `process.env.WEBSITE_SITE_NAME` / `WEBSITE_INSTANCE_ID` checks are App Service Linux conditionals; lift verbatim if council-claw runs on App Service, swap for kit-generic environment detection if it runs elsewhere.
- The `loadConversationRefs` / `persistConversationRefs` calls are F-210 scope; in F-206 these are stubs that no-op until F-210 lands.
- The `permissionSweepInterval` / `sweepExpiredPermissions` calls are F-209 scope; F-206 stubs them.

No ports / protocol changes; the WebSocket message contract in `m-relay-main/src/protocol.ts:1-111` lifts as-is into a council-claw `packages/engine-relay/protocol.ts` or equivalent. Discrete-union `RelayMessage` type stays.

## Surface trace

| surface-id | what it contributes |
|---|---|
| mr:m-relay-main/src/relay.ts:84-235 | `RelayManager` class, in-memory client + pendingRequests Maps, capability negotiation, rate limit, request/response correlation, lifecycle |
| mr:m-relay-main/src/protocol.ts:1-111 | TS message contracts (AuthMessage, IncomingMessage, ResponseMessage, TypingMessage, ProactiveMessage, PingMessage, PongMessage, ErrorMessage); discriminated `RelayMessage` union |
| mr:m-relay-main/package.json | `ws ^8.18.0` runtime dep version pin |
| kit:rules/concurrency-safety.md | Map mutation ordering rules (single-writer per key); informs the per-user lock-free design (Maps are partitioned by `oid`) |
| kit:rules/single-owner-accountability.md | session_id ↔ alias binding pattern; relay's `oid`-keyed Maps follow the same ownership discipline |

## References

- `.mad/reports/mad-council-claw-audit-2026-05-07.md` (in `C:\Users\tonym\Repos\MAD - Clean`) — Lane C inventory + § "Lift surface — m-relay-main" + Decision 3.
- `m-relay-main/src/relay.ts:84-235` — direct source for the lift contract.
- `m-relay-main/src/protocol.ts:1-111` — message-type union.
- `m-relay-main/package.json:24` — `ws ^8.18.0` version baseline.
- `docs/03-feature-catalog/M19-deferred/F-D-008-teams-adapter.md:47-55` — re-open trigger protocol.
- `docs/03-feature-catalog/M0-bootstrap/F-205-kit-bootstrap.md` — hard-dep substrate.
- `.claude/rules/no-silent-deferrals.md` (in MAD - Clean kit) — the rule that mandates surfacing this lift.
- `docs/01-requirements/glossary.md` reference-repos block (m-relay-main entry added 2026-05-07 same commit).
