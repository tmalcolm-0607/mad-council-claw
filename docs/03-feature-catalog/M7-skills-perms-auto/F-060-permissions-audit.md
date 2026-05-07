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
feature-id: F-060
short-slug: permissions-audit
milestone: M7
provenance:
  surfaces:
    - foundational-plan:M7-skills-perms-auto
    - ce:FR-AUDIT-001
    - ce:FR-AUDIT-002
    - cp:electron/permission-policy.ts
    - cp:electron/permissions.ts
    - kit:rules/concurrency-safety.md
    - kit:rules/dangerous-operations-policy.md
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
  LOCKED if GREEN AND reviews/F-060-permissions-audit-review.md exists with verdict: ACCEPT.
depends-on: [F-015, F-058, F-059]
out-of-scope-notes: |
  3-tier classification is F-058; rules are F-059.
  Hash-chained audit log is F-015 (M2); this feature WRITES audit entries via that mechanism.
  PII redaction in audit body is F-017.
  Audit query UI is F-016 + M5 desktop shell info-panel (F-034).
  Per-automation audit linking is F-066; this feature owns the per-decision audit shape.
configurable: |
  Audit entries are append-only and immutable post-write per FR-AUDIT-001 + concurrency-safety §1.
confidence: high
---

# F-060 — Permissions audit

## Behavior contract

Every permission decision (ALLOW / ASK-resolved / DENY) writes an audit entry through the F-015 hash-chained audit log. Entry shape: `{ ts_utc, run_id, agent_id, decision, request: { kind, target, args_redacted }, matched_rule_id, policy_tier, prev_hash, this_hash }`. The args field is redacted via the F-017 PII-redaction layer before hashing. ASK-resolved entries additionally record `user_response: "approved" | "denied" | "timeout"` and the latency between prompt-emit and resolution. The audit is the authoritative record of what executed under whose authority — per canonical-e FR-AUDIT-001 + FR-AUDIT-002, the audit log is hash-chained and any tampering breaks the chain detectably.

## Acceptance scenarios

1. **Given** an ALLOW decision for `shell.git status`, **When** the engine logs the audit entry, **Then** `<state-dir>/audit/<run_id>.jsonl` gains a line with `decision: "ALLOW", matched_rule_id: "rule-1234", this_hash != prev_hash` AND the chain validates against F-015's hash-chain checker.
2. **Given** an ASK decision the user approves after 4.2s, **When** the engine logs, **Then** the entry records `decision: "ASK", user_response: "approved", latency_ms: 4200`.
3. **Given** an attacker edits a past audit entry's `decision` from `DENY` to `ALLOW`, **When** the F-015 chain checker runs, **Then** the chain is reported broken at that index AND a `red badge + banner` event is emitted (per F-034 info-panel surface).

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/integration/permissions/audit-allow-entry-shape.test.ts` | integration | RED | scenario 1 |
| (TBD) `tests/integration/permissions/audit-ask-records-response.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/integration/permissions/audit-tamper-breaks-chain.test.ts` | integration | RED | scenario 3 |

## Dependencies

- **Hard:** F-015 (hash-chained audit log this feature writes through), F-058 (decisions to record), F-059 (matched rule IDs to record)
- **Soft:** F-017 (PII redaction applied before hashing), F-016 (query-audit consumes these entries), F-034 (info-panel surfaces chain-broken state)
- **Independent:** F-051..F-057, F-061..F-066

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:M7-skills-perms-auto | "audit" is item 10 of the M7 catalog list |
| ce:FR-AUDIT-001 | Hash-chain audit-log requirement |
| ce:FR-AUDIT-002 | Tamper-detection requirement |
| cp:electron/permission-policy.ts | Site of the decision the audit records |
| cp:electron/permissions.ts | Reference persistence pattern |
| kit:rules/concurrency-safety.md §1 | Audit entries are append-only |
| kit:rules/dangerous-operations-policy.md | Every consent gate writes to consent-log.jsonl — generalized here as audit log |

## Implementation notes

(empty — populated when implementation begins)
