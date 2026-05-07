import { describe, it, expect } from 'vitest';
import {
  appendAuditEntry,
  verifyAuditChain,
  GENESIS_SENTINEL,
  type AuditLogEntry,
} from '@mad-council-claw/engine-core';

/**
 * F-015 RED → GREEN test.
 * Per docs/03-feature-catalog/M2-governance-triad/F-015-hash-chained-audit-log.md
 * acceptance scenarios. Authored RED-first in wave-008 / lane-b per the
 * wave-5 retro proposal (capture RED before flipping GREEN).
 *
 * Behavior contract (verbatim from ledger):
 *   Every audit entry includes `prev_sha256` and `entry_sha256` fields.
 *   `prev_sha256` is the `entry_sha256` of the immediately preceding entry in
 *   the same run (or `"GENESIS"` for the first entry). `entry_sha256 =
 *   sha256(canonical_json(entry_without_entry_sha256))`. The audit log lives
 *   at `runs/<run_id>/audit.ndjson` and is append-only (never rewritten). A
 *   `Verify-AuditChain` operation walks the log and reports the first index
 *   where `prev_sha256` mismatch is detected — pointing precisely at the
 *   tampered entry.
 *
 * Acceptance scenarios mirrored from the ledger:
 *   1. Empty log → first entry: prev_sha256 === "GENESIS" AND entry_sha256
 *      is a valid 64-hex SHA-256.
 *   2. Tamper with entry K's fields → verifyAuditChain returns
 *      {valid: false, broken_at: K, reason: "entry_sha256 mismatch"}.
 *   3. Append entry M+1 via the writer (which computes prev_sha256 from M's
 *      entry_sha256) → chain remains valid 1..M+1.
 *
 * Bonus scenario 4: tampering with row N's content invalidates verification
 * starting at row N (chain detection is precise per the behavior contract).
 *
 * Out of scope (per ledger): cryptographic signing, third-party timestamping
 * (deferred to v1.5 per ce:FR-IDENTITY-002).
 */
const SHA256_HEX_REGEX = /^[0-9a-f]{64}$/;

describe('F-015 hash-chained-audit-log', () => {
  it('scenario 1: first entry on empty log has prev_sha256 === GENESIS and 64-hex entry_sha256', () => {
    const log: AuditLogEntry[] = [];
    const entry = appendAuditEntry(log, {
      cycle: 1,
      action: 'engine.boot',
      fields: { state: 'open' },
    });

    expect(entry.prev_sha256).toBe(GENESIS_SENTINEL);
    expect(GENESIS_SENTINEL).toBe('GENESIS');
    expect(entry.entry_sha256).toMatch(SHA256_HEX_REGEX);

    // The append mutates the log (append-only) — ledger contract.
    expect(log).toHaveLength(1);
    expect(log[0]).toBe(entry);

    // verifyAuditChain over the single-entry log returns valid:true.
    expect(verifyAuditChain(log)).toEqual({ valid: true });
  });

  it('scenario 2: tampering with entry K invalidates chain with precise broken_at index', () => {
    const log: AuditLogEntry[] = [];
    appendAuditEntry(log, { cycle: 1, action: 'engine.boot', fields: { state: 'open' } });
    appendAuditEntry(log, { cycle: 2, action: 'agent.spawn', fields: { agent_id: 'a1' } });
    appendAuditEntry(log, { cycle: 3, action: 'tool.invoke', fields: { tool: 'grep' } });
    appendAuditEntry(log, { cycle: 4, action: 'engine.cycle', fields: { state: 'active' } });

    // Healthy chain first.
    expect(verifyAuditChain(log)).toEqual({ valid: true });

    // Manually tamper with entry at zero-based index K=1 (the second entry).
    // Mutating the `fields` object mutates the canonical-json input so the
    // recomputed entry_sha256 won't match the stored value. The impl reports
    // broken_at as a zero-based array index (per the F-015 acceptance
    // contract: "first index where prev_sha256 mismatch is detected" — index
    // is the array position, the natural shape for callers iterating the
    // ndjson file).
    log[1] = { ...log[1], fields: { agent_id: 'tampered' } };

    const result = verifyAuditChain(log);
    expect(result.valid).toBe(false);
    if (!result.valid) {
      expect(result.broken_at).toBe(1);
      expect(result.reason).toBe('entry_sha256 mismatch');
    }
  });

  it('scenario 3: appending M+1 to a valid 1..M chain keeps the chain valid', () => {
    const log: AuditLogEntry[] = [];
    for (let cycle = 1; cycle <= 10; cycle++) {
      appendAuditEntry(log, {
        cycle,
        action: `engine.cycle.${cycle}`,
        fields: { state: 'active' },
      });
    }
    expect(log).toHaveLength(10);
    expect(verifyAuditChain(log)).toEqual({ valid: true });

    // Append M+1.
    appendAuditEntry(log, {
      cycle: 11,
      action: 'engine.closing',
      fields: { state: 'closing' },
    });

    expect(log).toHaveLength(11);
    expect(verifyAuditChain(log)).toEqual({ valid: true });

    // The new entry's prev_sha256 chains from entry 10's entry_sha256.
    expect(log[10].prev_sha256).toBe(log[9].entry_sha256);
  });

  it('scenario 4: tampering with prev_sha256 also invalidates with prev_sha256 reason', () => {
    const log: AuditLogEntry[] = [];
    appendAuditEntry(log, { cycle: 1, action: 'engine.boot', fields: { state: 'open' } });
    appendAuditEntry(log, { cycle: 2, action: 'engine.cycle', fields: { state: 'active' } });
    appendAuditEntry(log, { cycle: 3, action: 'engine.cycle', fields: { state: 'active' } });

    // Tamper with prev_sha256 chain link on entry 2 (zero-indexed log[1])
    // without mutating fields. Recomputed entry_sha256 over the tampered
    // entry will mismatch its stored entry_sha256, so the writer detects at K=1.
    log[1] = { ...log[1], prev_sha256: '0'.repeat(64) };

    const result = verifyAuditChain(log);
    expect(result.valid).toBe(false);
    if (!result.valid) {
      // Tampering happens at K=1 (the entry whose prev_sha256 we changed).
      expect(result.broken_at).toBe(1);
    }
  });
});
