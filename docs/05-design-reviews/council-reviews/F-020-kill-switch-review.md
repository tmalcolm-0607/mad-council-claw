---
artifact-class: council-review
feature-id: F-020
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-013 / lane-d
---

# F-020 kill-switch — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 92 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 75 |
| architect-lens | Architect | APPROVE | 88 |

Median confidence: 88

## Implementation reviewed

- `packages/engine-core/src/killswitch.ts` — 151 LOC; `defaultKillFileExists()` lazy fs-existsSync wrapper, `KillSwitch` class with constructor (4 injectable params), `isTriggered()` method, `checkOrThrow()` method that throws Error decorated with F-018 `RunHaltedVerdict` (trigger=`manual`). Imports `RunHaltedVerdict` from `./halt.js` per the wave-011/lane-a engine-core split.
- `tests/unit/F-020-kill-switch.test.ts` — 11 acceptance scenarios; all PASS at review time (11/11 PASS in 9ms).
- Commit history per ledger status-history: F-020 RED at wave-002 / lane-b (initial ledger); F-020 GREEN at wave-010 / lane-b (RED test stub authored — 11 scenarios per wave-5 retro proposal; GREEN impl appended ~175 LOC F-020 region to `index.ts`); engine-core split (wave-011/lane-a) carved `killswitch.ts` out of `index.ts` with no behavior change.

## Advocate lens

**Verdict: APPROVE (confidence 92)**

- Implementation is minimal and correct per `minimum-change.md`: 151 LOC delivers the full kill-switch primitive with FOUR injectable seams (kill-file path, env var name, file-exists function, env Record) — every external surface is mockable for tests. Zero hidden side effects; pure read-time propagation per the F-020 ledger contract.
- All 11 acceptance scenarios PASS: scenarios 1, 2, 3 verify the three ledger acceptance contracts (mid-run env mutation observed on next call; existence-check on absent file = not triggered; checkOrThrow no-op when not triggered). The 8 extended scenarios cover MAD_KILL=`'1'` and `'true'` truthy gate, custom envVarName, file-existence triggering, both-sources-tripped reason composition, error.verdict shape, env-mutation-after-construction, file-mutation-after-construction, and idempotency under repeated reads.
- Verdict-shape reuse: `trigger='manual'` is the F-018 sibling trigger reserved for operator/kill-switch invocations. The thrown `Error` is decorated with a `verdict: RunHaltedVerdict` property — single uniform halt-reporting surface across F-018 (failure-pattern), F-020 (kill-switch), F-021 (degradation), F-022 (tool-quota). Callers downstream of `checkOrThrow()` can pattern-match on `error.verdict.trigger` to route to the right F-014 retro outcome.
- Read-time propagation per the ledger: every `isTriggered()` call re-reads the env + FS sources. No internal state mutation. A kill triggered AFTER engine boot is observed on the NEXT call (acceptance scenario 1's mid-run-halt). No need for the engine to subscribe to file-change events; the cycle-start hook re-evaluates on every iteration.
- Surface trace per ledger: `ce:FR-KILL-001` (read-time-propagating kill-switch JSON) + `kit:rules/non-negotiable-rules.md` ("MUST NOT skip user-requested halt" discipline). The ledger explicitly carries this responsibility — F-020 is the in-memory primitive that the engine's cycle-start hook calls; persistence + JSON parsing is F-008's path-resolution + F-001's cycle-integration step.

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 75)**

