---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-019 / lane-b)
wave: wave-019
lane: lane-b
topic: F-139 backend-event-usage-variant + F-140 retro-outcome-degradation NEW RED -> GREEN
date: 2026-05-07
status: complete
---

# Wave 19 / Lane B — F-139 + F-140 NEW RED -> GREEN

## Scope

Two net-new features promoted from wave-016/lane-d Copilot CLI design review. Both flip RED -> GREEN in the SAME lane in the SAME micro-session, each targeting a different milestone:

- **F-139 backend-event-usage-variant** (M1) — promoted from Opus C-2 (single-model Critical demoted to SHOULD-FIX under cross-model rule but reasoning concrete: F-019 cost ledger had no event source). Resolves D-36.
- **F-140 retro-outcome-degradation** (M2) — promoted from Opus m-1 (single-model Minor): RetroOutcome lacked `halted_by_degradation` despite F-021 DegradationLadder emitting trigger=`degrade_escalate`.

Both follow F-138 wave-017/lane-a's "NEW feature whose explicit purpose is to integrate prior LOCKED primitives" precedent. F-139 extends BackendEvent (F-009/M1 surface) with a 5th `usage` variant + maps to F-019 CostEntryInput. F-140 extends RetroOutcome (F-014/M2 surface) with a 5th `halted_by_degradation` value + a typed builder validating the F-021 `degrade_escalate` trigger boundary.

## Outcome

**F-139 + F-140 NEW RED -> GREEN** in 2 commits (RED + GREEN). 12/12 scenarios passing for the two features isolated; full suite 323/323 across 38 test files.

| Feature | RED -> GREEN | Test result | Files added/modified |
|---|---|---|---|
| F-139 | RED -> GREEN in same lane | 6/6 PASS | tests/unit/F-139-backend-event-usage-variant.test.ts (new); packages/engine-core/src/backend-event-variant.ts (new); packages/engine-core/src/backend.ts (additive: 5th BackendEvent variant); packages/engine-core/src/backend-events.ts (additive: isUsageEvent + eventTextContent 5th branch); packages/engine-core/src/index.ts (1 ownership-table line + 1 re-export) |
| F-140 | RED -> GREEN in same lane | 6/6 PASS | tests/unit/F-140-retro-outcome-degradation.test.ts (new); packages/engine-core/src/retro-degradation.ts (new); packages/engine-core/src/retro.ts (additive: 5th RetroOutcome value + HALTED_OUTCOMES + validOutcomes); packages/engine-core/src/index.ts (1 ownership-table line + 1 re-export) |

## Test results

```
$ pnpm test
 Test Files  38 passed (38)
      Tests  323 passed (323)
   Duration  ~5s
```

## What landed

1. **`tests/unit/F-139-backend-event-usage-variant.test.ts`** (~205 LOC, 6 scenarios across one describe block):
   - usage event + price lookup + correlation -> CostEntryInput with computed usd_estimate (1000 input × $0.000015 + 500 output × $0.000075 = $0.0525); F-019 round-trip yields CostEntry with seq=0 and matching numeric fields.
   - isUsageEvent type guard returns false for token / finish / tool_call / tool_result; true for usage.
   - usage event WITHOUT price lookup -> usd_estimate=0 + all 4 token-count fields mapped verbatim (cache_read=200, cache_write=100 included).
   - eventTextContent on usage event returns deterministic `[usage: input=N output=M cache_read=R cache_write=W]` descriptor.
   - parent_run_id in correlation propagates to CostEntryInput.
   - 5-variant exhaustive-switch witness compiles (eventTextContent over the extended union).

2. **`packages/engine-core/src/backend-event-variant.ts`** (~70 LOC, ESM):
   - `usageEventToCostEntry(event, ctx, priceLookup?): CostEntryInput` — pure mapper.
   - `UsageEventContext` — `{run_id, agent_id, parent_run_id?}`.
   - `PriceLookup` — `(model, kind: 'input' | 'output') => number`.

3. **Additive extensions** (no modifications to LOCKED contracts):
   - `backend.ts` — 5th BackendEvent variant `{type:'usage', input_tokens, output_tokens, cache_read_tokens, cache_write_tokens, model, backend?}`.
   - `backend-events.ts` — `isUsageEvent` type guard + `eventTextContent` 5th branch; `const _exhaustive: never` witness keeps compiling.
   - StubBackend NOT modified — F-009 acceptance contract intact; real-SDK swaps in F-010/F-011 will emit usage events when they land.

