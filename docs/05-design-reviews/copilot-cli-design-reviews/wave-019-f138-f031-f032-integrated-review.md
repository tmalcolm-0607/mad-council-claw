---
artifact-class: design-review
review-type: copilot-cli-multi-model
date: 2026-05-07
wave: wave-019 / lane-d
cadence: every-5-waves QG7 (wave-001 foundation -> wave-016 M0+M1+M2 impl -> wave-019 spine integrated)
inputs:
  - packages/engine-core/src/cycle.ts (F-138, 278 LOC)
  - packages/cli/src/daemon.ts (F-031, 226 LOC)
  - packages/desktop-shell/src/window.ts (F-032, 206 LOC)
  - tests/unit/F-138-engine-cycle-orchestrator.test.ts (3 scenarios)
  - tests/node/F-031-daemon-mode.test.ts (5 scenarios)
  - tests/unit/F-032-window.test.ts (6 scenarios)
  - common/ipc-contract.ts (F-007 scaffold)
  - docs/03-feature-catalog/M0-bootstrap/F-138-engine-cycle-orchestrator.md
  - docs/03-feature-catalog/M4-headless-cli/F-031-daemon-mode.md
  - docs/03-feature-catalog/M5-desktop-shell/F-032-window.md
  - docs/05-design-reviews/copilot-cli-design-reviews/2026-05-07-wave-016-impl-review.md
models-dispatched:
  - claude-opus-4.7 -- ~10m 57s; 12.6 KB raw output (494-line structured md persisted to .mad/scratch/wave-019-design-review-output/opus-result.md); ~1.4M input + 31.0k output tokens (~1.3M cached)
  - gpt-5.5 -- ~5m 28s; 27.5 KB raw output; ~1.8M input + 17.6k output tokens (~1.6M cached) + 8.8k reasoning
brief: .mad/scratch/wave-019-design-review-brief.md
dispatcher-output: .mad/scratch/wave-019-design-review-output/
opus-result: .mad/scratch/wave-019-design-review-output/opus-result.json (+ opus-result.md sidecar)
gpt-result: .mad/scratch/wave-019-design-review-output/gpt-result.json (+ gpt-result.md sidecar)
dispatcher-mode: CopilotCLI
---

# Wave-019 Lane D -- F-138 + F-031 + F-032 integrated spine review

## Review path taken

**Multi-model dispatch via `Invoke-CopilotMultiModel.ps1` at TimeoutSeconds=1200.** Both `claude-opus-4.7` (~11 min, 494-line structured review at `.mad/scratch/wave-019-design-review-output/opus-result.md`) and `gpt-5.5` (~5.5 min, 27.5 KB inline review) returned complete reviews. Dispatched in parallel; dispatcher Mode = `CopilotCLI`. Cross-model agreement table populated per `lens-multi-model-review-pattern.md`.

**Both-flag-CRITICAL hard-block rule active.** ZERO findings flagged Critical by both models -- this review issues NO HARD BLOCKs against the spine. Both models converge on 0 Critical / multiple Majors. The composition spine wave-016 lane-d named as the M3 prerequisite is structurally sound; the Major findings are correctness gaps + idiom-drift + an Opus-detected JSDoc/code drift, none of which block M3 entry but ALL should be fixed before F-138 transitions to LOCKED.

This is the **third** Copilot CLI multi-model design review on the every-5-waves QG7 cadence: wave-001 foundation -> wave-016 M0+M1+M2 implementation -> wave-019 spine integrated. Next natural slot: wave-024 (~mid M3-M5 impl).

## Cross-model agreement table

