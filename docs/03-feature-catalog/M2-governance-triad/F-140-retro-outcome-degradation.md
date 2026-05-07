---
artifact-class: feature-ledger
generated-by: hand-authored (wave-019 / lane-b)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-019 / lane-b
    note: "Initial creation. Behavior contract + 4 acceptance scenarios drafted. Promoted from wave-016/lane-d Copilot CLI design review m-1 (Opus Minor; gpt-5.5 didn't flag separately): RetroOutcome lacks halted_by_degradation. F-021 DegradationLadder emits a halt with trigger='degrade_escalate' (the 14th HaltTrigger value, added in wave-012/lane-a) but no matching RetroOutcome enum value — degradation halts are unreportable via F-014 closeSession() because the Likert validation rejects the halted-by carve-out (which requires the outcome to start with halted_by_*). Lane B authors RED test scaffold + GREEN impl in same micro-session per the wave-5 retro proposal validated by F-138's pattern. Owner milestone is M2 because the new RetroOutcome enum value extends the F-014 RetroOutcome union which lives at packages/engine-core/src/retro.ts (F-014 owner); the helper that surfaces the halted-by-degradation closeSession path lives at packages/engine-core/src/retro-degradation.ts and reuses retro.ts's RetroSignal + closeSession + RetroMissingError without modifying retro.ts beyond the additive enum value."
feature-id: F-140
short-slug: retro-outcome-degradation
milestone: M2
provenance:
  surfaces:
    - ce:FR-CORE-005
    - cp:src/engine/retro
    - kit:council-retro-skill
fr-coverage: []
test-files:
  unit:
    - tests/unit/F-140-retro-outcome-degradation.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - unit
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-140-retro-outcome-degradation-review.md exists with verdict: ACCEPT.
depends-on: [F-014, F-018, F-021]
out-of-scope-notes: |
  Per `rules/no-silent-deferrals.md`, the v1 surface is intentionally narrow:

  - **Persistence to runs/<run_id>/retro.json** — F-008 (storage layout) owns
    the filesystem write. F-140 lands the in-memory enum extension + a small
    helper that constructs a degradation-halt RetroSignal from a halt verdict
    + caller-supplied prose. The atomic-rename write happens in a future
    F-008 + F-138 integration step.

  - **Audit-log entry for degradation halts** (`appendAuditEntry({action:'cycle.halted',
    fields:{trigger:'degrade_escalate', ladder_history:[...]}})`). F-138 already
    audits cycle.halted via the cycle.ts adapter; F-140's closeSessionForDegradation
    helper does NOT call appendAuditEntry. The trigger_evidence_sha256 plumbing
    that links the retro to the audit entry's SHA-256 chain head is the
    caller's responsibility (same shape as F-018 halted-by-failure-pattern;
    same shape as F-020 halted-by-kill-switch). F-138 cycle.ts will provide
    the SHA when it composes the helper in a future iteration.

  - **DegradationLadder.getState() history snapshot in retro prose**. The
    F-021 ladder maintains an append-only `history: DegradationTransition[]`
    array (rung-at-time-of-transition + ISO-8601 timestamp + trigger). The
    F-140 helper surfaces an OPTIONAL hook to render the history into the
    retro's `meta_observations` field; v1 ships the helper signature accepting
    an optional `historyRender: (history: DegradationTransition[]) => string`
    callback. Production rendering (e.g. multi-line markdown table) belongs
    to a future M11 retro-introspection feature.

  - **ALAS-compatible learning-hub posting** — same deferral as F-014's
    out-of-scope-notes; M11 (F-088..F-092 soul/introspect/replay) owns the
    learning-hub integration.

  - **Per-rung outcome variants** (e.g. halted_by_skill_fallback,
    halted_by_model_fallback). F-021's escalation ladder has 5 non-terminal
    rungs (skill-fallback, model-fallback, reduced-tool-set, headless) but
    only the terminal `halt` rung emits a halt verdict. Adding per-rung
    variants would require modifying the F-021 ladder to emit halts mid-
    escalation — that is not the F-021 contract. F-140 v1 adds ONE new
    RetroOutcome value (`halted_by_degradation`) for the terminal-rung
    halt; per-rung diagnostics belong in `meta_observations` prose, not
    in the enum.

  - **`halted_by_circuit_breaker`** — F-021's circuit-breaker subsystem
    (per-resource open/half-open/closed) is itself deferred per F-021's
    out-of-scope-notes. When that ships, a future feature may add
    `halted_by_circuit_breaker` as a sibling RetroOutcome value; F-140
    does NOT pre-add the enum value.

  These deferrals are honest scope-narrowing per `no-silent-deferrals.md`;
  every primitive F-140 produces is the smallest unit that lets F-021
  degradation halts close the run via F-014's mandatory close-transition.

