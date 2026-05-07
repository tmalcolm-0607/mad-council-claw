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
    by: wave-008 / lane-b
    note: "RED test landed in commit 3d91a72 (4/4 fail captured); GREEN impl + AuditLogEntry rename to avoid collision with F-001's AuditEntry; 4/4 PASS across 3 stable runs; physical-proof.md authored"
feature-id: F-015
short-slug: hash-chained-audit-log
milestone: M2
provenance:
  surfaces:
    - ce:FR-AUDIT-001
    - ce:FR-AUDIT-002
    - kit:rules/concurrency-safety.md (append-only)
fr-coverage:
  - ce:FR-AUDIT-001
test-files:
  unit:
    - tests/unit/F-015-hash-chained-audit-log.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - unit
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-015-hash-chained-audit-log-review.md exists with verdict: ACCEPT.
depends-on: [F-001, F-002, F-008]
out-of-scope-notes: |
  Cryptographic signing of audit entries (third-party timestamping) is deferred
  to v1.5 per ce:FR-IDENTITY-002. This feature implements SHA-256 chaining only —
  detects tampering, does not prevent it cryptographically.
confidence: high
---

# F-015 — Hash-chained audit log

## Behavior contract

Every audit entry includes `prev_sha256` and `entry_sha256` fields. `prev_sha256` is the `entry_sha256` of the immediately preceding entry in the same run (or `"GENESIS"` for the first entry). `entry_sha256 = sha256(canonical_json(entry_without_entry_sha256))`. The audit log lives at `runs/<run_id>/audit.ndjson` and is append-only (never rewritten). A `Verify-AuditChain` operation walks the log and reports the first index where `prev_sha256` mismatch is detected — pointing precisely at the tampered entry. Repair-from-backup is supported per `FR-AUDIT-002`.

## Acceptance scenarios

1. **Given** an empty audit log, **When** the first entry is appended, **Then** `prev_sha256 === "GENESIS"` and `entry_sha256` is a valid 64-hex SHA-256.
2. **Given** an audit log with N entries, **When** a developer manually edits entry K's `fields.cycle` value, **Then** `Verify-AuditChain` returns `{valid: false, broken_at: K, reason: "entry_sha256 mismatch"}`.
3. **Given** an audit log with valid chain entries 1..M, **When** entry M+1 is appended via the writer (which computes `prev_sha256` from M's `entry_sha256`), **Then** the chain remains valid for entries 1..M+1.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/audit/genesis-entry.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/integration/audit/tamper-detection.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/audit/append-keeps-chain.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-001 (engine produces entries), F-002 (identity stamps every entry), F-008 (storage layout)
- **Soft:** F-006 (logger pipeline is the upstream)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-AUDIT-001 | Hash-chained audit log + Query-AuditLog |
| ce:FR-AUDIT-002 | Repair / restore from backup pathway |
| kit:rules/concurrency-safety.md | Append-only message-file pattern (§1) |

## Implementation notes

GREEN landed wave-008 / lane-b (2026-05-07). Implementation in `packages/engine-core/src/index.ts` adds ~165 LOC.

API surface:
- `GENESIS_SENTINEL = 'GENESIS' as const` — exported sentinel
- `interface AuditLogEntry { cycle, action, fields, prev_sha256, entry_sha256 }` — renamed from brief's `AuditEntry` to avoid silent TypeScript declaration-merging with F-001's transient `AuditEntry { cycle, hash, state }`. The two shapes serve different audiences: F-001's is the run-bootstrap cycle audit kept in `RunResult.audit`; F-015's is the durable audit log row destined for `runs/<run_id>/audit.ndjson`.
- `interface AuditLogEntryInput { cycle, action, fields }` — caller-facing shape minus the chain fields the writer fills in
- `type VerifyAuditChainResult = {valid:true} | {valid:false, broken_at:number, reason: 'entry_sha256 mismatch'|'prev_sha256 mismatch'}` — discriminated union; two failure modes reported separately
- `appendAuditEntry(log, input) → AuditLogEntry` — append-only; mutates log; returns sealed entry
- `verifyAuditChain(log) → VerifyAuditChainResult` — walks chain once; O(N); reports first failure with zero-based index

Key implementation choices:
- **Canonical JSON**: recursive key-sorted serializer (lightweight; sufficient for v1's free-form `fields` payload). RFC 8785 (JCS) precision deferred to v1.5 if cross-language verification is ever needed.
- **`broken_at` indexing**: zero-based array position (matches `log[i]` calls and ndjson row offsets that a repair tool would seek to). Documented inline with the `VerifyAuditChainResult` type so storage-layer consumers can rely on it.
- **Order of failure-mode checks**: `entry_sha256 mismatch` is reported FIRST per entry. If both fail, the user sees the more specific signal. (In scenario 4 — tampering with `prev_sha256` — the entry_sha256 also breaks because prev_sha256 is part of the hash input, so entry_sha256 mismatch fires at the tampered index.)

Out-of-scope (per ledger):
- Cryptographic signing of audit entries (deferred to v1.5 per ce:FR-IDENTITY-002; tracked in F-D-005).
- Persistence to `runs/<run_id>/audit.ndjson` (F-008's job).
- Logging-pipeline wiring that emits engine cycle events through `appendAuditEntry` (F-006's job).
- Repair-from-backup (per ce:FR-AUDIT-002) — `verifyAuditChain` pinpoints the broken index; the repair tool that splices in a backup row is a follow-on feature.

Physical proof: `docs/09-examples-proof/F-015/{red-test-output.txt, green-test-output.txt, physical-proof.md}`.
