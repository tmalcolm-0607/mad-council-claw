---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: locked
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-009 / lane-c
    note: "RED test stub committed (eacc651); GREEN impl landed in HEAD's packages/engine-core/src/index.ts (~290 LOC F-018 region) per anomaly A1 below — the GREEN file blob was captured by sibling-lane commit da48f2a per the wave-008 lane-coexistence pattern. 9/9 acceptance scenarios pass via vitest. HaltDetector class + RunHaltedVerdict + HaltTrigger 12-value union (9 ledger + 3 sibling) + HaltContext + HaltDetectorConfig landed. Out-of-scope per ledger: F-006 logger surfacing, F-015 audit-evidence binding, F-020 kill-switch JSON watcher, F-021 degradation source signal, F-022 per-tool quota source."
  - status: locked
    at: 2026-05-07
    by: wave-013 / lane-d
    note: "Post-impl council review at docs/05-design-reviews/council-reviews/F-018-failure-pattern-halt-review.md verdict ACCEPT (Verdict consensus: APPROVE; median confidence 89; 0 CRITICAL / 0 MAJOR / 4 MINOR / 3 PRAISE). Source post-wave-011/lane-a engine-core split lives at packages/engine-core/src/halt.ts (269 LOC). 9/9 acceptance scenarios continue to PASS unchanged at review time. Per the red-green-rule predicate: LOCKED requires both GREEN AND review file with verdict: ACCEPT. Both conditions verified."
feature-id: F-018
short-slug: failure-pattern-halt
milestone: M2
provenance:
  surfaces:
    - kit:foundational-plan.md "halt" surface for M2
    - kit:rules/anomaly-thresholds.md
    - ce:halted_by_* trigger enum
fr-coverage: []
test-files:
  unit:
    - tests/unit/F-018-failure-pattern-halt.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - unit
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-018-failure-pattern-halt-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-014, F-015]
out-of-scope-notes: |
  Manual operator halt (kill-switch JSON) is owned by F-020. This feature is the
  AUTOMATIC failure-pattern halt that fires on detected anomalies (consecutive
  failures, OVERPLANNING, runaway spawns).
confidence: high
---

# F-018 — Failure-pattern halt

## Behavior contract

The engine watches a 9-value enum of trigger conditions: `consecutive_failures_3`, `consecutive_failures_10`, `overplanning_5`, `overplanning_8`, `spawns_per_hour_exceeded`, `token_anomaly_2x`, `rapid_prompt_burst`, `circuit_breaker_open`, `degradation_threshold`. When any trigger fires, the engine immediately transitions to `closing` with `halted_by: <trigger_name>` and `trigger_evidence_sha256: <audit_entry_sha>`. The retro signal (F-014) fires next, capturing the trigger evidence. Thresholds are sourced from `rules/anomaly-thresholds.md` and overridable per-run.

## Acceptance scenarios

1. **Given** an engine that records 3 consecutive failed cycles, **When** the 3rd failure lands, **Then** the engine transitions to `closing` with `halted_by: "consecutive_failures_3"` and the retro carries `trigger_evidence_sha256` matching the 3rd failure's audit entry.
2. **Given** an engine that observes 5 consecutive read-only Tool calls (Read/Grep/Glob with no Write/Edit), **When** the 6th would-be-read fires, **Then** the engine halts with `halted_by: "overplanning_5"` BEFORE the 6th call.
3. **Given** thresholds overridden via run config `consecutive_failures_3 = 10`, **When** the engine records 5 consecutive failures, **Then** no halt fires (threshold = 10 not yet reached); on the 10th failure, halt fires.

## Red→green wire-up

| Test file | Project | State | Verifies |
|---|---|---|---|
| `tests/unit/F-018-failure-pattern-halt.test.ts` | unit | GREEN (9/9 PASS) | scenarios 1, 2, 3 + extended (recordSuccess reset, overplanning reset, iteration_cap, tool_calls_quota, manualHalt, correlation triple) |
| (deferred) `tests/integration/halt/consecutive-failures.test.ts` | integration | F-006 + F-008 + F-015 deps | scenario 1 (filesystem + logger + audit-evidence integration) |
| (deferred) `tests/integration/halt/overplanning.test.ts` | integration | F-006 + F-008 + F-015 deps | scenario 2 (filesystem + logger + audit-evidence integration) |

**Scope note**: ledger originally named per-scenario test files split across `tests/integration/halt/` and `tests/unit/halt/`. Wave-009 / lane-c flipped F-018 GREEN as a single unit-level test (`tests/unit/F-018-failure-pattern-halt.test.ts`, 9 scenarios) covering all three ledger acceptance scenarios + 6 extended scenarios for the full HaltDetector surface, mirroring the F-014 / F-015 / wave-008 convention (`tests/unit/F-NNN-<slug>.test.ts`). Integration-level tests stay TBD against F-006 (logger surfacing) + F-008 (storage) + F-015 (audit-evidence binding). Per `rules/no-silent-deferrals.md`: deferred files explicitly named here, not silently dropped.

## Dependencies

