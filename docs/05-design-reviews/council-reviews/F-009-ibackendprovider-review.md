---
artifact-class: council-review
feature-id: F-009
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-015 / lane-a
---

# F-009 ibackendprovider — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 91 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 76 |
| architect-lens | Architect | APPROVE | 89 |

Median confidence: 89

## Implementation reviewed

- `packages/engine-core/src/backend.ts` (205 LOC) — `IBackendProvider` interface (5 members: `origin: string`, `startSession(config) → Promise<{sessionId}>`, `sendPrompt(sessionId, prompt) → AsyncGenerator<BackendEvent>`, `halt(sessionId, verdict) → Promise<void>`, `stopSession(sessionId) → Promise<void>`); `BackendEvent` discriminated union (`token` | `tool_call` | `tool_result` | `finish`); `BackendSessionConfig` composing F-002 `Agent` + `Session`; `StubBackend` deterministic test fixture.
- `packages/engine-core/src/index.ts` — barrel re-export adds `export * from './backend.js';`.
- `tests/unit/F-009-ibackend-provider.test.ts` (163 LOC) — 6 scenarios: structural-witness (interface present + StubBackend constructible); `startSession` returns sessionId; `sendPrompt` streams `token` then `finish`; unknown sessionId throws via iterator reject; `halt` accepts `RunHaltedVerdict` and removes session; `stopSession` removes session. All PASS per `docs/09-examples-proof/F-009/green-test-output.txt`.
- Commit history per `docs/07-roadmap/decision-log.md`: F-009 RED at wave-002 / lane-b (initial ledger only); F-009 GREEN at wave-014 / lane-d, impl commit `4cb2417`.

## Advocate lens

**Verdict: APPROVE (confidence 91)**

- Implementation is minimal and correct per `minimum-change.md`. ~190 LOC delivers the entire backend-pluggability contract: 1 interface + 1 discriminated union + 1 config type + 1 deterministic stub fixture. No premature abstraction; no helper functions invented before they have a caller.
- Composition with F-002 + F-018 is clean. `BackendSessionConfig` requires `agent: Agent` + `session: Session` (from `identity.ts`) — runId / agentId thread through every started session for downstream F-014 (retro), F-015 (audit), F-019 (cost) consumption. `halt(sessionId, verdict: RunHaltedVerdict)` accepts the F-018 verdict shape — when F-020 (kill-switch) / F-022 (tool-quota) / F-018 (overplanning) triggers fire, the verdict flows through to the provider so cleanup is routed by trigger.
- 6/6 acceptance scenarios PASS at GREEN time (10ms total runtime). Full suite at GREEN: 122/122 PASS across 18 test files.
- StubBackend is the right fixture shape: `origin === "stub"`, `sendPrompt` yields a single token then finish, `halt` and `stopSession` are idempotent. Used by F-009's own tests today; future F-012 factory tests (origin routing), F-018 / F-020 / F-022 halt-integration tests, and any backend-consuming feature reuse it.
- F-009 is the FIRST M1 feature flipped — opens the milestone. The interface is the contract; F-010 (Anthropic) + F-011 (Copilot) + F-012 (factory) + F-013 (event-normalization) plug into this contract without touching this surface. LOCKED here makes the M1 contract permanent.
- The "shared types live with their FIRST owner" convention from wave-011 / lane-a engine-core split extends cleanly to M1: `Agent` + `Session` stay in `identity.ts` (F-002's first-owner), `RunHaltedVerdict` stays in `halt.ts` (F-018's first-owner), F-009 imports from both without owning the types itself.

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 76)**

