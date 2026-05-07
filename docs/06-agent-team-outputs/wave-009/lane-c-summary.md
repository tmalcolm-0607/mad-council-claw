---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-009 / lane-c)
wave: wave-009
lane: lane-c
topic: F-018-failure-pattern-halt-RED-GREEN
date: 2026-05-07
status: complete
---

# Wave 9 / Lane C — F-018 failure-pattern-halt RED → GREEN

## Scope

Sixth feature transition RED → GREEN in the repo (after F-001 wave-005, F-002 wave-006, F-014 + F-015 wave-008, F-006 + F-016 wave-009 sibling lanes). First M2 governance feature beyond F-014/F-015 to flip GREEN. The behavior-contract surface lands the in-memory failure-pattern halt-detection primitive that future M2 governance features (F-020 kill-switch, F-021 degradation, F-022 tool-quota) will reuse via a uniform `RunHaltedVerdict` shape consumed by F-014's retro signal.

Wave-009 ran with multiple lanes in parallel:
- **Lane A**: F-006 logging-pipeline (M0)
- **Lane C (this lane)**: F-018 failure-pattern-halt (M2)
- **Lane D (sibling)**: F-016 query-audit-log (M2) + backlog intake
- **Lane D (separate work)**: 25 F-D-NNN backlog promotions + 5 RG + 5 D-NN + decision-log

All lanes modify `packages/engine-core/src/index.ts` in disjoint append-only zones. Coordination resolved via the wave-008 multi-lane append convention — but with the wave-009 additional finding that staging races between concurrent `git add` operations on the same file can absorb cross-lane work into the wrong commit message (see Anomaly A1 below).

## What was created / modified

| Group | Path | Type | Count |
|---|---|---|---|
| RED test stub | `tests/unit/F-018-failure-pattern-halt.test.ts` | new | 1 |
| GREEN impl additions | `packages/engine-core/src/index.ts` | modified (~290 LOC added in F-018 region) | 1 |
| Ledger transition | `docs/03-feature-catalog/M2-governance-triad/F-018-failure-pattern-halt.md` | modified (status red→green; status-history; test-files; wire-up; impl notes; reproduction) | 1 |
| Roadmap update | `roadmap.md` | modified (M2 row 6R+3G→5R+4G; TOTAL row 30R+6G→29R+7G; F-018 detail row 🔴→🟢) | 1 |
| Confidence-ledger entries | `docs/11-loop-state/confidence-ledger.md` | modified (lane-c wave-009 entries) | 1 |
| Physical proof | `docs/09-examples-proof/F-018/physical-proof.md` | new | 1 |
| Vitest output capture | `docs/09-examples-proof/F-018/red-test-output.txt` + `green-test-output.txt` | new | 2 |
| This summary | `docs/06-agent-team-outputs/wave-009/lane-c-summary.md` | new | 1 |
| **Total touched** | | | **9 artifacts** |

## Commit chain

The wave-008 / wave-009 5-atomic-commit convention was disrupted by the multi-lane staging race documented in Anomaly A1. Actual commit landings:

| # | SHA | Subject | Notes |
|---|---|---|---|
| 1 | `eacc651` | `test(F-018): RED test stub for failure-pattern-halt` | Substantively correct (RED-before-GREEN, output captured). Scope leak: also captured sibling F-016 test stub due to working-tree contamination. |
| 2 | `da48f2a` | `docs(examples-proof): F-006 GREEN — vitest output + physical-proof + lane-a-summary` | Substantively misnamed: this commit's index.ts hunk landed lane-c's F-018 GREEN impl + sibling lane's F-016 GREEN impl. Lane A's commit message describes lane A's docs work; the index.ts hunk inside includes lane C's content. |
| 3 | (this commit chain) | Ledger + roadmap + confidence-ledger + physical-proof + lane-c-summary | Pure docs; no contention-zone files. Should land cleanly under lane-c's own message. |

Net: F-018 GREEN code IS in HEAD; tests 9/9 PASS; the audit-trail names are scrambled. Per `rules/scope-discipline.md` honest naming requires this surfacing. Loop-improvement proposal below addresses the prevention path.

## Vitest output

```
RUN  v2.1.9 C:/Users/tonym/Repos/mad-council-claw

✓ tests/unit/F-018-failure-pattern-halt.test.ts (9 tests) 11ms

Test Files  1 passed (1)
     Tests  9 passed (9)
  Duration  2.25s
```