| # | Finding (canonical phrasing) | claude-opus-4.7 | gpt-5.5 | Decision |
|---|---|---|---|---|
| **F1** | **F-138 normal-path event loop lacks try-finally around `backend.stopSession` + `closeSession`.** AsyncGenerator throw mid-stream leaks backend session and skips mandatory F-014 retro. | **Major (A-1)** | **Major: "F-138 does not guarantee backend cleanup when sendPrompt throws"** | **MUST-FIX** -- both flag. Wrap `cycle.ts:211-276` event-loop + post-loop cleanup in try-finally. Model on the manual-halt path (lines 178-207) which is linear and exception-safe by structure. **Pre-LOCKED for F-138.** |
| **F2** | **F-138 infinite-throwing handler in F-031 spins daemon CPU-hot with no exit.** No `maxConsecutiveErrors` guard; production-equivalent default `maxTicks = Infinity` + `tickIntervalMs = 0` permits 100% CPU on a perpetually-failing handler. | **Major (S-1)** | **Major: "F-031 can spin forever on an always-throwing handler"** | **MUST-FIX** -- both flag. Add `maxConsecutiveHandlerFailures?: number` to `DaemonOptions` (default 10). Track consecutive throws; reset on success; exit with `outcome: 'force_killed'` (reuse existing union variant) when exceeded. Mirrors `HaltDetector.maxConsecutiveFailures` pattern from F-018. **Pre-LOCKED for F-031.** |
| **F3** | **F-138 `costTotalUsd: number` cannot distinguish "zero cost" from "tracking unavailable."** In v1 it is always 0; consumers can misread missing telemetry as a true zero-cost run. | **Minor (S-5)** | **Major: "costTotalUsd: 0 conflates known zero with unknown"** | **MUST-FIX** -- both flag (severity diverges; take the higher = Major). Adopt either `costTotalUsd: number \| null` (null = "tracking not available for this run") OR add a companion `costStatus: 'known' \| 'unknown'` field. Resolves at F-139 wiring. |
| **F4** | **F-031 dual `runDaemon` invocation in same process has no in-process coordination.** No singleton guard; PID-file `DAEMON_ALREADY_RUNNING` is deferred to OS-process layer. | **Major (S-2)** | **Minor: "F-031 duplicate in-process daemon loops are not surfaced as caller-owned"** | **MUST-FIX** -- both flag (severity diverges; take the higher = Major). Add an in-process singleton guard (module-scoped `_running` flag with try-finally reset). Strict subset of the deferred PID-file check; cheap to implement. Alternative (gpt-5.5's minor framing): document caller-owned coordination explicitly in JSDoc + ledger. |
| **F5** | **F-138 BackendEvent `usage` variant exists (added wave-019/lane-b) but cycle.ts ignores it; JSDoc claims variant doesn't exist.** Stale `cycle.ts:89-92` JSDoc says "0 in v1 because BackendEvent has no `usage` variant per wave-016 D-36". | **Major (A-2)** | (not flagged independently) | **MUST-FIX** (single-model Opus Major; demoted under cross-model rule but the evidence is concrete code-vs-spec drift that gpt-5.5 missed because it didn't compare backend.ts:72-88 against cycle.ts JSDoc). Add `else if (event.type === 'usage')` branch in event loop; call `cost.append(...)`. Update stale JSDoc + ledger `out-of-scope-notes` item #6. If wiring is intentionally deferred to a later wave, change comment from "no variant" to "variant exists; wiring deferred to wave-NNN" so the scope note stays honest per `no-silent-deferrals.md`. |
| **F6** | **F-032 `windowsHide` cross-platform no-op semantics undocumented.** Field is set unconditionally (`window.ts:197`); macOS/Linux Electron silently ignores it; doc says "On Windows" only. | **Minor (A-4)** | **Minor: "F-032 windowsHide platform semantics need an explicit contract"** | **SHOULD-FIX** -- both flag. Append to JSDoc at `window.ts:109-113`: "No-op on macOS/Linux; set unconditionally for cross-platform descriptor portability per the `descriptor-as-data` idiom." OR move to a launcher-metadata section per gpt-5.5's framing. |
| **F7** | **F-032 `IpcInvokeChannel = keyof IpcInvokeMap = never` means test scenario 4 bypasses type contract.** Test passes string literals as `ReadonlyArray<never>`; compiles only because vitest transpiles without type-checking. | **Minor (S-3)** | **Major: "IPC extension path should be fixed before F-033+ channels land"** (with the separate observation that `IpcInvokeMap` is a `type` not `interface`) | **SHOULD-FIX** -- both flag (severity diverges; take the higher = Major). Two complementary actions: (a) Add `// @ts-expect-error -- IpcInvokeMap is empty` to the test's runtime-string passing site OR test with `ipcChannels: []` only; (b) per gpt-5.5: convert `IpcInvokeMap` from `type` to `interface` so consumer features can declaration-merge new channels without editing the central scaffold. Both fixes cost minutes; the asymmetry is currently aspirational vs enforced. |
| **F8** | **F-031 `runDaemon` uses `HeartbeatScheduler.tick()` as a clock, not as the scheduler's handler lifecycle.** F-023's in-flight/handler semantics do not wrap the daemon handler. | (not flagged independently; A-P2 instead praises listener-cleanup) | **Minor: "F-031 uses tick() as a clock, not as scheduler's handler lifecycle"** | **CONSIDER** (single-model gpt-5.5). Either register the daemon handler with `HeartbeatScheduler` so F-024 in-flight skip-counting wraps it, OR document that `runDaemon` intentionally uses `tick()` only as heartbeat accounting. Documentation is the minimum-change path. |
| **F9** | **F-138 RunOutcome `status='completed'` returned on `finish/error` without halt.** JSDoc lists `'stop'/'tool'/'length'` for `'completed'`; `'error'` is omitted in the doc but reachable in code when threshold not yet hit. | **Minor (A-3)** | (not flagged independently) | **SHOULD-FIX** (single-model Opus Minor). Update RunOutcome JSDoc at `cycle.ts:77-78` to document the threshold-not-reached single-error finish semantics, OR add a third `status: 'error'` for that branch. Documentation is the minimum-change path. |
| **F10** | **F-032 descriptor-as-data already needs an adapter despite claiming BrowserWindow-ready shape.** `maximized` flag requires post-construct `win.maximize()` call (not a constructor option); `ipcChannels` is app metadata, not BrowserWindow option. | (not flagged independently; A-P3 praises non-overridable security tripod) | **Major: "F-032 descriptor already needs an adapter despite claiming BrowserWindow-ready shape"** | **SHOULD-FIX** (single-model gpt-5.5 Major). Either (a) restructure the shape to `{ browserWindowOptions, postCreate, ipcChannels }` to separate constructor options from post-create actions and app metadata; OR (b) document the required adapter explicitly in F-032 ledger before the LOCKED transition. Option (b) is the minimum-change path; option (a) is the principled refactor. |
| **F11** | **F-032 security-tripod "non-overridable" is factory-only, not descriptor-enforced.** `createMainWindow` returns a normal mutable object; consumer can `descriptor.webPreferences.sandbox = false` post-call. | (not flagged independently; A-P3 praises the option-shape non-overridability) | **Major: "F-032 security-tripod non-overridable is factory-only, not descriptor-enforced"** | **SHOULD-FIX** (single-model gpt-5.5 Major). Return a frozen / `as const` / deeply readonly descriptor (Opus's praise stands at the option-API level; gpt-5.5's finding is that the returned object itself is mutable). `Object.freeze(...)` on the returned descriptor is the minimum-change fix. |
| **F12** | **Wave-016 F1 "RESOLVED" status is partial -- F-021 ladder + F-022 per-spawn quota still deferred per F-138 ledger.** | (not flagged; V-5 marks F1 RESOLVED) | **Major: "F-138 closes the spine gap, but the wave-016 full canonical flow is still not closed"** | **CONSIDER** (single-model gpt-5.5 Major). Both models agree the SPINE is in place; gpt-5.5 reads wave-016 F1's exact wording stricter (`F-001 -> F-009 -> F-019 -> F-022 -> F-021 -> F-018 -> F-014` requires F-021 + F-022 wired, not just instantiated). Decision: the "RESOLVED" label is correct for "composition spine exists"; mark F1 as **"spine resolved; canonical integration flow pending F-139/F-021/F-022 + one cross-feature integration test"** in the F-138 ledger transition note. Tracks F12 as part of F-138's pre-LOCKED checklist alongside F1, F2, F4, F5. |
| **P1** | **F-138 orchestrator-identity discipline is immaculate -- compose; do not re-implement.** Every step delegates to a LOCKED primitive; AuditChain adapter is thin alias. | **Praise (A-P1)** | **Praise: "F-138 follows compose-don't-reimplement for core primitives"** | **PRAISE** -- both confirm. Continue this pattern in M3+. Cite as exemplar when adding F-020/F-021/F-022/F-017 wiring. |
| **P2** | **F-031 listener-cleanup-as-load-bearing-detail (entry-attach + finally-detach) generalizes to all deferred OS-process concerns.** | **Praise (A-P2)** | **Praise: "F-031's injectable signal source is a good IPC extension seam"** | **PRAISE** -- both confirm. Preserve the EventEmitter abstraction when OS-process daemon mode lands. |
| **P3** | **F-032 descriptor-as-data idiom is unit-testable + JSON-cloneable + composable.** | (implicit -- no Electron in tests is praised throughout) | **Praise: "F-032's descriptor-as-data idiom is unit-testable and composable"** | **PRAISE** -- both confirm at different lenses (Opus on security tripod, gpt-5.5 on JSON cloneability). Keep the pure-data idiom; F-033..F-043 will compose against this same shape. |
| **P4** | **F-138 RunOutcome extension surface holds for M3+ without reshaping.** F-020/F-021/F-022/F-017 are additive insertions, not refactors. | **Praise (V-1)** | **Praise: "F-138's RunOutcome is a useful M3+ extension surface"** | **PRAISE** -- both confirm. Add future fields additively; avoid changing the existing status/audit/event spine. |
| **P5** | **F-031 injectable `signals` EventEmitter generalizes to IPC-socket transport events without API change.** | **Praise (V-2)** | **Praise: same** | **PRAISE** -- both confirm. The OS-process daemon layer (future F-104..F-109) can wrap `runDaemon` without forking it. |
| **P6** | **F-032 IPC channel `keyof IpcInvokeMap` indirection means descriptor widens automatically as channels are added.** | **Praise (V-3)** | (not echoed at praise; gpt-5.5 turns it into F7-Major saying type-not-interface limits this) | **PRAISE** (single-model Opus). Reconciled with F7: the indirection IS extensible (Opus correct), but the `type` vs `interface` distinction (gpt-5.5 in F7) means consumers cannot declaration-merge -- they must edit the central scaffold. Both observations stand. |
| **P7** | **The spine reveals a cross-feature integration-test pattern (daemon -> engine-cycle -> window-descriptor) that addresses wave-016 F16 "no cross-feature integration test."** | **Praise (V-4)** | **Major: "The three-feature spine reveals the missing integration test pattern"** (severity flipped to Major because gpt-5.5 frames it as actionable, not just praise) | **MUST-FIX (action)** -- both flag the same pattern; gpt-5.5 escalates to actionable. Decision: author the integration test in next wave (wave-020 lane candidate). Test shape (per Opus V-4 sketch): daemon hosts a HeartbeatScheduler, ticks invoke `runEngineCycle({backend: StubBackend, retro: validRetro})`, descriptor consumed at daemon-start time. Closes wave-016 F16 + finalizes wave-016 F1 closure per F12 above. |
| **P8** | **Wave-016 HARD BLOCK F1 RESOLVED at the spine level.** F-138 IS the M3-prerequisite composition layer the 18 LOCKED M0/M1/M2 primitives lacked. | **Praise (V-5)** | (acknowledged at F12 but qualified as "partial") | **PRAISE (qualified)** -- both agree the spine is in place. See F12 for the canonical-flow nuance gpt-5.5 raised. |

