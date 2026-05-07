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
feature-id: F-061
short-slug: automations-base
milestone: M7
provenance:
  surfaces:
    - foundational-plan:M7-skills-perms-auto
    - cp:electron/automations/manager.ts
    - cp:electron/automations/types.ts
    - cp:electron/automations/schemas.ts
    - cp:electron/automations.ts
    - cp:src/features/automations/AutomationsPanel.tsx
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
  LOCKED if GREEN AND reviews/F-061-automations-base-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-007, F-008]
out-of-scope-notes: |
  Cron-type schedule trigger is F-062.
  Condition-type trigger (file-watch, event-bus) is F-063.
  Multistep automation chaining is F-064.
  Persistence across restarts is F-065.
  Results visible in shell are F-066.
  Per-automation permissions are also F-066 (split per the foundational-plan list: "automations base + cron + condition + multistep + persist + shell-visible" — 6 items mapping to F-061..F-066).
  Marketplace import-from-GitHub is `cp:src/features/automations/GithubImportView.tsx` reference; not in v1 scope per foundational plan but capability flag in the contract.
configurable: |
  Type contract derived from Zod schemas per refactor d8056042 in clawpilot.
confidence: high
---

# F-061 — Automations base

## Behavior contract

An automation is a typed object `{ id, name, trigger, steps, enabled, capabilities, source: "user" | "github-import" | "bundled" }` defined by Zod schemas (the schema is source-of-truth; types are inferred). The engine exposes a manager (`automations.manager`-style) that creates, updates, deletes, lists, and triggers automations. Manager state is written to `<state-dir>/automations/store.json` atomically. Every automation supports a "Run Now" capability flag (`AutomationCapabilities.heartbeatRunNow`-equivalent) so an operator can manually trigger the steps once for testing without involving the trigger. Automations are PURE DATA at this layer — F-061 owns shape + manager + run-now; trigger semantics (cron, condition) and step execution (single, multistep) live in dedicated downstream features.

## Acceptance scenarios

1. **Given** a created automation `{ id: "auto-1", name: "Daily summary", trigger: { type: "manual" }, steps: [{ kind: "skill-invoke", skill: "loop", args: {...} }], enabled: true }`, **When** persisted, **Then** `<state-dir>/automations/store.json` contains the entry AND `manager.list()` returns it.
2. **Given** an existing automation `auto-1`, **When** `manager.runNow({ id: "auto-1" })` is called, **Then** the steps execute under the engine's normal IPC + permission pipeline AND a run record `{ id, automation_id, status: "succeeded" | "failed", started_utc, finished_utc }` is appended to `<state-dir>/automations/history.jsonl`.
3. **Given** an automation submitted with `steps: []` (empty), **When** validation runs, **Then** the manager rejects with `AUTOMATION_STEPS_EMPTY` and the entry is NOT persisted.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/automations/base-create-list.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/automations/base-run-now.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/automations/base-empty-steps-rejection.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine kernel hosts the manager), F-007 (IPC contract surfaces CRUD + run-now), F-008 (storage layout for `<state-dir>/automations/`)
- **Soft:** F-058 (permission tier classifies steps before they execute)
- **Independent:** F-051..F-057 (skills are common step targets but the link is via step type, not direct dependency)

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M7-skills-perms-auto | "automations base" is item 11 of the M7 catalog list |
| cp:electron/automations/manager.ts | Manager pattern + run-now capability |
| cp:electron/automations/types.ts | Type contract derived from Zod (types-from-schema discipline) |
| cp:electron/automations/schemas.ts | Zod schemas — single source of truth for shape |
| cp:electron/automations.ts | Top-level glue surface |
| cp:src/features/automations/AutomationsPanel.tsx | UI surface for CRUD + history |
| kit:rules/concurrency-safety.md | Atomic store.json writes + append-only history.jsonl |

## Implementation notes

(empty — populated when implementation begins)
