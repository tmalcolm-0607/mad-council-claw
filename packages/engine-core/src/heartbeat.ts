/**
 * F-023 Cron heartbeat — GREEN.
 * F-024 Skip-on-overlap — GREEN (wave-017 / lane-b).
 * F-025 Idle-archival — GREEN (wave-017 / lane-b).
 *
 * Per docs/03-feature-catalog/M3-cron-heartbeat/F-023-cron-heartbeat.md +
 * F-024-skip-on-overlap.md + F-025-idle-archival.md. Behavior contract
 * for F-023 (from ledger):
 *   The engine supports cron-driven heartbeats: scheduled, recurring,
 *   autonomous run invocations. A heartbeat scheduler reads cadence,
 *   computes next-fire times, and at each fire spawns a fresh run.
 *   Schedule drift (actual_fire_utc vs scheduled_utc) MUST stay ≤5% of
 *   the cadence interval over a 100-fire window (per ce:SC-007). The
 *   scheduler is cadence-aware per `kit:rules/loop-cadence-discipline.md` —
 *   the two named profiles (`mad-iteration` 270s, `deployment-watch`
 *   1500s) are the canonical defaults; the 280-1199s zone is forbidden
 *   (worst-of-both prompt-cache miss without amortization).
 *
 * F-024 contract: same-schedule re-entry guard. When tick() is invoked
 * while a prior tick is still running (handler hasn't resolved), the
 * new fire is recorded as skipped (skippedTicks++, return value
 * { ran: false, skipped: true }) and the handler is NOT invoked again.
 * Cross-schedule independence is by-design: separate
 * HeartbeatScheduler instances per schedule, mirrored on F-022's
 * one-quota-per-resource shape.
 *
 * F-025 contract: idle-archival trigger. When configured
 * `archiveAfterMinutes` is set, every successful tick measures the gap
 * since the PRIOR lastTickAt and (if it exceeds the threshold) fires
 * the registered onIdleArchive callbacks. The actual atomic-rename of
 * the archive directory (per `concurrency-safety.md` §2) lives in the
 * F-008 storage-layout layer; F-025 contributes the trigger only.
 *
 * Scope discipline (FETCH BEFORE CITE on the F-023 ledger):
 *   F-023's primitive is the SCHEDULER — a pure-class (no I/O, no run
 *   spawn) that owns cadence-zone validation + tick lifecycle + start/stop
 *   + observability. F-024 + F-025 extend it as same-class additions
 *   per the F-022 ToolCallQuota / F-018 HaltDetector pattern.
 *
 * Cross-feature coordination:
 *   - F-001 (engine-bootstrap-loop) — caller's `tick` handler invokes
 *     boot-fresh-run; F-023 is agnostic to what the handler does.
 *   - F-006 (logging-pipeline) — caller writes the `cron-fires.jsonl`
 *     append-only entry inside its handler. F-024's skip return shape
 *     gives the caller the SKIP signal to log `outcome: "overlap_skipped"`.
 *   - F-008 (local-storage-layout) — onIdleArchive callback writes the
 *     atomic-rename of `runs/<run_id>/` → `archive/runs/<YYYY>/<MM>/<run_id>/`.
 *   - F-002 (per-agent-identity) — caller resolves agent identity for
 *     the fresh run before invoking F-023's tick.
 *
 * Authored in wave-016 / lane-b (F-023). Extended in wave-017 / lane-b
 * (F-024 + F-025). Per-feature file (no index.ts churn beyond barrel
 * re-export) per the wave-011/lane-a anti-cross-lane-race convention.
 */

/**
 * Canonical cadence profiles per `loop-cadence-discipline.md`.
 *
 * `mad-iteration` (270s) — warm-cache zone; for active MAD development
 * loops where the prompt cache (5-min TTL = 300s) re-uses prior turn's
 * tokens. Re-reading conversation costs ~10% of input tokens.
 *
 * `deployment-watch` (1500s) — amortized-cache-miss zone; for
 * long-poll loops waiting on slow external state change (deploys,
 * builds). Pays one cache miss per long sleep but amortizes across
 * meaningful wait time.
 *
 * `custom` — operator-supplied `intervalSeconds`; subject to the
 * forbidden-zone gate unless `enforceWarmCacheZones: false`.
 */
export type CadenceProfile = 'mad-iteration' | 'deployment-watch' | 'custom';

