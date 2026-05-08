---
name: multi-model-review
description: >
  Multi-model code review using Copilot CLI with LENS-specific context. Runs GPT 5.5
  (max effort) and Claude Opus 4.7 (max effort) in parallel against an ADO pull request
  or local git diff. Injects project-specific CLAUDE.md and .claude/rules as review
  context so findings respect LENS conventions (ParameterContracts, no var, CRLF,
  sealed classes, layered architecture, etc.). Also injects the recurring-pitfalls
  security checklist (S1–S15) covering AllowAnonymous endpoints, authorization
  fail-open, IDOR, secret/PII leakage, IaC misconfig, crypto misuse, cert/TLS
  validation, injection, and supply chain. Produces deduplicated findings with
  confidence scoring, cross-model agreement analysis, and prioritized fix
  recommendations. Use when reviewing a PR, checking code quality before merge,
  auditing changes against LENS standards, or running a pre-commit security/quality gate.
allowed-tools: Read, Glob, Grep, Bash, AskUserQuestion
user-invocable: true
version: 1.1.0
changelog:
  - "1.0.0: Initial release — multi-model review with LENS context injection"
  - "1.1.0: Inject security pitfalls checklist (S1–S15) into every review prompt"
---

# LENS Multi-Model Code Review (COD Review)

Run GPT 5.5 and Claude Opus 4.7 in parallel to review code changes with full LENS project context. Produces deduplicated, prioritized findings that respect project-specific conventions.

## Usage

```
/lens-multi-model-review:multi-model-review 5069800                    # Review ADO PR by number
/lens-multi-model-review:multi-model-review https://o365exchange...     # Review ADO PR by URL
/lens-multi-model-review:multi-model-review --diff                      # Review local branch changes vs master
/lens-multi-model-review:multi-model-review --diff --base develop       # Review against a different base branch
```

## Overview

Standard AI code reviews miss LENS-specific conventions because they lack project context. A generic reviewer doesn't know about `ParameterContracts`, the `no var` rule, CRLF line endings, the layered architecture prohibition on cross-layer access, or MISE v2 auth patterns.

This skill solves that by:
1. **Discovering** the project's CLAUDE.md and all `.claude/rules/*.md` files
2. **Injecting** them as review context into the Copilot CLI prompt
3. **Running** two models in parallel (GPT 5.5 max effort + Opus 4.7 max effort)
4. **Analyzing** findings against LENS conventions to filter false positives
5. **Deduplicating** across models and scoring by cross-model agreement

---

## Execution Flow

### Phase 0: Detect Copilot CLI Command

On first invocation, determine the user's Copilot CLI setup:

1. Check if `copilot` exists: `which copilot 2>/dev/null`
2. Check if `agency` exists: `which agency 2>/dev/null`
3. If both exist, use AskUserQuestion: "Which command do you use? `copilot` or `agency copilot`?"
4. If only one exists, use that
5. If neither exists, abort with: "Copilot CLI not found. Install from https://aka.ms/copilot-cli"

Store the resolved command (e.g., `copilot` or `agency copilot`) for the session.

---

### Phase 1: Parse Input & Gather Changes

**Mode A — ADO Pull Request:**

Parse the PR identifier from arguments:
- Numeric: `5069800` → PR ID directly
- URL: `https://o365exchange.visualstudio.com/O365%20Core/_git/LENS-LRMS/pullrequest/5069800` → extract number from end

Gather changes. The Azure CLI does **not** ship a `pr diff` subcommand (verified against `az repos pr --help`: only `checkout`, `create`, `list`, `policy`, `reviewer`, `set-vote`, `show`, `update`, `work-item`). Use `pr show` for metadata, then compute the patch locally with `git`:

```bash
# 1. PR metadata as JSON (extract sourceRefName, targetRefName, repository)
az repos pr show --id <PR_ID> --output json

# 2. Strip the refs/heads/ prefix from sourceRefName / targetRefName.
#    Then fetch both branches from origin.
git fetch origin <source-branch> <target-branch>

# 3. Produce the diff.
git diff origin/<target-branch>...origin/<source-branch>
```

The local checkout must be on the same repo as the PR — confirm via the `repository.name` field in the `pr show` output before running the `git` commands.

