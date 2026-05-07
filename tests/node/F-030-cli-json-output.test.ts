import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { runCli, type CliOptions, type Subcommand } from '@mad-council-claw/cli';
import {
  hasJsonFlag,
  stripJsonFlag,
  emitJson,
  type JsonOutput,
} from '@mad-council-claw/cli/json-output';

/**
 * F-030 RED → GREEN test (tests/node — Node-environment).
 * Per docs/03-feature-catalog/M4-headless-cli/F-030-json-output.md
 * acceptance scenarios + wave-017 lane-d brief.
 *
 * Behavior contract (from ledger):
 *   Every subcommand supports `--format json` (or in the wave-017
 *   minimum-viable shape, `--json` flag detection at the dispatcher
 *   layer). When `--json` is present, output is a single JSON line
 *   with shape `{ ok, data?, error? }`. Stripped flag does not flow
 *   into the subcommand's args.
 *
 * Scope deviation acknowledged openly per `no-silent-deferrals.md`:
 * the F-030 ledger §Acceptance scenarios envision rich envelopes
 * (per-subcommand schemas, NDJSON streaming for `audit query`
 * 50k-entry runs, sysexits.h exit codes — e.g. 65 EX_DATAERR for
 * missing-run lookups). v1 / wave-017 ships THE FLAG-DETECTION +
 * EMIT PRIMITIVES only — the per-subcommand schemas + NDJSON
 * streaming are deferred to subsequent M4+ features when concrete
 * subcommand behavior lands. The minimum-viable envelope covers
 * the structural contract (ok/data/error) so downstream features
 * can extend without re-shaping. Recorded in F-030 ledger
 * §Implementation notes when this RED test flips GREEN.
 *
 * Wired-down acceptance scenarios (5+):
 *   1. hasJsonFlag detects `--json` anywhere in args, returns false otherwise.
 *   2. stripJsonFlag removes `--json` while preserving order of remaining args.
 *   3. emitJson writes a single valid JSON line to stdout (terminated by \n).
 *   4. JsonOutput envelope shape: { ok: boolean, data?: unknown, error?: string }.
 *   5. runCli with `--json` strips the flag before passing to the subcommand
 *      (the subcommand never sees `--json` in its args).
 *   6. emitJson handles ok=true with data correctly (parseable JSON, ok=true).
 *   7. emitJson handles ok=false with error correctly (parseable JSON, ok=false).
 */

