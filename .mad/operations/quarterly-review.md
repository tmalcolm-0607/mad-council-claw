# Quarterly service review (QSR) — MAD operational ritual

A recurring review of MAD council health, adoption, and incidents. Runs every **quarter** (not monthly as the ecosystem does — MAD is lower-volume) and feeds back into the `plans/phase-*.md` roadmap and the `_review-checklist.md` backlog.

**Source:** internal engineering standards docs (service-review process — Monthly Service Review format: leadership visibility, compliance posture, availability/reliability/security metrics). Adopted via **ADOPT-005**.

## Why

Metrics that nobody reviews are noise. A standing review forces:

- Someone looks at every alert counter at least once per quarter and asks whether the threshold is still right.
- Drift between stated policies (rules, SLOs) and observed behaviour gets surfaced before it becomes incident fuel.
- `_review-checklist.md` gets a natural flush point — deferred items either move or die.
- The phase plans get re-prioritised with evidence from real usage rather than initial guesses.

## Cadence

- Quarterly — first Tuesday after quarter close. 90 minutes.
- Skippable **only** if the preceding quarter had zero production councils (measured by `council_open_total{environment_tier=prod}` == 0). Skips are logged in `operations/quarterly-review-log.md` for audit.

## Weekly promotion review (ADOPT-030)

Between the quarterly QSR and the daily CI gate, a lighter weekly touchpoint catches two specific drifts early:

1. **`status: preview` items whose `promote_by` date is approaching.** Review every rule/pattern with a `promote_by` date in the next 30 days. Decide: promote to `stable`, extend `promote_by` (with stated reason), or retire.
2. **Staged-rollout entries stuck in `canary` or `staged`.** Any row in `operations/rollout-log.md` that's been in the same stage for >14 days gets a status check — promote, retire, or document the blocker.

### Format

