---
artifact-class: feature-ledger
generated-by: hand-authored (wave-005 / lane-b)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-005 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-082
short-slug: council-mode-dispatch
milestone: M10
provenance:
  surfaces:
    - kit:lens-multi-model-review-pattern.md
    - kit:Invoke-CopilotMultiModel.ps1
    - ce:US-7
    - ce:FR-MULTI-001
    - cp:wave-002-wave-003-copilot-cli-design-review
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
  LOCKED if GREEN AND reviews/F-082-council-mode-dispatch-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-008, F-013]
out-of-scope-notes: |
  Skill-side `--council` mode wiring on individual skills (pr-review, code-reviewer, etc.) is the
  inheritance contract per `kit:rules/skill-standards.md` Dimension 6 — covered by F-087
  (high-blast-radius-skills-wired). This ledger covers the dispatcher mechanism only.
  Agreement-table synthesis is F-083; both-flag-CRITICAL hard-block is F-084.
confidence: high
---

# F-082 — Council-mode dispatch

## Behavior contract

The orchestrator MUST NOT invoke `Invoke-CopilotMultiModel.ps1` directly (per `kit:rules/orchestrator-identity.md` Rule 1). When a skill activates `--council` mode, the orchestrator spawns a Task-tool subagent (`subagent_type: general-purpose`) that runs the dispatcher script with `-PromptFile` and `-OutputDir` arguments. The dispatcher detects Copilot CLI (`which copilot` / `which agency`), spawns two `copilot --yolo -p ...` processes in parallel (Claude Opus + GPT-5+), waits for both, and writes structured outputs to `<OutputDir>/opus-result.json` and `<OutputDir>/gpt-result.json`. The subagent reads both files and returns the cross-model agreement table to the orchestrator.

## Acceptance scenarios

1. **Given** a skill with `--council` mode active and Copilot CLI installed, **When** the orchestrator dispatches via Task-tool subagent, **Then** the subagent invokes `Invoke-CopilotMultiModel.ps1`, both model processes complete in parallel, and `<OutputDir>/{opus-result.json, gpt-result.json}` exist with structured findings.
2. **Given** an orchestrator that attempts to invoke the dispatcher script directly (bypassing the Task subagent), **When** the dispatch is attempted, **Then** the orchestration violates `orchestrator-identity.md` Rule 1 and the harness rejects the invocation (orchestrator's tool surface does not include Bash for dispatcher invocation).
3. **Given** Copilot CLI is unavailable on the host, **When** `--council` mode is requested, **Then** the dispatcher returns rc=2 with a clear "Copilot CLI not detected" message and the skill falls back per F-085 (same-model role-split fallback).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/multi-model/council-dispatch-happy-path.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/unit/multi-model/orchestrator-direct-invocation-blocked.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/multi-model/copilot-cli-missing.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (lifecycle — dispatch happens within a run cycle), F-008 (storage layout for `<OutputDir>`), F-013 (events.md — emits `multi_model_dispatch_started` / `multi_model_dispatch_completed`)
- **Soft:** F-083 (agreement-table consumes the two result files), F-085 (fallback path when Copilot CLI missing), F-086 (consent gate fires before first dispatch per session)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:lens-multi-model-review-pattern.md | Canonical Task-tool subagent-spawn shape (Steps 1-5) |
| kit:Invoke-CopilotMultiModel.ps1 | Dispatcher script: param block, Copilot CLI detection, parallel Start-Job dispatch |
| ce:US-7 | User story for cross-model adversarial review |
| ce:FR-MULTI-001 | Functional requirement: parallel dispatch to ≥2 models |
| cp:wave-002-wave-003-copilot-cli-design-review | First production proof-of-concept; surfaced the orchestrator-direct-invocation anti-pattern |

## Implementation notes

(empty — populated when implementation begins)