- F-009 is a **contract-shape** feature today: real backend integration (Anthropic SDK call, Copilot SDK call, event-normalization across providers, factory routing) is NOT yet implemented. The current `StubBackend` yields a synthetic single-token response; no actual LLM call happens.
- Scope deviation from original wave-002 ledger is significant — recorded openly per `no-silent-deferrals.md` in §Implementation notes. The original ledger named `complete(prompt, opts) → AsyncIterable<NormalizedEvent>` paired with `cancel(handle)`, `listModels() → ModelInfo[]`, and `name: BackendName`. The wave-014 / lane-d implementation uses a session-oriented surface (`startSession` / `sendPrompt` / `halt` / `stopSession`) carrying a discriminated `BackendEvent` union. The session shape is a strict generalization (sendPrompt returns AsyncGenerator<BackendEvent>, preserving the iterator-of-events pattern) and adds a halt path (`halt(sessionId, verdict)`) that composes with F-018 — but a reader of the original ledger contract needs to know the API shape changed.
- LOCKED status here is therefore narrowly "**F-009 session-oriented contract shape LOCKED**" — the original ledger's `complete()` / `cancel()` / `listModels()` shape is explicitly retired in favor of the session surface. The §Implementation notes paragraph explains why (composes with F-018 RunHaltedVerdict; `listModels` is provider-specific and best deferred to F-012 factory; `cancel(handle)` semantically split into `halt(verdict)` + `stopSession()`).
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `packages/engine-core/src/backend.ts` lines 1-205 directly + the test lines 1-163. The interface + StubBackend match the §Implementation notes; the original ledger's `complete()` / `cancel()` / `listModels()` shape does NOT exist on disk. This is a documented divergence, not a hidden one.
- Suggestion (NON-BLOCKING per `no-silent-deferrals.md`): when F-010 / F-011 land, the wave that implements the Anthropic + Copilot providers should re-verify that the session-oriented contract maps cleanly to the underlying SDKs. The Anthropic SDK exposes a streaming completion API; the Copilot SDK exposes a session API. Both should map; if either doesn't, the F-009 contract may need a minor extension. The deferral is forward-known.
- Suggestion (NON-BLOCKING): `BackendEvent` discriminated union has 4 variants (`token` / `tool_call` / `tool_result` / `finish`). F-013 (event-normalization) is responsible for mapping provider-specific events into this canonical shape. If F-013 surfaces a 5th meaningful variant (e.g., `thinking` / `reasoning` / `usage` / `error`), the F-009 union grows additively (no breaking change). Flagging for F-013's first author to consider.

## Architect lens

**Verdict: APPROVE (confidence 89)**

