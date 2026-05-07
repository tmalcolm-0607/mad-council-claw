---
artifact-class: council-review
feature-id: F-005
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-015 / lane-a
---

# F-005 deps-pinning — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 90 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 74 |
| architect-lens | Architect | APPROVE | 88 |

Median confidence: 88

## Implementation reviewed

- `package.json` (root, 30 LOC) — devDependencies stripped of `^`/`~` range operators (5 deps: `vitest: 2.1.9`, `@vitest/ui: 2.1.9`, `happy-dom: 15.11.7`, `typescript: 5.9.3`, `@types/node: 20.19.39`); `packageManager: pnpm@9.0.0` field declared; `engines.node >=20`.
- `pnpm-lock.yaml` — regenerated with exact-pin specifiers (e.g. `specifier: 2.1.9` instead of `specifier: ^2.0.0`); resolved package versions in the `packages:` section unchanged.
- `tests/node/F-005-deps-pinning.test.ts` (124 LOC) — 4 tests: (1) sweep every workspace package.json + assert exact-pin regex on every non-`workspace:*` version, (2) lockfile presence, (3) `engines.node` defined, (4) `packageManager` field declared. All PASS per `docs/09-examples-proof/F-005/green-test-output.txt`.
- Commit history per `docs/07-roadmap/decision-log.md`: F-005 RED at wave-002 / lane-b (initial ledger only); F-005 GREEN at wave-013 / lane-b.

## Advocate lens

**Verdict: APPROVE (confidence 90)**

- Implementation is minimal and correct per `minimum-change.md`. The package-manager choice (npm → pnpm) was already in the working tree at wave-013 lane start; the GREEN flip honors F-005's *intent* (exact-pinned deps + committed lockfile + reproducible-install discipline) by validating the equivalent pnpm shape — not by re-litigating the package-manager decision.
- Resolved versions read from prior lockfile (no version drift, only specifier-string change). The `^2.0.0 → 2.1.9` etc. sweep was a mechanical translation, not a version-bump opportunity. Per `minimum-change.md`, that's the right discipline: don't smuggle bumps into a pinning task.
- 4/4 structural assertions PASS at GREEN time. The exact-pin regex sweep covers root + every workspace package.json — no spot-check; full coverage of the surface.
- `packageManager: pnpm@9.0.0` field declared — `corepack` consumers get deterministic pnpm version. Without this, a contributor running `pnpm install` with a different pnpm major could regenerate a non-equivalent lockfile.
- Surface trace (per ledger): `cp:package-lock.json` + `kit:rules/verification-protocol.md` (reproducible-build discipline). The clawpilot lockfile-commit pattern transfers cleanly — the file format (`package-lock.json` vs `pnpm-lock.yaml`) is incidental; the discipline (committed lockfile, frozen-lockfile install, exact pins) is the contract.
- F-005 was the 14th feature to flip RED → GREEN (wave-013 / lane-b alongside F-007's LOCKED flip). LOCKED here closes the M0 deps-pinning contract permanently.

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 74)**

- F-005 §Acceptance scenarios 2 (lockfile-vs-package.json drift fails CI) and 3 (cross-OS byte-identity install on Linux + macOS + Windows) are deferred to M16 (telemetry/CI hardening). Only Scenario 1 (range operators forbidden in any package.json) is fully runtime-verifiable today.
- LOCKED status here is therefore narrowly "**F-005 exact-pin sweep + lockfile-presence + engines.node-pin contract LOCKED**" — Scenarios 2 + 3 will be retired by M16 CI hardening. The ledger §Out-of-scope-notes already names this deferral; no surprise.
- The package-manager swap (npm → pnpm) is recorded openly in the F-005 ledger §Implementation notes per `no-silent-deferrals.md`. The translation table (npm `package-lock.json` → pnpm `pnpm-lock.yaml`; npm `npm ci` → pnpm `pnpm install --frozen-lockfile`; npm workspaces → pnpm workspaces; `engines.npm` → `packageManager: pnpm@...`) is explicit. A reader who expects npm semantics needs to know to substitute pnpm equivalents.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `package.json` lines 1-30, `pnpm-lock.yaml` head + tail (devDependencies block), and the test file lines 1-124. The sweep covers every workspace package.json; no exceptions. The 5 devDeps are pinned exactly; no `^`/`~` operators remain.
- Suggestion (NON-BLOCKING per `no-silent-deferrals.md`): when M16 CI hardening lands, F-005 §Acceptance scenarios 2 + 3 should be revisited and runtime tests added (a pre-merge gate that fails on lockfile-vs-package.json drift; a cross-OS CI matrix that compares `pnpm install --frozen-lockfile` results on Linux + macOS + Windows). The deferrals are forward-known, not hidden.
- Suggestion (NON-BLOCKING): vulnerability scanning + Dependabot auto-PRs are deferred to M16 per ledger §Out-of-scope-notes. Without them, exact-pinning means stale-version drift accumulates over time without surfacing as a CI signal. Acceptable v1 trade-off; flagging for M16 to wire `pnpm audit` into the gate suite.

