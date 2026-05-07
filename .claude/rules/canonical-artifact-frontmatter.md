---
title: Rule — Canonical artifact frontmatter signature
status: preview
since: 2026-05-03
last_reviewed: 2026-05-03
---

# Rule — Canonical artifact frontmatter signature

Every artifact written by a canonical MAD skill MUST carry three frontmatter keys, set by the skill body itself (not by the orchestrator after the fact). The signature is what mechanically distinguishes canonical skill output from a subagent emulation that bypasses the skill's gates.

**Source:** session 249a59a7 (2026-05-02). Iter 1-41 of the collab-engine session, code-investigator and code-implementer subagents emulated `/mad-analyze`, `/mad-spec`, `/mad-plan`, `/mad-tasks` skill bodies inline because their system prompts blocked Write/Edit of files outside scope, and the orchestrator persisted their final-message output to disk. The persisted artifacts looked structurally similar to canonical skill output but bypassed every gate the skill body enforces (agent-team review, council verdict, completeness oracle, etc.). There was no mechanical way to tell a canonical `/mad-analyze` output from a subagent emulation — both were valid Markdown with the right section headers. The signature contract makes the distinction visible.

## Required frontmatter keys

Every spec.md / plan.md / tasks.md / analysis-report.md / test-plan.md MUST start with:

```yaml
---
generated-by: /<skill-name>          # e.g. /mad-plan
generated-by-version: <semver>       # e.g. 2.1.0
skill-state-file-id: <session-id>    # value of .mad/scratch/mad-pipeline-active.json:session_id at write time
---
```

Optional metadata fields (use when applicable):

```yaml
canonical-rerun: true                # for A/B/C comparison reruns
source-snapshot: <path>              # for canonical-rerun input
source-fr-count: <n>                 # for spec.md / test-plan.md
phase: <phase-id>                    # for tracking which Phase produced this
plan-ref: <plan-file-path>           # link to the governing plan
experiment-arm: <A|B|C|...>          # for A/B/C experiment artifacts
```

## How to apply

- When updating a `/mad-*` skill body, ensure the artifact-write step injects the three frontmatter keys before any other content.
- `generated-by-version` follows the skill's semver; bump it any time the skill body changes meaningfully (new gate, new section template, breaking output shape).
- `skill-state-file-id` is read from `.mad/scratch/mad-pipeline-active.json:session_id` (written by `track-mad-skill-invocation.js` at skill invocation). Audits cross-reference this against the historical pipeline state to verify the artifact was produced during a real skill run.
- Subagent-persisted reports (e.g., investigation findings, retros, audits) belong under `.mad/reports/`, NOT under `specs/<N>/`. Reports under `.mad/reports/` are NOT MAD-pipeline artifacts and are exempt from the signature contract.
- If you must persist a partial canonical artifact (e.g., resumption from compaction), set frontmatter and append `partial: true` so consumers know to re-run the skill body before relying on the artifact for downstream gates.

## Mechanical detection

Hook `.claude/hooks/enforce-skill-canonical-marker.js` (PostToolUse:Write|Edit) flags artifacts under `specs/<N>/` that are missing or malformed. Findings append to `.mad/scratch/canonical-marker-flags.json`. Hook `validate-artifact-completeness.js` (SubagentStop) blocks completion on unacknowledged flags.

Script `.claude/scripts/Verify-CanonicalSkillFrontmatter.ps1` validates a path or directory against the contract. Used by gate scripts and as an on-demand audit tool.

## Anti-patterns

| Anti-pattern | Why it fails | Correct path |
|---|---|---|
| Skill body forgets to write frontmatter | Artifact looks canonical but isn't traceable to a real skill run | Skill body's first Write call MUST emit the 3 keys |
| Subagent forges `generated-by: /mad-plan` without matching `skill-state-file-id` | Audit can detect: pipeline-state-file history won't show the session_id | If subagent emulates a skill, route through orchestrator Skill-tool invocation so the state file is set first |
| Orchestrator post-edits frontmatter onto a subagent-emulated artifact | Same forgery pattern, just by the orchestrator | Don't emulate; invoke the skill |
| `generated-by-version` static at `1.0.0` for years | Audits can't tell which skill version produced which artifact | Bump on meaningful changes |

## Related

- `.claude/hooks/enforce-skill-canonical-marker.js` — PostToolUse signature check
- `.claude/hooks/validate-artifact-completeness.js` — SubagentStop completion gate
- `.claude/scripts/Verify-CanonicalSkillFrontmatter.ps1` — on-demand validator
- `.claude/rules/canonical-skill-only.md` — companion rule blocking inline-authoring
- All 5 MAD SKILL.md files — embed the frontmatter contract in their § Produced artifact frontmatter contract sections
