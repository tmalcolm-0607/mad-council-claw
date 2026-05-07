---
artifact-class: feature-ledger
generated-by: hand-authored (wave-007 / lane-a)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-007 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-118
short-slug: automation-cookbook
milestone: M17
provenance:
  surfaces:
    - cp:docs/automation
    - kit:rules/loop-cadence-discipline.md
    - kit:rules/autonomous-loop-discipline.md
    - kit:rules/loop-stop-language-discipline.md
    - foundational-plan.md M17 docs section
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
  LOCKED if GREEN AND reviews/F-118-automation-cookbook-review.md exists with verdict: ACCEPT.
depends-on: [F-023, F-024, F-029, F-115]
out-of-scope-notes: |
  Visual workflow builder UI for automation is OUT for v1 (text recipes only).
  Marketplace of community recipes is OUT (M11+ scope). Per-recipe scheduling
  beyond cron expressions is v1.5. Automation analytics / "which recipes ran
  this week" dashboard is OUT (telemetry is M16; recipe-specific analytics is
  v1.5). Recipe versioning + import/export between users is v1.5. Automated
  recipe-validity testing harness is v1.5.
confidence: high
---

# F-118 — Automation cookbook

## Behavior contract

The repo MUST ship `docs/automation-cookbook.md` containing 6+ end-to-end recipes covering common automation patterns the engine supports: (1) cron-driven daily briefing (uses M3 cron-heartbeat F-023 + M14 daily-briefing F-101), (2) headless CLI run via M4 CLI (F-024) for CI / scheduled tasks, (3) MCP-tool-driven multi-step automation (e.g. WorkIQ scan + Geneva log lookup + post to council channel), (4) self-pacing autonomous loop using `/loop` per `rules/autonomous-loop-discipline.md` and `rules/loop-cadence-discipline.md` profiles (mad-iteration 270s vs. deployment-watch 1500s; the forbidden zone is named explicitly), (5) multi-skill pipeline (`/mad-spec → /mad-plan → /mad-tasks → /mad-implement` chained against a feature ticket), (6) cross-machine A2A bridge automation (one engine posts to a council channel another engine reads). Each recipe has: prerequisites, step-by-step commands (copy-pasteable), expected wall-clock, expected outputs (log lines, file paths), and pitfalls. Recipes that touch dangerous operations (state-mutating MCP tools, automated council verdicts) MUST cite `rules/dangerous-operations-policy.md` and show the consent gate firing in the expected output. Loop-stop language follows `rules/loop-stop-language-discipline.md` — recipes use "iter N checkpoint" style, never "loop complete" mid-run.

## Acceptance scenarios

1. **Given** an engineer who has read the README + architecture-docs and has a running engine, **When** they pick recipe 4 (autonomous loop with mad-iteration cadence) and follow it, **Then** the engine runs the loop with `delaySeconds: 270` (warm-cache zone), the loop checkpoints emit "iter N checkpoint" language NOT "loop complete", and the loop exits cleanly when stop conditions are met — measured against the recipe's expected outputs.
2. **Given** a CI run on `main`, **When** the docs link-check + recipe-syntax-check job runs against `automation-cookbook.md`, **Then** every code block is parseable, every cited kit rule path resolves, every cron expression validates, every cited F-NNN ledger exists.
3. **Given** recipe 3 (MCP-tool multi-step automation) involves a state-mutating tool call, **When** an engineer follows the recipe, **Then** the recipe's "expected output" section explicitly shows the consent prompt firing, the explicit "yes" being typed, and the audit-log entry being written — the consent gate is named, not silently bypassed.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/e2e/docs/cookbook-recipe-4-autonomous-loop.test.ts` | e2e | RED | scenario 1 |
| (TBD) `tests/integration/docs/cookbook-link-and-syntax-check.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/docs/cookbook-recipe-3-consent-walkthrough.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-023 (cron-heartbeat; recipe 1 + 4), F-024 (headless CLI; recipe 2), F-029 (MCP runtime; recipe 3 + 5), F-115 (architecture docs; recipes cross-link to component boundaries)
- **Soft:** F-101 (daily briefing surface for recipe 1), F-026 (a2a bridge for recipe 6), every kit rule referenced (loop-cadence / autonomous-loop / loop-stop-language / dangerous-operations / no-silent-deferrals)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:docs/automation | clawpilot automation docs starting reference (if present); engine adapts to council-centric flows |
| kit:rules/loop-cadence-discipline.md | recipe 4 cites the named profiles (mad-iteration / deployment-watch) and forbidden zone explicitly |
| kit:rules/autonomous-loop-discipline.md | recipe 4 frames the loop's continuation contract; closing-bow language banned mid-run |
| kit:rules/loop-stop-language-discipline.md | recipe outputs use "iter N checkpoint" framing; verified by the recipe's expected-output section |
| foundational-plan.md M17 | docs scope: cookbook is the 5th M17 deliverable; ties the docs plane to runtime usage |

## Implementation notes

(empty — populated when implementation begins)
