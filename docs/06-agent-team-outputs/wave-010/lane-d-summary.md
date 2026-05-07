---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-010 / lane-d)
wave: wave-010
lane: lane-d
topic: F-008 local-storage-layout RED → GREEN
date: 2026-05-07
status: complete
---

# Wave 10 / Lane D — F-008 local-storage-layout RED → GREEN

## Scope

Land the GREEN flip for F-008 local-storage-layout per
`docs/03-feature-catalog/M0-bootstrap/F-008-local-storage-layout.md` +
the wave-010 lane-d brief. Surface delivered:

- `StorageLayout` interface — `{root, sessions, skills, automations, audit, settingsFile}`.
- `getStorageLayout(rootOverride?)` — pure path computation; defaults to `~/.mad-council-claw`.
- `ensureStorageLayout(layout)` — idempotent recursive `mkdirSync` over root + 4 subdirs.
- `atomicWriteJson(path, content)` — write-temp-then-rename per kit's `concurrency-safety.md` §2.
- `readJson<T>(path)` — typed JSON read helper.

## What was created / modified

| Group | Path | Type |
|---|---|---|
| RED test | `tests/node/F-008-local-storage-layout.test.ts` | new (6 acceptance scenarios) |
| RED proof | `docs/09-examples-proof/F-008/red-test-output.txt` | new |
| GREEN impl | `packages/engine-core/src/index.ts` | modified (+150 LOC F-008 region append) |
| GREEN proof | `docs/09-examples-proof/F-008/green-test-output.txt` | new |
| Ledger flip | `docs/03-feature-catalog/M0-bootstrap/F-008-local-storage-layout.md` | modified (status red → green; status-history; test-files; implementation notes) |
| Roadmap flip | `roadmap.md` | modified (F-008 row 🔴 → 🟢; M0 RED/GREEN counts; TOTAL row) |
| Confidence ledger | `docs/11-loop-state/confidence-ledger.md` | modified (Wave 10 lane-d section + 4 entries) |
| This summary | `docs/06-agent-team-outputs/wave-010/lane-d-summary.md` | new |

## Acceptance scenarios

| # | Scenario | Verifies |
|---|---|---|
| 1 | `getStorageLayout(rootOverride)` returns 5 paths anchored under the override | layout shape contract |
| 2 | `ensureStorageLayout(layout)` creates root + 4 subdirs; idempotent on re-run | mkdir-recursive + existing-dir tolerance; settingsFile NOT created (file lifecycle owned by atomicWriteJson) |
| 3 | `atomicWriteJson` + `readJson` round-trip preserves deeply-nested content | JSON serialization fidelity |
| 4 | After successful `atomicWriteJson`, no `<path>.tmp` orphan remains | rename consumed the temp file |
| 5 | Atomic write replaces a prior file without producing a half-read | rename-atomicity guarantee from `concurrency-safety.md` §2 |
| 6 | `getStorageLayout()` without override defaults to `~/.mad-council-claw` (path-shape only) | default-root contract; no operator-home side effects during unit run |

All 6 PASS. RED state: 6/6 fail with `TypeError: getStorageLayout is not a function` (recorded at `docs/09-examples-proof/F-008/red-test-output.txt`).

## Test routing

The brief re-routed F-008 tests from `tests/unit/` (happy-dom env) to
`tests/node/` because the impl uses `node:fs` / `node:os` — happy-dom's
DOM environment doesn't expose Node fs primitives. F-008 is the FIRST
F-NNN to live in the node project. The vitest config already declared
the node project (lines 14-21 of `vitest.config.ts`); no config change
was required.

Test isolation: each test gets its own `mkdtempSync(join(tmpdir(), ...))`
root and `rmSync(..., recursive: true)` in `afterEach`, so concurrent
test runs and the operator's actual `~/.mad-council-claw/` are
untouched.

## Brief-vs-ledger scope reconciliation (anomaly + decision)

The wave-002 / lane-b ledger §Behavior contract describes a richer
subdirectory tree (`runs/<run_id>/` per-run dirs + `verdicts/` +
`kill-switch.json` at root). The wave-010 lane-d brief scoped the
flip to the static layout primitives (4 subdirs +
`settings.json` + atomic-write helper).

Per `rules/no-silent-deferrals.md`: surfaced explicitly in:
- F-008 ledger §Implementation notes (4 explicit out-of-scope items + follow-on owners).
- This summary (this section).
- Confidence ledger entry `Lane-D-w10-brief-vs-ledger-scope-divergence` (MEDIUM).

