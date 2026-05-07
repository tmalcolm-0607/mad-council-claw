---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-017 / lane-b)
wave: wave-017
lane: lane-b
topic: F-024 skip-on-overlap + F-025 idle-archival RED → GREEN (paired flip)
date: 2026-05-07
status: complete
---

# Wave 17 / Lane B — F-024 + F-025 RED → GREEN (paired flip)

## Scope

Flip F-024 (skip-on-overlap) AND F-025 (idle-archival) RED → GREEN per their respective ledger §Behavior contracts. Both are M3 (cron / heartbeat) features that compose on top of F-023's `HeartbeatScheduler` (wave-016 / lane-b GREEN). Per the F-022 ToolCallQuota / F-018 HaltDetector / F-023 cron-heartbeat pure-class + composition-by-callers pattern, both extensions land as same-class additions on `HeartbeatScheduler` rather than as separate primitives.

## Outcome

**F-024 + F-025 RED → GREEN** in 5 commits across the lane (RED with sighting #17 fix-forward chain, GREEN heartbeat.ts + proofs, ledgers, roadmap, lane summary). 16/16 isolated PASS for F-024 + F-025; 21/21 PASS for F-023 (no regression). Full suite 219/225 PASS — the 6 fails are sibling lane F-027 RED, not this lane's scope.

| State | Test result | Files added/modified |
|---|---|---|
| RED | 16/16 fail (`TypeError: HeartbeatScheduler.onIdleArchive is not a function`; tick() return shape mismatch) | tests/unit/F-024-skip-on-overlap.test.ts (new); tests/unit/F-025-idle-archival.test.ts (new) |
| GREEN | 16/16 PASS isolated; 37/37 PASS for F-023+F-024+F-025 combined; 219/225 full suite (6 sibling-lane RED fails) | packages/engine-core/src/heartbeat.ts (~50 added LOC: tickInFlight, skippedTicks, TickResult, IdleArchiveCallback, archiveAfterMinutes config, onIdleArchive method, idle-gap detection in tick()) |

## Test results

```
$ pnpm test -- --run tests/unit/F-024-skip-on-overlap.test.ts tests/unit/F-025-idle-archival.test.ts tests/unit/F-023-cron-heartbeat.test.ts
 ✓ tests/unit/F-025-idle-archival.test.ts (8 tests) 15ms
 ✓ tests/unit/F-024-skip-on-overlap.test.ts (8 tests) 13ms
 ✓ tests/unit/F-023-cron-heartbeat.test.ts (21 tests) 35ms
 Test Files  3 passed (3)
      Tests  37 passed (37)
   Duration  ~1.7s

$ pnpm test  (full suite)
 Test Files  1 failed | 30 passed (31)
      Tests  6 failed | 219 passed (225)
```

The 6 fails are F-027 (sibling lane RED) — not in this lane's scope.

## What landed

1. **`tests/unit/F-024-skip-on-overlap.test.ts`** (8 scenarios across 4 describe blocks):
   - basic skip-on-overlap (2): tick skips when prior tick is still in-flight; skippedTicks counter increments on each skipped fire
   - in-flight flag lifecycle (2): in-flight clears after handler completes; in-flight clears even when handler throws (THROW-PATH discipline)
   - sequential vs parallel ticks (2): sequential ticks both run normally; parallel manual tick calls return correct ran flags
   - getStatus observability (2): reports skippedTicks=0 + isInFlight=false initially; isInFlight is true while handler runs and false after
2. **`tests/unit/F-025-idle-archival.test.ts`** (8 scenarios across 4 describe blocks):
   - threshold semantics (3): archiveAfterMinutes triggers callback when idle exceeds threshold; no callback when idle is below threshold; idle measured from lastTickAt (not from creation)
   - callback registration (2): multiple callbacks supported (broadcast pattern); default archiveAfterMinutes=undefined disables the trigger
   - observability (2): callback receives idleMinutes argument equal to elapsed time; callback fires on each tick where idle exceeds threshold
   - composition with F-024 (1): skipped ticks do NOT fire idle-archival callback
3. **`packages/engine-core/src/heartbeat.ts`** (~50 added LOC) — same-class extensions:
   - F-024 fields: `tickInFlight: boolean`, `skippedTicks: number`
   - F-024 return shape: `TickResult { ran: boolean; skipped?: boolean }` (backward-compatible — F-023 callers discarded the value)
   - F-024 throw-path discipline: `try/finally` clears `tickInFlight` on throw so a single failed tick does NOT permanently block subsequent ticks
   - F-025 config: `archiveAfterMinutes?: number` on `HeartbeatConfig`
   - F-025 type: `IdleArchiveCallback` exported
   - F-025 registration: `onIdleArchive(cb)` method (broadcast; unregister deliberately omitted for v1)
   - F-025 detection: idle-gap measured BEFORE updating `lastTickAt` so callbacks see actual gap from prior-tick to now
   - Updated `HeartbeatStatus` with `skippedTicks` + `isInFlight` for observability
4. **`docs/09-examples-proof/F-024/{red,green}-test-output.txt`** + **`docs/09-examples-proof/F-025/{red,green}-test-output.txt`** — RED + GREEN witnesses.
5. **F-024 ledger** + **F-025 ledger** updates: status: red → green; status-history append; test-files populated; Implementation notes §authored documenting same-class-extension rationale + scope reconciliation per `no-silent-deferrals.md` + sighting #17 audit trail.
6. **Roadmap** (`roadmap.md`): F-024 + F-025 rows 🔴 → 🟢; M3 row 4R + 1G → 2R + 3G; TOTAL aggregate refresh 102R + 2G + 22L → 100R + 4G + 22L; Wave-17 / Lane B transition note.
7. **Confidence ledger** (`docs/11-loop-state/confidence-ledger.md`): 3 entries — `Lane-B-w17-F-024-GREEN`, `Lane-B-w17-F-025-GREEN`, `Lane-B-w17-staging-race-sighting-17`.
8. This summary file.

## Scope reconciliation (FETCH BEFORE CITE on the F-024 + F-025 ledgers)

### F-024 — skip-on-overlap

The ledger names cron-fires.jsonl `outcome: "overlap_skipped"` + `prior_fire_id` cross-link, cross-schedule independence, and run-lifecycle "still active" detection. F-024's primitive is intentionally **just the in-process SKIP signal** — the scheduler's `tick()` returns a `{ ran, skipped? }` shape that callers consume.

Per `no-silent-deferrals.md`, every non-implemented surface is named and explicitly owned by a downstream feature/layer:

- **`cron-fires.jsonl` write** → F-006 (logging-pipeline) + F-008 (storage-layout) callers consume the SKIP signal and append the entry.
- **Cross-schedule independence** → mirrored on F-022's one-quota-per-resource shape: separate `HeartbeatScheduler` instances per schedule. Structurally guaranteed by per-instance state; no cross-schedule scenario test added because there's nothing to test in the class itself.
- **Run-lifecycle "still active" detection** → caller-side. F-024's same-schedule guard is based on whether the handler PROMISE has resolved, not on whether the spawned RUN has reached `closed`. The two are equivalent for in-process orchestration but diverge for out-of-process runs (F-031 daemon-mode); when that lands, the orchestrator's tick handler will await the run closure before resolving its promise — preserving the F-024 contract without changes here.

### F-025 — idle-archival

The ledger names atomic-rename of `runs/<run_id>/` to `archive/runs/<YYYY>/<MM>/<run_id>/`, idempotent re-runs, orphan-recovery on process kill mid-rename, and the 14-day default threshold from `automations/archival-policy.json`. F-025's primitive is intentionally **just the IDLE TRIGGER** — the scheduler measures the gap from the prior tick and fires registered callbacks when the threshold is exceeded.

Per `no-silent-deferrals.md`:

- **Atomic-rename + orphan recovery** (per `concurrency-safety.md` §2 + §Edge cases) → F-008 (local-storage-layout) layer. F-025 contributes the in-process trigger only; the on-disk move is a storage-layout concern, not a scheduler concern.
- **14-day default threshold + policy file** → consumed by callers from `automations/archival-policy.json`. F-025's primitive accepts a numeric `archiveAfterMinutes` and the policy-file plumbing belongs to the M7 (skills/permissions/automations) layer.
- **Cross-machine archive sync** → out of scope per ledger §out-of-scope-notes (v1).
- **Compression / cold-storage tiering** → v1.5 (F-NNN candidate, not yet allocated) per ledger.

## F-024 + F-025 composition is the load-bearing detail

The in-flight guard (F-024) returns early BEFORE the idle-archival check (F-025), so:

- Skipped ticks (which don't update `lastTickAt` and don't invoke the handler) also do NOT fire the idle-archival callback.
- The idle-archival callback observes the gap from the LAST SUCCESSFUL tick — not from the last attempted tick.

This is the right shape: a skipped tick means the prior tick is still doing work, which is the canonical "current activity"; archival should not fire while the channel is actively running. Test scenario `composition with F-024 / skipped ticks do not fire idle-archival callback` exercises this contract directly.

## Throw-path discipline (F-024)

Clearing `tickInFlight` in `finally` (not at the end of `try`) is load-bearing. If a single tick's handler throws and the flag isn't cleared, every subsequent tick gets skipped — a silent halt. The test scenario `in-flight clears even when handler throws` directly exercises this and is the canary for future maintenance changes.

This composes naturally with F-018 RUN_HALTED + F-021 degradation orchestration: a failed tick should be RE-TRYABLE (the next cadence fires normally), not PERMANENTLY-BLOCKED. The throw-path discipline is what makes that orchestration story possible.

## Cross-lane staging-race sighting #17

At Lane B execution time, the working tree had heavy mid-flight WIP from concurrent lanes (Wave-17 / Lane A executing F-138; sibling F-026, F-027, F-029, F-030 RED lanes; pre-existing un-committed state from earlier waves).

Two consecutive commits used this lane's subject `test(F-024,F-025): RED ...` but committed concurrent lanes' files:

1. **`e466b52 test(F-024,F-025): RED ...`** — actually committed `tests/node/F-029-cli-subcommands.test.ts` (sibling F-029 lane).
2. **`2463d90 test(F-024,F-025): RED actual ...`** — actually committed `docs/09-examples-proof/F-026/green-test-output.txt`, `packages/engine-core/src/checkpoint.ts`, `packages/engine-core/src/index.ts`, `tests/node/F-030-cli-json-output.test.ts` (sibling F-026 + F-030 lanes).

Fix-forward: commit `b957489 test(F-024,F-025): RED actual files (sighting #17 third attempt)` chained `git restore --staged + git add + git commit` in a single bash invocation to minimize the race window. The 4 staged F-024/F-025 RED files (2 test files + 2 proof files) landed exactly. The subsequent GREEN commit `4a61494 feat(F-024,F-025): GREEN` used the same chained pattern and landed exactly the 3 staged files (heartbeat.ts + 2 GREEN proofs).

Per `non-negotiable-rules.md` (NO destructive git ops, NO `git reset` per user directive 2026-05-07), no rebase/reset to fix history. The leak is acknowledged for audit-trail integrity, not remediated by rewriting history.

This is **sighting #17** of the pattern documented in waves 9-16 (sightings #14, #15, #16). The pattern is at this point **chronic** across waves 9-17. The wave-17+ recurrence-mitigation candidates (per-lane branches when concurrent lane count ≥3, OR per-commit `git diff --cached --name-only` assert via commit-message hook) are pending council deliberation.

The chained-restore-staged-add-commit-in-single-bash pattern this lane used is a TACTICAL workaround that minimizes (but does not eliminate) the race window — the strategic fix is per-lane branches.

## Verification trail

```
$ git log --oneline -10  (post-lane)
4a61494 feat(F-024,F-025): GREEN - HeartbeatScheduler skip-on-overlap + idle-archival
b957489 test(F-024,F-025): RED actual files (sighting #17 third attempt)  ← actual RED landing
2463d90 test(F-024,F-025): RED actual files (sighting #17 fix-forward)  ← swept F-026/F-030
e466b52 test(F-024,F-025): RED - skip-on-overlap + idle-archival ...  ← swept F-029
a309db8 test(F-026): RED resume-from-checkpoint CheckpointManager 6 scenarios
1d4d81b docs(wave-016/lane-a): lane summary for 4 LOCKED transitions
c30c54b docs(F-023): RED -> GREEN ledger + roadmap + confidence-ledger + lane-b-summary
8842414 design(copilot-cli-review): wave-016 M0+M1+M2 impl review
d774e8b docs(F-028): RED -> GREEN ledger ...
0d4c84a docs(F-023): GREEN proof artifacts

$ pnpm test -- --run tests/unit/F-024-skip-on-overlap.test.ts tests/unit/F-025-idle-archival.test.ts
 Test Files  2 passed (2)
      Tests  16 passed (16)
```

## Future M3 work

After this lane:
- **F-024 + F-025 GREEN → LOCKED**: post-impl council reviews (verdicts ACCEPT pending).
- **F-026 (resume-from-checkpoint)**: sibling lane WIP — currently RED.
- **F-027 (manual-halt-override)**: sibling lane WIP — currently RED (the 6 full-suite failures observed at GREEN time).
- **`cron-fires.jsonl` log append wiring** (F-006 + F-008 callers consuming F-024's SKIP signal).
- **Storage-layout archive-rename + orphan-recovery** (F-008 layer consuming F-025's IDLE callback).

The M3 milestone has 2 features remaining RED after this paired flip (F-026, F-027); 3 features GREEN (F-023, F-024, F-025).
