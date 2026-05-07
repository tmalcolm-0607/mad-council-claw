import { describe, it, expect, vi } from 'vitest';
import {
  HeartbeatScheduler,
  type HeartbeatConfig,
} from '@mad-council-claw/engine-core';

/**
 * F-024 RED → GREEN test (wave-017 / lane-b).
 * Per docs/03-feature-catalog/M3-cron-heartbeat/F-024-skip-on-overlap.md
 * acceptance scenarios. Authored RED-first per the wave-5 retro proposal
 * (capture RED before flipping GREEN) — same pattern as F-018, F-022,
 * F-010, F-011, F-023.
 *
 * Behavior contract (from ledger):
 *   When a cron heartbeat (per F-023) is about to fire and a prior fire
 *   of the SAME schedule is still active, the scheduler MUST skip the
 *   new fire — NOT queue, NOT run concurrently. Per ce:SC-007 the
 *   silent-overlap rate must be 0% across 100 simulated overlap
 *   conditions. The cron-fires.jsonl entry is the record (wired by
 *   F-006/F-008 callers — F-024's primitive contributes the SKIP signal
 *   only).
 *
 * Wave-017 / Lane B brief: extend `HeartbeatScheduler` (wave-016 / lane-b)
 * with an in-flight tick guard. F-023's tick lifecycle owns the cadence
 * gate; F-024's lifecycle owns same-schedule re-entry. The two compose:
 * `tick()` returns `{ ran: true }` on a fresh fire and `{ ran: false,
 * skipped: true }` when a prior tick is still in flight.
 *
 * Scope reconciliation per `no-silent-deferrals.md`:
 *   - cron-fires.jsonl `outcome: "overlap_skipped"` append → F-006 + F-008
 *     (logging-pipeline + storage-layout) caller writes the entry; F-024
 *     surfaces the skip event via tick return shape + skippedTicks counter.
 *   - `prior_fire_id` cross-link → caller-side once F-001 run-id wiring
 *     lands; F-024 contributes the trigger, not the link.
 *   - cross-schedule independence → handled by separate HeartbeatScheduler
 *     instances (one per schedule); F-024 only guards same-schedule
 *     re-entry — by-design, mirrored on the F-022 ToolCallQuota pattern
 *     of one quota per resource.
 *
 * Acceptance scenarios:
 *   1. Tick skips when prior tick is still in-flight (same schedule).
 *   2. skippedTicks counter increments on each skipped fire.
 *   3. In-flight flag clears after handler completes (next tick can run).
 *   4. Sequential ticks (no overlap) both run normally.
 *   5. Parallel manual tick calls return correct `ran` flags (one true,
 *      others false-with-skipped-true).
 *   6. getStatus surfaces skippedTicks + isInFlight for observability.
 */