confidence: high
---

# F-140 — Retro outcome degradation

## Behavior contract

The `RetroOutcome` discriminated union (F-014 owner) gains a 5th value: `halted_by_degradation`. The F-014 `closeSession` validation accepts the new value as a halted-by carve-out (requires `trigger_evidence_sha256` 64-hex). A new helper at `packages/engine-core/src/retro-degradation.ts` constructs a degradation-halt RetroSignal from a F-021 `RunHaltedVerdict` (trigger=`degrade_escalate`) + caller-supplied 5-axis Likert + 7 pattern-prose fields + audit chain head, returning the validated retro object the caller passes to `closeSession`. Resolves wave-016/lane-d F21/m-1 (Opus single-model Minor): degradation halts are now reportable via F-014's mandatory close-transition.

## Acceptance scenarios

1. **Given** a F-021 DegradationLadder that has escalated through all rungs and emitted a `RunHaltedVerdict` with `trigger='degrade_escalate'`, **When** the caller invokes `buildDegradationRetro(verdict, fields, auditChainHead)` with valid 5-axis Likert + 7 pattern fields + a 64-hex audit chain head, **Then** the returned `RetroSignal` carries `outcome='halted_by_degradation'` + `trigger_evidence_sha256=<auditChainHead>` + the caller-supplied Likert scores + pattern fields, and `closeSession(retro)` returns `{ok:true}` (the F-014 boundary contract is satisfied).
2. **Given** the same scenario as #1 but with the audit chain head set to a 60-character hex string (3-char-too-short), **When** `closeSession(retro)` is called, **Then** it throws `RetroMissingError` with `missingFields` containing `'trigger_evidence_sha256'` (F-014's halted-by carve-out validation rejects malformed SHA-256 lengths).
3. **Given** a `RunHaltedVerdict` with `trigger='consecutive_failures_3'` (NOT degrade_escalate), **When** `buildDegradationRetro` is called, **Then** it throws `Error` with message containing `'expected trigger=degrade_escalate'` (the helper rejects mis-routed halt verdicts at the boundary, preventing the wrong RetroOutcome from being used).
4. **Given** a `buildDegradationRetro` call with a F-021 ladder history snapshot supplied via the optional `historyRender` callback, **When** the helper runs, **Then** the returned `RetroSignal.meta_observations` field contains the rendered history string verbatim (caller-controlled rendering; v1 just preserves the string).
5. **Given** a `buildDegradationRetro` call WITHOUT the optional `historyRender` callback, **When** the helper runs, **Then** the returned `RetroSignal.meta_observations` field is the caller-supplied verbatim `meta_observations` field from `fields` (no auto-injection, per the orchestrator-identity rule "compose; do not re-implement").
6. **Given** the `RetroOutcome` union extension, **When** TypeScript compiles, **Then** the F-014 `closeSession` switch over `outcome` continues to accept the 5 values (`completed | halted_by_kill_switch | halted_by_failure_pattern | halted_by_tool_quota | halted_by_degradation`) without unhandled-case warnings.

## Red→green wire-up

| Test file | Project | State | Verifies |
|---|---|---|---|
| `tests/unit/F-140-retro-outcome-degradation.test.ts` | unit | RED at lane start; GREEN after impl lands | scenarios 1, 2, 3, 4, 5, 6 |

## Dependencies

