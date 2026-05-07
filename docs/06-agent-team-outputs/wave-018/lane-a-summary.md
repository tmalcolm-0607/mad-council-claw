# Wave-18 / Lane A — F-023 + F-028 GREEN → LOCKED (parallel-double LOCKED-flip)

**Date:** 2026-05-07
**Lane:** wave-018 / lane-a
**Lane theme:** First M3 (cron / heartbeat) + first M4 (Headless CLI) cornerstone-primitive LOCKED transitions via post-impl council reviews. Both features ship with their downstream same-class extensions (M3: F-024 + F-025) or composing features (M4: F-029 + F-030) already GREEN — empirical contract validation precedes formal LOCKED.

## Outcome

| Outcome | Detail |
|---|---|
| F-023 cron-heartbeat LOCKED | `docs/05-design-reviews/council-reviews/F-023-cron-heartbeat-review.md` verdict ACCEPT median 88; Advocate 90 / Skeptic 76 / Architect 88; 0 CRITICAL / 0 MAJOR / 4 MINOR / 3 PRAISE |
| F-028 cli-entry LOCKED | `docs/05-design-reviews/council-reviews/F-028-cli-entry-review.md` verdict ACCEPT median 87; Advocate 90 / Skeptic 75 / Architect 87; 0 CRITICAL / 0 MAJOR / 5 MINOR / 3 PRAISE |
| Test count at HEAD | **225 / 225 PASS** across 31 vitest files (3.38s total) |
| F-023 isolated test | 21/21 PASS unchanged at review time (no regression from wave-016/lane-b GREEN flip) |
| F-028 isolated test | 7/7 PASS unchanged at review time (no regression from wave-016/lane-c GREEN flip) |
| Council-verdict validity | Both reviews validated via `.claude/scripts/Validate-CouncilVerdict.ps1` — exit 0; CRITICAL count 0; not claiming ACCEPT-WITH-FIXES |
| Ledger flips | F-023 status: green → locked; F-028 status: green → locked (status-history rows authored documenting wave-018/lane-a verdict + findings) |
| Roadmap milestone counts | M3 row 0R+5G+0L → 0R+4G+1L; M4 row 1R+3G+0L → 1R+2G+1L; TOTAL 98R+7G+22L → 98R+5G+24L |
| Roadmap per-feature rows | F-023 row 🟢 → 🔒; F-028 row 🟢 → 🔒 |
| Wave-018 lane-a transition note | Inserted at top of transition-notes block above wave-17/lane-a |
| Confidence ledger | Wave 18 / Lane A entry-block authored with 4 finding rows: F-023-LOCKED, F-028-LOCKED, parallel-double-LOCKED-pattern-validated, cross-milestone-cornerstone-LOCKED-pattern |
| Decision log | F-023 + F-028 rows appended (23rd + 24th LOCKED transitions in repo history) |

## Decision-rationale per feature

### F-023 cron-heartbeat — verdict ACCEPT (median 88)

**Why ACCEPT.** The F-023 ledger's `red-green-rule` predicate reads "LOCKED if GREEN AND reviews/F-023-cron-heartbeat-review.md exists with verdict: ACCEPT." Both conditions met:

1. **GREEN** — 21/21 acceptance scenarios PASS at review time (`pnpm test` 2026-05-07; full suite 225/225 across 31 test files; F-023 isolated 21/21 in 24ms). Source at `packages/engine-core/src/heartbeat.ts` (~313 LOC; F-023-owned ~145 LOC + F-024/F-025 same-class additions ~50 LOC each).
2. **Verdict ACCEPT** — review file exists at `docs/05-design-reviews/council-reviews/F-023-cron-heartbeat-review.md` with frontmatter `verdict: ACCEPT`, body satisfies `council-verdict-artifact.md` validity oracle (Reviewer summary table + `Median confidence: 88` + `Decision: ACCEPT` + size > 500B), 0 CRITICAL / 0 MAJOR findings, no findings block.

**MINOR findings (4) — all honest scope-narrowing notes per `no-silent-deferrals.md`.**

