---
artifact-class: research-finding
source-tag: [R:frontier-2026]
confidence: high
wave: wave-001
lane: lane-a
date: 2026-05-07
sources:
  - https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices
---

# Anthropic — Skill Authoring Best Practices

## Source
https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices (fetched 2026-05-07)

## Load-bearing patterns

- **Concise is key (context window is a public good)**: Only add context Claude doesn't already have. Challenge each piece: "Does Claude really need this? Can I assume Claude knows this? Does this paragraph justify its token cost?"
- **Default assumption: Claude is already very smart**: Don't restate background knowledge. The bad-vs-good example (50 vs 150 tokens) shows the discipline.
- **Set appropriate degrees of freedom**: Match specificity to fragility. High-freedom for code review (many valid approaches); low-freedom for database migrations (one safe path).
- **Robot-on-a-bridge analogy**: Narrow bridge → narrow rules. Open field → general direction + trust.
- **Test with all models you plan to use**: What works perfectly for Opus might need more detail for Haiku.
- **Frontmatter contract**: `name` (≤64 chars, lowercase/numbers/hyphens, no `anthropic`/`claude`), `description` (≤1024 chars, third-person, includes both WHAT and WHEN).
- **Description is critical for skill selection**: Claude picks the right skill from 100+ available based on the description. WHAT + WHEN, third-person.
- **Gerund-form naming preferred**: `processing-pdfs`, `analyzing-spreadsheets`, `managing-databases`. Or noun phrases. Avoid vague names (`helper`, `utils`).
- **Progressive disclosure via referenced files**: SKILL.md is a TOC; detailed content in separate files loaded on-demand. Body under 500 lines.
- **References ONE level deep**: Not nested. Claude may partial-read nested references and miss content.
- **Table-of-contents for >100-line reference files**: Ensures Claude sees the full scope even when previewing.
- **Workflows with checklists**: Multi-step workflows include checklist Claude can copy and tick off.
- **Feedback loops**: Run validator → fix errors → repeat. Greatly improves quality.
- **Avoid time-sensitive information**: Will become outdated. Use "old patterns" detail-block for legacy.
- **Consistent terminology**: Pick one term and use it throughout (e.g., always "API endpoint", never mix with "URL"/"path").
- **Solve, don't punt**: Scripts handle errors explicitly rather than failing back to Claude.
- **No voodoo constants**: Document why every value is what it is.
- **Pre-made utility scripts > generated code**: More reliable, save tokens, save time, ensure consistency.
- **Plan-validate-execute pattern**: Create plan file → validate plan with script → execute → verify. Catches errors early.
- **Forward slashes always (Unix-style paths)**: Even on Windows. Backslashes break on Unix.
- **Don't offer too many options**: Provide a default + escape hatch, not a menu.
- **Build evaluations FIRST**: Before extensive documentation. Evaluation-driven skill development.
- **Iterate with two Claudes**: Claude A helps refine the skill; Claude B uses it on real tasks; observe gaps; refine with Claude A.
- **MCP tool references use full names**: `ServerName:tool_name` format. Without prefix, Claude may fail to locate the tool.

## Verbatim quotes worth preserving

> "The context window is a public good. Your Skill shares the context window with everything else Claude needs to know."

> "Always write in third person. The description is injected into the system prompt, and inconsistent point-of-view can cause discovery problems."

> "Create evaluations BEFORE writing extensive documentation. This ensures your Skill solves real problems rather than documenting imagined ones."

## Implications for the engine catalog

This document is the canonical authoring reference and the kit's `skill-standards.md` already implements ~80% of it. Gaps the engine should close: (1) frontmatter contract enforcement is currently advisory; should be a PreToolUse hook on Write to skills/. (2) "Reference one level deep" rule isn't audited; F-NNN candidate for nested-reference detection. (3) "Build evaluations first" is the inverse of the kit's current evals discipline (we mostly add evals after); F-NNN for an evals-first skill scaffold. (4) The Claude-A-with-Claude-B iteration pattern is uniquely valuable — it's the kit's `pair-programming` mode that doesn't yet exist as a first-class skill. (5) The concise-is-key discipline is consistently violated in the kit's longer SKILL.md files; an audit pass to compress is overdue.

## NEW F-NNN candidates

- F-051 frontmatter-contract-hook — Engine has a PreToolUse hook on writes to skills/ that validates frontmatter (name + description format, length, third-person, gerund form) — confidence: H
- F-052 reference-depth-audit — Engine audits skills for nested references (>1 level deep); flags as a quality finding — confidence: H
- F-053 evals-first-scaffold — Engine `/skill-create` shape: evals first (3 fixtures + expected outputs), then SKILL.md body. Evals-driven skill authoring — confidence: H
- F-054 pair-programming-mode — Engine surfaces a Claude-A-helps-Claude-B-iterate pattern: orchestrator spawns "skill author" subagent + "skill consumer" subagent in a refine loop — confidence: M
- F-055 skill-conciseness-audit — Engine audits SKILL.md files against the concise-is-key discipline (token-cost-vs-information-value); flags overly-verbose sections — confidence: M
- F-056 mcp-tool-name-validation — Engine validates that MCP tool references in skills use `ServerName:tool_name` format; flags bare tool names — confidence: H

## Confidence

HIGH — Authoritative Anthropic reference. The kit's skill-standards.md should be cross-referenced against this and updated where divergent.