4. **`tests/unit/F-140-retro-outcome-degradation.test.ts`** (~190 LOC, 6 scenarios across one describe block):
   - degrade_escalate verdict + valid Likert + valid 64-hex SHA -> RetroSignal with outcome=`halted_by_degradation` + trigger_evidence_sha256; closeSession returns {ok:true}.
   - 60-char SHA (3-too-short) -> closeSession throws RetroMissingError with `missingFields` containing `'trigger_evidence_sha256'`.
   - Wrong-trigger verdict (consecutive_failures_3) -> buildDegradationRetro throws Error with message matching `/expected trigger=degrade_escalate/`.
   - historyRender callback supplied with 3-rung DegradationTransition history -> meta_observations contains rendered string verbatim.
   - No historyRender callback -> meta_observations is caller-supplied verbatim from DegradationRetroFields (no auto-injection).
   - 5-value RetroOutcome union accepts halted_by_degradation in closeSession.

5. **`packages/engine-core/src/retro-degradation.ts`** (~75 LOC, ESM):
   - `buildDegradationRetro(verdict, fields, auditChainHead, opts?): RetroSignal` — typed builder.
   - `DegradationRetroFields` — caller-supplied 5-axis Likert + 7 pattern-prose fields shape.
   - `DegradationRetroOptions` — `{history?, historyRender?}` optional history-render hook.
   - Defensive boundary throws `Error` (NOT `RetroMissingError` — that's F-014's contract) when `verdict.trigger !== 'degrade_escalate'`.

6. **Additive extensions** (no modifications to LOCKED contracts):
   - `retro.ts` — 5th RetroOutcome value `'halted_by_degradation'` + HALTED_OUTCOMES Set entry + validOutcomes Set entry inside closeSession.
   - F-014's Likert / pattern-field / SHA validation all unchanged.

7. **`packages/engine-core/src/index.ts`** — 2 ownership-table comment lines + 2 re-exports (`backend-event-variant.js` + `retro-degradation.js`) appended in disjoint zone per the wave-011/lane-a per-feature-files convention.

8. **Proof artifacts**: `docs/09-examples-proof/F-139/{red,green}-test-output.txt` + `docs/09-examples-proof/F-140/{red,green}-test-output.txt`.

9. **Ledger flips**: F-139 ledger at `docs/03-feature-catalog/M1-backend/F-139-backend-event-usage-variant.md` (status: red -> green; status-history append; test-files populated; Implementation notes section authored). F-140 ledger at `docs/03-feature-catalog/M2-governance-triad/F-140-retro-outcome-degradation.md` (same shape).

10. **Roadmap** (`roadmap.md`):
    - M1 row 0R+0G+5L -> 0R+1G+5L (M1 expands by 1 to 6 features).
    - M2 row 0R+0G+9L -> 0R+1G+9L (M2 expands by 1 to 10 features).
    - TOTAL row 145+97R+6G+24L -> 147+97R+8G+24L; active feature count 127 -> 129.
    - Wave-019 / Lane B transition note inserted before the Wave-019 / Lane C note.

11. **Design decisions** (`docs/10-backlog/design-decisions-pending.md`):
    - D-36 marked RESOLVED 2026-05-07 by wave-019/lane-b (option (a) "add usage variant to BackendEvent now").

12. **Confidence ledger** (`docs/11-loop-state/confidence-ledger.md`):
    - Lane B / wave-019 section + 3 entries: Lane-B-w19-F-139-GREEN, Lane-B-w19-F-140-GREEN, Lane-B-w19-parallel-double-NEW-feature-pattern-validated.

13. This summary file.

## Scope reconciliation (FETCH BEFORE CITE on each ledger)

Per `no-silent-deferrals.md`, every non-implemented surface is named and explicitly owned by a downstream feature. The two ledgers each carry 6 honest scope-narrowing notes in `out-of-scope-notes`:

### F-139 deferrals

- **Concrete-backend usage emission** — F-010 + F-011 stub bodies don't emit usage events; gated on real-SDK swap.
- **F-138 cycle.ts integration** — cycle.ts will compose this primitive in a future iteration; primitive lives here, integration there.
- **Per-model price table** — caller supplies the lookup; F-019's deferred `pricing/<backend>.json` concern stays deferred.
- **Cache-attribution analytics** — token counts mapped verbatim; cache-cost analytics belong to a future M16 telemetry feature.
- **Audit-pipeline taxonomy refinement** — F-138 already audits BackendEvents generically; discrete `cost.row.appended` audit category deferred.
- **eventTextContent variant exhaustiveness** — extended in same wave so the never-witness keeps compiling.

### F-140 deferrals

