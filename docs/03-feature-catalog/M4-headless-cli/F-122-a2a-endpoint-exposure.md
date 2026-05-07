---
artifact-class: feature-ledger
generated-by: hand-authored (wave-012 / lane-c)
status: red
status-since: 2026-05-07
status-history:
  - status: planned
    at: 2026-05-06
    by: foundational-plan.md catalog deltas
    note: "F-NNN reserved as one of 5 frontier-research candidates"
  - status: red
    at: 2026-05-07
    by: wave-012 / lane-c
    note: "Initial ledger created; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-122
short-slug: a2a-endpoint-exposure
milestone: M4
provenance:
  surfaces:
    - foundational-plan.md "Plus 5 NEW F-NNN candidates" F-122
    - foundational-plan.md "[R:WorkIQ + msft-learn finding 10]"
    - docs/06-agent-team-outputs/wave-001/lane-b-summary.md (finding 10 — A2A protocol Microsoft adapters)
    - docs/04-research/microsoft-2026/workiq-a2a-impl-patterns.md (HTTP+JSON default binding; ITaskManager removed in v1.0)
    - kit:rules/dangerous-operations-policy.md (cross-org A2A first-message consent gate)
    - kit:rules/stride-threat-model.md §Spoofing + §Elevation (A2A cross-machine OAuth 2.0)
    - kit:rules/non-negotiable-rules.md (no remote exposure without explicit user request)
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
  LOCKED if GREEN AND reviews/F-122-a2a-endpoint-exposure-review.md exists with verdict: ACCEPT.
depends-on: [F-028, F-029, F-031, F-002, F-015]
out-of-scope-notes: |
  Cross-org broadcast UI / agent-card publication to a public registry — out of v1; first
  message to any OIDC-discovered cross-org endpoint requires the consent gate from
  `rules/dangerous-operations-policy.md` § Cross-org A2A Bridge category.
  JSON-RPC binding — out for v1; per `workiq-a2a-impl-patterns.md` finding 2, the A2A v1.0
  default binding is HTTP+JSON. Engine declares HTTP+JSON explicitly via `MapA2AHttpJson`.
  ITaskManager contract — explicitly NOT cited (removed in A2A v1.0 per finding 3).
  MCP OAuth 2.1 + TLS-pinned MCP endpoints — tracked under D-29 / candidate F-135 (not this
  ledger). F-122 governs A2A endpoint exposure on the engine's CLI/daemon surface only.
  Teams adapter A2A integration — tracked under F-D-007 (deferred); separate `@microsoft/teams.a2a`
  package per finding 4 of `workiq-a2a-impl-patterns.md`.
confidence: high
---

# F-122 — A2A endpoint exposure

## Behavior contract

The engine MUST expose its agent capabilities to other A2A-compatible agents via a
declared HTTP+JSON endpoint that conforms to A2A protocol v1.0 (`workiq-a2a-impl-patterns.md`
finding 2 — HTTP+JSON is the v1.0 default binding, not JSON-RPC). Endpoint exposure is
disabled by default and OFF in `local-only` mode (matching the telemetry default in F-110);
enabling it on the headless CLI / daemon (F-031) requires explicit user opt-in via the
`a2a` subcommand surface (e.g., `mad-council a2a serve --bind 127.0.0.1:8443`). The endpoint
publishes an Agent Card under `/.well-known/agent-card.json` enumerating the engine's
capabilities, supported skills (per F-051), supported transports, and `auth_schemes`.
Inbound requests are bound to the engine's session identity (per F-002) and audit-logged
via the hash-chained audit log (per F-015). The first inbound message from any
OIDC-discovered cross-org endpoint triggers the Dangerous Operation consent gate per
`rules/dangerous-operations-policy.md` § Cross-org A2A Bridge category. The engine MUST
NOT advertise an endpoint on a non-loopback interface without an explicit `--bind` flag
naming a non-loopback address; default bind is `127.0.0.1` only.

## Acceptance scenarios

1. **Given** a fresh engine launch with default config (no `a2a serve` invoked), **When**
   any HTTP client probes the engine's process namespace for `/.well-known/agent-card.json`
   on any port, **Then** no port is bound and no agent card is served (default-off
   exposure; verified via test-time port-scan).
2. **Given** the operator runs `mad-council a2a serve --bind 127.0.0.1:8443` and a peer
   A2A client (same machine) `GET`s `https://127.0.0.1:8443/.well-known/agent-card.json`,
   **When** the request completes, **Then** the response is a valid A2A v1.0 Agent Card
   with HTTP+JSON declared as the default binding, the engine's `auth_schemes`, and
   the engine's enumerated skills (per F-051); `MapA2AJsonRpc` is NOT advertised.
3. **Given** an authorized inbound A2A `tasks/send` arrives from a previously-unknown
   cross-org endpoint (OIDC discovery yielding a different `iss` than the engine's
   session-bound issuer), **When** the engine processes the first message, **Then** the
   Dangerous Operation consent gate fires per `rules/dangerous-operations-policy.md`
   § Cross-org A2A Bridge, the operator must type "yes", and the consent decision is
   logged to `<state-dir>/consent-log.jsonl` with `from_iss`, decision, and timestamp.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/a2a/default-off-exposure.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/integration/a2a/agent-card-http-json-binding.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/a2a/cross-org-consent-gate.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-028 (CLI entry; `a2a` subcommand surface), F-029 (subcommand dispatch),
  F-031 (daemon hosts the listener), F-002 (session identity binds to inbound requests),
  F-015 (hash-chained audit log captures every inbound A2A call)
- **Soft:** F-051 (skills enumeration in the Agent Card), F-058 (3-tier permissions
  classifier governs which inbound capabilities are allowed), F-076..F-079 (M9 MSAL/WAM
  + token refresh feed the `auth_schemes` declaration when the engine is signed in)
- **Independent:** F-122 deliberately does NOT touch the MCP plane (M6); MCP endpoints
  are inbound-tool surfaces, A2A is the engine's outbound-agent surface

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan.md F-122 | reserved F-NNN allocation; M4 placement; "[R:WorkIQ + msft-learn finding 10]" provenance |
| docs/06-agent-team-outputs/wave-001/lane-b-summary.md finding 10 | A2A protocol Microsoft adapters originally surfaced this candidate |
| docs/04-research/microsoft-2026/workiq-a2a-impl-patterns.md | HTTP+JSON default binding; `MapA2AHttpJson` vs `MapA2AJsonRpc` separation; ITaskManager removed in v1.0 |
| kit:rules/dangerous-operations-policy.md | first cross-org message triggers consent gate |
| kit:rules/stride-threat-model.md | OAuth 2.0 cross-machine trust boundary; spoofing-mitigation via session_id binding on inbound requests |
| kit:rules/non-negotiable-rules.md | no remote exposure without explicit user request — translates to default-off + explicit `--bind` |

## Implementation notes

(empty — populated when implementation begins)