- 15-20 minutes, Tuesday mornings (aligned with the ecosystem's Dogfood weekly cadence at `pipelinepermissions.md`).
- Facilitator: whoever owns the `_status-convention.md` index that week (rotates quarterly).
- Output: one row per decision added to `operations/weekly-promotion-log.md` (append-only). Format:

```markdown
| week | change-id or rule | decision | reason | next review |
|---|---|---|---|---|
| 2026-W18 | rules/triage-gate.md | extend promote_by to 2026-10-31 | need 2 more QSRs of live data | 2026-W32 |
```

No formal attendee list — this is a lightweight review. Decisions land in writing; disputed decisions escalate to the next QSR.

### Why weekly instead of monthly

A typical dogfood cadence is weekly because build signing happens weekly — weekly lets you catch "this isn't ready for prod" before the signed build lands. MAD's analogue is the preview → stable promotion: weekly catches "this preview rule has no evidence for it" before a quarter passes without review.

Monthly would be the typical service-review cadence, but a monthly service review covers operational posture (incidents, availability) — orthogonal to promotion discipline. The two cadences serve different purposes; keep both.

## Attendees

| Role | Responsibility at QSR |
|---|---|
| Facilitator (rotates quarterly) | Drives agenda; captures decisions; publishes summary |
| Council owners (one per `prod`-tier channel active in quarter) | Present their channel's health; own their action items |
| Rules steward | Owns `rules/*.md` changes; defends or retires policies with insufficient evidence |
| Evals steward | Owns `evals/*.md` coverage; reports drift in Layer 4 adversarial lock set |
| Metrics steward | Owns `metrics/*.md`; flags alert thresholds that need re-calibration |

## Required agenda (min 60 min)

### 1. Reliability posture (15 min)

Read from `metrics/reliability-metrics.md` counters:

- `council_open_total{environment_tier}` — how many channels opened; breakdown by tier.
- `council_verdict.verdict_distribution_total` — balance of FIX / ACCEPT / ESCALATE / INVESTIGATE + the three lifecycle verdicts.
- `council_check.circuit_breaker_trip_total` — polling degradation events. >baseline × 2 → investigate.
- `council_post.session_mismatch_total` — spoofing attempts. ANY value ≥1 → full investigation before QSR closes.
- `triage.estimate_vs_actual_hours_gap` (from `rules/triage-gate.md §Metrics`) — calibration drift on effort estimates. If median gap > 2× estimate, acceptance-criteria discipline needs review.

### 2. Security posture (15 min)

- Review `council_post.suspicious_tagged_total` trend. New spikes → check `rules/prompt-injection-policy.md` ban list; add any novel techniques from the quarter's observations.
- Review Layer-4 adversarial regression lock set. Any tests softened / disabled since last QSR? Why?
- Review the OWASP/Vectra/Lakera adaptive-attack references in `wiki/references.md §6` for new attack families to add to Layer 4.
- **Security review program cadence (ADOPT-039).** Read `operations/security-review-log.md`; confirm the next `Checkup` is scheduled ≤ 6 months from the most recent prior `Baseline` or `Checkup` row. If overdue, the QSR itself schedules it as an action item. Surface every HIGH finding from prior reviews that hasn't closed — open HIGHs block staged-rollout promotions per `wiki/patterns/staged-rollout.md §Integration with the QSR`. Confirm any new feature / skill / verdict type that shipped this quarter and introduced new data flows, trust boundaries, or external integrations has either booked a `Feature` review or produced a written justification for why it didn't need one.
- **Standing-admin audit (ADOPT-040).** Walk `prod`-tier channels for members with `role: admin` and absent-or-distant `membership_expires_at`. Each standing admin either gets time-bounded at the QSR or gets written justification logged as a CHK entry per `rules/dangerous-operations-policy.md §Least-privilege default` rule 4.

### 3. Backlog flush (15 min)

- Open items in `_review-checklist.md` older than 2 QSRs (~6 months) MUST be closed: `RESOLVED` (with evidence), `DEFERRED` (with target phase and why it's still deferred), or `WITHDRAWN` (with rationale).
- Open adoption items treated the same way — anything not adopted within 2 QSRs of surfacing either becomes a tracked deferral with a named owner or gets withdrawn.

### 4. Rules/policy drift (10 min)

- Each `rules/*.md` with `status: preview` (see `ADOPT-009`): is it ready to promote to `stable`, or should it be retired?
- Any skill that inherits a rule but whose plan.md or tests don't enforce it — that's a policy drift and gets a CHK entry on the spot.

### 5. Roadmap decision (5 min)

- Which open phase-plan item becomes top priority next quarter? One decision, one owner, one exit criterion. Logged in `plans/phase-*.md`.

## Optional agenda (add if time permits)

- Cost review (consume `metrics/financial-metrics.md` + `operations/cost-projection.md` variance).
- Performance review (consume `operations/performance-benchmarks.md` vs. current measurements).
- Multi-user / privacy posture sweep (`operations/multi-user-isolation.md`, `operations/privacy-data-governance.md`).

## Output artifact

QSR produces a single file at `operations/quarterly-review-log.md` (new file; append-only). Format per quarter:

```markdown
## Q<n> <year>   (facilitator: <alias>)

- Reliability: <green/yellow/red> — <top-1 signal and number>
- Security: <green/yellow/red> — <top-1 concern>
- Backlog: <n opened / m closed / k deferred this quarter>
- Rules drift: <n preview-to-stable promotions / m stable-to-retired / k drift findings>
- Next-quarter priority: <named work-item + owner + exit criterion>

### Decisions
- <decision 1, 1 line each>

### New CHK items opened
- CHK-<id>: <1-line summary>

### Actions
- <action>, owner: <alias>, due: <next QSR or earlier>
```

## Escalation path

A QSR finding with **blocking severity** (e.g., an unhandled spoofing attempt, a rule violation observed in production, a regression in Layer 4 adversarial gate) MUST be:

1. Assigned to a single owner within 24 hours of the QSR close.
2. Posted to the `meta-mad-council` channel (owner-of-MAD-itself channel; tier `prod`) with `--type task`.
3. Resolved via a standard `council-verdict` cycle — not carried forward to next QSR.

Non-blocking findings can wait for the next QSR if they're still outstanding.

## Related

- `metrics/reliability-metrics.md` — source of the reliability counters.
- `metrics/safety-metrics.md` — source of the security signals.
- `rules/triage-gate.md §Metrics wiring` — triage calibration counters.
- `_review-checklist.md` — backlog that QSR must flush.
- `plans/phase-*.md` — roadmap that QSR re-prioritises.

## Why quarterly, not monthly

Large production services typically run a monthly service review because they operate at production scale with live customers, incidents, and compliance deadlines. MAD is a lower-volume, lower-stakes system — monthly reviews would meet the discipline diminishing-return threshold quickly. Quarterly preserves the benefit (forced flush, leadership visibility, calibration) without burning hours on reviews that would have nothing to say. If MAD grows to production scale with regular incidents, revisit the cadence.
