---
artifact-class: council-review
feature-id: F-019
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-013 / lane-d
---

# F-019 cost-ledger — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 90 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 78 |
| architect-lens | Architect | APPROVE | 89 |

Median confidence: 89

## Implementation reviewed

- `packages/engine-core/src/cost.ts` — 216 LOC; `CostEntry` interface (16 fields; brief-API-name + ledger-canonical-name aliases on every alias-pair), `CostEntryInput` interface (caller input minus auto-stamped fields), `CostLedger` class with `append`, `getEntries`, `totalTokensIn`, `totalTokensOut`, `totalUsd`, `failureRate`. Split from `index.ts` in wave-011/lane-a per the engine-core split refactor.
- `tests/unit/F-019-cost-ledger.test.ts` — 8 acceptance scenarios; all PASS at review time (8/8 PASS in 10ms).
- Commit history per ledger status-history: F-019 RED at wave-002 / lane-b (initial ledger); F-019 GREEN at wave-010 / lane-a (RED test stub `03e3353`; GREEN impl appended to `index.ts` as ~270 LOC F-019 region per the wave-008 multi-lane append convention); engine-core split (wave-011/lane-a) carved `cost.ts` out of `index.ts` with no behavior change.

## Advocate lens

**Verdict: APPROVE (confidence 90)**

- Implementation is minimal and correct per `minimum-change.md`: 216 LOC delivers the entire append-only cost ledger primitive plus 4 deterministic aggregations + 1 failure-rate metric. The deliberate ABSENCE of a halt API (`halt()`, `checkBudget()`, `overBudget()`) is itself a load-bearing design decision per `rules/no-invented-constraints.md` — the ledger records facts, the user opts into budget enforcement.
- All 8 acceptance scenarios PASS: scenarios 1, 2, 3 verify the three ledger acceptance contracts (per-token cost flows through, integer-token + 4-decimal-dollar deterministic aggregation, $1000 cost does NOT halt or warn); the 5 extended scenarios cover seq+ISO-8601 stamping, identity-triple stamping, optional `failure_mode`, mixed-row failureRate computation, and read-only `getEntries` view.
- Alias-pair design (`tokens_in` ↔ `input_tokens`, `tokens_out` ↔ `output_tokens`, `usd_estimate` ↔ `cost_usd`, `timestamp` ↔ `ts_utc`): both names co-exist on every row so consumers using either the brief's ergonomic API names OR the ledger's canonical names see the same numbers. The writer mirrors brief-API → ledger-canonical at append time. Unifies two competing naming conventions without forcing callers to choose.
- Per ce:per-agent-cost-ledger + kit:rules/no-invented-constraints.md: F-019 explicitly does NOT impose default budgets. The ledger is observable-only — ce:US-2 (every governance feature stamps run_id + agent_id) is satisfied via mandatory `agent_id`/`run_id` on `CostEntryInput`; budget enforcement is an explicit user opt-in via a separate (future) feature. The asymmetry is intentional and aligns with `rules/no-invented-constraints.md`'s "do not invent budgets the user has not set" mandate.
- Surface trace per ledger: `kit:foundational-plan.md M2 "cost ledger" surface` + `kit:rules/no-invented-constraints.md` (NO default budgets) + `ce:per-agent cost ledger` (per-agent rows). Provenance is auditable; the public surface (`CostEntry`, `CostEntryInput`, `CostLedger` class) matches what the ledger contract describes.

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 78)**

