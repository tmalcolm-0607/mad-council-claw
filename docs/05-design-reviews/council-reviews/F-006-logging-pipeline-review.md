---
artifact-class: council-review
feature-id: F-006
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-012 / lane-d
---

# F-006 logging-pipeline — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 88 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 72 |
| architect-lens | Architect | APPROVE | 86 |

Median confidence: 86

## Implementation reviewed

- `packages/engine-core/src/logger.ts` — 134 LOC; `LogLevel`, `LogEvent`, `Logger` types + `createLogger(level, sink)` factory + internal `LOG_LEVEL_ORDER` map + `defaultSink` (the ONE permitted `console.log` reach behind the facade). Split out from monolithic `index.ts` in wave-011/lane-a.
- `tests/unit/F-006-logging-pipeline.test.ts` — 4 acceptance scenarios; all PASS per `docs/09-examples-proof/F-006/green-test-output.txt` and re-confirmed at review time (4/4 PASS in 8ms; full vitest run 13/13 PASS across F-002 + F-006 + F-008).
- Commit history per `docs/07-roadmap/decision-log.md` + ledger status-history: F-006 RED at wave-002 / lane-b (initial ledger); F-006 GREEN at wave-009 / lane-a (RED test authored first per the wave-5 retro proposal; GREEN impl appended to `index.ts` ~165 LOC; 22/22 PASS at GREEN time across F-001/F-002/F-014/F-015/F-006); engine-core split (Lane A wave-011) carved `logger.ts` out of `index.ts` with no behavior change.

## Advocate lens

**Verdict: APPROVE (confidence 88)**

- Implementation is minimal and correct per `minimum-change.md`: ~134 LOC delivers a four-method logging facade with level-gating + injectable sink + reserved-key shadowing protection. The facade is the boundary primitive that the F-008 storage flip and F-015 audit-chain integration will compose against — locked here, integrations follow.
- All 4 acceptance scenarios PASS:
  - **Scenario 1** (structured emit): `logger.info('cycle.start', { cycle: 3 })` produces a `LogEvent` with `event: 'cycle.start'`, `level: 'info'`, ISO-8601 `timestamp`, and `cycle: 3` merged at the top level. Verified.
  - **Scenario 2** (level-gating): a logger created with min-level `warn` drops `debug` + `info` calls and emits `warn` + `error`. Verified via `LOG_LEVEL_ORDER` numeric comparison.
  - **Scenario 3** (context merge): caller-supplied keys (`agent_id`, `run_id`, `cycle`, `reason`) appear at the top level of the emitted record. The implementation deliberately spreads ctx FIRST then overwrites with reserved keys (`timestamp`, `level`, `event`) — this prevents callers from accidentally shadowing the canonical fields by passing `{ level: 'info' }` in ctx.
  - **Scenario 4** (sink injection): a custom sink receives every event; the default `console.log` sink is NOT invoked when a custom sink is provided. Verified via `vi.spyOn(console, 'log')` — `expect(consoleSpy).not.toHaveBeenCalled()`.
- The `defaultSink` carries an `eslint-disable-next-line no-console` comment scoped narrowly to that ONE line. The `no-console` lint rule (acceptance scenario 2 of the original ledger contract) is enforced by ESLint config (out-of-scope per ledger; tracked as F-005/M0 toolchain follow-on); the runtime test only verifies the facade routes correctly.
- Surface trace per ledger maps cleanly: `cp:src/main/logger` (clawpilot main-process logger) + `ce:FR-AUDIT-001` (hash-chained audit feeds off this pipeline) + `kit:lens-telemetry` (structured-event discipline). The facade is identity-agnostic — callers route stamped artifacts (via F-002's `stampIdentity()`) through `Logger.*`, keeping the boundary minimal.

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 72)**

