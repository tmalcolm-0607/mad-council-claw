---
artifact-class: council-review
feature-id: F-007
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-013 / lane-b
---

# F-007 ipc-contract-scaffold — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 90 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 76 |
| architect-lens | Architect | APPROVE | 88 |

Median confidence: 88

## Implementation reviewed

- `common/ipc-contract.ts` (~82 LOC) — exports `IpcInvokeMap` (empty object type), `IpcInvokeChannel = keyof IpcInvokeMap` (= `never` until first channel added), `IpcInvokeRequest<C>` + `IpcInvokeResponse<C>` (conditional-infer accessors over the map). Header docblock cites the F-007 ledger + the clawpilot surface trace (`cp:src/main/ipc` + `cp:src/preload`) + `kit:rules/orchestrator-identity.md` and carries a `TODO (refresh after PR merge)` marker per the kit's "just copy" rule for future M5 verification.
- `tests/unit/F-007-ipc-contract-scaffold.test.ts` — 3 acceptance scenarios scoped to the wave-011 / lane-a scaffold-shape contract (per F-007 ledger §Acceptance scenarios + the explicit M5 deferral notes); all PASS per `docs/09-examples-proof/F-007/green-test-output.txt`.
- Commit history per `docs/07-roadmap/decision-log.md`: F-007 RED at wave-002 / lane-b (initial ledger only); F-007 GREEN at wave-011 / lane-a alongside the engine-core file split.
- `tsconfig.json` `include` array extended to cover `common/**/*.ts` so the new repo-root tree participates in type-check (1-line change; minimal-extension per `verification-protocol.md` Rule 3).

## Advocate lens

**Verdict: APPROVE (confidence 90)**

- Implementation is minimal and correct per `minimum-change.md`. ~82 LOC delivers the entire scaffold-shape contract: the map type + 3 derived helper types + the conditional-infer pattern future channels extend through. No premature abstraction; no helper functions invented before they have a caller.
- Type-only API: zero runtime cost. The scaffold is purely compile-time discipline; the runtime witness (the wildcard import in the test) only exists to confirm the module file is on disk.
- Clean composition with future M5 features: when F-032..F-043 land their first channels, they extend `IpcInvokeMap` directly. The conditional-infer accessors (`IpcInvokeRequest<C>`, `IpcInvokeResponse<C>`) preserve type information at every call site without further machinery.
- Surface trace (per ledger): `cp:src/main/ipc` + `cp:src/preload` + `kit:rules/orchestrator-identity.md` are all cited in the header docblock; provenance is auditable.
- The `expectTypeOf` + compile-time witness approach in the test is the right shape for a type-only contract. Runtime assertion (`expect(IpcContract).toBeDefined()`) provides the file-on-disk witness; the type assertions provide the shape witness.
- F-007 was the 12th feature to flip RED → GREEN (wave-011) and is now the 5th LOCKED transition. Together with F-001/F-002/F-006/F-008 LOCKED, M0 reaches 5/8 LOCKED — a meaningful "bootstrap is mostly stable" signal.

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 76)**

