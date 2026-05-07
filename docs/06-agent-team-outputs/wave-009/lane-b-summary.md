---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-009 / lane-b)
wave: wave-009
lane: lane-b
topic: F-016-query-audit-log-RED-GREEN
date: 2026-05-07
status: complete
---

# Wave 9 / Lane B — F-016 query-audit-log RED → GREEN

## Scope

Sixth feature transition RED → GREEN in the repo (after F-001 wave-005, F-002 wave-006, F-014 + F-015 wave-008, F-006 wave-009/lane-a). Second M2 feature pair to flip — completes the audit-write + audit-read primitive set (F-015 writes the chain; F-016 reads it). Lane B's brief specified a synchronous filter API + a chain-integrity helper, simplifying the F-016 ledger's streaming async-iterator shape per the brief's explicit `queryAuditLog` + `findChainBreak` signatures.

Wave-009 ran with three+ active lanes:
- **Lane A**: F-006 logging-pipeline (M0)
- **Lane B (this lane)**: F-016 query-audit-log (M2)
- **Other lane (unattributed)**: F-018 failure-pattern-halt (M2)
- **Lane D**: backlog intake (25 F-D-NNN candidates + 5 RG + 5 D-NN)

All three feature lanes modify `packages/engine-core/src/index.ts` in disjoint append zones.

## What was created / modified

| Group | Path | Type | Count |
|---|---|---|---|
| RED test | `tests/unit/F-016-query-audit-log.test.ts` | new | 1 |
| GREEN impl additions | `packages/engine-core/src/index.ts` | modified (~109 LOC added in F-016 region) | 1 |
| Ledger transition | `docs/03-feature-catalog/M2-governance-triad/F-016-query-audit-log.md` | modified (status red→green; status-history; test-files; impl notes) | 1 |
| Roadmap update | `roadmap.md` | modified (F-016 row → 🟢 GREEN; M2 + TOTAL counters bumped) | 1 |
| Confidence-ledger entries | `docs/11-loop-state/confidence-ledger.md` | modified (4 new wave-009 lane-b entries) | 1 |
| Physical proof | `docs/09-examples-proof/F-016/physical-proof.md` | new | 1 |
| Vitest output capture | `docs/09-examples-proof/F-016/{red,green}-test-output.txt` | new | 2 |
| This summary | `docs/06-agent-team-outputs/wave-009/lane-b-summary.md` | new | 1 |
| **Total touched** | | | **9 artifacts** |

## Commit chain (Lane B's own commits)

| # | SHA | Subject | Notes |
|---|---|---|---|
| 1 | (lost) `62d9cbb` | `test(F-016): RED test for query-audit-log` | Reset by another lane; files re-included in `eacc651` (B1) |
| 2 | `f867251` | `test(F-016): GREEN test output captured` | Lane B's first surviving commit; landed after the cross-lane race |
| 3 | `04f37e3` | `docs(catalog): F-016 ledger transition RED → GREEN` | Status flip + impl notes + cross-lane race writeup |
| 4 | `fe9b654` | `docs(roadmap): F-016 GREEN; M2 6 RED + 3 GREEN; confidence-ledger wave-009 lane-b entries` | Roadmap + confidence-ledger together |
| 5 | (this commit) | `docs(examples-proof): F-016 GREEN — physical-proof + lane-b-summary` | Audit-trail anchor |

Each surviving commit body uses the chain-of-thought block (WHY / SOURCE / CONFIDENCE / WAVE / Gate Results) per the wave-005..wave-008 commit pattern.

## Vitest output

```
✓ tests/unit/F-016-query-audit-log.test.ts (8 tests) 8ms

Test Files  1 passed (1)
     Tests  8 passed (8)
```

