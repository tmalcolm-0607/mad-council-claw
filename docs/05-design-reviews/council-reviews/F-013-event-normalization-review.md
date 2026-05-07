---
artifact-class: council-review
feature-id: F-013
review-type: post-impl-council
date: 2026-05-07
reviewers: [advocate-lens, skeptic-lens, architect-lens]
status: complete
verdict: ACCEPT
wave: wave-016 / lane-a
---

# F-013 event-normalization — post-impl council review

## Decision: ACCEPT (Verdict consensus: APPROVE)

## Reviewer summary

| Reviewer | Role | Verdict | Confidence |
|---|---|---|---|
| advocate-lens | Advocate | APPROVE | 90 |
| skeptic-lens | Skeptic | APPROVE-WITH-SUGGESTIONS | 74 |
| architect-lens | Architect | APPROVE | 88 |

Median confidence: 88

## Implementation reviewed

- `packages/engine-core/src/backend-events.ts` (~115 LOC) — 4 type guards (`isTokenEvent`, `isToolCallEvent`, `isToolResultEvent`, `isFinishEvent`) using `Extract<BackendEvent, { type: '<variant>' }>` narrowing returns; 1 content-extractor function (`eventTextContent(e: BackendEvent): string`) returning verbatim text for tokens, deterministic descriptors for tool/finish events; exhaustive-switch witness in eventTextContent (`const _exhaustive: never = e`).
- `packages/engine-core/src/index.ts` — barrel re-export `export * from './backend-events.js';`.
- `tests/unit/F-013-backend-event-normalization.test.ts` — 9 scenarios: 4 type-guard checks (one per BackendEvent variant); 4 content-extractor checks (one per variant including the finish-with-details edge case); 1 cross-provider witness exercising StubBackend + AnthropicBackend + CopilotBackend through the same union. 9/9 PASS at GREEN time per ledger §Implementation notes.
- Commit history per `docs/07-roadmap/decision-log.md`: F-013 RED at wave-002 / lane-b; F-013 GREEN at wave-015 / lane-d.
- GREEN proof: `docs/09-examples-proof/F-013/` (red-test-output + green-test-output + physical-proof) per ledger §Implementation notes.

## Advocate lens

**Verdict: APPROVE (confidence 90)**

- Implementation is minimal and correct per `minimum-change.md`. ~115 LOC delivers the entire convenience layer: 4 type guards + 1 content-extractor. No premature abstraction — no event mapper class, no provider-specific normalization registry, no SDK-event translation table.
- F-013 is the **fifth M1 feature** flipped (after F-009 LOCKED + F-010 GREEN + F-011 GREEN + F-012 GREEN at wave-015) — closes the M1 RED-clear at GREEN. The convenience layer satisfies the ledger's "cross-SDK normalization" goal because F-009's `BackendEvent` union is ALREADY the normalized shape across all backends (StubBackend, AnthropicBackend, CopilotBackend all emit identical events). F-013's contribution is the consumer-facing helpers so downstream features (F-014 retro, F-015 audit, F-019 cost-ledger) don't re-implement discriminated-union narrowing.
- Scope simplification recorded openly per `no-silent-deferrals.md` is the right call. The wave-002 ledger named a 9-variant `NormalizedEvent` union; the wave-014 / lane-d F-009 implementation already settled on a 4-variant `BackendEvent` union that covers the M2 governance triad's observability requirements (token stream, tool dispatch, tool result, terminal state). The 5 missing variants (`message_start`, `tool_use_input_delta`, `usage`, `cancelled`, `error`) are tracked for the future event-richness wave; `error` is partially covered today by `{type:'finish', reason:'error', details}`.
- 9/9 acceptance scenarios PASS at GREEN time. Full suite at GREEN time: 151/151 across 22 test files (was 136/136 across 20 pre-F-012/F-013) per ledger §Implementation notes.
- Type guards use `Extract<BackendEvent, { type: '<variant>' }>` — TypeScript's canonical pattern for narrowing a discriminated union. Consumers can write `if (isTokenEvent(e)) e.text` without a manual `if (e.type === ...)` re-check. The ergonomics improvement is real and small.
- The cross-provider witness scenario (1 of the 9 tests) exercises all three backends through the same union — proves F-009's "cross-SDK normalization is satisfied by the union shape itself" claim from the F-009 review F4 finding.

## Skeptic lens

**Verdict: APPROVE-WITH-SUGGESTIONS (confidence 74)**

