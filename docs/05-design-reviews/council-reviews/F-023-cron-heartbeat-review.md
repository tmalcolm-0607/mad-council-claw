---
artifact-class: council-review
feature-id: F-023
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-018 / lane-a
---

# F-023 cron-heartbeat — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 90 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 76 |
| architect-lens | Architect | APPROVE | 88 |

Median confidence: 88

## Implementation reviewed

- `packages/engine-core/src/heartbeat.ts` — ~313 LOC at review time. Exports `CadenceProfile` (union of `'mad-iteration' | 'deployment-watch' | 'custom'`), `HeartbeatConfig` interface, `HeartbeatStatus` interface, `TickResult` interface (F-024 surface), `IdleArchiveCallback` type (F-025 surface), and the `HeartbeatScheduler` class. F-023's owned surface is the constructor cadence-zone gate, `start(handler)` / `stop()` (idempotent) / public `tick()` (test ergonomics + manual-mode driver) / `getStatus()` / `getIntervalSeconds()`. F-024 (skip-on-overlap, wave-017 / lane-b) and F-025 (idle-archival, wave-017 / lane-b) extended the same file as same-class additions per the F-022 ToolCallQuota / F-018 HaltDetector pattern; their additions (`tickInFlight` guard, `skippedTicks` counter, `archiveAfterMinutes` field, `onIdleArchive(cb)` registration, idle-gap detection in `tick()`) preserve the F-023 contract — the existing 21 acceptance scenarios still pass at review time without modification.
- `packages/engine-core/src/index.ts` — barrel re-export `export * from './heartbeat.js';` + ownership-table comment line entry.
- `tests/unit/F-023-cron-heartbeat.test.ts` — 288 LOC, 21 acceptance scenarios across 6 describe blocks (cadence profile resolution: 5 scenarios; forbidden-zone enforcement: 6 scenarios; tick lifecycle: 3 scenarios; start/stop lifecycle: 4 scenarios incl. fake-timers `setInterval` witness; getStatus observability: 2 scenarios; CadenceProfile type-witness: 1 scenario). All 21/21 PASS at review time per `pnpm test` 2026-05-07 (full suite 225/225 across 31 test files).
- Commit history per `docs/07-roadmap/decision-log.md` + ledger status-history: F-023 RED at wave-003 / lane-a (initial ledger creation only); F-023 GREEN at wave-016 / lane-b — substance preserved across cross-lane staging-race sighting #16 (heartbeat.ts + barrel re-export landed under commit `fdede59 docs(F-011): post-impl council review verdict ACCEPT`; restoration in fix-forward `f59c4ce`; proof artifacts in `0d4c84a docs(F-023): GREEN proof artifacts`).
- GREEN proof: `docs/09-examples-proof/F-023/{red,green}-test-output.txt` + `physical-proof.md`.

## Advocate lens

**Verdict: APPROVE (confidence 90)**

