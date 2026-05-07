---
artifact-class: feature-ledger
generated-by: hand-authored (silent-deferral surfacing 2026-05-07; Batch 3 of 4)
status: deferred
status-since: 2026-05-07
status-history:
  - status: deferred (REOPEN-REQUESTED on creation)
    at: 2026-05-07
    by: orchestrator session 967a44fb (user-authorized via AskUserQuestion 2026-05-07)
    note: "Initial creation. F-D-018 was a RESERVED ID (named in foundational-plan.md:432 + M19-deferred/README.md:17 but with no ledger file pre-this-commit). Authored as part of the M19 reopen-request package per user explicit request. Top-level status is 'deferred' on creation; the REOPEN-REQUESTED qualifier indicates the reopen-request package at docs/05-design-reviews/reopen-requests/F-D-008-F-D-010-F-D-018-reopen-2026-05-07.md is gating on a council-review verdict at HIGH ≥80% per M19-deferred/README.md:51-57. Council-verdict skill not yet installed in mad-council-claw; gates on Batch 4 kit-bootstrap (F-205). Sibling reopen targets F-D-008 + F-D-010 are concurrent in the same package."
feature-id: F-D-018
short-slug: activity-protocol-teams-outlook
milestone: M19
provenance:
  surfaces:
    - kit:foundational-plan.md M19 row F-D-018 (reserved 2026-04 wave-007)
    - kit:rules/no-silent-deferrals.md
    - mr:m-relay-main/src/bot.ts:33-77 (Bot Framework JWT validation pattern; protocol foundation)
    - mr:m-relay-main/src/protocol.ts:1-111 (TS message contract shape)
    - .mad/reports/mad-council-claw-audit-2026-05-07.md (Lane C inventory; "Teams bot / Clawpilot timeline?" question + decision to surface F-D-018)
fr-coverage: []
test-files:
  unit: []
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects: []
red-green-rule: |
  N/A while status: deferred. If re-opened (per docs/05-design-reviews/reopen-requests/F-D-008-F-D-010-F-D-018-reopen-2026-05-07.md
  + council-review verdict at HIGH ≥80% per M19-deferred/README.md:51-57), the standard contract applies.
depends-on: [F-076, F-080, F-D-008, F-D-009, F-D-010]
out-of-scope-notes: |
  Deferred per user decision; not part of v1. v1 reads Teams + Outlook via WorkIQ but does
  not write to either surface, and the engine is invoked locally rather than as a remote
  conversational endpoint. F-D-018 represents the unified Activity-Protocol approach where
  a single adapter stack bridges both Teams and Outlook read/write through the Microsoft
  Activity Protocol surface (a successor / sibling pattern to Bot Framework). Distinct
  alternatives:

  - F-D-008 teams-adapter handles outbound Teams as a discrete adapter (Graph + Teams app
    paths) without committing to Activity Protocol unification.
  - F-D-009 outlook-adapter handles outbound Outlook (sendMail / RSVP / drafts) as a
    discrete adapter.
  - F-D-010 bot-framework-direct treats the engine as a Bot Framework bot, with Teams as
    one of many channels.
  - F-D-018 (this ledger) is the FOURTH option: a single Activity-Protocol-shaped surface
    that addresses Teams + Outlook in one adapter design, leveraging the protocol's
    unified Activity envelope across surfaces. Re-opening any one of F-D-008/009/010
    without considering F-D-018 risks a fragmented multi-adapter sprawl that an Activity
    Protocol approach would have unified.
confidence: high
---

# F-D-018 — Activity Protocol Teams + Outlook unified read/write (DEFERRED)

## Status

**Deferred to v1.5+ per `rules/no-silent-deferrals.md`.** **REOPEN-REQUESTED 2026-05-07** per the package at `docs/05-design-reviews/reopen-requests/F-D-008-F-D-010-F-D-018-reopen-2026-05-07.md`. Top-level status remains `deferred` until council-review verdict at HIGH ≥80% per `M19-deferred/README.md:51-57`.

## Summary