- F-013 is a **convenience-layer** feature today: 4 type guards and 1 content-extractor. The ledger §Behavior contract (lines 47-49) describes a richer normalization story — "every provider maps its native event stream to this shape" — but the actual normalization mapping (Anthropic `content_block_delta` → `BackendEvent token`; Copilot CLI line buffering → `BackendEvent token`) does NOT exist in F-013's file. The mapping lives alongside each backend's real-impl swap (per the file header lines 21-26 and the ledger §Implementation notes lines 113-118).
- LOCKED status here is therefore narrowly "**F-013 convenience-layer LOCKED**" — the type guards + content-extractor are permanent; the cross-SDK normalization CONTRACT (the 4-variant union) was already locked when F-009 was LOCKED at wave-015 / lane-a. F-013 contributes the helpers; the union itself is F-009's owned shape.
- Verification check (per `verification-protocol.md` Rule 1 FETCH BEFORE CITE): I read `packages/engine-core/src/backend-events.ts` lines 1-115 directly + the ledger lines 1-126 directly. The implementation matches the §Implementation notes; the file imports `BackendEvent` from `./backend.js` (F-009's file) and contributes only helpers; no provider-specific mapping function exists.
- Scope deviation from wave-002 ledger (9-variant `NormalizedEvent` → 4-variant `BackendEvent` reuse + helpers) is significant — recorded openly per `no-silent-deferrals.md` in §Implementation notes lines 87-111. The 5 missing variants are tracked. A reader of the original ledger contract (lines 44-54) needs the §Implementation notes paragraph to reconcile the gap.
- Suggestion (NON-BLOCKING per `no-silent-deferrals.md`): when the real `@anthropic-ai/sdk` integration lands (F-010 real-SDK swap, gated on F-070 secure-storage), the SDK emits `message_start` + `content_block_delta` + `message_stop` events that F-013's union currently does not have first-class slots for. The mapping is `content_block_delta → token`; `message_start` + `message_stop` are folded into the iterator's start/end (current `finish/stop` covers `message_stop`; `message_start` is observable as the first event). When the SDK swap lands, the wave should re-verify that the union still covers the observability requirements OR additively extends the union per the F-009 review F4 finding.
- Suggestion (NON-BLOCKING): `usage` events (token counts) are tracked for the future event-richness wave. F-019 (cost-ledger, LOCKED at wave-13 / lane-d) currently consumes cost data via a separate channel (per the F-019 review). When the union adds `usage`, F-019 should be updated to consume token counts via the BackendEvent stream rather than a separate channel — that integration is owned by a future cost-attribution wave, not F-013.
- Suggestion (NON-BLOCKING): the content-extractor format choice (lines 92-100 of the file header) deliberately does NOT serialize tool `arguments` / `result` payloads into the descriptor (because they're arbitrary-shape and may be large). Consumers that need the payload narrow with the type guards and access the field directly. This is the right call for a convenience helper, but a consumer wanting a complete log line for audit may want a richer formatter; that's a future helper, not F-013's scope.

## Architect lens

**Verdict: APPROVE (confidence 88)**

- File-location posture: `packages/engine-core/src/backend-events.ts` — correct shape per the wave-011 / lane-a engine-core split convention. F-013's file is the consumer-facing helpers; F-009's `backend.ts` owns the union itself; the separation is clean.
- API surface review:
  - 4 type guards: `isTokenEvent`, `isToolCallEvent`, `isToolResultEvent`, `isFinishEvent` — each takes `e: BackendEvent` and returns `e is Extract<BackendEvent, { type: '<variant>' }>`. The `Extract` utility-type pattern is the canonical TS narrowing primitive; no custom type-predicate plumbing.
  - `eventTextContent(e: BackendEvent): string` — content-extractor with deterministic format. Token events surface their `text` verbatim; tool events surface `[tool_call: <name>]` / `[tool_result: <name>]`; finish events surface `[finish: <reason>]` with optional details suffix joined by single space (covered by scenario 5 per ledger §Acceptance scenarios). The format is documented at the function's docstring (file header lines 92-100).
  - Exhaustive-switch witness in eventTextContent (lines 107-112): `const _exhaustive: never = e` after the 4 if-branches. Adding a new BackendEvent variant without a branch fails TS narrowing — `e` is no longer narrowed to `never` and the assignment fails TS2322 at compile time. The empty-string fallback is a runtime safety net for the never-can-happen path. F-012 uses the same pattern for `BackendKind`; F-018 uses it for `HaltTrigger`. Convention is consistent across the engine-core.
- Composition with F-009 + F-010 + F-011 + StubBackend:
  - Imports: `BackendEvent` (type) from `./backend.js` (F-009's file). Single import, single dependency.
  - The "shared types live with their FIRST owner" convention is honored: F-009 owns `BackendEvent`; F-013 owns the helpers that operate on it. No type leak; no duplicate definition.
  - The cross-provider witness scenario (1 of 9 tests) exercises StubBackend + AnthropicBackend + CopilotBackend through the same union — empirical validation of the F-009 review's "cross-SDK normalization is satisfied by the union shape itself" claim.
- Scope-simplification rationale (4-variant reuse vs 9-variant superset) is architecturally sound per the ledger §Implementation notes lines 87-111. The 4-variant union covers the M2 governance triad's observability requirements; richer variants (`usage`, `message_start`, `tool_use_input_delta`, `cancelled`, `error`) are additive extensions per the F-009 review F4 finding — adding them later does NOT break existing consumers because the discriminated-union shape allows new variants.
- Forward path for SDK-specific mapping (Anthropic `content_block_delta` → `token`; Copilot CLI line-buffering → `token`) lives alongside each backend's real-impl swap per file header lines 21-26 + ledger §Implementation notes lines 113-118. The mapping function CO-LOCATES with the SDK call, not with F-013's helpers. The architectural separation is deliberate: F-013 is downstream-consumer-facing; the mapping is upstream-provider-facing.
- Forward path for OpenTelemetry GenAI semantic-convention spans (F-123, M16 frontier-research candidate) consumes the same union via OTel exporters per ledger §Implementation notes lines 120-122. The 9-variant superset, when needed, is an additive change; existing consumers stay compatible.

## Findings

| # | Severity | Finding | Disposition |
|---|---|---|---|
| F1 | MINOR | F-013 is convenience-layer-shaped today; the cross-SDK normalization MAPPING (Anthropic `content_block_delta` → `BackendEvent token`; Copilot CLI line-buffering → `BackendEvent token`) lives alongside each backend's real-impl swap, not in F-013's file. F-013 contributes the helpers, not the mapping. | Accept; LOCKED status applies to the convenience-layer scope explicitly. The mapping is co-located with the SDK call by design. |
| F2 | MINOR | Scope simplification from wave-002 ledger (9-variant `NormalizedEvent` → 4-variant `BackendEvent` reuse + helpers) recorded openly in §Implementation notes lines 87-111. The 5 missing variants (`message_start`, `tool_use_input_delta`, `usage`, `cancelled`, `error`) are tracked for the future event-richness wave. | Accept; the simplification is correct because every concrete backend already emits identical events; the union shape itself is the normalization. |
| F3 | MINOR | When the real `@anthropic-ai/sdk` integration lands, the SDK's richer event taxonomy (e.g., `usage` token counts) may want first-class slots in the union. The future event-richness wave should re-verify and additively extend the union per the F-009 review F4 finding. | Accept; flagged for the future event-richness wave. |
| F4 | MINOR | The content-extractor format choice does NOT serialize tool `arguments` / `result` payloads into the descriptor (because they're arbitrary-shape). Consumers that need a complete log line for audit may want a richer formatter; that's a future helper, not F-013's scope. | Accept; the design choice is documented at file header lines 92-100. |
| F5 | PRAISE | `Extract<BackendEvent, { type: '<variant>' }>` narrowing is the canonical TS pattern for type guards on discriminated unions. No custom type-predicate plumbing. Forward-compatible with additive union extension. | Keep. |
| F6 | PRAISE | Exhaustive-switch witness in eventTextContent (lines 107-112) follows the same pattern as F-012 (BackendKind) and F-018 (HaltTrigger). Compile-time + runtime safety net is consistent across engine-core. | Keep. |
| F7 | PRAISE | The cross-provider witness scenario (1 of 9 tests) empirically validates the F-009 review's "cross-SDK normalization is satisfied by the union shape itself" claim — F-013 is the proof that the union shape, not a normalization mapper, is the load-bearing primitive. | Keep. |

No CRITICAL findings. No MAJOR findings. No findings block.

## Decision rationale

**ACCEPT** (Verdict consensus: APPROVE; median confidence 88).

F-013 convenience-layer contract is implemented correctly; all 9 acceptance scenarios pass per the recorded green-test-output proof; no CRITICAL or MAJOR findings; review verdict ACCEPT per the `red-green-rule` predicate in the F-013 ledger frontmatter (`LOCKED if GREEN AND reviews/F-013-event-normalization-review.md exists with verdict: ACCEPT`).

The MINOR findings F1+F2+F3+F4 are honest scope-narrowing notes per `no-silent-deferrals.md` — the convenience-layer scope, the scope simplification from the original ledger, the future event-richness alignment, and the audit-formatter forward path are all documented. Nothing is silent.

F-013 transitions GREEN → LOCKED.

**This LOCKED transition closes M1 100% LOCKED for the active feature set (F-009 + F-010 + F-011 + F-012 + F-013 — 5 of 5).**

## Cross-references

- Ledger: `docs/03-feature-catalog/M1-backend/F-013-event-normalization.md`
- Source: `packages/engine-core/src/backend-events.ts` (~115 LOC)
- Tests: `tests/unit/F-013-backend-event-normalization.test.ts` (9/9 PASS)
- GREEN proof: `docs/09-examples-proof/F-013/` (red-test-output + green-test-output + physical-proof)
- GREEN transition: decision-log.md F-013 row; wave-015 / lane-d
- Composing features: F-009 (`BackendEvent` union owner), F-010 / F-011 / StubBackend (event producers exercised in cross-provider witness scenario)
- Forward path: F-123 (OTel GenAI semantic-convention spans, M16 frontier-research) + future event-richness wave (additive extension to add `message_start`, `tool_use_input_delta`, `usage`, `cancelled`, `error`)
- Pattern: TS exhaustive-switch `_exhaustive: never` (also used in F-012 BackendKind + F-018 HaltTrigger)
- Review verdict envelope: per `docs/05-design-reviews/README.md` (APPROVE / APPROVE-WITH-SUGGESTIONS / WAIT-FOR-AUTHOR / REJECT)
- Kit rule: `.claude/rules/council-verdict-artifact.md` validity oracle (Reviewer summary table + Median confidence + Decision)
