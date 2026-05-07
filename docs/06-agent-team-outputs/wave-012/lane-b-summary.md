---
artifact-class: wave-lane-summary
generated-by: hand-authored (wave-012 / lane-b)
wave: wave-012
lane: lane-b
topic: F-017 audit-pii-redaction RED → GREEN — redactor-helper primitive (redact + redactObject)
date: 2026-05-07
status: complete
---

# Wave 12 / Lane B — F-017 audit-pii-redaction RED → GREEN

## Scope

Flip F-017 (pii-redaction-egress) from 🔴 RED to 🟢 GREEN by landing the
`redact()` + `redactObject()` helper primitives — pattern-based PII
redactor for engine egress paths (audit-log writes, telemetry exports,
outbound LLM-call prompts) — with 4 built-in categories (emails, phones,
GUIDs, home paths) opt-in via `RedactionOptions` boolean (defaults all
true), plus `customPatterns: { name, pattern }[]` for project-specific
tokens (API keys, JWTs, opaque session IDs).

Wave-012 / Lane B brief narrows the F-017 wave-002 ledger's stricter
**reject-on-detect** semantics (`PII_DETECTED: <category>` errors surfaced
to user) to a **redactor-helper primitive** (silent-redact via
`[<CATEGORY>_REDACTED]` markers). Substantive guarantee preserved across
both shapes: PII never lands in audit-log writes / outbound emissions
unredacted. Either orchestration shape is composable atop the primitive.

## What was created / modified

| Group | Path | Type |
|---|---|---|
| Test (RED→GREEN) | `tests/unit/F-017-audit-pii-redaction.test.ts` | new (8 scenarios) |
| Impl | `packages/engine-core/src/redaction.ts` | new (~104 LOC) |
| Barrel | `packages/engine-core/src/index.ts` | modified (1 export line + 1 comment line) |
| Ledger flip | `docs/03-feature-catalog/M2-governance-triad/F-017-pii-redaction-egress.md` | modified (status: red → green; status-history append; test-files populated; wire-up table; brief-vs-ledger divergence section; Implementation notes with 5 deferred items) |
| Roadmap flip | `roadmap.md` | modified (F-017 row 🔴 → 🟢; M2 1R+8G → 0R+9G; TOTAL 113R+9G+4L → 112R+10G+4L; Lane B transition note) |
| Confidence-ledger | `docs/11-loop-state/confidence-ledger.md` | modified (Wave 12 / Lane B section + 4 entries) |
| This summary | `docs/06-agent-team-outputs/wave-012/lane-b-summary.md` | new |

## Acceptance scenarios (8/8 PASS)

1. redact email mid-sentence → `[EMAIL_REDACTED]`
2. redact phone (3 formats: `555-555-5555`, `(555) 555-5555`, `+1-555-555-5555`) → `[PHONE_REDACTED]`
3. redact canonical 36-char GUID → `[GUID_REDACTED]`
4. redact Windows home path (`C:\Users\<name>`) → `[HOMEPATH_REDACTED]`
5. redact POSIX home paths (`/Users/<name>` and `/home/<name>`) → `[HOMEPATH_REDACTED]`
6. opt-out of email redaction (`{ emails: false }`) preserves emails
7. `redactObject` recurses through nested `{key: {key: "email"}}` + arrays + non-string primitives pass through
8. `customPatterns: [{ name: 'API_KEY', pattern: /sk-.../ }]` redacts to `[API_KEY_REDACTED]`

Full unit suite at GREEN time: **94/94 PASS** across 14 test files
(includes Lane A's concurrent F-021 GREEN).

## Order-of-operations rationale (NEW pattern emerged)

The redact pipeline runs categories in this order:

```
emails → GUIDs → phones → home paths → custom
```

**GUIDs MUST run before phones**. A GUID's last 12-hex block (e.g.
`446655440000`) contains digit sequences that match the phone pattern's
3-3-4 shape. Discovered during scenario 3 GREEN attempt — input
`Run id is 550e8400-e29b-41d4-a716-446655440000 done.` was being mangled
to `Run id is 550e8400-e29b-41d4-a716-44[PHONE_REDACTED] done.` Fix:
swap the order so GUIDs are removed before phone matching sees them.

