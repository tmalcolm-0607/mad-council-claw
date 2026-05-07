---
artifact-class: research-finding
source-tag: [R:frontier-2026]
confidence: high
wave: wave-001
lane: lane-a
date: 2026-05-07
sources:
  - https://cursor.com/blog/agent-best-practices
  - https://cursor.com/docs/rules
  - https://rzaeeff.medium.com/mastering-cursor-rules-agent-skills-modes-models-and-best-practices-81908ec4f4a4
---

# Cursor + Windsurf — 2026 Best Practices

## Source
- https://cursor.com/blog/agent-best-practices
- https://cursor.com/docs/rules
- https://rzaeeff.medium.com/mastering-cursor-rules-agent-skills-modes-models-and-best-practices-81908ec4f4a4
- (fetched 2026-05-07 via WebSearch)

## Load-bearing patterns

- **Rules as persistent always-on context**: Rules are injected at the start of every conversation; they shape how the agent works with the codebase. Equivalent to the kit's `rules/*.md`.
- **Reference files, don't copy contents**: Rules SHOULD reference canonical examples in the codebase by path, not embed code. Keeps rules concise + automatically up-to-date.
- **Check rules into git**: Rules are repo-shared, not per-developer. Whole team benefits.
- **Commands for repeated workflows**: Stored as Markdown in `.cursor/commands/`, checked into git, callable as slash commands. Direct parallel to the kit's skills.
- **Agent Skills (dynamically loaded)**: Unlike Rules (always included), Skills load dynamically to keep context window clean. Same model as Anthropic Agent Skills.
- **2026 Agentic Engineering paradigm**: Shift from 2025 "Vibe Coding" to 2026 "Agentic Engineering" — engineers design architecture, agents execute autonomously, focus shifts to system architecture, data modeling, rule codification, and quality supervision.
- **Critical agent boundaries**: NEVER commit code without user review; NEVER delete config files without explicit confirmation; if a security vulnerability is found, STOP and report immediately.
- **Verify packages at runtime, not from training data**: Before importing packages, verify they exist by running the install command — don't trust the training-data prior.
- **Start simple, add rules only after repeated mistakes**: Rules are added reactively when the agent makes the same mistake repeatedly. NOT preemptively.
- **Boundaries on autonomous execution**: For autonomous agents, establish explicit boundaries before delegation.

## Verbatim quotes worth preserving

> (Cursor rules doc) "Reference files instead of copying their contents; this keeps rules short and prevents them from becoming stale as code changes."

> (Cursor agent best practices) "Start simple and add rules only when you notice the agent making the same mistake repeatedly."

> (2026 agentic-engineering article) "developers now design architecture while agents execute autonomously, with engineers focusing on system architecture, data modeling, rule codification, and quality supervision rather than writing code"

## Implications for the engine catalog

Cursor's Rules-vs-Skills distinction maps directly to the kit's `rules/` (always-on) vs `skills/` (dispatched). The "reference files, don't copy contents" rule is a critical discipline the kit only partially follows — many `rules/*.md` files embed pattern code instead of pointing to `wiki/patterns/`. The "start simple, add rules reactively" pattern is the inverse of the kit's current approach (we have many preemptive rules); F-NNN candidate for an "observed-mistake rule trigger" — only add rules when an anomaly fires N times. The "verify packages at runtime" pattern is a subtle anti-hallucination discipline the kit's `verification-protocol.md` rule should incorporate. The 2026 agentic-engineering paradigm shift validates the engine's overall thesis (orchestration + governance, not just code generation).

## NEW F-NNN candidates

- F-040 reference-not-embed-rule-discipline — Engine rule for rule files: reference codebase paths, don't embed code blocks. Audit script flags embedded code in rules — confidence: H
- F-041 reactive-rule-creation-trigger — Engine tracks anomaly frequency per failure mode; suggests rule creation only when same mistake recurs N times — confidence: M
- F-042 runtime-package-verification — Engine includes a "verify-packages-at-runtime" step in implementer agents per Cursor's discipline — confidence: M
- F-043 commands-as-shared-shortcuts — Engine treats slash commands as repo-shared shortcuts (`.claude/commands/*.md`) checked into git — confidence: M
- F-044 agentic-engineering-mode-default — Engine UX defaults assume operator is in "architect" role, not "coder"; affordances optimize for orchestration + supervision — confidence: H

## Confidence

HIGH — Cursor's docs are the most concrete public reference for production agent-IDE design; the patterns are widely-cited and validated across the dev-tool space.
