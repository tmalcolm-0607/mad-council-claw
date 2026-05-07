---
artifact-class: research-finding
source-tag: [R:software-patterns]
confidence: high
wave: wave-002
lane: lane-a
date: 2026-05-06
sources:
  - https://github.blog/ai-and-ml/generative-ai/spec-driven-development-with-ai-get-started-with-a-new-open-source-toolkit/
  - https://github.com/github/spec-kit
  - https://developer.microsoft.com/blog/spec-driven-development-spec-kit
  - https://github.com/github/spec-kit/blob/main/spec-driven.md
  - https://levelup.gitconnected.com/exploring-spec-driven-development-sdd-a-practical-guide-with-github-speckit-and-copilot-72fd9a70535a
  - https://intuitionlabs.ai/articles/spec-driven-development-spec-kit
  - https://www.augmentcode.com/guides/what-is-spec-driven-development
  - https://www.augmentcode.com/tools/best-spec-driven-development-tools
---

# Spec-driven development for AI agents (SpecKit)

## Source
Multi-source synthesis (web search 2026-05-06). See `sources` frontmatter.

## Load-bearing patterns

- **The four-phase canonical workflow** (SpecKit + most adopters):
  1. `/speckit.specify` — capture business context, success criteria, constraints. Spec is a contract, not a wish-list.
  2. `/speckit.plan` — translate spec into architectural decisions; what to build, what to defer, what to refuse.
  3. `/speckit.tasks` — decompose plan into testable units with explicit dependencies.
  4. `/speckit.implement` — AI agents execute under those constraints (not free-form coding from a prompt).
  This is **identical in shape** to the kit's `/mad-spec → /mad-plan → /mad-tasks → /mad-implement` chain — strong cross-validation that the kit's MAD workflow IS the industry-converging spec-driven pattern.
- **Spec as contract, not as documentation**. The semantic shift: a spec is the source of truth that AI tools generate, test, and validate code AGAINST. Code is downstream; spec is upstream. Documentation is a derived artifact, not a parallel one. This is incompatible with "code-first then doc-it-later" workflows.
- **The 88K-stars adoption signal (April 2026)**. SpecKit reached 88K GitHub stars and 129 releases by April 2026, with template packages for 28 named AI agent platforms (Copilot, Claude Code, Gemini CLI, Cursor, Windsurf, +23 others). This is the single most-validated 2026 productivity claim ("specs make AI coding work better"). Industry adoption signal: spec-driven is becoming the norm, not an experimental approach.
- **Specifications as code artifacts**. Specs live in version control alongside code; PR diffs against specs are reviewed; spec changes trigger downstream regeneration. This is the architectural commitment — specs are NOT chat prompts saved into a wiki, they are first-class code-equivalent artifacts.
- **AI assistants enforce specs automatically**. The "AI assistants automatically enforce" claim is meaningful: the AI tool, given a spec, will refuse or flag deviations from the spec. The spec acts as a guardrail on AI generation. This requires (a) machine-readable spec format, (b) automatic spec-vs-code drift detection, (c) refusal-or-flag behavior in the agent.
- **IBM's `iac-spec-kit` variant** — specs for infrastructure-as-code; AI translates business requirements into Terraform/Bicep/etc. The pattern generalizes beyond app code; it's "intent → spec → executable artifact" for any artifact class.

## Verbatim quotes worth preserving

> "Instead of coding first and writing docs later, in spec-driven development, you start with a spec. This is a contract for how your code should behave and becomes the source of truth your tools and AI agents use to generate, test, and validate code."

> "The result is less guesswork, fewer surprises, and higher-quality code."

> "As of early 2026, specification-driven development is rapidly becoming the industry norm. Specifications are increasingly treated as code artifacts, baked into workflows, and automatically enforced by AI assistants."

## Implications for the engine catalog

This is the **closest-to-the-kit-already** pattern in this entire research wave. The MAD workflow IS spec-driven development; the four-phase chain is already implemented; canonical artifact frontmatter is already required (`canonical-artifact-frontmatter.md`); the `validate-mad-pipeline.js` hook already enforces "no inline-authoring of MAD artifacts". 

Gaps vs 2026 SpecKit best practice: (a) the kit's spec format is not formally machine-readable (Markdown with conventions, not JSON-Schema-validated structure), (b) automatic spec-vs-code drift detection is partial (the analyze step exists, but no continuous scanning), (c) spec change → regenerate downstream artifacts is manual (`/mad-plan` after `/mad-spec` is not auto-triggered), (d) the kit's discipline is bespoke whereas SpecKit aims for cross-tool portability (Claude Code + Copilot + Gemini all consume the same spec).

The kit can claim: "MAD = the LENS-flavored, governance-extended spec-driven development implementation." Strategic direction: investigate whether MAD specs CAN be made readable by SpecKit-format consumers (or vice-versa) for portability.

## NEW F-NNN candidates

- F-094 mad-spec-portability-bridge — A converter (`/mad-to-speckit` and reverse) that translates between MAD spec format and SpecKit format, enabling consumers using either to consume the other's specs. Defends against tool lock-in — confidence: M
- F-095 spec-vs-code-drift-detector — Continuous (CI-style) drift detector: when code merges but matching spec wasn't updated, fail the build. Currently kit has `validate-mad-pipeline.js` for skill-active enforcement but no post-merge drift check — confidence: H
- F-096 spec-changes-cascade-regen — When `spec.md` is meaningfully modified, the kit auto-prompts `/mad-plan --regenerate` and downstream `tasks.md` is flagged stale. Currently fully manual — confidence: M
- F-097 machine-readable-spec-schema — Promote the spec format from prose+convention to a JSON-Schema-validated structure (with prose annotations); enables external tools to consume MAD specs without parsing Markdown — confidence: M
- F-098 spec-driven-as-default-narrative — Update kit narrative + onboarding docs to position MAD as "spec-driven development for LENS engineering"; this aligns with industry vocabulary and helps newcomers find the kit when searching for SDD tooling — confidence: H

## Confidence

HIGH — SpecKit adoption numbers (88K stars, 129 releases, 28 platforms) are direct GitHub-verifiable signals; the four-phase shape is documented in GitHub blog + Microsoft Developer blog + multiple independent walkthroughs. Cross-validation against the kit's MAD workflow is strong — they are the same pattern.
