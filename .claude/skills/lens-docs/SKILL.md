---
name: lens-docs
description: Review, create, update, or sync LENS-Docs documentation for any LENS service against its source code. Use when asked to write, fix, update, or generate API docs for a LENS service, or when docs are out of date with the code.
allowed-tools: Read, Write, Edit, Bash, Grep, Glob, Agent
---

<!-- TODO: source — LENS-Common plugins/LENS/Documentation/lens-docs (PR 5158460 branch u/jacote/lens-aspnet-structure-skill); copied 2026-05-08; refresh after PR merges. -->

# LENS-Docs Manager

Review, create, or update documentation in the LENS-Docs repo following the established enghub structure. Validates documentation against actual source code and generates missing content.

## Usage

```
/lens-docs:lens-docs review {service}         # Review existing docs for accuracy against source code
/lens-docs:lens-docs create {service}         # Create new doc hub for a LENS service
/lens-docs:lens-docs update {service}         # Update existing docs from source code changes
/lens-docs:lens-docs sync {service}           # Full sync: review + fix + update from source
```

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| `action` | Yes | - | `review`, `create`, `update`, or `sync` |
| `service` | No | all | Target service name (e.g., `cms`, `leapi`, `delivery`, `exchange`, `lrms`) |
| `--source-repo` | No | auto-detect | Path to the source code repo to validate against |
| `--docs-repo` | No | auto-detect | Path to the LENS-Docs repo |
| `--skip-enums` | No | false | Skip enum value validation |
| `--dry-run` | No | false | Show what would change without writing files |

## Behavior

### Repository Discovery

Repos are discovered in this order:

1. Explicit `--source-repo` / `--docs-repo` parameters
2. `${LENS_REPOS_ROOT}` environment variable
3. `$HOME/Repos/` default path

| Repo | Discovery | Purpose |
|------|-----------|---------|
| LENS-Docs | `${LENS_REPOS_ROOT:-$HOME/Repos}/LENS-Docs` | Documentation target |
| Source repo | `${LENS_REPOS_ROOT:-$HOME/Repos}/LENS-{SERVICE}` | Source code to validate against |

### DocFX Structure (enghub pattern)

Every service follows this structure under `sources/docs/enghub/`:

```
{service}/
  index.md                    # Landing page with quick links
  docfx.json                  # DocFX build config
  images/                     # Screenshots, diagrams
  content/
    toc.yml                   # Table of contents
    api-guide.md              # Full API reference with curl examples
    onboarding.md             # Consumer onboarding guide
    architecture.md           # Infrastructure + data model
```

Existing services to match: `leapi`, `delivery`, `exchange`, `core`.

---

## Execution Flow

### Action: `review`

Validates existing documentation against source code.

1. **Locate docs**: Find `sources/docs/enghub/{service}/` in LENS-Docs repo
   - If not found: ERROR "No docs for {service}. Use `/lens-docs:lens-docs create {service}` first."

2. **Locate source**: Find the corresponding source repo
   - Try `${LENS_REPOS_ROOT:-$HOME/Repos}/LENS-{SERVICE}` (uppercased)
   - If `--source-repo` provided, use that path directly
   - If not found: WARN "Source repo not found. Skipping code validation."

3. **Analyze source code**: Investigate the source repo to extract:
   - All API controllers with routes, methods, auth policies
   - All enum values from enum directories
   - All DTO fields from DTO directories
   - All allowed PATCH paths from repository code

4. **Compare against docs**: Review the api-guide.md and other doc files:

   **Check A: Endpoint Coverage**
   - Every controller action in source has a corresponding section in the doc
   - Route paths match exactly
   - Auth policy names match

   **Check B: Enum Accuracy**
   - Every enum value in the doc exists in the source
   - No values in the doc that don't exist in source (phantom values)
   - No values in source missing from the doc (coverage gaps)

   **Check C: Field Accuracy**
   - Required/optional fields match DTO definitions
   - JSON property names match `[JsonPropertyName]` attributes
   - Request/response examples use valid field names

   **Check D: Structural Compliance**
   - DocFX structure matches enghub pattern (index.md, toc.yml, docfx.json)
   - All internal links resolve
   - TOC entries match actual files