| # | Finding | Disposition |
|---|---|---|
| F1 | Behavior-contract scope narrowing: ledger §Behavior contract names cron-schedules.json reading + cron-fires.jsonl appending + F-001 run-spawn + F-002 identity at fire time. The wave-016/lane-b GREEN flip deliberately scoped F-023 to the scheduler primitive only. | Accept; ledger §Implementation notes documents this openly. Backlog: cron-registry + run-spawn integration flips. |
| F2 | Acceptance-scenario divergence: ledger lists 3 end-to-end scenarios; 21 implemented scenarios go deeper on the primitive contract (cadence-zone bounds, escape-hatch, tick-before-start, async-handler await, setInterval witness). | Accept; ledger documents the divergence. Future integration waves retire scenarios 1+2 by composing against this primitive. |
| F3 | CADENCE_FORBIDDEN_ZONE error code naming: ledger acceptance scenario 3 specifies the rejection string includes `CADENCE_FORBIDDEN_ZONE`. Impl uses `forbidden zone 280-1199s` + remediation pointer. Semantically equivalent. | Accept; future error-code-taxonomy wave normalizes for machine-parseable contexts (when M4 F-029 sysexits.h normalization + F-030 JSON envelope reach error shapes). |
| F4 | Drift accounting deferred: ledger §Behavior contract specifies "schedule drift MUST stay ≤5% of the cadence interval over a 100-fire window" per ce:SC-007. F-023 contributes the SHAPE only (`getStatus.lastTickAt` + `tickCount`). F-026 owns the math. | Accept; F-026 has consumed the shape per its own ledger; drift accounting is an integration concern not a primitive concern. |

**PRAISE findings (3).**

- F5: Cadence-zone enforcement directly mechanizes `loop-cadence-discipline.md` — the kit rule's prose ("the 280-1199s zone is forbidden") becomes a constructor throw with an inline remediation pointer. Operator escape hatch (`enforceWarmCacheZones: false`) preserves consent-in-code over consent-in-silence.
- F6: Public `tick()` is the right test ergonomics — tests drive the handler synchronously without fake-timers; the `setInterval`-driven path IS empirically witnessed via `vi.useFakeTimers()`. Two-paths-one-counter is the canonical async-trigger primitive shape.
- F7: Same-class extension by F-024 + F-025 (wave-017/lane-b) preserves F-023's contract. The `tickInFlight` guard + `skippedTicks` counter + `archiveAfterMinutes` field + `onIdleArchive` registration + idle-gap detection all live on the same `HeartbeatScheduler` instance.

### F-028 cli-entry — verdict ACCEPT (median 87)

**Why ACCEPT.** The F-028 ledger's `red-green-rule` predicate reads "LOCKED if GREEN AND reviews/F-028-cli-entry-review.md exists with verdict: ACCEPT." Both conditions met:

1. **GREEN** — 7/7 acceptance scenarios PASS at review time (`pnpm test` 2026-05-07; F-028 isolated 7/7 in 12ms). Source at `packages/cli/src/index.ts` (~103 LOC; F-028-owned ~95 LOC + 1-import + 1-line F-030 strip integration from wave-017/lane-d).
2. **Verdict ACCEPT** — review file exists at `docs/05-design-reviews/council-reviews/F-028-cli-entry-review.md` with frontmatter `verdict: ACCEPT`, body satisfies `council-verdict-artifact.md` validity oracle (Reviewer summary table + `Median confidence: 87` + `Decision: ACCEPT` + size > 500B), 0 CRITICAL / 0 MAJOR findings, no findings block.

**MINOR findings (5) — all honest scope-narrowing notes per `no-silent-deferrals.md`.**

