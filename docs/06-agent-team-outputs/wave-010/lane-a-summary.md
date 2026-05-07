---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-010 / lane-a)
wave: wave-010
lane: lane-a
topic: F-019-cost-ledger-RED-GREEN
date: 2026-05-07
status: complete
---

# Wave 10 / Lane A — F-019 cost-ledger RED → GREEN

## Scope

Ninth feature transition RED → GREEN in the repo (after F-001 / F-002 / F-006 / F-008 / F-014 / F-015 / F-016 / F-018). Second M2 governance feature to flip in the wave-009/wave-010 push beyond F-014/F-015/F-016 (which were already GREEN). The behavior-contract surface lands the in-memory cost-ledger primitive that F-013 (event-normalization) will feed, F-008 (storage layout) will persist to `runs/<run_id>/cost-ledger.ndjson`, and F-021 (degradation-fallback) will read for failure-mode aggregations.

## What was created / modified

| Group | Path | Type | Count |
|---|---|---|---|
| RED test stub | `tests/unit/F-019-cost-ledger.test.ts` | new | 1 |
| GREEN impl additions | `packages/engine-core/src/index.ts` (~270 LOC F-019 region appended after F-008's region) | modified | 1 |
| Ledger transition | `docs/03-feature-catalog/M2-governance-triad/F-019-cost-ledger.md` (status red→green; status-history; test-files; impl notes; reproduction) | modified | 1 |
| Roadmap update | `roadmap.md` (M2 5R+4G→4R+5G; TOTAL 28R+8G→27R+9G; F-019 detail row 🔴→🟢) | modified | 1 |
| Confidence-ledger entries | `docs/11-loop-state/confidence-ledger.md` (Lane A wave-010 section, 5 entries) | modified | 1 |
| Physical proof | `docs/09-examples-proof/F-019/physical-proof.md` | new | 1 |
| Vitest output capture | `docs/09-examples-proof/F-019/{red,green}-test-output.txt` | new | 2 |
| This summary | `docs/06-agent-team-outputs/wave-010/lane-a-summary.md` | new | 1 |
| **Total touched** | | | **9 artifacts** |

## Vitest output (GREEN)

```
RUN  v2.1.9 C:/Users/tonym/Repos/mad-council-claw

✓ tests/unit/F-019-cost-ledger.test.ts (8 tests) 12ms

Test Files  1 passed (1)
     Tests  8 passed (8)
```

Full unit suite at GREEN time (Lane A scope): **47/47 GREEN-feature tests pass** — 39 prior (F-001 / F-002 / F-006 / F-014 / F-015 / F-016 / F-018) + 8 F-019. Sibling-lane RED tests (F-020 kill-switch, F-022 tool-quota) still fail as expected; not Lane A's responsibility.

## RED→GREEN transition

| Phase | State | Test result |
|---|---|---|
| RED (commit `03e3353`) | `CostLedger` not exported; `CostEntry` type absent | 8/8 fail with `TypeError: CostLedger is not a constructor` |
| GREEN (this batch) | `CostLedger` class + `CostEntry` + `CostEntryInput` exported from `packages/engine-core/src/index.ts` (~270 LOC F-019 region after F-008's region) | 8/8 PASS |

Output captured: `docs/09-examples-proof/F-019/{red,green}-test-output.txt` + `physical-proof.md`.

## Surface inventory (the F-019 GREEN region)

- `CostEntry` interface — 16 fields. Brief-style ergonomic API names (`tokens_in`, `tokens_out`, `usd_estimate`, `timestamp`) coexist with the ledger's authoritative names (`input_tokens`, `output_tokens`, `cost_usd`, `ts_utc`). Mirrored on every append.
- `CostEntryInput` interface — caller input shape minus auto-stamped fields.
- `CostLedger` class — 6 methods:
  - `append(input: CostEntryInput): CostEntry`
  - `getEntries(): readonly CostEntry[]`
  - `totalTokensIn(): number` (exact integer)
  - `totalTokensOut(): number` (exact integer)
  - `totalUsd(): number` (floating-point; callers use 4-decimal compare)
  - `failureRate(): number` (range [0, 1]; 0 for empty ledger — NOT NaN)
- **Load-bearing absence**: NO `halt()`, `checkBudget()`, `overBudget()` API. Per `rules/no-invented-constraints.md`, F-019 is observable-only; budget enforcement requires explicit user opt-in via a separate (future) feature. Test scenario 3 asserts these methods are `undefined` to lock the contract in.

## Acceptance scenarios — 3 ledger + 5 extended

| # | Source | Scenario | Status |
|---|---|---|---|
| 1 | ledger | usage:{input:1000, output:500} for claude-opus-4-7 → row with cost_usd flowing through | ✅ |
| 2 | ledger | 50 rows / 3 agents → integer-token sums + 4-decimal dollar sums | ✅ |
| 3 | ledger | $1000 cost does NOT halt or warn (observable-only) | ✅ |
| 4 | extended | seq monotonic 0-based; ISO-8601 timestamp | ✅ |
| 5 | extended | identity stamps (run_id, agent_id) on every row | ✅ |
| 6 | extended | failure_mode optional — undefined on success, set on failure | ✅ |
| 7 | extended | failureRate computation across mixed rows; empty ledger → 0 | ✅ |
| 8 | extended | getEntries returns readonly view; full CostEntry shape preserved | ✅ |

## Scope deviation from prompt brief (intentional, per wave-009 lane-c precedent)

The wave-010 / lane-a brief proposed an 8-field CostEntry shape:
```typescript
{seq, timestamp, agent_id, run_id, tokens_in, tokens_out, usd_estimate, failure_mode?, model}
```

The F-019 ledger names an 11-field shape:
```
{run_id, agent_id, parent_run_id, ts_utc, backend, model, input_tokens, output_tokens,
 cache_read_tokens, cache_write_tokens, cost_usd}
```

Per FETCH BEFORE CITE / wave-009 lane-c precedent (honor authoritative ledger over brief snippet), this impl encodes the ledger's full shape on every row WHILE exposing the brief's simpler API as ergonomic aliases:
- `tokens_in` ↔ `input_tokens`
- `tokens_out` ↔ `output_tokens`
- `usd_estimate` ↔ `cost_usd`
- `timestamp` ↔ `ts_utc`

Both names present; consumers using either see the same numbers. The brief's added ergonomic fields (`seq`, `timestamp`, `failure_mode`) are preserved as siblings on the ledger row. The ledger's optional `parent_run_id` / `backend` / `cache_read_tokens` / `cache_write_tokens` are also exposed (defaulted to 0 / undefined as appropriate).

**Wave-10 takeaway (4th sighting of brief-vs-ledger divergence after wave-009 Lane A F-006, Lane C F-018, wave-010 Lane D F-008)**: the brief-generation tool needs a live-ledger lookup pass at brief-write time, surfacing divergences inline so future lane authors don't independently re-decide the reconciliation. Tracked as MEDIUM in confidence-ledger Lane-A-w10-brief-vs-ledger-shape-divergence; promote to HIGH if 5th sighting occurs.

## Multi-lane staging discipline (wave-10 mode)

Followed Lane D's wave-10 pattern. Concurrent lanes touched the working tree (F-008 / F-020 / F-022 RED stubs visible in `git status`); Lane A explicitly named only its own paths in `git add`:

- RED commit `03e3353`: `tests/unit/F-019-cost-ledger.test.ts` + `docs/09-examples-proof/F-019/red-test-output.txt`
- GREEN commit (this batch): the F-019 region of `packages/engine-core/src/index.ts` + ledger / roadmap / confidence-ledger / physical-proof / lane-summary updates

The pre-commit `pre-commit-validate.js` hook required explicit gate results in the commit message; baseline 39 PASS + 27 FAIL was surfaced (8/27 = this RED; remainder = sibling-lane RED). Single-shell `git add` + `git commit` works around the working-directory-reset-between-bash-calls quirk.

No commit-message misattribution; no sibling-lane contamination in Lane A's commits. Validates the wave-009 lane-c proposal that explicit per-lane staging discipline is sufficient for 4+ concurrent lanes when each lane stages its own paths only — no per-lane branches yet required.

## Out-of-scope (deferred per ledger §out-of-scope-notes)

1. Cost-budget enforcement (auto-halt) — gated on explicit user opt-in per `rules/no-invented-constraints.md`. F-019 records facts.
2. Persistence to `runs/<run_id>/cost-ledger.ndjson` — F-008's job. F-008 region landed in parallel (Lane D wave-10); integration is a future flip.
3. Live event consumption from F-013 (event-normalization). The ledger accepts pre-normalized rows; F-013 will feed it.
4. Per-model price table (`pricing/<backend>.json`). Caller-supplied `usd_estimate` is passed through verbatim; F-013 will compute it from the price table in a future flip.

## Loop-improvement candidates surfaced this lane

1. **Brief-vs-ledger reconciliation discipline at brief-generation time** (4th sighting). Promote to HIGH and elevate to a kit-level rule if 5th sighting occurs at wave-011.
2. **Load-bearing-absence test pattern** (HIGH). When a behavior contract names a rule like `no-invented-constraints.md` as load-bearing, the test surface should encode the absence as a negative assertion (`expect(typeof (instance as any).method).toBe('undefined')`). Lane A scenario 3 demonstrates this; recommend embedding in `rules/skill-standards.md` or a new pattern file.
3. **Pre-commit gate-validation hook works as designed** (HIGH). The hook required explicit gate results in the RED commit message, forcing the orchestrator to capture the actual unit-suite baseline (39 PASS / 27 FAIL) rather than asserting the RED state via prose alone. Reusable pattern — keep enforcing.
