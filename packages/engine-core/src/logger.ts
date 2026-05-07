/**
 * F-006 Logging pipeline — GREEN (in-memory boundary primitive).
 *
 * Per docs/03-feature-catalog/M0-bootstrap/F-006-logging-pipeline.md.
 * Behavior contract scoped to wave-9 / lane-a: a structured-logging facade
 * that emits LogEvent records to an injectable sink. Each event carries
 * `{timestamp, level, event, ...ctx}` with the four common levels
 * (debug | info | warn | error). Level-gating drops events below the
 * configured threshold; context fields merge onto the record so callers can
 * stamp `agent_id`, `run_id`, `cycle`, etc. without nesting.
 *
 * Split from index.ts in wave-011/lane-a (cross-lane staging race elimination).
 */

/**
 * Recognized log levels in order of severity. Per the F-006 ledger the full
 * level set is `trace | debug | info | warn | error | fatal`; this minimal
 * flip implements the four common levels per the brief's TypeScript hint.
 * Extending to six is straightforward and lives in a follow-on flip.
 */
export type LogLevel = 'debug' | 'info' | 'warn' | 'error';

/**
 * A single emitted log record. Reserved keys: `timestamp`, `level`, `event`.
 * All caller-supplied context fields merge onto the record at the top level
 * — minimum-change discipline per the brief's hint. The F-008 storage flip
 * will serialize these records line-by-line to `runs/<run_id>/log.ndjson`;
 * the F-015 audit integration will route them through `appendAuditEntry`.
 */
export interface LogEvent {
  /** ISO-8601 UTC timestamp (e.g. "2026-05-07T00:04:25.123Z"). */
  timestamp: string;
  /** One of `LogLevel`. */
  level: LogLevel;
  /** Short event name in dot-segment form (e.g. `cycle.start`, `audit.write.failed`). */
  event: string;
  /** Caller-supplied context fields merged onto the record. */
  [key: string]: unknown;
}

/**
 * The four-method logging facade. Each method takes an event name and an
 * optional context bag whose fields merge onto the emitted LogEvent.
 *
 * Per `rules/canonical-skill-only.md`-style discipline (the F-006 ledger's
 * "ONLY supported way to emit logs from engine-core" clause), engine-core
 * code should reach for this facade — direct `console.log` is forbidden by
 * the no-console lint rule (acceptance scenario 2 of the ledger; ESLint
 * config not runtime).
 */
export interface Logger {
  debug(event: string, ctx?: Record<string, unknown>): void;
  info(event: string, ctx?: Record<string, unknown>): void;
  warn(event: string, ctx?: Record<string, unknown>): void;
  error(event: string, ctx?: Record<string, unknown>): void;
}

/** Numeric ordering for level-gating — `debug < info < warn < error`. */
const LOG_LEVEL_ORDER: Record<LogLevel, number> = {
  debug: 0,
  info: 1,
  warn: 2,
  error: 3,
};

/**
 * Default sink — emits the LogEvent as a single JSON-stringified line on
 * stdout. The brief specifies this default; it gives the facade a working
 * out-of-the-box shape for headless smoke tests. Production callers (engine
 * cycles, audit integrations) will inject custom sinks per scenario 4.
 *
 * Reach for `console.log` here is the ONE permitted use — it's the default
 * sink BEHIND the facade, not engine code emitting log events. The
 * no-console lint rule will scope its allowlist accordingly.
 */
function defaultSink(event: LogEvent): void {
  // eslint-disable-next-line no-console -- default sink only; engine code MUST use the Logger facade.
  console.log(JSON.stringify(event));
}

/**
 * Create a structured-logging facade.
 *
 * Acceptance scenarios from the F-006 ledger + wave-9 / lane-a brief:
 *   1. `logger.info('cycle.start', { cycle: 3 })` → LogEvent with timestamp,
 *      level=info, event='cycle.start', cycle=3.
 *   2. Level-gating: min-level `warn` drops debug/info; emits warn/error.
 *   3. Context fields merge: caller-supplied keys (agent_id, run_id, cycle,
 *      reason, ...) appear at the top level of the emitted record.
 *   4. Sink injection: custom sink receives every event; default `console.log`
 *      sink is NOT invoked when a sink is provided.
 *
 * @param level - minimum level to emit (default `info`); events at lower
 *                severity are dropped.
 * @param sink  - injectable sink invoked once per emitted event (default
 *                JSON-stringified stdout).
 * @returns a `Logger` whose `debug`/`info`/`warn`/`error` methods route
 *          through the level-gate and sink.
 */
export function createLogger(
  level: LogLevel = 'info',
  sink: (event: LogEvent) => void = defaultSink,
): Logger {
  const minOrder = LOG_LEVEL_ORDER[level];

  const emit = (
    levelOfCall: LogLevel,
    eventName: string,
    ctx: Record<string, unknown> = {},
  ): void => {
    if (LOG_LEVEL_ORDER[levelOfCall] < minOrder) {
      return; // level-gating: drop below threshold (scenario 2).
    }
    // Build the LogEvent. Reserved keys (`timestamp`, `level`, `event`) win
    // over any same-named ctx keys — the ctx spread happens FIRST, then
    // reserved keys overwrite. This keeps the contract stable: callers
    // can't accidentally shadow the canonical fields by passing
    // `{ level: 'info' }` in ctx.
    const record: LogEvent = {
      ...ctx,
      timestamp: new Date().toISOString(),
      level: levelOfCall,
      event: eventName,
    };
    sink(record);
  };

  return {
    debug: (event, ctx) => emit('debug', event, ctx),
    info: (event, ctx) => emit('info', event, ctx),
    warn: (event, ctx) => emit('warn', event, ctx),
    error: (event, ctx) => emit('error', event, ctx),
  };
}