Full unit suite (with concurrent lanes' work also landed): **39/39 PASS** (7 test files).

## RED→GREEN transition

| Phase | State | Test result |
|---|---|---|
| RED (commit eacc651, file re-included due to race) | `queryAuditLog` not exported; `findChainBreak` not exported; `AuditQueryOptions` interface absent | 8/8 fail with `TypeError: queryAuditLog is not a function` |
| GREEN (commit da48f2a, F-016 region included due to race) | `queryAuditLog` + `findChainBreak` + `AuditQueryOptions` exported (~109 LOC F-016 region appended after F-015) | 8/8 PASS |

Output captured: `docs/09-examples-proof/F-016/{red,green}-test-output.txt`.

## Surface inventory (the F-016 GREEN region)

- `interface AuditQueryOptions { since?, top?, skip?, action? }` — all fields optional
- `queryAuditLog(rows: readonly AuditLogEntry[], opts?) → AuditLogEntry[]`:
  - Defensive copy at entry; no mutation of source log
  - Filter pipeline: `since` → `action` → `skip` → `top` (chronological order preserved)
  - `since` filter targets `entry.fields.timestamp` (string, lexicographic compare)
  - `action` filter is exact-match
- `findChainBreak(rows: readonly AuditLogEntry[]) → number | null`:
  - Wraps F-015's `verifyAuditChain`
  - Returns zero-based broken_at index, or null when chain is intact

## Anomalies / context gaps

### B1 — Lane B's own RED commit was reset by another lane and re-included in their commit

**Severity**: HIGH (load-bearing for credit attribution + multi-lane discipline).

Lane B's first commit was `62d9cbb test(F-016): RED test for query-audit-log` containing `tests/unit/F-016-query-audit-log.test.ts` + `docs/09-examples-proof/F-016/red-test-output.txt`. Within seconds, another lane (working on F-018) ran `git reset HEAD~1` (visible in `git reflog`), undoing Lane B's commit. They then committed `eacc651 test(F-018): RED test stub for failure-pattern-halt` whose file list inadvertently included Lane B's two F-016 files. Substance preserved (F-016 RED files are in HEAD); credit attribution misaligned (commit message says F-018, content includes F-016).

### B2 — Lane B's own GREEN impl was lost from a separate commit and re-included in Lane A's F-006 GREEN commit

**Severity**: HIGH (same family as B1).

Lane B appended ~109 LOC of F-016 GREEN impl to `packages/engine-core/src/index.ts` (disjoint append zone after F-015). The working tree raced with Lane A's F-006 GREEN impl + the F-018 GREEN impl (both also appending to the same file). When Lane A committed `da48f2a docs(examples-proof): F-006 GREEN ...`, that commit's `--stat` shows 403 insertions to `packages/engine-core/src/index.ts` — covering F-006 + F-018 + F-016 regions all bundled together. Substance preserved (F-016 GREEN impl is in HEAD; tests pass); credit attribution misaligned again.

**Wave-10 LOOP IMPROVEMENT (HIGH priority)**: the wave-008 disjoint-append-zones + scope-discipline pattern was sufficient for 2-lane parallel work but breaks down at 4+ concurrent lanes hitting the same file. Three options for wave-10+:
1. **Per-lane branches** — each lane works on `users/<alias>/wave-NNN-lane-X` branch; merge to main coordinated by a wave-coordinator. Higher overhead but eliminates the race.
2. **Wave-coordinator gate** — a designated lane (e.g. Lane Z) gates all commits; other lanes propose patches that the coordinator stages atomically. Lower overhead but introduces a serialization point.
3. **Lane-aware git lock** — a hook/script that checks for other lanes' work-in-progress before allowing `git reset HEAD~1`. Prevents the destructive race; doesn't prevent inadvertent file inclusion.

The cleanest path is probably (1) per-lane branches; the parallel-lane discipline was originally designed assuming each lane has its own branch (per the LENS-DCS standardization loop pattern in `CLAUDE.md`). Direct-to-main multi-lane work without coordination is the antipattern.

### B3 — Brief's `since` filter targets a field absent from `AuditLogEntry`

**Severity**: MEDIUM (resolved cleanly with documented choice).

The wave-9 brief specified `since?: string; // ISO timestamp` filter — but F-015's `AuditLogEntry` has no top-level timestamp field (only `cycle`, `action`, `fields`, `prev_sha256`, `entry_sha256`). The brief also said "Use the existing F-015 AuditLogEntry type — DO NOT re-define." Resolved by reading `entry.fields.timestamp` (typed `unknown` per F-015's `Record<string, unknown>` shape; runtime-checked for `typeof === 'string'` before lexicographic compare). Documented inline in the impl + ledger §Implementation notes + this summary.

Wave-10 takeaway: when a brief's filter API surface implies a field that doesn't exist in the underlying type, document the indirection inline (here: `fields.timestamp` lookup with explicit fallback semantics).

### B4 — Test count exceeds brief's "5+ scenarios" target