/**
 * Configuration accepted by `HeartbeatScheduler`'s constructor.
 *
 * The forbidden-zone gate is on-by-default. Operators with a documented
 * reason to park in the 280-1199s zone (rare, almost always wrong per
 * `loop-cadence-discipline.md`) MUST opt out explicitly via
 * `enforceWarmCacheZones: false` so the override is reviewable.
 */
export interface HeartbeatConfig {
  /** Cadence profile selector. */
  profile: CadenceProfile;
  /** Custom interval in seconds; required when `profile === 'custom'`. */
  intervalSeconds?: number;
  /**
   * Defaults to true. When true, intervals in 280-1199s are rejected at
   * construction with a clear remediation pointer. Set false to bypass.
   */
  enforceWarmCacheZones?: boolean;
  /**
   * F-025 idle-archival threshold in minutes. When set AND the gap
   * between successive ticks exceeds this value, the registered
   * onIdleArchive callbacks fire. Undefined disables the feature
   * (default).
   */
  archiveAfterMinutes?: number;
}

/** Snapshot of scheduler state for observability + tests. */
export interface HeartbeatStatus {
  isRunning: boolean;
  tickCount: number;
  lastTickAt: Date | null;
  intervalSeconds: number;
  /** F-024: count of ticks skipped because a prior tick was in flight. */
  skippedTicks: number;
  /** F-024: true when the handler is actively running. */
  isInFlight: boolean;
}

/**
 * F-024 tick result. `ran: true` means the handler was invoked
 * (regardless of success/failure — failure surfaces as a thrown
 * promise). `ran: false` + `skipped: true` means the tick was
 * suppressed because a prior tick is still in flight (same-schedule
 * re-entry guard).
 */
export interface TickResult {
  ran: boolean;
  skipped?: boolean;
}

/**
 * F-025 idle-archival callback. Receives the measured idle gap (in
 * minutes) between the prior tick and this one, so listeners can log
 * + decide which run directories to archive.
 */
export type IdleArchiveCallback = (idleMinutes: number) => void;

const MAD_ITERATION_SECONDS = 270;
const DEPLOYMENT_WATCH_SECONDS = 1500;
/** Lower (inclusive) bound of the forbidden zone — TTL cliff. */
const FORBIDDEN_ZONE_LOWER_INCLUSIVE = 280;
/** Upper (inclusive) bound of the forbidden zone — under amortized boundary. */
const FORBIDDEN_ZONE_UPPER_INCLUSIVE = 1199;

/**
 * Cadence-aware scheduler primitive.
 *
 * Construction is the gate: invalid configurations throw before any
 * timer is registered. Once constructed, the instance is well-formed.
 *
 * Test ergonomics: `tick()` is exposed as a public method so tests
 * (and tools like `/loop` dynamic mode) can drive the handler manually
 * without `setInterval` or fake-timers.
 */
export class HeartbeatScheduler {
  private timer: ReturnType<typeof setInterval> | null = null;
  private tickHandler: (() => void | Promise<void>) | null = null;
  private lastTickAt: Date | null = null;
  private tickCount = 0;
  private readonly intervalSeconds: number;
  /** F-024 in-flight guard. */
  private tickInFlight = false;
  /** F-024 skip counter for observability. */
  private skippedTicks = 0;
  /** F-025 idle-archival callbacks (broadcast pattern). */
  private archiveCallbacks: IdleArchiveCallback[] = [];

  constructor(private readonly config: HeartbeatConfig) {
    if (config.profile === 'custom' && config.intervalSeconds == null) {
      throw new Error(
        "HeartbeatConfig: intervalSeconds required when profile='custom'",
      );
    }
    this.intervalSeconds = this.computeIntervalSeconds();

    const enforce = config.enforceWarmCacheZones !== false;
    if (
      enforce &&
      this.intervalSeconds >= FORBIDDEN_ZONE_LOWER_INCLUSIVE &&
      this.intervalSeconds <= FORBIDDEN_ZONE_UPPER_INCLUSIVE
    ) {
      throw new Error(
        `HeartbeatConfig: ${this.intervalSeconds}s falls in forbidden zone ` +
          `${FORBIDDEN_ZONE_LOWER_INCLUSIVE}-${FORBIDDEN_ZONE_UPPER_INCLUSIVE}s ` +
          `(worst-of-both cache: pays the prompt-cache miss without amortizing). ` +
          `Use 270s (warm-cache) OR 1200s+ (amortized) per ` +
          `kit:rules/loop-cadence-discipline.md, or set enforceWarmCacheZones=false to bypass.`,
      );
    }
  }

