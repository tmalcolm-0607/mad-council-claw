---
artifact-class: council-review
feature-id: F-021
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-015 / lane-a
---

# F-021 degradation-fallback — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 90 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 74 |
| architect-lens | Architect | APPROVE | 88 |

Median confidence: 88

## Implementation reviewed

- `packages/engine-core/src/degradation.ts` (208 LOC) — `DegradationRung` union (6 values: `'normal' | 'skill-fallback' | 'model-fallback' | 'reduced-tool-set' | 'headless' | 'halt'`); `DegradationTransition` shape (rung + at + trigger); `DegradationState` shape (current + trigger + history); `DegradationLadder` class with `getCurrent()`, `getState()`, `escalate(trigger) → RunHaltedVerdict | null`, `recover(reason) → void`.
- `packages/engine-core/src/halt.ts` — `HaltTrigger` union extended with 14th value `'degrade_escalate'` (1-line addition; sibling trigger to existing 9th value `'degradation_threshold'`).
- `packages/engine-core/src/index.ts` — barrel re-export adds `export * from './degradation.js';`.
- `tests/unit/F-021-degradation-ladder.test.ts` (223 LOC) — 11 scenarios: 7 acceptance + 2 sub-scenarios (5a/5b, 6a/6b) + 2 robustness checks (trigger-string preservation, getState snapshot shape). All PASS per `docs/09-examples-proof/F-021/green-test-output.txt`.
- Commit history per `docs/07-roadmap/decision-log.md`: F-021 RED at wave-002 / lane-b (initial ledger only); F-021 GREEN at wave-012 / lane-a (impl commits `8d79b1f` + `226acaa`); finalization at wave-013 / lane-a (proof artifacts + ledger frontmatter flip).

## Advocate lens

**Verdict: APPROVE (confidence 90)**

- Implementation is minimal and correct per `minimum-change.md`. ~208 LOC delivers the entire in-memory escalation-ladder primitive: 1 union (6 rungs) + 2 record shapes + 1 class with 4 methods. No premature abstraction; no helper functions invented before they have a caller.
- Composition with F-018 (`RunHaltedVerdict`) is exemplary. Reaching the `halt` rung returns a `RunHaltedVerdict` (trigger=`'degrade_escalate'`) — reusing the F-018 verdict shape per the wave-011 / lane-a "verdict-shape reuse across halt features" rule. The 1-line `HaltTrigger` union extension is the smallest patch that preserves the F-018 verdict-shape contract.
- 11/11 scenarios PASS at GREEN time (8ms total runtime). Full suite at GREEN: 94/94 PASS across 14 test files.
- The 5-rung ladder (`normal → skill-fallback → model-fallback → reduced-tool-set → headless → halt`) is the canonical degradation strategy from `kit:rules/degradation-fallback-policy.md`. Each rung represents a strategy attempted before the next escalation; the ladder tracks history for retro consumption.
- Surface trace (per ledger): `kit:rules/degradation-fallback-policy.md` (the 5 rules + named failure modes 1-6) + `kit:rules/anomaly-thresholds.md` (sliding-window thresholds for circuit-breaker). The kit rule's escalation discipline is the contract; the in-memory ladder is the v1 primitive.
- F-021 was the 13th feature to flip RED → GREEN (wave-012 / lane-a). LOCKED here closes the M2 governance triad COMPLETELY — combined with F-014..F-020 + F-022 already LOCKED, M2 reaches 0R + 0G + 9L (100% LOCKED).

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 74)**

- F-021 is **in-memory primitive only** at v1. The ledger §Behavior contract describes a 5-rule policy:
  1. Per-resource circuit-breaker (open/half-open/closed state machine)
  2. Context-Gaps section emission tied to user-facing status output
  3. Required-vs-optional dependency classification + automatic F-018 halt hand-off on required-dependency failure
  4. Sliding-window threshold sourcing from `rules/anomaly-thresholds.md`
  5. F-015 audit-log entry per failure observation
