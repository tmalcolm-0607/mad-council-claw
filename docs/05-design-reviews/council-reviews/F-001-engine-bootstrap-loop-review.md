---
artifact-class: council-review
feature-id: F-001
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-011 / lane-b
---

# F-001 engine-bootstrap-loop — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 90 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 75 |
| architect-lens | Architect | APPROVE | 88 |

Median confidence: 88

## Implementation reviewed

- `packages/engine-core/src/index.ts` — `bootstrap(config: RunConfig): Promise<RunResult>` + 4 type exports (`LifecycleState`, `TerminatedBy`, `RunConfig`, `AuditEntry`, `RunResult`) + `MAX_CYCLES_HARD_CAP = 50` constant. ~95 LOC for the F-001 region (the file also hosts F-006 + F-008 surfaces appended in later waves).
- `tests/unit/F-001-engine-bootstrap-loop.test.ts` — 3 acceptance scenarios; all PASS per `docs/09-examples-proof/F-001/green-test-output.txt`.
- Commit history per `docs/07-roadmap/decision-log.md`: F-001 RED at wave-002 / lane-b (initial ledger) and wave-003 / lane-c (test scaffold); F-001 GREEN at wave-005 / lane-d, impl commit `e83f0b9`.
- Brief-vs-reality reconciliation: the wave-011 / lane-b brief references a "Lane A file split" with a dedicated `bootstrap.ts`. As of this review the actual file location is `packages/engine-core/src/index.ts` (no `bootstrap.ts` exists yet). The review evaluates the implementation **as it actually exists on disk** per `verification-protocol.md` Rule 4 (ACTUAL BEFORE PRESENT). The minimal-contract surface is identical regardless of file split; LOCKED status applies to the contract, not the file path.

## Advocate lens

**Verdict: APPROVE (confidence 90)**

- Implementation is minimal and correct per `minimum-change.md`. SHA-256 hash-chained audit + 4-state lifecycle + cycle-cap satisfy all 3 acceptance scenarios with ~95 LOC.
- `randomUUID()` from `node:crypto` is the canonical Node primitive — no custom code, no third-party dependency. (F-001 itself uses no UUID; F-002 covers identity correlation. The point stands: F-001 chose primitives that compose with F-002 cleanly.)
- All 3 acceptance scenarios PASS with named termination paths (`completion`, `cycle_cap`, `exception` type surface in place — actual exception-injection seam deferred to F-021 explicitly).
- F-001 was the first feature to flip RED → GREEN in the repo (per decision-log.md row 1). It proved the RED → GREEN state-machine and primary tooling chain (vitest path-glob filter workaround, pnpm workspace fix) end-to-end. LOCKED transition makes it the first proof of the full RED → GREEN → LOCKED machinery.
- Surface trace (per ledger): ce:FR-CORE-001 + ce:FR-CORE-002 + ce:FR-CORE-003 all map cleanly to the `bootstrap()` contract. Provenance is auditable.

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 75)**

- F-001 is a **stub-shaped** feature today: real engine bootstrap (open council channel, spawn Supervisor + sub-agents, write retro at exit, integrate cost ledger + kill-switch) is NOT yet implemented. The current `bootstrap()` runs a synthetic cycle loop that emits `AuditEntry` records — no actual agent dispatch happens.
- The behavior contract in the ledger says the engine kernel "runs one MAD-pipeline iteration end-to-end" as the substrate other features plug into. That integration scope spans M0+M1+M2+M3 (cycle loop + backend + governance triad + cron). F-001 alone delivers the *substrate shape*, not the substrate behavior.
- LOCKED status here is therefore narrowly "**F-001 minimal-contract LOCKED**" — the deeper integration is owned by future features that are already GREEN in their own right (F-002 identity, F-014 retro signal, F-015 audit log, F-018 halt, F-019 cost, F-020 kill-switch). The integration layer that wires them through F-001's bootstrap is its own future feature (currently un-scoped; candidates: integration-test feature in M2 or a new M0 wires-up feature).
- Suggestion (NON-BLOCKING per `no-silent-deferrals.md`): track an explicit "engine-integration" follow-on F-NNN that wires F-002 + F-014 + F-015 + F-018 + F-019 + F-020 through `bootstrap()`. Without it, a reader of F-001 LOCKED could mistakenly assume the substrate is functionally complete. The ledger's `out-of-scope-notes` already references this; backlog promotion to a concrete F-NNN is the closure path.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `packages/engine-core/src/index.ts` lines 1-95 directly; the bootstrap implementation matches the contract, but does NOT call into F-002/F-014/F-015/F-018/F-019/F-020 surfaces. This is an honest gap, not a hidden one — the ledger's behavior contract paragraph is accurate to the contract, but the integration scope it describes is broader than what F-001 alone delivers.

## Architect lens

**Verdict: APPROVE (confidence 88)**