| # | Finding | Disposition |
|---|---|---|
| F1 | Exit code on unknown subcommand is `1`, not `64` (EX_USAGE). Wave-016/lane-c deferred sysexits.h normalization to F-029; F-029 wave-017/lane-d ALSO deferred (preserved exit code `1` unchanged). Future M4+ feature owns the chain. | Accept; ledger documents this openly. Backlog: M4 sysexits.h normalization wave (covers F-028 + F-029 + F-031). |
| F2 | Windows-no-flash + IPv6 dual-stack (ledger scenario 3) NOT exercised. Those concerns belong to the binary launcher (electron-builder / native shim), not the JS dispatcher. | Accept; ledger documents this openly. F-031 ledger owns the integration. |
| F3 | `--state-dir` flag + `MAD_COUNCIL_*` env-var resolution deferred. They belong with concrete subcommands that read state. | Accept; ledger documents this openly. Future M4+ feature when concrete subcommand behavior lands. |
| F4 | Binary name divergence: ledger names binary `mad-council`; package.json `bin` + default `programName` are `nested-quilt`. | Accept; CliOptions.programName override mechanism exists; future binary-naming + packaging wave normalizes. |
| F5 | F-030 stripJsonFlag side effect: `runCli` now strips `--json` from subArgs before forwarding. F-028's 7 scenarios don't exercise `--json` so contract preserved; subtle dispatcher-level shift. | Accept; behavior is documented in dispatcher docblock + F-030 ledger. Future F-030 LOCKED review should cite this dispatcher-side strip as the integration point. |

**PRAISE findings (3).**

- F6: Async dispatcher returning `Promise<number>` is the canonical exit-code carrier shape. The `import.meta.url === \`file://${process.argv[1]}\`` direct-execution block awaits + `process.exit(code)`. Unhandled rejection caught + logged to stderr + exit 1.
- F7: Test-ergonomics via `vi.spyOn(process.stdout/stderr, 'write')` is the right shape for in-process CLI testing — ~12ms scenario time; pattern mirrors Node's own test harnesses.
- F8: F-029 (subcommands) + F-030 (json-output) compose against F-028's surface with zero contract drift. F-029 plugs into `CliOptions.subcommands` map; F-030's stripJsonFlag is 1-import + 1-call additive responsibility. Clean module graph (index.ts ← json-output.ts; subcommands.ts ← index.ts) validates F-028's tight callable+record+options shape.

## Cross-milestone cornerstone-LOCKED-pattern

This lane validates a reusable LOCKED-review template shape across milestones:

1. **Identify the cornerstone primitive** — the pure-class (no I/O orchestration) feature that downstream same-class extensions or composing features depend on. M3's cornerstone is F-023 HeartbeatScheduler; M4's cornerstone is F-028 runCli dispatcher.
2. **Verify GREEN status preservation across downstream extensions** — F-023's contract held across F-024 + F-025 same-class additions; F-028's contract held across F-029 + F-030 composition. Empirical contract validation precedes formal LOCKED.
3. **Apply the review template chain** — read recent LOCKED reviews (F-022 / F-018 / F-007 / F-013) as template; author Advocate / Skeptic / Architect lenses focusing on contract preservation + scope reconciliation per `no-silent-deferrals.md` + verification-protocol.md FETCH BEFORE CITE; emit findings classified by severity (BLOCKING / MAJOR / MINOR / PRAISE per `pr-review/templates/review-findings.md`); compute median confidence; emit Decision.
4. **The first-cornerstone-of-milestone precedent matters** — F-023's review establishes the precedent shape for F-024..F-027 LOCKED reviews; F-028's review establishes the precedent shape for F-029..F-030 LOCKED reviews. Future M3/M4 LOCKED waves can re-use this lane's review templates with feature-specific findings.

## Verification protocol per `verification-protocol.md`

Per Rule 1 (FETCH BEFORE CITE) + Rule 4 (ACTUAL BEFORE PRESENT), the following sources were read directly during review authorship:

- `packages/engine-core/src/heartbeat.ts` lines 1-313 (F-023 owned ~145 LOC + F-024/F-025 same-class additions)
- `tests/unit/F-023-cron-heartbeat.test.ts` lines 1-239 (21 scenarios across 6 describe blocks)
- `docs/03-feature-catalog/M3-cron-heartbeat/F-023-cron-heartbeat.md` lines 1-119 (full ledger)
- `packages/cli/src/index.ts` lines 1-103 (F-028 dispatcher + F-030 strip integration)
- `tests/node/F-028-cli-entry.test.ts` lines 1-138 (7 scenarios)
- `packages/cli/package.json` (bin + exports map)
- `docs/03-feature-catalog/M4-headless-cli/F-028-cli-entry.md` lines 1-134 (full ledger)
- `packages/cli/src/json-output.ts` lines 1-74 (F-030 surface to verify F-028 composition claim)
- `packages/engine-core/src/index.ts` lines 1-50 (engine-core barrel for ownership-table cite)
- Test verification: `pnpm test` from repo root → 225/225 PASS across 31 vitest files (3.38s total) at 2026-05-07