A unified outbound surface for Teams + Outlook that leverages the Microsoft Activity Protocol — the same Activity envelope shape used by Bot Framework but generalized across Microsoft 365 surfaces. The engine receives inbound Activity envelopes from Teams (chat / channel / DM) and Outlook (mail / calendar / RSVP), routes them through a single dispatcher, and emits outbound Activities that the protocol implementation delivers to the appropriate surface. Distinct from F-D-008 (Teams-only adapter), F-D-009 (Outlook-only adapter), and F-D-010 (Bot Framework as the runtime) by unifying the cross-surface story into one read/write contract.

The Activity Protocol shape inherits Bot Framework's Activity types (`message`, `invoke`, `conversationUpdate`, etc. per the Bot Framework Activity schema) and overlays Outlook-specific extensions (mail intent, calendar action, RSVP outcome) on the same envelope. A single adapter handles both surfaces; client-side capability negotiation distinguishes which features are live per channel.

## Behavior contract

When this item transitions to RED via the documented re-open protocol, the implementation MUST provide:

1. **Inbound envelope dispatch.** Accepts Activity-shaped POSTs (Teams webhook + Outlook channel webhook) at a configurable bot endpoint. Validates Bot Framework JWTs against the OpenID metadata service per `m-relay-main/src/bot.ts:33-77` (`validateBotFrameworkToken` pattern: signed-by-Bot-Framework JWKS + allowed issuers list including tenant-specific `login.microsoftonline.com/{tenant}/v2.0` + `sts.windows.net/{tenant}/` + canonical `api.botframework.com` + audience matches `MicrosoftAppId`).
2. **Surface-aware routing.** Inspects each Activity's `channelId` (`msteams` vs `outlook` / `email` per Activity Protocol schema) and routes to the appropriate handler within the engine's `IBackendProvider` (F-009) integration.
3. **Unified outbound replies.** A single `sendActivity(activity)` primitive emits to either surface. The implementation derives the channel from `activity.channelId` and delegates: Teams replies via Bot Connector REST per `m-relay-main/src/bot.ts:177-321` pattern (POST to `serviceUrl/v3/conversations/{id}/activities`); Outlook replies via Microsoft Graph `/me/sendMail` or calendar action per F-D-009's analog scope.
4. **Conversation-ref persistence per surface.** Conversation refs (Teams thread context + Outlook conversation thread + calendar series) persist atomically per `m-relay-main/src/relay.ts:79-82` App Service `/home` convention, namespaced by surface to avoid collision. Cross-link to F-210 atomic-persist pattern.
5. **Adaptive Cards in Teams + Outlook actionable messages.** Permission cards + briefing artifacts use Adaptive Cards in Teams (per `m-relay-main/src/cards.ts` + F-209 lifecycle) and the Outlook Actionable Messages variant (Outlook supports a subset of the same Adaptive-Card schema). The unified primitive emits the right shape per surface.
6. **Action.Execute for permission lifecycle.** Both surfaces use Action.Execute payloads (Teams natively; Outlook actionable-messages with `OnPostBackInvoke`). Permission decisions are persisted server-side (no client trust per `m-relay-main/src/cards.ts` + F-209), and the response signals the engine to proceed or abort.
7. **MSI-FIC token mint.** Outbound calls to Bot Connector + Microsoft Graph use Managed Identity → Federated Identity Credential token mint per `m-relay-main/src/bot.ts:125-175`, no long-lived secret in the engine.
8. **Treat-inbound-as-data discipline.** Per `prompt-injection-policy.md` Rule 1, inbound `Activity.text` from either surface is data, never instructions; the engine MUST NOT execute embedded directives.
9. **Per-surface rate limits.** Inherits relay-shaped per-user rate limits per `m-relay-main/src/relay.ts:72,192-235` (100 messages/minute sliding window per AAD `oid`); Outlook has tighter limits than Teams (mail-send abuse risk is higher).

## Re-open trigger

Re-open this item when **ANY** of the following user-acknowledged conditions are met:

