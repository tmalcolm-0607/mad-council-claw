---
artifact-class: feature-ledger
generated-by: hand-authored (wave-003 / lane-a)
status: locked
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-003 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-016 / lane-b
    note: "RED -> GREEN transition; HeartbeatScheduler ~145 LOC + 21 acceptance scenarios across 6 describe blocks; 21/21 PASS at GREEN time; full suite 179/179 PASS. First M3 feature transition. Pure-class scheduler primitive; cadence-zone validation enforced at construction per loop-cadence-discipline.md (270/1500 named profiles + 280-1199s forbidden zone with operator-override escape hatch). Test ergonomics: tick() public for manual-mode + setInterval-driven mode covered via fake-timers. Source-file attribution corrupted by cross-lane staging race (sighting #16) - heartbeat.ts + barrel re-export landed under commit fdede59 'docs(F-011): post-impl council review verdict ACCEPT' with substance preserved; barrel restoration in fix-forward commit f59c4ce; proof artifacts committed at 0d4c84a. Drift accounting (5% over 100-fire window per ce:SC-007) deferred to F-026/F-027 - shape contributed via getStatus.lastTickAt; documented in physical-proof.md."
  - status: locked
    at: 2026-05-07
    by: wave-018 / lane-a
    note: "GREEN -> LOCKED transition; post-impl council review verdict ACCEPT (median confidence 88; Advocate APPROVE 90, Skeptic APPROVE-WITH-SUGGESTIONS 76, Architect APPROVE 88; 0 CRITICAL / 0 MAJOR / 4 MINOR / 3 PRAISE). Review file: docs/05-design-reviews/council-reviews/F-023-cron-heartbeat-review.md. MINOR findings: behavior-contract scope narrowing (cron-schedules.json reading + cron-fires.jsonl appending + F-001 run-spawn deferred to caller integration); acceptance-scenario divergence (21 implemented scenarios go deeper on primitive contract vs ledger's 3 end-to-end scenarios); CADENCE_FORBIDDEN_ZONE error code naming (impl uses 'forbidden zone 280-1199s' + remediation pointer, semantically equivalent); drift accounting deferred to F-026/F-027 (F-023 contributes shape only). PRAISE: cadence-zone enforcement directly mechanizes loop-cadence-discipline.md; public tick() is the right test ergonomics; same-class extension by F-024+F-025 preserves the contract. First M3 (cron / heartbeat) feature LOCKED — establishes the precedent shape for the milestone's remaining LOCKED transitions. Re-verified at review time: 21/21 PASS, full suite 225/225 across 31 test files."
feature-id: F-023
short-slug: cron-heartbeat
milestone: M3
provenance:
  surfaces:
    - ce:FR-PROACTIVE-001
    - ce:US-7
    - ce:US-8
    - ce:CronFireRecord
    - kit:loop-skill
    - kit:rules/loop-cadence-discipline.md
fr-coverage: []
test-files:
  unit: [tests/unit/F-023-cron-heartbeat.test.ts]
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects: [unit]
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-023-cron-heartbeat-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-006, F-008]
out-of-scope-notes: |
  Skill-allowlist + version-pinning at heartbeat fire is M7 (F-051..F-056).
  Conditional-trigger automations (event-driven, not cron) are M7 (F-061..F-063).
  Multistep automations (chained cron-fires) are M7 (F-064).
confidence: high
---

# F-023 — Cron heartbeat

## Behavior contract

The engine supports cron-driven heartbeats: scheduled, recurring, autonomous run invocations registered in `automations/cron-schedules.json`. A heartbeat scheduler reads each schedule's cron expression, computes next-fire times, and at each fire spawns a fresh run (per F-001) under the configured agent identity (per F-002). Each fire is recorded as an append-only entry in `automations/cron-fires.jsonl` with `fire_id`, `schedule_id`, `scheduled_utc`, `actual_fire_utc`, `run_id`, and `outcome`. Schedule drift (actual_fire_utc vs scheduled_utc) MUST stay ≤5% of the cadence interval over a 100-fire window (per ce:SC-007). The scheduler is cadence-aware per `kit:rules/loop-cadence-discipline.md` — the two named profiles (`mad-iteration` 270s, `deployment-watch` 1500s) are the canonical defaults; the 280-1199s zone is forbidden.

## Acceptance scenarios

