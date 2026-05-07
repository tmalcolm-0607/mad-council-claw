---
artifact-class: feature-ledger
generated-by: hand-authored (wave-005 / lane-a)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-005 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-081
short-slug: workiq-rate-limit-cb
milestone: M9
provenance:
  surfaces:
    - kit:rules/degradation-fallback-policy.md
    - kit:rules/anomaly-thresholds.md
    - cp:electron/ipc/with-timeout.ts
    - R:microsoft-2026/workiq-internal-context.md
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
  LOCKED if GREEN AND reviews/F-081-workiq-rate-limit-cb-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-015, F-021, F-080]
out-of-scope-notes: |
  Cross-tenant rate-limit pooling (one rate-limit budget shared across multiple
  tenants) is OUT — engine v1 keys rate-limits per (session_id, resource).
  Adaptive rate-limiting based on Graph 429 retry-after hints is a v1.5
  hardening item. v1 uses a fixed token-bucket per resource.
  Per-user rate-limit (independent of session) is deferred to M8 settings.
confidence: high
---

# F-081 — WorkIQ rate-limit + circuit-breaker

## Behavior contract

The engine MUST wrap every WorkIQ + Graph call (per F-080) with two layers: (1) a per-resource token-bucket rate limiter (default capacity 60/min, refill 1/sec — tunable) and (2) a circuit-breaker that opens after 3 consecutive failures within a 60-second sliding window per `degradation-fallback-policy.md` Rule 4 + `anomaly-thresholds.md` `consecutive_failures: 3`. When the bucket is exhausted, calls return immediately with `RATE_LIMIT_EXCEEDED`; when the breaker is open, calls return immediately with `CIRCUIT_OPEN`. Both rejections are logged to the hash-chained audit log (per F-015) with the resource name, attempt count, and breaker state. The breaker enters half-open after a 30-second cooldown; one probe call decides re-close vs. re-open. This protects downstream Microsoft Graph and WorkIQ from runaway clients and protects the engine from cascading failures during transient outages.

## Acceptance scenarios

1. **Given** a token bucket with 60 capacity and 5 calls already consumed within the same minute, **When** the engine fires 56 more calls in rapid succession, **Then** calls 1-55 succeed (consuming tokens) and call 56 rejects with `RATE_LIMIT_EXCEEDED` immediately (no network round trip), with a single audit entry summarizing the rate-limit event.
2. **Given** Graph returns 503 three times in 60 seconds for the same resource, **When** the 4th call attempts, **Then** the circuit-breaker is open and the call returns `CIRCUIT_OPEN` without a network attempt; an audit entry records the breaker open transition with the 3 trigger sha256s chained.
3. **Given** a breaker has been open for 30 seconds, **When** the next call fires, **Then** the breaker enters half-open, allows one probe; if the probe succeeds the breaker closes (full traffic resumes), if it fails the breaker re-opens for another 30-second cooldown.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/rate-limit/token-bucket-exhaustion.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/integration/circuit-breaker/three-fail-opens.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/circuit-breaker/half-open-probe.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine cycles), F-015 (rejection events appended to audit chain), F-021 (degradation policy provides circuit-breaker semantics + Context Gap framing), F-080 (WorkIQ adapter is the wrapped surface)
- **Soft:** F-018 (failure-pattern halt may escalate when CB stays open across multiple cycles), F-022 (per-cycle quota interacts with rate-limit budget)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:rules/degradation-fallback-policy.md | Rule 4: respect retry limits + circuit-breaker open/half-open/closed semantics |
| kit:rules/anomaly-thresholds.md | `consecutive_failures: 3` threshold for breaker-open; sliding-window seconds |
| cp:electron/ipc/with-timeout.ts | timeout-wrapping helper pattern (informs rate-limit timing primitive) |
| R:microsoft-2026/workiq-internal-context.md | Microsoft-internal "tool explosion" lesson informs why per-resource limits are non-negotiable |

## Implementation notes

(empty — populated when implementation begins)
