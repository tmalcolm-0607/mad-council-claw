---
artifact-class: council-review
feature-id: F-008
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-012 / lane-d
---

# F-008 local-storage-layout — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 90 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 75 |
| architect-lens | Architect | APPROVE | 88 |

Median confidence: 88

## Implementation reviewed

- `packages/engine-core/src/storage.ts` — 119 LOC; `StorageLayout` interface + `getStorageLayout(rootOverride?)` (pure path computation) + `ensureStorageLayout(layout)` (idempotent recursive mkdir) + `atomicWriteJson(path, content)` (write-temp-then-rename per `concurrency-safety.md` §2) + `readJson<T>(path)` typed helper. Split out from monolithic `index.ts` in wave-011/lane-a.
- `tests/node/F-008-local-storage-layout.test.ts` — 6 acceptance scenarios; all PASS per `docs/09-examples-proof/F-008/green-test-output.txt` and re-confirmed at review time (6/6 PASS in 35ms; full vitest run 13/13 PASS across F-002 + F-006 + F-008). Tests run under the `node` project (not `unit`) because they touch real filesystem under `os.tmpdir()`.
- Commit history per ledger status-history: F-008 RED at wave-002 / lane-b (initial ledger); RED test at wave-010 / lane-d (`tests/node/F-008-local-storage-layout.test.ts` — 6 acceptance scenarios fail with `TypeError: getStorageLayout is not a function`); F-008 GREEN at wave-010 / lane-d (impl ~150 LOC F-008 region, 6/6 PASS, full unit suite 39/39 GREEN-feature tests still passing); engine-core split (Lane A wave-011) carved `storage.ts` out of `index.ts` with no behavior change.

## Advocate lens

**Verdict: APPROVE (confidence 90)**

- Implementation is minimal and correct per `minimum-change.md`: ~119 LOC delivers the entire on-disk layout primitive (5 paths + settings file) plus the atomic-write helper that every mutable JSON file in the engine must use. No behavior beyond what the ledger contract describes.
- All 6 acceptance scenarios PASS:
  - **Scenario 1** (layout shape): `getStorageLayout(rootOverride)` returns 5 paths anchored under root: `root` / `sessions` / `skills` / `automations` / `audit` + `settingsFile`. Verified.
  - **Scenario 2** (idempotent mkdir): `ensureStorageLayout(layout)` creates all dirs on first call, no-throws on second call. `settingsFile` is intentionally NOT created by `ensureStorageLayout` — it's a file owned by `atomicWriteJson`'s lifecycle.
  - **Scenario 3** (round-trip): `atomicWriteJson` + `readJson` round-trip with deeply-nested content survives intact (deeply nested objects, arrays, primitives — all preserved).
  - **Scenario 4** (no .tmp orphan): after a successful `atomicWriteJson`, no `<path>.tmp` file remains. The `renameSync` consumes the temp file atomically per kit's `concurrency-safety.md` §2.
  - **Scenario 5** (replace prior content cleanly): existing file is replaced atomically; readers always observe a fully-formed JSON document; no half-write window.
  - **Scenario 6** (default root): `getStorageLayout()` without override anchors to `~/.mad-council-claw` under the operator's home; path-shape check only — no filesystem touch in the operator's home during the unit run.
- The test suite uses `mkdtempSync` + `os.tmpdir()` per test — every test gets an isolated root, avoiding cross-test state leaks AND avoiding perturbation of the operator's actual `~/.mad-council-claw/`. Cleanup via `rmSync(tempRoot, { recursive: true, force: true })` in `afterEach`.
- Surface trace per ledger maps cleanly: `cp:userData layout` (clawpilot Electron `app.getPath('userData')` pattern adapted to a Node-only `homedir()` baseline) + `ce:FR-AUDIT-001` (hash-chained audit log lives at `runs/<run_id>/audit.ndjson` — F-001/F-008 integration is the per-run subdir layer) + `kit:rules/concurrency-safety.md` (the §2 atomic write-temp-then-rename pattern verbatim).

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 75)**

- F-008 implements the **static layout primitive** (`sessions / skills / automations / audit + settingsFile`) — but the ledger §Behavior contract describes a **richer per-run subdirectory tree**: `runs/<run_id>/` (per-run audit log + cost ledger + manifest), `verdicts/`, `kill-switch.json`, `automations/`. This is the wave-010 lane-d brief's narrowing (acknowledged in the F-008 ledger §Implementation notes as "Brief-vs-ledger scope reconciliation"):
  - `runs/<run_id>/` per-run subdirectory creation lands in F-001 / F-008 integration (currently un-scoped follow-on).
  - `kill-switch.json` lands alongside F-020 (already GREEN — kill-switch reads/writes via its own primitive in `killswitch.ts`; the path-anchoring step is the integration).
  - `verdicts/` lands alongside the governance triad (F-022 + F-014/F-015 already GREEN; the verdict directory creation is the integration).
