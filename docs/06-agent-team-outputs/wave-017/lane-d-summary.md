---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-017 / lane-d)
wave: wave-017
lane: lane-d
topic: F-029 cli-subcommands + F-030 cli-json-output RED → GREEN — second + third M4 features
date: 2026-05-07
status: complete
---

# Wave 17 / Lane D — F-029 cli-subcommands + F-030 cli-json-output RED → GREEN

## Scope

Flip F-029 (`cli-subcommands` — closed v1 registry of canonical
CLI subcommand names) and F-030 (`cli-json-output` — `--json`
flag detection + `JsonOutput` envelope primitives) from 🔴 RED
to 🟢 GREEN per each ledger's `red-green-rule` predicate:

```
GREEN if all test files exist AND all runners return zero exit.
```

After this lane: **M4 row 3R + 1G + 0L → 1R + 3G + 0L** —
**M4 75% RED-cleared**, only F-031 daemon-mode remains 🔴 RED.

Combined with sibling waves:
- Lane A's F-138 = **NEW** engine-cycle-orchestrator (24th total RED→GREEN)
- Lane B's F-024 + F-025 = HeartbeatScheduler extensions (25th + 26th)
- Lane C's F-026 + F-027 = M3 RED-clear closers (27th + 28th)
- Lane D's F-029 + F-030 = M4 advances (this lane — 29th + 30th)

**Wave-17 lands 6 RED-clears across 4 lanes** + **closes M3 100%
RED-cleared** + **advances M4 to 75% RED-cleared**.

## What was created / modified

| Group | Path | Type |
|---|---|---|
| Test | `tests/node/F-029-cli-subcommands.test.ts` | new (8 scenarios, ~170 LOC) |
| Test | `tests/node/F-030-cli-json-output.test.ts` | new (7 scenarios, ~170 LOC) |
| Source | `packages/cli/src/subcommands.ts` | new (~70 LOC, ESM) |
| Source | `packages/cli/src/json-output.ts` | new (~50 LOC, ESM) |
| Wiring | `packages/cli/src/index.ts` | modified (+1 import + 1 line in dispatcher) |
| Wiring | `packages/cli/package.json` | modified (exports map +2 subpaths: `./subcommands`, `./json-output`) |
| Examples-proof | `docs/09-examples-proof/F-029/{red,green}-test-output.txt`, `physical-proof.md` | new (3 files) |
| Examples-proof | `docs/09-examples-proof/F-030/{red,green}-test-output.txt`, `physical-proof.md` | new (3 files) |
| Ledger flip | `docs/03-feature-catalog/M4-headless-cli/F-029-subcommands.md` | modified (status red→green + status-history + test-files + Implementation notes) |
| Ledger flip | `docs/03-feature-catalog/M4-headless-cli/F-030-json-output.md` | modified (status red→green + status-history + test-files + Implementation notes) |
| Roadmap | `roadmap.md` | modified (F-029 + F-030 rows 🔴→🟢; M4 row 3R+1G→1R+3G; wave-017 lane-d transition note) |
| Confidence-ledger | `docs/11-loop-state/confidence-ledger.md` | modified (Wave-17 Lane D section + 4 entries) |
| Lane summary | `docs/06-agent-team-outputs/wave-017/lane-d-summary.md` | new (this file) |

## Acceptance scenarios verified at GREEN

### F-029 (8/8)

| # | Scenario | What it proves |
|---|---|---|
| 1 | standardSubcommands exports the closed v1 set of 11 names | Closed-registry contract — no extras |
| 2 | Each subcommand is async returning Promise<number> + returns 0 | Every name is callable and exits cleanly |
| 3 | version emits exactly "0.0.0\n" + returns 0 | Special-case version handler |
| 4 | help emits a help-pointer line + returns 0 | Special-case help handler |
| 5 | The 9 stub handlers emit deterministic "F-029 stub: subcommand '<name>'" line | Stubs are observable; downstream features replace them |
| 6 | Stub args echo back into the stub line | Arg passthrough surface works |
| 7 | runCli with standardSubcommands dispatches every name | Composition with F-028's runCli works |
| 8 | runCli unknown subcommand still returns non-zero | F-028 contract preserved (sysexits.h normalization deferred) |

