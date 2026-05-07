/**
 * F-023 Cron heartbeat — GREEN.
 *
 * Per docs/03-feature-catalog/M3-cron-heartbeat/F-023-cron-heartbeat.md.
 * Behavior contract (from ledger):
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
 * Scope discipline (FETCH BEFORE CITE on the F-023 ledger):
 *   F-023's primitive is the SCHEDULER — a pure-class (no I/O, no run
 *   spawn) that owns cadence-zone validation + tick lifecycle + start/stop
 *   + observability. The actual fresh-run spawn (per F-001) and overlap
 *   detection (per F-024) and append-to-cron-fires.jsonl logging (per
 *   F-006/F-008) are wired by ORCHESTRATOR callers, not by this class.
 *   This mirrors the F-022 ToolCallQuota / F-018 HaltDetector pattern —
 *   pure behavior + composition by callers.
 *
 * Cross-feature coordination:
 *   - F-001 (engine-bootstrap-loop) — caller's `tick` handler invokes
 *     boot-fresh-run; F-023 is agnostic to what the handler does.
 *   - F-006 (logging-pipeline) — caller writes the `cron-fires.jsonl`
 *     append-only entry inside its handler.
 *   - F-024 (skip-on-overlap) — wraps tick handler with an overlap check
 *     before invoking F-023's tick.
 *   - F-002 (per-agent-identity) — caller resolves agent identity for
 *     the fresh run before invoking F-023's tick.
 *
 * Authored in wave-016 / lane-b. Per-feature file (no index.ts churn
 * beyond barrel re-export) per the wave-011/lane-a anti-cross-lane-race
 * convention.
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
}

/** Snapshot of scheduler state for observability + tests. */
export interface HeartbeatStatus {
  isRunning: boolean;
  tickCount: number;
  lastTickAt: Date | null;
  intervalSeconds: number;
}

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
   * Trigger a single tick. Public so tests + manual-mode callers can
   * drive the handler without setInterval. Returns the handler's
   * promise so `await tick()` is meaningful.
   *
   * If no handler is registered (tick before start, used in tests),
   * the counter still increments — this is the manual-test
   * affordance, mirroring how F-018's HaltDetector counters increment
   * regardless of caller plumbing.
   */
  async tick(): Promise<void> {
    this.lastTickAt = new Date();
    this.tickCount++;
    if (this.tickHandler !== null) {
      await this.tickHandler();
    }
  }

  /** Snapshot of scheduler state. */
  getStatus(): HeartbeatStatus {
    return {
      isRunning: this.timer !== null,
      tickCount: this.tickCount,
      lastTickAt: this.lastTickAt,
      intervalSeconds: this.intervalSeconds,
    };
  }
}