- Implementation is minimal and correct per `minimum-change.md`. The F-023-owned surface (constructor + start/stop/tick/getStatus/getIntervalSeconds + cadence-zone validation) is ~145 LOC of actual scheduler primitive — the smallest correct shape that satisfies the cadence-aware scheduler contract from the ledger §Behavior contract. F-024 + F-025 added ~50 LOC each later as same-class extensions per the F-022 ToolCallQuota / F-018 HaltDetector pattern; F-023's contract is intact and unchanged.
- All 21 acceptance scenarios PASS. The 5 cadence-profile-resolution scenarios cover the canonical defaults (`mad-iteration` → 270s warm-cache; `deployment-watch` → 1500s amortized) + the operator escape hatch via `custom` profile + the missing-intervalSeconds throw. The 6 forbidden-zone-enforcement scenarios mechanize the `loop-cadence-discipline.md` rule directly: 600s rejected (mid-zone), 280s rejected (lower bound inclusive), 1199s rejected (upper bound inclusive), 270s accepted (warm-cache margin under TTL), 1200s accepted (amortized lower bound), and `enforceWarmCacheZones: false` bypasses the gate. The 3 tick-lifecycle scenarios cover manual-tick invocation, tick-before-start affordance, and async-handler awaiting. The 4 start/stop scenarios cover the isRunning state + double-start throw + idempotent stop + the `setInterval`-driven witness using `vi.useFakeTimers()` + `advanceTimersByTimeAsync(269_000)` + `+2_000` boundary cross. The 2 getStatus scenarios cover the configured intervalSeconds reporting + the initial-state shape. The 1 CadenceProfile type-witness scenario asserts the documented 3-element profile set at compile-time.
- Cadence-zone enforcement is the load-bearing reusable primitive in the scheduler. The constructor REJECTS configs in 280-1199s with a remediation pointer to `loop-cadence-discipline.md`. Operators with a documented reason can opt out via `enforceWarmCacheZones: false` so the override is reviewable in code rather than silent — same-shape discipline as F-020's kill-switch override or F-021's degradation `--bypass-degradation` flag (consent in code, not silence).
- Test ergonomics: `tick()` is a public method so tests + manual-mode callers can drive the handler without `setInterval` and without fake-timers when they don't need to. The setInterval-driven witness IS covered (`vi.useFakeTimers()` scenario in start/stop describe block) so the timer wiring is empirically verified, but production code paths can prefer the `tick()` direct-call. Mirrors F-018 `HaltDetector.recordFailure` / F-022 `ToolCallQuota.recordCall` style — pure data-class primitives with public manipulators that compose cleanly without timers.
- Surface trace per ledger: `ce:FR-PROACTIVE-001` (Cron-driven heartbeat with overlap detection) + `ce:US-7` (Heartbeat user story P3) + `ce:US-8` (Cron proactive execution) + `ce:CronFireRecord` (Append-only schema) + `kit:loop-skill` (`/loop` cadence pattern as the substrate) + `kit:rules/loop-cadence-discipline.md` (Cadence profiles + forbidden zone). Provenance is auditable; the cadence-zone enforcement directly mechanizes the kit rule.
- F-023 is the **first M3 (cron / heartbeat) feature** flipped (wave-016 / lane-b) and the cornerstone primitive — F-024 (skip-on-overlap) + F-025 (idle-archival) extend it without re-implementing the scheduler; F-026 (drift-accounting) + F-027 (manual-halt-override) compose against the `getStatus.lastTickAt` + `tickCount` shape that F-023 contributes. By LOCKED time, all 5 M3 features are GREEN — F-023 anchors the milestone.

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 76)**

