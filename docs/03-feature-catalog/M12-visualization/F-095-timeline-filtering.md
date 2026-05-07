---
artifact-class: feature-ledger
generated-by: hand-authored (wave-006 / lane-a)
status: red
status-since: 2026-05-06
status-history:
  - status: red
    at: 2026-05-06
    by: wave-006 / lane-a
    note: "Initial creation; behavior contract + acceptance scenarios drafted; no test or implementation yet"
feature-id: F-095
short-slug: timeline-filtering
milestone: M12
provenance:
  surfaces:
    - kit:foundational-plan.md M12 NEW Message 11
    - kit:rules/no-silent-deferrals.md
    - kit:rules/no-top-n-capping.md
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
  LOCKED if GREEN AND reviews/F-095-timeline-filtering-review.md exists with verdict: ACCEPT.
depends-on: [F-093]
out-of-scope-notes: |
  Saved-filter persistence (named filter presets) is post-v1 — v1 filters are per-session
  only. Cross-run filter (apply same filter across multiple runs) is post-v1 — v1 is
  single-run filter only. Full-text search across audit-entry payloads is M17 documentation
  scope (deferred). Filter export to CSV is post-v1. Filter syntax (DSL) is intentionally
  minimal — checkbox + dropdown UI only, NOT a query language.
confidence: high
---

# F-095 — Timeline filtering

## Behavior contract

The F-093 timeline view exposes **filter controls** that hide/show timeline nodes based on three orthogonal axes: `event_type` (multi-select checkboxes — TOOL_CALL, VERDICT, HALT, INTROSPECTION, COST, etc.), `agent_id` (multi-select dropdown of agents in the run), and `time-range` (slider bounded by run start/end). Filters are additive (intersection): a node renders only if it satisfies ALL active filter axes. Hidden nodes do NOT alter the audit chain or the F-094 scrubber's index space — scrubbing past hidden nodes still visits them in the underlying state, only the visual rendering is suppressed. The filter UI MUST display a count of `visible / total` so the user always knows how much is hidden (per `rules/no-silent-deferrals.md`).

## Acceptance scenarios

1. **Given** a run with 100 entries (40 TOOL_CALL, 30 INTROSPECTION, 20 COST, 10 VERDICT), **When** the user unchecks TOOL_CALL and INTROSPECTION, **Then** 30 nodes render (20 COST + 10 VERDICT) AND the filter bar shows "30 / 100 visible" AND the underlying audit chain is unchanged.
2. **Given** an active filter hiding 70 of 100 nodes, **When** the user scrubs (per F-094) to a hidden index, **Then** the scrubber state-reconstruction includes the hidden entries (state is correct) AND the timeline highlights "scrubber at hidden entry — adjust filters to see" (no silent skip).
3. **Given** the filter bar shows "0 / 100 visible" because all event types are unchecked, **When** the timeline renders, **Then** an empty-state message appears AND the filter bar displays a "Reset filters" affordance — the timeline does NOT silently appear empty without explanation.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/browser/timeline-filter/filter-by-event-type.test.ts` | browser | RED | scenario 1 |
| (TBD) `tests/browser/timeline-filter/filter-vs-scrubber-state.test.ts` | browser | RED | scenario 2 |
| (TBD) `tests/browser/timeline-filter/filter-empty-state-explicit.test.ts` | browser | RED | scenario 3 |

## Dependencies

- **Hard:** F-093 (filtering operates on the timeline UI's nodes)
- **Soft:** F-094 (scrubber must coordinate with hidden-entry visualization), F-002 (agent-id dropdown sources from per-run identity registry)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md M12 NEW Message 11 | "filtering" verbatim from user's NEW-features answer (M12 row) |
| kit:rules/no-silent-deferrals.md | Hidden-entry counts MUST be visible; "X of Y visible" prevents silent omission |
| kit:rules/no-top-n-capping.md | Filtering hides by user-controlled criteria, NOT by capping arbitrary "top N" entries |

## Implementation notes

(empty — populated when implementation begins; filter-state persistence in F-075 settings deferred to v1.5 per out-of-scope-notes)