- **Hard:**
  - F-014 (pre-close-retro-signal) — owns RetroOutcome union + closeSession + RetroMissingError; F-140 extends the union with a 5th value and authors the validated-retro builder
  - F-018 (failure-pattern-halt) — owns RunHaltedVerdict shape + HaltTrigger union; F-140 reads `verdict.trigger` and validates it equals `'degrade_escalate'`
  - F-021 (degradation-fallback) — owns DegradationLadder + the `degrade_escalate` halt verdict that F-140's helper consumes
- **Soft:** F-138 (engine-cycle-orchestrator) — composes the helper in a future iteration when DegradationLadder is wired into cycle.ts; F-008 (storage layout) — atomic-write of the retro to runs/<run_id>/retro.json; F-015 (hash-chained-audit-log) — supplies the audit chain head used as `trigger_evidence_sha256`

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-CORE-005 | halted-by carve-out retro carries trigger_evidence_sha256 — extended to cover the degrade_escalate trigger |
| cp:src/engine/retro | clawpilot mandatory-retro pattern; per-outcome carve-outs |
| kit:council-retro-skill | 5-axis scoring rubric + halted-by carve-out for degradation-class halts |

## Implementation notes

Wave-019 / Lane B — RED test scaffold + GREEN impl landed in same micro-session per the wave-5 retro proposal validated by F-138's pattern. Cross-lane staging-race avoidance: per user directive 2026-05-07, NO `git reset` (any flavor) for staging-race recovery; explicit `git add <paths>` for each commit; `git status --short` audit before each commit. Push at end of lane authorized for this loop session.

- **Implementation file**: `packages/engine-core/src/retro-degradation.ts` (~75 LOC).
- **Public surface**:
  - `buildDegradationRetro(verdict, fields, auditChainHead, opts?): RetroSignal` — constructs the validated halted-by-degradation retro.
  - `DegradationRetroFields` — caller-supplied 5-axis Likert + 7 pattern-prose fields shape.
  - `DegradationRetroOptions` — `{historyRender?: (history) => string}` optional history-render hook.
- **Retro.ts changes** (F-014 owner; minimal additive):
  - Extend `RetroOutcome` union with `'halted_by_degradation'` (5th value).
  - Extend `HALTED_OUTCOMES` Set with the new value (closeSession's halted-by carve-out triggers on it).
  - Extend the `validOutcomes` Set inside `closeSession` to include the 5th value.
  - The Likert validation, 7 pattern-field validation, and 64-hex SHA validation all stay unchanged — the new value plugs into existing infrastructure.
- **Index.ts barrel addition**: 1 ownership-table comment line + 1 `export * from './retro-degradation.js'` re-export. Disjoint append zone per the wave-011/lane-a convention.
- **Boundary-validation discipline**: `buildDegradationRetro` throws `Error` (NOT RetroMissingError — that's F-014's specific contract) when `verdict.trigger !== 'degrade_escalate'`. This is a defensive boundary that prevents callers from feeding a wrong-shape halt verdict into the helper and getting a misleading `halted_by_degradation` retro for what was actually e.g. a `consecutive_failures_3` halt.
- **Anti-orchestrator-impostor discipline** per `kit:rules/orchestrator-identity.md`: retro-degradation.ts NEVER calls `closeSession`. It returns a validated RetroSignal; the caller (F-138 cycle.ts in a future iteration) calls `closeSession(retro)` to fire the F-014 boundary. The F-014 close-transition stays with F-014.
- **No-invented-constraints discipline**: the helper does NOT auto-fill any field from the verdict (e.g. it does not derive `next_steps` prose from the ladder history). The 7 pattern-prose fields are caller-supplied verbatim. The optional `historyRender` callback is the ONLY hook for ladder-state injection, and it modifies ONLY `meta_observations`.
- **F21 (Opus m-1) status**: marked addressed in the wave-016 review delta tracker once GREEN lands. The single-model demoted-to-CONSIDER finding is now mechanically resolved: the enum gap is closed; the closeSession contract accepts the new value; the helper provides a typed boundary for callers.