- F-007 is a **scaffold-only** feature today. Two of the three F-007 ledger §Acceptance scenarios (renderer can't directly call `ipcRenderer.send`; build fails when handler is registered without contract entry) require an actual Electron context-bridge harness + a registered handler call site — neither exists yet, both land with M5 (F-032..F-043). The wave-011 GREEN flip and this LOCKED review honor only Scenario 1 (typed contract module exists).
- LOCKED status here is therefore narrowly "**F-007 scaffold-shape contract LOCKED**" — Scenarios 2 and 3 will be retired by M5 features that produce the runtime harness. The ledger §Red→green wire-up table already names them as deferred-to-M5; the proof artifact (`docs/09-examples-proof/F-007/physical-proof.md`) reconciles the deferrals explicitly per `no-silent-deferrals.md`.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `common/ipc-contract.ts` lines 1-82 directly + the test lines 1-60. The scaffold is exactly what the ledger describes; no hidden surface area; no consumer code yet exists for the contract to gate.
- Suggestion (NON-BLOCKING per `no-silent-deferrals.md`): when M5 desktop-shell ledgers land (F-032..F-043), the first channel addition should re-verify the declaration-merging vs type-extension pattern noted in the header `TODO`. The scaffold uses type-extension today (`type IpcInvokeMap = {...}`); if clawpilot's actual surface uses `interface IpcInvokeMap` with declaration merging across multiple files, the scaffold needs a one-line shape adjustment. This is a forward-known gap, not a hidden one.
- Suggestion (NON-BLOCKING): the `keyof IpcInvokeMap = never` empty-state is *correct* TypeScript but produces unhelpful error messages at consumer call sites until the first channel is added (`Argument of type 'foo' is not assignable to parameter of type 'never'`). M5's first channel will retire this; until then any premature consumer would see the cryptic `never` error and need to read the F-007 ledger to understand. Acceptable scaffold trade-off; flagging for the M5 ledger refresh wave to consider whether a one-channel placeholder would soften the onboarding path.

## Architect lens

**Verdict: APPROVE (confidence 88)**

- File-location posture: `common/ipc-contract.ts` at the repo root (NOT under `packages/engine-core/src/`) is the correct shape per the F-007 ledger surface trace (`cp:src/main/ipc` + `cp:src/preload`). The `common/` tree is shared between main + renderer + headless backend, none of which is the engine-core package alone — placing the scaffold in `packages/engine-core/` would have leaked the engine-core boundary into the IPC layer and forced future Electron consumers to depend on the engine-core package just to import the contract types.
- The 1-line `tsconfig.json` `include` extension (`common/**/*.ts`) brings the new tree into the type-check sweep without touching the existing `packages/*/src/` or `tests/` patterns. Future common/ files (e.g. F-013 event-normalization shared types) inherit the same hookup.
- API surface review:
  - `IpcInvokeMap` shape — `type` not `interface`. Slight tradeoff: `interface` would allow declaration-merging across multiple files (a cross-package extensibility pattern); `type` requires direct file edits in `common/ipc-contract.ts`. Per `minimum-change.md`, `type` is the right minimum default — switching to `interface` is a one-line refactor when M5 surfaces a need.
  - `IpcInvokeChannel = keyof IpcInvokeMap` — derives from the map so a future channel addition automatically updates the channel union. No drift possible.
  - `IpcInvokeRequest<C>` + `IpcInvokeResponse<C>` — conditional-infer accessors. The `extends { request: infer R } ? R : never` shape correctly handles the case where a channel has only `request` or only `response` (returns `never` for the missing half).
- Composition with future features: clean separation of concerns. F-007 owns the contract-type module; M5 features (F-032..F-043) own the actual channel registrations; the engine-core package and headless-backend boundary stay free of Electron-specific contracts. The scaffold does not pre-commit to any specific main-process or renderer-process implementation.
- No surprises in dependencies: F-007 has zero hard deps on other features (per ledger frontmatter `depends-on: [F-003]` — repo-scaffolding is the only listed dependency, and it's a soft dep on `tsconfig.json` existing). Soft deps via the surface trace (clawpilot's `cp:src/main/ipc` pattern) are documented.

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | F-007 is a scaffold; Scenarios 2 + 3 from the ledger §Acceptance scenarios (renderer can't bypass the contract; missing-handler build failure) require an Electron + handler-registration runtime that lands with M5 (F-032..F-043). | Accept; LOCKED status applies to the scaffold-shape contract scope explicitly. The ledger §Red→green wire-up + the proof artifact `docs/09-examples-proof/F-007/physical-proof.md` document the deferrals. |
| F2 | MINOR | `type IpcInvokeMap = {...}` may want to become `interface IpcInvokeMap {...}` if M5 ledgers find that channel registrations need declaration-merging across multiple files (e.g. one channel per feature file). | Accept; flagged for M5's first channel-adding feature to verify. One-line refactor when the use case lands. |
| F3 | MINOR | `keyof IpcInvokeMap = never` empty state produces cryptic call-site errors until M5 adds the first channel. | Accept; M5's first channel retires this. No premature consumer exists today. |
| F4 | PRAISE | `expectTypeOf` + compile-time witness types is the right shape for a type-only contract — the test asserts both the file-on-disk witness AND the shape contract. | Keep. |
| F5 | PRAISE | File location at `common/ipc-contract.ts` (not `packages/engine-core/src/`) keeps the engine-core boundary clean and lets non-engine-core consumers (main, renderer, future headless backend) import the types without depending on engine-core. | Keep. |
| F6 | PRAISE | Co-shipped with the wave-011 / lane-a engine-core file split (per-feature files instead of a single `index.ts`) — the file split's "future-lane staging-race elimination" prediction (per `docs/11-loop-state/confidence-ledger.md:298`) is supported by the wave-013 / lane-b lane shipping cleanly without colliding with sibling features. Wave-13 / lane-b is the second post-split wave to ship without an engine-core race; the prediction continues to hold. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 88).

F-007 scaffold-shape contract is implemented correctly; all 3 wave-011-scoped acceptance scenarios pass per the recorded green-test-output proof; no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-007 ledger frontmatter (`LOCKED if GREEN AND reviews/F-007-ipc-contract-scaffold-review.md exists with verdict: ACCEPT`).

The MINOR findings are honest scope-narrowing notes per `no-silent-deferrals.md` — F1 (scenarios 2+3 require M5 runtime), F2 (`type` vs `interface` choice deferred to M5), and F3 (cryptic empty-state errors retired by M5's first channel) are surfaced in this review and in the F-007 ledger §Out-of-scope-notes. No finding is silent.

F-007 transitions GREEN → LOCKED. **Fifth LOCKED transition in the repo** (after F-001 wave-11/lane-b, F-002 + F-006 + F-008 wave-12/lane-d).

## Cross-references

- Ledger: `docs/03-feature-catalog/M0-bootstrap/F-007-ipc-contract-scaffold.md`
- Source: `common/ipc-contract.ts` (~82 LOC)
- Tests: `tests/unit/F-007-ipc-contract-scaffold.test.ts` (3/3 PASS)
- GREEN proof: `docs/09-examples-proof/F-007/green-test-output.txt` + `physical-proof.md`
- GREEN transition: decision-log.md row (wave-011 / lane-a entry)
- Co-shipped: `tsconfig.json` 1-line `include` extension for `common/**/*.ts`
- Review verdict envelope: per `docs/05-design-reviews/README.md` (APPROVE / APPROVE-WITH-SUGGESTIONS / WAIT-FOR-AUTHOR / REJECT)
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle (Reviewer summary table + Median confidence + Decision)