describe('F-030 cli-json-output — JSON envelope + flag handling', () => {
  let stdoutChunks: string[];
  let stdoutSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    stdoutChunks = [];
    stdoutSpy = vi.spyOn(process.stdout, 'write').mockImplementation(((chunk: string | Uint8Array) => {
      stdoutChunks.push(typeof chunk === 'string' ? chunk : Buffer.from(chunk).toString('utf8'));
      return true;
    }) as typeof process.stdout.write);
  });

  afterEach(() => {
    stdoutSpy.mockRestore();
  });

  it('scenario 1: hasJsonFlag detects --json anywhere in args', () => {
    expect(hasJsonFlag([])).toBe(false);
    expect(hasJsonFlag(['--config', './c.json'])).toBe(false);
    expect(hasJsonFlag(['--json'])).toBe(true);
    expect(hasJsonFlag(['--config', './c.json', '--json'])).toBe(true);
    expect(hasJsonFlag(['--json', '--config', './c.json'])).toBe(true);
    expect(hasJsonFlag(['arg1', '--json', 'arg2'])).toBe(true);
    // Substring of another flag should NOT match — exact-equality only.
    expect(hasJsonFlag(['--jsonpath'])).toBe(false);
    expect(hasJsonFlag(['--no-json'])).toBe(false);
  });

  it('scenario 2: stripJsonFlag removes --json preserving order', () => {
    expect(stripJsonFlag([])).toEqual([]);
    expect(stripJsonFlag(['--json'])).toEqual([]);
    expect(stripJsonFlag(['--config', './c.json'])).toEqual(['--config', './c.json']);
    expect(stripJsonFlag(['--json', 'arg1', 'arg2'])).toEqual(['arg1', 'arg2']);
    expect(stripJsonFlag(['arg1', '--json', 'arg2'])).toEqual(['arg1', 'arg2']);
    expect(stripJsonFlag(['arg1', 'arg2', '--json'])).toEqual(['arg1', 'arg2']);
    // Multiple --json instances all stripped.
    expect(stripJsonFlag(['--json', 'mid', '--json'])).toEqual(['mid']);
    // Substring-flags preserved.
    expect(stripJsonFlag(['--jsonpath', '--json', '--no-json'])).toEqual(['--jsonpath', '--no-json']);
  });

  it('scenario 3: emitJson writes a single valid JSON line to stdout terminated by \\n', () => {
    const output: JsonOutput = { ok: true, data: { msg: 'hello' } };
    emitJson(output);
    const written = stdoutChunks.join('');
    expect(written.endsWith('\n')).toBe(true);
    // Exactly one newline at the end (the line terminator).
    expect(written.match(/\n/g)?.length).toBe(1);
    const lineWithoutNewline = written.slice(0, -1);
    const parsed = JSON.parse(lineWithoutNewline);
    expect(parsed).toEqual({ ok: true, data: { msg: 'hello' } });
  });

  it('scenario 4: JsonOutput envelope accepts ok/data/error fields', () => {
    // Type-witness scenario: each of these constructs is a valid JsonOutput.
    const a: JsonOutput = { ok: true };
    const b: JsonOutput = { ok: true, data: 'string-data' };
    const c: JsonOutput = { ok: true, data: { nested: { value: 42 } } };
    const d: JsonOutput = { ok: false, error: 'something failed' };
    const e: JsonOutput = { ok: false, error: 'failed', data: { partial: true } };
    // Runtime witness: emit each + parse round-trips.
    for (const sample of [a, b, c, d, e]) {
      stdoutChunks.length = 0;
      emitJson(sample);
      const written = stdoutChunks.join('');
      const parsed = JSON.parse(written);
      expect(parsed).toEqual(sample);
    }
  });

  it('scenario 5: runCli with --json strips the flag before passing to the subcommand', async () => {
    const captured: string[][] = [];
    const echo: Subcommand = async (args: string[]) => {
      captured.push(args);
      return 0;
    };
    const opts: CliOptions = { subcommands: { echo } };
    // --json before positional args
    const code1 = await runCli(['node', '/path/to/cli', 'echo', '--json', '--flag', 'value'], opts);
    expect(code1).toBe(0);
    // --json sandwiched between positional args
    const code2 = await runCli(['node', '/path/to/cli', 'echo', '--flag', '--json', 'value'], opts);
    expect(code2).toBe(0);
    // --json at end
    const code3 = await runCli(['node', '/path/to/cli', 'echo', '--flag', 'value', '--json'], opts);
    expect(code3).toBe(0);
    // No --json present
    const code4 = await runCli(['node', '/path/to/cli', 'echo', '--flag', 'value'], opts);
    expect(code4).toBe(0);

    // All four invocations should have given the subcommand the SAME stripped args.
    expect(captured).toHaveLength(4);
    for (const args of captured) {
      expect(args).toEqual(['--flag', 'value']);
      expect(args).not.toContain('--json');
    }
  });

  it('scenario 6: emitJson with ok=true + data round-trips through JSON.parse', () => {
    const sample: JsonOutput = {
      ok: true,
      data: { run_id: 'r-123', cycle_count: 5, lifecycle: 'active' },
    };
    emitJson(sample);
    const parsed = JSON.parse(stdoutChunks.join(''));
    expect(parsed.ok).toBe(true);
    expect(parsed.data).toEqual({ run_id: 'r-123', cycle_count: 5, lifecycle: 'active' });
    expect(parsed.error).toBeUndefined();
  });

  it('scenario 7: emitJson with ok=false + error round-trips through JSON.parse', () => {
    const sample: JsonOutput = {
      ok: false,
      error: 'RUN_NOT_FOUND: run id not present in storage',
    };
    emitJson(sample);
    const parsed = JSON.parse(stdoutChunks.join(''));
    expect(parsed.ok).toBe(false);
    expect(parsed.error).toBe('RUN_NOT_FOUND: run id not present in storage');
    expect(parsed.data).toBeUndefined();
  });
});
