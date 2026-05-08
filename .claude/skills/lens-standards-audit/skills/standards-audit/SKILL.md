---
name: standards-audit
description: Audit LENS-* repos for compliance with engineering standards extracted from LENS-Docs, rating each repo with confidence scores using a 3-tier obligation model. Use when asked to audit standards compliance, check engineering practices, or generate a compliance report across LENS repos.
allowed-tools: Read, Write, Bash, Grep, Glob, Agent
---

# LENS Standards Audit

Pull all LENS-* repos, extract engineering standards from LENS-Docs, and rate each repo's compliance with confidence scores.

## Usage

```
/lens-standards-audit:standards-audit                              # Full audit of all LENS-* repos
/lens-standards-audit:standards-audit --repos LENS-CMS,LENS-LRMS  # Audit specific repos only
/lens-standards-audit:standards-audit --standards-only             # Just extract and display standards (no repo audit)
/lens-standards-audit:standards-audit --update-repos               # Force update reference repos before audit
/lens-standards-audit:standards-audit --category security          # Audit only a specific standards category
```

## Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `--repos` | all LENS-* | Comma-separated list of repos to audit |
| `--standards-only` | false | Extract and display standards without auditing repos |
| `--update-repos` | false | Pull latest from all discovered repos before audit |
| `--category` | all | Filter to specific standards category (security, testing, architecture, observability, api, infrastructure) |

## CRITICAL: Severity Classification Rules

**ALL LENS-Docs documents are marked "preview state" and subject to change.** The skill MUST surface this disclaimer in every report.

LENS-Docs uses **informal language**, NOT RFC 2119 keywords. Classify obligations using this 3-tier model based on the **exact language** in the source document:

### Tier 1: REQUIREMENT (weight 3x)

Triggered ONLY by these exact phrases in the source text:
- "must" (lowercase or uppercase)
- "must not", "must never"
- "mandated", "required"
- "blocks check-in", "cannot", "do not" (as prohibition)

### Tier 2: STANDARD (weight 2x)

Triggered ONLY by these exact phrases declaring something as "the standard":
- "is the LENS standard"
- "is the standard tool"
- "Use [tool]" (imperative with specific tool name)
- "We use [X] for [Y]"

### Tier 3: RECOMMENDATION (weight 1x)

Triggered by these phrases:
- "should", "should not"
- "recommended", "recommends"
- "preferred", "target"
- "evaluating", "plan to"
- "advise"

### What agents MUST NOT do

- **DO NOT** treat "should" as "must" -- these are different obligation levels
- **DO NOT** infer requirements that are not literally stated in the text
- **DO NOT** score a repo as NON-COMPLIANT for missing a RECOMMENDATION
- **DO NOT** add requirements from repo-local CLAUDE.md files -- only LENS-Docs counts
- **DO NOT** fabricate standard IDs or requirement numbers not traceable to source text
- **DO NOT** count "evaluating" or "plan to" as decided standards

## Behavior

### Phase 0: Prerequisites

1. Discover LENS repos using this priority:
   - `--repos` parameter (explicit list of repo names)
   - `${LENS_REPOS_ROOT}` environment variable, scanning for `LENS-*` directories
   - `$HOME/Repos/` default path, scanning for `LENS-*` directories
   - `references/` directory in the current working directory

2. If `--update-repos` specified, pull latest from all discovered repos:
   ```bash
   for repo in ${LENS_REPOS_ROOT:-$HOME/Repos}/LENS-*; do
     [ -d "$repo/.git" ] && git -C "$repo" pull --ff-only 2>/dev/null
   done
   ```

3. Verify LENS-Docs is available (check for `sources/docs/enghub/core/` directory)
4. If repos cannot be found, ABORT with instructions

### Phase 1: Extract Standards from LENS-Docs

Investigate the LENS-Docs repo to extract all engineering standards.

**Standards source path**: `{LENS-Docs}/sources/docs/enghub/core/`

For each normative statement found:
1. **Quote the EXACT text** from the document (no paraphrasing)
2. **Record file path and line number** for traceability
3. **Classify using the 3-tier model** above based on the exact language used
4. **Note the preview state** of the source document

Write extracted standards to `{cwd}/lens-standards-audit/standards-catalog.md`

**Standards catalog format**:

```markdown
# LENS Engineering Standards Catalog

Extracted from: LENS-Docs/sources/docs/enghub/core/
Date: {ISO timestamp}

> **DISCLAIMER**: All LENS-Docs documents are marked "preview state" and subject to change.
> Standards below reflect the current text as of extraction date.

## Summary

| Tier | Count | Description |
|------|-------|-------------|
| REQUIREMENT | {N} | Hard obligations ("must", "blocks", "do not") |
| STANDARD | {N} | Declared tools/patterns ("is the standard", "Use X") |
| RECOMMENDATION | {N} | Guidance ("should", "target", "recommended") |

## {Category}

### {STD-ID}: {Standard Title}
- **Source**: {relative file path}:{line number}
- **Tier**: REQUIREMENT | STANDARD | RECOMMENDATION
- **Exact quote**: "{verbatim text from document}"
- **Preview state**: Yes
```

