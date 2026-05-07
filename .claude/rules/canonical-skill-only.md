---
title: Rule — MAD artifacts authored only via canonical skill
status: preview
since: 2026-05-03
last_reviewed: 2026-05-03
---

# Rule — MAD artifacts authored only via canonical skill

Each MAD artifact has exactly one canonical author skill. Inline authoring (orchestrator Write, subagent Write, even Edit "for typo fixes") is forbidden. Both Write and Edit on the artifact paths are blocked by `.claude/hooks/validate-mad-pipeline.js` unless the matching skill is currently active.

**Source:** session 249a59a7 (2026-05-02). Iter 1-41 of the collab-engine session, every cascade of spec/plan/tasks edits was inline-authored. The reasoning was always "this is just a small adjustment / typo fix / cascade from the spec change," and the Edit-loophole in the original hook (`toolName !== 'Write'`) accepted that framing. By iter 41 the inline cascades had bypassed: agent-team review, pattern-compliance gate, council verdict, council-review.md persistence, implementability checks, completeness oracle, dependency analysis, and canonical frontmatter signature. The user flagged: "the MAD infra is made to catch your hallcunations and shortcuts" — and was right. Bypassing the skill was bypassing the safety system. The Edit loophole was closed 2026-05-02.

## Artifact-to-skill map

| Artifact | Canonical author skill | Hook coverage |
|---|---|---|
| `specs/<N>-<feature>/spec.md` | `/mad-spec` | `validate-mad-pipeline.js` Write + Edit |
| `specs/<N>-<feature>/test-plan.md` | `/testplan` | same; presence check next to spec.md by `validate-artifact-completeness.js` |
| `specs/<N>-<feature>/plan.md` | `/mad-plan` | same |
| `specs/<N>-<feature>/tasks.md` | `/mad-tasks` | same |
| `specs/<N>-<feature>/analysis-report.md` | `/mad-analyze` | same |

## How to apply

- Need to update spec.md? Invoke `/mad-spec`. Even for "trivial" changes. The skill body owns the artifact.
- Need to update plan.md? Invoke `/mad-plan` (which runs agent-team review + writes `reviews/plan-review.md`).
- Same for tasks.md (`/mad-tasks`), analysis-report.md (`/mad-analyze`), test-plan.md (`/testplan`).
- Multi-artifact orchestration skills (`/mad-implement`, `/mad-validate`, `/mad-full`, `/mad-decompose`, `/mad-parallel`) are exempt — they legitimately write multiple MAD artifacts during their body. The hook recognizes these as `MULTI_ARTIFACT_SKILLS`.
- If a subagent must persist findings that resemble an analysis report, write to `.mad/reports/`, never to `specs/<N>/analysis-report.md`. The `analysis-report.md` filename is reserved for canonical `/mad-analyze` output.
- "It's faster to just edit it inline" is not a valid override. The skill's gates are the speed cost; bypassing them is the failure mode the gates exist to prevent.

## Mechanical detection

Hook `.claude/hooks/validate-mad-pipeline.js` (PreToolUse:Write|Edit) blocks Write/Edit on the 5 artifact paths when no matching `/mad-*` skill is active per `.mad/scratch/mad-pipeline-active.json` (TTL 30 min, populated by `track-mad-skill-invocation.js` on Skill PreToolUse).

Override: `MAD_PIPELINE_HOOK_DISABLED=true` in `.claude/settings.local.json` env. Use only after explicit user discussion.

## Anti-patterns

| Anti-pattern | Why it fails | Correct path |
|---|---|---|
| Orchestrator Write to `specs/N/plan.md` directly | Bypasses agent-team review + council verdict + pattern-compliance gate | Invoke `/mad-plan` skill |
| Subagent Write to spec.md "with frontmatter to look canonical" | Forged canonical signature (no `skill-state-file-id` matching the pipeline state) | Invoke `/mad-spec` via the orchestrator's Skill tool; subagent returns content for orchestrator to relay |
| `Edit` on plan.md "for a one-line typo" | Same loophole that bypassed gates iter 15-41 | Invoke `/mad-plan` (yes, even for typos — the gate cost is the safety) |
| Persist a findings report to `specs/N/analysis-report.md` from a code-investigator | Forged /mad-analyze output | Write to `.mad/reports/<finding-name>.md` instead |

## Related

- `.claude/hooks/validate-mad-pipeline.js` — Write/Edit block on the 5 artifact paths
- `.claude/hooks/track-mad-skill-invocation.js` — pipeline-state file maintenance
- `.claude/rules/canonical-artifact-frontmatter.md` — frontmatter contract that distinguishes canonical from emulated output
- `.claude/rules/mad-workflow.md` — MAD pipeline phase ordering and skill chain
- `CLAUDE.md` § Authoring discipline — operator-facing summary that cites this rule
