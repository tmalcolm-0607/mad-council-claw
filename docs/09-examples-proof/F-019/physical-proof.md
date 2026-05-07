---
artifact-class: physical-proof
generated-by: hand-authored (wave-010 / lane-a)
wave: wave-010
lane: lane-a
feature: F-019
date: 2026-05-07
status: complete
---

# F-019 cost-ledger — physical proof

## RED state

Commit: `03e3353` — `test(F-019): RED test stub for cost-ledger`

```
TypeError: CostLedger is not a constructor
 ❯ tests/unit/F-019-cost-ledger.test.ts:* (8 occurrences)

Test Files  1 failed (1)
     Tests  8 failed (8)
```

Full RED output: [`red-test-output.txt`](red-test-output.txt).

## GREEN state

Commit: (this batch) — adds `CostLedger` class + `CostEntry` / `CostEntryInput` interfaces to `packages/engine-core/src/index.ts` (~270 LOC F-019 region appended after the F-008 region).

```
RUN  v2.1.9 C:/Users/tonym/Repos/mad-council-claw

✓ tests/unit/F-019-cost-ledger.test.ts (8 tests) 12ms

Test Files  1 passed (1)
     Tests  8 passed (8)
```

Full GREEN output: [`green-test-output.txt`](green-test-output.txt).

## Acceptance scenario coverage

| Ledger scenario | Test name | PASS |
|---|---|---|
| 1 — usage:{1000, 500} for claude-opus-4-7 → row with cost_usd | scenario 1: ... → row with cost_usd from caller-supplied estimate | ✅ |
| 2 — 50 rows / 3 agents → integer-token sums + 4-decimal dollar sums | scenario 2: aggregations across 50 rows / 3 agents | ✅ |
| 3 — $1000 cost does NOT halt or warn (observable-only) | scenario 3: observable-only — logging $1000 cost does NOT halt or warn | ✅ |

## Extended scenario coverage (full surface)

| Extended scenario | Test name | PASS |
|---|---|---|
| seq monotonic + ISO-8601 timestamp | scenario 4: append entries gain sequential seq starting at 0 ... | ✅ |
| identity stamps on every row | scenario 5: identity stamps (run_id, agent_id) are present on every row | ✅ |
| failure_mode optional | scenario 6: failure_mode is optional — undefined on success, set on failure | ✅ |
| failureRate computation | scenario 7: failureRate computes correctly across mixed success/failure rows | ✅ |
| CostEntry shape preservation | getEntries returns a readonly view; CostEntry stamps preserve all fields | ✅ |

## Surface inventory (the F-019 GREEN region)

- `CostEntry` interface — full ledger row (16 fields incl. brief-style ergonomic aliases + ledger-canonical names)
- `CostEntryInput` interface — caller-supplied input (writer auto-stamps seq + timestamp + alias-mirroring)
- `CostLedger` class:
  - `append(input: CostEntryInput): CostEntry`
  - `getEntries(): readonly CostEntry[]`
  - `totalTokensIn(): number` (exact integer)
  - `totalTokensOut(): number` (exact integer)
  - `totalUsd(): number` (floating-point; callers use 4-decimal compare)
  - `failureRate(): number` (range [0, 1]; 0 for empty ledger)
- NO `halt()` / `checkBudget()` / `overBudget()` — load-bearing absence per `rules/no-invented-constraints.md`

## Out-of-scope (deferred per ledger §out-of-scope-notes)

- Cost-budget enforcement (auto-halt) — gated on explicit user opt-in per `rules/no-invented-constraints.md`
- Persistence to `runs/<run_id>/cost-ledger.ndjson` — F-008's job (the F-008 region in the same file landed in parallel; integration is a future flip)
- Live event consumption from F-013 (event-normalization)
- Per-model price table (`pricing/<backend>.json`) — F-013 will compute `usd_estimate` from this in a future flip
