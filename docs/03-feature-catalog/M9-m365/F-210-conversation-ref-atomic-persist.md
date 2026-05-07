---
artifact-class: feature-ledger
generated-by: hand-authored (silent-deferral surfacing 2026-05-07)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: silent-deferral surfacing audit (.mad/reports/mad-council-claw-audit-2026-05-07.md in MAD - Clean kit)
    note: "Initial creation surfacing a silent-deferral. The conversation-ref persistence pattern at m-relay-main/src/relay.ts:262-331 was inventoried in the 2026-05-07 audit (Lane C, agentId a762840e5a17233e0) but never tracked as an F-NNN — it is a precursor to F-D-008 teams-adapter re-open AND an example of pragmatic single-instance file-backed state under App Service Linux's /home/data persistent-mount constraint. Per .claude/rules/no-silent-deferrals.md, surfacing here as F-210. Sibling ledgers F-206/F-207/F-208/F-209."
feature-id: F-210
short-slug: conversation-ref-atomic-persist
milestone: M9
provenance:
  surfaces:
    - mr:m-relay-main/src/relay.ts:48-68
    - mr:m-relay-main/src/relay.ts:79-82
    - mr:m-relay-main/src/relay.ts:88
    - mr:m-relay-main/src/relay.ts:98-99
    - mr:m-relay-main/src/relay.ts:262-331
    - mr:m-relay-main/src/bot.ts:323-355
    - mr:m-relay-main/src/bot.ts:438-462
    - mr:m-relay-main/src/log-safe.ts (hashUserId)
    - kit:rules/concurrency-safety.md
    - kit:rules/single-owner-accountability.md
fr-coverage: []
test-files:
  unit: []
  node:
    - tests/node/F-210-conversation-ref-atomic-persist.test.ts
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - node
red-green-rule: |
  RED   if ANY of the 9 acceptance items (a)-(i) below fails OR test file is missing OR runner returns non-zero exit.
  GREEN if ALL 9 acceptance items pass AND tests/node/F-210-conversation-ref-atomic-persist.test.ts exists AND runner returns zero exit.
  LOCKED if GREEN AND docs/05-design-reviews/council-reviews/F-210-conversation-ref-atomic-persist-review.md exists with verdict: ACCEPT (median confidence ≥ 80).
depends-on: [F-205, F-206, F-D-008-pending-reopen]
out-of-scope-notes: |
  Per .claude/rules/no-silent-deferrals.md, every adjacent surface NOT covered by this ledger is
  enumerated below with explicit rationale. None of these are silently dropped:

  1. **Cross-instance / horizontal scale-out persistence** (Service Bus, Cosmos, Redis,
     SQL) is OUT OF SCOPE for v1. m-relay-main is single-instance App Service Linux;
     v1 inherits that. Re-open trigger: scale-out load requirement.
  2. **Atomic write-temp-then-rename** (per `.claude/rules/concurrency-safety.md` §2) is
     RECOMMENDED but m-relay-main currently uses a direct `writeFileSync` (per `relay.ts:327`).
     v1 lifts the m-relay-main shape AS-IS for parity, BUT the council-review verdict on
     F-210 GREEN→LOCKED SHOULD challenge this and either justify the direct write OR
     promote a tmp-then-rename improvement before LOCKED. Documented as a hardening item
     per audit.
  3. **Encryption at rest** for `conversation-refs.json` is OUT OF SCOPE; the file holds
     `(userId, conversationId, serviceUrl)` tuples — not secrets, but identifiers tied to
     Azure AD `oid`. v1 inherits the cleartext-on-disk shape from m-relay-main. F-070
     encrypted-storage (M8) MAY consume conversation-refs as a candidate after F-210 GREEN.
  4. **Schema migration** for the conversation-refs file format is OUT OF SCOPE; v1 lifts
     the `Array<[string, ConversationRef]>` shape from m-relay-main verbatim. If the
     shape changes, F-D-005 schema-migration applies.
  5. **TTL / expiry on conversation-refs** is OUT OF SCOPE; m-relay-main retains refs
     indefinitely (a user who messaged the bot once stays in the Map forever, until the
     file is wiped). Stale-ref pruning is a follow-on hardening item.
  6. **Diagnostic emptiness logging** (`relay.ts:306-320`) — the warn-on-unexpected-empty
     pattern (loaded === 0 + (loadErrored || fileExisted)) lifts verbatim. The hashed-userId
     diagnostic at bot.ts:399-401 lifts verbatim too. NOT extending this beyond what
     m-relay-main already does in v1.
  7. **`WEBSITES_ENABLE_APP_SERVICE_STORAGE` runtime check** is OUT OF SCOPE; m-relay-main
     warns the operator (relay.ts:317-318) but does not assert. v1 inherits the warn-not-fail
     posture; making it a startup assertion is a follow-on operational concern.
  8. **Background sync to a remote source-of-truth** (e.g. periodic write-through to a
     blob store for cross-instance consistency) is OUT OF SCOPE for v1.
  9. **Multiple-conversation-per-user** (a user with two distinct Teams threads) is NOT
     supported; m-relay-main keeps ONE ref per userId, last-write-wins. v1 inherits.
     Re-open trigger: multi-conversation-per-user requirement (e.g. group chats).
