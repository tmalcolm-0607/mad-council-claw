---
artifact-class: physical-proof
generated-by: hand-authored (wave-009 / lane-b)
wave: wave-009
lane: lane-b
feature-id: F-016
date: 2026-05-07
status: complete
---

# F-016 — Physical proof of GREEN transition

## Audit-trail anchor

This file binds the F-016 ledger acceptance contract to actual vitest output. The two artifacts in this directory are the load-bearing evidence:

- `red-test-output.txt` — captured BEFORE the GREEN impl flip; shows 8/8 fail with `TypeError: queryAuditLog is not a function` (and `findChainBreak is not a function`). Was committed under `eacc651 test(F-018): RED test stub for failure-pattern-halt` due to a cross-lane race during wave-009 (see § Anomalies B1+B2 in `docs/06-agent-team-outputs/wave-009/lane-b-summary.md`).
- `green-test-output.txt` — captured AFTER the GREEN impl flip; shows 8/8 PASS. Lane B's own commit `f867251 test(F-016): GREEN test output captured`.

## Acceptance scenarios → test names → results

| # | Ledger / brief origin | Test name | Result |
|---|---|---|---|
| 1 | Ledger §Acceptance #1 — filter by attribute | `scenario 1: filter by action yields only matching entries in chronological order` | ✅ PASS |
| 2a | Brief — `findChainBreak` returns null on intact chain | `scenario 2a: findChainBreak returns null on intact chain` | ✅ PASS |
| 2b | Ledger §Acceptance #2 — chain-break detection | `scenario 2b: findChainBreak returns broken index on tampered chain` | ✅ PASS |
| 3 | Ledger §Acceptance #3 — limit (`top`) caps result set | `scenario 3: top caps the result set to at most N entries` | ✅ PASS |
| 4 | Brief — `since` filter | `scenario 4: since filter yields only entries at or after the given timestamp` | ✅ PASS |
| 5 | Brief — `top` + `skip` pagination | `scenario 5: top + skip pagination skips first then takes top` | ✅ PASS |
| 6 | Brief — combined filter compose | `scenario 6: combined filters compose (since + action + top)` | ✅ PASS |
| 7 | Brief — defensive copy / read-only | `scenario 7: empty options returns all entries (defensive copy, read-only)` | ✅ PASS |

**8/8 PASS** — full F-016 acceptance contract satisfied.

## Full-suite context

```
Test Files  7 passed (7)
     Tests  39 passed (39)
```

7 test files: F-001 (3) + F-002 (3) + F-006 (4) + F-014 (8) + F-015 (4) + F-016 (8) + F-018 (9). All GREEN-feature tests pass; no regression introduced by F-016's append-only impl region.

## Behavior contract → impl mapping

The F-016 ledger §Behavior contract specifies a streaming async iterator yielding entries with one `chain_invalid` warning when integrity breaks. The wave-9 lane-b brief simplifies this to:

- `queryAuditLog(rows, opts) → AuditLogEntry[]` — synchronous filter, defensive copy, chronological order preserved
- `findChainBreak(rows) → number | null` — opt-in chain integrity check (zero-based broken_at or null)

The substantive guarantees are preserved (filter by attribute, integrity warning, read-only); the streaming shape is deferred to v1.5 per the ledger out-of-scope-notes ("M2 ships a streaming filter API only; heavy query needs are tracked under F-088..F-092 / M11 introspect/replay").

## Reproduction

```bash
cd C:/Users/tonym/Repos/mad-council-claw
pnpm install
pnpm exec vitest run tests/unit/F-016-query-audit-log.test.ts   # 8/8 PASS
pnpm test:unit                                                   # 39/39 PASS (full suite)
git log --oneline | head -10                                     # see lane-b commits + cross-lane attribution context
```

## Cross-lane race notice

Per `rules/no-silent-deferrals.md` + `rules/canonical-skill-only.md` honesty discipline: the F-016 RED test files (`tests/unit/F-016-query-audit-log.test.ts` + `docs/09-examples-proof/F-016/red-test-output.txt`) were committed under `eacc651 test(F-018): RED test stub for failure-pattern-halt` due to a cross-lane race where another lane's `git reset HEAD~1` undid Lane B's own RED commit and then re-included Lane B's files in their next commit. Similarly, F-016 GREEN impl was included in `da48f2a docs(examples-proof): F-006 GREEN ...`.

The substance — RED captured + GREEN impl + 8/8 PASS — is preserved in HEAD. Credit attribution is corrected in this physical-proof file + lane-b-summary.md + the F-016 ledger §status-history. See lane-b-summary.md § Anomalies B1+B2 for the full writeup and the wave-10 loop-improvement proposal.