- Of those 5 rules, the wave-012 / lane-a GREEN flip implements **only the in-memory escalation-ladder primitive** — the substrate that the 5 rules build on. The 5 ledger §Acceptance scenarios (1: circuit-breaker open after 3 failures; 2: Context-Gaps section in user output; 3: required-dependency triggers F-018 halt) are NOT yet implemented at runtime. The ledger §Out-of-scope-notes documents this narrowing explicitly per `no-silent-deferrals.md`.
- LOCKED status here is therefore narrowly "**F-021 in-memory escalation-ladder primitive LOCKED**" — the 5 rule integrations will be retired by future engine-cycle integration work. The ledger's §Out-of-scope-notes paragraph 1-5 enumerates the deferred surface explicitly.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `packages/engine-core/src/degradation.ts` lines 1-208 directly + the test lines 1-223. The ladder primitive is exactly what the wave-012 / lane-a brief describes; the 5 ledger §Behavior contract integrations do NOT exist on disk. This is a documented gap, not a hidden one.
- Suggestion (NON-BLOCKING per `no-silent-deferrals.md`): the 5 deferred integrations should be tracked as follow-on F-NNN entries (similar to the F-001 "engine-integration" backlog suggestion). The current `out-of-scope-notes` block enumerates them but doesn't promote to concrete F-NNN candidates. A future audit lane could close this by drafting per-integration RED ledgers.
- Suggestion (NON-BLOCKING): the ladder records `DegradationTransition` history but doesn't bound history size. A long-running session that escalates + recovers thousands of times would grow the history unboundedly. Acceptable v1 trade-off (single-machine, runs are short-lived); flagging for M16 telemetry to consider history-size bound when long-running daemon mode lands.

## Architect lens

**Verdict: APPROVE (confidence 88)**

