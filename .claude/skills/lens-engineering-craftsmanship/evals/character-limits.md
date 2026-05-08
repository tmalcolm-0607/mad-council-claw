# Eval: MS Connect form character limits

The MS Connect form enforces hard character limits per field. Drafts that exceed silently get truncated when posted.

## Limits

| Field | Limit (chars) | Section in draft |
|---|---|---|
| Results / Impact | 6000 | Part 1 § "What results have you delivered" |
| Reflect on setbacks | 1000 | Part 1 § "Reflect on recent setbacks" |
| Goals (next period) | open | Part 1 § "What are your goals" |
| How will your actions help your goals | 1000 | Part 1 § "How will your actions and behaviors" |
| Perspective boxes (peer feedback) | varies | Part 2 — each of 6 boxes per peer |

## Validator (`connect-validate.ps1`)

Counts visible characters (markdown stripped) per field. Reports:
- Current count vs limit
- Which sentence pushes a section over (if over)
- Suggested cuts (lowest-information bullets first)

## Fixtures

### F1 — exactly at limit

```
Results section text exactly 6000 chars including all newlines.
```

Expected: PASS, count == 6000.

### F2 — 5994 chars (within limit)

Expected: PASS with note "6 chars headroom".

### F3 — 6043 chars (over limit)

Expected: FAIL. Output should:
- Show `6043 / 6000 (-43)`
- Identify the last bullet that pushed it over
- Suggest 2-3 candidate cuts ranked by lowest information density

### F4 — Setbacks 1024 chars (over)

Expected: FAIL. `1024 / 1000 (-24)`.

### F5 — How section 1000 chars (exactly at)

Expected: PASS, count == 1000.

## Pre-commit hook integration

Optional: a Husky-style pre-commit hook can call `connect-validate.ps1` against `.mad/reports/connect-prep-2026/connect-draft.md` and block the commit if any section is over.

## Common over-limit causes

1. Outside-perspective citations padding the prose ("manager noted that...", "peer review pointed out..."). Drop these; manager handles via Feedback section.
2. PR numbers + repo paths in prose. Genericize ("the cross-team identifier-hashing PR" not "PR #5042222 in LENS-CMS").
3. Em-dashes converted to periods doubled some paragraphs. Combine sentences instead.
4. Verbose hedging ("it would be reasonable to say that perhaps the team..."). Cut.
5. Multiple setbacks listed when 2 is enough.