This is the THIRD sighting of the brief-narrower-than-ledger pattern in
the loop (after wave-009 lane-a F-006 four-vs-six log levels +
wave-009 lane-c F-018 trigger-name reconciliation). Wave-10
loop-improvement candidate: **brief-generation should diff against the
live ledger contract and FLAG divergences in the brief itself.** Three
sightings is the threshold for codifying the discipline as a
brief-generation pre-flight check (per `verification-protocol.md`
FETCH BEFORE CITE).

## Cross-lane staging discipline (HIGH-priority lesson applied)

Wave-009 surfaced two anomaly entries on cross-lane git races:
- `Lane-B-w9-cross-lane-race-credit-misattribution` (F-016 RED + GREEN absorbed by sibling lanes' commits).
- `Lane-C-w9-staging-race-with-sibling-lanes` (F-018 same fate).

Lane D applied the proposed remediation: **explicit per-lane staging
discipline.** Concretely:

1. Pre-RED-commit: `git status --short` showed Lane D files + 3 sibling
   lanes' RED stubs (F-019, F-020 — staged; F-022 — untracked).
2. Lane D ran `git reset HEAD <foreign-files>` to unstage the sibling
   files, leaving them as untracked-in-working-tree-only.
3. Lane D's RED commit `git add <Lane-D-paths-only>` then committed.
4. Same discipline at GREEN: only Lane D paths staged.
5. Each commit's body explicitly cites `rules/scope-discipline.md` and
   the wave-9 anomaly entries.

Outcome: clean per-lane attribution; no cross-lane absorption; no
commit-message misattribution. Validates the wave-009 lane-c
proposal that explicit per-lane staging is sufficient at the
4-lane scale when EACH lane is disciplined — no per-lane branches
or wave-coordinator required (yet).

The proposal `lane-c-w9-multi-lane-staging-discipline-pattern`'s
options (a) per-lane branches, (b) wave-coordinator, (c) git-staging-lock
are escalation paths if the per-lane discipline ever degrades; for now
(c-light: per-lane reset-then-add) suffices.

## Confidence

HIGH for the GREEN flip + the four confidence-ledger entries. Surface
shape, acceptance scenarios, and the kit's `concurrency-safety.md` §2
atomic-write pattern are canonical references. The 6 acceptance
scenarios cover the contract end-to-end.

MEDIUM only on `Lane-D-w10-brief-vs-ledger-scope-divergence` — the
brief's narrower scope was the right call (richer subdirs need their
feature flips first), but it widens the gap between the wave-002 ledger
and the live impl. Closure path: per-run subdir creation lands as
F-001/F-008 integration flip; kill-switch + verdicts dirs land
alongside F-020 and the governance triad. No silent deferral.

## Quality-gate checklist

- [x] QG1 — net-new — 1 NEW test file + 2 NEW proof files + 1 NEW summary + 1 NEW wave-010 dir
- [x] QG2 — sources cited — F-008 ledger + concurrency-safety.md §2 + wave-010 lane-d brief
- [x] QG3 — touches Goal G37 (immediate working product) — atomic-write helper is foundational for F-006 sink, F-015 audit, F-019 cost ledger, F-020 kill-switch
- [x] QG4 — backlog item processed — F-008 final M0-bootstrap RED → GREEN
- [x] QG5 — loop-improvement proposal — see "Brief-vs-ledger" section: third sighting → codify pre-flight diff
- [x] QG6 — multi-lane fan-out — wave-010 has multiple lanes (this is lane-d)
- [ ] QG7 — Copilot CLI design review — N/A this lane (in-memory primitive + standard fs ops)
- [x] QG8 — Microsoft tools used — N/A direct
- [x] QG9 — open questions captured — brief-vs-ledger scope divergence + per-run subdir deferral

## Reproduction

```bash
cd C:/Users/tonym/Repos/mad-council-claw
pnpm test:node                          # F-008 6/6 PASS
pnpm test:unit                          # 39/39 GREEN-feature tests PASS (F-001/F-002/F-006/F-014/F-015/F-016/F-018)
cat docs/09-examples-proof/F-008/green-test-output.txt
git log --oneline -5                    # 5 commits this lane: RED + GREEN-impl + ledger-flip + roadmap-flip + summary
```

## Push

Pending — `git push` per `rules/non-negotiable-rules.md` requires explicit user request.
Lane D's commits are local; push only on user instruction.
