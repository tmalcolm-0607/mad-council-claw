---
artifact-class: council-review
feature-id: F-012
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-016 / lane-a
---

# F-012 backend-factory — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 91 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 78 |
| architect-lens | Architect | APPROVE | 90 |

Median confidence: 90

## Implementation reviewed

- `packages/engine-core/src/backend-factory.ts` (~96 LOC) — `BackendKind = 'anthropic' | 'copilot' | 'stub'` string-literal union; `BackendFactoryOptions { kind: BackendKind; model?: string }`; `createBackend(opts)` pure-function dispatcher returning `IBackendProvider` via TypeScript exhaustive-switch over `kind`; `default:` arm uses `const _exhaustive: never = opts.kind` for compile-time exhaustivity check + `throw new Error('Unknown backend kind: <kind>')` for runtime safety.
- `packages/engine-core/src/index.ts` — barrel re-export `export * from './backend-factory.js';`.
- `tests/unit/F-012-backend-factory.test.ts` — 6 scenarios: kind dispatch for anthropic/copilot/stub returns the right concrete class with the right origin; unknown kind throws at runtime; model parameter forwards to AnthropicBackend + CopilotBackend constructors; factory return type is exactly `IBackendProvider` (not narrowed to a concrete class). 6/6 PASS at GREEN time per ledger §Implementation notes (full suite 151/151).
- Commit history per `docs/07-roadmap/decision-log.md`: F-012 RED at wave-002 / lane-b; F-012 GREEN at wave-015 / lane-d.
- GREEN proof: `docs/09-examples-proof/F-012/` (red-test-output + green-test-output + physical-proof) per ledger §Implementation notes.

## Advocate lens

**Verdict: APPROVE (confidence 91)**

