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
feature-id: F-083
short-slug: cross-model-agreement-table
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
  LOCKED if GREEN AND reviews/F-083-cross-model-agreement-table-review.md exists with verdict: ACCEPT.
depends-on: [F-082]
out-of-scope-notes: |
  Hard-block enforcement on both-flag-CRITICAL findings is F-084 (decision logic, not table shape).
  Severity calibration per content-type is `kit:rules/prescriptive-content-review.md` § Severity
  calibration — table consumes that calibration but does not redefine it.
confidence: high
---

# F-083 — Cross-model agreement table

## Behavior contract

After the dispatcher (F-082) completes, the subagent reads `<OutputDir>/opus-result.json` + `<OutputDir>/gpt-result.json` and builds a cross-model agreement table with one row per finding. Each row carries: finding ID, finding title, severity, Opus state (`flagged | not-flagged`), GPT state (`flagged | not-flagged`), and decision class (`HARD BLOCK | SHOULD-FIX | CONSIDER`). Findings flagged by BOTH models at CRITICAL severity decide HARD BLOCK; findings flagged by only one model decide SHOULD-FIX (high-confidence single-model signal) or CONSIDER (lower severity). The orchestrator integrates the table into its synthesis WITHOUT re-reading raw `*-result.json` files (separation of concerns: subagent does dispatch + tabulation; orchestrator does decision).

## Acceptance scenarios

1. **Given** Opus + GPT both flag the same CRITICAL finding (e.g., SQL injection at line 42), **When** the agreement table is built, **Then** the row carries `Opus: flagged | GPT: flagged | Decision: HARD BLOCK`.
2. **Given** Opus flags a MAJOR finding that GPT does not flag, **When** the agreement table is built, **Then** the row carries `Opus: flagged | GPT: not-flagged | Decision: SHOULD-FIX (one-model signal)`.
3. **Given** GPT flags a MINOR naming finding that Opus does not flag, **When** the agreement table is built, **Then** the row carries `Opus: not-flagged | GPT: flagged | Decision: CONSIDER (one-model signal)`.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/multi-model/agreement-table-both-flag-critical.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/unit/multi-model/agreement-table-opus-only.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/unit/multi-model/agreement-table-gpt-only.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-082 (table consumes dispatcher output files)
- **Soft:** F-084 (HARD BLOCK decision class triggers hard-block enforcement), F-085 (fallback table uses same shape with weakened disagreement signal)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:lens-multi-model-review-pattern.md | § Output — exact agreement-table shape (4 columns: Finding / Opus / GPT / Decision) |
| ce:US-7 | Cross-model adversarial review story; "use the two as adversarial cross-checks" |
| ce:FR-MULTI-001 | Synthesis requirement: structured cross-model findings |
| cp:wave-002-wave-003-copilot-cli-design-review | First instance: revealed the orchestrator-side integration pattern (table not raw JSON) |

## Implementation notes

(empty — populated when implementation begins)
