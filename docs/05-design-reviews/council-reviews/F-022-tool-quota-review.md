---
artifact-class: council-review
feature-id: F-022
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-013 / lane-d
---

# F-022 tool-quota — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 90 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 76 |
| architect-lens | Architect | APPROVE | 88 |

Median confidence: 88

## Implementation reviewed

- `packages/engine-core/src/quota.ts` — 101 LOC; `ToolCallQuota` class with `recordCall(agentId)`, `getCount(agentId)`, `reset(agentId)`, `resetAll()`. Per-agent counter via `Map<string, number>`; reuses F-018's `RunHaltedVerdict` shape with `trigger='tool_calls'` (the 13th value in the `HaltTrigger` union — distinct from F-018's global `'tool_calls_quota'`). Imports `RunHaltedVerdict` from `./halt.js` per the wave-011/lane-a engine-core split.
- `tests/unit/F-022-tool-call-quota.test.ts` — 8 acceptance scenarios; all PASS at review time (8/8 PASS in 8ms).
- Commit history per ledger status-history: F-022 RED at wave-002 / lane-b (initial ledger); F-022 GREEN at wave-010 / lane-c (RED test file; GREEN impl + 1-line `HaltTrigger` union extension landed in `index.ts` ~135 LOC F-022 region — substance preserved but commits scrambled per the cross-lane staging-race anomaly A1 documented in `docs/06-agent-team-outputs/wave-010/lane-c-summary.md`); engine-core split (wave-011/lane-a) carved `quota.ts` out of `index.ts` with no behavior change.

## Advocate lens

**Verdict: APPROVE (confidence 90)**

- Implementation is minimal and correct per `minimum-change.md`: 101 LOC delivers the entire per-agent quota primitive — the smallest of the four LOCKED-candidate features in this lane and the one with the cleanest single-purpose surface. Pure data structure (Map) + 4 methods + reuse of F-018's verdict shape.
- All 8 acceptance scenarios PASS: scenarios 1, 2, 3 verify the three ledger acceptance contracts (per-agent quota exhaustion at threshold + 1, per-agent counter independence, per-run override). The 5 extended scenarios cover `reset(agentId)` single-agent clear, `resetAll()` global clear, `getCount` before any call returns 0, default `maxPerAgent=50`, per-agent isolation across 50+ alternating calls.
- Verdict-shape reuse: `trigger: 'tool_calls'` (added to `HaltTrigger` union per the F-018 owner) emits the standard `RunHaltedVerdict` with `agent_id` of the offending agent populated for precise audit anchoring (line 81 of `quota.ts`). F-014's `halted_by_tool_quota` retro outcome (already in `RetroOutcome` enum) consumes this — no F-014 changes needed. Single uniform halt-reporting surface preserved.
- Coexistence with F-018: F-018's `HaltDetector.recordToolCall()` catches runaway global aggregate usage across the run (emits `tool_calls_quota`); F-022's `ToolCallQuota.recordCall()` catches per-spawn per-agent quota exhaustion (emits `tool_calls`). Two surfaces, one verdict shape, one retro consumer. The semantic distinction (`tool_calls_quota` = global; `tool_calls` = per-agent) is documented in F-018's `HaltTrigger` doc-comment (lines 32-38 of `halt.ts`).
- Surface trace per ledger: `kit:foundational-plan.md M2 "tool-quota" surface` + `kit:rules/mcp-tiering.md` (tool-tier classification + max-active default of 10) + `ce:FR-GOV-001` (allowlist; this feature is the quotas counterpart). Provenance is auditable.

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 76)**

