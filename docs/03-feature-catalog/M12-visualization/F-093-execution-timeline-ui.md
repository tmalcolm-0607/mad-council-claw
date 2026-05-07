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
feature-id: F-093
short-slug: execution-timeline-ui
milestone: M12
provenance:
  surfaces:
    - kit:foundational-plan.md M12 NEW Message 11
    - kit:rules/verification-protocol.md
    - cp:src/main/logger
    - ce:FR-AUDIT-001
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
  LOCKED if GREEN AND reviews/F-093-execution-timeline-ui-review.md exists with verdict: ACCEPT.
depends-on: [F-015, F-032, F-092]
out-of-scope-notes: |
  Replay scrubber (F-094) is the interactive control overlay; this ledger covers the
  read-only timeline render only. Timeline filtering (F-095) is the separate companion.
  Export-to-PNG / export-to-CSV of a timeline view is post-v1. Multi-run side-by-side
  comparison is post-v1 (single-run timeline only). Live-streaming a currently-running
  agent's events is M3 cron/heartbeat scope (F-024 heartbeat); v1 timeline renders
  COMPLETED runs only. M12-D-7 (replay scrubber overlay design) closes here per M11
  README out-of-scope reference.
confidence: high
---

# F-093 — Execution timeline UI

## Behavior contract

The desktop shell renders a **chronological timeline view** of any completed run by reading `runs/<run_id>/audit-chain.jsonl` (per F-015) and the run's introspection snapshots (per F-090). Each audit entry becomes a timeline node positioned by `entry_index` (monotonic), labeled with `event_type` + `agent_id`, color-coded by category (tool-call / verdict / halt / introspection / cost). Hover reveals the full entry payload; click expands the node into a side-panel detail view. The timeline scrolls horizontally; vertical lanes group entries by `agent_id` so multi-agent runs render as parallel tracks.

## Acceptance scenarios

1. **Given** a completed run with 47 audit entries across 3 agents, **When** the user opens the run in the timeline view, **Then** 47 nodes render in `entry_index` order, grouped into 3 vertical lanes (one per `agent_id`), each lane labeled with the agent's identity from F-002.
2. **Given** a node representing a `TOOL_CALL` entry, **When** the user clicks it, **Then** the side panel shows the entry's full JSON payload AND the entry's chain-hash + previous-hash (proving F-015 audit integrity at view time).
3. **Given** a run that emitted a `HALT` entry at index 23, **When** the timeline renders, **Then** node 23 appears with the halt color category AND an alert badge AND nodes 24+ render with a "post-halt" visual marker (dimmed); the timeline does NOT silently drop post-halt entries.

## Red→green wire-up

| Test file | Project | Initial state | Verifies |
|---|---|---|---|
| (TBD) `tests/browser/timeline/timeline-renders-audit-entries.test.ts` | browser | RED | scenario 1 |
| (TBD) `tests/browser/timeline/timeline-node-detail-panel.test.ts` | browser | RED | scenario 2 |
| (TBD) `tests/browser/timeline/timeline-halt-marker.test.ts` | browser | RED | scenario 3 |

## Dependencies

- **Hard:** F-015 (audit-chain is the timeline's data source), F-032 (desktop shell window hosts the view), F-092 (replay manifest links the timeline to a reproducible run for cross-verification)
- **Soft:** F-002 (per-agent identity provides lane labels), F-090 (introspection snapshots enrich timeline nodes), F-019 (cost-ledger entries appear as cost-category nodes)
- **Independent:** n/a

## Surface trace

| surface-id | what it contributes |
|---|---|
| kit:foundational-plan.md M12 NEW Message 11 | "Agent execution timeline + replay scrubber" verbatim from user's NEW-features answer |
| kit:rules/verification-protocol.md | "ACTUAL BEFORE PRESENT" — timeline shows what actually happened, not summaries; chain-hash visible per node proves it |
| cp:src/main/logger | Existing logger emits structured records; timeline consumes them via the audit-chain layer |
| ce:FR-AUDIT-001 | Audit log is the canonical source the timeline visualizes |

## Implementation notes

(empty — populated when implementation begins; rendering library choice deferred to M12 design wave council-review)