## Architect lens

**Verdict: APPROVE (confidence 88)**

- Pinning regex shape: `^\d+\.\d+\.\d+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$` covers SemVer + pre-release tags + build metadata. Workspace-internal references via `workspace:*` are correctly excluded (those resolve to local packages, not registry versions). Sweep is full-coverage, not spot-check.
- Lockfile choice (`pnpm-lock.yaml` vs `package-lock.json`): pnpm is already committed in the repo; F-005 honors the discipline regardless of which lockfile format is used. The contract is "committed lockfile + frozen-lockfile install path"; the format is incidental.
- `packageManager: pnpm@9.0.0` field: load-bearing for `corepack`-driven version pinning. Without this, two contributors with different pnpm majors installed locally could regenerate non-equivalent lockfiles. The field gives `corepack` deterministic input.
- `engines.node >=20`: floor-pin (not exact-pin) is intentional — patch-level Node updates are not the supply-chain concern; major Node bumps are. The `>=20` floor matches the F-001 ESM-everywhere posture (Node 20+ for stable ESM support).
- Test approach: filesystem traversal of every `package.json` (root + workspace packages) + regex sweep + lockfile-presence + engines + packageManager — pure-structural, fast (~ms), no module imports. Same pattern as F-003 + F-004 — consistent test shape across M0 features.
- No surprises in dependencies: F-005 has F-003 as its only hard dep (per ledger frontmatter `depends-on: [F-003]`) — package.json files must exist to be checked. F-004 (vitest+playwright config) is a soft dep — vitest is pinned by this feature.

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | F-005 §Acceptance scenarios 2 (lockfile-vs-package.json drift fails CI) + 3 (cross-OS byte-identity install) deferred to M16 (telemetry/CI hardening). Only Scenario 1 (range operators forbidden) is fully runtime-verifiable today. | Accept; LOCKED status applies to the exact-pin + lockfile-presence + engines + packageManager contract scope explicitly. The ledger §Out-of-scope-notes documents the deferral. |
| F2 | MINOR | Package-manager swap (npm → pnpm) is recorded openly in §Implementation notes per `no-silent-deferrals.md`. Reader who expects npm semantics needs to substitute pnpm equivalents. | Accept; the implementation-notes translation table is explicit. |
| F3 | MINOR | Vulnerability scanning + Dependabot auto-PRs deferred to M16. Without them, stale-version drift accumulates without CI signal. | Accept; M16 wires `pnpm audit` into the gate suite. |
| F4 | MINOR | `engines.node >=20` is a floor-pin not exact-pin — intentional per ledger §Implementation notes (patch-level Node updates aren't the supply-chain concern). | Accept; design choice, not a defect. |
| F5 | PRAISE | Resolved versions read from prior lockfile — no version drift smuggled into the pinning task. Pure specifier-string translation (`^2.0.0` → `2.1.9` etc.). | Keep. |
| F6 | PRAISE | `packageManager: pnpm@9.0.0` field gives `corepack` deterministic input — closes the "two contributors with different pnpm majors" lockfile-divergence vector. | Keep. |
| F7 | PRAISE | Sweep covers every workspace package.json + root + non-`workspace:*` versions only. Full coverage of the surface; no spot-check. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 88).

F-005 exact-pin + lockfile + engines + packageManager contract is implemented correctly; all 4 wave-013-scoped structural assertions pass per the recorded green-test-output proof; no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-005 ledger frontmatter (`LOCKED if GREEN AND reviews/F-005-deps-pinning-review.md exists with verdict: ACCEPT`).

The MINOR findings are honest scope-narrowing notes per `no-silent-deferrals.md` — F1 (Scenarios 2+3 deferred to M16), F2 (npm → pnpm package-manager swap recorded openly), F3 (vulnerability scanning deferred to M16), F4 (`engines.node` floor-pin design choice) are surfaced in this review and in the F-005 ledger §Out-of-scope-notes. No finding is silent.

F-005 transitions GREEN → LOCKED.

## Cross-references

- Ledger: `docs/03-feature-catalog/M0-bootstrap/F-005-deps-pinning.md`
- Source: `package.json` (root devDeps stripped of `^`/`~`), `pnpm-lock.yaml` (regenerated with exact-pin specifiers)
- Tests: `tests/node/F-005-deps-pinning.test.ts` (4/4 PASS)
- GREEN proof: `docs/09-examples-proof/F-005/` (green-test-output + physical-proof)
- GREEN transition: decision-log.md (F-005 RED → GREEN row); wave-013 / lane-b
- Review verdict envelope: per `docs/05-design-reviews/README.md` (APPROVE / APPROVE-WITH-SUGGESTIONS / WAIT-FOR-AUTHOR / REJECT)
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle (Reviewer summary table + Median confidence + Decision)
