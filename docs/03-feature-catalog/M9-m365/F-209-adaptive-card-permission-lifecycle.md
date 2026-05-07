---
artifact-class: feature-ledger
generated-by: hand-authored (silent-deferral surfacing 2026-05-07)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: silent-deferral surfacing audit (.mad/reports/mad-council-claw-audit-2026-05-07.md in MAD - Clean kit)
    note: "Initial creation surfacing a silent-deferral. The Adaptive Card permission lifecycle (TTL + sweeper + Action.Execute + cross-device PUT refresh) at m-relay-main/src/relay.ts:73-74,95-101,339-418,554-566 + cards.ts:19-93 was inventoried in the 2026-05-07 audit (Lane C, agentId a762840e5a17233e0) but never tracked as an F-NNN — it is a precursor to F-D-008 teams-adapter re-open and the canonical example of a multi-device permission UX that does NOT require a custom Teams app surface. Per .claude/rules/no-silent-deferrals.md, surfacing here as F-209. Sibling ledgers F-206/F-207/F-208/F-210."
feature-id: F-209
short-slug: adaptive-card-permission-lifecycle
milestone: M9
provenance:
  surfaces:
    - mr:m-relay-main/src/cards.ts:19-93
    - mr:m-relay-main/src/cards.ts:95-159
    - mr:m-relay-main/src/relay.ts:73-74
    - mr:m-relay-main/src/relay.ts:95-101
    - mr:m-relay-main/src/relay.ts:339-418
    - mr:m-relay-main/src/bot.ts:521-583
    - mr:m-relay-main/src/protocol.ts:58-81
    - kit:rules/dangerous-operations-policy.md
    - kit:rules/concurrency-safety.md
fr-coverage: []
test-files:
  unit: []
  node:
    - tests/node/F-209-adaptive-card-permission-lifecycle.test.ts
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - node
red-green-rule: |
  RED   if ANY of the 11 acceptance items (a)-(k) below fails OR test file is missing OR runner returns non-zero exit.
  GREEN if ALL 11 acceptance items pass AND tests/node/F-209-adaptive-card-permission-lifecycle.test.ts exists AND runner returns zero exit.
  LOCKED if GREEN AND docs/05-design-reviews/council-reviews/F-209-adaptive-card-permission-lifecycle-review.md exists with verdict: ACCEPT (median confidence ≥ 80).
depends-on: [F-205, F-206, F-207, F-D-008-pending-reopen]
out-of-scope-notes: |
  Per .claude/rules/no-silent-deferrals.md, every adjacent surface NOT covered by this ledger is
  enumerated below with explicit rationale. None of these are silently dropped:

  1. **Adaptive Cards beyond permission cards** (e.g. result cards for arbitrary engine
     events, briefing cards, calendar cards) are OUT OF SCOPE for v1. F-209 covers ONLY the
     permission-request flow. Re-open trigger: a specific feature (e.g. F-101 daily-briefing
     when surfacing to Teams) that needs a non-permission card.
  2. **Card schema beyond Adaptive Cards 1.5** (e.g. Hero Card, Thumbnail Card, List Card,
     Universal Actions migration, Adaptive Cards 1.6+) is OUT OF SCOPE. v1 lifts the 1.5
     baseline from m-relay-main verbatim.
  3. **Card customization (icons, colors, branding)** beyond what `cards.ts:19-93` already
     emits is a UX polish concern; out of scope here.
  4. **Permission-cache integration on the desktop side** (the M7 perms-3-tier surface, F-058)
     consumes the WS `permission_response` message but lives downstream. F-209 covers ONLY
     the relay-side card lifecycle; the desktop-side cache (allow / allow_session /
     always_allow / deny semantics, persistence, expiry) is M7 scope.
  5. **Action.Submit fallback** for Teams clients that don't support Action.Execute — m-relay-main
     does NOT include a fallback (Action.Execute requires Teams 2.0+). v1 inherits the
     Action.Execute-only requirement.
  6. **Universal Actions back-end refresh model** (the Bot Framework's `refresh.action` field
     for auto-refreshing cards via bot) is OUT OF SCOPE; v1 uses the simpler PUT-on-resolve
     pattern from m-relay-main.
  7. **TTL configurability** — the 5-minute TTL (`PERMISSION_TTL_MS = 300_000`, `relay.ts:73`)
     and 1-minute sweep cadence (`PERMISSION_SWEEP_INTERVAL_MS = 60_000`, `relay.ts:74`) lift
     verbatim. Per-permission TTL or per-environment override is deferred.
  8. **TTL-expiry user notification** — when a permission expires, the desktop is NOT
     notified (`sweepExpiredPermissions` deletes silently; the user-facing card stays in
     Teams as stale). Surfacing expiry to the desktop OR refreshing the Teams card to
     "EXPIRED" state is a follow-on UX item.
  9. **Cross-tenant card delivery** — m-relay-main is single-tenant. Multi-tenant card
     routing is OUT OF SCOPE; tracked as a future scaling concern.
  10. **Card content sanitization** — the `title` / `message` / `command` strings are
     emitted into the card body verbatim. v1 inherits this, but downstream the content
     SHOULD pass through the kit's `prompt-injection-policy.md` Rule 1 substring scan
     before being trusted as data — that integration is follow-on, not in F-209 acceptance.
  11. **Audit-log emission of permission outcomes** to F-015 hash-chained-audit-log is a
     cross-link, not scoped here.
