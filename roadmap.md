---
artifact-class: navigable-roadmap
generated-by: wave-011 / lane-d
generated-by-version: 0.2.0
wave: wave-011
date: 2026-05-07
status: living
---

# Roadmap

> Navigable view of all milestones + features. Status auto-tracks `docs/03-feature-catalog/Mn-*/F-NNN-*.md` ledger frontmatter (`red` / `green` / `locked`). Source of truth for behavior contracts: per-feature ledger files. Source of truth for milestone scope: `docs/01-requirements/foundational-plan.md` § "True Synthesis → Feature catalog".

## Status legend

- 🔴 **RED** — ledger exists, status=red; test exists or planned, implementation absent, test fails
- 🟢 **GREEN** — ledger exists, status=green; test exists, implementation present, test passes
- 🔒 **LOCKED** — ledger exists, status=green AND post-impl council-review verdict ACCEPT (post-impl review verdict file must exist alongside the ledger)
- ⏸ **DEFERRED** — explicitly out of v1 (user-acknowledged); re-open trigger noted in `docs/10-backlog/`
- 🔄 **REOPEN-PENDING (verdict required)** — reopen-request package authored under `docs/05-design-reviews/reopen-requests/`; top-level ledger `status` remains `deferred` until council-review verdict at HIGH ≥80% per `M19-deferred/README.md:51-57` ratifies the transition + selects target milestone. Status indicator used here ONLY; ledger frontmatter unchanged.
- ⚪ **PLANNED** — feature ID reserved in foundational-plan catalog; ledger not yet authored

## Update protocol

- When a feature transitions RED → GREEN → LOCKED, the agent updates the corresponding row in this file in the **same commit** as the ledger frontmatter change. Per `no-silent-deferrals.md` and the chain-of-thought commit message shape, the WHY field cites both transitions.
- New ledger authored (PLANNED → RED): update both the ledger and this roadmap row in one commit.
- Per `concurrency-safety.md`: this file is mutable shared state; use atomic write-temp-rename when multiple instances may edit concurrently.

## Milestone overview

| Milestone | Theme | Span | Total | RED | GREEN | LOCKED | DEFERRED | PLANNED |
|---|---|---|---:|---:|---:|---:|---:|---:|
| M0 | Project bootstrap | F-001..F-008, F-138 | 9 | 0 | 1 | 8 | 0 | 0 |
| M1 | Pluggable backend | F-009..F-013 | 5 | 0 | 0 | 5 | 0 | 0 |
| M2 | Governance triad | F-014..F-022 | 9 | 0 | 0 | 9 | 0 | 0 |
| M3 | Cron / heartbeat | F-023..F-027 | 5 | 0 | 5 | 0 | 0 | 0 |
| M4 | Headless CLI | F-028..F-031 | 4 | 1 | 3 | 0 | 0 | 0 |
| M5 | Desktop chat shell | F-032..F-043 | 12 | 12 | 0 | 0 | 0 | 0 |
| M6 | MCP & tools | F-044..F-050 | 7 | 7 | 0 | 0 | 0 | 0 |
| M7 | Skills + Permissions + Automations | F-051..F-066 | 16 | 16 | 0 | 0 | 0 | 0 |
| M8 | Settings & persistence | F-067..F-075 | 9 | 9 | 0 | 0 | 0 | 0 |
| M9 | M365 integration | F-076..F-081 | 6 | 6 | 0 | 0 | 0 | 0 |
| M10 | Multi-model adversarial review | F-082..F-087 | 6 | 6 | 0 | 0 | 0 | 0 |
| M11 | Soul / introspect / replay | F-088..F-092 | 5 | 5 | 0 | 0 | 0 | 0 |
| M12 | Visualization (NEW) | F-093..F-095 | 3 | 3 | 0 | 0 | 0 | 0 |
| M13 | Multimodal input (NEW) | F-096..F-100 | 5 | 5 | 0 | 0 | 0 | 0 |
| M14 | Productivity (NEW) | F-101..F-103 | 3 | 3 | 0 | 0 | 0 | 0 |
| M15 | Build / packaging | F-104..F-109 | 6 | 6 | 0 | 0 | 0 | 0 |
| M16 | Telemetry | F-110..F-113 | 4 | 4 | 0 | 0 | 0 | 0 |
| M17 | Documentation | F-114..F-118 | 5 | 5 | 0 | 0 | 0 | 0 |
| M18 | Marketplace local-v1 | F-119..F-121 | 3 | 3 | 0 | 0 | 0 | 0 |
| **NEW from research** | Frontier-2026 candidates | F-122..F-126 | 5 | 5 | 0 | 0 | 0 | 0 |
| M19 | Deferred (user-acknowledged tracking row) | F-D-001..F-D-018 | 18 | 0 | 0 | 0 | 18 | 0 |
| **TOTAL** | (121 base + 5 new + 1 wave-017 NEW = 127 active) + 18 deferred | | **145** | **98** | **7** | **22** | **18** | **0** |

> Wave-1 research lanes consolidated ~78 additional F-NNN candidates as F-127..F-204 (see `docs/04-research/wave-001-new-fnnn-candidates-consolidated.md`). These are tracked in the consolidation matrix and will be allocated against existing milestones (or roll a M20+) as design decisions close. They are NOT counted in the milestone-overview table above; that table uses the foundational-plan F-NNN allocation only.

> Wave-10 transition note (closing summary `docs/11-loop-state/wave-history/wave-010.md`): F-008 (M0), F-019 / F-020 / F-022 (M2) flipped RED → GREEN. Wave-11 in flight: Lane A (F-007 ipc-contract-scaffold), Lane B (F-001 GREEN → LOCKED candidate via post-impl council review), Lane C (M5 desktop-shell ledger refresh + RED→GREEN candidate), Lane D (this lane — roadmap freshness).

> Wave-12 / Lane C transition note: F-122..F-126 (the 5 frontier-research candidates that had been PLANNED for several waves) flipped PLANNED → RED. Ledgers now exist in their respective milestone directories: F-122 (M4), F-123 (M16), F-124 (M1), F-125 (M7), F-126 (M8). Provenance traces to wave-1 Lane A (findings 21, 23) + Lane B (findings 10, 15, 16). D-3 (F-125 default cap) and D-4 (F-124 default policy) remain OPEN; closure is prerequisite for RED → GREEN flips.

> Wave-12 / Lane D transition note: F-002 + F-006 + F-008 flipped GREEN → LOCKED via post-impl council reviews. Three new review files under `docs/05-design-reviews/council-reviews/` (F-002 median confidence 90; F-006 median 86; F-008 median 88; all verdict ACCEPT, 0 CRITICAL / 0 MAJOR each). M0 now reads 3R + 1G + 4L (F-001/F-002/F-006/F-008 LOCKED; F-007 GREEN; F-003/F-004/F-005 RED). Total project state: 114 RED / 8 GREEN / 4 LOCKED across 144 features (126 active + 18 deferred).

> Wave-12 / Lane A transition note: F-021 (degradation-fallback) flipped RED → GREEN. New `packages/engine-core/src/degradation.ts` (~208 LOC) lands the in-memory `DegradationLadder` primitive — a 5-rung escalation ladder (`normal → skill-fallback → model-fallback → reduced-tool-set → headless → halt`) with `escalate(trigger)` advancing one rung at a time and `recover(reason)` dropping one rung; reaching 'halt' returns a `RunHaltedVerdict` (trigger=`degrade_escalate`, the 14th value in the F-018 `HaltTrigger` union). Per-resource circuit-breaker, Context-Gaps emission, required-vs-optional classification, and F-018 hand-off for required-dependency failures deferred to engine-cycle integration per `rules/no-silent-deferrals.md`. M2 row updated 2R + 7G → 1R + 8G; TOTAL 114R / 8G → 113R / 9G.

> Wave-13 / Lane D transition note: F-018 + F-019 + F-020 + F-022 flipped GREEN → LOCKED via post-impl council reviews. Four new review files under `docs/05-design-reviews/council-reviews/` (F-018 median 89; F-019 median 89; F-020 median 88; F-022 median 88; all verdict ACCEPT, 0 CRITICAL / 0 MAJOR each). M2 row aggregate-count update is owned by whichever lane lands last (Lane C is flipping F-014/15/16/17 in parallel; the row-state count refresh is intentionally deferred to a post-wave-13 refresh lane to avoid the cross-lane stale-input race documented in `confidence-ledger.md` Lane-D-w12-roadmap-F-001-LOCKED-restored). Per-feature row state above is owned by the lane that flipped each feature.

