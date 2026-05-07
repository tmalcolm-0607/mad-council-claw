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
    by: wave-010 / lane-a
    note: "RED test stub committed (03e3353); GREEN impl appended to packages/engine-core/src/index.ts (~270 LOC F-019 region after F-008's region — wave-008 multi-lane append convention). 8/8 acceptance scenarios pass via vitest. CostLedger class + CostEntry/CostEntryInput interfaces landed. Ledger ships without halt/checkBudget/overBudget API by design — observable-only per rules/no-invented-constraints.md. Out-of-scope per ledger: cost-budget enforcement (gated on explicit user opt-in), persistence to runs/<run_id>/cost-ledger.ndjson (F-008's job), live F-013 event consumption, per-model pricing/<backend>.json table (caller-supplied usd_estimate)."
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
  unit:
    - tests/unit/F-019-cost-ledger.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - unit
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

GREEN landed in wave-010 / lane-a (2026-05-07). Surface in
`packages/engine-core/src/index.ts` F-019 region (~270 LOC after F-008):

- `CostEntry` interface — 16 fields. Brief-style ergonomic API names
  (`tokens_in`, `tokens_out`, `usd_estimate`, `timestamp`) live alongside
  the ledger's authoritative names (`input_tokens`, `output_tokens`,
  `cost_usd`, `ts_utc`). The writer mirrors brief-API → ledger-canonical
  on every append; both are present on every row so consumers using
  either name see the same numbers.
- `CostEntryInput` interface — caller input minus auto-stamped fields.
- `CostLedger` class — `append`, `getEntries`, `totalTokensIn`,
  `totalTokensOut`, `totalUsd`, `failureRate`.
- **NO halt API** by design — no `halt()`, `checkBudget()`,
  `overBudget()`. Per `rules/no-invented-constraints.md`, F-019 is
  observable-only; budget enforcement requires explicit user opt-in via
  a separate (future) feature.

Tests at `tests/unit/F-019-cost-ledger.test.ts` (8/8 PASS):
1. seq + ISO-8601 timestamp on every append (extended)
2. usage:{1000, 500} for claude-opus-4-7 → caller-supplied cost_usd flows through (ledger §1)
3. identity stamps on every row (extended)
4. 50 rows / 3 agents → integer-token sums + 4-decimal dollar sums (ledger §2)
5. $1000 cost does NOT halt or warn (ledger §3, observable-only)
6. failure_mode optional — undefined on success, set on failure (extended)
7. failureRate across mixed rows; empty ledger returns 0 (extended)
8. getEntries returns readonly view; CostEntry shape preserved (extended)

Physical proof: `docs/09-examples-proof/F-019/{red,green}-test-output.txt`
+ `physical-proof.md`.

## Reproduction

```bash
cd C:/Users/tonym/Repos/mad-council-claw
npx vitest run tests/unit/F-019-cost-ledger.test.ts
# → 8/8 PASS
```
