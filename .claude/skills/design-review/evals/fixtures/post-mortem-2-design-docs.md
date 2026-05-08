# Fixture: post-mortem 2 design-doc consistency case

Synthetic input replicating the May 2026 cross-file consistency miss (Gap 4) but applied at design-review scope: 2 design docs that prescribe overlapping patterns with subtle inconsistencies.

## Synthetic input artifact

Two design docs in same PR:
- `specs/ideas/event-sourcing-pattern.md` (vision doc proposing event-sourcing for module A)
- `specs/ideas/cqrs-pattern.md` (vision doc proposing CQRS for module B)

Body excerpts:

`event-sourcing-pattern.md`:
> Event-sourced aggregates use optimistic concurrency. ETag-equivalent is the aggregate version number.
> Snapshot frequency: every 100 events.
> Eventual consistency between read and write models.

`cqrs-pattern.md`:
> Commands write through the aggregate; queries read from a denormalized projection.
> Snapshot frequency: every 50 events.
> Strong consistency between command and query models within a single tenant.

The conflict: both docs touch the same domain ("aggregate snapshots", "consistency model") but prescribe different values without acknowledging each other. Both also assume different consistency models — strong vs eventual — which is a load-bearing architectural disagreement.

## Skill invocation

```
/design-review specs/ideas/event-sourcing-pattern.md specs/ideas/cqrs-pattern.md
```

## Notes

This fixture is the regression test for Gap 4 applied at design-review scope:

| Miss | Caught by |
|------|-----------|
| 1 No grounding | Step 1.5 — keywords "event sourcing", "CQRS" both fire WorkIQ pull |
| 2 No ref-repo cross-check | Step 1.7 — both docs are prescriptive; cross-check the snapshot frequency + consistency claims against `references/` |
| 3 No completeness pass | Step 1.9 — `spec.md` oracle (vision-flag relaxes BLOCKING but still emits) |
| 4 **Cross-file consistency (THE primary catch)** | Step 1.8 — 2× spec-change in `cross_file_groups[]`; flag inconsistent snapshot frequency + contradictory consistency models as BLOCKING |
| 5 Risk-blind | Step 1.6 — 2× doc-change with org-wide blast → blast_radius=5 each, combined surfaces for council |
| 6 Severity calibration | Output Contract — for spec-change cross-file inconsistency: MUST-FIX. For consistency-model contradiction (architectural): BLOCKING. |
