import { describe, it, expect, vi, afterEach } from 'vitest';
import {
  HeartbeatScheduler,
  type HeartbeatConfig,
} from '@mad-council-claw/engine-core';

/**
 * F-025 RED → GREEN test (wave-017 / lane-b).
 * Per docs/03-feature-catalog/M3-cron-heartbeat/F-025-idle-archival.md
 * acceptance scenarios. Authored RED-first per the wave-5 retro proposal
 * (capture RED before flipping GREEN).
 *
 * Behavior contract (from ledger):
 *   Cron heartbeats produce a steady stream of completed runs whose
 *   `runs/<run_id>/` directories accumulate on disk. After a run reaches
 *   `closed` AND its final cycle's `closed_utc` is older than the
 *   archival threshold (default 14 days; configurable), the archival
 *   sweep MUST move the run directory atomically from `runs/` to
 *   `archive/runs/<YYYY>/<MM>/<run_id>/`. Archival is idempotent. The
 *   sweep is itself a scheduled cron job using F-023 infrastructure
 *   running on the `mad-iteration` cadence profile (270s).
 *
 * Wave-017 / Lane B brief: extend `HeartbeatScheduler` with idle-archival
 * trigger primitive — when configured `archiveAfterMinutes` is set and
 * the scheduler has been idle (lastTickAt is older than threshold) the
 * scheduler emits an idle-archival callback. This is the SIGNAL that the
 * archival sweep should run; the actual filesystem move (atomic-rename
 * per `concurrency-safety.md` §2 + orphan recovery) lives in the F-008
 * storage layout layer. F-025 contributes the tick-time trigger.
 *
 * Scope reconciliation per `no-silent-deferrals.md`:
 *   - atomic-rename + orphan recovery → F-008 (local-storage-layout)
 *     callback writes the move; F-025 emits the trigger.
 *   - 14-day default threshold → consumed by callers from
 *     `automations/archival-policy.json`; F-025's primitive accepts a
 *     numeric `archiveAfterMinutes` and the policy-file plumbing is the
 *     M7 (skills/permissions/automations) layer's responsibility.
 *   - cross-machine archive sync → out of scope per ledger §
 *     out-of-scope-notes (v1).
 *   - compression / cold-storage tiering → v1.5 (F-NNN candidate, not
 *     yet allocated) per ledger.
 *
 * Acceptance scenarios:
 *   1. archiveAfterMinutes triggers callback when idle exceeds threshold.
 *   2. No callback when idle is below threshold.
 *   3. Multiple callbacks supported (broadcast pattern).
 *   4. Default archiveAfterMinutes=undefined disables the trigger.
 *   5. Idle measured from lastTickAt (not from scheduler creation).
 *   6. Callback receives idleMinutes argument for observability.
 */

afterEach(() => {
  vi.useRealTimers();
});

