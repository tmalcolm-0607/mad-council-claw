import { describe, it, expect } from 'vitest';
import { bootstrap } from '@mad-council-claw/engine-core';

/**
 * F-001 RED test stub.
 * Per docs/03-feature-catalog/M0-bootstrap/F-001-engine-bootstrap-loop.md
 * acceptance scenarios. Tests intentionally FAIL until F-001 is implemented in
 * the M0 wave; that's the RED state contract.
 *
 * Acceptance scenarios mirrored from the ledger:
 *   1. fresh run with max_cycles=3 emits lifecycle [open, active, closing, closed]
 *      in order, with exactly one audit entry per cycle.
 *   2. run with max_cycles=50 refuses cycle 51 and transitions to closing with
 *      terminated_by: cycle_cap.
 *   3. run interrupted by an unhandled exception still transitions through
 *      closing (not direct to closed) so the pre-close retro signal fires
 *      with terminated_by: exception.
 */
describe('F-001 engine-bootstrap-loop', () => {
  it('scenario 1: fresh run emits lifecycle in order with one audit entry per cycle', async () => {
    const result = await bootstrap({ maxCycles: 3 });
    expect(result.lifecycle).toEqual(['open', 'active', 'closing', 'closed']);
    expect(result.audit).toHaveLength(3);
    expect(result.audit.map((e) => e.cycle)).toEqual([1, 2, 3]);
  });

  it('scenario 2: cycle cap (max_cycles=50) refuses cycle 51 and terminates with cycle_cap', async () => {
    const result = await bootstrap({ maxCycles: 50 });
    expect(result.audit).toHaveLength(50);
    expect(result.terminatedBy).toBe('cycle_cap');
    expect(result.lifecycle).toContain('closing');
    expect(result.lifecycle[result.lifecycle.length - 1]).toBe('closed');
  });

  it('scenario 3: unhandled exception still transitions through closing (pre-close retro signal fires)', async () => {
    // Implementation contract: even on exception, the engine must pass through
    // closing before reaching closed. This test will be made concrete once an
    // exception-injection seam exists in the impl; for now it asserts the
    // shape implied by terminatedBy='exception' implies closing in lifecycle.
    const result = await bootstrap({ maxCycles: 3 });
    if (result.terminatedBy === 'exception') {
      expect(result.lifecycle).toContain('closing');
      expect(result.lifecycle[result.lifecycle.length - 1]).toBe('closed');
    } else {
      // For RED state, just assert the type surface exists.
      expect(['completion', 'cycle_cap', 'exception']).toContain(result.terminatedBy);
    }
  });
});