- File-location posture: `packages/engine-core/src/backend.ts` — correct shape per the wave-011 / lane-a engine-core split convention (per-feature files instead of a single `index.ts`). F-009 owns its file; F-010 / F-011 will own their concrete-provider files; F-012 will own the factory file. Clean separation of concerns; no engine-core-staging-race risk per the wave-013/14 lane-shipping pattern.
- API surface review:
  - `IBackendProvider` interface (TypeScript `interface`, not `type`) — declaration-merging is intentional. F-013 event-normalization and F-124 multi-tier-routing may extend the interface in their own files (e.g., adding optional `getModelInfo()`); `interface` allows merge across multiple files; `type` would force every extension to touch this file.
  - `origin: string` (not a `BackendName` union) — replaces the original ledger's `name: BackendName` choice. String-typed `origin` means adding a new provider doesn't require a type-system change. The trade-off: factory routing (F-012) needs explicit string comparison in a switch/dispatch table; mistyping `"anthropic"` as `"antrhopic"` is a runtime bug, not a compile-time bug. Acceptable for a v1 single-machine trust model — F-012's own tests will catch the typos.
  - `sendPrompt(sessionId, prompt) → AsyncGenerator<BackendEvent>` — the iterator-of-events pattern is the canonical async-stream shape in modern JS. Consumers can `for await` cleanly; cancellation flows through the generator's `.return()` method.
  - `halt(sessionId, verdict: RunHaltedVerdict)` — accepts the canonical halt verdict from F-018. The signature change (vs original ledger's `cancel(handle)`) is the right composition: the verdict carries trigger-specific cleanup metadata so providers can route shutdown by reason.
- Composition with F-002 + F-018: `BackendSessionConfig` requires `Agent` + `Session`; `halt` accepts `RunHaltedVerdict`. The "shared types live with their FIRST owner" rule means F-002 owns `Agent` + `Session` (in `identity.ts`); F-018 owns `RunHaltedVerdict` (in `halt.ts`); F-009 imports from both without owning the shape. Forward-compatible: F-002 or F-018 can extend their types; F-009 inherits the extension automatically.
- No surprises in dependencies: F-009 has F-001 (engine cycles) + F-002 (identity composition) + F-018 (halt verdict) as hard deps (per ledger frontmatter `depends-on: [F-001, F-002, F-018]` — though the on-disk ledger only lists `[F-001]`; F-002 + F-018 are de-facto deps via the `Agent` + `RunHaltedVerdict` imports). F-013 (event normalization) is a soft dep — F-009 defines the union; F-013 wires concrete providers into it.

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | F-009 is contract-shape only; concrete provider integration (F-010 Anthropic, F-011 Copilot) + factory routing (F-012) + event normalization (F-013) are RED. The contract is permanent, the consumers haven't been built. | Accept; LOCKED status applies to the contract-shape scope explicitly. F-010..F-013 follow-ons are tracked as separate features in the M1 milestone. |
| F2 | MINOR | Scope deviation from original wave-002 ledger (`complete()` / `cancel()` / `listModels()` / `name: BackendName`) → session-oriented surface (`startSession` / `sendPrompt` / `halt` / `stopSession`). Recorded openly in §Implementation notes per `no-silent-deferrals.md`. | Accept; the divergence is documented; the new shape generalizes the old (sendPrompt returns AsyncGenerator<BackendEvent>) and adds the F-018-composing halt path. |
| F3 | MINOR | `origin: string` instead of typed `BackendName` union — adding a new provider doesn't require a type-system change but mistyping a name is a runtime bug. F-012 factory tests catch typos. | Accept; v1 single-machine trust model; revisit if cross-machine factory routing surfaces typo-driven failures. |
| F4 | MINOR | `BackendEvent` union has 4 variants today; F-013 may surface a 5th meaningful variant (thinking / usage / error). The union grows additively (no breaking change). | Accept; flagged for F-013's first author. |
| F5 | PRAISE | `IBackendProvider` declared as `interface` (not `type`) enables future declaration-merging from F-013 / F-124 without touching this file. Forward-extension-friendly. | Keep. |
| F6 | PRAISE | StubBackend deterministic test fixture is the right shape: `origin === "stub"`, idempotent `halt` / `stopSession`, single-token-then-finish on `sendPrompt`. Reused by F-012 / F-018 / F-020 / F-022 future tests without re-authoring. | Keep. |
| F7 | PRAISE | Composition with F-002 (`Agent` + `Session`) + F-018 (`RunHaltedVerdict`) is clean — F-009 imports without owning, per the wave-011 / lane-a "shared types live with their FIRST owner" convention. M1 inherits the M0-M2 type-ownership discipline. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 89).

F-009 session-oriented contract shape is implemented correctly; all 6 wave-014-scoped acceptance scenarios pass per the recorded green-test-output proof; no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-009 ledger frontmatter (`LOCKED if GREEN AND reviews/F-009-ibackendprovider-review.md exists with verdict: ACCEPT`).

The MINOR findings are honest scope-narrowing notes per `no-silent-deferrals.md` — F1 (concrete providers F-010/F-011 + factory F-012 + event-normalization F-013 remain RED), F2 (scope deviation from original ledger recorded openly), F3 (`origin: string` vs typed union design choice), F4 (additive union extension path) are surfaced in this review and in the F-009 ledger §Implementation notes + §Out-of-scope-notes. No finding is silent.

F-009 transitions GREEN → LOCKED.

## Cross-references

- Ledger: `docs/03-feature-catalog/M1-backend/F-009-ibackendprovider.md`
- Source: `packages/engine-core/src/backend.ts` (205 LOC), `packages/engine-core/src/index.ts` (barrel re-export)
- Tests: `tests/unit/F-009-ibackend-provider.test.ts` (6/6 PASS)
- GREEN proof: `docs/09-examples-proof/F-009/` (red-test-output + green-test-output + physical-proof)
- GREEN transition: decision-log.md (F-009 RED → GREEN row); impl commit `4cb2417`; wave-014 / lane-d
- Composing features: F-002 (`Agent` + `Session` from `identity.ts`), F-018 (`RunHaltedVerdict` from `halt.ts`)
- Review verdict envelope: per `docs/05-design-reviews/README.md` (APPROVE / APPROVE-WITH-SUGGESTIONS / WAIT-FOR-AUTHOR / REJECT)
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle (Reviewer summary table + Median confidence + Decision)
