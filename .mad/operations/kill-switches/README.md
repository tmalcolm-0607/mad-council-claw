# Kill-switches

One JSON file per staged change, per `wiki/patterns/staged-rollout.md §Kill-switch`. Adopted via ADOPT-027.

## Filename convention

`<change-id>.json` — same `change-id` as appears in `../rollout-log.md`. kebab-case; must match `^[a-z0-9][a-z0-9-]{0,63}$`.

Examples:
- `rule-injection-ban-list-v2.json`
- `skeptic-prompt-confidence-tightening.json`
- `verdict-schema-ownership-transfer-v1.json`

## JSON shape

```json
{
  "change_id": "rule-injection-ban-list-v2",
  "stage": "canary",
  "revert_to": "rule-injection-ban-list-v1",
  "killed": false,
  "killed_at_utc": null,
  "kill_reason": null,
  "owner": "rules-steward-alias"
}
```

| Field | Required | Notes |
|---|---|---|
| `change_id` | yes | Matches filename (sans `.json`) |
| `stage` | yes | Current stage: `dark \| canary \| staged \| default` |
| `revert_to` | yes | The prior-change-id whose behaviour is restored when killed |
| `killed` | yes | `true`/`false`. Flip to true by atomic rewrite — skills read this on every invocation |
| `killed_at_utc` | only when `killed=true` | ISO-8601 |
| `kill_reason` | only when `killed=true` | Free-text; 1-2 sentences; surfaces in the next QSR |
| `owner` | yes | Alias of the person who owns the kill decision — typically the rules steward or the channel owner that introduced the change |

## Operational rules

1. **Every staged change has a file here.** A rollout without a kill-switch file is rejected at promotion per `operations/validation-strategy.md §Readiness`.
2. **Write through atomic rename.** Per `rules/concurrency-safety.md` — no partial writes on this file.
3. **Kill propagation is read-time.** Skills re-read this file on every invocation. Flipping `killed: true` affects the very next skill call anywhere in the system.
4. **Killed ≠ deleted.** Keep killed files on disk — they are the audit trail. Delete only after the replacement change's `revert_to` no longer names this change-id (typically 2 QSRs after kill).
5. **No kill-switch on `stable`-tier pre-adoption rules.** Kill-switches are for post-ADOPT changes. The pre-existing stable rules are out of scope; revert them via standard `git revert` on the source.

## Related

- `../rollout-log.md` — one-row-per-change rollout history.
- `../../wiki/patterns/staged-rollout.md` — pattern specification.
- `../../rules/concurrency-safety.md` — atomic-write requirement.