describe('F-025 idle-archival — HeartbeatScheduler idle trigger', () => {
  describe('threshold semantics', () => {
    it('archiveAfterMinutes triggers callback when idle exceeds threshold', async () => {
      vi.useFakeTimers();
      const baseTime = new Date('2026-05-07T00:00:00Z');
      vi.setSystemTime(baseTime);
      const sch = new HeartbeatScheduler({
        profile: 'mad-iteration',
        archiveAfterMinutes: 10,
      });
      const archiveCb = vi.fn();
      sch.onIdleArchive(archiveCb);
      // First tick records lastTickAt at baseTime.
      await sch.tick();
      // No idle yet.
      expect(archiveCb).not.toHaveBeenCalled();
      // Advance past the threshold (15 minutes > 10 minutes).
      vi.setSystemTime(new Date(baseTime.getTime() + 15 * 60_000));
      await sch.tick();
      expect(archiveCb).toHaveBeenCalledTimes(1);
      // Callback received idleMinutes argument >= 10.
      expect(archiveCb.mock.calls[0]![0]).toBeGreaterThanOrEqual(10);
    });

    it('no callback when idle is below threshold', async () => {
      vi.useFakeTimers();
      const baseTime = new Date('2026-05-07T00:00:00Z');
      vi.setSystemTime(baseTime);
      const sch = new HeartbeatScheduler({
        profile: 'mad-iteration',
        archiveAfterMinutes: 10,
      });
      const archiveCb = vi.fn();
      sch.onIdleArchive(archiveCb);
      await sch.tick();
      // Advance only 5 minutes.
      vi.setSystemTime(new Date(baseTime.getTime() + 5 * 60_000));
      await sch.tick();
      expect(archiveCb).not.toHaveBeenCalled();
    });

    it('idle measured from lastTickAt (not from creation)', async () => {
      vi.useFakeTimers();
      const baseTime = new Date('2026-05-07T00:00:00Z');
      vi.setSystemTime(baseTime);
      const sch = new HeartbeatScheduler({
        profile: 'mad-iteration',
        archiveAfterMinutes: 10,
      });
      const archiveCb = vi.fn();
      sch.onIdleArchive(archiveCb);
      // Advance 20 minutes BEFORE first tick — should NOT trigger,
      // because idle is measured from lastTickAt and we haven't
      // ticked yet. (lastTickAt is null at construction; checkIdle
      // is a no-op then.)
      vi.setSystemTime(new Date(baseTime.getTime() + 20 * 60_000));
      await sch.tick();
      expect(archiveCb).not.toHaveBeenCalled();
      // Advance another 15 minutes; this tick measures idle from the
      // previous tick (which we just took) and triggers the callback.
      vi.setSystemTime(new Date(baseTime.getTime() + 35 * 60_000));
      await sch.tick();
      expect(archiveCb).toHaveBeenCalledTimes(1);
    });
  });

  describe('callback registration', () => {
    it('multiple callbacks supported (broadcast pattern)', async () => {
      vi.useFakeTimers();
      const baseTime = new Date('2026-05-07T00:00:00Z');
      vi.setSystemTime(baseTime);
      const sch = new HeartbeatScheduler({
        profile: 'mad-iteration',
        archiveAfterMinutes: 5,
      });
      const cb1 = vi.fn();
      const cb2 = vi.fn();
      const cb3 = vi.fn();
      sch.onIdleArchive(cb1);
      sch.onIdleArchive(cb2);
      sch.onIdleArchive(cb3);
      await sch.tick();
      vi.setSystemTime(new Date(baseTime.getTime() + 10 * 60_000));
      await sch.tick();
      expect(cb1).toHaveBeenCalledTimes(1);
      expect(cb2).toHaveBeenCalledTimes(1);
      expect(cb3).toHaveBeenCalledTimes(1);
    });

    it('default archiveAfterMinutes=undefined disables the trigger', async () => {
      vi.useFakeTimers();
      const baseTime = new Date('2026-05-07T00:00:00Z');
      vi.setSystemTime(baseTime);
      // No archiveAfterMinutes configured — feature disabled.
      const sch = new HeartbeatScheduler({ profile: 'mad-iteration' });
      const archiveCb = vi.fn();
      sch.onIdleArchive(archiveCb);
      await sch.tick();
      // Advance well past any reasonable threshold.
      vi.setSystemTime(new Date(baseTime.getTime() + 60 * 60_000));
      await sch.tick();
      expect(archiveCb).not.toHaveBeenCalled();
    });
  });

  describe('observability', () => {
    it('callback receives idleMinutes argument equal to elapsed time', async () => {
      vi.useFakeTimers();
      const baseTime = new Date('2026-05-07T00:00:00Z');
      vi.setSystemTime(baseTime);
      const sch = new HeartbeatScheduler({
        profile: 'mad-iteration',
        archiveAfterMinutes: 5,
      });
      const observed: number[] = [];
      sch.onIdleArchive((idleMinutes) => observed.push(idleMinutes));
      await sch.tick();
      vi.setSystemTime(new Date(baseTime.getTime() + 7 * 60_000));
      await sch.tick();
      expect(observed.length).toBe(1);
      // Roughly 7 minutes (allow a small drift; range check rather
      // than exact equality because of microtask jitter).
      expect(observed[0]).toBeGreaterThanOrEqual(6.9);
      expect(observed[0]).toBeLessThanOrEqual(7.1);
    });

    it('callback fires on each tick where idle exceeds threshold', async () => {
      vi.useFakeTimers();
      const baseTime = new Date('2026-05-07T00:00:00Z');
      vi.setSystemTime(baseTime);
      const sch = new HeartbeatScheduler({
        profile: 'mad-iteration',
        archiveAfterMinutes: 5,
      });
      const archiveCb = vi.fn();
      sch.onIdleArchive(archiveCb);
      await sch.tick(); // t=0; lastTickAt = baseTime
      vi.setSystemTime(new Date(baseTime.getTime() + 10 * 60_000));
      await sch.tick(); // t=10m; idle 10m → fires (lastTickAt update happens before checkIdle)
      vi.setSystemTime(new Date(baseTime.getTime() + 20 * 60_000));
      await sch.tick(); // t=20m; idle 10m → fires
      vi.setSystemTime(new Date(baseTime.getTime() + 22 * 60_000));
      await sch.tick(); // t=22m; idle 2m → no fire
      // Expectation: exactly 2 callback invocations (the two ticks
      // whose preceding-tick gap exceeded 5 minutes).
      expect(archiveCb).toHaveBeenCalledTimes(2);
    });
  });

  describe('composition with F-024 skip-on-overlap', () => {
    it('skipped ticks do not fire idle-archival callback', async () => {
      vi.useFakeTimers();
      const baseTime = new Date('2026-05-07T00:00:00Z');
      vi.setSystemTime(baseTime);
      const sch = new HeartbeatScheduler({
        profile: 'mad-iteration',
        archiveAfterMinutes: 5,
      });
      const archiveCb = vi.fn();
      sch.onIdleArchive(archiveCb);
      let release: (() => void) | null = null;
      const slow = () =>
        new Promise<void>((r) => {
          release = r;
        });
      sch.start(slow);
      try {
        // First tick is in-flight; don't await.
        const firstPromise = sch.tick();
        await Promise.resolve();
        // Advance past threshold; second tick is SKIPPED (overlap)
        // and must NOT fire the archive callback because skipped
        // ticks don't update lastTickAt nor invoke the handler — the
        // idle measurement is based on the in-flight first tick's
        // start time.
        vi.setSystemTime(new Date(baseTime.getTime() + 10 * 60_000));
        const skipped = await sch.tick();
        expect(skipped.skipped).toBe(true);
        expect(archiveCb).not.toHaveBeenCalled();
        release!();
        await firstPromise;
      } finally {
        sch.stop();
      }
    });
  });
});
