---
title: Pattern — Staged rollout for rule + prompt changes
status: preview
since: 2026-04-18
last_reviewed: 2026-04-18
promote_by: 2026-07-31
---

# Pattern — Staged rollout for rule + prompt changes

New rules, amended agent prompts, retuned thresholds, and changed verdict heuristics SHOULD NOT be force-landed everywhere at once. They roll out through observed cohorts, with a kill-switch, before they become defaults.

**Source:** internal engineering standards docs (flighting / staged-rollout guidance) — feature-flag service-driven feature flags + staged rollouts + A/B testing + incident mitigation without redeploy. Adopted via **ADOPT-006**.

## The problem

A "small" change to `rules/prompt-injection-policy.md` or an agent prompt in `agents/skeptic/agent.md` can shift the distribution of verdicts across every `prod` channel simultaneously. One untested interaction produces a wave of false positives or — worse — false negatives that nobody notices until the retro metrics diverge a week later.

Hard rollbacks on filesystem-based config aren't cheap: `git revert` is fine, but the affected channels have already written verdicts, logged retros, and influenced downstream decisions. The damage is in the data, not the code.

## The pattern

Every non-cosmetic change to the following files MUST ship via a stage-gated rollout:

- `rules/*.md` — any change to a MUST / MUST NOT clause, or a change to the enumerated ban list.
- `agents/*/agent.md` — any change to the role-prompt body.
- `metrics/*.md` — any change to an alert threshold.
- `schemas/*.schema.json` — any change that tightens validation (loosening is considered safe; tightening can reject in-flight writes).
- `mad.council.a2a.md §§8.x` — any change to a runtime-enforced numeric constant (body cap, poll interval, retry limit).

