---
artifact-class: feature-ledger
generated-by: hand-authored (wave-012 / lane-c)
status: red
status-since: 2026-05-07
status-history:
  - status: planned
    at: 2026-05-06
    by: foundational-plan.md catalog deltas
    note: "F-NNN reserved as one of 5 frontier-research candidates"
  - status: red
    at: 2026-05-07
    by: wave-012 / lane-c
    note: "Initial ledger created; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-126
short-slug: context-budget-allocation
milestone: M8
provenance:
  surfaces:
    - foundational-plan.md "Plus 5 NEW F-NNN candidates" F-126
    - foundational-plan.md "[R:WebSearch frontier 2026]"
    - docs/06-agent-team-outputs/wave-001/lane-a-summary.md (finding 23 — Context window management as architectural concern)
    - kit:rules/context-guardian.md (ADVISORY/PREPARE/HALT thresholds in MAD kit)
    - kit:rules/no-invented-constraints.md (engine MUST NOT silently invent budget defaults)
    - kit:rules/single-owner-accountability.md (budget ownership is per-workspace + audit-logged)
    - docs/10-backlog/feature-promotions.md F-131 fanout-budget-governor (cross-model adversarial tie-in)
fr-coverage: []
test-files:
  unit: []
  node: []
  browser: []
  integration: []
  e2e: []
test-runner-projects: []
red-green-rule: |
  RED   if any test file is missing OR any runner returns non-zero exit.
  GREEN if all test files exist AND all runners return zero exit.
  LOCKED if GREEN AND reviews/F-126-context-budget-allocation-review.md exists with verdict: ACCEPT.
depends-on: [F-067, F-073, F-019, F-018, F-013]
out-of-scope-notes: |
  Auto-compaction / auto-summarization at threshold — out for v1; F-126 emits the
  signals (ADVISORY / PREPARE / HALT thresholds) but does not perform compaction. The
  caller decides whether to compact, hand off to a fresh session, or halt. Compaction
  itself is M11 (soul/introspect/replay) territory + a v1.5 candidate.
  Per-tool context budgets (cap how much context any single tool's output consumes)
  — adjacent concern; v1 budget is end-to-end across the whole call's input + tool
  outputs + reasoning + response.
  Cross-session context aggregation (sum context across N parallel sessions in one
  workspace) — out for v1; F-126 is per-call.
  Multi-agent fan-out budget governance (the F-131 promotion candidate) — RELATED but
  distinct. F-131 governs fan-out token cost across child agents; F-126 governs
  per-call context-window budget. F-131 should consume F-126's budget primitives when
  it lands.
  Hidden-buffer rescaling (Claude Code's ~16.5% reserved buffer) — F-126 follows
  `rules/context-guardian.md` convention but does NOT bake provider-specific buffer
  values into the engine; the user supplies the effective-budget rescale factor per
  workspace.
confidence: high
---

# F-126 — Context-budget allocation per workspace

## Behavior contract

The engine MUST track per-call context-window utilization against a user-declared
per-workspace budget and emit threshold-crossing signals so callers can make
compaction / handoff / halt decisions before silent compaction occurs. Each workspace
(per F-073) declares: `context_budget_total_tokens` (the model's effective context
window), `context_budget_advisory_threshold` (default 0.50), `context_budget_prepare_threshold`
(default 0.70), `context_budget_halt_threshold` (default 0.85), and an optional
`hidden_buffer_factor` for rescaling against provider-internal buffers. Every LLM
call's input-token estimate (prompt + tools + history + system) is computed
pre-dispatch and emitted as a normalized event (per F-013) with `budget.used_tokens`,
`budget.total_tokens`, `budget.utilization` (ratio 0..1), and `budget.threshold`
(`under` | `advisory` | `prepare` | `halt`). HALT emits a `CONTEXT_BUDGET_HALT`
event and the call is rejected unless the caller passes `--force-context-overflow`.
The engine MUST NOT silently invent budget defaults absent workspace configuration
(per `rules/no-invented-constraints.md`); a missing budget is treated as "no budget"
(no signal), not "use a sensible default". Mirrors the kit's
`rules/context-guardian.md` ADVISORY/PREPARE/HALT shape so MAD-kit operators see
familiar signals when running the engine.

## Acceptance scenarios

1. **Given** a workspace with `context_budget_total_tokens: 200000` and the default
   thresholds, **When** an LLM call is prepared with 100000 estimated input tokens
   (50% utilization), **Then** the engine emits a `budget.threshold: "advisory"`
   normalized event before dispatch and proceeds with the call; F-019 cost ledger
   records the budget snapshot.
2. **Given** the same workspace and an LLM call with 175000 estimated input tokens
   (87.5% utilization, above HALT 0.85), **When** dispatch is attempted without
   `--force-context-overflow`, **Then** the engine emits `budget.threshold: "halt"`
   plus `CONTEXT_BUDGET_HALT`, the call is rejected with a structured error naming
   the workspace id + thresholds, and the F-015 audit log captures the rejection.
3. **Given** a workspace with NO `context_budget_total_tokens` configured, **When**
   any LLM call is prepared, **Then** no budget event is emitted (no silent default
   per `rules/no-invented-constraints.md`); the call proceeds unmodified; downstream
   callers that depend on budget signals (e.g., F-131 fan-out governor) see "no
   budget configured" and follow their own degraded-mode path.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/budget/advisory-threshold-emit.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/integration/budget/halt-rejects-without-force.test.ts` | integration | RED | scenario 2 |
| (TBD) `tests/unit/budget/no-config-no-default.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-067 (settings shape stores the budget fields), F-073 (per-workspace
  scope; budgets vary per workspace), F-019 (cost ledger consumes budget snapshots
  for per-call telemetry), F-018 (halt mechanism handles the HALT-threshold rejection
  path), F-013 (budget events flow through the normalized-event stream)
- **Soft:** F-110 / F-112 (telemetry sink + perf metrics record budget utilization
  histograms over time for retrospective analysis), F-058 (3-tier permissions could
  gate `--force-context-overflow` behind ASK in stricter workspaces — v1.5 follow-up)
- **Independent:** F-D-NNN compaction strategies (out of v1; F-126 emits signals,
  doesn't compact)

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan.md F-126 | reserved F-NNN allocation; M8 placement; "[R:WebSearch frontier 2026]" provenance |
| docs/06-agent-team-outputs/wave-001/lane-a-summary.md finding 23 | Context-window management identified as architectural-tier concern in 2026 frontier reports |
| kit:rules/context-guardian.md | ADVISORY/PREPARE/HALT threshold shape that this ledger mirrors so MAD-kit operators see familiar signals |
| kit:rules/no-invented-constraints.md | engine MUST NOT pick a default budget; missing config = no signal, not silent default |
| kit:rules/single-owner-accountability.md | budget ownership is per-workspace; budget changes audit-logged with session_id |
| docs/10-backlog/feature-promotions.md F-131 | downstream fanout-budget-governor will consume F-126's budget primitives when it lands |

## Implementation notes

(empty — populated when implementation begins)