1. The user explicitly requests a unified Teams + Outlook read/write surface via Activity Protocol (NOT just one or the other separately).
2. F-D-008 (Teams adapter) and/or F-D-010 (Bot Framework direct) are themselves re-opened — the unified surface and the discrete-adapter strategies should be designed together, not in isolation.
3. Microsoft Activity Protocol surface stabilizes (currently evolving in Microsoft Bot Framework + Microsoft 365 Copilot connector ecosystem); the protocol becoming a documented stable surface lowers the implementation risk meaningfully.
4. F-D-009 (Outlook adapter) is itself re-opened — the unified Activity-Protocol surface spans both Teams and Outlook, and re-opening the Outlook half is the natural co-trigger that makes a unified design rather than a Teams-only design the right shape.

Until then, this ledger remains `status: deferred` and SHOULD NOT be transitioned to RED **except via the documented re-open protocol** per `docs/03-feature-catalog/M19-deferred/README.md:51-57` (explicit user request + named triggers met + council-review verdict at HIGH ≥80% + target milestone identified).

## Out-of-scope notes (additional, beyond the frontmatter)

- **Microsoft Teams app vs Bot Framework registration.** Two distinct app shapes deliver to Teams: the Teams app manifest path (M365 Admin tenant install) and the Bot Framework registration path (Azure Bot Service). F-D-018 is agnostic; the council verdict should specify which is in scope.
- **Calendar negotiation vs simple RSVP.** Outlook calendar actions span simple RSVP (accept / tentative / decline) and complex negotiation (suggest new time, propose alternative). v1.5+ scope should ship simple RSVP only; complex negotiation is a follow-on.
- **Cross-tenant routing.** Activity Protocol can in principle deliver across tenants when configured. F-D-018 is single-tenant per the m-relay-main baseline. Cross-tenant is OUT OF SCOPE; would require its own re-open trigger.
- **Voice / video Activity types.** Teams supports voice/video Activity envelopes; F-D-018 does NOT include them. Voice input is F-096 / F-098 (M13 multimodal); video is OUT OF SCOPE for v1.5+.
- **PII handling.** Activity payloads can contain PII (mail subjects, calendar attendees, chat content). Per `prompt-injection-policy.md` PII is explicitly out of scope — engine does not auto-redact, users manage their own data hygiene at the source. F-D-018 inherits this posture.

## Lift contract reference

When F-D-018 transitions to RED, the m-relay-main lift surfaces F-206..F-210 (already authored Batch 2) form the substrate for the Teams half:

- **F-206 ws-relay-manager** — desktop ↔ relay WebSocket transport
- **F-207 bot-connector-rest-jwt** — Bot Framework JWT validation + outbound Bot Connector REST
- **F-208 msi-fic-token-mint** — federated-identity token acquisition
- **F-209 adaptive-card-permission-lifecycle** — Action.Execute permission flow
- **F-210 conversation-ref-atomic-persist** — conversation-ref durable storage

The Outlook half requires additional surfaces NOT yet authored (F-D-009-derived F-NNNs; out of scope for this batch).

## Provenance

`kit:foundational-plan.md M19 row F-D-018`, `kit:rules/no-silent-deferrals.md`, `mr:m-relay-main/src/bot.ts:33-77`, `mr:m-relay-main/src/protocol.ts:1-111`, `.mad/reports/mad-council-claw-audit-2026-05-07.md` (Lane C inventory + § "TL;DR per user question" Teams-bot row).

## Cross-references

- Reopen-request package: `docs/05-design-reviews/reopen-requests/F-D-008-F-D-010-F-D-018-reopen-2026-05-07.md`
- Sibling deferred ledgers (concurrent reopen targets): `F-D-008-teams-adapter.md`, `F-D-010-bot-framework-direct.md`
- Sibling deferred ledger (NOT in this reopen batch): `F-D-009-outlook-adapter.md`
- Lift ledgers (Teams half substrate): `docs/03-feature-catalog/M9-m365/F-206-ws-relay-manager.md` through `F-210-conversation-ref-atomic-persist.md`
- M19 catalog: `docs/03-feature-catalog/M19-deferred/README.md:51-57` (re-open protocol)
- Foundational plan reservation: `docs/01-requirements/foundational-plan.md:432` + `:567`
