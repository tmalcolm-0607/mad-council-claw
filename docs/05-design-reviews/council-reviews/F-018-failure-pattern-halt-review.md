---
artifact-class: council-review
feature-id: F-018
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-013 / lane-d
---

# F-018 failure-pattern-halt — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 91 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 76 |
| architect-lens | Architect | APPROVE | 89 |

Median confidence: 89

## Implementation reviewed

- `packages/engine-core/src/halt.ts` — 269 LOC; `HaltTrigger` (14-value union: 9 ledger automatic + 4 sibling + `degrade_escalate` from F-021), `RunHaltedVerdict` interface, `HaltContext` interface, `HaltDetectorConfig` interface, `HaltDetector` class with 6 record-* methods + `manualHalt()` + private `halt()` helper. Split from `index.ts` in wave-011/lane-a per the engine-core file-split refactor.
- `tests/unit/F-018-failure-pattern-halt.test.ts` — 9 acceptance scenarios; all PASS at review time (9/9 PASS in 8ms; full vitest run for the four LOCKED-candidate features 36/36 PASS in 1.34s).
- Commit history per `docs/07-roadmap/decision-log.md` + ledger status-history: F-018 RED at wave-002 / lane-b (initial ledger); F-018 GREEN at wave-009 / lane-c (RED test stub `eacc651`; GREEN impl absorbed into sibling-lane commit `da48f2a` per the wave-008 lane-coexistence anomaly A1 documented in `lane-c-summary.md`); engine-core split (wave-011/lane-a) carved `halt.ts` out of `index.ts` with no behavior change.

## Advocate lens

**Verdict: APPROVE (confidence 91)**

- Implementation is minimal and correct per `minimum-change.md`: 269 LOC delivers the full automatic-halt detection primitive plus the verdict shape that F-020 (kill-switch), F-021 (degradation-fallback), and F-022 (tool-quota) all reuse — single uniform `RunHaltedVerdict` shape across the entire governance triad. Single source of truth for halt taxonomy.
- All 9 acceptance scenarios PASS: scenarios 1, 2, 3 verify the three ledger acceptance contracts (consecutive_failures threshold, overplanning at the 5th read-only call, threshold override leaves trigger NAME canonical); the 6 extended scenarios cover `recordSuccess`/`recordWriteTool` reset semantics, `iteration_cap` sibling trigger, `tool_calls_quota` sibling trigger, `manualHalt` unconditional verdict, and the F-002 correlation triple flow-through.
- Trigger taxonomy is authoritative — the `HaltTrigger` union is the single export that every other halt-emitting feature in M2 imports. F-020 emits `manual`, F-021 emits `degrade_escalate`, F-022 emits `tool_calls`; the 9-value automatic-halt enum stays intact per the ledger contract. One union, one verdict shape, one consumer (F-014's retro signal).
- Per ce:halted_by_* + kit:rules/anomaly-thresholds.md: F-018 sources thresholds from the kit's anomaly-thresholds rule (consecutive_failures=3, planning_turns_without_write=5) and defaults to the kit's published values. Per-run override semantics preserve trigger names (acceptance scenario 3) so audit replays remain stable across config drift.
- The `halt()` private helper centralizes verdict construction with optional context fields conditionally added (lines 247-268 of `halt.ts`). Avoids serializing `undefined` fields into JSON — clean NDJSON output for downstream features.

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 76)**

