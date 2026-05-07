import { describe, it, expect } from 'vitest';
import {
  appendAuditEntry,
  queryAuditLog,
  findChainBreak,
  type AuditLogEntry,
} from '@mad-council-claw/engine-core';

/**
 * F-016 RED → GREEN test.
 * Per docs/03-feature-catalog/M2-governance-triad/F-016-query-audit-log.md.
 *
 * Behavior contract (verbatim from ledger §Behavior contract):
 *   queryAuditLog returns matching entries in chronological order. It validates
 *   the chain integrity per F-015 BEFORE yielding any entry; if the chain is
 *   broken, the consumer is warned via findChainBreak. The API is read-only;
 *   it never mutates the log.
 *
 * Wave-9 lane-b brief simplifies the streaming async-iterator shape from the
 * ledger to a synchronous filter API + a separate findChainBreak helper. The
 * substantive guarantees (filter shape, integrity-warning, read-only) are
 * preserved; the streaming shape is deferred to v1.5 per the ledger
 * out-of-scope-notes ("Full-text search + indexed pagination across thousands
 * of runs is deferred — M2 ships a streaming filter API only").
 *
 * Acceptance scenarios mirrored from the ledger + brief:
 *   1. (ledger #1) Filter by agent_id (here: by `action`) yields only matching
 *      entries in chronological order.
 *   2. (ledger #2) findChainBreak returns the broken-at index when the chain
 *      is tampered, and null when intact.
 *   3. (ledger #3) limit (`top`) caps the result set to at most N entries.
 *   4. (brief)    `since` filter (string-compare on timestamp field in
 *      `fields.timestamp`) yields only entries at or after that timestamp.
 *   5. (brief)    `top` + `skip` pagination interacts correctly (skip first,
 *      then take top).
 *
 * RED-before-GREEN: this file lands BEFORE queryAuditLog / findChainBreak are
 * exported from `@mad-council-claw/engine-core`, so the import line itself
 * fails type-check at vitest collect time and the runtime resolution returns
 * `undefined` for both functions, producing a TypeError on first call. Wave-5
 * retro proposal pattern continued (RED commit captures real before/after).
 */

describe('F-016 query-audit-log', () => {
  /** Build a small valid log used across multiple scenarios. */
  function buildSampleLog(): AuditLogEntry[] {
    const log: AuditLogEntry[] = [];
    appendAuditEntry(log, {
      cycle: 1,
      action: 'engine.boot',
      fields: { state: 'open', timestamp: '2026-05-07T00:00:00Z' },
    });
    appendAuditEntry(log, {
      cycle: 2,
      action: 'agent.spawn',
      fields: { agent_id: 'a1', timestamp: '2026-05-07T00:01:00Z' },
    });
    appendAuditEntry(log, {
      cycle: 3,
      action: 'tool.invoke',
      fields: { tool: 'grep', timestamp: '2026-05-07T00:02:00Z' },
    });
    appendAuditEntry(log, {
      cycle: 4,
      action: 'agent.spawn',
      fields: { agent_id: 'a2', timestamp: '2026-05-07T00:03:00Z' },
    });
    appendAuditEntry(log, {
      cycle: 5,
      action: 'engine.cycle',
      fields: { state: 'active', timestamp: '2026-05-07T00:04:00Z' },
    });
    return log;
  }

  it('scenario 1: filter by action yields only matching entries in chronological order', () => {
    const log = buildSampleLog();

    const result = queryAuditLog(log, { action: 'agent.spawn' });

    expect(result).toHaveLength(2);
    expect(result[0].cycle).toBe(2);
    expect(result[1].cycle).toBe(4);
    // Chronological order: cycles strictly increasing
    expect(result[0].cycle).toBeLessThan(result[1].cycle);
    // Read-only: original log is not mutated
    expect(log).toHaveLength(5);
  });

  it('scenario 2a: findChainBreak returns null on intact chain', () => {
    const log = buildSampleLog();

    const result = findChainBreak(log);

    expect(result).toBeNull();
  });

  it('scenario 2b: findChainBreak returns broken index on tampered chain', () => {
    const log = buildSampleLog();

    // Tamper with entry at zero-based index 2 — mutate fields without
    // recomputing entry_sha256 (matches F-015 scenario 2 tamper pattern).
    log[2] = { ...log[2], fields: { tool: 'tampered', timestamp: '2026-05-07T00:02:00Z' } };

    const result = findChainBreak(log);

    expect(result).toBe(2);
  });

  it('scenario 3: top caps the result set to at most N entries', () => {
    const log: AuditLogEntry[] = [];
    for (let cycle = 1; cycle <= 20; cycle++) {
      appendAuditEntry(log, {
        cycle,
        action: 'engine.cycle',
        fields: { state: 'active', timestamp: `2026-05-07T00:${String(cycle).padStart(2, '0')}:00Z` },
      });
    }

    const result = queryAuditLog(log, { top: 5 });

    expect(result).toHaveLength(5);
    // Chronological order preserved: first 5 entries
    expect(result[0].cycle).toBe(1);
    expect(result[4].cycle).toBe(5);
    // Original log untouched
    expect(log).toHaveLength(20);
  });

  it('scenario 4: since filter yields only entries at or after the given timestamp', () => {
    const log = buildSampleLog();

    const result = queryAuditLog(log, { since: '2026-05-07T00:02:00Z' });

    // cycles 3, 4, 5 — timestamps >= 00:02:00
    expect(result).toHaveLength(3);
    expect(result.map((e) => e.cycle)).toEqual([3, 4, 5]);
  });

  it('scenario 5: top + skip pagination skips first then takes top', () => {
    const log: AuditLogEntry[] = [];
    for (let cycle = 1; cycle <= 10; cycle++) {
      appendAuditEntry(log, {
        cycle,
        action: 'engine.cycle',
        fields: { state: 'active', timestamp: `2026-05-07T00:${String(cycle).padStart(2, '0')}:00Z` },
      });
    }

    // Skip first 3, then take 4 → entries with cycles 4, 5, 6, 7
    const result = queryAuditLog(log, { skip: 3, top: 4 });

    expect(result).toHaveLength(4);
    expect(result.map((e) => e.cycle)).toEqual([4, 5, 6, 7]);
  });

  it('scenario 6: combined filters compose (since + action + top)', () => {
    const log = buildSampleLog();

    // since=00:01:00 → drops cycle 1; action=agent.spawn → keeps 2 + 4;
    // top=1 → keeps the first one (cycle 2).
    const result = queryAuditLog(log, {
      since: '2026-05-07T00:01:00Z',
      action: 'agent.spawn',
      top: 1,
    });

    expect(result).toHaveLength(1);
    expect(result[0].cycle).toBe(2);
  });

  it('scenario 7: empty options returns all entries (defensive copy, read-only)', () => {
    const log = buildSampleLog();

    const result = queryAuditLog(log);

    expect(result).toHaveLength(5);
    expect(result.map((e) => e.cycle)).toEqual([1, 2, 3, 4, 5]);
    // Defensive copy — mutating the result must not affect the source log
    result.length = 0;
    expect(log).toHaveLength(5);
  });
});