- **Hard:** F-001 (lifecycle transitions), F-014 (retro consumes trigger_evidence_sha256), F-015 (audit log provides the SHA)
- **Soft:** F-006 (logger surfaces halt events), F-021 (degradation reuses anomaly thresholds)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md M2 | "halt" surface |
| kit:rules/anomaly-thresholds.md | 9-value enum + numeric thresholds |
| ce:halted_by_* | trigger enum from canonical-e |

## Implementation notes

**Wave-009 / lane-c GREEN flip** (2026-05-07):

`packages/engine-core/src/index.ts` — F-018 region (~290 LOC) adds the in-memory failure-pattern halt-detection primitive that F-020 (kill-switch), F-021 (degradation), F-022 (tool-quota) will reuse. Surface inventory:

- `HaltTrigger` union (12 values total):
  - **9-value ledger automatic-halt enum** (verbatim from behavior contract): `consecutive_failures_3`, `consecutive_failures_10`, `overplanning_5`, `overplanning_8`, `spawns_per_hour_exceeded`, `token_anomaly_2x`, `rapid_prompt_burst`, `circuit_breaker_open`, `degradation_threshold`.
  - **3 sibling triggers** for verdict-shape reuse: `manual` (F-020 kill-switch path), `iteration_cap` (F-001 cycle-cap reuse), `tool_calls_quota` (F-022 reuse). These are NOT new automatic anomaly classes — they are halt-source labels for the verdict's `trigger` field.
- `RunHaltedVerdict` interface — `{type:'RUN_HALTED', trigger, reason, timestamp, optional run_id/agent_id/trigger_evidence_sha256}`. Per the F-018 ledger acceptance contract: when any trigger fires, the engine transitions to `closing` with `halted_by: <trigger>` and `trigger_evidence_sha256` linking to the audit entry (F-015) that triggered the halt; the retro signal (F-014) fires next, capturing the evidence.
- `HaltContext` interface — caller-supplied F-002 correlation triple + F-015 evidence anchor at fire time. All fields optional because halt detection happens in the hot path where the full identity context may not be threaded.
- `HaltDetectorConfig` interface — per-run threshold overrides (`maxConsecutiveFailures`, `maxOverplanningReadOnly`, `maxIterations`, `maxToolCalls`). Defaults track `.claude/rules/anomaly-thresholds.md`: consecutive_failures=3, planning_turns_without_write=5, maxIterations=100, maxToolCalls=200. Override semantics (acceptance scenario 3): trigger NAMES stay canonical even when thresholds are overridden — the trigger identifies the FAMILY, not the count.
- `HaltDetector` class:
  - `recordFailure(context?)` → returns verdict at threshold, null otherwise; trigger=`consecutive_failures_3`.
  - `recordSuccess()` → resets the consecutive-failures counter.
  - `recordReadOnlyTool(context?)` → returns verdict at threshold, null otherwise; trigger=`overplanning_5`. Per ledger acceptance scenario 2, halt fires AT the 5th call (BEFORE the 6th could fire) — counter tests `>=` against the threshold.
  - `recordWriteTool()` → resets the read-only overplanning streak.
  - `recordIteration(context?)` → returns verdict at threshold, null otherwise; trigger=`iteration_cap`. Sibling trigger to F-001's `MAX_CYCLES_HARD_CAP` — the two coexist: F-001 enforces a hard cap of 50; F-018 surfaces a per-run override-able cap.
  - `recordToolCall(context?)` → returns verdict at threshold, null otherwise; trigger=`tool_calls_quota`. F-022 will source the per-tool quota separately.
  - `manualHalt(reason, context?)` → unconditional verdict; trigger=`manual`. F-020 will call this from its kill-switch JSON watcher. The caller-supplied reason is preserved verbatim.

Trigger-name reconciliation: the wave-009 / lane-c brief proposed a 7-trigger enum with simpler names (`consecutive_failures`, `no_progress`, `iteration_cap`, `tool_calls`, `manual`, `kill_switch`, `governance`, `soul_boundary`, `degrade_escalate`). The F-018 ledger names a different 9-value enum carrying threshold counts in the name. Per FETCH BEFORE CITE / wave-008 lane-a precedent, this impl encodes the ledger's enum + adds 3 sibling triggers for full HaltDetector surface coverage (`manual`, `iteration_cap`, `tool_calls_quota`). The 9-trigger automatic-halt enum stays intact.

**Out of scope** (per ledger out-of-scope-notes + soft-deps; explicit per `rules/no-silent-deferrals.md`):
- F-006 logger surfacing of halt events — logging-pipeline owns routing.
- F-008 filesystem persistence to `runs/<run_id>/runtime-state.json` — storage layout owns the on-disk shape.
- F-015 audit-evidence binding for `trigger_evidence_sha256` — the field is in the verdict shape but binding to a real audit row is F-015's integration step.
- F-020 kill-switch JSON file watcher — F-020 will call `manualHalt()` from its watcher.
- F-021 degradation source signal — F-021 will source the `degradation_threshold` trigger.
- F-022 per-tool quota source — F-022 will source the per-tool quota; this impl provides the global tool-call counter.

## Reproduction

```bash
cd C:/Users/tonym/Repos/mad-council-claw
pnpm install
pnpm exec vitest run tests/unit/F-018-failure-pattern-halt.test.ts
# Expected: "Test Files 1 passed (1)" + "Tests 9 passed (9)" + exit 0
```