Cosmetic changes (typo fixes, link updates, clarifying parentheticals that don't change semantics) skip the rollout.

### Stages

```
  dark ────▶ canary ────▶ staged ────▶ default
  0%         1-5%         10-50%        100%
```

| Stage | Who sees the change | Signal to advance |
|---|---|---|
| **dark** | No production channels. Only `evals/fixtures/` + developer workstations loading from a feature branch. | Full Layer 0-4 eval suite green; Layer-4 adversarial lock set still green with the new behaviour. |
| **canary** | 1-5% of `prod` channels (select by `owner_alias` opt-in or explicit channel setting). | 72h live with zero new `council_post.suspicious_tagged_total` spikes, zero new `circuit_breaker_trip_total` trips attributable to the change, zero new CHK-HIGH items. |
| **staged** | 10-50% of `prod` channels (expand incrementally; double each checkpoint). | 2 weeks live with zero negative regressions + improved trend on the target metric (if there is one — purely defensive changes can advance on "no regression"). |
| **default** | All `prod` channels. Also `ci`, which always follows `default`. `local` may opt in at any stage. | Kept in this stage indefinitely. Revert requires a new staged-rollout in reverse. |

### Blast-radius rationale — why at least 4 stages (ADOPT-041)

The 4-stage model above is the MAD-tuned shape of a broader the ecosystem discipline documented in `CreatingServices/configuringPpeAndProdRings.md §Creating Stage Maps`: the ecosystem release pipelines use a **5-stage inner stage map** (Canary → Pilot → Medium → Heavy → Broad) because "fewer than 5 stages concentrates too many regions in the final stage, increasing blast radius. The standard 5-stage pattern is the recommended approach for SDP compliance."

The principle generalises beyond Azure region rollouts: **the larger the final cohort, the later a late-surfacing failure is caught, and the larger the population already affected when it is.** MAD's 4-stage shape (dark / canary / staged / default) already honours this — `staged` is itself an incremental doubling sub-stage, not a single jump from canary to default. A rollout that collapses `staged` into "flip to 100% after canary passes" violates this discipline even if it names the stages correctly.

Two concrete applications:

- **Large-cohort MAD deployments.** An installation that operates >50 `prod` channels SHOULD treat `staged` as a mandatory multi-checkpoint doubling path (1% → 5% → 10% → 25% → 50% → 100%), matching the Canary → Pilot → Medium → Heavy → Broad granularity. The stage *name* remains `staged`; the internal progression gets 4-5 checkpoints instead of 2-3.
- **Ring-based orchestration.** When MAD is layered on an external rollout system with ring-based stages (e.g. Azure-style deployment rings), the outer-ring manual-promotion gate (PPE → Prod) maps to MAD's promotion from `canary` → `staged`, and the inner stage map (Canary → Pilot → Medium → Heavy → Broad) maps to the internal checkpoint doubling within `staged`. The kill-switch (`operations/kill-switches/<change-id>.json`) is readable from any ring.

The invariant: **no single promotion step should increase cohort size by more than ~5×.** 1% → 5% → 10% → 25% → 50% → 100% satisfies this; 5% → 100% does not.

### How channels opt in to a stage

Each channel's `channel.json:settings` gains a `rollout_cohort` field (enum `early | default | late`; default `default`). The skill runtime reads the cohort and decides whether to apply the new behaviour:

```
if (change.stage == 'dark')   load only when env var MAD_DARK_ROLLOUT=1
if (change.stage == 'canary') load only when channel.settings.rollout_cohort == 'early'
if (change.stage == 'staged') load for 'early' + fraction of 'default' (by stable hash of channel.name)
if (change.stage == 'default') load for all cohorts
```

No file-level feature flag — the stage is a property of the change, tracked in `operations/rollout-log.md` alongside the commit hash that introduced it.

### Kill-switch

Every staged change carries a literal kill-switch path:

```
operations/kill-switches/<change-id>.json
  {
    "change_id": "rule-injection-ban-list-v2",
    "stage": "canary",  // live stage
    "revert_to": "rule-injection-ban-list-v1",
    "killed": false,
    "killed_at_utc": null,
    "kill_reason": null
  }
```

Setting `killed: true` via atomic rewrite immediately returns all cohorts to the previous behaviour. The skill runtime reads this file on every invocation (cheap — it's a single JSON read). No deploy, no restart. The kill propagates in the time it takes the next `council-*` invocation to read the file.

### Rollout log

One file: `operations/rollout-log.md`. Append-only. Each staged change gets one table row:

```markdown
| date | change-id | commit | stage reached | killed? | notes |
|---|---|---|---|---|---|
| 2026-04-20 | rule-injection-ban-list-v2 | a1b2c3d | default | no | +3 ban-list entries for multi-turn attacks |
| 2026-04-25 | skeptic-prompt-confidence-tightening | e5f6g7h | canary | **yes** (revert 2026-04-26) | 12h live; 3× false-positive rate on investigate-typed reviews |
```

## Integration with the QSR

The `operations/quarterly-review.md` ritual reviews the rollout-log: any change stuck in `canary` or `staged` for >1 QSR either promotes, retires, or gets a written justification for continued gradual rollout. No silent indefinite-canary state.

## STRIDE implications

- **Tampering.** A malicious actor changing the kill-switch file to falsely `killed: true` could disable defensive changes. Mitigation: kill-switches live in repo-controlled config, not user-writeable filesystem paths; changes go through normal PR review.
- **Elevation.** The rollout cohort field is per-channel, not per-member, so a non-owner member cannot force-promote a channel to `early` cohort. Owner-only (per `rules/single-owner-accountability.md` write-gate).

## Anti-patterns

- **Skip-to-default with "just a small change".** The size of the change is never the criterion — its side-effect surface is. A 1-line change to a ban-list regex still goes through dark → canary → staged → default.
- **No kill-switch.** A staged rollout without a documented kill-switch is just a late-bound code change; it provides none of the "revert fast in prod" benefit.
- **Permanent canary.** A change that sits in `canary` for a quarter without either promotion or retirement is the worst of both worlds — neither deployed nor reverted. Retire or promote at the next QSR; don't let it fester.

## Related

- `rules/minimum-change.md` — keep each rollout atomic and understood in isolation.
- `operations/migration-strategy.md` — heavier migrations use the same stages but with explicit data-migration scripts.
- `operations/quarterly-review.md §Rules/policy drift` — QSR gate on preview + stuck rollouts.

## Source

internal engineering standards docs (flighting / staged-rollout guidance) — a central experimentation/configuration service (ECS-style) for feature flags, staged rollouts, A/B testing, incident mitigation without redeploy.
