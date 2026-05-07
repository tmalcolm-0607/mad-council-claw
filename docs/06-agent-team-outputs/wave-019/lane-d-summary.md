---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-019 / lane-d)
wave: wave-019
lane: lane-d
topic: QG7 Copilot CLI cross-model design review of the composition spine (F-138 + F-031 + F-032 integrated set)
date: 2026-05-07
status: complete
---

# Wave 19 / Lane D -- QG7 Copilot CLI design review (every-5-waves cadence)

## Scope

QG7 every-5-waves Copilot CLI multi-model design review of the **composition spine** -- the three NEW (composition-spine) features that landed across waves 17-18:

1. **F-138 engine-cycle-orchestrator** (M0 / wave-17 lane-a) -- composes F-001/F-002/F-009/F-014/F-015/F-018/F-019 into one MAD-pipeline iteration. Resolved wave-016/lane-d HARD BLOCK F1.
2. **F-031 daemon-mode** (M4 / wave-18 lane-b) -- long-lived in-process tick loop primitive driving an F-023 HeartbeatScheduler with graceful-shutdown signal handling.
3. **F-032 window** (M5 / wave-18 lane-c) -- Electron BrowserWindow descriptor-as-data factory. Pure-data shape; no Electron instantiation.

These three are reviewed as a **set** because they collectively introduce three distinct ledger-deferral idioms (compose-don't-reimplement / minimum-viable-stub / descriptor-as-data, instantiation-deferred) and form the M3+ on-ramp the wave-016 review named as the M3 prerequisite.

## Review path taken

**Multi-model dispatch via `Invoke-CopilotMultiModel.ps1`** at `TimeoutSeconds=1200`. Dispatcher Mode = **CopilotCLI** (Copilot CLI v1.0.44 detected on PATH; primary path active; no fallback triggered).

- `claude-opus-4.7` -- ~10m 57s wall-clock; 12.6 KB raw output + 494-line structured md sidecar at `.mad/scratch/wave-019-design-review-output/opus-result.md`. ~1.4M input + 31.0k output tokens (~1.3M cached).
- `gpt-5.5` -- ~5m 28s wall-clock; 27.5 KB raw output. ~1.8M input + 17.6k output + 8.8k reasoning tokens (~1.6M cached).

Both jobs completed within the 1200s budget; no Timeout / ConcurrencyLimited fallback paths triggered. Cross-model agreement table populated per `.claude/rules/lens-multi-model-review-pattern.md`.

## Cross-model agreement table summary

**ZERO HARD BLOCKs.** No findings flagged Critical by BOTH models. The composition spine is structurally sound; no gate against M3 entry.

| Class | Count | Examples |
|---|---|---|
| **HARD BLOCK** (both flag Critical) | **0** | -- |
| **MUST-FIX** (both flag, escalated to higher severity OR action) | **6** | F1 try-finally on event loop, F2 maxConsecutiveHandlerFailures, F3 costTotalUsd 0-vs-unknown, F4 in-process singleton guard, F5 usage variant wiring (Opus single-model strong-evidence), P7 cross-feature integration test (gpt-5.5 escalates to action) |
| **SHOULD-FIX** (both-flag at lower severity OR single-model major) | **5** | F6 windowsHide cross-platform doc, F7 IpcInvokeMap type->interface + @ts-expect-error, F9 RunOutcome finish/error JSDoc, F10 descriptor-needs-adapter, F11 Object.freeze returned descriptor |
| **CONSIDER** | **2** | F8 tick()-as-clock vs handler-lifecycle, F12 wave-016 F1 re-label "spine resolved; canonical flow pending" |
| **PRAISE** | **8** | P1 orchestrator-identity discipline, P2 listener-cleanup pattern, P3 descriptor-as-data idiom, P4 RunOutcome extension surface, P5 injectable signals EventEmitter, P6 keyof IpcInvokeMap indirection, P7 (also action), P8 wave-016 F1 spine-resolved |

**Pre-LOCKED checklist by feature:**
- **F-138** (4 items): F1 + F3 + F5 + F12 ledger re-label
- **F-031** (2 items): F2 + F4
- **F-032** (none required by both-flag; F10/F11 recommended single-model)

## Key findings highlighted

### MUST-FIX (BOTH-FLAG MAJOR)

- **F1 -- F-138 normal-path event loop lacks try-finally** (`cycle.ts:214-259`). AsyncGenerator throw mid-stream leaks backend session and skips F-014 retro. Manual-halt path (lines 178-207) is exception-safe by structure; normal path is not. **Fix:** wrap event loop + post-loop cleanup in try-finally.
- **F2 -- F-031 infinite-throwing handler spins CPU-hot** (`daemon.ts:163-179`). `maxTicks = Infinity + tickIntervalMs = 0` permits 100% CPU on perpetually-failing handler. **Fix:** add `maxConsecutiveHandlerFailures` (default 10) mirroring `HaltDetector.maxConsecutiveFailures` from F-018.

### MUST-FIX (BOTH-FLAG; severity diverges)

- **F3 -- costTotalUsd: 0 conflates known-zero with unknown** (Opus Minor, gpt-5.5 Major; take higher). Take `costTotalUsd: number | null` OR add `costStatus` companion field.
- **F4 -- F-031 dual-invocation in same process** (Opus Major, gpt-5.5 Minor; take higher). Add module-scoped `_running` singleton guard with try-finally reset.

### MUST-FIX (Opus single-model strong-evidence)

- **F5 -- BackendEvent `usage` variant exists (wave-019/lane-b) but F-138 ignores it.** Concrete code-vs-spec drift: `backend.ts:72-88` added the variant; `cycle.ts:89-92` JSDoc still claims it doesn't exist; `cycle.ts:218-241` event loop never handles it. gpt-5.5 missed because it didn't compare backend.ts against cycle.ts JSDoc. **Fix:** add `else if (event.type === 'usage')` branch + update stale JSDoc + ledger `out-of-scope-notes` item #6.

### Action item

- **P7 -- Cross-feature integration test now expressible** (gpt-5.5 escalates from Praise to Major-action). The spine reveals a daemon -> engine-cycle -> window-descriptor integration test pattern that closes wave-016 F16. **Wave-020 lane candidate.**

### Praise (BOTH-FLAG)

- **P1 -- F-138 orchestrator-identity discipline immaculate.** Every step delegates to a LOCKED primitive; AuditChain adapter is thin alias.
- **P2 -- F-031 listener-cleanup-as-load-bearing.** Entry-attach + finally-detach generalizes to all deferred OS-process concerns.
- **P3 -- F-032 descriptor-as-data idiom.** JSON-cloneable, unit-testable without Electron, composable for F-038..F-043.
- **P4 -- RunOutcome extension surface.** F-020/F-021/F-022/F-017 are additive insertions, not refactors.
- **P5 -- F-031 injectable `signals` EventEmitter.** OS-process daemon layer (future F-104..F-109) wraps without forking.
- **P8 (qualified) -- Wave-016 HARD BLOCK F1 RESOLVED at spine level.** Canonical-flow nuance per F12.

## What this lane did NOT do

- **No code changes.** This is a design review lane only; recommendations are recorded in the review artifact for the relevant feature owners to execute pre-LOCKED.
- **No new ledger flips.** F-138/F-031/F-032 remain at their wave-17/18 transition states; LOCKED transitions are gated on the pre-LOCKED checklist items above.
- **No integration test authoring.** P7 is recorded as a wave-020 lane candidate; not authored here per minimum-change discipline.

## Anomalies

- **Both models initially failed to find files.** Copilot CLI's working directory was `C:/Users/tonym/Repos/MAD - Clean` (the kit), not `C:/Users/tonym/Repos/mad-council-claw` (the source). Both eventually located the repo via different paths (Opus via `Test-Path`, gpt-5.5 via github-mcp + clone). **Loop-improvement proposal #1 for wave-024:** brief should explicitly state target repo path on first line.
- **Opus persisted its full review to a sidecar md** (494 lines at `.mad/scratch/wave-019-design-review-output/opus-result.md`). Consistent with wave-016 anomaly note "Opus chose to verify by reading + dumping every file first". **Loop-improvement proposal #2:** brief should explicitly request structured findings WITHOUT preamble dump.
- **gpt-5.5 used the GitHub MCP server to fetch sources** (vs filesystem reads). Worked but added latency. Both arrived at structurally similar findings, confirming the cross-model agreement rule.

## Cross-lane staging-discipline

Per user directive 2026-05-07 + waves 13-18 precedent: NO `git reset` (any flavor); use `git restore --staged` or selective `git add <paths>` only. This lane's commits use explicit `git add <paths>` only; no `git add .` / `git add -A`.

### Sighting #19 (CHRONIC since wave-9; same pattern as F-031 sighting #18)

The first commit attempt (`7be3b24`) titled "docs(wave-019/lane-d): QG7 Copilot CLI multi-model design review" did NOT land the two Lane D files; it instead swept 14 sibling-lane files (F-139 / F-140 / F-033 / F-034 ledgers + their proof artifacts + lane-b summary + supporting source under `packages/engine-core/src/`). Pre-commit hook scope crossed the explicit `git add` set during execution. Same root cause as wave-018 sighting #18(b): the pre-commit-hook scope is broader than the explicit `git add` set when sibling lanes' working-tree modifications exist at hook-execution time.

Per `non-negotiable-rules.md` (NO `git reset` per user directive 2026-05-07), no rebase/reset to fix history. The mis-attributed HEAD commit (`7be3b24`) preserved real lane-b work; the two Lane D files re-staged + committed in a follow-up commit at this sighting. Substance preserved on both sides; credit attribution recorded openly here.

Pattern is now CHRONIC across waves 9-19 (sightings #14-#19). Strategic fix candidates pending council retro at end of wave-19+:
(a) per-lane branches when concurrent lane count >= 3
(b) pre-commit hook scope-restriction to `git diff --cached --name-only` only -- the chronic root cause; the hook should NEVER touch the working tree
(c) per-feature scope manifest at `.mad/wave-N/lane-X/scope.txt` with hook-enforced reject on cached-but-not-listed files

## Push at end

Per user directive 2026-05-07 (`Push at end is AUTHORIZED for this loop session`), this lane pushes after the commit lands cleanly.

## Files written

| Path | Type |
|---|---|
| `docs/05-design-reviews/copilot-cli-design-reviews/wave-019-f138-f031-f032-integrated-review.md` | new (~430 LOC) -- the review artifact + cross-model agreement table |
| `docs/06-agent-team-outputs/wave-019/lane-d-summary.md` | new -- this summary |

Sidecar artifacts at `.mad/scratch/wave-019-design-review-output/` (NOT committed -- ephemeral dispatcher output): `opus-result.json`, `opus-result.md` (Opus's structured 494-line review), `gpt-result.json`, `gpt-result.md` (gpt-5.5's review extracted from JSON wrapper).

## Loop-improvement proposals

1. **Wire cross-feature integration test in wave-020** (closes wave-016 F16; validates spine end-to-end).
2. **Mandate `pnpm typecheck` includes test files** (F7 surfaced because vitest transpiles without type-check; CI gate addition).
3. **Severity-divergence rule held**: take-the-higher worked for F3, F4, F7. Continue.
4. **Single-model strong-evidence carve-out**: F5 (Opus alone) is the example -- concrete code-vs-spec drift should NOT auto-demote. Add a "concrete drift" tag for the demotion rule's carve-out.
5. **Cadence (every-5-waves QG7) holding well**: wave-001 -> wave-016 -> wave-019. Next slot wave-024 (~mid M3-M5 impl).
