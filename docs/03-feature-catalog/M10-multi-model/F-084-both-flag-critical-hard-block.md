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
feature-id: F-084
short-slug: both-flag-critical-hard-block
milestone: M10
provenance:
  surfaces:
    - kit:lens-multi-model-review-pattern.md
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
  LOCKED if GREEN AND reviews/F-084-both-flag-critical-hard-block-review.md exists with verdict: ACCEPT.
depends-on: [F-083]
out-of-scope-notes: |
  Bypass / override of a HARD BLOCK requires explicit user consent — covered by F-086
  (first-use-consent-gate already preserves consent semantics; explicit override is
  out of scope for v1, tracked in M19-deferred backlog).
confidence: high
---

# F-084 — Both-flag-CRITICAL hard block

## Behavior contract

When the cross-model agreement table (F-083) contains ≥1 row with `Opus: flagged | GPT: flagged | Severity: CRITICAL`, the orchestrator MUST emit a HARD BLOCK verdict and refuse to proceed with `ACCEPT` or `wait-for-author` paths. The only valid forward paths are `wait-for-author` (the author addresses the finding and re-runs the review) or `reject`. A HARD BLOCK cannot be dismissed by orchestrator-side reasoning, downstream skill rationalization, or user override without an explicit consent gate (out of scope for v1). This is the load-bearing precision improvement: a single model can rationalize a CRITICAL finding away; two models agreeing is high-precision adversarial signal.

## Acceptance scenarios

1. **Given** an agreement table with one row `Opus: flagged | GPT: flagged | Severity: CRITICAL (SQL injection)`, **When** the orchestrator computes its synthesis, **Then** the verdict is HARD BLOCK and the only emitted next-action options are `wait-for-author` or `reject`.
2. **Given** an agreement table with three CRITICAL findings, ALL three flagged by only one model each, **When** the orchestrator computes its synthesis, **Then** the verdict is NOT HARD BLOCK (each is SHOULD-FIX one-model signal); orchestrator may emit `accept-with-fixes` or `wait-for-author`.
3. **Given** a HARD BLOCK verdict, **When** the orchestrator attempts to proceed past it without `wait-for-author` / `reject`, **Then** the harness rejects the proceed action and persists the violation to audit (F-015 hash-chained log).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/multi-model/hard-block-on-both-critical.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/unit/multi-model/no-hard-block-on-single-model-criticals.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/multi-model/hard-block-bypass-rejected.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-083 (consumes the agreement table)
- **Soft:** F-015 (hard-block bypass attempts logged to audit), F-018 (HARD BLOCK is a halt-equivalent gate within review pipeline)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:lens-multi-model-review-pattern.md | § Output — "Both-flag-CRITICAL → hard block" verbatim |
| ce:US-7 | Adversarial cross-check user story (precision improvement is the story's payoff) |
| ce:FR-MULTI-001 | FR mandates blocking semantics on cross-model agreement |
| cp:wave-002-wave-003-copilot-cli-design-review | Production proof: orchestrator must not rationalize away both-model agreement |

## Implementation notes

(empty — populated when implementation begins)
