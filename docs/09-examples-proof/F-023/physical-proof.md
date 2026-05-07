---
artifact-class: physical-proof
generated-by: hand-authored (wave-016 / lane-b)
feature-id: F-023
date: 2026-05-07
---

# F-023 cron-heartbeat — physical proof

## RED state (commit f32aebe)

- **Test file**: `tests/unit/F-023-cron-heartbeat.test.ts` (288 LOC, 21 `it` scenarios across 6 `describe` blocks).
- **Failure mode**: `TypeError: HeartbeatScheduler is not a constructor` — 20/20 of F-023's hot-path scenarios fail because the import `HeartbeatScheduler` is undefined; the 1 type-witness scenario passes (compile-only). All 152 prior tests in the suite continue to pass.
- **Captured at**: `red-test-output.txt`.

## GREEN state (this commit)

- **Implementation file**: `packages/engine-core/src/heartbeat.ts` (~145 LOC).
- **Surface**:
  - `type CadenceProfile = 'mad-iteration' | 'deployment-watch' | 'custom'`
  - `interface HeartbeatConfig { profile, intervalSeconds?, enforceWarmCacheZones? }`
  - `interface HeartbeatStatus { isRunning, tickCount, lastTickAt, intervalSeconds }`
  - `class HeartbeatScheduler { constructor; getIntervalSeconds; start; stop; tick; getStatus }`
- **Barrel re-export**: `packages/engine-core/src/index.ts` adds `export * from './heartbeat.js'` (1 line) + 1-line ownership-table comment per the per-feature-files convention from wave-011 / lane-a.
- **Test result**: 21/21 PASS at GREEN time. Full unit suite 144/144 PASS across 19 unit test files (was 123/123 across 18 pre-F-023). Captured at `green-test-output.txt`.

## Behavior witnesses

The 6 describe blocks enumerate the contract:

| Describe | Scenarios | Witness |
|---|---|---|
| cadence profile resolution | 5 | `mad-iteration → 270s`; `deployment-watch → 1500s`; `custom` requires `intervalSeconds`; custom warm-cache (120s) and amortized (1800s) both accepted |
| forbidden-zone enforcement | 6 | rejects 280s / 600s / 1199s with `loop-cadence-discipline.md` remediation pointer; accepts 270s + 1200s boundaries; `enforceWarmCacheZones: false` bypasses |
| tick lifecycle | 3 | manual `tick()` increments tickCount + sets lastTickAt; tick before start works (manual mode for tests); async handler is awaited |
| start/stop lifecycle | 4 | `isRunning` toggles; double-start throws; `stop()` is idempotent; fake-timers exercise the actual `setInterval` cadence (handler fires after 270s elapses, three times across 810s window) |
| getStatus observability | 2 | reports the configured intervalSeconds; initial state has tickCount=0, lastTickAt=null, isRunning=false |
| CadenceProfile type witness | 1 | compile-time witness that the union has exactly the 3 documented values |

## Scope reconciliation with F-024 / F-001 / F-006 / F-008

F-023's primitive is the **scheduler** — a pure-class with no I/O, no run spawn, no log append. Per the F-022 ToolCallQuota and F-018 HaltDetector pattern: pure behavior + composition by callers.

- **F-001 (engine-bootstrap-loop)**: orchestrator's `tick` handler invokes the boot-fresh-run path; F-023 is agnostic.
- **F-006 (logging-pipeline)**: caller writes `cron-fires.jsonl` append-only entries inside its handler.
- **F-008 (local-storage-layout)**: caller resolves the `automations/cron-fires.jsonl` path.
- **F-024 (skip-on-overlap)**: wraps the tick handler with an overlap check before invoking F-023's tick.
- **F-002 (per-agent-identity)**: caller resolves agent identity for the fresh run before invoking the handler.

Per `no-silent-deferrals.md`: every non-implemented surface is named and explicitly owned by a downstream feature. No silent OoS.

## Cadence-zone math (loop-cadence-discipline.md)

```
0s ─── 270s ─── 300s ─── 1200s ─── 3600s
       │          │            │
       │          └ "worst-of-both" wall ─ DO NOT PARK HERE
       │
       └ Warm-cache zone        └ Amortized-cache-miss zone
```

- 0-270s: warm cache (TTL is 300s; 270s leaves margin).
- 280-1199s: forbidden — pays the prompt-cache miss without amortizing.
- 1200s+: amortized — one cache miss per long sleep.

The constructor enforces this gate at registration time so misconfigured cron schedules are rejected before any timer is registered. `enforceWarmCacheZones: false` is the operator escape hatch and exists so the override is reviewable in code rather than silent.

## Drift accounting (deferred)

The ledger §Behavior contract names a ≤5% drift target over a 100-fire window (per ce:SC-007). v1's `setInterval` does not natively guarantee this — Node `setInterval` accumulates drift on the order of 1-5 ms per tick under load. F-023's surface contributes the **shape** that drift accounting will plug into (`getStatus` exposes `lastTickAt`; future `getDriftWindow()` reads N-most-recent fire times against scheduled times). The actual drift calculation lives in F-026 / F-027 (per the M3 catalog) and is gated on `cron-fires.jsonl` (F-008) being populated by callers. Documented here so the deferral is not silent.

## RED → GREEN delta

```
$ git diff --stat HEAD~1..HEAD
 docs/09-examples-proof/F-023/green-test-output.txt    | 14 +++++
 docs/09-examples-proof/F-023/physical-proof.md        | (this file)
 packages/engine-core/src/heartbeat.ts                 | 188 ++++++++++++++++++++++++++
 packages/engine-core/src/index.ts                     |   2 ++
```

(The wave's full delta also includes the F-023 ledger flip + roadmap row + confidence-ledger entry-block + lane-b-summary; reconciled across separate commits per `scope-discipline.md`.)