- F-006 is a **boundary primitive**; the deeper integrations are explicitly out-of-scope per the ledger §Implementation notes. Five distinct deferrals (each surfaced honestly per `no-silent-deferrals.md`):
  1. **F-008 filesystem sink** — the LogEvent stream is NOT yet routed to `runs/<run_id>/log.ndjson`; the boundary is ready but the storage integration is a follow-on flip.
  2. **F-015 audit-chain integration** — LogEvent records are NOT yet routed through `appendAuditEntry()`; the chain primitive (wave-008/lane-b) and the logging facade (wave-009/lane-a) are both GREEN, but the integration step is unfinished.
  3. **`no-console` ESLint rule** (ledger §Acceptance scenario 2) — enforced by ESLint config, not runtime test; lives in M0 toolchain follow-on (F-005 deps-pinning).
  4. **Audit-sink degradation signal** (ledger §Acceptance scenario 3) — requires the F-015 integration above; cannot be tested until that lands.
  5. **Six-level extension** — `trace` + `fatal` are documented but not implemented; brief specifies four for v1. Trivial extension (one entry in `LogLevel` union + one entry in `LOG_LEVEL_ORDER` + one method on `Logger` interface).
- The ledger's behavior contract (§Behavior contract) describes a **richer envelope** than the current implementation: "Every entry carries `{run_id, agent_id, parent_run_id, timestamp_utc, level, event_name, fields}`." The current `LogEvent` shape is `{timestamp, level, event, ...ctx}` — the identity triple (`run_id` / `agent_id` / `parent_run_id`) is NOT a reserved field; it merges through `ctx` like any other key. This is the `wave-9 / lane-a` brief's TypeScript hint preserving minimum-change discipline. **However**, a reader of the ledger could mistake "F-006 LOCKED" for "every log line carries the stamped identity automatically" — which is not yet the case. Closure path: when the F-002 audit-writer integration follow-on lands (see F-002 review F2), `Logger` calls in engine code will stamp identity via `stampIdentity()` first then pass the stamped object as ctx; the merge produces the ledger's envelope shape automatically.
- Suggestion (NON-BLOCKING): track a "logging-identity-integration" follow-on F-NNN that wires F-002's `stampIdentity` through `Logger.*` calls. Pairs with the F-002 audit-writer integration follow-on; both can be a single F-NNN.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `packages/engine-core/src/logger.ts` lines 1-134 and `tests/unit/F-006-logging-pipeline.test.ts` lines 1-141 directly; the implementation matches the contract; the reserved-key-wins shadowing protection is real (line 119-124 of `logger.ts`); the `eslint-disable` comment is correctly scoped to the `defaultSink` only.

## Architect lens

**Verdict: APPROVE (confidence 86)**

