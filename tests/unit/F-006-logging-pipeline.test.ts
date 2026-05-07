import { describe, it, expect, vi } from 'vitest';
import {
  createLogger,
  type LogEvent,
  type LogLevel,
  type Logger,
} from '@mad-council-claw/engine-core';

/**
 * F-006 RED → GREEN test.
 * Per docs/03-feature-catalog/M0-bootstrap/F-006-logging-pipeline.md
 * acceptance scenarios. Authored RED-first per the wave-5 retro proposal so
 * the transition has a real before/after pair.
 *
 * Behavior contract scoped to wave-9 / lane-a (in-memory boundary primitive):
 *   The structured-logging facade emits LogEvent records to an injectable
 *   sink. Each event carries `{timestamp, level, event, ...ctx}`. Levels are
 *   `debug | info | warn | error`. The facade is the boundary the F-015 audit
 *   chain (already GREEN, wave-008/lane-b) and F-008 storage layout will
 *   later compose against — currently those integrations are deferred per
 *   the F-006 ledger §dependencies (F-001 + F-002 + F-008 hard; F-015 soft).
 *
 * Acceptance scenarios mirrored from the ledger + extended for the four
 * level methods + level-gating contract:
 *   1. (ledger §1) `logger.info('cycle.start', { cycle: 3 })` produces a
 *      LogEvent with `event: 'cycle.start'`, `level: 'info'`, `cycle: 3`,
 *      and an ISO-8601 timestamp.
 *   2. Level-gating: a logger created with min-level `warn` drops `debug`
 *      and `info` calls; emits `warn` and `error`.
 *   3. Context fields merge: `logger.error('boom', { agent_id: 'a1', cycle: 7 })`
 *      produces a LogEvent whose `agent_id` and `cycle` keys appear at the
 *      top level alongside `timestamp`/`level`/`event` (ledger contract:
 *      "every entry carries `{run_id, agent_id, ...timestamp, level,
 *      event_name, fields}`" — this minimal flip flattens fields onto the
 *      record per the brief's TypeScript hint; the ledger's nested-fields
 *      shape lands in F-008's storage flip when the on-disk ndjson row is
 *      written).
 *   4. Sink injection: a custom sink function receives every emitted event
 *      and is the only side-effect path (no `console.log` from the facade
 *      itself when a sink is provided).
 *
 * Out of scope (per the F-006 ledger and `rules/no-silent-deferrals.md`):
 *   - Filesystem write to `runs/<run_id>/log.ndjson` (F-008 storage layout).
 *   - Hash-chained audit composition (F-015 — the chain primitive lives in
 *     engine-core; the integration is a follow-on feature).
 *   - `no-console` lint rule (acceptance scenario 2 of the ledger). That
 *     scenario is enforced by ESLint config, not by a runtime test.
 *   - Degradation signal when the audit-log writer is offline (acceptance
 *     scenario 3 of the ledger). Requires the audit-log integration which
 *     is itself out of scope above; tracked as a follow-on.
 *   - Level extensions `trace` and `fatal` (the ledger lists six levels;
 *     this minimal flip implements the four common levels per the brief).
 *     Extending to six is straightforward and lives in a follow-on.
 */
const ISO_TIMESTAMP_REGEX = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z$/;

describe('F-006 logging-pipeline', () => {
  it('scenario 1: logger.info emits LogEvent with timestamp + level + event + context', () => {
    const sink = vi.fn<(e: LogEvent) => void>();
    const logger: Logger = createLogger('debug', sink);

    logger.info('cycle.start', { cycle: 3 });

    expect(sink).toHaveBeenCalledTimes(1);
    const event = sink.mock.calls[0][0];
    expect(event.event).toBe('cycle.start');
    expect(event.level).toBe('info');
    expect(event.timestamp).toMatch(ISO_TIMESTAMP_REGEX);
    // Context fields appear at the top level alongside timestamp/level/event.
    expect(event.cycle).toBe(3);
  });

  it('scenario 2: level-gating drops events below the configured threshold', () => {
    const sink = vi.fn<(e: LogEvent) => void>();
    const logger: Logger = createLogger('warn', sink);

    logger.debug('drop.me.1');
    logger.info('drop.me.2');
    logger.warn('keep.me.1');
    logger.error('keep.me.2');

    expect(sink).toHaveBeenCalledTimes(2);
    const levels = sink.mock.calls.map((c) => c[0].level);
    expect(levels).toEqual<LogLevel[]>(['warn', 'error']);
    const events = sink.mock.calls.map((c) => c[0].event);
    expect(events).toEqual(['keep.me.1', 'keep.me.2']);
  });

  it('scenario 3: context fields merge onto the LogEvent record', () => {
    const sink = vi.fn<(e: LogEvent) => void>();
    const logger: Logger = createLogger('debug', sink);

    logger.error('audit.write.failed', {
      agent_id: 'a1',
      run_id: 'r1',
      cycle: 7,
      reason: 'sink offline',
    });

    expect(sink).toHaveBeenCalledTimes(1);
    const event = sink.mock.calls[0][0];
    expect(event.event).toBe('audit.write.failed');
    expect(event.level).toBe('error');
    expect(event.agent_id).toBe('a1');
    expect(event.run_id).toBe('r1');
    expect(event.cycle).toBe(7);
    expect(event.reason).toBe('sink offline');
    // The reserved keys still hold their canonical meanings.
    expect(event.timestamp).toMatch(ISO_TIMESTAMP_REGEX);
  });

  it('scenario 4: sink injection — every emitted event flows through the injected sink only', () => {
    const captured: LogEvent[] = [];
    const customSink = (e: LogEvent) => captured.push(e);
    const logger: Logger = createLogger('debug', customSink);

    // Spy on console.log to confirm the facade does NOT fall back to it
    // when a custom sink is provided.
    const consoleSpy = vi.spyOn(console, 'log').mockImplementation(() => {});
    try {
      logger.debug('a');
      logger.info('b');
      logger.warn('c');
      logger.error('d');
    } finally {
      consoleSpy.mockRestore();
    }

    expect(captured).toHaveLength(4);
    expect(captured.map((e) => e.event)).toEqual(['a', 'b', 'c', 'd']);
    expect(captured.map((e) => e.level)).toEqual<LogLevel[]>([
      'debug',
      'info',
      'warn',
      'error',
    ]);
    // The facade routed every event through the custom sink, not console.log.
    expect(consoleSpy).not.toHaveBeenCalled();
  });
});
