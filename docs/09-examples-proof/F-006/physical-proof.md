---
artifact-class: physical-proof
generated-by: wave-009 / lane-a
feature-id: F-006
date: 2026-05-07
status: green
---

# F-006 — Physical proof

Fifth feature transition RED → GREEN in the repo (after F-001 in wave-005, F-002 in wave-006, F-014 in wave-008 / lane-a, F-015 in wave-008 / lane-b). First M0 feature beyond the F-001/F-002 spine to flip GREEN. This file binds the wave-009/lane-a brief's four acceptance scenarios to actual vitest output, per Goal G27 (full behavior tests + physical proof) and the wiki contribution protocol.

## Acceptance scenarios → test results

| # | Scenario | Vitest test name | Result |
|---|---|---|---|
| 1 | `logger.info('cycle.start', { cycle: 3 })` produces a `LogEvent` carrying `event: 'cycle.start'`, `level: 'info'`, `cycle: 3`, and an ISO-8601 timestamp. (Mirrors F-006 ledger §Acceptance scenario 1.) | scenario 1: logger.info emits LogEvent with timestamp + level + event + context | ✓ PASS |
| 2 | A logger created with min-level `warn` drops `debug`/`info` calls and emits only `warn`/`error`. | scenario 2: level-gating drops events below the configured threshold | ✓ PASS |
| 3 | Caller-supplied context fields (`agent_id`, `run_id`, `cycle`, `reason`) appear at the top level of the emitted record alongside `timestamp`/`level`/`event`. | scenario 3: context fields merge onto the LogEvent record | ✓ PASS |
| 4 | A custom sink function receives every emitted event; the default `console.log` sink is NOT invoked when a sink is provided. | scenario 4: sink injection — every emitted event flows through the injected sink only | ✓ PASS |

## Scope deviations from F-006 ledger (intentional, documented)

The wave-009/lane-a brief defines a narrower scope than the F-006 ledger §Behavior contract. Lane A executed the brief's scope and surfaced 5 explicit out-of-scope items per `rules/no-silent-deferrals.md`:

| Item | Brief | Ledger | Resolution |
|---|---|---|---|
| Level set | 4 levels (debug/info/warn/error) | 6 levels (trace+fatal added) | Implement 4; trace+fatal extension is straightforward follow-on (extend `LogLevel` + `LOG_LEVEL_ORDER` + `Logger` interface). |
| Sinks | Single injectable sink | Dual sinks (text log + audit log) | Implement single. F-008 will plug in the filesystem text sink; F-015 audit-chain integration plugs in the audit sink. |
| Audit composition | Out of scope | Routes through hash-chained audit log | Out of scope per ledger §dependencies (F-015 soft dep). The audit chain primitive is GREEN already (wave-008/lane-b); the integration step is a follow-on flip. |
| `no-console` lint rule | Out of scope | Acceptance scenario 2 (lint fires on direct `console.log` from engine code) | ESLint config concern, not a runtime test. Tracked as M0 toolchain follow-on alongside F-005 (deps-pinning) and F-004 (vitest config). The default sink reaches `console.log` ONCE with an explicit eslint-disable comment — engine code is still required to use the Logger facade. |
| Audit-sink degradation signal | Out of scope | Acceptance scenario 3 (text log still receives entry; surfaces degradation signal per `degradation-fallback-policy.md` Rule 3) | Requires the audit-log integration which is itself out of scope. Tracked as follow-on. |

The ledger's identity stamping requirement (`{run_id, agent_id, parent_run_id}` on every entry) is honored implicitly: the facade is identity-agnostic; callers route stamped artifacts (via F-002's `stampIdentity()`) through `Logger.*`. The boundary stays minimal so F-008 storage and F-015 audit-chain integrations plug in without forcing identity through the facade itself.

## Implementation summary

`packages/engine-core/src/index.ts` — F-001 / F-002 / F-014 / F-015 unchanged; F-006 adds ~165 LOC at end-of-file (same disjoint-append-zone convention used by waves 8/lane-a (F-014) and 8/lane-b (F-015)):