1. **Given** a registered cron schedule `*/5 * * * *` (every 5 min, mapped to `deployment-watch` profile @ 300s nearest), **When** the scheduler runs for 1 hour, **Then** `cron-fires.jsonl` contains exactly 12 entries (±1 for boundary), each with `outcome: "completed"` and drift ≤15s (5% of 300s).
2. **Given** a heartbeat fire that boots a run, **When** the run completes, **Then** the cron-fires entry is updated with the resulting `run_id` + final outcome (cross-referenced with that run's audit log).
3. **Given** a heartbeat scheduled with cadence in the forbidden zone (`delaySeconds: 600`), **When** the scheduler validates the schedule, **Then** registration is rejected with `CADENCE_FORBIDDEN_ZONE` and a remediation pointer to `loop-cadence-discipline.md`.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/cron/scheduler-drift.test.ts` | unit | RED — drift accounting | scenario 1 |
| (TBD) `tests/integration/cron/heartbeat-run-spawn.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/cron/cadence-zone-validation.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (run lifecycle to spawn), F-006 (logging for fire entries), F-008 (storage layout for `automations/cron-fires.jsonl`)
- **Soft:** F-024 (skip-on-overlap fires when this scheduler would double-fire), F-002 (identity for spawned-run agent_id)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-PROACTIVE-001 | Cron-driven heartbeat with overlap detection |
| ce:US-7 | Heartbeat user story (P3) |
| ce:US-8 | Cron proactive execution user story |
| ce:CronFireRecord | Append-only `cron-fires.jsonl` schema |
| kit:loop-skill | `/loop` cadence pattern as the substrate |
| kit:rules/loop-cadence-discipline.md | Cadence profiles + forbidden zone enforcement |

## Implementation notes

### Wave-016 / Lane B implementation (RED → GREEN, 2026-05-07)

**Surface shipped:**

- `type CadenceProfile = 'mad-iteration' | 'deployment-watch' | 'custom'`
- `interface HeartbeatConfig { profile, intervalSeconds?, enforceWarmCacheZones? }`
- `interface HeartbeatStatus { isRunning, tickCount, lastTickAt, intervalSeconds }`
- `class HeartbeatScheduler` — constructor (cadence-gate); `start(handler)`; `stop()`; `tick()` (public for tests); `getStatus()`; `getIntervalSeconds()`

**Files:**

- `packages/engine-core/src/heartbeat.ts` — ~145 LOC implementation.
- `packages/engine-core/src/index.ts` — 1 ownership-table comment + 1 re-export `export * from './heartbeat.js'`.
- `tests/unit/F-023-cron-heartbeat.test.ts` — 288 LOC, 21 scenarios across 6 describe blocks.
- `docs/09-examples-proof/F-023/{red,green}-test-output.txt` + `physical-proof.md`.

**Scope simplified vs ledger §Behavior contract:**

F-023 is intentionally the SCHEDULER PRIMITIVE — no I/O, no run spawn, no log append. Mirrors the F-022 ToolCallQuota / F-018 HaltDetector pure-class pattern. Composition by callers:

- Run spawn → F-001 (engine-bootstrap-loop): orchestrator's tick handler invokes the boot path.
- `cron-fires.jsonl` append → F-006 (logging-pipeline) + F-008 (storage layout).
- Overlap detection → F-024 (skip-on-overlap): wraps the tick handler.
- Agent identity → F-002 (per-agent-identity-runid): caller resolves before the handler.

Per `no-silent-deferrals.md`: every non-implemented surface is named and explicitly owned by a downstream feature. Drift accounting (≤5% over a 100-fire window per ce:SC-007) is the only ledger-named contract that lives in F-026/F-027 (logging+aggregation); F-023 contributes the SHAPE (`getStatus.lastTickAt` + `tickCount` are the inputs to drift calculation) but not the calculation.

**Cadence-zone enforcement (loop-cadence-discipline.md):**

The constructor rejects intervals in the 280-1199s forbidden zone with a remediation pointer. Operators with a documented reason can opt out via `enforceWarmCacheZones: false` so the override is reviewable in code rather than silent.

**Cross-lane staging-race attribution (sighting #16):**

The actual `heartbeat.ts` + barrel-export commit landed under commit `fdede59 docs(F-011): post-impl council review verdict ACCEPT` due to cross-lane staging crowding (recurring pattern from waves 9-15, sightings #14, #15). The substance is correct — F-023 isolated test passes 21/21 against HEAD — but the commit message is misleading. Per `non-negotiable-rules.md` (no destructive git ops), did NOT use git rebase / reset to fix attribution. The fix-forward commit `f59c4ce fix(barrel): restore F-012 + F-013 exports lost in cross-lane race` reconciled the same race for sibling lanes. Proof artifacts committed in `0d4c84a docs(F-023): GREEN proof artifacts`.