- All four deferrals are honest per `no-silent-deferrals.md` — surfaced in ledger §Implementation notes + ledger §out-of-scope-notes — but a reader could mistake "F-008 LOCKED" for "the on-disk layout matches the ledger's behavior contract" — which is true only for the static-layout primitive, NOT the per-run / per-verdict subdirectories.
- The startup sweep of orphaned `<path>.tmp` files (per `concurrency-safety.md` §Edge cases) is NOT yet implemented. If the engine crashes between step 2 (write `.tmp`) and step 3 (rename), the `.tmp` orphans on disk forever. Tracked in ledger §out-of-scope; small follow-on flip.
- The atomic-write helper itself is the building block, NOT a race-test harness. The test suite verifies single-writer atomicity; it does NOT exercise the concurrent-writer last-write-wins scenario from `concurrency-safety.md` §4 (digest.json-class files). Acceptable for v1 because the engine has no current concurrent writers; the harness is needed when M3 cron / multi-instance lands.
- The encrypted-at-rest concern (M8 / F-070-F-071) is explicitly out-of-scope here — the ledger contracts the directory layout + atomic write helpers, NOT the encryption layer. Reader who expects "F-008 LOCKED → my settings.json is encrypted" will be surprised; the ledger §out-of-scope-notes makes this explicit.
- Suggestion (NON-BLOCKING per `no-silent-deferrals.md`): track an explicit "storage-layout-per-run-integration" follow-on F-NNN that creates `runs/<run_id>/` on engine boot via F-001 + F-008 composition. Pairs with the kill-switch + verdicts + audit log per-run subdirectory layer.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `packages/engine-core/src/storage.ts` lines 1-119 and `tests/node/F-008-local-storage-layout.test.ts` lines 1-164 directly; the implementation matches the contract; the atomic-write helper writes to `<path>.tmp` first then renames (lines 107-111 of storage.ts); the `mkdtempSync` test isolation is correct.

## Architect lens

**Verdict: APPROVE (confidence 88)**

