---
artifact-class: research-finding
source-tag: [R:frontier-2026]
confidence: high
wave: wave-001
lane: lane-a
date: 2026-05-07
sources:
  - https://a2a-protocol.org/latest/specification/
---

# A2A Protocol — Specification

## Source
https://a2a-protocol.org/latest/specification/ (fetched 2026-05-07)

## Load-bearing patterns

- **Three-layer architecture**: Canonical data model (Protocol Buffers) + abstract operations + protocol bindings (JSON-RPC, gRPC, HTTP/REST). Transport-agnostic above the protobuf layer.
- **Agent Card (JSON metadata)**: Each A2A Server publishes a JSON document describing identity, capabilities, skills, endpoints, authentication. Foundation of dynamic discovery.
- **Capability declarations**: Streaming support, push notifications, extended-card-after-auth. Clients query declared capabilities BEFORE attempting feature use.
- **Explicit error on unsupported capability**: `UnsupportedOperationError`, `PushNotificationNotSupportedError`. NOT silent fallback.
- **Task lifecycle states**: SUBMITTED → WORKING → COMPLETED/FAILED/CANCELED/REJECTED (terminal). Plus interrupted states INPUT_REQUIRED + AUTH_REQUIRED that allow resumption.
- **Three task-tracking modes**: Polling (GetTask), streaming (SubscribeToTask), webhooks (push notifications).
- **Message format**: Role (User/Agent), Parts (text, binary, URL ref, structured JSON), Metadata (custom KV), Task/Context IDs (multi-turn).
- **Cross-org boundary as first-class concern**: Agents collaborate based on declared capabilities + exchanged information WITHOUT sharing internal thoughts, plans, or tool implementations. Opaque collaboration.
- **Authentication menu**: API keys, HTTP Auth, OAuth 2.0, OpenID Connect, mutual TLS — enterprise-grade options across the menu.
- **HTTP transport mapping**: REST endpoints (`POST /messages`, `GET /tasks/{id}`); SSE for streaming; webhooks for push.

## Verbatim quotes worth preserving

> "Agents collaborate based on declared capabilities and exchanged information, without needing to share their internal thoughts, plans, or tool implementations."

> "Parts can be purely textual, some sort of file (image, video, etc) or a structured data blob (i.e. JSON)."

> (paraphrased from spec) Capability negotiation is explicit; servers declare what they support, clients respect declarations, mismatches return explicit named errors — NOT silent fallback.

## Implications for the engine catalog

A2A is the canonical reference for cross-agent (cross-process, cross-org) coordination. The kit's MAD.Council channel architecture is essentially A2A's local-mode subset. F-NNN candidates: (1) Agent Card publishing is the kit's missing primitive — every skill should expose itself via an A2A-compatible Agent Card so external agents can discover it. (2) The opaque-collaboration thesis (don't share internal thoughts) is the inverse of the kit's current "subagent dumps full context" pattern; the engine should adopt scoped-context handoffs per OpenAI's input_filter pattern + A2A's opaque collaboration principle. (3) Three-mode task tracking (poll/stream/webhook) is more flexible than the kit's current "wait synchronously" pattern; F-NNN for streaming + webhook task tracking. (4) Authentication menu (API keys → mTLS) maps to enterprise readiness — engine should support the full menu, not just one. (5) Explicit-error-on-unsupported-capability is a safer default than silent fallback (which the kit currently does in some places).

## NEW F-NNN candidates

- F-057 agent-card-publishing — Engine emits A2A-compatible Agent Cards for every registered skill; cards are JSON-discoverable at `.well-known/agent-cards/` — confidence: H
- F-058 opaque-collaboration-discipline — Engine subagent handoffs share only declared inputs + expected outputs; do NOT dump full conversation history (per A2A's opaque-collaboration principle + OpenAI input_filter) — confidence: H
- F-059 task-lifecycle-states-explicit — Engine task tracking has explicit states (SUBMITTED/WORKING/COMPLETED/FAILED/CANCELED/REJECTED + interrupted INPUT_REQUIRED/AUTH_REQUIRED); maps to council-thread states — confidence: H
- F-060 streaming-task-subscription — Engine supports SubscribeToTask-style streaming for long-running operations; clients poll-or-stream-or-webhook — confidence: M
- F-061 webhook-task-notifications — Engine supports push-notification (webhook) for asynchronous task completion; integrates with cron + ScheduleWakeup — confidence: M
- F-062 explicit-capability-errors — Engine returns named errors (`UnsupportedOperationError`-class) on capability mismatch; never silent-fallbacks per A2A's discipline — confidence: H
- F-063 enterprise-auth-menu — Engine supports the full A2A auth menu (API keys, HTTP Auth, OAuth 2.0, OIDC, mTLS); selection per channel/skill — confidence: M

## Confidence

HIGH — A2A is the canonical cross-agent protocol; the kit's existing council/channel architecture aligns with A2A's local-mode subset and the engine should make the alignment explicit.