confidence: high
---

# F-209 — Adaptive Card permission lifecycle

## Rationale

`m-relay-main` solves a hard UX problem: how does a desktop AI agent prompt the user for permission (e.g. "calendar access requested") in a way that:

- Works across the user's connected devices (desktop AND Teams mobile, when they're checking Teams from a phone in a meeting),
- Auto-expires when the user doesn't respond within 5 minutes (the desktop's request times out),
- Shows the user's choice on every device after they tap a button on ONE device (cross-device card refresh).

The solution lives across four files:

- `m-relay-main/src/cards.ts:19-93` — `buildPermissionCard` builds the initial Adaptive Card with 4 `Action.Execute` buttons (`allow`, `allow_session`, `always_allow`, `deny`).
- `m-relay-main/src/cards.ts:95-159` — `buildPermissionResultCard` builds the post-resolution card (no buttons, shows `✅ Allowed` / `❌ Denied`).
- `m-relay-main/src/relay.ts:73-74,95-101,339-418` — TTL constants, sweep interval, in-memory `pendingPermissions` Map, store/get/resolve/delete lifecycle methods, `setPermissionActivityId` for cross-device PUT, `setPermissionConversation` for the exact endpoint stash.
- `m-relay-main/src/bot.ts:521-583` — invoke handler for `verb: "permission_respond"` that returns the result card inline (updates the invoking client) AND fires `updateCardActivity` PUT to fan-out to other devices.

This is the second-most-load-bearing primitive in m-relay-main after F-206 (the relay manager itself). Per `.mad/reports/mad-council-claw-audit-2026-05-07.md` Lane C: "Adaptive-Card permission lifecycle is the canonical example of how to do multi-device permission UX without a custom Teams app surface".

This ledger is RED on creation and **soft-blocked on F-D-008 teams-adapter re-open**. F-209 is meaningless without F-D-008 active.

## Behavior contract

The mad-council-claw engine MUST provide an Adaptive-Card permission lifecycle primitive that:

1. **Stores** a pending permission in an in-memory `Map<requestId, PendingPermission>` keyed by UUID v4 requestId, with `{userId, title, message, command, tooltips?, createdAt: Date.now(), activityId?, serviceUrl?, conversationId?}` (per `relay.ts:362-371`).
2. **Sends** a card via F-207's `sendCardReply` using the card built by `buildPermissionCard(requestId, title, message, command, tooltips?)` (per `cards.ts:19-93`); captures the returned `activityId`; stashes it via `setPermissionActivityId` AND stashes the `serviceUrl` + `conversationId` via `setPermissionConversation` (per `bot.ts:343-355`).
3. **Sweeps** expired entries every `PERMISSION_SWEEP_INTERVAL_MS = 60_000` ms via `sweepExpiredPermissions` (per `relay.ts:101`); an entry is expired when `Date.now() - createdAt > PERMISSION_TTL_MS = 300_000`.
4. **Returns undefined** from `getPermissionRequest(requestId)` for both expired entries (auto-deletes on read) AND missing entries (per `relay.ts:346-354`).
5. **Resolves** a permission on user action: `resolvePermission(requestId, action)` deletes the pending entry, sends `{type: "permission_response", requestId, action}` over WebSocket to the user's desktop client (per `relay.ts:400-418`).
6. **Emits the result card inline** in the Action.Execute response body via the `application/vnd.microsoft.card.adaptive` envelope shape — replaces the original card on the invoking Teams client (per `bot.ts:565-570`).
7. **Pushes the result card cross-device** via `updateCardActivity` PUT to `/v3/conversations/{id}/activities/{activityId}` for the user's other connected Teams clients — best-effort, NEVER throws, logs error on failure (per `bot.ts:579-583`, `bot.ts:284-321`).
8. **Falls back to `replyToId`** when `activityId` was not stashed in time (race between `sendCardReply` resolving and `setPermissionActivityId` running): `bot.ts:558-562` reads `activity.replyToId` from the invoke and uses it as the PUT target.
9. **Builds the 4 action buttons** with: `allow` (positive style), `allow_session` (default style, optional tooltip), `always_allow` (default style, optional tooltip), `deny` (destructive style) — per `cards.ts:62-90`.
10. **Builds the result card** with the `{icon, label}` lookup from `ACTION_LABELS` (`cards.ts:95-100`): `allow → ✅ Allowed`, `allow_session → ✅ Allowed for session`, `always_allow → ✅ Always allowed`, `deny → ❌ Denied`. No actions on the result card (it is finalized).
11. **Capability-gates** card-permission requests on `permission_cards` capability (per `relay.ts:154-160`): a desktop client without `permission_cards` in negotiated capabilities CANNOT request a card; the `permission_request` WS message from such a client is silently dropped.

