---
artifact-class: feature-ledger
generated-by: hand-authored (wave-004 / lane-a)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-004 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-047
short-slug: tool-call-audit
milestone: M6
provenance:
  surfaces:
    - ce:US-6
    - ce:FR-AUDIT-001
    - ce:FR-QUOTA-001
    - ce:tool_calls_exhausted
    - ce:QUOTA_EXCEEDED_TOOL_CALLS
    - cp:electron/tool-discovery.ts
    - cp:common/tool-registry.ts
    - kit:rules/verification-protocol.md
    - kit:rules/prompt-injection-policy.md
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
  LOCKED if GREEN AND reviews/F-047-tool-call-audit-review.md exists with verdict: ACCEPT.
depends-on: [F-006, F-015, F-017, F-022, F-044]
out-of-scope-notes: |
  Query-AuditLog UX for tool calls is F-016 (the same query interface; this ledger only WRITES).
  Cost attribution per tool call (when backend exposes per-tool cost) is F-019.
  Multi-model adversarial review of audit-log integrity is M10 (F-082..F-087).
  Live trace timeline UI for tool-call sequence is M11+M12 (F-088..F-095).
confidence: high
---

# F-047 — Tool-call audit

## Behavior contract

Every tool invocation through the MCP bridge (per F-044) appends a hash-chained entry to the active run's audit log (per F-015). Entry shape: `tool_name`, `server_id`, `args_sha256` (sha256 of arg JSON), `result_sha256` (sha256 of full result; populated when call completes), `started_utc`, `completed_utc`, `outcome` (`success` | `tool_error` | `cancelled` | `quota_blocked` | `flagged_suspicious`), `prev_entry_sha256` (chain pointer per F-015). The audit MUST emit BEFORE the call dispatches to the server (so even cancellations are recorded), and a follow-up update entry records the outcome — both entries are themselves chained per F-015. PII redaction (per F-017) runs on `args` BEFORE sha256 + persist. The tool-quota gate (per F-022 / `ce:FR-QUOTA-001`) runs BEFORE the audit emits the start entry; calls blocked by quota produce a single `outcome: quota_blocked` entry and never reach the bridge. Suspicious tool descriptions (per `kit:rules/prompt-injection-policy.md` Rule 1) are flagged at registration time; tool calls to those tools still execute but the audit entry carries `flagged_suspicious: true`.

## Acceptance scenarios

1. **Given** an in-flight run that calls `read_file({ path: "/tmp/x.txt" })` against the bundled filesystem MCP server, **When** the call begins, **Then** the audit log gains a `started` entry with `tool_name="read_file"`, `args_sha256` matching `sha256(JSON.stringify({path:"/tmp/x.txt"}))`, `started_utc` populated, and `prev_entry_sha256` chained to the prior entry per F-015 — verifiable by the F-016 query path.
2. **Given** a tool call cancelled mid-execution by the kill-switch (per F-020), **When** the cancel propagates, **Then** a `completed` entry is appended with `outcome: cancelled` + `completed_utc` + `result_sha256: sha256("")` (empty result on cancel) — the chain remains unbroken, queryable via F-016.
3. **Given** a run that has consumed its tool-call quota (per F-022 / `ce:FR-QUOTA-001`), **When** the next tool call is attempted, **Then** the audit emits a single `outcome: quota_blocked` entry, the bridge does NOT dispatch, the run terminates with `tool_calls_exhausted` per `ce:tool_calls_exhausted`, and the failure mode tag matches `ce:QUOTA_EXCEEDED_TOOL_CALLS`.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/mcp/audit-chain-on-success.test.ts` | integration | RED — chain integrity | scenario 1 |
| (TBD) `tests/integration/mcp/audit-chain-on-cancel.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/mcp/audit-quota-block-precedes-dispatch.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-006 (logger writes the audit log), F-015 (hash-chain primitive), F-017 (PII redaction in args), F-022 (tool-quota gate runs before audit), F-044 (bridge is the dispatch point)
- **Soft:** F-016 (Query-AuditLog reads what this writes), F-018 (3-consecutive `tool_error` halt counts these outcomes), F-019 (per-tool cost attribution if backend exposes), F-020 (kill-switch produces `cancelled` outcomes)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:US-6 | Skills/MCP allowlist user story (audit is the verification surface) |
| ce:FR-AUDIT-001 | Hash-chained audit log primitive |
| ce:FR-QUOTA-001 | Per-spawn tool count quota — pre-audit gate |
| ce:tool_calls_exhausted | Run-end reason when quota consumed |
| ce:QUOTA_EXCEEDED_TOOL_CALLS | Failure mode tag |
| cp:electron/tool-discovery.ts | Tool catalog source for sanitization |
| cp:common/tool-registry.ts | Tool-schema normalization |
| kit:rules/verification-protocol.md | ACTUAL BEFORE PRESENT — outcomes are persisted, never inferred |
| kit:rules/prompt-injection-policy.md | Rule 3 (flag suspicious content inline; don't redact) |

## Implementation notes

(empty — populated when implementation begins)