**Severity**: LOW (informational — exceeds, doesn't violate).

Brief said "5+ scenarios". Lane B authored 8 (1, 2a, 2b, 3, 4, 5, 6, 7) covering the 3 ledger acceptance scenarios + 5 brief-derived. Defensible: combined-filter compose (#6) and defensive-copy (#7) close real bug surfaces (filter-order coupling + unintended mutation). Within tolerance of "5+".

## Scope deviations from brief (intentional, documented)

1. **Test file path** — brief said `tests/unit/F-016-query-audit-log.test.ts`; actual matches exactly.
2. **Function signatures** — brief gave verbatim signatures; actual matches exactly (parameter names, return types, optional fields).
3. **`since` semantics** — brief said `e.timestamp >= opts.since` (assumes top-level field); actual reads `e.fields.timestamp` (lookup into the existing-type's free-form fields map). See B3.
4. **Test count** — brief said "5+ scenarios"; actual is 8. See B4.

All deviations honor the brief's explicit "DO NOT re-define AuditLogEntry" constraint and surface the gap explicitly rather than silently expanding the brief.

## Out of scope (per `rules/no-silent-deferrals.md`)

- **Streaming async-iterator shape** — F-016 ledger §Behavior contract specifies `async iterator yielding matching entries`. Brief simplified to synchronous filter; substantive guarantees preserved. Streaming shape deferred to v1.5 per ledger out-of-scope-notes ("M2 ships a streaming filter API only; heavy query needs are tracked under F-088..F-092 / M11 introspect/replay").
- **Persistence-layer reads** — querying directly against `runs/<run_id>/audit.ndjson` is F-008's job (storage layout). Lane B's flip is in-memory only.
- **`agent_id` / `run_id` filters** — F-002 stamps these into `fields` via `stampIdentity`. Brief uses `action` as the v1 filter to keep the API minimal. 2-LOC follow-on to add.
- **`until_utc` timestamp upper bound** — brief specifies `since` only; `until` is symmetric and trivial to add when needed.
- **Chain-integrity-on-query** — F-016 ledger says queryAuditLog "validates the chain integrity per F-015 BEFORE yielding any entry". Brief separates this into `findChainBreak` so callers compose deliberately. Substantive guarantee preserved (callers can verify before query); cost model now caller-controlled.

## Confidence

HIGH (substance — F-016 RED + GREEN impl + 8/8 PASS — verifiable in HEAD). MEDIUM on credit attribution (Anomalies B1+B2 documented; reflog evidence; but two of Lane B's commits are filed under other lanes' commit messages and that cannot be unwound without rewriting other lanes' history). The cross-lane race is the load-bearing wave-10 loop-improvement candidate.

## Quality-gate checklist (QG1-QG9 for wave-009 lane-b)

- [x] QG1 — net-new — F-016 GREEN flip is the sixth RED→GREEN in the repo and the second M2 feature pair (with F-018 same wave)
- [x] QG2 — sources cited — every commit body cites SOURCE; physical-proof.md cites the ledger + actual test output; this summary cites rules + commit SHAs + reflog
- [x] QG3 — touches Goal G1-G37 — touches G1 (red→green ledgers per V:1), G27 (full behavior tests + physical proof), G37 (immediate working product — second M2 audit primitive)
- [x] QG4 — backlog item processed/generated — generates: 4 deferred dependencies (F-008 / agent_id-runid filters / streaming shape / chain-integrity-on-query) explicitly named; surfaces the 4-lane race as a HIGH-priority wave-10 loop-improvement
- [x] QG5 — loop-improvement proposal — see B2 § Wave-10 LOOP IMPROVEMENT (per-lane branches recommended)
- [x] QG6 — multi-lane fan-out applied at wave level — wave-009 has 4+ lanes (this is lane-b)
- [ ] QG7 — Copilot CLI design review — N/A this lane (RED→GREEN flips don't trigger council review per current convention)
- [ ] QG8 — Microsoft tools used — N/A this lane (engine-core implementation, not Microsoft-stack)
- [x] QG9 — open questions captured — B1, B2, B3, B4 in Anomalies above

## Loop-improvement proposal (QG5)

The dominant lesson from wave-009 lane-b: **multi-lane direct-to-main racing destroys credit attribution**. Three options ranked:

1. **Per-lane branches (recommended)** — each lane works on `users/<alias>/wave-NNN-lane-X`. Merge to main happens once per lane, coordinated. Solves both (a) the destructive `git reset HEAD~1` race and (b) the inadvertent multi-lane file inclusion. Higher per-commit overhead; eliminates the entire race class.
2. **Wave-coordinator gate** — a designated lane (e.g. Lane Z) is the only one that commits to main; other lanes submit patches. Lower per-lane overhead; introduces a serialization point.
3. **Lane-aware git lock** — pre-commit hook checks `git reflog` for other lanes' uncommitted work; rejects `git reset HEAD~1` if another lane has work-in-progress. Doesn't prevent inadvertent file inclusion (lanes still race on the same working tree).

Recommend: **(1) per-lane branches** — matches the LENS-DCS standardization loop pattern in `CLAUDE.md` ("references/LENS-DCS-p<N>" worktrees + per-lane branches). The current direct-to-main multi-lane work in mad-council-claw is an antipattern that worked at 2 lanes (wave-008) and broke at 4 (wave-009).

## Reproduction

```bash
cd C:/Users/tonym/Repos/mad-council-claw
git log --oneline | head -10                                # see lane-b's commits + cross-lane attribution context
pnpm install
pnpm exec vitest run tests/unit/F-016-query-audit-log.test.ts   # 8/8 PASS
pnpm test:unit                                              # 39/39 PASS (full suite)
cat docs/09-examples-proof/F-016/physical-proof.md          # the audit anchor
git reflog | head -15                                       # evidence for Anomaly B1+B2
```

## Push

Pending — `git push` per `rules/non-negotiable-rules.md` requires explicit user request. Lane B's commits are local; user adjudication on the cross-lane race writeup may inform whether to push as-is or amend.
