---
artifact-class: physical-proof
generated-by: wave-008 / lane-a
feature-id: F-014
date: 2026-05-06
status: green
---

# F-014 — Physical proof

Third feature transition RED → GREEN in the repo (F-001 wave-005, F-002 wave-006, F-014 this lane). First M2 (governance triad) feature to flip GREEN. This file binds the F-014 ledger's three behavior-contract acceptance scenarios + the halted-by carve-out to actual vitest output, per Goal G27 (full behavior tests + physical proof) and the wiki contribution protocol.

## Acceptance scenarios → test results

| # | Scenario (verbatim from ledger) | Vitest test name | Result |
|---|---|---|---|
| 1 | Given a run that completes naturally (cycle cap reached or explicit terminate), When `closing` fires, Then `runs/<run_id>/retro.json` exists with all 5 axes scored and `outcome: "completed"`. | scenario 1: closeSession with valid retro returns ok and accepts outcome=completed | ✓ PASS |
| 2 | Given a run halted by kill-switch (per F-020), When `closing` fires, Then the retro carries `outcome: "halted_by_kill_switch"` and `trigger_evidence_sha256` matching the kill-switch audit entry. | halted-by carve-out: outcome=halted_by_kill_switch requires trigger_evidence_sha256 | ✓ PASS (rejection path) |
| 2b | (positive variant of scenario 2) Same outcome WITH the SHA-256 evidence pointer present. | halted-by carve-out: halted retro with trigger_evidence_sha256 succeeds | ✓ PASS |
| 3 | Given a buggy implementation that omits the retro emit, When the engine attempts to transition to `closed`, Then the transition rejects with `RETRO_MISSING` and the run stays in `closing` until retro lands. | scenario 2: closeSession with no retro rejects with RETRO_MISSING | ✓ PASS |
| 3a | (extended) Missing one Likert axis (`tsg_alignment`) → RETRO_MISSING with the field name in `.missingFields`. | scenario 3a: closeSession with retro missing one Likert axis rejects | ✓ PASS |
| 3b | (extended) Missing one pattern field (`what_worked`) → RETRO_MISSING with the field name in `.missingFields`. | scenario 3b: closeSession with retro missing one pattern field rejects | ✓ PASS |
| 3c | (extended) Likert axis above 5 → RETRO_MISSING citing the offending axis. | scenario 3c: closeSession with Likert score out of 1-5 range rejects | ✓ PASS |
| 3d | (extended) Likert axis below 1 → RETRO_MISSING. | scenario 3d: closeSession with Likert score below 1 rejects | ✓ PASS |

8/8 PASS, single vitest run, exit 0.

## Scope deviations from ledger (intentional, documented)

The F-014 ledger names per-scenario test files under `tests/integration/governance/` and `tests/unit/governance/` because it co-targets F-008 (storage layout for retro.json). Wave-008 / lane-a's minimal flip implements the **in-memory boundary surface** that F-008 will compose against:

- `closeSession(retro): {ok: true}` — the boundary contract that fails the close transition with `RETRO_MISSING`
- `RetroSignal` interface — the structured shape (5 axes + 7 pattern fields + outcome + optional trigger_evidence_sha256)
- `RetroMissingError` class with `.missingFields` — the rejection contract callers handle

