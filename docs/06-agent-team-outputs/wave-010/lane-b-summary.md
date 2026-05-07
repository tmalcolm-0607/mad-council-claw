---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-010 / lane-b)
wave: wave-010
lane: lane-b
topic: F-020-kill-switch-RED-GREEN
date: 2026-05-07
status: complete
---

# Wave 10 / Lane B — F-020 kill-switch RED → GREEN

## Scope

Eighth feature transition RED → GREEN in the repo (after F-001 wave-005, F-002 wave-006, F-014 wave-008/lane-a, F-015 wave-008/lane-b, F-006 wave-009/lane-a, F-016 wave-009/lane-b, F-018 wave-009/lane-c, F-008 + F-019 wave-010 sibling lanes). Third standalone M2 governance feature beyond F-014/F-015/F-018 to flip GREEN — completes the kill-switch primitive that future F-001 cycle-start hook integration will call before every model + tool invocation.

The behavior-contract surface lands the in-memory `KillSwitch` primitive that the engine-cycle integration step will plug into. JSON schema parsing of `kill-switch.json`, F-001 cycle-start hook wiring, F-008 path resolution, F-014 retro consumer routing, and F-015 audit-log entries are explicitly deferred per `rules/no-silent-deferrals.md`.

Wave-010 ran with multiple lanes in parallel:
- **Lane A**: F-019 cost-ledger (M2)
- **Lane B (this lane)**: F-020 kill-switch (M2)
- **Lane C**: F-022 tool-call-quota (M2)
- **Lane D**: F-008 local-storage-layout (M0)

All four lanes modified `packages/engine-core/src/index.ts` in disjoint append-only zones. The 5th sighting of the multi-lane staging-race pattern (4 sightings prior across waves 9-10) is documented below in Anomaly A1.

## What was created / modified

| Group | Path | Type | Count |
|---|---|---|---|
| RED test stub | `tests/unit/F-020-kill-switch.test.ts` | new | 1 |
| RED test output | `docs/09-examples-proof/F-020/red-test-output.txt` | new | 1 |
| GREEN impl additions | `packages/engine-core/src/index.ts` | modified (~175 LOC added in F-020 region; wave-010 sibling lanes added F-008 + F-019 + F-022 in their own zones) | 1 |
| GREEN test output | `docs/09-examples-proof/F-020/green-test-output.txt` | new | 1 |
| Ledger transition | `docs/03-feature-catalog/M2-governance-triad/F-020-kill-switch.md` | modified (status red→green; status-history; test-files; wire-up; impl notes; reproduction) | 1 |
| Roadmap update | `roadmap.md` | modified (M2 row 3R+6G→2R+7G; TOTAL row 26R+10G→25R+11G; F-020 detail row 🔴→🟢) | 1 |
| Confidence-ledger entries | `docs/11-loop-state/confidence-ledger.md` | modified (lane-b wave-010 entries: 5 entries) | 1 |
| Physical proof | `docs/09-examples-proof/F-020/physical-proof.md` | new | 1 |
| This summary | `docs/06-agent-team-outputs/wave-010/lane-b-summary.md` | new | 1 |
| **Total touched** | | | **9 artifacts** |

## Commit chain

| # | SHA | Subject | Notes |
|---|---|---|---|
| 1 | `f142eb1` | `test(F-020): RED test stub for kill-switch` | Substantively correct (RED-before-GREEN, output captured); absorbed sibling F-022 RED stub due to multi-lane staging race (Anomaly A1 below) |
| 2 | `7b70c5a` | `feat(F-020): GREEN impl — read-time-propagating kill switch` | Clean (only `packages/engine-core/src/index.ts` + `green-test-output.txt`). Single-shell stage-then-commit discipline prevented absorption on the second pass |
| 3 | (this commit) | Ledger + roadmap + confidence-ledger + physical-proof + lane-b-summary | Pure docs; no contention-zone files. Lands cleanly under lane-b's own message |

