import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { runCli, type CliOptions } from '@mad-council-claw/cli';
import { standardSubcommands } from '@mad-council-claw/cli/subcommands';

/**
 * F-029 RED → GREEN test (tests/node — Node-environment).
 * Per docs/03-feature-catalog/M4-headless-cli/F-029-subcommands.md
 * acceptance scenarios + wave-017 lane-d brief.
 *
 * Behavior contract (from ledger):
 *   The CLI exposes a canonical subcommand surface for the engine's
 *   run + automation lifecycle. v1 ships an enumerated set of names
 *   (start, status, halt, retro, replay, query-audit, list-sessions,
 *   archive, restore, version, help) — concrete behavior is layered
 *   in subsequent M4+ features. The wave-017 / lane-d brief explicitly
 *   ships MINIMUM-VIABLE STUBS that print a deterministic "stub:
 *   subcommand <name> ..." line + return 0 — every name is wired,
 *   every call returns 0, version emits "0.0.0".
 *
 * Scope deviation acknowledged openly per `no-silent-deferrals.md`:
 * the F-029 ledger §Acceptance scenarios envision real implementations
 * with arg parsing + sysexits.h exit codes (e.g. 64 EX_USAGE on
 * unknown subcommand). v1 / wave-017 ships stubs only — real
 * implementations are deferred to subsequent M4+ features (this is
 * the same scope-narrowing pattern that F-013 used vs the 9-variant
 * superset, F-012 used vs the env-var resolution). Recorded in the
 * F-029 ledger §Implementation notes when this RED test flips GREEN.
 *
 * Wired-down acceptance scenarios (8+):
 *   1. standardSubcommands exports an object with all 11 v1 names
 *      (start, status, halt, retro, replay, query-audit, list-sessions,
 *      archive, restore, version, help).
 *   2. Each of the 11 subcommands is callable as a Subcommand
 *      (async function returning Promise<number>) and returns 0.
 *   3. version subcommand emits "0.0.0\n" to stdout and returns 0.
 *   4. help subcommand emits a help-pointer line to stdout and returns 0.
 *   5. Stub subcommands (the 9 non-special ones) emit a literal
 *      "F-029 stub: subcommand '<name>'" line to stdout and return 0.
 *   6. Stub subcommand args echo back in the stub line (so callers
 *      can confirm the arg passthrough surface works).
 *   7. runCli with standardSubcommands wired in dispatches each name
 *      to its handler and propagates the 0 exit code.
 *   8. runCli with an unknown subcommand still returns non-zero (1
 *      per F-028's behavior contract; F-029's stub layer doesn't
 *      change that — exit-code-normalization to sysexits.h is a
 *      future-feature concern documented in F-028 ledger §Implementation
 *      notes scope-deviation #1 and re-flagged here).
 */