The actual filesystem write to `runs/<run_id>/retro.json` is F-008's job (storage layout). The audit-pipeline integration (write retro entry into the hash-chained audit log) is F-015's job. The halt-source wiring (which audit entry's SHA supplies `trigger_evidence_sha256`) is F-018 / F-020 / F-022's job. Those are tracked as soft / hard deps in the F-014 ledger and explicitly out-of-scope here per `rules/no-silent-deferrals.md`. The `RETRO_MISSING` rejection IS the boundary contract those features will plug into.

This mirrors the F-002 / wave-006 pattern: stamp primitive landed unit-level; storage path deferred to F-008.

## Implementation summary

`packages/engine-core/src/index.ts` — F-001 + F-002 unchanged (~250 LOC); F-014 adds ~180 LOC:

- `RetroOutcome` type — `'completed' | 'halted_by_kill_switch' | 'halted_by_failure_pattern' | 'halted_by_tool_quota'`
- `RetroSignal` interface — 5-axis Likert + 7 pattern fields + outcome + optional trigger_evidence_sha256
- `RetroMissingError` class extending `Error`, with `.missingFields: string[]`
- `LIKERT_AXES` / `PATTERN_FIELDS` / `HALTED_OUTCOMES` const arrays for validation
- `closeSession(retro)` — full validation pipeline:
  - retro is non-null object
  - 5 Likert axes: present, integer, 1..5 inclusive
  - 7 pattern fields: present, non-empty string
  - outcome: present, one of the 4 known values
  - halted-by carve-out: when outcome ∈ halted_by_*, trigger_evidence_sha256 MUST be 64-char lowercase hex

## Toolchain hops landed alongside

None. Wave-005 + wave-006 already landed `pnpm-workspace.yaml` + `@mad-council-claw/engine-core: workspace:*` devDep + `test:unit` script fix. F-014 inherits all three.

## Reproduction

```bash
cd C:/Users/tonym/Repos/mad-council-claw
pnpm install
pnpm exec vitest run tests/unit/F-014-pre-close-retro-signal.test.ts
# Expected: "Test Files 1 passed (1)" + "Tests 8 passed (8)" + exit 0
```

Or for the full M0+M2 unit suite (F-001 + F-002 + F-014 + Lane B's F-015 if landed):

```bash
pnpm test:unit
# Expected: "Test Files 4 passed (4)" + "Tests 18 passed (18)"
```

Captured: `green-test-output.txt`. RED baseline captured BEFORE the flip per the wave-5 retro proposal — see `red-test-output.txt`.

## Confidence

HIGH. All 3 ledger acceptance scenarios + 5 extended scenarios pass with real vitest output. RED baseline captured BEFORE the flip per the wave-5 retro proposal. The `RETRO_MISSING` rejection in scenarios 3 / 3a / 3b / 3c / 3d satisfies ce:FR-CORE-004 (mandatory pre-close retro emit). The halted-by carve-out in scenarios 2 / 2b satisfies ce:FR-CORE-005 (trigger evidence SHA-256 link).

## Soft dependencies still RED / pending

Per the F-014 ledger:
- F-008 (local-storage-layout) — F-014 emits the retro shape in-memory; persistence to `runs/<run_id>/retro.json` is F-008's job
- F-015 (hash-chained-audit-log) — retro entry is also written to the audit log; F-015 owns the chain
- F-018 (failure-pattern-halt) / F-020 (kill-switch) / F-022 (tool-quota) — supply the actual `trigger_evidence_sha256` value when running halts the engine

ALAS-compatible learning-hub posting (downstream consumption of the retro signal) is explicitly deferred to M11 (soul/introspect/replay) per the F-014 ledger out-of-scope-notes — tracked in M19 deferred catalog.

## Coordination note (parallel lane)

Wave-008 / Lane B is in flight on F-015 (hash-chained-audit-log) in the SAME `packages/engine-core/src/index.ts` file. Lane A's F-014 GREEN commit (ba54036) is scoped to the F-014 region only and does NOT include Lane B's uncommitted F-015 impl additions. Lane B's working-tree F-015 impl is preserved post-commit and will land under their own GREEN commit. Per `rules/scope-discipline.md`: every modified file classified, no silent commit of out-of-lane work.

## Scope flag (prompt-vs-ledger naming)

The wave-008 / lane-a prompt named this work `F-003-pre-close-signal-capture`. F-003 in M0 is `repo-scaffolding` (RED, separate ledger). The behavior contract authored by the prompt — `closeSession`, 5-axis Likert, 7 pattern fields, halted-by carve-out — matches the F-014 ledger verbatim. Lane A executed against the existing F-014 ledger rather than silently rewriting F-003's contract per `rules/no-silent-deferrals.md` and `rules/canonical-skill-only.md`. Surfaced for user adjudication in `lane-a-summary.md`.
