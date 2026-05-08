---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-019 / lane-a)
wave: wave-019
lane: lane-a
topic: F-033 chat-history-pane + F-034 session-info-panel RED -> GREEN — second + third M5 desktop-shell features
date: 2026-05-07
status: complete
---

# Wave 19 / Lane A — F-033 + F-034 RED -> GREEN, M5 desktop-shell continues

## Scope

Flip F-033 (`history` — multi-session left rail) and F-034 (`info-panel` — right-side run metadata) from RED to GREEN per each ledger's `red-green-rule` predicate:

```
GREEN if all test files exist AND all runners return zero exit.
```

This is the **second + third M5 desktop-shell feature transition.** M5 was 11R + 1G at wave-19 lane start (after F-032 GREEN'd in wave-018 / lane-c). This lane drops 11R + 1G -> 9R + 3G.

The wave-019 / lane-a brief simplifies each ledger's three browser-suite acceptance scenarios to STRUCTURAL / INTERFACE-BASED tests asserting the shape of `buildHistoryPane(opts)` and `buildInfoPanel(opts)` rather than booting the desktop renderer in headless Chromium. Substantive guarantees (sort order + virtualization predicate + lifecycle type-safety + selectedRunId pass-through + IPC channel registration intent for F-033; read-only field rendering + audit-chain badge type-safety + explicit-placeholder discipline + chain-red-masks-cost + missing-cost-emits-placeholder + default-open + closed-only-retro for F-034) are preserved by the structural tests; full DOM render + on-disk read + IPC subscription wiring + button-driven re-verify behavior are deferred to the M5 integration wave per `no-silent-deferrals.md`.

Both features inherit F-032's wave-018 / lane-c-registered "descriptor-as-data, instantiation-deferred" idiom unchanged. F-034 introduces the new **"explicit-placeholder discipline" corollary** to that idiom.

## What was created / modified

| Group | Path | Type |
|---|---|---|
| Test (F-033) | `tests/unit/F-033-chat-history-pane.test.ts` | new (~310 LOC, 6 scenarios) |
| Test (F-034) | `tests/unit/F-034-session-info-panel.test.ts` | new (~245 LOC, 6 scenarios) |
| Source (F-033) | `packages/desktop-shell/src/history-pane.ts` | new (~165 LOC, ESM) |
| Source (F-034) | `packages/desktop-shell/src/info-panel.ts` | new (~190 LOC, ESM) |
| Wiring | `packages/desktop-shell/src/index.ts` | modified (barrel re-exports both new modules + ownership-table comments) |
| Wiring | `packages/desktop-shell/package.json` | modified (exports map gains `./history-pane` + `./info-panel` subpaths) |
| Examples-proof | `docs/09-examples-proof/F-033/red-test-output.txt` | new |
| Examples-proof | `docs/09-examples-proof/F-033/green-test-output.txt` | new (verbose reporter output) |
| Examples-proof | `docs/09-examples-proof/F-034/red-test-output.txt` | new |
| Examples-proof | `docs/09-examples-proof/F-034/green-test-output.txt` | new (verbose reporter output) |
| Ledger flip (F-033) | `docs/03-feature-catalog/M5-desktop-shell/F-033-history.md` | modified (status: red -> green; 2 status-history entries documenting wave-019/lane-a RED+GREEN flips; test-files.unit + test-runner-projects populated; Implementation notes section authored documenting scope simplification + 6 deferrals + cross-feature composition + first-owner ownership of types/constants/helpers) |
| Ledger flip (F-034) | `docs/03-feature-catalog/M5-desktop-shell/F-034-info-panel.md` | modified (status: red -> green; 2 status-history entries; test-files.unit + test-runner-projects populated; Implementation notes section authored documenting scope simplification + 7 deferrals + cross-feature composition + the new "explicit-placeholder discipline" corollary registration + first-owner ownership) |
| Roadmap rows | `roadmap.md` | modified (F-033 row 🔴 -> 🟢 with detail-row test summary; F-034 row 🔴 -> 🟢 with detail-row test summary; M5 row 11R+1G+0L -> 9R+3G+0L; TOTAL 147+97R+8G+24L -> 147+95R+10G+24L; wave-019/lane-a transition note inserted before wave-019/lane-b note) |
| Confidence-ledger | `docs/11-loop-state/confidence-ledger.md` | modified (Wave 19 Lane A section + 4 entries: Lane-A-w19-F-033-GREEN, Lane-A-w19-F-034-GREEN, Lane-A-w19-explicit-placeholder-discipline-corollary, Lane-A-w19-staging-race-mitigation-success) |
| Lane summary | `docs/06-agent-team-outputs/wave-019/lane-a-summary.md` | new (this file) |

## Acceptance scenarios verified at GREEN

### F-033 — 6/6 PASS

| # | Scenario | What it proves |
|---|---|---|
| 1 | `buildHistoryPane()` no-opts returns descriptor matching `DEFAULT_HISTORY_PANE` (empty entries; default threshold=100; default IPC channel) | Default-state contract for fresh installs (no runs) |
| 2 | `buildHistoryPane({entries})` sorts DESC by `lastActivityUtc` | Ledger scenario 1 most-recent-first contract |
| 3 | Virtualization toggles based on `entries.length` vs `threshold` (50=disabled / 100=enabled / 500=enabled / custom-threshold override) | Ledger scenario 3 — rail virtualizes for >100 runs |
| 4 | `selectedRunId` + `liveUpdateChannel` pass-through (including stale id; custom channel override) | Ledger scenario 2 — live updates via IPC; selection state |
| 5 | `resolveHistoryEntry(null \| undefined \| {} \| partial \| full)` always yields a complete `HistoryEntry`; never throws; unknown lifecycle falls back to 'closed' | Partial-state hydration contract; safest read-only default |
| 6 | Descriptor JSON-cloneable; no functions / class instances / Date objects | Plain-data contract |

### F-034 — 6/6 PASS

| # | Scenario | What it proves |
|---|---|---|
| 1 | `buildInfoPanel()` no-opts returns descriptor matching `DEFAULT_INFO_PANEL` (panel open; placeholder fields; chain status null; cost breakdown empty) | Default-state contract for fresh installs (no run selected) |
| 2 | Active run + chain green + live cost breakdown surfaces all metadata fields verbatim | Ledger scenario 1 — all metadata fields present + live sub-totals |
| 3 | Tampered audit chain (status='red') MASKS costBreakdown + emits Context Gap | Ledger scenario 2 — chain broken → red badge + integrity warning + cost masked |
| 4 | Missing cost-ledger (`costBreakdownAvailable: false`) emits placeholder + Context Gap | Ledger scenario 3 — explicit placeholder, NOT silent zeros |
| 5 | Closed run renders retroSummary + killSwitchActive verbatim; active run silently drops retro | F-014 emit-on-close discipline; closed-only retro enforcement |
| 6 | Descriptor JSON-cloneable + isOpen toggle + `resolveInfoPanelField` hydrator (`null`/`undefined`/`''` → placeholder; `0` round-trips) | Plain-data contract; field-level hydration distinguishing "missing" from "actual zero" |

12/12 PASS at GREEN time. **Full unit suite 323/323 across 38 test files** (re-verified at lane-summary time via `pnpm test`). **Build: pnpm build => exit 0.**

## Scope deviations recorded openly

Per `verification-protocol.md` Rule 1 (FETCH BEFORE CITE) + `no-silent-deferrals.md`:

### Scope simplification: structural-shape contracts, not browser-suite Electron-launch

Both F-033 and F-034 ledger §Acceptance scenarios specify three end-to-end browser-suite scenarios that bind to a future M5 integration wave (which boots the desktop renderer in headless Chromium and asserts visual rail/panel behavior). The wave-019 / lane-a brief simplifies the v1 shape to STRUCTURAL / INTERFACE-BASED tests asserting what `buildHistoryPane(opts)` and `buildInfoPanel(opts)` return — the descriptors. Per F-004's "browser project runtime wiring deferred to first DOM-rendering spec consumer wave" + F-032's wave-018 / lane-c "descriptor-as-data, instantiation-deferred" idiom precedent, booting Electron + Playwright in the unit-test path would be premature; the integration wave is the consumer.

**Substantive guarantees preserved by the structural tests:**

For F-033:
- Sort order (entries DESC by `lastActivityUtc`)
- Virtualization predicate (`enabled === entries.length >= threshold`)
- Lifecycle badge type-safety (`'active' | 'closed' | 'halted'` enum; unknown strings fall back to `'closed'`)
- `selectedRunId` pass-through (verbatim; consumer reconciles)
- IPC channel registration intent (`liveUpdateChannel` default `'history.run.progress'`)
- JSON-cloneability

For F-034:
- Read-only field rendering (descriptor has no edit handlers)
- Audit-chain badge type-safety (`'green' | 'yellow' | 'red'` enum)
- **Explicit-placeholder discipline** (`INFO_PANEL_PLACEHOLDER = '—'` for missing source data; NEVER silent zeros per `kit:rules/verification-protocol.md` Rule 4 ACTUAL BEFORE PRESENT)
- Chain-red-masks-cost discipline (data-integrity warning)
- Missing-cost-emits-placeholder discipline (per `kit:rules/degradation-fallback-policy.md` Rule 3 Context Gap)
- Default `isOpen: true` (panel default-open)
- Closed-only `retroSummary` enforcement (active runs silently drop retro per F-014)
- JSON-cloneability

### Six deferrals to M5 integration wave (F-033)

1. Actual DOM render of the rail (react-virtuoso / tanstack/react-virtual / hand-rolled) — belongs in the M5 integration consumer.
2. On-disk read of `<state-dir>/runs/` + `<state-dir>/archive/runs/<YYYY>/<MM>/` — caller resolves entries via F-008 atomic-read helpers.
3. F-007 IPC handler runtime wiring for live updates — channel name + threshold declaration is v1 contract; ≤2s SLA observed at consumer wave's e2e harness.
4. Full-text search / filter — v1.5 per ledger out-of-scope-notes.
5. History export/import — v1.5 per ledger out-of-scope-notes.
6. Server-synced multi-device history — out of v1 per ledger out-of-scope-notes.

### Seven deferrals to M5 integration wave (F-034)

1. Actual DOM render of the panel — belongs in the M5 integration consumer.
2. F-007 IPC subscription wiring for live updates per cycle.
3. "Re-verify chain on button" runtime trigger — wires F-015 audit-chain re-verification via the F-007 IPC bridge.
4. F-019 cost-ledger live sub-total streaming.
5. Live trace timeline + step-by-step replay scrubber — M11 scope (F-088..F-092 per ledger out-of-scope-notes).
6. Cross-run aggregate stats — v1.5 per ledger out-of-scope-notes.
7. Editable run metadata fields — out of scope per ledger out-of-scope-notes (info panel is read-only by design).

## New ledger-deferral idiom corollary registered

**"explicit-placeholder discipline"** — corollary to F-032's parent **"descriptor-as-data, instantiation-deferred"** idiom.

Where the parent idiom is about WHAT to ship (plain object vs. instantiated subsystem), the corollary is about HOW to handle missing inputs in those plain-object descriptors:

| Property | Parent idiom (F-032) | Corollary (F-034) |
|---|---|---|
| Concern | What does the descriptor produce? | What does the descriptor produce when source data is missing? |
| Mechanism | Plain object; consumer instantiates | Typed placeholder constant; readers detect by string-equality |
| Mechanizes | F-004 "browser project runtime wiring deferred" | `kit:rules/verification-protocol.md` Rule 4 ACTUAL BEFORE PRESENT |
| Distinguishes | Descriptor (data) from runtime (foreign-constructor consumer) | "Missing data" (placeholder) from "actual zero" (round-trip) |
| Pairs with | F-007 IPC contract scaffold | `kit:rules/degradation-fallback-policy.md` Rule 3 Context Gap |

Future Electron-bound M5 features displaying source-dependent data (F-035 model-picker, F-036 personality, F-037 system-message, F-042 notifications) should cite this corollary alongside F-032's parent idiom.

Distinct from prior idioms in the project lexicon:

| Idiom | First seen | What it's about |
|---|---|---|
| config-present, runtime-deferred | F-004 (wave-14) | Config file lands; runtime activation deferred |
| stub-body-vs-deferred-real-SDK | F-010, F-011 (wave-15) | Full contract behavior with deterministic stub yields; real SDK swap deferred |
| minimum-viable-stub-with-deterministic-stdout | F-029 (wave-17) | Stubs return 0 + emit deterministic line for downstream verification |
| in-process primitive only | F-031 (wave-18) | Orchestration spine ships, OS-process shell deferred |
| descriptor-as-data, instantiation-deferred | F-032 (wave-18) | Plain-object descriptor; consumer instantiates the foreign-constructor |
| **explicit-placeholder discipline (corollary)** | **F-034 (wave-19)** | **Typed placeholder constant for missing source data; readers detect by string-equality** |

## Cross-feature composition

| Composes against | LOCKED state | Role |
|---|---|---|
| F-032 window | GREEN (wave-018/lane-c) | Sibling M5 surface; the `MainWindowDescriptor.ipcChannels` array will eventually include the rail's `liveUpdateChannel` once the consumer wires it in. |
| F-007 ipc-contract-scaffold | LOCKED (wave-13/lane-b) | `liveUpdateChannel` types as string for forward-compat with future `IpcInvokeMap` entries. |
| F-008 local-storage-layout | LOCKED (wave-12/lane-d) | Caller reads `<state-dir>/runs/` + archive directories via F-008 atomic-read helpers and passes parsed `HistoryEntry[]`. |
| F-001 engine-bootstrap-loop | LOCKED (wave-11/lane-b), F-019 cost-ledger | Supply data each row + each panel field displays. |
| F-002 per-agent identity | LOCKED (wave-12) | Supplies `agentLabel` for both rail rows and the info-panel. |
| F-014 pre-close retro signal | LOCKED (wave-13) | Supplies `retroSummary` for closed runs in the info-panel. |
| F-015 hash-chained audit log | LOCKED (wave-13) | Supplies `auditChainStatus`; F-034's red-masks-cost discipline preserves data-integrity warning semantics. |
| F-019 cost-ledger | LOCKED (wave-13) | Supplies per-tool/model `CostBreakdown[]`. |
| F-020 kill-switch | LOCKED (wave-13) | Supplies `killSwitchActive`. |
| F-033 ↔ F-034 | Paired in same lane | Info panel reads `selectedRunId`; rail writes it. |
| F-035..F-043 | RED (M5 siblings) | Future M5 features compose against `HistoryPaneDescriptor` + `InfoPanelDescriptor` unchanged. |

## Cross-lane staging-race observation

Lane A's RED commit (`fdd4a95`) landed clean — first clean RED commit observed in the repo since wave-9. The combined `git add <paths>` then `pnpm test` then `git commit` single-bash invocation was used (the wave-017 mitigation pattern). Sibling lanes had working-tree modifications (F-205 + F-139 + F-140 + .claude/ + backend.ts) at staging time; none were swept into this lane's commit. This suggests the tactical mitigation IS effective when:

1. Lane scope is genuinely disjoint (Lane A's files: `tests/unit/F-033-*` + `tests/unit/F-034-*` + `docs/03-feature-catalog/M5-*/F-033-*` + `docs/03-feature-catalog/M5-*/F-034-*` + `docs/09-examples-proof/F-033/*` + `docs/09-examples-proof/F-034/*` — no overlap with sibling lanes)
2. Each lane uses combined `git add && git commit` single-bash to minimize the race window
3. Pre-commit hook scope-restriction matches the explicit `git add` set when scope is disjoint

But Lane B's wave-018 sighting #18 + Lane C's wave-018 sighting #20 had broader scope overlap (sibling-lane modifications to files this lane was also touching), so the chronic pattern remains for those cases. Council retro at wave-19 close should revisit the strategic-mitigation candidates (per-lane branches, hook scope-restriction, scope-manifest) — but Lane A's clean RED commit suggests they may not be necessary IF lane scope is genuinely disjoint AND combined-bash is used.

The GREEN commit will be attempted with the same single-bash combined pattern; outcome documented post-commit.

## Push status

Push at end of lane authorized for this loop session per user directive 2026-05-07. Per `non-negotiable-rules.md`, no destructive git ops; selective `git add <paths>` only; `git status --short` audit before each commit. Per CLAUDE.md user directive 2026-05-07 explicitly noted in this loop's brief: do NOT use `git reset` (any flavor) for staging-race recovery; use `git restore --staged` or selective add instead.

## Reporting metric

- F-033 GREEN: 6/6 PASS
- F-034 GREEN: 6/6 PASS
- M5 desktop-shell milestone continues (11R+1G -> 9R+3G; second + third M5 feature transitions)
- TOTAL: 147+97R+8G+24L -> 147+95R+10G+24L
- 31st + 32nd feature transitions RED -> GREEN in the repo (sequential count after F-032 = 30th in wave-18/lane-c; sibling wave-19/lane-b F-139+F-140 are NEW additions, separate accounting)
- Second + third feature in `packages/desktop-shell/` after F-032 (workspace populated wave-018/lane-c)
- New design corollary registered: "explicit-placeholder discipline" (F-034) — corollary to F-032's "descriptor-as-data, instantiation-deferred" idiom
- First clean RED commit observed in the repo since wave-9 (Lane A scope was genuinely disjoint from sibling lanes)

## Commits

| # | Subject | SHA | Status |
|---|---|---|---|
| 1 | `test(F-033,F-034): RED -- chat-history-pane + info-panel structural scenarios + ledger flips` | `fdd4a95` | landed clean — no cross-lane staging-race observed (this lane's clean RED commit was the "first since wave-9") |
| 2 | `feat(F-033,F-034): GREEN -- buildHistoryPane + buildInfoPanel descriptors + ledger flips + roadmap + confidence-ledger + lane-a summary` | `2bdfcac` | landed 10 files; **roadmap.md updates absorbed by sibling Lane D's earlier commit `7be3b24` (subject "docs(wave-019/lane-d): QG7 Copilot CLI multi-model design review of composition spine")** — same chronic cross-lane staging-race pattern, **sighting #21+**. Substance preserved (roadmap.md HAS my F-033+F-034 row updates, M5 row 9R+3G, TOTAL 95R+10G+24L, wave-019/lane-a transition note); credit attribution on roadmap.md corrupted; rest of GREEN scope (10 files) credited to this lane's commit. Per `non-negotiable-rules.md`: NO destructive git ops. |

## Cross-lane staging-race sighting #21+

Observed during this lane's GREEN commit attempt. The roadmap.md edits this lane authored (F-033 row 🔴 -> 🟢 + F-034 row 🔴 -> 🟢 + M5 row 11R+1G+0L -> 9R+3G+0L + TOTAL 147+97R+8G+24L -> 147+95R+10G+24L + wave-019/lane-a transition note inserted before wave-019/lane-b note) were absorbed by sibling Lane D's commit `7be3b24` (subject "docs(wave-019/lane-d): QG7 Copilot CLI multi-model design review of composition spine"). Lane D's commit landed BEFORE this lane's GREEN commit attempt; Lane D's `git add` set apparently included broader-scope working-tree modifications including roadmap.md.

Pattern repeats from wave-018 sightings #18 + #20 + earlier waves. Tactical mitigation (combined `git add && git commit` single-bash) was used here, but did NOT prevent the issue because Lane D committed FIRST while this lane was still authoring; Lane D had the staged roadmap.md modifications at the moment of its commit.

Per user directive 2026-05-07: NO `git reset` (any flavor); fix-forward via documentation in this summary + the wave-019/lane-a transition note in roadmap.md (which IS in HEAD via Lane D's commit). Credit attribution on roadmap.md corrupted; substance preserved.

**Strategic mitigation candidates** (carried over from wave-017+18 retros + Lane B's wave-018 #18 + Lane C's wave-018 #20 + this Lane A #21+):

(a) Per-lane branches when concurrent lane count >= 3 — author lane's work on a private branch + merge at end (preserves credit attribution mechanically)
(b) Pre-commit-hook scope-restriction to `git diff --cached --name-only` only (reject any modification to files not in the cached diff) — would have prevented Lane D from committing roadmap.md unless Lane D explicitly staged it
(c) Per-feature scope manifest at `.mad/wave-N/lane-X/scope.txt` with hook-enforced reject — declares lane scope upfront; pre-commit rejects if commit touches files outside scope

**Council retro at wave-19 close should escalate from tactical (combined-bash) to strategic mitigation.** The chronic pattern across waves 9-19 (sightings #14-#21+) suggests the tactical mitigation has reached its ceiling; strategic intervention is the next move.