confidence: high
---

# F-210 — Conversation reference atomic persist

## Rationale

`m-relay-main/src/relay.ts:262-331` solves a subtle production problem for proactive Teams messaging: when the desktop wants to push a message to Teams (via `relay.onProactive` → `bot.ts:332-333` `sendReply`) it needs the user's `conversationId` + `serviceUrl` — but those are only available in the inbound Bot Activity from the user's first Teams message. The mapping `(userId → conversationId, serviceUrl)` MUST survive App Service restarts (Linux container churn, deploys, scale events) — otherwise every user has to message the bot AGAIN after any restart before proactive delivery works.

App Service Linux's filesystem is mostly ephemeral; only `/home` is persistent (per Microsoft Learn: "App Service Linux mounts /home as a persistent volume"). m-relay-main detects this via `process.env.WEBSITE_SITE_NAME ? "/home/data" : "."` (per `relay.ts:79-82`) and writes `conversation-refs.json` there.

The pragmatic solution is small but load-bearing:

- In-memory `Map<userId, ConversationRef>` for fast read.
- Read-on-construct from `/home/data/conversation-refs.json` with ENOENT-as-cold-start handling.
- Write-on-update via `mkdirSync` + `writeFileSync` (cleartext JSON, single file).
- Diagnostic emptiness logging that distinguishes "fresh deploy" (ENOENT, no warn) from "we lost the file" (errored OR `fileExisted && loaded === 0`, warn loudly).

Per `.mad/reports/mad-council-claw-audit-2026-05-07.md` Lane C: "conversation-ref atomic-persist is one of 5 high-value lift candidates from m-relay-main; pattern is small but solves a real production gotcha".

This ledger is RED on creation and **soft-blocked on F-D-008 teams-adapter re-open**. F-210 has no production utility without an active commitment to ship Teams integration.

## Behavior contract

The mad-council-claw engine MUST provide a conversation-ref persistence primitive that:

1. **Detects** the persistent mount: when `process.env.WEBSITE_SITE_NAME` is set (App Service Linux), use `/home/data` as the refs directory; otherwise use `"."` (local development).
2. **Loads** `conversation-refs.json` on construction; parses `Array<[string, ConversationRef]>` and rehydrates the in-memory Map; converts `updatedAt` strings back to `Date` instances (per `relay.ts:283-289`).
3. **Distinguishes** load outcomes: ENOENT → cold start, log info "starting fresh" (per `relay.ts:292-293`); other errors → set `loadErrored = true`, log error (per `relay.ts:294-300`); success but 0 entries → `fileExisted = true`, no warn unless emptiness is unexpected.
4. **Logs unconditionally** the loaded count outside the try block so a silent failure can never hide that the Map is empty (per `relay.ts:303-306`).
5. **Warns** with `WEBSITES_ENABLE_APP_SERVICE_STORAGE` recovery hint when emptiness is unexpected (`loaded === 0 && (loadErrored || fileExisted)`) — per `relay.ts:314-320`.
6. **Persists** on `saveConversationRef(userId, conversationId, serviceUrl)`: updates the Map, calls `persistConversationRefs` (per `relay.ts:262-266`); persistence wraps `mkdirSync(REFS_DIR, {recursive: true})` + `writeFileSync(REFS_FILE, JSON.stringify(entries, null, 2))` (per `relay.ts:323-331`).
7. **Catches** persistence errors and logs without re-throwing — the in-memory Map is the active source of truth; disk persistence is best-effort recovery (per `relay.ts:328-330`).
8. **Exposes** `getConversationRef(userId)` returning the in-memory entry; exposes `conversationRefsSize` getter for diagnostic logging (per `relay.ts:268-275`).
9. **Hashes** `userId` in log lines via `hashUserId` from `m-relay-main/src/log-safe.ts` (per `relay.ts:265`, `bot.ts:399-401`) so production logs do NOT leak Azure AD `oid` values; lifted as part of this surface.

