---
artifact-class: council-review
feature-id: F-003
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-015 / lane-a
---

# F-003 repo-scaffolding — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 90 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 75 |
| architect-lens | Architect | APPROVE | 87 |

Median confidence: 87

## Implementation reviewed

- `package.json` (root, 30 LOC) — workspace globs (`packages/*`), shared scripts (`test`, `test:unit`, `test:node`, `lint`, `format`, `build`), `type: module`, `private: true`, `engines.node >=20`, `packageManager: pnpm@9.0.0`.
- `tsconfig.json` (root) — strict TS, ES2022 target, ESNext modules, Bundler resolution, `include` covers `packages/*/src/**/*.ts`, `tests/**/*.ts`, `common/**/*.ts`.
- `.eslintrc.cjs`, `.prettierrc.cjs`, `.editorconfig` — config files at root.
- `packages/engine-core/`, `packages/desktop-shell/`, `packages/cli/` — three workspace packages with `name: @mad-council-claw/<slug>`, `type: module`, `private: true`. desktop-shell + cli are scaffold-only at v1.
- LICENSE / README.md / .gitignore — present at root.
- `tests/node/F-003-repo-scaffolding.test.ts` (145 LOC) — 11 structural assertions; all PASS per `docs/09-examples-proof/F-003/green-test-output.txt`.
- Commit history per `docs/07-roadmap/decision-log.md`: F-003 RED at wave-002 / lane-b (initial ledger only); F-003 GREEN at wave-014 / lane-b, impl commit `a7af933`.

## Advocate lens

**Verdict: APPROVE (confidence 90)**

- Implementation is minimal and correct per `minimum-change.md`. ~50 LOC of new content (two scaffold package.json files); the rest of the F-003 contract surfaces (root tsconfig, eslint, prettier, editorconfig, engine-core, LICENSE/README/.gitignore) had been de-facto landed by waves 11+13. Lane B closes only the workspace-package gap.
- The 3-package monorepo shape (engine-core / desktop-shell / cli) directly maps to the foundational-plan §M-1 layout. `packages/desktop-shell/` and `packages/cli/` exist as workspace packages so their future M5 + M4 features have an attachment point without any further scaffolding work.
- 11/11 structural assertions PASS at GREEN time — workspace globs, strict TS, lint/format/editor configs, 3-package structure, LICENSE/README/.gitignore presence are all enforced via the test.
- Surface trace (per ledger): `cp:package.json` + `cp:tsconfig.json` + `cp:packages/` + `kit:foundational-plan.md M-1` are all honored — provenance is auditable.
- F-003 is the foundation that F-004 (vitest+playwright config), F-005 (deps-pinning), and every future feature implicitly depend on. LOCKED here makes the foundation contract permanent.

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 75)**

- F-003 is **scaffold-only** for desktop-shell and cli today. The ledger §Behavior contract paragraph claims "`npm run build` compiles every package in topological order" — at v1 the root `package.json` defines `build` as a no-op echo per F-001's library-only design. Working topological build is M3+ scope.
- The ledger §Acceptance scenarios 1 + 2 (fresh-clone build + TS error fails build) require a working `tsc -b` topological compile across packages. Currently only Scenario 3 (workspace globs auto-pickup) is fully runtime-verifiable; Scenarios 1 + 2 are deferred to M3+.
- LOCKED status is therefore narrowly "**F-003 monorepo-scaffold-shape contract LOCKED**" — the working-build scenarios will be retired by future build-wiring work (M3+ feature scope, currently un-scoped). The ledger §Out-of-scope-notes already names this; no surprise.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `package.json` (30 LOC), `tsconfig.json` (16 LOC), and verified `packages/desktop-shell/` + `packages/cli/` exist with their package.json files. The scaffold is exactly what the ledger describes; no hidden surface area.
- Suggestion (NON-BLOCKING per `no-silent-deferrals.md`): when the M3 working-build wave lands, the F-003 §Acceptance scenarios 1 + 2 should be revisited and a runtime test added (`pnpm build` exits 0; introducing a TS error fails the build). The deferral is forward-known, not hidden.
- Suggestion (NON-BLOCKING): per-package `tsconfig.json` extending a `tsconfig.base.json` is in the ledger §Behavior contract but deferred per §Implementation notes. The current root-only tsconfig handles all sources via `include` globs. When per-package compile units need to diverge (e.g., desktop-shell needs `lib: DOM`, cli needs `lib: ES2022` only), the per-package tsconfig adds. One-time refactor when the divergence appears.

## Architect lens

**Verdict: APPROVE (confidence 87)**

