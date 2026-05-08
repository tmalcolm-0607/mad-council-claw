---
name: docs-review
description: Quickly review LENS-Docs documentation against source code and produce a compliance report covering endpoint coverage, enum accuracy, field accuracy, and structural compliance. Use when asked to audit, check, or validate docs accuracy for a LENS service.
allowed-tools: Read, Bash, Grep, Glob, Agent
---

<!-- TODO: source — LENS-Common plugins/LENS/Documentation/lens-docs (PR 5158460 branch u/jacote/lens-aspnet-structure-skill); copied 2026-05-08; refresh after PR merges. -->

# LENS-Docs Quick Review

Review existing LENS-Docs documentation against source code and output a compliance report to the conversation. This skill is read-only and does not modify any files.

## Usage

```
/lens-docs:docs-review {service}             # Review specific service docs
/lens-docs:docs-review --all                 # Review all services
/lens-docs:docs-review cms --source-repo /path/to/LENS-CMS
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `service` | No | all | Target service name (e.g., `cms`, `leapi`, `delivery`, `exchange`, `lrms`) |
| `--all` | No | false | Review all services with docs in LENS-Docs |
| `--source-repo` | No | auto-detect | Path to the source code repo to validate against |
| `--docs-repo` | No | auto-detect | Path to the LENS-Docs repo |
| `--skip-enums` | No | false | Skip enum value validation |

## Behavior

### Repository Discovery

Repos are discovered in this order:

1. Explicit `--source-repo` / `--docs-repo` parameters
2. `${LENS_REPOS_ROOT}` environment variable
3. `$HOME/Repos/` default path

### Execution Flow

1. **Locate docs**: Find `sources/docs/enghub/{service}/` in LENS-Docs repo
   - If `--all`: enumerate all subdirectories under `sources/docs/enghub/`
   - If not found: ERROR "No docs for {service}."

2. **Locate source**: Find the corresponding source repo
   - Try `${LENS_REPOS_ROOT:-$HOME/Repos}/LENS-{SERVICE}` (uppercased)
   - If `--source-repo` provided, use that path directly
   - If not found: WARN "Source repo not found. Skipping code validation."

3. **Analyze source code**: Investigate the source repo to extract:
   - All API controllers with routes, methods, auth policies
   - All enum values from enum directories
   - All DTO fields from DTO directories
   - All allowed PATCH paths from repository code

4. **Run all checks**:

   **Check A: Endpoint Coverage**
   - Every controller action in source has a corresponding section in the doc
   - Route paths match exactly
   - Auth policy names match

   **Check B: Enum Accuracy** (skip if `--skip-enums`)
   - Every enum value in the doc exists in the source
   - No phantom values (in doc but not in source)
   - No missing values (in source but not in doc)

   **Check C: Field Accuracy**
   - Required/optional fields match DTO definitions
   - JSON property names match `[JsonPropertyName]` attributes
   - Request/response examples use valid field names

   **Check D: Structural Compliance**
   - DocFX structure matches enghub pattern (index.md, toc.yml, docfx.json)
   - All internal links resolve
   - TOC entries match actual files

5. **Output review report**: Display the full report in the conversation with issue counts and severity.

### Report Format

```markdown
# LENS-Docs Review: {service}

**Date**: {ISO timestamp}
**Source repo**: {path}
**Docs path**: {path}

## Summary

| Check | Result | Issues |
|-------|--------|--------|
| Endpoint Coverage | X/Y (Z%) | [count] |
| Enum Accuracy | X/Y (Z%) | [count] |
| Field Accuracy | X/Y (Z%) | [count] |
| Structure | PASS/FAIL | [count] |

## CRITICAL Issues (doc says wrong thing)
...

## MAJOR Issues (doc missing important info)
...

## MINOR Issues (style, formatting)
...
```

## Source Code Analysis Patterns

### .NET API (CMS, LEAPI)

| What | Where |
|------|-------|
| Controllers | `sources/dev/{project}/src/API/Controllers/` |
| Enums | `sources/dev/{project}/src/Common/Enums/` |
| Request DTOs | `sources/dev/{project}/src/Common/DTOs/Requests/` |
| Response DTOs | `sources/dev/{project}/src/Common/DTOs/Responses/` |
| Domain models | `sources/dev/{project}/src/Common/Models/` |
| Auth policies | `sources/dev/{project}/src/Common/Constants/AuthorizationPolicies.cs` |

### React/TypeScript (LRMS)

| What | Where |
|------|-------|
| API client | `src/services/api/` or `src/api/` |
| Routes | `src/routes/` or `src/App.tsx` |
| Types | `src/types/` or `src/**/*.types.ts` |

## Examples

```
/lens-docs:docs-review cms

=== LENS-Docs Review: CMS ===
Endpoint Coverage: 35/35 (100%)
Enum Accuracy: 12/12 enums correct
Field Accuracy: 3 issues found
Structure: PASS

Issues:
- MAJOR: CreateCaseRequest missing `workflowStage` field in example
- MINOR: NoteType example uses "Internal" (should be "General")
- MINOR: Missing `Scenario` enum in DFT section
```

## Notes

- This skill is read-only -- it does not modify any files
- Use `/lens-docs:lens-docs update {service}` to fix issues found by this review
- All enum values are compared against actual source code, never guessed


<!-- TODO: source — LENS-Common plugins/LENS/Documentation/lens-docs/skills/docs-review (PR 5158460 branch u/jacote/lens-aspnet-structure-skill); copied 2026-05-08; refresh after PR merges. Tier 2 PR-time gate; read-only. -->
