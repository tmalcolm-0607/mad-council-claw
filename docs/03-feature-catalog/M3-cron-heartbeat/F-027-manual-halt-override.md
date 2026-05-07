---
artifact-class: feature-ledger
generated-by: hand-authored (wave-003 / lane-a; flipped wave-017 / lane-c)
status: green
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-003 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-017 / lane-c
    note: "RED → GREEN. manualHaltOverride primitive (~80 LOC) + 6 RED-cleared scenarios under tests/unit/F-027-manual-halt-override.test.ts. Scope: operator-side halt entry-point with injected consent-gate + RunHaltedVerdict shape (shared with halt.ts F-018 first-owner). Pause-schedule + bulk-halt + kill-switch.json file write + F-014 retro emission deferred to caller integration per no-silent-deferrals.md."
feature-id: F-027
short-slug: manual-halt-override
milestone: M3
provenance:
  surfaces:
    - ce:FR-PROACTIVE-001
    - ce:FR-KILL-001
    - kit:rules/dangerous-operations-policy.md
fr-coverage: []
test-files:
  unit:
    - tests/unit/F-027-manual-halt-override.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - "vitest run tests/unit/F-027-manual-halt-override.test.ts"
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-027-manual-halt-override-review.md exists with verdict: ACCEPT.
depends-on: [F-020, F-023]
out-of-scope-notes: |
  Multi-operator quorum on halts (e.g., 2-person rule) is out of scope for v1.
  Per-schedule role-based authorization (only the schedule owner may halt) is v1.5.
  In v1 any operator with filesystem write access to `automations/` may pause/halt.
confidence: high
---

# F-027 — Manual halt override

## Behavior contract

An operator MUST be able to halt cron heartbeats manually without modifying source. Two distinct operations are supported:

1. **Pause schedule** — write `paused: true` (with `paused_at_utc` + `paused_reason`) into `automations/cron-schedules.json` for the target schedule. The scheduler reads this on each tick; paused schedules are skipped (recorded in `cron-fires.jsonl` with `outcome: "paused_skipped"`). Resuming clears `paused: true`.
2. **Halt active run** — independent of pausing the schedule, an operator may write to the engine-wide `kill-switch.json` (per F-020) which propagates within ≤1 cycle to halt any in-flight runs (cron-spawned or otherwise). The cron-fires entry's `outcome` is updated to `halted_by_kill_switch`.