describe('F-024 skip-on-overlap — HeartbeatScheduler in-flight guard', () => {
  describe('basic skip-on-overlap', () => {
    it('tick skips when prior tick is still in-flight', async () => {
      const sch = new HeartbeatScheduler({ profile: 'mad-iteration' });
      let release: (() => void) | null = null;
      const slowHandler = () =>
        new Promise<void>((r) => {
          release = r;
        });
      sch.start(slowHandler);
      try {
        // Start the slow tick but DO NOT await — leave it in flight
        const firstPromise = sch.tick();
        // Allow microtask queue to advance so handler starts and
        // tickInFlight flips to true; we don't await the slow promise
        // directly because it never resolves until we call release.
        await Promise.resolve();
        const second = await sch.tick();
        expect(second.ran).toBe(false);
        expect(second.skipped).toBe(true);
        // Release the slow handler so the first promise can settle
        release!();
        const first = await firstPromise;
        expect(first.ran).toBe(true);
      } finally {
        sch.stop();
      }
    });

    it('skippedTicks counter increments on each skipped fire', async () => {
      const sch = new HeartbeatScheduler({ profile: 'mad-iteration' });
      let release: (() => void) | null = null;
      const slow = () =>
        new Promise<void>((r) => {
          release = r;
        });
      sch.start(slow);
      try {
        const firstPromise = sch.tick();
        await Promise.resolve();
        await sch.tick(); // skip 1
        await sch.tick(); // skip 2
        await sch.tick(); // skip 3
        expect(sch.getStatus().skippedTicks).toBe(3);
        release!();
        await firstPromise;
      } finally {
        sch.stop();
      }
    });
  });

  describe('in-flight flag lifecycle', () => {
    it('in-flight clears after handler completes — next tick runs', async () => {
      const sch = new HeartbeatScheduler({ profile: 'mad-iteration' });
      const handler = vi.fn().mockResolvedValue(undefined);
      sch.start(handler);
      try {
        const r1 = await sch.tick();
        expect(r1.ran).toBe(true);
        expect(sch.getStatus().isInFlight).toBe(false);
        const r2 = await sch.tick();
        expect(r2.ran).toBe(true);
        expect(sch.getStatus().isInFlight).toBe(false);
        expect(handler).toHaveBeenCalledTimes(2);
      } finally {
        sch.stop();
      }
    });

    it('in-flight clears even when handler throws', async () => {
      const sch = new HeartbeatScheduler({ profile: 'mad-iteration' });
      const handler = vi.fn().mockRejectedValue(new Error('boom'));
      sch.start(handler);
      try {
        await expect(sch.tick()).rejects.toThrow('boom');
        // Despite the throw, in-flight must have cleared so the next
        // tick is not stuck in a permanent skip state.
        expect(sch.getStatus().isInFlight).toBe(false);
        // And a follow-up tick can still run.
        await expect(sch.tick()).rejects.toThrow('boom');
        expect(handler).toHaveBeenCalledTimes(2);
      } finally {
        sch.stop();
      }
    });
  });

  describe('sequential vs parallel ticks', () => {
    it('sequential ticks (no overlap) both run normally', async () => {
      const sch = new HeartbeatScheduler({ profile: 'mad-iteration' });
      const handler = vi.fn().mockResolvedValue(undefined);
      sch.start(handler);
      try {
        const r1 = await sch.tick();
        const r2 = await sch.tick();
        expect(r1.ran).toBe(true);
        expect(r2.ran).toBe(true);
        expect(r1.skipped).toBeUndefined();
        expect(r2.skipped).toBeUndefined();
        expect(sch.getStatus().tickCount).toBe(2);
        expect(sch.getStatus().skippedTicks).toBe(0);
      } finally {
        sch.stop();
      }
    });

    it('parallel manual tick calls return correct ran flags', async () => {
      const sch = new HeartbeatScheduler({ profile: 'mad-iteration' });
      let release: (() => void) | null = null;
      const slow = () =>
        new Promise<void>((r) => {
          release = r;
        });
      sch.start(slow);
      try {
        // Fire three ticks in parallel; only the first should run.
        const p1 = sch.tick();
        await Promise.resolve();
        const p2 = sch.tick();
        const p3 = sch.tick();
        const [r2, r3] = await Promise.all([p2, p3]);
        expect(r2.ran).toBe(false);
        expect(r2.skipped).toBe(true);
        expect(r3.ran).toBe(false);
        expect(r3.skipped).toBe(true);
        release!();
        const r1 = await p1;
        expect(r1.ran).toBe(true);
      } finally {
        sch.stop();
      }
    });
  });

  describe('getStatus observability', () => {
    it('reports skippedTicks=0 + isInFlight=false initially', () => {
      const sch = new HeartbeatScheduler({ profile: 'mad-iteration' });
      const s = sch.getStatus();
      expect(s.skippedTicks).toBe(0);
      expect(s.isInFlight).toBe(false);
    });

    it('isInFlight is true while handler runs, false after', async () => {
      const sch = new HeartbeatScheduler({ profile: 'mad-iteration' });
      let observed: boolean | null = null;
      const handler = async () => {
        observed = sch.getStatus().isInFlight;
      };
      sch.start(handler);
      try {
        await sch.tick();
        expect(observed).toBe(true);
        expect(sch.getStatus().isInFlight).toBe(false);
      } finally {
        sch.stop();
      }
    });
  });
});