Full unit suite (with sibling lane work also present — F-006 PENDING due to sibling lane re-land needed): **35/39 PASS** (6 of 7 test files green; F-006 4 fails are sibling-lane gap, NOT F-018).

## RED→GREEN transition

| Phase | State | Test result |
|---|---|---|
| RED (commit eacc651) | `HaltDetector` not exported; `RunHaltedVerdict` type absent; `HaltTrigger` union absent | 9/9 fail with `TypeError: HaltDetector is not a constructor` |
| GREEN (impl in HEAD via da48f2a hunk) | `HaltDetector` + `RunHaltedVerdict` + `HaltTrigger` + `HaltContext` + `HaltDetectorConfig` exported from `packages/engine-core/src/index.ts` (~290 LOC F-018 region) | 9/9 PASS |

Output captured: `docs/09-examples-proof/F-018/{red,green}-test-output.txt`.

## Surface inventory (the F-018 GREEN region)

- `HaltTrigger` union (12 values total):
  - 9-value ledger automatic-halt enum (verbatim from behavior contract): `consecutive_failures_3`, `consecutive_failures_10`, `overplanning_5`, `overplanning_8`, `spawns_per_hour_exceeded`, `token_anomaly_2x`, `rapid_prompt_burst`, `circuit_breaker_open`, `degradation_threshold`
  - 3 sibling triggers for verdict-shape reuse: `manual` (F-020 kill-switch), `iteration_cap` (F-001 cycle-cap reuse), `tool_calls_quota` (F-022)
- `RunHaltedVerdict` interface — `{type:'RUN_HALTED', trigger, reason, timestamp, optional run_id/agent_id/trigger_evidence_sha256}`
- `HaltContext` interface — caller-supplied F-002 correlation triple + F-015 evidence anchor at fire time (all optional)
- `HaltDetectorConfig` interface — per-run threshold overrides (`maxConsecutiveFailures` default 3, `maxOverplanningReadOnly` default 5, `maxIterations` default 100, `maxToolCalls` default 200)
- `HaltDetector` class — `recordFailure` / `recordSuccess` / `recordReadOnlyTool` / `recordWriteTool` / `recordIteration` / `recordToolCall` / `manualHalt`. Reset semantics: `recordSuccess` resets consecutive-failures, `recordWriteTool` resets overplanning; iteration / tool-call counts are monotonic per-run

Override semantics: trigger NAMES stay canonical even when thresholds are overridden — the trigger identifies the FAMILY, not the count (acceptance scenario 3).

## Anomalies / context gaps

### A1 — Sibling-lane commit absorbed F-018 GREEN impl

**Severity**: HIGH (load-bearing for commit-history cleanliness; substantively benign — work landed correctly).

When wave-009 / lane-c started authoring the F-018 GREEN impl, sibling lane wave-009 / lane-a (F-006) and another lane (F-016) had uncommitted work in the working tree. Lane C's `git add packages/engine-core/src/index.ts && git commit ...` was raced by sibling commits twice in quick succession:

1. The first commit attempt (RED stub `eacc651`) accidentally captured a sibling lane's `tests/unit/F-016-query-audit-log.test.ts` + F-016 RED output. Per `rules/scope-discipline.md` this is a scope violation — lane-c's commit should have been F-018-only.
2. The GREEN impl staged file (engine-core/src/index.ts containing F-018 region) was captured by sibling commit `da48f2a` because sibling lane-a had concurrently restaged its own modifications. The F-018 GREEN code IS in HEAD (verified by grep) but the commit MESSAGE says F-006.

Per `rules/non-negotiable-rules.md` (no destructive git ops without authorization), `git reset --hard` to fix the commit history was not pursued. The substantive work landed; the audit trail is honestly surfaced here.

**Loop-improvement candidate** (in confidence-ledger as `Lane-C-w9-staging-race-with-sibling-lanes`): when multiple lanes modify the same file in disjoint append zones AND one lane is mid-staging a focused commit, a sibling's `git add` can absorb the first lane's staged hunks. Mitigations:
1. `git stash` set aside other-lane work before staging
2. `git add --patch` to interactively select only your hunks
3. Wave-level staging-lock convention: "no `git add packages/engine-core/src/index.ts` while another lane has uncommitted hunks in that file"