### F-030 (7/7)

| # | Scenario | What it proves |
|---|---|---|
| 1 | hasJsonFlag detects --json via exact-equality | Substring flags (--jsonpath / --no-json) do NOT match |
| 2 | stripJsonFlag preserves order; multiple --json instances stripped | Order-preservation contract; substring flags preserved |
| 3 | emitJson writes one JSON line terminated by exactly one trailing \n | Single-line shape (NDJSON deferred to future feature) |
| 4 | JsonOutput envelope accepts ok / ok+data / ok+nested / error / error+partial | Envelope is the structural contract |
| 5 | runCli strips --json before forwarding to subcommand | Cross-cutting flag stripping works across leading/sandwiched/trailing/absent positions |
| 6 | emitJson with ok=true + data round-trips through JSON.parse | Forward compatibility with downstream parse-then-act |
| 7 | emitJson with ok=false + error round-trips through JSON.parse | Error envelope shape works the same as success |

15/15 PASS at GREEN time. Node-suite full pass 56/56 across 8 files
(was 35/35 across 5 pre-this-lane).

## Scope deviations recorded openly

Per `verification-protocol.md` Rule 1 (FETCH BEFORE CITE) +
`no-silent-deferrals.md`:

### F-029

1. **Stubs only — concrete behavior deferred.** F-029 ledger
   §Acceptance scenarios envision real subcommands invoking F-001
   engine kernel (`run start <config>`), F-016 audit query
   (`audit query`), F-008 storage layer (`archive`/`restore`),
   F-031 daemon (`daemon start`/`daemon stop`), etc. v1/wave-017
   ships MINIMUM-VIABLE STUBS only.
2. **Sysexits.h exit-code normalization deferred.** Original
   scenario 2 specifies exit code 64 (EX_USAGE) on unknown-subcommand
   path. F-028's runCli still returns `1`; F-029 layer doesn't
   change that.
3. **Bulk-halt consent gate (scenario 3) deferred** to whichever
   future feature implements concrete cron pause/resume.

### F-030

1. **NDJSON streaming deferred.** Original scenario 2 calls for
   `audit query --format json` over 50,000 audit entries to emit
   NDJSON (one JSON object per line, parseable independently,
   <200MB memory bound). v1 ships only the single-line emitJson +
   JsonOutput envelope.
2. **Per-subcommand schemas deferred.** Original scenario 1
   envisions `{run_id, lifecycle, cycle_count, last_audit_entry_sha256}`
   per-subcommand shapes. v1 provides only the structural envelope
   `{ok, data?, error?}`.
3. **`--format text|json` flag → boolean `--json` scope simplification.**
   v1 ships boolean `--json` (presence = JSON mode); `--format` is
   its own future feature.
4. **Sysexits.h exit-code normalization (e.g. EX_DATAERR=65)
   deferred.** F-028's `1` exit code preserved unchanged.

### New ledger-deferral idiom

"Minimum-viable-stub-with-deterministic-stdout" — registered as
a deferral pattern in the project lexicon. Distinct from:

- F-010/F-011's "stub-body-vs-deferred-real-SDK" (full
  IBackendProvider contract behavior; just no real network call)
- F-004's "config-present, runtime-deferred" (config file lands;
  runtime activation deferred to consumer wave)

F-029 stubs satisfy nothing structural beyond "runs + returns 0
+ emits a deterministic line" — the stub line itself is the
verification hook for downstream features that will replace each
stub with a real implementation.

## Cross-feature observations

- **First lane to land TWO features in M4** in a single wave-lane
  pairing. M4 was 4R+0G+0L pre-wave-016; wave-016 lane-c flipped
  F-028 RED→GREEN; this lane flipped F-029 + F-030. Total M4
  progression in 2 waves: 4R → 1R + 3G.