**Summary count:**
- **HARD BLOCKs (both flag Critical):** 0
- **MUST-FIXes (both flag, escalated to higher severity OR action):** 6 (F1, F2, F3, F4, P7-as-action, F5 single-model-strong-evidence)
- **SHOULD-FIXes (both flag at lower severity OR single-model-major):** 5 (F6, F7, F9, F10, F11)
- **CONSIDER:** 2 (F8, F12)
- **PRAISE:** 8 patterns to preserve (P1-P8 with P8 qualified)

## Findings by lens

### Architect lens -- composition coherence

#### F1 -- F-138 normal-path event loop lacks try-finally (BOTH-FLAG MAJOR)

`packages/engine-core/src/cycle.ts:214-259` -- the `for await (const event of config.backend.sendPrompt(...))` loop has no try-finally. If the AsyncGenerator throws (per `IBackendProvider` contract: "sendPrompt throws on transport failure or unknown sessionId" -- `backend.ts:111-116`), execution jumps past `backend.stopSession` (line 254) and `closeSession(retro())` (line 259).

```typescript
// line 214 -- NO try { around this:
for await (const event of config.backend.sendPrompt(sessionId, config.prompt)) {
  // ...
}
// line 254 -- unreachable if generator threw:
await config.backend.stopSession(sessionId);
// line 259 -- retro never fires:
closeSession(config.retro());
```

