---
artifact-class: feature-ledger
generated-by: hand-authored (wave-004 / lane-a)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-004 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-046
short-slug: mcp-reconnect-health
milestone: M6
provenance:
  surfaces:
    - ce:US-6
    - ce:FR-COST-003
    - cp:electron/mcp-store.ts
    - cp:electron/mcp-tools.ts
    - kit:rules/degradation-fallback-policy.md
    - "wave-1 lane-c lessons-learned.md (bounded retries with explicit timeouts)"
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
  LOCKED if GREEN AND reviews/F-046-mcp-reconnect-health-review.md exists with verdict: ACCEPT.
depends-on: [F-021, F-044, F-045]
out-of-scope-notes: |
  Cross-machine MCP server reachability (e.g. A2A endpoint health) is M19 deferred (F-122 a2a-endpoint-exposure NEW frontier candidate).
  Failure-pattern halt on 3 consecutive `tool_error` (run-end semantics, distinct from server reconnect) is F-018.
  Per-server cost-bounded retries are F-019 cost-ledger interaction.
  Network-level rate-limit + circuit-break on outbound MCP traffic for cross-machine BYO is M19 deferred.
confidence: high
---

# F-046 — MCP reconnect & health

## Behavior contract

Every MCP server bridge runs a bounded health probe: a lightweight `tools/list` (or equivalent capability ping) on a configurable cadence (default 60s). On probe failure, the bridge attempts reconnect with exponential backoff (1s, 2s, 4s) — at most 3 attempts. The retry budget is explicit per `kit:rules/degradation-fallback-policy.md` Rule 4 (respect retry limits) and per `wave-1 lane-c lessons-learned.md` (bounded retries with explicit timeouts). After 3 consecutive reconnect failures, the bridge opens its circuit breaker and the server transitions to `degraded`: the server stays in the registry but no new tool calls dispatch to it; the engine continues running with a Context Gap surfaced per F-021. A circuit-broken server retries reconnection on a slow cadence (10 minutes) until success closes the circuit. Health probe failures count distinctly from tool-call failures (per F-018 / `ce:FR-COST-003` 3-consecutive-`tool_error` halt) — a degraded server does NOT halt the run; it just isn't called.

## Acceptance scenarios

1. **Given** an MCP server whose process is killed externally, **When** the next health probe runs (within ≤60s), **Then** the probe fails, the bridge attempts reconnect with backoff (1s, 2s, 4s), and on the third failure the server enters `degraded` state with a Context Gap per F-021 — total time from kill to `degraded` ≤7s + (next probe interval).
2. **Given** a `degraded` MCP server whose process is restored, **When** the slow-cadence reconnect probe runs (within 10 min), **Then** reconnect succeeds, the circuit breaker closes, the server returns to `ready`, and the Context Gap is cleared on the next `/council-check`-equivalent surface (the run-status read).
3. **Given** a probe-failure-vs-tool-call-failure interaction, **When** a server's probe is healthy but two of its `tools/call` invocations fail with `tool_error`, **Then** the server stays in `ready` (probes are not failing) and the run's `tool_error` counter advances toward F-018's 3-consecutive halt threshold — the two failure paths are independent and clearly distinguishable in audit per F-047.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/mcp/reconnect-bounded-backoff.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/mcp/circuit-close-on-recovery.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/mcp/probe-vs-tool-failure-isolation.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-021 (degradation for the Context Gap surface), F-044 (bridge owns the probe loop), F-045 (lifecycle drives the actual reconnect)
- **Soft:** F-018 (failure-pattern halt — distinct counter for `tool_error`), F-047 (audit log records probe + reconnect events)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:US-6 | MCP allowlist user story (degraded servers stay registered + auditable) |
| ce:FR-COST-003 | Failure-pattern halt — distinct from probe failure; this ledger draws the distinction |
| cp:electron/mcp-store.ts | Server state machine includes `degraded` state |
| cp:electron/mcp-tools.ts | Bridge probe loop pattern |
| kit:rules/degradation-fallback-policy.md | Rule 4 (respect retry limits) + Rule 5 (graceful partial completion) |
| wave-1 lane-c lessons-learned.md | Bounded retries with explicit timeouts (3 attempts, exponential backoff) |

## Implementation notes

(empty — populated when implementation begins)
