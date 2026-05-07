# Confidence ledger

Per kit's `verification-protocol.md` and the user directive "as new items get added to the loop. we should keep medium and high confidence items": every finding's confidence over time. HIGH ↔ MEDIUM transitions captured.

## Schema

| Finding ID | Source | Confidence | Wave introduced | Last revisited | Notes |
|---|---|---|---|---|---|

## Entries

_empty — first entries land after Lanes A-D commit findings_

## Transitions

- MEDIUM → HIGH: requires evidence-gathering wave per QG2 (cite at least one source)
- HIGH → MEDIUM: requires explicit re-review (a contradicting finding from a later wave)
- HIGH → DROPPED: requires user acknowledgement at periodic interview gate L3 per `no-silent-deferrals.md`
- MEDIUM → DROPPED: rationale logged to `docs/10-backlog/dropped-with-rationale.md`
