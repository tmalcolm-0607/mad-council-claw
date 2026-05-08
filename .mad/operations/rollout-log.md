# Rollout log

Append-only log of staged rollouts per `wiki/patterns/staged-rollout.md` (ADOPT-006). Referenced by `operations/validation-strategy.md` stage-gate readiness checklist and `operations/quarterly-review.md` rules-drift review.

**Every row represents one change-id progressing through dark → canary → staged → default.** Rows are written on stage entry and amended in-place only to record the final outcome (reached default, killed, or stuck).

## Format

```markdown
| date | change-id | commit | stage reached | killed? | owner | notes |
|---|---|---|---|---|---|---|
| <ISO date> | <kebab-case-id> | <short sha> | <dark\|canary\|staged\|default> | <no\|yes (ts + reason)> | <alias> | <1-line summary> |
```

Rules:
- `change-id` is stable across stages. A change that reaches `staged` then rolls back to `canary` gets a second row with the same change-id and a "rolled back" note.
- `killed?` is set via the kill-switch JSON in `operations/kill-switches/<change-id>.json`.
- `notes` is 1 line maximum. Deeper context lives in the commit message or a `_review-checklist.md` entry.

## Initial entries

No staged rollouts yet — the staged-rollout pattern itself is currently `status: preview` (see `rules/_status-convention.md`). This log begins populating once the first post-ADOPT rule change lands under the pattern.

| date | change-id | commit | stage reached | killed? | owner | notes |
|---|---|---|---|---|---|---|
| — | — | — | — | — | — | (empty — first entry expected with Phase-1 MVP rollout) |

## Related

- `wiki/patterns/staged-rollout.md` — pattern spec.
- `operations/kill-switches/` — per-change-id kill-switch JSON files.
- `operations/quarterly-review.md §Rules/policy drift` — QSR reviews stuck rollouts.