## Acceptance scenarios (9 items, exhaustively enumerated)

1. **(a) Cold start with no file → `loaded = 0`, no warn.** Test runs in a temp dir with no `conversation-refs.json`. Constructs the manager. Asserts: log line `"No conversation refs file at <path> — starting fresh"` fired; the unconditional `"Loaded 0 conversation refs from disk"` line fired; the empty-warn line did NOT fire.

2. **(b) Cold start with valid file → entries rehydrated.** Test pre-writes `conversation-refs.json` with `[["user-A", {conversationId: "c-1", serviceUrl: "https://smba.tm.net/", updatedAt: "2026-05-07T00:00:00.000Z"}]]`. Constructs. Asserts `getConversationRef("user-A")` returns `{conversationId: "c-1", serviceUrl: "https://smba.tm.net/", updatedAt: <Date instance>}` AND `loaded = 1`.

3. **(c) `updatedAt` is rehydrated as `Date`, not string.** From (b), test asserts `getConversationRef("user-A")?.updatedAt instanceof Date === true` and the millisecond value matches `Date.parse("2026-05-07T00:00:00.000Z")`.

4. **(d) Cold start with corrupt file → empty Map + loadErrored warn.** Test pre-writes invalid JSON `"not a json"`. Constructs. Asserts: `loadErrored = true` (internally tracked); the unconditional "Loaded 0" log fired; the empty-warn line DID fire (`loadErrored && loaded === 0`).

5. **(e) Cold start with empty array → empty Map + fileExisted warn.** Test pre-writes `[]`. Constructs. Asserts: `fileExisted = true`, `loaded = 0`; the empty-warn DID fire (`fileExisted && loaded === 0`).

6. **(f) `saveConversationRef` updates Map AND writes file.** Test cold-starts with no file, calls `saveConversationRef("user-B", "c-2", "https://smba.tm.net/")`. Asserts: `getConversationRef("user-B")` returns `{conversationId: "c-2", serviceUrl: "https://smba.tm.net/", updatedAt: <recent Date>}` AND the on-disk `conversation-refs.json` contains a serialized `[["user-B", {...}]]` array.

7. **(g) Persistence error is caught, in-memory Map remains valid.** Test calls `saveConversationRef("user-C", "c-3", "https://smba.tm.net/")` with the refs dir mocked to throw on `writeFileSync` (e.g., readonly mount). Asserts: a console.error fired with the failure; `getConversationRef("user-C")` STILL returns the new ref (in-memory Map updated); no exception propagated to caller.

8. **(h) `conversationRefsSize` getter reflects Map size.** Test cold-starts, calls `saveConversationRef` twice for two distinct users. Asserts `conversationRefsSize === 2`.

9. **(i) `hashUserId` log helper hides raw oid.** Test calls `saveConversationRef("real-aad-oid-with-PII", "c-4", "https://smba.tm.net/")`. Captures console.log output. Asserts the raw string `"real-aad-oid-with-PII"` does NOT appear in any log line; instead a hashed prefix (`hashUserId` returns a short SHA-256 prefix) appears.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| `tests/node/F-210-conversation-ref-atomic-persist.test.ts` | node | RED — RelayManager `loadConversationRefs` / `persistConversationRefs` / `saveConversationRef` / `getConversationRef` / `conversationRefsSize` do not exist; `log-safe.ts` `hashUserId` does not exist; temp-dir + console.log capture infrastructure absent | acceptance items (a)-(i); structural via `existsSync` + `import`; behavioral via tmp-dir fs operations + console.log spy + mocked writeFileSync for (g) |

## Dependencies

