---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-008 / lane-a)
wave: wave-008
lane: lane-a
topic: F-014-pre-close-retro-signal-RED-GREEN
date: 2026-05-06
status: complete
---

# Wave 8 / Lane A — F-014 pre-close-retro-signal RED → GREEN

## Scope

Third feature transition RED → GREEN in the repo (after F-001 wave-005, F-002 wave-006). First M2 (governance triad) feature to flip GREEN. The behavior-contract surface lands the in-memory pre-close retro discipline that every run lifecycle MUST satisfy before transitioning `closing → closed`.

Wave-008 ran with two lanes in parallel:
- **Lane A (this lane)**: F-014 pre-close-retro-signal (M2)
- **Lane B**: F-015 hash-chained-audit-log (M2)

Both lanes modify `packages/engine-core/src/index.ts` in disjoint append-only zones. Coordination resolved via the wave-008 multi-lane append convention (no shared-line conflicts; type-name collision avoided by Lane B's `AuditEntry` → `AuditLogEntry` rename — see Lane B's summary).

## What was created / modified

| Group | Path | Type | Count |
|---|---|---|---|
| RED test stub | `tests/unit/F-014-pre-close-retro-signal.test.ts` | new | 1 |
| GREEN impl additions | `packages/engine-core/src/index.ts` | modified (~180 LOC added in F-014 region) | 1 |
| Ledger transition | `docs/03-feature-catalog/M2-governance-triad/F-014-pre-close-retro-signal.md` | modified (status red→green; status-history; test-files; wire-up; impl notes) | 1 |
| Roadmap update | `roadmap.md` | modified (M2 row 8R+1G→7R+2G; TOTAL row 33R+3G→32R+4G; F-014 detail row → 🟢 GREEN) | 1 |
| Confidence-ledger entries | `docs/11-loop-state/confidence-ledger.md` | modified (4 new wave-008 lane-a entries) | 1 |
| Physical proof | `docs/09-examples-proof/F-014/physical-proof.md` | new | 1 |
| Vitest output capture | `docs/09-examples-proof/F-014/red-test-output.txt` + `green-test-output.txt` | new | 2 |
| This summary | `docs/06-agent-team-outputs/wave-008/lane-a-summary.md` | new | 1 |
| **Total touched** | | | **9 artifacts** |

## Commit chain (5 atomic commits)

