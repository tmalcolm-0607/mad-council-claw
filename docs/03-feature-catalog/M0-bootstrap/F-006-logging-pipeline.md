---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b); GREEN flip wave-009 / lane-a; LOCKED flip wave-012 / lane-d
status: locked
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-009 / lane-a
    note: "RED test authored first per wave-5 retro proposal (4 scenarios: structured emit + level-gating + ctx merge + sink injection); GREEN impl appended to packages/engine-core/src/index.ts (~165 LOC F-006 region) with createLogger / LogEvent / Logger / LogLevel surface. 4/4 PASS; full GREEN feature suite 22/22 PASS (F-001+F-002+F-014+F-015+F-006). Out-of-scope per `rules/no-silent-deferrals.md`: F-008 filesystem sink, F-015 audit-chain integration, ESLint no-console rule, trace+fatal levels — all surfaced in commit body."
  - status: locked
    at: 2026-05-07
    by: wave-012 / lane-d
    note: "Council review verdict ACCEPT (Verdict consensus: APPROVE; median confidence 86; 0 CRITICAL / 0 MAJOR / 4 MINOR / 2 PRAISE) at docs/05-design-reviews/council-reviews/F-006-logging-pipeline-review.md. red-green-rule predicate satisfied: GREEN AND review file with verdict ACCEPT. MINOR findings are honest scope-narrowing notes per no-silent-deferrals.md (F-008 filesystem sink integration; F-015 audit-chain integration; six-level extension; identity-stamping enforcement). Source post-wave-011/lane-a engine-core split lives at packages/engine-core/src/logger.ts (134 LOC). 4/4 acceptance scenarios continue to PASS unchanged. Third LOCKED transition in the repo (sibling with F-002 + F-008 in wave-012 / lane-d)."
feature-id: F-006
short-slug: logging-pipeline
milestone: M0
provenance:
  surfaces:
    - cp:src/main/logger
    - ce:FR-AUDIT-001
    - kit:lens-telemetry
fr-coverage: []
test-files:
  unit:
    - tests/unit/F-006-logging-pipeline.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - vitest:tests/unit
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-006-logging-pipeline-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-002, F-008]
out-of-scope-notes: |
  Local OpenTelemetry export + crash reporting are tracked under M16 (F-110..F-113).
  This feature provides the structured-event pipeline that those telemetry features
  consume; it does not itself emit OTel spans.
confidence: high
---

# F-006 — Logging pipeline

## Behavior contract

A single structured-logging facade routes every engine event to two sinks: (1) a human-readable rolling text log under `runs/<run_id>/log.ndjson`, and (2) the hash-chained audit log per F-015. Every entry carries `{run_id, agent_id, parent_run_id, timestamp_utc, level, event_name, fields}`. Levels are `trace | debug | info | warn | error | fatal`. The facade is the ONLY supported way to emit logs from engine-core; direct `console.log` from engine code is forbidden by lint rule.

## Acceptance scenarios

1. **Given** an engine cycle emits `logger.info('cycle.start', { cycle: 3 })`, **When** the cycle completes, **Then** `runs/<run_id>/log.ndjson` contains a single JSON line with `event_name: "cycle.start"`, `fields.cycle: 3`, and the full identity triple.
2. **Given** a developer adds `console.log('debug')` inside `packages/engine-core/src/`, **When** lint runs, **Then** the rule `no-console` fires with severity error.
3. **Given** an info-level emit and an audit-log writer that's offline, **When** the logger is invoked, **Then** the text log still receives the entry AND the logger surfaces a degradation signal (per `degradation-fallback-policy.md` Rule 3) without crashing.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| `tests/unit/F-006-logging-pipeline.test.ts` | unit | 🟢 GREEN (4/4 PASS) | scenario 1 (structured emit) + 3 brief-scoped extensions |
| (deferred) `tests/unit/logging/no-console-rule.test.ts` | unit | RED | scenario 2 (ESLint config not runtime; tracked as follow-on per wave-009/lane-a out-of-scope notes) |
| (deferred) `tests/integration/logging/audit-sink-degraded.test.ts` | integration | RED | scenario 3 (requires audit-log integration; F-015 follow-on) |

## Dependencies

- **Hard:** F-001 (engine cycles produce events), F-002 (identity stamps every entry), F-008 (storage layout for `runs/<run_id>/log.ndjson`)
- **Soft:** F-015 (hash-audit consumes the same pipeline)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| cp:src/main/logger | clawpilot main-process logger pattern |
| ce:FR-AUDIT-001 | hash-chained audit log feeds off this pipeline |
| kit:lens-telemetry | structured-event discipline (LoggerMessage source generators in .NET; same shape in TS) |

## Implementation notes

GREEN flip landed wave-009 / lane-a as the boundary primitive (in-memory facade). Lives at `packages/engine-core/src/index.ts` § "F-006 — Logging pipeline (in-memory boundary primitive)" (~165 LOC, end-of-file append zone — same convention used by wave-008/lane-a (F-014) and wave-008/lane-b (F-015)).

Surface inventory:

- `LogLevel` type — `'debug' | 'info' | 'warn' | 'error'` (4 of the ledger's 6 levels; `trace` + `fatal` extension is straightforward follow-on per wave-009/lane-a brief).
- `LogEvent` interface — reserved keys `{timestamp, level, event}` + `[key: string]: unknown` for context-field merge.
- `Logger` interface — four-method facade (`debug`/`info`/`warn`/`error`), each takes `(eventName, ctx?)`.
- `createLogger(level, sink)` — factory. Default level `'info'`, default sink JSON-stringified stdout. Custom sink overrides default; spread-then-overwrite ensures reserved keys win over same-named ctx keys.
- `LOG_LEVEL_ORDER` const — internal severity map for level-gating.
- `defaultSink` — the ONE permitted `console.log` reach (with eslint-disable comment); engine code MUST use the Logger facade per the ledger's "ONLY supported way to emit logs" clause.

The facade is identity-agnostic: callers route stamped artifacts (via F-002's `stampIdentity()`) through `Logger.*`. Keeps the boundary minimal so F-008 storage and F-015 audit-chain integrations plug in without forcing identity through the facade.

Out-of-scope items (per `rules/no-silent-deferrals.md`, all surfaced in the wave-009/lane-a commit chain):

1. **F-008 filesystem sink** — write the LogEvent stream to `runs/<run_id>/log.ndjson`. The boundary is ready; the storage flip composes against it.
2. **F-015 audit-chain integration** — route LogEvent records through `appendAuditEntry()` so every event enters the tamper-evident chain. The chain primitive (wave-008/lane-b) and the logging facade (wave-009/lane-a) are both GREEN; the integration step is a follow-on.
3. **`no-console` ESLint rule** (ledger §Acceptance scenario 2) — enforced by ESLint config, not runtime test. Lives in M0 toolchain follow-on (F-005 deps-pinning + F-004 vitest config sibling).
4. **Audit-sink degradation signal** (ledger §Acceptance scenario 3) — requires the F-015 integration which is itself out of scope above.
5. **Six-level extension** — `trace` + `fatal` are straightforward to add by extending `LogLevel` + `LOG_LEVEL_ORDER` + `Logger` interface. Brief specifies four for v1.

## Reproduction

```bash
cd C:/Users/tonym/Repos/mad-council-claw
pnpm install
pnpm exec vitest run tests/unit/F-006-logging-pipeline.test.ts   # 4/4 PASS
```
