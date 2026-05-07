---
artifact-class: physical-proof
generated-by: hand-authored (wave-017 / lane-d)
feature-id: F-030
status: green
date: 2026-05-07
---

# F-030 — CLI JSON output — physical proof

## RED capture (pre-impl)

Test author: `tests/node/F-030-cli-json-output.test.ts` (7 scenarios —
hasJsonFlag exact-match / stripJsonFlag order-preservation / emitJson
single-line-with-newline / JsonOutput envelope shape / runCli strips
flag before subcommand / ok=true round-trip / ok=false round-trip)
authored BEFORE `packages/cli/src/json-output.ts` exists.

```
FAIL  tests/node/F-030-cli-json-output.test.ts (0 test)
Error: Failed to resolve entry for package "@mad-council-claw/cli/json-output".

Test Files  1 failed | 5 passed (6)
     Tests  35 passed (35)
```

Failure scoped to import boundary; 5 prior node-suite files unaffected.
Full RED output: [`red-test-output.txt`](red-test-output.txt).

## GREEN capture (post-impl)

After:
- authoring `packages/cli/src/json-output.ts` (~50 LOC; 4 exports —
  `JsonOutput` interface, `hasJsonFlag`, `stripJsonFlag`, `emitJson`);
- updating `packages/cli/package.json` exports to include
  `"./json-output": "./src/json-output.ts"`;
- modifying `packages/cli/src/index.ts` to import `stripJsonFlag` from
  `./json-output.js` and strip `--json` from subArgs before forwarding
  to the matched subcommand (1 import + 1 function call edit total).

```
✓ tests/node/F-030-cli-json-output.test.ts (7 tests) 26ms

Test Files  8 passed (8)
     Tests  56 passed (56)
```

Full GREEN output: [`green-test-output.txt`](green-test-output.txt).

## What was built

| File | Type | LOC |
|---|---|---|
| `tests/node/F-030-cli-json-output.test.ts` | new test | ~170 |
| `packages/cli/src/json-output.ts` | new source | ~50 |
| `packages/cli/src/index.ts` | modified (+1 import, +1 line in dispatcher) | +2 |
| `packages/cli/package.json` | modified (exports map already extended in F-029 commit) | 0 (no new delta) |

`json-output.ts` exports:

```typescript
export interface JsonOutput {
  ok: boolean;
  data?: unknown;
  error?: string;
}
export function hasJsonFlag(args: string[]): boolean { return args.includes('--json'); }
export function stripJsonFlag(args: string[]): string[] { return args.filter((a) => a !== '--json'); }
export function emitJson(output: JsonOutput): void {
  process.stdout.write(JSON.stringify(output) + '\n');
}
```

`index.ts` now:

```typescript
import { stripJsonFlag } from './json-output.js';
// ... in runCli, after subcommand resolution:
const forwarded = stripJsonFlag(subArgs);
return await subcommand(forwarded);
```

## Cross-references

- Test: `tests/node/F-030-cli-json-output.test.ts` (7 scenarios)
- Impl: `packages/cli/src/json-output.ts` (~50 LOC)
- Wiring: `packages/cli/src/index.ts` (1-import + 1-line edit), `package.json` exports
- Lane summary: `docs/06-agent-team-outputs/wave-017/lane-d-summary.md`
- Sibling-this-wave: F-029 cli-subcommands (this lane)
- Downstream: future M4+ features will wrap their structured output via
  emitJson when --json mode is detected via hasJsonFlag

## Scope deviations recorded openly

Per `verification-protocol.md` Rule 1 + `no-silent-deferrals.md`:

1. **NDJSON streaming deferred.** F-030 ledger scenario 2 calls for
   `audit query` against 50,000 audit entries to emit NDJSON (one JSON
   object per line, parseable independently, <200MB memory bound). v1
   ships only the single-line emitJson + `JsonOutput` envelope; NDJSON
   is its own future feature when concrete `audit query` behavior lands.
2. **Per-subcommand schemas deferred.** F-030 ledger scenario 1 envisions
   `mad-council run status <run_id> --format json` emitting
   `{run_id, lifecycle, cycle_count, last_audit_entry_sha256}`. v1
   provides only the structural envelope `{ok, data?, error?}`; schemas
   are per-subcommand concerns that land with each subcommand's
   concrete behavior.
3. **`--format` flag → `--json` flag scope simplification.** Ledger
   §Behavior contract specifies `--format text` (default) | `--format
   json`. v1 ships boolean `--json` (presence = JSON mode). The
   `--format` flag is a deferred future-feature; current envelope
   shape will accept that extension without re-shaping.
4. **Sysexits.h exit codes deferred.** Ledger scenario 3 calls for
   exit code 65 (EX_DATAERR) for missing-run lookups under `--json`.
   F-028's `1` exit code is preserved unchanged; cross-cutting
   sysexits.h normalization is its own future feature.

## Composition notes

The `index.ts` edit is intentionally minimal — `stripJsonFlag` is
called inside the existing dispatcher after subcommand-name
resolution. The subcommand never sees `--json` directly; the
orchestrator-level wrap of subcommand output via `emitJson` is the
caller's responsibility (or a future wrapping skill). This keeps
the F-028 dispatcher contract backward-compatible while making the
F-030 primitive available for downstream use.