Option 3 recommended as wave protocol; option 2 as per-commit fallback.

### A2 — F-006 test fails locally because F-006 GREEN impl is not in HEAD

**Severity**: MEDIUM (sibling-lane cleanup pending; not blocking F-018).

`pnpm test:unit` runs 7 unit test files. After lane-c's F-018 GREEN landed (via absorbed da48f2a commit), sibling F-006 test file remains in HEAD but F-006's GREEN impl in index.ts was reverted by an earlier sibling commit (HEAD only has F-001 + F-002 + F-014 + F-015 + F-016 + F-018). Result: F-006 fails 4/4. F-018: 9/9 PASS.

This is a sibling-lane (Lane A wave-009) finalization gap, NOT a Lane C concern. Surfaced here so loop-state honestly reflects: Lane C work GREEN; Lane A's F-006 GREEN impl needs re-land commit.

### A3 — Brief's HaltTrigger enum diverges from F-018 ledger's 9-value enum

**Severity**: LOW (informational; resolved per FETCH BEFORE CITE / wave-008 lane-a precedent).

Wave-009 / lane-c brief proposed:

```typescript
HaltTrigger = 'consecutive_failures' | 'no_progress' | 'iteration_cap' | 'tool_calls' |
              'manual' | 'kill_switch' | 'governance' | 'soul_boundary' | 'degrade_escalate'
```

F-018 ledger's authoritative 9-value enum:

```
consecutive_failures_3 | consecutive_failures_10 | overplanning_5 | overplanning_8 |
spawns_per_hour_exceeded | token_anomaly_2x | rapid_prompt_burst | circuit_breaker_open |
degradation_threshold
```

Per FETCH BEFORE CITE / wave-008 lane-a precedent, the test encodes the ledger's enum as authoritative. Brief-proposed names like `manual`, `iteration_cap`, `tool_calls` were retained as 3 sibling triggers (renamed `tool_calls` → `tool_calls_quota` for clarity) for verdict-shape reuse by F-020 / F-001-cycle-cap / F-022. The 9-trigger automatic-halt enum is preserved.

## Scope deviations from prompt (intentional, documented)

The wave-009 / lane-c brief's deviations from what was actually executed:

