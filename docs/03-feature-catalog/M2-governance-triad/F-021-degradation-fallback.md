---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-021
short-slug: degradation-fallback
milestone: M2
provenance:
  surfaces:
    - kit:rules/degradation-fallback-policy.md
    - kit:rules/anomaly-thresholds.md
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
  LOCKED if GREEN AND reviews/F-021-degradation-fallback-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-006]
out-of-scope-notes: |
  Circuit-breaker open/half-open/closed state-machine for individual external
  resources is part of this feature. Cross-resource health-rollup dashboards
  belong to M16 telemetry (F-110..F-113).
confidence: high
---

# F-021 — Degradation & fallback policy

## Behavior contract

When any optional dependency fails (A2A bridge unreachable, MCP server down, telemetry export rejected), the engine MUST: (1) skip that path and continue, (2) emit a `Context Gaps` entry, (3) offer a manual fallback in user-facing output. After 3 consecutive failures of the same resource within a sliding window, the engine opens a circuit-breaker for that resource (subsequent calls fail-fast for cooldown duration). Required dependencies (engine kernel, audit log) do NOT degrade — their failures halt per F-018. The 5 rules of `degradation-fallback-policy.md` are the contract.

## Acceptance scenarios

1. **Given** an outbound telemetry export that times out 3 times in 60 seconds, **When** the 4th export attempts, **Then** the circuit-breaker is open and the call returns immediately with `CIRCUIT_OPEN` (no actual network attempt).
2. **Given** a Context-Gap-eligible failure (MCP server returns 503), **When** the next user-facing status emission fires, **Then** the output includes a `⚠️ Context Gaps` section listing the source + status + impact.
3. **Given** a required-dependency failure (audit log writer fails), **When** the engine attempts to log, **Then** the engine does NOT degrade — it halts via F-018 with `halted_by: "audit_writer_failure"`.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/degradation/circuit-breaker.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/unit/degradation/context-gaps-emit.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/degradation/required-dep-halts.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine cycles), F-006 (logger emits Context Gaps lines)
- **Soft:** F-018 (required-dep failures escalate to halt), F-015 (each failure logs an audit entry)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:rules/degradation-fallback-policy.md | the 5 rules + named failure modes (1-6) |
| kit:rules/anomaly-thresholds.md | sliding-window thresholds for circuit-breaker |

## Implementation notes

(empty — populated when implementation begins)