Both operations are observable + recoverable: pause leaves the schedule intact; kill-switch fires the retro per F-014. The dangerous-operations consent gate (per `kit:rules/dangerous-operations-policy.md` §Force Reclaim category) does NOT apply to pause (it's reversible) but DOES apply to bulk-halt (pausing >5 schedules in one operation requires explicit "yes").

## Acceptance scenarios

1. **Given** an active cron schedule + an operator writing `paused: true` to its entry, **When** the next scheduled fire-time arrives, **Then** no run is spawned + `cron-fires.jsonl` contains an entry with `outcome: "paused_skipped"`.
2. **Given** an in-flight run spawned from a heartbeat fire + an operator setting `kill-switch.json: { "halt_run_id": "<id>" }`, **When** the run's next cycle hook checks, **Then** the run halts within ≤1 cycle, transitions through `closing`, fires the retro with `halted_by: kill_switch`, and the cron-fires entry is updated with `outcome: "halted_by_kill_switch"`.
3. **Given** an operator attempting to pause 6 schedules at once, **When** the bulk-pause command is invoked, **Then** the dangerous-operations consent gate fires + the operation does NOT proceed without explicit "yes" + a preview of the 6 schedules is shown.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/cron/manual-pause.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/cron/manual-halt-active-run.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/cron/bulk-pause-consent-gate.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-020 (kill-switch infrastructure for halting active runs), F-023 (scheduler reads pause state per tick)
- **Soft:** F-014 (retro fires on halt), F-018 (halt is one of 9 trigger enum values)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-PROACTIVE-001 | Manual halt + pause operations on cron schedules |
| ce:FR-KILL-001 | Kill-switch propagation into cron-spawned runs |
| kit:rules/dangerous-operations-policy.md | Bulk-halt consent gate |

## Implementation notes

### wave-017 / lane-c — RED → GREEN flip (2026-05-07)

**Scope deviation from ledger §Behavior contract** (intentional, documented per `rules/no-silent-deferrals.md`):

The ledger §Behavior contract specifies TWO distinct operations:

1. **Pause schedule** — write `paused: true` (with `paused_at_utc` + `paused_reason`) into `automations/cron-schedules.json`. Scheduler skips on next tick; `cron-fires.jsonl` records `outcome: "paused_skipped"`.
2. **Halt active run** — write to `kill-switch.json` (per F-020) which propagates within ≤1 cycle to halt in-flight runs.

The wave-017 lane-c brief simplifies to operation (2) only, exposed as a pure async function `manualHaltOverride()` returning the verdict shape shared with F-018/F-020:

- `manualHaltOverride({runId, reason, consentGate})` → `Promise<RunHaltedVerdict>`.
- Awaits the injected `consentGate()` (boolean OR `Promise<boolean>`).
- Returns a `RunHaltedVerdict` with `type: 'RUN_HALTED'`, `trigger: 'manual'`, `reason` verbatim, `run_id` stamped, ISO-8601 `timestamp`.
- Throws an Error containing "consent denied" when consent is false (callers map abort-by-user → exit 0; real errors → exit non-zero).

The substantive guarantees are preserved:

- Verdict shape shared with F-018 (HaltDetector), F-020 (KillSwitch), F-021 (DegradationLadder), F-022 (ToolCallQuota) — single source of truth in `halt.ts`.
- `trigger: 'manual'` (the F-018 sibling reserved for operator halts) honored.
- Reason carried verbatim for `dangerous-operations-policy.md` audit-trail discipline (consent-log.jsonl integration is caller-side).
- Async consent gate awaited (operators may need an async UI confirmation step).

Deferred to caller integration:

- Pause-schedule operation (F-023 HeartbeatScheduler caller wires `automations/cron-schedules.json` write).
- Bulk-halt consent gate (>5 schedules) — caller-side per `dangerous-operations-policy.md` §Bulk Post.
- `kill-switch.json` file write integration (F-020 caller wires).
- F-014 retro-on-manual-halt emission (F-014 caller wires).
- Multi-operator quorum on halts (v1 ledger out-of-scope).
- Per-schedule role-based authorization (v1.5 ledger out-of-scope).

This mirrors F-022 ToolCallQuota + F-018 HaltDetector + F-023 HeartbeatScheduler + F-026 CheckpointManager pure-primitive pattern: primitive function/class + caller wires composition.

### Cross-lane staging-race sighting #19+ (2026-05-07)

`packages/engine-core/src/manual-halt.ts` + barrel re-export update + F-027 GREEN proof artifact landed in commit `a8f5de2` (subject "feat(F-030): GREEN cli-json-output"). The F-030 commit message even claims "Sibling-lane work (F-024/F-025/F-026/F-027/F-138 + engine-core edits) explicitly NOT touched per cross-lane staging-discipline" — the swept-up files contradict that claim. Pre-commit hook swept files from working tree across active lanes. Per `non-negotiable-rules.md` (no destructive git ops; user directive 2026-05-07 "DO NOT use git reset"), no rebase/reset to fix history. Substance preserved (verified by 6/6 tests PASS at GREEN; full suite 225/225 PASS post-flip); credit attribution in commit subject is corrupted. Per `verification-protocol.md` Rule 1 (FETCH BEFORE CITE), the file's actual provenance is documented here in the ledger Implementation notes — the authoritative record beats the commit subject for archaeology.

### Test-file path

- `tests/unit/F-027-manual-halt-override.test.ts` (~135 LOC, 6 scenarios across one `describe` block: consent=true returns RUN_HALTED with trigger=manual, consent=false throws abort error, runId stamped on verdict, reason carried through, async consent awaited, ISO-8601 timestamp captured at fire time).

### Source path

- `packages/engine-core/src/manual-halt.ts` (~80 LOC, exports `manualHaltOverride` function + `ManualHaltOptions` interface; imports `RunHaltedVerdict` type from `halt.ts` per wave-011/lane-a "shared types live with FIRST owner" rule).

### Proof artifacts

- `docs/09-examples-proof/F-027/red-test-output.txt` (6/6 fail at RED; `manualHaltOverride is not a function`).
- `docs/09-examples-proof/F-027/green-test-output.txt` (6/6 PASS at GREEN, verbose reporter output).