If `--standards-only` is specified, STOP here and display the catalog.

### Phase 2: Audit Each Repo

For each discovered LENS-* repo (or filtered by `--repos`), investigate it for compliance.

**Per-standard scoring**:

| Score | Meaning | When to use |
|-------|---------|-------------|
| **COMPLIANT** (100%) | Fully meets the standard | File path + line reference as evidence |
| **PARTIAL** (50%) | Partially meets or has gaps | What's present + what's missing |
| **NON-COMPLIANT** (0%) | Does not meet the standard | Only for REQUIREMENT and STANDARD tier items |
| **NOT-ADOPTED** (0%) | Recommendation not followed | For RECOMMENDATION tier only -- NOT a failure |
| **NOT-APPLICABLE** (N/A) | Standard doesn't apply to this repo type | Justification required |

**IMPORTANT**: A repo that doesn't follow a RECOMMENDATION is scored as NOT-ADOPTED, not NON-COMPLIANT. Only REQUIREMENT and STANDARD tier items can be NON-COMPLIANT.

**Per-standard confidence**:

| Confidence | Meaning |
|------------|---------|
| **HIGH** (90-100%) | Clear evidence found (file exists, pattern matches) |
| **MEDIUM** (60-89%) | Indirect evidence or partial match |
| **LOW** (0-59%) | Uncertain -- manual review recommended |

Write per-repo findings to `{cwd}/lens-standards-audit/repo-{RepoName}.md`

### Phase 3: Synthesize Scores

Read all per-repo findings and compute:

1. **Per-repo compliance score**: weighted average using tier weights (REQUIREMENT=3x, STANDARD=2x, RECOMMENDATION=1x)
2. **Per-repo requirement-only score**: score against only REQUIREMENT tier items (the hard gates)
3. **Per-category score**: average across all repos for each standards category
4. **Cross-repo heatmap**: which standards are universally met vs missed
5. **Top gaps**: top 10 most-missed items, clearly labeled by tier

### Phase 4: Generate Report

Write final report to `{cwd}/lens-standards-audit/audit-report.md`:

```markdown
# LENS Standards Compliance Audit Report

**Date**: {ISO timestamp}
**Repos Audited**: {count}
**Standards Source**: LENS-Docs (all documents in preview state)
**Requirements (must)**: {count} | **Standards (declared tools)**: {count} | **Recommendations (should)**: {count}

> **DISCLAIMER**: All LENS-Docs documents are marked "preview state -- subject to change."
> Scores below distinguish hard requirements from recommendations.
> A low recommendation-adoption score is informational, not a compliance failure.

## Executive Summary

| Repo | Requirements | Standards | Recommendations | Weighted Overall | Confidence |
|------|-------------|-----------|-----------------|-----------------|------------|

## Requirement Compliance (Hard Gates Only)

| Repo | Score | Gaps |

## Standard Adoption (Declared Tools/Patterns)

| Repo | Score | Gaps |

## Recommendation Adoption (Guidance)

| Repo | Adoption Rate | Notable |

## Cross-Repo Heatmap

| Standard | Tier | Repo1 | Repo2 | ... |

## Top 10 Gaps

1. **{ID}**: {description} -- Tier: {tier} -- missed by {N}/{total}
   - Exact quote: "{source text}"
   - Source: {file}:{line}
```

## Output

| Artifact | Path |
|----------|------|
| Standards catalog | `{cwd}/lens-standards-audit/standards-catalog.md` |
| Per-repo findings | `{cwd}/lens-standards-audit/repo-{name}.md` |
| Final report | `{cwd}/lens-standards-audit/audit-report.md` |

## Error Handling

| Error | Resolution |
|-------|------------|
| No LENS repos found | Set `LENS_REPOS_ROOT` env var or clone repos to `$HOME/Repos/` |
| LENS-Docs not found | Clone: `git clone https://o365exchange.visualstudio.com/O365%20Core/_git/LENS-Docs` |
| No standards found in docs path | Check path `sources/docs/enghub/core/` -- may have moved |
| Agent timeout on large repo | Reduce scope with `--repos` or `--category` |
| ADO auth failure on clone | Run `az login` first; ensure ADO PAT is configured |

## Notes

- **ALL LENS-Docs are preview state** -- scores should be interpreted as adoption readiness, not compliance failures
- Standards are extracted fresh each run (not cached) to pick up LENS-Docs updates
- The audit is read-only: no code changes, no PRs, no commits to audited repos
- For large audits (all repos x all standards), expect 5-10 minutes
- Confidence scores are heuristic -- LOW confidence items should be manually verified
- N/A scores are excluded from percentage calculations
- Only standards from `LENS-Docs/sources/docs/enghub/core/` count -- repo-local CLAUDE.md rules are NOT LENS standards

<!-- TODO: source — LENS-Common PR 5158460, branch u/jacote/lens-aspnet-structure-skill, copied 2026-05-08 from references/LENS-Common/sources/plugins/LENS/Quality/lens-standards-audit/skills/standards-audit/SKILL.md. Refresh after PR merges. -->