## Vitest output

```
RUN  v2.1.9 C:/Users/tonym/Repos/mad-council-claw

✓ tests/unit/F-020-kill-switch.test.ts (11 tests) 8ms

Test Files  1 passed (1)
     Tests  11 passed (11)
  Duration  1.11s
```

Full unit suite at GREEN time: **66/66 PASS** across 10 test files (F-001 + F-002 + F-006 + F-008 + F-014 + F-015 + F-016 + F-018 + F-019 + F-020).

## RED→GREEN transition

| Phase | State | Test result |
|---|---|---|
| RED (commit f142eb1) | `KillSwitch` not exported; `defaultKillFileExists` not defined | 11/11 fail with `TypeError: KillSwitch is not a constructor` |
| GREEN (commit 7b70c5a) | `KillSwitch` + `defaultKillFileExists` exported from `packages/engine-core/src/index.ts` (~175 LOC F-020 region appended at EOF) | 11/11 PASS |

Output captured: `docs/09-examples-proof/F-020/{red,green}-test-output.txt`.

## Surface inventory (the F-020 GREEN region)

- `defaultKillFileExists(path)` — module-private helper. Lazy `node:fs.existsSync` wrapper that fail-safes to `false` on errors.
- `KillSwitch` class — `constructor(killFilePath, envVarName, fileExistsFn, env)` with all 4 dependencies defaulted for ergonomics + injectable for testability:
  - `killFilePath: string | null = null` — null means no file check.
  - `envVarName: string = 'MAD_KILL'` — env var consulted for the truthy gate (`'1'` or `'true'`).
  - `fileExistsFn = defaultKillFileExists` — injectable existence check.
  - `env: Record<string, string | undefined> = process.env` — injectable env source.
- Methods:
  - `isTriggered(): boolean` — read-time propagation (re-reads env + FS each call); no internal state mutation.
  - `checkOrThrow(): void` — throws `Error & { verdict: RunHaltedVerdict }` when triggered with `trigger='manual'`, contextual `reason` (env / file / both), and ISO-8601 `timestamp`.

Verdict-shape reuse: F-018's `RunHaltedVerdict` is the canonical halt-reporting surface; F-020 reuses it with `trigger='manual'` (the F-018 sibling trigger reserved for operator/kill-switch invocations). F-014's `RetroOutcome.halted_by_kill_switch` consumes this when the engine-cycle integration step catches the throw.

## Anomalies / context gaps

### A1 — RED commit absorbed sibling lane F-022 RED stub (5th sighting of the cross-lane staging-race pattern)

**Severity**: HIGH (load-bearing for commit-history cleanliness; substantively benign — the work landed correctly).

When wave-010 / lane-b started authoring the F-020 RED test, sibling lanes had uncommitted F-022 RED stub files in the working tree (`tests/unit/F-022-tool-call-quota.test.ts` + `docs/09-examples-proof/F-022/red-test-output.txt`). Lane B's RED commit `f142eb1` absorbed those F-022 files.

Specific mechanism observed: between Lane B's `git add` and `git commit`, a sibling lane appeared to run a `git reset HEAD~1` that unstaged Lane B's hunks but left other lanes' files in the index. Subsequent re-add absorbed them. Lane B's GREEN commit `7b70c5a` was clean (only 2 files) because the wave-010 single-shell stage-then-commit discipline (used on the second pass) prevented absorption.

Per `rules/non-negotiable-rules.md` (no destructive git ops without authorization), `git reset --hard` to fix the RED commit history was NOT pursued. The substantive work landed; the audit trail is honestly surfaced in the commit message + this summary + the F-020 ledger status-history note + the confidence-ledger entry `Lane-B-w10-staging-race-with-sibling-lanes`.