1. **HaltTrigger enum** — brief proposed 9 simpler trigger names; ledger uses 9 count-bearing names. Honored ledger; added 3 sibling triggers from brief.
2. **Test count** — prompt said "6+ scenarios"; actual is 9 scenarios.
3. **Class API** — followed brief's `HaltDetector` / `recordFailure` / `recordSuccess` / `recordIteration` / `recordToolCall` / `manualHalt` shape. Added `recordReadOnlyTool` + `recordWriteTool` for the ledger's `overplanning_5` scenario (not in brief). Added `HaltContext` for F-002/F-015 correlation (not in brief; needed for `trigger_evidence_sha256` per ledger contract).
4. **Threshold defaults** — brief said `maxNoProgress=5, maxIterations=100, maxToolCalls=200`. Used `maxOverplanningReadOnly=5` (matches ledger's overplanning_5), kept iteration/tool-call defaults from brief.

All deviations reflect honoring the existing F-018 ledger over the prompt's stale brief.

## Out of scope (per `rules/no-silent-deferrals.md`)

- **F-006 logger surfacing of halt events** — logging-pipeline owns routing.
- **F-008 storage layout** — filesystem write to `runs/<run_id>/runtime-state.json`. Lane C's flip is in-memory only.
- **F-015 audit-evidence binding** — `trigger_evidence_sha256` field is in the verdict shape but binding to a real audit row is F-015's integration step.
- **F-020 kill-switch JSON file watcher** — F-020 will call `manualHalt()` from its watcher.
- **F-021 degradation-fallback source signal** — F-021 will source the `degradation_threshold` trigger.
- **F-022 per-tool quota source** — F-022 will source per-tool quotas; F-018 surfaces global tool-call counter as scaffolding.
- **Sibling lane re-land of F-006 GREEN impl** — Lane A wave-009 owns this.
- **Spawn-rate / token-anomaly / rapid-prompt / circuit-breaker source signals** — 4 of the 9 ledger triggers are part of the type union but await source signals from their respective owning features (TBD beyond M2).

## Confidence

HIGH (substantive work). MEDIUM (commit-history cleanliness, due to A1).

Source material — F-018 ledger acceptance scenarios + behavior contract + `.claude/rules/anomaly-thresholds.md` thresholds + F-014's `RetroOutcome.halted_by_failure_pattern` consumer contract — is consistent and unambiguous. RED baseline captured BEFORE the GREEN flip per the wave-005 retro proposal. 9/9 acceptance scenarios pass with real vitest output (not synthesized). Rule citations across the work — `scope-discipline.md`, `canonical-skill-only.md`, `no-silent-deferrals.md`, `non-negotiable-rules.md` (no destructive git) — reflect load-bearing discipline contracts.

## Quality-gate checklist (QG1-QG9 for wave-009 lane-c)

- [x] QG1 — net-new — F-018 GREEN flip is the sixth RED→GREEN in the repo and second M2 transition beyond F-014/F-015
- [x] QG2 — sources cited — every doc cites SOURCE; physical-proof.md cites ledger + actual test output; this summary cites rules + commit SHAs
- [x] QG3 — touches Goal G1-G37 — touches G1 (red→green ledgers), G27 (full behavior tests + physical proof), G37 (immediate working product — central halt mechanism for M2)
- [x] QG4 — backlog item processed/generated — generates: 6 deferred dependencies (F-006 / F-008 / F-015 / F-020 / F-021 / F-022) explicitly named; 4 ledger triggers awaiting source signals named; surfaces multi-lane staging-race loop-improvement
- [x] QG5 — loop-improvement proposal — see "Loop-improvement proposal" below
- [x] QG6 — multi-lane fan-out applied at wave level — wave-009 has 3+ lanes (Lane A: F-006; Lane C: F-018 this lane; Lane D: F-016 + backlog)
- [ ] QG7 — Copilot CLI design review — N/A this lane (RED→GREEN flips don't trigger council review per current convention)
- [ ] QG8 — Microsoft tools used — N/A this lane (engine-core implementation, not Microsoft-stack)
- [x] QG9 — open questions captured — A1, A2, A3 in Anomalies above

## Loop-improvement proposal (QG5)

Three observations from this lane that should feed wave-010+ discipline:

1. **Multi-lane staging-race protocol (HIGH).** Lane C's F-018 GREEN impl was captured by a sibling-lane commit message because both lanes raced `git add` on the same file. The substantive work landed correctly (HEAD has F-018) but the audit trail is muddled. Wave-010 takeaway: codify a per-file staging-lock convention OR adopt `git add --patch` as default for any lane modifying a multi-lane file. Concretely, propose `wiki/patterns/multi-lane-staging-discipline.md` with the lock convention + patch fallback.

2. **Per-feature engine-core file split (MEDIUM, longer-term).** As more features pile into `packages/engine-core/src/index.ts`, the contention zone grows. After M2 stabilizes, consider splitting into `engine-core/src/{lifecycle,identity,retro,audit,logging,halt,query}.ts` with `index.ts` as a barrel re-exporter. Per-file ownership eliminates the staging contention entirely. Wave-010 takeaway: log this as a refactor proposal in `docs/10-backlog/` for post-M2 consideration.

3. **Brief-vs-ledger reconciliation discipline (informational).** Lane-c brief's `HaltTrigger` enum diverged from ledger's; lane honored ledger per FETCH BEFORE CITE. This is the third lane (after wave-008 lane-a, lane-b) where brief and ledger diverged on a load-bearing field/enum name. Wave-010 takeaway: brief generation should diff against the live ledger's enum values and FLAG divergences in the brief itself, so the lane operator doesn't have to spot them.

## Reproduction

```bash
cd C:/Users/tonym/Repos/mad-council-claw
git log --oneline | head -10                                              # see lane-c's RED commit + absorbed GREEN
pnpm install
pnpm exec vitest run tests/unit/F-018-failure-pattern-halt.test.ts        # 9/9 PASS
pnpm test:unit                                                            # 35/39 PASS (F-006 sibling-lane gap)
cat docs/09-examples-proof/F-018/physical-proof.md                        # the audit anchor
```

## Push

Pending — `git push` per `rules/non-negotiable-rules.md` requires explicit user request. Lane C's RED commit + the absorbed GREEN hunk are local; user adjudication on the staging-race anomaly (A1) may inform whether to rewrite history (under explicit authorization) or push as-is with the audit-trail surfaced.
