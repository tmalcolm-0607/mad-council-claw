---
artifact-class: feature-ledger
generated-by: hand-authored (wave-019 / lane-b)
status: green
status-since: 2026-05-07
status-history:
  - status: red
    at: 2026-05-07
    by: wave-019 / lane-b
    note: "Initial creation. Behavior contract + 6 acceptance scenarios drafted. Promoted from wave-016/lane-d Copilot CLI design review C-2 (Opus Critical, single-model demoted under cross-model rule but reasoning concrete: F-019 cost ledger has no event source because BackendEvent has no usage variant — see D-36 in design-decisions-pending.md). Resolves the F-138 §out-of-scope-notes gap that names this feature explicitly: 'cycle.ts does NOT compute cost-ledger rows from BackendEvent because BackendEvent has no usage variant per wave-016 D-36. CostLedger is instantiated and totalUsd() reported in RunOutcome, but no rows are appended in v1. F-139 backend-event-usage-variant (D-36) closes this gap.' Lane B authors RED test scaffold + GREEN impl in same micro-session per the wave-5 retro proposal validated by F-138's RED-then-GREEN micro-session pattern. Owner milestone is M1 because the new variant extends BackendEvent which lives at packages/engine-core/src/backend.ts (F-009 owner); the variant-mapping helper lives at packages/engine-core/src/backend-event-variant.ts and reuses CostEntryInput from cost.ts (F-019 owner) without modifying cost.ts."
  - status: green
    at: 2026-05-07
    by: wave-019 / lane-b
    note: "RED test scaffold + impl landed in same lane (RED-then-GREEN micro-session per wave-5 retro proposal validated by F-138). Test at tests/unit/F-139-backend-event-usage-variant.test.ts (6 scenarios across one describe block). Impl at packages/engine-core/src/backend-event-variant.ts (~70 LOC: usageEventToCostEntry mapper + UsageEventContext + PriceLookup types). Additive extension to backend.ts (5th BackendEvent variant: usage); additive extension to backend-events.ts (isUsageEvent type guard + eventTextContent 5th branch returning [usage: input=N output=M cache_read=R cache_write=W] descriptor; const _exhaustive: never witness keeps compiling). 6/6 acceptance scenarios passing (full suite 323/323 across 38 test files via `pnpm test`). Resolves wave-016/lane-d D-36; F-138 cycle.ts can begin computing cost-ledger rows from BackendEvent in a future iteration. Cross-lane staging-race: per user directive 2026-05-07, NO `git reset` for staging-race recovery; explicit `git add <paths>` for each commit. RED commit aa1632d landed cleanly with no sweep; GREEN commit pending."
feature-id: F-139
short-slug: backend-event-usage-variant
milestone: M1
provenance:
  surfaces:
    - ce:FR-COST-001
    - cp:src/engine/backend-events
    - kit:rules/no-invented-constraints.md
fr-coverage: []
test-files:
  unit:
    - tests/unit/F-139-backend-event-usage-variant.test.ts
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects:
  - unit
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-139-backend-event-usage-variant-review.md exists with verdict: ACCEPT.
depends-on: [F-009, F-013, F-019]
out-of-scope-notes: |
  Per `rules/no-silent-deferrals.md`, the v1 surface is intentionally narrow:

  - **Concrete-backend usage emission** (F-010 AnthropicBackend + F-011 CopilotBackend
    yielding `{type:'usage', ...}` after `finish`). The stub bodies live with
    deferred real-SDK swaps per the F-010/F-011 ledgers' "stub-body-vs-deferred-
    real-SDK" idiom; emitting a real `usage` event requires the real SDK reporting
    token counts, which lands when those swaps land. F-139 ships the EVENT SHAPE
    + the type guard + the variant-to-CostEntryInput mapper; concrete backends
    plug in via `for await (const ev of provider.sendPrompt(...))` consumption.

  - **F-138 cycle.ts integration** (cycle.ts iterates BackendEvent stream and
    routes `usage` events to CostLedger.append). The mapping primitive lives
    here; the integration commit lives in a future cycle.ts iteration when
    the F-138 §out-of-scope-notes cost-rows-deferred clause closes. Per the
    orchestrator-identity rule, F-138 will compose this primitive without
    re-implementing it.

  - **Per-model price table** (`pricing/<backend>.json`). The F-019 ledger
    references this; F-139 v1 trusts the caller to compute `usd_estimate`
    from the usage event's token counts using whatever rate table they own.
    The mapper accepts an optional `pricePerToken` lookup callback for
    deterministic test inputs; production callers will integrate a real
    price table when the future feature lands.

  - **`cache_read_tokens` / `cache_write_tokens` discrimination**. The usage
    variant carries 4 token-count fields (`input_tokens`, `output_tokens`,
    `cache_read_tokens`, `cache_write_tokens`) per the F-019 ledger CostEntry
    schema. v1 maps all 4 verbatim; the cache-attribution analytics that
    distinguish prompt-cache hits from cold reads belong to a future M16
    telemetry feature, not the variant itself.

  - **Audit-pipeline integration** (every `usage` event emits an
    appendAuditEntry call alongside the cost row). F-138 already audits every
    BackendEvent via `audit.append('backend.event', { event })`; once F-138
    integrates F-139's mapper, the cost-row append happens in the same loop
    iteration as the audit append. Discrete audit category for usage events
    (e.g. `cost.row.appended` separate from `backend.event`) is a future
    audit-taxonomy refinement.

  - **Variant exhaustiveness in eventTextContent**. F-013's `eventTextContent`
    helper (backend-events.ts) currently has an exhaustive switch over the
    4-variant BackendEvent union with a `const _exhaustive: never = e` witness.
    Adding the `usage` variant requires extending eventTextContent with a 5th
    branch returning a deterministic descriptor (e.g. `[usage: input=N
    output=M cache_read=R cache_write=W]`). v1 ships the eventTextContent
    extension alongside the new variant so the never-witness keeps compiling.

  These deferrals are honest scope-narrowing per `no-silent-deferrals.md`;
  every primitive F-139 produces is the smallest unit that closes D-36.