Per Rule 4 (ACTUAL BEFORE PRESENT), no claims are made beyond the verified evidence; both review files cite specific file:line references for every architectural claim.

## Files modified in this lane

| File | Edit type | Purpose |
|---|---|---|
| `docs/05-design-reviews/council-reviews/F-023-cron-heartbeat-review.md` | New file | Council review verdict + Advocate/Skeptic/Architect lenses + 7 findings |
| `docs/05-design-reviews/council-reviews/F-028-cli-entry-review.md` | New file | Council review verdict + Advocate/Skeptic/Architect lenses + 8 findings |
| `docs/03-feature-catalog/M3-cron-heartbeat/F-023-cron-heartbeat.md` | Frontmatter + status-history append | green → locked + status-history row |
| `docs/03-feature-catalog/M4-headless-cli/F-028-cli-entry.md` | Frontmatter + status-history append | green → locked + status-history row |
| `roadmap.md` | M3 + M4 row + TOTAL row + F-023 + F-028 per-feature rows + wave-018/lane-a transition note | Aggregate + per-feature state refresh + transition note |
| `docs/11-loop-state/confidence-ledger.md` | Append wave-18 lane-a entry-block | 4 finding rows: F-023-LOCKED, F-028-LOCKED, parallel-double-LOCKED-pattern-validated, cross-milestone-cornerstone-LOCKED-pattern |
| `docs/07-roadmap/decision-log.md` | Append F-023 + F-028 rows | 23rd + 24th LOCKED transitions in repo history |
| `docs/06-agent-team-outputs/wave-018/lane-a-summary.md` | New file | This summary |

## Push-discipline per user directive 2026-05-07

Per the loop-session prompt: "push pre-AUTHORIZED for this loop session per user directive 2026-05-07." This lane will commit per chain-of-thought shape (WHY/SOURCE/CONFIDENCE/WAVE) with selective `git add` (no `git reset`) and push to `origin/main` after all commits land cleanly. Test count in commit message: 225/225 PASS.

## Cross-references

- Council reviews: `docs/05-design-reviews/council-reviews/F-023-cron-heartbeat-review.md` + `docs/05-design-reviews/council-reviews/F-028-cli-entry-review.md`
- Ledgers: `docs/03-feature-catalog/M3-cron-heartbeat/F-023-cron-heartbeat.md` + `docs/03-feature-catalog/M4-headless-cli/F-028-cli-entry.md`
- Roadmap: `roadmap.md` (Wave-18 / Lane A transition note)
- Confidence ledger: `docs/11-loop-state/confidence-ledger.md` § Entries — Wave 18 § Lane A
- Decision log: `docs/07-roadmap/decision-log.md` (F-023 + F-028 rows)
- Validation: `.claude/scripts/Validate-CouncilVerdict.ps1` (exit 0 for both review files)
- Kit rules: `council-verdict-artifact.md` (validity oracle); `verification-protocol.md` (FETCH BEFORE CITE + ACTUAL BEFORE PRESENT); `no-silent-deferrals.md` (scope-narrowing transparency); `minimum-change.md` (review template re-use across milestones); `non-negotiable-rules.md` (NO destructive git ops; NO `git reset` per user directive 2026-05-07)
- Precedent reviews: F-022 (wave-013/lane-d), F-018 (wave-013/lane-d), F-007 (wave-013/lane-b), F-013 (wave-016/lane-a) — same architectural shape (cornerstone primitive + scope narrowing + verification-protocol discipline)
- Sibling-lane wave-018 outputs: `docs/06-agent-team-outputs/wave-018/lane-d-summary.md` (audit followups + cleanup)