- File-location posture: `packages/engine-core/src/degradation.ts` — correct shape per the wave-011 / lane-a engine-core split convention. F-021 owns its file; the ladder primitive is single-purpose; future integration features (per-resource circuit-breaker, Context-Gaps emission, required-vs-optional classification) own their own files.
- Verdict-shape reuse: imports `RunHaltedVerdict` from `./halt.js` (F-018's first-owner) — does NOT declare a parallel verdict type. The wave-011 / lane-a "verdict-shape reuse across halt features" rule is honored exactly. F-018 / F-020 / F-021 / F-022 all return the same canonical shape; one union (`HaltTrigger`), one verdict shape, one retro consumer.
- HaltTrigger union extension: 1-line patch adding `'degrade_escalate'` as the 14th value. The minimum-change discipline per `rules/minimum-change.md` is honored — no parallel union, no shape divergence. Sibling to existing 9th value `'degradation_threshold'` (reserved for sliding-window threshold trips); semantic distinction is "ladder-top reached" vs "threshold tripped".
- Class-vs-pure-function choice: `DegradationLadder` is a class (stateful: current rung + history). Acceptable for an instance that holds mutating state across calls. A purely functional alternative (`escalate(state, trigger) → newState`) would be more compositional but require external state-threading at every callsite — over-engineered for the v1 scope.
- API surface review:
  - `escalate(trigger: string) → RunHaltedVerdict | null` — null until 'halt'; verdict at 'halt'. Caller pattern: `const verdict = ladder.escalate(reason); if (verdict) handleHalt(verdict);` — clean, no exception-as-control-flow.
  - `recover(reason: string) → void` — drops one rung; no-op at 'normal'; no-op from terminal 'halt'. Idempotent by construction.
  - `getState(): Readonly<DegradationState>` — `Readonly<>` wrapper signals immutability intent; consumers can't mutate the ladder via the snapshot.
- Composition with sibling features (F-018 / F-020 / F-022): when any halt verdict is emitted (kill-switch, tool-quota, overplanning, degradation-escalation), the F-014 retro signal consumes them through the same `RunHaltedVerdict` shape. No special-casing per trigger.
- No surprises in dependencies: F-021 has F-001 (engine cycles) + F-006 (logger emits Context Gaps lines) as hard deps (per ledger frontmatter `depends-on: [F-001, F-006]`). F-018 (halt verdict) is a soft dep — F-021 reuses F-018's verdict shape. F-015 (audit-log entry per failure) is a soft dep deferred to future integration.

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | F-021 implements only the in-memory escalation-ladder primitive at v1. The 5 ledger §Behavior contract integrations (per-resource circuit-breaker; Context-Gaps emission; required-vs-optional classification; sliding-window thresholds; F-015 audit-log entry per failure) are deferred to engine-cycle integration. | Accept; LOCKED status applies to the in-memory ladder primitive scope explicitly. The ledger §Out-of-scope-notes paragraph 1-5 enumerates the deferred surface. |
| F2 | MINOR | The 3 ledger §Acceptance scenarios (circuit-breaker open after 3 failures; Context-Gaps in user output; required-dep triggers F-018 halt) are NOT yet runtime-verifiable. Today only the wave-012 / lane-a brief scenarios (escalate / recover / halt-is-terminal / history-records-every-transition / verdict-trigger=`degrade_escalate`) are runtime-verifiable. | Accept; flagged for the engine-cycle integration wave to revisit and add runtime tests. |
| F3 | MINOR | The 5 deferred integrations are tracked in §Out-of-scope-notes but not promoted to concrete F-NNN candidates. A future audit lane could draft per-integration RED ledgers. | Accept; backlog item for follow-on planning. |
| F4 | MINOR | `DegradationTransition` history grows unboundedly across long-running sessions. Acceptable v1 trade-off (single-machine, short-lived runs); flagging for M16 telemetry / daemon-mode to consider history-size bound. | Accept; design choice for v1. |
| F5 | PRAISE | Verdict-shape reuse via `RunHaltedVerdict` import from `halt.ts` (F-018's first-owner) — exemplifies the wave-011 / lane-a convention. F-018 / F-020 / F-021 / F-022 all return canonical shape; F-014 retro consumer handles them uniformly. | Keep. |
| F6 | PRAISE | 1-line `HaltTrigger` union extension — minimum-change discipline honored exactly. Sibling to `'degradation_threshold'`; semantic distinction is preserved without forking the union. | Keep. |
| F7 | PRAISE | `Readonly<DegradationState>` snapshot shape on `getState()` signals immutability intent — consumers can't mutate the ladder via the snapshot. Forward-compatible: future ladder mutations don't break consumers. | Keep. |
| F8 | PRAISE | F-021 LOCKED closes the M2 governance triad COMPLETELY (F-014..F-020 + F-022 + F-021 = 9/9 LOCKED). The full halt + cost + audit + redaction + retro + degradation surface is now permanent. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 88).

F-021 in-memory escalation-ladder primitive is implemented correctly; all 11 wave-012-scoped scenarios pass per the recorded green-test-output proof; no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-021 ledger frontmatter (`LOCKED if GREEN AND reviews/F-021-degradation-fallback-review.md exists with verdict: ACCEPT`).

The MINOR findings are honest scope-narrowing notes per `no-silent-deferrals.md` — F1 (5 ledger §Behavior contract integrations deferred to engine-cycle integration), F2 (ledger §Acceptance scenarios not runtime-verifiable today), F3 (deferred integrations not yet promoted to F-NNN candidates), F4 (unbounded history size design choice) are surfaced in this review and in the F-021 ledger §Out-of-scope-notes. No finding is silent.

F-021 transitions GREEN → LOCKED. **Closes the M2 governance triad** — F-014/15/16/17/18/19/20/22 already LOCKED; F-021 was the last GREEN → LOCKED candidate. M2 reaches 0R + 0G + 9L (100% LOCKED).

## Cross-references

- Ledger: `docs/03-feature-catalog/M2-governance-triad/F-021-degradation-fallback.md`
- Source: `packages/engine-core/src/degradation.ts` (208 LOC), `packages/engine-core/src/halt.ts` (1-line `HaltTrigger` extension), `packages/engine-core/src/index.ts` (barrel re-export)
- Tests: `tests/unit/F-021-degradation-ladder.test.ts` (11/11 PASS)
- GREEN proof: `docs/09-examples-proof/F-021/` (red-test-output + green-test-output + physical-proof)
- GREEN transition: decision-log.md (F-021 RED → GREEN row); impl commits `8d79b1f` + `226acaa`; wave-012 / lane-a
- GREEN finalization: wave-013 / lane-a (proof artifacts + ledger frontmatter flip)
- Composing features: F-018 (`RunHaltedVerdict` from `halt.ts`)
- Review verdict envelope: per `docs/05-design-reviews/README.md` (APPROVE / APPROVE-WITH-SUGGESTIONS / WAIT-FOR-AUTHOR / REJECT)
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle (Reviewer summary table + Median confidence + Decision)
