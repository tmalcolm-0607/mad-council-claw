---
artifact-class: feature-ledger
generated-by: hand-authored (wave-004 / lane-b)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-004 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-063
short-slug: automations-condition-type
milestone: M7
provenance:
  surfaces:
    - foundational-plan:M7-skills-perms-auto
    - cp:electron/automations/condition-monitor.ts
    - cp:electron/automations/triggering.ts
    - kit:rules/anomaly-thresholds.md
    - kit:rules/concurrency-safety.md
fr-coverage: []
test-files:
  unit: []
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects: []
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-063-automations-condition-type-review.md exists with verdict: ACCEPT.
depends-on: [F-061]
out-of-scope-notes: |
  Cron-typed triggers are F-062; multistep chaining is F-064.
  The condition-types in v1: file-watch (path glob), event-bus (engine internal event name), idle (no activity for N seconds).
  External webhook triggers (HTTP POST from the outside) are OUT OF SCOPE for v1; map to a future F-NNN.
  Conditions polling more frequently than 5 seconds are rejected per anomaly-thresholds (avoid CPU drain).
configurable: |
  File-watch implementation uses the OS-native watcher (chokidar-class) — no polling.
  Event-bus condition matches by event name + optional predicate (Zod-schema-typed).
confidence: high
---

# F-063 — Automations condition-type trigger

## Behavior contract

An automation with `trigger: { type: "condition", condition: <typed-condition> }` registers with a condition-monitor (per `condition-monitor.ts`-style). Three condition kinds are supported in v1: `file-watch` (`{ kind: "file-watch", paths: glob[] }`) — fires when any matching file is created/modified/deleted; `event-bus` (`{ kind: "event-bus", event: string, predicate?: ZodSchema }`) — fires when the engine emits a matching event with a payload satisfying the optional predicate; and `idle` (`{ kind: "idle", seconds: number }`) — fires after N seconds of no engine activity. Condition triggers cannot fire faster than 5 seconds apart for the same automation (debounce floor); rapid re-fires are coalesced into one execution. The condition monitor runs in the engine kernel (F-001), not in the renderer, so it survives window close.

## Acceptance scenarios

1. **Given** an automation `{ trigger: { type: "condition", condition: { kind: "file-watch", paths: ["**/*.md"] } }, ... }`, **When** a `.md` file is saved in the workspace, **Then** the automation's steps execute and a run record appears in history.jsonl.
2. **Given** an automation `{ trigger: { type: "condition", condition: { kind: "event-bus", event: "halt.triggered" } } }`, **When** the engine emits `halt.triggered` from F-018, **Then** the automation fires.
3. **Given** a file-watch automation receives 50 file-modify events in 2 seconds, **When** the monitor processes, **Then** the automation executes ONCE (debounced) AND the coalesced event count is recorded `{ run_id, coalesced_event_count: 50 }`.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/automations/condition-file-watch.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/automations/condition-event-bus.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/automations/condition-debounce.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-061 (automations base — this is a trigger type)
- **Soft:** F-018 (halt event is a common event-bus condition target), F-058 (steps still classified by perms)
- **Independent:** F-051..F-057, F-062 (different trigger type)

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M7-skills-perms-auto | "condition" is item 13 of the M7 catalog list |
| cp:electron/automations/condition-monitor.ts | Reference condition monitor pattern |
| cp:electron/automations/triggering.ts | Trigger dispatch with debounce |
| kit:rules/anomaly-thresholds.md | Excessive-fire detection pauses runaway condition automations |
| kit:rules/concurrency-safety.md | Coalescing + atomic run-record write |

## Implementation notes

(empty — populated when implementation begins)