**Fifth sighting**:
1. Wave-9 Lane B (F-016) — `Lane-B-w9-cross-lane-race-credit-misattribution`
2. Wave-9 Lane C (F-018) — `Lane-C-w9-staging-race-with-sibling-lanes`
3. Wave-10 Lane A (F-019) — race-resistant via single-shell discipline (clean)
4. Wave-10 Lane C (F-022) — `Lane-C-w10-staging-race-redux`
5. Wave-10 Lane B (F-020) — this lane

**Wave-11+ priority HIGH**: per-feature engine-core file split (`engine-core/src/{halt,killswitch,cost,quota,storage,audit,query,logging,...}.ts` with `index.ts` as a barrel re-exporter) is now mandatory. The "explicit per-lane staging discipline" mitigation works for 2-3 concurrent lanes but NOT for 4+. Per-file ownership eliminates the contention zone entirely.

### A2 — Brief-vs-ledger shape divergence (5th sighting)

**Severity**: MEDIUM, but **promoting to HIGH for wave-011** per the Lane A wave-010 promotion threshold.

The wave-010 / lane-b brief specifies a narrower KillSwitch shape (constructor with 4 injected deps, env + file existence check) than the F-020 ledger §Behavior contract (full JSON schema with `{halted, reason?, set_at_utc?, set_by?}`). Per FETCH-BEFORE-CITE / wave-009 precedent, encode the brief's narrower in-memory primitive and surface the broader ledger surface as documented out-of-scope per `rules/no-silent-deferrals.md`.

Five sightings across waves 9-10:
1. Wave-9 Lane A — F-006 (4 levels brief vs 6 levels ledger)
2. Wave-9 Lane C — F-018 (HaltTrigger enum names)
3. Wave-10 Lane A — F-019 (8-field brief vs 11-field ledger)
4. Wave-10 Lane D — F-008 (storage-layout breadth)
5. Wave-10 Lane B — F-020 (this lane: in-memory primitive vs JSON schema)

Lane A wave-010 entry pre-flagged "promote from MEDIUM to HIGH at next wave if 5th sighting occurs" — **this lane's flip IS the 5th sighting**. Promotion: brief-generation tooling MUST diff against live ledger frontmatter + behavior contract at brief-write time and surface divergences inline.

## Scope deviations from prompt (intentional, documented)

The wave-010 / lane-b brief's deviations from what was actually executed:

1. **API shape** — brief proposed a `KillSwitch` class with constructor + `isTriggered()` + `checkOrThrow()`. Implemented exactly that, plus `defaultKillFileExists` helper as a module-private dependency for the default `fileExistsFn`.
2. **Test count** — prompt said "5+ scenarios"; actual is 11 scenarios. Two extended scenarios cover env-truthy gate (only `'1'`/`'true'` triggers) and read-time propagation across env mutation.
3. **JSON schema parsing** — F-020 ledger names `userData/mad-council-claw/kill-switch.json` with `{halted, reason?, set_at_utc?, set_by?}` schema. Brief simplifies to existence-check only. Honored brief; surfaced 5 explicit out-of-scope items in F-020 ledger §out-of-scope-notes.

## Out of scope (per `rules/no-silent-deferrals.md`)

- **F-001 cycle-start hook integration** — F-001's bootstrap loop will call `KillSwitch.checkOrThrow()` at the START of each cycle.
- **F-008 storage path resolution** — F-008 owns the kill-switch file path (e.g. `<userData>/mad-council-claw/kill`).
- **F-014 retro consumer wiring** — F-014's `RetroOutcome.halted_by_kill_switch` consumes the verdict; the engine cycle catches the throw and routes there.
- **F-015 audit-log entry** — F-015 will record each kill-switch read result for forensic replay.
- **JSON schema parsing** — kill-switch.json full schema (`halted` boolean + `reason` + `set_at_utc` + `set_by`) — engine-cycle integration step.
- **Sibling-lane file-split refactor** — wave-11 LOOP IMPROVEMENT (per A1).

## Confidence

HIGH (substantive work). MEDIUM (commit-history cleanliness, due to A1 — the 5th sighting).

