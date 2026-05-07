---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: red
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-002
short-slug: per-agent-identity-runid
milestone: M0
provenance:
  surfaces:
    - ce:FR-IDENTITY-001
    - kit:rules/single-owner-accountability.md
    - cp:src/agents/identity
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
  LOCKED if GREEN AND reviews/F-002-per-agent-identity-runid-review.md exists with verdict: ACCEPT.
depends-on: [F-001]
out-of-scope-notes: |
  Cryptographic spawn signing + Entra principal-binding deferred to v1.5 per
  ce:FR-IDENTITY-002 / FR-IDENTITY-003 (tracked in M19 deferred catalog).
  This feature implements run_id + agent_id + parent_run_id correlation chain only.
confidence: high
---

# F-002 — Per-agent identity & run_id correlation

## Behavior contract

Every agent action is stamped with a triple `{run_id, agent_id, parent_run_id}`. `run_id` is allocated at engine boot (UUID v7, time-ordered). `agent_id` is allocated per spawned agent. `parent_run_id` is set when an agent is spawned from another agent's context, forming a correlation chain. The triple is non-optional on every audit entry, every cost-ledger row, and every IPC message; missing-identity writes are rejected at the audit-writer boundary. Cryptographic spawn signing is explicitly deferred (v1.5).

## Acceptance scenarios

1. **Given** the engine boots, **When** it allocates the root `run_id`, **Then** the value is a valid UUID v7 (time-ordered) AND is written to `runs/<run_id>/manifest.json`.
2. **Given** agent A (id=`a1`) spawns agent B, **When** agent B emits its first audit entry, **Then** the entry carries `parent_run_id = <run_id of A>` and a fresh `agent_id` distinct from `a1`.
3. **Given** an audit-write call without an `agent_id`, **When** the audit writer is invoked, **Then** the call rejects with `IDENTITY_MISSING` and no entry is appended.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/identity/uuid-v7.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/unit/identity/correlation-chain.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/unit/identity/missing-identity-rejection.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine kernel must exist for identity to attach to)
- **Soft:** F-006 (logging pipeline consumes identity), F-008 (storage layout for `runs/<run_id>/`)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-IDENTITY-001 | run_id + agent_id + parent_run_id correlation chain |
| kit:rules/single-owner-accountability.md | owner-of-record discipline; identity is the substrate |
| cp:src/agents/identity | clawpilot per-agent identity allocator pattern |

## Implementation notes

(empty — populated when implementation begins)
