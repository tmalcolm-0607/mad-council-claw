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
feature-id: F-085
short-slug: same-model-fallback
milestone: M10
provenance:
  surfaces:
    - kit:lens-multi-model-review-pattern.md
    - kit:rules/degradation-fallback-policy.md
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
  LOCKED if GREEN AND reviews/F-085-same-model-fallback-review.md exists with verdict: ACCEPT.
depends-on: [F-082, F-083, F-021]
out-of-scope-notes: |
  Multi-host fallback (e.g., Copilot CLI on a remote machine) is not in v1. The fallback path
  only covers the local-Copilot-missing case. CI environments without any Copilot CLI install
  use this same-model role-split path.
confidence: high
---

# F-085 — Same-model role-split fallback

## Behavior contract

When the dispatcher (F-082) detects Copilot CLI is unavailable, the orchestrator MUST fall back to two parallel `Task` calls (`subagent_type: general-purpose` for both lanes) on the SAME model with role-distinguishing prompts: Role A "Act as a security-first reviewer. Flag every plausible attack class." and Role B "Act as a correctness-first reviewer. Flag every plausible spec deviation." Same orchestration shape as the cross-model path (parallel dispatch → agreement table per F-083 → both-flag-CRITICAL hard-block per F-084), but with a WEAKER disagreement signal because both lanes share the same model's blind spots. The orchestrator MUST emit a Context Gap line per `kit:rules/degradation-fallback-policy.md` Rule 3: "Copilot CLI unavailable; using same-model role-split fallback. Cross-model signal weaker."

## Acceptance scenarios

1. **Given** Copilot CLI is not installed, **When** a skill activates `--council` mode, **Then** the orchestrator dispatches two parallel `Task` calls with role-distinguishing prompts on the same model AND emits the Context Gap line "Copilot CLI unavailable; using same-model role-split fallback. Cross-model signal weaker."
2. **Given** the same-model fallback runs, **When** both lanes flag the same CRITICAL finding, **Then** F-084 hard-block fires (the agreement-table semantics apply uniformly regardless of dispatch path).
3. **Given** the same-model fallback runs, **When** the consent gate (F-086) is evaluated, **Then** it does NOT fire (no third-party egress occurs in the fallback path).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/multi-model/fallback-when-copilot-missing.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/multi-model/fallback-hard-block-still-applies.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/multi-model/fallback-no-consent-gate.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-082 (fallback fires when dispatcher returns Copilot-unavailable rc), F-083 (fallback uses same agreement-table shape), F-021 (Context Gap emission)
- **Soft:** F-084 (hard-block applies uniformly), F-086 (consent gate explicitly skipped on this path)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:lens-multi-model-review-pattern.md | § Fallback (Copilot CLI unavailable) — exact role-distinguishing prompts |
| kit:rules/degradation-fallback-policy.md | Rule 3 — Context Gap reporting requirement on fallback path |
| ce:US-7 | Adversarial review story; fallback preserves the orchestration shape with weakened signal |
| ce:FR-MULTI-001 | Functional requirement: parallel adversarial dispatch (mode-agnostic) |
| cp:wave-002-wave-003-copilot-cli-design-review | First production proof: same-model role-split shape used pre-Copilot CLI |

## Implementation notes

(empty — populated when implementation begins)