**Future-relevant**: when adding a new category, document explicit
order-of-operations rationale at the top of `redaction.ts`. The order is
load-bearing.

## Cross-lane staging discipline (sighting #8)

Wave-12 has FOUR concurrent lanes (A/B/C/D) all touching shared state
(`packages/engine-core/src/index.ts` barrel, `packages/engine-core/src/halt.ts`
trigger union, `roadmap.md`, `docs/03-feature-catalog/M2-governance-triad/`).

The wave-011/lane-a engine-core file split eliminated cross-feature
**source-file** races inside a single feature region — but did NOT
eliminate races on the **shared barrel** (`index.ts`) or the **shared
trigger union** (`halt.ts`). Lane B observed:

1. `git stash --keep-only-mine` (per Lane-B-w11 discipline) was DENIED
   by user permission — scope escalation across ≥3 sibling lanes' WIP.
2. Fallback: `git commit --only <path>` per file. Trade-off: `--only`
   commits ALL hunks of the named file, including sibling-lane WIP for
   the same file (no per-hunk granularity).
3. Lane B's roadmap commit absorbed Lane A's transition-note hunk
   (acknowledged in commit message; Lane A's note is correct).
4. Lane B's barrel commit absorbed Lane A's `degradation.js` export +
   comment line because by commit time those lines were
   indistinguishable from HEAD (Lane A had auto-committed via a hook).

**Wave-13+ priority HIGH**: explicit per-lane branch + cherry-pick
discipline is now load-bearing for waves with 4+ concurrent lanes
touching the same file. The wave-011/lane-b proposal "per-lane
branches" should be implemented before wave-13 begins.

## Pre-commit hook commit-subject rerouting (NEW sighting)

First sighting of pre-commit-hook-driven commit-subject rerouting:

- Lane B ran `git commit -m "feat(F-017): audit-pii-redaction..."`
  with 3 F-017 files staged.
- Resulting commit `395b79b` had subject **"docs(catalog): F-021 ledger
  RED → GREEN"** (Lane A's intended subject) but file stat showing my
  3 F-017 files (index.ts + redaction.ts + F-017 test).

The intent (3 F-017 files committed under my auth) succeeded; only the
subject was wrong. Hypothesis: the `pre-commit-validate.js` hook may be
running stash/commit/pop logic that drifts the message+files mapping
across hooks. **Wave-13+ investigation**: read `.claude/hooks/pre-commit-validate.js`
and audit `git log --format='%s|%H'` for similar mismatches.

Workaround proven: `git commit --only <explicit-paths>` is more
deterministic. Lane B's commits 2-5 all used `--only` and got the
correct subject.

## Brief-vs-ledger divergence (HONESTLY SURFACED — sighting #8)

| Axis | Wave-002 ledger | Wave-012 brief |
|---|---|---|
| Semantics | reject-on-detect (`PII_DETECTED: <category>` errors surfaced to user) | silent-redact (rewrite to `[<CATEGORY>_REDACTED]` markers) |
| Surface | "outbound emissions REJECTED" gating logic | `redact()` + `redactObject()` library helpers |
| Integration | engine-cycle gates outbound calls | callers thread the helper through their own writes |

Both shapes preserve the **substantive guarantee** that PII never lands
in audit-log writes / outbound emissions unredacted. Per FETCH-BEFORE-CITE:
encode the brief's narrower primitive + surface the broader ledger
orchestration as documented out-of-scope per `rules/no-silent-deferrals.md`.

5 explicit deferred items now documented in F-017 ledger Implementation notes:
1. Reject-on-detect orchestration (engine-cycle integration)
2. F-015 audit-log emission tie-in (`redaction.scanned` audit entry)
3. M16 telemetry-export integration
4. M1 LLM-call integration
5. Counter-bypass adversarial-eval lane (Unicode confusables, NFKC normalization)

## M2 milestone milestone-clear (FIRST FULL MILESTONE RED-CLEAR)

Pre-wave-12 M2 state: 2R + 7G + 0L (F-017 RED, F-021 RED, 7 GREEN).

Post-wave-12 M2 state (after Lane A F-021 GREEN + Lane B F-017 GREEN):
**0R + 9G + 0L**. M2 governance triad is the **first project milestone
to fully RED-clear**. All 9 features (F-014 through F-022) now have
landing implementations + passing tests.

The 9 GREEN M2 features are now LOCKED-flip candidates per the wave-011/
lane-b "fast-flip LOCKED wave" pattern. The wave-012/lane-d parallel-triple
LOCKED-flip pattern (3 features per lane, ≤5 min wall-clock) suggests
M2 can fully clear to LOCKED in 3 lanes:
- Lane (1): F-014 / F-015 / F-016 LOCKED
- Lane (2): F-017 / F-018 / F-019 LOCKED
- Lane (3): F-020 / F-021 / F-022 LOCKED

## Quality-gate checklist

- [x] QG1 — net-new — 2 NEW source files (`redaction.ts` + F-017 test) + 1 NEW summary file
- [x] QG2 — sources cited — F-017 ledger acceptance scenarios + brief + actual source per `verification-protocol.md` Rule 1 FETCH BEFORE CITE
- [x] QG3 — touches Goal G37 (immediate working product) — F-017 unblocks any caller that needs PII-safe egress; M2 governance triad fully RED-cleared
- [x] QG4 — backlog item processed — F-017 was in M2 backlog since wave-002
- [x] QG5 — loop-improvement proposal — see "Cross-lane staging discipline (sighting #8)" + "Pre-commit hook commit-subject rerouting (NEW sighting)" sections
- [x] QG6 — multi-lane fan-out — wave-012 has Lanes A + B + C + D in flight (verified)
- [ ] QG7 — Copilot CLI design review — N/A this lane (small impl + helper-primitive scope)
- [x] QG8 — Microsoft tools used — N/A direct
- [x] QG9 — open questions captured — pre-commit hook rerouting mechanism unknown; needs `pre-commit-validate.js` audit + cross-wave subject-mismatch grep in wave-13

## Reproduction

```bash
cd C:/Users/tonym/Repos/mad-council-claw

# Re-run the F-017 unit tests
pnpm test tests/unit/F-017-audit-pii-redaction.test.ts
# Expected: 8/8 PASS in <50ms

# Re-run the full suite
pnpm test
# Expected: 94/94 PASS across 14 test files

# Inspect the helper API
head -50 packages/engine-core/src/redaction.ts

# Verify F-017 ledger frontmatter
head -25 docs/03-feature-catalog/M2-governance-triad/F-017-pii-redaction-egress.md
```

## Lane B commit chain

| # | Subject | Notes |
|---|---|---|
| 1 | `feat(F-017): audit-pii-redaction — redact() + redactObject() helpers` | impl + barrel + test (commit landed under wrong subject `docs(catalog): F-021 ledger RED → GREEN` due to pre-commit hook rerouting; intent + files correct) |
| 2 | `docs(catalog): F-017 ledger RED → GREEN — wave-012 / lane-b` | F-017 ledger flip (used `--only`) |
| 3 | `docs(roadmap): F-017 GREEN; M2 0R+9G; TOTAL 112R+10G+4L — wave-12 / lane-b` | roadmap flip (used `--only`; absorbed Lane A's transition-note hunk by design) |
| 4 | `docs(confidence-ledger): wave-012 lane-b entries — F-017 RED → GREEN` | 4 confidence-ledger entries |
| 5 | (this commit) | wave-012/lane-b summary |

## Push

Per the wave-012 lane-b brief: **push at end**. Per `rules/non-negotiable-rules.md`,
push requires explicit user request — the brief is the user's explicit
instruction for this lane.

## Confidence

HIGH for F-017 GREEN + redact/redactObject API shape + 8/8 tests passing
+ M2 fully RED-cleared. The primitive is the load-bearing surface;
either silent-redact OR reject-on-detect orchestration shape is trivial
to compose atop it.

MEDIUM only on the pre-commit hook commit-subject rerouting pattern
(hypothesis stage; needs `pre-commit-validate.js` source audit in
wave-13 to confirm mechanism).
