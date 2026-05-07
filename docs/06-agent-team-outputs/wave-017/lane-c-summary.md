---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-017 / lane-c)
wave: wave-017
lane: lane-c
topic: F-026 resume-from-checkpoint + F-027 manual-halt-override RED → GREEN — closes M3 cron-heartbeat 100%
date: 2026-05-07
status: complete
---

# Wave 17 / Lane C — F-026 + F-027 RED → GREEN, M3 100% RED-cleared

## Scope

Flip F-026 (`resume-from-checkpoint` — `CheckpointManager` save/load/exists primitive) AND F-027 (`manual-halt-override` — `manualHaltOverride` async function with consent gate) from RED to GREEN per each ledger's `red-green-rule` predicate:

```
GREEN if all test files exist AND all runners return zero exit.
```

**Combined with Lane B's F-024 + F-025 RED → GREEN earlier this wave, this lane closes M3 cron-heartbeat 100% RED-cleared (5/5 GREEN).** M3 was 4R + 1G at wave-17 lane start (F-023 was the only GREEN feature, from wave-16/lane-b). Lane B dropped 4R → 2R + 3G; this lane drops the final 2R → 0R + 5G.

This is the **first milestone in the repo to reach 100% RED-cleared (5/5 GREEN) without any LOCKED yet** — M0/M1/M2 all reached 100% LOCKED via post-impl council reviews. The M3 GREEN → LOCKED batch is a wave-18+ candidate.

## What was created / modified

