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
feature-id: F-124
short-slug: multi-tier-routing
milestone: M1
provenance:
  surfaces:
    - foundational-plan.md "Plus 5 NEW F-NNN candidates" F-124
    - foundational-plan.md "[R:WebSearch frontier 2026 architecture]"
    - docs/06-agent-team-outputs/wave-001/lane-a-summary.md (finding 21 — Multi-tier routing 60% cost reduction)
    - kit:rules/no-invented-constraints.md (no implicit routing thresholds without user config)
    - kit:rules/single-owner-accountability.md (routing decisions audit-logged with session_id)
    - foundational-plan.md D-4 (open decision: rules-based vs ML-routed default policy)
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
  LOCKED if GREEN AND reviews/F-124-multi-tier-routing-review.md exists with verdict: ACCEPT.
depends-on: [F-009, F-012, F-013, F-019]
out-of-scope-notes: |
  ML-driven router (an actual classifier model selecting tier per call) — D-4 is OPEN
  in `docs/10-backlog/design-decisions-pending.md`; v1 default per this ledger is
  rules-based routing with explicit user-supplied tier policy. ML routing would extend
  the policy interface in v1.5 without breaking the v1 contract.
  Cross-provider routing (Anthropic Haiku → Copilot GPT) — out of v1; F-124 routes within
  a single provider's model family (e.g., Haiku ↔ Sonnet ↔ Opus within Anthropic).
  Cost-budget enforcement gating (refuse to call Opus when budget exhausted) — F-019
  cost ledger + F-018 halt are the enforcement surface; F-124 only emits the routing
  decision plus its rationale.
  Adversarial multi-model dispatch (`--council` mode running Opus + GPT in parallel)
  — that is M10 (F-082..F-087), distinct concern from cost-routing.
  Auto-retry on tier upgrade (call failed at Haiku tier → retry at Opus) — out for v1;
  failures surface to the caller, who decides whether to retry.
confidence: high
---

# F-124 — Multi-tier model routing (Haiku / Sonnet / Opus)

## Behavior contract

The engine MUST support per-call routing across model tiers within the same backend
provider, gated by an explicit user-supplied policy. The default policy is rules-based
(per D-4 working assumption pending closure): the caller declares a `tier` hint
(`fast` | `balanced` | `deep`) on the `complete()` call, and the router maps that hint
to a concrete model id (e.g., `claude-haiku-4-5` / `claude-sonnet-4-7` /
`claude-opus-4-7`). Callers MAY pass a concrete model id, which bypasses the router.
Every routing decision is captured as a normalized event (per F-013) with
`router.policy` (rules | passthrough), `router.tier_hint`, `router.selected_model`,
`router.rationale` (why this tier), and `router.cost_estimate_usd` (computed from
F-019's price table). Routing decisions land in the F-019 cost ledger so per-tier
spend is queryable. The engine MUST NOT invent routing thresholds, automatic tier
upgrades, or cost-saving heuristics absent explicit user policy (per
`rules/no-invented-constraints.md`); the 60% cost-reduction headline figure from the
2026 frontier architecture finding is achievable ONLY when the user configures the
policy.

## Acceptance scenarios

1. **Given** a user-supplied policy mapping `tier_hint: "fast"` to `claude-haiku-4-5`
   and a `complete({ tier: "fast", prompt: "..." })` call, **When** the router resolves,
   **Then** the underlying provider receives `model: "claude-haiku-4-5"`, the
   normalized event stream emits a `router.decision` event with `selected_model:
   "claude-haiku-4-5"` and `policy: "rules"`, and the F-019 cost ledger records the
   spend at the Haiku price.
2. **Given** a `complete({ model: "claude-opus-4-7", prompt: "..." })` call (concrete
   model id, no tier hint), **When** the router resolves, **Then** the router emits
   `policy: "passthrough"` and `selected_model: "claude-opus-4-7"`; no rule-based
   substitution occurs; the call proceeds unmodified.
3. **Given** a `complete({ tier: "fast" })` call but NO user policy is configured,
   **When** the router resolves, **Then** the call fails with
   `ROUTER_POLICY_NOT_CONFIGURED` (no fallback default; per
   `rules/no-invented-constraints.md` the engine MUST NOT pick a default tier mapping)
   and the failure is audit-logged via F-015.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/unit/backend/router-rules-policy.test.ts` | unit | RED | scenario 1 |
| (TBD) `tests/unit/backend/router-passthrough.test.ts` | unit | RED | scenario 2 |
| (TBD) `tests/unit/backend/router-no-policy-rejects.test.ts` | unit | RED | scenario 3 |

## Dependencies

- **Hard:** F-009 (IBackendProvider exposes the `complete()` surface the router wraps),
  F-012 (backend factory hosts the router as a thin adapter layer), F-013 (router
  emits decisions as normalized events), F-019 (cost ledger consumes router decisions
  for per-tier spend rollup)
- **Soft:** F-010 / F-011 (concrete providers expose their model-id catalog to the
  policy validator), F-067 (M8 settings stores the user policy persistently),
  F-019 + F-018 (cost halt halts routes that would exceed the user's per-run budget —
  but enforcement lives in F-018, not F-124)
- **Independent:** F-082..F-087 (M10 multi-model `--council` is adversarial cross-model
  dispatch; F-124 is single-call cost-aware routing within one provider)

## Surface trace

| surface-id | what it contributes |
|---|---|
| foundational-plan.md F-124 | reserved F-NNN allocation; M1 placement; "[R:WebSearch frontier 2026 architecture]" provenance |
| docs/06-agent-team-outputs/wave-001/lane-a-summary.md finding 21 | 60% cost-reduction figure from 2026 frontier architecture trend reports |
| kit:rules/no-invented-constraints.md | no implicit tier defaults; empty policy must reject, not silently pick |
| kit:rules/single-owner-accountability.md | every routing decision audit-logged with session_id |
| foundational-plan.md D-4 | open decision: rules-based (this ledger's working assumption) vs ML-routed default; v1.5 may extend |

## Implementation notes

(empty — populated when implementation begins)
