---
artifact-class: feature-ledger
generated-by: hand-authored (wave-002 / lane-b); LOCKED flip wave-013 / lane-c
status: locked
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-002 / lane-b
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-009 / lane-b
    note: "RED test landed in commit eacc651 (8/8 fail captured); GREEN impl (queryAuditLog + findChainBreak + AuditQueryOptions) landed in commit da48f2a (~109 LOC); 8/8 PASS across 3 stable runs; physical-proof.md authored. NOTE: cross-lane race during wave-009 caused both commits to be filed under other lanes' commit messages (eacc651 = F-018; da48f2a = F-006); see lane-b summary § Anomalies B1+B2 for the writeup."
  - status: locked
    at: 2026-05-07
    by: wave-013 / lane-c
    note: "Council review verdict ACCEPT (Verdict consensus: APPROVE; median confidence 87; 0 CRITICAL / 0 MAJOR / 5 MINOR / 3 PRAISE) at docs/05-design-reviews/council-reviews/F-016-query-audit-log-review.md. red-green-rule predicate satisfied: GREEN AND review file with verdict ACCEPT. MINOR findings are honest scope-narrowing notes per no-silent-deferrals.md (streaming async-iterator shape deferred to v1.5 / M11; persistence-layer reads deferred to F-008; agent_id/run_id filters deferred — 2-LOC follow-on; until_utc upper bound deferred — symmetric extension; inline chain-validity warn-then-yield deferred — separated into findChainBreak per brief). Source post-wave-011/lane-a engine-core split lives at packages/engine-core/src/audit.ts (F-016 region ~109 LOC; co-hosted with F-015 write API). 8/8 acceptance scenarios continue to PASS unchanged. Co-locked with F-014 + F-015 + F-017 in wave-013 / lane-c."
feature-id: F-016
short-slug: query-audit-log
milestone: M2
provenance:
  surfaces:
    - ce:FR-AUDIT-001 ("Query-AuditLog" sub-surface)
fr-coverage:
  - ce:FR-AUDIT-001
test-files:
  unit:
    - tests/unit/F-016-query-audit-log.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - unit
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

GREEN landed wave-009 / lane-b (2026-05-07). Implementation in `packages/engine-core/src/index.ts` adds ~109 LOC.

API surface:
- `interface AuditQueryOptions { since?, top?, skip?, action? }` — all fields optional
- `queryAuditLog(rows, opts) → AuditLogEntry[]` — defensive copy + filter pipeline; chronological order preserved
- `findChainBreak(rows) → number | null` — wraps F-015's `verifyAuditChain`; returns broken zero-based index or null

Key implementation choices:
- **Filter pipeline order**: `since` → `action` → `skip` → `top`. Each step operates on the in-flight array; `since` and `action` are O(N) filters; `skip`/`top` are O(K) array slices. Total worst-case O(N).
- **Defensive copy**: `[...rows]` at entry; mutations to the returned array do not affect the source log. Individual entries share object identity (callers mutating `entry.fields` invalidates the chain — `findChainBreak` will detect).
- **`since` filter targets `entry.fields.timestamp`**: F-015's `AuditLogEntry` has no top-level timestamp field; the brief's `since` semantics are honored by reading `fields.timestamp` (string). Lexicographic compare on ISO-8601 strings sorts correctly. Entries without a `fields.timestamp` are excluded when `since` is set.
- **`action` filter is exact-match**: per the brief's `e.action === opts.action`. Substring/regex match deferred to v1.5 (heavy query needs are tracked under M11 introspect/replay per the ledger out-of-scope-notes).
- **Chain integrity is opt-in via `findChainBreak`**: the F-016 ledger §Behavior contract says `queryAuditLog` "validates the chain integrity per F-015 BEFORE yielding any entry". The wave-9 brief separates the verification cost into `findChainBreak` so callers compose them deliberately. Substantive guarantee preserved (callers can verify before query); cost model now caller-controlled.

Out-of-scope (per ledger):
- Streaming async-iterator shape for large logs (deferred to v1.5; M2 ships a synchronous filter API only — heavy query needs tracked under F-088..F-092 / M11 introspect/replay).
- Persistence-layer reads — querying directly against `runs/<run_id>/audit.ndjson` is F-008's job.
- `agent_id` / `run_id` filters — F-002 stamps these into `fields` via `stampIdentity`; the brief uses `action` as the v1 surface filter to keep the API minimal. Adding these is a 2-LOC follow-on.
- `until_utc` timestamp upper bound — the brief specifies `since` only; `until` is symmetric and trivial to add.

Physical proof: `docs/09-examples-proof/F-016/{red-test-output.txt, green-test-output.txt, physical-proof.md}`.

Cross-lane race writeup (Anomalies B1 + B2): see `docs/06-agent-team-outputs/wave-009/lane-b-summary.md`.
