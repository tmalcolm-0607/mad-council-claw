import { describe, it, expect, beforeEach, afterEach, vi } from 'vitest';
import { runCli, type CliOptions, type Subcommand } from '@mad-council-claw/cli';

/**
 * F-028 RED → GREEN test (tests/node — Node-environment).
 * Per docs/03-feature-catalog/M4-headless-cli/F-028-cli-entry.md
 * acceptance scenarios + wave-016 lane-c brief.
 *
 * Behavior contract (from ledger):
 *   The headless CLI is a single executable entrypoint (`nested-quilt`)
 *   that exposes the engine's run lifecycle via subcommand dispatch.
 *   Each subcommand may receive its own args; root invocation prints
 *   help; unknown subcommand prints stderr message + help and returns
 *   a non-zero exit code.
 *
 * This RED test author runs BEFORE packages/cli/src/index.ts is created,
 * so all imports fail at the boundary. Once index.ts exists exporting
 * `runCli`, `CliOptions`, `Subcommand`, the same test file flips to GREEN.
 *
 * Wired-down acceptance scenarios (5+; F-028 ledger lists 3 broader
 * acceptance scenarios — these test the entry+dispatcher scaffold;
 * subcommand-specific behavior is F-029 territory):
 *
 *   1. runCli with no args returns exit 0 and prints root help to stdout.
 *   2. runCli with --help returns exit 0 and prints root help to stdout.
 *   3. runCli with -h returns exit 0 and prints root help to stdout.
 *   4. runCli with unknown subcommand returns exit 1 and writes error
 *      message to stderr (the F-028 ledger §Acceptance scenario 2
 *      specifies exit code 64 / EX_USAGE, but the v1 scaffold uses 1
 *      until the F-029 subcommand layer normalizes exit codes — see
 *      §Implementation notes in the F-028 ledger).
 *   5. runCli with a registered subcommand returns the subcommand's
 *      return code and forwards remaining args to the subcommand.
 *   6. Subcommand args (everything after the subcommand name) flow
 *      through to the registered Subcommand callable.
 */

describe('F-028 cli-entry — runCli entry + dispatcher', () => {
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

  function makeNoopSubcommand(returnCode = 0): Subcommand {
    return async (_args: string[]) => returnCode;
  }

  it('scenario 1: runCli with no args returns exit 0 and prints root help', async () => {
    const opts: CliOptions = {
      subcommands: { run: makeNoopSubcommand(), version: makeNoopSubcommand() },
    };
    // argv shape mirrors process.argv: [node, script, ...userArgs]
    const code = await runCli(['node', '/path/to/cli'], opts);
    expect(code).toBe(0);
    const stdout = stdoutChunks.join('');
    expect(stdout).toMatch(/nested-quilt/);
    expect(stdout).toMatch(/Subcommands/);
    expect(stdout).toMatch(/run/);
    expect(stdout).toMatch(/version/);
  });

  it('scenario 2: --help returns exit 0 and prints root help', async () => {
    const opts: CliOptions = { subcommands: { run: makeNoopSubcommand() } };
    const code = await runCli(['node', '/path/to/cli', '--help'], opts);
    expect(code).toBe(0);
    expect(stdoutChunks.join('')).toMatch(/Usage:.*nested-quilt/);
  });

  it('scenario 3: -h returns exit 0 and prints root help', async () => {
    const opts: CliOptions = { subcommands: { run: makeNoopSubcommand() } };
    const code = await runCli(['node', '/path/to/cli', '-h'], opts);
    expect(code).toBe(0);
    expect(stdoutChunks.join('')).toMatch(/Usage:.*nested-quilt/);
  });

  it('scenario 4: unknown subcommand returns non-zero exit and writes stderr', async () => {
    const opts: CliOptions = { subcommands: { run: makeNoopSubcommand() } };
    const code = await runCli(['node', '/path/to/cli', 'fooble'], opts);
    expect(code).not.toBe(0);
    const stderr = stderrChunks.join('');
    expect(stderr).toMatch(/unknown subcommand/i);
    expect(stderr).toMatch(/fooble/);
  });

  it('scenario 5: registered subcommand return code is propagated', async () => {
    const opts: CliOptions = {
      subcommands: {
        ok: makeNoopSubcommand(0),
        fail: makeNoopSubcommand(7),
      },
    };
    expect(await runCli(['node', '/path/to/cli', 'ok'], opts)).toBe(0);
    expect(await runCli(['node', '/path/to/cli', 'fail'], opts)).toBe(7);
  });

  it('scenario 6: subcommand receives remaining args after subcommand name', async () => {
    const captured: string[][] = [];
    const opts: CliOptions = {
      subcommands: {
        echo: async (args: string[]) => {
          captured.push(args);
          return 0;
        },
      },
    };
    const code = await runCli(['node', '/path/to/cli', 'echo', '--flag', 'value', 'positional'], opts);
    expect(code).toBe(0);
    expect(captured).toEqual([['--flag', 'value', 'positional']]);
  });

  it('scenario 7: programName override surfaces in help output', async () => {
    const opts: CliOptions = {
      subcommands: { run: makeNoopSubcommand() },
      programName: 'mad-council-cli',
    };
    const code = await runCli(['node', '/path/to/cli'], opts);
    expect(code).toBe(0);
    expect(stdoutChunks.join('')).toMatch(/mad-council-cli/);
  });
});