- F-018 lands the in-memory primitive only. Out-of-scope per the ledger §Implementation notes: F-006 logger surfacing of halt events, F-008 filesystem persistence to `runs/<run_id>/runtime-state.json`, F-015 audit-evidence binding for `trigger_evidence_sha256` (the field is in the verdict shape but not yet bound to a real audit row), F-020 kill-switch JSON file watcher (F-020 will call `manualHalt()`), F-021 degradation-source signal (F-021 emits `degrade_escalate` directly via its own primitive), F-022 per-tool quota source. Acceptable for v1; the boundary is in place. Surfaced honestly per `no-silent-deferrals.md` — both the ledger §Implementation notes "Out of scope" block and this review enumerate the deferred integrations explicitly.
- Trigger-name reconciliation: the wave-009 / lane-c brief proposed a 7-trigger enum with simpler names (`consecutive_failures`, `no_progress`, etc.). The ledger names a different 9-value enum carrying threshold counts in the name (`consecutive_failures_3`, `consecutive_failures_10`, etc.). The impl encodes the ledger's enum + adds 4 sibling triggers. The reconciliation is honest; a future reader should expect the trigger NAMES to be stable taxonomy (not literal counter readings) — the ledger acceptance scenario 3's "trigger name stays canonical even when threshold is overridden" makes this explicit. Worth keeping eyes on as the eventual `consecutive_failures_10` (the higher escalation tier) is currently emitted by the SAME `recordFailure()` path as `consecutive_failures_3` — the difference is config-only, not source-line-only.
- Threshold defaults vs anomaly-thresholds.md drift risk: the ledger asserts thresholds are "sourced from `rules/anomaly-thresholds.md` and overridable per-run". The impl hard-codes defaults (`consecutive_failures=3`, `planning_turns_without_write=5`, `maxIterations=100`, `maxToolCalls=200`) inside `HaltDetectorConfig`. There is NO compile-time link to `anomaly-thresholds.md`. If kit rule values change, the impl defaults won't auto-update. Documented in this review; backlog candidate: a config-source loader that reads `anomaly-thresholds.md` at boot.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `packages/engine-core/src/halt.ts` lines 1-269 and `tests/unit/F-018-failure-pattern-halt.test.ts` directly; the implementation matches the contract; the trigger union has 14 values (not 13 as some prior wave notes claim — `degrade_escalate` was added in wave-12/lane-a as the F-021 hand-off trigger and is now part of the F-018 `HaltTrigger` surface). Counter increments BEFORE the threshold compare (line 161-167 + line 184-194 + line 208-218 + line 226-236) so verdict reasons report the actual breach value, not the threshold ("3 consecutive failures reached threshold 3"). Audit anchor is precise.

## Architect lens

**Verdict: APPROVE (confidence 89)**

