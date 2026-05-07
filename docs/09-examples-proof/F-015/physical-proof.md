---
artifact-class: physical-proof
generated-by: wave-008 / lane-b
feature-id: F-015
date: 2026-05-07
status: green
---

# F-015 — Physical proof

Fourth feature transition RED → GREEN in the repo (after F-001 in wave-005, F-002 in wave-006, F-014 in wave-008 / lane-a). This file binds the F-015 ledger's three behavior contract acceptance scenarios (plus a bonus tamper-prev_sha256 scenario) to actual vitest output, per Goal G27 (full behavior tests + physical proof) and the wiki contribution protocol.

## Acceptance scenarios → test results

| # | Scenario (verbatim from ledger) | Vitest test name | Result |
|---|---|---|---|
| 1 | Given an empty audit log, When the first entry is appended, Then `prev_sha256 === "GENESIS"` and `entry_sha256` is a valid 64-hex SHA-256. | scenario 1: first entry on empty log has prev_sha256 === GENESIS and 64-hex entry_sha256 | ✓ PASS |
| 2 | Given an audit log with N entries, When a developer manually edits entry K's `fields.cycle` value, Then `Verify-AuditChain` returns `{valid: false, broken_at: K, reason: "entry_sha256 mismatch"}`. | scenario 2: tampering with entry K invalidates chain with precise broken_at index | ✓ PASS |
| 3 | Given an audit log with valid chain entries 1..M, When entry M+1 is appended via the writer (which computes `prev_sha256` from M's `entry_sha256`), Then the chain remains valid for entries 1..M+1. | scenario 3: appending M+1 to a valid 1..M chain keeps the chain valid | ✓ PASS |
| (bonus) | Tampering with `prev_sha256` chain link also invalidates verification at the same index — exercises the second `verifyAuditChain` failure mode (`prev_sha256 mismatch` reason) and confirms the entry_sha256 seal also catches the change because prev_sha256 is part of the hash input. | scenario 4: tampering with prev_sha256 also invalidates with prev_sha256 reason | ✓ PASS |

## Scope deviations from ledger (intentional, documented)

The F-015 ledger references `runs/<run_id>/audit.ndjson` as the on-disk format. F-015's wave-008 / lane-b minimal flip implements the **in-memory chain primitives** that the storage layer will compose against:

- `appendAuditEntry(log, input) → AuditLogEntry` — append-only writer; computes `prev_sha256` from prior entry, seals with `entry_sha256` over canonical JSON of the entry without `entry_sha256`.
- `verifyAuditChain(log) → {valid: true} | {valid: false, broken_at, reason}` — walks the chain, reports the first index where verification fails plus the failure mode.
- `GENESIS_SENTINEL` — exported `'GENESIS'` literal sentinel for first-entry `prev_sha256`.
- `AuditLogEntry`, `AuditLogEntryInput`, `VerifyAuditChainResult` — type surface.

The actual filesystem write to `runs/<run_id>/audit.ndjson` is F-008's job (storage layout). The pipeline that consumes `appendAuditEntry` from the engine is F-006's job (logging pipeline). Repair-from-backup (per ce:FR-AUDIT-002) is a follow-on feature — currently the `verifyAuditChain` reporter pinpoints the broken index so the storage-layer repair tool can splice in the backup row. Those are tracked as soft deps in the F-015 ledger and explicitly out-of-scope here per `rules/no-silent-deferrals.md`.

Cryptographic signing of audit entries (third-party timestamping) is deferred to v1.5 per ce:FR-IDENTITY-002 — tracked in M19 deferred catalog. The hash chain detects tampering; it does not cryptographically prevent it. That is the agreed v1 surface.

## Implementation summary

`packages/engine-core/src/index.ts` — F-001 unchanged, F-002 unchanged, F-014 unchanged (landed concurrently on wave-008 / lane-a); F-015 adds ~165 LOC:

- `GENESIS_SENTINEL` constant — exported `'GENESIS'` literal as `as const` so TypeScript narrows it to a singleton type.
- `AuditLogEntry` interface — `{cycle, action, fields, prev_sha256, entry_sha256}`. Renamed from the brief's `AuditEntry` to `AuditLogEntry` to avoid silent TypeScript declaration-merging with F-001's transient `AuditEntry` (`{cycle, hash, state}`). The two shapes serve different audiences: F-001's is the run-bootstrap cycle audit kept in `RunResult.audit`; F-015's is the durable audit log row destined for `runs/<run_id>/audit.ndjson`. Holding both in scope without merging requires distinct names — minimum-change discipline applied to the smaller blast radius (F-015 has 0 prior callers, F-001's `AuditEntry` is referenced by `RunResult`).
- `AuditLogEntryInput` — caller-facing shape minus the chain fields the writer fills in.
- `VerifyAuditChainResult` discriminated union — `{valid: true} | {valid: false, broken_at: number, reason: 'entry_sha256 mismatch' | 'prev_sha256 mismatch'}`. Two failure modes reported separately so the storage-layer repair tool can choose the right remediation.
- `canonicalJson(value)` — recursive key-sorted JSON serializer. Sufficient for v1's free-form `fields` payload; if we later need RFC 8785 (JCS) precision we'll swap this out. Matches the ledger's `canonical_json(...)` term.
- `computeEntrySha256(entry)` — strips `entry_sha256` from the input (per the ledger contract `entry_sha256 = sha256(canonical_json(entry_without_entry_sha256))`), hashes via `node:crypto.createHash('sha256')`. Returns 64-hex.
- `appendAuditEntry(log, input)` — append-only writer. Builds the unsealed entry, computes the seal, pushes to log, returns the sealed entry.
- `verifyAuditChain(log)` — for each entry: recompute `entry_sha256` → if mismatch, return `entry_sha256 mismatch` at that index; else verify `prev_sha256` against expected (`GENESIS_SENTINEL` for index 0, prior entry's `entry_sha256` otherwise) → if mismatch, return `prev_sha256 mismatch`. Walks once; O(N).

## Toolchain hops landed alongside

None. Wave-005 / lane-d already landed `pnpm-workspace.yaml` + `@mad-council-claw/engine-core: workspace:*` devDep + `test:unit` script fix. F-015 inherits all three.

## Reproduction

```bash
cd C:/Users/tonym/Repos/mad-council-claw
pnpm install
pnpm test:unit
# Expected: "Test Files 4 passed (4)" + "Tests 18 passed (18)" + exit 0
```

Or for per-scenario detail:

```bash
pnpm exec vitest run tests/unit/F-015-hash-chained-audit-log.test.ts --reporter=verbose
```

Captured: `green-test-output.txt`. Stability: 3 consecutive runs, 18/18 PASS each (across all four feature test files), no flake.

## Lessons / loop-improvement notes for wave-9

1. **Concurrent lane name collision (HIGH).** The brief's hint type was `AuditEntry` — same name as F-001's existing interface. Lane B's first impl pass declared a second `interface AuditEntry` in the same module; TypeScript declaration merging would have silently fused the two shapes (or the test runner's transpile-only mode would have masked the type error until `tsc` ran). Caught by reading the file end-to-end before committing GREEN. Renamed to `AuditLogEntry` — minimum-change discipline applied to the smaller blast radius. **Wave-9 takeaway:** when adding a new top-level type to a shared module, grep for the type name first; rename pre-emptively if a same-name interface exists in F-001..F-NNN siblings.

2. **Brief-vs-ledger field naming divergence (MEDIUM).** The brief's TypeScript hint used camelCase (`prevHash`, `hash`) and 64-zero genesis. The ledger's behavior contract used snake_case (`prev_sha256`, `entry_sha256`) and `"GENESIS"` string sentinel. Per FETCH BEFORE CITE the ledger is authoritative; the brief is a hint. Wave-9 takeaway: when brief and ledger disagree on a load-bearing field name, the test should encode the ledger's choice and the impl should follow.

3. **broken_at indexing (MEDIUM).** The ledger says "entry K" abstractly. Two natural choices: 1-indexed cycle number (matches the human-friendly retro language) vs zero-indexed array position (matches the ndjson row offset that a repair tool would seek to). Picked zero-indexed — matches `log[i]` calls and is the more useful API for storage-layer consumers. Test fix landed in the same RED-iteration round; documented inline. Wave-9 takeaway: when an index is reported in a result object, the doc string should state the indexing base explicitly.

## Confidence

HIGH. All 4 scenarios pass with real vitest output (not synthesized). 3 consecutive stable runs across all 4 test files (18/18 PASS each). RED baseline captured BEFORE the impl flip per the wave-5 retro proposal — see `red-test-output.txt`. The hash chain detects tampering of both `fields` (scenario 2) and `prev_sha256` (scenario 4) at the precise index. Append-only mutation discipline mirrors `rules/concurrency-safety.md` §1.

## Soft dependencies still RED

Per the F-015 ledger:
- F-006 (logging-pipeline) — F-015 emits the chain primitives; the pipeline that wires the engine into the writer is F-006's job
- F-008 (local-storage-layout) — F-015 maintains the chain in memory; persistence to `runs/<run_id>/audit.ndjson` is F-008's job
- F-016 (query-audit-log) — sibling on M2; consumes `verifyAuditChain` for forensic queries

Cryptographic signing + Entra binding (ce:FR-IDENTITY-002) are explicitly deferred to v1.5 per the F-015 ledger out-of-scope-notes — tracked in M19 deferred catalog (F-D-005 identity-crypto).