- File-split posture: `logger.ts` lives in `packages/engine-core/src/` per the wave-011/lane-a engine-core split. Clean module boundary; the single `LogLevel`/`LogEvent`/`Logger`/`createLogger` surface re-exports through the barrel (`packages/engine-core/src/index.ts`). No cross-feature imports; F-006 is independent of F-002 at the type level (the identity composition happens at call site via `stampIdentity` → `ctx`).
- API surface (`Logger { debug, info, warn, error }`, `createLogger(level, sink)`, `LogEvent { timestamp, level, event, [key: string]: unknown }`): symmetric and predictable. The four-method shape matches the four `LogLevel` union values; future six-level extension (`trace` + `fatal`) is an additive change to both surfaces with no breaking impact on callers.
- Reserved-key shadowing: the implementation's `record` construction (line 119-124 of `logger.ts`) spreads ctx FIRST then overwrites with reserved keys. This is a deliberate API-shape decision: callers cannot accidentally clobber the canonical fields (`timestamp` / `level` / `event`) — keeps the contract stable. Architecturally clean.
- Sink injection contract: `createLogger` accepts a `(event: LogEvent) => void` sink; the default JSON-stringified-stdout is the ONE permitted `console.log` reach (with eslint-disable comment scoped to that line). Engine code MUST use the `Logger` facade per the ledger's "ONLY supported way to emit logs from engine-core" clause. Architecturally clean — the facade IS the boundary; sinks are pluggable; the default sink is the smoke-test convenience.
- Hard deps per ledger: F-001 (engine cycles produce events), F-002 (identity stamps every entry), F-008 (storage layout for `runs/<run_id>/log.ndjson`). Soft dep on F-015 (hash-audit consumes the same pipeline). The current implementation has ZERO compile-time deps on F-001/F-002/F-008/F-015 — pure boundary primitive. The deps materialize at the call site (engine code routes stamped artifacts through `Logger.*`, with the storage sink writing to F-008's path layout, with the F-015 integration appending to the audit chain). This compose-at-call-site shape is forward-compatible.
- Level-gating implementation: `LOG_LEVEL_ORDER` numeric map (`debug=0, info=1, warn=2, error=3`) with `<` comparison against `minOrder` is the minimum-shape correct algorithm. No allocation per call; constant-time check; predictable behavior at level boundaries.

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | F-008 filesystem sink integration follow-on: the boundary is ready but the LogEvent stream is NOT yet routed to `runs/<run_id>/log.ndjson`. | Accept; soft-dep-relationship ledger note already covers; backlog item: track explicit "logging-storage-integration" F-NNN follow-on (or fold into F-002 audit-writer integration). |
| F2 | MINOR | F-015 audit-chain integration follow-on: LogEvent records are NOT yet routed through `appendAuditEntry()`; both primitives are GREEN but the wiring step is unfinished. | Accept; integration F-NNN scope (same as F1). |
| F3 | MINOR | Six-level extension (`trace` + `fatal`) deferred per brief's four-level v1 scope. Trivial future extension; non-breaking. | Accept; documented in ledger §Implementation notes. |
| F4 | MINOR | Identity-stamping is NOT enforced inside the facade — ctx merge is the path, requiring callers to stamp first via `stampIdentity()`. A reader could mistake "F-006 LOCKED" for "every log line carries identity automatically." | Accept; pairs with the F-002 audit-writer integration follow-on (see F-002 review F2). |
| F5 | PRAISE | Reserved-key shadowing protection: ctx spread BEFORE reserved-key overwrite prevents accidental clobbering of `timestamp`/`level`/`event`. | Keep. |
| F6 | PRAISE | `defaultSink` is the ONE permitted `console.log` reach, narrowly scoped with `eslint-disable-next-line no-console` comment. Discipline preserved. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 86).

F-006 minimal-contract is implemented correctly; all 4 acceptance scenarios pass per the recorded green-test-output proof; no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-006 ledger frontmatter (`LOCKED if GREEN AND reviews/F-006-logging-pipeline-review.md exists with verdict: ACCEPT`).

The MINOR findings are honest scope-narrowing notes per `no-silent-deferrals.md` — they are surfaced in this review (and in the F-006 ledger §Implementation notes), not silently elided. Future deeper integration work (filesystem sink wiring; audit-chain composition; six-level extension; identity-stamping enforcement) is scoped to future F-NNNs, not a re-scoping of F-006's contract.

F-006 transitions GREEN → LOCKED.

## Cross-references

- Ledger: `docs/03-feature-catalog/M0-bootstrap/F-006-logging-pipeline.md`
- Source: `packages/engine-core/src/logger.ts` (split from `index.ts` in wave-011/lane-a)
- Tests: `tests/unit/F-006-logging-pipeline.test.ts` (4/4 PASS)
- GREEN proof: `docs/09-examples-proof/F-006/` (per ledger §green-evidence)
- GREEN transition: ledger status-history wave-009 / lane-a; impl appended to `index.ts` (~165 LOC F-006 region)
- Engine-core split: wave-011 / lane-a (no behavior change; pure refactor; verified by 75/75 PASS post-split)
- Review verdict envelope: per `docs/05-design-reviews/README.md` (APPROVE / APPROVE-WITH-SUGGESTIONS / WAIT-FOR-AUTHOR / REJECT)
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle (Reviewer summary table + Median confidence + Decision)
- Precedent: `docs/05-design-reviews/council-reviews/F-001-engine-bootstrap-loop-review.md` (first LOCKED transition; wave-011 / lane-b); `F-002-per-agent-identity-runid-review.md` (wave-012 / lane-d sibling)
