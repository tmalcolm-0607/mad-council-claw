/**
 * F-030 cli-json-output — `--json` flag detection + JSON envelope primitives.
 *
 * Authored wave-017 / lane-d (per docs/03-feature-catalog/M4-headless-cli/
 * F-030-json-output.md). Composes against F-028's `runCli` surface + F-029's
 * `standardSubcommands` registry without touching either — the wave-011/
 * lane-a "shared types live with their FIRST owner" convention applies.
 *
 * v1 / wave-017 scope is intentionally MINIMUM-VIABLE PRIMITIVES:
 *   - `hasJsonFlag(args)` — exact-equality `--json` detection (substring
 *     flags like `--jsonpath` / `--no-json` do NOT match)
 *   - `stripJsonFlag(args)` — removes ALL `--json` instances preserving
 *     order of remaining args
 *   - `emitJson(output)` — writes a single JSON line to stdout terminated
 *     by exactly one `\n`
 *   - `JsonOutput` — `{ ok: boolean, data?: unknown, error?: string }`
 *     envelope (deliberately minimal so downstream features can extend)
 *
 * Per-subcommand schemas, NDJSON streaming for `audit query` (50k-entry
 * runs, <200MB memory bound), sysexits.h exit codes (e.g. 65 EX_DATAERR),
 * and rich error envelopes are all DEFERRED to subsequent M4+ features
 * per `no-silent-deferrals.md`. The minimum-viable envelope here covers
 * the structural contract so downstream features extend without
 * re-shaping.
 *
 * Integration with F-028's `runCli`: when the dispatcher detects `--json`
 * in the post-subcommand-name args, it strips the flag before forwarding
 * to the matched subcommand. The subcommand never sees `--json` directly;
 * cross-cutting JSON-mode wrap is the orchestrator's responsibility.
 * The detection / strip helpers are exported so subcommands that emit
 * structured output can call them too if needed in the future.
 */

/**
 * Structured JSON output envelope. Every CLI subcommand operating in
 * `--json` mode SHOULD emit exactly one line of this shape (or NDJSON
 * for streaming subcommands when those land in a future feature).
 */
export interface JsonOutput {
  /** True if the operation succeeded; false otherwise. */
  ok: boolean;
  /** Operation-specific payload on success. Type narrowed by callers. */
  data?: unknown;
  /** Human-readable error message on failure. */
  error?: string;
}

/**
 * Returns true if the `--json` flag is present anywhere in args.
 * Exact-equality match — substring flags (`--jsonpath`, `--no-json`)
 * are NOT detected.
 */
export function hasJsonFlag(args: string[]): boolean {
  return args.includes('--json');
}

/**
 * Returns a new array with all `--json` entries removed, preserving
 * the order of remaining args. The original array is not mutated.
 */
export function stripJsonFlag(args: string[]): string[] {
  return args.filter((a) => a !== '--json');
}

/**
 * Writes the envelope as a single JSON line to stdout, terminated
 * by exactly one trailing newline. Output is parseable by any
 * standard JSON consumer (jq, JSON.parse, etc.) — never embeds
 * ANSI codes or shell-formatting characters.
 */
export function emitJson(output: JsonOutput): void {
  process.stdout.write(JSON.stringify(output) + '\n');
}