  private computeIntervalSeconds(): number {
    if (this.config.profile === 'mad-iteration') return MAD_ITERATION_SECONDS;
    if (this.config.profile === 'deployment-watch') return DEPLOYMENT_WATCH_SECONDS;
    // custom — guarded above
    return this.config.intervalSeconds!;
  }

  /** The cadence interval in seconds, after profile resolution. */
  getIntervalSeconds(): number {
    return this.intervalSeconds;
  }

  /**
   * Begin firing `handler` every `intervalSeconds`. Throws if already
   * started — callers must `stop()` before re-starting.
   */
  start(handler: () => void | Promise<void>): void {
    if (this.timer !== null) {
      throw new Error('HeartbeatScheduler already started');
    }
    this.tickHandler = handler;
    this.timer = setInterval(() => {
      // Fire-and-forget: setInterval cannot await; tick() captures
      // the promise so unhandled rejections don't leak. Tests use
      // `tick()` directly to await.
      void this.tick();
    }, this.intervalSeconds * 1000);
  }

  /**
   * Stop firing. Idempotent — safe to call when not running.
   * Preserves tickCount + lastTickAt for post-mortem inspection.
   */
  stop(): void {
    if (this.timer !== null) {
      clearInterval(this.timer);
      this.timer = null;
    }
  }

  /**
   * F-025 register an idle-archival callback. The callback fires from
   * tick() whenever the measured gap from the prior lastTickAt
   * exceeds the configured `archiveAfterMinutes`. Callbacks compose
   * (broadcast pattern); unregister is not currently supported (kept
   * minimal — the F-025 v1 contract is fire-only).
   */
  onIdleArchive(callback: IdleArchiveCallback): void {
    this.archiveCallbacks.push(callback);
  }

  /**
   * Trigger a single tick. Public so tests + manual-mode callers can
   * drive the handler without setInterval. Returns the handler's
   * promise so `await tick()` is meaningful.
   *
   * F-024 same-schedule re-entry guard: if a prior tick is still in
   * flight (handler hasn't resolved), this call is recorded as
   * skipped and returns `{ ran: false, skipped: true }` without
   * invoking the handler. The tick counter is NOT incremented for
   * skipped ticks — only the skip counter — and the handler is not
   * invoked again. Cross-schedule independence is by-design: separate
   * HeartbeatScheduler instances per schedule.
   *
   * F-025 idle-archival: when configured `archiveAfterMinutes` is set
   * AND a prior lastTickAt exists, the gap (now - prior) in minutes
   * is computed; if it exceeds the threshold, every registered
   * onIdleArchive callback is invoked with the measured idleMinutes
   * BEFORE the handler runs. Idle is measured from the PRIOR
   * lastTickAt, not from scheduler creation — so the first tick after
   * construction never fires the callback.
   *
   * If no handler is registered (tick before start, used in tests),
   * the counter still increments — this is the manual-test
   * affordance, mirroring how F-018's HaltDetector counters increment
   * regardless of caller plumbing.
   */
  async tick(): Promise<TickResult> {
    // F-024: skip if a prior tick is still in flight.
    if (this.tickInFlight) {
      this.skippedTicks++;
      return { ran: false, skipped: true };
    }

    // F-025: measure idle gap BEFORE updating lastTickAt so callbacks
    // see the gap from prior-to-now (not zero).
    const priorTickAt = this.lastTickAt;
    const now = new Date();
    if (
      this.config.archiveAfterMinutes != null &&
      priorTickAt !== null
    ) {
      const idleMs = now.getTime() - priorTickAt.getTime();
      const idleMinutes = idleMs / 60_000;
      if (idleMinutes >= this.config.archiveAfterMinutes) {
        for (const cb of this.archiveCallbacks) {
          cb(idleMinutes);
        }
      }
    }

    this.tickInFlight = true;
    try {
      this.lastTickAt = now;
      this.tickCount++;
      if (this.tickHandler !== null) {
        await this.tickHandler();
      }
      return { ran: true };
    } finally {
      // Clear in-flight even on throw — otherwise a single failed
      // tick would permanently block subsequent ticks (silent halt).
      this.tickInFlight = false;
    }
  }

  /** Snapshot of scheduler state (F-023 + F-024 fields). */
  getStatus(): HeartbeatStatus {
    return {
      isRunning: this.timer !== null,
      tickCount: this.tickCount,
      lastTickAt: this.lastTickAt,
      intervalSeconds: this.intervalSeconds,
      skippedTicks: this.skippedTicks,
      isInFlight: this.tickInFlight,
    };
  }
}