- F-020 lands the in-memory primitive only. Out-of-scope per the ledger §out-of-scope-notes: JSON schema parsing of `kill-switch.json` (the brief simplified to existence-check; the ledger's full JSON schema with `reason`/`set_at_utc`/`set_by` stays out of scope here), F-001 cycle-start hook integration (engine bootstrap calls `checkOrThrow()` before every model + tool call), F-008 storage layout for resolving the kill-switch file path, F-014 retro consumer wiring, F-015 audit-log entry for each kill-switch read result. Acceptable for v1; the boundary is in place. Surfaced honestly per `no-silent-deferrals.md`.
- **Brief simplification vs ledger contract divergence**: the wave-010/lane-b brief simplified the kill-switch surface to existence-check (file-or-env). The F-020 ledger acceptance scenario 2 says "halt at boot WITH `halted_by: 'kill_switch_at_boot'`" — but the impl emits `trigger='manual'` (the F-018 sibling trigger), not `'kill_switch_at_boot'`. The reconciliation: `'kill_switch_at_boot'` is a logical halt classification, not a `HaltTrigger` enum value; the routing to F-014's retro outcome `halted_by_kill_switch` is the responsibility of the engine-cycle integration step (which catches the throw and surfaces the appropriate retro outcome). A reader could mistake "F-020 LOCKED" for "boot-halt path implemented end-to-end" — surfaced honestly here; the engine-cycle integration is the materialization path.
- The `defaultKillFileExists` swallows ALL errors and returns false (lines 36-44). This is fail-safe behavior per the ledger ("missing file is NOT an error" + read-time-propagation), but it ALSO masks permission errors, broken filesystems, or network-mount issues that an operator might want to know about. A subtle attacker could flip the kill-file's permissions to make it appear "missing" while the file is in fact present. The env-var override (`MAD_KILL=1`) is the belt-and-braces path — both surfaces are checked independently. Acceptable for v1 single-machine trust model; documented in this review for the multi-tenant adversarial scenario.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `packages/engine-core/src/killswitch.ts` lines 1-151 and `tests/unit/F-020-kill-switch.test.ts` directly; the implementation matches the contract; the lazy `require('node:fs')` (line 39) is a deliberate CJS-style require so injected stubs in tests never trigger fs load. The eslint-disable-next-line comment is scoped to that specific line. Architecturally clean.

## Architect lens

**Verdict: APPROVE (confidence 88)**

- File-split posture: `killswitch.ts` lives in `packages/engine-core/src/` per wave-011/lane-a engine-core split. Module boundary is clean — `killswitch.ts` imports `RunHaltedVerdict` from `./halt.js` (line 21); single direction; no cyclic dep. F-020 depends on F-018's verdict shape, not vice versa. The wave-011 split made this explicit.
- Public API surface (`KillSwitch` class with 2 public methods + 4 constructor seams): minimal and predictable. `isTriggered()` is read-only (idempotent across reads); `checkOrThrow()` is the throwing variant. The two-method shape lets callers either probe-without-throwing (for diagnostic logging) or unconditional-check (for cycle-start hooks).
- Error decoration pattern: `const err = new Error(reason) as Error & { verdict: RunHaltedVerdict }; err.verdict = verdict; throw err;` (lines 147-149). Standard JavaScript-error-with-extra-property pattern. Catchers can pattern-match on `error.verdict?.trigger === 'manual'` to identify kill-switch halts vs other Error throws. The Error message is the verdict's reason — operator-friendly stack traces.
- Reason-composition logic: when BOTH env var and file are tripped, the reason includes both ("env MAD_KILL=1 AND file /path/to/kill-switch.json exists"); single-source tripped, reason names the source (lines 128-138). Precise audit anchor for the F-014 retro consumer.
- Hard deps per ledger: F-001 (cycle hook for read-time check), F-008 (storage path for `kill-switch.json`), F-014 (retro consumes trigger evidence). Soft deps on F-015 + F-018. The current impl has compile-time dep on F-018 (`RunHaltedVerdict` import) and ZERO compile-time deps on F-001/F-008/F-014 — the boundary is in place. F-001/F-008/F-014 integrations materialize at the call-site (engine-cycle integration step). This is forward-compatible.
- The default `KillSwitch` instance shape (no args; consults `process.env.MAD_KILL` and treats null kill-file path as "no file check configured"): simplest-possible operator UX. An operator who has set `MAD_KILL=1` in their shell can construct `new KillSwitch()` with zero config and the kill takes effect on the next `checkOrThrow()`. Architecturally clean.

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | F-001 cycle-start integration follow-on: `checkOrThrow()` is the boundary primitive but no engine-cycle code calls it before every model + tool call yet. The integration is the engine-bootstrap (F-001) step. | Accept; ledger §out-of-scope explicit; backlog item: "kill-switch-cycle-integration" F-NNN follow-on. |
| F2 | MINOR | F-008 storage-path resolution follow-on: kill-file path is caller-supplied today; F-008 will resolve `userData/mad-council-claw/kill-switch.json` via the storage layout. | Accept; ledger §out-of-scope explicit; F-008 integration is the materialization path. |
| F3 | MINOR | F-014 retro-consumer wiring follow-on: F-020 throws Error+verdict with trigger=`manual`; F-014 routing to `halted_by_kill_switch` retro outcome happens at engine-cycle catch site, not inside F-020. | Accept; ledger §out-of-scope explicit; engine-cycle integration owns the routing. |
| F4 | MINOR | JSON schema parsing of `kill-switch.json` (`reason`/`set_at_utc`/`set_by` fields) deferred per brief simplification. Existence-check is the v1 surface; full-JSON-parse is the future extension. | Accept; ledger §out-of-scope explicit; non-breaking extension when added. |
| F5 | MINOR | `defaultKillFileExists` swallows ALL errors as "not exists" — a permissions error or broken FS appears as "kill-file missing." Acceptable for v1 single-machine trust model; multi-tenant adversarial scenarios would prefer a strict-error mode. | Accept; backlog item: a strict-error mode for adversarial multi-tenant deployments. |
| F6 | PRAISE | FOUR injectable constructor seams (kill-file path, envVarName, fileExistsFn, env Record) make the full state matrix testable without touching real fs/env. Architecturally clean. | Keep. |
| F7 | PRAISE | Error-with-verdict decoration pattern. Standard JS shape; pattern-matchable downstream; verdict carries the F-018 trigger taxonomy. Single uniform halt-reporting surface across the governance triad. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 88).

F-020 minimal-contract is implemented correctly; all 11 acceptance scenarios pass per the recorded green-test-output proof and re-verified at review time; no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-020 ledger frontmatter (`LOCKED if GREEN AND reviews/F-020-kill-switch-review.md exists with verdict: ACCEPT`).

The MINOR findings are honest scope-narrowing notes per `no-silent-deferrals.md` — they are surfaced in this review (and in the F-020 ledger §out-of-scope-notes), not silently elided. Future deeper integration work (cycle-start hook; storage-path resolution; retro consumer wiring; JSON schema parsing; strict-error mode) is scoped to future F-NNNs, not a re-scoping of F-020's contract.

F-020 transitions GREEN → LOCKED.

## Cross-references

- Ledger: `docs/03-feature-catalog/M2-governance-triad/F-020-kill-switch.md`
- Source: `packages/engine-core/src/killswitch.ts` (split from `index.ts` in wave-011/lane-a)
- Tests: `tests/unit/F-020-kill-switch.test.ts` (11/11 PASS)
- GREEN proof: per ledger §Implementation notes (wave-010 / lane-b GREEN flip)
- GREEN transition: ledger status-history wave-010 / lane-b
- Engine-core split: wave-011 / lane-a (no behavior change; `killswitch.ts` carved out)
- Review verdict envelope: per `docs/05-design-reviews/README.md`
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle
- Precedent: `F-001-engine-bootstrap-loop-review.md` (wave-011 / lane-b); F-002/F-006/F-008 reviews (wave-012 / lane-d)