- **Hard:** F-205 (kit-bootstrap), F-206 (RelayManager substrate; `conversationRefs` Map lives on RelayManager).
- **Soft (BLOCKING for RED→GREEN):** F-D-008 teams-adapter re-open.
- **Independent:** F-008 local-storage-layout (M0 storage convention; F-210 may consume it for the refs-dir path resolver, OR override with App Service `/home/data` detection — sibling, not dep).
- **Cross-link:** F-070 encrypted-storage (M8) — IF future hardening encrypts `conversation-refs.json`, F-070 is the consumer.
- **Cross-link:** F-D-005 schema-migration (M19) — IF the on-disk shape ever changes, F-D-005 covers the migration.

## Lift contract

**Direct lift** of `m-relay-main/src/relay.ts:48-68,79-82,88,98-99,262-331` AND `m-relay-main/src/log-safe.ts` (entire file, expected ~30 LOC) per Lane C audit. Adapter requirements:

- `loadConversationRefs` / `persistConversationRefs` / `saveConversationRef` / `getConversationRef` / `conversationRefsSize` lift verbatim onto the council-claw RelayManager.
- The `ConversationRef` interface (`relay.ts:48-68`) lifts verbatim.
- The `REFS_DIR` / `REFS_FILE` resolution at `relay.ts:79-82` lifts verbatim — the App Service Linux convention is the right primitive.
- The `bot.ts` paths that consume conversation-refs (`bot.ts:323-355` proactive handler constructor; `bot.ts:438-462` saveConversationRef call from `handleMessage`) lift verbatim into the council-claw `BotHandler`.
- The `log-safe.ts` helper module (`hashUserId` + `errLabel`) lifts verbatim into `packages/engine-relay/log-safe.ts` or equivalent.
- **Hardening item (NOT a v1 RED→GREEN gate but flagged for council-review at LOCKED):** the direct `writeFileSync` on `relay.ts:327` does NOT use the kit's atomic write-temp-then-rename pattern from `concurrency-safety.md` §2. v1 lifts AS-IS; the LOCKED gate's council review SHOULD either accept the deviation (single-writer scenario; in-process Map is source of truth) or promote to atomic-write before LOCKED.

## Surface trace

| surface-id | what it contributes |
|---|---|
| mr:m-relay-main/src/relay.ts:48-68 | `ConversationRef` interface (conversationId, serviceUrl, updatedAt) |
| mr:m-relay-main/src/relay.ts:79-82 | `REFS_DIR` / `REFS_FILE` App Service Linux persistent-mount detection |
| mr:m-relay-main/src/relay.ts:88 | `conversationRefs` Map declaration on RelayManager |
| mr:m-relay-main/src/relay.ts:98-99 | `loadConversationRefs()` invocation in constructor |
| mr:m-relay-main/src/relay.ts:262-331 | `saveConversationRef` / `getConversationRef` / `conversationRefsSize` getter / `loadConversationRefs` / `persistConversationRefs` |
| mr:m-relay-main/src/bot.ts:323-355 | proactive handler that consumes `getConversationRef` |
| mr:m-relay-main/src/bot.ts:438-462 | `handleMessage` write path that calls `saveConversationRef` + `savedRef` warn pattern |
| mr:m-relay-main/src/log-safe.ts | `hashUserId` log helper (lift in same commit) |
| kit:rules/concurrency-safety.md | atomic-write discipline; v1 lifts m-relay-main's direct write but flags the deviation for LOCKED-gate review |
| kit:rules/single-owner-accountability.md | userId ↔ conversationRef ownership; F-210 enforces last-write-wins per userId (single-writer-per-key invariant matches the rule) |

## References

- `.mad/reports/mad-council-claw-audit-2026-05-07.md` (in `C:\Users\tonym\Repos\MAD - Clean`) — Lane C inventory.
- `m-relay-main/src/relay.ts:48-68,79-82,88,98-99,262-331` — direct source.
- `m-relay-main/src/bot.ts:323-355,438-462` — direct source for consumers.
- `docs/03-feature-catalog/M9-m365/F-206-ws-relay-manager.md` — RelayManager substrate.
- `docs/03-feature-catalog/M19-deferred/F-D-008-teams-adapter.md` — soft-blocking re-open.
- `docs/03-feature-catalog/M0-bootstrap/F-205-kit-bootstrap.md` — hard-dep substrate.
- `.claude/rules/concurrency-safety.md` (in MAD - Clean kit) — atomic-write discipline reference.
- `.claude/rules/no-silent-deferrals.md` (in MAD - Clean kit).