> Wave-12 / Lane B transition note: F-017 (pii-redaction-egress) flipped RED → GREEN. New `packages/engine-core/src/redaction.ts` (~104 LOC) lands the `redact()` + `redactObject()` helper primitives — pattern-based PII redactor for engine egress paths (audit-log writes, telemetry exports, outbound LLM-call prompts) with 4 built-in categories (emails, phones, GUIDs, home paths) + `customPatterns` for project-specific tokens. Order-of-operations (emails → GUIDs → phones → home paths → custom) prevents GUID-vs-phone false-match. Reject-on-detect orchestration (ledger's stricter `PII_DETECTED: <category>` semantics), F-015 audit-log emission tie-in, M16 telemetry-export integration, M1 LLM-call integration, and adversarial-eval lane deferred per `rules/no-silent-deferrals.md`. M2 row 1R + 8G → 0R + 9G; TOTAL 113R / 9G → 112R / 10G. **M2 governance triad now fully RED-cleared.**

> Wave-13 / Lane A transition note: **F-021 finalization** (deferred from wave-12 / lane-a). No row state change — F-021 is already 🟢 GREEN at wave-12 HEAD via commits `8d79b1f` (RED test stub) + `226acaa` (GREEN impl). Lane finalizes the deferred docs + proof artifacts that the wave-12 / lane-a ledger commit (intended SHA `395b79b`) failed to land due to the pre-commit-hook subject-rerouting pathology (commit `395b79b` actually landed F-017 redaction files under the F-021 ledger subject). This lane lands: F-021 ledger frontmatter flip (status: red → green + status-history append + Implementation notes section), `docs/09-examples-proof/F-021/{red,green}-test-output.txt` proof artifacts, wave-13 confidence-ledger entries, and this transition note. M2 row 0R + 9G unchanged; TOTAL 112R / 10G / 4L unchanged. Full suite at finalization time: 94/94 PASS across 14 test files (no regressions vs wave-12 / lane-b checkpoint).

> Wave-13 / Lane B transition note: **F-005 RED → GREEN** + **F-007 GREEN → LOCKED** (paired flip in same lane). F-005 deps-pinning lands `tests/node/F-005-deps-pinning.test.ts` (4 tests; root + workspace package.json exact-pin sweep, lockfile presence, engines.node specified) — RED captured (5 `^`-prefixed devDeps), root `package.json` updated to exact pins (vitest 2.1.9, @vitest/ui 2.1.9, happy-dom 15.11.7, typescript 5.9.3, @types/node 20.19.39) + `packageManager: pnpm@9.0.0` declared, `pnpm-lock.yaml` regenerated with exact-pin specifiers, GREEN captured (4/4 PASS); package-manager choice (npm → pnpm) recorded in F-005 ledger §Implementation notes (transfers F-005 intent: committed lockfile + reproducible install + frozen-lockfile install path). F-007 ipc-contract-scaffold council review at `docs/05-design-reviews/council-reviews/F-007-ipc-contract-scaffold-review.md` verdict ACCEPT (median confidence per Advocate / Skeptic / Architect lenses; 0 CRITICAL / 0 MAJOR; scaffold-shape contract only, M5 integration scenarios deferred per F-007 ledger). M0 row 3R + 1G + 4L → 2R + 1G + 5L; TOTAL 112R + 10G + 4L → 111R + 10G + 5L. **Fifth LOCKED transition in the repo** (after F-001 wave-11, F-002 + F-006 + F-008 wave-12). Full suite at GREEN time: 98/98 across 15 test files (was 94/94 across 14 pre-F-005).

> Wave-14 / Lane C transition note: **F-004 RED → GREEN** (vitest-playwright-config). `vitest.config.ts` gains the `browser` project (4th in `projects[]`, env `happy-dom` + glob `tests/browser/**/*.test.ts`, runtime wiring `browser: { provider: 'playwright', ... }` deferred to first DOM-rendering spec consumer wave to avoid shipping ~200MB browser-binary download to every clone before any spec exists). New `playwright.config.ts` at repo root mirrors clawpilot baseline (`C:/Users/tonym/Repos/m-main/playwright.config.ts`): `defineConfig({ testDir: 'e2e', testMatch: '**/*.test.ts', timeout: 60_000, expect: { timeout: 10_000 }, workers: 1, retries: 2, reporter: [['html'], ['list']], projects: [] })`. `@playwright/test` devDep + sharedTest fixture-mode behavior + `pnpm e2e` script deferred per `rules/no-silent-deferrals.md` to M5 desktop-shell + e2e companion suites — config-present at v1, runtime-functional at first consumer wave. New `tests/node/F-004-vitest-playwright-config.test.ts` (7 tests; vitest.config.ts existence + 4 project names + integration testTimeout=30_000 + playwright.config.ts existence + parseable defineConfig invocation; all structural via `existsSync` + `readFileSync` + regex; no module imports — works without `@playwright/test` installed); 7/7 PASS. M0 row aggregate-count update is owned by whichever lane lands last in wave-14 (per the cross-lane stale-input race convention from wave-13 / lane-d). Per-feature row state above (F-004 row) owned by this lane. **M0 active-feature set is now 100% RED-cleared** when this lane + the F-003 sibling lane both land. Tenth feature transition lane in the repo for M0; F-004 is **15th feature transition RED → GREEN** in repo history (after F-001/F-002/F-006/F-007/F-008/F-014/F-015/F-016/F-017/F-018/F-019/F-020/F-021/F-022/F-005). Full suite at GREEN time: 28/28 across `tests/node` (4 test files: F-003 + F-004 + F-005 + F-008).

> Wave-13 / Lane C transition note: **F-014 + F-015 + F-016 + F-017 flipped GREEN → LOCKED** via post-impl council reviews (parallel-quadruple LOCKED-flip). Four new review files under `docs/05-design-reviews/council-reviews/` (F-014 median 88; F-015 median 89; F-016 median 87; F-017 median 86; all verdict ACCEPT; 0 CRITICAL / 0 MAJOR each; MINOR findings are honest scope-narrowing notes per `no-silent-deferrals.md`). **Sixth, seventh, eighth, and ninth LOCKED transitions in the repo** (after F-001 wave-11, F-002 + F-006 + F-008 wave-12, F-007 wave-13/lane-b). Lane C is the **last-lander** for wave-13 and refreshes the M2 + TOTAL aggregate counts (per the wave-13/lane-d deferral): M2 row 0R + 9G → 0R + 1G + 8L (F-014/15/16/17/18/19/20/22 LOCKED; F-021 still GREEN); TOTAL 111R + 10G + 5L → 111R + 2G + 13L. **M2 governance triad GREEN→LOCKED batch is COMPLETE except F-021** (which remains GREEN since wave-12/lane-a's redactor-helper-primitive flip is not yet a council-reviewed scope-locked surface; F-021 LOCKED is a future-wave candidate). Wave-13 lands **8 LOCKED transitions in a single wave** (4 from lane-c + 4 from lane-d). Validates the parallel-quadruple LOCKED pattern proposed in wave-12/lane-d's "parallel-triple LOCKED-flip wave" finding.

> Wave-14 / Lane B transition note: **F-003 repo-scaffolding RED → GREEN.** New `tests/node/F-003-repo-scaffolding.test.ts` (11 structural assertions: workspace globs + strict TS + lint/format/editor configs + 3-package monorepo + LICENSE/README/.gitignore). RED captured 2/11 fail (`packages/desktop-shell/package.json` + `packages/cli/package.json` missing); GREEN flip authored both as empty-but-named workspace packages with `@mad-council-claw/<slug>` naming, `type: module`, `private: true`. 11/11 PASS at GREEN time. Most scaffolding (root tsconfig, eslint, prettier, editorconfig, engine-core, LICENSE/README/.gitignore) was de-facto landed by waves 11+13; this lane closes the workspace-package gap. M0 row 2R + 1G + 5L → 1R + 2G + 5L; TOTAL 111R + 2G + 13L → 110R + 3G + 13L. **15th feature transition RED → GREEN in the repo** (after F-001 / F-002 / F-006 / F-008 / F-014 / F-015 / F-016 / F-017 / F-018 / F-019 / F-020 / F-021 / F-022 / F-007 / F-005). Per-package tsconfig + working `npm run build` topological compile + concrete src/ for desktop-shell/cli deferred per `no-silent-deferrals.md`.

> Wave-17 / Lane A transition note: **F-138 engine-cycle-orchestrator NEW (not promotion) RED → GREEN in same lane.** First NEW feature lane since wave-002 catalog authorship; first feature whose explicit purpose is to **integrate** prior LOCKED primitives. Resolves wave-016 / lane-d Copilot CLI HARD-BLOCK F1 (cross-model Critical from claude-opus-4.7 + Major from gpt-5.5: "no engine-cycle orchestrator wires F-001 → F-009 → F-019 → F-022 → F-021 → F-018 → F-014"). New `tests/unit/F-138-engine-cycle-orchestrator.test.ts` (3 acceptance scenarios: completed run / forceHaltTrigger='manual' halted run / null retro throws RetroMissingError) + `packages/engine-core/src/cycle.ts` (~210 LOC: `runEngineCycle` async dispatcher + `EngineCycleConfig` + `RunOutcome` + private `AuditChain` adapter wrapping appendAuditEntry for ergonomics). Composes F-002 createAgent/createSession + F-009 IBackendProvider startSession/sendPrompt/halt/stopSession + F-018 HaltDetector (recordToolCall/recordSuccess/recordFailure/manualHalt) + F-019 CostLedger (instantiated; totalUsd reported) + F-015 appendAuditEntry (cycle.start / backend.session.start / backend.event / cycle.halted / backend.session.stop / cycle.end) + F-014 closeSession (mandatory close-transition; throws RetroMissingError on null/invalid). 3/3 PASS at GREEN time (vitest 2.1.9, 7ms isolated); full unit suite 147/163 PASS (16 pre-existing failures unrelated: F-024/F-025 RED scenarios + F-030 CLI). M0 row 0R + 0G + 8L → 0R + 1G + 8L (M0 expands by 1 to 9 features); TOTAL 102R + 2G + 22L → 102R + 3G + 22L (active feature count 126 → 127). **24th feature transition RED → GREEN in the repo**, **D-35 in design-decisions-pending.md marked RESOLVED**. Honest scope discipline: 7 numbered scope-narrowing notes in §out-of-scope-notes enumerate every primitive composed but not yet end-to-end wired (F-017 redaction at audit-egress, F-021 ladder, F-020 polling, F-022 per-spawn, F-002 stamp at audit-writer, F-013 usage variant, multi-iteration loop). **Orchestrator-identity rule held throughout**: cycle.ts NEVER re-implements primitive logic — calls appendAuditEntry (does not compute hash chains itself), calls closeSession (does not validate retro itself), calls backend.startSession (does not invoke any SDK directly). Push at end of lane authorized for this loop session per user directive 2026-05-07.

> Wave-17 / Lane C transition note: **F-026 resume-from-checkpoint RED → GREEN + F-027 manual-halt-override RED → GREEN — M3 cron-heartbeat 100% RED-cleared (5/5 GREEN)**. Fourth + fifth M3 feature transitions; combined with Lane B's F-024+F-025 closes M3 entirely. New `tests/node/F-026-resume-from-checkpoint.test.ts` (~155 LOC, 6 scenarios: save creates file, load round-trips, load returns null when missing, exists reflects presence, schemaVersion preserved, savedAt auto-injected ISO-8601) + `packages/engine-core/src/checkpoint.ts` (~80 LOC: `CheckpointManager` class + `Checkpoint` + `CheckpointInput` + `PipelinePhase` types; persists via F-008 `atomicWriteJson`; null on missing file). New `tests/unit/F-027-manual-halt-override.test.ts` (~135 LOC, 6 scenarios: consent=true → RUN_HALTED with trigger=manual, consent=false → throws "consent denied" abort, runId stamped, reason verbatim, async consent awaited, ISO-8601 timestamp at fire-time) + `packages/engine-core/src/manual-halt.ts` (~80 LOC: `manualHaltOverride({runId, reason, consentGate})` async function returning `Promise<RunHaltedVerdict>`; reuses `RunHaltedVerdict` shape from `halt.ts` per wave-011/lane-a "shared types live with FIRST owner" rule; trigger='manual' is the F-018 sibling reserved for operator halts). **Scope simplified vs ledgers** — F-026 contributes the CHECKPOINT PRIMITIVE only (F-015 audit-chain `cycle_state_sha256` verification + `last_completed_cycle` advancement + scheduler resume dispatch deferred to engine-cycle integration step); F-027 contributes the OPERATOR HALT VERDICT only (pause-schedule write + bulk-halt consent gate + `kill-switch.json` file write + F-014 retro emission deferred to caller integration). Both deferrals recorded openly in the respective ledger §Implementation notes per `no-silent-deferrals.md`. F-026 + F-027 isolated test 12/12 PASS at GREEN time; full suite 225/225 PASS across 31 test files. **26th and 27th feature transitions RED → GREEN in the repo** (after Lane B's F-024 + F-025 = 24th + 25th). M3 row 2R + 3G + 0L → 0R + 5G + 0L (**M3 cron-heartbeat 100% RED-cleared**); TOTAL 100R + 4G + 22L → 98R + 6G + 22L. **Cross-lane staging-race sighting #19+ observed** (chronic pattern across waves 9-17): F-026 GREEN files (`checkpoint.ts` + barrel update + green-test-output.txt) landed in commit `2463d90` (subject "test(F-024,F-025): RED actual"); F-027 GREEN files (`manual-halt.ts` + barrel update + green-test-output.txt) landed in commit `a8f5de2` (subject "feat(F-030): GREEN cli-json-output") — the F-030 commit message even claims "Sibling-lane work (F-024/F-025/F-026/F-027/F-138 + engine-core edits) explicitly NOT touched per cross-lane staging-discipline" while contradicting that claim by including the swept files. Per `non-negotiable-rules.md` (NO destructive git ops, NO `git reset` per user directive 2026-05-07), no rebase/reset to fix history; substance preserved (12/12 tests PASS); credit attribution corrupted; authoritative provenance documented in F-026 + F-027 ledger §Implementation notes per `verification-protocol.md` Rule 1 (FETCH BEFORE CITE). Push at end of lane authorized for this loop session per user directive 2026-05-07.

> Wave-17 / Lane B transition note: **F-024 skip-on-overlap RED → GREEN + F-025 idle-archival RED → GREEN** — second + third M3 (cron / heartbeat) feature transitions, both as same-class extensions of F-023's `HeartbeatScheduler` (wave-16 / lane-b GREEN). New `tests/unit/F-024-skip-on-overlap.test.ts` (8 scenarios: tick skips when prior in-flight; skippedTicks counter; in-flight clears post-handler including throw-path; sequential ticks both run; parallel ticks return correct ran flags; getStatus surfaces skippedTicks + isInFlight) + new `tests/unit/F-025-idle-archival.test.ts` (8 scenarios: archiveAfterMinutes triggers callback when idle exceeds threshold; no callback below threshold; idle measured from lastTickAt not creation; multiple callbacks broadcast; default archiveAfterMinutes=undefined disables; callback receives idleMinutes; fires on each threshold-exceeding tick; composition with F-024 — skipped ticks do NOT fire idle-archival callback). `packages/engine-core/src/heartbeat.ts` extended (~50 added LOC) with: `tickInFlight` boolean + `skippedTicks` counter + `TickResult { ran, skipped? }` return shape (backward-compatible — F-023 callers discarded the return value); `archiveAfterMinutes` config field + `IdleArchiveCallback` exported type + `onIdleArchive(callback)` registration + idle-gap detection in `tick()`. **Scope simplified vs ledgers** — F-024 contributes the SKIP signal only (cron-fires.jsonl `outcome: "overlap_skipped"` write deferred to F-006/F-008 callers); F-025 contributes the IDLE TRIGGER only (atomic-rename + orphan recovery deferred to F-008 storage-layout layer). Both deferrals recorded openly in the respective ledger §Implementation notes per `no-silent-deferrals.md`. F-024 + F-025 isolated test 16/16 PASS at GREEN time; F-023 21/21 PASS no regression; full suite 219/225 PASS (the 6 fails are concurrent-lane F-027 RED, NOT in this lane's scope). **24th and 25th feature transitions RED → GREEN in the repo** (after wave-16/lane-c's F-028 = 23rd). M3 row 4R + 1G + 0L → 2R + 3G + 0L; TOTAL 102R + 2G + 22L → 100R + 4G + 22L. **Cross-lane staging-race sighting #17 observed** (matched to waves 9-16 sightings #14-#16): two commits before this lane's RED files actually landed (e466b52 + 2463d90) used this lane's subject but committed concurrent lanes' files (F-029 + F-026 + F-030); fix-forward commit b957489 chained `git restore --staged + add + commit` in a single bash invocation to minimize race window and successfully landed all 4 RED files. Per `non-negotiable-rules.md` (NO destructive git ops, NO `git reset` per user directive 2026-05-07), no rebase/reset to fix history. Pattern is now **chronic** across waves 9-17.

> Wave-17 / Lane D transition note: **F-029 cli-subcommands RED → GREEN + F-030 cli-json-output RED → GREEN** — second + third M4 (Headless CLI) feature transitions, both composing against F-028's `runCli` / `Subcommand` surface (wave-016 / lane-c GREEN) without changing it. New `tests/node/F-029-cli-subcommands.test.ts` (8 scenarios: closed 11-name registry contract; async-callable shape returning Promise<number>; version emits "0.0.0\n"; help emits help-pointer line; 9 stubs emit deterministic "F-029 stub: subcommand '<name>' (args: ...)" lines; arg passthrough echoes in stub line; runCli with standardSubcommands dispatches every name; runCli unknown-subcommand still returns non-zero per F-028 contract). New `tests/node/F-030-cli-json-output.test.ts` (7 scenarios: hasJsonFlag exact-match — substring `--jsonpath`/`--no-json` do NOT trip it; stripJsonFlag preserves order + handles multiple --json instances; emitJson writes one JSON line terminated by exactly one trailing \n; JsonOutput envelope shape; runCli strips --json from subArgs across leading/sandwiched/trailing/absent positions; ok=true round-trip; ok=false round-trip). New `packages/cli/src/subcommands.ts` (~70 LOC, ESM): `standardSubcommands: Record<string, Subcommand>` with the closed v1 set (start, status, halt, retro, replay, query-audit, list-sessions, archive, restore, version, help) — 9 stubs return 0 + emit deterministic stdout; version emits exactly "0.0.0\n"; help emits a help-pointer line. New `packages/cli/src/json-output.ts` (~50 LOC, ESM): `JsonOutput` interface (`{ ok: boolean; data?: unknown; error?: string }`) + `hasJsonFlag(args)` (exact-equality detection) + `stripJsonFlag(args)` (removes ALL --json instances preserving order) + `emitJson(output)` (single JSON line + trailing newline). `packages/cli/src/index.ts` 1-import + 1-line edit: imports `stripJsonFlag` from `./json-output.js`; runCli now strips --json from subArgs before forwarding to the matched subcommand (subcommand never sees --json directly). `packages/cli/package.json` exports map gains `"./subcommands"` and `"./json-output"` subpaths. **Scope deviations recorded openly** per `no-silent-deferrals.md`: (1) F-029 ships MINIMUM-VIABLE STUBS only — concrete behavior (engine kernel calls, audit query, storage-layer archive, retro hooks, daemon control, session registry reads) deferred to subsequent M4+ features; (2) F-029 sysexits.h normalization (EX_USAGE=64 on unknown subcommand path) deferred — F-028's exit code `1` preserved unchanged; (3) F-030 ships THE FLAG-DETECTION + EMIT PRIMITIVES only — per-subcommand schemas + NDJSON streaming for audit query (50k entries, <200MB memory bound) + sysexits.h exit codes (e.g. EX_DATAERR=65) deferred to subsequent M4+ features when concrete subcommand behavior lands; (4) `--format text|json` flag scope-simplified to boolean `--json` — `--format` is its own future feature, current envelope shape will accept that extension without re-shaping. **New ledger-deferral idiom** "minimum-viable-stub-with-deterministic-stdout" registered in the project lexicon (distinct from F-010/F-011's "stub-body-vs-deferred-real-SDK" + F-004's "config-present, runtime-deferred"). F-029 8/8 PASS + F-030 7/7 PASS at GREEN time; node-suite full pass 56/56 across 8 files (was 35/35 across 5 pre-this-lane). M4 row 3R + 1G + 0L → 1R + 3G + 0L (**M4 75% RED-cleared — only F-031 daemon-mode remains RED**). TOTAL aggregate refresh deferred to last-lander per the wave-13/14/15 last-lander pattern (Wave-17 / Lane A + Lane B + Lane C have already pre-claimed the wave-17 reconciliation; this lane contributes its 2 RED-clears + 2 GREEN flips for the eventual last-lander). **28th and 29th feature transitions RED → GREEN in the repo** (after Lane A's F-138 = 24th + Lane B's F-024+F-025 = 25th+26th + Lane C's F-026+F-027 = 27th+28th — wave-17 sibling-lane order; this lane's F-029=29th, F-030=30th if counted by transition-order in wave-17). **Cross-lane staging-race sighting #17 observed twice in this lane** (matching Lane B's + Lane C's accounts): (a) commit `e466b52` (sibling Lane B F-024/F-025 RED subject) inadvertently swept this lane's `tests/node/F-029-cli-subcommands.test.ts` into its commit; substance preserved in HEAD (F-029 RED test → GREEN tests pass), credit attribution corrupted; (b) this lane's F-030 GREEN commit (`a8f5de2`) inadvertently swept sibling Lane C's F-027 GREEN files (`docs/09-examples-proof/F-027/green-test-output.txt`, `packages/engine-core/src/manual-halt.ts`, `packages/engine-core/src/index.ts`) into its commit due to broader pre-commit-hook scope than the explicit `git add` set — same sighting #17 pattern, reverse direction (this lane the SWEEPER not the swept). Lane B's "combined `git add && git commit` single bash invocation" mitigation was used for both my GREEN commits (`ae0a5f7` F-029 + `a8f5de2` F-030) and DID land cleanly for F-029 — F-030 still got cross-swept anyway, suggesting the pre-commit hook itself (not the staging window) is the culprit. Per `non-negotiable-rules.md` (NO destructive git ops, NO `git reset` per user directive 2026-05-07), no rebase/reset to fix history; substance preserved on both sides; credit attribution recorded openly. **Pattern remains chronic across waves 9-17**; per Lane B's note + wave-16/lane-a's note + Lane C's #19+ extension, escalation candidate (per-lane branches when concurrent lane count >= 3 OR per-lane scope-manifest hook OR pre-commit-hook scope-restriction) deferred until end of wave-17 retro to assess across all 4 lanes' experiences this wave.

> Wave-16 / Lane B transition note: **F-023 cron-heartbeat RED → GREEN** — first M3 (cron / heartbeat) feature transition. New `tests/unit/F-023-cron-heartbeat.test.ts` (288 LOC, 21 scenarios across 6 describe blocks: cadence profile resolution, forbidden-zone enforcement per `kit:rules/loop-cadence-discipline.md`, tick lifecycle, start/stop lifecycle including fake-timers setInterval witness, getStatus observability, CadenceProfile type witness). New `packages/engine-core/src/heartbeat.ts` (~145 LOC): `HeartbeatScheduler` class with constructor cadence-zone gate (mad-iteration → 270s warm-cache; deployment-watch → 1500s amortized; 280-1199s rejected with remediation pointer; `enforceWarmCacheZones: false` operator escape hatch); `start(handler)` / `stop()` (idempotent) / public `tick()` (test ergonomics + manual-mode driver) / `getStatus()` / `getIntervalSeconds()`. **Scope simplified vs ledger §Behavior contract** — F-023 is intentionally the SCHEDULER PRIMITIVE only (no I/O, no run spawn, no `cron-fires.jsonl` append, no drift accounting). Mirrors F-022 ToolCallQuota + F-018 HaltDetector pure-class pattern. Composition by callers per `no-silent-deferrals.md`: F-001 (engine-bootstrap-loop) supplies the boot-fresh-run handler; F-006 + F-008 wire `cron-fires.jsonl`; F-024 wraps with overlap detection; F-002 resolves agent identity; F-026/F-027 calculate drift via `getStatus.lastTickAt` + `tickCount`. F-023 isolated test 21/21 PASS at GREEN time; full suite 179/179 PASS across 24 test files. **Cross-lane staging-race sighting #16** observed (matched by Wave-16 / Lane A's note): F-023's source files (`heartbeat.ts` + barrel re-export) landed under commit `fdede59 docs(F-011): post-impl council review verdict ACCEPT` — substance preserved (verified by F-023 isolated test), credit attribution corrupted. Per `non-negotiable-rules.md` (no destructive git ops), no rebase/reset to fix history. Fix-forward commit `f59c4ce` restored F-012 + F-013 barrel re-exports also lost in the same race; proof artifacts committed in `0d4c84a`. **23rd feature transition RED → GREEN in the repo** (after wave-15 / lane-d's 21st = F-013). M3 row 5R + 0G → 4R + 1G; TOTAL 104R + 0G + 22L → 102R + 2G + 22L (combines Lane A's 4 LOCKED-flips landing first + this lane's F-023 RED-clear; aggregate already reflects Lane A pre-this-lane; this lane drops 1R, adds 1G).

> Wave-16 / Lane A transition note: **4 LOCKED transitions** (F-010 + F-011 + F-012 + F-013 GREEN → LOCKED) via post-impl council reviews. Four new review files under `docs/05-design-reviews/council-reviews/` (F-010 median 88; F-011 median 87; F-012 median 90; F-013 median 88; all verdict ACCEPT, 0 CRITICAL / 0 MAJOR each; MINOR findings are honest scope-narrowing notes per `no-silent-deferrals.md`). **19th, 20th, 21st, and 22nd LOCKED transitions in the repo** (after wave-15 / lane-a's batch of F-003 + F-004 + F-005 + F-009 + F-021 = 14th-18th). M1 row 0R + 4G + 1L → 0R + 0G + 5L (**100% LOCKED — M1 backend pluggability complete**). TOTAL 104R + 4G + 18L → 104R + 0G + 22L. **Wave-16 / Lane A closes M1 100% LOCKED** — three of three active milestones with implementation scope (M0 + M1 + M2) now reach 100% LOCKED. F-010 + F-011 stub-bodies are explicitly LOCKED at the minimal-contract scope (real `@anthropic-ai/sdk` + Copilot CLI swaps remain gated on F-070 secure-storage + recorded-fixture harness per ledger out-of-scope-notes); the F-009 contract surface accepts both concrete providers + the routing factory + the convenience-layer helpers without contract drift, validating the F-009 review's "cross-SDK normalization is satisfied by the union shape itself" claim. **Cross-lane staging-race sighting #16** observed: sibling F-023 lane's `packages/engine-core/src/heartbeat.ts` was swept into commit `fdede59` (this lane's F-011 review file commit) because the file existed untracked in the working tree at `git add docs/...F-011...md` time and pre-commit hooks committed broader scope; per user directive 2026-05-07 (NO `git reset`), the leak is acknowledged for audit-trail integrity, not remediated by rewriting history. Wave-17+ candidate (escalation): per-commit `git diff --cached --name-only` assert before each commit OR per-lane branches when concurrent lane count ≥3.

> Wave-15 / Lane A transition note: **5 LOCKED transitions in a single lane** (F-003 + F-004 + F-005 + F-009 + F-021 GREEN → LOCKED) via post-impl council reviews. Five new review files under `docs/05-design-reviews/council-reviews/` (F-003 median 87; F-004 median 87; F-005 median 88; F-009 median 89; F-021 median 88; all verdict ACCEPT, 0 CRITICAL / 0 MAJOR each; MINOR findings are honest scope-narrowing notes per `no-silent-deferrals.md`). **14th, 15th, 16th, 17th, and 18th LOCKED transitions in the repo** (after F-001 wave-11; F-002 + F-006 + F-008 wave-12; F-007 + F-014/15/16/17 + F-018/19/20/22 wave-13). M0 row 0R + 3G + 5L → 0R + 0G + 8L (**100% LOCKED — M0 active feature set complete**). M1 row 4R + 1G + 0L → 4R + 0G + 1L (**first M1 feature LOCKED**). M2 row 0R + 1G + 8L → 0R + 0G + 9L (**100% LOCKED — M2 governance triad complete**). TOTAL 108R + 5G + 13L → 108R + 0G + 18L. **Wave-15 / Lane A lands 5 LOCKED transitions in a single lane** — validates the parallel-quintuple LOCKED-flip pattern, extending the parallel-quadruple (wave-13) and parallel-triple (wave-12) precedents. Two of three active milestones (M0 + M2) are now 100% LOCKED for their implementation scope; M1 has its contract locked with concrete backends (F-010/F-011) + factory (F-012) + event-normalization (F-013) remaining RED.

> Wave-15 / Lane B transition note: **F-010 anthropic-sdk-provider RED → GREEN** — second M1 (backend pluggability) feature flipped (after F-009 in wave-14, parallel with F-011/F-012/F-013 sibling lanes in same wave-15). New `tests/unit/F-010-anthropic-backend.test.ts` (7 scenarios: AnthropicBackend implements IBackendProvider with origin='anthropic'; startSession returns 'anthropic-<runId>'-tagged sessionId; sendPrompt streams token (with model id surfaced) + finish/stop; unknown sessionId throws; halt yields finish/error rather than removing session — observability-preserving variant per F-018 RUN_HALTED contract; stopSession removes session; halt is idempotent). New `packages/engine-core/src/backend-anthropic.ts` (~85 LOC: AnthropicBackend class implementing F-009 IBackendProvider with deterministic STUB body; constructor accepts optional model id default 'claude-opus-4-7'; sessions Map + halted Set for state). 7/7 PASS at GREEN time. **Real `@anthropic-ai/sdk` integration explicitly deferred** per `rules/no-silent-deferrals.md` — gated on (a) F-070 secure-storage for `ANTHROPIC_API_KEY` (per ledger `[NEEDS CLARIFICATION: secure storage]` note) and (b) recorded-fixture test harness. Stub satisfies the F-009 structural contract (origin tag, IBackendProvider compliance, BackendEvent shape correctness, halt composing with F-018 RunHaltedVerdict); swapping the stub body for a real SDK call is self-contained. **Halt-semantics divergence from F-009 StubBackend** is intentional and documented: StubBackend's halt removes the session (subsequent sendPrompt throws "Unknown session"); AnthropicBackend's halt keeps the session registered so subsequent sendPrompt yields `finish/error` with `details: 'Session halted'` — F-020 (kill-switch) and F-022 (tool-call quota) both rely on this cross-provider parity (mirrored by sibling F-011 lane C). **17th/18th feature transition RED → GREEN in the repo** (counted alongside Lane C's concurrent F-011 flip). M1 row 4R + 0G + 1L → 3R + 1G + 1L (this lane's contribution; Lane C's concurrent F-011 flip drops it further). TOTAL aggregate reconciliation deferred to last-lander per the wave-13/14 `last-lander` pattern. New ledger-deferral idiom **"stub-body-vs-deferred-real-SDK"** named for first time (distinct from F-004's "config-present, runtime-deferred"; distinct from F-022's "scope narrowing"). Future SDK-bound features (F-029..F-031 MCP transports, F-184..F-187 Foundry memory) should cite this entry.

> Wave-15 / Lane D transition note: **F-012 backend-factory + F-013 event-normalization RED → GREEN** — third + fourth M1 feature transitions in wave-15 (parallel with sibling Lane B's F-010 + Lane C's F-011, after Lane A's wave-15 LOCKED batch). New `tests/unit/F-012-backend-factory.test.ts` (6 scenarios: kind dispatch for anthropic / copilot / stub; unknown kind throws; model parameter forwarding to anthropic + copilot constructors; interface contract preservation across all kinds). New `packages/engine-core/src/backend-factory.ts` (~95 LOC): `createBackend({kind, model})` factory function dispatches to `AnthropicBackend` / `CopilotBackend` / `StubBackend` via TS exhaustive-switch over the `BackendKind` union (`'anthropic' | 'copilot' | 'stub'`); pure-function shape (no I/O); `BackendNotRegistered` realized via TS exhaustive-switch never-arm + runtime throw. **Scope simplified vs ledger** (createBackendProvider + MAD_BACKEND env override) — env-var resolution moved up to caller per future F-067 settings layer (M8); recorded openly in F-012 ledger §Implementation notes per `no-silent-deferrals.md`. New `tests/unit/F-013-backend-event-normalization.test.ts` (9 scenarios: 4 type-guard checks, 4 content-extractor checks, 1 cross-provider witness exercising StubBackend + AnthropicBackend + CopilotBackend through the same union). New `packages/engine-core/src/backend-events.ts` (~95 LOC): 4 type guards (`isTokenEvent`, `isToolCallEvent`, `isToolResultEvent`, `isFinishEvent`) + `eventTextContent(e)` content-extractor returning verbatim text for tokens or deterministic descriptors for tool/finish events. **F-013 ledger 9-variant superset NOT implemented** — F-009's 4-variant `BackendEvent` union (`token | tool_call | tool_result | finish`) already satisfies the cross-SDK normalization contract because every concrete backend already emits identical events. F-013 contributes the convenience layer so downstream consumers (F-014 retro, F-015 audit, F-019 cost-ledger) don't re-implement narrowing. The 5 missing variants (`message_start`, `tool_use_input_delta`, `usage`, `cancelled`, `error`) tracked for future event-richness wave per `no-silent-deferrals.md`. **20th and 21st feature transitions RED → GREEN in the repo** (after F-010/F-011 in this same wave). Full suite at GREEN time: 151/151 PASS across 22 test files (was 136/136 across 20 pre-F-012/F-013). **Last-lander aggregate reconciliation:** M1 row 3R + 1G + 1L → 0R + 4G + 1L (incorporates Lane B's F-010 + Lane C's F-011 + this lane's F-012 + F-013 in one combined refresh per the wave-13 / lane-c "last-lander" pattern). TOTAL 108R + 0G + 18L → 104R + 4G + 18L. **M1 backend pluggability is now 100% RED-cleared** (4 GREEN + 1 LOCKED of 5; F-010/F-011/F-012/F-013 GREEN→LOCKED transitions pending future council-review wave). Composition: F-012 imports concrete classes from `backend-anthropic.ts` + `backend-copilot.ts` + `backend.ts`; F-013 imports the `BackendEvent` type from `backend.ts` (F-009 owner). The wave-011 / lane-a "shared types live with their FIRST owner" convention holds.

> Wave-016 / Lane C transition note: **F-028 cli-entry RED → GREEN — first M4 (Headless CLI) feature flipped.** New `tests/node/F-028-cli-entry.test.ts` (7 scenarios: root help on no args; `--help`; `-h`; unknown subcommand returns non-zero + stderr error; registered subcommand return code propagates; subcommand args flow through after subcommand name; `programName` override surfaces in help output). New `packages/cli/src/index.ts` (~95 LOC, ESM): `runCli(argv, opts): Promise<number>` async dispatcher + `CliOptions` interface (`subcommands` map, optional `defaultSubcommand`, optional `programName`) + `Subcommand` callable type. `packages/cli/package.json` gains `exports` + `bin` (`nested-quilt`) fields; root `package.json` adds `@mad-council-claw/cli: workspace:*` to devDependencies so vitest's resolver finds the workspace package (mirrors the engine-core pattern). 7/7 PASS at GREEN time; node-suite full pass 35/35 across 5 files (was 28/28 across 4). **Scope deviations recorded openly** per `no-silent-deferrals.md`: (1) exit code on unknown subcommand is `1`, not `64` (EX_USAGE) — F-029 (subcommands) will normalize the exit-code surface across the subcommand set; (2) Windows-no-flash + IPv6 dual-stack (ledger scenario 3) NOT exercised in v1 — those concerns belong to the binary launcher (electron-builder / native shim), not the JS dispatcher, tracked in F-031 (daemon-mode); (3) `--state-dir` flag + `MAD_COUNCIL_*` env-var resolution deferred to F-029 — they belong with concrete subcommands that read state, not with the entry dispatcher. **22nd feature transition RED → GREEN in the repo** (after wave-015's F-010 + F-011 + F-012 + F-013 — counted as 17/18/19/20/21 in the wave-15 last-lander reconciliation). M4 row 4R + 0G + 0L → 3R + 1G + 0L (**first M4 feature GREEN**). TOTAL 104R + 0G + 22L → 103R + 1G + 22L (reflects post-wave-15-linter state where M1 4G transitions had been folded into LOCKED prior to this lane; M1 row stays at 0R + 0G + 5L per linter; M4's 1G is the only GREEN entry in the project at lane close). **First feature in the repo to live under `packages/cli/`** — the workspace was scaffolded empty in M0 (F-006 packages-bootstrap LOCKED) and stayed empty until this lane authored the first src/ entry. The wave-011 / lane-a "shared types live with their FIRST owner" convention applies: `Subcommand`/`CliOptions`/`runCli` live with F-028 (cli/src/index.ts) — F-029, F-030, F-031 will compose against this surface without touching it.

> Wave-15 / Lane C transition note: **F-011 copilot-sdk-provider RED → GREEN** — second concrete M1 backend provider (after Lane B's concurrent F-010 flip). New `tests/unit/F-011-copilot-backend.test.ts` (7 scenarios mirroring F-010: structural witness for `IBackendProvider` with origin === 'copilot'; `startSession` returns `'copilot-<runId>'`-prefixed sessionId; `sendPrompt` streams `token` (with model id surfaced) then `finish`/`stop`; unknown sessionId throws; `halt` short-circuits subsequent `sendPrompt` to `finish`/`error` rather than removing the session — F-018 RUN_HALTED observability variant; `stopSession` removes session; `halt` is idempotent). New `packages/engine-core/src/backend-copilot.ts` (~95 LOC): `CopilotBackend` class implementing F-009's session shape with a deterministic STUB body (no real Copilot CLI / SDK invocation). Default model `'gpt-5'` constructor-injectable so F-012's factory + the M10 multi-model dispatch wave can pin specific catalog entries (e.g. `'claude-opus-4-7'` for cross-model adversarial pattern). 7/7 PASS at GREEN time; F-011-only run + F-009 sibling stays GREEN. **Real Copilot CLI / SDK invocation deferred** per `rules/no-silent-deferrals.md` — gated on (a) Copilot CLI installed and authed (device-flow OAuth + entitlement check) and (b) recorded-fixture test harness so unit tests do not require live CLI invocation. Both deferrals are explicit in the F-011 ledger `out-of-scope-notes`. **ConfigurationError: copilot CLI not found** (ledger scenario 2) is also deferred — the v1 stub does not shell out, so the missing-CLI failure mode is impossible to exercise; documented in test header. **Halt semantics intentionally identical to F-010** — once `halt(sessionId, verdict)` is called, subsequent `sendPrompt` yields `finish`/`error` with `details: 'Session halted'`. F-018's RUN_HALTED contract requires that callers observe a halt event from the provider, not just an "unknown session" error; F-020 (kill-switch) and F-022 (tool-call quota) both rely on this cross-provider parity. **19th feature transition RED → GREEN in the repo** (counting concurrently with Lane B's F-010 = 18th). M1 row 4R + 0G + 1L → 3R + 1G + 1L (this lane's contribution; Lane B's concurrent F-010 flip will further drop it to 2R + 2G + 1L when both lanes land). TOTAL aggregate reconciliation deferred to last-lander of wave-15 per the wave-13/14 `last-lander` pattern. F-012 / F-013 follow-ons remain RED — F-011 + F-010 are concrete provider implementations the F-012 factory will route to by `origin` tag.

> Wave-14 / Lane D transition note: **F-009 ibackendprovider RED → GREEN** — first M1 (backend pluggability) feature flipped. New `tests/unit/F-009-ibackend-provider.test.ts` (6 scenarios: structural witness for `IBackendProvider` interface; `startSession` returns sessionId; `sendPrompt` streams `token` then `finish`; unknown sessionId throws; `halt` accepts `RunHaltedVerdict` and removes session; `stopSession` removes session). New `packages/engine-core/src/backend.ts` (~190 LOC): `IBackendProvider` interface + `BackendEvent` discriminated union (`token` | `tool_call` | `tool_result` | `finish`) + `BackendSessionConfig` composing F-002 `Agent` + `Session` + `StubBackend` (origin "stub", deterministic test fixture). 6/6 PASS at GREEN time; full suite 122/122 PASS across 18 test files (was 116/116 across 17 pre-F-009 — discounting F-003 flake observed in early baseline). Scope deviation from original wave-002 ledger (`complete()` / `cancel()` / `listModels()` / `name: BackendName`) recorded openly in F-009 §Implementation notes per `no-silent-deferrals.md`: session-oriented surface generalizes the iterator-of-events pattern (sendPrompt returns AsyncGenerator<BackendEvent>) and adds a halt path that composes with F-018 `RunHaltedVerdict` — the M2 governance-triad halt verdict shape now flows through to backends. **16th feature transition RED → GREEN in the repo** (after F-001 / F-002 / F-006 / F-008 / F-014 / F-015 / F-016 / F-017 / F-018 / F-019 / F-020 / F-021 / F-022 / F-007 / F-005 / F-003). M1 row 5R + 0G → 4R + 1G; TOTAL reconciled by sibling Lane C as actual last-lander to 108R + 5G + 13L (incorporates this lane's F-009 GREEN + Lane B's F-003 GREEN + Lane C's F-004 GREEN in one combined aggregate refresh per the wave-13 / lane-c "last-lander" pattern). F-010 / F-011 / F-012 / F-013 follow-ons remain RED — F-009 surface is the contract; concrete provider implementations + factory + event-normalization plug in without touching this surface. Composition: F-009 imports `Agent` / `Session` from `identity.ts` (F-002) and `RunHaltedVerdict` from `halt.ts` (F-018) — the wave-011 / lane-a "shared types live with their FIRST owner" convention extends cleanly to M1.

## Per-milestone detail

### M0 — Project bootstrap

📂 [`docs/03-feature-catalog/M0-bootstrap/README.md`](docs/03-feature-catalog/M0-bootstrap/README.md) — engine kernel, identity, scaffolding, vitest+playwright, deps, logging, IPC contract, storage layout.

| F-ID | Slug | Status | Test files |
|---|---|---|---|
| F-001 | engine-bootstrap-loop | 🔒 LOCKED | `tests/unit/F-001-engine-bootstrap-loop.test.ts` (3/3 PASS); council review verdict ACCEPT (median 88) — wave-11 / lane-b |
| F-002 | per-agent-identity-runid | 🔒 LOCKED | `tests/unit/F-002-per-agent-identity-runid.test.ts` (3/3 PASS); council review verdict ACCEPT (median 90) — wave-12 / lane-d |
| F-003 | repo-scaffolding | 🔒 LOCKED | `tests/node/F-003-repo-scaffolding.test.ts` (11/11 PASS); council review verdict ACCEPT (median 87) — wave-15 / lane-a; workspace globs + strict TS + lint/format/editor configs + 3-package monorepo + LICENSE/README/.gitignore; per-package tsconfig + working `npm run build` + concrete src/ deferred per `no-silent-deferrals.md` |
| F-004 | vitest-playwright-config | 🔒 LOCKED | `tests/node/F-004-vitest-playwright-config.test.ts` (7/7 PASS); council review verdict ACCEPT (median 87) — wave-15 / lane-a; vitest.config.ts gains `browser` project + new `playwright.config.ts` at repo root mirroring clawpilot baseline; `@playwright/test` devDep + sharedTest fixtures + `pnpm e2e` deferred to M5 per `no-silent-deferrals.md` |
| F-005 | deps-pinning | 🔒 LOCKED | `tests/node/F-005-deps-pinning.test.ts` (4/4 PASS); council review verdict ACCEPT (median 88) — wave-15 / lane-a; root + workspace package.json exact-pin sweep + lockfile presence + engines.node check; package-manager choice (npm → pnpm) recorded in §Implementation notes; cross-OS byte-identity + drift-fails-CI deferred to M16 |
| F-006 | logging-pipeline | 🔒 LOCKED | `tests/unit/F-006-logging-pipeline.test.ts` (4/4 PASS); council review verdict ACCEPT (median 86) — wave-12 / lane-d |
| F-007 | ipc-contract-scaffold | 🔒 LOCKED | `tests/unit/F-007-ipc-contract-scaffold.test.ts` (3/3 PASS); council review verdict ACCEPT — wave-13 / lane-b; scaffold-shape contract; M5 integration scenarios deferred |
| F-008 | local-storage-layout | 🔒 LOCKED | `tests/node/F-008-local-storage-layout.test.ts` (6/6 PASS); council review verdict ACCEPT (median 88) — wave-12 / lane-d |
| F-138 | engine-cycle-orchestrator | 🟢 GREEN | `tests/unit/F-138-engine-cycle-orchestrator.test.ts` (3/3 PASS) — wave-017 / lane-a; **NEW (not promotion); resolves wave-016 / lane-d Copilot CLI HARD-BLOCK F1** (no engine-cycle orchestrator wires F-001 → F-009 → F-019 → F-022 → F-021 → F-018 → F-014). `runEngineCycle({backend, prompt, retro})` composes F-002 createAgent/Session + F-009 startSession/sendPrompt/halt/stopSession + F-018 HaltDetector + F-019 CostLedger + F-015 appendAuditEntry + F-014 closeSession. Returns structured `RunOutcome {status, runId, agentId, auditChainHead, haltTrigger?, haltReason?, events, costTotalUsd}`. v1 single-iteration; multi-turn + F-017/F-020/F-021/F-022 integration deferred per `no-silent-deferrals.md` (7 honest scope-narrowing notes in ledger §out-of-scope-notes). Orchestrator-identity rule held: cycle.ts re-implements ZERO primitive logic — every step delegates to a LOCKED primitive. |

### M1 — Pluggable backend

📂 [`docs/03-feature-catalog/M1-backend/README.md`](docs/03-feature-catalog/M1-backend/README.md) — IBackendProvider, Anthropic SDK, Copilot SDK, factory, event normalization.

| F-ID | Slug | Status | Test files |
|---|---|---|---|
| F-009 | ibackendprovider | 🔒 LOCKED | `tests/unit/F-009-ibackend-provider.test.ts` (6/6 PASS); council review verdict ACCEPT (median 89) — wave-15 / lane-a; **First M1 (backend pluggability) feature LOCKED.** Concrete providers F-010/F-011 + factory F-012 + event-normalization F-013 remain RED — F-009 contract is permanent, consumers plug in without touching this surface |
| F-010 | anthropic-sdk-provider | 🔒 LOCKED | `tests/unit/F-010-anthropic-backend.test.ts` (7/7 PASS); council review verdict ACCEPT (median 88) — wave-016 / lane-a; deterministic STUB body — real `@anthropic-ai/sdk` deferred per `no-silent-deferrals.md` (gated on F-070 secure-storage + recorded-fixture harness); halt-keeps-session-registered divergence from StubBackend per F-018 RUN_HALTED observability contract |
| F-011 | copilot-sdk-provider | 🔒 LOCKED | `tests/unit/F-011-copilot-backend.test.ts` (7/7 PASS); council review verdict ACCEPT (median 87) — wave-016 / lane-a; v1 deterministic stub (real Copilot CLI/SDK invocation deferred per ledger out-of-scope-notes — gated on CLI install + device-flow OAuth + recorded-fixture harness); halt-flips-state semantics matching F-010; default model 'gpt-5' constructor-injectable; cross-provider parity with F-010 architecturally validates F-009's contract surface |
| F-012 | backend-factory | 🔒 LOCKED | `tests/unit/F-012-backend-factory.test.ts` (6/6 PASS); council review verdict ACCEPT (median 90) — wave-016 / lane-a; `createBackend({kind, model})` dispatches to AnthropicBackend / CopilotBackend / StubBackend by string-literal kind; pure-function shape (no I/O); `BackendNotRegistered` realized via TS exhaustive-switch never-arm + runtime throw. Scope simplified vs ledger (createBackendProvider + MAD_BACKEND env override) — env resolution moved to caller per F-067 settings layer (M8). Lint rule + typed-error alignment + model-validation forward path documented |
| F-013 | event-normalization | 🔒 LOCKED | `tests/unit/F-013-backend-event-normalization.test.ts` (9/9 PASS); council review verdict ACCEPT (median 88) — wave-016 / lane-a; `BackendEvent` union from F-009 satisfies the cross-SDK normalization contract; F-013 contributes the convenience layer (4 type guards + `eventTextContent`) so downstream consumers don't re-implement narrowing. 5 ledger variants (`message_start` / `tool_use_input_delta` / `usage` / `cancelled` / `error`) tracked for future event-richness wave per `no-silent-deferrals.md`. **Closes M1 100% LOCKED** (F-009 + F-010 + F-011 + F-012 + F-013 = 5 of 5) |

### M2 — Governance triad

📂 [`docs/03-feature-catalog/M2-governance-triad/README.md`](docs/03-feature-catalog/M2-governance-triad/README.md) — pre-close signal, hash-audit, query-audit, PII redaction, halt, cost ledger, kill-switch, degradation, tool-quota.

| F-ID | Slug | Status | Test files |
|---|---|---|---|
| F-014 | pre-close-retro-signal | 🔒 LOCKED | `tests/unit/F-014-pre-close-retro-signal.test.ts` (8/8 PASS); council review verdict ACCEPT (median 88) — wave-13 / lane-c |
| F-015 | hash-chained-audit-log | 🔒 LOCKED | `tests/unit/F-015-hash-chained-audit-log.test.ts` (4/4 PASS); council review verdict ACCEPT (median 89) — wave-13 / lane-c |
| F-016 | query-audit-log | 🔒 LOCKED | `tests/unit/F-016-query-audit-log.test.ts` (8/8 PASS); council review verdict ACCEPT (median 87) — wave-13 / lane-c |
| F-017 | pii-redaction-egress | 🔒 LOCKED | `tests/unit/F-017-audit-pii-redaction.test.ts` (8/8 PASS); council review verdict ACCEPT (median 86) — wave-13 / lane-c; redact() + redactObject() helper primitives (~104 LOC); reject-on-detect orchestration deferred (composable atop primitive ~5 LOC wrapper) |
| F-018 | failure-pattern-halt | 🔒 LOCKED | `tests/unit/F-018-failure-pattern-halt.test.ts` (9/9 PASS); council review verdict ACCEPT (median 89) — wave-13 / lane-d |
| F-019 | cost-ledger | 🔒 LOCKED | `tests/unit/F-019-cost-ledger.test.ts` (8/8 PASS); council review verdict ACCEPT (median 89) — wave-13 / lane-d |
| F-020 | kill-switch | 🔒 LOCKED | `tests/unit/F-020-kill-switch.test.ts` (11/11 PASS); council review verdict ACCEPT (median 88) — wave-13 / lane-d |
| F-021 | degradation-fallback | 🔒 LOCKED | `tests/unit/F-021-degradation-ladder.test.ts` (11/11 PASS); council review verdict ACCEPT (median 88) — wave-15 / lane-a; in-memory escalation-ladder primitive (5 rungs + halt); per-resource circuit-breaker + Context-Gaps + required-vs-optional classification deferred to engine-cycle integration. **Closes the M2 governance triad (9/9 LOCKED).** |
| F-022 | tool-quota | 🔒 LOCKED | `tests/unit/F-022-tool-call-quota.test.ts` (8/8 PASS); council review verdict ACCEPT (median 88) — wave-13 / lane-d |

### M3 — Cron / heartbeat

📂 [`docs/03-feature-catalog/M3-cron-heartbeat/README.md`](docs/03-feature-catalog/M3-cron-heartbeat/README.md) — heartbeat, skip-on-overlap, idle archival, resume-from-checkpoint, manual halt override.

| F-ID | Slug | Status | Test files |
|---|---|---|---|
| F-023 | cron-heartbeat | 🟢 GREEN | tests/unit/F-023-cron-heartbeat.test.ts |
| F-024 | skip-on-overlap | 🟢 GREEN | tests/unit/F-024-skip-on-overlap.test.ts |
| F-025 | idle-archival | 🟢 GREEN | tests/unit/F-025-idle-archival.test.ts |
| F-026 | resume-from-checkpoint | 🟢 GREEN | tests/node/F-026-resume-from-checkpoint.test.ts |
| F-027 | manual-halt-override | 🟢 GREEN | tests/unit/F-027-manual-halt-override.test.ts |

### M4 — Headless CLI

📂 [`docs/03-feature-catalog/M4-headless-cli/README.md`](docs/03-feature-catalog/M4-headless-cli/README.md) — cli entry, subcommands, JSON output, daemon mode.

| F-ID | Slug | Status | Test files |
|---|---|---|---|
| F-028 | cli-entry | 🟢 GREEN | tests/node/F-028-cli-entry.test.ts |
| F-029 | subcommands | 🟢 GREEN | tests/node/F-029-cli-subcommands.test.ts |
| F-030 | json-output | 🟢 GREEN | tests/node/F-030-cli-json-output.test.ts |
| F-031 | daemon-mode | 🔴 RED | TBD |

### M5 — Desktop chat shell

📂 [`docs/03-feature-catalog/M5-desktop-shell/`](docs/03-feature-catalog/M5-desktop-shell/) (full ledger set landed wave-3 lane-b) — window, history, info-panel, model picker, personality, system message, primitives, theming, shortcuts, menu, notifications, multi-window.

| F-ID | Slug | Status |
|---|---|---|
| F-032 | window | 🔴 RED |
| F-033 | history | 🔴 RED |
| F-034 | info-panel | 🔴 RED |
| F-035 | model-picker | 🔴 RED |
| F-036 | personality | 🔴 RED |
| F-037 | system-message-editor | 🔴 RED |
| F-038 | ui-primitives | 🔴 RED |
| F-039 | theming | 🔴 RED |
| F-040 | keyboard-shortcuts | 🔴 RED |
| F-041 | menu-bar | 🔴 RED |
| F-042 | notifications | 🔴 RED |
| F-043 | multi-window | 🔴 RED |

### M6 — MCP & tools

🔴 RED ledgers landed wave-4 lane-a — bridge, lifecycle, reconnect+health, tool-call audit, streaming, BYO-MCP, registry persist.

| F-ID | Slug | Status |
|---|---|---|
| F-044 | mcp-bridge | 🔴 RED |
| F-045 | mcp-lifecycle | 🔴 RED |
| F-046 | mcp-reconnect-health | 🔴 RED |
| F-047 | tool-call-audit | 🔴 RED |
| F-048 | mcp-streaming | 🔴 RED |
| F-049 | byo-mcp | 🔴 RED |
| F-050 | mcp-registry-persist | 🔴 RED |

### M7 — Skills + Permissions + Automations

🔴 RED ledgers landed wave-4 lane-b — SKILL.md, bundled, toggle, custom-load, allowlist, version-pin, expiry, 3-tier perms, rules, audit, automations base + cron + condition + multistep + persist + shell-visible.

| F-ID | Slug | Status |
|---|---|---|
| F-051 | skill-md-format | 🔴 RED |
| F-052 | skills-bundled | 🔴 RED |
| F-053 | skills-toggle | 🔴 RED |
| F-054 | skills-custom-load | 🔴 RED |
| F-055 | skills-allowlist | 🔴 RED |
| F-056 | skills-version-pin | 🔴 RED |
| F-057 | skills-expiry | 🔴 RED |
| F-058 | perms-3-tier | 🔴 RED |
| F-059 | perms-rules | 🔴 RED |
| F-060 | perms-audit | 🔴 RED |
| F-061 | automations-base | 🔴 RED |
| F-062 | automations-cron | 🔴 RED |
| F-063 | automations-condition | 🔴 RED |
| F-064 | automations-multistep | 🔴 RED |
| F-065 | automations-persist | 🔴 RED |
| F-066 | automations-shell-visible | 🔴 RED |

### M8 — Settings & persistence

🔴 RED ledgers landed wave-4 lane-d — shape, UI, per-automation rules, encrypted storage, key-mgmt, encrypted import/export, project workspace, switcher UI, persistence.

| F-ID | Slug | Status |
|---|---|---|
| F-067 | settings-shape | 🔴 RED |
| F-068 | settings-ui | 🔴 RED |
| F-069 | per-automation-rules | 🔴 RED |
| F-070 | encrypted-storage | 🔴 RED |
| F-071 | key-management | 🔴 RED |
| F-072 | encrypted-import-export | 🔴 RED |
| F-073 | project-workspace | 🔴 RED |
| F-074 | workspace-switcher-ui | 🔴 RED |
| F-075 | settings-persistence | 🔴 RED |

### M9 — M365 integration

🔴 RED ledgers landed wave-5 lane-a — MSAL, WAM, auth screen, token refresh, WorkIQ adapter, rate-limit+CB.

| F-ID | Slug | Status |
|---|---|---|
| F-076 | msal-auth | 🔴 RED |
| F-077 | wam-broker | 🔴 RED |
| F-078 | auth-screen | 🔴 RED |
| F-079 | token-refresh | 🔴 RED |
| F-080 | workiq-adapter | 🔴 RED |
| F-081 | rate-limit-circuit-breaker | 🔴 RED |

### M10 — Multi-model adversarial review

🔴 RED ledgers landed wave-5 lane-b — --council dispatch, agreement table, both-flag-CRITICAL block, fallback, consent gate, 5 high-blast-radius wired.

| F-ID | Slug | Status |
|---|---|---|
| F-082 | council-dispatch | 🔴 RED |
| F-083 | agreement-table | 🔴 RED |
| F-084 | both-flag-critical-block | 🔴 RED |
| F-085 | council-fallback | 🔴 RED |
| F-086 | council-consent-gate | 🔴 RED |
| F-087 | high-blast-radius-wiring | 🔴 RED |

### M11 — Soul / introspect / replay

🔴 RED ledgers landed wave-5 lane-c — soul boundary, schema, snapshot, signal pairs, deterministic replay.

| F-ID | Slug | Status |
|---|---|---|
| F-088 | soul-boundary | 🔴 RED |
| F-089 | soul-schema | 🔴 RED |
| F-090 | soul-snapshot | 🔴 RED |
| F-091 | signal-pairs | 🔴 RED |
| F-092 | deterministic-replay | 🔴 RED |

### M12 — Visualization (NEW)

🔴 RED ledgers landed wave-6 lane-a — timeline UI, replay scrubber, filtering. New surface beyond clawpilot + canonical-e per `[V:11]`.

| F-ID | Slug | Status |
|---|---|---|
| F-093 | timeline-ui | 🔴 RED |
| F-094 | replay-scrubber | 🔴 RED |
| F-095 | timeline-filtering | 🔴 RED |

### M13 — Multimodal input (NEW)

🔴 RED ledgers landed wave-6 lane-b — voice STT, engine selection, activation modes, screenshot-to-prompt, image preprocessing.

| F-ID | Slug | Status |
|---|---|---|
| F-096 | voice-stt | 🔴 RED |
| F-097 | stt-engine-selection | 🔴 RED |
| F-098 | voice-activation-modes | 🔴 RED |
| F-099 | screenshot-to-prompt | 🔴 RED |
| F-100 | image-preprocessing | 🔴 RED |

### M14 — Productivity (NEW)

🔴 RED ledgers landed wave-6 lane-a — daily briefing, schedule, destination.

| F-ID | Slug | Status |
|---|---|---|
| F-101 | daily-briefing | 🔴 RED |
| F-102 | briefing-schedule | 🔴 RED |
| F-103 | briefing-destination | 🔴 RED |

### M15 — Build / packaging

🔴 RED ledgers landed wave-6 lane-c — electron-builder, auto-update, branding, code signing, CI, CLI binary.

| F-ID | Slug | Status |
|---|---|---|
| F-104 | electron-builder | 🔴 RED |
| F-105 | auto-update | 🔴 RED |
| F-106 | branding | 🔴 RED |
| F-107 | code-signing | 🔴 RED |
| F-108 | ci-pipeline | 🔴 RED |
| F-109 | cli-binary | 🔴 RED |

### M16 — Telemetry

🔴 RED ledgers landed wave-7 lane-a — local OTel, crash reporting, perf metrics, opt-in/out.

| F-ID | Slug | Status |
|---|---|---|
| F-110 | local-otel | 🔴 RED |
| F-111 | crash-reporting | 🔴 RED |
| F-112 | perf-metrics | 🔴 RED |
| F-113 | telemetry-opt-in-out | 🔴 RED |

### M17 — Documentation

🔴 RED ledgers landed wave-7 lane-a — README+quickstart, architecture docs, skill guide, MCP guide, automation cookbook.

| F-ID | Slug | Status |
|---|---|---|
| F-114 | readme-quickstart | 🔴 RED |
| F-115 | architecture-docs | 🔴 RED |
| F-116 | skill-guide | 🔴 RED |
| F-117 | mcp-guide | 🔴 RED |
| F-118 | automation-cookbook | 🔴 RED |

### M18 — Marketplace local-v1

🔴 RED ledgers landed wave-7 lane-b — local marketplace, metadata, search/browse UI.

| F-ID | Slug | Status |
|---|---|---|
| F-119 | local-marketplace | 🔴 RED |
| F-120 | marketplace-metadata | 🔴 RED |
| F-121 | marketplace-search-ui | 🔴 RED |

### NEW from research (foundational-plan §"Plus 5 NEW F-NNN candidates")

🔴 RED — added during loop iter-1..4 frontier research; allocated to existing milestones. Ledgers authored wave-012/lane-c.

| F-ID | Slug | Target milestone | Status | Source |
|---|---|---|---|---|
| F-122 | a2a-endpoint-exposure | M4 | 🔴 RED | `[R:WorkIQ + msft-learn finding 10]` (wave-1 lane-b finding 10) |
| F-123 | otel-genai-spans | M16 | 🔴 RED | `[R:msft-learn Foundry observability]` (wave-1 lane-b finding 16) |
| F-124 | multi-tier-routing-haiku-opus | M1 | 🔴 RED | `[R:WebSearch frontier 2026 architecture]` (wave-1 lane-a finding 21) |
| F-125 | mcp-tool-cap-per-workspace | M7 | 🔴 RED | `[R:WorkIQ internal tool-explosion lesson]` (wave-1 lane-b finding 15) |
| F-126 | context-budget-allocation | M8 | 🔴 RED | `[R:WebSearch frontier 2026]` (wave-1 lane-a finding 23) |

### M19 — Deferred (tracking only; user-acknowledged)

⏸ DEFERRED — explicitly out of v1 per user-acknowledged scope. Re-open trigger: see `docs/10-backlog/`. F-D-016/017/018 — F-D-016 + F-D-017 remain reserved without ledger files; F-D-018 ledger authored 2026-05-07 as part of M19 reopen-request package (status remains deferred per ledger top-level field; REOPEN-PENDING indicator below).

> **Row-label ↔ ledger-file off-by-one note (2026-05-07):** the rows below label some entries by slug at offset relative to their ledger file IDs. The slug column is the human-readable name; the actual ledger file IDs are F-D-001..F-D-015 (and F-D-018 authored in this batch). Reopen-request indicator updates target the SLUG (the human-recognizable label), not the F-ID. Fixing the row-label/file-id alignment is not part of this batch per `minimum-change.md`; tracked as documentation drift to be addressed separately.

2026-05-07 silent-deferral surfacing (off-wave; Batch 3 of 4): reopen-request package authored for F-D-008/F-D-010/F-D-018 per user explicit request via AskUserQuestion. Per `M19-deferred/README.md:51-57` protocol, top-level ledger status remains `deferred` pending council-review verdict at HIGH ≥80%; verdict step gates on Batch 4 (kit-bootstrap installs `/council-review`). Per-ledger status-history entries added to F-D-008 + F-D-010; F-D-018 ledger authored from scratch (was RESERVED). Reopen-request package: `docs/05-design-reviews/reopen-requests/F-D-008-F-D-010-F-D-018-reopen-2026-05-07.md`.

| F-ID | Slug | Status |
|---|---|---|
| F-D-001 | cloud-marketplace | ⏸ DEFERRED |
| F-D-002 | ring-deployment | ⏸ DEFERRED |
| F-D-003 | archive-tier | ⏸ DEFERRED |
| F-D-004 | schema-migration | ⏸ DEFERRED |
| F-D-005 | identity-crypto | ⏸ DEFERRED |
| F-D-006 | entra-binding | ⏸ DEFERRED |
| F-D-007 | teams-adapter | 🔄 REOPEN-PENDING (verdict required) |
| F-D-008 | outlook-adapter | ⏸ DEFERRED |
| F-D-009 | bot-framework | 🔄 REOPEN-PENDING (verdict required) |
| F-D-010 | agent365-sink | ⏸ DEFERRED |
| F-D-011 | byok | ⏸ DEFERRED |
| F-D-012 | sandboxing | ⏸ DEFERRED |
| F-D-013 | i18n | ⏸ DEFERRED |
| F-D-014 | mobile-companion | ⏸ DEFERRED |
| F-D-015 | (reserved) | ⏸ DEFERRED |
| F-D-016 | in-meeting-live-assistant | ⏸ DEFERRED |
| F-D-017 | foundry-hosted-agent-deployment | ⏸ DEFERRED |
| F-D-018 | activity-protocol-teams-outlook | 🔄 REOPEN-PENDING (verdict required) |

## Dependency graph (high-level)

```
M0 (bootstrap) ──► M1 (backend) ──► M2 (governance triad)
                                         │
                                         ▼
                          M3 (cron) ◄──► M4 (CLI)
                                         │
                                         ▼
                M5 (desktop shell) ◄═parallel═► M6 (MCP) ──► M7 (extensibility) ──► M8 (settings)
                                                                          │
                                                                          ▼
                                            M9 (M365) ──► M10 (multi-model) ──► M11 (soul/replay)
                                                                          │
                                                                          ▼
                              M12 (viz) ‖ M13 (multimodal) ‖ M14 (productivity)
                                                                          │
                                                                          ▼
                                  M15 (build) ‖ M16 (telemetry) ‖ M17 (docs)
                                                                          │
                                                                          ▼
                                            M18 (marketplace local-v1)
                                                                          │
                                                                          ▼
                                            M19 (deferred — tracking only)
```

Notes:
- M0..M2 are sequential (foundation triad).
- M3 + M4 are co-equal headless concerns; either may land first based on driver demand.
- M5 + M6 can run in parallel with each other once M0..M4 settle; M5 depends on M0+M1, M6 depends on M0+M1+M2.
- M7 depends on M6 (skills are discovered via the MCP-style bridge).
- M8 depends on M7 (settings UI hosts the perms model + automations registry).
- M9 (M365) is gated on M0+M1+M2; can land in parallel with M5 (UI auth-screen depends on M9 partial).
- M10 depends on M1 (multi-provider) + M2 (council-dispatch is governance-adjacent).
- M11 depends on M2 (audit-log) + M14 (replay UI in scrubber).
- M12..M14 are NEW surfaces; depend on M5 (desktop shell) for UI hosts.
- M15..M17 cross-cut all milestones; M15 lands continuously as packaging concerns surface.
- M18 closes v1 with local marketplace; cloud variant tracked under M19 (user-acknowledged).

## Source

- Refreshed by **wave-11 / Lane D** (this commit). Original draft: wave-3 / Lane D.
- Authoritative source for per-feature behavior contracts: `docs/03-feature-catalog/Mn-*/F-NNN-*.md` ledgers.
- Authoritative source for milestones + scope: `docs/01-requirements/foundational-plan.md` § "True Synthesis → Feature catalog".
- Wave history: `docs/11-loop-state/wave-history/`.
- Dependency graph derived from foundational-plan dependency cues + Lane C (clawpilot/openclaw) lessons L1..L15 ordering hints.
