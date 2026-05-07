---
artifact-class: feature-ledger
generated-by: hand-authored (wave-004 / lane-b)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-004 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-064
short-slug: automations-multistep
milestone: M7
provenance:
  surfaces:
    - foundational-plan:M7-skills-perms-auto
    - cp:electron/automations/manager.ts
    - cp:electron/automations/types.ts
    - kit:rules/orchestration.md
    - kit:rules/degradation-fallback-policy.md
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
  LOCKED if GREEN AND reviews/F-064-automations-multistep-review.md exists with verdict: ACCEPT.
depends-on: [F-061]
out-of-scope-notes: |
  Single-step automations are F-061's base shape; this feature adds multi-step chaining.
  Cron triggers are F-062; condition triggers are F-063 — the multistep chain runs once per trigger, not once per step.
  Persistence of partial chain state across restarts is F-065.
  Step kinds in v1: skill-invoke, shell-exec, mcp-call, http-fetch, sleep, branch-on. Other kinds (loops, pipes) are v1.5.
  Parallel-step execution within a chain is OUT OF SCOPE for v1; chains are sequential.
configurable: |
  Step output is bound to a step `id` and addressable in subsequent steps via `${steps.<id>.output}` interpolation.
  On step failure, default policy is `halt-chain` (graceful partial completion per degradation-fallback rule 5); per-step `on_failure: "continue" | "halt"` overrides default.
confidence: high
---

# F-064 — Automations multistep

## Behavior contract

An automation's `steps` array runs sequentially. Each step has shape `{ id, kind, args, on_failure: "halt" | "continue" }`. On step success, output is captured to the run-context map keyed by `id` and is interpolatable into later steps via `${steps.<id>.output.<jsonPath>}`. On step failure with `on_failure: "halt"` (default), the chain stops and the run record records `{ status: "failed", failed_step_id, error }`. On `on_failure: "continue"`, the failure is logged but the next step proceeds. Chain progress is checkpointed after each step to `<state-dir>/automations/runs/<run_id>/checkpoint.json` (atomic write per `concurrency-safety.md` §2). A `branch-on` step kind takes a predicate over previous step outputs and routes to one of two named sub-step lists; this is the only conditional flow primitive in v1.

## Acceptance scenarios

1. **Given** an automation with steps `[{id: "a", kind: "shell-exec", args: {cmd: "git status"}}, {id: "b", kind: "skill-invoke", skill: "loop", args: {input: "${steps.a.output.stdout}"}}]`, **When** the chain runs, **Then** step `b` receives the stdout of step `a` AND the run completes `status: "succeeded"`.
2. **Given** a chain `[a, b, c]` where step `b` fails with `on_failure: "halt"`, **When** the chain runs, **Then** step `c` does NOT execute AND the run record contains `failed_step_id: "b", error: <message>`.
3. **Given** a chain whose step 2 of 5 has just completed, **When** the engine restarts mid-chain (simulated crash before step 3), **Then** the checkpoint at `<state-dir>/automations/runs/<run_id>/checkpoint.json` records `last_completed_step_id: "step-2"` (resume behavior is F-065's responsibility; this feature only verifies the checkpoint).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/automations/multistep-output-interpolation.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/automations/multistep-halt-on-failure.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/automations/multistep-checkpoint-write.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-061 (automations base — this feature extends step semantics)
- **Soft:** F-065 (persistence reads the checkpoints this feature writes), F-058 (each step still classified), F-021 (degradation policy applied per-step)
- **Independent:** F-062, F-063 (this feature is trigger-type-agnostic)

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M7-skills-perms-auto | "multistep" is item 14 of the M7 catalog list |
| cp:electron/automations/manager.ts | Manager dispatches steps sequentially |
| cp:electron/automations/types.ts | Step type contract from Zod |
| kit:rules/orchestration.md | Sequential step execution within a single automation chain mirrors orchestrator-worker pattern |
| kit:rules/degradation-fallback-policy.md | "halt vs continue" semantics on step failure |

## Implementation notes

(empty — populated when implementation begins)