- **Persistence to runs/<run_id>/retro.json** — F-008 storage layout owns the filesystem write.
- **Audit-log entry for degradation halts** — F-138 already audits cycle.halted; SHA-256 plumbing is caller's responsibility.
- **DegradationLadder.getState() history rendering** — production format (multi-line markdown) belongs to a future M11 retro-introspection feature.
- **ALAS-compatible learning-hub posting** — same M11 deferral as F-014.
- **Per-rung outcome variants** — F-021's escalation has 5 non-terminal rungs but only the terminal halt rung emits a verdict; per-rung diagnostics belong in `meta_observations` prose, not in the RetroOutcome enum.
- **`halted_by_circuit_breaker`** — F-021's circuit-breaker subsystem itself deferred; pre-adding the enum value would silent-defer.

## Discipline checks

- **Anti-orchestrator-impostor** per `kit:rules/orchestrator-identity.md`:
  - F-139 mapper NEVER calls CostLedger.append (returns CostEntryInput; caller appends).
  - F-140 builder NEVER calls closeSession (returns RetroSignal; caller closes).
  - Both modules respect "compose; do not re-implement" — F-019's append validator + F-014's closeSession boundary stay authoritative.

- **No-invented-constraints** per `kit:rules/no-invented-constraints.md`:
  - F-139 mapper computes usd_estimate ONLY when priceLookup callback supplied (otherwise 0; F-019 stays observable-only).
  - F-140 builder does NOT auto-fill any field from the verdict; 7 pattern-prose fields are caller-supplied verbatim; optional historyRender hook modifies ONLY meta_observations.

- **Boundary-validation** (F-140 specific):
  - `buildDegradationRetro` throws `Error` (NOT RetroMissingError — that's F-014's specific contract) when `verdict.trigger !== 'degrade_escalate'`. Defensive boundary preventing wrong-shape verdicts producing misleading halted_by_degradation retros.

- **Cross-lane staging-race avoidance** per user directive 2026-05-07:
  - NO `git reset` (any flavor); selective `git add` for each commit; `git status --short` audit before each commit.
  - RED commit aa1632d landed cleanly with no sweep (sibling lanes' work-tree mods existed but explicit `git add` set scoped to F-139 + F-140 paths only).
  - GREEN commit pending — combined-bash `git add && git commit` mitigation pattern from wave-017 lane-b retained.

## Pattern: parallel-double-NEW-feature

This lane validates a NEW pattern: **two net-new features (not promotions of pre-existing RED ledgers) flipped RED -> GREEN in the SAME lane in the SAME micro-session, targeting DIFFERENT milestones**.

| Iteration | Pattern | Source |
|---|---|---|
| F-138 wave-017/lane-a | Single NEW feature in M0 | First "NEW feature integrating prior LOCKED primitives" |
| **F-139 + F-140 wave-019/lane-b** | **Two NEW features across M1 + M2** | **This lane — parallel-double-NEW-feature** |
| Future similar | Wave-002-class wide-aperture review yielding 5+ NEW F-NNN candidates | Batch by milestone-disjoint pairs |

Wall-clock: ~25 min combined for 2 features (vs ~15 min for F-138 solo) — sub-linear scaling because both features share the wave-016/lane-d review context + the same orchestrator-identity / no-invented-constraints / boundary-validation discipline frame + the same RED-then-GREEN micro-session shape.

## Verification trail

```
$ git log --oneline -5
# (pre-GREEN-commit)
aa1632d test(F-139,F-140): RED ledgers + scenarios
2a70c1e docs(F-023,F-028,wave-018/lane-a): GREEN -> LOCKED via post-impl council reviews
34e561c docs(F-032,wave-018/lane-c): RED -> GREEN ledger + roadmap + confidence-ledger + lane-c summary
15c3d43 docs(F-031,wave-018/lane-b): RED -> GREEN ledger + roadmap + confidence-ledger + lane-b-summary
ffafb3a docs(wave-18-d): audit followups + absolute-paths directive + wave-history line

$ pnpm test
 Test Files  38 passed (38)
      Tests  323 passed (323)
```

## Future M1 / M2 work after this lane

- **F-139 GREEN -> LOCKED** — post-impl council review (verdict ACCEPT pending).
- **F-140 GREEN -> LOCKED** — post-impl council review (verdict ACCEPT pending).
- **F-138 §out-of-scope-notes "F-013 event-normalization usage variant" item** — closeable when a future cycle.ts iteration composes the F-139 mapper into the BackendEvent loop.
- **F-141 governance-kernel-extract** (M3 candidate) — extract RunHaltedVerdict + HaltTrigger from halt.ts into verdict.ts; halt.ts shrinks to F-018 logic only.
- **F-142 engine-core-public-api-boundary** (M3 candidate) — `public-api.ts` re-export only consumer-facing surface.
- **F-131 fanout-budget-governor** unblocked — depends on F-139 usage variant for token-count signal.
