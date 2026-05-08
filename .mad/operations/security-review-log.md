---
title: Operations — Security review log
status: preview
since: 2026-04-18
last_reviewed: 2026-04-18
promote_by: 2026-07-31
---

# Security review log

Append-only ledger of security reviews conducted per `operations/security-review-program.md`. One row per completed review.

| date | type | reviewer | scope | findings-count | follow-up CHK items |
|---|---|---|---|---|---|
| *(no reviews yet — first Baseline is a Phase-1 deliverable before the first `--tier prod` channel opens)* | — | — | — | — | — |

## Rules

1. **Append only.** Rows are never rewritten. Corrections land as a new row with a `supersedes: <prior-date>` note in the scope column.
2. **One row per completed review.** Drafts, no-shows, and cancellations are NOT logged here (they belong in `operations/quarterly-review.md §Security` as process notes).
3. **Checkup cadence gate.** The QSR reads this log and flags if no `Checkup` row exists within 6 months of the prior `Baseline` or `Checkup`.
4. **HIGH findings block staged-rollout promotions.** Per `wiki/patterns/staged-rollout.md §Integration with the QSR`, any open HIGH CHK item cited in this log blocks the next `canary → staged` or `staged → default` promotion until closed.

## Related

- `operations/security-review-program.md` — cadence and scheduling discipline.
- `operations/quarterly-review.md §Security` — QSR gate on review cadence.
- `rules/stride-threat-model.md` — framework each review applies.

