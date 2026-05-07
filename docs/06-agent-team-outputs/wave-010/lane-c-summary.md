---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-010 / lane-c)
wave: wave-010
lane: lane-c
topic: F-022-tool-call-quota-RED-GREEN
date: 2026-05-07
status: complete
---

# Wave 10 / Lane C — F-022 tool-call-quota RED → GREEN

## Scope

Tenth feature transition RED → GREEN in the repo (after F-001 / F-002 / F-006 / F-008 / F-014 / F-015 / F-016 / F-018 / F-019). Third M2 governance feature in the wave-009/wave-010 push to flip GREEN — adds the per-spawn (per `agent_id`) tool-call quota primitive, complementing F-018's global counter.

The behavior-contract surface lands the in-memory `ToolCallQuota` class that the M2 governance triad will reuse:
- F-018 catches runaway global tool usage via `HaltDetector.recordToolCall` → trigger `'tool_calls_quota'`
- F-022 catches per-spawn quota exhaustion via `ToolCallQuota.recordCall` → trigger `'tool_calls'` (new HaltTrigger value)

Both verdicts feed F-014's `halted_by_tool_quota` retro outcome (already in the `RetroOutcome` enum) — zero F-014 changes needed.

Wave-010 ran with multiple lanes in parallel:
- **Lane A**: F-019 cost-ledger (M2)
- **Lane C (this lane)**: F-022 tool-call-quota (M2)
- **Lane D**: F-008 local-storage-layout (M0)
- **Other lane**: F-020 kill-switch RED (M2)

## What was created / modified

| Group | Path | Type | Count |
|---|---|---|---|
| RED test stub | `tests/unit/F-022-tool-call-quota.test.ts` | new | 1 |
| GREEN impl additions | `packages/engine-core/src/index.ts` | modified (~135 LOC F-022 region append + 1-line HaltTrigger union extension) | 1 |
| Ledger transition | `docs/03-feature-catalog/M2-governance-triad/F-022-tool-quota.md` | modified (status red→green; status-history; test-files; wire-up; impl notes) | 1 |
| Roadmap update | `roadmap.md` | modified (M2 row + TOTAL row updated to reflect F-022 GREEN) | 1 |
| Confidence-ledger entries | `docs/11-loop-state/confidence-ledger.md` | modified (5 wave-010 lane-c entries) | 1 |
| Physical proof | `docs/09-examples-proof/F-022/physical-proof.md` | new | 1 |
| Vitest output capture | `docs/09-examples-proof/F-022/red-test-output.txt` + `green-test-output.txt` | new | 2 |
| This summary | `docs/06-agent-team-outputs/wave-010/lane-c-summary.md` | new | 1 |
| **Total touched** | | | **9 artifacts** |

## Commit chain

The wave-010 5-atomic-commit convention was disrupted by the multi-lane staging race documented in Anomaly A1 below — same pattern as wave-009 lane-c. Actual commit landings:

| # | SHA | Subject | Notes |
|---|---|---|---|
| 1 (absorbed) | `f142eb1` | `test(F-020): RED test stub for kill-switch` | **A1: F-022 RED files swept into F-020's RED commit** because both lanes raced `git add`. Substantively correct (RED-before-GREEN, output captured at `red-test-output.txt`); commit message names F-020 but file list includes F-022. |
| 2 (absorbed) | `9163d95` | `feat(F-008): GREEN impl for local-storage-layout` | **A1: F-022 GREEN impl region absorbed into F-008's GREEN commit.** The 495-line file stat is F-008 ~390 + F-019 residual ~80 + F-022 ~135 + F-018 union 1-line edit = matches. F-022 GREEN code IS in HEAD (`grep -c "ToolCallQuota"` returns 1; tests 8/8 PASS). |
| 3 (this commit chain) | (forthcoming) | Ledger + roadmap + confidence-ledger + physical-proof + lane-c-summary | Pure docs; should land cleanly under lane-c's own message provided no further race. |

Net: F-022 GREEN code IS in HEAD; tests 8/8 PASS; the audit-trail names are scrambled (same as wave-009 lane-c). Per `rules/scope-discipline.md` honest naming requires this surfacing. Loop-improvement proposal escalates to HIGH priority in §Loop-improvement below — fourth sighting of the same anti-pattern.

## Vitest output