- F-019 lands the in-memory primitive only. Out-of-scope per the ledger: budget enforcement (gated on explicit user opt-in), persistence to `runs/<run_id>/cost-ledger.ndjson` (F-008's job), live F-013 event consumption (F-013 normalizes backend usage events; F-019 currently consumes caller-supplied `usd_estimate` rather than computing from a per-model price table at append time), per-model pricing/`<backend>.json` table. Acceptable for v1; the boundary is in place. Surfaced honestly per `no-silent-deferrals.md` — the ledger §Implementation notes + this review enumerate the deferred integrations explicitly.
- Pricing-table absence: the ledger acceptance scenario 1 says "cost_usd matching the price table's per-token rate". The current impl takes `usd_estimate` from the caller verbatim — there is no price-table lookup in `cost.ts`. This is the right scope split (the price table is `pricing/<backend>.json` per the ledger), but a reader could mistake "F-019 LOCKED" for "cost-from-tokens computation is implemented." Surfaced honestly: F-019 is the LEDGER primitive; the COMPUTATION primitive (price-table lookup + token-to-USD conversion) is a distinct future feature that feeds F-019.
- F-002 identity composition is partial: `CostEntryInput` requires `agent_id` + `run_id` (mandatory), and `parent_run_id` is optional. This means any caller MUST supply identity at the boundary — that's the rejection contract. BUT the boundary is purely structural — there's no compile-time link between `CostEntryInput.agent_id` and a real `Agent` object from F-002. A caller could pass any string. Same gap-class as F-002's audit-writer integration follow-on (F-006/F-008/F-019 do not yet call `stampIdentity()`). Surfaced honestly per `no-silent-deferrals.md`.
- Floating-point arithmetic on `totalUsd`: the test uses `toBeCloseTo` with 4 decimal places per the ledger acceptance scenario 2. Sum of 50 rows of fractional dollars accumulates floating drift; production callers comparing for equality MUST use 4-decimal-tolerance comparisons or migrate to integer-cents arithmetic. Documented in this review; backlog candidate: a `totalUsdCents()` method that returns integer cents to eliminate drift.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `packages/engine-core/src/cost.ts` lines 1-216 and `tests/unit/F-019-cost-ledger.test.ts` directly. Implementation matches the contract. The class is `readonly entries: CostEntry[] = []` private — `getEntries()` returns the raw array typed as `readonly CostEntry[]` (line 174-176). The doc-comment correctly warns that mutating it (or any entry) corrupts aggregations; defensive-copy is the caller's job. The shape is forward-compatible: a future F-008 storage integration can add an `appendToFile` sink without changing the in-memory contract.

## Architect lens

**Verdict: APPROVE (confidence 89)**

- File-split posture: `cost.ts` lives in `packages/engine-core/src/` per wave-011/lane-a engine-core split. Module boundary is clean — `cost.ts` exports the ledger primitive as the FIRST owner; barrel re-export through `packages/engine-core/src/index.ts`. Zero imports of other engine-core modules — `cost.ts` is a pure-data primitive with no compile-time deps on `halt.ts` / `identity.ts` / `logger.ts`.
- Public API surface (`CostEntry` + `CostEntryInput` + `CostLedger` class): symmetric and predictable. The 4 aggregation methods + 1 failure-rate metric form a complete read-side contract for downstream consumers (telemetry exporters, retro signal authors, M16 metrics emitters). Future extensions (per-day aggregation, per-backend aggregation, per-model histogram) are additive — no breaking change to the existing methods.
- Append-only discipline: `entries: CostEntry[]` is `private readonly` (line 123). The array reference cannot be reassigned; entries are pushed inside `append()` only. No public mutation path other than `append`. NDJSON output via F-008 storage integration will preserve this monotonic-append semantic naturally.
- Auto-stamped fields: `seq` (monotonic 0-based via `entries.length`) + `timestamp`/`ts_utc` (ISO-8601 UTC at append-time) are stamped inside `append()` so callers cannot forge them. The seq + timestamp pair gives downstream consumers two independent total-orders (monotonic counter + wall-clock time) for replay deterministically.
- Optional-field-omission discipline: `parent_run_id`, `backend`, `failure_mode` are conditionally added to the entry only when defined on the input (lines 155-163). Avoids serializing `undefined` fields into JSON output — clean NDJSON for F-008 + F-014 retro + M16 telemetry consumers. Same architecturally-clean discipline as F-002's `parent_run_id?` omission and F-018's `halt()` private helper.
- Hard deps per ledger: F-002 (identity stamps every row), F-013 (usage events feed the ledger). Soft deps on F-008 (storage layout for `cost-ledger.ndjson`) + F-006 (logger correlates). The current impl has ZERO compile-time deps on F-002/F-013/F-008/F-006 — pure boundary primitive. The deps materialize at call-site (engine code routes F-013 events through F-002-stamped `CostEntryInput` into `CostLedger.append`, with F-008's storage sink writing to the right path, with F-006's logger emitting correlation events). This compose-at-call-site shape is forward-compatible.

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | F-013 event-consumption follow-on: `usd_estimate` is caller-supplied today; the price-table lookup (`pricing/<backend>.json` per ledger) and F-013-driven backend-usage event normalization are deferred. A reader could mistake "F-019 LOCKED" for "cost-from-tokens computation implemented." | Accept; ledger §Implementation notes explicit; backlog item: "cost-computation-from-pricing-table" F-NNN follow-on (or fold into F-013 integration). |
| F2 | MINOR | F-008 persistence follow-on: ledger lives in memory only; `runs/<run_id>/cost-ledger.ndjson` shape is F-008's job. State is lost across engine restarts. | Accept; explicit per ledger §Implementation notes; F-008 integration is the materialization path. |
| F3 | MINOR | F-002 identity composition is structural-only: `CostEntryInput.agent_id`/`.run_id` are required strings, but no compile-time link to a real `Agent` from F-002. Same gap-class as F-006 / F-008 / F-019 audit-writer integration follow-on. | Accept; pairs with the F-002 audit-writer integration follow-on (see F-002 review F2). |
| F4 | MINOR | Floating-point drift on `totalUsd`: 50-row sum of fractional dollars accumulates drift; tests use `toBeCloseTo` with 4 decimal places. Production callers must mirror the 4-decimal-tolerance discipline or migrate to integer-cents. | Accept; backlog item: a `totalUsdCents()` method (integer cents) to eliminate drift for strict-equality comparisons. |
| F5 | PRAISE | Deliberate ABSENCE of a halt/budget API per `rules/no-invented-constraints.md`. Recording facts ≠ imposing constraints. The asymmetry (additions OK; budgets require explicit user opt-in) is intentional and load-bearing. | Keep. |
| F6 | PRAISE | Alias-pair design (brief-API + ledger-canonical names co-existing on every row) unifies two competing naming conventions without forcing callers to choose. Both producers and consumers see the same numbers regardless of which name they read. | Keep. |
| F7 | PRAISE | Optional-field-omission discipline: `parent_run_id`, `backend`, `failure_mode` are conditionally added rather than serialized as `undefined`. Clean NDJSON output for F-008 + F-014 + M16 telemetry consumers. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 89).

