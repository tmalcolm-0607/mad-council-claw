# Non-Negotiable Rules

Verb-bound permission fences. These apply in ALL sessions regardless of context compaction.

| YOU MUST NOT | You may | Enforced by |
|---|---|---|
| YOU MUST NOT create or submit a pull request without explicit user request. | Ask the user if they want a PR created. | (no hook — user trust) |
| YOU MUST NOT run `git push` without explicit user request in the current session. | Stage and commit; ask before pushing. | `hooks/pre-bash-validate.js` |
| YOU MUST NOT dismiss test failures as "pre-existing" and proceed without action. | Fix, track via `/mad-spec`, or add skip logic — then report. | `hooks/validate-quality-gates.js` |
| YOU MUST NOT dismiss ANY build/test error as "not my fault" or "pre-existing" and move on. | Triage every error. If it's a known-local-only failure, document it. If it's real, fix it. Who created it is irrelevant — all errors are your responsibility. | (no hook — discipline) |
| YOU MUST NOT use `run_in_background: true` for Task tool agent spawns. | Use synchronous parallel Task calls (single message, multiple tool blocks). | (no hook — confirmed bugs: hangs, empty outputs) |
| YOU MUST NOT skip quality gates or bypass pre-commit hooks without explicit user approval. | Run gates, fix failures, then proceed. | `hooks/pre-bash-validate.js` |
| YOU MUST NOT push iterative/fix commits directly to a PR branch. | Do all fix work in a `-fix` worktree; cherry-pick only the final confirmed-clean commit. | (no hook — discipline) |
| YOU MUST NOT rely on subagent responses >30K tokens without chunking. | Instruct subagents to split responses into ≤30K token segments (silent truncation at 32K). | (no hook — silent truncation) |
| YOU MUST NOT destroy data without confirmation: `git push --force`, `git reset --hard`, `git checkout .`, `git restore .`, `git clean -f`, `git branch -D`. | Ask the user before any destructive operation; prefer non-destructive alternatives. | `hooks/pre-bash-validate.js` |
| YOU MUST NOT amend published commits or use interactive git (`-i`, `--no-edit`). | Create NEW commits; if a pre-commit hook fails, fix and re-stage — don't `--amend`. | `hooks/pre-commit-validate.js` |
| YOU MUST NOT read code files from the main orchestrator. | Spawn `code-investigator` or `Explore` subagent. | `hooks/enforce-orchestration.js` |
| YOU MUST NOT edit files outside the current task's scope without asking. | Ask before modifying unrelated files. | `hooks/scope-guard.js` |
| YOU MUST NOT guess when uncertain. | Insert `[NEEDS CLARIFICATION: <question>]` marker and pause. | (no hook — discipline) |
| YOU MUST NOT upload content to third-party web tools (diagram renderers, pastebins, gists) without considering sensitivity. | Confirm with user; assume uploaded content is public. | (no hook — discipline) |
| YOU MUST NOT author MAD artifacts (`spec.md`, `plan.md`, `tasks.md`, `analysis-report.md`, `test-plan.md`) directly via Write. | Always invoke the corresponding `/mad-*` skill (`/mad-spec`, `/mad-plan`, `/mad-tasks`, `/mad-analyze`, `/testplan`) via the Skill tool. The skill body writes the artifact. Inline authorship skips the gates the skill enforces (implementability checks, agent-team review, completeness oracle, dependency analysis). Edit (not Write) is allowed for incremental updates / typo fixes. | `hooks/validate-mad-pipeline.js` + `hooks/track-mad-skill-invocation.js` |
| YOU MUST NOT rename git branches (`git branch -m`) or move tracked directories (`mv specs/<N>-<feature>`) without explicit user authorization. | Ask the user before any rename/move. Names don't constrain content; rewrite content in place. | `hooks/pre-bash-validate.js` (extension pending) |
