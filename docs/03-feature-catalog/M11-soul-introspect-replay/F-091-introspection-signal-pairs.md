---
artifact-class: feature-ledger
generated-by: hand-authored (wave-005 / lane-c)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-005 / lane-c
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-091
short-slug: introspection-signal-pairs
milestone: M11
provenance:
  surfaces:
    - ce:FR-INTROSPECT-002
    - ce:FR-CALIBRATION-001
    - kit:rules/lens-multi-model-review-pattern.md
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
  LOCKED if GREEN AND reviews/F-091-introspection-signal-pairs-review.md exists with verdict: ACCEPT.
depends-on: [F-002, F-090]
out-of-scope-notes: |
  Multi-model adversarial grading (multiple grader peer-agents emitting independent
  outcome signals per `lens-multi-model-review-pattern.md`) is post-v1 — v1 is one grader
  per session. Cross-run calibration trend dashboards (visualization of CALIBRATION_DRIFT
  over time) are M12 visualization scope. Auto-remediation policies on CALIBRATION_DRIFT
  (e.g. drop agent's tool-quota when drift >= N) are deferred to v1.5.
confidence: high
---

# F-091 — Introspection signal pairs

## Behavior contract

After each session closes, a **grader peer-agent** (distinct identity from any work agent: `Grader.agent_id != work_agent_id` is a hard invariant) reads the run's introspection snapshots (per F-090) and the audit log (per F-015) and emits an **outcome signal** per agent per cycle to `runs/<run_id>/grader/<agent_id>/<cycle>.json`. Each outcome signal records the grader's score (1-5 per axis) and prose evidence. The engine then computes the **signal pair** `{self: snapshot.score, outcome: grader.score}`; pairs whose absolute axis-gap >= 2 mark the cycle with `CALIBRATION_DRIFT` and stamp the audit log. The grader runs post-session and is blocked from running concurrently against the same run.

## Acceptance scenarios

1. **Given** a closed run with 2 agents and 4 cycles, **When** the grader executes, **Then** `runs/<run_id>/grader/<agent_id>/<cycle>.json` exists for all 8 (agent x cycle) cells AND `Grader.agent_id` differs from both work-agent ids in every emitted signal.
2. **Given** an agent that self-rated `accuracy: 5` in cycle K and the grader scores `accuracy: 2`, **When** the pair is computed, **Then** the audit log has an entry `event: calibration_drift` with `fields.agent_id`, `fields.cycle: K`, `fields.axis: accuracy`, `fields.gap: 3`.
3. **Given** the grader is given the same `agent_id` as one of the work agents, **When** grader bootstrap runs, **Then** bootstrap rejects with `GRADER_IDENTITY_VIOLATION` naming the colliding agent_id; no signals are emitted.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/introspect/grader-emits-pairs.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/introspect/calibration-drift-detection.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/introspect/grader-identity-invariant.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-002 (agent identity invariant for grader vs work split), F-090 (snapshots are the input half of the pair)
- **Soft:** F-015 (audit log records calibration_drift events), F-014 (post-close grader emits at retro time)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-INTROSPECT-002 | Grader peer-agent (post-session); independence invariant `Grader.agent_id != work_agent_id` |
| ce:FR-CALIBRATION-001 | Self-confidence vs outcome-grade gap detection; CALIBRATION_DRIFT trigger |
| kit:rules/lens-multi-model-review-pattern.md | Adversarial second-opinion pattern applied to grader-vs-self signal pairing |

## Implementation notes

(empty — populated when implementation begins; consider grader model-tier policy under D-4 multi-tier-routing closure)