- Implementation is minimal and correct per `minimum-change.md`. ~96 LOC delivers the entire backend-factory contract: 1 union type + 1 options interface + 1 pure-function dispatcher with exhaustive-switch. No premature abstraction — no registry pattern (per the wave-002 ledger's original `createBackendProvider(name, opts)` shape), no plug-in loader, no env-var resolution.
- F-012 is the **fourth M1 feature** flipped (after F-009 LOCKED + F-010 GREEN + F-011 GREEN at wave-015) — proves the F-009 contract surface accepts a routing layer above without contract drift. The factory is the recommended-but-not-enforced single entry point for engine code; concrete classes remain importable but the convention is `createBackend({kind})`.
- Scope simplified vs ledger (per ledger §Implementation notes lines 84-93) — the simplification is the architecturally correct call: pure function with no I/O, settings-layer resolution moved up to the caller per future F-067 (M8 settings shape). The factory itself is deterministic and testable in isolation; settings are tested separately when F-067 lands.
- TypeScript exhaustive-switch `never`-arm pattern is the right realization of `BackendNotRegistered`. Compile-time check (TS2322 if a new BackendKind doesn't have a case) + runtime throw is stronger than a runtime registry-lookup pattern. F-018 uses the same exhaustivity pattern for `HaltTrigger` per the F-018 review's notes — F-012 reinforces the convention.
- 6/6 acceptance scenarios PASS at GREEN time. Full suite at GREEN time: 151/151 across 22 test files (was 136/136 across 20 pre-F-012/F-013) per ledger §Implementation notes.
- Forward extension is named: F-124 (multi-tier model routing, frontier-research candidate) plugs into this factory by extending `BackendKind` and adding routing predicates above the call site without touching the factory body. The two-line change (extend union + add case) is the discipline.

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 78)**

- F-012 is a **mechanical-routing** feature today: dispatch by kind, forward model parameter, throw on unknown. The behavior is deterministic and testable — but it's also narrow. The ledger §Behavior contract (lines 47-49) names the factory as "the ONLY supported way for engine code to obtain a provider" with a "lint rule" forbidding direct instantiation. **The lint rule does not exist yet.** Engine code can still `import { AnthropicBackend } from './backend-anthropic.js'` and instantiate it directly. The recommendation is documented but not enforced.
- Scope simplification recorded openly per `no-silent-deferrals.md` is the right move — the wave-002 ledger's `createBackendProvider(name, opts)` + `MAD_BACKEND` env override + `BackendNotRegistered` exception class + lint rule were all aspirational. The wave-015 / lane-d implementation honors the architectural intent (single dispatch point, type-safe routing) without the ceremony. But a reader of the original ledger contract may need the §Implementation notes paragraph (lines 84-93) to reconcile.
- LOCKED status here is therefore narrowly "**F-012 simplified-shape LOCKED**" — the original ledger's `createBackendProvider(name, opts)` + `MAD_BACKEND` env override + named `BackendNotRegistered` class are explicitly retired in favor of `createBackend({kind, model})` + caller-resolves-env + TS exhaustive-switch never-arm. Documented in §Implementation notes.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `packages/engine-core/src/backend-factory.ts` lines 1-96 directly + the ledger lines 1-114 directly. The implementation matches the §Implementation notes; `BackendNotRegistered` is not a class but a runtime `Error` with the kind in the message; the never-arm exhaustivity check is at line 92.
- Suggestion (NON-BLOCKING per `no-silent-deferrals.md`): the lint rule that forbids direct concrete-class instantiation should be authored as a follow-up F-NNN under M0 (or M16 telemetry-and-discipline if pattern-enforcement lives there). Without it, the "factory is the ONLY entry point" claim is convention, not enforcement. Today the convention holds because the codebase is small; at wave-30 it may slip.
- Suggestion (NON-BLOCKING): the runtime `throw new Error('Unknown backend kind: <kind>')` shape returns a generic `Error`, not a typed `BackendNotRegistered` exception. Engine code that wants to catch this specific failure mode has to string-match the message. When F-018 / F-021 / F-022 governance failure-pattern features mature their typed-error story, F-012's runtime throw should align.
- Suggestion (NON-BLOCKING): `model: string` is loosely typed — there is no validation that the model name actually matches the backend's catalog. F-010 + F-011 forward the model into their stub bodies without validation; the real-SDK swap will need to validate. Flag this for the F-010/F-011 real-SDK swap waves and for F-124 (multi-tier routing).

## Architect lens

**Verdict: APPROVE (confidence 90)**

- File-location posture: `packages/engine-core/src/backend-factory.ts` — correct shape per the wave-011 / lane-a engine-core split convention. F-012's file is its own; no contention with F-009/F-010/F-011/F-013.
- API surface review:
  - `BackendKind = 'anthropic' | 'copilot' | 'stub'` — string-literal union. Adding a new value is a deliberate two-line change (extend union + add case) per the file header docs at lines 47-49. Compile-time enforced via `_exhaustive: never`. Stronger than a runtime registry lookup; the type system is the contract surface.
  - `BackendFactoryOptions { kind: BackendKind; model?: string }` — minimal options interface. `model` is optional and forwarded positionally to AnthropicBackend / CopilotBackend constructors via the default-parameter mechanism. StubBackend ignores the model (no model concept in stub). Forwarding logic at lines 80-85.
  - `createBackend(opts: BackendFactoryOptions): IBackendProvider` — return type is the interface, not the concrete class. Engine consumers cannot accidentally narrow to a provider-specific surface; if they need narrowing, they import the concrete class directly (which is currently allowed but conventionally discouraged per the §Behavior contract).
  - Pure-function shape: no I/O, no env reads, no file reads, no side effects. Pure I/O (kind in → provider out) makes the factory unit-testable in isolation; settings-layer resolution lives in the caller.
- TypeScript exhaustive-switch `_exhaustive: never` pattern at lines 86-94: this is the canonical TS pattern for compile-time exhaustivity. Adding a new BackendKind without a case fails TS2322 on the assignment. The runtime throw covers the case where an external string is cast as BackendKind to bypass the type system (config files, env vars, IPC messages from M5/M6). F-018 uses this pattern for HaltTrigger; F-012 reinforces the convention. Per the F-009 review's F4 finding, the additive-extension path is well-defined.
- Composition with F-009 + F-010 + F-011 + StubBackend:
  - Imports: `IBackendProvider` (type) + `StubBackend` (class) from `./backend.js` (F-009's file); `AnthropicBackend` from `./backend-anthropic.js`; `CopilotBackend` from `./backend-copilot.js`. Concrete classes are imported by the factory; engine code imports the factory function. The dependency direction is correct: factory depends on concrete; engine depends on factory.
  - The "shared types live with their FIRST owner" convention (wave-011 / lane-a) is honored: F-009 owns `IBackendProvider` + `StubBackend`; F-010 owns `AnthropicBackend`; F-011 owns `CopilotBackend`; F-012 owns the routing layer. No type leaks across files.
- Forward path for F-124 (multi-tier routing) is documented at file header lines 23-30. The forward extension is additive (extend BackendKind + add case); the routing predicate (Haiku for cheap calls, Opus for hard reasoning) lives ABOVE the factory call site. F-012's body does not need to change for F-124 to land.
- Halt + run-id forward path: `createBackend` does not take run-id or session config — it returns a stateless provider class. Per-session state is per-instance (held by the AnthropicBackend / CopilotBackend instances). This is the right separation: the factory is identity-free; sessions are identity-bearing (via F-002's Agent/Session in BackendSessionConfig).

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | The "factory is the ONLY supported way for engine code to obtain a provider" claim in the §Behavior contract is convention, not enforcement. The lint rule that forbids direct concrete-class instantiation does not exist yet. | Accept; flag as a follow-up F-NNN candidate (M0 scaffolding-discipline or M16 telemetry-and-discipline). Today the codebase is small enough that the convention holds. |
| F2 | MINOR | Scope simplification from wave-002 ledger (`createBackendProvider(name, opts)` + `MAD_BACKEND` env override + named `BackendNotRegistered` exception class + lint rule) recorded openly in §Implementation notes. The simplified shape is correct; the original was aspirational. | Accept; the divergence is documented; the simplification is architecturally correct. |
| F3 | MINOR | Runtime `throw new Error('Unknown backend kind: <kind>')` returns a generic Error, not a typed exception. Engine code catching this specific failure mode needs to string-match. | Accept; align with the F-018/F-021/F-022 typed-error story when those features mature. |
| F4 | MINOR | `model: string` is loosely typed — no validation against the backend's catalog. F-010 + F-011 forward the model into stub bodies without validation; the real-SDK swap will need to validate. | Accept; flag for the F-010/F-011 real-SDK swap waves and for F-124 (multi-tier routing). |
| F5 | PRAISE | TypeScript exhaustive-switch `_exhaustive: never` pattern at lines 86-94 is the canonical TS pattern for compile-time exhaustivity. Compile-time check + runtime throw is stronger than a runtime registry lookup. F-018 uses the same pattern for HaltTrigger; F-012 reinforces the convention. | Keep. |
| F6 | PRAISE | Pure-function shape (no I/O) makes the factory deterministic and testable in isolation. Settings-layer resolution moved up to the caller per future F-067 — separation of concerns is clean. | Keep. |
| F7 | PRAISE | Forward path for F-124 (multi-tier routing) is documented at file header lines 23-30. Additive extension; the factory body does not need to change. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 90).

F-012 simplified-shape contract is implemented correctly; all 6 acceptance scenarios pass per the recorded green-test-output proof; no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-012 ledger frontmatter (`LOCKED if GREEN AND reviews/F-012-backend-factory-review.md exists with verdict: ACCEPT`).

The MINOR findings F1+F2+F3+F4 are honest scope-narrowing notes per `no-silent-deferrals.md` — the lint-rule deferral, the scope simplification from the original ledger, the typed-error future-alignment, and the model-validation forward path are all documented. Nothing is silent.

F-012 transitions GREEN → LOCKED.

## Cross-references

- Ledger: `docs/03-feature-catalog/M1-backend/F-012-backend-factory.md`
- Source: `packages/engine-core/src/backend-factory.ts` (~96 LOC)
- Tests: `tests/unit/F-012-backend-factory.test.ts` (6/6 PASS)
- GREEN proof: `docs/09-examples-proof/F-012/` (red-test-output + green-test-output + physical-proof)
- GREEN transition: decision-log.md F-012 row; wave-015 / lane-d
- Composing features: F-009 (`IBackendProvider`, `StubBackend`), F-010 (`AnthropicBackend`), F-011 (`CopilotBackend`)
- Forward path: F-124 (multi-tier routing, frontier-research candidate)
- Pattern: TS exhaustive-switch `_exhaustive: never` (also used in F-018 HaltTrigger)
- Review verdict envelope: per `docs/05-design-reviews/README.md` (APPROVE / APPROVE-WITH-SUGGESTIONS / WAIT-FOR-AUTHOR / REJECT)
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle (Reviewer summary table + Median confidence + Decision)