describe('F-029 cli-subcommands — standard subcommand registry', () => {
  let stdoutChunks: string[];
  let stderrChunks: string[];
  let stdoutSpy: ReturnType<typeof vi.spyOn>;
  let stderrSpy: ReturnType<typeof vi.spyOn>;

  beforeEach(() => {
    stdoutChunks = [];
    stderrChunks = [];
    stdoutSpy = vi.spyOn(process.stdout, 'write').mockImplementation(((chunk: string | Uint8Array) => {
      stdoutChunks.push(typeof chunk === 'string' ? chunk : Buffer.from(chunk).toString('utf8'));
      return true;
    }) as typeof process.stdout.write);
    stderrSpy = vi.spyOn(process.stderr, 'write').mockImplementation(((chunk: string | Uint8Array) => {
      stderrChunks.push(typeof chunk === 'string' ? chunk : Buffer.from(chunk).toString('utf8'));
      return true;
    }) as typeof process.stderr.write);
  });

  afterEach(() => {
    stdoutSpy.mockRestore();
    stderrSpy.mockRestore();
  });

  const expectedNames = [
    'start',
    'status',
    'halt',
    'retro',
    'replay',
    'query-audit',
    'list-sessions',
    'archive',
    'restore',
    'version',
    'help',
  ] as const;

  it('scenario 1: standardSubcommands exports all 11 v1 names', () => {
    expect(standardSubcommands).toBeDefined();
    expect(typeof standardSubcommands).toBe('object');
    for (const name of expectedNames) {
      expect(standardSubcommands).toHaveProperty(name);
      expect(typeof standardSubcommands[name]).toBe('function');
    }
    // No extra unexpected names — the registry is closed at v1 contract.
    expect(Object.keys(standardSubcommands).sort()).toEqual([...expectedNames].sort());
  });

  it('scenario 2: each subcommand is async and returns 0', async () => {
    for (const name of expectedNames) {
      const handler = standardSubcommands[name];
      const result = handler([]);
      expect(result).toBeInstanceOf(Promise);
      const code = await result;
      expect(code).toBe(0);
    }
  });

  it('scenario 3: version subcommand emits "0.0.0\\n" to stdout', async () => {
    const code = await standardSubcommands.version([]);
    expect(code).toBe(0);
    expect(stdoutChunks.join('')).toBe('0.0.0\n');
  });

  it('scenario 4: help subcommand emits a help-pointer line to stdout', async () => {
    const code = await standardSubcommands.help([]);
    expect(code).toBe(0);
    const stdout = stdoutChunks.join('');
    expect(stdout.length).toBeGreaterThan(0);
    expect(stdout).toMatch(/help/i);
  });

  it('scenario 5: stub subcommands emit deterministic "F-029 stub: subcommand \'<name>\'" line', async () => {
    // The 9 non-special names (everything except version + help) are stubs.
    const stubNames = expectedNames.filter((n) => n !== 'version' && n !== 'help');
    for (const name of stubNames) {
      stdoutChunks.length = 0;
      const code = await standardSubcommands[name]([]);
      expect(code).toBe(0);
      const stdout = stdoutChunks.join('');
      expect(stdout).toContain('F-029 stub');
      expect(stdout).toContain(`'${name}'`);
    }
  });

  it("scenario 6: stub subcommand passes args through into its stub-line echo", async () => {
    stdoutChunks.length = 0;
    const code = await standardSubcommands.start(['--config', './config.json', 'positional-arg']);
    expect(code).toBe(0);
    const stdout = stdoutChunks.join('');
    expect(stdout).toContain('F-029 stub');
    expect(stdout).toContain("'start'");
    // Args appear somewhere in the stub line so callers can confirm passthrough.
    expect(stdout).toMatch(/--config/);
    expect(stdout).toMatch(/config\.json/);
    expect(stdout).toMatch(/positional-arg/);
  });

  it('scenario 7: runCli dispatches every standardSubcommands name to its handler', async () => {
    const opts: CliOptions = { subcommands: standardSubcommands };
    for (const name of expectedNames) {
      stdoutChunks.length = 0;
      stderrChunks.length = 0;
      const code = await runCli(['node', '/path/to/cli', name], opts);
      expect(code).toBe(0);
      // Either help-text or stub-text or version-text is on stdout — never empty.
      expect(stdoutChunks.join('').length).toBeGreaterThan(0);
      // No stderr noise on a known subcommand.
      expect(stderrChunks.join('')).toBe('');
    }
  });

  it('scenario 8: runCli with unknown subcommand still returns non-zero (F-028 contract preserved)', async () => {
    const opts: CliOptions = { subcommands: standardSubcommands };
    const code = await runCli(['node', '/path/to/cli', 'definitely-not-a-subcommand'], opts);
    expect(code).not.toBe(0);
    expect(stderrChunks.join('')).toMatch(/unknown subcommand/i);
    expect(stderrChunks.join('')).toMatch(/definitely-not-a-subcommand/);
  });
});
