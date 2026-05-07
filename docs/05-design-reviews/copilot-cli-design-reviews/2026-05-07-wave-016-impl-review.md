---
artifact-class: design-review
review-type: copilot-cli-multi-model
date: 2026-05-07
wave: wave-016 / lane-d
inputs:
  - packages/engine-core/src/*.ts (18 source files, ~2660 LOC)
  - common/ipc-contract.ts
  - tests/unit/F-001..F-022 (~18 unit test files)
  - tests/node/F-003..F-008 (~4 node test files)
  - docs/03-feature-catalog/M0-bootstrap, M1-backend, M2-governance-triad
  - docs/05-design-reviews/copilot-cli-design-reviews/2026-05-07-wave-001-foundation-review.md
models-dispatched:
  - claude-opus-4.7 — completed in ~4 min, ~180KB raw output, 2.1M input + 64.8k output tokens (1.6M cached)
  - gpt-5.5 — completed in ~1 min, ~65KB raw output
brief: .mad/scratch/wave-016-impl-review-brief.md
dispatcher-output: .mad/scratch/wave-016-impl-review-output/
opus-result: .mad/scratch/wave-016-impl-review-output/opus-result.json
gpt-result: .mad/scratch/wave-016-impl-review-output/gpt-result.json
---

# Wave-016 Lane D — M0+M1+M2 implementation design review

## Review path taken

**Multi-model dispatch via `Invoke-CopilotMultiModel.ps1` at TimeoutSeconds=1200.** Both `claude-opus-4.7` (~4 min, 180KB output) and `gpt-5.5` (~1 min, 65KB output) returned complete structured reviews. Both dispatched in parallel. Cross-model agreement table populated per `lens-multi-model-review-pattern.md`.

**Both-flag-CRITICAL hard-block rule active.** Findings flagged Critical by BOTH models are HARD BLOCKs on M3 entry. Findings flagged Critical by only one model are SHOULD-FIX (single-model signal weaker per pattern doc).

This is the FIRST implementation-review since wave-002's catalog-only foundation review. 18 LOCKED features (F-001..F-022 minus a few infrastructure-only) are now implemented.

## Cross-model agreement table

| # | Finding (canonical phrasing) | claude-opus-4.7 | gpt-5.5 | Decision |
|---|---|---|---|---|
| **F1** | **No engine-cycle orchestrator wires F-001 → F-009 → F-019 → F-022 → F-021 → F-018 → F-014.** `bootstrap()` makes zero backend/governance calls; 18 primitives have no composition layer. | **C-1 (Critical)** | **Major: "Cycle orchestration is not wired through the governance/backends stack"** | **HARD BLOCK** (severity escalates to Critical via Opus; gpt-5.5 confirms gap). Promote **F-138 engine-cycle-orchestrator** as M3 pre-impl prerequisite. |
| **F2** | **F-013 did NOT resolve wave-002 HARD BLOCK F2 (IBackendProvider over-normalization).** F-013 is 4 type-guards + a content extractor; IBackendProvider stays a single 4-method interface (no IChat/IToolDispatch/IIdentity split). | **M-1 (Major)** | **Major: "F-013 does not split normalization into separate event domains; it is only type guards + a formatter… papers over normalization rather than decomposing"** | **MUST-FIX** — both flag. Document as conscious deviation OR revisit when real SDK integration lands. Add `rawEvent?: unknown` to BackendEvent so original provider event is preserved. |
| **F3** | **Halt surface is broadly shared and HaltTrigger union has expanded beyond F-018 auto-halt set into cross-feature sentinels (`manual`, `iteration_cap`, `tool_calls_quota`, `tool_calls`, `degrade_escalate`).** halt.ts is 269 LOC — biggest file. Indicates de-facto shared kernel, not a narrow failure-pattern feature. | **(implicit P-1: "halt.ts is the convergence hub: 6 files import RunHaltedVerdict")** treats as praise (clean DAG) | **Major: "high-coupling shared kernel, not a narrow failure-pattern feature"** | **MUST-FIX** (single-model major from gpt-5.5; Opus reframes as praise). Decision: gpt-5.5's framing wins — document halt.ts explicitly as the **governance-kernel verdict shape**, and consider extracting `RunHaltedVerdict` into a dedicated `verdict.ts` so halt.ts proper can shrink to F-018-only logic. Adjacent to F-127 foundation-governance-kernel. |
| **F4** | **`index.ts` barrel `export *` leaks public surface — no public API boundary.** ~50+ symbols flat-exported (input types, config types, classes, helpers). | **M-2 (Major)** | **Major: "Public API leakage via barrel export"** | **MUST-FIX** — both flag. Add explicit `public-api.ts` re-exporting only consumer-facing surface; keep `index.ts` for internal. Apply `@internal`/`@public` JSDoc tags. |
| **F5** | **Catalog/API mismatch: F-013 spec requires 9 normalized variants + provider-specific mapping; impl has 4-variant `BackendEvent` and moves normalization downstream.** Catalog drift. | **(captured via M-1)** | **Major: "F-013 acceptance criteria no longer match source"** | **MUST-FIX** — Opus folds into M-1; gpt-5.5 calls out as separate. Same root cause as F2. Decision: update catalog OR resync code; do not let drift persist. |
| **F6** | **Catalog/API mismatch: F-022 spec says quota rejects with `QUOTA_EXCEEDED:<name>`; source returns `RUN_HALTED` with trigger `tool_calls`; global trigger is `tool_calls_quota`.** | (not flagged independently) | **Major: "F-022 trigger name split vs source"** | **SHOULD-FIX** (single-model gpt-5.5). Spec/code drift; pick one canonical. Recommendation: align with source (F-022 emits `RunHaltedVerdict`), update F-022 spec text to match. |
| **F7** | **F-129..F-134 candidates from wave-002 are mostly not materialized in source.** Only promotion table exists; no .ts files; no helpers under `packages/`. | **(table in NEW F-NNN section confirms F-129/F-130/F-131/F-132/F-133/F-134 NOT implemented)** | **Major: "F-129..F-134 candidates are mostly not materialized"** | **MUST-FIX** — both flag. Tracking issue: each candidate needs an explicit milestone assignment + lock-status decision. F-130 tool-invocation-proof-gate is the most urgent (M3 pre-req per wave-002 F3). |
| **F8** | **BackendEvent lacks `usage` variant — cost ledger has no event source.** F-019 expects token counts but `sendPrompt` only yields `token`/`tool_call`/`tool_result`/`finish` — no usage data. F-013 comment explicitly defers `usage` to future. | **C-2 (Critical)** | (not flagged independently) | **MUST-FIX** (single-model Opus Critical; demoted under cross-model rule but reasoning is concrete). Promote **F-139 backend-event-usage-variant** (M3 pre-impl). Without this, F-131 fanout-budget-governor cannot be built. |
| **F9** | **StubBackend halt semantics contradict AnthropicBackend / CopilotBackend.** StubBackend deletes session on halt (post-halt sendPrompt throws); Anthropic/Copilot keep session + add to halted set (yield `finish/error`). F-009 test scenario 5 asserts the wrong contract. | **C-3 (Critical)** | (not flagged independently) | **MUST-FIX** (single-model Opus Critical; demoted under cross-model rule but is a real contract bug). Align StubBackend with concrete backends; update F-009 test. Risk: downstream halt-integration tests will encode the wrong contract. |
| **F10** | **CostLedger.getEntries() and DegradationLadder.getState() return live mutable references.** `readonly` typing is type-level only; mutating individual entries silently corrupts aggregation. | **M-3, M-4 (Major)** | (not flagged independently) | **SHOULD-FIX** (single-model Opus). Return shallow copies. Cheap fix. |
| **F11** | **F-001 bootstrap exception path is dead code — scenario 3 test never exercises it.** `bootstrap()` has no exception injection seam; `terminatedBy: 'exception'` union member is never produced. | **M-5 (Major)** | (implicit; not separately flagged) | **SHOULD-FIX** — Opus only. Defer to F-138 engine-cycle-orchestrator where real exceptions can occur. |
| **F12** | **F-007 IPC contract is empty scaffold (`IpcInvokeMap = {}`) at repo-root `common/`, not under engine-core.** Will accumulate staleness until M5. | **M-6 (Major)** | **Minor: "ipc-contract scaffold is not dead code, but it is only validated as a contract stub"** | **SHOULD-FIX** — both flag (severity diverges; take the higher = Major). Document `common/` as cross-package type-sharing location; lint-rule that `common/` exports types only (no runtime). |
| **F13** | **KillSwitch uses CJS `require()` inside ESM module.** Defeats tree-shaking, may break under strict ESM. ESLint already flags it. | **M-7 (Major)** | (not flagged) | **SHOULD-FIX** (single-model Opus). Replace with static top-level import + constructor injection (the `fileExistsFn` parameter is already in place; just wire the default to a static import). |
| **F14** | **heartbeat.ts (F-023, M3) is barrel-exported in M0-M2 engine-core/index.ts** — milestone boundary leak. | **M-8 (Major)** | (not flagged) | **CONSIDER** (single-model Opus). Accept as-is if M3 is the next milestone; document the early-landing in index.ts comment. |
| **F15** | **No concurrency tests for halt/cost/quota.** All tests strictly sequential — no `Promise.all`/`allSettled`/`race`/`parallel`/`worker` matches in source. F-019 cost-ledger especially: no concurrent writers/readers tested. | (test-gap matrix table confirms F-018/F-019/F-022 lack concurrent tests) | **Major: "No concurrent behavior coverage for halt/cost/quota; all tests are strictly sequential"** | **MUST-FIX** — both flag. Add concurrent-invocation tests to F-018, F-019, F-022 unit tests. Or document the single-thread assumption explicitly + emit a warning when the engine runs multi-agent. |
| **F16** | **No cross-feature integration test exercises the canonical flow:** backend → cost → quota → audit → redact → halt-check. `tests/integration/` is empty (`.gitkeep` only). | **(test-gap matrix table)** | **Major: "No cross-feature integration test exercises backend + cost + quota + audit + redaction + halt in one flow"** | **MUST-FIX** — both flag. Critical for downstream wiring confidence. Adjacent to F-138 (engine-cycle-orchestrator) which is the natural integration-test target. |
| **F17** | **F-021 degradation: failure-path coverage incomplete.** Tests cover normal escalation/recovery + terminal halt idempotency, NOT negative path around broken fallback resources or degraded-handoff failure. | (not flagged independently) | **Major: "Failure-path coverage is incomplete for degradation + kill-switch SIGTERM"** | **SHOULD-FIX** (single-model gpt-5.5). Add failure-path tests; F-020 SIGTERM/process-shutdown path test. |
| **F18** | **F-020 kill-switch test gap: covers env/file/idempotency/throw, but NOT SIGTERM/process-shutdown path.** | (not flagged) | **Major: same** | **SHOULD-FIX** (single-model gpt-5.5). |
| **F19** | **Lifecycle/API surface inconsistency.** backend exposes `startSession/sendPrompt/halt/stopSession`; audit/cost/storage have separate primitives with different shapes (`appendAuditEntry`, `CostLedger.append`, `atomicWriteJson`); no common `start/record/query/close` contract. | (related to C-1) | **Minor** | **CONSIDER** — both flag. Adjacent to F-138 — engine-cycle-orchestrator may obviate the need for a uniform contract by composing each in its native shape. |
| **F20** | **Persistence boundary asymmetric.** storage owns atomic JSON writes; audit/cost are in-memory mutators; cost explicitly says persistence is F-008's job without exposing a writer interface. No single cohesive persistence boundary for engine-core. | (not flagged independently; P-7 praises cost.ts NO-budget posture) | **Minor** | **CONSIDER** (single-model gpt-5.5). Document explicitly: M0-M2 features are in-memory; persistence wiring is an M3+ concern. Add a `persist()` interface to CostLedger + AuditLog that accepts a `StorageLayout`. |
| **F21** | **RetroOutcome lacks `halted_by_degradation`.** DegradationLadder emits halt with trigger `degrade_escalate` but no matching RetroOutcome value — degradation halts unreportable via `closeSession()`. | **m-1 (Minor)** | (not flagged) | **SHOULD-FIX** (single-model Opus). Trivial enum addition. Promote **F-140 retro-outcome-degradation**. |
| **F22** | **`AuditEntry` (bootstrap.ts) and `AuditLogEntry` (audit.ts) have similar names but unrelated shapes.** Both flat-exported from barrel; consumers may confuse. | **m-2 (Minor)** | (not flagged) | **CONSIDER** (single-model Opus). Rename bootstrap's `AuditEntry` → `BootstrapCycleEntry` for disambiguation. |
| **F23** | **No `trace` or `fatal` log levels.** F-006 ledger specifies 6 levels; impl has 4. | **m-4 (Minor)** | (not flagged) | **CONSIDER** (single-model Opus). Track as known gap; needed for M3 verbose protocol logging. |
| **F24** | **Hand-rolled UUID v7 implementation (identity.ts:66-89).** Security-adjacent; needs RFC 9562 conformance test. | **m-6 (Minor)** | (not flagged) | **SHOULD-FIX** (single-model Opus). Add a focused conformance test (version nibble = 0x7, variant bits = 0b10, timestamp monotonicity). |
| **F25** | **Redaction order matters but is not configurable.** `customPatterns` always run last; can't precede built-in patterns. | **m-3 (Minor)** | (not flagged) | **ACCEPT-AS-IS** for v1. Document the constraint in JSDoc. |
| **F26** | **`atomicWriteJson` does not handle cross-filesystem renames.** Edge case if `path` is a symlink to different mount. | **m-5 (Minor)** | (not flagged) | **ACCEPT-AS-IS**. `.tmp` is always co-located with target. |
| **P-1** | **RunHaltedVerdict shared across F-018/F-020/F-021/F-022 with `halt.ts` as first owner is excellent.** | **P-1 (Praise)** | **Praise: "Good first-owner/type-sharing discipline"** | **PRAISE** — both confirm. Continue this pattern in M3+. |
| **P-2** | **Type-only imports preserve DAG from runtime coupling.** Every cross-feature import uses `import type`. Tree-shaking eliminates unused features. | **P-2** | (implicit in DAG analysis) | **PRAISE**. Continue. |
| **P-3** | **Exhaustive-switch with `const _exhaustive: never = ...` in backend-factory + backend-events.** Gold standard for discriminated-union safety. | **P-3** | (not echoed) | single-model praise. |
| **P-4** | **Consistent FETCH-BEFORE-CITE + scope-deviation documentation in source comments.** Every file documents where it deviates from spec and why. | **P-4** | (not echoed) | single-model praise. |
| **P-5** | **Injectable test seams** (KillSwitch.fileExistsFn, createLogger.sink, storage.ts `_`-prefixed fs imports). Unit-testable without globals. | **P-5** | (not echoed) | single-model praise. |
| **P-6** | **Hash-chained audit (F-015) clean canonical-JSON serializer + SHA-256 chain + tamper detection + appendAuditEntry → verifyAuditChain → queryAuditLog → findChainBreak.** | **P-6** | (not echoed) | single-model praise. |
| **P-7** | **No-invented-constraints discipline on CostLedger** (cost.ts:122 explicitly documents the ABSENCE of `halt()`/`checkBudget()`/`overBudget()`). | **P-7** | (not echoed) | single-model praise. Consistent with `rules/no-invented-constraints.md`. |

**Summary count:**
- **HARD BLOCKs (both flag Critical, OR escalation by either):** 1 (F1)
- **MUST-FIXes (both flag Major):** 6 (F2, F4, F7, F15, F16, F12 if taking higher severity)
- **SHOULD-FIXes (single-model Major):** 8 (F3, F5, F6, F8, F9, F10, F11, F13, F17, F18)
- **CONSIDER:** 4 (F14, F19, F20, F22)
- **PRAISE:** 7 patterns to preserve
- **ACCEPT-AS-IS:** 2 (F25, F26)

## Findings by severity

### Critical (BLOCKING — cannot proceed to M3 until resolved)

**C-1 / F1 — No engine-cycle orchestrator wires the 18 primitives.**
Both models flag this as the central design gap. M0-M2 are 18 standalone features; nothing composes them. Bootstrap.ts runs an empty cycle loop with no backend, no governance, no event flow.

**Recommendation:** Promote **F-138 engine-cycle-orchestrator** as M3 pre-impl prerequisite. Define the canonical cycle: `startSession → [sendPrompt → observeEvent → recordCost → checkQuota → checkHalt → audit → redact]* → closeSession(retro)`. M3-M5 features will need to plug into this cycle; building them without it produces another round of orphan primitives.

### Major (MUST-FIX before M3 implementation begins)

**M-1 / F2** — F-013 did not resolve wave-002's IBackendProvider split. (Add `rawEvent?: unknown` to BackendEvent, OR document conscious deviation.)
**M-2 / F4** — Barrel `export *` leaks ~50+ symbols. (Add `public-api.ts` re-export.)
**M-3 / F8** — BackendEvent lacks `usage` variant. (Promote F-139.)
**M-4 / F15** — No concurrency tests for halt/cost/quota.
**M-5 / F16** — No cross-feature integration test. (`tests/integration/` is empty.)
**M-6 / F7** — F-129..F-134 wave-002 candidates not materialized. (Each needs explicit milestone assignment.)
**M-7 / F12** — F-007 IPC contract empty scaffold; document `common/` as cross-package shared types only.
**M-8 / F3** — HaltTrigger has expanded into a cross-feature kernel sentinel union. (Extract `RunHaltedVerdict` into `verdict.ts`; halt.ts shrinks to F-018 logic.)

### Minor (SHOULD-FIX / CONSIDER)

- **m-1 / F9** — StubBackend halt contract diverges from concrete backends; F-009 test asserts wrong contract.
- **m-2 / F10** — CostLedger.getEntries() and DegradationLadder.getState() return live mutable references.
- **m-3 / F11** — F-001 bootstrap exception path is dead code.
- **m-4 / F13** — KillSwitch CJS `require()` in ESM module.
- **m-5 / F14** — heartbeat.ts (F-023/M3) in M0-M2 barrel.
- **m-6 / F17, F18** — F-021 degradation failure-path tests + F-020 SIGTERM test missing.
- **m-7 / F19** — Lifecycle/API surface inconsistency (no uniform `start/record/query/close`).
- **m-8 / F20** — Persistence boundary asymmetric.
- **m-9 / F21** — RetroOutcome lacks `halted_by_degradation` (F-140 candidate).
- **m-10 / F22** — `AuditEntry` (bootstrap) and `AuditLogEntry` (audit) name collision.
- **m-11 / F23** — Logger missing `trace` + `fatal` levels.
- **m-12 / F24** — UUID v7 hand-rolled; needs RFC 9562 conformance test.
- **m-13 / F5, F6** — F-013 + F-022 catalog/code drift.

### Praise (PRAISE — preserve in M3+)

- **P-1** — RunHaltedVerdict first-owner shared-type pattern (both models).
- **P-2** — Type-only `import type` imports preserve DAG (Opus).
- **P-3** — Exhaustive-switch with `const _exhaustive: never` (Opus).
- **P-4** — FETCH-BEFORE-CITE + scope-deviation comments throughout (Opus).
- **P-5** — Injectable test seams (Opus).
- **P-6** — Hash-chained audit (F-015) clean implementation (Opus).
- **P-7** — No-invented-constraints discipline on CostLedger (Opus); consistent with `rules/no-invented-constraints.md`.

### NEW F-NNN candidates

| ID | Name | Scope | Target | Source |
|---|---|---|---|---|
| **F-138** | engine-cycle-orchestrator | Wire F-001 → F-009 → F-019 → F-022 → F-021 → F-018 → F-014 into a single cycle loop with event observation + governance checks | **M3 pre-impl** | Both models (Opus C-1, gpt-5.5 cycle gap) |
| **F-139** | backend-event-usage-variant | Add `usage` variant to BackendEvent; concrete backends MUST emit after `finish` | **M3 pre-impl** | Opus C-2 — prerequisite for F-131 |
| **F-140** | retro-outcome-degradation | Add `halted_by_degradation` to RetroOutcome | **M3** | Opus m-1 |
| **F-141** (new) | governance-kernel-extract | Extract RunHaltedVerdict + HaltTrigger into `verdict.ts`; halt.ts shrinks to F-018 logic | **M3** | gpt-5.5 F3 / Opus framing of halt.ts as TYPE HUB |
| **F-142** (new) | engine-core-public-api-boundary | Add `public-api.ts` barrel + `@internal`/`@public` JSDoc tags | **M3** | Both models (M-2 / F4) |

**Wave-002 HARD BLOCK resolution status (matrix):**

| Wave-002 verdict | M0-M2 status | Action |
|---|---|---|
| F1 governance-before-backend | ⚠️ Features exist; not wired | F-138 |
| F2 IBackendProvider split | ❌ F-013 is just type guards | M-1 / F2 above |
| F3 tool-proof-gate (F-130) | ❌ Not implemented | M3 milestone assignment |
| F5 identity-before-backend (F-128) | ✅ BackendSessionConfig requires Agent+Session | resolved at type level |
| F6 oauth-singleflight (F-129) | ❌ Not implemented | M6 milestone assignment |
| F7 fanout-budget (F-131) | ❌ Not implemented | needs F-139 first |
| F8 supervision-locks (F-132) | ❌ Not implemented | M3-M5 candidate |

### Loop-improvement proposals for wave-17+

1. **Mandate one integration test per milestone before milestone-freeze.** `tests/integration/` exists but is empty. Cross-feature flows (cost+quota+audit+redact+halt across one backend call) belong here.
2. **Add `BackendEvent` variant-stability CI gate.** A test that asserts the exact set of `type` discriminators forces variant additions/removals through review.
3. **Track wave-002 verdict resolution status in a machine-readable file** (e.g. `docs/05-design-reviews/wave-002-resolution-tracker.md`). The 7 HARD BLOCKs have varying resolution states; an auditable table prevents re-reading every source file each wave.
4. **Profile barrel export surface.** index.ts re-exports ~50+ symbols. When engine-core gains consumers (M5 desktop shell, M6 MCP), a usage profile reveals dead exports + contraction opportunities.
5. **Run multi-model design review every 5 waves (QG7 cadence).** Wave-001 (foundation) → wave-016 (M0-M2 impl) is a 14-wave gap. Wave 21 (~M3-M5 mid-impl) is the next natural slot.

## Anomalies

- **Opus output included full source-file dumps before findings** (3155 lines of preamble). The brief asked for findings; Opus chose to verify by reading + dumping every file first, then synthesizing. Net: the synthesis itself is excellent (lines 3155-3398). For wave-17+ briefs, consider explicitly forbidding "echo source back to me" preamble.
- **GPT output formatting was streaming-corrupted in places** (interleaved output between agent steps). Findings are extractable but require care; the substance is sound.
- **Wave-002 retry-with-1200s lesson held**: both models completed inside the 1200s budget (Opus ~4 min, gpt-5.5 ~1 min). No timeout retry needed.
- **Index.ts was modified during the dispatch** (heartbeat.ts entry added at line 27 + 51) — F-023 was added to the barrel mid-review. This is reflected in F14 finding (M3 boundary leak).