- File-split posture: `halt.ts` lives in `packages/engine-core/src/` per wave-011/lane-a engine-core split. Module boundaries are clean — `halt.ts` exports the halt taxonomy + verdict shape + detector class as the FIRST owner; `killswitch.ts` (F-020) and `quota.ts` (F-022) import `RunHaltedVerdict` + `HaltTrigger` from here via `from './halt.js'`. The single ownership of the verdict-shape contract is exactly the architecture the wave-011 split was designed to enforce.
- Public API surface (`HaltTrigger` union, `RunHaltedVerdict` interface, `HaltContext` interface, `HaltDetectorConfig` interface, `HaltDetector` class with 8 public methods) — symmetric and predictable. The `record*` family follows a consistent naming convention; the verdict-or-null return shape lets call sites either unconditionally invoke and pattern-match on null OR check `instanceof null` cheaply. No surprises in dep graph: `halt.ts` has zero compile-time imports beyond the test file's vitest types.
- Sibling-trigger composition: `manual` (F-020 reuse), `iteration_cap` (F-001 cycle-cap reuse — the kit's `MAX_CYCLES_HARD_CAP=50` and the F-018 per-run `maxIterations` coexist as two-layer safety), `tool_calls_quota` (F-022 reuse for the global counter), `tool_calls` (F-022 per-spawn quota), `degrade_escalate` (F-021 ladder-top reach). All five sibling triggers share the same verdict-emission path (`halt()` private helper) — no parallel verdict-shape paths to maintain. Architecturally clean.
- Reset semantics: `recordSuccess()` resets the consecutive-failures counter; `recordWriteTool()` resets the read-only overplanning streak; iteration + tool-call counters are monotonic per-run (the run is the natural reset boundary). The asymmetry is correct — a single success "absolves" prior failures (the ledger's "consecutive" qualifier is what makes the counter resettable), but a single Write doesn't absolve the run's iteration count (the run still happened, the cycles still ran).
- Hard deps per ledger: F-001 (lifecycle transitions), F-014 (retro consumes `trigger_evidence_sha256`), F-015 (audit log provides the SHA). Soft deps on F-006 + F-021. The current impl has ZERO compile-time deps on F-001/F-014/F-015 — pure boundary primitive. The deps materialize at call-site (engine code routes failure events through HaltDetector, retro consumes the verdict at `closing`, audit log binds the SHA at fire time). This compose-at-call-site shape is forward-compatible per `verification-protocol.md` Rule 3 (MATCH EXISTING STYLE).

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | F-006 logger surfacing follow-on: HaltDetector emits verdicts but does NOT route them through `Logger.*` — the wiring step is unfinished (same gap-class as F-006's identity-stamping enforcement). | Accept; soft-dep ledger note already covers; backlog item: "halt-event-logging-integration" F-NNN follow-on (or fold into the broader engine-cycle integration step). |
| F2 | MINOR | F-008 filesystem persistence follow-on: detector state lives in memory only; `runs/<run_id>/runtime-state.json` shape is F-008's job. State is lost across engine restarts. | Accept; explicit per ledger §Out-of-scope; F-008 integration is the materialization path. |
| F3 | MINOR | F-015 audit-evidence binding follow-on: `trigger_evidence_sha256` is in the verdict shape but no integration calls into F-015's `appendAuditEntry` to populate it. The field stays optional today; binding is the F-015 integration step. | Accept; ledger §Out-of-scope captures; F-014 retro consumer reads the field when present. |
| F4 | MINOR | Threshold-defaults vs `anomaly-thresholds.md` drift risk: defaults are hard-coded in `HaltDetectorConfig`; kit rule values can drift independently. No compile-time link. | Accept; backlog item: a boot-time loader that reads `anomaly-thresholds.md` and asserts equality (or warns on drift). |
| F5 | PRAISE | The `HaltTrigger` union as the SINGLE source of truth for halt taxonomy across F-018 / F-020 / F-021 / F-022 is the architectural keystone of M2. One union, one verdict shape, one retro consumer. | Keep. |
| F6 | PRAISE | Counter-increment-BEFORE-threshold-compare gives the verdict's `reason` field a precise breach value (e.g. "3 consecutive failures reached threshold 3" not "threshold reached"). Audit anchors on actual numbers. | Keep. |
| F7 | PRAISE | The `halt()` private helper centralizes verdict construction with conditional-add of optional context fields. Avoids serializing `undefined` into JSON. Clean NDJSON output for F-008 storage + F-014 retro. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 89).

F-018 minimal-contract is implemented correctly; all 9 acceptance scenarios pass per the recorded green-test-output proof and re-verified at review time; no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-018 ledger frontmatter (`LOCKED if GREEN AND reviews/F-018-failure-pattern-halt-review.md exists with verdict: ACCEPT`).

The MINOR findings are honest scope-narrowing notes per `no-silent-deferrals.md` — they are surfaced in this review (and in the F-018 ledger §Implementation notes "Out of scope" block), not silently elided. Future deeper integration work (logger surfacing; filesystem persistence; audit-evidence binding; threshold-source loader) is scoped to future F-NNNs, not a re-scoping of F-018's contract.

F-018 transitions GREEN → LOCKED.

## Cross-references

- Ledger: `docs/03-feature-catalog/M2-governance-triad/F-018-failure-pattern-halt.md`
- Source: `packages/engine-core/src/halt.ts` (split from `index.ts` in wave-011/lane-a)
- Tests: `tests/unit/F-018-failure-pattern-halt.test.ts` (9/9 PASS)
- GREEN proof: per ledger §Implementation notes (wave-009 / lane-c GREEN flip + sibling-lane absorption documented in `docs/06-agent-team-outputs/wave-009/lane-c-summary.md` Anomaly A1)
- GREEN transition: `docs/07-roadmap/decision-log.md` (M2 row); ledger status-history wave-009 / lane-c
- Engine-core split: wave-011 / lane-a (no behavior change; `halt.ts` carved out as authoritative location for `HaltTrigger` + `RunHaltedVerdict`)
- Review verdict envelope: per `docs/05-design-reviews/README.md` (APPROVE / APPROVE-WITH-SUGGESTIONS / WAIT-FOR-AUTHOR / REJECT)
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle (Reviewer summary table + Median confidence + Decision)
- Precedent: `docs/05-design-reviews/council-reviews/F-001-engine-bootstrap-loop-review.md` (first LOCKED transition; wave-011 / lane-b); `F-002-per-agent-identity-runid-review.md` + `F-006-logging-pipeline-review.md` + `F-008-local-storage-layout-review.md` (parallel-triple LOCKED transition; wave-012 / lane-d)
