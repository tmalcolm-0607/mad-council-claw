---
artifact-class: research-finding
source-tag: [R:frontier-2026]
confidence: high
wave: wave-001
lane: lane-a
date: 2026-05-07
sources:
  - https://www.anthropic.com/research/measuring-agent-autonomy
---

# Anthropic — Measuring Agent Autonomy

## Source
https://www.anthropic.com/research/measuring-agent-autonomy (fetched 2026-05-07)

## Load-bearing patterns

- **Two-axis autonomy framework**: Risk Scale (1-10) × Autonomy Scale (1-10). NOT a single tier; a 2D position with safety implications differing per quadrant.
- **Risk axis (1-10)**: From "no consequences for errors" (1) through "actions causing substantial harm" (10).
- **Autonomy axis (1-10)**: From "agent follows explicit instructions" (low) to "agent operates independently" (high).
- **Comparative-evaluation methodology**: Anthropic uses Claude-generated relative comparisons of individual tool calls in full context (system prompt + history) — NOT a fixed rubric. Prioritizes relative comparisons over absolute precision.
- **Operational metrics for autonomy**: Turn duration (start-to-stop time), auto-approval rates by user experience, interrupt frequency, agent-initiated clarification pauses.
- **Empirical observation, not prescriptive tiers**: Software tasks empirically show autonomy 3-4 (narrow scope) vs 6+ (independent decisions); Anthropic explicitly does NOT prescribe named tiers.
- **Oversight ≠ approval-chain**: Effective oversight requires positioning to intervene, not approving every action. Experienced users shift from action-approval to active monitoring.

## Verbatim quotes worth preserving

> "an emergent characteristic of a deployment, shaped by the model's behavior, the user's oversight strategy, and the product's design"

> "Effective oversight of agents requires more than putting a human in the approval chain"

> (paraphrased finding) Software tasks observed in the 3-4 range for narrow scope and 6+ for independent decision-making — autonomy is observed, not assigned.

## Implications for the engine catalog

The 2D framework directly extends the kit's existing `dangerous-operations-policy.md` (currently 1D — "is this dangerous? yes/no"). The engine should classify every agent invocation by (risk, autonomy) coordinates, not single-axis severity. The "oversight ≠ approval-chain" finding ratifies the kit's discipline of NOT requiring per-action approval for routine work — which the user has explicitly enforced via `autonomous-loop-discipline.md` ("the loop continues without asking permission"). The empirical-observation approach (vs prescriptive tiers) maps to the engine's eval harness: measure observed autonomy per skill invocation, then plot the population.

## NEW F-NNN candidates

- F-017 two-axis-autonomy-classifier — Engine annotates every skill / agent invocation with (risk:1-10, autonomy:1-10) coordinates; rendered in council-list / progress dashboards — confidence: H
- F-018 monitor-not-approve-mode — Default operator UX is "monitor with intervene-when-needed" not "approve every action"; per-action approval is opt-in for high-risk-high-autonomy invocations only — confidence: H
- F-019 autonomy-emergent-not-assigned — Engine measures observed autonomy per skill invocation; surfaces as drift signal when a skill's observed autonomy diverges from its declared envelope — confidence: M
- F-020 turn-duration-metric — First-class metric: start-to-stop wall-clock per agent invocation, exposed in skill-timing.jsonl + dashboards — confidence: H

## Confidence

HIGH — Anthropic's framework is the canonical 2D autonomy reference and directly extends the kit's existing 1D consent-gate model. The 2D coordinates are immediately implementable.
