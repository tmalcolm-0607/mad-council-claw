/**
 * F-029 cli-subcommands — standard subcommand registry.
 *
 * Authored wave-017 / lane-d (per docs/03-feature-catalog/M4-headless-cli/
 * F-029-subcommands.md). Composes against F-028's `Subcommand` callable
 * type without touching it — the wave-011/lane-a "shared types live with
 * their FIRST owner" convention applies.
 *
 * v1 / wave-017 scope is intentionally MINIMUM-VIABLE STUBS. Each of the
 * 9 non-special subcommands prints a deterministic "F-029 stub: subcommand
 * '<name>' (args: ...) — implementation deferred ..." line + returns 0.
 * `version` emits the literal "0.0.0\n" + returns 0; `help` emits a
 * help-pointer line + returns 0.
 *
 * Real implementations are deferred to subsequent M4+ features per
 * `no-silent-deferrals.md`:
 *   - `start` / `status` / `halt` invoke the F-001 engine kernel
 *   - `query-audit` invokes F-016's audit query API
 *   - `archive` / `restore` use F-008's storage layer
 *   - `replay` invokes F-031's daemon if present, else fallback
 *   - `retro` invokes F-014's retro hooks
 *   - `list-sessions` reads F-002's session registry
 *   - all output-bearing variants will integrate with F-030 `--json`
 *     mode when their concrete behavior lands
 *
 * The 11 v1 names are the closed contract — no extensions in this
 * registry without a new feature ledger entry.
 */

import type { Subcommand } from './index.js';

const stub = (name: string): Subcommand =>
  async (args: string[]): Promise<number> => {
    const argsStr = args.length === 0 ? 'none' : args.join(' ');
    process.stdout.write(
      `F-029 stub: subcommand '${name}' (args: ${argsStr}) — implementation deferred to subsequent M4+ features\n`,
    );
    return 0;
  };

const versionSubcommand: Subcommand = async (_args: string[]): Promise<number> => {
  process.stdout.write('0.0.0\n');
  return 0;
};

const helpSubcommand: Subcommand = async (_args: string[]): Promise<number> => {
  process.stdout.write(
    "See `nested-quilt --help` for top-level help; run `nested-quilt <subcommand> --help` for subcommand-specific help (when subcommands implement their own help).\n",
  );
  return 0;
};

/**
 * The closed v1 set of canonical subcommand names. Adding a new name
 * requires a new feature ledger entry (per the F-029 ledger's
 * `out-of-scope-notes` — plugin-style subcommand extensibility is v1.5).
 */
export const standardSubcommands: Record<string, Subcommand> = {
  start: stub('start'),
  status: stub('status'),
  halt: stub('halt'),
  retro: stub('retro'),
  replay: stub('replay'),
  'query-audit': stub('query-audit'),
  'list-sessions': stub('list-sessions'),
  archive: stub('archive'),
  restore: stub('restore'),
  version: versionSubcommand,
  help: helpSubcommand,
};