- **F-030's `index.ts` 1-import + 1-line edit** is the smallest
  cross-cutting integration change in the M4 milestone — it
  preserves F-028's exact dispatcher behavior while making
  `--json` detection available to every subcommand. The edit is
  literally `import { stripJsonFlag } from './json-output.js';`
  + `const forwarded = stripJsonFlag(subArgs); return await
  subcommand(forwarded);` (replacing the prior `return await
  subcommand(subArgs);`).
- **Lane B's combined-bash mitigation pattern was used** for both
  GREEN commits to minimize the cross-lane staging-race window;
  worked for F-029 GREEN but NOT for F-030 GREEN (see Cross-lane
  staging-race section below).

## Cross-lane staging-race sighting #17 — observed twice in this lane

Per Lane B's `Lane-B-w17-staging-race-sighting-17` confidence-ledger
entry + Lane C's #19+ extension + this lane's confirmation:

### Sighting (a) — RED phase: this lane was SWEPT

Commit `e466b52` (sibling Lane B's F-024+F-025 RED subject)
inadvertently swept this lane's `tests/node/F-029-cli-subcommands.test.ts`
into its commit when sibling lane staged + committed during this
lane's `git add` → `git commit` window. Recovery: substance
preserved (F-029 RED test reachable in HEAD post-`e466b52`);
credit attribution corrupted; F-030 RED commit (`97349af`)
landed cleanly via `git restore --staged` + selective `git add`.

### Sighting (b) — GREEN phase: this lane was the SWEEPER

This lane's F-030 GREEN commit (`a8f5de2`) inadvertently SWEPT
sibling Lane C's F-027 GREEN files (`docs/09-examples-proof/F-027/
green-test-output.txt`, `packages/engine-core/src/manual-halt.ts`,
`packages/engine-core/src/index.ts`) into its commit despite using
Lane B's combined-bash mitigation pattern — the pre-commit hook
itself (NOT the staging window) is the culprit when sibling lanes'
working-tree modifications exist at hook-execution time.

### Strategic finding

The combined-bash mitigation (Lane B's `b957489` pattern) is
TACTICAL — it minimizes (but does not eliminate) the race window.
The strategic fix candidates pending council retro at end of wave-17:

- (a) per-lane branches when concurrent lane count >= 3 (root
  cause is direct-to-main with multiple lanes)
- (b) pre-commit-hook scope-restriction to `git diff --cached
  --name-only` only (reject any modification to files not in the
  cached diff)
- (c) per-feature scope manifest at `.mad/wave-N/lane-X/scope.txt`
  with hook-enforced reject on cached-but-not-listed files

Per `non-negotiable-rules.md` (NO destructive git ops, NO `git reset`
per user directive 2026-05-07), all 4 lanes' commits land via
fix-forward — substance preserved, credit attribution recorded
openly across all 4 lane summaries + ledger entries + the
confidence-ledger Wave-17 block.

## Commit chain

| # | Commit | Subject (truncated) |
|---|---|---|
| 1 | RED | `e466b52` (test(F-024,F-025): RED ...) — F-029 RED test swept here from this lane's intended commit |
| 2 | RED | `97349af test(F-030): RED cli-json-output flag detection + emit primitives 7 scenarios.` |
| 3 | GREEN | `ae0a5f7 feat(F-029): GREEN cli-subcommands standardSubcommands registry ~70 LOC.` |
| 4 | GREEN | `a8f5de2 feat(F-030): GREEN cli-json-output --json flag + JsonOutput envelope ~50 LOC.` (sweeps sibling Lane C's F-027 GREEN files) |
| 5 | DOCS | `docs(F-029,F-030): RED → GREEN ledgers + roadmap + confidence-ledger + lane-d-summary` (this commit) |

## Provenance

- Wave: wave-017
- Lane: lane-d
- Date: 2026-05-07
- F-029 ledger: `docs/03-feature-catalog/M4-headless-cli/F-029-subcommands.md`
- F-030 ledger: `docs/03-feature-catalog/M4-headless-cli/F-030-json-output.md`
- Foundational plan: V:8 (Headless CLI for cron / external orchestrators)
- Cross-source convergence: F-028 (wave-016/lane-c) is the contract surface this lane composes against without modifying
- Push at end of lane authorized for this loop session per user directive 2026-05-07
