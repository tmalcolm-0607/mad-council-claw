---
artifact-class: milestone-overview
generated-by: hand-authored (wave-006 / lane-a)
status: red
milestone: M12
short-slug: visualization
features: F-093..F-095
authored: 2026-05-06
---

# M12 — Visualization (NEW)

A NEW milestone introduced per Message 11: "Agent execution timeline + replay scrubber." Three features render a completed run as a navigable artifact: the timeline UI (read-only), the scrubber (interactive state inspection), and filtering (multi-axis hide/show). M12 is post-M11: it consumes the deterministic-replay manifest (F-092), the audit-chain (F-015), and the introspection snapshots (F-090) to render past runs that are reproducible and tamper-evident. Without M11, the timeline would render unverifiable history; with M11, every node visualizes a hash-chained, replayable event.

## Features

| ID | Slug | One-liner |
|---|---|---|
| F-093 | execution-timeline-ui | Read-only chronological timeline; multi-agent vertical lanes; click-to-detail; hash-visible per node |
| F-094 | replay-scrubber | Interactive scrub by entry index; reconstructs cost/agents/snapshot state; read-only — no engine re-execution |
| F-095 | timeline-filtering | Hide/show by event_type / agent_id / time-range; "X of Y visible" counter; never silent emptying |

## Dependency DAG

```
M0 (F-002 identity, F-008 storage, F-032 desktop shell) ──→ M12 features
M2 (F-015 audit-chain)        ──→ F-093 (data source)
                              └──→ F-094 (state reconstruction source)

M11 (F-092 deterministic-replay) ──→ F-093 (cross-verifies timeline against replay manifest)
                                 └──→ F-094 (replay manifest is determinism anchor for scrub state)

F-093 (timeline UI) ──→ F-094 (scrubber overlays timeline)
                   └──→ F-095 (filter operates on timeline nodes)

F-094 (scrubber) ──→ F-095 (must coordinate with hidden-entry visualization)
```

## Milestone exit criteria

- All 3 ledgers GREEN
- A completed run renders as a chronological timeline with multi-agent lane grouping
- Each timeline node click reveals full audit-entry payload + chain-hash for verification
- A scrubber drag reconstructs state at the scrubbed index without invoking the engine binary
- Filter changes update the visible-count display in real time AND the underlying audit chain is unchanged
- An empty filter state shows an explicit reset affordance — the timeline never silently appears empty

## Pending design decisions blocking M12 implementation

- **D-7** — Replay scrubber overlay design (visual style, scrub granularity vs cost trade-off). Closure: M12 design wave council-review per M11 README out-of-scope reference.
- **D-M12-1** — Timeline rendering library choice (canvas vs SVG vs DOM-list). Trade-off is performance at high entry counts vs detail fidelity. Closure: M12 design wave; cite frontier 2026 Electron desktop-rendering patterns.
- **D-M12-2** — Filter persistence scope (per-session only in v1; F-075 settings integration is post-v1). Closure: in scope decision, no review needed; documented in F-095 out-of-scope-notes.

## Out of scope (tracked elsewhere)

- Saved-filter presets — post-v1 (F-095 out-of-scope-notes)
- Cross-run side-by-side comparison — post-v1 (F-093 out-of-scope-notes)
- Live-replay (re-execute from scrub position) — post-v1 (F-094 out-of-scope-notes)
- Branching replay (fork from scrub position) — post-v1 (F-094 out-of-scope-notes)
- Live-streaming a running agent's events into the timeline — M3 cron/heartbeat scope (F-024)
- Cross-run filter (apply filter across multiple runs simultaneously) — post-v1 (F-095 out-of-scope-notes)
- Filter export to CSV — post-v1 (F-095 out-of-scope-notes)
- Full-text search across audit-entry payloads — M17 documentation scope (deferred)

## Provenance

`kit:foundational-plan.md M12 NEW Message 11`, `kit:rules/{verification-protocol, no-silent-deferrals, no-top-n-capping}.md`, `cp:src/main/logger`, `ce:FR-AUDIT-001`, `ce:FR-REPLAY-001`. Per-ledger `provenance.surfaces`.
