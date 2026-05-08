---
title: Rule — Triage gate
status: preview
since: 2026-04-18
last_reviewed: 2026-04-18
promote_by: 2026-07-31
---

# Rule — Triage gate

No council work begins until someone has written down what "done" looks like, who owns the outcome, and roughly how much effort is expected. Channels that want this discipline open at `status: triage` and stay there until an explicit `TRIAGE_ACCEPT` verdict transitions them to `ready`.

**Source:** internal engineering standards docs (work-item intake / triage guide) — "No work enters a sprint without triage approval" + explicit state flow `New → Triage → Ready → Active → Resolved → Closed`. Adopted via **ADOPT-002**.

## Why

Speculative council channels become graveyards. Without an acceptance criterion, contributors disagree about whether a verdict is warranted; without an owner, the criterion has no defender; without an effort estimate, retros have no baseline to calibrate against. The triage gate forces three decisions upfront — they can be wrong, but they can't be absent.

The gate is **opt-in**. Channels opened without `--triage` start at `status: active` (today's behaviour). Use triage for high-stakes prod channels, ambiguous intake requests, or anything that benefits from a human-visible "we are aligned on what we're doing" marker.

## State machine

```
[no state]
    │  /council-open --triage
    ▼
  triage  ──────── TRIAGE_ACCEPT ──────▶  ready
    │                                       │
    │  TRIAGE_REJECT                        │  first /council-post (any type)
    ▼                                       ▼
  closed                                  active  ───── final verdict ─────▶  resolved
                                                                                │
                                                                                │  /council-resolve
                                                                                ▼
                                                                              closed
```

Without `--triage`:
```
[no state]  ──────── /council-open ────────▶  active  ─────▶  resolved  ─────▶  closed
```

## Required fields at `status: triage`

Set by `council-open --triage`:

| Field | Required | Source |
|---|---|---|
| `channel.json:status` | yes | `"triage"` |
| `channel.json:owner_alias` | yes | `--owner <alias>` or the creator's alias |
| `channel.json:acceptance_criteria` | yes | `--acceptance-criteria "<text>"` — min 10, max 2000 chars |
| `channel.json:effort_estimate_hours` | recommended | `--effort-estimate <hours>` — informational, not enforced |
| `channel.json:environment_tier` | yes (already) | per ADOPT-004 |

`council-open --triage` without `--acceptance-criteria` rejects with exit code `TRIAGE_MISSING_CRITERIA`. The field is not backfilled silently — making the discipline skippable defeats the point.

## Allowed operations per status

| Status | `council-post` | `council-review` | `council-verdict` | `council-resolve` | `council-leave` |
|---|---|---|---|---|---|
| `triage` | **only** `type=triage-question` or `type=triage-context` | no | **only** `TRIAGE_ACCEPT` / `TRIAGE_REJECT` | only to close a rejected triage | yes, non-owner |
| `ready` | yes, any type | no (no work to review yet) | no (no thread yet) | no | yes, non-owner |
| `active` | yes | yes | yes (FIX/ACCEPT/ESCALATE/INVESTIGATE) | no | yes, non-owner |
| `resolved` | no | no | no | yes | yes, non-owner |
| `closed` | no | no | no | no | no-op (already left) |

The restricted `triage-*` message types (`triage-question`, `triage-context`) exist so triage participants can clarify scope without "starting work" — they're posts but they don't transition the channel to `active`. The first *non-triage* post is the marker that flips `ready → active`.

### Owner departures

Combines with `rules/single-owner-accountability.md`: if `owner_alias` tries to leave while `status ∈ {triage, ready, active}`, `council-leave` rejects with `OWNER_LEAVING_WITHOUT_TRANSFER` unless preceded by an `OWNERSHIP_TRANSFER` verdict. `resolved` + `closed` channels permit owner departure (work is done).

## Transition verdicts

### TRIAGE_ACCEPT

- Issuer MUST be `owner_alias` OR a Skeptic (STRIDE-driven; see `rules/stride-threat-model.md`) asserting scope sanity on the owner's behalf.
- `triage_decision.confirmed_acceptance_criteria` — copy-edit or verbatim restatement of `channel.json:acceptance_criteria` (mismatch ⇒ `council-resolve` atomically rewrites both the verdict and the channel field so they agree).
- `triage_decision.effort_estimate_hours` — may differ from the opening estimate; retros compute the gap.
- Resolution atomically sets `channel.json:status = ready`, `triaged_at_utc = now`, `triaged_by_alias = issuer.alias`.

### TRIAGE_REJECT

- Any active member may issue (deliberately low bar — triage should fail loudly, not die quietly).
- `triage_decision.rejection_reason` required (enum: `out_of_scope | duplicate | insufficient_context | wrong_tier | deprioritized`).
- Resolution sets `status = closed`; channel stays on disk for audit but rejects further writes. A completion report records the rejection.

## Why not a separate `/council-triage` skill

Considered during iter 3 design. Rejected per `rules/minimum-change.md`: a new skill would duplicate `council-open`'s preflight, filesystem, and atomic-write machinery for a difference of three optional flags. Adding the flags to `council-open` keeps the surface area flat. Future: if triage grows acceptance checklists, subteam assignments, or multi-stage gates, split out then — YAGNI until.

## CI and prod tier interactions (ADOPT-004)

- `ci` tier channels MAY skip triage if the invoking pipeline has passed external gates (fixture contract must include a passing `eval-certification.json` older than 1h). Without the certification, `ci` channels MUST use `--triage`.
- `prod` tier channels MUST use `--triage`. Opening a `prod` channel without the flag exits `PROD_TRIAGE_REQUIRED`.
- `local` tier is unconstrained — developer discretion.

## Metrics wiring

Counters consumed by `metrics/reliability-metrics.md`:

- `council_open.triage_mode_total{tier}` — channels opened with `--triage`.
- `council_verdict.triage_accept_total` / `council_verdict.triage_reject_total{reason}`.
- `triage.estimate_vs_actual_hours_gap` (histogram) — emitted by `council-retro` when the channel closes; difference between `effort_estimate_hours` and actual elapsed time from `triaged_at_utc` to final `council-resolve`.

## Anti-patterns

- **Auto-accept on open.** "If the creator is also the owner, skip TRIAGE_ACCEPT and jump straight to `ready`." Defeats the gate — the whole point is that someone stops and writes the criteria down. If the creator is the sole reviewer, they should issue `TRIAGE_ACCEPT` explicitly so there is an auditable record.
- **Triage-via-inference.** "Use the channel purpose as acceptance criteria." Purpose is high-level; acceptance criteria must be testable. Reject.
- **Backfilling criteria on an active channel.** Once `status = active`, don't flip back to `triage` to retroactively justify the work. Close the channel, open a new one if the scope really shifted.

## Work-item classification at triage (ADOPT-038)

Distilled from internal engineering standards docs (`Documentation/uatprocessguide.md §Bug or Change Request ADO Work Item Guidelines`): triage must distinguish **Bug** (observed behaviour diverges from expected) from **Change Request** (new capability wanted; no defect exists). MAD applies this to the triage gate:

Every channel opened with `--triage` must self-classify via an implicit or explicit category:

| Category | Signal in `acceptance_criteria` | Typical verdict path |
|---|---|---|
| **Bug** | "expected X, observed Y" — concrete divergence described | TRIAGE_ACCEPT if reproducible + scope-clear; TRIAGE_REJECT `reason=insufficient_context` if repro missing |
| **Change Request** | "add Z" or "support W" — net-new capability | TRIAGE_ACCEPT if fits current phase; TRIAGE_REJECT `reason=out_of_scope` / `deprioritized` if not |
| **Investigation** | "what happens when..." or "measure Q" — no remediation commitment | TRIAGE_ACCEPT routes through `/council-review` yielding INVESTIGATE verdict |

The classification is advisory, not schema-enforced. It belongs in the acceptance-criteria prose so reviewers can immediately calibrate their verdict expectations.

**Why this matters:** a change request that's treated as a bug ("why doesn't it already do Z?") produces FIX verdicts for features that don't exist yet. A bug treated as a change request ("we should also handle Y") lets a real defect linger as backlog. Making the category explicit in triage prevents both failure modes.

## Related

- `schemas/channel.schema.json` — `status`, `acceptance_criteria`, `effort_estimate_hours`, `triaged_at_utc`, `triaged_by_alias`.
- `schemas/verdict.schema.json` — `TRIAGE_ACCEPT`, `TRIAGE_REJECT` verdict types + `triage_decision` sub-object.
- `rules/single-owner-accountability.md` — owner-leave-during-triage interaction.
- `operations/environment-tiers.md` — per-tier triage requirements.
- `rules/minimum-change.md` — justification for bolting onto `council-open` instead of creating `council-triage`.
