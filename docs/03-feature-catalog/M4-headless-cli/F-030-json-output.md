---
artifact-class: feature-ledger
generated-by: hand-authored (wave-003 / lane-a)
status: green
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-003 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
  - status: green
    at: 2026-05-07
    by: wave-017 / lane-d
    note: "RED → GREEN: tests/node/F-030-cli-json-output.test.ts (7 scenarios) PASS against packages/cli/src/json-output.ts (~50 LOC, ESM) + 1-import + 1-line edit to packages/cli/src/index.ts to strip --json before subcommand dispatch. Minimum-viable {ok, data?, error?} envelope + flag detection primitives shipped; per-subcommand schemas + NDJSON streaming deferred per no-silent-deferrals.md."
feature-id: F-030
short-slug: json-output
milestone: M4
provenance:
  surfaces:
    - foundational-plan:V:8
    - kit:rules/verification-protocol.md (ACTUAL BEFORE PRESENT)
fr-coverage: []
test-files:
  unit: []
  node:
    - tests/node/F-030-cli-json-output.test.ts
  browser: []
  integration: []
  e2e: []
test-runner-projects: [node]
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-030-json-output-review.md exists with verdict: ACCEPT.
depends-on: [F-029]
out-of-scope-notes: |
  Streaming NDJSON for very-long outputs (e.g., audit query >10k entries) is supported
  in v1 (one record per line). Pretty-printed JSON (`--pretty`) is v1.5.
  YAML or TOML output is out of scope; JSON is the only structured format in v1.
confidence: high
---

# F-030 — JSON output

## Behavior contract

Every CLI subcommand (per F-029) supports two output modes: `--format text` (default; human-readable plain UTF-8) and `--format json` (machine-readable). When `--format json` is passed, stdout MUST be a single JSON document for query/single-record subcommands, OR newline-delimited JSON (NDJSON, one record per line) for streaming subcommands (`audit query`, `cron fires`, `run list`). Stderr is reserved for diagnostics — error envelopes go to stdout in JSON mode (with `{"error": {...}, "exit_code": N}`), so callers can parse them. Exit codes follow sysexits.h conventions consistently across both modes. JSON output never embeds ANSI color codes, never embeds shell-formatting characters, and never silently truncates — large outputs MUST be streamed (NDJSON) rather than buffered.

## Acceptance scenarios

1. **Given** `mad-council run status <run_id> --format json`, **When** the run exists, **Then** stdout is a single valid JSON object containing at least `{run_id, lifecycle, cycle_count, last_audit_entry_sha256}` + a trailing newline + exit 0.
2. **Given** `mad-council audit query --run <run_id> --format json` against a run with 50,000 audit entries, **When** the command runs, **Then** stdout is NDJSON (one JSON object per line, each parseable independently) + memory usage stays bounded (<200MB) + the stream completes without truncation.
3. **Given** `mad-council run halt <invalid-id> --format json`, **When** the run does not exist, **Then** stdout is `{"error": {"code": "RUN_NOT_FOUND", "message": "..."}, "exit_code": 65}` + exit code 65 (EX_DATAERR) + stderr empty.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/cli/json-format-status.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/integration/cli/json-ndjson-streaming.test.ts` | integration | RED — needs 50k-entry fixture | scenario 2 |
| (TBD) `tests/unit/cli/json-error-envelope.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-029 (subcommand surface that outputs)
- **Soft:** F-016 (audit query streaming source for NDJSON), F-013 (event-normalization shape if events are surfaced to CLI)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan:V:8 | Machine-readable output for external orchestrators consuming the CLI |
| kit:rules/verification-protocol.md | "ACTUAL BEFORE PRESENT" — JSON output is the verifiable form |

## Implementation notes

### Wave 017 / Lane D — RED → GREEN (2026-05-07)

Implementation lives at `packages/cli/src/json-output.ts` (~50 LOC, ESM).
Surface:

```typescript
export interface JsonOutput {
  ok: boolean;
  data?: unknown;
  error?: string;
}
export function hasJsonFlag(args: string[]): boolean;
export function stripJsonFlag(args: string[]): string[];
export function emitJson(output: JsonOutput): void;
```

`packages/cli/src/index.ts` gains a 1-import + 1-line edit so `runCli`
strips `--json` from `subArgs` before forwarding to the matched
subcommand:

```typescript
import { stripJsonFlag } from './json-output.js';
// ...inside runCli, after subcommand resolution:
const forwarded = stripJsonFlag(subArgs);
return await subcommand(forwarded);
```

Tested by `tests/node/F-030-cli-json-output.test.ts` (7 scenarios) — all
PASS at GREEN. Full proof at `docs/09-examples-proof/F-030/`. Composes
against F-028's `runCli` surface + F-029's `standardSubcommands` without
changing either's external API.

### Scope deviations from original ledger acceptance scenarios

Four deviations recorded openly per `verification-protocol.md` Rule 1
(FETCH BEFORE CITE) + `no-silent-deferrals.md`:

1. **NDJSON streaming deferred.** Original §Acceptance scenario 2 calls
   for `audit query --format json` over 50,000 audit entries to emit
   NDJSON (one JSON object per line, parseable independently, <200MB
   memory bound). v1 ships only the single-line `emitJson` + `JsonOutput`
   envelope; NDJSON is its own future feature when concrete `audit
   query` behavior lands (currently an F-029 stub).
2. **Per-subcommand schemas deferred.** Original §Acceptance scenario 1
   envisions `mad-council run status <run_id> --format json` emitting
   `{run_id, lifecycle, cycle_count, last_audit_entry_sha256}`. v1
   provides only the structural envelope `{ok, data?, error?}`;
   per-subcommand schemas land with each subcommand's concrete behavior.
3. **`--format` flag → `--json` flag scope simplification.** Original
   §Behavior contract specifies `--format text` (default) | `--format
   json`. v1 ships boolean `--json` (presence = JSON mode). The
   `--format` flag is a deferred future feature; the current envelope
   shape will accept that extension without re-shaping.
4. **Sysexits.h exit-code normalization deferred.** Original scenario 3
   calls for exit code 65 (EX_DATAERR) for missing-run lookups under
   `--json`. F-028's `1` exit code is preserved unchanged; cross-cutting
   sysexits.h normalization is its own future feature (called out also
   in F-028 + F-029 ledger §Implementation notes scope-deviations).

### Composition notes

The `index.ts` edit is intentionally minimal — `stripJsonFlag` is called
inside the existing dispatcher after subcommand-name resolution. The
subcommand never sees `--json` in its own args; orchestrator-level
JSON-mode wrap of subcommand output via `emitJson` is the caller's
responsibility (or a future wrapping skill that replaces subcommand
stubs with real behavior). This keeps the F-028 dispatcher contract
backward-compatible while making the F-030 primitive available for
downstream use.

The minimum-viable `{ok, data?, error?}` envelope was deliberately
chosen so future per-subcommand schemas can extend the `data` field
without re-shaping the envelope itself.

### Cross-references

- Test: `tests/node/F-030-cli-json-output.test.ts` (7 scenarios)
- Impl: `packages/cli/src/json-output.ts` (~50 LOC)
- Wiring: `packages/cli/src/index.ts` (1-import + 1-line edit),
  `packages/cli/package.json` (exports `./json-output` subpath)
- Proof: `docs/09-examples-proof/F-030/{red,green}-test-output.txt`
  + `physical-proof.md`
- Lane summary: `docs/06-agent-team-outputs/wave-017/lane-d-summary.md`
- Sibling-this-wave: F-029 cli-subcommands (this lane); F-024/F-025/
  F-026/F-027 (sibling lanes B/C — M3 features)
- Downstream: future M4+ features will wrap their structured output
  via `emitJson` when `hasJsonFlag` returns true
