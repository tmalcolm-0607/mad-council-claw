import { describe, it, expect, vi, afterEach } from 'vitest';
import {
  HeartbeatScheduler,
  type HeartbeatConfig,
  type CadenceProfile,
} from '@mad-council-claw/engine-core';

/**
 * F-023 RED → GREEN test.
 * Per docs/03-feature-catalog/M3-cron-heartbeat/F-023-cron-heartbeat.md
 * acceptance scenarios. Authored RED-first per the wave-5 retro proposal
 * (capture RED before flipping GREEN) — same pattern as F-018 (wave-009 /
 * lane-c), F-022 (wave-010 / lane-c), F-010 (wave-015 / lane-b), and
 * F-011 (wave-015 / lane-c).
 *
 * Behavior contract (from ledger):
 *   The engine supports cron-driven heartbeats: scheduled, recurring,
 *   autonomous run invocations. A heartbeat scheduler reads cadence,
 *   computes next-fire times, and at each fire spawns a fresh run.
 *   Schedule drift (actual vs scheduled) MUST stay ≤5% over a 100-fire
 *   window (per ce:SC-007). The scheduler is cadence-aware per
 *   `kit:rules/loop-cadence-discipline.md` — the two named profiles
 *   (`mad-iteration` 270s, `deployment-watch` 1500s) are the canonical
 *   defaults; the 280-1199s zone is forbidden.
 *
 * Wave-016 / Lane B brief: encode F-023 as `HeartbeatScheduler` class
 * with constructor enforcing cadence-zone validation, start/stop
 * lifecycle, manual `tick()` for testability, and `getStatus()` for
 * observability. Real `setInterval` wiring + spawn-fresh-run integration
 * are deferred to F-024 (skip-on-overlap) and F-001 wiring waves —
 * F-023's scope is the scheduler primitive itself, mirrored on the
 * F-022 ToolCallQuota / F-018 HaltDetector pattern of pure-class +
 * orchestrator-driven invocation.
 *
 * Acceptance scenarios mirrored from the ledger + brief:
 *   1. mad-iteration profile → getIntervalSeconds() === 270 (warm cache).
 *   2. deployment-watch profile → getIntervalSeconds() === 1500 (amortized).
 *   3. custom profile WITHOUT intervalSeconds → constructor throws.
 *   4. Forbidden zone (280-1199s) → constructor throws with clear message.
 *   5. Manual tick increments tickCount and updates lastTickAt.
 *   6. getStatus reports isRunning + tickCount + lastTickAt + intervalSeconds.
 *   7. start() registers handler; stop() clears the timer.
 *   8. Custom profile in warm-cache zone (e.g. 120s) is accepted.
 *   9. Custom profile in amortized zone (e.g. 1800s) is accepted.
 *  10. enforceWarmCacheZones=false bypasses the forbidden-zone gate.
 */

afterEach(() => {
  vi.useRealTimers();
});