Source material — F-020 ledger acceptance scenarios + behavior contract + F-018 `RunHaltedVerdict` consumer contract + `rules/no-silent-deferrals.md` — is consistent and unambiguous. RED baseline captured BEFORE the GREEN flip per the wave-005 retro proposal. 11/11 acceptance scenarios pass with real vitest output (not synthesized). Rule citations across the work — `scope-discipline.md`, `canonical-skill-only.md`, `no-silent-deferrals.md`, `non-negotiable-rules.md` (no destructive git), `minimum-change.md` (verdict-shape reuse instead of new error class) — reflect load-bearing discipline contracts.

## Quality-gate checklist (QG1-QG9 for wave-010 lane-b)

- [x] QG1 — net-new — F-020 GREEN flip is the eighth RED→GREEN in the repo and third standalone M2 transition beyond F-014/F-015/F-018
- [x] QG2 — sources cited — every doc cites SOURCE; physical-proof.md cites ledger + actual test output; this summary cites rules + commit SHAs
- [x] QG3 — touches Goal G1-G37 — touches G1 (red→green ledgers), G27 (full behavior tests + physical proof), G37 (immediate working product — operator kill switch surface)
- [x] QG4 — backlog item processed/generated — generates: 5 deferred dependencies (F-001 cycle hook / F-008 path / F-014 retro / F-015 audit / JSON schema) explicitly named; surfaces 5th sighting of multi-lane staging race + 5th sighting of brief-vs-ledger divergence
- [x] QG5 — loop-improvement proposal — see "Lessons / loop-improvement notes for wave-11" in physical-proof.md (3 proposals: file-split refactor mandatory, brief-vs-ledger reconciliation promoted to HIGH, verdict-shape reuse pattern validated)
- [x] QG6 — multi-lane fan-out applied at wave level — wave-010 has 4 lanes (A: F-019; B: F-020 this lane; C: F-022; D: F-008)
- [ ] QG7 — Copilot CLI design review — N/A this lane (RED→GREEN flips don't trigger council review per current convention)
- [ ] QG8 — Microsoft tools used — N/A this lane (engine-core implementation, not Microsoft-stack)
- [x] QG9 — open questions captured — A1, A2 in Anomalies above

## Loop-improvement proposals (QG5)

1. **Per-feature engine-core file split is now mandatory (HIGH, 5th sighting).** Five sightings of the cross-lane staging-race pattern across waves 9-10. The "explicit per-lane staging discipline" mitigation does not scale to 4+ concurrent lanes. Wave-11 should land `engine-core/src/{halt,killswitch,cost,quota,storage,audit,query,logging,...}.ts` with `index.ts` as a barrel re-exporter.

2. **Brief-vs-ledger reconciliation discipline (5th sighting; PROMOTING TO HIGH).** Wave-11 mandate: brief-generation tooling MUST diff against live ledger frontmatter + behavior contract at brief-write time and surface divergences inline.

3. **Verdict-shape reuse pattern formalized (HIGH).** F-020's reuse of F-018's `RunHaltedVerdict` validates the pattern. Wave-11 reusable rule: when a feature emits a halt, REUSE the F-018 verdict shape with the appropriate sibling trigger; adding a new top-level halt type means adding it to the F-018 `HaltTrigger` union FIRST, with explicit ledger/test alignment.

## Reproduction

```bash
cd C:/Users/tonym/Repos/mad-council-claw
git log --oneline | head -10                                              # see lane-b's RED + GREEN commits
pnpm install
pnpm exec vitest run tests/unit/F-020-kill-switch.test.ts                 # 11/11 PASS
pnpm test:unit                                                            # 66/66 PASS across 10 files
cat docs/09-examples-proof/F-020/physical-proof.md                        # the audit anchor
```

## Push

Pending — `git push` per `rules/non-negotiable-rules.md` requires explicit user request. Lane B's RED + GREEN commits + this summary commit are local; push deferred to user adjudication.