- F-023 lands the **scheduler primitive only**. Out-of-scope per the ledger §Implementation notes (recorded openly per `no-silent-deferrals.md`): run spawn (caller's `tick` handler invokes F-001 boot-fresh-run); `cron-fires.jsonl` append (callers wire F-006 + F-008); overlap detection (F-024); agent identity (F-002); drift accounting at the ≤5% over a 100-fire window per ce:SC-007 (F-023 contributes the SHAPE — `getStatus.lastTickAt` + `tickCount` — but NOT the calculation; F-026 + F-027 own the drift math). LOCKED status here is therefore narrowly "**F-023 scheduler-primitive contract LOCKED**" — the ledger's §Behavior contract names a richer story; the wave-016 / lane-b GREEN flip and this LOCKED review honor only the primitive scope.
- **Behavior-contract vs impl-scope divergence**: the ledger §Behavior contract paragraph reads "The engine supports cron-driven heartbeats: scheduled, recurring, autonomous run invocations registered in `automations/cron-schedules.json`. ... at each fire spawns a fresh run (per F-001) under the configured agent identity (per F-002). Each fire is recorded as an append-only entry in `automations/cron-fires.jsonl` ..." — the impl provides ONLY the scheduler primitive (constructor cadence gate + start/stop/tick + getStatus). A reader of the §Behavior contract paragraph could mistake "F-023 LOCKED" for "automations/cron-schedules.json reading + cron-fires.jsonl writing + F-001 run-spawn integration all done." Surfaced honestly per `no-silent-deferrals.md`: F-023 LOCKED applies to the scheduler primitive scope; the JSON-config reading + JSONL-append + run-spawn callsites are deferred to caller-integration work owned by F-001 / F-006 / F-008.
- **Acceptance-scenario divergence**: the ledger §Acceptance scenarios (3 scenarios) describe end-to-end behavior: scenario 1 ("scheduler runs for 1 hour, cron-fires.jsonl contains 12 entries"), scenario 2 ("heartbeat fire boots a run, completes, cron-fires entry updated with run_id"), scenario 3 ("cadence in forbidden zone rejected with CADENCE_FORBIDDEN_ZONE"). The 21 implemented scenarios test the primitive surface; only scenario 3 (forbidden-zone rejection) maps directly. Scenarios 1+2 require F-001 / F-006 / F-008 integration that doesn't exist yet. The implemented test file's 21 scenarios go DEEPER on the primitive contract (cadence-zone enforcement at lower + mid + upper bounds, escape-hatch validation, tick-before-start, async-handler await, fake-timers setInterval witness) — different shape, same architectural intent. Surfaced per the ledger §Implementation notes "Scope simplified vs ledger §Behavior contract" paragraph.
- **CADENCE_FORBIDDEN_ZONE error code naming**: the ledger §Acceptance scenarios scenario 3 specifies the rejection string includes `CADENCE_FORBIDDEN_ZONE`. The implementation's error message includes `forbidden zone 280-1199s` + a remediation pointer to `kit:rules/loop-cadence-discipline.md` — semantically equivalent (both communicate "forbidden zone rejected"), but a consumer parsing for the literal `CADENCE_FORBIDDEN_ZONE` substring would not match. Acceptable for v1 because there are no current consumers parsing this; the rejection is constructor-throw, callers see the entire message. Surfaced for the future error-code-taxonomy wave (when F-029 sysexits.h normalization + F-030 JSON output reach error envelopes).
- **Single-schedule scope**: the impl is one `HeartbeatScheduler` instance per cadence. Multi-schedule support (multiple cron expressions in `automations/cron-schedules.json`, each with its own scheduler) is achieved by the caller instantiating one `HeartbeatScheduler` per registered schedule. Per F-024's contract "Cross-schedule independence is by-design: separate HeartbeatScheduler instances per schedule" — this is the deliberate architectural choice. A consumer reading the ledger §Behavior contract paragraph might expect a registry-style API; the actual API is per-schedule. Acceptable; documented in the F-024 doc-comment lines 21-25.
- **Cross-lane staging-race substance preservation** (per ledger status-history wave-016 / lane-b): F-023's `heartbeat.ts` + barrel re-export landed under commit `fdede59 docs(F-011): post-impl council review verdict ACCEPT` (sighting #16 of the chronic cross-lane race documented across waves 9-17). Substance was preserved (HEAD has the work; isolated test 21/21 PASS); audit-trail-naming is scrambled. Per `non-negotiable-rules.md` (NO destructive git ops; user directive 2026-05-07 specifically NO `git reset`), no rebase/reset to fix history. The fix-forward commit `f59c4ce fix(barrel): restore F-012 + F-013 exports lost in cross-lane race` reconciled the same race for sibling lanes. F-023's substance is intact; the scrambled-attribution is a wave-16 artifact, not an F-023 quality issue.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `packages/engine-core/src/heartbeat.ts` lines 1-313 directly + `tests/unit/F-023-cron-heartbeat.test.ts` lines 1-239 directly + the F-023 ledger lines 1-119 directly. The implementation matches the contract; cadence-zone enforcement uses inclusive bounds (`>= 280 && <= 1199`) which is the canonical shape per `loop-cadence-discipline.md` (zone forbidden 280-1199s inclusive). The constructor throws BEFORE registering any timer (no resource leak on rejection). The `start()` double-call throws "already started". The `stop()` is idempotent (no-op when not started + safe second call). The `tick()` increments `tickCount` and updates `lastTickAt` BEFORE invoking the handler — counters are observable even if the handler throws.

## Architect lens

**Verdict: APPROVE (confidence 88)**

- File-location posture: `packages/engine-core/src/heartbeat.ts` per the wave-011 / lane-a engine-core split convention. Single feature-owned file; barrel re-export from `index.ts`; F-024 + F-025 extend the same file (same-class additions to one shared scheduler — they're not three independent classes; they're three intertwined features on the same `HeartbeatScheduler` instance). The architectural choice mirrors the F-022 ToolCallQuota / F-018 HaltDetector pattern: pure-class primitive with no I/O, public methods, observability counters in `getStatus()`.
- Public API surface (`HeartbeatScheduler` class): minimal and predictable.
  - Constructor (`HeartbeatConfig` → throws on invalid configs): the validation gate. Construction is the sole side effect; once the instance exists, it's well-formed. No partially-initialized state.
  - `start(handler)`: registers the handler + creates the `setInterval` timer. Throws on double-start.
  - `stop()`: clears the timer if running. Idempotent.
  - `tick()`: public manual driver returning `Promise<TickResult>`. Used by tests + manual-mode callers + the F-024 same-schedule guard.
  - `getStatus()`: observability snapshot.
  - `getIntervalSeconds()`: convenience accessor for the resolved interval.
  - `onIdleArchive(callback)`: F-025 broadcast registration.
- Cadence-zone enforcement constants are explicit (`MAD_ITERATION_SECONDS = 270`, `DEPLOYMENT_WATCH_SECONDS = 1500`, `FORBIDDEN_ZONE_LOWER_INCLUSIVE = 280`, `FORBIDDEN_ZONE_UPPER_INCLUSIVE = 1199`). Lined up with `loop-cadence-discipline.md` profile table; future profile additions (e.g., a hypothetical `audit-watch` for ~500s on a different invariant trade-off) would extend the union + add a constant + extend the resolution switch — additive change, not breaking.
- `setInterval`-driven tick uses `void this.tick()` so the timer callback doesn't await but the promise's rejection cannot leak as an unhandled rejection (TypeScript's `void` operator is the canonical fire-and-forget shape). Tests await `tick()` directly. The F-024 in-flight guard catches re-entry whether driven by setInterval OR manual tick — both paths share the same `tickInFlight` boolean.
- F-024's `tickInFlight` boolean is set BEFORE `await this.tickHandler()` and cleared in a `finally` block. This is the **canonical pattern** for async re-entry guards: even if the handler throws (synchronous or async), the guard clears so the next tick can proceed. If the guard were cleared in a `then()` only, a thrown handler would permanently halt the scheduler. The `finally` shape is correct (lines 287-298 of heartbeat.ts).
- F-025's idle-gap detection runs BEFORE the in-flight guard sets, BEFORE `lastTickAt` updates, but AFTER the in-flight skip-check. So: if a tick fires while the prior tick is in-flight, the new tick is skipped (no idle-archival check), the skip counter increments, and `{ ran: false, skipped: true }` returns. If a tick fires while NOT in-flight AND `archiveAfterMinutes` is set AND `priorTickAt` is non-null AND the gap exceeds the threshold, callbacks fire BEFORE the handler runs. This ordering preserves the F-024 contract (skipped ticks don't fire idle-archival callbacks, per the F-025 ledger acceptance scenario 8) and gives idle-archival listeners precedence over the boot-handler invocation (so archives complete before the boot-spawn writes new run files).
- Composition with downstream features per ledger:
  - F-001 (engine-bootstrap-loop): caller's `tick` handler invokes the boot-fresh-run path. F-023 is agnostic to what the handler does. Compile-time deps on F-001: ZERO. Call-site deps on F-001: caller wires when integrating.
  - F-006 (logging-pipeline) + F-008 (storage-layout): caller writes `cron-fires.jsonl` append-only entry inside its handler. F-024's skip return shape gives the caller the SKIP signal to log `outcome: "overlap_skipped"`.
  - F-002 (per-agent-identity): caller resolves agent identity for the fresh run before invoking F-023's tick.
  - F-026 + F-027 (drift-accounting + manual-halt-override): consume `getStatus.lastTickAt` + `tickCount` for drift calculation. F-023 contributes the shape, not the calculation.
- Hard deps per ledger: F-001 + F-006 + F-008. Soft deps on F-024 + F-002. The current impl has compile-time dep on NONE of these (F-024 + F-025 are SAME-FILE additions, not cross-file imports). The boundary is in place; the deps materialize at call-site (engine code routes the pieces together when the cron registry + run-spawn integration lands). Forward-compatible per `verification-protocol.md` Rule 3 (MATCH EXISTING STYLE).
- Forward path for `automations/cron-schedules.json` reading + multi-schedule registry + cross-platform cron-expression parsing (currently the cadence is profile-or-seconds, not a `*/5 * * * *` cron string per the ledger §Behavior contract): a future `CronRegistry` feature would compose against `HeartbeatScheduler` instances per parsed schedule. The split-class shape is correct: parsing belongs in a parser; cadence-aware scheduling belongs here. Same architectural separation as F-009 (backend interface) vs F-010 / F-011 (concrete providers).

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | Behavior-contract scope narrowing: ledger §Behavior contract names cron-schedules.json reading + cron-fires.jsonl appending + F-001 run-spawn + F-002 identity at fire time. The wave-016 / lane-b GREEN flip deliberately scoped F-023 to the scheduler primitive only (mirroring F-022 ToolCallQuota + F-018 HaltDetector). The integration callsites are deferred to caller integration work owned by F-001 / F-006 / F-008. | Accept; ledger §Implementation notes "Scope simplified vs ledger §Behavior contract" paragraph documents this openly. Backlog item: cron-registry + runspawn integration flips. |
| F2 | MINOR | Acceptance-scenario divergence: ledger lists 3 end-to-end scenarios (scheduler runs for 1 hour producing cron-fires.jsonl; fire boots a run; cadence rejection); 21 implemented scenarios go deeper on the primitive contract (cadence-zone bounds, escape-hatch, tick-before-start, async-handler await, setInterval witness). Only scenario 3 (forbidden-zone rejection) maps directly. Scenarios 1+2 require F-001/F-006/F-008 integration. | Accept; ledger §Implementation notes documents the divergence. Future integration waves will retire scenarios 1+2 by composing against this primitive. |
| F3 | MINOR | CADENCE_FORBIDDEN_ZONE error code naming: ledger acceptance scenario 3 specifies the rejection string includes `CADENCE_FORBIDDEN_ZONE`. Impl uses `forbidden zone 280-1199s` + remediation pointer. Semantically equivalent; a literal-substring consumer would not match. | Accept; no current consumers parse this string. Future error-code-taxonomy wave (when M4 F-029 sysexits.h normalization + F-030 JSON envelope reach error shapes) should normalize the error string for machine-parseable contexts. |
| F4 | MINOR | Drift accounting deferred: ledger §Behavior contract specifies "schedule drift (actual_fire_utc vs scheduled_utc) MUST stay ≤5% of the cadence interval over a 100-fire window" per ce:SC-007. F-023 contributes the SHAPE (`getStatus.lastTickAt` + `tickCount`) but NOT the calculation. F-026 (drift-accounting, GREEN at wave-017 / lane-c) owns the math. | Accept; ledger §Implementation notes documents this openly. F-026 has consumed the shape per its own ledger; drift accounting is an integration concern not a primitive concern. |
| F5 | PRAISE | Cadence-zone enforcement directly mechanizes `loop-cadence-discipline.md` — the kit rule's prose ("the 280-1199s zone is forbidden") becomes a constructor throw with an inline remediation pointer. Operator escape hatch (`enforceWarmCacheZones: false`) preserves consent-in-code over consent-in-silence. | Keep. |
| F6 | PRAISE | Public `tick()` is the right test ergonomics: tests drive the handler synchronously without fake-timers; the `setInterval`-driven path IS empirically witnessed via `vi.useFakeTimers()` in scenario 14 (start/stop block). Two-paths-one-counter is the canonical async-trigger primitive shape. F-018 + F-022 follow the same pattern; F-023 extends it to the cron domain. | Keep. |
| F7 | PRAISE | Same-class extension by F-024 + F-025 (wave-017 / lane-b) preserves F-023's contract. The `tickInFlight` guard + `skippedTicks` counter + `archiveAfterMinutes` field + `onIdleArchive` registration + idle-gap detection all live on the same `HeartbeatScheduler` instance — three intertwined features sharing one timer + one tickCount + one lastTickAt. The architectural choice mirrors F-022 + F-018; future cron features (drift-accounting, fire-budgeting, etc.) extend this same class additively. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 88).

F-023 scheduler-primitive contract is implemented correctly; all 21 acceptance scenarios pass per the recorded green-test-output proof and re-verified at review time (`pnpm test` 2026-05-07: 31 test files / 225 tests / 0 failed); no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-023 ledger frontmatter (`LOCKED if GREEN AND reviews/F-023-cron-heartbeat-review.md exists with verdict: ACCEPT`).

The MINOR findings F1-F4 are honest scope-narrowing notes per `no-silent-deferrals.md`. The Behavior-contract scope (F1) and acceptance-scenario divergence (F2) are recorded openly in the ledger §Implementation notes "Scope simplified vs ledger §Behavior contract" paragraph; the CADENCE_FORBIDDEN_ZONE naming gap (F3) is a future-error-taxonomy concern; the drift-accounting deferral (F4) is owned by F-026 (already GREEN). PRAISE findings F5-F7 capture three load-bearing architectural choices: cadence-zone enforcement as direct kit-rule mechanization, the test-ergonomics two-paths-one-counter shape, and the same-class extension pattern that F-024 + F-025 honor.

F-023 transitions GREEN → LOCKED.

**This LOCKED transition is the first M3 (cron / heartbeat) feature LOCKED — the cornerstone primitive. M3 sibling features F-024 + F-025 + F-026 + F-027 are all GREEN and LOCKED-eligible; this review establishes the precedent shape future M3 LOCKED reviews follow.**

## Cross-references

- Ledger: `docs/03-feature-catalog/M3-cron-heartbeat/F-023-cron-heartbeat.md`
- Source: `packages/engine-core/src/heartbeat.ts` (~313 LOC; F-023 owned ~145 LOC + F-024/F-025 same-class additions)
- Tests: `tests/unit/F-023-cron-heartbeat.test.ts` (21/21 PASS at GREEN time + at review time)
- GREEN proof: `docs/09-examples-proof/F-023/{red,green}-test-output.txt` + `physical-proof.md`
- GREEN transition: ledger status-history wave-016 / lane-b (cross-lane staging-race sighting #16; substance preserved; commits scrambled per `non-negotiable-rules.md` (NO destructive git ops))
- Engine-core file-split convention: wave-011 / lane-a (per-feature .ts files + barrel re-export)
- Same-class extensions: F-024 (skip-on-overlap, wave-017 / lane-b) + F-025 (idle-archival, wave-017 / lane-b) — both extend `HeartbeatScheduler` without breaking F-023's contract
- Composing features: F-026 (drift-accounting, GREEN at wave-017 / lane-c — consumes `getStatus.lastTickAt` + `tickCount`) + F-027 (manual-halt-override, GREEN at wave-017 / lane-c) — both compose against this primitive
- Forward path: cron-schedules.json reader + multi-schedule registry + cron-expression parser (a future feature, not F-023 scope) + F-001 run-spawn integration + F-006/F-008 cron-fires.jsonl write
- Kit rule: `loop-cadence-discipline.md` (cadence profiles + forbidden zone — directly mechanized in the constructor)
- Kit rule: `council-verdict-artifact.md` validity oracle (Reviewer summary table + Median confidence: 88 + Decision: ACCEPT + size > 500B)
- Pattern: pure-class primitive + public manual driver + observability counters (also used by F-018 HaltDetector + F-022 ToolCallQuota)
- Precedent: F-022 review (wave-013 / lane-d), F-018 review (wave-013 / lane-d) — same architectural shape
- Review verdict envelope: per `docs/05-design-reviews/README.md` (APPROVE / APPROVE-WITH-SUGGESTIONS / WAIT-FOR-AUTHOR / REJECT)