describe('F-023 cron-heartbeat — HeartbeatScheduler', () => {
  describe('cadence profile resolution', () => {
    it('mad-iteration profile resolves to 270s (warm cache)', () => {
      const config: HeartbeatConfig = { profile: 'mad-iteration' };
      const sch = new HeartbeatScheduler(config);
      expect(sch.getIntervalSeconds()).toBe(270);
    });

    it('deployment-watch profile resolves to 1500s (amortized)', () => {
      const config: HeartbeatConfig = { profile: 'deployment-watch' };
      const sch = new HeartbeatScheduler(config);
      expect(sch.getIntervalSeconds()).toBe(1500);
    });

    it("custom profile without intervalSeconds throws", () => {
      expect(() => new HeartbeatScheduler({ profile: 'custom' })).toThrow(
        /intervalSeconds required when profile='custom'/,
      );
    });

    it('custom profile in warm-cache zone (120s) is accepted', () => {
      const sch = new HeartbeatScheduler({ profile: 'custom', intervalSeconds: 120 });
      expect(sch.getIntervalSeconds()).toBe(120);
    });

    it('custom profile in amortized zone (1800s) is accepted', () => {
      const sch = new HeartbeatScheduler({ profile: 'custom', intervalSeconds: 1800 });
      expect(sch.getIntervalSeconds()).toBe(1800);
    });
  });

  describe('forbidden-zone enforcement (loop-cadence-discipline.md)', () => {
    it('rejects 600s (mid forbidden zone) with clear remediation message', () => {
      expect(
        () => new HeartbeatScheduler({ profile: 'custom', intervalSeconds: 600 }),
      ).toThrow(/forbidden zone 280-1199s/);
    });

    it('rejects 280s (lower bound of forbidden zone)', () => {
      expect(
        () => new HeartbeatScheduler({ profile: 'custom', intervalSeconds: 280 }),
      ).toThrow(/forbidden zone/);
    });

    it('rejects 1199s (upper bound of forbidden zone)', () => {
      expect(
        () => new HeartbeatScheduler({ profile: 'custom', intervalSeconds: 1199 }),
      ).toThrow(/forbidden zone/);
    });

    it('accepts 270s (warm-cache margin under TTL)', () => {
      const sch = new HeartbeatScheduler({ profile: 'custom', intervalSeconds: 270 });
      expect(sch.getIntervalSeconds()).toBe(270);
    });

    it('accepts 1200s (amortized lower bound)', () => {
      const sch = new HeartbeatScheduler({ profile: 'custom', intervalSeconds: 1200 });
      expect(sch.getIntervalSeconds()).toBe(1200);
    });

    it('enforceWarmCacheZones=false bypasses forbidden-zone gate', () => {
      const sch = new HeartbeatScheduler({
        profile: 'custom',
        intervalSeconds: 600,
        enforceWarmCacheZones: false,
      });
      expect(sch.getIntervalSeconds()).toBe(600);
    });
  });

  describe('tick lifecycle', () => {
    it('manual tick() invokes handler and increments tickCount', async () => {
      const sch = new HeartbeatScheduler({ profile: 'mad-iteration' });
      const handler = vi.fn();
      sch.start(handler);
      try {
        await sch.tick();
        await sch.tick();
        expect(handler).toHaveBeenCalledTimes(2);
        expect(sch.getStatus().tickCount).toBe(2);
        expect(sch.getStatus().lastTickAt).toBeInstanceOf(Date);
      } finally {
        sch.stop();
      }
    });

    it('tick() works even before start() (manual-mode for tests)', async () => {
      const sch = new HeartbeatScheduler({ profile: 'mad-iteration' });
      // No handler registered; tick should still bump counters without throwing
      await sch.tick();
      expect(sch.getStatus().tickCount).toBe(1);
      expect(sch.getStatus().lastTickAt).toBeInstanceOf(Date);
    });

    it('async handler is awaited by tick()', async () => {
      const sch = new HeartbeatScheduler({ profile: 'mad-iteration' });
      let resolved = false;
      const handler = async () => {
        await new Promise((r) => setTimeout(r, 1));
        resolved = true;
      };
      sch.start(handler);
      try {
        await sch.tick();
        expect(resolved).toBe(true);
      } finally {
        sch.stop();
      }
    });
  });

  describe('start/stop lifecycle', () => {
    it('start() sets isRunning=true; stop() sets isRunning=false', () => {
      const sch = new HeartbeatScheduler({ profile: 'mad-iteration' });
      expect(sch.getStatus().isRunning).toBe(false);
      sch.start(() => {});
      expect(sch.getStatus().isRunning).toBe(true);
      sch.stop();
      expect(sch.getStatus().isRunning).toBe(false);
    });

    it('start() twice throws (already started)', () => {
      const sch = new HeartbeatScheduler({ profile: 'mad-iteration' });
      sch.start(() => {});
      try {
        expect(() => sch.start(() => {})).toThrow(/already started/);
      } finally {
        sch.stop();
      }
    });

    it('stop() is idempotent', () => {
      const sch = new HeartbeatScheduler({ profile: 'mad-iteration' });
      sch.stop(); // no-op when not started
      sch.start(() => {});
      sch.stop();
      sch.stop(); // second call must not throw
      expect(sch.getStatus().isRunning).toBe(false);
    });

    it('setInterval-driven tick fires after the cadence elapses (fake timers)', async () => {
      vi.useFakeTimers();
      const sch = new HeartbeatScheduler({ profile: 'mad-iteration' }); // 270s
      const handler = vi.fn();
      sch.start(handler);
      try {
        // Advance just under the cadence: no tick
        await vi.advanceTimersByTimeAsync(269_000);
        expect(handler).not.toHaveBeenCalled();
        // Cross the cadence boundary: one tick
        await vi.advanceTimersByTimeAsync(2_000);
        expect(handler).toHaveBeenCalledTimes(1);
        // Two more cadences
        await vi.advanceTimersByTimeAsync(540_000);
        expect(handler).toHaveBeenCalledTimes(3);
      } finally {
        sch.stop();
      }
    });
  });

  describe('getStatus observability', () => {
    it('reports the configured intervalSeconds', () => {
      const a = new HeartbeatScheduler({ profile: 'mad-iteration' });
      const b = new HeartbeatScheduler({ profile: 'deployment-watch' });
      const c = new HeartbeatScheduler({ profile: 'custom', intervalSeconds: 60 });
      expect(a.getStatus().intervalSeconds).toBe(270);
      expect(b.getStatus().intervalSeconds).toBe(1500);
      expect(c.getStatus().intervalSeconds).toBe(60);
    });

    it('initial state: tickCount=0, lastTickAt=null, isRunning=false', () => {
      const sch = new HeartbeatScheduler({ profile: 'mad-iteration' });
      const s = sch.getStatus();
      expect(s.tickCount).toBe(0);
      expect(s.lastTickAt).toBeNull();
      expect(s.isRunning).toBe(false);
    });
  });

  describe('CadenceProfile type surface (compile-time witness)', () => {
    it('accepts the three documented profile values', () => {
      const profiles: CadenceProfile[] = ['mad-iteration', 'deployment-watch', 'custom'];
      expect(profiles).toHaveLength(3);
    });
  });
});
