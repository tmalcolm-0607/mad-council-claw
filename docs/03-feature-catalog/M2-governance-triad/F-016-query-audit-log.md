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
feature-id: F-016
short-slug: query-audit-log
milestone: M2
provenance:
  surfaces:
    - ce:FR-AUDIT-001 ("Query-AuditLog" sub-surface)
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
  LOCKED if GREEN AND reviews/F-016-query-audit-log-review.md exists with verdict: ACCEPT.
depends-on: [F-015]
out-of-scope-notes: |
  Full-text search + indexed pagination across thousands of runs is deferred —
  M2 ships a streaming filter API only. Heavy query needs are tracked under
  F-088..F-092 (M11 introspect/replay) where they belong.
confidence: high
---

# F-016 — Query-AuditLog API

## Behavior contract

`queryAuditLog({run_id, agent_id?, event_name?, since_utc?, until_utc?, limit?})` returns an async iterator yielding matching entries in chronological order. It validates the chain integrity per F-015 BEFORE yielding any entry; if the chain is broken, it yields one `chain_invalid` warning event and the broken-at index, then continues yielding remaining valid entries. The API is read-only; it never mutates the log. Streaming shape lets consumers process large logs without loading into memory.

## Acceptance scenarios

1. **Given** an audit log with 100 entries from 2 agents, **When** `queryAuditLog({run_id, agent_id: "a1"})` is iterated, **Then** only entries with `agent_id: "a1"` are yielded, in chronological order.
2. **Given** a log with broken chain at index 50, **When** the query is iterated, **Then** the first yielded item is `{type: "chain_invalid", broken_at: 50}` and subsequent yields continue but the consumer has been warned.
3. **Given** a query with `limit: 10`, **When** iterated to exhaustion, **Then** at most 10 matching entries are yielded.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/audit/query-filters.test.ts` | unit | RED | scenarios 1, 3 |
| (TBD) `tests/integration/audit/query-broken-chain.test.ts` | integration | RED | scenario 2 |

## Dependencies

- **Hard:** F-015 (audit log to query)
- **Soft:** F-002 (identity-based filters)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-AUDIT-001 | "Query-AuditLog" companion to hash-chained audit log |

## Implementation notes

(empty — populated when implementation begins)