## Acceptance scenarios (11 items, exhaustively enumerated)

1. **(a) `buildPermissionCard` emits the canonical 4-action shape.** Test invokes `buildPermissionCard("req-1", "Calendar Access", "Read your calendar", "calendar.readwrite")`. Asserts the returned `CardAttachment` has `contentType: "application/vnd.microsoft.card.adaptive"`, `content.actions` length 4, `content.actions[0].verb === "permission_respond"`, `content.actions[0].data === {requestId: "req-1", action: "allow"}`, similarly for the other 3 actions. Asserts `content.body[2].items[0].text === "calendar.readwrite"` (command in monospace block).

2. **(b) `buildPermissionCard` includes tooltips when supplied.** Test invokes with `tooltips: {"Allow for session": "Until app close", "Always allow": "Until you revoke"}`. Asserts `actions[1].tooltip === "Until app close"` AND `actions[2].tooltip === "Until you revoke"`.

3. **(c) `buildPermissionResultCard` for each action.** Test invokes `buildPermissionResultCard("Calendar Access", "Read your calendar", "calendar.readwrite", action)` for each of 4 actions. For `allow` → label "✅ Allowed"; `allow_session` → "✅ Allowed for session"; `always_allow` → "✅ Always allowed"; `deny` → "❌ Denied". Asserts `content.body[3].text` matches AND `content.actions` is undefined / empty (no buttons).

4. **(d) `storePendingPermission` + `getPermissionRequest` round-trip.** Test stores `("req-2", "user-A", "title", "msg", "cmd", undefined)`, then `getPermissionRequest("req-2")` returns `{userId: "user-A", title, message: "msg", command: "cmd", createdAt: <recent timestamp>}`. Test asserts.

5. **(e) `getPermissionRequest` returns undefined after TTL.** Test stores, fast-forwards mock clock by `PERMISSION_TTL_MS + 1ms`, then `getPermissionRequest` returns undefined AND the entry is removed from the internal Map (verified by a second `getPermissionRequest` returning undefined immediately).

6. **(f) `sweepExpiredPermissions` fires periodically and removes stale entries.** Test stores 3 entries at t=0, t=10s, t=200s. Fast-forwards to t=350s and triggers a sweep. Asserts only the 2 stale entries (t=0 + t=10s) are removed; the t=200s entry survives (350-200=150 < 300 TTL).

7. **(g) `setPermissionActivityId` + `setPermissionConversation` stash idempotently.** Test stores, then calls `setPermissionActivityId("req-3", "act-X")` and `setPermissionConversation("req-3", "https://smba.tm.net/", "conv-Y")`. `getPermissionRequest("req-3")` returns the entry with `activityId: "act-X"`, `serviceUrl: "https://smba.tm.net/"`, `conversationId: "conv-Y"`. Calling either setter on a non-existent or expired entry is a no-op (does not throw).

8. **(h) `resolvePermission` deletes the entry AND notifies the desktop over WS.** Test stores, mocks a connected WS client for the user, calls `resolvePermission("req-4", "allow")`. Asserts the entry is removed AND the WS client received `{type: "permission_response", requestId: "req-4", action: "allow"}`.

9. **(i) `resolvePermission` against expired/missing entry is a no-op.** Test calls `resolvePermission("nonexistent", "allow")`. No throw; no WS message sent.

10. **(j) Bot invoke handler returns inline result card AND fires PUT.** Test simulates an `invoke` activity with `value.action.verb === "permission_respond"`, `value.action.data === {requestId: "req-5", action: "deny"}`. Mocks the pending entry (with `activityId` + `serviceUrl` + `conversationId`). Test asserts: (1) HTTP response body is `{statusCode: 200, type: "application/vnd.microsoft.card.adaptive", value: <result card content>}`; (2) `updateCardActivity` was called with the stashed serviceUrl + conversationId + activityId + result card.