| # | SHA | Subject | Why split |
|---|---|---|---|
| 1 | `d896ecb` | `test(F-014): RED test stub for pre-close-retro-signal` | RED-before-GREEN per wave-5 retro proposal — captures real before/after pair |
| 2 | `ba54036` | `feat(M2): F-014 pre-close-retro-signal GREEN — closeSession + RetroSignal + RetroMissingError` | GREEN impl scoped to F-014 only (Lane B's F-015 hunks stripped pre-commit per `rules/scope-discipline.md`) |
| 3 | `5b98d29` | `docs(catalog): F-014 ledger transition RED → GREEN` | Ledger frontmatter + body update — separate concern from impl |
| 4 | `4404cf8` | `docs(roadmap): F-014 GREEN; M2 7 RED + 2 GREEN; confidence-ledger wave-008 lane-a entries` | Roadmap + confidence-ledger together — both are loop-state truth |
| 5 | `2e1398b` | `docs(examples-proof): F-014 GREEN — vitest output + physical-proof` | Audit-trail anchor — separate so future audits cite proof commit explicitly |

Each commit body uses the chain-of-thought block (WHY / SOURCE / CONFIDENCE / WAVE / Gate Results) per the wave-005 / wave-006 commit pattern.

## Vitest output

```
RUN  v2.1.9 C:/Users/tonym/Repos/mad-council-claw

✓ tests/unit/F-014-pre-close-retro-signal.test.ts (8 tests) 7ms

Test Files  1 passed (1)
     Tests  8 passed (8)
  Duration  742ms
```

Full unit suite (with Lane B's F-015 also present): **18/18 PASS** (4 test files).

## RED→GREEN transition

| Phase | State | Test result |
|---|---|---|
| RED (commit d896ecb) | `closeSession` not exported; `RetroSignal` type absent; `RetroMissingError` class absent | 7/8 fail with `TypeError: closeSession is not a function`; 1 spurious pass on a no-throw assertion path |
| GREEN (commit ba54036) | `closeSession` + `RetroSignal` + `RetroMissingError` + `RetroOutcome` exported from `packages/engine-core/src/index.ts` (~180 LOC F-014 region) | 8/8 PASS |

Output captured: `docs/09-examples-proof/F-014/{red,green}-test-output.txt`.

## Surface inventory (the F-014 GREEN region)

- `RetroOutcome` type — `'completed' | 'halted_by_kill_switch' | 'halted_by_failure_pattern' | 'halted_by_tool_quota'`
- `RetroSignal` interface — 5-axis Likert (each int 1..5) + 7 pattern prose fields + outcome + optional 64-hex `trigger_evidence_sha256`
- `RetroMissingError` class extending `Error`; `.missingFields: string[]` enumerates failed fields
- `LIKERT_AXES` / `PATTERN_FIELDS` / `HALTED_OUTCOMES` const arrays for validation
- `closeSession(retro)` — full validation pipeline:
  - retro non-null
  - 5 Likert axes present, integer, 1..5
  - 7 pattern fields present, non-empty string
  - outcome recognized
  - halted-by carve-out: trigger_evidence_sha256 required + 64-char lowercase hex when outcome ∈ halted_by_*

## Anomalies / context gaps

### A1 — Prompt named the work F-003-pre-close-signal-capture; the actual ledger ID is F-014

**Severity**: HIGH (load-bearing for catalog integrity).

The wave-008 / lane-a brief asked Lane A to flip `F-003-pre-close-signal-capture` RED → GREEN, with a behavior contract describing `closeSession`, 5-axis Likert, 7 pattern fields, halted-by carve-out. Reality:

- **F-003 in M0 is `repo-scaffolding`** (RED, separate ledger at `docs/03-feature-catalog/M0-bootstrap/F-003-repo-scaffolding.md`).
- **The behavior contract the prompt described matches F-014 verbatim** — F-014 is M2's `pre-close-retro-signal` ledger.

Per `rules/canonical-skill-only.md` + `rules/no-silent-deferrals.md`: silently rewriting F-003's contract to be "pre-close-signal-capture" would corrupt the catalog and roadmap. Lane A executed the substantive work against the existing F-014 ledger and surfaced the discrepancy here for user adjudication.

**Loop-improvement candidate (logged in confidence-ledger as Lane-A-w8-prompt-vs-ledger-naming)**: brief generation should validate F-NNN ↔ slug pairing against the live catalog before issuing wave lane briefs. A pre-flight grep — "does the named F-NNN file exist with the named slug?" — would catch this category of brief drift.

### A2 — Lane B's F-015 impl was in working tree but uncommitted at start of Lane A

**Severity**: MEDIUM (resolved cleanly).

When Lane A started, `packages/engine-core/src/index.ts` had Lane B's uncommitted F-015 impl (`appendAuditEntry`, `verifyAuditChain`, etc.) appended at end-of-file. Lane A's edit added F-014 in the same trailing append zone, producing a single combined diff hunk.

**Resolution per `rules/scope-discipline.md`**: stripped Lane B's hunks pre-commit by reconstructing an F-014-only file (head -439), committed F-014 GREEN scoped to its own region, then restored Lane B's F-015 working-tree state for Lane B to commit independently. No silent commit of out-of-lane work.

Loop-improvement candidate (Lane-A-w8-disjoint-append-coexistence in confidence-ledger): even disjoint append-zones MUST be reviewed for type-name collision before commit. Lane B's `AuditEntry` → `AuditLogEntry` rename is the canonical example — without the rename, declaration-merging would have silently fused F-001's `AuditEntry` with F-015's, breaking type contracts.

### A3 — Counts in the prompt's "Expected" section don't match repo state

**Severity**: LOW (informational).

Prompt expected `F-001 (3) + F-002 (3) + F-003 (3+) = 9+ PASS` after Lane A flip. Actual: F-001 (3) + F-002 (3) + F-014 (8) + F-015 (4) = **18 PASS** (including Lane B's parallel work). The mismatch chains from A1 (F-003 vs F-014 naming) plus the prompt's assumption that no other lane was active. Reported in physical-proof.md and this summary.

## Scope deviations from prompt (intentional, documented)

The wave-008 / lane-a brief's deviations from what was actually executed:

1. **Feature ID** — prompt said F-003; real ledger is F-014 (per A1 above).
2. **Test file path** — prompt said `tests/unit/F-003-pre-close-signal-capture.test.ts`; actual is `tests/unit/F-014-pre-close-retro-signal.test.ts` (mirrors F-014's slug).
3. **Test count** — prompt said "3+ scenarios"; actual is 8 scenarios (3 ledger + 5 extended for Likert range / pattern field / halted-by carve-out positive + negative).
4. **Impl scope** — prompt's snippet defined `closeSession(retro: Partial<RetroSignal> | null): { ok: true }` with simple required-field iteration; actual impl extends the validation to recognize `outcome`, the halted-by carve-out (trigger_evidence_sha256), and integer-range (vs presence-only) checks per the F-014 ledger's actual behavior contract.

All deviations reflect honoring the existing F-014 ledger over the prompt's stale brief.

## Out of scope (per `rules/no-silent-deferrals.md`)

- **F-008 storage layout** — filesystem write to `runs/<run_id>/retro.json`. Lane A's flip is in-memory only; the boundary contract (RETRO_MISSING) is what F-008 will plug into.
- **F-015 audit-log integration** — write the retro entry into the hash-chained audit log. Lane B's F-015 work covers the chain primitive; the integration step is a follow-up.
- **F-018 / F-020 / F-022 halt-source wiring** — supply the actual `trigger_evidence_sha256` value when an audit entry triggers a halt. Currently the carve-out validates the SHA-256 shape; the source is a future feature.
- **ALAS-compatible learning-hub posting** — downstream consumption of the retro signal. Tracked under M11 (soul/introspect/replay) in M19 deferred catalog.
- **Lane B's F-015 GREEN commit** — Lane B owns committing their F-015 impl + ledger-transition + roadmap update + lane-b-summary.md. Lane A's commits are scoped to F-014 only.

## Confidence

HIGH (all 9 artifacts). Source material — F-014 ledger acceptance scenarios + behavior contract + kit:council-retro-skill rubric (5-axis 1-5 + 7 pattern fields) + ce:FR-CORE-004 + ce:FR-CORE-005 — is consistent and unambiguous. RED baseline captured BEFORE the GREEN flip per the wave-005 retro proposal. 8/8 acceptance scenarios pass with real vitest output (not synthesized). 5 atomic commits each carrying the chain-of-thought commit body. Rule citations across the work — `scope-discipline.md`, `canonical-skill-only.md`, `no-silent-deferrals.md`, `concurrency-safety.md` — reflect load-bearing discipline contracts.

## Quality-gate checklist (QG1-QG9 for wave-008 lane-a)

- [x] QG1 — net-new — F-014 GREEN flip is the third RED→GREEN in the repo and first M2 transition
- [x] QG2 — sources cited — every commit body cites SOURCE; physical-proof.md cites the ledger + actual test output; this summary cites rules + commit SHAs
- [x] QG3 — touches Goal G1-G37 — touches G1 (red→green ledgers per V:1), G27 (full behavior tests + physical proof), G37 (immediate working product — first M2 governance feature)
- [x] QG4 — backlog item processed/generated — generates: 4 deferred dependencies (F-008 / F-015 / F-018+F-020+F-022 / M11 ALAS) explicitly named; surfaces brief-validation loop-improvement
- [x] QG5 — loop-improvement proposal — see "Loop-improvement proposal" below
- [x] QG6 — multi-lane fan-out applied at wave level — wave-008 has two lanes (this is lane-a; lane-b runs F-015)
- [ ] QG7 — Copilot CLI design review — N/A this lane (RED→GREEN flips don't trigger council review per current convention; pending if M2 features should be `--council` per `prescriptive-content-review.md` blast-radius axis)
- [ ] QG8 — Microsoft tools used — N/A this lane (engine-core implementation, not Microsoft-stack)
- [x] QG9 — open questions captured — A1, A2, A3 in Anomalies above

## Loop-improvement proposal (QG5)

Three observations from this lane that should feed wave-009+ discipline:

1. **Brief F-NNN ↔ slug validation pre-flight.** Pattern: prompt asked for `F-003-pre-close-signal-capture`, actual ledger is `F-014-pre-close-retro-signal`. A 30-second grep at brief-generation time — `grep -r "F-003-pre-close" docs/03-feature-catalog/` returns empty AND `grep -r "pre-close" docs/03-feature-catalog/` returns F-014 — would have caught it. Recommend: brief-generation skill validates every named F-NNN+slug pair against the live catalog before issuing.
2. **Disjoint-append zone discipline for parallel lanes.** Pattern: Lane A + Lane B both modify the same file in disjoint append zones. The mechanical convention (each lane appends in its own region; coordinate via type-name uniqueness) works AS LONG AS the second lane to commit understands the first lane's uncommitted work and doesn't include it. Lane A's strip-then-commit-then-restore shape is reusable. Recommend: codify this pattern as a pattern doc under `wiki/patterns/` (e.g. `parallel-append-zone-coordination.md`) so future multi-lane waves don't re-derive it.
3. **Ledger transition status-history `at:` field convention.** F-001 / F-002 entries used `at: 2026-05-07`; this lane used `at: 2026-05-06` matching the actual session date per the userMemory `currentDate`. The mismatch with the original RED entry (`at: 2026-05-07`) is informational not load-bearing. Recommend: ledger-transition convention should specify "use the date the transition is committed, not the original RED authoring date" so audit consumers can sort by actual transition events.

## Reproduction

```bash
cd C:/Users/tonym/Repos/mad-council-claw
git log --oneline | head -6        # see lane-a's 5 commits
pnpm install
pnpm exec vitest run tests/unit/F-014-pre-close-retro-signal.test.ts   # 8/8 PASS
pnpm test:unit                                                          # 18/18 PASS (with Lane B's F-015)
cat docs/09-examples-proof/F-014/physical-proof.md                      # the audit anchor
```

## Push

Pending — `git push` per `rules/non-negotiable-rules.md` requires explicit user request. Lane A's commits are local; user adjudication on the F-003 vs F-014 naming divergence (Anomaly A1) may inform whether to push as-is or amend.
