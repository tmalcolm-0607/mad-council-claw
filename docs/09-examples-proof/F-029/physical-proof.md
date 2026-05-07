---
artifact-class: physical-proof
generated-by: hand-authored (wave-017 / lane-d)
feature-id: F-029
status: green
date: 2026-05-07
---

# F-029 — CLI subcommands — physical proof

## RED capture (pre-impl)

Test author: `tests/node/F-029-cli-subcommands.test.ts` (8 scenarios —
registry contract / async-callable / version "0.0.0\n" / help pointer /
9 stub deterministic lines / arg passthrough / runCli dispatch / unknown
subcommand exit code) authored BEFORE `packages/cli/src/subcommands.ts`
exists.

```
FAIL  tests/node/F-029-cli-subcommands.test.ts (0 test)
Error: Failed to resolve entry for package "@mad-council-claw/cli/subcommands".

Test Files  1 failed | 5 passed (6)
     Tests  35 passed (35)
```

The 5 prior node-suite files (F-003 11/11, F-004 7/7, F-005 4/4, F-008
6/6, F-028 7/7) stayed GREEN — failure scoped to the F-029 import boundary.
Full RED output: [`red-test-output.txt`](red-test-output.txt).

## GREEN capture (post-impl)

After:
- authoring `packages/cli/src/subcommands.ts` (~70 LOC; 9 stubs +
  version + help — 11 names total, closed registry per F-029 ledger
  out-of-scope-notes which defers plugin-style extensibility to v1.5);
- updating `packages/cli/package.json` exports map to include
  `"./subcommands": "./src/subcommands.ts"` and
  `"./json-output": "./src/json-output.ts"` (the F-030 GREEN partner
  commit — both exports added together to minimize the package.json
  delta surface area).

```
✓ tests/node/F-029-cli-subcommands.test.ts (8 tests) 14ms

Test Files  8 passed (8)
     Tests  56 passed (56)
```

Full GREEN output: [`green-test-output.txt`](green-test-output.txt).

## What was built

| File | Type | LOC |
|---|---|---|
| `tests/node/F-029-cli-subcommands.test.ts` | new test | ~170 |
| `packages/cli/src/subcommands.ts` | new source | ~70 |
| `packages/cli/package.json` | modified (exports map +2 subpaths) | +3 |

`subcommands.ts` exports `standardSubcommands: Record<string, Subcommand>`
with the closed v1 set:

```typescript
export const standardSubcommands: Record<string, Subcommand> = {
  start, status, halt, retro, replay, 'query-audit', 'list-sessions',
  archive, restore,                  // 9 stubs
  version,                           // emits "0.0.0\n"
  help,                              // emits help-pointer line
};
```

Each stub follows the same shape: `async (args) => { stdout.write("F-029
stub: subcommand '<name>' (args: ...)" line); return 0; }`. The closed-set
contract means adding new names requires a new feature ledger entry per
F-029 §out-of-scope-notes (plugin-style extensibility is v1.5).

## Cross-references

- Test: `tests/node/F-029-cli-subcommands.test.ts` (8 scenarios)
- Impl: `packages/cli/src/subcommands.ts` (~70 LOC)
- Wiring: `packages/cli/package.json` (exports `./subcommands` subpath)
- Lane summary: `docs/06-agent-team-outputs/wave-017/lane-d-summary.md`
- Sibling-this-wave: F-030 cli-json-output (this lane); F-024/F-025
  HeartbeatScheduler extensions + F-026 resume-from-checkpoint +
  F-027 manual-halt-override (sibling lanes B/C)
- Downstream: F-031 daemon-mode (only RED M4 feature remaining); future
  M4+ features will swap each stub for concrete behavior

## Scope deviations recorded openly

Per `verification-protocol.md` Rule 1 (FETCH BEFORE CITE) +
`no-silent-deferrals.md`:

1. **Stubs only — concrete behavior deferred.** F-029 ledger §Acceptance
   scenarios envision real subcommands invoking F-001 engine kernel
   (`start`/`status`/`halt`), F-016 audit query (`query-audit`),
   F-008 storage layer (`archive`/`restore`), F-031 daemon
   (`replay`), F-014 retro hooks (`retro`), F-002 session registry
   (`list-sessions`). v1/wave-017 ships MINIMUM-VIABLE STUBS only.
2. **Sysexits.h exit-code normalization deferred.** F-029 ledger
   scenario 2 specifies exit code 64 (EX_USAGE) on unknown subcommand
   path. F-028's runCli still returns `1`; F-029 layer doesn't
   change that. Cross-cutting normalization is its own future feature
   per the F-028 ledger §Implementation notes scope-deviation #1.
3. **Bulk-halt consent gate (scenario 3) deferred** to whichever
   future feature implements concrete cron pause/resume behavior —
   the consent-gate is part of F-027 territory once `cron pause`
   leaves stub state.

## New ledger-deferral idiom

"Minimum-viable-stub-with-deterministic-stdout" — registered as a
deferral pattern for the project lexicon. Distinct from:

- F-010/F-011's "stub-body-vs-deferred-real-SDK" (those have full
  IBackendProvider contract behavior; just no real network call)
- F-004's "config-present, runtime-deferred" (config file lands;
  runtime activation deferred to consumer wave)

F-029 stubs satisfy nothing structural beyond "runs + returns 0 +
emits a deterministic line" — the stub line itself is the verification
hook for downstream features that will replace each stub with a real
implementation.