- File-location posture: 3 workspace packages under `packages/` (engine-core, desktop-shell, cli) — clean separation of concerns. engine-core hosts the F-001..F-022 governance + backend surfaces; desktop-shell will host M5 features; cli will host M4 features. No premature consolidation; no premature splits.
- Workspace shape: pnpm workspaces declared via `workspaces: ["packages/*"]` glob in root `package.json` + `pnpm-workspace.yaml`. Adding a new package is config-free per Scenario 3 — confirmed by the test's workspace-glob assertion.
- Strict TS opt-in: root `tsconfig.json` carries `"strict": true` + `"forceConsistentCasingInFileNames": true` + `"isolatedModules": true`. The strict flag is the contract that downstream features inherit; a future feature that needs to relax for a specific file uses `// @ts-expect-error` rather than a per-package tsconfig override.
- Module-resolution choice: `"module": "ESNext"` + `"moduleResolution": "Bundler"` matches the modern ESM bundler pattern. ESM-everywhere (`type: module` in every package.json) keeps imports unified — no CommonJS interop wrinkles.
- LICENSE/README/.gitignore presence: the test asserts these exist at root. Cosmetic but load-bearing for OSS distribution and onboarding.
- No surprises in dependencies: F-003 has zero hard deps (per ledger frontmatter `depends-on: []`). F-005 (deps-pinning) is a soft dep — package.json content is what F-005 enforces; F-003 just creates the files.

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | F-003 is scaffold-only for desktop-shell and cli; concrete `src/` content lands with M5 (desktop-shell) and M4 (cli) features. | Accept; LOCKED status applies to the monorepo-scaffold-shape scope explicitly. The ledger §Out-of-scope-notes documents the deferral. |
| F2 | MINOR | Working `npm run build` topological compile (`pnpm build` runs `tsc -b` across packages) is deferred to M3+; current `build` script is a no-op echo per F-001's library-only design. F-003 §Acceptance scenarios 1 + 2 wait for M3+. | Accept; flagged for M3+'s build-wiring work to revisit and add runtime tests. |
| F3 | MINOR | Per-package `tsconfig.json` extending a `tsconfig.base.json` (per ledger §Behavior contract) is deferred. Root-only tsconfig handles all sources today via `include` globs. | Accept; refactor when per-package compile-unit divergence is needed. |
| F4 | PRAISE | `@mad-council-claw/<slug>` package naming + `type: module` + `private: true` for all three workspace packages — consistent shape across packages, no naming drift. | Keep. |
| F5 | PRAISE | `pnpm-workspace.yaml` + `workspaces: ["packages/*"]` glob makes adding new packages config-free. The test's workspace-glob assertion enforces this contract permanently. | Keep. |
| F6 | PRAISE | F-003 closes the foundation contract that every other feature implicitly depends on. LOCKED here makes the bootstrap monorepo shape permanent — future packages slot in without touching this contract. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 87).

F-003 monorepo-scaffold-shape contract is implemented correctly; all 11 wave-014-scoped structural assertions pass per the recorded green-test-output proof; no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-003 ledger frontmatter (`LOCKED if GREEN AND reviews/F-003-repo-scaffolding-review.md exists with verdict: ACCEPT`).

The MINOR findings are honest scope-narrowing notes per `no-silent-deferrals.md` — F1 (concrete `src/` for desktop-shell + cli deferred to M4/M5), F2 (working topological build deferred to M3+), F3 (per-package tsconfig deferred to per-package divergence) are surfaced in this review and in the F-003 ledger §Out-of-scope-notes. No finding is silent.

F-003 transitions GREEN → LOCKED.

## Cross-references

- Ledger: `docs/03-feature-catalog/M0-bootstrap/F-003-repo-scaffolding.md`
- Source: `package.json` (root), `tsconfig.json`, `.eslintrc.cjs`, `.prettierrc.cjs`, `.editorconfig`, `packages/{engine-core,desktop-shell,cli}/package.json`, LICENSE, README.md, .gitignore
- Tests: `tests/node/F-003-repo-scaffolding.test.ts` (11/11 PASS)
- GREEN proof: `docs/09-examples-proof/F-003/green-test-output.txt` + `physical-proof.md`
- GREEN transition: decision-log.md (F-003 RED → GREEN row); impl commit `a7af933`; wave-014 / lane-b
- Review verdict envelope: per `docs/05-design-reviews/README.md` (APPROVE / APPROVE-WITH-SUGGESTIONS / WAIT-FOR-AUTHOR / REJECT)
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle (Reviewer summary table + Median confidence + Decision)
