---
artifact-class: physical-proof
generated-by: hand-authored (wave-016 / lane-c)
feature-id: F-028
status: green
date: 2026-05-07
---

# F-028 — CLI entry — physical proof

## RED capture (pre-impl)

Test author: `tests/node/F-028-cli-entry.test.ts` (7 scenarios — root
help / --help / -h / unknown subcommand / return-code propagation /
arg passthrough / programName override) authored BEFORE
`packages/cli/src/index.ts` exists.

```
FAIL  tests/node/F-028-cli-entry.test.ts (0 test)
Error: Failed to load url @mad-council-claw/cli
       (resolved id: @mad-council-claw/cli) in
       C:/Users/tonym/Repos/mad-council-claw/tests/node/F-028-cli-entry.test.ts.
       Does the file exist?

Test Files  1 failed | 4 passed (5)
     Tests  28 passed (28)
```

The 4 prior node-suite files (F-003 11/11, F-004 7/7, F-005 4/4,
F-008 6/6) stayed GREEN — the failure was scoped to the F-028 import
boundary. Full RED output: [`red-test-output.txt`](red-test-output.txt).

## GREEN capture (post-impl)

After:
- authoring `packages/cli/src/index.ts` (~95 LOC; ESM module exporting
  `runCli`, `CliOptions`, `Subcommand` + a direct-execution dispatcher
  block at the bottom);
- updating `packages/cli/package.json` with `exports` + `bin` fields;
- adding `@mad-council-claw/cli: workspace:*` to root devDependencies
  so vitest's resolver finds the workspace package;
- running `pnpm install` to refresh the workspace symlinks.

```
✓ tests/node/F-005-deps-pinning.test.ts (4 tests) 12ms
✓ tests/node/F-028-cli-entry.test.ts (7 tests) 14ms
✓ tests/node/F-003-repo-scaffolding.test.ts (11 tests) 24ms
✓ tests/node/F-004-vitest-playwright-config.test.ts (7 tests) 9ms
✓ tests/node/F-008-local-storage-layout.test.ts (6 tests) 47ms

Test Files  5 passed (5)
     Tests  35 passed (35)
```

Full GREEN output: [`green-test-output.txt`](green-test-output.txt).
Net delta: +1 test file, +7 tests; prior 4 files unchanged.

## Acceptance scenarios — coverage map

| # | Scenario | Test name | Status |
|---|---|---|---|
| 1 | `runCli` with no args returns exit 0 + prints root help | scenario 1: runCli with no args returns exit 0 and prints root help | PASS |
| 2 | `--help` returns exit 0 + prints root help | scenario 2: --help returns exit 0 and prints root help | PASS |
| 3 | `-h` returns exit 0 + prints root help | scenario 3: -h returns exit 0 and prints root help | PASS |
| 4 | unknown subcommand returns non-zero + writes stderr | scenario 4: unknown subcommand returns non-zero exit and writes stderr | PASS |
| 5 | registered subcommand return code propagates | scenario 5: registered subcommand return code is propagated | PASS |
| 6 | subcommand args flow through after subcommand name | scenario 6: subcommand receives remaining args after subcommand name | PASS |
| 7 | `programName` override surfaces in help output | scenario 7: programName override surfaces in help output | PASS |

## Scope deviations recorded openly

Per `verification-protocol.md` Rule 1 (FETCH BEFORE CITE) +
`no-silent-deferrals.md`:

1. **Exit code on unknown subcommand is `1`, not `64` (EX_USAGE).**
   The F-028 ledger §Acceptance scenarios scenario 2 specifies
   `64` per `sysexits.h` convention. The v1 scaffold uses `1`; F-029
   (subcommands) will normalize the exit-code surface across the
   subcommand set. Documented in test header + this proof + the
   F-028 ledger §Implementation notes.
2. **Windows-no-flash + IPv6 dual-stack (ledger scenario 3) NOT
   exercised in v1.** Those concerns belong to the binary launcher
   (electron-builder / native shim) not the JS dispatcher. The
   scaffold cannot exercise them; they're tracked in F-031
   (daemon-mode) instead.
3. **`--state-dir` flag + `MAD_COUNCIL_*` env-var resolution (ledger
   §Behavior contract) deferred to F-029.** They belong with concrete
   subcommands that read state, not with the entry dispatcher.

## What this lane did NOT touch

- Browser tests (none affected)
- desktop-shell package (unchanged)
- engine-core package (unchanged)
- Other M4 ledgers (F-029, F-030, F-031 still RED)

## Artifacts produced

| File | Type |
|---|---|
| `tests/node/F-028-cli-entry.test.ts` | new (7 scenarios) |
| `packages/cli/src/index.ts` | new (~95 LOC) |
| `packages/cli/package.json` | modified (exports + bin fields added) |
| `package.json` | modified (1-line cli workspace devDependency added) |
| `docs/09-examples-proof/F-028/red-test-output.txt` | new |
| `docs/09-examples-proof/F-028/green-test-output.txt` | new |
| `docs/09-examples-proof/F-028/physical-proof.md` | new (this file) |

## Provenance

- Wave: wave-016
- Lane: lane-c
- Date: 2026-05-07
- F-028 ledger: `docs/03-feature-catalog/M4-headless-cli/F-028-cli-entry.md`
- Foundational plan: V:8 (BOTH UI surfaces — desktop + headless CLI)