11. **(k) `replyToId` fallback when activityId was lost to a race.** Test simulates the invoke with `replyToId: "act-fallback"` AND a pending entry that has `activityId: undefined`. Test asserts `updateCardActivity` was called with `activityId: "act-fallback"` AND a console.log mentioning the fallback path fired (per `bot.ts:561`).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| `tests/node/F-209-adaptive-card-permission-lifecycle.test.ts` | node | RED — `cards.ts` + permission-lifecycle methods on `RelayManager` do not exist; mock fetch + clock infrastructure absent | acceptance items (a)-(k); structural via `existsSync` + `import`; behavioral via mock WS + mock fetch + fake clock |

## Dependencies

- **Hard:** F-205 (kit-bootstrap), F-206 (RelayManager substrate; `pendingPermissions` Map lives on RelayManager), F-207 (`sendCardReply` + `updateCardActivity` REST calls).
- **Soft (BLOCKING for RED→GREEN):** F-D-008 teams-adapter re-open.
- **Independent:** F-058 perms-3-tier (M7 desktop-side perms cache; F-209 emits the WS message; F-058 consumes it).
- **Cross-link:** F-015 hash-chained-audit-log (audit emission of permission resolutions; integration is follow-on).

## Lift contract

**Direct lift** of `m-relay-main/src/cards.ts` (entire file, ~160 LOC) and the permission-lifecycle additions on `RelayManager` from `relay.ts:73-74,95-101,339-418`. Adapter requirements:

- `cards.ts` lifts verbatim — pure functions building Adaptive Card JSON; no env-coupling, no platform-specific code.
- The `pendingPermissions` Map + `permissionSweepInterval` setInterval lift to `RelayManager` class verbatim (these are the surfaces F-206 stubbed).
- The `bot.ts` invoke handler at lines 521-583 lifts to the council-claw `BotHandler.handleMessage` `invoke` branch verbatim.
- The `PermissionAction` type from `m-relay-main/src/protocol.ts:59` (`"allow" | "allow_session" | "always_allow" | "deny"`) lifts as the canonical permission-action enum for council-claw v1.
- The Adaptive Cards `version: "1.5"` (initial card) and `version: "1.4"` (result card) constants lift verbatim — m-relay-main intentionally uses 1.4 for result cards for max compatibility (1.5 features only used in initial card's interactive surface).

## Surface trace

| surface-id | what it contributes |
|---|---|
| mr:m-relay-main/src/cards.ts:19-93 | `buildPermissionCard` — initial card with 4 Action.Execute buttons |
| mr:m-relay-main/src/cards.ts:95-159 | `buildPermissionResultCard` — finalized card (no buttons, action label) |
| mr:m-relay-main/src/relay.ts:73-74 | `PERMISSION_TTL_MS = 300_000` + `PERMISSION_SWEEP_INTERVAL_MS = 60_000` constants |
| mr:m-relay-main/src/relay.ts:95-101 | `pendingPermissions` Map declaration + setInterval sweep wiring in constructor |
| mr:m-relay-main/src/relay.ts:339-418 | `onPermissionRequest` / `getPermissionRequest` / `deletePendingPermission` / `storePendingPermission` / `setPermissionActivityId` / `setPermissionConversation` / `resolvePermission` lifecycle methods |
| mr:m-relay-main/src/bot.ts:521-583 | `invoke` activity handler for `permission_respond` verb; inline result card + cross-device PUT fan-out + replyToId fallback |
| mr:m-relay-main/src/protocol.ts:58-81 | `PermissionAction` enum + `PermissionRequestMessage` + `PermissionResponseMessage` types |
| kit:rules/dangerous-operations-policy.md | Permission card prompt is a consent gate; lifts the Category-table pattern |
| kit:rules/concurrency-safety.md | Permission Map mutation under sweep + invoke + WS-resolve; sweep is single-writer; invoke + resolve are user-keyed (lock-free) |

## References

- `.mad/reports/mad-council-claw-audit-2026-05-07.md` (in `C:\Users\tonym\Repos\MAD - Clean`) — Lane C inventory.
- `m-relay-main/src/cards.ts` (entire file) — direct source for card builders.
- `m-relay-main/src/relay.ts:73-74,95-101,339-418` — direct source for lifecycle.
- `m-relay-main/src/bot.ts:521-583` — direct source for invoke handler.
- `m-relay-main/src/protocol.ts:58-81` — direct source for permission-action types.
- `docs/03-feature-catalog/M9-m365/F-206-ws-relay-manager.md` — RelayManager substrate.
- `docs/03-feature-catalog/M9-m365/F-207-bot-connector-rest-jwt.md` — REST send/update primitives.
- `docs/03-feature-catalog/M19-deferred/F-D-008-teams-adapter.md` — soft-blocking re-open.
- `docs/03-feature-catalog/M0-bootstrap/F-205-kit-bootstrap.md` — hard-dep substrate.
- `.claude/rules/no-silent-deferrals.md` (in MAD - Clean kit).
