#!/usr/bin/env node
/**
 * F-028 cli-entry — `nested-quilt` CLI entry + subcommand dispatcher.
 *
 * Authored wave-016 / lane-c (per docs/03-feature-catalog/M4-headless-cli/
 * F-028-cli-entry.md). This is the entry + dispatcher scaffold; concrete
 * subcommands are wired in F-029 (subcommands), F-030 (json-output),
 * and F-031 (daemon-mode). The exit-code surface is intentionally
 * minimal here (0 / 1) — F-029 normalizes to sysexits.h conventions
 * (EX_USAGE = 64 for unknown subcommand, etc.) per the F-028 ledger.
 *
 * Module style: ESM, per packages/cli/package.json `type: "module"`.
 *
 * No I/O happens at import time. `runCli` is a pure async function that
 * receives argv and options; the only side effects are `process.stdout`
 * and `process.stderr` writes. Tests stub those streams via `vi.spyOn`
 * to assert behavior without launching real processes.
 *
 * The bottom-of-file `import.meta.url === ...` block makes the file
 * runnable directly via `node packages/cli/src/index.ts` (after a
 * future build/transpile step) or via `tsx`. v1 only ships the
 * library surface; binary wiring is package.json's `bin` field.
 */

import { stripJsonFlag } from './json-output.js';

export type Subcommand = (args: string[]) => Promise<number>;

export interface CliOptions {
  /** Map of subcommand name → handler. */
  subcommands: Record<string, Subcommand>;
  /** Optional: subcommand to use when none is named. v1 prints help instead. */
  defaultSubcommand?: string;
  /** Optional: program name shown in help output. Default 'nested-quilt'. */
  programName?: string;
}

/**
 * Dispatch CLI invocation per `argv` and `opts`.
 *
 * @param argv - Process argv shape: [node, script, ...userArgs].
 *               The first two entries are stripped by convention.
 * @param opts - Subcommand registry + optional metadata.
 * @returns Exit code (0 = success).
 */
export async function runCli(argv: string[], opts: CliOptions): Promise<number> {
  const args = argv.slice(2); // strip node + script
  const programName = opts.programName ?? 'nested-quilt';

  // Root invocation: no args, --help, or -h — print help, exit 0.
  if (args.length === 0 || args[0] === '--help' || args[0] === '-h') {
    printRootHelp(programName, opts);
    return 0;
  }

  const [subcommandName, ...subArgs] = args;
  const subcommand = opts.subcommands[subcommandName];
  if (!subcommand) {
    process.stderr.write(`${programName}: unknown subcommand '${subcommandName}'\n`);
    printRootHelp(programName, opts);
    return 1;
  }

  // F-030: strip --json before forwarding to subcommand. The subcommand
  // never sees the flag in its own args; orchestrator-level JSON-mode
  // detection is the responsibility of the caller (or a future wrapping
  // skill). hasJsonFlag(subArgs) here would let runCli wrap the
  // subcommand result in a JsonOutput envelope, but v1 keeps the shape
  // backward-compatible: just strip + forward. Concrete subcommand
  // wrapping lands when the first F-029 stub gets a real implementation.
  const forwarded = stripJsonFlag(subArgs);
  return await subcommand(forwarded);
}

function printRootHelp(programName: string, opts: CliOptions): void {
  process.stdout.write(`${programName} — MAD Council Claw CLI\n\n`);
  process.stdout.write(`Usage: ${programName} <subcommand> [options]\n\n`);
  process.stdout.write('Subcommands:\n');
  for (const name of Object.keys(opts.subcommands)) {
    process.stdout.write(`  ${name}\n`);
  }
  process.stdout.write('\n');
  process.stdout.write(`Run '${programName} <subcommand> --help' for subcommand-specific help.\n`);
}

// Direct-execution dispatcher (when this file is run as the script).
// In v1 only `version` is wired; F-029 expands the registry.
if (import.meta.url === `file://${process.argv[1]}`) {
  runCli(process.argv, {
    subcommands: {
      version: async () => {
        process.stdout.write('0.0.0\n');
        return 0;
      },
    },
  })
    .then((code) => process.exit(code))
    .catch((err) => {
      process.stderr.write(`nested-quilt: fatal: ${err?.message ?? err}\n`);
      process.exit(1);
    });
}