```
RUN  v2.1.9 C:/Users/tonym/Repos/mad-council-claw

✓ tests/unit/F-022-tool-call-quota.test.ts (8 tests) 8ms

Test Files  1 passed (1)
     Tests  8 passed (8)
  Duration  1.11s
```

Full suite at GREEN time (when sibling lanes' work also visible): 9 passed test files, 1 failed (F-020 sibling lane RED — not my concern). 55 PASS + 11 FAIL across 66 tests. F-022: 8/8 PASS.

## RED→GREEN transition

| Phase | State | Test result |
|---|---|---|
| RED (commit f142eb1, F-022 files absorbed) | `ToolCallQuota` not exported; 8/8 fail with `TypeError: ToolCallQuota is not a constructor` | RED captured at `red-test-output.txt` |
| GREEN (impl absorbed into 9163d95) | `ToolCallQuota` class + `'tool_calls'` HaltTrigger value exported from `packages/engine-core/src/index.ts` (~135 LOC F-022 region + 1-line union edit) | 8/8 PASS captured at `green-test-output.txt` |

## Surface inventory (the F-022 GREEN region)

- 1-line `HaltTrigger` union extension: added `'tool_calls'` value (13th `HaltTrigger` value; F-018 region edit, additive only)
- `class ToolCallQuota` (~135 LOC at end-of-file disjoint append zone after F-019's CostLedger):
  - Constructor: `new ToolCallQuota(maxPerAgent = 50)`
  - `recordCall(agentId): RunHaltedVerdict | null` — increments per-agent counter; returns halt verdict when count exceeds `maxPerAgent`
  - `getCount(agentId): number` — returns 0 for unseen agents
  - `reset(agentId): void` — clears one agent's counter
  - `resetAll(): void` — clears every agent's counter
- Reuses F-018's `RunHaltedVerdict` shape; trigger is `'tool_calls'` (distinct from F-018's `'tool_calls_quota'`)

Override semantics: trigger NAME stays canonical (`'tool_calls'`) regardless of `maxPerAgent` value — same stable-taxonomy contract F-018 established.

## Anomalies / context gaps

### A1 — Cross-lane staging-race absorbed F-022 RED + GREEN into sibling commits (FOURTH sighting)

**Severity**: HIGH (load-bearing for commit-history cleanliness; substantively benign — work landed correctly).

Same anti-pattern documented by wave-009 Lane B (Lane-B-w9-cross-lane-race-credit-misattribution) and wave-009 Lane C (Lane-C-w9-staging-race-with-sibling-lanes). Two cross-lane absorptions in this lane:

1. F-022 RED test files (`tests/unit/F-022-tool-call-quota.test.ts` + `docs/09-examples-proof/F-022/red-test-output.txt`) were captured by F-020's RED commit `f142eb1 test(F-020): RED test stub for kill-switch`. Verified via `git show f142eb1 --stat` showing F-022 paths in the F-020 commit's file list.
2. F-022 GREEN impl region (~135 LOC + 1-line union edit) in `packages/engine-core/src/index.ts` was absorbed into F-008's GREEN commit `9163d95 feat(F-008): GREEN impl for local-storage-layout`. Verified: 495-line file stat = F-008 ~390 + F-019 residual ~80 + F-022 ~135 + F-018 union 1-line edit. `grep -c "ToolCallQuota"` against HEAD's index.ts returns 1.

The substantive F-022 work IS in HEAD: tests pass 8/8, type-checking succeeds, the `'tool_calls'` HaltTrigger value is exported, the `ToolCallQuota` class is exported.

Per `rules/non-negotiable-rules.md` (no destructive git ops without authorization), `git reset --hard` to rewrite history was NOT pursued. Lane C's own pre-commit-hook-gated commit attempts in this session were repeatedly racing with sibling lanes' faster shell loops; substance landed via sibling commits but commit messages name those siblings, not F-022.

### A2 — F-020 test fails locally because F-020 GREEN impl is not in HEAD

**Severity**: MEDIUM (sibling-lane in-flight; not blocking F-022).

`pnpm test:unit` at GREEN time runs 10 unit test files. Working tree has F-020 impl mid-flight (visible in `git diff packages/engine-core/src/index.ts` from line 1672+). HEAD has F-008 + F-019 + F-022 GREEN; F-020's GREEN impl is uncommitted in the working tree at this lane's commit time. Result: F-020's 11 tests fail. F-022: 8/8 PASS.

This is a sibling-lane (Lane B wave-010 or similar) finalization gap, NOT a Lane C concern. Surfaced here so loop-state honestly reflects: Lane C work GREEN; F-020 lane's GREEN impl needs a commit by that lane.

### A3 — Brief proposes new HaltTrigger `'tool_calls'` distinct from F-018's `'tool_calls_quota'`

**Severity**: LOW (informational; resolved per FETCH BEFORE CITE / `rules/minimum-change.md`).

Wave-010 / lane-c brief proposes `trigger: 'tool_calls'` for F-022's per-spawn quota. F-018's existing 12-value `HaltTrigger` union already includes `'tool_calls_quota'` for the global counter. Decision: extend the union with `'tool_calls'` as a 13th value (1-line edit in F-018 region) to preserve both surfaces — F-018's global counter and F-022's per-spawn counter. Both feed F-014's `halted_by_tool_quota` retro outcome (already in `RetroOutcome` enum); no F-014 changes needed.

Per `rules/minimum-change.md`, the 1-line union extension is the smallest patch that preserves the contract. Alternative considered: localize a new union or use type-assertion at construction. Rejected because `RunHaltedVerdict.trigger` IS the canonical taxonomy; bifurcating the verdict shape would create two halt-verdict types for one retro-outcome consumer.

## Scope deviations from prompt (intentional, documented)

The wave-010 / lane-c brief's specifications vs what was actually executed:

1. **HaltTrigger value** — brief proposed `trigger: 'tool_calls'`. Honored verbatim; added as 13th `HaltTrigger` value in F-018 region.
2. **Test count** — prompt said "6+ scenarios"; actual is 8 scenarios (3 ledger + 5 extended).
3. **Class API** — followed brief's `ToolCallQuota` / `recordCall` / `getCount` / `reset` / `resetAll` shape exactly.
4. **Default maxPerAgent** — brief said 50; honored.
5. **Out of scope** — brief did not name the F-022 ledger's other two quotas (`max_calls_per_run` 1000 default, `max_tools_active` 10 default). Per `rules/no-silent-deferrals.md`, lane-c surfaces these explicitly in 4 places (ledger §Implementation notes, test file comment, HaltTrigger union comment, this summary §Out of scope) — 5th sighting of the brief-vs-ledger scope-divergence pattern.

All deviations honor the existing F-022 ledger surface alongside the brief.

## Out of scope (per `rules/no-silent-deferrals.md`)

- **`max_calls_per_run` (1000 default)** and **`max_tools_active` (10 default)** — mentioned in the F-022 ledger Behavior contract but the wave-10 brief scopes F-022 to per-spawn (per `agent_id`) cap only. M7 owns skill-allowlist + version-pinning per ledger §out-of-scope-notes.
- **F-006 logger surfacing of QUOTA_EXCEEDED events** — F-022 emits the verdict; F-006 routes it. F-006 is GREEN; integration is a wiring step.
- **F-008 storage layout** — F-022 keeps state in memory; persistence is F-008's job (F-008 GREEN wave-10 lane-d; `atomicWriteJson` helper compositional).
- **F-015 audit-evidence binding** — `trigger_evidence_sha256` field is in the verdict shape but binding to a real audit row is F-015's integration step.
- **Per-cycle reset** — `reset(agentId)` exists but no F-001 cycle-boundary call site composes it yet (the run is the natural reset boundary; per-cycle quotas land in a follow-on flip).
- **F-019 cost-budget integration** — F-019 is observable-only by design (per `rules/no-invented-constraints.md`); F-022 is enforcement-only. They coexist as separate rails — cost observation does NOT halt; quota exhaustion DOES halt.

## Confidence

HIGH (substantive work). MEDIUM (commit-history cleanliness, due to A1 — fourth sighting in two waves).

Source material — F-022 ledger acceptance scenarios + behavior contract + wave-10 brief + F-018 ledger HaltTrigger taxonomy + F-014 RetroOutcome enum + `rules/anomaly-thresholds.md` — is consistent and unambiguous. RED baseline captured BEFORE the GREEN flip per the wave-005 retro proposal. 8/8 acceptance scenarios pass with real vitest output (not synthesized). Stable re-run after sibling-lane churn: 8/8 PASS, no flake. Rule citations across the work — `scope-discipline.md`, `canonical-skill-only.md`, `no-silent-deferrals.md`, `non-negotiable-rules.md` (no destructive git), `minimum-change.md` (1-line union extension) — reflect load-bearing discipline contracts.

## Quality-gate checklist (QG1-QG9 for wave-010 lane-c)

- [x] QG1 — net-new — F-022 GREEN flip is the tenth RED→GREEN in the repo and third M2 transition in the wave-009/wave-010 push (after F-018 wave-009/lane-c, F-019 wave-010/lane-a)
- [x] QG2 — sources cited — every doc cites SOURCE; physical-proof.md cites ledger + actual test output; this summary cites rules + commit SHAs
- [x] QG3 — touches Goal G1-G37 — touches G1 (red→green ledgers), G27 (full behavior tests + physical proof), G37 (immediate working product — per-spawn quota enforcement primitive for M2)
- [x] QG4 — backlog item processed/generated — generates: 4 deferred dependencies (F-006 / F-008 / F-015 / F-018 — all GREEN; integration steps follow); explicit out-of-scope items (`max_calls_per_run`, `max_tools_active` → M7); fourth sighting of staging-race anti-pattern surfaces engine-core file-split as P0 wave-11 deliverable
- [x] QG5 — loop-improvement proposal — see "Loop-improvement proposal" below
- [x] QG6 — multi-lane fan-out applied at wave level — wave-010 has 4+ lanes (Lane A: F-019; Lane C: F-022 this lane; Lane D: F-008; another lane: F-020)
- [ ] QG7 — Copilot CLI design review — N/A this lane (RED→GREEN flips don't trigger council review per current convention)
- [ ] QG8 — Microsoft tools used — N/A this lane (engine-core implementation, not Microsoft-stack)
- [x] QG9 — open questions captured — A1, A2, A3 in Anomalies above

## Loop-improvement proposal (QG5)

Three observations from this lane that should feed wave-011+ discipline:

1. **Engine-core file split is OVERDUE (HIGH, P0 for wave-011).** Four sightings across two waves of the same staging-race anti-pattern (wave-009 lanes B + C, wave-010 lanes A + C this lane). The "explicit per-lane staging discipline" mitigation that Lane D wave-010 demonstrated does NOT scale to 4+ concurrent lanes — when 4 lanes race `git add` on `packages/engine-core/src/index.ts`, even careful staging gets absorbed by sibling lanes' faster shell loops. The refactor — split `index.ts` into per-feature files (`halt.ts`, `audit.ts`, `cost.ts`, `quota.ts`, `storage.ts`, `logging.ts`, `lifecycle.ts`, `identity.ts`, `retro.ts`) with `index.ts` as a barrel re-exporter — eliminates contention entirely. Wave-011 must include this refactor as a P0 deliverable BEFORE flipping additional features through M2.

2. **Brief-vs-ledger scope reconciliation: 5th sighting confirms pattern (HIGH).** F-022 brief specifies 4-method `ToolCallQuota` (per-agent only); F-022 ledger names three quotas. Per FETCH BEFORE CITE / wave-009 lane-a precedent + wave-010 lane-a/d precedent, lane honors the brief's narrower scope and surfaces 4 explicit out-of-scope items (per `rules/no-silent-deferrals.md`). **5th sighting**: brief-generation tooling MUST diff against live ledger frontmatter + behavior contract at brief-write time and surface divergences inline. Promote from MEDIUM to HIGH at wave-11.

3. **HaltTrigger union as canonical taxonomy (informational).** F-022 added `'tool_calls'` as a 13th `HaltTrigger` value to distinguish per-spawn quota from F-018's global `'tool_calls_quota'`. Pattern: when a new feature emits a halt verdict with semantically-distinct meaning from existing triggers, extend the union with a new value (1-line edit in F-018 region). Don't bifurcate the verdict shape; F-014's `RetroOutcome.halted_by_tool_quota` is the one consumer for both triggers. This pattern is now reusable for F-021 degradation-fallback and F-023..F-027 (M3 cron heartbeat) when they need new halt triggers.

## Reproduction

```bash
cd C:/Users/tonym/Repos/mad-council-claw
git log --oneline | head -10                                              # see absorbed RED + GREEN commits
pnpm install
pnpm exec vitest run tests/unit/F-022-tool-call-quota.test.ts             # 8/8 PASS
cat docs/09-examples-proof/F-022/physical-proof.md                        # the audit anchor
```

## Push

Pending — `git push` per `rules/non-negotiable-rules.md` requires explicit user request. The lane-c brief asks for "Standard 5-commit pattern + push at end" — push will happen via the standard convention if/when the user approves.