- `LogLevel` type — `'debug' | 'info' | 'warn' | 'error'` (4 levels per brief; ledger's 6-level set deferred).
- `LogEvent` interface — reserved keys `{timestamp: string, level: LogLevel, event: string}` + `[key: string]: unknown` for caller-supplied context-field merge.
- `Logger` interface — four-method facade (`debug`/`info`/`warn`/`error`), each takes `(eventName: string, ctx?: Record<string, unknown>)`.
- `createLogger(level, sink)` — factory function. Default level `'info'`, default sink JSON-stringified stdout. Custom sink overrides default; spread-then-overwrite ensures reserved keys win over same-named ctx keys (callers cannot accidentally shadow `timestamp`/`level`/`event` by passing them in `ctx`).
- `LOG_LEVEL_ORDER: Record<LogLevel, number>` — internal severity map for level-gating (`debug=0 < info=1 < warn=2 < error=3`).
- `defaultSink(event)` — the ONE permitted `console.log` reach (with `eslint-disable-next-line no-console` comment); engine code MUST use the `Logger` facade per the ledger's "ONLY supported way to emit logs" clause.

## Reproduction

```bash
cd C:/Users/tonym/Repos/mad-council-claw
pnpm install
pnpm exec vitest run tests/unit/F-006-logging-pipeline.test.ts
# Expected: "Test Files 1 passed (1)" + "Tests 4 passed (4)" + exit 0
```

For the GREEN-feature suite count (5 GREEN test files):

```bash
pnpm exec vitest run tests/unit/F-001-engine-bootstrap-loop.test.ts \
                    tests/unit/F-002-per-agent-identity-runid.test.ts \
                    tests/unit/F-014-pre-close-retro-signal.test.ts \
                    tests/unit/F-015-hash-chained-audit-log.test.ts \
                    tests/unit/F-006-logging-pipeline.test.ts
# Expected: "Test Files 5 passed (5)" + "Tests 22 passed (22)" + exit 0
```

Captured: `green-test-output.txt`. Stability: 2 consecutive runs, 4/4 PASS each (10ms and 12ms test execution time respectively), no flake.

Note on `pnpm test:unit`: the full unit suite shows 17 fail / 22 pass / 7 test files because two parallel wave-009 lanes have authored RED tests for F-016 (query-audit-log) and F-018 (failure-pattern-halt) that intentionally fail pending their own GREEN flips. Per `rules/scope-discipline.md`, those are out of this lane's scope; F-006 itself is fully GREEN.

## Lessons / loop-improvement notes for wave-10

1. **Brief-vs-ledger scope-divergence framing (MEDIUM).** The wave-009/lane-a brief specified four levels; the F-006 ledger §Behavior contract specifies six. Without explicit framing, this could read as either "brief is wrong, expand to six" or "brief overrides ledger, six was a mistake." Lane A treated the brief as authoritative for v1 scope and surfaced the five-item gap explicitly in commit body + ledger §Implementation notes. Wave-10 takeaway: the brief-vs-ledger relationship MUST be stated explicitly in the wave brief itself ("brief narrows ledger scope to v1; deferred items remain in ledger") to prevent silent drift in either direction.

2. **Disjoint-append-zone convention scales beyond 2 lanes (HIGH).** Wave-008 demonstrated 2 concurrent lanes appending disjoint regions to engine-core/src/index.ts. Wave-009 added a third concurrent lane (F-006 by Lane A, F-016 + F-018 RED tests by other lanes). Disjoint-append still works because: (a) F-006 appended at end-of-file after F-015's region; (b) F-016 + F-018 tests live in separate test files, not in engine-core/src/index.ts (their GREEN impls would also append). Wave-10 takeaway: the rule is "shared file MUST have disjoint regions; separate files MUST be staged separately." Both honored in this wave.

3. **Linter-touch after commit is non-load-bearing (HIGH).** During wave-009/lane-a, an editor/linter normalized line endings on `packages/engine-core/src/index.ts` after the GREEN commit landed (system reminder confirmed intentional). F-006 still passed 4/4 after the touch — proves the impl is robust to whitespace/line-ending changes. Wave-10 takeaway: when a system reminder flags a non-author file modification, re-run the lane's tests to confirm GREEN holds; if so, no commit needed (the next commit will pick up the normalization).

## Confidence

HIGH. All 4 acceptance scenarios pass with real vitest output (not synthesized). RED baseline captured BEFORE the impl flip per the wave-5 retro proposal — see `red-test-output.txt`. Two consecutive stable runs confirm no flake. RED→GREEN transition cleanly observable in commit history (`c46199e` RED, `ed5556f` GREEN). Sink injection scenario explicitly verifies that `console.log` is NOT invoked when a custom sink is provided — closes the load-bearing concern from the F-006 ledger that the facade is the ONLY emit path.

## Soft dependencies still RED

Per the F-006 ledger:
- F-008 (local-storage-layout) — F-006 emits LogEvent records; the filesystem sink that writes them to `runs/<run_id>/log.ndjson` is F-008's job
- F-015 (hash-chained-audit-log) — already GREEN wave-008/lane-b; the integration step (route LogEvent through `appendAuditEntry`) is a follow-on
- F-001 (engine-bootstrap-loop) — already GREEN wave-005; engine cycles will reach for the Logger facade once their emit sites are wired
- F-002 (per-agent-identity-runid) — already GREEN wave-006; identity stamping happens before LogEvent emit (caller responsibility per the boundary contract)

`no-console` ESLint rule + degradation-signal-on-audit-offline + six-level extension (trace+fatal) remain explicitly out-of-scope for v1 per wave-009/lane-a brief; tracked as follow-on flips.