| Group | Path | Type |
|---|---|---|
| Test (F-026) | `tests/node/F-026-resume-from-checkpoint.test.ts` | new (~155 LOC, 6 scenarios) |
| Source (F-026) | `packages/engine-core/src/checkpoint.ts` | new (~80 LOC, ESM) |
| Test (F-027) | `tests/unit/F-027-manual-halt-override.test.ts` | new (~135 LOC, 6 scenarios) |
| Source (F-027) | `packages/engine-core/src/manual-halt.ts` | new (~80 LOC, ESM) |
| Wiring | `packages/engine-core/src/index.ts` | modified (2 new `export * from` lines: `./checkpoint.js`, `./manual-halt.js`) |
| Examples-proof | `docs/09-examples-proof/F-026/red-test-output.txt` | new (50 lines) |
| Examples-proof | `docs/09-examples-proof/F-026/green-test-output.txt` | new |
| Examples-proof | `docs/09-examples-proof/F-027/red-test-output.txt` | new (50 lines) |
| Examples-proof | `docs/09-examples-proof/F-027/green-test-output.txt` | new (verbose reporter output) |
| Ledger flip (F-026) | `docs/03-feature-catalog/M3-cron-heartbeat/F-026-resume-from-checkpoint.md` | modified (status: red → green; status-history append; test-files/test-runner-projects populated; Implementation notes section appended documenting wave-017/lane-c flip + scope deviation reconciliation + sighting #19+ audit trail) |
| Ledger flip (F-027) | `docs/03-feature-catalog/M3-cron-heartbeat/F-027-manual-halt-override.md` | modified (same shape as F-026) |
| Roadmap rows | `roadmap.md` | modified (F-026 + F-027 rows 🔴 → 🟢; M3 row 2R+3G+0L → 0R+5G+0L; TOTAL 100R+4G+22L → 98R+6G+22L; wave-017/lane-c transition note inserted before lane-b note) |
| Confidence-ledger | `docs/11-loop-state/confidence-ledger.md` | modified (Wave 17 Lane C section + 3 entries: Lane-C-w17-F-026-GREEN, Lane-C-w17-F-027-GREEN, Lane-C-w17-M3-100-percent-RED-cleared) |
| Lane summary | `docs/06-agent-team-outputs/wave-017/lane-c-summary.md` | new (this file) |

## Acceptance scenarios verified at GREEN

### F-026 — 6/6 PASS

| # | Scenario | What it proves |
|---|---|---|
| 1 | `save()` creates a checkpoint file at the configured path | atomic-write persistence path works; `.tmp` orphan does not remain |
| 2 | `load()` returns the saved state intact | round-trip preserves every caller-supplied field (runId/agentId/pipelinePhase/step/data) |
| 3 | `load()` returns null when no checkpoint file exists | callers map this to ledger scenario 2's `halted_by: lost_checkpoint` path |
| 4 | `exists()` reflects file presence | scheduler startup sweeps can inventory resumable runs without parsing |
| 5 | `schemaVersion` preserved verbatim through round-trip | future schema bump can detect incompatible on-disk formats |
| 6 | `savedAt` auto-injected at save time as ISO-8601 in [before, after] window | caller cannot fabricate stale timestamps |

### F-027 — 6/6 PASS

| # | Scenario | What it proves |
|---|---|---|
| 1 | `consentGate=()=>true` → `RUN_HALTED` verdict with `trigger='manual'` | F-018 sibling trigger reserved for operator halts honored |
| 2 | `consentGate=()=>false` → throws Error matching `/consent\|denied/i` | callers distinguish abort-by-user from real failures |
| 3 | `runId` stamped onto `verdict.run_id` verbatim | F-002 correlation preserved on the verdict |
| 4 | `reason` carried through to `verdict.reason` verbatim | `dangerous-operations-policy.md` audit-trail intent preserved |
| 5 | async `consentGate` (`Promise<true>`) is awaited | operators may need async UI confirmation step |
| 6 | timestamp captured at fire-time as ISO-8601 in [before, after] window | freshness, not session-cached |

12/12 PASS at GREEN time. **Full suite: 31 test files, 225/225 PASS.**

## Scope deviations recorded openly

Per `verification-protocol.md` Rule 1 (FETCH BEFORE CITE) + `no-silent-deferrals.md`:

### F-026 — `CheckpointManager` is a primitive, not the full ledger schema

The F-026 ledger §Behavior contract specifies a richer `runs/<run_id>/checkpoint.json` schema with `last_completed_cycle`, `cycle_state_sha256` (linking F-015 audit log), and `resumable: true`, plus a scheduler-startup sweep that resumes from `last_completed_cycle + 1` and emits a `resumed_from_checkpoint` audit entry.

The wave-017 lane-c brief simplifies this to a `CheckpointManager` class with:
- Constructor `new CheckpointManager(path: string)`.
- `save(input)` → returns `Checkpoint` with auto-injected `schemaVersion: 1` + ISO-8601 `savedAt`.
- `load()` → `Checkpoint | null` (catch-all swallows IO+parse errors per ledger's "no checkpoint" semantics).
- `exists()` → cheap presence check.

Substantive guarantees preserved:
- Atomic-write persistence (F-008 `atomicWriteJson` — no half-read).
- Missing-file → null contract (callers map to ledger scenario 2's `halted_by: lost_checkpoint` path).
- `schemaVersion: 1` round-trip preservation.
- `savedAt` auto-injection (caller cannot fabricate stale timestamps).

Deferred to caller integration:
1. F-015 audit-chain `cycle_state_sha256` verification + `CHECKPOINT_INTEGRITY_FAIL` → F-018 `audit_chain_broken` halt path (engine-cycle integration step).
2. `last_completed_cycle` advancement semantics + scheduler resume dispatch (F-023 caller integration).
3. Resume-marker re-write on advance + F-014 retro-on-lost-checkpoint emission (F-014 caller wiring).
4. Cross-machine resume — explicitly v1 out-of-scope per ledger §out-of-scope-notes.

### F-027 — `manualHaltOverride` is operation (2) only, not the full ledger contract

The F-027 ledger §Behavior contract specifies TWO distinct operations:
1. **Pause schedule** — write `paused: true` (with `paused_at_utc` + `paused_reason`) into `automations/cron-schedules.json`. Scheduler skips on next tick; `cron-fires.jsonl` records `outcome: "paused_skipped"`.
2. **Halt active run** — write to `kill-switch.json` (per F-020) which propagates within ≤1 cycle to halt in-flight runs.

The wave-017 lane-c brief simplifies to operation (2) only, exposed as a pure async function `manualHaltOverride()` returning the verdict shape shared with F-018/F-020:
- `manualHaltOverride({runId, reason, consentGate})` → `Promise<RunHaltedVerdict>`.
- Awaits the injected `consentGate()` (boolean OR `Promise<boolean>`).
- Returns a `RunHaltedVerdict` with `type: 'RUN_HALTED'`, `trigger: 'manual'`, `reason` verbatim, `run_id` stamped, ISO-8601 `timestamp`.
- Throws an Error containing "consent denied" when consent is false.

Deferred to caller integration:
1. Pause-schedule operation (F-023 HeartbeatScheduler caller wires `automations/cron-schedules.json` write).
2. Bulk-halt consent gate (>5 schedules) — caller-side per `dangerous-operations-policy.md` §Bulk Post.
3. `kill-switch.json` file write integration (F-020 caller wires).
4. F-014 retro-on-manual-halt emission (F-014 caller wires).
5. Multi-operator quorum on halts (v1 ledger out-of-scope).
6. Per-schedule role-based authorization (v1.5 ledger out-of-scope).

This mirrors F-022 ToolCallQuota + F-018 HaltDetector + F-023 HeartbeatScheduler + F-026 CheckpointManager pure-primitive pattern: primitive function/class + caller wires composition.

## Cross-lane staging-race sighting #19+ (chronic pattern continues across waves 9-17)

Two more sightings in this lane, both fix-forward per the user directive 2026-05-07 (NO `git reset` (any flavor)):

1. **F-026 GREEN files landed in commit `2463d90`** (subject "test(F-024,F-025): RED actual"). The pre-commit hook swept `packages/engine-core/src/checkpoint.ts` + `packages/engine-core/src/index.ts` (with my `./checkpoint.js` re-export) + `docs/09-examples-proof/F-026/green-test-output.txt` from the working tree into Lane B's commit before I had a chance to commit them under my lane's subject.

2. **F-027 GREEN files landed in commit `a8f5de2`** (subject "feat(F-030): GREEN cli-json-output"). Same pattern. The F-030 commit message even claims "Sibling-lane work (F-024/F-025/F-026/F-027/F-138 + engine-core edits) explicitly NOT touched per cross-lane staging-discipline" — and the file list immediately contradicts that claim:

   ```
   docs/09-examples-proof/F-027/green-test-output.txt |  15 +++
   packages/cli/src/index.ts                          |  12 ++-
   packages/cli/src/json-output.ts                    |  73 +++++++++++++
   packages/engine-core/src/index.ts                  |   3 +
   packages/engine-core/src/manual-halt.ts            | 117 +++++++++++++++++++++
   ```

Per `non-negotiable-rules.md` (no destructive git ops; user directive 2026-05-07: NO `git reset`), no rebase/reset to fix history. **Substance preserved (verified by 12/12 tests PASS at GREEN; full suite 225/225 PASS post-flip)**; credit attribution in commit subjects is corrupted. Authoritative provenance documented in:
- F-026 ledger §Implementation notes (`docs/03-feature-catalog/M3-cron-heartbeat/F-026-resume-from-checkpoint.md`).
- F-027 ledger §Implementation notes (`docs/03-feature-catalog/M3-cron-heartbeat/F-027-manual-halt-override.md`).
- This lane summary.
- Confidence-ledger entries `Lane-C-w17-F-026-GREEN` + `Lane-C-w17-F-027-GREEN`.

Per `verification-protocol.md` Rule 1 (FETCH BEFORE CITE), the file's actual provenance is documented here in the ledger Implementation notes — the authoritative record beats the commit subject for archaeology.

## Cross-feature observations

- **M3 cron-heartbeat 100% RED-cleared** is the first milestone-100%-RED-cleared event in the repo without LOCKED yet. M0+M1+M2 reached 100% LOCKED via post-impl council reviews; M3 jumps to 100% RED-clear before any LOCKED. Council-review wave for M3 (F-023..F-027 GREEN → LOCKED) is a wave-18+ candidate. The five M3 primitives compose into the cron-spawned-run shape that the engine-cycle orchestrator (F-138, wave-17 lane-a) consumes: heartbeat ticks; in-flight overlaps skip; idle gaps trigger archival; cycle-boundary state persists; operator halts produce verdicts.
- **Pure-primitive pattern is consistent across M3 + F-022 + F-018**: `~80-150 LOC` per primitive; no inter-primitive dependency in this milestone (composition is the caller's job). This validates the wave-002 catalog architecture choice that primitive features are independently testable + LOCK-able + reusable.
- **`RunHaltedVerdict` reuse from `halt.ts` (F-018 first-owner)** is the right shape for F-027 per the wave-011/lane-a "shared types live with FIRST owner" rule. F-027 imports the verdict type via `import type { RunHaltedVerdict } from './halt.js'`; manualHaltOverride does NOT redeclare or extend the shape, just constructs it.

## Pre-commit gate friction (recorded for future contributors)

The cross-lane staging-race that swept F-026/F-027 GREEN files into other lanes' commits is now documented across **5 lanes' worth of summaries** (waves 16-17): wave-16/lane-a (sighting #16), wave-16/lane-b (#16), wave-17/lane-a (mentioned), wave-17/lane-b (#17), this lane (#19+). The pattern is chronic. Mitigation candidates pending council deliberation per Lane B's confidence-ledger entry:

- (a) **per-lane branches when concurrent lane count ≥3** — root cause is direct-to-main pattern.
- (b) **per-commit `git diff --cached --name-only` assert** listed in commit-message hook.
- (c) **per-feature scope manifest at `.mad/wave-N/lane-X/scope.txt`** with pre-commit reject on cached-but-not-listed files.

The chained-restore-staged-add-commit-in-single-bash pattern Lane B used is a TACTICAL workaround that minimizes (but does not eliminate) the race window. The strategic fix is per-lane branches.

This lane's only mitigation was: stage selectively via `git restore --staged <other-lane-paths>` after every `git add`, then commit immediately. Even that proved insufficient — the pre-commit hook still swept files added between my `git add` and `git commit` steps. Until the strategic fix lands, the documentation-in-Implementation-notes pattern is the right tactical response per `verification-protocol.md` Rule 1.

## Commit chain (logical — actual SHAs corrupted by staging race)

| # | Commit (intended) | Subject (truncated) | Actual landing |
|---|---|---|---|
| 1 | RED F-026 | `test(F-026): RED resume-from-checkpoint CheckpointManager 6 scenarios. Gate Results: 0 passed, 6 failed (CheckpointManager not exported yet — RED captured per F-026 ledger red-green-rule).` | `a309db8` (clean — landed exactly the 2 staged files) |
| 2 | GREEN F-026 | `feat(F-026): GREEN resume-from-checkpoint CheckpointManager ~80 LOC.` | **swept into `2463d90`** (subject "test(F-024,F-025): RED actual") |
| 3 | RED F-027 | `test(F-027): RED manual-halt-override 6 scenarios. Gate Results: 0 passed, 6 failed (manualHaltOverride not exported yet — RED captured per F-027 ledger red-green-rule).` | `de0c271` (clean — landed exactly the 2 staged files) |
| 4 | GREEN F-027 | `feat(F-027): GREEN manual-halt-override ~80 LOC.` | **swept into `a8f5de2`** (subject "feat(F-030): GREEN cli-json-output") |
| 5 | DOCS | `docs(F-026,F-027,M3): RED → GREEN ledgers + roadmap + confidence-ledger + lane-c summary. M3 cron-heartbeat 100% RED-cleared (5/5 GREEN). Gate Results: 31 test files, 225/225 PASS.` | (this commit; coming next) |

## Provenance

- Wave: wave-017
- Lane: lane-c
- Date: 2026-05-07
- F-026 ledger: `docs/03-feature-catalog/M3-cron-heartbeat/F-026-resume-from-checkpoint.md`
- F-027 ledger: `docs/03-feature-catalog/M3-cron-heartbeat/F-027-manual-halt-override.md`
- Foundational plan: V:5 (cron + heartbeat foundation for autonomous-loop M3)
- Cross-source convergence:
  - F-026 — kit:rules/resume-protocol.md (resume discipline) + kit:resume-handoff-skill (resume-from-handoff pattern) + ce:FR-CORE-002 (run lifecycle through `active`)
  - F-027 — kit:rules/dangerous-operations-policy.md (consent gate) + ce:FR-KILL-001 (kill-switch propagation into cron-spawned runs)
- Push at end of lane authorized for this loop session per user directive 2026-05-07.