Extract from PR metadata:
- Repository name (e.g., `LENS-LRMS`, `LENS-LEPortal`, `LENS-Common`)
- Source and target branches
- PR title and description
- File list with change stats

**Mode B — Local Git Diff:**

```bash
git branch --show-current                    # Current branch
git diff master...HEAD --stat                # Changed files summary
git diff master...HEAD                       # Full diff
git log master..HEAD --oneline               # Commit history
```

If `--base` is specified, use that instead of `master`.

Detect the repository name from the git remote:
```bash
git remote get-url origin | sed 's/.*\///' | sed 's/\.git$//'
```

---

### Phase 2: Discover Project Context

This is the **critical differentiator** — inject LENS-specific context so the review respects project conventions.

**Step 2a — Find the project root:**

From the detected repository name, locate the project root. If running inside a repo, use the git root:
```bash
git rev-parse --show-toplevel
```

**Step 2b — Read CLAUDE.md:**

Read the project's `CLAUDE.md` at the repo root. This contains:
- Architecture rules (layered architecture, dependency flow)
- Critical coding rules (no var, ParameterContracts, CRLF, sealed classes)
- Naming conventions
- Testing standards
- Security requirements

If the repo also has nested CLAUDE.md files (e.g., `sources/dev/WebApi/src/CLAUDE.md`), read those too for layer-specific context.

