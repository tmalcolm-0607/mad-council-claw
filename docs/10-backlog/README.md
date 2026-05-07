# 10 — Backlog

Append-only intake for items the loop discovers but does NOT immediately act on. Per Goal G19 (Message 25) and the user directive "as new items get added to the loop. we should keep medium and high confidence items."

## Files

| File | Purpose |
|---|---|
| `open-questions.md` | Accumulated user-decision items (Q-1..Q-N + new). Surfaced periodically per Standing Milestone L3. |
| `research-gaps.md` | Research topics queued for upcoming waves |
| `design-decisions-pending.md` | D-1..D-N decisions awaiting closure |
| `implementation-todo.md` | F-NNN waiting for implementation (RED state) |
| `feature-promotions.md` | Rules-without-hooks promotion candidates per `rules-without-hooks-audit.md` discipline |
| `retire-candidates.md` | Tools / surfaces flagged ACTIVE → OBS or OBS → RETIRED |
| `dropped-with-rationale.md` | Items removed from backlog with reason. Audit trail per `no-silent-deferrals.md`. |

## Confidence labeling

- **HIGH (≥80%)** — auto-pickup eligible by next available instance
- **MEDIUM (50-79%)** — kept; needs more research or user input before action
- **LOW (<50%)** — dropped (with rationale) OR moved to `research-gaps.md`

## Aging

- Aged >30 days without action → flag for next periodic interview gate (L3)
- MEDIUM for >5 waves without promotion → research-wave priority

## Removal

- HIGH executed → moved to `docs/07-roadmap/decision-log.md` with date + outcome
- LOW dropped → moved to `dropped-with-rationale.md` (audit trail)
- Per `no-silent-deferrals.md`: removals require explicit user acknowledgement at L3