- File-split posture: `storage.ts` lives in `packages/engine-core/src/` per the wave-011/lane-a engine-core split. Clean module boundary; the `StorageLayout`/`getStorageLayout`/`ensureStorageLayout`/`atomicWriteJson`/`readJson` surface re-exports through the barrel. No circular dep, no shared mutable state, no cross-feature imports — F-008 is a foundational primitive that every other feature can depend on.
- API surface: `StorageLayout` is a pure value (5 paths + settings file); `getStorageLayout` is a pure function (no FS side-effects); `ensureStorageLayout` and `atomicWriteJson` are the only side-effecting calls — and the latter is the single canonical write path for mutable JSON state. Architecturally clean: layout-shape and write-discipline are separated.
- Atomic-write contract: `atomicWriteJson(path, content)` writes pretty-printed JSON (2-space indent) to `<path>.tmp` via `writeFileSync`, then `renameSync` to the final path. `renameSync` is atomic on POSIX + Windows NTFS per `concurrency-safety.md` §2; readers either see the pre-update file or the post-update file, never a half-written one. `.tmp` orphan on writer crash is documented (startup sweep is the follow-on).
- Hard deps per ledger: NONE (foundational). Soft deps on F-001 (engine consumes layout) + F-006 (logger writes here). The current implementation is correctly dependency-free at compile-time — pure primitive that other features layer on top.
- The default `~/.mad-council-claw` root is computed via `os.homedir()` + `path.join`; rooted aliases `_existsSync` / `_mkdirSync` / `_readFileSync` / `_renameSync` / `_writeFileSync` / `_join` / `_homedir` are imported once and used internally. This pattern (rooted aliases) is repeated across the engine-core split files (cf. `bootstrap.ts`, `audit.ts`); architectural consistency is preserved per `verification-protocol.md` Rule 3 (MATCH EXISTING STYLE).
- Test placement: `tests/node/F-008-local-storage-layout.test.ts` — F-008 is the FIRST feature whose tests live under the `node` test runner project (not `unit`). The split is correct because F-008 touches real filesystem; running it under `unit` would either require mocking FS (loss of fidelity) or accept slower test runtimes (cross-runner pollution). Architecturally sound.
- The settings.json file's lifecycle is owned by `atomicWriteJson`, NOT `ensureStorageLayout`. Test scenario 2 verifies this (`expect(existsSync(layout.settingsFile)).toBe(false)` after `ensureStorageLayout`). This separation is correct: directory creation is a tree-shape concern; file writes are content-lifecycle concerns. Forward-compatible: future readers/writers don't need to coordinate creation across both helpers.

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | Per-run subdirectory creation (`runs/<run_id>/`) deferred to F-001/F-008 integration follow-on. The static layout primitive is locked; per-run dynamic shape is not. | Accept; ledger §Implementation notes makes the brief-vs-ledger scope reconciliation explicit. Backlog item: track "storage-layout-per-run-integration" F-NNN follow-on. |
| F2 | MINOR | Startup sweep of orphaned `<path>.tmp` files (per `concurrency-safety.md` §Edge cases) NOT yet implemented. Writer crash between step 2 and step 3 leaves orphan on disk. | Accept; tracked in ledger §out-of-scope; small follow-on flip. |
| F3 | MINOR | Concurrent writer race testing harness NOT included; the atomic helper itself is the building block, not the harness. Last-write-wins semantics for digest.json-class files (per `concurrency-safety.md` §4) untested at this layer. | Accept; harness needed when M3 cron / multi-instance lands; v1 single-writer model OK. |
| F4 | MINOR | Encrypted-at-rest storage of secrets/keys explicitly out-of-scope (M8 / F-070-F-071). A reader could mistake "F-008 LOCKED" for "all writes encrypted" — they are NOT. | Accept; ledger §out-of-scope-notes makes this explicit. |
| F5 | PRAISE | Test isolation via `mkdtempSync` + `os.tmpdir()` + `afterEach rmSync` — every test runs against its own root; no cross-test state leaks; no perturbation of operator's `~/.mad-council-claw/`. | Keep. |
| F6 | PRAISE | Layout-shape vs file-content lifecycle separation: `ensureStorageLayout` creates directories; `atomicWriteJson` owns file content. Architecturally clean. | Keep. |
| F7 | PRAISE | First feature to use the `tests/node/` runner project — sets the precedent for FS-touching tests cleanly without polluting the unit suite. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 88).

F-008 minimal-contract (static layout + atomic-write helpers) is implemented correctly; all 6 acceptance scenarios pass per the recorded green-test-output proof; no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-008 ledger frontmatter (`LOCKED if GREEN AND reviews/F-008-local-storage-layout-review.md exists with verdict: ACCEPT`).

The MINOR findings are honest scope-narrowing notes per `no-silent-deferrals.md` — they are surfaced in this review (and in the F-008 ledger §Implementation notes + §out-of-scope-notes), not silently elided. Future deeper integration work (per-run subdirectory creation; .tmp sweep on startup; concurrent-writer race harness; encrypted-at-rest) is scoped to future F-NNNs, not a re-scoping of F-008's contract.

F-008 transitions GREEN → LOCKED.

## Cross-references

- Ledger: `docs/03-feature-catalog/M0-bootstrap/F-008-local-storage-layout.md`
- Source: `packages/engine-core/src/storage.ts` (split from `index.ts` in wave-011/lane-a)
- Tests: `tests/node/F-008-local-storage-layout.test.ts` (6/6 PASS)
- GREEN proof: `docs/09-examples-proof/F-008/{red-test-output.txt,green-test-output.txt}` (per ledger status-history)
- GREEN transition: ledger status-history wave-010 / lane-d; impl ~150 LOC F-008 region appended to `index.ts`
- Engine-core split: wave-011 / lane-a (no behavior change; pure refactor; verified by 75/75 PASS post-split)
- Review verdict envelope: per `docs/05-design-reviews/README.md` (APPROVE / APPROVE-WITH-SUGGESTIONS / WAIT-FOR-AUTHOR / REJECT)
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle (Reviewer summary table + Median confidence + Decision)
- Concurrency contract: `.claude/rules/concurrency-safety.md` §2 (atomic write-temp-then-rename) + §4 (last-write-wins for mutable shared state)
- Precedent: `docs/05-design-reviews/council-reviews/F-001-engine-bootstrap-loop-review.md` (first LOCKED transition; wave-011 / lane-b); `F-002-per-agent-identity-runid-review.md` + `F-006-logging-pipeline-review.md` (wave-012 / lane-d siblings)
