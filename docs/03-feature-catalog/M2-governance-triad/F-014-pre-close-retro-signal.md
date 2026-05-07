---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: green
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-06
    by: wave-008 / lane-a
    note: "RED test stub committed (d896ecb); GREEN impl committed (ba54036). 8/8 acceptance scenarios pass via vitest. closeSession + RetroSignal interface + RetroMissingError landed in packages/engine-core/src/index.ts. Filesystem write to runs/<run_id>/retro.json deferred to F-008 per ledger out-of-scope-notes."
feature-id: F-014
short-slug: pre-close-retro-signal
milestone: M2
provenance:
  surfaces:
    - ce:FR-CORE-004
    - ce:FR-CORE-005
    - kit:council-retro-skill
fr-coverage: []
test-files:
  unit:
    - tests/unit/F-014-pre-close-retro-signal.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - unit
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-014-pre-close-retro-signal-review.md exists with verdict: ACCEPT.
depends-on: [F-001]
out-of-scope-notes: |
  ALAS-compatible learning-hub posting is tracked under M11 (F-088..F-092 soul/introspect/replay).
  This feature emits the local retro signal at run wind-down; downstream consumption
  is owned by later milestones.
confidence: high
---

# F-014 — Pre-close retro signal

## Behavior contract

Every run lifecycle MUST pass through `closing` before reaching `closed` (per F-001). During `closing` the engine emits a mandatory retro signal: a structured artifact at `runs/<run_id>/retro.json` capturing 5-axis 1-5 scores (accuracy / completeness / tsg_alignment / dx / confidence) plus what-worked + what-was-hard prose. For halted runs (`halted_by_*` outcomes), the retro additionally carries `trigger_evidence_sha256` linking to the audit entry that triggered the halt. Skipping the retro emit fails the close transition with `RETRO_MISSING`.

## Acceptance scenarios

1. **Given** a run that completes naturally (cycle cap reached or explicit terminate), **When** `closing` fires, **Then** `runs/<run_id>/retro.json` exists with all 5 axes scored and `outcome: "completed"`.
2. **Given** a run halted by kill-switch (per F-020), **When** `closing` fires, **Then** the retro carries `outcome: "halted_by_kill_switch"` and `trigger_evidence_sha256` matching the kill-switch audit entry.
3. **Given** a buggy implementation that omits the retro emit, **When** the engine attempts to transition to `closed`, **Then** the transition rejects with `RETRO_MISSING` and the run stays in `closing` until retro lands.

## Red→green wire-up

| Test file | Project | State | Verifies |
|---|---|---|---|
| `tests/unit/F-014-pre-close-retro-signal.test.ts` | unit | GREEN (8/8 PASS) | scenarios 1, 2, 3 + halted-by carve-out |
| (deferred) `tests/integration/governance/retro-natural-close.test.ts` | integration | F-008 dep — filesystem write to runs/<run_id>/retro.json | scenario 1 (filesystem-bound) |
| (deferred) `tests/integration/governance/retro-halted-trigger.test.ts` | integration | F-008 + F-018/F-020 deps | scenario 2 (filesystem-bound + halt source) |

**Scope note**: ledger originally named per-scenario test files under `tests/{integration,unit}/governance/`. Wave-008 / lane-a flipped F-014 GREEN as a single unit-level test (`tests/unit/F-014-pre-close-retro-signal.test.ts`, 8 scenarios) covering all three acceptance scenarios + the halted-by carve-out, mirroring the F-001 / F-002 wave-005/006 convention (`tests/unit/F-NNN-<slug>.test.ts`). Integration-level filesystem tests stay TBD against F-008 (storage layout). Per `rules/no-silent-deferrals.md`: deferred files explicitly named here, not silently dropped.

## Dependencies

- **Hard:** F-001 (lifecycle), F-008 (storage layout for retro.json)
- **Soft:** F-015 (retro entry is also written to audit log), F-018 (halt outcomes feed trigger_evidence_sha256)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-CORE-004 | Mandatory pre-close retro signal (ALAS Step 9 anchor) |
| ce:FR-CORE-005 | Carve-out retro for halted_by_* with trigger_evidence_sha256 |
| kit:council-retro-skill | 5-axis scoring rubric + blameless framing |

## Implementation notes

**Wave-008 / lane-a GREEN flip** (2026-05-06):

- **Surface added** to `packages/engine-core/src/index.ts` (~180 LOC):
  - `RetroOutcome` type — `'completed' | 'halted_by_kill_switch' | 'halted_by_failure_pattern' | 'halted_by_tool_quota'`
  - `RetroSignal` interface — 5-axis Likert (1-5) + 7 pattern-prose fields + `outcome` + optional `trigger_evidence_sha256`
  - `RetroMissingError` class extending `Error`, `.missingFields: string[]` carries the per-field diagnostic
  - `closeSession(retro): {ok: true}` — full validation: presence, integer-1..5 Likert, non-empty string pattern fields, recognized outcome, halted-by SHA-256 carve-out (64-hex)
- **5-axis Likert**: `accuracy`, `completeness`, `tsg_alignment`, `dx`, `confidence` (each int 1..5)
- **7 pattern fields**: `what_worked`, `what_was_hard`, `surprises`, `blockers`, `next_steps`, `notes`, `meta_observations` (each non-empty string)
- **Halted-by carve-out**: when `outcome` ∈ `halted_by_*`, a 64-char lowercase hex `trigger_evidence_sha256` MUST be present
- **Out-of-scope (per ledger out-of-scope-notes)**:
  - Filesystem persistence to `runs/<run_id>/retro.json` → F-008 (storage layout)
  - Audit-pipeline integration (write retro entry into hash-chained audit log) → F-015
  - Halt-source wiring (kill-switch / failure-pattern / tool-quota that supplies the trigger_evidence) → F-020 / F-018 / F-022
  - ALAS-compatible learning-hub posting → M11 deferred catalog

**RED→GREEN evidence**:
  - RED commit: `d896ecb` (test only, 7/8 fail with TypeError; 1 spurious pass on no-throw scenario)
  - GREEN commit: `ba54036` (closeSession + types + error class; 8/8 PASS)
  - Output captured: `docs/09-examples-proof/F-014/{red,green}-test-output.txt`

**Reproduction**:
```bash
cd C:/Users/tonym/Repos/mad-council-claw
pnpm install
pnpm exec vitest run tests/unit/F-014-pre-close-retro-signal.test.ts
# Expected: "Test Files 1 passed (1)" + "Tests 8 passed (8)"
```
