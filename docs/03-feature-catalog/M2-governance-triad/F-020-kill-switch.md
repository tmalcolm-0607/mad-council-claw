---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: locked
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-010 / lane-b
    note: "RED test stub authored (11 scenarios) per wave-5 retro proposal; GREEN impl appends ~175 LOC F-020 region to packages/engine-core/src/index.ts. KillSwitch class + defaultKillFileExists helper; checkOrThrow() throws Error decorated with F-018 RunHaltedVerdict (trigger='manual'). 11/11 acceptance scenarios pass. Full unit suite 66/66 across 10 test files. Scope deviation from ledger surface (JSON schema parsing) explicitly surfaced per rules/no-silent-deferrals.md — deferred to engine-cycle integration step."
  - status: locked
    at: 2026-05-07
    by: wave-013 / lane-d
    note: "Post-impl council review at docs/05-design-reviews/council-reviews/F-020-kill-switch-review.md verdict ACCEPT (Verdict consensus: APPROVE; median confidence 88; 0 CRITICAL / 0 MAJOR / 5 MINOR / 2 PRAISE). Source post-wave-011/lane-a engine-core split lives at packages/engine-core/src/killswitch.ts (151 LOC). 11/11 acceptance scenarios continue to PASS unchanged at review time. Per the red-green-rule predicate: LOCKED requires both GREEN AND review file with verdict: ACCEPT. Both conditions verified."
feature-id: F-020
short-slug: kill-switch
milestone: M2
provenance:
  surfaces:
    - ce:FR-KILL-001
    - kit:rules/non-negotiable-rules.md (manual halt)
fr-coverage: []
test-files:
  unit: [tests/unit/F-020-kill-switch.test.ts]
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects: [packages/engine-core]
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-020-kill-switch-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-008, F-014]
out-of-scope-notes: |
  Manual operator verdict (override at `verdicts/manual-<ts>.json` per FR-OVERRIDE-001)
  is a related-but-distinct surface tracked separately in M11 (F-088..F-092). This
  feature is the read-time-propagating JSON kill switch only.

  Wave-010 / lane-b GREEN flip lands the in-memory KillSwitch primitive only.
  Deferred to engine-cycle integration step:
    - JSON schema parsing of kill-switch.json (the brief simplifies to
      existence-check; the ledger's full JSON schema with reason/set_at_utc/
      set_by stays out of scope here).
    - F-001 cycle-start hook integration (engine bootstrap calls
      checkOrThrow() before every model + tool call).
    - F-008 storage layout for resolving the kill-switch file path.
    - F-014 retro consumer wiring (catch the throw, route halted_by_kill_switch).
    - F-015 audit-log entry for each kill-switch read result.
confidence: high
---

# F-020 — Read-time-propagating kill switch

## Behavior contract

A single file `userData/mad-council-claw/kill-switch.json` declares the engine's halt state. Schema: `{halted: boolean, reason?: string, set_at_utc?: string, set_by?: string}`. Every engine cycle reads this file at the START of the cycle (read-time propagation, not snapshot-at-boot). If `halted: true`, the engine skips the cycle's work and transitions immediately to `closing` with `halted_by: "kill_switch"` and `trigger_evidence_sha256` linking to a fresh audit entry that captures the kill-switch state at the instant of read.

## Acceptance scenarios

1. **Given** a running engine and `kill-switch.json` set to `{halted: false}`, **When** an external process writes `{halted: true, reason: "ops review"}` mid-run, **Then** the engine's NEXT cycle observes the halt and transitions to `closing` within that cycle.
2. **Given** `kill-switch.json` set to `{halted: true}` BEFORE engine boot, **When** the engine boots, **Then** it transitions through `open → closing` without ever entering `active`, and the retro records `halted_by: "kill_switch_at_boot"`.
3. **Given** the kill-switch file is missing entirely, **When** the engine reads, **Then** the engine treats this as `{halted: false}` (default open) and continues; missing file is NOT an error.

## Red→green wire-up

| Test file | Project | State | Verifies |
|---|---|---|---|
| `tests/unit/F-020-kill-switch.test.ts` | unit | GREEN | 9 ledger/brief acceptance scenarios + 2 robustness checks (env-truthy gate; read-time propagation across env mutation) |
| (TBD) `tests/integration/kill-switch/mid-run-halt.test.ts` | integration | DEFERRED | scenario 1 (engine-cycle integration step) |
| (TBD) `tests/integration/kill-switch/halt-at-boot.test.ts` | integration | DEFERRED | scenario 2 (engine-cycle integration step) |

## Dependencies

- **Hard:** F-001 (cycle hook for read-time check), F-008 (storage path for kill-switch.json), F-014 (retro consumes trigger evidence)
- **Soft:** F-015 (audit log records every read result), F-018 (halt mechanism shared)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-KILL-001 | Read-time-propagating kill-switch JSON |
| kit:rules/non-negotiable-rules.md | "MUST NOT skip user-requested halt" discipline |

## Implementation notes

Wave-010 / lane-b lands the in-memory `KillSwitch` primitive (~175 LOC F-020 region in `packages/engine-core/src/index.ts`):

- **`defaultKillFileExists(path)`** — lazy `node:fs.existsSync` wrapper that fail-safes to `false` on errors (read-time propagation per ledger).
- **`KillSwitch` class** — constructor takes optional kill-file path, env-var name (default `MAD_KILL`), injectable `fileExistsFn`, injectable `env`. Methods:
  - `isTriggered()` — returns true when env var === `'1'` OR `'true'`, OR kill-file path is configured AND `fileExistsFn(path)` returns true.
  - `checkOrThrow()` — throws `Error` decorated with F-018 `RunHaltedVerdict` (`trigger='manual'`, non-empty `reason` describing which source tripped, ISO-8601 `timestamp`).

Verdict-shape reuse: `trigger='manual'` is the F-018 sibling trigger reserved for operator/kill-switch invocations — same uniform halt-reporting surface across F-018 (failure-pattern), F-020 (kill-switch), F-021 (degradation), F-022 (tool-quota).

Read-time propagation: every `isTriggered()` call re-reads env + FS sources; a kill triggered AFTER engine boot is observed on the NEXT call (per ledger acceptance scenario 1).

11/11 acceptance scenarios pass. Full unit suite at GREEN time: 66/66 across 10 test files (F-001/F-002/F-006/F-008/F-014/F-015/F-016/F-018/F-019/F-020).

Reproduction:

```bash
cd C:/Users/tonym/Repos/mad-council-claw
pnpm install
pnpm exec vitest run tests/unit/F-020-kill-switch.test.ts
# Expected: "Test Files 1 passed (1)" + "Tests 11 passed (11)" + exit 0
```
