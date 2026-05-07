---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: green
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-012 / lane-a
    note: "RED → GREEN: in-memory DegradationLadder primitive (5-rung escalation: normal → skill-fallback → model-fallback → reduced-tool-set → headless → halt). 11/11 vitest scenarios PASS. RunHaltedVerdict reused with new sibling trigger 'degrade_escalate' (14th value in HaltTrigger union). Per-resource circuit-breaker + Context-Gaps emission + required-vs-optional classification deferred to engine-cycle integration per `rules/no-silent-deferrals.md`."
feature-id: F-021
short-slug: degradation-fallback
milestone: M2
provenance:
  surfaces:
    - kit:rules/degradation-fallback-policy.md
    - kit:rules/anomaly-thresholds.md
fr-coverage: []
test-files:
  unit:
    - tests/unit/F-021-degradation-ladder.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - vitest unit (tests/unit/**)
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-021-degradation-fallback-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-006]
out-of-scope-notes: |
  Circuit-breaker open/half-open/closed state-machine for individual external
  resources is part of this feature. Cross-resource health-rollup dashboards
  belong to M16 telemetry (F-110..F-113).

  Wave-012 / lane-a narrowed initial F-021 GREEN scope to the in-memory
  escalation-ladder primitive. The following ledger surface is deferred to
  engine-cycle integration per `rules/no-silent-deferrals.md`:
    1. Per-resource circuit-breaker open/half-open/closed state machine.
    2. Context-Gaps section emission tied to user-facing status output (F-006
       logger integration).
    3. Required-vs-optional dependency classification + automatic F-018 halt
       hand-off on required-dependency failure (audit_writer_failure trigger).
    4. Sliding-window threshold sourcing from `rules/anomaly-thresholds.md`.
    5. F-015 audit-log entry per failure observation.
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

| Test file | Project | State | Verifies |
|---|---|---|---|
| `tests/unit/F-021-degradation-ladder.test.ts` | vitest unit | 🟢 GREEN (11/11 PASS) | wave-012 lane-a brief scenarios 1-7 (escalate one rung at a time, recover one rung, halt is terminal, history records every transition, halt verdict trigger=`degrade_escalate`). |
| (deferred) `tests/integration/degradation/circuit-breaker.test.ts` | integration | RED | ledger scenario 1 — per-resource circuit-breaker open/half-open/closed |
| (deferred) `tests/unit/degradation/context-gaps-emit.test.ts` | unit | RED | ledger scenario 2 — Context-Gaps emission on user-facing status |
| (deferred) `tests/integration/degradation/required-dep-halts.test.ts` | integration | RED | ledger scenario 3 — required-dependency F-018 halt hand-off |

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

**Wave-012 / lane-a (RED → GREEN):**

- **Module:** `packages/engine-core/src/degradation.ts` (~208 LOC). New file under the wave-011 lane-a per-feature-files split convention. Re-exported via the `packages/engine-core/src/index.ts` barrel as `export * from './degradation.js';`.
- **Surface:**
  - `DegradationRung` union: `'normal' | 'skill-fallback' | 'model-fallback' | 'reduced-tool-set' | 'headless' | 'halt'` (6 values).
  - `DegradationTransition`: `{ rung: DegradationRung; at: string; trigger: string }` (FROM-rung snapshot recorded at transition time).
  - `DegradationState`: `{ current: DegradationRung; trigger: string; history: DegradationTransition[] }`.
  - `DegradationLadder` class:
    - `getCurrent(): DegradationRung`
    - `getState(): Readonly<DegradationState>`
    - `escalate(trigger: string): RunHaltedVerdict | null` — advances exactly one rung; returns null until 'halt'; returns a `RunHaltedVerdict` (trigger=`'degrade_escalate'`) when reaching/at 'halt'.
    - `recover(reason: string): void` — drops one rung; no-op at 'normal'; no-op from terminal 'halt'.
- **Verdict-shape reuse:** imports `RunHaltedVerdict` from `./halt.js` (first-owner rule per wave-011 lane-a); does NOT declare a parallel verdict type.
- **HaltTrigger union extension:** `halt.ts` `HaltTrigger` extended with the 14th value `'degrade_escalate'` (sibling trigger for ladder-top-reached, distinct from the existing 9th value `'degradation_threshold'` reserved for sliding-window threshold trips). Per `rules/minimum-change.md` the 1-line union extension is the smallest patch that preserves the F-018 verdict-shape contract.
- **Test coverage:** `tests/unit/F-021-degradation-ladder.test.ts` 11/11 PASS in 8ms — 7 acceptance scenarios + 2 sub-scenarios (5a/5b, 6a/6b) + 2 robustness checks (trigger-string preservation, getState snapshot shape).

**Reproduction recipe (vitest unit):**

```bash
pnpm vitest run tests/unit/F-021-degradation-ladder.test.ts
# Expected: Test Files 1 passed (1) | Tests 11 passed (11)
```

**Full suite at GREEN time:** 94/94 PASS across 14 test files. `npx tsc --noEmit` clean.
