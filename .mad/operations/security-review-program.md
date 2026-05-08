---
title: Operations — Security review program
status: preview
since: 2026-04-18
last_reviewed: 2026-04-18
promote_by: 2026-07-31
---

# Security review program

MAD inherits the ecosystem's structured security-review discipline: every council installation engages a security reviewer through defined review types with triggers and cadence, rather than ad-hoc outreach. See internal engineering standards docs (security-review process).

Adopted via **ADOPT-039**.

## Review types

| Type | Duration | Trigger | Cadence |
|---|---|---|---|
| **Baseline** | 45 min | First formal security review for a new council installation. Prerequisite: initial self-assessment (STRIDE sweep per `rules/stride-threat-model.md` + `evals/layer-4-adversarial.md` fixture baseline). | Once per installation, before `--tier prod` channels are opened. |
| **Consultation** | 25 min | Team needs guidance on a specific decision — new authN approach, new data-handling path, architectural trade-off with security implications. | Any time; not limited to new installations. |
| **Feature** | 25 min | New feature / skill / verdict type introduces new data flows, trust boundaries, or external integrations not covered in a prior review. | Per-feature; triggered by the feature author. |
| **Checkup** | 25 min | Posture drift assessment: have any changes since the last review shifted the threat surface? | **Every 6 months, mandatory.** Teams are responsible for self-scheduling; no auto-initiation. |

**Rationale for mandatory Checkup.** The council framework holds adversarial-review state (`channel-verdicts/*.json`, `rules/prompt-injection-policy.md §ban-list`, `evals/layer-4-adversarial.md` fixtures) that decays as the surrounding ecosystem shifts. Six months is the outer bound at which the snapshot is stale enough that "still secure" becomes a claim that needs re-verification rather than default assumption.

## Scheduling

Reviews are booked through whatever security-review portal the installation's parent organisation provides (many large organisations run their own threat-modeling or security-review portal). MAD itself does not bind the scheduling surface.

**Urgent escalation path.** If scheduling availability is outside an acceptable window, reach out to the designated security-program leads — not directly to the reviewer. This exists to protect reviewer time across the multiple teams they support.

## Output artifacts

Each completed review produces one row in `operations/security-review-log.md`:

```markdown
| date | type | reviewer | scope | findings-count | follow-up CHK items |
|---|---|---|---|---|---|
| 2026-04-18 | Baseline | <alias> | MAD council scaffold | 0 HIGH / 2 MEDIUM | CHK-039, CHK-040 |
| 2026-10-18 | Checkup | <alias> | Posture drift since 2026-04-18 | 0 HIGH / 0 MEDIUM | — |
```

Findings with severity HIGH block the next staged-rollout promotion per `wiki/patterns/staged-rollout.md §Integration with the QSR` until closed.

## Pre-review self-assessment (Baseline prerequisite)

Before booking a Baseline review, the team completes:

1. **STRIDE walk-through.** Every category in `rules/stride-threat-model.md §Canonical 6 categories` mapped to the council's surface (channels, threads, verdicts, MAD artifacts, A2A bridges).
2. **Ban-list coverage.** `rules/prompt-injection-policy.md §ban-list` audited for known attacker techniques (reference OWASP + current LLM-attack taxonomies).
3. **Adversarial fixture lock.** `evals/layer-4-adversarial.md` has at least one fixture per trust boundary.
4. **Dangerous-ops enumeration.** `rules/dangerous-operations-policy.md §Operation categories` covers every side-effecting skill path.

The output is a 1-2 page document for the reviewer, not a deep threat model — the deep model is what the review produces collaboratively.

## QSR integration

`operations/quarterly-review.md §Security` (added with this adoption):

- Confirms the next Checkup is scheduled ≤ 6 months from the previous one.
- Surfaces any open HIGH findings from prior reviews that haven't closed.
- Tracks whether new features shipped this quarter triggered a Feature review.

## STRIDE implications

- **Repudiation.** The log file is the audit trail; treat it as the source of truth for "did a review happen" — no review is "done" until the log row is written.
- **Information Disclosure.** Review outputs may contain sensitive threat details; keep `security-review-log.md` in the same access-control tier as the repo itself and do not duplicate findings into broader channels.

## Anti-patterns

- **Ad-hoc "I know someone on the security team".** Violates the scheduling discipline; the reviewer becomes a bottleneck for the whole team rather than a scheduled resource. Always book through the portal.
- **Skipping Checkup because "nothing has changed".** The point of Checkup is to re-verify that belief; the review itself is the evidence, not the team's own assessment.
- **Baseline without self-assessment.** Wastes reviewer time discovering what the team could have surfaced. The prerequisites section is non-optional.

## Related

- `rules/stride-threat-model.md` — the framework each review applies.
- `rules/prompt-injection-policy.md` — the first surface every review touches.
- `evals/layer-4-adversarial.md` — fixture lock set that baseline reviews establish.
- `operations/quarterly-review.md §Security` — QSR gate on review cadence.


## Source

internal engineering standards docs (security-review process) — Product Security Review process: Baseline (45m) / Consultation (25m) / Feature (25m) / Checkup (25m, mandatory biannual). Scheduling via the organisation's threat-modeling portal; urgent escalation via program leads.