- File-split posture: the brief references a future Lane A split into `bootstrap.ts`. Current location `packages/engine-core/src/index.ts` is the legitimate state on disk; future split is purely a refactor and would be **additive, not modifying** F-001's public API. The LOCKED contract is the public surface (`bootstrap()` + types + `MAX_CYCLES_HARD_CAP`), which is file-location-agnostic.
- API surface (`BootstrapResult { runId, agentId }`) — note the brief asserts this shape. **Actual** shape per source is `RunResult { runId, lifecycleStates: LifecycleState[], cycles: number, terminatedBy: TerminatedBy, auditEntries: AuditEntry[] }`. The richer return shape is correct for F-001's contract (lifecycle + cycle count + termination reason + audit chain are all required by acceptance scenarios). The brief's simpler `{ runId, agentId }` shape would be an under-spec; we keep the actual shape and note this divergence here.
- Per ce:US-2 (every governance feature stamps run_id + agent_id): F-001 emits `runId` only; `agentId` is F-002's concern. The composition is correct — F-001 owns the run identity; F-002 layers per-agent identity on top.
- Cycle cap design: hard cap at 50 per `MAX_CYCLES_HARD_CAP`; user-supplied `maxCycles` is clamped via `Math.min(maxCycles, MAX_CYCLES_HARD_CAP)`. Termination via `cycle_cap` fires when cycle 51 is requested. Architecturally clean: the hard cap is a safety boundary, the user cap is a policy boundary, and they compose without ambiguity.
- Hash-chain shape: SHA-256 of `${priorHash}|${cycle}|${state}` from genesis hash `0`×64. This is the **contract** F-015 extends with cycle payload + signed verdicts. F-001's chain shape is forward-compatible per `verification-protocol.md` Rule 3 (MATCH EXISTING STYLE) — F-015's existing surface aligns.
- No surprises in dependencies; F-001 has zero hard deps on other features (per ledger frontmatter `depends-on: []`). Soft deps on F-002/F-006/F-008 are appropriate and uncoupled.

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | Bootstrap returns identity + lifecycle but does NOT yet spawn agents, open council channels, or invoke the F-014 retro signal at lifecycle `closing` (per ledger contract paragraph). Deeper integration deferred to a future wires-up feature. | Accept; LOCKED status applies to the minimal-contract scope explicitly. Backlog item: track explicit "engine-integration" F-NNN follow-on. |
| F2 | MINOR | Brief-vs-source shape divergence: brief asserts `BootstrapResult { runId, agentId }`; actual is `RunResult { runId, lifecycleStates, cycles, terminatedBy, auditEntries }`. Source shape is correct; brief is under-spec. | Accept source shape; review records the divergence here for audit. |
| F3 | MINOR | Brief-vs-source file-location divergence: brief references `packages/engine-core/src/{bootstrap.ts,index.ts}` post-split; actual is single `index.ts`. | Accept; file split is an orthogonal future refactor that does not affect contract LOCKED status. |
| F4 | PRAISE | `randomUUID()` choice avoids a third-party dependency for run identity. | Keep. |
| F5 | PRAISE | F-001 was the first feature to flip RED → GREEN; this LOCKED transition completes the proof of the full RED → GREEN → LOCKED state machine in the loop. | Keep. |
| F6 | PRAISE | Lifecycle ALWAYS routes through `closing` (even on cycle-cap and exception paths) so the F-014 retro hook fires regardless of termination cause. Forward-compatible by design. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 88).

F-001 minimal-contract is implemented correctly; all 3 acceptance scenarios pass per the recorded green-test-output proof; no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-001 ledger frontmatter (`LOCKED if GREEN AND reviews/F-001-engine-bootstrap-loop-review.md exists with verdict: ACCEPT`).

The MINOR findings are honest scope-narrowing notes per `no-silent-deferrals.md` — they are surfaced in this review (and in the F-001 ledger §Implementation notes), not silently elided. Future deeper-integration work is scoped to a future F-NNN, not a re-scoping of F-001's contract.

F-001 transitions GREEN → LOCKED.

## Cross-references

- Ledger: `docs/03-feature-catalog/M0-bootstrap/F-001-engine-bootstrap-loop.md`
- Source: `packages/engine-core/src/index.ts` (F-001 region)
- Tests: `tests/unit/F-001-engine-bootstrap-loop.test.ts` (3/3 PASS)
- GREEN proof: `docs/09-examples-proof/F-001/green-test-output.txt` + `physical-proof.md`
- GREEN transition: decision-log.md row 1; impl commit `e83f0b9`; wave-005 / lane-d
- Review verdict envelope: per `docs/05-design-reviews/README.md` (APPROVE / APPROVE-WITH-SUGGESTIONS / WAIT-FOR-AUTHOR / REJECT)
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle (Reviewer summary table + Median confidence + Decision)
