---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b)
status: green
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-010 / lane-c
    note: "RED test landed at tests/unit/F-022-tool-call-quota.test.ts (8/8 fail captured); GREEN impl ToolCallQuota class + 'tool_calls' HaltTrigger value landed in packages/engine-core/src/index.ts (~135 LOC F-022 region + 1-line union edit). 8/8 PASS. Verdict shape reuses F-018 RunHaltedVerdict; trigger='tool_calls' distinguishes per-spawn quota from F-018's global 'tool_calls_quota'. Both feed F-014's halted_by_tool_quota retro outcome. NOTE: cross-lane staging race during wave-010 — F-022 RED files were absorbed into commit f142eb1 (test(F-020)) and F-022 GREEN impl into commit 9163d95 (feat(F-008)); same Anomaly A1 pattern documented in wave-009/lane-c. Substance preserved (HEAD has the work; tests pass); audit-trail names scrambled. See lane-c-summary §A1 for writeup. Out of scope per ledger: max_calls_per_run + max_tools_active (M7), F-006 logger surfacing, F-015 audit-evidence binding."
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
  unit:
    - tests/unit/F-022-tool-call-quota.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - unit
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

| Test file | Project | State | Verifies |
|---|---|---|---|
| `tests/unit/F-022-tool-call-quota.test.ts` | unit | GREEN | scenarios 1, 2, 3 + 5 extended (reset, resetAll, getCount=0, default=50, per-agent isolation) |

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

GREEN landed wave-010 / lane-c (2026-05-07). Implementation in `packages/engine-core/src/index.ts` adds ~135 LOC F-022 region + 1-line `HaltTrigger` union extension (added `'tool_calls'` value).

API surface:
- `class ToolCallQuota` — constructor `new ToolCallQuota(maxPerAgent = 50)`; methods `recordCall(agentId): RunHaltedVerdict | null`, `getCount(agentId): number`, `reset(agentId): void`, `resetAll(): void`.
- Reuses F-018's `RunHaltedVerdict` shape; emits `trigger: 'tool_calls'` (new `HaltTrigger` value) to distinguish per-spawn quota from F-018's global `'tool_calls_quota'`.

Key implementation choices:
- **Per-agent counter via `Map<string, number>`**: independent counters keyed by `agent_id`. Agent A's calls do not count against agent B's quota (ledger scenario 2).
- **Increment-before-check**: counter increments BEFORE the threshold compare so the verdict's `reason` reports the actual breach value (e.g. "51 > 50") for precise audit anchoring.
- **Coexists with F-018 global counter**: F-018's `HaltDetector.recordToolCall()` catches runaway global usage; F-022's `ToolCallQuota.recordCall()` catches per-spawn quota exhaustion. Both feed F-014's `halted_by_tool_quota` retro outcome (already in `RetroOutcome` enum — no F-014 changes needed).
- **No automatic decay**: counters are monotonic per-agent until `reset(agentId)` (per-spawn end) or `resetAll()` (run boundary). Per-cycle quotas (max_calls_per_cycle from ledger) would compose `reset` at F-001's cycle-boundary — out of scope for this flip.
- **Reset semantics**: `reset(agentId)` clears one agent (no-op when unseen); `resetAll()` clears every agent.

Out-of-scope (per ledger §out-of-scope-notes + wave-10 brief):
- `max_calls_per_run` (1000 default) and `max_tools_active` (10 default) — mentioned in ledger Behavior contract but wave-10 brief scopes F-022 to per-spawn (per agent_id) cap only. M7 owns skill-allowlist + version-pinning.
- F-006 logger surfacing of QUOTA_EXCEEDED events — F-022 emits the verdict; F-006 routes it.
- F-015 audit-evidence binding for `trigger_evidence_sha256` — field is optional in the verdict shape; binding to a real audit row is F-015's integration step.
- F-008 storage layout — F-022 keeps quota state in memory; persistence is F-008's job.

Physical proof: `docs/09-examples-proof/F-022/{red-test-output.txt, green-test-output.txt, physical-proof.md}`.

Cross-lane race writeup (Anomaly A1): see `docs/06-agent-team-outputs/wave-010/lane-c-summary.md`.
