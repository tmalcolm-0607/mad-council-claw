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
feature-id: F-022
short-slug: tool-quota
milestone: M2
provenance:
  surfaces:
    - kit:foundational-plan.md "tool-quota" surface
    - kit:rules/mcp-tiering.md
    - ce:FR-GOV-001 (allowlist) related-but-distinct
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
  LOCKED if GREEN AND reviews/F-022-tool-quota-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-002]
out-of-scope-notes: |
  Per-workspace tool-cap default of 10 tools (F-125 NEW frontier-research candidate)
  is the policy layer; this feature is the enforcement primitive — count + quota +
  rejection. Skill-allowlist + version-pinning are owned by M7 (F-051..F-066).
confidence: high
---

# F-022 — Per-agent tool-call quota

## Behavior contract

Every tool invocation an agent makes is counted against per-agent quotas: `max_calls_per_cycle` (default 50), `max_calls_per_run` (default 1000), `max_tools_active` (default 10 per `mcp-tiering.md`). When any quota is reached, further tool calls from that agent reject with `QUOTA_EXCEEDED: <quota_name>` and the rejection is logged to the audit chain. Quotas are per-agent (agent A and agent B have independent counters within the same run) and run-scoped (counters reset on new run). The user can override per-run via config; see `no-invented-constraints.md` — defaults exist but are documented and overridable.

## Acceptance scenarios

1. **Given** an agent with `max_calls_per_cycle: 5`, **When** the agent makes the 6th tool call within one cycle, **Then** the call rejects with `QUOTA_EXCEEDED: max_calls_per_cycle` and the audit log records the rejection.
2. **Given** two agents A and B in the same run, A having exhausted its `max_calls_per_run`, **When** agent B makes a tool call, **Then** B's call succeeds (per-agent counters are independent).
3. **Given** a run config override `max_tools_active: 20`, **When** an agent activates 15 tools simultaneously, **Then** all 15 succeed (override wins over default 10).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/quota/per-cycle-cap.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/integration/quota/per-agent-isolation.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/quota/config-override.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (cycle boundaries reset per-cycle counters), F-002 (per-agent counters keyed on agent_id)
- **Soft:** F-015 (audit log records rejections), F-018 (repeated rejections may trigger halt)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md M2 | "tool-quota" surface |
| kit:rules/mcp-tiering.md | tool-tier classification + max-active default of 10 |
| ce:FR-GOV-001 | allowlist (related; this feature is quotas) |

## Implementation notes

(empty — populated when implementation begins)
