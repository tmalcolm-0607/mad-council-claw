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
feature-id: F-019
short-slug: cost-ledger
milestone: M2
provenance:
  surfaces:
    - kit:foundational-plan.md "cost ledger" surface
    - kit:rules/no-invented-constraints.md
    - ce:per-agent cost ledger
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
  LOCKED if GREEN AND reviews/F-019-cost-ledger-review.md exists with verdict: ACCEPT.
depends-on: [F-002, F-013]
out-of-scope-notes: |
  Cost-budget enforcement (auto-halt when run exceeds budget) is gated on the user
  explicitly setting a budget per `rules/no-invented-constraints.md`. This feature
  records spend; it does NOT impose default budgets.
confidence: high
---

# F-019 — Per-agent cost ledger

## Behavior contract

Every `usage` event from a backend (per F-013) is converted to a cost-ledger row at `runs/<run_id>/cost-ledger.ndjson`. Each row carries `{run_id, agent_id, parent_run_id, ts_utc, backend, model, input_tokens, output_tokens, cache_read_tokens, cache_write_tokens, cost_usd}`. Costs are computed using a per-model price table (versioned in `pricing/<backend>.json`). Aggregations over the ledger (sum per agent, per run, per day) are deterministic. The ledger NEVER auto-imposes budgets — it records facts; budget enforcement requires explicit user opt-in per `rules/no-invented-constraints.md`.

## Acceptance scenarios

1. **Given** a backend that emits `usage: {input: 1000, output: 500}` for `claude-opus-4-7`, **When** the ledger writer consumes it, **Then** a row is appended with `cost_usd` matching the price table's per-token rate (input × $rate_in + output × $rate_out).
2. **Given** a ledger with 50 rows across 3 agents, **When** `aggregateBy("agent_id")` is called, **Then** the result is exact integer-token sums (no floating drift from JSON parsing) and dollar sums to 4 decimal places.
3. **Given** no budget configured, **When** a run logs $1000 of cost, **Then** the engine does NOT halt or warn — it just records (per `no-invented-constraints.md`).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/cost/price-computation.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/unit/cost/aggregation.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/integration/cost/no-invented-budget.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-002 (identity stamps every row), F-013 (usage events feed the ledger)
- **Soft:** F-008 (storage layout for `cost-ledger.ndjson`), F-006 (logger correlates)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md M2 | "cost ledger" surface |
| kit:rules/no-invented-constraints.md | NO default budgets — engine records, user decides |
| ce:per-agent cost ledger | shape (per-agent rows) |

## Implementation notes

(empty — populated when implementation begins)