**Impact.** M3+ features compose real backend providers (F-010 Anthropic, F-011 Copilot) where transport failures are expected. A network-error mid-stream leaves the backend session dangling and the F-014 retro unfired -- the run never reaches `closed`, which breaks the lifecycle invariant.

**Recommendation.** Wrap `cycle.ts:211-276` in a try-finally that ensures `backend.stopSession(sessionId)` and `closeSession(config.retro())` fire even on generator-throw. Model on the manual-halt path (lines 178-207), which is linear and exception-safe by structure.

#### F5 -- BackendEvent `usage` variant exists but F-138 ignores it (Opus single-model major; concrete drift)

`packages/engine-core/src/backend.ts:72-88` -- the `usage` variant was added by wave-019/lane-b (Opus surfaced this from the source; gpt-5.5 didn't compare):

```typescript
// F-139 usage variant (added wave-019 / lane-b). Concrete backends emit this
// after `finish` so engine-cycle composers (F-138) can compute cost-ledger
// rows (F-019) without re-implementing token-count extraction.
| { type: 'usage'; input_tokens: number; output_tokens: number; ... };
```

`packages/engine-core/src/cycle.ts:89-92` -- stale JSDoc still says:

```typescript
// costTotalUsd is CostLedger.totalUsd() -- 0 in v1 because BackendEvent has
// no `usage` variant per wave-016 D-36; F-139 adds the variant ...
```

`cycle.ts:218-241` event loop handles `tool_call` and `finish` only; `usage` events pass through with no cost-ledger wiring.

**Impact.** Backends that emit `usage` events (F-010/F-011 once F-139 lands) will flow through the cycle but `costTotalUsd` stays 0. Downstream F-131 fanout-budget-governor cannot function. The F-138 ledger `out-of-scope-notes` item #6 ("F-013 event-normalization usage variant: cycle.ts does NOT compute cost-ledger rows from BackendEvent because BackendEvent has no `usage` variant per wave-016 D-36") is now stale.

**Recommendation.** Add `else if (event.type === 'usage')` branch in event loop; call `cost.append({input_tokens, output_tokens, ...})`. Update stale JSDoc at `cycle.ts:89-92` AND ledger `out-of-scope-notes` item #6 -- if the wiring IS intentionally deferred past this wave, change wording to "variant exists in BackendEvent (wave-019/lane-b); cost-ledger wiring deferred to wave-NNN" per `no-silent-deferrals.md`.

#### F9 -- RunOutcome `status='completed'` on finish/error without halt (Opus single-model minor)

`cycle.ts:228-241` returns `status='completed'` when `finish/error` arrives and `maxConsecutiveFailures: 3` hasn't been reached. JSDoc at `cycle.ts:77-78` lists only `'stop'/'tool'/'length'` -- `'error'` is undocumented but reachable.

**Impact.** Consumers checking `outcome.status === 'completed'` cannot distinguish a clean stop from a single-error finish without inspecting `outcome.events`.

**Recommendation.** Update JSDoc to document threshold-not-reached single-error finish semantics, OR add a third status `'error'` for that branch. Documentation is the minimum-change path.

#### F10 -- F-032 descriptor needs adapter (gpt-5.5 single-model major)

`window.ts:101-105` says "The BrowserWindow constructor itself doesn't take a `maximized` flag -- Electron expects a post-construct `win.maximize()` call." `window.ts:143-149` also stores `ipcChannels` control-plane metadata.

**Impact.** A future M5 consumer cannot safely do only `new BrowserWindow(descriptor)`; it must split constructor options from post-create actions and app metadata. The "BrowserWindow-ready shape" claim is partially aspirational.

**Recommendation.** Either (a) restructure the descriptor to `{ browserWindowOptions, postCreate, ipcChannels }` to separate concerns, OR (b) document the required adapter explicitly in F-032 ledger before LOCKED. Option (b) is minimum-change; option (a) is the principled refactor.

#### F11 -- F-032 security tripod is factory-only, not descriptor-enforced (gpt-5.5 single-model major)

`window.ts:177-182` claims the tripod is non-overridable, but `createMainWindow` returns a normal mutable object at `window.ts:191-205`. A consumer can `descriptor.webPreferences.sandbox = false` post-call.

**Impact.** Reconciles with Opus's A-P3 (which praises the OPTION-API non-overridability -- correct: `MainWindowOptions` has no `webPreferences` field). gpt-5.5's finding is one layer deeper: the RETURNED object is mutable. Two complementary observations.

**Recommendation.** `Object.freeze(returnedDescriptor)` -- minimum-change fix. Alternatively `as const` the literal + JSDoc the immutability contract.

### Skeptic lens -- failure modes the descriptor-as-data idiom hides

#### F2 -- F-031 infinite-throwing handler spins daemon CPU-hot (BOTH-FLAG MAJOR)

`daemon.ts:163-179` -- with `maxTicks = Infinity` (production default, line 144) and `tickIntervalMs = 0` (default, line 145), a handler that always throws iterates the loop at maximum speed with zero delay between iterations.

```typescript
while (!shutdownRequested && tickCount < maxTicks) {
  try {
    await scheduler.tick();
    await handler();
    tickCount++;
  } catch (err) {
    lastError = err instanceof Error ? err : new Error(String(err));
    tickCount++;
  }
  // ... no consecutive-failure guard
}
```

**Impact.** Production daemon deployment with a broken handler (config error, unreachable dependency, etc.) consumes 100% CPU core with no automatic recovery or exit. Only external SIGTERM/SIGINT stops it. The comment at line 128-131 cites "F-021 degradation-fallback territory" but the daemon has no such wiring.

**Recommendation.** Add `maxConsecutiveHandlerFailures?: number` to `DaemonOptions` (default 10). Track consecutive throws; reset on success; exit with `outcome: 'force_killed'` (reuse existing union variant) when exceeded. Mirrors `HaltDetector.maxConsecutiveFailures` from F-018 -- same concept, applied at the daemon layer.

#### F4 -- F-031 dual-invocation in same process (BOTH-FLAG; severity diverges Major/Minor)

`daemon.ts:140-198` -- `runDaemon` is a pure async function with no module-scoped guard. Two callers invoking it concurrently each get their own `shutdownRequested` flag, `tickCount`, and `lastError`. Both attach listeners to the same `signals` emitter (default: `process`), so a single SIGTERM sets both `shutdownRequested` flags.

The F-031 ledger (`F-031-daemon-mode.md:49`) documents: "Only one daemon may run per state-dir at a time ... a second `daemon start` against a live PID rejects with `DAEMON_ALREADY_RUNNING`." The PID-file check is deferred; no in-process equivalent exists.

**Impact.** A misuse pattern (two CLI commands sharing a process, or a test that forgets to `await` the first `runDaemon` before starting a second) causes two parallel tick loops with no way to distinguish or individually stop them.

**Recommendation.** Add an in-process singleton guard:

```typescript
let _running = false;
export async function runDaemon(opts: DaemonOptions): Promise<DaemonOutcome> {
  if (_running) throw new Error('DAEMON_ALREADY_RUNNING (in-process)');
  _running = true;
  try { /* ... existing body ... */ }
  finally { _running = false; }
}
```

Strict subset of the deferred PID-file check; cheap to implement; prevents the "two loops, no coordination" hazard without touching the OS-process scope.

#### F3 -- costTotalUsd: 0 vs unknown (BOTH-FLAG; severity diverges Minor/Major)

`cycle.ts:101-102` declares `costTotalUsd: number;`. In v1 it is always 0 because no rows are appended (per F5). A backend that genuinely costs $0 (free tier) would also produce `costTotalUsd: 0`. Consumers cannot distinguish the two states. The test at `tests/unit/F-138-engine-cycle-orchestrator.test.ts:65-66` locks this in.

**Impact.** Minor in v1 (all runs return 0). Becomes meaningful in M3+ when some backends report usage and others don't. Consumers building dashboards or budget alerts need to differentiate "free" from "untracked."

**Recommendation.** `costTotalUsd: number | null` with `null` = "tracking not available" OR add `costStatus: 'known' | 'unknown'` companion field. Resolves naturally at F-139 wiring.

#### F6 -- windowsHide cross-platform no-op (BOTH-FLAG MINOR)

`window.ts:109-113` documents "On Windows, prevent the spawn flash" but `window.ts:197` sets `windowsHide: true` unconditionally. macOS/Linux Electron silently ignores this property.

**Recommendation.** Append to JSDoc: "No-op on macOS/Linux; set unconditionally for cross-platform descriptor portability per the `descriptor-as-data` idiom." OR move to a launcher-metadata section per gpt-5.5's framing.

#### F7 -- IpcInvokeChannel = never bypasses type contract (BOTH-FLAG; severity diverges Minor/Major)

`common/ipc-contract.ts:52-58` declares `IpcInvokeMap` as a `type` (empty) -- so `IpcInvokeChannel = keyof IpcInvokeMap = never`. `tests/unit/F-032-window.test.ts:143-146` passes `['chat.send', 'settings.read']` as `ReadonlyArray<never>` -- compiles only because vitest transpiles via esbuild/SWC without type-checking. A `pnpm typecheck` run that includes test files would flag `TS2322: Type 'string' is not assignable to type 'never'`.

gpt-5.5 adds: `IpcInvokeMap` is a `type` not an `interface`. Future M5 features cannot declaration-merge new channels; they must edit the central scaffold directly.

**Recommendation (combined).** (a) Add `// @ts-expect-error -- IpcInvokeMap is empty; runtime shape with arbitrary strings tested here` to the test scenario 4 site; (b) Convert `IpcInvokeMap` from `type` to `interface` so consumer features can declaration-merge new channels in their own files. Both fixes minutes; the asymmetry is currently aspirational vs enforced.

#### F8 -- F-031 uses tick() as clock not handler-lifecycle (gpt-5.5 single-model minor)

`daemon.ts:165-168` calls `await scheduler.tick(); await handler();`. But `heartbeat.ts:290-292` only invokes the scheduler's own handler if `tickHandler !== null`. The F-024 in-flight skip-counting wraps the scheduler's handler, not the daemon's.

**Recommendation.** Either register the daemon handler with `HeartbeatScheduler` so F-024 in-flight semantics wrap it, OR document that `runDaemon` intentionally uses `tick()` only as heartbeat accounting. Documentation is minimum-change.

### Advocate lens -- extension paths the spine enables

#### P1 -- F-138 orchestrator-identity discipline immaculate (BOTH-FLAG PRAISE)

Every step in `cycle.ts:149-278` delegates to a LOCKED primitive: `createAgent()`/`createSession()` -> F-002, `appendAuditEntry` via AuditChain adapter -> F-015, `backend.startSession`/`sendPrompt`/`halt`/`stopSession` -> F-009, `HaltDetector.recordToolCall`/`recordFailure` -> F-018, `CostLedger.totalUsd` -> F-019, `closeSession(retro)` -> F-014. AuditChain (lines 114-132) is a thin ergonomic wrapper -- never re-implements hash chain or chain verification.

#### P2 -- F-031 listener-cleanup-as-load-bearing (BOTH-FLAG PRAISE)

`daemon.ts:159-186` entry-attach + finally-detach is verified by `tests/node/F-031-daemon-mode.test.ts:179-225` (listenerCount returns to baseline; no accumulation across two sequential invocations). Generalizes to all deferred OS-process concerns (PID-file, IPC-socket, heartbeat-file) without changing `runDaemon`'s signature.

#### P3 -- F-032 descriptor-as-data idiom (BOTH-FLAG PRAISE at different lenses)

JSON-cloneable per scenario 6 test (`tests/unit/F-032-window.test.ts:175-183`). Unit-testable without bundling Electron into the test runner. F-038..F-043 will compose against this same shape per the wave-018 lane-c registered idiom.

#### P4 -- F-138 RunOutcome extension surface (BOTH-FLAG PRAISE)

F-020 kill-switch -> add `killSwitch.poll()` between event-loop iterations. F-021 degradation -> instantiate `DegradationLadder` alongside `HaltDetector`. F-017 redaction -> pipe audit entries through `redact()` before append. F-022 per-spawn quota -> replace global `recordToolCall` with per-`agent_id` tracking (HaltContext already carries `agent_id`). Multi-iteration loop -> wrap existing single-pass in outer loop; `maxIterations` config already exists. None require RunOutcome reshaping.

#### P5 -- F-031 injectable signals EventEmitter (BOTH-FLAG PRAISE)

`daemon.ts:114-116` -- the OS-process daemon layer (future F-104..F-109) can wrap `runDaemon` without forking it. `on`/`off` is all `runDaemon` depends on; future IPC-socket events (`'shutdown'`, `'reload'`, `'status'`) emit on the same emitter.

#### P6 -- F-032 IPC channel keyof indirection (Opus praise; partially-flagged by gpt-5.5 in F7)

When `IpcInvokeMap` gains entries, `IpcInvokeChannel` widens automatically. The descriptor accepts new channel names without `window.ts` change. Reconciled with F7: extensibility holds at the indirection level (Opus correct); declaration-merging requires `interface` not `type` (gpt-5.5 in F7).

#### P7 -- Spine reveals integration test pattern (BOTH-FLAG; gpt-5.5 escalates to actionable)

The integration test shape is now expressible:

```typescript
const descriptor = createMainWindow({ /* restored state */ });
const scheduler = new HeartbeatScheduler({ profile: 'custom', intervalSeconds: 1, ... });
const outcome = await runDaemon({
  scheduler,
  handler: async () => {
    const result = await runEngineCycle({
      backend: new StubBackend(),
      prompt: 'integration-tick',
      retro: () => validRetro,
    });
    // assert result.status === 'completed'
  },
  maxTicks: 3,
});
// assert outcome.outcome === 'tick_exhausted', outcome.tickCount === 3
```

Wave-016 F16 flagged: "No cross-feature integration test exercises the canonical flow." This spine makes that test expressible for the first time. **Authoring this test is a wave-020 lane candidate.**

#### P8 -- Wave-016 HARD BLOCK F1 RESOLVED at spine level (BOTH-FLAG; gpt-5.5 qualifies)

F-138 is the M3-prerequisite composition layer the 18 LOCKED primitives lacked. gpt-5.5's qualification (F12 in agreement table): wave-016 F1's exact wording calls for `F-001 -> F-009 -> F-019 -> F-022 -> F-021 -> F-018 -> F-014`; F-021 + F-022 wiring are still deferred per F-138's `out-of-scope-notes`. Decision: re-label as "spine resolved; canonical flow pending F-139/F-021/F-022 wiring + cross-feature integration test."

## Resolved prior-wave findings

| Wave-016 finding | Status in wave-019 |
|---|---|
| **F1 (HARD BLOCK):** No engine-cycle orchestrator | **PARTIALLY RESOLVED** by F-138 -- spine present, canonical flow (F-021 + F-022 wired) still pending. Re-label per F12. |
| **F8 (MUST-FIX):** BackendEvent lacks `usage` variant | **RESOLVED** by wave-019/lane-b (`backend.ts:72-88`). But F-138 doesn't wire it yet (F5 above). |
| **F16 (MUST-FIX):** No cross-feature integration test | **UNBLOCKED** -- the spine makes the test expressible (P7 above). Test not yet authored; wave-020 candidate. |

## Recommendations summary (pre-LOCKED checklist)

| # | Severity | Action | Target | Pre-LOCKED? |
|---|---|---|---|---|
| F1 | Major (BOTH) | Add try-finally around event loop + post-loop cleanup in cycle.ts | F-138 | YES |
| F2 | Major (BOTH) | Add `maxConsecutiveHandlerFailures` to DaemonOptions (default 10) | F-031 | YES |
| F3 | Major (BOTH) | costTotalUsd `number \| null` OR add `costStatus` field | F-138 | YES |
| F4 | Major (BOTH) | Add in-process singleton guard to runDaemon | F-031 | YES |
| F5 | Major (Opus) | Wire `usage` events to CostLedger.append; update stale JSDoc + ledger | F-138 | YES |
| P7 | (Action) | Author cross-feature integration test (closes wave-016 F16) | NEW (wave-020 lane) | NO (next wave) |
| F6 | Minor (BOTH) | Document `windowsHide` cross-platform no-op semantics | F-032 | NO |
| F7 | Minor (BOTH; gpt-5.5 Major) | Add `@ts-expect-error` to test 4; convert IpcInvokeMap type->interface | F-032 / F-007 | NO |
| F9 | Minor (Opus) | Update RunOutcome JSDoc on finish/error -> 'completed' semantics | F-138 | NO |
| F10 | Major (gpt-5.5) | Document descriptor adapter requirement OR refactor shape | F-032 | NO (LOCKED-blocker if option (a)) |
| F11 | Major (gpt-5.5) | `Object.freeze` returned descriptor | F-032 | NO |
| F8 | Minor (gpt-5.5) | Document tick() as clock-only OR register handler with scheduler | F-031 | NO |
| F12 | Major (gpt-5.5) | Re-label wave-016 F1 as "spine resolved; canonical flow pending" | F-138 ledger note | YES |

**Pre-LOCKED for F-138:** F1 + F3 + F5 + F12 (4 items).
**Pre-LOCKED for F-031:** F2 + F4 (2 items).
**Pre-LOCKED for F-032:** none required by both-flag (F10/F11 are gpt-5.5 single-model major; recommend addressing before LOCKED but not strict gate).

## Loop-improvement proposals for wave-20+

1. **Wire the cross-feature integration test in wave-020.** P7 makes it expressible; authoring it closes wave-016 F16 and validates the spine end-to-end.
2. **Mandate `pnpm typecheck` includes test files.** F7 surfaced because vitest transpiles without type-checking; a real `tsc --noEmit` would have flagged the `string -> never` mismatch at `F-032-window.test.ts:143`. Add to CI gate.
3. **Cross-model agreement: `severity-divergence-take-the-higher` rule worked.** F3, F4, F7 had Opus minor / gpt-5.5 major (or vice versa); the higher severity won and produced actionable items. Continue the rule for wave-024.
4. **Single-model strong-evidence findings should NOT be auto-demoted** when the evidence is concrete code-vs-spec drift. F5 (Opus single-model Major) is the example -- gpt-5.5 didn't compare backend.ts:72-88 against cycle.ts:89-92 JSDoc; Opus did. Add a "concrete drift" tag to single-model findings so the demotion rule has a carve-out for this pattern.
5. **Cadence: every-5-waves QG7 holding well.** wave-001 (foundation) -> wave-016 (M0+M1+M2 impl) -> wave-019 (spine integrated). Next slot wave-024 covers mid M3-M5 expansion -- right shape for cross-model verification on the F-021/F-022 wiring landing.

## Anomalies

- **Both models initially failed to find files** because Copilot CLI's working directory was `C:/Users/tonym/Repos/MAD - Clean` (the kit), not `C:/Users/tonym/Repos/mad-council-claw` (the source). Both eventually located the repo via different paths (Opus via `Test-Path`, gpt-5.5 via github-mcp + clone). Brief should explicitly state target repo path on first line for next dispatch.
- **Opus persisted its full review to a sidecar `opus-result.md`** (494 lines) -- consistent with wave-016 anomaly note "Opus chose to verify by reading + dumping every file first". For wave-024, brief should explicitly request structured findings WITHOUT preamble dump.
- **gpt-5.5 used the GitHub MCP server to fetch sources** (vs filesystem reads). Worked but added latency and produced fewer detailed line citations than Opus. Both arrived at structurally similar findings, confirming the cross-model agreement rule.
- **Concurrency cap held**: dispatcher Mode = `CopilotCLI` cleanly; no Timeout/ConcurrencyLimited fallback path triggered. Both jobs completed within 1200s budget.

---

*Authored 2026-05-07 wave-019 / lane-d. Cross-model agreement table populated per `lens-multi-model-review-pattern.md`. ZERO HARD BLOCKs; 6 MUST-FIXes (4 of which are pre-LOCKED for F-138/F-031); 5 SHOULD-FIXes; 8 PRAISE patterns to preserve. Spine integrity confirmed.*