5. **Generate review report**: Write to `{docs-repo}/reviews/lens-docs-review-{service}.md`

   ```markdown
   # LENS-Docs Review: {service}

   | Check | Result | Issues |
   |-------|--------|--------|
   | Endpoint Coverage | X/Y | [list] |
   | Enum Accuracy | X/Y | [list] |
   | Field Accuracy | X/Y | [list] |
   | Structure | PASS/FAIL | [list] |

   ## Issues Found
   ### CRITICAL (doc says wrong thing)
   ### MAJOR (doc missing important info)
   ### MINOR (style, formatting)
   ```

6. **Report**: Print summary and path to full report.

---

### Action: `create`

Creates a new documentation hub for a LENS service.

1. **Verify service doesn't already exist**: Check `sources/docs/enghub/{service}/`
   - If exists: ERROR "Docs already exist. Use `/lens-docs:lens-docs update {service}` instead."

2. **Create branch**: `git checkout -b users/{user}/{service}-api-docs origin/master` in the LENS-Docs repo

3. **Create directory structure**: Following enghub pattern

4. **Analyze source code**: Investigate source repo to extract:
   - Service description and purpose
   - All API endpoints with full details
   - All enums, DTOs, entity models
   - Infrastructure components (Cosmos containers, storage, etc.)

5. **Generate docs**:

   **index.md**: Landing page with:
   - Service description (what and why)
   - Quick links to main sections
   - Environment URLs table
   - Contact info

   **content/api-guide.md**: Full API guide following this structure:
   ```
   Part 1: Understanding {Service}
   - What is it and why does it exist?
   - Domain model (entity relationship diagram)
   - Key design decisions

   Part 2: Getting Started
   - Environments & access
   - Token acquisition
   - Quick Start (happy-path walkthrough)
   - Common patterns (pagination, ETag, idempotency)

   Part 3: API Reference (grouped by workflow)
   - Each workflow section has:
     - Context (why this endpoint group exists)
     - curl examples with request bodies
     - Example response bodies
     - Patchable fields (for PATCH endpoints)
     - Troubleshooting table

   Part 4: Reference Tables
   - Endpoint summary (all endpoints, one table)
   - Error reference (HTTP status codes + ProblemDetails)
   - Enum values (every enum with all values)
   ```

   **content/onboarding.md**: Consumer onboarding:
   - Prerequisites (app registration, VNet, MI)
   - Role assignment steps
   - Token verification
   - Common integration patterns table

   **content/architecture.md**: Technical architecture:
   - Infrastructure components table
   - Database containers/tables
   - Entity relationship diagram
   - Dual storage / caching patterns (if applicable)
   - Application layer architecture

   **content/toc.yml**: Table of contents

   **docfx.json**: Standard DocFX config (copy from existing service, update appTitle)

6. **Validate**: Run `review` action on the newly created docs

7. **Commit and push**: Stage all files, commit, push branch

8. **Report**: Print branch name, file count, line count, and suggest PR creation

---

### Action: `update`

Updates existing docs from source code changes.

1. **Run `review`**: Identify all issues
2. **For each CRITICAL/MAJOR issue**:
   - Investigate source to get correct values
   - Update the doc with correct values
3. **Check for new endpoints**: Compare source controllers to doc endpoint list
   - For each new endpoint: generate section with curl example, response, troubleshooting
4. **Check for removed endpoints**: Flag any doc sections for endpoints that no longer exist
5. **Update enum values**: Replace all enum sections with current values from source
6. **Commit**: Stage changes, commit with descriptive message
7. **Report**: Print changes made, issues resolved, remaining issues

---

### Action: `sync`

Full end-to-end: review + fix all issues + update from source + validate.

1. Run `review`
2. Run `update` (fixes all issues found)
3. Run `review` again (verify all issues resolved)
4. If issues remain after 2 iterations: report as manual-fix-needed
5. Commit and push

---

## Source Code Analysis Patterns

When investigating source repos, look in these locations:

### .NET API (CMS, LEAPI)