**Step 2c — Read .claude/rules/*.md:**

Glob for all rule files:
```bash
find .claude/rules -name "*.md" -type f 2>/dev/null
```

Read EACH rule file. Key rules by repo:

| Repo | Key Rules Files |
|------|----------------|
| **All LENS repos** | `architecture.md`, `code-quality.md`, `naming.md`, `testing.md`, `error-handling.md`, `validation.md`, `templates.md`, `folder-structure.md` |
| **LEPortal/LRMS** | + `api-layer.md`, `webclient-layer.md`, `e2e-testing.md` |
| **LRMS** | + `di-registration.md`, `logging.md`, `enum-source-of-truth.md`, `background-services.md` |
| **LEAPI** | + `infrastructure.md`, `background-services.md` |

**Step 2d — Read FilesForEveryRepository standards (if accessible):**

Discover the `FilesForEveryRepository/CLAUDE.md` org-wide baseline. Try these locations in order and use the first one that exists:

1. `$LENS_BASELINE_PATH/CLAUDE.md` — operator override via env var.
2. `<git-root>/../FilesForEveryRepository/CLAUDE.md` — sibling to the active LENS repo. The canonical LENS engineer checkout layout has `LENS-Common`, `LENS-CMS`, `LENS-DCS`, `LENS-LEAPI`, `LENS-LEPortal`, `LENS-LRMS`, `LENS-Publish`, `LENS-SMS`, `LENS-Teams`, and `FilesForEveryRepository` all as siblings under one parent directory.

```bash
git_root=$(git rev-parse --show-toplevel)
baseline=""
if [ -n "$LENS_BASELINE_PATH" ] && [ -f "$LENS_BASELINE_PATH/CLAUDE.md" ]; then
  baseline="$LENS_BASELINE_PATH/CLAUDE.md"
elif [ -f "$git_root/../FilesForEveryRepository/CLAUDE.md" ]; then
  baseline="$git_root/../FilesForEveryRepository/CLAUDE.md"
fi
```

If neither resolves, emit a single line to stderr (`echo "[lens-multi-model-review] org-wide baseline not found — proceeding without it" >&2`) and continue. The baseline is **optional** — proceeding without it just means the review uses the project's CLAUDE.md and `.claude/rules/` only.

Do not clone-on-demand. The repo is part of the LENS engineer's standard checkout.

When found, the baseline contains the canonical LENS standards that all repos inherit:
- Explicit types (no `var`) — org-wide
- ParameterContracts — org-wide
- CRLF line endings — org-wide
- One class per file — org-wide
- No nested IFs — org-wide
- Copyright headers — org-wide

**Step 2e — Read the security pitfalls checklist (mandatory):**

Read this skill's bundled security checklist:

```
${SKILL_DIR}/references/security-checklist.md
```

Where `${SKILL_DIR}` is the directory containing this `SKILL.md`. Resolve it relative to the skill plugin install path (e.g. `~/.claude/plugins/lens-multi-model-review/skills/multi-model-review/references/security-checklist.md` or, when running from a repo install, the path under `sources/plugins/LENS/Quality/lens-multi-model-review/skills/multi-model-review/references/security-checklist.md`).

This file is **mandatory context for every review** — it encodes the S1–S15 taxonomy of recurring security pitfalls in enterprise web services. Do not skip it. If you cannot locate the file, abort the review and surface a clear error to the user; do not proceed without the checklist.

**Step 2f — Build the context document:**

Concatenate into a single context document (max ~80KB to stay within Copilot CLI limits — security checklist adds ~15KB):

```
=== LENS PROJECT CONTEXT ===
Repository: {repo-name}

=== CLAUDE.md (Project Root) ===
{content of CLAUDE.md}

=== Key Rules ===
{concatenated .claude/rules/*.md content, summarized if too large}

=== CRITICAL LENS CONVENTIONS (Org-Wide) ===
1. EXPLICIT TYPES: Never use 'var' — always use explicit type declarations
2. PARAMETER VALIDATION: Use ParameterContracts.CheckIsNotNull(), not ?? throw or ThrowIfNull
3. LINE ENDINGS: CRLF (Windows) for all files
4. ONE CLASS PER FILE: Every public type gets its own .cs file
5. NO NESTED IFS: Use early returns and guard clauses
6. SEALED CLASSES: Use 'sealed' for implementations not designed for inheritance
7. NO UNDERSCORE PREFIX: Use 'this.' for instance members, not '_field'
8. COPYRIGHT HEADERS: Required on every .cs file
9. ARCHITECTURE: Strict layered — API → BusinessLogic → DataAccess → Common (no skip/reverse)
10. ASYNC: CancellationToken through all async, ConfigureAwait(false) in libraries, never .Result/.Wait()

=== MANDATORY SECURITY CHECKLIST — RECURRING PITFALLS (S1–S15) ===
{full content of references/security-checklist.md, verbatim}
```

If the diff + context exceeds the prompt budget, drop low-priority sections in this order: nested CLAUDE.md files → repo-specific rules other than the matched layer → org-wide critical conventions summary. **Never** drop the security checklist — it is the highest-priority block.

---

### Phase 3: Construct and Execute Reviews

> **Critical Architecture Decision**: Claude Code owns the parallelism — run TWO separate Copilot CLI processes, NOT one process with internal background agents. Copilot's internal agent orchestrator has a limited token budget and will timeout during polling before synthesis. Each separate process gets its full token budget.

**Step 3a — Build the review prompt:**

Create a unique temp directory for this invocation so concurrent runs (parallel reviews on the same machine, or two users on a shared dev VM) cannot clobber each other's artifacts:

```bash
TEMP_DIR=$(mktemp -d -t cod-review-XXXXXX)
```

Use `$TEMP_DIR` for every artifact in this and the following phases. Save the diff and context to `$TEMP_DIR`:

```bash
# Save diff
git diff {base}...{head} > "$TEMP_DIR/cod-review-diff.patch"

# Save context + instructions as a prompt file
cat > "$TEMP_DIR/cod-review-prompt.md" << EOF
You are performing a thorough code review for a LENS (Lawful Electronic Notification Service)
enterprise codebase at Microsoft. This is a {repo-name} repository.

IMPORTANT: Do NOT use background agents. Read the diff yourself and produce the review directly.

CRITICAL: You MUST check all code changes against the LENS project conventions AND the
security pitfalls taxonomy (S1–S15) below. These are NOT suggestions — they are
mandatory standards. Any violation is a finding.

{context document from Phase 2f}

The diff to review is at $TEMP_DIR/cod-review-diff.patch — read it completely.

REVIEW PROCEDURE (do BOTH passes — do not skip the security pass):

Pass 1: Security review against the S1–S15 taxonomy.
- Walk every section S1 through S15. For each section, scan the diff for the listed
  "Flag if you see" patterns. If a pattern matches and the diff does not explicitly
  mitigate it, raise a finding.
- Tag each security finding with [S#] at the front of the title.
- Mark each as ACTIVE (reachable today) or LATENT (dead-code / fail-open path that is
  currently unreachable).
- If no S1–S15 patterns trigger, state explicitly: "Security review: no S1–S15
  patterns triggered." Do NOT invent findings to fill the category.

Pass 2: Code-quality / convention review.
- Walk LENS conventions for var, ParameterContracts, nested IFs, sealed, layering, etc.

For each finding, report:
- Severity: CRITICAL / HIGH / MEDIUM / LOW / NIT (use the security severity table for
  S-class findings; otherwise size by impact)
- File and line number
- Which LENS convention or which S# section is violated
- Whether this is a security issue, bug, style issue, or convention violation
- Confidence level (0-100)
- ACTIVE vs LATENT for security findings

Categorize findings:
1. Security (S1–S15) — the recurring-pitfalls taxonomy. List each with its [S#] tag.
2. LENS Convention Violations (var usage, ParameterContracts, naming, architecture, etc.)
3. Logic/Correctness Issues (bugs, edge cases, race conditions)
4. Performance Issues (N+1, blocking async, unnecessary allocations)
5. Test Coverage Gaps (missing tests, untested edge cases)
6. Documentation Issues (missing XML docs, stale comments)

Provide:
- All findings sorted by severity, with security findings grouped first
- Overall risk assessment (LOW/MEDIUM/HIGH) — any CRITICAL S-finding forces HIGH
- Merge recommendation (Approve / Approve with nits / Request Changes / Block);
  any unmitigated CRITICAL S-finding forces "Block"
EOF
```

**Step 3b — Run TWO separate Copilot CLI processes in parallel:**

```bash
# Opus review (typically ~2-3 minutes)
{copilot_command} --yolo -p "$(cat "$TEMP_DIR/cod-review-prompt.md")" \
  > "$TEMP_DIR/cod-opus-result.txt" 2>&1 &

# GPT 5.5 review (typically ~5-6 minutes)
{copilot_command} --yolo --model gpt-5.5 -p "$(cat "$TEMP_DIR/cod-review-prompt.md")" \
  > "$TEMP_DIR/cod-gpt-result.txt" 2>&1 &

# Wait for both to complete
wait
```

Use TWO `run_in_background` Bash calls — one for each model. Total wall clock time is ~5-6 minutes (limited by the slower model).

> **Why not one process with internal agents?** Copilot's orchestrator exhausts its token budget during agent polling before synthesis. Two separate processes each get their full budget. Claude Code (the calling agent) handles synthesis — which it does better anyway because it has the full conversation context.

> **If `--model` flag is not supported**, run both with the default model and instruct the prompt differently: "You are running as the Opus reviewer" vs "You are running as the GPT reviewer". The Copilot CLI will use its default model routing.

**Step 3c — Read both result files** when both background processes complete.

---

### Phase 4: Synthesize and Present Results

Claude Code performs the synthesis — NOT the Copilot CLI.

**Step 4a — Read both review outputs:**
```bash
cat "$TEMP_DIR/cod-opus-result.txt"   # Opus findings
cat "$TEMP_DIR/cod-gpt-result.txt"    # GPT findings
```

**Step 4b — Deduplicate findings across models.** Match findings by file:line and issue description. Track which model(s) found each issue.

**Step 4c — Present the raw findings** from both models to the user.

**Step 4d — Analyze each finding** in a structured table:

| # | Finding | Models | LENS Convention? | Assessment | Action |
|---|---------|--------|-----------------|------------|--------|
| 1 | `var` usage in handler | Both | Yes — org-wide explicit types | Agree | Fix |
| 2 | Missing ParameterContracts | Opus | Yes — validation standard | Agree | Fix |
| 3 | Nested IF in controller | GPT | Yes — no nested IFs rule | Agree | Fix |
| 4 | Could use LINQ instead | Opus | No — style preference | Disagree — current is clearer | Skip |

Assessment categories:
- **Agree**: Valid finding, should be fixed in this PR
- **Disagree**: Finding is incorrect or misunderstands the code
- **False Positive**: Reviewer misread the code or context
- **Pre-existing**: Valid issue but not introduced by this PR
- **By Design**: Current behavior is intentional
- **LENS Convention**: Explicitly violates a documented LENS rule

**Step 4e — Prioritized fix recommendations:**

| Priority | Fixes | Effort |
|----------|-------|--------|
| Block — Security CRITICAL | S1 (AllowAnonymous on state-changing route), S2 (auth fail-open in PRD), S3 (IDOR returning credential), S7 (secret in logs/outputs), S14 (RCE/path-traversal) | Varies |
| Must fix — Security HIGH | S4–S6, S8–S13, S15 findings | Varies |
| Must fix — LENS violations | var usage, missing ParameterContracts, nested IFs | Quick |
| Must fix — Logic bugs | Correctness errors, race conditions, edge cases | Varies |
| Should fix | Missing XML docs, naming inconsistencies | Moderate |
| Can defer | Style preferences, minor optimizations | Low priority |

**Step 4f — Ask**: "Which of these would you like me to fix?"

---

### Phase 5: Apply Fixes (if requested)

If the user asks to fix findings:
1. Apply each fix in the order of priority
2. For LENS convention violations, apply the correct pattern from `.claude/rules/templates.md`
3. Run `dotnet build` after fixes to verify no compile errors
4. Run `dotnet test` to verify no test regressions
5. Stage and present the changes for review

---

## Output Artifacts

| Artifact | Location | Purpose |
|----------|----------|---------|
| Raw multi-model review | stdout | Full findings from GPT 5.5 + Opus 4.7 |
| Finding analysis table | stdout | Per-finding assessment with LENS convention mapping |
| Priority matrix | stdout | Fixes grouped by effort and priority |
| Applied fixes | git working tree (if requested) | Code changes addressing findings |

---

## Integration Points

**Spawns**: Copilot CLI process (background)

**Reads**:
- `CLAUDE.md` — project root and nested
- `.claude/rules/*.md` — all project convention files
- `FilesForEveryRepository/CLAUDE.md` — org-wide baseline (if accessible)
- `${SKILL_DIR}/references/security-checklist.md` — bundled S1–S15 security pitfalls checklist (mandatory)
- `${SKILL_DIR}/references/lens-conventions-cheatsheet.md` — bundled convention reference (optional)
- Git diff / ADO PR diff — the changes to review
- PR metadata (title, description) via `az repos pr show`

**Writes**: None (read-only analysis, unless user requests fixes)

---

## Success Criteria

- [ ] Both models (GPT 5.5 + Opus 4.7) produce independent findings
- [ ] Security pass runs explicitly against S1–S15. If none trigger, the absence is stated.
- [ ] Security findings are tagged `[S#]` and labeled ACTIVE vs LATENT
- [ ] Any unmitigated CRITICAL S-finding forces a "Block" merge recommendation
- [ ] LENS convention violations are detected (var usage, ParameterContracts, naming, architecture)
- [ ] False positives are reduced by context injection (e.g., don't flag `var` in test projects if tests allow it)
- [ ] Cross-model agreement is highlighted (findings both models flag are higher confidence)
- [ ] Findings include file:line references
- [ ] Priority matrix separates security (S1–S15) from LENS conventions from style preferences
- [ ] Fix recommendations reference the specific `.claude/rules/` file or S# section

---

## Safety Rules

- **Read-only by default** — never modify code unless the user explicitly requests fixes
- **Never push code** — fixes are staged locally, never committed or pushed automatically
- **Respect .gitignore** — never read or include ignored files in the review context
- **No secrets in prompts** — strip any `appsettings.*.json` content, connection strings, or tokens from the diff before sending to Copilot CLI
- **Prompt size limit** — keep the total prompt under 100KB to avoid Copilot CLI failures. If the diff + context exceeds this, summarize the context and send the diff in chunks.
- **Copilot CLI auth** — if the CLI command fails, provide the user a fallback: export the diff and context to files for manual review

<!-- TODO: source — LENS-Common PR 5138039 (Shayon Gupta), copied 2026-05-08 from references/LENS-Common-fix/sources/plugins/LENS/Quality/lens-multi-model-review/skills/multi-model-review/SKILL.md. Refresh after PR merges. -->
