---
title: Rule — Council verdict artifact
status: preview
since: 2026-05-02
last_reviewed: 2026-05-02
promote_by: 2026-08-02
---

# Rule — Council verdict artifact

> **Status: preview.** Adopted 2026-05-02 per `.mad/reports/d6-council-verdict-iter3a-2026-05-02.md` (M8 — producer-side rule extension surfaced by Architect A3). Promotion to `stable` is gated on the next Quarterly Standards Review (QSR), no earlier than 2026-08-02.

## Rule statement

Any `/council-review` invocation that produces a phase-bearing verdict MUST write the verdict to `.mad/reports/council-verdict-{phase}-{date}.md` from the council-review skill body itself — not as a side effect of a downstream consumer, not as an in-conversation summary that "could be persisted later," and not under any other naming convention.

The artifact is the verdict. If the artifact doesn't exist on disk, the verdict didn't happen for the purposes of `Check-LoopStopConditions.ps1` Step 6 enforcement.

## Required body sections

The body MUST satisfy the validity oracle enforced by `Check-LoopStopConditions.ps1` Step 6 (per `.mad/reports/d6-council-verdict-iter3a-2026-05-02.md` M4):

1. **File size** — at least 500 bytes. Stub files (empty headers, placeholder text) fail the oracle.
2. **Reviewer summary table** — explicit `## Reviewer summary` heading (case-insensitive), with one row per reviewer role (Architect, Skeptic, Advocate at minimum) listing each role's verdict and confidence score (0-100).
3. **Median confidence** — explicit line `Median confidence: N` (case-insensitive, `N` is an integer 0-100). The median is computed across all reviewer rows in the summary table.
4. **Decision or verdict consensus** — explicit line beginning `Decision:` OR `Verdict consensus:` (case-insensitive). One of: `FIX`, `ACCEPT`, `ESCALATE`, `INVESTIGATE` (or the consensus equivalent).

Producers SHOULD also include:
- **Date** — front-of-body `**Date:** YYYY-MM-DD` line; the date inside the body is informational and the gate cross-checks against the filename.
- **Cross-role agreement table** — when ≥2 roles concur on a finding, list the concurrence as `M1`, `M2`, ... entries (per the d6 verdict's own structure).
- **Defended trade-offs** — explicit list of design decisions that are settled and not to be re-litigated.

## Filename convention

Phase-keyed: `council-verdict-{phaseId}-{YYYY-MM-DD}.md` where `{phaseId}` matches the regex `^P\d+(?:-[a-z0-9]+)?$` (e.g. `P2`, `P3-exception-boundary`, `P4-handler-extraction`, or sub-phase tags like `P2-iter3a`).

The date in the filename is informational only — the gate sorts by `LastWriteTime` and picks the most recent matching file (per M3, this avoids time-zone ambiguity and glob smuggling).

Legacy files (`d5-council-verdict-{date}.md`, `d6-council-verdict-iter3a-{date}.md`) remain valid for historical reference but are NOT detected by the gate; new producers MUST use the phase-keyed convention.

## Atomic write

Per `.claude/rules/concurrency-safety.md` §2, the producer MUST use the write-temp-then-rename atomic pattern. A reader (the gate, or a parallel skill) must never see a half-written verdict. The gate's M5 retroactive-backfill detection compares verdict `LastWriteTime` against `progress.json:phases.<phase>.completed_utc`; verdicts written more than 5 minutes after phase completion are rejected.

## Producer responsibilities

The skill emitting the verdict (`/council-review`, or any future `/council-verdict`-style skill that wraps a multi-role review) is responsible for:

1. Writing the artifact from the skill body, not deferring to a downstream consumer.
2. Producing a body that satisfies the validity oracle on first write — no "I'll fill in the median later" stubs.
3. Using atomic write so the gate never reads a half-written file.
4. Filing the artifact under `.mad/reports/` (not under `specs/<N>/reviews/`, which serves a different audience — MAD-pipeline review artifacts).

## Enforcement

| Layer | Mechanism |
|---|---|
| Producer-side (this rule) | Skill body MUST write the artifact directly. Reviewers of new `/council-review`-shaped skills check this in code review. |
| Consumer-side (`Check-LoopStopConditions.ps1` Step 6) | For each phase >= `-EnforceCouncilVerdictsFromPhase` (default `P2`), gate verifies presence + validity oracle + non-backfill. Any miss fails the loop's stop-condition check with `[FAIL]`-prefixed message. |
| Continuous improvement | `/apply-learnings` after each phase looks for new producer-side gaps; council reviews each preview rule for promotion or retirement at QSR. |

## Out of scope (v1)

Per the d6 verdict's defended trade-offs and deferrals:

- **Substance enforcement** — this rule enforces presence + structural validity, not the *quality* of the council deliberation. Substance enforcement (multi-model agreement, evidence-protocol audit) is iter3-B scope (`council-verdict-multi-model.md` rule, future).
- **Backfill of D1-D4** — not feasible (source threads lost); accepted as permanent gap per `verification-protocol.md` Rule 1+4.
- **Single-source-of-truth for verdicts** — both `.mad/reports/council-verdict-*.md` (loop-meta) and `specs/<N>/reviews/*.md` (MAD-pipeline) coexist as v1; consolidation revisited in iter6+ once both conventions have ≥3 examples each.

## Related

- `.claude/rules/review-gate-protocol.md` — sibling pattern; this rule extends the producer-side discipline for council verdicts specifically (review-gate-protocol covers MAD-pipeline phase reviews under `specs/<N>/reviews/`).
- `.claude/scripts/Check-LoopStopConditions.ps1` Step 6 — the enforcement.
- `.mad/reports/d6-council-verdict-iter3a-2026-05-02.md` — the council verdict that ratified this rule (M8).
- `.claude/rules/concurrency-safety.md` §2 — the atomic-write discipline.
- `.claude/rules/_status-convention.md` — preview/stable/deprecated lifecycle.
- `.claude/rules/verification-protocol.md` — Rule 1 (FETCH BEFORE CITE) and Rule 4 (ACTUAL BEFORE PRESENT) underpin why a "verdict that wasn't written" is not a verdict.