- F-022 lands the in-memory primitive only. Out-of-scope per the ledger §out-of-scope-notes: `max_calls_per_run` (1000 default) and `max_tools_active` (10 default) — mentioned in ledger Behavior contract but the wave-10 brief scopes F-022 to per-spawn (per agent_id) cap only; F-006 logger surfacing of QUOTA_EXCEEDED events; F-015 audit-evidence binding for `trigger_evidence_sha256` (field is optional in the verdict shape; binding to a real audit row is F-015's integration step); F-008 storage layout — F-022 keeps quota state in memory only. Acceptable for v1; the boundary is in place. Surfaced honestly per `no-silent-deferrals.md`.
- **Behavior-contract vs impl-scope divergence**: the ledger's Behavior contract paragraph names THREE quotas: `max_calls_per_cycle` (default 50), `max_calls_per_run` (default 1000), `max_tools_active` (default 10). The impl provides a SINGLE quota: `maxPerAgent` (default 50). This is the wave-10 brief's deliberate scope-narrowing (per the ledger §out-of-scope-notes), but a reader of the Behavior contract paragraph could mistake "F-022 LOCKED" for "all three quotas implemented." Surfaced honestly: F-022 LOCKED applies to the `maxPerAgent` primitive; the per-cycle and per-tools-active counterparts are deferred to future flips.
- **Cross-lane staging-race substance preservation**: per the ledger status-history note, F-022 RED files were "absorbed into commit `f142eb1` (test(F-020))" and F-022 GREEN impl into commit `9163d95` (feat(F-008))" during wave-10's parallel-lane execution. Substance was preserved (HEAD has the work; tests pass) but the commit-level audit trail is scrambled. The wave-011/lane-a engine-core split eliminated source-file races; subsequent waves still see roadmap.md races (sighting #6+ across waves). The discipline going forward (per wave-12 retro): per-lane branches + cherry-pick. F-022's substance is intact; the scrambled-attribution is a wave-10 artifact, not an F-022 quality issue.
- Counter unboundedness: `Map<string, number>` grows monotonically until `reset(agentId)` is called. A long-running run that spawns N unique agents accumulates N entries. The ledger does not specify per-agent retention semantics — production callers MUST call `reset(agentId)` at agent-spawn-end (or `resetAll()` at run-end) to bound memory. Backlog candidate: an automatic retention policy (e.g., GC entries older than X cycles) once F-001's cycle-boundary integration lands.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `packages/engine-core/src/quota.ts` lines 1-101 and `tests/unit/F-022-tool-call-quota.test.ts` directly; the implementation matches the contract; counter increments BEFORE threshold compare (line 73 → line 75) so the verdict's `reason` reports the actual breach value ("Agent X exceeded per-spawn tool-call quota (51 > 50)"). The verdict carries `agent_id` set to the offending agent — precise audit anchor.

## Architect lens

**Verdict: APPROVE (confidence 88)**

- File-split posture: `quota.ts` lives in `packages/engine-core/src/` per wave-011/lane-a engine-core split. Module boundary is clean — `quota.ts` imports `RunHaltedVerdict` from `./halt.js` (line 27); single direction; no cyclic dep. F-022 depends on F-018's verdict shape, not vice versa. Same architectural discipline as F-020.
- Public API surface (`ToolCallQuota` class with 4 public methods): minimal and predictable. The method shape is symmetric (`recordCall` is the throwing-via-verdict path; `getCount` is the diagnostic read; `reset`/`resetAll` are the cleanup path). No fields exposed publicly — encapsulation preserved.
- Per-agent counter via `Map<string, number>`: the smallest correct data structure. Independent counters keyed by `agent_id` per the ledger acceptance scenario 2; agent A's calls do not count against agent B's quota. Map iteration order is insertion-order in JS — deterministic for any future "list all over-quota agents" extension.
- Increment-before-check discipline (line 73-74): counter increments BEFORE the threshold compare so the verdict's `reason` reports the actual breach value. Same architecturally-clean discipline as F-018's record-* family. Audit anchors on actual numbers, not threshold-only messages.
- Reset semantics: `reset(agentId)` clears one agent's counter (no-op on unseen agents — `Map.delete` is forgiving); `resetAll()` clears every agent's counter (run-boundary reset). No automatic decay — counters are monotonic per-agent until reset. Per-cycle quotas (the ledger's `max_calls_per_cycle`) would compose `reset` at F-001's cycle-boundary callsite, which is out-of-scope for this flip but architecturally enabled by the existing `reset(agentId)` method.
- Hard deps per ledger: F-001 (cycle boundaries reset per-cycle counters), F-002 (per-agent counters keyed on `agent_id`). Soft deps on F-015 (audit log records rejections) + F-018 (repeated rejections may trigger halt). The current impl has compile-time dep on F-018 (`RunHaltedVerdict` import) and ZERO compile-time deps on F-001/F-002/F-015 — the boundary is in place. The deps materialize at call-site (engine code routes F-002-stamped agent IDs into `recordCall`, F-001's cycle-boundary calls `reset(agentId)`, F-015 binds the audit row when the verdict fires). Forward-compatible per `verification-protocol.md` Rule 3 (MATCH EXISTING STYLE).

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | Behavior-contract scope narrowing: ledger names 3 quotas (`max_calls_per_cycle`, `max_calls_per_run`, `max_tools_active`); impl provides 1 (`maxPerAgent`). The wave-10 brief deliberately narrowed scope; the per-cycle and per-tools-active counterparts are deferred. | Accept; ledger §out-of-scope-notes explicit; backlog item: "tool-quota-per-cycle" + "tool-quota-tools-active" F-NNN follow-ons. |
| F2 | MINOR | F-006 logger surfacing follow-on: `recordCall` returns the verdict but does NOT route it through `Logger.error('quota_exceeded', ...)`. Same gap-class as F-018's logger-surfacing follow-on. | Accept; soft-dep ledger note covers; backlog item: fold into the broader engine-cycle integration step. |
| F3 | MINOR | F-015 audit-evidence binding follow-on: `trigger_evidence_sha256` field is optional in `RunHaltedVerdict`; F-022 does NOT populate it. Binding is the F-015 integration step. | Accept; ledger §out-of-scope explicit; F-015 integration is the materialization path. |
| F4 | MINOR | Counter-Map unboundedness: per-agent entries accumulate monotonically until `reset(agentId)` or `resetAll()`. Long-running runs spawning many unique agents accumulate memory. | Accept; backlog item: automatic retention policy once F-001 cycle-boundary integration lands. |
| F5 | PRAISE | Cleanest single-purpose surface in the four LOCKED-candidate features (101 LOC; 4 methods; one Map). Single-responsibility primitive. | Keep. |
| F6 | PRAISE | `agent_id` is populated on the verdict from the offending agent — precise audit anchor for the F-014 retro consumer. F-018's verdict shape leaves `agent_id` optional; F-022 fills it because the per-agent context is exactly what triggered the halt. | Keep. |
| F7 | PRAISE | Verdict-trigger taxonomy distinction: F-018 emits `tool_calls_quota` for global; F-022 emits `tool_calls` for per-agent. Two surfaces, one verdict shape, one retro consumer (`halted_by_tool_quota` covers both). | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 88).

F-022 minimal-contract is implemented correctly; all 8 acceptance scenarios pass per the recorded green-test-output proof and re-verified at review time; no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-022 ledger frontmatter (`LOCKED if GREEN AND reviews/F-022-tool-quota-review.md exists with verdict: ACCEPT`).

The MINOR findings are honest scope-narrowing notes per `no-silent-deferrals.md` — they are surfaced in this review (and in the F-022 ledger §out-of-scope-notes), not silently elided. Future deeper integration work (per-cycle quota; per-tools-active quota; logger surfacing; audit-evidence binding; counter retention policy) is scoped to future F-NNNs, not a re-scoping of F-022's contract.

F-022 transitions GREEN → LOCKED.

## Cross-references

- Ledger: `docs/03-feature-catalog/M2-governance-triad/F-022-tool-quota.md`
- Source: `packages/engine-core/src/quota.ts` (split from `index.ts` in wave-011/lane-a)
- Tests: `tests/unit/F-022-tool-call-quota.test.ts` (8/8 PASS)
- GREEN proof: `docs/09-examples-proof/F-022/{red-test-output.txt, green-test-output.txt, physical-proof.md}` (per ledger §Implementation notes)
- GREEN transition: ledger status-history wave-010 / lane-c (cross-lane staging-race anomaly A1 documented in `docs/06-agent-team-outputs/wave-010/lane-c-summary.md`)
- Engine-core split: wave-011 / lane-a (no behavior change; `quota.ts` carved out)
- Review verdict envelope: per `docs/05-design-reviews/README.md`
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle
- Precedent: `F-001-engine-bootstrap-loop-review.md` (wave-011 / lane-b); F-002/F-006/F-008 reviews (wave-012 / lane-d)
