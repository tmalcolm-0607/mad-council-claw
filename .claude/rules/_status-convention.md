# Convention — `status:` frontmatter on rules and patterns

Every `rules/*.md`, `wiki/patterns/*.md`, and `wiki/implementations/*.md` file SHOULD carry a `status:` frontmatter field indicating maturity. Readers (humans and skills) use it to weigh how much to trust the doc against observed behaviour.

**Source:** internal engineering standards docs (preview-documentation guidance — preview tag for evolving standards, coordinate with area champions). Adopted via **ADOPT-009**.

## The three values

| Value | Meaning | Treatment |
|---|---|---|
| `stable` | Validated by ≥1 full rollout cycle (dark→default per `wiki/patterns/staged-rollout.md`). Skills enforce; evals have locked regression tests; rule has survived ≥1 QSR review. | Default citation target. Break only via staged rollout. |
| `preview` | Drafted and cross-linked but not yet validated end-to-end. May be enforced by skills optionally (`inherits-rules` on an individual skill) but not globally. | Readers should note the status in citations. Break-changes acceptable with `_review-checklist.md` entry. QSR reviews each preview item for promotion or retirement. |
| `deprecated` | Retained for historical reference but superseded. New skills MUST NOT inherit it. Eval fixtures may continue to reference it to verify migration paths. | Cite only in "historical" context. Remove after two QSRs from deprecation date. |

Absence of `status:` implies `stable` (backward-compatible for existing files).

## Format

YAML frontmatter at the top of the file:

```markdown
---
title: Rule — Single-owner accountability
status: stable
since: 2026-04-18
last_reviewed: 2026-04-18
---

# Rule — Single-owner accountability
...
```

Fields:

- `status` — one of `stable | preview | deprecated`. Required.
- `since` — ISO-8601 date of first publication. Required.
- `last_reviewed` — ISO-8601 date of most recent QSR acknowledgement. Updated at each QSR.
- `supersedes` (optional) — filename of a deprecated rule this replaces.
- `superseded_by` (optional) — filename that replaces this one (set when marking deprecated).
- `promote_by` (optional, `preview` only) — target date for promotion-to-stable; QSR past this date without promotion triggers a forced retire-or-promote decision.

## Where it applies

| Location | Required? | Enforcement |
|---|---|---|
| `rules/*.md` | yes | `scripts/check-mad-links.ps1` (Phase-1 deliverable) enforces presence; CI fails PR if missing |
| `wiki/patterns/*.md` | yes | same |
| `wiki/implementations/*.md` | yes | same, but `stable` requires ≥1 MAD skill referencing the implementation |
| `operations/*.md` | recommended | not enforced (ops docs may be narrative; status header less useful) |
| `mad.council.a2a.md` + README.md + loop-state + review-checklist + similar top-level | not applicable | these are not rules/patterns |

## Initial sweep

The following files are tagged `preview` as of 2026-04-18 because they reference Phase-5 features not yet live:

- `rules/stride-threat-model.md` §ASTRIDE extensions — Phase-5 only
- `wiki/patterns/multi-model-ensemble.md` — requires Phase-5 ensemble runtime
- `wiki/patterns/learning-signals.md` — Phase-5 retro-intelligence pipeline

All other pre-existing `rules/*.md` and `wiki/patterns/*.md` default to `stable` — they've been cross-linked and referenced from skills through iters 1-4 and have survived the `_review-checklist.md` MEDIUM/LOW close-out.

The three ADOPT rules introduced in iters 2-4 (`single-owner-accountability.md`, `triage-gate.md`) are **`preview`** until they've been through one full QSR — the adoption is 2026-04-18; promotion target is the first QSR after 2026-07-18.

## Not a gate

`status: preview` is **not** an excuse for the rule to be ignored. A skill that `inherits-rules` a preview rule inherits it fully — preview means "the wording may change before final QSR promotion," not "the rule is optional." Preview vs stable is a governance marker, not a runtime flag.

## Related

- `operations/quarterly-review.md §Rules/policy drift` — QSR step that flushes preview items.
- `wiki/patterns/staged-rollout.md` — the mechanism preview rules progress through before being declared stable.