confidence: high
---

# F-139 — Backend-event usage variant

## Behavior contract

The discriminated `BackendEvent` union (F-009 owner) gains a 5th variant: `{type:'usage', input_tokens, output_tokens, cache_read_tokens, cache_write_tokens, model, backend?}`. Concrete backends (F-010 AnthropicBackend, F-011 CopilotBackend) emit this variant after `finish` so engine-cycle composers (F-138) can compute cost-ledger rows (F-019 CostLedger) without re-implementing token-count extraction inside the backend. F-013's type-guard suite extends with `isUsageEvent(e)`; F-013's `eventTextContent` extends with a deterministic `[usage: ...]` descriptor; a new variant-to-CostEntryInput mapper at `packages/engine-core/src/backend-event-variant.ts` produces a F-019 CostLedger.append-ready row from one usage event + correlation context (run_id + agent_id + parent_run_id) + an optional `pricePerToken` lookup. Resolves wave-016/lane-d D-36 (Opus C-2): F-019 cost ledger now has an event source.

## Acceptance scenarios

1. **Given** a usage event `{type:'usage', input_tokens:1000, output_tokens:500, cache_read_tokens:0, cache_write_tokens:0, model:'claude-opus-4-7', backend:'anthropic'}` with correlation `{run_id:'r1', agent_id:'a1'}` and a price lookup returning `{input:0.000015, output:0.000075}`, **When** `usageEventToCostEntry(event, ctx, lookup)` is called, **Then** the returned `CostEntryInput` carries `tokens_in=1000, tokens_out=500, cache_read_tokens=0, cache_write_tokens=0, usd_estimate=0.0525, model='claude-opus-4-7', backend='anthropic'` and the F-019 CostLedger.append round-trip yields a CostEntry with `seq=0` and the same numeric fields.
2. **Given** an event of type `'token'`, **When** `isUsageEvent(event)` is called, **Then** it returns `false` (the type guard narrows `BackendEvent` to the new union member ONLY for `type==='usage'`).
3. **Given** a usage event with all 4 token-count fields populated (input=1000, output=500, cache_read=200, cache_write=100), **When** `usageEventToCostEntry` is called WITHOUT a price-lookup callback, **Then** the returned CostEntryInput carries `usd_estimate=0` (caller-deferred pricing) and ALL 4 token counts are mapped verbatim — including the cache fields per the F-019 ledger's CostEntry schema.
4. **Given** the F-013 `eventTextContent` helper is called on a usage event, **Then** it returns `[usage: input=N output=M cache_read=R cache_write=W]` deterministically (greppable for log-mining; consistent with the existing `[finish: <reason>]` and `[tool_call: <name>]` formats).
5. **Given** a usage event with `parent_run_id` present in the correlation context, **When** `usageEventToCostEntry` is called, **Then** the resulting CostEntryInput carries `parent_run_id` for cross-spawn cost attribution per F-019's parent_run_id contract.
6. **Given** the BackendEvent discriminated union, **When** the TypeScript exhaustive-switch witness in `eventTextContent` compiles, **Then** the `const _exhaustive: never = e` assignment continues to type-check (verifies the 5-variant union is exhaustively handled in eventTextContent).

