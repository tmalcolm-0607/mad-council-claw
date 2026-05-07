# Dropped with rationale

Audit trail for items removed from backlog. Per `no-silent-deferrals.md`: "even dropped backlog items move here (rather than being deleted)."

## Schema

```
| ID | Item | Original location (which backlog file) | Dropped (date) | Rationale | User-acknowledged at L3 (date) |
```

## Entries

| ID | Item | Original location | Dropped | Rationale | L3-ack |
|---|---|---|---|---|---|

_no entries yet_

## Process

1. Item proposed for drop in a wave's loop-improvement proposal
2. Surfaced at next periodic interview gate (L3 — every 10 waves)
3. User acknowledges the drop OR pulls the item back to active backlog
4. If acknowledged: row appended here with rationale + L3 date
5. If pulled back: item stays in original location with the user's reason

The asymmetry per `no-silent-deferrals.md`: silent additions are easy to revert; silent deferrals erase user intent. So dropping ALWAYS requires a conversation; adding does not.