| What | Where |
|------|-------|
| Controllers | `sources/dev/{project}/src/API/Controllers/` |
| Enums | `sources/dev/{project}/src/Common/Enums/` |
| Request DTOs | `sources/dev/{project}/src/Common/DTOs/Requests/` |
| Response DTOs | `sources/dev/{project}/src/Common/DTOs/Responses/` |
| Domain models | `sources/dev/{project}/src/Common/Models/` |
| Auth policies | `sources/dev/{project}/src/Common/Constants/AuthorizationPolicies.cs` |
| PATCH paths | `sources/dev/{project}/src/DataAccess/Repositories/*Repository.cs` (AllowedPatchPaths) |
| Cosmos containers | `sources/dev/{project}/src/DataAccess/Contexts/*ContainerContext.cs` |
| Bicep infra | `sources/dev/{project}/src/Ev2/ServiceGroupRoot/Templates/*.bicep` |

### React/TypeScript (LRMS)

| What | Where |
|------|-------|
| API client | `src/services/api/` or `src/api/` |
| Routes | `src/routes/` or `src/App.tsx` |
| Types | `src/types/` or `src/**/*.types.ts` |
| Components | `src/components/` |

---

## Quality Checks

Every generated or updated doc must pass:

| Check | Criteria |
|-------|----------|
| **Enum accuracy** | Every enum value in doc exists in source code (zero phantom values) |
| **Endpoint coverage** | Every controller action has a doc section |
| **curl copy-paste** | Every curl example is syntactically valid bash |
| **Response realism** | Response examples use correct field names from DTOs |
| **Structure** | DocFX files present (index.md, toc.yml, docfx.json) |
| **Links** | All internal `[text](link)` references resolve to existing files/anchors |
| **Freshness** | Version and "Last Updated" date reflect current state |

---

## Examples

### Review docs for a service

```
/lens-docs:lens-docs review cms

=== LENS-Docs Review: CMS ===
Endpoint Coverage: 35/35 (100%)
Enum Accuracy: 12/12 enums correct
Field Accuracy: 3 issues found
Structure: PASS

Issues:
- MAJOR: CreateCaseRequest missing `workflowStage` field in example
- MINOR: NoteType example uses "Internal" (should be "General")
- MINOR: Missing `Scenario` enum in DFT section

Report: reviews/lens-docs-review-cms.md
```

### Create docs for a new service

```
/lens-docs:lens-docs create lrms

Creating LENS-Docs hub for LRMS...
Source repo: ${LENS_REPOS_ROOT}/LENS-LRMS
Branch: users/{user}/lrms-api-docs

Generated:
  sources/docs/enghub/lrms/index.md (32 lines)
  sources/docs/enghub/lrms/content/api-guide.md (450 lines)
  sources/docs/enghub/lrms/content/onboarding.md (60 lines)
  sources/docs/enghub/lrms/content/architecture.md (85 lines)
  sources/docs/enghub/lrms/content/toc.yml (6 lines)
  sources/docs/enghub/lrms/docfx.json (40 lines)

Review: 0 issues found.
Ready for PR.
```

### Sync after source code changes

```
/lens-docs:lens-docs sync cms

Step 1: Review...
  Found 4 issues (2 MAJOR, 2 MINOR)

Step 2: Update...
  Fixed: 2 new endpoints added
  Fixed: RequestType enum added "VoluntaryDisclosure"
  Fixed: NoteType example corrected

Step 3: Re-review...
  0 issues remaining.

Committed: "docs(cms): sync API guide with source -- 2 new endpoints, enum updates"
```

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| Source repo not found | Repo not cloned locally | Clone the repo or set `LENS_REPOS_ROOT` |
| Docs already exist | Using `create` on existing service | Use `update` or `sync` instead |
| No docs found | Using `review`/`update` on missing service | Use `create` first |
| Branch conflict | Branch already exists in LENS-Docs | Delete old branch or use a different name |

## Notes

- Generated docs follow the onboarding-first structure: context then quick start then reference
- All enum values are extracted from actual source code, never guessed
- The `sync` action is the recommended regular maintenance workflow
- LENS-Docs repo: `https://o365exchange.visualstudio.com/O365%20Core/_git/LENS-Docs`


<!-- TODO: source — LENS-Common plugins/LENS/Documentation/lens-docs/skills/lens-docs (PR 5158460 branch u/jacote/lens-aspnet-structure-skill); copied 2026-05-08; refresh after PR merges. Manual-only — never auto-triggered. -->