## Red→green wire-up

| Test file | Project | Final state | Verifies |
|---|---|---|---|
| `tests/unit/F-139-backend-event-usage-variant.test.ts` | unit | GREEN — 6/6 scenarios PASS | scenarios 1, 2, 3, 4, 5, 6 |

## Dependencies

- **Hard:**
  - F-009 (ibackend-provider) — owns BackendEvent union; F-139 extends it with a 5th variant
  - F-013 (event-normalization) — owns type guards + eventTextContent; F-139 extends with `isUsageEvent` + usage-event branch
  - F-019 (cost-ledger) — owns CostEntryInput + CostLedger.append; F-139 produces CostEntryInput shape from a usage event
- **Soft:** F-010 (anthropic-sdk-provider) + F-011 (copilot-sdk-provider) — concrete backends will emit the new variant when their stub bodies are swapped for real SDK calls; F-138 (engine-cycle-orchestrator) — composes the mapper into the cycle's BackendEvent loop in a future iteration

## Surface trace

| surface-id | what it contributes |
|---|---|
| ce:FR-COST-001 | every backend response has token-count attribution observable to the cost ledger |
| cp:src/engine/backend-events | clawpilot per-event normalization pattern |
| kit:rules/no-invented-constraints.md | the variant carries token counts ONLY; no auto-budget enforcement (F-019 stays observable-only) |

## Implementation notes

Wave-019 / Lane B — RED test scaffold + GREEN impl landed in same micro-session per the wave-5 retro proposal validated by F-138's pattern. Cross-lane staging-race avoidance: per user directive 2026-05-07, NO `git reset` (any flavor) for staging-race recovery; explicit `git add <paths>` for each commit; `git status --short` audit before each commit. Push at end of lane authorized for this loop session.

- **Implementation file**: `packages/engine-core/src/backend-event-variant.ts` (~70 LOC).
- **Public surface**:
  - `usageEventToCostEntry(event, ctx, priceLookup?): CostEntryInput` — converts a usage event + correlation + optional pricing into the F-019 append-ready shape.
  - `UsageEventContext` — `{run_id, agent_id, parent_run_id?}` correlation triple shape.
  - `PriceLookup` — `(model, kind: 'input' | 'output') => number` per-token rate function (USD per token).
  - `isUsageEvent` — re-exported from backend-events.ts via the variant-mapper module barrel for ergonomics.
- **Backend.ts changes** (F-009 owner; minimal additive):
  - Extend `BackendEvent` union with the 5th variant: `{type:'usage', input_tokens:number, output_tokens:number, cache_read_tokens:number, cache_write_tokens:number, model:string, backend?:string}`.
  - StubBackend `sendPrompt` is NOT modified to emit usage events — keeps the F-009 acceptance contract intact (Stub yields token + finish only). Real-SDK swaps in F-010/F-011 add the 6-event sequence (token chunks + finish + usage) when they land.
- **Backend-events.ts changes** (F-013 owner; minimal additive):
  - Add `isUsageEvent(e): e is Extract<BackendEvent, {type:'usage'}>` type guard.
  - Extend `eventTextContent` switch with a 5th branch returning `[usage: input=N output=M cache_read=R cache_write=W]`.
  - The `const _exhaustive: never = e` exhaustive-switch witness continues to compile (5/5 variants handled).
- **Index.ts barrel addition**: 1 ownership-table comment line + 1 `export * from './backend-event-variant.js'` re-export. Disjoint append zone per the wave-011/lane-a convention.
- **Anti-orchestrator-impostor discipline** per `kit:rules/orchestrator-identity.md`: backend-event-variant.ts NEVER appends to a CostLedger directly. It produces a CostEntryInput; the caller (F-138 cycle.ts in a future iteration) calls `costLedger.append(input)`. Cost-ledger ownership stays with F-019.
- **No-invented-constraints discipline**: the mapper computes `usd_estimate` ONLY when a price-lookup callback is supplied. Without the callback, `usd_estimate=0` (caller-deferred pricing). NO halt, NO budget-check, NO warning when costs are high — F-019's observable-only contract per `no-invented-constraints.md` propagates through this mapper.
- **D-36 status**: marked RESOLVED in `docs/10-backlog/design-decisions-pending.md` upon GREEN landing. The design-decision row's chosen option is (a) "add usage variant to BackendEvent now", consistent with the wave-016/lane-d default recommendation.