F-019 minimal-contract is implemented correctly; all 8 acceptance scenarios pass per the recorded green-test-output proof and re-verified at review time; no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-019 ledger frontmatter (`LOCKED if GREEN AND reviews/F-019-cost-ledger-review.md exists with verdict: ACCEPT`).

The MINOR findings are honest scope-narrowing notes per `no-silent-deferrals.md` — they are surfaced in this review (and in the F-019 ledger §Implementation notes), not silently elided. Future deeper integration work (cost-from-tokens computation; filesystem persistence; identity-stamping enforcement; integer-cents arithmetic) is scoped to future F-NNNs, not a re-scoping of F-019's contract.

F-019 transitions GREEN → LOCKED.

## Cross-references

- Ledger: `docs/03-feature-catalog/M2-governance-triad/F-019-cost-ledger.md`
- Source: `packages/engine-core/src/cost.ts` (split from `index.ts` in wave-011/lane-a)
- Tests: `tests/unit/F-019-cost-ledger.test.ts` (8/8 PASS)
- GREEN proof: `docs/09-examples-proof/F-019/{red,green}-test-output.txt` + `physical-proof.md` (per ledger §Implementation notes)
- GREEN transition: ledger status-history wave-010 / lane-a
- Engine-core split: wave-011 / lane-a (no behavior change; `cost.ts` carved out as authoritative location)
- Review verdict envelope: per `docs/05-design-reviews/README.md`
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle
- Precedent: `docs/05-design-reviews/council-reviews/F-001-engine-bootstrap-loop-review.md` (first LOCKED transition; wave-011 / lane-b); F-002/F-006/F-008 reviews (parallel-triple LOCKED transition; wave-012 / lane-d)
